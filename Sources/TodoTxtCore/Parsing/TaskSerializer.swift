/// Writes tasks in the spec's canonical order (conservative output):
///
///     x COMPLETION CREATION body          (completed; priority kept as pri:X)
///     (P) CREATION body                   (incomplete)
///
/// Only used for lines that were changed. Unchanged lines are written back exactly.
public enum TaskSerializer {
    public static func serialize(_ task: TodoTask) -> String {
        var parts: [String] = []
        var body = task.body
        if task.isCompleted {
            parts.append("x")
            if let c = task.completionDate { parts.append(c.description) }
            if let cr = task.creationDate, task.completionDate != nil { parts.append(cr.description) }
            // A priority on a completed line isn't spec, so keep it as a pri: tag instead.
            if let p = task.priority, task.tag(KnownTag.priority) == nil {
                body = body.todoWords.isEmpty ? "pri:\(p)" : body.trimmingTrailingWhitespace + " pri:\(p)"
            }
        } else {
            if let p = task.priority { parts.append(p.token) }
            if let cr = task.creationDate { parts.append(cr.description) }
        }
        let trimmedBody = body.trimmingTrailingWhitespace
        if !trimmedBody.isEmpty { parts.append(trimmedBody) }
        return parts.joined(separator: " ")
    }
}
