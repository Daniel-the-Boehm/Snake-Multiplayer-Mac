import SwiftUI

@main
struct SnakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Snake", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 520, minHeight: 480)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 900, height: 780)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.toggleSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Game") {
                Button("Restart") { model.menuRestart() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Pause / Resume") { model.togglePause() }
                    .keyboardShortcut("p", modifiers: .command)
                Divider()
                Button("Multiplayer…") { model.openMPMenu() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
