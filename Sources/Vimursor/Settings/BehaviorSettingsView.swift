import AppKit

// MARK: - BehaviorSettingsView

/// Behavior タブのコンテンツビュー。
/// ヒント文字セット・連続モード・ディレイ・スクロール量などの挙動設定 UI を提供する。
@MainActor
final class BehaviorSettingsView: NSView {

    // MARK: - Constants

    private enum Layout {
        static let margin: CGFloat = 20
        static let rowHeight: CGFloat = 30
        static let rowSpacing: CGFloat = 12
        static let labelWidth: CGFloat = 200
        static let stepperWidth: CGFloat = 15
        static let valueFieldWidth: CGFloat = 50
    }

    // MARK: - Properties

    private let settings: AppSettings

    // Controls
    private let hintCharSetField = NSTextField()
    private let continuousModeCheckbox = NSButton()
    private let reactivationDelayField = NSTextField()
    private let reactivationDelayStepper = NSStepper()
    private let scrollStepField = NSTextField()
    private let scrollStepStepper = NSStepper()

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
        // Hint Character Set
        hintCharSetField.stringValue = settings.hintCharacterSet
        hintCharSetField.isEditable = true
        hintCharSetField.isBordered = true
        hintCharSetField.delegate = self
        hintCharSetField.placeholderString = "例: fjrieodks"

        // Continuous Mode
        continuousModeCheckbox.setButtonType(.switch)
        continuousModeCheckbox.title = ""
        continuousModeCheckbox.state = settings.isContinuousMode ? .on : .off
        continuousModeCheckbox.target = self
        continuousModeCheckbox.action = #selector(continuousModeChanged(_:))

        // Reactivation Delay
        reactivationDelayField.stringValue = String(format: "%.1f", settings.reactivationDelay)
        reactivationDelayField.isEditable = false
        reactivationDelayField.isBordered = true
        reactivationDelayField.alignment = .right

        reactivationDelayStepper.minValue = 0.1
        reactivationDelayStepper.maxValue = 2.0
        reactivationDelayStepper.increment = 0.1
        reactivationDelayStepper.doubleValue = settings.reactivationDelay
        reactivationDelayStepper.target = self
        reactivationDelayStepper.action = #selector(reactivationDelayChanged(_:))

        // Scroll Step Lines
        scrollStepField.stringValue = "\(settings.scrollStepLines)"
        scrollStepField.isEditable = false
        scrollStepField.isBordered = true
        scrollStepField.alignment = .right

        scrollStepStepper.minValue = 1
        scrollStepStepper.maxValue = 20
        scrollStepStepper.increment = 1
        scrollStepStepper.doubleValue = Double(settings.scrollStepLines)
        scrollStepStepper.target = self
        scrollStepStepper.action = #selector(scrollStepChanged(_:))
    }

    private func setupLayout() {
        // 各行: (ラベルテキスト, コントロール群)
        let rows: [(String, [NSView])] = [
            ("Hint Characters:", [hintCharSetField]),
            ("Continuous Hint Mode:", [continuousModeCheckbox]),
            ("Reactivation Delay (s):", [reactivationDelayField, reactivationDelayStepper]),
            ("Scroll Step Lines:", [scrollStepField, scrollStepStepper])
        ]

        for (index, row) in rows.enumerated() {
            let label = makeLabel(row.0)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)

            let yOffset = Layout.margin + CGFloat(rows.count - 1 - index) * (Layout.rowHeight + Layout.rowSpacing)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.margin),
                label.widthAnchor.constraint(equalToConstant: Layout.labelWidth),
                label.centerYAnchor.constraint(equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2)
            ])

            var xOffset = Layout.margin + Layout.labelWidth + 8
            for control in row.1 {
                control.translatesAutoresizingMaskIntoConstraints = false
                addSubview(control)

                switch control {
                case let stepper as NSStepper:
                    NSLayoutConstraint.activate([
                        stepper.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
                        stepper.widthAnchor.constraint(equalToConstant: Layout.stepperWidth),
                        stepper.centerYAnchor.constraint(
                            equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2
                        )
                    ])
                    xOffset += Layout.stepperWidth + 4
                case let button as NSButton:
                    NSLayoutConstraint.activate([
                        button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
                        button.centerYAnchor.constraint(
                            equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2
                        )
                    ])
                default:
                    let fieldWidth: CGFloat = control === hintCharSetField ? 160 : Layout.valueFieldWidth
                    NSLayoutConstraint.activate([
                        control.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xOffset),
                        control.widthAnchor.constraint(equalToConstant: fieldWidth),
                        control.centerYAnchor.constraint(
                            equalTo: topAnchor, constant: yOffset + Layout.rowHeight / 2
                        )
                    ])
                    xOffset += fieldWidth + 4
                }
            }
        }
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    // MARK: - Validation

    /// ヒント文字セットの入力をバリデートする。
    /// - Returns: バリデーション成功なら true
    private func validateHintCharacterSet(_ value: String) -> Bool {
        guard value.count >= 2 else { return false }
        let chars = Array(value)
        return chars.count == Set(chars).count  // 重複なし
    }

    private func applyValidationFeedback(_ isValid: Bool, to field: NSTextField) {
        field.backgroundColor = isValid ? .textBackgroundColor : NSColor.systemRed.withAlphaComponent(0.3)
        field.drawsBackground = !isValid
    }

    // MARK: - Actions

    @objc private func continuousModeChanged(_ sender: NSButton) {
        settings.isContinuousMode = sender.state == .on
    }

    @objc private func reactivationDelayChanged(_ sender: NSStepper) {
        let value = sender.doubleValue
        reactivationDelayField.stringValue = String(format: "%.1f", value)
        settings.reactivationDelay = value
    }

    @objc private func scrollStepChanged(_ sender: NSStepper) {
        let value = Int(sender.doubleValue)
        scrollStepField.stringValue = "\(value)"
        settings.scrollStepLines = value
    }

    // MARK: - Public

    /// 設定の現在値をコントロールに反映する（Reset 後などに使用）。
    func reloadValues() {
        hintCharSetField.stringValue = settings.hintCharacterSet
        applyValidationFeedback(true, to: hintCharSetField)
        continuousModeCheckbox.state = settings.isContinuousMode ? .on : .off
        reactivationDelayStepper.doubleValue = settings.reactivationDelay
        reactivationDelayField.stringValue = String(format: "%.1f", settings.reactivationDelay)
        scrollStepStepper.doubleValue = Double(settings.scrollStepLines)
        scrollStepField.stringValue = "\(settings.scrollStepLines)"
    }
}

// MARK: - NSTextFieldDelegate

extension BehaviorSettingsView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === hintCharSetField else { return }
        let value = field.stringValue
        let isValid = validateHintCharacterSet(value)
        applyValidationFeedback(isValid, to: field)
        if isValid {
            settings.hintCharacterSet = value
        }
    }
}
