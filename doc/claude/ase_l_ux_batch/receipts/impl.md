# Implementation — Stage 3, F1, F2 against today's tree

**Crew:** IMPLEMENTER. **Tree:** `fluid-editing` @ `6a0d1126`, working tree **uncommitted**.
**Date:** 2026-09-21. **Input:** `receipts/recon.md`.
**Binary:** `make -C src` → `Nothing to be done for 'all'` before any measurement, so
`src/xschem` (1 688 152 bytes, 22:50:07) *is* this tree.
**Scratch:** `/var/tmp/xsr_ux/i1` (18 characters), peak **5 484 KiB** on disk / 5 224 KiB
apparent, deleted at the end.
**Isolation:** every probe and every suite ran with `HOME=/var/tmp/xsr_ux/i1/h` or a
driver-armed throwaway, on a **private Xvfb `:235`** with openbox 3.6.1, stopped at the
end. `~/.xschem` still carries its 09-17 mtimes; **`:99` was never touched** and is still
up; `~/.claude` was never written (see §7); no simulation was run on any bench under
`sky130A/`; no commit.

Code is cited **by proc name**. The plan's coordinates have all rotted and these will too.

---

## 1. What landed, and what did not

| stage | recon said | what I did |
|---|---|---|
| **F2** the Value column reads the answers | GO, highest value | **LANDED** — issue **1498** |
| **3 (ii)** log window hscroll | GO | **LANDED** — issue **1499** |
| **3 (i)** tooltip on clipped cells | GO | **LANDED** — issue **1499** |
| **3 (i)** visible `…` | HOLD, ⚖ R-U1 | **NOT TOUCHED.** Question written into issue 1499 in full, with three options and a recommendation |
| **3 (iii)** per-pane hscroll | NO-GO, already shipped, unpinned | **no code**; **retro-pinned** by three rows, which is also what protects the rename below |
| **F1** one producer | NO-GO, already delivered | **no code**; closed on the ledger |

**A second ruling was raised by the work and is also not assumed: ⚖ R-U2** — should
`Results > Select` repoint the Value column at the selected run? `PLAN.md` F2 says it
should. It is the user's call and the safe default is the conservative one, because
`result_probe_raw` reads the **session's own** raw and `ase::has_results` can only vouch
for that one against that one deck: feeding the column from a hand-picked file **bypasses
issue 0838's guard**, which is the exact defect class F2 exists to close. Stated in full in
issue 1498 §"Still open".

⚠ **Neither ruling is in `owed.sh`.** The brief forbids this crew to write `~/.claude`
state. **The driver owes two `owed.sh add rule` entries** — `add rule 1499` (R-U1) and
`add rule 1498` (R-U2). Both issue files resolve, so the pointer-style `add rule <id>` will
find them.

## 2. The measurements, before and after

Same fixture both times: a scratch library, a session whose rundir holds a raw carrying
`v(vbg) = 1.177085`, a second rundir whose raw carries `0.812345`, a third with none, and a
vars pane holding the audit's own Monte Carlo string. Measured at **`ase_font_size 12`**,
the user's real setting (`2f1fad58`), not the bare default — the recon crew's correction.

| | before | after |
|---|---|---|
| `ase::has_results` | 1 | 1 |
| `result_probe_raw` off that state | `{VBG 1.177085e+00 START 1.803088e+00}` | unchanged |
| **Value cell on window open** | **`{}`** | **`1.177`** / `1.803` |
| `results` attr on open | `{}` | `{VBG 1.177085e+00 START 1.803088e+00}` |
| **Value cell after loading a DIFFERENT state** | **`10`** — the *previous* state's number | **`812.3m`** — the loaded state's own |
| Value cell after loading a state with **no** raw | the last one, still standing | `{}` |
| notices reaching the notice sink during an open | the readers' run-time narration | **0** |
| `<Motion>`/`<Leave>` on the three panes | **none** | armed, all three |
| `<Motion>`/`<Leave>` on `status.state` / the Simulators table | **none** | armed |
| vars Value column | 143 px, ink 244 px, **CLIPPED** | unchanged — and hovering resolves the whole string |
| a status segment squeezed to 72 px of its 188 px of text | nothing | the whole string |
| log window children | `.sb .t` | `.hsb .sb .t` |
| log `-xscrollcommand` | `{}` | `ase::ui::hscroll_autohide <lw>` |
| log `.t` geometry manager | `pack` | `grid` (so `grid remove` can hide the bar) |
| log hsb after a 137-char line | — | mapped; `xview` `0.0 0.615` |
| log `-wrap` / `-width` | `none` / `84` | **unchanged, deliberately** |

