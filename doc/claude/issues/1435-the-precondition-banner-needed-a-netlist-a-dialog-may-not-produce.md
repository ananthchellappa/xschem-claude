# 1435 — the precondition banner needed a netlist a dialog may not produce

**Stage 6 of the ASE-L analyses batch, task 6.** Batch:
`doc/claude/ase_analyses_batch/`; receipt
`doc/claude/ase_analyses_batch/receipts/18-stage-6-banner.md`.

## The defect

`PLAN.md` Stage 4 ("The netlist permits") shipped `ase::netlist_facts`,
`ase::analysis_needs` and `ase::analysis_precheck`, and **two of its three
user-visible surfaces**: `ase::preflight_gate`'s `fatal` refusal (issue 1424) and
its pre-run advice block (issue 1425). The third — *"a banner under the form
saying what will be wrong before you run"* — did not land, and `LEDGER.md` named
the reason rather than hiding it:

> the **precondition banner under the form** needs netlist *text*, which the
> dialog does not have and can only obtain by calling `ase::netlist` — **a side
> effect no dialog may have because a user opened it**.

So the user's only route to *"`v1` has no AC value — a noise analysis needs an AC
input source"* was to press Run and read the log afterwards. The fact was
knowable from the netlist before anything started, the remedy was already minted,
and the form said nothing.

**And the call really is not a read.** `ase::netlist` deletes and rewrites
`<rundir>/<cell>.spice`; with an empty `rundir` key `ase::rundir` answers
`set_netlist_dir 0`, i.e. `~/.xschem/simulations`, one global directory shared by
every state of every cell. Its arm (b) does `xschem load`, replacing the current
schematic buffer. Its arm (c) is `ase::with_design_current`, which ascends the
user's hierarchy, parks `autosave_backup`, and **refuses outright** for a
modified buffer with autosave off.

## The fix

