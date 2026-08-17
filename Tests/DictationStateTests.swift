import XCTest
@testable import VoiceWritingAssistant

final class DictationStateTests: XCTestCase {
    func testTerminalStatesCanStartAnotherDictation() {
        XCTAssertTrue(DictationState.idle.canStart)
        XCTAssertTrue(DictationState.completed.canStart)
        XCTAssertTrue(DictationState.failed("test").canStart)
    }
    func testRecordingIsBusy() { XCTAssertTrue(DictationState.recording.isBusy) }
}
