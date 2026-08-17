import ApplicationServices
import Foundation

final class AccessibilityPermissionService {
    var status: PermissionStatus { AXIsProcessTrusted() ? .granted : .denied }
    func request() { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) }
}
