# Code analysis — the single global document, and what it cost annotation

Status: 2026-09-01. Read-only audit; no code changed. Commissioned before starting
new work on the branch, to answer three questions: how many issues the annotation
effort generated, why a display feature was so hard, and what the single highest-value
architectural fix is.

Method: five parallel audits (annotation issue forensics; C core; C↔Tcl boundary;
test architecture; hierarchy/state model), each instructed to *measure* rather than
opine, with every load-bearing number re-verified independently by the driver before
being admitted here. Numbers that failed re-verification are noted as such in §7.

Companion reading: `orthogonality_analysis.txt` and `dependency_graph_analysis.txt`
(the June 2026 chain that first named this problem), `descend_silent_refusal_census.md`,
`instance_identity_decision.md`, `doc/claude/WIRING.md`.

---

## 0. Verdict

**XSCHEM's number one architecture problem is that there is exactly one document in
memory, it is a mutable global, and it is the only representation of the design.**

This is not a new finding. The June 2026 analysis chain reached it already —
*"the `xctx` god-struct is a shared blackboard … that's the opposite of orthogonal"*
(`orthogonality_analysis.txt:29`). What is new is the **trend**, and the demonstration
that this single fact *generates* most of the other architectural complaints rather
than sitting beside them.

| metric | 2026-06-27 | 2026-09-01 | change |
|---|---|---|---|
| `xctx->` references | 14,648 across 25 files | **19,637 across 35 of 40 `.c`** | **+34%** |
| C↔Tcl `tcleval` | 426 | 444 | +4% |
| C↔Tcl `tclgetboolvar` | 251 | 323 | +29% |
| `refactor` share of commits | — | **26 / 1,585 = 1.6%** | — |

The diagnosis was correct in June, was not acted on, and the coupling grew by a third
in ten weeks.

**Not** the number one problem, and worth stating plainly because it is the obvious
guess: **object identity**. Stable handles shipped in June. All seven object types
(`xWire`, `xInstance`, `xRect`, `xLine`, `xPoly`, `xArc`, `xText`) carry a birth-stamped
`unsigned int id` with `*_index_from_id()` accessors. The classic index-as-identity flaw
was diagnosed and fixed. Its one remaining limit is that ids are session-scoped and do
not survive a reload — which is itself a consequence of §3's finding, not a separate bug.

---

## 1. What the annotation effort actually cost

The branch `annotate` spans 1,585 commits, 2026-06-07 → 2026-08-31, and adds **794 issue
files** (numbering to 1237).

**Scope correction, important for reading the number honestly:** the branch is not only
annotation. It also carries ASE (57 issue files by name), descend/hierarchy (52),
window/tab management (48), selection (44), netlisting (35), the fluid wiring router (28),
a calculator and a signal browser. **Annotation itself is 98 files by name, ~243 that
mention it** — 12–30% depending on how you count. "One simple feature produced 794 issues"
is not supported; "one simple feature produced ~98–243" is.

The slope is the concerning part, not the total:

| month | commits | issues filed | issues / 100 commits |
|---|---|---|---|
| 2026-06 | 591 | 62 | 10.5 |
| 2026-07 | 534 | 127 | 23.8 |
| 2026-08 | 460 | **605** | **131.5** |

Commit output fell 22% while defect discovery per unit of work rose 12.5×.

**Caveat, and it is a real one:** much of the test harness was built during this window,
so this metric conflates *more defects existing* with *better instruments finding them*.
It should not be read as proof of accelerating decay on its own. What it does support
without ambiguity is that effort-per-shipped-change deteriorated.

Rework, which is not subject to that caveat:
- **`op_annot::save_cards` was written and reverted five times** — preserved patches
  `0436-attempt-1-reverted.patch`, `0442-attempt-2-reverted.patch`,
  `0443-attempt-3-interrupted.patch`, `0494-attempt-4-reverted.patch`; attempt 5 landed.
  Attempt 4 was reverted **despite** being green at 275 headless checks with 17/17
  sabotage probes correctly red — because its central claim was false on shipped designs.
