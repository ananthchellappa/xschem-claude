#!/bin/bash
# test_wslg_health.sh — self-test for tests/headless/wslg_health.sh, the WSLg
# display-health probe (issue 0310; spec doc/claude/specs/wslg_health_probe.md).
#
# Run from anywhere:  tests/headless/test_wslg_health.sh
#
# NOT REACHED BY ANY RUNNER, DELIBERATELY. full_audit.sh globs test_*.tcl (plus
# the name-special-cased `wireedit` pseudo-entry) and run_suites.sh resolves every
# name to <name>.tcl and drives it through the xschem binary, so neither can run a
# .sh suite. This file is HAND-RUN, exactly like its neighbours
# test_gui_gate_revive.sh and test_gui_gate_batch.sh. Its green result is not
# CI-backed and must never be quoted as if it were.
#
# THE PROBLEM THIS TEST HAS TO SOLVE. The condition wslg_health.sh detects is a
# 640x480 Xwayland stub that parks every window at -32768, and Xwayland cannot be
# crashed to order — nor may this test try: building a second display, or killing
# the compositor, takes down the user's desktop and every X client, which is the
# very failure the harness exists to avoid.
#
# So the script's JUDGEMENT is factored away from its MEASURING, and the decision
# arm below feeds the judgement the values RECORDED FROM THE REAL FAILURE on
# 2026-08-10 (issue 0310):
#     root 640x480
#     tree line  0x201d48 (has no name): ()  544x547+-32768+-32768  +-32768+-32768
#     probe      want +200+200 got +-32730+-32709 screen 640x480
# and the values recorded from the healthy server the same day:
#     root 5120x1440, no sentinel anywhere,
#     probe      want +200+200 got +206+227 screen 5120x1440
# Invented numbers would prove nothing; these are the two machines.
#
# Arms:
#   DECISION  DH01-DH19  pure judgement, no X needed. Every check driven BOTH
#                        ways, and each of the faults driven ALONE so that no
#                        check can be hiding behind another.
#   LIVE      DH20-DH28  the real script against $DISPLAY: shape AND CONTENT of
#                        the output, verdict/exit-code agreement, and that the
#                        Tk probe really ran -- proved by an ARBITRARY requested
#                        position that the reported one has to track, and by
#                        catching the probe's own uniquely-titled window on the
#                        display while it is up. ONE PROBE RUN FOR THE WHOLE
#                        ARM (see below).
#   SAFETY    DH30-DH36  the contract: no display is NOT a failure, a typo is
#                        never "headless, carry on", the forbidden full_audit
#                        SKIP substrings never appear, the GUI-test gate dir is
#                        never touched, and a server that does not answer is
#                        bounded by the timeout rather than hanging.
#   E2E       DH40-DH45  wslg_health.sh ITSELF, end to end, under a PATH shim of
#                        fake xdpyinfo/xwininfo/wish emitting the RECORDED stub
#                        values and (separately) the RECORDED healthy values.
#                        This is the only arm that ties the numbers the script
#                        REPORTS to what X actually SAID: without it, a script
#                        that ignored xwininfo and the Tk probe entirely and
#                        always printed HEALTHY passed every other check.
#   GATE      DH50-DH67  the probe answers the control panel's Pause and Stop
#                        BEFORE it maps anything -- and before EVERY retry, not
#                        just the first. Driven under the shim, where the fake
#                        `wish` counts its calls, so "it obeyed" is evidence
#                        (zero calls, or exactly one) and not a verdict word.
#
# ONE WINDOW PER RUN, NOT A DOZEN, AND IT IS COUNTED. Check 5 maps a real
# top-level ON THE USER'S SCREEN. The whole live arm is derived from a SINGLE
# probe run (it used to start four, each retrying up to three times), and every
# other arm runs under a PATH shim whose fake wish maps nothing.
# MEASURED, with a `wish`-counting shim on PATH: this file used to launch THREE
# real probes per run -- the live arm's, DH31's bare `"$PROBE"`, and DH34's
# `HOME="$fakehome" "$PROBE"`. The last was the worst of the three: with $HOME
# redirected the probe resolved its control file to a gate dir that did not
# exist, failed open, and mapped a window on the user's display whatever the
# real panel said -- one ungated window per run, the exact invariant this file
# exists to defend. Both now run under $NOWIN (below) and map nothing, so a run
# of this file maps ONE window (up to 3 if the WM misplaces it and the probe
# retries).
#
# Nothing here starts, kills or pauses anything, and it never writes into
# ~/.claude/gui_test_gate/ -- every control file it writes is under its own
# mktemp dir, pointed at with $GUI_GATE_DIR.

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$SELF/wslg_health.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0
CHECKS=0
ck()   { CHECKS=$((CHECKS+1)); if [ "$2" = "1" ]; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS+1)); fi; }
eqck() { CHECKS=$((CHECKS+1)); if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got '$2' want '$3')"; FAILS=$((FAILS+1)); fi; }

[ -f "$PROBE" ] || { echo "FAIL DH00 wslg_health.sh not found at $PROBE"; echo "RESULT fails=1 checks=1"; exit 1; }

# --- $NOWIN: a PATH shim that maps NOTHING ----------------------------------
# Only `wish` is faked, so xdpyinfo and xwininfo still answer from the REAL
# display -- but check 5, the only thing in this harness that paints on the
# user's screen, never gets a window. Every live-display check that is not about
# the placement MEASUREMENT itself runs under this shim (see "ONE WINDOW PER
# RUN" above).
NOWIN="$TMP/shim_nowin"; mkdir -p "$NOWIN"
cat > "$NOWIN/wish" <<'NW'
#!/bin/sh
echo "PROBE want +200+200 got +206+227 screen 5120x1440"
exit 0
NW
chmod +x "$NOWIN/wish"
# An empty gate dir: the probe fails open on it, so a Pause the user presses
# mid-run cannot turn a check that is NOT about the panel red (nor hold it). The
# panel's own behaviour is asserted in the GATE arm, against control files this
# test writes under $TMP.
mkdir -p "$TMP/gate_none"

# --- the two recorded machines ----------------------------------------------
STUB_TREE='     0x201d48 (has no name): ()  544x547+-32768+-32768  +-32768+-32768
        0x400049 "xschem GUI-test control": ("xschem" "Xschem")  468x450+38+59  +-32730+-32709'
# the SAME stub, sampled again a moment later: the parked windows have not moved
# (that is what makes them a stub and not a WM frame in flight), while an
# unrelated window has come and gone.
STUB_TREE2='     0x201d48 (has no name): ()  544x547+-32768+-32768  +-32768+-32768
        0x400049 "xschem GUI-test control": ("xschem" "Xschem")  468x450+38+59  +-32730+-32709
        0x900001 "xterm": ("xterm" "XTerm")  500x300+-32768+-32768  +-32768+-32768'
GOOD_TREE='  0x3a9 (has no name): ()  5120x1440+0+0  +0+0
     0x400049 "xschem GUI-test control": ("xschem" "Xschem")  468x450+46+67  +46+67'
# MEASURED on the healthy 5120x1440 display, not invented: every ordinary window
# map passes through this transient WM pre-placement frame (seen in 1 of 240
# one-shot `xwininfo -root -tree` snapshots taken across 6 wish launches; a
# reviewer saw 6 of 240 under load). It is gone from the next sample.
TRANSIENT_TREE="$GOOD_TREE
     0x2001e1 (has no name): ()  236x157+-32768+-32768  +-32768+-32768"

echo "=== DECISION arm (recorded values; no X needed) ==="

# Source the script: it must define the judgement and RUN NOTHING. If the main
# entry point were not guarded this would probe the live display here, and every
# check below would be measuring the machine instead of the logic.
#
# The first source is deliberately inside a COMMAND SUBSTITUTION, i.e. a
# subshell. An unguarded wslg_health.sh ends in `wh_main "$@"; exit $?`, and a
# sourced `exit` kills the CALLER -- this whole test would vanish at line one,
# printing no RESULT banner and exiting 0. (Measured: that is exactly what the
# first version of this check did when the guard was sabotaged, which made it
# hollow.) In a subshell the exit is contained, and the probe's own verdict line
# becomes the evidence.
# shellcheck source=/dev/null
srcout="$( . "$PROBE" 2>&1 )"
eqck "DH01 sourcing wslg_health.sh executes nothing (the entry point is guarded)" "$srcout" ""
if [ -n "$srcout" ]; then
  echo "FAIL DH01 sourcing the script RAN it -- the decision arm would measure this machine, not the logic"
  echo "RESULT fails=$((FAILS+1)) checks=$((CHECKS+1))"
  exit 1
fi
# shellcheck source=/dev/null
. "$PROBE"
ck "DH01 ...and defines the judgement: wh_decide + the three checks" \
   "$(for f in wh_decide wh_check_geometry wh_check_sentinel wh_check_placement; do
        type -t "$f" >/dev/null || { echo 0; exit 0; }
      done; echo 1)"

# --- check 2: root geometry, as a FLOOR ---
# geom <w> <h> -> rc of wh_check_geometry, with WH_DETAIL freshly captured
geom() { WH_DETAIL=""; wh_check_geometry "$1" "$2" "root geometry"; }
geom 640 480;   eqck "DH02 recorded stub root 640x480 -> STUB" "$?" "1"
ck "DH02 ...and says so in the detail block" \
   "$(case "$WH_DETAIL" in *"[STUB]"*"640x480"*) echo 1 ;; *) echo 0 ;; esac)"
