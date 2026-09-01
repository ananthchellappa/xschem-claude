# 0665 — one notice, two durable lines when the channel raises after sink 2

Status: OPEN (measured twice, NOT fixed — introduced by issue 0658's fix)
Filed by: the 0658 crew, 2026-08-24. Found by the adversary leg, independently
reproduced by the write-up pass.

## Measured

`xschem::notify_safe` (`src/xschem.tcl`) re-makes the **whole** notice through
`notify_bootstrap` on any raise from `::xschem::notify` — including a raise that
happens **after** sink 2 already wrote the durable line. `src/ciw.tcl`'s sink 2
is followed by `notify_short`, `notify_popup` / `notify_ciw_visible` /
`notify_statusbar` and `notify_record`, every one of which is a live call.

Headless, `--nogui --pipe -q --logdir`, with `::xschem::notify_record` renamed
away so the channel raises at its last statement:

```
full channel live: notify body mentions notify_bootstrap = 0
ase::echo rc=0 res='1'
'#! ' lines carrying WU-B-UNIQUEMARKER : 2   (expected 1)
'NOTICE CHANNEL DEGRADED' lines        : 1
```

One `ase::echo`, **two** identical `#! ` lines in `Xschem.log`, plus a
degradation claim that is false (the channel was fully live — that half is issue
0664). The false degradation then persists for every later notice in the session.

## Why it matters

0658's "also in scope" question was answered with a **true return value** and an
**untrue log**. The durable log is the artifact the whole item exists to protect,
and a duplicated line there breaks the one property `grep Xschem.log` is relied
on for: one notice, one record. It also distorts every count-based assertion
(`test_ase_log_seam_0207` PS19 is the one-echo-per-notice fence for the pane; the
file has no equivalent fence).

## Probable fix

Do not re-make a notice the full channel already delivered. Cheapest honest
options, in blast-radius order:

1. Have `xschem::notify` record progress in a namespace variable
   (`notify_progress` set to `logged` right after sink 2), and have
   `notify_safe` pass `-nolog` — or simply skip `notify_log` — when the fallback
   sees that flag set for the current call.
2. Compare `[xschem get actionlog_filename]`'s size before and after the failed
   attempt; skip the fallback's log write if it grew. Cheap, but wrong under
   `--nolog` where the size is always -1.

Option 1 is preferred: it is exact, and it costs one `set` in the channel.

## Still open

All of it.

---

# ✅ FIXED 2026-08-24 — the 0664+0665+0666 crew

Status: **FIXED**. Shipped with 0664 (partially) and 0666 (fixed) as one
mechanism, because all three were one root cause in one proc.

## BEFORE (Measure agent, verbatim, at `bb0ec866`)

```
notify_is_bootstrap=0
ciw_echo_present=1
0665 DRIVERMARK-B durable lines = 2   (expected 1)
0664 NOTICE CHANNEL DEGRADED    = 1  (channel was LIVE)
G1  DRIVERMARK-A durable lines  = 1   (expected 1)
0664 later GENUINE degradation announced = 0  (expected 1, latch burnt)
0666 ase::echo    rc=1 'invalid command name "::xschem::notify_safe"'
0666 wviewer::echo rc=1 'invalid command name "::xschem::notify_safe"'
--- Xschem.log of that run, lines 4-7, IN ORDER ---
4:#! DRIVERMARK-B
5:#! NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here on (no CIW pane, no status field, no popup, no remedy). Cause: invalid command name "xschem::notify_record"
6:#! DRIVERMARK-B
7:#! DRIVERMARK-A
```

Read in order those four lines are the whole defect: sink 2 wrote the real
line; `notify_safe` then declared the channel dead; the bootstrap re-made the
notice and wrote **the same line a second time**; and the notice issued when the
channel really *was* gone got no announcement at all, because the false positive
had already burnt the latch.

**A SECOND 0665 SHAPE, AT A DIFFERENT EXIT** (measured by the Measure agent, not
in the original report). A whitespace-only message takes `ciw.tcl`'s early exit
at `:322`, which is reached **after** sink 2 has written (`notify_log` trims only
`\n`), so it doubles too:

```
WS durable lines MARK-WS = 2  (1 = ok, 2 = 0665 at the whitespace exit)
```

## AFTER (same probe, this tree)

```
notify_is_bootstrap=0
0665 DRIVERMARK-B durable lines = 1   (driver measured 2 at HEAD, expected 1)
0664 NOTICE CHANNEL DEGRADED    = 0  (channel was LIVE; HEAD said 1)
0664 NOTICE CHANNEL FAULT       = 1
G1   DRIVERMARK-A durable lines = 1   (expected 1)
0664 GENUINE degradation announced = 1  (HEAD: 0, latch burnt)
0666 ase::echo    rc=0 ret='0'
0666 wviewer::echo rc=0 ret='0'
```

## The mechanism

The channel now **records what it actually did**, and `notify_safe` **reads the
record instead of assuming** — the driver's recommended design, taken as
written except for one refuted sentence (see 0664).

* `variable ::xschem::notify_progress` in the `src/xschem.tcl` bootstrap block,
  beside `notify_degraded`. **A namespace variable is the whole trick**: the old
  `sinks` was a *local* and unwound with the very raise the record exists to
  survive.
* `xschem::notify_mark {sink}` / `xschem::notify_mark_reset {}` — the ONE
  appender and the ONE reset (I1). `ciw.tcl`'s local `sinks` is now
  `notify_mark`'s **return value**, so the record and the `notify_last` witness
  cannot drift.
* The reset is the **first statement** of `xschem::notify` (`src/ciw.tcl:257`),
  *before* option parsing and before the `notify_latch_ok` gate — not where
  `set sinks {}` used to sit. A raise in option parsing would otherwise leave
  the *previous* call's record standing and make `notify_safe` skip a durable
  write that never happened: a G1 regression wearing a 0665 fix.
* `notify_safe` **completes, never re-makes**: if `log` is in the record it
  writes only the missing witness (`notify_record`, catch'd) and returns
  `[llength $record]`. Sinks 1/3/4 are never retried — "exactly one `ciw_echo`
  per notify" is a committed fence in three suites, and the sink that just
  raised is the least safe call to repeat.

All three of `ciw.tcl`'s exits are covered (`:289` empty, `:322` whitespace,
`:342` normal).

## Decisions

| # | rung | taken | rejected, and why |
|---|---|---|---|
| D1 | L1 (I1) | ONE record, ONE appender, ONE reset; `sinks` is the appender's return value | mirroring each `lappend` into a second namespace list — two accounts of one fact, drifting silently: the exact I1 breach 0658's D2 had just deleted |
| D2 | L2 | the record is declared in `src/xschem.tcl` | declaring it in `src/ciw.tcl` — the degraded state it serves is precisely the state where `ciw.tcl` is absent, so it would be undefined exactly where it is needed |
| D3 | L2 | reset at the channel's FIRST statement **and** at `notify_safe`'s | reset only at `:281` (a G1 regression, above); reset only in `notify_safe` (a delegate whose `::xschem::notify` is absent would inherit a direct call's leftovers, and `ciw.tcl`'s reset would be unfalsifiable) |
| D4 | L2 | on a raise, COMPLETE (write the missing witness only) | retrying the remaining sinks — can double the pane count against a fence committed in three suites |

## Sabotage matrix

Neutralised by renaming the callee to a live no-op, restored with `cp` + `touch`,
`grep -rn SABOTAGE src/` empty, baseline re-measured green.

| variant | predicted | observed |
|---|---|---|
| SAB-A1 record never resets | 11 | 10 red (+3 unpredicted; missed NT21 NT29 NTD2 NTD3) |
| SAB-A2 `notify_safe` stops resetting | 4 | 7 red, all 4 hit |
| SAB-D record never appended to | 6 | 6 red, missed PS29 |
| SAB-E `notify_safe` ignores the record (**the literal HEAD defect**) | 7 | **3 red** — NTD8, PS28, PS31 |
| SAB-F `notify_log` neutralised (0658 variant E re-run) | 12 | 26 red — up from 0658's 17, so the rewrite gave sink 2 no second builder |

**COVERAGE HOLE, reported the way 0648's SAB-H appendix did.** SAB-E — this
issue's own defect, re-introduced verbatim — reddens **exactly three rows**:
`NTD8` (child, `--logdir`), `PS28` (normal exit) and `PS31` (whitespace exit).
That covers both post-sink-2 exits in two suites and is adequate, but it is the
**whole** of the 0665 net; a later edit weakening any one of the three leaves it
thin. Rows that were predicted to catch it and do not: `NT25`/`NT26`/`PS29`/
`PS32` are 0664 rows and are genuinely orthogonal to the record — with the
record ignored the bootstrap still *measures* the channel live and still says
FAULT, so their assertions stay satisfied.

`NT17`/`NT18`/`NT21`/`NT29` cannot falsify the durable-log writer at all:
`test_ase_core` runs `--nogui --nolog`, where `notify_log` legitimately returns
0, so `log` never enters the record and the completion branch is unreachable in
that suite **by construction**. Only the NTD children and the seam suite can
test it. `NT29` (record == witness) falsifies *drift between two accounts* and
nothing else — a broken reset leaves both sides equally wrong, so they still
agree.
