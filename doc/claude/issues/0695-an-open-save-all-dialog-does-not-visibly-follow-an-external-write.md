# 0695 — an open `Save All` dialog does not VISIBLY follow an external write

Status: **FIXED 2026-08-25** (status **E** — user-visible, unratified; see
"Decisions" and rule debt [0692]). Fixed together with **0696** in one item,
because both ask one question. Filed 2026-08-25 by the 0691+0692 crew as the
declared residual of the 0692 fix. Related: **0692** (fixed — the state half),
0679, 0648 (the dialog's diff/cancel model), 0696, **0697** (the one writer that
still does not fire the hook this fix hangs off).

⚠ **SEVERITY RAISED 2026-08-25 BY THE SAME CREW'S WRITE-UP PASS, BEFORE THIS
EVER SHIPPED.** This was filed as a cosmetic lag. It is not: the display lag has
a DATA consequence, measured below (§ "The lag is not cosmetic"), reachable with
two shipped menu items. The sentence "the display lag is not a data-loss defect
once OK and ESC are honest" below was **wrong when written** and is struck
through where it appears. Treat this as blocking for the 0692 ruling, not as a
follow-up nicety.

## What 0692 fixed, and what it deliberately did not

0692's defect was that an OPEN `Save All` dialog is a snapshot: the pasted CIW
remedy turned the OP gate ON behind it and OK wrote the stale `0` back. That is
fixed — `ase::ui::save_all_resolve` (src/ase_window.tcl:3419) now takes the user's value for a box they
touched and the LIVE value for one they did not, and `save_all_cancel` (:3488) diffs
against the AS-OPENED seed so ESC no longer prints a phantom "was NOT applied"
about a setting that *was* applied.

**The pixels still lag.** Measured after the fix, through the real widget on
`:99` with openbox live:

```
PROBE0692  seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0 ok_rc=1 gate_after_ok=1
PROBE0692C seed=0 remedy_rc=1 gate_after_remedy=1 box_still=0
           phantom_discard_notices=0 gate_after_esc=1
```

`box_still=0` is this issue: the checkbutton keeps displaying the pre-write value
until the dialog is closed and reopened. OK and ESC are now correct about the
state; the widget is not correct about itself.

## Why it was not fixed with 0692

A live refresh is 0692's **option 1** (re-seed from inside
`ase::ui::save_all_commit`), which the 0692 write-up flags with a ⚠ of its own:
it puts a widget side effect into the shared writer the pasted remedy calls, it
would silently move a box the user had just ticked by hand and not yet OK'd, and
it changes what 0679's SAB-N6 sabotage discriminator proves. L2: smallest blast
radius wins, ~~and the display lag is not a data-loss defect once OK and ESC are
honest~~ — **that struck clause is false; see the next section.**

## The lag is not cosmetic — measured, two shipped menu items

Because `ase::ui::save_all_resolve` gives an **untouched** box the LIVE value,
and the checkbutton does not follow the live value, an open dialog can DISPLAY a
ticked box while OK writes it **off**. Measured after the 0692 fix, on `:99` with
openbox 3.6.1 live, driving the real product workers:

```
WU-B2 box_at_open=1 load_rc=1 live_after_load=0 box_still=1 ok_rc=1 gate_after_ok=0
```

The gesture is entirely ordinary:

1. `ASE-L > Outputs > Save All` with 'Save device OP parameters' **ticked**
   (`box_at_open=1`), left open.
2. `ASE-L > Session > Load State`, importing a state whose gate is off
   (`live_after_load=0`). A shipped menu item, not a probe seam.
3. The checkbutton still shows **ticked** (`box_still=1`).
4. Press **OK** → the gate is written **off** (`gate_after_ok=0`).

At HEAD this wrote **on**, matching the box the user was looking at. So for this
gesture the 0692 fix is a regression in what the user GETS versus what they SEE,
and not a harmless one: `ase::op_cards_capture` gates the whole OP-card block on
`save_op_params`, so the next deck is emitted with **no OP save cards** while the
dialog says they are on — the silent-missing-numbers failure the whole 0648/0679
arc exists to end.

⚠ This is not an argument for reverting 0692. Both halves cannot be satisfied at
once: "an untouched box takes the live value" is what fixes the reported defect,
and it is only coherent when the box FOLLOWS the live value. Fixing this issue is
what makes the 0692 reconcile whole.

## Pinned, so it cannot be forgotten

`tests/headless/test_ase_window.tcl`, row **W1x**, third term
(`box_before_ok`) is pinned at `0` with a comment naming this issue. **Flip that
term to 1 when this lands.**

## Acceptance (when scheduled)

1. An external write to any of the three blankets behind an open dialog moves the
   corresponding checkbutton, read off the widget's own `-variable`.
