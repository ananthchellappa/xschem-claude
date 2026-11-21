# 1384 — the sheet never said what the pick mode was waiting for

**Branch** `fluid-editing`. **Files** `src/rdw.tcl`, `src/xschem.tcl`.
**Suites** `tests/headless/test_rdw_window_1245.tcl` section HT (15 rows, five
on both arms), `tests/headless/test_rdw_keys_1245.tcl` section HP (2 rows, :99).
**Status: FIXED, after a repair pass — see "The repair pass" below, which is
where the tooltip half of the request actually started working.**

## What the user asked for, verbatim (2026-09-07)

> Add status message in status bar of schematic window for the three RDW print
> modes 1,2,3 key : Is user is in verb-noun mode, pressed key without instance
> selected, she is in command mode, and status bar should suggest "Click on
> instance for annotation/summary/all OP info in Results Display Window" And,
> BTW, if since *that* much space may not be available on the status bar, if
> user hovers on the visible portion of the message in the status bar, can we do
> a tooltip that displays the rest? Doable?

## The gate — ruled by the user, not inferred

Asked whether to gate the hint on the verb-noun interface, they declined both
options offered and restated the condition better:

> If an instance is selected and user presses 1/2/3, only the selected instance
> is processed. One does not enter command mode in this case. If more than one
> selected, issue a warning in the CIW and refuse.

So the gate is **command-mode entry**, and `intuitive_interface` is not read at
all — the pick mode is identical in both grammars and a hint that appeared in
only one would itself be the surprise.

### The other two branches were DRIVEN before a line was written

The brief called this a verification task, not a change. Measured at HEAD on the
shipped `xschem_library/examples/cmos_inv.sch`, :99, before this feature
existed:

| selection | `rdw::_selected_instance` | what happened |
|---|---|---|
| M1 | `one M1` | `pick_running` **0**, canvas **not** seized, one block headed `M1:/`, `xschem get lastsel` still 1, CIW **silent** |
| M1 + M2 | `many {}` | CIW warns by name; **nothing moved** — no block, no window, `::rdw::listkind` still `summary` |
| a wire | `notinst {}` | its own CIW line, same nothing |
| nothing | `none {}` | `pick_running` 1, canvas seized, CIW prompt |

All three of the user's clauses already held, including the "refusal changes
nothing" half (issue 1312's rule, row K12's fence). **No defect** — the hint is
an addition on working code. Rows HT7 and HP2 now hold the two silent branches
from the new side: neither of them may write the status bar.

## Which slot, and the measurement that refused the other one

`.statusbar.10` — xschem's own mode-prompt label, the one that already carries
`DRAW WIRE!` and `HIGHLIGHT NET! (click a net or label, ESC to end)`
(callback.c:9902-9914). The same shape of message, in the same slot, per
top-level (`.drw` → `.statusbar.10`, `.x1.drw` → `.x1.statusbar.10`).

**`.statusbar.1`, the wide one, was measured and refused.** It is C's
`statusmsg()` field (scheduler.c:65) and callback.c:10177 rewrites it on **every
event** — motion, key, enter — guarded only by an 8-pixel test and *not* by
`ui_state`. Measured on :99 with a pick live and `ui_state` 0: the sentence
written there was gone after **one hover motion**, replaced by
`mouse = 220 -110 - selected: 0 path: .`, and a selection change replaced it
with select.c's `n= x= y= w= h=` info line. That is exactly what actions.c:5985
documents from the other side, and its remedy — `statusmsg_hold()` — buys a
fixed `STATUSMSG_HOLD_MS` = 5000 ms (scheduler.c:70), which says nothing about
how long a user takes to find a device. It is also the field carrying the
readout the user is aiming with.

**`.statusbar.10` is blanked, not fought over, and that is the difference.**
`update_statusbar()` (callback.c:9860) resets it to `{ }` on every canvas event
whenever no C `ui_state` draw/hilight bit is set — and this mode is pure Tcl, so
none ever is. Measured: one hover blanked it too.

The first answer was the one `ase::ui::sod_prompt_pump` (ase_window.tcl:1880)
already ships for the same class of Tcl-level canvas pick mode: a light periodic
re-assert on **80 ms**, ASE's number taken unchanged so the two modes cannot
drift (`rdw::hint_period`). ⚠ **That was not enough, and ASE's stated reason for
the number is measurably false** — see the repair pass. The 80 ms timer is now
the *backstop*; the sentence is put back by a private binding tag on the canvas,
in the same binding invocation C blanked in.

