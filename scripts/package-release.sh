#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/clipshot-release.XXXXXX")"
archive_path="$build_root/ClipShot.xcarchive"
export_path="$build_root/export"
output_path="$repo_root/dist/ClipShot.zip"
temporary_output="$build_root/ClipShot.zip"

trap 'rm -rf "$build_root"' EXIT
mkdir -p "$export_path" "$repo_root/dist"

xcodebuild \
  -project "$repo_root/ClipShot.xcodeproj" \
  -scheme ClipShot \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  archive

cp -R "$archive_path/Products/Applications/ClipShot.app" "$export_path/ClipShot.app"
ditto -c -k --sequesterRsrc --keepParent "$export_path/ClipShot.app" "$temporary_output"
mv -f "$temporary_output" "$output_path"

echo "Created $output_path"
