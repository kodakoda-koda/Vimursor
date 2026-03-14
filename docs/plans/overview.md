# Vimursor — 概要・アーキテクチャ

macOSをキーボードのみで操作できるツール（Homerowの代替OSS）。
Swift + AppKit で実装。App Store非対応（Accessibility APIのためサンドボックス外配布）。

---

## 技術スタック

| 機能 | API / フレームワーク | 理由 |
|------|---------------------|------|
| UI要素の列挙 | `AXUIElement` (Accessibility API) | macOS上の全アプリのUI要素を取得できる唯一の公式API |
| グローバルホットキー | `CGEventTap` | バックグラウンドでもキー入力を捕捉・消費できる |
| 透明オーバーレイ | `NSPanel` (AppKit) | 全ウィンドウの最前面に透明パネルを浮かせられる |
| クリックシミュレーション | `CGEvent` | ハードウェアと同等のマウスイベントを発行できる |
| スクロール | `CGEvent` (scrollWheelEvent2) | 慣性スクロール対応のホイールイベントを送れる |
| ビルド | Swift Package Manager | Xcode IDEなしにコマンドラインでビルド可能 |

---

## 動作フロー

```
ユーザーがホットキーを押す
        ↓
最前面アプリのPIDを取得（NSWorkspace）
        ↓
AXUIElementでUI要素を非同期・バッチで列挙
        ↓
透明なNSPanelオーバーレイを最前面に表示
        ↓
各要素の座標にラベル（sa, df, gh...）を描画
        ↓
ユーザーがラベル文字を入力 → CGEventでクリック送信
        ↓
オーバーレイを非表示にして通常状態に戻る
```

---

## ディレクトリ構成

```
Sources/Vimursor/
├── main.swift               # エントリポイント
├── AppDelegate.swift        # ライフサイクル管理・権限チェック
├── HotkeyManager.swift      # CGEventTapによるグローバルホットキー
├── Accessibility/
│   ├── AXManager.swift              # AXUIElementラッパー（バッチ取得・クリック）
│   └── UIElementEnumerator.swift    # UI要素の再帰的列挙
├── Overlay/
│   ├── OverlayWindow.swift          # NSPanel（透明・最前面・全Space対応）
│   └── LabelGenerator.swift         # ラベル文字列生成（sa, df...）
├── HintMode/
│   ├── HintModeController.swift     # ヒントモードの状態管理
│   └── HintView.swift               # ラベルのNSView描画
├── SearchMode/
│   ├── SearchModeController.swift
│   └── SearchView.swift
└── ScrollMode/
    └── ScrollModeController.swift
```

---

## 既知の制約

- **App Store非対応** — App Sandbox下ではAXUIElementが機能しない。`.dmg`直接配布のみ
- **AXUIElement は本質的に遅い** — XPC経由のため。バッチ取得・非同期実行で対策が必要
- **UI操作はメインスレッド必須** — `DispatchQueue.main` で実行すること
- **Electronアプリは部分対応** — AXUIElementのアクセシビリティツリーが限定的
- **macOS Sonoma/Sequoiaで不安定なケースあり** — タイムアウト付きリトライを推奨
- **アクセシビリティ権限が必要** — 起動時に `AXIsProcessTrustedWithOptions` で確認・要求

---

## ロードマップ

| バージョン | 内容 | 計画ファイル |
|-----------|------|------------|
| **MVP** | ホットキー + ヒントモード（ラベル表示→クリック） | `mvp.md` |
| **v0.2** | 検索モード（Spotlight風テキスト検索） | MVP完了後に作成 |
| **v0.3** | スクロールモード（vim風 j/k/u/d） | v0.2完了後に作成 |
| **v0.4** | 右クリック・Cmd+クリック | v0.3完了後に作成 |
| **v1.0** | .appバンドル・Universal Binary・配布 | v0.4完了後に作成 |

---

## 参考リソース

- [nchudleigh/vimac](https://github.com/nchudleigh/vimac) — Homerowの前身OSS。実装パターンの参考
- [y3owk1n/neru](https://github.com/y3owk1n/neru) — Go製OSS。Recursive Gridモードあり
- [AXUIElement Apple Docs](https://developer.apple.com/documentation/applicationservices/axuielement)
- [CGEvent Apple Docs](https://developer.apple.com/documentation/coregraphics/cgevent)