*Cost, stated:* a C draw mode armed **during** a pick would have its own
`DRAW WIRE!` overwritten (now immediately rather than within 80 ms). Unreachable
by any useful gesture — the press that would draw the wire is the press the
seize eats — and the alternative, a C `ui_state` bit, is an engine change for a
Tcl-only mode.

*Cost that is real,* measured on :99, `.statusbar` children packed `-side left`:

```
main window 1110 px   the slot gets all 471, and .statusbar.1 pays for it, 266 -> 218
main window  700 px   the slot is CLIPPED to 356 and .statusbar.1 keeps its 266
```

`HIGHLIGHT NET! (click a net or label, ESC to end) ` wants 350 px and does the
same thing three quarters as hard. Either way it lasts exactly as long as the
mode.

⚠ **That cost is a STEP. While the timer was the only door it was a 12 Hz
oscillation** — the label is packed `-side left` with no `-fill x`, so its width
follows its text and it swung 8 ↔ 471 px, dragging `.statusbar.1` between 218
and 275 px, for as long as the pointer moved. Repaired; row HT13 is the fence.

## The tooltip — doable, and it needed two helpers `balloon` never had

`balloon` (xschem.tcl:14826) bakes its help string into `<Enter>` at bind time
and has no undo. This is the tree's first tooltip whose **string changes** and
whose **widget belongs to someone else the rest of the time**, so two helpers
went in beside it:

* **`balloon_off w`** — cancels any pending `balloon_show` for that widget
  (scanned out of `after info`, so a caller that lost track of the string still
  cannot leak one), clears the four bindings **only if they are balloons**, and
  destroys a live tip. The binding test is not tidiness: `bind $w <Enter> {}`
  *destroys* a binding and four status-bar labels carry a build-time tip of
  their own (`.statusbar.2`, `.4`, `.6`, `.7` — xschem.tcl:18723 and siblings).
* **`label_clipped w text`** / **`balloon_clipped w text ?pos? ?delay?`** — arm
  a tip **only** when `font measure` overflows the label's own usable width
  (`winfo width` minus `2*(borderwidth + highlightthickness + padx)`). A tooltip
  repeating text the reader can already see in full is noise.

Measured on :99 at 1920x1080, sweeping the main window with the 467 px
annotation sentence on the label:

```
1400 / 1110 / 1000 / 900 / 850 / 820 / 815 px  ->  slot 471 px, NO tip
 800 -> 456   750 -> 406   700 -> 356   600 -> 256   500 -> 156   tip ARMED
```

`pack -side left` really does **shrink** the over-wide label once the bar runs
out of room rather than letting it hang over the edge, so `winfo width` alone is
the honest measure — no `winfo x` arithmetic against the parent. Threshold:
between 800 and 815 px of main window. `pos 1` (widget-anchored), because issue
1368 measured a moved `pos 0` tip landing under the pointer, dying to its own
`<Leave>` and flickering 25 times in 1.5 s; a status bar sits on the bottom edge
of its window, which is exactly where issue 1368's vertical **flip** is
load-bearing. Driven through the real `<Enter>` at 700 px: the tip renders
`567x24+717+941` on a 1920x1080 screen, whole sentence, on screen.

**The re-arm is the trap, and it has two halves.** Re-binding is not enough: an
`<Enter>` that already fired leaves an `after 1000 balloon_show <w> {the OLD
sentence} 1` in flight that `balloon`'s own `<Leave>` can no longer cancel once
the string has moved — the tip would pop the previous mode's sentence one second
later, over a bar that now says something else. Row HT8 presses `2` over a live
`1`-pick at a clipped width and asserts the label, the **baked** string and the
timer queue all moved together.

*(Aside, measured while writing HT8: the binding `balloon` writes reads
`after 1000   balloon_show %W {{the sentence}} 1` — two levels of quoting,
because `[list $help]` is wrapped by an outer `[list]`. `after ms script ...`
CONCATs its trailing words and strips exactly one, so `balloon_show` is handed
the clean sentence. Verified with `string equal` through the real `<Enter>`, for
this hint and for the `aA` button. **Not** a bug; the row's reader takes both
levels off.)*

## One proc decides what the slot says — invariant I1

`rdw::_hint_sync` reads the mode, picks the sentence and writes the label. Every
other place is a **door** on it:

