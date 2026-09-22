# 1498 — ASE-L's Outputs Value column never read the answers on disk, and Load State showed the previous state's numbers under the new state's names

**STAMP:** `v1 claim=fixed tree=6a0d1126 stamped=2026-09-21 fix=taken open=1 by=ase-l-ux-batch-item-3`

**Status: FIXED — filed and fixed 2026-09-21** by the ASE-L UX batch, stage F2 of
`doc/claude/ase_l_ux_batch/PLAN.md`, from `receipts/recon.md` §1 and `receipts/impl.md`.
**Class** silent wrong data (the Load State half) + a column that was blank for no reason
(the open half).
**Related, read first:** **0838** (`ase::results_stale` — a raw older than the deck it
claims to describe; the predicate this fix gates on, and the same silent-wrong-data class),
**1429** (the `result_probe` dispatcher and its two readers), **1461** (`::open`/`::close`
inside `ase::ui`).

---

## The defect, in two halves

### Half 1 — the column the window exists to show was blank

`ase::ui::run_finished`'s `ec == 0` arm was the **only** writer of the `results` session
attr. So the Outputs Value column could only ever display a run **this process** made:
close xschem, reopen yesterday's bench, and the column is empty although the numbers are
sitting in the run directory.

Measured 2026-09-21 on a fixture whose raw holds `v(vbg) = 1.177085`:

```
ase::has_results                       = 1      <- already says yes
result_probe_raw off that same state   = {VBG 1.177085e+00}
the Value cell                         = {}     <- blank
writers of the `results` session attr  = 1      (run_finished, ec == 0)
```

### Half 2 — and the blank cell was the harmless one

`ase::ui::load_state_commit` calls `ase::session_update`, which replaces the `state`
sub-key of the session entry. **`results` is a SIBLING sub-key and survived untouched.**
Measured on the same fixture, with a session showing `10` and a loaded state whose own raw
holds `0.812345`:

```
results attr AFTER load_state_commit        = {VBG 9.999999e+00}
VALUE CELL after loading a DIFFERENT state  = {10}
```

**In a corner sweep, where states share output names by construction, that is the previous
corner's answer read as this corner's, with nothing on screen to say so.** The plan
asserted this from reading; the recon crew measured it.

## The fix (`ase::ui::results_from_disk` / `results_refill`, `ase::quiet`)

* **`ase::ui::results_from_disk $key`** (`src/ase_window.tcl`, beside
  `refresh_output_values`) returns what this session's rundir says, or `{}`. It gates on
  `ase::has_results`, **not** on file existence — so a raw older than its deck is refused
  by 0838's predicate and a number that reaches the column is current by construction.
  That is why **no "stale result" marker is needed**, which was the plan's only candidate
  ruling for this stage; it has lapsed rather than been decided.
* It calls the **registered `result_probe` hook**, not the ngspice-internal readers beside
  it. The partition it computes decides only whether the LOG has to be read at all (a
  simulation log can be tens of megabytes and this runs on every window open); the hook
  re-partitions and owns the rule.
* **`ase::ui::results_refill $key`** writes the attr and repaints. It **overwrites**; it
  never merges. That is the whole of half 2: a state whose rundir holds nothing CLEARS the
  column.
* Two call sites: `ase::ui::open` (between `build` and `populate`, so the first paint
  carries the numbers) and `ase::ui::load_state_commit` (on the success arm only).
* **`ase::quiet {script}`** (`src/ase.tcl`, beside `ase::echo`) mutes `ase::echo` for the
  duration of a script, by a **counter** restored on the error path too. The result
  readers narrate the run they are reading — *"the results file holds no single-point value
  for v(nosuch)"*, *"this run: 1 from the file, 0 from the log"* — and on a window **open**
  nothing ran, so every one of those sentences would describe a run that did not happen,
  again on every Load State. The numbers are still read; only the narration is dropped.
  **This is what keeps the change invisible except for the numbers, and therefore off the
  ruling queue.**

## Pinned by

`tests/headless/test_ase_window.tcl`, 15 headless rows `RD1498a`–`RD1498i` and 5 GUI rows
`UX1498a`–`UX1498d`. Sabotaged and red by name: the reader neutered → 7 rows including
`RD1498a` and `UX1498a`; the refill dropped from `load_state_commit` → `UX1498c`/`UX1498d`;
`ase::quiet` neutered → `RD1498g`/`h`/`h3`.

`W1p id output row Value blank pre-run` is **unmoved and still green**: its fixture rundir
holds no raw, so `has_results` answers 0 and the cell stays blank. ⚠ If a future leg ever
leaves a raw where the `W1` fixture can see it, that row turns red **for a good reason**.

## Still open (1)

**⚖ R-U2 — should `Results > Select` repoint the Value column at the selected run?**
`PLAN.md` F2 says it should: *"`Results > Select` repoints the column at another run's
numbers without re-running — which is what that menu item means in ADE-L."* It was
**deliberately not implemented**, because it is the user's call and the safe default is the
conservative one:

* `ase::ui::rsel_commit` selects an **arbitrary** raw file for the waveform viewer;
  `result_probe_raw` reads the **session's own** `raw_file` and cannot be pointed
  elsewhere without a new argument;
* `ase::has_results` / `ase::results_stale` can only vouch for the session's own raw
  against the session's own deck. Feeding the Value column from a file selected by hand
  **bypasses 0838's guard** — which is the exact defect class this issue is about.

So the question is genuinely the user's: *when you pick another run's results file to look
at in the waveform viewer, should the numbers in the Outputs pane change to that file's
too — knowing that ASE-L cannot then tell you whether those numbers describe the deck you
are looking at?* Not answered here, not assumed.
