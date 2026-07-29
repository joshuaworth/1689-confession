#!/usr/bin/env python3
"""Generates public/index.html for 1689.intentmesh.dev from confession JSON."""

import html
import json
import re
import sys
import urllib.parse
from pathlib import Path

HERE = Path(__file__).resolve().parent
JSON_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "confession.json"
OUT = HERE / "public"

ROMAN = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII",
         "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII",
         "XXIII", "XXIV", "XXV", "XXVI", "XXVII", "XXVIII", "XXIX", "XXX", "XXXI", "XXXII"]


def proof_links(proofs: str) -> str:
    if not proofs or not proofs.strip():
        return ""
    parts = [p.strip() for p in re.split(r"[;]", proofs) if p.strip()]
    links = [f'<button class="ref" data-ref="{html.escape(ref, quote=True)}" aria-expanded="false">{html.escape(ref)}</button>'
             for ref in parts]
    return '<span class="proofs">( ' + '; '.join(links) + ' )</span>'


def render_paragraph(ch_num: int, p: dict, first: bool) -> str:
    text = html.escape(p["text"]).strip()
    proofs = proof_links(p.get("proofs", ""))
    return (f'<div class="para" id="c{ch_num}p{p["number"]}">'
            f'<a class="pnum" href="#c{ch_num}p{p["number"]}" aria-label="Chapter {ch_num} paragraph {p["number"]}">{p["number"]}</a>'
            f'<p>{text} {proofs}</p></div>')


def apparatus_section(sid: str, kicker: str, title: str, paragraphs) -> str:
    paras = "\n".join(
        f'<div class="para" id="{sid}-p{i}">'
        f'<a class="pnum" href="#{sid}-p{i}" aria-label="{title} paragraph {i}">{i}</a>'
        f'<p>{html.escape(p).strip()}</p></div>'
        for i, p in enumerate(paragraphs, 1))
    return f'''
<section class="chapter" id="{sid}">
  <header class="ch-head">
    <div class="ch-kicker">{kicker}</div>
    <h2>{html.escape(title)}</h2>
  </header>
  {paras}
</section>'''


def build():
    data = json.loads(JSON_PATH.read_text())
    apparatus = json.loads((HERE / "apparatus.json").read_text())
    chapters = data["chapters"]
    assert len(chapters) == 32, f"expected 32 chapters, got {len(chapters)}"

    toc_items = []
    body_chapters = []
    for ch in chapters:
        n = ch["number"]
        title = html.escape(ch["title"])
        toc_items.append(f'<li><a href="#ch{n}"><span class="rn">{ROMAN[n]}</span> {title}</a></li>')
        paras = "\n".join(render_paragraph(n, p, i == 0) for i, p in enumerate(ch["paragraphs"]))
        body_chapters.append(f'''
<section class="chapter" id="ch{n}">
  <header class="ch-head">
    <div class="ch-kicker">Chapter {ROMAN[n]}</div>
    <h2>{title}</h2>
  </header>
  {paras}
</section>''')

    pre = apparatus["preface"]
    app = apparatus["appendix"]
    sig = apparatus["signatories"]

    preface_html = apparatus_section("preface", "Preface · 1677", pre["title"], pre["paragraphs"])
    appendix_html = apparatus_section("appendix", "Appendix · 1677", app["title"], app["paragraphs"])

    sig_rows = "\n".join(
        f'<div class="sig"><span class="sig-name">{html.escape(s["name"])}</span>'
        f'<span class="sig-church">{html.escape((s.get("role") or ""))}'
        f'{" · " if s.get("role") and s.get("church") else ""}{html.escape(s.get("church") or "")}</span></div>'
        for s in sig["names"])
    signatories_html = f'''
<section class="chapter" id="signatories">
  <header class="ch-head">
    <div class="ch-kicker">The General Assembly · 1689</div>
    <h2>{html.escape(sig["title"])}</h2>
  </header>
  <p class="sig-note">{html.escape(sig.get("note") or "")}</p>
  <div class="sig-grid">
{sig_rows}
  </div>
  <p class="sig-sub">{html.escape(sig.get("subscription") or "")}</p>
</section>'''

    toc_items.append('<li class="toc-div" aria-hidden="true">Apparatus</li>')
    toc_items.append('<li><a href="#preface"><span class="rn">✦</span> To the Reader (1677)</a></li>')
    toc_items.append('<li><a href="#appendix"><span class="rn">✦</span> Appendix on Baptism</a></li>')
    toc_items.append('<li><a href="#signatories"><span class="rn">✦</span> The Signatories</a></li>')

    all_body = preface_html + "\n" + "\n".join(body_chapters) + "\n" + appendix_html + "\n" + signatories_html

    page = TEMPLATE.replace("{{TOC}}", "\n".join(toc_items)) \
                   .replace("{{CHAPTERS}}", all_body)
    OUT.mkdir(exist_ok=True)
    (OUT / "index.html").write_text(page)

    # Crawler / AI-tool surface
    (OUT / "robots.txt").write_text(
        "User-agent: *\nAllow: /\nSitemap: https://1689.intentmesh.dev/sitemap.xml\n")
    (OUT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        '<url><loc>https://1689.intentmesh.dev/</loc><changefreq>yearly</changefreq></url>\n'
        '</urlset>\n')
    (OUT / "llms.txt").write_text(
        "# The Baptist Confession of Faith of 1689\n\n"
        "> The complete Second London Baptist Confession of Faith (1677/1689), all 32 chapters "
        "with scripture proofs, collated against the 1677 original-spelling edition. Public domain.\n\n"
        "This site is the full primary text, not commentary. Three clauses commonly dropped by "
        "internet e-texts (10.2, 11.1, 25.3) are restored here from the 1677 original.\n\n"
        "## Resources\n\n"
        "- [Full text, human-readable](https://1689.intentmesh.dev/): all chapters on one page\n"
        "- [Full text, Markdown](https://1689.intentmesh.dev/1689.md): plain-text for machines\n"
        "- [Structured JSON](https://1689.intentmesh.dev/confession.json): chapters/paragraphs/proofs\n"
        "- [Proof texts JSON](https://1689.intentmesh.dev/verses.json): every cited verse in BSB, KJV, WEB\n")

    md = ["# The Baptist Confession of Faith of 1689\n"]
    md.append(f"\n## {pre['title']} (1677 Preface)\n")
    for p in pre["paragraphs"]:
        md.append(f"\n{p}\n")
    for ch in chapters:
        md.append(f"\n## Chapter {ch['number']}: {ch['title']}\n")
        for p in ch["paragraphs"]:
            md.append(f"\n{p['number']}. {p['text']}\n")
            if p.get("proofs"):
                md.append(f"   *( {p['proofs']} )*\n")
    md.append(f"\n## {app['title']} (1677)\n")
    for p in app["paragraphs"]:
        md.append(f"\n{p}\n")
    md.append(f"\n## {sig['title']} (1689)\n\n{sig.get('note') or ''}\n")
    for s in sig["names"]:
        role = f", {s['role']}" if s.get("role") else ""
        church = f" — {s['church']}" if s.get("church") else ""
        md.append(f"- {s['name']}{role}{church}\n")
    md.append(f"\n*{sig.get('subscription') or ''}*\n")
    (OUT / "1689.md").write_text("".join(md))

    import shutil
    shutil.copy2(HERE / "confession.json", OUT / "confession.json")

    # ---- PWA: manifest + versioned service worker ----
    (OUT / "manifest.webmanifest").write_text(json.dumps({
        "name": "The Baptist Confession of Faith of 1689",
        "short_name": "1689",
        "description": "The complete Second London Baptist Confession with scripture proofs in BSB, KJV, and WEB.",
        "start_url": "/",
        "display": "standalone",
        "background_color": "#faf9f7",
        "theme_color": "#faf9f7",
        "icons": [
            {"src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png"},
        ],
    }, indent=1))

    import hashlib
    version = hashlib.sha1(page.encode() + (OUT / "verses.json").read_bytes()[:4096]).hexdigest()[:10]
    fonts = sorted(p.name for p in (OUT / "fonts").glob("*.woff2")) if (OUT / "fonts").exists() else []
    precache = (["/", "/verses.json?v=2", "/confession.json", "/manifest.webmanifest",
                 "/icons/icon-192.png", "/icons/icon-512.png"]
                + [f"/fonts/{f}" for f in fonts])
    (OUT / "sw.js").write_text(
        "const CACHE = 'c1689-" + version + "';\n"
        "const ASSETS = " + json.dumps(precache) + ";\n"
        "self.addEventListener('install', (e) => {\n"
        "  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));\n"
        "});\n"
        "self.addEventListener('activate', (e) => {\n"
        "  e.waitUntil(caches.keys().then((keys) =>\n"
        "    Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))\n"
        "  ).then(() => self.clients.claim()));\n"
        "});\n"
        "self.addEventListener('fetch', (e) => {\n"
        "  const req = e.request;\n"
        "  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;\n"
        "  e.respondWith(\n"
        "    caches.match(req).then((hit) => {\n"
        "      const net = fetch(req).then((res) => {\n"
        "        if (res && res.ok) {\n"
        "          const copy = res.clone();\n"
        "          caches.open(CACHE).then((c) => c.put(req, copy));\n"
        "        }\n"
        "        return res;\n"
        "      }).catch(() => hit || (req.mode === 'navigate' ? caches.match('/') : undefined));\n"
        "      return hit || net;\n"
        "    })\n"
        "  );\n"
        "});\n")

    print(f"built {OUT / 'index.html'} ({len(page)//1024} KB, {len(chapters)} chapters) "
          f"+ robots, sitemap, llms.txt, 1689.md, confession.json, manifest, sw ({version})")