| door | why it exists |
|---|---|
| `pick_start`, fresh seize | the mode just armed |
| `pick_start`, re-arm in place | `2` over a live `1`-pick re-arms without re-seizing, and the sentence names the list |
| `pick_end` — **after** `array unset pick` | the synchronous exit; ESC on the canvas and `.rdw`'s own Escape (DD-12) both reach it |
| `pick_resume`, rehome | a descend that lands elsewhere moves the sentence with the mode |
| `pick_resume`, drop path | the one exit that is not a `pick_end` at all |
| `rdw::_hint_attach`, the canvas binding tag | C blanks the label at the top of `callback()` on every canvas event, and this runs in the same binding invocation |
| `rdw::_hint_pump`, the 80 ms backstop | the seized sequences `break` before the tag is reached; and it is the second layer under every exit |

The exits are covered **twice on purpose**: the transition blanks the slot in
the same call, and the backstop timer notices a mode that vanished by a route
nobody added a door to and stops itself within 80 ms. A stale `Click on instance` after the
mode has ended is worse than no hint — it is an instruction for a click that
will do nothing.

**Note, 2026-11-19 (issue 1724, its last build).** One thing changed in what
`rdw::_hint_sync` writes: it does not write the sentence while another click mode
that is up (ASE-L's Select On Design, a Calculator selector's pick) is seized over
this mode on the same canvas (`rdw::_pick_covered`). The presses are that mode's
then, it keeps its own sentence on this slot, and the two used to take turns on it.
Everything else in the table above goes on while this mode is underneath: the tag,
the record of the slot, the blanking of what was last written, the timer, and the
tip, which therefore still holds this mode's sentence over a slot that shows the
other mode's. The sentence is back within one period of the mode on top ending.
Band PG28 of `tests/headless/test_calc_pick.tcl`.

The sentence itself is **one template**, because the identity token *is* the
adjective the user's three sentences differ in; the fence on an unknown identity
is `rdw::_list_name`, the proc that already owns which list names exist, so
`refresh` (a real `rdw::key` argument) answers the empty string rather than
`Click on instance for refresh OP info`.


## The repair pass — the tooltip half of the request never worked

An adversary drove the whole gesture and found the second half of the user's
sentence — *"if user hovers on the visible portion of the message in the status
bar, can we do a tooltip that displays the rest?"* — **producing no tooltip at
all**, with every row above green. Reproduced independently, 3/3, at 700x761
with the mode live: 25 real canvas motions, the pointer warped on to the label,
1.65 s of real time.

```
PROBE slot            = .statusbar.10
PROBE txt             = |Click on instance for annotation OP info in Results Display Window|
PROBE tipbound        = 1
PROBE aftersweep.w    = 8            <- the label COLLAPSED on the way past
PROBE aftersweep.txt  = | |
PROBE over            = .statusbar.10   <- the pointer really is on it
PROBE balloon         = 0               <- and no tip is ever created
```

**Two causes, and they compound.**

1. **The slot collapses.** `.statusbar.10` is packed `-side left` with **no
   `-fill x`** (xschem.tcl:16834), so its width follows its text: 8 px blank,
   471 px with the sentence. C blanks it on every canvas event and the 80 ms
   timer grew it back, ~12 times a second. The pointer can only reach the status
   bar **from the canvas**, so it arrives at a label that is 8 px wide, and the
   crossing churn cancels the pending show.
2. **The tip's arm was cached on `winfo width`.** `rdw::_hint_sync` re-armed
   whenever the width term moved, and `balloon_clipped` begins with
   `balloon_off`, which cancels the `after 1000 balloon_show` the `<Enter>` had
   just queued. The pointer was already inside, so **no second `<Enter>` ever
   came** and the tip was unreachable until the pointer left and returned —
   which re-collapses the label.

**And the row that claimed to fence it drove a different path.** HT9's sentence
said the tip "really renders that whole string through the real `<Enter>` and
the real `balloon_show`"; the body warped the pointer and then called
`balloon_show` **directly** — no `<Enter>`, no 1000 ms delay, no arrival from
the canvas. It was green for an unstated reason, which is the failure mode this
tree's row style exists to prevent.

### What the timer was actually costing, measured

Motion timer on `.drw`, the slot sampled every 10 ms, 200 samples a cell, hint
live throughout, on :99:

