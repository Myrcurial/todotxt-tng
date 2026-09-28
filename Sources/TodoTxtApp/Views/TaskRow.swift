import SwiftUI
import TodoTxtCore

struct TaskRow: View {
    @Environment(AppModel.self) private var model
    let task: TodoTask
    let today: TaskDate

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button { model.toggle(task.id) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Mark incomplete" : "Mark complete")

            if let p = task.priority {
                Text(p.description)
                    .font(.caption.weight(.bold).monospaced())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(priorityColor(p).opacity(0.18), in: .capsule)
                    .foregroundStyle(priorityColor(p))
            }

            VStack(alignment: .leading, spacing: 3) {
                styledText
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .textSelection(.enabled)
                metadata
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    /// Description with projects and contexts tinted.
    private var styledText: Text {
        var out = AttributedString()
        for (i, token) in task.tokens.enumerated() {
            if case .tag = token { continue }
            if i > 0, !out.characters.isEmpty { out += AttributedString(" ") }
            var piece = AttributedString(token.text)
            switch token {
            case .project: piece.foregroundColor = .purple
            case .context: piece.foregroundColor = .teal
            default: break
            }
            out += piece
        }
        return Text(out)
    }

    @ViewBuilder private var metadata: some View {
        let items = metadataItems
        if !items.isEmpty {
            HStack(spacing: 10) {
                ForEach(items, id: \.text) { item in
                    Label(item.text, systemImage: item.symbol)
                        .foregroundStyle(item.color)
                }
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)
        }
    }

    private struct Item { let text: String; let symbol: String; let color: Color }

    private var metadataItems: [Item] {
        var items: [Item] = []
        if let due = task.dueDate, !task.isCompleted {
            let days = today.days(until: due)
            let text = switch days {
            case ..<0: "Overdue \(due)"
            case 0: "Today"
            case 1: "Tomorrow"
            default: due.description
            }
            items.append(Item(text: text, symbol: "calendar", color: days < 0 ? .red : days == 0 ? .orange : .secondary))
        }
        if let t = task.thresholdDate, t > today {
            items.append(Item(text: "Starts \(t)", symbol: "eye.slash", color: .secondary))
        }
        if let r = task.recurrence {
            items.append(Item(text: r.description, symbol: "repeat", color: .secondary))
        }
        if task.isCompleted {
            if let c = task.effectiveCompletionDate {
                let inferred = task.completionDate == nil ? " (inferred)" : ""
                items.append(Item(text: "Done \(c)\(inferred)", symbol: "checkmark", color: .secondary))
            }
            if let n = task.daysToComplete {
                items.append(Item(text: n == 0 ? "same day" : n == 1 ? "1 day" : "\(n) days", symbol: "timer", color: .secondary))
            }
        }
        let known: Set = ["due", "t", "rec", "pri", "cal", "src", "msg"]
        for tag in task.tags where !known.contains(tag.key) {
            items.append(Item(text: "\(tag.key): \(tag.value)", symbol: "tag", color: .secondary))
        }
        if task.sourceURL != nil { items.append(Item(text: "link", symbol: "link", color: .blue)) }
        if task.messageID != nil { items.append(Item(text: "mail", symbol: "envelope", color: .secondary)) }
        return items
    }

    private func priorityColor(_ p: Priority) -> Color {
        switch p.letter {
        case "A": .red
        case "B": .orange
        case "C": .yellow
        default: .blue
        }
    }
}
