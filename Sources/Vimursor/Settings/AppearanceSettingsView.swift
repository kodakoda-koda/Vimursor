import AppKit

// MARK: - AppearanceSettingsView

/// Appearance タブのコンテンツビュー。
/// ラベルのフォントサイズ・色・背景色・透明度などの外観設定 UI を提供する。
@MainActor
final class AppearanceSettingsView: NSView {

    // MARK: - Constants

    private enum Layout {
        static let margin: CGFloat = 20
        static let rowHeight: CGFloat = 30
        static let rowSpacing: CGFloat = 12
        static let labelWidth: CGFloat = 160
        static let controlWidth: CGFloat = 200
        static let colorWellWidth: CGFloat = 44
        static let colorWellHeight: CGFloat = 28
        static let stepperWidth: CGFloat = 15
        static let valueFieldWidth: CGFloat = 50
    }

    // MARK: - Properties

    private let settings: AppSettings

    // Controls
    private let fontSizeField = NSTextField()
    private let fontSizeStepper = NSStepper()
    private let textColorWell = NSColorWell()
    private let backgroundColorWell = NSColorWell()
    private let bgOpacitySlider = NSSlider()
    private let bgOpacityField = NSTextField()
    private let searchBarOpacitySlider = NSSlider()
    private let searchBarOpacityField = NSTextField()

    // MARK: - Initialization

    init(settings: AppSettings) {
        self.settings = settings
        super.init(frame: .zero)
        setupControls()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Setup

    private func setupControls() {
        // Font Size
        fontSizeField.stringValue = "\(Int(settings.labelFontSize))"
        fontSizeField.isEditable = false
        fontSizeField.isBordered = true
        fontSizeField.alignment = .right

        fontSizeStepper.minValue = 8
        fontSizeStepper.maxValue = 24
        fontSizeStepper.increment = 1
        fontSizeStepper.doubleValue = Double(settings.labelFontSize)
        fontSizeStepper.target = self
        fontSizeStepper.action = #selector(fontSizeStepperChanged(_:))

        // Text Color
        textColorWell.color = settings.labelTextColor
        textColorWell.target = self
        textColorWell.action = #selector(textColorChanged(_:))

        // Background Color
        backgroundColorWell.color = settings.labelBackgroundColor
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(backgroundColorChanged(_:))

        // Background Opacity
        bgOpacitySlider.minValue = 0.0
        bgOpacitySlider.maxValue = 1.0
        bgOpacitySlider.doubleValue = Double(settings.labelBackgroundOpacity)
        bgOpacitySlider.target = self
        bgOpacitySlider.action = #selector(bgOpacitySliderChanged(_:))

        bgOpacityField.stringValue = String(format: "%.2f", settings.labelBackgroundOpacity)
        bgOpacityField.isEditable = false
        bgOpacityField.isBordered = true
        bgOpacityField.alignment = .right

        // Search Bar Opacity
        searchBarOpacitySlider.minValue = 0.0
        searchBarOpacitySlider.maxValue = 1.0
        searchBarOpacitySlider.doubleValue = Double(settings.searchBarOpacity)
        searchBarOpacitySlider.target = self
        searchBarOpacitySlider.action = #selector(searchBarOpacitySliderChanged(_:))

        searchBarOpacityField.stringValue = String(format: "%.2f", settings.searchBarOpacity)
        searchBarOpacityField.isEditable = false
        searchBarOpacityField.isBordered = true
        searchBarOpacityField.alignment = .right
    }

    private func setupLayout() {
        let rows: [(label: String, controls: [NSView])] = [
            ("Font Size:", [fontSizeField, fontSizeStepper]),
            ("Text Color:", [textColorWell]),
            ("Background Color:", [backgroundColorWell]),
            ("Background Opacity:", [bgOpacitySlider, bgOpacityField]),
            ("Search Bar Opacity:", [searchBarOpacitySlider, searchBarOpacityField])
        ]

        for (index, row) in rows.enumerated() {
            let label = makeLabel(row.label)

            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)

            let yOffset = Layout.margin + CGFloat(rows.count - 1 - index) * (Layout.rowHeight + Layout.rowSpacing)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.margin),
                label.widthAnchor.constraint(equalToConstant: Layout.labelWidth),
                label.centerYAnchor.constraint(equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2)
            ])

            var xOffset = Layout.margin + Layout.labelWidth + 8
            for control in row.controls {
                control.translatesAutoresizingMaskIntoConstraints = false
                addSubview(control)

                switch control {
                case let cw as NSColorWell:
                    NSLayoutConstraint.activate([
                        cw.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
                        cw.widthAnchor.constraint(equalToConstant: Layout.colorWellWidth),
                        cw.heightAnchor.constraint(equalToConstant: Layout.colorWellHeight),
                        cw.centerYAnchor.constraint(equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2)
                    ])
                    xOffset += Layout.colorWellWidth + 4
                case let slider as NSSlider:
                    NSLayoutConstraint.activate([
                        slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
                        slider.widthAnchor.constraint(equalToConstant: 140),
                        slider.centerYAnchor.constraint(equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2)
                    ])
                    xOffset += 144
                case let stepper as NSStepper:
                    NSLayoutConstraint.activate([
                        stepper.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
                        stepper.widthAnchor.constraint(equalToConstant: Layout.stepperWidth),
                        stepper.centerYAnchor.constraint(equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2)
                    ])
                    xOffset += Layout.stepperWidth + 4
                default:
                    NSLayoutConstraint.activate([
                        control.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
                        control.widthAnchor.constraint(equalToConstant: Layout.valueFieldWidth),
                        control.centerYAnchor.constraint(equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2)
                    ])
                    xOffset += Layout.valueFieldWidth + 4
                }
            }
        }
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    // MARK: - Actions

    @objc private func fontSizeStepperChanged(_ sender: NSStepper) {
        let value = Int(sender.doubleValue)
        fontSizeField.stringValue = "\(value)"
        settings.labelFontSize = CGFloat(value)
    }

    @objc private func textColorChanged(_ sender: NSColorWell) {
        settings.labelTextColor = sender.color
    }

    @objc private func backgroundColorChanged(_ sender: NSColorWell) {
        settings.labelBackgroundColor = sender.color
    }

    @objc private func bgOpacitySliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        bgOpacityField.stringValue = String(format: "%.2f", value)
        settings.labelBackgroundOpacity = CGFloat(value)
    }

    @objc private func searchBarOpacitySliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        searchBarOpacityField.stringValue = String(format: "%.2f", value)
        settings.searchBarOpacity = CGFloat(value)
    }

    // MARK: - Public

    /// 設定の現在値をコントロールに反映する（Reset 後などに使用）。
    func reloadValues() {
        fontSizeStepper.doubleValue = Double(settings.labelFontSize)
        fontSizeField.stringValue = "\(Int(settings.labelFontSize))"
        textColorWell.color = settings.labelTextColor
        backgroundColorWell.color = settings.labelBackgroundColor
        bgOpacitySlider.doubleValue = Double(settings.labelBackgroundOpacity)
        bgOpacityField.stringValue = String(format: "%.2f", settings.labelBackgroundOpacity)
        searchBarOpacitySlider.doubleValue = Double(settings.searchBarOpacity)
        searchBarOpacityField.stringValue = String(format: "%.2f", settings.searchBarOpacity)
    }
}
