import AppKit
import CoreGraphics

private enum ScrollModeState {
    case inactive
    case fetching
    case active(areas: [ScrollAreaInfo], selectedIndex: Int)
}

enum ScrollKeyCode {
    static let esc: CGKeyCode  = 53
    static let tab: CGKeyCode  = 48
    static let j: CGKeyCode    = 38
    static let k: CGKeyCode    = 40
    static let d: CGKeyCode    = 2
    static let u: CGKeyCode    = 32
    static let g: CGKeyCode    = 5
    // 数字 1〜9（US キーボード）
    static let numToIndex: [CGKeyCode: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
        22: 5, 26: 6, 28: 7, 25: 8
    ]
}

@MainActor
private final class ScrollIndicatorView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        ("SCROLL" as NSString).draw(
            at: CGPoint(x: 8, y: (bounds.height - 14) / 2),
            withAttributes: attrs
        )
    }
}

@MainActor
final class ScrollModeController {
    private var state: ScrollModeState = .inactive
    private var scrollAreaView: ScrollAreaView?
    private var indicatorView: ScrollIndicatorView?
    private weak var overlayWindow: (any OverlayProviding)?
    private weak var hotkeyManager: (any KeyEventHandling)?
    private let elementFetcher: any ElementFetching
    /// `g` キーが1回押された状態を保持する（gg 入力のため）
    private var pendingG: Bool = false
    /// scrollToExtreme の進行中イベントをキャンセルするためのハンドル
    private var extremeScrollToken: DispatchWorkItem?

    init(elementFetcher: any ElementFetching = AXManager()) {
        self.elementFetcher = elementFetcher
    }

    func activate(overlayWindow: any OverlayProviding, hotkeyManager: any KeyEventHandling) {
        guard case .inactive = state else { return }
        state = .fetching
        self.overlayWindow = overlayWindow
        self.hotkeyManager = hotkeyManager

        hotkeyManager.keyEventHandler = { [weak self] keyCode, flags, _ in
            guard let self else { return false }

            let otherModifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate])
            let isShift = flags.contains(.maskShift)

            // ESC は常に消費
            let shouldConsume: Bool
            if keyCode == ScrollKeyCode.esc {
                shouldConsume = true
            } else if !otherModifiers.isEmpty {
                // Cmd/Ctrl/Alt 付きはシステムに渡す（Cmd+Tab 等を妨げない）
                shouldConsume = false
            } else if keyCode == ScrollKeyCode.tab {
                // Tab / Shift+Tab は消費
                shouldConsume = true
            } else if isShift {
                // Shift+g (= G) のみ消費、他の Shift 付きは消費しない
                shouldConsume = (keyCode == ScrollKeyCode.g)
            } else {
                // 数字キー・スクロールキーのみ消費
                shouldConsume = ScrollKeyCode.numToIndex[keyCode] != nil
                    || keyCode == ScrollKeyCode.j
                    || keyCode == ScrollKeyCode.k
                    || keyCode == ScrollKeyCode.d
                    || keyCode == ScrollKeyCode.u
                    || keyCode == ScrollKeyCode.g
            }

