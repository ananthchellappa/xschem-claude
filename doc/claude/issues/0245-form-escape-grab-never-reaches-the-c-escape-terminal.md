# 0245 — while a placement form is open, canvas Escape never reaches the C Escape terminal: an idle form swallows it and aborts nothing

Status: **FIXED** 2026-08-11 — see *RESOLUTION* at the end of this file. The item ships as
**status E**: it carries an unratified user-visible change (form Escape now sets `tclstop`).
Both halves are now **measured** under xvfb, including the Tk delivery half this file called
unmeasurable — and the measurement showed the analysis below is scoped one window too narrow
(Tk routes keys to `[focus]`, so the form's OWN `<Key-Escape>`, not the `.drw` slot, is what
fires while the form has focus). See *What the issue got right, and the one thing it got wrong*.

Status (original): **OPEN** — measured (the *downstream* half; the Tk delivery half is proven by
code + documented Tk semantics, see *What cannot be shown headlessly*). Fix drafted, not implemented.
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

---

# RESOLUTION — FIXED 2026-08-11 (driver run 2026-08-09, item D7)

Status: **FIXED**, and the item ships as **status E**: it carries a user-visible change that no
prior rung ratifies. The question a human must answer is at the bottom of this section.

## What the issue got right, and the one thing it got wrong

