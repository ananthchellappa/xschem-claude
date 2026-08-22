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
# There are THREE lists. Two of them are the USER'S QUEUE and one is not, and no
# code path converts any into another:
#
#            rule debt              look debt              suite debt
#   pays     the USER               the USER               a script
#   asks for a ruling, in words     a judgment, on pixels  a :0 run
#   verdict  a decision             judgment               PASS/FAIL
#   clears   ONLY `clear rule <id>` ONLY `clear look <id>` itself, on a pass
#
# `drain` reads the SUITE list and nothing else -- it does not so much as open
# the other two. A ledger that cleared an eyeball because a suite went green
# would be precisely the defect the eyeball rule was written about, and a ledger
# that closed a RULING that way would be the same defect wearing a tie.
#
# WHY `rule` WAS ADDED (2026-08-22, at the user's instruction)
#
# The E questions a driver run emits -- "ratify this user-visible change, or
# revert it" -- are owed by the user exactly as a look is, and were living in a
# markdown table in doc/claude/ledger/ purely because that is where the run's
# own table happened to be. Two queues in two files, both waiting on one person,
# who then has to know which file each lives in. Worse, the split does not even
# cut cleanly: four of the nine open rulings on the OP-annotation branch (0457,
# 0458, 0468, 0475) cannot be decided WITHOUT looking at pixels. So a rule entry
# can carry the `eyes` tag, and `list`/`show` say so.
#
# A rule entry is a POINTER, not a copy. The question's option set (a/b/c), its
# measurements and its history stay in doc/claude/issues/NNNN-*.md, which `add`
# resolves automatically from the id and records as `ref:`. Flattening a
# three-option ruling into one ledger line is how the options get lost.
#
# Spec: doc/claude/specs/owed.md
#
# USAGE
#   owed.sh add rule  <id> [why] [--eyes] [--ref <path>]
#   owed.sh add look  <what> [why]      owed.sh list [rule|look|suite]
#   owed.sh add suite <name> [why]      owed.sh show
#   owed.sh drain [--display :0]        owed.sh clear <rule|look|suite> <id>
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
    rule|suite|look) _dir "$1" ;;
    *) return 2 ;;
  esac
}
_bad_kind() { _die "unknown kind '$1' -- expected 'rule', 'look' or 'suite'" 2; }

# The order the two READING commands walk the lists: the user's own queue
# first, the self-clearing one last. `count` prints them in this order too, so
# a caller can never pick the wrong field by position.
KINDS="rule look suite"

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

# OPTIONAL FIELDS live on lines 2+ as `key:value`, NOT as extra tab-separated
# columns on line 1. _read_entry splits line 1 on tabs and hands everything
# after the second tab to `reason`, so a fourth column would silently appear
# glued to the end of every reason string in every existing reader. Line 1 is
# frozen; growth happens downward.
_entry_field() {  # $1 path, $2 key -> prints value, empty if absent
  sed -n "2,\$ s/^$2://p" "$1" 2>/dev/null | head -1
}

# doc/claude/issues/NNNN-*.md for a bare issue id, so a rule debt points at the
# file holding its option set instead of trying to restate it. Silent when it
# resolves to nothing: an id with no issue file yet is a normal early state, and
# an invented path would be worse than none.
_issue_ref() {  # $1 id -> prints repo-relative path, or nothing
  local n="$1" root f
  case "$n" in [0-9][0-9][0-9][0-9]) ;; *) return 0 ;; esac
  root=$(cd "$HERE/../.." 2>/dev/null && pwd) || return 0
  for f in "$root/doc/claude/issues/$n"-*.md; do
    [ -e "$f" ] || return 0
    printf '%s' "${f#$root/}"
    return 0
  done
}

