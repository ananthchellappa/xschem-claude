# 0314 — Ctrl-Alt-V reports a loaded VCD as "not among the loaded results databases"

**Status:** FIXED 2026-08-11. The open question below is ANSWERED — **refusal C,
`switch_ctx`** — and the cause is the gesture's own callback frame: `callback()`
raises `xctx->semaphore` for the whole of any key/button event and
`switch_window`/`switch_tab` refuse a context switch while it is raised, so the
loan was refused on every gesture and granted on every CIW call. Measured, fixed
and sabotage-verified in
`doc/claude/batch_F/receipts/14-0314-0313-gesture-context-loan.md`; the fix is
the semaphore-aware retry in `wviewer::enter_ctx`/`leave_ctx` plus a `refused`
status that stops `cosim_db_inventory` falling back to a registry that
structurally cannot answer (new cause `notread`). Issue 0313 was the same
refusal one caller over. Checks: `FD70`-`FD74`, `FS51`/`FS51b`-`FS51f`.
**Filed:** 2026-08-11, from the Batch F eyeball queue (session 4, item 5 step 6).
**Found by:** hand, then narrowed with live instrumentation in the running
session. Reproducible.
**Related:** Batch F item 5 (`fda9d5a8` + `7ff1be9d`), `ase.tcl:1763` (the comment
that names this exact failure mode), issue 0313 (same gesture, different
collateral).

## What happens

A code-block instance whose cell IS in the co-simulation map, whose VCD IS
attached to the viewer, refuses:

```
ase: signal browser: no digital signals to show: 'dig.vcd' is not among the
loaded results databases: run the simulation, or re-attach its results (f3)
```

The advice is wrong in both halves: the simulation has run and the results are
attached. The viewer's own registry says so:

```
0 current
0 /tmp/xschem_eyeball_F/lib5/anlg.raw tran
1 /tmp/xschem_eyeball_F/lib5/dig.vcd   vcd
```

**The same operation succeeds when driven from the CIW.** Calling
`ase::show_in_browser_for_current` by hand, with the context first switched to
the design window, does the whole thing correctly — the tree grows the VCD
group, `TREE SEL` becomes `d:1|g:TOP`, `All DBs` ticks itself, and the caption,
header and pane all carry `showing the digital scope 'TOP' of 'dig.vcd' …`.

Three mouse gestures failed, in the same session, either side of the successful
CIW call. It is the route, not the state.

## Where it goes wrong

`ase::cosim_scope_for_f1` step 4 (`src/ase.tcl:1868`) walks
`ase::cosim_db_inventory $token` looking for the map entry's VCD.
`cosim_db_inventory` (`:1753`) asks `wviewer::signal_list_all $token` and, when
that answers `{}`, falls back to the **current context's** registry — which on
the design window is empty, so nothing matches and `notloaded` is minted.

Instrumented at the moment of a failing gesture (wrappers installed from the
CIW, logging to a file because `puts` from inside a Tk binding does not reach
the CIW):

```
PRE tok='dlib/tb1/schematic' ic=1 sla=0/0 ctx=.drw
POST n=0
```

* `tok` is correct — identical to the fixture's token, and
  `ase::session_for_current` returns the same string (`EQ=1`).
* `ctx=.drw` is the design window, holding `tb1.sch` — the right context.
* `ic=1`: the guard's `info commands ::wviewer::signal_list_all` clause is true.
* **`sla=0/0`: `wviewer::signal_list_all $token` returned an empty list**, no
  error.
* `POST n=0`: the inventory is empty, so step 4 cannot match.

The identical call from the CIW, in the same `.drw` context, returns 2 entries
(`SLA=2`, both paths listed, matching the map's `vcd=` exactly).

`signal_list_all` (`src/wave_viewer.tcl:2222`) has two ways to answer `{}`
without erroring: the token is not in `windows` (`:2224`), or
`wviewer::enter_ctx` refuses the ticket (`:2226`). `enter_ctx` (`:1257`) refuses
when the token is unknown, when `current_win_path` reads empty (the transient
documented at `scheduler.c` ~9380), or when `switch_ctx` fails.

**Which of those fires was not isolated** — a fourth wrapper tangled the live
session's renames before it logged. That is the one open question, and one clean
run with a wrapper on `enter_ctx` alone should answer it.

> **ANSWERED (2026-08-11), by exactly that run.** It is the THIRD:
> `wviewer::switch_ctx` is refused, because the gesture's own `callback()` frame
> holds `xctx->semaphore` and `switch_window`/`switch_tab` refuse on
> `if(xctx->semaphore)`. At a real gesture, with a wrapper on `enter_ctx` alone:
>
> ```
> >>> Ctrl-Alt-V ENTRY hit#1 win='' sem=1 cur=.drw
>   enter_ctx REFUSED-C(switch_ctx) inwin=1 wp='.x1.drw' prev='.drw' sem=1 ticket='0 {}' caller=wviewer::signal_list
>   enter_ctx REFUSED-C(switch_ctx) inwin=1 wp='.x1.drw' prev='.drw' sem=1 ticket='0 {}' caller=wviewer::signal_list_all
> ```
>
> `inwin=1` rules out the stale token; `prev='.drw'` rules out the empty
> `current_win_path`. Controlled, in the same session: `sem=0` → 2 databases,
> `sem=1` → 0, `sem=0` → 2 again. The second line also names issue 0313's
> clearing step, which was neither of the two candidates that issue lists.

## Why the fallback makes it worse

`ase.tcl:1763` already anticipates precisely this:

> AN EMPTY ANSWER IS NOT "the registry is empty", and treating it as one is how
> a loaded database gets reported as `notloaded`.

The comment then argues the fallback to the current context is safe because that
context "reports {} by itself when nothing is loaded — the honest empty — and
reports the real DBs when the token was simply unusable." That argument holds
only where the current context is the **viewer**. On the gesture path the
current context is the **design window**, which never has databases, so the
fallback converts "I could not ask" into "there are none" — the exact
degradation the comment forbids, reached through the door it left open.

## Suggested direction

Distinguish "the loan was refused" from "the viewer has no databases".
`signal_list_all` returning `{}` for a token that IS in `windows` means refused,
not empty; `cosim_db_inventory` can retry, or report a distinct cause, rather
than falling back to a context that structurally cannot answer. Retrying the
loan once is likely enough if the refusal is the `current_win_path` transient.

Whatever the fix, the user-facing sentence must not tell someone to re-run a
simulation whose results are already attached.

## Reproduce

```sh
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s4_item5.tcl
```

Click the left box `a1` in `tb1.sch`, press Ctrl-Alt-V → the `(f3)` refusal.
Then, in the CIW, one line:

```tcl
xschem new_schematic switch .drw ; xschem select_at -10 -10 ; ase::show_in_browser_for_current
```

→ the correct success, on the same selection.

## Not affected

Item 5's notice machinery, which is what `7ff1be9d` fixed. Both notices — the
refusal and the success caveat — reach all three surfaces and are still there
seconds later. The refusal in this issue is *delivered* perfectly; it is simply
untrue.
