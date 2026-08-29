# 0836 - `update_op()` SIGSEGVs on a zero-point database, reachable from a shipped verb

**Status:** **RULING SETTLED 2026-08-29** (see "RULING, 2026-08-29" at the foot of this file) — the rule debt is answered; the `look` debt on the wording stays queued and one follow-up code change (the refusal sentence) is owed. **FIXED (narrow) 2026-08-26.** `update_op()` now refuses a zero-point
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

---

# RULING — DECIDED 2026-08-29 (delegated batch; user: "decide the 23, leave 0861 and 0299 for me")

## The ruling

**NARROW IS RATIFIED. The reader keeps attaching a zero-point results file; the
refusal stays at the annotator only.** Specifically, and as instructions to the
codebase:

1. **Do NOT add a reader-level refusal.** `xschem raw read` must keep returning 1
   for a well-formed zero-point raw, and the database must keep attaching.
2. **`xschem raw loaded` keeps answering the hierarchy level** at which the
   database is attached, exactly as for a good database (row `R6c` stands).
3. **`xschem raw points` keeps answering `0`** — that is the discriminator a
   caller acts on (rows `R6b`, `R6d`, `R6f` stand).
4. The `update_op()` guard on `xctx->raw->allpoints <= 0` (`src/save.c:2198`)
   **is the ruled shape** and stays where it is, before `annot_p = 0`.
5. **Separately: `backannot_refuse_empty()`'s sentence is rewritten** — see
   "The sentence" below. This is the one half of this ruling that moves code.

Nothing already shipped is undone by (1)-(4). `test_zero_point_raw_0836.tcl`
(648 lines) and `test_zero_point_pos_at_0852.tcl` are unaffected.

## Why narrow, and why it is not a close call

**CADENCE OR NOTHING settles it.** Watching a transient build while the run is
still going is ordinary Virtuoso/ADE practice. The wide option — refuse the read
outright — does not merely decline to ship that today; it makes it unreachable,
because nothing can plot a file that will not attach. An option whose entire
benefit is "stock XSCHEM never had to think about this" is an argument against
itself under the standing ruling.

**Measured blast radius of the wide option.** `sch_waves_loaded()`
(`src/draw.c:2834`) gates every graph path in `draw.c` — `:3722`, `:3984`,
`:5828`, `:5970`, `:6594`, `:7054`, `:8308`, `:9134`, `:9142`, `:9168`, `:9291`
all return early on `-1`. Refusing the read (or making `raw loaded` answer `-1`,
which is the same ruling wearing a different hat) stops a running simulation's
waveform rendering everywhere at once. That is a large, permanent loss bought
with nothing.

**The safety argument the wide option rested on is spent.** It was written while
a zero-point database still killed the process. It no longer does: three guards,
three call sites, one input — `update_op()` (this issue), `get_raw_value()`'s
lower bound and `raw_get_pos()`'s empty-dataset refusal (0852, fixed
2026-08-26). Ruling wide would demote those to belt-and-braces; it would not
remove a live crash, because there is none left to remove.

**What narrow leaves open is separately owned and does not hinge on this.**
0853 (the `raw switch` gate reads `allpoints` off the OUTGOING database) is a
mixed-predicate bug that must be fixed whichever way this went; 0855 (the viewer
readout mid-run) exists only because 0852 was fixed and has already shipped its
option (a). Neither becomes cheaper under the wide ruling.

## The sentence — REWRITE IT (this part implies a code change)

The shipped text (`src/save.c:1652`) is:

> `backannotation: '<path>' holds no simulation points yet -- a spice raw file`
> `reports 'No. Points: 0' from the moment its run starts until the moment it`
> `ends, so while the simulation is still running there is nothing in it to`
> `annotate onto the schematic`

Three defects, each against a ruling already standing — so **no new ruling is
needed for the rewrite, only the instruction to do it**:

1. **PLAIN ENGLISH.** `backannotation:` is the program's own vocabulary (0886
   removed exactly this class of prefix elsewhere and did not reach the two C
   mints in `save.c`). `'No. Points: 0'` and "a spice raw file" are file-format
   internals; the user sees a menu item and a results file, not a header field.
2. **No remedy.** The standing ruling is "say what happened AND what the user
   can do about it". This sentence says only what happened.
3. **It over-claims, and INTENT OVER MECHANISM makes that the sharpest of the
   three.** It asserts "while the simulation is still running". A zero-point
   file is *not* proof of a live run: ngspice backfills `No. Points:` only at
   the end, so a run that was killed or died leaves that header on disk
   **permanently**, and `xschem raw read <f> op 999 1000` manufactures the same
   state with no simulator involved at all. A user whose run crashed twenty
   minutes ago is currently told it is still going, and told to do nothing.

**Ruled replacement shape** (words to this effect; the exact final wording is
still the user's `look` debt "0836 refusal sentence on the CIW", which this
ruling does NOT clear):

> `No results yet in '<file>'. A simulation writes its results only when it`
> `finishes, so there is nothing to put on the schematic. If the run is still`
> `going, wait for it to finish and annotate again; if it already stopped, it`
> `ended before saving anything -- open the run log to see why.`

Constraints on the edit, all of which the current mint already satisfies and
none of which may be lost: minted in ONE place per RULING D5-4 and returned to
callers; `dbname` handed to Tcl as a **variable**, never spliced (the measured
`}`-in-path execution hazard documented at `backannot_refuse_digital()`);
`static char msg[512]`; `dbg(0, ...)` unchanged so `--nogui` rows keep reading
it. Channel is unchanged — CIW via `ciw_echo`, matching its sibling.

