# Issue 0064 — Library Manager mutations (git / create / rename / delete / copy) are not logged

**Opened:** 2026-07-02
**Status:** OPEN — identified by the action-log coverage audit; not yet fixed.
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
