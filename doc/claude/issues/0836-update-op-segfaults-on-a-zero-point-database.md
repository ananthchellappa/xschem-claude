# 0836 - `update_op()` SIGSEGVs on a zero-point database, reachable from a shipped verb

**Status:** OPEN, measured, not fixed. Filed by the Measure agent of the
0807+0813+0814 crew (2026-08-26) as a STUB claim; see `doc/claude/issues/status_annotate.md`.

> ⚠ **THIS ISSUE NOW BLOCKS [0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md)
> / 0813 / 0814.** Attempt 2 of that item was tier-green and was **reverted on 2026-08-26
> because of this bug** — closing 0814 means making the fallback legs perform a *real*
> read, and a real read of a running simulation's raw lands exactly here. See 0807 §13
> and constraint §11.7. Fix this first, then re-apply
> `doc/claude/evidence/0807-attempt2-reverted.patch.txt`.

> ⚠ **THE DOOR IS FAR WIDER THAN THE SWEEP WINDOW BELOW.** The original filing reached
> the crash through `xschem raw read <f> op 999 1000`, a deliberate sweep window that
> excludes every point. That made it look like a corner. It is not — see
> "The live-raw door" below: **every ngspice run leaves a zero-point raw on disk for its
> entire duration**, with no crafted arguments and no truncation.

**Not a duplicate of 0834** (that is `xschem callback` under `--nogui`). This one
needs no GUI and no crafted header - a real `ngspice` raw and one documented
sub-command reach it.

## Measured, at HEAD `ebc2cfd5`, `--nogui`, real `/usr/local/bin/ngspice-46+` raw

Fixture: a 296-byte 1-point BINARY operating-point raw written by ngspice from

    * run1
    v1 a 0 dc 3.14
    v2 b 0 dc 1.50
    r1 a 0 1k
    r2 b 0 1k
    .op
    .end

Driver (`xschem --nogui --pipe -q --nolog --script`):

    WU| SEG1 raw read <real 1-point op.raw> op 999 1000 -> rc=1
    WU| SEG2 points=0  loaded=0  sim=op
    WU| SEG3 about to call: xschem update_op

    FATAL: signal 11
    while editing: untitled

`annotate_op` reaches it from the same state:

    WU| SEGB1 raw read op 999 1000 rc=1 points=0
    WU| SEGB2 about to call: xschem annotate_op <...>/g1.raw

    FATAL: signal 11

`SEG4 SURVIVED update_op` / `SEGB3 SURVIVED annotate_op` never print. Process exit
is 1, not 139, because xschem installs its own handler for signal 11.

## Mechanism (source-confirmed)

`xschem raw read <f> op 999 1000` asks for a sweep window that excludes every
point. `read_raw_data_block()` then calls

    src/save.c:705   my_realloc(_ALLOC_ID_, &raw->values[p], (offset + npoints) * sizeof(SPICE_DATA));

with `npoints == 0`, and `my_realloc(id, ptr, 0)` **frees and NULLs**
(`src/util.c:1330-1334`). So `raw->values` is non-NULL while every
`raw->values[v]` is NULL, and the read still returns 1 with `points` 0.

