# Library Manager — Git Revision Control: Design & Decision Record

Branch: `library-manager`. Spec: `doc/claude/specs/library_git.md`. Plan:
`doc/claude/suggestions/library_git_plan.md`.
Status: **Phases 1–5 implemented, verified under the built binary, committed**
(`9070508a`). Author: implementation sessions 2026-06-21 → 2026-06-22.

This is the narrative/decision companion to the spec — the *why* behind the
choices, the traps hit, and the verification story that flat commit messages and
the spec don't preserve. It builds on the library model in
[library_manager_design.md](library_manager_design.md) (Library → Cell → View).

---

## 1. Goal

Give the Cadence-style Library Manager a **Maintain** capability backed by
**git**: see what is untracked / pending, view history, and check cells/views in
and out — without leaving xschem. The whole feature is **pure Tcl** (a new
`src/library_git.tcl` plus edits to `src/library_manager.tcl`); the C engine and
the `.sch`/`.sym` record format are untouched, so there is **no rebuild of the
engine** — only the shared Tcl is reinstalled. Same low-risk profile as the
earlier read-only / context-menu work.

---

## 2. The one invariant that carries the whole feature

A "library" in xschem is a **directory** (`library_resolve <lib>` → absolute
path) with **no fixed relationship** to a git repository. The design must handle,
as first-class and indistinguishable-to-the-user cases:

| Case | Shape |
|------|-------|
| A. standalone repo | the library dir *is* the repo root |
| B. subdir of a bigger repo | library lives deep inside a larger repo (the shipped reality: `xschem_libraries_oa/devices` inside the xschem checkout) |
| C. two libraries, ONE repo | `devices` + `examples` share a root; an op on one must not touch the other |
| D. libraries in DIFFERENT repos | each lib resolves to its own root |
| E. not under git | every action degrades gracefully, never errors the GUI |

**Decision D-GIT-1 — resolve everything from the path, never special-case.**
Every action computes, from the target's **absolute path**:

```
root     = git -C <abspath> rev-parse --show-toplevel   # "" => case E
pathspec = <abspath> made relative to root              # lib_git_relpath
```

then runs `git -C <root> … -- <pathspec>`. Because `root` is derived from the
path itself, cases A and B collapse to the same two values (the only observable
difference is what `--show-toplevel` returns). The `-- <pathspec>` scoping makes
case C safe: an op on `devices` touches only `devices/` files. Multi-library
operations **bucket by root** (`lib_git_group_by_root`): libs sharing a root → one
git call with multiple pathspecs; libs in different roots → separate calls;
reports are assembled per library and concatenated. This grouping is the single
most important correctness property and is covered head-on by the Phase-1/2
fixtures (A–E).

---

## 3. The lock / checkout model — "whatever git permits"

Plain git has **no native file-lock / checkout-lock**. So:

**Decision D-GIT-2 — local edit-lock baseline, LFS as an opportunistic upgrade.**
- Baseline (any repo, no server): **Check out** clears the view's read-only flag
  (integrates with the existing per-window `xctx->readonly` layer) and records a
  local marker under `<gitdir>/xschem_lib_checkouts`. **Show Checkouts** = your
  locally-modified-but-uncommitted views **plus** marked-but-unedited ones; the
  report **labels itself local-mode** so it is never mistaken for cross-user
  locks. **Cancel checkout** = `git checkout HEAD -- <file>` (rolls back), behind
  a confirm box.
- Upgrade: when `git lfs` is installed **and** the remote answers the lock API
  (`git lfs locks` succeeds), check-out/in/cancel also drive `git lfs
  lock`/`unlock` and Show Checkouts shows *other* users' locks. Detected at
  runtime; absent ⇒ silent local fallback.

Honest limitation (surfaced, not hidden): "locked by someone else" is real only
under LFS + a lock-capable remote. The local model shows *your* edits and says so.

---

## 4. GUI decisions

**Decision D-GIT-3 — listbox → `ttk::treeview` for the three panes.** Tk
`listbox` has no per-row font, so a "bold = revision-controlled" cue is
impossible. `ttk::treeview` supports a per-row tag font. The panes keep the same
widget paths (`.libmgr.pw.{lib,cell,view}.lb`); the **row id is the item name**,
so `[$t children {}]` is the ordered name list and select/lookup are by name —
which kept the migration mechanical and the existing tests a near-1:1 port.
A library/cell/view with any git-tracked datafile renders **bold** (`tracked`
tag, font `LibMgrBold`); `lib_git_tracked_set` drives it and degrades to "nothing
bold" off-git.

