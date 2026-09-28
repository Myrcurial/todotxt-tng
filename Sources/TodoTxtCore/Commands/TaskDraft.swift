/// Every field of a new task, as separate values. Used by the New Task dialog.
///
/// `line` builds the spec-standard text; `problems` lists anything that would not
/// round-trip (e.g. a project name with a space, or a bad date).
public struct TaskDraft: Hashable, Sendable {
    public var text = ""
    public var priority: Priority?
    public var creationDate: TaskDate?
    public var due: TaskDate?
    public var threshold: TaskDate?
    public var recurrence = ""
    public var projects: [String] = []
    public var contexts: [String] = []
    /// Other `key:value` tags, in order.
    public var tags: [Tag] = []

    public struct Tag: Hashable, Sendable {
        public var key: String
        public var value: String
        public init(key: String, value: String) { self.key = key; self.value = value }
    }

    public init() {}

    /// Keys handled by dedicated fields; not allowed in `tags`.
    public static let reservedKeys: Set<String> = [KnownTag.due, KnownTag.threshold, KnownTag.recurrence, KnownTag.priority]

    public var problems: [String] {
        var out: [String] = []
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append("Description is empty") }
        if text.contains(where: \.isNewline) { out.append("Description must be one line") }
        let rec = recurrence.trimmingCharacters(in: .whitespaces)
        if !rec.isEmpty, Recurrence(rec) == nil { out.append("Recurrence “\(rec)” isn’t valid (try 1w, 3d, +1m)") }
        if let d = due, let t = threshold, t > d { out.append("Threshold is after the due date") }
        for p in projects where !Self.isWord(p) { out.append("Project “\(p)” can’t contain spaces") }
        for c in contexts where !Self.isWord(c) { out.append("Context “\(c)” can’t contain spaces") }
        for tag in tags {
            if Self.reservedKeys.contains(tag.key) { out.append("Use the dedicated field for “\(tag.key):”") }
            else if case .tag(tag.key, tag.value) = Token(word: "\(tag.key):\(tag.value)") {} else {
                out.append("Tag “\(tag.key):\(tag.value)” isn’t a valid key:value")
            }
        }
        return out
    }

    public var isValid: Bool { problems.isEmpty }

    /// The line to write: `(P) CREATED text +projects @contexts due: t: rec: tags`.
    /// Projects/contexts already typed in the description aren't repeated.
    public var line: String {
        var parts: [String] = []
        if let p = priority { parts.append(p.token) }
        if let c = creationDate { parts.append(c.description) }
        let desc = text.split(whereSeparator: \.isNewline).joined(separator: " ").todoWords.joined(separator: " ")
        if !desc.isEmpty { parts.append(desc) }
        let existing = TodoTask(line: desc)
        for p in Self.unique(projects) where !existing.projects.contains(p) { parts.append("+" + p) }
        for c in Self.unique(contexts) where !existing.contexts.contains(c) { parts.append("@" + c) }
        if let d = due { parts.append("\(KnownTag.due):\(d)") }
        if let t = threshold { parts.append("\(KnownTag.threshold):\(t)") }
        let rec = recurrence.trimmingCharacters(in: .whitespaces)
        if !rec.isEmpty { parts.append("\(KnownTag.recurrence):\(rec)") }
        for tag in tags where !tag.key.isEmpty || !tag.value.isEmpty { parts.append("\(tag.key):\(tag.value)") }
        return parts.joined(separator: " ")
    }

    public var task: TodoTask { TodoTask(line: line) }

    private static func isWord(_ s: String) -> Bool { !s.isEmpty && !s.contains(where: \.isWhitespace) }

    private static func unique(_ xs: [String]) -> [String] {
        var seen = Set<String>()
        return xs.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

/// Values already used in a file, most-used first, for dropdowns.
public struct TaskVocabulary: Sendable, Equatable {
    public var projects: [String] = []
    public var contexts: [String] = []
    public var priorities: [Priority] = []
    public var recurrences: [String] = []
    /// Other tag keys (excluding ones with dedicated fields) and their values.
    public var tagKeys: [String] = []
    public var tagValues: [String: [String]] = [:]

    public init() {}

    public init(tasks: [TodoTask]) {
        var proj: [String: Int] = [:], ctx: [String: Int] = [:], rec: [String: Int] = [:], keys: [String: Int] = [:]
        var vals: [String: [String: Int]] = [:]
        var pris = Set<Priority>()
        for t in tasks where !t.isBlank {
            t.projects.forEach { proj[$0, default: 0] += 1 }
            t.contexts.forEach { ctx[$0, default: 0] += 1 }
            if let p = t.priority { pris.insert(p) }
            if let p = t.tag(KnownTag.priority).flatMap({ Priority($0) }) { pris.insert(p) }
            for (k, v) in t.tags {
                if k == KnownTag.recurrence { rec[v, default: 0] += 1 }
                if TaskDraft.reservedKeys.contains(k) { continue }
                keys[k, default: 0] += 1
                vals[k, default: [:]][v, default: 0] += 1
            }
        }
        func ranked(_ d: [String: Int]) -> [String] {
            d.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.localizedStandardCompare($1.key) == .orderedAscending }.map(\.key)
        }
        projects = ranked(proj)
        contexts = ranked(ctx)
        recurrences = ranked(rec)
        priorities = pris.sorted()
        tagKeys = ranked(keys)
        tagValues = vals.mapValues(ranked)
    }
}
