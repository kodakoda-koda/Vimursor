import AppKit

// MARK: - UserDefaults キー定数

enum AppSettingsKey {
    // Appearance
    static let labelFontSize = "appearance.labelFontSize"
    static let labelTextColor = "appearance.labelTextColor"
    static let labelBackgroundColor = "appearance.labelBackgroundColor"
    static let labelBackgroundOpacity = "appearance.labelBackgroundOpacity"
    static let searchBarOpacity = "appearance.searchBarOpacity"

    // Behavior
    static let hintCharacterSet = "behavior.hintCharacterSet"
    static let isContinuousMode = "hintMode.continuousMode"  // 既存キーと互換
    static let reactivationDelay = "behavior.reactivationDelay"
    static let scrollStepLines = "behavior.scrollStepLines"
}

// MARK: - AppSettings

/// アプリ全体の設定を一元管理する UserDefaults ラッパー。
/// テスト時は `AppSettings(defaults: testDefaults)` で分離可能。
final class AppSettings: @unchecked Sendable {

    // MARK: - Default values

    enum Defaults {
        static let labelFontSize: CGFloat = 11
        static let labelTextColor: NSColor = .black
        static let labelBackgroundColor: NSColor = .white
        static let labelBackgroundOpacity: CGFloat = 0.95
        static let searchBarOpacity: CGFloat = 1.0
        static let hintCharacterSet: String = "fjrieodkslapnvmc"
        static let isContinuousMode: Bool = true
        static let reactivationDelay: TimeInterval = 0.3
        static let scrollStepLines: Int = 3
    }

    // MARK: - Storage

    let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            AppSettingsKey.labelFontSize: Defaults.labelFontSize,
            AppSettingsKey.labelBackgroundOpacity: Defaults.labelBackgroundOpacity,
            AppSettingsKey.searchBarOpacity: Defaults.searchBarOpacity,
            AppSettingsKey.hintCharacterSet: Defaults.hintCharacterSet,
            AppSettingsKey.isContinuousMode: Defaults.isContinuousMode,
            AppSettingsKey.reactivationDelay: Defaults.reactivationDelay,
            AppSettingsKey.scrollStepLines: Defaults.scrollStepLines
        ])
    }

    // MARK: - Shared instance

    static let shared = AppSettings()

    // MARK: - Appearance

    var labelFontSize: CGFloat {
        get { CGFloat(defaults.double(forKey: AppSettingsKey.labelFontSize)) }
        set { defaults.set(Double(newValue), forKey: AppSettingsKey.labelFontSize) }
    }

    var labelTextColor: NSColor {
        get { loadColor(forKey: AppSettingsKey.labelTextColor) ?? Defaults.labelTextColor }
        set { saveColor(newValue, forKey: AppSettingsKey.labelTextColor) }
    }

    var labelBackgroundColor: NSColor {
        get { loadColor(forKey: AppSettingsKey.labelBackgroundColor) ?? Defaults.labelBackgroundColor }
        set { saveColor(newValue, forKey: AppSettingsKey.labelBackgroundColor) }
    }

    var labelBackgroundOpacity: CGFloat {
        get { CGFloat(defaults.double(forKey: AppSettingsKey.labelBackgroundOpacity)) }
        set { defaults.set(Double(newValue), forKey: AppSettingsKey.labelBackgroundOpacity) }
    }

    var searchBarOpacity: CGFloat {
        get { CGFloat(defaults.double(forKey: AppSettingsKey.searchBarOpacity)) }
        set { defaults.set(Double(newValue), forKey: AppSettingsKey.searchBarOpacity) }
    }

    // MARK: - Behavior

    var hintCharacterSet: String {
        get { defaults.string(forKey: AppSettingsKey.hintCharacterSet) ?? Defaults.hintCharacterSet }
        set { defaults.set(newValue, forKey: AppSettingsKey.hintCharacterSet) }
    }

    var isContinuousMode: Bool {
        get { defaults.bool(forKey: AppSettingsKey.isContinuousMode) }
        set { defaults.set(newValue, forKey: AppSettingsKey.isContinuousMode) }
    }

    var reactivationDelay: TimeInterval {
        get { defaults.double(forKey: AppSettingsKey.reactivationDelay) }
        set { defaults.set(newValue, forKey: AppSettingsKey.reactivationDelay) }
    }

    var scrollStepLines: Int {
        get { defaults.integer(forKey: AppSettingsKey.scrollStepLines) }
        set { defaults.set(newValue, forKey: AppSettingsKey.scrollStepLines) }
    }

    // MARK: - Reset

    /// 全設定をデフォルト値にリセットする。
    func resetToDefaults() {
        let keys = [
            AppSettingsKey.labelFontSize,
            AppSettingsKey.labelTextColor,
            AppSettingsKey.labelBackgroundColor,
            AppSettingsKey.labelBackgroundOpacity,
            AppSettingsKey.searchBarOpacity,
            AppSettingsKey.hintCharacterSet,
            AppSettingsKey.isContinuousMode,
            AppSettingsKey.reactivationDelay,
            AppSettingsKey.scrollStepLines
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Toggle helpers (互換性維持)

    /// `isContinuousMode` を反転する。
    func toggleContinuousMode() {
        defaults.set(!isContinuousMode, forKey: AppSettingsKey.isContinuousMode)
    }

    // MARK: - NSColor 永続化

    private func saveColor(_ color: NSColor, forKey key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: color,
            requiringSecureCoding: true
        ) else {
            return  // アーカイブ失敗は無視（デフォルトにフォールバック）
        }
        defaults.set(data, forKey: key)
    }

    private func loadColor(forKey key: String) -> NSColor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }
}
