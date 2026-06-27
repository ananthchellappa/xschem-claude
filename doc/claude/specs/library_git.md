# Spec: Git revision control in the Library Manager

Branch: `library-manager`. Status: Phases 1–4 done & verified under the built
binary (X): git backend, Maintain reports (grouping, Show Status, History),
Maintain menubar + multi-select picker → viewdata, listbox→ttk::treeview panes
with the bold `tracked` tag, and the check-out / check-in / cancel-checkout +
Show Checkouts context-menu actions (commit-comment dialog, confirm boxes,
do_* seam). All headless tclsh tests, the GUI tests
(`test_lib_manager_{bold,ctx,gui,maintain,checkin}`, `test_action_log_libmgr`,
`test_create_instance`, launch/browse) and the netlist golden sweep are green.
Phase 5 (docs + final sweep) remaining.

## 1. Goal

Give the Cadence-style Library Manager a **Maintain** capability backed by **git**,
so users can see what is untracked / pending, view history, and check cells/views
in and out — without leaving xschem. The whole feature is **pure Tcl** (a new
`library_git.tcl` plus edits to `library_manager.tcl`); the C engine and the file
record format are untouched, so there is **no rebuild**.

## 2. Dual git-topology support (the central requirement)

A "library" in xschem is a **directory** (`library_resolve <lib>` → absolute path).
That directory has **no fixed relationship** to a git repository. We MUST support, as
first-class and indistinguishable-to-the-user cases:

1. **Standalone repo** — the library directory *is* (or contains) its own `.git`,
   i.e. the library is the whole repository.
   ```
   mylib/                <- git repo root  AND  library dir
     .git/
     inv/symbol/inv.sym
     library.tag
   ```

2. **Subdirectory of a bigger repo** — the library lives deep inside a larger
   repository that holds many other things. This is the **shipped reality**:
   `xschem_libraries_oa/` is tracked inside the xschem repo itself
   (`git rev-parse --show-toplevel` = the xschem checkout, not the library dir).
   ```
   xschem/               <- git repo root
     .git/
     src/ ...             (unrelated files)
     xschem_libraries_oa/
       devices/           <- library dir (DEFINE devices ...)
       examples/          <- ANOTHER library dir, SAME repo
   ```

3. **Two (or more) libraries sharing ONE repo** — a direct consequence of case 2:
   `devices` and `examples` above are distinct registered libraries whose files
   live under the **same** repo root. Operations on one must scope to that one
   library's files and must NOT sweep the other library (nor unrelated repo files).

4. **Libraries in DIFFERENT repos** — `devices` in repo A, a user's `mylib` in
   repo B. A multi-library operation (e.g. "Show Status for devices + mylib") must
   address each library against its **own** repo root.

5. **Not under git at all** — a library on a path with no enclosing repo. Every git
   action degrades gracefully (greyed/explained), never errors out the GUI.

### 2.1 How the design satisfies all cases uniformly

Every git action resolves, for the **absolute path** of the target (library, cell,
or view):

- **repo root** = `git -C <abspath> rev-parse --show-toplevel`  → `""` if not a repo
  (case 5). This is computed *from the library/cell/view path itself*, so it is
  correct whether the root equals the library dir (case 1) or sits far above it
  (cases 2–4). Never assume `library dir == repo root`.
- **pathspec** = the target path made **relative to that root**
  (`lib_git_relpath`). All `git` commands run with `git -C <root> … -- <pathspec>`,
  so a library that is a deep subdir is scoped exactly to its own files, and the
  "bigger repo" cases 2–4 never leak into a sibling library or unrelated files.

**Grouping rule for multi-library operations:** resolve each selected library to
`{root, pathspec}`, then **bucket by root**. Libraries that share a root (case 3)
become *multiple pathspecs in one git invocation* against that root; libraries in
different roots (case 4) get separate invocations. A status/history report is
assembled per library and concatenated, so the user sees per-library sections
regardless of how they map onto repos.

**Standalone vs subdir is therefore not special-cased anywhere** — the
root+relpath resolution collapses both into the same two values. The only
observable difference is what `--show-toplevel` returns.

## 3. Lock / checkout model ("whatever git permits")

Plain git has **no native file-lock / checkout-lock** concept (it is distributed:
"locked by another user" does not exist without extra machinery). So:

- **Baseline = local edit-lock** (works on ANY git repo, no server, both topologies):
  - **Check out** = clear the view's read-only flag (integrates with the existing
    per-window `xctx->readonly` file-protection layer) + record a local marker.
  - **Show Checkouts** = the library's locally-modified-but-uncommitted views
    (your edits in this clone). The report **labels** this as local-mode so it is
    never mistaken for cross-user locks.
  - **Cancel checkout** = `git restore` the datafile(s) to HEAD (roll back edits),
    with a confirm box (destructive).
