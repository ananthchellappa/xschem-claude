#!/bin/bash
# test_owed.sh — the owed ledger (doc/claude/specs/owed.md, O1..O46).
#
# The headline is O9 and its twin O18: `drain` must not touch the look list, and
# must not touch the RULE list either. That is the rule the whole design exists
# to protect -- an automated verdict may never discharge a human one -- and it
# is the one a future refactor is most likely to "simplify" away. O18 exists
# because the `rule` kind arrived AFTER O9 was written, and a new list that no
# check defends is a list the next refactor drains by accident.
#
# O23..O34 defend the same rule from the direction nobody had guarded: ANOTHER
# CLONE. The state dir is in $HOME, so two checkouts of this repo share one
# ledger, and until 2026-09-10 either could close the other's ruling in silence
# -- `clear` rm'd by exact filename, `add` truncated with a bare `>` and printed
# "recorded". Those rows need a two-clone fixture; they build one.
#
# ⚠ AND A THIRD CLONE, SHARING A BASENAME WITH ONE OF THEM (O35/O36). cloneA and
# cloneB structurally CANNOT see the headline defect: the ownership tests used to
# compare the BASENAME of two clone ids, and `cloneA` never equals `cloneB`. So
# every row from O23 to O34 passed while a plain, no-flag `add` from a second
# clone still replaced the first clone's unanswered ruling at exit 0. The
# ordinary shape is a repo cloned twice under its own name -- `.../p1/xschem`,
# `.../p2/xschem` -- and that pair is the fixture O35 builds.
#
# O40..O46 are the SECOND repair round of the same day: an id that was a path
# (`clear rule ../cleared.log` deleted the pre-image log at exit 0), what an
# update silently destroyed (`eyes:1`, the standing `ref:`), the fact that an
# unstamped entry CHANGED MEANING once the ledger was backfilled to 196 of 196
# stamped, a clone that moves and orphans its own queue, and the vocabulary of
# `repo_via:`.
#
# ⚠ AND O46, WHICH IS THE ONE THAT DOES NOT ASSERT A PROTECTION. Every refusal
# in O23..O45 is THIS script declining to write another clone's entry. The other
# checkout on this machine runs its own 2026-09-04 owed.sh -- still what
# `git show HEAD:tests/headless/owed.sh` produces -- with no `repo:` logic at
# all, and against the fully stamped ledger it still destroys at exit 0 printing
# "recorded". O46 runs BOTH versions against one throwaway ledger and pins the
# destruction, because a hole that no check describes is a hole the next reader
# has to rediscover. It must go red the day the hole is closed.
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
# OWED_SH points the WHOLE suite at another copy of owed.sh. It exists for the
# RED run: `OWED_SH=<a pristine copy> tests/headless/test_owed.sh` shows the new
# rows failing against the code they were written for, which is the only thing
# that proves they test anything. The copy needs a doc/claude/issues/ beside it
# (O21 and the O23.. clones resolve refs against their own checkout root).
OWED="${OWED_SH:-$HERE/owed.sh}"

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

# =============================================================================
# O23..O34 — WHICH CLONE FILED IT (2026-09-10, issue 1400).
#
# The defect these defend, measured in both checkouts on this machine: the state
# dir lives in $HOME, so one ledger serves every worktree of this clone AND
# every other CLONE of the repo, which $HOME cannot tell apart from a worktree.
# Two clones each read their own TRACKED doc/claude/issues/NUMBERING.md, each
# found 1333-1348 free, and each filed into it -- so a rule id became a 4-digit
# number with two unrelated meanings.
#
# ⚠ AND THE SET IS NOT A FIXED SIZE, so nothing here publishes a bare count.
# Measured 2026-09-10: SEVEN colliding numbers at 08:25, TWELVE at 10:45, and it
# was STILL GROWING as this was written -- the other clone filed 1349, 1350,
# 1351, 1352 and 1353 during this batch's own run, and its next-free pointer
# then read 1354. Every one of those is already a committed issue file on this
# branch. A count here is a measurement with a timestamp on it, never a fact.
 Both writing paths then destroyed the
# other tree's entry in silence: `clear` rm'd by exact filename, and `add` was a
# bare `>` with no existence check that printed "recorded" while truncating a
# ruling nobody had answered. `clear rule 1339` from the wrong tree closed one
# at exit 0 with no output.
#
# That is THE rule of this file (see the header, and O9/O18 -- a ruling clears
# only when the USER says so) being broken from one directory over, by a command
# nobody typed wrong. So these rows need TWO CLONES.
#
# ⚠ A STUB COPY OF owed.sh IS ALREADY A DIFFERENT CLONE. $STUB above lives in
# $TMP/bin, whose origin is $TMP's parent, not this tree -- so $OWED-added and
# $STUB-added entries belong to two clones and mixing them in one fixture is now
# a REFUSAL, not a no-op. The rows above happen never to mix them; nothing below
# starts. Everything here uses $CLA / $CLB and a state dir of its own.
# =============================================================================

# ⚠ /usr/bin/grep, not `grep`. In an interactive shell here `grep` is a function
# routing to ugrep with -I --ignore-files forced, and it returns 0 for a
# single-alternative numeric pattern GNU grep matches six times (measured on
# doc/claude/issues/NUMBERING.md, 2026-09-10: 0 against 6). It is not exported,
# so a script gets /usr/bin/grep today -- but the rows below count issue
# NUMBERS, and a count that silently becomes 0 turns a red row green. Spell it.
GREP=/usr/bin/grep; [ -x "$GREP" ] || GREP=grep

rm -rf "$XSCHEM_OWED_DIR"
FX="$TMP/clones"

# Two clones, each a REAL `git init`. A stub .git directory would prove nothing:
# the whole point of an origin is that `git rev-parse` answers it, and the
# worktree leg below needs a real commit. Each clone carries its own copy of
# owed.sh at tests/headless/ and its own doc/claude/issues/, so THE SAME NUMBER
# resolves to a different question in each -- which is the collision itself.
mk_clone() {  # $1 tag
  local c="$FX/$1"
  mkdir -p "$c/tests/headless" "$c/doc/claude/issues"
  git -C "$c" init -q . >/dev/null 2>&1
  cp "$OWED" "$c/tests/headless/owed.sh"
  chmod +x "$c/tests/headless/owed.sh"
}
mk_clone cloneA
mk_clone cloneB
CLA="$FX/cloneA/tests/headless/owed.sh"
CLB="$FX/cloneB/tests/headless/owed.sh"
IDA=$(cd "$FX/cloneA" && pwd -P)
IDB=$(cd "$FX/cloneB" && pwd -P)
: > "$FX/cloneA/doc/claude/issues/3001-the-rdw-copy-question.md"
: > "$FX/cloneB/doc/claude/issues/3001-negative-page-scale.md"
# Whether git can answer at all decides the EXPECTED repo_via, and gates the
# three legs of O24 that need a commit, a branch and a remote. The probe is the
# exact call owed.sh makes, not `command -v git`: an installed git that cannot
# answer --path-format (< 2.31) is the case that matters.
if git -C "$FX/cloneA/tests/headless" rev-parse --path-format=absolute \
     --git-common-dir >/dev/null 2>&1; then GIT_OK=1; VIA=git; else GIT_OK=0; VIA=path; fi

# --- O23: the stamp — on lines 2+, with line 1 frozen (R608/R607) -------------
# Line 1 is <epoch>\t<subject>\t<reason> and _read_entry hands EVERYTHING after
# the second tab to `reason`. An origin written as a fourth column would arrive
# glued to the end of every reason string in every existing reader, so growth
# happens downward and line 1 does not move.
"$CLA" add rule 3001 "does the RDW copy the text or the label" >/dev/null 2>&1
ck "O23 add on a fresh entry exits 0" 0 "$?"
ck "O23 the origin is stamped, on lines 2+" 1 \
   "$(sed -n '2,$p' "$XSCHEM_OWED_DIR/rule/3001" | $GREP -c '^repo:')"
ck "O23 ...and NOT on line 1" 0 \
   "$(head -1 "$XSCHEM_OWED_DIR/rule/3001" | $GREP -c 'repo:')"
ck "O23 ...line 1 still has exactly three tab fields" 3 \
   "$(awk -F'\t' 'NR==1{print NF}' "$XSCHEM_OWED_DIR/rule/3001")"
ep=$(head -1 "$XSCHEM_OWED_DIR/rule/3001" | cut -f1)
ck "O23 ...and line 1 is BYTE-identical to the three frozen fields" \
   "$(printf '%s\t%s\t%s' "$ep" "3001" "does the RDW copy the text or the label")" \
   "$(head -1 "$XSCHEM_OWED_DIR/rule/3001")"
ck "O23 the stamp names the clone that filed it" "$IDA" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3001" | head -1)"
ck "O23 ...and records HOW that id was derived" "$VIA" \
   "$(sed -n 's/^repo_via://p' "$XSCHEM_OWED_DIR/rule/3001" | head -1)"
ck "O23 ...beside the ref, which still gets its own line (R603/R607)" 1 \
   "$($GREP -c '^ref:doc/claude/issues/3001-the-rdw-copy-question.md' \
      "$XSCHEM_OWED_DIR/rule/3001")"
"$CLA" add look  "the pane proportions" "pixels" >/dev/null 2>&1
"$CLA" add suite SHARED_suite          "needs a real screen" >/dev/null 2>&1
ck "O23 EVERY kind is stamped, not just rule" 3 \
   "$($GREP -l '^repo:' "$XSCHEM_OWED_DIR"/rule/* "$XSCHEM_OWED_DIR"/look/* \
      "$XSCHEM_OWED_DIR"/suite/* 2>/dev/null | wc -l | tr -d ' ')"

# --- O24: one id per CLONE, one id for every WORKTREE of it (R608) ------------
# --git-common-dir, not --git-dir. The shared ledger's whole rationale is that
# the main session and its worktrees see one queue (owed.md §2); if a worktree
# got its own origin, this file's own refusal would fire on the session that
# opened one -- the fix breaking the thing it was built to protect.
"$CLB" add rule 3002 "B's own, unrelated question" >/dev/null 2>&1
ck "O24 a SECOND CLONE gets a different id" "$IDB" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3002" | head -1)"
"$CLA" add rule 3003 "a second entry from the same clone" >/dev/null 2>&1
ck "O24 the same clone gets the SAME id every time" "$IDA" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3003" | head -1)"
if [ "$GIT_OK" = 1 ]; then
  git -C "$FX/cloneA" -c user.email=t@t -c user.name=t \
      commit --allow-empty -q -m init >/dev/null 2>&1
  git -C "$FX/cloneA" worktree add -q -b wt "$FX/wtA" >/dev/null 2>&1
  mkdir -p "$FX/wtA/tests/headless"
  cp "$OWED" "$FX/wtA/tests/headless/owed.sh"; chmod +x "$FX/wtA/tests/headless/owed.sh"
  "$FX/wtA/tests/headless/owed.sh" add rule 3003 "restated from a WORKTREE" >/dev/null 2>&1
  ck "O24 a worktree of that clone is NOT another clone: the add is accepted" 0 "$?"
  ck "O24 ...and stamps the CLONE, not the worktree" "$IDA" \
     "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3003" | head -1)"
  git -C "$FX/cloneA" checkout -q -b other_branch >/dev/null 2>&1
  "$CLA" add rule 3004 "filed after a branch switch" >/dev/null 2>&1
  ck "O24 a branch switch does not change the id" "$IDA" \
     "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3004" | head -1)"
  git -C "$FX/cloneA" remote add origin https://example.invalid/x.git >/dev/null 2>&1
  git -C "$FX/cloneA" remote set-url origin https://example.invalid/y.git >/dev/null 2>&1
  "$CLA" add rule 3005 "filed after a remote set-url" >/dev/null 2>&1
  ck "O24 a remote set-url does not change it either" "$IDA" \
     "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3005" | head -1)"
else
  skipck "O24 worktree/branch/remote legs (git cannot answer --path-format here)"
fi

# --- O25: with git unable to answer, the fallback names the SAME clone --------
# ⚠ WHY THE TRAILING /.git IS STRIPPED. The git answer is <clone>/.git and the
# path fallback is <clone>; if those differed, a tree that loses git -- or whose
# git predates --path-format (2.31) -- would read every one of its OWN entries
# as another clone's in a single step, and the refusal would fire on the only
# person entitled to write. So the two derivations must produce one id, and
# repo_via: records which answered, because they are not interchangeable
# evidence.
mkdir -p "$FX/nogit"
printf '#!/bin/bash\nexit 1\n' > "$FX/nogit/git"
chmod +x "$FX/nogit/git"
"$CLA" add rule 3009 "filed while git works" >/dev/null 2>&1
PATH="$FX/nogit:$PATH" "$CLA" add rule 3006 "filed with git refusing to answer" >/dev/null 2>&1
ck "O25 with git unable to answer, add still records" 0 "$?"
ck "O25 ...and stamps the checkout ROOT — the same id git gives" "$IDA" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3006" | head -1)"
ck "O25 ...saying the id is path-derived, not git-derived" "path" \
   "$(sed -n 's/^repo_via://p' "$XSCHEM_OWED_DIR/rule/3006" | head -1)"
