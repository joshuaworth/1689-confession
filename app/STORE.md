# 1689 — App Store & Google Play Submission Kit

The Capacitor wrapper is built and verified: iOS simulator build succeeds and the app
runs clean (no webview errors); Android debug APK builds. What remains is signing and
the store consoles — both legally require Joshua's accounts.

## Rebuild from scratch

```sh
cd app
npm install
npm run sync-site        # copies ../public → www, strips sw.js (app loads from disk)
npx cap sync
npx cap open ios         # or: npx cap open android
```

Android needs Java: `export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`

## Identity

- App ID: `com.intentmesh.confession1689`
- Home-screen label: **1689** (matches the mark)
- Store display name: **1689 — The Baptist Confession of Faith**
- Version: 1.0 (1)

## Listing copy

**Subtitle / short description (30 chars):**
`Every proof, one tap away.`

**Description:**

The Second London Baptist Confession of Faith (1689), complete and unabridged —
thirty-two chapters, the 1677 preface To the Judicious and Impartial Reader, the
Appendix Concerning Baptism, and all thirty-seven signatories.

Every one of the 770 scripture proofs opens in place, in three public-domain
translations: the Berean Standard Bible, the King James Version, and the World
English Bible — side by side in parallel view.

- Instant full-text search across the confession and apparatus
- Five reading sizes, light and dark
- Works entirely offline — the whole text ships with the app
- No ads, no account, no tracking, no cost. Ever.

The text is public domain. The app is a gift.

**Keywords (iOS, 100 chars):**
`1689,baptist,confession,reformed,creed,catechism,scripture,theology,puritan,westminster`

**Category:** Reference (primary), Books (secondary)

**Privacy — App Store "App Privacy" answers:** Data Not Collected (no analytics, no
tracking, no accounts, no third-party SDKs; everything is on-device).
Privacy policy URL (both stores require one): https://1689.intentmesh.dev — add a
one-line colophon statement: "This site and app collect nothing."

**Age rating:** 4+ / Everyone.

## What only Joshua can do

**Apple** (needs Apple Developer Program membership, $99/yr):
1. Xcode → open `app/ios/App/App.xcworkspace` → Signing & Capabilities → select team.
2. Product → Archive → Distribute → App Store Connect.
3. appstoreconnect.apple.com → New App → paste listing copy above → attach
   screenshots (6.7" + 6.9" sim screenshots; capture from iPhone 17 Pro sim) → Submit.

**Google** (needs Play Console account, $25 once):
1. `keytool -genkey -v -keystore release.keystore -alias confession1689 -keyalg RSA -keysize 2048 -validity 10000`
   (keep the keystore OUT of git — it's ignored — and back it up; losing it means
   losing the app listing).
2. Configure signing in `android/app/build.gradle`, then `./gradlew bundleRelease`.
3. play.google.com/console → Create app → upload the `.aab` → listing copy above → Submit.

## Review-risk note (Apple guideline 4.2, minimum functionality)

Apple sometimes rejects thin website wrappers. Mitigations already in place: fully
offline text (no network needed at all), native splash/icons, on-device search,
persisted reading preferences. If a rejection cites 4.2, the planned answer is
bookmarks + highlights stored natively — flag it and it ships in v1.1.
