import SwiftUI

@main
struct ProtokolApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Process Audio Files...") {
                    appState.showFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
