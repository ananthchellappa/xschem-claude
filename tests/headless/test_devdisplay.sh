#!/bin/bash
# test_devdisplay.sh — the persistent dev display, its arm attach path, and the
# gate exclusion that keeps it from breaking Pause.
#
# Spec: doc/claude/specs/dev_display.md  (D1..D13 below are its §5 test plan)
#
# Runs entirely against a THROWAWAY display number and a temp state dir, so it
# can never disturb a real dev display -- including the one it may itself be
# running on.
#
#   tests/headless/test_devdisplay.sh
#   tests/headless/run_suites.sh test_devdisplay        # also works
#
# DEVDISPLAY_TEST_NUMS / DEVDISPLAY_TEST_FOREIGN_NUMS (space lists) move the
# display numbers it may take (default 96..89 and 88..85; :99 is never taken).
#
# ROUND 4 (DECISIONS D20.1/D20.2) added, each red on the round-3 build or under
# the round-3 regression refuter's sabotage it names: D17c/D17d (the orphan sweep
# kills only on the display its dir recorded), D19 (argv[0] identity; S1), D20
# (the lock says whose a live server is; S3), D21 (a dead xvfb.pid means `stop`
# kills nothing) and D22 (a WM is identified by DISPLAY and HOME, not its name).
# The decoys are `perl -e 'sleep 300'` under the name being impersonated; the
# rows skip, loudly, where there is no perl.
#
# This suite deliberately does NOT arm its DISPLAY: it manages X displays, so it
# must be the thing deciding which ones exist.
#
# Its HOME IS armed (DECISIONS D13.1): the dev display it starts runs openbox and
# a GUI xschem, and round 1 measured this file creating ~/.cache/openbox and
# rewriting ~/.xschem/geometry in the tester's real home. Its state dir was
# always its own temp dir (XSCHEM_DEVDISPLAY_DIR below), never
# ~/.claude/xschem_dev_display.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
DD="$HERE/devdisplay.sh"
# shellcheck source=/dev/null
. "$HERE/test_home.sh"
test_home_arm || exit $?
. "$HERE/spawn_reaper.sh"

# BEFORE a display number is chosen: a run of THIS FILE that was SIGKILLed
# leaves its `Xvfb :95 -screen 0 1920x1080x24` and its openbox serving, and the
# number taken -- that pair, alive for a day, is half of what item 14 was raised
# about, and no trap can cover a SIGKILL. The sweep reclaims only a state dir
# whose `.reaper_owner` stamp names a run that is provably dead, and kills only
# the pids that run itself recorded in that dir. A concurrent run's dir is
# stamped alive and is never touched; the persistent dev display's state dir is
# ~/.claude/xschem_dev_display, which this glob cannot reach.
reaper_sweep_orphan_runs "${TMPDIR:-/tmp}/devdisplay_test.*" xvfb.pid wm.pid vnc.pid

pass=0; fail=0; skip=0
ck() {  # ck <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "ok:   $1"; pass=$((pass+1))
  else
    echo "FAIL: $1 -> {$3} (exp {$2})"; fail=$((fail+1))
  fi
}
note() { echo "--    $*"; }
skipck() { echo "skip: $*"; skip=$((skip+1)); }

# --- a display number nothing else is using ---------------------------------
# DEVDISPLAY_TEST_NUMS / DEVDISPLAY_TEST_FOREIGN_NUMS move the two candidate
# lists (default 96..89 and 88..85) -- so that a run can be kept on numbers
# assigned to it, and never on :99.
_NUMS="${DEVDISPLAY_TEST_NUMS:-96 95 94 93 92 91 90 89}"
_FNUMS="${DEVDISPLAY_TEST_FOREIGN_NUMS:-88 87 86 85}"
_free_num() {
  local n
  for n in $_NUMS; do
    case "$n" in ''|*[!0-9]*|99) continue ;; esac
    [ -S "/tmp/.X11-unix/X$n" ] && continue
    ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$n\b" && continue
    [ -e "/tmp/.X$n-lock" ] && continue
    echo "$n"; return 0
  done
  return 1
}
NUM=$(_free_num) || { echo "RESULT: FAIL (no free display number in: $_NUMS)"; exit 1; }
FOREIGN=$(for n in $_FNUMS; do
            case "$n" in ''|*[!0-9]*|99|"$NUM") continue ;; esac
            [ -S "/tmp/.X11-unix/X$n" ] && continue
            ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$n\b" && continue
            [ -e "/tmp/.X$n-lock" ] && continue
            echo "$n"; break; done)

