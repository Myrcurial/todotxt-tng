import Foundation
import TodoTxtCore

@MainActor func normalizeChecks() {
    suite("Rewrite in standard format") {
        check("a messy file becomes spec-standard") {
            let data = Data([0xEF, 0xBB, 0xBF]) + Data("""
              2011-03-01 (A)  Call   Mom\t@phone \r\n\r\nx (B) 2011-03-02 Done thing\r\n(b) not a priority\r\nlast
              """.utf8)
            let f = try TodoFile(data: data).normalized()
            expectEqual(f.data, Data("""
            (A) 2011-03-01 Call Mom @phone
            x 2011-03-02 Done thing pri:B
            (b) not a priority
            last

            """.utf8))
        }
        check("the result is stable: normalizing twice changes nothing") {
            let once = TodoFile(text: "  x  2020-01-01  a \n(A)  b\n").normalized()
            expectEqual(TodoFile(text: once.text).normalized().text, once.text)
            expectEqual(TodoFile(text: once.text).normalizationChanges.lines, 0)
            expect(!TodoFile(text: once.text).normalizationChanges.fileFormat)
        }
        check("counts the lines that would change") {
            let c = TodoFile(text: "(A) ok\n2020-01-01 (B) x\n\nfine\r\n").normalizationChanges
            expectEqual(c.lines, 2)
            expect(c.fileFormat)
        }
        check("unknown tags, URLs, Unicode and the spec's non-priority cases stay the same") {
            let lines = ["(B)->Submit TPS report", "xylophone lesson", "X 2012-01-01 Make resolutions",
                         "Read https://ex.com a:b:c zz:top +🏠 @東京"]
            for l in lines { expectEqual(TodoTask(line: l).normalized().line, l) }
        }
        check("an inferred completion date is not written") {
            var t = TodoTask(line: "x  no date")
            t.inferredCompletionDate = d("2026-01-01")
            expectEqual(t.normalized().line, "x no date")
        }
        check("the store rewrites the file on disk") {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tt-norm-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("todo.txt")
            try Data("2020-01-01 (A)  a\r\n\r\nb".utf8).write(to: url)
            let s = try TodoStore(url: url, watch: false)
            try s.rewriteInStandardFormat()
            expectEqual(try String(contentsOf: url, encoding: .utf8), "(A) 2020-01-01 a\nb\n")
            expectEqual(s.file.normalizationChanges.lines, 0)
        }
    }
}
