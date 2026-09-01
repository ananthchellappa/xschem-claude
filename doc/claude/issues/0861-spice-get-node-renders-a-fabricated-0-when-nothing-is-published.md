# 0861 - a `@spice_get_node` text renders a fabricated `0` when nothing has been published

**Status:** **FIXED 2026-08-29** by crew item **B3**, on branch `annotate`.
Two C guards and one comment reconcile; the new suite
`tests/headless/test_spice_get_node_0861.tcl` (23 checks) pins all six
acceptance rows and is registered in `full_audit.sh` and `run_regression.tcl`.
Landing notes are at the foot of this file. Originally filed 2026-08-27 by the write-up pass
of the [0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md)
landing. The hole is **PRE-EXISTING** — it is reachable today on a plain
`xschem raw read` and predates the gate — but the 0856 landing **routes the
ordinary menu flow into it**, so it went from a corner case to the thing a user
sees after **Simulation > Graphs > Annotate Operating Point** on a transient.
Same class as RULING **D5-1**.

## What the user sees

A schematic carrying a `@spice_get_node` text — a probe symbol, or the shipped
`xschem_library/devices/scope_ammeter.sym` — reads **`0`** where it should read
nothing at all. On a scope ammeter that is **zero amps through the branch**,
which is a plausible-looking measurement and is a number the database does not
contain.

## The measurement

Fixture: `probe.sym` carrying `T {VDNODE=@spice_get_node v(d) }` (the pattern
`src/token.c:4443` documents verbatim), one instance on a sheet, and a 3-point
database whose `v(d)` is 1.8 / 1.9 / 2.0. Rendered text, measured on the landed
binary 2026-08-27:

    A nothing-loaded : loaded=-1  annot=-1 0 -1  text=VDNODE=-
    B TRAN attached  : sim=tran   annot=-1 0 -1  text=VDNODE=0     <-- FABRICATED
    C OP   attached  : sim=dc     annot=0 0 -1   text=VDNODE=1.8

**Causation is proven, not inferred.** B and C are the SAME three data points;
the only difference is the `Plotname:` line. And the codebase's own correct
answer already exists two lines away — with nothing loaded the identical text
renders `-`.

**The hole is older than the gate.** A plain `raw read`, which never calls
`update_op()` at all, has always left `annot_p` at -1 with a database attached:

    PRE-EXISTING raw-read tran : annot=-1 0 -1  text=VDNODE=0
    PRE-EXISTING raw-read op   : annot=-1 0 -1  text=VDNODE=0

So this is not a defect the 0856 gate created. It is a defect the 0856 gate made
**reachable from the menu**: before it, Annotate-OP-on-a-transient set
`annot_p = 0` and this text showed the t=0 sample (measured, mislabeled); after
it, `annot_p` stays -1 and the text shows a calloc zero (measured for nothing).

## Root cause, one line

`spice_get_node()`, `src/token.c:4483`:

```c
    idx = get_raw_index(node, NULL);
    if(idx >= 0) {
      val = xctx->raw->cursor_b_val[idx];
    }
```

No `annot_p >= 0` term, no `live_cursor2_backannotate` term, no
`sch_waves_loaded()` term. It is the **one** `cursor_b_val[` read in `token.c`
that stands outside the guarded `live_cursor2` family — six siblings guard at
`token.c:4349, 4838, 4930, 5016, 5111, 5184`; this one does not.

`update_op()` returns at `src/save.c:2240` **before** `annot_p = 0` (`:2246`) and
before the fill loop `cursor_b_val[i] = values[i][p]` (`:2251`), so the array
keeps its `my_calloc` zeros and this reader publishes them.

## A comment being committed asserts the wrong inventory

`src/save.c`'s 0836 block says `annot_p >= 0` *"is a term of the published-
annotation gate in token.c's six live_cursor2 sites and in op_annot.tcl"*. Six is
the right count of **guarded** sites; there is a **seventh reader** with no
guard. The audit that produced that sentence stopped at `op_annot.tcl`'s
`_annotated` and never reached the C renderers.

## Second face, same root

The public verb answers the same fabricated number: `xschem raw value {v(d)} -1`
returns `0` on the refused transient and `1.8` on the operating point.
`op_annot::raw_or_blank` is that verb.

## Shipped consumer

