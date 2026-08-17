import AVFoundation
import Foundation

final class AudioCaptureService: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?

    var microphonePermission: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }

    func requestMicrophonePermissionIfNeeded() async -> PermissionStatus {
        guard microphonePermission == .notDetermined else { return microphonePermission }
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return microphonePermission
    }

    func start(levelHandler: @escaping @Sendable (Float) -> Void) throws {
        cancel()
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw AudioCaptureError.noInputDevice }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zerotype-\(UUID().uuidString).caf")
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        outputURL = url
        engine.inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            do { try self?.audioFile?.write(from: buffer) } catch { }
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for index in 0..<count { sum += channel[index] * channel[index] }
            levelHandler(min(1, sqrt(sum / Float(count)) * 8))
        }
        engine.prepare()
        try engine.start()
    }

    func stop() throws -> URL {
        guard let outputURL else { throw AudioCaptureError.noRecording }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        self.outputURL = nil
        return outputURL
    }

    func cancel() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        if let outputURL { try? FileManager.default.removeItem(at: outputURL) }
        outputURL = nil
    }
}

enum AudioCaptureError: LocalizedError { case noInputDevice, noRecording
    var errorDescription: String? { self == .noInputDevice ? "No microphone input is available." : "No recording was created." }
}
