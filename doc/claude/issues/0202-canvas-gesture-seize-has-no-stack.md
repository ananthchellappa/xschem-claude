# 0202 — canvas Button-1 and Escape are single ownership slots with no stack, so no pick mode can nest inside another

Status: **OPEN**, and **no longer a blocker** — see "0201 shipped without it" below.
Filed 2026-08-01, spawned by [0201](0201-no-command-suspend-resume-contract.md) on the
reasoning that it was 0201's mechanical blocker. Established by reading; the defect itself
is still **not measured** (no reproducer for the LIFO violation), but the hand-back
invariant it rests on now *is* — see the same section.
Area: `src/ase_window.tcl` (`select_on_design` 1595-1602, `sod_end` 1644-1646),
`src/xschem.tcl` (`addpin::grab_esc` / `release_esc` 10817-10820,
`addlabel::grab_esc` / `release_esc` 11159-11162, the `<ButtonRelease>` drop hooks
10704-10709 / 11072, `set_bindings` 13892), `src/create_instance.tcl` (56-61),
`src/callback.c` (`abort_operation` 246, `case XK_Escape` 6918).
Tests: none yet.
Related: [0200](0200-descend-has-no-verb-noun-pick.md),
[0201](0201-no-command-suspend-resume-contract.md), 0122 E2/F3 (the ESC-slot hand-back that
established the current scheme).

## The defect

Three different subsystems arbitrate the same handful of canvas binding slots, and every
one of them arbitrates by **overwrite + remember one predecessor**:

```tcl
# src/ase_window.tcl:1595-1602 — ASE Select-On-Design
set sod($key,prevpress) [bind $cv <ButtonPress-1>]
set sod($key,prevrel)   [bind $cv <ButtonRelease-1>]
set sod($key,prevesc)   [bind $cv <Key-Escape>]
bind $cv <ButtonPress-1>   "[list ase::ui::sod_click $key]; break"
bind $cv <ButtonRelease-1> {break}
bind $cv <Key-Escape>      "[list ase::ui::sod_end $key]; break"
```

```tcl
# src/xschem.tcl:10817-10820 — the Add-Pin / Add-Wire-Label ESC slot (issue 0122 E2)
proc addpin::grab_esc    {} { bind .drw <Key-Escape> {if {[winfo exists .addpin]} {addpin::escape; break}} }
proc addpin::release_esc {} { if {[winfo exists .addlabel]} { addlabel::grab_esc } else { bind .drw <Key-Escape> {} } }
```

Each stores **one** predecessor. Two consequences:

1. **Nesting is unsafe.** If B seizes while A holds the slot, B records A's script as its
   predecessor. If A then ends first, A restores *its* remembered predecessor over B's
   live binding — B is silently disarmed, and B's teardown later restores A's script over
   whatever is current. LIFO is assumed but never enforced.
2. **A mode cannot be paused.** There is no "hold the slot for me and give it back" — only
   "take it" and "put back the one thing I remember". This is exactly what
   [0201](0201-no-command-suspend-resume-contract.md) needs and cannot have.

`addpin`/`addlabel` avoid (1) by hand: `release_esc` explicitly hands the slot to the
sibling form if it still exists. That is a two-party special case written out longhand, not
a mechanism, and ASE is not party to it.

## Two aggravating facts

**The slot is `.drw` only.** The Add-Pin/Add-Label mechanism targets the main canvas by
name and says so:

```tcl
# src/xschem.tcl:10813-10816
# SCOPE (0122-F3): like the whole form mechanism ... this targets the MAIN window canvas `.drw` only --
# not a detached window / non-first tab (`.xN.drw`). Pre-existing single-canvas assumption.
```

ASE, by contrast, seizes `[xschem get current_win_path]` — whichever canvas is current
*at arm time*. Two subsystems, two different notions of "the canvas", and a descend into a
new window/tab changes which one is current.

