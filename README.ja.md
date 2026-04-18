# ClaudeUsage

[Claude.ai](https://claude.ai) の利用量を表示する macOS メニューバーアプリ + WidgetKit ウィジェット。

- **メニューバー**: 常駐ステータスアイコン (色分け: 緑 / 橙 / 赤) と popover で、現在の 5 時間セッション / 週次 / 週次 Sonnet の使用率を表示
- **ウィジェット**: `systemSmall` (セッション %) と `systemMedium` (セッション / 週次 / 週次 Sonnet の 3 本バー) をデスクトップや通知センターに配置可能

[English](README.md)

## セットアップ

1. `ClaudeUsage.xcodeproj` を Xcode で開いて Run、または `xcodebuild -scheme ClaudeUsage build`
2. アプリを起動 — メニューバーにスパークアイコンが表示される
3. メニューバーアイコン → **Sign in with Claude.ai** を押す。claude.ai/login を開くウェブビューウィンドウが開く
4. メールまたは passkey でサインイン (Google SSO は Google 側が embedded WebView をブロックするため不可。メール/passkey を使うか、後述のフォールバックを使用)
5. **複数 org のあるアカウント (Claude Team 等) の場合**、追跡したい組織に claude.ai の UI 上で切り替えておく
6. ウェブビューのウィンドウを閉じる。閉じた時点で有効な cookie を保存し、即 fetch される
7. デスクトップ右クリック → **ウィジェットを編集** → **Claude Usage** を追加

メインアプリは 5 分ごとにポーリング。ウィジェットは共有 snapshot を読むだけなので、**メインアプリが起動していないと値は古いまま** になります。

### フォールバック: cookie の手動ペースト

popover の **Advanced: paste cookie manually** の開閉セクションから、サインインフローの代わりに cookie 文字列を直接貼れます (WebView フローが通らない、Google SSO しか使えない等のケース用)。両形式受け付け:
- `Cookie:` リクエストヘッダー値 (DevTools → Network → 任意の `/api/...` リクエスト → Request Headers からコピー)
- DevTools **Application → Cookies** テーブルの貼り付け (タブ区切りの全行選択)

## アーキテクチャ

- **メインアプリ (`ClaudeUsage/`)**: Claude.ai をポーリング、App Group `group.com.serendipitynz.ClaudeUsage` に書き込み、fetch ごとに `WidgetCenter.reloadAllTimelines()` を呼ぶ
- **ウィジェット拡張 (`ClaudeUsageWidget/`)**: App Group の snapshot を読むだけ。ネットワークアクセスなし
- **共有レイヤー (`Shared/`)**: `UsageSnapshot` + `SharedStore`

詳細は [CLAUDE.ja.md](CLAUDE.ja.md) と [docs/design.ja.md](docs/design.ja.md) 参照。

## クレジット

[ClaudeUsageBar](https://github.com/Artzainnn/claudeusagebar) (MIT) に着想。Claude.ai API クライアントとメニューバーアイコンのデザインは同プロジェクトから派生。ウィジェット拡張、App Group の仕組み、WebView サインイン、async/await アーキテクチャは新規。

## ライセンス

[MIT](LICENSE)
