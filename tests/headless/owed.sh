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
# WHICH CLONE FILED IT (2026-09-10, issue 1400)
#
# The state dir is under $HOME, so one ledger serves the main session and every
# worktree -- and every other CLONE of this repo too, which $HOME cannot tell
# apart from a worktree. Two clones here each read their own tracked
# doc/claude/issues/NUMBERING.md, each found 1333-1348 free, and each filed into
# it: a rule id became a 4-digit number with two unrelated meanings. Both
# writing paths then destroyed the other tree's entry in silence -- `clear`
# rm'd by exact filename, `add` truncated with a bare `>` and printed
# "recorded". A ruling clears only when the USER says so; a second checkout
# could close one without anybody typing the word.
#
# ⚠ THE SIZE OF THAT COLLISION IS NOT A STANDING FACT, SO NO BARE COUNT IS
# WRITTEN HERE. At 08:25 on 2026-09-10 it was seven numbers; by 10:45 the same
# day it was TWELVE, the other clone having filed 1349-1353 while this very
# change was being written, and its own next-free pointer read 1354 -- every one
# of those already a committed issue file on this branch. It was still growing
# when this comment was written. Any number quoted for it needs the date and the
# time beside it or it will read as settled when it is not.
#
# So an entry records the clone that filed it, and a command that would write
# another clone's entry REFUSES (exit 5), printing what is standing there and
# what to type instead. `--repo <clone>` is the deliberate override, on `add` as
# much as on `clear`. Mechanism and what was measured: see _origin_init below.
#
# ⚠ THE PROTECTION IS ONE-SIDED, AND THE SIDE IT DOES NOT COVER IS THE ONE THAT
#   HAS ALREADY DESTROYED A RULING. Everything above is THIS script refusing to
#   write another clone's entry. The other checkout runs its OWN copy of this
#   file -- the 2026-09-04 one, 459 lines, no `_origin`, no refusal, no
#   `cleared.log` -- and measured on 2026-09-10 against a stamped copy of the
#   live ledger it still truncates any entry at exit 0 printing `recorded`,
#   erasing `repo:`, `repo_via:` and `ref:` with it, and its `drain` still
#   clears this clone's suite debts on its own copies of this clone's suites.
#   Stamping every entry did NOT narrow that by one byte. Do not read a green
#   refusal here as a guarantee: it is half a door. The other half is one `cp`
#   of this file into that tree, which this batch was forbidden to make.
#
# Spec: doc/claude/specs/owed.md
#
# USAGE
#   owed.sh add rule  <id> [why] [--eyes|--no-eyes] [--ref <path>] [--repo <clone>]
#   owed.sh add look  <what> [why]      owed.sh list [rule|look|suite]
#   owed.sh add suite <name> [why]      owed.sh show
#   owed.sh drain [--display :0]        owed.sh clear <rule|look|suite> <id> [--repo <clone>]
#   owed.sh count                       owed.sh restamp --from <clone> [--to here] [--dry-run]
#
#   XSCHEM_OWED_DIR   state dir, default $HOME/.claude/xschem_owed
#   --repo <clone>    a clone PATH, `here` for THIS clone, or a basename the
#                     ledger already knows. Needed only when an id is contested
#                     between two CLONES. Matched EXACTLY -- an unknown basename,
#                     or one two clones share, is an error, not a guess.
#   --no-eyes         drop the `eyes` tag an existing entry carries. An update
#                     KEEPS it otherwise: dropping a ruling the user cannot make
#                     without looking, silently, is a downgrade of the debt.
#   restamp           re-point entries after a clone MOVED or was RENAMED. The
#                     stamp is an absolute path, so a move orphans every entry
#                     that clone filed -- see cmd_restamp.
#   exit 2            usage -- including an id that is a path (ids are filenames)
#   exit 3            state dir unusable, or the pre-image could not be recorded
#                     (nothing is destroyed without one)
#   exit 5            REFUSED: that entry belongs to another clone, or it carries
#                     no stamp in a ledger where everything else does.

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

