# 0836 - `update_op()` SIGSEGVs on a zero-point database, reachable from a shipped verb

**Status:** **FIXED (narrow) 2026-08-26.** `update_op()` now refuses a zero-point
database. Filed by the Measure agent of the 0807+0813+0814 crew (2026-08-26) as a
STUB claim; see `doc/claude/issues/status_annotate.md`. **The open ruling below is
STILL OPEN** - narrow shipped because no user ruling had arrived, and the wide
option is recorded, not closed. The rule debt is NOT cleared.

See § **WHAT SHIPPED** at the bottom for the guard, the field measurement, the
0299 read-across and the three siblings filed.

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

---

# WHAT SHIPPED (2026-08-26)

## The ruling taken, and why

**NARROW: guard the consumers.** `update_op()` refuses a zero-point database; the
read still succeeds and the database still attaches, so the wave viewer can still
attach a running simulation's raw and watch it fill. This is what this issue
recommends and it is what a session with **no user ruling** is entitled to take.

**The wide option — refuse the read outright — is still open and is still the
user's.** The `rule` debt against this id is **NOT cleared**; its `why` was
updated to say narrow shipped. Nothing measured here discharges it.

## The guard

`update_op()` (`src/save.c`), immediately after the existing `raw_is_digital`
refusal and **before** `annot_p = 0`:

    if(xctx->raw && xctx->raw->allpoints <= 0) {
      backannot_refuse_empty(xctx->raw->rawfile);
      return 0;
    }

Same shape as the D5-3 digital refusal eleven lines above, deliberately: refuse,
say why once, `return 0` meaning "nothing was published", leave whatever was
previously attached alone rather than half-publishing (invariant I3). A reader who
has learned one exit does not have to learn a second idiom.

`backannot_refuse_empty()` is minted beside `backannot_refuse_digital()` and
follows the same RULING D5-4 discipline — one sentence, minted where the reason is
known, rendered by callers — and the same anti-splice discipline: `dbname` is a
user-supplied path and is handed to Tcl as a *variable*, never concatenated into a
script.

### Placement is load-bearing

The guard **must return before `annot_p = 0`**, not after. `annot_p >= 0` is a term
of the published-annotation gate at all six `live_cursor2_backannotate` sites in
`src/token.c` and in `src/op_annot.tcl`. A guard that let `annot_p` reach 0 would
make every one of them read the `my_calloc`-zeroed `cursor_b_val` and print
**0 V** on the schematic instead of blanking — a fabricated number, which is the
exact outcome RULING D5-1 exists to prevent.

## The field guarded, and what the other one answered

**Guarded on `allpoints`.** This issue's own "Suggested fix" above proposed
`npoints[raw->datasets] > 0` instead. **That is an out-of-bounds read**, and it
would have shipped the crash.

Measured with a temporary `dbg()` at the guard site, on both fixtures:

    MEASC allpoints=0 datasets=1 npoints0=0 npoints[datasets]=22017
    MEASC allpoints=0 datasets=1 npoints0=0 npoints[datasets]=21932
    MEASC allpoints=0 datasets=1 npoints0=0 npoints[datasets]=22063
    MEASC allpoints=0 datasets=1 npoints0=0 npoints[datasets]=22006
    MEASC allpoints=0 datasets=1 npoints0=0 npoints[datasets]=21912
    MEASC allpoints=1 datasets=1 npoints0=1 npoints[datasets]=5      <- good db

`npoints[datasets]` is **heap garbage**, different on every run, and in six of six
runs it was **greater than zero** — so `npoints[datasets] > 0` would have passed
every acceptance row while leaving the segfault live.

Why: `read_dataset()` does `raw->datasets++` **after** `read_raw_data_block()`,
while the `npoints` array was realloc'd to `datasets+1` entries **before** that
increment. For a one-dataset file the array therefore holds exactly **one** entry
and `npoints[datasets]` is `npoints[1]`, one past it.

The other candidates: `npoints[0]` answers 0 correctly but has to be indexed;
`allpoints` is a plain signed `int` that cannot be indexed wrong, is set on all
four reader paths (`raw_read`, `table_read`, `vcd_read`, `new_rawfile`), and is
already the field every other point-count guard in the tree uses.

## Three doors, not two

