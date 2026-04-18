# ClaudeUsage Design

Design notes for a macOS app that displays Claude.ai usage (5-hour session / 7-day weekly / 7-day weekly Sonnet) as a menu bar popover and WidgetKit widget.

Inspired by [`reference-claudeusagebar/`](https://github.com/Artzainnn/claudeusagebar) (MIT).

---

## Architecture overview

- **Main app `ClaudeUsage`**: uses a session cookie to poll the Claude.ai API and writes results into App Group UserDefaults. Menu-bar resident. Hosts the sign-in UI.
- **Widget extension `ClaudeUsageWidget`**: reads from the App Group only; never touches the network.
- **App Group ID**: `group.com.serendipitynz.ClaudeUsage`

---

## API

### Authentication
- **Cookie-based**. The full HTTP `Cookie:` header string (e.g. `sessionKey=...; lastActiveOrg=...; anthropic-device-id=...`).
- If `lastActiveOrg=<UUID>` is present in the cookie it is used as the org ID; otherwise the `/api/bootstrap` fallback is used.

### Endpoints

**Org ID fallback**
```
GET https://claude.ai/api/bootstrap
Cookie: <full cookie>
→ json["account"]["lastActiveOrgId"]
```

**Usage (main)**
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

### Response shape
```json
{
  "five_hour":        { "utilization": <Double 0-100>, "resets_at": "<ISO8601 w/ fractional sec>" },
  "seven_day":        { "utilization": ..., "resets_at": ... },
  "seven_day_sonnet": { "utilization": ..., "resets_at": ... }
}
```
- `utilization` is a percentage 0–100.
- `resets_at` is ISO8601 with fractional seconds → `ISO8601DateFormatter` with `.withFractionalSeconds`.
- `seven_day_sonnet` is Pro-only and may be absent.

### Refresh interval
Every 5 minutes (300 seconds).

---

## Components

### Shared (`Shared/`)

**`UsageSnapshot`** — Codable struct persisted to the App Group.
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

**`SharedStore`** — App Group UserDefaults wrapper.
- `UserDefaults(suiteName: "group.com.serendipitynz.ClaudeUsage")`
- `saveSnapshot(_:)` / `loadSnapshot()` — JSON under `usage_snapshot_v1`
- `saveCookie(_:)` / `loadCookie()` / `clearCookie()` — stored at `claude_session_cookie`

### Main app (`ClaudeUsage/`)

**`ClaudeUsageAPI.swift`** — API client.
- `normalizeCookie(_:)` — accepts both the HTTP `Cookie:` header format and the DevTools Application → Cookies tab-separated paste, emitting the `a=b; c=d` form.
- `fetchOrganizationId(cookie:) async throws -> String`
- `fetchUsage(cookie:orgId:) async throws -> UsageSnapshot`

**`UsageManager.swift`** — `@MainActor ObservableObject` coordinator. Loads cookie → `fetchUsage` → `SharedStore.saveSnapshot` → `WidgetCenter.shared.reloadAllTimelines()`. 5-minute `Timer`. Immediate fetch on launch and on cookie update.

**`LoginWindowController.swift`** — hosts a `WKWebView` at `https://claude.ai/login` with a `.nonPersistent()` data store. Captures cookies into a pending header on every cookie-store and URL change. On window close, the most-recent header is sent to the main app. Capturing on close (rather than on first `sessionKey` appearance) lets Team users switch from their personal org to the Team org in-session before confirming.

**`AppDelegate.swift`** — menu bar status item (`.accessory`), popover host, 5-minute timer. The sign-in action presents the `LoginWindowController`.

**`UsageView.swift`** — SwiftUI popover. Three usage rows, Refresh button, `Sign in with Claude.ai` / `Sign out` buttons, and an "Advanced" disclosure group with a fallback manual cookie-paste field.

### Widget extension (`ClaudeUsageWidget/`)

- `StaticConfiguration` (no per-instance config).
- `UsageEntry { date; snapshot }` and `UsageProvider` reading `SharedStore.loadSnapshot()`. Timeline policy `.after(now + 5min)`.
- `systemSmall` — session % large; `systemMedium` — three bars.
- Bars are hand-rolled `Capsule`s with `.widgetAccentable()` on the fill, so accented rendering (desktop inactive state) preserves track/fill contrast.
- Color thresholds: 70 / 90 → green / amber / red.

---

## Sign-in flow (WebView)

1. User clicks **Sign in with Claude.ai** in the popover.
2. `LoginWindowController` opens a `WKWebView` (non-persistent store) at `https://claude.ai/login`.
3. User signs in. The window does not auto-close; if the account has multiple orgs (e.g., Team), the user can switch in claude.ai's UI first.
4. On every cookie change or URL change (KVO on `webView.url` catches SPA pushState navigation), the controller re-reads cookies and stashes a header candidate.
5. When the user closes the window, the latest captured header is saved to App Group and an immediate fetch is triggered.

The **Advanced: paste cookie manually** disclosure group is a fallback for accounts where the WebView flow breaks (e.g., Google SSO, which Google blocks in embedded WebViews).

---

## Out-of-scope (post-MVP)

- Threshold notifications (alerts at 90% usage, etc.)
- Global keyboard shortcut (Cmd+U or similar)
- `systemLarge` widget family
- Auto-refresh of expiring session cookies (when expired the user re-signs in)
- Background daemon mode (the main app must be running for data to stay fresh)