TEMPLATE = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>The Baptist Confession of Faith of 1689</title>
<meta name="description" content="The Second London Baptist Confession of Faith (1689), complete with all thirty-two chapters and scripture proofs. Public domain.">
<meta property="og:title" content="The Baptist Confession of Faith of 1689">
<meta property="og:description" content="The complete text of the 1689 Second London Baptist Confession, with scripture proofs.">
<meta property="og:type" content="article">
<meta property="og:url" content="https://1689.intentmesh.dev/">
<meta property="og:image" content="https://1689.intentmesh.dev/og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="The Baptist Confession of Faith of 1689">
<meta name="twitter:description" content="All 32 chapters with every scripture proof readable inline in BSB, KJV, and WEB. No ads, no account, public domain.">
<meta name="twitter:image" content="https://1689.intentmesh.dev/og.png">
<link rel="canonical" href="https://1689.intentmesh.dev/">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Book","name":"The Baptist Confession of Faith of 1689",
"alternateName":"Second London Baptist Confession of Faith","datePublished":"1689",
"inLanguage":"en","isAccessibleForFree":true,"license":"https://creativecommons.org/publicdomain/mark/1.0/",
"url":"https://1689.intentmesh.dev/","publisher":{"@type":"Organization","name":"IntentMesh","url":"https://intentmesh.dev"}}
</script>
<link rel="icon" type="image/png" sizes="48x48" href="/icons/favicon-48.png">
<link rel="icon" type="image/png" sizes="32x32" href="/icons/favicon-32.png">
<link rel="manifest" href="/manifest.webmanifest">
<link rel="apple-touch-icon" href="/icons/icon-192.png">
<link rel="preload" href="/fonts/EBGaramond-400.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/InstrumentSans-400.woff2" as="font" type="font/woff2" crossorigin>
<meta name="theme-color" id="metaTheme" content="#faf9f7">
<style>
@font-face { font-family: 'EB Garamond'; font-style: normal; font-weight: 400; font-display: swap; src: url('/fonts/EBGaramond-400.woff2') format('woff2'); }
@font-face { font-family: 'EB Garamond'; font-style: italic; font-weight: 400; font-display: swap; src: url('/fonts/EBGaramond-400i.woff2') format('woff2'); }
@font-face { font-family: 'EB Garamond'; font-style: normal; font-weight: 500; font-display: swap; src: url('/fonts/EBGaramond-500.woff2') format('woff2'); }
@font-face { font-family: 'EB Garamond'; font-style: normal; font-weight: 600; font-display: swap; src: url('/fonts/EBGaramond-600.woff2') format('woff2'); }
@font-face { font-family: 'Instrument Sans'; font-style: normal; font-weight: 400; font-display: swap; src: url('/fonts/InstrumentSans-400.woff2') format('woff2'); }
@font-face { font-family: 'Instrument Sans'; font-style: normal; font-weight: 500; font-display: swap; src: url('/fonts/InstrumentSans-500.woff2') format('woff2'); }
@font-face { font-family: 'Instrument Sans'; font-style: normal; font-weight: 600; font-display: swap; src: url('/fonts/InstrumentSans-600.woff2') format('woff2'); }
@font-face { font-family: 'Instrument Sans'; font-style: normal; font-weight: 700; font-display: swap; src: url('/fonts/InstrumentSans-700.woff2') format('woff2'); }
:root {
  --paper: #faf9f7;
  --paper-deep: #f0eeea;
  --ink: #1c1b1a;
  --ink-soft: #5c5955;
  --oxblood: #8a1016;
  --oxblood-bright: #ad1620;
  --gold: #8a6d2f;
  --rule: #e2dfda;
  --shadow: rgba(20, 18, 16, .08);
  --sans: "Instrument Sans", -apple-system, sans-serif;
  --serif: "EB Garamond", Georgia, serif;
}
[data-theme="dark"] {
  --paper: #121212;
  --paper-deep: #1c1b1a;
  --ink: #e9e7e3;
  --ink-soft: #a3a09a;
  --oxblood: #8a1016;
  --oxblood-bright: #ad1620;
  --gold: #c2a05a;
  --rule: #2b2a28;
  --shadow: rgba(0, 0, 0, .45);
}
* { margin: 0; padding: 0; box-sizing: border-box; }
html { scroll-padding-top: 74px; }
body {
  font-family: var(--serif);
  background: var(--paper);
  color: var(--ink);
  line-height: 1.7;
  font-size: 18.5px;
  transition: background .3s, color .3s;
}
.wrap { position: relative; z-index: 2; display: grid; grid-template-columns: 280px minmax(0, 700px); gap: 56px; max-width: 1100px; margin: 0 auto; padding: 0 24px; }

