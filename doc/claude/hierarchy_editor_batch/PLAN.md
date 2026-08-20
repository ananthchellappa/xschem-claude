# Hierarchy Editor — work breakdown

Driver-orchestration batch plan for `doc/claude/specs/hierarchy_editor.md`.
**Read the spec first.** Every item below cites spec section numbers (§) and
decision ids (D1–D13); the plan does not repeat the spec's reasoning.

- **Spec:** `doc/claude/specs/hierarchy_editor.md`
- **Batch dir:** `doc/claude/hierarchy_editor_batch/`
- **Ledger:** `doc/claude/hierarchy_editor_batch/LEDGER.md` (created by item 0.1)
- **Receipts:** `receipts/NN-<slug>.md`, 120 lines max
- **Pipeline:** copy `doc/claude/calculator_batch/item_pipeline.js`, retarget the
  four path constants at its head (item 0.1)

Verdicts: `[x]` done+verified · `[E]` done, eyeball pending · `[D]` deferred
(file an issue) · `[F]` failed (file an issue).

---

## How to run this

```
Workflow({ scriptPath: 'doc/claude/hierarchy_editor_batch/item_pipeline.js',
           args: { n: <item>, slug: '<kebab>', title: '...', brief: '...',
                   load: [<files to read first>], hints: '...' } })
```

State lives in `LEDGER.md`, not in the driver's context. After a compaction,
re-read the ledger and resume at the first row that is not `[x]`/`[E]`/`[D]`/`[F]`.

**Display:** dev display `:99` (`tests/headless/devdisplay.sh start`), never `:0`.
GUI items that produce pixels record a **look debt**
(`tests/headless/owed.sh add look hed-<what>`) and are marked `[E]`, never `[x]`.

**Per item, always:** build → run the item's named suites **plus T-A** → sabotage
the new code and prove red → un-sabotage → commit → write the receipt → tick the
ledger. Never push.

---

## Adaptation protocol — how to change this plan

The plan is partitioned so a reversed decision touches one phase, not the batch.

1. A decision changes → write it into the **ledger's rulings table** first
   (id, ruling, who, date, which D it amends).
2. Amend **spec §8** (the decision table) and the spec section that the decision
   governs. The spec is the source of truth; the plan cites it.
3. Look up the D in the **partition map** below. Only the phases listed there
   are affected.
4. For each affected item already `[x]`/`[E]`: change its ledger verdict to
   `[R]` (redo) and append a one-line reason. Items not listed are untouched —
   **do not re-verify them, and do not re-run their suites as "just in case"**;
   the T-A invariant is what protects the rest.
5. Re-run the affected items through the same pipeline. Receipts get a `-r2`
   suffix, they do not overwrite.

**The GUI is the phase most likely to move.** That is why P4 (GUI) reads all its
data through exactly one command — `xschem config expand` (spec §5) — and holds
zero resolution logic. A GUI redesign is P4-only. Conversely, if the *resolver*
changes, P4 does not move at all, because it never reimplemented any of it.

---

## Partition map: decision → phases at risk

| decision | governs | phases that must be redone if reversed |
|---|---|---|
| D1 attribute rank — **RULED 2026-08-18** | §3.2, §3.8 | P2 (2.4, 2.8), P5 (5.2, 5.8) |
| D2 stop list shape — **RULED 2026-08-18** | §3.4 | P1 (format), P2, P4 (band 3) |
| D3 mangling scheme | §3.7 | P5 |
| D4 expander in C vs Tcl | §6 | P3, and P4's data source |
| D5 file format | §2.2 | P1 only |
| D6 occurrence path syntax | §2.3 | P1, P2, P4 display, all fixtures |
| D7 auto-update | §4.5 | P4 (one item) |
| D8 launcher — **RULED 2026-08-18** | §2.1, §4.6 | P1 (1.9), P4 (4.2, 4.15) |
| D9 fate of `traversal` | §4.6 | P8 (one item) |
| D10 config scope per-xctx | §5 | P2 (one item) |
| D11 nested configs | §3, §6 | P2, P3 |
| D12 toplevel vs LibMgr tab | §4.1 | all of P4 |
| D13 ASE carries a config | §5 C4 | P7 only |
| D14 view name / extension — **RULED 2026-08-18** | §2.1 | P1 (1.1) only, *provided* T-P stays green |
| D15 several HED windows | §4.7 | P4 (4.1, 4.17); amends D12 |
| D16 the Locate key | §4.9 | P4 (4.19) — one `actions.csv` row |
| D17 `View ▸` cascade vs flat | §4.10 | P4 (4.20) |

---

## Phase map

| phase | what | items | gate before next phase |
|---|---|---|---|
| **P0** | recon, baseline, harness | 0.1–0.3 | baseline recorded, pipeline runs |
| **P1** | the config object: view type, format, load/save | 1.1–1.9 | `xschem config load/save` round-trips (T-B) |
| **P2** | the resolver in C | 2.1–2.10 | precedence + inheritance green (T-C, T-D), **T-A still byte-identical** |
| **P3** | the expander | 3.1–3.6 | `xschem config expand` returns a whole tree (T-G) |
| **P4** | the GUI + the schematic↔HED link | 4.1–4.20 | window usable end to end; look debts recorded |
| **P5** | netlist integration | 5.1–5.8 | occurrence divergence netlists correctly (T-F) |
| **P6** | import / export / validate / diff | 6.1–6.6 | T-H, T-J green |
| **P7** | ASE-L, Library Manager, print | 7.1–7.5 | a sim runs under a config (T-K) |
| **P8** | docs, audit, close | 8.1–8.5 | full audit diffed against baseline |

**Ship order rationale:** P1→P2→P3 is a strict dependency chain (object →
resolver → expander) and none of it is visible to the user, so all three can run
unattended with pure headless verification. P4 needs P3's one command and
nothing else. P5 is independent of P4 and can be interleaved. That ordering is
what makes a GUI rethink cheap: at the P3/P4 boundary, everything below the GUI
is already proven.

---

## Ledger rows (copy into LEDGER.md)

