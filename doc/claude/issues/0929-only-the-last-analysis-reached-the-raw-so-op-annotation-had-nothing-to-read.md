# 0929 — only the last analysis reached the raw, so `6` had nothing to read

**Status:** **FIXED 2026-08-29.** Reported by the user the same day, with their
action log. **This is the defect they had been hitting for days**; 0927 and 0928
were both upstream of it and neither would have made `6` work on their bench.

**Related:** 0617 (the feature), 0927 (default on), 0928 (cards riding the wrong
analysis)

---

## 1. What the user saw

`sky130_tests_ase/tb_bandgap`, ASE-L with **OP analysis enabled** and *Save
device OP parameters* ticked. From their `/tmp/Xschem.log.2`:

```
xschem netlist /home/analog/.xschem/simulations/tb_bandgap.spice
#= ASE: 468 device OP save card(s) added to the deck.
#= ase: simulation finished (exit 0), log: .../tb_bandgap_ase.log
...
#= No operating point results are loaded. These are from a 'tran' run instead,
   so there are no operating-point numbers to show.
#! ase: could not put the results from '.../tb_bandgap_ase.raw' onto the
   schematic ... it could not be read as a results file, or it holds no
   operating point
```

Everything upstream succeeded. The cards were emitted, the run exited 0, and the
answer was still no.

## 2. The cause, in one line of deck

Their generated `.control` block:

```
.control
op
tran 10n 200u
print VBG
...
remzerovec
write /home/analog/.xschem/simulations/tb_bandgap_ase.raw
.endc
```

**ngspice's `write` writes the CURRENT plot, and every analysis creates a new
one.** One `write` after the last analysis therefore stores the last analysis
and silently discards every earlier one. Confirmed on the artifact: the 144 MB
raw contains exactly one plot.

```
$ strings tb_bandgap_ase.raw | grep -E '^(Plotname|No\. Points)'
Plotname: Transient Analysis
No. Points: 20513
```

The operating point was computed and thrown away. The 468 device cards were
saved into the transient, where nothing reads them — 468 vectors × 20513
timepoints is most of that 144 MB.

**The code said so out loud.** The comment above the write read: *"emit an
explicit `write <raw_file path>` of the **CURRENT (= last analysis) plot**"*.
The behaviour was documented, deliberate, and wrong for any state with more than
one analysis enabled.

## 3. The fix

`set appendwrite` once, then `remzerovec` + `write` after **each** enabled
analysis, inside the analysis loop.

* `set appendwrite` makes each `write` **append** its plot to the file instead
  of truncating it (MEASURED, ngspice-46+: a repeated bare `write` to one path
  overwrites — the file ends up holding only the last plot).
* `remzerovec` is **per plot**, so one call at the end only ever cleaned the
  last analysis's. It is needed before every write for the reason it was
  introduced: `.options savecurrents` leaves zero-length `@m…[ib]`-class vectors
  and ngspice's write then aborts *silently*.
* **No reader change was needed.** `xschem raw read <file> op` already selects
  the operating-point plot out of a multi-plot raw and `… tran` selects the
  transient one — measured against this tree before the fix was written.

`ase::run_deck` now **deletes the raw before the run**, beside the existing
`cosim_clear_artifacts` call and for the same stated reason. With append
semantics this is mandatory: without it every run's plots pile onto the previous
run's and `6` annotates whichever stale operating point happens to come first.
It also restores a property the single-`write` deck had for free — a run that
dies before writing now leaves no raw, instead of serving the previous run's
numbers as though they were this one's.

## 4. Why a wall of green checks never saw it

**Every ASE row that renders or runs a deck uses an OP-ONLY state.** With one
analysis enabled, "write the last plot" and "write every plot" are the same
deck. The two-analysis case — the one every real bench uses — was rendered by no
test and run by none.

`test_wave_viewer` V1 came closest: it enables op **and** dc, and it asserted
*"exactly one write line"*. It was pinning the defect as the contract.

## 5. ⚠ AND THE FIRST VERSION OF THE NEW TEST WAS VACUOUS

Recorded because the mechanism is worth more than the fix. F21 was first written
to assert `xschem raw read $raw op` succeeded and that `xschem raw sim_type`
answered `op`. **It passed on a tree with the fix reverted.**

Two reasons, both worth knowing:

1. **`xschem raw read` does not report failure through its return code.** On a
   tran-only raw it prints `raw_read(): no useful data found` and returns 0.
2. **A failed read leaves the previously loaded raw in place.** F13–F17 earlier
   in the same file load an op raw, so `sim_type` kept answering `op` long after
   the read that was supposed to establish it had failed.

The row now leads with a term read off the **file** — the list of `Plotname:`
headers — which no reader state can fake, and clears the reader before each
read. Verified in both directions: on the reverted tree it reports
`{{Transient Analysis}}` and `NO-READ`, i.e. the user's exact symptom.

Item 1 is a latent defect in its own right and is **not fixed here**.

## 6. Acceptance

* **`test_ase_core` D6** — deck shape: `set appendwrite` once, then
  analysis/`remzerovec`/`write` per enabled analysis, **in that order**, with
  counts. Fails on the reverted tree.
* **`test_ase_final` F21** — the user's case end to end with real ngspice: op +
  tran in one deck, and the raw carries `Operating Point` **then** `Transient
  Analysis`; `6`'s own reader finds the operating-point plot (1 point); the
  device OP vectors are present. Fails on the reverted tree with
  `{{Transient Analysis}} NO-READ`.
* **`test_wave_viewer` V1** — retargeted from "exactly one write" to one write
  per enabled analysis plus the `appendwrite` line, on a fixture that already
  enabled two analyses.

Suites: `test_ase_core` 182, `test_ase_final` 80, `test_wave_viewer` 404,
`test_ase_window` 227, `test_ase_dialogs` 174, `test_ase_persist` 109,
`test_ase_cosim` 341, `test_ase_plot` 150, `test_ase_view` 36,
`test_ase_final_gf180` 34, `test_annot_blank_cause_0909` 27 — all pass.

## 7. Not fixed

The device OP cards still ride every analysis in the deck, so on an op+tran
bench they are sampled at every transient timepoint (measured: +8.6 s and
+242 MB for 3000 cards over 10068 points). 0928 stopped them being emitted when
**no** op analysis is enabled; scoping them to the op analysis when both are
enabled is a further change and needs a ruling.
