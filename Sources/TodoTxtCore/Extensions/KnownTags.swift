import Foundation

/// Tag keys this app understands. Other keys are kept as they are.
public enum KnownTag {
    public static let due = "due"             // due:YYYY-MM-DD
    public static let threshold = "t"         // t:YYYY-MM-DD, hide until
    public static let recurrence = "rec"      // rec:1w, rec:+1m
    public static let priority = "pri"        // pri:A, priority kept after completion
    public static let calendar = "cal"        // cal:<EventKit identifier>
    public static let source = "src"          // src:<URI, colons written as ;>
    public static let message = "msg"         // msg:<percent-encoded Message-ID>
}

extension TodoTask {
    public var dueDate: TaskDate? { tag(KnownTag.due).flatMap { TaskDate($0) } }
    public var thresholdDate: TaskDate? { tag(KnownTag.threshold).flatMap { TaskDate($0) } }
    public var recurrence: Recurrence? { tag(KnownTag.recurrence).flatMap { Recurrence($0) } }
    public var calendarID: String? { tag(KnownTag.calendar) }
    public var sourceURL: URL? { tag(KnownTag.source).flatMap(TagValue.decodeURI).flatMap { URL(string: $0) } }
    public var messageID: String? { tag(KnownTag.message).flatMap { $0.removingPercentEncoding } }

    /// Completion date from the file, or else the one the app inferred.
    public var effectiveCompletionDate: TaskDate? { completionDate ?? inferredCompletionDate }

    /// Days from creation to completion. Nil unless both dates are known.
    public var daysToComplete: Int? {
        guard let c = creationDate, let d = effectiveCompletionDate else { return nil }
        return c.days(until: d)
    }

    /// Hidden by a future threshold date (`t:`).
    public func isHidden(today: TaskDate) -> Bool {
        guard let t = thresholdDate else { return false }
        return t > today
    }
}

/// Encoding for values that must fit in `key:value`: no whitespace and no ASCII colon.
public enum TagValue {
    /// URIs: `%`, `;` and whitespace are percent-encoded first, then `:` becomes `;`.
    /// `https://ex.com/a` → `https;//ex.com/a`. Decoding reverses this exactly.
    public static func encodeURI(_ uri: String) -> String {
        var out = ""
        for ch in uri.unicodeScalars {
            switch ch {
            case "%": out += "%25"
            case ";": out += "%3B"
            case ":": out += ";"
            default:
                if ch.properties.isWhitespace {
                    out += String(ch).utf8.map { String(format: "%%%02X", $0) }.joined()
                } else {
                    out.unicodeScalars.append(ch)
                }
            }
        }
        return out
    }

    public static func decodeURI(_ value: String) -> String? {
        value.replacingOccurrences(of: ";", with: ":").removingPercentEncoding
    }

    /// Arbitrary text such as an RFC 5322 Message-ID: percent-encode everything except
    /// unreserved characters and a few safe marks, so no `:` or whitespace remains.
    public static func encodeOpaque(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~@")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
