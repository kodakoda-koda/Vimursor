# Agent Orchestration

## Available Agents

Located in `~/.claude/agents/`:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| planner | Implementation planning | 新機能・リファクタリングの計画を `docs/plans/` に作成するとき |
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

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth module
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utilities

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Background Execution (Context Preservation)

実装系エージェントは必ず `run_in_background: true` で起動する：

| Agent | Background | Rationale |
|-------|-----------|-----------|
| developer | **YES** | 実装コード・テスト出力がメインコンテキストを圧迫するため |
| tdd-guide | **YES** | 同上 |
| code-reviewer | **YES** | レビューレポートが長大になるため |
| planner | NO | 計画書はメインセッションで承認が必要なため |
| architect | NO | 設計判断はユーザー確認が必要なため |

起動後の確認方法：

```bash
# 出力ファイルの末尾のみ読む（Bash tool）
tail -n 50 <output_file>
```

完全な出力が必要な場合のみ `Read` tool で出力ファイルを開く。

## Multi-Perspective Analysis

For complex problems, use split role sub-agents:
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker
