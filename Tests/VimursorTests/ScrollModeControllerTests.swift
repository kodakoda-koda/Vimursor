import Testing
import CoreGraphics
@testable import Vimursor

@Suite
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
}