- **~11 full revert cycles** across the annotation work.
- **One harness defect filed five times**: 0420, 0456, 0492, 0629, 0689. Four were later
  reconciled; **0456 is still OPEN and cross-referenced by none of the other four.**
  A second defect (a stale golden) was filed four times: 0421, 0455, 0491, 0690.

---

## 2. Why annotation was hard: it is a provenance problem wearing a rendering problem's clothes

To print `id = 515.8u` beside a transistor, five layers that were never designed to agree
must agree at the same instant:

1. **Which string names this device** — C's `get_fqdevice()` vs Tcl's `op_annot::devpath`
   vs the PDK's own `.sym` text vs the netlister's `.subckt` block.
2. **Whether the loaded `.raw` is this run** — decided by path string, `sim_type`, mtime
   and size. Every one of those is a proxy, and each has a filed defeat: 0810 (bare
   `strcmp` on `annot_root`, so `b/dut/./dut.sch` false-clears the mask), 0916 (a
   symlinked results path defeats the same-path test), 0915 (`{mtime size}` cannot see a
   re-run inside one second at the same byte length).
3. **Which window's `xctx` holds it** — 0881: the waveform viewer attaches to its own context.
4. **Which sheet the mask was armed for** — 0809: `::annot_show` is a process-global Tcl
   variable while `annot_root` is per-`Xschem_ctx`, so a context can hold a live mask with
   a NULL stamp and 0688's fix is permanently inert there.
5. **Whether the cached block is still valid** — 0466: a 13-field "observed-state epoch"
   moved on nothing when a file was re-read at the same path with the same instance count,
   so the overlay painted the *previous file's* numbers. The retry needed 14 epoch terms
   plus 4 explicit hooks; 0464 residuals remain open.

Issue **0485** states the origin outright: *"this defect is the reason `op_annot` exists."*
`get_fqdevice()` switches on the SPICE element letter and therefore can never name a
subcircuit-wrapped PDK device. So the feature was **born as a second device-name builder
standing beside the C one** — and `src/op_annot.tcl` (3,121 lines, 74 procs, essentially
no GUI) went on to re-implement hierarchy walking, netlist-deck parsing, and model/path
substitution that C already had.

The forensic classification of ~202 annotation-related issues by *mechanism*:

| root cause | count |
|---|---|
| **Two representations of one fact, nothing forcing agreement** | **31** |
| Test instrument defective | 41 |
| Silence — N causes behind one blank | 40 |
| **Identity/freshness decided by a proxy key** | **19** |
| Hierarchy traversal is a *mutating* operation | 14 |
| Unratified user-visible decision (a ruling, not a defect) | 14 |
| Simulator/deck contract | 12 |
| Per-window `xctx` ownership | 10 |
| Build/install/startup + memory safety | 11 |
| Draw/bbox/redraw ordering | 6 |
| `@`-token parsing in shared `translate()` | 4 |

Rows 1 and 4 are one mechanism seen from two sides: **50 of ~202 = 25%**.

**And then the compounding blow: building the save cards requires a hierarchy walk, and
in XSCHEM walking is a write.** See §3.

---

## 3. The mechanism: one document, so looking is writing

Hierarchy is not a data structure. It is a stack of strings and scalars beside the one
mutable document (`xschem.h:212`, `:1586-1597`):

```c
#define CADMAXHIER 40
char *sch[CADMAXHIER];              /* filename per level */
int   currsch;                      /* depth cursor */
char *sch_path[CADMAXHIER];         /* ".x1.x2." instance path */
Str_hashtable portmap[CADMAXHIER];  /* pin->net STRINGS, snapshotted at descend */
Lcc   hier_attr[CADMAXHIER];        /* copies of the parent instance's prop strings */
```

`CADMAXHIER` is a hard 40-level cap enforced by refusal.

**Descending is a destructive reload, not navigation.** `descend_schematic()`
(`actions.c:5669`) stacks metadata, increments `currsch`, then calls `load_schematic()`,
which `clear_drawing()`s — freeing every wire, instance, text and polygon — and re-parses
the child **over the parent's arrays**. `go_back()` (`actions.c:6020`) reads the parent
back **off disk**.

