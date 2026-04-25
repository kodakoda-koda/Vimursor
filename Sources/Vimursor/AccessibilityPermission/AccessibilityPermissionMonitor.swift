import Foundation

// MARK: - Monitor

/// アクセシビリティ権限の付与をポーリングで監視するクラス。
///
/// `startPolling(onGranted:)` を呼ぶと指定間隔でチェックを行い、
/// 権限が付与されたタイミングで `onGranted` を1度だけ呼び出す。
/// `stopPolling()` でタイマーを停止できる。
@MainActor
final class AccessibilityPermissionMonitor {

    // MARK: - Private properties

    private let checker: any AccessibilityPermissionChecker
    private let interval: TimeInterval
    private var pollingTask: Task<Void, Never>?
    private var onGranted: (() -> Void)?

    // MARK: - Initialization

    /// - Parameters:
    ///   - checker: 権限状態を問い合わせるプロバイダ
    ///   - interval: ポーリング間隔（秒）。デフォルト 1.0 秒
    init(checker: any AccessibilityPermissionChecker, interval: TimeInterval = 1.0) {
        self.checker = checker
        self.interval = interval
    }

    // NOTE: deinit では Task のキャンセルを行わない。
    // Swift 6 の deinit は nonisolated であり、@MainActor プロパティへの直接アクセスは不可。
    // MainActor.assumeIsolated はバックグラウンドスレッドからの解放時にクラッシュするリスクがある。
    // 呼び出し側が不要になったタイミングで stopPolling() を呼ぶこと。

    // MARK: - Public interface

    /// ポーリングを開始する。権限が付与されたら `onGranted` を呼び出してタスクを停止する。
    /// すでにポーリング中の場合は先のタスクをキャンセルしてから再開する。
    /// - Parameter onGranted: 権限付与検出時に **メインスレッド** で呼ばれるクロージャ
    func startPolling(onGranted: @escaping () -> Void) {
        stopPolling()
        self.onGranted = onGranted

        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.handleTimerFire()
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000))
            }
        }
    }

    /// ポーリングを停止する。
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        onGranted = nil
    }

    // MARK: - Private

    private func handleTimerFire() {
        guard checker.isGranted() else { return }
        // 権限付与を検出 — タイマーを先に停止してからコールバックを1度だけ呼ぶ
        let callback = onGranted
        stopPolling()
        callback?()
    }
}
