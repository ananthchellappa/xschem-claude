#!/bin/bash
# suite_cwd.sh — WHERE A SUITE'S UNTITLED AUTOSAVE LANDS.  A sourced library;
# it starts nothing.  Issue 1486 (and 0609, 1480).
#
#   . "$HERE/suite_cwd.sh"
#   suite_cwd_arm "$REPO"        # once, after the cd to the repository root
#   d=$(suite_cwd_for "$tag")    # one private directory per run
#   ... timeout N env "PWD=$d" "$XSCHEM" --script ...
#   suite_cwd_disarm             # once, at the end
#
# WHY.  xschem names its unsaved buffer `<$PWD>/untitled.sch` and autosaves it
# to `<$PWD>/untitled~.sch` on the FIRST edit — `set_modify(1)` calls
# `write_backup()`, which backs an untitled buffer up ON PURPOSE (issue 0060:
# `go_back` restores an unsaved top level from that file, so skipping it lost
# the whole top level on descend+ascend).  `$PWD` is preferred over `getcwd()`
# because it does not dereference symlinks (`Tcl_AppInit` in src/xinit.c and
# `load_schematic` in src/save.c both resolve it that way).
#
# MEASURED, 2026-09-20, all 405 headless suites each run in a private directory
# holding a seeded `untitled~.sch`: **51 destroy it** — 34 overwrite it and 17
# delete it, and `test_add_pin_lib_symbol_view` takes `untitled~.sym` too.  No
# suite leaves anything else IN ITS WORKING DIRECTORY, so within that directory
# the untitled autosave is the whole of this class.
#
# ⚠ WHICH IS NOT THE SAME AS "THE CHECKOUT COMES OUT CLEAN", and this header said
# it was.  `backup_file_name()` puts the `~` BESIDE THE CELL, not in `$PWD`, so a
# suite that loads a checkout cell and modifies it writes that cell's `~` into the
# repository whatever `$PWD` says — the redirect below cannot reach it, and a
# sweep that only watches private working directories is structurally blind to
# it.  Nine suites do it; attributed one at a time with an mtime marker, and
# identical on the pre-1486 binary, so it is not a regression:
#   test_apply_properties_readonly, test_readonly_guard  -> xschem_library/examples/Q1~.sch
#   test_load_window_routing                             -> xschem_library/examples/dlatch~.sch
#   test_undo_link_symbols                               -> xschem_library/examples/nand2~.sch
#   test_fluid_bodyshove_guards_0132,
#   test_fluid_ortho_ctrl1_shove_0132,
#   test_fluid_ortho_second_drag_0132                    -> tests/from_user/before_10~.sch
#   test_fluid_rotate_body_route_0130,
#   test_fluid_rotate_second_drag_0132                   -> xschem_libs_newsym/SANDBOX/
#                        test_hier_descend_etc/schematic/test_hier_descend_etc~.sch
# Re-measured in the fix round: with `tests/from_user/before_10~.sch` moved away,
# `run_suites.sh --nogui test_fluid_bodyshove_guards_0132` put it back, byte-
# identical.  `git status` cannot show any of it (`*~.sch` is .gitignore:75).
# That class belongs to issues 0609/1480, not here.
#
# D13.3 moved the drivers' directory off the tester's HOME (where
# that was their own unsaved work) and onto the repository root, which is where
# the litter has been piling up since: `test_ase_core`'s C11 and
# `test_op_dump_altshow`'s H1 both assert the repo root is clean and both are
# structurally red inside `full_audit.sh` for that reason (issue 0609).
#
# SO IT IS REDIRECTED, NOT SUPPRESSED.  The autosave is a product feature, not a
# test artefact, and two of the suites (`test_backup_file`,
# `test_descend_untitled_preserve`) assert it is written.  The run therefore
# keeps **cwd = the repository root** — suites resolve fixtures against `[pwd]`,
# e.g. `test_reopen_readonly` globs `[file join [pwd] xschem_library ...]` and
# dies with `error copying "": no such file or directory` from anywhere else
# (measured) — and only `$PWD` points at a private directory.  Tcl's `pwd`
# reads `getcwd()`, so `[pwd]` is unaffected; bash re-derives `PWD` at startup,
# so a shell child is not misled either (both measured).
#
# ⚠ SUPPRESSION WAS MEASURED NOT TO WORK, so do not "simplify" this into a
# blanket `set ::autosave_backup 0`.  That guard (issue 0601, carried by nine
# suites) stops `write_backup()` but NOT `remove_backup()`, so a guarded suite
# still DELETES a pre-existing `untitled~.sch`: measured on
# `test_instance_update`, `test_paste_modify_flag_0244`,
# `test_placement_wire_gate` and `test_shape_draw_gate`, every one of which
# carries the guard and every one of which removed the seeded file.
#
# The private directory lives under `tests/headless/.scratch/` — gitignored
# (.gitignore:85), outside `full_audit.sh`'s `scratch_snapshot` globs, and named
# `_suitecwd_<pid>` so `scratch.tcl`'s dead-pid sweep collects it if the driver
# is killed before `suite_cwd_disarm`.  If that tree cannot be written (a
# read-only checkout) it falls back to `$TMPDIR`, and if that fails too the run
# proceeds with `$PWD` as it found it and says so: this must never stop a suite
# from running.