Therefore **there is no non-destructive traversal**, and the proof is in the tree:
`xschem list_hierarchy` — a pure question, "which cells are in this design?" — is
implemented as `hier_psprint(&res, 2)` (`scheduler.c:7562-7569`), the netlister driver,
which destroys and rebuilds the user's buffer. Every walk in the program is
destroy-and-restore via `push_undo()`/`pop_undo()` used as a save/restore idiom.

### 3.1 The `reset_undo` conflation — the sharpest single defect

```c
int load_schematic(int load_symbols, const char *fname, int reset_undo, int alert);
```

That one `int` gates **13 distinct semantic decisions** in `save.c:4660-4857`: clear the
undo history, `set_modify(0)` at four separate sites, recompute `readonly`, capture
`time_last_modify`, run `autotrim_wires`, and fire the `eval_load_file_postprocess` Tcl hook.

And `descend_schematic` passes **`(set_title & 1)`** into it (`actions.c:5914`).

*"Should I update the window title"* and *"should I erase the undo history and declare
this buffer clean"* are the same bit. This one conflation is the mechanism behind issues
0250, 0261 and 0626.

### 3.2 The `~` backup file is the hierarchy stack

`load_backup_as()` (`save.c:4504`) loads the `~` file's **content**, then re-asserts the
cell's **identity** (`sch[currsch]`, `current_name`, `current_dirname`), then calls
`set_modify(1)`. So every name-based guard downstream is *right about which cell and wrong
about which content*.

File I/O is not entangled with navigation by accident. An in-memory design
(`hier_slot[CADMAXHIER]`) was specified and then abandoned, because the per-level metadata
arrays and the cross-level hilight functions all assume one context holds every level.
**The backup file was chosen as navigation's storage.**

### 3.3 One descend/go_back round trip, measured on this tree

1. Parent geometry destroyed and re-read from disk.
2. **Undo history destroyed** (issue 0261).
3. Selection destroyed, never restored; `ui_state` zeroed.
4. **Modified flag fabricated**: clean buffer + a stale `parent~.sch` → returns with extra
   content and `modified=1` (issue 0495).
5. With `autosave_backup=0`: child edits silently reverted, parent falsely dirty (0626).
6. **Disk writes as a side effect of looking**: `set_modify(1)` → `write_backup()` rewrites
   `<cell>~.sch` for ancestors the user never touched (0632).
7. Symbols purged unless `keep_symbols`; hilights re-derived; graph/marker/preview/floater
   state wiped; `readonly`, `current_name`, `current_dirname` recomputed.

Correctness now depends on a **user preference**: `autosave_backup` on rewrites strangers'
files; off destroys edits. Both halves are defective.

Census of the ~78 substantive descend issues (~45 still open): silent refusal / false
success 18; modified-flag + autosave coupling 14; state-not-restored-on-ascend 13;
pick-mode arming 10; path-string handling 10; symbol↔schematic binding 9; stale
`sel_array` 8; load-over-context orphans 8; walk drivers ignoring per-step results 6.

**What they collectively prove: the hierarchy has no traversal API, so every caller
re-implements the walk and re-discovers the same holes.**

---

## 4. Why this is the root and the other complaints are branches

The single-document fact *generates* the rest:

- **Anything needing a second view** of the design must either destroy-and-restore the one
  document, or keep a private shadow that drifts. That is exactly the 25% "two
  representations" class in §2. The shadows exist because there is nowhere else to put a
  second view. `op_annot.tcl`'s 3,121 lines are one such shadow.
- **Multi-window correctness is already being paid in hand-copies**: `compare_schematics()`
  (`xinit.c:1011-1146`) allocates a fresh context and hand-copies **27 of 431 fields**;
  `swap_tabs()`/`swap_windows()` hand-swap **4 of 431**; `net_hilight_borrow_ctx` has
  **17 borrows against 20 restores**, asymmetric because functions have multiple exits.
  Every new field silently rots these.
