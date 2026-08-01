#!/bin/bash
# review_gate.sh — shell side of the "review requested" panel.
# See tools/review_gate/review_gate_widget.tcl and doc/claude/specs/review_gate.md
#
# Raise one review request and BLOCK until the user answers or the request
# times out, then print the verdict on stdout:
#
#   DECISION: PROCEED | STOP | TIMEOUT | NOGATE
#   NOTES:
#   <whatever the user typed, possibly empty>
#
# Exit status:  0 = go on to the next item (PROCEED / TIMEOUT / NOGATE)
#               3 = the user pressed Stop; do not start the next item
#
# Usage:
#   review_gate.sh --label "Item 5 — e deletes empty strips" \
#                  --body-file /path/to/summary.md \
#                  [--timeout 1800] [--out /path/to/verdict.txt]
#
# The caller normally runs this in the BACKGROUND (a 30-minute foreground wait
# exceeds the agent's per-command timeout) and reads --out when it exits.
#
# FAILS OPEN: no DISPLAY, no wish, REVIEW_GATE=0, or a panel that will not
# launch -> prints NOGATE and exits 0 immediately. A review gate that can wedge
# the build loop is worse than no review gate.

set -u

DIR="${REVIEW_GATE_DIR:-$HOME/.claude/review_gate}"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL=""
BODY_FILE=""
TIMEOUT="${REVIEW_GATE_TIMEOUT:-1800}"
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --label)     LABEL="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --out)       OUT="$2"; shift 2 ;;
    --dir)       DIR="$2"; shift 2 ;;
    -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "review_gate.sh: unknown arg '$1'" >&2; exit 64 ;;
  esac
done
[ -n "$LABEL" ] || LABEL="review requested (pid $$)"

emit() {  # emit <decision> [notes-file]
  local dec="$1" nf="${2:-}"
  { printf 'DECISION: %s\n' "$dec"
    printf 'NOTES:\n'
    [ -n "$nf" ] && [ -f "$nf" ] && cat "$nf"
  } | tee ${OUT:+"$OUT"}
}

_enabled() {
  [ "${REVIEW_GATE:-1}" = "0" ] && return 1
  [ -z "${DISPLAY:-}" ] && return 1
  command -v wish >/dev/null 2>&1 || return 1
  return 0
}

_alive() {
  local pf="$DIR/widget.pid" wp
  [ -f "$pf" ] || return 1
  wp="$(cat "$pf" 2>/dev/null)"
  [ -n "$wp" ] && kill -0 "$wp" 2>/dev/null
}

_ensure_widget() {
  _alive && return 0
  # NEVER /dev/null. The first time this panel died on its own the gate did the
  # right thing and failed open — and there was no way to find out WHY, because
  # wish's stderr had been discarded. A gate that fails open silently and
  # untraceably is a gate that quietly stops being a gate. The log is truncated
  # per launch, so it cannot grow without bound.
  local log="$DIR/widget.log"
  # setsid: the panel is a singleton meant to outlive the request that spawned
  # it. Left in the caller's process group, the routine teardown of a
  # background task (kill -TERM -<pgid>) takes the panel with it — measured on
  # the GUI-test gate, same fix. A stale pid file loses the singleton race
  # harmlessly; _alive kill -0's it.
  if command -v setsid >/dev/null 2>&1; then
    ( setsid wish "$SELF_DIR/review_gate_widget.tcl" "$DIR" >"$log" 2>&1 & )
  else
    ( wish "$SELF_DIR/review_gate_widget.tcl" "$DIR" >"$log" 2>&1 & )
  fi
  local i
  for i in $(seq 1 20); do _alive && return 0; sleep 0.15; done
  _alive
}

# A panel that dies mid-wait used to end the review outright ("panel gone,
# proceeding"). That is the correct FALLBACK but a poor first response: the
# request is still pending, the user has still not seen it, and relaunching
# costs one process. Try once to bring it back, and only give up — failing
# open, as always — if it will not stay up.
_revive_widget() {
  rm -f "$DIR/widget.pid"
  _ensure_widget || return 1
  # re-arm the countdown: the user cannot answer during the window in which
  # there was no window to answer in.
  [ "$TIMEOUT" -gt 0 ] 2>/dev/null && printf '%s' "$(( $(date +%s) + TIMEOUT ))" > "$DEAD"
  return 0
}

