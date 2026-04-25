import AppKit
import Testing
@testable import Vimursor

// MARK: - Mock

/// NSStatusBar を呼ばずに StatusBarController をテストするためのモック。
@MainActor
final class MockStatusItem: StatusItemProvider {
    var button: NSStatusBarButton? { nil }
    var menu: NSMenu?
}

// MARK: - Tests

@Suite("StatusBarControllerTests")
struct StatusBarControllerTests {

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test("onHintMode クロージャが呼ばれること")
    @MainActor
    func hintModeCallbackIsInvoked() {
        var hintCalled = false
        var searchCalled = false
        var scrollCalled = false

        let controller = StatusBarController(
            statusItem: MockStatusItem(),
            onHintMode: { hintCalled = true },
            onSearchMode: { searchCalled = true },
            onScrollMode: { scrollCalled = true },
            settings: makeSettings()
        )

        controller.simulateHintMode()
        #expect(hintCalled == true)
        #expect(searchCalled == false)
        #expect(scrollCalled == false)
    }

    @Test("onSearchMode クロージャが呼ばれること")
    @MainActor
    func searchModeCallbackIsInvoked() {
        var hintCalled = false
        var searchCalled = false
        var scrollCalled = false

        let controller = StatusBarController(
            statusItem: MockStatusItem(),
            onHintMode: { hintCalled = true },
            onSearchMode: { searchCalled = true },
            onScrollMode: { scrollCalled = true },
            settings: makeSettings()
        )

        controller.simulateSearchMode()
        #expect(hintCalled == false)
        #expect(searchCalled == true)
        #expect(scrollCalled == false)
    }

    @Test("onScrollMode クロージャが呼ばれること")
    @MainActor
    func scrollModeCallbackIsInvoked() {
        var hintCalled = false
        var searchCalled = false
        var scrollCalled = false

        let controller = StatusBarController(
            statusItem: MockStatusItem(),
            onHintMode: { hintCalled = true },
            onSearchMode: { searchCalled = true },
            onScrollMode: { scrollCalled = true },
            settings: makeSettings()
        )

        controller.simulateScrollMode()
        #expect(hintCalled == false)
        #expect(searchCalled == false)
        #expect(scrollCalled == true)
    }

    @Test("onSettings クロージャが呼ばれること")
    @MainActor
    func settingsCallbackIsInvoked() {
        var settingsCalled = false
        let controller = StatusBarController(
            statusItem: MockStatusItem(),
            onHintMode: {},
            onSearchMode: {},
            onScrollMode: {},
            onSettings: { settingsCalled = true },
            settings: makeSettings()
        )
        controller.simulateSettings()
        #expect(settingsCalled == true)
    }

    @Test("メニューが正しい項目数を持つこと")
    @MainActor
    func menuHasCorrectItemCount() {
        let mockItem = MockStatusItem()
        _ = StatusBarController(
            statusItem: mockItem,
            onHintMode: {},
            onSearchMode: {},
            onScrollMode: {},
            settings: makeSettings()
        )
        // Hint Mode, Search Mode, Scroll Mode, separator, Settings..., About, separator,
        // Continuous Hint Mode, Launch at Login, separator, Quit = 11 items
        #expect(mockItem.menu?.items.count == 11)
    }

    @Test("メニューに Continuous Hint Mode 項目が含まれること")
    @MainActor
    func menuContainsContinuousHintModeItem() {
        let mockItem = MockStatusItem()
        _ = StatusBarController(
            statusItem: mockItem,
            onHintMode: {},
            onSearchMode: {},
            onScrollMode: {},
            settings: makeSettings()
        )
        let titles = mockItem.menu?.items.map(\.title) ?? []
        #expect(titles.contains("Continuous Hint Mode"))
    }

    @Test("メニュータイトルが正しいこと")
    @MainActor
    func menuItemTitlesAreCorrect() {
        let mockItem = MockStatusItem()
        _ = StatusBarController(
            statusItem: mockItem,
            onHintMode: {},
            onSearchMode: {},
            onScrollMode: {},
            settings: makeSettings()
        )
        let titles = mockItem.menu?.items.map(\.title) ?? []
        #expect(titles.contains("Hint Mode"))
        #expect(titles.contains("Search Mode"))
        #expect(titles.contains("Scroll Mode"))
        #expect(titles.contains("Settings..."))
        #expect(titles.contains("About Vimursor"))
        #expect(titles.contains("Launch at Login"))
        #expect(titles.contains("Quit Vimursor"))
    }
}
