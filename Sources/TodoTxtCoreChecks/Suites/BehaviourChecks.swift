import Foundation
import TodoTxtCore

@MainActor func mutationChecks() {
    suite("Completing and editing") {
        check("complete moves priority into pri:") {
            var t = TodoTask(line: "(A) 2011-03-01 Call Mom @phone")
            t.complete(on: d("2011-03-05"))
            expectEqual(t.line, "x 2011-03-05 2011-03-01 Call Mom @phone pri:A")
            expectEqual(t.daysToComplete, 4)
        }
        check("uncomplete restores priority from pri:") {
            var t = TodoTask(line: "x 2011-03-05 2011-03-01 Call Mom @phone pri:A")
            t.uncomplete()
            expectEqual(t.line, "(A) 2011-03-01 Call Mom @phone")
        }
        check("complete and uncomplete gives back the original line") {
            let raw = "(C) 2020-02-02 Thing +p @c due:2020-03-01 zz:top"
            var t = TodoTask(line: raw)
            t.complete(on: d("2020-02-10"))
            t.uncomplete()
            expectEqual(t.line, raw)
        }
        check("an existing pri: tag is not doubled") {
            var t = TodoTask(line: "(A) x pri:A")
            t.complete(on: d("2020-01-01"))
            expectEqual(t.line, "x 2020-01-01 x pri:A")
        }
        check("completing a task that has no creation date") {
            var t = TodoTask(line: "Buy milk")
            t.complete(on: d("2020-01-01"))
            expectEqual(t.line, "x 2020-01-01 Buy milk")
        }
        check("the result re-parses to the same fields") {
            var t = TodoTask(line: "(A) 2011-03-01 Call Mom")
            t.complete(on: d("2011-03-05"))
            let r = TodoTask(line: t.line)
            expect(r.isCompleted)
            expectEqual(r.completionDate, d("2011-03-05"))
            expectEqual(r.creationDate, d("2011-03-01"))
            expectEqual(r.tag("pri"), "A")
        }
        check("setTag replaces in place; removeTag removes") {
            var t = TodoTask(line: "Thing due:2020-01-01 +p")
            t.setTag("due", "2021-01-01")
            expectEqual(t.line, "Thing due:2021-01-01 +p")
            t.removeTag("due")
            expectEqual(t.line, "Thing +p")
        }
        check("serializer: a completed task with only a creation date drops it (no completion date to anchor it)") {
            let t = TodoTask(line: "x Call Mom")
            expect(t.isCompleted)
            expectEqual(t.line, "x Call Mom")
        }
    }
}

@MainActor func unicodeChecks() {
    suite("Unicode and emoji") {
        check("emoji and non-Latin projects and contexts") {
            let t = TodoTask(line: "Plan trip +🏖️ @東京 +Café")
            expectEqual(t.projects, ["🏖️", "Café"])
            expectEqual(t.contexts, ["東京"])
        }
        check("combined emoji stay one character") {
            let t = TodoTask(line: "Call +👨‍👩‍👧 fam")
            expectEqual(t.projects, ["👨‍👩‍👧"])
        }
        check("non-breaking and ideographic spaces separate words") {
            let t = TodoTask(line: "a\u{00A0}@nbsp b\u{3000}+wide")
            expectEqual(t.contexts, ["nbsp"])
            expectEqual(t.projects, ["wide"])
        }
        check("non-ASCII tag keys and values") {
            expectEqual(TodoTask(line: "x κλειδί:τιμή").tag("κλειδί"), "τιμή")
        }
        check("precomposed and decomposed é are both kept exactly") {
            let a = "Caf\u{00E9} +caf\u{00E9}", b = "Cafe\u{0301} +cafe\u{0301}"
            expectEqual(Array(TodoTask(line: a).line.utf8), Array(a.utf8))
            expectEqual(Array(TodoTask(line: b).line.utf8), Array(b.utf8))
        }
    }
}
