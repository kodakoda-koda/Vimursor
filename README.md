# Vimursor

macOS をキーボードのみで操作するためのオープンソースツールです。Accessibility API を活用し、画面上の UI 要素をキーボードだけでクリック・スクロールできます。

App Store 非対応（Accessibility API のためサンドボックス外配布）。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/kodakoda-koda/Vimursor/actions/workflows/ci.yml/badge.svg)](https://github.com/kodakoda-koda/Vimursor/actions/workflows/ci.yml)

---

<!-- TODO: Add screenshot/GIF demonstrating hint mode -->

## 機能

| ショートカット | 機能 |
|--------------|------|
| `Cmd+Shift+Space` | **ヒントモード** — 画面上のクリック可能な要素にラベルを表示し、キー入力でクリック |
| `Cmd+Shift+/` | **検索モード** — テキスト入力で要素を絞り込み、Enter でクリック |
| `Cmd+Shift+J` | **スクロールモード** — キーボードでスクロール操作 |

ショートカットはメニューバーアイコン → 「設定...」から変更できます。

### ヒントモード

<!-- TODO: Add GIF demonstrating hint mode -->

1. `Cmd+Shift+Space` を押すと、クリック可能な要素すべてにラベル（`A`、`B`、`SA` 等）が表示される
2. ラベルに表示されているキーを入力する（例: `S` → `A` の順に入力）
3. 対応する要素が自動でクリックされ、ヒントモードが終了する
4. キャンセルするには `ESC` を押す

### 検索モード

<!-- TODO: Add GIF demonstrating search mode -->

1. `Cmd+Shift+/` を押すと、画面下部に検索バーが表示される
2. 対象要素のテキストを入力して絞り込む
3. `Enter` で最初の候補をクリックする
4. キャンセルするには `ESC` を押す

### スクロールモード

<!-- TODO: Add GIF demonstrating scroll mode -->

1. `Cmd+Shift+J` を押してスクロールモードに入る
2. 以下のキーでスクロール操作を行う:
   - `j` — 下にスクロール
   - `k` — 上にスクロール
   - `d` — 半ページ下にスクロール
   - `u` — 半ページ上にスクロール
3. `ESC` でスクロールモードを終了する

---

## 必要環境

- macOS 14 (Sonoma) 以降
- Swift 6.0 以降（ソースからビルドする場合）

---

## インストール

### GitHub Releases からダウンロード（推奨）

1. [Releases ページ](https://github.com/kodakoda-koda/Vimursor/releases) から最新の `Vimursor.dmg` をダウンロードする
2. DMG を開いて `Vimursor.app` を `/Applications` フォルダにドラッグする
3. `Vimursor.app` を起動する（初回は Gatekeeper の警告が表示される場合あり）
   - 警告が表示されたら: 右クリック → 「開く」→ 「開く」を選択

### ソースからビルド

```bash
git clone https://github.com/kodakoda-koda/Vimursor.git
cd Vimursor

# .app バンドルを生成する
bash scripts/build-app.sh

# 起動
open Vimursor.app
```

### アクセシビリティ権限の設定

Vimursor はアクセシビリティ API を使用するため、初回起動時に権限の許可が必要です。

1. Vimursor を起動する（起動時にシステムダイアログが表示される）
2. 「システム設定」→「プライバシーとセキュリティ」→「アクセシビリティ」を開く
3. リストに `Vimursor` が表示されていることを確認し、トグルをオンにする

> 権限を付与しないとホットキーが反応しません。

---

## トラブルシューティング

### ホットキーが反応しない

アクセシビリティ権限が付与されているか確認してください。

1. 「システム設定」→「プライバシーとセキュリティ」→「アクセシビリティ」を開く
2. `Vimursor` にチェックが入っているか確認する
3. チェックが入っているのに動かない場合は、一度リストから削除して再追加する（下記参照）

### 権限を付与したのに動かない

権限の再登録で解決することがあります。

1. 「システム設定」→「プライバシーとセキュリティ」→「アクセシビリティ」を開く
2. リスト内の `Vimursor` の左の `-` ボタンで一度削除する
3. Vimursor を再起動すると再度ダイアログが表示されるので、再び許可する

### ラベルが表示されない

- 対象ウィンドウにフォーカス（キーボードフォーカス）があるか確認してください
- 一部のアプリ（Electron 系など）は Accessibility API 非対応のため、ラベルが表示されない場合があります

---

## 開発

```bash
swift build          # デバッグビルド
swift test           # テスト実行
```

詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

---

## ライセンス

[MIT License](LICENSE)
