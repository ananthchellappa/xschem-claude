#!/bin/bash
# spawn_reaper.sh — every process a test suite starts, tracked and reaped.
#
# WHY THIS EXISTS (measured 2026-08-15)
#
# 21 `wish tests/headless/gui_gate_widget.tcl` processes were alive on this box,
# all between 87433 s and 88025 s old — a little over 24 hours — together with a
# second virtual display and its window manager. Steady cost: 12% CPU, 269 MB.
# They came from repeated runs of tests/headless/test_gui_gate_batch.sh, whose
# `trap 'rm -rf "$TMP"' EXIT` reaped the throwaway CONTROL DIRS and nothing else.
# So every run deleted the directory and spared the panels, leaving processes
# polling a control dir that no longer existed, forever.
#
# The suite passed all of its own checks the whole time. A suite that leaks
# cannot see it, because "did I clean up after myself" was never asserted.
#
# THE RULE THIS FILE ENFORCES, AND THE ONE IT MUST NOT BREAK
#
#   `pkill -f gui_gate_widget.tcl` IS NOT A FIX.
#
# The gate's control dir ~/.claude/gui_test_gate/ is shared by the main session,
# every worktree and every subagent run, and the USER MAY HAVE A LIVE PANEL ON
# :0 AT THAT MOMENT — it is their only authority over their own screen while a
# suite runs (Pause / Stop / Halt). Killing it by name takes that away mid-run.
# Likewise `pkill Xvfb` would take down :99, the persistent dev display every
# other suite on this machine is using.
#
# So nothing here ever matches by program name. Two identifications, both exact:
#
#   1. PID REGISTRY   — `reaper_track <pid>`, for anything the suite forked
#                       itself and holds a `$!` for.
#   2. PROVENANCE     — a process whose command line names this run's PRIVATE
#                       scratch directory ($TMP from `mktemp -d`). The gate
#                       launches `wish .../gui_gate_widget.tcl <GATE_DIR>`, and
#                       a panel this run caused to exist carries this run's
#                       throwaway GATE_DIR as its last argument. The user's
#                       panel carries ~/.claude/gui_test_gate and can never
#                       match; neither can another session's, whose mktemp
#                       suffix is different.
#
# The X server gets the same treatment plus three hard refusals:
# `reaper_own_xvfb` will not adopt `:0` (the user's screen), will not adopt the
# display named by devdisplay.sh's state file (`:99`, the persistent dev
# display), and will not adopt a server THIS RUN DID NOT START — the last of
# those being the one that does not depend on any environment variable. It
# re-checks the pid's identity in /proc, STRUCTURALLY, before it signals it.
#
# WHAT A RUN THAT NEVER REACHED ITS TEARDOWN LEAVES, AND WHO CLEARS IT
#
# A trap cannot cover a SIGKILL. Three sweeps cover what it leaves, each by
# PROVENANCE and never by name — a run stamps `.reaper_owner` (pid + boot-unique
# start time) into its own scratch root, so "the run that made this is dead" is
# a fact on disk rather than a guess:
#
#   reaper_sweep_orphan_panels   panels whose control dir is under a temp root
#                                and is either GONE, or owned by a dead run
#   reaper_sweep_orphan_xvfb     private displays this launcher started
#                                (marker file per display number), plus the
#                                stale /tmp/.X<n>-lock that burns the number
#   reaper_sweep_orphan_runs     a suite's own state dirs, given a glob and the
#                                pidfiles inside them (test_devdisplay.sh)
#
# USAGE
#
#   . "$HERE/spawn_reaper.sh"
#   reaper_init "$TMP"                     # arm provenance + stamp the owner
#   reaper_mark_owner "$DIR"               # stamp only (a second scratch root)
#   reaper_track "$SOMEPID"                # optional, for explicit forks
#   reaper_own_xvfb "$DISPLAY"             # only if THIS run started it
#   reaper_survivors                       # "pid<TAB>cmdline" lines, one each
#   reaper_reap_procs                      # kill them (idempotent)
#   reaper_reap_xvfb                       # then the server, if we own one
#   reaper_reap                            # both, for a trap
#   reaper_sweep_orphan_panels             # panels of runs that were SIGKILLed
#   reaper_sweep_orphan_xvfb               # their private displays and locks
#   reaper_sweep_orphan_runs <glob> <pidfile...>
#
# Spec: doc/claude/specs/gui_test_gate.md, "Reaping contract".