STATE=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_test.XXXXXX")
EMPTY=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_empty.XXXXXX")
export XSCHEM_DEVDISPLAY_DIR="$STATE"
export DEVDISPLAY_NUM="$NUM"
# Claim this state dir for THIS run, so that a run which never reaches its
# teardown can be identified as dead by the next one (and, equally, so that a
# concurrent run is identified as ALIVE and left alone).
reaper_mark_owner "$STATE"
# ...and the display it is about to take, BEFORE devdisplay.sh has written its
# own `display` record: the orphan sweep kills a recorded pid only on the display
# its dir recorded (DECISIONS D20.2), and a run killed inside `start` would
# otherwise leave a dir that names none.
echo ":$NUM" > "$STATE/.reaper_display"

# A DECOY: a process that merely LOOKS like something -- argv[0] <argv0>, the
# given words after it, and the given environment -- and is really `perl -e
# 'sleep 300' -- <words>`, one process that dies cleanly on any signal (a bash wrapper would
# leave its `sleep` child behind when killed -9). The identity rows below plant
# them wherever a state dir names a pid; every one is killed in _cleanup.
#   _decoy <argv0> [NAME=value ...] -- [word ...]   -> its pid in $DECOY
DECOYS=""
HAVE_PERL=0; command -v perl >/dev/null 2>&1 && HAVE_PERL=1
_decoy() {
  local a0="$1"; shift
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do envs+=("$1"); shift; done
  [ "${1:-}" = -- ] && shift
  env ${envs[@]+"${envs[@]}"} bash -c 'a0=$1; shift; exec -a "$a0" perl -e "sleep 300" -- "$@"' _ "$a0" "$@" \
    </dev/null >/dev/null 2>&1 &
  DECOY=$!
  DECOYS="$DECOYS $DECOY"
}
_alive() { [ -d "/proc/$1" ] && ! grep -q '^State:.*Z' "/proc/$1/status" 2>/dev/null && echo 1 || echo 0; }

# THIS SUITE STARTS AN X SERVER AND A WINDOW MANAGER, so it tears them down --
# and not only through `$DD stop`. The strays that produced item 14 were an
# `Xvfb :95 -screen 0 1920x1080x24` and its `openbox`, alive for a day: that is
# this file's shape exactly (devdisplay.sh's default screen and WM, no `-auth`,
# and :95 is the second number _free_num picks). `$DD stop` is the right call and
# usually works, but it goes through several liveness predicates and a state dir
# that a half-finished run may have left inconsistent, so the pids are recorded
# as they appear and killed directly as a backstop.
#
# NOTHING IS KILLED OR UNLOCKED BY NUMBER OR BY PATTERN (DECISIONS D17.6). The
# FOREIGN server of D11 was stopped with `pkill -f "Xvfb [:]<n>"`, which kills
# ANY process whose command line merely contains that text, and both X locks
# were removed by number -- so a concurrent run that took either number after
# this one freed it lost its lock. Now: FOREIGN is a pid this run started and
# tracks (reaper_reap_procs re-checks it in /proc before it signals), and a lock
# goes only if it still names a server this run started, which is gone.
_dd_track_pids() {   # remember whatever devdisplay.sh has started so far
  local f p
  for f in xvfb.pid wm.pid vnc.pid; do
    [ -r "$STATE/$f" ] || continue
    p=$(cat "$STATE/$f" 2>/dev/null)
    reaper_track "$p"
    [ "$f" = xvfb.pid ] && case "$p" in ''|*[!0-9]*) ;; *) OURX="$OURX $p" ;; esac
  done
  return 0
}
OURX=""   # every X server this run started (devdisplay's, and D11's FOREIGN)
_rm_our_lock() {   # <n>: remove /tmp/.X<n>-lock only if it names a server of ours that is gone
  local n="$1" lk p
  lk=$(head -c 32 "/tmp/.X$n-lock" 2>/dev/null | tr -cd 0-9)
  [ -n "$lk" ] || return 0
  for p in $OURX; do
    [ "$p" = "$lk" ] || continue
    kill -0 "$p" 2>/dev/null && return 0
    rm -f "/tmp/.X$n-lock" 2>/dev/null
    return 0
  done
  return 0
}
SWEEPPIDS=""
_cleanup() {
  local p
  XSCHEM_DEVDISPLAY_DIR="$STATE" DEVDISPLAY_NUM="$NUM" "$DD" stop >/dev/null 2>&1
  reaper_reap_procs
  for p in $SWEEPPIDS ${DECOYS:-}; do kill -9 "$p" 2>/dev/null; done
  rm -rf "$STATE" "$EMPTY" ${SWEEPDIRS:-} 2>/dev/null
  _rm_our_lock "$NUM"
  [ -n "${FOREIGN:-}" ] && _rm_our_lock "$FOREIGN"
  return 0
}
# The EXIT trap REPLACES the one test_home_arm installed, so the throwaway HOME's
# owner cleanup runs from it, last, once everything that ran under that HOME is
# down. Only on EXIT: an INT/TERM here runs _cleanup and the suite carries on,
# and it must not carry on in a deleted HOME.
trap '_cleanup; _th_cleanup' EXIT
trap _cleanup INT TERM

