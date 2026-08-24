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
