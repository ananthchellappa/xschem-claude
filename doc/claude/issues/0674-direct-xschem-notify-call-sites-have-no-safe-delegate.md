# 0674 — direct `::xschem::notify` call sites have no safe delegate

Status: OPEN (measured, NOT fixed — a declared coverage hole of the 0664/0665/0666 fix)
Filed by: the 0664+0665+0666 crew, 2026-08-24 (Implement agent claimed the
number as a stub before the work; the Write-up agent owns the final text).

## The class

`xschem::notify_safe` is the ONE guarded delegate body, and `ase::echo` /
`wviewer::echo` are its two callers. But a notice that carries a **remedy** —
`-short`, `-menu`, `-command`, the R-0653-d distinct fields — cannot go through
it: `notify_safe`'s signature is `{msg {tag {}}}` and it drops every one of
them. So those sites call `::xschem::notify` **directly**, and nothing guards
them.

Measured on this tree (2026-08-24, HEAD bb0ec866):

```
$ grep -n '::xschem::notify ' src/*.tcl
src/ase.tcl:692    the 0617 gate-off nudge  (-short, -menu, -command)  UNCAUGHT at HEAD
```

`src/ase.tcl:802`'s `catch {ase::op_cards_capture $state $nl}` swallows a raise
from :692 **together with the entire OP-card block** — no message, no log line,
and the user's actually-reported 0617 nudge silently dead.

## Why it is filed now rather than fixed now

The 0664/0665 fix adds a statement (`xschem::notify_mark_reset`) to the
channel's **entry**, i.e. in front of every option-parsing raise that site could
ever hit. That makes the hazard one this change *creates*, so :692 got a `catch`
in this step (decision D10, `src/ase.tcl`).

**DECLARED COVERAGE HOLE, in the 0648 SAB-H style: no committed row falsifies
that catch.** Building the row means driving `op_cards_capture` behind a raising
channel and asserting the nudge still reaches the user — a later step's work,
and larger than the one-line guard it would fence.

## What the class fix looks like

A `notify_safe`-shaped delegate that FORWARDS the remedy fields
(`xschem::notify_safe_args {msg args}`), so a site carrying `-short/-menu/
-command` has something to call, and every direct `::xschem::notify` in the
product moves to it. Then the coverage row is one row, not one per site.

## Acceptance

* every `::xschem::notify` call outside `src/ciw.tcl` and `src/xschem.tcl` goes
  through a guarded delegate that preserves `-short/-menu/-command`;
* a committed row proves the 0617 nudge still reaches the user when the channel
  raises — i.e. `ase.tcl:802`'s catch no longer eats the OP-card block;
* `grep -n '::xschem::notify ' src/*.tcl` outside those two files is empty.

---

## 2026-08-25 — AN ATTEMPT WAS MADE, MEASURED GREEN, AND **REVERTED** (status F)

The 0674+0675+0677 crew batched all three (four crews had filed 24 issues
against this one channel by seeing only their own slice). It built the fix,
every suite went green, and its **adversary leg refuted the central claim**, so
nothing was committed to `src/`. This issue stays **OPEN**.

The full working diff is preserved, tracked, and re-appliable:
`doc/claude/evidence/0674_0675_0677_attempt/rejected_attempt.patch` (1885 lines).
**Read it before rebuilding — most of it is right.**

### What the attempt built

One predicate, `xschem::notify_reach` (in `src/xschem.tcl`, never `ciw.tcl` —
the degraded state it serves is the one where `ciw.tcl` is absent), returning a
per-sink dict of `{state reason}` over `visible | blind | dead | off`, consumed
by sink 1's mark, by `notify_ciw_visible`, and by all three announcements. Plus
a third voice (`NOTICE CHANNEL UNREACHABLE`), `notify_done` as the channel's one
exit, `notify_log_open` / `notify_line` collapsing two existing I1 breaches,
`notify_safe` widened to `{msg args}`, and 0662 closed for the CIW arm.

Suites at the time of the revert (baseline → attempt):
`test_ase_core` 172 → 188, `test_ase_log_seam_0207` 48 → 55,
`test_startup_guard_0663` 22 → 23, `test_ase_final` 78 → 79,
`test_ase_window` 214 → 214, `test_ase_dialogs` 174 → 174.

### Why it was reverted — the refutation, re-measured by the write-up agent

