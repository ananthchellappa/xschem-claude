# 0256 — open_sub_schematic is a no-op with 2+ objects selected and ignores the descend it just asked for

Status: **OPEN** — both halves reproduced headless, plus two escalations found while reproducing
(a stale-window hijack that ends in data loss, measured; a semaphore path that is read-verified
only). Nothing here is a GUI-only claim except the visual perception of the orphan window.
Area: `src/xschem.tcl` `open_sub_schematic` (`:5660-5720`); the Alt+E arm `src/callback.c:6459-6465`;
`schematic_in_new_window()` `src/actions.c:2896-2942`; `copy_hierarchy_data()` `src/actions.c:2817-2889`;
`xschem select instance` result `src/scheduler.c:10718`; `xschem descend` result `src/scheduler.c:3006`
Tests: **none.** No file under `tests/` names `open_sub_schematic`. `tests/headless/test_hi_descend.tcl:151`
covers only the *guarded* sibling `hi_descend_newwin`. Proposed `tests/headless/test_open_sub_schematic_0256.tcl`
Found: 2026-08-08, in the descend silent-refusal census (`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md) (the same
"first ELEMENT in the selection" derivation, on the C side),
[0250](0250-failed-descend-strands-the-window-on-a-blank-child-page.md) (the blank-page state this
proc reports as success), [0251](0251-a-refused-descend-has-no-return-channel.md) (the discarded
`"0"`), **0253** "the semaphore threshold disagrees across Tcl and C" (filed in the same census
batch; the `semaphore == 0` gate the inner `xschem descend` sits behind). Pre-existing:
[0203](0203-stale-sel_array-descends-a-deselected-instance.md) (the stale `sel_array[0]` that the
`xschem descend` at `:5710` reads after a *failed* `select instance`),
[0035](0035-descended-new-window-spuriously-modified.md) and
[0037](0037-newwin-descend-desync-and-exit-confusion.md) (the new-window descend desync this proc
already carries workarounds for), [0053](0053-descend-new-window-return-should-navigate-window-chain.md)
(the parent↔child window link a failed descend never establishes),
[0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md) (any status
message a fix emits here has to survive the coordinate readout).

## The defect

`open_sub_schematic` is the whole implementation of **File → "Open selected schematic in new
window"** (`src/actions.csv:47`, registry id `file.open_sub_sch`) and of **Alt+E / Super+E**
(`src/callback.c:6459-6465`). Nothing else implements that operation. It is called with **no
arguments** from both:

```c
src/callback.c:6459-6465
      else if(EQUAL_MODMASK) { /* edit schematic in new window */
        int save = xctx->semaphore;
        xctx->semaphore--; /* so semaphore for current context wll be saved correctly */
        /*  schematic_in_new_window(0, 1, 0); */
        tcleval("open_sub_schematic");
        xctx->semaphore = save;
      }
```

`tcleval()` returns `const char *` (`src/xschem.h:2933`) and the return value is dropped on the
floor here; the menu path discards it too (a Tk `-command` result goes nowhere). So whatever this
proc returns, no caller in the tree looks at it —
[0251](0251-a-refused-descend-has-no-return-channel.md).
(Alt+E reaches the C arm because `%s & 0x4c` includes `Mod1Mask`; the Tcl `<Key-e>` interceptor at
`src/xschem.tcl:14175` forwards modified `e` to `xschem callback` — `hi_descend_keybind_script`,
`:6271-6273`. The `accel` column in `actions.csv` is display-only, `src/action_registry.tcl:14`.)

### (a) 2+ objects selected: the proc returns before it does anything

```tcl
src/xschem.tcl:5669-5686
  if { $inst eq {} && $n_sel == 0} {
    if {$search_schematic == 1} {
      set f [abs_sym_path [xschem get current_name] {.sch}]
    } else {
      set f [file rootname [xschem get schname]].sch
    }
    xschem new_schematic create {} $f
    return 1
  } elseif { $inst eq {} && $n_sel == 1} {
    set inst [lindex [xschem selected_set] 0]
    xschem unselect_all
  } else {
    set instlist {}
    # get list of instances (instance names only)
    foreach {i s t} [xschem instance_list] {lappend instlist $i}
    # if provided $inst is not in the list return 0
    if {[lsearch -exact $instlist $inst] == -1} {return 0}
  }
```

The `else` arm was written for the **argument** form (`open_sub_schematic x1`), where `$inst` is a
caller-supplied name to validate. But the arm is also where control lands for `$inst eq {}` with
`$n_sel >= 2`, and there `$inst` is still the empty string: `lsearch -exact $instlist {}` is `-1`,
so the proc returns 0 having created nothing, selected nothing and said nothing. No
`statusmsg`, no `ciw_echo`, no `alert_`, no stderr — a **silent refusal** by the census definition.

The user perceives: rubber-band a region, hit Alt+E (or the File menu item), **nothing happens at
all** — no window, no tab, no message, no flicker. The obvious diagnosis ("I must have missed the
symbol") is wrong; a rubber band over an instance and one attached wire is exactly the input that
kills it.

The inconsistency is the sharp part: **plain descend accepts the identical selection.**
`descend_schematic()` only inspects `sel_array[0]` (`src/actions.c:3590-3593`), and
`rebuild_selected_array()` orders instances first, so `e` descends where Alt+E is dead. Measured
below.

**Single non-instance selection is worse, not better.** `xschem selected_set` reports **only
ELEMENT** selections (`src/scheduler.c:11026-11029`), so with one wire (or one text, or one rect)
selected the `$n_sel == 1` arm sets `$inst` to `{}` via `lindex {} 0`, calls `xschem unselect_all`
— and then *falls through into the whole window-creating body with an empty instance name*.
`schematic_in_new_window` now sees `lastsel == 0`, takes its duplicate-the-current-sheet branch
(`src/actions.c:2902-2917`) and returns 1; `xschem select instance {} fast` fails (`get_instance("")`
→ `isonlydigit("")` is 0 and no instname matches, `src/scheduler.c:187-211`; the command returns
the string `"0"` at `src/scheduler.c:10718` rather than raising); `xschem descend` no-ops; and the
proc **returns 1**. Net effect: you asked to open a wire's schematic and got a second window on the
sheet you were already looking at, reported as success.

### (b) the descend result is discarded, after the window already exists

```tcl
src/xschem.tcl:5693-5697
  set res [xschem schematic_in_new_window force]
  set new_window_path [xschem get last_created_window] ;# something like .x1.drw
  xschem copy_hierarchy $current_win_path $new_window_path
  # if successfull descend into indicated sub-schematic
  if {$res} {
```

```tcl
src/xschem.tcl:5709-5719
    xschem select instance $inst fast
    xschem descend
    # In window mode the just-created window has not settled to its real size, so the
    # descend's zoom_full used a transient geometry (blank / off-screen until F). A new tab
    # shares the already-sized main canvas, so skip it there. issue 0035/0037.
    if {!([info exists ::tabbed_interface] && $::tabbed_interface)} {
      newwin_defer_fullzoom $new_window_path
    }
    return 1
  }
  return 0
```

`xschem descend` *does* return a status (`src/scheduler.c:3006`, `Tcl_SetResult(interp, dtoa(ret), …)`),
and `xschem select instance` returns `"1"`/`"0"` (`src/scheduler.c:10718`). Neither is read. The
`return 1` is unconditional on everything that happened after the window was created, so the proc
reports success for:

- an instance whose symbol is not `subcircuit`/`primitive` (`src/actions.c:3620-3624`) — the window
  is created, the descend refuses, the window stays on the **parent**;
- a descend whose child file fails to load — the window stays on a blank page,
  [0250](0250-failed-descend-strands-the-window-on-a-blank-child-page.md);
- the empty-`$inst` fall-through of (a) above, where the failed `xschem select instance {}` leaves
  `xctx->lastsel == 0` and `xschem descend` then reads a stale `sel_array[0]`
  ([0203](0203-stale-sel_array-descends-a-deselected-instance.md)) — which is why the outcome of
  that arm depends on what was selected *before*, not on what the user did.

**The window is not torn down.** Nothing in the failure path destroys it, and the proc has already
switched the active context into it at `:5699`. In tabbed mode the user is left staring at a new
tab showing the sheet they came from; in window mode at a new toplevel doing the same. Either way
it is a resource the user must close by hand — a leak in the ordinary sense, and one the user has
no reason to expect since they asked to *descend*, not to duplicate. (Headless the extra context is
observable; the visual perception is stated from the state, not from a GUI session.)

### (c) escalation, found while reproducing: `copy_hierarchy` runs before `$res` is checked

`:5694-5695` read `last_created_window` and copy the hierarchy into it **before** the `if {$res}`
at `:5697`. `last_created_window` is a `static int` in `src/xinit.c:54`, only ever assigned on a
*successful* create (`:2012`, `:2168`) and never reset — so when nothing was created it names a
**previously created, unrelated window**, and `copy_hierarchy_data()` writes into that window's
context: `to->currsch = from->currsch` plus `to->sch[i]` / `to->sch_path[i]` / `zoom_array` /
`hier_attr` / `portmap` (`src/actions.c:2851-2887`).

The victim window keeps its loaded objects but adopts the source window's *identity*. A save there
writes the wrong cell. Two reachable routes:

1. **Bare Alt+E, window table full.** `new_schematic` refuses at `*window_count + 1 >= MAX_NEW_WINDOWS`
   (20, `src/xschem.h:158`) and `return`s void (`src/xinit.c:1999-2001` for windows, `:2150-2151`
   for tabs), but `schematic_in_new_window` returns 1 unconditionally from that branch
   (`src/actions.c:2916`). So `$res` is 1, `new_window_path` is the stale `.x19.drw`, and the proc
   clobbers it, switches into it, and runs the select+descend there. The refusal itself does print
   `no more free slots` via `dbg(0,…)` — visible to a terminal-launched user, invisible to a
   desktop-launched one — but the hijack and the wrong-identity window are silent on every channel,
   and the proc returns 1.
2. **`open_sub_schematic <inst>` with 2+ selected.** `schematic_in_new_window` returns 0 for
   `lastsel > 1` (`src/actions.c:2918-2920`), and `:5695` has already fired by then.

The guarded sibling 250 lines below gets this exactly right, and its comment names the hazard:

```tcl
src/xschem.tcl:5948-5952
  # Check the open result BEFORE touching last_created_window: on failure it is a stale
  # prior window, and copy_hierarchy into it would clobber that window's hierarchy path.
  if {!$res} { ciw_echo "hi_descend: could not open a new window/tab" error; return 0 }
  set new_window_path [xschem get last_created_window]
  xschem copy_hierarchy $current_win_path $new_window_path
```

`hi_descend_newwin` was hardened; `open_sub_schematic` — the one the File menu and Alt+E actually
run — was not.

## Reproduce

Fixture `tests/headless/fixtures/descend/`: `descend_parent.sch` = one wire `N 200 200 300 200` +
one instance `C {descend_child.sym} 0 0 0 0 {name=x1}`; `descend_child.sch` = three wires;
`descend_child.sym` carries `type=subcircuit`. All transcripts below are verbatim from
`src/xschem --nogui --pipe -q --nolog --script <script>` on the working tree, with the two
boilerplate startup lines (`Using run time directory…`, `Sourcing …xschemrc…`) elided.

**(a) 2+ selected — Alt+E is dead, `e` is not.**

```tcl
xschem load $work/descend_parent.sch
xschem unselect_all; xschem select instance 0; xschem select wire 0
puts "  lastsel=[xschem get lastsel] -> descend=[xschem descend] schname=…"
```
```
== plain 'xschem descend' with the SAME 2-object selection Alt+E refuses ==
  lastsel=2 -> descend=1  schname=descend_child.sch currsch=1
== same, wire selected first ==
  lastsel=2 -> descend=1  schname=descend_child.sch currsch=1
== rubber-band-equivalent: select_inside over everything ==
  select_inside rc=<> lastsel=2 selected_set=<{x1}>
  open_sub_schematic -> 0
  after: win=.drw schname=descend_parent.sch
```

`xschem select_inside -1000 -1000 1000 1000` is the scripted twin of a rubber band over the sheet:
`lastsel=2`, `selected_set` finds `x1` perfectly well, `xschem descend` would succeed — and
`open_sub_schematic` returns 0 without creating a window or emitting a byte.

**(b) single non-instance selection — a duplicate window reported as success.**

```
== B: single WIRE selected ==
  selected_set=<>  lastsel=1
  rc=0  result=<1>
  after: schname=descend_parent.sch currsch=0 lastsel=0 win=.x2.drw last_created=.x2.drw
```

**(b′) single non-subcircuit instance — the orphan window, GUI-reachable with no arguments.**
Fixture: a `nosub.sym` carrying `type=label` instanced as `l1`.

```
== single NON-SUBCIRCUIT instance selected, Alt+E (no args) ==
  lastsel=1 selected_set=<{l1}>
  open_sub_schematic -> 1
  now in win=.x1.drw schname=nosub_parent.sch currsch=0
  windows open: 0 <1>
== control: plain descend on the same selection ==
  xschem descend -> 0  schname=nosub_parent.sch currsch=0
```

(`windows open: 0 <1>` is `[catch {xschem new_schematic ntabs} o]` — rc 0, one extra context.)
`xschem descend` returns 0; `open_sub_schematic` returns 1; the extra context exists and shows the
parent. This is the ordinary "I clicked a resistor and hit Alt+E" case.

**(c1) window table full — bare Alt+E hijacks `.x19.drw`.**

```
  create #18 -> r=19 last_created=.x19.drw
new_schematic("new_tab"...): no more free slots
  create #19 -> r=19 last_created=.x19.drw
  … (repeats)
last_created_window now = .x19.drw
state of .x19.drw BEFORE: schname=descend_child.sch currsch=0 wires=3 insts=0
new_schematic("new_tab"...): no more free slots
Alt+E from .drw with x1 selected -> open_sub_schematic = 1
  we are now in win=.x19.drw schname=descend_parent.sch currsch=0 wires=3 insts=0
```

`.x19.drw` still holds `descend_child`'s three wires but now reports `schname=descend_parent.sch`.
Focus was moved into it. Return value: 1.

**(c2) the same clobber via the argument form, then the data loss.**

```
  new window .x1.drw after legit Alt+E win=.x1.drw schname=descend_child.sch currsch=1 wires=3 insts=0
  victim .x1.drw after the FAILED Alt+E win=.x1.drw schname=descend_parent.sch currsch=0 wires=3 insts=0
  parent file on disk before save:
  v {xschem version=3.4.4 file_version=1.2} | G {} | V {} | S {} | E {} | N 200 200 300 200 {} | C {descend_child.sym} 0 0 0 0 {name=x1} |
  parent file on disk AFTER 'xschem save' in .x1.drw:
  v {xschem version=3.4.8RC file_version=1.3} | G {} | K {} | V {} | S {} | F {} | E {} | N 0 -100 0 0 {} | N 0 0 100 0 {} | N -100 0 0 0 {} | N 500 500 600 500 {} |
```

Sequence: a legitimate Alt+E creates `.x1.drw` in the child; back in `.drw`, `open_sub_schematic x1`
with two objects selected returns 0 but has already run `copy_hierarchy .drw .x1.drw`; `.x1.drw` now
believes it is `descend_parent.sch`; a wire is added there and `xschem save` writes the **child's**
contents over `descend_parent.sch`. The parent's instance and wire are gone. `(c2)` needs the
argument form, so it is script/rc-reachable rather than menu-reachable; `(c1)` needs no argument
and is the menu path.

**Not reproduced:** the semaphore route. `xschem descend` only acts when `xctx->semaphore == 0`
(`src/scheduler.c:2973`); `callback()` raises the semaphore at `src/callback.c:8920` and the Alt+E
arm compensates with a single `--` at `:6461`. Unlike the `rstate == 0` and `ControlMask` arms
(`:6452`, `:6456`), the `EQUAL_MODMASK` arm carries **no** `if(xctx->semaphore >= 2) break;`, so in
a recursive callback the decrement lands on 1, the inner `xschem descend` is skipped by the gate,
and the proc still creates a window and returns 1. Read-verified in the source; not driven to
a measured transcript — a recursive callback is not reachable from `--nogui --script`. See
0253.

## Fix, if it is to be closed

Four changes, all inside `open_sub_schematic`; none of them touch C.

1. **Derive `$inst` once, from the first selected ELEMENT, independent of `$n_sel`** — the same
   rule `descend_schematic()` uses via `sel_array[0]`, and the same rule
   [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md) wants on the C side. Collapse the `n_sel == 1`
   and `else` arms:

   ```tcl
   if {$inst eq {}} {
     set inst [lindex [xschem selected_set] 0]     ;# ELEMENT selections only
     if {$inst eq {}} {
       statusmsg_hold "Open in new window: select an instance first" 1
       return 0
     }
     xschem unselect_all
   } else {
     …existing instlist validation, with a message on the -1 branch…
   }
   ```

   This makes Alt+E behave like `e` for every mixed selection, and turns the wire-only case from a
   spurious duplicate window into a refusal with a reason.

2. **Move the `$res` check above `last_created_window`** — lift `src/xschem.tcl:5948-5950`
   verbatim from `hi_descend_newwin`. That closes (c2) outright.

3. **Make `$res` mean what it claims.** (c1) survives step 2 because `schematic_in_new_window`
   returns 1 from a branch whose `new_schematic()` may have done nothing. Either propagate the
   failure in C (`src/actions.c:2902-2917`; `new_schematic` is `void` for the create verbs, so this
   needs a return value or a `get_window_count()` delta), or defend in Tcl by comparing
   `[xschem get last_created_window]` against the value captured *before* the call and treating
   "unchanged" as failure. The C fix is the honest one; the Tcl guard is the one that can ship
   today.

4. **Check the descend and report.** Replace `:5709-5710` with

   ```tcl
   if {![xschem select instance $inst fast]} { … }
   if {![xschem descend]} { … }
   ```

   and on failure: switch back to `$current_win_path`, `xschem new_schematic destroy $new_window_path`
   (the verb shape used at `src/scheduler.c:3286`), skip `newwin_defer_fullzoom`, and `return 0`
   with a `statusmsg_hold`. The message is the only channel that exists — both callers discard the
   return value ([0251](0251-a-refused-descend-has-no-return-channel.md)) — and it must be a *held*
   message or the coordinate readout eats it ([0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)).

Longer-term, `doc/claude/specs/hi_descend.md:243-245` already records the right answer: this proc
and `hi_descend_newwin` are duplicates and one should call the other. Fixing this issue by deleting
`open_sub_schematic`'s body in favour of `hi_descend_newwin` would close (a), (b) and (c) at once —
but it changes Alt+E's semantics (view enumeration, read-only mode, the 0053 window link), so it is
a separate decision, not this fix.

## Risks

- **Tearing down the new window mid-flight.** By the time the descend result is known the proc has
  already run `xschem new_schematic switch $new_window_path` (`:5699`), `xschem copy_hilights`
  (`:5698`) and possibly `newwin_restore_unsaved` (`:5700`) and a raw reload (`:5701-5708`).
  Destroying that context requires switching back first, and `newwin_defer_fullzoom` must not be
  scheduled against a path that is about to disappear (`:5714-5716`, the 0035/0037 workaround).
  Getting the order wrong trades a leaked window for a dangling `after` on a dead window path.
- **The autosave bridge fires before any decision.** `newwin_capture_unsaved` at `:5667` runs
  `xschem backup write` unconditionally when the parent is modified (`:5645-5649`). A refusal added
  in step 1 returns *after* that write, so a `<cell>~.sch` exists for an operation that never
  happened. Pre-existing, but a teardown path makes it observable — move the capture below the
  `$inst` derivation.
- **Behaviour change for the duplicate-window habit.** Today a single wire/text selection silently
  duplicates the current sheet in a new window and returns 1. Step 1 turns that into a refusal.
  The genuinely-nothing-selected case (`:5669-5676`) is a different, documented arm and is
  untouched — but anyone who has been selecting a wire and pressing Alt+E to clone a view will see
  a behaviour change.
- **`instance_list` cost.** The `else` arm builds the full instance-name list to answer one
  membership question (`:5681-5683`). On a large sheet that is a linear scan per Alt+E; the
  name-addressed C helper `get_instance()` (`src/scheduler.c:187`) already answers it in one call
  and is what `xschem descend -inst` uses. Not a correctness risk, but the validation should move
  to `xschem select instance $inst` and read its result.
- **No coverage anywhere.** Nothing under `tests/` exercises `open_sub_schematic`, so every change
  above is currently unguarded. The proposed test needs the `--nogui` window/tab machinery, which
  works (all transcripts above ran that way), including the 19-window exhaustion case — that one is
  slow but deterministic.
- **`copy_hierarchy_data` has no self-copy guard.** `xschem copy_hierarchy .x2.drw .x2.drw` is
  accepted and emits `my_strdup2(): WARNING: src == *dest` (observed in the (c2) run). Harmless
  here, but it is the tell that the from/to paths were never validated; a guard at
  `src/actions.c:2837-2843` would have made (c) fail loudly years ago.
