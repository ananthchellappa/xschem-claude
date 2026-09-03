# 1259 — the value gate accepts a published zero, so a `savecurrents` run still declutters

Status: **PARTIALLY FIXED by item A6-b**, 2026-09-02 — the `dims=0` flavour is
closed, the flavour xschem's own simulate command produces is **not** (issue
**1263**) · Branch: `fluid-editing`

> ⚠ **NOT LANDED. The fix below was implemented, built and verified, then its
> write-up agent destroyed `src/save.c`'s half with `git checkout -- src/save.c`.
> The code is preserved in
> `doc/claude/op_param_batch/A6_working_tree_UNVERIFIED.patch` and in the working
> tree; PLAN.md's A6 entry says what to do first. Everything recorded below was
> measured and is correct.**

Related: **1244**, ruling **D-6**, invariant **I3**, item **A5-a**

## The defect, in one sentence

Item A5-a's gate asks whether a block row carries *anything after the `=`*; a raw
that publishes a column of `0.0` renders `zid = 0`, so the device is decluttered
on a number that carries no information — which is the shape of "got OP numbers"
D-6 was meant to exclude.

## Measured, first-hand, 2026-09-02, against the A5 binary

```
C2 vectors            = i(m1[zid]) | m1[zgm]
C2 raw loaded         = 0
C2 op_annot::text M1  = <<zid = 0|zgm = 0|>>
C2 mask 1 texts       = M1 VCW=1u PD {zid = 0} {zgm = 0}
C2 mask 9 texts       = M1 {zid = 0} {zgm = 0}
```

`VCW=1u` and the pin label `PD` are hidden in exchange for two zeros.

## Why it is a real PDK case, not a fixture artefact

`.option savecurrents` publishes `sky130` terminal currents `ig` / `is` / `ib` as
**0**, and `save [ib]` yields a `dims=0` column of `0.0` — both recorded in
`doc/claude/code_analysis/1244_op_param_list_measurements.md`. A user who runs
with `savecurrents` and registers those rows therefore gets a decluttered sheet
whose whole annotation is zeros.

## Not a regression, and not obviously wrong

Item A3's gate opened here too (a non-blank block), so nothing got worse. And
`::op_annot::eng_or_blank` prints a **measured** `0.0` as `0` deliberately: a
zero that the simulator actually reported is a fact about the circuit, and
invariant **I3** says a *missing* vector renders blank — it does not say a
measured zero should. Suppressing zeros would make a legitimately-zero current
indistinguishable from an absent one, which is the failure I3 exists to prevent.

## Why item A5 did not act on it (ladder L1, invariant I3)

The distinction the gate would need is **absent vs. zero**, and that distinction
does not exist in the block string A5-a reads — by design, because reading it
from a second source is issue **0466** re-opened (see the comment above
`annot_block_has_value()` in `src/actions.c`). Making it visible means the
*minter* publishing an absence count, i.e. the `::op_annot::dropped` side-channel
shape in `src/op_annot.tcl` — a file item A5 does not own, and a change that
belongs with item **B1**'s backend seam, where "a zero-length or `dims=0` vector
is **absent**, not zero" is already the stated rule.

**Rejected alternative:** treating the rendered string `0` as blank in the C
helper. It cannot tell a measured zero from an absent one, so it would suppress
the declutter on a device that really is at zero bias — a wrong answer in the
other direction, and one the user can never diagnose from the screen.

## Still open (the question a later item must put to the user)

Should a device whose every published OP number is **0** count as "got OP
numbers" for ruling D-6? If not, the fix is B1-shaped: `op_annot::text` (or
`op_param_set`) must distinguish an absent vector from a zero-valued one and the
gate must read that distinction, not the rendered digits.

---

## PARTIALLY FIXED — item A6-b, 2026-09-02. ⚠ READ THE LIMIT BEFORE THE FIX.

### The three states, and where each ended up