PATH="$FX/nogit:$PATH" "$CLA" clear rule 3009 >/dev/null 2>&1
ck "O25 ...so a git-stamped entry is still MINE once git is gone" 0 "$?"

# --- O26: a foreign ADD refuses — THE SILENT-OVERWRITE DEFECT (R609) ----------
# This is the path with the loaded barrels: 35 bare 4-digit rule ids inside
# 1349-1399 that the other clone is aimed at. Today's code printed
# "owed: recorded rule debt: 1344" at exit 0 and left the other tree's standing
# ruling truncated. So the row that matters is the BYTES, not the exit code.
cp "$XSCHEM_OWED_DIR/rule/3001" "$TMP/3001.before"
out=$("$CLB" add rule 3001 "negative page scale mirrors the export" 2>&1); rc=$?
ck "O26 a foreign add REFUSES, exit 5" 5 "$rc"
cmp -s "$TMP/3001.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O26 ...and the standing ruling is BYTE-IDENTICAL afterwards" 0 "$?"
ck "O26 ...nothing was filed beside it either" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/rule" | $GREP -c '^3001@')"
ck "O26 ...the refusal quotes what is standing there" 1 \
   "$(echo "$out" | $GREP -cF 'standing:  does the RDW copy the text or the label')"
ck "O26 ...names the clone that owns it" 1 "$(echo "$out" | $GREP -cF "its clone: $IDA")"
ck "O26 ...and this one" 1 "$(echo "$out" | $GREP -cF "this tree: $IDB")"
ck "O26 ...offers BOTH escapes: file yours beside it" 1 \
   "$(echo "$out" | $GREP -cF -- '--repo here')"
ck "O26 ...or update theirs" 1 "$(echo "$out" | $GREP -cF -- '--repo cloneA')"
cp "$XSCHEM_OWED_DIR/suite/SHARED_suite" "$TMP/shared.before"
"$CLB" add suite SHARED_suite "B's own reason for the same suite name" >/dev/null 2>&1
ck "O26 a foreign add on a SUITE id refuses too" 5 "$?"
cmp -s "$TMP/shared.before" "$XSCHEM_OWED_DIR/suite/SHARED_suite"
ck "O26 ...and that entry is byte-identical too" 0 "$?"

# --- O27: a foreign CLEAR refuses, and says what you probably meant (R609) ----
# `clear rule 1339` today rm's by exact filename: it closed the other tree's
# link-hotspot ruling while this tree's 1339_R3_copy_says_what_it_did survived,
# with no error. The did-you-mean list is what makes the refusal usable -- the
# entry the user meant is usually right there under a suffixed id.
"$CLB" add rule 3001_H4_hotspot_wording "B's own ruling on that number" >/dev/null 2>&1
out=$("$CLB" clear rule 3001 2>&1); rc=$?
ck "O27 a foreign clear REFUSES, exit 5" 5 "$rc"
ck "O27 ...and the ruling is STILL THERE afterwards" 1 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3001" ] && echo 1 || echo 0)"
cmp -s "$TMP/3001.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O27 ...byte-identical, not merely present" 0 "$?"
ck "O27 ...the refusal names the clone that owns it" 1 \
   "$(echo "$out" | $GREP -cF "its clone: $IDA")"
ck "O27 ...quotes the ruling it is protecting" 1 \
   "$(echo "$out" | $GREP -cF 'standing:  does the RDW copy the text or the label')"
ck "O27 ...and names THIS tree's own ids on the same number, as a command" 1 \
   "$(echo "$out" | $GREP -cF 'clear rule 3001_H4_hotspot_wording')"
out=$("$CLB" clear rule 3003 2>&1); rc=$?
ck "O27 a foreign clear on a number this tree owns nothing on refuses too" 5 "$rc"
ck "O27 ...and says plainly that it owns none — itself the answer" 1 \
   "$(echo "$out" | $GREP -cF 'this clone owns no rule debt on that number')"
ck "O27 ...and a refusal destroys nothing, so nothing is logged as cleared" 0 \
   "$(cat "$XSCHEM_OWED_DIR/cleared.log" 2>/dev/null | $GREP -c $'\tcleared\trule\t3001\t')"

# --- O28: `--repo here` files a slot of its own, ref intact (R609/R603) -------
# Without this a second clone could not record a ruling for its own issue number
# AT ALL. The workaround it replaces -- suffixing the SUBJECT to `3001b` --
# silently drops the pointer to the options, because _issue_ref accepts a bare
# 4-digit id only. So the subject is left alone and the ID is namespaced.
out=$("$CLB" add rule 3001 "negative page scale mirrors the export" --repo here 2>&1); rc=$?
ck "O28 --repo here is accepted" 0 "$rc"
ck "O28 ...and files a slot of its own, <id>@<tag>" 1 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3001@cloneB" ] && echo 1 || echo 0)"
cmp -s "$TMP/3001.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O28 ...leaving the contested entry byte-identical" 0 "$?"
ck "O28 ...with the ref intact, resolved in THIS clone" 1 \
   "$($GREP -c '^ref:doc/claude/issues/3001-negative-page-scale.md' \
      "$XSCHEM_OWED_DIR/rule/3001@cloneB")"
ck "O28 ...and stamped to the clone that filed it" "$IDB" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3001@cloneB" | head -1)"
"$CLB" clear rule 3001 --repo here >/dev/null 2>&1
ck "O28 clear --repo here reaches that slot with the same words" 0 "$?"
ck "O28 ...and removes it" 0 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3001@cloneB" ] && echo 1 || echo 0)"
cmp -s "$TMP/3001.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O28 ...while the bare id it is deliberately not touching is untouched" 0 "$?"

# --- O29: `--repo <their tag>` updates THEIRS, stamp verbatim (R609) ----------
# ⚠ THE STAMP MUST NOT BECOME WHAT WAS TYPED. A first implementation stamped the
# tag, so `add rule 3001 --repo cloneA` replaced clone A's full id with the word
# "cloneA" -- and clone A then read its OWN entry as another clone's, the
# refusal firing on the one person entitled to write. Both rows below.
"$CLB" add rule 3001 "B updates A's ruling, deliberately" --repo cloneA >/dev/null 2>&1
ck "O29 --repo <their tag> is accepted" 0 "$?"
ck "O29 ...and the newer reason wins" 1 \
   "$($GREP -c "B updates A's ruling" "$XSCHEM_OWED_DIR/rule/3001")"
ck "O29 ...with their stamp kept VERBATIM: the full id, never the tag" "$IDA" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3001" | head -1)"
"$CLA" clear rule 3001 >/dev/null 2>&1
ck "O29 ...so the owning clone still clears its own, with no --repo at all" 0 "$?"
# ⚠ AND THE FORM THAT IS COMPARED EXACTLY, which is what makes the row above
# able to fail at all. A bare TAG is resolved back to a full id by asking the
# ledger, so it arrives correct; a --repo given as a PATH is taken as typed and
# compared EXACTLY. A path that merely CARRIES another clone's basename is
# therefore NOT that clone -- it need not even exist.
#
# ⚠ THIS ROW USED TO ASSERT THE OPPOSITE, and that is the correction. It read
# "a --repo path carrying that clone's basename is accepted as that clone", i.e.
# it PINNED THE TAG COMPARE AS CORRECT -- and the tag compare is the blocking
# defect: with two clones sharing a directory name it let a plain, no-flag
# `add rule 1344` from the second replace the first's unanswered ruling at exit
# 0, keeping the first's stamp on the second's text (measured 2026-09-10, and
# O35 below is the row that reaches it). Against the tag-comparing code this add
# UPDATED A's entry in place; it now files a slot of its own and leaves A's
# alone.
"$CLA" add rule 3011 "A's ruling, again" >/dev/null 2>&1
cp "$XSCHEM_OWED_DIR/rule/3011" "$TMP/3011.before"
"$CLB" add rule 3011 "B names A by a path that merely shares the basename" \
       --repo "$TMP/another_disk/cloneA" >/dev/null 2>&1
ck "O29 a --repo PATH that only shares a basename is accepted, as its OWN clone" 0 "$?"
ck "O29 ...so it files a slot of its own, <id>@<tag>, and does NOT update theirs" 1 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3011@cloneA" ] && echo 1 || echo 0)"
cmp -s "$TMP/3011.before" "$XSCHEM_OWED_DIR/rule/3011"
ck "O29 ...leaving the standing entry BYTE-identical" 0 "$?"
ck "O29 ...its stamp still the owner's own full id, never the path typed" "$IDA" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3011" | head -1)"
"$CLA" clear rule 3011 >/dev/null 2>&1
ck "O29 ...and the owner is not refused on its own entry" 0 "$?"
"$CLB" clear rule 3011 --repo "$TMP/another_disk/cloneA" >/dev/null 2>&1
ck "O29 ...while the slot it DID file is reachable by that same exact path" 0 "$?"
ck "O29 ...and is gone once cleared" 0 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3011@cloneA" ] && echo 1 || echo 0)"
"$CLA" add rule 3010 "A's, again" >/dev/null 2>&1
"$CLB" clear rule 3010 --repo cloneB >/dev/null 2>&1
ck "O29 a --repo naming a clone the entry is NOT filed in still refuses" 5 "$?"
ck "O29 ...the escape is a statement of intent, not -f: the entry stands" 1 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3010" ] && echo 1 || echo 0)"

# --- O30: drain SKIPS another clone's suite debt (R609/R301/R303) -------------
# Measured over the 8 suite debts standing on 2026-09-10: 7 resolve in this
# clone, all 7 resolve in the other one too, and 6 of those 7 files DIFFER in
# content. So a wrong-tree drain runs a DIFFERENT suite from the one that was
# owed and then clears the other tree's debt on a pass -- an automated verdict
# discharging work it never did, one directory over.
for c in cloneA cloneB; do
  cat > "$FX/$c/tests/headless/SHARED_suite.sh" <<EOF
#!/bin/bash
echo ran > "$TMP/witness.$c"
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOF
  chmod +x "$FX/$c/tests/headless/SHARED_suite.sh"
done
cat > "$FX/cloneB/tests/headless/PASSB_suite.sh" <<'EOF'
#!/bin/bash
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOF
chmod +x "$FX/cloneB/tests/headless/PASSB_suite.sh"
rm -f "$TMP/witness.cloneA" "$TMP/witness.cloneB"
looks_b=$(ls -1 "$XSCHEM_OWED_DIR/look" | sort)
rules_b=$(ls -1 "$XSCHEM_OWED_DIR/rule" | sort)
"$CLB" drain --display ":test" > "$TMP/drain10.out" 2>&1
ck "O30 a drain that owes nothing HERE exits 0 — a skip is not a failure" 0 "$?"
ck "O30 ...and says whose debt it is leaving alone" 1 \
   "$($GREP -cF "== SKIP SHARED_suite -- another clone's debt (cloneA)" "$TMP/drain10.out")"
ck "O30 ...the debt is KEPT" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" | $GREP -c '^SHARED_suite$')"
ck "O30 ...this clone's file of that name did NOT run" 0 \
   "$([ -e "$TMP/witness.cloneB" ] && echo 1 || echo 0)"
ck "O30 ...nor the other clone's" 0 \
   "$([ -e "$TMP/witness.cloneA" ] && echo 1 || echo 0)"
ck "O30 ...and it is reported as standing for another clone" 1 \
   "$($GREP -cF 'left standing for another clone' "$TMP/drain10.out")"
# O9 AND O18, IN THE TWO-CLONE WORLD. The headline rows above run in one clone;
# the skip path is new code on the way to the same guarantee, and a list that no
# check defends is the list the next refactor drains by accident.
ck "O30 the skipping drain still did not touch the look list" "$looks_b" \
   "$(ls -1 "$XSCHEM_OWED_DIR/look" | sort)"