_REAPER_PREFIX=""
_REAPER_PIDS=""
_REAPER_XVFB_DPY=""
_REAPER_XVFB_PID=""
_REAPER_SWEPT=0
_REAPER_SWEPT_X=0
_REAPER_PRIV_XPID=""
_REAPER_PRIV_NUM=""

_reaper_say() { echo "reaper: $*" >&2; }

# /proc/<pid>/cmdline is NUL-separated arbitrary text. Space-joined, with a
# trailing space, so a `case` pattern can anchor on whole words.
#
# `2>/dev/null` comes BEFORE the input redirection, and that ordering is the
# whole point: redirections are applied left to right, so with the file first
# bash reports "No such file or directory" on the still-live stderr when the
# process exits between the /proc listing and this read -- which happens on
# nearly every scan, because a scan is what we run while reaping. Written the
# other way round the suite's output was two thirds diagnostics for a race that
# is entirely normal.
_reaper_cmdline() { tr '\0' ' ' 2>/dev/null < "/proc/$1/cmdline"; }

_reaper_alive() { kill -0 "$1" 2>/dev/null; }

# argv as a list of words, one per line. /proc/<pid>/cmdline is NUL-separated,
# so this is exact even when an argument contains spaces or quotes -- which is
# the whole reason the identifications below are word-wise and never substring.
_reaper_argv() { tr '\0' '\n' 2>/dev/null < "/proc/$1/cmdline"; }
_reaper_argv_n() {   # <pid> <n>  -> argv[n], empty if absent
  _reaper_argv "$1" | sed -n "$(( $2 + 1 ))p"
}

# A pid alone does not identify a process: pids recycle, and a sweep that reads
# "owner 3017510 is dead" off a file written yesterday can be reading about a
# pid that has since been reused. Field 22 of /proc/<pid>/stat (start time in
# clock ticks since boot) makes the pair unique for the life of the boot. The
# comm field is parenthesised and may contain spaces AND parentheses, so the
# split is on the LAST ')'.
_reaper_starttime() {
  local s
  s=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  s=${s##*) }
  printf '%s' "$s" | awk '{print $20}'
}

# Stamp a scratch dir with the identity of the run that owns it. Written at the
# moment the dir is created, so a run that is later SIGKILLed still leaves proof
# of who it was -- which is what lets the NEXT run tell "a live sibling owns
# this" from "the owner is dead and these processes are strays".
reaper_mark_owner() {
  local d="${1:-}"
  [ -d "$d" ] || return 1
  printf '%s %s\n' "$$" "$(_reaper_starttime "$$")" > "$d/.reaper_owner" 2>/dev/null || return 1
  return 0
}

# Is the run that stamped <dir> still alive? Returns 0 = alive (hands off),
# 1 = provably dead, 2 = no stamp at all (UNKNOWN, and therefore also hands off:
# an unstamped dir may predate this mechanism or belong to something else).
_reaper_owner_state() {
  local f="$1/.reaper_owner" p t now
  [ -r "$f" ] || return 2
  read -r p t < "$f" 2>/dev/null || return 2
  case "$p" in ''|*[!0-9]*) return 2 ;; esac
  _reaper_alive "$p" || return 1
  [ -n "$t" ] || return 0
  now=$(_reaper_starttime "$p") || return 1
  [ "$now" = "$t" ] && return 0
  return 1                        # pid recycled: the stamping run is gone
}

# OUR OWN PROCESS AND EVERY ANCESTOR OF IT ARE OFF LIMITS, ALWAYS.
#
# Learned the hard way while building this file: an early
# reaper_sweep_orphan_panels matched `gui_gate_widget.tcl ` anywhere in a
# command line and took the last word as the control dir. The shell that
# LAUNCHED the suite had that string in its own `-c` argument -- the command it
# was running mentioned the widget by path -- and its last word was an unrelated
# /tmp file, so the sweep killed the parent shell. Exit 144, the run gone with
# it. A reaper that can kill its own caller is worse than the leak it fixes;
# sibling test files carry the same scar (`pkill -f gui_gate_widget.tcl` also
# matches pkill itself). The identification below is structural now, and this
# belt is here as well.
_REAPER_ANCESTORS=""
_reaper_ancestor_list() {
  [ -n "$_REAPER_ANCESTORS" ] && { printf '%s' "$_REAPER_ANCESTORS"; return 0; }
  local q="$$" n=0 pp out=" "
  while [ "$n" -lt 64 ]; do
    out="$out$q "
    pp=$(awk '/^PPid:/{print $2; exit}' "/proc/$q/status" 2>/dev/null)
    case "$pp" in ''|0|*[!0-9]*) break ;; esac
    q="$pp"; n=$((n + 1))
  done
  _REAPER_ANCESTORS="$out"
  printf '%s' "$_REAPER_ANCESTORS"
}
_reaper_is_self_or_ancestor() {
  case "$(_reaper_ancestor_list)" in *" $1 "*) return 0 ;; esac
  return 1
}

