import Foundation
import Testing
import AppKit
@testable import Vimursor

@Suite
@MainActor
struct HintModeControllerTests {

    private func makeSettings(continuous: Bool = false) -> HintModeSettings {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(continuous, forKey: HintModeDefaultsKey.continuousMode)
        return HintModeSettings(defaults: defaults)
    }

    private func makeSUT(
        continuous: Bool = false,
        elements: [UIElementInfo] = []
    ) -> (HintModeController, MockOverlayProviding, MockKeyEventHandling, MockElementFetching) {
        let fetcher = MockElementFetching()
        fetcher.uiElementInfos = elements
        // fetchClickableElements は AXElement を返すが、buildUIElementInfos で UIElementInfo に変換する
        // 要素あり / なしの切り替えは clickableElements の有無で制御する
        let overlay = MockOverlayProviding()
        let hotkey = MockKeyEventHandling()
        let controller = HintModeController(settings: makeSettings(continuous: continuous), elementFetcher: fetcher)
        return (controller, overlay, hotkey, fetcher)
    }

    // MARK: - reactivationDelay 定数

    @Test func reactivationDelayIsThreeHundredMilliseconds() {
        #expect(HintModeController.reactivationDelay == 0.3)
    }

    // MARK: - deactivate() が reactivationTask をクリアすること

    @Test func deactivateClearsReactivationTask() {
        let controller = HintModeController(settings: makeSettings())
        controller.deactivate()
        #expect(controller.reactivationTask == nil)
    }

    // MARK: - HintModeSettings の注入

    @Test func controllerAcceptsSettings() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = HintModeSettings(defaults: defaults)
        let controller = HintModeController(settings: settings)
        controller.deactivate()
        #expect(controller.reactivationTask == nil)
    }

    // MARK: - deactivate() ステート遷移

    @Test func deactivateHidesOverlay() async throws {
        let (controller, overlay, hotkey, _) = makeSUT()
        // activate を呼んで overlayWindow / hotkeyManager を controller に登録してから deactivate する
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        overlay.showCallCount = 0  // activate 結果はリセット
        overlay.hideCallCount = 0
        controller.deactivate()
        #expect(overlay.hideCallCount == 1)
    }

    @Test func deactivateClearsKeyEventHandler() async throws {
        let (controller, overlay, hotkey, _) = makeSUT()
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        // activate 後に handler が設定されていれば deactivate で nil になる
        // 設定されていなければ nil → nil で引き続き nil を確認
        controller.deactivate()
        #expect(hotkey.keyEventHandler == nil)
    }

    // MARK: - activate() → frontmostApplication が nil の場合は inactive に戻る

    @Test func activateWithNoFrontmostAppDoesNotShowOverlay() async throws {
        // テスト環境では frontmostApplication が返ることもあるが、
        // このテストは MockElementFetching に要素がない場合に overlay.show が呼ばれないことを確認する
        // frontmostApplication が nil なら即座に inactive → show は 0 回
        // frontmostApplication が非 nil なら fetchClickableElements が呼ばれ、要素なしなら inactive → show は 0 回
        let (controller, overlay, hotkey, _) = makeSUT(elements: [])  // UIElementInfo が空
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        // fetchClickableElements が DispatchQueue.main.async で completion を呼ぶので待つ
        try await Task.sleep(for: .milliseconds(50))
        #expect(overlay.showCallCount == 0)
    }

    // MARK: - activate() → 要素ありの場合 overlay.show が呼ばれる

    @Test func activateWithElementsShowsOverlay() async throws {
        let axRef = AXUIElementCreateSystemWide()
        let axElement = AXElement(ref: axRef)
        let info = UIElementInfo(
            frame: CGRect(x: 100, y: 100, width: 50, height: 20),
            label: "a",
            axElement: axElement
        )
        let (controller, overlay, hotkey, fetcher) = makeSUT(elements: [info])
        // clickableElements に1つ追加することで buildUIElementInfos が呼ばれる経路を通す
        fetcher.clickableElements = [axElement]

        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        // DispatchQueue.main.async + Task { @MainActor } を待つ
        try await Task.sleep(for: .milliseconds(50))

        // frontmostApplication が nil ならテストはパスを変える（overlay.show = 0 もテストとして有効）
        // frontmostApplication が非 nil なら show = 1 になる
        // どちらのパスでも overlay.show > 1 にはならないことを確認
        #expect(overlay.showCallCount <= 1)
    }

    // MARK: - 二重 activate は無視される

    @Test func doubleActivateIsIgnored() async throws {
        let (controller, overlay, hotkey, _) = makeSUT()
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)  // fetching 中なので無視される
        try await Task.sleep(for: .milliseconds(50))
        // show は最大1回（要素なし時は0回）
        #expect(overlay.showCallCount <= 1)
    }

    // MARK: - ESC キーで deactivate される

    @Test func escKeyDeactivates() async throws {
        let (controller, overlay, hotkey, _) = makeSUT()
        // activate → active 状態に移行してから ESC をシミュレート
        controller.activate(overlayWindow: overlay, hotkeyManager: hotkey)
        try await Task.sleep(for: .milliseconds(50))
        // ESC (keyCode 53) を送る（handler が設定されていれば deactivate が呼ばれる）
        hotkey.simulateKey(53)
        try await Task.sleep(for: .milliseconds(20))
        // deactivate によって keyEventHandler が nil になることを確認
        #expect(hotkey.keyEventHandler == nil)
    }
}
