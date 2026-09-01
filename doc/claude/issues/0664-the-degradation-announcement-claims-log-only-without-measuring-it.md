# 0664 — the degradation announcement claims LOG-ONLY without measuring it

Status: OPEN — RULING SETTLED 2026-08-29 (see RULING at the foot; ruled as one pair with 0677). Still measured, NOT fixed — introduced by issue 0658's fix; the ruling implies a code change that is follow-up work, not yet done.
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

---

# ✅ RULED 2026-08-29 — decided under the user's "decide the 23" instruction

Ruled together with **0677**; the two got one answer. This is a ruling only —
no code was touched by the ruling run.

## The ruling

1. **Keep the rule that picks the sentence.** Say `NOTICE CHANNEL DEGRADED`
   only when the live message channel really is the log-only fallback; say
   `NOTICE CHANNEL FAULT`, on its **own** one-shot latch, when the channel is
   intact but something in it raised; and inside DEGRADED say **STDERR-ONLY**
   instead of LOG-ONLY when no log file is open. Keep claiming **nothing**
   about which places a later message reaches. That is D5-1 applied to prose
   and it is what ships.
2. **No third voice yet.** `NOTICE CHANNEL UNREACHABLE` and the `sinks now:`
   inventory wait on 0675/0800 actually measuring reachability.
3. **Rewrite the prose in plain English** (standing PLAIN ENGLISH ruling —
   the sentences are not exempt because they are diagnostics). Keep the two
   markers byte-identical (four committed rows grep them; they are the log
   search key) and change only the words after them.

## ⚠ TWO THINGS THE LEDGER PITCH GOT WRONG — VERIFIED IN THE TREE

The `owed.sh show` pitch for 0664 says *"This crew shipped a THIRD marker,
NOTICE CHANNEL UNREACHABLE, and appended a measured 'sinks now: ...' inventory
to all three. The MARKER and the inventory are fenced by tests."* **They are
not in the tree.** `grep -rn 'UNREACHABLE\|notify_reach\|sinks now' src/*.tcl`
= 0 hits. The 2026-08-25 attempt that built them was reverted whole; only
`doc/claude/evidence/0674_0675_0677_attempt/rejected_attempt.patch` holds them.
The pitch describes the reverted attempt as shipped, so the user was being
asked to rule on prose that is not in the product.

What actually ships, confirmed: `xschem::notify_channel_degraded`
(`src/xschem.tcl:14971`) and the three sentences in `notify_degraded_once`
(`src/xschem.tcl:15050`, `:15070`, `:15073`), with the refuted forward-looking
clause already deleted.

## Wording to land (plain English, 9th grade), markers unchanged

* FAULT — after the marker: *"a startup step failed: `<cause>`. The message
  system itself is still working, so most messages will still get through. Some
  may quietly go missing while this lasts. This warning is in the terminal you
  started xschem from and in `<Xschem.log path>`."*
* DEGRADED, log open — *"xschem could not build its command window, so from now
  on messages only go to the log file `<path>` and to the terminal — not to the
  command window, the status line, or a pop-up. Cause: `<cause>`. Restart xschem
  to get the command window back."*
* DEGRADED, no log — same, with *"and no log file is open (`--nolog`, or
  `--nogui` with no `--logdir`), so messages only reach the terminal you started
  xschem from."*

No internal proc names, no "sink", no "fallback", no "bootstrap".

## What must change in code

`src/xschem.tcl` `notify_degraded_once` — the prose after the two markers only.
The true/false rule, the two latches and the marker strings do not move.
`PS30` asserts the premise via `notify_channel_degraded`, not the string, so no
committed row greps the prose being replaced.

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29:

> **"decide the 23, leave 0861 and 0299 for me"**

A read-only audit of the 57-entry ruling queue classified 25 of them as
questions whose answer is cheap and obvious — things that should be **decided**
rather than handed to the user to read. This debt was one of the 23 the user
told us to decide. (0861 and 0299 the user kept; they are untouched.)

Ruled as one pair with **0677** — one answer covers both files, and both
files carry this same text.

### What the user gets, in one line

If xschem can't build its command window at startup, the warning stays where it
already goes — the terminal you started xschem from, and `Xschem.log`, with no
extra pop-up. What changes is the wording: those warnings get rewritten in
plain English, and four cases where they under-report what actually got through
are fixed.

### ⚠ THIS SUPERSEDES THE "Wording to land" BLOCK

