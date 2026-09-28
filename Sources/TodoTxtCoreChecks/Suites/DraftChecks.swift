import TodoTxtCore

@MainActor func draftChecks() {
    suite("New Task draft and vocabulary") {
        check("every field produces a spec-standard line that parses back") {
            var dr = TaskDraft()
            dr.text = "Call Mom"
            dr.priority = Priority("A")
            dr.creationDate = d("2026-09-28")
            dr.due = d("2026-10-01")
            dr.threshold = d("2026-09-30")
            dr.recurrence = "1w"
            dr.projects = ["Family"]
            dr.contexts = ["phone"]
            dr.tags = [.init(key: "est", value: "15m")]
            expect(dr.isValid, "\(dr.problems)")
            expectEqual(dr.line, "(A) 2026-09-28 Call Mom +Family @phone due:2026-10-01 t:2026-09-30 rec:1w est:15m")
            let t = dr.task
            expectEqual(t.priority, Priority("A"))
            expectEqual(t.projects, ["Family"])
            expectEqual(t.dueDate, d("2026-10-01"))
            expectEqual(t.recurrence?.description, "1w")
            expectEqual(t.tag("est"), "15m")
        }
        check("projects typed in the text aren't repeated; duplicates and blanks dropped") {
            var dr = TaskDraft()
            dr.text = "Plan +Trip"
            dr.projects = ["Trip", " ", "Trip", "Work"]
            expectEqual(dr.line, "Plan +Trip +Work")
        }
        check("problems are reported") {
            var dr = TaskDraft()
            expect(dr.problems.contains("Description is empty"))
            dr.text = "x"
            dr.projects = ["two words"]
            dr.recurrence = "weekly"
            dr.due = d("2026-01-01"); dr.threshold = d("2026-02-01")
            dr.tags = [.init(key: "a", value: "b:c"), .init(key: "due", value: "2026-01-01")]
            expectEqual(dr.problems.count, 5)
        }
        check("unicode values work") {
            var dr = TaskDraft()
            dr.text = "Onsen ♨️"
            dr.projects = ["旅行"]
            dr.contexts = ["🏠"]
            expectEqual(dr.task.projects, ["旅行"])
            expectEqual(dr.task.contexts, ["🏠"])
        }
        check("vocabulary lists used values, most-used first") {
            let f = TodoFile(text: """
            (B) a +Work @desk est:1h rec:1w
            (A) b +Home @desk est:30m
            c +Work @phone src:x due:2026-01-01
            x 2026-01-01 d +Work pri:C

            """)
            let v = TaskVocabulary(tasks: f.tasks)
            expectEqual(v.projects, ["Work", "Home"])
            expectEqual(v.contexts, ["desk", "phone"])
            expectEqual(v.priorities.map(\.description), ["A", "B", "C"])
            expectEqual(v.recurrences, ["1w"])
            expectEqual(v.tagKeys, ["est", "src"])
            expectEqual(v.tagValues["est"] ?? [], ["1h", "30m"])
        }
    }
}
