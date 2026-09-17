# 1332 — the keys suite's SD rows drive a real modal on a fixed `after 100` and can false-red under load

**Status: FIXED** 2026-09-05, by item **P3** of the RDW repair batch. The
three rows now POLL for the dialog instead of betting on a fixed delay; rows
**SD5**, **SD6** and **SD7** were added and each reds under the old driver.
Measurements at the bottom of this file. Found by item **B5-3**'s Verify-A agent as a
1-in-134 intermittent, diagnosed and instrumented there. Subject:
`tests/headless/test_rdw_keys_1245.tcl` rows **SD1** (`:1794`), **SD2**
(`:1820`) and **SD3b** (`:1915`).

## The shape

Each SD row drives the real, grabbing `.rdw.scope` dialog with the tree's only
sanctioned modal-driving idiom (`tests/headless/test_ase_bus_bits_0159.tcl:258`,
rows BB34/BB35): a driver armed on `after 100`, plus an `after 5000` deadman so
`tkwait` always returns.

```tcl
after 100 {
  catch {set ::SD3B_SEEN [expr {[winfo exists .rdw.scope] ? 1 : 0}]}
  catch {set ::SD3B_GRAB [grab current]}
  catch {.rdw.scope.sc.broad invoke}
  catch {.rdw.scope.btns.ok invoke}
}
after 5000 {catch {destroy .rdw.scope}}
catch {.rdw.b.delete invoke}
```

The driver's delay is a **fixed 100 ms**, not a poll. If the dialog has not been
constructed by then, every `catch` inside the driver hits nothing, the deadman
cancels the dialog 4.9 s later, and the row reports an **all-zeros tuple** —
a false red, not a hang.

## The measurement

Observed once in 134 runs, during item B5-3's Verify-A pass:

```
RESULT: 1 FAILED (40 passed)
SD3b -> {0 0 0 {} 0 0 {}}   expected {1 1 1 {{id ids 0} {gds gds 1}} 0 0 {}}
```

The whole rest of that log was byte-identical to a passing run — only SD3b
moved. The all-zeros tuple is `SD3B_SEEN=0` + `SD3B_GRAB={}` + store unmoved +
nothing left behind, i.e. the driver fired before the dialog existed.

The real margin, instrumented on a COPY in a `/tmp` shadow tree with a 1 ms
poll (repo file md5-verified untouched), over 88 runs: the dialog appears
**3–6 ms** after the invoke, **max 19 ms** — a 5–30x margin against the 100 ms
timer.

The trigger was **cross-agent contention on the shared `:99` display**, measured
from file mtimes: the failing run occupied 20:50:09–20:50:11 while another crew
agent's `test_op_annot` ran on the same display from 20:50:02 to 20:50:15, with
two further concurrent agent processes live. That is the situation
`CLAUDE.md` issue **0990** says is not evidence.

It did not reproduce in **133** subsequent runs: 3+10 plain, 6 under deliberate
6-way CPU load, 4 in a window→keys pairing, 20 plain, 89 in the shadow tree, and
once inside a full audit (PASS). The write-up agent added a further **10** clean
runs (`pass=10 other=0`) after the tree was final.

## Why this is a test defect and not a product defect

Nothing about it points at `src/rdw.tcl`, `src/op_annot.tcl` or
`src/op_param_lists.tcl`. The deadman **worked** — the suite did not hang, so
issue **0803** is honoured. `CLAUDE.md`'s own rule applies:

> treat a bug that only `:0` can reproduce as a *test* defect too: the fix is to
> force the race deterministically (`test_calc_skeleton` S12), not to hope an
> environment supplies it.

## Recommended fix

Replace the fixed `after 100` in SD1, SD2 and SD3b with a **poll**: an `after 5`
re-arming itself until `[winfo exists .rdw.scope]`, then driving the widgets,
with the `after 5000` deadman kept unchanged. Deterministic on a loaded box, a
slower machine, or any run sharing an X display; and it fails LOUDLY (the
deadman still fires) rather than reporting a plausible zero tuple.

Rejected: widening the delay to 500 ms — the same race with a bigger number,
which is exactly what the rule above forbids; and serialising crew agents on
`:99` — a process rule that no suite can enforce.

## Acceptance

The three rows pass with the poll under deliberate load (a 6-way CPU spinner
plus a concurrent suite on the same display), and a deliberately never-built
dialog still reds within the deadman rather than hanging.

## Still open

The same fixed-delay idiom is used by `test_ase_bus_bits_0159.tcl:258`
(BB34/BB35), which is where the SD rows copied it from. Not measured flaking,
not touched here.

