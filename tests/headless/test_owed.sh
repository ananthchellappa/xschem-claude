#!/bin/bash
# test_owed.sh — the owed ledger (doc/claude/specs/owed.md, O1..O22).
#
# The headline is O9 and its twin O18: `drain` must not touch the look list, and
# must not touch the RULE list either. That is the rule the whole design exists
# to protect -- an automated verdict may never discharge a human one -- and it
# is the one a future refactor is most likely to "simplify" away. O18 exists
# because the `rule` kind arrived AFTER O9 was written, and a new list that no
# check defends is a list the next refactor drains by accident.
#
# Most checks run against a STUBBED run_suites.sh so pass/fail is deterministic
# and the suite is fast; O13 then drains a real suite on a real (virtual)
# display so the stub cannot be hiding an integration break.

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
TMP="$(mktemp -d "${TMPDIR:-/tmp}/owedtest.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM

pass=0; fail=0; skip=0
ck() {  # ck <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok:   $1"; pass=$((pass+1))
  else echo "FAIL: $1 -> {$3} (exp {$2})"; fail=$((fail+1)); fi
}
skipck() { echo "skip: $*"; skip=$((skip+1)); }

export XSCHEM_OWED_DIR="$TMP/state"
OWED="$HERE/owed.sh"

# A copy of owed.sh with a STUB run_suites.sh beside it. drain resolves that
# script relative to its own location, so this swaps the runner without
# touching the real one. PASSME passes, FAILME fails.
mkdir -p "$TMP/bin"
cp "$OWED" "$TMP/bin/owed.sh"
cat > "$TMP/bin/run_suites.sh" <<'EOF'
#!/bin/bash
echo "stub run_suites: $*"
echo "stub AUDIT_DISPLAY=${AUDIT_DISPLAY:-unset}"
case "$1" in
  *FAILME*) exit 1 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/run_suites.sh" "$TMP/bin/owed.sh"
STUB="$TMP/bin/owed.sh"

# drain RESOLVES a suite name to a file before running anything (O14/O15), so
# the stubbed suites need files beside the stubbed runner. They are never read
# -- the stub above decides pass/fail from the name -- but their EXISTENCE is
# now part of the contract, which is the whole of O15.
: > "$TMP/bin/PASSME_suite.tcl"
: > "$TMP/bin/FAILME_suite.tcl"

# --- O1/O2: recording, and the two lists staying apart -----------------------
"$OWED" add suite alpha_suite "needs a real screen" >/dev/null 2>&1
ck "O1 add suite exits 0" 0 "$?"
"$OWED" add look "the pane proportions" "pixels, tests cannot see it" >/dev/null 2>&1
ck "O2 add look exits 0" 0 "$?"
ck "O1 count reports every list, in rule/look/suite order" "0 rule, 1 look, 1 suite" "$("$OWED" count)"
ck "O2 suite list has only the suite" 1 \
   "$("$OWED" list suite | grep -c alpha_suite)"
ck "O2 suite list does NOT contain the look entry" 0 \
   "$("$OWED" list suite | grep -c 'pane proportions')"

# --- O3/O4: dedupe for suites, never for looks -------------------------------
"$OWED" add suite alpha_suite "a newer reason" >/dev/null 2>&1
ck "O3 re-adding a suite does not duplicate it" "0 rule, 1 look, 1 suite" "$("$OWED" count)"
ck "O3 ...and the newer reason wins" 1 \
   "$("$OWED" list suite | grep -c 'a newer reason')"
"$OWED" add look "the pane proportions" "a DIFFERENT thing, same words" >/dev/null 2>&1
ck "O4 an identically-worded look is NOT merged away" "0 rule, 2 look, 1 suite" "$("$OWED" count)"

# --- O5: an unknown kind is an error, not a FOURTH list ----------------------
# (It said "third list" until 2026-08-22, when `rule` became the third. The
# check is unchanged -- the point was never the number, it was that a typo must
# not quietly open a new list nothing reads.)
"$OWED" add banana x y >/dev/null 2>&1
ck "O5 unknown kind is an error" 2 "$?"
ck "O5 ...and created nothing" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR" 2>/dev/null | grep -c banana)"

