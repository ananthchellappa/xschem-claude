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
| A correct parser for that listing | `wviewer::rawinfo_parse {text}`, `src/wave_viewer.tcl:2380` (PURE, per-LINE) |
| A content check that refuses ngspice's `constants` plot and an empty plot (and deliberately says nothing about a file it cannot parse) | `ase::raw_content_verdict {path}`, `src/ase.tcl:2794` |
| A safe adopt sequence | `ase::attach_dbs {rawfile sim_type {vcdfiles {}}}`, `src/ase.tcl:2866` |
| A shipped path-picker with a 20-deep persisted MRU | the Location bar: `wviewer::rawbar_load {token path}`, `src/wave_viewer.tcl:8392`; MRU `wviewer::rawhist_*`, `:8185-8325`, disk `$USER_CONF_DIR/raw_history` |
| A file chooser filtered on `.raw` | `select_raw {{parent {.}}}`, `src/xschem.tcl:16672` — **the only `.raw` filetype filter in the tree** |
| A persistence slot for the choice | ASE state `viewer.rawfile`, restored by `ase::ui::viewer_restore`, `src/ase_window.tcl:3472-3504` |
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
| Plot signals from **several histories** into one window | **yes** — better than the framing suggests | per-trace `%<rawfile> <sim_type>` suffix via `node_token_split()`; `wviewer::db_suffix`, `src/wave_viewer.tcl:2571` |
| Results Browser **Location field** + last-20-directories drop-down | **yes**, for files not directories | `wviewer::rawbar_load`, `src/wave_viewer.tcl:8392`; MRU `:8185-8325`, cap `::raw_history_max` = 20 |
| `File ▸ Open Results` → *Choose Data Directory* | **partial** — `Browse…` → `select_raw`, a `tk_getOpenFile` on `.raw` **files** | `src/wave_viewer.tcl:8440`; `src/xschem.tcl:16672` |
| Search across **all open databases** (`All DBs`) | **yes** | `wviewer::browser_alldbs`, `src/wave_viewer.tcl:10206`; walker `wviewer::signal_list_all`, `:2430` |
| `Update` vs `Reload` vs `Clear` on a selected result | **absent** as a distinction — every attach path re-reads | `references/viva_cadence_waveform_viewer.md:169` |
| OCEAN `openResults(dir)` + `selectResult('tran)` sets the **current** selection | **partial** — `xschem raw read` / `raw switch` do this, but only from surfaces not framed as a selection (the viewer Location bar `src/wave_viewer.tcl:8413`; the graph dialog `src/xschem.tcl:6927`) plus scripts, and `read` mis-binds (0509) | `src/scheduler.c:10386`, `:10406`; issue **0509** |
| Per-call `?result` / `?resultsDir` override **without** changing the selection | **yes**, per trace — the `%<rawfile>` suffix is exactly this | `references/viva_research_raw.json` research[5].items[53]; `src/draw.c` node walkers |
| `Edit ▸ Component Display ▸ Set Simulation Data Directory` — tell a *schematic* whose results are its | **absent as a UI** — the stamp can be re-pointed only by `xschem set raw_level <n>` or `xschem annotate_op <file> <level>`, neither framed as "whose results are these", and both bounded to a level already on the current stack | re-stamp `src/scheduler.c:12292-12293`, `:2432-2433`; gate `sch_waves_loaded()` `src/draw.c:2825-2840` |
| Results **Display Window** for `Results ▸ Print` | **absent** (Calculator §9's Table, R606, is the nearest planned thing) | `references/viva_research_raw.json` research[5].items[33] |
| A selection survives a session save/restore | **half-built** — the slot is read, resolved, existence-gated and tested; **nothing ever writes it** | read `src/ase_window.tcl:3472-3504`; writer hardcodes `rawfile {}`, `src/wave_viewer.tcl:3995` |

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
one flat `.raw`. `doc/claude/specs/calculator.md:885-895` §13 (the ruling row is `:891`) already rules
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
`wviewer::leave_ctx {token ticket}` (`src/wave_viewer.tcl:1391`, `:1462`).
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
`casemode_reapply` (`src/wave_viewer.tcl:14484`, `:14517`) exist for this and
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

**It is not the only fix, and the alternative already ships.**
`xschem set raw_level <n>` (`src/scheduler.c:12275-12297`) writes *both*
`raw->level` and `raw->schname` from Tcl, bounded to `0 <= n <= xctx->currsch`,
and is already used by `open_sub_schematic` and `hi_descend`'s new-window arm.
A Tcl-only `results::select` could therefore re-bind with
`xschem set raw_level [xschem get currsch]` and ship with **no C change at all**.
R110 is still preferred — it makes the verb correct for every caller rather than
for the one that remembers to follow up — but §17 Q1 may rule otherwise, and a
C-free v1 is a real option.

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
`ase::ui::viewer_restore`'s existing shape (`src/ase_window.tcl:3477-3484`:
absolute-ise → `file isfile` → else `ase::last_rawfile`), which is the model
`results::resolve` copies. The resolver itself is a new **pure** proc in
`src/results.tcl` (R204), and `viewer_restore` is re-expressed on top of it.