note "display :$NUM, state $STATE"

# --- D1: start ---------------------------------------------------------------
"$DD" start >/dev/null 2>&1
rc=$?
_dd_track_pids
ck "D1 start exits 0" 0 "$rc"
"$DD" status >/dev/null 2>&1
ck "D1 status exits 0 (alive)" 0 "$?"
ck "D1 display file written" ":$NUM" "$(cat "$STATE/display" 2>/dev/null)"
ck "D1 screen recorded" "${DEVDISPLAY_SCREEN:-1920x1080x24}" "$(cat "$STATE/screen" 2>/dev/null)"
ck "D1 server answers" 0 "$(timeout 10 xdpyinfo -display ":$NUM" >/dev/null 2>&1; echo $?)"

# --- D2: idempotence ---------------------------------------------------------
p1=$(cat "$STATE/xvfb.pid" 2>/dev/null)
"$DD" start >/dev/null 2>&1
p2=$(cat "$STATE/xvfb.pid" 2>/dev/null)
ck "D2 second start reuses the server" "$p1" "$p2"
ck "D2 exactly one Xvfb on :$NUM" 1 "$(pgrep -f "Xvfb [:]$NUM" | wc -l | tr -d ' ')"

# --- D3: the window manager --------------------------------------------------
wmname=$(cat "$STATE/wm" 2>/dev/null)
if [ "$wmname" = none ]; then
  skipck "D3 WM checks (wm=none)"
else
  id=$(xprop -display ":$NUM" -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -o '0x[0-9a-f]*' | head -1)
  ck "D3 WM claimed the screen" 1 "$([ -n "$id" ] && echo 1 || echo 0)"
  nm=$(xprop -display ":$NUM" -id "$id" _NET_WM_NAME 2>/dev/null | sed 's/.*= *//; s/"//g')
  ck "D3 WM identifies as Openbox" "Openbox" "$nm"
  # WSLg's Weston WM advertises 7. A real WM advertises ~70. The point of
  # running one at all is the difference.
  n=$(xprop -display ":$NUM" -root _NET_SUPPORTED 2>/dev/null | grep -o '_NET[A-Z_]*' | wc -l | tr -d ' ')
  ck "D3 EWMH hints far above WSLg's 7" 1 "$([ "${n:-0}" -gt 20 ] && echo 1 || echo 0)"
  note "D3 measured $n hints"
  ck "D3 iconify is honoured (not the WSLg silent no-op)" "iconic" \
     "$(DISPLAY=":$NUM" timeout 20 wish <<'EOF' 2>/dev/null
wm geometry . 200x120+40+40
update; after 300; update
wm iconify .
update; after 300; update
puts [wm state .]
exit 0
EOF
)"
fi

# --- D4: status output -------------------------------------------------------
out=$("$DD" status 2>/dev/null)
# NOT `grep -qc`: -q silences the count -q was meant to replace, so the
# substitution yields "" and the check compares against nothing.
ck "D4 status names the display" 1 "$(echo "$out" | grep -c "^display: :$NUM$")"
ck "D4 status reports alive"     1 "$(echo "$out" | grep -c '^state:   alive$')"
ck "D4 status names the screen"  1 "$(echo "$out" | grep -c '^screen:  ')"
ck "D4 status names the wm"      1 "$(echo "$out" | grep -c '^wm:      ')"

# --- D5: the arm ATTACHES ----------------------------------------------------
armout=$(unset AUDIT_DISPLAY; bash "$HERE/xvfb_arm.sh" --arm \
          sh -c 'echo "DPY=$DISPLAY GATE=${GUI_GATE:-unset}"' 2>/dev/null)
ck "D5 arm attaches to the dev display" "DPY=:$NUM GATE=0" "$armout"

# --- D6: the arm still FALLS BACK when there is no dev display ---------------
fbout=$(unset AUDIT_DISPLAY; XSCHEM_DEVDISPLAY_DIR="$EMPTY" \
          bash "$HERE/xvfb_arm.sh" --arm sh -c 'echo "$DISPLAY"' 2>/dev/null)
ck "D6 no dev display -> a display was still provided" 1 \
   "$([ -n "$fbout" ] && echo 1 || echo 0)"
ck "D6 the fallback is NOT the dev display" 1 \
   "$([ "$fbout" != ":$NUM" ] && echo 1 || echo 0)"
