#!/bin/bash
# test_home.sh -- give a test driver a THROWAWAY HOME, so a documented test run
# never writes into the tester's real one.
#
# WHY THIS EXISTS (doc/claude/outsider_fixes_batch, Item 2; DECISIONS D4-D7, D13)
#
# No driver used to point the tests at a throwaway home, so run_suites.sh,
# full_audit.sh and gated_xschem.sh overwrote the tester's xschem clipboard
# (~/.xschem/.clipboard.sch), same-named netlists in ~/.xschem/simulations and
# saved window positions, and openbox on the private display arm wrote
# ~/.cache/openbox. Setting HOME for the whole driver process -- once, here,
# before anything else runs -- moves every one of those writes, including the
# ones made by children nobody lists (xschem, ngspice, git, openbox).
#
# The Tcl side of the same contract is `t1_arm_home` in tests/test_utility.tcl.
# The two must stay identical in behaviour: the pattern, `.owner`, the nesting
# rule, the handoff and the sweep below are all shared, and a throwaway armed by
# either language is recognised as nested by the other. Section L of
# tests/headless/test_home_isolation.tcl feeds the SAME inputs to both helpers
# and requires the same verdict. Two differences are deliberate and are not
# contract: the refusal exit code (2 here, where run_suites.sh already means
# "Stop pressed" by 3; 3 in Tcl, where CLAUDE.md gives T1's rc 2 a retired
# meaning) and the stream of the routine lines (stderr here, like the display
# arm's; stdout in Tcl, where a golden case's stderr becomes an exec error).
#
# USAGE, from a bash driver's top, BEFORE `. xvfb_arm.sh`:
#     . "$HERE/test_home.sh"
#     test_home_arm || exit $?
#
# It must come before xvfb_arm so that openbox on the private Xvfb arm, and the
# xvfb-run re-exec of the driver, both inherit the throwaway (D4).
#
# A POSIX sh script cannot source this file (it is bash). It re-execs THROUGH it
# instead, once, guarded by its parent's pid (D13.1: run.sh, run_nogui.sh):
#     [ "${XSCHEM_TEST_HOME_WRAPPED:-}" = "$PPID" ] ||
#       exec bash "$here/test_home.sh" --run sh "$0" "$@"
#     unset XSCHEM_TEST_HOME_WRAPPED
# `--run` arms, runs the command as a CHILD (never exec: exec never runs the EXIT
# trap that deletes the throwaway), and exits with its status. The standalone
# display suites do the same through `xvfb_arm.sh --arm`, which arms here too.
#
# INTERFACE
#   XSCHEM_TEST_HOME       unset/empty  a fresh throwaway, deleted at exit (DEFAULT)
#                          real         leave HOME alone; a loud banner on every run
#                          <abs dir>    use that directory as HOME; never deleted.
#                                       Fully resolved first, symlinks included:
#                                       one that resolves to your real HOME is
#                                       REFUSED (D13.5), and so is one whose
#                                       .xschem, .cache or .claude -- or an entry
#                                       in them, two levels deep in .xschem --
#                                       resolves into your real HOME (D17.5, D20.4)
#   XSCHEM_TEST_KEEP_HOME  1            keep the throwaway and print its path; the
#                                       `.keep` marker is written AT ARM TIME, so a
#                                       killed run's home is kept too (D13.9)
#   XSCHEM_TEST_REAL_HOME  set BY this file: the tester's real home, a PATH and
#                          nothing else. A value that is not an absolute,
#                          existing, non-throwaway directory is REFUSED.
#
# THE RULES (D5, D13), each one a line that can otherwise delete something live:
#   * The throwaway is mktemp -d "${TMPDIR:-/tmp}/xschem-test-home.<ownerpid>.XXXXXX".
#     If that fails, or yields the real HOME or an ancestor of it, the run is
#     REFUSED. It never falls back to the real HOME.
#   * `.owner` holds ONE line, `<pid> <boot_id> <pidns>` (D13.6): the owner's
#     pid, /proc/sys/kernel/random/boot_id, and the link text of
#     /proc/<pid>/ns/pid -- each `-` where it cannot be read. A reader takes the
#     FIRST field as the pid; a one-field `.owner` (the round-1 format) reads as
#     `<pid> - -`. `.xschem` is pre-created mode 700 (F25: 16 parallel xschem
#     starts on an empty HOME lose the mkdir race).
#   * A RELATIVE TMPDIR is made absolute -- and exported absolute -- before
#     anything is created under it (D17.3): the drivers change their cwd, so a
#     relative one names a different directory a moment later.
#   * NESTED means ALL of: HOME is an existing directory named
#     xschem-test-home.<pid>.*, DIRECTLY UNDER THE TEMP ROOT (D17.4: the fresh
#     arm and the handoff both require it, and a forged throwaway-shaped
#     directory inside the real home must not pass for one), its .owner names
#     an owner that is ALIVE by the D13.6 rule below (not from another boot,
#     not from another pid namespace, and its pid alive), and
#     XSCHEM_TEST_REAL_HOME is set -- and nothing in it leads into the real home
#     (D20.4, the custom-home check of D17.5). A nested run reuses HOME, never creates or
#     deletes, and SAYS NOTHING: the arm that made the home already said where
#     it is (D17.9; Tcl's nested arm was always silent). Anything short of all
#     of them is a fresh arm.
#   * Only the owner deletes, from its EXIT trap, and only the exact path it
#     created, after re-checking it is under the temp root, matches the pattern
#     and is not the real HOME.
#   * The xvfb-run re-exec cannot run the owner's EXIT trap (exec never does),
#     so ownership is HANDED OFF: xvfb_arm exports XSCHEM_TEST_HOME_HANDOFF=<pid>
#     immediately before its exec, and the re-exec'd driver takes ownership only
#     if that pid is its parent or grandparent, matches .owner, AND
#     /proc/<pid>/cmdline shows it is NOW RUNNING xvfb-run -- i.e. the exec
#     really happened (D13.8). A child merely handed the variable is refused.
#   * A fresh arm sweeps DEAD throwaways older than 300 s, same uid, no `.keep`.
#     DEAD (D13.6): the boot_id differs from the current one; or the boot_id AND
#     the pidns both match the sweeper's own and the pid is not alive. A
#     matching boot_id with a DIFFERENT pidns (a container, bwrap, flatpak) is
#     never swept unless the entry is older than 7 days. Where a field is `-`,
#     the old rule (pid not alive) applies for that field.
#   * The sweep kills only what it can IDENTIFY (D13.7): a recorded Xvfb
#     (.xvfb.pid) or window manager (.xvfb/wm.pid, named by .xvfb/wm) only if
#     argv[0] names that program AND the HOME in /proc/<pid>/environ is exactly
#     the dead throwaway's path; a gate panel only by a cmdline naming that
#     exact gate dir.
#
# WHAT IS CARRIED from the real home (D7), each only if not already set:
#   XSCHEM_TEST_REAL_HOME   always
#   XSCHEM_DEVDISPLAY_DIR   always (read to ATTACH; nothing here creates it)
#   GUI_GATE_DIR            ONLY if $REAL/.claude/gui_test_gate already exists;
#                           otherwise the gate resolves inside the throwaway
#   XAUTHORITY              only if $REAL/.Xauthority exists
#   XDG_{CACHE,CONFIG,DATA,STATE}_HOME   repointed into the throwaway ONLY if
#                           already set (the originals ride in
#                           XSCHEM_TEST_PRE_XDG_*_HOME, which the Tcl side reads)
#   git safe.directory      GIT_CONFIG_KEY_<n>/VALUE_<n>, appended at n=GIT_CONFIG_COUNT
#                           (command scope, so it imports none of the tester's own
#                           git config; an identical entry is not stacked twice)
#
# THE PRE-SWITCH ENVIRONMENT IS A SNAPSHOT (D13.16). The outermost arm records the
# environment exactly as it was before arming, every XSCHEM_TEST_* removed, in
# XSCHEM_TEST_PRE_ENV (base64 of the NUL-separated NAME=VALUE list). A long-lived
# process that must outlive the run -- the shared gate panel, gui_gate.sh
# _gate_panel_env -- is started from THAT, plus the current DISPLAY, so it
# inherits none of the harness variables (XSCHEM_TEST_*, the GIT_CONFIG_* entry,
# a carried XSCHEM_DEVDISPLAY_DIR/GUI_GATE_DIR/XAUTHORITY the tester had not set).
# A nested arm or a handoff keeps the outer snapshot; so does an arm under an
# enclosing one (XSCHEM_TEST_REAL_HOME already set on entry).
#
# Spec: doc/claude/outsider_fixes_batch/DECISIONS.md D4-D7, D13.

