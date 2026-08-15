# 0313 — a refused Ctrl-Alt-V empties the Signal Browser, and only an unrelated checkbox brings it back

**Status:** FIXED 2026-08-11. **The clearing step was NEITHER of the two
candidates below.** It is `wviewer::browser_reload` overwriting `browsersigs`
— the browser's whole model — with the empty answer of a REFUSED context loan,
the same refusal issue 0314 turned out to be: the gesture's own `callback()`
frame holds `xctx->semaphore`, so `wviewer::signal_list`'s loan was refused and
its `{}` was read as "the viewer has no signals". Measured (`caller=signal_list`
in the receipt's log), fixed and sabotage-verified in
`doc/claude/batch_F/receipts/14-0314-0313-gesture-context-loan.md`. A refused
reload now keeps the previous snapshot, so the refusal falls through with the
analog listing still on screen (RULING F1b). Check: `FD72` (sabotage S3).
**Filed:** 2026-08-11, from the Batch F eyeball queue (session 4, item 5 step 4).
**Found by:** hand. Every automated check for item 5 asserts on the notice's
three surfaces, and the notice is correct — what none of them assert is what
happened to the rest of the sidebar.
**Related:** Batch F item 5 (`fda9d5a8` + `7ff1be9d`), RULING F1b (a refusal
falls through, it does not strand the user), issue 0308, issue 0309.

## What happens

Pre-state, sidebar open on an analog design: the tree's design root is selected,
the lower pane lists `time` and `v(anlg)`, the caption reads `2 of 2 signals`.

Select an instance whose cell has a `verilog` view but **no entry in the
co-simulation map** (the `nomap` refusal path) and press **Ctrl-Alt-V**. The
notice arrives correctly, on all three surfaces:

```
PANE CAPTION: no digital signals to show: no entry of the co-simulation map
              matches cell 'dlib/dcell2' (module 'dcell2', model 'dcell2'): …
SIDEBAR HEAD: Signal Browser >> no digital signals to show: …
CANVAS NOTE : 1 item(s)
```

But the rest of the sidebar has been emptied:

```
PANE ROWS   : 0          <-- was 2 (time, v(anlg))
TREE SEL    : g:         <-- the design root, still selected
ALL-DBS BOX : 0
```

and the tree itself is down to the single root row (`anlg`). The analog listing
the user was looking at is gone.

**It does not come back by clicking.** The design root is still the selected
row, so clicking it sets the selection to what it already is, ttk fires no
`<<TreeviewSelect>>`, and nothing rebuilds. The user has to find some *other*
control that forces a refresh. What worked was ticking and unticking
**`Show device internals`** — a class filter that has nothing to do with the
gesture that emptied the pane.

## Why it matters

RULING F1b's whole point is that a refusal **falls through**: "the analog path
still runs and still lands where it always did; F5's notice … is what says why
the digital pane the user asked for is not there. Refusing outright would
replace a partial answer with none." Here the refusal does replace the partial
answer with none — it lands on the design root and then shows nothing about it.

The notice is also strictly worse for it. `browser_sea_draw` (`:8204`) draws the
sentence into the pane **only when the pane has nothing to draw** — "it may
never overprint names" — precisely so the notice reads as "the digital pane you
asked for is missing" and not "this pane is empty". With the analog names gone,
the user sees an empty pane carrying a refusal, which is the state F5 exists to
prevent, reached from the other direction.

## Where to look

The clearing step is **not isolated** — this is a hand observation, and the two
candidates were not distinguished:

* `src/ase.tcl:2668` — step 6b's last-mile retry. `browser_show_path` with the
  base path re-lands the design root. If that row is already selected, ttk's
  `selection set` is a no-op and the queued-refresh contract that step 6c
  (`catch {update}`, `:2686`) depends on never fires. The comment at 6c states
  the dependency explicitly: the refresh is what rebuilds `browsersea`.
* A tree rebuild somewhere on the path collapsing the tree to its root and
  clearing the pane model, with the notice then landing on the empty result.
  The tree being down to one row (`anlg`) points this way and the two are not
  exclusive.

A `-d 1` run through the a2 gesture, watching `browsersea` and the
`<<TreeviewSelect>>` deliveries around `:2686`, should settle it in one pass.

> **SETTLED (2026-08-11), and it is a THIRD cause.** `browser_reload`
> (`src/wave_viewer.tcl`) rebuilds `browsersigs($token)` — which feeds BOTH the
> tree's node set and the lower pane — from `wviewer::signal_list`, and on the
> gesture path that call was refused, not empty. Instrumented at the a2 gesture:
>
> ```
>   enter_ctx REFUSED-C(switch_ctx) ... caller=wviewer::signal_list
>   TREE(after-a2): top=1 rows=g:/0 sel=g:     <- collapsed to the bare root
>   browsersea(after-a2): 0 entries
>   PANE ROWS : 0
> ```
>
> Step 6b's retry did re-land the design root and did queue nothing (as this
> issue predicted), but that is not what emptied the pane: the model had already
> been wiped one step earlier. Both candidates above are innocent.

## Reproduce

```sh
DISPLAY=:0 ./src/xschem --script /tmp/xschem_eyeball_F/tcl/s4_item5.tcl
```

Click the middle box `a2` in `tb1.sch`, press Ctrl-Alt-V, then type `e5cap` in
the CIW. `PANE ROWS` reads 0 where the pre-state read 2. Click the root row —
nothing. Tick and untick `Show device internals` — both panes come back.

## Not affected

Item 5's own claim. The notice is written, is on the caption, the sidebar header
and inside the pane, and is **still there seconds later** — the
written-and-erased-in-one-turn defect that `7ff1be9d` fixed has not returned.
The refusal text itself is correct and names the right cell, module and model.
