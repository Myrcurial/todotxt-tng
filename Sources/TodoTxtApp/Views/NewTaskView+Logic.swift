import SwiftUI
import TodoTxtCore

extension NewTaskView {
    /// Letters already used first, then A–D, then the rest of the alphabet.
    var priorityChoices: [String] {
        let used = vocabulary.priorities.map(\.description)
        let common = Self.merge(used, ["A", "B", "C", "D"]).sorted()
        return common + Self.letters.filter { !common.contains($0) }
    }

    static let letters = (65...90).map { String(UnicodeScalar($0)!) }

    static func merge(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set<String>()
        return (a + b).filter { seen.insert($0).inserted }
    }

    /// Everything outside `draft` that feeds it, so one onChange keeps it in sync.
    var fieldsSnapshot: [String] {
        [priorityText, "\(hasCreated)\(created)", "\(hasDue)\(due)", "\(hasThreshold)\(threshold)"]
            + tags.map { "\($0.key)\u{1}\($0.value)" }
    }

    func sync() {
        draft.priority = Priority(priorityText)
        draft.creationDate = hasCreated ? TaskDate.from(created) : nil
        draft.due = hasDue ? TaskDate.from(due) : nil
        draft.threshold = hasThreshold ? TaskDate.from(threshold) : nil
        draft.tags = tags.filter { !$0.key.isEmpty || !$0.value.isEmpty }.map { .init(key: $0.key, value: $0.value) }
    }

    func save() {
        sync()
        guard draft.isValid else { return }
        model.add(draft.line, addCreationDate: false)
        if model.errorMessage == nil { dismiss() }
    }
}
