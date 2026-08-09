# 0259 — the cadence_nav descend procs refuse without the ciw_echo every sibling proc gives

Status: **OPEN** — measured. Two distinct defects share one gate: (a) an *intended* silent
refusal that the spec argued for and that the rest of the file contradicts, and (b) a **false**
refusal on a selection that really is exactly one instance, caused by reading the sticky
`first_sel` memo. (b) is a plain bug with no policy question attached; (a) is a policy call, and
`doc/claude/specs/cadence_descend_newwin_ro.md:56-65` currently argues the other way (quoted below).
Area: `utils/cadence_nav.tcl` — `cadence::descend_into_inst()` (`:236-239`), `cadence::descend_into_inst_edit()` (`:243-247`), `cadence::descend_into_inst_newwin_ro()` (`:257-260`), gate `cadence::one_instance_selected()` (`:13-17`); bindings `src/cadence_style_rc:198` (Ctrl-X) and `:204` (Ctrl-Shift-X); the memo they read is `set_first_sel()` (`src/select.c:1117-1151`)
Tests: `tests/headless/test_cadence_descend_newwin_ro.tcl:38-54` already asserts both silent no-ops, but only over *state* (`llength [xschem windows]`, `currsch`, `schname`) — it never asserts the echo channel, and it stubs `ciw_echo` to a no-op at `:19`. So adding an echo does not turn it red. Nothing anywhere covers the message, and nothing covers the stale-memo refusal. Proposed `tests/headless/test_cadence_descend_echo_0259.tcl`
Found: 2026-08-08, in the descend silent-refusal census (`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0249](0249-descend-symbol-silently-refuses-any-multi-selection.md) and [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md) (the C-side multi-selection refusals this wrapper is the mirror image of), [0251](0251-a-refused-descend-has-no-return-channel.md) (these procs also discard the `0`/`""` they produce), [0203](0203-stale-sel_array-descends-a-deselected-instance.md) (the other "selection bookkeeping went stale" descend defect — same family, different array), [0200](0200-descend-has-no-verb-noun-pick.md) (the C/Tcl path that *does* speak up), [0019](0019-ctxmenu-b22-name-collision-breaks-right-click-menu.md) (the other cadence-profile-only descend defect). Specs: `doc/claude/specs/cadence_descend_newwin_ro.md`, `doc/claude/specs/cadence_bindkey_plan.md`, `doc/claude/specs/descend_readonly.md`.

## The defect

`utils/cadence_nav.tcl` (repo root `utils/`, **not** `src/utils/` — there is no such directory;
`src/cadence_style_rc:161-163` resolves it as `[file join [file dirname [info script]] .. utils]`)
holds three descend verbs. All three open with the same bare-`return` gate:

```tcl
utils/cadence_nav.tcl:236-260
# Ctrl-X: descend into selected instance's schematic; no-op if no instance selected.
# With descend_readonly set (the cadence default) this opens the child read-only.
proc cadence::descend_into_inst {} {
  if {![cadence::one_instance_selected]} { return }
  xschem descend
}
…
proc cadence::descend_into_inst_edit {} {
  if {![cadence::one_instance_selected]} { return }
  xschem descend
  cadence::make_editable
}
…
proc cadence::descend_into_inst_newwin_ro {} {
  if {![cadence::one_instance_selected]} { return }
  hi_descend target=new_window mode=readonly
}
```

The gate:

```tcl
utils/cadence_nav.tcl:12-17
# 1 iff exactly one instance (ELEMENT == type 8) is selected.
proc cadence::one_instance_selected {} {
  if {[xschem get lastsel] != 1} { return 0 }
  lassign [xschem get first_sel] type n col   ;# "type n col"
  return [expr {$type == 8}]
}
```

Those three procs are its **only** callers in the tree (`grep -rn one_instance_selected` finds
them plus the two spec documents), so the gate is descend-only: nothing else in the cadence
profile is subject to it, and nothing else in the cadence profile is mute.

Because the rest of the file is not. Every other proc that declines to act says so:

```tcl
utils/cadence_nav.tcl:211
      if {$lc eq {}} { ciw_echo "no library/cell (lib/cell) in the selected note" error ; return }
utils/cadence_nav.tcl:323-328
    if {[xschem select instance $name] == 0} {
      ciw_echo "instance '$name' not found while descending to $names" error ; return 0
    }
    if {[xschem descend] == 0} {
      ciw_echo "cannot descend into '$name'" error ; return 0
    }
```

and likewise at `:179`, `:204`, `:214`, `:219`, `:287`, `:306`, `:319`, `:337`, `:383`, `:390`
and `:395`. Fourteen refusal sites speak; the three descend verbs do not.
`cadence::make_editable` (`:266-271`) even
echoes on the *no-op* case ("already editable"). The file's house style is unambiguous, and the
descend verbs are the only violators of it.

**The inconsistency is older than the file.** `doc/claude/specs/cadence_bindkey_plan.md` proposed
both procs in one listing, with the same gate, one echoing and one not:

```tcl
doc/claude/specs/cadence_bindkey_plan.md:139-154
proc cadence::open_inst_sch_readonly {} {
  if {![cadence::one_instance_selected]} {
    ciw_echo "select one instance to open its schematic (read-only)" error ; return
  }
…
proc cadence::descend_into_inst {} {
  if {![cadence::one_instance_selected]} { return }
  xschem descend
}
```

**And the silence was later argued for explicitly**, which is why this is a policy call and not a
one-line oversight:

> `doc/claude/specs/cadence_descend_newwin_ro.md:58-65`
> The user wants a strict "one instance selected, else does nothing" (silent no-op, like
> Ctrl-X `descend_into_inst`). … Note this is stricter than bare `hi_descend`, which would
> descend into the *first* selected instance of several and would emit a CIW error on an empty
> selection. The gate makes the shortcut a clean silent no-op in every non-single-instance case.

The spec is accurate about the mechanism and states the trade openly. What it does not weigh is
that "does nothing" and "does nothing *and says nothing*" are separable, that the ten sibling
procs chose the other side, and that under (b) below the gate does not actually mean "not exactly
one instance".

### Ctrl-Shift-X is quieter than the thing it wraps

`hi_descend` resolves its target through `hi_descend_target_inst`, which *does* report an
unusable selection:

```tcl
src/xschem.tcl:5764-5772
  # Use the selected INSTANCES only (selected_set returns ELEMENT selections), so a
  # mixed rubber-band selection (instance + wires/text) still descends into the
  # instance, matching the old C descend's sel_array[0] behaviour. Descend into the
  # first selected instance when several are selected.
  set sel [xschem selected_set]
  if {[llength $sel] == 0} { ciw_echo "hi_descend: select an instance to descend into" error; return {} }
  return [lindex $sel 0]
```

`cadence::descend_into_inst_newwin_ro` refuses *before* reaching that line, so binding Ctrl-Shift-X
removes a message the user would otherwise have got. The wrapper is strictly less communicative
than the unwrapped command — measured as A1/A2 and C1/C2 below.

### The multi-selection asymmetry, stated precisely

With an instance **plus a wire** selected, `xschem descend` succeeds (it uses
`sel_array[0]`, and `descend_schematic()` only requires `sel_array[0].type == ELEMENT` —
`src/actions.c:3589-3593`, where the `lastsel != 1` half of the test is commented out in the
source). The cadence gate refuses it. So on the cadence profile Ctrl-X is the *only* place the
"exactly one" policy is enforced anywhere in the program — and it enforces it without a word.
Measured as B1/B2 below.

The asymmetry does **not** extend to instance + *text*: there `xschem descend` returns 0 too
(that is [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md)), so the
cadence gate merely adds a second silent refusal on top of a silent one. Do not write "the C core
always would have descended" — it depends on what the co-selected object is.

Nor does the C core help when the gate is bypassed: its own refusal is

```c
src/actions.c:3590-3592
 if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
   dbg(1, "descend_schematic(): wrong selection\n");
   return 0;
 }
```

`dbg(1, ...)` is below the default `debug_var == 0`, so it reaches neither stderr nor the GUI.
There is no channel at any layer.

### The false refusal (the part that is not a policy call)

`xschem get lastsel` calls `rebuild_selected_array()` before answering
(`src/scheduler.c:4394-4398`), so the count is fresh. `xschem get first_sel` does **not** — it
returns `xctx->first_sel` verbatim (`src/scheduler.c:3966-3971`), and that field is a *sticky
memo*: `set_first_sel()` stores only when the slot is empty and is cleared only by
`unselect_all()` and the delete paths:

```c
src/select.c:1145-1149
  } else if(xctx->first_sel.n == -1) {
    xctx->first_sel.type = type;
    xctx->first_sel.n = n;
    xctx->first_sel.col = col;
    dbg(1, "set_first_sel(): storing %d\n", n);
  }
