# Issue 0006 — legacy property dialogs clip their action buttons (no `wm minsize` floor)

**Opened:** 2026-06-14
**Status:** RESOLVED (2026-06-14) — minsize floor implemented on the three
affected legacy dialogs (`enter_text`, `text_line`, `edit_prop_legacy`) via a
shared `dialog_minsize_floor` helper; the stretch dialogs were inspected and
found unaffected (position-only geometry, naturally sized). Fix committed in
`87791b4b`; **follow-up `dialog_minsize_floor` gridded-window fix** for
`text_line`/`edit_prop_legacy` — see §8.1. See §8 for the resolution record.
**Affects:** the legacy Tk property/edit dialogs (`enter_text`, `text_line`,
`edit_prop_legacy`, …) — usability when the window opens (or is remembered) too
short. NOT the slick property form (`slickprop::edit_form`), which sizes to
content and is unaffected.
**Severity:** low (cosmetic/usability; workaround = maximize the window). No data
loss, no regression — pre-existing legacy code.
**Branch:** suggest a small dedicated branch off `master`,
e.g. `fix/legacy-dialog-minsize` (this is a legacy-dialog bugfix, independent of
the slick-form feature work on `slick-property-forms`). Continuing on
`slick-property-forms` is also fine.
**Related:** the slick-property-forms work (the modern replacement for the
*instance* dialog) explicitly deferred the other property dialogs (`enter_text`
for text, `text_line` for rect/line/poly/wire/arc) to "v2" — see
`doc/claude/specs/multi_instance_property_editing.md` and the
[[slick-property-forms]] memory. This issue is one of those deferred dialogs
biting a user.

---

## 1. The symptom (reported)

Select a **text object**, press **`q`** → the **"Enter text"** dialog opens, and
its bottom button row — **OK / Cancel / Load / Del** — is **not visible**. You
have to **maximize** the dialog to reveal the buttons.

This is the legacy `enter_text` dialog (`xschem.tcl:6602`), reached for text
objects via `editprop.c:681` (`tcleval("enter_text {text:} normal")`) — *not* the
slick form (that only handles instances).

---

## 2. Root cause (verified on `enter_text`, confirmed identical in `text_line`)

Three things combine:

1. **The window's height is forced to a *remembered* value.** `enter_text` keeps a
   global `enter_text_default_geometry` (init `{}`, `xschem.tcl:11636`), saves the
   current size into it on **every** `<Configure>` event
   (`xschem.tcl:6613–6616`, stripping the `+x+y` position), and re-applies it with
   `wm geometry .dialog "${enter_text_default_geometry}+$X+$Y"`
   (`xschem.tcl:6620`). Once a too-short size is captured (a stray resize, a WM
   placement, or an intermediate size grabbed mid-map under the `wm_fix`
   `tkwait visibility` path at `:6619`), that short height sticks across opens.
2. **The content area expands; the buttons don't.** The big text widget is packed
   `-side top -fill both -expand yes` (`xschem.tcl:6632`); the button row is packed
   **last and at the bottom**, `pack .dialog.buttons -side bottom -fill x`
   (`xschem.tcl:6701`).
3. **There is no `wm minsize`.** Grep confirms **zero** `wm minsize` calls in
   `xschem.tcl`. So nothing stops the toplevel from being shorter than its own
   controls require.

When the toplevel is shorter than the sum of required heights, Tk gives the
expanding text widget its space and **clips the last-packed bottom row** — exactly
the OK/Cancel/Load/Del row. Maximizing supplies enough height, so they reappear.

**`text_line` (`xschem.tcl:7700`) has the identical pattern** — its own
`text_line_default_geometry` saved on `<Configure>` and forced via `wm geometry`,
`wm_fix` `tkwait`, and **no `wm minsize`** (`xschem.tcl:7731–7750`). So it shares
the bug. `edit_prop_legacy` (`:7379`) and `edit_vi_prop` (`:7247`) should be
checked for the same shape.

---

## 3. Scope of this session (option (b))

**In scope — add a minimum-size floor to the legacy modal property/edit dialogs**
so their action buttons can never be clipped:

| Dialog | Proc / `toplevel` | Used for |
| --- | --- | --- |
| `enter_text` | `xschem.tcl:6602` / `:6606` | editing **text objects** (the reported case) |
| `text_line` | `xschem.tcl:7700` / `:7733` | rect/line/poly/wire/arc + global schematic props |
| `edit_prop_legacy` | `xschem.tcl:7379` / `:7390` | the legacy instance dialog (slick-form rollback) — verify/fix |
| `edit_vi_prop` | `xschem.tcl:7247` | vim-editor launcher — verify (may have no packed buttons to clip) |

