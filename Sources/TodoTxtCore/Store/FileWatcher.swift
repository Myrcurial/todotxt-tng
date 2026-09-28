import Foundation

/// Watches a file for outside changes using DispatchSource.
///
/// Watches both the file and its folder, because many editors (vim, BBEdit) and
/// iCloud save by writing a new file and renaming it over the old one. That
/// replaces the inode, so a file-only watch would go quiet. When the file is
/// deleted, renamed or replaced, the file watch is re-armed.
///
/// Events are debounced and delivered on the main actor.
@MainActor
public final class FileWatcher {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    public init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
        armDirectory()
        armFile()
    }

    isolated deinit {
        fileSource?.cancel()
        dirSource?.cancel()
        pending?.cancel()
    }

    public func stop() {
        fileSource?.cancel(); fileSource = nil
        dirSource?.cancel(); dirSource = nil
    }

    private func makeSource(path: String, mask: DispatchSource.FileSystemEvent,
                            handler: @escaping @MainActor (DispatchSource.FileSystemEvent) -> Void) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: mask, queue: .main)
        src.setEventHandler { [weak src] in
            let ev = src?.data ?? []
            MainActor.assumeIsolated { handler(ev) }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        return src
    }

    private func armFile() {
        fileSource?.cancel()
        fileSource = makeSource(path: url.path, mask: [.write, .extend, .delete, .rename, .revoke, .attrib]) { [weak self] ev in
            guard let self else { return }
            if !ev.isDisjoint(with: [.delete, .rename, .revoke]) {
                self.fileSource?.cancel()
                self.fileSource = nil
            }
            self.schedule()
        }
    }

    private func armDirectory() {
        dirSource = makeSource(path: url.deletingLastPathComponent().path, mask: [.write]) { [weak self] _ in
            self?.schedule()
        }
    }

    private func schedule() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.fileSource == nil { self.armFile() }  // file replaced: watch the new one
                self.onChange()
            }
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }
}