The issue lists two. A third was found and is now covered by the same guard:

3. **`xschem raw switch <n>`.** `src/scheduler.c` snapshots `Raw *raw = xctx->raw`
   *before* the switch and then gates `update_op()` on the **outgoing** database's
   `allpoints` while reading `sim_type` off the **incoming** one — so switching
   from a 1-point op database into a zero-point one called `update_op()` on the
   zero-point one. Measured `FATAL: signal 11`; now refused.
   The mixed predicate itself is filed as **0853** (it also *fails to annotate*
   when it should, which the 0836 guard does not fix).

## Acceptance — all six rows, plus what had to change about two of them

`tests/headless/test_zero_point_raw_0836.tcl` — **72 checks, all green**. It is a
`.tcl` parent that never executes a crashing path; every crash-provoking row runs
in a **child** `xschem --nogui --pipe` under `timeout(1)` whose **process exit is
the assertion**. Because xschem installs its own handler for signal 11, a crash
exits 1 and not 139, so every row asserts **`rc == 0` AND** that a post-call
`Z_SURVIVED` sentinel actually printed — a clean refusal that returned nonzero and
a crash are different failures and must be tellable apart from the log alone.

Fixtures are hand-written **well-formed** headers built in pure Tcl (no ngspice
needed), never garbage bytes. They were validated against real
`/usr/local/bin/ngspice-46+` output: a 296-byte 1-point op raw, and a real 868 KB
raw copied out of a still-running `.tran`, both give identical readings and the
identical crash.

| row | what | id |
|---|---|---|
| 1 | `raw read <op.raw> op 999 1000` + `update_op` survives, exit 0 | `R1a`-`R1f` |
| 2 | same via `annotate_op` | `R2a`-`R2b` |
| 3 | **positive twin**: a normal op raw still publishes `v(a)=3.14 v(b)=1.5`, 6 entries | `R3a`-`R3g` |
| 4 | **live-raw row** | `R4a`-`R4h`, and `R4i`-`R4r` for I3 |
| 5 | **registered-path twin** | `R5a`-`R5j`, plus `R5s0`-`R5s3` |
| 6 | what a zero-point database reports about itself | `R6a`-`R6f` |
| +  | door 3, `raw switch` | `R7a`-`R7e` |
| +  | scope: `raw pos_at` on the same database | `R8a`-`R8c` — shipped as a **crash** assertion (the tripwire), **converted to survival** when 0852 landed, same day |

### Row 4 had to be split: its I3 clause is unachievable on a 0836-only tree

`annotate_op` **deletes the previously loaded OP before it reads anything** — the
block commented "delete previously loaded OP" fires on exactly `allpoints == 1`
plus sim_type op/dc, which is the good database verbatim. So the previous database
is already gone by the time `update_op()` is reached, and no guard placed in
`update_op()` can rescue it. That is **0807**, which was out of scope here.

- `R4a`-`R4g` assert the crash gate and that nothing is published.
- `R4h` **pins the known-defective state on purpose** (one registry entry), with a
  `BLOCKED ON 0807` comment, so that fixing 0807 REDS it and forces an update
  rather than quietly satisfying it.
- `R4i`-`R4r` assert **invariant I3 for real**, by a route the pre-delete does not
  cover: the pre-delete keys on the *current* database, so making the good op
  database present-but-not-current leaves it untouched. After the refused call,
  `R4o` reads **`v(a) = 3.14` out of the survivor** — a number, not a non-NULL
  pointer — and `R4p`-`R4r` re-publish all 6 entries from it.
  (`xschem raw value` alone would have been hollow: on a zero-point database both
  of its bound arms are false and it falls through to the `my_calloc`-zeroed
  `cursor_b_val`, returning a benign-looking `0`.)

### Row 5 as literally worded is VACUOUS, and is kept as an 0814 witness

`raw read <P> tran` then `annotate_op <P>` hits the same-path dedup, whose hit arm
**never opens the file** — so the rewritten zero-point bytes are never read and the
row is green on a crashing tree. That is **0814**.

- `R5a`-`R5j` are the real row: break the dedup the way a real re-run does, with a
  **different analysis at the same path**, so the op leg performs a genuine read of
  the rewritten file. `R5h`-`R5j` then assert I3 with a number (`7.77`) out of the
  surviving tran entry at the same path.