geom 5120 1440; eqck "DH03 recorded healthy root 5120x1440 -> ok" "$?" "0"
# A LEGITIMATE RESIZE IS NOT A FAULT: this machine's root really does alternate
# between 5120x1440 and 2560x1440 as monitors come and go. That is why the check
# is a floor and not an equality test against either number.
geom 2560 1440; eqck "DH04 the machine's OTHER real size 2560x1440 -> ok (a resize is not a fault)" "$?" "0"
geom 1024 768;  eqck "DH05 the floor itself 1024x768 -> ok (inclusive)" "$?" "0"
geom 1024 767;  eqck "DH06 one pixel under the floor -> STUB" "$?" "1"
geom - -;       eqck "DH07 unreadable geometry -> cannot judge (3), never a silent pass" "$?" "3"

# --- check 3: the -32768 sentinel, over TWO samples ---
sent() { WH_DETAIL=""; wh_check_sentinel "$1" "${2:-}"; }
sent "$STUB_TREE" "$STUB_TREE2"; eqck "DH08 the recorded stub, parked in BOTH samples -> STUB" "$?" "1"
ck "DH08 ...naming the count and quoting the offending window" \
   "$(case "$WH_DETAIL" in *"2 window(s)"*"0x201d48"*) echo 1 ;; *) echo 0 ;; esac)"
sent "$GOOD_TREE" "$GOOD_TREE"; eqck "DH09 the recorded healthy window tree -> ok" "$?" "0"
# the sentinel is a MAGNITUDE, not the text '327': a window legitimately AT
# +327+327 is fine...
sent '  0x1 "w": ()  100x100+327+327  +327+327' '  0x1 "w": ()  100x100+327+327  +327+327'
eqck "DH10 a window at POSITIVE +327+327 is not the sentinel -> ok" "$?" "0"
# ...and so is one overhanging the left edge by 327 or 3275 px, which is entirely
# ordinary on this 5120x1440 multi-monitor desktop. The old '+-327' PREFIX match
# condemned both (measured: `900x700+-327+140` reported as a stub).
sent '  0x1400003 "gvim": ("gvim" "Gvim")  900x700+-327+140  +-327+140' \
     '  0x1400003 "gvim": ("gvim" "Gvim")  900x700+-327+140  +-327+140'
eqck "DH10b an ordinary window at x=-327 is NOT the sentinel -> ok" "$?" "0"
sent '  0x1400003 "gvim": ()  900x700+-3275+140  +-3275+140' \
     '  0x1400003 "gvim": ()  900x700+-3275+140  +-3275+140'
eqck "DH10c ...nor one at x=-3275 -> ok" "$?" "0"
# THE BLOCKER. A transient WM pre-placement frame appears at exactly the stub
# coordinates on a HEALTHY display while any window is mapping, and it is gone
# from the next sample. One snapshot is not evidence; two are.
sent "$TRANSIENT_TREE" "$GOOD_TREE"
eqck "DH10d a transient WM frame at +-32768+-32768 in ONE sample only -> ok (healthy display, window mid-map)" "$?" "0"
ck "DH10d ...and it is reported as transient, not silently ignored" \
   "$(case "$WH_DETAIL" in *"transient"*) echo 1 ;; *) echo 0 ;; esac)"
sent "$GOOD_TREE" "$TRANSIENT_TREE"
eqck "DH10e ...the other way round too (frame in the SECOND sample only) -> ok" "$?" "0"
# and a window that is parked in both samples is still caught, even when the rest
# of the tree churns around it.
sent "$TRANSIENT_TREE" "$TRANSIENT_TREE"
eqck "DH10f the SAME window at the sentinel in both samples -> STUB" "$?" "1"

# --- check 5: the functional placement probe (the decisive one) ---
place() { WH_DETAIL=""; wh_check_placement "$1" "$2" "$3" "$4"; }
place 200 200 -32730 -32709; eqck "DH11 recorded stub placement +-32730+-32709 -> STUB" "$?" "1"
place 200 200 206 227;       eqck "DH12 recorded healthy placement +206+227 -> ok (a WM decoration offset is CORRECT)" "$?" "0"
place 200 200 200 200;       eqck "DH13 an exact landing -> ok" "$?" "0"
place 200 200 264 264;       eqck "DH14 the tolerance edge (64 px) -> ok" "$?" "0"
place 200 200 265 200;       eqck "DH15 one pixel past the tolerance -> STUB" "$?" "1"
place 200 200 - -;           eqck "DH16 no probe coordinates -> cannot judge (3), never a silent pass" "$?" "3"
ck "DH11 ...and the STUB line quotes both the wanted and the actual position" \
   "$(WH_DETAIL=""; wh_check_placement 200 200 -32730 -32709
      case "$WH_DETAIL" in *"want +200+200 got +-32730+-32709"*) echo 1 ;; *) echo 0 ;; esac)"

# --- the composed verdict, on the two recorded machines ---
WH_DETAIL=""; WH_VERDICT=""
wh_decide 640 480 "$STUB_TREE" 200 200 -32730 -32709 640 480 "$STUB_TREE2" >/dev/null; rc=$?
eqck "DH17 the WHOLE recorded stub -> UNHEALTHY" "$WH_VERDICT" "UNHEALTHY"
eqck "DH17 ...rc 1" "$rc" "1"
# each of the three faults must be seen by its OWN check, not inferred from a
# neighbour: the stub trips all of them, and that is the evidence that none of
# them is dead code hiding behind another.
eqck "DH17 ...and all FOUR judgements report STUB independently" \
     "$(printf '%s\n' "$WH_DETAIL" | grep -c '\[STUB\]')" "4"

WH_DETAIL=""; WH_VERDICT=""
wh_decide 5120 1440 "$GOOD_TREE" 200 200 206 227 5120 1440 "$GOOD_TREE" >/dev/null; rc=$?
eqck "DH18 the WHOLE recorded healthy machine -> HEALTHY" "$WH_VERDICT" "HEALTHY"
eqck "DH18 ...rc 0" "$rc" "0"
eqck "DH18 ...with nothing flagged" "$(printf '%s\n' "$WH_DETAIL" | grep -c '\[STUB\]')" "0"

# EACH FAULT ALONE. A stub that only showed up in one of the three would have
# been missed by a probe that ANDed them, and the placement leg is the one that
# is decisive on its own — that is the whole reason it exists.
WH_VERDICT=""; WH_DETAIL=""
wh_decide 5120 1440 "$GOOD_TREE" 200 200 -32730 -32709 5120 1440 "$GOOD_TREE" >/dev/null
eqck "DH19a placement fault ALONE (real root, clean tree) -> UNHEALTHY" "$WH_VERDICT" "UNHEALTHY"
WH_VERDICT=""; WH_DETAIL=""
wh_decide 640 480 "$GOOD_TREE" 200 200 206 227 5120 1440 "$GOOD_TREE" >/dev/null
eqck "DH19b stub root ALONE -> UNHEALTHY" "$WH_VERDICT" "UNHEALTHY"
WH_VERDICT=""; WH_DETAIL=""
wh_decide 5120 1440 "$STUB_TREE" 200 200 206 227 5120 1440 "$STUB_TREE2" >/dev/null
eqck "DH19c a parked window ALONE -> UNHEALTHY" "$WH_VERDICT" "UNHEALTHY"
WH_VERDICT=""; WH_DETAIL=""
wh_decide 5120 1440 "$GOOD_TREE" 200 200 206 227 640 480 "$GOOD_TREE" >/dev/null
eqck "DH19d the PROBE's own screen size ALONE -> UNHEALTHY" "$WH_VERDICT" "UNHEALTHY"
WH_VERDICT=""; WH_DETAIL=""
wh_decide 5120 1440 "$GOOD_TREE" 200 200 - - 5120 1440 "$GOOD_TREE" >/dev/null
eqck "DH19e everything fine but the probe did not run -> UNKNOWN, not HEALTHY" "$WH_VERDICT" "UNKNOWN"
# a healthy machine that merely happened to be opening a window while sample 1
# was taken must NOT be condemned -- this is the false UNHEALTHY a reviewer
# measured 4 times in 8 runs on the live display.
WH_VERDICT=""; WH_DETAIL=""
wh_decide 5120 1440 "$TRANSIENT_TREE" 200 200 206 227 5120 1440 "$GOOD_TREE" >/dev/null
eqck "DH19f healthy machine with a window mid-map -> HEALTHY, not a false stub" "$WH_VERDICT" "HEALTHY"

echo "=== LIVE arm (the real script against \$DISPLAY) ==="
if [ -z "${DISPLAY:-}" ]; then
  # NOT the string "skipped: no X" / "RESULT: SKIP" / "SKIP: no X connection":
  # full_audit.sh scores a whole FILE on those substrings and would discard every
  # decision check above. This file is not globbed by full_audit today, but the
  # banner must not become a landmine if it ever is.
  echo "info DH2x live arm not run (no DISPLAY) -- decision arm above is display-independent"
