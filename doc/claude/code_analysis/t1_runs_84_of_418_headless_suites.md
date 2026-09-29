# T1 runs 84 of the 418 headless suites, and CLAUDE.md's rule reads as if that cannot happen

Measured 2026-09-28 on `fluid-editing` at `809c03d1`, as a side finding of issue **1615**.
Nothing here is a fix; it is a measurement plus one decision, recorded so it is not
re-discovered a third time.

## What was measured

Issue 1615 needed to add a fence to `tests/headless/test_wave_sigbrowser_panes.tcl`, so
the first question was whether T1 runs that suite. It does not — and neither does it run
any of its thirteen siblings:

```
$ /usr/bin/grep -c sigbrowser tests/run_regression.tcl
0
$ /usr/bin/grep -o '"headless/test_wave[^"]*"' tests/run_regression.tcl
(nothing)
```

Widening it, reconciled against the two lists in `run_regression.tcl`:

| | count |
|---|---|
| `tests/headless/test_*.tcl` files present | **418** |
| distinct names in `hcases` ∪ `dcases` | **88** |
| …of those, `tests/headless/test_*.tcl` | **84** |
| …of those, living in `tests/` instead (`buried_hilight`, `hilight_hier_oracle`, `hilight_hier_dump_replay`, `hilight_xwin_sync_headless` — bare names, no `headless/` prefix) | **4** |
| `tests/headless/test_*.tcl` NOT in either list | **334** |

`hcases` holds 85 entries and `dcases` 16, all distinct within their own list, with **13
names in both** (a suite in both lists costs two cases and one headless self-skip, which
is the step CLAUDE.md warns is not a constant).

⚠ **One false alarm, checked and cleared, recorded so nobody repeats it.** A first pass
reported "four names registered with no file" — those are the four bare-name entries
above, resolved relative to `tests/` rather than `tests/headless/`, and all four files
exist. The regex was wrong, not the registration. Any future census of these lists must
allow for the bare-name form.

## The whole `test_wave_*` family is in the 334

All 34 `test_wave_*` suites plus `test_signal_short_nohier_0230` were run on the display
arm for issue 1615: **32 passed, totalling roughly 5,160 checks.** The three non-passes
were each measured identical at HEAD with 1615's change stashed, so all three are
standing and pre-existing:

* `test_wave_sigbrowser_0312` — `BF21a`/`BF24a`, the width assertions (issues **0842**,
  **1399**, which already records "two standing reds on the display arm").
* `test_wave_sigbrowser_keys` — `BK22`/`BK29`/`BK31`, binding-table rows.
* `test_wave_markers` — `TIMEOUT` after 200 s when `run_suites.sh` attaches to the dev
  display (issue **1488**, which CLAUDE.md already names).

So ~5,160 checks' worth of waveform-viewer coverage exists, is almost entirely green, and
**does not gate a commit.** Two of those five standing reds have had issue numbers since
before this measurement and have simply never been in front of a gate.

## Why CLAUDE.md's sentence is misleading, and what is actually true

CLAUDE.md says, in the Harness rules:

> **A suite that is not in `run_regression.tcl` is run by NOTHING, and a fence nothing
> runs rots silently.**

Read literally that is false for 334 files, because **`tests/headless/full_audit.sh`
globs them**: `mapfile -t files < <(ls "$HERE"/test_*.tcl | sort)`. The accurate statement
is narrower and more useful:

> A suite that is not in `run_regression.tcl` **does not gate a commit**. It is reachable
> only through `full_audit.sh`, which nothing in the workflow requires anyone to run.

The distinction matters because the two readings imply different remedies. "Run by
nothing" says *register everything*. "Does not gate" says *decide, per suite, whether its
fence needs to be in front of every commit* — and leaves `full_audit.sh` as the real home
for the long tail.

## ⚠ THE REASON IS MECHANICAL, AND MY FIRST EXPLANATION WAS WRONG

This section originally said the family was unregistered because of runtime cost and
known reds. **That was a guess, and gating the registration refuted it.** The real reason
is that **T1 could not score these suites at all.**

`tests/banner_rule.tcl` — the only Tcl reader of the completion-banner rule, and the one
`run_regression.tcl` sources — is:

```tcl
proc banner_complete {body} {
  return [regexp -line {^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$} $body]
}
```

