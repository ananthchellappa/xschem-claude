# 1404 — Stop succeeds silently, and the user goes looking for a rawfile that was never written

**Stage 2e of `doc/claude/ase_analyses_batch/`**, and the item the user asked for *right away*.
⚠ **It is not thematic to Stage 2 and does not pretend to be.** It rides Stage 2 because it
mints a user-facing sentence and Stage 2 is the first stage in that plan carrying one. It is
deliberately **not** in Stage 0 — Stage 0's whole claim on shipping first is that it costs no
ruling and moves no existing row — and **not** in Stage 6f either, because the warning is what
is honest *until* salvage lands, not a substitute for it.

## The defect

**Both Stop doors kill the simulator outright, and the window says nothing about what that
costs.** `ase::ui::do_stop` → `kill_running_cmds $id -9`.

⚠ **ngspice in batch installs a handler for NO SIGNAL AT ALL.** `main.c` puts the whole signal
block inside `if (!ft_batchmode)`, and SIGTERM, SIGHUP and SIGQUIT are installed in no mode. So
the process dies at the default disposition in **a few milliseconds at worst**, and nothing of
the analysis in flight is on disk.

The Stop therefore succeeds, silently, and the user goes looking for a rawfile that was never
written. Downstream they meet `ase::attach_dbs` reporting `NOT ATTACHED … the analysis did not
run` — which reads as the simulator having failed rather than as the Stop having discarded
everything.

## What shipped

**Two sentences, both plain text, no dialog.**

1. **At launch** — in the run log header as a `stop      :` field, and once in the CIW:
   > `ase: Stopping this run discards it — ngspice in batch mode writes nothing on a stop.`
2. **At the moment of the Stop**, from `ase::ui::do_stop`, and **only on the path that actually
   killed something** — the nothing-to-stop path keeps the sentence it has:
   > `ase: simulation stopped — nothing of this run was written`

**⚠ ASE-L OWNS THE FRAME; THE ADAPTER OWNS THE CLAUSE, and that split is the whole design.**
Stage 1's Xyce paper-validation (§1e) caught this item's own plan text asserting *"ngspice in
batch mode writes nothing on a stop"* in ASE-L's voice — a **run-model fact about one
simulator**, sitting in the half D34–D37 say may hold none. The clause now comes from an
**optional** `run_stop_cost` backend hook:

| | |
|---|---|
| `ase::backend::ngspice::run_stop_cost` | CONTENT — `{before {…} after {…}}`, ngspice's facts about ngspice |
| `ase::run_stop_cost` | SCHEMA — resolves the hook, `{}` when absent |
| `ase::run_stop_warning` / `ase::run_stopped_msg` | SCHEMA — the two frames |

⚠ **A BACKEND THAT DECLARES NO HOOK GETS NO SENTENCE — there is no fallback text.** Core does
not know what a stop costs on a simulator it was never told about, and a *guessed* warning is
worse than silence. The hook is OPTIONAL, exactly like `capabilities` and `op_param_set`; row
**SW6** pins that registering a backend without it still succeeds.

**Placement, each for a reason already in the tree.** The launch note sits at the last instant
before `execute`, beside `ase::run_using_report` and after `ase::preflight_gate` — issue 1370's
repair, so that **a run that was refused is never told what stopping it would cost**. It is
**not** `ase::ui::set_status`, which sets a one-word coloured label. It is **not** a modal: row
RG13 drives `do_stop` headless and a modal would hang it. It is **not** on the strip button's
tip, where issue 1391 minted `stop` as exactly `[ase::ui::menu_path_stop]` and three rows hold
it there.

## Evidence

`tests/headless/test_ase_core.tcl` section **SW**, 8 rows, floor **258 → 266**.

⚠ **RG13 DOES NOT MOVE, AND THAT TURNED OUT TO BE THE FINDING.** The row asserts a successful
Stop's CIW line, and the first expectation written for this change *made it the new sentence* —
which failed. **MEASURED**: RG12/RG13's fixture runs with `simulator holdsim`, which is not a
registered backend, so ASE-L correctly says nothing. **The code was right and the test
expectation was wrong**; the silence there is the adapter scoping working, not the warning
failing. RG13 keeps `{}` with a comment saying so, and row **SW7** pins that `holdsim`
specifically yields nothing — so that emptiness can never again be mistaken for the feature
having quietly broken.

⚠ **A `catch` hid the first attempt's real cause for two rounds.** `catch {set stopmsg …}`
swallowed the failure, so the row read an empty CIW and gave no hint why. The measurement that
settled it was surfacing the error and then printing the resolved simulator — which is the same
lesson as this batch's correction C36: render it and look.

## What changes when Stage 6f lands

Sentence 1 becomes conditional — a checkpointed run says what it will lose and what the
checkpoints cost instead — and sentence 2 gains the salvaged-file case. **Same proc, same two
keys**, which is why the sentence ships now rather than waiting for salvage.

## The sentences are the user's

Both are **recommended shapes, not ratifications**. Filed as `owed.sh add rule 1404` and paid
with the ⚖ **R9** batch.