# --- O11: only `clear look` clears a look ------------------------------------
lookid=$(ls -1 "$XSCHEM_OWED_DIR/look" | head -1)
"$OWED" clear look "$lookid" >/dev/null 2>&1
ck "O11 clear look removes exactly one" "0 rule, 1 look, 1 suite" "$("$OWED" count)"
"$OWED" clear look "no_such_id" >/dev/null 2>&1
ck "O11 clearing a missing id is an error, not a silent success" 4 "$?"

# --- O7/O8/O9: drain ---------------------------------------------------------
# Fresh ledger: one suite that will pass, one that will fail, one look debt.
rm -rf "$XSCHEM_OWED_DIR"
"$STUB" add suite PASSME_suite  "should clear"      >/dev/null 2>&1
"$STUB" add suite FAILME_suite  "should be kept"    >/dev/null 2>&1
"$STUB" add look  "a pixel thing" "needs human eyes" >/dev/null 2>&1
looks_before=$(ls -1 "$XSCHEM_OWED_DIR/look" | sort)

"$STUB" drain --display ":test" > "$TMP/drain.out" 2>&1
drain_rc=$?
ck "O8 drain exits non-zero when a suite failed" 1 "$drain_rc"
ck "O7 a PASSING suite's debt is cleared" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | grep -c PASSME)"
ck "O8 a FAILING suite's debt is KEPT" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | grep -c FAILME)"
ck "O8 ...and the failure is recorded on it" 1 \
   "$("$STUB" list suite | grep -c 'still owed')"
ck "O7 drain ran BOTH queued suites" 2 \
   "$(grep -c 'stub run_suites' "$TMP/drain.out")"
ck "O7 ...on the display it was given, via AUDIT_DISPLAY" 2 \
   "$(grep -c 'stub AUDIT_DISPLAY=:test' "$TMP/drain.out")"

# THE HEADLINE. A green suite must never discharge a human obligation.
looks_after=$(ls -1 "$XSCHEM_OWED_DIR/look" | sort)
ck "O9 drain did not touch the look list" "$looks_before" "$looks_after"
ck "O9 ...and said so" 1 "$(grep -c 'look debts untouched' "$TMP/drain.out")"

# --- O10: draining an empty queue --------------------------------------------
rm -rf "$XSCHEM_OWED_DIR"
"$STUB" add look "still here" "untouched" >/dev/null 2>&1
"$STUB" drain --display ":test" > "$TMP/drain2.out" 2>&1
ck "O10 empty suite queue exits 0" 0 "$?"
ck "O10 ...runs nothing" 0 "$(grep -c 'stub run_suites' "$TMP/drain2.out")"
ck "O10 ...and still leaves the look list alone" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/look" | wc -l | tr -d ' ')"

# --- O6: the empty ledger is a normal state ----------------------------------
rm -rf "$XSCHEM_OWED_DIR"
out=$("$OWED" list 2>&1); rc=$?
ck "O6 empty ledger exits 0" 0 "$rc"
ck "O6 ...and says so" 1 "$(echo "$out" | grep -c 'nothing owed')"

# --- O12: a corrupt entry is survivable --------------------------------------
"$OWED" add suite good_suite "fine" >/dev/null 2>&1
printf 'this is not an entry\n' > "$XSCHEM_OWED_DIR/suite/corrupt_one"
out=$("$OWED" list 2>&1); rc=$?
ck "O12 a corrupt entry does not kill the listing" 0 "$rc"
ck "O12 ...the good entry still shows" 1 "$(echo "$out" | grep -c good_suite)"
ck "O12 ...and the corruption is reported, not swallowed" 1 \
   "$(echo "$out" | grep -c 'unreadable entry')"