| main window | motion every 16 ms | 33 ms | 50 ms |
|---|---|---|---|
| 1110x761 | **18 %** visible | 16 % | 40 % |
| 1400x800 | **17 %** visible | 16 % | 37 % |

`.statusbar.10` reported two widths throughout (8 and 471) and `.statusbar.1`
two (218 and 275). So the comment this file inherited from
`ase_window.tcl:1884` — *"~80 ms => a blanking event shows at most a sub-frame
flicker before the prompt returns"* — has it backwards: **it is the prompt that
shows for a sub-frame.** ASE's own select-on-design prompt carries the same
false sentence; that is recorded on issue 1387, not fixed here.

### The fix — a private binding tag on the canvas

C blanks at the **top** of `callback()` (callback.c:10093, unconditional), and
`.drw`'s own bindings are what call `xschem callback`. A binding tag inserted
immediately **after** the widget's own tag therefore runs in the *same binding
invocation*, and Tk's geometry manager runs at idle — so the blank never
survives to a relayout. `rdw::_hint_attach` / `_hint_detach` / `_hint_tag` /
`_hint_events`, driven from `rdw::_hint_sync` (which keeps the single
definition, invariant I1) and recorded in `hint(cv)` exactly as the slot is in
`hint(slot)`.

*Why a tag and not `bind $cv <Motion> +…`*: `rdw::_pick_seize` latches four of
this canvas's binding scripts **verbatim** and row V6 asserts the restore is
byte-identical, so an append is not removable without rewriting a script the
seize is holding. A tag is one `bindtags` write each way and cannot touch what
the seize latched. *Why the timer stays*: all four seized scripts end in
`break`, which stops the remaining binding tags for that event, so a press, a
release and a B1-drag never reach the tag — and a mode that ended by a route
nobody added a door to still has to be noticed.

*The other half of the fix*: the tip's cache key is now the **verdict**
(`label_clipped`) and not the raw width, so a regrow that does not change
"clipped or not" no longer disturbs a tip the pointer is sitting on.

### Measured after

```
PROBE aftersweep.w    = 356      (was 8)
PROBE aftersweep.txt  = |Click on instance for annotation OP info…|   (was blank)
PROBE balloon         = 1        (was 0)      <- the user's tooltip, real gesture
```

| main window | motion every 16 ms | 33 ms | 50 ms |
|---|---|---|---|
| 1110x761 | **100 %** visible, slot 471 px, `.statusbar.1` 218 px | 100 % | 100 % |
| 1400x800 | **100 %** visible, slot 471 px, `.statusbar.1` 275 px | 100 % | 100 % |

Cost: `rdw::_hint_sync` is ~20 µs a call; a synthetic `.drw` `<Motion>`
delivered `-when now` costs 73–97 µs without the tag and 93–155 µs with it — so
a 60 Hz motion stream buys the synchronous re-assert for about **1.3 ms per
second** of moving the mouse.

### The tab claim was backwards, and it is now measured

`rdw::_hint_slot`'s comment and HT2's sentence both said the arithmetic was
"right for a tab too, because the tabbed interface shares one status bar".
Sharing the bar is exactly what makes it wrong — the **canvas path** is not
shared with it. Measured on :99, shipped `tabbed_interface 1`, one
`xschem schematic_in_new_window force`:

```
xschem get current_win_path   .x1.drw
winfo exists .x1.drw          0        <- tabs share the ONE real .drw
xschem get top_path           {}       <- so C writes the shared .statusbar.10
the string arithmetic         .x1.statusbar.10     <- does not exist
rdw::pick_start               0        <- and the mode does not arm at all
```

`_hint_slot` now **asks the widget hierarchy** (`winfo toplevel`) and keeps the
string arithmetic only as the fallback for a path that is not a widget, which
`_hint_sync`'s own `winfo exists $slot` then drops. Three things were rejected
on measurement:

* **`xschem get top_path`**, the adversary's suggested fix and the obvious one:
  it is by its own definition the **current** window's ("get top hier path of
  current window", scheduler.c:5468), not the one the mode was seized on, so a
  pick live on `.x1` while the user works in the main window would write the
  main window's bar. Verified end to end that the hint must follow
  `pick(canvas)`: with a forced `.x1` top-level the sentence lands on
  `.x1.statusbar.10`, the main bar stays `{ }`, the tag goes on `.x1.drw` only,
  and `pick_end` puts both back.
