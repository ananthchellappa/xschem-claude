#!/bin/bash
# test_owed.sh — the owed ledger (doc/claude/specs/owed.md, O1..O13).
#
# The headline is O9: `drain` must not touch the look list. That is the rule the
# whole design exists to protect -- an automated verdict may never discharge a
# human one -- and it is the one a future refactor is most likely to "simplify"
# away.
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

# --- O1/O2: recording, and the two lists staying apart -----------------------
"$OWED" add suite alpha_suite "needs a real screen" >/dev/null 2>&1
ck "O1 add suite exits 0" 0 "$?"
"$OWED" add look "the pane proportions" "pixels, tests cannot see it" >/dev/null 2>&1
ck "O2 add look exits 0" 0 "$?"
ck "O1 count reports both lists" "1 suite, 1 look" "$("$OWED" count)"
ck "O2 suite list has only the suite" 1 \
   "$("$OWED" list suite | grep -c alpha_suite)"
ck "O2 suite list does NOT contain the look entry" 0 \
   "$("$OWED" list suite | grep -c 'pane proportions')"

# --- O3/O4: dedupe for suites, never for looks -------------------------------
"$OWED" add suite alpha_suite "a newer reason" >/dev/null 2>&1
ck "O3 re-adding a suite does not duplicate it" "1 suite, 1 look" "$("$OWED" count)"
ck "O3 ...and the newer reason wins" 1 \
   "$("$OWED" list suite | grep -c 'a newer reason')"
"$OWED" add look "the pane proportions" "a DIFFERENT thing, same words" >/dev/null 2>&1
ck "O4 an identically-worded look is NOT merged away" "1 suite, 2 look" "$("$OWED" count)"

# --- O5: an unknown kind is an error, not a third list -----------------------
"$OWED" add banana x y >/dev/null 2>&1
ck "O5 unknown kind is an error" 2 "$?"
ck "O5 ...and created nothing" 0 \
   "$(ls -1 "$XSCHEM_OWED_DIR" 2>/dev/null | grep -c banana)"

# --- O11: only `clear look` clears a look ------------------------------------
lookid=$(ls -1 "$XSCHEM_OWED_DIR/look" | head -1)
"$OWED" clear look "$lookid" >/dev/null 2>&1
ck "O11 clear look removes exactly one" "1 suite, 1 look" "$("$OWED" count)"
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
