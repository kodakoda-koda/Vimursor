import AppKit

// AXUIElement の Sendable ラッパー
struct AXElement: @unchecked Sendable {
    let ref: AXUIElement
}

// バックグラウンドスレッドからメインスレッドへ安全に渡せる値型
struct UIElementInfo: Sendable {
    let frame: CGRect   // NSWindow 座標系（原点:左下）に変換済み
    let label: String
    let axElement: AXElement
}

final class AXManager {
    /// バックグラウンドで列挙し、メインスレッドで completion を呼ぶ
    func fetchClickableElements(in app: AXUIElement, completion: @escaping @Sendable ([AXElement]) -> Void) {
        let wrapped = AXElement(ref: app)
        DispatchQueue.global(qos: .userInitiated).async {
            let elements = UIElementEnumerator.enumerateClickableElements(root: wrapped.ref)
            let axElements = elements.map { AXElement(ref: $0) }
            DispatchQueue.main.async {
                completion(axElements)
            }
        }
    }

    func buildUIElementInfos(elements: [AXElement], labels: [String]) -> [UIElementInfo] {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        var infos: [UIElementInfo] = []

        for (index, element) in elements.enumerated() {
            guard index < labels.count else { break }
            guard let frame = fetchFrame(element: element.ref, screenHeight: screenHeight) else { continue }
            infos.append(UIElementInfo(
                frame: frame,
                label: labels[index],
                axElement: element
            ))
        }

        return infos
    }

    func click(element: AXUIElement) {
        AXUIElementPerformAction(element, "AXPress" as CFString)
    }

    private func fetchFrame(element: AXUIElement, screenHeight: CGFloat) -> CGRect? {
        var position = CGPoint.zero
        var size = CGSize.zero

        var posRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &posRef) == .success,
              let posRef else { return nil }
        let posVal = posRef as! AXValue  // AXValue は CF型なので force cast が正しい
        AXValueGetValue(posVal, .cgPoint, &position)

        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
              let sizeRef else { return nil }
        let sizeVal = sizeRef as! AXValue
        AXValueGetValue(sizeVal, .cgSize, &size)

        guard size.width > 0, size.height > 0 else { return nil }

        // AX座標（原点:左上）→ NSWindow座標（原点:左下）変換
        let convertedY = screenHeight - position.y - size.height
        return CGRect(x: position.x, y: convertedY, width: size.width, height: size.height)
    }
}