**R203** The content half of `stale` is `ase::raw_content_verdict {path}`
(`src/ase.tcl:2794`), which parses the first plot header and refuses a
constants-only or zero-point raw with a full sentence. **It is the only
content check in the tree, and only `ase::attach_dbs` calls it.** Do not
reimplement it.

**R204** The resolver is **pure** — it reads the filesystem and returns a dict.
It never touches the registry. The caller decides whether to act.

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

Return: `1` selected-by-switch, `2` selected-by-read, `0` refused. **Three
values, not two** — this is the distinction R112 says `read` should have had.

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
`wviewer::rawinfo_parse` (`src/wave_viewer.tcl:2380`) and `wviewer::db_label`
(`:2401`). **There must not be a second parser for `xschem raw info`** — issue
**0507**'s ruling. If `raw_is_loaded` survives 0507, it is re-expressed on top of
`results::list`.

**R305** `results::current {}` returns the selected result's dict or `{}`.
**RULED (§17 decisions 3 and 6): the Calculator's Results Dir row consumes it,
and `calc::results_source`'s `self` arm is removed entirely** — the Calculator
reads the ASE-L session's result and nothing else. It answers
R103's three-part definition, so it returns `{}` for a
database that is loaded and current but whose stamp does not resolve (F4) —
**a loaded-but-blind database is not a selection.**

---

## 6. `Results ▸ Select…` — the ASE-L dialog

**R401** A new entry `Select…` in ASE-L's existing Results menu, above
`Direct Plot` (`src/ase_window.tcl:526-535` — the menu has **no** separator
today, so one is added if `Select…` is to be grouped apart). Hand-built plain
Tk `$top.mb.results add command` — ASE-L's menubar is not generated from
`actions.csv` (only the main File menu is, via `build_menu_from_table`,
`src/xschem.tcl:16912`), so **no CSV row is needed**. A key chord would need one,
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
| **Recent** | the MRU, newest first, entries already in the registry visually distinguished from ones that are not | `wviewer::rawhist_get`, `src/wave_viewer.tcl:8224` |
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

---

## 7. The two surfaces that already select

**R501 — the viewer Location bar keeps its behaviour and gains the resolver.**
`wviewer::rawbar_load` (`src/wave_viewer.tcl:8392-8424`) is already correct on
the hard points: `file isfile` guard, `switch_ctx` (a move, not a loan),
additive read with **no** clear (F7), `regenerate`, `browser_refresh`,
`rawhist_push`, `rawbar_sync`, `log_action`, and every refusal returning 0 with
nothing thrown. (Three of its five refusal arms write a one-line sidebar status;
the unknown-token arm and the failed-`switch_ctx` arm return silently — the
re-expression must not quietly change which.) The re-expression must also state
which steps move into `results::select` and which stay in `rawbar_load`:
`capture_live_view_state` and `regenerate` are viewer concerns and stay. It is re-expressed on
`results::select` so the status sentence and the MRU push happen in one place —
**its user-visible behaviour must not change**, and §12 T-C pins that.

**R502 — the Calculator's `Browse` stays disabled. RULED §17 decision 9,
reversing this rule's original text.** Browsing to a result is
`ASE-L ▸ Results ▸ Select`'s job; the Calculator consumes the session's
selection and never makes one. The stub keeps its shape and its reason, and the
spec now says why it is inert rather than promising it will not be.
For the record, the state it is reversing: `.calc.res.path` is
`-state readonly` (`src/calculator.tcl:712`) and `.calc.res.browse` is
`-state disabled` with a command that writes *"Browse: not implemented"*
(`:723-727`, with the reason at `:719-722`). It becomes
`results::select` + `select_raw`. **Browse has no R-number and no plan row in
`doc/claude/calculator_batch/PLAN.md`** — it is named once, at
`doc/claude/specs/calculator.md:201`. This spec is where it acquires one.

