import Foundation

struct WhisperCppTranscriptionService: SpeechToTextService {
    let providerName = "whisper.cpp"
    let runner = ProcessRunner()
    func readiness() async -> ProviderReadiness { ProviderReadiness(ready: await runner.locate("whisper-cli") != nil, detail: "Install whisper.cpp's whisper-cli to enable") }
    func transcribe(audioURL: URL, language: RecognitionLanguage, vocabularyHints: [String]) async throws -> TranscriptResult {
        guard let binary = await runner.locate("whisper-cli") else { throw SpeechToTextError.unavailable(providerName) }
        var arguments = ["-f", audioURL.path, "--no-timestamps"]
        if let language = language.whisperLanguageCode { arguments += ["-l", language] }
        if !vocabularyHints.isEmpty { arguments += ["--prompt", vocabularyHints.joined(separator: ", ")] }
        let process = try await runner.run(executable: binary, arguments: arguments, timeout: 30)
        guard process.exitCode == 0 else { throw SpeechToTextError.failed(process.stderr) }
        return TranscriptResult(text: process.stdout.trimmingCharacters(in: .whitespacesAndNewlines), language: language.whisperLanguageCode, duration: nil, confidence: nil, provider: providerName)
    }
}
