# Results selection — binding a saved simulation result to a session

**Status:** SPEC. No code yet. No companion PLAN.md yet.
**§17 was RULED by the user on 2026-08-18** — ten decisions, the result model
(§17.1) and the `cadence_compat` gate (§17.2). Two questions remain open (§17.1
and §17.2 are not among them): how much C v1 needs, and whether a run history is
wanted.
**Owner branch:** `fluid-editing`
**Audience:** Claude Code, in a future session, asked to build xschem's answer to
Cadence ADE-L's **`Results ▸ Select…`** — the command that binds a saved
simulation result to a session so that everything downstream (the Calculator,
annotation, printing) has something to evaluate against.
**Related:** `doc/claude/specs/calculator.md` (W03–W05, R204, R601–R607, R705,
§13) · `doc/claude/specs/waveform_signal_browser.md` §11–§12 (the shipped
Location bar and the atomicity ruling) · `doc/claude/specs/ase_l.md` (the menu
this extends) · `doc/claude/specs/simulator_profiles.md` §8 (the four-status
resolver this copies) and §14.7 (the bypass enumeration this copies) ·
`doc/claude/specs/hierarchy_editor.md` (structure and the §1.1 gap-table idiom).
**Issues on this path:** **0507**, **0508**, **0509** (all filed 2026-08-18 by
the survey that produced this spec), and the pre-existing **0216**.

**Line numbers below are as of 2026-08-18 (`58b2c24d`) and will drift. Grep the
symbol.** Cross-file citations *inside source comments* in `wave_viewer.tcl`,
`calculator.tcl` and `ase.tcl` were measured to be systematically stale — do not
copy one without re-grepping it.

> **READER'S MAP.** **Nothing is ever renumbered** — tests and source comments
> will cite these sections by number.
>
> | you want to know | section |
> |---|---|
> | why this is cheap (most of it already exists) | §0 |
> | how far xschem is from Cadence, row by row | §1.1 |
> | the facts the design may not violate | §1.2 |
> | what "a result" *is* here, and why it is a file not a directory | §2 |
> | the engine contract, and the C changes | §3 |
> | the four statuses a stored selection resolves to | §4 |
> | the verb and the Tcl API | §5 |
> | the ASE-L `Results ▸ Select…` dialog | §6 |
> | the two surfaces that already select, and how they align | §7 |
> | persistence — the seam that is already read and tested | §8 |
> | naming a run so there is something to select among | §9 |
> | messages and refusals | §10 |
> | landmines | §11 |
> | verification invariants | §12 |
> | decisions that can change | §13 |
> | beyond Cadence / deviations / non-goals | §14–§16 |
> | the rulings, and the result model they correct | §17, §17.1, §17.2 |
> | what is deliberately NOT here | §18 |
> | the `v(out)` -> `VT(out)` move, and why it is not here | §19 |

---

## 0. The one-paragraph version, and the single most important fact

Cadence binds a *result* to a *session*: pick it once with `Results ▸ Select…`,
and the Calculator, annotation and the print commands all work against it until
you pick another. xschem has every mechanical piece of that and no concept
joining them — many databases can be loaded at once, one is "current", a verb
exists to switch between them, and a persistence slot for the choice is already
read, restored and covered by two tests. What is missing is (a) any UI framed as
*choose a result*, (b) a correct re-bind when the chosen result is re-selected,
and (c) anything worth choosing *among*, because every simulation overwrites one
deterministic path.

**Most of the engine already exists. Do not write a database manager.**

| What you need | Where it already is |
|---|---|
| A registry of many simultaneously-loaded results, per window **and per tab** | `xctx->raw` + `xctx->extra_raw_arr[]` / `extra_idx` / `extra_prev_idx`, `src/xschem.h:2036-2043` |
| "Make this loaded one current" | `xschem raw switch <n \| file type>`, `src/scheduler.c:10406`; back-out `raw switch_back`, `:10425` |
| "Load this file and make it current" | `xschem raw read <file> [type]`, `src/scheduler.c:10386` |
| Registry listing | `xschem raw info` → `<idx> current` + one `<i> <path> <type>` line per slot, `src/save.c:2110-2122` |
| A correct parser for that listing | `wviewer::rawinfo_parse {text}`, `src/wave_viewer.tcl:2393` (PURE, per-LINE) |
| A content check that refuses ngspice's `constants` plot and an empty plot (and deliberately says nothing about a file it cannot parse) | `ase::raw_content_verdict {path}`, `src/ase.tcl:2794` |
| A safe adopt sequence | `ase::attach_dbs {rawfile sim_type {vcdfiles {}}}`, `src/ase.tcl:2866` |
| A shipped path-picker with a 20-deep persisted MRU | the Location bar: `wviewer::rawbar_load {token path}`, `src/wave_viewer.tcl:8583`; MRU `wviewer::rawhist_*`, `:8185-8325`, disk `$USER_CONF_DIR/raw_history` |
| A file chooser filtered on `.raw` | `select_raw {{parent {.}}}`, `src/xschem.tcl:16672` — **the only `.raw` filetype filter in the tree** |
| A persistence slot for the choice | ASE state `viewer.rawfile`, restored by `ase::ui::viewer_restore`, `src/ase_window.tcl:4441-4517` |
| Tests that already drive that slot | `tests/headless/test_ase_persist.tcl` **G11** (G9 pins the open-gate, G10 the missing-raw fallback); `tests/headless/test_wave_crossdb_trace.tcl` `xs_state` (`:1000-1012`) |
| A "which configured row is the one" selector idiom | `sim($tool,default)` radiobuttons, `src/xschem.tcl:5042-5170` |

The work is a verb, a dialog, one C fix (or none — see §3.1), and a decision
about run identity.

---

## 1. Where xschem stands today

### 1.1 Cadence capability × xschem today

| Cadence ADE-L / ViVA capability | xschem today | Evidence |
|---|---|---|
| `Results ▸ Select…` — a chooser that binds a result to the **session** | **absent** | `$top.mb.results` gets two adds — Direct Plot and a cascade onto a two-entry disabled Annotate submenu, `src/ase_window.tcl:526-535` |
| Selection is a **prerequisite**: Calculator selectors and every `Results ▸ Print` refuse until a result is bound | **partial** — refusal exists but is per-*name*, not per-*session*: `get_raw_index()` returns -1 | `src/save.c:3406`; `references/viva_research_raw.json` research[5].items[55] |
| `Results ▸ Save` — **names** the current results into a history (`Interactive.32.R0`) | **absent** | `references/viva_research_raw.json` research[7].items[28]; no producer varies a path per run (§9) |
| Plot signals from **several histories** into one window | **yes** — better than the framing suggests | per-trace `%<rawfile> <sim_type>` suffix via `node_token_split()`; `wviewer::db_suffix`, `src/wave_viewer.tcl:2584` |
| Results Browser **Location field** + last-20-directories drop-down | **yes**, for files not directories | `wviewer::rawbar_load`, `src/wave_viewer.tcl:8583`; MRU `:8185-8325`, cap `::raw_history_max` = 20 |
| `File ▸ Open Results` → *Choose Data Directory* | **partial** — `Browse…` → `select_raw`, a `tk_getOpenFile` on `.raw` **files** | `src/wave_viewer.tcl:8659`; `src/xschem.tcl:16672` |
| Search across **all open databases** (`All DBs`) | **yes** | `wviewer::browser_alldbs`, `src/wave_viewer.tcl:10425`; walker `wviewer::signal_list_all`, `:2443` |
| `Update` vs `Reload` vs `Clear` on a selected result | **absent** as a distinction — every attach path re-reads | `references/viva_cadence_waveform_viewer.md:169` |
| OCEAN `openResults(dir)` + `selectResult('tran)` sets the **current** selection | **partial** — `xschem raw read` / `raw switch` do this, but only from surfaces not framed as a selection (the viewer Location bar `src/wave_viewer.tcl:8647`; the graph dialog `src/xschem.tcl:6927`) plus scripts, and `read` mis-binds (0509) | `src/scheduler.c:10386`, `:10406`; issue **0509** |
| Per-call `?result` / `?resultsDir` override **without** changing the selection | **yes**, per trace — the `%<rawfile>` suffix is exactly this | `references/viva_research_raw.json` research[5].items[53]; `src/draw.c` node walkers |
| `Edit ▸ Component Display ▸ Set Simulation Data Directory` — tell a *schematic* whose results are its | **absent as a UI** — the stamp can be re-pointed only by `xschem set raw_level <n>` or `xschem annotate_op <file> <level>`, neither framed as "whose results are these", and both bounded to a level already on the current stack | re-stamp `src/scheduler.c:12292-12293`, `:2432-2433`; gate `sch_waves_loaded()` `src/draw.c:2825-2840` |
| Results **Display Window** for `Results ▸ Print` | **absent** (Calculator §9's Table, R606, is the nearest planned thing) | `references/viva_research_raw.json` research[5].items[33] |
| A selection survives a session save/restore | **was half-built** — the slot was read, resolved, existence-gated and tested while **nothing ever wrote it**; **BUILT by item 6** (§8.1) | read `src/ase_window.tcl:4441-4517`; writer `src/wave_viewer.tcl:4101` (hardcoded `rawfile {}` until 2026-08-19) |

**Score: xschem has the machinery and none of the concept.** Every mechanical
primitive Cadence's Select rests on is shipped and tested — a multi-database
registry, a switch verb, a content check, a picker, an MRU, a persistence slot,
even per-trace cross-database addressing that Cadence charges a history for. What
is absent is the *object*: nothing in xschem is named "the result this session is
working against", nothing writes that choice down, and no menu offers to change
it. Five of the thirteen rows are outright absent, three partial, one half-built,
four already at parity or ahead.

### 1.2 The architectural facts the design must respect

**F1 — a result is a FILE, and this is already ruled.** Cadence's PSF is a
*directory* (`references/viva_cadence_waveform_viewer.md:38-40`); ngspice writes
one flat `.raw`. `doc/claude/specs/calculator.md:911-921` §13 (the ruling row is `:917`) already rules
"Results Dir = a PSF directory → a `.raw` **file** path". This spec inherits that
ruling and does not re-litigate it. It also means Cadence's *two* mechanisms —
`Results ▸ Select` (picks a **data file**) and the Results Browser Location field
(takes a **directory**) — collapse into one here. Do not model both.

**F2 — the registry is per-`xctx`, i.e. per window/tab.** `extra_raw_arr` lives
in `Xschem_ctx` (`src/xschem.h:2036-2043`), allocated per context. Two viewer
windows genuinely hold two different selections — **and so do two tabs**:
`create_new_tab` allocates a fresh context per tab (`alloc_xschem_data`, then
`save_xctx[i] = xctx`, `src/xinit.c:2204`, `:2209`) and `switch_tab` swaps the
whole context (`xctx = save_xctx[n]`, `:1938`). Measured: a database read in one
tab is absent from `xschem raw info` in a sibling tab.
A "session's current result" therefore means *this context's*, and any
cross-context statement (the Calculator reporting a viewer's raw) is a **loan**,
not a shared state — see F6.

**F3 — the engine registry is the source of truth, not any UI history.** Stated
already at `doc/claude/specs/waveform_signal_browser.md:890-916`. The MRU
(`$USER_CONF_DIR/raw_history`) is a convenience and is *incomplete by
construction*: `attach_raw` never pushes to it (**issue 0216**, declared limit
L-13a). A Select dialog may offer the MRU as suggestions but must never present
it as "the results you have open".

**F4 — a database is bound to the schematic that was current when it was READ.**
**Every reader** stamps `raw->schname` / `raw->level` from
`xctx->sch[xctx->currsch]` — `raw_read()` `src/save.c:1383-1384`, `new_rawfile()`
`:1545-1547`, `table_read()` `:3131-3132`, `vcd_read()` `src/vcd_read.c:835`. A
fix aimed at "raw_read" alone misses three of the four. `get_raw_index()`
(`:3406`) refuses unless `sch_waves_loaded()` (`src/draw.c:2825-2840`) finds that
stamp on the *current* hierarchy stack. Measured:

```
srlatch open, its raw read here   → raw loaded 0   raw index v(q) 52   value 7.7437794e-16
navigate to another cell          → raw loaded -1  raw index v(q) -1   value <empty>
                                    ...and `raw info` still lists it as slot 0, current
```

**This is the single hardest constraint in the feature.** Cadence's selection is
independent of what is on screen; xschem's is not. §3.1 owns the fix — and note
that a re-stamp verb **already ships**: `xschem set raw_level <n>`
(`src/scheduler.c:12275-12297`) writes both fields, bounded to
`0 <= n <= xctx->currsch`. Measured: it restores the blind database above to
`raw loaded 0` / `raw index v(q) 52`.

**F5 — `read` silently degrades into `switch`, and lies about it.** Re-reading an
already-loaded path takes `extra_rawfile()`'s *"file found: switch to it"* branch
(`src/save.c:1916-1921`, **and again at `:1970-1975`** — the `what == 1` arm is
written twice, once per reader family), which moves the cursor and never
re-stamps. Measured: `rc=1`, and the database stays unusable. **Issue 0509.** A
Select verb built naively on `xschem raw read` would report success and deliver
nothing.

**F6 — the borrow idiom is the only legal cross-context read.**
`wviewer::enter_ctx {token ?borrow?}` → ticket `{ok prev ?sem?}` → work →
`wviewer::leave_ctx {token ticket}` (`src/wave_viewer.tcl:1404`, `:1475`).
`borrow 1` lowers a `semaphore == 1` gesture frame so a menu-driven read is not
refused (issue 0314). **A REFUSED ticket is skipped, never read as "no raw"** —
`doc/claude/specs/calculator.md:201`. Five borrow sites exist today; a Select
dialog reading another window's registry becomes the sixth.

**F7 — clearing before reading turns a typo into data loss.** Measured and ruled
at `doc/claude/specs/waveform_signal_browser.md:945-953`: with raw A current,
`xschem raw read <garbage>` returns 0 and leaves **both** `raw rawfile` and
`raw list` on A. The engine's read is atomic *as long as nothing cleared first*.
`rawbar_load` therefore deliberately does **not** clear. The declared cost is
that databases accumulate (L-13b) — which is exactly the substrate this feature
needs.

---

## 2. What "a result" is here

**R101** A **result** is a readable `.raw` file plus the `sim_type` it was read
as. The pair `(rawfile, sim_type)` is the registry's identity key — it is what
`extra_rawfile()` dedupes on and what `xschem raw switch <file> <type>` accepts.
Nothing else identifies a result: not a name, not a run, not a directory.

Two asymmetries in that key, both measured in `extra_rawfile()`: on the **read**
side an empty/NULL type matches *any* analysis already loaded from that path
(`(!type || !strcmp(...))`, `src/save.c:1934-1937`), while on the **switch by
name** side both `file` and `type` are required (`if(file && type)`,
`src/save.c:1978`) — so `xschem raw switch <path>` with no type does not find
anything by path. R301 and L10 own the consequence.

**R102** A result is **not** a VCD or a table database, even though those share
the registry. `Results ▸ Select…` selects analog results only; digital
databases arrive alongside one (`ase::attach_dbs`'s `vcdfiles` argument) and are
not independently selectable in v1. See §16.

**R103** The **selection** is a property of one `xschem` context (F2), expressed
as `extra_idx`. Selecting a result means: it is in the registry, it is current,
and its `schname`/`level` stamp resolves against the current hierarchy stack.
All three, or the selection is not real — R103 is the definition every check in
§12 tests against.

**R104** A selection carries a **case mode**. `Raw` holds `case_sensitive`, a
lazily-built `fold_table` and `req_sim_type` (`src/xschem.h:1183-1250`, from the
casemode batch). Selecting a result must not silently change the mode a viewer's
Case Mode readout is describing — `wviewer::casemode_invalidate` /
`casemode_reapply` (`src/wave_viewer.tcl:14703`, `:14736`) exist for this and
must be called.

---

## 3. The engine contract

### 3.1 The C change — RULING

### RULING — `xschem raw read` re-stamps on the dedupe path

**R110** `extra_rawfile(what == 1, …)`, in *both* "file found: switch to it"
branches (`src/save.c:1916-1921` and `:1970-1975`), must refresh
`raw->schname` and `raw->level` from `xctx->sch[xctx->currsch]` before returning.
No re-parse. This makes `read` mean one thing — *"this file is the current
result, here"* — and is the cleanest fix. Issue **0509** candidate (1).

**R110 re-binds ONE ANALYSIS SLOT, not the whole run — a stated boundary, added
by the item-1 fix round.** The registry key is `(rawfile, sim_type)`, so one
`multi.raw` holding a DC sweep and a transient occupies **two** slots, which
**U11** calls one result. `xschem raw read <file> <type>` names an analysis and
re-binds that slot; the sibling stays bound where it was, and a `raw switch` to
it lands on a database that still answers `-1` to every name. Measured
2026-08-19 with a two-plot ascii raw:

```
read multi.raw dc under cellA ; read multi.raw tran under cellA   -> 2 slots
load cellB (unrelated)                                            -> loaded=-1
raw read multi.raw tran   -> rc=1 loaded=0  index v(n1)=1   (tran re-bound)
raw switch multi.raw dc   -> rc=1 loaded=-1 index v(n1)=-1  (dc still on cellA)
```

That is R110's boundary and not a defect in it: `read` is an analysis-level verb.
The **run**-level gesture is item 3's `xschem raw select`, and re-binding every
slot of the chosen run is that verb's job under U11. Recorded here so the gap is
a boundary someone chose rather than one nobody noticed.

**R110a — CREW RULING, 2026-08-19 (results batch item 1). The re-stamp fires
only when the current stamp does NOT already resolve against the stack.**
R110's literal wording — *refresh from `xctx->sch[xctx->currsch]` before
returning* — was implemented, measured, and found to create the same blindness
pointing the other way. `sch_waves_loaded()` accepts any stamp still **on** the
current hierarchy stack, ancestors included (`src/draw.c:2831-2838`), so a
database read at the top and re-read after a **descend** is already the current
result here; re-stamping it to the child moves the binding *down*. Measured with
the unconditional form, `tests/headless/fixtures/hi_descend/hidlib`:

```
read at top          : loaded=0  raw_level=0  idx=1
descend to leaf      : loaded=0  raw_level=0  idx=1
re-read same path    : loaded=1  raw_level=1
ascend to top        : loaded=-1 raw_level=1  idx=-1     <-- top level now blind
```

The shipped descend path already treats the level as load-bearing for exactly
this reason: `open_sub_schematic` and `hi_descend`'s new-window arm follow their
re-read with `xschem set raw_level <n>` to push the stamp back **up**
(`src/scheduler.c:12275-12297`). So the rule is **re-bind only what is not bound
here**, which is R110's stated goal — *"this file is the current result, here"* —
with no case where a **`read` verb** makes a result less reachable than before.
(That qualifier is not decoration: the first cut of R110 applied to the *draw*
callers too and did make a result less reachable — see **R110c**, which is the
rule that earns the sentence back.) Implemented as one guard in
`raw_restamp_design()` (`src/save.c`); pinned by group D (SEL39/SEL41/SEL42) of
`tests/headless/test_results_select.tcl`, which goes red if the guard is removed.

**The guard still refreshes `raw->level`** — item-1 fix round. Returning early
left the level un-refreshed and able to sit **above** `xctx->currsch`: read a
database one level down (`level = 1`), then open that same cell **flat**
(`currsch = 0`) and the stamp still resolves, so the guard fires and `level`
stays 1. `xschem set raw_level` refuses to write such a value at all (it bounds
`0 <= n <= currsch`, `src/scheduler.c:12291`), and the four `ngspice::` path
builders in `src/xschem.tcl` (`:4025`, `:4071`, `:4101`, `:4126`) read the field
directly and hand back an **empty string** where they owe a `?`. So on the guard
path `raw->level` is set to the index `sch_waves_loaded()` just reported and
`raw->schname` is left alone — the binding does not move off the stack, which is
all R110a ever claimed. Pinned by group I (SEL70-SEL74).

**R110b — the re-stamp re-primes the case-mode comparison**, for the reason
`raw_read()` gives at its own call (`src/save.c:1391`): after a re-bind the
current schematic **is** the raw's own one, and that is the one moment the
comparison is answerable. Without it a verdict computed against cell A survives
as `raw->sch_case_mode` and is **replayed** as this design's answer by the
descend arm of `raw_case_mode_schematic()` (`src/save.c:2877-2883`). It costs
one schematic walk per re-bind, the same price the read path already pays, and
because of R110a it only runs when a re-bind actually happens.

**Coverage — corrected by the item-1 fix round.** This paragraph first claimed
the re-prime was *"covered by `test_raw_case_mode` staying green (277 checks)"*.
That was false and was measured to be false: deleting
`raw_case_mode_schematic(xctx->raw)` from `raw_restamp_design()` left
`test_raw_case_mode` at 277/277 **and** `test_results_select` at 49/49 — the
whole ruling could be removed from the binary with zero red. It now has a real
check, group **G** (SEL58-SEL63) of `tests/headless/test_results_select.tcl`:
read a raw under a cell whose labels give a decidable verdict (`fold`), load an
unrelated hierarchy, re-read there, **descend** — which is the only state in
which `raw_case_mode_schematic()` replays `raw->sch_case_mode` instead of
recomputing (`src/save.c:2877-2883`) — and assert the answer is that hierarchy's
own `unknown`. With the re-prime removed it reads `fold`, the first cell's
verdict, replayed for a design that has nothing to do with the file.

**R110c — CREW RULING, 2026-08-19 (item-1 fix round). The re-bind is opt-in, and
only the `read` VERBS opt in.** `src/draw.c` reaches the same `what == 1` dedupe
arm at ~14 sites, passing the graph rect's `autoload` (1, or 33 with the warning
bit) purely as a reader-dispatch flag while **painting** a rect. With the
re-stamp unconditional inside `extra_rawfile()`, merely *opening* a schematic
carrying an `autoload=` graph that names an already-loaded raw re-bound that
database to the newly opened cell, and the cell the user had actually read it
under went blind. Measured, item binary vs `HEAD:src/save.c`:

```
                     first cut of R110      pristine / with R110c
read under cellA     loaded=0  idx=1        loaded=0  idx=1
open graph cell      loaded=0  idx=1  <--   loaded=-1 idx=-1   (F4 blindness)
back on cellA        loaded=-1 idx=-1 <--   loaded=0  idx=1
```

That is 0509's own symptom recreated one door along, and it contradicts driver
ruling **U10** (*graph rects with `autoload=` are left alone*). So `what` gains
bit 6, `RAW_READ_REBIND` (`src/xschem.h`), set by `xschem raw read`,
`raw table_read` and `raw vcd_read` (`src/scheduler.c`) and by nothing in
`src/draw.c`. `raw_case_reread()`'s read does not set it either, and does not
need to: it deletes the slot first, so the dedupe arm is unreachable from there.
Pinned by group **F** (SEL51-SEL57), which is real under X and vacuous under
`--nogui` (`xschem draw_graph` is `has_x`-gated) — the audit arm has X.

**It is not the only fix, and the alternative already ships.**
`xschem set raw_level <n>` (`src/scheduler.c:12275-12297`) writes *both*
`raw->level` and `raw->schname` from Tcl, bounded to `0 <= n <= xctx->currsch`,
and is already used by `open_sub_schematic` and `hi_descend`'s new-window arm.
A Tcl-only `results::select` could therefore re-bind with
`xschem set raw_level [xschem get currsch]` and ship with **no C change at all**.
R110 is still preferred — it makes the verb correct for every caller rather than
for the one that remembers to follow up — but §17 Q1 may rule otherwise, and a
C-free v1 is a real option.

**R110d — CREW RULING, 2026-08-19 (item 3). The THIRD verbatim copy of the
"file found: switch to it" branch, in `new_rawfile()` (`src/save.c`), re-stamps
too — unconditionally.** Item 1 fixed the two copies inside `extra_rawfile()`
and closed 0509 naming this one, with no reproducer built either way. It IS
reachable with a stale stamp, measured on the shipped verb and the pristine
binary:

```
load cellA ; xschem raw new hist.raw distrib vsweep 0 1.0 0.1
   -> rc=1  raw loaded=0   raw index vsweep=0
load cellB (unrelated)          -> raw loaded=-1  index=-1   (F4, by design)
xschem raw new hist.raw ...     -> rc=0  raw loaded=-1  index=-1
```

*"Build me this dataset, here"* found the name already taken, made it current,
and left it bound to `cellA` — so the `xschem raw add` / `xschem raw set` calls
that always follow write into a database no lookup in this design can see.

**Who reaches it — corrected by the fixer round.** This ruling first justified
itself with the *shipped* launcher, on the grounds that its dataset name is the
constant `distrib` (`xschem_library/ngspice/autozero_comp.sch:542`), so two
designs carrying it would collide by construction. **That is false and the
measurement says why:** the launcher's FIRST line is
`xschem raw_read $netlist_dir/<cell>.raw`, which clears the whole registry
(`extra_rawfile(3, …)`) and takes the previous design's `distrib` dataset with
it, so the `xschem raw new distrib distrib …` further down always **creates**
(rc 1) and never finds. Measured on the item binary: cellA `raw_read` →
`raw new distrib` → rc 1, slots `{0 an.raw tran} {1 distrib distrib}`; load
cellB, `raw_read` → slots `{0 an.raw tran}` only, `distrib` **gone**;
`raw new distrib` → rc 1 again, never 0. R110d itself stands on what remains
true: `xschem raw new` is a documented Tcl verb
(`doc/xschem_man/developer_info.html`) and a Tcl author calling it twice with
one name and no intervening clear reaches the branch — which is the sequence
group W drives, and is exactly the measurement quoted above.

**Unconditional, unlike the two `extra_rawfile()` arms, and that is not an
inconsistency.** `RAW_READ_REBIND` exists because `src/draw.c` reaches those
arms while merely painting a graph rect (R110c/U10). `new_rawfile()` has exactly
**one** caller in the tree — the `xschem raw new` verb in `src/scheduler.c` —
and a Tcl verb is a user gesture by definition; `grep -rn new_rawfile src/` is
the whole audience. **The return value is unchanged**: `0` still means "already
loaded" (SEL189 pins it, and goes red if the branch starts returning 1). Pinned
by group W (SEL186-SEL192).

**R111** `xschem raw switch` keeps its current behaviour and does **not**
re-stamp. Switching is navigation between things already bound; re-binding is
what `read` is for. This is the same separation
`doc/claude/specs/mixed_signal_signal_browser.md` RULING D5-7 makes when it rules
that `raw switch` deliberately does not touch the annotation array.

**R112** `extra_rawfile()`'s header comment (`src/save.c:1833`, *"return 1 if
sucessfull, 0 otherwise"*) gains the distinction it currently hides: what the
return value means when the file was already loaded.

**Non-goal here:** relaxing `sch_waves_loaded()` itself (issue 0509 candidate 2).
It has **52 call sites** across seven files (`draw.c` 21, `scheduler.c` 11,
`token.c` 10, `save.c` 4, `hilight.c` 3, `actions.c` 2, `callback.c` 1);
widening the gate is its own change with its own audit. R110 buys the
whole feature without touching it.

### 3.2 What the verb layer must not do

**R113** No new C data structure. No second registry, no "results list" in
`Xschem_ctx`. The selection is `extra_idx` and nothing else (F3).

**R114** No new top-level `xschem` command. A sub-verb lands in the existing
`raw` arm's `argv[2]` chain (`src/scheduler.c:10332ff`, reached from
`xschem_cmds_r`) — see §5.

---

## 4. The resolver — four statuses

Copied deliberately from `doc/claude/specs/simulator_profiles.md:515-534`, which
solved the same problem for a stored simulator-profile selection: **a stored
selection must never make a session unopenable.** Every status still returns
something usable.

**R201** `results::resolve {state}` answers one of four statuses. The third
column is what the caller gets *anyway*.

| status | when | what is returned |
|---|---|---|
| `default` | the state names no result | the derived path (`ase::last_rawfile`), or `{}` |
| `ok` | the named result exists and is readable | that path |
| `stale` | the named result exists but its content verdict says it is not a usable result (constants-only, zero points), **or** its mtime is older than the netlist it was produced from | that path, plus the reason |
| `invalid` | the named result no longer exists on disk | fall back to the derived path, **never** an error |

**R202** `stale` is reported and **still selected**. A user who deliberately kept
last night's run is not wrong; the sentence says why it looks old. `invalid`
falls back silently to the derived path and says which happened — this is exactly
`ase::ui::viewer_restore`'s existing shape (absolute-ise → `file isfile` → else
`ase::last_rawfile`), which is the model `results::resolve` copies. **That
hand-written shape is GONE as of item 6** — `viewer_restore`
(`src/ase_window.tcl:4441`) now asks this resolver, so the model and its copy
are one proc again (R604, §8.1). The resolver itself is a new **pure** proc in
`src/results.tcl` (R204), and `viewer_restore` is re-expressed on top of it.