note "D6 fallback display was '$fbout'"
# D17.8: and it is never :99 -- the private arm hands xvfb-run `-n <base> -a`
# with a base of at least 100, where `-a` alone numbered from :99 and took the
# dev display's number whenever the dev display was down.
fbn="${fbout#:}"; fbn="${fbn%%.*}"
ck "D6 the fallback is numbered from 100 up, never :99" 1 \
   "$(case "$fbn" in ''|*[!0-9]*) echo 0 ;; *) [ "$fbn" -ge 100 ] && echo 1 || echo 0 ;; esac)"

# --- D7: an explicit AUDIT_DISPLAY still wins --------------------------------
expout=$(AUDIT_DISPLAY=:0 bash "$HERE/xvfb_arm.sh" --arm sh -c 'echo "$DISPLAY"' 2>/dev/null)
ck "D7 AUDIT_DISPLAY=:0 overrides the attach" ":0" "$expout"
noneout=$(AUDIT_DISPLAY=none bash "$HERE/xvfb_arm.sh" --arm sh -c 'echo "[${DISPLAY:-unset}]"' 2>/dev/null)
ck "D7 AUDIT_DISPLAY=none unsets DISPLAY" "[unset]" "$noneout"

# --- D8/D9: the gate exclusion, and its negative control ---------------------
gout=$(DISPLAY=":$NUM" GUI_GATE_DIR="$STATE/gate" bash -c \
        ". '$HERE/gui_gate.sh'; _gate_enabled; echo \$?" 2>/dev/null)
ck "D8 gate DISABLED on the dev display" 1 "$gout"
gout0=$(DISPLAY=":0" GUI_GATE_DIR="$STATE/gate" bash -c \
        ". '$HERE/gui_gate.sh'; _gate_enabled; echo \$?" 2>/dev/null)
ck "D9 gate ARMED on a normal display (negative control)" 0 "$gout0"

# --- D10: stale state is detected, not trusted -------------------------------
realpid=$(cat "$STATE/xvfb.pid")
echo 999999 > "$STATE/xvfb.pid"
sout=$("$DD" status 2>/dev/null | grep '^state:' | awk '{print $2}')
ck "D10 dead pid -> not reported alive" 1 "$([ "$sout" != alive ] && echo 1 || echo 0)"
note "D10 reported '$sout'"
echo "$realpid" > "$STATE/xvfb.pid"
ck "D10 restoring the real pid restores 'alive'" "alive" \
   "$("$DD" status 2>/dev/null | grep '^state:' | awk '{print $2}')"

# --- D11: a foreign display is not adopted -----------------------------------
if [ -z "${FOREIGN:-}" ]; then
  skipck "D11 (no second free display number)"
else
  Xvfb ":$FOREIGN" -screen 0 640x480x24 -nolisten tcp >/dev/null 2>&1 &
  fpid=$!
  reaper_track "$fpid"
  OURX="$OURX $fpid"
  i=0; while [ $i -lt 60 ]; do
    ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$FOREIGN\b" && break
    i=$((i+1)); sleep 0.1
  done
  XSCHEM_DEVDISPLAY_DIR="$EMPTY" DEVDISPLAY_NUM="$FOREIGN" "$DD" start >/dev/null 2>&1
  ck "D11 start refuses a foreign display" 4 "$?"
  ck "D11 and does not kill it" 1 "$(kill -0 $fpid 2>/dev/null && echo 1 || echo 0)"

  # --- D14: the WM-readiness predicate, tested DIRECTLY -------------------
  #
  # This exists because the obvious test does not work. Breaking the poll to
  # `grep -q window` -- so it matches xprop's failure text "no such atom on any
  # window." and reports the WM live before it is -- leaves the whole suite
  # GREEN, because openbox wins the race anyway on an idle machine. That is
  # precisely how the identical bug shipped in xvfb_arm.sh and survived review.
  # A hazard you cannot observe through the front door gets tested at the
  # predicate: this Xvfb has no window manager, so _wm_claimed MUST be false,
  # on every machine, every time.
  (
    NUM="$FOREIGN"; DPY=":$FOREIGN"
    . "$DD"
    NUM="$FOREIGN"; DPY=":$FOREIGN"
    _wm_claimed && exit 0 || exit 1
  )
  ck "D14 _wm_claimed is FALSE on a WM-less display" 1 "$?"
  (
    NUM="$NUM"; DPY=":$NUM"
    . "$DD"
    _wm_claimed && exit 0 || exit 1
  )
  ck "D14 _wm_claimed is TRUE on the managed one (positive control)" 0 "$?"

  kill -TERM $fpid 2>/dev/null
fi