# AN ID IS A FILENAME, NEVER A PATH (R611). `clear` takes its id straight from
# the command line and uses it as one -- `$d/$id` -- so, measured 2026-09-10
# against a cp -a copy of the live ledger:
#     clear rule ../cleared.log     -> exit 0, the PRE-IMAGE LOG deleted
#     clear rule ../../victim.txt   -> exit 0, a file outside the state dir gone
# Both printed `owed: cleared rule debt <x>` and neither wrote a pre-image,
# which is R502 broken in the destroying direction. The traversal is INHERITED
# from the pre-stamp script; what the stamping work added was a target worth
# hitting -- `cleared.log` sits one `../` from every kind dir, and taking it
# destroys the pre-image of the very clear that took it (in the measurement the
# next destroy then failed with exit 3, because the log it needed was gone).
# `add` was never exposed -- _slug maps `/` to `_` -- and cmd_add asserts anyway,
# so an edit that drops the slug is caught here rather than in the filesystem.
# No legitimate id has ever contained a slash: an id is _slug output
# (`A-Za-z0-9._-`) plus, at most, the `@<tag>` namespacing suffix.
_check_id() {  # $1 kind, $2 id -- exits 2 unless the id is a bare filename
  case "$2" in
    */*)  _die "a $1 id is a FILENAME, not a path: '$2' contains '/', which would reach outside the $1 list" 2 ;;
    .|..) _die "a $1 id is a FILENAME, not a path: '$2' names a directory" 2 ;;
  esac
}

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

# ---------------------------------------------------------------------------
# WHAT NAMES A CLONE
#
# `git rev-parse --path-format=absolute --git-common-dir`, run against THIS
# SCRIPT's directory -- the clone that owns this owed.sh is the clone doing the
# writing, whatever the caller's cwd happens to be.
#   * distinct per clone;
#   * the SAME for every worktree of one clone -- --git-common-dir, not
#     --git-dir -- which is the property the shared ledger rests on;
#   * survives a branch switch and a `git remote set-url`.
#
# MEASURED AND REJECTED 2026-09-10: the remote URL (both clones on this machine
# point at the same GitHub repo) and the root commit (identical in both).
# Neither can name a clone, so neither is an origin.
#
# --path-format wants git >= 2.31; git here is 2.53.0. When git is missing or
# the call fails, the fallback is this checkout's root by path, and `repo_via:`
# records which of the two answered -- a path-derived id and a git-derived id
# are not interchangeable evidence.
# ---------------------------------------------------------------------------
_ORIGIN=""
_ORIGIN_VIA=""
_origin_init() {
  [ -n "$_ORIGIN" ] && return 0
  local raw=""
  # GIT_DIR / GIT_WORK_TREE are dropped: inside a git hook they name whatever
  # repo invoked the hook, which is exactly the wrong answer here.
  raw=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR \
        git -C "$HERE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || raw=""
  if [ -n "$raw" ]; then
    _ORIGIN_VIA=git
    # .../<clone>/.git -> .../<clone>. Not cosmetic: it makes the git answer and
    # the path fallback name the SAME clone, so a tree that loses git -- or one
    # whose git is too old for --path-format -- does not turn every one of its
    # own entries foreign in a single step.
    case "$raw" in */.git) raw=${raw%/.git} ;; esac
  else
    _ORIGIN_VIA=path
    raw=$(cd "$HERE/../.." 2>/dev/null && pwd -P) || raw=""
    [ -n "$raw" ] || raw="$HERE"
    # A LINKED WORKTREE's `.git` is a FILE, `gitdir: <clone>/.git/worktrees/<n>`,
    # so the checkout root by path names the WORKTREE while git names the CLONE.
    # Without this, a worktree that loses git turns every one of its own entries
    # foreign -- the same one-step break the /.git strip exists to prevent for a
    # main worktree, and the case that claim originally missed. Absolute gitdir
    # only: a relative one cannot be an id, and a submodule's
    # `.git/modules/<n>` deliberately does not match.
    if [ -f "$raw/.git" ]; then
      local gd; gd=$(sed -n 's/^gitdir: *//p' "$raw/.git" 2>/dev/null | head -1)
      case "$gd" in /*/.git/worktrees/*) raw=${gd%%/.git/worktrees/*} ;; esac
    fi
  fi
  _ORIGIN="$raw"
}
_origin()     { _origin_init; printf '%s' "$_ORIGIN"; }
_origin_via() { _origin_init; printf '%s' "$_ORIGIN_VIA"; }

# A clone's TAG is the basename of its id: short enough to type after --repo and
# to put in a filename. It is a CONVENIENCE, never the truth -- two clones whose
# directory names match share a tag, and that is the ORDINARY shape (clone this
# repo twice under its own name). So NO OWNERSHIP DECISION EVER COMPARES TAGS.
# Every one of them compares the FULL id, exactly. A --repo the human typed is
# allowed to NAME a clone by tag, but the tag is turned into a full id here, at
# resolve time, by asking the ledger -- and if the ledger cannot answer, or
# answers with more than one clone, the command dies rather than guessing.
#
# It used to compare tags in three places (add's ownership test, add's
# namespacing test, clear's --repo test). Measured 2026-09-10 in a fixture whose
# two clones were both named `xschem`: a plain, no-flag `add rule 1344` from the
# second clone REPLACED the first clone's unanswered ruling at exit 0 and left
# the first clone's stamp on it -- verbatim the defect this file exists to stop.
_NL='
'
_repo_tag()  { _slug "${1##*/}"; }
_repo_resolve() {  # $1 --repo argument -> prints the full clone id
  #   rc 0  resolved (prints the id)
  #   rc 2  a bare tag no stamp in the ledger answers to (prints nothing)
  #   rc 3  a bare tag MORE THAN ONE clone answers to (prints the candidates)
  local r hits tag
  case "$1" in
    here|HERE|.) _origin; return 0 ;;
    */*)         r="${1%/}"; printf '%s' "${r%/.git}"; return 0 ;;
  esac
  # A bare TAG is resolved back to the full id by asking the ledger, because a
  # tag stamped verbatim would be a THIRD name for a clone that already has two
  # (its path, and the tag of that path) -- and the clone it names would then
  # read its OWN entry as foreign, which is the refusal firing on the one person
  # entitled to write. It used to be stamped verbatim when the ledger did not
  # know it, which is exactly how that happened; it now fails instead.
  tag=$(printf '%s' "$1" | sed 's/[.[\*^$/]/\\&/g')
  hits=$(sed -n "s|^repo:\(.*/$tag\)\$|\1|p" "$OWED_DIR"/*/* 2>/dev/null | sort -u)
  case "$hits" in
    '')  return 2 ;;
    *"$_NL"*) printf '%s' "$hits"; return 3 ;;
  esac
  printf '%s' "$hits"
}
# The shortest --repo argument that really reaches a given clone: its tag when
# the tag is unambiguous, its full path when it is not. A refusal is the ONE
# place the override is spelled out (`show` no longer prints it at all), so the
# command it prints has to be one that works: with two clones sharing a
# basename, `--repo <tag>` is now a hard error, and a refusal that suggested it
# would send the reader from one refusal straight into another.
_repo_hint() {  # $1 full clone id -> a --repo argument for it
  local t o
  t=$(_repo_tag "$1")
  o=$(_repo_resolve "$t") && [ "$o" = "$1" ] && { printf '%s' "$t"; return 0; }
  printf '%s' "$1"
}

# NOT called inside $( ): _die's `exit` would end only the subshell (see
# _kind_dir). Sets _REPO_RESOLVED in the caller's shell instead.
_REPO_RESOLVED=""
_repo_arg() {  # $1 argument, $2 the flag it came from -> sets _REPO_RESOLVED, or dies
  local out rc flag="${2:---repo}"
  out=$(_repo_resolve "$1"); rc=$?
  case "$rc" in
    0) _REPO_RESOLVED="$out" ;;
    2) _die "$flag '$1': no entry in the ledger is stamped to a clone by that name. Give the clone's PATH, or 'here' for this one." 2 ;;
    *) _die "$flag '$1': more than one clone answers to that name -- $(printf '%s' "$out" | tr '\n' ' '). Give the clone's PATH." 2 ;;
  esac
}

_entry_repo()    { _entry_field "$1" repo; }
_entry_is_mine() { [ "$(_entry_repo "$1")" = "$_ORIGIN" ]; }
_stamp_as()      { printf 'repo:%s\nrepo_via:%s\n' "$2" "$3" >> "$1"; }

