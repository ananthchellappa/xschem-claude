# 0245 — while a placement form is open, canvas Escape never reaches the C Escape terminal: an idle form swallows it and aborts nothing

Status: **OPEN** — measured (the *downstream* half; the Tk delivery half is proven by code +
documented Tk semantics, see *What cannot be shown headlessly*). Fix drafted, not implemented.
**Major**, not critical: a second Escape always recovers — but nothing tells the user to press it,
because the form visibly closed.
Area: `src/xschem.tcl:11370` (`addlabel::grab_esc`), `:11028` (`addpin::`),
`src/create_instance.tcl:151` (`ciform::`, no guard at all) vs `src/callback.c:7344-7359`
(`case XK_Escape`)
Tests: `test_cmdmode_descend_0201.tcl` legs CS3a–CS3c pin the exact `.drw <Key-Escape>` script text
Found: 2026-08-06, verifying issue **0240**'s out-of-scope list
Related: **0240** — its "Still open" item 3 called this *"harmless now"*; **this issue supersedes
that verdict**. **0122** item 3 / E2 (Esc dismisses an idle form; the `release_esc` handoff),
`doc/claude/specs/cadence_pin_name_text.md:549-551` (**states the opposite of what the code does**
— see *History*), **0202** D3 (same, see *Landmines*).

## The gesture

1. `l` → Add Wire Label opens. Leave the name empty, or place one label and let the queue drain
   (status: *"all labels placed — type more names, or Esc/Close to finish"*, `xschem.tcl:11313`).
   **No preview is armed; the form stays open.**
2. **Tools ▸ Insert wire** (or the right-click ctx-menu button, `xschem.tcl:12668`).
3. Press **Esc over the canvas**. The form closes — so Esc *looks* like it worked.
4. Click anywhere on the canvas → **a wire starts**, unrequested.

Variant: step 2 = select a wire and press `m`. The move is not aborted; the click at step 4 commits
it at the cursor.

## Measured

Headless, calling the **real** grabbed proc (not a transliteration):

```
  menu wire armed    ui=65536  ui2=1   lc=0     <- MENUSTART | MENUSTARTWIRE
  addlabel::placing = 0
  -- .drw <Key-Escape> -> addlabel::escape --
  after form ESC     ui=65536  ui2=1   lc=0     <- BUG: byte-identical, nothing aborted
  -- now what callback.c:7348 would have run --
  after C ESC        ui=0      ui2=1   lc=0     <- MENUSTART cleared
```

| scenario (form idle) | armed | after form ESC | after C ESC |
|---|---|---|---|
| A menu wire (`xschem wire`) | `ui=65536 ui2=1 lc=0 tclstop=0` | **unchanged** | `ui=0`, `tclstop=1` |
| B keyboard move (`move_objects start`) | `ui=40` | **`ui=40`, STARTMOVE still set** | `ui=8` (aborted) |
| C live wire draw (`wire gui`) | `ui=1 lc=1` | **`ui=1 lc=1`** | `ui=0 lc=1` |
| D preview + `w` on top (`cadence_compat`, `persistent_command`) | `ui=16425 lc=1` | `ui=0`, **`lc=1`** | `ui=0 lc=1` **+ C clears `STARTWIRE` from `lc`** |

## Root cause — two independent links

**(1) Delivery.** `xinit.c:3649` installs the generic dispatcher on the bindtag **`.drw`**
(`xschem.tcl:14164`, `bind $topwin <KeyPress> "… xschem callback …"`). The forms grab the *same*
tag:

- `xschem.tcl:11370` — `proc addlabel::grab_esc {} { bind .drw <Key-Escape> {if {[winfo exists .addlabel]} {addlabel::escape; break}} }`
- `xschem.tcl:11028` — identical for `addpin`
- `create_instance.tcl:151` — `bind .drw <Key-Escape> {ciform::escape; break}`, **no guard**

Tk runs exactly one binding per bindtag, the most specific match. `<Key-Escape>` carries a detail
and `<KeyPress>` does not, so `<Key-Escape>` wins **regardless of `break`** — `break` only
suppresses the later tags (`Frame`, `.`, `all`, all empty here). `.drw` has default bindtags. So
`callback.c:7344 case XK_Escape:` is unreachable while any of the three forms is open.