# --- D12: end to end ---------------------------------------------------------
if [ -x "$REPO/src/xschem" ] && [ -f "$HERE/test_calc_skeleton.tcl" ]; then
  e2e=$(DISPLAY=":$NUM" GUI_GATE=0 timeout 240 "$REPO/src/xschem" \
          --pipe -q --nolog --script "$HERE/test_calc_skeleton.tcl" 2>&1 | \
          grep -c '^RESULT: ALL PASS')
  ck "D12 a real GUI suite passes on the dev display" 1 "$e2e"
else
  skipck "D12 (src/xschem not built)"
fi

# --- D15: the shell-rc snippet, both directions ------------------------------
si_up=$(DISPLAY=:0 bash -c "eval \"\$('$DD' shellinit)\"; echo \$DISPLAY" 2>/dev/null)
ck "D15 shellinit points a shell at a LIVE dev display" ":$NUM" "$si_up"

# --- D20: the LOCK says whose a live server is (DECISIONS D17.6; round 3's S3) --
#
# `_ours` requires /tmp/.X<N>-lock to name the recorded pid, and nothing locked
# that: the round-3 regression refuter removed the check (its sabotage S3) and
# every suite stayed green. The shape it guards is a recorded pid that IS an
# `Xvfb :N` by argv -- a server that lost the race for :N, or a recycled pid --
# while a DIFFERENT server answers on :N. Here that server is this suite's own,
# and the state dir records a decoy named `Xvfb` with `:N` as its own word:
# `status` must call the display foreign, `exec` must refuse to route there, and
# `stop` must leave the answering server and its lock alone.
if [ "$HAVE_PERL" = 1 ]; then
  D20S=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_empty.XXXXXX")
  _decoy Xvfb -- ":$NUM" -screen 0 640x480x24; D20X=$DECOY
  sleep 0.2
  echo "$D20X" > "$D20S/xvfb.pid"; echo ":$NUM" > "$D20S/display"; echo none > "$D20S/wm"
  realx=$(cat "$STATE/xvfb.pid" 2>/dev/null)
  st20=$(XSCHEM_DEVDISPLAY_DIR="$D20S" "$DD" status 2>/dev/null | grep '^state:' | awk '{print $2}')
  ck "D20 a recorded 'Xvfb :$NUM' that the lock does NOT name is not ours: status says foreign" "foreign" "$st20"
  XSCHEM_DEVDISPLAY_DIR="$D20S" "$DD" exec true >/dev/null 2>&1
  ck "D20 ...and exec refuses to route to it (rc 6)" 6 "$?"
  XSCHEM_DEVDISPLAY_DIR="$D20S" "$DD" stop >/dev/null 2>&1
  ck "D20 ...and stop leaves the server the lock names running, lock intact" "1 $realx" \
     "$(_alive "$realx") $(tr -cd 0-9 < "/tmp/.X$NUM-lock" 2>/dev/null)"
  kill -9 "$D20X" 2>/dev/null; wait "$D20X" 2>/dev/null; rm -rf "$D20S"
else
  skipck "D20 (no perl on PATH to make an argv[0]-named decoy)"
fi

# --- D22: a window manager is identified by its DISPLAY and HOME, not its name --
#
# DECISIONS D20.1. `stop` killed a recorded WM on argv[0] alone, so a wm.pid
# naming ANY live openbox -- the round-3 safety refuter's was serving another
# display -- was killed. _wm_is now also requires DISPLAY=:N in the WM's own
# environment and the HOME of the server it serves (one `start` launched both).
# Tested at the predicate, like D14, so that the positive controls are exact:
# the real WM passes, and so does a decoy with the right name, display and home.
if [ "$HAVE_PERL" = 1 ] && [ -n "$(cat "$STATE/wm.pid" 2>/dev/null)" ] && [ "$(cat "$STATE/wm" 2>/dev/null)" != none ]; then
  realx=$(cat "$STATE/xvfb.pid" 2>/dev/null); realw=$(cat "$STATE/wm.pid" 2>/dev/null)
  xhome=$(tr '\0' '\n' < "/proc/$realx/environ" 2>/dev/null | sed -n 's/^HOME=//p' | head -n 1)
  _decoy openbox "DISPLAY=:$((NUM + 1000))" "HOME=$xhome"; W1=$DECOY
  _decoy openbox "DISPLAY=:$NUM" "HOME=$xhome/elsewhere"; W2=$DECOY
  _decoy openbox "DISPLAY=:$NUM" "HOME=$xhome"; W3=$DECOY
  sleep 0.3
  d22=$( (
    . "$DD"
    NUM="$NUM"; DPY=":$NUM"; STATE_DIR="$STATE"
    for w in "$realw" "$W1" "$W2" "$W3"; do _wm_is "$w" "$realx" && printf 1 || printf 0; done
  ) 2>/dev/null )
  ck "D22 _wm_is: the real WM yes; another DISPLAY no; another HOME no; right name+DISPLAY+HOME yes" "1001" "$d22"
  kill -9 "$W1" "$W2" "$W3" 2>/dev/null; wait "$W1" "$W2" "$W3" 2>/dev/null