- **Transactions cannot be built** without an object to snapshot and swap.
  `mem_restore_slot()` already does precisely that — it simply cannot be *scoped* while
  "the document" is a global.
- **Testability**: there are **zero C unit tests**, because a document cannot be
  instantiated without a window. Every test boots the full binary and drives it through Tcl.

Supporting hygiene measurements, for completeness:

| | measured |
|---|---|
| `Xschem_ctx` fields | **431** declarators; 421 named directly outside the header; 59 accessors (0.3%) |
| Global reassigned at | 32 sites (26 in `xinit.c`) |
| Cache coherency | 185 manual `xctx->prep_* = 0` invalidations vs 267 reads |
| `void` vs `int` functions | **713 vs 651** — over half cannot report failure |
| `load_schematic()` returns | 47–50 call sites, **~45 discard the result** |
| Undo model | `MAX_UNDO 80` whole-document deep copies; **137 `push_undo` / 59 `pop_undo`; no begin/commit/abort** |
| OOM | allocator returns NULL; `my_strncat` `memcpy`s into it on the next line |
| `CFLAGS` | **no `-Wall`, no `-Wextra`** |

---

## 5. Ranked runners-up

**#2 — `scheduler.c` is the entire API surface, and it is untyped.** 14,771 lines, **322
`strcmp(argv[1], …)` dispatch sites**, 743 `else if`, a `switch(argv[1][0])` into 22
per-letter functions (largest 2,112 and 2,062 lines). It calls 412 of the 704 exported
functions (58%). Adding a command means editing a 2,000-line function and keeping
alphabetical order by hand. There is no arity or type descriptor and no generated help;
everything crosses as strings, with 64 sites running `sscanf`/`strtok`/`atoi` directly on
a Tcl result (filed consequences: 0388, 0180, 0048, 0050).

Real, and worth fixing with a dispatch table carrying arity and types. Ranked below #1
because it is an *API-surface* problem: fixing it would not have prevented annotation's
98 issues.

**#3 — the C↔Tcl boundary has no contract.** The *split* is defensible and is what makes
XSCHEM extensible. What is not defensible: ~25 values duplicated between C and Tcl
(13 carry a `MIRRORED IN TCL` marker; the marker set is incomplete — `xinit.c` caches 5
more that carry none), with **no sync function, no assertion, no invariant check**. The
only automated defence in the tree greps `xschem.h` *as text* from a Tcl test, for one
constant of ~25. Issue **0453** is the live, open, deliberately-unfixed instance:
`show_hidden_texts` is refreshed in three places and read in three others that never
refresh, so SVG exports render stale. Compounding it, `tcleval()` on `TCL_ERROR` returns
the *empty result*, so a caller cannot distinguish "error" from "false", and
`tclvareval`'s return code is checked at 22 of 261 sites (8.4%).

**Independent problem, not a symptom — the test architecture.** 359 headless test files;
**332 define their own `proc check`** in mutually incompatible signatures; the shared
`tests/headless/harness.tcl` is 56 lines and is sourced by **zero** of them. `test_op_annot.tcl`
is 16,286 lines against a 3,121-line implementation (5.2:1), of which 41% of the code is
183 private `opa_*` helpers — 16 lines of scaffolding per assertion. 105 of 359 test files
assert against the *source text* of `src/*.c` / `src/*.tcl`, which is refactor-fragile by
construction. ~65 issues (~8% of the tracker) are defects in the test system itself,
several of which manufacture false greens. A full audit is sequential, ~437 process
launches, ~13–15 minutes.

This one is largely self-inflicted and fixable **in parallel** with everything above:
extract one assertion library, replace source-grep assertions with behavioural ones,
parallelise the audit.

---

## 6. Recommendation

### Target design

Make a schematic sheet a **first-class in-memory document**, and make descend a **cursor
over documents** rather than a reload of the one document.

- A `Sheet` value — the object arrays, prep flags, undo stack, dirty bit — keyed by
  canonical file path, held in an open-document table with refcounts.