**(2) The form terminal is a strict subset.** `addlabel::escape` (`xschem.tcl:11376-11381`) is
`set armed 0; addlabel::abort_if_placing; catch {destroy .addlabel}`, and `abort_if_placing`
(`:11228`) calls `xschem abort_operation` **only** when `ui_state & 16384` (`START_SYMPIN`). With
the form idle, nothing runs at all — and these four siblings never run in any case:

```c
case XK_Escape:                                       /* abort & redraw */
  if(xctx->semaphore < 2) { abort_operation(tclgetboolvar("escape_deselects")); }   /* :7348 */
  tclsetvar("tclstop", "1"); /* stop simulation if any running */                   /* :7351 */
  if(xctx->ui_state2 & MENUSTARTWIRE) { xctx->ui_state2 &= ~MENUSTARTWIRE; }        /* :7352 */
  if(snap_cursor) draw_snap_cursor(1); /* erase */                                  /* :7355 */
  if(tclgetboolvar("persistent_command") && (xctx->last_command & STARTWIRE) && cadence_compat) {
    xctx->last_command &= ~STARTWIRE;                                               /* :7357 */
  }
```

What each skip costs:

- **`:7348`** — the whole teardown. With `MENUSTART` surviving, the next Button-1 press reaches
  `callback.c:7845 check_menu_start_commands()` → `:3733` → `start_wire()`. That is the unrequested
  wire at step 4. With `STARTMOVE` surviving, the same press commits the move.
- **`:7351`** — `tclstop` is the only break-out of the logic-propagation loop (`hilight.c:2301-2302`,
  comment: *"get out from infinite loops (circuit is oscillating)"*). With a form open, Esc cannot
  break it.
- **`:7352`** — leaves `MENUSTARTWIRE` in `ui_state2` even on paths where `abort_operation` *does*
  run (measured `ui2=1` after the C terminal too). Inert today because every arming site **assigns**
  `ui_state2` wholesale (`scheduler.c:13015`, `:13020`); hygiene, same status 0240 gives
  `MENUSTARTDESCEND` at `callback.c:330`.
- **`:7355`** — the snap cursor is never erased.
- **`:7357`** — the cadence one-stage-Esc fixup. **This one has teeth after 0240**: `abort_operation`
  now latches `keep_last_command = 1` (`callback.c:376`) whenever a placement is co-armed, so
  `last_command` stays `STARTWIRE` (measured, row D), and `callback.c:7828` then starts a wire on
  the next press. Without the form, `:7357` would have cleared it.

Also skipped: the `semaphore < 2` re-entrancy guard (`:7345`). The Tcl path has none, so with a
modal dialog up a form Esc runs `abort_operation` re-entrantly.

## History — the invariant was written down, implemented as a no-op, then removed

- `93a54f76` (P3.7 F2) deliberately wrote
  `bind .drw <Key-Escape> {if {[addpin::placing]} {addpin::escape; break}}` with the comment *"when
  nothing is being placed, fall through so Esc still cancels an unrelated in-progress gesture
  (wire/move/…) the user may have started while this form is open"*, and
  `doc/claude/specs/cadence_pin_name_text.md:549-551` records it as done. **That fall-through never
  existed** — same bindtag, `<Key-Escape>` still pre-empts `<KeyPress>`; guarding the script *body*
  only made it a no-op. The spec statement is false as written and should be corrected.
- `1acb602f` (issue 0122 item 3) then replaced the guard with `{if {[winfo exists .addpin]} …}` to
  make Esc dismiss an idle form, removing even the intent.

So the defect predates 0122 by one commit and has never worked since the forms were introduced.

## Fix sketch

**The form's Escape handler must call the same terminal the C case uses.** "Narrow the grab" cannot
work — `<Key-Escape>` beats `<KeyPress>` on the shared tag whatever the script body says (that is
exactly what `93a54f76` tried), and dropping `break` does not help either.