```

Deselecting one object of several never revisits it. So the ordinary GUI sequence *click a wire →
shift-click the instance → shift-click the wire again to drop it* leaves `lastsel == 1` (the
instance) with `first_sel.type == WIRE (1)`, and the gate returns 0. Ctrl-X then refuses a
selection that is, by any user-visible reading, exactly one instance — and refuses it silently.
Measured as E below. This is [0203](0203-stale-sel_array-descends-a-deselected-instance.md)'s
failure mode with the polarity flipped: there stale bookkeeping descends into something the user
deselected; here stale bookkeeping refuses something the user did select.

### Two smaller corrections to the record

- **`cadence::descend_into_inst_edit` is not bound to anything.** The comment at `:241-242`
  says "Used by the canvas context menu", but the right-click **Descend schematic (edit)** item
  (`src/xschem.tcl:12626-12628`) sets `tctx::retval 22`, handled entirely in C:

  ```c
  src/callback.c:4512-4517
      case 22: /* descend schematic, then force editable (overrides descend_readonly) */
        if(descend_schematic(0, 1, 1, 1)) {
          xctx->readonly = 0;
          set_modify(-1); /* refresh title: clear the read-only marker */
        }
        break;
  ```

  — with `fallback=1, alert=1`, i.e. the *loud* variant. `doc/claude/specs/descend_readonly.md:37`
  is the accurate description: the Tcl proc is "the bindable equivalent", and
  `grep -rn descend_into_inst_edit` finds only its own definition and that spec sentence. Its
  severity is therefore latent, not live — but it is the template a user copies when binding a
  key, and its bail also skips `cadence::make_editable`, whose own echo (`:270`) consequently
  never fires either.
- **Return values are dropped twice over.** On the bail path each proc returns `""`; on the
  through path it returns whatever `xschem descend` / `hi_descend` produced (`1`, `0`). The
  bindings at `src/cadence_style_rc:198,204` discard all of it, so "refused by the gate",
  "refused by the core" and "descended" are indistinguishable to any caller — the wrapper-level
  instance of [0251](0251-a-refused-descend-has-no-return-channel.md).

## Reproduce

`ciw_echo` is a deliberate no-op without Tk (`src/ciw.tcl:113-115`: `if {![llength [info commands
winfo]] || ![winfo exists .ciw.l.t]} return`), so under `--nogui` *everything* is silent and the
channel is unobservable. The script below replaces `ciw_echo` with a printer before sourcing
`cadence_nav.tcl`, which makes the echo channel visible headlessly without touching the code
under test. Fixture: the existing `tests/headless/fixtures/hi_descend/hidlib` (top.sch with
instance `x1`, whose schematic view is `leaf.sch`).

```
$ ./src/xschem --nogui --pipe -q --nolog --script .../rep0259.tcl
== A1: nothing selected, cadence::descend_into_inst_newwin_ro (Ctrl-Shift-X)
  before: currsch=0 sch_path=. wins=1 name=top.sch
  ret=
  after : currsch=0 sch_path=. wins=1 name=top.sch
