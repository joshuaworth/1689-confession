#!/usr/bin/env python3
"""Resolves every scripture proof reference in confession.json to verse text
in BSB (default), KJV, and WEB — all public domain — writing
public/verses.json for the site's inline proof-text panels."""

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BSB_TXT = Path("/Users/blackbetty/fssb/data/raw/bsb.txt")
KJV_DIR = Path(sys.argv[1])
WEB_TXT = Path(sys.argv[2])

SINGLE_CHAPTER = {"obadiah", "philemon", "2john", "3john", "jude"}

ALIASES = {
    "psalm": "psalms", "ps": "psalms", "songofsongs": "songofsolomon",
    "canticles": "songofsolomon", "revelations": "revelation",
    "actsoftheapostles": "acts", "gal": "galatians", "rom": "romans",
    "romans": "romans", "cor": "corinthians", "matt": "matthew", "heb": "hebrews",
    "eph": "ephesians", "phil": "philippians", "col": "colossians",
    "tim": "timothy", "pet": "peter", "gen": "genesis", "exod": "exodus",
    "deut": "deuteronomy", "isa": "isaiah", "jer": "jeremiah",
}

WEB_CODES = {
    "GEN": "genesis", "EXO": "exodus", "LEV": "leviticus", "NUM": "numbers",
    "DEU": "deuteronomy", "JOS": "joshua", "JDG": "judges", "RUT": "ruth",
    "1SA": "1samuel", "2SA": "2samuel", "1KI": "1kings", "2KI": "2kings",
    "1CH": "1chronicles", "2CH": "2chronicles", "EZR": "ezra", "NEH": "nehemiah",
    "EST": "esther", "JOB": "job", "PSA": "psalms", "PRO": "proverbs",
    "ECC": "ecclesiastes", "SNG": "songofsolomon", "ISA": "isaiah",
    "JER": "jeremiah", "LAM": "lamentations", "EZK": "ezekiel", "DAN": "daniel",
    "HOS": "hosea", "JOL": "joel", "AMO": "amos", "OBA": "obadiah",
    "JON": "jonah", "MIC": "micah", "NAM": "nahum", "HAB": "habakkuk",
    "ZEP": "zephaniah", "HAG": "haggai", "ZEC": "zechariah", "MAL": "malachi",
    "MAT": "matthew", "MRK": "mark", "LUK": "luke", "JHN": "john", "ACT": "acts",
    "ROM": "romans", "1CO": "1corinthians", "2CO": "2corinthians",
    "GAL": "galatians", "EPH": "ephesians", "PHP": "philippians",
    "COL": "colossians", "1TH": "1thessalonians", "2TH": "2thessalonians",
    "1TI": "1timothy", "2TI": "2timothy", "TIT": "titus", "PHM": "philemon",
    "HEB": "hebrews", "JAS": "james", "1PE": "1peter", "2PE": "2peter",
    "1JN": "1john", "2JN": "2john", "3JN": "3john", "JUD": "jude",
    "REV": "revelation",
}


def norm(book: str) -> str:
    b = book.strip().lower().rstrip(".")
    b = re.sub(r"^i{3}\s", "3 ", b)
    b = re.sub(r"^i{2}\s", "2 ", b)
    b = re.sub(r"^i\s", "1 ", b)
    b = re.sub(r"[^a-z0-9]", "", b)
    return ALIASES.get(b, b)


def load_bsb():
    index = {}
    for line in BSB_TXT.read_text(encoding="utf-8-sig").splitlines():
        m = re.match(r"^(.+?) (\d+):(\d+)\t(.*)$", line)
        if m:
            book, ch, v, text = m.groups()
            index[(norm(book), int(ch), int(v))] = text.strip()
    return index


def load_kjv():
    index = {}
    for f in KJV_DIR.rglob("*.json"):
        try:
            d = json.loads(f.read_text())
        except Exception:
            continue
        if not isinstance(d, dict) or "book" not in d:
            continue
        b = norm(d["book"])
        for ch in d.get("chapters", []):
            cn = int(ch["chapter"])
            for v in ch.get("verses", []):
                index[(b, cn, int(v["verse"]))] = v["text"].strip()
    return index


def load_web():
    index = {}
    for line in WEB_TXT.read_text(encoding="utf-8-sig").splitlines():
        m = re.match(r"^([A-Z0-9]{3}) (\d+):(\d+)\s+(.*)$", line)
        if m and m.group(1) in WEB_CODES:
            index[(WEB_CODES[m.group(1)], int(m.group(2)), int(m.group(3)))] = m.group(4).strip()
    return index


