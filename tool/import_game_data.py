#!/usr/bin/env python3
"""Imports the approved D1 alignment subset into game data.

Per the GPT review of the D1 package (2026-11-22):
- imports only editor-confirmed links (alignment_audit.csv verdicts),
- on the ACTUAL game texts (english/russian fields of levels.json),
- builds an explicit corpus->game token map (apostrophe folding merges
  corpus tokens " ' s" into one game chip "Jane's"),
- drops punctuation links (the lens never highlights punctuation),
- blocks levels whose corpus RU text differs from the game RU text
  (RU indices would point at the wrong words),
- reports every unmapped link instead of guessing.

Outputs:
- levels.json: adds "alignment" to approved levels + new level 140
  (corpus line 204, Rocket Summer scene puzzle),
- assets/scenes/rocket_summer_01.json: the first scene route.

Run: python3 tool/import_game_data.py
"""

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "assets" / "corpus"
OUT = ROOT / "tool" / "d1"

PUNCT = re.compile(r"^[^\w']+$")

# editor-approved lens levels: level_id -> corpus line (from alignment_audit)
APPROVED = {
    101: 205,
    102: 115,
    105: 351,
    107: 832,
    108: 239,
    120: 359,
}

NEW_LEVEL_204 = {
    "id": 140,
    "english": "The icicles dropped , shattering , to melt .",
    "russian": "Сосульки срывались с крыш , разбивались и таяли .",
    "difficulty": "medium",
    "commentaryRu": "Обратите внимание: shattering — причастие, вставленное между запятыми.",
    "prelearnPairs": [
        {"en": "icicles", "ru": "сосульки"},
        {"en": "melt", "ru": "таять"},
    ],
}

SCENE = {
    "id": "rocket_summer_01",
    "titleRu": "Ракетное лето",
    "steps": [
        {
            "kind": "context",
            "sourceLineIds": [201, 203],
            "textRu": "По зимнему городку прокатилась неожиданная волна тепла.",
            "textKind": "editorial_summary",
        },
        {"kind": "puzzle", "sourceLineId": 204, "levelId": 140},
        {"kind": "puzzle", "sourceLineId": 205, "levelId": 101},
    ],
}


def fold_token(token):
    """Folds a corpus token the way curation did: lowercase, typographic
    quote to ASCII, and apostrophe tokens join the previous word."""
    t = token.lower().replace("’", "'")
    return t


def build_corpus_map(corpus_tokens, game_tokens):
    """Maps 1-based corpus token indices to 0-based game token indices.
    Corpus apostrophe tokens (" '", "s") accumulate into the previous
    game chip ("Jane ' s" -> "Jane's"). Compared fully lowercase."""
    mapping = {}
    pending = ""
    gi = 0
    group_start = 1
    for ci, raw in enumerate(corpus_tokens, start=1):
        pending += fold_token(raw)
        if gi < len(game_tokens) and pending == game_tokens[gi].lower():
            # Every corpus token that contributed to this game chip
            # (Jane + ' + s -> Jane's) maps to the same chip.
            for k in range(group_start, ci + 1):
                mapping[k] = gi
            gi += 1
            pending = ""
            group_start = ci + 1
    if pending or gi != len(game_tokens):
        return None, (
            f"token mismatch (leftover '{pending}', "
            f"matched {gi}/{len(game_tokens)})"
        )
    return mapping, None


def main():
    src = (CORPUS / "enru.src").read_text(encoding="utf-8").splitlines()
    tgt = (CORPUS / "enru.tgt").read_text(encoding="utf-8").splitlines()
    talp = (CORPUS / "enru.talp").read_text(encoding="utf-8").splitlines()
    levels = json.loads((CORPUS / "levels.json").read_text(encoding="utf-8"))

    # editor verdicts from the D1 audit
    audit = {}
    for r in csv.DictReader(open(OUT / "alignment_audit.csv", encoding="utf-8")):
        audit.setdefault((int(r["level_id"]), int(r["corpus_line"])), []).append(r)

    by_id = {lv["id"]: lv for lv in levels}
    report = {"approved": [], "unmapped": [], "skipped_levels": []}
    exported = {}

    for level_id, line in sorted(APPROVED.items()):
        lv = by_id[level_id]
        corpus_en = src[line - 1].split()
        corpus_ru = tgt[line - 1].split()
        en_map, err = build_corpus_map(corpus_en, lv["english"].split())
        if en_map is None:
            report["skipped_levels"].append({"level": level_id, "reason": f"EN {err}"})
            continue
        ru_map, err = build_corpus_map(corpus_ru, lv["russian"].split())
        if ru_map is None:
            report["skipped_levels"].append({"level": level_id, "reason": f"RU {err}"})
            continue

        links = []
        for r in audit[(level_id, line)]:
            if r["verdict"] != "confirmed":
                report["unmapped"].append(
                    {"level": level_id, "link": f"{r['en_index']}-{r['ru_index']}",
                     "reason": f"verdict {r['verdict']}: {r['note']}"}
                )
                continue
            ci = int(r["en_index"])
            cj = int(r["ru_index"])
            if ci not in en_map or cj not in ru_map:
                report["unmapped"].append(
                    {"level": level_id, "link": f"{ci}-{cj}",
                     "reason": "index maps to punctuation or missing token"}
                )
                continue
            if PUNCT.match(r["en_token"]) or PUNCT.match(r["ru_token"]):
                report["unmapped"].append(
                    {"level": level_id, "link": f"{ci}-{cj}",
                     "reason": "punctuation excluded from the lens"}
                )
                continue
            links.append({"en": en_map[ci], "ru": ru_map[cj]})

        if not links:
            report["skipped_levels"].append({"level": level_id, "reason": "no confirmed lexical links"})
            continue
        # deduplicate identical pairs (clitic tokens can repeat one mapping)
        unique = []
        seen_pairs = set()
        for link in links:
            key = (link["en"], link["ru"])
            if key not in seen_pairs:
                seen_pairs.add(key)
                unique.append(link)
        links = unique
        exported[level_id] = {"links": links}
        report["approved"].append(
            {"level": level_id, "corpus_line": line, "links": len(links)}
        )

    # write alignment into levels.json
    for lv in levels:
        lv["alignment"] = exported.get(lv["id"], lv.get("alignment") if isinstance(lv.get("alignment"), dict) else None)
    if NEW_LEVEL_204["id"] not in {lv["id"] for lv in levels}:
        lv140 = dict(NEW_LEVEL_204)
        lv140["tokenCount"] = len(lv140["english"].split())
        lv140["alignment"] = None
        levels.append(lv140)
        levels.sort(key=lambda l: l["id"])
    (CORPUS / "levels.json").write_text(
        json.dumps(levels, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    scenes_dir = ROOT / "assets" / "scenes"
    scenes_dir.mkdir(exist_ok=True)
    (scenes_dir / "rocket_summer_01.json").write_text(
        json.dumps(SCENE, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    (OUT / "import_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