## 3. What I built, by name

**`src/ase.tcl`** (+43): `ase::quiet {script}`, `ase::quiet_depth`, and a mute check as the
first two lines of `ase::echo`.

**`src/ase_window.tcl`** (+291/−7):

* `ase::ui::results_from_disk $key` — the reader. Gated on `ase::has_results` (0838), calls
  the **registered `result_probe` hook** rather than the ngspice-internal readers, reads the
  log **only** when a row needs it, and runs inside `ase::quiet`.
* `ase::ui::results_refill $key` — writes the attr and repaints. **Overwrites, never
  merges**; that is the whole of the Load State half.
* Call sites: `ase::ui::open` (between `build` and `populate`) and
  `ase::ui::load_state_commit` (success arm only).
* `ase::ui::cell_font`, `cell_tip_text`, `label_tip_text`, `tip_text`, `tip_motion`,
  `tip_show`, `tip_cancel`, `tip_attach`, and `variable ase::ui::cellpad 6`.
* `ase::ui::pane_hscroll` → **`ase::ui::hscroll_autohide`**, now wired by both `build_pane`
  and `log_open`.
* `ase::ui::log_open` — `$lw.hsb`, `-xscrollcommand`, pack → grid.
* `tip_attach` at four sites: `build_pane` (×3 panes), `simulators_dialog`, and the status
  bar's `sim` and `state` segments.

### Three decisions that were mine, stated rather than queued

1. **The on-open read is SILENT.** The result readers narrate the run they are reading; on
   an open nothing ran, so those sentences would describe a run that did not happen, on
   every open and every Load State. Saying nothing is what today's code already does, so
   silence is the choice that adds no user-visible text — and therefore the one that keeps
   this off the ruling queue. `ase::quiet` is a **counter**, restored on the error path, and
   mutes `ase::echo` only; the error itself propagates with its stack (row `RD1498h2`).
2. **One producer for both horizontal bars**, hence the rename. A lying name is a real cost
   in this file, and nothing referenced `pane_hscroll` outside `build_pane`. The retro-pin
   rows are what make the rename safe from here.
3. **`-width 84` and `-wrap none` stay.** The plan asked for a font-derived width "worth
   ~115 columns in the same pixels"; 1398 spent that arithmetic, and re-deriving now makes
   the window **wider** — the direction `2f1fad58` exists to correct.

## 4. Suites — 15 headless rows, 23 GUI rows

⚠ **THIS HEADING SAID "22 GUI rows" AND THE `UX1499a` LINE BELOW SAID "11 checks", AND
BOTH WERE WRONG** (found by `receipts/verify.md` N1, corrected in the fix round of
2026-09-21). Counted off the diff rather than by hand: `UX1499a`, `a2`…`a10` is **10**
rows, not 11, and the GUI total is **23**, not 22, because the breakdown omitted the
`UX open_state -> 1` fixture anchor. The grand total was always right — 295 + 15 + 23 =
333 — which is exactly why the slip survived: **the sum checked out while two of its
terms did not.** The corrected figures are inline below.

⚠ **AND THE FIX ROUND ADDED THREE MORE**, so the numbers in this section are the
*delivered* state, not today's tree. Today: `UX1499a` is **13** rows (`a9b`, `a9c`, `a11`),
the GUI total is **26**, the new-check total is **41**, and the suite runs **336** GUI /
**71** `--nogui`. Read `receipts/verify.md` §"Fix round" for what moved and why.

`tests/headless/test_ase_window.tcl` (+421):

* **`RD1498a`–`RD1498i`** (15 checks, **headless**, next to the P-block): the reader answers
  a session whose rundir holds a raw; a row the file cannot answer gets no value; the 0838
  gate refuses a raw older than its deck **and reads it again once the deck is gone**; no
  raw → `{}`; `results_refill` **clears** a planted attr and lands the new rundir's answer;
  reading says **nothing** to the user **while still reading the numbers**; the mute
  survives a raise, nests, and restores; an unknown key answers rather than raises.
