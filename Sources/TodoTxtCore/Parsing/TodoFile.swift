import Foundation

/// A whole todo.txt file, kept so that `TodoFile(data:).data` gives back the same bytes.
///
/// Keeps: a UTF-8 BOM, LF/CRLF per line, blank lines, and whether the file ends with a newline.
public struct TodoFile: Hashable, Sendable {
    public var tasks: [TodoTask]
    public var hasBOM: Bool
    public var endsWithNewline: Bool
    /// Line ending used for new lines: CRLF if the file mostly uses it.
    public var prefersCRLF: Bool

    public enum Error: Swift.Error, Equatable { case notUTF8 }

    public init(tasks: [TodoTask] = [], hasBOM: Bool = false, endsWithNewline: Bool = true, prefersCRLF: Bool = false) {
        self.tasks = tasks
        self.hasBOM = hasBOM
        self.endsWithNewline = endsWithNewline
        self.prefersCRLF = prefersCRLF
    }

    /// Decodes strict UTF-8. Invalid bytes throw rather than being silently replaced.
    public init(data: Data) throws {
        var bytes = data[...]
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        let hasBOM = bytes.starts(with: bom)
        if hasBOM { bytes = bytes.dropFirst(3) }
        guard let text = String(validating: bytes, as: UTF8.self) else { throw Error.notUTF8 }
        self.init(text: text)
        self.hasBOM = hasBOM
    }

    public init(text: String) {
        // Split on \n only (by scalar, so "\r\n" isn't one Character we miss).
        var lines = text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false).map { String(String.UnicodeScalarView($0)) }
        let endsWithNewline = text.unicodeScalars.last == "\n"
        if endsWithNewline || text.isEmpty { lines.removeLast() }
        var crCount = 0
        tasks = lines.map { raw in
            var line = raw
            let cr = line.unicodeScalars.last == "\r"
            if cr { line.unicodeScalars.removeLast(); crCount += 1 }
            var t = TodoTask(line: line)
            t.endsWithCR = cr
            return t
        }
        hasBOM = false
        self.endsWithNewline = endsWithNewline || text.isEmpty
        prefersCRLF = crCount * 2 > lines.count && crCount > 0
    }

    public var text: String {
        var out = ""
        for (i, t) in tasks.enumerated() {
            out += t.line
            let isLast = i == tasks.count - 1
            if !isLast || endsWithNewline { out += t.endsWithCR ? "\r\n" : "\n" }
        }
        return out
    }

    public var data: Data {
        (hasBOM ? Data([0xEF, 0xBB, 0xBF]) : Data()) + Data(text.utf8)
    }

    /// Adds a task, using the file's usual line ending. Makes sure the previous last
    /// line gets a newline if the file didn't end with one.
    public mutating func append(_ task: TodoTask) {
        var t = task
        t.endsWithCR = prefersCRLF
        endsWithNewline = true
        tasks.append(t)
    }

    /// Carries in-memory IDs over from an earlier load. Lines are matched by raw text,
    /// in order, so duplicate lines pair off one to one. Unmatched lines keep new IDs.
    public func adoptingIdentities(from old: TodoFile) -> TodoFile {
        var pool: [String: [TodoTask]] = [:]
        for t in old.tasks { pool[t.line, default: []].append(t) }
        var copy = self
        for i in copy.tasks.indices {
            let key = copy.tasks[i].rawLine
            if var list = pool[key], !list.isEmpty {
                let prior = list.removeFirst()
                copy.tasks[i].id = prior.id
                copy.tasks[i].inferredCompletionDate = prior.inferredCompletionDate
                pool[key] = list
            }
        }
        return copy
    }
}
