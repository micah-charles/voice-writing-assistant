import Foundation

struct ProcessOutput: Sendable { let stdout: String; let stderr: String; let exitCode: Int32 }
enum ProcessRunnerError: LocalizedError { case executableNotFound(String), timedOut, failed(String)
    var errorDescription: String? { switch self { case .executableNotFound(let name): "\(name) was not found."; case .timedOut: "The command timed out."; case .failed(let message): message } }
}

actor ProcessRunner {
    func run(executable: String, arguments: [String], input: String? = nil, timeout: TimeInterval) async throws -> ProcessOutput {
        guard FileManager.default.isExecutableFile(atPath: executable) else { throw ProcessRunnerError.executableNotFound(executable) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe(), error = Pipe(), inputPipe = Pipe()
        process.standardOutput = output; process.standardError = error
        if input != nil { process.standardInput = inputPipe }
        do { try process.run() } catch { throw ProcessRunnerError.failed(error.localizedDescription) }
        if let input, let data = input.data(using: .utf8) { inputPipe.fileHandleForWriting.write(data); try? inputPipe.fileHandleForWriting.close() }
        let finished = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await withCheckedContinuation { continuation in process.terminationHandler = { _ in continuation.resume(returning: true) } } }
            group.addTask { try? await Task.sleep(for: .seconds(timeout)); return false }
            let first = await group.next() ?? false; group.cancelAll(); return first
        }
        guard finished else { process.terminate(); throw ProcessRunnerError.timedOut }
        let out = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
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
