# 0799 — **New library** accepts a folder that is already a library, or the root that holds them all, and registers it without a word

**Status:** **FIXED on `annotate`**, 2026-08-31 — see "Fixed on `annotate`"
below for what shipped and what is still open (`[[0999]]`, `[[1200]]`, and five
decisions on the user's ruling queue). Still OPEN on `synthesis`, whose
`vimport::create_library` half does not exist here.

**The user's question**, 2026-08-30:

> *"why does library manager > New Library menu item allow a user to do
> something so stupid?"*

asked of a `DEFINE JUNK <the sky130A/xschem_libs root>` line that appeared in a
**git-tracked PDK `library.defs`** during the session that found `[[0798]]`.
**Branch:** `synthesis`. **Owner:** `src/library_defs.tcl` (`library_new`),
`src/library_manager.tcl` (`libmgr::do_new_library`), `src/xschem.tcl`
(`vimport::create_library`).
**Related:** `[[0792]]` D2/D3 (the import dialog's own `New...` and why it grew
guards), `[[0798]]` (the session this surfaced in).

> **Read this on the `annotate` branch?** This file was authored on `synthesis`
> and carried across as the brief for backlog item S5, which is why it carries a
> 07xx number inside the block `NUMBERING.md` reserves for that branch — that is
> the block doing its job, not a filing mistake, and the S5 repair pass ruled on
> 2026-08-31 that it must NOT be renumbered (renumbering gives one user complaint
> two identities and breaks the two links above, neither of which resolves here).
> `annotate` fixed the `library_new` half; `vimport::create_library` does not
> exist on this branch. What `annotate` found while fixing it is filed in its own
> range: **0995** (the folder-to-library lookup's path tidy-up had no test row),
> **0996** (two structural rows were reading a comment), **0997** (the refusal
> asked for a file named `library.defs` instead of asking whether this is your
> registry root — the original harm, alive on the fixed tree), **0998** (the
> re-prompt loop's way out), **0999** (the same missing close-button handler in
> the Library Manager's four other prompts).

---

## The measurement

A throwaway registry — a root holding `library.defs` and two libraries — and two
calls, on the shipped code:

```tcl
library_new ROOTLIB   <root>          ;# the folder that HOLDS library.defs, libA, libB
library_new INSIDE_A  <root>/libA     ;# a folder that IS library libA
```

```
library_new rc=0 err=
ROOTLIB resolves to: <root>
library_new(inside libA) rc=0 err=
```

Both accepted, silently, and both written into the registry:

```
DEFINE libA libA
DEFINE libB libB
DEFINE ROOTLIB /…/root        <-- a "library" that contains the other two
DEFINE INSIDE_A libA          <-- a second name for libA
```

## Why it says yes

`library_defs.tcl:873`. `library_new` checks **three** things and none of them
is about the directory:

| checked | not checked |
|---|---|
| the name is non-empty | the folder already holds a `library.defs` — i.e. it is a registry ROOT, not a library |
| the name is not already registered | the folder is already some registered library's own path |
| there is a writable `library.defs` to append to | the folder is inside a library carrying `ROLE reference` |

Then it runs `file mkdir $path` and appends the `DEFINE`. **The path is never
looked at.** `libmgr::do_new_library` (`library_manager.tcl:1051`) is a thin
wrapper — it adds no check of its own, so **Library manager ▸ New library…** is
`library_new` with a form in front of it.

## What each of the two costs

**A "library" that is the root.** Every cell written into it lands loose in the
folder that holds the real libraries — for `JUNK` that was
`sky130A/xschem_libs`, so an import would have scattered cellviews among
`sky130_stdcells`, `sky130_fd_pr` and the rest, inside a **git-tracked PDK
tree**. Nothing about the name warns anybody: it looks like a normal entry in
the Target library dropdown.

**Two names for one library.** This tree already knows this hazard and has
written it down. `vimport::symbols_path`'s comment records it verbatim: *"TWO
DEFINEs may point at the same directory — `DEFINE zstd std` beside `DEFINE astd
std` — and dropping the one name that came back leaves the OTHER name for the
same tree on the list, so picking it dumps the import into the very library the
run is reading its cell symbols from. Measured 2026-08-28 on exactly that
fixture."* **The defence was built in the consumer; the thing that manufactures
the fixture was left alone.**

## The import dialog is half-defended, and that is the shape of the bug

`vimport::create_library` (`xschem.tcl:17777`) grew four extra guards for
`[[0792]]`: not the std-cell tree of this run, not inside a `ROLE reference`
library, not a directory whose own `library.tag` carries a reference role, and a
post-check that unwinds if the result is not offered as a target. **None of
them lives in `library_new`.** So the same press is guarded on one path and bare
on the other, which also means the guards cannot be trusted by anything that did
not go through the import dialog.

## What the fix has to be

1. **The structural guards belong in `library_new`**, the one choke point both
   forms already call, so every caller inherits them. Two, at least, and each
   with a sentence naming the folder and what is already there:
   * the folder holds a `library.defs` — that is a registry root;
   * the folder is already the path of a registered library — name it, and say
     that a second name for one library is what `[[0792]]` D2 is about.
2. **Keep `vimport::create_library`'s import-specific guards where they are.**
   "This is the std-cell library *this run* reads" is a property of a run, not
   of a directory; it cannot move down. Say in a comment which guard lives where
   and why, so the split is a decision and not an accident.
3. **The refusal must reach the user.** `libmgr::do_new_library` puts `library_new`'s
   error on the status line; check that a refusal is actually visible there and
   not swallowed, and that the New-library dialog does not close over it —
   `vimport::new_library_prompt` deliberately **loops** rather than closing on a
   refusal, and the reason ("closing the window over it would throw away what
   the user typed and say why somewhere they are no longer looking") applies
   here identically.
4. **Do not break the ordinary case.** A blank Directory means
   `<dirname of the primary library.defs>/<name>` — i.e. a new folder *inside* a
   registry root. That is the normal, correct path and must stay rc 0. The
   refusal is for the root **itself**, not for anything under it.
5. **Mutation-verify every check**, and include the ordinary blank-directory
   case as a check in its own right, because it is what a wrong guard would
   break first.

## Not in scope

Anything about what an import writes once a library exists, and any change to
the library manager's other operations.

---

## Fixed on `annotate`, 2026-08-31

The `Branch:` field above says `synthesis`. The fix shipped on **`annotate`**,
where the same defect is live and where the code this issue names actually is.
Two of the five requirements land differently here, and both re-scopes are
measured, not assumed — see "What did not land literally".

**This section describes what was COMMITTED.** An earlier draft of it described
the first implementation, which went green on both arms and was still wrong in
four ways. A mutation pass — sixteen variants, one per build against the real
tree, each restored and re-baselined before the next — took it apart and filed
`[[0995]]`–`[[0998]]`, and all four were repaired before anything was committed.
The most important of them, `[[0997]]`, is that **the user's original complaint
was still reproducible on the tree that "fixed" it**. Read that one if you read
nothing else here.

### What the user sees now

**Library Manager ▸ right-click the Library pane ▸ New library…**, type a name,
pick a Directory. Three presses that used to be accepted in silence are now
refused, and the refusal comes back **in the window**, with what you typed still
in the fields and the reason on a red line across the top — the window no longer
closes over its own error. The Library Manager's status line carries the same
sentence as well; nothing that used to be visible was traded away for the window
coming back. Cancel, Escape, an empty name, and now the title-bar close button
all leave immediately and silently.

**Three sentences, not two, because they are three different facts and only one
of them may be stated as a fact about the user's own setup** (D5-1). All three
are minted in `library_new` and nowhere else (D5-4); callers render them verbatim
and `libmgr::do_new_library` prefixes its existing `new library failed: `.

1. **This is the folder your library list lives in.**

   > `'<folder>' is the folder your library list lives in - the file
   > '<listfile>' in it is the list that says where all your libraries are - so
   > it is the folder that HOLDS your libraries, not a library itself. Cells
   > saved into it would land loose beside your real libraries instead of inside
   > one. Pick one of the folders inside it, or leave the Directory box empty and
   > a new folder will be made for you beside your main library list.`

   `<listfile>` is **the name of the file the user actually has** — `library.defs`,
   or `cds.lib`, or whatever `$XSCHEM_LIBRARY_DEFS` names. That is `[[0997]]`.

2. **This folder holds somebody else's library list** — a checked-out PDK, another
   project's tree — and is not one of the lists this session reads:

   > `'<folder>' holds a library list of its own - there is a library.defs file
   > in it - so it is a folder that holds libraries, not a library itself. It is
   > not one of the library lists this session is reading, so it belongs to some
   > other setup. Cells saved into it would land loose beside those libraries
   > instead of inside one. Pick one of the folders inside it, or a different
   > folder.`

3. **This folder is already a library:**

   > `'<folder>' is already the library '<name>'. Giving one folder a second name
   > means both names open the same files, so work you do under one name quietly
   > turns up under the other. Pick a different folder, or use the library
   > '<name>' you already have.`

### What shipped

**`src/library_defs.tcl` — the structural checks, in the one choke point.**

* **`library_dir_listfile {dir}`** — the name of the list file this session reads
  that lives in `$dir`, or `""`. It walks `library_candidate_defs_files`, which is
  *the very list the write side appends to*, so it asks the question sentence 1
  answers. The first implementation tested for a file literally named
  `library.defs` instead, and that gap was reachable both ways: a registry root
  whose list is spelled `cds.lib` sailed straight through at rc=0 — the user's own
  complaint, alive on the tree that fixed it — while somebody else's PDK tree was
  told it holds *your* list. `[[0997]]`.
* **`library_dir_owner {dir}`** — the name of the registered library whose OWN
  directory is `$dir`, or `""`. **Both** sides of the comparison are normalized and
  neither is decoration: `library_registry`'s auto-discovery stores the raw
  `$pathlist` string verbatim, and `library_defs_parse_file` normalizes a
  *relative* `DEFINE` path only, so a hand-written absolute one keeps its `/./`.
  It reads `library_registry` (the FULL registry), not `library_defs_registry`,
  because with the default `library_registry_defs_only` 0 every search-path
  directory is already a library the user sees in the Library pane.
* Both are separate procs, not inline code, so a mutation run has a callee it can
  no-op and the suite has a handle it can unit-test.
* **`library_new`** gained the three refusals, placed **before** the directory is
  created — a refused press must not leave a stray empty folder behind — and after
  the existing name/registry checks. `set np [file normalize $path]` moved up above
  the directory creation so the checks and the existing relative-path store share
  one value; `file normalize` does not require the path to exist, so the value is
  identical either side.

**`src/library_manager.tcl` — the refusal reaches the user, and the window can
always be closed.**

* `libmgr::last_status` records the last sentence put on the status line — in a
  `--nogui` session too, where the `catch` around the widget configure is a no-op.
  That is the seam that lets the window re-show the SAME sentence rather than word
  a second one.
* `libmgr::newlib_dialog {{name {}} {path {}} {msg {}}}`: the two fields are
  pre-filled from `$name`/`$path`, and `$msg` is a red line across the TOP of the
  window, above the fields. With no `$msg` the label is **not created**, so an
  ordinary New library carries no empty red bar.
* `libmgr::ctx_new_library` LOOPS: on a refusal the window comes back holding what
  was typed and carrying the reason.
* **The title-bar close button was wired to nothing.** Press the X and the window
  vanished while New library went on waiting for an answer that could never
  arrive; destroying the Library Manager took the child the same way. Once the
  prompt loops, a window that can vanish without returning is a **hang**, not a
  mistake. `wm protocol $d WM_DELETE_WINDOW` plus a `<Destroy>` binding guarded on
  `%W` (so a child widget being torn down is not read as a Cancel) now make both
  mean exactly what Cancel means. `[[0998]]`. The dialog was deliberately **not**
  given a timeout: a window that closes itself while somebody is typing is a worse
  defect than the one being fixed.

### What did not land literally, and why

**Requirement 2 has no code to act on here.** `grep -rn vimport src/` returns
**zero** hits on `annotate`; `src/xschem.tcl` is 17578 lines, so the issue's
`xschem.tcl:17777` anchor is outside the file. `library_new` has exactly one
caller in this tree, `src/library_manager.tcl`. What survives of requirement 2 is
the **comment**, which is what it was really asking for: `library_new`'s body now
records that these checks are *structural* (properties of the directory, so they
live in the choke point) while a *run*-scoped check — "this is the std-cell
library THIS run reads its symbols from" — cannot move down and stays in its
caller, which on the import branch is `vimport::create_library`'s four 0792 D2/D3
guards. It says explicitly that there is no vimport here, so nobody reads the
comment as a description of code they can go and open.

**Requirement 3's first half already measured clean.** A refusal was never
swallowed: the duplicate-name refusal reached the status line verbatim before this
change. The real gap was structural — `libmgr::newlib_dialog` destroyed the window
and returned *before* `do_new_library`, the first code that can refuse, ever ran.
So the reason landed on a status bar behind where the window had been, and
`libmgr::on_lib` overwrites that line with `library: <name>` on the next click in
the Library pane. The `vimport::new_library_prompt` loop the issue cites as
precedent is not in this tree, so the loop was written fresh.

**Stale line anchors for this branch:** `library_new` was at
`src/library_defs.tcl:790` (not `:873`) before this change, `libmgr::do_new_library`
at `src/library_manager.tcl:1052` (not `:1051`).

### Mutation-verified (requirement 5)

`tests/headless/test_lib_new_path_guards_0799.tcl`, registered in
`tests/run_regression.tcl` (`hcases` **and** `dcases` — it has window rows) and in
`tests/headless/full_audit.sh`'s `nogui_tests`. **Two arms, two legitimate counts**
(`[[0994]]`): **36 checks headless**, **55 on the dev display**. Reporting one
number against the other arm reads as a standing red.

The rows that carry the load:

| row | what breaks if it goes |
|---|---|
| **R1a–R1d** | the ordinary blank-Directory press — a check in its own right, because it is what a wrong guard breaks first |
| **R2a–R2e** | "this is the folder your library list lives in" |
| **R3a–R3d**, **R5a–R5c** | "this folder is already a library", and the path tidy-up on the registry side |
| **R4b** | the checks running **before** the folder is made — the only behavioural eye on a refused press leaving a stray empty folder |
| **R6b** | auto-discovered libraries count too (the check reads `library_registry`, not `library_defs_registry`) |
| **R7** | the check did **not** over-reach: under the Cadence-style setup a search-path folder is not a library yet, so naming it is still allowed |
| **R8b3, R8b4** | the lookup's **argument-side** path tidy-up, reached by calling it directly with the two untidy spellings — `[[0995]]` |
| **R8a, R8d** | the checks live in the choke point, and run before the folder is made — reading the proc body **with the comments stripped out**, because until `[[0996]]` they were reading the comment and stayed green on a tree with every check deleted |
| **R8c** | the which-check-lives-where note itself; the one row whose subject really is the comment |
| **R9a–R9c** | the Library Manager renders `library_new`'s sentence verbatim instead of wording its own (D5-4) |
| **R10a–R10d** | the window comes back holding what you typed, with the reason on a red line, and **no** empty red bar when there is nothing to say |
| **R11a–R11e** | the window comes back **at all** on a refusal, and the status line still carries the reason too |
| **R12a–R12c** | Cancel still gets you out of New library for good |
| **R13a–R13c** | requirement 4 through the real window: blank Directory is accepted first time, no second window |
| **R14a–R14e** | the refusal asks whether this is **your** registry root, not whether a file called `library.defs` happens to be here — `[[0997]]` |
| **R15a–R15d** | the title-bar close button answers the prompt — `[[0998]]` |

Rewording `structural`, `vimport::create_library`, `library_dir_listfile`,
`set owner [library_dir_owner` or the directory creation out of `library_new`'s
body deletes R8a/R8c/R8d's subject. That is said in the comment itself.

Two suite defects the mutation pass found and the repair pass fixed, both of which
made a row green for the wrong reason:

* **R9 was independent of nothing.** On a tree with the first check broken, R2
  succeeded and registered `ROOTLIB` against the fixture root, so R9's press was
  refused by the *other* check and the status line carried the other sentence —
  green, on exactly the tree shape this issue is about. R9 now unregisters
  `ROOTLIB` first.
* **R7 shared its folder with R6b**, so its greenness depended on R6b having
  passed. A row that only passes when the row above it passed is not a control;
  R7 now uses a search-path folder nothing else reaches.

### Still open after this commit

* **`[[0999]]`** — the Library Manager's four **other** prompts (New cell…,
  Rename…, Copy view…, New view…) have the identical missing close-button handler:
  press the X and the press is lost silently for the rest of the session. Fixed in
  **New library…** only, because that is the one window that loops (a vanish there
  is a hang, not a lost press) and the one this suite can reproduce. Four untested
  one-line changes riding a repair pass was the wrong trade.
* **`[[1200]]`** — `library_new`'s one remaining cryptic sentence,
  `no writable library.defs (set XSCHEM_LIBRARY_DEFS)`, which the loop above now
  puts **inside the New-library window** where it never used to appear. Pre-existing,
  untested, and widening it inside a repair pass was the wrong trade too.
* **On the user's ruling queue** (`tests/headless/owed.sh show`), not decided by
  anybody here: the three refusal sentences; the window re-opening instead of
  closing; whether a folder INSIDE a library should also be refused; the
  default-vs-Cadence mode split below; and whether the four other prompts should
  get 0999's fix now.
* **Owed to the user's eyes**: the three sentences read on screen, and the
  title-bar close button pressed by a person under a real window manager — the
  suite destroys the window from a script, which is not the same gesture. A green
  suite discharges neither.

### Considered and rejected

* **Refuse a folder INSIDE an existing library** (`<root>/libA/sub`). Requirement 1
  names only the two cases fixed here, and refusing this would be a wider
  behaviour change than the issue asked for. On the ruling queue.
* **Allow a second name when the existing one is only auto-discovered** (no
  `DEFINE`). Rejected: that is exactly the "two names for one library" hazard
  requirement 1 names, and it is 0792 D2's fixture. The cost is real and is
  recorded — in the default setup this removes the only way to give an
  auto-discovered directory an explicit `DEFINE` name of your own.
* **Put the checks in `libmgr::do_new_library`** instead of `library_new`.
  Rejected: that is the shape of the bug this issue is about — a guard in one form
  and nothing in the choke point.
* **Give the New-library window a timeout** so a suite can never hang on it.
  Rejected: a window that closes itself while somebody is typing is a worse defect
  than `[[0998]]`. The *test* pollers carry the watchdog instead — each hands over
  to one the moment it stops watching, so the next window a broken loop tries to
  open raises an error and unwinds it. Setting the dialog's done flag cannot do
  that job: a broken loop reads it as one more Cancel.
* The issue's `ROLE reference` row in its "not checked" table has no ROLE concept
  on this branch and was skipped.

### Mode-dependence, recorded rather than hidden

`library_registry_defs_only` is 0 by default (`src/xschem.tcl:14860`) and 1 under
`src/cadence_style_rc:24`. In the default setup every search-path directory is a
library, so New library pointed at one is now **refused**; under the Cadence-style
setup the same directory is not a library and naming it is **accepted**. Row R7
pins that split on purpose, and it is on the ruling queue.
