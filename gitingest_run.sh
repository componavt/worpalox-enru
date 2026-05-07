#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$ROOT/output/ai_concat"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$OUT_DIR"

last_num="$(
  find "$OUT_DIR" -maxdepth 1 -type f -name 'concat_*.txt' \
    | sed -E 's|.*/concat_([0-9]+)\.txt|\1|' \
    | sort -n \
    | tail -n 1
)"

if [[ -z "${last_num:-}" ]]; then
  next_num=1
else
  next_num=$((10#$last_num + 1))
fi

OUT_FILE="$(printf '%s/concat_%02d.txt' "$OUT_DIR" "$next_num")"

rsync -a --relative \
  "$ROOT/LICENSE" \
  "$ROOT/README.md" \
  "$ROOT/analysis_options.yaml" \
  "$ROOT/pubspec.yaml" \
  "$ROOT/pubspec.lock" \
  "$ROOT/android/" \
  "$ROOT/lib/" \
  "$ROOT/test/" \
  "$ROOT/assets/corpus/levels.json" \
  "$TMP_DIR/"

gitingest "$TMP_DIR" -o "$OUT_FILE"

printf '%s\n' "$(basename "$OUT_FILE")" > "$OUT_DIR/latest.txt"

echo "Created: $OUT_FILE"
echo "Latest:  $OUT_DIR/latest.txt"
