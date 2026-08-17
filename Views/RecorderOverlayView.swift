import SwiftUI

struct RecorderOverlayView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.menuBarSymbol).foregroundStyle(.red).font(.title2)
            VStack(alignment: .leading) { Text(state.statusText).font(.headline); if state.dictationState == .recording { ProgressView(value: Double(state.audioLevel), total: 1).frame(width: 120); Text(state.elapsedText).monospacedDigit().font(.caption) } }
        }.padding(16).frame(width: 270)
    }
}
