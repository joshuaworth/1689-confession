#!/bin/zsh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
WDEV=1FA65808-23CD-4938-A3D9-D99BA5E8AF11
BUNDLE=com.intentmesh.confession1689.watchkitapp
OUT="$DIR/store-screens-watch"
mkdir -p "$OUT"
WAPP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Confession1689-*/Build/Products/Debug-watchsimulator/Confession1689Watch.app | head -1)
xcrun simctl boot "$WDEV" 2>/dev/null || true
xcrun simctl bootstatus "$WDEV" -b >/dev/null
xcrun simctl status_bar "$WDEV" override --time "9:41" 2>/dev/null || true
xcrun simctl terminate "$WDEV" "$BUNDLE" 2>/dev/null || true
xcrun simctl uninstall "$WDEV" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$WDEV" "$WAPP"
xcrun simctl launch "$WDEV" "$BUNDLE" >/dev/null
sleep 7
xcrun simctl io "$WDEV" screenshot "$OUT/w1-today.png" >/dev/null
echo "captured w1-today"
