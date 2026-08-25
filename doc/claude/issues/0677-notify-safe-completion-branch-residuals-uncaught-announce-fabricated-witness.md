# 0677 — `notify_safe`'s completion branch: an uncaught announce, a fabricated witness, no reentrancy guard

Status: **OPEN** (measured, NOT fixed — residuals of the 0664/0665/0666 fix)
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