**Decision D-GIT-4 — reports via the existing read-only `viewdata` window**, and
**History as a dedicated two-pane form.** Show Status / History (Maintain menubar,
multi-select library picker) reuse `viewdata`. The richer **History** form
(`libmgr::history_dialog`, also on the cell/view/library right-click) is a
non-modal two-pane dialog: an upper scrollable `ttk::treeview` of commits (Date |
short hash | Subject, newest first) over a lower read-only message pane that
updates on selection. Backed by `lib_git_log_records` (per-commit dicts:
hash/short/date/author/subject/body, US/RS-delimited so multiline bodies survive).

**Decision D-GIT-5 — the `do_*` worker seam.** Every context action splits into a
dialog-gathering `ctx_*` and a dialog-free `do_*` worker (explicit args, calls the
backend, refreshes panes, sets the status bar, returns 1/0). The `do_*` layer is
the headless-testable seam; the modal commit-comment / confirm dialogs stay manual.

---

## 5. Verification story

**RED-first throughout.** Two test tiers, because the backend is pure Tcl:

- **tclsh (no binary, no X)** — the backend procs are path/`exec git`-based, so
  `test_library_git.tcl` (topologies A–E, status/tracked/log/commit/restore/
  checkouts), `test_library_git_report.tcl` (grouping + Status/History reports),
  and `test_library_git_history.tcl` (structured records) run under a plain
  `tclsh` sourcing `library_defs.tcl` + `library_git.tcl` directly. Fixtures live
  under `/tmp` (NOT the working tree) so case E is genuinely outside any repo.
- **X GUI (built binary)** — `test_lib_manager_{maintain,bold,checkin,history}.tcl`
  drive the real Tk surface; the modal commit dialog/picker are driven
  non-interactively via an `after` that sets `::libmgr::dlg_done`, and the
  History/viewdata output is inspected from the widget tree. Existing
  listbox-driven tests (`_ctx`, `_gui`, `_action_log_libmgr`) were ported to the
  treeview API; `test_create_instance` (the separate `.mkinst` browser) was left
  on listbox — it is **out of scope**.

**Regression gates, all green:** the netlist golden sweep
(`tests/headless/run.sh` → `HARNESS: PASS`) is the authoritative netlisting
check; `open_close` + `netlisting` core cases pass with no FAIL/GOLD?/FATAL;
all 9 GUI + 3 tclsh suites pass. (`create_save` is slow under WSLg and was not
run to completion; it exercises save/load, which this purely-additive Library
Manager Tcl does not touch — the golden netlist sweep covers that path.)

---

## 6. Lessons / traps burned in (so they don't recur)

1. **`ttk::treeview identify` needs BOTH coords.** `$lb identify item $x $y`
   (returns the row id) — a one-arg `identify row $y` misparses as the legacy
   `identify x y` form and throws *"expected integer but got row"*. The Button-3
   bindings now pass `%x %y %X %Y`; regression: CTX3b/CTX3c. Caught only via the
   real right-click path, which the original ctx tests bypassed — **test the
   coordinate seam, not just the handler.**
2. **A mid-word `"` in a Tcl list element splits on spaces.**
   `--pretty=format:"%h %s"` inside `[list …]` becomes *four* elements (literal
   quotes, space-split). Build such git format/date args from a **variable**
   (`set fmt "…"; … --pretty=format:$fmt`) so substitution keeps it one word.
   Hit twice (`lib_git_log`, `lib_git_log_records`).
3. **`git status --porcelain` collapses an untracked directory** to a single
   entry — pass `-uall` for per-cell/view granularity.
4. **`git -C <path>` needs a directory** — resolve a datafile target to its
   `[file dirname]` before `rev-parse`.

---

## 7. Phase plan, as built

1. **Backend** `library_git.tcl` (+ A–E fixtures). ✓
2. **Maintain menubar** — Show Status / History + multi-select picker → viewdata. ✓
3. **Treeview migration** — bold tracked; existing GUI tests ported. ✓
4. **Check-in/out** — check out / check in… / cancel checkout (cell+view),
   Show Checkouts / Check in… (library); commit-comment dialog; confirm boxes. ✓
5. **History form + docs + sweep** — structured `lib_git_log_records`, two-pane
   dialog on cell/view/lib menus; this document; regression sweep. ✓

---

## 8. Decision log

- 2026-06-21: D-GIT-1 (path-derived root+pathspec, no standalone/subdir branch),
  D-GIT-2 (local edit-lock baseline + opportunistic LFS), D-GIT-3 (treeview for
  bold), D-GIT-4 (viewdata reports + two-pane History), D-GIT-5 (`do_*` seam).
  Phases 1–4 implemented & verified under the built binary.
- 2026-06-22: History moved onto the cell/view/library right-click as a two-pane
  commit-selector form (`lib_git_log_records` + `history_dialog`) per user
  request; Phase 5 doc + regression sweep; committed `9070508a` (authored
  `Ananth Ch <ananth.chellappa@outlook.com>` at user's explicit instruction).