else
  # ONE PROBE RUN IN THIS WHOLE ARM, AND ONLY ONE.
  #
  # Check 5 maps a real top-level ON THE USER'S SCREEN. The first version of
  # this file ran the probe FOUR separate times here (and each run retries up
  # to three times), so a single pass could flash a dozen little windows across
  # the desktop -- which is exactly the complaint that stopped the previous
  # attempt at this item. Every live check below is therefore derived from ONE
  # run, whose requested position is deliberately ARBITRARY (+437+311) and
  # whose window is held up for two seconds so it can be caught in the window
  # tree while it is actually there.
  tag="dh2x-$$"
  rm -f "$TMP/live.rc"
  # THE HOLD BOUND IS SMALLER THAN THE OUTER TIMEOUT, deliberately. With the
  # panel actually PAUSED and the shipped 300 s bound, `timeout 90` SIGKILLed
  # the probe first: no VERDICT line at all, DH20/DH21 red, and the
  # STOPPED|DEFERRED partial-run branch below never taken -- i.e. the user
  # pressing the button turned this file red instead of making it report a
  # partial run. 20 s is well inside 90.
  ( WSLG_HEALTH_PROBE_TAG="$tag" WSLG_HEALTH_WANT_X=437 WSLG_HEALTH_WANT_Y=311 \
    WSLG_HEALTH_PROBE_HOLD_MS=2000 WSLG_HEALTH_GATE_WAIT=20 timeout 90 "$PROBE" > "$TMP/live.out" 2>&1
    echo $? > "$TMP/live.rc" ) &
  bgpid=$!
  # ...and while it is up, catch it: a real TOP-LEVEL really being mapped on the
  # real display is the one thing no amount of output-shape checking can prove.
  # The title carries a per-process tag, so this can never see another copy's
  # window nor another copy this one's -- two agents share this display.
  # KEEP THE WHOLE TREE LINE, not just "seen": its last field is the absolute
  # position X ITSELF reports for that window, measured from the shell by a
  # different tool than the one inside the probe -- the independent witness
  # DH22d needs (see there).
  #
  # TWO TRAPS IN THIS SAMPLING, both measured here, both fixed by keeping the
  # LAST SETTLED reading rather than the first reading:
  #  1. THE READ MUST SETTLE, for exactly the reason the probe's own does: a
  #     window appears in `xwininfo -root -tree` at the WM's PRE-PLACEMENT frame
  #     -- measured, `+-32730+-32709`, byte-identical to the recorded stub value
  #     -- and only lands at its real position a few tens of ms later. So a
  #     reading inside the sentinel region is never taken as the answer while a
  #     settled one is available.
  #  2. THE PROBE MAY RETRY, and then the FIRST settled window is not the one it
  #     reports: measured live, attempt 1 was placed at the origin (+6+27, the
  #     documented WM hiccup), attempt 2 at +443+338, and a witness that stopped
  #     at the first settled reading compared two DIFFERENT windows and went red
  #     on a display that was fine. Sampling runs until the probe process exits,
  #     so the last settled reading is the last attempt's -- the reported one.
  # If nothing ever settles (a genuine stub parks permanently) the last raw
  # reading is used, which is the parked position -- and that is what the probe
  # reports too, so the two still have to agree.
  seen=0; treeline=""; treeraw=""
  for _i in $(seq 1 600); do
    tl="$(timeout 10 xwininfo -root -tree 2>/dev/null | grep -F "wslg_health probe $tag" | head -1)"
    if [ -n "$tl" ]; then
      seen=1; treeraw="$tl"
      tp="${tl##* }"; tpx="${tp#+}"; tpx="${tpx%%+*}"; tpy="${tp##*+}"
      if wh_is_int "$tpx" && wh_is_int "$tpy" \
         && [ "${tpx#-}" -lt 30000 ] && [ "${tpy#-}" -lt 30000 ]; then treeline="$tl"; fi
    fi
    kill -0 "$bgpid" 2>/dev/null || break
    sleep 0.05
  done
  [ -n "$treeline" ] || treeline="$treeraw"
  wait "$bgpid" 2>/dev/null
  out="$(cat "$TMP/live.out" 2>/dev/null)"; rc="$(cat "$TMP/live.rc" 2>/dev/null || echo 99)"
  printf '%s\n' "$out" | sed 's/^/     | /'
  eqck "DH20 exactly one VERDICT line" "$(printf '%s\n' "$out" | grep -c '^VERDICT: ')" "1"
  verdict="$(printf '%s\n' "$out" | sed -n 's/^VERDICT: \([A-Z]*\).*/\1/p')"
  case "$verdict" in
    HEALTHY)   want=0 ;;
    UNHEALTHY) want=1 ;;
    NODISPLAY) want=2 ;;
    STOPPED)   want=4 ;;
    DEFERRED)  want=5 ;;
    *)         want=3 ;;
  esac
  eqck "DH21 the exit code agrees with the verdict word ($verdict)" "$rc" "$want"

  # THE CHECK COUNT OF THIS BRANCH IS ITSELF ASSERTED (DH29, after the esac).
  # DH22b used to be asserted only inside `if verdict = HEALTHY`, with the other
  # branch printing an info line and counting NOTHING: a probe that reported a
  # hardcoded wrong position therefore produced fails=0 with one check fewer and
  # no red anywhere. A check that can vanish silently is not a check.
  livec0=$CHECKS
  case "$verdict" in
    STOPPED|DEFERRED)
      # THE USER PRESSED THE BUTTON WHILE THIS TEST WAS RUNNING. That is the
      # probe behaving correctly, not a defect: it mapped nothing, so there is
      # nothing to assert about a measurement that was never taken. Report the
      # partial run and move on -- never work around the hold.
      echo "info DH22-DH27 not asserted: the GUI-test panel held the probe ($verdict), so nothing was measured. This is the gate working; press Resume and re-run for the live arm."
      ;;
    *)
      # THE decisive check must actually have run: if the Tk probe silently did
      # not map a window, the script would still print four green lines and a
      # HEALTHY verdict -- the exact hollow-green this whole item exists to
      # prevent.
      ck "DH22 the functional Tk probe really ran (want/got coordinates present)" \
         "$(printf '%s\n' "$out" | grep -q 'window placement.*want +[0-9-]*+[0-9-]*  *got +[0-9-]*+[0-9-]*' && echo 1 || echo 0)"
      # ...and "present" is not enough: text can be printed from variables. The
      # position asked for was ARBITRARY, and the reported one has to track it.
      ck "DH22a an ARBITRARY requested position (+437+311) is echoed back" \
         "$(case "$out" in *"want +437+311"*) echo 1 ;; *) echo 0 ;; esac)"
      agot="$(printf '%s\n' "$out" | sed -n 's/.*got +\([0-9-]*\)+\([0-9-]*\) .*/\1 \2/p' | head -1)"
      agx="${agot%% *}"; agy="${agot##* }"
      if [ "$verdict" = HEALTHY ]; then
        # Nothing but a real window, really placed by the real WM, can do this:
        # a hardcoded +206+227 is 231/84 px from THIS request, which is outside
        # the 64 px tolerance and would have read UNHEALTHY.
        ck "DH22b ...and the position the WM actually used tracks it (got +${agx:-?}+${agy:-?})" \
           "$([ -n "$agot" ] \
              && [ "$((agx > 437 ? agx - 437 : 437 - agx))" -le 64 ] \
              && [ "$((agy > 311 ? agy - 311 : 311 - agy))" -le 64 ] && echo 1 || echo 0)"
      else
        # On a display that is genuinely a stub the reported position SHOULD be
        # far from the request -- asserting tracking here would confuse "this
        # code is correct" with "this desktop is currently fine". This branch
        # still COUNTS a check (see DH29): an unhealthy verdict has to NAME the
        # check that produced it, or the run is a verdict with no evidence.
        ck "DH22b (this display is $verdict, so 'got' +${agx:-?}+${agy:-?} is expected NOT to track 'want' -- asserting instead that the verdict names the check behind it)" \
           "$(printf '%s\n' "$out" | grep -qE '^  \[(STUB|\?\? )\]' && echo 1 || echo 0)"
      fi
      eqck "DH22c the probe's own window (tagged '$tag') was really MAPPED on the display" "$seen" "1"
      # DH22d -- THE INDEPENDENT WITNESS, and the only check in this file that
      # can catch a probe which stops MEASURING. Everything else about placement
      # compares the probe's own two numbers against each other or against the
      # request, so a PROBE_TCL that dropped `winfo rootx/rooty` and echoed the
      # REQUESTED position back as the measured one passed all 130 checks (got
      # == want satisfies DH22b by construction). Here the position is taken
      # from the SHELL side, by a different tool (xwininfo -root -tree, whose
      # last field is the window's absolute position), while the probe holds its
      # window up -- so the number the probe printed has to match a number it
      # did not produce. MEASURED live: tree `160x60+38+59  +443+338` against a
      # reported `got +443+338` for a request of +437+311, i.e. the 6,27 WM
      # decoration offset is present in BOTH and identical. Tolerance 2 px for a
      # WM that nudges the window between the two reads; the fabrication this
      # defeats is 27 px out.
      wgot="${treeline##* }"; wgx="${wgot#+}"; wgx="${wgx%%+*}"; wgy="${wgot##*+}"
      ck "DH22d the position xwininfo INDEPENDENTLY saw (${wgot:-none}) is the one the probe reported (+${agx:-?}+${agy:-?})" \
         "$( { [ -n "$treeline" ] && wh_is_int "${wgx:-}" && wh_is_int "${wgy:-}" \
                && wh_is_int "${agx:-}" && wh_is_int "${agy:-}" \
                && [ "$((agx > wgx ? agx - wgx : wgx - agx))" -le 2 ] \
                && [ "$((agy > wgy ? agy - wgy : wgy - agy))" -le 2 ]; } && echo 1 || echo 0)"
      # every reported check must carry its measured VALUE, not just its label: a
      # degraded branch that prints the same label with "unknown" under it must not
      # read as the check having run.
      missing=""
      for k in 'server answers' 'root geometry' 'parked windows' 'window placement' 'server started'; do
        printf '%s\n' "$out" | grep -q "$k" || missing="$missing [$k]"
      done
      eqck "DH23 all five checks are reported" "$missing" ""
      ck "DH23 ...root geometry carries a WxH, not just the label" \
         "$(printf '%s\n' "$out" | grep -qE '\[ok  \] root geometry +[0-9]+x[0-9]+' && echo 1 || echo 0)"
      case "${DISPLAY:-}" in
        :*) ck "DH23 ...server started carries a real timestamp from the socket" \
               "$(printf '%s\n' "$out" | grep -qE 'server started +[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} ' && echo 1 || echo 0)" ;;
        *)  ck "DH23 ...server started says WHY it has no timestamp on a hosted display" \
               "$(printf '%s\n' "$out" | grep -q 'server started.*no local socket' && echo 1 || echo 0)" ;;
      esac
      ck "DH24 the Fatal-server-error count is INFORMATION, never a verdict" \
         "$(printf '%s\n' "$out" | grep -q '^  \[info\] Fatal server error' && echo 1 || echo 0)"
      # nothing left behind on the display, from THAT run -- scoped to our tag,
      # because asserting over the whole display fails whenever another agent
      # runs the probe at the same time, and this script advertises being safe
      # to run while suites are in flight.
      ck "DH27 the probe window (tagged '$tag') is gone afterwards" \
         "$(! (timeout 10 xwininfo -root -tree 2>/dev/null | grep -q "wslg_health probe $tag") && echo 1 || echo 0)"
      ;;
  esac
  # ...and the branch asserted its FULL set of checks. Without this, a check
  # that quietly stops being asserted (DH22b used to, on any non-healthy
  # verdict) shrinks the run's check count and reds nothing -- and a shrinking
  # check count with nobody watching it is how a suite goes hollow. 10 in the
  # measuring branch, 0 in the partial-run branch, and both are deliberate:
  # change either only together with the checks themselves.
  case "$verdict" in
    STOPPED|DEFERRED) eqck "DH29 the panel held the probe, so the live arm asserted NO measurement" "$((CHECKS - livec0))" "0" ;;
    *)                eqck "DH29 the live arm asserted its full set of measurement checks" "$((CHECKS - livec0))" "10" ;;
  esac
  # AN EXPLICIT DISPLAY ARGUMENT MUST BE HONOURED OVER $DISPLAY -- and to prove
  # that, the argument has to DIFFER from $DISPLAY. Passing "$DISPLAY" itself
  # (as this check used to) holds whether the argument is read at all: deleting
  # the whole positional arm left it green.
  sockdir0="$TMP/xsock0"; mkdir -p "$sockdir0"
  # GUI_GATE_DIR neutralised: this check is about the ARGUMENT, not the panel,
  # and a Pause the user presses mid-run must not turn it red (nor hold it).
  aout="$(GUI_GATE_DIR="$TMP/gate_none" WSLG_HEALTH_SOCKET_DIR="$sockdir0" timeout 60 "$PROBE" :9 2>&1 | head -1)"
  ck "DH26 an explicit display argument is honoured over \$DISPLAY (:9, not $DISPLAY)" \
     "$(case "$aout" in *"display=:9"*) echo 1 ;; *) echo 0 ;; esac)"
  ck "DH26 ...and the current \$DISPLAY is not reported instead" \
     "$(case "$aout" in *"display=${DISPLAY}"*) echo 0 ;; *) echo 1 ;; esac)"
  # (DH27 -- the probe window is gone afterwards -- is asserted above, against
  # the SAME single run, rather than by starting another one.)
  # A HOSTED DISPLAY HAS NO LOCAL SOCKET. `localhost:N` is TCP on port 6000+N and
  # never uses /tmp/.X11-unix/XN; attributing this machine's socket to it made the
  # probe announce "the X server is wedged" (exit 1, with `fix: wsl --shutdown`)
  # about a display that is simply not listening -- measured on this healthy box.
  case "${DISPLAY:-}" in
    :*)
      n="${DISPLAY#:}"; n="${n%%.*}"
      # ...also shielded from the panel (a hosted display has no socket, so the
      # NODISPLAY early exit does not cover it) and run under $NOWIN so it can
      # never map a window: this check is about naming, not about placement.
      hout="$(env PATH="$NOWIN:$PATH" GUI_GATE_DIR="$TMP/gate_none" \
              WSLG_HEALTH_TIMEOUT=2 timeout 30 "$PROBE" "localhost:$n" 2>&1)"; hrc=$?
      hok=1
      [ "$hrc" = 1 ] && hok=0
      # the WORD "wedged" is fine in the UNKNOWN explanation ("no local socket to
      # tell 'absent' from 'wedged'"); the VERDICT is what must never say it.
      case "$hout" in *"VERDICT: UNHEALTHY"*) hok=0 ;; esac
      ck "DH28 a hosted display form (localhost:$n) is never called 'wedged' (rc=$hrc)" "$hok"
      ck "DH28 ...and it says WHY it cannot tell absent from wedged there" \
         "$(case "$hout" in *"no local socket"*|*"no X server there"*) echo 1 ;; *) echo 0 ;; esac)"
      ;;
    *) echo "info DH28 not run (\$DISPLAY is not a local :N display)" ;;
  esac
