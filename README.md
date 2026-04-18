# ClaudeUsage

macOS WidgetKit widget and menu bar app that shows your [Claude.ai](https://claude.ai) usage.

- **Menu bar**: Always-on status icon (color-coded: green / yellow / red) with a popover for details and cookie setup.
- **Widget**: `systemSmall` (session %) and `systemMedium` (session / weekly / weekly Sonnet bars) for the desktop and Notification Center.

## Setup

1. Build in Xcode (`xcodebuild -scheme ClaudeUsage`), or open `ClaudeUsage.xcodeproj` and Run.
2. Launch the app — a spark icon appears in the menu bar.
3. Grab your Claude.ai session cookie:
   - Open DevTools on [claude.ai](https://claude.ai) → **Network** tab → reload → click the `usage` request → copy the `Cookie:` request header value.
   - *Or*: DevTools → **Application** → **Cookies** → `https://claude.ai` → select all rows → copy. Both formats are accepted.
4. Click the menu bar icon → **Set Session Cookie** → paste → **Save & Fetch**.
5. Right-click the desktop → **Edit Widgets** → add **Claude Usage**.

The main app polls every 5 minutes. The widget only reads the shared snapshot — **the main app must be running** for values to stay fresh.

## Architecture

- Main app (`ClaudeUsage/`) — polls Claude.ai, writes to an App Group (`group.com.serendipitynz.ClaudeUsage`), calls `WidgetCenter.reloadAllTimelines()`.
- Widget extension (`ClaudeUsageWidget/`) — reads the App Group snapshot only; no network access.
- Shared layer (`Shared/`) — `UsageSnapshot` + `SharedStore`.

See [CLAUDE.md](CLAUDE.md) and [plan.md](plan.md) for design details.

## Credits

Inspired by [ClaudeUsageBar](https://github.com/Artzainnn/claudeusagebar) (MIT). The Claude.ai API client and menu bar icon design are adapted from it; the widget extension, App Group plumbing, and async/await architecture are new.

## License

[MIT](LICENSE).
