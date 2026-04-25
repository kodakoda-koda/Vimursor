import AppKit

/// AXUIElement の属性取得を安全に行う共通ユーティリティ。
/// 座標は AX スクリーン座標系（原点:左上）で返す。
enum AXAttributes {
    /// AXUIElement の AXPosition + AXSize から CGRect を取得する。
    /// - Returns: AX座標（原点:左上）の CGRect。取得失敗時は nil。
    static func frame(of element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        return rectFromValues(positionValue: posRef, sizeValue: sizeRef)
    }

    /// CFTypeRef から CGRect を構築する純粋ロジック（テスト用に分離）。
    /// - Returns: サイズが 0 以下、または AXValue 型でない場合は nil。
    static func rectFromValues(positionValue: CFTypeRef, sizeValue: CFTypeRef) -> CGRect? {
        // CFGetTypeID で AXValue かどうかを確認（条件付き as? は CF 型では常に成功するため使えない）
        guard CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        // 型チェック済みなので force cast は安全
        let posVal = positionValue as! AXValue  // swiftlint:disable:this force_cast
        let sizeVal = sizeValue as! AXValue     // swiftlint:disable:this force_cast
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posVal, .cgPoint, &position),
              AXValueGetValue(sizeVal, .cgSize, &size) else { return nil }
        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// CFTypeRef が AXUIElement かどうかを検証し、安全にキャストする。
    static func element(from ref: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)  // swiftlint:disable:this force_cast
    }
}