> **CLOSED 2026-09-17** by the harness-concurrency batch, item **E3** — see
> **THE RESIDUAL, CLOSED** at the bottom of this file.
> ⚠ The `:258` above had **already drifted when it was written**: the two
> drivers were at `:277` and `:285`. Cite the **`BB34-BB35`** anchor, never a
> line number — that block has now moved twice.

---

# THE FIX, AND WHAT IT WAS MEASURED AGAINST (item P3, 2026-09-05)

## It was not rare on the user's own server

The filing above says "once in 134 runs" on `:99`. **VERIFY #5 measured it
firing on 2 of 2 runs on the user's VcXsrv** (`$DISPLAY`, the `HC-Consult`
server of CLAUDE.md's three-server table) — SD3b on one run, SD2 **and** SD3b on
the other. Reproduced here: over four pre-fix runs on that same server this
session, **SD2 fired on one**, giving the recorded shape
`7 FAILED (67 passed)` = D1 + SD2 + RA1..RA5. That is why every `$DISPLAY`
count for this suite was unusable, and `$DISPLAY` is the only server that can
settle issue **1343**.

## Two losing shapes, not one — and only one of them was known

Both driven **deterministically** before anything was changed, by wrapping
`rdw::scope_dialog_build` in a scratchpad probe and spinning the **event loop**
for a fixed time (a busy-wait proves nothing: no timer can fire while Tcl is not
in the event loop). The repo file was never touched; `md5sum` verified.

**Shape A — the driver fires before the toplevel exists.** The known one.
Delay 300 ms *before* the build:

```
driver=fixed  FAIL  in 5004 ms  -> {0 0 0 {} 0 0 {}}   <- this file's own tuple
driver=poll   PASS  in  315 ms  -> {1 1 1 {{id ids 0} {gds gds 1}} 0 0 {}}
```

**Shape B — the driver fires after the build but before the keyboard moves.**
NOT in the filing, and it is the one that hurts. `rdw::scope_dialog` builds,
then `update`, then `grab set`, then `focus -force $w`. A driver that fires
inside that `update` finds `.rdw.scope` **already existing** — so a poll that
waited on `winfo exists` alone would have shipped the bug intact. Tk redirects a
key event to the **display's focus window**, not to the window the event names,
so SD2's Escape lands on `.drw` and **silently ends the user's canvas command
mode** — the exact thing SD2 exists to forbid. Delay 200 ms *after* the build:

```
driver=fixed  run1=0 (exp 1)  focus at drive .drw         dt 5000 ms
driver=poll   run1=1          focus at drive .rdw.scope   dt  205 ms
```

## The poll, and why its condition is the grab

`sd_arm` / `sd_poll_modal` / `sd_disarm`, defined in the SD section beside the
fixture. The poll re-arms on `after 5` until **`[winfo exists .rdw.scope]` AND
`[grab current] ne {}`**. That pair is exact rather than lucky:
`rdw::scope_dialog` runs `grab set` and `focus -force` with **no event loop
between them and `tkwait window`**, so a driver that sees a grab is running from
inside `tkwait` on a dialog that is fully modal and already holds the keyboard.

* Budget 900 × 5 ms = **4.5 s, deliberately inside the 5 s deadman**, so a poll
  that never finds its dialog gives up rather than driving whatever toplevel a
  later row happens to put on screen.
* The **deadman is unchanged** and still not optional (issue 0803).
* Both timers are now **cancelled when the row ends**. They were not: SD1's 5 s
  deadman was still armed while SD3b's dialog was up, one
  `catch {destroy .rdw.scope}` away from cancelling a dialog a later row was in
  the middle of driving. A second latent flake, removed on the way past.
* The delay was **not widened**, per this file's own recommendation.

## The three new rows, and that they are not decorative

**SD5** (shape A, 300 ms), **SD6** (shape B, 200 ms), **SD7** (a dialog that is
never constructed → the poll must give up on its budget and its script must
never run; plus a real dialog nobody drives → the deadman still ends it). Each
carries an elapsed-time leg, so a poll quietly reverted to a fixed delay cannot
pass by accident.

Verified non-vacuous on a **copy** of the suite whose `sd_arm` was reverted to
`after 100` (the copy was deleted and the repo file `md5sum`-verified
unchanged):

```
FAIL SD5 -> {0 0 0 {} 0 {} 1 0 1 0}          exp {1 1 1 {{id ids 0} {gds gds 1}} 0 {} 1 1 1 0}
FAIL SD6 -> {1 CANCELLED 0 .drw 0 {} 1 0 1 0} exp {1 CANCELLED 1 .rdw.scope 0 {} 1 1 1 0}
FAIL SD7 -> {CANCELLED 1 0 1 CANCELLED 1 1 0 {} 1} exp {CANCELLED 0 1 1 ...}
RESULT: 3 FAILED (74 passed)
```

