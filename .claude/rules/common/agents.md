# Agent Orchestration

## Available Agents

Located in `.claude/agents/`:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| planner | Planning & architecture | 新機能・リファクタリングの計画、モジュール設計・依存関係・処理フローを決定するとき |
| developer | Feature implementation (TDD) | 計画に基づいて実際にコードを書くとき（テストファースト含む） |
| code-reviewer | Code review & dead code detection | 実装後・コミット前に必ず実行 |

## Immediate Agent Usage

No user prompt needed:
1. Complex feature requests / architectural decisions - Use **planner** agent
2. Feature implementation / bug fix - Use **developer** agent
3. Code just written/modified - Use **code-reviewer** agent

## Parallel Task Execution

独立した作業は並列でエージェントを起動する。

## Agent Prompt Requirements

サブエージェントはメインセッションの会話履歴を持たない。プロンプトに以下を必ず含める：

- **ワーキングディレクトリ**: `/Users/souheikodama/Desktop/repos/Vimursor`
- **対象ファイルの絶対パス**: 作成・修正するファイルを明示
- **参照ファイルのパス**: 読むべき既存コード、または Issue 番号
- **完了条件**: 何が通れば成功か

*Rationale: コンテキストが不足したエージェントは手探りになり失敗率が上がる。プロンプトが自己完結していれば成功率が大幅に上がる。*

## Tool Permissions

`permissions.allow`（`.claude/settings.json` および `~/.claude/settings.json`）で以下を自動承認済み：

- `Read` / `Write` / `Edit` / `Glob` / `Grep`
- `Bash(swift build*)` / `Bash(swift test*)` — ビルド・テスト
- `Bash(git status*)` / `Bash(git diff*)` / `Bash(git log*)` — git 読み取り

git の書き込み操作（commit, push, reset 等）および破壊的コマンド（`rm`、`sudo` 等）はメインセッションでのみ実行する。

*Rationale: サブエージェントには読み取り系のみ許可し、リポジトリ状態の変更はメインセッションが責任を持つ。*
