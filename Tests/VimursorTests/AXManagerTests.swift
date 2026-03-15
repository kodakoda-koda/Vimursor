import Testing
import AppKit
@testable import Vimursor

@Suite
struct AXManagerTests {

    // MARK: - centerScreenPoint

    @Test func centerScreenPointTypical() {
        // NSWindow座標: x=100, y=200（下から200px）、80x40の要素
        let frame = CGRect(x: 100, y: 200, width: 80, height: 40)
        let point = AXManager.centerScreenPoint(from: frame, screenHeight: 1080)
        // centerX = 100 + 80/2 = 140
        // centerY = 1080 - 200 - 40/2 = 860
        #expect(point.x == 140)
        #expect(point.y == 860)
    }

    @Test func centerScreenPointAtOrigin() {
        // 画面左下原点に置いた要素
        let frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let point = AXManager.centerScreenPoint(from: frame, screenHeight: 800)
        // centerX = 50, centerY = 800 - 0 - 25 = 775
        #expect(point.x == 50)
        #expect(point.y == 775)
    }

    @Test func centerScreenPointAtTopLeft() {
        // 画面左上端（AX座標の原点）に対応する要素
        // AX: position=(0,0), size=(60,20) → NSWindow: y = screenHeight - 0 - 20 = 780
        let frame = CGRect(x: 0, y: 780, width: 60, height: 20)
        let point = AXManager.centerScreenPoint(from: frame, screenHeight: 800)
        // centerX = 30, centerY = 800 - 780 - 10 = 10
        #expect(point.x == 30)
        #expect(point.y == 10)
    }

    @Test func centerScreenPointSymmetry() {
        // 変換を2回かけると元の AX center に戻ることを確認
        // AX center: (200, 150) → NSWindow frame → screen point
        let screenHeight: CGFloat = 1000
        let axCenterX: CGFloat = 200
        let axCenterY: CGFloat = 150  // AX座標（上から150px）

        // NSWindow 座標への変換（fetchFrame の逆）
        // frame.origin.y = screenHeight - axPosition.y - height
        // axPosition.y = axCenterY - height/2 = 150 - 20 = 130
        let width: CGFloat = 80
        let height: CGFloat = 40
        let frame = CGRect(
            x: axCenterX - width / 2,
            y: screenHeight - (axCenterY - height / 2) - height,
            width: width,
            height: height
        )

        let point = AXManager.centerScreenPoint(from: frame, screenHeight: screenHeight)
        #expect(point.x == axCenterX)
        #expect(point.y == axCenterY)
    }
}