**SD1, SD2 and SD3b passed in that same sabotaged run.** The old rows cannot see
this defect on a quiet `:99`; that is the whole reason it survived 134 runs.

## Acceptance, measured

| where | pre-fix | post-fix |
|---|---|---|
| `:99`, quiet | ALL PASS (74), 1-in-134 | **ALL PASS (77) × 12/12** |
| `:99`, **6-way CPU spinner + a concurrent `test_op_annot` on the same display** (this file's own acceptance clause) | **SD3b fired on 2 of 13** | **SD rows 0 of 13** |
| `$DISPLAY`, the user's VcXsrv | **SD2 fired on 1 of 4** here, 2 of 2 for VERIFY #5 | **SD rows 0 of 7** |

Under the CPU spinner **other** rows of this suite flake in both arms
identically — F1 F3 F4 B2 B3 B4 B5 V2 D1 CP1 RA1 RA2 RA3 RA6, measured
interleaved pre/post so the comparison is same-machine same-minute. Those are
pre-existing and **not** issue 1332; nothing about them is claimed fixed here.

The suite is also **faster**: the same drive takes 17 ms under the poll against
107 ms under the fixed timer, so the three converted rows give back more time
than they cost.

## What still fails on `$DISPLAY`, and it is not this

Steady and byte-identical across seven post-fix runs on the user's VcXsrv:
`5 FAILED (72 passed)` — **RA1, RA2, RA3, RA4, RA5**, which is issue **1343**
(item R4's raise). One run in seven also flaked **CU7**, pre-existing and
unrelated. **`$DISPLAY` is now a usable measurement for this suite**, which was
the point.

---

# THE RESIDUAL, CLOSED (item **E3**, harness-concurrency batch, 2026-09-17)

`test_ase_bus_bits_0159.tcl` — the file the SD rows copied the idiom **from** —
now polls too. Both drivers converted, three rows added (**BB36**, **BB37**,
**BB38**), display arm **40 → 43 checks**, headless arm unchanged at 23.

## The citation in this file was wrong in both directions

It said `:258` three times. The drivers were at **`:277` and `:285`** on the day
this was read, and the `BB34-BB35` block is at **`:387-407`** now. Nothing was
ever at `:258`. Cite the anchor, not a line.

## It is NOT CI-gated, and only one runner reaches it

Checked before touching anything, because the two previous companions both
turned out to be gated and both crews discovered it themselves:

* **`ci.yaml` does not name it.** The headless hard gate lists 15 suites
  (`AUDIT_MIN_PASS=15`) and this is not one; nor is it in the fluid-suites gate
  (`test_fluid_* / test_rotate_* / test_cadence_stretch_move /
  test_drag_keeps_selection`). `test_audit_classifier.tcl`'s `$GATED` agrees —
  15 names, not this one.
* **Not in `run_regression.tcl`'s `hcases` or `dcases`** (T1 never runs it,
  consistent with issue 1421, which lists `bus_bits_0159` among the 21 ASE
  suites outside T1), and **not in `full_audit.sh`'s `nogui_tests`**. It is
  reached **only** by `full_audit.sh`'s `ls "$HERE"/test_*.tcl` glob, in the
  default `--pipe -q --nolog` arm, on whatever display the audit arms — i.e. the
  **informational** audit step, which CI runs with `|| true`.

So the blast radius is the informational audit and the suite's own two arms.

## Two losing shapes, both driven deterministically, both red before the fix

Same method as item P3 above: wrap the real `ase::ui::bus_dialog_build` and
delay it by **spinning the event loop** (`vwait`), which is the only kind of
delay a timer can fire during. Rows added first, red observed, then fixed.

**Shape A — the driver fires before the toplevel exists.** Build delayed 300 ms,
driver reverted to `after 100`. Twice, byte-identical:

```
FAIL: BB36 -> {0 {} {} 0 {} 1 0 1 0 1}   exp {1 .asebusbits {{A[1]} {A[0]}} 0 {} 1 1 1 0 1}
FAIL: BB37 -> {0 {} 0 {} 0 {} 1 1 1 0 1} exp {1 .asebusbits 1 {{A[1]} {A[0]}} 0 {} 1 1 1 0 1}
FAIL: BB38 -> {{} 1 0 1 {} 1 1 0 {} 1 {} {}} exp {{} 0 1 1 {} 1 1 0 {} 1 {} {}}
RESULT: 3 FAILED (40 passed)      suite wall clock 5.92 s (green: 1.50 s)
```

Nothing seen, no grab, no bits, the `< 3000 ms` leg 0 — the deadman burned the
full ~4.9 s. This is P3's tuple in a different suite.

**Shape B — the window exists but the modal does not, and it PASSES.** The half
that matters, and it is **not** produced by the fixed delay. With the delay
moved between the build and the wrapper's own `grab set`, a poll keyed on
**`winfo exists` alone** gives:

```
FAIL: BB36 -> {1 {} {{A[1]} {A[0]}} 0 {} 1 1 1 0 1}
FAIL: BB37 -> {1 {} 1 {{A[1]} {A[0]}} 0 {} 1 1 1 0 1}
RESULT: 2 FAILED (41 passed)
```

Window **seen**, grab **empty**, `tkwait` **never entered**, and the **right
bits returned**. Before BB37 existed that shape was a silent pass: BB34's own
comment says it is there so "the grab/tkwait path itself is covered", and on
this path it covers nothing — `ase::ui::bus_dialog` destroys `$w` on OK and then
skips `tkwait` because its window is already gone. **Only the grab leg sees it.**

## ⚠ Two claims that had to be corrected by measurement

1. **The fixed `after 100` does not produce shape B here.** BB37's first draft
   said it did. Measured, the timer fires *before the toplevel exists* and the
   fixture degenerates into shape A (`{0 {} 0 {} …}` above). The comment and the
   check name now state the two results separately. An unmeasured mechanism
   asserted in a comment is the same defect as a detail string that describes
   the failure case unconditionally, one layer up.
2. **The focus leg is a guard, not the discriminator.** It reads **1 under both
   sabotages**, because the window manager hands the new toplevel the focus
   before the wrapper's own `focus $w.lf.list` runs. Kept, but it is not
   evidence of modality; the grab is the only leg that separates "inside
   `tkwait`" from "during the build's `update`". Said so in the file, so nobody
   reads it the way P3's SD6 comment reads on `.rdw.scope`.

## A second, latent defect removed on the way past — the same one P3 found

**BB34's `after 5000` deadman stayed armed all through BB35.** One
`catch {destroy .asebusbits}` from ending a dialog the next row was still
driving — and **BB35 expects `{}`**, so it would have passed on the deadman's
answer instead of Cancel's. Worse in the other direction: BB34's `after 100`
driver, firing late, presses `All`+`OK` on **BB35's** dialog and reds it. Both
timers are now cancelled by `bb_disarm` at the end of every row, and **BB38**
asserts the deadman handle no longer resolves.

## The poll, and why its condition is the grab

`bb_arm` / `bb_poll_modal` / `bb_disarm`, beside the fixture. Re-arms on
`after 5` until **`[winfo exists .asebusbits]` AND `[grab current] eq
{.asebusbits}`**. Measured, not assumed: a probe inside the live modal returned
`grab current` = `.asebusbits` and `focus` = `.asebusbits.lf.list`.
`ase::ui::bus_dialog` runs `grab set`, `focus` and `tkwait window` with **no
event loop between them**, so a driver that sees that grab is running from
inside `tkwait`.

* The grab is compared to the **window**, not to `{}` — P3's **SD8** lesson,
  adopted rather than re-learned.
* Give-up is a poll count **and** a wall-clock deadline (`deadman - 500`), P3's
  own correction: `after 5` is a floor, not a period.
* The **deadman is unchanged** (issue 0803) and the delay was **not widened**.

## Acceptance, measured

| arm | result |
|---|---|
| `:99` + openbox, clean | **`ALL PASS (43 checks)` × 12/12**, 1.50 s |
| `:99`, **6-way CPU spinner + a concurrent `test_op_annot` on the same display** (this file's own acceptance clause) | **8/8 `ALL PASS (43)`**, load avg 0.67 → 1.72 |
| `run_suites.sh -n 3` (bounded, gated) | **3/3 PASS** |
| headless `--nogui` | `ALL PASS (23 checks, 1 group(s) skipped)` — unchanged |
| `DISPLAY` unset | same, unchanged |
| before the change, for comparison | `ALL PASS (40 checks)` × 5, 0.50 s |

Cost: 0.50 s → 1.50 s, all of it the three sabotage spins (300 + 200 + 120 +
300 ms). Unlike P3 this suite does not get faster: its two original drivers were
already winning their bet on a quiet display.

## ⚠ Adding rows moved this suite's banner, and three citing files are untouchable

The banner went `:294` → **`:540`**. It is cited by **`tests/banner_rule.tcl:50`**,
**`tests/headless/test_audit_classifier.tcl:280`** and
**`tests/headless/full_audit.sh:211`** — all three on item E3's do-not-touch
list, all three **comments** (nothing reddens). `doc/claude/issues/0805`'s copy
was updated; `test_rdw_keys_1245.tcl`'s two `:263-280` citations were updated to
`:387-407` and that suite re-run green (`ALL PASS (92 checks)`).
**Cite the emitter, not the line.**
