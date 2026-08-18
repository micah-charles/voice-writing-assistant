import Foundation
import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var dictationState: DictationState = .idle
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var microphonePermission: PermissionStatus = .unknown
    @Published private(set) var accessibilityPermission: PermissionStatus = .unknown
    @Published private(set) var lastRecordingURL: URL?
    @Published private(set) var rawTranscript = ""
    @Published private(set) var processedText = ""
    @Published private(set) var capturedContext = CapturedContext.empty
    @Published private(set) var processingProvider = ""
    @Published private(set) var processingLatency: TimeInterval = 0
    @Published private(set) var lastPasteMethod = ""
    @Published private(set) var alternativeResults: [ProcessingResult] = []
    @Published private(set) var floatingMenuVisible = false
    @Published var settings = AppSettings() { didSet { shortcut.toggleMode = settings.shortcutMode == .toggle; settings.showFloatingControl ? floatingControl.show() : floatingControl.hide(); Task { await settingsStore.save(settings) } } }
    @Published private(set) var dictionaryEntries: [PersonalDictionaryEntry] = []
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var diagnostics: [ProviderDiagnostic] = []

    private let audioCapture = AudioCaptureService()
    private let permissions = AccessibilityPermissionService()
    private let shortcut = GlobalShortcutService()
    private let settingsStore = SettingsStore()
    private let dictionaryStore = DictionaryStore()
    private let historyStore = HistoryStore()
    private let sttRouter = STTProviderRouter()
    private let contextCapture = ContextCaptureService()
    private let textProcessor = TextProcessorRouter()
    private let terminology = TerminologyService()
    private let openCC = OpenCCService()
    private let autoPaste = AutoPasteService()
    private let clipboard = ClipboardService()
    private var timer: Timer?
    private var workflow: Workflow = .dictation
    private var preRecordingContext = CapturedContext.empty
    private var pasteTargetBundleIdentifier: String?
    private var currentHistoryEntryID: UUID?
    private var lastPasteTargetBundleIdentifier: String?
    private var pipelineTask: Task<Void, Never>?
    private var floatingMenuTask: Task<Void, Never>?
    private lazy var recorderPanel = RecorderPanelController(state: self)
    private lazy var floatingControl = FloatingControlPanelController(state: self)

    init() {
        shortcut.onPress = { [weak self] in Task { @MainActor in guard let self else { return }; if self.settings.shortcutMode == .toggle, self.dictationState == .recording { await self.finishRecording() } else { await self.beginDictation() } } }
        shortcut.onRelease = { [weak self] in Task { @MainActor in await self?.finishRecording() } }
        shortcut.onTransformPress = { [weak self] in Task { @MainActor in await self?.beginSelectedTextTransform() } }
        shortcut.onTransformRelease = { [weak self] in Task { @MainActor in await self?.finishRecording() } }
        shortcut.onCancel = { [weak self] in Task { @MainActor in self?.cancel() } }
        shortcut.onRegistrationFailure = { [weak self] message in
            Task { @MainActor in self?.dictationState = .failed(message) }
        }
        shortcut.start()
        floatingControl.show()
        refreshPermissions()
        Task { [weak self] in
            guard let self else { return }
            settings = await settingsStore.loadWithHistoryEnabled()
            dictionaryEntries = await dictionaryStore.load()
            history = await historyStore.load()
            if settings.warmModelAtLaunch { try? await sttRouter.warm(settings: settings) }
            await refreshDiagnostics()
        }
    }

    deinit { shortcut.stop() }

    var statusText: String { dictationState.displayText }
    var isRecording: Bool { dictationState == .recording }
    var floatingStatusSymbol: String {
        switch dictationState {
        case .recording: return "waveform"
        case .transcribing, .capturingContext: return "ellipsis"
        case .processing, .normalizing: return "brain.head.profile"
        case .pasting, .completed: return "checkmark"
        case .failed: return "exclamationmark"
        default: return "sparkles"
        }
    }
    var elapsedText: String { String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60) }
    var menuBarSymbol: String {
        switch dictationState {
        case .recording: return "waveform.circle.fill"
        case .failed: return "exclamationmark.circle"
        case .transcribing, .capturingContext, .processing, .normalizing, .pasting: return "arrow.triangle.2.circlepath.circle"
        default: return "mic.circle"
        }
    }

    func refreshPermissions() {
        microphonePermission = audioCapture.microphonePermission
        accessibilityPermission = permissions.status
    }

    func requestAccessibility() { permissions.request(); refreshPermissions() }

    func refreshDiagnostics() async {
        let whisper = await WhisperKitTranscriptionService(model: settings.whisperModel).readiness()
        let parakeet = await ParakeetTranscriptionService().readiness()
        let whisperCpp = await WhisperCppTranscriptionService().readiness()
        let codex = await CodexCLIProcessor().readiness()
        let ollama = await OllamaProcessor(endpoint: settings.ollamaEndpoint, model: settings.ollamaModel, timeout: TimeInterval(settings.processingTimeoutSeconds)).readiness()
        diagnostics = [
            ProviderDiagnostic(id: "whisperkit", name: "WhisperKit", ready: whisper.ready, detail: whisper.detail),
            ProviderDiagnostic(id: "parakeet", name: "Parakeet", ready: parakeet.ready, detail: parakeet.detail),
            ProviderDiagnostic(id: "whispercpp", name: "whisper.cpp", ready: whisperCpp.ready, detail: whisperCpp.detail),
            ProviderDiagnostic(id: "codex", name: "Codex CLI", ready: codex.ready, detail: codex.detail),
            ProviderDiagnostic(id: "ollama", name: "Ollama", ready: ollama.ready, detail: ollama.detail),
            ProviderDiagnostic(id: "accessibility", name: "Accessibility", ready: accessibilityPermission == .granted, detail: accessibilityPermission.rawValue),
            ProviderDiagnostic(id: "microphone", name: "Microphone", ready: microphonePermission == .granted, detail: microphonePermission.rawValue)
        ]
    }

    func beginDictation() async {
        workflow = .dictation
        pasteTargetBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        await beginRecording()
    }

    func toggleFloatingDictation() async {
        if isRecording { await finishRecording() } else { await beginDictation() }
    }

    func beginFloatingPushToTalk() async {
        guard dictationState.canStart else { return }
        floatingMenuVisible = false
        floatingControl.setMenuVisible(false)
        await beginDictation()
    }

    func finishFloatingPushToTalk() async {
        guard dictationState == .recording else { return }
        await finishRecording()
    }

    func showSettings() {
        activateAndBringForward(windowTitle: "Voice Writing Assistant Settings")
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        bringWindowToFront(matching: "Settings")
    }

    func bringHistoryToFront() { activateAndBringForward(windowTitle: "History"); bringWindowToFront(matching: "History") }
    func bringDictionaryToFront() { activateAndBringForward(windowTitle: "Personal Dictionary"); bringWindowToFront(matching: "Personal Dictionary") }

    private func activateAndBringForward(windowTitle: String) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.title == windowTitle })?.makeKeyAndOrderFront(nil)
    }

    private func bringWindowToFront(matching title: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) {
            guard let window = NSApp.windows.first(where: { $0.title.localizedCaseInsensitiveContains(title) }) else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func setFloatingMenuHover(_ hovering: Bool) {
        floatingMenuTask?.cancel()
        floatingMenuTask = Task { [weak self] in
            try? await Task.sleep(for: hovering ? .milliseconds(650) : .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.floatingMenuVisible = hovering
            self.floatingControl.setMenuVisible(hovering)
        }
    }

    func closeFloatingMenu() {
        floatingMenuTask?.cancel()
        floatingMenuVisible = false
        floatingControl.setMenuVisible(false)
    }

    func beginSelectedTextTransform() async {
        guard dictationState.canStart else { return }
        workflow = .selectedTransform
        preRecordingContext = await contextCapture.capture(settings: settings)
        pasteTargetBundleIdentifier = preRecordingContext.bundleIdentifier
        guard let selected = preRecordingContext.selectedText, !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            dictationState = .failed("Select text first, then hold Control + Option + E.")
            return
        }
        await beginRecording()
    }

    private func beginRecording() async {
        guard dictationState.canStart else { return }
        dictationState = .starting
        let permission = await audioCapture.requestMicrophonePermissionIfNeeded()
        microphonePermission = permission
        guard permission == .granted else {
            dictationState = .failed("Microphone permission is required.")
            return
        }
        do {
            try audioCapture.start { [weak self] level in
                Task { @MainActor in self?.audioLevel = level }
            }
            elapsedSeconds = 0
            startTimer()
            dictationState = .recording
            recorderPanel.show()
        } catch {
            dictationState = .failed(error.localizedDescription)
        }
    }

    func finishRecording() async {
        guard case .recording = dictationState else { return }
        stopTimer()
        do {
            let url = try audioCapture.stop()
            lastRecordingURL = url
            audioLevel = 0
            pipelineTask?.cancel()
            pipelineTask = Task { [weak self] in await self?.process(audioURL: url) }
        } catch {
            dictationState = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        stopTimer()
        audioCapture.cancel()
        audioLevel = 0
        dictationState = .idle
        workflow = .dictation
        pipelineTask?.cancel(); pipelineTask = nil
        recorderPanel.hide()
    }

    func reset() { if !dictationState.isBusy { dictationState = .idle } }

    func saveDictionaryEntry(_ entry: PersonalDictionaryEntry) async {
        if let index = dictionaryEntries.firstIndex(where: { $0.id == entry.id }) { dictionaryEntries[index] = entry } else { dictionaryEntries.append(entry) }
        await dictionaryStore.save(dictionaryEntries)
    }
    func deleteDictionary(at offsets: IndexSet) async { dictionaryEntries.remove(atOffsets: offsets); await dictionaryStore.save(dictionaryEntries) }
    func clearHistory() async { try? await historyStore.clear(); history = [] }
    func pasteReviewedText() async { guard !processedText.isEmpty else { return }; await paste(text: processedText) }
    func useRawText() async { guard !rawTranscript.isEmpty else { return }; await paste(text: rawTranscript) }
    func replaceLastPaste(with result: ProcessingResult) async {
        guard !result.text.isEmpty else { return }
        do {
            try await autoPaste.undoLastPaste(targetBundleIdentifier: lastPasteTargetBundleIdentifier)
            await paste(text: result.text)
            processingProvider = result.provider
            processingLatency = result.latency
        } catch { showTemporaryFailure("Could not undo the previous paste: \(error.localizedDescription)") }
    }

    private func process(audioURL: URL) async {
        do {
            try Task.checkCancellation()
            dictationState = .transcribing
            let transcript = try await sttRouter.transcribe(audioURL: audioURL, settings: settings, hints: terminology.hints(dictionaryEntries))
            try Task.checkCancellation()
            rawTranscript = terminology.normalize(transcript.text, entries: dictionaryEntries)
            dictationState = .capturingContext
            capturedContext = workflow == .selectedTransform ? preRecordingContext : await contextCapture.capture(settings: settings)
            try Task.checkCancellation()
            let mode = ModeClassifier().classify(context: capturedContext, transform: workflow == .selectedTransform)
            dictationState = .processing
            let result: ProcessingResult
            if workflow == .selectedTransform, let selected = capturedContext.selectedText {
                result = await textProcessor.transform(selectedText: selected, instruction: rawTranscript, context: capturedContext, settings: settings)
            } else {
                alternativeResults = []
                var iterator = textProcessor.race(rawText: rawTranscript, context: capturedContext, mode: mode, settings: settings).makeAsyncIterator()
                guard let first = await iterator.next() else { throw ProcessRunnerError.failed("No text processor returned a result.") }
                result = first
                Task { [weak self] in
                    while let alternative = await iterator.next() {
                        guard let self else { return }
                        let normalized = self.openCC.convert(self.terminology.normalize(alternative.text, entries: self.dictionaryEntries), profile: self.settings.openCCProfile)
                        guard !normalized.isEmpty, normalized != self.processedText else { continue }
                        self.alternativeResults.append(ProcessingResult(text: normalized, provider: alternative.provider, latency: alternative.latency, usedFallback: alternative.usedFallback))
                        if let id = self.currentHistoryEntryID {
                            try? await self.historyStore.updateAlternatives(id: id, alternatives: self.alternativeResults)
                            self.history = await self.historyStore.load()
                        }
                    }
                }
            }
            dictationState = .normalizing
            processedText = openCC.convert(terminology.normalize(result.text, entries: dictionaryEntries), profile: settings.openCCProfile)
            processingProvider = result.provider; processingLatency = result.latency
            if settings.storeHistory {
                let entry = HistoryEntry(id: UUID(), date: .now, rawTranscript: rawTranscript, processedText: processedText, provider: processingProvider, mode: mode, activeApplication: capturedContext.activeApplicationName, latency: processingLatency, alternativeResults: alternativeResults)
                currentHistoryEntryID = entry.id
                try? await historyStore.append(entry)
                history = await historyStore.load()
            }
            if settings.reviewBeforePaste { dictationState = .awaitingReview } else { await paste(text: processedText) }
        } catch is CancellationError { dictationState = .idle; recorderPanel.hide() }
        catch { dictationState = .failed(error.localizedDescription) }
    }

    private func showTemporaryFailure(_ message: String) {
        dictationState = .failed(message)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, case .failed = self.dictationState else { return }
            self.dictationState = .idle
            self.recorderPanel.hide()
        }
    }

    private func paste(text: String) async {
        dictationState = .pasting
        guard settings.autoPaste else { clipboard.copy(text); dictationState = .completed; recorderPanel.hide(); return }
        do { lastPasteMethod = try await autoPaste.paste(text, targetBundleIdentifier: pasteTargetBundleIdentifier, restoreClipboard: settings.restoreClipboard).description; lastPasteTargetBundleIdentifier = pasteTargetBundleIdentifier; dictationState = .completed; recorderPanel.hide() }
        catch { showTemporaryFailure(error.localizedDescription) }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }
}

private enum Workflow { case dictation, selectedTransform }
