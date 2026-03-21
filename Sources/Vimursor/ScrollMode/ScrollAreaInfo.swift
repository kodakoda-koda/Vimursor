import CoreGraphics

struct ScrollAreaInfo {
    let frame: CGRect        // AX スクリーン座標（描画変換用）
    let centerPoint: CGPoint // CGEvent.location 用（変換不要、スクリーン座標のまま）
    let label: String        // "1", "2", ...
}
