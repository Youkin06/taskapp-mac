# AGENTS.md

ClipShot は、スクリーンショットと画面収録を検知してクリップボードへコピーする macOS メニューバーアプリ（SwiftUI）です。

## 構成

- `TaskApp/TaskAppApp.swift`: アプリのエントリポイント（`MenuBarExtra`）
- `TaskApp/ContentView.swift`: メニューバーの UI と `CaptureMonitor`（監視・クリップボード・保存処理）
- `ClipShot.xcodeproj`: 使用するプロジェクト（スキーム `ClipShot`）。`TaskApp.xcodeproj` は古いもの
- `scripts/package-release.sh`: Release ビルドして `dist/ClipShot.zip` を作る
- バージョンは `ClipShot.xcodeproj/project.pbxproj` の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`

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

ビルドが失敗した場合は Release を作らず、原因を報告してください。