fi

echo "=== SAFETY arm (the contract) ==="

# no display at all is the LEGITIMATE headless case, not a fault, and must be
# distinguishable from a stub.
out="$(env -u DISPLAY "$PROBE" 2>&1)"; rc=$?
eqck "DH30 no DISPLAY -> exit 2 (not 0, not 1)" "$rc" "2"
ck "DH30 ...and says NODISPLAY, not STUB" \
   "$(case "$out" in *"VERDICT: NODISPLAY"*) echo 1 ;; *) echo 0 ;; esac)"

# THE full_audit LANDMINE. is_skip() scores a whole FILE as SKIP on any of these
# three substrings and silently discards every check that ran in it. The
# no-display case has to be reported some other way, and here it is.
# All three invocations are shielded from the panel and the live one runs under
# $NOWIN: this is a check about STRINGS. It used to map a real window (and, with
# no timeout on the `:77` run, hold for the full 300 s bound on a Pause).
allout="$(env -u DISPLAY GUI_GATE_DIR="$TMP/gate_none" timeout 60 "$PROBE" 2>&1
          env GUI_GATE_DIR="$TMP/gate_none" timeout 60 "$PROBE" :77 2>&1
          [ -n "${DISPLAY:-}" ] && env PATH="$NOWIN:$PATH" GUI_GATE_DIR="$TMP/gate_none" timeout 60 "$PROBE" 2>&1)"
ck "DH31 no output of this script ever contains a full_audit SKIP substring" \
   "$(case "$allout" in
        *"RESULT: SKIP"*|*"skipped: no X"*|*"SKIP: no X connection"*) echo 0 ;;
        *) echo 1 ;;
      esac)"

# a display number with no socket is ABSENT, not wedged and not a stub. Against
# such a display Xlib falls back to TCP and retries SYNs for minutes, so a
# timeout alone cannot tell the two apart; the socket is what does.
sockdir="$TMP/xsock"; mkdir -p "$sockdir"; mkdir -p "$TMP/gate_none"
# GUI_GATE_DIR neutralised (an empty dir -> the probe fails open) for the checks
# in this arm that are about the SOCKET, not about the panel: a Pause the user
# presses mid-run would otherwise turn them red instead of holding them, and the
# panel's own behaviour has its own arm below.
out="$(GUI_GATE_DIR="$TMP/gate_none" WSLG_HEALTH_SOCKET_DIR="$sockdir" "$PROBE" :9 2>&1)"; rc=$?
eqck "DH32 a display with no socket -> exit 2 NODISPLAY (never a false STUB)" "$rc" "2"
ck "DH32 ...and it names the display it was asked about, not \$DISPLAY" \
   "$(case "$out" in *"display=:9"*) echo 1 ;; *) echo 0 ;; esac)"

# ...and a display whose socket EXISTS but never answers is WEDGED, bounded by
# the timeout. This is also the only witness that a timeout is applied at all: a
# probe that hangs on a hung display is useless, so the whole run is itself
# wrapped in an outer timeout and must finish well inside it.
: > "$sockdir/X9"
t0=$(date +%s)
out="$(GUI_GATE_DIR="$TMP/gate_none" WSLG_HEALTH_SOCKET_DIR="$sockdir" WSLG_HEALTH_TIMEOUT=2 timeout 25 "$PROBE" :9 2>&1)"; rc=$?
t1=$(date +%s)
eqck "DH33 a socket that never answers -> exit 1 UNHEALTHY (wedged), not a hang" "$rc" "1"
ck "DH33 ...and it is the TIMEOUT that bounds it ($((t1-t0))s, well under the 25s outer limit)" \
   "$([ "$((t1-t0))" -lt 20 ] && echo 1 || echo 0)"
ck "DH33 ...and the verdict names the wedged server" \
   "$(case "$out" in *"wedged"*) echo 1 ;; *) echo 0 ;; esac)"

# (DH34/DH34b -- the probe must never create or write anything under $HOME, the
# gate dir included -- are asserted in the GATE arm below, where the full PATH
# shim exists: they need the $HOME-derived control file to be really READ, and
# they must not map a window to do it. See there.)

# a usage error must NOT borrow the "no display, and that is fine" code: a caller
# that acted on a typo as if the box were headless would get a silent, wrong
# all-clear, which is the class of bug this whole script exists to kill. That
# covers a bad OPTION and a bad DISPLAY VALUE alike -- `0` and `:O` used to be
# reported as "the legitimate headless case, not a fault".
"$PROBE" --bogus >/dev/null 2>&1
eqck "DH35 an unknown option exits 64 (EX_USAGE), never 2" "$?" "64"
"$PROBE" 0 >/dev/null 2>&1
eqck "DH35b a display with the colon forgotten ('0') exits 64, never 2" "$?" "64"
"$PROBE" :O >/dev/null 2>&1
eqck "DH35c a display with a letter O for zero (':O') exits 64, never 2" "$?" "64"
"$PROBE" :0 :55 >/dev/null 2>&1
eqck "DH35d two displays exits 64 -- the last must not silently win" "$?" "64"
GUI_GATE_DIR="$TMP/gate_none" WSLG_HEALTH_SOCKET_DIR="$TMP/xsock_empty" "$PROBE" :9.0 -q >/dev/null 2>&1; rc35e=$?
ck "DH35e a legitimate screen-qualified display (':9.0') is NOT a usage error (rc=$rc35e)" \
   "$([ "$rc35e" != 64 ] && echo 1 || echo 0)"