# The one shape a throwaway has. mktemp's XXXXXX is [A-Za-z0-9].
_TH_NAME_RE='^xschem-test-home\.([0-9]+)\.[A-Za-z0-9]+$'
_TH_SWEEP_AGE=300
_TH_FOREIGN_NS_AGE=604800     # 7 days (D13.6)
# Above this the snapshot is not exported: a single environment string past
# MAX_ARG_STRLEN (128 KiB) makes EVERY later exec fail with E2BIG.
_TH_PRE_ENV_MAX=65536

_th_say()  { echo "test home: $*" >&2; }
# LOUD, and deliberately not prefixed like the routine line (see xvfb_arm.sh
# on why a warning you routinely filter is not a warning).
_th_warn() { echo "!! test home: $*" >&2; }

# pid alive? Where liveness cannot be established the answer is "alive": the
# failure direction must always be "a leftover survives", never "a live run's
# home is deleted".
_th_pid_alive() {
  local p="${1:-}"
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  if [ -d /proc/self ]; then
    [ -d "/proc/$p" ]
    return
  fi
  kill -0 "$p" 2>/dev/null && return 0
  # EPERM (another uid's live process) is not "dead"
  kill -0 "$p" 2>&1 | grep -qi 'no such process' && return 1
  return 0
}

_th_is_name() { [[ "$1" =~ $_TH_NAME_RE ]]; }

# Physical path of an existing directory, or fail. `cd` follows EVERY symlink,
# the last component's included -- which Tcl's `file normalize` does not (D13.5).
_th_phys() { ( cd "$1" 2>/dev/null && pwd -P ); }

# Does any component of $1 look like a throwaway?
_th_path_has_throwaway() {
  local p="$1" c
  local IFS=/
  for c in $p; do _th_is_name "$c" && return 0; done
  return 1
}

# Every symlink followed, the last component's included, and the target NEED
# NOT EXIST (a dangling link into the real home is still a link into it).
# `readlink -m` is GNU; elsewhere an existing path is resolved by _th_phys.
_th_resolve_any() {
  local r
  r=$(readlink -m -- "$1" 2>/dev/null) && [ -n "$r" ] && { printf '%s' "$r"; return 0; }
  _th_phys "$1"
}

# The physical directory CONTAINING <dir>, or fail.
_th_parent_phys() {
  local p
  p=$(_th_phys "$1") || return 1
  p="${p%/*}"
  printf '%s' "${p:-/}"
}

# The temp root, ${TMPDIR:-/tmp}, without a trailing slash.
_th_root() {
  local r="${TMPDIR:-/tmp}"
  r="${r%/}"
  printf '%s' "${r:-/}"
}

