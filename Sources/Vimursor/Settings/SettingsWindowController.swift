import AppKit

// MARK: - SettingsWindowController

/// 設定ウィンドウを管理する NSWindowController。
/// Appearance / Behavior / Shortcuts (placeholder) の3タブ構成。
@MainActor
final class SettingsWindowController: NSWindowController {

    // MARK: - Constants

    private enum WindowMetrics {
        static let width: CGFloat = 480
        static let height: CGFloat = 400
        static let resetButtonHeight: CGFloat = 32
        static let resetButtonBottomMargin: CGFloat = 16
        static let tabViewMargin: CGFloat = 16
    }

    // MARK: - Properties

    private let settings: AppSettings
    private var appearanceView: AppearanceSettingsView?
    private var behaviorView: BehaviorSettingsView?

    // MARK: - Initialization

    init(settings: AppSettings = .shared) {
        self.settings = settings
        let win = SettingsWindowController.makeWindow()
        super.init(window: win)
        buildContent(in: win)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Window factory

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: WindowMetrics.width, height: WindowMetrics.height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vimursor Settings"
        window.isRestorable = false
        window.center()
        return window
    }

    // MARK: - Content building

    private func buildContent(in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        // Reset ボタン（下部）
        let resetButton = makeResetButton()
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(resetButton)

        NSLayoutConstraint.activate([
            resetButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            resetButton.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -WindowMetrics.resetButtonBottomMargin
            ),
            resetButton.heightAnchor.constraint(equalToConstant: WindowMetrics.resetButtonHeight)
        ])

        // TabView
        let tabView = makeTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: WindowMetrics.tabViewMargin
            ),
            tabView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: WindowMetrics.tabViewMargin
            ),
            tabView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -WindowMetrics.tabViewMargin
            ),
            tabView.bottomAnchor.constraint(
                equalTo: resetButton.topAnchor,
                constant: -WindowMetrics.tabViewMargin
            )
        ])
    }

    private func makeTabView() -> NSTabView {
        let tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder

        tabView.addTabViewItem(makeAppearanceTab())
        tabView.addTabViewItem(makeBehaviorTab())
        tabView.addTabViewItem(makeShortcutsTab())

        return tabView
    }

    private func makeAppearanceTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Appearance"

        let view = AppearanceSettingsView(settings: settings)
        self.appearanceView = view
        item.view = view

        return item
    }

    private func makeBehaviorTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Behavior"

        let view = BehaviorSettingsView(settings: settings)
        self.behaviorView = view
        item.view = view

        return item
    }

    private func makeShortcutsTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Shortcuts"

        let placeholder = NSView()
        let label = NSTextField(labelWithString: "Coming soon")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 14)
        placeholder.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor)
        ])
        item.view = placeholder

        return item
    }

    private func makeResetButton() -> NSButton {
        let button = NSButton(
            title: "Reset to Defaults",
            target: self,
            action: #selector(resetToDefaults(_:))
        )
        button.bezelStyle = .rounded
        return button
    }

    // MARK: - Actions

    @objc private func resetToDefaults(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults"
        alert.informativeText = "All settings will be reset to their default values."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        guard let window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.performReset()
        }
    }

    private func performReset() {
        settings.resetToDefaults()
        appearanceView?.reloadValues()
        behaviorView?.reloadValues()
    }

    // MARK: - Show / Hide

    /// ウィンドウを前面に表示する。既にウィンドウが存在する場合は前面に移動する。
    func showSettingsWindow() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
