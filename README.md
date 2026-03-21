# Vimursor

macOS をキーボードのみで操作するためのツールです。[Homerow](https://www.homerow.app/) のオープンソース代替を目指しています。

Accessibility API を使用するため、App Store 非対応です（サンドボックス外配布）。

## 機能

| ショートカット | 機能 |
|--------------|------|
| `Cmd+Shift+Space` | **ヒントモード** — 画面上のクリック可能な要素にラベルを表示し、キー入力でクリック |
| `Cmd+Shift+/` | **検索モード** — テキスト入力で要素を絞り込み、Enter でクリック |
| `Cmd+Shift+J` | **スクロールモード** — キーボードでスクロール操作 |

## 必要環境

- macOS 14 (Sonoma) 以降
- Swift 6.0 以降（ビルドする場合）

## インストール

### ソースからビルド

```bash
git clone https://github.com/kodakoda-koda/Vimursor.git
cd Vimursor
swift build -c release
```

### アクセシビリティ権限の設定

Vimursor はアクセシビリティ API を使用するため、初回起動時に権限の許可が必要です。

1. ビルドしたバイナリを実行する
   ```bash
   .build/release/Vimursor
   ```
2. 「システム設定」→「プライバシーとセキュリティ」→「アクセシビリティ」を開く
3. Vimursor（またはターミナル）を許可する

権限が付与されていない場合、ホットキーが反応しません。

## 開発

```bash
swift build          # デバッグビルド
swift test           # テスト実行
```

詳細は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

[MIT License](LICENSE)
