import CoreGraphics

/// 修飾キーからクリックアクションへのマッピング
enum ClickModifier: Sendable {
    case leftClick      // 修飾キーなし → 通常の左クリック
    case commandClick   // Cmd → Cmd+左クリック
    case rightClick     // Shift → 右クリック（contextual menu）
    case controlClick   // Ctrl → Ctrl+左クリック
    case optionClick    // Option → Option+左クリック

    /// CGEventFlags から ClickModifier を決定する。
    /// 複数修飾キーが同時に押された場合の優先順位: Cmd > Ctrl > Option > Shift
    static func from(flags: CGEventFlags) -> ClickModifier {
        if flags.contains(.maskCommand)   { return .commandClick }
        if flags.contains(.maskControl)   { return .controlClick }
        if flags.contains(.maskAlternate) { return .optionClick }
        if flags.contains(.maskShift)     { return .rightClick }
        return .leftClick
    }
}
