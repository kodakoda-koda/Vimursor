# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

macOSをキーボードのみで操作できるツール（Homerowの代替OSS）。
Swift + AppKit で実装。App Store非対応（Accessibility APIのためサンドボックス外配布）。

## Directory Structure

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

---

## Development Commands

```bash
swift build                        # デバッグビルド
swift build -c release             # リリースビルド
swift test                         # テスト実行
swift test --enable-code-coverage  # カバレッジ付きテスト
.build/debug/Vimursor              # 実行（初回はアクセシビリティ権限ダイアログが出る）
```

---

## Workflow Rules

> **Meta-rule**: ルールには理由（rationale）を記述する。推論モデルはルールを暗記するのではなく、各推論ステップで意図を再導出できると信頼性が上がる。

### Discussion First

実装を始める前に、要件と制約を完全に理解することを優先する。不明な点があれば質問してから着手する。

*Rationale: 途中で方向転換するコストは、事前の確認コストより常に高い。*

### Review Mode

非自明なロジック変更・設計上の意思決定・プロトコル変更に対しては「Review Mode」を開始する。
変更内容をテキストで提案し、アクション（ファイル変更・コマンド実行）は承認を得てから行う。
探索中に発見した関連する問題・不整合・改善機会も積極的に提案する。

*Rationale: 承認ゲートがあれば過剰な提案のコストは低く、見落としのコストは高い。*

### Git Protocol

ユーザーが明示的に「コミットして」「プッシュして」と指示するまで、`git commit` / `git push` を実行しない。
コミットを求められたら、その時点のファイルシステムの状態を真実とみなす。

*Rationale: 意図しないコミットは git history を汚染し、ロールバックが困難になる。*

### Meta Feedback

ユーザーが "meta:" プレフィクスでメッセージを送った場合、現在のタスクを即座に中断する。
ワークフロー改善の提案を `CLAUDE.md` または関連ルールファイルへの変更として Review Mode で提案し、承認後に適用する。
元のタスクはメタフィードバックの反映後に再開する。

*Rationale: ワークフロー改善の洞察は揮発性が高い。即座にキャプチャしなければ、そのコンテキストは次のセッションまでに失われる。*

### Development Workflow

**開発フローの詳細は `.claude/rules/common/git-workflow.md` を参照すること。**
Discussion → Plan → Develop → Code Review → Commit（Issue単位） → PR（Epic単位）の順で進める。
Issue管理・コミット/PR粒度のルールも同ファイルに記載。