ck "O30 ...nor the rule list" "$rules_b" "$(ls -1 "$XSCHEM_OWED_DIR/rule" | sort)"
"$CLB" add suite PASSB_suite "B's own :0 run" >/dev/null 2>&1
"$CLB" drain --display ":test" > "$TMP/drain11.out" 2>&1
ck "O30 a drain WITH work of its own still exits 0" 0 "$?"
ck "O30 ...clears its own debt" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" | $GREP -c '^PASSB_suite$')"
ck "O30 ...leaves the other clone's standing" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" | $GREP -c '^SHARED_suite$')"
ck "O30 ...and counts the skip separately in the summary" 1 \
   "$($GREP -cF 'skipped: 1 from another clone' "$TMP/drain11.out")"

# --- O31: BOTH drain rewrite arms preserve lines 2+ (R303/R309/R607) ----------
# Both arms wrote line 1 with a bare `>`, so the origin stamp, the ref and any
# verdict a human had written on the entry were erased -- and exactly where
# debts live longest, since only a FAILED or an UNRESOLVED debt is ever
# rewritten. One red run destroyed a hand-written note; a stamp eroded on the
# entries that had waited the longest.
cat > "$FX/cloneA/tests/headless/FAILA_suite.sh" <<'EOF'
#!/bin/bash
echo "RESULT: 1 FAILED (0 passed)"
exit 1
EOF
chmod +x "$FX/cloneA/tests/headless/FAILA_suite.sh"
"$CLA" add suite FAILA_suite  "will fail on purpose"     >/dev/null 2>&1
"$CLA" add suite ghostA_suite "resolves to no file here" >/dev/null 2>&1
printf 'verdict:a human wrote this\n' >> "$XSCHEM_OWED_DIR/suite/FAILA_suite"
printf 'verdict:a human wrote this\n' >> "$XSCHEM_OWED_DIR/suite/ghostA_suite"
"$CLA" drain --display ":test" > "$TMP/drain12.out" 2>&1
ck "O31 a drain with one red suite and one misnamed exits non-zero" 1 "$?"
ck "O31 the FAILED arm rewrote line 1" 1 \
   "$(head -1 "$XSCHEM_OWED_DIR/suite/FAILA_suite" | $GREP -c 'FAILED on :test')"
ck "O31 ...and KEPT the origin stamp" 1 \
   "$($GREP -cF "repo:$IDA" "$XSCHEM_OWED_DIR/suite/FAILA_suite")"
ck "O31 ...and the human's verdict line under it" 1 \
   "$($GREP -c '^verdict:a human wrote this' "$XSCHEM_OWED_DIR/suite/FAILA_suite")"
ck "O31 the UNRESOLVED arm rewrote line 1" 1 \
   "$(head -1 "$XSCHEM_OWED_DIR/suite/ghostA_suite" | $GREP -c 'NO SUCH SUITE FILE')"
ck "O31 ...and KEPT the origin stamp" 1 \
   "$($GREP -cF "repo:$IDA" "$XSCHEM_OWED_DIR/suite/ghostA_suite")"
ck "O31 ...and the human's verdict line under it" 1 \
   "$($GREP -c '^verdict:a human wrote this' "$XSCHEM_OWED_DIR/suite/ghostA_suite")"
"$CLA" drain --display ":test" > "$TMP/drain12b.out" 2>&1
ck "O31 a SECOND red run neither loses the stamp nor duplicates it" 1 \
   "$($GREP -c '^repo:' "$XSCHEM_OWED_DIR/suite/FAILA_suite")"
ck "O31 ...and the debts are still kept, not eroded away" 2 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" | $GREP -c 'A_suite$')"

# --- O32: an unattributed entry in a ledger with NO stamps — LEGACY (R608) ----
#
# ⚠ THIS HEADING USED TO READ "the 192-legacy contract", AND THAT LABEL IS NOW
# BACKWARDS -- relabelled 2026-09-10 (second repair round), behaviour unchanged.
# It said "192 entries were standing with no stamp when this landed", which was
# true when it was written and stopped being true at 12:18 the same day: the
# ledger was backfilled to 196 of 196 stamped, so in the LIVE ledger there are
# no unattributed entries left, and a new one can arrive exactly one way --
# another clone's older owed.sh wrote it, over whatever was in the slot. In THAT
# world claiming an unstamped entry is a false statement that transfers the
# other clone's text to this one and erases the only signal that a destroy
# happened; `add` refuses instead, and that is O42.
#
# What this group pins is the OTHER verdict, and it is still exactly right for
# the world it builds: THIS FIXTURE'S LEDGER CARRIES NO STAMP AT ALL. That is a
# ledger nobody ever backfilled, every `clear rule <id>` quoted in a receipt has
# to keep working in it, and breaking that would cost the user the very queue
# the file exists to protect. So on the LEGACY verdict: proceed, warn once,
# claim -- byte-identical to the pre-repair wording. The first row below asserts
# the precondition, so the label cannot go quietly wrong a second time. O43
# carries the same contract into the two other worlds where LEGACY is still the
# right answer.
rm -rf "$XSCHEM_OWED_DIR"
mkdir -p "$XSCHEM_OWED_DIR/rule" "$XSCHEM_OWED_DIR/look" "$XSCHEM_OWED_DIR/suite"
printf '1750000000\t0444\tkeep the whitespace fix, or revert\n' > "$XSCHEM_OWED_DIR/rule/0444"
printf 'ref:doc/claude/ledger/driver_run_2026-08-16.md\n'      >> "$XSCHEM_OWED_DIR/rule/0444"
printf '1750000000\t0445\tanother legacy ruling\n'              > "$XSCHEM_OWED_DIR/rule/0445"
legacy1=$(head -1 "$XSCHEM_OWED_DIR/rule/0444")
ck "O32 the fixture ledger carries NO stamp at all -- which is what makes LEGACY right" 0 \
   "$($GREP -l '^repo:' "$XSCHEM_OWED_DIR"/rule/* 2>/dev/null | wc -l | tr -d ' ')"
out=$("$CLB" clear rule 0444 2>&1); rc=$?
ck "O32 an unattributed entry still clears, from any clone" 0 "$rc"
ck "O32 ...and is gone" 0 "$([ -e "$XSCHEM_OWED_DIR/rule/0444" ] && echo 1 || echo 0)"
ck "O32 ...with one warning saying no clone is recorded on it" 1 \
   "$(echo "$out" | $GREP -c 'predates origin stamps')"
out=$("$CLA" add rule 0445 "restated, years later" 2>&1); rc=$?
ck "O32 an add over an unattributed entry is accepted, not refused" 0 "$rc"
ck "O32 ...and CLAIMED by the clone that touched it" "$IDA" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/0445" | head -1)"
ck "O32 ...which says so rather than doing it silently" 1 \
   "$(echo "$out" | $GREP -c 'predates origin stamps -- claiming it for cloneA')"
# ⚠ THE ONE NARROWING. drain claims an unattributed SUITE debt only when its
# name resolves HERE. Of the 8 debts standing, test_hier_pdf_links_1333 exists
# in the OTHER clone and not in this one: a name that resolves nowhere here is
# evidence the debt is not this clone's, and claiming it would hand this tree a
# debt it cannot pay while refusing the clone that can.
printf '1750000000\tFAILA_suite\ta legacy suite debt\n' > "$XSCHEM_OWED_DIR/suite/FAILA_suite"
printf '1750000000\tonly_elsewhere_suite\tresolves nowhere here\n' \
   > "$XSCHEM_OWED_DIR/suite/only_elsewhere_suite"
"$CLA" drain --display ":test" > "$TMP/drain13.out" 2>&1
ck "O32 draining two legacy debts exits non-zero (one red, one misnamed)" 1 "$?"
ck "O32 a legacy debt whose name RESOLVES here is claimed" "$IDA" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/suite/FAILA_suite" | head -1)"
ck "O32 ...and one that resolves NOWHERE here stays unattributed" 0 \
   "$($GREP -c '^repo:' "$XSCHEM_OWED_DIR/suite/only_elsewhere_suite")"
ck "O32 ...and is still reported as a misnamed debt, exactly as before" 1 \
   "$(head -1 "$XSCHEM_OWED_DIR/suite/only_elsewhere_suite" | $GREP -c 'NO SUCH SUITE FILE')"

# --- O33: cleared.log — the pre-image of anything destroyed (R610) ------------
# `clear` is an rm and `add` is a `>`. The only reason the 2026-09-10 collision
# could be reconstructed at all is that a tool result happened to persist --
# luck, not a ledger. Append-only, inside the state dir ROOT, where nothing
# globs: list and count walk the KIND dirs only.
ck "O33 cleared.log lives in the state dir root" 1 \
   "$([ -f "$XSCHEM_OWED_DIR/cleared.log" ] && echo 1 || echo 0)"
ck "O33 a clear is captured, with event, kind and id" 1 \
   "$(cat "$XSCHEM_OWED_DIR/cleared.log" | $GREP -c $'\tcleared\trule\t0444\t')"
ck "O33 ...with the entry's full text, prefixed so the log self-delimits" 1 \
   "$(cat "$XSCHEM_OWED_DIR/cleared.log" | $GREP -cF '| 1750000000	0444	keep the whitespace fix, or revert')"
ck "O33 ...including its lines 2+, not just line 1" 1 \
   "$(cat "$XSCHEM_OWED_DIR/cleared.log" | $GREP -cF '| ref:doc/claude/ledger/driver_run_2026-08-16.md')"
ck "O33 ...and line 1 byte-identical to what stood there" "$legacy1" \
   "$(sed -n '/	cleared	rule	0444	/{n;s/^| //p;q;}' "$XSCHEM_OWED_DIR/cleared.log")"
"$CLA" add rule 3007 "the first wording" >/dev/null 2>&1
out=$("$CLA" add rule 3007 "the second wording" 2>&1)
ck "O33 an add that REPLACES says so — it said 'recorded' however much it destroyed" 1 \
   "$(echo "$out" | $GREP -c 'updated rule debt')"
ck "O33 ...and the overwritten text is captured under an 'overwritten' header" 1 \
   "$(cat "$XSCHEM_OWED_DIR/cleared.log" | $GREP -c $'\toverwritten\trule\t3007\t')"
ck "O33 ...with the wording it destroyed still readable" 1 \
   "$(cat "$XSCHEM_OWED_DIR/cleared.log" | $GREP -cF '	3007	the first wording')"
"$CLA" add suite PASSA_suite "a debt a pass will clear" >/dev/null 2>&1
cat > "$FX/cloneA/tests/headless/PASSA_suite.sh" <<'EOF'
#!/bin/bash
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOF
chmod +x "$FX/cloneA/tests/headless/PASSA_suite.sh"
"$CLA" drain --display ":test" > "$TMP/drain14.out" 2>&1
ck "O33 a debt a drain clears on a pass leaves a pre-image too" 1 \
   "$(cat "$XSCHEM_OWED_DIR/cleared.log" | $GREP -c $'\tdrained\tsuite\tPASSA_suite\t')"
ck "O33 ...and the log in the state dir root is not read as an entry" 0 \
   "$("$CLA" list 2>&1 | $GREP -c 'cleared.log')"
ck "O33 ...nor mistaken for a corrupt one" 0 \
   "$("$CLA" list 2>&1 | $GREP -c 'unreadable entry')"
# ⚠ THIS COUNTS THE DIRECTORIES owed.sh CAN ACTUALLY REACH. It was a
# non-recursive `ls -1 "$FX"` -- the PARENT of the fake clones, which no write
# path in owed.sh has an expression for -- so the row could not go red whatever
# the code did. Measured 2026-09-10: a mutation appending the pre-image to
# $HERE/cleared.log IN ADDITION to the state-dir log (ledger pre-images leaking
# into a git checkout as untracked litter -- exactly what R502 forbids) left the
# suite at ALL PASS. The eight rows above catch a log that MOVED out, because
# the state-dir one then goes missing; only this one can catch a log that is
# ALSO written out, and it is the row named for the job.
ck "O33 ...and nothing was written outside the state dir (R502)" 0 \
   "$(find "$FX" "$TMP/bin" "$(dirname "$OWED")" -name cleared.log 2>/dev/null \
      | sort -u | wc -l | tr -d ' ')"

# --- O34: the everyday output is unchanged, and `show` tells the truth --------
# A single-clone session must read exactly as it always did: this file is typed
# dozens of times a day by someone who is not thinking about clones. The clone
# is named only when it is NOT this one.
rm -rf "$XSCHEM_OWED_DIR"
out=$("$CLA" add rule 3001 "does the RDW copy the text or the label" 2>&1)
ck "O34 a single-clone add prints exactly the line it always printed" \
   "owed: recorded rule debt: 3001" "$out"
ck "O34 ...list names no clone when the entry is this one's" 0 \
   "$("$CLA" list | $GREP -c 'another clone')"
ck "O34 ...and does not mark a ref that resolves here" 0 \
   "$("$CLA" list | $GREP -c 'read: .*(not in this clone)')"
