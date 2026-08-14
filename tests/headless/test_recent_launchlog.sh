#!/bin/sh
# Recent-files protection + launch-line logging (pre-default-on cleanups).
#
# 1) The recent-views list ($HOME/.xschem/recent_files) BELONGS TO THE USER: scripted/test
#    sessions (--nogui or --pipe), and any session launched with --norecent, must never
#    create or rewrite it. A normal user-mode session (none of those flags) still updates it.
#    A --script startup file is gated only for the DURATION of the script body (its programmatic
#    loads); a file the user opens AFTER the script (event loop) still records -- rails 4b/4c.
# 2) The action log (Xschem.log) records the full launch command line + cwd as Tcl-comment
#    header lines, so a log found later can be traced back to the exact invocation.
#
#   sh tests/headless/test_recent_launchlog.sh
#
# Prints "RESULT: ALL PASS" / "RESULT: N FAILED" and exits nonzero on failure.

HERE=$(cd "$(dirname "$0")" && pwd)

# Route this run onto the private/persistent GUI-test display instead of the
# screen it was launched from (tests/headless/xvfb_arm.sh, spec
# doc/claude/specs/dev_display.md). POSIX sh cannot source the arm -- it is
# bash -- so re-exec through its --arm entry. AUDIT_DISPLAY=:0 opts back in.
[ "${XSCHEM_XVFB_ARM:-0}" = 1 ] || exec bash "$HERE/xvfb_arm.sh" --arm sh "$0" "$@"
REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="$REPO/src/xschem"
TMP=$(mktemp -d /tmp/xschem_recent_test.XXXXXX)
SCH="$REPO/tests/from_user/before_3.sch"
fail=0

ok()   { echo "ok:   $1"; }
bad()  { echo "FAIL: $1"; fail=$((fail+1)); }

# a script that loads a real schematic (drives update_recent_file) then quits
cat > "$TMP/load_quit.tcl" <<EOF
xschem load {$SCH}
xschem exit closewindow force
EOF

# 1) headless test-style run (--nogui --pipe): must NOT create recent_files
H1="$TMP/home1"; mkdir -p "$H1"
HOME="$H1" timeout 30 "$XSCHEM" --nogui --pipe -q --nolog --script "$TMP/load_quit.tcl" >/dev/null 2>&1
if [ -f "$H1/.xschem/recent_files" ]; then
  bad "--nogui --pipe run wrote \$HOME/.xschem/recent_files (user list corrupted)"
else ok "--nogui --pipe run leaves recent_files alone"; fi

# 2) --pipe alone (X-driven GUI tests use this too): must NOT create recent_files
H2="$TMP/home2"; mkdir -p "$H2"
HOME="$H2" timeout 30 "$XSCHEM" --pipe -q -x --nolog --script "$TMP/load_quit.tcl" >/dev/null 2>&1
if [ -f "$H2/.xschem/recent_files" ]; then
  bad "--pipe run wrote recent_files"
else ok "--pipe run leaves recent_files alone"; fi

# 3) --norecent in an otherwise user-mode launch: must NOT create recent_files,
#    and the load must still have happened (the option must be accepted, not fatal)
H3="$TMP/home3"; mkdir -p "$H3"
HOME="$H3" timeout 30 "$XSCHEM" -q -r -x --nolog --norecent --script "$TMP/load_quit.tcl" >/dev/null 2>&1
rc=$?
if [ "$rc" = "0" ]; then ok "--norecent accepted (exit 0)"; else bad "--norecent run exited rc=$rc"; fi
if [ -f "$H3/.xschem/recent_files" ]; then
  bad "--norecent run wrote recent_files"
else ok "--norecent run leaves recent_files alone"; fi

# 4) POSITIVE rail: a genuine user-mode session (no --nogui/--pipe/--norecent/--script) still
#    records the loaded file -- protection must not kill the feature for real users. A real user
#    opens a file via a positional arg (or File>Open in the GUI). A canned --script's own loads
#    are automation (gated for the script body, see rail 4b) but a file opened AFTER the script
#    still records (rail 4c). The startup load writes recent_files during init;
#    the process then sits in the GUI event loop, so launch it in the background, wait for the
#    write, then kill it. (-x is required, as in rails 2/3.)
H4="$TMP/home4"; mkdir -p "$H4"
HOME="$H4" "$XSCHEM" -q -r -x --nolog "$SCH" >/dev/null 2>&1 &
h4pid=$!
for _ in $(seq 1 50); do [ -f "$H4/.xschem/recent_files" ] && break; sleep 0.2; done
kill "$h4pid" 2>/dev/null; wait "$h4pid" 2>/dev/null
if [ -f "$H4/.xschem/recent_files" ] && grep -q "before_3.sch" "$H4/.xschem/recent_files"; then
  ok "user-mode positional-arg run still records the file in recent_files"
