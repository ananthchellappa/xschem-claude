# 1283 — three things `test_rdw_window_1245.tcl` claims to fence and does not

**Filed by:** item **B3**, 2026-09-03, against **B3's own new suite**. Found by
B3's sabotage agent (Verify-B) and confirmed by the adversary (Verify-C).
**FILED, NOT FIXED.**

**Status:** **FIXED by item B2d, 2026-09-04** — all three gaps, each with the
sabotage it now catches recorded. See §"Fixed by item B2d" at the end. When
filed, the suite was **ALL PASS 32 (`--nogui`) / 42 (`:99`)** and eight
of eight planned sabotage variants were caught. These are the gaps *behind* that
number — B1's lesson one item later: **a green count is a statement about the
fence, not about the code.**

---

## 1. Gap A — newest-first STORE order is fenced only on the display arm

**The measurement.** Sabotage `SB-OLDEST-ON-TOP` reverses `rdw::_insert_index`
from `1.0` to `end`, which flips **both** the pane insert **and** the prepend in
`rdw::push`, so `::rdw::blocks` becomes oldest-first. Result:

* `--nogui` arm: **ALL PASS (32 checks)** — the reversed store is invisible.
* `:99` arm: 2 FAILED — `W3`, `W3b`, both of which are widget rows.

So the accept row *"newest dump on top"* has **no headless witness at all**.
Every `--nogui` run, and `full_audit.sh`'s nogui leg, would pass with the store
reversed.

**Why the row that should have caught it does not.** Row `Q1b`
(`test_rdw_window_1245.tcl:780-785`) is titled

> `Q1b the dump is pushed onto ::rdw::blocks, newest first, on BOTH arms`

and its body is

```tcl
  [list [expr {[info exists ::rdw::blocks] ? 1 : 0}] \
        [expr {[info exists ::rdw::blocks] && [llength $::rdw::blocks] >= 1
               && [lindex $::rdw::blocks 0] eq $Q1_BLK ? 1 : 0}]] \
  {1 1}
```

It pushes exactly **one** block and then asserts that block is at index 0 — true
under either ordering. **The row's name claims a property its body does not
test.**

**Repair, cheap and obvious.** Push a second, distinct block in `Q1b` and assert
`[lindex $::rdw::blocks 0]` is the **second** one. Two lines.

**Second witness, same hole from the other side.** Row `W1b` (*"the stored dumps
SURVIVE the close, and a reopen paints them again"*) was predicted red under the
same sabotage and stayed **green**: it asserts the blocks survive a close but
never asserts their **order**.

## 2. Gap B — the union's cross-bucket ORDER is unfenced on both arms

`src/rdw.tcl`'s own comment promises the row set is built in

> first-appearance order across `devices` → `absent` → `nonfinite`

Reversing `rdw::_rowdevs` so `absent`/`nonfinite` devices are listed **before**
`devices` devices passes **all 32 headless and all 42 display checks**. No row
holds the promise the file makes.

Related and also unasserted, measured while filing: **column order within a
device is bucket order, not raw-file order.** A raw ordered `id`, `ib`(dims=0),
`vth` renders `id`, `vth`, `ib` — measured values first, then non-finite, then
absent. That looks deliberate (it groups the blanks together, which reads
better), but it is stated nowhere and asserted nowhere, so a later crew cannot
tell the design from the accident. **One row keyed on a mixed answer closes both
halves.**

## 3. Gap C — the inert-button message is fenced only on the display arm

`rdw::status` was split precisely so the inert path is drivable headless
(`::rdw::statusmsg` is set whether or not a widget exists). But the only row that
asserts an inert button *says* anything is `W4b`, which is inside the
Tk-guarded section. Making `rdw::status` a no-op passes the full 32-check
headless run.

## 4. Two predicted reds that did NOT appear, recorded so the matrix is honest

Neither is a defect; both are predictions that over-claimed a row's reach, and
both are the kind of thing that rots into a false sense of coverage if left
unwritten.

* **`SB-NO-UNION` was predicted to red `F5` and did not.** `F5`'s fixture puts
  its `absent` column on a device that **also** has entries in `devices`, so the
  device survives a devices-only row walk and `F5` never exercises the union.
  `F6` and `Q3` are the **sole** fences on the union rule. If either were ever
  weakened, the union would be unfenced with `F5` still green.
* **`SB-HONESTY-ALWAYS` was predicted to red `F3` and did not** — correctly.
  `F3`'s answer carries `complete 1`, so an always-emit variant emits nothing for
  it either. `F11` is the real and only fence on *"no non-ok block carries the
  incompleteness sentence"*, and it fired.

## 5. What is NOT wrong with the suite

Recorded so a later reader does not over-correct: the `--nogui` arm is **not**
vacuous (32 of 42 checks run headless, including every renderer row and every
seam row; only section `W` skips), `N2` proves no Tk runs at source time
**behaviourally** by sourcing the file into a bare `interp create` slave rather
than by grep, and the structural rows (`H3`, `S1`) read the **loaded proc** via
`rw_body`, not just the file, so a hand-built device name that uses none of the
forbidden literals is still caught.

## 6. Still open

All three gaps. None was repaired in B3 because each is a **new row in a suite
that is already green**, and adding rows to close a fence found by one's own
sabotage pass is the kind of same-item self-marking this batch has been careful
about; they are named here so item **B4** — which touches this suite by its own
Files cell (`rows in B3's suite`) — closes them as it goes.

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **FIXED**, 2026-09-03. All three fences now fence, and each is proved by its own sabotage.)