# ---------------------------------------------------------------------------
cmd_add() {
  local kind="" subject="" why="" eyes=0 ref="" positional=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --eyes) eyes=1 ;;
      --ref)  shift; ref="${1:-}"; [ -n "$ref" ] || _die "--ref needs a value" 2 ;;
      --*)    _die "unknown option '$1'" 2 ;;
      *)      positional=$((positional + 1))
              case "$positional" in
                1) kind="$1" ;;
                2) subject="$1" ;;
                3) why="$1" ;;
                *) _die "too many arguments -- quote the reason as ONE word" 2 ;;
              esac ;;
    esac
    shift
  done
  [ -n "$kind" ] && [ -n "$subject" ] \
    || _die "usage: $0 add <rule|look|suite> <what> [why] [--eyes] [--ref <path>]" 2
  local d; d=$(_kind_dir "$kind") || _bad_kind "$kind"
  [ "$eyes" = 1 ] && [ "$kind" != rule ] \
    && _die "--eyes is a RULE tag: a look debt already needs eyes, and a suite debt never does" 2
  mkdir -p "$d" || _die "cannot create $d" 3

  local id
  case "$kind" in
    suite)
      # DEDUPED by name: the same suite owing a :0 run twice is one debt, and
      # the newer reason is the informative one.
      id=$(_slug "$subject")
      ;;
    rule)
      # DEDUPED by id, for the same reason and a stronger one: a ruling IS its
      # issue number. Re-adding 0444 is a re-statement of one open question, not
      # a second question, and two 0444 entries would let the user answer one
      # and still see the other standing.
      id=$(_slug "$subject")
      [ -n "$ref" ] || ref=$(_issue_ref "$subject")
      ;;
    look)
      # NEVER deduped. Two different things can carry the same description
      # ("the marker callout"), and merging them would silently drop one -- the
      # exact class of loss this ledger exists to prevent. Unique id per add.
      id="$(_slug "$subject").$(date +%s).$$"
      ;;
  esac
  printf '%s\t%s\t%s\n' "$(date +%s)" "$subject" "$why" > "$d/$id"
  [ "$eyes" = 1 ] && printf 'eyes:1\n' >> "$d/$id"
  [ -n "$ref" ]   && printf 'ref:%s\n' "$ref" >> "$d/$id"
  _say "recorded $kind debt: $subject"
  return 0
}

