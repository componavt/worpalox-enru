#!/usr/bin/env python3
"""Imports the approved D1 alignment subset into game data.

Per the GPT reviews of the D1 package and report 006:
- imports only editor-confirmed links (alignment_audit.csv verdicts),
- on the ACTUAL game texts (english/russian fields of levels.json),
- builds an explicit corpus->game token map; merging is allowed ONLY for
  the documented apostrophe pattern (word + ' + short suffix -> one chip),
- drops punctuation links (the lens never highlights punctuation),
- fails BEFORE touching game files when an approved level cannot be
  imported (strict mode, default); relaxed mode (--relaxed) writes
  alignment: null for the failed level instead of keeping stale links,
- verifies alignment_audit.csv rows against the corpus sources (tokens by
  index and the talp edge with its original kind),
- never writes the scene JSON (the scene is a curated asset),
- marks story-only levels so they stay out of the random pool.

Outputs:
- levels.json: "alignment" on approved levels + new story-only level 140,
- tool/d1/import_report.json.

Run: python3 tool/import_game_data.py [--relaxed] [--root DIR]
"""

import argparse
import csv
import json
import re
import sys
from pathlib import Path

PUNCT = re.compile(r"^[^\w']+$")
APOSTROPHE_SUFFIX = re.compile(r"^[a-z]{1,3}$")
LINK_RE = re.compile(r"^(\d+)([p-])(\d+)$")

# editor-approved lens levels: level_id -> corpus line (alignment_audit)
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
    "storyOnly": True,
}


def fold_token(token):
    """Normalization applied to BOTH sides: lowercase and typographic
    apostrophe folded to ASCII."""
    return token.lower().replace("’", "'")


def build_corpus_map(corpus_tokens, game_tokens):
    """Maps 1-based corpus token indices to 0-based game token indices.

    Only the documented apostrophe merge is allowed: a word token followed
    by an apostrophe token and a short suffix builds one game chip
    ("Jane", "'", "s" -> "Jane's"). Arbitrary joins of neighbouring words
    are rejected. Both sides are compared fully folded.
    """
    mapping = {}
    gi = 0
    ci = 0
    while ci < len(corpus_tokens) and gi < len(game_tokens):
        corpus_word = fold_token(corpus_tokens[ci])
        game_word = fold_token(game_tokens[gi])
        if corpus_word == game_word:
            mapping[ci + 1] = gi
            ci += 1
            gi += 1
            continue
        # documented apostrophe merge: word + ' + short suffix
        parts = corpus_tokens[ci: ci + 3]
        if (
            len(parts) == 3
            and fold_token(parts[0]) != ""
            and parts[1].strip() in {"'", "’"}
            and APOSTROPHE_SUFFIX.match(fold_token(parts[2]))
            and fold_token(parts[0]) + "'" + fold_token(parts[2]) == game_word
        ):
            for k in range(ci, ci + 3):
                mapping[k + 1] = gi
            ci += 3
            gi += 1
            continue
        return None, (
            f"token mismatch: corpus[{ci}]='{corpus_tokens[ci]}' "
            f"vs game[{gi}]='{game_tokens[gi]}'"
        )
    if ci != len(corpus_tokens) or gi != len(game_tokens):
        return None, (
            f"token count mismatch: corpus {ci}/{len(corpus_tokens)}, "
            f"game {gi}/{len(game_tokens)}"
        )
    return mapping, None


def verify_audit_row(row, corpus_en, corpus_ru, talp_line):
    """Cross-checks an alignment_audit.csv row against the corpus sources:
    the recorded tokens must match the source tokens at the recorded
    indices, and a corpus edge with the original kind must exist."""
    en_tokens = corpus_en.split()
    ru_tokens = corpus_ru.split()
    en_i = int(row["en_index"])
    ru_i = int(row["ru_index"])
    if not 1 <= en_i <= len(en_tokens) or en_tokens[en_i - 1] != row["en_token"]:
        return f"EN token mismatch at {en_i}: csv '{row['en_token']}' vs source '{en_tokens[en_i - 1] if 1 <= en_i <= len(en_tokens) else '?'}'"
    if not 1 <= ru_i <= len(ru_tokens) or ru_tokens[ru_i - 1] != row["ru_token"]:
        return f"RU token mismatch at {ru_i}: csv '{row['ru_token']}' vs source '{ru_tokens[ru_i - 1] if 1 <= ru_i <= len(ru_tokens) else '?'}'"
    expected_kind = "-" if row["talp_kind"] == "reliable" else "p"
    edge = f"{en_i}{expected_kind}{ru_i}"
    if edge not in talp_line.split():
        return f"talp edge '{edge}' not found in source line"
    return None


def load_audit(OUT):
    audit = {}
    for r in csv.DictReader(open(OUT / "alignment_audit.csv", encoding="utf-8")):
        audit.setdefault((int(r["level_id"]), int(r["corpus_line"])), []).append(r)
    return audit