`update_op()`'s only guard is

    src/save.c:2063   if(xctx->raw && xctx->raw->values) {
    src/save.c:2069       xctx->raw->cursor_b_val[i] = xctx->raw->values[i][p];   /* p == 0 */

- it checks the outer array and then dereferences the inner one. There is no
`npoints` / `allpoints` check anywhere on that path.

## The live-raw door — no crafted arguments, no truncation, the whole run long

Added 2026-08-26 by the write-up agent of the 0807+0813+0814 crew, after recovering
the finding from the Verify-C adversary's leftover transcript (`live_fix.out`), which
drove a **real, still-being-written 2.9 MB ngspice raw**.

`ngspice` writes the raw header **before** it has any points and backfills
`No. Points:` only when the run ends. The header on disk during a run reads:

    Title: * long tran
    Date: Wed Aug 26 06:20:57  2026
    Plotname: Transient Analysis
    Flags: real
    No. Variables: 3
    No. Points: 0
    Variables:
    ...
    Binary:

That file is **well-formed and untruncated**. `read_dataset()` reads it as a success
with `points == 0`; the store loop `for(p = 0; p < npoints; p++)` never executes, so
no `fread` happens and **no truncation logic of any kind is involved** (there is no
`binary block is not of correct size` warning). `my_realloc(..., 0)` then frees and
NULLs every `raw->values[v]`, and `update_op()` dereferences `values[i][0]`.

Reproduced minimally with a twelve-line hand-written header plus 4 KB of zeros —
`good.raw` attached as the op database, then `annotate_op` on the live raw:

    WU| LIVE-A before  loaded=0 v(a)=3.14
    Raw file data read: .../live0.raw
    points=0, vars=3, datasets=1 sim_type=tran

    FATAL: signal 11

**Consequence:** on any tree where `annotate_op`'s fallback legs really read (i.e.
once 0814 is fixed), pressing *Annotate Operating Point* at any moment while a
simulation is running is a segfault. On HEAD it is reachable too — whenever the path
is not already registered with the sim_type the fallback settles on — but HEAD's
same-path dedup masks it in the ASE/wave-viewer arrangement, which is why 0807
attempt 2 turned it from masked into routine.

## Why it is on 0807's critical path

`raw->npoints[raw->datasets] = p` is 0299's rejected alternative for a short read
(`src/save.c:754`). For the **1-point** op raw of 0807's bench case `p` is 0 when
the store loop breaks, so that alternative would *manufacture* exactly this
zero-point dataset on every truncated op raw. Measured evidence that `p` reaches
0 there: a 296-byte 1-point op raw cut to 272 (3 of its 4 doubles gone) loads
`rc=1 points=1` with `v(a)=3.14` and `v(b)/i(v1)/i(v2)` all fabricated as 0 -
there is no earlier point to keep.

This is the mechanism behind the lead's narrowing of the 0299 ruling, and it is
an argument, not a preference: `npoints = p` must never be applied on a path
where `p` can reach 0.

## Suggested fix (not applied here)

Guard `update_op()` on a positive point count as well as a non-NULL `values`:
`if(xctx->raw && xctx->raw->values && xctx->raw->npoints && xctx->raw->npoints[xctx->raw->datasets] > 0)`
- exact field spelling to be checked against `Raw` in `xschem.h`. Consider also
refusing to publish a zero-point dataset as `loaded` at all.

## No test covers it

It crashes the interpreter, so it cannot be a check inside an existing suite; it
needs its own one-shot driver whose *process exit* is the assertion. None exists.

## Acceptance if fixed

1. `xschem raw read <op.raw> op 999 1000` then `xschem update_op` returns
   normally, process exit 0, no `FATAL: signal 11`.
2. Same, with `xschem annotate_op <op.raw>` in place of `update_op`.
3. Positive twin: a normal `xschem raw read <op.raw> op` then `xschem update_op`
   still publishes `v(a)=3.14 v(b)=1.5` and still populates
   `ngspice::ngspice_data` (6 entries on this fixture).
4. **THE LIVE-RAW ROW (added 2026-08-26, and the one that actually matters).**
   With a good op database attached, `xschem annotate_op <live 0-point raw>`
   returns normally with process exit 0, and — invariant I3 — leaves the
   **previous** database attached rather than publishing anything from the
   zero-point one. Fixture: a hand-written `No. Points: 0` header; do **not** use
   garbage bytes, which fail every leg and pass on a crashing tree.
5. **The registered-path twin**, which is the shipped ASE/wave-viewer shape:
   `xschem raw read <P> tran`, overwrite `P` with a live 0-point header, then
   `xschem annotate_op <P>` — returns normally, exit 0.
6. A zero-point database must not be reported as usable: decide (and record) what
   `xschem raw loaded` and `xschem raw points` answer for one.

## Open ruling this raises

Whether a zero-point read should be **refused by the reader** (so a running
simulation's raw simply does not attach) or **accepted and guarded** at every
consumer is user-visible: the wave viewer may legitimately want to attach a running
sim's raw and watch it fill. The narrow fix (guard `update_op()`) is the smaller
blast radius and is what this issue recommends; the wider one is not for an
unattended crew to choose. Recorded as a `rule` debt against this issue id.
