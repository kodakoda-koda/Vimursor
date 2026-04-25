import Testing
@testable import Vimursor

@Suite
struct ScrollEngineTests {

    @Test
    func stepDownIsNegative() {
        let amount = ScrollAmount.step(direction: .down)
        #expect(amount.lines < 0, "下スクロールは負の wheel1 値")
    }

    @Test
    func stepUpIsPositive() {
        let amount = ScrollAmount.step(direction: .up)
        #expect(amount.lines > 0, "上スクロールは正の wheel1 値")
    }

    @Test
    func halfPageDownHasLargerMagnitudeThanStep() {
        let step = ScrollAmount.step(direction: .down)
        let halfPage = ScrollAmount.halfPage(direction: .down)
        #expect(halfPage.lines < step.lines, "半ページは1ステップより大きな絶対値を持つ")
    }

    @Test
    func halfPageUpHasLargerMagnitudeThanStep() {
        let step = ScrollAmount.step(direction: .up)
        let halfPage = ScrollAmount.halfPage(direction: .up)
        #expect(halfPage.lines > step.lines)
    }

    @Test
    func upDownSymmetry() {
        let down = ScrollAmount.step(direction: .down)
        let up = ScrollAmount.step(direction: .up)
        #expect(down.lines == -up.lines, "上下は符号反転で対称")
    }

    @Test
    func halfPageUpDownSymmetry() {
        let down = ScrollAmount.halfPage(direction: .down)
        let up = ScrollAmount.halfPage(direction: .up)
        #expect(down.lines == -up.lines)
    }

    @Test
    func stepAndHalfPageRatio() {
        let step = abs(Int(ScrollAmount.step(direction: .down).lines))
        let halfPage = abs(Int(ScrollAmount.halfPage(direction: .down).lines))
        #expect(halfPage > step * 3, "半ページは1ステップの3倍以上")
    }

    // scrollToExtreme は CGEvent を直接 post するため、
    // 単体テストでは ScrollEngine.scroll の既存テストで
    // ScrollAmount の符号・大きさを検証し、
    // scrollToExtreme の動作は手動テストで確認する。
}
