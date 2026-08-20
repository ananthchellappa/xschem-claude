# Results batch — crew brief

Read this **first**, before the item scope. It carries the landmines the spec
measured and the decisions you are not allowed to re-open. It is in every item's
`load` list on purpose.

Companion state: `PLAN.md` (**§1 is the authoritative item list**, §2 the
re-grepped pointers, §4 the item briefs), `DECISIONS.md` (the ten user rulings
and the two driver rulings), `LEDGER.md` (batch state and the baseline).
Authority for everything technical: `doc/claude/specs/results_selection.md`.

---

## 1. Base, baseline, and how an audit is judged

- Base HEAD **`226302f9`**, branch `fluid-editing`. **Nothing is pushed and
  nothing may be pushed.**
- Baseline audit: `doc/claude/results_batch/baseline_2026-08-19_226302f9.txt`,
  shot at that HEAD on the dev display. **`LEDGER.md` carries its counts** —
  read them there, not from memory.
- **Judge every audit by DIFFING that file by test NAME and STATUS, never by the
  red count.** `full_audit.sh` is never clean and *"the audit is red"* is not a
  finding. A test going red that is **not** red in the baseline outranks
  everything else in the item.
- **`doc/claude/batch_F/baseline_status.txt` (285/19/1) is VOID** — shot with the
  pre-rework scorer. Do not diff against it, cite it, or average it in.
- When you count the baseline yourself: lines reading `FAIL     | key ...` are
  **within-file detail, not test rows**. A naive `grep -c '^FAIL'` over-counts.

## 2. What you may not do

- **Do not re-open anything in `DECISIONS.md`.** Ten rulings taken with the user
  2026-08-18, one question at a time, plus two driver rulings. If one looks
  wrong, say so in your return value with evidence — do not quietly choose
  differently.
- **Do not build a database manager.** Most of the engine already exists: a
  per-window-and-per-tab registry (`xctx->extra_raw_arr[]`/`extra_idx`,
  `src/xschem.h:2036-2043`), `raw switch`/`switch_back`, a content check, a
  `.raw` picker, a 20-deep persisted MRU, and per-trace cross-database
  addressing. **No new C data structure, no second registry, no "results list"
  in `Xschem_ctx`** (R113). The selection is `extra_idx` and nothing else.
- **Do not introduce a per-run result directory** and do not start the read-side
  migration of the ~293 `raw_read $netlist_dir/<cell>.raw` launcher sites
  (driver ruling D-B).
- **Do not relax `sch_waves_loaded()`** (`src/draw.c:2825`). 52 call sites across
  seven files; that is its own change with its own audit.
- **Do not model `Select` on `ase::attach_dbs`.** That is the *run* path and its
  purge is deliberate (L8).
- **Do not add a cascade to the waveform viewer's menubar** (R504, D12) —
  `tests/headless/test_wave_viewer.tcl:586-587` (G2) freezes the cascade set.

## 3. Environment

- Dev display **`:99`** (1920x1080x24, openbox). `full_audit.sh` and
  `run_suites.sh` self-arm to it; a bare `./src/xschem --script` does **not** —
  route it as `tests/headless/devdisplay.sh exec ./src/xschem …`. Never a bare
  `for … do ./src/xschem … done` loop: it enrols in no gate, the user cannot
  pause it, and the panel lists it as `UNGATED`.
- The GUI gate control dir `~/.claude/gui_test_gate/` is already armed. Do not
  relaunch, kill, re-arm, or write into it.
- **Never run `make` in the xschem tree while suites are running** — CPU load
  makes the headless suites flake, and four repeat failures are not determinism.
- **Never run `full_audit.sh` with DISPLAY stripped** (`env -u DISPLAY`): the GUI
  guards themselves throw `invalid command name "winfo"` and you get ~62 bogus
  CRASHes.
- `full_audit.sh` globs `test_*.tcl` only — **no `.sh` suite is scored by it.**
  If your item touches one, run it by hand and say so in the receipt.
