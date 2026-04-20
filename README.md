# ClaudeUsage

macOS menu bar app and WidgetKit widget that shows your [Claude.ai](https://claude.ai) usage.

- **Menu bar**: always-on status icon (color-coded: green / amber / red) with a popover showing the current five-hour session, weekly, and weekly-Sonnet utilization.
- **Widget**: `systemSmall` (session %) and `systemMedium` (session / weekly / weekly Sonnet bars) on the desktop or in Notification Center.

[日本語版](README.ja.md)

## Setup

1. Open `ClaudeUsage.xcodeproj` in Xcode and Run, or `xcodebuild -scheme ClaudeUsage build`.
2. Launch the app — a spark icon appears in the menu bar.
3. Click the menu bar icon → **Sign in with Claude.ai**. A web-view window opens on claude.ai/login.
4. Sign in via email or passkey. (Google SSO is blocked by Google in embedded web views — use email/passkey, or see the fallback below.)
5. **If your account has multiple organizations (e.g., a Claude Team membership)**, switch to the organization you want to track in claude.ai's UI first.
6. Close the web-view window. The app saves the cookies that were active at close and fetches your usage.
7. Right-click the desktop → **Edit Widgets** → add **Claude Usage**.

The main app polls every 5 minutes. The widget just reads the shared snapshot — **the main app must be running** for the widget to stay current.

### Fallback: manual cookie paste

The popover has an **Advanced: paste cookie manually** disclosure group for pasting a cookie string directly when the WebView flow doesn't work (e.g., Google-SSO-only accounts). Both formats are accepted:
- The `Cookie:` request-header value (DevTools → Network → any `/api/...` request → Request Headers).
- The DevTools **Application → Cookies** table paste (tab-separated rows, all rows selected).

### Widget missing from the gallery

If the Claude Usage widget doesn't appear in the widget gallery after launching the app:

1. Open **System Settings → General → Login Items & Extensions → Widgets** and make sure **ClaudeUsage** is turned on.
2. If it still doesn't show, run the following in Terminal and re-open the widget gallery:
   ```sh
   pluginkit -e use -i com.serendipitynz.ClaudeUsage.ClaudeUsageWidget
   killall chronod
   ```

## Architecture

- **Main app (`ClaudeUsage/`)**: polls Claude.ai, writes to the App Group `group.com.serendipitynz.ClaudeUsage`, calls `WidgetCenter.reloadAllTimelines()` after each fetch.
- **Widget extension (`ClaudeUsageWidget/`)**: reads the App Group snapshot only; no network access.
- **Shared layer (`Shared/`)**: `UsageSnapshot` + `SharedStore`.

See [CLAUDE.md](CLAUDE.md) and [docs/design.md](docs/design.md) for more.

## Credits

Inspired by [ClaudeUsageBar](https://github.com/Artzainnn/claudeusagebar) (MIT). The Claude.ai API client and menu bar icon design are adapted from it; the widget extension, App Group plumbing, WebView sign-in, and async/await architecture are new.

## License

[MIT](LICENSE).
