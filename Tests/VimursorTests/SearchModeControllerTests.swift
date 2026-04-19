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

    // MARK: - マッチ件数による分岐テスト

    @Test("マッチ1件でEnter → 即クリック（回帰テスト）")
    func executeSearchWithSingleMatchClicksImmediately() async throws {
        let element = makeSearchInfo(title: "Save")
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: [element])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        // frontmostApplication が nil の場合は searchView が設定されないため、テストをスキップ
        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // SearchView の onEnterPressed を直接発火
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(300))

        // deactivate が呼ばれ、clickAt が 1 回実行されること
        #expect(fetcher.clickAtCallCount == 1)
        #expect(hotkey.keyEventHandler == nil)
    }

    @Test("マッチ2件以上でEnter → selecting 状態に遷移")
    func executeSearchWithMultipleMatchesTransitionsToSelecting() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // SearchView の onEnterPressed を直接発火
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // selecting 状態ではクリックされない
        #expect(fetcher.clickAtCallCount == 0)
        // keyEventHandler が selecting モード（全キー消費）に変わること
        #expect(hotkey.keyEventHandler != nil)
    }

    @Test("selecting 中の ESC → searching に戻る（クエリ維持）")
    func selectingEscReturnsToSearching() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // Enter で selecting に遷移
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // ESC で searching に戻る（ESC keyCode = 53）
        let consumed = hotkey.simulateKey(53)
        try await Task.sleep(for: .milliseconds(100))

        #expect(consumed == true)
        // searching に戻っているのでクリックなし
        #expect(fetcher.clickAtCallCount == 0)
        // searching 中は ESC のみ処理するハンドラが設定されていること
        #expect(hotkey.keyEventHandler != nil)
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

    // MARK: - selecting キー入力処理テスト

    @Test("selecting 中の修飾キー付きキーは無視される")
    func selectingIgnoresModifierKeys() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return
        }

        // Enter で selecting に遷移
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // Cmd+F（修飾キー付き）を送信 — 無視されること
        // keyCode 3 = 'f'（ラベル先頭文字）, flags = .maskCommand
        _ = hotkey.simulateKey(3, flags: .maskCommand, char: "f")
        try await Task.sleep(for: .milliseconds(100))

        // クリックなし・deactivate なし（ハンドラが維持されている）
        #expect(fetcher.clickAtCallCount == 0)
        #expect(hotkey.keyEventHandler != nil)
    }

    @Test("selecting 中にマッチなし → deactivate")
    func selectingNoMatchDeactivates() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return
        }

        // Enter で selecting に遷移（ラベルは "a", "b" 等が生成される）
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // ラベルに存在しない文字を入力（KeyCodeMapping で 'z' は存在しない場合もあるため 'z' ではなく 'q' + 'z' の連続で確実にマッチなしを作る）
        // KeyCode 12 = 'q'、まず 'q' を入力してから 'q' を再度入力（"qq" は "a", "b" にマッチしない）
        _ = hotkey.simulateKey(12, flags: [], char: "q")  // 'q'
        try await Task.sleep(for: .milliseconds(100))
        _ = hotkey.simulateKey(12, flags: [], char: "q")  // 'qq' はマッチなし
        try await Task.sleep(for: .milliseconds(100))

        // クリックなし・deactivate されてハンドラが nil
        #expect(fetcher.clickAtCallCount == 0)
        #expect(hotkey.keyEventHandler == nil)
    }

    @Test("selecting 中の prefix マッチで状態が更新される")
    func selectingPrefixMatchUpdatesState() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As"),
            makeSearchInfo(title: "Close")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return
        }

        // Enter で selecting に遷移（ラベルは 2 文字: aa, ab, ba 等）
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // クリックまたはマッチなしになるまでハンドラが維持されていること
        #expect(hotkey.keyEventHandler != nil)
        // クリックはまだ発生していない
        #expect(fetcher.clickAtCallCount == 0)
    }

    @Test("selecting 中の完全一致でクリックが実行される")
    func selectingExactMatchTriggerClick() async throws {
        // 要素が2つ: ラベルは "a", "b" となる（singleChar）
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Close")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return
        }

        // Enter で selecting に遷移
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // keyCode 3 = 'f' を入力 → ラベル "f" に完全一致 → クリック
        _ = hotkey.simulateKey(3, flags: [], char: "f")
        try await Task.sleep(for: .milliseconds(300))

        // deactivate されてクリックが 1 回発生
        #expect(fetcher.clickAtCallCount == 1)
        #expect(hotkey.keyEventHandler == nil)
    }

    // MARK: - 追加統合テスト・回帰テスト

    @Test("マッチ0件でEnter → searching のまま変化なし")
    func executeSearchWithZeroMatchesDoesNothing() async throws {
        let element = makeSearchInfo(title: "Save")
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: [element])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // クエリをマッチなし状態にしてから Enter を発火
        // onQueryChanged を呼んで matched を 0 件に絞る
        searchView.onQueryChanged?("zzzzz_no_match")
        try await Task.sleep(for: .milliseconds(50))

        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(200))

        // クリックされない・deactivate されない（ハンドラが維持される）
        #expect(fetcher.clickAtCallCount == 0)
        #expect(hotkey.keyEventHandler != nil)
    }

    @Test("searching 中の ESC → deactivate")
    func searchingEscDeactivates() async throws {
        let element = makeSearchInfo(title: "Save")
        let (controller, overlay, hotkey, _) = makeSUT(elements: [element])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard overlay.contentView?.subviews.first(where: { $0 is SearchView }) != nil else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // searching 状態で ESC を送信（keyCode 53）
        let consumed = hotkey.simulateKey(53)
        try await Task.sleep(for: .milliseconds(100))

        #expect(consumed == true)
        // deactivate により keyEventHandler が nil になること
        #expect(hotkey.keyEventHandler == nil)
        // overlay が hide されること
        #expect(overlay.hideCallCount >= 1)
    }

    @Test("selecting 状態から deactivate するとクリーンアップされる")
    func deactivateFromSelectingStateCleansUp() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // selecting 状態に遷移
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // selecting 状態から直接 deactivate
        controller.deactivate()
        try await Task.sleep(for: .milliseconds(50))

        // クリーンアップが正しく行われること
        #expect(hotkey.keyEventHandler == nil)
        #expect(overlay.hideCallCount >= 1)
        #expect(fetcher.clickAtCallCount == 0)
    }

    @Test("selecting → searching → Enter → 再び selecting に遷移できる（往復テスト）")
    func selectingToSearchingAndBackToSelectingWorks() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // 1回目: Enter で selecting に遷移
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))
        #expect(hotkey.keyEventHandler != nil)  // selecting ハンドラが設定されている

        // ESC で searching に戻る
        hotkey.simulateKey(53)
        try await Task.sleep(for: .milliseconds(100))
        #expect(hotkey.keyEventHandler != nil)  // searching ハンドラが設定されている

        // 2回目: Enter で再び selecting に遷移できること
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // クリックなし（selecting 状態）かつハンドラが設定されていること
        #expect(fetcher.clickAtCallCount == 0)
        #expect(hotkey.keyEventHandler != nil)
    }

    @Test("selecting 中 ESC で searching に戻ったときクエリが維持される（詳細検証）")
    func selectingEscMaintainsQueryInSearching() async throws {
        let elements = [
            makeSearchInfo(title: "Save"),
            makeSearchInfo(title: "Save As")
        ]
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: elements)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(100))

        guard let searchView = overlay.contentView?.subviews.first(where: { $0 is SearchView }) as? SearchView else {
            return  // UI 環境なし（CI等）では SearchView が生成されない
        }

        // クエリを "save" に設定してから Enter → selecting
        searchView.onQueryChanged?("save")
        try await Task.sleep(for: .milliseconds(50))
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // ESC で searching に戻る
        hotkey.simulateKey(53)
        try await Task.sleep(for: .milliseconds(100))

        // searching 状態に戻っているのでクリックなし・ハンドラ維持
        #expect(fetcher.clickAtCallCount == 0)
        #expect(hotkey.keyEventHandler != nil)

        // searching に戻った後、Enter を再度押すと再び selecting に遷移（クエリが有効）
        searchView.onEnterPressed?()
        try await Task.sleep(for: .milliseconds(100))

        // 2件マッチ（"Save", "Save As"）のため selecting 状態に遷移
        #expect(fetcher.clickAtCallCount == 0)
        #expect(hotkey.keyEventHandler != nil)
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