**Note, not part of this ruling:** `backannot_refuse_digital()` eleven lines
above carries defect (1) identically ("backannotation: ... is a digital results
database"). Two sibling refusals in two registers would violate D5-4's spirit,
so the same pass should carry it — but it belongs to D5-3/0886, not here, and is
recorded rather than ruled.

## What was verified in the tree before ruling

- `src/save.c:2198-2201` — the guard is exactly as this issue claims:
  `if(xctx->raw && xctx->raw->allpoints <= 0) { backannot_refuse_empty(...); return 0; }`,
  sited after the `raw_is_digital` refusal (`:2120`) and before `annot_p = 0`.
- `src/save.c:1652-1668` — the sentence, verbatim, as quoted above.
- **No reader-level refusal exists.** Every `allpoints` site in `save.c`
  (`:1212 :1229 :1234 :1271-1277 :1466 :2451-2463 :3264-3302`) either sums,
  sizes or bounds; `:1466` assigns the count and rejects nothing. The read
  succeeds and the database attaches, which is what the narrow ruling claims to
  be ratifying.
- `src/draw.c:2834` + the eleven `sch_waves_loaded()` gates listed above — the
  measured cost of the wide option.
- `src/ase_window.tcl:4885-4931` (`ase::ui::run_finished`) — auto-plot and
  `annot_refresh_idle` fire only on `exitcode == 0`, i.e. **after** the run.
  So watch-it-fill is *permitted* by the narrow ruling, not yet *shipped* by
  ASE-L; the wide ruling would have foreclosed it before it was written.
- `tests/headless/test_zero_point_raw_0836.tcl` present, 648 lines.

## Debts

- The **`rule` debt for 0836 is discharged by this ruling.**
- The **`look` debt "0836 refusal sentence on the CIW" is NOT.** It is the
  user's eyes on the new wording once the rewrite lands, and it stays queued.

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29:

> **"decide the 23, leave 0861 and 0299 for me"**

A read-only audit had sorted the 57-entry ruling queue and classified 25 of the
questions as ones whose answer is cheap and obvious — things to be **decided**
rather than put to the user. **This debt was one of the 23** the user handed
over. (0861 and 0299 were kept back and are untouched.)

**This section is the settled answer, and it SUPERSEDES item (5) of the
"RULING — DECIDED 2026-08-29" section immediately above.** Items (1)-(4) of that
section are ratified word for word and nothing there is withdrawn; only the
prescribed replacement wording is replaced, for the reasons under "Why" below.
Nothing already shipped is undone by any part of this ruling.

### The ruling, as instructions to the codebase

**Ratified, nothing moves:**

1. **No refusal at the reading step.** `xschem raw read` keeps returning 1 for a
   well-formed results file that holds zero points, and the file keeps
   attaching. A simulation that is still running stays openable in the waveform
   window.
2. **`xschem raw loaded` is unchanged** — it keeps answering the hierarchy level
   the file is attached at, exactly as for a full file (row `R6c` stands).
3. **`xschem raw points` keeps answering `0`.** That is the discriminator a
   caller acts on (rows `R6b`, `R6d`, `R6f` stand).
4. **The guard in `update_op()` on `allpoints <= 0` (`src/save.c:2198`) is the
   ruled shape** and stays exactly where it is — after the digital refusal and
   **before** `annot_p = 0`, so nothing is published and `annot_p` stays -1.

**Moves code — the refusal sentence:**

5a. **ONE SENTENCE, MINTED ONCE.** This one state is currently described by two
   different sentences in two different languages: `backannot_refuse_empty()`
   (`src/save.c:1652`) in C, and `op_annot::db_attach`'s fallback string
   (`src/op_annot.tcl:1182-1184`) in Tcl. Per **RULING D5-4** that is one
   sentence: mint it in C, where the reason is known, return it to callers, and
   make `db_attach` carry that text through instead of substituting its own.
   The Tcl fallback goes in the same pass — not because its words are ugly but
   because **"it could not be read as a results file" is untrue** of a file that
   read successfully.

5b. **WHAT THE SENTENCE MAY CLAIM — only what is checkable.** Say that the
   results file has not recorded how many points it holds yet, so there is
   nothing in it to read. **Do NOT write "a simulation writes its results only
   when it finishes"** — that is false (the simulator writes data continuously;
   what it defers to the end is the point count in the header) and it
   contradicts the promise this same ruling makes about the waveform window.
   **Do NOT assert the run is still going.** A killed or crashed run leaves that
   header on disk forever, and `xschem raw read <f> op 999 1000` manufactures
   the identical state with no simulator involved at all.

5c. **THE REMEDY MUST BE TRUE FOR THE ANALYSIS IN HAND.** `xctx->raw->sim_type`
   is in scope at the guard, so pass it to the mint and let the sentence branch:
   - **transient** — do NOT say "wait and annotate again". Annotate Operating
     Point will never read a transient, by the user's own 0856/0872 ruling, so
     that advice dead-ends in deliberate silence eleven lines below this guard.
     Point at the thing that does work: read transient voltages at the waveform
     cursor with **Alt-Shift-6**, once the run has finished.
   - **op / dc** — waiting and annotating again genuinely works, so say that.
   - **either** — if the run has already stopped, it ended before recording
     anything; open **Simulation > Log** to see why. Name that menu item, not
     "the run log".
   If a branch is judged out of scope when the edit is made, **the minimum
   acceptable edit is to DELETE the remedy clause** rather than ship one that
   dead-ends. A sentence with no remedy falls short of the standard; a sentence
   whose remedy leads to silence is worse than both.

5d. **Unchanged constraints, all of which the current mint already satisfies and
   none of which may be lost:** one place per **D5-4**; `dbname` handed to Tcl
   as a **variable**, never spliced into a script (the measured `}`-in-path
   execution hazard); `static char msg[512]`; `dbg(0, ...)` kept so `--nogui`
   rows keep reading it; the channel unchanged — the CIW via `ciw_echo`. Drop
   the `backannotation:` prefix and the `'No. Points: 0'` file-format detail.
   `backannot_refuse_digital()` carries the same prefix defect but stays **out
   of scope here** — it is recorded against D5-3 / 0886.