# D17.3: a RELATIVE TMPDIR names a different directory from every cwd, and these
# drivers change theirs (run_suites.sh and gated_xschem.sh cd to the repository
# root, D13.3). The round-2 safety refuter measured it: HOME exported as a
# relative path, re-pointed by that cd, the run dead ('binary never reported'),
# and the throwaway left in the caller's cwd -- permanent litter in the real
# home when the caller stood there. So TMPDIR is made absolute, and EXPORTED
# absolute, before anything is created under it: every child, and the
# re-exec'd driver's takeover, then name the same directory. Fails, changing
# nothing, if it names no directory from here.
_th_abs_tmpdir() {
  local t="${TMPDIR:-}" a
  case "$t" in ''|/*) return 0 ;; esac
  a=$(cd -- "$t" 2>/dev/null && pwd) || return 1
  export TMPDIR="$a"
}

# D17.5 + D20.4: does anything the harness WRITES under home <dir> resolve into
# the real home <real>? xschem writes under .xschem (the clipboard, simulations/,
# geometry), openbox under .cache (openbox/), the gate under .claude
# (gui_test_gate/), so each of those is checked -- the directory itself, every
# entry in it, and for .xschem the entries one level further down, where
# simulations/clean.spice lives. So such a "copy of someone's configuration"
# writes the tester's OWN files while the banner says the HOME is untouched:
# measured by the round-2 safety refuter with a symlinked .xschem, and by the
# round-3 one with a symlinked .cache (openbox wrote the real .cache/openbox)
# and with symlinked simulations/{clean,short}.spice (both overwritten).
#   Only a SYMLINK can lead out -- every entry examined sits in a real
# directory of <dir>, or in one a symlink already checked leads to -- so only
# symlinks are resolved: cheap on a large simulations/. Allowed only where <dir>
# is itself inside the real home and the entry stays inside <dir> -- the case
# the banner already announces as writing there. Prints the offender.
#   Used for a custom home (XSCHEM_TEST_HOME=<dir>) AND, since D20.4, for a
# nested one: a throwaway-shaped HOME planted under the temp root whose .xschem
# leads into the real home was reused as nested, and wrote there.
_th_custom_escapes() {
  local dir="$1" real="$2" cp rp x xr top
  local -a c
  cp=$(_th_phys "$dir") || return 1
  rp=$(_th_phys "$real" 2>/dev/null || printf '%s' "$real")
  for top in .xschem .cache .claude; do
    # an unmatched glob stays literal and fails the -L test below
    c=("$dir/$top" "$dir/$top"/* "$dir/$top"/.[!.]* "$dir/$top"/..?*)
    [ "$top" = .xschem ] && c+=("$dir/$top"/*/* "$dir/$top"/*/.[!.]* "$dir/$top"/.[!.]*/*)
    for x in "${c[@]}"; do
      [ -L "$x" ] || continue
      xr=$(_th_resolve_any "$x") || continue
      case "$xr/" in "$rp"/*) ;; *) continue ;; esac
      case "$cp/" in "$rp"/*) case "$xr/" in "$cp"/*) continue ;; esac ;; esac
      printf '%s -> %s' "${x#"$dir"/}" "$xr"
      return 0
    done
  done
  return 1
}

# ---- .owner (D13.6) ---------------------------------------------------------
_th_boot_id() {
  local b
  b=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null) || b=""
  b="${b//[[:space:]]/}"
  printf '%s' "${b:--}"
}
_th_pidns() {   # link text of /proc/<pid>/ns/pid, or -
  local n
  n=$(readlink "/proc/$1/ns/pid" 2>/dev/null) || n=""
  n="${n//[[:space:]]/}"
  printf '%s' "${n:--}"
}
_th_owner_line() { printf '%s %s %s\n' "$1" "$(_th_boot_id)" "$(_th_pidns "$1")"; }

# Parse <dir>/.owner into _TH_OF_PID / _TH_OF_BOOT / _TH_OF_NS. Fails if there
# is no readable file or its first field is not a pid. Missing fields read `-`.
_th_owner_fields() {
  local a="" b="" c=""
  _TH_OF_PID="" _TH_OF_BOOT=- _TH_OF_NS=-
  [ -r "$1/.owner" ] || return 1
  { read -r a b c _ || [ -n "$a" ]; } < "$1/.owner" 2>/dev/null || return 1
  # A plain decimal pid, 1-10 digits, no leading zero -- the same test as the
  # Tcl reader (t1_home_read_owner). Anything else is NOT a pid, and the
  # caller falls back to the pid in the directory's name; read loosely, a
  # corrupt `0<pid>` would be judged dead while the name's live owner runs.
  [[ "$a" =~ ^[1-9][0-9]{0,9}$ ]] || return 1
  _TH_OF_PID="$a"; _TH_OF_BOOT="${b:--}"; _TH_OF_NS="${c:--}"
  return 0
}

# The pid .owner names (its first field), or fail.
_th_owner_of() {
  _th_owner_fields "$1" || return 1
  printf '%s' "$_TH_OF_PID"
}

# Is throwaway <dir>'s owner ALIVE by the D13.6 rule -- the NESTING test? Its
# .owner must parse, its boot_id must not be known to differ from ours, its pidns
# must not be known to differ from ours, and its pid must be alive. A home from
# another boot whose pid happens to be alive again, or one owned in another pid
# namespace (whose pid means nothing here), is NOT reused: the sweep calls the
# first dead and cannot see the second, so either could be deleted under a run
# that nested in it. A fresh arm is the safe answer -- the same rule as Tcl's
# t1_home_live_throwaway; row L13 of test_home_isolation.tcl holds the two to it.
_th_owner_alive() {
  local cboot cns me="$BASHPID"
  _th_owner_fields "$1" || return 1
  cboot=$(_th_boot_id); cns=$(_th_pidns "$me")
  if [ "$_TH_OF_BOOT" != - ] && [ "$cboot" != - ] && [ "$_TH_OF_BOOT" != "$cboot" ]; then return 1; fi
  if [ "$_TH_OF_NS" != - ] && [ "$cns" != - ] && [ "$_TH_OF_NS" != "$cns" ]; then return 1; fi
  _th_pid_alive "$_TH_OF_PID"
}

# Is the owner of throwaway <dir> DEAD, in the sweep's sense (D13.6)?
#   $1 dir   $2 the pid in its name (used when .owner is unreadable)   $3 age, s
_th_owner_dead() {
  local d="$1" npid="$2" age="$3" pid boot ns cboot cns
  if _th_owner_fields "$d"; then
    pid="$_TH_OF_PID"; boot="$_TH_OF_BOOT"; ns="$_TH_OF_NS"
  else
    pid="$npid"; boot=-; ns=-
  fi
  local me="$BASHPID"     # not inside $(...), where it would name the subshell
  cboot=$(_th_boot_id); cns=$(_th_pidns "$me")
  # a different boot: every pid it recorded is gone, whatever /proc says now
  if [ "$boot" != - ] && [ "$cboot" != - ] && [ "$boot" != "$cboot" ]; then return 0; fi
  # the same boot but ANOTHER pid namespace: its pid means nothing from here, so
  # it is presumed live -- a leftover survives -- unless it is a week old
  if [ "$ns" != - ] && [ "$cns" != - ] && [ "$ns" != "$cns" ]; then
    [ "$age" -gt "$_TH_FOREIGN_NS_AGE" ]
    return
  fi
  ! _th_pid_alive "$pid"
}

# XSCHEM_TEST_REAL_HOME carries a path and nothing else (D5): absolute, an
# existing directory, and not itself (inside) a throwaway.
_th_valid_real() {
  local r="$1"
  case "$r" in /*) ;; *) return 1 ;; esac
  [ -d "$r" ] || return 1
  _th_path_has_throwaway "$r" && return 1
  return 0
}

# A pid's parent, from /proc (no ps dependency).
_th_ppid_of() {
  local s
  s=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  s="${s##*) }"          # past "pid (comm) "; comm may contain spaces
  set -- $s              # state ppid ...
  printf '%s' "${2:-}"
}

# Does /proc/<pid>/cmdline show that process running xvfb-run? The script is
# run through its interpreter, so argv[0] OR argv[1] carries the name (D13.8).
_th_runs_xvfb_run() {
  local a0="" a1=""
  { IFS= read -r -d '' a0 && IFS= read -r -d '' a1; } < "/proc/$1/cmdline" 2>/dev/null
  [ "${a0##*/}" = xvfb-run ] || [ "${a1##*/}" = xvfb-run ]
}

