import AppKit

/// テキスト変更をコントローラに通知するコールバック
typealias QueryChangedHandler = (String) -> Void

// MARK: - レイアウト定数
private enum SearchBarLayout {
    /// フローティングバーの幅（画面幅に対する比率）
    static let widthRatio: CGFloat = 0.4
    /// フローティングバーの高さ（px）
    static let height: CGFloat = 48
    /// 画面下端からのマージン（px）
    static let bottomMargin: CGFloat = 80
    /// フローティングバーの角丸半径（px）
    static let cornerRadius: CGFloat = 12
    /// テキストフィールドの左右マージン（px）
    static let fieldHorizontalMargin: CGFloat = 16
    /// テキストフィールドの高さ（px）
    static let fieldHeight: CGFloat = 28
    /// マッチ件数ラベルの幅（px）
    static let countLabelWidth: CGFloat = 64
    /// ドロップシャドウのブラー半径（px）
    static let shadowRadius: CGFloat = 8
    /// ドロップシャドウのY方向オフセット（px）
    static let shadowOffsetY: CGFloat = -2
    /// ドロップシャドウの不透明度
    static let shadowOpacity: Float = 1.0
    /// ドロップシャドウの色の不透明度
    static let shadowColorAlpha: CGFloat = 0.3
}

@MainActor
final class SearchView: NSView {
    private var matchedElements: [SearchElementInfo] = []
    private var query: String = ""

    // ブラー効果付きフローティングバーのコンテナ
    private let blurContainer: NSVisualEffectView

    // NSTextField（検索バー部分）
    private let searchField: SearchTextField

    // マッチ件数表示ラベル
    private let countLabel: NSTextField

    // コントローラからセットされるコールバック
    var onQueryChanged: QueryChangedHandler?
    // Enter 確定時のコールバック（IME 変換確定との区別は NSTextField デリゲートが担う）
    var onEnterPressed: (() -> Void)?

    override init(frame: NSRect) {
        self.blurContainer = NSVisualEffectView()
        self.searchField = SearchTextField()
        self.countLabel = SearchView.makeCountLabel()
        super.init(frame: frame)
        setupBlurContainer()
        setupTextField()
        setupCountLabel()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - セットアップ

    private func setupBlurContainer() {
        // ブラー効果の設定
        blurContainer.material = .hudWindow
        blurContainer.blendingMode = .behindWindow
        blurContainer.state = .active

        // 角丸マスク（NSVisualEffectView は layer?.cornerRadius では角丸にならないため maskImage を使う）
        blurContainer.maskImage = Self.roundedRectMaskImage(cornerRadius: SearchBarLayout.cornerRadius)

        // ドロップシャドウの設定
        blurContainer.wantsLayer = true
        blurContainer.shadow = NSShadow()
        blurContainer.layer?.shadowColor = NSColor.black.withAlphaComponent(SearchBarLayout.shadowColorAlpha).cgColor
        blurContainer.layer?.shadowOffset = CGSize(width: 0, height: SearchBarLayout.shadowOffsetY)
        blurContainer.layer?.shadowRadius = SearchBarLayout.shadowRadius
        blurContainer.layer?.shadowOpacity = SearchBarLayout.shadowOpacity

        addSubview(blurContainer)
        updateBlurContainerFrame()
    }

    private func setupTextField() {
        let fieldWidth = barWidth - SearchBarLayout.fieldHorizontalMargin * 2 - SearchBarLayout.countLabelWidth
        let fieldY = (SearchBarLayout.height - SearchBarLayout.fieldHeight) / 2
        searchField.frame = CGRect(
            x: SearchBarLayout.fieldHorizontalMargin,
            y: fieldY,
            width: fieldWidth,
            height: SearchBarLayout.fieldHeight
        )
        // オートリサイズはblurContainer内で幅に追従させる
        searchField.autoresizingMask = [.width]
        searchField.delegate = self
        blurContainer.addSubview(searchField)
    }

    private func setupCountLabel() {
        let labelX = barWidth - SearchBarLayout.countLabelWidth - SearchBarLayout.fieldHorizontalMargin
        let labelY = (SearchBarLayout.height - SearchBarLayout.fieldHeight) / 2
        countLabel.frame = CGRect(
            x: labelX,
            y: labelY,
            width: SearchBarLayout.countLabelWidth,
            height: SearchBarLayout.fieldHeight
        )
        // オートリサイズはblurContainer内で右端に追従させる
        countLabel.autoresizingMask = [.minXMargin]
        blurContainer.addSubview(countLabel)
    }

    // MARK: - フローティングバーの幅（現在のboundsから算出）

    private var barWidth: CGFloat {
        bounds.width * SearchBarLayout.widthRatio
    }

    // MARK: - blurContainerのframeを更新

    private func updateBlurContainerFrame() {
        let width = barWidth
        let x = (bounds.width - width) / 2
        // NSViewの原点は左下なので、下からのマージンをそのまま使う
        let y = SearchBarLayout.bottomMargin
        blurContainer.frame = CGRect(x: x, y: y, width: width, height: SearchBarLayout.height)
    }

    // MARK: - リサイズ対応

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        updateBlurContainerFrame()
    }

    // MARK: - Public API

    func update(query: String, matched: [SearchElementInfo]) {
        self.query = query
        self.matchedElements = query.isEmpty ? [] : matched
        // マッチ件数ラベルの更新
        if query.isEmpty {
            countLabel.stringValue = ""
        } else {
            countLabel.stringValue = "\(matched.count) 件"
        }
        needsDisplay = true
    }

    func focusSearchField() {
        window?.makeFirstResponder(searchField)
    }

    // MARK: - 描画

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawHighlights()
    }

    private func drawHighlights() {
        for info in matchedElements {
            let path = NSBezierPath(roundedRect: info.frame.insetBy(dx: -2, dy: -2), xRadius: 4, yRadius: 4)
            NSColor.systemGreen.withAlphaComponent(0.85).setStroke()
            path.lineWidth = 2.5
            path.stroke()

            NSColor.systemGreen.withAlphaComponent(0.12).setFill()
            path.fill()
        }
    }

    // MARK: - ファクトリ

    /// NSVisualEffectView 用の角丸マスク画像を生成する
    private static func roundedRectMaskImage(cornerRadius: CGFloat) -> NSImage {
        let maskSize = NSSize(width: cornerRadius * 2 + 1, height: cornerRadius * 2 + 1)
        let image = NSImage(size: maskSize, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.capInsets = NSEdgeInsets(
            top: cornerRadius,
            left: cornerRadius,
            bottom: cornerRadius,
            right: cornerRadius
        )
        image.resizingMode = .stretch
        return image
    }

    private static func makeCountLabel() -> NSTextField {
        let label = NSTextField()
        label.isSelectable = false
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.alignment = .right
        return label
    }
}

// MARK: - NSTextFieldDelegate
extension SearchView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        onQueryChanged?(field.stringValue)
    }

    /// IME 変換確定中には呼ばれず、通常の Enter 入力時のみ呼ばれる。
    /// これにより IME の変換確定 Enter と検索実行 Enter を自然に区別できる。
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            onEnterPressed?()
            return true
        }
        return false
    }
}

// MARK: - SearchTextField（プレースホルダー付きカスタム NSTextField）
@MainActor
private final class SearchTextField: NSTextField {
    override init(frame: NSRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        isBordered = false
        backgroundColor = .clear
        textColor = .white
        font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        placeholderString = "検索... (Cmd+Shift+/)"
        focusRingType = .none
    }
}