# Pop the panel where the user actually IS. Under a virtual-desktop manager
# (VirtuaWin) a window created on desktop A is unreachable from desktop B and
# raise/-topmost act only within a desktop, so the only reliable attention
# mechanism is to relaunch: a fresh window maps on the current desktop. TERM,
# not the WM close path — the close handler replies PROCEED to everything
# pending, which would release the request we are about to raise.
_attention() {
  local stamp="$DIR/last_raise" now prev wp i
  now="$(date +%s)"
  if [ -f "$stamp" ]; then
    prev="$(cat "$stamp" 2>/dev/null || echo 0)"
    [ "$((now - prev))" -lt 10 ] && return 0
  fi
  printf '%s' "$now" > "$stamp"
  if _alive; then
    wp="$(cat "$DIR/widget.pid" 2>/dev/null)"
    kill "$wp" 2>/dev/null
    for i in $(seq 1 10); do _alive || break; sleep 0.1; done
    _alive && kill -9 "$wp" 2>/dev/null
    rm -f "$DIR/widget.pid"
  fi
  _ensure_widget
}

ID="$$"
mkdir -p "$DIR"/{req,body,reply,hold,deadline}
REQ="$DIR/req/$ID"; BODY="$DIR/body/$ID"; REPLY="$DIR/reply/$ID"
HOLD="$DIR/hold/$ID"; DEAD="$DIR/deadline/$ID"

cleanup() { rm -f "$REQ" "$BODY" "$HOLD" "$DEAD" 2>/dev/null; }
trap 'cleanup; exit 0' TERM INT

if ! _enabled; then
  emit NOGATE
  exit 0
fi

printf '%s' "$LABEL" > "$REQ"
if [ -n "$BODY_FILE" ] && [ -f "$BODY_FILE" ]; then
  cp "$BODY_FILE" "$BODY"
else
  : > "$BODY"
fi

_attention
if ! _ensure_widget; then
  echo "review_gate: panel unavailable, proceeding without review" >&2
  cleanup
  emit NOGATE
  exit 0
fi

# The countdown is per-request and OWNED BY THIS SCRIPT, not by the panel — the
# panel only displays it and freezes it via the hold file. That way a panel
# that is killed and relaunched (which _attention does routinely) cannot lose
# or restart the deadline.
if [ "$TIMEOUT" -gt 0 ] 2>/dev/null; then
  printf '%s' "$(( $(date +%s) + TIMEOUT ))" > "$DEAD"
fi

echo "review_gate: '$LABEL' — waiting up to ${TIMEOUT}s for review" >&2

while true; do
  if [ -f "$REPLY" ]; then
    verdict="$(head -n1 "$REPLY" 2>/dev/null)"
    tail -n +2 "$REPLY" > "$DIR/notes.$ID" 2>/dev/null
    rm -f "$REPLY"
    cleanup
    case "$verdict" in
      STOP) emit STOP "$DIR/notes.$ID"; rm -f "$DIR/notes.$ID"; exit 3 ;;
      *)    emit PROCEED "$DIR/notes.$ID"; rm -f "$DIR/notes.$ID"; exit 0 ;;
    esac
  fi

  # A dead panel must not strand the request: the user cannot answer a window
  # that is not there. But try to bring it back FIRST — a panel that died on
  # its own (it has happened) should cost a relaunch, not the whole review.
  # Only one revival, so a panel that cannot stay up degrades to fail-open
  # instead of spinning.
  if ! _alive; then
    if [ "${_revived:-0}" = "0" ]; then
      _revived=1
      echo "review_gate: panel died, relaunching once" >&2
      if _revive_widget; then
        sleep 1
        continue
      fi
    fi
    echo "review_gate: panel gone, proceeding (see $DIR/widget.log)" >&2
    cleanup
    emit NOGATE
    exit 0
  fi

  # Hold freezes the countdown by pushing the deadline forward one tick. This
  # is the ONLY state that blocks indefinitely, and it means the user is
  # demonstrably at the desk.
  if [ -f "$HOLD" ] && [ -f "$DEAD" ]; then
    printf '%s' "$(( $(date +%s) + TIMEOUT ))" > "$DEAD"
  elif [ -f "$DEAD" ]; then
    now="$(date +%s)"; dl="$(cat "$DEAD" 2>/dev/null || echo 0)"
    if [ "$now" -ge "$dl" ]; then
      cleanup
      echo "review_gate: no review within ${TIMEOUT}s, proceeding" >&2
      emit TIMEOUT
      exit 0
    fi
  fi

  sleep 1
done
