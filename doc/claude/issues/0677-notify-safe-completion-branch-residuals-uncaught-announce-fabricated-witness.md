# 0677 — `notify_safe`'s completion branch: an uncaught announce, a fabricated witness, no reentrancy guard

Status: **OPEN** — RULING SETTLED 2026-08-29 (see RULING at the foot; ruled as one pair with 0664). Still measured, NOT fixed — residuals of the 0664/0665/0666 fix; the ruling implies a code change that is follow-up work, not yet done.
Filed by: the 0664+0665+0666 crew, 2026-08-24, from its adversary leg.

Three small defects in the **completion branch** that issues 0665/0664 added to
`xschem::notify_safe` (`src/xschem.tcl`). None is reachable from a shipped code
path today; all three are cheap to close and each is 0652's class (*a report
that lies*) inside the fix that was written to end 0652's class.

## (a) an UNCAUGHT announce turns a delivered notice into `return 0`

`xschem::notify_degraded_once` is called **uncaught** in the completion branch,
*after* the durable line has already landed. Measured — with it renamed away and
the CIW withdrawn:

```
ase::echo {A5MARK}  ->  returned 0      ("nothing reached any sink")
A5MARK durable lines on disk = 1        (it DID reach the log)
```

That is exactly the rule issue 0666 set for itself — *"whatever it returns must
be TRUE"* — broken by 0666's own fix. **Cost to close: one `catch`.**

## (b) the completion path FABRICATES the witness

```tcl
catch {xschem::notify_record $tag $msg $msg {} {} {} $done}
```

The `short` field is hard-coded `{}` and `line` is set to `msg`. Measured with a
one-shot raising `notify_record` and the CIW withdrawn (so the statusbar sink is
selected):

```
notify_last.sinks = ciw log statusbar      short = ''
.statusbar.12 actually displayed          'A4MARK a message far long...'
```

So the witness claims a statusbar sink fired with an empty short form. It would
also record `line == msg` if `notify_safe` ever grew `-menu`/`-command`. `NT29`
checks record-vs-witness agreement **only in the healthy case**.

## (c) `notify_progress` has NO reentrancy guard

A notice emitted from **inside a sink** appends to the same global record:

```
::ciw_echo that itself notifies  ->  record = {ciw log ciw log}
ase::echo returned 4 for a notice that reached 2 sinks
notify_last.sinks recorded the doubled list
```

No double durable line, so 0665 itself survives. **Product reachability is nil
today** — no shipped sink emits a notice — but the mechanism's correctness
depends on that staying true, and nothing enforces it.

## (d) two smaller notes, recorded so they are not rediscovered

* `notify_channel_degraded` greps `info body ::xschem::notify` for the **literal
  string `notify_bootstrap`**, and `info body` includes **comments**. A future
  comment inside `ciw.tcl`'s `notify` that merely *mentions* `notify_bootstrap`
  silently flips every announcement back to the false DEGRADED claim. `NT24`
  guards this today; the guard is one comment away from being needed.
* `ase::echo`'s return is now **three-valued** — `1` healthy, `[llength $record]`
  from the completion path, `0` from the guard. No product caller reads it
  (checked across `src/*.tcl`), but "the honest sink count" and "delivered" are
  now different numbers for the same successful notice.

## Acceptance

* `notify_degraded_once` cannot change what `notify_safe` returns;
* the completion path records the **real** `short`/`line`, or records nothing
  rather than something false (I3's precedent: blank beats a plausible wrong
  value);
* a nested notice cannot inflate the record, the witness or the return — or a
  row proves nesting is impossible;
* a row pins the `info body` grep against a comment mentioning `notify_bootstrap`.

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

### 0677-specific: all four sub-defects had working fixes in the patch

(a) one `catch` on the completion branch's announce; (b) the branch recording
the REAL short (via `notify_short`) and REAL line (via `notify_line`) with the
sentinel `UNMEASURED` — never `{}` — when a builder is genuinely absent (I3:
a real empty short form and "I did not look" must stay distinguishable);
(c) closed by a **static row** proving no shipped sink writer can emit a notice,
not by a runtime depth counter (a raise between increment and decrement would
mis-account the channel permanently, inside the one proc whose subject is
surviving raises); (d) a comment strip before the `string first notify_bootstrap`
test. Sabotage confirmed each: SAB-N13 → NT35, SAB-N15 → NT34, both exact.
Lift these four from the patch as-is.

---

# ✅ RULED 2026-08-29 — decided under the user's "decide the 23" instruction

Ruled together with **0664**; the two got one answer. Ruling only — no code was
touched by the ruling run. The wording half of this ruling is written up in
0664; this file carries the part specific to 0677.

## The ruling

1. **No fourth on-screen affordance.** When by definition no on-screen place is
   reachable, nothing can be put on screen. The log file plus the terminal is
   the honest end of the line. This is not a trade-off, it is a tautology, and
   it needed no user.
2. **Same for FAULT.** At every shipped caller of the FAULT branch the command
   window is either not built yet (`src/xschem.tcl:14855`, the `ciw.tcl` source
   catch; `:16920`, the `ciw_create` guard) or is the very thing that just
   raised (the `notify_safe` completion branch). Re-entering it to announce is
   out — it is the least safe call in the program to repeat. Whether a live
   pane should ever carry the FAULT line stays with **0675/0800**, which is
   where reachability gets measured.
3. **Land the four residuals from the preserved patch.** Each has exactly one
   right answer and none is a user question.

## ⚠ THE LEDGER PITCH SAYS THESE ARE FIXED. THEY ARE NOT — VERIFIED AT HEAD

`owed.sh show` for 0677 says *"the four measurable residuals (uncaught announce,
fabricated witness, reentrancy, comment-sensitive identity test) are FIXED"*.
All four are still live in `src/`; they were reverted with the rest of the
2026-08-25 attempt and the pitch was never corrected:

| sub-defect | still at HEAD |
|---|---|
| (a) uncaught announce | `src/xschem.tcl:15178` calls `notify_degraded_once` uncaught; `src/ase.tcl:181-184` catches and returns **0** for a notice whose durable line already landed |
| (b) fabricated witness | `src/xschem.tcl:15177` — `catch {xschem::notify_record $tag $msg $msg {} {} {} $done}`, `short` hard-coded `{}`, `line` set to `msg` |
| (c) no reentrancy guard | `notify_mark` (`:14946`) still a bare `lappend`, nothing enforces that no sink emits a notice |
| (d) comment-sensitive test | `src/xschem.tcl:14973` — `string first notify_bootstrap $b` still runs on the un-stripped `info body` |

## What must change in code

Lift exactly these four from
`doc/claude/evidence/0674_0675_0677_attempt/rejected_attempt.patch`:
a `catch` on the completion branch's announce; the branch recording the **real**
short and line with the sentinel `UNMEASURED` — never `{}` — when a builder is
genuinely absent (I3: a real empty short form and "I did not look" must stay
distinguishable); a **static** row proving no shipped sink writer can emit a
notice (not a runtime depth counter); and a comment strip before the identity
test. Take **nothing else** from that patch — its `notify_reach` /
`NOTICE CHANNEL UNREACHABLE` half was refuted on 2026-08-25 and stays reverted
until 0675/0800.

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29:

> **"decide the 23, leave 0861 and 0299 for me"**

A read-only audit of the 57-entry ruling queue classified 25 of them as
questions whose answer is cheap and obvious — things that should be **decided**
rather than handed to the user to read. This debt was one of the 23 the user
told us to decide. (0861 and 0299 the user kept; they are untouched.)

Ruled as one pair with **0664** — one answer covers both files, and both
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
