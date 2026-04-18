# ClaudeUsage 実装計画

Claude.ai の利用量を macOS ウィジェット (WidgetKit) として表示するアプリの実装計画。
参考実装: `./reference-claudeusagebar/` (メニューバーアプリ)。

---

## 全体アーキテクチャ

- **メインアプリ (`ClaudeUsage`)**: Cookie を使って定期的に Claude.ai の API を叩き、App Groups の UserDefaults に結果を保存。メニューバーに常駐し、Cookie 設定 UI を提供。
- **ウィジェット拡張 (`ClaudeUsageWidget`)**: App Groups から読んで表示するだけ。自身では API を叩かない。
- **App Group ID**: `group.com.serendipitynz.ClaudeUsage`

---

## API 仕様 (参考実装から読み取った内容)

### 認証
- **Cookie ベース**。ユーザーが DevTools から手でコピーした full cookie 文字列 (`sessionKey=...; lastActiveOrg=...; anthropic-device-id=...` などを含む) を使う。
- Cookie 文字列に `lastActiveOrg=<UUID>` があればそれを org ID として利用。無ければ bootstrap API にフォールバック。

### エンドポイント

**Org ID フォールバック**
```
GET https://claude.ai/api/bootstrap
Cookie: sessionKey=<cookie>
→ json["account"]["lastActiveOrgId"]
```

**使用量取得 (メイン)**
```
GET https://claude.ai/api/organizations/{orgId}/usage
Headers:
  Cookie: <full cookie string>
  Accept: */*
  Content-Type: application/json
  Origin: https://claude.ai
  Referer: https://claude.ai
  User-Agent: Mozilla/5.0 ... Chrome/120 ...
  authority: claude.ai
```

### レスポンス構造
```json
{
  "five_hour":        { "utilization": <Double 0-100>, "resets_at": "<ISO8601 with fractional seconds>" },
  "seven_day":        { "utilization": ..., "resets_at": ... },
  "seven_day_sonnet": { "utilization": ..., "resets_at": ... }
}
```
- `utilization` は 0〜100 の割合 (%)。
- `resets_at` は ISO8601 小数秒付き → `ISO8601DateFormatter` with `.withFractionalSeconds`。
- `seven_day_sonnet` は Pro プランのみで、存在しないことがある。

### リフレッシュ間隔
5 分 (300 秒) ごと。

---

## 実装計画

### フェーズ 0: Xcode プロジェクト構成

1. **App Group 有効化** (両ターゲット)
   - `ClaudeUsage` と `ClaudeUsageWidget` の entitlements に `group.com.serendipitynz.ClaudeUsage` を追加。
2. **Network entitlement**
   - メインアプリに `com.apple.security.network.client = YES` を追加 (Sandbox 前提)。
3. **メニューバー常駐**
   - メインアプリの Info.plist に `LSUIElement = YES`、または起動時に `.accessory` アクティベーションポリシー。

### フェーズ 1: 共有レイヤー (`Shared/` を両ターゲットにメンバー追加)

**`Shared/UsageSnapshot.swift`** — App Group で読み書きする Codable 構造
```swift
struct UsageSnapshot: Codable {
    let sessionUtilization: Double
    let sessionResetsAt: Date?
    let weeklyUtilization: Double
    let weeklyResetsAt: Date?
    let weeklySonnetUtilization: Double?
    let weeklySonnetResetsAt: Date?
    let fetchedAt: Date
    let errorMessage: String?
}
```

**`Shared/SharedStore.swift`** — App Group UserDefaults のラッパー
- `UserDefaults(suiteName: "group.com.serendipitynz.ClaudeUsage")`
- `save(_: UsageSnapshot)` / `load() -> UsageSnapshot?`
- キー: `"usage_snapshot_v1"` に JSON エンコードで格納。
- Cookie も共有 UserDefaults に (`"claude_session_cookie"`)。

### フェーズ 2: メインアプリ (`ClaudeUsage/`)

**`ClaudeUsage/API/ClaudeUsageAPI.swift`** — 参考実装からロジックだけ切り出し
- `fetchOrganizationId(cookie:) async throws -> String`
- `fetchUsage(cookie:, orgId:) async throws -> UsageSnapshot`
- ヘッダー・JSON パース・ISO8601 処理は参考実装を踏襲。
- `URLSession` を async/await で書き直す。

**`ClaudeUsage/UsageManager.swift`** — コーディネータ
- Cookie 読み込み → `fetchUsage()` → `SharedStore.save(snapshot)` → `WidgetCenter.shared.reloadAllTimelines()`。
- 5 分ごとの `Timer`。起動時と Cookie 更新時に即時 fetch。

**`ClaudeUsage/AppDelegate.swift`** — メニューバー常駐
- 参考実装のアイコン/パーセンテージ表示をそのまま流用。
- ポップオーバーに Cookie 設定 UI (`PasteableTextField` / `CustomTextField`)。
- キーボードショートカット・通知は MVP では省略 (将来の拡張)。

**`ClaudeUsage/ClaudeUsageApp.swift`** — `@main` を `AppDelegate` ベースに置き換え
- テンプレートの `WindowGroup { ContentView() }` は不要。
- `@NSApplicationDelegateAdaptor` を使う。

### フェーズ 3: ウィジェット (`ClaudeUsageWidget/`)

**`ClaudeUsageWidget.swift` を書き換え**
- `AppIntentConfiguration` → `StaticConfiguration` に変更 (ユーザー設定不要)。
- `AppIntent.swift` / `ClaudeUsageWidgetControl.swift` は削除。
- `Provider`:
  - `placeholder` / `snapshot` は仮データ。
  - `timeline` は `SharedStore.load()` を読む → `Timeline([entry], policy: .after(now + 5min))`。
  - ウィジェットは自身では API を叩かない (Cookie 認証の負荷とバックグラウンド制約)。
- `Entry`:
  ```swift
  struct UsageEntry: TimelineEntry { let date: Date; let snapshot: UsageSnapshot? }
  ```
- サイズ対応: `.systemSmall` / `.systemMedium`。
  - small: セッション % を大きく。
  - medium: セッション / 週次 / 週次 Sonnet の 3 バー。
- 色分けは参考実装と同じ (70 / 90 しきい値で緑・橙・赤)。

### フェーズ 4: 動作確認

1. `xcodebuild` でビルド。
2. メインアプリを起動 → Cookie 貼り付け → Fetch 成功を確認。
3. App Group の保存確認: `/Users/ootani/Library/Group Containers/group.com.serendipitynz.ClaudeUsage/` を覗く。
4. 通知センター/デスクトップにウィジェットを配置して表示確認。

---

## 未確定/判断が必要な点

- **メインアプリ UI**: メニューバーのみで進める想定 (通常ウィンドウは出さない)。
- **通知/グローバルショートカット**: MVP では外し、後段で追加。
- **ウィジェットのサイズ**: `systemSmall` + `systemMedium` の 2 サイズで開始。

---

## MVP 範囲まとめ

- [x] API 仕様理解
- [ ] App Group / entitlements 設定
- [ ] Shared レイヤー (UsageSnapshot / SharedStore)
- [ ] API クライアント (ClaudeUsageAPI)
- [ ] UsageManager + 5 分タイマー + WidgetCenter reload
- [ ] メニューバー UI (Cookie 入力 + 現状表示)
- [ ] Widget (small / medium)
- [ ] 動作確認
