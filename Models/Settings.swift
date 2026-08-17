import Foundation

struct AppSettings: Codable, Equatable {
    var shortcutMode: ShortcutMode = .pushToTalk
    var autoPaste = true
    var restoreClipboard = false
    var reviewBeforePaste = false
    var showFloatingControl = true
    var warmModelAtLaunch = true
    var selectedSTTProvider: STTProvider = .automatic
    var selectedTextProcessor: TextProcessorProvider = .automatic
    var recognitionLanguage: RecognitionLanguage = .automatic
    var processingStyle: ProcessingStyle = .automatic
    var whisperModel = "small"
    var ollamaEndpoint = "http://127.0.0.1:11434"
    var ollamaModel = ""
    var processingTimeoutSeconds = 20
    var useActiveAppContext = true
    var useWindowTitle = true
    var useSelectedTextContext = true
    var useClipboardContext = false
    var clipboardCharacterLimit = 2_000
    var useBrowserURL = false
    var storeHistory = false
    var chineseOutput = ChineseOutputStyle.preserve
    var outputLanguage = OutputLanguage.preserveSpokenLanguage
    var openCCProfile = OpenCCProfile.preserve
}

enum ShortcutMode: String, Codable, CaseIterable, Identifiable { case pushToTalk, toggle; var id: String { rawValue } }
enum ChineseOutputStyle: String, Codable, CaseIterable, Identifiable { case cantonese, formalTraditional, preserve; var id: String { rawValue } }
enum OpenCCProfile: String, Codable, CaseIterable, Identifiable { case preserve, traditional, taiwanTraditional; var id: String { rawValue } }
enum OutputLanguage: String, Codable, CaseIterable, Identifiable {
    case preserveSpokenLanguage, english, cantoneseWritten, formalTraditionalChinese
    var id: String { rawValue }
    var displayName: String {
        switch self { case .preserveSpokenLanguage: "Preserve spoken language"; case .english: "Translate to English"; case .cantoneseWritten: "Cantonese written style"; case .formalTraditionalChinese: "Formal Traditional Chinese" }
    }
}
