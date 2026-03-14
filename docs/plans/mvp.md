# MVP 実装プラン

アーキテクチャ・制約の詳細は `overview.md` を参照。

---

## MVP の完了条件

1. `Cmd+Shift+Space` で画面上のクリック可能要素にラベルが表示される
2. ラベルを入力すると対応するUI要素がクリックされる
3. `ESC` でキャンセルできる

---

## Setup

### 前提条件確認

```bash
xcode-select -p      # インストール済みであること
swift --version      # Swift利用可能であること
```

### Swift Package 初期化

```bash
cd ~/Desktop/repos/Vimursor
swift package init --type executable --name Vimursor
```

`swift package init` が生成するデフォルトの `Sources/Vimursor/main.swift` は後で上書きする。

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Vimursor",
    platforms: [
        .macOS(.v13)  // AXUIElementの安定APIのため
    ],
    targets: [
        .executableTarget(
            name: "Vimursor",
            path: "Sources/Vimursor"
        )
    ]
)
```

### Info.plist

`Sources/Vimursor/Info.plist` に作成（メニューバーアプリとして動作させる設定）:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIdentifier</key>
    <string>com.vimursor.app</string>
    <key>CFBundleName</key>
    <string>Vimursor</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>Vimursor needs accessibility access to detect UI elements and simulate clicks.</string>
</dict>
</plist>
```

### Vimursor.entitlements

`Sources/Vimursor/Vimursor.entitlements` に作成（サンドボックス無効化）:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

---

## Phase 1: グローバルホットキー + 透明オーバーレイ

**目標:** `Cmd+Shift+Space` で透明パネルが表示/非表示される。

### 実装ファイル

| ファイル | 役割 |
|---------|------|
| `main.swift` | NSApplication起動、AppDelegateを設定 |
| `AppDelegate.swift` | 権限チェック、OverlayWindow・HotkeyManager初期化 |
| `Overlay/OverlayWindow.swift` | NSPanel（透明・最前面・全Space対応） |
| `HotkeyManager.swift` | CGEventTapでホットキー検知 |

### ポイント

- `OverlayWindow` は `level = .screenSaver`、`ignoresMouseEvents = true`、`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- `CGEventTap` は `.cgSessionEventTap` / `.headInsertEventTap` で作成し、消費したイベントは `nil` を返す
- ホットキー検知後の処理は必ず `DispatchQueue.main.async` 経由でUI操作する

### ホットキー（MVP時点）

| ホットキー | 動作 |
|-----------|------|
| `Cmd+Shift+Space`（keyCode: 49） | ヒントモード起動 |

### 動作確認

```bash
swift build && .build/debug/Vimursor
# Cmd+Shift+Space で透明パネルが表示/非表示されれば Phase 1 完了
```

---

## Phase 2: ヒントモード（ラベル表示 → クリック）

**目標:** ラベルを入力すると対応するUI要素がクリックされる。

### 実装ファイル

| ファイル | 役割 |
|---------|------|
| `Accessibility/AXManager.swift` | AXUIElementラッパー（バッチ取得・クリック） |
| `Accessibility/UIElementEnumerator.swift` | UI要素の再帰的列挙 |
| `Overlay/LabelGenerator.swift` | ラベル文字列生成 |
| `HintMode/HintView.swift` | ラベルのNSView描画 |
| `HintMode/HintModeController.swift` | 状態管理（入力・マッチング・ESC） |

### ラベル生成

ホームポジション優先（Vimiumと同様）:

```
chars = "sadfjklewcmpgh"
1文字ラベルを先に割り当て → 足りなければ2文字ラベルを生成
```

### AXUIElement バッチ取得（パフォーマンス対策）

逐次取得ではなくバッチ取得を使う。

**Swift 6 注意**: `kAXPositionAttribute` 等の C グローバルは Swift 6 で "not concurrency-safe" エラーになる。生の文字列を使うこと:

```swift
// NG: kAXPositionAttribute 等の C グローバルは Swift 6 非互換
// OK: 生の文字列を使う
let attributes = ["AXPosition", "AXSize", "AXTitle", "AXRole"] as [CFString]
var valuesRef: CFArray?
AXUIElementCopyMultipleAttributeValues(element, attributes as CFArray, .stopOnError, &valuesRef)
```

UI要素の列挙はバックグラウンドキューで実行し、UIはメインスレッドで更新する。

**Swift 6 注意**: `AXUIElement`（CFTypeRef）は `Sendable` 非準拠。バックグラウンドからメインスレッドへ渡すと Swift 6 エラーになる。

対策: `UIElementInfo` 構造体は値型のみ（座標・サイズ・ラベル文字列）で構成し、クリック時に必要な `AXUIElement` は `@unchecked Sendable` でラップするか、enumeration 完了後にメインスレッドで改めて取得する。

```swift
// Sendable な値型として定義
struct UIElementInfo: Sendable {
    let frame: CGRect      // NSWindow座標系に変換済み
    let label: String      // 割り当てたラベル文字列
    let axElement: AXElement  // AXUIElementのSendableラッパー
}