2. A box the user has ticked by hand and not yet OK'd is NOT moved by it (the
   conflict the ⚠ above names) — or, if it is, that is a ratified ruling and not
   a side effect.
3. W1x's third term is 1; W1y/W1z/W1za stay green.
4. **The `WU-B2` gesture above**: with the dialog open and showing a ticked box,
   a `Load State` that turns the gate off must not leave OK writing a value the
   user cannot see. Either the box follows (rows 1–3), or the race is reported
   (0692's rule debt, option (a)) — but "shows on, writes off" may not ship
   unratified.

---

# RESOLUTION — 2026-08-25, fixed with 0696 as ONE item

Pure Tcl, one product file: `src/ase_window.tcl`. No `.c/.h/.y/.l` changed, no
`make`, no `./configure` (`find src/ -maxdepth 1 \( -name '*.c' -o -name '*.h' -o
-name '*.y' -o -name '*.l' \) -newer src/xschem` is EMPTY, `src/Makefile.in`
untouched). xschem sources the `.tcl` at startup, so every measurement below is
the new code running on the same binary the baseline used.

## BEFORE → AFTER, the SAME probe, verbatim

BEFORE (re-measured by this crew, not copied from the filing):

```
WU-B2 box_at_open=1 load_rc=1 live_after_load=0 box_still=1 ok_rc=1 gate_after_ok=0
WU-B1 seedbox=0 remedy_rc=1 gate=1 pending={opparams} notices=1
WU-B1-NOTICE: ASE: Save All was closed without OK — 'Save device OP parameters'
              was NOT applied. Reopen Outputs > Save All and press OK.
WU-B1 gate_after_esc=1
CONTRAST-A plain-hand-tick-ESC notices=1 gate=0
CONTRAST-B untouched+external-ESC notices=0 gate=1
```

AFTER, same script, same display (`:99`, Xvfb 1920x1080x24, **openbox 3.6.1
live** — `devdisplay.sh status: wm: openbox (Openbox)`):

```
WU-B2 box_at_open=1 load_rc=1 live_after_load=0 box_still=0 ok_rc=1 gate_after_ok=0
WU-B1 seedbox=0 remedy_rc=1 gate=1 pending={opparams} notices=0
WU-B1 gate_after_esc=1
CONTRAST-A plain-hand-tick-ESC notices=1 gate=0
CONTRAST-B untouched+external-ESC notices=0 gate=1
```

Read `WU-B2` as the acceptance rows read it. `box_still` went `1 → 0`: the
checkbutton **followed** the `Session > Load State` that landed behind it, read
off the widget's own `-variable`. `gate_after_ok` is still `0` and that is
correct — **the point is that it now equals what the box was showing**
(acceptance row 4). `gate_after_ok == 1` would have been the wrong assertion.

`WU-B1` is 0696: `notices 1 → 0` with `gate_after_esc=1` unchanged. Note
`pending={opparams}` is **unchanged and deliberate** — the user really did touch
that box, so `save_all_touched` still names it; the narrowing lives in the
CONSUMER (`save_all_discarded`), which is decision D2.

Both CONTRAST arms are byte-identical before and after: a plain hand tick still
reports exactly once, and 0692's fixed gesture is still silent.

## What changed, in six edits

1. `save_all_dialog` clears `dlg($key,touched)` **at open** (`dialog_frame`
   destroys an existing toplevel with **no** cancel, so the re-open path runs no
   teardown at all).
2. The three checkbuttons gain
   `-command [list ase::ui::save_all_mark_touched $key <field>]`. Before this the
   product had **no touch event at all** (`command={}`, measured), which is why
   "the user changed this box" had to be a value diff.
3. `ase::ui::save_all_seed` → `ase::ui::save_all_mark_touched`; the as-opened
   `dlg($key,seed)` record is **deleted** (decision D5).
4. NEW `ase::ui::save_all_refresh {key}` — the follow. Total no-op unless a Save
   All dialog for that key is really up; otherwise it paints
   `save_all_resolve`'s output into the three linked variables.
5. NEW `ase::ui::save_all_discarded {key}` — 0696's narrowed cancel predicate,
   `touched AND box ne live`, feeding BOTH the notice and the nudge re-arm.
6. `ase::ui::session_changed` gains ONE line, called **last**:
   `ase::ui::save_all_refresh $key`.

`save_all_commit`, `save_all_apply`, `save_all_current`, `save_op_params_on`,
`save_all_report_discard` and the nudge model are **untouched** — so 0679's
SAB-N6 discriminator still proves what it proved, and 0648's diff/cancel model is
not reworked (the scope fence held; only the predicate feeding it moved).

## Decisions (ladder rung, and the rejected alternative)

| # | rung | decision | rejected, and why |
|---|---|---|---|
| D1 | **L1 (I1)** | **"touched" is a widget EVENT** (`-command`), never a value diff. One definition of "the user changed this box" | keep the seed diff and follow only untouched boxes — smaller, and **refuted by measurement**: H2 (box follows to 0, user hand-ticks back to 1) gives `touched={}` → resolve answers 0 → `gate_after_ok=0`, i.e. the user's own tick is silently discarded; H1 (a followed box) reads as touched → ESC prints a phantom discard, reinstating 0692 |
| D2 | L2 | a **touched field stays touched** even when the live value later drifts to equal it — the box the user put a hand on never moves again under that hand | "re-cleaning" a field once live catches up: reads well for the ESC notice, re-opens H2 for OK because the field would go back to following. The ESC half is solved at the consumer instead (`save_all_discarded`), which changes nothing about what OK writes |
| D3 | **L1 (I1)** | the follow paints **`save_all_resolve`'s output**, not the raw live state — ONE builder, TWO consumers (the widget and the OK write) | painting `save_all_current`: it would MOVE a touched box, and it would give the widget a second independent definition of the dialog's meaning — I1's silent-failure mode, and how the ESC arm drifted in the first place |
| D4 | L2 + L1 | the seam is **`ase::ui::session_changed`**, the existing single-slot `ase::session_notify` hook, one line, called last | 0692's option 1 (re-seed inside `save_all_commit`): a widget side effect in the shared writer, it changes what SAB-N6 proves, and it would **not cover `Session > Load State` at all** — this issue's own measured gesture. Also rejected: a Tk `trace` on the state (a new mechanism where a fired hook already exists) |
| D5 | L2 | **delete** `save_all_seed` / `dlg($key,seed)` rather than keep it as a dialog-less fallback | keeping it: its own docstring claimed the fallback existed for "a dlg record poked in directly with no dialog, which several suites do" — measured FALSE (no product path, no suite; the only direct pokes are `dlg($key,anen\|antype)`). **COST ACCEPTED:** SAB-0692-B ceases to exist; SAB-0695-A/B/E replace it, and W1zb's 5th term pins the deletion |
| D6 | L2 | `save_all_ok` **keeps the per-field reconcile** (touched → box, untouched → LIVE); OK does not simply write what the boxes show | resolve-from-the-boxes (purest WYSIWYG): it makes OK depend on the follow having fired, so any writer that reaches the state without firing notify puts **0692** back — a silently reverted external write. With resolve unchanged, that path degrades to a pixel lag instead of a lost write. **0697 is exactly such a writer**, which is what makes this the right call rather than a theoretical one |
| D7 | L2 | the one remaining non-notifying writer is **filed as 0697, not fixed here** | fixing it: it changes the session model's notify contract for every open/raise path, none of which this item measured — the scope fence |
| D8 | **L3** | ship it and mark the step **E** | it is user-visible with no prior ratification; rule debt **[0692]** is RESTATED (not discharged) and a `look` debt records the four gestures |

## Sabotage matrix (Verify-B, on `:99`, openbox live)

| variant | how | predicted red | observed |
|---|---|---|---|
| SAB-0695-A | `save_all_refresh` → no-op stub (callee renamed `_real`) | W1x, W1zc, W1zc2, W1ze | **all 4 + GE10j** |
| SAB-0695-B | `save_all_mark_touched` → `return {}` | W1y, W1z, W1za, W1ze, G5c, GE10c/d/f | **all 8**, 15 red lines total; GE10k stayed GREEN by design (it asserts the `-command` NAME, which a body swap cannot move) |
| SAB-0695-C | `save_all_discarded` → `return {}` | W1za, GE10c/d/f/g | **all 5 + W1za2** |
| **SAB-0696-D** | `save_all_discarded` → `return [save_all_touched $key]` (the PRE-FIX predicate) | **W1zd only** | **W1zd ONLY**; `test_ase_dialogs` stayed ALL PASS (174). The sharpest discriminator in the set, and the one that isolates 0696 |
| SAB-0695-E | `save_all_touched` → `{allv alli opparams}` | W1x, W1zc, W1zf, W1za(n_ext) | **all 4 + W1z, W1ze, GE10j**; W1za's `n_ext` term red = 0692's phantom discard reinstated, as claimed |
| SAB-0695-F | `save_all_resolve` → `{allv 0 alli 0 opparams 0}` (**the I1 discriminator**) | W1x, W1y, W1z, W1ze, W1zc, G5c | **all 6**, 13 red lines: BOTH consumer families (widget rows AND OK-write rows) reddened in one shot, which is exactly what "one builder, two consumers" claims |
| SAB-G (unplanned, Verify-B's own) | delete the `save_all_refresh $key` LINE from `session_changed`, proc left intact | — | W1x, W1zc, W1zc2, W1ze, GE10j — identical to SAB-A, so the **wiring** is covered and not merely the proc's existence |
| CONTROL (not sabotage) | full revert to `git show HEAD:src/ase_window.tcl`, both test files left fixed | — | **8 red**: W1x, W1zb, W1zc, W1zc2, W1zd, W1ze, W1zf, W1zg. Every new/edited row is RED at HEAD |

**No predicted red failed to appear.** Restore after every variant was `cp` +
`touch` (never `cp -p`), with `grep -rn SABOTAGE src/` empty and the suites
re-asserted green (214 / 174).

## Still open (adversary residuals — read these before calling the feature done)

1. **0695's SYMPTOM IS STILL REACHABLE on one path**, and it is a shipped one:
   `ase::session_open`'s re-open refresh arm (`ase.tcl:2696`) replaces a clean
   session's whole state from disk and fires nothing.
   `ATK-2 box_at_open=1 live_after_reopen=0 ok_rc=1 gate_after_ok=0 WYSIWYG=0` —
   box ON, OK writes OFF, **identical pre- and post-fix**. Reachable from the
   Library Manager (`library_manager.tcl:453`) and `xschem.tcl:6196`. Filed as
   **0697** and named verbatim in the `look` debt; NOT fixed.
2. **The net-zero hand gesture changed for the worse versus HEAD.** Tick a box
   twice (back to its as-opened value), then `Session > Load State` behind the
   dialog: post-fix `ATK-1 gate_after_ok=1` — the import is silently reverted —
   where HEAD deferred to live (`0`). WYSIWYG still holds, so this issue's own
   claim survives, but 0692's "an open dialog no longer silently reverts an
   external write" is **narrowed**. Disclosed as rule debt **[0692](d)**; there
   is deliberately **no test row** pinning it either way, because the ruling is
   the user's.
3. **The follow is the first casualty of any unrelated throw in
   `session_changed`.** `session_notify_fire` wraps the hook in a `catch`
   (`ase.tcl:2680`) and `save_all_refresh` is called LAST, so a future defect in
   `refresh_title`/`refresh_status` silently re-opens this issue with no row red
   (`FRAG-1 WYSIWYG=0`, produced with an armed throw). The adversary hunted for a
   NATURAL trigger — state with `design` unset, `temperature` unset,
   `temperature {}`, malformed `analyses` — and found none (`FRAG-2 followed=1`
   in all four). **Latent, not live.** W1zg asserts the notify slot and the
   callee's existence; nothing asserts the refresh is REACHED.
4. **The I1 comment above `save_all_refresh` overstates.** It says flatly that
   what the user sees and what OK writes "CANNOT drift silently"; residual 1 is a
   measured counter-example, and the 0697 caveat lives ~700 lines away in
   `session_changed`. On this branch an overstated comment two lines from the
   code is the exact failure family being fixed. **Left as-is only because the
   caveat is now in this file and in 0697; a future editor should tighten it.**
5. **There are now TWO writers of the three linked variables** — `save_all_dialog`
   seeds them from `save_all_current`, `save_all_refresh` repaints them from
   `save_all_resolve`. They agree only because `touched` is empty at open. That
   is a latent second source for the same records, one leak away from
   disagreeing — precisely the I1 shape D3 invokes against.
6. **`save_all_discarded` compares the RAW box value to live**, not
   `save_all_resolve`'s output — a third reading of "what does this dialog mean".
   Consistent today only because resolve returns the box's own value for a
   touched field; any change to that rule silently desynchronises the ESC notice
   from what OK writes.
7. **The discard sentence still reads "was NOT applied" for a discarded UNTICK**
   (`ATK-8`: the message names the box while the gate IS on). Pre-existing prose
   drift, **issue 0661**, correctly out of scope here — but it is the same "a
   report that lies" family and the user will meet it on the bench.

## Acceptance — measured

| # | acceptance row | verdict |
|---|---|---|
| 1 | an external write moves the corresponding checkbutton, read off the widget's `-variable` | **MET** — `WU-B2 box_still=0`; W1zc moves TWO boxes in OPPOSITE directions in one import (OP gate 1→0, `Save all voltages` 0→1), so it cannot pass on a refresh that always answers 0 |
| 2 | a box the user ticked by hand and not yet OK'd is NOT moved | **MET** — D1/D2; W1ze pins it (the hand tick survives a follow), W1zf pins that a follow is not a touch |
| 3 | W1x's third term is 1; W1y/W1z/W1za stay green | **MET** — `{0 1 1 1 1}`; the whole suite 208 → 214 ALL PASS |
| 4 | the `WU-B2` gesture must not leave OK writing a value the user cannot see | **MET** — the box follows (rows 1–3), and W1zc2 asserts the EQUALITY `gate_after_ok == box_before_ok` rather than a literal, so it stays honest whichever way the live value moved. ⚠ **on the `ase::session_open` path this row is still UNMET — issue 0697** |
