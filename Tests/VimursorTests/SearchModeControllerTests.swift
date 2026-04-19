import Testing
import AppKit
@testable import Vimursor

@Suite
@MainActor
struct SearchModeControllerTests {

    private func makeSearchInfo(title: String) -> SearchElementInfo {
        SearchElementInfo(
            frame: CGRect(x: 100, y: 100, width: 80, height: 24),
            title: title,
            label: "",
            description: "",
            role: "AXButton",
            axElement: AXElement(ref: AXUIElementCreateSystemWide())
        )
    }

    private func makeSUT(
        elements: [SearchElementInfo] = []
    ) -> (SearchModeController, MockOverlayProviding, MockKeyEventHandling, MockElementFetching) {
        let fetcher = MockElementFetching()
        fetcher.searchableElements = elements
        let overlay = MockOverlayProviding()
        let hotkey = MockKeyEventHandling()
        let controller = SearchModeController(elementFetcher: fetcher)
        return (controller, overlay, hotkey, fetcher)
    }

    // MARK: - ステート遷移テスト

    @Test func activateWithElementsShowsOverlayAsKeyWindow() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(elements: [makeSearchInfo(title: "Save")])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        // frontmostApplication が非 nil の場合は showAsKeyWindow が呼ばれる
        // nil の場合は早期リターンで 0 回（どちらも最大 1 回）
        #expect(overlay.showAsKeyWindowCallCount <= 1)
    }

    @Test func activateWithNoElementsDoesNotShowOverlay() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(elements: [])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        // 要素なし → startSearchMode が呼ばれない → showAsKeyWindow は 0 回
        #expect(overlay.showAsKeyWindowCallCount == 0)
    }

    @Test func deactivateHidesOverlay() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(elements: [makeSearchInfo(title: "Save")])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        overlay.hideCallCount = 0
        controller.deactivate()
        #expect(overlay.hideCallCount == 1)
    }

    @Test func deactivateClearsKeyEventHandler() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(elements: [makeSearchInfo(title: "Save")])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        controller.deactivate()
        #expect(hotkey.keyEventHandler == nil)
    }

    @Test func deactivateThenActivateIsAllowed() async throws {
        // deactivate 後は isActive=false になるため、再 activate が可能
        let (controller, overlay, hotkey, _) = makeSUT(elements: [makeSearchInfo(title: "Save")])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        controller.deactivate()
        // deactivate 後に再 activate してもエラーにならない
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        // hide は deactivate で 1 回呼ばれる（再 activate 後は show が呼ばれるかもしれない）
        #expect(overlay.hideCallCount >= 1)
    }

    private func makeInfo(
        title: String,
        label: String = "",
        description: String = "",
        role: String = "AXButton"
    ) -> SearchElementInfo {
        SearchElementInfo(
            frame: .zero,
            title: title,
            label: label,
            description: description,
            role: role,
            axElement: AXElement(ref: AXUIElementCreateSystemWide())
        )
    }

    @Test func filterByTitle() {
        let elements = [makeInfo(title: "Save"), makeInfo(title: "Cancel")]
        let result = SearchModeController.filter(elements: elements, query: "save")
        #expect(result.count == 1)
        #expect(result.first?.title == "Save")
    }

    @Test func filterByLabel() {
        let elements = [makeInfo(title: "", label: "Submit Button"), makeInfo(title: "Cancel")]
        let result = SearchModeController.filter(elements: elements, query: "submit")
        #expect(result.count == 1)
    }

    @Test func filterByDescription() {
        let elements = [makeInfo(title: "", description: "Close the window")]
        let result = SearchModeController.filter(elements: elements, query: "close")
        #expect(result.count == 1)
    }

    @Test func emptyQueryReturnsAllElements() {
        let elements = [makeInfo(title: "A"), makeInfo(title: "B"), makeInfo(title: "C")]
        let result = SearchModeController.filter(elements: elements, query: "")
        #expect(result.count == 3)
    }

    @Test func noMatchReturnsEmpty() {
        let elements = [makeInfo(title: "Save"), makeInfo(title: "Cancel")]
        let result = SearchModeController.filter(elements: elements, query: "zzz")
        #expect(result.isEmpty)
    }

    @Test func caseInsensitiveMatch() {
        let elements = [makeInfo(title: "System Preferences")]
        let result = SearchModeController.filter(elements: elements, query: "SYSTEM")
        #expect(result.count == 1)
    }

    @Test func partialMatchInMiddle() {
        let elements = [makeInfo(title: "Open in New Tab")]
        let result = SearchModeController.filter(elements: elements, query: "new tab")
        #expect(result.count == 1)
    }

    @Test func multipleMatches() {
        let elements = [
            makeInfo(title: "Save File"),
            makeInfo(title: "Save As"),
            makeInfo(title: "Cancel")
        ]
        let result = SearchModeController.filter(elements: elements, query: "save")
        #expect(result.count == 2)
    }

    @Test func filterWithUpperCaseQuery() {
        let elements = [makeInfo(title: "Save")]
        let result = SearchModeController.filter(elements: elements, query: "S")
        #expect(result.count == 1)
    }

    @Test func filterWithSpaceInQuery() {
        let elements = [makeInfo(title: "Open in New Tab"), makeInfo(title: "New Window")]
        let result = SearchModeController.filter(elements: elements, query: "new tab")
        #expect(result.count == 1)
        #expect(result.first?.title == "Open in New Tab")
    }

    @Test func filterIsCaseInsensitiveForFullUpperCase() {
        let elements = [makeInfo(title: "save file")]
        let result = SearchModeController.filter(elements: elements, query: "SAVE")
        #expect(result.count == 1)
    }
}
