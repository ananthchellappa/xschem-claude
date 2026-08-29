# 0924 — File > Open Recent empties whenever a stock xschem touches the same conf

**Status:** **FIXED 2026-08-29**, measured both before and after. Reported by the
user: *"Each time you do some work, I find that the File > Open Recent gets
emptied. Can you find out why and fix?"*

**Test:** `tests/headless/test_recent_conf_compat_0924.tcl` — 22 checks, **8 red
on the pre-fix tree**, all green after.
**Related:** [0839](0839-*.md) (the empty-entry poisoning of the same list),
[0119](0119-recent-files-script-leak.md) (the automation gate this does not touch).

---

## 1. What the user sees

`File > Open Recent` is populated. Work happens — a build, a test run, a session
in another checkout. Next time the user looks, the menu is **empty**. No error,
no message, nothing in a log. Reopen-most-recent (`Ctrl+Shift+O`) has nothing to
reopen either, because it walks the same list.

It is not a display problem. The list is gone from **disk**:
`~/.xschem/recent_files` genuinely no longer holds the user's schematics.

## 2. Two halves, and each one feeds the other

The conf file is a Tcl script that gets sourced. There are two spellings of the
variable it sets, and this tree only ever understood one of them.

| | writes | reads |
|---|---|---|
| stock xschem, and this tree before `6be62c26` | `set recentfile {...}` | `recentfile` |
| this tree, since `6be62c26` | `set tctx::recentfile {...}` | `tctx::recentfile` |

**The read half.** `load_recent_file` did `source $USER_CONF_DIR/recent_files`
**inside the proc**. A sourced script runs in its caller's variable frame, so a
legacy `set recentfile {...}` line created a **proc-local** named `recentfile`,
which was discarded the instant the proc returned. `tctx::recentfile` stayed
`{}`. The list was read and thrown away, silently — the worst available outcome,
because a *failure* to read would at least have raised.

**The write half.** `write_recent_file` emitted only the `tctx::` spelling. A
stock xschem sharing the same `~/.xschem` cannot see that line, so it began from
an empty list, appended the one schematic it had just opened, and rewrote the
file — the open is `w`, so the whole file is replaced. **The user's ten entries
were destroyed on disk by a program that never knew they were there.**

Each half alone is survivable. Together they are a ratchet: the old build empties
the file, the new build cannot read what is left, and nothing anywhere reports it.

## 3. Why a stock xschem is running at all

Measured on this machine, 2026-08-29:

```
/usr/local/bin/xschem            3.4.6, Jan 26 2025
/usr/local/share/xschem/xschem.tcl:1166   puts $fd "set recentfile {$recentfile}"
grep -c 'no_recent_files\|update_recent_files' /usr/local/share/xschem/xschem.tcl
0
```

That build predates issue 0119 and therefore has **no automation gate at all** —
`--pipe`, `--nogui` and `--norecent` do not protect the user's list from it,
because it has never heard of them. And it is what a bare `xschem` on `PATH`
resolves to: any harness or session whose tree has no built `src/xschem` falls
through to it.

The conf on disk when the user reported this held exactly one entry —
`/tmp/claude-1000/-home-analog-dev-demo-fluid-drag-xschem-claude/.../scratchpad/syn/out_new/top.sch`
— a scratch file belonging to a **different concurrent session**, written at
07:48 that morning. The shape of the file (a bare `set recentfile` line followed
by `array set ::c_toolbar::c_t_*` lines) matches the 3.4.6 writer byte for byte,
and was reproduced deliberately in an isolated `HOME`.

## 4. The fix

`src/xschem.tcl`, both procs, symmetric:

* **`load_recent_file`** sources the conf with `uplevel #0 [list source ...]`, so
  a legacy `set recentfile` line lands in `::recentfile` rather than a doomed
  local. If `tctx::recentfile` came back empty and `::recentfile` exists, adopt
  it; then `unset -nocomplain ::recentfile` so a stale global cannot be adopted
  by a later, unrelated load. Qualified names (`tctx::*`, `::c_toolbar::c_t_*`)
  are unaffected by the scope change.