* **`tabbed_interface` as the discriminator**: `xschem new_schematic
  create_window .x1 <sch>` forces a **real** top-level while `tabbed_interface`
  is still 1 (test_multi_window.tcl MW2/MW1b), so the flag does not separate the
  two. Measured: `.x1.drw` exists, `winfo toplevel .x1.drw` is `.x1`.
* **a tab arm inside `_hint_slot`**: a tab's `.x1.drw` and a **destroyed**
  window's `.x9.drw` are the same shape, so no rule maps the first to the shared
  bar without also redirecting the second there — which would put a live
  sentence on the wrong window. Refusing both is the only answer right twice.
  And the tab case is unreachable anyway for a reason that is **its own
  defect**: `pick_start` refuses in a tab, so 1/2/3 with nothing selected does
  nothing there and says nothing, not even in the CIW. Filed as issue **1387**.
  Its fix is to give the seize the real canvas widget, after which
  `pick(canvas)` is always a widget and this proc is already right.

Row **HT14** drives a real tab and asserts the silence, so the day 1387 is fixed
without the hint following, this suite says so.

### One line was dead, and it is the one only a state reaches

The adversary neutered the second `rdw::_hint_blank` inside `_hint_sync` (`if
{0}`) and the whole suite stayed **ALL PASS** — every row drove an *exit*, and
on an exit `$slot` becomes `{}` and the first blank has already fired. The case
only that line covers is a **live** mode whose `::rdw::listkind` names a list
`rdw::_list_name` has no words for: `hint(slot)` still equals `$slot`, nothing
above fires, and the previous list's sentence would stand under a mode that no
longer means it. `refresh` is a real `rdw::key` argument, so this is reachable
state and not a hypothetical. Row **HT11** is the fence; the line stays.

### Two Tcl writers of one slot — recorded, not arbitrated here

`ase::ui::sod_prompt_pump` writes the **same** `.statusbar.10` on its own 80 ms
timer whenever select-on-design is armed, and neither pump reads the other. It
is worse than a label fight: both modes also seize `<ButtonPress-1>` on the same
canvas, last arm winning, so with both live **ASE's prompt was on the label
while an RDW click was what a press actually did** — the label was lying about
the mode. The synchronous door makes this hint win the label as decisively as
the seize wins the click, so the two now **agree**; that is an improvement, not
an arbitration. The real defect is two Tcl command modes seizing one canvas with
nobody deciding, and it is filed on issue **1387** against the seize, not
against the label. Recorded in `rdw.tcl` beside the C-draw-mode cost.

### A citation was wrong

`rdw::_hint_slot`'s comment said the status bar "is built per TOP-LEVEL by
`pack_widgets` (xschem.tcl:18719)". Line 18736 is inside **`build_widgets`**
(declared 17795); `pack_widgets` is at 16824 and only **packs** the slot, at
16834 — and that pack line, `-side left` with no `-fill x`, is the load-bearing
one for the collapse above. Corrected.

## Rows

`test_rdw_window_1245.tcl` section **HT** — HT1 the three sentences and the
template's fence; HT2 the slot, from the canvas's own top-level, and
`.statusbar.1` named nowhere; HT3 every door safe with no Tk at all; HT4 the
single definition and the door count including `pick_end`'s ordering; **HT4b**
(repair pass) the structure of the synchronous re-assert — one tag, one script,
one event list, `bindtags` written from two procs and nowhere else, and the four
seized sequences ending in `break`; HT5 the hint arrives with the wide field
untouched; **HT6** (re-spelled) the synchronous re-assert as an A/B in one
process — tag off and C's blank stands, tag on and the sentence stands, with no
timer having run; HT7 the two silent branches; HT8 the re-arm and the cancelled
show; **HT9** (re-spelled) armed only when clipped, and its sentence now claims
`balloon_show` and not the tooltip; HT10 all four exits, now including the
binding tag as a sixth fact; **HT11** the clear reached by a state and not by an
exit; **HT12** the whole tooltip gesture — canvas sweep, real warp, real 1000 ms
delay, a real toplevel, and the negative at a width where the sentence fits;
**HT13** the eviction is a step and not a 12 Hz swing; **HT14** a real tab;
**HT15** a re-decision that changes nothing must not cancel a tip the pointer is
already waiting for.
`test_rdw_keys_1245.tcl` section **HP** — HP1 a bare `1` on the canvas under the
cadence profile and a real ESC; HP2 the ruling through the real keyboard.

