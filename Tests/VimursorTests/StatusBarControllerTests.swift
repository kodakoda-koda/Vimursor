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
            onScrollMode: { scrollCalled = true }
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
            onScrollMode: { scrollCalled = true }
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
            onScrollMode: { scrollCalled = true }
        )

        controller.simulateScrollMode()
        #expect(hintCalled == false)
        #expect(searchCalled == false)
        #expect(scrollCalled == true)
    }

    @Test("メニューが正しい項目数を持つこと")
    @MainActor
    func menuHasCorrectItemCount() {
        let mockItem = MockStatusItem()
        _ = StatusBarController(
            statusItem: mockItem,
            onHintMode: {},
            onSearchMode: {},
            onScrollMode: {}
        )
        // Hint Mode, Search Mode, Scroll Mode, separator, About, separator, Quit = 7 items
        #expect(mockItem.menu?.items.count == 7)
    }

    @Test("メニュータイトルが正しいこと")
    @MainActor
    func menuItemTitlesAreCorrect() {
        let mockItem = MockStatusItem()
        _ = StatusBarController(
            statusItem: mockItem,
            onHintMode: {},
            onSearchMode: {},
            onScrollMode: {}
        )
        let titles = mockItem.menu?.items.map(\.title) ?? []
        #expect(titles.contains("Hint Mode"))
        #expect(titles.contains("Search Mode"))
        #expect(titles.contains("Scroll Mode"))
        #expect(titles.contains("About Vimursor"))
        #expect(titles.contains("Quit Vimursor"))
    }
}
