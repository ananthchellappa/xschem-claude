# 0308 — the Signal Browser's lower pane reads only the CURRENT results database, so the digital scope F1 just landed on lists nothing

**Status:** **FIXED 2026-08-10, batch F item 7 (spec RULING F6). See the closing
section at the bottom of this file — it also records that the issue was WORSE than
this text says, and what was done with the arm this file told the fixer to delete.**
Was: OPEN. Not fixed. The *caption* was made truthful (spec RULING F1e, batch F item 5
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

---

## FIXED — batch F item 7, 2026-08-10 (spec RULING F6)

Commit: `feat(waveform): give the browser's sea a database dimension` on branch
`fluid-editing`, parent `1e5c2b64` — the SHA itself is written in by the one-line
follow-up commit that immediately succeeds it, because a commit cannot carry its
own hash. Receipt `doc/claude/batch_F/receipts/07-browser-sea-per-db.md`.

### It was worse than this file says, and the worse case is what the fix is proved on

Every measurement above is of two databases that share **no path**, so the symptom
is an EMPTY pane — visible, and annoying. The state nobody had measured is two
databases that carry the **same** path, which is not exotic (`time` is in every
raw and every VCD; `x1` is a subcircuit under ngspice's grammar and a module scope
under Verilog's). There the stripped prefix does not produce nothing, it produces
**the current run's signals under a foreign node, with the same count and the same
caption as the right answer**. MEASURED, `FD61`, a raw and a VCD that each own
`x1`:

```
                        shipped            ruled
foreign  d:1|g:x1  {same onlyraw}    {same onlyvcd}
current       g:x1 {same onlyraw}    {same onlyraw}
caption both       2 of 2 signals    2 of 2 signals
```

and one gesture on (`FD62`), a Plot out of that pane sent `v(x1.same)` and
`v(x1.onlyraw)` — the current raw's names — because the pane's model held them.
The same is true at the design root, which is `BD70d`'s case (`FD63`).

### The two functions this file named, and what happened to each

* `browser_reload` already snapshotted every foreign database's `names`
  (`browserdbsigs`). What did not exist was the **sea's** per-database entry list,
  so `browser_refresh`'s All-DBs loop now writes `browserseadbent($token)` in the
  same pass as the tree group it describes, and empties it at the top of every
  refresh.
* `browser_id_path` no longer decodes at all: `browser_id_split {id}` →
  `{<db> <path>}` is the ONE decode, and `browser_id_path` / `browser_row_db` are
  its two one-line projections. `browser_id_path`'s signature and answer are
  unchanged to the character, because `TP44` freezes its call sites at 1/1.

### `FD48` was RESTATED exactly as this file prescribed

Leg 2 is the six names, leg 3 the ordinary count. Two legs were ADDED —
`browser_sea_own` asked of the foreign row (6) and of nothing (0, the current
analog raw) — because "per-database" has to be an assertion and not a count.
`BD70d` in `tests/headless/test_wave_sigbrowser_i14.tcl` was restated the same
way, and its fixture is a colliding one (`time` and `v(shared)` in both raws),
which is why its movement is evidence.

### RULING F1e's arm was RE-CAUSED, not deleted — and that is a ruling AGAINST this file

The closing line above told the fixer to delete it. The fixer ruled otherwise, in
the spec as **RULING F1g**, and the reason is that this file conflated the arm's
predicate with its sentence:

* the **predicate** (`browser_sea_empty`) was never about the database — it asks
  whether the selected NODE has anything to list, and RULING F6 makes it ask that
  of the node's own database, so it now fires exactly when the landing is a pure
  ancestor, which every `partial` landing is;
* the **sentence** was about the database and is now false, so it was rewritten:
  "…but that scope has no signals of its own - open one of its sub-scopes to see
  any";
* deleting the arm would hand a `partial` landing back to a caption that never
  says the digital show succeeded, which scope was asked for, or which run the
  tree landed in — the contradiction RULING F1e was minted to remove, and the very
  thing `FV45`'s own ⚠⚠ block argues from the other side.

Item 6's sabotage **S17** predicted this fix would red `FD19`, `FD21`, `FD23`,
`FD24`, `FD26` and `FD48`. **Measured: `FD19`, `FD21`, `FD23`, `FD24`, `FD25` and
`FD48`.** `FD26` did NOT move — S17's shape (append every foreign database's
entries to the pane) is not the shape that landed, and under RULING F6 the current
database's own root is untouched. `FD25` moved and S17 did not predict it: it is a
tombstone quoting the caption that the pane reverts to, which is now
`2 of 2 signals` rather than the falsehood this issue is named for.


### The fix pass — the first landing rescued the identity and then dropped it twice

Review of the first landing found the same mistake in two of the readers'
CONSUMERS: a database identity answered correctly in one proc and thrown away in
the next. Both were made reachable *by* this fix, so they belong to this issue.

* **`Descend to here` out of the pane walked the CURRENT database's subtree.**
  `browser_sea_target_path` answered in the row's own database and handed the path
  to `browser_node_for … [browser_root_id $rows]`. Before the fix the resolver
  errored on a foreign pane and the menu entry was DISABLED; after it the entry is
  ENABLED, so the state was strictly worse than the one this issue records — the
  user was told *"'TOP.dcell' is not in the Signal Browser tree"* about
  `d:1|g:TOP.dcell`, a row of that very tree, and on a colliding pair the walk
  landed on the CURRENT database's `g:x1` with no cue at all. Ruled and fixed as
  **RULING F6a** (`browser_sea_root_id`); pinned by `FD65` and `FD66`.
* **`Send to Add Trace…` handed a bare name onward** while its sibling `Plot`
  armed the row's database — so on a colliding pair two entries in ONE menu landed
  on two different runs. Ruled and fixed as **RULING F6b** (`atddb`, an arm that
  carries the prefilled NAME as well as the registry index, because the dialog is
  modeless and meant to be edited); pinned by `FD67` and `FD68`.
* **The pane's half of the class filter had no oracle.** The write into
  `browserseadbent` is the post-`browser_class_filter` list, and feeding it the
  pre-filter list left 564 checks green while a foreign pane really did list a
  device-internal node the tree beside it hid. `BD58d`/`BD58e` now pin it, on an
  ANALOG foreign database — the only kind that can reach it, since RULING F4 makes
  the filter a no-op on digital names.
* **A mechanism sentence was wrong** in three places written by the first landing:
  `resolve_signal_db` returns the CURRENT database's match first, not the
  lowest-index one (`signal_list_all` is current-first). The conclusion it
  supported is unchanged. Corrected in `src/wave_viewer.tcl`, in
  `tests/headless/test_wave_sigbrowser_digital.tcl` and in the spec's F6 section.
  ⚠ It is NOT wrong at `src/wave_viewer.tcl:7443`, `:10004` or spec §D1's DEFECT 2
  write-up: there the current database has already refused the name, and among the
  remaining databases lowest-index IS the rule.