# --- O14: a SHELL-script suite is drainable at all ----------------------------
# The defect this pins: drain handed every name to run_suites.sh, which resolves
# `<name>.tcl` only, so a debt naming a test_*.sh suite failed with "FATAL: no
# such test file" on every drain and was therefore kept forever. Nothing about
# the ledger could ever pay it. The real casualty was `test_gui_gate_batch`.
#
# The stub run_suites.sh must NOT be what runs it -- that is half the point --
# so the .sh suite writes a witness file and the check reads it back.
rm -rf "$XSCHEM_OWED_DIR"
#
# ⚠ THE TWO SPELLINGS GO ON SEPARATE LINES, anchored. The first draft echoed
# them on ONE line and grepped for the substring `DISPLAY=:test` -- which also
# matches `AUDIT_DISPLAY=:test`, so dropping either assignment from owed.sh left
# the check green (measured, both ways: ALL PASS 42). R308's specific claim is
# that a shell suite is handed DISPLAY, the spelling such a suite actually
# reads; that needs its own check that cannot be satisfied by the other one.
cat > "$TMP/bin/SHELLY_suite.sh" <<EOF
#!/bin/bash
echo "shell suite ran"
echo "got-display=\${DISPLAY:-unset}"
echo "got-audit=\${AUDIT_DISPLAY:-unset}"
echo ran > "$TMP/shelly.witness"
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOF
chmod +x "$TMP/bin/SHELLY_suite.sh"
"$STUB" add suite SHELLY_suite "a .sh suite, not a .tcl one" >/dev/null 2>&1
"$STUB" drain --display ":test" > "$TMP/drain4.out" 2>&1
ck "O14 draining a .sh suite exits 0" 0 "$?"
ck "O14 ...the shell suite really ran (its own witness, not the stub runner)" \
   "ran" "$(cat "$TMP/shelly.witness" 2>/dev/null)"
ck "O14 ...NOT through run_suites.sh (a .sh cannot be an xschem --script)" 0 \
   "$(grep -c 'stub run_suites' "$TMP/drain4.out")"
ck "O14 ...on the display it was given, in the spelling a shell suite reads" 1 \
   "$(grep -c '^got-display=:test$' "$TMP/drain4.out")"
ck "O14 ...and in the arm-aware spelling too, pinned separately (AUDIT_DISPLAY)" 1 \
   "$(grep -c '^got-audit=:test$' "$TMP/drain4.out")"
ck "O14 ...and the debt is cleared" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | wc -l | tr -d ' ')"

# a .sh suite that fails is kept, exactly like a .tcl one (R303)
cat > "$TMP/bin/SHELLBAD_suite.sh" <<'EOF'
#!/bin/bash
echo "RESULT: 1 FAILED (0 passed)"
exit 1
EOF
chmod +x "$TMP/bin/SHELLBAD_suite.sh"
"$STUB" add suite SHELLBAD_suite "fails on purpose" >/dev/null 2>&1
"$STUB" drain --display ":test" > "$TMP/drain5.out" 2>&1
ck "O14 a FAILING .sh suite makes drain exit non-zero" 1 "$?"
ck "O14 ...and its debt is KEPT (R303)" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | grep -c SHELLBAD)"

# --- O15: a name with NEITHER extension fails loudly, and keeps the debt -------
rm -rf "$XSCHEM_OWED_DIR"
"$STUB" add suite ghost_suite "no such file anywhere" >/dev/null 2>&1
"$STUB" drain --display ":test" > "$TMP/drain6.out" 2>&1
ck "O15 an unresolvable suite name makes drain exit non-zero" 1 "$?"
ck "O15 ...names BOTH candidates it looked for" 1 \
   "$(grep -c 'ghost_suite.tcl and .*ghost_suite.sh' "$TMP/drain6.out")"
ck "O15 ...does not run the suite runner at all" 0 \
   "$(grep -c 'stub run_suites' "$TMP/drain6.out")"
ck "O15 ...keeps the debt" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | grep -c ghost_suite)"
ck "O15 ...and records WHY, as a misnamed debt and not as a red suite" 1 \
   "$("$STUB" list suite | grep -c 'NO SUCH SUITE FILE')"

# ⚠ THE MESSAGE NAMES WHAT WAS REALLY STAT'D (R309), and the two arms that stat
# exactly ONE file are where that went wrong: the warning used to be composed
# from the name unconditionally as `$HERE/<name>.tcl nor $HERE/<name>.sh`, so a
# path-shaped debt was reported against a DOUBLED directory and a DOUBLED
# extension -- two files nobody had looked for. O15's bare-name leg above cannot
# see that, because for a bare name the guess happens to be right.
rm -rf "$XSCHEM_OWED_DIR"
"$STUB" add suite "tests/headless/test_nope.tcl" "a path-shaped name" >/dev/null 2>&1
"$STUB" drain --display ":test" > "$TMP/drain7.out" 2>&1
ck "O15 a path-shaped unresolvable name also exits non-zero" 1 "$?"
ck "O15 ...and names the ONE path it really stat'd" 1 \
   "$(grep -c 'looked for tests/headless/test_nope.tcl -- no such file' "$TMP/drain7.out")"
