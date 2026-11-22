#!/usr/bin/env python3
"""Technical audit of the bundled RNC EN-RU aligned corpus snapshot.

Reads assets/corpus/enru.src, enru.tgt, enru.talp and assets/corpus/levels.json,
then writes a technical report for the D1 markup milestone:

- tool/d1/audit_summary.json  -- aggregate numbers (feeds talp_summary.md)
- tool/d1/audit_lines.csv     -- one row per corpus line
- tool/d1/level_mapping.csv   -- game levels matched to corpus lines

Everything here is descriptive; no game data is modified. talp indices are
1-based over whitespace tokens of enru.src / enru.tgt ("i-j" reliable,
"ipj" probable). Usage: python3 tool/talp_audit.py [--seed N]
"""

import argparse
import csv
import json
import random
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "assets" / "corpus"
OUT = ROOT / "tool" / "d1"

LINK_RE = re.compile(r"^(\d+)([p-])(\d+)$")


def tokenize(text):
    return text.split()


def parse_talp_line(line):
    """Returns a list of (en_index, ru_index, reliable) tuples. The corpus
    mixes two spellings inside the same line: "i-j" (reliable) and "ipj"
    (probable). Malformed tokens are reported separately."""
    links = []
    bad = []
    for token in line.split():
        m = LINK_RE.match(token)
        if not m:
            bad.append(token)
            continue
        links.append((int(m.group(1)), int(m.group(3)), m.group(2) == "-"))
    return links, bad


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261122)
    args = parser.parse_args()

    src_lines = (CORPUS / "enru.src").read_text(encoding="utf-8").splitlines()
    tgt_lines = (CORPUS / "enru.tgt").read_text(encoding="utf-8").splitlines()
    talp_lines = (CORPUS / "enru.talp").read_text(encoding="utf-8").splitlines()
    levels = json.loads((CORPUS / "levels.json").read_text(encoding="utf-8"))

    summary = {}
    if not (len(src_lines) == len(tgt_lines) == len(talp_lines)):
        print(
            "FATAL: file line counts differ: "
            f"src={len(src_lines)} tgt={len(tgt_lines)} talp={len(talp_lines)}"
        )
        sys.exit(1)
    total = len(src_lines)
    summary["total_lines"] = total
    summary["files_in_sync"] = True

    terminal = {".", "!", "?", "…", "?!", "!?"}
    rows = []
    link_counts = Counter()
    bad_talp_tokens = []
    empty_alignment = []
    out_of_bounds = []
    unpaired_en_counter = Counter()
    dup_map = {}

    en_text_seen = {}
    duplicates = []

    for number, (en, ru, talp) in enumerate(
        zip(src_lines, tgt_lines, talp_lines), start=1
    ):
        en_toks = tokenize(en)
        ru_toks = tokenize(ru)
        links, bad = parse_talp_line(talp)
        if bad:
            bad_talp_tokens.append({"line": number, "tokens": bad})
        link_counts[len(links)] += 1
        if not links:
            empty_alignment.append(number)

        en_idx = {i for i, _, _ in links}
        ru_idx = {j for _, j, _ in links}
        oob = [
            {"line": number, "kind": "en", "index": i}
            for i in en_idx
            if not 1 <= i <= len(en_toks)
        ] + [
            {"line": number, "kind": "ru", "index": j}
            for j in ru_idx
            if not 1 <= j <= len(ru_toks)
        ]
        if oob:
            out_of_bounds.extend(oob)

        en_unpaired = [
            t for i, t in enumerate(en_toks, start=1) if i not in en_idx
        ]
        ru_unpaired = [
            t for j, t in enumerate(ru_toks, start=1) if j not in ru_idx
        ]
        for t in en_unpaired:
            unpaired_en_counter[t.lower()] += 1

        # many-to-one / one-to-many groups (ignoring punctuation tokens)
        ru_groups = Counter(i for i, _, _ in links)
        en_groups = Counter(j for _, j, _ in links)

        # calque inversions: reliable pairs only, mean ru index per en token
        reliable = [(i, j) for i, j, ok in links if ok]
        ru_mean = {}
        for i, j in reliable:
            ru_mean.setdefault(i, []).append(j)
        key = {i: sum(v) / len(v) for i, v in ru_mean.items()}
        ordered = sorted(key)
        inversions = [
            (b, a)
            for x, a in enumerate(ordered)
            for b in ordered[x + 1 :]
            if key[b] < key[a]
        ]

        movable = list(en_toks)
        if len(movable) > 1 and movable[-1] in terminal:
            movable = movable[:-1]
        ratio = round(len(en_toks) / max(1, len(ru_toks)), 2)

        norm_en = " ".join(en_toks).lower()
        if norm_en in en_text_seen:
            duplicates.append((number, en_text_seen[norm_en]))
        else:
            en_text_seen[norm_en] = number

        rows.append(
            {
                "line_id": number,
                "en": en,
                "ru": ru,
                "en_tokens": len(en_toks),
                "ru_tokens": len(ru_toks),
                "movable_tokens": len(movable),
                "links": len(links),
                "reliable": sum(1 for _, _, ok in links if ok),
                "probable": sum(1 for _, _, ok in links if not ok),
                "en_unpaired": len(en_unpaired),
                "ru_unpaired": len(ru_unpaired),
                "m2o_groups": sum(1 for c in ru_groups.values() if c > 1),
                "o2m_groups": sum(1 for c in en_groups.values() if c > 1),
                "calque_inversions": len(inversions),
                "inversion_pairs": " ".join(f"{b}<{a}" for b, a in inversions),
                "length_ratio": ratio,
                "duplicate_of": "",
            }
        )

    for number, original in duplicates:
        for row in rows:
            if row["line_id"] == number:
                row["duplicate_of"] = original

    # game level mapping: normalized english match with apostrophe folding.
    # The corpus mixes ASCII ' and typographic ’ and keeps apostrophes as
    # separate " ' " tokens; curated levels fold both. Some corpus lines
    # carry trailing "..." after the terminal mark, hence the prefix match.
    level_norm = lambda s: " ".join(tokenize(s)).lower()
    fold = lambda s: level_norm(s).replace("’", "'").replace(" ' ", "'")
    corpus_by_en = {fold(en): n for n, en in enumerate(src_lines, 1)}
    corpus_by_pair = {
        (fold(en), fold(ru)): n
        for n, (en, ru) in enumerate(zip(src_lines, tgt_lines), 1)
    }
    mapping = []
    found = 0
    for lv in levels:
        key = fold(lv["english"])
        n = corpus_by_en.get(key)
        how = "en"
        if n is None:
            n = corpus_by_pair.get((key, fold(lv["russian"])))
            how = "en+ru"
        if n is None:
            for line_key, num in corpus_by_en.items():
                if line_key.startswith(key):
                    n = num
                    how = "en-prefix"
                    break
        if n is not None:
            found += 1
        # GPT review (D1): a prefix match is provenance only, never an
        # alignment import permission.
        mapping.append(
            {
                "level_id": lv["id"],
                "corpus_line": n or "",
                "match": how if n else "not_found",
                "import_allowed": "no" if how == "en-prefix" or n is None else "yes",
                "english": lv["english"],
            }
        )

    ratios = [r["length_ratio"] for r in rows]
    ratios_sorted = sorted(ratios)
    summary.update(
        {
            "talp_base": "1-based (verified on line 205: 2-1 3-2 4-2 5-3)",
            "total_links": sum(r["links"] for r in rows),
            "reliable_links": sum(r["reliable"] for r in rows),
            "probable_links": sum(r["probable"] for r in rows),
            "lines_without_links": len(empty_alignment),
            "lines_without_links_ids": empty_alignment[:20],
            "out_of_bounds_count": len(out_of_bounds),
            "out_of_bounds_sample": out_of_bounds[:10],
            "bad_talp_tokens": bad_talp_tokens[:10],
            "links_per_line_min": min(link_counts) if link_counts else 0,
            "links_per_line_max": max(link_counts) if link_counts else 0,
            "links_per_line_mean": round(sum(r["links"] for r in rows) / total, 1),
            "links_distribution": {
                str(k): v for k, v in sorted(link_counts.items())
            },
            "en_unpaired_token_share": round(
                sum(r["en_unpaired"] for r in rows)
                / max(1, sum(r["en_tokens"] for r in rows)),
                3,
            ),
            "en_unpaired_top": unpaired_en_counter.most_common(15),
            "m2o_groups_total": sum(r["m2o_groups"] for r in rows),
            "o2m_groups_total": sum(r["o2m_groups"] for r in rows),
            "duplicate_en_lines": duplicates,
            "length_ratio_min": ratios_sorted[0],
            "length_ratio_max": ratios_sorted[-1],
            "length_ratio_outliers_15": sum(
                1 for r in ratios if r >= 1.5 or r <= 0.67
            ),
            "levels_found": found,
            "levels_total": len(levels),
        }
    )

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "audit_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    with (OUT / "audit_lines.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    with (OUT / "level_mapping.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(mapping[0].keys()))
        writer.writeheader()
        writer.writerows(mapping)

    # stratified 300-line selection for content markup
    selected = set()
    # ~200: six continuous windows over the corpus (33 lines each)
    windows = [(1, 33), (148, 180), (340, 372), (480, 512), (620, 652), (830, 862)]
    for a, b in windows:
        selected.update(range(a, b + 1))
    window_ids = sorted(selected)
    # 50: lines around the mapped game levels (line itself ±2)
    around = set()
    for m in mapping:
        if m["corpus_line"]:
            n = int(m["corpus_line"])
            around.update(range(max(1, n - 2), min(total, n + 2) + 1))
    # 50: deterministic random from the rest
    rng = random.Random(args.seed)
    rest = [n for n in range(1, total + 1) if n not in selected | around]
    random_ids = sorted(rng.sample(rest, min(50, len(rest))))
    # union, capped at 300 unique ids preferring windows, then around, then random
    final = list(dict.fromkeys(window_ids + sorted(around) + random_ids))[:300]
    (OUT / "selection.json").write_text(
        json.dumps(
            {
                "seed": args.seed,
                "windows": [f"{a}-{b}" for a, b in windows],
                "window_ids": len(window_ids),
                "around_levels": len(around),
                "random": len(random_ids),
                "selected_count": len(final),
                "selected_ids": final,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2)[:3000])
    print(f"\nselected for markup: {len(final)} lines (windows={len(window_ids)}, "
          f"around={len(around)}, random={len(random_ids)})")


if __name__ == "__main__":
    main()