The `✅ RULED 2026-08-29` write-up earlier in this pair (its wording half is in
**0664**) was recorded first, and its **"Wording to land" block was overturned
by the adversary leg of the same ruling run.** Do not lift that block. The rule
that picks the sentence, the "no third voice yet" hold and the plain-English
instruction all stand unchanged and are restated below; the wording itself is
replaced here; and the four-residual item is restated here because its sub-item
(b) was not executable as written.

### The ruling, as an instruction to the codebase

**1. Keep the rule that picks which sentence is said.** Say
`NOTICE CHANNEL DEGRADED` only when the live message channel really is the
log-only backup; say `NOTICE CHANNEL FAULT`, on its **own** one-shot latch, when
the channel is intact but something in it raised; and inside DEGRADED say
**STDERR-ONLY** instead of LOG-ONLY when no log file is open. Keep claiming
**nothing** about which places a later message reaches. (Unchanged. D5-1 applied
to prose; this is what ships.)

**2. No third voice yet.** `NOTICE CHANNEL UNREACHABLE` and a `sinks now:`
inventory wait on 0675/0800 actually measuring reachability. (Unchanged.)

**3. Rewrite the prose in plain English.** The two markers stay **byte-identical**
— four committed rows grep them and they are the user's log search key — and
only the words after them change. (Unchanged; the standing PLAIN ENGLISH ruling
applies to diagnostics too.)

**Unchanged from the pair's earlier write-up, and not re-argued here:** there is
**no fourth on-screen affordance** — when by definition no on-screen place is
reachable, nothing can be put on screen, and the log file plus the terminal is
the honest end of the line; and the FAULT branch is **not** re-entered to
announce on screen, because at every shipped caller the command window is either
not built yet or is the very thing that just raised. Whether a live pane should
ever carry the FAULT line stays with **0675/0800**, where reachability gets
measured.

**4. The wording that lands** (replaces the overturned block above).

Binding rule for the rewrite — the sentence may say:

* (i) **what just failed**, quoting the cause verbatim in the same line
  (NTD9/NTD12/NTD11 grep the cause out of it);
* (ii) **whether the live message system is the full one or the stripped-down
  backup** — that is measured, and `PS30` calls it *"the whole of what the FAULT
  sentence asserts"*;
* (iii) **where THIS warning went**, and only behind the same
  `actionlog_filename` gate the DEGRADED arm already uses at
  `src/xschem.tcl:15069`.

It may **NOT** say where later messages will land; may **NOT** name a cause the
proc did not measure; may **NOT** offer a remedy that is not known to work
(`src/ase.tcl:765` — *"a wrong direction printed with authority is worse than
printing none"*).

**FAULT** (channel intact, something in it raised) — after the unchanged marker:

> something went wrong while xschem was showing you a message. The error was:
> `<cause>`. xschem's full message system is still loaded, so this is not the
> stripped-down backup. xschem has not checked where your later messages will
> go, so it is not promising anything about that: if this keeps happening, some
> messages may stop appearing with no further warning.

Add, **only when a log is open**: " This warning is also in the log file
`<path>`." No remedy clause — there is none to give.

**DEGRADED, log open:**

> xschem is now running on its stripped-down backup message system. From here
> on, messages go only to the log file `<path>` and to the terminal you started
> xschem from — not to the command window, not to the status line, not to a
> pop-up, and a message that would normally offer you a fix to click will not
> offer one. What caused this: `<cause>`. This will not repair itself during
> this session; restarting only helps once whatever the cause above names has
> been fixed.

**DEGRADED, no log open:** the same sentence, with the first clause replaced by
*"and no log file is open (you started xschem with `--nolog`, or with `--nogui`
and no `--logdir`), so messages reach only the terminal you started xschem
from."* Read in full, that is:

> xschem is now running on its stripped-down backup message system, and no log
> file is open (you started xschem with `--nolog`, or with `--nogui` and no
> `--logdir`), so messages reach only the terminal you started xschem from —
> not the command window, not the status line, not a pop-up, and a message that
> would normally offer you a fix to click will not offer one. What caused this:
> `<cause>`. This will not repair itself during this session; restarting only
> helps once whatever the cause above names has been fixed.

Note the sentence deliberately says **"backup message system"**, not *"could
not build the command window"*: "backup message system" is true in **every**
shape that reaches the branch, including NTD9/NTD12, where the command window
is alive on screen and someone deleted the routing command.

Three fences on the rewrite:

