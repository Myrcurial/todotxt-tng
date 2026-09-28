import Foundation

/// The one entry point for creating tasks. Quick-add uses it now. The URL scheme
/// (`todotxt://add?text=`), App Intents, the menu bar and AppleScript/Mail will too.
public struct AddTaskCommand: Sendable, Hashable {
    public var text: String
    public var sourceURI: String?
    public var messageID: String?
    public var addCreationDate: Bool

    public init(text: String, sourceURI: String? = nil, messageID: String? = nil, addCreationDate: Bool = true) {
        self.text = text
        self.sourceURI = sourceURI
        self.messageID = messageID
        self.addCreationDate = addCreationDate
    }

    /// Builds the task line. Newlines become spaces (one task = one line). The user's
    /// own prefix (priority, date) is honoured. A creation date is added if missing.
    /// Returns nil for empty input.
    public func makeTask(today: TaskDate) -> TodoTask? {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !flat.isEmpty else { return nil }
        var t = TodoTask(line: flat)
        if t.isCompleted { return TodoTask(line: flat) }   // pasted a done line: keep it
        if addCreationDate, t.creationDate == nil { t.setCreationDate(today) }
        if let s = sourceURI { t.setTag(KnownTag.source, TagValue.encodeURI(s)) }
        if let m = messageID { t.setTag(KnownTag.message, TagValue.encodeOpaque(m)) }
        if t.isModified { t.setBody(t.body) }   // make sure the canonical form is written
        return TodoTask(line: t.line)
    }
}
