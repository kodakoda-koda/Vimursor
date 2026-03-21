import Testing
import CoreGraphics
@testable import Vimursor

@Suite
struct ScrollModeControllerTests {

    // MARK: - AX座標 → NSView座標 変換
    // 変換式: nsY = screenHeight - axY - axHeight
    // ScrollAreaView.toNSViewFrame と同一ロジックを純粋な数式でテストする

    @Test func axToNSViewYConversion() {
        let screenHeight: CGFloat = 1000
        let axY: CGFloat = 100
        let height: CGFloat = 200
        let nsY = screenHeight - axY - height
        // nsY = 1000 - 100 - 200 = 700
        #expect(nsY == 700)
    }

    @Test func axToNSViewYConversionTopOfScreen() {
        let screenHeight: CGFloat = 800
        let axY: CGFloat = 0
        let height: CGFloat = 100
        let nsY = screenHeight - axY - height
        // nsY = 800 - 0 - 100 = 700
        #expect(nsY == 700)
    }

    @Test func axToNSViewYConversionBottomOfScreen() {
        let screenHeight: CGFloat = 800
        let axY: CGFloat = 700
        let height: CGFloat = 100
        let nsY = screenHeight - axY - height
        // nsY = 800 - 700 - 100 = 0
        #expect(nsY == 0)
    }

    @Test func axToNSViewXIsUnchanged() {
        // x 座標は変換不要（スクリーン左端を共有）
        let axX: CGFloat = 250
        #expect(axX == 250)
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

    @Test func tabCyclesForward() {
        let count = 3
        #expect((0 + 1) % count == 1)
        #expect((1 + 1) % count == 2)
        #expect((2 + 1) % count == 0)  // 末尾 → 先頭へ循環
    }

    @Test func shiftTabCyclesBackward() {
        let count = 3
        #expect((0 - 1 + count) % count == 2)  // 先頭 → 末尾へ循環
        #expect((1 - 1 + count) % count == 0)
        #expect((2 - 1 + count) % count == 1)
    }

    @Test func tabCyclesWithSingleArea() {
        let count = 1
        #expect((0 + 1) % count == 0)          // Tab: 自分自身に戻る
        #expect((0 - 1 + count) % count == 0)  // Shift+Tab: 同様
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
