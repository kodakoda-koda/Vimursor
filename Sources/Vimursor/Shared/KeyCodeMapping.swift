import CoreGraphics

/// キーコード → アルファベット文字の共通マッピングユーティリティ
/// HintModeController / SearchModeController から共有して使用する
enum KeyCodeMapping {

    /// キーコードと文字の全マッピング（US キーボードレイアウト準拠）
    static let allMappings: [CGKeyCode: String] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e",
        3: "f", 5: "g", 4: "h", 34: "i", 38: "j",
        40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
        35: "p", 12: "q", 15: "r", 1: "s", 17: "t",
        32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z"
    ]

    /// 指定キーコードに対応するアルファベット文字を返す
    /// - Parameter keyCode: CGEventTap から受け取るキーコード
    /// - Returns: 対応する文字（英小文字1文字）。マッピングに存在しない場合は nil
    static func charFromKeyCode(_ keyCode: CGKeyCode) -> String? {
        allMappings[keyCode]
    }
}
