# Plan: Git revision control for the Library Manager

Branch: `library-manager`. Spec: `specs/library_git.md`.

## Difficulty: Moderate, all pure-Tcl, no rebuild

Everything is Tcl: a new `src/library_git.tcl` helper + edits to
`src/library_manager.tcl`. The C engine and the `.sch`/`.sym` record format are
untouched — same low-risk profile as the existing context-menu / read-only work,
**no `make` required**. The two genuinely fiddly parts are (a) the
listbox→treeview migration and (b) robust git-repo-topology handling (below).
Locking is descoped to what plain git natively permits.

## ⚠️ Dual git-repo support — the thing to get right

A library is a **directory**; it has **no fixed relationship** to a git repo. The
design treats these as one code path, never special-cased:

| Case | Shape | Example |
|------|-------|---------|
| **A. Standalone repo** | the library dir *is* the repo root | a user's `mylib/.git` |
| **B. Subdir of a bigger repo** | library lives deep inside a larger repo | `xschem_libraries_oa/devices` inside the **xschem** repo (the shipped reality — confirmed: `git rev-parse --show-toplevel` returns the xschem checkout, not the library dir) |
| **C. Two libraries, ONE repo** | distinct registered libs share a root | `devices` **and** `examples`, both under `xschem_libraries_oa/` in the same repo |
| **D. Libraries in DIFFERENT repos** | each lib has its own root | `devices` (repo A) + user `mylib` (repo B) |
| **E. Not under git** | no enclosing repo | graceful no-op, never errors the GUI |

**How one mechanism covers all five:** every action resolves, from the target's
**absolute path**, two values:

```
root     = git -C <abspath> rev-parse --show-toplevel   # "" => case E
pathspec = <abspath> made relative to root              # lib_git_relpath
```

then runs `git -C <root> … -- <pathspec>`.

- Because `root` is derived **from the path itself**, case A (root == library dir)
  and case B (root far above) collapse to the same two values — **no
  standalone-vs-subdir branch anywhere**.
- The `-- <pathspec>` scoping guarantees an operation on `devices` in case C
  touches **only** `devices/` files, never the sibling `examples/` nor unrelated
  files elsewhere in the bigger repo. This is what makes "Check in this library"
  safe inside a giant monorepo.
- **Multi-library operations bucket by root:** libs sharing a root (case C) become
  multiple pathspecs in **one** git call; libs in different roots (case D) get
  **separate** calls. Reports are assembled per-library and concatenated, so the
  user always sees per-library sections no matter how libs map onto repos.

This grouping is the single most important invariant in the implementation and is
covered head-on by the Phase-1 headless fixtures (A–E).

## Phases

### Phase 1 — git backend `src/library_git.tcl` (+ headless tests) ← doing now
Pure-Tcl `exec git` wrappers, `library_defs.tcl` error-throwing style. Source at
xschem.tcl:10844; add to `Makefile` (199/248) + `Makefile.in:21`.
Procs: `lib_git_available`, `lib_git_root`, `lib_git_relpath`, `lib_git_context`,
`lib_git_status_map`, `lib_git_tracked_set`, `lib_git_log`, `lib_git_commit`,
`lib_git_restore`, `lib_git_checkout`/`_cancel_checkout`/`_checkouts`, and a
path→cellview attribution helper.
Tests `tests/headless/test_library_git.tcl` with fixtures for topologies **A–E**.
**Risk:** porcelain parsing + path attribution — both fully unit-testable headless.

### Phase 2 — Maintain menubar + Show Status / History
Add a menubar (none today) with **Maintain → Show Status, History**; a shared
multi-select library picker (Ctrl+Click); reports rendered via the existing
read-only `viewdata` text window. **Risk: low.**

### Phase 3 — treeview migration (bold tracked)
Convert the 3 panes `listbox → ttk::treeview`; bold tag for tracked items. Updates
`open`, `populate_libs`, `on_lib/on_cell/on_view`, `cursel`, `ctx_post`,
`refresh_after`. **Risk: moderate-mechanical**, guarded by `test_lib_manager_ctx`.

### Phase 4 — context-menu check-in / check-out / cancel
Extend the lib/cell/view popups with *Show Checkouts*, *Check in…*, *Check out*,
*Cancel checkout*; shared commit-comment dialog; `ctx_*`/`do_*` workers (the
testable seam); live pane refresh. **Risk: low–moderate.**

### Phase 5 — tests, regression sweep, docs
Extend GUI seam tests; run full lib suite + netlist sweep; eyeball treeview +
Maintain menu; update `code_analysis/` doc + memory.

## Flagged limitations (not hidden)
- Cross-user "locked by someone" is real only under Git LFS + a lock-capable
  remote; the local model shows your own uncommitted edits and labels itself.
- Library *Check in* commits only datafiles under that library's pathspec — never
  a sibling library or unrelated monorepo files.
- `.xschem_trash/`, `~`-backing files excluded from status/attribution.
