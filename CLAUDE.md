# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

A macOS app that shows Claude.ai usage in a menu bar popover and a WidgetKit widget.

- **Main app (`ClaudeUsage/`)**: polls the Claude.ai API every 5 minutes using a session cookie and shares results via App Groups. Menu bar resident (`.accessory`). Provides a WebView-based sign-in flow.
- **Widget extension (`ClaudeUsageWidget/`)**: reads only from the App Group; never calls the API itself.
- **App Group ID**: `group.com.serendipitynz.ClaudeUsage`
- **Shared UserDefaults keys**:
  - `usage_snapshot_v1` — `UsageSnapshot` encoded as JSON
  - `claude_session_cookie` — the full HTTP `Cookie:` header string

## Reference implementation

`reference-claudeusagebar/app/ClaudeUsageBar.swift` is the menu bar app this project was inspired by. API-level details (endpoints, headers, response shape) follow that implementation. See `docs/design.md`.

Key points:
- **Endpoint**: `GET https://claude.ai/api/organizations/{orgId}/usage`
- **Auth**: the HTTP `Cookie:` header string. Obtained either from the in-app WebView sign-in or pasted from DevTools.
- **orgId**: extracted from `lastActiveOrg=<UUID>` in the cookie; falls back to `/api/bootstrap` if absent.
- **Response**: `five_hour` / `seven_day` / `seven_day_sonnet` (optional) each with `utilization` (0-100) and `resets_at` (ISO8601 with fractional seconds).
- **Refresh**: every 5 minutes.

## Architecture rules

- The widget extension never hits the Claude.ai API (cookie-auth load and background-execution constraints). The main app fetches, calls `SharedStore.save`, then `WidgetCenter.shared.reloadAllTimelines()`.
- Cookies live in the App Group UserDefaults. Both targets read the same suite.
- Errors and empty data surface as `UsageSnapshot.errorMessage`, which the widget and popover branch on for display.

## Build

Xcode project (`ClaudeUsage.xcodeproj`). Build with `xcodebuild -scheme ClaudeUsage`. Both targets need the App Group entitlement `group.com.serendipitynz.ClaudeUsage`.

## Current status

MVP complete. Out-of-scope items are listed in `docs/design.md`.
