# 1651 — two of the three one-shot plot-channel armers are fenced only OUTSIDE the gate

**STAMP:** `v1 claim=open tree=81cd51db stamped=2026-10-04 fix=untried open=3`

Status: **OPEN**, derived 2026-10-04 by the issue-1645/1650 hole-filing crew while testing a
different hypothesis — that the one-shot discipline was fenced by *nothing*. That hypothesis is
**false** and the refutation is the reason this file is narrow.

Area: `wviewer::plot_dbs_arm` / `wviewer::plot_dbs_take` / `wviewer::plot_sweeps_arm` /
`wviewer::plot_sweeps_take` and `wviewer::plot_signals` in `src/wave_viewer.tcl`; the three armers
`wviewer::browser_plot_ids`, `wviewer::browser_sea_plot_idx` (both `src/wave_viewer.tcl`) and
`calc::wave_show` (`src/calculator.tcl`).

## The mechanism

The per-signal **database** list and the per-signal **X column** list reach `plot_signals` out of
band, through a namespace array rather than as a fifth and sixth parameter — because the formal
count is pinned (row `WD4` of `tests/headless/test_calc_wave_dest.tcl`, and `BM05` of
`test_wave_sigbrowser.tcl`, both off `info args` on the live proc). The only thing that keeps a
hidden channel honest is that `plot_dbs_take` **unsets**, and that `plot_signals` takes **first
thing in its body**, before any early return.

That discipline protects the case where `plot_signals` is *entered*. It does **not** cover an arm
whose caller refuses, or raises, before the call — and for that case each armer carries its own
unconditional take after the call. `wviewer::browser_plot_ids`' own comment states the contract: *a
no-op after a real call, a clear after a stub.*

**If an arm survives, the next plot gesture in that window silently resolves its names against the
previous gesture's database.** That is issue 0308's wrong answer one gesture on: `resolve_signal_db`
resolves by name and its documented tie-break is *the current database wins*, so a stale arm does
not error — it draws a namesake from the wrong run. `plot_sweeps` leaks the same way onto the X
axis.

## What is actually fenced, and what is not

Derived, not recalled. The armer population is every command-position caller of `plot_dbs_arm` /
`plot_sweeps_arm` in `src/`:

```sh
/usr/bin/grep -rn 'plot_dbs_arm\|plot_sweeps_arm' src/*.tcl | /usr/bin/grep -vE ':[0-9]+:\s*#'
```

and the suites that assert a take are every test naming either channel, cross-referenced against
the two registration lists extracted from `tests/run_regression.tcl` by terminating on the first
line **without** a trailing backslash (the `^]`-terminating slurp reads the whole file and answers
wildly wrong):

```sh
awk '/set hcases \[list/{f=1} f{print; if ($0 !~ /\\$/) exit}' tests/run_regression.tcl \
  | /usr/bin/grep -o '"[^"]*"' | wc -l      # and the same for dcases
git grep -l 'plot_dbs_\|plot_sweeps_' HEAD -- tests/
```

| armer | the suite that asserts its take | in `hcases`/`dcases`? | reaches a gate? |
|---|---|---|---|
| `calc::wave_show` | `test_calc_wave_dest` row `WD12` | **hcases** | **YES** |
| `wviewer::browser_plot_ids` | `test_wave_crossdb_trace` row `XB10` | neither | no |
| `wviewer::browser_sea_plot_idx` | `test_wave_sigbrowser_digital`, `test_wave_sigbrowser_sea` | neither | no |

⚠ **`WD12` is the counter-example that makes this issue small, and it is worth reading before
anyone "fixes" the other two by copying a weaker row.** It does not merely assert that the channels
are empty after a success. It installs a spy that can be told to **raise** (`WD_SPY_RAISE`), drives
`calc::wave_show` through both a refusal and a forced seam failure, and asserts both channels are
still empty afterwards — and it carries a **non-vacuity** leg proving an untaken arm really does
persist for that token, read without consuming it, so the empty answer is a measurement and not a
proc that always answers empty. That is the shape the other two armers need.

## What a maintainer loses

An edit to either browser plot route that drops or moves its unconditional take passes the gate.
The next gesture then plots the wrong run's namesake, silently and with no error — the failure mode
`XB10`'s own comment describes and the one `plot_dbs_take`'s header was written to prevent. Both
routes are shipped user gestures: the signal browser's tree plot and the lower pane's plot.

## Why the two halves need different remedies

* `test_wave_sigbrowser_digital` and `test_wave_sigbrowser_sea` **can be registered today.**
  Measured by sourcing `tests/banner_rule.tcl` itself and evaluating `banner_complete` over each
  suite's real captured output on both arms — not by reading the regexp and reasoning about it:
  both answer **1** on both arms.
* `test_wave_crossdb_trace` **cannot.** It answers `banner_complete` **0** and
  `regression_case_failed` **1** on both arms, so registering it as it stands costs a counted
  failure at `ALL PASS`. That is issue **1615**'s incident and it is filed separately as issue
  **1652**, which is a precondition for this half.

Reproduce the verdicts with (`<arm>` = the capture from `--nogui` and from the display arm; never
inherit `$DISPLAY`):

```sh
tclsh -c 'source tests/banner_rule.tcl; set f [open <capture>]; set b [read $f]
          puts "banner=[banner_complete $b] died=[banner_died $b] casefail=[regression_case_failed 0 $b]"'
```

⚠ **Registration shape must be chosen by measuring each arm's check count, not by preference.**
`test_wave_sigbrowser_sea`'s counted arm self-skips to a handful of checks and announces it in
**uppercase**, which `summarize_all` does not count; its display arm carries the behavioural band
over `wviewer::browser_sea_plot_idx` that issue **1645**'s Outstanding item 1 names. Derive the
trailer delta by lifting `summarize_all` out of `run_regression.tcl`'s own text and running its
regexp arms over the real captured output, per CLAUDE.md — two parties reasoning carefully about
registration shape have both been wrong about `skips=`.

## One stale sentence found in passing

`wviewer::plot_sweeps_arm`'s header says the channel has no armer yet and that the Calculator's
click wiring will be the first. `calc::wave_show` arms it at HEAD:

```sh
git grep -n 'plot_sweeps_arm' HEAD -- src/ | /usr/bin/grep -v '#'
```

Three test suites quote that sentence inside check **names** as a claim about the tree, so the
sentence is load-bearing prose that nothing re-checks — CLAUDE.md's rule exactly: name the
instrument that re-checks a sentence every run, or delete the sentence.

## Outstanding

1. `wviewer::browser_plot_ids`' take is asserted only by `test_wave_crossdb_trace`, which cannot be
   registered until it emits the completion sentinel (issue **1652**).
2. `test_wave_sigbrowser_digital` and `test_wave_sigbrowser_sea` are registerable today and are
   registered in neither list; the shape (`hcases`, `dcases` or both) and the trailer delta are
   underived. `test_wave_sigbrowser_sea` is also issue **1645**'s Outstanding item 1 — one
   registration discharges both, and this file is not a second claim on it.
3. The stale sentence in `wviewer::plot_sweeps_arm`'s header, and the three check names that quote
   it, are unrepaired.