Three of the four arms probed the widget actually written. **The fourth
asserted.** The popup arm was `if degraded → dead; elseif style ne popup → off;
elseif !$tk → dead(no-Tk); else → visible` — it never looked at
`.xschem_notify` at all. So, on `:99` with openbox live, in the shipped opt-in
`popup` style, with `.ciw.l` and `[top_path].statusbar.12` destroyed and **one
ordinary click** (`wm iconify .xschem_notify`):

```
AFTER-ICONIFY: exists=1 mapped=0 state=iconic
degraded=0
reach=sinks now: ciw=dead(no-pane) log=blind(open,UNVERIFIED issue 0699) statusbar=dead(no-widget) popup=visible
notify_returned=1
witness_sinks={log popup}
NOTICE CHANNEL UNREACHABLE = 0   DEGRADED = 0   FAULT = 0
```

The channel passes its **own new test**, reports delivered, names a sink, and
reaches nobody — **in total silence**. That is verbatim the state the batch
brief demanded the red phase construct, and the fix did not survive it.

Sharper still, the arm contradicts the channel's own sink result inside one
call: with `.xschem_notify.t` destroyed and the toplevel alive,
`xschem::notify_popup` returns **0** (the writer failed) while the arm still
says `popup=visible` and the witness reads `sinks {log}` — zero human sinks,
zero announcements.

Driver: `doc/claude/evidence/0674_0675_0677_attempt/refutation_popup_iconified.tcl`.

### What was NOT wrong with it — do not throw this away

For the **shipped default** style (`ciw`) the attempt did exactly what it
claimed. In the user's own reported state (`.ciw` mapped, `.ciw.l` destroyed):
`notify_ciw_visible` went 1 → **0**, the status field moved from its sentinel to
the notice text — the fallback really fired, where at HEAD the notice reached
nobody. Sabotage variant SAB-N11 (revert `notify_ciw_visible` to the `.ciw`
toplevel probe) reddened **exactly one** row and left PS14/PS16/PS17/PS19/
PS24/PS25/PS26/PS34 green, which is direct evidence the `.ciw` → `.ciw.l.t`
move is behaviour-preserving.

### What the next crew must do differently

1. **Write the popup arm as a probe, not an assertion**, symmetric with the
   other three — and gate sink 4's `notify_mark popup` on it, the way the
   attempt gated sink 1. Filed as issue **0800**, which is HEAD-level: the
   ungated popup mark is a defect at HEAD too, measured there.
2. **Fence every arm's `visible` branch with a committed row.** No test ever
   exercised `popup=visible` (`grep -rn 'popup=visible' tests/headless/*.tcl` =
   0 hits) — NT32 ran `--nogui`, PS37 pinned the style to `ciw`. The one arm
   nobody tested is the one that was wrong.
3. Three sabotage rows were **over-predicted** and are genuine coverage holes,
   all still true of the patch: PS39 asserts only against the value
   `notify_reach_line` returned, so muting the third voice cannot redden it;
   PS40 counts all three markers together, so the UNREACHABLE line can vanish
   entirely while it passes; NTD16's tuple is only
   `{child-status rc ret log-count}`, so stripping `{*}$args` leaves it green.
4. `notify_reach`'s header comment claimed "It NEVER raises" — false: rename
   `notify_log_open` away and it raises. Every consumer caught it, so there was
   no product impact, but the comment was wrong.
5. The latch **never re-arms on a return**: unreachable → reachable →
   unreachable announces once, total. `notify_latch_ok` stores `{subject state}`
   forever, and PS38 only tested the forward direction. The source comment
   asserted the opposite of the behaviour.

### 0674-specific residue from the attempt

Widening `notify_safe` to `{msg args}` forwards `{*}$args` into a channel that
**raises on an unknown option**, so any future option typo at any call site
produces a durable `NOTICE CHANNEL FAULT` line and silently downgrades the
notice to the bootstrap, losing `-short`/`-menu`/`-command`. Measured:
`notify_safe {msg} -tag error -shortt {typo}` did exactly that. At HEAD the
state is unreachable because `notify_safe` takes no options. Validate options in
`notify_safe`, or catch only that class, so the FAULT voice keeps meaning what
it says.

Also: moving `ase.tcl:778` to `notify_safe` **deleted its local `catch`** on the
argument that `notify_safe` never raises — but `notify_safe`'s own first
statement (`xschem::notify_mark_reset`) is uncaught, so a missing helper aborts
`ase::op_cards_capture` and the outer catch swallows the entire OP-card block:
the precise 0674 failure, through a different door. Keep the local catch, or
catch that statement inside `notify_safe`.
