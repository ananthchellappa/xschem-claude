#!/bin/bash
# owed.sh — the ledger of debts that need the real screen or the real user.
#
# WHY THIS EXISTS
#
# After devdisplay.sh, routine GUI testing does not touch the developer's screen
# at all. Two obligations survive, and both arrive at the worst possible
# cadence: scattered, one at a time, whenever a feature happens to finish.
#
#   1. "run a GUI feature's suite on :0 once before calling it done" (CLAUDE.md)
#   2. "the report is 'suites green, please look' -- not 'done'" for anything
#      whose deliverable is pixels (doc/claude/specs/... , and the incident that
#      produced that rule: two defects shipped past 28 passing checks)
#
# The cost is not runtime -- a suite is seconds. The cost is the NUMBER of
# interruptions. Three two-minute ones at moments the user did not choose are
# worse than one six-minute block they did. The gate already batches APPROVAL
# ("Allow 30m" / "Forever"); nothing batched the work, because nothing recorded
# it. This records it.
#
# THE ONE RULE THIS FILE EXISTS TO PROTECT
#
# There are TWO lists and they are not interchangeable:
#
#            suite debt                     look debt
#   pays     a script                       the USER
#   verdict  PASS/FAIL                      judgment
#   clears   itself, on a pass              ONLY `owed.sh clear look <id>`
#
# No code path here converts one into the other, and `drain` does not so much as
# read the look list. A ledger that cleared an eyeball because a suite went
# green would be precisely the defect the eyeball rule was written about.
#
# Spec: doc/claude/specs/owed.md
#
# USAGE
#   owed.sh add suite <name> [why]      owed.sh list [suite|look]
#   owed.sh add look <what> [why]       owed.sh show
#   owed.sh drain [--display :0]        owed.sh clear <suite|look> <id>
#   owed.sh count
#
#   XSCHEM_OWED_DIR   state dir, default $HOME/.claude/xschem_owed

set -u

OWED_DIR="${XSCHEM_OWED_DIR:-$HOME/.claude/xschem_owed}"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

_say()  { echo "owed: $*" >&2; }
_warn() { echo "!! owed WARNING: $1" >&2; }
_die()  { echo "!! owed ERROR: $1" >&2; exit "${2:-1}"; }

_dir()  { echo "$OWED_DIR/$1"; }

# One entry per file: <epoch>\t<subject>\t<reason>. A file per entry rather than
# a single appended list so two concurrent sessions -- the main one and a
# worktree -- cannot interleave writes into the same line.
_slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64; }

# Returns non-zero rather than calling _die: every caller invokes this inside a
# command substitution, and `exit` in `$( )` only ends the SUBSHELL. Dying here
# left the parent running with an empty $d, which then failed further down on
# `mkdir ""` -- reporting the wrong error with the wrong exit code. Let the
# status propagate and let the caller die.
_kind_dir() {
  case "$1" in
    suite|look) _dir "$1" ;;
    *) return 2 ;;
  esac
}
_bad_kind() { _die "unknown kind '$1' -- expected 'suite' or 'look'" 2; }

# Read an entry, or fail. A hand-edited or truncated file must not be fatal to
# the rest of the ledger, and must not be silently skipped either.
_read_entry() {  # $1 path -> prints "epoch<TAB>subject<TAB>reason"
  local line
  line=$(head -1 "$1" 2>/dev/null) || return 1
  case "$line" in
    ''|*[!0-9]*"	"*) ;;
  esac
  local epoch=${line%%	*}
  case "$epoch" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s' "$line"
}

_age_days() {  # $1 epoch
  local now; now=$(date +%s)
  echo $(( (now - $1) / 86400 ))
}

# ---------------------------------------------------------------------------
cmd_add() {
  local kind="${1:-}" subject="${2:-}" why="${3:-}"
  [ -n "$kind" ] && [ -n "$subject" ] || _die "usage: $0 add <suite|look> <what> [why]" 2
  local d; d=$(_kind_dir "$kind") || _bad_kind "$kind"
  mkdir -p "$d" || _die "cannot create $d" 3

  local id
  case "$kind" in
    suite)
      # DEDUPED by name: the same suite owing a :0 run twice is one debt, and
      # the newer reason is the informative one.
      id=$(_slug "$subject")
      ;;
    look)
      # NEVER deduped. Two different things can carry the same description
      # ("the marker callout"), and merging them would silently drop one -- the
      # exact class of loss this ledger exists to prevent. Unique id per add.
      id="$(_slug "$subject").$(date +%s).$$"
      ;;
  esac
  printf '%s\t%s\t%s\n' "$(date +%s)" "$subject" "$why" > "$d/$id"
  _say "recorded $kind debt: $subject"
}