ck "O34 the OTHER clone marks the same ref as not resolving there" 1 \
   "$("$CLB" list | $GREP -cF 'read: doc/claude/issues/3001-the-rdw-copy-question.md   (not in this clone)')"
ck "O34 ...and names the clone it came from" 1 "$("$CLB" list | $GREP -cF "from: $IDA")"
# --- O34b: `show` NEVER prints --repo, on any entry (the user's ruling) -------
# ⚠ THIS BLOCK ASSERTED THE OPPOSITE and had to be turned round. It read "show
# prints a clear command carrying --repo ... and running THAT, verbatim, is
# accepted ... and really clears the entry" -- i.e. it PINNED THE BYPASS. The
# argument for it was that a queue telling the user to type a command that then
# gets refused is worse than one that says nothing. True of a person at a
# keyboard; wrong here. The failure this whole change exists to stop is an AGENT
# in clone B closing a ruling the user has never answered in clone A, and `show`
# handed it that exact command with no friction and no statement of consequence.
# The refusal IS the friction. So: the plain command is printed, running it is
# refused, and the refusal -- read by someone who has just been told no -- is
# the one place the override is named. (User's ruling, 2026-09-10.)
sh_out=$("$CLB" show 2>&1)
ck "O34b show prints no --repo AT ALL, on any entry" 0 \
   "$(printf '%s\n' "$sh_out" | $GREP -c -- '--repo')"
ck "O34b ...but does name the clone the entry was filed in" 1 \
   "$(printf '%s\n' "$sh_out" | $GREP -cF "filed in another clone: $IDA")"
cmd=$(printf '%s\n' "$sh_out" | sed -n 's/^ *waiting [0-9]* day(s)   clear with: //p' | head -1)
ck "O34b ...and the command it prints is the PLAIN one, byte for byte" \
   "$CLB clear rule 3001" "$cmd"
eval "$cmd" >/dev/null 2>&1
ck "O34b running what show printed is REFUSED, exit 5" 5 "$?"
ck "O34b ...and the ruling is still standing — a queue may not close its own item" 1 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3001" ] && echo 1 || echo 0)"
ck "O34b ...the refusal is where --repo IS named, and it is the only place" 1 \
   "$("$CLB" clear rule 3001 2>&1 | $GREP -c -- '--repo')"

# --- O35: TWO CLONES THAT SHARE A DIRECTORY BASENAME (R608/R609) --------------
# ⚠ EVERYTHING ABOVE PASSED WHILE THE HEADLINE DEFECT WAS LIVE. cloneA/cloneB
# cannot reach it: the ownership tests compared the BASENAME of the two clone
# ids, and `cloneA` never equals `cloneB`. The ordinary shape is a repo cloned
# twice under its own name, and with `.../p1/xschem` and `.../p2/xschem` a
# plain, NO-FLAG `add rule 3001` from the second clone replaced the first
# clone's unanswered ruling at exit 0 -- keeping the FIRST clone's stamp on the
# SECOND clone's text, so nothing downstream could even see it had moved. The
# real pair on this machine (`xschem-claude`, `xschem-op-wcard`) differ, which
# is the only reason the defect was latent rather than live.
rm -rf "$XSCHEM_OWED_DIR"
mk_clone_at() {  # $1 parent, $2 basename -> prints the clone root
  local c="$FX/$1/$2"
  mkdir -p "$c/tests/headless" "$c/doc/claude/issues"
  git -C "$c" init -q . >/dev/null 2>&1
  cp "$OWED" "$c/tests/headless/owed.sh"
  chmod +x "$c/tests/headless/owed.sh"
  (cd "$c" && pwd -P)
}
ID1=$(mk_clone_at p1 xschem)
ID2=$(mk_clone_at p2 xschem)
S1="$ID1/tests/headless/owed.sh"
S2="$ID2/tests/headless/owed.sh"
ck "O35 the fixture really is two clones sharing one basename" "$(basename "$ID1")" \
   "$(basename "$ID2")"
ck "O35 ...and they really are two different clones" 1 \
   "$([ "$ID1" != "$ID2" ] && echo 1 || echo 0)"
: > "$ID1/doc/claude/issues/3001-p1-question.md"
: > "$ID2/doc/claude/issues/3001-p2-question.md"
"$S1" add rule 3001 "P1's unanswered ruling" >/dev/null 2>&1
"$S2" add rule 3002 "P2's own, unrelated question" >/dev/null 2>&1
cp "$XSCHEM_OWED_DIR/rule/3001" "$TMP/p1.before"

# (1) A PLAIN, NO-FLAG foreign add. This is the defect verbatim.
out=$("$S2" add rule 3001 "P2's unrelated question, same number" 2>&1); rc=$?
ck "O35 a PLAIN no-flag add from the same-named clone REFUSES, exit 5" 5 "$rc"
cmp -s "$TMP/p1.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O35 ...and the standing ruling is BYTE-IDENTICAL afterwards" 0 "$?"
ck "O35 ...still the first clone's wording, not the second's" 1 \
   "$($GREP -cF "P1's unanswered ruling" "$XSCHEM_OWED_DIR/rule/3001")"
ck "O35 ...and still its own full id, which is all that tells the two apart" "$ID1" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3001" | head -1)"
ck "O35 ...nothing was filed beside it either" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/rule" | $GREP -c '^3001@')"
ck "O35 ...the refusal names the owning clone in FULL" 1 \
   "$(echo "$out" | $GREP -cF "its clone: $ID1")"
ck "O35 ...and this one, which the shared basename cannot distinguish" 1 \
   "$(echo "$out" | $GREP -cF "this tree: $ID2")"
ck "O35 ...so the escape it offers is the PATH, never the ambiguous tag" 1 \
   "$(echo "$out" | $GREP -cF -- "--repo $ID1")"

# (2) `--repo here` means STRICTLY THIS CLONE, and cannot reach the other.
out=$("$S2" add rule 3001 "P2's unrelated question, same number" --repo here 2>&1); rc=$?
ck "O35 --repo here from the same-named clone is accepted" 0 "$rc"
ck "O35 ...and files a slot of its OWN, <id>@<tag>" 1 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3001@xschem" ] && echo 1 || echo 0)"
cmp -s "$TMP/p1.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O35 ...leaving the other clone's ruling byte-identical" 0 "$?"
ck "O35 ...and the new slot is stamped to THIS clone, not the one it is named like" "$ID2" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/3001@xschem" | head -1)"
"$S2" clear rule 3001 --repo here >/dev/null 2>&1
ck "O35 clear --repo here reaches ITS OWN slot" 0 "$?"
ck "O35 ...and removes it" 0 \
   "$([ -e "$XSCHEM_OWED_DIR/rule/3001@xschem" ] && echo 1 || echo 0)"
out=$("$S2" clear rule 3001 --repo here 2>&1); rc=$?
ck "O35 ...but with its own slot gone, --repo here does NOT fall through to theirs" 5 "$rc"
cmp -s "$TMP/p1.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O35 ...the other clone's ruling still byte-identical" 0 "$?"
ck "O35 ...and that refusal names the owner by PATH, since the basename names both" 1 \
   "$(echo "$out" | $GREP -cF -- "--repo $ID1")"

# --- O36: a bare --repo TAG the ledger cannot answer for (R609) ---------------
# ⚠ A TAG STAMPED VERBATIM IS A THIRD NAME for a clone that already has two (its
# path, and the tag of that path), and the clone it names then reads its OWN
# entry as another clone's -- the refusal firing on the only person entitled to
# write. It used to be stamped verbatim whenever the ledger did not know it.
out=$("$S2" add rule 3001 "P2 names a clone nobody has heard of" --repo notaclone 2>&1); rc=$?
ck "O36 a bare --repo tag no stamp answers to is a usage error, exit 2" 2 "$rc"
cmp -s "$TMP/p1.before" "$XSCHEM_OWED_DIR/rule/3001"
ck "O36 ...and nothing was written to the entry it names" 0 "$?"
ck "O36 ...nor filed beside it under an invented tag" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/rule" | $GREP -c '^3001@')"
ck "O36 ...it says plainly that no entry is stamped to such a clone" 1 \
   "$(echo "$out" | $GREP -c 'no entry in the ledger is stamped')"
"$S1" clear rule 3001 >/dev/null 2>&1
ck "O36 ...so the rightful owner is NOT locked out of its own entry" 0 "$?"
"$S1" add rule 3012 "P1's, again" >/dev/null 2>&1
cp "$XSCHEM_OWED_DIR/rule/3012" "$TMP/p1b.before"
out=$("$S2" add rule 3012 "P2 names them both at once" --repo xschem 2>&1); rc=$?
ck "O36 a bare tag TWO clones answer to is the same usage error, exit 2" 2 "$rc"
ck "O36 ...naming the first candidate rather than picking one" 1 \
   "$(echo "$out" | $GREP -cF "$ID1")"
ck "O36 ...and the second" 1 "$(echo "$out" | $GREP -cF "$ID2")"
cmp -s "$TMP/p1b.before" "$XSCHEM_OWED_DIR/rule/3012"
ck "O36 ...with the entry it would have touched byte-identical" 0 "$?"
"$S1" clear rule 3012 >/dev/null 2>&1
ck "O36 ...and its owner still clears it with no --repo at all" 0 "$?"

# --- O37: a NEWLINE in what the user typed would FORGE a field (R607) ---------
# Line 1 is ONE line and lines 2+ are `key:value`, and the stamp is POSITIONAL,
# not authenticated. `add rule 9001 $'B claims this\nrepo:/other/clone'` wrote a
# repo: line ABOVE the real stamp; _entry_repo takes the first, so the writer
# was refused on its own entry and another clone was handed it. Keeping each
# field to one line is what keeps the position meaningful.
n37=$(ls -1 "$XSCHEM_OWED_DIR/rule" 2>/dev/null | wc -l | tr -d ' ')
"$S1" add rule "$(printf '9001\nrepo:%s' "$ID2")" "a forged subject" >/dev/null 2>&1
ck "O37 a newline in the SUBJECT is a usage error, exit 2" 2 "$?"
"$S1" add rule 9002 "$(printf 'a forged reason\nrepo:%s' "$ID2")" >/dev/null 2>&1
ck "O37 ...in the REASON too" 2 "$?"
"$S1" add rule 9003 "why" --ref "$(printf 'a\nrepo:%s' "$ID2")" >/dev/null 2>&1
ck "O37 ...and in --ref" 2 "$?"
ck "O37 ...and not one of the three filed anything" "$n37" \
   "$(ls -1 "$XSCHEM_OWED_DIR/rule" 2>/dev/null | wc -l | tr -d ' ')"

# --- O38: an entry whose LAST LINE is unterminated (R607) ---------------------
# TWO readers look at these files -- _entry_field, which `clear` uses to decide
# ownership, and _read_opts, which `list`/`show` use to describe them -- and
# they disagreed about a `repo:` on a last line with no trailing newline:
# `clear` refused the foreign entry while `list` showed it as this clone's own.
# A queue that describes an entry one way and acts on it another is the shape of
# defect this whole file is about.
rm -rf "$XSCHEM_OWED_DIR"; mkdir -p "$XSCHEM_OWED_DIR/rule"
printf '1750000000\t9040\tan entry whose last line is unterminated\nrepo:%s' "$ID1" \
   > "$XSCHEM_OWED_DIR/rule/9040"
ck "O38 the fixture entry really has no trailing newline" 1 \
   "$([ -n "$(tail -c1 "$XSCHEM_OWED_DIR/rule/9040")" ] && echo 1 || echo 0)"
ck "O38 the owning clone's list does not call its OWN entry another clone's" 0 \
   "$("$S1" list 2>&1 | $GREP -c 'another clone')"
ck "O38 the other clone's list DOES — the same answer clear gives" 1 \
   "$("$S2" list 2>&1 | $GREP -c 'another clone')"
"$S2" clear rule 9040 >/dev/null 2>&1
ck "O38 ...and that clear is refused, exit 5" 5 "$?"
"$S1" clear rule 9040 >/dev/null 2>&1
ck "O38 ...while the owner's is accepted" 0 "$?"