# TERM, then KILL. Never a pattern, always a pid. Returns non-zero only if the
# process survived both, which on Linux means it is a zombie or unkillable.
_reaper_kill() {
  local p="${1:-}" i
  case "$p" in ''|*[!0-9]*) return 0 ;; esac
  _reaper_is_self_or_ancestor "$p" && return 0
  _reaper_alive "$p" || return 0
  kill -TERM "$p" 2>/dev/null
  for i in $(seq 1 20); do _reaper_alive "$p" || return 0; sleep 0.1; done
  kill -KILL "$p" 2>/dev/null
  for i in $(seq 1 20); do _reaper_alive "$p" || return 0; sleep 0.1; done
  return 1
}

# Arm provenance tracking on a PRIVATE scratch directory.
#
# It must be a temp dir, and that is checked rather than trusted: pointed at,
# say, $HOME, the provenance scan would match every process whose command line
# mentions a path under it — which on a developer box is most of them.
reaper_init() {
  local d="${1:-}"
  case "$d" in
    /tmp/?*|/var/tmp/?*) ;;
    "${TMPDIR:-/nonexistent-tmpdir}"/?*) ;;
    *)
      _reaper_say "REFUSING to arm on '$d' — not a private temp directory"
      return 1 ;;
  esac
  _REAPER_PREFIX="$d"
  # Not fatal if it cannot be written (a read-only or vanished dir): provenance
  # and the registry still work, only the orphan sweep loses one criterion.
  reaper_mark_owner "$d" || _reaper_say "could not stamp an owner file in '$d'"
  return 0
}

# Register a pid we forked ourselves (we hold its $!). Cheap; call it at the
# fork, not at the teardown, so an abort between the two is still covered.
reaper_track() {
  local p="${1:-}"
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  _REAPER_PIDS="$_REAPER_PIDS $p"
  return 0
}

# Everything this run started that is STILL ALIVE, as "pid<TAB>cmdline".
# Empty output is the whole point of the end-of-suite check.
reaper_survivors() {
  local p c seen=" "
  for p in $_REAPER_PIDS; do
    case "$seen" in *" $p "*) continue ;; esac
    _reaper_alive "$p" || continue
    seen="$seen$p "
    printf '%s\t%s\n' "$p" "$(_reaper_cmdline "$p")"
  done
  [ -n "$_REAPER_PREFIX" ] || return 0
  for p in /proc/[0-9]*; do
    p=${p#/proc/}
    _reaper_is_self_or_ancestor "$p" && continue
    case "$seen" in *" $p "*) continue ;; esac
    c=$(_reaper_cmdline "$p") || continue
    [ -n "$c" ] || continue
    # Leading space so argv[0] itself can match; _reaper_cmdline supplies the
    # trailing one. The `/` after the prefix keeps this to things INSIDE our
    # scratch dir rather than a sibling whose name merely starts the same.
    case " $c" in
      *" $_REAPER_PREFIX/"*) seen="$seen$p "; printf '%s\t%s\n' "$p" "$c" ;;
    esac
  done
  return 0
}

# Kill every survivor. Two passes: reaping a launcher can let a launch that was
# still in flight finish and appear, and gui_gate.sh's panels are deliberately
# `setsid`-detached so killing a parent never takes them with it.
reaper_reap_procs() {
  local pass p c n=0
  for pass in 1 2; do
    while IFS=$'\t' read -r p c; do
      [ -n "$p" ] || continue
      _reaper_kill "$p" || _reaper_say "pid $p survived TERM+KILL: $c"
      n=$((n + 1))
    done <<EOF
$(reaper_survivors)
EOF
  done
  return 0
}

