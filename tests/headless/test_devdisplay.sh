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
# This suite deliberately does NOT arm itself: it manages X displays, so it must
# be the thing deciding which ones exist.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
DD="$HERE/devdisplay.sh"

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
_free_num() {
  local n
  for n in 96 95 94 93 92 91 90 89; do
    [ -S "/tmp/.X11-unix/X$n" ] && continue
    ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$n\b" && continue
    [ -e "/tmp/.X$n-lock" ] && continue
    echo "$n"; return 0
  done
  return 1
}
NUM=$(_free_num) || { echo "RESULT: FAIL (no free display number in 89..96)"; exit 1; }
FOREIGN=$(DEVDISPLAY_NUM= _free_num_skip=$NUM; for n in 88 87 86 85; do
            [ -S "/tmp/.X11-unix/X$n" ] && continue
            ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$n\b" && continue
            [ -e "/tmp/.X$n-lock" ] && continue
            echo "$n"; break; done)

STATE=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_test.XXXXXX")
EMPTY=$(mktemp -d "${TMPDIR:-/tmp}/devdisplay_empty.XXXXXX")
export XSCHEM_DEVDISPLAY_DIR="$STATE"
export DEVDISPLAY_NUM="$NUM"

_cleanup() {
  XSCHEM_DEVDISPLAY_DIR="$STATE" DEVDISPLAY_NUM="$NUM" "$DD" stop >/dev/null 2>&1
  [ -n "${FOREIGN:-}" ] && pkill -f "Xvfb [:]$FOREIGN" >/dev/null 2>&1
  rm -rf "$STATE" "$EMPTY" 2>/dev/null
  rm -f "/tmp/.X$NUM-lock" "/tmp/.X${FOREIGN:-999}-lock" 2>/dev/null
}
trap _cleanup EXIT INT TERM

note "display :$NUM, state $STATE"

# --- D1: start ---------------------------------------------------------------
"$DD" start >/dev/null 2>&1
rc=$?
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