`xschem_library/devices/scope_ammeter.sym:31` is the one in-tree symbol using the
pattern, and its text is **not** `hide=true`:

    T {tcleval(@spice_get_node [xschem get_fqdevice @device ] )} 12.5 -139.375 0 0 0.15 0.15 {layer=17}

## No row sees it

None of the eleven rows rewritten for 0856, and none of the new T23-T28 / BA26b /
BA37, exercises a rendered `@spice_get_node` value in the refused state. They key
on `annot_p`, on `ngspice::ngspice_data`, and on the lab_pin `@spice_get_voltage`
floater — which **is** guarded and does blank correctly (row `T22`).

## ⚠ TWO GOLDENS NOW PIN THE FABRICATED ZERO — a correct fix will red them

`T14` and `T15` of `tests/headless/test_op_annot.tcl` carry
`[opa_t_v {v(d)}] == 0` with a comment that correctly identifies the calloc-zero
fall-through and judges it inert. It is **not** inert — it is this same zero, one
accessor over. Whoever fixes this must expect T14 and T15 to red, and must move
those goldens to the blank rather than weaken the fix. `T23`'s `{{tran 5 0} 0}`
and `T27`'s `{{table 3 0} {}}` are unaffected.

## Acceptance if fixed

1. B above renders `-` (or empty), not `0` — same three data points, `Plotname:
   Transient Analysis`.
2. **Positive twin.** C still renders `1.8`, unchanged.
3. The pre-existing `raw read`-without-annotate path renders `-` too, for both
   `tran` and `op`.
4. `xschem raw value {v(d)} -1` and `op_annot::raw_or_blank` agree with the
   rendered text — one answer, not two (RULING D5-4).
5. `T14`/`T15` goldens moved to the blank, not the fix narrowed to keep them.
6. Sabotage: restore the unguarded read and confirm row 1 reds.

## RED rows exist as of 2026-08-29 (item B3, PLAN+RED pass)

Re-measured on HEAD e60e1974 -- `src/token.c` is byte-identical to the tree
this was filed on, and the transcript above reproduces line for line, including
the shipped scope ammeter reading `vd 0`.

**New suite: `tests/headless/test_spice_get_node_0861.tcl`**, 23 checks,
registered in `tests/headless/full_audit.sh` and `tests/run_regression.tcl`.
Identical on both arms (23 checks, same 10 red) headless and on the dev
display. 13 of its rows are green today and are POSITIVE TWINS whose job is to
stay green -- the over-refusal fence, which is the whole risk on this item.

Ten rows are red for the measured reason, and no other block in the tree moved:

| acceptance | rows |
|---|---|
| 1 -- refused transient paints a dash | `SGN2`, `SGN6` (drawn), `SGN8` (shipped ammeter) |
| 2 -- positive twin, operating point unchanged | `SGN3`, `SGN7`, `SGN9`, `SGN11` (all GREEN today, must stay) |
| 3 -- plain results read, both run types | `SGN4`, `SGN5` |
| 4 -- one answer, not two (D5-4) | `SGN10`; twin `SGN11` |
| 5 -- T14/T15 moved to the blank | done, both red now |
| 6 -- sabotage | one variant per guard, listed in the B3 report |

Plus three rows nothing behavioural can see:

* `SGN19` -- `src/save.c` must stop asserting that a seventh reader is
  unguarded and that six is the count of guarded ones. A comment cannot be
  executed, so no other row in the tree can tell when it goes false.
* `SGN20` / `SGN21` -- shape locks on the two guards, one each, so a sabotage
  variant maps to exactly one row. Both strip C comments before matching,
  because the prose in both files quotes the tokens being counted.

**The fix is TWO C sites, not one.** `spice_get_node()` in `src/token.c` is the
rendered text; the `xschem raw value <vec> -1` fall-through in
`src/scheduler.c` is the verb behind `op_annot::raw_or_blank`. Guarding only
the first satisfies rows 1-3 and leaves row 4 red with `T14`/`T15` still green
at `0` -- a landing that looks clean and is not.

**A neighbouring decision was taken deliberately and is filed as 0920:** the
same fall-through also serves an OUT-OF-RANGE explicit point. Row `SGN18` pins
both halves -- blank while the annotation is refused, unchanged at `1.8` where
one was published. The remaining half is a real defect and is left open on
purpose.


---

## What landed (2026-08-29, item B3)

