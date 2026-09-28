/// A Codable task predicate, so filters can be saved later ("saved filters").
public struct TaskFilter: Hashable, Sendable, Codable {
    public enum Status: String, Sendable, Codable { case open, completed, any }
    public enum DueBucket: String, Sendable, Codable, CaseIterable { case overdue, today, upcoming, noDate }

    public var status: Status = .open
    public var projects: Set<String> = []     // all must match
    public var contexts: Set<String> = []     // all must match
    public var priorities: Set<String> = []   // any matches; "" means "no priority"
    public var hasPriority: Bool?
    public var due: DueBucket?
    public var search: String = ""
    public var includeHidden = false          // tasks with a future t:

    public init(status: Status = .open, projects: Set<String> = [], contexts: Set<String> = [],
                hasPriority: Bool? = nil, due: DueBucket? = nil, search: String = "", includeHidden: Bool = false) {
        self.status = status
        self.projects = projects
        self.contexts = contexts
        self.hasPriority = hasPriority
        self.due = due
        self.search = search
        self.includeHidden = includeHidden
    }

    public func matches(_ t: TodoTask, today: TaskDate) -> Bool {
        if t.isBlank { return false }
        switch status {
        case .open: if t.isCompleted { return false }
        case .completed: if !t.isCompleted { return false }
        case .any: break
        }
        if !includeHidden, !t.isCompleted, t.isHidden(today: today) { return false }
        if !projects.isEmpty, !projects.isSubset(of: Set(t.projects)) { return false }
        if !contexts.isEmpty, !contexts.isSubset(of: Set(t.contexts)) { return false }
        if let hp = hasPriority, (t.priority != nil) != hp { return false }
        if !priorities.isEmpty, !priorities.contains(t.priority?.description ?? "") { return false }
        if let b = due, TaskFilter.bucket(for: t, today: today) != b { return false }
        if !search.isEmpty, !t.line.localizedStandardContains(search) { return false }
        return true
    }

    public static func bucket(for t: TodoTask, today: TaskDate, upcomingDays: Int = .max) -> DueBucket {
        guard let d = t.dueDate else { return .noDate }
        if d < today { return .overdue }
        if d == today { return .today }
        return .upcoming
    }
}
