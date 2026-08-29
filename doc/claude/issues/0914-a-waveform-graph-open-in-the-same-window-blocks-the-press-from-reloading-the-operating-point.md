# 0914 — with a waveform graph open, taking a stale operating point off is a one-way door: the press blanks the sheet and never reloads

STATUS: FIXED 2026-08-28 (item B1, repair pass) — two branches in
`cadence::annot_mode`, `utils/annot_mode.tcl`. Found by item B1's sabotage pass,
reproduced independently three ways before the repair, and re-measured against
HEAD to separate the regression half from the pre-existing half.
FOUND IN: `cadence::annot_mode`, `utils/annot_mode.tcl` — the `$loaded >= 0` arm
taken immediately after `op_annot::db_detach`, and the whole-registry
`xschem raw clear` in the RULING 0856 unwind at the tail of the same proc.
RELATED: [0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md)
(whose fix made the regression half reachable),
[0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md) (the
re-attach-or-blank contract this breaks),
[0902](0902-the-transient-annotation-gate-unloads-databases-it-never-attached.md) (the
bare `xschem raw clear` this arm had left),
[0908](0908-the-annotate-tick-can-show-another-corners-operating-point.md) (the
opposite error, still fenced).

---

## 1. What the user does, and what they see

The bench state is the ordinary one: **a waveform graph is open on the sheet**.
That graph is a second database in the same window's registry, and every
hand-attach row written for 0684 and 0910 staged an EMPTY window instead.

**Half A — the regression. Nothing was re-run at all.**

```
  the user has a waveform strip on the sheet (a transient)
  Waves > Op Annotate  ->  numbers appear:  id = 10u | gm = 100u | gds = 1u
  press 6              ->  id =  | gm =  | gds =
                           "Showing device operating-point values on the
                            schematic. The loaded results do not include an
                            operating point, so there are no device values to
                            show. Load a different results file from
                            Waves > Op Annotate, then press again."
```

Nothing had been re-run and nothing on disk had changed. Dumping the window's
registry either side of that press shows the operating point is **deleted, not
hidden**: `1 current / 0 …/foreign.raw tran / 1 …/mos.raw op` before, and
`0 current / 0 …/foreign.raw tran` after.

**Half B — the same defect after a real re-run, and this half was true of the
shipped tree too.**

```
  waveform strip open, Waves > Op Annotate, press 6  ->  id = 10u | gm = 100u …
  the simulation is re-run, rewriting the same path
  press 6 again  ->  id =  | gm =  | gds =
```

The press that should have painted the new numbers blanks the sheet instead.

## 2. Why

`cadence::annot_mode` decides what to do next by asking `xschem raw loaded`
**immediately after taking its own operating point off**:

```tcl
    if {$annotated && !$live} {
      ::op_annot::db_detach
      set annotated 0
      set loaded -1
      catch {set loaded [xschem raw loaded]}      ;# "is ANY database attached"
      ...
    }
    if {$live} { ... } elseif {$loaded >= 0} { set state noop } else { ...search... }
```

`xschem raw loaded` answers *"is **any** database attached to this window"*, not
*"is one of **ours**"*. With a waveform graph open, the graph is still there and
still answers 0, so control takes the `noop` arm — "a raw is loaded and the rows
render blank anyway" — and the press **never looks for the results file it was
about**. With an empty window the same re-read answers −1 and the press works,
which is why every row in the suite passed.

The two halves differ only in what makes `db_current` answer 0:

* **Half B (pre-existing)** — the freshness stamp differs after a re-run. Guard
  G4's headline arm. Reachable on HEAD.
* **Half A (regression from 0910)** — first sight of this surface's own
  candidate is re-read rather than trusted. Guard G3a-2, added by item B1.
  Before 0910 that first press answered "current" and never detached, so the
  numbers survived by accident.

Measured 2026-08-28 with the identical probe against HEAD's `db_current`: half A
passes on HEAD (`"These results were already loaded."`, registry unchanged) and
fails on the delivered tree. Half B fails on both.

## 3. The second door: the unwind would have taken the graph away