**Two readers, one question.** The rendered schematic text and the public verb
are two faces of "what does this node say", and RULING **D5-4** says they are one
sentence with one answer. Both now ask whether an annotation was actually
published before they read the cursor values:

* `src/token.c`, `spice_get_node()` — the reader behind every `@spice_get_node`
  text on a schematic, which is what `draw.c`, `svgdraw.c` and `psprint.c` all
  render through. It now takes the same blank it already produced for an unknown
  vector, two lines away.
* `src/scheduler.c`, the cursor fall-through of the
  `xschem raw value <vec> <point>` arm — the face `op_annot::raw_or_blank`
  answers through.

**The term is `annot_p >= 0`, not the simulation type.** A transient that HAS
published, because the user put cursor B on a waveform graph, still paints its
real values. A guard written on the simulation type would pass every negative row
in the new suite and silently kill that; row `SGN15` exists to catch it.

**The guard is on the cursor arm only, never on the enclosing index test.**
Asking for a numbered data point is data inspection and stays live while an
annotation is refused (`SGN13`, `SGN14`, `SGN22`).

**`src/save.c`'s inventory comment is reconciled, not appended to.** It no longer
tells a future reader that a seventh reader is unguarded, and it now names both
readers that were missing plus the obligation to add the term to any new one.
Row `SGN19` is a structural check over that comment, because nothing behavioural
can see a comment go false.

**Goldens that were pinning the fabricated zero, moved to the blank:**
`T14`, `T15` and `S14` of `tests/headless/test_op_annot.tcl`, and `V2c` of
`tests/headless/test_zero_point_pos_at_0852.tcl`. Each carried a comment
correctly identifying the calloc zero and judging it inert; it was not inert.

**Sibling [0855](0855-the-waveform-readout-shows-0-v-on-a-still-running-simulation.md)
landed with it**, and had to: once the engine stopped answering an out-of-range
point with the cursor's value, `wviewer::interp_value` was doing arithmetic on
the blank. It now asks the point count itself. Note that 0855 had guessed the
engine side "should probably not change" — B3's acceptance row 4 required exactly
that change, so the guess is superseded, not overlooked.

**Still open on the same arm:**
[0920](0920-an-out-of-range-explicit-point-is-answered-with-the-cursors-value.md)
— an out-of-range explicit point still answers the annotation value wherever one
was published. Row `SGN18` pins both halves so the behaviour is chosen rather
than inherited.

---

## The measurement, re-taken on the delivered tree

Same fixture, same two databases differing in one line. BEFORE is the transcript
at the top of this file, quoted literally; AFTER was re-taken by hand on the
built binary by the write-up pass, 2026-08-29, on a quiet box:

| row | BEFORE | AFTER |
|---|---|---|
| A nothing loaded | `annot=-1 0 -1  text=VDNODE=-` | `text=VDNODE=-`  verb raises, wrapper blank — unchanged |
| **B annotate-OP on a transient** | `annot=-1 0 -1  text=VDNODE=0` | `annot=-1 0 -1  text=VDNODE=-  verb=  raw_or_blank=` |
| **C annotate-OP on an operating point** | `annot=0 0 -1  text=VDNODE=1.8` | `annot=0 0 -1  text=VDNODE=1.8  verb=1.8  raw_or_blank=1.8` — **unchanged** |
| **D plain `raw read`, tran** | `annot=-1 0 -1  text=VDNODE=0` | `text=VDNODE=-  verb=  raw_or_blank=` |
| **E plain `raw read`, op** | `annot=-1 0 -1  text=VDNODE=0` | `text=VDNODE=-  verb=  raw_or_blank=` |

The shipped `xschem_library/devices/scope_ammeter.sym`, drawn through the SVG
back end (the same `translate()` the on-screen renderer calls), moved with it:
`vd 0` → `vd -` on the refused transient, and stays at `vd 1.8` on the operating
point. Zero amps through the branch is off the sheet.

## Acceptance, walked row by row against the delivered tree

