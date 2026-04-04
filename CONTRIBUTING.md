# Contributing to Vimursor

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

## ブランチ運用

```
main           ── リリース済みの安定版
  └─ develop   ── 開発統合ブランチ
       ├─ feature/<name>  ── 機能単位の作業ブランチ
       ├─ fix/<name>      ── バグ修正ブランチ
       └─ docs/<name>     ── ドキュメントブランチ
```

### 通常の開発フロー（feature → develop）

```bash
# 1. develop から作業ブランチを切る
git checkout develop
git checkout -b feature/my-feature

# 2. 実装・コミット
git commit -m "feat: Add my feature"

# 3. develop へ PR を出す
git push -u origin feature/my-feature
# GitHub で PR を作成 → レビュー → マージ
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
# GitHub で PR を作成 → 確認 → マージ

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

## 開発環境セットアップ

```bash
git clone https://github.com/kodakoda-koda/Vimursor.git
cd Vimursor
git checkout develop
swift build
```

アクセシビリティ権限の設定は [README.md](README.md) を参照してください。

## テスト

```bash
swift test                         # テスト実行
swift test --enable-code-coverage  # カバレッジ付き
```

カバレッジ 80% 以上を目標としています。

## PR のガイドライン

- `feature/**` / `fix/**` / `docs/**` → `develop` へ PR
- `release/**` → `main` へ PR
- PR タイトルはコミットメッセージと同じ形式で
- `.github/pull_request_template.md` に従って記述してください
