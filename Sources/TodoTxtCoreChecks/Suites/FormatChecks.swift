import Foundation
import TodoTxtCore

@MainActor func keyValueChecks() {
    suite("key:value tags") {
        check("due:2010-01-02 is a tag") {
            let t = TodoTask(line: "Pay rent due:2010-01-02")
            expectEqual(t.tag("due"), "2010-01-02")
            expectEqual(t.dueDate, d("2010-01-02"))
        }
        check("more than one colon is not a tag") {
            expectEqual(TodoTask(line: "a:b:c").tags.count, 0)
        }
        check("empty key or value is not a tag") {
            expectEqual(TodoTask(line: ":x x: :").tags.count, 0)
        }
        check("unknown tags are kept, in order, with duplicates") {
            let t = TodoTask(line: "Thing foo:bar zap:1 foo:baz")
            expectEqual(t.tags.map(\.key), ["foo", "zap", "foo"])
            expectEqual(t.tag("foo"), "bar")
        }
        check("URLs in text are not tags (decision 1)") {
            let t = TodoTask(line: "Read https://example.com/a?b=c and mailto:x@y.z")
            expectEqual(t.tags.map(\.key), ["mailto"])
            expect(t.displayText.contains("https://example.com/a?b=c"))
        }
        check("a full-width colon is not a separator") {
            expectEqual(TodoTask(line: "a：b").tags.count, 0)
        }
        check("displayText hides tags but keeps projects and contexts") {
            expectEqual(TodoTask(line: "(A) Call +Mom @phone due:2026-01-01").displayText, "Call +Mom @phone")
        }
    }
}

@MainActor func leniencyChecks() {
    suite("Liberal reading (Postel's Law)") {
        check("date before priority") {
            let t = TodoTask(line: "2011-03-01 (A) Call Mom")
            expectEqual(t.priority, Priority("A"))
            expectEqual(t.creationDate, d("2011-03-01"))
            expectEqual(t.body, "Call Mom")
        }
        check("completed with a priority in the prefix") {
            let t = TodoTask(line: "x (A) 2011-03-02 2011-03-01 Call Mom")
            expect(t.isCompleted)
            expectEqual(t.priority, Priority("A"))
            expectEqual(t.completionDate, d("2011-03-02"))
            expectEqual(t.creationDate, d("2011-03-01"))
        }
        check("extra spaces, tabs and leading whitespace") {
            let t = TodoTask(line: "  (B)\t 2020-01-01   Spaced   out ")
            expectEqual(t.priority, Priority("B"))
            expectEqual(t.creationDate, d("2020-01-01"))
            expectEqual(t.body, "Spaced   out ")
        }
        check("liberal lines are still written back unchanged") {
            let raw = "2011-03-01 (A)  Call Mom"
            expectEqual(TodoTask(line: raw).line, raw)
        }
        check("a changed liberal line is written in canonical order") {
            var t = TodoTask(line: "2011-03-01 (A)  Call Mom")
            t.setPriority(Priority("B"))
            expectEqual(t.line, "(B) 2011-03-01 Call Mom")
        }
    }
}

@MainActor func roundTripChecks() {
    suite("Round-trip without loss") {
        let samples: [String] = [
            "",
            "one line no newline",
            "(A) a\n\n  \nx 2011-03-02 b\n",
            "(A) a\r\nb\r\n",
            "mixed\r\nendings\nhere\r\n",
            "\n\n\n",
            "(b) odd  spacing\t\ttabs   \n(B)->x\nX 2012-01-01 y\nxylophone\n",
            "emoji 🏠 +家 @café 👨‍👩‍👧 due:2026-01-01 κλειδί:τιμή\n",
        ]
        for (i, s) in samples.enumerated() {
            check("sample \(i) is byte-identical") {
                let data = Data(s.utf8)
                expectEqual(try TodoFile(data: data).data, data)
            }
        }
        check("BOM is kept") {
            let data = Data([0xEF, 0xBB, 0xBF]) + Data("(A) x\n".utf8)
            let f = try TodoFile(data: data)
            expect(f.hasBOM)
            expectEqual(f.tasks.first?.priority, Priority("A"))
            expectEqual(f.data, data)
        }
        check("invalid UTF-8 is refused, not mangled") {
            var threw = false
            do { _ = try TodoFile(data: Data([0x61, 0xFF, 0x0A])) } catch { threw = true }
            expect(threw)
        }
        check("editing one line leaves every other line byte-identical") {
            let text = "(b) keep  me\r\n2011-03-01 (A)  odd\r\nlast"
            var f = TodoFile(text: text)
            f.tasks[1].setPriority(nil)
            expectEqual(f.text, "(b) keep  me\r\n2011-03-01 odd\r\nlast")
        }
        check("append to a file with no final newline") {
            var f = TodoFile(text: "a")
            f.append(TodoTask(line: "b"))
            expectEqual(f.text, "a\nb\n")
        }
        check("append to a CRLF file uses CRLF") {
            var f = TodoFile(text: "a\r\nb\r\n")
            f.append(TodoTask(line: "c"))
            expectEqual(f.text, "a\r\nb\r\nc\r\n")
        }
        check("IDs carry over across reloads; duplicates pair one to one") {
            let old = TodoFile(text: "a\nb\na\n")
            let new = TodoFile(text: "a\nNEW\nb\na\n").adoptingIdentities(from: old)
            expectEqual(new.tasks[0].id, old.tasks[0].id)
            expectEqual(new.tasks[2].id, old.tasks[1].id)
            expectEqual(new.tasks[3].id, old.tasks[2].id)
            expect(!old.tasks.map(\.id).contains(new.tasks[1].id))
        }
    }
}