else bad "user-mode run did not update recent_files (feature broken)"; fi

# 4b) REGRESSION rail: a --script startup file with a real X display (no --pipe) whose body does a
#     programmatic `xschem load` must NOT write recent_files -- the load happens inside the script
#     body, which is automation. This is the exact leak that re-contaminated the user's list with
#     test/scratchpad files (mos_power_ampli.sch, scratchpad/wirefix.sch): a real-GUI verify/repro
#     run launches `xschem -x --script foo.tcl`, and foo.tcl's `xschem load` used to pollute the
#     user list. Recents are suppressed for the script body (then restored -- see rail 4c).
#     See doc/claude/issues/0119-recent-files-script-leak.md.
H4B="$TMP/home4b"; mkdir -p "$H4B"
HOME="$H4B" timeout 30 "$XSCHEM" -q -r -x --nolog --script "$TMP/load_quit.tcl" >/dev/null 2>&1
if [ -f "$H4B/.xschem/recent_files" ]; then
  bad "--script (real-GUI, no --pipe) run wrote recent_files (user list corrupted -- leak is back)"
else ok "--script body load leaves recent_files alone (automation, not a human opening a file)"; fi

# 4c) POSITIVE rail (the cadence_style_rc fix): a --script startup file that does NO load in its
#     body (a config/keybinding rc -- e.g. cadence_style_rc) must NOT freeze the recent list. A
#     file the user opens AFTER the script runs -- modeled here by an `after` callback firing in
#     the Tk event loop, exactly as File>Open / Library Manager / reopen-last (Ctrl+Shift+O) do --
#     MUST record recent_files. Before the fix, --script hard-gated the WHOLE session, so a user
#     who launched `xschem --script cadence_style_rc` never updated recent_files: reopen-last
#     stayed stuck on a stale file. See doc/claude/issues/0119-recent-files-script-leak.md.
cat > "$TMP/rc_then_open.tcl" <<EOF
# no load in the script body (config/keybinding rc); open a file in the event loop afterwards
after 300 {
  xschem load {$SCH}
  xschem exit closewindow force
}
EOF
# NB: no -q here -- -q (cli_opt_quit) exits right after init, never entering the Tk event loop,
# so the `after` (and every real interactive open) would never fire. The user's launch has no -q.
H4C="$TMP/home4c"; mkdir -p "$H4C"
HOME="$H4C" timeout 30 "$XSCHEM" -r -x --nolog --script "$TMP/rc_then_open.tcl" >/dev/null 2>&1
if [ -f "$H4C/.xschem/recent_files" ] && grep -q "before_3.sch" "$H4C/.xschem/recent_files"; then
  ok "post-script (event-loop) open records recent_files -- config rc no longer freezes the session"
else bad "post-script open did NOT record recent_files (cadence_style_rc-style launch freezes recents)"; fi

# 5) an existing user recent_files survives a test run byte-for-byte
H5="$TMP/home5"; mkdir -p "$H5/.xschem"
printf 'set tctx::recentfile {/home/user/precious.sch}\nset tctx::recentdirs {}\n' > "$H5/.xschem/recent_files"
cp "$H5/.xschem/recent_files" "$TMP/precious.orig"
HOME="$H5" timeout 30 "$XSCHEM" --nogui --pipe -q --nolog --script "$TMP/load_quit.tcl" >/dev/null 2>&1
if cmp -s "$H5/.xschem/recent_files" "$TMP/precious.orig"; then
  ok "pre-existing user recent_files byte-identical after a test run"
else bad "test run modified the user's pre-existing recent_files"; fi

