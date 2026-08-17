import XCTest
@testable import VoiceWritingAssistant

final class CoreServiceTests: XCTestCase {
    func testModeClassifierUsesBundleIdentifierBeforeNames() {
        XCTAssertEqual(ModeClassifier().classify(context: CapturedContext(activeApplicationName: "Unknown", bundleIdentifier: "com.microsoft.Outlook", windowTitle: nil, selectedText: nil, clipboardText: nil, browserURL: nil)), .email)
        XCTAssertEqual(ModeClassifier().classify(context: CapturedContext(activeApplicationName: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode", windowTitle: nil, selectedText: nil, clipboardText: nil, browserURL: nil)), .technical)
        XCTAssertEqual(ModeClassifier().classify(context: .empty, transform: true), .selectedTextTransform)
    }

    func testPrivacyFilterExcludesDisabledFieldsAndCapsClipboard() {
        var settings = AppSettings(); settings.useClipboardContext = true; settings.clipboardCharacterLimit = 3
        let source = CapturedContext(activeApplicationName: "Mail", bundleIdentifier: "com.apple.mail", windowTitle: "Private", selectedText: "selected", clipboardText: "abcdef", browserURL: "https://example.com")
        let filtered = ContextPrivacyPolicy().filter(source, settings: settings)
        XCTAssertEqual(filtered.clipboardText, "abc")
        XCTAssertNil(filtered.browserURL)
        XCTAssertEqual(filtered.selectedText, "selected")
    }

    func testPromptOmitsUnavailableFieldsAndProtectsMeaning() {
        let prompt = PromptBuilder().dictation(rawText: "tell James it is fine", context: CapturedContext(activeApplicationName: "Mail", bundleIdentifier: nil, windowTitle: nil, selectedText: nil, clipboardText: nil, browserURL: nil), mode: .email, style: .professional)
        XCTAssertTrue(prompt.contains("Do not invent facts"))
        XCTAssertTrue(prompt.contains("ACTIVE APP"))
        XCTAssertFalse(prompt.contains("WINDOW TITLE"))
    }

    func testTerminologyNormalizesAliasesWithoutTouchingOtherWords() {
        let entry = PersonalDictionaryEntry(term: "Keycloak", preferredForm: "Keycloak", aliases: ["key cloak"], category: "technical")
        XCTAssertEqual(TerminologyService().normalize("key cloak is ready", entries: [entry]), "Keycloak is ready")
    }

    func testRuleProcessorPreservesNewlines() async throws {
        let output = try await RuleBasedProcessor().process(rawText: "  hello   world  \n  next line ", context: .empty, mode: .general, style: .faithful, outputLanguage: .preserveSpokenLanguage)
        XCTAssertEqual(output.text, "hello world\nnext line")
    }

    func testOutputSanitizerRemovesFenceOnly() {
        XCTAssertEqual(OutputSanitizer().sanitize("```\nHello\n```"), "Hello")
    }

    func testEnglishOutputPromptExplicitlyRequestsTranslation() {
        let prompt = PromptBuilder().dictation(rawText: "你好", context: .empty, mode: .general, style: .faithful, outputLanguage: .english)
        XCTAssertTrue(prompt.contains("Translate the final text into natural English"))
    }
}
