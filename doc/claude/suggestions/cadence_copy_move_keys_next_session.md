# Resume: C-copy / M-move command-mode in the symbol editor (Cadence-style)

Paste this to resume. **First read:** memory `cadence-pin-name-text` (and `wire-stub-netlabel`),
and spec `doc/claude/specs/cadence_pin_name_text.md`. Branch **`cadence-pin-name-text`** (off
`fluid-editing`).

> **STATUS 2026-06-30: DONE + COMMITTED.** Noun-verb C/M committed `374bf826`; P4 committed
> `d54e0e92`. **True verb-noun is now SOLVED** (user GUI-confirmed working). The "deltax==0 on
> drop" theory below was a RED HERRING — new `xschem get deltax|x1|x2|...` getters proved the
> gesture completes fine; the real bug was that a pin's stub LINE (SYMLAYER) sits at distance 0
> through the pin centre and `find_closest_line` wins ties, so a centre click selected the LINE
> not the pin. Fix: empty c/m arm MENUSTART (callback.c); check_menu_start_commands selects the
> object under the click when nothing is selected; find_closest_box scores a click inside a
> PINLAYER body as distance 0 and lets pins win ties. Test `tests/headless/
> test_verb_noun_copy_move.tcl` (13 checks). Full write-up of the debugging saga:
> `doc/claude/code_analysis/observable_debugging_tutorial.md`. The rest of this doc is the
> historical resume note (kept for the root-cause archaeology).

## Where we are
The Cadence-pin-owned-name-text feature is largely done and committed (P0–P3.6 `35cd449a…8c4ead6f`,
P3.7 preview `81fa73d9`, review fixes `93a54f76`, D-sel/D-split/Apply `d1f1d53a`). On top of
`d1f1d53a` there is **UNCOMMITTED** work:
- **P4 copy/paste view handling** (`src/move.c`, `src/paste.c`, +8 checks in `tests/pin_name_text.tcl`):
  copying/pasting a pin regenerates its name view (never duplicates it as a stray text). DONE +
  sabotage-verified; `pin_name_text.tcl` is **73/73**.
- **C-key copy / M-key move UX** (`src/callback.c`, comments in `src/scheduler.c`): see below.

Build/run: `cd src && make && ./xschem`. The user runs the GUI as `src/xschem --script
src/cadence_style_rc` with **`infix_interface = 0`** (important — see below). Commit only when asked;
end commit messages with the Co-Authored-By line.

## THE CURRENT EFFORT — C/M keys in the symbol editor (this is what's giving trouble)
Goal (user, Cadence-style): in the symbol editor, select a pin and press **C** → the copy should
follow the cursor IMMEDIATELY (one click drops). **M** → same for move. With nothing selected,
pressing C/M should give feedback and ideally let you click a pin to copy/move it (verb-noun).

### CRITICAL discovery (don't re-learn this)
The **C and M KEYS are handled in `callback.c` `case 'c'` (~line 4059) and `case 'm'` (~4376)**,
NOT by the `xschem copy_objects`/`move_objects` COMMANDS in scheduler.c. The commands are the
**Edit▸Duplicate / Move MENU** path only (mouse over the menu → stays deferred). The key handlers
were gated on the Tcl var **`infix_interface`** (`set_ne infix_interface 1` in xschem.tcl:14509 —
default 1, but the user's session is 0). With infix=1 the key started immediately; with infix=0 it
only ARMED MENUSTARTCOPY → deferred → "press C, nothing follows until you click". A GUI smoke run
without forcing infix=0 will FALSELY pass — **always `set ::infix_interface 0` in copy/move smokes.**

### DONE (noun-verb) — verified 7/7 GUI smoke with infix forced 0
`callback.c` case 'c'/'m' (the plain `rstate==0` branch) now: `rebuild_selected_array(); if(lastsel>0)
{ mx/my_double_save=mousex/y_snap; copy_objects(START) / move_objects(START); } else { statusmsg(
"…select object(s) first, then press the copy/move key"); }` — IMMEDIATE start regardless of
infix_interface; the MotionNotify handler (`callback.c:3822` `if(STARTCOPY) copy_objects(RUBBER)`)
makes the ghost follow; the drop is completed on the next button-PRESS ("complete pending STARTCOPY",
`callback.c:~5524`). Empty case = prompt only (no MENUSTART arm), so a click does NORMAL selection
and the user then presses C/M. scheduler.c copy/move commands were reverted to the original MENUSTART
arming (comment-only diff) — the MENU stays deferred.

### UNSOLVED (true verb-noun) — the bug to crack if the user wants it
Desired: C with nothing selected → click a pin → it gets selected AND the copy starts in one gesture.
Implemented (then REVERTED to prompt-only): empty C/M armed MENUSTART|MENUSTARTCOPY + prompt, and
`check_menu_start_commands` (callback.c ~2076 MENUSTARTMOVE / ~2084 MENUSTARTCOPY) did
`select_object(mousex,mousey,SELECTED,0,NULL)` when `lastsel==0` before `copy_objects(START)`.
Arming worked and STARTCOPY got set after the click-on-pin (verified). **But the click-STARTED copy
fails to COMPLETE on drop:** `copy_objects(END)` sees `deltax==0` → "released without moving" →
clears STARTCOPY, makes NO copy. Diagnosed: `mousex_snap` DOES update on motion (80, 120),
`semaphore==0`, STARTCOPY stays set through the motion — yet the motion's `copy_objects(RUBBER)`
delta never reaches END. The key-STARTED (noun-verb) path computes delta fine; only the
check_menu_start_commands-STARTED path loses it. Priming with `copy_objects(RUBBER)` right after
START did NOT fix it. Move's verb-noun *seemed* to work but the test was weak (move doesn't change
the pin count, so "1 pin" is trivially true). To debug: there is **no `xschem get deltax`/`x1`/`x2`**
getter — add one (scheduler.c `xschem get`) to see x1/x2/deltax after each event; suspect x1 or x2
init differs, or a `draw()`/state reset between the click-START and the motion. Files: `copy_objects`
START `move.c:648`, RUBBER `move.c:682`, END `move.c:703`; `handle_button_release` STARTCOPY+
drag_elements `callback.c:~5936`.