5e. **The `look` debt "0836 refusal sentence on the CIW" stays queued**, and it
   now covers **both** surfaces — the CIW line and what the key chord and
   ASE-L's **Results > Annotate** say — because after 5a they are the same
   words. This ruling does not clear it.

**Worth filing separately, NOT ruled here:** whether a zero-point **transient**
should reach this sentence at all, or take the 0856 silence instead. Guard order
(the 0836 guard sits before the analysis-type guard) decides that today and
nobody chose it. Making the sentence analysis-aware per 5c settles the
user-visible half without touching guard order, so no shipped ruling is
disturbed either way.

### Why

**CADENCE OR NOTHING settles the main question.** Watching a transient build
while the run is still going is ordinary Virtuoso/ADE practice. The wide option
— refuse the read — does not merely decline to ship that today, it makes it
unreachable, because nothing can plot a file that will not attach. An option
whose whole benefit is "stock XSCHEM never had to think about this" argues
against itself under the standing ruling.

**Measured cost of the wide option.** `sch_waves_loaded()` (`src/draw.c:2834`)
gates every graph path in `draw.c` — `:3722 :3984 :5828 :5970 :6594 :7054 :8308
:9134 :9142 :9168 :9291` all return early on `-1`. Refusing the read, or making
`xschem raw loaded` answer `-1` (the same ruling wearing a hat), stops a running
simulation's waveform drawing everywhere at once.

**The safety argument for the wide option is spent.** It was written while a
zero-point database still killed the process. It no longer does: three guards,
three call sites, one input — `update_op()` here, plus `get_raw_value()`'s lower
bound and `raw_get_pos()`'s empty-dataset refusal (0852, fixed 2026-08-26).

**What narrow leaves open is separately owned.** 0853 is a mixed-predicate bug
that must be fixed either way; 0855 has already shipped its option (a). Neither
gets cheaper under wide.

**The sentence needed no new ruling — three standing ones already condemn the
shipped text.** PLAIN ENGLISH (`backannotation:` is program vocabulary,
`'No. Points: 0'` is a file-format internal); the "say what the user can do"
half of it (there is no remedy at all); and INTENT OVER MECHANISM, the sharpest
— the sentence asserts the run is still going, which a killed run makes
permanently false.

**What changed from the section above, and why.** Its prescribed replacement was
verified against the C mint only, and three things about the rest of the tree
break it: (A) the same state is already described by a **second, contradictory**
sentence in Tcl, so a wording pass on one string leaves the program giving two
answers about one file — the very thing D5-4 exists to stop; (B) its words state
a **false mechanism** ("a simulation writes its results only when it finishes"),
which the mid-run 868 KB and 2.9 MB raws measured in this issue disprove and
which contradicts this ruling's own headline; (C) its remedy, "wait for it to
finish and annotate again", **dead-ends on the commonest case** — the zero-point
file in front of a user is nearly always a transient, and the next press is
refused silently and deliberately by the analysis-type guard eleven lines below.
(D) "open the run log" names nothing the user can press; the surface is
**Simulation > Log**.

### What was verified in the tree

- `src/save.c:2198-2201` — the guard is exactly as claimed:
  `if(xctx->raw && xctx->raw->allpoints <= 0) { backannot_refuse_empty(xctx->raw->rawfile); return 0; }`,
  sited after the digital refusal (`:2120`) and before `annot_p = 0`.
- `src/save.c:1652-1668` — `backannot_refuse_empty()` mints the shipped sentence
  verbatim, reaches the CIW only through `ciw_echo`, and passes `dbname` as a
  Tcl **variable**, never spliced. `static char msg[512]`, `dbg(0, ...)` present.
- `src/save.c:1260` and `:1456` — `raw->annot_p = -1` on read, which is why the
  Tcl-side check answers "not annotated" after the guard returns 0.
