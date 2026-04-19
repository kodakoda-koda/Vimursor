# Git Workflow

## Commit Message Format

```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

Note: Attribution disabled globally via ~/.claude/settings.json.

## Feature Implementation Workflow

1. **Discussion** — 要件・制約を議論し合意する
   - 不明な点があれば質問してから着手する
   - 非自明な設計判断は Review Mode で提案→承認を経る

2. **Plan** — **planner** エージェントで計画を作成
   - GitHub Issue として登録（Epic: `[Epic N]`、Task: `[N-M]`）
   - 依存関係・リスクを特定し、Phase に分解する

3. **Develop** — **developer** エージェントで TDD 実装
   - テストファースト（RED → GREEN → REFACTOR）
   - カバレッジ 80%+ を維持

4. **Code Review** — **code-reviewer** エージェントでレビュー
   - CRITICAL / HIGH の指摘は修正必須
   - MEDIUM は可能な限り対応

5. **Commit** — ユーザーの指示で実行
   - ユーザーが明示的に指示するまで `git commit` しない
   - Conventional Commits 形式
   - `Closes #XX` はコミットメッセージには書かない（squash merge で消えるため）

6. **Task Close** — 実装完了時に Issue を更新
   - Close 前に該当 Issue へコメントで実装内容（設計判断・変更ファイル・注意点等）を記録する
   - Issue のクローズは PR body の `Closes` キーワードで自動化する（後述）

7. **Pull Request** — Epic 単位で PR を作成
   - ユーザーが明示的に指示するまで実行しない
   - PR body に `Epic: #N` で親 Epic を参照
   - PR body に `Closes #51, Closes #52, ...` で対象タスク Issue を列挙する（自動クローズ用）
   - Epic Issue 自体も `Closes #50` のように含める
   - 全コミット履歴（`git diff [base-branch]...HEAD`）を分析して PR サマリーを作成
   - テストプランを含める
   - マージ先は `develop`（`release/**` → `main` の場合を除く）
   - マージは常に **squash merge** で行う（ユーザーが手動で実行）

## Branch Naming

```
feature/epic<N>-<short-description>   # 機能開発（例: feature/epic6-appearance）
fix/<short-description>               # バグ修正（例: fix/hint-label-overlap）
docs/<short-description>              # ドキュメント
release/v<version>                    # リリース（→ main）
```

ブランチは `develop` から切る。詳細は `CONTRIBUTING.md` を参照。

## Issue Management

実装計画・タスクは GitHub Issue で管理する。

- **Epic**（機能グループ）: `[Epic N]` 形式のタイトル、`epic` ラベル
- **Task**（個別実装）: `[N-M]` 形式のタイトル、`task` ラベル
- **Memo**（技術的知見・調査記録等）: `memo` ラベル
- Issue テンプレートは `.github/ISSUE_TEMPLATE/` を使用
- **方針の記録**: タスクの方針が決まった時・変更した時は、該当 Issue のコメントに随時記載する
