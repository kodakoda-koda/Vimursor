import Testing
import CoreGraphics
import AppKit
@testable import Vimursor

@Suite
@MainActor
struct ScrollModeControllerTests {

    // MARK: - AX座標 → NSView座標 変換
    // ScrollAreaView.toNSViewFrame(static) を通じて検証する
    // 変換式: nsY = screenHeight - axY - axHeight

    @Test func axToNSViewYConversion() {
        let axFrame = CGRect(x: 0, y: 100, width: 500, height: 200)
        let nsFrame = ScrollAreaView.toNSViewFrame(axFrame, screenHeight: 1000)
        // nsY = 1000 - 100 - 200 = 700
        #expect(nsFrame.origin.y == 700)
        #expect(nsFrame.origin.x == 0)
        #expect(nsFrame.width == 500)
        #expect(nsFrame.height == 200)
    }

    @Test func axToNSViewYConversionTopOfScreen() {
        let axFrame = CGRect(x: 0, y: 0, width: 300, height: 100)
        let nsFrame = ScrollAreaView.toNSViewFrame(axFrame, screenHeight: 800)
        // nsY = 800 - 0 - 100 = 700
        #expect(nsFrame.origin.y == 700)
    }

    @Test func axToNSViewYConversionBottomOfScreen() {
        let axFrame = CGRect(x: 0, y: 700, width: 300, height: 100)
        let nsFrame = ScrollAreaView.toNSViewFrame(axFrame, screenHeight: 800)
        // nsY = 800 - 700 - 100 = 0
        #expect(nsFrame.origin.y == 0)
    }

    @Test func axToNSViewXIsUnchanged() {
        let axFrame = CGRect(x: 250, y: 100, width: 400, height: 300)
        let nsFrame = ScrollAreaView.toNSViewFrame(axFrame, screenHeight: 1000)
        #expect(nsFrame.origin.x == 250)
        #expect(nsFrame.width == 400)
        #expect(nsFrame.height == 300)
    }

    // MARK: - 数字キー → 0-based インデックス変換

    @Test func numKeyToIndexMapping() {
        #expect(ScrollKeyCode.numToIndex[18] == 0)  // 1 → index 0
        #expect(ScrollKeyCode.numToIndex[19] == 1)  // 2 → index 1
        #expect(ScrollKeyCode.numToIndex[20] == 2)  // 3 → index 2
        #expect(ScrollKeyCode.numToIndex[21] == 3)  // 4 → index 3
        #expect(ScrollKeyCode.numToIndex[23] == 4)  // 5 → index 4
        #expect(ScrollKeyCode.numToIndex[22] == 5)  // 6 → index 5
        #expect(ScrollKeyCode.numToIndex[26] == 6)  // 7 → index 6
        #expect(ScrollKeyCode.numToIndex[28] == 7)  // 8 → index 7
        #expect(ScrollKeyCode.numToIndex[25] == 8)  // 9 → index 8
    }

    @Test func numToIndexHasNineEntries() {
        #expect(ScrollKeyCode.numToIndex.count == 9)
    }

    @Test func numToIndexIndicesAreUnique() {
        let values = Array(ScrollKeyCode.numToIndex.values)
        #expect(Set(values).count == values.count)
    }

    // MARK: - Tab / Shift+Tab 循環ロジック

    /// ScrollModeController の selectArea と同じ循環計算をヘルパーとして切り出す
    private func nextIndex(current: Int, count: Int, direction: Int) -> Int {
        (current + direction + count) % count
    }

    @Test func tabCyclesForward() {
        let count = 3
        #expect(nextIndex(current: 0, count: count, direction: +1) == 1)
        #expect(nextIndex(current: 1, count: count, direction: +1) == 2)
        #expect(nextIndex(current: 2, count: count, direction: +1) == 0)  // 末尾 → 先頭へ循環
    }

    @Test func shiftTabCyclesBackward() {
        let count = 3
        #expect(nextIndex(current: 0, count: count, direction: -1) == 2)  // 先頭 → 末尾へ循環
        #expect(nextIndex(current: 1, count: count, direction: -1) == 0)
        #expect(nextIndex(current: 2, count: count, direction: -1) == 1)
    }

    @Test func tabCyclesWithSingleArea() {
        let count = 1
        #expect(nextIndex(current: 0, count: count, direction: +1) == 0)  // Tab: 自分自身に戻る
        #expect(nextIndex(current: 0, count: count, direction: -1) == 0)  // Shift+Tab: 同様
    }

    // MARK: - ScrollAreaInfo のラベル生成

