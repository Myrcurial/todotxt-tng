import Foundation
import TodoTxtCore

@MainActor func extensionChecks() {
    suite("Extensions: dates, recurrence, URI encoding, add command") {
        check("date maths") {
            expectEqual(d("2024-01-31").adding(months: 1), d("2024-02-29"))
            expectEqual(d("2023-12-31").adding(days: 1), d("2024-01-01"))
            expectEqual(TaskDate(dayNumber: d("2011-03-02").dayNumber), d("2011-03-02"))
            expectEqual(d("2026-09-28").weekday, 0)  // Monday
        }
        check("today depends on the time zone") {
            let instant = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21T14:13:20Z
            expectEqual(TaskDate.today(in: TimeZone(identifier: "UTC")!, now: instant), d("2026-09-21"))
            expectEqual(TaskDate.today(in: TimeZone(identifier: "Pacific/Kiritimati")!, now: instant), d("2026-09-22"))
        }
        check("recurrence") {
            expectEqual(Recurrence("1w")?.next(after: d("2026-09-28")), d("2026-10-05"))
            expectEqual(Recurrence("+1m")?.strict, true)
            expectEqual(Recurrence("3b")?.next(after: d("2026-10-02")), d("2026-10-07"))  // Fri + 3 business days
            expectEqual(Recurrence("0d"), nil)
            expectEqual(Recurrence("w"), nil)
        }
        check("URI tag encoding round-trips, with no ASCII colon") {
            for uri in ["https://ex.com/a?b=c;d%20e", "message://%3Cabc@mail%3E", "mailto:a@b.c"] {
                let enc = TagValue.encodeURI(uri)
                expect(!enc.contains(":") && !enc.contains(where: \.isWhitespace), "encoded: \(enc)")
                expectEqual(TagValue.decodeURI(enc), uri)
            }
            expectEqual(TagValue.encodeURI("https://ex.com"), "https;//ex.com")
        }
        check("the add command adds a creation date and keeps the user's priority") {
            let t = AddTaskCommand(text: "(A) Call Mom @phone").makeTask(today: d("2026-09-28"))
            expectEqual(t?.line, "(A) 2026-09-28 Call Mom @phone")
        }
        check("the add command flattens newlines and rejects empty input") {
            expectEqual(AddTaskCommand(text: "a\nb", addCreationDate: false).makeTask(today: d("2026-01-01"))?.line, "a b")
            expect(AddTaskCommand(text: "  \n ").makeTask(today: d("2026-01-01")) == nil)
        }
        check("the add command stores source and message as safe tags") {
            let t = AddTaskCommand(text: "Reply", sourceURI: "https://x.io/p", messageID: "<a1@mail.x>",
                                   addCreationDate: false).makeTask(today: d("2026-01-01"))!
            expectEqual(t.tag("src"), "https;//x.io/p")
            expectEqual(t.sourceURL, URL(string: "https://x.io/p"))
            expectEqual(t.messageID, "<a1@mail.x>")
            expectEqual(TodoTask(line: t.line).tags.count, 2)
        }
    }
}

@MainActor func queryChecks() {
    suite("Queries and views") {
        let today = d("2026-09-28")
        let f = TodoFile(text: """
        (B) b due:2026-09-27
        (A) a due:2026-09-30
        c due:2026-09-28 +p @x
        hidden t:2026-10-10
        x 2026-09-20 2026-09-10 done
        x 2026-09-25 done2 pri:A

        """)
        check("due buckets") {
            let b = f.tasks.map { TaskFilter.bucket(for: $0, today: today) }
            expectEqual(b[0], .overdue); expectEqual(b[1], .upcoming)
            expectEqual(b[2], .today); expectEqual(b[3], .noDate)
        }
        check("open filter hides completed and future-threshold tasks") {
            expectEqual(f.tasks.filter { TaskFilter().matches($0, today: today) }.count, 3)
            expectEqual(f.tasks.filter { TaskFilter(includeHidden: true).matches($0, today: today) }.count, 4)
        }
        check("project, context and search filters") {
            expectEqual(f.tasks.filter { TaskFilter(projects: ["p"], contexts: ["x"]).matches($0, today: today) }.count, 1)
            expectEqual(f.tasks.filter { TaskFilter(status: .any, search: "DONE").matches($0, today: today) }.count, 2)
        }
        check("sorting by priority then due; completed most recent first") {
            let open = f.tasks.filter { TaskFilter().matches($0, today: today) }
            expectEqual(TaskSort.byPriority(open).map(\.body.first), ["a", "b", "c"])
            expectEqual(TaskSort.byDue(open).map(\.body.first), ["b", "c", "a"])
            let done = f.tasks.filter { TaskFilter(status: .completed).matches($0, today: today) }
            expectEqual(TaskSort.byCompletion(done).map(\.body), ["done2 pri:A", "done"])
            expectEqual(done.first?.daysToComplete, 10)
        }
        check("project counts include only open tasks") {
            expectEqual(TaskSort.counts(f.tasks, \.projects).map(\.name), ["p"])
        }
    }
}
