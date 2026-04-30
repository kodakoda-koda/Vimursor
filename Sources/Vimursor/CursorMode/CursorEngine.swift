import CoreGraphics
import AppKit

enum CursorDirection {
    case left, down, up, right
}

enum CursorEngine {
    /// カーソルの新しい位置を計算する純粋関数。画面端でクランプする。
    /// - Parameters:
    ///   - current: 現在のカーソル位置（スクリーン座標、原点:左上）
    ///   - direction: 移動方向
    ///   - steps: ステップ数（マルチプライヤ適用済み）
    ///   - stepPixels: 1ステップあたりのピクセル数
    ///   - screenBounds: スクリーンの矩形（原点:左上、通常 (0,0,width,height)）
    static func moveCursor(
        from current: CGPoint,
        direction: CursorDirection,
        steps: Int,
        stepPixels: Int,
        screenBounds: CGRect
    ) -> CGPoint {
        let delta = CGFloat(steps * stepPixels)
        var newX = current.x
        var newY = current.y

        switch direction {
        case .left:  newX -= delta
        case .right: newX += delta
        case .up:    newY -= delta  // screen coords: origin top-left, up = y decreases
        case .down:  newY += delta  // down = y increases
        }

        // Clamp to screen bounds
        newX = max(screenBounds.minX, min(screenBounds.maxX, newX))
        newY = max(screenBounds.minY, min(screenBounds.maxY, newY))

        return CGPoint(x: newX, y: newY)
    }

    /// カーソルを指定位置に移動する（副作用あり）
    static func applyMove(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
    }

    /// 指定位置でクリックを実行する（副作用あり）
    /// - Parameters:
    ///   - point: クリック位置（スクリーン座標、原点:左上）
    ///   - isRightClick: true なら右クリック、false なら左クリック
    static func click(at point: CGPoint, isRightClick: Bool) {
        let downType: CGEventType = isRightClick ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = isRightClick ? .rightMouseUp : .leftMouseUp
        let button: CGMouseButton = isRightClick ? .right : .left

        let down = CGEvent(mouseEventSource: nil, mouseType: downType,
                           mouseCursorPosition: point, mouseButton: button)
        let up = CGEvent(mouseEventSource: nil, mouseType: upType,
                         mouseCursorPosition: point, mouseButton: button)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// NSEvent.mouseLocation（原点:左下）をスクリーン座標（原点:左上）に変換する
    static func screenPointFromMouseLocation(_ mouseLocation: CGPoint, screenHeight: CGFloat) -> CGPoint {
        CGPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)
    }
}
