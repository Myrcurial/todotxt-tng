/// `rec:` values in the common todo.txt style: `[+]<n><d|b|w|m|y>`.
///
/// Without `+`, the next date counts from the completion date. With `+` ("strict"),
/// it counts from the task's current due date. `b` means business days (Mon–Fri).
public struct Recurrence: Hashable, Sendable, CustomStringConvertible {
    public enum Unit: Character, Sendable { case day = "d", businessDay = "b", week = "w", month = "m", year = "y" }

    public let amount: Int
    public let unit: Unit
    public let strict: Bool

    public init?(_ string: some StringProtocol) {
        var s = Substring(string)
        strict = s.first == "+"
        if strict { s = s.dropFirst() }
        guard let u = s.last.flatMap(Unit.init(rawValue:)),
              let n = Int(s.dropLast()), n > 0 else { return nil }
        amount = n
        unit = u
    }

    public var description: String { (strict ? "+" : "") + "\(amount)\(unit.rawValue)" }

    public func next(after date: TaskDate) -> TaskDate {
        switch unit {
        case .day: return date.adding(days: amount)
        case .week: return date.adding(days: 7 * amount)
        case .month: return date.adding(months: amount)
        case .year: return date.adding(months: 12 * amount)
        case .businessDay:
            var d = date, left = amount
            while left > 0 {
                d = d.adding(days: 1)
                if d.weekday < 5 { left -= 1 }
            }
            return d
        }
    }
}