- **A HAND-WRITTEN DRIVE IS NOT EXEMPT FROM THE TEST FILE'S SHIMS.** Added in the
  item-4 fixer round, because an ad-hoc verification drive of `results::select`
  set `::update_recent_files` and did **not** shim `wviewer::rawhist_write` — so
  the real writer ran and **truncated the user's `~/.xschem/raw_history`** to one
  scratchpad path. That is issue 0119's exact class, and unlike `recent_files`
  there is no `.bak`: the user's list was unrecoverable and the file has been
  left holding an empty list. So: **any drive — suite or scratch script — that
  sets `::update_recent_files` must first `rename wviewer::rawhist_write` to a
  no-op and must save and restore `::wviewer::rawhist`**, exactly as
  `test_results_select.tcl`'s group AJ does. The same rule holds for anything
  else that writes under `$::USER_CONF_DIR`: repoint `$::USER_CONF_DIR` at
  `test_scratch`, or shim the writer. "No droppings in `$HOME`" is a claim that
  must be **checked** (`ls -la ~/.xschem`), never assumed from a green suite.

## 4. Landmines — measured while writing the spec, do not rediscover

- **L1 — `select_raw` does NOT return `{}` headlessly.** `src/xschem.tcl:16672-16685`
  computes a guessed default (`$netlist_dir/<cell>.raw`) *first*, then overwrites
  it with `tk_getOpenFile` **only inside `if {[info exists has_x]}`**. With no
  `has_x` it returns the guess. A headless test expecting "cancel → `{}`" will
  see a plausible path and a real selection. **Shim `select_raw` in tests**;
  never rely on its headless return.
- **L2 — two verbs one underscore apart, opposite semantics.** `xschem raw read`
  appends; `xschem raw_read` **clears the whole registry** then reads
  (`src/scheduler.c:10776-10793`). **Write `raw read`.**
- **L3 — until item 1 lands, `raw read` of an already-loaded file returns
  success without re-binding.** Before item 1, `results::select` must detect it
  (registry size unchanged) and either re-stamp with `xschem set raw_level` or
  refuse honestly. It must **not** clear-then-read — R301(3), F7 and T-D forbid
  it.
- **L4 — the shared scratch column.** `raw->values[raw->nvars]` is ONE buffer
  overwritten by the next evaluation. Re-evaluate immediately before reading.
  Switching results between an evaluation and its read is that bug in a new hat.
- **L5 — a cached `SPICE_DATA *` belongs to one `Raw`.** `raw_add_vector()`
  reallocs, and a selection change reassigns `xctx->raw` without freeing
  (`src/save.c:1977-2015`), so a stale pointer does not crash — it silently reads
  the *other* database. **No cached `SPICE_DATA *` may survive a selection
  change.**
- **L6 — a `<NULL>` `sim_type` makes a slot unreachable BY NAME.** Both
  name-lookup loops in `extra_rawfile()` require a non-NULL `sim_type`
  (`src/save.c:1934`, `:1985`); switching by **index** still reaches it.
  `results::select` must never pass an empty type through as NULL when the caller
  had one. Pinned by `tests/headless/test_raw_read_dispatch.tcl`.
- **L7 — no `update`, no `after`, while the current-DB pointer is swapped.** A
  redraw during a walk draws the wrong waveforms. `signal_list_all`
  (`src/wave_viewer.tcl:2430`) restores the cursor unconditionally *outside* the
  loop's catch — copy that shape.
- **L8 — `ase::attach_dbs` purges more than it looks like**: targeted clear of
  the incoming path (`src/ase.tcl:2903`), read (`:2904-2908`), then **wipes every
  other slot highest-index-first** (`:2912-2919`), reads the VCDs, and switches
  to slot 0 only `if {[llength $got]}` (`:2928`).
- **L9 — in-source citations in `wave_viewer.tcl`, `calculator.tcl` and
  `ase.tcl` are systematically STALE.** The `rawinfo_parse` comment alone is
  wrong twice (issue 0507). **Re-grep every citation before quoting it**, and
  re-grep any line number not in `PLAN.md` §2.
