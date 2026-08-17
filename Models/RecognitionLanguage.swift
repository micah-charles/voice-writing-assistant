import Foundation

enum RecognitionLanguage: String, Codable, CaseIterable, Identifiable {
    case automatic, english, traditionalChinese, cantonese, mixedChineseEnglish
    var id: String { rawValue }
    var displayName: String {
        switch self { case .automatic: "Auto"; case .english: "English"; case .traditionalChinese: "Traditional Chinese"; case .cantonese: "Cantonese"; case .mixedChineseEnglish: "Mixed Chinese / English" }
    }
    var whisperLanguageCode: String? {
        switch self { case .automatic, .mixedChineseEnglish: nil; case .english: "en"; case .traditionalChinese: "zh"; case .cantonese: "yue" }
    }
}