else
  skipck "D22 (no perl, or the dev display is running WM-less)"
fi

# --- D13: stop ---------------------------------------------------------------
"$DD" stop >/dev/null 2>&1
ck "D13 stop exits 0" 0 "$?"
ck "D13 server is gone" 0 "$(pgrep -f "Xvfb [:]$NUM" | wc -l | tr -d ' ')"
ck "D13 state cleaned" 0 "$([ -e "$STATE/display" ] && echo 1 || echo 0)"
"$DD" stop >/dev/null 2>&1
ck "D13 stopping again is not an error" 0 "$?"

# The half that actually protects the user: an UNCONDITIONAL `export
# DISPLAY=:99` in a shell rc outlives the display it names, and after a reboot
# or a stop it points every GUI program in every new terminal at nothing.
si_down=$(DISPLAY=:0 bash -c "eval \"\$('$DD' shellinit)\"; echo \$DISPLAY" 2>/dev/null)
ck "D15 shellinit leaves DISPLAY ALONE when it is not running" ":0" "$si_down"

# --- D17: the sweep that covers what no trap can ------------------------------
#
# D16 below asserts the trap path. This asserts the OTHER one, which is the one
# the strays came through: a run of this file that is SIGKILLed never reaches
# any teardown, and its server and window manager keep serving. The next run
# reclaims them, and the proof it uses is a stamp on disk -- so the check is a
# pair, because "it killed something" is only half of it. The negative control
# is the whole point: a state dir whose owner is ALIVE is a concurrent run, and
# touching it would be the same defect one layer down.
SWEEPDIRS=""
ORPH=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_test.XXXXXX")
LIVED=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_test.XXXXXX")
OTHER=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_test.XXXXXX")
NODPY=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_test.XXXXXX")
SWEEPDIRS="$ORPH $LIVED $OTHER $NODPY"
DEADP=999999; while [ -e "/proc/$DEADP" ]; do DEADP=$((DEADP + 1)); done
# Display numbers no server uses: the decoys below only CARRY them.
DA=":$((NUM + 2000))"; DB=":$((NUM + 3000))"
for d in "$ORPH" "$OTHER" "$NODPY"; do printf '%s %s\n' "$DEADP" 1 > "$d/.reaper_owner"; done   # runs that are gone
cp "$STATE/.reaper_owner" "$LIVED/.reaper_owner"             # THIS run: alive
if [ "$HAVE_PERL" = 1 ]; then
  # ORPH: a dead run's dir recording $DA, naming what that run started ON $DA --
  # a server by argv[0] and display word, a WM by argv[0] and DISPLAY=$DA -- and a
  # pid it recorded as its WM that is now something else entirely (recycled).
  echo "$DA" > "$ORPH/display"; echo openbox > "$ORPH/wm"
  _decoy Xvfb -- "$DA" -screen 0 640x480x24; OPH=$DECOY
  _decoy openbox "DISPLAY=$DA"; OWM=$DECOY
  sleep 300 & RCY=$!
  echo "$OPH" > "$ORPH/xvfb.pid"; echo "$OWM" > "$ORPH/wm.pid"
  # OTHER: a dead run's dir recording $DA whose pid files name a server and a WM
  # on ANOTHER display, $DB -- the round-3 safety refuter's recipe (DECISIONS
  # D20.2): a stale dir recording :188 named a live `Xvfb :192` and its openbox,
  # and one run of this suite killed both.
  echo "$DA" > "$OTHER/display"; echo openbox > "$OTHER/wm"
  _decoy Xvfb -- "$DB" -screen 0 640x480x24; XO=$DECOY
  _decoy openbox "DISPLAY=$DB"; WO=$DECOY
  echo "$XO" > "$OTHER/xvfb.pid"; echo "$WO" > "$OTHER/wm.pid"
  # NODPY: a dead run's dir with NO display record at all: nothing can be
  # identified, so nothing is killed.
  echo openbox > "$NODPY/wm"
  _decoy Xvfb -- "$DA"; XN=$DECOY
  echo "$XN" > "$NODPY/xvfb.pid"
  # LIVED: THIS run's (alive) dir: never touched, whatever it names.
  echo "$DA" > "$LIVED/display"
  _decoy Xvfb -- "$DA"; LVP=$DECOY
  echo "$LVP" > "$LIVED/xvfb.pid"
  echo "$RCY" > "$ORPH/vnc.pid"
  SWEEPPIDS="$RCY"
  sleep 0.3
  reaper_sweep_orphan_runs "${TMPDIR:-/tmp}/devdisplay_test.*" xvfb.pid wm.pid vnc.pid
  ck "D17 the sweep reclaims the server and WM of a run that is provably dead, on the display it recorded" "0 0" \
     "$(_alive "$OPH") $(_alive "$OWM")"
  ck "D17 ...and leaves a CONCURRENT run's alone (negative control)" 1 "$(_alive "$LVP")"
  ck "D17b ...and never kills a recorded pid that is no longer the program recorded (a recycled pid)" 1 "$(_alive "$RCY")"
  ck "D17c ...nor a server or WM on ANOTHER display than the dead dir recorded (D20.2)" "1 1" \
     "$(_alive "$XO") $(_alive "$WO")"
  ck "D17d ...nor anything named by a dead dir that records no display" 1 "$(_alive "$XN")"
  kill -9 "$OPH" "$OWM" "$LVP" "$RCY" "$XO" "$WO" "$XN" 2>/dev/null
  wait "$OPH" "$OWM" "$LVP" "$RCY" "$XO" "$WO" "$XN" 2>/dev/null