_th_now() { date +%s; }

# The HOME a live process was started with, from /proc/<pid>/environ.
_th_env_home() {
  local e
  e=$( (tr '\0' '\n' < "/proc/$1/environ") 2>/dev/null | grep -m 1 '^HOME=') || return 1
  printf '%s' "${e#HOME=}"
}

# Is <pid> alive, running <prog> (argv[0]'s basename), and -- when <home> is
# given -- started with exactly that HOME (textually or physically)? This is
# the identity rule every kill in this file goes through (D13.7).
_th_is_proc() {
  local p="$1" prog="$2" home="${3:-}" a0 h
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  _th_pid_alive "$p" || return 1
  a0=$( (tr '\0' '\n' < "/proc/$p/cmdline") 2>/dev/null | head -n 1)
  [ -n "$a0" ] && [ "${a0##*/}" = "${prog##*/}" ] || return 1
  [ -n "$home" ] || return 0
  h=$(_th_env_home "$p") || return 1
  [ "$h" = "$home" ] && return 0
  [ -d "$h" ] && [ -d "$home" ] && [ "$(_th_phys "$h")" = "$(_th_phys "$home")" ]
}

# Kill <pid> only if it passes _th_is_proc <pid> <prog> [<home>].
_th_kill_if() {
  local p="$1" prog="$2" home="${3:-}" i
  _th_is_proc "$p" "$prog" "$home" || return 0
  kill "$p" 2>/dev/null
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    _th_pid_alive "$p" || return 0
    # a zombie child of ours counts as dead
    case "$(cut -d' ' -f3 "/proc/$p/stat" 2>/dev/null)" in Z) return 0 ;; esac
    sleep 0.1
  done
  kill -9 "$p" 2>/dev/null
  return 0
}

# Kill the private display recorded in throwaway <dir>, by identity only
# (D13.7): `.xvfb/wm.pid` named by `.xvfb/wm`, then `.xvfb.pid` as Xvfb -- each
# only if its environ HOME is exactly <dir>. A lock naming the killed server
# goes too, compared by CONTENT, never by number (D13.14).
#   With `defer` (the owner's own cleanup at a normal exit) a server whose
# parent is a LIVE xvfb-run is left to it: xvfb-run stops its own server the
# moment its command exits, and it runs under `set -e` -- so a server killed
# from under it turns its `kill` in clean_up into a failure and the run's exit
# status into 1 (measured once the shell path began recording its server,
# D17.7). The sweep, whose owner is dead, never defers.
_th_kill_recorded_display() {
  local d="$1" mode="${2:-}" w wn x n lk
  w=$(head -c 32 "$d/.xvfb/wm.pid" 2>/dev/null | tr -cd 0-9)
  wn=$(head -n 1 "$d/.xvfb/wm" 2>/dev/null)
  [ -n "$w" ] && [ -n "$wn" ] && _th_kill_if "$w" "$wn" "$d"
  x=$(head -c 32 "$d/.xvfb.pid" 2>/dev/null | tr -cd 0-9)
  [ -n "$x" ] || return 0
  if [ "$mode" = defer ]; then
    local xpp; xpp=$(_th_ppid_of "$x" 2>/dev/null) || xpp=""
    [ -n "$xpp" ] && _th_runs_xvfb_run "$xpp" && return 0
  fi
  if _th_is_proc "$x" Xvfb "$d"; then
    _th_kill_if "$x" Xvfb "$d"
    n=$(head -n 1 "$d/.xvfb/display" 2>/dev/null); n="${n#:}"
    case "$n" in ''|*[!0-9]*) ;; *)
      lk=$(head -c 32 "/tmp/.X$n-lock" 2>/dev/null | tr -cd 0-9)
      [ "$lk" = "$x" ] && rm -f "/tmp/.X$n-lock" 2>/dev/null ;;
    esac
  fi
  return 0
}