def run_import(root: Path, strict: bool):
    corpus = root / "assets" / "corpus"
    out = root / "tool" / "d1"
    src = (corpus / "enru.src").read_text(encoding="utf-8").splitlines()
    tgt = (corpus / "enru.tgt").read_text(encoding="utf-8").splitlines()
    talp = (corpus / "enru.talp").read_text(encoding="utf-8").splitlines()
    levels = json.loads((corpus / "levels.json").read_text(encoding="utf-8"))
    audit = load_audit(out)

    by_id = {lv["id"]: lv for lv in levels}
    report = {"approved": [], "unmapped": [], "skipped_levels": [],
              "csv_source_issues": []}
    exported = {}

    for level_id, line in sorted(APPROVED.items()):
        lv = by_id[level_id]
        rows = audit.get((level_id, line))
        if not rows:
            problem = f"level {level_id}: no alignment_audit rows"
            if strict:
                raise SystemExit("STRICT IMPORT FAILURE: " + problem)
            report["skipped_levels"].append({"level": level_id, "reason": problem})
            exported[level_id] = None
            continue
        # CSV rows are verified against the corpus sources before use.
        for r in rows:
            issue = verify_audit_row(r, src[line - 1], tgt[line - 1], talp[line - 1])
            if issue:
                problem = f"level {level_id} line {line}: {issue}"
                if strict:
                    raise SystemExit("STRICT IMPORT FAILURE: " + problem)
                report["csv_source_issues"].append(problem)
        en_map, err = build_corpus_map(src[line - 1].split(), lv["english"].split())
        if en_map is None:
            problem = f"level {level_id}: EN {err}"
            if strict:
                raise SystemExit("STRICT IMPORT FAILURE: " + problem)
            report["skipped_levels"].append({"level": level_id, "reason": problem})
            exported[level_id] = None
            continue
        ru_map, err = build_corpus_map(tgt[line - 1].split(), lv["russian"].split())
        if ru_map is None:
            problem = f"level {level_id}: RU {err}"
            if strict:
                raise SystemExit("STRICT IMPORT FAILURE: " + problem)
            report["skipped_levels"].append({"level": level_id, "reason": problem})
            exported[level_id] = None
            continue

        links = []
        for r in rows:
            if r["verdict"] != "confirmed":
                report["unmapped"].append(
                    {"level": level_id,
                     "link": f"{r['en_index']}-{r['ru_index']}",
                     "reason": f"verdict {r['verdict']}"})
                continue
            ci, cj = int(r["en_index"]), int(r["ru_index"])
            if ci not in en_map or cj not in ru_map:
                report["unmapped"].append(
                    {"level": level_id, "link": f"{ci}-{cj}",
                     "reason": "index maps to punctuation or missing token"})
                continue
            if PUNCT.match(r["en_token"]) or PUNCT.match(r["ru_token"]):
                report["unmapped"].append(
                    {"level": level_id, "link": f"{ci}-{cj}",
                     "reason": "punctuation excluded from the lens"})
                continue
            links.append({"en": en_map[ci], "ru": ru_map[cj]})
        unique, seen = [], set()
        for link in links:
            key = (link["en"], link["ru"])
            if key not in seen:
                seen.add(key)
                unique.append(link)
        if not unique:
            problem = f"level {level_id}: no confirmed lexical links"
            if strict:
                raise SystemExit("STRICT IMPORT FAILURE: " + problem)
            report["skipped_levels"].append({"level": level_id, "reason": problem})
            exported[level_id] = None
            continue
        exported[level_id] = {"links": unique}
        report["approved"].append({"level": level_id, "corpus_line": line,
                                   "links": len(unique)})

    # Managed levels always receive the fresh result (None on failure):
    # stale generated links must never survive a failed re-import.
    managed_ids = set(APPROVED)
    for lv in levels:
        if lv["id"] in managed_ids:
            lv["alignment"] = exported.get(lv["id"])
        elif not isinstance(lv.get("alignment"), dict):
            lv["alignment"] = None
    # The story-only level is managed by this importer too: created when
    # missing, and its storyOnly flag is enforced when it already exists
    # (older imports created it without the flag).
    if NEW_LEVEL_204["id"] not in {lv["id"] for lv in levels}:
        lv140 = dict(NEW_LEVEL_204)
        lv140["tokenCount"] = len(lv140["english"].split())
        lv140["alignment"] = None
        levels.append(lv140)
        levels.sort(key=lambda l: l["id"])
    for lv in levels:
        if lv["id"] == NEW_LEVEL_204["id"]:
            lv["storyOnly"] = True

    (corpus / "levels.json").write_text(
        json.dumps(levels, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (out / "import_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--relaxed", action="store_true",
                        help="write alignment: null for failed levels instead of failing")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="project root (for tests on temp copies)")
    args = parser.parse_args()
    report = run_import(args.root.resolve(), strict=not args.relaxed)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
