import SwiftUI

struct FloatingControlView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            recordButton
            if state.floatingMenuVisible { Divider().frame(height: 250); FloatingQuickMenu() }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .onHover { state.setFloatingMenuHover($0) }
    }

    private var recordButton: some View {
        Button { Task { await state.toggleFloatingDictation() } } label: {
            Image(systemName: state.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white).frame(width: 58, height: 58)
                .background(state.isRecording ? Color.red : Color.orange, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1))
                .shadow(color: state.isRecording ? .red.opacity(0.55) : .black.opacity(0.28), radius: state.isRecording ? 10 : 5)
        }
        .buttonStyle(.plain).help(state.isRecording ? "Stop recording" : "Start recording")
        .contextMenu { Button("Settings…") { state.showSettings() }; Toggle("Show floating record button", isOn: $state.settings.showFloatingControl); Divider(); Button("Quit Voice Writing Assistant") { NSApplication.shared.terminate(nil) } }
        .accessibilityLabel(state.isRecording ? "Stop recording" : "Start recording")
    }
}
