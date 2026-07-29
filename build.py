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
    links = [f'<button class="ref" data-ref="{html.escape(ref, quote=True)}">{html.escape(ref)}</button>'
             for ref in parts]
    return '<span class="proofs">( ' + '; '.join(links) + ' )</span>'


def render_paragraph(ch_num: int, p: dict, first: bool) -> str:
    text = html.escape(p["text"]).strip()
    if first and len(text) > 1:
        # Drop cap on the first letter of the chapter
        text = f'<span class="dropcap">{text[0]}</span>{text[1:]}'
    proofs = proof_links(p.get("proofs", ""))
    return (f'<div class="para" id="c{ch_num}p{p["number"]}">'
            f'<a class="pnum" href="#c{ch_num}p{p["number"]}" aria-label="Chapter {ch_num} paragraph {p["number"]}">{p["number"]}</a>'
            f'<p>{text} {proofs}</p></div>')


def build():
    data = json.loads(JSON_PATH.read_text())
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
    <div class="ch-rule"><span class="fleuron">❦</span></div>
    <div class="ch-kicker">Chapter {ROMAN[n]}</div>
    <h2>{title}</h2>
  </header>
  {paras}
</section>''')

    page = TEMPLATE.replace("{{TOC}}", "\n".join(toc_items)) \
                   .replace("{{CHAPTERS}}", "\n".join(body_chapters))
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
    for ch in chapters:
        md.append(f"\n## Chapter {ch['number']}: {ch['title']}\n")
        for p in ch["paragraphs"]:
            md.append(f"\n{p['number']}. {p['text']}\n")
            if p.get("proofs"):
                md.append(f"   *( {p['proofs']} )*\n")
    (OUT / "1689.md").write_text("".join(md))

    import shutil
    shutil.copy2(HERE / "confession.json", OUT / "confession.json")

    print(f"built {OUT / 'index.html'} ({len(page)//1024} KB, {len(chapters)} chapters) "
          f"+ robots, sitemap, llms.txt, 1689.md, confession.json")


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
<link rel="canonical" href="https://1689.intentmesh.dev/">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Book","name":"The Baptist Confession of Faith of 1689",
"alternateName":"Second London Baptist Confession of Faith","datePublished":"1689",
"inLanguage":"en","isAccessibleForFree":true,"license":"https://creativecommons.org/publicdomain/mark/1.0/",
"url":"https://1689.intentmesh.dev/","publisher":{"@type":"Organization","name":"IntentMesh","url":"https://intentmesh.dev"}}
</script>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Ctext y='0.9em' font-size='90'%3E%E2%9D%A6%3C/text%3E%3C/svg%3E">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,500;0,600;1,400&family=IM+Fell+English:ital@0;1&family=IM+Fell+English+SC&display=swap" rel="stylesheet">
<style>
:root {
  --paper: #f5efe2;
  --paper-deep: #ede4d0;
  --ink: #241f1a;
  --ink-soft: #4a4238;
  --oxblood: #7a0e15;
  --oxblood-bright: #9e131d;
  --gold: #8a6d2f;
  --rule: #c9bda3;
  --shadow: rgba(36, 31, 26, .12);
}
[data-theme="dark"] {
  --paper: #171310;
  --paper-deep: #100d0b;
  --ink: #e8dfcd;
  --ink-soft: #b3a689;
  --oxblood: #a80f18;
  --oxblood-bright: #d41520;
  --gold: #c2a05a;
  --rule: #3a322a;
  --shadow: rgba(0, 0, 0, .5);
}
* { margin: 0; padding: 0; box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  font-family: "EB Garamond", Georgia, serif;
  background: var(--paper);
  color: var(--ink);
  line-height: 1.65;
  font-size: 19px;
  transition: background .3s, color .3s;
}
/* Laid-paper grain */
body::before {
  content: ""; position: fixed; inset: 0; pointer-events: none; z-index: 1; opacity: .35;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='240' height='240'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3CfeColorMatrix values='0 0 0 0 0.5 0 0 0 0 0.45 0 0 0 0 0.38 0 0 0 0.05 0'/%3E%3C/filter%3E%3Crect width='240' height='240' filter='url(%23n)'/%3E%3C/svg%3E");
}
.wrap { position: relative; z-index: 2; display: grid; grid-template-columns: 300px minmax(0, 720px); gap: 56px; max-width: 1140px; margin: 0 auto; padding: 0 28px; }

/* ---------- Frontispiece ---------- */
.frontis {
  grid-column: 1 / -1; text-align: center; padding: 88px 20px 64px;
  border-bottom: 4px double var(--rule); margin-bottom: 40px; position: relative;
}
.frontis .smallrule { width: 120px; height: 1px; background: var(--rule); margin: 22px auto; position: relative; }
.frontis .smallrule::after { content: "❦"; position: absolute; top: -13px; left: 50%; transform: translateX(-50%);
  background: var(--paper); padding: 0 12px; color: var(--gold); font-size: 15px; }
.frontis .kicker { font-family: "IM Fell English SC", serif; letter-spacing: .35em; font-size: 15px; color: var(--oxblood); }
.frontis h1 { font-family: "IM Fell English SC", serif; font-weight: 400; font-size: clamp(42px, 7vw, 84px);
  line-height: 1.05; margin: 18px 0 8px; letter-spacing: .02em; }
.frontis .sub { font-family: "IM Fell English", serif; font-style: italic; font-size: clamp(17px, 2.4vw, 22px);
  color: var(--ink-soft); max-width: 560px; margin: 0 auto; }
.frontis .imprint { font-family: "IM Fell English SC", serif; font-size: 14px; letter-spacing: .22em;
  color: var(--ink-soft); margin-top: 30px; }
.frontis .imprint b { color: var(--oxblood); font-weight: 400; }

/* ---------- Sidebar ---------- */
.side { position: sticky; top: 0; align-self: start; max-height: 100vh; overflow-y: auto; padding: 28px 4px 40px;
  scrollbar-width: thin; }
.side h3 { font-family: "IM Fell English SC", serif; font-weight: 400; font-size: 15px; letter-spacing: .3em;
  color: var(--oxblood); margin-bottom: 14px; }
.side ol { list-style: none; }
.side li a { display: block; padding: 4.5px 10px; text-decoration: none; color: var(--ink-soft); font-size: 15.5px;
  border-left: 2px solid transparent; transition: all .15s; }
.side li a:hover { color: var(--oxblood-bright); border-left-color: var(--gold); }
.side li a.active { color: var(--oxblood); border-left-color: var(--oxblood); background: linear-gradient(90deg, var(--shadow), transparent); }
.side .rn { display: inline-block; width: 42px; font-family: "IM Fell English SC", serif; color: var(--gold); }

/* ---------- Controls ---------- */
.controls { display: flex; gap: 8px; margin-bottom: 18px; }
.controls button { font-family: "IM Fell English SC", serif; letter-spacing: .12em; font-size: 13px;
  background: transparent; color: var(--ink-soft); border: 1px solid var(--rule); border-radius: 3px;
  padding: 7px 12px; cursor: pointer; transition: all .15s; }
.controls button:hover { color: var(--oxblood); border-color: var(--oxblood); }
.controls button[aria-pressed="true"] { color: var(--paper); background: var(--oxblood); border-color: var(--oxblood); }

/* ---------- Chapters ---------- */
main { padding-bottom: 120px; }
.chapter { padding-top: 30px; }
.ch-head { text-align: center; margin: 46px 0 30px; }
.ch-rule { height: 1px; background: var(--rule); position: relative; margin-bottom: 26px; }
.ch-rule .fleuron { position: absolute; top: -14px; left: 50%; transform: translateX(-50%);
  background: var(--paper); padding: 0 14px; color: var(--gold); font-size: 17px; }
.ch-kicker { font-family: "IM Fell English SC", serif; font-size: 14px; letter-spacing: .34em; color: var(--gold); }
.ch-head h2 { font-family: "IM Fell English SC", serif; font-weight: 400; font-size: clamp(27px, 4vw, 38px);
  line-height: 1.15; color: var(--oxblood); margin-top: 6px; }
.para { position: relative; margin: 0 0 20px; padding-left: 54px; }
.para .pnum { position: absolute; left: 8px; top: 6px; font-family: "IM Fell English SC", serif; font-size: 15px;
  color: var(--gold); text-decoration: none; }
.para .pnum:hover { color: var(--oxblood-bright); }
.para p { text-align: justify; hyphens: auto; }
.dropcap { font-family: "IM Fell English SC", serif; float: left; font-size: 64px; line-height: .78;
  padding: 6px 8px 0 0; color: var(--oxblood); }
.proofs { font-size: 15px; color: var(--ink-soft); font-style: italic; }
.proofs .ref { font: inherit; color: var(--ink-soft); background: none; border: none; padding: 0;
  cursor: pointer; border-bottom: 1px dotted var(--gold); transition: color .15s; }
.proofs .ref:hover { color: var(--oxblood-bright); }
.proofs .ref.open { color: var(--oxblood); border-bottom-style: solid; border-bottom-color: var(--oxblood); }
body.hide-proofs .proofs { display: none; }

/* Inline proof-text panel */
.prooftext { margin: 10px 0 16px; padding: 14px 18px 12px; border-left: 3px solid var(--oxblood);
  background: linear-gradient(180deg, var(--paper-deep), transparent 240%);
  box-shadow: inset 0 1px 0 var(--rule), 0 2px 8px var(--shadow);
  animation: unfold .28s ease; border-radius: 0 4px 4px 0; }
@keyframes unfold { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: none; } }
.prooftext .pt-head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px; }
.prooftext .pt-ref { font-family: "IM Fell English SC", serif; font-size: 14px; letter-spacing: .16em; color: var(--oxblood); }
.prooftext .pt-close { font: inherit; font-size: 13px; background: none; border: none; color: var(--ink-soft);
  cursor: pointer; letter-spacing: .1em; }
.prooftext .pt-close:hover { color: var(--oxblood-bright); }
.prooftext .vrow { margin-bottom: 9px; font-size: 16.5px; line-height: 1.55; }
.prooftext .vref { font-family: "IM Fell English SC", serif; font-size: 13px; color: var(--gold); margin-right: 6px; white-space: nowrap; }
.prooftext .vtr { font-size: 11.5px; letter-spacing: .12em; color: var(--ink-soft); font-family: "IM Fell English SC", serif; margin-right: 6px; }
.prooftext .parallel .vrow + .vrow { margin-top: -3px; }
.prooftext .pt-foot { font-size: 12.5px; color: var(--ink-soft); font-style: italic; margin-top: 6px; }

/* Translation segmented control */
.seg { display: flex; border: 1px solid var(--rule); border-radius: 3px; overflow: hidden; }
.seg button { flex: 1; font-family: "IM Fell English SC", serif; letter-spacing: .1em; font-size: 12.5px;
  background: transparent; color: var(--ink-soft); border: none; padding: 7px 6px; cursor: pointer; transition: all .15s; }
.seg button + button { border-left: 1px solid var(--rule); }
.seg button:hover { color: var(--oxblood); }
.seg button.on { color: var(--paper); background: var(--oxblood); }

/* Reading progress + back-to-top */
#progress { position: fixed; top: 0; left: 0; height: 3px; width: 0; z-index: 50;
  background: linear-gradient(90deg, var(--oxblood), var(--gold)); transition: width .1s linear; }
#totop { position: fixed; right: 26px; bottom: 26px; z-index: 40; width: 46px; height: 46px; border-radius: 50%;
  border: 1px solid var(--rule); background: var(--paper); color: var(--gold); font-size: 19px; cursor: pointer;
  box-shadow: 0 4px 14px var(--shadow); opacity: 0; pointer-events: none; transition: all .25s; }
#totop.show { opacity: 1; pointer-events: auto; }
#totop:hover { color: var(--oxblood); border-color: var(--oxblood); }

/* ---------- Footer ---------- */
.colophon { grid-column: 1 / -1; text-align: center; border-top: 4px double var(--rule);
  padding: 44px 20px 70px; }
.colophon .sdg { font-family: "IM Fell English SC", serif; font-size: 22px; letter-spacing: .3em; color: var(--oxblood); }
.colophon p { font-size: 15px; color: var(--ink-soft); margin-top: 10px; }

/* ---------- Responsive ---------- */
@media (max-width: 900px) {
  .wrap { grid-template-columns: 1fr; gap: 0; }
  .side { position: relative; max-height: none; border-bottom: 1px solid var(--rule); margin-bottom: 8px; }
  .side ol { columns: 2; column-gap: 20px; }
  body { font-size: 17.5px; }
  .para { padding-left: 40px; }
}
@media print {
  .side, .controls, body::before { display: none !important; }
  .wrap { display: block; }
  body { font-size: 11pt; background: #fff; color: #000; }
  .proofs { display: block !important; }
}
</style>
</head>
<body>
<div class="wrap">

  <header class="frontis">
    <div class="kicker">Put forth by the Elders and Brethren</div>
    <h1>The Baptist<br>Confession of Faith</h1>
    <div class="smallrule"></div>
    <p class="sub">of many Congregations of Christians (baptized upon Profession of their Faith) in London and the Country; adopted by the General Assembly of 1689.</p>
    <div class="imprint">London · Printed in the Year <b>MDCLXXXIX</b></div>
  </header>

  <nav class="side" aria-label="Table of contents">
    <div class="controls">
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

  <main>
{{CHAPTERS}}
  </main>

  <footer class="colophon">
    <div class="sdg">Soli Deo Gloria</div>
    <p>The Second London Baptist Confession of Faith (1677/1689). The text is in the public domain.<br>
    Scripture proof references link to the King James Version.</p>
  </footer>

</div>
<div id="progress"></div>
<button id="totop" aria-label="Back to top">❦</button>
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
      versesPromise = fetch('verses.json').then(function (r) { return r.json(); });
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
      '<div class="pt-head"><span class="pt-ref">' + ref + ' · ' + trLabel + '</span>' +
      '<button class="pt-close">Close ✕</button></div>' + rows +
      '<div class="pt-foot">Berean Standard Bible and World English Bible are public domain; KJV is Crown copyright expired.</div>';
    panel.querySelector('.pt-close').addEventListener('click', function () { closePanel(panel); });
  }

  function closePanel(panel) {
    var btn = panel._refBtn;
    if (btn) { btn.classList.remove('open'); }
    panel.remove();
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
