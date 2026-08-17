import SwiftUI

struct RecorderView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: state.menuBarSymbol).font(.system(size: 54)).foregroundStyle(.tint)
            Text(state.statusText).font(.title3).multilineTextAlignment(.center)
            if state.dictationState == .recording {
                ProgressView(value: Double(state.audioLevel), total: 1).frame(width: 220)
                Text(state.elapsedText).monospacedDigit().foregroundStyle(.secondary)
            }
            HStack {
                Button(state.dictationState == .recording ? "Stop" : "Start") { Task { state.dictationState == .recording ? await state.finishRecording() : await state.beginDictation() } }
                    .disabled(state.dictationState != .recording && !state.dictationState.canStart)
                Button("Cancel") { state.cancel() }.disabled(!state.dictationState.isBusy)
            }
            if !state.processedText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Processed text").font(.headline)
                    Text(state.processedText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(state.processingProvider) · \(Int(state.processingLatency * 1000)) ms").font(.footnote).foregroundStyle(.secondary)
                    if state.dictationState == .awaitingReview { HStack { Button("Paste") { Task { await state.pasteReviewedText() } }; Button("Use Raw") { Task { await state.useRawText() } }; Button("Cancel") { state.cancel() } } }
                }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            Text("Dictate: hold Control + Option + R  •  Transform selected text: hold Control + Option + E").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(32)
    }
}
