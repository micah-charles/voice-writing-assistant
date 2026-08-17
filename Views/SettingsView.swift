import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var newTerm = ""
    @State private var newPreferred = ""
    var body: some View {
        ScrollView {
        Form {
            Section("General") {
                Picker("Shortcut", selection: $state.settings.shortcutMode) { Text("Push to talk").tag(ShortcutMode.pushToTalk); Text("Toggle").tag(ShortcutMode.toggle) }
                Toggle("Auto-paste", isOn: $state.settings.autoPaste); Toggle("Restore clipboard after paste", isOn: $state.settings.restoreClipboard); Toggle("Review before paste", isOn: $state.settings.reviewBeforePaste)
                Toggle("Show floating record button", isOn: $state.settings.showFloatingControl)
            }
            Section("Speech recognition") {
                Picker("Provider", selection: $state.settings.selectedSTTProvider) { ForEach(STTProvider.allCases) { Text($0.displayName).tag($0) } }
                Picker("Language", selection: $state.settings.recognitionLanguage) { ForEach(RecognitionLanguage.allCases) { Text($0.displayName).tag($0) } }
                Picker("Whisper model", selection: $state.settings.whisperModel) { Text("Small (multilingual)").tag("small"); Text("Large v3 compressed").tag("large-v3-v20240930_626MB"); Text("Large v3 turbo").tag("large-v3-v20240930_turbo") }; Toggle("Warm transcription model at launch", isOn: $state.settings.warmModelAtLaunch)
                Text("WhisperKit is the preferred local multilingual engine. Parakeet and whisper.cpp route automatically when installed/configured.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("AI processing") {
                Picker("Provider", selection: $state.settings.selectedTextProcessor) { ForEach(TextProcessorProvider.allCases) { Text($0.displayName).tag($0) } }
                Picker("Writing style", selection: $state.settings.processingStyle) { ForEach(ProcessingStyle.allCases) { Text($0.displayName).tag($0) } }
                TextField("Ollama endpoint", text: $state.settings.ollamaEndpoint); TextField("Ollama model", text: $state.settings.ollamaModel); Stepper("Timeout: \(state.settings.processingTimeoutSeconds)s", value: $state.settings.processingTimeoutSeconds, in: 5...60)
                Text("Codex CLI uses the existing Codex sign-in and may send text/context through that service. Ollama remains local at the configured endpoint.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Context and privacy") {
                Toggle("Use active app", isOn: $state.settings.useActiveAppContext); Toggle("Use window title", isOn: $state.settings.useWindowTitle); Toggle("Use selected text", isOn: $state.settings.useSelectedTextContext); Toggle("Use clipboard context", isOn: $state.settings.useClipboardContext); Toggle("Use browser URL", isOn: $state.settings.useBrowserURL); Toggle("Store transcription history locally", isOn: $state.settings.storeHistory)
                if state.settings.storeHistory { Button("Clear history", role: .destructive) { Task { await state.clearHistory() } } }
            }
            Section("Language") {
                Picker("Output", selection: $state.settings.outputLanguage) { ForEach(OutputLanguage.allCases) { Text($0.displayName).tag($0) } }
                Picker("Chinese output", selection: $state.settings.chineseOutput) { ForEach(ChineseOutputStyle.allCases) { Text($0.rawValue.capitalized).tag($0) } }
                Picker("Chinese conversion", selection: $state.settings.openCCProfile) { ForEach(OpenCCProfile.allCases) { Text($0.rawValue.capitalized).tag($0) } }
            }
            Section("Personal dictionary") {
                HStack { TextField("Term", text: $newTerm); TextField("Preferred form", text: $newPreferred); Button("Add") { let entry = PersonalDictionaryEntry(term: newTerm, preferredForm: newPreferred.isEmpty ? newTerm : newPreferred, aliases: [newTerm], category: nil); Task { await state.saveDictionaryEntry(entry) }; newTerm = ""; newPreferred = "" }.disabled(newTerm.isEmpty) }
                ForEach(state.dictionaryEntries) { entry in Text("\(entry.term) → \(entry.preferredForm)") }.onDelete { offsets in Task { await state.deleteDictionary(at: offsets) } }
            }
            Section("Permissions") {
                LabeledContent("Microphone", value: state.microphonePermission.rawValue); LabeledContent("Accessibility", value: state.accessibilityPermission.rawValue)
                HStack { Button("Refresh") { state.refreshPermissions() }; Button("Request Accessibility") { state.requestAccessibility() } }
            }
            Section("Provider diagnostics") {
                ForEach(state.diagnostics) { diagnostic in
                    HStack(alignment: .firstTextBaseline) { Image(systemName: diagnostic.ready ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(diagnostic.ready ? .green : .secondary); VStack(alignment: .leading) { Text(diagnostic.name); Text(diagnostic.detail).font(.caption).foregroundStyle(.secondary) } }
                }
                Button("Refresh diagnostics") { Task { await state.refreshDiagnostics() } }
            }
        }
        }.frame(width: 540, height: 620).onAppear { state.refreshPermissions(); Task { await state.refreshDiagnostics() } }
    }
}
