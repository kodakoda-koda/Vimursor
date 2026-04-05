import Foundation
import Testing
@testable import Vimursor

@Suite
struct HintModeSettingsTests {

    // テスト用に分離した UserDefaults を使う
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    @Test @MainActor func defaultIsContinuousMode() {
        let settings = HintModeSettings(defaults: makeDefaults())
        #expect(settings.isContinuousMode == true)
    }

    @Test @MainActor func toggleSwitchesMode() {
        let settings = HintModeSettings(defaults: makeDefaults())
        settings.toggle()
        #expect(settings.isContinuousMode == false)
        settings.toggle()
        #expect(settings.isContinuousMode == true)
    }

    @Test @MainActor func settingIsPersisted() {
        let defaults = makeDefaults()
        let settings1 = HintModeSettings(defaults: defaults)
        settings1.toggle()  // true → false
        let settings2 = HintModeSettings(defaults: defaults)
        #expect(settings2.isContinuousMode == false)
    }
}