== A2: nothing selected, the thing it wraps: hi_descend target=new_window mode=readonly
  before: currsch=0 sch_path=. wins=1 name=top.sch
  CIW[error]: hi_descend: select an instance to descend into
  ret=0
  after : currsch=0 sch_path=. wins=1 name=top.sch
== B1: instance x1 + wire 0 selected, cadence::descend_into_inst (Ctrl-X)
  lastsel=2 first_sel=8 0 0
  ret=
  after : currsch=0 sch_path=. wins=1 name=top.sch
== B2: same selection, the thing it wraps: xschem descend
  lastsel=2 first_sel=8 0 0
  ret=1
  after : currsch=1 sch_path=.x1. wins=1 name=leaf.sch
== C1: one TEXT selected, cadence::descend_into_inst_newwin_ro
  lastsel=1 first_sel=16 0 0
  ret=
  after : currsch=0 sch_path=. wins=1 name=top.sch
== C2: same, hi_descend target=new_window mode=readonly
  lastsel=1 first_sel=16 0 0
  CIW[error]: hi_descend: select an instance to descend into
  ret=0
  after : currsch=0 sch_path=. wins=1 name=top.sch
== D: sibling proc for contrast -- cadence::descend_to_last with no memory
  CIW[error]: no remembered location for this window (use Alt-E first)
  ret=