# ---------------------------------------------------------------------------
# WHAT AN ENTRY WITH NO `repo:` MEANS -- AND IT CHANGED MEANING ON 2026-09-10
#
# It used to mean one thing: LEGACY, filed before stamps existed. Every entry
# then standing was one, so `add` and `clear` proceeded on it, warned once, and
# CLAIMED it for whoever touched it. That was right, and the compatibility
# contract it protects is real: every `clear rule <id>` quoted in a receipt has
# to keep working, and breaking that would cost the user the very queue this
# file exists to protect.
#
# Then the whole ledger was backfilled -- 196 of 196 entries stamped, counted
# with `/usr/bin/grep -rl '^repo:'` at 12:43:56 -0700 on 2026-09-10 (any count
# here is a timestamp, not a standing fact; another clone writes this
# directory). In a ledger like that an unstamped entry can no longer be legacy.
# It can only have been written by something that does not stamp -- i.e. the
# other clone's older owed.sh, which overwrites with NO pre-image. So the
# absence of a stamp stopped being history and became EVIDENCE OF A DESTROY,
# and claiming on the strength of it would be a false statement about someone
# else's text that also erases the one signal the destroy left behind.
# Measured, before this change, on a stamped copy of the live ledger:
#     (their 2026-09-04 script)  add rule 1354 "their unanswered ruling"
#        -> `recorded`, exit 0; this clone's 1354 entry, its ref: and both
#           stamp lines gone; no cleared.log
#     (this clone)               add rule 1354 "our unrelated ruling"
#        -> `predates origin stamps -- claiming it for xschem-claude`, exit 0,
#           and the result carried OUR stamp and OUR ref over THEIR words.
#
# The reading is therefore evidence-based rather than assumed, and it has to be
# right in BOTH worlds, because other checkouts of this repo exist and their
# ledgers have never been backfilled:
#
#   FOREIGN -- BOTH of: stamped entries are the MAJORITY of this ledger, and
#              this entry was written AFTER the oldest stamped one. Such an
#              entry cannot predate stamping here, so something that does not
#              stamp wrote it after stamping was already in use.
#   LEGACY  -- anything else, and the behaviour is exactly what it was, wording
#              included, so a ledger that was never backfilled notices nothing.
#
# WHY TWO CONDITIONS, AND WHY NOT "NEWER THAN THE NEWEST STAMP". That was the
# first rule written here and it was measured wrong the same hour: this clone's
# own next `add` raises the newest stamp above the foreign write, and every
# older anomaly silently falls back to LEGACY and gets claimed. The two the code
# uses instead do not move when this clone writes: the majority test says the
# ledger has been stamped rather than merely touched, and the oldest-stamp test
# is what tells a genuine legacy entry (older than any stamp) from a write that
# arrived after stamping. Line 1's epoch is written by whichever `add` created
# the entry, so both comparisons are between writes into this one directory.
#
# THE VERDICT LEANS TOWARD FOREIGN ON PURPOSE. Calling a legacy entry foreign
# costs a refusal with a documented escape, a loud warning, and a drain that
# leaves a debt standing. Calling a foreign write legacy costs a false claim
# and erases the only evidence of a destroy -- which is the defect this exists
# to stop. What each command does with the verdict is at its own call site:
# `add` refuses (an automatic write must not paper over a destroy), `clear`
# proceeds with a loud warning (only the user clears, and a refusal there locks
# them out of their own queue), `drain` skips, `list`/`show` mark it.
# ---------------------------------------------------------------------------
_LEDGER_SCANNED=0
_LEDGER_TOTAL=0
_LEDGER_STAMPED=0
_LEDGER_FIRST=0    # epoch of the OLDEST stamped entry; 0 when there are none
_ledger_scan() {
  [ "$_LEDGER_SCANNED" = 1 ] && return 0
  _LEDGER_SCANNED=1
  local -a files=()
  local k f out
  for k in $KINDS; do
    for f in "$(_dir "$k")"/*; do [ -f "$f" ] && files+=("$f"); done
  done
  [ "${#files[@]}" -eq 0 ] && return 0
  # ONE awk over the ledger, not a fork per entry. It runs only when an
  # unstamped entry is actually met -- but that is the moment a destroy is being
  # decided, which is the moment worth spending a fork on.
  out=$(awk '
    function flush() { if (!seen) return; t++
                       if (st) { s++; if (first == 0 || ep < first) first = ep } }
    FNR==1 { flush(); seen=1; ep=$1+0; st=0; next }
    /^repo:/ { st=1 }
    END { flush(); printf "%d %d %d", t+0, s+0, first+0 }
  ' "${files[@]}" 2>/dev/null) || out=""
  case "$out" in
    [0-9]*\ [0-9]*\ [0-9]*)
      _LEDGER_TOTAL=${out%% *}; out=${out#* }
      _LEDGER_STAMPED=${out%% *}; _LEDGER_FIRST=${out##* } ;;
  esac
  return 0
}

_UV=""; _UV_WHY=""
_unstamped_verdict() {  # $1 path -- sets _UV to legacy|foreign, _UV_WHY to why
  _ledger_scan
  local ep unstamped
  ep=$(head -1 "$1" 2>/dev/null | cut -f1)
  case "$ep" in ''|*[!0-9]*) ep=0 ;; esac
  unstamped=$((_LEDGER_TOTAL - _LEDGER_STAMPED))
  _UV=legacy; _UV_WHY=""
  if [ "$_LEDGER_STAMPED" -gt "$unstamped" ] && [ "$ep" -gt "$_LEDGER_FIRST" ]; then
    _UV=foreign
    _UV_WHY="$_LEDGER_STAMPED of $_LEDGER_TOTAL entries here carry a clone stamp, this one does not, and it was written $(date -d "@$ep" '+%F %T' 2>/dev/null || echo "at epoch $ep") -- AFTER the oldest stamped entry ($(date -d "@$_LEDGER_FIRST" '+%F' 2>/dev/null || echo "epoch $_LEDGER_FIRST")), so it cannot predate stamping here (counted $(date '+%F %T %z'))"
  fi
  return 0
}

# Used by `drain` only, and only on the LEGACY verdict: an entry older than
# every stamp in a ledger that has some, or one in a ledger that has none. The
# wording is the pre-2026-09-10 wording on purpose -- on that verdict it is
# still true, and a ledger that was never backfilled must not notice this
# change at all.
_claim() {  # $1 path, $2 kind, $3 id -- warn once, attributed from here on
  _warn "$2 '$3' predates origin stamps -- claiming it for $(_repo_tag "$_ORIGIN")"
  _stamp_as "$1" "$_ORIGIN" "$_ORIGIN_VIA"
}

# The pre-image of anything this ledger destroys, appended INSIDE the state dir
# (R502) and never rotated. `clear` is an rm and `add` is an overwrite; the only
# reason the 2026-09-10 collision could be reconstructed at all is that a tool
# result happened to persist, which is luck, not a ledger. Body lines are
# prefixed `| ` so the log is self-delimiting, and it sits in the state dir ROOT,
# where nothing globs: cmd_list and _count_kind walk the KIND dirs only.
#
# ⚠ IT RETURNS NON-ZERO WHEN THE APPEND FAILS, AND EVERY CALLER THEN REFUSES TO
# DESTROY. A pre-image that can silently not happen is the luck this exists to
# replace, so an unwritable state dir stops the rm, it does not narrate it.
# stderr is redirected BEFORE the append, or the shell's own "Permission denied"
# for the failing redirect leaks out ahead of the warning.
_log_gone() {  # $1 event, $2 kind, $3 id, $4 path
  local log="$OWED_DIR/cleared.log"
  { printf '=== %s\t%s\t%s\t%s\tby %s\n' "$(date +%s)" "$1" "$2" "$3" "$_ORIGIN"
    sed 's/^/| /' "$4" 2>/dev/null
  } 2>/dev/null >> "$log" && return 0
  _warn "could not append the pre-image to $log"
  return 3
}

# Rewrite LINE 1 and KEEP EVERYTHING BELOW IT. Both of drain's rewrite arms used
# a bare `>`, which erased the origin stamp, the ref, and any verdict a human had
# written on the entry -- and it did that exactly where debts live longest, since
# only a FAILED or an UNRESOLVED debt is ever rewritten. The temp file sits in
# the state dir ROOT, not in the kind dir, because cmd_list globs the kind dir.
_rewrite_line1() {  # $1 path, $2 epoch, $3 subject, $4 reason
  local tmp="$OWED_DIR/.rewrite.$$"
  { printf '%s\t%s\t%s\n' "$2" "$3" "$4"; tail -n +2 "$1" 2>/dev/null; } > "$tmp" \
    && mv -f "$tmp" "$1"
}

# ONE read per entry instead of a sed per field. cmd_list and cmd_show want
# three optional fields on EVERY entry, and the live ledger runs to hundreds of
# them -- three sed subshells each is three forks per entry for one `list`, and
# `list` is the command typed most. (No bare number is written here on purpose:
# this comment carried a frozen `192` that was 194, then 196, inside one day.
# Measured 2026-09-10 12:43:56 -0700 with `find ~/.claude/xschem_owed -mindepth
# 2 -type f | wc -l`: 196 -- 134 rule, 53 look, 9 suite. Another clone writes
# this directory, so that is a timestamp, not a constant.) The loop below reads
# the file in the CURRENT shell (a redirect, not a pipe), so it forks nothing.
# `repo_via:` does not match `repo:*`: the colon has to come straight after the
# key.
_OPT_EYES=""; _OPT_REF=""; _OPT_REPO=""
_read_opts() {  # $1 path -> sets _OPT_EYES _OPT_REF _OPT_REPO
  _OPT_EYES=""; _OPT_REF=""; _OPT_REPO=""
  # `|| [ -n "$l" ]` catches a FINAL LINE WITH NO NEWLINE, which a bare
  # `read` drops. _entry_field uses sed, which does not drop it, so without this
  # `list`/`show` and `add`/`clear`/`clear --repo` disagreed about the very
  # field that decides ownership: a hand-edited entry whose `repo:` was its last
  # line listed as this clone's and refused as another clone's.
  local l
  while IFS= read -r l || [ -n "$l" ]; do
    case "$l" in
      eyes:*) [ -n "$_OPT_EYES" ] || _OPT_EYES=${l#eyes:} ;;
      ref:*)  [ -n "$_OPT_REF" ]  || _OPT_REF=${l#ref:} ;;
      repo:*) [ -n "$_OPT_REPO" ] || _OPT_REPO=${l#repo:} ;;
    esac
  done < "$1"
}

# A ref recorded by another clone can name a file that does not exist here.
# Measured 2026-09-10 over the 132 standing rule entries: 82 carry a ref, ONE of
# those does not resolve in this clone (`rule/1339` -> the other clone's
# 1339-pdf-link-hotspot-tracks-name.md, which is the collision itself), and 42
# of the 82 do not resolve in the other clone. Unmarked, such a ref is a path
# with no explanation -- it reads as a missing file, not as another tree's.
_ROOT=$(cd "$HERE/../.." 2>/dev/null && pwd) || _ROOT=""
_ref_missing() {  # $1 ref -> 0 when it does NOT resolve in this clone
  local p
  case "$1" in
    /*) p="$1" ;;
    *)  [ -n "$_ROOT" ] || return 1; p="$_ROOT/$1" ;;
  esac
  [ -e "$p" ] && return 1
  return 0
}

# The "did you mean" list on a refused clear: the ids in THIS tree carrying the
# same issue number. A refusal that only says no leaves the user grepping the
# ledger by hand for the entry they actually meant -- and it is usually there,
# under a suffixed id (`1339_R3_copy_says_what_it_did`).
_local_ids_for() {  # $1 kind dir, $2 contested id, $3 path to skip
  local n f b
  n=$(printf '%s' "$2" | sed -n 's/^\([0-9][0-9][0-9][0-9]\).*$/\1/p')
  [ -n "$n" ] || return 0
  for f in "$1/$n"*; do
    [ -e "$f" ] || continue
    [ "$f" = "$3" ] && continue
    b=$(basename "$f")
    if [ -z "$(_entry_repo "$f")" ] || _entry_is_mine "$f"; then printf '%s\n' "$b"; fi
  done
}

# A refusal is user-facing and is read under pressure: the headline, then what is
# standing there, then the ONE command that does what they meant. Exit 5 belongs
# to it alone (2 usage, 3 mkdir, 4 no such debt).
_refuse() {  # $1 headline, $2.. detail lines
  echo "!! owed REFUSED: $1" >&2
  shift
  local l
  for l in "$@"; do echo "   $l" >&2; done
  exit 5
}

# Computed ONCE, at load. Every reader below asks for it inside a $( ), and a
# subshell cannot memoise back into its parent -- a lazy version would fork git
# once per ENTRY, 132 times for one `list` against the live ledger.
_origin_init

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
  local kind="" subject="" why="" eyes=0 no_eyes=0 ref="" ref_given=0
  local positional=0 repo="" repo_given=0 via=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --eyes) eyes=1 ;;
      # An UPDATE keeps the `eyes` tag (R612); this is the one way to drop one,
      # and it has to be typed, because dropping it downgrades what the debt
      # asks of the user and there is no other record that it ever said so.
      --no-eyes) no_eyes=1 ;;
      --ref)  shift; ref="${1:-}"; [ -n "$ref" ] || _die "--ref needs a value" 2
              ref_given=1 ;;
      --repo) shift; repo="${1:-}"
              [ -n "$repo" ] || _die "--repo needs a value: a clone path, its basename, or 'here'" 2
              repo_given=1 ;;
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
    || _die "usage: $0 add <rule|look|suite> <what> [why] [--eyes|--no-eyes] [--ref <path>] [--repo <clone>]" 2
  [ "$eyes" = 1 ] && [ "$no_eyes" = 1 ] \
    && _die "--eyes and --no-eyes say opposite things about the same entry" 2
  # LINE 1 IS ONE LINE, and lines 2+ are `key:value` (R607). A newline in the
  # subject, the reason or the ref forges them: `add rule 9001 $'B claims
  # this\nrepo:/other/clone'` wrote a repo: line ABOVE the real stamp, and
  # _entry_repo takes the first -- so the writer was refused on its own entry
  # and another clone was offered it. The stamp is positional, not
  # authenticated; this is what keeps the position meaningful.
  local _f
  for _f in "$subject" "$why" "$ref"; do
    case "$_f" in
      *"$_NL"*) _die "a newline in the subject, the reason or the ref would forge a field -- keep each to ONE line" 2 ;;
    esac
  done
  local d; d=$(_kind_dir "$kind") || _bad_kind "$kind"
  { [ "$eyes" = 1 ] || [ "$no_eyes" = 1 ]; } && [ "$kind" != rule ] \
    && _die "--eyes is a RULE tag: a look debt already needs eyes, and a suite debt never does" 2
  mkdir -p "$d" || _die "cannot create $d" 3

  # WHOSE ENTRY THIS IS: this clone's, unless --repo says otherwise. Two uses,
  # and both are real -- another clone's id, to update what they filed; or
  # `here`, when another clone holds the bare id and this tree needs a slot for
  # its own issue number of the same value. Suffixing the SUBJECT would give it
  # a slot too, and is wrong: _issue_ref resolves a bare 4-digit id only, so
  # `1344b` records the ruling with no pointer to its options (R603).
  if [ "$repo_given" = 1 ]; then
    case "$repo" in here|HERE|.) via="$_ORIGIN_VIA" ;; *) via=told ;; esac
    _repo_arg "$repo"; repo="$_REPO_RESOLVED"
  else
    repo="$_ORIGIN"; via="$_ORIGIN_VIA"
  fi

  local id
  case "$kind" in
    suite)
      # DEDUPED by name: the same suite owing a :0 run twice is one debt, and
      # the newer reason is the informative one.
      id=$(_slug "$subject")
      ;;
    rule)
      # DEDUPED by id -- WITHIN AN ORIGIN (R602, amended 2026-09-10). "A ruling
      # IS its issue number" holds inside one clone and nowhere else: two clones
      # filed 1344 for unrelated questions, and folding those together is the
      # defect, not the dedupe.
      id=$(_slug "$subject")
      # The `ref:` is resolved further down, NOT here: it depends on whose entry
      # this turns out to be, and on what the entry it replaces already carries.
      ;;
    look)
      # NEVER deduped. Two different things can carry the same description
      # ("the marker callout"), and merging them would silently drop one -- the
      # exact class of loss this ledger exists to prevent. Unique id per add.
      id="$(_slug "$subject").$(date +%s).$$"
      ;;
  esac

  # THE ASSERTION, not a check on the user: every arm above runs the id through
  # _slug, which maps `/` to `_`, so `add` has never been able to escape the
  # kind dir. It is here so that an edit which drops a _slug is caught by the
  # ledger rather than by the filesystem (R611).
  _check_id "$kind" "$id"

  # An explicit --repo that does not match what is standing in the bare slot gets
  # a slot of its OWN, `<id>@<tag>`. `@` cannot survive _slug, so a namespaced id
  # can never collide with a legacy one, and `clear --repo` finds it back.
  if [ "$repo_given" = 1 ] && [ -e "$d/$id" ]; then
    local standing; standing=$(_entry_repo "$d/$id")
    # EXACT. On a tag compare, `--repo here` from a clone that merely SHARES the
    # bare slot owner's directory name skipped the namespacing and went on to
    # overwrite it (measured: two clones both named `xschem`).
    if [ -n "$standing" ] && [ "$standing" != "$repo" ]; then
      id="$id@$(_repo_tag "$repo")"
    fi
  fi

  local action="recorded" prev_eyes="" prev_ref="" prev_extra="" carried=""
  if [ -e "$d/$id" ]; then
    # It said "recorded" here however much it destroyed. An add that replaces
    # says so, and the pre-image goes to cleared.log before the `>` runs.
    action="updated"
    local st; st=$(_entry_repo "$d/$id")
    if [ -z "$st" ]; then
      # NO STAMP -- and which of the two things that can mean is now decided by
      # evidence (_unstamped_verdict), not assumed.
      _unstamped_verdict "$d/$id"
      if [ "$_UV" = foreign ] && [ "$repo_given" != 1 ]; then
        # REFUSED, because this is the automatic path. An agent recording new
        # work must not be the thing that writes over the only surviving copy of
        # a ruling another clone's older script has just destroyed the previous
        # copy of -- and claiming it, which is what this branch used to do, also
        # erased the single signal that anything had happened. The user asking
        # for it deliberately (--repo) still gets it, one flag away.
        local ln2 sub2="(unreadable entry)" rsn2=""
        if ln2=$(_read_entry "$d/$id"); then
          sub2=$(printf '%s' "$ln2" | cut -f2); rsn2=$(printf '%s' "$ln2" | cut -f3-)
        fi
        [ "$sub2" = "$id" ] || rsn2="$sub2 -- $rsn2"
        _refuse "$kind $id carries NO clone stamp, in a ledger that is stamped -- NOTHING written" \
                "standing:  $rsn2" \
                "$_UV_WHY." \
                "That is not a legacy entry: something wrote it here that does not stamp," \
                "which on this machine means another clone's older owed.sh -- and that one" \
                "overwrites with NO pre-image, so an entry of yours may ALREADY be gone from" \
                "this slot. Look before you write over what is left:" \
                "   $OWED_DIR/cleared.log      (nothing of ITS destroying is in here)" \
                "   $0 show" \
                "then take the slot deliberately: $0 add $kind $subject '$why' --repo here" \
                "or drop what is standing:        $0 clear $kind $id"
      fi
      if [ "$_UV" = foreign ]; then
        _warn "$kind '$id' carries no clone stamp and was written after stamping began here -- another clone's older owed.sh wrote it; taking it as you asked and stamping it $(_repo_tag "$repo")"
      else
        _warn "$kind '$id' predates origin stamps -- claiming it for $(_repo_tag "$repo")"
      fi
    elif [ "$st" = "$repo" ]; then
      # It matched, so the entry stays stamped EXACTLY as it was. Rewriting the
      # stamp from what the user typed (`--repo cloneA`) would replace a full
      # clone id with a tag, and clone A would then read its own entry as
      # another clone's -- the refusal firing on its rightful owner.
      repo="$st"
      local prev_via; prev_via=$(_entry_field "$d/$id" repo_via)
      [ -n "$prev_via" ] && via="$prev_via"
    else
      local ln sub="(unreadable entry)" rsn=""
      if ln=$(_read_entry "$d/$id"); then
        sub=$(printf '%s' "$ln" | cut -f2); rsn=$(printf '%s' "$ln" | cut -f3-)
      fi
      [ "$sub" = "$id" ] || rsn="$sub -- $rsn"
      _refuse "$kind $id belongs to another clone -- NOTHING written" \
              "standing:  $rsn" \
              "its clone: $st" \
              "this tree: $_ORIGIN" \
              "file yours beside it:  $0 add $kind $subject '$why' --repo here" \
              "or update theirs:      $0 add $kind $subject '$why' --repo $(_repo_hint "$st")"
    fi
    # WHAT THE ENTRY BEING REPLACED CARRIES, read BEFORE the `>` runs (R612).
    # An `add` rebuilt the file from the command line and nothing else, so an
    # update DROPPED whatever the standing entry said about itself. Measured
    # 2026-09-10 on a copy of the live ledger, `add rule 1351 ... --repo
    # xschem-op-wcard`: their `eyes:1` gone and their `ref:` replaced by this
    # clone's 1351 file -- a ruling that could not be made without looking
    # quietly stopped saying so, and their entry ended up pointing at a document
    # their tree does not have.
    _read_opts "$d/$id"
    prev_eyes="$_OPT_EYES"; prev_ref="$_OPT_REF"
    # Anything ELSE a human or a later version wrote on lines 2+ is carried too:
    # the same `>` destroys it, and this file has already had to learn that
    # lesson once, in drain's two rewrite arms (_rewrite_line1).
    prev_extra=$(sed -n '2,$ { /^eyes:/d; /^ref:/d; /^repo:/d; /^repo_via:/d; p; }' "$d/$id")
    _log_gone overwritten "$kind" "$id" "$d/$id" \
      || _die "$kind '$id' NOT overwritten: the pre-image could not be recorded" 3
  fi

  # THE REF, in priority order (R612):
  #   1. what the caller typed with --ref -- an explicit statement wins;
  #   2. what the entry being replaced already carries -- NEVER overwritten with
  #      a path derived here, because for another clone's entry that path names
  #      a file that tree does not have;
  #   3. for a rule entry that is THIS clone's, the issue file this clone can
  #      see (R603). An entry filed for ANOTHER clone gets no auto-resolved ref:
  #      the ledger would be asserting, in their name, that their ruling lives
  #      in our file.
  local auto_ref=""
  if [ "$kind" = rule ] && [ "$repo" = "$_ORIGIN" ]; then auto_ref=$(_issue_ref "$subject"); fi
  if [ "$ref_given" != 1 ]; then
    if [ -n "$prev_ref" ]; then
      ref="$prev_ref"
      # Only a ref that would NOT have been re-derived anyway is worth a line of
      # the user's attention -- so the everyday same-clone re-add says nothing
      # new, and a rescued one says so.
      [ "$prev_ref" = "$auto_ref" ] || carried="ref:$prev_ref"
    else
      ref="$auto_ref"
    fi
  fi
  # THE EYES TAG survives an update unless --no-eyes says otherwise. Nothing
  # auto-derives it, so carrying it is always a rescue and is always reported.
  if [ "$eyes" != 1 ] && [ "$no_eyes" != 1 ] && [ "$prev_eyes" = 1 ]; then
    eyes=1
    carried="${carried:+$carried, }eyes:1"
  fi
  if [ -n "$prev_extra" ]; then
    carried="${carried:+$carried, }$(printf '%s\n' "$prev_extra" | wc -l) other line(s)"
  fi

  printf '%s\t%s\t%s\n' "$(date +%s)" "$subject" "$why" > "$d/$id"
  [ "$eyes" = 1 ] && printf 'eyes:1\n' >> "$d/$id"
  [ -n "$ref" ]   && printf 'ref:%s\n' "$ref" >> "$d/$id"
  [ -n "$prev_extra" ] && printf '%s\n' "$prev_extra" >> "$d/$id"
  _stamp_as "$d/$id" "$repo" "$via"
  # The everyday line is UNCHANGED. The id and the clone are named only when one
  # of them is not the obvious one, so a single-clone session reads as before.
  if [ "$repo" = "$_ORIGIN" ] && [ "$id" = "$(_slug "$subject")" ]; then
    _say "$action $kind debt: $subject"
  else
    _say "$action $kind debt: $subject  (id $id, clone $(_repo_tag "$repo"))"
  fi
  # AFTER the summary, and only when something was actually rescued: a field the
  # command line did not supply and this tree could not have re-derived.
  [ -n "$carried" ] && _say "kept from the entry it replaced: $carried"
  return 0
}

cmd_list() {
  local want="${1:-}"
  case "$want" in ''|rule|suite|look) ;; *) _die "unknown kind '$want'" 2 ;; esac
  local total=0 k d f line epoch subject reason tag ref orig
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
      _read_opts "$f"
      tag=""
      [ "$_OPT_EYES" = 1 ] && tag=" [needs eyes]"
      printf '  [%s] %-34s %3sd  %s%s\n' "$(basename "$f")" "$subject" "$(_age_days "$epoch")" "$reason" "$tag"
      ref="$_OPT_REF"
      if [ -n "$ref" ]; then
        if _ref_missing "$ref"; then
          printf '  %-37s      read: %s   (not in this clone)\n' "" "$ref"
        else
          printf '  %-37s      read: %s\n' "" "$ref"
        fi
      fi
      # The EVERYDAY output is unchanged: a clone is named only when it is not
      # this one, so a single-clone ledger lists exactly as it always did.
      orig="$_OPT_REPO"
      if [ -n "$orig" ] && [ "$orig" != "$_ORIGIN" ]; then
        printf '  %-37s      from: %s   (another clone)\n' "" "$orig"
      elif [ -z "$orig" ]; then
        # AN UNSTAMPED ENTRY IS MARKED ONLY WHEN IT IS EVIDENCE. In a ledger
        # with no stamps at all, or for an entry older than every stamp, this
        # says nothing -- a never-backfilled ledger lists exactly as it did.
        # In a stamped ledger a NEWER unstamped entry is a write by something
        # that does not stamp, and the reader is where that has to surface: the
        # user reads `show` before they type `clear`.
        _unstamped_verdict "$f"
        [ "$_UV" = foreign ] && \
          printf '  %-37s      no clone recorded, and written after stamping began here -- another clone wrote this\n' ""
      fi
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
  local k d f line epoch subject reason n=0 ref orig
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
      _read_opts "$f"
      if [ "$k" = rule ] && [ "$_OPT_EYES" = 1 ]; then
        printf '  %s   (a RULING — and one you must LOOK to make)\n' "$subject"
      elif [ "$k" = rule ]; then
        printf '  %s   (a RULING)\n' "$subject"
      else
        printf '  %s\n' "$subject"
      fi
      [ -n "$reason" ] && printf '      why: %s\n' "$reason"
      ref="$_OPT_REF"
      if [ -n "$ref" ]; then
        if _ref_missing "$ref"; then
          printf '      the options are in: %s   (not in this clone)\n' "$ref"
        else
          printf '      the options are in: %s\n' "$ref"
        fi
      fi
      # A foreign entry is NAMED, and the command printed is the PLAIN one --
      # never the --repo override (user's ruling, 2026-09-10).
      #
      # This used to print the override, on the argument that a queue telling
      # the user to type a command that gets refused is worse than one that says
      # nothing. True of a user at a keyboard, and wrong here: the failure this
      # whole change exists to stop is an AGENT in clone B closing a ruling the
      # user has never answered in clone A, and `show` handed it that exact
      # command with no friction and no statement of consequence. The refusal is
      # the friction. So the plain command is printed, the refusal explains
      # whose entry it is, and the refusal -- read by someone who has just been
      # told no -- is the one place the override is spelled out.
      orig="$_OPT_REPO"
      if [ -n "$orig" ] && [ "$orig" != "$_ORIGIN" ]; then
        printf '      filed in another clone: %s\n' "$orig"
      elif [ -z "$orig" ]; then
        _unstamped_verdict "$f"
        [ "$_UV" = foreign ] && {
          printf '      NO CLONE RECORDED, and written after stamping began here --\n'
          printf '      a clone running an older owed.sh wrote this, over whatever was in\n'
          printf '      the slot. Read it before you answer it.\n'
        }
      fi
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
  local kind="" id="" repo="" repo_given=0 positional=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) shift; repo="${1:-}"
              [ -n "$repo" ] || _die "--repo needs a value: a clone path, its basename, or 'here'" 2
              repo_given=1 ;;
      --*)    _die "unknown option '$1'" 2 ;;
      *)      positional=$((positional + 1))
              case "$positional" in
                1) kind="$1" ;;
                2) id="$1" ;;
                *) _die "too many arguments" 2 ;;
              esac ;;
    esac
    shift
  done
  [ -n "$kind" ] && [ -n "$id" ] \
    || _die "usage: $0 clear <rule|look|suite> <id> [--repo <clone>]" 2
  # THE ID IS A FILENAME (R611). `clear rule ../cleared.log` deleted the
  # pre-image log at exit 0 and `clear rule ../../victim.txt` deleted a file
  # outside the state dir -- both measured 2026-09-10, both inherited from the
  # pre-stamp script, and the first of them destroys the record of itself.
  _check_id "$kind" "$id"
  local d; d=$(_kind_dir "$kind") || _bad_kind "$kind"

  # --repo also finds the namespaced slot `add --repo` writes, and PREFERS it:
  # `add rule 1344 --repo here` from the clone that does not hold the bare slot
  # writes `1344@<tag>`, so `clear rule 1344 --repo here` has to reach the same
  # file rather than the bare one it is deliberately not touching.
  local f="$d/$id" want=""
  if [ "$repo_given" = 1 ]; then
    _repo_arg "$repo"; want="$_REPO_RESOLVED"
    [ -e "$d/$id@$(_repo_tag "$want")" ] && f="$d/$id@$(_repo_tag "$want")"
  fi
  [ -e "$f" ] || _die "no $kind debt with id '$id' (see: $0 list)" 4

  # WHOSE ENTRY IS BEING DESTROYED. `clear` resolved by exact filename and rm'd
  # whatever was there, so `clear rule 1339` from the wrong clone closed a
  # ruling the user had never answered -- silently, exit 0. It refuses now.
  local st; st=$(_entry_repo "$f")
  if [ -z "$st" ]; then
    # UNATTRIBUTED -- one word for two very different situations since the
    # ledger was backfilled, so the verdict is measured (_unstamped_verdict) and
    # the warning says which one it is.
    _unstamped_verdict "$f"
    if [ "$_UV" = foreign ]; then
      # PROCEEDS, and it is the one place a FOREIGN verdict does. `clear` is the
      # command only the user is entitled to run, and a refusal here is how the
      # user gets locked out of their own queue -- the failure mode the absolute
      # -path stamp already makes too easy (see cmd_restamp). It is loud, it
      # names what it may be destroying, and R610's pre-image makes it
      # recoverable. `add`, which is the AUTOMATIC path, refuses instead.
      _warn "$kind '$(basename "$f")' carries no clone stamp -- and this is NOT a legacy entry"
      echo "   $_UV_WHY," >&2
      echo "   so a clone running an owed.sh that does not stamp wrote it, and what is" >&2
      echo "   standing here may be a ruling nobody in THIS tree has answered." >&2
      echo "   Clearing it as asked; the pre-image goes to $OWED_DIR/cleared.log." >&2
    else
      # Filed before stamps existed. Proceeds exactly as it always did -- every
      # `clear rule <id>` quoted in a receipt has to keep working -- but says
      # so, because nothing on the entry records which clone filed it.
      _warn "$kind '$(basename "$f")' predates origin stamps -- clearing it, but no clone is recorded on it"
    fi
  elif [ "$repo_given" = 1 ]; then
    # EXACT, and `here` is therefore strictly THIS clone: --repo is a statement
    # of intent (R609), and on a tag compare `--repo here` cleared another
    # clone's unanswered ruling whenever the two directories shared a name.
    [ "$st" = "$want" ] || _refuse \
      "$kind $(basename "$f") is filed in $st, not $want -- NOT cleared" \
      "drop --repo to clear your own, or name that clone: --repo $(_repo_hint "$st")"
  elif [ "$st" != "$_ORIGIN" ]; then
    local ln sub="(unreadable entry)" rsn="" cands c
    if ln=$(_read_entry "$f"); then
      sub=$(printf '%s' "$ln" | cut -f2); rsn=$(printf '%s' "$ln" | cut -f3-)
    fi
    local -a msg=()
    [ "$sub" = "$id" ] || rsn="$sub -- $rsn"
    msg+=("its clone: $st")
    msg+=("standing:  $rsn")
    # DID YOU MEAN. Both answers are worth printing: the entries this clone owns
    # on that number are what the user probably meant, and owning NONE says the
    # number means something else here -- which is the situation itself.
    cands=$(_local_ids_for "$d" "$id" "$f")
    if [ -n "$cands" ]; then
      msg+=("this clone's own $kind debts on that number:")
      while IFS= read -r c; do
        [ -n "$c" ] && msg+=("   $0 clear $kind $c")
      done <<< "$cands"
    else
      case "$id" in
        [0-9][0-9][0-9][0-9]*) msg+=("this clone owns no $kind debt on that number") ;;
      esac
    fi
    msg+=("to clear THEIRS anyway: $0 clear $kind $id --repo $(_repo_hint "$st")")
    _refuse "$kind $id belongs to another clone -- NOT cleared" "${msg[@]}"
  fi

  # The pre-image FIRST: after the rm there is nothing left to record -- and if
  # it cannot be recorded, the rm does not happen.
  _log_gone cleared "$kind" "$(basename "$f")" "$f" \
    || _die "$kind '$(basename "$f")' NOT cleared: the pre-image could not be recorded" 3
  rm -f "$f"
  _say "cleared $kind debt $(basename "$f")"
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
  local names=() ids=() f line subject skipped=0 orig
  for f in "$d"/*; do
    [ -e "$f" ] || continue
    line=$(_read_entry "$f") || { _warn "skipping unreadable entry $f"; continue; }
    # WHOSE SUITE IS IT. A suite name resolves against THIS clone's
    # tests/headless (_suite_file, below). Measured 2026-09-10 over the 8 debts
    # then standing: 7 resolve here, all 7 resolve in the other clone too, and 6
    # of those 7 files DIFFER in content. So draining another clone's debt runs
    # a different suite from the one that was owed, and then clears their debt
    # on a pass -- an automated verdict discharging work it never did, one clone
    # over.
    orig=$(_entry_repo "$f")
    if [ -z "$orig" ]; then
      # NO STAMP, and since the backfill that can mean two things. A debt that
      # arrived after stamping began here was written by something that does not
      # stamp, so it is treated exactly like another clone's: not run, not
      # claimed, left standing. Running it would let a pass in this tree clear a
      # debt this tree was never given.
      _unstamped_verdict "$f"
      if [ "$_UV" = foreign ]; then
        skipped=$((skipped + 1))
        echo "== SKIP $(basename "$f") -- no clone recorded, and written after stamping began here; another clone's older owed.sh wrote it. Not run, not claimed."
        continue
      fi
      # UNATTRIBUTED, so it is claimed on the way through (R608) -- but ONLY if
      # its name resolves here. The 8th of those 8 debts,
      # test_hier_pdf_links_1333, exists in the other clone and not in this one:
      # a name that resolves nowhere here is evidence the debt is not this
      # clone's, and stamping it would hand this tree an entry it cannot pay and
      # refuse the clone that can. Unresolvable stays unattributed and is
      # reported as a misnamed debt by R309 below, exactly as before.
      if _suite_file "$(printf '%s' "$line" | cut -f2)" >/dev/null; then
        _claim "$f" suite "$(basename "$f")"
      fi
    elif [ "$orig" != "$_ORIGIN" ]; then
      skipped=$((skipped + 1))
      echo "== SKIP $(basename "$f") -- another clone's debt ($(_repo_tag "$orig")); drain it there"
      continue
    fi
    line=${line#*	}; subject=${line%%	*}
    names+=("$subject"); ids+=("$(basename "$f")")
  done

  if [ "${#names[@]}" -eq 0 ]; then
    if [ "$skipped" -gt 0 ]; then
      echo "no suite debts for THIS clone to drain ($skipped left standing for another clone)."
    else
      echo "no suite debts to drain."
    fi
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
      _rewrite_line1 "$d/${ids[$i]}" "$now" "${names[$i]}" \
                     "NO SUCH SUITE FILE -- looked for $cand"
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
      # A pass is the ONE verdict allowed to clear a debt by itself (R302), and
      # it still leaves a pre-image: nothing may leave this ledger unrecorded.
      _log_gone drained suite "${ids[$i]}" "$d/${ids[$i]}" \
        || _die "suite '${ids[$i]}' passed but is NOT cleared: the pre-image could not be recorded" 3
      rm -f "$d/${ids[$i]}"
      echo "   PASS -> debt cleared"
    else
      failed=$((failed + 1))
      # A failure must NOT clear the debt. A drain that loses work when a suite
      # goes red is a way to forget things, not a way to remember them.
      now=$(date +%s)
      _rewrite_line1 "$d/${ids[$i]}" "$now" "${names[$i]}" \
                     "FAILED on $display (rc=$rc) -- still owed"
      echo "   FAIL -> debt KEPT"
    fi
  done

  echo
  echo "drained: $ran run, $passed passed, $failed failed, $((ran - passed)) still owed"
  # Only when there IS one: the everyday summary is unchanged. A skipped debt is
  # not a failure -- it is not this clone's work -- so it does not colour the
  # exit status, and it is left standing for the clone that owes it.
  [ "$skipped" -gt 0 ] && echo "skipped: $skipped from another clone -- drain those in their own tree"
  # BY NAME, not by position -- see cmd_count. And BOTH user-owed lists are
  # named: an unmentioned list is one a reader can believe was drained.
  echo "look debts untouched: $(_count_kind look)"
  echo "rule debts untouched: $(_count_kind rule)"
  [ "$failed" -eq 0 ]
}

# ---------------------------------------------------------------------------
# THE STAMP IS AN ABSOLUTE PATH, SO MOVING A CLONE ORPHANS EVERY ENTRY IT FILED
#
# `repo:` holds a clone's full path, and every ownership decision compares it
# EXACTLY. That is what makes the refusal trustworthy, and it has a cost nobody
# had written down until 2026-09-10: rename or move a checkout and its own
# entries all turn foreign at once. Measured that day, running this script from
# a copy of the tree at a different path against a copy of the live ledger: all
# 196 entries read as another clone's, `show` marked 187 of 187 rule+look
# `filed in another clone`, `clear` on the user's OWN look debt was REFUSED
# exit 5, and `drain` reported nothing of its own to do. Nothing is destroyed --
# refusal is the safe direction -- but the user's whole queue appears to belong
# to nobody, and before that morning moving a clone cost nothing.
#
# So there is a way back, and it is deliberately narrow:
#
#   * --from is REQUIRED and is never guessed. It is the id the entries carry
#     NOW: the old path, or a basename the ledger itself can resolve (which it
#     still can, because the stamps are what it asks).
#   * --to defaults to THIS clone.
#   * IT REFUSES IF THE --from CLONE IS STILL A CHECKOUT ON THIS MACHINE. That
#     is the whole safety argument: restamp is for a clone that MOVED, which is
#     why its old path is gone. A path that still holds a tests/headless/owed.sh
#     is a live clone, and re-stamping its entries would be a mass transfer of
#     another tree's rulings on one command line -- the very thing R609 exists
#     to make expensive. To write one of its entries deliberately, --repo does
#     that, one command at a time.
#   * Every entry it touches gets a pre-image in cleared.log first (R610), and
#     if that cannot be written, nothing is rewritten. A re-attribution is not a
#     destroy, but it rewrites the one field this whole mechanism rests on.
#   * --dry-run lists what it would do and writes nothing.
#
# `repo_via:` becomes `restamped`: a path that was told to us by a human after
# the fact is not the same evidence as one git or the filesystem answered with,
# and the ledger says which it has.
# ---------------------------------------------------------------------------
cmd_restamp() {
  local from="" to="" dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --from) shift; from="${1:-}"; [ -n "$from" ] || _die "--from needs a value: the clone id the entries carry now" 2 ;;
      --to)   shift; to="${1:-}";   [ -n "$to" ]   || _die "--to needs a value: a clone path, or 'here'" 2 ;;
      --dry-run|-n) dry=1 ;;
      *) _die "usage: $0 restamp --from <clone> [--to here|<clone>] [--dry-run]" 2 ;;
    esac
    shift
  done
  [ -n "$from" ] \
    || _die "restamp needs --from <clone>: the id the entries carry now (its old path, or a basename the ledger knows). Nothing here is guessed." 2
  _repo_arg "$from" --from; from="$_REPO_RESOLVED"
  if [ -n "$to" ]; then _repo_arg "$to" --to; to="$_REPO_RESOLVED"; else to="$_ORIGIN"; fi
  [ "$from" = "$to" ] && _die "restamp --from and --to both name $from -- nothing to do" 2

  local k d f n=0
  local -a hits=()
  for k in $KINDS; do
    d=$(_dir "$k")
    for f in "$d"/*; do
      [ -f "$f" ] || continue
      [ "$(_entry_repo "$f")" = "$from" ] || continue
      hits+=("$k	$f"); n=$((n + 1))
    done
  done
  if [ "$n" -eq 0 ]; then
    _say "no entry in this ledger is stamped $from -- nothing restamped"
    return 0
  fi

  # THE ONE GUARD. A clone that is still there has not moved.
  if [ -e "$from/tests/headless/owed.sh" ]; then
    _refuse "restamp refused: $from is still a checkout on this machine -- NOTHING written" \
            "it still holds tests/headless/owed.sh, so it did not move: those $n entries" \
            "are another live tree's, and restamp is not the way to take them." \
            "restamp exists for a clone that MOVED or was RENAMED, whose old path is gone." \
            "to write ONE of that clone's entries deliberately: $0 add|clear ... --repo $(_repo_hint "$from")"
  fi

  local tmp="$OWED_DIR/.restamp.$$" line b
  for line in "${hits[@]}"; do
    k=${line%%	*}; f=${line#*	}; b=$(basename "$f")
    if [ "$dry" = 1 ]; then echo "  would restamp $k/$b"; continue; fi
    _log_gone restamped "$k" "$b" "$f" \
      || _die "$k '$b' NOT restamped: the pre-image could not be recorded" 3
    awk -v old="repo:$from" -v new="repo:$to" '
      $0 == old { print new; print "repo_via:restamped"; next }
      /^repo_via:/ { next }
      { print }
    ' "$f" > "$tmp" && mv -f "$tmp" "$f" \
      || _die "$k '$b' could not be rewritten -- stopping with $n entries part-done; cleared.log holds every pre-image" 3
  done

  if [ "$dry" = 1 ]; then
    _say "$n entries would be restamped: $from -> $to  (dry run, nothing written)"
  else
    _say "restamped $n entries: $from -> $to  (pre-images in $OWED_DIR/cleared.log)"
  fi
  return 0
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
    restamp) shift; cmd_restamp "$@" ;;
    -h|--help|help) cmd_help ;;
    *) _die "unknown command '${1:-}'. Try: $0 help" 2 ;;
  esac
fi