cmd_list() {
  local want="${1:-}"
  case "$want" in ''|rule|suite|look) ;; *) _die "unknown kind '$want'" 2 ;; esac
  local total=0 k d f line epoch subject reason tag ref
  for k in $KINDS; do
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
          rule)  echo "RULE debts — need YOUR ruling; cleared only by 'owed.sh clear rule <id>'" ;;
          look)  echo "LOOK debts — need YOUR eyes; cleared only by 'owed.sh clear look <id>'" ;;
          suite) echo "SUITE debts — a :0 run each; cleared automatically when one passes" ;;
        esac
      fi
      n=$((n + 1)); total=$((total + 1))
      epoch=${line%%	*}; line=${line#*	}
      subject=${line%%	*}; reason=${line#*	}
      tag=""
      [ "$(_entry_field "$f" eyes)" = 1 ] && tag=" [needs eyes]"
      printf '  [%s] %-34s %3sd  %s%s\n' "$(basename "$f")" "$subject" "$(_age_days "$epoch")" "$reason" "$tag"
      ref=$(_entry_field "$f" ref)
      [ -n "$ref" ] && printf '  %-37s      read: %s\n' "" "$ref"
    done
    [ "$n" -gt 0 ] && echo
  done
  [ "$total" -eq 0 ] && echo "nothing owed."
  return 0
}

_count_kind() { ls -1 "$(_dir "$1")" 2>/dev/null | wc -l | tr -d ' '; }

# Prints in $KINDS order, and every consumer must SELECT BY NAME. The previous
# consumer was `count | sed 's/.*, //'` inside drain, meaning "the last field
# is the look count" -- true only while there were exactly two fields, and
# silently reporting the RULE count the moment a third arrived.
cmd_count() {
  local k out=""
  for k in $KINDS; do
    [ -n "$out" ] && out="$out, "
    out="$out$(_count_kind "$k") $k"
  done
  echo "$out"
}

# `show` is the USER'S QUEUE, read aloud: rule debts and look debts together,
# because from where the user sits they are one queue -- both are owed by them,
# both are cleared only by them, and four of the OP-annotation rulings need a
# look before they can be ruled on anyway. Suite debts stay out: nobody needs to
# be told about work a script will do.
cmd_show() {
  local k d f line epoch subject reason n=0 ref
  for k in rule look; do
    d=$(_dir "$k")
    for f in "$d"/*; do
      [ -e "$f" ] || continue
      line=$(_read_entry "$f") || { _warn "skipping unreadable entry $f"; continue; }
      if [ "$n" -eq 0 ]; then
        echo "These need a HUMAN. No suite can discharge them — that is the point:"
        echo "a green suite is a precondition for asking you, never an answer."
        echo
      fi
      n=$((n + 1))
      epoch=${line%%	*}; line=${line#*	}
      subject=${line%%	*}; reason=${line#*	}
      if [ "$k" = rule ] && [ "$(_entry_field "$f" eyes)" = 1 ]; then
        printf '  %s   (a RULING — and one you must LOOK to make)\n' "$subject"
      elif [ "$k" = rule ]; then
        printf '  %s   (a RULING)\n' "$subject"
      else
        printf '  %s\n' "$subject"
      fi
      [ -n "$reason" ] && printf '      why: %s\n' "$reason"
      ref=$(_entry_field "$f" ref)
      [ -n "$ref" ] && printf '      the options are in: %s\n' "$ref"
      printf '      waiting %s day(s)   clear with: %s clear %s %s\n\n' \
             "$(_age_days "$epoch")" "$0" "$k" "$(basename "$f")"
    done
  done
  if [ "$n" -eq 0 ]; then
    echo "nothing owed by you."
    return 0
  fi
  echo "To serve the looks: tests/headless/devdisplay.sh view   (a VNC window onto"
  echo "the test display — your attention is what is scarce here, not the screen),"
  echo "or DISPLAY=:0 if the point IS how WSLg itself renders it."
}

cmd_clear() {
  local kind="${1:-}" id="${2:-}"
  [ -n "$kind" ] && [ -n "$id" ] || _die "usage: $0 clear <suite|look> <id>" 2
  local d; d=$(_kind_dir "$kind") || _bad_kind "$kind"
  [ -e "$d/$id" ] || _die "no $kind debt with id '$id' (see: $0 list)" 4
  rm -f "$d/$id"
  _say "cleared $kind debt $id"
}

# Resolve a queued suite NAME to the file that runs it.
#
# ⚠ A SUITE IS NOT ALWAYS A .tcl. tests/headless holds both kinds -- 200-odd
# `test_*.tcl` driven through the xschem binary, and a dozen standalone
# `test_*.sh` (the gate's own self-tests, the dev-display one, the action-log
# ones) that are plain shell and are not runnable by run_suites.sh at all.
# drain used to hand every name straight to run_suites.sh, whose resolver only
# knows `<name>.tcl` (run_suites.sh:82-88), so a shell-script suite debt failed
# with
#     FATAL: no such test file: tests/headless/test_gui_gate_batch.tcl
# on EVERY drain, was recorded as failed, was therefore kept (R303), and so
# could never be paid -- an entry the ledger could only accumulate. Measured
# 2026-08-15 on the real `test_gui_gate_batch` debt.
#
# Prints "<kind>\t<path>" (kind = tcl | sh) and returns 0 when it resolves.
#
# ⚠ ON FAILURE IT PRINTS "none\t<the candidates it REALLY stat'd>" and returns
# 1, and the caller must print THAT rather than composing its own guess. It did
# compose its own: `$HERE/<name>.tcl nor $HERE/<name>.sh`, unconditionally. For
# a name that is already a path or already carries an extension — the two arms
# that stat exactly ONE file — the warning then named two paths nobody had
# looked for, with the directory or the extension doubled:
#     add suite tests/headless/test_nope.tcl
#     -> "neither …/tests/headless/tests/headless/test_nope.tcl.tcl nor …"
# R309 says the message names the paths it looked for; a fabricated pair sends
# the reader to check files that were never in question.
_suite_file() {  # $1 name -> prints "<kind>\t<path>", or "none\t<candidates>"
  local n="$1"
  case "$n" in
    */*)   if [ -f "$n" ]; then
             case "$n" in *.sh) printf 'sh\t%s' "$n" ;; *) printf 'tcl\t%s' "$n" ;; esac
             return 0
           fi
           printf 'none\t%s' "$n"; return 1 ;;
    *.tcl) [ -f "$HERE/$n" ] && { printf 'tcl\t%s' "$HERE/$n"; return 0; }
           printf 'none\t%s' "$HERE/$n"; return 1 ;;
    *.sh)  [ -f "$HERE/$n" ] && { printf 'sh\t%s'  "$HERE/$n"; return 0; }
           printf 'none\t%s' "$HERE/$n"; return 1 ;;
  esac
  [ -f "$HERE/$n.tcl" ] && { printf 'tcl\t%s' "$HERE/$n.tcl"; return 0; }
  [ -f "$HERE/$n.sh"  ] && { printf 'sh\t%s'  "$HERE/$n.sh";  return 0; }
  printf 'none\t%s and %s' "$HERE/$n.tcl" "$HERE/$n.sh"
  return 1
}