## How to test (this WSLg env)
- Headless (reliable): `cd tests && ../src/xschem --nogui --pipe -q --script pin_name_text.tcl` → 73/73.
- GUI smokes: `DISPLAY=:0` is available; run `DISPLAY=:0 src/xschem --pipe -q --script <file>` (NO
  `--nogui`, so Tk loads — `xschem callback` segfaults under `--nogui`). Pattern: `set ::infix_interface 0`;
  `xschem clear force symbol`; `xschem add_symbol_pin 0 0 AA in 0`; `xschem zoom_full; update idletasks`;
  screen coords `int((u + [xschem get xorigin]) / [xschem get zoom])`; events `xschem callback .drw
  <type> <sx> <sy> <keysym> <button> 0 <state>` with type motion=6 / press=4 / release=5 / key=2,
  keysym 'c'=99 'm'=109; state masks STARTCOPY=64, STARTMOVE=32, MENUSTART=65536, SELECTION=8.
- WSLg flakiness: the `property_form` GUI suite and `tests/headless/test_gesture_end_log.tcl` are
  flaky after many GUI launches (0-byte logs, timeouts; test_gesture_end_log fails at line 108
  `instance not found` — confirmed IDENTICAL on the committed baseline via `git stash`, so it's
  ENV, not the change). Use small targeted smokes; one clean property_form run = 39/39 graphical (RL).

## Next actions
1. **User GUI eyeball** (rebuild): select a pin, press **C** → copy follows the cursor at once → click
   drops; **M** same; empty **C** → status-bar prompt. (Headless can't see the ghost; this is the gate.)
2. If it feels right → **commit P4 + the copy/move-key fix** (both uncommitted on `d1f1d53a`).
3. Optional: crack the true verb-noun deltax-on-drop bug (above).
4. Then the remaining planned phases (spec §8): **P5** global show/hide tri-state `show_pin_names`
   (wins over per-pin), **P6** instance draw-from-tokens (until then placed instances show no pin
   names — expected), **P7** ERC/check + docs, **P8** Python migration `tools/migrate/`, **P9** the
   original goal: wire-stubs + auto net-labels (`doc/claude/specs/wire_stub_netlabel.md`).

## Quick file index (copy/move keys)
| What | Where |
|---|---|
| C key handler (immediate noun-verb / prompt) | `callback.c` `case 'c'` ~4059 |
| M key handler | `callback.c` `case 'm'` ~4376 |
| Click-after-arm dispatch (verb-noun would live here) | `callback.c` `check_menu_start_commands` ~2076/~2084 |
| Motion → ghost follow (`if STARTCOPY copy_objects(RUBBER)`) + `semaphore>=2` early-return | `callback.c` 3822 / 3779 |
| Drop completes copy on button PRESS | `callback.c` ~5524 ("complete pending STARTCOPY") |
| copy_objects START/RUBBER/END | `move.c` 648 / 682 / 703 |
| MENU commands (deferred; NOT the keys) | `scheduler.c` `copy_objects` ~1021, `move_objects` ~4467 |
| infix_interface default | `xschem.tcl:14509` `set_ne infix_interface 1` |
