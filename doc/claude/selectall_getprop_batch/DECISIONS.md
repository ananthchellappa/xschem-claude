# DECISIONS — selectall_getprop_batch

Numbered decisions taken during this batch. A decision here is one the DRIVER took and is
answerable for; anything that reaches the user's eyes or changes wording they see is a
RULING and goes to them instead, via `owed.sh add rule`.

## D1 — two issues, not one (driver, 2026-09-29)

Ctrl-A (wish new-list 13) and the `getprop` arms (wish old-list 21) get **separate issue
numbers, 1617 and 1618, and separate commits**, although the user asked for them in one
breath. They share no code: one is a waveform-viewer binding over the Tcl selection model,
the other is C arms in `scheduler.c`'s dispatcher. Bundling them would make any resulting
gate red unattributable, which is the mistake issue 1615 recorded at `809c03d1` and issue
1616 avoided by splitting registration from behaviour.

## D2 — a recon stage before any code (driver, 2026-09-29)

Stage R is read-only and produces no code. It exists because the driver's own scouting was
refuted twice in the immediately preceding work: issue 1616 was scouted as "one seeded
value" and turned out to need three changes plus fixture repairs in two suites, and the
claim that its fix was narrowly scoped was falsified by a test row. The enumeration of
`getprop`'s nine arms in PLAN.md question 7 is driver scouting of exactly the kind that has
been wrong, so it is put to a crew as a question rather than handed down as a fact.

## D3 — the red row must assert on the VALUE, never on an error (driver, 2026-09-29)

Stage R crew B measured, and the driver independently re-ran, that the `getprop` `else if`
chain in `xschem_cmds_g()` has **no terminating `else`**: an unknown `argv[2]` falls through
every arm and returns `TCL_OK` with an empty result. Verified verbatim:

```
getprop line 4 0 fmt -> rc=0 result=||
getprop poly 4 0 fmt -> rc=0 result=||
getprop arc  4 0 fmt -> rc=0 result=||
getprop zzz  4 0 fmt -> rc=0 result=||
```

So a red row written as *"this errors today and must succeed tomorrow"* **would already look
green on the broken tree** — `catch` returns 0 both before and after the fix. Every Stage B
red row must assert the returned VALUE. This is the same failure class as the symptom-keyed
fence CLAUDE.md warns about, reached from the other side.

## D4 — the write-then-read-back round trip is the red (driver, 2026-09-29)

`setprop` **already has** line/arc/poly arms (`xschem_cmds_s()`, "audit 0063 atom 10"), so
item 21 is an **asymmetry, not a hole**: Tcl can already write a line/poly/arc property and
cannot read it back. Driver-verified:

```
setprop line 4 0 zz 9      -> rc=0 result=||     (write succeeds)
getprop line 4 0 zz        -> rc=0 result=||     (read comes back empty)
```

That round trip is the fence: it needs no fixture file, it cannot pass vacuously, and it
states the defect in the product's own terms. It also **settles the grammar with no tradeoff
to resolve** — `setprop`'s `<layer> <index> <token>` and `getprop`'s shipped `rect` arm
already agree, so the new arms mirror both.

## D5 — the whole-string form ships for ALL six types, with a proof obligation (driver)

`getprop <type> <layer> <index>` with the **token omitted** returns the object's whole
`prop_ptr`. This is what actually delivers wish-list item 21, because it is what lets
`xschem list_tokens` enumerate an object's properties — which already works for `instance`
and for nothing else.

The apparent tradeoff was *consistency* (extend `rect`/`text`/`wire` too) versus *not
touching shipped behaviour*. It dissolves on inspection: today `getprop rect 4 0` **errors**
(driver-verified, `rc=1`), so making it succeed is a **pure widening** — no call that
previously worked changes meaning, and only a caller that deliberately depends on the error
could notice.

⚠ **Therefore this is conditional, not assumed.** The implementer must PROVE no shipped
caller relies on that error — a census of `getprop` callers across `src/*.tcl`, `src/*.c`,
`xschem_library/` and `tests/`, reported as a count with its instrument named. Crew B's
"only literal types appear in `src/*.tcl`" is suggestive, not proof, and said so.
**If the proof fails, fall back to the new three arms only** and file the rest. Do not widen
on an unproven census.

## D6 — `getprop <unknown-type>` stays silent, and is filed not fixed (driver)

Flipping `getprop zzz` from silent-empty to an error is a change to existing behaviour with
an unaudited caller set, and PLAN.md forbids changing existing behaviour silently. It is a
real defect — it is what makes the missing arms indistinguishable from a typo — but it is a
separate issue, not a rider on this one.

## D7 — the driver's Ctrl-A claim was half wrong, and the half that was wrong changes the job

Stage R crew A refuted PLAN question 5's first half by measurement on the dev display. Over a
waveform graph, Ctrl+A does **not** reach `select_all()` — it reaches `waves_callback()` and
**toggles x-cursor A**:

```
after Ctrl+a OVER GRAPH      graph_flags=2 lastsel=0
after 2nd Ctrl+a OVER GRAPH  graph_flags=0 lastsel=0
after Ctrl+a OVER CANVAS     graph_flags=2 lastsel=20
```

`graph_flags` bit 2 is cursor A; `lastsel` never leaves 0 over the graph and goes 0→20 for the
same chord 574 px lower. The second half — that `select_all()` has zero wave awareness — was
confirmed: it selects 20 objects including one layer-2 graph rect and never touches
`hilight_wave`/`sel_waves`.

