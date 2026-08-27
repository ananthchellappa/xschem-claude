# 0856 - **Annotate Operating Point** shows a transient's t=0 as the operating point, silently

**Status:** OPEN, **measured**, not fixed. Filed 2026-08-26 from a user report on
`tb_bandgap` (a bench carrying both an OP and a TRAN analysis). Same class as
RULING D5-1 — a number on a schematic that the user reads as a measurement and
that the database does not contain — one surface over from
[0836](0836-update-op-segfaults-on-a-zero-point-database.md) and
[0855](0855-the-waveform-readout-shows-0-v-on-a-still-running-simulation.md).

## What the user sees

Node voltages annotated on the schematic that are **not** the operating point.
They are the transient's **first sample**, t=0 — the initial condition. Nothing
on screen says so.

The user's own two observations pin it precisely, and together they are
diagnostic:

* press `6` (device OP info) → every row blank (`id = `, `gm = `, …). **Correct**:
  a transient raw carries no `@m.x1.xm1…[id]` device-parameter vectors.
* press `Alt-6` (node voltages) → numbers appear. Those numbers are `v(net)` at
  **point 0** of that same transient.

Blank device rows beside populated voltage rows is exactly the signature of "the
current database is a transient". One is honest about having nothing; the other
is not.

## Two routes, both measured

**Route 1 — `annotate_op`'s deliberate fallback.** `src/scheduler.c`, the
`annotate_op` arm, after trying `op` then `dc`:

```c
        if(res != 1) { /* try to load a tran analysis (display 1stpoint as OP data in schematic) */
          res = extra_rawfile(1, f, "tran", -1.0, -1.0);
        }
```

The comment states the intent, so this is upstream behaviour and not an
accident. The defect is that it is **silent**. Measured on a 5-point transient
whose `v(a)` runs 0,1,2,3,4 with no operating-point plot in the file:

    M| annotate_op on a TRAN-only raw -> rc=0 res=::op_annot::text
    M| sim_type=tran points=5 annot=0 0 -1
    M| published v(a)=0   (true samples: 0 1 2 3 4 )
    M| statusmsg=

`annot_p` is 0, so `op_annot::_annotated` answers true and the block renders as
LIVE. `statusmsg` is **empty**. rc is 0. Nothing distinguishes this from a real
operating point.

**Route 2 — `update_op()` has no `sim_type` gate at all.** `src/save.c`:

```c
int update_op()
{
  int res = 0, p = 0, i;
```

`p` is pinned at 0 and there is no test of `xctx->raw->sim_type` anywhere in the
function. It refuses a digital database (D5-3) and, since 0836, a zero-point one
— but a 5-point transient publishes `values[i][0]` as the operating point.
Measured:

    Q| OP    update_op=1 va=3.14 nd=6 annot=0 0 -1
    Q| TRAN  update_op=1 va=0    nd=6 annot=0 0 -1
    Q| TRAN  true v(a) samples = 0 1 2 3 4

The tree already knows this is wrong. `xschem raw switch`'s gate exists for it,
and [0853](0853-raw-switch-gates-update-op-on-the-outgoing-database-s-point-count.md)
says so in as many words: *"Calling `update_op()` on every switch would publish a
multi-point transient's point 0 onto the schematic as though it were an
operating point, which is a fabricated number on a schematic — the outcome
RULING D5-1 exists to prevent."* That gate is **the only** thing standing between
a user and this, it lives in a caller rather than in `update_op()`, and 0853
measured it asking the wrong database.

## A third route worth naming, and it is NOT this issue

If the waveform viewer has a cursor on a transient,
`backannotate_cursor_b_in_db()` (`src/callback.c`) publishes that database's
values **at cursor B**, interpolated, into `ngspice::ngspice_data`. Those also
land on the schematic under `Alt-6`. That is RULING D4 working as designed — one
cursor, every database — and it is not a defect. It does mean a user cannot tell,
from the schematic alone, whether they are looking at an operating point, a
transient's t=0, or a transient at wherever they last left a cursor.

## What is actually at stake

`v(net)` at t=0 of a transient is the DC initial condition, which for many
benches is *close to* the operating point and for a bandgap with a startup
circuit may be nowhere near it. A number that is plausibly-but-not-quite right is
worse than a blank, because nothing prompts the user to check.

## The fix shape, and the ruling it needs

The engine change is small; the choice is not. Options:

* **(a)** `update_op()` refuses any `sim_type` that is not `op`/`dc`, minting a
  refusal sentence beside `backannot_refuse_digital()` and
  `backannot_refuse_empty()`. Consistent with D5-3 and 0836, and it deletes
  route 1's fallback along with route 2.
* **(b)** Keep the fallback but **say so**: publish, and announce once that these
  are transient t=0 values, not an operating point (status line + CIW). Keeps a
  bench with no `.op` usable.
* **(c)** Keep the fallback and mark it **in the annotation itself** — e.g. the
  block carries the sim type — so the schematic is self-describing.
* **(d)** Leave it.

⚠ **(a) is not obviously right.** The fallback was deliberate; removing it makes
`Annotate Operating Point` do nothing at all on a bench that only ran `.tran`,
which is a regression for whoever relies on it.

## Acceptance if fixed

1. A TRAN-only raw through `xschem annotate_op` produces the chosen behaviour
   (refusal, or an announcement naming the sim type), not silence.
2. **Positive twin.** An OP raw still annotates exactly as today — the numbers,
   `annot_p`, and `ngspice::ngspice_data`'s 6 entries all unchanged.
3. A 1-point `dc` raw (Xyce's operating point spelling) is still accepted.
4. `xschem update_op` on a multi-point transient does the same thing as the
   menu route — one behaviour, not two.
5. Sabotage both ways: restore the silent fallback and confirm row 1 reds;
   refuse `dc` as well and confirm row 3 reds.
