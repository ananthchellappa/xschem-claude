# 0308 — the Signal Browser's lower pane reads only the CURRENT results database, so the digital scope F1 just landed on lists nothing

**Status:** OPEN. Not fixed. The *caption* was made truthful (spec RULING F1e, batch F item 5
salvage pass); the pane itself is still empty and that is what this issue is about.
**Area:** `src/wave_viewer.tcl` — `wviewer::browser_sea_refresh` (`:8025`), which draws the
lower pane from `browserseaent($token)`; `wviewer::browser_level_names` (`:6803`); the tree side is fine
(`browser_rows_multi` already gives every foreign database its own `d:<idx>|` subtree).
**Found:** 2026-08-10, measuring what batch F item 5's happy path actually leaves on screen.
**Related:** spec `doc/claude/specs/mixed_signal_signal_browser.md` §F rows **F1**, **F3** and
**F5**, and RULING **F1e**; the same limit is already pinned from the other side by **BD70d**
in `tests/headless/test_wave_sigbrowser_i14.tcl` (two-pane item 15), for the FOREIGN DESIGN
ROOT case. This issue is the case item 15 could not reach: a foreign NON-root scope, which
only became reachable when F1 started navigating to one.

---

## Mechanism

`browser_sea_refresh` resolves the selected row to a dotted path and then asks
`browser_level_names $ent $path` for that level's own names, where `$ent` is
`browserseaent($token)` — **the entries of the CURRENT database and only those**. A row that
belongs to a foreign registry slot (`d:1|g:TOP.m`) decodes to `TOP.m`, the current database
has no name under `TOP.m`, so `$pairs` is empty and `browser_sea_own` is 0.

Nothing about that is wrong for the analog tree, where every row belongs to the current
database. It becomes visible the moment something navigates the user INTO another database's
subtree, which is exactly what §F item F1's `wviewer::browser_show_db_scope` now does.

## What the user sees (measured, real viewer, `DISPLAY=:0`)

Fixture: an ngspice ASCII raw (current) plus a VCD declaring `TOP.m.siga` and `TOP.m.sigb`,
attached through `ase::attach_dbs`, sidebar on, All-DBs box off.

```
wviewer::browser_show_db_scope $tok $vcd TOP.m
  -> {alldbs d:1|g:TOP.m TOP.m}          ; the tree DID re-scope, correctly
tree selection      = d:1|g:TOP.m        ; the right row IS selected
lower pane cells    = 0                  ; and it lists NOTHING
lower pane caption  = "TOP.m has no signals of its own"     <-- FALSE
```

`TOP.m` has two signals. The caption is `browser_sea_refresh`'s shipped `seaempty` arm, which
is a true sentence about the current database and a false one about the node on screen.

## What was done, and what was not

**Done (item 5, RULING F1e + F1f):** `ase::show_in_browser_for_current` step 7b now detects
that state (`ase::browser_pane_unread` → `wviewer::browser_sea_empty`) and overwrites the
caption, the sidebar status line and the pane canvas with a sentence that is true — the scope
is shown in the tree, and the lower pane lists only the current results database. Pinned by
`FV41`-`FV46` and `FD19`/`FD19b`/`FD23`/`FD24`.

> **⚠ CORRECTION, 2026-08-10.** As first written this paragraph was FALSE on two of the three
> surfaces, and the correction is worth keeping because the mechanism will catch the next
> person. The tree landing only **queues** `<<TreeviewSelect>>`; `browser_sea_refresh` is
> delivered when the key binding returns, and its first act clears the notice while its last
> re-captions the pane from the shipped `seaempty` arm. So the caption and the canvas held the
> true sentence for exactly one event-loop turn and then reverted to
> `TOP.m has no signals of its own` — the very falsehood this issue quotes — leaving only the
> sidebar status line. RULING F1f (step 6c, one `catch {update}` below the last tree move and
> above the notice) is what makes the sentence above true; `FD23`/`FD24` assert it AFTER an
> `update`, and `FD25` is the tombstone for the state without the flush.

**Not done:** the pane still lists nothing. A user who wants `TOP.m.siga` must still switch
the current database. Two further paths are unfixed and share this cause:

* selecting a foreign row **by hand** (no Ctrl-Alt-V) gets the false `seaempty` caption, because
  the honest sentence is written by the ASE command, not by `browser_sea_refresh`;
* the foreign **design root** case, which shows the CURRENT database's top-level names as if
  they belonged to the foreign one — `BD70d`'s declared limit, worse than empty because it is
  wrong rather than absent.

## Re-measured at batch F item 6 (F3/F4), 2026-08-10 — STILL OPEN, and now PINNED

Item 6 took F3 and **did not fix this**, deliberately: F3's subject is the TREE,
and RULING F4 is a classification ruling, while what this issue needs is a
per-ROW inventory reader inside `browser_sea_refresh`. Two things did change, and
both are worth recording here.

**1. The tree half is now completely sound, which sharpens the contrast.** Before
RULING F4 a VCD whose top `$scope` was one letter had its wires classed `devnode`
and hidden by Ruling B's default-off box, so the foreign digital rows were not in
the tree at all. They are now. Measured on a healthy `:0` with a three-database
fixture (analog raw current, two VCDs foreign):

```
tree rows        d:2|g:m , d:2|g:m.sub , d:2|s:m.sub.sig , d:2|s:m.sub.count[3]   ; ALL PRESENT
lower pane cells 0
lower pane caption  "m.sub has no signals of its own"    <-- STILL FALSE
browser_sea_own  0
```

So the shape of the defect is unchanged, but it is now the ONLY thing wrong on
that path — the row exists, is selected, is correctly classified, and lists
nothing.

**2. It is pinned as a value.** `FD48` in
`tests/headless/test_wave_sigbrowser_digital.tcl` asserts all four lines above in
one tuple, with the row's presence as leg 1 so the check carries its own positive
evidence. **When this issue is fixed `FD48` must be RESTATED, not deleted**: leg
2 becomes the six names and leg 3 the ordinary count.

Its oracle is item 6's sabotage **S17**, which is the shape of the fix suggested
below (the pane appends every foreign database's entries). S17 reds `FD48` **and
five of item 5's own notice checks** — `FD19`, `FD21`, `FD23`, `FD24`, `FD26` —
which is the measured evidence for the closing line of this issue: fixing the
pane retires RULING F1e's arm, and that arm must then be DELETED rather than left
saying something no longer true.

## The fix, when someone takes F3

Make the lower pane read the database its selected ROW belongs to: `browser_row_db $id` (`src/wave_viewer.tcl:7189`) already
answers which registry slot that is, and `browserdbsigs($token)` already holds each foreign
slot's `names`. `browser_sea_refresh` would pick the entry list by row instead of always using
`browserseaent`. The two consequences to think through first are §7.2's three status sentences
(`seaempty`/`seabars`/`seaclass` all reason about the current inventory's counts) and whether
the class filters (R11) apply to a foreign database's names, which two-pane item 12 already had
to answer once for the tree (`BD58`).

Doing that also retires RULING F1e's arm — at which point the arm should be DELETED, not left
saying something no longer true.
