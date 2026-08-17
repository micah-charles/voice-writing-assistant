import SwiftUI

@main
struct VoiceWritingAssistantApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Voice Writing Assistant", systemImage: state.menuBarSymbol) {
            MenuBarView()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.menu)
        WindowGroup("History", id: "history") { HistoryView().environmentObject(state).frame(minWidth: 520, minHeight: 360) }
        WindowGroup("Personal Dictionary", id: "dictionary") { DictionaryView().environmentObject(state).frame(minWidth: 520, minHeight: 360) }

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 540, height: 620)
        }
    }
}