# Is <pid> an Xvfb serving <display>?
#
# STRUCTURAL, and this one is not a style preference. The first version asked
# whether the word `Xvfb` and the word `:137` appeared ANYWHERE in the command
# line, and a reviewer got it to adopt -- and therefore TERM+KILL -- a plain
# `bash -c 'sleep 120; :' Xvfb :137`, and before that a tool shell whose own -c
# argument merely mentioned both. An X server's argv begins
#     <...Xvfb> <:display> ...
# and nothing that is not an X server does. argv[0]'s basename must BE `Xvfb`
# (never `wrapper-for-Xvfb`, hence the `/` in the second pattern) and argv[1]
# must BE the display, not merely contain it -- which also keeps :9 from
# matching :99, the same rule devdisplay.sh uses for the same reason.
_reaper_is_xvfb() {
  local p="${1:-}" d="${2:-}" a0 a1
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  [ -n "$d" ] || return 1
  _reaper_alive "$p" || return 1
  a0=$(_reaper_argv_n "$p" 0) || return 1
  a1=$(_reaper_argv_n "$p" 1)
  case "$a0" in Xvfb|*/Xvfb) ;; *) return 1 ;; esac
  [ "$a1" = "$d" ] || return 1
  return 0
}

_reaper_xvfb_pid() {
  local d="${1:-}" p
  for p in /proc/[0-9]*; do
    p=${p#/proc/}
    if _reaper_is_xvfb "$p" "$d"; then echo "$p"; return 0; fi
  done
  return 1
}

# Every display a dev display could be running on, one per line.
#
# BOTH state files, and the $HOME one UNCONDITIONALLY: the refusal below used to
# consult `$XSCHEM_DEVDISPLAY_DIR/display` alone, so any caller that redirected
# that variable made the guard disappear -- and one exists in the tree,
# test_devdisplay.sh, which exports a throwaway state dir for its whole run and
# sources this file. A guard that a caller can switch off by setting a variable
# is documentation, not a guard.
_reaper_devdisplays() {
  local f
  for f in "${XSCHEM_DEVDISPLAY_DIR:-}/display" "$HOME/.claude/xschem_dev_display/display"; do
    case "$f" in /display) continue ;; esac
    [ -r "$f" ] && cat "$f" 2>/dev/null && echo
  done
  return 0
}

# Did THIS run start the server at <pid>? Three ways, all of them facts rather
# than assertions by the caller:
#   * it is in our own pid registry (we forked it here), or
#   * reaper_run_on_private_xvfb forked it in this very shell, or
#   * our parent forked it and handed it down as a PAIR -- display AND pid --
#     through XSCHEM_REAPER_OWNED_*, and the pid really is that server.
# The third is how the re-run under a private display adopts the display its
# parent made for it; it is a pid, so a stale or forged value cannot resolve to
# some other run's server without also naming that server's exact pid.
_reaper_started_xvfb() {
  local p="${1:-}" d="${2:-}" q
  for q in $_REAPER_PIDS; do [ "$q" = "$p" ] && return 0; done
  [ -n "${_REAPER_PRIV_XPID:-}" ] && [ "$p" = "$_REAPER_PRIV_XPID" ] && return 0
  if [ -n "${XSCHEM_REAPER_OWNED_XVFB_PID:-}" ] && \
     [ "$p" = "$XSCHEM_REAPER_OWNED_XVFB_PID" ] && \
     [ "${XSCHEM_REAPER_OWNED_DISPLAY:-}" = "$d" ]; then
    return 0
  fi
  return 1
}

# Adopt the X server on <display> for teardown — ONLY when this run started it.
#
# THREE REFUSALS, and they are the reason this function exists rather than a
# `kill $XVFBPID` at the call site:
#   :0        is the user's screen.
#   :99       (whatever either devdisplay.sh state file says) is the PERSISTENT
#             dev display, shared by every other suite on this machine. Killing
#             it would break all of them, and it must survive everything.
#   not ours  a server this run did not start is somebody else's, whatever it
#             is called and whatever the environment says. This is the refusal
#             that holds when the other two are subverted -- :99's server is not
#             in our registry, so `reaper_own_xvfb :99` fails even with both
#             state files unreadable.
reaper_own_xvfb() {
  local d="${1:-${DISPLAY:-}}" p dd
  [ -n "$d" ] || return 1
  case "$d" in
    :0|:0.*|localhost:0*|*:0|*:0.*)
      _reaper_say "REFUSING to own '$d' — that is the user's screen"; return 1 ;;
  esac
  for dd in $(_reaper_devdisplays); do
    if [ "$dd" = "$d" ]; then
      _reaper_say "REFUSING to own '$d' — that is the persistent dev display"
      return 1
    fi
  done
  p=$(_reaper_xvfb_pid "$d") || { _reaper_say "no Xvfb serving '$d' to own"; return 1; }
  if ! _reaper_started_xvfb "$p" "$d"; then
    _reaper_say "REFUSING to own '$d' (pid $p) — this run did not start it"
    return 1
  fi
  _REAPER_XVFB_DPY="$d"
  _REAPER_XVFB_PID="$p"
  return 0
}

