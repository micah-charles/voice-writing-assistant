import Foundation

struct ProcessOutput: Sendable { let stdout: String; let stderr: String; let exitCode: Int32 }
enum ProcessRunnerError: LocalizedError { case executableNotFound(String), timedOut, failed(String)
    var errorDescription: String? { switch self { case .executableNotFound(let name): "\(name) was not found."; case .timedOut: "The command timed out."; case .failed(let message): message } }
}

/// Drains a child-process pipe while it is still running. Codex CLI emits startup
/// and progress diagnostics; waiting until termination to read can fill the pipe
/// buffer and make the child appear to hang until the timeout expires.
private final class PipeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ chunk: Data) { guard !chunk.isEmpty else { return }; lock.lock(); data.append(chunk); lock.unlock() }
    func value() -> Data { lock.lock(); defer { lock.unlock() }; return data }
}

actor ProcessRunner {
    func run(executable: String, arguments: [String], input: String? = nil, timeout: TimeInterval) async throws -> ProcessOutput {
        guard FileManager.default.isExecutableFile(atPath: executable) else { throw ProcessRunnerError.executableNotFound(executable) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe(), error = Pipe(), inputPipe = Pipe()
        let stdout = PipeCollector(), stderr = PipeCollector()
        process.standardOutput = output; process.standardError = error
        if input != nil { process.standardInput = inputPipe }
        do { try process.run() } catch { throw ProcessRunnerError.failed(error.localizedDescription) }
        output.fileHandleForReading.readabilityHandler = { handle in stdout.append(handle.availableData) }
        error.fileHandleForReading.readabilityHandler = { handle in stderr.append(handle.availableData) }
        if let input, let data = input.data(using: .utf8) { inputPipe.fileHandleForWriting.write(data); try? inputPipe.fileHandleForWriting.close() }
        let finished = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await withCheckedContinuation { continuation in process.terminationHandler = { _ in continuation.resume(returning: true) } } }
            group.addTask { try? await Task.sleep(for: .seconds(timeout)); return false }
            let first = await group.next() ?? false; group.cancelAll(); return first
        }
        guard finished else { process.terminate(); throw ProcessRunnerError.timedOut }
        output.fileHandleForReading.readabilityHandler = nil
        error.fileHandleForReading.readabilityHandler = nil
        stdout.append(output.fileHandleForReading.readDataToEndOfFile())
        stderr.append(error.fileHandleForReading.readDataToEndOfFile())
        let out = String(data: stdout.value(), encoding: .utf8) ?? ""
        let err = String(data: stderr.value(), encoding: .utf8) ?? ""
        return ProcessOutput(stdout: out, stderr: err, exitCode: process.terminationStatus)
    }

    func locate(_ executable: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init) + [
            "\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"
        ]
        return paths.map { URL(fileURLWithPath: $0).appendingPathComponent(executable).path }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
