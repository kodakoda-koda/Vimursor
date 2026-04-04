import Testing
import Foundation
@testable import Vimursor

// MARK: - Mock

/// テスト用モック。isGranted() の戻り値を外部から制御できる。
/// NOTE: granted を外部から書き換えて Monitor 内部に伝播させるため、
/// 参照セマンティクスが必要。struct ではコピーされるため不可。
final class MockAccessibilityPermissionChecker: AccessibilityPermissionChecker {
    var granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func isGranted() -> Bool {
        granted
    }
}

// MARK: - Tests

@Suite("AccessibilityPermissionMonitorTests")
@MainActor
struct AccessibilityPermissionMonitorTests {

    // MARK: - startPolling: 初回から権限あり

    @Test("権限が最初から付与済みならポーリング開始直後にコールバックが呼ばれること")
    func callsOnGrantedImmediatelyWhenAlreadyGranted() async throws {
        let checker = MockAccessibilityPermissionChecker(granted: true)
        let monitor = AccessibilityPermissionMonitor(checker: checker, interval: 0.05)

        var called = false
        monitor.startPolling {
            called = true
        }

        // Timer は RunLoop 経由なので少し待つ
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        monitor.stopPolling()

        #expect(called == true)
    }

    // MARK: - startPolling: 権限なし → 後から付与

    @Test("権限なし→付与でコールバックが呼ばれること")
    func callsOnGrantedAfterPermissionIsGiven() async throws {
        let checker = MockAccessibilityPermissionChecker(granted: false)
        let monitor = AccessibilityPermissionMonitor(checker: checker, interval: 0.05)

        var callCount = 0
        monitor.startPolling {
            callCount += 1
        }

        // 権限なしの間は呼ばれない
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        #expect(callCount == 0)

        // 権限付与をシミュレート
        checker.granted = true
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        monitor.stopPolling()

        #expect(callCount == 1)
    }

    // MARK: - startPolling: コールバックは1度だけ

    @Test("権限付与後にコールバックは1度だけ呼ばれること")
    func callsOnGrantedOnlyOnce() async throws {
        let checker = MockAccessibilityPermissionChecker(granted: true)
        let monitor = AccessibilityPermissionMonitor(checker: checker, interval: 0.05)

        var callCount = 0
        monitor.startPolling {
            callCount += 1
        }

        // 複数回ポーリングが走っても1度だけ
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        monitor.stopPolling()

        #expect(callCount == 1)
    }

    // MARK: - stopPolling

    @Test("stopPolling後はコールバックが呼ばれないこと")
    func doesNotCallOnGrantedAfterStop() async throws {
        let checker = MockAccessibilityPermissionChecker(granted: false)
        let monitor = AccessibilityPermissionMonitor(checker: checker, interval: 0.05)

        var callCount = 0
        monitor.startPolling {
            callCount += 1
        }

        monitor.stopPolling()

        // 停止後に権限付与してもコールバックは呼ばれない
        checker.granted = true
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        #expect(callCount == 0)
    }
}
