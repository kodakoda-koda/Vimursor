import AppKit
import KeyboardShortcuts

// MARK: - ShortcutsSettingsView

/// Shortcuts タブのコンテンツビュー。
/// ヒント／検索／スクロールモードの起動ショートカットを ShortcutRecorderField でカスタマイズできる。
@MainActor
final class ShortcutsSettingsView: NSView {

    // MARK: - Constants

    private enum Layout {
        static let margin: CGFloat = 20
        static let rowHeight: CGFloat = 30
        static let rowSpacing: CGFloat = 12
        static let labelWidth: CGFloat = 140
        static let recorderWidth: CGFloat = 160
    }

    // MARK: - Recorders

    private let hintModeRecorder = ShortcutRecorderField(for: .hintMode)
    private let searchModeRecorder = ShortcutRecorderField(for: .searchMode)
    private let scrollModeRecorder = ShortcutRecorderField(for: .scrollMode)
    private let cursorModeRecorder = ShortcutRecorderField(for: .cursorMode)

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Setup

    private func setupLayout() {
        let rows: [(String, ShortcutRecorderField)] = [
            ("Hint Mode:", hintModeRecorder),
            ("Search Mode:", searchModeRecorder),
            ("Scroll Mode:", scrollModeRecorder),
            ("Cursor Mode:", cursorModeRecorder)
        ]

        for (index, (labelText, recorder)) in rows.enumerated() {
            let label = makeLabel(labelText)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)

            recorder.translatesAutoresizingMaskIntoConstraints = false
            addSubview(recorder)

            let yOffset = Layout.margin + CGFloat(rows.count - 1 - index) * (Layout.rowHeight + Layout.rowSpacing)
            let centerY = yOffset + Layout.rowHeight / 2

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.margin),
                label.widthAnchor.constraint(equalToConstant: Layout.labelWidth),
                label.centerYAnchor.constraint(equalTo: topAnchor, constant: centerY),

                recorder.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: Layout.margin + Layout.labelWidth + 8
                ),
                recorder.widthAnchor.constraint(equalToConstant: Layout.recorderWidth),
                recorder.centerYAnchor.constraint(equalTo: topAnchor, constant: centerY)
            ])
        }
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    // MARK: - Public

    /// KeyboardShortcuts.reset() は UserDefaults を更新し、ShortcutRecorderField は
    /// KeyboardShortcuts_shortcutByNameDidChange 通知を監視して自動的に表示を更新する。
    /// 明示的な操作は不要。このメソッドは AppearanceSettingsView / BehaviorSettingsView
    /// との API 対称性のために提供する。
    func reloadValues() {}
}
