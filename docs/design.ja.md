# ClaudeUsage 設計ドキュメント

Claude.ai の利用量 (5 時間セッション / 7 日週次 / 7 日週次 Sonnet) を macOS のメニューバー popover + WidgetKit ウィジェットで表示するアプリの設計ノート。

参考実装: [`reference-claudeusagebar/`](https://github.com/Artzainnn/claudeusagebar) (MIT)。

---

## アーキテクチャ概要

- **メインアプリ `ClaudeUsage`**: Cookie を使って Claude.ai API を定期ポーリングし、App Groups UserDefaults に結果を保存。メニューバー常駐、サインイン UI を提供
- **ウィジェット拡張 `ClaudeUsageWidget`**: App Groups から読むだけ。ネットワーク通信はしない
- **App Group ID**: `group.com.serendipitynz.ClaudeUsage`

---

## API 仕様 (参考実装を踏襲)

### 認証
- **Cookie ベース**。HTTP `Cookie:` ヘッダー文字列 (`sessionKey=...; lastActiveOrg=...; anthropic-device-id=...` など) をそのまま送信
- Cookie 文字列に `lastActiveOrg=<UUID>` があればそれを org ID として利用。無ければ `/api/bootstrap` にフォールバック

### エンドポイント

**Org ID フォールバック**
```
GET https://claude.ai/api/bootstrap
Cookie: <full cookie>
→ json["account"]["lastActiveOrgId"]
```

**使用量取得 (メイン)**
```
GET https://claude.ai/api/organizations/{orgId}/usage
Headers:
  Cookie: <full cookie>
  Accept: */*
  Content-Type: application/json
  Origin: https://claude.ai
  Referer: https://claude.ai
  User-Agent: Mozilla/5.0 ... Chrome/120 ...
  authority: claude.ai
```

### レスポンス
```json
{
  "five_hour":        { "utilization": <Double 0-100>, "resets_at": "<ISO8601 小数秒付き>" },
  "seven_day":        { "utilization": ..., "resets_at": ... },
  "seven_day_sonnet": { "utilization": ..., "resets_at": ... }
}
```
- `utilization` は 0-100 の割合 (%)
- `resets_at` は ISO8601 小数秒付き → `ISO8601DateFormatter` + `.withFractionalSeconds` で parse
- `seven_day_sonnet` は Pro プランのみ、存在しないことがある

### リフレッシュ間隔
5 分 (300 秒) ごと

---

## コンポーネント

### 共有 (`Shared/`)

**`UsageSnapshot`** — App Group に置く Codable 構造:
```swift
struct UsageSnapshot: Codable {
    var sessionUtilization: Double
    var sessionResetsAt: Date?
    var weeklyUtilization: Double
    var weeklyResetsAt: Date?
    var weeklySonnetUtilization: Double?
    var weeklySonnetResetsAt: Date?
    var fetchedAt: Date
    var errorMessage: String?
}
```

**`SharedStore`** — App Group UserDefaults のラッパー:
- `UserDefaults(suiteName: "group.com.serendipitynz.ClaudeUsage")`
- `saveSnapshot(_:)` / `loadSnapshot()` — `usage_snapshot_v1` に JSON で格納
- `saveCookie(_:)` / `loadCookie()` / `clearCookie()` — `claude_session_cookie` に保存

### メインアプリ (`ClaudeUsage/`)

**`ClaudeUsageAPI.swift`** — API クライアント:
- `normalizeCookie(_:)` — HTTP `Cookie:` ヘッダー形式と DevTools Application → Cookies のタブ区切りペーストの両方を受け付け、`a=b; c=d` 形式に正規化
- `fetchOrganizationId(cookie:) async throws -> String`
- `fetchUsage(cookie:orgId:) async throws -> UsageSnapshot`

**`UsageManager.swift`** — `@MainActor ObservableObject` のコーディネータ。Cookie 読み込み → `fetchUsage` → `SharedStore.saveSnapshot` → `WidgetCenter.shared.reloadAllTimelines()`。5 分 `Timer`。起動時と Cookie 更新時に即時 fetch。

**`LoginWindowController.swift`** — `WKWebView` を `https://claude.ai/login` で開くログインウィンドウ。`.nonPersistent()` データストアを使用。cookie / URL 変更のたびに header 候補を保持し、ユーザーがウィンドウを閉じたタイミングで最終確定。最初に `sessionKey` が出た瞬間ではなく「閉じた時点」で確定することで、Team アカウントユーザーは 個人 org → Team org への切り替え後に確定できる。

**`AppDelegate.swift`** — メニューバー `.accessory` 常駐、popover、5 分タイマー。サインインアクションは `LoginWindowController` を提示。

**`UsageView.swift`** — SwiftUI popover。3 つの usage 行、Refresh ボタン、`Sign in with Claude.ai` / `Sign out` ボタン、フォールバック用の手動 cookie ペーストフィールド (「Advanced」の disclosure)。

### ウィジェット拡張 (`ClaudeUsageWidget/`)

- `StaticConfiguration` (インスタンス別設定なし)
- `UsageEntry { date; snapshot }` と `UsageProvider` が `SharedStore.loadSnapshot()` を読む。Timeline ポリシーは `.after(now + 5min)`
- `systemSmall` はセッション % の大きな表示、`systemMedium` は 3 本バー
- バーは `Capsule` を手書きし fill に `.widgetAccentable()` — accented rendering でも track/fill のコントラストを維持
- 色しきい値: 70 / 90 → 緑 / 橙 / 赤

---

## サインインフロー (WebView)

1. ユーザーが popover の **Sign in with Claude.ai** を押下
2. `LoginWindowController` が `.nonPersistent()` データストアで `WKWebView` を `https://claude.ai/login` で開く
3. ユーザーがサインイン。ウィンドウは自動で閉じない — 複数 org (例: Team) がある場合、claude.ai UI で切り替えてから閉じる
4. cookie 変更 / URL 変更 (`webView.url` の KVO が SPA pushState も捕捉) のたびに cookie を再読み込みし header 候補を保持
5. ユーザーがウィンドウを閉じると、保持している最新 header が App Group に保存され、即時 fetch がトリガーされる

**Advanced: paste cookie manually** の disclosure group は、WebView フローが通らないケース (Google SSO は embedded WebView でブロックされる) のフォールバック。

---

## 範囲外 (MVP 以降)

- しきい値通知 (例: 90% 到達アラート)
- グローバルキーボードショートカット (Cmd+U 等)
- `systemLarge` ウィジェット
- 期限切れ cookie の自動再取得 (期限切れ時はユーザーが再サインイン)
- バックグラウンド常駐化 (データの鮮度維持にはアプリ起動が必要)