# Run every queued SUITE debt in one batch on the real display.
#
# A .tcl suite deliberately goes through run_suites.sh rather than the binary:
# that is what enrols the run in the gate, so the user keeps Pause and Stop over
# a batch they approved once with "Forever".
#
# A .sh suite is executed directly, because there is nothing else that could run
# it: run_suites.sh drives `xschem --script`, which cannot source a shell
# script. Such a suite owns its own display arm (test_gui_gate_batch.sh re-execs
# itself onto a private Xvfb when it finds the dev display, precisely because
# the gate is disabled there), so it is handed the display in both spellings --
# DISPLAY, which it reads, and AUDIT_DISPLAY, which the arm-aware ones read --
# and is NOT wrapped in the gate: a self-test OF the gate must not run inside
# one. Its exit status is its verdict, which is the contract every test_*.sh in
# this tree already keeps (`exit 1` on any FAIL).
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
    echo "(rule and look debts are untouched by drain, by design: $0 show)"
    return 0
  fi

  _say "draining ${#names[@]} suite debt(s) on $display"
  _say "the gate is live on a real display -- Pause and Stop still work"

  local ran=0 passed=0 failed=0 i res kind path rc now cand
  for i in "${!names[@]}"; do
    ran=$((ran + 1))
    echo "== [$ran/${#names[@]}] ${names[$i]}"

    # ⚠ RESOLVE BEFORE RUNNING, and say both candidates when it fails. An
    # unresolvable name is a MISNAMED DEBT, not a red suite, and reporting it as
    # "FAILED on :0" (which is what delegating blindly to run_suites.sh did)
    # sends the reader looking for a regression that does not exist. The debt is
    # still KEPT -- only the user knows what they meant to write.
    if ! res=$(_suite_file "${names[$i]}"); then
      failed=$((failed + 1))
      now=$(date +%s)
      cand=${res#*	}
      printf '%s\t%s\t%s\n' "$now" "${names[$i]}" \
             "NO SUCH SUITE FILE -- looked for $cand" \
             > "$d/${ids[$i]}"
      _warn "no such suite '${names[$i]}': looked for $cand -- no such file"
      echo "   UNRESOLVED -> debt KEPT (fix the name, or: $0 clear suite ${ids[$i]})"
      continue
    fi
    kind=${res%%	*}; path=${res#*	}

    if [ "$kind" = "sh" ]; then
      echo "   (shell suite: $path -- run directly, it owns its own display arm)"
      AUDIT_DISPLAY="$display" DISPLAY="$display" bash "$path"; rc=$?
    else
      AUDIT_DISPLAY="$display" "$HERE/run_suites.sh" "${names[$i]}"; rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
      passed=$((passed + 1))
      rm -f "$d/${ids[$i]}"
      echo "   PASS -> debt cleared"
    else
      failed=$((failed + 1))
      # A failure must NOT clear the debt. A drain that loses work when a suite
      # goes red is a way to forget things, not a way to remember them.
      now=$(date +%s)
      printf '%s\t%s\t%s\n' "$now" "${names[$i]}" \
             "FAILED on $display (rc=$rc) -- still owed" > "$d/${ids[$i]}"
      echo "   FAIL -> debt KEPT"
    fi
  done

  echo
  echo "drained: $ran run, $passed passed, $failed failed, $((ran - passed)) still owed"
  # BY NAME, not by position -- see cmd_count. And BOTH user-owed lists are
  # named: an unmentioned list is one a reader can believe was drained.
  echo "look debts untouched: $(_count_kind look)"
  echo "rule debts untouched: $(_count_kind rule)"
  [ "$failed" -eq 0 ]
}

# The comment block this prints now runs past line 45 (the `rule` rationale),
# so the window is found rather than hard-coded: from line 2 to the last line
# that still begins with `#`.
cmd_help() {
  local last
  last=$(awk 'NR>1 && !/^#/ {print NR-1; exit}' "$0")
  sed -n "2,${last}p" "$0" | sed 's/^# \{0,1\}//'
}

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
