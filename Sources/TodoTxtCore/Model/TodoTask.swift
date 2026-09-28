import Foundation

/// One line of a todo.txt file.
///
/// Round-trip guarantee: a task keeps its original `rawLine`. ``line`` returns it
/// exactly until the task is changed through one of the mutating APIs. After a
/// change, the line is rebuilt in the spec's field order.
///
/// Blank lines are tasks too (``isBlank``) so the file layout survives a save.
public struct TodoTask: Identifiable, Hashable, Sendable {
    /// In-memory identity only. Never written to disk. Carried across reloads by
    /// matching raw text (see `TodoFile.adoptingIdentities(from:)`).
    public var id: UUID

    public private(set) var rawLine: String
    public private(set) var isModified = false

    public private(set) var isCompleted: Bool
    public private(set) var priority: Priority?
    public private(set) var completionDate: TaskDate?
    public private(set) var creationDate: TaskDate?
    /// Everything after the prefix fields, with the user's spacing kept.
    public private(set) var body: String

    /// Whether the original line ended in CR (from a CRLF file). Per line, so mixed files survive.
    public var endsWithCR = false

    /// Completion date the app inferred for a completed line that had none
    /// (file modification time, or the time the file was opened). Not persisted.
    public var inferredCompletionDate: TaskDate?

    public init(line: String, id: UUID = UUID()) {
        self.id = id
        self = TaskParser.parse(line, id: id)
    }

    init(id: UUID, rawLine: String, isCompleted: Bool, priority: Priority?,
         completionDate: TaskDate?, creationDate: TaskDate?, body: String) {
        self.id = id
        self.rawLine = rawLine
        self.isCompleted = isCompleted
        self.priority = priority
        self.completionDate = completionDate
        self.creationDate = creationDate
        self.body = body
    }

    /// The text to write for this task.
    public var line: String { isModified ? TaskSerializer.serialize(self) : rawLine }

    public var isBlank: Bool { rawLine.allSatisfy(\.isWhitespace) && !isModified }

    // MARK: Derived metadata

    public var tokens: [Token] { body.todoWords.map(Token.init(word:)) }

    public var projects: [String] { tokens.compactMap { if case .project(let p) = $0 { p } else { nil } } }
    public var contexts: [String] { tokens.compactMap { if case .context(let c) = $0 { c } else { nil } } }
    public var tags: [(key: String, value: String)] {
        tokens.compactMap { if case .tag(let k, let v) = $0 { (k, v) } else { nil } }
    }

    /// The first value for `key`, if any.
    public func tag(_ key: String) -> String? { tags.first { $0.key == key }?.value }

    /// The description minus tags, for display. Projects and contexts are kept.
    public var displayText: String {
        tokens.filter { if case .tag = $0 { false } else { true } }.map(\.text).joined(separator: " ")
    }

    // MARK: Mutation (each marks the task modified)

    /// Marks complete. Moves any priority into a `pri:` tag, as the spec suggests.
    public mutating func complete(on date: TaskDate) {
        guard !isCompleted else { return }
        if let p = priority {
            if tag(KnownTag.priority) == nil { appendWord("\(KnownTag.priority):\(p)") }
            priority = nil
        }
        isCompleted = true
        completionDate = date
        inferredCompletionDate = nil
        isModified = true
    }

    /// Marks incomplete. Restores the priority from `pri:` if there is no priority.
    public mutating func uncomplete() {
        guard isCompleted else { return }
        if priority == nil, let v = tag(KnownTag.priority), let p = Priority(v) {
            priority = p
            removeTag(KnownTag.priority)
        }
        isCompleted = false
        completionDate = nil
        inferredCompletionDate = nil
        isModified = true
    }

    public mutating func setPriority(_ p: Priority?) {
        priority = p
        isModified = true
    }

    public mutating func setCreationDate(_ d: TaskDate?) {
        creationDate = d
        isModified = true
    }

    public mutating func setBody(_ text: String) {
        body = text
        isModified = true
    }

    /// Replaces the first `key:` tag, or appends one. Other words and their order are unchanged.
    public mutating func setTag(_ key: String, _ value: String) {
        var words = body.todoWords.map(String.init)
        if let i = words.firstIndex(where: { if case .tag(key, _) = Token(word: $0) { true } else { false } }) {
            words[i] = "\(key):\(value)"
            body = words.joined(separator: " ")
        } else {
            appendWord("\(key):\(value)")
        }
        isModified = true
    }

    /// Removes every `key:` tag.
    public mutating func removeTag(_ key: String) {
        body = body.todoWords
            .filter { if case .tag(key, _) = Token(word: $0) { false } else { true } }
            .joined(separator: " ")
        isModified = true
    }

    /// This task in the spec's standard form: fields in order, single spaces, no
    /// leading or trailing whitespace, and a priority on a completed task moved to `pri:`.
    /// An inferred completion date is not written; only dates already in the file are used.
    public func normalized() -> TodoTask {
        var t = self
        t.body = body.todoWords.joined(separator: " ")
        t.isModified = true
        var n = TodoTask(line: t.line, id: id)
        n.inferredCompletionDate = inferredCompletionDate
        return n
    }

    private mutating func appendWord(_ w: String) {
        body = body.todoWords.isEmpty ? w : body.trimmingTrailingWhitespace + " " + w
        isModified = true
    }
}

extension String {
    var trimmingTrailingWhitespace: String {
        var s = self[...]
        while let l = s.last, l.isWhitespace { s = s.dropLast() }
        return String(s)
    }
}