| # | acceptance row | status | what pins it |
|---|---|---|---|
| 1 | B renders `-`, not `0` | ✅ | `SGN2` (text), `SGN6` (drawn sheet), `SGN8` (shipped scope ammeter) |
| 2 | **positive twin** — C still renders `1.8` | ✅ unchanged | `SGN3`, `SGN7`, `SGN9`, `SGN11` |
| 3 | plain `raw read` renders `-` for both run types | ✅ | `SGN4` (tran), `SGN5` (op) — `SGN5` is the row that forces the guard onto "was anything published" rather than onto the run type |
| 4 | verb and `op_annot::raw_or_blank` agree with the text (D5-4) | ✅ | `SGN10` refused, `SGN11` published — each pins the AGREED VALUE, because before the fix all three already agreed on the wrong answer |
| 5 | `T14`/`T15` moved to the blank, fix not narrowed | ✅ | `T14`, `T15` of `test_op_annot.tcl`, **plus two the brief did not predict**: `S14` of the same file (its own title read *"fabricates 0"*) and `V2c` of `test_zero_point_pos_at_0852.tcl`, whose comment had said in as many words that it was pinned so a fix would red it |
| 6 | sabotage: restore the unguarded read, row 1 reds | ✅ | one variant per guard; `SGN20`/`SGN21` map a text-side and a verb-side variant to exactly one row each, and `S5` maps the comment |

Counts on the delivered tree, both arms: `test_spice_get_node_0861` **23 checks
ALL PASS** headless and on the dev display, byte-identical verdict.
`test_op_annot` 475 headless / 482 with a display. `run_regression.tcl` 45 blocks,
**all 45 at `Total num fail: 0`** — the 45th block is this suite; the baseline
before the item was 44 blocks at zero.

## Fences that are the actual deliverable

More than half the new suite is rows that were green before the fix and whose job
is to stay green. This branch has shipped two defects past twenty-eight passing
checks and both were over-refusals.

* **`SGN15` is the one that matters.** A transient that *has* published, because
  the user dropped cursor B on a waveform graph, still paints the real value at
  that time (`annot {0 1e-09 0}`, text `VDNODE=1.9`). A guard written on the
  **simulation type** instead of on **whether anything was published** passes
  every negative row in the file and destroys exactly this.
* **`SGN13`, `SGN14`, `SGN22`** — asking for a numbered data point is data
  inspection, not annotation, and stays live while an annotation is refused. The
  term sits on the cursor fall-through alone and was never lifted onto the
  enclosing index test. `test_raw_read_dispatch` (137), `test_vcd_read` (156),
  `test_del_negative_arg` (24) and `test_cosim_golden_e2e` (46) all read that arm
  and are all green, unchanged.
* **`SGN16`** — a literal ground node still paints `0.0` in every state. Ground is
  a definition, not a measurement.
* **`SGN17`** — INVARIANT I3 unchanged: a vector absent from the file still
  dashes.

## Still open on the same arm

* **[0920](0920-an-out-of-range-explicit-point-is-answered-with-the-cursors-value.md)**
  — an out-of-range explicit point still answers the annotation's value wherever
  one was published. `SGN18` pins both halves so the behaviour is chosen.
* **[0921](0921-the-comment-lock-catches-the-old-wrong-prose-coming-back-but-not-the-new-correct-prose-going-away.md)**
  — `SGN19` locks the *old wrong* prose out of `src/save.c` but does not lock the
  *new correct* prose in; the whole paragraph can be deleted with all 23 checks
  green.
* **[0922](0922-an-expression-trace-added-to-the-results-paints-a-fabricated-0-on-the-schematic.md)**
  — ⚠ **the D5-1 class is not closed by this fix.** An expression trace added
  from the waveform viewer (`xschem raw add`) gets a fresh `cursor_b_val` slot
  initialised to `0.0` while `annot_p` stays published, so a `@spice_get_node`
  text naming it paints `0` — same array, same accessor, same shipped drawing
  path, and **both** of this item's guards walk straight past it because
  `annot_p` answers *"was an annotation published"*, never *"is THIS column's
  slot a measurement"*. Measured on the fixed tree: the true value is
  `3.5999999` and the schematic reads `X=0`. Not a regression — the pre-fix
  unguarded read produced the identical zero — but it means the `update_op()`
  comment's *"Both are guarded now"* is a claim about readers, not about the
  class.
* **Rule debt [0855]** — the mid-run waveform readout now drops each trace out of
  the cursor line entirely rather than showing a placeholder. That is option (a)
  of the four 0855 lists and the user has not chosen it.
* **A look debt is recorded.** Every measurement here reaches the drawing path
  through an SVG export. Nobody has yet seen a scope ammeter in a real window.
