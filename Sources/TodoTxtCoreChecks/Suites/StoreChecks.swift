import Foundation
import TodoTxtCore

@MainActor func storeChecks() {
    suite("Store (temporary files)") {
        func tempFile(_ contents: String?) -> URL {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tt-checks-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("todo.txt")
            if let contents { try? Data(contents.utf8).write(to: url) }
            return url
        }
        let fixedNow: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_790_000_000) }  // 2026-09-21 UTC

        check("creates a missing file") {
            let url = tempFile(nil)
            let s = try TodoStore(url: url, watch: false, now: fixedNow)
            expect(FileManager.default.fileExists(atPath: url.path))
            expectEqual(s.tasks.count, 0)
        }
        check("add and toggle write through, leaving other lines untouched") {
            let url = tempFile("(b) keep  this\r\n(A) 2026-01-01 Call Mom\r\n")
            let s = try TodoStore(url: url, watch: false, now: fixedNow)
            s.timeZone = TimeZone(identifier: "UTC")!
            let id = s.tasks[1].id
            try s.toggleCompletion(id)
            try s.add(AddTaskCommand(text: "New thing"))
            let text = try String(contentsOf: url, encoding: .utf8)
            expectEqual(text, "(b) keep  this\r\nx 2026-09-21 2026-01-01 Call Mom pri:A\r\n2026-09-21 New thing\r\n")
            expectEqual(s.tasks[1].id, id)
        }
        check("an edit merges with an outside change instead of overwriting it") {
            let url = tempFile("a\nb\n")
            let s = try TodoStore(url: url, watch: false, now: fixedNow)
            let idB = s.tasks[1].id
            try Data("a\nb\nfrom other app\n".utf8).write(to: url)   // another writer
            try s.toggleCompletion(idB)
            let text = try String(contentsOf: url, encoding: .utf8)
            expect(text.contains("from other app"), text)
            expect(text.contains("x 2026-09-21 b"), text)
        }
        check("editing a line someone else changed is refused as a conflict") {
            let url = tempFile("a\nb\n")
            let s = try TodoStore(url: url, watch: false, now: fixedNow)
            let idB = s.tasks[1].id
            try Data("a\nb edited elsewhere\n".utf8).write(to: url)
            var err: TodoStore.StoreError?
            do throws(TodoStore.StoreError) { try s.toggleCompletion(idB) } catch { err = error }
            expectEqual(err, .conflict)
            expectEqual(try String(contentsOf: url, encoding: .utf8), "a\nb edited elsewhere\n")
            expectEqual(s.tasks.map(\.line), ["a", "b edited elsewhere"])
        }
        check("completed lines without a date get an inferred date that isn't written") {
            let url = tempFile("x no date\n")
            let s = try TodoStore(url: url, watch: false, now: fixedNow)
            s.timeZone = TimeZone(identifier: "UTC")!
            expect(s.tasks[0].effectiveCompletionDate != nil)
            expectEqual(try String(contentsOf: url, encoding: .utf8), "x no date\n")
        }
        check("the watcher reloads after an outside atomic replace") {
            let url = tempFile("one\n")
            let s = try TodoStore(url: url, watch: true, now: fixedNow)
            try Data("one\ntwo\n".utf8).write(to: url, options: .atomic)
            let deadline = Date().addingTimeInterval(3)
            while s.tasks.count < 2, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            expectEqual(s.tasks.map(\.line), ["one", "two"])
            // A second replace, to show the watch re-armed on the new file.
            try Data("one\ntwo\nthree\n".utf8).write(to: url, options: .atomic)
            let deadline2 = Date().addingTimeInterval(3)
            while s.tasks.count < 3, Date() < deadline2 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            expectEqual(s.tasks.count, 3)
            s.stopWatching()
        }
    }
}