`RW_FLOOR` 193 → **197**, and → **198** by the repair pass (HT4b is the only new
row that runs on both arms; HT11–HT14 are `live_tk`-gated and uncounted).
`KX_FLOOR` 90 → **92**, unchanged by the repair pass — HP1 and HP2 gained legs
(the binding tag, and eight real hover motions that must leave the sentence
standing) but no row was added. Row FZ4 re-spelled rather than added: its tooltip leg was a bare `::balloon` count of 1, which would have been
satisfied by any three calls once the number was bumped; it now counts the three
**by name**.

## The `:0` run, PAID — and it found two rows of this item that were measuring
## the environment

The first spelling of HT9 and HT10 asserted **pixel constants through a
`wm geometry .`**: HT9 said "at 1200 px no tip, at 600 px a tip" and HT10 said
"the tip is armed" in its UP states. Both went red on `:0` (Xwayland), and each
for a different reason, both of them the environment and not the code:

* HT10 — at 700 px the **shortest** of the three sentences (`all`, 61 characters
  against 66) *fits* in Xwayland's font while all three clip under Xvfb's, so a
  constant `1` was a statement about DejaVu.
* HT9 — `wm geometry .` came back with the **same slot width** at 1200 and at
  600, so the row's own precondition (the two widths differ) was false. A
  compositor is not obliged to honour a resize request.

That is issue 1385's coupling, self-inflicted, and both are now written so no
window manager is asked for anything:

* the tip is asserted as an **agreement** — `armed if and only if the label's
  own current text is clipped` — which is the contract, is true in any font, and
  still reds if the clear leaves a binding behind (a blank label is never
  clipped). It converges over at most 600 ms in the UP states, because the arm
  is a pump decision up to 80 ms old and `:0` delivers three `<Configure>`
  events per request; the CLEAR is read with no pumping at all, which is the
  half of HT10 that claims to be synchronous.
* HT9 drives the predicate with **two texts at one width** — `x`, which fits in
  any label, and a 300-character string, which fits in none — so the predicate,
  the arm, the render and `balloon_off`'s disarm are all measured with no
  geometry at all. The wide/narrow *main window* numbers stay in this issue,
  where they belong: they are a fact about a font, not a contract.

`ht_tipok`'s third term also drove a small change in the code: the pump's cache
key gained **"is a tip actually bound"** beside the sentence and the width, so a
binding removed by some other hand is put back rather than believed away. Costs
one `bind` read per 80 ms; makes the pump's contract simply "make the slot
agree", which is what every other line of `_hint_sync` already says.

After that, on `:0`, twice:

```
4 FAILED (257 passed)   SL8 FZ11 FZ17 FZ18
4 FAILED (257 passed)   SL8 FZ11 FZ14 FZ17
```

— exactly issue **1383**'s set, and no HT row among them. The keys suite's `:0`
debt was paid in the same pass and is **18 FAILED (74 passed)**, measured at
HEAD with this item out of the tree as **18 FAILED (72 passed)** — same count,
the two extra passes being HP1 and HP2. Filed as issue **1386**.

## Sabotage — every new mechanism has its own fence

Driven on `:99`, one change at a time, each reverted afterwards
(`md5sum` back to the good file):

| what was neutered | what goes red |
|---|---|
| the binding tag never attaches (`if {0 && …}`) | HT6, HT13, HT10, HT11 — and HP1 in the keys suite |
| the tip's cache key back on `winfo width` | HT15 |
| **both** — the state this feature actually shipped in | those six **and HT12**, the user's own gesture |

Each half alone still leaves the tooltip working, which is why HT12 does not
fence either of them on its own and both have a row of their own. The earlier
pass's sabotage results still hold: lowercasing `OP` reds HT1/HT5/HT6/HT8/HT10;
`hint_period` 80 → 4000 reds HT6/HT9/HT10; disabling the exit blank reds
HT5/HT10; `label_clipped` forced to 1 reds HT9 and forced to 0 reds HT8/HT9;
`balloon_off` not cancelling pending shows reds HT8/HT9.

## Measured (repair pass, 2026-09-08)

