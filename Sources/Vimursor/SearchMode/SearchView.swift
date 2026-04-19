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

// MARK: - ラベル描画定数
private enum LabelStyle {
    /// ラベルフォントサイズ（pt）
    static let fontSize: CGFloat = 11
    /// ラベルテキストパディング（px）
    static let padding: CGFloat = 3
    /// ラベル角丸半径（pt）
    static let cornerRadius: CGFloat = 3
    /// マッチラベル背景アルファ
    static let matchBgAlpha: CGFloat = 0.95
    /// 非マッチラベル背景アルファ
    static let noMatchBgAlpha: CGFloat = 0.5
    /// マッチラベル枠アルファ
    static let matchBorderAlpha: CGFloat = 1.0
    /// 非マッチラベル枠アルファ
    static let noMatchBorderAlpha: CGFloat = 0.4
}

// MARK: - selecting 状態データ
private struct SelectingData {
    let matched: [SearchElementInfo]
    let labels: [String]
    let input: String
}

@MainActor
final class SearchView: NSView {
    private var matchedElements: [SearchElementInfo] = []
    private var query: String = ""

    /// selecting 状態のデータ（nil = searching 状態）
    private var selectingData: SelectingData?

    // ブラー効果付きフローティングバーのコンテナ
    private let blurContainer: NSVisualEffectView

    // NSTextField（検索バー部分）
    private let searchField: SearchTextField

    // マッチ件数表示ラベル
    private let countLabel: NSTextField

    // selecting 状態を視覚的に示すオーバーレイ（blurContainer 上に重ねる）
    private let selectingOverlay: NSView

    // コントローラからセットされるコールバック
    var onQueryChanged: QueryChangedHandler?
    // Enter 確定時のコールバック（IME 変換確定との区別は NSTextField デリゲートが担う）
    var onEnterPressed: (() -> Void)?

    override init(frame: NSRect) {
        self.blurContainer = NSVisualEffectView()
        self.searchField = SearchTextField()
        self.countLabel = SearchView.makeCountLabel()
        self.selectingOverlay = NSView()
        super.init(frame: frame)
        setupBlurContainer()
        setupTextField()
        setupCountLabel()
        setupSelectingOverlay()
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

    private func setupSelectingOverlay() {
        // blurContainer 全体を覆うオーバーレイ（selecting 状態時に表示）
        selectingOverlay.frame = CGRect(origin: .zero, size: CGSize(width: 0, height: SearchBarLayout.height))
        selectingOverlay.autoresizingMask = [.width, .height]
        selectingOverlay.wantsLayer = true
        selectingOverlay.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
        selectingOverlay.layer?.cornerRadius = SearchBarLayout.cornerRadius
        selectingOverlay.isHidden = true
        // ユーザー操作を透過させる（サブビューのイベントに影響しない）
        selectingOverlay.frame = blurContainer.bounds
        blurContainer.addSubview(selectingOverlay)
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

    func unfocusSearchField() {
        window?.makeFirstResponder(nil)
    }

    /// selecting 状態に入る時・ラベル入力更新時に呼ぶ
    func updateForSelecting(matched: [SearchElementInfo], labels: [String], input: String) {
        selectingData = SelectingData(matched: matched, labels: labels, input: input)
        searchField.isEditable = false
        selectingOverlay.isHidden = false
        unfocusSearchField()
        needsDisplay = true
    }

    /// ESC で selecting → searching に戻る時に呼ぶ
    func returnToSearching(query: String, matched: [SearchElementInfo]) {
        selectingData = nil
        self.query = query
        self.matchedElements = matched
        searchField.isEditable = true
        selectingOverlay.isHidden = true
        focusSearchField()
        needsDisplay = true
    }

    // MARK: - 描画

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawHighlights()
        if let data = selectingData {
            drawLabels(data: data)
        }
    }

    private func drawHighlights() {
        // selecting 状態では selectingData.matched からハイライトを描画する
        let elements: [SearchElementInfo]
        if let data = selectingData {
            elements = data.matched
        } else {
            elements = matchedElements
        }
        for info in elements {
            let path = NSBezierPath(roundedRect: info.frame.insetBy(dx: -2, dy: -2), xRadius: 4, yRadius: 4)
            NSColor.systemGreen.withAlphaComponent(0.85).setStroke()
            path.lineWidth = 2.5
            path.stroke()

            NSColor.systemGreen.withAlphaComponent(0.12).setFill()
            path.fill()
        }
    }

    private func drawLabels(data: SelectingData) {
        for (label, element) in zip(data.labels, data.matched) {
            let isMatch = data.input.isEmpty || label.hasPrefix(data.input)
            drawLabel(label: label, frame: element.frame, isMatch: isMatch)
        }
    }

    private func drawLabel(label: String, frame: CGRect, isMatch: Bool) {
        let font = NSFont.systemFont(ofSize: LabelStyle.fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isMatch ? NSColor.black : NSColor.gray
        ]

        let size = (label as NSString).size(withAttributes: attrs)
        let padding = LabelStyle.padding
        let boxWidth = size.width + padding * 2
        let boxHeight = size.height + padding * 2

        let origin = CGPoint(x: frame.minX, y: frame.maxY)
        let boxRect = CGRect(x: origin.x, y: origin.y, width: boxWidth, height: boxHeight)

        let path = NSBezierPath(roundedRect: boxRect, xRadius: LabelStyle.cornerRadius, yRadius: LabelStyle.cornerRadius)
        let bgColor: NSColor = isMatch ? .white : .lightGray
        bgColor.withAlphaComponent(isMatch ? LabelStyle.matchBgAlpha : LabelStyle.noMatchBgAlpha).setFill()
        path.fill()
        NSColor.black.withAlphaComponent(isMatch ? LabelStyle.matchBorderAlpha : LabelStyle.noMatchBorderAlpha).setStroke()
        path.lineWidth = 1.0
        path.stroke()

        let textOrigin = CGPoint(x: origin.x + padding, y: origin.y + padding)
        (label as NSString).draw(at: textOrigin, withAttributes: attrs)
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