* **`write_recent_file`** emits the legacy `set recentfile {...}` line **as well
  as** the `tctx::` one. The old build now reads the real list, appends to it,
  and writes back something this tree can read. The cost is one duplicated line
  in a conf file.

**Ordering is load-bearing, and the legacy line goes FIRST.** The conf is
*executed*, not parsed. A reader whose Tcl has no `tctx` namespace **raises** on
`set tctx::recentfile ...` and abandons the rest of the file — so the line it can
read has to come before the line it cannot. The 3.4.6 build measured here happens
to have the namespace (`grep -c 'namespace eval tctx'` = 1) and reads either
order, which is why the first cut of this fix passed its own tests with the lines
the other way round. Check **C9** now sources the conf into a fresh child interp,
which genuinely has no `tctx`, and reds if the order is reversed.

Three more hardenings from the same review:
* `::recentfile` is cleared **before** the source, so the adoption arm can only
  pick up something *this* conf just set, never a leftover;
* the adoption is guarded by `llength`, because a hand-edited or truncated conf
  can leave an unbalanced brace and the 0839 filter downstream is an unguarded
  `lsearch` that would raise on one;
* the open-failure message read an undefined `$f` and therefore *threw* instead
  of reporting — pre-existing, one line, fixed in passing.

Round trip measured lossless in **both** directions: legacy conf → this build →
3.4.6 opening a schematic → this build, with every entry intact. Before the fix
the same sequence ended at one entry and an empty menu.

## 5. What is NOT fixed, and why

* **`tctx::recentdirs`** (directories visited through the file dialog) has no
  legacy counterpart. A stock xschem rewrites the whole file, so that list is
  still lost on a round trip through it. Nothing can be written that makes a
  2025 build preserve a variable it has never heard of.
* **The entries already destroyed** cannot be recovered. The conf holds one
  surviving entry; it now shows in the menu, and the list rebuilds from there.
* **The stock build itself.** It is not ours to gate. The durable answer is not
  to have a bare `xschem` on `PATH` resolve to a 2025 binary while development
  trees exist — noted in `CLAUDE.md`.
* **Two siblings found by the same review, filed separately.**
  [0925](0925-saved-net-highlight-styles-are-discarded-at-every-startup.md) is
  this bug's read half unfixed in `load_net_hilight_conf` — measured, and with a
  test that is green over the dead path. **0926** is a different shared-`~/.xschem`
  collision: a stock-written `simrc` would strip Spectre from this tree's
  simulator list. Neither is a regression from this fix.

## 6. Acceptance

`tests/headless/test_recent_conf_compat_0924.tcl`, registered in
`tests/run_regression.tcl` and `tests/headless/full_audit.sh`. Twenty-two checks
in nine groups, each with a positive or negative twin: legacy conf reads (C1)
with the current format still reading (C1b) and a conf naming neither yielding
empty (C1c); no leaked global (C2); both names written and agreeing (C3); the
full round trip (C4); 0839's empty-entry filter applied to an adopted legacy
list (C5); the namespaced name winning when both are present (C6); 0119's
automation gate still refusing to write (C7); **reachability** by a reader with
no `tctx` namespace, with a negative twin proving that reader really is strict
(C9); and a missing conf loading cleanly to an empty list (C10).

**C3a proves the legacy line is in the file; C9 proves a foreign reader gets to
it.** Those are different claims, and only the second one is the bug. Measured:
8 red on the pre-fix tree, and exactly 1 red — C9 — on a tree that has the whole
fix but writes the two lines in the wrong order.

The completion banner this runner reads is `OVERALL: ok`
(`tests/banner_rule.tcl`, `banner_complete`). The first cut of this suite ended
on a bare `RESULT: ALL PASS`, copied from `test_reopen_recent.tcl` — which is not
registered and so never needed one — and scored a harness FAIL with all checks
green. Same shape as 0689, from the other side.

**The user's eyes are still owed one thing**: that `File > Open Recent` really
does list schematics again on the real screen. A headless suite cannot see a
menu. Recorded as a `look` debt.