ck "O15 ...as exactly ONE candidate, not a fabricated pair" 0 \
   "$(grep -c 'looked for .* and ' "$TMP/drain7.out")"
ck "O15 ...with the directory NOT doubled" 0 \
   "$(grep -c 'tests/headless/tests/headless' "$TMP/drain7.out")"
ck "O15 ...and the extension NOT doubled" 0 \
   "$(grep -c 'test_nope.tcl.tcl' "$TMP/drain7.out")"
ck "O15 ...and that debt is kept too" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | wc -l | tr -d ' ')"

rm -rf "$XSCHEM_OWED_DIR"
"$STUB" add suite "ghost_suite.sh" "a name that already carries its extension" >/dev/null 2>&1
"$STUB" drain --display ":test" > "$TMP/drain8.out" 2>&1
ck "O15 an already-suffixed unresolvable name exits non-zero" 1 "$?"
ck "O15 ...names the stub dir's ghost_suite.sh once, extension not doubled" 1 \
   "$(grep -c "looked for $TMP/bin/ghost_suite.sh -- no such file" "$TMP/drain8.out")"
ck "O15 ...and does not invent a .tcl candidate it never stat'd" 0 \
   "$(grep -c 'ghost_suite.sh.tcl' "$TMP/drain8.out")"

# =============================================================================
# O16..O22 — the `rule` kind (2026-08-22). A ruling is owed by the user exactly
# as a look is; it lives here so there is ONE queue to read, not a shell ledger
# plus a markdown table in doc/claude/ledger/.
# =============================================================================

rm -rf "$XSCHEM_OWED_DIR"

# --- O16: recording, and dedupe BY ID ----------------------------------------
"$OWED" add rule 0444 "keep the whitespace fix, or revert" >/dev/null 2>&1
ck "O16 add rule exits 0" 0 "$?"
ck "O16 ...and lands in its own list" "1 rule, 0 look, 0 suite" "$("$OWED" count)"
"$OWED" add rule 0444 "restated with a newer reason" >/dev/null 2>&1
ck "O16 re-adding the SAME ruling does not duplicate it" "1 rule, 0 look, 0 suite" \
   "$("$OWED" count)"
ck "O16 ...and the newer reason wins" 1 \
   "$("$OWED" list rule | grep -c 'restated with a newer reason')"

# --- O17: the three lists stay apart -----------------------------------------
"$OWED" add look  "the pane proportions" "pixels" >/dev/null 2>&1
"$OWED" add suite alpha_suite            "needs :0" >/dev/null 2>&1
ck "O17 rule list holds only the ruling" 1 "$("$OWED" list rule | grep -c '^  \[0444\]')"
ck "O17 ...and not the look" 0 "$("$OWED" list rule | grep -c 'pane proportions')"
ck "O17 ...and not the suite" 0 "$("$OWED" list rule | grep -c 'alpha_suite')"
ck "O17 the look list does not hold the ruling" 0 "$("$OWED" list look | grep -c '^  \[0444\]')"

# --- O19: only `clear rule` clears a ruling ----------------------------------
"$OWED" clear look 0444 >/dev/null 2>&1
ck "O19 clear look cannot reach a rule id" 4 "$?"
ck "O19 ...and the ruling is still standing" 1 "$("$OWED" list rule | grep -c '^  \[0444\]')"
"$OWED" clear rule 0444 >/dev/null 2>&1
ck "O19 clear rule removes it" "0 rule, 1 look, 1 suite" "$("$OWED" count)"

# --- O20/O21: the `eyes` tag and the `ref` pointer ---------------------------
# Four of the nine rulings this kind was built for (0457, 0458, 0468, 0475)
# cannot be decided without looking at pixels, so a ruling can be tagged. And a
# rule entry is a POINTER: the option set stays in the issue file.
"$OWED" add rule 0457 "annot_show default 0 or 1" --eyes >/dev/null 2>&1
ck "O20 an --eyes ruling is marked in the listing" 1 \
   "$("$OWED" list rule | grep -c 'needs eyes')"
ck "O20 ...and show says the ruling needs looking" 1 \
   "$("$OWED" show | grep -c 'one you must LOOK to make')"
ck "O20 a plain ruling is NOT marked" 1 \
   "$("$OWED" add rule 0479 "stale-cursor seam" >/dev/null 2>&1; \
      "$OWED" list rule | grep -c 'needs eyes')"