/* ---------- Top bar + hero ---------- */
.topbar { grid-column: 1 / -1; position: sticky; top: 0; z-index: 50;
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 0; margin: 0 -24px; padding-left: 24px; padding-right: 16px;
  background: color-mix(in srgb, var(--paper) 85%, transparent);
  backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--rule); }
.wordmark { font: 700 19px/1 var(--sans); letter-spacing: -0.03em; color: var(--ink);
  text-decoration: none; }
.wordmark span { color: var(--oxblood); }
.topbar-actions { display: flex; gap: 2px; }
.tb-btn { width: 40px; height: 40px; display: grid; place-items: center; background: none;
  border: none; border-radius: 10px; color: var(--ink); cursor: pointer; }
.tb-btn svg { width: 19px; height: 19px; }
.tb-btn:hover { background: var(--paper-deep); color: var(--oxblood); }

.hero { grid-column: 1 / -1; padding: clamp(56px, 10vw, 120px) 0 clamp(40px, 6vw, 72px); }
.hero-kicker { font: 600 12px var(--sans); text-transform: uppercase; letter-spacing: .14em;
  color: var(--oxblood); margin-bottom: 20px; }
.hero h1 { font-family: var(--serif); font-weight: 500; font-size: clamp(56px, 13vw, 128px);
  line-height: .95; letter-spacing: -0.015em; margin-bottom: 26px; text-wrap: balance;
  color: var(--oxblood); }
.hero-sub { font: 400 16.5px/1.6 var(--sans); color: var(--ink-soft); max-width: 46ch; margin-bottom: 26px; }
.hero-meta { display: flex; flex-wrap: wrap; gap: 8px 0; font: 500 12.5px var(--sans); color: var(--ink-soft); }
.hero-meta span { display: flex; align-items: center; }
.hero-meta span + span::before { content: ""; width: 3px; height: 3px; border-radius: 50%;
  background: var(--oxblood); margin: 0 10px; }

/* ---------- Sidebar (desktop rail / mobile sheet) ---------- */
.side { position: sticky; top: 61px; align-self: start; max-height: calc(100vh - 61px);
  overflow-y: auto; padding: 28px 4px 40px; scrollbar-width: thin; overscroll-behavior: contain; }
.side-close { display: none; }
.side h3 { font: 600 11px var(--sans); text-transform: uppercase; letter-spacing: .14em;
  color: var(--ink-soft); margin: 22px 0 10px; }
.side ol { list-style: none; }
.side li a { display: flex; gap: 10px; padding: 6px 10px; text-decoration: none; color: var(--ink-soft);
  font: 400 14px/1.45 var(--sans); border-radius: 8px; transition: all .12s; }
.side li a:hover { color: var(--ink); background: var(--paper-deep); }
.side li a.active { color: var(--oxblood); background: var(--paper-deep); font-weight: 600; }
.side .rn { flex: 0 0 26px; font: 600 12px/1.7 var(--sans); color: var(--oxblood); }

/* ---------- Controls ---------- */
.controls { display: flex; gap: 8px; margin-bottom: 10px; flex-wrap: wrap; }
.controls button { font: 500 13px var(--sans); background: transparent; color: var(--ink-soft);
  border: 1px solid var(--rule); border-radius: 8px; padding: 8px 13px; cursor: pointer; transition: all .12s; }
.controls button:hover { color: var(--oxblood); border-color: var(--oxblood); }
.controls button[aria-pressed="true"] { color: var(--paper); background: var(--oxblood); border-color: var(--oxblood); }

/* ---------- Chapters ---------- */
main { padding-bottom: 120px; }
.chapter { border-top: 1px solid var(--rule); margin-top: 56px; padding-top: 44px;
  content-visibility: auto; contain-intrinsic-width: auto 300px;
  contain-intrinsic-height: auto 3200px; }
.chapter:first-of-type { border-top: none; margin-top: 0; }
.ch-head { margin: 0 0 28px; }
.ch-kicker { font: 600 12px var(--sans); text-transform: uppercase; letter-spacing: .14em;
  color: var(--oxblood); margin-bottom: 10px; }
.ch-head h2 { font-family: var(--serif); font-weight: 500; font-size: clamp(30px, 6vw, 44px);
  line-height: 1.1; letter-spacing: -0.01em; text-wrap: balance; color: var(--oxblood); }
.para { position: relative; margin: 0 0 18px; }
.para .pnum { font: 600 12px/1 var(--sans); color: var(--oxblood); text-decoration: none;
  margin-right: 9px; }
.para .pnum:hover { color: var(--oxblood-bright); }
.para p { display: inline; }
.para { display: block; }
.para > p { display: inline; }
.proofs { font: 400 13.5px var(--sans); color: var(--ink-soft); }
.proofs .ref { font: 500 13.5px var(--sans); color: var(--oxblood); background: none; border: none;
  padding: 0; cursor: pointer; opacity: .85; transition: opacity .12s; }
.proofs .ref:hover { opacity: 1; text-decoration: underline; text-underline-offset: 3px; }
.proofs .ref.open { opacity: 1; font-weight: 600; text-decoration: underline; text-underline-offset: 3px; }
body.hide-proofs .proofs { display: none; }

/* Inline proof text — an in-flow scholium, typeset as if it were always there */
.prooftext { display: grid; grid-template-rows: 0fr; position: relative; margin: 0;
  padding-left: 20px;
  transition: grid-template-rows .26s cubic-bezier(.25,1,.5,1), margin .26s cubic-bezier(.25,1,.5,1); }
.prooftext::before { content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 2px;
  background: var(--oxblood); transform: scaleY(0); transform-origin: top;
  transition: transform .26s cubic-bezier(.25,1,.5,1); }
