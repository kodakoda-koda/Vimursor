import Foundation
import ServiceManagement
import os

private let logger = Logger(subsystem: "com.vimursor.app", category: "LoginItem")

// MARK: - Protocol

/// ログインアイテム登録・解除の抽象化。
/// 本番では SMAppService.mainApp をラップ、テストではモックを注入する。
@MainActor
protocol LoginItemService {
    /// 現在のシステム登録状態を返す。
    var isEnabled: Bool { get }
    /// ログインアイテムに登録する。
    func enable() throws
    /// ログインアイテムから解除する。
    func disable() throws
}

// MARK: - Production implementation

/// SMAppService.mainApp をラップした本番用実装。
@MainActor
struct SMLoginItemService: LoginItemService {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}

// MARK: - Manager

enum LoginItemDefaultsKey {
    static let launchAtLogin = "launchAtLogin"
}

/// ログインアイテム登録の状態管理と UserDefaults 永続化を担当するクラス。
/// toggle() 失敗時はロールバックを行い、ログを出力する。
@MainActor
final class LoginItemManager {

    // MARK: - Private properties

    private let service: any LoginItemService
    private let defaults: UserDefaults

    // MARK: - Public properties

    /// UserDefaults に保存された「ログイン時起動」の状態。
    var isEnabled: Bool {
        defaults.bool(forKey: LoginItemDefaultsKey.launchAtLogin)
    }

    // MARK: - Initialization

    /// 本番用イニシャライザ。SMLoginItemService を使う。
    convenience init(defaults: UserDefaults = .standard) {
        self.init(service: SMLoginItemService(), defaults: defaults)
    }

    /// テスト・DI 用イニシャライザ。任意の LoginItemService を注入できる。
    init(service: any LoginItemService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    // MARK: - Public methods

    /// ログイン時起動をトグルする。
    /// UserDefaults を先に更新し、SMAppService への登録・解除を試みる。
    /// 失敗した場合は UserDefaults をロールバックしてログを出力する。
    func toggle() {
        let newValue = !isEnabled
        defaults.set(newValue, forKey: LoginItemDefaultsKey.launchAtLogin)
        do {
            if newValue {
                try service.enable()
            } else {
                try service.disable()
            }
        } catch {
            // ロールバック: SMAppService 操作が失敗したため UserDefaults を元に戻す
            defaults.set(!newValue, forKey: LoginItemDefaultsKey.launchAtLogin)
            logger.error("ログインアイテムの変更に失敗: \(error.localizedDescription)")
        }
    }

    /// SMAppService の実態と UserDefaults を同期する。
    /// 起動時に呼び出し、外部での変更（システム設定での手動変更等）を反映する。
    func syncWithSystem() {
        let systemEnabled = service.isEnabled
        if isEnabled != systemEnabled {
            defaults.set(systemEnabled, forKey: LoginItemDefaultsKey.launchAtLogin)
        }
    }
}