⚠ **The driver's error came from trusting a shipped comment.** `callback.c`'s
`set_input_binding(DEV_KEY,'a',ControlMask,ACTX_OVER_GRAPH,"graph.forward"); /* select all */`
carries a comment naming the CANVAS meaning that the very row diverts away from. This is
CLAUDE.md's "cite by symbol, verify cross-references" rule arriving from a new direction: a
comment on the line that contradicts it.

**So item 13 is not filling an empty chord. It is TAKING AN OCCUPIED ONE.**

## D8 — scope is WINDOW-WIDE, and this is decidable rather than a ruling

Crew A asks whether Ctrl-A should select the pointed strip's traces or every strip's. Decided:
**every strip, window-wide.** Two reasons that agree: the word "all" in the user's own wish
("CTRL-A to select all traces") has no strip qualifier, and the existing Delete path already
acts window-wide via `wviewer::delete_selection_at` → `selection_pairs`. A per-strip Ctrl-A
would mean "select all" and "delete the selection" disagreed about what "all" covers, which is
the kind of quiet mismatch that gets discovered by destroying something. Ctrl+click already
builds a window-wide set, so window-wide also matches the closest existing gesture.

## D9 — build it, and file the cursor-A price as a RULING rather than blocking on it

The user's wish list names **Ctrl-A specifically**, so implementing it is authorised by their
own words; they simply cannot have known the chord was occupied. The cost is bounded but real:

* In the **default** profile, nothing is lost — bare `a` still toggles cursor A.
* With **`graph_use_ctrl_key 1`**, Ctrl-A is the ONLY cursor-A chord (bare `a` there opens the
  make-symbol dialog), so those users would reach cursor A only through the Cursors menu.

What bounds it: Ctrl-A over a graph is **undocumented** — it appears in no manual page — and
the Cursor A/B menu entries carry no accelerator, so no printed sentence becomes false.

Per the standing instruction not to let a ruling gate progress, Stage A **builds**, and the
consequence goes to the user as an `owed.sh add rule` debt. It is theirs because it removes a
function from a profile they may be using; it does not gate the build because the fence and the
code are identical either way — only the disposition of cursor A in that one profile changes.

⚠ **Deliberately NOT done: inventing a replacement chord for cursor A.** That would add new
user-facing UI to pay for a change the user has not yet ratified, which is worse than leaving
cursor A on its menu and asking.

## D10 — three implementer traps crew A measured, all binding

1. **`wviewer::key_cursor_tail` desyncs the Cursors menu.** `key_filter`'s tail calls it for
   `N==97` with **no modifier test** (measured `kct=97` on Ctrl+a). If C stops toggling cursor
   A, the tail still flips the `cva` mirror and the Cursors ▸ Cursor A checkbutton desyncs on
   every Ctrl-A. Needs a carve-out shaped like the existing `fwd` one for 98/100.
2. **The new action must declare `mutates = 0`.** `mutates=1` routes through `readonly_block()`
   and a viewer is read-only for life, so the user would get a modal instead of a selection.
   Trace selection is view state — no `set_modify`, no `push_undo` — and `graph.forward` itself
   declares 0.
3. **`src/keybindings.csv` is GENERATED** and byte-compared by `test_bindings_file.tcl`, which
   is **unregistered**. A C-table change obliges regenerating it via
   `save_input_bindings_file` in the same change, and nothing in T1 would catch the omission.

## D11 — log nothing, because the PLAN had it backwards

PLAN Stage A said to match the siblings on replayable logging. Crew A measured that selection
gestures are **not** logged — there is no `log_action` anywhere in the Button1 selection arm —
and that the logged neighbours are the *mutations* (`delete_items`, `move_traces`,
`set_wave_hilights`). So matching the siblings means logging nothing, and adding a log line
here would make Ctrl-A the odd one out.

## D12 — the driver put two building crews in one tree, and that was an orchestration error

⚠ **This is the driver's mistake, not a crew's.** Stages A and B were dispatched concurrently
into the **same working tree with one shared `src/xschem` binary**. Both stages need to build C
(`scheduler.c` for B; `callback.c`/`draw.c`/`xschem.h` for A), so each crew's `make` compiled the
other's in-flight work into the binary the other was measuring against.

Crew B noticed and worked around it correctly, by taking its red and its first sabotage battery in
an **isolated `git archive HEAD` tree** configured and built from scratch. It also reported the
collateral honestly: it swapped `src/scheduler.c` to pristine and rebuilt the shared binary **four
times**, so any suite crew A ran inside those windows saw a `getprop`-less binary, and one of its
builds hit a transient link failure racing crew A's `make`.

**Consequences the driver must act on, not the crews:**

1. **Crew A's greens are suspect until re-measured.** Any suite it ran during those four windows
   may have been measured against a binary that was not the tree. The driver re-verifies Stage A's
   result itself rather than accepting the receipt's numbers.
2. **The T1 gate must not race a live crew.** CLAUDE.md records that a suite hand-run while T1 was
   live has reddened a gate run, so Stage B's gate waits for Stage A to hand back even though
   Stage B's own work is finished and committable.

**The rule for the rest of this batch and any future one: concurrent crews that BUILD get isolated
trees**, or they are serialised. Read-only recon crews may share a tree — Stage R's two crews did,
with no conflict, because neither compiled anything. Crew B's receipt §8.1 carries the working
isolated-tree recipe; it is the method, not a workaround.
