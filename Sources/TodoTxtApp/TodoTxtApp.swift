import SwiftUI

/// Not marked @main: `main.swift` is the entry point, so the activation policy can be set first.
struct TodoTxtApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("todotxt-tng", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 720, minHeight: 440)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New todo.txt…") { model.showNewPanel() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Open todo.txt…") { model.showOpenPanel() }
                    .keyboardShortcut("o")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