# Kill a gate panel whose control dir is <gatedir>, identified by its cmdline
# naming both gui_gate_widget and that exact dir -- never a shared panel.
_th_kill_panel_in() {
  local gd="$1" f p c i
  for f in "$gd/widget.pid" "$gd/widget.launching"; do
    [ -f "$f" ] || continue
    p=$(head -c 64 "$f" 2>/dev/null); p="${p%% *}"
    case "$p" in ''|*[!0-9]*) continue ;; esac
    _th_pid_alive "$p" || continue
    c=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
    case "$c" in *gui_gate_widget*"$gd"*) ;; *) continue ;; esac
    kill "$p" 2>/dev/null
    for i in 1 2 3 4 5 6 7 8 9 10; do _th_pid_alive "$p" || break; sleep 0.1; done
    _th_pid_alive "$p" && kill -9 "$p" 2>/dev/null
  done
  return 0
}

# Is <dir> a throwaway we may delete? Under the temp root (physically), the
# name pattern, same uid, not a symlink, and not any home we know of.
_th_deletable() {
  local d="$1" root_phys="$2" parent_phys dphys
  [ -n "$d" ] && [ -d "$d" ] && [ ! -L "$d" ] && [ -O "$d" ] || return 1
  _th_is_name "${d##*/}" || return 1
  parent_phys=$(_th_phys "${d%/*}") || return 1
  [ -n "$root_phys" ] && [ "$parent_phys" = "$root_phys" ] || return 1
  dphys=$(_th_phys "$d") || return 1
  [ "$dphys" != "/" ] || return 1
  local h
  for h in "${XSCHEM_TEST_REAL_HOME:-}" "${_TH_REAL:-}" "${_TH_ORIG_HOME:-}"; do
    [ -n "$h" ] || continue
    [ "$dphys" = "$(_th_phys "$h" 2>/dev/null || printf '%s' "$h")" ] && return 1
    # an ancestor of a real home is never a throwaway
    case "$(_th_phys "$h" 2>/dev/null || printf '%s' "$h")/" in "$dphys"/*) return 1 ;; esac
  done
  return 0
}

# Sweep dead throwaways under the temp root (D5, D13.6, D13.7). Same contract as
# sweep_dead_run_dirs: where liveness cannot be established, nothing is swept.
_th_sweep() {
  local root="$1" root_phys d mt now age swept=""
  [ -d /proc/self ] || return 0
  root_phys=$(_th_phys "$root") || return 0
  now=$(_th_now)
  for d in "$root"/xschem-test-home.*; do
    [ -d "$d" ] && [ ! -L "$d" ] && [ -O "$d" ] || continue
    [[ "${d##*/}" =~ $_TH_NAME_RE ]] || continue
    local npid="${BASH_REMATCH[1]}"
    # kept on purpose (XSCHEM_TEST_KEEP_HOME=1, by either language): never swept
    [ -e "$d/.keep" ] && continue
    mt=$(stat -c %Y "$d" 2>/dev/null) || continue
    age=$((now - mt))
    [ "$age" -gt "$_TH_SWEEP_AGE" ] || continue
    _th_owner_dead "$d" "$npid" "$age" || continue
    _th_kill_recorded_display "$d"
    _th_kill_panel_in "$d/.claude/gui_test_gate"
    _th_deletable "$d" "$root_phys" || continue
    rm -rf -- "$d" 2>/dev/null && swept="$swept ${d##*/}"
  done
  [ -z "$swept" ] || _th_say "swept dead throwaway(s):$swept"
  return 0
}

# D13.16: record the environment as it is BEFORE arming, XSCHEM_TEST_* removed.
# Only the outermost arm records it: under an enclosing arm (XSCHEM_TEST_REAL_HOME
# already set on entry, the caller says so in $1) an inherited snapshot is the
# enclosing arm's and is kept.
_th_snapshot_env() {
  local enclosed="$1" s
  if [ "$enclosed" = 1 ] && [ -n "${XSCHEM_TEST_PRE_ENV:-}" ]; then return 0; fi
  s=$(env -0 2>/dev/null | grep -z -v '^XSCHEM_TEST_' | base64 | tr -d '\n') || s=""
  if [ -z "$s" ] || [ "${#s}" -gt "$_TH_PRE_ENV_MAX" ]; then
    unset XSCHEM_TEST_PRE_ENV
    [ -n "$s" ] && _th_warn "note: the environment is too large to snapshot (${#s} B encoded); a shared gate panel gets HOME and XDG_* restored instead"
    return 0
  fi
  export XSCHEM_TEST_PRE_ENV="$s"
}

# Carry the harness paths from the real home (D7). Each only if not already
# set; XDG_* repointed into <home> only if already set.
_th_carry() {
  local real="$1" home="$2" repo v n sub
  export XSCHEM_TEST_REAL_HOME="${XSCHEM_TEST_REAL_HOME:-$real}"
  [ -n "${XSCHEM_DEVDISPLAY_DIR:-}" ] || \
    export XSCHEM_DEVDISPLAY_DIR="$real/.claude/xschem_dev_display"
  if [ -z "${GUI_GATE_DIR:-}" ] && [ -d "$real/.claude/gui_test_gate" ]; then
    export GUI_GATE_DIR="$real/.claude/gui_test_gate"
  fi
  if [ -z "${XAUTHORITY:-}" ] && [ -f "$real/.Xauthority" ]; then
    export XAUTHORITY="$real/.Xauthority"
  fi
  for v in CACHE:.cache CONFIG:.config DATA:.local/share STATE:.local/state; do
    n="XDG_${v%%:*}_HOME"; sub="${v#*:}"
    [ -n "${!n+x}" ] || continue
    local pre="XSCHEM_TEST_PRE_$n"
    [ -n "${!pre+x}" ] || export "$pre=${!n}"
    export "$n=$home/$sub"
  done
  # git safe.directory as COMMAND-scope config, APPENDED so a GIT_CONFIG_COUNT
  # the tester already uses survives (the same rule as t1_arm_home), and not
  # stacked twice by a nested arm.
  repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd -P)
  local gn="${GIT_CONFIG_COUNT:-0}" i k val have=0
  case "$gn" in ''|*[!0-9]*) gn="" ;; esac
  if [ -n "$repo" ] && [ -n "$gn" ]; then
    i=0
    while [ "$i" -lt "$gn" ]; do
      k="GIT_CONFIG_KEY_$i"; val="GIT_CONFIG_VALUE_$i"
      [ "${!k:-}" = safe.directory ] && [ "${!val:-}" = "$repo" ] && have=1
      i=$((i + 1))
    done
    if [ "$have" = 0 ]; then
      export "GIT_CONFIG_KEY_$gn=safe.directory" "GIT_CONFIG_VALUE_$gn=$repo"
      export GIT_CONFIG_COUNT=$((gn + 1))
    fi
  fi
}

