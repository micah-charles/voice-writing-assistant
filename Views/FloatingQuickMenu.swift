import SwiftUI

private enum QuickSection: String, CaseIterable { case output = "Output language", style = "Writing style", processor = "AI processor", alternatives = "Last results" }

struct FloatingQuickMenu: View {
    @EnvironmentObject private var state: AppState
    @State private var section: QuickSection = .output
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Quick settings").font(.headline)
                ForEach(QuickSection.allCases, id: \.self) { item in quickRow(item) }
                Divider()
                Toggle("Auto-paste", isOn: $state.settings.autoPaste).toggleStyle(.switch)
                Button("All settings…") { state.showSettings() }
            }.frame(width: 158, alignment: .leading)
            Divider().frame(height: 235)
            VStack(alignment: .leading, spacing: 5) {
                Text(section.rawValue).font(.headline)
                switch section {
                case .output:
                    ForEach(OutputLanguage.allCases) { option in choice(option.displayName, selected: state.settings.outputLanguage == option) { state.settings.outputLanguage = option } }
                case .style:
                    ForEach(ProcessingStyle.allCases) { option in choice(option.displayName, selected: state.settings.processingStyle == option) { state.settings.processingStyle = option } }
                case .processor:
                    ForEach(TextProcessorProvider.allCases) { option in choice(option.displayName, selected: state.settings.selectedTextProcessor == option) { state.settings.selectedTextProcessor = option } }
                case .alternatives:
                    if state.alternativeResults.isEmpty { Text("No alternate result yet").foregroundStyle(.secondary) }
                    ForEach(Array(state.alternativeResults.enumerated()), id: \.offset) { _, result in
                        Button("Use \(result.provider) (\(String(format: "%.1fs", result.latency)))") { Task { await state.replaceLastPaste(with: result) } }
                            .buttonStyle(.plain).padding(.horizontal, 6).padding(.vertical, 4)
                    }
                }
            }.frame(width: 176, alignment: .leading)
        }
        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func quickRow(_ item: QuickSection) -> some View {
        Button { section = item } label: { HStack { Text(item.rawValue); Spacer(); Image(systemName: "chevron.right").font(.caption) }.contentShape(Rectangle()) }
            .buttonStyle(.plain).padding(.horizontal, 7).padding(.vertical, 5)
            .background(section == item ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .onHover { inside in
                hoverTask?.cancel()
                if inside { hoverTask = Task { try? await Task.sleep(for: .milliseconds(300)); guard !Task.isCancelled else { return }; section = item } }
            }
    }

    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack { Image(systemName: selected ? "checkmark" : "").frame(width: 14); Text(title) }.contentShape(Rectangle()) }
            .buttonStyle(.plain).padding(.horizontal, 6).padding(.vertical, 4)
            .background(selected ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}
