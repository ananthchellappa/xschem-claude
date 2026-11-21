# 1307 — a new window or tab created while a canvas command mode is LIVE inherits the seize, and the mode's own ESC restores only the canvas it seized

**Status:** FILED, NOT FIXED. **TRUE OF THE TREE AS IT STANDS** (`0ce85dda`) —
this one is **not** a defect of the reverted B4-2 patch. It is measured against
**shipped `ase::ui::select_on_design`**, with no B4-2 code loaded.
**Found by:** item **B4-2**'s adversary (Verify-C), 2026-09-04, as route (b) of
its permanent-seize refutation; measured against ASE by the write-up agent.
**2026-11-19:** the clone route is closed for every mode that tells `cmdmode` what it
holds, which all three click modes now do; the second route, added below by item B4-3,
is not. See the last two sections: the second is about two modes stacked across a descend.

## The mechanism, and it is already written down

`src/cmdmode.tcl:44-50` documents the hazard exactly, and states the invariant
that is supposed to make it safe:

> ORDERING NOTE, not obvious and load-bearing. Suspending BEFORE a new window or
> tab is created is what keeps `clone_canvas_bindings` (xschem.tcl) honest: it
> copies `.drw`'s bindings verbatim onto every new canvas, so a still-seized
> mode would be cloned onto the child with the parent's key already substituted
> — clicks there would queue into a mode whose `sod_end` restores bindings on
> the *other* canvas, leaving the child permanently seized with dead scripts.
> **Because every suspend site in the descend chain runs before
> `schematic_in_new_window`, the clone always copies pristine bindings.**

The last sentence is true **of the descend chain** and of nothing else.
`clone_canvas_bindings` is called by C for **every** new window and tab
(`src/xinit.c:2121`, `:2337`), and `File > New Window` / a new tab has **no**
suspend site at all. Issue **1301** already records that the cadence profile's
own descend has none either.

## MEASURED — shipped ASE, reverted tree, `:99`/openbox

`rdw::pick_start exists = 0` — no B4-2 code in the process.

```
select_on_design armed = 1
.drw    P='ase::ui::sod_click probe; break'  E='ase::ui::sod_end probe; break'
.x1.drw P='ase::ui::sod_click probe; break'  E='ase::ui::sod_end probe; break'
after ESC on the parent:
.drw    P=''
.x1.drw P='ase::ui::sod_click probe; break'
VERDICT: ASE LEAKS THE SAME WAY - true of the tree today
```

The parent is cleaned; the child keeps the seize. Its `<Key-Escape>` runs
`sod_end probe`, which finds nothing active and restores bindings on a canvas
that is already pristine — so **the child's ESC is dead** and every click there
queues into a mode that no longer exists.

## And the same route was measured on B4-2's mode, before the revert

```
armed on: .drw
.x1.drw  P='rdw::pick_click; break'  R='break'  E='rdw::pick_end; break'  M='break'
after ESC on the parent:
.x1.drw  P='rdw::pick_click; break'  M='break'
VERDICT: LEAKED - the new window is seized and its ESC restores nothing
ESC on the child returns: 0
```

⚠ **The fourth sequence makes it worse.** Once issue **1304**'s fix lands,
`<B1-Motion> {break}` joins the cloned set, so the leaked child also loses its
rubber band — 1304's *transient* harm becomes *permanent*, on a window the user
never armed a mode on.

## Recommended fix (option a)

**Suspend at the door that creates the window, not only in the descend chain.**
`cmdmode::suspend_all` immediately before `schematic_in_new_window` /
`new_schematic create_window` / the tab-create path, and `resume_all` after —
which is what `cmdmode.tcl`'s own ordering note already prescribes, applied to
the sites it does not yet cover. This is one mechanism for all modes and needs
no per-mode change.

**Rejected — (b) have each mode re-seize on the child.** That is what
`pick_resume`/`sod_resume` do for a *descend*, where the user's mode follows
them to the canvas they land on. A new window is not a descend: the user is
still working on the original, and a mode that spread itself to every window
would be a bigger surprise than one that pauses.

**Rejected — (c) have `clone_canvas_bindings` skip the four seized sequences.**
It would need to know which scripts belong to a mode, i.e. a second definition
of the seize, in C, in a proc whose job is to copy verbatim.

**Rejected — (d) leave it, since the child's ESC is only "dead", not harmful.**
Measured above: clicks on the child run the parent's click handler with `break`,
so the child cannot select anything at all. That is not an inert leftover.

## Acceptance for whoever takes it