**Before** (Measure agent, driven on A5's binary):

```
PROBE 1259 dims=0 xschem raw value = 0
PROBE 1259 dims=0 block = zid = 0|zgm = 0|
PROBE 1259 dims=0 mask9==mask1 (1 == gate correctly CLOSED on an ABSENT value; 0 == THE DEFECT) = 0
PROBE 1259 real-0.0 mask9==mask1 (0 == gate correctly OPEN: a real 0 is a measurement) = 0
PROBE 1259 absent-vector block = zid =|zgm =|
PROBE 1259 absent-vector mask9==mask1 (1 == already correct, A5's gate) = 1
```

| state | before | after |
|---|---|---|
| (1a) no column at all | blank, gate closed — already correct (A5-a) | unchanged |
| (1b) a `dims=0` column | `zid = 0`, **gate opens** — the defect | **blank, gate closed** |
| (1b′) an unsatisfiable card on the `-r` writer | `zid = 0`, gate opens | **unchanged — see the limit** |
| (1c) a genuinely zero-**length** vector | never reaches xschem | unchanged (issue **1264**) |
| (2) a real computed 0.0 | `zid = 0`, gate opens — correct | unchanged, deliberately |
| (3) a normal value | gate opens | unchanged |

### What changed

**The gate was not touched. It was already correct.** The defect was one rung
upstream and is a plain invariant **I3** violation — xschem rendered a
fabricated `0` for a vector the simulator did not compute. Ladder rung **L1**.

* `src/save.c` `raw_line_dims_zero()` — the one anchor for the `dims=0` token,
  parsed out of the **third tab-separated field** of a `Variables:` line, on the
  `raw_header_case_mode()` precedent. `src/save.c:1057`'s
  `sscanf(line, "%*[\t]%d%*[\t]%[^\t]", &i, varname)` reads index and name and
  stops at the next tab, which is why the carrier was being thrown away.
* `Raw.dims0` — one byte per column, allocated / grown / freed exactly where
  `cursor_b_val` is, and **shifted** in `raw_deletevar()`, which `cursor_b_val`
  is not (filed as **1262**).
* `raw_vector_absent()` — the single exported predicate. **This is the seam item
  B1 inherits**: B1's own rule ("a zero-length or `dims=0` vector is absent, not
  zero") is answered here, once, rather than re-derived. Invariant **I1**.
* `src/scheduler.c`'s `raw value` **annotation fall-through** gains one term.
  The **numbered-point** read (`xschem raw value <v> 0`) deliberately still
  answers `0` — that arm is data inspection, not annotation.

**Rejected**, and both were forbidden: treating the rendered string `0` as blank
inside `annot_block_has_value()` (it would hide a genuinely cut-off device);
asking a second source from inside the gate (that is issue **0466** re-opened,
and row A35 reds on it). Also rejected: keeping the `dims=0` name out of
`Raw.table` so `get_raw_index()` answers −1 — one file smaller, far wider in
reach, and it **leaks**, because `raw_deletevar()`'s re-index loop re-inserts
every later name.

### ⚠ THE LIMIT — issue 1263, and it is the literal headline of this issue

**`dims=0` is the detector for the `.control` + `write` flavour only.** On
**xschem's own shipped simulate command** — `ngspice -b -r "$n.raw" "$N"`,
`src/xschem.tcl:3854` — an unsatisfiable `.save` card, *including everything
`.options savecurrents` adds for a FET's `ig`/`is`/`ib`*, is written as an
**ordinary `current` column of 0.0 with no `dims=0` token at all**. Re-measured
by the write-up agent, ngspice 45.2, BSIM4:

```
        5       i(@m1[is])      current
        6       i(@m1[ig])      current
        7       i(@m1[ib])      current
$ grep -ac 'dims=' sc.raw
0
$ head -3 sc.err
Warning: unrecognized variable - @m1[is]
...
PT0 i(@m1[id]) = 0.00031215789
PT0 i(@m1[ib]) = 0
```

The only signal is on **stderr**, which xschem never reads. **So on that path a
`savecurrents` run still declutters.** Full record and fix options: issue
**1263**.

### Rows and sabotage

Rows **A45** (`dims=0`: `raw index` ≥ 0 so the column *is* in the file, `raw
value … -1` empty, block label-only, mask 9 == mask 1) · **A46** (a real
computed 0.0, same zeros, type field alone removed: `raw value` = 0, block
`zid = 0`, device **is** decluttered — the row that reds a fix collapsing (1)
and (2) toward *absent*) · **A47** (a normal value) · **A48** (the seam, plus
the numbered-point data-inspection leg).

Sabotage: `SB-A6b-ALWAYS-ABSENT` (`return 1;` — the forbidden collapse toward
absent) → 27 red in the owned suite, 3 in `test_spice_get_node_0861`, 64 in
`test_op_annot`. `SB-A6b-NOPARSE` → **A45 only** and `SB-A6b-NUMBERED` → **A48
only**: two coverage holes, filed as **1267**.

### Still open

* **1263** — the `-r` writer flavour. The headline case, on the path xschem uses.
* **1264** — the zero-**length** flavour never reaches xschem at all.
* **1265** — the absence rule reached one of three readers of `cursor_b_val[]`.
* The user-visible change is **unratified**: a parameter that used to print `0`
  now prints blank. On the user's ruling queue.

---

## ITEM B1's ANSWER, IN WRITING — 2026-09-03. **NO, `op_param_set` DOES NOT CLOSE THIS ISSUE.**

> ✅ **UPDATE, SAME DAY: THE SEAM IS IN THE TREE AFTER ALL.** The driver re-did
> B1 from the preserved patch, fixed both blockers and landed it — 37 → 49
> checks, ALL PASS. So everything below is now a description of live code, not
> of a patch file, with **one correction**: the answer dict has **five** keys,
> not four. `nonfinite` was added, carrying `{<rawdev> <param> <text>}` triples
> for columns the raw DOES hold on a device that did not converge (issue 1272).
> That does not change this issue's answer, which is still NO, and the
> paragraph below explaining why is unaffected.
>
> ⚠ *The following was written while it was still reverted:* Item **B1** built it,
> passed every tier and its own 37-check suite, was then **refuted by its
> adversary pass on a separate defect** (issue **1272** — it read through
> `op_annot::raw_or_blank` without `op_annot::_finite`, so a binary raw carrying
> a NaN returned `nan` in the **value** bucket) and was **reverted**. The code is
> preserved as `doc/claude/op_param_batch/B1_working_tree_REFUTED.patch`
> (applies cleanly to `9f1d9153`); the record is
> `doc/claude/op_param_batch/receipts/B1.md`.
>
> **What follows is therefore B1's measured DESIGN answer to this issue, not a
> description of code you can call today.** Every sentence of it survived the
> refutation — the defect was in how a value was read, not in what the seam says
> about absence — so it stands as the answer this issue asked for, and the
> reconstruction should keep it. **One correction it forces:** with 1272 fixed, a
> **non-finite** value is a third outcome, distinct from both "computed" and
> "the column is not there", and `absent` must not quietly absorb it.

This issue names the honest fix as B1-shaped — *"`op_param_set` publishes absence
as a first-class answer"* — and item B1's brief obliges B1 to say plainly whether
it does. It does publish absence as a first-class answer. It does **not** close
this issue, and the two statements are not in tension. Three separate reasons,
each measured rather than reasoned:

### 1. Absence IS now first-class, and here is exactly what to call

`ase::backend::ngspice::op_param_set <devpath>`, reached through the one
dispatch as `[ase::backend_hook ngspice op_param_set]`, returns a dict with four
keys, and **two** of them answer this issue's question:

| key | what it carries |
|---|---|
| `absent` | ordered `{<rawdev> <param>}` pairs — every column the raw **named** and the simulator **did not compute**. A device whose whole annotation is absences comes back with an **empty** `devices` entry and a populated `absent`. |
| `complete` | the honesty flag as **data** (DD-1's corollary): `0` today, because `op_param_enumerable` **declares** that stock ngspice has no wildcard operating-point save. So the pairs are what the run saved, never everything the device has. |

The other two keys are `devices` (ordered `{<rawdev> {{<param> <value>} ...}}`)
and `state` (`no_devpath` | `no_raw` | `not_op` | `not_annotated` | `ok`).
**`absent` is populated only in state `ok`**, and that is not fastidiousness:
measured on this tree, `xschem raw value <v> -1` is empty **for every vector**
until `update_op()` has published, so a seam that filled `absent` outside `ok`
would report *"the simulator did not compute id"* about a run nobody had
annotated. Rows `A1`, `A1c`, `A2`, `A3`, `G1`, `G2` of
`tests/headless/test_rdw_seam_1245.tcl` are that contract.

A genuinely computed `0.0` is still returned **as `0`, in `devices`, never in
`absent`** (row `P3`). A transistor that is off has `id = 0` and that is a
measurement — the same rule this issue's own "Rejected alternative" paragraph
states, kept on B1's side of the seam.

### 2. But A5-a's gate cannot read it, and that is a language boundary, not an omission

The declutter gate is `annot_instance_annotated()` → `annot_block_has_value()`
in **C** (`src/actions.c`), and it reads the **rendered block string**. Reaching
`op_param_set` from there means a `tcleval` from inside the gate — which is
issue **0466** re-opened (row A35), the thing this issue's own "Rejected"
paragraph already forbids, and spec landmine 13. B1 adds a Tcl seam a Tcl caller
can read; it does not, and may not, hand the C gate a second source.

**And it would buy nothing on the flavour A6-b already closed.** For the
`.control` + `write` writer the `dims=0` case is closed *at the mint*:
`op_annot::raw_or_blank` answers `{}`, the row renders `zid =` blank, and the
gate stays shut (row A45 of `test_annot_declutter_1244`). `op_param_set` adds no
information there.

### 3. On the flavour that is still open, `op_param_set` is blind for the same reason everything else is

On xschem's shipped `ngspice -b -r` command an unsatisfiable `.save` card
arrives as an ordinary `current` column of `0.0` **with no `dims=0` token at
all** (issue **1263**, re-measured 2026-09-03: `grep -ac 'dims=' q11.raw` = 0,
the only signal on stderr). `op_param_set` reads the raw through
`raw_vector_absent()` like everything else, so on that writer it reports the
fabricated zero as a value, exactly as `op_annot::text` does. **The carrier is
not in the file.** No seam on the read side can invent it; issue 1263 is where
that is fixed, at simulate time.

### What a future item would have to call

To ask *"did this device get real OP numbers, or only absences?"* from **Tcl**,
with a raw loaded and annotated:

```tcl
set ans [[ase::backend_hook ngspice op_param_set] $devpath]
# real numbers?      [dict get $ans devices]   non-empty
# only absences?     [dict get $ans devices] empty AND [dict get $ans absent] non-empty
# nothing to say?    [dict get $ans state] ne {ok}
# and ALWAYS render  [dict get $ans complete] == 0 means "what the run saved,
#                    not everything the device has" (DD-1)
```

Its **caller must be in Tcl and must not be the C gate.** The natural home is
the mint — `src/op_annot.tcl` — publishing a per-instance absence count the C
side can read the way it already reads a rendered string, i.e. the
`::op_annot::dropped` side-channel shape this issue named a year of work ago.
That is still an item nobody has taken, and it is still the fix.

### Status, restated

**Unchanged: PARTIALLY FIXED by A6-b.** B1 did not move it. The user-ratifiable
question this issue records — *should a device whose every published OP number
is `0` count as "got OP numbers" for ruling D-6?* — is **still open and still
the user's**, and B1 deliberately did not answer it: A5-a is Feature A and
Feature A closed at commit `4f711e80`.
