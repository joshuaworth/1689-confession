# 1689 — App Store & Google Play Submission Kit

The Capacitor wrapper is built and verified: iOS simulator build succeeds and the app
runs clean (no webview errors); Android debug APK builds. Both store consoles are
reachable; what remains gated on Joshua is signing membership and final submission.

## Rebuild from scratch

```sh
cd app
npm install
npm run sync-site        # copies ../public into www, strips sw.js (app loads from disk)
npx cap sync
npx cap open ios         # or: npx cap open android
```

Android needs Java: `export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`

## Identity

- App ID: `com.intentmesh.confession1689`
- Home-screen label: **1689** (matches the mark)
- Store display name: **1689: The Baptist Confession of Faith**
- Version: 1.0 (1)

## Listing copy (no em dashes anywhere below)

**Subtitle / short description (30 chars):**
`Every proof, one tap away.`

**Description:**

The Second London Baptist Confession of Faith (1689), complete and unabridged:
thirty-two chapters, the 1677 preface To the Judicious and Impartial Reader, the
Appendix Concerning Baptism, and all thirty-seven signatories.

Every one of the 770 scripture proofs opens in place, in three public-domain
translations: the Berean Standard Bible, the King James Version, and the World
English Bible, side by side in parallel view.

- Instant full-text search across the confession, the apparatus, and every proof text
- Bookmark any paragraph and keep your own study notes beside the text
- Today's reading: one paragraph a day through the whole confession
- Picks up right where you left off
- Five reading sizes, light and dark
- Works entirely offline; the whole text ships with the app
- No ads, no account, no tracking, no cost. Ever.

The text is public domain. The app is a gift.

**Keywords (iOS, 100 chars):**
`1689,baptist,confession,reformed,creed,catechism,scripture,theology,puritan,westminster`

**Category:** Reference (primary), Books (secondary)

**Privacy answers (both stores):** Data Not Collected / No data shared. No analytics,
no tracking, no accounts, no third-party SDKs; bookmarks and notes live only on the
device. Privacy policy URL: https://1689.intentmesh.dev (colophon states the policy:
this site and app collect nothing).

**Age rating:** 4+ / Everyone.

## What only Joshua can do

**Apple** (needs Apple Developer Program membership, $99/yr):
1. Xcode: open `app/ios/App/App.xcworkspace`, Signing & Capabilities, select team.
2. Product > Archive > Distribute > App Store Connect.
3. appstoreconnect.apple.com: attach build, screenshots (6.7" and 6.9"), submit.

**Google** (needs Play Console account, $25 once):
1. `keytool -genkey -v -keystore release.keystore -alias confession1689 -keyalg RSA -keysize 2048 -validity 10000`
   (keystore stays OUT of git and must be backed up; losing it means losing the listing).
2. Configure signing in `android/app/build.gradle`, then `./gradlew bundleRelease`.
3. play.google.com/console: upload the `.aab`, listing copy above, submit.

## Review-risk posture (Apple guideline 4.2, minimum functionality)

Shipped mitigations, all verified working in the app: fully offline text, on-device
full-text search, bookmarks, per-paragraph study notes, today's reading, reading
position resume, five reading sizes, native splash and icons. This is a study app,
not a website wrapper. Planned for v1.1: a bundled narrated audiobook of the whole
confession (open-source neural voice, pending Joshua's approval of the sample).
