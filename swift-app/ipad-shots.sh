#!/bin/zsh
# iPad listing screenshots, captured from the real app in the simulator.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
DEV=6E91FD59-B9B8-4D31-8E24-2E41081C5C4B     # iPad Pro
BUNDLE=com.intentmesh.confession1689
OUT="$DIR/store-screens-ipad"
mkdir -p "$OUT"
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Confession1689-*/Build/Products/Debug-iphonesimulator/Confession1689.app | head -1)

xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b >/dev/null
xcrun simctl status_bar "$DEV" override --time "9:41" --batteryLevel 100 --batteryState charged 2>/dev/null || true

fresh() {
  xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
  xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null || true
  for key in seedOverlay seedProof seedSearchQuery seedChapter seedCompanion pos theme bm nt; do
    xcrun simctl spawn "$DEV" defaults delete "$BUNDLE" "$key" 2>/dev/null || true
  done
  xcrun simctl install "$DEV" "$APP"
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" launched -bool true
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" theme -bool false
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedNoTips -bool true
}

capture() {
  xcrun simctl launch "$DEV" "$BUNDLE" >/dev/null
  sleep 8
  xcrun simctl io "$DEV" screenshot "$OUT/$1.png" >/dev/null
  xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
  echo "captured $1"
}

fresh
capture 01-library

fresh
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" pos c1p1
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedProof "c1p1|2 Timothy 3:15-17"
capture 02-proof

fresh
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" bm -array c1p1 c11p1 c17p1
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" nt -dict c11p1 "Justification is by faith alone, but not by a faith that is alone."
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" pos c11p1
capture 03-note

fresh
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedOverlay search
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedSearchQuery "effectual calling"
capture 04-search

fresh
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" theme -bool true
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" pos c1p1
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedProof "c1p1|2 Timothy 3:15-17"
capture 05-dark

xcrun simctl status_bar "$DEV" clear 2>/dev/null || true
for f in "$OUT"/*.png; do sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr '\n' ' '; echo "$(basename $f)"; done
