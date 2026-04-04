# Agent Orchestration

## Available Agents

Located in `.claude/agents/`:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| planner | Implementation planning | 新機能・リファクタリングの計画を GitHub Issue として作成するとき |
| architect | System design | モジュール設計・依存関係・処理フローを決定するとき |
| developer | Feature implementation | 計画に基づいて実際にコードを書くとき |
| tdd-guide | Test-driven development | 新関数・バグ修正でテストファーストを強制したいとき |
| code-reviewer | Code review | 実装後・コミット前に必ず実行 |
| refactor-cleaner | Dead code cleanup | 未使用コード・インポート整理のとき |

## Immediate Agent Usage

No user prompt needed:
1. Complex feature requests - Use **planner** agent
2. Feature implementation - Use **developer** agent
3. Code just written/modified - Use **code-reviewer** agent
4. Bug fix or new feature - Use **tdd-guide** agent
5. Architectural decision - Use **architect** agent

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
- `Bash(git *)` — git 操作
- `Bash(cat/ls/head/tail *)` — ファイル閲覧

破壊的コマンド（`rm`、`sudo` 等）は許可しない。

*Rationale: ビルド・テスト・ファイル閲覧は安全な操作であり自動承認することでエージェントの作業効率が上がる。破壊的コマンドは承認プロンプトで防御する。*