# --- O39: with cleared.log unwritable, NOTHING is destroyed (R610) ------------
# The pre-image is the only record of what a clear or an overwrite removed, so a
# failed append is fatal to the destroy rather than a warning beside it. A
# ledger that loses the entry AND the pre-image together is worse than one that
# refuses. (The log is made unwritable here by putting a DIRECTORY where the
# file must go -- no chmod, so this row behaves the same when run as root.)
rm -rf "$XSCHEM_OWED_DIR"
"$S1" add rule 9050 "a ruling nobody has answered" >/dev/null 2>&1
cp "$XSCHEM_OWED_DIR/rule/9050" "$TMP/9050.before"
mkdir -p "$XSCHEM_OWED_DIR/cleared.log"
"$S1" clear rule 9050 >/dev/null 2>&1
ck "O39 clear with an unwritable cleared.log exits 3" 3 "$?"
cmp -s "$TMP/9050.before" "$XSCHEM_OWED_DIR/rule/9050"
ck "O39 ...and KEEPS the entry, byte-identical" 0 "$?"
"$S1" add rule 9050 "a second wording" >/dev/null 2>&1
ck "O39 an add that would overwrite exits 3 too" 3 "$?"
cmp -s "$TMP/9050.before" "$XSCHEM_OWED_DIR/rule/9050"
ck "O39 ...and writes nothing" 0 "$?"
cat > "$ID1/tests/headless/PASSP1_suite.sh" <<'EOS'
#!/bin/bash
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOS
chmod +x "$ID1/tests/headless/PASSP1_suite.sh"
"$S1" add suite PASSP1_suite "a debt a pass would clear" >/dev/null 2>&1
"$S1" drain --display ":test" >/dev/null 2>&1
ck "O39 a PASSING drain exits non-zero rather than lose the pre-image" 3 "$?"
ck "O39 ...and KEEPS the debt it could not record removing" 1 \
   "$(ls -1 "$XSCHEM_OWED_DIR/suite" | $GREP -c '^PASSP1_suite$')"
rmdir "$XSCHEM_OWED_DIR/cleared.log"
# ⚠ AND THE WORKTREE THE FALLBACK USED TO LOSE. A linked worktree's `.git` is a
# FILE (`gitdir: <clone>/.git/worktrees/<n>`), so with git unable to answer, the
# checkout root by path names the WORKTREE while git names the CLONE -- and the
# session that opened a worktree was refused on entries it had filed itself.
if [ "$GIT_OK" = 1 ]; then
  git -C "$ID1" -c user.email=t@t -c user.name=t \
      commit --allow-empty -q -m init >/dev/null 2>&1
  git -C "$ID1" worktree add -q -b wtp1 "$FX/wtP1" >/dev/null 2>&1
  mkdir -p "$FX/wtP1/tests/headless"
  cp "$OWED" "$FX/wtP1/tests/headless/owed.sh"; chmod +x "$FX/wtP1/tests/headless/owed.sh"
  "$S1" add rule 9060 "filed from the clone itself" >/dev/null 2>&1
  PATH="$FX/nogit:$PATH" "$FX/wtP1/tests/headless/owed.sh" clear rule 9060 >/dev/null 2>&1
  ck "O39 a linked worktree whose git is gone still clears its CLONE's entry" 0 "$?"
else
  skipck "O39 the linked-worktree-without-git leg (git cannot answer --path-format here)"
fi

rm -rf "$XSCHEM_OWED_DIR"

# =============================================================================
# SECOND REPAIR ROUND, 2026-09-10 — O40..O46.
#
# The rows above were all written against the FIRST repair (origin stamping and
# the cross-clone refusal). The second repair added four things and changed the
# meaning of a fifth, and `test_owed.sh` scored ALL PASS against it UNALTERED --
# which says the repair broke nothing and says NOTHING WHATEVER about whether
# any of the new behaviour works. These are the rows for it:
#
#   O40  R611  an id is a FILENAME. `clear rule ../cleared.log` used to delete
#              the pre-image log at exit 0, and `../../<file>` a file outside
#              the ledger entirely.
#   O41  R612  what an UPDATE must not destroy: `eyes:1`, the standing `ref:`,
#              and any line a human wrote.
#   O42  R608  the FOREIGN verdict -- an unstamped entry in a STAMPED ledger.
#   O43  R608  the LEGACY verdict, unchanged, in all three worlds where it is
#              still the right one.
#   O44  R613  the stamp is an absolute path, so a clone that MOVES orphans its
#              own queue -- and `restamp` is the way back.
#   O45        `repo_via:` is a CLOSED SET. Nothing pinned it before.
#   O46        ⚠ TWO owed.sh VERSIONS AGAINST ONE LEDGER, which is the world
#              this machine is actually in. This group asserts what happens,
#              and what happens is that the old script still destroys.
#
# ⚠ THE DOOR IS HALF A DOOR, AND O46 IS THE HALF THAT IS OPEN. Every refusal
# above is THIS script declining to write another clone's entry. The other
# checkout on this machine runs its own 2026-09-04 copy -- the one still at
# `git show HEAD:tests/headless/owed.sh` -- which has never heard of `repo:`,
# and stamping every entry in the ledger did not narrow that by one byte.
# O46 does not assert a protection. It pins the DESTRUCTION, so that the day
# someone closes the hole the row goes red and has to be rewritten deliberately.
# =============================================================================

# cleared.log size, or 0 when it does not exist yet: several rows below assert
# that a REFUSED destroy appended nothing, and "the file is absent" and "the
# file did not grow" are the same claim here.
logbytes() { [ -f "$XSCHEM_OWED_DIR/cleared.log" ] && wc -c < "$XSCHEM_OWED_DIR/cleared.log" | tr -d ' ' || echo 0; }

# --- O40: an id is a FILENAME, never a path (R611) ----------------------------
# `cmd_clear` took its id straight from the command line and used it as a path
# component -- `$d/$id` -- with no check that the result stayed inside the kind
# dir. Measured 2026-09-10 against a cp -a copy of the LIVE ledger:
#     clear rule ../cleared.log     -> exit 0, "owed: cleared rule debt cleared.log",
#                                      THE PRE-IMAGE LOG GONE, and the next
#                                      destroy then failed exit 3 for want of it
#     clear rule ../../victim.txt   -> exit 0, a file outside the state dir gone
# The traversal is INHERITED from the pre-stamp script; what the stamping work
# added was a target worth hitting, one `../` from every kind dir. Both witnesses
# below are planted and asserted STILL PRESENT: an exit code alone would pass on
# a version that refused after deleting.
rm -rf "$XSCHEM_OWED_DIR"
ID40=$(mk_clone_at r0 solo)
S40="$ID40/tests/headless/owed.sh"
"$S40" add rule 8000 "a seed, so cleared.log exists to be aimed at" >/dev/null 2>&1
"$S40" clear rule 8000 >/dev/null 2>&1
ck "O40 the fixture really has a cleared.log to destroy" 1 \
   "$([ -f "$XSCHEM_OWED_DIR/cleared.log" ] && echo 1 || echo 0)"
printf 'a file the ledger has no business touching\n' > "$TMP/o40_outside.txt"
printf 'and one inside the state dir root\n' > "$XSCHEM_OWED_DIR/o40_inside.txt"
log40=$(logbytes)
"$S40" add rule 8001 "a standing ruling, so the ledger is not empty" >/dev/null 2>&1
for form in '../cleared.log' '../../o40_outside.txt' '../o40_inside.txt' '.' '..' 'a/b'; do
  out=$("$S40" clear rule "$form" 2>&1); rc=$?
  ck "O40 clear rule '$form' is a usage error, exit 2" 2 "$rc"
  ck "O40 ...'$form' says an id is a FILENAME, not a path" 1 \
     "$(printf '%s\n' "$out" | $GREP -c 'is a FILENAME, not a path')"
done
ck "O40 the pre-image log it was aimed at is still there" 1 \
   "$([ -f "$XSCHEM_OWED_DIR/cleared.log" ] && echo 1 || echo 0)"
ck "O40 ...and did not grow: a refused clear records nothing" "$log40" "$(logbytes)"
ck "O40 the witness in the state dir root survived" 1 \
   "$([ -f "$XSCHEM_OWED_DIR/o40_inside.txt" ] && echo 1 || echo 0)"
ck "O40 the witness OUTSIDE the state dir survived" 1 \
   "$([ -f "$TMP/o40_outside.txt" ] && echo 1 || echo 0)"
ck "O40 ...and the standing ruling was not touched either" 1 \
   "$([ -f "$XSCHEM_OWED_DIR/rule/8001" ] && echo 1 || echo 0)"
# EVERY kind, not just `rule`: the id reaches the same `$d/$id` in all three.
"$S40" clear look '../../o40_outside.txt' >/dev/null 2>&1
ck "O40 a look id is a filename too" 2 "$?"
"$S40" clear suite '../../o40_outside.txt' >/dev/null 2>&1
ck "O40 ...and a suite id" 2 "$?"
ck "O40 ...with the witness still there after all three" 1 \
   "$([ -f "$TMP/o40_outside.txt" ] && echo 1 || echo 0)"
# THE OTHER ID->PATH SITES. `add` was never exposed -- every arm runs the
# subject through _slug, which maps `/` to `_` -- and `--repo` reaches a
# filename only through _repo_tag, which is _slug of the basename. Both are
# asserted rather than assumed, because the containment is one deleted call away
# in each: a traversal must end up INSIDE the kind dir or nowhere.
root40_before=$(ls -a "$XSCHEM_OWED_DIR" | sort)
"$S40" add rule '../../o40_evil' "add must not escape the kind dir" >/dev/null 2>&1
ck "O40 add with a traversal subject exits 0 — it is slugged, not refused" 0 "$?"
ck "O40 ...and the entry it filed is INSIDE the kind dir" 1 \
   "$(ls -a "$XSCHEM_OWED_DIR/rule" | $GREP -c '^\.\._\.\._o40_evil$')"
ck "O40 ...nothing appeared in the state dir root" "$root40_before" \
   "$(ls -a "$XSCHEM_OWED_DIR" | sort)"
ck "O40 ...and nothing outside it" 0 \
   "$([ -e "$TMP/o40_evil" ] && echo 1 || echo 0)"
"$S40" add rule 8001 "filed for a clone named by a traversal" --repo '../../o40_evilclone' >/dev/null 2>&1
ck "O40 a --repo carrying a traversal is tagged by basename, and stays inside" 1 \
   "$(ls -a "$XSCHEM_OWED_DIR/rule" | $GREP -c '^8001@o40_evilclone$')"
ck "O40 ...with nothing outside the state dir" 0 \
   "$([ -e "$TMP/o40_evilclone" ] && echo 1 || echo 0)"
# AND THE TWO LEGITIMATE SHAPES STILL CLEAR. A guard that also rejected a real
# id would lock the user out of their own queue, which is the failure mode this
# whole file is written against.
"$S40" clear rule 8001 --repo '../../o40_evilclone' >/dev/null 2>&1
ck "O40 an <id>@<tag> id still clears — the namespacing suffix is not a path" 0 "$?"
ck "O40 ...and it was the namespaced slot that went, not the bare one" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/rule" | $GREP -c '^8001@o40_evilclone$')"
"$S40" clear rule 8001 >/dev/null 2>&1
ck "O40 ...and so does a bare one" 0 "$?"

# --- O41: what an UPDATE must not destroy (R612) ------------------------------
# An `add` rebuilt the entry from the command line and nothing else, so an
# update dropped whatever the standing entry said about itself. Measured
# 2026-09-10 on a copy of the live ledger, `add rule 1351 ... --repo
# xschem-op-wcard` against the only one of the other clone's 14 entries carrying
# `eyes:1`: the tag was gone and their `ref:` had been replaced by THIS clone's
# 1351 file -- a ruling that could not be made without looking quietly stopped
# saying so, and their entry ended up pointing at a document their tree does not
# have. Neither loss printed anything.
rm -rf "$XSCHEM_OWED_DIR"
IDM=$(mk_clone_at r1 mine)
IDT=$(mk_clone_at r1 theirs)
SM="$IDM/tests/headless/owed.sh"
ST="$IDT/tests/headless/owed.sh"
: > "$IDT/doc/claude/issues/3301-the-question-they-filed.md"
: > "$IDM/doc/claude/issues/3301-my-unrelated-question.md"
: > "$IDM/doc/claude/issues/3302-my-other-question.md"
"$ST" add rule 3301 "a ruling THEY cannot make without looking" --eyes >/dev/null 2>&1
ck "O41 the fixture entry carries eyes:1 and their own ref" 2 \
   "$($GREP -c '^eyes:1$\|^ref:doc/claude/issues/3301-the-question-they-filed.md$' \
      "$XSCHEM_OWED_DIR/rule/3301")"
out=$("$SM" add rule 3301 "I update their ruling, deliberately" --repo theirs 2>&1); rc=$?
ck "O41 an update of THEIR entry is accepted" 0 "$rc"
ck "O41 ...and eyes:1 SURVIVES it" 1 \
   "$($GREP -c '^eyes:1$' "$XSCHEM_OWED_DIR/rule/3301")"