# only :N and unix/:N are socket-backed. localhost:N / 127.0.0.1:N are TCP on
# port 6000+N and have no socket in /tmp/.X11-unix at all.
eqck "DH36 wh_dpy_socket ':7' -> the local socket" "$(wh_dpy_socket :7)" "/tmp/.X11-unix/X7"
eqck "DH36 ...'unix/:7' -> the same socket" "$(wh_dpy_socket unix/:7)" "/tmp/.X11-unix/X7"
eqck "DH36 ...'localhost:7' (TCP) -> NO socket" "$(wh_dpy_socket localhost:7 || true)" ""
eqck "DH36 ...'127.0.0.1:7' (TCP) -> NO socket" "$(wh_dpy_socket 127.0.0.1:7 || true)" ""
eqck "DH36 ...'somehost:7' (remote) -> NO socket" "$(wh_dpy_socket somehost:7 || true)" ""

echo "=== E2E arm (the whole script, under a PATH shim of recorded values) ==="
# THE ONLY ARM THAT BINDS THE MEASURING TO THE VERDICT. Everything above either
# calls the pure judgement directly or asserts the shape of the live output, and
# a wslg_health.sh that ignored xwininfo and the Tk probe entirely and always
# printed HEALTHY passed all of it. Here the script runs for real, but xdpyinfo,
# xwininfo and wish are stubs emitting the values RECORDED on 2026-08-10 -- so
# any hardcoded root, tree or probe result inside the script contradicts them.
mkshim() {  # mkshim <dir> <rootW> <rootH> <tree-text> <probe-line>
  local d="$1" w="$2" h="$3" tree="$4" probe="$5"
  mkdir -p "$d"
  printf '%s\n' "$tree" > "$d/.tree"
  printf '#!/bin/sh\nexit 0\n' > "$d/xdpyinfo"
  cat > "$d/xwininfo" <<XW
#!/bin/sh
for a in "\$@"; do
  [ "\$a" = "-tree" ] && { cat "$d/.tree"; exit 0; }
done
printf '  Width: %s\n  Height: %s\n' "$w" "$h"
exit 0
XW
  cat > "$d/wish" <<WI
#!/bin/sh
echo "$probe"
exit 0
WI
  chmod +x "$d/xdpyinfo" "$d/xwininfo" "$d/wish"
}
shimrun() {  # shimrun <shimdir> <outfile> [VAR=VAL ...] [--] [args]
  # writes output to <outfile>, returns the probe's exit code.
  # GUI_GATE_DIR points at an EMPTY dir on purpose: these checks measure the
  # judgement, and the real control file must not be able to turn them red (nor
  # this test hold, silently, on a Pause aimed at a suite). The GATE arm below
  # points it at control files it writes itself. Later assignments win, so a
  # caller can override any of these.
  local d="$1" of="$2"; shift 2
  local sd="$TMP/shimsock"; mkdir -p "$sd" "$TMP/gate_none"; : > "$sd/X9"
  env PATH="$d:$PATH" WSLG_HEALTH_SOCKET_DIR="$sd" \
    WSLG_HEALTH_STDERR_LOG="$TMP/fatal2.log" \
    GUI_GATE_DIR="$TMP/gate_none" "$@" \
    timeout 60 "$PROBE" :9 > "$of" 2>&1
  return $?
}
printf 'Fatal server error:\nblah\nFatal server error:\n' > "$TMP/fatal2.log"

mkshim "$TMP/shim_stub" 640 480 "$STUB_TREE" \
       "PROBE want +200+200 got +-32730+-32709 screen 640x480"
shimrun "$TMP/shim_stub" "$TMP/out_stub"; src=$?
sout="$(cat "$TMP/out_stub")"
printf '%s\n' "$sout" | sed 's/^/     | /'
eqck "DH40 the RECORDED stub, driven through the whole script -> exit 1" "$src" "1"
ck "DH40 ...verdict UNHEALTHY, naming the stub as a stub" \
   "$(case "$sout" in *"VERDICT: UNHEALTHY"*"STUB DISPLAY"*) echo 1 ;; *) echo 0 ;; esac)"
ck "DH40 ...the root geometry it reports is the one xwininfo gave it (640x480)" \
   "$(case "$sout" in *"root=640x480"*) echo 1 ;; *) echo 0 ;; esac)"
ck "DH40 ...the placement it reports is the one the Tk probe gave it (+-32730+-32709)" \
   "$(case "$sout" in *"got +-32730+-32709"*) echo 1 ;; *) echo 0 ;; esac)"
ck "DH40 ...and the screen size the probe itself saw (640x480)" \
   "$(case "$sout" in *"screen 640x480"*) echo 1 ;; *) echo 0 ;; esac)"
eqck "DH40 ...all FOUR judgements flag it" "$(printf '%s\n' "$sout" | grep -c '\[STUB\]')" "4"
ck "DH40 ...including the parked window from the tree xwininfo gave it" \
   "$(printf '%s\n' "$sout" | grep -q '\[STUB\].*parked windows.*0x201d48' && echo 1 || echo 0)"

mkshim "$TMP/shim_good" 5120 1440 "$GOOD_TREE" \
       "PROBE want +200+200 got +206+227 screen 5120x1440"
shimrun "$TMP/shim_good" "$TMP/out_good"; grc=$?
gout="$(cat "$TMP/out_good")"
eqck "DH41 the RECORDED healthy machine, driven through the whole script -> exit 0" "$grc" "0"
ck "DH41 ...verdict HEALTHY" \
   "$(case "$gout" in *"VERDICT: HEALTHY"*) echo 1 ;; *) echo 0 ;; esac)"
eqck "DH41 ...with nothing flagged" "$(printf '%s\n' "$gout" | grep -c '\[STUB\]')" "0"
ck "DH41 ...reporting the root xwininfo gave it (5120x1440), not the live one" \
   "$(case "$gout" in *"root=5120x1440"*) echo 1 ;; *) echo 0 ;; esac)"
ck "DH41 ...and the placement the probe gave it (+206+227)" \
   "$(case "$gout" in *"got +206+227"*) echo 1 ;; *) echo 0 ;; esac)"
# -q is asserted HERE, under the shim, and not against the live display: it used
# to cost a second real probe window on the user's screen for a check about
# nothing but line count.
qout="$(env PATH="$TMP/shim_good:$PATH" WSLG_HEALTH_SOCKET_DIR="$TMP/shimsock" \
        WSLG_HEALTH_STDERR_LOG="$TMP/fatal2.log" GUI_GATE_DIR="$TMP/gate_none" \
        timeout 60 "$PROBE" -q :9 2>&1)"
eqck "DH25 -q prints the verdict and nothing else" "$(printf '%s\n' "$qout" | grep -c .)" "1"
ck "DH25 ...and that one line IS the verdict" \
   "$(case "$qout" in "VERDICT: HEALTHY"*) echo 1 ;; *) echo 0 ;; esac)"

# the same healthy machine with one window mid-map: the transient WM frame is in
# BOTH shim samples here (the shim cannot vary), so this instead pins the other
# half of the two-sample rule -- see DH10d/DH19f for the transient case.
mkshim "$TMP/shim_parked" 5120 1440 "$TRANSIENT_TREE" \
       "PROBE want +200+200 got +206+227 screen 5120x1440"
shimrun "$TMP/shim_parked" "$TMP/out_parked"; prc2=$?
pout="$(cat "$TMP/out_parked")"
eqck "DH42 a genuinely parked window with an otherwise healthy display -> exit 1" "$prc2" "1"
eqck "DH42 ...and it is the SENTINEL check alone that says so" \
     "$(printf '%s\n' "$pout" | grep -c '\[STUB\]')" "1"

# THE PLACEMENT PROBE IS BEST-OF-N. MEASURED on the healthy display: the WM
# occasionally ignores the requested position outright and maps at the origin
# (`want +437+311 got +6+27`) -- 1 in 15 in one burst, 0 in 45 and 0 in 30
# elsewhere. One attempt makes the script cry STUB about a display that is fine.
# A stub, by contrast, fails EVERY attempt. Shim a wish that misplaces the first
# window and places the second correctly.
mkdir -p "$TMP/shim_retry"
cp "$TMP/shim_good/xdpyinfo" "$TMP/shim_good/xwininfo" "$TMP/shim_good/.tree" "$TMP/shim_retry/"
sed -i "s#$TMP/shim_good#$TMP/shim_retry#g" "$TMP/shim_retry/xwininfo"
cat > "$TMP/shim_retry/wish" <<WIR
#!/bin/sh
d="$TMP/shim_retry"
n=\$(cat "\$d/.n" 2>/dev/null || echo 0); n=\$((n+1)); echo "\$n" > "\$d/.n"
if [ "\$n" = "1" ]; then
  echo "PROBE want +200+200 got +6+27 screen 5120x1440"
else
  echo "PROBE want +200+200 got +206+227 screen 5120x1440"
