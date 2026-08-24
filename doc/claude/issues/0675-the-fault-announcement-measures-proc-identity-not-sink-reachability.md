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
