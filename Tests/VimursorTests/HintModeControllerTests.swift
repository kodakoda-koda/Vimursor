import Foundation
import Testing
@testable import Vimursor

@Suite
struct HintModeControllerTests {

    // MARK: - reactivationDelay 定数

    @Test @MainActor func reactivationDelayIsThreeHundredMilliseconds() {
        #expect(HintModeController.reactivationDelay == 0.3)
    }

    // MARK: - deactivate() が reactivationTask をクリアすること

    @Test @MainActor func deactivateClearsReactivationTask() {
        let controller = HintModeController()
        controller.deactivate()
        #expect(controller.reactivationTask == nil)
    }
}