# Is the server we own still up? (For the end-of-suite assertion.)
reaper_xvfb_alive() {
  [ -n "$_REAPER_XVFB_PID" ] || return 1
  _reaper_is_xvfb "$_REAPER_XVFB_PID" "$_REAPER_XVFB_DPY"
}

reaper_owns_xvfb() { [ -n "$_REAPER_XVFB_PID" ]; }
reaper_xvfb_pid() { printf '%s' "$_REAPER_XVFB_PID"; }

# Tear down the server we own. The identity re-check is not decoration: pids
# recycle, and by the time a trap runs, xvfb-run's own clean_up may already have
# killed it and something unrelated may hold the number.
reaper_reap_xvfb() {
  [ -n "$_REAPER_XVFB_PID" ] || return 0
  if ! _reaper_is_xvfb "$_REAPER_XVFB_PID" "$_REAPER_XVFB_DPY"; then
    _REAPER_XVFB_PID=""
    return 0
  fi
  _reaper_kill "$_REAPER_XVFB_PID" || \
    _reaper_say "Xvfb pid $_REAPER_XVFB_PID ($_REAPER_XVFB_DPY) survived TERM+KILL"
  return 0
}

# Everything, for a trap. Idempotent — a suite that traps EXIT, INT and TERM
# will call it more than once.
reaper_reap() { reaper_reap_procs; reaper_reap_xvfb; }

# The control dir of a stray panel says whose it is -- IF anything in it or
# above it still says so. Walk up from the control dir towards the temp root
# looking for the `.reaper_owner` stamp: a gate self-test's control dirs are
# `$TMP/g1`, `$TMP/g3`, ... and the stamp is on `$TMP`.
#
# Echoes: gone | dead | live | unknown.
_reaper_dir_verdict() {
  local dir="$1" d n=0
  [ -d "$dir" ] || { echo gone; return 0; }
  d="$dir"
  while [ "$n" -lt 4 ]; do
    case "$d" in ''|/|/tmp|/var/tmp) break ;; esac
    if [ -e "$d/.reaper_owner" ]; then
      _reaper_owner_state "$d"
      case $? in
        0) echo live; return 0 ;;
        1) echo dead; return 0 ;;
        *) echo unknown; return 0 ;;
      esac
    fi
    d=$(dirname "$d"); n=$((n + 1))
  done
  echo unknown
  return 0
}

# Panels left behind by a run that could not run its own teardown — a SIGKILL, a
# tool timeout, a pulled worktree. A trap cannot cover those, so the NEXT run
# does, at startup.
#
# The criterion is PROOF, not a name. A gate panel's last argument is its
# control dir, and there are two proofs of orphanhood, because the fix for the
# original leak created a second shape:
#
#   GONE   — the dir is under a temp root and NO LONGER EXISTS, so the panel is
#            polling a directory nobody can ever write to again. This is the
#            exact criterion by which the 21 strays were identified; it is the
#            shape the OLD code produced, where `rm -rf "$TMP"` ran and the
#            panels were spared.
#   DEAD   — the dir exists, and the `.reaper_owner` stamp at or above it names
#            a run that is provably gone (pid dead, or its start time no longer
#            matches so the pid was recycled). This is the shape a SIGKILLed run
#            now leaves, because reaping moved BEFORE the `rm -rf` -- the dirs
#            survive with it. Without this half the sweep would only ever have
#            cleaned up history, never the leak path the spec claims it covers.
#
# The user's panel is excluded three times over: ~/.claude/gui_test_gate is not
# under a temp root, it exists, and it carries no owner stamp. A concurrent
# suite's panel is excluded because its dir exists AND its stamp is alive. A dir
# with no stamp and no way to judge it is left strictly alone.
reaper_sweep_orphan_panels() {
  local p c dir n=0 w0 w1 w2 extra
  for p in /proc/[0-9]*; do
    p=${p#/proc/}
    _reaper_is_self_or_ancestor "$p" && continue
    c=$(_reaper_cmdline "$p") || continue
    case " $c" in *"gui_gate_widget.tcl "*) ;; *) continue ;; esac
    # STRUCTURAL, never a substring. A gate panel's argv is exactly
    #     <...wish>  <...gui_gate_widget.tcl>  <control-dir>
    # and nothing else. Matching the string anywhere in a command line instead
    # matches every shell whose -c argument happens to mention the widget by
    # path -- including the one that launched this suite, whose own last word is
    # then taken for a control dir. See the ancestor guard above: that is not a
    # hypothetical, it killed the parent shell before this was rewritten.
    # `read` rather than `set --`, so a `*` in a foreign command line cannot
    # glob against the filesystem on its way through.
    read -r w0 w1 w2 extra <<< "$c"
    [ -n "${w2:-}" ] && [ -z "${extra:-}" ] || continue
    case "$w0" in *wish) ;; *) continue ;; esac
    case "$w1" in *gui_gate_widget.tcl) ;; *) continue ;; esac
    dir="$w2"
    case "$dir" in
      /tmp/?*|/var/tmp/?*) ;;
      "${TMPDIR:-/nonexistent-tmpdir}"/?*) ;;
      *) continue ;;
    esac
    case "$(_reaper_dir_verdict "$dir")" in
      gone|dead) ;;
      *) continue ;;                   # live, or nothing to judge it by
    esac
    _reaper_kill "$p"
    n=$((n + 1))
  done
  _REAPER_SWEPT="$n"
  [ "$n" -gt 0 ] && _reaper_say "swept $n orphaned panel(s) (control dir gone, or its run is dead)"
  return 0
}

