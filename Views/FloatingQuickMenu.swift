import SwiftUI

private enum FlowerRoot: String, CaseIterable, Identifiable {
    case output = "Output\nlanguage"
    case style = "Writing\nstyle"
    case processor = "AI\nprocessor"
    case paste = "Paste\nbehaviour"
    case results = "Last\nresults"
    case settings = "All\nsettings"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .output: "globe"
        case .style: "pencil"
        case .processor: "cpu"
        case .paste: "doc.on.clipboard"
        case .results: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .output: .blue
        case .style: .green
        case .processor: .purple
        case .paste: .orange
        case .results: .yellow
        case .settings: .gray
        }
    }
}

/// A hover-first radial menu. Hovering explores a category; clicking a final petal changes a setting.
struct FloatingQuickMenu: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedRoot: FlowerRoot?
    @State private var hoverTask: Task<Void, Never>?

    private let radius: CGFloat = 124

    var body: some View {
        ZStack {
            ForEach(Array(FlowerRoot.allCases.enumerated()), id: \.element.id) { index, item in
                mainPetal(item, index: index)
            }

            if let selectedRoot {
                fan(for: selectedRoot)
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
        }
        .frame(width: 430, height: 430)
        .animation(.spring(duration: 0.22), value: selectedRoot)
    }

    private func mainPetal(_ item: FlowerRoot, index: Int) -> some View {
        let angle = CGFloat(index) * (.pi * 2 / CGFloat(FlowerRoot.allCases.count)) - .pi / 2
        let x = cos(angle) * radius
        let y = sin(angle) * radius
        let isSelected = selectedRoot == item

        return Button {
            select(item)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: item.symbol).font(.system(size: 19, weight: .semibold))
                Text(item.rawValue).font(.system(size: 11, weight: .semibold)).multilineTextAlignment(.center)
            }
            .foregroundStyle(item.tint)
            .frame(width: 94, height: 94)
            .background(item.tint.opacity(isSelected ? 0.28 : 0.12), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.82), lineWidth: 1))
            .shadow(color: item.tint.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedRoot == nil || isSelected ? 1 : 0.84)
        .opacity(selectedRoot == nil || isSelected ? 1 : 0.34)
        .offset(x: x, y: y)
        .onHover { inside in scheduleSelection(item, inside: inside) }
        .accessibilityLabel(item.rawValue.replacingOccurrences(of: "\n", with: " "))
    }

    @ViewBuilder private func fan(for root: FlowerRoot) -> some View {
        let options = options(for: root)
        ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
            let count = max(options.count - 1, 1)
            let angle = CGFloat(index) * (.pi * 0.86 / CGFloat(count)) - .pi / 2 - .pi * 0.43
            let x = cos(angle) * 184
            let y = sin(angle) * 184
            Button { option.action() } label: {
                VStack(spacing: 4) {
                    Image(systemName: option.symbol).font(.system(size: 16, weight: .semibold))
                    Text(option.title).font(.system(size: 10, weight: .semibold)).multilineTextAlignment(.center).lineLimit(2)
                }
                .foregroundStyle(root.tint)
                .frame(width: 78, height: 78)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(root.tint.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .offset(x: x, y: y)
            .accessibilityLabel(option.title)
        }
    }

    private func select(_ item: FlowerRoot) {
        if item == .settings {
            state.showSettings()
        } else {
            selectedRoot = item
        }
    }

    private func scheduleSelection(_ item: FlowerRoot, inside: Bool) {
        hoverTask?.cancel()
        guard inside else { return }
        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            select(item)
        }
    }

    private func options(for root: FlowerRoot) -> [FlowerOption] {
        switch root {
        case .output:
            [
                .init("Keep original", "doc.text", selected: state.settings.outputLanguage == .preserveSpokenLanguage) { state.settings.outputLanguage = .preserveSpokenLanguage },
                .init("English", "character.book.closed", selected: state.settings.outputLanguage == .english) { state.settings.outputLanguage = .english },
                .init("Cantonese written", "text.bubble", selected: state.settings.outputLanguage == .cantoneseWritten) { state.settings.outputLanguage = .cantoneseWritten },
                .init("Formal Traditional", "character", selected: state.settings.outputLanguage == .formalTraditionalChinese) { state.settings.outputLanguage = .formalTraditionalChinese }
            ]
        case .style:
            ProcessingStyle.allCases.map { style in .init(style.displayName, "pencil", selected: state.settings.processingStyle == style) { state.settings.processingStyle = style } }
        case .processor:
            TextProcessorProvider.allCases.map { provider in .init(provider.displayName, "cpu", selected: state.settings.selectedTextProcessor == provider) { state.settings.selectedTextProcessor = provider } }
        case .paste:
            [
                .init(state.settings.autoPaste ? "Auto-paste on" : "Auto-paste off", "doc.on.clipboard", selected: state.settings.autoPaste) { state.settings.autoPaste.toggle() },
                .init(state.settings.reviewBeforePaste ? "Review on" : "Review before paste", "eye", selected: state.settings.reviewBeforePaste) { state.settings.reviewBeforePaste.toggle() },
                .init(state.settings.restoreClipboard ? "Restore clipboard on" : "Restore clipboard", "arrow.uturn.backward", selected: state.settings.restoreClipboard) { state.settings.restoreClipboard.toggle() }
            ]
        case .results:
            state.alternativeResults.isEmpty
                ? [.init("No alternate\nresult yet", "clock", selected: false) {}]
                : state.alternativeResults.map { result in
                    .init("Use \(result.provider)\n\(String(format: "%.1fs", result.latency))", "checkmark", selected: false) {
                        Task { await state.replaceLastPaste(with: result) }
                    }
                }
        case .settings:
            []
        }
    }
}

private struct FlowerOption: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    init(_ title: String, _ symbol: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.selected = selected
        self.action = action
    }
}
