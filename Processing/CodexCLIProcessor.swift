import Foundation

struct CodexCLIProcessor: TextProcessingService {
    let providerName = "Codex CLI"
    let timeout: TimeInterval
    let runner = ProcessRunner()

    init(timeout: TimeInterval = 30) {
        self.timeout = timeout
    }
    func readiness() async -> ProviderReadiness {
        guard let executable = await runner.locate("codex") else { return ProviderReadiness(ready: false, detail: "Codex CLI not installed") }
        do { let version = try await runner.run(executable: executable, arguments: ["--version"], timeout: 3); return ProviderReadiness(ready: version.exitCode == 0, detail: version.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) }
        catch { return ProviderReadiness(ready: false, detail: error.localizedDescription) }
    }
    func process(rawText: String, context: CapturedContext, mode: AppMode, style: ProcessingStyle, outputLanguage: OutputLanguage) async throws -> ProcessingResult {
        guard let executable = await runner.locate("codex") else { throw ProcessRunnerError.executableNotFound("codex") }
        let started = ContinuousClock.now
        let prompt = PromptBuilder().dictation(rawText: rawText, context: context, mode: mode, style: style, outputLanguage: outputLanguage)
        let output = try await runner.run(executable: executable, arguments: ["exec", "--ephemeral", "--skip-git-repo-check", "--sandbox", "read-only", "-"], input: prompt, timeout: timeout)
        guard output.exitCode == 0 else { throw ProcessRunnerError.failed(output.stderr.isEmpty ? "Codex CLI failed." : output.stderr) }
        return ProcessingResult(text: OutputSanitizer().sanitize(output.stdout), provider: providerName, latency: started.duration(to: .now).timeInterval, usedFallback: false)
    }
    func transform(selectedText: String, instruction: String, context: CapturedContext) async throws -> ProcessingResult {
        guard let executable = await runner.locate("codex") else { throw ProcessRunnerError.executableNotFound("codex") }
        let started = ContinuousClock.now
        let output = try await runner.run(executable: executable, arguments: ["exec", "--ephemeral", "--skip-git-repo-check", "--sandbox", "read-only", "-"], input: PromptBuilder().transform(selectedText: selectedText, instruction: instruction, context: context), timeout: timeout)
        guard output.exitCode == 0 else { throw ProcessRunnerError.failed(output.stderr) }
        return ProcessingResult(text: OutputSanitizer().sanitize(output.stdout), provider: providerName, latency: started.duration(to: .now).timeInterval, usedFallback: false)
    }
}