1. Arm any registered command mode, create a new window, and assert the child's
   four canvas slots equal the child's own predecessors — **not** the parent's
   seize.
2. `ESC` on the child restores the child; `ESC` on the parent restores the
   parent; neither restores the other's bindings.
3. The existing descend suites (`test_cmdmode_descend_0201`,
   `test_verb_noun_descend_0200`) stay green — the descend path already
   suspends, and this must not double-suspend it (`cmdmode.tcl` D6: a second
   `suspend_all` is a no-op returning 0).

## ⚠ ADDED 2026-09-04 by item **B4-3** — the a1 rehome residue lands HERE, with no new number

B4-3 fixed issue **1305** with its option **a1**: `rdw::pick_start` clears
`pick(suspended)` as part of taking the canvas back. **That is deliberate, and
it has a stated cost that belongs to this issue's subject**, so it is recorded
here rather than under a fresh number:

> `pick_start` now re-seizes on the canvas **current at key-press time**, which
> during a descend's wait is still the **parent**. Because `resume_all`'s
> `pick_resume` returns 0 once the flag is gone, a descend that lands on a
> **different** canvas (new window, new tab) leaves the mode live on the **old**
> one and never rehomes it.

So this issue now covers **two** ways a command-mode seize ends up on a canvas
nobody armed it on: `clone_canvas_bindings` copying it forward (the original
subject, true of shipped `src/ase.tcl` today), and a1 declining to rehome it.
The rejected alternative that *would* have preserved the rehome — a2, the
suspended arm returning 1 without seizing — makes a `1`-`4` press during the
wait silently do nothing, contradicting ruling **D-2**. See issue 1305's
"COST, STATED".

**Whoever takes this issue must fix both**, or the fix will look complete and
leave half the class live. Issue **1309**'s option (d) — a suspend that returns
a lock `pick_start` must not step over — is the shape that covers all of it.

## Still open

