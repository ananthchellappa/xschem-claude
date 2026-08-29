# 0917 — answering always from the top of the hierarchy moves the 0911 defect
#         into the standalone-block workflow, where nothing refuses and nothing warns

STATUS: OPEN — and it needs a USER RULING, not just a fix (see §3).
FOUND BY: the adversary/guard-coverage pass on item B2, 2026-08-28, against the
          delivered tree — i.e. this is a cost of 0911's fix, not a pre-existing
          defect.
SEEN BY: NOTHING. Every suite in the annotation tier list and all 44 blocks of
         `tests/run_regression.tcl` are green with the behaviour below live.
RELATED: [0911](0911-on-a-descended-sheet-with-no-ase-l-session-the-chord-never-repairs.md)
         (the fix that caused this), [0918](0918-alt-shift-6-changed-direction-on-a-descended-sheet-when-0911-was-fixed.md)
         (the same two lines moved the transient chord too), 0908, 0910, 0912.

---

## 1. What the user does, and what they get

Issue 0911's fix makes the operating-point results file always resolve from the
**top of the hierarchy stack**. On a bench whose `netlist_dir` holds the chip's
results file **as well as** the block's, that turns 0911's own symptom loose one
workflow over — and this time there is no refusal to warn anybody. The sheet
simply shows the wrong run, for ever.

MEASURED on the delivered tree. `netlist_dir` holds `top.raw` (an older chip
run, `id = 10u`) and `sub.raw` (the block run the user just did, `id = 9m`,
written 1.1 s later). The user descends into `x1` and presses `6`, then re-runs
the block (`sub.raw` becomes `id = 3m`) and presses `6` again.

| press | BEFORE 0911's fix | AFTER 0911's fix (ships today) |
|---|---|---|
| 1 | `id = 9m \| gm = 7m \| gds = 50u`, "Loaded results from …/sub.raw." | `id = 10u \| gm = 100u \| gds = 1u`, "Loaded results from …/top.raw." |
| 2 | same numbers, "These results were already loaded." | same numbers, "These results were already loaded." |
| 3, after the re-run | `id = 3m \| gm = 2m \| gds = 20u`, "Loaded results from …/sub.raw." | `id = 10u \| gm = 100u \| gds = 1u`, **"These results were already loaded."** |

That last cell is the **exact sentence and the exact shape** issue 0911 was filed
about: a re-run that never appears, under "These results were already loaded",
with no path named on the repeat presses so the user cannot even tell which file
won. It is driver ruling **0900** failing again — the press re-consults `top.raw`
for ever and never looks at the file the user's run actually wrote — and
invariant **I3** (never the previous run's number) with it.

## 2. Why the mechanism makes this certain, not merely likely

`cadence::_annot_raw_candidate`'s `netlist_dir` arm **never consults the disk**.
It composes `$netlist_dir/<cell>.raw` from a name and returns it. Since issue
0911 that name is `[xschem get schname 0]`, the top of the stack, unconditionally.
So on a descended sheet the candidate is `top.raw` *whether or not `top.raw`
exists and whether or not `sub.raw` does*, the freshness stamp in
`op_annot::db_current` tracks `top.raw` from the first press onward, and the file
the user's own run wrote is never looked at again.

The refusal case — `top.raw` absent — is the one row **H13** of
`tests/headless/test_annot_hier_0911.tcl` already pins, and it is the *loud* half:
the user at least gets a sentence. The case above is the *silent* half, and
nothing in the tree measures it.

## 3. Why the existing rule debt does NOT cover it

Rule debt **[0911]** offers the user two options:

* **A** (shipped): the top of the hierarchy stack, always.
* **B**: the top first, the standing sheet as a fallback **when the top's results
  file is absent**.

§1's input has the top's file **present**, so option B answers `top.raw` too. The
user is being asked to rule on a two-item menu that **does not contain a fix for
the worse half of the cost**. At least one more option belongs on it:

* **C** — prefer whichever of the two candidate files is **newer**, so the run the
  user just did wins whichever sheet they are standing on. Cost: the answer
  depends on what is on disk, and two clocks (file mtime vs. the freshness stamp)
  now decide one thing.
* **D** — keep A for the operating-point chord and let the transient chord fall
  back to the standing sheet, on the reading that the two surfaces have different
  failure costs. This is really a ruling on **0918** as well; answer them together.
* **E** — keep A, and make the "already loaded" sentence **name the file** on every
  press, so the silent half at least becomes visible. Does not fix the wrong-file
  answer; does remove the "cannot even tell which file won" half. Note issue
  **0907** already asks for that sentence to name its file, for a different reason.

## 4. What would close it

Two things, and the row is the cheap half:

1. **A running row** staging §1 exactly — chip raw present, fresh block raw,
   descend, press `6`, re-run the block, press `6` — so the SILENT form of the
   H13 cost is pinned the way the refusal form already is. It belongs next to
   H13 in `tests/headless/test_annot_hier_0911.tcl`; the fixture machinery it
   needs (`h_nd`, `h_mkop`, `h_press`, the top/sub hierarchy) is all already
   there.
2. **The user's ruling** on the A/B/C/D/E menu above, which is what decides what
   that row golds. Do not build the row first: it would pin whichever answer the
   builder happened to prefer, which is how H13 came to pin option A.
