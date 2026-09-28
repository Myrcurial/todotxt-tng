import AppKit
import Observation
import TodoTxtCore
import UniformTypeIdentifiers

/// Sidebar selection.
enum SmartView: Hashable {
    case all, priority, overdue, today, upcoming, noDate, completed
    case project(String)
    case context(String)

    var title: String {
        switch self {
        case .all: "All"
        case .priority: "Priority"
        case .overdue: "Overdue"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .noDate: "No Date"
        case .completed: "Completed"
        case .project(let p): "+" + p
        case .context(let c): "@" + c
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .priority: "exclamationmark.circle"
        case .overdue: "calendar.badge.exclamationmark"
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .noDate: "calendar.badge.minus"
        case .completed: "checkmark.circle"
        case .project: "folder"
        case .context: "at"
        }
    }

    var filter: TaskFilter {
        switch self {
        case .all: TaskFilter()
        case .priority: TaskFilter(hasPriority: true)
        case .overdue: TaskFilter(due: .overdue)
        case .today: TaskFilter(due: .today)
        case .upcoming: TaskFilter(due: .upcoming)
        case .noDate: TaskFilter(due: .noDate)
        case .completed: TaskFilter(status: .completed)
        case .project(let p): TaskFilter(projects: [p])
        case .context(let c): TaskFilter(contexts: [c])
        }
    }
}

/// App state: which file is open, sidebar selection, errors.
@MainActor
@Observable
final class AppModel {
    private(set) var store: TodoStore?
    var selection: SmartView? = .all
    var search = ""
    var errorMessage: String?

    private static let bookmarkKey = "lastFileBookmark"

    init() { reopenLastFile() }

    /// Tasks for the current view, sorted to suit it.
    func visibleTasks() -> [TodoTask] {
        guard let store else { return [] }
        let view = selection ?? .all
        var f = view.filter
        f.search = search
        let today = store.today
        let matched = store.file.tasks.filter { f.matches($0, today: today) }
        switch view {
        case .completed: return TaskSort.byCompletion(matched)
        case .overdue, .today, .upcoming: return TaskSort.byDue(matched)
        default: return TaskSort.byPriority(matched)
        }
    }

    func count(_ view: SmartView) -> Int {
        guard let store else { return 0 }
        let today = store.today
        return store.file.tasks.filter { view.filter.matches($0, today: today) }.count
    }

    // MARK: Files

    func open(_ url: URL) {
        do {
            store?.stopWatching()
            store = try TodoStore(url: url)
            saveBookmark(for: url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't open \(url.lastPathComponent): \(error)"
        }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.message = "Choose a todo.txt file"
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func showNewPanel() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "todo.txt"
        panel.allowedContentTypes = [.plainText]
        panel.message = "Create a new todo.txt file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        open(url)
    }

    private func saveBookmark(for url: URL) {
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        }
    }

    private func reopenLastFile() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path) else { return }
        open(url)
    }

    // MARK: Actions

    func add(_ text: String) {
        run { try $0.add(AddTaskCommand(text: text)) }
    }

    func toggle(_ id: TodoTask.ID) {
        run { try $0.toggleCompletion(id) }
    }

    func delete(_ id: TodoTask.ID) {
        run { try $0.delete(id) }
    }

    func setPriority(_ id: TodoTask.ID, _ p: Priority?) {
        run { try $0.update(id) { $0.setPriority(p) } }
    }

    func rewriteInStandardFormat() {
        run { try $0.rewriteInStandardFormat() }
    }

    private func run(_ action: (TodoStore) throws -> Void) {
        guard let store else { return }
        do {
            try action(store)
            errorMessage = nil
        } catch TodoStore.StoreError.conflict {
            errorMessage = "That task was changed in another app. The list has been reloaded, so please try again."
        } catch {
            errorMessage = "\(error)"
        }
    }
}
