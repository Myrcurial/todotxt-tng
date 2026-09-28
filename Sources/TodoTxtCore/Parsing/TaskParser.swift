import Foundation

/// Parses single todo.txt lines.
///
/// Follows the spec (https://github.com/todotxt/todo.txt/blob/master/README.md),
/// and is liberal where the spec allows it (Postel's Law):
///
/// - Leading whitespace and runs of spaces or tabs between prefix fields are accepted.
/// - After an optional leading `x `, the prefix fields (priority, dates) may come in
///   any order, e.g. `2011-03-01 (A) Call Mom` or `x (A) 2011-03-02 Call Mom`.
/// - `x` must be the first field, be lowercase, and be followed by whitespace, so
///   `xylophone`, `X 2012-…` and `(A) x Find…` are not complete, as the spec says.
/// - A priority is exactly `(A)`–`(Z)` as a whole word: `(b)` and `(B)->Submit` are not.
/// - A completed task's first prefix date is the completion date, the second the creation date.
///   An incomplete task has at most one prefix date: its creation date.
public enum TaskParser {
    public static func parse(_ line: String, id: UUID = UUID()) -> TodoTask {
        var rest = line[...]
        var isCompleted = false
        var priority: Priority?
        var dates: [TaskDate] = []

        func skipSpace() { rest = rest.drop(while: \.isWhitespace) }
        /// Next word and the remainder after it; nil at end.
        func peekWord() -> (Substring, Substring)? {
            let w = rest.prefix { !$0.isWhitespace }
            return w.isEmpty ? nil : (w, rest[w.endIndex...])
        }

        skipSpace()
        if let (w, after) = peekWord(), w == "x", after.first?.isWhitespace == true {
            isCompleted = true
            rest = after
            skipSpace()
        }

        let maxDates = isCompleted ? 2 : 1
        while let (w, after) = peekWord(), after.isEmpty || after.first!.isWhitespace {
            if priority == nil, let p = Priority(token: w) {
                priority = p
            } else if dates.count < maxDates, let d = TaskDate(w) {
                dates.append(d)
            } else {
                break
            }
            rest = after
            skipSpace()
        }

        let completion = isCompleted ? dates.first : nil
        let creation = isCompleted ? (dates.count > 1 ? dates[1] : nil) : dates.first
        return TodoTask(id: id, rawLine: line, isCompleted: isCompleted, priority: priority,
                        completionDate: completion, creationDate: creation, body: String(rest))
    }
}
