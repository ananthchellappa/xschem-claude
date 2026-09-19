#!/bin/bash
# lookshot.sh — pose xschem with a script, photograph one window, kill it.
#
# The serial capture driver behind the look-debt digest.  A look debt is paid by
# the user's eyes; this only makes the pixels EXIST so they have something to
# look at without rebuilding each setup by hand.
#
#   lookshot.sh out.png pose.tcl [-name SUBSTR] [-timeout SEC] [-settle MS] [-args ...]
#
# The pose script must leave the window UP: end it with `vwait forever` (or any
# blocking wait).  This driver, not the script, decides when the picture is
# taken and then kills xschem — which is what lets a MODAL dialog be captured at
# all: a modal blocks its own script, so a script that photographs itself can
# never photograph one.
#
# -name defaults to xschem's own main window.  Poll-until-it-appears rather than
# sleep-and-hope: a dialog that takes 3 s on a loaded box and 0.2 s on an idle
# one otherwise yields a photograph of the wrong thing, silently.
#
# Display: $LOOK_DISPLAY, default :99 (the persistent dev display).  NEVER the
# inherited $DISPLAY — on this box that is the user's real screen (CLAUDE.md,
# the three-X-servers table).
#
# HOME: a THROWAWAY one, deleted at exit (tests/headless/test_home.sh; DECISIONS
# D17.1). Measured unarmed by the round-2 safety refuter: the posed xschem
# evicted a saved window position from ~/.xschem/geometry, and winshot.sh built
# its binary into ~/.cache/xschem-winshot. The first now lands in the throwaway;
# winshot.sh builds into the checkout's gitignored tests/headless/.winshot-cache/
# (D20.3), so its build no longer follows HOME at all. XSCHEM_TEST_HOME=real
# opts out, loudly.
set -u
here=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
. "$here/test_home.sh"
test_home_arm || exit $?
repo=$(cd -- "$here/../.." && pwd)
out=${1:-} ; pose=${2:-} ; shift 2 || true
name=xschem ; timeout=25 ; settle=400 ; extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    -name)    name=$2 ; shift 2 ;;
    -timeout) timeout=$2 ; shift 2 ;;
    -settle)  settle=$2 ; shift 2 ;;
    -args)    shift ; extra=("$@") ; break ;;
    *) echo "lookshot.sh: unknown option $1" >&2 ; exit 1 ;;
  esac
done
[ -n "$out" ] && [ -n "$pose" ] || { echo "usage: lookshot.sh out.png pose.tcl [-name SUB] [-timeout SEC] [-settle MS]" >&2; exit 1; }
[ -f "$pose" ] || { echo "lookshot.sh: no such pose script: $pose" >&2; exit 1; }
[ -x "$repo/src/xschem" ] || { echo "lookshot.sh: no built binary at $repo/src/xschem" >&2; exit 1; }

dpy=${LOOK_DISPLAY:-:99}
log=$(mktemp -t lookshot.XXXXXX)
# --nolog: the user's live action log is /tmp/Xschem.log.* and --logdir would
# tread on it (issue 1359).  A path to the binary, never a bare `xschem` (0924).
DISPLAY="$dpy" "$repo/src/xschem" --nolog -q --script "$pose" "${extra[@]+"${extra[@]}"}" >"$log" 2>&1 &
pid=$!

rc=2 ; waited=0
while [ "$waited" -lt "$((timeout * 4))" ]; do
  if ! kill -0 "$pid" 2>/dev/null; then
    # xschem exited before we got the picture: a pose script that forgot to
    # block, or an error.  Say which — a zero-byte PNG explains nothing.
    echo "lookshot.sh: xschem exited early (rc unknown); tail of its output:" >&2
    tail -5 "$log" >&2
    rm -f "$log" ; exit 3
  fi
  if DISPLAY="$dpy" "$here/winshot.sh" "$out" -name "$name" -raise -settle "$settle" 2>/dev/null; then
    rc=0 ; break
  fi
  sleep 0.25 ; waited=$((waited + 1))
done

kill "$pid" 2>/dev/null ; sleep 0.3 ; kill -9 "$pid" 2>/dev/null ; wait "$pid" 2>/dev/null
if [ "$rc" -ne 0 ]; then
  echo "lookshot.sh: no window matching \"$name\" within ${timeout}s; tail of xschem output:" >&2
  tail -8 "$log" >&2
fi
rm -f "$log"
exit "$rc"