reaper_swept() { printf '%s' "$_REAPER_SWEPT"; }

# How many pids the registry holds. Not a health metric -- a check that asserts
# "nothing survived" is only worth its ink if something was started, and this is
# how a suite carries that positive evidence in the same breath.
reaper_tracked() {
  local p n=0
  for p in $_REAPER_PIDS; do n=$((n + 1)); done
  printf '%s' "$n"
}

# --- a private X display whose teardown is OURS ------------------------------
#
# WHY NOT `xvfb-run`, which is what the gate self-tests used to re-exec through.
# Two reasons, the second measured here on 2026-08-15:
#
#   1. Its teardown is ITS `trap clean_up EXIT`. That is a shell trap like any
#      other: a SIGKILL, a tool timeout, or its own `exit 5` out of a failing
#      `rm -r` skips it, and the server plus every client on it outlives the run
#      that created them. Delegating the one thing this file exists to guarantee
#      to a trap in someone else's script is exactly the shape of the bug.
#   2. `clean_up` runs under `set -e` and ends with `kill "$XVFBPID"`. Reap the
#      server from inside the session -- which is the correct thing for the
#      session to do -- and that `kill` fails, `set -e` fires INSIDE the trap,
#      and xvfb-run exits 1 regardless of what the command returned. A suite
#      with `RESULT fails=0` and 57 green checks reported failure. So the
#      careful teardown and the honest exit status could not both be had while
#      xvfb-run owned the server.
#
# Started the way devdisplay.sh starts one -- no xauth, `-nolisten tcp` -- and
# the readiness poll uses the ABSTRACT socket as well as the file, because WSLg
# mounts /tmp/.X11-unix 777 without the sticky bit and an X server there binds
# only the abstract one (doc/claude/specs/dev_display.md).
_reaper_x_listening() {
  [ -S "/tmp/.X11-unix/X$1" ] && return 0
  command -v ss >/dev/null 2>&1 || return 1
  ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$1\b"
}

# A lock file with no server behind it. X servers stale-check their own lock and
# start anyway; this code did not, and treated the mere existence of
# /tmp/.X<n>-lock as "taken" -- so every SIGKILLed run permanently burned one of
# the 60 numbers this launcher can use, monotonically, until after 60 of them
# `reaper_run_on_private_xvfb` returns 127 and the suite exits with no RESULT
# line at all. Measured: /tmp/.X101-lock naming a dead pid, nothing listening,
# survived six subsequent runs and pushed each one to the next number.
#
# Removing it is only safe when BOTH are true: nothing is listening on that
# display, and the pid written in the lock is not alive. Either alone is not
# enough -- a server mid-startup has a lock and no socket yet.
_reaper_drop_stale_lock() {
  local n="$1" f="/tmp/.X$1-lock" p
  [ -e "$f" ] || return 0
  _reaper_x_listening "$n" && return 1
  p=$(tr -d ' \t\n' < "$f" 2>/dev/null)
  case "$p" in ''|*[!0-9]*) ;; *) _reaper_alive "$p" && return 1 ;; esac
  rm -f "$f" 2>/dev/null
  return 0
}

