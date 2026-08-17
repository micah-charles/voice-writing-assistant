import SwiftUI

struct FloatingControlView: View {
    @EnvironmentObject private var state: AppState
    @State private var isPressing = false
    @State private var pulse = false

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
        ZStack(alignment: .topTrailing) {
            Circle().fill(state.isRecording ? Color.red.opacity(0.28) : Color.orange.opacity(0.22))
                .scaleEffect(state.isRecording && pulse ? 1.18 : 1)
            Image("FoxR").resizable().scaledToFit().padding(2)
            Image(systemName: state.floatingStatusSymbol)
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                .padding(5).background(state.isRecording ? .red : .black.opacity(0.6), in: Circle())
                .offset(x: 3, y: -3)
        }
        .frame(width: 58, height: 58)
        .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 1))
        .shadow(color: state.isRecording ? .red.opacity(0.55) : .black.opacity(0.3), radius: state.isRecording ? 11 : 5)
        .onAppear { pulse = state.isRecording }
        .onChange(of: state.isRecording) { _, recording in withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = recording } }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in guard !isPressing else { return }; isPressing = true; Task { await state.beginFloatingPushToTalk() } }
            .onEnded { _ in isPressing = false; Task { await state.finishFloatingPushToTalk() } })
        .help(state.isRecording ? "Release to stop recording" : "Hold to talk")
        .contextMenu { Button("Settings…") { state.showSettings() }; Toggle("Show floating record button", isOn: $state.settings.showFloatingControl); Divider(); Button("Quit Voice Writing Assistant") { NSApplication.shared.terminate(nil) } }
        .accessibilityLabel(state.isRecording ? "Release to stop recording" : "Hold to talk")
    }
}
