# 0800 — the popup sink's mark claims an iconified popup nobody can see

Status: **OPEN** (measured, NOT fixed)
Filed by: the 0674+0675+0677 crew (the notify-channel cluster), 2026-08-25,
from its own write-up leg, reproduced against **pristine HEAD** before filing.
Class: **0662's, exactly** — a witness that names a sink no human can see.
0662 was closed for the CIW arm by an attempt that was then reverted; the popup
arm was never in its scope and is still open at HEAD.

## ⚠ NUMBERING

This is the **first issue in the 08xx block**. `0700-0799` is reserved by the
user, so the number after `0699` is `0800`. See `doc/claude/issues/NUMBERING.md`.

## The measurement, at pristine HEAD (`e9232ec3`)

Driver: `doc/claude/evidence/0674_0675_0677_attempt/head_popup_mark.tcl`,
run on `:99` with openbox 3.6.1 live, against a `XSCHEM_SHAREDIR` snapshot whose
four `.tcl` files are `git show HEAD:` content (`notify_reach` absent — verified
`grep -c 'proc xschem::notify_reach'` = **0**, i.e. genuine HEAD).

State: `::notify_style popup` (the shipped opt-in mode), `.ciw.l` and
`[top_path].statusbar.12` destroyed, one notice emitted so the popup exists and
is mapped, then **one ordinary click**: `wm iconify .xschem_notify`.

```
HEAD: popup exists=1 mapped=0 state=iconic
HEAD: notify_popup_returns=1  (1 = the writer claims success)
HEAD: notify_returned=1 witness_sinks={ciw log popup}
HEAD: degraded=0
```

| what was asked | what was answered | what is true |
|---|---|---|
| `winfo ismapped .xschem_notify` | `0` | the popup is iconic |
| `xschem::notify_popup` returned | `1` | the text was inserted into a window nobody can see |
| `notify_last` `sinks` | `{ciw log popup}` | **zero** human sinks were reached |
| `notify_channel_degraded` | `0` | the channel passes its own liveness test |

## The mechanism

`xschem::notify_popup` (`src/ciw.tcl:162`) returns 1 whenever the `insert` into
`.xschem_notify.t` did not raise. It never asks whether the toplevel is mapped.
Sink 4's mark (`src/ciw.tcl:365`) is correspondingly ungated:

```tcl
if {[xschem::notify_popup $line $tag]} { set sinks [xschem::notify_mark popup] }
```

A successful write into an **iconified** toplevel is indistinguishable, to the
witness, from one a human is looking at. This is the same shape as 0662 (sink 1
marking `ciw` whenever `ciw_echo` merely failed to raise), one sink over.

## Why this is not merely cosmetic

`::notify_style` is `{ciw|popup}` and **rule debt [0650](b) — being ratified by
the user — asks whether it should ship `popup` as the default.** If it does,
this defect moves from an opt-in mode into the default configuration, and it
takes the whole notice channel's honesty with it: in `popup` style the popup is
the only on-screen sink, so a witness that cannot tell iconic from visible is
the only account anyone gets.

## Recommended fix

Symmetric with the ciw and statusbar arms of any reachability predicate — probe
the widget that is **actually written**, not merely Tk's presence:

* `winfo exists .xschem_notify.t` false → the sink is **dead**;
* `winfo ismapped .xschem_notify` false → **blind** (iconic / withdrawn);
* otherwise reachable.

and gate sink 4's `notify_mark popup` on that answer, the way 0662 recommended
for sink 1. Note `winfo ismapped` cannot see **occlusion** (issue 0659), so the
honest vocabulary stays REACHABLE, never SEEN.

## Landmine for whoever takes it

The reverted 0674+0675+0677 attempt built a four-arm `notify_reach` and wrote
this arm as `!$tk -> dead(no-Tk)` / `else -> visible {}` — an **assertion**,
while its ciw and statusbar arms were genuine probes. That asymmetry is what
refuted the whole attempt (a state where the channel passes its own new test and
reaches nobody, in silence). **Do not rebuild the predicate with an asserted
fourth arm.** The patch is preserved at
`doc/claude/evidence/0674_0675_0677_attempt/rejected_attempt.patch`.

## Acceptance

1. A row that iconifies `.xschem_notify` in `popup` style and asserts the
   witness does **not** name `popup`.
2. A control row: a mapped popup still marks `popup` (no under-claim).
3. A row that destroys `.xschem_notify.t` while the toplevel survives and
   asserts the sink reports dead — today `notify_popup` returns 0 there while
   any predicate arm that only checks Tk still says the sink is fine.