_reaper_display_free() {
  if [ -e "/tmp/.X$1-lock" ]; then
    _reaper_drop_stale_lock "$1" || return 1
  fi
  _reaper_x_listening "$1" && return 1
  return 0
}

# A private display, recorded on disk the instant it exists.
#
# The parent of a private-Xvfb run gets a trap (below), but a trap cannot cover
# a SIGKILL of that parent -- and THE STRAY THAT STARTED THIS WHOLE ITEM WAS AN
# X SERVER, not a panel. So the launcher leaves a marker naming the server AND
# the run that owns it, and the next run sweeps the ones whose owner is dead.
# Panels had this cover from the start; displays did not, and the spec claimed
# they did.
_reaper_xvfb_marker() { printf '%s/.reaper_xvfb.%s' "${TMPDIR:-/tmp}" "$1"; }

# reaper_run_on_private_xvfb <screen> <cmd> [args...]
#
# Runs <cmd> on a private display, tears the display down, and returns <cmd>'s
# exit status -- never the teardown's. The command is handed
# XSCHEM_REAPER_OWNED_DISPLAY so it can adopt the server itself (which is what
# lets it ASSERT the teardown); the kill here is then a guarded no-op, and the
# real thing only when the command could not run its own.
# Tear down the private display this shell started, if it still has one.
# Idempotent, and safe to call from a trap that fires more than once.
#
# THE LOCK IS DROPPED ONLY WHEN THE KILL SUCCEEDED. It used to be an
# unconditional `rm -f` after the kill, which under a sabotage that made the
# kill a no-op left :103 serving happily with no lock file -- and the lock is
# the only thing that stops `xvfb-run -a`, or the next Xvfb, from claiming a
# number that is in use.
_reaper_private_xvfb_teardown() {
  local x="$_REAPER_PRIV_XPID" n="$_REAPER_PRIV_NUM"
  [ -n "$x" ] || return 0
  if _reaper_kill "$x"; then
    rm -f "$(_reaper_xvfb_marker "$n")" 2>/dev/null
    _reaper_drop_stale_lock "$n"
    _REAPER_PRIV_XPID=""; _REAPER_PRIV_NUM=""
  else
    _reaper_say "private Xvfb pid $x (:$n) survived TERM+KILL — lock left in place"
  fi
  return 0
}

reaper_run_on_private_xvfb() {
  local screen="${1:-1280x1024x24}"; shift
  command -v Xvfb >/dev/null 2>&1 || { _reaper_say "Xvfb not found"; return 127; }
  local n dpy="" xpid="" i
  for n in $(seq 101 160); do
    _reaper_display_free "$n" || continue
    Xvfb ":$n" -screen 0 "$screen" -nolisten tcp >/dev/null 2>&1 &
    xpid=$!
    for i in $(seq 1 100); do
      _reaper_x_listening "$n" && break
      kill -0 "$xpid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$xpid" 2>/dev/null && _reaper_x_listening "$n"; then
      dpy=":$n"
      _REAPER_PRIV_XPID="$xpid"; _REAPER_PRIV_NUM="$n"
      # marker BEFORE the command runs: everything after this point can be
      # SIGKILLed, and the next run still knows this server had an owner and
      # who it was.
      printf '%s %s %s\n' "$xpid" "$$" "$(_reaper_starttime "$$")" \
        > "$(_reaper_xvfb_marker "$n")" 2>/dev/null
      break
    fi
    # lost the race for that number, or the server died: try the next one, and
    # do NOT leave the number burned behind us.
    _reaper_kill "$xpid" && _reaper_drop_stale_lock "$n"
    xpid=""
  done
  if [ -z "$dpy" ]; then
    _reaper_say "could not start a private Xvfb on any of :101..:160"
    return 127
  fi
  # The parent had no trap at all: SIGKILL the two suite shells and the server
  # they were sitting on outlived them, with its lock, forever. Measured, twice,
  # by two reviewers. The previous traps are saved and restored, so this cannot
  # quietly disarm a caller that had its own.
  local prev_exit prev_int prev_term rc=0
  prev_exit=$(trap -p EXIT); prev_int=$(trap -p INT); prev_term=$(trap -p TERM)
  trap '_reaper_private_xvfb_teardown' EXIT
  trap '_reaper_private_xvfb_teardown; exit 130' INT
  trap '_reaper_private_xvfb_teardown; exit 143' TERM
  DISPLAY="$dpy" XSCHEM_REAPER_OWNED_DISPLAY="$dpy" \
    XSCHEM_REAPER_OWNED_XVFB_PID="$xpid" "$@" || rc=$?
  _reaper_private_xvfb_teardown
  trap - EXIT INT TERM
  eval "${prev_exit:-}"; eval "${prev_int:-}"; eval "${prev_term:-}"
  return "$rc"
}

