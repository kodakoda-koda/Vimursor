import AppKit
import Testing
@testable import Vimursor

@Suite("AppSettings Tests")
struct AppSettingsTests {

    // テスト用に分離した UserDefaults を使う
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: makeDefaults())
    }

    // MARK: - Default Values

    @Test("labelFontSize のデフォルト値は 11")
    func defaultLabelFontSize() {
        let settings = makeSettings()
        #expect(settings.labelFontSize == 11)
    }

    @Test("labelBackgroundOpacity のデフォルト値は 0.95")
    func defaultLabelBackgroundOpacity() {
        let settings = makeSettings()
        #expect(settings.labelBackgroundOpacity == 0.95)
    }

    @Test("searchBarOpacity のデフォルト値は 1.0")
    func defaultSearchBarOpacity() {
        let settings = makeSettings()
        #expect(settings.searchBarOpacity == 1.0)
    }

    @Test("hintCharacterSet のデフォルト値は LabelGenerator と同じ文字列")
    func defaultHintCharacterSet() {
        let settings = makeSettings()
        #expect(settings.hintCharacterSet == "fjrieodkslapnvmc")
    }

    @Test("isContinuousMode のデフォルト値は true")
    func defaultIsContinuousMode() {
        let settings = makeSettings()
        #expect(settings.isContinuousMode == true)
    }

    @Test("reactivationDelay のデフォルト値は 0.3")
    func defaultReactivationDelay() {
        let settings = makeSettings()
        #expect(settings.reactivationDelay == 0.3)
    }

    @Test("scrollStepLines のデフォルト値は 3")
    func defaultScrollStepLines() {
        let settings = makeSettings()
        #expect(settings.scrollStepLines == 3)
    }

    // MARK: - Read/Write

    @Test("labelFontSize の書き込みと読み出し")
    func readWriteLabelFontSize() {
        let settings = makeSettings()
        settings.labelFontSize = 14
        #expect(settings.labelFontSize == 14)
    }

    @Test("labelBackgroundOpacity の書き込みと読み出し")
    func readWriteLabelBackgroundOpacity() {
        let settings = makeSettings()
        settings.labelBackgroundOpacity = 0.8
        #expect(abs(settings.labelBackgroundOpacity - 0.8) < 0.001)
    }

    @Test("hintCharacterSet の書き込みと読み出し")
    func readWriteHintCharacterSet() {
        let settings = makeSettings()
        settings.hintCharacterSet = "asdf"
        #expect(settings.hintCharacterSet == "asdf")
    }

    @Test("isContinuousMode の書き込みと読み出し")
    func readWriteIsContinuousMode() {
        let settings = makeSettings()
        settings.isContinuousMode = false
        #expect(settings.isContinuousMode == false)
    }

    @Test("scrollStepLines の書き込みと読み出し")
    func readWriteScrollStepLines() {
        let settings = makeSettings()
        settings.scrollStepLines = 5
        #expect(settings.scrollStepLines == 5)
    }

    // MARK: - NSColor Persistence

    @Test("labelTextColor の永続化と復元")
    func persistLabelTextColor() {
        let defaults = makeDefaults()
        let settings1 = AppSettings(defaults: defaults)
        settings1.labelTextColor = .red

        let settings2 = AppSettings(defaults: defaults)
        // CGColor比較（デバイス色空間に変換して比較）
        let saved = settings2.labelTextColor.usingColorSpace(.deviceRGB)
        let expected = NSColor.red.usingColorSpace(.deviceRGB)
        #expect(saved?.redComponent ?? -1 == expected?.redComponent ?? -2)
    }

    @Test("labelBackgroundColor の永続化と復元")
    func persistLabelBackgroundColor() {
        let defaults = makeDefaults()
        let settings1 = AppSettings(defaults: defaults)
        settings1.labelBackgroundColor = .blue

        let settings2 = AppSettings(defaults: defaults)
        let saved = settings2.labelBackgroundColor.usingColorSpace(.deviceRGB)
        let expected = NSColor.blue.usingColorSpace(.deviceRGB)
        #expect(saved?.blueComponent ?? -1 == expected?.blueComponent ?? -2)
    }

    @Test("NSColor データが存在しない場合はデフォルト値を返す")
    func colorFallsBackToDefaultWhenNotSet() {
        let settings = makeSettings()
        // データを書き込まずに読み出すとデフォルト値が返る
        let color = settings.labelTextColor
        #expect(color == AppSettings.Defaults.labelTextColor)
    }

    // MARK: - resetToDefaults()

    @Test("resetToDefaults() で全設定が初期値に戻ること")
    func resetToDefaultsRestoresAllValues() {
        let settings = makeSettings()
        // 全設定を変更
        settings.labelFontSize = 20
        settings.labelBackgroundOpacity = 0.5
        settings.searchBarOpacity = 0.7
        settings.hintCharacterSet = "xyz"
        settings.isContinuousMode = false
        settings.reactivationDelay = 1.0
        settings.scrollStepLines = 10
        settings.labelTextColor = .red
        settings.labelBackgroundColor = .blue

        settings.resetToDefaults()

        #expect(settings.labelFontSize == AppSettings.Defaults.labelFontSize)
        #expect(settings.labelBackgroundOpacity == AppSettings.Defaults.labelBackgroundOpacity)
        #expect(settings.searchBarOpacity == AppSettings.Defaults.searchBarOpacity)
        #expect(settings.hintCharacterSet == AppSettings.Defaults.hintCharacterSet)
        #expect(settings.isContinuousMode == AppSettings.Defaults.isContinuousMode)
        #expect(settings.reactivationDelay == AppSettings.Defaults.reactivationDelay)
        #expect(settings.scrollStepLines == AppSettings.Defaults.scrollStepLines)
        #expect(settings.labelTextColor == AppSettings.Defaults.labelTextColor)
        #expect(settings.labelBackgroundColor == AppSettings.Defaults.labelBackgroundColor)
    }

    // MARK: - isContinuousMode キー互換性

    @Test("isContinuousMode は HintModeSettings と同じ UserDefaults キーを使う")
    func continuousModeKeyIsCompatible() {
        let defaults = makeDefaults()
        // HintModeSettings と同じキー "hintMode.continuousMode" で保存されることを検証
        defaults.set(false, forKey: "hintMode.continuousMode")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.isContinuousMode == false)
    }

    @Test("toggleContinuousMode() で isContinuousMode が反転すること")
    func toggleContinuousMode() {
        let settings = makeSettings()
        #expect(settings.isContinuousMode == true)
        settings.toggleContinuousMode()
        #expect(settings.isContinuousMode == false)
        settings.toggleContinuousMode()
        #expect(settings.isContinuousMode == true)
    }
}