fi
exit 0
WIR
chmod +x "$TMP/shim_retry/wish"; rm -f "$TMP/shim_retry/.n"
shimrun "$TMP/shim_retry" "$TMP/out_retry"; rrc=$?
rout="$(cat "$TMP/out_retry")"
eqck "DH45 a one-off WM misplacement is retried, not condemned -> exit 0" "$rrc" "0"
eqck "DH45 ...the probe really ran twice" "$(cat "$TMP/shim_retry/.n" 2>/dev/null || echo 0)" "2"
ck "DH45 ...and the retry is reported, never hidden" \
   "$(printf '%s\n' "$rout" | grep -q 'placement attempts *2 of 3' && echo 1 || echo 0)"
# ...and a STUB fails every attempt, so retrying never launders one green.
mkdir -p "$TMP/shim_always_bad"
cp "$TMP/shim_stub/xdpyinfo" "$TMP/shim_stub/xwininfo" "$TMP/shim_stub/.tree" "$TMP/shim_always_bad/"
sed -i "s#$TMP/shim_stub#$TMP/shim_always_bad#g" "$TMP/shim_always_bad/xwininfo"
cat > "$TMP/shim_always_bad/wish" <<WIB
#!/bin/sh
d="$TMP/shim_always_bad"
n=\$(cat "\$d/.n" 2>/dev/null || echo 0); echo \$((n+1)) > "\$d/.n"
echo "PROBE want +200+200 got +-32730+-32709 screen 640x480"
exit 0
WIB
chmod +x "$TMP/shim_always_bad/wish"; rm -f "$TMP/shim_always_bad/.n"
shimrun "$TMP/shim_always_bad" "$TMP/out_bad"; brc=$?
eqck "DH45b a STUB fails every attempt -> still exit 1" "$brc" "1"
eqck "DH45b ...and it gave up after exactly 3 attempts, never looping" \
     "$(cat "$TMP/shim_always_bad/.n" 2>/dev/null || echo 0)" "3"

# THE BLOCKER, END TO END. The shims above answer every `xwininfo -tree` the
# same way, so they cannot tell "the script takes TWO samples" from "the script
# takes one and uses it twice". This shim answers the FIRST call with a tree
# carrying the transient WM pre-placement frame and the SECOND with a clean one
# -- exactly what the healthy display does while any window is mapping. A
# wh_main that sampled once (or passed the same sample twice) condemns it.
mkdir -p "$TMP/shim_alt"
printf '%s\n' "$TRANSIENT_TREE" > "$TMP/shim_alt/.tree1"
printf '%s\n' "$GOOD_TREE"      > "$TMP/shim_alt/.tree2"
printf '#!/bin/sh\nexit 0\n' > "$TMP/shim_alt/xdpyinfo"
cat > "$TMP/shim_alt/xwininfo" <<XWA
#!/bin/sh
d="$TMP/shim_alt"
for a in "\$@"; do
  if [ "\$a" = "-tree" ]; then
    n=\$(cat "\$d/.n" 2>/dev/null || echo 0); n=\$((n+1)); echo "\$n" > "\$d/.n"
    if [ "\$n" = "1" ]; then cat "\$d/.tree1"; else cat "\$d/.tree2"; fi
    exit 0
  fi
done
printf '  Width: 5120\n  Height: 1440\n'
exit 0
XWA
cat > "$TMP/shim_alt/wish" <<'WIA'
#!/bin/sh
echo "PROBE want +200+200 got +206+227 screen 5120x1440"
exit 0
WIA
chmod +x "$TMP/shim_alt/xdpyinfo" "$TMP/shim_alt/xwininfo" "$TMP/shim_alt/wish"
rm -f "$TMP/shim_alt/.n"
shimrun "$TMP/shim_alt" "$TMP/out_alt"; arc2=$?
aout2="$(cat "$TMP/out_alt")"
eqck "DH44 a healthy display with a window mid-map at sample 1 -> exit 0, not a false stub" "$arc2" "0"
ck "DH44 ...and the script really took TWO tree samples (the frame is gone from the second)" \
   "$(printf '%s\n' "$aout2" | grep -q 'parked windows.*transient' && echo 1 || echo 0)"
eqck "DH44 ...xwininfo -tree was called exactly twice" "$(cat "$TMP/shim_alt/.n" 2>/dev/null || echo 0)" "2"

# the [info] Fatal-server-error count is one line and a bare integer, on a log
# with matches AND on a clean-boot log with none (`grep -c` prints 0 and exits 1,
# so a `|| echo 0` fallback used to append a second 0 and split the line).
eqck "DH43 the Fatal-server-error count is ONE line" \
     "$(printf '%s\n' "$gout" | grep -c 'Fatal server error')" "1"
eqck "DH43 ...and reports the number of blocks in the log (2)" \
     "$(printf '%s\n' "$gout" | sed -n 's/.*Fatal server error *\([0-9]*\) so far.*/\1/p')" "2"
: > "$TMP/fatal0.log"
# GUI_GATE_DIR neutralised like its siblings: this is a check about a log file,
# and a Pause the user presses mid-run used to hold it until its own `timeout 60`
# killed it, leaving $zout empty and DH43 red twice over.
zout="$(PATH="$TMP/shim_good:$PATH" WSLG_HEALTH_SOCKET_DIR="$TMP/shimsock" \
        GUI_GATE_DIR="$TMP/gate_none" \
        WSLG_HEALTH_STDERR_LOG="$TMP/fatal0.log" timeout 60 "$PROBE" :9 2>&1)"
eqck "DH43 ...a clean boot (zero blocks) is ALSO one line" \
     "$(printf '%s\n' "$zout" | grep -c 'Fatal server error')" "1"
eqck "DH43 ...reading 0, not '0\\n0'" \
     "$(printf '%s\n' "$zout" | sed -n 's/.*Fatal server error *\([0-9]*\) so far.*/\1/p')" "0"

echo "=== GATE arm (the probe MAPS A WINDOW, so it answers Pause and Stop) ==="
# THE INVARIANT THIS ARM DEFENDS, and the reason the previous attempt at this
# item was stopped. Check 5 puts a real top-level ON THE USER'S SCREEN. The
# first draft consulted nothing: little probe windows flashed past during a
# sabotage run, the user pressed Pause on the control panel, and NOTHING
# STOPPED. Anything that paints on that screen must answer that button.
#
# Everything here runs under the PATH shim, so no window is mapped even when the
# gate is wide open -- and the shim's `wish` COUNTS ITS CALLS, which is what
# turns "it obeyed" into evidence rather than into a verdict word: a probe that
# obeys Pause calls wish EXACTLY ZERO times. The control files are all written
# under $TMP; ~/.claude/gui_test_gate/ is never written to by this test, and the
# probe only ever READS it.
GATE="$TMP/gate"; mkdir -p "$GATE"
mkdir -p "$TMP/shim_gate"
cp "$TMP/shim_good/xdpyinfo" "$TMP/shim_good/xwininfo" "$TMP/shim_good/.tree" "$TMP/shim_gate/"
sed -i "s#$TMP/shim_good#$TMP/shim_gate#g" "$TMP/shim_gate/xwininfo"
cat > "$TMP/shim_gate/wish" <<WG
#!/bin/sh
echo x >> "$TMP/shim_gate/.wish"
echo "PROBE want +200+200 got +206+227 screen 5120x1440"
exit 0
WG
chmod +x "$TMP/shim_gate/wish"
gwish=0
gaterun() {  # gaterun <control-word|-> <outfile> [VAR=VAL ...]; sets $gwish
  local word="$1" of="$2" rc; shift 2
  rm -f "$TMP/shim_gate/.wish"
  if [ "$word" = "-" ]; then rm -f "$GATE/control"; else printf '%s' "$word" > "$GATE/control"; fi
  shimrun "$TMP/shim_gate" "$of" GUI_GATE_DIR="$GATE" \
          WSLG_HEALTH_GATE_WAIT=2 WSLG_HEALTH_GATE_POLL=0.2 "$@"
  rc=$?
  gwish="$(grep -c . "$TMP/shim_gate/.wish" 2>/dev/null || echo 0)"
  return "$rc"
}

# --- STOP: map nothing, say so, and use a code of its own -------------------
gaterun STOP "$TMP/g_stop"; rc=$?; stoprc=$rc
gsout="$(cat "$TMP/g_stop")"
printf '%s\n' "$gsout" | sed 's/^/     | /'
eqck "DH50 control=STOP -> exit 4, a code of its own" "$rc" "4"
eqck "DH50 ...AND NOTHING WAS MAPPED: the shim's wish was never called" "$gwish" "0"
ck "DH50 ...verdict STOPPED, saying plainly that the display was NOT measured" \
   "$(case "$gsout" in *"VERDICT: STOPPED"*"NOT measured"*) echo 1 ;; *) echo 0 ;; esac)"
ck "DH50 ...and it is NOT dressed up as a health failure (no UNHEALTHY, no STUB verdict)" \
   "$(case "$gsout" in *"VERDICT: UNHEALTHY"*|*"STUB DISPLAY"*) echo 0 ;; *) echo 1 ;; esac)"

# --- PAUSE that never lifts: hold, then DEFER -- bounded ---------------------
t0=$(date +%s)
gaterun PAUSE "$TMP/g_pause"; rc=$?; defrc=$rc
t1=$(date +%s)
gpout="$(cat "$TMP/g_pause")"
printf '%s\n' "$gpout" | sed 's/^/     | /'
eqck "DH51 control=PAUSE that never lifts -> exit 5 (DEFERRED), never 0 and never 1" "$rc" "5"
eqck "DH51 ...AND NOTHING WAS MAPPED: the shim's wish was never called" "$gwish" "0"
ck "DH51 ...the wait is BOUNDED, so a forgotten Pause cannot hang a suite (took $((t1-t0))s, bound 2s)" \
   "$([ "$((t1-t0))" -lt 20 ] && echo 1 || echo 0)"
