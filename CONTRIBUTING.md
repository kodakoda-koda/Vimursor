# Contributing to Vimursor

## 開発環境セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/kodakoda-koda/Vimursor.git
cd Vimursor
git checkout develop
swift build
```

### 2. Accessibility 権限の設定

Vimursor は macOS の Accessibility API を使用するため、初回起動時にアクセシビリティ権限が必要です。

1. `.build/debug/Vimursor` を実行すると、権限ダイアログが表示される
2. 「システム設定」→「プライバシーとセキュリティ」→「アクセシビリティ」を開く
3. `Vimursor` または Terminal（`swift run` で実行する場合）を有効にする
4. 権限付与後、アプリを再起動する

権限がない状態でも起動自体は可能ですが、AXUIElement の操作（要素取得・クリック）が失敗します。

### 3. ビルドコマンド

```bash
swift build                        # デバッグビルド
swift build -c release             # リリースビルド
swift test                         # テスト実行
swift test --enable-code-coverage  # カバレッジ付きテスト
.build/debug/Vimursor              # デバッグ実行
```

---

## アーキテクチャ概要

### ディレクトリ構造

```
Sources/Vimursor/
├── main.swift               # エントリポイント
├── AppDelegate.swift        # ライフサイクル管理・権限チェック
├── HotkeyManager.swift      # CGEventTapによるグローバルホットキー
├── Accessibility/           # AXUIElementラッパー・UI要素列挙
├── Overlay/                 # NSPanel・ラベル生成
├── HintMode/                # ヒントモード制御・描画
├── SearchMode/              # 検索モード制御・UI
└── ScrollMode/              # スクロールモード制御
```

### 主要モジュールの役割

| モジュール | 役割 |
|-----------|------|
| `AppDelegate` | アプリ起動時の権限チェック、メニューバーアイコン管理 |
| `HotkeyManager` | `CGEventTap` でグローバルキーイベントを捕捉し各モードを起動 |
| `Accessibility/AXManager` | `AXUIElement` を通じてクリック可能・検索対象の要素を列挙、クリック実行 |
| `Overlay/LabelGenerator` | 要素数に応じたラベル文字列（`a`, `b`, ..., `aa`, `ab`, ...）を生成 |
| `Overlay/OverlayWindow` | `NSPanel` を使ったオーバーレイウィンドウの生成・配置 |
| `HintMode/HintModeController` | ヒントモードの状態管理（起動→ラベル表示→キー入力→クリック→終了） |
| `SearchMode/SearchModeController` | 検索モードの状態管理、テキストフィルタリング（純粋関数） |
| `ScrollMode/` | スクロールモードの状態管理、スクロール領域の検出 |

### 処理フロー（ヒントモード）

```
Cmd+Shift+Space
  → HotkeyManager
  → HintModeController.start()
  → AXManager.fetchClickableElements()
  → LabelGenerator.generate(count:)
  → OverlayWindow + HintView（ラベル描画）
  → キー入力でフィルタリング
  → 完全一致 → AXUIElementPerformAction("AXPress")
  → オーバーレイ閉じる
```

---

## コードスタイルガイドライン

詳細は `.claude/rules/common/coding-style.md` を参照してください。主要ルールを以下に示します。

### イミュータビリティ優先

- `class` より `struct`（値型）を使う
- `var` より `let` を使う

```swift
// 推奨
struct Config {
    let labels: [String]
}

// 非推奨
class Config {
    var labels: [String] = []
}
```

### ファイル・関数サイズ

- 関数は **50 行以内**
- ファイルは **200〜400 行** が目安、**800 行が上限**
- 大きくなる場合は機能・責務ごとにファイルを分割する

### エラーハンドリング

- `AXUIElement` が返す `AXError` は必ず確認する
- `Optional` の強制アンラップ（`!`）は禁止（`guard let` / `if let` を使う）
- Silent failure（エラーを握りつぶす）は禁止

### その他

- キーコード等の定数はファイル上部にまとめる（マジックナンバー禁止）
- UI 操作は必ず `DispatchQueue.main.async` で実行する
- デリゲート・クロージャの循環参照を防ぐため `[weak self]` を使う

---

## テスト方針

詳細は `.claude/rules/common/testing.md` を参照してください。

### TDD フロー

実装は必ずテストファーストで進めます。

1. **RED** — 失敗するテストを書く
2. **GREEN** — テストが通る最小実装を書く
3. **REFACTOR** — コードを改善しながらテストをグリーンに保つ

```bash
swift test   # RED / GREEN の確認
```

### テスト対象の分類

| 対象 | テスト方法 |
|------|-----------|
| 純粋ロジック（`LabelGenerator`、`SearchModeController.filter` 等） | Swift Testing で単体テスト |
| `AXUIElement` 呼び出し | プロトコルでラップしてモックに差し替え |
| `NSPanel` / `CGEventTap` | システム依存のため手動テスト |

### テストフレームワーク

`XCTest` ではなく **Swift Testing** を使います。

```swift
import Testing
@testable import Vimursor

