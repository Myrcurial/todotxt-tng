/// Sorting and grouping helpers for the list views.
public enum TaskSort {
    /// Priority (A first, none last), then due date (sooner first, none last), then file order.
    public static func byPriority(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.enumerated().sorted { a, b in
            let pa = a.element.priority, pb = b.element.priority
            if pa != pb { return pa.map { p in pb.map { p < $0 } ?? true } ?? false }
            let da = a.element.dueDate, db = b.element.dueDate
            if da != db { return da.map { d in db.map { d < $0 } ?? true } ?? false }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Due date, then priority.
    public static func byDue(_ tasks: [TodoTask]) -> [TodoTask] {
        byPriority(tasks).enumerated().sorted { a, b in
            let da = a.element.dueDate, db = b.element.dueDate
            if da != db { return da.map { d in db.map { d < $0 } ?? true } ?? false }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Most recently completed first.
    public static func byCompletion(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.enumerated().sorted { a, b in
            let da = a.element.effectiveCompletionDate, db = b.element.effectiveCompletionDate
            if da != db { return da.map { d in db.map { d > $0 } ?? true } ?? false }
            return a.offset < b.offset
        }.map(\.element)
    }

    /// Distinct projects or contexts with open-task counts, sorted case-insensitively.
    public static func counts(_ tasks: [TodoTask], _ key: (TodoTask) -> [String]) -> [(name: String, count: Int)] {
        var c: [String: Int] = [:]
        for t in tasks where !t.isBlank {
            for n in Set(key(t)) { c[n, default: 0] += t.isCompleted ? 0 : 1 }
        }
        return c.map { ($0.key, $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
