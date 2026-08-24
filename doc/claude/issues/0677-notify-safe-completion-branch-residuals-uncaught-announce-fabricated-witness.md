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
