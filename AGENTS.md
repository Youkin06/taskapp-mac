# AGENTS.md

ClipShot は、スクリーンショットと画面収録を検知してクリップボードへコピーする macOS メニューバーアプリ（SwiftUI）です。

## 構成

- `TaskApp/TaskAppApp.swift`: アプリのエントリポイント（`MenuBarExtra`）
- `TaskApp/ContentView.swift`: メニューバーの UI と `CaptureMonitor`（監視・クリップボード・保存処理）
- `ClipShot.xcodeproj`: 使用するプロジェクト（スキーム `ClipShot`）。`TaskApp.xcodeproj` は古いもの
- `scripts/package-release.sh`: Release ビルドして `dist/ClipShot.zip` を作る
- バージョンは `ClipShot.xcodeproj/project.pbxproj` の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`

## クリップボードの仕組み（貼り付け先に合わせて切り替え）

「パスも一緒にコピー」がオンのとき、画像とパス文字列を両方クリップボードに入れると、LINE などのアプリが「テキスト／画像どちらで貼るか」のダイアログを出してしまう。これを避けるため、`CaptureMonitor` は手前のアプリに合わせてクリップボードを書き換える。

- ターミナル・コードエディタ（`pathPasteBundleIDs` に列挙）: 画像＋ファイル URL＋パス文字列（Claude Code はパスから画像を読む）
- それ以外のアプリ（LINE など）: 画像だけ（動画はファイル URL のみ）
- ClipShot 自身が手前のときは貼り付け先が不明なのでパス付きで書き、次のアプリが手前に来た時点（`NSWorkspace.didActivateApplicationNotification`）で書き直す
- クリップボードが ClipShot のコピー内容のまま（`changeCount` が一致）のときだけ書き換える。ユーザーが後から別のものをコピーしたら触らない
- パスを貼りたいアプリが増えたら `pathPasteBundleIDs` に Bundle ID を追加する（`osascript -e 'id of app "アプリ名"'` で調べられる）

## ルール: 変更したら必ず最新版を README から配布する

README のダウンロードリンクは GitHub Release の最新版（`releases/latest/download/ClipShot.zip`）を指しています。
アプリに何か変更を加えたら、作業の最後に必ず次を行い、README から最新版をダウンロードできる状態にしてください。

1. `MARKETING_VERSION` を上げ、`CURRENT_PROJECT_VERSION` を 1 増やす（直前のタグは `git tag` で確認）
2. README の「主な機能」「使い方」「注意」と English 版を、変更内容に合わせて更新する（日本語と英語の両方）
3. 配布用 zip を作り、コミットして、Release を作成する

```sh
./scripts/package-release.sh
git add -A
git commit -m "release: vX.Y.Z"
git push
gh release create vX.Y.Z dist/ClipShot.zip --title "ClipShot vX.Y.Z" --generate-notes
```

4. `gh release list -L 1` で新しいバージョンが `Latest` になったことを確認する
5. ユーザーの Mac にインストールされている ClipShot（`/Applications/ClipShot.app`）も新しいバージョンに入れ替えて起動し直す。メニュー左下のバージョン表示、または `Info.plist` の `CFBundleShortVersionString` で新しいバージョンになったことを確認する

```sh
APP_ID=$(defaults read /Applications/ClipShot.app/Contents/Info.plist CFBundleIdentifier)
osascript -e "quit app id \"$APP_ID\"" || pkill -f /Applications/ClipShot.app/Contents/MacOS/ClipShot
TMP=$(mktemp -d) && ditto -x -k dist/ClipShot.zip "$TMP"
rm -rf /Applications/ClipShot.app && ditto "$TMP/ClipShot.app" /Applications/ClipShot.app
open /Applications/ClipShot.app
defaults read /Applications/ClipShot.app/Contents/Info.plist CFBundleShortVersionString
```

ビルドが失敗した場合は Release を作らず、原因を報告してください。