- **L10 — `xschem raw switch <path>` with no type finds nothing.** The
  switch-by-name arm is guarded `if(file && type)` (`src/save.c:1978`); with no
  type it falls through to the by-index form. Always pass the type, or pass the
  index from `results::list`.
- **L11 — the MRU is gated off in automation.** `wviewer::rawhist_push` no-ops
  unless `::update_recent_files` is set (issue 0119). A test asserting an MRU
  delta must **set and restore** it, and a scripted selection legitimately leaves
  no trace in the history.

## 5. The architectural facts a change here must respect

- **F4 is the load-bearing one.** A database is bound to the schematic that was
  current **when it was read** (`raw->schname`/`raw->level`, stamped by four
  readers, gated by `sch_waves_loaded()`). Navigate to another cell and
  `raw info` still lists it while `raw index` returns **-1**. **A loaded-but-blind
  database is not a selection** (R305), and R804's sentence is how the user is
  told so.
- **F7 — selection never clears.** Accumulating databases is the declared cost.
- **Tabs do NOT share a registry** — each tab is its own `Xschem_ctx`
  (`src/xinit.c:1938`, `:2204`, `:2209`). Measured.
- **`xschem set raw_level <n>` already re-stamps BOTH `raw->level` and
  `raw->schname` from Tcl** (`src/scheduler.c:12275-12297`, bounded
  `0 <= n <= currsch`). This is why a C-free v1 was possible; driver ruling D-A
  rejected it, but the verb is still the right tool inside a Tcl fallback path.

## 6. Test discipline

- **Anti-vacuity:** existence + class + `cget` is **not** proof a control is
  mapped — assert `winfo manager` / `winfo ismapped` / slave order. And a rule
  proved only by reading the source is proved by **moving** the source, not by
  re-reading it.
- Measure the first free check-id band by grepping `tests/headless/*.tcl` for the
  highest id **actually in use**. A band quoted in a doc is not evidence, and
  doc-quoted bands in this repo have been wrong twice.
- Run new checks **before** the code works. A check that passes before the
  feature exists is vacuous.
- **`-q` on the xschem command line is `--quit`, not `--quiet`.**
- A `--script` file must end in an explicit `exit 0` or the process idles
  forever.
- **Never print `RESULT: SKIP`, `skipped: no X` or `SKIP: no X connection` from a
  per-group skip** — `full_audit.sh` scores the WHOLE FILE as SKIP on that
  substring and silently discards every check that ran in it.
- Use `test_scratch` (`tests/headless/scratch.tcl`); leave no droppings in the
  repo. A helper file must **not** be named `test_*.tcl` — `full_audit.sh` globs
  those and scores a zero-check file FAIL forever.
- Known WSLg flakes that are **not** regressions: `test_ase_plot` P4/P6/P8
  (1-2 in 10), TG9 root-coords (4 in 10 on a pristine tree), bare
  `event generate` key delivery (~1 in 5). Re-run before calling any of them a
  fail.

## 7. Issue numbering — READ THIS BEFORE FILING ONE

**New issues on `fluid-editing` take the next free number at or above 0500.**
Highest in use is **0514** (item 4 filed it). Derive it, never guess:

```sh
ls doc/claude/issues/ | grep -E '^0[0-9]{3}-' | cut -c1-4 | sort -n | tail -1
```

The 04xx tail belongs to the live `annotate` branch (filed through 0448 and
counting); 0449-0499 is its headroom, not a pool to draw from. Full rule at the
top of `doc/claude/issues/status.md`.

## 8. The issues this batch closes

| issue | closed by | what it is |
|---|---|---|
| **0509** | item 1 | `raw read` of an already-loaded file reports success but leaves it bound to the old cell — the dedupe arm is written **twice** (`save.c:1916-1921` and `:1968-1975`) and neither re-stamps |
| **0508** | item 8 | the Waves-menu chooser discards the whole registry; zero functional coverage |
| **0507** | item 9 | `raw_is_loaded` parses `xschem raw info` by WORD and has zero callers |
| **0216** (shape) | item 4 | `attach_raw` never pushes to `raw_history`, so the one durable list omits the results the user actually produced |