// AXUIElementのSendableラッパー
struct AXElement: @unchecked Sendable {
    let ref: AXUIElement
}
```

### キー入力ルーティング（HintMode 中）

`HotkeyManager` が全 keyDown を捕捉しているため、HintMode 中はキー入力を `HintModeController` に委譲する。

```swift
// HotkeyManager に委譲ハンドラを追加
// 戻り値 true = イベント消費、false = 通常処理
var keyEventHandler: ((CGKeyCode, CGEventFlags) -> Bool)?

// handleEvent 内で委譲
if let handler = keyEventHandler, handler(keyCode, flags) {
    return nil  // 消費
}
```

`HintModeController` の `activate()` 時に `hotkeyManager.keyEventHandler` をセットし、`deactivate()` 時に `nil` に戻す。

### クリック処理の順序（重要）

オーバーレイを先に非表示にしてからクリックする:

```swift
deactivate()  // 先にオーバーレイを消す
DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
    self.axManager.click(element: match.axElement.ref)
}
```

### 座標系の注意

AXUIElementの座標はmacOS座標系（原点:左下）ではなくスクリーン座標系（原点:左上）。
NSWindowの座標系（原点:左下）への変換が必要:

```swift
let screenHeight = NSScreen.main?.frame.height ?? 0
let convertedY = screenHeight - position.y - size.height
```

---

## 実装チェックリスト

```
[x] Setup: swift package init, Package.swift, Info.plist, entitlements
    Note: swift-tools-version 6.0（CLT 16.2 x86_64 ABI バグ回避）
          platforms: [.macOS(.v13)] は Swift.org ツールチェーン使用時は指定可能
[x] Phase 1-1: main.swift + AppDelegate.swift（起動・権限チェック）
[x] Phase 1-2: Overlay/OverlayWindow.swift（透明NSPanel）
[x] Phase 1-3: HotkeyManager.swift（CGEventTap）
[x] Phase 1 動作確認: Cmd+Shift+Space でオーバーレイ表示/非表示
    Note: hidesOnDeactivate = false が必須（デフォルト true だと非アクティブ時に即消える）
          orderFrontRegardless() を使用 / main.swift で setActivationPolicy(.regular)
[x] Phase 2-1: Accessibility/AXManager.swift（バッチ取得・クリック）
[x] Phase 2-2: Accessibility/UIElementEnumerator.swift（再帰的列挙）
[x] Phase 2-3: Overlay/LabelGenerator.swift（ラベル生成）
[x] Phase 2-4: HintMode/HintView.swift（ラベル描画・前方一致フィルタ）
[x] Phase 2-5: HintMode/HintModeController.swift（状態管理）
[x] MVP 動作確認: ラベル入力でクリック、ESCでキャンセル
```