- **No refusal exists at the reading step.** Every `allpoints` site in `save.c`
  (`:1212 :1229 :1234 :1271-1277 :1466 :2451-2463 :3264-3302`) sums, sizes or
  bounds; `:1466` assigns the count and rejects nothing. The read succeeds and
  the file attaches — which is the behaviour items (1)-(3) ratify.
- `src/op_annot.tcl:1182-1184` — the **second** sentence, in Tcl: "it could not
  be read as a results file, or it holds no operating point. If the simulator is
  still writing it, try again when the run has finished." It is substituted when
  `op_annot::_annotated` (`:791`) answers 0, which is exactly this state.
- **Correction to one surface claim.** The 6 / Alt-6 chord calls
  `::op_annot::db_attach` at `utils/annot_mode.tcl:1248` **without capturing its
  return**, so the chord does **not** speak the Tcl sentence. The only shipped
  consumer of that string is **ASE-L's Results > Annotate**
  (`src/ase_window.tcl:2429-2431`, wrapped by `ase::ui::annot_fail_msg` at
  `:2539` and echoed as an *error* line). So the measured "two paragraphs, one
  press" is Results > Annotate: the CIW note from C **and** that error line. On
  the chord the user gets the CIW note plus, on a mid-run **transient**, the
  chord's own 0857 unwind line — still two sentences about one press, by a
  different route. **This does not weaken 5a**; both texts describe the same
  state and both must come from one mint.
- `src/save.c:2226+` — the analysis-type guard sits eleven lines below the 0836
  guard, and its own comment states the refusal is silent by design: "no CIW
  line, no status line, no number on the schematic." This is what makes "wait
  and annotate again" dead-end on a transient.
- `src/ase_window.tcl:525` (`$top.mb.sim add command -label Log`) and `:4687`
  (window title "Simulation Log") — **Simulation > Log** is a real menu item the
  user can press.
- `src/draw.c:2834` plus the eleven `sch_waves_loaded()` gates listed above —
  the measured blast radius of the wide option.
- `src/ase_window.tcl:4885-4931` (`ase::ui::run_finished`) — auto-plot and the
  annotate refresh fire only inside the `exitcode == 0` arm, i.e. **after** the
  run. Watch-it-fill is *permitted* by this ruling, not yet *shipped* by ASE-L;
  the wide ruling would have foreclosed it before it was written.
- `git show b5d5b24f | grep backannot_refuse` — no hits. The 0886 plain-English
  pass never reached the two C mints in `save.c`, and the 0886 rule debt's six
  items do not include this sentence, so it is not covered elsewhere.
- `tests/headless/test_zero_point_raw_0836.tcl` present, 648 lines.

### Ratify or code change

**Both.** Items (1)-(4) **ratify shipped behaviour — nothing moves**;
`tests/headless/test_zero_point_raw_0836.tcl` and
`test_zero_point_pos_at_0852.tcl` are unaffected by them.

Item 5 **implies a code change, and it is FOLLOW-UP WORK NOT YET DONE**
(no code was touched by this ruling):

- rewrite the `my_snprintf()` text in `backannot_refuse_empty()`
  (`src/save.c:1652`) per 5b/5c/5d, taking the analysis type so the remedy
  branches;
- make `op_annot::db_attach` (`src/op_annot.tcl:1182-1184`) carry the C text
  through instead of substituting its own string, so ASE-L's **Results >
  Annotate** and the CIW say the same words;
- move any golden rows in `tests/headless/test_zero_point_raw_0836.tcl` that
  match the old string;
- recorded, not ruled: `backannot_refuse_digital()` carries the same
  `backannotation:` prefix defect and should follow under D5-3 / 0886.

### The adversary

An adversary ran against this decision: it **conceded items (1)-(4)** as
obviously right and **overturned item (5)** on three tree-verified counts
(a second contradictory sentence in Tcl, a false mechanism in the prescribed
words, and a remedy that dead-ends on transients) — its better answer is 5a-5e
above, which is what stands.

**The user may reverse this at any time; it was decided to spare their
attention, not to bind them.**
