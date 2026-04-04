import Foundation
import Testing
@testable import Vimursor

// MARK: - Mock

/// LoginItemService のモック実装。
/// class を使う理由: テスト内で enableCallCount / disableCallCount を変異させる必要があるため、
/// 値型では #expect() 内のキャプチャが想定どおりに動作しない。
/// @MainActor は不要 (プロトコル自体が @MainActor のため自動的に適用される)
final class MockLoginItemService: LoginItemService {
    var systemEnabled: Bool = false
    var enableCallCount: Int = 0
    var disableCallCount: Int = 0
    var shouldThrowOnEnable: Bool = false
    var shouldThrowOnDisable: Bool = false

    var isEnabled: Bool { systemEnabled }

    func enable() throws {
        if shouldThrowOnEnable {
            throw NSError(domain: "MockLoginItemService", code: 1, userInfo: [NSLocalizedDescriptionKey: "enable failed"])
        }
        enableCallCount += 1
        systemEnabled = true
    }

    func disable() throws {
        if shouldThrowOnDisable {
            throw NSError(domain: "MockLoginItemService", code: 2, userInfo: [NSLocalizedDescriptionKey: "disable failed"])
        }
        disableCallCount += 1
        systemEnabled = false
    }
}

// MARK: - Tests

@Suite("LoginItemManagerTests")
struct LoginItemManagerTests {

    // MARK: - toggle: ON

    @Test("toggle() で OFF → ON になること")
    @MainActor
    func toggleEnablesLoginItem() {
        let mockService = MockLoginItemService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        // 初期状態は OFF
        #expect(manager.isEnabled == false)

        manager.toggle()

        #expect(manager.isEnabled == true)
        #expect(mockService.enableCallCount == 1)
        #expect(mockService.disableCallCount == 0)
    }

    // MARK: - toggle: OFF

    @Test("toggle() で ON → OFF になること")
    @MainActor
    func toggleDisablesLoginItem() {
        let mockService = MockLoginItemService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: LoginItemDefaultsKey.launchAtLogin)
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        // 初期状態は ON
        #expect(manager.isEnabled == true)

        manager.toggle()

        #expect(manager.isEnabled == false)
        #expect(mockService.enableCallCount == 0)
        #expect(mockService.disableCallCount == 1)
    }

    // MARK: - toggle: ロールバック（enable 失敗）

    @Test("enable() が throw した場合は UserDefaults がロールバックされること")
    @MainActor
    func toggleRollsBackWhenEnableFails() {
        let mockService = MockLoginItemService()
        mockService.shouldThrowOnEnable = true
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        // 初期状態は OFF
        #expect(manager.isEnabled == false)

        manager.toggle()

        // ロールバックにより OFF のまま
        #expect(manager.isEnabled == false)
        #expect(mockService.enableCallCount == 0)
    }

    // MARK: - toggle: ロールバック（disable 失敗）

    @Test("disable() が throw した場合は UserDefaults がロールバックされること")
    @MainActor
    func toggleRollsBackWhenDisableFails() {
        let mockService = MockLoginItemService()
        mockService.shouldThrowOnDisable = true
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: LoginItemDefaultsKey.launchAtLogin)
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        // 初期状態は ON
        #expect(manager.isEnabled == true)

        manager.toggle()

        // ロールバックにより ON のまま
        #expect(manager.isEnabled == true)
        #expect(mockService.disableCallCount == 0)
    }

    // MARK: - syncWithSystem

    @Test("syncWithSystem() でシステム状態が OFF なら UserDefaults が OFF に更新されること")
    @MainActor
    func syncWithSystemUpdatesDefaultsToFalse() {
        let mockService = MockLoginItemService()
        mockService.systemEnabled = false
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        // UserDefaults は ON、システムは OFF → 不整合
        defaults.set(true, forKey: LoginItemDefaultsKey.launchAtLogin)
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        manager.syncWithSystem()

        #expect(manager.isEnabled == false)
    }

    @Test("syncWithSystem() でシステム状態が ON なら UserDefaults が ON に更新されること")
    @MainActor
    func syncWithSystemUpdatesDefaultsToTrue() {
        let mockService = MockLoginItemService()
        mockService.systemEnabled = true
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        // UserDefaults は OFF、システムは ON → 不整合
        defaults.set(false, forKey: LoginItemDefaultsKey.launchAtLogin)
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        manager.syncWithSystem()

        #expect(manager.isEnabled == true)
    }

    @Test("syncWithSystem() で状態が一致していれば UserDefaults は変更されないこと")
    @MainActor
    func syncWithSystemDoesNotChangeDefaultsWhenAlreadyInSync() {
        let mockService = MockLoginItemService()
        mockService.systemEnabled = true
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: LoginItemDefaultsKey.launchAtLogin)
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        manager.syncWithSystem()

        #expect(manager.isEnabled == true)
    }

    // MARK: - isEnabled デフォルト値

    @Test("isEnabled のデフォルト値は false であること")
    @MainActor
    func isEnabledDefaultsToFalse() {
        let mockService = MockLoginItemService()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = LoginItemManager(service: mockService, defaults: defaults)

        #expect(manager.isEnabled == false)
    }
}