| # | item | phase | owns | verdict |
|---|---|---|---|---|
| 0.1 | batch scaffolding: ledger, pipeline, receipts dir | P0 | — | |
| 0.2 | baseline: audit + netlist goldens for T-A | P0 | — | |
| 0.3 | fixture library `tests/headless/fixtures/hedlib/` | P0 | D6 | |
| 1.1 | `config` row in the four view-type procs | P1 | D14 **ruled** | |
| 1.2 | `lib_qualified_abs` must not divert `.cfg` to symbol | P1 | — | |
| 1.3 | `library_new_view` seeds a valid empty config | P1 | D5 | |
| 1.4 | config file format: writer | P1 | D5 | |
| 1.5 | config file format: parser + version refusal | P1 | D5 | |
| 1.6 | unknown-key preservation on round-trip | P1 | D5 | |
| 1.7 | occurrence-path helpers (build, parse, ancestors) | P1 | D6 | |
| 1.8 | `xschem config load/save/unload/get` | P1 | D10 | |
| 1.9 | LibMgr *New view…* launches the new view's tool (all types) | P1 | D8 **ruled** | |
| 2.1 | per-`xctx` active-config storage + teardown | P2 | D10 | |
| 2.2 | `xschem config global/cell/inst` accessors (dotted keys) | P2 | D2 **ruled** | |
| 2.3 | effective-list walk (inheritance) | P2 | — | |
| 2.4 | precedence ranks 2/3 + the `cadence_compat` cutout | P2 | D1 **ruled** | |
| 2.5 | the view-list walk, rank 5 | P2 | — | |
| 2.6 | stop-list evaluation, one list all formats | P2 | D2 **ruled** | |
| 2.7 | library binding / liblist | P2 | — | |
| 2.8 | `get_sch_from_sym()` calls the resolver (descend, C1) | P2 | D1 | |
| 2.9 | `xschem config resolve` + provenance | P2 | — | |
| 2.10 | mirror notify: dirty flag + one flush per event | P2 | — | |
| 3.1 | `.sch` instance scanner (no editor descend) | P3 | D4 | |
| 3.2 | file+mtime cache | P3 | D4 | |
| 3.3 | recursion guard + depth cap | P3 | — | |
| 3.4 | vector-instance lazy expansion | P3 | D6 | |
| 3.5 | nested-config handling, one level | P3 | D11 | |
| 3.6 | `xschem config expand` command | P3 | D4 | |
| 4.1 | `.hed` toplevel skeleton, six bands | P4 | D12 | |
| 4.2 | band 2: config + top-cell selectors, pre-filled | P4 | D8 **ruled** | |
| 4.3 | band 3: global bindings, collapsible (one Stop List field) | P4 | D2 **ruled** | |
| 4.4 | band 4: tree treeview + columns | P4 | — | |
| 4.5 | band 4: populate from `config expand` | P4 | D4 | |
| 4.6 | row tags: bound/inherited/stopped/unresolved/generator | P4 | — | |
| 4.7 | View-To-Use combobox editing | P4 | — | |
| 4.8 | Table tab (unique-cell view) | P4 | — | |
| 4.9 | band 5: cell-bindings table | P4 | — | |
| 4.10 | band 5: instance-bindings table | P4 | D6 | |
| 4.11 | right-click Bindings menu, retargeted | P4 | — | |
| 4.12 | Update + dirty/stale state | P4 | D7 | |
| 4.13 | File menu: new/open/save/save-as/close | P4 | — | |
| 4.14 | View menu: filters, expand/collapse, provenance | P4 | — | |
| 4.15 | launch points, no accelerator, Tools-menu pre-fill | P4 | D8 **ruled**, D12 | |
| 4.16 | status bar + window-activation logging | P4 | — | |
| 4.17 | schematic-window ↔ HED binding registry | P4 | D15 | |
| 4.18 | live mirror consumer: Tree follows the schematic, one way | P4 | D6 | |
| 4.19 | Locate: `Ctrl+Shift+L` → Table row focus | P4 | D16 | |
| 4.20 | schematic context menu `View ▸` → occurrence binding | P4 | D17 | |
| 5.1 | binding materialisation pre-pass (design) | P5 | D3 | |
| 5.2 | `get_additional_symbols()` consumes the pre-pass | P5 | D3 | |
| 5.3 | subckt name mangling + collision detection | P5 | D3 | |
| 5.4 | spice + spectre backends under a config | P5 | — | |
| 5.5 | verilog + vhdl + tedax backends under a config | P5 | — | |
| 5.6 | stop list OR `*_stop`, all five formats | P5 | D2 **ruled** | |
| 5.7 | T-A regression sweep across all five backends | P5 | — | |
| 5.8 | ignored-attribute warning to log + CIW | P5 | D1 **ruled** | |
| 6.1 | `xschem config import` | P6 | — | |
| 6.2 | `xschem config export` | P6 | — | |
| 6.3 | Bindings menu wiring for import/export | P6 | — | |
| 6.4 | `Tools → Validate Config`, five categories | P6 | — | |
| 6.5 | `Tools → Diff Against Config…` | P6 | — | |
| 6.6 | Promote Instance→Cell | P6 | — | |
| 7.1 | `hier_psprint()` under a config (C3) | P7 | — | |
| 7.2 | ASE state gains an optional `config` field | P7 | D13 | |
| 7.3 | ASE netlist activates/deactivates the config | P7 | D13 | |
| 7.4 | LibMgr opens a `config` view in the HED | P7 | — | |
| 7.5 | two windows, two configs, one session (T-K) | P7 | D10 | |
| 8.1 | user documentation | P8 | — | |
| 8.2 | `doc/claude/code_analysis/` explainer | P8 | — | |
| 8.3 | actions.csv rows + command palette | P8 | — | |
| 8.4 | decide the fate of `traversal` | P8 | D9 | |
| 8.5 | full audit diffed against the P0 baseline; close | P8 | — | |

---

# Item detail

Format per item: **Do** · **Files** · **Verify** · **Blast** (what breaks
elsewhere if this is wrong).

---

## P0 — recon, baseline, harness

### 0.1 Batch scaffolding
- **Do:** create `LEDGER.md` from the row table above, with a rulings table and
  an audit-policy section. Copy `doc/claude/calculator_batch/item_pipeline.js`
  to this batch dir; change `BATCHDIR`, `LEDGER`, `BASELINE`, and the meta
  `name`/`description`. Nothing else in the pipeline changes.
- **Files:** `doc/claude/hierarchy_editor_batch/{LEDGER.md,item_pipeline.js}`
- **Verify:** run the pipeline on a no-op item; it writes a receipt and returns.
- **Blast:** none.

### 0.2 Baseline for T-A
- **Do:** record the current `full_audit.sh` verdict set. Separately, generate
  and store the netlist output of **every** `tests/` design in all five formats,
  as the T-A golden set. This is the invariant the whole batch is judged by:
  **with no config loaded, netlists must stay byte-identical.**
