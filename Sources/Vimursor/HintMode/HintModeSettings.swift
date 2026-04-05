import Foundation

enum HintModeDefaultsKey {
    static let continuousMode = "hintMode.continuousMode"
}

final class HintModeSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [HintModeDefaultsKey.continuousMode: true])
    }

    var isContinuousMode: Bool {
        defaults.bool(forKey: HintModeDefaultsKey.continuousMode)
    }

    func toggle() {
        defaults.set(!isContinuousMode, forKey: HintModeDefaultsKey.continuousMode)
    }
}