* the two markers stay byte-identical;
* the **cause text** stays in the DEGRADED line for NTD9/NTD12 and in the FAULT
  line for NTD11. Measured while ruling: those rows grep the **cause itself**
  (`"::xschem::notify"` at `test_ase_core.tcl:2065` and `:2170`; `ciw.tcl` at
  `:2155`), **not** the label `Cause:` — so rendering the label as *"What caused
  this:"* keeps all three green, provided the cause is quoted verbatim in the
  same line;
* two things must land **with** the rewrite or it is unfenced:
  1. **gate the FAULT arm's log-path clause on `actionlog_filename`**, the way
     `src/xschem.tcl:15069` already gates DEGRADED. This is a real improvement
     over HEAD, not just prose: without it the sentence would name a log file
     that does not exist under `--nolog`, which is verbatim 0657's defect
     re-committed inside the sentence written to end that class.
  2. **one committed row per sentence pinning its CLAIM SET** — that no
     forward-looking phrase and no unmeasured cause appears. Today only the
     markers are golden, so the prose can rot silently.

**5. Land the four residuals from the preserved patch**
(`doc/claude/evidence/0674_0675_0677_attempt/rejected_attempt.patch`), and
**nothing else** from it — its `notify_reach` / `NOTICE CHANNEL UNREACHABLE`
half was refuted on 2026-08-25 and stays reverted until 0675/0800:

* **(a)** a `catch` on the completion branch's announce;
* **(b)** *restated so it is executable without the reverted half* — record
  `short` as `xschem::notify_short {} $msg` under a `catch`, falling back to the
  sentinel `UNMEASURED` only when the builder is genuinely absent; record `line`
  as `UNMEASURED`, **never** as `$msg`. At HEAD there is no shared line builder
  and `notify_safe` carries no `-menu`/`-command`, so claiming a rendered line
  is exactly the fabrication 0677(b) is about. **Do NOT widen `notify_safe` and
  do NOT import `notify_line`** — those belong to the half held for 0675/0800;
* **(c)** a **static** row proving no shipped sink writer can emit a notice (not
  a runtime depth counter);
* **(d)** a comment strip before the identity test.

(a), (c) and (d) lift from the patch as-is.

### Why this was decidable without the user

* **PLAIN ENGLISH is already the user's standing ruling** — *"wording too
  cryptic. Give it in plain english with context, 9th grade level."* Applying a
  standing ruling is not a new call. The shipped FAULT sentence says *"the live
  xschem::notify is the full channel, not the log-only fallback"* — an internal
  proc name and three internal nouns in one breath — and the shipped DEGRADED
  sentence says *"no remedy"* without ever saying where the log is or what to do.
* **No Cadence use-mode question and no legacy-XSCHEM option** is in play. These
  two strings appear only on the terminal and in the log after a broken startup.
  CADENCE OR NOTHING does not bite here.
* **The three-way DEGRADED / FAULT / STDERR-ONLY split, and the refusal to
  predict later delivery, are D5-1 applied to prose** — never a claim next to a
  thing it was not measured for — and 0652's *"a report that lies"* class.
* **0677's sub-question is a tautology, not a choice.** Asking whether a fourth
  on-screen affordance is owed when by definition no on-screen place is
  reachable answers itself.

And why the *first* recorded wording was overturned: it invented claims instead
of translating measured ones, which is the very defect this pair is filed about.
Five faults, each verified:

1. it re-shipped the forward-looking clause this issue **deleted** ("most
   messages will still get through") — `src/xschem.tcl:15032-15041` carries a
   caps-locked comment saying reachability *"is the one thing it must not
   assert"*, and `test_ase_log_seam_0207.tcl:855` states the fence in the check
   text. "Most" is also quantitatively false when `ciw.tcl` fails between its
   `notify` and `ciw_echo` definitions: the CIW pane — the window the user
   watches — is dead for the whole session;
2. *"a startup step failed"* is false at half the FAULT call sites:
   `src/xschem.tcl:15178` and `:15104` fire **mid-session**, with startup long
   over;
3. *"This warning is in `<Xschem.log path>`"* had no log-open gate — 0657
   re-committed (fixed above by fence 3.1);
4. *"xschem could not build its command window"* names a cause the proc never
   measures — `notify_channel_degraded` measures **proc identity, never why** —
   and NTD9/NTD12 reach DEGRADED with the command window alive on screen, so the
   sentence would contradict the cause printed beside it, which is 0888's class;
5. *"Restart xschem to get the command window back"* is a guessed remedy: for
   the shipped cause (a broken or absent `src/ciw.tcl` in the install) a restart
   reproduces the failure byte for byte. `src/ase.tcl:765` forbids exactly this.

### What was verified in the tree, so nobody re-derives it

Read-only, at `annotate` HEAD, 2026-08-29:

* `src/xschem.tcl:14971` `xschem::notify_channel_degraded` — decides DEGRADED vs
  FAULT purely by whether the live channel's body names `notify_bootstrap`;
  it ships as this issue describes.
* `src/xschem.tcl:15049` `notify_degraded_once`: FAULT sentence at `:15055` on
  its own `notify_fault` latch, with the refuted forward-looking clause already
  deleted; DEGRADED LOG-ONLY at `:15070`; DEGRADED STDERR-ONLY at `:15073`,
  gated on an empty `actionlog_filename` at `:15069`. **The FAULT arm has no such
  gate** — it calls `notify_log` unconditionally.
* `grep -rn 'NOTICE CHANNEL UNREACHABLE\|notify_reach\|sinks now' src/*.tcl` →
  **0 hits.** The third marker and the sink inventory that the `owed.sh show`
  pitch describes as *shipped and fenced by tests* are **not in the tree**; the
  2026-08-25 attempt was reverted whole. The user was being asked to rule on
  prose that is not in the product.
* All four 0677 residuals are **still live at HEAD**, contradicting the ledger
  pitch's *"the four measurable residuals … are FIXED"*:
  `src/xschem.tcl:15178` announce is **uncaught** while `src/ase.tcl:181-184`
  catches and returns **0**, so a notice whose durable line landed still reports
  "nothing delivered" (a); `src/xschem.tcl:15177`
  `catch {xschem::notify_record $tag $msg $msg {} {} {} $done}` — `short`
  hard-coded `{}`, `line` set to `$msg` (b); `src/xschem.tcl:14946`
  `notify_mark` is a bare `lappend` with no reentrancy guard (c);
  `src/xschem.tcl:14973` `string first notify_bootstrap` still runs on the
  un-stripped `info body` (d).
* `src/ciw.tcl:112` `proc xschem::notify_short {short msg}` exists;
  `xschem::notify_line` and `notify_log_open` do **not** exist at HEAD, and
  `src/xschem.tcl:15168` `proc xschem::notify_safe {msg {tag {}}}` is still the
  narrow signature — which is why residual (b) had to be restated.
* `doc/claude/evidence/0674_0675_0677_attempt/rejected_attempt.patch` is present
  and unapplied; issues **0675** and **0800** are both still OPEN.
* `tests/headless/test_ase_log_seam_0207.tcl:781-799` and `:896` — `PS30`
  asserts the premise via `notify_channel_degraded`, **not** the prose string.
  Only the markers (`NOTICE CHANNEL DEGRADED`, `NOTICE CHANNEL FAULT`, and
  `ase.tcl`'s `notice channel unavailable`) are golden, so the prose can be
  rewritten without reddening a committed row — which is also why it can rot
  without one, hence fence 3.2 above.

### Does anything move?

**This IMPLIES A CODE CHANGE. It is follow-up work and it is NOT done.** The
ruling run touched no source and no test; it only wrote this section and this
file's STATUS line. Owed:

1. `src/xschem.tcl` `notify_degraded_once` (~`:15049-15080`) — replace the prose
   after the two golden markers with the three sentences above. Markers,
   latches and the true/false rule do not move.
2. `src/xschem.tcl` FAULT arm — gate its new log-path clause on
   `actionlog_filename`, mirroring `:15069`.
3. One committed row per sentence pinning its **claim set** (no forward-looking
   phrase, no unmeasured cause).
4. 0677's four residuals lifted from
   `doc/claude/evidence/0674_0675_0677_attempt/rejected_attempt.patch` — (a) the
   `catch`, (b) as restated above, (c) the static row, (d) the comment strip —
   and **nothing else** from that patch.

### The adversary

An adversary leg ran against the first recorded answer and **overturned its
wording** — it agreed the skeleton and that an edit is genuinely owed, then
showed the proposed sentences made four claims the code never measures, three of
them falsified by shapes committed rows already build and print. Its better
answer is the one recorded above; it explicitly did **not** bounce the question
back to the user.

---

**The user may reverse this at any time; it was decided to spare their
attention, not to bind them.**