Every claim in the analysis above is corroborated, and the half declared unmeasurable in
*"What cannot be shown headlessly"* is now **measured** under xvfb (`GUI_GATE=0 xvfb-run -a`, which
is not the user's display and so is not gated).

The one thing it got wrong is its *scope*, and it cost this item a refuted first attempt. The issue
— and the fix built from it — assumed the swallow lives at the three `.drw <Key-Escape>` grabs.
It does not live only there. **Tk routes a key event to `[focus]`, not to the window named in the
binding**, and every placement form ends `open()` by focusing its first entry. So from the moment a
form appears until the user next *clicks the canvas*, the binding that fires is the form's **own**
toplevel `<Key-Escape>` — the `.drw` slot never runs at all. Fixing only the `.drw` slot left the
defect fully live on the plainest sequence there is:

> arm a wire, open Add-Wire-Label from the menu, press Escape.

Measured (xvfb, first attempt installed, `.drw` slot fixed, form binding still `{addlabel::escape}`):

```
A1 focus after open          = .addlabel.f.ename
A2 armed                     ui=65536 ui2=1
A3 ESC (focus still in form) ui=65536 ui2=1 form=0      <- BYTE-IDENTICAL: swallowed anyway
C2 focus after canvas click  = .drw                      <- only a click restores the fixed path
D1 armed before form         ui=65536 ui2=1
D2 after addlabel::open      ui=65536 ui2=1 focus=.addlabel.f.ename   <- the arm SURVIVES form open
```

`D2` is what makes the sequence trivial to reach: opening a form on top of an armed wire keeps the
arm *and* takes focus. The final fix therefore forwards from **both** Escape routes.

## BEFORE (Measure agent, verbatim)

Scout repro under xvfb, `RESULT: 8 FAILED / 6 passed` / `OVERALL: notok`:

```
FAIL: K1d ESC ALSO aborted the wire arm -> {65536} (exp {0}) : FAIL
FAIL: K1e ESC cleared MENUSTARTWIRE -> {1} (exp {0}) : FAIL
FAIL: K2a addpin ESC aborted the arm -> {65536} (exp {0}) : FAIL
FAIL: K2b addpin ESC cleared ui_state2 -> {1} (exp {0}) : FAIL
FAIL: K3a ciform ESC aborted the arm -> {65536} (exp {0}) : FAIL
FAIL: K3b ciform ESC cleared ui_state2 -> {1} (exp {0}) : FAIL
FAIL: K4 one ESC with BOTH forms open -> {65536} (exp {0}) : FAIL
FAIL: K5 label form still owns canvas ESC -> {0} (exp {1}) : FAIL
```

The damage, step by step (`infix_interface 0`):

```
C2 ESC                                       ui=0      ui2=0   lc=0
C3 click after ESC (must be a no-op)         ui=0      ui2=0   lc=0
D1 armed under idle form                     ui=65536  ui2=1   lc=0
D2 ESC (form closes, nothing else)           ui=65536  ui2=1   lc=0
D3 click after ESC -> UNREQUESTED WIRE DRAW  ui=65537  ui2=1   lc=1
D4 second ESC finally aborts                 ui=0      ui2=0   lc=1
```

Sibling amplification (three Escapes), and `abort_operation` alone never clearing `MENUSTARTWIRE`:

```
 9 ESC #1                                    ui=65536  ui2=1   lc=0   addlabel=0 addpin=1
10 ESC #2                                    ui=65536  ui2=1   lc=0   addlabel=0 addpin=0
11 ESC #3                                    ui=0      ui2=0   lc=0   addlabel=0 addpin=0
17 after xschem abort_operation              ui=0 ui2=1
```

## AFTER

Same repro, same command:

```
ok:   K4 one ESC with BOTH forms open
ok:   K5 label form still owns canvas ESC
RESULT: ALL PASS (14 checks)
OVERALL: ok
```

Both Escape routes, all three forms (xvfb, focus left where `open()` put it — **no** `focus -force`):

```
LABEL  focus=.addlabel.f.ename   armed=65536/1  after-ESC ui=0 ui2=0  gone=1
PIN    focus=.addpin.f.ename     armed=65536/1  after-ESC ui=0 ui2=0  gone=1
CI     focus=.ciform.f.elib      armed=65536/1  after-ESC ui=0 ui2=0  gone=1
```

## What changed

1. **`src/callback.c`** — the sixteen lines of `case XK_Escape:` lifted **verbatim** into
   `void escape_terminal(void)`: `abort_operation(tclgetboolvar("escape_deselects"))` behind the
   `semaphore < 2` re-entrancy guard, then the four reentrant siblings (`tclstop=1`, the
   `MENUSTARTWIRE` clear, the snap-cursor erase, the cadence `persistent_command`/`last_command`
   fixup). It sits after the `draw_snap_cursor()` forward declaration — next to `abort_operation()`
   it does not compile. `snap_cursor`/`cadence_compat` were `handle_key_press()` parameters; the
   helper re-reads them with the same `tclgetboolvar()` calls `callback()` made microseconds
   earlier. `case XK_Escape:` is now `escape_terminal(); break;`.
2. **`src/xschem.h`** — `extern void escape_terminal(void);` beside `abort_operation`.
3. **`src/scheduler.c`** — new verb `xschem escape`, inserted immediately before `escape_chars`.
   No argument. Not a `perform_action` verb, so it mints no action-log line of its own.
4. **`src/xschem.tcl` / `src/create_instance.tcl`** — a new `X::canvas_escape` per form
   (`X::escape` then `catch {xschem escape}`), wired to **both** Escape routes:
   - the shared `.drw` slot, whose script is now **total** —
     `{if {[winfo exists .X]} {X::canvas_escape} else {xschem escape}; break}` — so a grab that
     outlives its form (`clone_canvas_bindings`, 0122-F3) can no longer swallow Escape;
   - the form's **own** `bind $w <Key-Escape>`, which is the one Tk actually fires while the form
     holds focus. This is the correction described above.
   The **Close BUTTON** keeps plain `X::escape` — a mouse click on Close is not the Escape key.
5. **`canvas_esc_release {self}`** — one shared owner-handoff walking
   `{.addlabel .addpin .ciform}` with an explicit exclude-self (inside a `<Destroy>` handler
   `winfo exists` for the dying toplevel is not dependable), replacing three pairwise release procs
   **and** `ciform::on_destroy`'s blanket `bind .drw <Key-Escape> {}` — the live 0122-E2 clobber
   this issue measured as K5.

Not hoisted into `abort_operation()`, exactly as the issue's *"Explicitly NOT the fix"* demands:
24 C call sites in `callback.c` alone plus 9 more in C and 10 in Tcl, and a `.load` dialog Cancel
must never set `tclstop` or drop the resting wire command.

## Decisions (ladder rung, and the rejected alternative)

- **R1 — extract + expose, do not hoist into `abort_operation()`.** The issue's own ruling, backed
  by the call-site census. *Rejected:* folding `tclstop`/`MENUSTARTWIRE`/snap-cursor/`last_command`
  into `abort_operation()`, which would make a `.load` Cancel or any context-menu abort stop a
  running simulation.
- **R2 — `xschem escape` takes NO argument** and reads `escape_deselects` itself. *Rejected:*
  mirroring `xschem abort_operation [deselect]`. No-arg `abort_operation` is `deselect=1` while
  C Escape is `escape_deselects` (default 0) — an optional argument would reproduce that trap for
  the next caller, and nothing wants Escape-but-with-a-different-deselect.
- **R2 — the forward lives at a new `X::canvas_escape`, not inside `X::escape`.** *Rejected:* the
  issue's own sketch item 2 (*"end `X::escape` with an unconditional `catch {xschem escape}`"*),
  which would make clicking **Close** stop a simulation and abort an unrelated armed gesture. Rows
  **L3**/**P3** exist solely to pin that the Close button gains nothing.
- **R3 — the FORM's own `<Key-Escape>` forwards too.** *Corrected mid-item.* The first attempt
  applied R2 to exclude it, reasoning *"with focus in the form those keys never reached callback.c,
  so they lost nothing and must gain nothing."* The premise is true; the conclusion left the defect
  live on the commonest path (measured above, `A3`/`D2`). Rung R3: user-visible, unratified,
  implement it and flag the item **E**. *Rejected:* leaving it out and filing the remainder — which
  would have shipped a fix whose own acceptance rows (`focus -force .drw` before every generated
  Escape) manufactured a state the product does not reach unaided, keeping the bug invisible
  forever.
- **R2 — one canvas Escape closes only the slot-OWNING form; a sibling stays up.** The
  amplification defect was that the *gesture* needed three Escapes, and that dies at the first
  press. *Rejected:* closing every open placement form, which destroys windows the user never
  addressed.
- **R1 — one `canvas_esc_release {self}` with an explicit exclude-self** (0241: a teardown must name
  what it is tearing down). ciform's blanket unbind named nothing and stranded a live `.addlabel`.
  *Rejected:* a third pairwise arm in each proc — nine combinations, the same clobber one form later.
- **R2 — the terminal does not touch the statusbar.** `update_statusbar()` runs at the *top* of
  `callback()`, so even today's C Escape leaves `DRAW WIRE!` up until the next event; the fix makes
  `wire_draw_active` evaluate 0 so the next motion clears it. *Rejected:* calling it from the
  terminal — its arguments are `callback()` locals, and it would double-call on the C path.

## Tests

New rows, all sabotage-verified:

| rows | suite | what they pin |
|---|---|---|
| I1–I9b (16) | `test_placement_wire_gate.tcl` (`--nogui`) | the verb: `ui_state`/`ui_state2`/`tclstop`/cadence fixup/semaphore guard/`escape_deselects`, each against an `abort_operation` **contrast** row |
| L0–L3 (4) | `test_add_wire_label.tcl` (xvfb) | `addlabel::canvas_escape` forwards; the Close button does not |
| P0–P3 (4) | `test_sch_add_pin.tcl` (xvfb) | same for Add-Pin |
| CI14a–g (10) | `test_create_instance.tcl` (X-only) | slot **content** + real `<Key-Escape>` delivery, the 0122-E2 clobber, one-Escape-with-two-forms, the stale-grab fall-through |
| CI15a–c (6) | `test_create_instance.tcl` (X-only) | **the form-focused route**, delivered with focus where `open()` left it — deliberately **no** `focus -force` |

CI15's preconditions assert `[focus]` is the form entry. That is load-bearing twice over: it caught
the first draft of the rows using `update idletasks` (which does not process the X `FocusIn`, so
focus stayed on `.drw` and the rows passed *hollowly* through the CI14 path), and it makes any
future regression in form focus handling fail loudly instead of silently re-hiding this bug.

## Sabotage matrix

Eight variants, run by the Verify-B agent against the `.drw`-slot fix. **Every predicted red
appeared; no predicted red was missing.** Two variants produced *extra* reds beyond prediction.

| variant | predicted | observed |
|---|---|---|
| `verb-noop` (the `escape` branch calls a static no-op) | 12 | **14** — all 12, plus CI14d and CI14g |
| `ui2-blind` (`ui_state2 &= ~MENUSTARTWIRE` → `|= 0`) | 5 | 5 — exact (I3, I8b, L2, P2, CI14d) |
| `semaphore-blind` (guard deleted) | 1 | 1 — exact (I8a only; I8b stayed green, proving I8a isolates the *guard*) |
| `label-forward-noop` | 3 | 3 — exact (L1, L2, CI14f) |
| `pin-forward-noop` | 2 | 2 — exact (P1, P2) |
| `ciform-forward-noop` | 2 | 2 — exact (CI14c, CI14d) |
| `grab-body-partial` (drop the `else {xschem escape}` arm) | 2 | 2 — exact (CI14b, CI14g) |
| `ciform-slot-clobber` (restore the blanket unbind) | 1 | 1 — exact (CI14e) |

The contrast rows (I4, I6a, I8a, L3, P3) correctly stayed **green** under `verb-noop`: they assert
what `abort_operation` does *not* do, so a dead verb cannot fake them.

`ciform-slot-clobber` confirms its own design note: with the total `else` arm intact the Escape
*outcome* stays correct under that sabotage, so only CI14e's **slot-content** assertion catches it.
An outcome-only row would have been hollow.

The CI15 rows were red-checked separately (write-up agent, after the R3 correction) by reverting
the three form-focused binds to `X::escape`: **CI15a/b/c went red at exactly `ui=65536 ui2=1`
while all ten CI14 rows stayed green** — the cleanest possible demonstration that CI14 could never
have caught this half.

## Tiers

All green, none moved except by the new rows: `shape_draw 421→421`, `paste_modify 376→376`,
`placement_wire_gate 171→187`, `preview_doors 177→177`, `add_wire_label 178→182`,
`label_ride 157→157`, `strand_oracle 32→32`, `sch_add_pin 21→25`, `instance_update 95→95`,
`inert_class 177→177`, `descend_symbol 38→38`, `refusal_channel_0251 45→45`, `hi_descend 24→24`,
`cadence_descend_newwin_ro 11→11`, `log_absorb 23→23`, `create_instance 56→72`,
`wire_split`/`crossview_paste` ok, WIREEDIT ALL PASS, harness 6 goldens PASS,
`run_regression.tcl` still exactly its 3 known-red lines. Risk-note suites re-run green:
`gesture_end_log` (no `--nolog`), `actionlog_suppress_gate`, `cmdmode_descend_0201` (CS3a–CS3c slot
round-trip intact), `drag_keeps_selection`, `ase_dialogs`.

## Still open

Adversary residuals that survive the fix, plus what was measured and deliberately not fixed:

- **`.mkinst` is a fourth swallow site** — `create_instance.tcl:351`,
  `bind $w <Key-Escape> {mkinst::cancel; break}`, focus `.mkinst.pw.lib.lb`, measured
  `after-ESC ui=65536 ui2=1`. The browser is a child selector and Escape-means-cancel-the-browse is
  a defensible reading, so it needs its own ratification. Filed as **0395**.
- **`X::canvas_escape` runs `X::escape` unprotected** before `catch {xschem escape}`. If the first
  half throws, the forward is silently lost. Not observed, but the shape is fragile.
- **`canvas_esc_release`'s terminal `catch {bind .drw <Key-Escape> {}}`** still blanks the shared
  slot without naming what it blanks (0241), and `ciform::open`'s raise-path `grab_esc` rebinds
  unconditionally — either can clobber an ASE `sod` seize installed *after* the form opened, and
  ASE would then restore a stale predecessor. Reasoned from source, not measured.
- **A grab cloned onto `.xN.drw`** by `clone_canvas_bindings` now runs `xschem escape` directly,
  bypassing `callback()`'s per-window `xctx` switch, so it would abort whatever context is current
  rather than the window that received the key. Unreachable in the default tabbed config
  (`new_schematic create` produced no `.xN.drw`) and therefore **untested, not cleared**.
- **The double abort on the PLACING path**: `abort_if_placing` passes `deselect=1` where the
  terminal passes `escape_deselects`, so a placing-case Escape calls `abort_operation` twice with
  mismatched deselect and costs a second `draw()`. Filed as **0393**.
- **ASE's `sod_end`** Escape also never reaches the terminal. Filed as **0394**.
- **Statusbar `DRAW WIRE!`** persists until the next event on both paths; the fix only makes
  `wire_draw_active` evaluate 0 for the next repaint. Pre-existing, not a regression.
- **The CI15 red-check exposed an evidence hazard, not in this fix but in how it was measured**:
  `test_create_instance.tcl` printed `RESULT: 1 FAILED` and still **exited 0**. Roughly 100 headless
  suites share that shape — `full_audit.sh` scores them by *banner* on purpose and catches it, but
  any `rc`-based runner reports a red suite as green. Every tier number in this file was
  consequently re-read from the logs, not from `rc`. Filed as **0396**.

## THE QUESTION FOR THE HUMAN (why this item is status E)

Canvas **and** form Escape, with a placement form open, now run the full C terminal. That newly
includes, on a path that previously ran neither:

- **`tclstop = 1`** — the only break-out of `propagate_logic`'s loop (`hilight.c:2301`); it stops a
  running simulation;
- **a deselect** for users who set `escape_deselects = 1` (default 0, `xschem.tcl:15884`);
- **ESC-commits-a-live-polygon** becomes reachable from a form Escape (`abort_operation`'s
  `new_polygon(END)`, which self-logs `xschem polygon …`).

> **Ratified, or should the form Escape forward only the abort and skip `tclstop`?**

It is implemented as a **full** forward because a partial one would leave the propagate-loop
break-out unreachable whenever any form is open — the same swallow wearing a smaller mask.
