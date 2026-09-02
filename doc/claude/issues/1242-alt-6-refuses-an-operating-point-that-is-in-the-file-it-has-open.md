# 1242 — Alt-6 refuses an operating point that is in the file it has open

**Status:** FIXED 2026-09-01, **in two rounds**. Reported by the user from a
real bench, twice — the first fix made Alt-6 *select* the operating point and
the user immediately reported that it still did not *show* one. See
"Round two" at the end.

## What happened

A `tb_bandgap` run in sky130, deck carrying **both** an operating point and a
transient. After it finished, **Alt-6** said:

> No operating point results are loaded. These are from a 'tran' run instead, so
> there are no operating-point numbers to show. Run an operating point analysis,
> or press Alt-Shift-6 for node voltages at the waveform cursor.

The user: *"Which is BS. The sim has both OP and TRAN results available. The
user can annotate whatever she chooses to."*

They were right. Measured on their own artifact,
`~/.xschem/simulations/tb_bandgap_ase.raw` (69 MB), which holds **two plots**:

| plot | variables | points | begins |
|---|---|---|---|
| `Transient Analysis` | 424 | 20500 | line 4 |
| `Operating Point` | **891** | 1 | line 81923 |

That is what ngspice's `set appendwrite` leaves on disk when a deck asks for
both — and ASE-L's own `render_deck` emits exactly that deck. The engine can
read either plot on demand: `xschem raw read <file> op` returns 1, adds a second
registry slot, and `xschem update_op` publishes from it. **Nothing ever asked.**

## The cause

`cadence::_annot_op_db_ok` (`utils/annot_mode.tcl`) decided on the **selected**
slot alone:

```tcl
set st [xschem raw sim_type]          ;# the current slot, and nothing else
if {$st eq {op} || $st eq {dc}} { return 1 }
return 0
```

ASE-L's auto-plot attaches the plot that **has a sweep** — the log says so:
`ase: op results have no sweep — nothing to auto-plot` — so the selected slot
was the transient. The predicate looked there, found `tran`, and refused. The
operating point was in the same file the whole time.

## The fix

Three rungs, cheapest first, each a real case:

1. the selected slot **is** an operating point — nothing to do (unchanged);
2. **another loaded slot** is one — switch to it;
3. the selected slot's **own file** carries one behind the plot that is current
   — read it, which adds a slot and makes it current.

Only when all three fail is the refusal honest, and then it says exactly what it
always said.

Measured on the reported artifact: rung 3 costs **1 ms** on the 69 MB raw, and a
second press costs **0 ms** — `xschem raw read` dedupes on (rawfile, sim_type),
so holding the key down does not re-read. The registry is per window (`xctx`),
so the slot this adds belongs to the schematic window and cannot disturb the
traces in the waveform window.

## Ruling 0856 is not weakened

A run that produced only a transient still has no operating point, still
publishes nothing, and still gets the sentence — and it is **not silently
switched away from underneath the user** by a rung that went looking and failed.
Rows R5/R5b of `tests/headless/test_annot_op_behind_tran_1242.tcl` are that
proof, and every suite guarding 0856 stays green: `test_op_annot`,
`test_annot_show_menu`, `test_annot_stale_0684`, `test_annot_blank_cause_0909`,
`test_backannotate_digital`, `test_annot_hier_0911`.

## A note on the fixture, because it nearly went green on the wrong file

The first version of the regression fixture wrote the two plots as ASCII
`Values:` blocks. **The reader does not find the second plot in that shape**, so
the suite would have passed while testing a file that is not the file the bug is
about. The committed fixture is binary, with the second header butting straight
against the first plot's data and carrying a `Command:` line — verified byte for
byte against the reported bench's own raw.


---

# Round two — selecting is not showing

The user, immediately after the first fix landed:

> *"Once the Alt-Shift-6 has been exercised, there is no way to go back to
> annotating from the OP results. Bad. One should always be able to do Ctrl-6 to
> dismiss simulation annotations and then do either Alt-6 or Alt-Shift-6 and 6"*

Measured on their bench, and the numbers say it exactly:

```
0. after the run     mask=0  db=tran  annot(p x idx) = -1 0 -1
1. Alt-6             mask=2  db=op    annot(p x idx) = -1 0 -1     <-- selected, blank
2. Alt-Shift-6       mask=6  db=tran  annot(p x idx) = 1359 1.344e-05 0
3. Ctrl-6            mask=0  db=tran  annot(p x idx) = 1359 1.344e-05 0
4. Alt-6 again       mask=2  db=op    annot(p x idx) = -1 0 -1     <-- selected, blank
```

`annot_p == -1` is what `token.c` gates the painted text on. So round one's fix
selected the operating point, armed the mask, and left the status line saying
"Showing DC node voltages on the schematic" while every node read `?`.

**Two causes, each sufficient on its own:**

* `xschem raw read` does not publish — and must not. A read is *"load this"*,
  not *"show this"*. Rung 3 used it.
* `xschem raw switch` does publish, but its gate straddled two databases —
  **issue 0513**, open since 2026-08-19 and fixed alongside this. Rung 2 used it.

**The fix:** every rung now ends in `cadence::_annot_op_publish`, which calls
`xschem update_op` and reports `annot_p >= 0` — the observable the painted text
actually depends on, rather than a proxy for it. Rung 1 publishes too, because a
database being *selected* does not mean its numbers were ever *published*:
`cursor_b_val` is per database and starts zeroed.

The publish stays in the Tcl even with 0513 fixed, deliberately: this proc knows
it is acquiring a database **in order to show it**, which is a fact no `raw` verb
can infer from its arguments.

After: every step above publishes, and the user's stated requirement holds —
Ctrl-6 dismisses, and 6 / Alt-6 / Alt-Shift-6 each work from there, in any order.
Rows R8–R13 of the regression suite; R11 is the reported sequence end to end and
R13 is the way back out (with the operating point selected, the transient side
knows to re-supply rather than refuse `notran`).
