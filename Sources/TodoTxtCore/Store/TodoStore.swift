import Foundation
import Observation

/// Holds one open todo.txt file. The file on disk is always the source of truth.
///
/// Multiple writers (another app, a text editor, iCloud on another Mac):
/// every change reads the current file, applies the change to that version and
/// writes it back atomically, all inside one `NSFileCoordinator` write. So we never
/// overwrite lines someone else changed from a stale copy. If the task being edited
/// was itself changed or removed on disk, the edit is refused (`.conflict`), the
/// view reloads, and nothing is lost.
@MainActor
@Observable
public final class TodoStore {
    public enum StoreError: Error, Equatable { case conflict, notUTF8, io(String) }

    public private(set) var url: URL
    public private(set) var file = TodoFile()
    public private(set) var lastError: StoreError?
    /// Time zone used to decide "today". Defaults to the machine's.
    public var timeZone: TimeZone = .current

    @ObservationIgnored private var watcher: FileWatcher?
    @ObservationIgnored private var lastDiskData: Data?
    @ObservationIgnored private let openedAt: Date
    @ObservationIgnored private let now: @Sendable () -> Date

    public var tasks: [TodoTask] { file.tasks.filter { !$0.isBlank } }
    public var today: TaskDate { TaskDate.today(in: timeZone, now: now()) }

    /// Opens `url`, creating an empty file if it doesn't exist.
    public init(url: URL, watch: Bool = true, now: @escaping @Sendable () -> Date = { Date() }) throws(StoreError) {
        self.url = url
        self.now = now
        self.openedAt = now()
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
                throw .io("Could not create \(url.path)")
            }
        }
        try reload()
        if watch { startWatching() }
    }

    public func startWatching() {
        watcher = FileWatcher(url: url) { [weak self] in
            try? self?.reload()
        }
    }

    public func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    // MARK: Reading

    /// Reloads from disk if the bytes changed. IDs carry over for unchanged lines.
    public func reload() throws(StoreError) {
        let data = try coordinatedRead()
        guard data != lastDiskData else { return }
        apply(diskData: data, modified: modificationDate())
    }

    private func apply(diskData data: Data, modified: Date?) {
        guard let parsed = try? TodoFile(data: data) else {
            lastError = .notUTF8
            return
        }
        let isFirstLoad = lastDiskData == nil
        var next = parsed.adoptingIdentities(from: file)
        // Completed lines with no date get an inferred date (not written to disk):
        // on first load, when the file was opened; later, the file's modification time.
        for i in next.tasks.indices {
            let t = next.tasks[i]
            guard t.isCompleted, t.completionDate == nil, t.inferredCompletionDate == nil else { continue }
            let when = isFirstLoad ? openedAt : (modified ?? now())
            next.tasks[i].inferredCompletionDate = TaskDate.from(when, in: timeZone)
        }
        file = next
        lastDiskData = data
        lastError = nil
    }

    // MARK: Coordinated I/O

    /// Read-modify-write against the latest disk contents, inside one coordinated write.
    func transact(_ change: (inout TodoFile) throws(StoreError) -> Void) throws(StoreError) {
        var failure: StoreError?
        var coordError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forMerging, error: &coordError) { u in
            // 1. Catch up with disk; another writer may have changed it.
            let disk = (try? Data(contentsOf: u)) ?? Data()
            if disk != lastDiskData {
                apply(diskData: disk, modified: modificationDate())
                if lastError == .notUTF8 { failure = .notUTF8; return }
            }
            // 2. Apply the change to the current version.
            var next = file
            do throws(StoreError) { try change(&next) } catch { failure = error; return }
            // 3. Write atomically, then re-read our own output so the in-memory
            //    state matches the bytes on disk (rawLine = what's on disk).
            let out = next.data
            do { try out.write(to: u, options: .atomic) } catch {
                failure = .io(error.localizedDescription); return
            }
            if var fresh = try? TodoFile(data: out) {
                for i in fresh.tasks.indices where i < next.tasks.count {
                    fresh.tasks[i].id = next.tasks[i].id
                    if fresh.tasks[i].isCompleted, fresh.tasks[i].completionDate == nil {
                        fresh.tasks[i].inferredCompletionDate = next.tasks[i].inferredCompletionDate
                    }
                }
                file = fresh
            }
            lastDiskData = out
            lastError = nil
        }
        if let coordError { failure = .io(coordError.localizedDescription) }
        if let failure {
            lastError = failure
            throw failure
        }
    }

    private func coordinatedRead() throws(StoreError) -> Data {
        var data: Data?
        var coordError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordError) { u in
            data = try? Data(contentsOf: u)
        }
        if let coordError { throw .io(coordError.localizedDescription) }
        guard let data else { throw .io("Could not read \(url.path)") }
        return data
    }

    private func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
