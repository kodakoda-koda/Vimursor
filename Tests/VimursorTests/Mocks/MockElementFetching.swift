import AppKit
@testable import Vimursor

final class MockElementFetching: ElementFetching, @unchecked Sendable {
    // テストデータ
    var clickableElements: [AXElement] = []
    var searchableElements: [SearchElementInfo] = []
    var scrollableAreas: [ScrollAreaInfo] = []
    var uiElementInfos: [UIElementInfo] = []

    // 呼び出し記録
    var clickAtCallCount = 0
    var lastClickedFrame: CGRect?
    var lastClickModifier: ClickModifier?
    var fetchClickableCallCount = 0
    var fetchSearchableCallCount = 0
    var fetchScrollableCallCount = 0

    func fetchClickableElements(in app: AXUIElement, completion: @escaping @Sendable ([(AXElement, CGRect)]) -> Void) {
        fetchClickableCallCount += 1
        // clickableElements にダミーフレームを付けてタプルに変換
        let elementsWithFrames = clickableElements.map { ($0, CGRect(x: 0, y: 0, width: 50, height: 20)) }
        DispatchQueue.main.async {
            completion(elementsWithFrames)
        }
    }

    @MainActor func buildUIElementInfos(elements: [(AXElement, CGRect)], labels: [String]) -> [UIElementInfo] {
        return uiElementInfos
    }

    func fetchSearchableElements(in app: AXUIElement, completion: @escaping @Sendable ([SearchElementInfo]) -> Void) {
        fetchSearchableCallCount += 1
        let elements = searchableElements
        DispatchQueue.main.async {
            completion(elements)
        }
    }

    func fetchScrollableElements(in app: AXUIElement, completion: @escaping @Sendable ([ScrollAreaInfo]) -> Void) {
        fetchScrollableCallCount += 1
        let areas = scrollableAreas
        DispatchQueue.main.async {
            completion(areas)
        }
    }

    func clickAt(frame: CGRect, modifier: ClickModifier) {
        clickAtCallCount += 1
        lastClickedFrame = frame
        lastClickModifier = modifier
    }
}