else
  skipck "D17 (no perl on PATH to make an argv[0]-named decoy)"
fi
rm -rf "$ORPH" "$LIVED" "$OTHER" "$NODPY" 2>/dev/null; SWEEPDIRS=""; SWEEPPIDS=""

# --- D18: `stop` kills only what it can identify, and unlocks only its own ---
#
# The round-2 safety refuter's recipe (DECISIONS D17.6): a state dir whose pid
# files name processes that are NOT the programs recorded -- here three `sleep`
# decoys, as a stale dir names whatever a reboot handed its pids to -- and a
# lock on the display naming one of them. `stop` used to kill every pid it was
# handed and remove the lock by number: both decoys died ('devdisplay: stopped
# :191'). The display is this run's own number, down since D13, so the planted
# lock is ours to plant and to clean up.
D18S=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_empty.XXXXXX")
sleep 300 & DX=$!; sleep 300 & DW=$!; sleep 300 & DV=$!
SWEEPPIDS="$DX $DW $DV"
echo "$DX" > "$D18S/xvfb.pid"; echo "$DW" > "$D18S/wm.pid"; echo "$DV" > "$D18S/vnc.pid"
echo ":$NUM" > "$D18S/display"; echo openbox > "$D18S/wm"
d18lock=0
if [ ! -e "/tmp/.X$NUM-lock" ]; then
  printf '%10d\n' "$DX" > "/tmp/.X$NUM-lock" && d18lock=1
fi
XSCHEM_DEVDISPLAY_DIR="$D18S" DEVDISPLAY_NUM="$NUM" "$DD" stop >/dev/null 2>&1
ck "D18 stop kills no recorded pid that is not the program recorded (three sleep decoys survive)" "1 1 1" \
   "$(for p in $DX $DW $DV; do kill -0 "$p" 2>/dev/null && printf 1 || printf 0; [ "$p" = "$DV" ] || printf ' '; done)"
if [ "$d18lock" = 1 ]; then
  ck "D18 ...and leaves a lock that does not name a server it stopped" 1 \
     "$([ "$(tr -cd 0-9 < "/tmp/.X$NUM-lock" 2>/dev/null)" = "$DX" ] && echo 1 || echo 0)"
  [ "$(tr -cd 0-9 < "/tmp/.X$NUM-lock" 2>/dev/null)" = "$DX" ] && rm -f "/tmp/.X$NUM-lock"
else
  skipck "D18 lock half (a lock appeared on :$NUM meanwhile -- another run's; not planting over it)"
fi
kill -9 $DX $DW $DV 2>/dev/null; wait $DX $DW $DV 2>/dev/null
rm -rf "$D18S"; SWEEPPIDS=""