**Stretch (same root cause, same one-line fix) — the rest of the
`toplevel .dialog` modal family**, if cheap: `property_search` (`:6988`),
`attach_labels_to_inst` (`:7124`), `ask_save` (`:7192`), `input_line` (`:8666`).
Apply the floor wherever a button row can be squeezed; skip any that are already
naturally sized or non-resizable.

**Out of scope (do NOT touch):**
- `slickprop::edit_form` (`src/property_form.tcl`) — the modern instance form; it
  already does a size-to-content pass and is not affected. Leave it alone.
- Any *behavioral* change to these dialogs (button commands, contents, the
  remembered-geometry feature itself). This is purely a **minimum-size floor**.
- The `viewdata` viewer (`:8205`) and other non-edit windows unless they exhibit
  the clip too.

---

## 4. The fix

After all widgets are packed (so the natural requested size is known), but before
`tkwait window .dialog`, set the floor to the natural required size:

```tcl
update idletasks
wm minsize .dialog [winfo reqwidth .dialog] [winfo reqheight .dialog]
```

Place it right after the final `pack .dialog.buttons …` (e.g. after
`xschem.tcl:6701` in `enter_text`, after the corresponding line in `text_line`,
etc.), ahead of the existing `tkwait window .dialog`.

**Also clamp the remembered geometry so a stale short value can't reopen too
short** (belt-and-suspenders, since these dialogs *force* a saved size): when
re-applying `..._default_geometry`, don't let it be shorter than the required
height. Simplest: set `wm minsize` *before* the `wm geometry "${...}+$X+$Y"` line
so the forced geometry is floored by the WM; or, if `update idletasks` isn't
viable that early (widgets not yet packed at the current `wm geometry` site —
`:6620` runs before packing), keep the forced-geometry line as-is and rely on the
post-pack `wm minsize` above (the WM enlarges the window to the minsize after the
content is packed). **Prefer the post-pack `wm minsize`** — it needs no
reordering and fixes both fresh and remembered-too-short opens.