# Private displays whose owning run is provably dead — the SIGKILL path for the
# process class the original stray belonged to. Run at suite start, next to
# reaper_sweep_orphan_panels.
#
# Provenance again, never a name and never a heuristic: only servers this
# launcher started have a marker, the marker names the owner, and the owner is
# either alive (hands off) or gone. A dev display started by devdisplay.sh has
# no marker and can never be selected; neither can :0; and the band is
# :101..:160 by construction. A stale lock with no server behind it is dropped
# in the same pass, because that is the other half of the leak — the number
# stays burned even after the server is gone.
reaper_sweep_orphan_xvfb() {
  local m n x op ost cur n_k=0 n_l=0 d
  for m in "${TMPDIR:-/tmp}"/.reaper_xvfb.*; do
    [ -e "$m" ] || continue
    n=${m##*.reaper_xvfb.}
    case "$n" in ''|*[!0-9]*) continue ;; esac
    read -r x op ost < "$m" 2>/dev/null || continue
    case "$op" in ''|*[!0-9]*) continue ;; esac
    if _reaper_alive "$op"; then
      cur=$(_reaper_starttime "$op")
      [ -z "$ost" ] || [ "$cur" = "$ost" ] && continue    # a live run owns it
    fi
    d=":$n"
    case "$d" in :0) continue ;; esac
    for cur in $(_reaper_devdisplays); do
      [ "$cur" = "$d" ] && continue 2
    done
    if _reaper_is_xvfb "$x" "$d"; then
      _reaper_kill "$x" && n_k=$((n_k + 1))
    fi
    rm -f "$m" 2>/dev/null
    _reaper_drop_stale_lock "$n" && [ ! -e "/tmp/.X$n-lock" ] && n_l=$((n_l + 1))
  done
  # Locks with no marker and no server: the numbers burned before markers
  # existed. Nothing is signalled here — a lock is a file, not a process.
  for n in $(seq 101 160); do
    [ -e "/tmp/.X$n-lock" ] || continue
    _reaper_x_listening "$n" && continue
    _reaper_drop_stale_lock "$n" && n_l=$((n_l + 1))
  done
  _REAPER_SWEPT_X="$n_k"
  [ "$n_k" -gt 0 ] && _reaper_say "swept $n_k orphaned private display(s) whose run is dead"
  [ "$n_l" -gt 0 ] && _reaper_say "dropped $n_l stale X lock(s)"
  return 0
}

reaper_swept_xvfb() { printf '%s' "$_REAPER_SWEPT_X"; }

# reaper_sweep_orphan_runs <dir-glob> [pidfile ...]
#
# The same proof, for a suite that keeps its processes' pids in files inside its
# own scratch STATE DIR rather than in argv — test_devdisplay.sh, whose stray
# was an `Xvfb :95 -screen 0 1920x1080x24` and its openbox, alive for a day. A
# state dir is claimed with reaper_mark_owner; if the stamp names a dead run,
# the pids it recorded are strays and the dir is rubbish.
#
# An unstamped dir is never touched: it may predate this mechanism, or belong to
# something else entirely. The dir must be under a temp root, checked here and
# not assumed from the glob.
reaper_sweep_orphan_runs() {
  local glob="${1:-}" ; shift || true
  local d f p n=0
  [ -n "$glob" ] || return 0
  for d in $glob; do
    [ -d "$d" ] || continue
    case "$d" in
      /tmp/?*|/var/tmp/?*) ;;
      "${TMPDIR:-/nonexistent-tmpdir}"/?*) ;;
      *) continue ;;
    esac
    _reaper_owner_state "$d"; [ $? -eq 1 ] || continue    # only "provably dead"
    for f in "$@"; do
      [ -r "$d/$f" ] || continue
      p=$(tr -d ' \t\n' < "$d/$f" 2>/dev/null)
      case "$p" in ''|*[!0-9]*) continue ;; esac
      _reaper_alive "$p" || continue
      _reaper_kill "$p" && n=$((n + 1))
    done
    rm -rf "$d" 2>/dev/null
  done
  [ "$n" -gt 0 ] && _reaper_say "swept $n process(es) of a dead run's state dir"
  return 0
}