.prooftext.open { grid-template-rows: 1fr; margin: 17px 0 22px; }
.prooftext.open::before { transform: scaleY(1); }
.prooftext .pt-inner { overflow: hidden; }
.prooftext .pt-body { opacity: 0; transform: translateY(6px); filter: blur(2px);
  transition: opacity .22s cubic-bezier(.25,1,.5,1) .07s, transform .22s cubic-bezier(.25,1,.5,1) .07s,
    filter .22s cubic-bezier(.25,1,.5,1) .07s; }
.prooftext.open .pt-body { opacity: 1; transform: none; filter: none; }
.prooftext.closing { grid-template-rows: 0fr; margin: 0; transition-duration: .2s; }
.prooftext.closing::before { transform: scaleY(0); transition-duration: .2s; }
.prooftext.closing .pt-body { opacity: 0; transform: none; filter: none; transition: opacity .15s ease; }
@media (prefers-reduced-motion: reduce) {
  .prooftext, .prooftext::before, .prooftext .pt-body { transition: opacity .15s ease !important; }
  .prooftext .pt-body { transform: none; filter: none; }
}
.prooftext .pt-head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 9px; }
.prooftext .pt-ref { font: 600 12px var(--sans); text-transform: uppercase; letter-spacing: .1em; color: var(--oxblood); }
.prooftext .pt-close { font: 500 12px var(--sans); background: none; border: none; color: var(--ink-soft);
  cursor: pointer; }
.prooftext .pt-close:hover { color: var(--oxblood-bright); }
.prooftext .vrow { margin-bottom: 12px; font-size: 17.5px; line-height: 1.55; color: var(--ink); }
.prooftext .vref { font: 600 11.5px var(--sans); color: var(--ink-soft); margin-right: 8px; white-space: nowrap; }
.prooftext .vtr { font: 700 10.5px var(--sans); letter-spacing: .1em; color: var(--oxblood); margin-right: 8px; }
.prooftext .parallel { margin-bottom: 16px; }
.prooftext .parallel .vrow { margin-bottom: 5px; }
.prooftext .pt-foot { font: 400 11.5px var(--sans); color: var(--ink-soft); margin-top: 4px; opacity: .75; }


/* Translation segmented control */
.seg { display: flex; background: var(--paper-deep); border-radius: 10px; padding: 3px; }
.seg button { flex: 1; font: 500 12.5px var(--sans); background: transparent; color: var(--ink-soft);
  border: none; border-radius: 7px; padding: 7px 8px; cursor: pointer; transition: all .12s; }
.seg button:hover { color: var(--ink); }
.seg button.on { color: var(--paper); background: var(--oxblood); font-weight: 600; }

/* Search */
.controls kbd { font-family: var(--sans); font-size: 10.5px; border: 1px solid var(--rule); border-radius: 5px;
  padding: 1px 5px; margin-left: 5px; color: var(--ink-soft); }
#searchOverlay { position: fixed; inset: 0; z-index: 60; background: rgba(10, 9, 8, .45);
  backdrop-filter: blur(4px); -webkit-backdrop-filter: blur(4px); display: none; }
#searchOverlay.open { display: block; }
.search-box { max-width: 640px; margin: 8vh auto 0; background: var(--paper);
  border: 1px solid var(--rule); border-radius: 16px; overflow: hidden;
  box-shadow: 0 24px 70px rgba(0,0,0,.35); }
.search-head { display: flex; align-items: center; border-bottom: 1px solid var(--rule); padding-left: 6px; }
#searchInput { flex: 1; font: 400 17px var(--sans); color: var(--ink);
  background: transparent; border: none; outline: none; padding: 17px 14px; }
#searchInput::placeholder { color: var(--ink-soft); opacity: .65; }
.search-esc { font: 500 11px var(--sans); color: var(--ink-soft);
  border: 1px solid var(--rule); border-radius: 6px; padding: 3px 8px; margin-right: 16px; cursor: pointer;
  background: none; }
#searchResults { max-height: 60vh; overflow-y: auto; scrollbar-width: thin; overscroll-behavior: contain; }
#searchOverlay { overscroll-behavior: contain; }
body.locked { position: fixed; left: 0; right: 0; width: 100%; }
.sr-group { font: 600 10.5px var(--sans); text-transform: uppercase; letter-spacing: .12em;
  color: var(--ink-soft); padding: 14px 18px 5px; }
.sr-item { display: block; width: 100%; text-align: left; background: none; border: none; cursor: pointer;
  padding: 10px 18px; border-left: 2px solid transparent; color: var(--ink); }
.sr-item .sr-where { font: 600 12px var(--sans); color: var(--oxblood); display: block; margin-bottom: 2px; }
.sr-item .sr-text { font: 400 15.5px/1.55 var(--serif); color: var(--ink-soft); display: block; }
.sr-item mark { background: none; color: var(--oxblood); font-weight: 600; }
.sr-item.active, .sr-item:hover { background: var(--paper-deep); border-left-color: var(--oxblood); }
.sr-empty { padding: 26px 18px 30px; text-align: center; font: 400 14px var(--sans); color: var(--ink-soft); }
.para.flash { animation: parflash 1.6s ease; }
@keyframes parflash { 0% { background: color-mix(in srgb, var(--oxblood) 14%, transparent); }
  100% { background: transparent; } }
@media (max-width: 700px) {
  .search-box { margin: 2vh 10px 0; border-radius: 14px; }
  #searchInput { font-size: 16px; }
}

/* Reading progress + back-to-top */
#progress { position: fixed; top: 0; left: 0; height: 2px; width: 0; z-index: 55;
  background: var(--oxblood); transition: width .1s linear; }
#totop { position: fixed; right: 22px; bottom: calc(22px + env(safe-area-inset-bottom)); z-index: 40; width: 44px; height: 44px; border-radius: 50%;
  border: 1px solid var(--rule); background: var(--paper); color: var(--ink-soft);
  font: 500 17px var(--sans); cursor: pointer;
  box-shadow: 0 6px 20px var(--shadow); opacity: 0; pointer-events: none; transition: all .2s; }
#totop.show { opacity: 1; pointer-events: auto; }
#totop:hover { color: var(--oxblood); border-color: var(--oxblood); }

/* ---------- Footer ---------- */
.colophon { grid-column: 1 / -1; border-top: 1px solid var(--rule); padding: 40px 0 72px; }
.colophon .sdg { font-family: var(--serif); font-style: italic; font-size: 19px; color: var(--oxblood); }
.colophon p { font: 400 13px/1.7 var(--sans); color: var(--ink-soft); margin-top: 10px; max-width: 60ch; }

