#!/usr/bin/env python3
from pathlib import Path
from typing import Optional, Tuple, List
import fnmatch
import re

ROOT = Path(__file__).resolve().parent
OUT_DIR = ROOT / "output" / "ai_concat"
CONFIG_FILE = ROOT / "gitingest_files.txt"
LATEST_FILE = OUT_DIR / "latest.txt"

Rule = Tuple[str, str, Optional[int]]
SelectedFile = Tuple[Path, Optional[int]]


def next_output_file(out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)

    pattern = re.compile(r"^concat_(\d+)\.txt$")
    numbers = []

    for path in out_dir.glob("concat_*.txt"):
        match = pattern.match(path.name)
        if match:
            numbers.append(int(match.group(1)))

    next_number = max(numbers, default=0) + 1
    return out_dir / "concat_{:02d}.txt".format(next_number)


def parse_config_line(line: str) -> Optional[Rule]:
    line = line.strip()

    if not line or line.startswith("#"):
        return None

    if line.startswith("-"):
        pattern = line[1:].strip()
        if not pattern:
            return None
        return ("exclude", pattern, None)

    if "|" in line:
        pattern, limit_str = line.rsplit("|", 1)
        pattern = pattern.strip()
        limit_str = limit_str.strip()

        if not pattern:
            raise ValueError("Empty pattern in config line: {!r}".format(line))
        if not limit_str.isdigit():
            raise ValueError("Invalid truncation limit in config line: {!r}".format(line))

        return ("truncate", pattern, int(limit_str))

    return ("include", line, None)


def load_rules(config_file: Path) -> List[Rule]:
    if not config_file.exists():
        raise FileNotFoundError("Config file not found: {}".format(config_file))

    rules = []
    for raw_line in config_file.read_text(encoding="utf-8").splitlines():
        parsed = parse_config_line(raw_line)
        if parsed is not None:
            rules.append(parsed)

    return rules


def matches_pattern(rel_path: Path, pattern: str) -> bool:
    rel_str = rel_path.as_posix()
    name = rel_path.name

    if pattern.endswith("/"):
        prefix = pattern.rstrip("/")
        return rel_str == prefix or rel_str.startswith(prefix + "/")

    if "/" in pattern:
        return fnmatch.fnmatchcase(rel_str, pattern)

    return fnmatch.fnmatchcase(name, pattern)


def collect_all_files(root: Path) -> List[Path]:
    files = []
    for path in root.rglob("*"):
        if path.is_file():
            files.append(path)
    return sorted(files, key=lambda p: p.relative_to(root).as_posix())


def resolve_files(root: Path, rules: List[Rule]) -> List[SelectedFile]:
    selected = []

    for path in collect_all_files(root):
        rel = path.relative_to(root)
        decision = None

        for action, pattern, limit in rules:
            if matches_pattern(rel, pattern):
                decision = (action, limit)

        if decision is None:
            continue

        action, limit = decision
        if action == "exclude":
            continue

        if action == "include":
            selected.append((path, None))
        elif action == "truncate":
            selected.append((path, limit))

    return selected


def read_with_optional_truncation(path: Path, limit: Optional[int]) -> Tuple[str, bool]:
    text = path.read_text(encoding="utf-8", errors="replace")
    truncated = False

    if limit is not None and len(text) > limit:
        text = text[:limit]
        truncated = True

    return text, truncated


def write_output(out_file: Path, files: List[SelectedFile]) -> None:
    with out_file.open("w", encoding="utf-8") as out:
        out.write("# AI CONCAT FILE\n")
        out.write("# OUTPUT: {}\n".format(out_file.relative_to(ROOT)))
        out.write("# CONFIG: {}\n".format(CONFIG_FILE.relative_to(ROOT)))
        out.write("# FILE COUNT: {}\n".format(len(files)))
        out.write("#\n")
        out.write("# Included files:\n")

        for path, limit in files:
            rel = path.relative_to(ROOT)
            if limit is None:
                out.write("# - {}\n".format(rel))
            else:
                out.write("# - {} (first {} characters)\n".format(rel, limit))

        out.write("\n")

        for path, limit in files:
            rel = path.relative_to(ROOT)
            text, truncated = read_with_optional_truncation(path, limit)

            out.write("\n" + "#" * 60 + "\n")
            out.write("# FILE: {}\n".format(rel))
            if limit is not None:
                note = "# NOTE: first {} characters only".format(limit)
                if truncated:
                    note += " (truncated)"
                out.write(note + "\n")
            out.write("#" * 60 + "\n\n")

            out.write(text)
            if not text.endswith("\n"):
                out.write("\n")


def main() -> None:
    rules = load_rules(CONFIG_FILE)
    files = resolve_files(ROOT, rules)
    out_file = next_output_file(OUT_DIR)

    write_output(out_file, files)
    LATEST_FILE.write_text(out_file.name + "\n", encoding="utf-8")

    print("Created:", out_file)
    print("Latest:", LATEST_FILE)
    print("Files included:", len(files))


if __name__ == "__main__":
    main()