# The owner's EXIT handler. Runs in the owner only ($BASHPID, not $$: a
# subshell shares $$ with its parent). Idempotent: a second call finds nothing.
_th_cleanup() {
  [ -n "${_TH_PATH:-}" ] || return 0
  [ "${BASHPID}" = "${_TH_OWNER_PID:-}" ] || return 0
  local th="$_TH_PATH" own
  # gui_gate.sh installs its own EXIT trap only when none exists, and this one
  # is installed first; so its cleanup is run from here.
  type gate_finish >/dev/null 2>&1 && gate_finish
  own=$(_th_owner_of "$th") || own=""
  if [ "$own" != "$BASHPID" ]; then
    _th_warn "NOT deleting $th: its .owner names pid ${own:-<none>}, not this run ($BASHPID)"
    _TH_PATH=""
    return 0
  fi
  _TH_PATH=""
  # The WM xvfb_arm started on the private arm runs under this HOME and must
  # die with the run, or it writes into a deleted home. After xvfb_arm's exec
  # it is a direct child of THIS process; check that before killing anything.
  local wm="${XSCHEM_XVFB_WM_PID:-}"
  case "$wm" in ''|*[!0-9]*) ;; *)
    if [ "$(_th_ppid_of "$wm")" = "$BASHPID" ]; then
      _th_kill_if "$wm" "${AUDIT_WM:-openbox}" "$th"
    fi ;;
  esac
  # A gate panel launched into a gate dir INSIDE this home (the real one did
  # not exist, D7) is this run's alone and must not outlive it.
  _th_kill_panel_in "$th/.claude/gui_test_gate"
  _th_kill_recorded_display "$th" defer
  if [ "${XSCHEM_TEST_KEEP_HOME:-0}" = 1 ]; then
    # `.keep` was written at arm time (D13.9); this only re-asserts it.
    : > "$th/.keep" 2>/dev/null
    _th_say "kept $th (XSCHEM_TEST_KEEP_HOME=1); nothing sweeps it, so delete it yourself"
    return 0
  fi
  if ! _th_deletable "$th" "${_TH_ROOT_PHYS:-}"; then
    _th_warn "NOT deleting $th: it failed the re-check (temp root ${_TH_ROOT_PHYS:-?}, pattern, real home)"
    return 0
  fi
  rm -rf -- "$th" 2>/dev/null
  [ ! -e "$th" ] || _th_warn "could not fully delete $th"
  return 0
}

_th_install_trap() {
  trap '_th_cleanup' EXIT
}

# Called by xvfb_arm.sh immediately before `exec xvfb-run`: hand ownership to
# the re-exec'd driver. Only an owner hands off, and only across that exec.
test_home_handoff() {
  [ -n "${_TH_PATH:-}" ] && [ "${BASHPID}" = "${_TH_OWNER_PID:-}" ] || return 0
  export XSCHEM_TEST_HOME_HANDOFF="$BASHPID"
}

