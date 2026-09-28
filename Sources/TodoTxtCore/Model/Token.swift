/// One whitespace-separated word of a task description, classified.
public enum Token: Hashable, Sendable {
    case text(String)
    case project(String)
    case context(String)
    case tag(key: String, value: String)

    /// Classifies a single word (no whitespace).
    ///
    /// - `+name` → project and `@name` → context, only when the sign starts the word.
    ///   So `soandso@example.com` and `2+2` stay plain text.
    /// - `key:value` → tag: exactly one ASCII colon, and neither side empty.
    ///   Values starting with `//` are URLs (`https://…`) and stay plain text.
    public init(word: some StringProtocol) {
        let w = String(word)
        if w.count > 1, w.first == "+" {
            self = .project(String(w.dropFirst()))
        } else if w.count > 1, w.first == "@" {
            self = .context(String(w.dropFirst()))
        } else if let colon = w.firstIndex(of: ":") {
            let key = w[..<colon]
            let value = w[w.index(after: colon)...]
            if !key.isEmpty, !value.isEmpty, !value.contains(":"), !value.hasPrefix("//") {
                self = .tag(key: String(key), value: String(value))
            } else {
                self = .text(w)
            }
        } else {
            self = .text(w)
        }
    }

    public var text: String {
        switch self {
        case .text(let s): s
        case .project(let p): "+" + p
        case .context(let c): "@" + c
        case .tag(let k, let v): "\(k):\(v)"
        }
    }
}

extension StringProtocol {
    /// Splits on any Unicode whitespace; never produces empty words.
    var todoWords: [SubSequence] { split(whereSeparator: \.isWhitespace) }
}