**R203** The content half of `stale` is `ase::raw_content_verdict {path}`
(`src/ase.tcl:2794`), which parses the first plot header and refuses a
constants-only or zero-point raw with a full sentence. **It is the only
content check in the tree, and only `ase::attach_dbs` calls it.** Do not
reimplement it.

**R204** The resolver is **pure** — it reads the filesystem and returns a dict.
It never touches the registry. The caller decides whether to act.

### 4.1 RULINGS — the resolver's exact shape (item 2, 2026-08-19)

Taken by the crew per `doc/claude/results_batch/DECISIONS.md` §C: these were
genuinely open in §4 above, there is no human in the loop, and the code cannot
be written without answering them. Evidence for each is in
`doc/claude/results_batch/receipts/02-results-tcl-resolver.md`.

**R201a — `state` is a dict of RESOLUTION INPUTS, not an ASE session state.**
Every key optional, unknown keys ignored:

| key | meaning |
|---|---|
| `rawfile` | the named result, exactly as stored; may be **relative** (R602's saved form), resolved against `rundir` |
| `rundir` | what a relative `rawfile` is resolved against |
| `derived` | the fallback path |
| `key` | an ASE session key — supplies `derived` via `ase::last_rawfile` when `derived` is absent |
| `netlist` | the netlist the result was produced from; present → the mtime half of `stale` is checked, absent → only the content half |

An ASE session state was rejected as the argument type for two measured
reasons. It would make the resolver reach into `ase::` to find its own inputs,
which kills R204's purity claim and makes the proc untestable without a live
session and a backend hook. And *"the state"* was already ambiguous between two
dicts: the saved `rawfile` lives in the **viewer** sub-dict
(`wviewer::snapshot`, `src/wave_viewer.tcl:4101`), not the state root, which is
why `ase::ui::viewer_restore` (`src/ase_window.tcl:4441`) reads `$vd` for the
path and `$st` for the rundir. A caller holding both passes both; a caller
holding only a path passes `[dict create rawfile $p]`.

**R201b — the returned dict's key set is fixed**: `status`, `path`, `named`,
`derived`, `why`, `reason`, `msg`. `path` is R201's third column — *what the
caller gets anyway*. `named` is the absolute-ised named result and is kept even
when the file is gone, because R804-class sentences name it. `reason` says
which half fired (`content` | `mtime` | `missing` | `unreadable` | `{}`), so a
caller can distinguish them without re-parsing `why`. `msg` is the one sentence
and is never empty.

**R201c — a file that exists but cannot be READ is `invalid`, not `stale`.**
R201's table says `ok` requires "exists **and is readable**" but assigns the
unreadable case to no status. It belongs with `invalid`: R202 makes `stale` a
status the user may still **select**, and an unreadable file cannot be selected
at all, so reporting it as stale would offer a choice that cannot be honoured.
`reason unreadable` keeps it distinguishable from `reason missing` for a caller
that wants to say which.

**R201d — the derived path is existence-gated in every status that returns
it.** `ase::last_rawfile` already gates itself (`src/ase.tcl:1952` returns `{}`
unless the file is there); an explicitly passed `derived` gets the same gate.
This is what makes T-H's *"`invalid` yields the derived path when one exists on
disk and `{}` otherwise"* true for both sources rather than only for the ASE
one.

**R201e — `default` is a statement about the STATE, not about the file.** When
nothing is named, the derived path is returned as-is without a content or mtime
verdict. Running the verdict there would report a *derived* default as stale,
which no user chose and cannot act on; the caller that goes on to select it
resolves it again by name and gets the verdict then.

---

## 5. The verb and the Tcl API

**R301** A new sub-verb `xschem raw select <file> [<type>]`, landing in the
`raw` arm (`src/scheduler.c:10332ff`). Semantics, in order:

1. If `(file, type)` is already in the registry → `extra_rawfile(2, …)` (switch)
   **and** re-stamp per R110's rule, because the user asked for *select*, not
   *navigate*. `<type>` is therefore **required**, or must be resolved from
   `results::list` first and the slot **index** passed instead — the switch-by-name
   loop refuses without it (R101, L10).
2. Otherwise → `extra_rawfile(1, …)` (read + make current + stamp).
3. Never clear. F7.

Return: `2` selected-by-switch, `1` selected-by-read, `0` refused. **Three
values, not two** — this is the distinction R112 says `read` should have had.

> **Corrected 2026-08-19 (item 3).** This line read *"`1` selected-by-switch,
> `2` selected-by-read"* — the two values the other way round from
> `doc/claude/results_batch/PLAN.md` §4 item 3 and from the item brief, which
> both say **2 = switch, 1 = read**. Two documents against one, and 1-for-read
> is also the value `extra_rawfile()` already returns for the read it performs,
> so the majority spelling is the one implemented and this sentence is the one
> that moved. Nothing had been written against the old spelling.

### 5.0 RULINGS — the sub-verb's exact shape (item 3, 2026-08-19)

Taken by the crew per `doc/claude/results_batch/DECISIONS.md` §C. Evidence for
each is in `doc/claude/results_batch/receipts/03-raw-select-subverb.md`; the
implementation is `raw_select()` in `src/save.c`, dispatched from the `raw` arm
of `src/scheduler.c`.

**R301a — SELECT IS A RUN-LEVEL GESTURE: IT RE-BINDS EVERY SLOT OF THE CHOSEN
RUN, not only the analysis named.** U11 rules that one run produces one result
and that analyses are *dimensions inside* a result, while the engine keys the
registry on `(rawfile, sim_type)` — so one `multi.raw` holding a dc and a tran
is **two slots and one result**. §3.1's own boundary note already assigns this
to `select`: *"`read` is an analysis-level verb … re-binding every slot of the
chosen run is that verb's job under U11"*. Measured on `cellB` with both
analyses of one file read under `cellA`:

```
raw switch multi.raw dc   -> loaded=-1  index v(m1)=-1
raw switch multi.raw tran -> loaded=-1  index v(m2)=-1
raw select multi.raw tran -> rc=2  loaded=0  index v(m2)=1
raw switch multi.raw dc   -> loaded=0   index v(m1)=1     <-- the sibling, re-bound
```

Without it, selecting the run in `cellB` leaves the sibling answering `-1` to
every name there, and a `raw switch` to it — navigation, which by **R111** does
not re-bind — drops the user on a blind database *inside the result they just
chose*. The re-stamp is `raw_restamp_design()`, so **R110a's guard applies to
each sibling in turn**: a slot already bound somewhere on the current stack is
left alone. The match is `strcmp` on the stored spelling, the same rule the
registry itself dedupes by, so two spellings of one path are two runs here as
everywhere else. Pinned by group S (SEL165-SEL172).

**R301b — `<type>` IS OPTIONAL.** R301 above calls it *required, or resolve the
index from `results::list` first* because it assumed the `what == 2` by-name
switch loop, which is guarded `if(file && type)` (**L10**). This verb does not
use that loop: it goes through the `what == 1` dedupe arm, which matches on the
**filename alone** when the type is NULL. So a caller holding only a path — which
is exactly what `results::select` is handed, and what the MRU and the
persistence slot store — reaches the already-loaded slot without resolving its
analysis first. An explicit type still names ONE analysis of the run, and is
still required to *read* a table or a VCD that is not loaded yet, because the
type is the reader dispatch key (issue 0290).

L10 is not merely awkward, it is silently wrong, and the check that says so
(SEL162) measures it rather than asserting it: with three slots loaded and
`an.raw` current, `xschem raw switch <an.raw>` with no type returns **1** and
leaves `bn.raw` current — the by-name arm never ran, the "switch to next" arm
did. `raw select <an.raw>` with no type stays on `an.raw`.

**R301c — the verb is ONE `extra_rawfile()` CALL, and the read/switch
distinction is computed, not branched on.** R301's step 1 and step 2 describe
two calls; the `what == 1` dedupe arm with `RAW_READ_REBIND` set *is* step 1
byte for byte (it moves `extra_prev_idx`/`extra_idx`/`xctx->raw` exactly as the
`what == 2` by-name arm does, then re-stamps). Routing through one call avoids a
**third** copy of the "is this file already loaded?" loop — the rule is written
twice already and that duplication is half of why issue **0509** survived — and
keeps the `spectrum`/`sp` → `ac` aliasing in one place. Which of the two
happened is then computed the way `extra_rawfile()`'s own header prescribes
(compare `xctx->extra_raw_n` across the call) **with the adopt correction**: the
first `extra_rawfile()` call in a context that has a base raw and an empty
registry also adopts that base into slot 0, so the count moves by one for a
reason that has nothing to do with the requested file. `xschem raw_read` — the
~293 launcher sites' verb — leaves exactly that state, so this is the common
case, not a corner: without the correction a select of the file `raw_read` just
loaded reports itself as a **read**. Pinned by group U (SEL178-SEL180), and it
is also why **T-A** is worded *"present exactly once in the registry"* rather
than *"adds exactly one slot"*.

**R301d — a select of a one-point OP/DC database publishes it, exactly as
`raw switch` does.** The `switch` arm's `update_op()` follow-up
(`src/scheduler.c`) is repeated in the `select` arm: making an operating point
*the result you are working against* is precisely when its numbers belong on the
schematic. Measured: `raw read op.raw op` publishes nothing
(`ngspice::get_voltage o1` → `?`), `raw select op.raw op` publishes `1.5`.
Pinned by SEL193/SEL194, the first of which is the contrast that makes the
second non-vacuous.

**Not copied from the `switch` arm: its gate.** That arm tests
`raw->allpoints == 1` on the local `Raw *raw` captured at the TOP of the
dispatcher — i.e. the database that was current *before* the switch — while
reading `xctx->raw->sim_type`, the one *after*. Measured on the pristine binary:
with a 3-point tran current, `raw switch <op.raw> op` does **not** publish. The
`select` arm therefore gates on `xctx->raw` after the call. The `switch` arm was
left alone (R111, and scope), and the observation is recorded in item 3's
receipt with its reproducer rather than filed. **The `allpoints == 1` term is
pinned in BOTH directions** (fixer round): SEL194 proves the gate fires, SEL200
proves it does not over-fire — widening `== 1` to `>= 1` left all 197 checks
green while a 3-point dc sweep started annotating the schematic with its first
point (`ngspice::get_voltage o1` went from `?` to `9`).

### R301e–R301h — the fixer round, 2026-08-19

Four rulings taken while fixing the item's confirmed review findings. All four
narrow `select`; none of them changes `raw read`, `raw switch` or
`extra_rawfile()`, which keep their behaviour and their audits (R111, R112).

**R301e — A REFUSED SELECT RESTORES BOTH HALVES OF THE CURSOR.** R113 rules that
the selection *is* `extra_idx` **and** `extra_prev_idx` (SEL143 is written on
that), so T-D's *"a failed selection leaves the previous selection intact"* has
to hold for both. It did not: `extra_rawfile()`'s two restore-on-failure arms put
`xctx->raw` back and then do `xctx->extra_prev_idx = xctx->extra_idx;`, which
silently destroys the switch-back cursor. Measured — select `an.raw`, select
`bn.raw`, refuse `nope.raw`, then `xschem raw switch_back` lands on **`bn.raw`**
instead of `an.raw`, i.e. the gesture becomes a no-op after a mistyped path.
`raw_select()` now saves `xctx->raw`/`extra_idx`/`extra_prev_idx` before the call
and restores them on every refusal (guarded on the registry surviving the failed
read at all — `read_rawfile()` can dispose of every database on its way out).
**Deliberately not fixed in `extra_rawfile()`:** `xschem raw read` has the same
wart, and repairing the shared failure path is R112's item with R112's audit.
Pinned by SEL196 (control), SEL197, SEL198.

**R301f — A TYPELESS SELECT PREFERS THE ANALYSIS YOU ARE ON.** R301b makes
`<type>` optional precisely so item 4 can pass a bare path (the MRU and the
persistence slot store a path only) — and the `what == 1` spice dedupe matches on
the **filename alone** when the type is NULL, so with one run read twice a bare
select landed on the run's FIRST slot. Measured: `raw read multi.raw dc`,
`raw read multi.raw tran`, `raw select multi.raw` → `sim_type` went `tran` → `dc`
and `raw index v(m2)` went `1` → `-1`; the user asked to select the run they were
plotting from and lost the analysis inside it. `raw_select()` now fills the type
in from the current database when — and only when — the current database already
names the requested file. Every other input is untouched, and SEL163 is the
over-fire guard: with a *different* file current, a typeless select must still
land on the file it names. Pinned by group Z (SEL201-SEL205).

**R301g — AN EXPLICIT NON-SPICE TYPE STILL NAMES ONE ANALYSIS.** The non-spice
`what == 1` arm dedupes on the filename **alone** — it must, because a table or a
VCD has no `sim_type` until its reader stamps one — so `raw select <an ngspice
raw> table` found the `tran` slot and answered **2 = selected by switch**: a
successful selection of an analysis that is not in the registry, which item 4
would push onto the MRU and write to disk as a `(path, type)` pair naming no
slot. Measured: `raw select an.raw table` → 2 with `raw_query sim_type` still
`tran`. `raw_select()` now verifies, on the switch path only, that the database
it landed on carries the requested non-spice type, and refuses (0) with a
sentence otherwise. The other direction needs no guard: a spice type goes through
the spice loop, which compares `sim_type` and refuses by itself; and a *read*
with a non-spice type is dispatched by that same token and stamps it, so it
cannot disagree. Pinned by group AA (SEL206-SEL210).

**R301h — A LEADING `~/` IS EXPANDED.** `xschem raw_read` expands it (its arm's
own `regsub {^~/}`) and `select` is the verb meant to front-end those ~293
launcher sites, so `~/x.raw` must not be the one spelling that works for one verb
and fails for the other — `extra_rawfile()` only runs Tcl `subst`, which does not
expand `~`. Measured before the fix: `raw_read ~/…/an.raw tran` → 1,
`raw select ~/…/an.raw tran` → **0**. Done with the same `regsub`, so both verbs
store the **same** spelling and a slot read by one is found by the other — the
registry dedupes by `strcmp`, so a `~` slot beside a `$HOME` slot would be two
runs of one file. This is the ONE normalisation `select` does: `..` and other
spellings are still two runs (measured, §5.0's note stands), and item 4 must
`file normalize` if it wants more. Pinned by group AB (SEL211-SEL213).

> **Why a new verb rather than fixing `read`.** R110 fixes `read` and is
> required regardless. `select` exists because the *intent* differs: `read`
> is "get this file into memory", `select` is "this is what I am working
> against now", and only the second is allowed to be a user-facing gesture with
> a message, a history push and a persistence write. If the driver rules that
> `read` + R110 is sufficient and `select` is redundant, see §17 Q1.

**R302** Tcl wrapper `results::select {path {sim_type {}} {opts {}}}`, in a new
`src/results.tcl`, returning a dict `{ok 0|1 how read|switch|refused path ..
type .. status .. msg ..}`. It is the **one** place that:
- runs the resolver (§4),
- calls `xschem raw select`,
- pushes to the MRU via `wviewer::rawhist_push` (fixing issue 0216's shape for
  this path at least),
- calls `wviewer::casemode_invalidate` / `casemode_reapply` (R104),
- refreshes a browser if one is showing this context
  (`wviewer::browser_refresh $token 1`),
- writes the persistence slot (§8),
- emits the message (§10).

**R303** Every other caller goes through `results::select`. §18 enumerates the
paths that will still bypass it and names them, following
`doc/claude/specs/simulator_profiles.md:2408-2427`'s idiom.

**R304** `results::list {}` returns the registry as
`{{idx .. path .. type .. cur 0|1 label ..} ..}`, built on
`wviewer::rawinfo_parse` (`src/wave_viewer.tcl:2393`) and `wviewer::db_label`
(**`:2414`** — re-grepped 2026-08-20 by item 10, handed on by item 9's
reviewers; `:2401` was the pre-batch line and `PLAN.md` §2 had already been
corrected). **There must not be a second parser for `xschem raw info`** — issue
**0507**'s ruling. `raw_is_loaded` did **not** survive it: **R304c** removed the
proc (item 9), so there is nothing left to re-express.

### 5.1 RULINGS — the two registry readers (item 2, 2026-08-19; R304c/R304d added by item 9, 2026-08-20)

**R304a — `results::list` lists EVERY registry slot, VCD and table included.**
R102 says a VCD is not a selectable *result*, but `results::list` is the
registry **reader**, not the policy: a dialog that wants analog only filters on
`type` (item 7), and a caller asking *"is this path already loaded?"* — which is
exactly what `results::select` asks before choosing between `read` and `switch`
(R301) — must see every slot or it will re-read one it already has. Hiding
slots here would put R102's policy in the one place that cannot express an
exception.

**R304b — the `cur` column MARKS the current slot, it does not MOVE it.** The
list comes back in the engine's own order with `cur 1` on one row, rather than
current-first. `wviewer::signal_list_all` sorts current-first because it is
building a *tree for a human*; `results::list` is an API whose `idx` must stay
the engine's index, since R301(1) and L10 pass that index back to
`xschem raw switch`.

**R304c — the by-word parser is deleted, and T-K is a grep over four shapes.**
Issue **0507** left the choice open: (a) delete `raw_is_loaded`, or (b) keep the
name and re-express it on `results::list`. **Removed.** The measurement that
decided it, and it is a history measurement, not a taste one:

- **Its four callers were all in the graph dialog, and upstream itself already
  replaced them with an ENGINE call.** `23092fc9` added the proc together with
  four `if {[raw_is_loaded [.graphdialog.center.right.rawentry get] …]}` guards;
  `ad96e222` deleted all four and moved the same question into
  `graph_fill_listbox` as `elseif {[xschem raw loaded] != -1}`. Tcl stopped
  asking this question years ago, and it did not stop by accident.
- **This batch asks it in C too.** `results::select` does not test "is it already
  loaded?" and then branch: it calls `xschem raw select` (item 3, R301b), whose
  `what == 1` dedupe arm makes the read-vs-switch decision inside
  `extra_rawfile()`. The one Tcl-side identity question that remains — *which
  spelling of this path is the registry's* — is `results::_engine_spelling`
  (R302a), built on `results::list`.
- So (b) would have shipped a proc with **zero callers and no caller in
  prospect**, and a second name for a question `results::list` already answers.

**What T-K asserts, precisely: NO BY-WORD PARSER OF `xschem raw info` SURVIVES.**
It is **not** "exactly one parser" — LINE-wise readers exist and every one is
legitimate (`wviewer::rawinfo_parse`, `ase::raw_indices`, `ase::raw_current`,
the inline per-line regexp in `ase.tcl`'s gesture path at `src/ase.tcl:3241-3245`
— a **fifth** reader, which SEL466 does not pin because SEL466 names the four
*procs*, not a total — and the test helpers). The grep runs over
**comment-stripped** source, because item 2's SEL82 was satisfied by a comment
that merely *named* `rawinfo_parse` while a hand-rolled parser ran underneath
it, and item 8 hit the same class again. **Both comment forms are stripped:**
whole-line `#` and Tcl's trailing `;#`. The fixer round measured that stripping
only the whole-line form made `set rows [results::list] ;# NOT the old foreach
{n f t} [lrange [xschem raw info] 2 end]` — prose of exactly the kind this batch
has written into five files — read as live code and reddened SEL461/SEL462 for
files carrying no parser at all.

**Four shapes are covered:** (a) a word-range over the blob; (b) a
three-variable `foreach` whose list operand is the blob; (c) the blob captured
whole into a variable and then consumed by `foreach`/`lrange`; and (d) that same
capture consumed by **index or length** — `llength $blob`, `lindex $blob $i`,
`lreplace $blob 0 1`, `lassign $blob i p t`. Shape (d) was added in the fixer
round: with only (a)-(c), 0507's defect rewritten as a
`for {set i 2} {$i < [llength $blob]} {incr i 3}` index walk — planted in
`src/xschem.tcl` by a reviewer, and answering **0** where the truth is **1** for
a rawfile path containing a space — left the suite 374/374 ALL PASS. A
whole-blob `llength`/`lindex` is a by-word read by definition; every legitimate
reader splits on `"\n"` first, and `lindex [split $txt "\n"] 0` (which is what
`ase::raw_current` does) does not match.

**DECLARED LIMITS.** T-K is a grep test, not a static analyser. Two holes are
named rather than hidden:

1. A proc that took the blob as a **parameter** and split it by word inside its
   body evades it — no line of it mentions `xschem raw info` at all.
2. The captured-variable arms (c)/(d) are **proc-scoped**: the detector clears
   its taint list at every `^proc` line, so a capture at file scope whose
   by-word consumption sits after an intervening `proc` definition evades them.
   That scoping is deliberate and was measured. Without it the taint on a
   variable **name** ran to end of file, and since the names actually captured
   in this tree are `info` (`src/wave_viewer.tcl:2458`, `src/ase.tcl:3241`) and
   `txt` (`src/ase.tcl:2936`, `:2944`, `src/results.tcl:289`) — two of the
   commonest local names in Tcl, one of them in an 18,671-line file — any later
   unrelated `lrange $txt …` or `foreach {a b c} $info …` in a **different**
   proc reddened SEL461 and named the wrong file. A false red that points a
   maintainer at innocent code is worse than the narrow miss above.

The detector's negative lookahead is load-bearing — without it
`lrange [split [xschem raw info] "\n"] 1 end-1`, a LINE-range over already-split
lines used correctly by four headless suites, matches (measured: four innocent
files went red).

**R304d — a deletion from `src/xschem.tcl` is LINE-NEUTRAL or it pays for 478
re-greps.** Measured 2026-08-20 —

```sh
grep -rhoE 'xschem\.tcl[:# ]*[0-9]{3,5}' doc/ src/ tests/ \
  | grep -oE '[0-9]+$' | awk '$1>6997' | wc -l      # -> 478
```

— **478** citations point below the proc's old position, so removing its 18
lines outright would have staled every one of them: L9's twin, at scale.
The proc was therefore replaced by an **18-line comment** recording what it was,
why it was wrong and why it is gone, and the neutrality is asserted
(`test_results_select` SEL471).

**SEL471 STATES IT RELATIVELY, and that is a ruling of its own.** Its first
draft also pinned `proc waves` at `6373` and `proc load_raw` at `16874`; a
reviewer showed that **one unrelated comment line added anywhere above line 6373
of a 19,046-line file** turned a results-selection suite red, and four of the
eight prior items in this batch edited `src/xschem.tcl`. A permanent check
cannot pin a historical line count of a file other items legitimately edit. What
it can pin is the **tombstone's shape**, and that is now the whole check, every
element measured relative to `proc set_rect_flags`: the 18 lines above it are
all comment lines (reds if one is deleted); the 19th line up is **not** a
comment (reds if the block grows — the half the absolute anchors used to carry);
and the block names `raw_is_loaded` (reds if some other comment drifts into the
window). `18` is not arbitrary — it is the line count of the proc it replaced,
`git show 226302f9:src/xschem.tcl | sed -n 6980,6997p`.

The rule generalises: **a removal from a heavily-cited file states its citation
cost, and either pays it or stays line-neutral — and the check that proves it
must be stated relative to the removal site, not against absolute line numbers
elsewhere in the file.**

**R305a — R103's third part is asked of the ENGINE, not re-derived in Tcl.**
`results::current` returns `{}` unless `xschem raw loaded` (`src/scheduler.c:10448`
→ `sch_waves_loaded()`, `src/draw.c:2825`) answers `>= 0`. Two properties of
that answer look like bugs from Tcl and must not be "fixed" at the call site:
an **ancestor** match counts, so a raw read at the top still resolves after a
descend (this is R110a's basis, item 1 §2); and **level 0 is a legal answer**,
so the test is `>= 0` and never `!= 0`. Re-deriving the comparison in Tcl would
be a second copy of a rule with 52 C call sites.

**R305b — R102 gates `results::current`: a VCD or a table slot is not a
selection.** RULED by the crew 2026-08-19 in the item-2 FIX ROUND, because
neither the code nor R304a covered it and the shape is reachable from the real
run path. Measured: with an ascii transient raw and a VCD both read into one
context, `xschem raw info` reports `1 current` on the **VCD**, and
`results::current` was returning that row as *the selected result* — which
R305 then hands to the Calculator's Results Dir row (a `.vcd` in a field that
names the result Evaluate reads). `ase::attach_dbs` produces exactly this
ordering: it reads the analog raw and **then** the VCDs (L8), switching back to
slot 0 only `if {[llength $got]}`.

So `results::current` returns `{}` when the current slot's `type` is not an
analog result. It does **not** skip past it to another slot: the selection *is*
`extra_idx` (R103, F2), and "the selection is a database that is not a result"
is honestly answered by "there is no selected result", not by silently
promoting a slot the user did not choose.

**Where the predicate comes from, and the one token that is written down.** The
authority for R102's *"not a VCD or a table"* is `raw_type_is_non_spice()`
(`src/save.c:1622`), driven by `raw_reader_table[]` (`:1610-1613`) — the same
table that picks the reader. **It has no Tcl verb.** `xschem raw is_digital
<type>` (`src/scheduler.c:10450`) exposes the table's *other* column and answers
a deliberately different question: `test_backannotate_digital` BA12 pins
`is_digital table` -> **0**, "an ascii TABLE is not: it is columns of real
numbers, an analog result by another reader — the ruling is about logic levels,
not about 'anything that is not a spice raw'". So the engine can answer the VCD
half of R102 and not the table half. `results::_is_result_type` therefore asks
the engine first and names exactly one reader token, `table`, in one place with
its C predicate cited beside it. When a `non_spice` question reaches Tcl —
item 3's `xschem raw select` is the natural home for it — that proc becomes a
one-line delegation. Do not copy the token to a second site.

**R305c — DONE, 2026-08-19 (item 3): `xschem raw non_spice [<type>]` exists and
the token is gone.** The verb is the other column of the same reader-table row
as `raw is_digital`, sits beside it in the `raw` arm, and answers
`raw_type_is_non_spice()` directly: `non_spice tran` → 0, `non_spice table` → 1,
`non_spice vcd` → 1, and with no argument, of the current database. It is
deliberately outside the `raw && raw->values` gate, like `is_digital`: *"is this
type non-spice?"* is answerable with nothing loaded at all.
`results::_is_result_type` is now the one-line delegation this paragraph
predicted, and `table` appears nowhere in `src/results.tcl`'s **code** —
SEL185 greps the comment-stripped file and goes red the moment the token comes
back. The distinction that made this necessary is pinned in the same place:
SEL182 asserts `non_spice table` = 1 **and** `is_digital table` = 0 in one
check, so a future "simplification" that collapses the two verbs reds it.

**R305** `results::current {}` returns the selected result's dict or `{}`.
**RULED (§17 decisions 3 and 6): the Calculator's Results Dir row consumes it,
and `calc::results_source`'s `self` arm is removed entirely** — the Calculator
reads the ASE-L session's result and nothing else. **DONE, item 10, 2026-08-20:
§7.1a carries the seven rulings that shape the consumption**, including R503d
(the borrowed read asks this proc rather than `xschem raw rawfile`) and R502a
(a derived path is not an answer, so the old `ase` arm went too). It answers
R103's three-part definition, so it returns `{}` for a
database that is loaded and current but whose stamp does not resolve (F4) —
**a loaded-but-blind database is not a selection.**

### 5.2 RULINGS — `results::select`'s exact shape (item 4, 2026-08-19)

**Nine** crew rulings, all measured, all in `src/results.tcl`, and they are
R302a, R302d, R302e, R302f, R302g, R302h, R802a, R804b and R804c below. A tenth,
**R805b**, belongs to the same item but is written under §10, because it is a
message rule. (An earlier draft of this line
said "six" and then listed eight — corrected in the item-4 fixer round, along
with the section ordering: this block was inserted **ahead** of §5.1, so the
spec's headings ran 5.0, 5.2, 5.1.) The dict R302 fixes
(`ok how path type status msg`) is a **minimum**, not a closed set: `why`,
`reason`, `named`, `resolves`, `channel` and `did` are added beside it, the same
way R201b opened the resolver's.

**R302a — ONE SPELLING PER RUN, and `file normalize` is where it is decided.**
Item 3 measured the hazard and handed it here: `w/an.raw` and `w/../w/an.raw`
**both read**, producing two registry slots for one file, because the engine
dedupes by `strcmp` on the stored spelling; `~/` is the only normalisation the C
verb does (R301h). Two halves, and the second is the one that actually fixes the
duplicate:

1. the path handed to the engine is `file normalize`d, so every caller coming
   through R303's single door arrives in **one** spelling;
2. **before** that, the registry is asked whether some slot's own spelling
   normalises to the same file — and if one does, **the engine's own spelling**
   is what is passed, so the select lands on the existing slot instead of
   reading a second copy of it.

Without (2), a slot some other path created as `w/../w/an.raw` would be
permanently unreachable through `results::select`, which would go on adding a
`w/an.raw` beside it every time; with it, this proc *converges* the registry on
one slot per file rather than merely declining to make it worse. Not done in C:
R113 forbids a new structure and the `strcmp` dedupe is shared by five loops in
`extra_rawfile()`, so changing what those compare is a behaviour change to
`raw read`, `raw switch` and the draw-time autoload walk at once. Pinned by
SEL237-SEL242, whose SEL237/238 re-drive item 3's two-slot measurement as the
control.

**R302h — where "one spelling" STOPS: at a final-component symlink,
deliberately.** Ruled in the item-4 fixer round, because R302a's original
rationale asserted something Tcl does not do — that `file normalize` "resolves
symlinks". It half does. Measured against a real link tree:

| spelling | `file normalize` answers |
|---|---|
| `<d>/real/an.raw` | `<d>/real/an.raw` |
| `<d>/linkdir/an.raw` (link in a **directory** component) | `<d>/real/an.raw` — **resolved** |
| `<d>/linkfile.raw` (link naming the **.raw itself**) | `<d>/linkfile.raw` — **not resolved** |

So `~`, `.`, `..`, relative→absolute, a trailing slash and every symlink in a
directory component converge on one slot; reaching one file both by its real
name and by a symlink *to that file* still makes two. **That boundary is ruled
correct, not tolerated as a gap.** A final-component symlink is a name the user
chose, and the reason to choose one is almost always that it is a **moving
target** — `latest.raw` pointing at whichever run is current. Resolving it would
push the run-specific path into the sentence (R803 labels by `file tail`, so
*"Selected latest.raw"* would silently become *"Selected an.raw"*), into the MRU
`rawhist_push` records, and into R302g's persistence slot — freezing the
indirection the user built expressly so it would not freeze. The cost is one
extra registry slot in that case, which **F7** already accepts as the declared
cost of never clearing. `results::_engine_spelling` and `results::_same_path`
therefore both answer *"same file?"* exactly as `file normalize` answers it, and
no `file readlink` loop is added; a later item wanting link identity needs
dev+inode from `file stat` **and** must answer the label/MRU/persistence
question above first. Pinned in **both** directions: SEL289 (the intermediate
link converges — red when `_engine_spelling` is neutered) and SEL290 (the final
component does **not** — red when a `file readlink` loop is added, which is the
"fix" this ruling declines).

**R302d — the side effects follow the ENGINE, not `ok`.** Whenever
`xschem raw select` returns non-zero the current database *has* changed, so the
case-mode cache is stale, the browser's inventory is stale and the MRU owes the
entry — whether or not the stamp resolves here and whether or not what landed is
a *result* (R102). Gating them on `ok` would leave a window showing the **old**
raw's signal list over the **new** raw's waveforms, which is the exact defect
`browser_refresh $token 1` was added to `rawbar_load` to stop. Only a **refused**
select (rc 0) runs none of them, because then nothing moved (F7, T-D). Measured
with no shim at all by SEL287: a `.vcd` select answers `ok 0` and still
invalidates the case-mode cache.

**R302e — `results::select` does NOT switch context.** The selection happens in
whatever `Xschem_ctx` is current and standing in the right one is the **caller's**
job — `rawbar_load` already does `switch_ctx` (a move, not an 0173 loan) before
it reads, and R501 keeps that. Two reasons: the registry is per-context (tabs do
not share one — `src/xinit.c:1938`, `:2204`, `:2209`), so *which* context is a
caller decision and not a resolver's; and a bracket here would put an
enter/leave pair around the engine call, which is precisely the window **L7**
forbids anything to redraw in. `opts token` is therefore used only for the
viewer-side follow-ups and the channel, never to decide where the select lands.

**R302f — `ok` is `results::current`'s answer, not a second opinion.** `ok 1`
means all three parts of R103 hold **and** R102's type gate passes — which is
exactly what `results::current` returns — so `ok 1` and a non-empty
`results::current` can never disagree, which is what T-I needs. The F4 term
(`xschem raw loaded >= 0`) is conjoined explicitly as well, and that is **not**
redundant bookkeeping: the sentence branches on it, and a dict whose `msg` says
*"no signal names will resolve"* beside an `ok 1` is the defect R804 names.
One measurement, one verdict, one sentence.

**R302g — the persistence write is a named seam, `results::persist {path type
opts}`, and item 6 fills its body.** At item 4 it was a documented no-op
returning 0, which was honest: nothing had ever written `viewer.rawfile`. It is
handed the **engine's own** spelling and sim_type plus the caller's whole
`opts`, must not throw, and returns 1 when it wrote. Item 4 pins the **call**,
not a write (SEL269-SEL272).

> **Item 6 FILLED IT AND CORRECTED THIS DESCRIPTION — see §8.1, R602a.** The
> sentence *"returns 1 when it wrote"* survives, but what it writes is a
> **record of the choice**, not the state: `viewer.rawfile` reaches disk through
> `wviewer::snapshot`, which rebuilds the viewer sub-dict from the live window,
> and `ase::session_dirty` is derived, so writing the state from inside a
> selection would both be overwritten at save time and mark the session dirty on
> every Location-bar load. The persisted value is read from the **engine** at
> snapshot time; this record is the fallback for the one state the engine cannot
> answer (F4). Measured: with this proc neutered entirely, the acceptance flow's
> stored `viewer.rawfile` is unchanged, because the run path never calls it.

**R802a — the channel default is derived from what the caller gave, and "no
channel" is a legitimate answer.** `opts host` names it outright
(`viewer`/`ase`/`calc`/`none`); with no `host`, a `token` means the viewer
sidebar and an ASE session `key` means `ase::echo`, and a caller that gave
neither gets **no emission at all** — the sentence is still in the returned
`msg`, which is what a headless caller and the dialog's Status region both read.
The alternative — falling back to a global channel when the named one is
unreachable — was rejected: a message landing in the CIW because a sidebar was
not packed is exactly the *"never the status bar directly"* R802 exists to stop.

**R804b — the F4 state is measured UNREACHABLE through `xschem raw select`, and
the guard stays.** Measured 2026-08-19 on the item-3 binary: read `an.raw` under
cellA (`raw loaded` 0), `xschem load` cellB (`raw loaded` -1),
`raw select an.raw tran` → 2 and `raw loaded` **0** again — because `raw select`
sets `RAW_READ_REBIND`, so a dedupe hit re-stamps (R110/R110c) and a fresh read
is stamped by the reader itself. A table and a VCD were measured the same way and
also came back `>= 0`. R804's sentence was written before R110 landed and this is
what R110 did to it. The guard is kept, and it is not decoration: R111 rules that
`raw switch` deliberately does **not** re-bind; `draw.c`'s autoload walk reaches
the same dedupe arm without the re-bind bit (U10); R303 makes this the single
door for item 6's restore path and item 7's dialog; and it is what makes `ok 1`
mean *"signal names resolve here"* rather than *"the engine did something"*.
Because it is unreachable through the verb, T-M drives it through the
`results::_resolves_here` seam — shimmed, as **L1** prescribes — with SEL247/248
pinning that seam to `xschem raw loaded` so the shim is not the only evidence.

**R804c — the "was read against X" clause needs a caller, because
`raw->schname` has no Tcl accessor.** Measured: the whole `xschem raw` /
`raw_query` arm answers `add annot datasets del index list points pos_at rawfile
rename sim_type value values vars view_armed view_keys` and **no `schname`**;
`xschem get raw_level` gives the level only, and in exactly the state this
sentence describes that level indexes a *different* stack, so
`xschem get schname <lev>` would name the wrong cell with total confidence. Item
4 is Tcl-only, so the accessor is filed as issue **0514** rather than added
there. The cell you *are* in comes from `xschem get schname` (tail, per R803);
the cell it was **read against** comes from `opts read_against` when the caller
knows it, and when it does not the clause is dropped and the sentence keeps the
load-bearing half — *"no signal names will resolve until you return to the
schematic it was read from."* Both forms are pinned (SEL251, SEL252).


---

## 6. `Results ▸ Select…` — the ASE-L dialog

**R401** A new entry `Select…` in ASE-L's existing Results menu, above
`Direct Plot` (`src/ase_window.tcl:526-535` — the menu has **no** separator
today, so one is added if `Select…` is to be grouped apart). Hand-built plain
Tk `$top.mb.results add command` — ASE-L's menubar is not generated from
`actions.csv` (only the main File menu is, via `build_menu_from_table`,
`src/xschem.tcl:17116`), so **no CSV row is needed**. A key chord would need one,
plus `action_registry[]` in `callback.c`; §16 says v1 has no chord.

**R402** The dialog is a **modeless** ASE-family window — no `grab`, no
`tkwait` — following `src/ase_window.tcl:1454`'s stated doctrine ("no
grab/tkwait — which is what keeps them test-drivable"). It is **not** the
vwait-latch chooser idiom used by `libmgr::view_dialog` / `alt2::choose_dialog`,
and **not** the `tkwait window` idiom of `save_as_cellview_dialog`. Both exist;
this one belongs to the third family because it is a browsing/selection dialog
rather than a blocking question — the ASE host does also carry grab+`tkwait`
modals (`ask_save_close`, `bus_dialog`), so "the host's family" alone does not
decide it.

**R403** Widget vocabulary is the ASE house mix: plain Tk chrome (frame, label,
entry, button, menu) painted from `ase::palette` through `ase::ui::apply_theme`
with the named ASE fonts, plus **ttk where a table or a combobox is needed**
(`ttk::treeview` with `-style Ase.Treeview`, `ttk::combobox`) — the Location bar
itself is a `ttk::combobox`. The wholly-ttk family (`slickprop` fonts,
ttk::panedwindow) lives under `library_manager.tcl` / `save_as_form.tcl` and is
not this. Colours come through the single accessor, per the Calculator's
RULING-1.

**R404** Contents, top to bottom:

| region | what | built on |
|---|---|---|
| **Loaded** | the registry of this session's context — one row per slot, the current one marked, showing `db_label` (file tail + analysis) with the full path in a balloon | `results::list` (R304) |
| **Recent** | the MRU, newest first, entries already in the registry visually distinguished from ones that are not | `wviewer::rawhist_get`, `src/wave_viewer.tcl:8349` |
| **Path** | an editable path entry + `Browse…` | `select_raw`, `src/xschem.tcl:16672` |
| **Status** | one sentence: the resolver's verdict for the highlighted candidate | §4, §10 |
| **Buttons** | `Select` · `Close`. No OK/Apply pair. | — |

**R405** The `Loaded` region is the primary control and is listed first,
deliberately inverting Cadence, whose Select form is a file chooser. xschem
already accumulates databases (F7's declared cost) — the common case is
"switch back to the one I had", which is free, and the file chooser is the
fallback. This is a **deliberate deviation**; §15.

**R406** Selecting a row is one gesture — double-click or `Select` — and calls
`results::select`. The dialog stays open and refreshes, because comparing two
runs means selecting twice.

**R407** The dialog reads the *host session's* context. Opened from an ASE-L
window it acts on that session's viewer context via the borrow idiom (F6); a
refused ticket is reported as such, never as "no results" (F6, R305).

### 6.1 RULINGS — the dialog's exact shape (item 7, 2026-08-20)

Taken by the crew per `doc/claude/results_batch/DECISIONS.md` §C: each was
genuinely open in §6 above, there is no human in the loop, and the window could
not be written without answering it. Evidence for every one of them is in
`doc/claude/results_batch/receipts/07-results-select-dialog.md`, and each is
pinned by a check with a sabotage that reds it.

**R407a — WHICH CONTEXT THE DIALOG READS: the session's viewer when it has one,
the current one when it has not, and a refusal is reported as a refusal.**
The registry is per-`Xschem_ctx` (F2), so "the loaded results" is only a
question once you have said *whose*. An ASE session's results live in its
**waveform viewer's** context: `wviewer::attach_raw` (`src/wave_viewer.tcl:3888`)
does `switch_ctx $token` before `ase::attach_dbs` reads, and the viewer token
**is** the session key. Three arms:

| arm | when | what the dialog does |
|---|---|---|
| `viewer` | the session has a viewer window | **borrows** it — `enter_ctx $key 1` / `leave_ctx`, the 0173 loan `wviewer::selected_rawfile` (`:4072`) already uses — for the read **and** for the select |
| `here` | it has none | reads the **current** context and says so, in the `Loaded` region's own title (`Loaded — current window`) |
| refused | the ticket came back refused | **reports the refusal** (R407), never an empty list |

A loan and not `rawbar_load`'s move, because a browsing dialog belongs to the
ASE window and must not leave the user's context somewhere else. Refusing to
work at all in the `here` arm was rejected: *"evaluate against last night's
raw"* happens **before** a run, which is exactly when no viewer exists.
**⚠ ITEM 10 COLLIDES WITH THAT ARM AND THE COLLISION IS OPEN.** U6 removes the
Calculator's read of the current context entirely, so a result selected through
the `here` arm is a real selection that the Calculator cannot see — filed as
issue **0516**, ruled *not* closable by a crew agent (U6 is the user's), and
mitigated only in the message R503f rules. If the `here` arm is ever withdrawn,
withdraw R503f's sentence with it.
Pinned: SEL365 (here), SEL368/SEL369 (refused — the sentence is asserted for
what it must **not** say, "no results", as well as for what it must),
SEL410 (the loan really is a loan: `current_win_path` is unchanged by both the
read and the select, with the viewer open and the context standing elsewhere).

**R407b — the sentence goes to the ASE channel AND into the dialog's Status
region, and it is ONE sentence, composed once.** `results::select` is called
with `host ase` (R802's channel for this host) and the dict it returns carries
the same `msg` into the Status label. This is not R604a's "two sentences for one
event": it is one string, in the place the user is looking and in the session's
log. R802a anticipated exactly this reader — *"the sentence is still in the
returned `msg`, which is what a headless caller and the dialog's Status region
both read"*. Pinned: SEL371 (the Status text **is** the door's), SEL375 (`host
ase` is named outright).

**R407b.1 — CORRECTED IN THE FIXER ROUND (item 7). The door's sentence is the
LAST word on the gesture, and no debounced preview may land on top of it.** The
Path entry binds `<Return>` to `rsel_commit` and `<KeyRelease>` to the 250 ms
debounced preview, and **one physical Return is a KeyPress *and* a
KeyRelease** — so a quarter of a second after every Return-commit the resolver's
*"Using an.raw."* replaced the door's *"Selected an.raw (tran)."*, in the Status
region and in the `dlg($key,rselstatus)` record. On a **refused** Return it was
worse than cosmetic: the refusal sentence was erased and the user was left
reading a verdict that says the opposite of what happened. Two races, two
closures, and neither alone is enough: **the keystrokes that COMMIT schedule
nothing** (`Return`/`KP_Enter`/`Escape` are the dialog's own gestures, not edits
to the path — the binding passes `%K` and `rsel_preview_soon` skips them), and
**`rsel_commit` cancels any preview already pending** from an earlier keystroke,
which the binding guard cannot reach because that timer was set before it ran.
Pinned SEL415 (a real `<KeyPress-Return>` commits) and SEL412 (the release half
schedules nothing, a pending timer is cancelled by the commit, and the sentence
still stands 400 ms later — the race is FORCED, not hoped for).

**R407c — THE TYPE RULE, and the answer to the question item 4 left open.**
Item 4's receipt §5 recorded that a **typeless** select of a VCD or a table
refuses, because with no type the C reader dispatches to the spice parser
(`no "<unspecified>" analysis`, `src/save.c:2110`) — and the MRU and the
persistence slot store a path and nothing else, so a non-spice database that
reaches `Recent` could never be re-selected. Item 7 is the first caller that can
put such an entry in front of a user. **Ruled in three clauses:**

1. **A `Loaded` row carries its own type and that type is what is passed** — the
   engine's own token, from `results::list`, **per slot**. One file read as `dc`
   and as `tran` is two rows and one result (U11), so a by-path lookup would
   select the *wrong analysis of the right file*. Pinned SEL372 on a two-plot
   `multi.raw` where the by-path answer (`dc`) differs from the row's (`tran`);
   SEL409 measures that fixture.
2. **A `Recent` or typed path that normalises onto a loaded slot inherits that
   slot's type** — so a VCD stays re-selectable by name for exactly as long as
   it is a loaded database, which is the whole window in which R102 calls it one.
   Pinned SEL367, SEL373.
3. **Otherwise no type is passed and none is invented.** The engine then means
   "first analysis found in the file", which is right for the spice raws that
   are almost all of the MRU, and refuses a non-spice file that is not loaded —
   reported by `results::select`'s own refusal sentence (T-D). Pinned SEL374.

`<NULL>` is mapped to the empty type at every hand-off (`rsel_type_norm`): it is
`xschem raw info`'s **rendering** of a NULL `sim_type`, and passing it on would
ask the engine for an analysis literally called `<NULL>` — no reader knows it,
so the verb would fall through to a read with a bogus type. Pinned SEL360,
SEL364.

**Two alternatives were considered and rejected, and the reasons are the
ruling's evidence.** *Sniffing the type from the extension* (`.vcd` → `vcd`) is
a guess dressed as knowledge: `raw_reader_table[]` (`src/save.c:1660`) is keyed
by a declared token, never by a filename, `table` databases have no
distinguishing extension, and a **wrong** guess is worse than none — an explicit
non-spice type makes `raw_select()` refuse a file that is loaded under another
analysis (R301b's guard, `:2466`), breaking the case clause 2 gets right.
*Showing such an entry disabled with a reason* needs the same sniff, so it would
either be wrong or would grey out every `Recent` entry that is not currently
loaded — most of them, and every spice one would have worked. **The residual
case is one MRU entry of a digital database that is no longer loaded, refused
with a sentence**, which is inside §16's declared non-goal rather than a gap
this dialog opened.

**R407d — one armed candidate, and the Path entry is its readout.** Picking a
row fills the Path entry with that row's full path and records the row's own
type; `Select` and double-click act on the armed row while the entry still shows
it, and on the entry's text once it has been edited (a different path is a
different candidate, and its type is re-derived by clause 2). So the two lists
and the Path region can never disagree about what is about to happen, and there
is ONE commit path for both gestures — `searchbar_fire`'s rule, so no route can
apply a policy another route skips. Pinned SEL403 (a pick fills the entry),
SEL402 (double-click reaches the commit).

**R407e — the resolver inputs the dialog supplies, and the two it refuses to.**
It fills `rawfile`, `rundir` (from the state, when it names one) and `netlist`.
The netlist input is what enables the **mtime** half of `stale` — *"older than
the netlist it was produced from"*, the one verdict a user cannot reach by
looking at a file list — and it is derived **only where deriving it writes
nothing**: `ase::netlist` (`src/ase.tcl:1663`) is a regenerator (it deletes the
artifact, re-netlists, can `xschem load` the design), so the name it writes,
`<rundir>/<cell>.spice` (`:1691`), is composed from the state's **own** `rundir`
and passed only when that file already exists.

**`key` is deliberately NOT passed.** R201a says a `key` supplies `derived` via
`ase::last_rawfile`, which reaches the ngspice backend's `raw_file` hook
(`:4777`) → **`ase::rundir`**, the create-and-default helper R602e was ruled
about: it `file mkdir`s, and for an empty `rundir` it creates
`$USER_CONF_DIR/simulations` and rewrites the global `::netlist_dir`. A preview
fires on every row click, so passing `key` would make merely *looking* at a
candidate create a directory and move a global. Second reason, independent:
with no `derived` there is no fallback, and R407g means the dialog never takes
one — a resolver answer promising a fall-back the dialog will refuse to perform
would be a sentence that lies. Pinned SEL381/382/383 (which keys, and when),
SEL384 (counted: zero `ase::rundir` and zero `ase::last_rawfile` calls, with the
counters carrying their own positive term), SEL385 (the mtime half is really
reached).

**R407f — the redraw happens INSIDE the loan.** `wviewer::regenerate` goes
through `with_edit`, which does its own `switch_ctx` and deliberately does not
restore — right for `rawbar_load`, whose gesture belongs to the viewer window,
wrong here. Run inside the bracket the switch is a no-op (we are already there)
and `leave_ctx` still puts everything back. It runs **after** the door returns,
so nothing redraws while the current-database pointer is moving (L7), and it is
`catch`ed because a dialog may not throw (R801). `capture_live_view_state` runs
**before** the door, issue 0194's rule: a selection replaces the DATA, not the
plot, so the regenerate owes the fold. Pinned SEL410 — moving the regenerate
outside the bracket reds it.

**R407g — a candidate that is not a file is refused by the dialog, ahead of the
door.** `results::resolve` would answer `invalid` and hand back the **derived**
result (R202, *"never make a session unopenable"*), which is right for a session
restore and wrong for a browsing gesture: the user picked *this* file and must
not be given a different one. This is `wviewer::rawbar_load`'s ARM 3 (`:8640`)
and its stated reasoning, in shape — *"its sentence is about a stored selection
that has gone missing, and this one is about a typo in an entry box the user is
looking at"*. Pinned SEL376 (the door is not called at all — the counter carries
its positive term in the same drive) and SEL377 (the sentence names the file and
says nothing was selected).

**R407g.1 — CORRECTED IN THE FIXER ROUND (item 7). The guard asks the question
the PREVIEW asks, which means it resolves a relative candidate against the
`rundir` first.** As first shipped the guard was `file isfile $path` against the
**process CWD**, while `rsel_preview` one region above it resolved the same
candidate against the session's `rundir` (through `results::resolve`, whose
own rule is *"relative paths resolve against the rundir"*). The engine keeps the
spelling it was handed, so `xschem raw read an.raw tran` issued from inside a
rundir puts a **relative** path in the registry and the `Loaded` list renders
it — and that row previewed as *"Using an.raw."* and was then refused by
`Select` with *"No such result file 'an.raw' — nothing was selected."*, while
`results::select` handed the identical path **selected it**. The dialog's own
preview and its own button contradicted each other on one candidate, and a row
the `Loaded` list displays could not be selected from the `Loaded` list.
R407g exists so the resolver's **derived fallback** cannot substitute a
different file; it was never a licence to refuse files that are there. The
resolution is a proc (`ase::ui::rsel_abs`) and the **original spelling is still
what the door is handed** — R302a's "one spelling per run" is
`results::_engine_spelling`'s ruling to make, not the dialog's. Clause (2)'s
type lookup asks the resolved path for the same reason: `results::_same_path`
normalises both sides against the CWD, so a relative candidate would otherwise
match no loaded slot and be passed typeless. Pinned SEL411 (CWD deliberately
**not** the rundir; the preview, the select and the resolved form asserted in
one check). SEL376/SEL377 could not see this — they only ever feed the guard an
**absolute** non-existent path, which is refused either way.

**R407h — three statuses speak in the resolver's own words; `invalid` does
not.** §10 requires the Status region to carry the resolver's verdict, and
`default`, `ok` and `stale` are quoted **verbatim** — R805 fixes one form per
status and R803a shortened them to `file tail` precisely so a one-line region
could hold them. The two `invalid` sentences describe a **fall-back**, which
R407g means will not happen, so the dialog says its own *"No such result file
'x.raw'."* (or *"The result file 'x.raw' cannot be read."* for
`reason unreadable`) instead. Same precedent as R407g. Pinned SEL386 (the three
are byte-identical to `results::resolve`'s `msg`) and SEL387 (`invalid` is not
quoted and promises no fallback).

**R407i — CORRECTED IN THE FIXER ROUND (item 7). `rsel_close` takes ALL the
per-window records, `rselstatus` included.** Its own header says a bare
`destroy` *"would leave the per-window records behind"*, and it was leaving
exactly one of them — the sentence — so a reopened dialog could be read back
holding the verdict of a candidate from the window's previous life, before its
first fill. Bounded (`ase::ui::close`'s `array unset dlg $key,*` sweeps it at
session teardown), and closed anyway because the promise was written down.
Pinned SEL407 and SEL414, both of which assert the record's presence **before**
the dismiss in the same check, so its absence after is the close path running.

**The controls are INVOKED, not read (the anti-vacuity rule, applied in the
fixer round).** `-text` and a slave list prove a button is on screen; they prove
nothing about what pressing it does. Retargeting `Select`'s `-command` at a
command that does not exist, emptying `Close`'s, and deleting the
`wm protocol WM_DELETE_WINDOW` line each left all 51 original checks green.
Pinned SEL413 (`$w.btns.select invoke` really moves the current database and the
dialog stays mapped), SEL414 (`$w.btns.close invoke` plus the `wm protocol`
command) and SEL416 (R407c clause (1) driven through the **gesture** R406
defines — a real `<<TreeviewSelect>>` on the `(tran)` row — because SEL372 arms
by calling `rsel_arm` directly and so cannot see `rsel_pick` dropping the row's
own type, which is U11's wrong analysis of the right file).

**Where the dialog reaches into `results::` private surface, and why.**
`results::_same_path` is called directly. "Are these two spellings the same
file?" is ruled once, in R302a and R302h; a second copy of that predicate in
`ase_window.tcl` would be a second place for the ruling to drift, and the drift
would show up as a `Recent` entry marked "not loaded" while `results::select`
lands on the slot it already has. A public alias in `src/results.tcl` was
declined as a wider edit than item 7's fence allows. Named here rather than
hidden.

---

## 7. The two surfaces that already select

**R501 — the viewer Location bar keeps its behaviour and gains the resolver.**
`wviewer::rawbar_load` (`src/wave_viewer.tcl:8583-8642`) is already correct on
the hard points: `file isfile` guard, `switch_ctx` (a move, not a loan),
additive read with **no** clear (F7), `regenerate`, `browser_refresh`,
`rawhist_push`, `rawbar_sync`, `log_action`, and every refusal returning 0 with
nothing thrown. (Three of its five refusal arms write a one-line sidebar status;
the unknown-token arm and the failed-`switch_ctx` arm return silently — the
re-expression must not quietly change which. **Delivered 2026-08-19; §7.1's
R501a/R501b/R501c are the rulings it took, including the five measured
divergences it did not pretend it had avoided — the fifth was found in the
fixer round, not the implementation round.**) The re-expression must also state
which steps move into `results::select` and which stay in `rawbar_load`:
`capture_live_view_state` and `regenerate` are viewer concerns and stay. It is re-expressed on
`results::select` so the status sentence and the MRU push happen in one place —
**its user-visible behaviour must not change**, and §12 T-C pins that.

### 7.1 RULINGS — the re-expression's exact shape (item 5, 2026-08-19)

**Three** crew rulings, all measured against the **frozen pre-item body**, which
lives on in `tests/headless/test_results_select.tcl` group AM as
`wviewer::rawbar_load_PRE` so T-C stays a *comparison* rather than a claim. They
are R501a, R501b and R501c. None re-opens `DECISIONS.md`.

**R501a — T-C OUTRANKS THE SENTENCE HALF OF R501's RATIONALE, so `rawbar_load`
passes `host none` and keeps its own three strings.** R501's stated payload is
that "the status sentence and the MRU push happen in one place". The MRU push
did move — it is `results::select`'s now, and the delta is provably identical
because `wviewer::rawhist_add` (`src/wave_viewer.tcl:8333`) `file normalize`s
its argument, so pushing the caller's spelling and pushing the engine's store
the same string (SEL312). **The sentences did not, and could not.** T-C's own
wording freezes "same status string", and the two texts are not the same text:
the door says *"Could not select notraw.txt — nothing was loaded and the
previous result is unchanged."* where the Location bar says *"Location: could
not read 'notraw.txt'"*. Worse, `results::select` emits on **success** too, and
`rawbar_load` never has — so routing the emission through the door would put a
new sentence into the sidebar on every successful load. **The channel is
unified either way** (both routes end in `wviewer::browser_status`); it is the
TEXT that T-C freezes, and R802a's `host none` is the option item 4 built for
exactly this caller. Pinned by SEL331, whose fourth term greps the *list
construction* rather than the two words — a first version grepped `host none`
and was satisfied by the comment three lines above the call.

> **The unification the payload wanted is therefore HALF DONE, on purpose, and
> the other half needs a behaviour change nobody has asked for.** If a later
> item wants one sentence, it must restate SEL299/SEL301/SEL306/SEL308 and say
> in its receipt that the Location bar's wording changed.

**R501b — THE TWO SILENT ARMS STAY SILENT, AND THAT SATISFIES T-J RATHER THAN
OVERRIDING IT.** §12's T-J was split in the item-4 fixer round and the **borrow
half** was assigned here, because R302e left `switch_ctx` in this proc. Measured
on the pre-item body, the five arms are:

| arm | condition | sentence | rc |
|---|---|---|---|
| 1 | the token names no viewer window | **none** | 0 |
| 2 | nothing typed | `Location: type the path of a raw file` | 0 |
| 3 | `![file isfile $path]` | `Location: no such file '<tail>'` | 0 |
| 4 | **`![wviewer::switch_ctx $token]`** | **none** | 0 |
| 5 | the engine refused the file | `Location: could not read '<tail>'` | 0 |

**That table is a table of ARMS, and it is unchanged. It is not a table of
inputs, and ONE INPUT CLASS CHANGED ARM** — a `~/`-spelled path naming a
readable raw used to land in arm 5 and now succeeds. That is R501c divergence 5
below, and it is the only place in this item where the *sentence ledger* moves
for a real user input. The five arms still say exactly what they said (SEL317 /
SEL318 measure that against the frozen body); what moved is which arm a tilde
reaches.

The ruling has two parts.

*First, T-J is satisfied and it is not close.* T-J names a refused **borrow
ticket** — `wviewer::enter_ctx {token ?borrow?}` → `{ok prev ?sem?}` — and F6's
defect is a refusal **that reads like an answer**: `enter_ctx`'s own comment
says it, *"the refusal was invisible because a refused loan answers `{}` exactly
like an empty registry"*. `rawbar_load` takes **no ticket at all**: `switch_ctx`
is a MOVE, and the idiom is not in this path (SEL332 greps it, both here and in
`results::select`). And it has **no answer a refusal could be mistaken for** —
it returns 0 on every refusal and 1 on every success, nothing else, ever
(SEL319 asserts the whole set is exactly `{0 1}`). There is no "no results" for
a refusal to be dressed as.

*Second, what remains is an R801 gap, and it is filed rather than fixed.* Arm
1's silence is **forced** — no window means no sidebar, and `browser_status`
looks the token up in the same dict that just failed. **Arm 4's is not**: the
window is there, `browser_status` would deliver, and the sentence simply was
never written, so a user who types a path while `ase::wait`'s `vwait` holds the
semaphore gets nothing at all. That is issue **0515**, OPEN, with the one-line
fix and the four checks that must be restated with it written into the issue.
It is not fixed here because T-C's text names the silence — *"the same two arms
staying silent"* — so repairing it inside this item would be the one change the
item forbids.

**R501c — FIVE DIVERGENCES ARE REAL, ARE RULED ACCEPTABLE, AND ARE EACH
MEASURED.** (Four were measured in the implementation round; the fifth in the
fixer round, by a reviewer's differential harness over fourteen spellings of the
Location-bar path.) Coming through R303's single door brings R302a's spelling rule,
R302d's side effects and R301d/R301f's verb semantics with it. Every one is a
*correctness gain*, which is what the ruling rests on, so each is asserted
against the frozen body rather than asserted about:

1. **One spelling per run (R302a).** `<d>/sub/../an.raw` used to add a SECOND
   slot beside `<d>/an.raw` — the engine dedupes by `strcmp` on the stored
   spelling — and **F7 makes that duplicate permanent**. It now lands on the
   slot already there. SEL320 (pre: 1 → 2 slots) / SEL321 (post: 1 → 1).
2. **The case-mode cache (R302d).** The pre-item body changed the current
   database and left the cached readout of the *old* one standing. SEL322.
3. **A one-point OP or DC publishes (R301d).** Measured: select `op.raw`, then
   Location-bar-load a *different* op raw, and the pre-item body left
   `ngspice::get_voltage o1` answering the FIRST file's `1.5` — the schematic
   annotated from one database while the viewer drew another. That is the same
   staleness `browser_refresh $token 1` was added to this proc to stop.
   SEL323/SEL324.
4. **A typeless re-load keeps the analysis you are on (R301f).** One file
   holding a dc and a tran is two slots and ONE RUN (U11); the old append-read
   deduped on the FILENAME ALONE and landed on whichever slot came first, so
   re-typing the path you were already looking at moved you from `tran` to `dc`.
   SEL325/SEL326.
5. **A LEADING `~/` NOW RESOLVES, WHERE THE PRE-ITEM BODY REFUSED IT.**
   `file isfile ~/x.raw` is 1 — Tcl expands `~` — so arm 3 passes in **both**
   bodies. The pre-item body then handed the tilde straight to
   `xschem raw read`, whose `extra_rawfile()` runs only a Tcl `subst` and has
   never expanded `~` (`src/save.c:2020`; measured, the engine prints
   `raw_read(): failed to open file ~/... for reading`), so every tilde spelling
   died in **arm 5** with `Location: could not read '<tail>'`. The door
   normalises before the verb (`results::_engine_spelling`,
   `src/results.tcl:475-486`) **and** `xschem raw select` expands `^~/` itself
   as of item 3's fixer round (`src/save.c:2408-2416`) — two independent
   expanders — so it now loads. SEL337 (pre: rc 0, no slot, the arm-5 sentence)
   / SEL338 (post: rc 1, one slot, the MRU pushed, silent).

   ⚠ **THIS IS THE ONLY DIVERGENCE THAT MOVES rc AND THE SENTENCE.** D1-D4 all
   keep rc 1 and an empty sentence list; this one flips 0 → 1, adds a registry
   slot and an MRU entry, and deletes a sidebar sentence — i.e. all four of the
   things T-C freezes, in one input. It is **ruled acceptable anyway**, on the
   same ground as the other four and more strongly: refusing `~/sim/foo.raw` was
   never a behaviour anyone wanted, `wviewer::rawbar_commit` passes the combobox
   text to `rawbar_load` verbatim so a user typing it and pressing Return hits
   this, and R302a's whole point is that the door decides one spelling per run.
   The honest statement is that T-C held for thirteen of the fourteen input
   classes a reviewer drove, and this is the fourteenth.

   ⚠ **AND IT IS BELT-AND-BRACES, WHICH THE SABOTAGE HAD TO PROVE.** Removing
   *either* expander alone leaves SEL338 green — the fixer round measured both:
   dropping `_engine_spelling`'s `file normalize` reds SEL336/SEL321 and six
   others but not SEL338, and swapping the door's verb back to `raw read` reds
   ten checks but not SEL338. Only removing **both** reds it. A later item that
   takes one of the two expanders out must therefore not read a green SEL338 as
   permission.

And **one ordering moved**: `browser_refresh` is one of R302d's side effects, so
it now runs BEFORE `regenerate` instead of after it (SEL327/SEL328). What did
**not** move: `capture_live_view_state` is still the first thing after the
context move (SEL329), and `rawbar_sync` and `log_action` still get **the path
the user typed**, not the engine's spelling — the Location bar echoes the
gesture and the replay log replays the gesture, not its resolution (SEL330,
**and SEL336**).

> **SEL330 ALONE WAS NOT ENOUGH, AND THE FIXER ROUND MEASURED WHY.** It reads
> `am7`, whose typed path *is* the engine's spelling, so a regression handing the
> widget tail `[dict get $res path]` passed all 335 checks in
> `test_results_select` and all 192 in `test_wave_sigbrowser_i1315` while
> silently rewriting the Location-bar text and the replay log under the user.
> **SEL336** re-asserts it on D1's `an1q` fixture (`<d>/amsub/../an.raw`), the
> one place in the suite where the two spellings provably differ.
>
> **And the four calls R501 keeps in the viewer must be present on EVERY success
> path, not only on a fresh read.** SEL327-SEL330 all read `am7`, the `how read`
> leg; a sabotage making the redraw conditional
> (`if {$how eq {read}} { wviewer::regenerate $token }`) survived all 1008
> checks in the four suites that touch `rawbar_load` while leaving the viewer
> drawing the *old* database after the engine had moved — exactly the case R501
> says must not move. **SEL334** (the already-loaded `how switch` leg) and
> **SEL335** (the second-raw leg) compare the viewer tail
> `{capture regenerate rawbar_sync log_action}` PRE vs POST as a subsequence,
> with its order pinned.

**What stayed in `rawbar_load`, and why.** R501 names `capture_live_view_state`
and `regenerate` by hand; the full list is the `file isfile` guard (it is what
makes arm 3's sentence about a *typo in an entry box* rather than about a stored
selection that went missing), `switch_ctx` (R302e), those two viewer concerns,
`rawbar_sync` and `log_action` (widget state and the replay log, neither of
which is a selection), and the three sentences (R501a).

---

**R502 — the Calculator's `Browse` stays disabled. RULED §17 decision 9,
reversing this rule's original text.** Browsing to a result is
`ASE-L ▸ Results ▸ Select`'s job; the Calculator consumes the session's
selection and never makes one. The stub keeps its shape and its reason, and the
spec now says why it is inert rather than promising it will not be.

**DELIVERED, item 10, 2026-08-20 — and the reversal is written into the code as
well as into this rule.** `.calc.res.path` is still `-state readonly`
(`src/calculator.tcl:728`) and `.calc.res.browse` is still `-state disabled`
(`:749`), but its command is no longer `{calc::status {Browse: not
implemented}}`: it is `calc::browse_inert` (`:1184`), whose sentence gives the
*reason* — *"Browse is deliberately inert: the Calculator consumes the session's
result and does not make one. Pick one with ASE-L ▸ Results ▸ Select."* — and
the block comment above the widget (`:735-748`) records the ruling that made it
so. **"Not implemented (phase N)" is a promise and may only be made where a
phase really is coming**; there is no phase coming for this control, and the
previous wording was an invitation to a later reader to "finish" it. What this
rule USED to say, for the record, is that Browse *"becomes `results::select` +
`select_raw`"*. It does not, and it will not.
**Browse has no R-number and no plan row in
`doc/claude/calculator_batch/PLAN.md`** — it is named once, at
`doc/claude/specs/calculator.md:201`. This spec is where it acquires one.

**R503 — the Calculator's Results Dir row must report what Evaluate will use.**
Before item 10, `calc::results_source` resolved self → viewer → ASE → none and
labelled which won (`doc/claude/specs/calculator.md:201`, pinned by
`tests/headless/test_calc_skeleton.tcl` S26). That is a *reporter*, and the
Calculator spec is **silent** on which database Evaluate uses — R601–R607
(`doc/claude/specs/calculator.md`, §9) never name one, and its only "current
raw" statements are §5 and R705. That silence is the gap: the row could name a
borrowed path while the computation used a different database, or none.
**RULED §17 decision 3: the row PICKS.** What it names is what Evaluate reads,
and the `self` arm that could disagree with it is gone (decision 6). The
invariant is: *the row names the database Evaluate will use, or it says it is
only reporting* — and under U3 it is the **first** arm that must hold.

**DELIVERED, item 10, 2026-08-20.** The mechanism is §7.1a's R503a: there is
exactly **one** resolver (`calc::results_source`, `src/calculator.tcl:948`), and
Evaluate reaches it through `calc::require_result` (`:1154`), which resolves
ONCE, publishes the row from that same measurement, and only then decides. The
row cannot name one database while the decision uses another, because there is
no second measurement for it to name.

**R504 — `Results ▸ Select…` does not appear in the waveform viewer's menubar.**
`tests/headless/test_wave_viewer.tcl:586-587` (G2) asserts the cascade set is
**exactly** `{File View Graph Cursors Options}`, and `src/wave_viewer.tcl:18469`
records the rule. The viewer's selection surface is the Location bar it already
has. Adding a cascade there is a separate decision with a frozen test in front
of it.

**R505 — the Waves menu is GATED, not fixed, not extended. RULED §17.2.**
Under `cadence_compat` its eight loading entries and `Op Annotate` are blocked
with a message naming the setting and pointing at `ASE-L ▸ Results ▸ Select`;
without `cadence_compat` it behaves exactly as it always has. The background: Issue **0508**: `load_raw`
(`src/xschem.tcl:16874`) calls `xschem raw_clear` and then `xschem raw_read`,
which *itself* clears the whole registry — so the eight `waves <type>` entries
(`Load first analysis found`, `Op`, `Dc`, `Ac`, `Tran`, `Noise`, `Sp`,
`Spectrum`) silently discard every other loaded result. `External viewer` and
`Clear` do not route there; `Op Annotate` calls `select_raw` directly.

**CORRECTED IN PLACE, item 8, 2026-08-20.** This paragraph used to end *"under
this spec those entries route through `results::select` and stop clearing"*.
**They do not, and they never will** — U4 ruled the menu GATED rather than
repaired, and a reader who followed the old sentence would look for a fix that
was deliberately not made. What shipped: under `cadence_compat` those entries
refuse with the sentence §7.2 R505c specifies; **without `cadence_compat` they
still call `xschem raw_clear` and then the registry-clearing `xschem raw_read`,
exactly as they always have**, and `tests/headless/test_waves_gate.tcl` asserts
that legacy behaviour POSITIVELY (SEL430, SEL437, SEL449) so "we broke the menu
for everyone" cannot read as a pass. The second half of U12's answer to the
driver's *"if the destructive behaviour is wanted it must be said"* is where it
is now said: in `waves_gate_msg`'s sentence, in the block comment above
`proc load_raw`, and in issue 0508's FIXED note.

### 7.1a RULINGS — the Calculator's consumption (item 10, 2026-08-20)

**Seven** crew rulings, taken per `doc/claude/results_batch/DECISIONS.md` §C
because U3/U6/U7/U9 settle *what* the Calculator must do and leave *how* open.
None re-opens a user ruling. Every one carries a check in
`tests/headless/test_calc_skeleton.tcl` (S15/S18/S26/S27) and a sabotage that
reds it; the evidence is in
`doc/claude/results_batch/receipts/10-calculator-consumes-selection.md`.

**R503d — the borrowed read asks `results::current`, not `xschem raw rawfile`.**
The old row read the raw verb. The two answers differ exactly where this batch
lives: `raw rawfile` names the current database even when it is a **VCD or a
table** (R102/R305b — `ase::attach_dbs` reads the analog raw and *then* the
VCDs, L8, so a digital slot really can be current) and even when its
`schname`/`level` stamp no longer resolves against the hierarchy stack (F4 — a
loaded-but-blind database in which every name lookup answers −1).
`results::current` (R305) answers R103's three parts and returns `{}` for both.
Naming either of them in a row that PICKS is precisely how the Calculator ends
up evaluating against a database in which no signal name resolves — the failure
R204 of `calculator.md` exists to prevent, one layer further out. Pinned by the
whole of S26 (the shim is on `results::current`), with SB8 — the reader reverted
to `raw rawfile` — reddening 17 checks.

**R502a — a DERIVED path is not an answer, so `calc::ase_raw` is GONE.** The old
`ase` arm returned `ase::last_rawfile` (`src/ase.tcl:1952`): the run directory's
raw, gated on the file existing. That is a **file on disk**, not a selection, and
under U3 the row must name what Evaluate READS. Evaluate cannot read a file that
nothing has loaded, so offering it would re-open R503's contradiction one arm to
the left — the row naming a path while the computation had none. The honest
answer there is *"no result is loaded"*, and **U7's sentence is what makes that
actionable**: it names the gesture that turns that file into a selection.
Item 13's original report is unaffected — a session with waveforms on screen has
a viewer context and is answered by the `ase` provenance below. Pinned S26 *"a
DERIVED session path is not a selection and is not reported"*, whose positive
term asserts the derivation really does answer; SB9 restores the arm and reds it
alone.

**R503b — the provenance vocabulary is `ase | viewer | refused | none`, and
`ase` is a LOOKUP.** The viewer token **is** the ASE-L session key —
`ase_window.tcl` attaches with `wviewer::attach_raw $key …` (`:2334`, `:4972`),
which is the same fact R407a rests on — so "whose result is this?" is answered
by `dict exists $::ase::sessions $tok`, not by a guess. A viewer with no session
behind it stays `viewer`: it is a results holder in its own right (its Location
bar selects through `results::select`, R501), so it is **not** the legacy door
U6 closes. U6 closes the **schematic window's own context**, which is now
consulted by nothing — **and that has a measured cost this rule does not pay:
R407a's `here` arm selects INTO that context, so a selection made through this
batch's own door can be invisible to the Calculator. See R503f and issue 0516.** Pinned S26 *"a token that IS a live ASE-L session key
reports as one"* (SB10) and *"a result in THIS window's own context is NOT
consulted"* (SB1, which restores the `self` arm and reds that leg alone).

**R503a — ONE resolver, and Evaluate publishes the row from the measurement it
decides on.** This is the mechanism of U3's *"the row PICKS"*, and it matters
that it is a mechanism rather than a pair of equal strings: two resolutions can
agree by luck and disagree under a world that moves between them (a viewer
closing, a session attaching). So `calc::require_result` calls
`calc::results_source` **once**, hands the result to `calc::results_publish`,
and answers from the same value. Pinned S27 *"the row is published from the SAME
resolution the decision used"*, which counts the calls (`1`), with SB3 — a second
resolve through `results_refresh` — reddening it.

**R503c — the refusal sentences MUST NOT COLLAPSE, and that is T-J's other
half.** §12's T-J is *"a refused borrow ticket is reported AS REFUSED, never as
'no results'"*. It is sharper here than anywhere else in the batch, because *"no
results are loaded"* is **also a legitimate answer this window gives** — U7's,
in fact. So the Calculator carries two procs with two texts: `calc::busy_msg`
(*"…the waveform viewer's context is busy — that is a refused context switch,
not an empty result list."*) and `calc::no_result_msg` (U7's, verbatim). The
refusal **denies the wrong reading in so many words**, the same shape as
`ase::ui::rsel_borrow`'s (R407a). A refused loan is still *skipped* first —
another viewer may hold the session's result and a refusal says nothing about
that one (issues 0313/0314) — but it is **remembered**, and if the walk ends with
nothing it becomes the origin. Pinned S26 (four legs) and S27 (two), with **SB6
— `busy_msg` returning `no_result_msg`** reddening three, and **SB2 — the
refusal not recorded at all** reddening six. SB2 is F6's defect exactly: a
refusal that reads like an answer.

**R503e — EVALUATE is gated; PLOT and TABLE are not.** U7 names Evaluate. Gating
the other two would be scope creep in an item whose fence is explicit, and their
phase-1 stubs still say what they always said. `calc::eval_click` refuses when
there is no result and otherwise **falls through to `calc::inert Eval 3`** — the
computation is `doc/claude/calculator_batch` phase 3's and item 10 builds none of
it. Pinned S27 *"Evaluate WITH a result falls through to the phase-3 stub"*: an
item that quietly grew a phase reds it.

**R503f — U7's SENTENCE IS NEVER SAID TO A USER WHO HAS ALREADY DONE WHAT IT
ASKS (fixer round, 2026-08-20).** This ruling exists because two items of this
same batch collide, and the spec argued both sides without noticing.

**The collision.** R407a (item 7, §6.1) gives the dialog a **`here` arm**: with
no waveform viewer the session reads — and selects into — the **current**
context, and the justification recorded there is verbatim *"Refusing to work at
all in the `here` arm was rejected: 'evaluate against last night's raw' happens
BEFORE a run, which is exactly when no viewer exists."* That sentence names the
Calculator's Evaluate. U6 then says the Calculator does **not** read that
context. So a selection made through this batch's **own door** can be invisible
to the Calculator, and — measured by a reviewer with no repo edit at all — the
row read `(no raw file loaded)` while `results::current` in that same context
returned the selection, and Evaluate answered *"pick an existing one with
ASE-L ▸ Results ▸ Select"*: **the gesture the user had just performed
successfully.**

**What is NOT ruled here, and why.** U6 is a **user** ruling whose words are
*"removed entirely, not demoted"*. An arm that reads this window's own context —
however late in the order, however tightly conditioned on "a live session with
no viewer" — is the demotion it forbids, and a crew agent may not take that
decision back. R503b's *"U6 closes the schematic window's own context, which is
now consulted by nothing"* therefore **stands**, and the gap is **filed, not
closed**: issue **0516**, with the reviewer's reproducer, for the driver and the
user to rule.

**What IS ruled.** The Calculator stops giving useless advice in that state. The
test is **structural** — is there a live ASE-L session with no waveform viewer
window (`wviewer::window_for`, which is exactly R407a's `here` precondition)? —
and it therefore reads **no database**, enters **no context** and produces **no
path**. Evaluate still refuses; it refuses *accurately*, in
`calc::no_viewer_msg`'s words, which name the obstacle and a door that works:

> *The ASE-L session has no waveform viewer, and the Calculator reads the
> session's viewer — a result selected while the session has no viewer is not
> visible here. Run a simulation, or open the session's waveforms and then pick
> a result with ASE-L ▸ Results ▸ Select.*

Both steps of that door are real: with a viewer open `ase::ui::rsel_borrow`
takes its `viewer` arm and `rsel_commit` passes `token $key`, so the select
happens **inside** the borrowed context — which is where `calc::session_result`
looks.

**⚠ `calc::no_result_msg` STAYS UNCONDITIONAL.** U7 ruled a *string*; making it
state-dependent would turn the ruled sentence into a branch and the check that
asserts it by text into an assertion about one arm. The choice lives one level
up, in `calc::no_result_advice`, which **both** the row's tooltip and
`calc::require_result` reach — so the row and Evaluate can never give different
advice about the same world. Pinned S27 (five legs, including the discriminating
positive control: the **same** session, now **with** a viewer whose context holds
no result, gets U7's ruled sentence back), sabotaged in both directions and once
more by making `sessions_without_viewer` skip `wviewer::window_for`.

**R503g — THE GATE NAMES A SLOT, NOT A FILE (fixer round, 2026-08-20).**
`calc::require_result` answers
`{ok .. origin .. path .. type .. idx .. msg ..}`, and the `type`/`idx` are
carried the whole way from `results::current` through `calc::ctx_result` →
`calc::session_result` → `calc::results_source`. The first draft identified a
result **by path alone**, which this spec already rules insufficient: R407c
clause (1) says in so many words that *"a by-path lookup would select the wrong
analysis of the right file"* (pinned SEL372 on a two-plot `multi.raw`), U11 says
one run is one result but the **engine's** identity key is `(rawfile,
sim_type)` and it stores one slot per analysis, and landmines **L6** and **L10**
say a slot is reachable by name only with its type. Measured on the item tree
before the fix: with `multi.raw` current as `dc` and then as `tran`,
`calc::require_result` and the row returned **byte-identical** answers, so phase
3 could not have been told which analysis it had been given. **The ROW still
names the path** — W05 is a path entry (§4) and the two rows of one file are one
*result* (U11) — **the GATE names the slot.** Pinned S27 *"the same FILE as two
analyses gives two answers, not one"* and *"T-I …and the same SLOT, not just the
same file"*, with the reviewer's own recipe (delete the keys) reddening both.

**R502b — a permanently inert control states WHY, and never "not
implemented".** The Browse stub keeps the shape phase 1a shipped (a control that
is missing "because it comes later" is not allowed; a control that is inert is),
and its command is now `calc::browse_inert`, whose sentence names the door. The
generalisation, which is the reason this is a ruling and not a code comment: **a
control that is inert BY RULING and one that is inert UNTIL A PHASE LANDS must
not say the same thing**, because the second sentence is a promise and a reader
who believes it will implement the control the user declined. Pinned S27 (four
legs, including that a press on the disabled button says nothing, with an
enabled control as the positive gesture), SB7, SB19 and SB20.

---

### 7.2 RULINGS — the Waves gate's exact shape (item 8, 2026-08-20)

Four crew rulings, none of which re-opens `DECISIONS.md`. Each carries a check
in `tests/headless/test_waves_gate.tcl` and a sabotage that reds it; the
evidence is in `doc/claude/results_batch/receipts/08-waves-menu-cadence-gate.md`.

**R505a — the gate sits in `load_raw`, not in eight menu-entry bodies.**
`load_raw` has exactly ONE caller (`proc waves`, `src/xschem.tcl:6385`) and
`waves`'s non-external branch is exactly `load_raw $type`, so one guard at the
top of `load_raw` gates precisely the eight loading entries. Eight copies in
eight menu bodies were rejected on two measured grounds: they drift, and a T-L
that greps eight entry bodies is satisfied by editing one of them — the shape
that made item 2's SEL82 satisfiable by a comment. The guard is the FIRST
executable statement of the proc; SEL421 asserts its position ordinally against
every `raw_clear`/`raw_read` in the body (comment-stripped), and SEL422 proves
that detector can tell "no gate" and "gate too late" apart, so SEL421 is not
vacuous.

*The cost, stated rather than discovered later:* gating `load_raw` also gates the
**two other invocations of the same action** — the toolbar `Waves` button
(`toolbar_add Waves { waves }`, `src/xschem.tcl:15555`) and the `-W` / `--waves`
command line (`src/xinit.c:3839`, which does `tcleval("waves ...")`). **That is
deliberate.** §17.2's stated purpose is that a Cadence-mode user *"must not be
able to reach a bad state"*, and a gate a toolbar button walks around is not a
gate. Both perform the identical destructive action; neither is a new door.

**R505b — `Op Annotate` carries its own gate, in a lifted proc.** It is the one
Waves entry that does not route through `load_raw`: it calls `select_raw` itself
and then `xschem annotate_op`, whose registry effect is a *targeted* delete of a
standing 1-point `op`/`dc` slot plus an **appending** read
(`src/scheduler.c:2410-2427`) — **not** a registry wipe. So it is blocked for the
other half of U12's reason: it adopts a result without coming through the door.
Its menu body is lifted VERBATIM into `waves_op_annotate` rather than gated
in-place, for three reasons: the gate becomes a call and not a ninth copy; the
entry becomes drivable without a menubar (SEL438/SEL439 run with no DISPLAY);
and the `-command` script shrinks to a name a check can read
(`entrycget -command`, SEL445). The lift declares `global show_hidden_texts` —
the menu body ran at global scope and set the global, and a proc would otherwise
have set a local. **The IDENTICAL body under `Simulation ▸ Graphs ▸ Annotate
Operating Point into schematic` (`src/xschem.tcl:17709-17718`) is NOT touched**:
U12 names the Waves cascade, and §18 records that twin as a remaining door.

**R505c — one sentence, composed once, in `waves_gate_msg`.** It names the entry
that was clicked, says WHY, names `cadence_compat` **twice** — the setting to
look for and the way out — and points at `ASE-L > Results > Select…`. The
pointer is checked to be a **direction and not a promise**: SEL429 asserts that
`ase::ui::rsel_dialog` exists in the running binary AND that the ASE-L menu entry
that runs it exists in `src/ase_window.tcl`. That is the whole reason item 8 is
sequenced after item 7, and sabotage S20 (rename the proc, rename the label)
reds it. **The entry name and the reason are both the CALLER's** — see R505e,
which corrects the first draft's single hard-coded reason and its menu-only
entry name.

**R505d — the channel is `ciw_echo` plus a modal `alert_` under `has_x`, and the
sentence is also the proc's own return value's twin.** NOT `puts` (R802's house
rule), and NOT `results::_emit`: that proc's hosts are `viewer` / `ase` / `calc`
/ `none`, and the schematic editor's menubar is none of them — an emitter that
answered a menu click on the ASE-L session's channel would be worse than no
channel. `ciw_echo` is safe headless (it no-ops without `.ciw.l.t`, which is how
the suite shims and captures it) and `alert_` is guarded on `has_x`, so `--nogui`
reaches neither. **A blocked entry is NOT greyed out** — SEL443/SEL444 assert
every cascade entry stays `-state normal` in both flag states, because U12 says
clicking one *says why*, and a disabled entry explains nothing.

#### The fixer round — three more rulings (item 8, 2026-08-20)

Each comes from a defect a reviewer **reproduced** against the first draft of the
gate. All three are in `src/xschem.tcl`'s `waves_gate_*` procs and all three
carry checks in `tests/headless/test_waves_gate.tcl`.

**R505e — the sentence takes an ENTRY NAME *and* a REASON, both from the
caller.** Three separate things were wrong with composing it from one hard-coded
clause:

- *The reason was false for `Op Annotate`.* It was told *"it discards every other
  result already loaded"* — while R505b above, and `src/scheduler.c:2410-2427`,
  both say `annotate_op` does a **targeted** delete plus an **appending** read
  and wipes nothing. The one sentence a blocked user reads may not assert
  something this very item measured to be untrue, and the suite was pinning the
  false clause green. `Op Annotate` now says *"it adopts a result without going
  through Results > Select"*, which is R505b's actual reason for blocking it.
  **SEL451** reads both sentences off the wire and pins them apart — including
  that Op Annotate's does **not** claim the wipe.
- *The entry name named the wrong surface.* It read *"Loading a result from the
  Waves menu"*, but R505a puts the guard in `load_raw`, which is also reached
  from the toolbar `Waves` button and from `-W`/`--waves`; a user who pressed a
  toolbar button was told a **menu** had blocked them. It is now surface-neutral
  (*"Loading a simulation result"*). Passing a per-surface name instead was
  considered and rejected: `proc waves` cannot tell its three callers apart
  without a new argument on a path `src/xinit.c` also drives, and the C side is
  out of item 8's scope.
- *The pointer was not followable.* `Results ▸ Select…` lives **only** on an
  ASE-L session window's menubar (`src/ase_window.tcl`, *"ASE-L ONLY (user ruling
  U5)"*), so a Cadence-mode user with no session open has no such cascade
  anywhere in the window they just clicked in. The sentence now names the step
  that opens the door — `Tools ▸ Launch ASE-L` — and **SEL452** asserts both that
  the sentence names it and that the entry exists in the schematic editor's own
  menubar, comment-stripped.

**R505f — the flag is read the way C reads it.** The gate tested
`$cadence_compat != 1`; C reads the same variable with
`tclgetboolvar("cadence_compat")` (`src/callback.c:633` →
`Tcl_GetBoolean`, `src/scheduler.c:14601-14613`), which accepts
`true`/`yes`/`on`/`TRUE` and answers 0 for an unset or non-boolean value. So
`set cadence_compat true` in an rc file put the editor in Cadence mode as far as
every C consumer was concerned **while the Waves gate stood wide open and the
registry was silently wiped** — precisely the state §17.2 says must not be
reachable. `!= 1` is the house convention here (`cadence_compat_sync` does the
same), but this is the first site where the mismatch lets a **destructive**
action escape a gate, so the convention is the bug at this call site. The gate
now mirrors `tclgetboolvar` exactly, unset and non-boolean included, and
**SEL453** drives `load_raw` once per value of a ten-row table.

**R505g — the GUI channel never creates a second `.alert`.** `alert_` blocks in
`tkwait window .alert` but its `grab set .alert` is **commented out**
(`src/xschem.tcl`, `proc alert_`), so the menubar stays live while a refusal box
is up and a second blocked click re-enters `waves_gate_blocked` from inside the
first refusal's own event loop — which is exactly how a real second click
arrives. The second `toplevel .alert` then threw `window name "alert" already
exists in parent` **out of a menu `-command`**, and the user got Tk's
background-error dialog instead of a refusal. The gate now retexts the standing
box and raises it instead of creating one. It **retexts only its own** refusal
box (tracked in `::waves_gate_alert`): destroying a modal it did not raise would
answer somebody else's question for them — `alert_` returns `tctx::rcode`, which
defaults to *Yes* — and a refused entry must change **nothing but the message**.
**SEL458** drives it through the real menubar with the real unshimmed `alert_`;
no check that counts a shim can see this class, which is why 34 green checks did
not.

**Two more holes the same round closed, in the suite rather than the code.**
Neither was a defect in the shipped gate, and both were sabotage-proved to be
invisible before: **SEL454/SEL455** drive a blocked entry with an **empty
registry** in both flag states (every other drive in the file is preceded by
`wg_two`, so a gate conditioned on *"something is already loaded"* passed all 34
checks); **SEL456** asserts a refused entry leaves `show_hidden_texts` and
`tctx::retval` untouched (a gate placed *after* `set show_hidden_texts 1` in
`waves_op_annotate` also passed all 34); and **SEL457** extends T-L's census to
`src/actions.csv`, the **second live dispatch surface** for the same Waves group
(nine palette rows, `src/action_registry.tcl`), with `raw_read_from_attr` added
to the verb pattern — a third registry-wiping verb (`src/scheduler.c:10898-10909`,
same `extra_rawfile(3, NULL, NULL, …)` wipe) that a `raw_(clear|read)` pattern
could not see by construction.

---

## 8. Persistence — the seam that is already built

**R601** The selection persists in the ASE state's `viewer.rawfile`. **Do not
invent a slot.** The read side is complete and covered — and as of item 6
(2026-08-19) the **write** side exists too; §8.1 below carries its rulings, and
everything in this section is written in the tense of the seam as item 6 found
it:

- `ase::ui::viewer_restore` (`src/ase_window.tcl:4441-4517`) gates on
  `viewer.open eq 1`, takes `viewer.rawfile`, absolute-ises a relative value
  against `ase::rundir`, gates on `file isfile`, and falls back to
  `ase::last_rawfile` on any miss — i.e. it *already implements* §4's
  `ok`/`invalid` arms.
- `tests/headless/test_ase_persist.tcl` pins the open gate (G9: viewer closed /
  key absent) and the `ok` arm (G11: a **relative** rawfile resolved against
  `rundir` and attached, `:597-598`). G10 (`open 1` with the raw **deleted** →
  viewer up, layout restored, raw not loaded, redraw rc 0, no crash) exercises
  the `ase::last_rawfile` **fallback**, not the slot — its `vd_live` carries the
  hardcoded empty `rawfile`.
- `tests/headless/test_wave_crossdb_trace.tcl`'s `xs_state` (`:1000-1012`) is
  stronger still: a state whose `viewer.rawfile` names an analog raw *and* whose
  traces carry a cross-database VCD suffix.

**R602** The write side is small but not one line. (⚠ THE LINE NUMBERS IN THIS
PARAGRAPH AND IN R604 BELOW ARE THE **PRE-ITEM-6** TREE'S, kept because the
sentences describe the tree as it was when the item was written; R605's were
re-derived because that block still exists.) `wviewer::snapshot
{token prev}` (`src/wave_viewer.tcl:4077-4113`) hardcodes `rawfile {}` at
`:3995`; it writes the selected result's path instead — **relative to `rundir`
when it is under it, absolute otherwise**, because G11 already proves the
relative form round-trips and a relative path is what makes a state file
movable. `snapshot` does not know the rundir, so either it is passed in or the
relativisation happens in `ase::ui::viewer_snapshot`
(`src/ase_window.tcl:4354-4363`), which does. Decide that in the item, not in
the patch. **RULED in §8.1: `ase::ui::viewer_snapshot` relativises (R602b), and
the value it relativises is read from the ENGINE, not from a remembered
selection (R602a).**

**R603** `doc/claude/specs/calculator.md:806-807` R705 forbids the *Calculator*
from persisting anything about the current raw ("Reopening the Calculator against
a different simulation must not resurrect stale vector names as if valid").
**R705 binds the Calculator, not the session.** This spec persists the session's
selection, and R705 is satisfied because the Calculator reads it live through
`results::current` (R305) rather than remembering it.

**R604** A restored selection runs through the resolver (§4) exactly as a fresh
one does, and its status is reported once, on restore, through `ase::echo`.
`viewer_restore` already emits a sentence for the no-results case
(`src/ase_window.tcl:4474-4476`); this extends that vocabulary rather than adding
a channel.

**R605** `wviewer::restore`'s inline attach block (`src/wave_viewer.tcl:4213-4246`)
does `catch {xschem raw clear}` and then `xschem raw read`. That is a **clear
before read** (F7) on the restore path, and it is one of the paths §18 names as
bypassing the content check. Bringing it onto `results::select` is in scope;
changing the *order* is a measured behaviour change and needs T-E.


### 8.1 RULINGS — the write side's exact shape (item 6, 2026-08-19)

Taken by the crew per `doc/claude/results_batch/DECISIONS.md` §C: R602 says
*"decide that in the item, not in the patch"* and R604 leaves the vocabulary
open. Evidence for each is in
`doc/claude/results_batch/receipts/06-persistence-write-side.md`.

**R602a — THE VALUE IS READ FROM THE ENGINE AT SNAPSHOT TIME, and
`results::persist` is only its fallback.** Two sources were possible and they
are not equivalent:

| source | what it knows |
|---|---|
| a **remembered** selection (`results::persist`) | only what came through R303's door |
| the **engine** (`results::current`, in the viewer's context) | whatever is actually loaded now, however it got there |

The run path is `ase::attach_dbs` via `wviewer::attach_raw`, and §18 keeps it a
**deliberate bypass** of R303 — a run is not a selection. So the acceptance flow
**T-F names** — run, then Save State (`test_ase_persist` G4→G7) — comes through
the door **not once**, and a `persist`-only slot would have been empty in exactly
the round trip T-F exists to prove. Measured: with the writer wired to the engine,
G7's stored `viewer.rawfile` is `test_nfet_final_ase.raw`; with `results::persist`
neutered (sabotage **S4**) it is *still* `test_nfet_final_ase.raw`, because the
run never called it. The same holds for a Waves-menu load and for `draw.c`'s
`autoload=` walk (U10).

So `wviewer::snapshot` asks `wviewer::selected_rawfile`, which asks
`results::current` through the **0173 loan** (`wviewer::enter_ctx $token 1` —
the registry is per-`Xschem_ctx`, and this is exactly the read-only
registry-reader class the `borrow` door was opened for in issue 0314). Asking
`results::current` rather than `xschem raw rawfile` is deliberate: it is R305's
definition of *the selected result*, so R102's type gate (a VCD or a table is a
loaded database, not a result) and R103's stamp test come with it.

**`results::persist` keeps a real job**: it records the choice for the window
(`token`, else `key`), and that record is what `selected_rawfile` answers with
when the engine **cannot** — the F4 state, a result selected while standing on
another schematic, where `results::current` correctly returns `{}` and the
user's own choice would otherwise not survive the save. Engine first, record
second, both pinned in both directions (SEL342/SEL343 for the order, SEL344 for
the fallback).

**Item 4's description of the seam was the wrong shape and is corrected here.**
It said this proc would relativise a path and *write* it. It cannot write the
state: `viewer.rawfile` reaches disk through `wviewer::snapshot`, which
**rebuilds** the whole viewer sub-dict from the live window, so anything written
at select time is rebuilt over at save time; and `ase::session_dirty`
(`src/ase.tcl:3589`) is **derived** — it serialises `state` and compares it to
`saved` — so an `ase::session_update` from inside a selection would mark the
session dirty and repaint its title on every Location-bar load, breaking the
*snapshot-at-Save-only* contract `ase::ui::viewer_snapshot` documents.

**R602b — `ase::ui::viewer_snapshot` IS WHERE THE PATH BECOMES RELATIVE.**
R602 named three possible homes; this is the ruling R602 asked for.
`wviewer::snapshot` writes the **absolute** path and
`ase::ui::viewer_rawfile_relative` (`src/ase_window.tcl`) turns it into R602's
stored form — relative to the state's rundir when it is **under** it, absolute
otherwise. Why not the other two:

- **not `wviewer::snapshot`**: a rundir is an *ASE state* concept and a viewer
  need not belong to an ASE session at all (`wviewer::echo` exists for exactly
  that reason). Making the viewer layer reach into `ase::` for its own inputs is
  the mistake **R201a** already rejected when it refused to let the resolver take
  an ASE state as its argument. Passing the rundir in would change `snapshot`'s
  arity for one production caller and a dozen suite calls, and would only move
  the decision rather than remove it.
- **not `results::persist`**: see R602a — the flow T-F names never reaches it.

Relativising at the point the value is folded **into** the state also keeps
*absolute in memory, relative on disk* one checkable boundary, and it means
`viewer_snapshot`'s difference test (`$vd eq $prev`) compares the **stored** form
against the stored form.

**The "under it" test is COMPONENT-WISE, not a string prefix.** `<rundir>bis/x.raw`
is not under `<rundir>`, and a `string first` test says it is — which would store
a relative path resolving to a different file on restore. Pinned by SEL347, whose
sabotage **S2** is precisely that substitution.

**R602c — `absolute in memory` IS MADE TRUE, NOT ASSERTED (fix round,
2026-08-20).** The registry stores whatever spelling it was handed — measured:
`cd <dir>; xschem raw read x.raw tran` leaves `xschem raw rawfile` answering
`x.raw` and `results::current` reporting `path x.raw` — so the "absolute here"
half of R602a was a claim the code did not enforce, and a relative engine
spelling flowed straight into the slot. On disk a relative `viewer.rawfile`
means *under the rundir* and nothing else, so such a value named the wrong file
or no file at all on restore (driven: stored `x.raw`, restore status `invalid`,
the user told a result that was current a moment ago "is no longer on disk").
Both sources of the slot therefore normalise **where the cwd is still the one
the path was read in**: `wviewer::selection_record` at record time and
`wviewer::selected_rawfile`'s engine arm at read time.

**R602d — AN ALREADY-RELATIVE `viewer.rawfile` IS A FIXED POINT (fix round,
2026-08-20).** `ase::ui::viewer_rawfile_relative` returns `$vd` untouched when
`file pathtype` is not `absolute`. Without that guard `file normalize` resolved
the value against the **process cwd**, which has nothing to do with the rundir,
and the proc re-relativised its own output. `ase::ui::viewer_snapshot` feeds it
whatever `wviewer::snapshot` returned, *including* the closed-viewer arm's
`[dict replace $prev open 0]` — already in the stored form — so with the cwd
under the rundir a Save State compounded one directory component per save
(`an.raw` → `sub/an.raw` → `sub/sub/an.raw` → …) until the state named a file
that does not exist; the read side then called it `invalid` and told the user
their result had gone missing while it sat on disk. It also made `$vd` differ
from `$prev` every time, dirtying the session on every save of a closed-viewer
state. **Do not `file join $rundir $rf` first either**: that re-absolutises a
value whose meaning was already rundir-relative, which is a different behaviour
change. Pinned by **SEL353**, which drives the proc from a cwd *under* the
rundir and asserts a fixed point.

**R602e — THE RUNDIR IS QUERIED, `ase::rundir` IS NOT CALLED (fix round,
2026-08-20).** `ase::rundir` (`src/ase.tcl:1643`) is a *create-and-default*
helper, not a query: it `file mkdir`s the directory a state names, and for the
common empty `rundir` it falls through to `set_netlist_dir 0`, which **creates
`$USER_CONF_DIR/simulations` and rewrites the global `::netlist_dir`**. Driven
with an empty `::netlist_dir` and `$USER_CONF_DIR` repointed at an empty dir,
one call to `ase::ui::viewer_rawfile_relative` created `simulations/` and moved
the global. A Save State may do neither, so the relativiser reads the state's
own `rundir` key and **an empty one means no relativisation** — the slot keeps
the absolute path, which the read side has always resolved as-is. The cost is
that a session naming no rundir stores a machine-specific path; guessing the
default from `::netlist_dir` instead can disagree with what `viewer_restore`
resolves against once `local_netlist_dir` re-points it per schematic, and a
stored path that resolves to the **wrong** file is worse than one that is merely
unportable. Pinned by **SEL355**.

**R602f — A SAVE NEVER *ERASES* THE STORED SELECTION (fix round, 2026-08-20).**
When neither source can answer — the engine is blind or its ticket was refused,
*and* no choice is recorded for this window — `wviewer::snapshot` keeps the
**previous** dict's `rawfile` instead of writing `{}` over it. Driven: a real
viewer window with no raw loaded in its context turned a stored
`my_chosen.raw` into `{}` in one Save State. R602a's fallback does not cover
this, and the header that said it did was wrong: a selection that came back
**from** a state file has no record behind it at all, because `wviewer::restore`
calls `results::select` with neither `token` nor `key` (R605's own ⚠), so
`results::persist` declines and `selected($token)` is never set. `{}` still
reaches the slot the one way it should — nothing ever selected, nothing ever
stored. Pinned by **SEL357**.

**R605a — A SESSION RESTORE *IS* A SELECTION FOR THE MRU (fix round,
2026-08-20), and it is asserted rather than incidental.** Moving the restore
attach onto `results::select` (R605) made re-opening a saved session push the
attached path into `$USER_CONF_DIR/raw_history` (`results.tcl`'s unconditional
`wviewer::rawhist_push`), which the bare `xschem raw read` it replaced never
did. That is **kept**, because it is 0216's shape — the one durable list should
carry the results the user actually worked with, and a restore attaches and uses
one. It is bounded: `wviewer::rawhist_add` dedupes on the normalised path and
caps at 20, so re-opening the same session repeatedly writes the file **once**
(the second push finds the path already at the head, returns 0, and does not
write). The batch has destroyed two `$HOME` files by leaving a writer's
reachability unasserted, so this one is pinned by **SEL356**, in group AJ's
shape: every writer the flag ungates is shimmed *before* the flag is raised, the
flag is raised around the single call under test, and `::wviewer::rawhist` is
saved and restored.

**R604a — `ok` AND `default` SAY NOTHING; `stale` AND `invalid` SPEAK.** R604
says the status is reported once, on restore, through `ase::echo`, and that this
*extends* `viewer_restore`'s existing no-results sentence rather than adding a
channel. It does not say every status is announced, and announcing every status
is wrong twice over: **every state file written before this item carries
`rawfile {}`**, which resolves `default`, so a sentence there would put a line in
the CIW on every single session open forever; and a successful restore reports
itself in the only way that matters, by drawing the waveforms. `stale` and
`invalid` are exactly the two statuses where what the user **gets** is not what
the state **named** — R202's *"the sentence says why it looks old"* and R201's
*"says which happened"*.

**And it is ONE sentence, not two.** The pre-existing *"no simulation results for
this state"* line keeps the case it was written for and is suppressed when the
resolver has already spoken about the same event — otherwise an `invalid` state
with nothing to fall back to produces both. Pinned by `test_ase_persist`'s
R6a-R6f, which run on **every** arm of that file (no DISPLAY and no ngspice
needed) precisely because §12 names T-E as the batch's one invariant that can be
green by not having run.

**R605 — the clear-then-read ORDER did not move, and that is checked.**
`wviewer::restore`'s `catch {xschem raw clear}` stays exactly where it was and
the door is asked to read into the empty registry it leaves. `results::select`
never clears (F7), so the whole of the "clear before read" behaviour is still the
viewer's own line, in its original position. SEL348 asserts the door is called,
the clear is present, and the clear's offset in the body is **before** the door's.
The restore passes `host none` (R802a) so the one sentence stays
`ase::ui::viewer_restore`'s (SEL349).

---

## 9. Naming a run — the half that does not exist

**This is the section that decides whether the feature is worth building, and it
is the one with no code behind it.**

**R701** There is one derived path per (results directory, cell):
`<netlist_dir>/<cell>.raw` — or ASE's `<rundir>/<cell>_ase.raw`, where `rundir`
is per-session state (`ase::rundir`, `src/ase.tcl:1643-1651`, falling through to
`set_netlist_dir 0`, which is itself per-schematic or per-cell when
`local_netlist_dir` is 1 or 2) (`src/ase.tcl:4777-4783`, with the invariant stated in
its own comment at `:1948-1950`: *deterministic per rundir/cell, runs overwrite
it in place*). **Nothing varies that path per run.** So `Results ▸ Select…`
selects among: whatever is currently loaded, whatever the MRU remembers, and
whatever the user copied aside by hand.

**R702** The one precedent in the tree for per-run identity is
`sim_probe_tmpdir` (`src/xschem.tcl:3397-3401`), which builds
`xschem_probe_[pid]_[clock clicks -milliseconds]_$::sim_probe_seq` — a pid, a
timestamp and a per-process counter in a directory name. It is a scratch dir, not
a result, but it is the shape.

**R703 — the collision surface is DATA, and it is bigger than the code.** 258
tracked schematics (390 occurrences) carry a bare relative `write <cell>.raw`
inside their `.control` block. Those resolve against the simulator's cwd, which
`proc simulate` sets with `cd $netlist_dir` (`src/xschem.tcl:6178`) — so a
per-run **cwd** would relocate all 390 with no data edit at all. That is the
good news and it is why R704 is a *deferral*, not an impossibility.

The actual blocker is the **read** side: ~293 `xschem raw_read $netlist_dir/…`
launcher instances tree-wide (141 of them in the three PDK workareas) name the
flat path explicitly. They are late-bound (`Tcl_GlobalEval` at click time) so
they follow `netlist_dir`, but they do **not** follow a per-run subdirectory —
every one would need to learn which run it means. That is the migration, and it
is a feature's worth of work, not a flag.

**R704 — v1 does NOT introduce per-run result directories.** A run history is
the honest answer to "select a saved result" and it is a separate feature with
R703's read-side migration in front of it. v1 ships selection over *what exists*:
loaded databases, the MRU, and any file the user points at. §17 Q2 asks the
driver whether to schedule the run history at all.

**R705 — but v1 makes the MRU tell the truth.** Issue **0216**:
`attach_raw` — the path every ASE run takes — never pushes to `raw_history`, so
the one durable list of past results systematically omits the results the user
actually produced. Routing the attach paths through `results::select` (R303)
fixes 0216 as a side effect, and is most of what makes a `Recent` list worth
showing in R404.

---

## 10. Messages and refusals

**R801** Every refusal returns a value and writes one sentence. Nothing throws.
This is `rawbar_load`'s existing contract and it is inherited whole.

**R802** The channels, by host: ASE-L → `ase::echo {msg {tag {}}}`
(`src/ase.tcl:138`); the viewer sidebar → `wviewer::browser_status {token msg}`
(`src/wave_viewer.tcl:10538`); the Calculator → `calc::status`. **Never `puts`,
never the status bar directly** — the house rule.

> **R802a is ruled in §5.2** (item 4): the channel default is derived from what
> the caller gave — `token` → viewer sidebar, ASE `key` → `ase::echo`, neither →
> **no emission at all**, with the sentence still in the returned `msg`.

**R803** The sentences say which database, by `db_label` (file tail + analysis),
not by full path — the full path lives in the balloon. `wviewer::db_label`
(`src/wave_viewer.tcl:2414`) already produces this.

**R803a — the RESOLVER's sentences name the file by `file tail`, not by full
path, and not by `db_label`.** RULED 2026-08-19 in the item-2 FIX ROUND. Two
halves. First, the defect: the two `invalid` sentences interpolated the absolute
path while `default`/`ok`/`stale` already used the tail, so the one status a
user meets on a broken restore was the one that put a 120-character path into
R404's one-line Status region. Fixed — R803 binds all four. Second, the limit:
`db_label` is *file tail + analysis*, and the resolver has **no `sim_type` input
at all** (R201a's key set is `rawfile`/`rundir`/`derived`/`key`/`netlist`) — it
resolves a *path*, before anything is loaded, so there is no analysis to name.
The full `db_label` form is reachable only in `results::select` (R302) and in
the dialog (R404), which do know the type. The resolver's obligation is the
tail; the full path stays in the balloon and in the returned `named` field.

**R804** A selection that lands but cannot resolve (F4 — the stamp does not match
the current hierarchy stack) is **reported as such, in those words**, and is not
silently reported as success. This is the sentence the whole feature exists to
avoid having to guess at:

> `Selected srlatch_ase.raw (dc), but this result was read against srlatch.sch and you are in tb_diff_amp.sch — no signal names will resolve until you return.`

> **R804b and R804c are ruled in §5.2** (item 4): the F4 state is measured
> unreachable through `xschem raw select` and the guard is kept anyway; and the
> *"was read against X"* clause needs `opts read_against` from the caller,
> because `raw->schname` has no Tcl accessor — issue **0514**.

**R805** The four resolver statuses each have exactly one sentence form, and
`stale` says *why* it is stale (content verdict, or older than the netlist).

**R805b — `results::select` composes its own form per OUTCOME, and two outcomes
outrank the resolver's verdict.** RULED 2026-08-19 (item 4). The order is: the
F4 sentence (R804) first, then the R102 one — *"`<label>` is now the current
database, but a digital or non-spice database is not a result you can evaluate
against."* — then `stale`/`invalid`/`default`/`ok`, because a selection that
landed somewhere unusable is not described by how its *path* resolved. Nine
distinct outcomes produce nine distinct sentences and none is empty (SEL286).
Two implementation notes worth keeping: `switch` is **not** used to dispatch on
the status, because one of the four statuses is spelled `default`, which is also
`switch`'s catch-all keyword and would answer the `default` STATUS for every
unknown one without ever being seen to be wrong; and the refusal arms do **not**
re-word the resolver's own sentence when it already said why (R805's one form
per status).

**R805a — one terminator, not two.** `stale` composes *"Using `<tail>`, but
`<why>`."*, and its two `why` sources are shaped differently: the mtime half's
is written here as a clause, while the content half's is quoted verbatim from
`ase::raw_content_verdict` (R203 forbids restyling it) and is already a
finished, full-stopped sentence — so every content-half message ended in `..`.
The composition strips one trailing full stop from `why`. **Only the composed
`msg` is trimmed**: the returned `why` field stays the verdict's own words,
because that is what R203 is pinned on.

---

## 11. Landmines

**L1 — `select_raw` does not return `{}` headlessly.** `src/xschem.tcl:16672-16685`
computes a guessed default (`$netlist_dir/<current cell>.raw`) *first*, then
overwrites it with `tk_getOpenFile` **only inside `if {[info exists has_x]}`.
With no `has_x` it returns the guess.** A headless test that expects "cancel →
`{}`" will instead see a plausible path and a real selection. Shim `select_raw`
in tests; never rely on its headless return.

**L2 — two `xschem` verbs, one underscore apart, opposite semantics.**
`xschem raw read` appends (`src/scheduler.c:10355`, `extra_rawfile(1 | …)`);
`xschem raw_read` **clears the whole registry** and then reads (arm
`src/scheduler.c:10850-10889` — the `extra_rawfile(3, NULL, NULL, …)` at
`:10865`, the read at `:10884`). Issue **0508**. Write `raw read`.
**Re-derived 2026-08-20 (item 8): this line said `:10776-10793`, which items 1
and 3 of this batch had already staled by ~74 lines.**

**L3 — `raw read` of an already-loaded file returns success without re-binding.**
F5, issue **0509**. Until R110 lands, `results::select` must detect this case
itself (registry size unchanged) and either re-stamp with `xschem set raw_level`
or refuse honestly. It must **not** clear-then-read — R301(3), F7 and T-D forbid
it.

**L4 — the shared scratch column.** `raw->values[raw->nvars]` is one buffer
overwritten by the next evaluation; re-evaluate immediately before reading
(`doc/claude/specs/calculator.md` L2). Switching results between an evaluation
and its read is the same bug wearing a new hat.

**L5 — a cached `SPICE_DATA *` belongs to one `Raw`.** `raw_add_vector()`
reallocs, and a selection change reassigns `xctx->raw` without freeing
(`src/save.c:1977-2015`), so a stale pointer does not crash — it silently reads
the *other* database. No cached `SPICE_DATA *` may survive a selection change.

**L6 — a `<NULL>` `sim_type` makes a slot unreachable BY NAME.** Both
name-lookup loops in `extra_rawfile()` require a non-NULL `sim_type`
(`src/save.c:1934`, `:1985`), so `raw switch <path> <type>` can never reach such
a slot again — pinned by `tests/headless/test_raw_read_dispatch.tcl`. Switching
by **index** still reaches it. `results::select` must never pass an empty type
through as NULL when the caller had one.

**L7 — no `update`, no `after`, while the current-DB pointer is swapped.** A
redraw during a walk draws the wrong waveforms
(`doc/claude/specs/waveform_signal_browser.md:917-918`). `signal_list_all`
(`src/wave_viewer.tcl:2443`) restores the cursor unconditionally *outside* the
loop's catch; copy that shape.

**L8 — `ase::attach_dbs` purges more than it looks like.** It does a targeted
clear of the incoming path (`src/ase.tcl:2903`), reads it (`:2904-2908`), then
**wipes every other slot highest-index-first** (`:2912-2919`), reads the VCDs,
and switches to slot 0 only `if {[llength $got]}` (`:2928`). It is the *run*
path, and its purge is deliberate. Do not model `Select` on it.

**L10 — `xschem raw switch <path>` with no type finds nothing.** The
switch-by-name arm is guarded `if(file && type)` (`src/save.c:1978`); with no
type it falls through to the by-index form. Always pass the type, or pass the
index from `results::list`.

**L11 — the MRU is gated off in automation.** `wviewer::rawhist_push` no-ops
unless `::update_recent_files` is set — the same flag the recent-files cluster
uses (issue 0119). A test asserting an MRU delta must set and restore it, and a
scripted selection legitimately leaves no trace in the history.

**L9 — stale in-source citations.** Comments in `wave_viewer.tcl`,
`calculator.tcl` and `ase.tcl` that cite other files were measured to be
systematically stale (the `rawinfo_parse` comment alone is wrong twice — issue
0507). Re-grep every one before quoting it. **Item 9 fixed those two and two
more in `ase.tcl`, and made them self-checking**: `test_results_select` SEL468 /
SEL469 extract the `save.c:<a>-<b>` citation out of each comment and assert that
the cited range actually contains the printer — a citation check that only
matched the *shape* of a citation would be satisfied by any number at all.

**And the twin, measured in the item-2 FIX ROUND: an insertion into
`src/xschem.tcl` silently stales every `xschem.tcl:<line>` citation below it.**
Item 2's 8-line `source $XSCHEM_SHAREDIR/results.tcl` block at `:16760` shifted
12 citations across six documents by +8 — including two in this spec, two in
`doc/claude/results_batch/PLAN.md` and two in issue **0508**, which item 8 of
this same batch is scheduled to close. Nothing goes red: no check and no source
comment cites a line above the insertion point, so the whole cost is paid by the
next reader who follows a pointer. **Any insertion into a file other documents
cite by line number obliges a re-grep** —
`grep -rnoE 'xschem\.tcl[:# ]+1[6-8][0-9]{3}' doc/ src/ tests/` — and a
re-derivation of each number from its symbol, never a blind `+N`.

---

## 12. Verification invariants

Each is a `check` in a headless suite. Suite names: `test_results_select.tcl`
(new) plus additions to `test_calc_skeleton`, `test_wave_sigbrowser_i1315`,
`test_ase_persist`. **T-E is the exception**: it extends `test_ase_persist`'s
G10/G11, whose legs self-skip without a usable DISPLAY or without ngspice — so
T-E can be green by not having run. Assert the skip reason, not just the count.

| id | invariant |
|---|---|
| **T-A** | Selecting a not-yet-loaded file leaves that path present exactly once in the registry and current, and `results::current` returns it. (Not "adds exactly one slot": the first read into an empty context also adopts the base raw into slot 0, `src/save.c:1857-1862`.) |
| **T-B** | Selecting an already-loaded `(path, type)` adds **no** slot, makes it current, **and** leaves `xschem raw index <known name>` ≥ 0 **while standing on a different cell from the one it was originally read against** (0509's scenario: read under A, `xschem load` B, re-select there) — the R110 re-stamp. Sabotage: revert the re-stamp, T-B goes red. |
| **T-C** | `wviewer::rawbar_load`'s observable behaviour is byte-identical before and after the re-expression: same rc, same registry delta, same MRU delta (with `::update_recent_files` set and restored — L11), same status string, and the same two arms staying silent. |
| **T-D** | A failed selection (garbage path) leaves the previous selection intact — registry, `raw rawfile` and `raw list` all unchanged — and returns 0 with a sentence. F7. |
| **T-E** | Restore of a state whose `viewer.rawfile` is **relative** attaches it (extends `test_ase_persist` G11); restore of one whose file was **deleted** falls back and says so (extends G10). **DELIVERED, item 6** — G11 could not tell "the stored name was followed" from "the derived default is the same file", so **G11b** stores a *second* raw under a name the derived default can never produce; the "says so" half is `test_ase_persist`'s **R6a-R6f**, which run on **every** arm of that file (shims, no DISPLAY and no ngspice needed) plus the G10 capture, and `te_why` re-measures the skip preconditions and asserts the recorded reason against them. |
| **T-F** | `wviewer::snapshot` writes a non-empty `rawfile`, relative when under `rundir`, and a save→restore round-trip re-selects the same result. This is the assertion that would have failed for the whole life of the seam. **DELIVERED, item 6** — `test_ase_persist` G7 (restated: it used to pin the hardcoded `{}`) and G8, with the writer's machinery in `test_results_select` group AO. |
| **T-G** | Selecting result B while a graph carries a `%<rawfileA>` trace suffix leaves that trace resolving against A. Per-trace addressing is not selection. |
| **T-H** | The four resolver statuses each produce their own sentence; `stale` still yields the named path, and `invalid` yields the derived path when one exists on disk and `{}` otherwise — never an error. |
| **T-I** | Cross-context: the Calculator's Results Dir row and `results::current` agree, or the row says it is reporting a borrowed path. §17 Q3 ruled the **first** arm (U3: the row PICKS). **DELIVERED, item 10** — `test_calc_skeleton` S27 asserts the row, `calc::require_result`'s answer and `results::current` (read in the borrowed context, which is where the read happens) name one path; and §7.1a R503a makes it structural rather than coincidental by resolving ONCE and publishing the row from that measurement; **R503g** extends the assertion from the file to the SLOT (`type` and `idx`), because R407c clause (1) and U11 make a by-path answer ambiguous across a two-plot raw. S26 is RESTATED, not deleted: it used to pin the `self → viewer → ase → none` order that U6 and R502a dismantled. **⚠ ONE STATE IS STILL OUTSIDE T-I's first arm and is filed rather than fixed:** in R407a's `here` arm the row says `(no raw file loaded)` while `results::current` in the same context names a selection — it neither agrees nor says it is reporting. Issue **0516**; the refusal at least stops naming a gesture that cannot help (R503f). |
| **T-J** | A **refused** borrow ticket is reported as refused, never as "no results". F6. **Split across items in the item-4 fixer round — see the note below the table.** |
| **T-K** | Grep test: no **by-word** parser of `xschem raw info` survives — `raw_is_loaded`'s `foreach {n f t} [lrange … 2 end]` is gone, and every new consumer is built on `wviewer::rawinfo_parse`. (LINE-wise readers already exist — `rawinfo_parse`, `ase::raw_indices` `src/ase.tcl:2935`, `ase::raw_current` `:2943`, the inline per-line regexp at `src/ase.tcl:3241-3245`, and the test helpers — so "exactly one parser" is not the assertion.) Issue 0507's ruling, pinned. **DELIVERED IN TWO HALVES:** item 2's SEL82/SEL83/SEL84 over `src/results.tcl`, and item 9's group AP (SEL459-SEL474) — the proc **removed** (R304c), the detector run over **all 28** `src/*.tcl` and all **358** `tests/headless/*.tcl` on source stripped of both whole-line `#` and trailing `;#` comments, covering **four** by-word shapes with its own positive and negative controls, plus the two rotted citations 0507 filed now asserted to RESOLVE against `src/save.c`. |
| **T-L** | Grep test: no Waves-menu **load** entry reaches `xschem raw_clear` or the registry-clearing `xschem raw_read`; the `Clear` entry (`src/xschem.tcl:17335`) is the sole permitted caller. Issue 0508, pinned. **DELIVERED, item 8** — as a `cadence_compat` GATE, not a repair (U4/U12): the eight loading entries funnel into `load_raw`, whose first executable statement is the guard, and `tests/headless/test_waves_gate.tcl` proves it by census + position (WA) and by clicking every cascade entry in BOTH flag states (WC/WD). Outside `cadence_compat` the destructive path is UNCHANGED and asserted so. **Fixer round 2026-08-20: the census is no longer one file and two verbs** — it reads `src/xschem.tcl` AND `src/actions.csv` (the command-palette surface, nine `waves` rows), and its pattern covers `raw_clear`, `raw_read` and `raw_read_from_attr` (SEL418/SEL419/SEL457). |
| **T-M** | A selection whose stamp does not match the current hierarchy stack is **not** reported as success (R804) — sabotage: make `results::select` return ok unconditionally, T-M goes red. |

**T-J IS TWO HALVES AND ONLY ONE OF THEM IS ITEM 4'S** (ruled in the item-4
fixer round, after a reviewer found the receipt claiming the whole of T-J).
T-J names an F6 **borrow ticket** — `wviewer::enter_ctx {token ?borrow?}` →
`{ok prev ?sem?}` (§F6). **R302e removes the context switch, and therefore the
borrow, from `results::select` entirely**, so a refused borrow ticket cannot
arise inside that proc: `grep -n 'borrow\|enter_ctx\|leave_ctx' src/results.tcl`
returns nothing, by design and not by omission. The halves are therefore:

- **the refused-SELECT half — item 4, delivered.** A refused selection is
  reported as refused, **naming the database**, and never as "no results";
  *both* refusal arms emit, and the resolver's arm is a different route out of
  the proc from the engine's. SEL230, SEL231, SEL279 and SEL288.
- **the refused-BORROW half — items 5 and 10.** R302e left `switch_ctx` in
  `wviewer::rawbar_load` (R501), so item 5 owns the borrow on the viewer side;
  the Calculator's cross-context read (R502, T-I) owns it on the other.
  Whichever of them takes the ticket must drive a **refused** one and assert the
  sentence names the database rather than reporting an empty result list (F6).
  - **Item 5's side is RULED AND DISCHARGED, 2026-08-19 — see R501b (§7.1).**
    `rawbar_load` takes **no ticket**: `switch_ctx` is a move and the
    `enter_ctx`/`leave_ctx` idiom is in neither this proc nor `results::select`
    (SEL332, both). Its refused switch is driven — through a shimmed
    `switch_ctx`, which is the only way to reach it deterministically — and it
    returns **0**, the same value every other refusal returns, with **1** the
    only success value (SEL303/SEL304, SEL319). F6's defect is a refusal that
    reads like an answer; this path has no answer for one to be mistaken for.
    The remaining complaint is that arm 4 writes no *sentence*, which is an
    **R801** gap and not a T-J one: filed as issue **0515**, left unfixed
    because T-C's own wording freezes the silence.
  - **Item 10's side is RULED AND DISCHARGED, 2026-08-20 — see R503c
    (§7.1a).** The Calculator takes a **real ticket**: `calc::session_result`
    (`src/calculator.tcl:924`) brackets every cross-window read in
    `wviewer::enter_ctx $tok 1` / `leave_ctx`, and a refused ticket is *skipped*
    (another viewer may hold the session's result) **and remembered**, so a walk
    that ends with nothing reports `refused`, never `none`. It is the sharpest
    instance of T-J in the batch, because *"No simulation results are loaded"* is
    **also a legitimate answer this window gives** (U7's) — so the two sentences
    are two procs with two texts, the refusal denies the wrong reading in words,
    and a check asserts they are different strings. Driven at both surfaces (the
    row and Evaluate) and sabotaged twice: `busy_msg` returning `no_result_msg`
    reds three checks, and dropping the refusal record altogether reds six.

Neither item may mark T-J complete on the strength of item 4's four checks.

**Anti-vacuity, per `doc/claude/specs/calculator.md` §11.3's two notes:**
existence + class + `cget` is not proof a control is mapped — assert
`winfo manager` / `ismapped` / slave order. And a rule proved only by reading the
source is proved by **moving** the source, not by re-reading it.

---

## 13. Design decisions that can change

| # | decision | default | if reversed, redo |
|---|---|---|---|
| **D1** | A result is a `.raw` **file**, not a directory | file (inherited: calculator.md §13) | §2, §4, §6 R404, and the Calculator's Results Dir row |
| **D2** | `Loaded` listed above `Recent` above `Path` | as stated (R405) | §6 R404 only |
| **D3** | New verb `xschem raw select` vs `read` + R110 alone | new verb | §5, §12 T-A/T-B |
| **D4** | The dialog is modeless (ASE family) | modeless (R402) | §6 entirely; a vwait-latch rewrite |
| **D5** | Selection persists in `viewer.rawfile` | yes (R601) | §8, T-E/T-F |
| **D6** | Relative-when-under-`rundir` path form | relative (R602) | §8 R602, T-F |
| **D7** | v1 has no per-run result directories | none (R704) | §9 entirely; a read-side migration of ~293 `raw_read` launcher sites |
| **D8** | v1 has no key chord | none | an `action_registry[]` entry + `keybindings.csv` row |
| **D9** | `stale` is selected anyway | yes (R202) | §4, T-H |
| **D10** | The eight Waves *load* entries + `Op Annotate` are **blocked under `cadence_compat`**, and unchanged without it | RULED §17.2 | §7, T-L, and issue 0508 |
| **D11** | Digital/VCD databases are not independently selectable | not (R102) | §2, §16 |
| **D12** | No cascade added to the waveform viewer's menubar | none (R504) | `test_wave_viewer` G2's frozen list |
| **D13** | `Results ▸ Select…` lives only in ASE-L | RULED §17 decision 5 | §6 |
| **D14** | The Calculator's `Browse` stays disabled | RULED §17 decision 9 | §7 R502 |
| **D15** | Analysis choice is not part of result selection | RULED §17.1 | §19, and the accessor spec |

---

## 14. Where we go beyond Cadence

1. **Selection over already-loaded databases is the primary gesture**, not a file
   chooser (R405). Cadence's Select is a chooser because PSF directories are
   heavy; xschem's registry is already populated and switching is free.
2. **Per-trace cross-database addressing exists without a history.** A single
   graph can carry traces from three results via `%<rawfile> <sim_type>`; Cadence
   requires named histories to do the same thing.
3. **The refusal names the reason.** R804's sentence — "this result was read
   against *X* and you are in *Y*" — has no Cadence analogue because Cadence has
   no such coupling. We have the coupling; the least we can do is explain it.
4. **The resolver never errors.** `invalid` falls back and says so (R202).
   Copied from the simulator-profile work, which learned it the same way.
5. **One parser, pinned by a grep test** (T-K). Issue 0507 exists because there
   were two.

---

## 15. Deliberate deviations from Cadence

| Cadence | Here | Why |
|---|---|---|
| `Results ▸ Select` picks a **data file**; the Results Browser Location field takes a **directory** — two mechanisms | one mechanism over `.raw` **files** | ngspice writes one file, not a directory (F1, calculator.md §13) |
| `Results ▸ Save` names a run into a history | absent in v1 | nothing varies the output path per run (R701); R704 defers it |
| Selection is independent of the schematic on screen | selection is bound to the cell it was read against, and says so | `raw->schname` is the existing data model (F4); R804 makes the coupling visible rather than pretending it is not there |
| `Update` vs `Reload` vs `Clear` distinction | one `Select`, which re-binds — and re-reads only a file not already in the registry (R301) | xschem has no frozen-graph concept for `Reload` to spare |
| Selection form is modal with OK | modeless, `Select` + `Close`, stays open | comparing two runs means selecting twice (R406); and ASE's dialogs are modeless to stay test-drivable |

---

## 16. Non-goals for v1

- **Per-run result directories / a run history.** R704, D7.
- **Independently selecting a VCD or table database.** R102.
- **A PSF reader.** Not a ViVA format question — xschem does not read PSF at all
  and this spec does not change that.
- **Relaxing `sch_waves_loaded()`.** §3.1's non-goal; issue 0509 candidate 2.
- **A Results Display Window** for `Results ▸ Print`. The Calculator's Table
  (its §9, R606) is the nearest planned surface.
- **A key chord.** D8.
- **A cascade in the waveform viewer's menubar.** R504, D12.
- **Cross-*window* selection sharing.** The registry is per-`xctx` (F2); two
  windows genuinely have two selections and v1 does not synchronise them.

---

## 17. Decisions — RULED 2026-08-18 by the user

Every question below was put to the user in plain language with worked
examples, and answered. The original question is kept; the answer follows in
bold. **Nothing here is an assumption any more.**

1. **How much C does v1 need — a new `raw select` sub-verb, R110's re-stamp on
   `read`, or neither?** (D3.) Three rungs: a new verb buys a three-valued
   return and a clean name; `read` + R110 buys the same behaviour with no new
   verb; and **`xschem set raw_level` already re-stamps from Tcl**
   (`src/scheduler.c:12275-12297`), so a v1 with **zero C change** is possible.
   **NOT RULED — still open.** Assumption stands: R110 plus the new verb.
2. **Is a run history (per-run result directories) wanted at all, and when?**
   (R704, D7.) **NOT RULED — still open.** Assumption stands: not in v1. Note
   R703's correction: the 390 bare relative `write` lines are *not* the blocker
   (a per-run cwd moves them for free); the ~293
   `raw_read $netlist_dir/<cell>.raw` launcher sites are.
3. **What does the Calculator's Results Dir row promise?** (R503.)
   **RULED: the row PICKS the result.** It stops being a label. The Calculator
   loads what the row names into its own context and evaluates against it —
   what the row shows is what you get, and changing the row changes what
   Evaluate reads. R503's contradiction is closed in favour of the selector.
4. **Do the Waves-menu entries stop clearing the registry?** (R505, D10, issue
   0508.) **RULED, and reshaped — see §17.2.** The Waves menu is *legacy upstream
   xschem*, not ours (`proc waves` arrives in `5e8df730`, the repo's first
   commit). It is gated on `cadence_compat` rather than repaired in place.
5. **Does `Results ▸ Select…` also appear on the schematic editor's menubar**,
   or is ASE-L its only home? **RULED: ASE-L only.** ASE-L is what ties a
   *design* to results; the schematic editor is not a results holder and is not
   given a second door to become one.
6. **Where does the Calculator look for results?** (R305, R503.)
   **RULED: the ASE-L session, and nothing else.** The `self` arm — this
   window's own context — is **removed entirely** from `calc::results_source`,
   not merely demoted. The Calculator never reads a raw that a legacy path put
   into a schematic window.
7. **What does Evaluate say when no result exists?** **RULED: refuse, and name
   the next action** — *"No simulation results are loaded. Run a simulation, or
   pick an existing one with ASE-L ▸ Results ▸ Select."* Naming the command
   beats a neutral refusal; the Calculator does **not** offer to launch ASE-L
   itself.
8. **Does a Calculator selection drag the waveform viewer with it?**
   **RULED: no.** Each window keeps its own choice, matching how xschem already
   works. Comparing two runs stays possible.
9. **Does the Calculator's `Browse` button come alive?** (R502.)
   **RULED: no — it stays greyed out.** Browsing to a result is
   `ASE-L ▸ Results ▸ Select`'s job. The Calculator consumes the session's
   selection; it does not make one. **This supersedes R502**, which had Browse
   becoming live; R502 is now "Browse stays disabled, and the spec says why".
10. **Graph rects with `autoload=` are a third legacy door. Block them?**
    **RULED: leave them alone for now.** They are drawn objects saved inside
    `.sch` files and blocking them would change how existing schematics render.
    Recorded in §18 as a known remaining door.

### 17.1 The result model — RULED, and it corrects §2

**ONE RUN PRODUCES ONE RESULT.** Analyses are *dimensions inside* a result, not
separate results. This corrects R101's framing: `(rawfile, sim_type)` is the
**engine's** identity key, and the engine stores one slot per analysis — but the
thing a user selects is the **run**, and selecting it makes all of its analyses
available at once.

Measured, on a file holding both a DC sweep and a transient:

```
0  /…/multi.raw  dc
1  /…/multi.raw  tran      <- current
```

Two registry slots, one file, one run, one result.

**What "current result" means, ruled:** the most recently **finished run** is the
loaded result, with no further action. A user may go to another ASE-L window and
load results there, and that becomes the current result instead. It is a
session-level pointer set by *running* or by *selecting* — never by which window
happens to have focus (which is why decision 6 removes the `self` arm).

**Which analysis is "current" is NOT part of this.** That question is answered by
the expression itself, and belongs to the typed-accessor work — §19.

---

### 17.2 The Waves menu is gated on `cadence_compat` — RULED

Decision 4's answer, in full. The Waves menu is **legacy upstream xschem**:
`proc waves` arrives in `5e8df730` *"populating xschem git repo"*, the repo's
first commit; the menubar it hangs on came from `b23b162f`. It is not ours, and
the direction is away from it.

- **Under `cadence_compat`**: the **eight loading entries** (`Load first analysis
  found`, `Op`, `Dc`, `Ac`, `Tran`, `Noise`, `Sp`, `Spectrum`) **and
  `Op Annotate`** are blocked. Clicking one says why and names `cadence_compat`,
  pointing at `ASE-L ▸ Results ▸ Select`. The user must not be able to reach a
  bad state in Cadence mode; the expected number of Cadence-mode users who want
  this menu is zero.
- **`Clear` and `External viewer` keep working** — neither loads a result.
- **Without `cadence_compat`**: the menu works as it always has. A user outside
  Cadence mode may mess things up if they wish. Issue **0508**'s registry-wiping
  behaviour is *documented* rather than repaired in that mode.

`cadence_compat` is an established gate here, not a new mechanism:
`set_ne cadence_compat 0` (`src/xschem.tcl:18435`), a menu checkbutton
(`:17177`), read from C via `tclgetboolvar("cadence_compat")`
(`src/callback.c:633`), and it already carries a write-trace that force-enables a
bundled setting (`cadence_compat_sync` → `autotrim_wires`, `:18896-18907`).

**This closes the wrong-cell case for Cadence-mode users *through the Waves
cascade*.** F4's blind-database scenario is reachable only through the legacy
doors; with all nine Waves entries blocked and only `autoload=` graph rects left
(decision 10), a `cadence_compat` user cannot get there through the **Waves**
menu.

**It is NOT true of the whole menubar, and item 8 measured that rather than
assuming it** (corrected in place, fixer round 2026-08-20 — an earlier draft of
this paragraph said *"cannot get there through a menu"* and put the correction
sixty lines away in §18, where the reader who needs it does not land).
`Simulation ▸ Graphs ▸ Annotate Operating Point into schematic`
(`src/xschem.tcl:17709-17718`) is a **verbatim twin** of the Waves `Op Annotate`
body — same `select_raw`, same `xschem annotate_op` — and is **ungated**; driven
in Cadence mode it calls `select_raw` once and adopts a result with no refusal.
`Simulation ▸ Graphs ▸ Add waveform reload launcher` (`:17704-17708`) places a
`launcher.sym` whose `tclcommand=` is a bare registry-clearing `xschem raw_read`.
Both are named in §18. Leaving them is a scope decision — U12 names the Waves
cascade — and gating the twin is a one-line call to `waves_gate_blocked`
(R505b made the gate a proc) for whoever wants the sentence to hold menubar-wide.

## 18. What is NOT here

**Five paths adopt a raw and will still bypass `results::select` after this
spec ships.** Naming them, per `doc/claude/specs/simulator_profiles.md:2408-2427`'s
idiom, rather than gesturing at them:

- **`ase::attach_dbs`** (`src/ase.tcl:2866`) — the *run* path. It purges
  deliberately (L8) and is the only caller of the content check. Out of scope:
  a run is not a selection.
- **`open_sub_schematic` / `hi_descend`'s new-window arm** (`src/xschem.tcl:7973`,
  `:8264`) — the descend-into-a-new-window carry, which does `xschem raw_read`
  (registry-clearing) followed by `xschem set raw_level`. It is the one existing
  caller that already re-stamps, and bringing it onto `results::select` is
  desirable but is a descend-path change, not a selection-path one.
- **The graph rect's `rawfile=` / `autoload=`** — a per-object binding read at
  draw time. It is Cadence's per-call `?result` override (the *Per-call `?result` /
  `?resultsDir` override* row of §1.1), not a session selection, and stays as it
  is.
- **`xschem raw_read_from_attr` / `embed_rawfile`** — the base64 `spice_data=`
  route that stores a result *inside* a `.sch`. It is the only thing in the tree
  that survives a re-run without a manual copy, and it is out of scope.

**Not a bypass, deliberately:** `wviewer::restore`'s inline attach
(`src/wave_viewer.tcl:4213-4246`) comes **onto** `results::select` under R605.
What is deferred there is only its clear-then-read *order*, which is a measured
behaviour change needing T-E.

**Checked against the shipped `results::select` (item 4, 2026-08-19): the list
above is unchanged — item 4 added no bypass and removed none.** It landed the
door; it converted no caller, which is items 5, 6 and 10. The two paths that
*could* have moved and did not: `results::select` does not switch context
(R302e), so `rawbar_load`'s own `switch_ctx` stays where it is; and the
persistence write is a named no-op seam (R302g), so nothing yet writes
`viewer.rawfile` and §8's seam is still unfilled. `wviewer::rawbar_load`,
`ase::ui::viewer_restore`, `wviewer::restore` and `calc::results_source` all
still reach the engine directly, exactly as they did at `226302f9`.

**Re-checked after item 6 (2026-08-19): the five-path list is STILL unchanged,
and two of the four callers named above have moved off the engine.**
`wviewer::rawbar_load` came onto the door in item 5;
`wviewer::restore`'s inline attach and `ase::ui::viewer_restore`'s hand-written
resolver came onto it in item 6 (R605 / R604), leaving `calc::results_source`
(item 10) as the last one. Item 6 added **no** bypass: the value
`wviewer::snapshot` writes is read through `results::current`, not through a
second registry reader, and `wviewer::selected_rawfile`'s engine call is the one
new `xschem raw`-adjacent read it introduces — read-only, inside the 0173 loan.
**`ase::attach_dbs` stays exactly where it is**, and R602a turns that on its
head as a *design input* rather than a gap: because the run path does not come
through the door, the persisted value is taken from the engine and not from a
remembered selection.

**Re-checked after item 7 (2026-08-20): the five-path list is STILL unchanged,
and the dialog is a NEW caller that comes through the door rather than a sixth
bypass.** `ase::ui::rsel_commit` reaches the engine only through
`results::select`; every other engine call the dialog makes is a **read** —
`results::list` (through `results::resolve`/`results::current`'s own reader),
`xschem get current_win_path` inside the 0173 loan, and nothing else. Two things
item 7 deliberately did **not** do, both of which would have widened this list:
it does not call `xschem raw read`/`raw switch`/`raw select` itself, and it does
not touch `ase::attach_dbs` (L8 — a run is not a selection). It also adds no
persistence write of its own: R602a's engine-read at snapshot time already
covers a dialog selection, because the dialog moves the engine.

**Re-checked after item 8 (2026-08-20): the five-path list is UNCHANGED, and the
Waves menu was never on it.** §18 lists the paths that adopt a raw *without*
`results::select`; the Waves menu was excluded because it was item 8's own
business, and item 8 did not convert it — it **gated** it (U4/U12). So after item
8 the Waves menu is still a bypass **whenever `cadence_compat` is 0**, which is
the default, and 0508's registry wipe is still exactly what it was. `Clear` and
`External viewer` adopt nothing and are not bypasses in either mode. Gating added
no path and removed none: `load_raw` reaches the same two C verbs it always did,
and `waves_gate_blocked` reads a Tcl flag and writes two message channels.

**Two doors item 8 MEASURED and deliberately left open**, recorded here so the
next reader finds them named rather than rediscovering them:

- **`Simulation ▸ Graphs ▸ Annotate Operating Point into schematic`**
  (`src/xschem.tcl:17709-17718`) is a **verbatim twin of the Waves cascade's
  `Op Annotate` body** — same `select_raw`, same `xschem annotate_op`. U12 names
  the Waves cascade, so gating it would be scope creep. **§17.2 was corrected in
  place in the fixer round** to say so where the reader lands, rather than
  claiming menubar-wide closure here and qualifying it sixty lines later. Gating
  the twin (a one-line call to `waves_gate_blocked`, since R505b made the gate a
  proc) is a bounded follow-up for whoever wants that sentence to hold
  menubar-wide.
- **`Simulation ▸ Graphs ▸ Add waveform reload launcher`**
  (`src/xschem.tcl:17704-17708`) places a `launcher.sym` whose `tclcommand=` is a
  bare `xschem raw_read $netlist_dir/<cell>.raw tran` — the registry-clearing
  verb, inside a **drawn object saved into the `.sch`**. That is U10's territory
  (graph rects with `autoload=`): blocking it would change how existing
  schematics behave, so it stays. It is the third `other` row in
  `test_waves_gate.tcl`'s SEL418/SEL419 census, which is where a NEW unclassified
  caller of either verb would go red.

**Re-checked after item 10 (2026-08-20): the five-path list is UNCHANGED, and
the LAST of the four callers named above has come off the engine.**
`calc::results_source` no longer reaches `xschem raw rawfile` at all — a grep of
the comment-stripped `src/calculator.tcl` for that verb returns **zero** lines,
asserted by `test_calc_skeleton` S27 — and what replaced it is a **reader**,
`results::current`, taken under the 0173 loan. So all four of §18's
directly-reaching callers (`wviewer::rawbar_load`, `ase::ui::viewer_restore`,
`wviewer::restore`, `calc::results_source`) are now converted.

Item 10 adds **no** bypass and could not: the Calculator **adopts nothing**. It
does not call `results::select`, `xschem raw read`, `raw switch` or `raw select`
— a second S27 grep pins the first of those at zero, which is U8's mechanism as
well as R303's (each window keeps its own choice, so comparing two runs stays
possible). The one thing it writes is its own row and its own status line. The
five paths that still adopt a raw without the door are exactly the five listed
above, and the Waves menu is still a bypass whenever `cadence_compat` is 0.

**Also not here:** the netlist-time and simulator-profile machinery
(`doc/claude/specs/simulator_profiles.md`), which decides *how a run is
produced*; this spec starts after a `.raw` exists. And the Calculator's own
build (`doc/claude/specs/calculator.md` + `doc/claude/calculator_batch/PLAN.md`,
phases 2–10; 0 and 1 have shipped), which consumes a selection but does not make
one.

---

## 19. The `v(out)` → `VT(out)` transition — scope note

Raised by the user 2026-08-18 while ruling §17, and **deliberately not built
here**. Recorded so the rulings are not lost; the work gets its own spec and its
own batch, **after** this one, because Results Selection settles *which file* and
the accessors settle *which analysis inside it*.

**The problem:** `v(out)` is ngspice's own vector name and says nothing about
which analysis it came from. With a DC sweep and a transient both loaded from one
run, `v(out)` resolves in both and gives different numbers depending on which
slot is current. Cadence removes the ambiguity by putting the analysis in the
expression: `VT("/out")`, `VS(...)`, `VDC(...)`.

**Rulings already taken (user, 2026-08-18):**

| # | ruling |
|---|---|
| A1 | **Its own spec and batch, after Results Selection.** Calculator item 8 ships speaking `v(out)`. |
| A2 | **Spelling: xschem paths, no quotes** — `VT(out)`, `VT(x1.x2.net5)`. Cadence's quoted `VT("/x1/x2/net5")` is *not* copied: nothing else in xschem quotes a node name, and the engine splits on whitespace. |
| A3 | **Full set in v1:** voltage and current, all four analyses — `VT`/`VS`/`VF`/`VDC` and `IT`/`IS`/`IF`/`IDC`. |
| A4 | **`v(out)` keeps working**, meaning "the current analysis", so saved schematics keep rendering. But **nothing the tool emits uses it any more** — every generated expression is typed. |
| A5 | **`VF(out)` alone is the magnitude.** |
| A6 | **Add the Cadence wrapper names** `mag` / `phase` / `real` / `imag`, compiling to vectors that already exist; the existing `ph()` / `re()` / `im()` spellings keep working. |
| A7 | **Rewrite the 24 tracked schematics** that carry `v(...)` inside a `node=`. Each graph box already records its own `sim_type=`, so the correct accessor is known without guessing. |
| A8 | **Direct Plot** detects which analyses the run produced and offers the choice; with only one it plots straight away — but always emits the *typed* accessor, never `v()`. ASE-L knows the analysis. |
| A9 | **Ctrl-4 is not Direct Plot.** It is the transient bindkey. If it is cheap, let Ctrl-4 also work when a run contains exactly one analysis, whatever that analysis is; Cadence restricts it to transient, and xschem need not. |

**Two measured facts the accessor spec must start from, both cheaper than they
look:**

1. **The token shape already exists.** The RPN engine has 40 ops spelled
   `name()` (`sin()`, `db20()`, `del()`, …, `src/save.c:3560-3612`), and a bare
   token that is not an op is looked up as a vector name. `VT()` fits the
   existing grammar — this is a **resolver** layer, not a parser rewrite.
2. **AC is already split into four real vectors at read time.** For a complex
   raw the reader produces `v(out)`, `ph(v(out))`, `re(v(out))`, `im(v(out))`
   as separate named vectors — measured on `cmos_ac_sweep_ase.raw`. So there is
   no complex object to carry: `mag`/`phase`/`real`/`imag` each compile to a
   name that is already in the file. (Careful: `re()`/`im()` are *also* RPN
   operator names doing magnitude+phase→rectangular — same spelling, different
   thing.)

Also note the analysis type is already recorded, just elsewhere: graph rects
carry `sim_type=` (tracked schematics: 100 `tran`, 35 `ac`, 26 `dc`, 3 `op`) and
node tokens can carry `%<dataset> <rawfile>`. The accessors move that fact into
the expression.
