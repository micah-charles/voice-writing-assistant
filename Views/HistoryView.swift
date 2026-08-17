import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedID: UUID?
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text("History").font(.title2); Spacer(); Button("Clear History", role: .destructive) { Task { await state.clearHistory() } }.disabled(state.history.isEmpty) }
            if state.history.isEmpty { ContentUnavailableView("No local history", systemImage: "clock", description: Text("Enable Store transcription history in Settings to retain completed dictations.")) }
            else {
                HStack(spacing: 0) {
                    List(state.history, selection: $selectedID) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preview(entry.processedText)).lineLimit(2)
                            Text("\(entry.provider)\(entry.latency.map { String(format: " · %.1fs", $0) } ?? "") · \(entry.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }.tag(entry.id)
                    }.frame(minWidth: 340)
                    Divider()
                    if let entry = state.history.first(where: { $0.id == selectedID }) ?? state.history.first {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("\(entry.provider)\(entry.latency.map { String(format: " · %.1fs", $0) } ?? "")").font(.headline)
                                Text("\(entry.mode.displayName) · \(entry.activeApplication ?? "Unknown app") · \(entry.date.formatted())").font(.caption).foregroundStyle(.secondary)
                                Group { Text("Spoken transcript").font(.caption).foregroundStyle(.secondary); Text(entry.rawTranscript).textSelection(.enabled) }
                                Divider()
                                Group { Text("Final text").font(.caption).foregroundStyle(.secondary); Text(entry.processedText).textSelection(.enabled) }
                                if let alternatives = entry.alternativeResults, !alternatives.isEmpty {
                                    Divider()
                                    Text("Other AI results").font(.caption).foregroundStyle(.secondary)
                                    ForEach(Array(alternatives.enumerated()), id: \.offset) { _, result in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(result.provider) · \(String(format: "%.1fs", result.latency))").font(.subheadline.weight(.medium))
                                            Text(result.text).textSelection(.enabled)
                                        }
                                    }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding()
                        }.frame(minWidth: 360)
                    }
                }
            }
        }.padding()
    }

    private func preview(_ text: String, wordLimit: Int = 24) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        let result = words.prefix(wordLimit).joined(separator: " ")
        return words.count > wordLimit ? result + "…" : result
    }
}
