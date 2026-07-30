# Handoff — 1689 Confession (and Top Floor Tech)

Written 2026-07-30 at the end of a long session, for whoever picks this up next.
Joshua is the user. Read the two memory files first; they encode corrections he
has already had to make more than once.

---

## The one-line state

**iOS is finished and submitted to App Review** (version 1.0, build 14,
`WAITING_FOR_REVIEW`, auto-release on). **Android is a WebView wrapper and needs
to be rewritten natively in Kotlin.** Unity is now unblocked — the Hub is signed
in — and the game work has never once compiled.

---

## THE JOB

**Rewrite the Android app natively in Kotlin + Jetpack Compose, at parity with
the iOS app.** Today `app/android/` is Capacitor: a single `MainActivity.java`
hosting a WebView over the bundled website. Joshua asked directly whether it was
Kotlin, and the honest answer was no. He wants both stores to get the same app,
not the website in a box on one of them.

Secondary, already unblocked: **Top Floor Tech** (Unity) — see the bottom.

---

## Non-negotiable design law (he has corrected this repeatedly)

- **Blood red `#8a1016`, hover/active `#ad1620` — identical in light and dark.
  Never lighten red for dark-mode contrast. Lightened red reads as pink and he
  hates it viscerally.** This was violated three separate times before it stuck.
- Type: **EB Garamond** for reading and display, **Instrument Sans** for UI.
  Never Inter, never system fonts. TTFs live in
  `swift-app/Confession1689/Resources/Fonts/` — already instanced to real static
  weights (Regular/Medium/SemiBold/Bold). Copy those; do not re-download Google's
  variable versions, which collapse to one weight because every instance shares a
  PostScript name.
- Light: paper `#faf9f7`, ink `#1c1b1a`, deep `#f0eeea`, soft `#5c5955`, rule
  `#e2dfda`. Dark: bg `#121212`, ink `#e9e7e3`.
- Straight rules only. No ornament, no rounded cards with colored edges, no
  skeuomorphism. A red bar on a rounded card is the exact thing he called
  "hideous AI nonsense."
- **Platform ports are 1:1.** When porting an approved design, reproduce it
  exactly; do not substitute "native idiom." He caught three such drifts in the
  Swift port immediately.
- **Preview at mobile width and get his verdict before deploying visual changes.**

## How he wants to be worked with

