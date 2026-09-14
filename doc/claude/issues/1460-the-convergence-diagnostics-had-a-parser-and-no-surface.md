# 1460 — the convergence diagnostics had a parser and no surface

**Branch** `fluid-editing`. **Batch** `doc/claude/ase_analyses_batch/`, **PLAN.md Stage 10**,
task 2 of two — the **GUI** half. Issue **1459** is task 1 and is the deck half; this is
everything that draws.

## What goes wrong for the user

Issue 1459 landed four parsers, three emitters, two refusal evaluators and eleven ngspice
adapter hooks, and **built no widget**. Every reader it shipped had exactly **zero callers**
anywhere in the program outside its own suite:

* **`ase::ncdump_failing`** knew which nodes had failed the convergence test — the table
  `evidence/convergence.md` calls *"the single most useful diagnostic in ngspice"* — and
  **nothing lit them**;
* **`ase::ladder_parse`** knew which of the four operating-point rungs had answered, and
  **nothing said so**;
* **`ase::optran_line`** could only be reached by **hand-editing a `.state` file**, because
  the `opstrategy` key had no control anywhere in the program;
* **`ase::wrnodev_lines`** and **`ase::runhealth_lines`** were the same: a deck line nobody
  could ask for and four counters nobody read back.

A feature that is half-built is not half-delivered. Until this, Stage 10 shipped a `.state`
schema and a set of test fixtures.

## What this adds

Everything is in **`src/ase_window.tcl`**, plus one reader (`ase::runhealth_strip`) and one
adapter hook (`runhealth_labels`) in `src/ase.tcl` — see the correction below for why that
one had to grow.

1. **The nodes that did not converge, lit on the canvas** (§10a). `Results > Highlight
   Non-Converged Nodes`. The starred names go through `ase::netlist_map`'s
   hierarchy-qualified resolution; the ones that are nets on this sheet are lit with
   `xschem hilight_netname`, and **the ones that are not are reported by name with the
   reason** — a node inside a subcircuit, or a name this netlist has never heard of.
2. **The four-rung ladder pane** (§10b). `Simulation > Convergence…`, directly below
   `Options…`. One checkbox per rung the registry declares, wearing that rung's own label;
   the step count and the two transient times as fields; the emitted line beneath it.
3. **The remedy assistant with a deck diff** (§10b). Every remedy is a state edit and
   nothing else, so the preview is two `render_deck` calls on one netlist and the diff is a
   promise rather than an illustration.
4. **The run-health strip** (§10c). One line in the status bar, filled by a finished run,
   empty on every bench that never asked for the counters.
5. **The sentence on the OP form** (§10b). `ase::ladder_ran_notes` mints it **conditionally**
   and this is the label that shows it.

## The row this issue exists for: a checkbox that really means OFF

*"An accepted-and-inert setting"* is this batch's most-met defect and has a standing rule in
`LEDGER.md` with five measured members. **MEASURED 2026-09-13, both binaries, byte-identical,
ONE checkbox apart**, on a circuit whose Newton rung runs and fails:

| the deck ASE-L renders | rc | what happened |
|---|---|---|
| `optran 1 0 0 100n 10u 0` — transient rung ticked | **0** | `v(1) = 1.413677e-02` |
| `optran 1 0 0 0 10u 0` — transient rung cleared | **1** | `Error: The operating point could not be simulated successfully.` + the starred table |

Newton is ON in both, so `ase::opstrategy_refusals` permits both decks: the pair differs in
the transient rung and in nothing else. Row **EE1** of `test_ase_conv_gui_1460.tcl` renders
both decks from the dialog's own state builder and runs them.

⚠ **And the deck that kills the run outright cannot be reached from the form.**
`optran 0 0 0 0 10u 0` — every rung off — is rc 1 on both binaries, and the dialog refuses it
(`allrungsoff`, row **GX3**) before it can be rendered.

## The trap this cost an hour to find, and the tree already knew about it