cmd_list() {
  local want="${1:-}"
  case "$want" in ''|suite|look) ;; *) _die "unknown kind '$want'" 2 ;; esac
  local total=0 k d f line epoch subject reason
  for k in suite look; do
    [ -n "$want" ] && [ "$want" != "$k" ] && continue
    d=$(_dir "$k")
    local n=0
    for f in "$d"/*; do
      [ -e "$f" ] || continue
      if ! line=$(_read_entry "$f"); then
        _warn "skipping unreadable entry $f"
        continue
      fi
      if [ "$n" -eq 0 ]; then
        case "$k" in
          suite) echo "SUITE debts — a :0 run each; cleared automatically when one passes" ;;
          look)  echo "LOOK debts — need YOUR eyes; cleared only by 'owed.sh clear look <id>'" ;;
        esac
      fi
      n=$((n + 1)); total=$((total + 1))
      epoch=${line%%	*}; line=${line#*	}
      subject=${line%%	*}; reason=${line#*	}
      printf '  [%s] %-34s %3sd  %s\n' "$(basename "$f")" "$subject" "$(_age_days "$epoch")" "$reason"
    done
    [ "$n" -gt 0 ] && echo
  done
  [ "$total" -eq 0 ] && echo "nothing owed."
  return 0
}

cmd_count() {
  local s l
  s=$(ls -1 "$(_dir suite)" 2>/dev/null | wc -l | tr -d ' ')
  l=$(ls -1 "$(_dir look)"  2>/dev/null | wc -l | tr -d ' ')
  echo "$s suite, $l look"
}

cmd_show() {
  local d f line epoch subject reason n=0
  d=$(_dir look)
  for f in "$d"/*; do
    [ -e "$f" ] || continue
    line=$(_read_entry "$f") || { _warn "skipping unreadable entry $f"; continue; }
    if [ "$n" -eq 0 ]; then
      echo "These need a HUMAN. No suite can discharge them — that is the point:"
      echo "a green suite is a precondition for asking you to look, never an answer."
      echo
    fi
    n=$((n + 1))
    epoch=${line%%	*}; line=${line#*	}
    subject=${line%%	*}; reason=${line#*	}
    printf '  %s\n' "$subject"
    [ -n "$reason" ] && printf '      why: %s\n' "$reason"
    printf '      waiting %s day(s)   clear with: %s clear look %s\n\n' \
           "$(_age_days "$epoch")" "$0" "$(basename "$f")"
  done
  if [ "$n" -eq 0 ]; then
    echo "no look debts."
    return 0
  fi
  echo "To serve these: tests/headless/devdisplay.sh view   (a VNC window onto the"
  echo "test display — your attention is what is scarce here, not the screen), or"
  echo "DISPLAY=:0 if the point IS how WSLg itself renders it."
}

cmd_clear() {
  local kind="${1:-}" id="${2:-}"
  [ -n "$kind" ] && [ -n "$id" ] || _die "usage: $0 clear <suite|look> <id>" 2
  local d; d=$(_kind_dir "$kind") || _bad_kind "$kind"
  [ -e "$d/$id" ] || _die "no $kind debt with id '$id' (see: $0 list)" 4
  rm -f "$d/$id"
  _say "cleared $kind debt $id"
}

# Run every queued SUITE debt in one batch on the real display.
#
# Deliberately goes through run_suites.sh rather than the binary: that is what
# enrols the run in the gate, so the user keeps Pause and Stop over a batch they
# approved once with "Forever".
cmd_drain() {
  local display=":0"
  while [ $# -gt 0 ]; do
    case "$1" in
      --display) shift; display="${1:-}"; [ -n "$display" ] || _die "--display needs a value" 2 ;;
      *) _die "unknown option '$1'" 2 ;;
    esac
    shift
  done

  local d; d=$(_dir suite)
  local names=() ids=() f line subject
  for f in "$d"/*; do
    [ -e "$f" ] || continue
    line=$(_read_entry "$f") || { _warn "skipping unreadable entry $f"; continue; }
    line=${line#*	}; subject=${line%%	*}
    names+=("$subject"); ids+=("$(basename "$f")")
  done

  if [ "${#names[@]}" -eq 0 ]; then
    echo "no suite debts to drain."
    echo "(look debts are untouched by drain, by design: $0 show)"
    return 0
  fi

  _say "draining ${#names[@]} suite debt(s) on $display"
  _say "the gate is live on a real display -- Pause and Stop still work"

  local ran=0 passed=0 failed=0 i
  for i in "${!names[@]}"; do
    ran=$((ran + 1))
    echo "== [$ran/${#names[@]}] ${names[$i]}"
    if AUDIT_DISPLAY="$display" "$HERE/run_suites.sh" "${names[$i]}"; then
      passed=$((passed + 1))
      rm -f "$d/${ids[$i]}"
      echo "   PASS -> debt cleared"
    else
      failed=$((failed + 1))
      # A failure must NOT clear the debt. A drain that loses work when a suite
      # goes red is a way to forget things, not a way to remember them.
      local now; now=$(date +%s)
      printf '%s\t%s\t%s\n' "$now" "${names[$i]}" \
             "FAILED on $display -- still owed" > "$d/${ids[$i]}"
      echo "   FAIL -> debt KEPT"
    fi
  done

  echo
  echo "drained: $ran run, $passed passed, $failed failed, $((ran - passed)) still owed"
  echo "look debts untouched: $($0 count | sed 's/.*, //')"
  [ "$failed" -eq 0 ]
}

cmd_help() { sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'; }

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-list}" in
    add)   shift; cmd_add "$@" ;;
    list)  shift; cmd_list "$@" ;;
    show)  shift; cmd_show "$@" ;;
    count) shift; cmd_count "$@" ;;
    clear) shift; cmd_clear "$@" ;;
    drain) shift; cmd_drain "$@" ;;
    -h|--help|help) cmd_help ;;
    *) _die "unknown command '${1:-}'. Try: $0 help" 2 ;;
  esac
fi