1. Extract `callback.c:7344-7359` into `void escape_terminal(void)` (semaphore guard included);
   `case XK_Escape:` becomes a one-line call. Expose it as a scheduler verb **`xschem escape`** (the
   name is free). That also gives the headless suite the seam it currently lacks — this
   investigation had to *transliterate* the case body because there is no way to execute it from
   Tcl.
2. `addlabel::escape` / `addpin::escape` / `ciform::escape`: drop `abort_if_placing`, end with an
   unconditional `catch {xschem escape}` **after** `destroy` (so the form's own bookkeeping is torn
   down first). This satisfies both prior requirements at once — 0122 item 3 (*Esc dismisses an idle
   form*) and cadence P3.7 F2 (*Esc still cancels an unrelated gesture*) — which were never in
   conflict; the code implemented "always swallow" instead of "always handle, then forward".
3. Keep `abort_if_placing` on the **non-Esc** close routes (`on_destroy` from Close / WM close):
   closing a form with the X button should tear down its preview, not stop a simulation.
4. `create_instance.tcl:151` additionally needs the `winfo exists .ciform` guard and a `release_esc`
   that hands the slot back to a live addpin/addlabel form instead of `bind .drw <Key-Escape> {}`
   (`:247`) — otherwise ciform silently re-creates the 0122-E2 clobber against the fixed forms.
5. Optionally the same call in ASE's seized Escape (`ase_window.tcl:1602` → `sod_end`), identical
   shape, likewise never reaches C. Separate decision.

**Explicitly NOT the fix:** hoisting the four siblings into `abort_operation()`. It has 24 C call
sites plus 8 Tcl ones — a context-menu abort or a `.load` dialog Cancel must not set `tclstop=1` or
clear `last_command & STARTWIRE`.

## Landmines

- **`test_cmdmode_descend_0201.tcl` legs CS3a–CS3c** assert the three seized `.drw` slots are handed
  back **string-identically, trailing `break` included** (`:132-135`). They capture the predecessor
  at runtime so a changed `grab_esc` body should pass — but this is the one suite that pins the
  exact script text.
- **`escape_deselects = 1` users** get a behaviour change: Esc-to-close an idle form will now
  deselect, because `abort_operation()` reaches `:418 if(deselect) unselect_all(1);` when nothing is
  pending. Default is 0 (`xschem.tcl:15731`), so most users see only an extra `draw()`.
- **`tclstop = 1` on every form Esc** will break a running `propagate_logic` that happens to be up
  while a form is open. Correct by definition, but a real change.
- **0122 E1's `sympin_drops` witness and the `::sympin_place` latch** (issue **0246**) sit on the
  same teardown path; ordering `destroy` before `xschem escape` must not let `after_drop` mistake
  the terminal's `delete()` for a real drop.
- **0202 D3 currently asserts the opposite of this finding** — *"neither is displaced by Tk-level
  seizes — the `break` is what keeps them apart"* (`doc/claude/issues/0202-…md:86-88`). Correct that
  sentence when this lands.
- **Sibling-form amplification:** with both forms open, `release_esc` (`xschem.tcl:11029`, `:11371`)
  hands the slot to the survivor, so it takes **three** Escapes before one reaches C.

## What cannot be shown headlessly

Under `--nogui` there is no Tk and no `.drw`, so the **delivery** half — that `<Key-Escape>` on
`.drw` wins over `<KeyPress>` on `.drw`, hence the C case is never entered — rests on the code above
plus documented Tk semantics, not on measurement (`xschem callback .drw …` segfaults with no mapped
window, so the keypress cannot be injected). Everything **downstream** of "which Tcl proc runs" is
measured by invoking the real `addlabel::escape`, which does load under `--nogui`.

GUI-manual checks the fix should carry: (a) Esc while the form is open clears the statusbar
`DRAW WIRE!` (`callback.c:8503`, fed by `wire_draw_active` at `:8650`, which counts the surviving
`MENUSTART|MENUSTARTWIRE` — today it keeps reading `DRAW WIRE!`, the only hint the user gets);
(b) the click at repro step 4 no longer draws a wire; (c) the snap cursor is erased.
