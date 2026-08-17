import SwiftUI

private enum FlowRoot: String, CaseIterable { case output = "Output language", style = "Writing style", processor = "AI processor", paste = "Paste behaviour", results = "Last results" }
private enum OutputBranch: String, CaseIterable { case preserve = "Preserve spoken language", english = "Translate to English", chinese = "Chinese output  ›" }

/// Hover navigates the cascading menu; a click is needed only to change a final value.
struct FloatingQuickMenu: View {
    @EnvironmentObject private var state: AppState
    @State private var root: FlowRoot = .output
    @State private var outputBranch: OutputBranch = .preserve
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            firstColumn
            Divider().frame(height: 274)
            secondColumn
            if root == .output && outputBranch == .chinese { Divider().frame(height: 274); chineseColumn }
        }
        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var firstColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Quick settings").font(.headline)
            ForEach(FlowRoot.allCases, id: \.self) { item in flowRow(item.rawValue, selected: root == item, chevron: true) { root = item } }
            Divider()
            Button("All settings…") { state.showSettings() }.buttonStyle(.bordered)
        }.frame(width: 170, alignment: .leading)
    }

    @ViewBuilder private var secondColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(root.rawValue).font(.headline)
            switch root {
            case .output:
                ForEach(OutputBranch.allCases, id: \.self) { item in
                    flowRow(item.rawValue, selected: outputBranch == item, chevron: item == .chinese) { outputBranch = item }
                        .onTapGesture { if item == .preserve { state.settings.outputLanguage = .preserveSpokenLanguage }; if item == .english { state.settings.outputLanguage = .english } }
                }
            case .style:
                ForEach(ProcessingStyle.allCases) { item in finalRow(item.displayName, selected: state.settings.processingStyle == item) { state.settings.processingStyle = item } }
            case .processor:
                ForEach(TextProcessorProvider.allCases) { item in finalRow(item.displayName, selected: state.settings.selectedTextProcessor == item) { state.settings.selectedTextProcessor = item } }
            case .paste:
                Toggle("Auto-paste", isOn: $state.settings.autoPaste).toggleStyle(.switch)
                Toggle("Review before paste", isOn: $state.settings.reviewBeforePaste).toggleStyle(.switch)
                Toggle("Restore clipboard", isOn: $state.settings.restoreClipboard).toggleStyle(.switch)
            case .results:
                if state.alternativeResults.isEmpty { Text("Waiting for an alternate result").font(.caption).foregroundStyle(.secondary) }
                ForEach(Array(state.alternativeResults.enumerated()), id: \.offset) { _, item in Button("Use \(item.provider) (\(String(format: "%.1fs", item.latency)))") { Task { await state.replaceLastPaste(with: item) } }.buttonStyle(.bordered) }
            }
        }.frame(width: 205, alignment: .leading)
    }

    private var chineseColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Chinese output").font(.headline)
            finalRow("Cantonese written style", selected: state.settings.outputLanguage == .cantoneseWritten) { state.settings.outputLanguage = .cantoneseWritten }
            finalRow("Formal Traditional Chinese", selected: state.settings.outputLanguage == .formalTraditionalChinese) { state.settings.outputLanguage = .formalTraditionalChinese }
        }.frame(width: 205, alignment: .leading)
    }

    private func flowRow(_ title: String, selected: Bool, chevron: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack { Text(title); Spacer(); if chevron { Image(systemName: "chevron.right").font(.caption) } }.contentShape(Rectangle()) }
            .buttonStyle(.plain).padding(.horizontal, 7).padding(.vertical, 5)
            .background(selected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .onHover { inside in
                hoverTask?.cancel()
                if inside { hoverTask = Task { try? await Task.sleep(for: .milliseconds(300)); guard !Task.isCancelled else { return }; action() } }
            }
    }

    private func finalRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack { Image(systemName: selected ? "checkmark" : "").frame(width: 14); Text(title) }.contentShape(Rectangle()) }
            .buttonStyle(.plain).padding(.horizontal, 7).padding(.vertical, 5)
            .background(selected ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}