BOOK_RE = r"(?:[1-3]\s?|I{1,3}\s)?[A-Z][A-Za-z]+(?:\s(?:of\s)?[A-Z][a-z]+)*\.?"
NUM = r"\d+(?![\s]*[A-Za-z])"
SPEC = rf"{NUM}(?:\s*[-–—]\s*{NUM})?(?:\s*,\s*{NUM}(?:\s*[-–—]\s*{NUM})?)*"
REF_RE = re.compile(rf"({BOOK_RE})\s+(\d+)(?::({SPEC}))?|(?<![:\d])({SPEC})")


def expand_spec(spec: str, ch: int):
    out = []
    for part in spec.replace("–", "-").replace("—", "-").split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            try:
                out.extend((ch, v) for v in range(int(a), int(b) + 1))
            except ValueError:
                pass
        elif part.isdigit():
            out.append((ch, int(part)))
    return out


def parse_ref(raw: str):
    """Tokenizes a raw proof segment into (norm_book, chapter, verse|None) triples.
    Handles: multiple refs in one segment, bare continuation verses, '&c./etc'
    suffixes, abbreviations, single-chapter books with and without colons."""
    text = raw.replace("&c.", " ").replace("etc.", " ").replace("etc", " ")
    text = re.sub(r"[()]", " ", text)
    triples = []
    last_book, last_ch = None, None
    for m in REF_RE.finditer(text):
        if m.group(1):  # book + chapter (+ optional verse spec)
            book, ch, spec = m.group(1), int(m.group(2)), m.group(3)
            nb = norm(book)
            if nb in SINGLE_CHAPTER:
                if spec:  # 'Jude 1:4' style — rare
                    triples += [(nb,) + cv for cv in expand_spec(spec, ch)]
                    last_book, last_ch = nb, ch
                else:     # 'Jude 4' / 'Jude 6, 7' — trailing numbers are verses
                    triples.append((nb, 1, ch))
                    last_book, last_ch = nb, 1
            elif spec:
                triples += [(nb,) + cv for cv in expand_spec(spec, ch)]
                last_book, last_ch = nb, ch
            else:         # whole chapter
                triples.append((nb, ch, None))
                last_book, last_ch = nb, ch
        elif m.group(4) and last_book:  # bare continuation numbers
            triples += [(last_book,) + cv for cv in expand_spec(m.group(4), last_ch)]
    return triples


def main():
    confession = json.loads((HERE / "confession.json").read_text())
    bsb, kjv, web = load_bsb(), load_kjv(), load_web()
    print(f"BSB: {len(bsb)}, KJV: {len(kjv)}, WEB: {len(web)} verses")

    refs = set()
    for ch in confession["chapters"]:
        for p in ch["paragraphs"]:
            for r in re.split(r"[;]", p.get("proofs", "")):
                if r.strip():
                    refs.add(r.strip())

    verses_out, unresolved = {}, []
    for ref in sorted(refs):
        entry, seen = [], set()
        for nb, ch, v in parse_ref(ref):
            pairs = ([(ch, x) for x in sorted(k[2] for k in bsb if k[0] == nb and k[1] == ch)]
                     if v is None else [(ch, v)])
            for c2, v2 in pairs:
                if (nb, c2, v2) in seen:
                    continue
                seen.add((nb, c2, v2))
                b, k, w = bsb.get((nb, c2, v2)), kjv.get((nb, c2, v2)), web.get((nb, c2, v2))
                if b is None and k is None and w is None:
                    unresolved.append(f"{ref} -> {nb} {c2}:{v2}")
                    continue
                display = re.sub(r"(?<=\d)([a-z])", r" \1", nb)  # cosmetic only
                pretty = f"{display.title()} {c2}:{v2}".replace("Songofsolomon", "Song of Solomon")
                entry.append({"r": pretty, "b": b or "", "k": k or "", "w": w or ""})
        if entry:
            verses_out[ref] = entry
        else:
            unresolved.append(ref + " (nothing resolved)")

    out_path = HERE / "public" / "verses.json"
    out_path.write_text(json.dumps(verses_out, ensure_ascii=False, separators=(",", ":")))
    print(f"wrote {out_path} ({out_path.stat().st_size // 1024} KB, {len(verses_out)}/{len(refs)} refs)")
    if unresolved:
        print(f"UNRESOLVED ({len(unresolved)}):")
        for u in unresolved[:25]:
            print("  -", u)


if __name__ == "__main__":
    main()