**R503 — the Calculator's Results Dir row must report what Evaluate will use.**
Today `calc::results_source` resolves self → viewer → ASE → none and labels
which won (`doc/claude/specs/calculator.md:201`, pinned by
`tests/headless/test_calc_skeleton.tcl` S26). That is a *reporter*. When phase 3
lands, Evaluate runs against **this window's own context**, and the Calculator spec is **silent** on which database Evaluate uses —
R601–R607 (`doc/claude/specs/calculator.md:753-768`) never name one, and its
only "current raw" statements are §5 (`:461`) and R705 (`:786`). That silence is
the gap: the row can name a borrowed path while the computation uses a different
database, or none. **RULED §17 decision 3: the row PICKS.** What it names is what Evaluate reads,
and the `self` arm that could disagree with it is gone (decision 6). Whatever is ruled, the invariant is: *the row names the database
Evaluate will use, or it says it is only reporting.*

**R504 — `Results ▸ Select…` does not appear in the waveform viewer's menubar.**
`tests/headless/test_wave_viewer.tcl:586-587` (G2) asserts the cascade set is
**exactly** `{File View Graph Cursors Options}`, and `src/wave_viewer.tcl:18249`
records the rule. The viewer's selection surface is the Location bar it already
has. Adding a cascade there is a separate decision with a frozen test in front
of it.

**R505 — the Waves menu is GATED, not fixed, not extended. RULED §17.2.**
Under `cadence_compat` its eight loading entries and `Op Annotate` are blocked
with a message naming the setting and pointing at `ASE-L ▸ Results ▸ Select`;
without `cadence_compat` it behaves exactly as it always has. The background: Issue **0508**: `load_raw`
(`src/xschem.tcl:16687`) calls `xschem raw_clear` and then `xschem raw_read`,
which *itself* clears the whole registry — so the eight `waves <type>` entries
(`Load first analysis found`, `Op`, `Dc`, `Ac`, `Tran`, `Noise`, `Sp`,
`Spectrum`) silently discard every other loaded result. `External viewer` and
`Clear` do not route there; `Op Annotate` calls `select_raw` directly. Under this spec those entries route through
`results::select` and stop clearing. If the driver rules the destructive
behaviour is wanted, it must be *said* in the menu and in the verb's comment.

---

## 8. Persistence — the seam that is already built

**R601** The selection persists in the ASE state's `viewer.rawfile`. **Do not
invent a slot.** The read side is complete and covered:

- `ase::ui::viewer_restore` (`src/ase_window.tcl:3472-3504`) gates on
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

**R602** The write side is small but not one line. `wviewer::snapshot
{token prev}` (`src/wave_viewer.tcl:3982-4016`) hardcodes `rawfile {}` at
`:3995`; it writes the selected result's path instead — **relative to `rundir`
when it is under it, absolute otherwise**, because G11 already proves the
relative form round-trips and a relative path is what makes a state file
movable. `snapshot` does not know the rundir, so either it is passed in or the
relativisation happens in `ase::ui::viewer_snapshot`
(`src/ase_window.tcl:3451-3459`), which does. Decide that in the item, not in
the patch.

