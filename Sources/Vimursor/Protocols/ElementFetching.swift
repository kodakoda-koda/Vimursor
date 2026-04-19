import AppKit

protocol ElementFetching: AnyObject {
    func fetchClickableElements(in app: AXUIElement, completion: @escaping @Sendable ([AXElement]) -> Void)
    @MainActor func buildUIElementInfos(elements: [AXElement], labels: [String]) -> [UIElementInfo]
    func fetchSearchableElements(in app: AXUIElement, completion: @escaping @Sendable ([SearchElementInfo]) -> Void)
    func fetchScrollableElements(in app: AXUIElement, completion: @escaping @Sendable ([ScrollAreaInfo]) -> Void)
    func clickAt(frame: CGRect)
}
