# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project

Claude.ai の利用量を macOS ウィジェット (WidgetKit) として表示するアプリ。

- **メインアプリ (`ClaudeUsage/`)**: Cookie を使って Claude.ai API を定期ポーリングし、App Groups 経由でデータを共有。メニューバー常駐 (`LSUIElement` / `.accessory`)。
- **ウィジェット拡張 (`ClaudeUsageWidget/`)**: App Groups から読むだけ。自身で API を叩かない。
- **App Group ID**: `group.com.serendipitynz.ClaudeUsage`
- **Shared UserDefaults キー**:
  - `usage_snapshot_v1` — `UsageSnapshot` を JSON エンコードして保存
  - `claude_session_cookie` — full cookie string

## Reference implementation

`reference-claudeusagebar/app/ClaudeUsageBar.swift` は元になったメニューバーアプリ。
API 呼び出し (エンドポイント・ヘッダー・レスポンス形) はこれを踏襲する。
詳細は `plan.md` 参照。

主要ポイント:
- **Endpoint**: `GET https://claude.ai/api/organizations/{orgId}/usage`
- **Auth**: ユーザーが DevTools でコピーした full cookie 文字列をそのまま `Cookie:` ヘッダーに載せる
- **orgId**: cookie 内 `lastActiveOrg=<UUID>` から取る (無ければ `/api/bootstrap` にフォールバック)
- **Response**: `five_hour` / `seven_day` / `seven_day_sonnet`(任意) の各 `utilization` (0-100) と `resets_at` (ISO8601 小数秒)
- **Refresh**: 5 分ごと

## Architecture rules

- ウィジェット側からは絶対に API を呼ばない (Cookie 認証の負荷とバックグラウンド制約のため)。メインアプリが fetch → `SharedStore.save` → `WidgetCenter.shared.reloadAllTimelines()`。
- Cookie は App Group UserDefaults に置く。ウィジェットもメインアプリも同じ suite を見る。
- エラーや空データは `UsageSnapshot.errorMessage` に載せて共有し、ウィジェット側で表示分岐。

## Build

Xcode プロジェクト (`ClaudeUsage.xcodeproj`)。`xcodebuild -scheme ClaudeUsage` でビルド。
初回セットアップ時は両ターゲットに App Group entitlement を追加すること。

## Current status

`plan.md` のチェックリストで進捗を管理。MVP では通知 / グローバルショートカット (Cmd+U) は実装せず、参考実装からは省略する。
