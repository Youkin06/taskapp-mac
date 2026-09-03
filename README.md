# ClipShot

ClipShot is a small macOS menu bar app that watches for screenshots and screen recordings, copies them to the clipboard, and keeps them out of the way.

## 日本語

### [macOS アプリをここからダウンロード！](https://raw.githubusercontent.com/Youkin06/taskapp-mac/main/dist/ClipShot.zip)

ClipShot は、スクリーンショットや画面収録を検知して、自動でクリップボードへコピーする macOS メニューバーアプリです。通常のウィンドウや Dock アイコンを出さず、画面上部のメニューバーから操作できます。

### 主な機能

- スクリーンショットを自動でクリップボードにコピー
- 画面収録ファイルを一時保存してクリップボードにコピー
- メニューバーから最近のキャプチャを確認
- 複数のキャプチャを選択してまとめてコピー
- コピー、デスクトップへ保存、一覧から削除
- Dock に常駐せず、作業の邪魔になりにくい

### 使い方

1. 上の「ここからダウンロード！」から `ClipShot.zip` をダウンロードします。
2. zip を展開します。
3. `ClipShot.app` を `Applications` フォルダへ移動します。
4. `ClipShot.app` を開きます。
5. スクリーンショットを撮ると、自動でクリップボードにコピーされます。
6. メニューバーの一覧でサムネイル左上の丸をクリックすると、複数のキャプチャを選択してまとめてコピーできます。

### ログイン時に自動起動する

`システム設定 > 一般 > ログイン項目と機能拡張` を開き、`ログイン時に開く` に `ClipShot.app` を追加してください。

### 注意

ClipShot は、スクリーンショットや画面収録を処理したあと、元の保存場所から元ファイルを削除します。必要なものはメニューバーの一覧からデスクトップへ保存してください。

この配布版は個人開発用の署名です。macOS の設定によっては、初回起動時に確認が表示される場合があります。

### 配布版を更新する

```sh
./scripts/package-release.sh
git add dist/ClipShot.zip
git commit -m "chore: update ClipShot download"
git push
```

README のダウンロードリンクは `main` ブランチの `dist/ClipShot.zip` を参照しているため、リンクの書き換えは不要です。

## English

### [Download the macOS app here](https://raw.githubusercontent.com/Youkin06/taskapp-mac/main/dist/ClipShot.zip)

ClipShot is a macOS menu bar app that detects screenshots and screen recordings, copies them to the clipboard automatically, and stays out of your workspace. It runs from the menu bar without showing a normal app window or Dock icon.

### Features

- Automatically copies screenshots to the clipboard
- Temporarily stages screen recordings and copies them to the clipboard
- Shows recent captures from the menu bar
- Selects multiple captures and copies them together
- Copy, save to Desktop, or remove captures
- Runs quietly without a Dock icon

### How to Use

1. Download `ClipShot.zip` from the link above.
2. Unzip it.
3. Move `ClipShot.app` to the `Applications` folder.
4. Open `ClipShot.app`.
5. Take a screenshot, and ClipShot will copy it to the clipboard automatically.
6. In the menu bar list, click the circle on a thumbnail to select multiple captures and copy them together.

### Launch at Login

Open `System Settings > General > Login Items & Extensions`, then add `ClipShot.app` to `Open at Login`.

### Notes

After ClipShot processes a screenshot or screen recording, it removes the original file from its saved location. Use the menu bar list to save anything you want to keep to the Desktop.

This build is signed for personal development use. Depending on your macOS security settings, you may see a confirmation prompt the first time you open it.

### Updating the Distribution Build

Run `./scripts/package-release.sh`, then commit and push `dist/ClipShot.zip`. The README download link always points to that file on the `main` branch, so the link itself does not need to change.