- **Files:** `receipts/00-baseline.md`, `receipts/00-netlist-goldens/`
- **Verify:** re-run the generator twice; diffs empty (proves the goldens are
  deterministic before anything is changed — timestamps, paths, pids).
- **Blast:** a non-deterministic golden makes T-A useless for the whole batch.
  If any format embeds a pid or a date (`spice_netlist.c` writes `getpid()` into
  split filenames), filter it in the generator and say so in the receipt.

### 0.3 Fixture library
- **Do:** build `tests/headless/fixtures/hedlib/` per spec §9: a 4-level design;
  cells with `schematic`+`veriloga`, `schematic`+`verilog`, `schematic`+`spice`;
  one recursive cell; one vector-instance cell (`x[3:0]`); one cell name present
  in two libraries; one cell whose `.sym` carries `schematic=`; one instance
  carrying `schematic=`.
- **Files:** `tests/headless/fixtures/hedlib/**`
- **Verify:** `xschem --nogui` loads the top cell, netlists it, descends every
  level. Record the fixture's own netlist into the T-A golden set.
  Add, for the **D1** ruling: a cell whose `.sym` carries `default_schematic=ignore`,
  and one carrying each of `spice_sym_def` / `verilog_sym_def` / `vhdl_sym_def`
  (copy the shapes from `xschem_library/inst_sch_select/inst_sch_select.sch`,
  which is the canonical example of all of this in one file).
- **Blast:** every P2–P7 test stands on this. Under-building it here costs a
  redo of half the batch. **D6** (path syntax) is first exercised here, and
  **T-M/T-N** (the `cadence_compat` cutout) cannot be written without the
  `*_sym_def` and `default_schematic=ignore` cells.

---

## P1 — the config object

### 1.1 `config` row in the view-type table
- **Do:** one row each in `view_type_of_ext` (`.cfg` → `config`),
  `view_exts_of_type` (`config` → `{.cfg}`), `view_type_opener` (`config` →
  `hed`). `view_default_name` needs nothing (name == type).
  **D14, ruled:** these four procs are the *only* place the strings `config` and
  `.cfg` may appear. Everything downstream in this batch asks the table. Write
  that rule as a comment on the rows, the way the `text` type's rationale is
  written at `src/library_defs.tcl:205-230`.
- **Files:** `src/library_defs.tcl:232-290`
- **Verify:** `test_hed_viewtype.tcl` — the four procs agree; `cell_views` lists
  a hand-made `config` dir; the existing `test_text_view_type` stays green.
  Add **T-P**, the grep test: no file outside those four procs contains the
  literal view name or extension. T-P runs on **every** item thereafter, not just
  this one — it is the thing that keeps D14 a two-row edit instead of a sweep.
- **Blast:** `view_type_opener` returning `hed` before the HED exists must not
  error — until 4.13 lands it reports "not implemented" on the status bar.
  Follow the `text_view_type.md` precedent exactly.

### 1.2 `lib_qualified_abs` must not divert `.cfg` to symbol
- **Do:** add a `config` arm beside `verilog`/`veriloga`/`text`
  (`src/library_defs.tcl:391-400`). Without it, `mylib/top.cfg` silently
  resolves to the **symbol** view — the exact class of bug the header comment at
  `:386` documents for `.v`.
- **Files:** `src/library_defs.tcl`
- **Verify:** `lib_qualified_abs mylib/top.cfg` returns the config path.
- **Blast:** silent wrong-file resolution; the worst failure mode in this file.

