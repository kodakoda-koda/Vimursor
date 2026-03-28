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

struct SearchElementInfo: Sendable {
    let frame: CGRect
    let title: String
    let label: String
    let description: String
    let role: String
    let axElement: AXElement

    var searchableText: String {
        [title, label, description, role]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}

final class AXManager: @unchecked Sendable {
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

    @MainActor
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

    @MainActor
    func fetchSearchableElements(
        in app: AXUIElement,
        completion: @escaping @Sendable ([SearchElementInfo]) -> Void
    ) {
        let wrapped = AXElement(ref: app)
        let screenHeight = NSScreen.main?.frame.height ?? 0
        DispatchQueue.global(qos: .userInitiated).async {
            let elements = UIElementEnumerator.enumerateSearchableElements(root: wrapped.ref)
            let infos = elements.compactMap { el -> SearchElementInfo? in
                guard let frame = self.fetchFrame(element: el, screenHeight: screenHeight) else { return nil }
                func str(_ key: String) -> String {
                    var ref: CFTypeRef?
                    guard AXUIElementCopyAttributeValue(el, key as CFString, &ref) == .success,
                          let s = ref as? String else { return "" }
                    return s
                }
                return SearchElementInfo(
                    frame: frame,
                    title: str("AXTitle"),
                    label: str("AXLabel"),
                    description: str("AXDescription"),
                    role: str("AXRole"),
                    axElement: AXElement(ref: el)
                )
            }
            DispatchQueue.main.async { completion(infos) }
        }
    }

    @MainActor
    func clickAt(frame: CGRect) {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let point = AXManager.centerScreenPoint(from: frame, screenHeight: screenHeight)
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        let up   = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                           mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// フォーカスアプリに AXManualAccessibility を設定し、Electron の完全な AX ツリーを有効にする。
    /// ネイティブアプリでは attributeUnsupported が返るが、副作用なし。
    static func enableManualAccessibility() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let result = AXUIElementSetAttributeValue(
            appElement,
            "AXManualAccessibility" as CFString,
            true as CFTypeRef
        )
        switch result {
        case .success, .attributeUnsupported:
            break
        default:
            NSLog("AXManager.enableManualAccessibility: AXUIElementSetAttributeValue failed with error: \(String(describing: result)) (rawValue: \(result.rawValue))")
        }
    }

    /// NSWindow 座標系（原点:左下）の frame をスクリーン座標系（原点:左上）の中心点に変換する
    /// テスト用に static で公開
    static func centerScreenPoint(from frame: CGRect, screenHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: screenHeight - frame.origin.y - frame.height / 2
        )
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
