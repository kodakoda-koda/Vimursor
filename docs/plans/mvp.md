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

逐次取得ではなくバッチ取得を使う:

```swift
let attributes = [kAXPositionAttribute, kAXSizeAttribute, kAXTitleAttribute, kAXRoleAttribute]
    as [CFString]
var valuesRef: CFArray?
AXUIElementCopyMultipleAttributeValues(element, attributes as CFArray, .stopOnError, &valuesRef)
```

UI要素の列挙はバックグラウンドキューで実行し、UIはメインスレッドで更新する。

### クリック処理の順序（重要）

オーバーレイを先に非表示にしてからクリックする:

```swift
deactivate()  // 先にオーバーレイを消す
DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
    self.axManager.click(element: match.element)
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
[ ] Setup: swift package init, Package.swift, Info.plist, entitlements
[ ] Phase 1-1: main.swift + AppDelegate.swift（起動・権限チェック）
[ ] Phase 1-2: Overlay/OverlayWindow.swift（透明NSPanel）
[ ] Phase 1-3: HotkeyManager.swift（CGEventTap）
[ ] Phase 1 動作確認: Cmd+Shift+Space でオーバーレイ表示/非表示
[ ] Phase 2-1: Accessibility/AXManager.swift（バッチ取得・クリック）
[ ] Phase 2-2: Accessibility/UIElementEnumerator.swift（再帰的列挙）
[ ] Phase 2-3: Overlay/LabelGenerator.swift（ラベル生成）
[ ] Phase 2-4: HintMode/HintView.swift（ラベル描画・前方一致フィルタ）
[ ] Phase 2-5: HintMode/HintModeController.swift（状態管理）
[ ] MVP 動作確認: ラベル入力でクリック、ESCでキャンセル
```
