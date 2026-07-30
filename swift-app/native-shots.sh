#!/bin/zsh
# Listing screenshots from the native app on the iPhone 17 Pro Max simulator.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
DEV=7FA18797-ADE1-4BCF-A120-BD1387241541
BUNDLE=com.intentmesh.confession1689
OUT="$DIR/store-screens-native"
mkdir -p "$OUT"

cd "$DIR"
xcodebuild -project Confession1689.xcodeproj -scheme Confession1689 \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO -quiet >/dev/null
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Confession1689-*/Build/Products/Debug-iphonesimulator/Confession1689.app | head -1)

xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b >/dev/null
xcrun simctl status_bar "$DEV" override --time "9:41" --batteryLevel 100 --batteryState charged --cellularBars 4 2>/dev/null || true

seed_common() {
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" theme -bool false
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedNoTips -bool true
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" bm -array c1p1 c11p1 c17p1
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" nt -dict c11p1 "Justification is by faith alone, but not by a faith that is alone. See paragraph 2."
}

capture() {  # $1 = name; preceding seeds already applied
  xcrun simctl launch "$DEV" "$BUNDLE" >/dev/null
  sleep 6
  xcrun simctl io "$DEV" screenshot "$OUT/$1.png" >/dev/null
  xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
  echo "captured $1"
}

fresh() {
  xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
  xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null || true
  for key in seedOverlay seedProof seedSearchQuery pos theme bm nt; do
    xcrun simctl spawn "$DEV" defaults delete "$BUNDLE" "$key" 2>/dev/null || true
  done
  xcrun simctl install "$DEV" "$APP"
}

# 1. Hero (light)
fresh
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" theme -bool false
  xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedNoTips -bool true
capture 01-hero

# 2. Proof open at Chapter I ¶ 1 (light)
fresh; seed_common
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" pos c1p1
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedProof "c1p1|2 Timothy 3:15-17"
capture 02-proof

# 3. Search with live results
fresh; seed_common
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedOverlay search
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedSearchQuery "effectual calling"
capture 03-search

# 4. Note scholium at Chapter XI (light)
fresh; seed_common
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" pos c11p1
capture 04-note

# 5. Contents sheet with bookmarks
fresh; seed_common
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedOverlay contents
capture 05-bookmarks

# 6. Candlelight with proof open
fresh; seed_common
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" theme -bool true
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" pos c1p1
xcrun simctl spawn "$DEV" defaults write "$BUNDLE" seedProof "c1p1|2 Timothy 3:15-17"
capture 06-dark

xcrun simctl status_bar "$DEV" clear 2>/dev/null || true
for f in "$OUT"/*.png; do sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr '\n' ' '; echo "$f"; done