# --- D19: identity is argv[0], not a word in the command line (round 3's S1) --
#
# DECISIONS D17.6: `sleep 300 Xvfb :99` is not an Xvfb. D18's decoys never carry
# the words, so when the round-3 regression refuter put `_pid_is` back to "the
# program's name anywhere in the command line" (its sabotage S1) every suite
# stayed green. This decoy carries exactly those words -- `Xvfb` and `:N`, each
# its own argv word -- behind an argv[0] that is something else, as a stale
# state dir's recycled pid might; `stop` must leave it, and a lock naming it,
# alone. (The display is this run's own number, down since D13.)
if [ "$HAVE_PERL" = 1 ]; then
  D19S=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_empty.XXXXXX")
  _decoy perl -- Xvfb ":$NUM" -screen 0 640x480x24; D19X=$DECOY
  sleep 0.2
  echo "$D19X" > "$D19S/xvfb.pid"; echo ":$NUM" > "$D19S/display"; echo none > "$D19S/wm"
  d19lock=0
  if [ ! -e "/tmp/.X$NUM-lock" ]; then printf '%10d\n' "$D19X" > "/tmp/.X$NUM-lock" && d19lock=1; fi
  XSCHEM_DEVDISPLAY_DIR="$D19S" "$DD" stop >/dev/null 2>&1
  ck "D19 stop never kills a pid whose command line merely CONTAINS 'Xvfb :$NUM' (argv[0] is perl)" 1 "$(_alive "$D19X")"
  if [ "$d19lock" = 1 ]; then
    ck "D19 ...and leaves the lock that names it" "$D19X" "$(tr -cd 0-9 < "/tmp/.X$NUM-lock" 2>/dev/null)"
    [ "$(tr -cd 0-9 < "/tmp/.X$NUM-lock" 2>/dev/null)" = "$D19X" ] && rm -f "/tmp/.X$NUM-lock"
  else
    skipck "D19 lock half (a lock appeared on :$NUM meanwhile -- another run's; not planting over it)"
  fi
  kill -9 "$D19X" 2>/dev/null; wait "$D19X" 2>/dev/null; rm -rf "$D19S"
else
  skipck "D19 (no perl on PATH to make a decoy)"
fi

# --- D21: a dead server means NOTHING the state dir names is killed ------------
#
# The round-3 safety refuter's recipe (DECISIONS D20.1), and the user's own state
# dir today: xvfb.pid names a DEAD pid, wm.pid a LIVE window manager -- theirs was
# serving another display. `stop` fell through the dead server to the WM kill and
# killed it on argv[0] alone ('devdisplay: stopped :194', that openbox gone).
# Nothing a state dir records can still be its own once its server is gone.
if [ "$HAVE_PERL" = 1 ]; then
  D21S=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_empty.XXXXXX")
  _decoy openbox "DISPLAY=:$((NUM + 1000))"; D21W=$DECOY
  _decoy x11vnc -- -display ":$NUM" -localhost; D21V=$DECOY
  sleep 0.2
  echo "$DEADP" > "$D21S/xvfb.pid"; echo "$D21W" > "$D21S/wm.pid"; echo "$D21V" > "$D21S/vnc.pid"
  echo ":$NUM" > "$D21S/display"; echo openbox > "$D21S/wm"
  d21out=$(XSCHEM_DEVDISPLAY_DIR="$D21S" "$DD" stop 2>&1)
  ck "D21 stop with a DEAD xvfb.pid kills neither the live WM nor the viewer its state dir names" "1 1" \
     "$(_alive "$D21W") $(_alive "$D21V")"
  ck "D21 ...says it was not running, and cleans the state" "1 0" \
     "$(printf '%s' "$d21out" | grep -c 'not running') $([ -e "$D21S/wm.pid" ] && echo 1 || echo 0)"
  kill -9 "$D21W" "$D21V" 2>/dev/null; wait "$D21W" "$D21V" 2>/dev/null; rm -rf "$D21S"
else
  skipck "D21 (no perl on PATH to make a decoy)"
fi

# --- D16: nothing this run started outlives it -------------------------------
#
# The check the harness did not have. A suite that leaks cannot see it: item 14
# began with 21 gate panels and an orphaned Xvfb + openbox pair alive for 24 h
# behind suites that were passing every one of their own checks. D13 already
# takes the dev display down, so what is left to reap here is the FOREIGN server
# of D11 -- taken down first, by pid, so this is an assertion and not a
# tautology. reaper_survivors is pid-registry based; it can never name a server
# or a panel belonging to another session.
#
# NOTE THE ORDER: it asserts, it does not reap. Reaping first would make the
# check ask "can I kill things", which is never the question. The net in
# _cleanup still runs afterwards, so a red D16 does not become a leak.
_dd_track_pids
ntracked="$(reaper_tracked)"
ck "D16 the run really did start servers of its own ($ntracked tracked)" 1 \
   "$([ "${ntracked:-0}" -ge 2 ] && echo 1 || echo 0)"
ck "D16 ...and nothing it started is still alive" 0 "$(reaper_survivors | grep -c . || true)"

# -----------------------------------------------------------------------------
echo
if [ "$fail" -eq 0 ]; then
  if [ "$skip" -gt 0 ]; then
    echo "RESULT: ALL PASS ($pass checks, $skip skipped)"
  else
    echo "RESULT: ALL PASS ($pass checks)"
  fi
  exit 0
fi
echo "RESULT: $fail FAILED ($pass passed, $skip skipped)"
exit 1