**No production code changed for this issue.** All three were missing *fences*,
not defects, so the red-before proof is the **sabotage run**, never the shipped
tree — which is this issue's own point and the batch's recurring lesson: *a
suite fences the questions its author thought of, and a green count is a
statement about the FENCE, not about the code.*

## Gap A — newest-first store order, which had NO headless witness at all

`Q1b` was titled *"newest first"* and pushed exactly **one** block, then
asserted it was at index 0 — true under either ordering. **Rewritten** to record
the store length, push a **second, distinct** block, and assert that the new
block is at index 0, `$Q1_BLK` is at index 1, and the length grew by exactly one.

```
SB-OLDEST-ON-TOP  (rdw::_insert_index -> end)
  before B2a : ALL PASS (32 checks) --nogui   /  2 FAILED (40 passed) on :99
  after  B2a : 1 FAILED (42 passed) --nogui   /  3 FAILED (50 passed) on :99
```

**That is the headless witness the accept row asked for.** Every `--nogui` run,
and `full_audit.sh`'s own nogui leg, would previously have passed with the store
reversed.

## Gap B — the union's cross-bucket order, unfenced on BOTH arms

New row **F16**, one mixed answer closing both halves: three devices, one in
each bucket, and one device carrying all three kinds. It asserts
`rdw::_rowdevs` answers `@m.x1.mA @m.x1.mB @m.x1.mC` (the *devices → absent →
nonfinite* first-appearance order `src/rdw.tcl`'s own comment promises) **and**
that within one device the columns render measured, then `(did not converge)`,
then blank — bucket order, not raw-file order, which was true and stated
nowhere.

```
SB-REVERSE-UNION  (rdw::_rowdevs, absent/nonfinite appended first)
  before B2a : ALL PASS (32) --nogui  AND  ALL PASS (42) on :99
  after  B2a : 1 FAILED (42 passed) --nogui  /  1 FAILED (52 passed) on :99
```

## Gap C — the inert-button message, fenced only on the display arm

New row **Q9**: drive `rdw::inert Delete` and `rdw::inert Save` with no widget
anywhere and assert `::rdw::statusmsg` names the button and the item that wires
it, that the two differ, and that the variable is clearable. `rdw::status` was
split for exactly this and it already worked headless — the row simply did not
exist. W4b on the display arm is the twin it is copied from.

```
SB-STATUS-NOOP  (rdw::status -> no-op)
  before B2a : ALL PASS (32 checks) --nogui
  after  B2a : 1 FAILED (42 passed) --nogui  /  2 FAILED (51 passed) on :99
```

## Suite size

`tests/headless/test_rdw_window_1245.tcl` grew **32 → 43** headless checks and
**42 → 53** on `:99`. It did not shrink.

## Why this was reverted

**This issue's own fix was not refuted, and nothing below was measured wrong.**
It was reverted as **collateral**. Item B2a was implemented as one 2,506-line
diff across four files; the adversary pass refuted the batch's central claim on
three *other* issues — **1277**, **1281** and **1284** — and the write-up agent
reproduced all three independently before deciding. Splitting a diff that size
into a "sound" half and an "unsound" half at write-up time would have committed
a code change that no Measure, Verify-A, Verify-B or Verify-C pass had ever
seen, which is precisely the failure mode this batch has already paid for in
items B1, B2 and B3.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` applies clean to
`825cd3bd`. The next crew's job is **apply → fix the three named holes →
re-verify**, and this issue's portion should survive that pass unchanged.

---

## Item B2a-2 — REVERTED A SECOND TIME, 2026-09-03, AGAIN AS COLLATERAL

**This issue's own fix was still not refuted.** Item **B2a-2** re-applied
B2a's patch unchanged, re-fixed the three holes, added ruling **DD-6**'s display
key, and went green everywhere — store **39→71**, RDW window **32→49** headless
and **42→59** on `:99`, `test_op_annot` **485/492** and
`test_annot_declutter_1244` **134** all unmoved, audit back at the 367/12/0/2
baseline with an empty non-PASS diff.

**It was reverted anyway**, because the adversary refuted the central claim on
**1277**, **1281** and **1285** and the write-up agent reproduced **four**
attacks first-hand. Same reasoning as the first revert: the diff was one
2,838-line change across eight files, and splitting it at write-up time would
commit code no verification pass had ever seen.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` (md5
`1977a39e5d419d31fcbbbc3932c2606f`, 3,573 lines, eight files) **applies clean to
`849f2231`** — verified with `git apply --check` in both directions. It contains
**both** attempts: B2a's six sound fixes *and* B2a-2's re-fixes. This issue's
portion should survive the third pass unchanged; apply the patch and fix only
what §"Still open after B2a-2" in **1277**, **1281** and **1285** names.

---

# Fixed by item B2d, 2026-09-04 — all three, each with its sabotage

**File:** `tests/headless/test_rdw_window_1245.tcl` only. **No production
change**: all three are missing FENCES, not code defects, so the shipped tree is
green before and after and **the sabotage IS the red-before proof.**

Every variant below ran as a **proc override in a scratch wrapper that sources
the suite** — the repo was never mutated, md5 verified identical before and
after each run (trap 3, the one that voided a B2c agent's numbers).

## Gap A — newest-first store order had no headless witness

| | before (HEAD's suite) | after |
|---|---|---|
| `SB-OLDEST-ON-TOP` (`_insert_index` → `end`) `--nogui` | **ALL PASS (32)** | **1 FAILED — Q1b** |
| the same on `:99` | 2 FAILED — W3, W3b | 3 FAILED — Q1b, W3, W3b |

`Q1b` was **rewritten in place**, keeping its name. Its title already claimed
*"newest first"* while its body pushed ONE block and asserted index 0 — true
under either ordering. It now records the length, pushes a SECOND distinct
block, and asserts it lands at index 0, the first is at index 1, and the length
grew by exactly one. *(L2; rejected: adding a `Q1c` beside it and leaving the
false title standing next to a true row, which is this issue's own thesis.)*

## Gap B — union order was unfenced on BOTH arms

`SB-REVERSE-UNION` (`_rowdevs` appending the `absent`/`nonfinite` devices before
the `devices` keys) passed **ALL 32 headless AND ALL 42 display checks** when
filed. It now reds **F16** on both arms.

F16 locks two things: the union is built `devices` → `absent` → `nonfinite` in
first-appearance order, **and** within one device the columns are measured, then
non-finite, then absent — bucket order, not raw-file order. That second half was
true and stated nowhere. **If a later item wants raw-file order, F16 is the row
that will say so; do not weaken it to make that change easier.**

## Gap C — the inert-button status line was display-arm only

`SB-MUTE-STATUS` (`rdw::status` → a no-op) passed all 32 headless checks and red
only `W4b` on `:99`. It now reds **Q9** headless as well: `rdw::inert Delete` and
`rdw::inert Save` each set `::rdw::statusmsg` naming themselves and the item that
wires them, the two differ, and the variable clears — with no widget anywhere.

## The suite

**32 → 52 (`--nogui`)** and **42 → 62 (`:99`)**, additive only: a row-ID diff
against `git show HEAD:` shows **0 removed**, and every pre-existing row (S0, M1-M3,
N1-N3, H1-H4, F1-F13, Q1-Q5, W0-W5, S1, S2) still runs. Q1b is the one row whose
body changed, in place.

## Still open

Nothing from this issue. The lesson it was filed for is not closed by it: **a
suite fences the questions its author thought of.** B2d's own adversary found a
sixth answer shape that F20 and F25 crossed on either side and neither caught
(issue 1284's `state` echo), which is this issue happening again one section
over — now fenced by **F29**.
