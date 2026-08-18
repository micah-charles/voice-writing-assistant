import SwiftUI

struct FloatingControlView: View {
    @EnvironmentObject private var state: AppState
    @State private var isPressing = false
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if state.floatingMenuVisible {
                    FloatingQuickMenu()
                        .frame(width: min(proxy.size.width - 16, 450), height: min(proxy.size.height - 16, 450))
                }
                recordButton
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .onHover { state.setFloatingMenuHover($0) }
    }

    private var recordButton: some View {
        ZStack(alignment: .topTrailing) {
            Circle().fill(state.isRecording ? Color.red.opacity(0.28) : Color.orange.opacity(0.12))
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
            .onChanged { _ in
                guard !isPressing else { return }
                isPressing = true
                guard !state.floatingMenuVisible else { return }
                Task { await state.beginFloatingPushToTalk() }
            }
            .onEnded { _ in
                isPressing = false
                if state.floatingMenuVisible {
                    state.closeFloatingMenu()
                } else {
                    Task { await state.finishFloatingPushToTalk() }
                }
            })
        .help(state.isRecording ? "Release to stop recording" : "Hold to talk")
        .contextMenu { Button("Settings…") { state.showSettings() }; Toggle("Show floating record button", isOn: $state.settings.showFloatingControl); Divider(); Button("Quit Voice Writing Assistant") { NSApplication.shared.terminate(nil) } }
        .accessibilityLabel(state.isRecording ? "Release to stop recording" : "Hold to talk")
    }
}
