import AppKit

protocol ElementFetching: AnyObject {
    /// BGスレッドでフレーム取得済みの要素を返す。CGRect は NSWindow 座標系（原点:左下）に変換済み。
    func fetchClickableElements(in app: AXUIElement, completion: @escaping @Sendable ([(AXElement, CGRect)]) -> Void)
    @MainActor func buildUIElementInfos(elements: [(AXElement, CGRect)], labels: [String]) -> [UIElementInfo]
    func fetchSearchableElements(in app: AXUIElement, completion: @escaping @Sendable ([SearchElementInfo]) -> Void)
    func fetchScrollableElements(in app: AXUIElement, completion: @escaping @Sendable ([ScrollAreaInfo]) -> Void)
    func clickAt(frame: CGRect, modifier: ClickModifier)
}

extension ElementFetching {
    func clickAt(frame: CGRect) {
        clickAt(frame: frame, modifier: .leftClick)
    }
}
