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
    let searchableText: String

    init(frame: CGRect, title: String, label: String, description: String, role: String, axElement: AXElement) {
        self.frame = frame
        self.title = title
        self.label = label
        self.description = description
        self.role = role
        self.axElement = axElement
        self.searchableText = [title, label, description, role]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}

final class AXManager: @unchecked Sendable {
    /// バックグラウンドで列挙・フレーム取得・座標変換を完了し、メインスレッドで completion を呼ぶ。
    /// CGRect は AX座標（原点:左上）→ NSWindow 座標（原点:左下）変換済み。
    func fetchClickableElements(in app: AXUIElement, completion: @escaping @Sendable ([(AXElement, CGRect)]) -> Void) {
        let wrapped = AXElement(ref: app)
        // screenHeight はメインスレッドで取得してからBGへ渡す
        let screenHeight = NSScreen.main?.frame.height ?? 0
        DispatchQueue.global(qos: .userInitiated).async {
            let elements = UIElementEnumerator.enumerateClickableElements(root: wrapped.ref)

            // フレーム取得・座標変換をバックグラウンドで完了（buildUIElementInfos での再取得を不要にする）
            let axElementsWithFrames = elements.compactMap { element -> (AXElement, CGRect)? in
                guard let axFrame = AXAttributes.frame(of: element) else { return nil }
                let convertedY = screenHeight - axFrame.origin.y - axFrame.size.height
                let frame = CGRect(x: axFrame.origin.x, y: convertedY,
                                   width: axFrame.size.width, height: axFrame.size.height)
                return (AXElement(ref: element), frame)
            }

            DispatchQueue.main.async {
                completion(axElementsWithFrames)
            }
        }
    }

    @MainActor
    func buildUIElementInfos(elements: [(AXElement, CGRect)], labels: [String]) -> [UIElementInfo] {
        var infos: [UIElementInfo] = []

        for (index, (element, frame)) in elements.enumerated() {
            guard index < labels.count else { break }
            infos.append(UIElementInfo(
                frame: frame,
                label: labels[index],
                axElement: element
            ))
        }

        return infos
    }

    func fetchSearchableElements(
        in app: AXUIElement,
        completion: @escaping @Sendable ([SearchElementInfo]) -> Void
    ) {
        let wrapped = AXElement(ref: app)
        let screenHeight = NSScreen.main?.frame.height ?? 0
        DispatchQueue.global(qos: .userInitiated).async {
            let elements = UIElementEnumerator.enumerateSearchableElements(root: wrapped.ref)

            let infos = elements.compactMap { data -> SearchElementInfo? in
                guard let frame = self.fetchFrame(element: data.element, screenHeight: screenHeight) else { return nil }
                return SearchElementInfo(
                    frame: frame,
                    title: data.title,
                    label: data.label,
                    description: data.description,
                    role: data.role,
                    axElement: AXElement(ref: data.element)
                )
            }
            DispatchQueue.main.async { completion(infos) }
        }
    }

    func clickAt(frame: CGRect, modifier: ClickModifier) {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let point = AXManager.centerScreenPoint(from: frame, screenHeight: screenHeight)

        switch modifier {
        case .leftClick:
            postMouseClick(point: point, downType: .leftMouseDown, upType: .leftMouseUp, button: .left)
        case .commandClick:
            postMouseClick(point: point, downType: .leftMouseDown, upType: .leftMouseUp, button: .left, flags: .maskCommand)
        case .controlClick:
            postMouseClick(point: point, downType: .leftMouseDown, upType: .leftMouseUp, button: .left, flags: .maskControl)
        case .optionClick:
            postMouseClick(point: point, downType: .leftMouseDown, upType: .leftMouseUp, button: .left, flags: .maskAlternate)
        case .rightClick:
            postMouseClick(point: point, downType: .rightMouseDown, upType: .rightMouseUp, button: .right)
        }
    }

    private func postMouseClick(
        point: CGPoint,
        downType: CGEventType,
        upType: CGEventType,
        button: CGMouseButton,
        flags: CGEventFlags = []
    ) {
        let down = CGEvent(mouseEventSource: nil, mouseType: downType,
                           mouseCursorPosition: point, mouseButton: button)
        let up = CGEvent(mouseEventSource: nil, mouseType: upType,
                         mouseCursorPosition: point, mouseButton: button)
        if !flags.isEmpty {
            down?.flags.formUnion(flags)
            up?.flags.formUnion(flags)
        }
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

    /// NSWindow 座標系（原点:左下）の frame をスクリーン座標系（原点:左上）の中心点に変換する。
    /// テストからの検証用に public で公開。プロダクションコードでは使用しないこと。
    static func centerScreenPoint(from frame: CGRect, screenHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: screenHeight - frame.origin.y - frame.height / 2
        )
    }

    func fetchScrollableElements(
        in app: AXUIElement,
        completion: @escaping @Sendable ([ScrollAreaInfo]) -> Void
    ) {
        let appElement = AXElement(ref: app)
        DispatchQueue.global(qos: .userInitiated).async {
            let areas = ScrollTarget.enumerateScrollableElements(root: appElement.ref)
            DispatchQueue.main.async {
                completion(areas)
            }
        }
    }

    private func fetchFrame(element: AXUIElement, screenHeight: CGFloat) -> CGRect? {
        guard let axFrame = AXAttributes.frame(of: element) else { return nil }
        // AX座標（原点:左上）→ NSWindow座標（原点:左下）変換
        let convertedY = screenHeight - axFrame.origin.y - axFrame.size.height
        return CGRect(x: axFrame.origin.x, y: convertedY, width: axFrame.size.width, height: axFrame.size.height)
    }
}

// MARK: - ElementFetching
extension AXManager: ElementFetching {}