- **Opportunistic upgrade = Git LFS locks** when `git lfs` is installed AND the
  remote supports the lock API: **Check out** → `git lfs lock`, **Show Checkouts**
  → `git lfs locks` (shows *other* users too), check-in/cancel also `git lfs unlock`.
  Detected at runtime; absent ⇒ silently fall back to the local model.

## 4. User-facing surface

### 4.1 `Maintain` menubar menu (new)
The Library Manager has no menubar today (only right-click popups + a button row).
Add a real menubar with a **Maintain** cascade:

- **Show Status** — multi-select library picker (Ctrl+Click, `selectmode extended`)
  → report of **untracked** cellviews and **pending-commit** (modified/staged)
  cellviews, shown in a read-only text window (reuse `viewdata`, xschem.tcl:8670).
- **History** — same multi-select picker → `git log` of the selected libraries'
  pathspecs, shown via `viewdata`.

### 4.2 Right-click context-menu additions
- **Library menu:** *Show Checkouts*, *Check in…*, *History*
- **Cell menu** and **View menu:** *Check out*, *Check in…*, *Cancel checkout*,
  *History*
- **History** opens a non-modal two-pane form (`libmgr::history_dialog`): the
  upper scrollable `ttk::treeview` lists commits (Date | Commit hash | Subject,
  newest first); selecting a row shows that commit's full message (header +
  subject + body) in the lower read-only pane. Backed by
  `lib_git_log_records {root pathspecs}`.
- Every **check-in** pops a **commit-comment dialog** (multiline text, OK/Cancel).
  *Cancel checkout* and *Delete* get confirm boxes.

### 4.3 Bold for revision-controlled items
The three panes migrate from Tk `listbox` (no per-row font) to `ttk::treeview`
(verified to support a bold per-row tag here). A library/cell/view whose datafile
is **tracked** (`git ls-files`) renders **bold**; untracked renders normal.

## 5. Backend: `src/library_git.tcl` (new, pure Tcl)

Mirrors `library_defs.tcl` conventions (throw a Tcl error with a human message on
failure; `catch` in the GUI). Sourced at xschem.tcl:10844 (between
`library_defs.tcl` and `library_manager.tcl`); installed via `src/Makefile`
(lines ~199/248) and listed in `src/Makefile.in:21`.

Procs:
- `lib_git_available` → `{git ?lfs?}` capability flags.
- `lib_git_root {abspath}` → repo toplevel or `""` (cached per path).
- `lib_git_relpath {root abspath}` → pathspec relative to root.
- `lib_git_context {abspath}` → `{root pathspec}` (or `{}` if not under git).
- `lib_git_status_map {libpath}` → dict `cell/view → state`
  (`untracked|modified|staged|clean`), parsed from `git status --porcelain -z`,
  each changed file attributed to a cell/view by stripping the libpath prefix
  (`<cell>/<view>/<cell>.<ext>` nested, `<cell>.<ext>` flat). Excludes
  `.xschem_trash/` and `~`-backing files.
- `lib_git_tracked_set {libpath}` → set of tracked datafiles (one `git ls-files`)
  driving the bold tag.
- `lib_git_log {root pathspecs}` → formatted history text.
- `lib_git_commit {root pathspecs message}` → `git add` + `git commit -m`.
- `lib_git_restore {root pathspecs}` → revert to HEAD.
- `lib_git_checkout` / `lib_git_cancel_checkout` / `lib_git_checkouts {libpath}` —
  LFS-aware lock layer with local fallback.
- path→cellview attribution helper (shared by status, checkouts, bold).

## 6. Testing

- `tests/headless/test_library_git.tcl` — temp git-repo fixtures covering **all
  topologies in §2**: (a) library == repo root; (b) library as deep subdir of a
  bigger repo; (c) two libraries in one repo; (d) not under git. Exercise root /
  relpath resolution, status map, tracked set, log, commit, restore, and
  path→cellview attribution. RED-genuine before implementation.
- Extend `tests/headless/test_lib_manager_ctx.tcl` for the `do_*` GUI workers and
  treeview bold tagging (the existing testable seam).
- Regression: full lib suite + netlist equivalence sweep; manual eyeball of the
  treeview + Maintain menu.

## 7. Honest limitations (surfaced, not hidden)

- "Locked by someone else" is real only under LFS + a lock-capable remote; the
  local model shows your own uncommitted edits and says so in the report.
- Library-level *Check in* commits only untracked/modified datafiles **under that
  library's pathspec** — it never sweeps a sibling library or unrelated files in a
  bigger repo (the whole point of §2.1's grouping).
- `.xschem_trash/`, `~`-backing files and other non-cell artifacts are excluded
  from status/attribution.
