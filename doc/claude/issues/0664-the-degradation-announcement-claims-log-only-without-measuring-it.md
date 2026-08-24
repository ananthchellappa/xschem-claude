# 0664 — the degradation announcement claims LOG-ONLY without measuring it

Status: OPEN (measured twice, NOT fixed — introduced by issue 0658's fix)
Filed by: the 0658 crew, 2026-08-24. Found by the adversary leg, independently
reproduced by the write-up pass.

## Measured

`xschem::notify_degraded_once` (`src/xschem.tcl`) hard-codes its consequence
clause, and the `ciw.tcl` source-catch (`src/xschem.tcl:14854`) fires it whenever
the source fails at **any** point — including *after* the whole notify family and
`ciw_create` have already been defined.

Share farm whose `ciw.tcl` is the real file plus a trailing
`error {WU-C deliberate failure at the END of ciw.tcl}`, child launched
`--nogui --pipe -q --logdir`:

```
child status              : 0
CHILD notify-is-bootstrap : 0        <- the FULL four-sink channel is live
CHILD ciw_echo present    : 1
CHILD unknown opt raises  : 1        <- ciw.tcl:257's strict switch is live
CHILD sinks reached       : ciw log  <- the notice reached the pane AND the file
LOG| #! NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here on (no CIW pane,
     no status field, no popup, no remedy). Cause: src/ciw.tcl failed to source:
     WU-C deliberate failure at the END of ciw.tcl
LOG| #! WU-C a notice in a session whose channel is FULLY ALIVE
```

The adversary measured the same thing on `:99` with a real `.ciw` present.

## Why it matters

The claim is false and it is **permanent**: it is written into `Xschem.log`, the
one artifact issue 0658 exists to protect, and stderr. `notify_degraded_once`
asserts a consequence it never measures. That is precisely 0652's class — a
report that lies — and 0657 is the same defect one layer down (`sinks` claimed
`log` with no log open).

A second-order effect: `::xschem::notify_degraded` **latches** on this false
positive, so a genuinely degraded state later in the same session announces
**nothing**. Issue 0658's acceptance row R4 ("the announcement fires ONCE, not
per notice") passes either way — it cannot distinguish a true announcement from
a spurious one.

## Probable fix

Measure before claiming. The discriminator is already used by 0658's own tests:

```tcl
if {[string match {*notify_bootstrap*} [info body ::xschem::notify]]} { ... }
```

If the live `::xschem::notify` is still the bootstrap wrapper, the LOG-ONLY
sentence is true; otherwise announce the **source failure alone** ("a startup
step failed; the notice channel itself is live") and do **not** burn the
one-shot latch. Keep the literal marker `NOTICE CHANNEL DEGRADED` for the truly
degraded case — `test_ase_core` NTD4/NTD6 and `test_ase_log_seam_0207` PS23/PS27
grep for it.

## Still open

All of it.

---

# ⚠ PARTIALLY FIXED 2026-08-24 — the 0664+0665+0666 crew

Status: **PARTIALLY FIXED, and this issue STAYS OPEN.** The false *DEGRADED*
claim and the latch inversion are gone and proved gone. The replacement sentence
was then **refuted by our own adversary leg and corrected during the write-up**,
and what remains — the discriminator measures the wrong fact — is filed as
**issue 0675** and is the reason this is not closed.

## What was wrong, restated by measurement

Two halves, and the second is worse than the original report said.

1. `notify_degraded_once` hard-coded "notices are LOG-ONLY from here on" and
   **nothing measured it**. It fired while `notify_is_bootstrap=0` and
   `ciw_echo_present=1` — the full four-sink channel demonstrably alive.
2. That false positive **latched**. `notify_degraded` is one-shot (0497 rule 1),
   so the *genuine* degradation that followed announced **nothing**:

```
0664 later GENUINE degradation announced = 0  (expected 1, latch burnt)
```

The announcement fired for the healthy case and stayed silent for the sick one.
That inversion is the sharpest thing in this issue and no committed row caught
it — `NTD4`/`PS23` count "exactly 1" and passed either way.

## What was fixed

* **The claim became a measurement.** `xschem::notify_channel_degraded` decides
  which sentence is true before either is said: the command is gone → degraded;
  `info body` raises → degraded; the body names `notify_bootstrap` → degraded;
  else live. That is the same discriminator `NT16`/`PS20` already use, so the
  product and the tests now measure the identical fact.
* **A live channel that raises is a FAULT, not a degradation**, on its **own**
  one-shot latch (`variable notify_fault`). The genuine `notify_degraded` latch
  can no longer be burnt by a false positive. The FAULT string deliberately does
  **not** contain the golden substring `NOTICE CHANNEL DEGRADED`.
* **The DEGRADED sentence stopped lying under `--nolog`.** With no action log
  open at all, "notices are LOG-ONLY" was false in exactly the way 0657's
  `sinks = log` with no log open was false. It now says
  `no durable log is open (--nolog, or --nogui with no --logdir), so notices
  reach STDERR ONLY from here on`. Both wordings measured.

AFTER, same probe as the BEFORE block above:

```
0664 NOTICE CHANNEL DEGRADED    = 0  (channel was LIVE; HEAD said 1)
0664 NOTICE CHANNEL FAULT       = 1
0664 GENUINE degradation announced = 1  (HEAD: 0, latch burnt)
```

## ⚠ THE REFUTATION — WE SHIPPED 0664's OWN DEFECT IN A NEW VOICE, AND CAUGHT IT

The adversary leg refuted the central claim, and the **write-up agent
reproduced the refutation independently before acting on it.** The FAULT
sentence as first implemented ended:

> …so this is a fault in one notice and not a degradation of the channel — **the
> next notice still reaches every sink.**

Nothing measures that. It is a *prediction*, and the brief's binding acceptance
for this issue is "a test must prove it TRUE **at the moment it is said**". It is
false, measured two ways:

**(a) a PERSISTENT post-sink-2 raiser** — `:99`, `notify_style popup`,
`xschem::notify_short` renamed away (it is called immediately after sink 2):

```
N1 rc-ret=2  record={ciw log}
N2 rc-ret=2  record={ciw log}   <- the "next notice", missing the popup sink
N2 popup toplevel .xschem_notify exists = 0
N3 CONTROL (notify_short restored) record={ciw log popup}  popup exists=1
```

The popup sink is provably live (the control reaches it and creates the
toplevel) and the next notice never got there. The persistent raiser is *the
shape of the driver's own repro*, not an exotic one.

**(b) a `ciw.tcl` that fails BETWEEN `notify` (:256) and `ciw_echo` (:464)** —
about 14% of the file. The pane is dead for the whole session:

```
== NEW  status=0   ciw_echo=0  nextsinks={log statusbar}
   LOG: #! NOTICE CHANNEL FAULT: src/ciw.tcl failed to source: …
== HEAD status=0   ciw_echo=0
   LOG: #! NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here on (no CIW pane, no status field, no popup, no remedy). …
```

### Correction to the adversary's own finding

The adversary called (b) "a strict regression, not a wash". **On `:99` it is a
wash**, and the write-up agent measured that: HEAD's sentence claims *"no status
field"* while the next notice measurably reaches `{log statusbar}` — so HEAD
lies there too, in the opposite direction. HEAD's sentence is true on that path
only under `--nogui`, where `log` is the only sink that exists and the claim is
true trivially. Recorded because it changes the severity and what 0675 must fix.

### What the write-up agent did about it, and why not a revert

The clause was **deleted**. The sentence now reads:

> NOTICE CHANNEL FAULT: `<cause>`. Measured: the live xschem::notify is the full
> channel, not the log-only fallback. NOT measured, and therefore NOT claimed:
> which sinks any later notice reaches — if this cause persists, later notices
> can keep missing a sink with no further word.

Deleting an unmeasured assertion cannot make anything less true, needs no new
mechanism, and is verifiable by inspection. Re-measured after the edit:
`test_ase_core` 172, `test_ase_log_seam_0207` 48, `test_startup_guard_0663` 22,
`test_ase_final` 67, `test_op_annot` 330 — all unchanged, and no committed row
greps the deleted clause (they count the marker only).

A full revert was rejected: it is **worse for the user**. It would restore a tree
where 0665 doubles the durable line, 0666 raises into 61+ ASE call sites, and the
genuine degradation is never announced at all — to remove a sentence that, in the
one case where HEAD's differs, is no more truthful than HEAD's.

## Decisions

| # | rung | taken | rejected, and why |
|---|---|---|---|
| D5 | L1 (I1, applied to honesty — 0652's class) | ONE measurement proc gates both sentences | comparing `actionlog_filename` size before/after (0665's option 2) — wrong under `--nolog`, where there is no file; keeping the unconditional claim — the defect |
| D6 | **L3, user-visible, UNRATIFIED** | a live channel that raises announces `NOTICE CHANNEL FAULT` on its own latch | saying nothing when the channel is live (0423's standing objection: a silent continue hides the problem); re-using the golden `NOTICE CHANNEL DEGRADED` marker for both — breaks four committed rows and re-tells this issue's lie in a new voice |
| D7 | L2 | the DEGRADED consequence clause is a claim about the user's NEXT notice, proved by `PS33` emitting one immediately after | enumerating live widgets — under `--nogui` there are none to enumerate and the sentence would differ per environment |
| D8 | **L3, user-visible, UNRATIFIED** | with no log open, say STDERR-ONLY instead of LOG-ONLY | one fixed sentence — false under `--nolog` in exactly 0657's way |
| D11 | L2 (write-up) | **delete** the forward-looking clause; file the real fix as 0675 | revert the whole change (worse for the user, above); gate on measured sink reachability now (a new mechanism, self-verified, with no adversary left — rounding a partial result up) |

## Sabotage matrix (the 0664 half)

| variant | predicted | observed |
|---|---|---|
| SAB-B1 discriminator → `return 1` (claim unconditional again) | 7 | 9 red, all 7 hit |
| SAB-B2 discriminator → `return 0` (inverted) | 9 | **9 red, exact match** |

## Still open — why this issue is NOT closed

* **The discriminator measures PROC IDENTITY, never SINK REACHABILITY** — issue
  **0675**. Which sentence is emitted is decided by *which line of `ciw.tcl`
  failed*: 1–360 → DEGRADED (correct), 361–463 → FAULT while the pane is dead
  for the session, 464+ → FAULT (fair). Nothing measures that.
* **The FAULT latch is one-shot**, so a *persistent* fault is announced once and
  then silently costs the user a sink for the rest of the session.
* No committed row catches either of the two refutation shapes. `NTD11`/`NTD12`
  deliberately truncate `ciw.tcl` at the one point where every proc including
  `ciw_echo` is defined; `PS30` asserts only the `Measured:` clause.
