import Testing
import AppKit
@testable import Vimursor

@Suite("HintView Tests")
struct HintViewTests {

    // MARK: - labelOrigin

    @Test("通常フレーム: x は minX、y は midY - boxHeight/2")
    func normalFrame() {
        // 要素フレーム: x=100, y=200, width=80, height=40
        // midY = 200 + 40/2 = 220
        // boxHeight = 20
        // 期待 origin: (100, 220 - 10) = (100, 210)
        let frame = CGRect(x: 100, y: 200, width: 80, height: 40)
        let boxHeight: CGFloat = 20
        let origin = HintView.labelOrigin(elementFrame: frame, boxHeight: boxHeight)
        #expect(origin.x == 100)
        #expect(origin.y == 210)
    }

    @Test("小さい要素: boxHeight が要素高さより大きい場合も midY 基準で計算される")
    func smallElement() {
        // 要素フレーム: x=50, y=100, width=30, height=10
        // midY = 100 + 10/2 = 105
        // boxHeight = 20 (要素高さより大きい)
        // 期待 origin: (50, 105 - 10) = (50, 95)
        let frame = CGRect(x: 50, y: 100, width: 30, height: 10)
        let boxHeight: CGFloat = 20
        let origin = HintView.labelOrigin(elementFrame: frame, boxHeight: boxHeight)
        #expect(origin.x == 50)
        #expect(origin.y == 95)
    }

    @Test("ゼロ起点フレーム: origin が (0, 0) の要素")
    func zeroOriginFrame() {
        // 要素フレーム: x=0, y=0, width=100, height=50
        // midY = 25
        // boxHeight = 16
        // 期待 origin: (0, 25 - 8) = (0, 17)
        let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let boxHeight: CGFloat = 16
        let origin = HintView.labelOrigin(elementFrame: frame, boxHeight: boxHeight)
        #expect(origin.x == 0)
        #expect(origin.y == 17)
    }

    @Test("正方形要素: 縦中央が正確に計算される")
    func squareElement() {
        // 要素フレーム: x=10, y=10, width=60, height=60
        // midY = 10 + 30 = 40
        // boxHeight = 22
        // 期待 origin: (10, 40 - 11) = (10, 29)
        let frame = CGRect(x: 10, y: 10, width: 60, height: 60)
        let boxHeight: CGFloat = 22
        let origin = HintView.labelOrigin(elementFrame: frame, boxHeight: boxHeight)
        #expect(origin.x == 10)
        #expect(origin.y == 29)
    }
}