- `xctx` demoted to a **view**: window, GCs, zoom, selection, bound to a `Sheet`.
- Hierarchy becomes a real cursor: a vector of `(sheet, instance_id, inst_number)` frames.
  No `sch_path[]` string arithmetic, no `CADMAXHIER` cap, recursion detected by sheet
  identity rather than by depth 40.
- Descend = push a frame and rebind the view, loading only on a cache miss. Ascend = pop.
  Parent geometry, undo, selection and dirty flag were never touched — so `load_backup_as`,
  the `~` coupling and `_park_backup` all **disappear**, and `autosave_backup` goes back to
  being crash recovery.
- Then one read-only traversal API — `for_each_sheet(root, visit)` handing the visitor a
  borrowed `const Sheet *` — and rebuild `list_hierarchy`, `hier_psprint`, the netlisters
  and the annotation walk on it. That single API deletes the `push_undo`/`pop_undo`-as-
  save/restore idiom (and issue 0498's segfault class) and makes "looking" provably
  non-mutating.

Prior art to copy rather than invent: KiCad passes `BOARD*` / `SCH_SHEET_PATH` explicitly
and makes multi-step edits atomic via `BOARD_COMMIT::Push()/Revert()`; Blender threads
`bContext*`/`Main*` through every operator and owns undo in the operator framework rather
than at the call site; Inkscape has `SPDocument`. None has a global "current document".

### Sequencing

1. **Split `load_schematic`'s `reset_undo` into named flags** — `clear_undo`, `set_clean`,
   `recompute_readonly`, `set_title`. Contained, low risk, and it is the mechanism behind
   0250, 0261 and 0626. Do this first regardless of what follows.
2. **Thread `Xschem_ctx *ctx` through the API and delete the global.** The mechanical
   prerequisite for everything else, and tractable: the global is *assigned* at only 32
   sites, and the 19,637 reads are a mechanical `xctx->` → `ctx->` rewrite plus a signature
   sweep.
3. **Introduce `Sheet` and the open-document table**; make descend a cursor.
4. **Add the read-only traversal API** and port the four walk drivers onto it.
5. Then, independently and in any order: the dispatch table (#2), a `tcleval_checked()`
   plus a generated mirror table with a startup assertion (#3), and the test-harness
   consolidation.

Doing this in the reverse order — transactions first, or the dispatch table first — leaves
both built on ambient state and buys back none of the testability.

Two cheap hygiene wins that need no design work: turn on `-Wall -Wextra`, and make the
allocator fail loudly on OOM instead of returning NULL into an unchecked `memcpy`.

---

## 7. Method, confidence, and what is *not* established

Every headline number above was re-measured by the driver independently of the agent that
produced it. Confirmed exactly: 19,637 `xctx->` refs across 35 of 40 files; `scheduler.c`
14,771 lines; 322 `strcmp(argv[1])`; 743 `else if`; `MAX_UNDO 80`; 137 `push_undo` / 59
`pop_undo`; `CADMAXHIER 40`; no `-Wall`; 359 test files with 332 private `proc check` and
0 sourcing `harness.tcl`; issue 0456 open; four preserved revert patches; 0485's
"reason `op_annot` exists" line; `list_hierarchy` → `hier_psprint`; `reset_undo`'s 13 gates.

Minor drift found and corrected during verification (none changes a conclusion): `tcleval`
is 444 not 461; `tclgetvar` 165 not 167; `tclsetvar` 158 not 159; `strcmp(argv[1])` 322 not
324; `load_schematic` call sites 47 not 50; `MIRRORED IN TCL` markers 13, with the
larger ~25 figure depending on counting unmarked mirrors.

**Not established, and should not be quoted as if it were:**

- That the rising issue rate proves accelerating decay. It conflates defect creation with
  detection improvement (§1).
- The exact domain-logic-in-Tcl total. The conservative figure is ~11,600 lines; a looser
  GUI-density filter yields 30,110. The *direction* is solid; the magnitude is not.
- The precise harness-defect count (~65) — it rests on a sampled body scan, not a full
  classification. The by-title floor of 43–47 is firm.
- Any claim about runtime performance. Nothing here measured it.
