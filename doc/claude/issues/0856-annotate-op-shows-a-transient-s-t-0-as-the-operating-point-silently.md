# 0856 - **Annotate Operating Point** shows a transient's t=0 as the operating point, silently

**Status:** **RULED BY THE USER 2026-08-26, AND LANDED 2026-08-27.** Filed
2026-08-26 from a user report on `tb_bandgap` (a bench carrying both an OP and a
TRAN analysis). Same class as RULING D5-1 — a number on a schematic that the
user reads as a measurement and that the database does not contain — one
surface over from
[0836](0836-update-op-segfaults-on-a-zero-point-database.md) and
[0855](0855-the-waveform-readout-shows-0-v-on-a-still-running-simulation.md).

## THE RULING (the user, verbatim, 2026-08-26)

> "if OP is part of the run, then plot from OP. We haven't yet built anything for
> annotating from TRAN results, so it should do nothing silently. Why complicate
> things?"

That is **option (a) without the sentence** — refuse, and do not announce the
refusal. Of the four options this issue offered below, (a) was the closest and
the user removed its announcement clause. (b), (c) and (d) are declined.

The user's stated worry about (a) — that **Annotate Operating Point** would then
do nothing on a bench that only ran `.tran` — is answered by (b) of the same
message and by [0857](0857-the-6-chord-does-not-say-the-loaded-database-is-the-wrong-kind.md):
the explanation belongs to the **chord**, one level up, which knows what the user
just pressed. `update_op()` itself stays silent.

## WHAT LANDED (2026-08-27)

One guard in `update_op()` (`src/save.c`), placed **after** the D5-3 digital
refusal and the 0836 zero-point refusal and **before** `annot_p = 0`:

```c
  if(!xctx->raw || !xctx->raw->sim_type ||
     (strcmp(xctx->raw->sim_type, "op") && strcmp(xctx->raw->sim_type, "dc"))) {
    dbg(0, "update_op(): '%s' is not an operating point database, publishing nothing\n",
        (xctx->raw && xctx->raw->sim_type) ? xctx->raw->sim_type : "<none>");
    return 0;
  }
```

**What the user sees change:** point a schematic at a bench whose results are a
transient, ask for the operating point, and the schematic now stays **blank**
instead of showing the t=0 numbers dressed as an operating point. Move a cursor
in the waveform window and the real values at that time still appear on the
schematic, exactly as before — that half was never the defect and is untouched.

**Route 1's `tran` fallback in `scheduler.c` STAYS.** It is not dead code: it is
the attach door for cursor-driven transient annotation (RULING D4, step S11),
pinned by section T of `tests/headless/test_op_annot.tcl`, and deleting it takes
~20 rows down while changing nothing about this ruling. The transient still
attaches; the point-0 publisher refuses to publish from it. Resting state on a
freshly attached transient is `annot_p == -1`.

**Five things the ruling did not settle**, all filed rather than assumed. The
first two are consequences of the guard; the last three were MEASURED during the
landing and are **not fixed** — none is a reason to hold the gate, and none is
closed by it:

* [0859](0859-the-0856-gate-shadows-the-d5-3-digital-refusal-in-update-op.md) —
  the new guard also refuses a `vcd`, with the identical observable, so it
  **shadows** the digital refusal above it. Mitigated by source witness `BA37`,
  which pins both guards' presence and their **order**.
* [0860](0860-the-0856-gate-refuses-every-non-op-dc-database-not-only-tran.md) —
  the guard is an allow-list, so it refuses `ac`, `noise` and `table` too, which
  is wider than the sentence the user wrote. Landed wide deliberately, pinned by
  row `T27`, and carrying an open `rule` debt.
* [0861](0861-spice-get-node-renders-a-fabricated-0-when-nothing-is-published.md)
  — **the one the user is most likely to notice.** `spice_get_node()` in
  `token.c` is a SEVENTH reader of `cursor_b_val` with no `annot_p` guard, so a
  `@spice_get_node` text (a probe symbol, or the shipped `scope_ammeter.sym`)
  prints a fabricated `0` where the block correctly blanks. Pre-existing — a
  plain `raw read` already produced it, for `op` databases too — but this gate
  routes the ordinary menu flow into it. Measured: `-` / `0` / `1.8` for
  nothing-loaded / refused transient / operating point, same three data points.
* [0862](0862-update-op-publishes-a-multi-point-dc-sweep-s-first-step-as-the-operating-point.md)
  — the guard tests the **type only**, while both `raw switch` gates it
  consolidates also require `allpoints == 1`. So a genuine multi-point `.dc`
  sweep still publishes its first step. Pre-existing; it is why this issue's
  headline in `save.c` was narrowed from *"only an operating point publishes an
  operating point"* to *"a transient does not"*.
* [0863](0863-a-mixed-raw-s-op-plot-is-only-found-when-it-is-the-first-plot-in-the-file.md)
  — **the one that decides whether this ruling can be honoured at all.** On a
  rawfile whose transient plot is written FIRST, the `op` plot is never found, so
  `annotate_op` falls through to the transient and now publishes nothing. The
  user's own bench, `tb_bandgap`, carries both analyses. Measured: identical
  vectors, op-plot-second is unreachable, op-plot-first reads 1.77 immediately.
  Fixing 0863 is what turns a blank schematic back into the right numbers.


## What the user sees (the original report)

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

## The fix shape, and the ruling it needed — HISTORICAL, kept for the record

The user chose **(a) without its sentence**; the options below are what was put
to them. Retained so the reasoning behind the landed shape is legible.

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

## Acceptance — MET, and these are the rows that pin it

All five original acceptance rows are satisfied, each by a named row that is
gate-sensitive (it reds if the guard is removed), measured 2026-08-27:

| # | Acceptance | Pinned by |
|---|---|---|
| 1 | A TRAN-only raw through `annotate_op` publishes nothing | `T0`, `T23`, `BA26`, `R5s2`/`R5s3` |
| 2 | **Positive twin** — an OP raw annotates exactly as before | `T24`, `BA26b`, `BA30`/`BA31`/`BA36` |
| 3 | A 1-point `dc` raw (Xyce's spelling) is still accepted | `T25`, and `T26` for the multi-point-OP → `dc` rewrite |
| 4 | The bare `xschem update_op` verb behaves as the menu route | `T23` (both answers come from `opa_t_pub`) |
| 5 | Sabotage both ways | `S1` reds T0/T10/T14/T15/T22/T23/T27 + BA26 + R5s2/R5s3; `S2` reds `T25`/`T26` only |

Two more terms of the guard had **no row anywhere in the tree** before this
landing and now do: `T27` pins the widening (issue 0860) as visible behaviour,
and `T28` pins the `!xctx->raw` NULL-safety term. `BA37` pins the guard ORDER
(issue 0859).

**Suite counts after the landing**, all `RESULT: ALL PASS` with a whole-line
`OVERALL: ok`: `test_op_annot` 364 headless / 370 on the display arm (was 358),
`test_backannotate_digital` 83 (was 81), `test_zero_point_raw_0836` 73
(unchanged — R5s2/R5s3 moved goldens, no rows added or dropped). The first two
were **not** in `run_regression.tcl`'s `hcases` and their reds were invisible to
T1; both are registered now, and T1 is back to **zero** counted failures.

⚠ **What acceptance does NOT cover.** Rows 1-5 are about what `update_op()`
publishes. They say nothing about what a schematic RENDERS once nothing has been
published — that is issue 0861, and it is not closed here.