- `R5s0`-`R5s3` keep the literal wording, **labelled a 0814 witness**: green at
  HEAD, asserting that the cached points are served from memory. It reds when 0814
  lands, forcing replacement — rather than 0814 silently turning an 0836 row from
  vacuous into meaningful with nobody noticing which it had been.

### Row 6 — DECIDED AND RECORDED

Under the narrow ruling:

- **`xschem raw points` answers `0`.** This is *the* discriminator. It is honest,
  it is the field the guard keys on, and a caller can act on it. (`R6b`, `R6f`.)
- **`xschem raw loaded` is UNCHANGED**: it keeps answering the hierarchy *level*
  at which the database is attached, exactly as for a good database. It is not a
  usability predicate and never was — `sch_waves_loaded()` asks "is a database
  attached at a schematic on my hierarchy stack", and under the narrow ruling a
  zero-point database **is** attached. Making it answer -1 would be the wide
  ruling in disguise: the same function gates graph drawing, so a running
  simulation's waveform would stop rendering. (`R6c`.)
- `R6d` is the row that stops the two being confused: it asserts that `raw points`
  discriminates between a good and a zero-point database while `raw loaded` does
  not.

## Sabotage matrix — run in BOTH directions

| direction | change | result |
|---|---|---|
| **never fires** | `if(0 && ... allpoints <= 0)` | **32 red.** All three doors crash again. Green and correct: `P1`-`P12`, `R1b`/`R1c` (the read still succeeds — the fix is not "make the read fail"), all of `R3` (positive twin), the preconditions before each crash, `R5s*` (0814 witness never opens the file), `R6*` (never calls `update_op`), `R8*`. |
| **always fires** | `allpoints >= 0` | **19 red**, and the red set is **disjoint** from the above: `P4`-`P7`, `R3b`-`R3g`, `R4b`/`R4c`/`R4j`/`R4k`/`R4p`-`R4r`, `R5s2`/`R5s3`. |

The two directions produce **different** red sets, so the suite can tell "a guard
that never fires" from "a guard that only ever fires" — which is the whole point of
running the over-reach direction, since one is as wrong as the other.

## The `raw_is_digital` NULL question, answered