- Execute the literal ask. Do not offer menus of options; `AskUserQuestion` with
  multiple choice made him furious ("reigning me into some multiple choice shit
  is not an option").
- **"Test everything you say you're doing, get proof or else you're wrong."**
  Screenshot it, curl it with a cache-buster, read it back from the API. A
  compile is not proof.
- Don't hand him a list of blockers. Exhaust what you can do first. He pushed
  back hard on this: "you don't need me at all." Twice, things I said needed him
  turned out to be my own tooling failing.
- Plain language. No em dashes in anything he ships.

---

## Where things are

| Thing | Path |
|---|---|
| Site generator (source of truth for content + web) | `build.py` → `public/` |
| Cloudflare worker (permalinks, AASA) | `worker.js` |
| **Native iOS app (reference implementation)** | `swift-app/` |
| Capacitor wrapper (iOS unused now; Android live) | `app/` |
| Store notes, listing copy, signing steps | `app/STORE.md` |
| Repo | `github.com/joshuaworth/1689-confession` (public) |

Data files, all already correct and shared:
- `confession.json` — `{title, chapters:[{number:Int, title, paragraphs:[{number:Int, text, proofs:"ref; ref"}]}]}`
- `apparatus.json` — `{preface{title,paragraphs[]}, appendix{...}, signatories{title,note,names[{name,role,church}],subscription}}`
- `public/verses.json` — `{"Ref": [{r,b,k,w}]}`, 770 refs, keys match proof strings exactly
- `swift-app/Confession1689/Resources/bible-bsb.json` — whole BSB, 31,086 verses,
  keyed `"Book Chapter"`. **Psalms needs an alias to "Psalm"** — that is the only
  book-name mismatch, already handled in `BibleStore.swift`.

---

## Feature parity checklist for the Kotlin app

Study `swift-app/Confession1689/Sources/` — each file maps to work:

1. **Reader** — one scroll: hero, preface, 32 chapters, appendix, signatories,
   colophon. *Document order matters: appendix comes AFTER chapter 32*, not next
   to the preface (he caught that).
2. **Apparatus collapsed** — preface and appendix rest closed behind their
   headers showing "N paragraphs · tap to read"; chapters stay open.
3. **Inline scripture proofs** — tap a red reference, verses open in place in a
   scholium (2px red left rule, small-caps red label, serif body). BSB/KJV/WEB
   and a parallel mode.
4. **Read the whole chapter** — "Read 2 Timothy 3 →" opens the full bundled
   chapter with cited verses marked by the red rule, auto-scrolled to the citation,
   with a chapter stepper and a "Cited in …" chip back.
5. **Long-press menu** — bookmark, note, copy link, share text, share as typeset
   image card.
6. **Notes** as in-flow scholia + a My Notes screen + Markdown export.
7. **Search** — port the scorer in `SearchView.swift` exactly (terms, phrase
   bonus, chapter jump, verse dedup), red highlighting of matches, recent searches.
8. **Today's reading** — `days_since_epoch % paragraph_count`, deterministic and
   identical across platforms and devices. Reading streak.
9. **Cold launch opens at the top** and *offers* "Continue reading …" — never
   auto-jumps. He specifically flagged the auto-jump as wrong.
10. **Five text sizes** (16.5/18.5/21/24/27) plus full system font-scale support.
11. Candlelight (dark), offline everything, daily reminder notification, home
    screen widget, deep links, share, haptics (light=proof, firm=bookmark,
    soft=chapter boundary), first-run frame, TalkBack labels and actions.

Android-specific equivalents worth having: Material You is **not** wanted —
the brand palette wins; Kotlin + Compose; DataStore for prefs; WorkManager or
AlarmManager for the daily reminder; Glance for the widget; app links via the
same `/p/<id>` permalinks (the association file for Android is
`/.well-known/assetlinks.json` — **it does not exist yet, you must add it to
`worker.js` alongside the Apple one**, using the Play App Signing SHA-256).

Deliberately **not** ported: the Foundation Models study companion (Apple
on-device LLM, no Android equivalent we committed to) and the Watch app.

---

## Credentials and tooling that already work

- **App Store Connect API** — key at `~/.appstoreconnect/private_keys/AuthKey_MDR3N3YJXX.p8`,
  issuer `f9c27b8e-d995-4b0f-805c-db500d67ee77`, key id `MDR3N3YJXX`. A helper
  `asc.py` was written in the session scratchpad; rewrite it if gone (JWT ES256,
  20-min exp, aud `appstoreconnect-v1`). **Prefer the API over the web UI** — the
  web UI silently failed a Delete All and left 10 interleaved screenshots.
- App Store app id `6796099200`, version id `cf8b328e-a017-41b9-81dd-7783e5db3fd3`.
- **Android signing** — `app/android/release.keystore` + `keystore.properties`,
  both gitignored. **They are not backed up anywhere. Losing them means losing
  the Play listing.** Tell Joshua to back them up.
- **Play Console** — developer account "Intent Mesh" `5216005430039487024`,
  app `4975640427136287638`, package `com.intentmesh.confession1689`, free.
  Store listing saved (icon, feature graphic, 4 screenshots, full description).
  Signed AAB sits in an internal testing release draft.
- **Cloudflare** — `npx wrangler deploy` from the repo root. Expect 10–30s of
  stale edge after deploy; verify with `?r=$RANDOM$RANDOM`.
- Xcode 26.6 / iOS 26.5 SDK. XcodeGen drives `swift-app/project.yml`.
  Do **not** pass `-sdk iphonesimulator` to xcodebuild — it stopped resolving
  once Mac Catalyst was enabled; use `-destination 'generic/platform=iOS Simulator'`.

---

## What remains on Play before it can go to production

Content rating questionnaire · data safety form (the true answer is **no data
collected** — nothing leaves the device) · target audience · 7-inch tablet
screenshots · then promote the internal release. Privacy policy URL is live at
`https://1689.intentmesh.dev/privacy`.

Decide with Joshua whether Play ships the wrapper now or waits for the Kotlin
rewrite. He leaned toward wanting them equal.

---

## Top Floor Tech (Unity) — now unblocked

`~/IntentMesh/Code/Projects/mobile/Top Floor Tech`, repo `joshuaworth/top-floor-tech` (private).

Unity 6000.3.4f1 is at `~/Applications/Unity-6000.3.4f1/Unity.app`; Unity Hub is
signed in as of this handoff, **but no `.ulf` license file had appeared yet** —
verify the editor actually launches before trusting it.

**Everything in `Assets/` was written blind and has never compiled.** Treat every
file as unverified. The plan lives at `~/.claude/plans/` history; the sequence is:

1. `tools/verify.sh` — compile headless, then `SetupTask.Run`,
   `MaterialLibraryBuilder.Build`, `PropPrefabBakery.Bake`,
   `CharacterPrefabBuilder.Build`, recompile, PlayMode tests.
2. Fix first-compile fallout. The likeliest culprit is
   `Assets/Editor/TopFloorTech.Editor.asmdef` missing URP references.
3. Then phases 3–7 of the plan: import pipeline, environment realism, character,
   audio activation, final verification.

The 2.1 GB of CC0 art is **gitignored and not on GitHub** — regenerate with
`tools/fetch_assets.py`. Individual files exceeded GitHub's 100 MB limit.

---

## Hard-won gotchas

- Cloudflare static assets serve dot-directories inconsistently — measured 404,
  200, 404 on identical requests for `/.well-known/…`. Serve association files
  **from the worker**.
- Universal links: never claim `/`; it hijacks every homepage visit. Use real
  permalinks (`/p/c11p1`).
- The iOS Simulator ships **no SensitiveContentAnalysis assets**, so Foundation
  Models always fails there with a bare error. Not a bug in the app.
- TipKit's `popoverTip(_ tip: (any Tip)?)` overload is iOS 26+; the iOS 17 form
  is obsoleted. Gate on 18.4.
- Control Center `ControlWidget` reaches back to **iOS 18**, not 26, and uses
  `StaticControlConfiguration` (not `StaticConfiguration`). Its builders reject
  conditionals.
- Journaling Suggestions is a **read** API — it pulls the user's photos and
  workouts *into* an app. It cannot donate a reading to Journal. Dropped.
- `zsh`: never use `for path in …`; it clobbers `PATH`.
- SSH to github.com hangs on this network — use HTTPS remotes.

---

## First thing to do

Read `~/.claude/projects/-Users-blackbetty-IntentMesh-Code-Projects-mobile-Top-Floor-Tech/memory/`
(`joshua-communication-style.md`, `joshua-design-taste.md`), then open
`swift-app/Confession1689/Sources/RootView.swift` and `ParagraphView.swift` —
they are the reference the Kotlin app has to match.