# Take ownership across the xvfb-run re-exec (D5, D13.8). Returns 0 if taken.
_th_takeover() {
  local h="$1" own gp why="" root a
  root=$(_th_root)
  case "$h" in ''|*[!0-9]*) why="not a pid" ;; esac
  if [ -z "$why" ]; then
    if [ ! -d "$HOME" ] || ! _th_is_name "${HOME##*/}"; then why="HOME is not a throwaway"
    elif [ "$(_th_phys "${HOME%/*}")" != "$(_th_phys "$root")" ]; then
      # the owner's delete re-checks "under the temp root"; a root derived from
      # HOME itself would make that check vacuous, so pin it to TMPDIR here
      # (xvfb-run does not change TMPDIR, so the pre-exec owner used this root)
      why="HOME is not under the temp root $root"
    elif ! own=$(_th_owner_of "$HOME"); then why="no .owner"
    elif [ "$own" != "$h" ]; then why=".owner names $own"
    elif [ -z "${XSCHEM_TEST_REAL_HOME:-}" ]; then why="XSCHEM_TEST_REAL_HOME unset"
    else
      gp=$(_th_ppid_of "$PPID" 2>/dev/null)
      if [ "$h" != "$PPID" ] && [ "$h" != "${gp:-x}" ]; then
        why="pid $h is neither the parent ($PPID) nor the grandparent (${gp:-?})"
      elif ! _th_runs_xvfb_run "$h"; then
        # D13.8: the exec must really have happened. A parent that merely
        # exported the variable to a child is still running itself, and its
        # live home is not the child's to delete.
        a=$( (tr '\0' ' ' < "/proc/$h/cmdline") 2>/dev/null | head -c 120)
        why="pid $h is not running xvfb-run (cmdline: ${a:-<unreadable>}), so no exec handed it over"
      fi
    fi
  fi
  if [ -n "$why" ]; then
    _th_warn "ignoring XSCHEM_TEST_HOME_HANDOFF=$h ($why)"
    return 1
  fi
  _th_owner_line "$BASHPID" > "$HOME/.owner.$BASHPID" && mv -f "$HOME/.owner.$BASHPID" "$HOME/.owner" || {
    _th_warn "could not rewrite $HOME/.owner; not taking ownership"; rm -f "$HOME/.owner.$BASHPID"; return 1; }
  _TH_PATH="$HOME"
  _TH_OWNER_PID="$BASHPID"
  _TH_REAL="$XSCHEM_TEST_REAL_HOME"
  _TH_ROOT_PHYS=$(_th_phys "$root")
  _th_install_trap
  return 0
}

# The loud banner for the opt-out, printed on EVERY run (D6).
_th_real_banner() {
  _th_warn "REAL -- XSCHEM_TEST_HOME=real: this run reads and WRITES your own HOME ($1)."
  _th_warn "       Your xschem clipboard, ~/.xschem/simulations netlists and window geometry can be overwritten."
}

# The routine armed line (D6). When TMPDIR puts the throwaway INSIDE the real
# home, "your HOME is untouched" would be false, so it says what IS true (D13.4).
_th_banner() {
  local th="$1" real="$2" thp realp
  thp=$(_th_phys "$th" 2>/dev/null || printf '%s' "$th")
  realp=$(_th_phys "$real" 2>/dev/null || printf '%s' "$real")
  case "$thp/" in "$realp"/*)
    _th_say "throwaway $th (your ~/.xschem is untouched; the throwaway lives under your HOME because TMPDIR does; XSCHEM_TEST_HOME=real to opt out)"
    return 0 ;;
  esac
  _th_say "throwaway $th (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)"
}

# test_home_arm -- the one entry point. 0 = armed; nonzero = REFUSED, and the
# caller must exit with it (the run must not proceed against the real HOME).
test_home_arm() {
  # Refuse an unset/empty HOME outright: xschem falls back to getpwuid() -- the
  # real home -- when HOME is unset, and maps "" to /.xschem.
  if [ -z "${HOME:-}" ]; then
    _th_warn "HOME is unset or empty; refusing to run (xschem would fall back to your passwd home)"
    return 2
  fi
  # XSCHEM_TEST_REAL_HOME is a PATH, never a flag. Validate it whatever the mode.
  if [ -n "${XSCHEM_TEST_REAL_HOME+x}" ] && ! _th_valid_real "$XSCHEM_TEST_REAL_HOME"; then
    _th_warn "refusing: XSCHEM_TEST_REAL_HOME='$XSCHEM_TEST_REAL_HOME' is not an absolute, existing, non-throwaway directory"
    _th_warn "          (it carries your real home's PATH and nothing else; unset it to arm afresh)"
    return 2
  fi
  # D17.3, before anything reads TMPDIR (a failure is refused below, only where
  # a throwaway has to be made under it).
  _th_abs_tmpdir
  # An enclosing arm already ran (it always exports XSCHEM_TEST_REAL_HOME).
  local enclosed=0
  [ -n "${XSCHEM_TEST_REAL_HOME:-}" ] && enclosed=1

  # 1. The xvfb-run re-exec taking ownership. The variable never outlives this
  #    check, taken or not, so no child of this process can see it.
  if [ -n "${XSCHEM_TEST_HOME_HANDOFF+x}" ]; then
    local _h="$XSCHEM_TEST_HOME_HANDOFF"
    unset XSCHEM_TEST_HOME_HANDOFF
    if _th_takeover "$_h"; then
      _th_carry "$XSCHEM_TEST_REAL_HOME" "$HOME"
      return 0
    fi
  fi

  local mode="${XSCHEM_TEST_HOME:-}" real
  real="${XSCHEM_TEST_REAL_HOME:-$HOME}"

  # 2. The opt-out.
  if [ "$mode" = real ]; then
    _th_snapshot_env "$enclosed"
    export XSCHEM_TEST_REAL_HOME="$real"
    _th_real_banner "$HOME"
    return 0
  fi

  # 3. A custom directory: used as HOME, never deleted.
  if [ -n "$mode" ]; then
    case "$mode" in /*) ;; *)
      _th_warn "refusing: XSCHEM_TEST_HOME='$mode' must be 'real' or an ABSOLUTE directory"; return 2 ;;
    esac
    if [ ! -d "$mode" ]; then
      _th_warn "refusing: XSCHEM_TEST_HOME='$mode' is not an existing directory"; return 2
    fi
    if _th_path_has_throwaway "$mode" || _th_path_has_throwaway "$(_th_phys "$mode")"; then
      _th_warn "refusing: XSCHEM_TEST_HOME='$mode' names a test throwaway; choose a directory of your own"; return 2
    fi
    if ! _th_valid_real "$real"; then
      _th_warn "refusing: HOME='$real' is itself a test throwaway and XSCHEM_TEST_REAL_HOME is not set"; return 2
    fi
    # Your real HOME is not "a copy of someone's configuration": say `real` for
    # that, which warns on every run. Compared FULLY RESOLVED -- a symlink in the
    # last component included (D13.5) -- and refused, as t1_arm_home refuses it.
    if [ "$(_th_phys "$mode")" = "$(_th_phys "$real")" ]; then
      _th_warn "refusing: XSCHEM_TEST_HOME='$mode' is your real HOME -- say XSCHEM_TEST_HOME=real for that, which also warns every run"
      return 2
    fi
    local esc
    if esc=$(_th_custom_escapes "$mode" "$real"); then
      _th_warn "refusing: XSCHEM_TEST_HOME='$mode' has $esc, inside your real HOME -- this run would write your own xschem files there. Copy the directory instead of linking it."
      return 2
    fi
    _th_snapshot_env "$enclosed"
    [ -d "$mode/.xschem" ] || mkdir -m 700 "$mode/.xschem" 2>/dev/null
    _th_carry "$real" "$mode"
    export HOME="$mode"
    # D13.4's rule, for the same reason: a custom dir INSIDE the real home is
    # written by this run, so "your HOME is untouched" would be false there.
    case "$(_th_phys "$mode")/" in "$(_th_phys "$real")"/*)
      _th_say "custom $mode (never deleted; it is inside your HOME, so this run writes there)"
      return 0 ;;
    esac
    _th_say "custom $mode (never deleted; your HOME is untouched)"
    return 0
  fi

  # 4. Nested: all four conditions, or it is not nested. Directly under the
  #    temp root (D17.4), compared physically, as the handoff compares it. And
  #    SILENT (D17.9): the arm that made this home has already printed where it
  #    is, and `owed.sh drain` running a suite that arms again printed it twice.
  #    AND NOTHING IN IT LEADS INTO THE REAL HOME (D20.4): the round-3 safety
  #    refuter planted a throwaway-shaped HOME directly under /tmp, `.owner`
  #    naming a live pid, `.xschem` a symlink into the real home -- both
  #    languages reused it as nested, and run_suites.sh overwrote the real
  #    simulations/{clean,short}.spice. An arm never makes such a home (it
  #    mkdirs .xschem), so one that has it is not a home an arm made: it is not
  #    reused, and a fresh throwaway is armed instead -- D17.4's answer too.
  if [ -d "$HOME" ] && _th_is_name "${HOME##*/}" && [ -n "${XSCHEM_TEST_REAL_HOME:-}" ]; then
    local _hp _rp _esc
    _hp=$(_th_parent_phys "$HOME" 2>/dev/null) || _hp=""
    _rp=$(_th_phys "$(_th_root)" 2>/dev/null) || _rp=""
    if [ -z "$_hp" ] || [ "$_hp" != "$_rp" ]; then
      _th_warn "note: HOME ($HOME) is named like a throwaway but is not directly under the temp root ($(_th_root)), so it is not reused; arming a fresh one"
    elif _esc=$(_th_custom_escapes "$HOME" "$XSCHEM_TEST_REAL_HOME"); then
      _th_warn "note: HOME ($HOME) is named like a throwaway but its $_esc, inside your real HOME, so it is not reused; arming a fresh one"
    elif _th_owner_alive "$HOME"; then
      _th_carry "$XSCHEM_TEST_REAL_HOME" "$HOME"
      return 0
    fi
  fi

  # 5. A fresh throwaway.
  if ! _th_valid_real "$real"; then
    _th_warn "refusing: HOME='$real' is itself a test throwaway with no live owner, and XSCHEM_TEST_REAL_HOME is not set"
    _th_warn "          (set HOME or XSCHEM_TEST_REAL_HOME to your real home)"
    return 2
  fi
  case "${TMPDIR:-/tmp}" in /*) ;; *)
    _th_warn "refusing: TMPDIR='$TMPDIR' is a relative path that names no directory from here ($(pwd)) -- set it to an absolute directory"
    _th_warn "          The run does NOT fall back to your real HOME."
    return 2 ;;
  esac
  # $BASHPID captured HERE: inside the $(mktemp ...) below it would name the
  # command-substitution subshell, and the name would disagree with .owner.
  local root th me="$BASHPID"
  root=$(_th_root)
  _th_sweep "$root"
  if ! th=$(mktemp -d "$root/xschem-test-home.$me.XXXXXX" 2>/dev/null) || [ -z "$th" ] || [ ! -d "$th" ]; then
    _th_warn "refusing: cannot create a throwaway HOME under '$root' (mktemp failed)."
    _th_warn "          Set TMPDIR to a writable directory, or XSCHEM_TEST_HOME=real to opt out."
    _th_warn "          The run does NOT fall back to your real HOME."
    return 2
  fi
  local thp realp homep
  thp=$(_th_phys "$th"); realp=$(_th_phys "$real"); homep=$(_th_phys "$HOME" 2>/dev/null || printf '%s' "$HOME")
  case "$realp/" in "$thp"/*)
    _th_warn "refusing: the throwaway '$th' is your real HOME or an ancestor of it"
    [ "$thp" = "$realp" ] || rmdir "$th" 2>/dev/null
    return 2 ;;
  esac
  case "$homep/" in "$thp"/*)
    _th_warn "refusing: the throwaway '$th' is HOME or an ancestor of it"
    [ "$thp" = "$homep" ] || rmdir "$th" 2>/dev/null
    return 2 ;;
  esac
  case "$thp/" in "$realp"/*)
    _th_warn "note: the throwaway is INSIDE your real home ($realp) because TMPDIR is; set TMPDIR elsewhere to keep it out" ;;
  esac
  if ! _th_owner_line "$me" > "$th/.owner" || ! mkdir -m 700 "$th/.xschem"; then
    _th_warn "refusing: could not initialise $th"
    rm -rf -- "$th" 2>/dev/null
    return 2
  fi
  # D13.9: kept means kept even if this run is killed before its EXIT trap.
  [ "${XSCHEM_TEST_KEEP_HOME:-0}" = 1 ] && : > "$th/.keep"
  _TH_PATH="$th"
  _TH_OWNER_PID="$me"
  _TH_REAL="$real"
  _TH_ORIG_HOME="$HOME"
  _TH_ROOT_PHYS=$(_th_phys "$root")
  _th_install_trap
  _th_snapshot_env "$enclosed"
  _th_carry "$real" "$th"
  export HOME="$th"
  _th_banner "$th" "$real"
  return 0
}

# Executed (not sourced) as the arming wrapper for a POSIX sh script, which
# cannot source this file:  bash test_home.sh --run <cmd> [args]
# Arms, runs <cmd> as a CHILD with XSCHEM_TEST_HOME_WRAPPED=<this pid> (the
# child's loop guard: it compares it with its $PPID and unsets it), and exits
# with the child's status -- after the EXIT trap has deleted the throwaway.
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${1:-}" = "--run" ]; then
  shift
  [ $# -gt 0 ] || { echo "!! test_home.sh --run needs a command" >&2; exit 2; }
  test_home_arm || exit $?
  export XSCHEM_TEST_HOME_WRAPPED="$BASHPID"
  "$@"
  _th_rc=$?
  exit "$_th_rc"
fi
