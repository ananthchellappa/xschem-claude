# 0675 — the FAULT/DEGRADED announcement measures PROC IDENTITY, not SINK REACHABILITY

Status: **OPEN** (measured, NOT fixed — the residual half of issue 0664)
Filed by: the 0664+0665+0666 crew, 2026-08-24, from its own adversary leg,
reproduced independently by the write-up agent before filing.

## The defect

`xschem::notify_channel_degraded` (`src/xschem.tcl`) answers exactly one
question:

```tcl
proc xschem::notify_channel_degraded {} {
  if {[info commands ::xschem::notify] eq {}} { return 1 }
  if {[catch {info body ::xschem::notify} b]}  { return 1 }
  return [expr {[string first notify_bootstrap $b] >= 0 ? 1 : 0}]
}
```

That is **proc identity** — "does the name `::xschem::notify` resolve to the
log-only bootstrap?". The sentences it gates make claims about **sink
availability**. Those are different facts.

`src/ciw.tcl` defines the channel at `:256` and its first sink, `ciw_echo`, at
`:464`. So *which sentence the user is told is decided by which line of
`ciw.tcl` failed*:

| `ciw.tcl` fails at | live state | announced | correct? |
|---|---|---|---|
| lines 1–255 | no channel at all | DEGRADED | ✅ |
| lines 256–360 | channel yes, `ciw_create` no, `ciw_echo` no | **FAULT** | ❌ pane dead for the session, never said |
| lines 361–463 | channel yes, `ciw_echo` no | **FAULT** | ❌ same |
| lines 464–735 | channel + sink 1 both live | FAULT | ✅ fair |

Nothing measures the middle rows. About **14% of `ciw.tcl`** lands there, and
`ciw.tcl` is sourced under a deliberate `catch` (`src/xschem.tcl:14854`, issue
0658), so it is a live runtime state — not a startup abort.

## Measured

Share farm, real `ciw.tcl` truncated after line 360 plus a trailing `error`,
child on `:99`:

```
== NEW  status=0   ciw_echo=0  nextsinks={log statusbar}
   LOG: #! NOTICE CHANNEL FAULT: src/ciw.tcl failed to source: WUP mid-file. …
   DEGRADED count=0  FAULT count=1
== HEAD status=0   ciw_echo=0
   LOG: #! NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here on (no CIW
        pane, no status field, no popup, no remedy). Cause: … WUP mid-file
```

The CIW pane is gone for the whole session and the user is never told.

**⚠ IT IS A WASH, NOT A REGRESSION, AND THE DISTINCTION MATTERS.** The adversary
leg called this "a strict regression, not a wash". The write-up agent measured
`:99` and it is a wash: HEAD's sentence asserts *"no status field"* while the
next notice measurably reaches `{log statusbar}` — HEAD lies too, in the
opposite direction. HEAD's sentence is true on this path only under `--nogui`,
where `log` is the only sink that exists and the claim is true trivially. Both
sentences are wrong on `:99`; neither implementation measures the fact it
asserts.

## The related half: a PERSISTENT fault is announced once and then goes quiet

The FAULT latch is one-shot (0497 rule 1: count per pass, never alert per item).
For a *persistent* cause the user is told once and then silently loses a sink
for the rest of the session. Measured on `:99`, `notify_style popup`, with
`xschem::notify_short` renamed away (it is called immediately after sink 2):

```
N1 rc-ret=2  record={ciw log}
N2 rc-ret=2  record={ciw log}   <- second notice, same session, popup missed
N2 popup toplevel .xschem_notify exists = 0
N3 CONTROL (notify_short restored) record={ciw log popup}  popup exists=1
```

This is the shape of the driver's own repro, so it is not exotic.

## What the 0664+0665+0666 crew did instead, and what it left

The FAULT sentence used to end *"the next notice still reaches every sink"*. That
clause was **deleted** during the write-up (it was refuted by the measurements
above, and the brief's binding acceptance for 0664 is that a test must prove the
line TRUE at the moment it is said). The sentence now claims only what is
measured, and says explicitly that it is not claiming the rest:

> NOTICE CHANNEL FAULT: `<cause>`. Measured: the live xschem::notify is the full
> channel, not the log-only fallback. NOT measured, and therefore NOT claimed:
> which sinks any later notice reaches — if this cause persists, later notices
> can keep missing a sink with no further word.

That removes the lie. It does **not** give the user the fact they need.

## The fix

Gate on **measured sink reachability**, not proc identity — at minimum
`info commands ::ciw_echo`, plus `notify_ciw_visible` / statusbar / popup
probes, i.e. ask the same questions the channel itself asks when it selects
sinks. Then:

* the mid-file rows above announce a degradation of **sink 1** by name;
* the sentence can state which sinks remain, which is the fact that matters;
* a persistent fault can re-announce when the *set of reachable sinks changes*,
  rather than being latched on first sight.

⚠ **The golden marker constraint binds any fix**: `NOTICE CHANNEL DEGRADED` is
grepped literally by `NTD4`, `NTD6`, `PS23`, `PS27`, and its **absence** is
asserted by `NTD1`/`PS20`. A new sentence must not contain that substring unless
it means it.

## Acceptance

* a `ciw.tcl` that fails between `:256` and `:463` produces an announcement that
  **names the dead sink**, and a row proves the named sink is really dead;
* a persistent post-sink-2 fault does not leave the user silently short a sink
  for the session;
* every clause of both sentences is proved TRUE by a row **at the moment it is
  said** — the standard 0664 was held to, applied to its own replacement;
* `NTD11`/`NTD12` gain siblings that truncate `ciw.tcl` at the *other* two
  points (before `ciw_create`, between `ciw_create` and `ciw_echo`) — today both
  use only the one truncation where every proc is defined.

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

### 0675-specific: the answer to "what predicate can honestly answer this" still stands

The batch brief asked for **one** predicate, used everywhere, for "can a notice
reach a human right now". The attempt's answer — one proc, per-sink
`{state reason}`, style read at call time, `human = reach - log` because a
durable log is a record and not an audience, and the vocabulary **REACHABLE,
never SEEN** because occlusion (issue 0659), a zero-height sash and whether
anyone is at the desk are unmeasurable — was not what failed. **Its fourth arm
failed to apply it.** Rebuild the same shape with four probes.
