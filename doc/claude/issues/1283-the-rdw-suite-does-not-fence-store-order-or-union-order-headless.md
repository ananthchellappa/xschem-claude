# 1283 — three things `test_rdw_window_1245.tcl` claims to fence and does not

**Filed by:** item **B3**, 2026-09-03, against **B3's own new suite**. Found by
B3's sabotage agent (Verify-B) and confirmed by the adversary (Verify-C).
**FILED, NOT FIXED.**

**Status:** open. The suite is **ALL PASS 32 (`--nogui`) / 42 (`:99`)** and eight
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