# 6) launch line + cwd in the action log (Tcl-comment header lines, replay-safe)
LD="$TMP/logs"
( cd "$TMP" && HOME="$TMP/home6" timeout 30 "$XSCHEM" --nogui --pipe -q --logdir "$LD" --script "$TMP/load_quit.tcl" >/dev/null 2>&1 )
LOG="$LD/Xschem.log"
if [ -f "$LOG" ]; then ok "Xschem.log created"; else bad "Xschem.log not created"; fi
if head -1 "$LOG" 2>/dev/null | grep -q '^# xschem action log'; then
  ok "header line unchanged (first line)"
else bad "header first line changed/missing"; fi
if grep -q '^# launch: .*--logdir' "$LOG" 2>/dev/null && grep -q '^# launch: .*--script' "$LOG" 2>/dev/null; then
  ok "full launch command line recorded (# launch: ... --logdir ... --script ...)"
else bad "launch command line not recorded"; fi
if grep -q "^# cwd: $TMP" "$LOG" 2>/dev/null; then
  ok "launch cwd recorded (# cwd: ...)"
else bad "cwd not recorded"; fi
# every header line is a Tcl comment: the log must stay source-able for replay
if grep -v '^#' "$LOG" | grep -q '^[^x[:space:]]' ; then
  bad "non-comment junk line in log (replay would break)"
else ok "log body still only comments / xschem commands"; fi

# 7) the header must record the PRE-parse argv: process_options permutes argv in place
#    (compacts non-option args over flag slots, NUL-splits --opt=val), so a post-parse dump
#    drops flags, duplicates the file arg and amputates =values (review wf_a23dea5b)
LD7="$TMP/logs7"
( cd "$TMP" && HOME="$TMP/home7" timeout 30 "$XSCHEM" --nogui --pipe -q --logdir "$LD7" --norecent "$SCH" --script "$TMP/load_quit.tcl" >/dev/null 2>&1 )
L7="$LD7/Xschem.log"
LAUNCH7=$(grep '^# launch:' "$L7" 2>/dev/null)
if echo "$LAUNCH7" | grep -q -- '--nogui'; then
  ok "launch header keeps --nogui despite argv compaction"
else bad "launch header lost --nogui (post-permutation argv dumped)"; fi
n=$(echo "$LAUNCH7" | grep -o "before_3.sch" | wc -l)
if [ "$n" = "1" ]; then ok "file argument appears exactly once in the launch header"
else bad "file argument duplicated/missing in launch header (count=$n)"; fi

# 8) --opt=val form survives intact (parser NUL-splits the '=' in place)
LD8="$TMP/logs8"
HOME="$TMP/home8" timeout 30 "$XSCHEM" --nogui --pipe -q "--logdir=$LD8" --script "$TMP/load_quit.tcl" >/dev/null 2>&1
if grep -q -- "--logdir=$LD8" "$LD8/Xschem.log" 2>/dev/null; then
  ok "launch header keeps --logdir=VALUE intact"
else bad "launch header amputated the =value of --logdir"; fi

# 9) an argv with an embedded NEWLINE must not break out of the comment line: a raw
#    newline would put executable text on its own line and RUN on replay (source)
LD9="$TMP/logs9"
NL_ARG=$(printf 'set junk 1\nputs INJECTED_FROM_ARGV')
HOME="$TMP/home9" timeout 30 "$XSCHEM" --nogui --pipe -q --logdir "$LD9" --tcl "$NL_ARG" --script "$TMP/load_quit.tcl" >/dev/null 2>&1
L9="$LD9/Xschem.log"
if grep -q '^puts INJECTED_FROM_ARGV' "$L9" 2>/dev/null; then
  bad "newline in argv escaped the comment (injected line would execute on replay)"
else ok "newline in argv stays inside the # launch: comment (escaped)"; fi
if grep '^# launch:' "$L9" 2>/dev/null | grep -q 'INJECTED_FROM_ARGV'; then
  ok "the multi-line arg is still recorded (escaped) in the header"
else bad "multi-line arg lost from the header"; fi
# whitespace-containing args are brace-wrapped for unambiguous reading
if grep '^# launch:' "$L9" 2>/dev/null | grep -q '{set junk 1\\nputs INJECTED_FROM_ARGV}'; then
  ok "multi-word arg brace-wrapped + newline escaped"
else bad "multi-word arg not brace-wrapped/escaped as expected"; fi

rm -rf "$TMP"
if [ $fail -eq 0 ]; then echo "RESULT: ALL PASS"; exit 0
else echo "RESULT: $fail FAILED"; exit 1; fi