# Armed root, or empty.  Read by the three functions below and by nothing else.
# ⚠ SCRIPT-LOCAL, NOT INHERITED.  Assigned unconditionally at source time, so an
# exported SUITE_CWD_ROOT cannot silently replace the arm — and, worse, defeat the
# cleanup: measured, `SUITE_CWD_ROOT=/some/dir run_suites.sh --nogui <37 suites>`
# wrote all 33 autosaves into that directory and then printed
# `refusing to remove '…' (not a suite_cwd name)` and left them there.  The value
# is a delete target; it does not come from outside.  Issue 1486, F fix round.
SUITE_CWD_ROOT=""

# suite_cwd_arm <repo-root>.  Idempotent; returns 1 (and warns once) if no
# writable place was found, having left SUITE_CWD_ROOT empty.
#
# ⚠ NO `trap suite_cwd_disarm EXIT` HERE, DELIBERATELY.  A shell has exactly one
# EXIT trap and two other libraries already want it: `test_home.sh:590` installs
# `trap '_th_cleanup' EXIT` (which deletes the throwaway HOME) and `gui_gate.sh`
# installs `trap 'gate_finish' EXIT` *only when none exists*.  Arming a trap here
# would therefore either clobber the HOME cleanup or stop the gate from ever
# installing its own — trading a leaked scratch directory for a leaked throwaway
# home or a stuck Pause panel.  Each early exit between the arm and the disarm
# calls `suite_cwd_disarm` explicitly instead, and row S1 of
# test_untitled_autosave_1486.tcl checks every one of them, so a new exit path
# reds rather than leaking.
suite_cwd_arm() {
  [ -n "${SUITE_CWD_ROOT:-}" ] && return 0
  local repo="${1:-}" d
  if [ -n "$repo" ]; then
    d="$repo/tests/headless/.scratch/_suitecwd_$$"
    if mkdir -p "$d" 2>/dev/null; then SUITE_CWD_ROOT="$d"; return 0; fi
  fi
  if d=$(mktemp -d "${TMPDIR:-/tmp}/xs-suitecwd.$$.XXXXXX" 2>/dev/null); then
    SUITE_CWD_ROOT="$d"; return 0
  fi
  echo "note: suite_cwd -- no writable scratch; xschem's untitled~.sch stays in $(pwd)" >&2
  return 1
}

# suite_cwd_for <tag>.  Prints the directory to pass as PWD for ONE run.  A
# directory PER RUN, not one shared by the whole driver: a leftover
# `untitled.sch` would otherwise make the next suite's namer pick
# `untitled-1.sch`, i.e. make one suite's verdict depend on what ran before it.
# Falls back to the current directory (today's behaviour) if anything fails, so
# the caller can always spell `env "PWD=$(suite_cwd_for x)"` unconditionally.
suite_cwd_for() {
  local tag d
  tag=$(printf '%s' "${1:-run}" | tr -c 'A-Za-z0-9._-' '_')
  if [ -n "${SUITE_CWD_ROOT:-}" ]; then
    d="$SUITE_CWD_ROOT/$tag"
    if mkdir -p "$d" 2>/dev/null; then printf '%s' "$d"; return 0; fi
  fi
  printf '%s' "$PWD"
  return 1
}

# suite_cwd_disarm.  Removes the armed root and everything the runs left in it.
# Guarded by the name shape so a mis-set SUITE_CWD_ROOT cannot delete a tree
# nobody armed.
#
# ⚠ IT LOOKS BEFORE IT DELETES.  The private $PWD is the one place a suite can
# write that NEITHER driver's leak detector can see: `full_audit.sh` disarms
# ahead of its SCRATCH and TREE "after" snapshots, and the tree is gone by the
# time anything could look.  Today nothing is hidden — measured twice, 33 suites
# through `run_suites.sh --nogui` and 34 through a 406-suite paired sweep, and in
# both the directory held ONLY `untitled~.sch`, one per suite — but a future
# producer of a new $PWD-derived file would otherwise be swallowed unseen, which
# is the exact shape of the class this file exists to close.  So anything that is
# not an `untitled*` is named on one `SUITECWD:` line first.  That line ends in a
# parenthesis on purpose: it must not be able to end in a shape the verdict
# readers count (`FAIL`, `GOLD?`, `RESULT?`), whatever a stray file is called.
suite_cwd_disarm() {
  local d="${SUITE_CWD_ROOT:-}" _unexp _n
  SUITE_CWD_ROOT=""
  [ -n "$d" ] || return 0
  case "$d" in
    */.scratch/_suitecwd_[0-9]*|*/xs-suitecwd.[0-9]*)
      _unexp=$(cd "$d" 2>/dev/null && find . ! -type d ! -name 'untitled*' 2>/dev/null \
                 | sed 's|^\./||' | sort)
      if [ -n "$_unexp" ]; then
        _n=$(printf '%s\n' "$_unexp" | wc -l | tr -d ' ')
        echo "SUITECWD: unexpected file(s) in the private \$PWD before it was removed:" \
             "$(printf '%s\n' "$_unexp" | head -20 | tr '\n' ' ')" \
             "-- (n=$_n, issue 1486)" >&2
      fi
      rm -rf -- "$d" 2>/dev/null ;;
    *) echo "note: suite_cwd -- refusing to remove '$d' (not a suite_cwd name)" >&2 ;;
  esac
  return 0
}
