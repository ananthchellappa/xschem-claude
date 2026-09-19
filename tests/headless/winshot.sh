#!/bin/bash
# winshot.sh — compile-on-demand front end for winshot.c (grab an X window to PNG).
#
# This box has NO screenshot tool: no import(1), no xwd, no scrot, no ffmpeg,
# no PIL, no Tk Img.  xschem can export its own canvas (`xschem print png`) but
# nothing in the tree could photograph a Tk DIALOG, which is what most of the
# owed-ledger's `look` debts are actually about.  See the header of winshot.c.
#
# The binary is built into a cache INSIDE THE CHECKOUT, tests/headless/.winshot-cache/,
# which .gitignore lists (so nothing to commit, no src/Makefile.in edit, no
# ./configure re-run -- see CLAUDE.md issue 0424 on why adding a file to src/ is
# not free).  It rebuilds whenever the .c is newer.
#
# ⚠ NOT ~/.cache (doc/claude/outsider_fixes_batch, DECISIONS D20.3). It used to
# build into $HOME/.cache/xschem-winshot, so this documented command, run on its
# own, wrote build.log and a 21 KB binary into the tester's real home (the
# round-3 safety refuter, on an empty home). The checkout is the build's home.
# Where the checkout cannot be written (a read-only tree), the binary is built
# into a temporary directory for this one call and deleted after.
# XSCHEM_WINSHOT_CACHE=<dir> still names a cache of your own.
#
#   winshot.sh out.png -name "Results" -raise      # by WM_NAME substring
#   winshot.sh out.png -id 0x2400007               # by window id
#   winshot.sh out.png -root                       # whole screen
#   DISPLAY=:99 winshot.sh out.png -name xschem    # any display
#
# Exit codes come straight from winshot: 0 ok, 2 no such window, 3 X error,
# 4 write error, 1 usage, 5 build failure.
set -u
here=$(cd -- "$(dirname -- "$0")" && pwd)
cache="${XSCHEM_WINSHOT_CACHE:-$here/.winshot-cache}"
src="$here/winshot.c"
[ -f "$src" ] || { echo "winshot.sh: missing $src" >&2; exit 5; }
once=""
if ! mkdir -p "$cache" 2>/dev/null || [ ! -w "$cache" ]; then
  once=$(mktemp -d "${TMPDIR:-/tmp}/xschem-winshot.XXXXXX") || { echo "winshot.sh: no writable build directory" >&2; exit 5; }
  cache="$once"
fi
bin="$cache/winshot"
if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
  # Built under a temporary name and moved into place: two concurrent callers
  # (two lookshots) must never exec a half-written binary.
  if ! cc -O2 -Wall -o "$bin.$$" "$src" -lX11 -lpng -lz 2>"$cache/build.log"; then
    echo "winshot.sh: build failed, see $cache/build.log" >&2
    sed -n '1,20p' "$cache/build.log" >&2
    rm -f "$bin.$$"
    [ -z "$once" ] || rm -rf "$once"
    exit 5
  fi
  mv -f "$bin.$$" "$bin" || { rm -f "$bin.$$"; exit 5; }
fi
if [ -z "$once" ]; then exec "$bin" "$@"; fi
"$bin" "$@"; rc=$?
rm -rf "$once"
exit "$rc"
