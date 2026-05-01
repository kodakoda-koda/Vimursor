# パフォーマンス診断レポート

日付: 2026-05-01

## 概要

各モードの起動・操作の所要時間を計測し、ボトルネックを特定して最適化を試みた。
計測は `PerfLog` ユーティリティによるタイムスタンプ出力と、AX API 呼び出しの統計情報で行った。

---

## 1. 初回計測（元コード）

### 計測環境

- 対象アプリ: Chrome（UI要素が多い画面）
- マシン: MacBook Air (Darwin 23.6.0)

### 全モード計測結果

| モード | 列挙時間 | activate total | 主なボトルネック |
|--------|---------|----------------|-----------------|
| ヒントモード | 374ms | 434ms | AX列挙 + buildUIElementInfos(58ms, main) |
| 検索モード | 364ms + 63ms(frame) | 479ms | AX列挙 + フレーム取得 |
| スクロールモード | 282ms | 283ms | AX列挙 |
| カーソルモード | — | 1.2ms | 問題なし |

### キー操作の計測結果

全モードで1ms未満。ボトルネックではない。

| 操作 | 時間 |
|------|------|
| ヒントモード filter + redraw | 0.08-0.16ms |
| 検索モード filter (163 items) | 0.5-0.7ms |
| スクロール j/k/d/u | 0.05-0.95ms |
| カーソル移動 (hjkl) | 0.35-0.39ms |

### 結論

**ボトルネックはほぼ全て AX API の IPC（プロセス間通信）**。
キー操作後のロジック（フィルタリング・描画）は全て1ms未満で問題なし。

---

## 2. 詳細診断（ヒントモード）

### AX API 呼び出しの内訳（元コード）

```
Total elements visited:       1530
Total IPC calls:              9741
Skipped by role:              154
Matched by clickable role:    353
Checked AXActionNames:        1023
```

要素あたり平均 6.4 IPC。AXActionNames の1023回呼び出しが最大のコスト。

### buildUIElementInfos の問題

```
Input elements:   290
Frame failed:     171  (59% が無駄)
Valid UIElements: 85
IPC calls (main): 290  (メインスレッドブロッキング)
```

290要素のフレームをメインスレッドで取得し、171個（59%）が失敗。無駄なIPCがメインスレッドをブロック。

---

## 3. 最適化テクニックの検討

### Web調査で収集したテクニック

| # | テクニック | 効果 | 実装コスト |
|---|-----------|------|-----------|
| A | `AXUIElementSetMessagingTimeout` | 最悪ケース防止 | 1行 |
| B | `collectClickable` のバッチ属性取得 | IPC 30%減 | 低 |
| C | `AXVisibleChildren` の利用 | 走査要素数削減 | 低〜中 |
| D | 画面外サブツリー枝刈り | 20-50%削減? | 中 |
| E | `buildUIElementInfos` のBG化 | メインスレッド解放 | 低 |
| F | プリフェッチ（アプリ切替時） | 体感ゼロ | 中 |
| G | AXObserverキャッシュ | 2回目以降ゼロ | 高 |

### 診断で効果なしと判明

| テクニック | 根拠 |
|-----------|------|
| **画面外枝刈り (D)** | Off-screen: 全モード0件。macOSのAXツリーは画面外要素を返さない |
| **AXHidden枝刈り** | Hidden: 全モード0件。非表示要素はツリーに含まれない |

---

## 4. 適用した最適化と効果

### 4-1. AXVisibleChildren 優先 (テクニック C)

`AXChildren` の代わりに `AXVisibleChildren`（利用可能な場合）を使い、不可視な子要素をスキップ。

**効果:**
- 走査要素数: 1530 → 1238 (-19%)
- Frame失敗: 171 → 0 (完全解消)
- buildUIElementInfos: 58ms → 10ms (-83%)

**理由:** AXVisibleChildren は画面上の要素のみ返すため、フレーム取得の失敗がなくなった。

### 4-2. バッチ属性取得 (テクニック B)

`isClickable` で AXRole と AXEnabled を個別に取得していたのを `AXUIElementCopyMultipleAttributeValues` で1回のIPCに統合。

**変更前:** ロール別に1〜3 IPC
```
skippable role:  AXRole(1) = 1 IPC
clickable role:  AXRole(1) + AXEnabled(1) = 2 IPC
unknown role:    AXRole(1) + AXEnabled(1) + AXActionNames(1) = 3 IPC
```

**変更後:** バッチで1〜2 IPC
```
skippable role:  バッチ(1) = 1 IPC
clickable role:  バッチ(1) = 1 IPC
unknown role:    バッチ(1) + AXActionNames(1) = 2 IPC
```

**効果:**
- IPC calls: 4623 → 3538 (-23%)
- 列挙時間: 390ms → 321ms (-18%)

### 4-3. clickableRoles 追加

診断データに基づき、AXPress を持つロールを clickableRoles に追加。
これにより AXActionNames の呼び出しを回避。

**追加ロール:** AXMenuBarItem, AXTextField, AXTextArea, AXMenuButton

### 4-4. フレーム事前フィルタ (テクニック E 部分)

`fetchClickableElements` 内でフレーム取得をバックグラウンドで実行し、フレーム取得不能な要素を事前に除外。

**効果:** buildUIElementInfos でのメインスレッドブロッキングを軽減。

### 4-5. スキップリスト拡張 → 撤回

診断で AXPress=0 だったロール（AXCell, AXGroup, AXColumn 等）をスキップリストに追加したが、
**Electron アプリ（Obsidian）で AXGroup が AXPress を持つケースが発覚**し、176要素が見逃された。

**結論:** アプリによって同じロールでも AXPress の有無が変わるため、スキップリストの拡張は危険。撤回。

---

## 5. 最終結果（ヒントモード）

### Chrome

| 指標 | 元コード | 最適化後 | 改善 |
|------|---------|---------|------|
| IPC calls | 9741 | 3526 | **-64%** |
| 列挙時間 | 374ms | 338ms | **-10%** |
| buildUIElementInfos | 58ms (main) | 18ms (main) | **-69%** |
| Frame 失敗 | 171/290 | 0/88 | **解消** |
| activate total | 434ms | 376ms | **-13%** |

### 全アプリ比較

| アプリ | activate total |
|--------|---------------|
| Chrome | 376ms |
| Obsidian | 270ms |
| Finder | 138ms |

### 残存するボトルネック

- **AXActionNames**: 996回呼び出し（Chrome）。`AXUIElementCopyActionNames` は `CopyMultipleAttributeValues` でバッチ化不可。スキップリスト拡張は Electron アプリとの互換性問題で断念。
- **buildUIElementInfos のメインスレッド IPC**: 18ms 残存。BGでフレーム事前フィルタ済みだが、`buildUIElementInfos` 自体がまだメインスレッドでフレームを再取得している（二重取得）。

---

## 6. 未診断（今後）

- 検索モードの最適化余地
- スクロールモードの最適化余地
- `AXUIElementSetMessagingTimeout` の効果
- プリフェッチの検討（ユーザー方針: 不採用）