> Optional polish (note, don't necessarily do): factor the floor into a tiny
> helper, e.g. `proc dialog_minsize_floor {w}` in a shared spot, and call it from
> each dialog — one definition, several call sites, easy to extend later.

---

## 5. Verification (mostly eyeball — Tk geometry isn't headlessly assertable)

This is a layout fix; correctness is visual. Verify **per dialog** on a real
display (the `slick-property-forms` suite does NOT cover these legacy dialogs):

- **`enter_text`**: select a text object, press `q` → **OK/Cancel/Load/Del are
  visible without maximizing**, at the default size. Resize smaller — the WM
  should refuse to shrink past the buttons (the minsize floor).
- **`text_line`**: select a rectangle (or wire/line/poly/arc), press `q` → its
  button row is visible at open and the window won't shrink below it.
- **`edit_prop_legacy`**: temporarily route to it (or set the rollback path) and
  confirm the same.
- Reopen each a few times (the remembered-geometry path) — buttons stay visible;
  no "first open fine, later opens clipped" regression.

A *light* headless smoke is possible but low-value (build the dialog withdrawn,
assert `[lindex [wm minsize .dialog] 1] >= [winfo reqheight .dialog]`), and these
modal dialogs are WSLg-flaky to drive — treat any such test as a smoke, not the
gate. **The real gate is the eyeball pass above.**

**Hard-won env rules (carried from prior sessions):** run from `src/`
(`cd …/src && ./xschem`); standalone GUI scripts are WSLg-flaky (drive the real
GUI by hand for this); a Bash `cd` drift gives `./xschem` → exit 127 (always
`cd …/src &&` per command).

---

## 6. Acceptance criteria

- Pressing `q` on a **text object** shows the "Enter text" dialog with **all four
  buttons visible without maximizing**, at the default and any remembered size.
- The same holds for `text_line` and `edit_prop_legacy` (and any stretch dialogs
  touched): a `wm minsize` floor prevents the action row from ever being clipped.
- No behavioral change to any dialog beyond the size floor; the slick form
  (`edit_form`) is untouched.
- A short eyeball-verification note is recorded (this issue → RESOLVED with which
  dialogs were floored).

---

## 7. Why this was deferred (context, not blame)

These are the *legacy* property dialogs the slick-form project consciously left
for "v2." The slick form replaced only the instance dialog and added its own
size-to-content logic, so it never had this bug; the older dialogs predate that
and were never given a minimum-size floor. This issue closes the gap for the ones
users still reach (text objects, graphical objects, global props) with the
smallest possible change.

---

## 8. Resolution record (2026-06-14)

Implemented the post-pack `wm minsize` floor exactly as sketched in §4, factored
into the optional shared helper:

```tcl
proc dialog_minsize_floor {w} {
  update idletasks
  wm minsize $w [winfo reqwidth $w] [winfo reqheight $w]
}
```

defined in `src/xschem.tcl` just above `enter_text`, and called immediately before
the modal `tkwait window .dialog` (after all widgets are packed) in:

| Dialog | Call site | Status |
| --- | --- | --- |
| `enter_text` | before `tkwait window .dialog` (~`:6722`) | **floored** |
| `text_line` | before `tkwait window .dialog` (~`:7953`) | **floored** |
| `edit_prop_legacy` | before `tkwait window .dialog` (~`:7626`) | **floored** |
| `edit_vi_prop` | n/a | **not applicable** — launches an external `$editor`, no Tk toplevel / no packed buttons to clip |

**Stretch dialogs inspected, NOT floored** (none exhibit the bug): `property_search`
(`:6998`), `attach_labels_to_inst` (`:7134`), `ask_save` (`:7202`), `input_line`
(`:8678`). Each forces only *position* (`wm geometry .dialog "+$X+$Y"`), keeps no
remembered size, and has no vertically-expanding content widget competing with the
button row — so the WM never makes them shorter than their controls. Adding a floor
would be inert; left untouched to keep the change minimal.

`info complete` confirms `xschem.tcl` still parses cleanly after the edits. The
change is Tcl-only (no C touched); the slick form (`slickprop::edit_form`) is
untouched.

**Eyeball gate (2026-06-14):** verified `enter_text` (non-gridded) shows the
OK/Cancel/Load/Del row and won't shrink past it. The gridded dialogs were *not*
fully exercised at the time — see §8.1.

---

## 8.1 Follow-up — gridded-window regression in `dialog_minsize_floor` (2026-06-14)

**Reported:** selecting the big dashed rectangle in
`xschem_library/examples/mos_power_ampli.sch` and pressing `q` opens the
**Text input** dialog (`text_line`) which jumps around and clips its buttons —
worse than before the fix.

**Cause:** `text_line` and `edit_prop_legacy` build their text widget with
`-setgrid 1` (`:7766`, `:7424`), which makes the **toplevel gridded**. For a
gridded window `wm minsize` is specified in **grid units (characters), not
pixels**. The original `dialog_minsize_floor` fed it `winfo reqwidth/reqheight`
(pixels — e.g. 739×717), so the WM read it as a **739×717-character** minimum
≈ thousands of pixels in each dimension. The toplevel ballooned far past the
screen and the WM repositioned it on every open → the "random position + buttons
off-screen unless maximized" symptom. `enter_text` was unaffected because it is
**not** gridded (no `-setgrid`).

**Fix:** make `dialog_minsize_floor` grid-aware. `wm grid $w` returns
`{baseWidth baseHeight widthInc heightInc}` for a gridded toplevel (`{}` when not
gridded); the natural requested size **is** the grid base, so use `baseWidth
baseHeight` as the minsize for gridded windows and pixel `reqwidth/reqheight`
otherwise.

```tcl
proc dialog_minsize_floor {w} {
  update idletasks
  set grid [wm grid $w]
  if {[llength $grid] == 4} {
    wm minsize $w [lindex $grid 0] [lindex $grid 1]
  } else {
    wm minsize $w [winfo reqwidth $w] [winfo reqheight $w]
  }
}
```

**Verified (standalone Tk repro of `text_line`'s exact widget tree + packing):**
with a deliberately catastrophic stale geometry (`90x2`, 2 rows forced at open)
the grid-aware floor restores the window to its natural `90x40` grid = 741×755 px
(screen is 1440 tall) and the OK button row lands inside the window
(bottom-edge 181 ≪ window bottom 882). The previous code set `wm minsize 739 717`
*grid cells* (~12 000 px tall) — the smoking gun. `enter_text`'s non-gridded path
is unchanged (`wm grid` → `{}` → pixel branch).

**Remaining gate:** eyeball in the real app — open `text_line` (select a
rect/wire/line/poly/arc, `q`) and `edit_prop_legacy`: the dialog opens at a sane
size at the pointer, buttons visible, no ballooning/jumping, and won't shrink
past the buttons. (The dialog still opens at the mouse pointer each time — that's
existing intended behavior, not the regression.)