/* ---------- Responsive: contents becomes a full-screen sheet ---------- */
@media (max-width: 900px) {
  .wrap { grid-template-columns: 1fr; gap: 0; }
  body { font-size: 17.5px; }
  .side { position: fixed; inset: 0; z-index: 65; height: 100dvh; max-height: 100dvh;
    background: var(--paper); padding: 64px 20px 40px; display: none; overflow-y: auto; }
  .side.open { display: block; animation: sheetin .18s ease; }
  @keyframes sheetin { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }
  .side-close { display: grid; place-items: center; position: absolute; top: 12px; right: 14px;
    width: 40px; height: 40px; background: var(--paper-deep); border: none; border-radius: 10px;
    color: var(--ink); font: 500 15px var(--sans); cursor: pointer; }
  .side li a { padding: 10px 10px; font-size: 15.5px; }
  #totop { bottom: calc(84px + env(safe-area-inset-bottom)); right: 16px; }
}
/* ---------- Apparatus ---------- */
.toc-div { font: 600 10.5px var(--sans); text-transform: uppercase; letter-spacing: .14em;
  color: var(--ink-soft); padding: 16px 10px 6px; list-style: none; }
.sig-note { font-style: italic; color: var(--ink-soft); margin-bottom: 24px; }
.sig-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px 32px; }
@media (max-width: 700px) { .sig-grid { grid-template-columns: 1fr; } }
.sig-name { display: block; font-family: var(--serif); font-size: 19px; color: var(--ink); }
.sig-church { display: block; font: 400 13px var(--sans); color: var(--ink-soft); margin-top: 2px; }
.sig-sub { font-style: italic; color: var(--ink-soft); margin-top: 26px; }

/* ---------- Accessibility ---------- */
.skip { position: absolute; left: -9999px; top: 0; z-index: 100; background: var(--oxblood);
  color: #fff; font: 600 14px var(--sans); padding: 10px 16px; border-radius: 0 0 8px 0; }
.skip:focus { left: 0; }
:focus-visible { outline: 2px solid var(--oxblood); outline-offset: 2px; border-radius: 2px; }

/* Copy-link toast */
#toast { position: fixed; left: 50%; bottom: 30px; transform: translateX(-50%) translateY(12px);
  background: var(--ink); color: var(--paper); font: 500 13px var(--sans); padding: 9px 16px;
  border-radius: 8px; opacity: 0; pointer-events: none; transition: all .2s ease; z-index: 80; }
#toast.show { opacity: 1; transform: translateX(-50%); }

/* Desktop hover preview */
.pt-pop { position: fixed; z-index: 75; max-width: 420px; background: var(--paper);
  border: 1px solid var(--rule); border-radius: 10px; padding: 13px 16px;
  box-shadow: 0 18px 50px rgba(0,0,0,.18); transform-origin: top left;
  animation: popin .15s cubic-bezier(.25,1,.5,1); }
@keyframes popin { from { opacity: 0; transform: scale(.96); } to { opacity: 1; transform: scale(1); } }
.pt-pop .vrow { font-size: 15.5px; line-height: 1.55; margin-bottom: 8px; font-family: var(--serif); }
.pt-pop .vref { font: 600 10.5px var(--sans); color: var(--ink-soft); margin-right: 7px; }
.pt-pop .pp-hint { font: 400 10.5px var(--sans); color: var(--ink-soft); opacity: .7; }