and its own header states: *"this file implements no `RESULT: ALL PASS` spelling at all"*.
`wvbs_finish` in `tests/headless/wvbs_common.tcl` — the shared epilogue of all fourteen
`test_wave_sigbrowser*` suites — printed **only** `RESULT: ALL PASS ($npass checks)`.

CLAUDE.md's banner rule says a case passes only on **exit 0 AND a whole-line completion
banner AND no column-0 death marker**. So registering one of these suites produced:

```
HARNESS: headless/test_wave_sigbrowser_panes (display arm) did not complete cleanly
         (exit=0, OVERALL_ok=0, died=0) -- crashed, aborted mid-script, or a check
         failed: FAIL
RESULT: ALL PASS (88 checks)
```

— measured at `809c03d1`, `cases=105 blocks=104 counted_failures=1 skips=8`, with the
suite's own verdict line sitting on the very next line of the same verdict file. Every
check passed and T1 scored it a harness failure.

**`run_suites.sh` and `full_audit.sh` each carry their own ERE, and both DO accept
`RESULT: ALL PASS`.** That is why every standalone run and every audit run of these suites
had always looked clean, and why nothing ever pointed at the gap: the two readers that
could see these suites were the two that are not the gate.

Measured: **119 suites in `tests/headless` print `OVERALL: ok`; `wvbs_common.tcl` printed
it zero times.** This family was the outlier. Issue 1615 makes `wvbs_finish` emit the
sentinel **in addition to** its `RESULT:` line — additive, `RESULT:` kept last because
`summarize_all` publishes a case's last `RESULT:` line — rather than teaching
`banner_rule.tcl` a fourth spelling, which would have meant re-spelling all three readers
plus section K of `test_audit_classifier.tcl` and forcing a ruling on the inner-paren
divergence that file documents as deliberate.

**This is the fourth time this defect family has been filed** — issues 0420, 0456, 0492,
0629 and 0689 are all "the completion sentinel rejects a suite that prints a check count",
and `banner_rule.tcl`'s own header records that the standing red *"was filed FOUR times and
waved through as furniture each time"*. This is the same defect wearing a different
spelling: not a counted `OVERALL: ok`, but a suite family that never emitted the sentinel
at all. **The lesson that generalises: a suite's banner is only validated against the
reader that actually reads it, so a suite outside T1 has never had its banner checked by
T1 — and "it passes standalone" is not evidence that it can be registered.**

## The decision on the remaining 333, and it is mine rather than the user's

**They are not being registered.** Reasons, in order of weight:

0. **The banner fix removes the blocker for the thirteen wvbs siblings but not for the
   other 320**, whose epilogues are unmeasured. Each would have to be checked against
   `banner_complete` individually, and "it passes standalone" is not evidence — that is
   the whole finding above.
1. **Cost.** T1 already takes ~600 s at 104 cases. The `test_wave_*` family alone took
   over 20 minutes on the display arm in this measurement, most of it in
   `test_wave_markers`' 200 s timeout. Registering the tail would turn the commit gate
   into an hours-long run, and a gate nobody can afford to run is worse than a short one
   plus a periodic audit.
2. **Five known reds would become the gate's problem** before anyone had decided to fix
   them, which converts "T1's baseline is ZERO counted failures" from a rule into a
   carried count — exactly what CLAUDE.md forbids.
3. **It is not this issue's work.** Smuggling a 14-case registration into a one-integer
   status-line fix would make any resulting red unattributable, which is the same
   reasoning items 12 and 13 of the two-pane batch used about each other.

**What IS adopted, and it is the bounded half:** *a suite you add a fence to, you
register in the same commit.* Issue 1615 registered `test_wave_sigbrowser_panes` in
`dcases` for exactly that reason — `dcases` and not `hcases` because the band carrying
the new rows is display-only. That keeps CLAUDE.md's underlying intent (a new fence must
be run by the thing that gates) without paying for the tail.

**What is left open**, and named so it is a choice rather than an omission: whether the
project wants a *second* scheduled gate — a `full_audit.sh` run that is actually required
at some cadence — so the 334 stop being effectively untested. That is a workflow question
with a real time cost, and it is worth deciding deliberately rather than by accretion.
The five standing reds above are the concrete evidence that today's answer is "nobody
runs it".