ck "O41 ...their ref survives, not replaced by the file MY clone has" 1 \
   "$($GREP -c '^ref:doc/claude/issues/3301-the-question-they-filed.md$' \
      "$XSCHEM_OWED_DIR/rule/3301")"
ck "O41 ...and nothing of mine was written into it" 0 \
   "$($GREP -c '3301-my-unrelated-question' "$XSCHEM_OWED_DIR/rule/3301")"
ck "O41 ...a rescue is REPORTED, not done silently" 1 \
   "$(printf '%s\n' "$out" | $GREP -c 'kept from the entry it replaced:.*eyes:1')"
"$ST" add rule 3301 "they restate it with an explicit ref" \
      --ref doc/claude/specs/owed.md >/dev/null 2>&1
ck "O41 an explicit --ref still WINS over the standing one" 1 \
   "$($GREP -c '^ref:doc/claude/specs/owed.md$' "$XSCHEM_OWED_DIR/rule/3301")"
printf 'verdict:a human wrote this line\n' >> "$XSCHEM_OWED_DIR/rule/3301"
"$ST" add rule 3301 "they restate it again" >/dev/null 2>&1
ck "O41 an unknown line 2+ a human wrote survives an update" 1 \
   "$($GREP -c '^verdict:a human wrote this line$' "$XSCHEM_OWED_DIR/rule/3301")"
"$ST" add rule 3301 "they decide it no longer needs eyes" --no-eyes >/dev/null 2>&1
ck "O41 --no-eyes is the ONE way to drop the tag, and it works" 0 \
   "$($GREP -c '^eyes:1$' "$XSCHEM_OWED_DIR/rule/3301")"
"$ST" add rule 3301 "both at once" --eyes --no-eyes >/dev/null 2>&1
ck "O41 --eyes and --no-eyes together is a usage error, exit 2" 2 "$?"
"$SM" add rule 3302 "a NEW entry filed for them by me" --repo theirs >/dev/null 2>&1
ck "O41 a new entry filed --repo <theirs> gets NO auto ref" 0 \
   "$($GREP -c '^ref:' "$XSCHEM_OWED_DIR/rule/3302")"
ck "O41 ...because the file it would name is one only MY clone has" 1 \
   "$([ -e "$IDM/doc/claude/issues/3302-my-other-question.md" ] && echo 1 || echo 0)"
"$SM" add rule 3399 "an everyday ruling in an everyday session" >/dev/null 2>&1
out=$("$SM" add rule 3399 "restated, same clone, nothing to rescue" 2>&1)
ck "O41 the everyday same-clone re-add prints ONE line, exactly as before" \
   "owed: updated rule debt: 3399" "$out"

# --- O42: an unstamped entry in a STAMPED ledger is FOREIGN (R608) ------------
# ⚠ THE DECISION THIS PINS, not its wording. Before the backfill an entry with
# no `repo:` meant one thing -- legacy, filed before stamps existed -- and
# whoever touched it next CLAIMED it. On 2026-09-10 the ledger was backfilled to
# 196 of 196 stamped, and in a ledger like that a new unstamped entry cannot be
# legacy: it is the signature of a clone running a script that does not stamp,
# writing over whatever was in the slot with no pre-image. So:
#
#   FOREIGN  <=>  the stamped entries are the MAJORITY, and this entry is NEWER
#                 than the OLDEST stamp.
#   add      REFUSES (5). It is the AUTOMATIC path -- an agent recording new
#            work must not be what writes over the only surviving copy.
#   clear    PROCEEDS, loudly. It is the path only the USER is entitled to run,
#            and a refusal there is how the user gets locked out of their own
#            queue. The pre-image makes it recoverable.
#   drain    SKIPS, and does NOT claim.
#   list/show MARK it -- the reader is where this has to surface, because the
#            user reads `show` before they type `clear`.
#
# The asymmetry (add refuses, clear proceeds) is the decision, and it is
# asserted in both directions below.
#
# ⚠ AND THE COMPARISON IS AGAINST THE OLDEST STAMP, NOT THE NEWEST. The first
# implementation compared against the newest, which collapsed the moment this
# clone filed anything: one `add` and every foreign entry read as legacy again.
rm -rf "$XSCHEM_OWED_DIR"
ID42=$(mk_clone_at r2 stamped)
S42="$ID42/tests/headless/owed.sh"
for i in 4001 4002 4003; do
  "$S42" add rule $i "a stamped ruling ($i)" >/dev/null 2>&1
  # Backdated because the backfill APPENDED a stamp and left line 1 alone, so a
  # stamped ledger's oldest stamp carries its entry's original filing date.
  sed -i '1s/^[0-9]*/1750000000/' "$XSCHEM_OWED_DIR/rule/$i"
done
printf '%s\t4009\ta ruling the other clone was never asked about\n' "$(date +%s)" \
   > "$XSCHEM_OWED_DIR/rule/4009"
cp "$XSCHEM_OWED_DIR/rule/4009" "$TMP/4009.before"
ck "O42 the fixture is a stamped ledger with ONE unstamped entry" "3 1" \
   "$($GREP -l '^repo:' "$XSCHEM_OWED_DIR"/rule/* | wc -l | tr -d ' ') $($GREP -L '^repo:' "$XSCHEM_OWED_DIR"/rule/* | wc -l | tr -d ' ')"
out=$("$S42" add rule 4009 "an agent records new work on that number" 2>&1); rc=$?
ck "O42 add over it REFUSES, exit 5" 5 "$rc"
cmp -s "$TMP/4009.before" "$XSCHEM_OWED_DIR/rule/4009"
ck "O42 ...and what is standing there is BYTE-IDENTICAL afterwards" 0 "$?"
ck "O42 ...nothing was filed beside it either" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR/rule" | $GREP -c '^4009@')"
ck "O42 ...the refusal says plainly it is NOT a legacy entry" 1 \
   "$(printf '%s\n' "$out" | $GREP -c 'That is not a legacy entry')"
ck "O42 ...and shows the arithmetic it decided on" 1 \
   "$(printf '%s\n' "$out" | $GREP -c 'AFTER the oldest stamped entry')"
ck "O42 ...and offers the deliberate way to take the slot" 1 \
   "$(printf '%s\n' "$out" | $GREP -c -- '--repo here')"
# ⚠ THE OLDEST-STAMP RULE. This clone files something newer than the foreign
# entry; the verdict must not move.
"$S42" add rule 4004 "a brand-new stamped ruling, filed just now" >/dev/null 2>&1
"$S42" add rule 4009 "second try, after this clone filed something newer" >/dev/null 2>&1
ck "O42 it STILL refuses after this clone files something newer" 5 "$?"
cmp -s "$TMP/4009.before" "$XSCHEM_OWED_DIR/rule/4009"
ck "O42 ...and it is still byte-identical" 0 "$?"
ck "O42 list MARKS it, where the reader will meet it" 1 \
   "$("$S42" list 2>&1 | $GREP -c 'no clone recorded, and written after stamping began here')"
ck "O42 show marks it too, above the clear command it prints" 1 \
   "$("$S42" show 2>&1 | $GREP -c 'NO CLONE RECORDED, and written after stamping began here')"
ck "O42 ...and marks nothing on the stamped entries beside it" 1 \
   "$("$S42" list 2>&1 | $GREP -c 'no clone recorded')"
# THE OTHER HALF OF THE DECISION: clear proceeds, because only the user runs it.
log42=$(logbytes)
out=$("$S42" clear rule 4009 2>&1); rc=$?
ck "O42 clear PROCEEDS on a foreign entry — the user is not locked out" 0 "$rc"
ck "O42 ...and it is gone" 0 "$([ -e "$XSCHEM_OWED_DIR/rule/4009" ] && echo 1 || echo 0)"
ck "O42 ...having said it is NOT legacy, not the old 'predates' line" 1 \
   "$(printf '%s\n' "$out" | $GREP -c 'this is NOT a legacy entry')"
ck "O42 ...and never printing the legacy wording" 0 \
   "$(printf '%s\n' "$out" | $GREP -c 'predates origin stamps')"
ck "O42 ...with the pre-image recorded before the rm" 1 \
   "$([ "$(logbytes)" -gt "$log42" ] && echo 1 || echo 0)"
ck "O42 ...and the full text of what it destroyed in it" 1 \
   "$($GREP -c 'a ruling the other clone was never asked about' "$XSCHEM_OWED_DIR/cleared.log")"
# DRAIN. A foreign suite debt is not run, not cleared, and NOT CLAIMED -- a pass
# in this tree may not discharge a debt this tree was never given.
cat > "$ID42/tests/headless/FOREIGNP_suite.sh" <<EOF
#!/bin/bash
echo ran > "$TMP/o42_witness"
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOF
chmod +x "$ID42/tests/headless/FOREIGNP_suite.sh"
mkdir -p "$XSCHEM_OWED_DIR/suite"
printf '%s\tFOREIGNP_suite\ta :0 run the other clone owes\n' "$(date +%s)" \
   > "$XSCHEM_OWED_DIR/suite/FOREIGNP_suite"
rm -f "$TMP/o42_witness"
"$S42" drain --display ":test" > "$TMP/drain40.out" 2>&1
ck "O42 a drain that meets a foreign debt exits 0 — a skip is not a failure" 0 "$?"
ck "O42 ...and says why it left it alone" 1 \
   "$($GREP -c 'SKIP FOREIGNP_suite -- no clone recorded, and written after stamping began here' \
      "$TMP/drain40.out")"
ck "O42 ...the suite did NOT run" 0 "$([ -e "$TMP/o42_witness" ] && echo 1 || echo 0)"
ck "O42 ...the debt is KEPT" 1 \
   "$([ -e "$XSCHEM_OWED_DIR/suite/FOREIGNP_suite" ] && echo 1 || echo 0)"
ck "O42 ...and it was NOT claimed on the way past" 0 \
   "$($GREP -c '^repo:' "$XSCHEM_OWED_DIR/suite/FOREIGNP_suite")"

# --- O43: the LEGACY verdict, unchanged, in all THREE worlds (R608) ----------
# The compatibility half. A ledger that was never backfilled must not notice the
# second repair AT ALL: every `clear rule <id>` quoted in a receipt still has to
# work, and the wording must be the pre-repair wording, because that is what the
# receipts and CLAUDE.md quote. Three worlds where LEGACY is still right:
#   (a) no stamps anywhere -- a ledger nobody ever backfilled;
#   (b) a stamped-majority ledger, entry OLDER than every stamp -- a real
#       pre-stamp entry that the backfill happened to miss;
#   (c) a HALF-ARMED ledger, unstamped still the majority -- mid-backfill.
LEGACY_ADD='predates origin stamps -- claiming it for'
LEGACY_CLR='predates origin stamps -- clearing it, but no clone is recorded on it'
# (a) --------------------------------------------------------------------------
rm -rf "$XSCHEM_OWED_DIR"; mkdir -p "$XSCHEM_OWED_DIR/rule" "$XSCHEM_OWED_DIR/look" "$XSCHEM_OWED_DIR/suite"
printf '1750000000\t0444\tkeep the whitespace fix, or revert\n' > "$XSCHEM_OWED_DIR/rule/0444"
printf '1750000000\t0445\tanother legacy ruling\n'             > "$XSCHEM_OWED_DIR/rule/0445"
ck "O43a the fixture ledger carries no stamp at all" 0 \
   "$($GREP -l '^repo:' "$XSCHEM_OWED_DIR"/rule/* 2>/dev/null | wc -l | tr -d ' ')"
out=$("$S42" add rule 0444 "restated, years later" 2>&1); rc=$?
ck "O43a an add over an unattributed entry is ACCEPTED, not refused" 0 "$rc"
ck "O43a ...the ADD says it in the pre-repair wording, byte for byte" 1 \
   "$(printf '%s\n' "$out" | $GREP -cF "$LEGACY_ADD stamped")"
out=$("$S42" clear rule 0445 2>&1); rc=$?
ck "O43a a clear is accepted too" 0 "$rc"
ck "O43a ...and the CLEAR says it in the pre-repair wording, byte for byte" 1 \
   "$(printf '%s\n' "$out" | $GREP -cF "$LEGACY_CLR")"
# (b) --------------------------------------------------------------------------
rm -rf "$XSCHEM_OWED_DIR"
for i in 4101 4102 4103; do
  "$S42" add rule $i "a stamped ruling ($i)" >/dev/null 2>&1
  sed -i '1s/^[0-9]*/1750000000/' "$XSCHEM_OWED_DIR/rule/$i"