**A slot the dialog peeks at and never fills**, which is the shape this file
already uses twice — `ase::sim_caps_cached` ("THE FREE PEEK … IT MUST NEVER START
A PROGRAM", with Detect as the one cold door) and `ase::op_cards_put/_hit/_for`
(filled as a by-product of a netlist somebody asked for).

**The fill site is `ase::netlist_in_place`, and it is the only one.** Measured:
`xschem netlist ` appears **exactly once** in `src/ase.tcl` and **not at all** in
`src/ase_window.tcl` once comments are stripped, and all four arms of
`ase::netlist` end in that proc. So every legitimate producer — *Simulation >
Netlist > Recreate*, *Netlist > Display*, *Netlist and Run*, the descend round
trip — fills the slot, and nothing else can. `ase::op_cards_capture` is captured
on the line above for the same reason.

### The schema half (`src/ase.tcl`, core `ase::`)

| proc | what it answers |
|---|---|
| `ase::facts_clear` / `ase::facts_stamp` | empty the one slot; a file's `mtime:size` identity |
| `ase::facts_design_path {state}` | where the design lives, resolved the way `ase::netlist` resolves it and with none of its side effects |
| `ase::facts_is_current {path}` | is this the schematic the editor is showing |
| `ase::facts_capture {state netlistpath}` | **the priming seam** — one line inside `ase::netlist_in_place` |
| `ase::facts_donate {state netlistpath facts}` | the run path hands over the copy `preflight_gate` already computed; **fills an existing slot, never creates one** |
| `ase::facts_status {state}` | `cold` / `stale <why>` / `warm`, from two `file stat`s and one `xschem get` |
| `ase::netlist_facts_cached {state}` | **the free peek** — parses once, memoises, `{}` for cold or stale |
| `ase::state_option_map {state}` | the option flattening `analysis_precheck` carried inline; now one body |
| `ase::precheck_banner {sim state type row}` | `cold` / `stale` / `clear` / `caution` / `blocked` / `fatal` **for the selected type, enabled or not** |
| `ase::precheck_banner_text {banner}` | the rendered lines, worst first |

### The content half

**None, and that is the finding.** Every precondition sentence the banner prints
was already minted by issues 1423/1425/1426/1427/1428/1432/1434 in
`ase::needs_eval`, where the adapter's content already arrives through hooks
(`dc_swkind`, `disto_*`). The registry's `needs` lists were complete. This issue
mints **three frames** — the cold sentence and the two stale sentences — and
`ase::backend::ngspice` is **byte-unmoved**.

### The window half (`src/ase_window.tcl`)

`$w.note`, a wrapping label at grid row 7 of the Choose Analyses dialog — under
the form, above `Options…`, **no existing widget path moved**; `ase::ui::chana_note`
repaints it at the end of `chana_show`; `ase::ui::chana_form_vals` and
`ase::ui::chana_merged_row` factored out of `chana_ok` so the banner judges *what
is typed* rather than what is stored; `ase::ui::chana_glyph` gains a `fatal` arm
that wears `blocked`'s mark; `lbl_netlist`, `lbl_netlist_recreate` and
`menu_path_netlist_recreate` so the banner's door is composed from the menu's own
labels rather than spelled twice.

## ⚠ THE PLAN CONTRADICTED ITSELF AND THE MEASUREMENT SETTLES IT

`PLAN.md` Stage 4's *Re-measure on the dev display* paragraph says *"there is no
new pixel … **No look debt is filed**"*; its *Files and procs* table three
paragraphs above adds a **`.note` precondition banner**. Measured on `:99`
against the live dialog, 2026-09-12:

* with the capability cache cold — **what a user who has never pressed Detect
  has** — `$w.status` is **occupied on all eleven cells** (nine `baseline`, two
  `unrenderable`), so a precondition sentence there would evict a capability
  sentence that is equally true;
* `$w.status` has **`-wraplength 0`**, and one 101-character precondition
  sentence in it took the dialog from **667 px to 856 px** wide.

So the `.note` table row is the live half and the *"no look debt"* paragraph is
the stale one. **A `look` debt is filed** (`owed.sh add look`), and the banner is
reported as *"suites green, please look"*, never as done.

## Measured

All 2026-09-12/13, both binaries where a simulator was involved — the fork
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`) and
`/usr/bin/ngspice` (`ngspice-45.2`). Nothing under `~/.xschem/` was touched, no
bench under `sky130A/` was run, every launch carried `--nolog` and a path.

* `ase::netlist_facts` costs **0.9 ms / 7.5 ms / 76.5 ms** over 200 / 2 000 /
  20 000 netlist lines (3.3 KB / 38.7 KB / 447 KB) — linear, and the reason the
  facts are parsed **lazily and memoised** rather than at every capture or at
  every `chana_show`.
* Through the product's own *Netlist > Recreate*: `ac` gains *"this circuit has
  no AC source … Fix: put `ac 1` on the input source"*, `disto` gains its
  `distof1` sentence, a `dc` row typed with `Vnope` gains *"this circuit has no
  'Vnope' to sweep"*, and a `noise` row referred to `V1` gains Stage 4's own
  headline sentence — **all before the run**.
* Opening the dialog and clicking all eleven cells starts **no netlist**
  (`bn_netlisted` 0 over eleven banner evaluations, a peek and a status call; and
  through the real dialog in `test_ase_dialogs` GN10).
* The banner adds **zero width**: dialog `reqwidth` is 667 with and without it,
  note `reqwidth` 590.

## Suites

| suite | before → after | in T1? |
|---|---|---|
| `test_ase_core` | 558 → **598** (section BN, 40 rows) | yes |
| `test_ase_preflight` | 229 → **235** (section PF233, 6 rows) | yes |
| `test_ase_dialogs` display | 285 → **300** (section GN, 15 rows) | headless arm only |
| `test_ase_dialogs` headless | 37 → 37 | yes |

**No deck golden moved and no `.state` file moved.** No new state key, no
`seed_enabled`, `ase::state_default` still seeds exactly four rows, and the 104
committed `.state` files round-trip byte-identically — section CP is the row that
would notice.

## What was NOT shipped, and why

* **A live refresh as the user types.** The banner repaints on every
  `chana_show` — a radio pick, an Advanced toggle, a mode relabel — and reads the
  form's live values when it does. A per-keystroke refresh needs per-field
  bindings and a debounce, which is a surface of its own.
* **A whole-bench banner.** `ase::preflight_gate`'s advice block (1425) already
  is one, before the run. This one is per-type, before the commit. Two
  complementary surfaces, neither replacing the other.
* **Filling the slot from anywhere but a netlist.** No probe, no background
  parse, no "netlist quietly on open". The whole item is that the dialog has no
  such right.