done
```

A1/A2 and C1/C2 are the suppression: the wrapper is silent where the wrapped command speaks.
B1/B2 is the asymmetry: the cadence profile refuses a descend the core would have performed.
D is the control — a sibling refusal in the same file, through the same instrumented channel,
which prints.

The false refusal, same instrumentation:

```
== E: wire selected first, then x1, then the wire deselected
lastsel=1  first_sel=1 0 0
one_instance_selected -> 0
cadence::descend_into_inst -> ''  currsch=0 name=top.sch
xschem descend             -> '1'  currsch=1 name=leaf.sch
```

`lastsel == 1` and the one selected object *is* `x1`, yet `first_sel` still names wire 0 (type
`WIRE == 1`, `src/xschem.h:307`), the gate answers 0, and Ctrl-X does nothing and says nothing.
The very next line shows the core descending the identical selection.

Script (`xschem select … clear` is the scripted equivalent of shift-clicking a selected object
off):

```tcl
xschem load .../hidlib/top/schematic/top.sch
xschem unselect_all
xschem select wire 0 fast              ;# wire selected FIRST -> first_sel memo = WIRE
xschem select instance x1 fast
xschem select wire 0 fast clear        ;# deselect the wire; only x1 remains
```

**Not reproduced under a real `$DISPLAY`.** Everything above is the Tcl layer, which the GUI
reaches through the same procs via `src/cadence_style_rc:198,204`; the remaining GUI-only
variable is whether a real CIW window is open to receive the echo, which is exactly what the
fix has to make true.

## Fix, if it is to be closed

Three separable pieces, in increasing order of contention.

**1. The stale memo (do this regardless of the policy debate).** Stop deriving "which one object
is selected" from `first_sel`. `xschem selected_set` already returns the ELEMENT selections and is
rebuilt on demand — the same source `hi_descend_target_inst` uses (`src/xschem.tcl:5769`):

```tcl
proc cadence::one_instance_selected {} {
  return [expr {[xschem get lastsel] == 1 && [llength [xschem selected_set]] == 1}]
}
```

This keeps the policy identical for every case in the spec (empty → 0, instance+wire → `lastsel`
2 → 0, one text → `selected_set` empty → 0) while fixing E. Verify `selected_set`'s exact contract
before adopting it — it is used here only through `hi_descend`, and a second caller with different
expectations is a new coupling. Guard it with the E sequence as a headless case.

**2. One echo per bail**, in the file's own voice, naming the actual reason rather than the
generic one — the gate already knows which arm failed:

```tcl
proc cadence::one_instance_selected {{verb descend}} {
  set n [xschem get lastsel]
  if {$n == 0} { ciw_echo "$verb: select one instance first" error ; return 0 }
  if {$n != 1} { ciw_echo "$verb: select exactly one instance ($n objects selected)" error ; return 0 }
  if {[llength [xschem selected_set]] != 1} { ciw_echo "$verb: the selected object is not an instance" error ; return 0 }
  return 1
}
```

with the three call sites passing `Ctrl-X` / `Descend (edit)` / `Ctrl-Shift-X`. Note the
`return 0` values stay identical, so `tests/headless/test_cadence_descend_newwin_ro.tcl` keeps
passing untouched (it stubs `ciw_echo` at `:19` and asserts only state). If it should assert the
message too, un-stub it into a collector.

**3. Decide where "exactly one instance" lives.** Today the policy exists in exactly one place —
a Tcl proc in an opt-in profile — while the C core enforces only `sel_array[0].type == ELEMENT`
(`src/actions.c:3590`), with its `lastsel != 1` clause commented out in the source and a
`dbg(1)` for the failure. That split is why [0249](0249-descend-symbol-silently-refuses-any-multi-selection.md),
[0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md) and this issue are
three separate tickets describing one missing decision. Either the core adopts the strict rule
with an `alert`-gated message (and the profile wrapper deletes its gate entirely, becoming a
one-liner), or the core's permissive `sel_array[0]` rule is declared correct and the profile stops
overriding it. Do not fix the echo here and leave the policy split — it will drift again.

Also correct the stale comment at `utils/cadence_nav.tcl:241-242` ("Used by the canvas context
menu"): the context menu goes to `src/callback.c:4512` and never reaches that proc.

## Risks

- **The spec says the silence is wanted.** `doc/claude/specs/cadence_descend_newwin_ro.md:56-65`
  records a user preference for a clean silent no-op. Adding echoes without amending that section
  leaves the tree self-contradictory in the other direction. If the preference is real, the honest
  close for part 2 is a preference variable (`cadence_quiet_gate`) plus a spec amendment — not a
  silent reversal of a documented decision.
- **Echo volume.** Ctrl-X is a high-frequency browse key. An error line on every mis-aimed press
  fills the CIW pane fast; `error`-tagged lines are the ones a user scans for real problems. A
  neutral tag, or a statusbar message instead, may be the better channel — but the statusbar is
  itself unreliable for transient text, see
  [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md).
- **Behaviour change under Ctrl-X.** Loosening the gate (rather than only fixing the memo) would
  make Ctrl-X descend on a rubber-band selection that today does nothing, silently changing what a
  stray drag-then-Ctrl-X does. Part 1 above deliberately preserves the current accept/reject set
  for every case the spec enumerates; anything beyond that is part 3's decision.
- **Blast radius is bounded but not zero.** The profile is opt-in: `src/xschemrc:766-767` ships the
  hook commented out —

  ```
  #### redefine some variables to emulate Cadence UI / bindkeys
  # source /home/schippes/share/xschem/cadence_style_rc
  ```

  — so stock XSCHEM never loads `cadence_nav.tcl` and is unaffected by any change here. But
  `src/Makefile:198` installs `cadence_style_rc`, and this repo's own workflow is the cadence
  profile, so "opt-in" means "off for upstream users, on for the people who will hit this".
- **Instrumentation is not the GUI.** Every transcript above comes from a `ciw_echo` override.
  It proves which code paths reach an echo call; it does not prove the CIW pane is open and
  visible at the moment a user presses Ctrl-X. `ciw_echo` no-ops when `.ciw.l.t` does not exist
  (`src/ciw.tcl:114`), so an echo-only fix still says nothing to a user who has closed the CIW —
  a fourth silent-refusal surface that part 3 should weigh when choosing the channel.
