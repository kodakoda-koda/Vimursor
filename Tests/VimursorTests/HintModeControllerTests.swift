import Foundation
import Testing
@testable import Vimursor

@Suite
struct HintModeControllerTests {

    // MARK: - reactivationDelay 定数

    private func makeSettings() -> HintModeSettings {
        HintModeSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test @MainActor func reactivationDelayIsThreeHundredMilliseconds() {
        #expect(HintModeController.reactivationDelay == 0.3)
    }

    // MARK: - deactivate() が reactivationTask をクリアすること

    @Test @MainActor func deactivateClearsReactivationTask() {
        let controller = HintModeController(settings: makeSettings())
        controller.deactivate()
        #expect(controller.reactivationTask == nil)
    }

    // MARK: - HintModeSettings の注入

    @Test @MainActor func controllerAcceptsSettings() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = HintModeSettings(defaults: defaults)
        let controller = HintModeController(settings: settings)
        // settings が注入できることを確認（コンパイル通過 + deactivate が壊れない）
        controller.deactivate()
        #expect(controller.reactivationTask == nil)
    }
}
