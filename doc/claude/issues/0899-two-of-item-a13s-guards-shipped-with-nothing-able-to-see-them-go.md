# 0899 — two of item A13's guards shipped with nothing able to see them go

Status: FIXED 2026-08-28 (A13 repair) — tests and attributions only, no behaviour changed
Filed: 2026-08-28, by the A13 sabotage pass
Class: test coverage (0894's shape, one item later)
Subject: `utils/annot_mode.tcl`, `cadence::_annot_viewer_db`

Item A13 split the waveform consult's answer into four named cases. Twelve
guards came out of that split. A real in-place sabotage pass — each guard
deleted on its own, every suite re-run, the file restored and the baseline
re-asserted between guards — found ten of them witnessed and **two invisible**.

## Guard 1 — "the waveform window is not showing a transient"

```tcl
if {$path eq {}} { return {} }        ## annot_mode.tcl:1197
```

Deleting this line reds **nothing, anywhere**: `test_op_annot` 460/460
headless and 467/467 on the dev display, `test_annot_show_menu` 34/34,
`test_results_freshness` 21/21, `test_zero_point_raw_0836` 73/73,
`test_backannotate_digital` 84/84, `test_wave_cursor_crossdb` 93/93.

It is not dead code. Before A13 the line read
`if {$path eq {} || ![file exists $path]} { return {} }`, where the
`$path eq {}` half was redundant (`file exists {}` is already false). After
the split it is the only thing keeping a waveform window that holds *nothing*
— or holds an operating point rather than a transient — out of the `filegone`
arm. Measured end to end, guard deleted, with a good five-point transient
sitting readable at the preferences path:

```
consult = {{} {} filegone}
supply  = {-1 viewergone {}}
raw loaded = -1, annotation mask 0, sheet bare
message = "The waveform window is showing the results file , but that file is
           no longer on disk, so nothing was placed on the schematic. ..."
```

A refusal that **names no file**, about a file that was never named, on a
session whose results were on disk and readable. Shipped, the same session
answers `ok` and paints `d 3 g 0.9`. That is the wrong-reason defect class
issue 0895 exists about, one guard along, with nothing able to see it go.

The spec and the code comment both attribute the witness to **row V37**:
`doc/claude/specs/op_annotation.md` says the bare `{}` "is what row V37 depends
on to keep reaching `noraw`", and `annot_mode.tcl:1174-1178` says the same.
V37's fixture has no waveform window at all, so it exits at the session and
window guards higher up and never reaches line 1197. The attribution is wrong
in both places.

**Fix:** a leg on row V63 standing up a viewer that holds nothing — the consult
must answer a bare `{}` (llength 0) and `cadence::annot_tran` must still reach
the file on disk and paint. Then correct the V37 attribution in the spec and in
the comment.

## Guard 2 — `filegone` is tested before `nopoints`

```tcl
if {![file exists $path]} { return [list $path $print filegone] }   ## :1198
if {![llength $print]}    { return [list $path $print nopoints] }   ## :1199
```

`annot_mode.tcl:1193-1196` carries a boxed warning that this order is
deliberate and closes "Rows V62 and V63 pin the classification". They pin the
spellings and the per-case mapping. They do not pin the **order**. Swapping the
two lines reds nothing on either arm in either suite (460/460, 467/467, 34/34).

The user-visible difference is small but real: a run the viewer attached at zero
points whose file the simulator then unlinks would be told "the run has not
produced any values yet" instead of "that file is no longer on disk". Both
sentences end in wait-and-retry, so severity is low — but the comment overstates
its coverage, which is the part worth fixing either way.

**Fix:** either a V63 leg for the both-true case, or soften the comment to say
what is actually pinned.

## What was checked and is fine

The other ten guards each have a witness, verified by deleting them one at a
time: the two classification arms (V62, V63, V53 leg 6, V60, V61, B12i, B12h),
both supplier refusals (V60/V61/B12i and V58/V59/B12h), both `$vseen` re-gates
(V62 legs 5 and 6, structural only and by design), the supplier's
return-before-hand-off ordering (V62 leg 9 structurally **and** V58's
`raw loaded` leg behaviourally), the `viewerfilling` dispatch arm (V52, V58,
V59), both new sentences (V42d, V43, V60/V58) and the runner registration of
the menu suite (V57 leg 7).

One mis-attribution, recorded so the sabotage plan is not repeated verbatim: the
plan predicted that moving the `viewergone` arm below `set attached 1` inside
`cadence::annot_tran` would red V62 leg 5. It does not — that leg slices
`cadence::_annot_tran_supply` and cannot see `annot_tran`'s dispatch order at
all. The variant is still caught, by V60, V61 and B12i, because the `noraw`
branch above swallows the moved arm; and `xschem raw loaded` stays `{0 -1}`
throughout, so nothing was left attached and no unwind was owed.


---

## FIXED 2026-08-28 — both guards reproduced, then witnessed

Both findings were reproduced first, on the restored tree, before anything was
written: deleting `annot_mode.tcl:1197` left `test_op_annot` at
`RESULT: ALL PASS (460 checks)`, and swapping :1198 with :1199 did the same. The
verifier was right on both counts.

**No product code was changed.** Both guards are correct as shipped; what was
missing was rows able to see them go, plus a wrong attribution that hid the
first one. `utils/annot_mode.tcl`'s only edit is comment text.

### Guard 1 — now four legs across two rows

* **V63 leg e** — a waveform window that IS in play and holds **nothing**. The
  fixture proves its own honesty: `$::opa_v_vw_ok` must read 0, so a fixture
  that quietly attached a file cannot pass by accident. The consult must answer
  a bare `{}`.
* **V63 leg f** — a waveform window showing a **DC operating point**. The
  viewer's own `sim_type` is recorded inside `opa_v_viewer`, where the read
  happens; a probe written in the script body would have asked the design
  window and answered for the sheet.
* **V64** — the same two faces asked of the **schematic**: with a good results
  file at the preferences path the chord must answer `ok`, paint
  `d 21 g 0.1 0 0.0 0 0.0`, and show *"Showing each node's voltage at 3 ns,
  where cursor B is on the waveform."* Deleting the guard reddens both faces
  with the file-less refusal quoted above, measured.

`opa_v_viewer` gained an optional third argument (`analysis`, default `tran`)
so a viewer can be stood up holding something this mode must not use. Every
existing caller reads unchanged.

### Guard 2 — now two rows, and it is a behavioural claim after all

* **V63 leg g** — a run with **no points yet whose file is then unlinked**, so
  both classification tests are true at once. The consult must answer
  `filegone`. This is the fixture nothing in the tree produced.
* **V65** — the same situation asked of the schematic: state `viewergone`, the
  deleted-file sentence in the CIW and on the status line, mask 0, sheet bare,
  and an inequality leg naming the *"has not produced any values yet"* sentence
  as the one that must not appear.

Swapping the two lines now reddens V63 and V65 on both arms.

### Attributions corrected

`doc/claude/specs/op_annotation.md` and the boxed comment in
`cadence::_annot_viewer_db` both said row **V37** depended on the bare `{}`.
Both now say what actually holds each guard, and the comment says out loud why
the empty-path line is a guard rather than a tidy-up, so the next reader does
not delete it as redundant.

### Counts

`test_op_annot` 460 → **462** headless, 467 → **469** on the dev display; V63
grew three legs inside its existing check. Everything else in the tier list is
unchanged.
