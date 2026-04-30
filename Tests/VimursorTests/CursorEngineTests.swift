import Testing
import CoreGraphics
@testable import Vimursor

@Suite("CursorEngine Tests")
struct CursorEngineTests {
    let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    // MARK: - moveCursor

    @Test("右移動")
    func moveRight() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 100, y: 100),
            direction: .right, steps: 1, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.x == 120)
        #expect(result.y == 100)
    }

    @Test("左移動")
    func moveLeft() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 100, y: 100),
            direction: .left, steps: 1, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.x == 80)
        #expect(result.y == 100)
    }

    @Test("上移動（スクリーン座標: y減少）")
    func moveUp() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 100, y: 100),
            direction: .up, steps: 1, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.x == 100)
        #expect(result.y == 80)
    }

    @Test("下移動（スクリーン座標: y増加）")
    func moveDown() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 100, y: 100),
            direction: .down, steps: 1, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.x == 100)
        #expect(result.y == 120)
    }

    @Test("マルチプライヤ: 5ステップ")
    func moveWithMultiplier() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 100, y: 100),
            direction: .right, steps: 5, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.x == 200)
    }

    @Test("右端クランプ")
    func clampRight() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 1900, y: 100),
            direction: .right, steps: 5, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.x == 1920)
    }

    @Test("左端クランプ")
    func clampLeft() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 10, y: 100),
            direction: .left, steps: 5, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.x == 0)
    }

    @Test("上端クランプ")
    func clampTop() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 100, y: 10),
            direction: .up, steps: 5, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.y == 0)
    }

    @Test("下端クランプ")
    func clampBottom() {
        let result = CursorEngine.moveCursor(
            from: CGPoint(x: 100, y: 1070),
            direction: .down, steps: 5, stepPixels: 20, screenBounds: screenBounds
        )
        #expect(result.y == 1080)
    }

    // MARK: - screenPointFromMouseLocation

    @Test("NSEvent座標 → スクリーン座標変換")
    func convertMouseLocation() {
        let result = CursorEngine.screenPointFromMouseLocation(
            CGPoint(x: 100, y: 200), screenHeight: 1080
        )
        #expect(result.x == 100)
        #expect(result.y == 880)
    }
}
