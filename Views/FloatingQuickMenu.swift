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
        case .output: "globe"; case .style: "pencil"; case .processor: "cpu"
        case .paste: "doc.on.clipboard"; case .results: "clock.arrow.circlepath"; case .settings: "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .output: .blue; case .style: .green; case .processor: .purple
        case .paste: .orange; case .results: .yellow; case .settings: .gray
        }
    }
}

/// A continuous hover path: fox hub → parent petal → outward child arc → click to apply.
struct FloatingQuickMenu: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedRoot: FlowerRoot?
    @State private var hoverTask: Task<Void, Never>?

    private let rootRadius: CGFloat = 108
    private let childRadius: CGFloat = 202

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 132, height: 132)
                .overlay(Circle().stroke(.white.opacity(0.75), lineWidth: 1))

            ForEach(Array(FlowerRoot.allCases.enumerated()), id: \.element.id) { index, root in
                rootPetal(root, at: index)
            }

            if let selectedRoot {
                childArc(for: selectedRoot)
                    .transition(.opacity.combined(with: .scale(scale: 0.84)))
            }
        }
        .frame(width: 470, height: 470)
        .animation(.spring(duration: 0.25, bounce: 0.18), value: selectedRoot)
        .onExitCommand { state.closeFloatingMenu() }
    }

    private func rootPetal(_ root: FlowerRoot, at index: Int) -> some View {
        let angle = rootAngle(index)
        let isActive = selectedRoot == root
        let isDimmed = selectedRoot != nil && !isActive

        return Button { select(root) } label: {
            petalLabel(title: root.rawValue, symbol: root.symbol, tint: root.tint, selected: isActive)
                .background(petalSurface(tint: root.tint, selected: isActive, angle: angle))
        }
        .buttonStyle(.plain)
        .frame(width: 112, height: 128)
        .offset(x: cos(angle) * rootRadius, y: sin(angle) * rootRadius)
        .scaleEffect(isDimmed ? 0.82 : 1)
        .opacity(isDimmed ? 0.25 : 1)
        .onHover { inside in scheduleSelection(root, inside: inside) }
        .accessibilityLabel(root.rawValue.replacingOccurrences(of: "\n", with: " "))
    }

    @ViewBuilder private func childArc(for root: FlowerRoot) -> some View {
        let values = options(for: root)
        let parentAngle = rootAngle(FlowerRoot.allCases.firstIndex(of: root) ?? 0)
        let spread = min(.pi * 0.92, .pi * 0.26 * CGFloat(max(values.count - 1, 1)))

        ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
            let childAngle = values.count == 1
                ? parentAngle
                : parentAngle - spread / 2 + spread * CGFloat(index) / CGFloat(values.count - 1)

            Button { value.action(); state.closeFloatingMenu() } label: {
                petalLabel(title: value.title, symbol: value.symbol, tint: root.tint, selected: value.selected)
                    .background(petalSurface(tint: root.tint, selected: value.selected, angle: childAngle))
            }
            .buttonStyle(.plain)
            .frame(width: 96, height: 112)
            .offset(x: cos(childAngle) * childRadius, y: sin(childAngle) * childRadius)
            .accessibilityLabel(value.title)
        }
    }

    private func petalLabel(title: String, symbol: String, tint: Color, selected: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).offset(x: 11, y: -8) }
            }
            Text(title).font(.system(size: 10.5, weight: .semibold)).multilineTextAlignment(.center).lineLimit(2)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(PetalShape())
    }

    private func petalSurface(tint: Color, selected: Bool, angle: CGFloat) -> some View {
        PetalShape()
            .fill(tint.opacity(selected ? 0.32 : 0.14))
            .overlay(PetalShape().stroke(.white.opacity(0.9), lineWidth: 1))
            .shadow(color: tint.opacity(selected ? 0.28 : 0.12), radius: selected ? 14 : 7, y: 3)
            .rotationEffect(.radians(angle + .pi / 2))
    }

    private func rootAngle(_ index: Int) -> CGFloat {
        CGFloat(index) * (.pi * 2 / CGFloat(FlowerRoot.allCases.count)) - .pi / 2
    }

    private func select(_ root: FlowerRoot) {
        if root == .settings { state.showSettings() } else { selectedRoot = root }
    }

    private func scheduleSelection(_ root: FlowerRoot, inside: Bool) {
        hoverTask?.cancel()
        guard inside else { return }
        hoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            select(root)
        }
    }

    private func options(for root: FlowerRoot) -> [FlowerOption] {
        switch root {
        case .output:
            [
                .init("Keep\noriginal", "doc.text", state.settings.outputLanguage == .preserveSpokenLanguage) { state.settings.outputLanguage = .preserveSpokenLanguage },
                .init("English", "character.book.closed", state.settings.outputLanguage == .english) { state.settings.outputLanguage = .english },
                .init("Written\nCantonese", "text.bubble", state.settings.outputLanguage == .cantoneseWritten) { state.settings.outputLanguage = .cantoneseWritten },
                .init("Traditional\nChinese", "character", state.settings.outputLanguage == .formalTraditionalChinese) { state.settings.outputLanguage = .formalTraditionalChinese }
            ]
        case .style:
            ProcessingStyle.allCases.map { style in .init(style.displayName, "pencil", state.settings.processingStyle == style) { state.settings.processingStyle = style } }
        case .processor:
            TextProcessorProvider.allCases.map { provider in .init(provider.displayName, "cpu", state.settings.selectedTextProcessor == provider) { state.settings.selectedTextProcessor = provider } }
        case .paste:
            [
                .init(state.settings.autoPaste ? "Auto-paste\non" : "Auto-paste\noff", "doc.on.clipboard", state.settings.autoPaste) { state.settings.autoPaste.toggle() },
                .init(state.settings.reviewBeforePaste ? "Review\non" : "Review before\npaste", "eye", state.settings.reviewBeforePaste) { state.settings.reviewBeforePaste.toggle() },
                .init(state.settings.restoreClipboard ? "Restore\nclipboard on" : "Restore\nclipboard", "arrow.uturn.backward", state.settings.restoreClipboard) { state.settings.restoreClipboard.toggle() }
            ]
        case .results:
            state.alternativeResults.isEmpty
                ? [.init("No alternate\nresult yet", "clock", false) {}]
                : state.alternativeResults.map { result in .init("Use \(result.provider)\n\(String(format: "%.1fs", result.latency))", "checkmark", false) { Task { await state.replaceLastPaste(with: result) } } }
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

    init(_ title: String, _ symbol: String, _ selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.selected = selected
        self.action = action
    }
}

/// Inner edge is narrow; the wide outer edge points away from the Fox hub.
private struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        var path = Path()
        path.move(to: CGPoint(x: midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.93, y: rect.height * 0.28),
            control1: CGPoint(x: rect.maxX * 0.78, y: rect.height * 0.82),
            control2: CGPoint(x: rect.maxX * 1.04, y: rect.height * 0.56)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: 0),
            control1: CGPoint(x: rect.maxX * 0.82, y: rect.height * 0.03),
            control2: CGPoint(x: rect.maxX * 0.62, y: 0)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.07, y: rect.height * 0.28),
            control1: CGPoint(x: rect.width * 0.38, y: 0),
            control2: CGPoint(x: -rect.width * 0.04, y: rect.height * 0.03)
        )
        path.addCurve(
            to: CGPoint(x: midX, y: rect.maxY),
            control1: CGPoint(x: -rect.width * 0.04, y: rect.height * 0.56),
            control2: CGPoint(x: rect.width * 0.22, y: rect.height * 0.82)
        )
        return path
    }
}