* **`UX1498a`–`UX1498d`** (5 checks, GUI): the column is filled on open; the planted stale
  number really is on screen first (the anti-vacuity anchor); Load State replaces it; a
  state with no raw clears it.
* **`UX1499a`–`UX1499a10`** (**10** checks, GUI; **13** after the fix round): all three panes armed; the fixture really is
  clipped; hovering a cut cell resolves the whole string; the `<Motion>` handler agrees with
  the resolver; **a cell that fits gets nothing**; a heading is not a cell; **the gate is
  pixels, not characters**; a status segment that fits offers nothing and a squeezed one
  offers everything; the Simulators table is armed.
* **`UX1499b1`–`UX1499b5`** (5 checks, GUI): the bar exists, is horizontal, drives
  `$lw.t xview`, is wired through the shared producer; `.t`/`.sb` paths and the pack→grid
  move; `-wrap none` / `-width 84` untouched; unmapped on a short line, mapped on a long one.
* **`UX1499c1`–`UX1499c2`** (2 checks, GUI, **retro-pin**): all three panes carry a bar on
  the same producer, and the auto-hide contract driven at the callback.

**Counts:** `test_ase_window` **ALL PASS (333)**, floor **295 → 333**; `--nogui` **56 → 71**.

⚠ **Row `UX1499a7` is the one worth reading.** The obvious way to prove "the gate is pixels"
is to drag a column — and it **cannot work here**: the vars `value` column is `-stretch 1`,
so ttk puts a widened column straight back on the next update, and `-minwidth` (1398's
heading-ink floor) stops a narrowed one at ~50 px. Both directions pass vacuously. The row
instead uses a pair that **no character rule can get right**: 20 characters of wide ink owe
a tip, 22 characters of narrow ink do not. Two earlier drafts of this row passed for the
wrong reason and were caught by running them.

## 5. Sabotage — seven, each red by name, each restored by `cp` and md5-verified

No `git checkout`, `restore`, `stash` or `clean` at any point.

| sabotage | result | rows red |
|---|---|---|
| `results_from_disk` → `{}` | 7 FAILED (326 passed) | `RD1498a` `RD1498c2` `RD1498f2` `RD1498g2` `UX1498a` `UX1498a2` `UX1498c` |
| `load_state_commit` → no refill | 2 FAILED (331) | `UX1498c` `UX1498d` |
| `ase::quiet` → no mute | 3 FAILED (68) *(nogui arm)* | `RD1498g` `RD1498h` `RD1498h3` |
| clip gate → always true | 2 FAILED (331) | `UX1499a5` `UX1499a7` |
| `tip_attach` → no-op | 2 FAILED (331) | `UX1499a` `UX1499a10` |
| log `-xscrollcommand` dropped | 2 FAILED (331) | `UX1499b2` `UX1499b5` |
| pane `-xscrollcommand` dropped | 1 FAILED (332) | `UX1499c1` |
| **restored** | **ALL PASS (333)** | md5 of all three files back to the pristine values |

## 6. Neighbouring suites

All on `:235`, openbox 3.6.1, throwaway `HOME`:

```
test_ase_window          ALL PASS (333)   test_ase_core        ALL PASS (675)
test_ase_interact        ALL PASS  (64)   test_ase_persist     ALL PASS (153)
test_ase_final           ALL PASS  (82)   test_ase_launch      ALL PASS  (44)
test_ase_plot            ALL PASS (151)   test_ase_savestate_adopt ALL PASS (27)
test_ase_view            ALL PASS  (36)   test_ase_simdlg_0937 ALL PASS  (55)
test_ase_simreg_0931     ALL PASS (118)   test_ase_simcaps_0948 ALL PASS (211)
test_ase_simchoice_1395  ALL PASS  (31)   test_ase_simwin_variant_1471 ALL PASS (21)
test_op_annot            ALL PASS (492)
test_ase_dialogs         7 FAILED (382 passed)   <- PRE-EXISTING, PROVED (on THIS display)
```

