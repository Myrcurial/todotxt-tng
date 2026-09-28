import Foundation

/// A small test runner, used because `swift test` can't load XCTest or Swift
/// Testing with Command Line Tools alone.
///
/// Moving to Swift Testing later:
/// - each `CheckSuite` becomes a `@Suite struct`
/// - each `check("name") { … }` becomes a `@Test func`
/// - `expect(a == b)` → `#expect(a == b)`, and `expectEqual(a, b)` → `#expect(a == b)`
@MainActor
final class CheckRunner {
    static let shared = CheckRunner()
    private(set) var passed = 0
    private(set) var failed: [String] = []
    private var current = ""
    private var currentFailures = 0

    func suite(_ name: String, _ body: () throws -> Void) {
        print("\n▸ \(name)")
        do { try body() } catch { record("suite threw: \(error)") }
    }

    func check(_ name: String, _ body: () throws -> Void) {
        current = name
        currentFailures = 0
        do { try body() } catch { record("threw \(error)") }
        if currentFailures == 0 {
            passed += 1
            print("  ✓ \(name)")
        }
    }

    func record(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
        if currentFailures == 0 { print("  ✗ \(current)") }
        currentFailures += 1
        let full = "\(current): \(message)  [\(file):\(line)]"
        failed.append(full)
        print("      \(message)  [\(file):\(line)]")
    }

    func finish() -> Never {
        print("\n\(passed) passed, \(failed.count) failed")
        exit(failed.isEmpty ? 0 : 1)
    }
}

@MainActor func suite(_ name: String, _ body: () throws -> Void) { CheckRunner.shared.suite(name, body) }
@MainActor func check(_ name: String, _ body: () throws -> Void) { CheckRunner.shared.check(name, body) }

@MainActor func expect(_ condition: Bool, _ message: @autoclosure () -> String = "expectation failed",
                       file: StaticString = #fileID, line: UInt = #line) {
    if !condition { CheckRunner.shared.record(message(), file: file, line: line) }
}

@MainActor func expectEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #fileID, line: UInt = #line) {
    if a != b { CheckRunner.shared.record("expected \(String(reflecting: b)), got \(String(reflecting: a))", file: file, line: line) }
}