            if shouldConsume {
                Task { @MainActor [weak self] in
                    self?.handleKey(keyCode: keyCode, flags: flags)
                }
            } else if self.pendingG {
                // 非消費キー（Cmd+Tab 等）でも pendingG をリセットし、
                // 意図しない gg 発火を防ぐ
                Task { @MainActor [weak self] in
                    self?.pendingG = false
                }
            }
            return shouldConsume
        }

        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            deactivate()
            return
        }
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)
        elementFetcher.fetchScrollableElements(in: appElement) { [weak self] areas in
            Task { @MainActor [weak self] in
                self?.startScrollMode(areas: areas)
            }
        }
    }

    private func startScrollMode(areas: [ScrollAreaInfo]) {
        guard case .fetching = state else { return }

        if areas.isEmpty {
            deactivate()
            return
        }

        state = .active(areas: areas, selectedIndex: 0)

        let screenHeight = NSScreen.main?.frame.height ?? 0
        let viewFrame = overlayWindow?.contentView?.bounds ?? .zero
        let areaView = ScrollAreaView(screenHeight: screenHeight, frame: viewFrame)
        areaView.autoresizingMask = [.width, .height]
        areaView.update(areas: areas, selectedIndex: 0)
        overlayWindow?.contentView?.addSubview(areaView)
        self.scrollAreaView = areaView

        let indicator = ScrollIndicatorView(frame: CGRect(x: 12, y: 12, width: 80, height: 28))
        overlayWindow?.contentView?.addSubview(indicator)
        self.indicatorView = indicator

        overlayWindow?.show()
    }

    func deactivate() {
        state = .inactive
        pendingG = false
        extremeScrollToken?.cancel()
        extremeScrollToken = nil
        scrollAreaView?.removeFromSuperview()
        scrollAreaView = nil
        indicatorView?.removeFromSuperview()
        indicatorView = nil
        hotkeyManager?.keyEventHandler = nil
        overlayWindow?.hide()
    }

    private func handleKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        // fetching 中は ESC のみ受け付ける
        if case .fetching = state {
            if keyCode == ScrollKeyCode.esc { deactivate() }
            return
        }

        guard case .active(let areas, let selectedIndex) = state else { return }

        if keyCode == ScrollKeyCode.esc {
            deactivate()
            return
        }

        let isShift = flags.contains(.maskShift)

        if keyCode == ScrollKeyCode.g {
            handleGKey(isShift: isShift, areas: areas, selectedIndex: selectedIndex)
            return
        }

        // g 以外のキーが押されたら pendingG をリセット
        pendingG = false

        if keyCode == ScrollKeyCode.tab {
            handleTabKey(isShift: isShift, areas: areas, selectedIndex: selectedIndex)
            return
        }

        if handleNumberKey(keyCode: keyCode, areas: areas) {
            return
        }

        handleScrollKey(keyCode: keyCode, targetPoint: areas[selectedIndex].centerPoint)
    }

    private func handleGKey(isShift: Bool, areas: [ScrollAreaInfo], selectedIndex: Int) {
        let targetPoint = areas[selectedIndex].centerPoint
        if isShift {
            // G（Shift+g）: ページ末尾へスクロール
            pendingG = false
            extremeScrollToken?.cancel()
            extremeScrollToken = ScrollEngine.scrollToExtreme(direction: .down, targetPoint: targetPoint)
        } else if pendingG {
            // gg: ページ先頭へスクロール
            pendingG = false
            extremeScrollToken?.cancel()
            extremeScrollToken = ScrollEngine.scrollToExtreme(direction: .up, targetPoint: targetPoint)
        } else {
            pendingG = true
        }
    }

    private func handleTabKey(isShift: Bool, areas: [ScrollAreaInfo], selectedIndex: Int) {
        let next = isShift
            ? (selectedIndex - 1 + areas.count) % areas.count  // Shift+Tab: 逆順
            : (selectedIndex + 1) % areas.count                 // Tab: 順送り
        selectArea(index: next, areas: areas)
    }

    /// 数字キーによる領域選択。消費した場合 true を返す。
    private func handleNumberKey(keyCode: CGKeyCode, areas: [ScrollAreaInfo]) -> Bool {
        guard let index = ScrollKeyCode.numToIndex[keyCode], index < areas.count else { return false }
        selectArea(index: index, areas: areas)
        return true
    }

    private func handleScrollKey(keyCode: CGKeyCode, targetPoint: CGPoint) {
        switch keyCode {
        case ScrollKeyCode.j:
            ScrollEngine.scroll(amount: .step(direction: .down), targetPoint: targetPoint)
        case ScrollKeyCode.k:
            ScrollEngine.scroll(amount: .step(direction: .up), targetPoint: targetPoint)
        case ScrollKeyCode.d:
            ScrollEngine.scroll(amount: .halfPage(direction: .down), targetPoint: targetPoint)
        case ScrollKeyCode.u:
            ScrollEngine.scroll(amount: .halfPage(direction: .up), targetPoint: targetPoint)
        default:
            break
        }
    }

    private func selectArea(index: Int, areas: [ScrollAreaInfo]) {
        state = .active(areas: areas, selectedIndex: index)
        scrollAreaView?.update(areas: areas, selectedIndex: index)
    }
}
