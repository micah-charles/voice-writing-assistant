import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice Writing Assistant").font(.headline)
            Text(state.statusText).foregroundStyle(.secondary)
            Divider()
            Text("Fast flow: hold ⌃R, speak, then release R. Toggle mode: press ⌃R again to stop.").font(.caption).foregroundStyle(.secondary)
            Button("Start Dictation") { Task { await state.beginDictation() } }.disabled(!state.dictationState.canStart)
            Button("Stop & Paste") { Task { await state.finishRecording() } }.disabled(state.dictationState != .recording)
            Button("Transform Selected Text") { Task { await state.beginSelectedTextTransform() } }.disabled(!state.dictationState.canStart)
            Button("Cancel") { state.cancel() }.disabled(!state.dictationState.isBusy)
            if !state.rawTranscript.isEmpty { Divider(); Text("Last transcript").font(.caption).foregroundStyle(.secondary); Text(state.rawTranscript).lineLimit(3) }
            if !state.lastPasteMethod.isEmpty { Text(state.lastPasteMethod).font(.caption).foregroundStyle(.secondary) }
            Button("History") { openWindow(id: "history") }
            Button("Personal Dictionary") { openWindow(id: "dictionary") }
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit Voice Writing Assistant") { NSApplication.shared.terminate(nil) }
        }.padding(12).frame(width: 310)
    }
}