**R603** `doc/claude/specs/calculator.md:786-787` R705 forbids the *Calculator*
from persisting anything about the current raw ("Reopening the Calculator against
a different simulation must not resurrect stale vector names as if valid").
**R705 binds the Calculator, not the session.** This spec persists the session's
selection, and R705 is satisfied because the Calculator reads it live through
`results::current` (R305) rather than remembering it.

**R604** A restored selection runs through the resolver (§4) exactly as a fresh
one does, and its status is reported once, on restore, through `ase::echo`.
`viewer_restore` already emits a sentence for the no-results case
(`src/ase_window.tcl:3499-3501`); this extends that vocabulary rather than adding
a channel.

**R605** `wviewer::restore`'s inline attach block (`src/wave_viewer.tcl:4074-4081`)
does `catch {xschem raw clear}` and then `xschem raw read`. That is a **clear
before read** (F7) on the restore path, and it is one of the paths §18 names as
bypassing the content check. Bringing it onto `results::select` is in scope;
changing the *order* is a measured behaviour change and needs T-E.

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
(`src/wave_viewer.tcl:10319`); the Calculator → `calc::status`. **Never `puts`,
never the status bar directly** — the house rule.

**R803** The sentences say which database, by `db_label` (file tail + analysis),
not by full path — the full path lives in the balloon. `wviewer::db_label`
(`src/wave_viewer.tcl:2401`) already produces this.

**R804** A selection that lands but cannot resolve (F4 — the stamp does not match
the current hierarchy stack) is **reported as such, in those words**, and is not
silently reported as success. This is the sentence the whole feature exists to
avoid having to guess at:

> `Selected srlatch_ase.raw (dc), but this result was read against srlatch.sch and you are in tb_diff_amp.sch — no signal names will resolve until you return.`

**R805** The four resolver statuses each have exactly one sentence form, and
`stale` says *why* it is stale (content verdict, or older than the netlist).

---

## 11. Landmines

**L1 — `select_raw` does not return `{}` headlessly.** `src/xschem.tcl:16672-16685`
computes a guessed default (`$netlist_dir/<current cell>.raw`) *first*, then
overwrites it with `tk_getOpenFile` **only inside `if {[info exists has_x]}`.
With no `has_x` it returns the guess.** A headless test that expects "cancel →
`{}`" will instead see a plausible path and a real selection. Shim `select_raw`
in tests; never rely on its headless return.

**L2 — two `xschem` verbs, one underscore apart, opposite semantics.**
`xschem raw read` appends; `xschem raw_read` **clears the whole registry** and
then reads (`src/scheduler.c:10776-10793`). Issue **0508**. Write `raw read`.

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
(`src/wave_viewer.tcl:2430`) restores the cursor unconditionally *outside* the
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
0507). Re-grep every one before quoting it.

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
| **T-E** | Restore of a state whose `viewer.rawfile` is **relative** attaches it (extends `test_ase_persist` G11); restore of one whose file was **deleted** falls back and says so (extends G10). |
| **T-F** | `wviewer::snapshot` writes a non-empty `rawfile`, relative when under `rundir`, and a save→restore round-trip re-selects the same result. This is the assertion that would have failed for the whole life of the seam. |
| **T-G** | Selecting result B while a graph carries a `%<rawfileA>` trace suffix leaves that trace resolving against A. Per-trace addressing is not selection. |
| **T-H** | The four resolver statuses each produce their own sentence; `stale` still yields the named path, and `invalid` yields the derived path when one exists on disk and `{}` otherwise — never an error. |
| **T-I** | Cross-context: the Calculator's Results Dir row and `results::current` agree, or the row says it is reporting a borrowed path. (Whichever §17 Q3 rules.) |
| **T-J** | A **refused** borrow ticket is reported as refused, never as "no results". F6. |
| **T-K** | Grep test: no **by-word** parser of `xschem raw info` survives — `raw_is_loaded`'s `foreach {n f t} [lrange … 2 end]` (`src/xschem.tcl:6989`) is gone, and every new consumer is built on `wviewer::rawinfo_parse`. (Four line-wise readers already exist — `rawinfo_parse`, `ase::raw_indices` `src/ase.tcl:2935`, `ase::raw_current` `:2943`, and the test helpers — so "exactly one parser" is not the assertion.) Issue 0507's ruling, pinned. |
| **T-L** | Grep test: no Waves-menu **load** entry reaches `xschem raw_clear` or the registry-clearing `xschem raw_read`; the `Clear` entry (`src/xschem.tcl:17131`) is the sole permitted caller. Issue 0508, pinned. |
| **T-M** | A selection whose stamp does not match the current hierarchy stack is **not** reported as success (R804) — sabotage: make `results::select` return ok unconditionally, T-M goes red. |

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
`set_ne cadence_compat 0` (`src/xschem.tcl:18236`), a menu checkbutton
(`:16974`), read from C via `tclgetboolvar("cadence_compat")`
(`src/callback.c:633`), and it already carries a write-trace that force-enables a
bundled setting (`cadence_compat_sync` → `autotrim_wires`, `:18773-18778`).

**This closes the wrong-cell case for Cadence-mode users.** F4's blind-database
scenario is reachable only through the legacy doors; with eight of the nine
blocked and only `autoload=` graph rects left (decision 10), a `cadence_compat`
user cannot get there through a menu.

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
(`src/wave_viewer.tcl:4074-4081`) comes **onto** `results::select` under R605.
What is deferred there is only its clear-then-read *order*, which is a measured
behaviour change needing T-E.

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
