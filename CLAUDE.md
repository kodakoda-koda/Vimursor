# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

macOSをキーボードのみで操作できるツール（Homerowの代替OSS）。
Swift + AppKit で実装。App Store非対応（Accessibility APIのためサンドボックス外配布）。
実装計画: `docs/plans/vimursor_implementation.md`

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

### Documentation Policy

`docs/` 以下のドキュメントは人間とエージェント両方のためのものとして書く。
- 正確なコマンド・パス・パラメータを省略しない
- 非自明な手順には理由を添える
- エージェントはセッションをまたいで記憶を持たないため、「読めばわかる」ドキュメントを目指す

複数セッションにまたがる実装計画は `docs/plans/` に保存する（1セッションで完結する計画は一時領域でよい）。

### Context Management

**メインセッションのコンテキストを節約するための必須ルール。**

#### 実装はサブエージェントに委譲する（CRITICAL）

メインセッションでコードを書かない。実装・修正・テスト実行はすべてサブエージェントに委譲する。

| 作業 | 使うエージェント |
|------|----------------|
| 新機能・モジュール実装 | **developer** |
| バグ修正・TDD | **tdd-guide** |
| コードレビュー | **code-reviewer**（developer内部で自動実行） |
| 計画立案 | **planner** |

*Rationale: メインセッションで実装するとコード・テスト出力・レビュー全体がコンテキストを圧迫し、セッションが短命になる。*

#### 実装エージェントはバックグラウンド起動

**developer** / **tdd-guide** / **code-reviewer** は `run_in_background: true` で起動する。
完了確認は出力ファイルの末尾50行程度のみ読む（`tail -n 50 <output_file>`）。

**例外:** `swift package init` など環境構築系タスクはフォアグラウンドで完了させてからエージェントを起動する。

*Rationale: フォアグラウンド実行だとエージェントの全出力がメインコンテキストに流入する。バックグラウンドならサマリーのみ受け取れる。環境が未構築のままバックグラウンドエージェントを起動すると即座に失敗する。*

#### バックグラウンドエージェントのプロンプトに必須の情報

バックグラウンドエージェントは会話履歴を持たないため、プロンプトに以下を必ず含める:

- **ワーキングディレクトリ**: `/Users/souheikodama/Desktop/repos/Vimursor`
- **対象ファイルの絶対パス**: 作成・修正するファイルを明示
- **参照ファイルのパス**: 読むべき既存コード・プランファイル
- **実行コマンド**: `swift build` / `swift test` 等
- **完了条件**: 何が通れば成功か

*Rationale: コンテキスト不足のエージェントは手探りになり失敗率が上がる。プロンプトが自己完結していれば成功率が大幅に上がる。*

#### メインセッションでのファイル読み込みを最小化

- ファイルを読む際は必要箇所のみ（`offset` + `limit` を活用）
- エージェントから返ってくるのは「完了サマリー」だけで十分。コードスニペットをメインに貼らない