Letting the press reach the file selector with a graph still in the window also
lets it reach the RULING 0856 unwind at the tail of that selector — the arm that
runs when the file it found turns out to be a transient and puts everything
back. That arm's own comment says *"we are only here because `xschem raw loaded`
was < 0 on entry, so the clear returns the session to exactly the state the key
press found"*, and it unwinds with a **bare `xschem raw clear`**, which unloads
**all** raw files (`src/scheduler.c`). The premise stops being true the moment
this fix lets the arm be reached with a graph in the window, so repairing §2
alone would have re-opened issue 0902's data loss through a new door: the user's
trace unloaded by a press that was only ever about the operating point.

## 4. The fix

`utils/annot_mode.tcl`, both inside `cadence::annot_mode`:

1. `db_detach`'s own answer is kept as `$took`, and the `noop` arm is asked as
   `!$took && $loaded >= 0`. Once this surface has taken its database off, "is
   something loaded" is not the question any more, whatever else the window is
   holding.
2. The unwind splits on `$entry_loaded`, the reading taken **before** the
   detach: empty on entry → the bare clear, byte for byte as RULING 0856 and row
   V31c ask; anything else → take off only what this proc attached, by name,
   through `op_annot::db_detach`.

Nothing in `src/op_annot.tcl` changed for this. No new user-facing sentence was
minted: the press now reaches the sentence the mint already had
(`" Loaded results from <path>."`, `utils/annot_mode.tcl`), so RULING **D5-4**
is untouched.

## 5. What is NOT changed, and was checked rather than assumed

* **Ruling 0857 stands.** With **only** a transient in the window and no
  operating point ever attached, `6` still does nothing and still says "No
  operating point results are loaded. These are from a 'tran' run instead …".
  `$annotated` is 0 there, the detach arm is not entered, `$took` stays 0 and the
  `noop` arm is reached exactly as before. Measured.
* **Issue 0908 stands.** A press whose candidate names a DIFFERENT file still
  leaves another corner's operating point exactly where it is, with a graph open
  or without. Rows F40 and F41 leg b.
* **ASE-L's `Results > Annotate` tick and `annot_refresh_here` were already
  right** on this bench state — they detach and then attach, with no "something
  is loaded, so stop" arm — measured on the delivered tree before the repair.
  Row F43b keeps them right.

## 6. Rows

`tests/headless/test_annot_stale_0684.tcl`, 46 → 52 checks:

| row | what it sees |
|---|---|
| **F43** | half A: graph open, menu attach, nothing re-run, three presses keep the numbers, the graph is still in the window, one read total |
| **F43b** | the same bench state on ASE-L's `Results > Annotate` tick |
| **F44** | half B: graph open, re-run at the same path, the press paints the NEW numbers and keeps the graph |
| **F45** | the unwind: the re-run left a transient where the operating point was — the press blanks, says which analysis it really found, puts the mask back, and **leaves the user's graph loaded** |
| **F46** | STRUCTURAL, and it replaces a false claim — see §7 |
| **F47** | the no-argument `op_annot::_db_forget` actually wipes, seen through the same-path question |

Sabotage, each applied alone: dropping `!$took` reds F43, F44 and F45; making the
unwind bare-clear again reds F45; dropping either emptiness term or the `catch`
in `db_current`'s first-sight branch reds F46; gutting `_db_forget`'s wipe loop
reds F47.

## 7. Two shipped claims that were false, corrected here

* `src/op_annot.tcl` said `$cand ne {}` had to stay above the normalize because
  **`file normalize {}` answers the current working directory**. Measured in the
  interpreter this runs in, **Tcl 8.6.14, it answers the EMPTY STRING**. The
  comment also named row F41 leg c as the term's witness; F41 is green with
  either emptiness term deleted, and so is every other row in the tier list. Both
  sentences are replaced with the measurement, and row **F46** is a real
  structural witness whose first leg re-measures `file normalize {}` every run.
* Row F41's own leg-c comment carried the same false mechanism and is corrected
  the same way.

The terms themselves stay. Deleting a guard because no row can see it is the
trap issue 0684 catalogued six of; the answer is to add the row.

## 8. What is still owed

A `look` debt: a real ngspice bench with a waveform strip open — load an
operating point from `Waves > Op Annotate`, press `6`, and watch the numbers
stay; then re-run and press `6` and watch them change. Green suites do not
discharge it.
