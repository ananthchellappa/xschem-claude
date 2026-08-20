#!/bin/bash
# homeguard.sh — DRIVER-OWNED. Snapshot the user's ~/.xschem config files before
# an item runs, and diff them after.
#
# Why this exists: two consecutive items wrote to the user's real config dir.
# Item 4 truncated ~/.xschem/raw_history (no .bak — unrecoverable). Item 5
# pushed ten scratch paths through ~/.xschem/recent_files, whose list is capped
# at 10, wiping every real entry; it was repaired from a .bak that was five
# weeks stale, so five weeks of entries are gone. Both times the crew's prose
# rule was in place and both times it was not enough, because
# `::update_recent_files` ungates FIVE writers across two files, not one:
#   src/xschem.tcl:3872 :3896 :3916   (update_recent_file / write_recent_file)
#   src/wave_viewer.tcl:8283 :8315    (rawhist_push / rawhist_write)
# A prose rule that names one of them is a rule that fails on the other four.
#
# Only the small config FILES are copied. simulations/, SANDBOX/, TEST/ and
# xschem_library/ are excluded — 91 MB, and none of it is what gets clobbered.
#
#   homeguard.sh snap <tag>    # take a reference copy
#   homeguard.sh check <tag>   # diff the live dir against it; rc 1 if anything moved
#   homeguard.sh restore <tag> # put the reference copy back (asks nothing — driver only)
#   homeguard.sh list

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
STORE="$HERE/homeguard"
SRC="$HOME/.xschem"

files() { find "$SRC" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort; }

case "${1:-}" in
  snap)
    tag=${2:?tag required}; d="$STORE/$tag"; mkdir -p "$d"
    n=0; while IFS= read -r f; do cp -p "$SRC/$f" "$d/$f" && n=$((n+1)); done < <(files)
    ( cd "$d" && md5sum * > .md5 2>/dev/null )
    echo "snap $tag: $n file(s) -> $d"
    ;;
  check)
    tag=${2:?tag required}; d="$STORE/$tag"
    [ -d "$d" ] || { echo "no such snap: $tag" >&2; exit 2; }
    rc=0
    while IFS= read -r f; do
      if [ ! -e "$d/$f" ]; then echo "APPEARED | $f"; rc=1
      elif ! cmp -s "$SRC/$f" "$d/$f"; then
        echo "CHANGED  | $f ($(stat -c%s "$d/$f") -> $(stat -c%s "$SRC/$f") bytes)"; rc=1
      fi
    done < <(files)
    while IFS= read -r f; do
      [ "$f" = ".md5" ] && continue
      [ -e "$SRC/$f" ] || { echo "VANISHED | $f"; rc=1; }
    done < <(cd "$d" && ls -A)
    [ $rc -eq 0 ] && echo "OK       | ~/.xschem unchanged since snap $tag"
    exit $rc
    ;;
  restore)
    tag=${2:?tag required}; d="$STORE/$tag"
    [ -d "$d" ] || { echo "no such snap: $tag" >&2; exit 2; }
    for f in "$d"/*; do [ -f "$f" ] && cp -p "$f" "$SRC/$(basename "$f")"; done
    echo "restored ~/.xschem from snap $tag"
    ;;
  list) ls -1 "$STORE" 2>/dev/null || echo "(no snaps)" ;;
  *) sed -n '2,25p' "$0"; exit 2 ;;
esac