done
printf '1740000000\t4109\tfiled long before stamps existed\n' > "$XSCHEM_OWED_DIR/rule/4109"
out=$("$S42" add rule 4109 "restated" 2>&1); rc=$?
ck "O43b an entry OLDER than every stamp is legacy, and the add is accepted" 0 "$rc"
ck "O43b ...with the pre-repair wording, byte for byte" 1 \
   "$(printf '%s\n' "$out" | $GREP -cF "$LEGACY_ADD stamped")"
ck "O43b ...and it is claimed, exactly as O32 requires" "$ID42" \
   "$(sed -n 's/^repo://p' "$XSCHEM_OWED_DIR/rule/4109" | head -1)"
# (c) --------------------------------------------------------------------------
rm -rf "$XSCHEM_OWED_DIR"
for i in 4201 4202; do
  "$S42" add rule $i "a stamped ruling ($i)" >/dev/null 2>&1
  sed -i '1s/^[0-9]*/1750000000/' "$XSCHEM_OWED_DIR/rule/$i"
done
for i in 4209 4210 4211; do
  printf '%s\t%s\tan entry the backfill has not reached yet\n' "$(date +%s)" "$i" \
     > "$XSCHEM_OWED_DIR/rule/$i"
done
ck "O43c the fixture is half-armed: unstamped are still the majority" "2 3" \
   "$($GREP -l '^repo:' "$XSCHEM_OWED_DIR"/rule/* | wc -l | tr -d ' ') $($GREP -L '^repo:' "$XSCHEM_OWED_DIR"/rule/* | wc -l | tr -d ' ')"
# ⚠ THE CLEAR FIRST, AND ON PURPOSE. `add` CLAIMS an entry on the legacy
# verdict, which stamps one more -- enough, in a fixture this small, to tip the
# majority and turn the next unstamped entry FOREIGN. Ordered the other way this
# group measures its own side effect instead of the contract.
out=$("$S42" clear rule 4210 2>&1); rc=$?
ck "O43c a clear in a mid-backfill ledger is accepted, pre-repair wording" 0 "$rc"
ck "O43c ...byte for byte" 1 "$(printf '%s\n' "$out" | $GREP -cF "$LEGACY_CLR")"
out=$("$S42" add rule 4209 "restated mid-backfill" 2>&1); rc=$?
ck "O43c a mid-backfill ledger still claims rather than refusing" 0 "$rc"
ck "O43c ...with the pre-repair wording, byte for byte" 1 \
   "$(printf '%s\n' "$out" | $GREP -cF "$LEGACY_ADD stamped")"
# AND drain still CLAIMS a legacy suite debt whose name resolves here (O32's
# narrowing is unchanged by any of this).
cat > "$ID42/tests/headless/LEGACYP_suite.sh" <<'EOF'
#!/bin/bash
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOF
chmod +x "$ID42/tests/headless/LEGACYP_suite.sh"
mkdir -p "$XSCHEM_OWED_DIR/suite"
printf '1740000000\tLEGACYP_suite\ta legacy suite debt\n' > "$XSCHEM_OWED_DIR/suite/LEGACYP_suite"
"$S42" drain --display ":test" > "$TMP/drain41.out" 2>&1
ck "O43c drain CLAIMS a legacy suite debt, and runs it" 1 \
   "$($GREP -c "$LEGACY_ADD" "$TMP/drain41.out")"
ck "O43c ...and a pass clears it, exactly as it always did" 0 \
   "$([ -e "$XSCHEM_OWED_DIR/suite/LEGACYP_suite" ] && echo 1 || echo 0)"

# --- O44: a clone that MOVES orphans its own queue, and restamp is the way back
# (R613) -----------------------------------------------------------------------
# The stamp is an ABSOLUTE PATH. Measured 2026-09-10 by running this clone's
# owed.sh from a copy of the tree at another path against a copy of the live
# ledger: all 196 entries read foreign, `show` marked 187 of 187 rule+look
# `filed in another clone`, `clear` on the user's OWN look debt was refused
# exit 5, and `drain` reported nothing of its own to do. Nothing is destroyed --
# refusal is the safe direction -- but the user's whole queue appears to belong
# to nobody, and before that morning moving a checkout cost nothing.
rm -rf "$XSCHEM_OWED_DIR"
IDMV=$(mk_clone_at r4 moving)
"$IDMV/tests/headless/owed.sh" add rule 7001 "a ruling filed before the move" >/dev/null 2>&1
"$IDMV/tests/headless/owed.sh" add look "a look filed before the move" "pixels" >/dev/null 2>&1
mv "$IDMV" "$FX/r4/moved"
IDMV2=$(cd "$FX/r4/moved" && pwd -P)
SMV="$IDMV2/tests/headless/owed.sh"
"$SMV" clear rule 7001 >/dev/null 2>&1
ck "O44 after a move, the user's OWN debt is refused, exit 5" 5 "$?"
ck "O44 ...and every entry the clone filed reads as another clone's" 2 \
   "$("$SMV" list 2>&1 | $GREP -c 'another clone')"
log44=$(logbytes)
out=$("$SMV" restamp --from "$IDMV" --dry-run 2>&1); rc=$?
ck "O44 restamp --dry-run exits 0 and names what it would do" 0 "$rc"
ck "O44 ...listing both entries" 2 "$(printf '%s\n' "$out" | $GREP -c 'would restamp')"
ck "O44 ...and writing NOTHING" "$log44" "$(logbytes)"
ck "O44 ...the entry still carrying its old stamp" 1 \
   "$($GREP -cF "repo:$IDMV" "$XSCHEM_OWED_DIR/rule/7001")"
"$SMV" restamp --from "$IDMV" >/dev/null 2>&1
ck "O44 restamp exits 0" 0 "$?"
ck "O44 ...and re-points the entry to where the clone now is" 1 \
   "$($GREP -cF "repo:$IDMV2" "$XSCHEM_OWED_DIR/rule/7001")"
ck "O44 ...recording that a HUMAN asserted this, not git or the filesystem" 1 \
   "$($GREP -c '^repo_via:restamped$' "$XSCHEM_OWED_DIR/rule/7001")"
ck "O44 ...with a pre-image per entry" 2 \
   "$($GREP -c '	restamped	' "$XSCHEM_OWED_DIR/cleared.log")"
ck "O44 ...show marks none of them foreign any more" 0 \
   "$("$SMV" show 2>&1 | $GREP -c 'filed in another clone')"
"$SMV" clear rule 7001 >/dev/null 2>&1
ck "O44 ...and the user can clear their own debt again" 0 "$?"
# THE GUARD. restamp is for a clone that MOVED, which is why its old path is
# gone. A live path is another tree's, and re-stamping its entries would be a
# mass transfer of another tree's rulings on one command line.
IDLIVE=$(mk_clone_at r4 stillhere)
"$IDLIVE/tests/headless/owed.sh" add rule 7002 "a live tree's ruling" >/dev/null 2>&1
out=$("$SMV" restamp --from "$IDLIVE" 2>&1); rc=$?
ck "O44 restamp REFUSES when --from is still a checkout, exit 5" 5 "$rc"
ck "O44 ...saying it still holds tests/headless/owed.sh" 1 \
   "$(printf '%s\n' "$out" | $GREP -c 'it still holds tests/headless/owed.sh')"
ck "O44 ...and that tree's entry is untouched" 1 \
   "$($GREP -cF "repo:$IDLIVE" "$XSCHEM_OWED_DIR/rule/7002")"
"$SMV" restamp --from here >/dev/null 2>&1
ck "O44 --from here is a usage error, exit 2 — nothing to do" 2 "$?"
"$SMV" restamp >/dev/null 2>&1
ck "O44 no --from at all is a usage error, exit 2 — it is never guessed" 2 "$?"
out=$("$SMV" restamp --from notaclone 2>&1); rc=$?
ck "O44 an unknown --from tag is a usage error, exit 2" 2 "$rc"
ck "O44 ...and the message names --from, not --repo" 1 \
   "$(printf '%s\n' "$out" | $GREP -c -- "--from 'notaclone'")"

# --- O45: `repo_via:` is a CLOSED SET (R608/R613) ------------------------------
# Nothing pinned this before. It matters because the field is the ledger's only
# record of WHAT KIND OF EVIDENCE the stamp is: `git` and `path` are answers the
# machine gave, `told` is a human's `--repo`, `restamped` is a human's assertion
# after a move. 195 of the 196 live entries read `told` at 12:31 on 2026-09-10
# because they were hand-stamped by the backfill -- which is exactly the sort of
# thing that must remain readable, and cannot be if a fifth value can appear
# without a check noticing. `add` writes three of the four; only `restamp`
# writes the fourth, and it must never be forgeable by an ordinary add.
"$SMV" add rule 7101 "stamped by asking git" >/dev/null 2>&1
PATH="$FX/nogit:$PATH" "$SMV" add rule 7102 "stamped by the path fallback" >/dev/null 2>&1
"$SMV" add rule 7103 "stamped because a human said so" --repo "$IDLIVE" >/dev/null 2>&1
# The expectation is $VIA, not the literal `git`: on a box whose git cannot
# answer --path-format the RIGHT answer here is `path`, and a hard-coded `git`
# turns a correct fallback into a red row (measured with a `git` shim that
# exits 1, 2026-09-10). O23 pins the same field the same way.
ck "O45 add records HOW the id was derived — git, or path where git cannot answer" "$VIA" \
   "$(sed -n 's/^repo_via://p' "$XSCHEM_OWED_DIR/rule/7101" | head -1)"
ck "O45 ...and path when it is asked with git unavailable" "path" \
   "$(sed -n 's/^repo_via://p' "$XSCHEM_OWED_DIR/rule/7102" | head -1)"
ck "O45 ...told when a --repo supplied it" "told" \
   "$(sed -n 's/^repo_via://p' "$XSCHEM_OWED_DIR/rule/7103" | head -1)"
ck "O45 restamp is the ONLY writer of the fourth value" 1 \
   "$(cat "$XSCHEM_OWED_DIR"/*/* 2>/dev/null | $GREP -c '^repo_via:restamped$')"
ck "O45 and NOTHING in the ledger carries a value outside the four" 0 \
   "$(cat "$XSCHEM_OWED_DIR"/*/* 2>/dev/null | sed -n 's/^repo_via://p' \
      | $GREP -vc '^\(git\|path\|told\|restamped\)$')"
ck "O45 ...every stamped entry has exactly one repo_via, on lines 2+" 0 \
   "$(for f in "$XSCHEM_OWED_DIR"/rule/* "$XSCHEM_OWED_DIR"/look/* "$XSCHEM_OWED_DIR"/suite/*; do
        [ -f "$f" ] || continue
        [ "$($GREP -c '^repo:' "$f")" = 0 ] && continue
        n=$(sed -n '2,$p' "$f" | $GREP -c '^repo_via:')
        [ "$n" = 1 ] || echo bad
      done | wc -l | tr -d ' ')"

# --- O46: TWO owed.sh VERSIONS AGAINST ONE LEDGER (the hole nothing closes) ---
#
# ⚠ THIS GROUP ASSERTS DESTRUCTION, NOT PROTECTION, AND THAT IS DELIBERATE.
# Everything from O23 to O45 is THIS script declining to write another clone's
# entry. The ledger lives in $HOME and the other checkout on this machine runs
# its OWN copy of owed.sh -- the 2026-09-04 one, still what
# `git show HEAD:tests/headless/owed.sh` produces -- which has never heard of
# `repo:`. Every earlier row runs ONE version against one ledger, and `OWED_SH`
# repoints the WHOLE suite at another copy, so it cannot reach this either: it
# is a RED-run knob, not a mixed-version fixture. This one builds the mixed
# fixture and pins what actually happens.
#
# What actually happens is that the old script destroys, at exit 0, printing
# `recorded`, taking `eyes:`, `ref:`, `repo:` and `repo_via:` with the ruling and
# leaving NO pre-image. Backfilling the ledger to 196/196 stamped on 2026-09-10
# did not narrow that by one byte -- it armed the half of the door that was
# never the problem. The rows below are true today and MUST GO RED the day
# somebody closes the hole: they are the record that it was open, not a blessing
# of it. The only thing that closes it is that clone running this file.
#
# The rows after the destroys are the ONLY thing this side has: detection, after
# the fact, and only while the wreckage is still a minority (O46's last two rows
# measure exactly where that stops working).
rm -rf "$XSCHEM_OWED_DIR"
OLDBLOB="$TMP/owed_stampblind.sh"
OLD_OK=0; OLD_REV=""
for rev in HEAD ddf1f58e; do
  git -C "$REPO" show "$rev:tests/headless/owed.sh" > "$OLDBLOB" 2>/dev/null || continue
  [ -s "$OLDBLOB" ] || continue
  if [ "$($GREP -c '_entry_repo' "$OLDBLOB")" = 0 ]; then OLD_OK=1; OLD_REV="$rev"; break; fi
