#!/bin/sh
# Aggregate every test_wireedit_*.tcl in this dir: print each RESULT line and exit
# nonzero if any test FAILS or produces no RESULT. Spec: Phase 0.2.
#
# These tests drive the scripted edit path (move_objects etc.), which is byte-identical
# to the interactive drag's release -- so they run TRUE HEADLESS via --nogui (no X server,
# no window; options.c sets has_x=0). DISPLAY is deliberately unset so a stray server can't
# turn this into a windowed run. This avoids the WSLg flakiness (empty stdout / exit 127)
# that windowed runs hit. (The GESTURE tests -- test_cadence_drag.tcl -- DO need a real
# window and are not part of this aggregate.) Run from anywhere; it locates the repo root.
#
# Usage: run_wireedit.sh [--memcheck]
#   (default)   functional run; each test must print "RESULT: ALL PASS".
#   --memcheck  ALSO run every test under valgrind memcheck and FAIL it on any memory error
#               (invalid read/write, uninitialised-value use, heap-buffer-overflow). Leak-check
#               is OFF on purpose: xschem's xctx is a deliberately long-lived global, so exit-time
#               "still reachable"/"lost" blocks are pre-existing noise -- the CORRUPTION class is
#               what regresses (it is what the movelastsel/symbol_bbox overflow was). ~20-50x
#               slower, so the per-test timeout is raised. The move/reroute code is heap-churny
#               (per-snap wire mutation in the incremental phases), so run this gate per phase.
#
#   NOTE (gotcha): `env -u DISPLAY` is the OUTER wrapper and valgrind's target is ./src/xschem.
#   Never write `valgrind env -u DISPLAY ./src/xschem` -- valgrind would trace `env`, which
#   execve()s xschem and ESCAPES the trace (no --trace-children), reporting a bogus "0 errors".
root=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$root" || exit 2

# Binary: honor the $XSCHEM override full_audit.sh documents (review wf_bfc3c5e4: this suite
# silently tested the in-tree binary while the audit's tcl tests ran the override's).
XSCHEM="${XSCHEM:-./src/xschem}"
if [ ! -x "$XSCHEM" ]; then echo "WIREEDIT FATAL: xschem binary not found/executable at: $XSCHEM" >&2; exit 2; fi

memcheck=0
idempotent=0
case "$1" in
  --memcheck|memcheck)     memcheck=1 ;;
  --idempotent|idempotent) idempotent=1 ;;   # D5: run the whole suite under FLUID_IDEMPOTENT_CHECK
  "") ;;
  *) echo "usage: $(basename "$0") [--memcheck|--idempotent]" >&2; exit 2 ;;
esac

if [ "$memcheck" -eq 1 ]; then
  TIMEOUT=600
  # --error-exitcode=99: valgrind returns 99 if it detects ANY error (authoritative fail signal,
  # independent of the summary text). --track-origins: pinpoint uninitialised reads.
  VG="valgrind --error-exitcode=99 --leak-check=no --track-origins=yes"
  LABEL="WIREEDIT MEMCHECK"
elif [ "$idempotent" -eq 1 ]; then
  # D5 idempotence oracle: FLUID_IDEMPOTENT_CHECK=1 makes the END-cleanup driver re-run the cluster
  # after finalization; any pass that changes the wire set on round 2 prints
  # FLUID_IDEMPOTENCE_VIOLATION to stderr (the 0111 oscillation class as a property). A correct
  # build is a fixpoint, so the suite must stay ALL PASS with no violation line.
  TIMEOUT=60
  VG=""
  LABEL="WIREEDIT IDEMPOTENT"
else
  TIMEOUT=60
  VG=""
  LABEL="WIREEDIT"
fi

fail=0
ran=0
for t in tests/headless/wireedit/test_wireedit_*.tcl; do
  [ -e "$t" ] || continue
  ran=$((ran + 1))
  if [ "$idempotent" -eq 1 ]; then
    out=$(env -u DISPLAY FLUID_IDEMPOTENT_CHECK=1 timeout "$TIMEOUT" "$XSCHEM" --nogui --pipe -q --nolog --script "$t" 2>&1)
  else
    out=$(env -u DISPLAY timeout "$TIMEOUT" $VG "$XSCHEM" --nogui --pipe -q --nolog --script "$t" 2>&1)
  fi
  rc=$?
  line=$(printf '%s\n' "$out" | grep -E '^RESULT:' | tail -1)
  status="${line:-NO RESULT}"
  ok=0
  case "$line" in "RESULT: ALL PASS") ok=1 ;; esac
  if [ "$idempotent" -eq 1 ]; then
    viol=$(printf '%s\n' "$out" | grep -E 'FLUID_IDEMPOTENCE_VIOLATION' | head -1)
    if [ -n "$viol" ]; then
      status="$status | IDEMPOTENCE FAIL ($viol)"
      ok=0
    else
      status="$status | fixpoint clean"
    fi
  fi
  if [ "$memcheck" -eq 1 ]; then
    summary=$(printf '%s\n' "$out" | grep -oE 'ERROR SUMMARY: [0-9]+ errors( from [0-9]+ contexts)?' | tail -1)
    # rc==99 is valgrind's --error-exitcode (ANY memory error). rc==124 is a timeout. Either => fail.
    # (A hard crash produces no "RESULT: ALL PASS", so the functional check above already fails it.)
    if [ "$rc" -eq 99 ] || [ "$rc" -eq 124 ]; then
      status="$status | MEMCHECK FAIL (rc=$rc ${summary:-no summary})"
      ok=0
    else
      status="$status | memcheck clean (${summary:-no summary})"
    fi
  fi
  echo "$(basename "$t"): $status"
  if [ "$ok" -ne 1 ]; then
    fail=1
    # Failure detail: the RESULT line alone doesn't say WHICH check regressed (review
    # wf_bfc3c5e4) -- dump the failing test's full output so CI logs are actionable.
    echo "------ full output: $(basename "$t") ------"
    printf '%s\n' "$out"
    echo "------ end output ------"
  fi
done
if [ "$ran" -eq 0 ]; then echo "$LABEL: no tests found"; exit 2; fi
if [ "$fail" -eq 0 ]; then echo "$LABEL: ALL PASS"; else echo "$LABEL: FAILURES"; fi
exit $fail