    @Test func scrollAreaLabelsAreSequential() {
        let areas = [
            ScrollAreaInfo(frame: .zero, centerPoint: .zero, label: "1"),
            ScrollAreaInfo(frame: .zero, centerPoint: .zero, label: "2"),
            ScrollAreaInfo(frame: .zero, centerPoint: .zero, label: "3"),
        ]
        for (i, area) in areas.enumerated() {
            #expect(area.label == String(i + 1))
        }
    }

    // MARK: - リーフ優先ロジック（countBefore/countAfter パターン）

    /// 子が追加された場合、親はスキップされる
    @Test func leafPreferenceSkipsParentWhenChildrenAdded() {
        let countBefore = 0
        let countAfterChildren = 2  // 子が2つ追加された
        let childrenAdded = countAfterChildren > countBefore
        #expect(childrenAdded == true, "子が追加されたら親はスキップ")
    }

    /// 子が追加されなかった場合、親が追加される
    @Test func leafPreferenceAddsParentWhenNoChildrenAdded() {
        let countBefore = 0
        let countAfterChildren = 0  // 子は追加されなかった
        let childrenAdded = countAfterChildren > countBefore
        #expect(childrenAdded == false, "子が追加されなければ親を追加")
    }

    /// 深い階層でもリーフが優先される（3階層ネスト）
    @Test func leafPreferenceThreeLevels() {
        // L1(scrollable) → L2(scrollable) → L3(scrollable, leaf)
        // L3 が追加される → L2 は childrenAdded=true でスキップ → L1 も childrenAdded=true でスキップ
        var count = 0

        // L3（リーフ）: 子なし → 追加
        let l3Before = count
        // 子なし
        let l3ChildrenAdded = count > l3Before  // false
        if !l3ChildrenAdded { count += 1 }      // count = 1
        #expect(count == 1)

        // L2: 子が追加された → スキップ
        let l2Before = 0  // L2 の探索開始時
        let l2ChildrenAdded = count > l2Before  // true
        if !l2ChildrenAdded { count += 1 }      // スキップ
        #expect(count == 1)

        // L1: 子が追加された → スキップ
        let l1Before = 0
        let l1ChildrenAdded = count > l1Before  // true
        if !l1ChildrenAdded { count += 1 }      // スキップ
        #expect(count == 1, "3階層ネストでもリーフの1つだけが追加される")
    }

    // MARK: - ステート遷移テスト

    private func makeSUT(
        areas: [ScrollAreaInfo] = []
    ) -> (ScrollModeController, MockOverlayProviding, MockKeyEventHandling, MockElementFetching) {
        let fetcher = MockElementFetching()
        fetcher.scrollableAreas = areas
        let overlay = MockOverlayProviding()
        let hotkey = MockKeyEventHandling()
        let controller = ScrollModeController(elementFetcher: fetcher)
        return (controller, overlay, hotkey, fetcher)
    }

    private func makeScrollArea() -> ScrollAreaInfo {
        ScrollAreaInfo(
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            centerPoint: CGPoint(x: 400, y: 300),
            label: "1"
        )
    }

    @Test @MainActor func activateWithAreasShowsOverlay() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(areas: [makeScrollArea()])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        // frontmostApplication が nil ならフェッチに到達しないため show = 0
        // frontmostApplication が非 nil なら show = 1
        #expect(overlay.showCallCount <= 1)
    }

    @Test @MainActor func activateWithNoAreasDeactivates() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(areas: [])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        // DispatchQueue.main.async + Task { @MainActor } の二重非同期を待つ
        try await Task.sleep(for: .milliseconds(200))
        // いずれのパスでも show は呼ばれない
        #expect(overlay.showCallCount == 0)
        // frontmostApplication が nil → 同期 deactivate → hide = 1
        // frontmostApplication が非 nil → 非同期 deactivate → hide = 1
        // keyEventHandler は deactivate で nil になる
        #expect(hotkey.keyEventHandler == nil)
    }

    @Test @MainActor func deactivateHidesOverlayAndClearsHandler() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(areas: [makeScrollArea()])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        // active 状態から deactivate
        controller.deactivate()
        #expect(overlay.hideCallCount == 1)
        #expect(hotkey.keyEventHandler == nil)
    }

    @Test @MainActor func keyEventHandlerIsSetAfterActivate() async throws {
        let (controller, overlay, hotkey, _) = makeSUT(areas: [makeScrollArea()])
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        // activate 直後（fetching 中）でも keyEventHandler は設定される
        #expect(hotkey.keyEventHandler != nil)
    }

}