done
if [ "$OLD_OK" = 1 ]; then
  chmod +x "$OLDBLOB"
  IDNEW=$(mk_clone_at r6 newclone)
  mkdir -p "$FX/r6/oldclone/tests/headless" "$FX/r6/oldclone/doc/claude/issues"
  git -C "$FX/r6/oldclone" init -q . >/dev/null 2>&1
  cp "$OLDBLOB" "$FX/r6/oldclone/tests/headless/owed.sh"
  chmod +x "$FX/r6/oldclone/tests/headless/owed.sh"
  IDOLD=$(cd "$FX/r6/oldclone" && pwd -P)
  SNEW="$IDNEW/tests/headless/owed.sh"
  SOLD="$IDOLD/tests/headless/owed.sh"
  ck "O46 the fixture's OLD script really is stamp-blind ($OLD_REV)" 0 \
     "$($GREP -c '_entry_repo\|_unstamped_verdict' "$SOLD")"
  ck "O46 ...and the new one is not" 1 \
     "$([ "$($GREP -c '_entry_repo' "$SNEW")" -gt 0 ] && echo 1 || echo 0)"
  : > "$IDNEW/doc/claude/issues/5001-a-ruling-nobody-answered.md"
  "$SNEW" add rule 5001 "a standing ruling, unanswered, needing eyes" --eyes >/dev/null 2>&1
  for i in 5002 5003 5004; do "$SNEW" add rule $i "another stamped ruling ($i)" >/dev/null 2>&1; done
  for i in 5001 5002 5003 5004; do sed -i '1s/^[0-9]*/1750000000/' "$XSCHEM_OWED_DIR/rule/$i"; done
  ck "O46 the standing entry has its ruling, its eyes tag, its ref and both stamp lines" 5 \
     "$(wc -l < "$XSCHEM_OWED_DIR/rule/5001" | tr -d ' ')"
  # (1) THE OVERWRITE. This is the 10:46:14 defect, reproduced.
  out=$("$SOLD" add rule 5001 "the other clone records something unrelated" 2>&1); rc=$?
  ck "O46 the old script's add over a stamped ruling EXITS 0 — nothing stops it" 0 "$rc"
  ck "O46 ...and prints 'recorded', where this clone would say 'updated'" 1 \
     "$(printf '%s\n' "$out" | $GREP -c 'recorded rule debt')"
  ck "O46 ...the unanswered ruling is GONE" 0 \
     "$($GREP -c 'a standing ruling, unanswered' "$XSCHEM_OWED_DIR/rule/5001")"
  ck "O46 ...its eyes tag with it" 0 "$($GREP -c '^eyes:1$' "$XSCHEM_OWED_DIR/rule/5001")"
  ck "O46 ...its pointer to the option set with it" 0 \
     "$($GREP -c '^ref:' "$XSCHEM_OWED_DIR/rule/5001")"
  ck "O46 ...and BOTH stamp lines, so the ledger cannot even say whose it was" 0 \
     "$($GREP -c '^repo' "$XSCHEM_OWED_DIR/rule/5001")"
  ck "O46 ...leaving NO pre-image: nothing anywhere records what it destroyed" 0 \
     "$([ -e "$XSCHEM_OWED_DIR/cleared.log" ] && echo 1 || echo 0)"
  # (2) THE CLEAR. An rm by exact filename, in silence.
  out=$("$SOLD" clear rule 5002 2>&1); rc=$?
  ck "O46 the old script's clear of a stamped entry exits 0 too" 0 "$rc"
  ck "O46 ...the entry is gone" 0 \
     "$([ -e "$XSCHEM_OWED_DIR/rule/5002" ] && echo 1 || echo 0)"
  ck "O46 ...and still no pre-image" 0 \
     "$([ -e "$XSCHEM_OWED_DIR/cleared.log" ] && echo 1 || echo 0)"
  # (3) THE DRAIN. It runs ITS OWN file of that name and clears THIS clone's
  # debt on the pass -- an automated verdict discharging work it never did, one
  # directory over. Both clones get a file of the same name, each with its own
  # witness, so which one ran is a fact and not an inference.
  for c in "$IDNEW" "$IDOLD"; do
    cat > "$c/tests/headless/SHAREDX_suite.sh" <<EOF
#!/bin/bash
echo ran > "$TMP/o46_witness.$(basename "$c")"
echo "RESULT: ALL PASS (1 checks)"
exit 0
EOF
    chmod +x "$c/tests/headless/SHAREDX_suite.sh"
  done
  rm -f "$TMP/o46_witness.newclone" "$TMP/o46_witness.oldclone"
  "$SNEW" add suite SHAREDX_suite "a :0 run THIS clone owes" >/dev/null 2>&1
  ck "O46 the suite debt is stamped to the clone that owes it" 1 \
     "$($GREP -cF "repo:$IDNEW" "$XSCHEM_OWED_DIR/suite/SHAREDX_suite")"
  "$SOLD" drain --display ":test" > "$TMP/drain46.out" 2>&1
  ck "O46 the old script drains it anyway, and clears the debt on a pass" 0 \
     "$([ -e "$XSCHEM_OWED_DIR/suite/SHAREDX_suite" ] && echo 1 || echo 0)"
  ck "O46 ...having run ITS OWN file of that name" 1 \
     "$([ -e "$TMP/o46_witness.oldclone" ] && echo 1 || echo 0)"
  ck "O46 ...not the file of the clone that owed it" 0 \
     "$([ -e "$TMP/o46_witness.newclone" ] && echo 1 || echo 0)"
  # (4) WHAT THIS SIDE CAN STILL DO: notice, afterwards. Nothing more.
  ck "O46 this clone's add over the wreckage REFUSES, exit 5" 5 \
     "$("$SNEW" add rule 5001 "new work on that number" >/dev/null 2>&1; echo $?)"
  ck "O46 ...and list marks the slot as written by something that does not stamp" 1 \
     "$("$SNEW" list 2>&1 | $GREP -c 'no clone recorded, and written after stamping began here')"
  # (5) AND WHERE THE DETECTION STOPS. The verdict is a MAJORITY vote: an
  # unstamped entry is evidence only while the stamped ones outnumber it. Let
  # the old script take the rest and the evidence becomes the norm -- the same
  # ledger, the same wreckage, and this clone claims it as legacy at exit 0.
  ck "O46 detection holds while the wreckage is a minority" "2 1" \
     "$($GREP -l '^repo:' "$XSCHEM_OWED_DIR"/rule/* | wc -l | tr -d ' ') $($GREP -L '^repo:' "$XSCHEM_OWED_DIR"/rule/* | wc -l | tr -d ' ')"
  "$SOLD" add rule 5003 "the old script takes another" >/dev/null 2>&1
  "$SOLD" add rule 5004 "and the last one" >/dev/null 2>&1
  ck "O46 ...but once it is the majority, nothing is stamped at all" "0 3" \
     "$($GREP -l '^repo:' "$XSCHEM_OWED_DIR"/rule/* 2>/dev/null | wc -l | tr -d ' ') $($GREP -L '^repo:' "$XSCHEM_OWED_DIR"/rule/* | wc -l | tr -d ' ')"
  out=$("$SNEW" add rule 5001 "new work, second try" 2>&1); rc=$?
  ck "O46 ...and this clone stops refusing: it CLAIMS the wreckage, exit 0" 0 "$rc"
  ck "O46 ...calling it legacy, which is the one thing it certainly is not" 1 \
     "$(printf '%s\n' "$out" | $GREP -c 'predates origin stamps')"
  ck "O46 ...the ledger holding a pre-image of THIS clone's own write" 1 \
     "$($GREP -c '^=== ' "$XSCHEM_OWED_DIR/cleared.log")"
  ck "O46 ...and of NONE of the four destroys the old script performed" 0 \
     "$($GREP -c 'a standing ruling, unanswered\|another stamped ruling' \
        "$XSCHEM_OWED_DIR/cleared.log")"
else
  skipck "O46 the two-version fixture (no stamp-blind owed.sh in git: neither HEAD nor ddf1f58e). THE HOLE IS NOT CLOSED BY THIS SKIP."
fi

# --- O13: one REAL drain, so the stub cannot hide an integration break --------
#
# ⚠ THIS ROW LAUNCHES THE REAL BINARY, ON WHATEVER $DISPLAY IT INHERITS. Falling
# back to $DISPLAY means the user's own screen: on this machine $DISPLAY is the
# Windows X server they are looking at (~/.profile:48), which is not `:0` and
# not the dev display, and CLAUDE.md's rule is that a GUI run lands on the dev
# display unless the point IS the real screen. It is announced rather than
# silently done, and `OWED_TEST_DISPLAY=none` opts out entirely -- which is what
# a run that must not start xschem should pass. Preferring the dev display by
# default is a change to what this row MEANS, so it is left for the user
# (2026-09-10, N3; the hazard was found by N2).
#
# ⚠ AND A SKIP HERE IS NOT COVERAGE. Every published run of this suite -- N3's,
# its adversary's, and every run under the batch rule that forbids launching the
# binary -- passed OWED_TEST_DISPLAY=none or had no DISPLAY, so the live arm
# below has NEVER BEEN EXECUTED BY ANYONE. `N checks, 1 skipped` reads like a
# pass and is the opposite: the announcement line and the drain are unverified
# in the branch they are taken in. The banner says so out loud at the end rather
# than leaving it to be inferred from a one-word `skip:`.
# (`full_audit.sh:393` globs `test_*.tcl`, so this file is outside the audit set
# and O13 can only ever fire on a hand-run.)
rm -rf "$XSCHEM_OWED_DIR"
O13_LIVE=0
DPY="${OWED_TEST_DISPLAY:-${DISPLAY:-}}"
[ "$DPY" = "none" ] && DPY=""
if [ -n "$DPY" ] && [ -x "$REPO/src/xschem" ] && [ -f "$HERE/test_calc_skeleton.tcl" ]; then
  O13_LIVE=1
  echo "note: O13 runs the real xschem binary on DISPLAY=$DPY (OWED_TEST_DISPLAY=none skips it)"
  "$OWED" add suite test_calc_skeleton "real end-to-end drain" >/dev/null 2>&1
  GUI_GATE=0 timeout 400 "$OWED" drain --display "$DPY" > "$TMP/drain3.out" 2>&1
  rc=$?
  ck "O13 a real drain of a passing suite exits 0" 0 "$rc"
  ck "O13 ...and cleared the debt" 0 \
     "$(ls -1 "$XSCHEM_OWED_DIR/suite" 2>/dev/null | wc -l | tr -d ' ')"
else
  if [ "${OWED_TEST_DISPLAY:-}" = "none" ]; then
    skipck "O13 (OWED_TEST_DISPLAY=none -- asked not to start the binary). NOT COVERAGE."
  else
    skipck "O13 (no display or no built binary). NOT COVERAGE."
  fi
fi

# -----------------------------------------------------------------------------
echo
# ⚠ THE CHECK COUNT IS ENVIRONMENT-DEPENDENT, so it is not a floor on its own.
# Where git cannot answer, THREE legs skip as one -- O24's worktree/branch/remote
# legs, O39's worktree leg, and the whole of O46, which needs `git show` to
# produce the stamp-blind script it runs beside this one -- and the suite reports
# THIRTY FEWER CHECKS at ALL PASS. That is correct behaviour a reader applying a
# hard number would score as a regression. Measured 2026-09-10 on the
# second-repair owed.sh, both ALL PASS: 365 checks / 1 skipped where git answers,
# 335 / 4 with a `git` shim that exits 1. Acceptance is NAME + STATUS, per check,
# never a count (LEDGER.md), and the floor RISES when rows are added: it was 75,
# then 233, and it is 365 here.
echo "env:  git answers --path-format: $([ "$GIT_OK" = 1 ] && echo yes || echo "no -- the O24, O39 and O46 legs skip, 30 fewer checks")"
if [ "$O13_LIVE" = 1 ]; then
  echo "env:  O13's live arm RAN (the real binary, DISPLAY=$DPY)."
else
  echo "env:  O13's live arm did NOT run, and a skip is NOT a pass -- the one row"
  echo "      that launches the real binary is unexecuted, in every published run"
  echo "      of this suite so far. Do not read the 'skipped' count as coverage."
fi
if [ "$fail" -eq 0 ]; then
  if [ "$skip" -gt 0 ]; then echo "RESULT: ALL PASS ($pass checks, $skip skipped)"
  else echo "RESULT: ALL PASS ($pass checks)"; fi
  exit 0
fi
echo "RESULT: $fail FAILED ($pass passed, $skip skipped)"
exit 1
