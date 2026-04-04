import ApplicationServices

// MARK: - Protocol

/// アクセシビリティ権限の状態を問い合わせるプロトコル。
/// テスト時にモックを差し込めるよう抽象化する。
protocol AccessibilityPermissionChecker {
    func isGranted() -> Bool
}

// MARK: - Production implementation

/// `AXIsProcessTrustedWithOptions` を使った本番実装。
/// 権限確認ダイアログは表示しない（nil を渡す）。
/// 代わりに AppDelegate.showPermissionAlert() でカスタム UI を提供する。
struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecker {
    func isGranted() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }
}