The issue asks whether `raw_is_digital(xctx->raw)` — called before the
`xctx->raw &&` null test — dereferences. **It does not.** `src/save.c`:

    int raw_is_digital(const Raw *raw)
    {
      if(!raw) return 0;
      ...

with the comment "A NULL Raw is not digital: 'nothing is loaded' is not 'a digital
thing is loaded'." **No sibling to file.** The new guard is spelled
`xctx->raw && ...` for the same reason: a NULL database must not emit an
"empty database" sentence, because nothing was asked for.

## The 0299 read-across — the answer is NO, and the reasoning had to be corrected

This issue argues that `raw->npoints[raw->datasets] = p` (0299's rejected
alternative) would manufacture a zero-point dataset on every truncated op raw.
Two corrections, both source-confirmed:

1. **The bare line at `src/save.c:754` is a NO-OP at HEAD.** The short-`fread`
   site only *logs*; there is no `break`, no `continue`, no flag, so control
   reaches the store and `p++` on every iteration and `p == npoints` whenever
   `res == 1`. **The `break` is the load-bearing half** — 0299 says "*stop* at the
   short point and set … = p", and the reverted 0807 attempt-2 patch adds `break;`
   at both `fread` sites. Read as the bare line, the alternative changes nothing.
2. **Read as the break-bearing form, does 0836's fix make it safe? NO.**
   - `get_raw_value()` adds `ofs` **before** its bound test, so a *trailing*
     zero-point dataset (`npoints = [1, 0]`, dset 1, point -1) computes
     `ofs + point == 0` and reads dataset 0 **in bounds** — a wrong number, not a
     crash. Silent corruption is not covered by a crash guard.
   - `allpoints` is used as a **whole-database predicate** at three `allpoints == 1`
     gates (`annotate_op`'s pre-delete, and both `raw switch` gates), so
     manufacturing a zero-point dataset changes behaviour at all three.
   - The free-and-NULL of the columns only happens for a **leading** zero-point
     dataset (it requires `offset == 0`), so the two positions are not equivalent.
   - The ascii and binary arms disagree about the same input.
   - Most simply: a truncated file is a **permanent** condition, while a
     zero-point live raw is a **transient diagnostic** — one sentence should not
     serve both.

**`npoints = p` must still never be applied on a path where `p` can reach 0**, and
0299's ruling is still the user's. Its rule debt is untouched. Note that acting on
that read-across would mean re-applying 0807 attempt 2, which was out of scope.

## Siblings (one since fixed)

The guard is `update_op()`-local **by ruling**. It does not close every zero-point
dereference in the tree, and the scope is asserted as a test row rather than
claimed in prose.

- **[0852] — FIXED 2026-08-26**, and it was the sharpest of these: a SECOND
  SIGSEGV on the same database, by a different route. `get_raw_value()` bounded
  `point` from **above only**, so `raw_get_pos()`'s
  `lastpoint = npoints[dset] - 1 == -1` reached `values[idx][-1]` on a NULL
  column — reachable from the shipped wave viewer (`wviewer::interp_value`),
  where the surrounding Tcl `catch` cannot catch a SIGSEGV. Fixed with two
  redundant guards (the lower bound in `get_raw_value()`, an empty-dataset
  refusal in `raw_get_pos()`), which also covers `waves_callback()`'s identical
  shape. `R8b` was written to assert the crash **on purpose** so that closing
  0852 would red it; that conversion is done — it now asserts **survival**, and
  `R8c` was added beside it so the answer must be `-1` and not a fabricated
  index. Full acceptance in `tests/headless/test_zero_point_pos_at_0852.tcl`.
- **[0855]** — filed by the 0852 crew, and it exists only **because** 0852 was
  fixed: with the crash gone, the viewer's value readout now shows **`0`** for
  every trace during a running simulation, a number the database does not
  contain. Same class as RULING D5-1, one surface over. The remedy is a
  presentation choice, so it is a queued ruling rather than a fix.
- **[0853]** — `xschem raw switch` gates the republish on the **outgoing**
  database's point count while reading `sim_type` off the **incoming** one (door
  3 above). Also **fails to annotate** a 1-point op database when switching into
  it from a multi-point one, measured; 0836's guard does not fix that half. The
  user-visible half: switch from waveforms back to your operating point and the
  schematic shows no numbers, with nothing said about why.
- **[0854]** — `annotate_op`'s pre-delete hands `extra_rawfile()`
  `xctx->raw->sim_type`, a pointer into the Raw the clear arm then frees; the
  named-clear loop keeps dereferencing it. **Confirmed under valgrind**
  (`Invalid read of size 1 at extra_rawfile`, into a 3-byte block — `"op"` —
  freed by `free_rawfile` one iteration earlier). Distinct from 0807: it stands
  however 0807 is ruled.

## Harness registration

- `tests/headless/full_audit.sh` `nogui_tests` — added (this is a `--nogui` item
  end to end; no display needed).
- `tests/run_regression.tcl` `hcases` — added, so T1 covers it. It emits the
  **dual banner** (`RESULT: ALL PASS (N checks)` **and** `OVERALL: ok`), because
  `banner_complete` in `tests/banner_rule.tcl` matches only the latter.
- `full_audit.sh`'s automatic enumerator globs `test_*.tcl` and needs no edit.

⚠ **It had to be a `.tcl`, not a `.sh`.** Nothing in this repo automatically runs
a `tests/headless/test_*.sh` — not `full_audit.sh` (its glob is `.tcl` only), not
`run_suites.sh` (it resolves bare names to `.tcl`), not `ci.yaml`, not
`run_regression.tcl`. A new `.sh` driver would have been a suite nobody runs,
which reads as coverage and is worse than none.

    grep -c test_zero_point_raw_0836 tests/headless/full_audit.sh   -> 1
    grep -c test_zero_point_raw_0836 tests/run_regression.tcl       -> 1

**T1 is at ZERO counted failures** with the suite added: every headless case
`Total num fail: 0`, no `couldn't execute` and no `exit 127`. The three `NOGOLD`
lines (create_save, open_close, netlisting) are the documented standing state —
those cases have no committed `gold/` baseline and verify nothing.