@media print {
  .topbar, .side, .controls, #progress, #totop, #searchOverlay, .skip, #toast { display: none !important; }
  .wrap { display: block; max-width: none; padding: 0; }
  @page { margin: 18mm; }
  body { font-size: 11pt; background: #fff; color: #000; }
  .hero { padding: 0 0 24px; }
  .hero h1, .ch-head h2, .hero-kicker, .ch-kicker { color: #000; }
  .chapter { break-before: page; border-top: none; margin-top: 0; content-visibility: visible;
    contain-intrinsic-size: none; }
  .chapter:first-of-type { break-before: auto; }
  .proofs { display: inline !important; }
  .proofs .ref { color: #444; }
}
</style>
</head>
<body>
<a class="skip" href="#main">Skip to the confession</a>
<div class="wrap">

  <header class="topbar">
    <a class="wordmark" href="#top">1689<span>.</span></a>
    <nav class="topbar-actions" aria-label="Site controls">
      <button class="tb-btn" id="tbSearch" aria-label="Search">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
      </button>
      <button class="tb-btn" id="tbTheme" aria-label="Toggle dark mode">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"/></svg>
      </button>
      <button class="tb-btn" id="tbContents" aria-label="Contents">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 6h16M4 12h16M4 18h10"/></svg>
      </button>
    </nav>
  </header>

  <section class="hero" id="top">
    <p class="hero-kicker">The Second London Baptist Confession · 1689</p>
    <h1>The Baptist<br>Confession<br>of&nbsp;Faith</h1>
    <p class="hero-sub">Thirty-two chapters. Every scripture proof one tap away, in three public-domain translations. No ads, no account — just the text.</p>
    <div class="hero-meta"><span>32 chapters</span><span>770 scripture proofs</span><span>BSB · KJV · WEB</span><span>Public domain</span></div>
  </section>

  <nav class="side" id="side" aria-label="Table of contents">
    <button class="side-close" id="sideClose" aria-label="Close contents">✕</button>
    <div class="controls">
      <button id="searchBtn" aria-label="Search (press slash)">Search <kbd>/</kbd></button>
      <button id="proofsBtn" aria-pressed="true">Scripture Proofs</button>
      <button id="themeBtn" aria-pressed="false">Candlelight</button>
    </div>
    <div class="controls">
      <div class="seg" role="group" aria-label="Proof text translation">
        <button data-tr="b" class="on">BSB</button>
        <button data-tr="k">KJV</button>
        <button data-tr="w">WEB</button>
        <button data-tr="p">Parallel</button>
      </div>
    </div>
    <h3>Contents</h3>
    <ol>
{{TOC}}
    </ol>
  </nav>

  <main id="main">
{{CHAPTERS}}
  </main>

  <footer class="colophon">
    <div class="sdg">Soli Deo Gloria</div>
    <p>The Second London Baptist Confession of Faith (1677/1689). The text is in the public domain.<br>
    Tap any scripture proof to read it in the Berean Standard Bible, the King James Version, or the
    World English Bible — or all three in parallel.</p>
  </footer>

</div>
<div id="progress"></div>
<div id="toast" role="status"></div>
<button id="totop" aria-label="Back to top">↑</button>

<div id="searchOverlay" role="dialog" aria-modal="true" aria-label="Search the confession">
  <div class="search-box">
    <div class="search-head">
      <input id="searchInput" type="search" autocomplete="off" spellcheck="false"
             placeholder="Search the confession and its scripture proofs&hellip;">
      <button class="search-esc" id="searchEsc">esc</button>
    </div>
    <div id="searchResults"></div>
  </div>
</div>
<script>
(function () {
  var proofsBtn = document.getElementById('proofsBtn');
  var themeBtn = document.getElementById('themeBtn');

  // ---- Proof-text panels (BSB / KJV / WEB / Parallel) ----
  var TR_NAMES = { b: 'BSB', k: 'KJV', w: 'WEB' };
  var mode = 'b';
  try { mode = localStorage.getItem('tr') || 'b'; } catch (e) {}
  var versesPromise = null;
  function verses() {
    if (!versesPromise) {
      versesPromise = fetch('verses.json?v=2').then(function (r) { return r.json(); });
    }
    return versesPromise;
  }

  function verseRow(v, tr) {
    var text = v[tr];
    if (!text) { return ''; }
    var label = mode === 'p' ? '<span class="vtr">' + TR_NAMES[tr] + '</span>' : '';
    return '<div class="vrow"><span class="vref">' + v.r + '</span>' + label + text + '</div>';
  }

  function renderPanel(panel, ref, data) {
    var rows = '';
    data.forEach(function (v) {
      if (mode === 'p') {
        rows += '<div class="parallel">' + verseRow(v, 'b') + verseRow(v, 'k') + verseRow(v, 'w') + '</div>';
      } else {
        rows += verseRow(v, mode) || verseRow(v, 'b') || verseRow(v, 'k') || verseRow(v, 'w');
      }
    });
    var trLabel = mode === 'p' ? 'Parallel' : TR_NAMES[mode];
    panel.innerHTML =
      '<div class="pt-inner"><div class="pt-body">' +
      '<div class="pt-head"><span class="pt-ref">' + ref + ' · ' + trLabel + '</span>' +
      '<button class="pt-close">Close ✕</button></div>' + rows +
      '<div class="pt-foot">Berean Standard Bible and World English Bible are public domain; KJV is Crown copyright expired.</div>' +
      '</div></div>';
    panel.querySelector('.pt-close').addEventListener('click', function () { closePanel(panel); });
  }

  function closePanel(panel) {
    var btn = panel._refBtn;
    if (btn) { btn.classList.remove('open'); btn.setAttribute('aria-expanded', 'false'); }
    panel.classList.remove('open');
    panel.classList.add('closing');
    setTimeout(function () { panel.remove(); }, 210);
  }

  document.querySelectorAll('.proofs .ref').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var para = btn.closest('.para');
      var existing = para.querySelector('.prooftext');
      if (existing && existing._refBtn === btn) { closePanel(existing); return; }
      if (existing) { closePanel(existing); }
      var ref = btn.getAttribute('data-ref');
      verses().then(function (all) {
        var data = all[ref];
        if (!data) { return; }
        var panel = document.createElement('div');
        panel.className = 'prooftext';
        panel._refBtn = btn;
        btn.classList.add('open');
        renderPanel(panel, ref, data);
        para.appendChild(panel);
        void panel.offsetHeight;
        panel.classList.add('open');
        btn.setAttribute('aria-expanded', 'true');
      });
    });
  });

  var segButtons = document.querySelectorAll('.seg button');
  function setMode(m) {
    mode = m;
    try { localStorage.setItem('tr', m); } catch (e) {}
    segButtons.forEach(function (b) { b.classList.toggle('on', b.getAttribute('data-tr') === m); });
    document.querySelectorAll('.prooftext').forEach(function (panel) {
      var btn = panel._refBtn;
      if (btn) {
        verses().then(function (all) {
          var data = all[btn.getAttribute('data-ref')];
          if (data) { renderPanel(panel, btn.getAttribute('data-ref'), data); }
        });
      }
    });
  }
  segButtons.forEach(function (b) {
    b.addEventListener('click', function () { setMode(b.getAttribute('data-tr')); });
  });
  setMode(mode);

  // ---- Search ----
  var overlay = document.getElementById('searchOverlay');
  var input = document.getElementById('searchInput');
  var resultsEl = document.getElementById('searchResults');
  var paraIndex = null, activeIdx = -1, currentItems = [];
  var ROMAN = ['', 'I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII','XIII','XIV','XV',
    'XVI','XVII','XVIII','XIX','XX','XXI','XXII','XXIII','XXIV','XXV','XXVI','XXVII','XXVIII',
    'XXIX','XXX','XXXI','XXXII'];

  function normText(s) {
    return s.toLowerCase().replace(/[‘’']/g, "'").replace(/[“”]/g, '"')
            .replace(/[—–]/g, '-');
  }

  function buildParaIndex() {
    if (paraIndex) { return paraIndex; }
    paraIndex = [];
    document.querySelectorAll('.chapter').forEach(function (ch) {
      var chNum = parseInt(ch.id.slice(2), 10);
      var chTitle = ch.querySelector('h2').textContent;
      ch.querySelectorAll('.para').forEach(function (para) {
        var m = para.id.match(/p(\d+)$/);
        var pNum = m ? m[1] : '';
        var clone = para.querySelector('p').cloneNode(true);
        var proofs = clone.querySelector('.proofs');
        if (proofs) { proofs.remove(); }
        var refs = [].map.call(para.querySelectorAll('.ref'), function (b) { return b.getAttribute('data-ref'); });
        paraIndex.push({ ch: chNum, chTitle: chTitle, p: pNum, text: clone.textContent.trim(),
                         el: para, refs: refs });
      });
    });
    return paraIndex;
  }

  function scoreText(ntext, terms, phrase) {
    var score = 0;
    for (var i = 0; i < terms.length; i++) {
      var idx = ntext.indexOf(terms[i]);
      if (idx === -1) { return 0; }
      score += 1;
      // count extra occurrences lightly
      score += Math.min(3, ntext.split(terms[i]).length - 2) * 0.3;
    }
    if (phrase && ntext.indexOf(phrase) !== -1) { score += 6; }
    return score;
  }

  function excerpt(text, terms) {
    var ntext = normText(text);
    var idx = terms.length ? ntext.indexOf(terms[0]) : 0;
    if (idx < 0) { idx = 0; }
    var start = Math.max(0, idx - 60);
    var slice = (start > 0 ? '…' : '') + text.slice(start, start + 190) +
                (start + 190 < text.length ? '…' : '');
    return highlight(slice, terms);
  }

  function escapeHtml(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function highlight(text, terms) {
    var safe = escapeHtml(text);
    if (!terms.length) { return safe; }
    var pattern = terms.map(function (t) {
      return t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }).join('|');
    try {
      return safe.replace(new RegExp('(' + pattern + ')', 'gi'), '<mark>$1</mark>');
    } catch (e) { return safe; }
  }

  function runSearch(q) {
    var phrase = normText(q.trim());
    if (!phrase || phrase.length < 2) { resultsEl.innerHTML = ''; currentItems = []; return; }
    var terms = phrase.split(/\s+/).filter(function (t) { return t.length > 1; });
    if (!terms.length) { terms = [phrase]; }

    var items = [];

    // Chapter jump: "chapter 11" / "ch 11" / bare number
    var chm = phrase.match(/^(?:chapter|chap|ch)?\.?\s*(\d{1,2})$/);
    if (chm) {
      var cn = parseInt(chm[1], 10);
      if (cn >= 1 && cn <= 32) {
        var chEl = document.getElementById('ch' + cn);
        items.push({ kind: 'chapter', where: 'Chapter ' + ROMAN[cn],
                     html: escapeHtml(chEl.querySelector('h2').textContent),
                     el: chEl, score: 100 });
      }
    }

    var paras = buildParaIndex();
    var pHits = [];
    paras.forEach(function (p) {
      var prefix = isNaN(p.ch) ? p.chTitle : ('Chapter ' + ROMAN[p.ch] + ' · ¶ ' + p.p + ' — ' + p.chTitle);
      var s = scoreText(normText(p.text), terms, phrase);
      if (s > 0) {
        pHits.push({ kind: 'para', where: isNaN(p.ch) ? p.chTitle + ' · ¶ ' + p.p : prefix,
                     html: excerpt(p.text, terms), el: p.el, score: s + 2 });
      }
      // also match on chapter title
      else if (scoreText(normText(p.chTitle), terms, phrase) > 0 && p.p === '1') {
        pHits.push({ kind: 'para', where: isNaN(p.ch) ? p.chTitle : ('Chapter ' + ROMAN[p.ch] + ' — ' + p.chTitle),
                     html: excerpt(p.text, []), el: p.el, score: 3 });
      }
    });
    pHits.sort(function (a, b) { return b.score - a.score; });
    items = items.concat(pHits.slice(0, 8));

    verses().then(function (all) {
      var vHits = [];
      var isRefQuery = /\d/.test(phrase) && /^[1-3]?\s?[a-z]+\.?\s*\d/.test(phrase);
      Object.keys(all).forEach(function (refKey) {
        all[refKey].forEach(function (v) {
          var matched = false, s = 0, source = '';
          if (isRefQuery && normText(v.r).indexOf(phrase) === 0) { s = 50; matched = true; source = v.b || v.k || v.w; }
          if (!matched) {
            var texts = [['BSB', v.b], ['KJV', v.k], ['WEB', v.w]];
            for (var i = 0; i < texts.length; i++) {
              if (!texts[i][1]) { continue; }
              var ts = scoreText(normText(texts[i][1]), terms, phrase);
              if (ts > 0) { s = ts; matched = true; source = texts[i][1]; v._tr = texts[i][0]; break; }
            }
          }
          if (matched) {
            vHits.push({ kind: 'verse', where: v.r + (v._tr ? ' · ' + v._tr : ''),
                         html: excerpt(source, isRefQuery ? [] : terms),
                         refKey: refKey, score: s });
          }
        });
      });
      vHits.sort(function (a, b) { return b.score - a.score; });
      // de-dup same verse cited in several paragraphs
      var seen = {}, deduped = [];
      vHits.forEach(function (h) {
        var key = h.where + h.html.slice(0, 40);
        if (!seen[key]) { seen[key] = 1; deduped.push(h); }
      });
      items = items.concat(deduped.slice(0, 10));
      render(items, q);
    });
  }

  function render(items, q) {
    currentItems = items; activeIdx = items.length ? 0 : -1;
    if (!items.length) {
      resultsEl.innerHTML = '<div class="sr-empty">Nothing found for “' + escapeHtml(q) + '”</div>';
      return;
    }
    var html = '', lastKind = '';
    items.forEach(function (item, i) {
      var group = item.kind === 'verse' ? 'In the Scripture Proofs' :
                  item.kind === 'chapter' ? 'Chapters' : 'In the Confession';
      if (group !== lastKind) { html += '<div class="sr-group">' + group + '</div>'; lastKind = group; }
      html += '<button class="sr-item' + (i === activeIdx ? ' active' : '') + '" data-i="' + i + '">' +
              '<span class="sr-where">' + escapeHtml(item.where) + '</span>' +
              '<span class="sr-text">' + item.html + '</span></button>';
    });
    resultsEl.innerHTML = html;
    resultsEl.querySelectorAll('.sr-item').forEach(function (btn) {
      btn.addEventListener('click', function () { choose(parseInt(btn.getAttribute('data-i'), 10)); });
    });
  }

  function choose(i) {
    var item = currentItems[i];
    if (!item) { return; }
    closeSearch();
    if (item.kind === 'verse') {
      var btn = document.querySelector('.proofs .ref[data-ref="' + item.refKey.replace(/"/g, '\\"') + '"]');
      if (btn) {
        var para = btn.closest('.para');
        para.scrollIntoView({ block: 'center' });
        flash(para);
        var existing = para.querySelector('.prooftext');
        if (!existing || existing._refBtn !== btn) { btn.click(); }
        return;
      }
    }
    item.el.scrollIntoView({ block: item.kind === 'chapter' ? 'start' : 'center' });
    if (item.kind !== 'chapter') { flash(item.el); }
  }

  function flash(el) {
    el.classList.remove('flash');
    void el.offsetWidth;
    el.classList.add('flash');
  }

  // Body scroll lock — stops iOS scrolling the page beneath open overlays
  var lockY = 0, lockCount = 0;
  function lockBody(on) {
    if (on) {
      if (++lockCount > 1) { return; }
      lockY = window.scrollY;
      document.body.style.top = (-lockY) + 'px';
      document.body.classList.add('locked');
    } else {
      if (lockCount === 0 || --lockCount > 0) { return; }
      document.body.classList.remove('locked');
      document.body.style.top = '';
      var html = document.documentElement;
      var prev = html.style.scrollBehavior;
      html.style.scrollBehavior = 'auto';
      window.scrollTo(0, lockY);
      html.style.scrollBehavior = prev;
    }
  }

  function openSearch() {
    overlay.classList.add('open');
    lockBody(true);
    verses();           // warm the verse data
    buildParaIndex();
    input.value = ''; resultsEl.innerHTML = ''; currentItems = [];
    setTimeout(function () { input.focus(); }, 30);
  }
  function closeSearch() {
    if (overlay.classList.contains('open')) { lockBody(false); }
    overlay.classList.remove('open');
  }

  document.getElementById('searchBtn').addEventListener('click', openSearch);
  document.getElementById('searchEsc').addEventListener('click', closeSearch);

  // Top bar + mobile contents sheet
  var side = document.getElementById('side');
  document.getElementById('tbSearch').addEventListener('click', openSearch);
  document.getElementById('tbTheme').addEventListener('click', function () {
    setTheme(document.documentElement.getAttribute('data-theme') !== 'dark');
  });
  var sheetMedia = window.matchMedia('(max-width: 900px)');
  function closeSheet() {
    if (side.classList.contains('open')) {
      side.classList.remove('open');
      if (sheetMedia.matches) { lockBody(false); }
    }
  }
  document.getElementById('tbContents').addEventListener('click', function () {
    if (side.classList.contains('open')) { closeSheet(); }
    else {
      side.classList.add('open');
      if (sheetMedia.matches) { lockBody(true); }
    }
  });
  document.getElementById('sideClose').addEventListener('click', closeSheet);
  side.addEventListener('click', function (e) {
    if (e.target.closest('a')) { closeSheet(); }
  });
  overlay.addEventListener('mousedown', function (e) { if (e.target === overlay) { closeSearch(); } });

  var debounce = null;
  input.addEventListener('input', function () {
    clearTimeout(debounce);
    debounce = setTimeout(function () { runSearch(input.value); }, 90);
  });
  input.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      if (!currentItems.length) { return; }
      activeIdx = (activeIdx + (e.key === 'ArrowDown' ? 1 : -1) + currentItems.length) % currentItems.length;
      resultsEl.querySelectorAll('.sr-item').forEach(function (b, i) {
        b.classList.toggle('active', i === activeIdx);
        if (i === activeIdx) { b.scrollIntoView({ block: 'nearest' }); }
      });
    } else if (e.key === 'Enter') {
      e.preventDefault(); choose(activeIdx);
    } else if (e.key === 'Escape') { closeSearch(); }
  });
  document.addEventListener('keydown', function (e) {
    var typing = /INPUT|TEXTAREA/.test(document.activeElement.tagName);
    if ((e.key === '/' && !typing) || ((e.metaKey || e.ctrlKey) && e.key === 'k')) {
      e.preventDefault(); openSearch();
    } else if (e.key === 'Escape' && overlay.classList.contains('open')) { closeSearch(); }
  });

  // ---- Copy-link paragraph numbers ----
  var toast = document.getElementById('toast');
  var toastTimer = null;
  document.querySelectorAll('.pnum').forEach(function (a) {
    a.addEventListener('click', function () {
      try {
        navigator.clipboard.writeText(location.origin + location.pathname + a.getAttribute('href'));
        toast.textContent = 'Link copied';
        toast.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function () { toast.classList.remove('show'); }, 1600);
      } catch (e) {}
    });
  });

  // ---- Desktop hover previews (Wikipedia-style intent delay) ----
  var pop = null, popTimer = null, popFor = null, lastPop = 0;
  function hidePop() { if (pop) { pop.remove(); pop = null; popFor = null; } }
  if (window.matchMedia('(hover: hover) and (min-width: 1100px)').matches) {
    document.querySelectorAll('.proofs .ref').forEach(function (btn) {
      btn.addEventListener('mouseenter', function () {
        clearTimeout(popTimer);
        var delay = (Date.now() - lastPop < 45000) ? 150 : 550;
        popTimer = setTimeout(function () {
          verses().then(function (all) {
            var data = all[btn.getAttribute('data-ref')];
            if (!data || para(btn).querySelector('.prooftext')) { return; }
            hidePop();
            pop = document.createElement('div');
            pop.className = 'pt-pop';
            var html = '';
            data.slice(0, 3).forEach(function (v) {
              var tr = mode === 'p' ? 'b' : mode;
              var t = v[tr] || v.b || v.k || v.w;
              if (t) { html += '<div class="vrow"><span class="vref">' + v.r + '</span>' + t + '</div>'; }
            });
            if (data.length > 3) { html += '<div class="pp-hint">+' + (data.length - 3) + ' more — click to pin</div>'; }
            pop.innerHTML = html;
            document.body.appendChild(pop);
            var r = btn.getBoundingClientRect();
            var x = Math.max(12, Math.min(r.left, window.innerWidth - 444));
            var y = r.bottom + 8;
            if (y + pop.offsetHeight > window.innerHeight - 14) { y = r.top - pop.offsetHeight - 8; }
            pop.style.left = x + 'px';
            pop.style.top = y + 'px';
            popFor = btn;
            lastPop = Date.now();
          });
        }, delay);
      });
      btn.addEventListener('mouseleave', function () {
        clearTimeout(popTimer);
        setTimeout(function () { if (popFor === btn) { hidePop(); } }, 80);
      });
      btn.addEventListener('click', function () { clearTimeout(popTimer); hidePop(); });
    });
    window.addEventListener('scroll', hidePop, { passive: true });
  }
  function para(el) { return el.closest('.para'); }

  // ---- Offline (PWA) ----
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('/sw.js').catch(function () {});
    });
  }

  // Tapping the empty top bar area scrolls to top (native-app convention)
  document.querySelector('.topbar').addEventListener('click', function (e) {
    if (e.target.closest('button, a')) { return; }
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  // ---- Reading progress + back-to-top ----
  var progress = document.getElementById('progress');
  var totop = document.getElementById('totop');
  window.addEventListener('scroll', function () {
    var max = document.documentElement.scrollHeight - window.innerHeight;
    progress.style.width = (max > 0 ? (window.scrollY / max) * 100 : 0) + '%';
    totop.classList.toggle('show', window.scrollY > 900);
  }, { passive: true });
  totop.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: 'smooth' }); });

  proofsBtn.addEventListener('click', function () {
    var hidden = document.body.classList.toggle('hide-proofs');
    proofsBtn.setAttribute('aria-pressed', String(!hidden));
  });

  function setTheme(dark) {
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    var mt = document.getElementById('metaTheme');
    if (mt) { mt.setAttribute('content', dark ? '#121212' : '#faf9f7'); }
    themeBtn.setAttribute('aria-pressed', String(dark));
    try { localStorage.setItem('theme', dark ? 'dark' : 'light'); } catch (e) {}
  }
  var saved = null;
  try { saved = localStorage.getItem('theme'); } catch (e) {}
  setTheme(saved ? saved === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches);
  themeBtn.addEventListener('click', function () {
    setTheme(document.documentElement.getAttribute('data-theme') !== 'dark');
  });

  // Active chapter highlight
  var links = {};
  document.querySelectorAll('.side li a').forEach(function (a) {
    links[a.getAttribute('href').slice(1)] = a;
  });
  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (en.isIntersecting) {
        Object.values(links).forEach(function (a) { a.classList.remove('active'); });
        var a = links[en.target.id];
        if (a) { a.classList.add('active'); }
        try { history.replaceState(null, '', '#' + en.target.id); } catch (e) {}
      }
    });
  }, { rootMargin: '-20% 0px -70% 0px' });
  document.querySelectorAll('.chapter').forEach(function (s) { observer.observe(s); });
})();
</script>
</body>
</html>'''


if __name__ == "__main__":
    build()
