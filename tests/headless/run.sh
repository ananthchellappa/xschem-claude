#!/bin/sh
#
# File: run.sh
# Reusable headless repro/test harness for xschem.
#
# Loads each schematic in cases.txt hermetically (no dependence on the user's
# ~/.xschem environment), netlists it, normalizes the output to remove
# machine-specific noise, and diffs against a committed golden baseline.
#
# Usage:
#   ./run.sh                 run all cases, diff against gold/, exit nonzero on mismatch
#   ./run.sh --update-gold   capture current normalized output as the new baseline
#   ./run.sh --script FILE    run an arbitrary driver .tcl instead of harness.tcl
#                             (ad-hoc repro mode; skips golden comparison)
#
# Requires the binary at src/xschem (build with: cd src && make).

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
export REPO
XSCHEM="$REPO/src/xschem"

RESULTS="$HERE/results"
NETLISTS="$RESULTS/netlists"
NORM="$RESULTS/normalized"
GOLD="$HERE/gold"
CASES_FILE="$HERE/cases.txt"
export CASES_FILE

UPDATE_GOLD=0
DRIVER="$HERE/harness.tcl"
AD_HOC=0
while [ $# -gt 0 ]; do
  case "$1" in
    --update-gold) UPDATE_GOLD=1 ;;
    --script) shift; DRIVER="$1"; AD_HOC=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ ! -x "$XSCHEM" ]; then
  echo "FATAL: $XSCHEM not found or not executable." >&2
  echo "       Build it first:  (cd $REPO/src && make)" >&2
  exit 3
fi

# Normalize a netlist/state file in place: strip machine-specific noise so the
# golden comparison is portable and deterministic.
#   - drop absolute path comment lines the netlister embeds (sch_path/sym_path)
#   - replace any remaining repo-root occurrences with the @REPO@ token
normalize() {
  # $1 = input file, $2 = output file
  sed -e '/ sch_path: /d' \
      -e '/ sym_path: /d' \
      -e "s#$REPO#@REPO@#g" \
      "$1" > "$2"
}

rm -rf "$RESULTS"
mkdir -p "$NETLISTS" "$NORM"

echo "== running headless harness =="
echo "   binary: $XSCHEM"
echo "   driver: $DRIVER"

# Run xschem headless. Pin the netlist dir, use the hermetic rcfile, quit after.
set +e
REPO="$REPO" CASES_FILE="$CASES_FILE" \
  "$XSCHEM" --no_x --rcfile "$HERE/minrc" --netlist_path "$NETLISTS" \
            --pipe -q --script "$DRIVER" \
            > "$RESULTS/state.txt" 2> "$RESULTS/stderr.log"
rc=$?
set -e

if [ $rc -ne 0 ]; then
  echo "FATAL: xschem exited with status $rc" >&2
  echo "----- stderr (tail) -----" >&2
  tail -20 "$RESULTS/stderr.log" >&2
  exit 4
fi

# Surface any in-script errors the harness reported.
if grep -q "ERROR " "$RESULTS/state.txt"; then
  echo "WARNING: harness reported case errors:"
  grep -n "ERROR \|EMPTY!" "$RESULTS/state.txt" || true
fi

# Build the normalized artifact set: the state report plus every netlist.
normalize "$RESULTS/state.txt" "$NORM/state.txt"
for nl in "$NETLISTS"/*; do
  [ -e "$nl" ] || continue
  normalize "$nl" "$NORM/$(basename "$nl")"
done

if [ "$AD_HOC" -eq 1 ]; then
  echo "== ad-hoc run complete (no golden comparison) =="
  echo "   state:    $RESULTS/state.txt"
  echo "   netlists: $NETLISTS/"
  cat "$RESULTS/state.txt"
  exit 0
fi

if [ "$UPDATE_GOLD" -eq 1 ]; then
  rm -rf "$GOLD"
  mkdir -p "$GOLD"
  cp "$NORM"/* "$GOLD"/
  echo "== gold baseline updated ($(ls "$GOLD" | wc -l | tr -d ' ') files) =="
  exit 0
fi

if [ ! -d "$GOLD" ]; then
  echo "FATAL: no gold baseline at $GOLD" >&2
  echo "       Capture one first:  ./run.sh --update-gold" >&2
  exit 5
fi

# Compare normalized output against the baseline.
fail=0
for g in "$GOLD"/*; do
  base=$(basename "$g")
  if [ ! -f "$NORM/$base" ]; then
    echo "FAIL  $base: missing from results"
    fail=1
    continue
  fi
  if diff -u "$g" "$NORM/$base" > "$RESULTS/$base.diff"; then
    echo "PASS  $base"
  else
    echo "FAIL  $base (see results/$base.diff)"
    fail=1
  fi
done
# Flag brand-new artifacts not yet in gold.
for n in "$NORM"/*; do
  base=$(basename "$n")
  [ -f "$GOLD/$base" ] || { echo "NEW   $base (not in gold; run --update-gold to adopt)"; fail=1; }
done

if [ "$fail" -ne 0 ]; then
  echo "== HARNESS: FAIL =="
  exit 1
fi
echo "== HARNESS: PASS =="