`src/ase_window.tcl` defines **`ase::ui::open`** and **`ase::ui::close`** (the session
window's own opener and closer). A bare `open $p r` inside **any** proc in that file
therefore resolves to the *window* opener, raises on its argument count, and — inside the
`catch` a total reader needs — **returns an empty log with nothing said**. Measured: every
reader in this change silently answered `{}`, and the rows that depended on one went green by
reading an empty string.

The tree already carried the knowledge, one screen away: `ase::ui::show_log` has the comment
*"::open — inside ase::ui a bare `open` resolves to ase::ui::open"*. A comment on one call
site is not a rule. Every file read added here is `::open` / `::read` / `::close`, and the
header of `ase::ui::conv_logtext` states it for the next person.

## Corrections to PLAN.md §10

| | |
|---|---|
| **C15** | ⚠ **`ase::ui::conv_form_state` with no dialog standing must return the session UNCHANGED.** Reading three absent widgets as three cleared controls handed back a state with the strategy, the saved operating point and the health line all **wiped** — a reader that destroys what it was asked to describe. Row **GT6b** is the one that says so. |
| **C16** | **The run-health strip needed a label hook, and that is why `src/ase.tcl` grew.** The counters' keys (`tranpoints`, `accept`, …) are not user copy, and a label table in the surface would leak ngspice into it. `ase::runhealth_strip` orders and renders; `ase::backend::ngspice::runhealth_labels` names. **Every counter the parser found is in the answer, labelled or not** — a label-driven loop would go on printing a stale set for ever the day the adapter reports a fifth counter (row **HL3**). |
| **C17** | ⚠ **§10a's highlight cannot light a hierarchy-qualified node, and that is a fact about the canvas rather than a limit of the map.** `hilight_netname` looks a name up in **this sheet's** node hash (`hilight.c`, `bus_node_hash_lookup`); `x1.nn` names a node inside a subcircuit and there is no wire here to find. It is reported by name with `inside a subcircuit` on it rather than dropped. |
| **C18** | ⚠ **The highlight must not be automatic on a failed run.** Lighting a user's schematic without being asked is a mutation of what they are looking at. `run_finished` **says** how many nodes failed and names the door; the user decides. |
| **C19** | **PLAN.md §10's ≈ +330 for `src/ase_window.tcl` is ≈ +780** (about half comment), because §10b is three surfaces (the pane, the emitted line, the refusal note) and the remedy assistant needs a real LCS diff — a positional compare reports every line after an insertion as changed, which is the opposite of what the pane exists to show (row **DF4**). |
| **C20** | ⚠ **`seed` and `force` reach the user in a refusal core already ships** (*"choose seed or force"*), so the form uses those words rather than inventing a second vocabulary for one setting. They are jargon and **whether they stay is the user's ruling** — filed, with the note that the refusal's fix clause changes with them. |

## Where it is tested

**`tests/headless/test_ase_conv_gui_1460.tcl`**, NEW, registered in **both** of
`tests/run_regression.tcl`'s case lists — **44 checks headless, 103 on the dev display**.
Sections `CP NC HL DF RM OP` are pure Tcl; `GW GT GX GN GH GR GC GF` need widgets and
self-skip without a display; **`EE` starts a real simulator on both binaries on both arms**.

`tests/headless/test_ase_window.tcl` row **W1m** gains the new Simulation-menu entry (a
changed expectation, not a new row; 56 / 295 unmoved).

## The two directions every reader here is asked in

Issue 1457 shipped a defect past an end-to-end row that asked only *"is everything promised
present?"* — it would have passed with a **missing** promise. So **NC6** asks the resolver to
account for **every** starred name with the row count as its control, and **HL3** feeds the
strip a counter the adapter has no label for and demands it appear anyway.

## Still owed

* ⚖ **The sentences this surface mints** — `owed.sh add rule 1460`, listed verbatim in
  `doc/claude/ase_analyses_batch/receipts/37-stage-10-gui.md`.
* 🔭 **The lit nets on the user's own screen.** `owed.sh add look`. `AUDIT_DISPLAY=:0` is
  **Xwayland**, not the screen the user looks at; a change to the *canvas* must be seen on
  `$DISPLAY`.
* **No live ladder pane.** Debt M1 is closed and says a live pane costs a **second capture
  channel** — `run_cmd` appends `2>@1` and every existing log reader expects one stream. The
  pane reads the log after the fact, which `PLAN.md` §10 allows.