Everything above. Related: **1301** (the cadence descend does not suspend),
**1305** (the other route to the same permanent-seize end state — **fixed**
2026-09-04, and its cost is the paragraph above), **1309** (the descend's own
half of 1305's key press, and probably the general fix for this whole class),
**1304** (the fourth sequence that widens both).

## The clone route closed, 2026-11-19 (issue 1724)

Built with issue 1724's third repair. It is neither the recommended (a) nor any of the
rejected shapes as written: no suspend site was added at the new-window door, and
`clone_canvas_bindings` was not taught which sequences a mode seizes. Each mode says what
it holds, and the copy asks.

**The mechanism.**

- `cmdmode::register <key> <suspend_cb> <resume_cb> ?<held_cb>?` (`src/cmdmode.tcl`). The
  optional fourth argument is a command prefix that takes no arguments and answers a flat
  list `canvas sequence script predecessor …`, one group of four for every canvas binding
  the mode holds NOW: the script it bound and the script that slot held before the mode
  took it. A mode that is not up, or is suspended, answers an empty list.
- `cmdmode::pristine <canvas> <sequence> <script> ?<canon>?` answers the script that slot
  would hold with no mode up, given that it holds `script` now. It steps down through every
  mode whose held list holds exactly `script` in that slot, so a mode seized over another
  is stepped through as well. A script no mode holds is answered unchanged. A held callback
  that raises, or answers a list that is not groups of four, is passed over; a group whose
  predecessor equals its script is not stepped; the walk is bounded.
- `clone_canvas_bindings` (`src/xschem.tcl`) puts each script it is about to copy through
  `cmdmode::pristine`; an empty answer copies nothing. It passes `bind_seq_spelling` as
  `canon`, Tk's own spelling of a sequence, asked of Tk on a binding tag no widget has: a
  mode may declare `<ButtonPress-1>` although `bind` lists that binding as `<Button-1>`.
- The three click modes declare: `ase::ui::sod_held` (Select On Design), `calc::pick_held`
  (the Calculator's pick), `rdw::pick_held` (the Results Display Window's pick mode).

**Measured**, on a private Xvfb with openbox, the window made with `xschem new_schematic
create_window` while the mode is up (acceptance 1 and 2 above):

- **Select On Design.** The new window's canvas carries exactly the bindings of a window
  made the same way with no mode up; the mode's own canvas is unchanged; a real click on a
  wire in the new window selects it, while the mode is up and after its ESC, and queues
  nothing. Before: the click queued that window's net into the session, and after the
  mode's ESC the window still swallowed every left click. Rows PW1 to PW3 of
  `tests/headless/test_pin_marker_1724.tcl`; rows TPL9 and TPL9b of
  `tests/headless/test_ase_terminal_pick_1724.tcl` on the counted arm.
- **The Calculator's pick and the Results Display Window's mode.** The same: the new
  canvas carries none of the mode's scripts and a click there selects, during and after.
  Band PG25 of `tests/headless/test_calc_pick.tcl`, rows XP5 and XP6 of
  `tests/headless/test_rdw_keys_1245.tcl`; band PK15 and row K21 on the counted arm.
- **The contract by itself**, with stub modes: `tests/headless/test_cmdmode_0201.tcl`,
  legs CR4 to CR7 and CR9 without Tk, leg CR8 between two real canvases and through the
  real new-window door (a mode holding the main canvas's press slot: the new canvas gets no
  press script and no `<Destroy>` script, and still gets the user's own extra binding).

One thing the user sees that acceptance 2 did not foresee: **ESC pressed in the new window
is the editor's.** That window carries no script of the mode, so the mode ends by ESC in
the window it is on.

**Limits, each measured on the contract with stub modes.**

- The script a mode declares must be the exact string it bound. If anything is appended to
  a slot the mode holds (`bind … +…`), or the strings differ by a blank, the slot is copied
  as it stands, the mode's script included.
- A mode that declares no held callback, or is registered again without one, is not seen:
  its scripts are copied as before.
- The walk is bounded, so past its bound of stacked modes on one slot the answer is a
  mode's own script and not the editor's.
- When two modes hold one same script in a slot and a third mode with another script sits
  between them, the answer depends on the order the modes were registered. The three click
  modes do not produce that shape today.
- With the tabbed interface a new tab is not a new canvas: nothing is copied, and the
  canvas the tabs share keeps the mode's bindings.
- Not driven: the Cadence-style profile's Ctrl-N key itself (it runs the same command),
  a tab detached into a window (the second C caller of `clone_canvas_bindings`), and a
  window made while a mode is suspended.
- Older than this change, and cured since (the same day): without Tk
  `clone_canvas_bindings` raised `invalid command name "winfo"`, and `create_new_window()`
  calls it there too, so `xschem new_schematic create_window` under `--nogui` printed that
  error on stderr. The proc now leaves at once when there is no Tk. Row CR7c of
  `tests/headless/test_cmdmode_0201.tcl` calls it directly: a row through the real door
  cannot see the guard go, because C swallows the raise.

**Still open here:** the second route this file carries (item B4-3's a1 residue: a mode
re-armed during a descend's wait stays on the old canvas and is not rehomed), and the
descend entry points that do not suspend (issue 1301).

## The other half of the invariant: the release order, 2026-11-19 (issue 1724, fourth repair)

The comment quoted at the top of this file ended *"Because every suspend site in the
descend chain runs before `schematic_in_new_window`, the clone always copies pristine
bindings."* That was true of one mode. With two modes stacked on the canvas it was false
on the descend chain itself whenever the upper mode was registered after the lower one.

**Measured** by the third review of issue 1724 and by the repair, with real modes: Select
On Design (or a Calculator pick) with the Results Display Window's mode on top, then
`hi_descend … target=new_window`. `cmdmode::suspend_all` released the modes in
registration order, the lower one first; the Results window's release then put the lower
mode's scripts back on the canvas; the new window was cloned in that state. The held
lists are empty while a mode is paused, so `cmdmode::pristine` had nothing to step
through, and the clone copied the lower mode's scripts (its press, release, held motion
and Escape) onto the new canvas. After both modes were ended there, neither window took a
left click. The same stack through a descend in the same window or into a new tab left
that canvas dead too.

`cmdmode::suspend_all` now releases the top of a stack first (`cmdmode::release_order`;
issue 0201 has the rule, issue 0202 the table). While everything is paused the canvas
holds the editor's bindings, and that is what the clone copies. The ordering note in
`src/cmdmode.tcl` was rewritten to say both halves: when the suspend comes, and in which
order the modes are released. Where the place of a mode cannot be read from what the
modes declare (a mode with no held callback, or one whose callback raises), that mode
waits for no other and no other waits for it; two such modes, and two modes that each
name the other's script, go in registration order. A stack of two whose order cannot be
read is therefore cloned as described above unless its upper mode was registered first.
(The last two sentences were reworded by the closing pass of issue 1724, 2026-11-19;
issue 0201 has the rule in full.)

Fences: band CR6 of `tests/headless/test_cmdmode_0201.tcl` and leg DS8 of
`tests/headless/test_cmdmode_descend_0201.tcl` (both binding tables against a baseline
and a control window, after two real ESC; since the closing pass also a descend in the
same window, rows DS8j to DS8q).