ck "O21 a 4-digit id resolves to its issue file" 1 \
   "$("$OWED" list rule | grep -c 'doc/claude/issues/0457-')"
ck "O21 ...and show names it as where the options are" 1 \
   "$("$OWED" show | grep -c 'the options are in: doc/claude/issues/0457-')"
"$OWED" add rule X0498 "no_undo netlist cost" --ref "doc/claude/ledger/driver_run_2026-08-16.md" \
   >/dev/null 2>&1
ck "O21 an explicit --ref is kept for a non-issue-numbered ruling" 1 \
   "$("$OWED" list rule | grep -c 'ledger/driver_run_2026-08-16.md')"
"$OWED" add rule 9999 "an id with no issue file yet" >/dev/null 2>&1
ck "O21 an id with no issue file gets NO ref, not an invented one" 0 \
   "$("$OWED" list rule | grep -c 'issues/9999')"

# --- O22: --eyes is a rule tag ------------------------------------------------
"$OWED" add look "x" "y" --eyes >/dev/null 2>&1
ck "O22 --eyes on a look is an error (a look already needs eyes)" 2 "$?"
"$OWED" add suite s "y" --eyes >/dev/null 2>&1
ck "O22 --eyes on a suite is an error" 2 "$?"

# --- O18: THE HEADLINE'S TWIN. drain must not touch the RULE list ------------
rm -rf "$XSCHEM_OWED_DIR"
"$STUB" add suite PASSME_suite "should clear"           >/dev/null 2>&1
"$STUB" add rule  0446 "a ruling the drain must not touch" >/dev/null 2>&1
# TWO looks against ONE rule, deliberately: with the counts equal, the very
# defect the last row of O18 pins (reading the look count POSITIONALLY, as the
# last field of `count`) would print the rule count under the look label and
# still agree. Unequal counts are what make that row able to fail.
"$STUB" add look  "a pixel thing"      "eyes" >/dev/null 2>&1
"$STUB" add look  "a second pixel thing" "eyes" >/dev/null 2>&1
rules_before=$(ls -1 "$XSCHEM_OWED_DIR/rule" | sort)
"$STUB" drain --display ":test" > "$TMP/drain9.out" 2>&1
ck "O18 the drain itself passed" 0 "$?"
ck "O18 ...the suite debt cleared, so the drain really ran" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | wc -l | tr -d ' ')"
ck "O18 drain did not touch the rule list" "$rules_before" \
   "$(ls -1 "$XSCHEM_OWED_DIR/rule" | sort)"
ck "O18 ...and said so, naming the list" 1 \
   "$(grep -c 'rule debts untouched: 1' "$TMP/drain9.out")"
# The defect this pins: drain used to read the look count as `count | sed
# 's/.*, //'`, i.e. "the last field", which became the RULE count the instant a
# third kind existed. Both counts are now selected BY NAME, and the fixture
# above keeps them unequal (2 looks, 1 rule) so the positional read prints 1
# here and the row goes red.
ck "O18 ...and reports the LOOK count under the look label" 1 \
   "$(grep -c 'look debts untouched: 2' "$TMP/drain9.out")"

rm -rf "$XSCHEM_OWED_DIR"

# --- O13: one REAL drain, so the stub cannot hide an integration break --------
rm -rf "$XSCHEM_OWED_DIR"
DPY="${OWED_TEST_DISPLAY:-${DISPLAY:-}}"
if [ -n "$DPY" ] && [ -x "$REPO/src/xschem" ] && [ -f "$HERE/test_calc_skeleton.tcl" ]; then
  "$OWED" add suite test_calc_skeleton "real end-to-end drain" >/dev/null 2>&1
  GUI_GATE=0 timeout 400 "$OWED" drain --display "$DPY" > "$TMP/drain3.out" 2>&1
  rc=$?
  ck "O13 a real drain of a passing suite exits 0" 0 "$rc"
  ck "O13 ...and cleared the debt" 0 \
     "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | wc -l | tr -d ' ')"
else
  skipck "O13 (no display or no built binary)"
fi

# -----------------------------------------------------------------------------
echo
if [ "$fail" -eq 0 ]; then
  if [ "$skip" -gt 0 ]; then echo "RESULT: ALL PASS ($pass checks, $skip skipped)"
  else echo "RESULT: ALL PASS ($pass checks)"; fi
  exit 0
fi
echo "RESULT: $fail FAILED ($pass passed, $skip skipped)"
exit 1