ck "DH51 ...verdict DEFERRED = 'not measured', which is neither healthy nor stub" \
   "$(case "$gpout" in *"VERDICT: DEFERRED"*"NOT measured"*) echo 1 ;; *) echo 0 ;; esac)"
ck "DH51 ...and it tells the user how to get a measurement (Resume, re-run)" \
   "$(case "$gpout" in *Resume*) echo 1 ;; *) echo 0 ;; esac)"

# --- PAUSE that is RESUMED: it POLLS, it does not just time out --------------
# Without this, a probe that slept out the whole bound and then happened to find
# RUN would look identical to one that never watched the file at all.
printf 'PAUSE' > "$GATE/control"
( sleep 1; printf 'RUN' > "$GATE/control" ) &
flip=$!
t0=$(date +%s)
gaterun PAUSE "$TMP/g_flip" WSLG_HEALTH_GATE_WAIT=30; rc=$?
t1=$(date +%s)
wait "$flip" 2>/dev/null
eqck "DH52 a PAUSE that is RESUMED mid-wait -> the probe proceeds (exit 0)" "$rc" "0"
eqck "DH52 ...and only THEN maps its window (wish called exactly once, after the resume)" "$gwish" "1"
ck "DH52 ...having really waited for the button rather than timed out ($((t1-t0))s held, bound 30s)" \
   "$([ "$((t1-t0))" -ge 1 ] && [ "$((t1-t0))" -lt 25 ] && echo 1 || echo 0)"

# --- FAIL OPEN, exactly like the rest of the gate ----------------------------
gaterun RUN "$TMP/g_run"; rc=$?
eqck "DH53 control=RUN -> the probe runs normally (exit 0)" "$rc" "0"
eqck "DH53 ...and it did map (wish called once)" "$gwish" "1"
gaterun - "$TMP/g_nofile"; rc=$?
eqck "DH54 no control file -> proceed (fail open), exit 0" "$rc" "0"
eqck "DH54 ...and it mapped" "$gwish" "1"
rm -f "$TMP/shim_gate/.wish"
shimrun "$TMP/shim_gate" "$TMP/g_nodir" GUI_GATE_DIR="$TMP/no_such_gate_dir"; rc=$?
eqck "DH54b no gate dir at all -> proceed (a box with no panel must still be probeable)" "$rc" "0"
rm -rf "$GATE/control"; mkdir -p "$GATE/control"   # unreadable: cat of a directory
rm -f "$TMP/shim_gate/.wish"
shimrun "$TMP/shim_gate" "$TMP/g_unread" GUI_GATE_DIR="$GATE"; rc=$?
rmdir "$GATE/control"
eqck "DH55 an unreadable control file -> proceed (fail open), never a silent hold" "$rc" "0"

# --- GUI_GATE=0 DOES NOT BUY AN EXEMPTION ------------------------------------
# Ruling, written up in doc/claude/specs/wslg_health_probe.md: GUI_GATE=0 means
# "do not stop to ask permission". PAUSE/STOP is not a question -- it is a
# standing order from a user who is at the keyboard and has pressed a button.
gaterun STOP "$TMP/g_g0" GUI_GATE=0; rc=$?
eqck "DH56 GUI_GATE=0 does NOT exempt the probe from STOP (still exit 4)" "$rc" "4"
eqck "DH56 ...and still nothing mapped" "$gwish" "0"

# --- the caller can tell 'not measured' from both healthy and stub -----------
# The four codes ACTUALLY OBSERVED in this run, not four literals: $grc is the
# recorded-healthy machine (DH41), $src the recorded stub (DH40), and the two
# holds above. Fold any pair together -- deferred reported as unhealthy, say --
# and this reads 3.
eqck "DH57 healthy($grc) / stub($src) / stopped($stoprc) / deferred($defrc) are four DISTINCT exit codes" \
     "$(printf '%s\n' "$grc" "$src" "$stoprc" "$defrc" | sort -u | grep -c .)" "4"
ck "DH57 ...and neither hold prints a full_audit SKIP substring" \
   "$(case "$gsout$gpout" in
        *"RESULT: SKIP"*|*"skipped: no X"*|*"SKIP: no X connection"*) echo 0 ;;
        *) echo 1 ;;
      esac)"

# --- READ ONLY. The gate dir belongs to the user and to the panel ------------
printf 'RUN' > "$GATE/control"
before="$(cd "$GATE" && find . -printf '%p %s %T@\n' | sort)"
rm -f "$TMP/shim_gate/.wish"
shimrun "$TMP/shim_gate" "$TMP/g_ro" GUI_GATE_DIR="$GATE"
after="$(cd "$GATE" && find . -printf '%p %s %T@\n' | sort)"
eqck "DH58 the probe never WRITES into the gate dir -- names, sizes and mtimes all unchanged" "$after" "$before"

# --- ...and the same, for the $HOME-DERIVED default gate dir -----------------
# The path EVERY ordinary invocation takes: WH_GATE_DIR defaults to
# $HOME/.claude/gui_test_gate. Two properties, both under the shim so nothing is
# mapped and neither can be held by the real panel (they read a control file
# under $TMP):
#   DH34  -- a $HOME with no .claude in it must stay that way. The probe must
#            never create the gate dir; a box with no panel is still probeable.
#   DH34b -- a $HOME that DOES have one has it READ and not written.
# DH34 used to run the REAL probe with $HOME redirected and GUI_GATE_DIR unset,
# on the live display: the gate dir it consulted was $fakehome's, which does not
# exist, so it failed open and mapped a real top-level whatever the user's own
# panel said -- one ungated window per run, in the file whose subject is that
# windows are gated.
fakehome="$TMP/home"; mkdir -p "$fakehome"
env -u GUI_GATE_DIR PATH="$TMP/shim_gate:$PATH" WSLG_HEALTH_SOCKET_DIR="$TMP/shimsock" \
    WSLG_HEALTH_STDERR_LOG="$TMP/fatal2.log" HOME="$fakehome" \
    timeout 60 "$PROBE" :9 >/dev/null 2>&1
ck "DH34 running the probe creates nothing under \$HOME/.claude (a box with no panel is still probeable)" \
   "$([ ! -e "$fakehome/.claude" ] && echo 1 || echo 0)"
fakehome2="$TMP/home2"; mkdir -p "$fakehome2/.claude/gui_test_gate"
printf 'RUN' > "$fakehome2/.claude/gui_test_gate/control"
h2before="$(cd "$fakehome2" && find . -printf '%p %s %T@\n' | sort)"
rm -f "$TMP/shim_gate/.wish"
env -u GUI_GATE_DIR PATH="$TMP/shim_gate:$PATH" WSLG_HEALTH_SOCKET_DIR="$TMP/shimsock" \
    WSLG_HEALTH_STDERR_LOG="$TMP/fatal2.log" HOME="$fakehome2" \
    timeout 60 "$PROBE" :9 >/dev/null 2>&1
h2after="$(cd "$fakehome2" && find . -printf '%p %s %T@\n' | sort)"
eqck "DH34b the \$HOME-derived gate dir is READ, never written (names, sizes, mtimes unchanged)" "$h2after" "$h2before"
# ...and that read really happened -- otherwise DH34b would pass on a probe that
# ignores $HOME entirely. STOP in the $HOME-derived control file must stop it.
printf 'STOP' > "$fakehome2/.claude/gui_test_gate/control"
rm -f "$TMP/shim_gate/.wish"
env -u GUI_GATE_DIR PATH="$TMP/shim_gate:$PATH" WSLG_HEALTH_SOCKET_DIR="$TMP/shimsock" \
    WSLG_HEALTH_STDERR_LOG="$TMP/fatal2.log" HOME="$fakehome2" \
    timeout 60 "$PROBE" :9 >/dev/null 2>&1; rc=$?
printf 'RUN' > "$fakehome2/.claude/gui_test_gate/control"
eqck "DH34c ...and the \$HOME-derived control file is really CONSULTED (STOP there -> exit 4)" "$rc" "4"
eqck "DH34c ...nothing mapped" "$(grep -c . "$TMP/shim_gate/.wish" 2>/dev/null || echo 0)" "0"

# --- THE SECOND CONSULT: a Pause pressed AFTER the run started ---------------
# The load-bearing one. A probe that reads the control file once at startup and
# then goes off to run xdpyinfo and two xwininfo calls will still put a window
# on the screen of a user who pressed Pause in between -- which is exactly the
# complaint. This shim presses the button FOR the user, from inside the
# `xwininfo -root -tree` call, i.e. after the first consult and before the probe.
mkdir -p "$TMP/shim_flip"
printf '%s\n' "$GOOD_TREE" > "$TMP/shim_flip/.tree"
printf '#!/bin/sh\nexit 0\n' > "$TMP/shim_flip/xdpyinfo"
cat > "$TMP/shim_flip/xwininfo" <<XF
#!/bin/sh
for a in "\$@"; do
  if [ "\$a" = "-tree" ]; then
    cat "$TMP/shim_flip/.flipword" > "$GATE/control"   # <- the user presses it now
    cat "$TMP/shim_flip/.tree"
    exit 0
  fi