@Suite("LabelGenerator Tests")
struct LabelGeneratorTests {
    @Test("generates correct count of labels")
    func generatesCorrectCount() {
        let labels = LabelGenerator.generate(count: 5)
        #expect(labels.count == 5)
    }
}
```

### カバレッジ目標

**80% 以上**を維持してください。

```bash
swift test --enable-code-coverage
```

---

## Issue 管理

開発は GitHub Issue を起点に進めます。

| ラベル | 用途 | タイトル例 |
|--------|------|-----------|
| `epic` | 機能グループ・マイルストーン | `[Epic 3] 配布基盤` |
| `task` | 個別の実装タスク（Epic の子） | `[3-1] .appバンドル化` |
| `memo` | 技術的知見・調査記録 | `[memo] AX座標系の変換` |
| `bug` | バグ報告 | `[bug] ヒントラベルが表示されない` |
| `enhancement` | 機能要望 | `[request] ダークモード対応` |

PR は対応する Issue 番号を紐づけてください。

---

## ブランチ運用

```
main           ── リリース済みの安定版
  └─ develop   ── 開発統合ブランチ
       ├─ feature/epic<N>-<name>  ── 機能単位の作業ブランチ（Epic 単位）
       ├─ fix/<name>              ── バグ修正ブランチ
       └─ docs/<name>             ── ドキュメントブランチ
```

### 通常の開発フロー（feature → develop）

```bash
# 1. develop から作業ブランチを切る
git checkout develop
git checkout -b feature/epic3-distribution

# 2. 実装・コミット
git commit -m "feat: Add my feature"

# 3. develop へ PR を出す
git push -u origin feature/epic3-distribution
# GitHub で PR を作成 → レビュー → squash merge
```

### リリースフロー（develop → release → main）

```bash
# 1. develop から release ブランチを切る
git checkout develop
git checkout -b release/v1.0

# 2. main に含めない開発用ファイルを削除してコミット
git rm -r .claude/ CLAUDE.md
git commit -m "chore: Remove dev-only files for release"

# 3. release → main へ PR を出す
git push -u origin release/v1.0
# GitHub で PR を作成 → 確認 → squash merge

# 4. main にタグを打つ
git checkout main
git pull
git tag v1.0
git push origin v1.0
```

### `main` に含めないファイル

| ファイル/ディレクトリ | 理由 |
|----------------------|------|
| `.claude/` | Claude Code 設定（開発ツール） |
| `CLAUDE.md` | エージェント向けプロジェクト指示 |

---

## コミットメッセージ

```
<type>: <description>
```

| type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `refactor` | リファクタリング |
| `docs` | ドキュメントのみの変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルド設定・ツール等 |
| `perf` | パフォーマンス改善 |

---

## PR のガイドライン

### PR の単位

- **PR は Epic 単位**でまとめます（タスク単位では出しません）
- `feature/**` / `fix/**` / `docs/**` → `develop` へ PR
- `release/**` → `main` へ PR

### マージ方式

すべての PR は **squash merge** で取り込みます。

### PR タイトル・本文

- タイトルはコミットメッセージと同じ形式（`feat: ...`）
- 本文には対象 Issue を `Closes #XX` で列挙する（squash merge 後に自動クローズされる）
- Epic Issue 自体も `Closes #N` に含める

### PR テンプレートの使い分け

| 用途 | テンプレート | 使い方 |
|------|------------|--------|
| `develop` 向け（通常開発） | `.github/pull_request_template.md` | PR 作成時のデフォルト |
| `main` 向け（リリース） | `.github/PULL_REQUEST_TEMPLATE/release.md` | PR URL に `?template=release.md` を付与 |

リリース PR を作成する場合は GitHub の URL に `?template=release.md` を追加してください。

```
https://github.com/kodakoda-koda/Vimursor/compare/main...release/v1.0?template=release.md
```
