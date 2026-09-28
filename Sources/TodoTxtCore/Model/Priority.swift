/// A todo.txt priority: one uppercase ASCII letter A–Z. `A` is the most important.
public struct Priority: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let letter: Character

    public init?(_ letter: Character) {
        guard letter.isASCII, letter.isUppercase, letter.isLetter else { return nil }
        self.letter = letter
    }

    public init?(_ string: some StringProtocol) {
        guard string.count == 1, let c = string.first else { return nil }
        self.init(c)
    }

    /// Parses the exact token `(X)`.
    public init?(token: some StringProtocol) {
        let chars = Array(token)
        guard chars.count == 3, chars[0] == "(", chars[2] == ")" else { return nil }
        self.init(chars[1])
    }

    public var description: String { String(letter) }
    public var token: String { "(\(letter))" }

    public static func < (a: Priority, b: Priority) -> Bool { a.letter < b.letter }

    public init(from decoder: any Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let p = Priority(s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad priority \(s)"))
        }
        self = p
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
