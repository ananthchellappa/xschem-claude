# 0832 — the `xschem library_manager` action-log line is unguarded, so a crafted lcv poisons the replayable log

Status: **measured LIVE on the 0831 tree (i.e. AFTER 0831's nine sites were
converted), NOT FIXED.** Found by 0831's scout, re-driven end to end by 0831's
Implement agent.
Severity: **medium-high** — not a load-time RCE, but the action log is a
*replayable Tcl script by design*, so the payload fires on replay, in whatever
session replays it.
Family: 0812 / 0816 / 0817 / 0821+0822 / 0825 / 0827 / 0829 / 0831.

## 1. The site

`src/scheduler.c:8107`, in the `xschem library_manager` branch:

```c
        if(argc > 2) {
          log_action("xschem library_manager {%s}", argv[2]);
          tcl_call("libmgr::open", argv[2], NULL, NULL);      /* fixed by 0831 */
        }
```

0831 converted the **execution** half of this branch (`libmgr::open`). The
`log_action()` half above it still splices `argv[2]` into a `{%s}` brace group
with no guard.

## 2. Its four siblings ARE guarded — this one alone is not

```
src/scheduler.c:7712   if(!force && has_x && tcl_braceable(f)) log_action("xschem load {%s}", f);
src/scheduler.c:7853   if(tcl_braceable(f))                    log_action("xschem load_new_window {%s}", f);
src/actions.c:834      if(!filename && tcl_braceable(f))        log_action("xschem load {%s}", f);
src/actions.c:846      if(!filename && tcl_braceable(f))        log_action("xschem load_new_window {%s}", f);
src/actions.c:771      if(!f && tcl_braceable(res))             log_action("xschem saveas {%s} %s", ...);
```

`tcl_braceable()` (`src/callback.c:3503-3507`) returns 0 for a string containing
`{`, `}` or `\`. The `library_manager` line has no such test.

## 3. Measured — 0831's Implement agent, 2026-08-26, on the FIXED 0831 binary

Driver, `:99`, action logging on:

```tcl
set q "x\} ; exec touch <D>/REPLAYHOST ; list \{y"
catch {xschem library_manager $q} b
```

`Xschem.log` line 4:

```
xschem library_manager {x} ; exec touch <D>/REPLAYHOST ; list {y}
```

Replaying that one line in a later `--nogui` session:

```
REPLAYING: xschem library_manager {x} ; exec touch <D>/REPLAYHOST ; list {y}
after-replay host=1 r=|y|
```

`REPLAYHOST` created, and the replay's own result is the payload's `list {y}`
tail. **VERDICT=PWNED on replay.**

## 4. Reach

`argv[2]` is an lcv list. The realistic feeder is
`xschem library_manager [xschem get_inst_lcv]` (the documented gesture, named in
the branch's own comment) — which after 0831 returns lib/cell/view **as data**,
so a `}`-bearing library or cell directory name on disk, or a scripted call, is
the route. Lower reach than 0831's file-derived doors; the payoff is deferred to
replay rather than immediate.

## 5. The fix, when someone takes it

Guard it exactly like its four siblings:

```c
        if(argc > 2) {
          if(tcl_braceable(argv[2])) log_action("xschem library_manager {%s}", argv[2]);
          else log_action("xschem library_manager");
          tcl_call("libmgr::open", argv[2], NULL, NULL);
        }
```

The `else` arm matters: dropping the line entirely would silently lose the
action from the log, which is its own defect. Same question applies to
`log_action("xschem create_instance")` — check whether the argument-bearing form
is ever logged there before assuming it is clean.

**And add a row.** `tests/headless/test_action_log_libmgr.tcl` already asserts
the replayable AL10/AL11 lines; the natural home for a "a brace-bearing lcv is
NOT logged verbatim" row is right beside them.

## 6. Why 0831 did not fix it

Ladder **L2** plus the brief's stop rule: 0831 was scoped to nine `tclvareval`
brace-concat sinks, was rebuilt and fully measured against them, and widening
past the rebuild-and-measure boundary would have invalidated every tier number
in its receipt. Filed with a driven repro instead, per 0831 §7's own reasoning.

## 7. Claims discipline (0823)

A `.sch` is executable **by design**. This issue must not be written up as part
of "the injection family is closed". What it names is narrower: one action-log
line that composes a *replayable script* out of unfiltered data while its four
siblings filter theirs.