done
printf '  Width: 5120\n  Height: 1440\n'
exit 0
XF
cat > "$TMP/shim_flip/wish" <<WF
#!/bin/sh
echo x >> "$TMP/shim_flip/.wish"
echo "PROBE want +200+200 got +206+227 screen 5120x1440"
exit 0
WF
chmod +x "$TMP/shim_flip/xdpyinfo" "$TMP/shim_flip/xwininfo" "$TMP/shim_flip/wish"
midrun() {  # midrun <word-pressed-mid-run> <outfile>; sets $fwish
  local word="$1" of="$2" rc
  printf 'RUN' > "$GATE/control"
  printf '%s' "$word" > "$TMP/shim_flip/.flipword"
  rm -f "$TMP/shim_flip/.wish"
  shimrun "$TMP/shim_flip" "$of" GUI_GATE_DIR="$GATE" \
          WSLG_HEALTH_GATE_WAIT=2 WSLG_HEALTH_GATE_POLL=0.2
  rc=$?
  fwish="$(grep -c . "$TMP/shim_flip/.wish" 2>/dev/null || echo 0)"
  return "$rc"
}
fwish=0
midrun PAUSE "$TMP/g_mid_pause"; rc=$?
eqck "DH59 a Pause pressed AFTER the run started (control=RUN at launch) -> exit 5" "$rc" "5"
eqck "DH59 ...AND STILL NOTHING WAS MAPPED: wish never called" "$fwish" "0"
ck "DH59 ...the report names where it was consulted (immediately before the probe)" \
   "$(grep -q 'immediately before the Tk probe' "$TMP/g_mid_pause" && echo 1 || echo 0)"
midrun STOP "$TMP/g_mid_stop"; rc=$?
eqck "DH60 a Stop pressed AFTER the run started -> exit 4, nothing mapped" "$rc" "4"
eqck "DH60 ...wish never called" "$fwish" "0"
# ...and the same shim with the button NEVER pressed still maps: without this,
# a probe that simply refused to run always would pass DH59 and DH60.
midrun RUN "$TMP/g_mid_run"; rc=$?
eqck "DH61 the same run with nobody pressing anything -> exit 0" "$rc" "0"
eqck "DH61 ...and it DID map (wish called once) -- so DH59/DH60 measure the button, not a dead probe" "$fwish" "1"
printf 'RUN' > "$GATE/control"

# --- THE BUTTON PRESSED BETWEEN TWO PROBE WINDOWS ---------------------------
# THE BLOCKER THIS ROUND FIXED. The consult used to sit OUTSIDE the best-of-3
# retry loop, so only the FIRST window was gated: with the button pressed the
# instant probe window 1 appeared, the probe mapped two MORE and then reported a
# health verdict (exit 1) instead of STOPPED/DEFERRED. It fires HARDEST on the
# very display this script exists to detect -- a stub misplaces every attempt,
# so it always takes all three. DH59/DH60 could not see it: their shim returns a
# MATCHING placement, so the loop never iterates.
# This shim's `wish` counts its calls, presses the button on its FIRST call, and
# returns a MISPLACED window so the loop wants to retry.
mkdir -p "$TMP/shim_press"
cp "$TMP/shim_good/xdpyinfo" "$TMP/shim_good/xwininfo" "$TMP/shim_good/.tree" "$TMP/shim_press/"
sed -i "s#$TMP/shim_good#$TMP/shim_press#g" "$TMP/shim_press/xwininfo"
cat > "$TMP/shim_press/wish" <<WP
#!/bin/sh
d="$TMP/shim_press"
echo x >> "\$d/.wish"
n=\$(grep -c . "\$d/.wish" 2>/dev/null || echo 0)
[ "\$n" = "1" ] && cat "\$d/.word" > "$GATE/control"   # <- the user presses it
echo "PROBE want +200+200 got +-32730+-32709 screen 5120x1440"
exit 0
WP
chmod +x "$TMP/shim_press/wish"
pressrun() {  # pressrun <word-pressed-at-window-1> <outfile>; sets $pwish
  local word="$1" of="$2" rc
  printf 'RUN' > "$GATE/control"
  printf '%s' "$word" > "$TMP/shim_press/.word"
  rm -f "$TMP/shim_press/.wish"
  shimrun "$TMP/shim_press" "$of" GUI_GATE_DIR="$GATE" \
          WSLG_HEALTH_GATE_WAIT=2 WSLG_HEALTH_GATE_POLL=0.2
  rc=$?
  pwish="$(grep -c . "$TMP/shim_press/.wish" 2>/dev/null || echo 0)"
  return "$rc"
}
pwish=0
pressrun STOP "$TMP/g_press_stop"; rc=$?
eqck "DH62 a Stop pressed the instant the FIRST probe window appears -> exit 4" "$rc" "4"
eqck "DH62 ...AND NO SECOND WINDOW: wish called exactly once, not three times" "$pwish" "1"
ck "DH62 ...and it reports STOPPED, not a health verdict about a display it stopped measuring" \
   "$(case "$(cat "$TMP/g_press_stop")" in *"VERDICT: STOPPED"*) echo 1 ;; *) echo 0 ;; esac)"
pressrun PAUSE "$TMP/g_press_pause"; rc=$?
eqck "DH63 a Pause pressed the instant the first probe window appears -> exit 5 (DEFERRED)" "$rc" "5"
eqck "DH63 ...and no further window: wish called exactly once" "$pwish" "1"
# ...and with nobody pressing, the SAME misplacing shim really does take all
# three attempts -- so DH62/DH63 measure the button and not a probe that stopped
# retrying.
pressrun RUN "$TMP/g_press_run"; rc=$?
eqck "DH64 the same misplacing shim with nobody pressing -> all 3 attempts taken" "$pwish" "3"
eqck "DH64 ...and it is judged a stub (exit 1), the pre-existing best-of-3 behaviour" "$rc" "1"

# --- A TUNABLE TYPO IS NOT A BROKEN DISPLAY ---------------------------------
# `$(( t0 + WH_GATE_WAIT ))` with a non-integer bound aborted bash while HOLDING:
# no VERDICT line at all and exit 1, which every caller reads as "stub display,
# GUI results are meaningless" -- a hold reported as a broken display, the exact
# confusion codes 4 and 5 exist to prevent. A fractional bound is easy to write:
# the poll interval beside it documents fractions, and this file uses 0.2.
gaterun PAUSE "$TMP/g_frac" WSLG_HEALTH_GATE_WAIT=2.5; rc=$?
gfout="$(cat "$TMP/g_frac")"
eqck "DH65 a fractional bound (2.5) still DEFERS -> exit 5, never a bare exit 1" "$rc" "5"
ck "DH65 ...it printed a VERDICT rather than dying in the arithmetic" \
   "$(case "$gfout" in *"VERDICT: DEFERRED"*) echo 1 ;; *) echo 0 ;; esac)"
ck "DH65 ...with no shell syntax error anywhere in the output" \
   "$(printf '%s\n' "$gfout" | grep -qi 'syntax error' && echo 0 || echo 1)"
eqck "DH65 ...and still nothing mapped" "$gwish" "0"
# ...and a bound that is not a number at all falls back to the DEFAULT (300s) and
# says so, rather than obeying a typo or crashing. Killed at 5s while it is still
# holding -- which is the evidence that it took the default and is waiting.
printf 'PAUSE' > "$GATE/control"
rm -f "$TMP/shim_gate/.wish"
env PATH="$TMP/shim_gate:$PATH" WSLG_HEALTH_SOCKET_DIR="$TMP/shimsock" \
    WSLG_HEALTH_STDERR_LOG="$TMP/fatal2.log" GUI_GATE_DIR="$GATE" \
    WSLG_HEALTH_GATE_WAIT=soon WSLG_HEALTH_GATE_POLL=0.2 \
    timeout 5 "$PROBE" :9 > "$TMP/g_garb" 2>&1; rc=$?
gwish="$(grep -c . "$TMP/shim_gate/.wish" 2>/dev/null || echo 0)"
printf 'RUN' > "$GATE/control"
eqck "DH66 a nonsense bound falls back to the default: still holding when killed at 5s" "$rc" "124"
ck "DH66 ...and says so on stderr instead of obeying the typo silently" \
   "$(grep -q "WSLG_HEALTH_GATE_WAIT='soon' is not a whole number" "$TMP/g_garb" && echo 1 || echo 0)"
ck "DH66 ...it is HOLDING, not crashed: nothing mapped and no shell syntax error" \
   "$([ "$gwish" = 0 ] && ! grep -qi 'syntax error' "$TMP/g_garb" && echo 1 || echo 0)"

# --- A DISPLAY WITH NO SERVER IS NOT SOMETHING TO HOLD FOR ------------------
# The panel used to be consulted BEFORE the socket check, so a display number
# with nothing behind it -- where there is no screen to paint on and nothing to
# see -- held for the full bound and then reported DEFERRED instead of
# NODISPLAY. An invented hold, and the cause of two unrelated checks in this file
# going red whenever the panel was paused.
mkdir -p "$TMP/xsock_empty2"
printf 'PAUSE' > "$GATE/control"
t0=$(date +%s)
nout="$(GUI_GATE_DIR="$GATE" WSLG_HEALTH_SOCKET_DIR="$TMP/xsock_empty2" \
        WSLG_HEALTH_GATE_WAIT=30 WSLG_HEALTH_GATE_POLL=0.2 timeout 60 "$PROBE" :9 2>&1)"; rc=$?
t1=$(date +%s)
printf 'RUN' > "$GATE/control"
eqck "DH67 a display with NO server, while the panel is PAUSED -> NODISPLAY 2, not a hold" "$rc" "2"
ck "DH67 ...and it did not wait for the bound ($((t1-t0))s of 30s): nothing there to map" \
   "$([ "$((t1-t0))" -lt 5 ] && echo 1 || echo 0)"
ck "DH67 ...the verdict is NODISPLAY, not DEFERRED" \
   "$(case "$nout" in *"VERDICT: NODISPLAY"*) echo 1 ;; *) echo 0 ;; esac)"

echo "RESULT fails=$FAILS checks=$CHECKS"
exit $((FAILS ? 1 : 0))