**`break` is load-bearing.** Every seized script ends in `break` so the generic
`bind $topwin <ButtonPress>` / `<KeyPress>` → `xschem callback` route
(`xschem.tcl:13944-13953`) never fires. A seize that forgets `break` double-dispatches; a
restore that loses the `break` silently re-enables the C path underneath a live mode. The
correctness of the whole scheme rides on string-identical restore.

## Decisions

### D1 — a real stack, keyed per (canvas, sequence) — proposed, not decided
`gestures::push <canvas> <seq> <script> <token>` / `gestures::pop <token>`, where `pop`
of a non-top token is either an error or reorders explicitly. Small, new file, no
behaviour change for a single owner. The existing three call sites migrate one at a time.

### D2 — scope: `.drw`-only or per-canvas? → **per-canvas**
Keying on the widget path costs nothing and removes the 0122-F3 single-canvas assumption
for free. `addpin`/`addlabel` can keep passing `.drw` until someone fixes them.

### D3 — does this need C? → **no**
Pure Tcl. The C side already has its own mode teardown (`abort_operation()`,
`callback.c:246`) and its own ESC arm (`callback.c:6918`), and neither is displaced by
Tk-level seizes — the `break` is what keeps them apart.

### D4 — is this worth fixing on its own merits? — OPEN, and now the *only* question
Standalone, it is a latent hazard with no known user-visible symptom (nobody has reported
ASE and Add-Pin fighting). The claim that it "becomes mandatory the moment 0201 is
attempted" was **wrong**, and 0201 shipping without it is the proof — see below. So this
issue now stands or falls purely on its own merits, which is the honest place for it.

## 0201 shipped without it (2026-08-01)

The blocker reasoning was: a descend pick would have to **nest** above ASE's live Button-1
seize, and the slots hold one predecessor each.

The pick does not nest. `hi_descend_pick_arm` calls `cmdmode::suspend_all` **before**
`xschem descend_pick`, so SOD has already handed the canvas back by the time the pick is
armed. The two owners are strictly sequential; each slot still only ever has one occupant.
A stack would have been dead weight on that path.

Two things this changes for *this* issue:

**The hand-back invariant is now measured.** `tests/headless/test_cmdmode_descend_0201.tcl`
legs `CS3a`-`CS3c` assert that suspending a seized mode restores all three slots
**string-identically**, trailing `break` included — the exact property the "`break` is
load-bearing" section says the whole scheme rides on, previously asserted by nobody. Any
future stack must keep those legs green.

**A third aggravating fact, found while doing 0201.** `clone_canvas_bindings`
(`xschem.tcl:13897`) copies `.drw`'s bindings verbatim onto every new canvas at creation
(`xinit.c:2036`, `2252`), and `set_bindings` binds only the *generic* `<ButtonPress>` /
`<ButtonRelease>` / `<KeyPress>` — never `<ButtonPress-1>`, `<ButtonRelease-1>` or
`<Key-Escape>`. So a seize that is live when a window or tab is created is **cloned onto
the child with the owner's key already substituted**: clicks there queue into the parent's
mode, but the child's ESC calls a `sod_end` that restores bindings on the *parent* canvas
only, leaving the child permanently seized with dead scripts. 0201 dodges this by
suspending before any window is created (leg `DS6d` pins it), but a per-canvas stack (D2)
has to handle it head-on: `push` must not inherit a cloned foreign script as its
"predecessor".

## Merge note

Everything proposed here is a new file plus three small call-site swaps. `ase_window.tcl`
(12 touches in the last 80 `fluid-editing` commits) and `xschem.tcl` (9) are both active;
keeping the mechanism out of them and the edits to three-line replacements is the whole
point.

## Cross-references

* `doc/claude/issues/0201-no-command-suspend-resume-contract.md` — the consumer.
* `doc/claude/issues/0200-descend-has-no-verb-noun-pick.md` — the pick that must nest.
* `doc/claude/specs/ase_l.md` — Select-On-Design's seize/restore.
