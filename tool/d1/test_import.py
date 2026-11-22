#!/usr/bin/env python3
"""Regression tests for tool/import_game_data.py (no external deps).

Runs the importer on temp copies of the corpus and checks the GPT-review
requirements:
1. a successful import writes lens links (level 120, apostrophe merge),
2. strict mode: changing the game RU text afterwards makes the next import
   fail BEFORE writing, and stale links do not survive,
3. relaxed mode: the failed level is written with alignment: null,
4. arbitrary token merges are rejected (Jane + lips must not join).

Run: python3 tool/d1/test_import.py
"""

import importlib.util
import json
import shutil
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location(
    "import_game_data", REPO / "tool" / "import_game_data.py"
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def fresh_root():
    root = Path(tempfile.mkdtemp())
    # assets/scenes is intentionally not copied: the importer must never
    # create or rewrite the curated scene JSON.
    for item in (REPO / "assets").iterdir():
        if item.name == "scenes":
            continue
        if item.is_dir():
            shutil.copytree(item, root / "assets" / item.name)
        else:
            shutil.copy2(item, root / "assets" / item.name)
    tool_dir = root / "tool" / "d1"
    tool_dir.mkdir(parents=True)
    for name in ("alignment_audit.csv",):
        shutil.copy(REPO / "tool" / "d1" / name, tool_dir / name)
    return root


def read_alignment(root, level_id):
    levels = json.loads((root / "assets" / "corpus" / "levels.json").read_text(
        encoding="utf-8"))
    lv = next(l for l in levels if l["id"] == level_id)
    return lv.get("alignment")


def check(name, condition):
    if condition:
        print(f"PASS {name}")
    else:
        print(f"FAIL {name}")
        sys.exit(1)


# 1. happy path: strict import succeeds and writes lens links
root = fresh_root()
report = mod.run_import(root, strict=True)
l120 = read_alignment(root, 120)
links = [tuple(l.values()) for l in l120["links"]] if l120 else []
check("120 gets lens links after strict import", (0, 1) in links or any(
    l[0] == 0 and l[1] == 1 for l in links))
check("140 story-only level created", any(
    l["id"] == 140 and l.get("storyOnly") for l in json.loads(
        (root / "assets" / "corpus" / "levels.json").read_text(encoding="utf-8"))))
check("no scene file written by importer",
      not (root / "assets" / "scenes" / "rocket_summer_01.json").exists())

# 2. strict mode: edited game RU text -> import fails before any write.
# The allowed outcomes are (a) hard failure with untouched files, or
# (b) relaxed write with alignment: null. A silent success that keeps the
# stale links is the forbidden third outcome.
levels_path = root / "assets" / "corpus" / "levels.json"
before_text = levels_path.read_text(encoding="utf-8")
levels = json.loads(before_text)
for lv in levels:
    if lv["id"] == 120:
        lv["russian"] = "Совсем другой перевод ."
levels_path.write_text(json.dumps(levels, ensure_ascii=False, indent=2),
                       encoding="utf-8")
try:
    mod.run_import(root, strict=True)
    check("strict import fails on edited RU", False)
except SystemExit as e:
    check("strict import fails on edited RU", "STRICT" in str(e))
check("strict failure leaves game files untouched",
      levels_path.read_text(encoding="utf-8") ==
      json.dumps(levels, ensure_ascii=False, indent=2))

# 3. relaxed mode: failed level written with alignment null, others keep links
root2 = fresh_root()
levels2_path = root2 / "assets" / "corpus" / "levels.json"
levels2 = json.loads(levels2_path.read_text(encoding="utf-8"))
for lv in levels2:
    if lv["id"] == 120:
        lv["russian"] = "Совсем другой перевод ."
levels2_path.write_text(json.dumps(levels2, ensure_ascii=False, indent=2),
                        encoding="utf-8")
report2 = mod.run_import(root2, strict=False)
check("relaxed: 120 written with null alignment",
      read_alignment(root2, 120) is None)
check("relaxed: 101 keeps confirmed links",
      (read_alignment(root2, 101) or {}).get("links"))
check("relaxed report mentions the skip",
      any(s["level"] == 120 for s in report2["skipped_levels"]))

# 4. arbitrary merges rejected
bad_map = mod.build_corpus_map(
    ["watched", "the", "doors"], ["watched", "the", "doors", "extra"])
check("token count mismatch rejected", bad_map[0] is None)
good_map, good_err = mod.build_corpus_map(
    ["Jane", "'", "s", "lips"], ["Jane's", "lips"])
check("documented apostrophe merge works", good_map == {1: 0, 2: 0, 3: 0, 4: 1})
pair_merge = mod.build_corpus_map(
    ["watched", "doors"], ["watched", "the", "doors"])
check("plain word joins rejected", pair_merge[0] is None)

print("ALL IMPORT TESTS PASSED")