### 1.3 `library_new_view` seeds a valid empty config
- **Do:** a `config` arm in the `switch` at `src/library_defs.tcl:1036` writing
  a minimal valid file (magic + version + `topcell` pointing at the cell's
  schematic view). **Never a zero-byte file** — the loader must not need an
  empty-file special case (the `state` arm's comment makes the same argument).
- **Files:** `src/library_defs.tcl`
- **Verify:** New View → config from the Library Manager; item 1.5's parser
  loads the result without error.
- **Blast:** every "create a config" path in the GUI.

### 1.4 Format writer
- **Do:** implement spec §2.2 emission: magic, version, `topcell`,
  `description`, `global` lines, `cell` lines, `inst` lines. Sorted output for
  stable diffs. Tcl-quote every value.
- **Files:** new `src/config_view.c` (add to `src/Makefile` `OBJ` **and** an
  explicit compile rule — `Makefile.in` is the source, `./configure` regenerates)
- **Verify:** `test_hed_format.tcl` writes a config with every record kind and
  diffs against a committed expected file.
- **Blast:** D5. If the format changes, only 1.4–1.6 move.

### 1.5 Format parser + version refusal
- **Do:** parse into an in-memory dict. A version the binary does not know →
  **refuse with a named error**, never a partial load. Malformed line → refuse,
  naming the line number.
- **Files:** `src/config_view.c`
- **Verify:** round-trip (T-B); a v2 file on a v1 binary errors and loads
  nothing; a truncated file errors.
- **Blast:** a partial load is worse than no load — it silently changes what a
  netlist means.

### 1.6 Unknown-key preservation
- **Do:** keys the parser does not recognise are kept verbatim and re-emitted on
  save, in their original relative order.
- **Files:** `src/config_view.c`
- **Verify:** T-B with an injected `global futurekey {x}` and
  `cell mylib a futurekey {y}`; byte-identical round-trip.
- **Blast:** without this, an older xschem silently deletes a newer xschem's
  bindings on any save. This is a data-loss item, not a nicety.

### 1.7 Occurrence-path helpers
- **Do:** build a path from `xctx->sch_path[]` + an instname; split a path;
  enumerate ancestors nearest-first; normalise (collapse `//`, strip trailing
  `/`). Vector element form `x[3]` per spec §2.3.
- **Files:** `src/config_view.c`, decl in `src/xschem.h`
- **Verify:** unit-style Tcl test over ~20 path cases including the vector and
  the root.
- **Blast:** **D6**. Every binding lookup and every GUI row id uses these.

### 1.8 `xschem config load|save|unload|get`
- **Do:** four subcommands in the `c` letter bucket of `scheduler.c`
  (`doc/claude/specs/` scheduler-letter-dispatch convention). `get` exposes
  `path`, `topcell`, `description`, `dirty`.
- **Files:** `src/scheduler.c`
- **Verify:** `test_hed_cmd.tcl` — load a fixture config, `get` each field,
  save to a temp path, diff.
- **Blast:** the only surface the GUI and the tests use.

### 1.9 *New view…* launches the new view's tool
- **Do:** `libmgr::do_new_view` (`src/library_manager.tcl:1241`) currently
  creates, refreshes, selects and logs — and leaves the user looking at a list
  row. Make it **open the view it just created**, routed through
  `libmgr::view_handler` / `view_type_opener`, so `schematic`→schematic editor,
  `symbol`→symbol editor, `verilog`/`veriloga`/`text`→text editor,
  `state`→ASE-L, `config`→the HED. **One call, not a `switch` on type** — a
  sixth private copy of the view-type table is exactly what
  `doc/claude/specs/text_view_type.md` exists to prevent.
  The `config` arm is a stub until 4.1 lands; it reports "Hierarchy Editor not
  built yet" on the status bar and does not error.
- **Files:** `src/library_manager.tcl`
- **Verify:** **T-Q** — one case per view type, asserting *which* handler ran
  (not that a window appeared). Plus the replay case: `xschem log_action`
  already records `do_new_view`; a **replay must create the view and spawn
  nothing** — the rule `libmgr::open_text_view` follows at `:459`, for the same
  reason (a replay must not fork gvim). Existing `test_action_log_libmgr` must
  stay green.
- **Blast:** **this changes behaviour for view types that already ship**, not
  only for `config`. It was asked for explicitly, but it is the one item in P1
  a user could notice without touching the new feature — so it gets its own
  commit and its own test rather than riding along on 1.1. If the auto-open
  turns out to be unwanted for some type, the table is where it is switched off.

---

## P2 — the resolver

### 2.1 Per-`xctx` active config
- **Do:** add the parsed config + its path to `Xschem_ctx`, freed in the context
  teardown, copied/not-copied per `get_save_xctx()`/`get_old_xctx()` policy.
  Not on the undo stack (a config is not design data).
- **Files:** `src/xschem.h`, `src/xinit.c`, `src/config_view.c`
- **Verify:** open two tabs, load a config in one, `config get path` differs;
  close the tab, run under valgrind/`-d 3` for the leak.
- **Blast:** **D10**. Getting this wrong leaks per tab and cross-contaminates
  netlists between windows — the failure would look like a netlister bug.

### 2.2 `global|cell|inst` accessors
- **Do:** get/set for every key in spec §2.2. Setting marks the config dirty.
- **Files:** `src/scheduler.c`, `src/config_view.c`
- **Verify:** set each key, `get` it back, save, reload, compare.
- **Blast:** **D2, ruled: one list ships.** Take a **dotted key** in the
  accessor regardless (`stoplist`, syntactically `stoplist.<fmt>`) and let the
  parser's unknown-key preservation (1.6) carry anything else. Insurance, not a
  feature — v1 documents and shows exactly one list.

### 2.3 Effective-list walk (inheritance)
- **Do:** given an occurrence path and a list name, walk ancestors nearest-first
  for an `inst` override, then the cell binding for the cell at that node, then
  `global`. Return the list **and** which node supplied it (for provenance).
- **Files:** `src/config_view.c`
- **Verify:** T-D.
- **Blast:** used by both the view walk and the stop list.

### 2.4 Precedence ranks 2 and 3, and the `cadence_compat` cutout
- **Do:** occurrence `view`, then cell `view`. Then implement **D1 as ruled**
  (spec §3.8): read `cadence_compat` once per resolution pass; when set, rank 4
  (instance/symbol `schematic=`) **does not exist** — the resolver never consults
  it. When unset, rank 4 is today's behaviour verbatim.
  `default_schematic=ignore` and the four `*_sym_def` attributes are **not**
  view selections and are untouched by this gate — they must keep firing in both
  modes.
  Record each ignored attribute in a per-pass list for item 5.8 to report; the
  resolver collects, it does not print.
- **Files:** `src/config_view.c`
- **Verify:** T-C, one test per rank, each proving the rank *below* it was
  suppressed (a test that only proves the *right* answer cannot tell rank 2 from
  rank 3). Then **T-M** both ways and **T-N**.
- **Blast:** **D1, ruled.** Two traps: (a) reading `cadence_compat` per instance
  instead of per pass makes a mid-netlist Tcl change split a netlist across two
  modes — read once, pass it down; (b) gating too widely and swallowing
  `*_sym_def` silently turns a PEX body back into an ideal one, which is the
  exact defect the warning exists to prevent. T-N is the guard.

### 2.5 The view-list walk (rank 5)
- **Do:** for each name in the effective view list, ask whether the cell has
  that view (`cell_views` for lib/cell layout; extension probing for the legacy
  flat layout). First hit wins.
- **Files:** `src/config_view.c`
- **Verify:** a cell with `veriloga` + `schematic` resolves per list order;
  reordering the list flips the answer.
- **Blast:** the legacy flat layout must still work — a design with no libraries
  registered must behave exactly as today (T-A).

### 2.6 Stop-list evaluation
- **Do:** after a view is chosen, test it against the effective stop list; set
  `stopped`. **One list, all five formats** (D2 as ruled) — the resolver takes no
  format argument for this purpose.
- **Files:** `src/config_view.c`
- **Verify:** T-E, including that the same list stops in all five formats.
- **Blast:** **D2, ruled.** The temptation is to thread a format through the
  resolver "since the netlisters have one anyway" — don't. A format-blind
  resolver is what lets the expander (P3) and the GUI (P4) show a single truthful
  tree; a format-aware one would need five trees.

### 2.7 Library binding / liblist
- **Do:** `lib` on a binding redirects the library; `global liblist` reorders
  the search. Implement over `library_registry`/`abs_sym_path`; **do not** mutate
  `XSCHEM_LIBRARY_PATH` (process-global, would leak across windows).
- **Files:** `src/config_view.c`
- **Verify:** the two-libraries-same-cellname fixture resolves to each in turn.
- **Blast:** the memory note on `XSCHEM_LIBRARY_PATH`'s trace gotcha applies.

### 2.8 `get_sch_from_sym()` calls the resolver (C1)
- **Do:** replace the if-ladder body at `src/actions.c:3556-3630` with: rank 1
  (`hi_descend_view_path`, unchanged) → resolver → today's tail as ranks 4/6.
  **The tail is moved, not rewritten.**
- **Files:** `src/actions.c`
- **Verify:** **T-A over descend**: with `cadence_compat` unset and no config, every existing descend test
  (`test_descend_*`, `test_hi_descend`, `test_alt2_*`, `test_cadence_descend_*`)
  green. Then a config-loaded test proves a descend lands in `veriloga`.
  Then, with `cadence_compat` set: a descend into an instance carrying
  `schematic=` lands on the **config's** choice, not the attribute's.
- **Blast:** the highest-blast item in the batch — 11 call sites, five
  netlisters, print, and every descend key. Sabotage-verify hard. Note
  `hi_descend_view_path` (rank 1) is **not** gated by `cadence_compat`: it is a
  live user gesture, not stored design data.

### 2.9 `xschem config resolve` + provenance
- **Do:** expose the §3.6 result dict, including `source` naming the rank.
- **Files:** `src/scheduler.c`
- **Verify:** one assertion per rank that `source` names the right one.
- **Blast:** the GUI's Provenance column and every later debugging session.

### 2.10 Mirror notify — dirty flag plus one flush per event
- **Do:** spec §4.8's notification. Add `xctx->hier_mirror_dirty`; set it at the
  authoritative points only — selection set/clear, the tail of
  `descend_schematic()` and `go_back()`, `load_schematic()`, window/tab switch.
  **One flush** at the tail of `callback()` emits
  `hed::notify <win_path> <sch_path> <selected-instname-or-empty>`, then clears
  the flag. Skip the whole thing when no window is bound (one integer test).
- **Files:** `src/xschem.h`, `src/callback.c`, `src/actions.c`, `src/select.c`
- **Verify:** **T-T** — zero notifications with nothing bound; a rubber-band drag
  over 50 objects produces **one** notification, not 50. Assert by counting calls
  to a stub `hed::notify`, not by watching a window.
- **Blast:** the obvious wrong build is a `tcleval` at every `sel_array` touch —
  hundreds of Tcl round-trips inside one drag, and the drag is exactly the
  gesture where the editor must stay fast. If the flush point in `callback()`
  turns out to miss a path (a Tcl-driven selection, say), **add a set-site, never
  a second flush** — two flushes is how you get the 50 notifications back.

---

## P3 — the expander

### 3.1 `.sch` instance scanner
- **Do:** read instance records (`C {name} x y rot flip {props}`) straight out
  of a `.sch` file without loading it into `xctx`. Model it on the file scan
  already in `sym_vs_sch_pins()` (`src/netlist.c:1930-2000`).
- **Files:** `src/config_view.c`
- **Verify:** scanner output for the fixture equals `xschem get instances` +
  `getprop` after a real load, for every level.
- **Blast:** **D4**. If this proves unworkable, the fallback is Tcl driving
  `descend`/`go_back` like `hier_traversal` — slower, but the *command surface*
  (`config expand`) stays identical, so P4 does not move. That is the point of
  the partition.

### 3.2 File+mtime cache
- **Do:** cache scans keyed by (path, mtime, size); invalidate on save.
- **Files:** `src/config_view.c`
- **Verify:** expand twice, second is a cache hit; touch a file, it re-scans.
- **Blast:** a stale cache shows a tree that does not match the design — and the
  user will believe the tree.

### 3.3 Recursion guard + depth cap
- **Do:** visited-set on (resolved path, occurrence); cap at `CADMAXHIER`.
  A cycle emits a row marked `unresolved: recursion`, never a hang.
- **Files:** `src/config_view.c`
- **Verify:** the recursive fixture cell; the test must **time-bound** (a hang
  is the failure mode being tested for).
- **Blast:** a hang in a GUI Update with no Stop is unrecoverable for the user.

### 3.4 Vector-instance lazy expansion
- **Do:** `x[3:0]` is one collapsed row; opening it yields four occurrence rows.
- **Files:** `src/config_view.c`, `src/scheduler.c` (a `-depth`/`-node` arg)
- **Verify:** the vector fixture; expanding costs four rows, not before.
- **Blast:** **D6** — the element path form.

### 3.5 Nested configs, one level
- **Do:** if a node's resolved view is a `config` view, load it and let its
  bindings govern that subtree. Depth 1 only; deeper reports
  `unresolved: nested config depth`.
- **Files:** `src/config_view.c`
- **Verify:** a fixture with a sub-config.
- **Blast:** **D11**.

### 3.6 `xschem config expand`
- **Do:** one command, flat output, one line per node: occurrence path, depth,
  lib, cell, view found, view to use, effective viewlist, effective stoplist,
  flags (bound/inherited/stopped/unresolved/generator), provenance, count.
- **Files:** `src/scheduler.c`
- **Verify:** T-G; the fixture's expansion committed as a golden.
- **Blast:** **this is the entire GUI's data source (D4).** Its output format is
  a contract — changing it later is a P4-wide redo. Fix the column set here,
  document it in the spec, and add columns only by appending.

---

## P4 — the GUI

> Every item in this phase reads data **only** through `xschem config expand`
> and `xschem config {global,cell,inst}`. No resolution logic in Tcl. That rule
> is what makes a GUI redesign (D12) a P4-only event.
>
> Widget doctrine: `ttk::treeview` + `ttk::panedwindow` + sunken status label;
> **fixed bottom bars packed before the expanding centre widget**
> (`src/library_manager.tcl:78`); reuse the Library Manager's colours, invent no
> palette.

### 4.1 `.hed` toplevel skeleton
- **Do:** `hed::open {{lcv {}}}` following `libmgr::open`'s shape: single window,
  raise-if-exists, `wm title`, geometry, the six bands as empty frames in a
  vertical `ttk::panedwindow` (bands 3/4/5) with 2 and 6 fixed.
- **Files:** new `src/hierarchy_editor.tcl`; source it from `src/xschem.tcl`
  where the other helpers are sourced; add to install lists
- **Verify:** `test_hed_window.tcl` — opens, has the six bands, second call
  raises rather than duplicating, `destroy` is clean.
- **Blast:** **D12**. Everything else in P4 packs into these frames.

### 4.2 Band 2 — selectors, pre-filled
- **Do:** Config lib/cell/config comboboxes (from `library_registry`,
  `library_cells`, `cell_views` filtered to the config type); Top lib/cell/view;
  `Open` and `Update` buttons.
  **Pre-fill (D8, ruled):** `hed::open` with no argument, launched while a
  schematic is showing, opens with Config *Library*/*Cell* and all three Top
  Cell fields set to the current cell — `xschem get_inst_lcv`-style, the same
  source `libmgr::open` uses for its optional LCV. Untitled window ⇒ empty
  fields, no error.
- **Verify:** combobox contents equal the corresponding proc's output; **T-R**
  covers the pre-fill and the untitled case.
- **Blast:** the pre-fill must read the *current* window's cell, not a global —
  with tabs open, reading the wrong one silently points the user at another
  design's hierarchy.

### 4.3 Band 3 — global bindings
- **Do:** four labelled entries (Library List, View List, Stop List,
  Description), collapsible to a one-line summary, bound to
  `xschem config global`.
- **Verify:** edit → `config get` reflects it → save → reload → survives.
- **Blast:** **D2, ruled: one Stop List field, not five.** Build the four rows
  as a loop over a `{key label}` list anyway — that is one line of insurance, and
  the accessor already takes dotted keys (§3.4's implementation note), so a
  per-format list would later be data rather than a redesign.

### 4.4 Band 4 — tree widget + columns
- **Do:** `ttk::treeview -columns` with the spec §4.3 column set; headings;
  per-column widths; a horizontal scroll region that scrolls **inside** the pane.
- **Verify:** columns present and in order.

### 4.5 Band 4 — populate from `config expand`
- **Do:** parse the flat expansion into treeview rows; row id **is** the
  occurrence path (making lookup, selection and binding-write all one string).
- **Verify:** the fixture's tree matches the committed expansion golden.
- **Blast:** **D4/D6**.

### 4.6 Row tags
- **Do:** `bound` (bold), `inherited` (normal), `stopped` (dimmed, no expander),
  `unresolved` (red fg, `<view not found>`), `generator` (italic). Fonts derived
  from the treeview default, created once — the `LibMgrBold` pattern
  (`src/library_manager.tcl:92`).
- **Verify:** one fixture row per tag; assert the tag, not the pixel.
- **Look debt:** `owed.sh add look hed-row-tags`.

### 4.7 View-To-Use editing
- **Do:** click the cell → a combobox listing exactly `cell_views` for that cell
  plus `<none>`; choosing writes `xschem config inst <path> view <v>` (Tree) or
  `config cell <lib> <cell> view <v>` (Table); marks stale.
- **Verify:** edit → the binding table (4.9/4.10) shows the new row → Update →
  View Found changes.
- **Blast:** ttk::treeview has no cell editor; use the overlay-combobox pattern
  already solved in `src/calculator.tcl:1556` — read that comment first.

### 4.8 Table tab
- **Do:** the notebook's second tab: one row per unique (lib, cell), with Count.
  Same columns, same right-click menu, no Instance column.
- **Verify:** unique-cell count matches the expansion.

### 4.9 / 4.10 Band 5 — cell and instance binding tables
- **Do:** two notebook tabs listing what the **config stores** (not what
  resolved). Editable View column; `[+] [−] [Clear all]`.
- **Verify:** every write path in 4.7 shows up here; deleting a row here and
  pressing Update reverts the tree.
- **Blast:** this is the pane that makes the feature comprehensible. Do not let
  it degrade into a filtered view of band 4 — it must show bindings that match
  **nothing** in the current hierarchy (that is how a typo becomes visible, and
  it is what 6.4's validator reports on).

### 4.11 Right-click Bindings menu
- **Do:** build once, retarget per click — `libmgr::ctx_post`
  (`src/library_manager.tcl:141`). Items = spec §4.2's Bindings menu.
- **Verify:** each item fires the right command with the clicked row's path.

### 4.12 Update + dirty/stale state
- **Do:** `Update`/`Ctrl+U` re-expands; a binding edit sets stale (status bar
  says so, tree dims); save clears dirty; close with dirty prompts.
- **Verify:** the three states asserted from Tcl.
- **Blast:** **D7** — auto-update is one `if` behind a preference here.

### 4.13 File menu
- **Do:** New Config… (a New View dialog pre-filtered to `config`), Open…,
  Save, Save As…, Recent Configs, Open Top Cellview, Close.
- **Verify:** each round-trips through P1's commands.
- **Blast:** "Recent Configs" must not pollute Open-Recent for schematics —
  issue 0119's leak, in a new place.

### 4.14 View menu
- **Do:** Tree/Table radio, Expand/Collapse All, Show Only Bound, Show Only
  Unresolved, Show Provenance.
- **Verify:** filter counts asserted against the expansion.

### 4.15 Launch points — no accelerator
- **Do:** **D8 as ruled — register no key.** Four ways in (spec §4.6):
  main menubar **Tools → Hierarchy Editor** (pre-filled, 4.2); a command-palette
  entry via an `actions.csv` row with an **empty `accel` column**; LibMgr
  double-click on a config view (pairs with 7.4) and *New view…* (1.9);
  `xschem hierarchy_editor [lcv]`.
- **Verify:** **T-R** — all four paths open the window, and a grep of
  `keybindings.csv` shows **no** binding was added. `test_accelerators` and
  `test_bindings_file` stay green (they will, since nothing was claimed — which
  is the point of asserting it rather than assuming it).
- **Blast:** D8 (ruled), D12. Note `Ctrl+Shift+H` is *make schematic from
  selection* (`src/xschem.tcl:17498`); do not reach for it. Anyone who wants a
  key gets one through the action registry, which is why the palette row matters
  more than a default chord.

### 4.16 Status bar + window numbering
- **Do:** counts (`N cells, M bound, K unresolved`), the stale message, and
  `bind $w <FocusIn> {+notify_window_active <n> {Hierarchy Editor}}` per
  `doc/claude/specs/window_numbering.md`. Pick the next free window number.
- **Verify:** the window-numbering suite.

### 4.17 Schematic-window ↔ HED binding registry
- **Do:** spec §4.7. `hed::bound(<win_path>) = <hed toplevel>`, set when the HED
  opens the design (band 2 `Open`, `File → Open Top Cellview`, a tree-row
  double-click that opens a cellview); cleared when either window closes.
  Re-opening through the same HED re-binds. One schematic window → at most one
  HED; **one HED → many schematic windows** (D15).
- **Files:** `src/hierarchy_editor.tcl`
- **Verify:** bind, close the schematic, re-open from the HED, still bound;
  close the HED, the schematic keeps working and every §4.8–§4.10 behaviour is
  gone; two schematic windows on one HED both mirror.
- **Blast:** **D15.** This is the item that decides whether "that HED instance"
  means anything. It also decides the leak: a stale `hed::bound` entry for a
  destroyed window makes 2.10's "is anything bound?" test true forever, so the
  flush never goes quiet again. Clear on `<Destroy>` of **both** windows.

### 4.18 Live mirror — Tree follows the schematic, one way
- **Do:** `hed::notify` consumer. Translate `sch_path` (dot-separated, trailing
  dot, `src/actions.c:4039-4042`) into a config occurrence path with the **1.7
  helper** — that helper is the single point where D6 could be reversed, so do
  not open-code the conversion here. Expand the tree down the path, scroll it
  into view, select the row for the selected instance or, with nothing selected,
  for the displayed cell. Ascending moves the selection up and collapses nothing.
- **Files:** `src/hierarchy_editor.tcl`
- **Verify:** **T-S**, and its second half is the important one: clicking,
  expanding and collapsing rows in the Tree must change **nothing** in the
  schematic — assert `sch_path`, `currsch` and the selection set unchanged
  across a scripted burst of tree interaction.
- **Blast:** the one-way rule is easy to break by accident, because the natural
  Tk idiom is a `<<TreeviewSelect>>` handler that "keeps the two in sync". The
  Library Manager already carries the scar tissue for the adjacent bug — a
  programmatic `selection set` firing the user's handler
  (`libmgr::suppress_select`, `src/library_manager.tcl:130`). Use the same
  suppress-flag pattern: the mirror's own writes must not re-enter anything.

### 4.19 Locate — `Ctrl+Shift+L` → Table row focus
- **Do:** spec §4.9. In a bound schematic window: switch the HED to **Table**
  view, select and scroll to the row for the target cell — the selected
  instance's cell, or the displayed cell when nothing is selected. Unbound, or
  cell not in the expanded hierarchy: report on the schematic status bar, do
  nothing. Register in `actions.csv` with `accel` = `Ctrl+Shift+L` (**D16**) so
  it is palette-searchable and rebindable in one row.
- **Files:** `src/hierarchy_editor.tcl`, `src/actions.csv`, `src/keybindings.csv`
- **Verify:** **T-U**, all five cases. `test_accelerators` and
  `test_bindings_file` stay green.
- **Blast:** **D16.** Do **not** take `Ctrl+I` — it is *insert symbol*
  (`src/callback.c:7590`), core, and stealing it regresses every user who never
  opens the HED. Anyone who wants the Cadence muscle memory rebinds one row.
  Second trap: this is the only key the feature claims, so it must be genuinely
  inert in an unbound window — not "opens an HED", not an error dialog.

### 4.20 Schematic context menu — `View ▸`
- **Do:** spec §4.10. Add a `View ▸` entry to `context_menu`
  (`src/xschem.tcl:14956`), shown **only** when the window is bound and exactly
  one instance is selected. It pops a second `overrideredirect` popup listing
  `cell_views` for that cell, the resolved view marked. Picking one writes an
  **occurrence** binding at that instance's occurrence path, reports on the
  status bar, and marks the HED stale (no auto-update, D7). Cell-wide is not a
  second cascade — that is the HED's existing **Promote Instance→Cell** (6.6).
  A new `tctx::retval` code and its arm in `context_menu_action()`
  (`src/callback.c:5144`); the pick is a config write, so it is **not** subject
  to `readonly_block()` and must **not** set the design's modify flag.
- **Files:** `src/xschem.tcl`, `src/callback.c`, `src/hierarchy_editor.tcl`
- **Verify:** **T-V**, including `xschem get modified` unchanged across a pick.
  Existing `test_context_menu_log` stays green.
- **Blast:** **D17.** `context_menu` is hand-rolled buttons in an
  `overrideredirect` toplevel, **not** a Tk `menu` — there is no cascade to
  inherit, and the existing `close_ctxmenu_on_leave` dismiss logic will fight a
  child popup that the pointer has to travel over to reach. Budget the dismiss
  handling as the real work of this item; if it turns ugly, the flat
  `Set view: <name>` fallback is one `foreach` and D17 flips with no other item
  affected. Second trap: the action log — a pick must record a replayable
  `xschem config inst <path> view <v>`, not a coordinate-bearing menu click.

---

## P5 — netlist integration

### 5.1 Binding materialisation pre-pass
- **Do:** before `get_additional_symbols(1)` runs, walk the **current**
  schematic's instances, resolve each against the config, and record the
  resolved target + mangled name where it differs from the default. Do **not**
  write into the design's `prop_ptr`; carry it in a side table keyed by instance
  index.
- **Files:** `src/config_view.c`, `src/actions.c`
- **Verify:** the side table's contents for the fixture, asserted via a debug
  subcommand.
- **Blast:** F3 — this is the only place instance context exists at netlist time.

### 5.2 `get_additional_symbols()` consumes the pre-pass
- **Do:** where it reads the instance `schematic=` attribute
  (`src/actions.c:3389`), take the resolution from the pre-pass instead. Per the
  **D1** ruling, under `cadence_compat` the attribute read is skipped entirely
  and the instance is logged into the ignored list for 5.8. Everything
  downstream — the clone, `base_name`, `parent_prop_ptr`, and the `*_sym_def`
  copying, which is **not** gated — is unchanged.
- **Verify:** T-A first (no config ⇒ identical clone set), then a config test.
- **Blast:** the single highest-value integration point in the batch (F2).

### 5.3 Mangling + collision detection
- **Do:** `<cell>__<viewname>`; the cell-level binding keeps the plain name;
  a real cell already holding the mangled name gets a numeric suffix and a
  warning line.
- **Verify:** T-F; plus a fixture that deliberately contains `amp__veriloga`.
- **Blast:** **D3**. Confined to P5 by construction.

### 5.4 / 5.5 Backends
- **Do:** verify each of spice, spectre, verilog, vhdl, tedax under a config.
  Expect **no code changes** in the backends — if one needs a change, that is a
  finding worth a receipt paragraph, because it means the F1/F2 model has a hole.
- **Verify:** per-format golden pairs (no-config vs config).

### 5.6 Stop list OR `*_stop`, all five formats
- **Do:** implement spec §3.4 as ruled: a node stops if **either** the config's
  stop list names its resolved view **or** the symbol carries that format's
  `spice_stop` / `spectre_stop` / `verilog_stop` / `vhdl_stop` / `tedax_stop`.
  OR, never override — a config may add a reason to stop, never remove one.
  Not gated by `cadence_compat`: `*_stop` is not a view selection (spec §3.8).
- **Files:** the five `*_netlist.c` stop reads, or one shared helper
- **Verify:** **T-O** — four combinations (attr × config, on/off) × five formats.
  Plus T-A: with no config, all twenty cases behave as today.
- **Blast:** **D2, ruled.** Getting the polarity backwards (letting a config
  un-stop a symbol) produces a netlist that descends into a schematic the symbol
  author knew was not netlistable — a broken netlist, not a different one.

### 5.7 T-A sweep
- **Do:** regenerate the whole 0.2 golden set with the feature built and no
  config; require byte-identical.
- **Blast:** if this is red, **stop the batch** and bisect. It is the promise
  the entire design rests on.

### 5.8 Ignored-attribute warning
- **Do:** at the end of a netlist run under `cadence_compat`, emit the spec §3.8
  report — a count line plus one line per ignored attribute (occurrence path,
  symbol, the attribute text), then the `Bindings > Import` pointer. To the log
  **and** to the CIW via `ciw_echo`, never `puts` (memory: ciw-feedback-channels).
  Deduplicate: a symbol-level attribute is reported once, not once per instance.
- **Files:** `src/config_view.c`, the five `*_netlist.c` tails or one shared
  hook — prefer one hook, called where `get_additional_symbols(0)` would be
- **Verify:** T-M's warning half — the fixture's five attributes produce exactly
  five lines, once, in one run; a second netlist in the same session produces
  five again, not ten (a stale accumulator is the obvious bug here); with
  `cadence_compat` unset, no output at all.
- **Blast:** **D1, ruled.** This item is the user-visible half of the ruling. If
  it is skipped or degraded to a log-only line, a parasitic-annotated block
  silently becomes ideal — the failure mode the ruling was written to prevent.

---

## P6 — import / export / validate / diff

### 6.1 `config import`
- **Do:** expand the hierarchy; for every node whose resolution came from a
  design attribute (provenance rank 4), write the equivalent binding — cell
  binding when the attribute is on the symbol, occurrence binding when it is on
  an instance.
- **Verify:** T-H first half — import, then `config unload`... no: import, then
  **strip the attributes in a scratch copy**, and prove the netlist is identical.

### 6.2 `config export`
- **Do:** the inverse — write resolved bindings back as `schematic=` attributes.
  Occurrence bindings that cannot be expressed (the same parent cell used twice
  with different children) are **reported, not silently dropped**.
- **Verify:** T-H second half; plus an explicit test that an inexpressible
  binding is reported.
- **Blast:** silent loss here corrupts a design. The report is the feature.

### 6.3 Menu wiring for import/export
- **Do:** the two Bindings-menu items, each with a confirmation naming how many
  bindings will be created/written.
- **Blast:** export **modifies the design**. It must be undoable
  (`push_undo` before) and must refuse on a read-only view.

### 6.4 Validate
- **Do:** all five spec §7.4 categories, reported in one list, each row
  clickable to the offending node.
- **Verify:** T-J — a fixture per category.

### 6.5 Diff against config
- **Do:** pick a second config; expand both; list only nodes that resolve
  differently, with both answers.
- **Look debt:** `owed.sh add look hed-diff`.

### 6.6 Promote Instance→Cell
- **Do:** turn an occurrence binding into a cell binding, warning how many other
  occurrences it will now affect.
- **Verify:** the count in the warning equals the expansion's count column.

---

## P7 — other consumers

### 7.1 `hier_psprint()` under a config
- **Do:** it already calls `get_additional_symbols(1)` twice
  (`src/psprint.c` path, `src/spice_netlist.c:80,108`); confirm the pre-pass
  reaches both, and that the printed page set follows the bindings.
- **Verify:** page count and cell order against a golden.

### 7.2 / 7.3 ASE-L
- **Do:** an optional `config` field in the ASE state dict (**D13**);
  `ase::netlist` loads it, netlists, unloads — never leaving it active.
- **Files:** `src/ase.tcl`, `src/ase_window.tcl`, `src/library_defs.tcl`
  (the `state` seed)
- **Verify:** a state with a config produces the config's netlist; the same
  state with the field removed produces today's; the field survives save/load.
- **Blast:** **D13**. An ASE state that silently keeps a config active would
  poison every later netlist in the session — assert the unload.

### 7.4 LibMgr opens a config in the HED
- **Do:** the `hed` branch in `libmgr::view_handler` (paired with 1.1).
- **Verify:** double-click a config view → the HED opens on it.

### 7.5 Two windows, two configs
- **Do:** nothing new — this is the T-K assertion that 2.1 was right.
- **Verify:** two tabs, two configs, two different netlists, one session, and no
  leak under `-d 3`.

---

## P8 — close

### 8.1 User documentation
- **Do:** a `doc/` page in the shipped format (`.html`/`.svg` per
  `doc/Makefile`), covering: what a config is, the three binding scopes, the
  view/stop list, and the import path for existing designs.

### 8.2 Explainer
- **Do:** `doc/claude/code_analysis/hierarchy_editor_explained.md` — how the
  resolver, the expander and the materialisation pre-pass fit together, written
  for the next session, not for the user.

### 8.3 actions.csv + palette
- **Do:** rows for the launcher and the Tools items so the command palette and
  the cheat sheet pick them up (`src/actions.csv`, header
  `id,type,menu,label,accel,command,submenu,hook,help,idle,nolog`).

### 8.4 The fate of `traversal`
- **Do:** decide **D9** with the user. Options: keep both; make `traversal`'s
  `Upd` button offer "write to config instead"; retire it. **Default: keep,
  untouched.** Whatever is chosen, record it in the ledger and the spec.

### 8.5 Full audit + close
- **Do:** `full_audit.sh` diffed **by test name and status** against the 0.2
  baseline (never by red count — new tests are not regressions). Regenerate the
  T-A goldens one final time. Drain the suite debts (`owed.sh drain`); list the
  look debts for the user and **do not clear them**.

---

## Standing rules for every item

0. **T-P runs on every item** alongside T-A: the moment a hardcoded `config` /
   `.cfg` lands, D14 stops being a two-row edit and the user's "easily updated
   later" quietly becomes false. Cheapest possible guard, so there is no excuse.
1. **T-A runs on every item**, not just P5. The moment a no-config netlist
   changes, the item that changed it is the one on the bench.
2. **Sabotage-verify**: break the new code, prove the suite goes red, restore.
   A green suite is not evidence the new code ran (memory: green-but-hollow).
3. **Never `make` while suites run** (memory: suite flakes under CPU load).
4. **Pixels are `[E]`, never `[x]`** — record a look debt and say "suites green,
   please look".
5. Commit per item; never push.
6. New `.c` file ⇒ `src/Makefile` `OBJ` **and** an explicit compile rule, edited
   in `Makefile.in`, then `./configure` (memory: open-pdk-merge).
7. `_ALLOC_ID_` placeholders, never hand-numbered ids. C89 only.
8. Any config variable mirrored into Tcl gets the `MIRRORED IN TCL` treatment.
