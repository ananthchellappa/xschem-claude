# Issue 0064 — Library Manager mutations (git / create / rename / delete / copy) are not logged

**Opened:** 2026-07-02
**Status:** FIXED 2026-07-14 (issue 0071 atom 7) — the 14 mutating `libmgr::do_*`
workers self-log `[list]`-built replayable call lines on their success arm (see §5);
locked by a `test_selflog_grep_guard` S1 row; tested by
`tests/headless/test_libmgr_mutation_log.tcl`.
**Severity:** MED — these operations mutate on-disk libraries, `library.defs`,
and git history, but only the *dialog-open* is logged. High blast radius, low
frequency.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/library_git.tcl`, `src/library_defs.tcl` (both contain **zero**
`log_action` — verified), `src/library_manager.tcl`; `xschem library_manager`
(`scheduler.c:4509`).
**Related:** [[action-logging]], [[library-manager]], [[library-git]],
[[lcv-save-as]]; issue 0055 (locate arg, FIXED); umbrella 0071.

---

## 1. Symptom

`Tools → Library Manager` open logs `xschem library_manager` (correct). But every
*action taken inside* the manager — git check-in, checkout, revert; create/rename/
delete/copy of a cell, view, or library; cross-library move; unregister — mutates
the filesystem/git and writes **nothing** to the action log or CIW.

## 2. Root cause

The Library Manager runs entirely in Tcl and never calls the `xschem log_action`
bridge. `library_git.tcl` and `library_defs.tcl` have no `log_action` calls;
`library_manager.tcl` logs only the load/open paths (:442/:445/:519) inherited
from the File-menu open hooks.

## 3. Scope — unlogged mutating operations

- **git** (`library_git.tcl`): check-in cell/view/lib (:214), checkout (:276),
  cancel-checkout / revert (:287).
- **create** (`library_defs.tcl`): new cell (:579), new view (:701), new library
  (:606).
- **rename**: cell (:536), view (:664).
- **delete**: cell (:407), view (:424) — moves to trash.
- **copy**: cell (:481), view (:680).
- **move / register**: cross-library move (:542), unregister (:626).

## 4. Fix sketch

Give the Library Manager operations replayable command forms and log them —
either expose `xschem library_manager <op> <lcv> …` subcommands that both perform
and log (extending the `library_manager` branch that issue 0055 already taught to
carry its argument), or call the `xschem log_action` Tcl bridge at each mutating
site. Note: many of these touch git/disk outside the schematic model, so "replay"
means re-running the library op, not re-editing a buffer — scope accordingly.

## 5. Resolution (2026-07-14, issue 0071 atom 7)

Fixed via the second route, narrowed to one seam: each of the **14 mutating
`libmgr::do_*` workers** in `library_manager.tcl` (the dialog-free layer the file
documents as its testable seam) logs on its **success arm only**, just before
`return 1`:

```tcl
xschem log_action [list libmgr::do_<op> <args...>]
```

The replayed line re-runs the library op through the same worker (headless-safe:
`refresh_after` early-returns without `.libmgr`, `libmgr::status` is catch-guarded,
the file is sourced unconditionally at startup). Dialog Cancels divert before do_*;
backend errors are caught to `return 0` — neither leaves a line. The
`library_defs.tcl` / `library_git.tcl` primitives stay silent (shared sub-steps —
cross-library rename composes copy+delete; `lib_git_restore` is cancel-checkout's
internal step). `[list]` keeps free-text commit messages (braces/newlines)
source-able. Full rationale + replay caveats: audit doc §10
(`doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md`)
and the ACTION LOG comment at the seam in `library_manager.tcl`.

Locked by `test_selflog_grep_guard.tcl` twice (the lines are S2-invisible since they
don't start with `"xschem "`): a line-anchored S1 row pinning ≥14 sites (comments
don't count) and an S1b closure scan enumerating every `proc libmgr::do_*` — a new
unlogged mutating worker fails closed. Adversarial review also surfaced (and this fix
closed) a real headless bug: `refresh_after`'s bare `winfo` guard *errored* without
Tk, AFTER the backend mutation, so a `--nogui` session mutated disk with no line and
a log replay aborted mid-file; the guard is now
`[info commands winfo] eq {} || ![winfo exists .libmgr]`. Tested by
`tests/headless/test_libmgr_mutation_log.tcl` (75 checks, in full_audit logdir_tests,
incl. a `--nogui` child section locking that guard), sabotage-verified ×6. Still out
of scope: `libmgr::place_symbol` (0069 gesture class), the NHSE editor (0065).