```
test_rdw_window_1245  :99            267 checks, ALL PASS
test_rdw_window_1245  --nogui        209 checks, ALL PASS
test_rdw_window_1245  :0             3 FAILED (264 passed)  SL8 FZ11 FZ17 — issue 1383
test_rdw_keys_1245    :99             92 checks, ALL PASS
test_rdw_keys_1245    --nogui        SKIP, by design
test_rdw_keys_1245    :0           12 FAILED (80 passed)   subset of issue 1386
test_op_param_store_1245 :99/--nogui 142 / 142 checks, ALL PASS
test_op_annot         :99 / --nogui  492 / 485 checks, ALL PASS
test_rdw_seam_1245    :99 / --nogui   49 /  49 checks, ALL PASS
test_annot_declutter_1244 :99        134 checks, ALL PASS
test_ase_dialogs      :99            176 checks, ALL PASS
test_ase_final        :99             82 checks, ALL PASS
test_wave_split_strip :99            221 checks, ALL PASS
test_calc_widgets     :99            244 checks, ALL PASS
test_results_dialog   :99             57 checks, ALL PASS
test_results_select   :99            377 checks, ALL PASS
test_wave_sigbrowser_sea   :99        79 checks, ALL PASS
test_wave_sigbrowser_i1315 :99       192 checks, ALL PASS
test_multi_window     :99             15 checks, ALL PASS
test_clone_canvas_bindings :99         3 checks, ALL PASS
```

The last seven are the neighbours of the two changed files that nothing else
covers: every suite in the tree that names `balloon` (the three new helpers live
beside it in `xschem.tcl`), and the two that drive second windows and tabs (the
`winfo toplevel` derivation in `rdw::_hint_slot`).

⚠ Both `:0` lines were taken through `run_suites.sh` with `AUDIT_DISPLAY=:0`, so
the GUI gate was live. The window suite's three are exactly issue **1383**'s set
and **no HT row is among them**, including the five the repair added. The keys
suite's twelve — `F1 V3 V7 D1 RA1..RA6 LK2 KD1` — are a **strict subset** of the
set issue **1386** filed (that issue recorded 18: a stable core plus a rim that
moves run to run; this run's core is smaller, which is Xwayland's variance, not
a claim that anything was fixed). **HP1 and HP2 pass on both servers**, as they
did before the repair, and the legs the repair added to them (the binding tag,
and eight real hover motions that must leave the sentence standing) pass on
`:0` too.

⚠ `run_regression.tcl` (T1) was **not** run: it must run solo (issue 0990) and
the driver owns it.

## Owed

* **Rule debt 1384** — three decisions the request did not settle:
  1. **the tip carries the WHOLE sentence, not "the rest"**. Rendering only the
     clipped tail needs the exact clip column, a font metric the label does not
     publish, and a tail read out of context (`...OP info in Results Display
     Window`) is worse than the sentence. Alternative: measure the clip column
     and show the remainder.
  2. **the hint evicts part of the coordinate readout on a wide window** (266 →
     218 px at 1110), and clips itself instead on a narrow one. Alternative:
     shorten the sentence to fit, which the user explicitly did not ask for
     ("do not silently shorten").
  3. **How the sentence is kept on the label.** ⚠ *This option set was
     MISFRAMED in the first pass and is restated here.* It used to say "80 ms
     re-assert, alternative a C `ui_state` bit, which removes the sub-frame
     flicker" — but the flicker was not sub-frame: with the timer alone the
     sentence was on screen **16–40 %** of the time while the pointer moved, and
     the slot's width swung 8 ↔ 471 px at ~12 Hz, dragging the coordinate
     readout with it. What ships now is a **synchronous re-assert** from a
     private binding tag on the canvas: measured **100 %** visible at every
     motion rate, both widths constant, for about 1.3 ms of CPU per second of
     moving the mouse. The remaining choice is whether that is the right shape
     at all, or whether the engine should own it: a C `ui_state` bit for a
     Tcl-level pick mode would make `update_statusbar()` skip the blank instead
     of having it undone, at the cost of an engine change for a Tcl-only mode
     and a bit that C would then have to clear on every path that ends one.
* **One `look` debt** — this is pixels: the green label on the schematic status
  bar, the sentence, and the tooltip that appears when the window is narrow. No
  suite is an eyeball.
* **The two `:0` suite debts are PAID, and both are red for reasons that are not
  this item's**: `test_rdw_window_1245` at issue **1383**'s four rows, and
  `test_rdw_keys_1245` at the eighteen now filed as issue **1386**. Both debts
  are left standing in the ledger as pointers at those issues. ⚠ A green `:0`
  line from either suite is not by itself evidence — check the count, because a
  dead `:0` client falls back to the headless arm.
