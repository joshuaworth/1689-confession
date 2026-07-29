#!/bin/zsh
# Listing screenshots captured from the real app in the iPhone 17 Pro Max simulator.
# Injects a per-state demo driver into the app's local www copy only (never the site).
set -e
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DEV=7FA18797-ADE1-4BCF-A120-BD1387241541
OUT="$APP_DIR/store-screens-sim"
APP_PRODUCT=$(ls -d ~/Library/Developer/Xcode/DerivedData/App-*/Build/Products/Debug-iphonesimulator/App.app | while read d; do
  [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$d/Info.plist" 2>/dev/null)" = "com.intentmesh.confession1689" ] && echo "$d"; done | head -1)
mkdir -p "$OUT"

xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b >/dev/null
xcrun simctl status_bar "$DEV" override --time "9:41" --batteryLevel 100 --batteryState charged --cellularBars 4 --operatorName "" 2>/dev/null || true

capture() {  # $1 = state name, $2 = seed+action JS
  cd "$APP_DIR"
  npm run sync-site >/dev/null
  # Seed storage BEFORE the main script runs; run actions after load.
  python3 - "$2" <<'PYEOF'
import sys, io
js = sys.argv[1]
p = 'www/index.html'
s = io.open(p, encoding='utf8').read()
s = s.replace('<body>', '<body>\n<script>' + js + '</script>', 1)
io.open(p, 'w', encoding='utf8').write(s)
PYEOF
  npx cap copy ios >/dev/null
  cd ios/App
  xcodebuild -workspace App.xcworkspace -scheme App -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO -quiet >/dev/null
  cd "$APP_DIR"
  xcrun simctl terminate "$DEV" com.intentmesh.confession1689 2>/dev/null || true
  xcrun simctl install "$DEV" "$APP_PRODUCT"
  xcrun simctl launch "$DEV" com.intentmesh.confession1689 >/dev/null
  sleep 8
  xcrun simctl io "$DEV" screenshot "$OUT/$1.png" >/dev/null
  echo "captured $1"
}

SEED_BM='localStorage.setItem("bm", JSON.stringify(["c1p1","c11p1","c17p1"]));
localStorage.setItem("nt", JSON.stringify({c11p1:"Justification is by faith alone, but not by a faith that is alone. See paragraph 2."}));'

capture 01-hero 'localStorage.setItem("theme","light");'

capture 02-proof 'localStorage.setItem("theme","light");
addEventListener("load",function(){setTimeout(function(){
  document.getElementById("c1p1").scrollIntoView(); scrollBy(0,-80);
  document.querySelector("#c1p1 .proofs .ref").click();
},1200);});'

capture 03-search 'localStorage.setItem("theme","light");
addEventListener("load",function(){setTimeout(function(){
  document.getElementById("tbSearch").click();
  setTimeout(function(){
    var i=document.getElementById("searchInput");
    i.value="effectual calling";
    i.dispatchEvent(new Event("input",{bubbles:true}));
    setTimeout(function(){ i.blur(); },1500);
  },500);
},1200);});'

capture 04-note "localStorage.setItem('theme','light'); $SEED_BM
addEventListener('load',function(){setTimeout(function(){
  document.getElementById('c11p1').scrollIntoView(); scrollBy(0,-90);
},1200);});"

capture 05-bookmarks "localStorage.setItem('theme','light'); $SEED_BM
addEventListener('load',function(){setTimeout(function(){
  document.getElementById('tbContents').click();
},1200);});"

capture 06-dark 'localStorage.setItem("theme","dark");
addEventListener("load",function(){setTimeout(function(){
  document.getElementById("c1p1").scrollIntoView(); scrollBy(0,-80);
  document.querySelector("#c1p1 .proofs .ref").click();
},1200);});'

# restore clean www
cd "$APP_DIR" && npm run sync-site >/dev/null && npx cap copy ios >/dev/null
xcrun simctl status_bar "$DEV" clear 2>/dev/null || true
for f in "$OUT"/*.png; do sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr '\n' ' '; echo "$f"; done