⚠ **`test_ase_dialogs` was proved pre-existing, not assumed.** `src/ase.tcl` and
`src/ase_window.tcl` were replaced with `git show HEAD:` copies and the suite re-run on the
same display: **the identical rows, the identical values, the identical passed count.**
The rows seen here are `G2sens`, `G2f`, `G8c` ×2, `GG3`, `GG9`, `GN1b` — analysis-form focus
and simulator-adapter rows, none of them touching anything this item changed. The two source
files were then restored from the pristine copies and md5-verified. **Not filed as an
issue** (it is an environment-shaped red on a bare private display, and filing a number for
it without diagnosing it would be a fifth copy of somebody else's defect) — but it is
flagged here so the driver's own T1/audit does not read it as new.

⚠ **THE COUNT IS DISPLAY-DEPENDENT AND IS NOT A GATE BASELINE. THIS SENTENCE ORIGINALLY
SAID "THE IDENTICAL SEVEN ROWS", WHICH READ AS A FIXED FACT AND IS NOT ONE.** Three
independent runs on three private Xvfb displays, all openbox 3.6.1, all against `6a0d1126`
sources:

| display | verdict | rows |
|---|---|---|
| `:235` (implementer) | 7 FAILED (382 passed) | `G2sens` `G2f` `G8c` ×2 `GG3` `GG9` `GN1b` |
| `:241` (verifier) | **4** FAILED (385 passed) | `G2sens` `GG3` `GG9` `GN1b` |
| `:251` (fix round) | **4** FAILED (385 passed) | `G2sens` `GG3` `GG9` `GN1b` |

The suite total is **389** on all three; the four are a strict subset of the seven, and the
three extra are focus-dependent (`G2f`, `G8c` ×2). **So what this suite is, stated the way
it should be used:** an environment-shaped red of **4 to 7** rows out of 389, pre-existing
at `6a0d1126`, proved three times by swapping both changed sources to `git show HEAD:`
copies and re-running on the same display — **the same rows, the same counts, every time.**
Quote the *proof method*, never the number: a later crew that takes 7/382 as a baseline and
measures 4/385 will read a spurious four-row improvement, and one that takes 4/385 and
measures 7/382 will read a spurious regression. Neither would be real.

**T1 was NOT run**, per the brief: the driver gates, solo.

## 7. Batch record repaired

1. **`README.md`** — the *"Nothing here has been implemented. `src/` is untouched"* line is
   replaced by a status table naming the three shipped items and their commits, the
   `git diff --stat` that refutes it, and a warning that `PLAN.md` is stale and must be read
   as a claim. The *"Not filed yet, deliberately"* section, which still said the next free
   number was 1396, now records what was actually minted and names **R-U1** and **R-U2** as
   the two rulings the driver owes to `owed.sh`.
2. **`LEDGER.md` item 2** — given its commit hash `4ddc4900`, a `status: DONE`, and its
   ledger line (rules 1398/1399).
3. **`LEDGER.md`** — a new row of its own for **`2f1fad58`**, which had none and therefore
   read as an orphan. It is not an orphan: it is item 2's consequence, it is the only
   recorded **user reaction** to anything this batch has shipped, and it is why ASE-L must
   be measured at `ase_font_size 12`.
4. **`LEDGER.md`** — a new block for **Item 3 + F2** carrying everything in §1–§6 above.
5. **`doc/claude/issues/NUMBERING.md`** — 1498 and 1499 recorded with their one-paragraph
   summaries; the pointer moved to **1600**, because 1499 is the last number below the
   op-wcard reserved band `1500–1599`. Both numbers were verified free first, in both
   clones, with the band check: the only hits were the band table and its example line.
6. **`tclsh tests/headless/issue_stamp.tcl`** → `ok (0 problems)`, self-test 180 parser
   cases, both new files stamped against `tree=6a0d1126`.

**Not done, and deliberately:** nothing was written to `~/.claude` (no `owed.sh add`), and
nothing was committed.

## 8. Two things the next crew should know

* **`library_new_view` refuses a state view whose type has no `_state` in it.**
  `view_exts_of_type` matches `*_state*`, so `ngspice_rd1498` raises `unknown view type`
  — and because the fixture block sits inside `test_ase_window.tcl`'s outer `catch`, that
  raise cost **the entire W block and the D1398 block**, reporting `40 passed` where the
  suite runs 333. A fixture error in that file does not look like a fixture error.
* **The user's `~/.xschem/simulations` is still one global rundir for every state of every
  cell** (`ase::rundir` with an empty `rundir` key), which is the mechanism behind this
  batch's own 13:38 incident. Everything here used explicit scratch rundirs. `PLAN.md`
  stage F5 is the fix and is still unbuilt.
