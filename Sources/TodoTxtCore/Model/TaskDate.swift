import Foundation

/// A calendar day (`YYYY-MM-DD`) with no time or time zone, as used by todo.txt.
///
/// todo.txt dates are floating calendar days. Deciding which day is "today" is the
/// only place a time zone enters, via ``today(in:now:)``.
public struct TaskDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Creates a validated date; returns nil for impossible dates such as 2011-02-30.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month),
              (1...TaskDate.daysInMonth(year: year, month: month)).contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses exactly `YYYY-MM-DD` (ASCII digits). Anything else returns nil.
    public init?(_ string: some StringProtocol) {
        let s = Array(string.utf8)
        guard s.count == 10, s[4] == UInt8(ascii: "-"), s[7] == UInt8(ascii: "-") else { return nil }
        func num(_ r: Range<Int>) -> Int? {
            var v = 0
            for i in r {
                guard (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(s[i]) else { return nil }
                v = v * 10 + Int(s[i] - UInt8(ascii: "0"))
            }
            return v
        }
        guard let y = num(0..<4), let m = num(5..<7), let d = num(8..<10) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (a: TaskDate, b: TaskDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    // MARK: Codable as the plain string form

    public init(from decoder: any Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = TaskDate(s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
        }
        self = d
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }

    // MARK: Calendar maths (proleptic Gregorian, no Foundation time zones involved)

    public static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    /// Days since 1970-01-01 (H. Hinnant's days_from_civil).
    public var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    public init(dayNumber z0: Int) {
        let z = z0 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (m <= 2 ? 1 : 0), month: m, day: d)!
    }

    public func adding(days: Int) -> TaskDate { TaskDate(dayNumber: dayNumber + days) }

    /// Adds calendar months, clamping the day (Jan 31 + 1 month = Feb 28/29).
    public func adding(months: Int) -> TaskDate {
        let total = year * 12 + (month - 1) + months
        let y = total / 12, m = total % 12 + 1
        return TaskDate(year: y, month: m, day: min(day, TaskDate.daysInMonth(year: y, month: m)))!
    }

    /// 0 = Monday ... 6 = Sunday.
    public var weekday: Int { ((dayNumber % 7) + 7 + 3) % 7 }

    public func days(until other: TaskDate) -> Int { other.dayNumber - dayNumber }

    /// The current calendar day in the given time zone (defaults to the machine's).
    public static func today(in timeZone: TimeZone = .current, now: Date = Date()) -> TaskDate {
        from(now, in: timeZone)
    }

    public static func from(_ date: Date, in timeZone: TimeZone = .current) -> TaskDate {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return TaskDate(year: c.year!, month: c.month!, day: c.day!)!
    }
}
