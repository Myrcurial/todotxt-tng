import TodoTxtCore

// Cases taken from the spec: https://github.com/todotxt/todo.txt/blob/master/README.md

@MainActor func specProjectContextChecks() {
    suite("Spec: Rule 3 — contexts and projects") {
        check("multiple projects and contexts") {
            let t = TodoTask(line: "(A) Call Mom +Family +PeaceLoveAndHappiness @iphone @phone")
            expectEqual(t.projects, ["Family", "PeaceLoveAndHappiness"])
            expectEqual(t.contexts, ["iphone", "phone"])
        }
        check("email addresses are not contexts") {
            expectEqual(TodoTask(line: "Email SoAndSo at soandso@example.com").contexts, [])
        }
        check("2+2 is not a project") {
            expectEqual(TodoTask(line: "Learn how to add 2+2").projects, [])
        }
        check("lone + or @ is plain text") {
            let t = TodoTask(line: "a + b @ c")
            expectEqual(t.projects, [])
            expectEqual(t.contexts, [])
        }
        check("names may contain any non-whitespace, including punctuation") {
            let t = TodoTask(line: "x+y +a.b-c/d @home:office @@x")
            expectEqual(t.projects, ["a.b-c/d"])
            expectEqual(t.contexts, ["home:office", "@x"])
        }
        check("tab counts as whitespace before a context") {
            expectEqual(TodoTask(line: "call\t@phone").contexts, ["phone"])
        }
        check("context at column 1 counts (decision 3)") {
            let t = TodoTask(line: "@phone call Bob +Work")
            expectEqual(t.contexts, ["phone"])
            expectEqual(t.projects, ["Work"])
        }
        check("the example file") {
            let f = TodoFile(text: """
            (A) Thank Mom for the meatballs @phone
            (B) Schedule Goodwill pickup +GarageSale @phone
            Post signs around the neighborhood +GarageSale
            @GroceryStore Eskimo pies

            """)
            let garage = f.tasks.filter { $0.projects.contains("GarageSale") }.map(\.line)
            expectEqual(garage, ["(B) Schedule Goodwill pickup +GarageSale @phone",
                                 "Post signs around the neighborhood +GarageSale"])
            expectEqual(f.tasks.filter { $0.contexts.contains("phone") }.count, 2)
            expectEqual(f.tasks[3].contexts, ["GroceryStore"])
        }
    }
}

@MainActor func specCompletionChecks() {
    suite("Spec: completed tasks") {
        check("x 2011-03-03 Call Mom is complete") {
            let t = TodoTask(line: "x 2011-03-03 Call Mom")
            expect(t.isCompleted)
            expectEqual(t.completionDate, d("2011-03-03"))
            expectEqual(t.creationDate, nil)
            expectEqual(t.body, "Call Mom")
        }
        check("xylophone lesson is not complete") {
            let t = TodoTask(line: "xylophone lesson")
            expect(!t.isCompleted)
            expectEqual(t.body, "xylophone lesson")
        }
        check("uppercase X is not complete, and its date is not a creation date") {
            let t = TodoTask(line: "X 2012-01-01 Make resolutions")
            expect(!t.isCompleted)
            expectEqual(t.creationDate, nil)
            expectEqual(t.body, "X 2012-01-01 Make resolutions")
        }
        check("(A) x Find ticket prices is not complete") {
            let t = TodoTask(line: "(A) x Find ticket prices")
            expect(!t.isCompleted)
            expectEqual(t.priority, Priority("A"))
            expectEqual(t.body, "x Find ticket prices")
        }
        check("completion then creation date") {
            let t = TodoTask(line: "x 2011-03-02 2011-03-01 Review Tim's pull request +TodoTxtTouch @github")
            expect(t.isCompleted)
            expectEqual(t.completionDate, d("2011-03-02"))
            expectEqual(t.creationDate, d("2011-03-01"))
            expectEqual(t.projects, ["TodoTxtTouch"])
            expectEqual(t.contexts, ["github"])
            expectEqual(t.daysToComplete, 1)
        }
        check("x with no date is complete, with no completion date (decision 2)") {
            let t = TodoTask(line: "x Call Mom")
            expect(t.isCompleted)
            expectEqual(t.completionDate, nil)
            expectEqual(t.body, "Call Mom")
        }
        check("a lone x is not complete (no space after it)") {
            expect(!TodoTask(line: "x").isCompleted)
        }
    }
}
