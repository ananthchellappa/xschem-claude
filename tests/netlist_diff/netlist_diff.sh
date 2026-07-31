#!/bin/bash
# netlist_diff.sh -- prove a change is byte-identical on the shipped libraries.
#
# Netlists every schematic under a library root, in every backend, with TWO
# binaries, and diffs the results. This is the evidence that cleared issues 0163
# and 0164 and, most recently, 0165's ERC warning -- and it had to be rebuilt
# from scratch each time because nobody committed it. Now it is committed.
#
# Usage:
#   tests/netlist_diff/netlist_diff.sh <old-binary> [<new-binary>]
#
#   <old-binary>   a TRUE pre-change build -- see "Building the old binary" below
#   <new-binary>   defaults to ./src/xschem
#
# Environment:
#   LIBROOT   library root to walk   (default <repo>/xschem_library)
#   FORMATS   backends               (default "spice spectre verilog vhdl tedax")
#   KEEP=1    keep the two output trees instead of deleting them
#
# Exit status: 0 = identical, 1 = differences, 2 = usage/setup error.
#
# ---------------------------------------------------------------------------
# THE THREE TRAPS, all paid for at least once already
#
# 1. RUN BOTH BINARIES BACK TO BACK, which is why this is one script and not two
#    invocations a day apart. xschem writes gitignored `<cell>~.sch` autosave
#    files while descending, and xschem_library/examples/*.sch globs them as
#    tops -- a stale one once produced a spurious `Q1~.spice` diff that looked
#    exactly like a behaviour change.
#
# 2. THE OUTPUT DIRECTORY IS EMBEDDED IN THE NETLIST. `.include` lines carry the
#    absolute path of the netlist dir, so two runs into different directories
#    differ on those lines and nothing else. This script normalises the path
#    before diffing; a hand-rolled `diff -r` will report false positives
#    (measured: 4 of 920 files, all of them a single `.include` line).
#
# 3. `git stash push src/<file>` ON A CLEAN TREE STASHES NOTHING, so a "pre-fix"
#    binary built that way is the fixed one and the diff is vacuously clean.
#
# Building the old binary, the way that actually works:
#
#     cp src/token.c src/hilight.c /tmp/keep/          # whatever you changed
#     git checkout HEAD -- src/token.c src/hilight.c   # or a specific <sha>
#     ( cd src && make ) && cp src/xschem /tmp/xschem_prefix
#     cp /tmp/keep/*.c src/ && ( cd src && make )      # restore
#
# Then VERIFY it is really the old one -- run your new test against it and
# confirm it FAILS. A binary copied out of the tree needs XSCHEM_SHAREDIR:
#
#     XSCHEM_SHAREDIR=$PWD/src /tmp/xschem_prefix --nogui --pipe -q --nolog --script <t>
#
# ---------------------------------------------------------------------------
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

OLD="${1:-}"
NEW="${2:-$REPO/src/xschem}"

if [ -z "$OLD" ]; then
  sed -n '2,20p' "$0"
  exit 2
fi
for b in "$OLD" "$NEW"; do
  if [ ! -x "$b" ]; then echo "netlist_diff: not executable: $b" >&2; exit 2; fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/netlist_diff.XXXXXX")"
cleanup() { if [ "${KEEP:-0}" != "1" ]; then rm -rf "$WORK"; else echo "kept: $WORK"; fi; }
trap cleanup EXIT

run_arm() {          # $1 = binary, $2 = arm name
  local bin="$1" arm="$2"
  echo "### arm '$arm': $bin"
  OUTDIR="$WORK/nl_$arm" \
  LIBROOT="${LIBROOT:-$REPO/xschem_library}" \
  FORMATS="${FORMATS:-spice spectre verilog vhdl tedax}" \
  XSCHEM_SHAREDIR="$REPO/src" \
    "$bin" --nogui --pipe -q --nolog --script "$HERE/sweep.tcl" 2>&1 \
    | grep -E '^(sweep|ERR)' || true
}

# Trap 1: back to back, in this order, in one process lifetime of the script.
run_arm "$OLD" old
run_arm "$NEW" new

# Trap 2: strip the absolute output dir before comparing.
for arm in old new; do
  mkdir -p "$WORK/norm_$arm"
  for f in "$WORK/nl_$arm"/*; do
    [ -f "$f" ] || continue
    sed "s|$WORK/nl_$arm|OUTDIR|g" "$f" > "$WORK/norm_$arm/$(basename "$f")"
  done
done

n_old=$(ls -1 "$WORK/norm_old" 2>/dev/null | wc -l)
n_new=$(ls -1 "$WORK/norm_new" 2>/dev/null | wc -l)
echo "### comparing $n_old vs $n_new generated netlists"

if diff -rq "$WORK/norm_old" "$WORK/norm_new"; then
  echo "RESULT: BYTE-IDENTICAL ($n_new netlists)"
  exit 0
else
  echo "RESULT: DIFFERENCES FOUND -- inspect with KEEP=1 and"
  echo "        diff -r \$WORK/norm_old \$WORK/norm_new"
  exit 1
fi
