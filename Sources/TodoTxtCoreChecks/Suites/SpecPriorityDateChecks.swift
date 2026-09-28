import TodoTxtCore

// Cases taken from the spec: https://github.com/todotxt/todo.txt/blob/master/README.md

func d(_ s: String) -> TaskDate { TaskDate(s)! }

@MainActor func specPriorityChecks() {
    suite("Spec: Rule 1 — priority comes first") {
        check("(A) Call Mom has priority A") {
            let t = TodoTask(line: "(A) Call Mom")
            expectEqual(t.priority, Priority("A"))
            expectEqual(t.body, "Call Mom")
        }
        check("priority not at the start is ignored") {
            let t = TodoTask(line: "Really gotta call Mom (A) @phone @someday")
            expectEqual(t.priority, nil)
            expectEqual(t.contexts, ["phone", "someday"])
        }
        check("lowercase (b) is not a priority") {
            let t = TodoTask(line: "(b) Get back to the boss")
            expectEqual(t.priority, nil)
            expectEqual(t.body, "(b) Get back to the boss")
        }
        check("(B)-> without a space is not a priority") {
            let t = TodoTask(line: "(B)->Submit TPS report")
            expectEqual(t.priority, nil)
            expectEqual(t.body, "(B)->Submit TPS report")
        }
        check("every letter A–Z is accepted") {
            for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
                expectEqual(TodoTask(line: "(\(c)) task").priority?.letter, c)
            }
        }
        check("non-letters, digits and non-ASCII letters are not priorities") {
            for s in ["(1) x", "(AA) x", "() x", "(É) x", "(Ａ) x", "[A] x"] {
                expectEqual(TodoTask(line: s).priority, nil)
            }
        }
        check("priority alone on a line") {
            let t = TodoTask(line: "(A)")
            expectEqual(t.priority, Priority("A"))
            expectEqual(t.body, "")
        }
    }
}

@MainActor func specDateChecks() {
    suite("Spec: Rule 2 — creation date") {
        check("date first when there is no priority") {
            let t = TodoTask(line: "2011-03-02 Document +TodoTxt task format")
            expectEqual(t.creationDate, d("2011-03-02"))
            expectEqual(t.projects, ["TodoTxt"])
        }
        check("date directly after priority") {
            let t = TodoTask(line: "(A) 2011-03-02 Call Mom")
            expectEqual(t.priority, Priority("A"))
            expectEqual(t.creationDate, d("2011-03-02"))
            expectEqual(t.body, "Call Mom")
        }
        check("trailing date is not a creation date") {
            let t = TodoTask(line: "(A) Call Mom 2011-03-02")
            expectEqual(t.creationDate, nil)
            expectEqual(t.body, "Call Mom 2011-03-02")
        }
        check("invalid calendar dates are not dates") {
            for s in ["2011-02-30 x", "2011-13-01 x", "2011-3-2 x", "20110302 x", "2011-03-02x"] {
                expectEqual(TodoTask(line: s).creationDate, nil)
            }
            expectEqual(TodoTask(line: "2012-02-29 leap").creationDate, d("2012-02-29"))
            expectEqual(TodoTask(line: "1900-02-29 x").creationDate, nil)
        }
        check("an incomplete task takes only one prefix date") {
            let t = TodoTask(line: "2011-03-02 2011-03-01 odd")
            expectEqual(t.creationDate, d("2011-03-02"))
            expectEqual(t.body, "2011-03-01 odd")
        }
    }
}
