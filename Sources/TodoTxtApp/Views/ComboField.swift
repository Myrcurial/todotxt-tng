import SwiftUI

/// A text field with a dropdown of existing values. Pick one, or type a new one.
struct ComboField: View {
    let title: String
    @Binding var text: String
    let options: [String]
    var prompt: String = ""

    var body: some View {
        HStack(spacing: 4) {
            TextField(title, text: $text, prompt: Text(prompt))
                .labelsHidden()
                .accessibilityLabel(title)
            Menu {
                if options.isEmpty {
                    Text("None used yet")
                } else {
                    ForEach(options, id: \.self) { o in Button(o) { text = o } }
                }
            } label: {
                Image(systemName: "chevron.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("\(title) options")
        }
    }
}

/// A list of values (projects or contexts). Existing values are one click; new ones are typed.
struct TokenListField: View {
    let title: String
    let sigil: String
    @Binding var values: [String]
    let options: [String]
    @State private var entry = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !values.isEmpty {
                FlowRow(values, id: \.self) { v in
                    HStack(spacing: 3) {
                        Text(sigil + v)
                        Button { values.removeAll { $0 == v } } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(sigil)\(v)")
                    }
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)
                }
            }
            HStack(spacing: 4) {
                TextField(title, text: $entry, prompt: Text("Add \(title.lowercased())…"))
                    .labelsHidden()
                    .accessibilityLabel("New \(title.lowercased())")
                    .focused($focused)
                    .onSubmit(commit)
                    // Typed-but-not-added text is kept when focus moves (e.g. to Add Task).
                    .onChange(of: focused) { _, now in if !now { commit() } }
                Menu {
                    let remaining = options.filter { !values.contains($0) }
                    if remaining.isEmpty { Text("None used yet") }
                    ForEach(remaining, id: \.self) { o in Button(sigil + o) { values.append(o) } }
                } label: { Image(systemName: "chevron.down") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("\(title) options")
                Button("Add", action: commit).disabled(clean.isEmpty)
            }
        }
    }

    private var clean: String {
        var s = entry.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix(sigil) { s.removeFirst() }
        return s
    }

    /// Pending typed text counts too, so Save doesn't drop it.
    func commit() {
        let v = clean
        if !v.isEmpty, !values.contains(v) { values.append(v) }
        entry = ""
    }
}

/// Minimal wrapping row layout for chips.
struct FlowRow<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    let data: Data
    let id: KeyPath<Data.Element, ID>
    let content: (Data.Element) -> Content

    init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.id = id
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: 5) {
            ForEach(data, id: id) { content($0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in arrange(subviews, width: bounds.width).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            points.append(CGPoint(x: x, y: y))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            maxX = max(maxX, x - spacing)
        }
        return (points, CGSize(width: maxX, height: y + rowH))
    }
}
