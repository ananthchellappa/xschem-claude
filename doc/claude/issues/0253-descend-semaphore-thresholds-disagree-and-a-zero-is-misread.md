# 0253 — the descend re-entrancy threshold differs between Tcl and C, and the resulting 0 is misread as a blank schematic

Status: **OPEN** — both halves measured headless (transcripts below). What is *not* measured is a
real keystroke landing at `semaphore == 1`: `xschem callback` segfaults under `--nogui` (no window),
and the GUI keystroke path is established here by reading the dialog code, not by a keystroke test.
Area: `src/scheduler.c` `descend` (`:2973`, result at `:3006`), `descend_symbol` (`:3018`, result at `:3035`), `go_back` (`:5472`); `src/callback.c` `case 'e'` (`:6452`), `case 'i'` (`:6589`); `src/xschem.tcl` `hi_descend` (`:6044`), `hier_traversal` (`:3717-3725`); `src/actions.c` `descend_schematic()` (`:3575`); `src/xschem.h` `int semaphore;` (`:1604`, undocumented)
Tests: none. `tests/headless/` drives the semaphore at **2 only** — `test_accelerators.tcl:68`, `test_key_graph_context.tcl:341/348/377`, `test_action_log_dispatch.tcl:41` — so the entire `semaphore == 1` band is untested. Proposed `tests/headless/test_descend_semaphore_0253.tcl`
Found: 2026-08-08, in the descend silent-refusal census (`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0203](0203-stale-sel_array-descends-a-deselected-instance.md) (the *other* reason `descend`'s answer cannot be trusted — a stale `sel_array[0]` makes it return 1 with nothing selected; measured again while writing this issue), [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md) (any statusbar cure proposed below must survive the coordinate readout), [0035](0035-descended-new-window-spuriously-modified.md) / [0037](0037-newwin-descend-desync-and-exit-confusion.md) / [0053](0053-descend-new-window-return-should-navigate-window-chain.md) / [0054](0054-descend-return-context-pointer-desync.md) / [0060](0060-descend-from-untitled-loses-parent-content-on-ascend.md) / [0073](0073-hilight-not-synced-into-linked-descend-new-window.md) (descend / new-window family), [0200](0200-descend-has-no-verb-noun-pick.md) (verb-noun pick, RESOLVED), [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md).
Census siblings filed in the same batch, not yet linkable by path: **0250** (a failed descend with `alert=0` strands the window on a blank child page — the *only* case half (b)'s comment actually describes), **0251** (a refused descend has no return channel; `"0"` and `""` are discarded at every caller — the protocol half of the fix below), **0261** (descend reports success on a blank page).

## The defect

Two independent bugs that meet on the same integer.

### (a) The two surfaces disagree about how busy is too busy

`xctx->semaphore` is xschem's re-entrancy counter. Nothing in `src/xschem.h` documents it — the
field is a bare `int semaphore;` at `:1604` — and the two halves of the program have settled on
different thresholds.

The **Tcl surface** demands `== 0`. Both descend branches wrap their entire body in the guard and
neither has an `else`:

```c
src/scheduler.c:2968-3006
    else if(!strcmp(argv[1], "descend"))
    {
      int ret=0;
      int set_title = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->semaphore == 0) {
        …
      }
      Tcl_SetResult(interp, dtoa(ret), TCL_VOLATILE);
    }
```

`ret` is initialised to 0 at `:2970` and never touched when the guard fails, so a refusal is
indistinguishable from `descend_schematic()` having run and returned 0. The symbol twin is worse —
it has no `ret` at all:

```c
src/scheduler.c:3015-3036
    else if(!strcmp(argv[1], "descend_symbol"))
    {
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(xctx->semaphore == 0) {
        …
        descend_symbol();
      }
      Tcl_ResetResult(interp);
    }
```

so *every* outcome, refused or not, is the empty string.

The **C key handlers** demand only `>= 2`:

```c
src/callback.c:6450-6454
    case 'e':
      if(rstate == 0) { /* descend to schematic */
        if(xctx->semaphore >= 2) break;
        descend_schematic(0, 1, 1, 1);
      }
```

```c
src/callback.c:6587-6591
    case 'i':
      if(rstate==0) { /* descend to  symbol */
        if(xctx->semaphore >= 2) break;
        descend_symbol();
      }
```

and so does the Tcl chooser, with a bare `return` (not `return 0`, so scripted callers get `""`):

```tcl
src/xschem.tcl:6043-6045
proc hi_descend {args} {
  if {[xschem get semaphore] >= 2} return
  if {![llength $args]} { return [hi_descend_dialog] }
```

Note which of these is the *default* `e`. `src/xschem.tcl:14175` binds `<Key-$hi_descend_key>`
(default `e`) to `hi_descend_keybind_script`, whose body
(`src/xschem.tcl:6272`) is
`{if {[expr {%s & 0x4c}]} {xschem callback %W %T %x %y %N 0 0 %s} else {hi_descend}; break}` —
plain `e` runs the Tcl chooser and only a Ctrl/Alt/Super chord reaches `case 'e'`. Descend-symbol
(`i`, `src/callback.c:6587`) is the raw C path.

**The gap is `semaphore == 1`.** The `>= 2` guards let the chooser open and run to completion; the
`== 0` guard then throws away the descend it asked for. Nothing tells the user: `hi_descend_finish`'s
schematic branch has no failure arm at all —

```tcl
src/xschem.tcl:5881-5888
  } else {
    if {![hi_descend_is_default_sch $instname $vpath]} {
      set ::hi_descend_view_path $vpath        ;# one-shot, consumed by get_sch_from_sym
    }
    set ok [xschem descend $iter]
    set ::hi_descend_view_path {}              ;# belt-and-suspenders if descend bailed early
  }
  if {$ok} {
```

— no `ciw_echo`, no `statusmsg`, and on the C side `descend_schematic()` is never entered, so not even
its `dbg()` lines run. **The user picks a view, presses OK, the dialog closes, and the schematic on
screen does not change.**

**Where the semaphore is exactly 1.** Confirmed by reading the increment sites and checking each for
a Tk grab (a grabbing dialog takes the keyboard, so the canvas binding cannot fire; a non-grabbing
one leaves the canvas fully live):

| site | pump | grab? | canvas live at sem==1 |
|---|---|---|---|
| `edit_property(0)` `src/editprop.c:1643-1647` → `text_line` → `text_line_legacy` | `tkwait window .dialog` (`src/xschem.tcl:11701`) | **no** — `#grab set .dialog` is commented out at `src/xschem.tcl:11697` | yes |
| `edit_rect_property` `src/editprop.c:279-283`, `edit_line_property` `src/editprop.c:395-397` | same | same | yes |
| `simulate` (foreground simulator) `src/xschem.tcl:4076` … `4093-4097` | `vwait execute(pipe,$id)` | no | yes |
| `waves` `src/xschem.tcl:4240-4244` | `vwait` | no | yes |
| `execute_wait` `src/xschem.tcl:328-338` | `vwait` | no | yes |
| `color_dim` `src/xschem.tcl:9503-9521` | `tkwait window .dim` | no | yes |
| `inutile … wait` `src/xschem.tcl:147` / `203-205` | `tkwait window .inutile` | no | yes |
| `input_line` `src/xschem.tcl:12440-12477` | `tkwait window .dialog` | **yes** (`:12474`) | no |
| `attach_labels_to_inst` `src/xschem.tcl:9718-9766` | `tkwait` | **yes** (`:9764`) | no |
| `place_symbol` / `place_text` `src/scheduler.c:9093-9117` / `9129-9141` | their own choosers | varies | suspected |

The everyday one is the first row: **`q` on an object (or Edit → schematic properties) opens a
non-modal attribute dialog and holds `semaphore == 1` for as long as it is up.** Press `e` on the
canvas while it is open and the descend chooser appears, works, and does nothing. That the property
dialog's grab is commented out is deliberate (the canvas stays usable while you edit attributes) —
it is exactly the configuration the `>= 2` guards were written for and the `== 0` guard was not.

The whole point of `>= 2` is stated at `src/callback.c:3721-3723`, about the descend chooser itself:

```c
     * The chooser dialog is modal (grab + tkwait); opening it from inside this callback
     * would pump a nested event loop and land every later event at semaphore >= 2, so the
     * Tcl continuation defers it to `after idle`. */
```

So `1` means "one non-grabbing dialog is up", `>= 2` means "an event loop is nested inside another".
Two defensible policies exist; what does not is having both.

### (b) The 0 is then read as a specific diagnosis it does not carry

`hier_traversal` treats a 0 from `xschem descend` as one thing:

```tcl
src/xschem.tcl:3715-3726
    if {$type eq {subcircuit} && $all_hierarchy} {
      xschem select instance $i fast nodraw
      set descended [xschem descend 1 6]
      if {$descended} {
        incr level
        set dp [hier_traversal $level $only_subckts 1]
        xschem go_back 2
        incr level -1
      } else { ;# descended into a blank schematic. Go back.
        xschem go_back 2
      }
    }
```

`descend_schematic()` has **eight** ways to produce 0 and only one of them descended:

| `src/actions.c` | condition | did it push? | audible? |
|---|---|---|---|
| `:3585-3588` | `currsch + 1 >= CADMAXHIER` (40) | no | `dbg(0,…)` → stderr only |
| `:3590-3593` | `sel_array[0].type != ELEMENT` | no | `dbg(1,…)` → nothing |
| `:3605` | Save-As dialog cancelled (untitled parent) | no | no |
| `:3608` | `save_schematic()` failed | no | no |
| `:3617` | `get_sch_from_sym()` returned an empty filename | no | no |
| `:3620-3624` | symbol `type` is neither `subcircuit` nor `primitive` | no | no |
| `:3661` | vector-instance number prompt cancelled | no | no |
| `:3737` `descend_ok = load_schematic(...)` | file could not be opened | **yes** — `xctx->currsch++` is at `:3731`, before the load | only if `alert` (0 from `xschem descend`) |

Only the last row matches the comment, and it is the one the census files separately as **0250**.
For the other seven the compensating `xschem go_back 2` pops a level that was never pushed.

And at nonzero semaphore that compensation is itself swallowed, by the same `== 0` idiom:

```c
src/scheduler.c:5465-5474
    else if(!strcmp(argv[1], "go_back"))
    {
      int what = 1;
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(argc > 2 ) {
        what = atoi(argv[2]);
      }
      if(xctx->semaphore == 0) go_back(what);
      Tcl_ResetResult(interp);
    }
```

so the two bugs partially cancel. What `currsch` actually does, per combination, at traversal
depth *D*:

| condition | `descend` returns | `currsch` after | `go_back 2` | net | what the walk does next |
|---|---|---|---|---|---|
| success | 1 | D+1 | (in the `if` arm, after recursion) | D | correct |
| `load_schematic` failed | 0 | D+1, blank page | pops | D | correct — the case the comment means |
| depth limit / wrong selection / empty filename / cancelled save / wrong type | 0 | D | pops | **D−1** | keeps indexing the *child's* instance count against the *parent's* array |
| `semaphore != 0` | 0 | D | **blocked** | D | subtree silently missing from the report; no message |

The last row is benign for `currsch` and still wrong for the user: the traversal listing is
truncated with no indication. The third row is the corruption. `set instances  [xschem get instances]`
is read once at `src/xschem.tcl:3640`, before the loop, so after a spurious pop the loop keeps
walking indices that now name different objects.

Two mitigations for today's blast radius, stated honestly: `traversal` has **no stock menu entry** in
this tree — repo-wide the only callers are its own recursion (`src/xschem.tcl:3720`) and the `Upd`
button it builds into its own dialog (`:3706`), so it is reached by typing `traversal` in the CIW,
from `--script`, or from a user menu hook. And the "wrong selection" row is currently masked by
[0203](0203-stale-sel_array-descends-a-deselected-instance.md): with a stale `sel_array[0]`,
`descend` often returns 1 where it should refuse. Neither makes the idiom right — and
`hi_descend_finish` already demonstrates the correct one, three thousand lines away in the same
file, for the symbol case:

```tcl
src/xschem.tcl:5875-5880
  if {$vtype eq {symbol}} {
    # descend_symbol has no return value; detect success by the hierarchy level rising,
    # so a no-op symbol descend does not falsely report success and then mislabel /
    # clear the modified flag of the CURRENT (un-descended) schematic.
    xschem descend_symbol
    set ok [expr {[xschem get currsch] > $lvl}]
```

## Reproduce

Measured with the prebuilt in-tree binary. Fixtures: `top.sch` → `mid.sym`/`mid.sch` (two `leaf`
instances), `rec.sch` holding an instance of its own symbol `rec.sym` (self-recursive), `top2.sch`
holding `nosch.sym` (`type=subcircuit`, no `nosch.sch` on disk).

```
$ ./src/xschem --nogui --pipe -q --nolog --script .../final.tcl
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
== A  baseline, semaphore 0 ==
  xschem descend 1 6  -> "1"   currsch=1 cell=mid.sch
  xschem go_back 2    ->            currsch=0 cell=top.sch
== B  semaphore 1: the Tcl surface refuses, silently ==
  xschem descend 1 6  -> "0"   currsch=0
  xschem descend_symbol -> ""    currsch=0
  xschem go_back 2    -> ""    currsch=0
  hi_descend view=schematic inst=xm1 -> "0"   currsch=0
== C  semaphore 2: hi_descend bails one step earlier, with "" not 0 ==
  hi_descend view=schematic inst=xm1 -> ""
== D  hier_traversal's else-branch at a NESTED level ==
  inside mid.sch: currsch=1 instances=2
  descend 1 6 with a WIRE selected -> "0"   currsch=1  (nothing pushed)
  else-branch 'xschem go_back 2'   ->     currsch=0 cell=top.sch  <-- popped an unpushed level
== E  depth limit, self-recursive symbol (CADMAXHIER=40) ==
descend_schematic(): max hierarchy depth reached: 40
  successful descends=39   refusing call returned "0"   currsch=39  (nothing pushed)
  else-branch 'xschem go_back 2'   ->     currsch=38  <-- drifted up one
== F  the ONE case the comment describes: push succeeded, load failed ==
  nosch.sym type=subcircuit  nosch.sch exists=0
  descend 1 6 -> "0"   currsch=1 cell=nosch.sch wires=0 insts=0
  else-branch 'xschem go_back 2'   ->     currsch=0 cell=top2.sch  <-- correct here
```

Reading of the transcript:

- **B** is half (a). At `semaphore == 1` the whole `hi_descend` machinery runs — the instance
  resolver, the view enumerator, `hi_descend_finish` — and returns 0 with `currsch` untouched. **C**
  shows the neighbouring band: at 2 the same call bails at `src/xschem.tcl:6044` and returns `""`.
  Two different falsy answers for two different refusals, neither of which any caller inspects (0251).
- **B** also shows the swallowed compensation: `xschem go_back 2` at `semaphore == 1` returns `""`
  and moves nothing.
- **D**, **E** are half (b): a refusal that never pushed, followed by the else-branch's `go_back 2`,
  leaves `currsch` one level *above* where the walk believes it is. **E** is the realistic trigger —
  a self-referential symbol drives the walk to `CADMAXHIER` and every deeper attempt then refuses.
- **F** is the case the comment was written for: the push happened (`currsch=1`, cell `nosch.sch`,
  `wires=0 insts=0` — a blank page) and the load failed, so `go_back 2` is the right response. It
  also re-confirms 0250: `alert=0` from `xschem descend`, so nothing was printed.

Two things the transcript does **not** prove:

- **The keystroke.** `xschem callback .drw 2 100 100 101 0 0 0` (KeyPress `e`) crashes under
  `--nogui` with `FATAL: signal 11` — no window to dispatch against — so the claim that
  `case 'e'`/`case 'i'` *would* descend at `semaphore == 1` rests on `src/callback.c:6452` and
  `:6589` reading `>= 2`, not on a measurement.
- **Silence.** `ciw_echo` is a headless no-op by design (`src/ciw.tcl:115`:
  `if {![llength [info commands winfo]] || ![winfo exists .ciw.l.t]} return`), so the empty output in
  **B** is not evidence (the guard is at `src/ciw.tcl:115`). Silence is established by reading `hi_descend_finish`
  (`src/xschem.tcl:5881-5902`: no echo on the `!$ok` path) plus the fact that the scheduler guard
  skips the branch entirely, so `descend_schematic()`'s `dbg()` lines never run.

Incidental, from **E**: `dbg(0, "descend_schematic(): max hierarchy depth reached: %d", CADMAXHIER);`
(`src/actions.c:3586`) has no trailing `\n` — the next line of output is concatenated onto it. One
character.

## Fix, if it is to be closed

**1. One threshold, chosen and written down.** Add the missing comment at `src/xschem.h:1604`
defining what each value means (0 = idle, 1 = one non-grabbing dialog / foreground wait with the
canvas live, ≥2 = a nested event loop), then make every descend/go_back gate use the same
predicate — ideally a named helper (`descend_busy()`) rather than an open-coded comparison repeated
in five files. The two candidates:

- **`>= 2` everywhere** (raise the Tcl surface to match the C keys). Matches what plain `e` already
  does, keeps navigation alive while a property dialog or a foreground simulation is up, and closes
  the gap with no user-visible loss. See Risks — this is the direction that grows the reachable
  state space.
- **`== 0` everywhere** (lower the C keys and `hi_descend` to match the Tcl surface). Smaller
  reachable state space, but then `case 'e'`, `case 'i'` and `hi_descend` must **refuse audibly** —
  a `statusmsg_hold` such as `"Descend: not while a dialog is open"` — or this issue simply moves.

Either way the guard must gain an `else` that says something. `dbg(0, …)` alone is not enough: it
reaches a terminal-launched user and not a desktop-launched one.

**2. A distinguishable return (0251).** `descend` must be able to say *refused* separately from
*descended into a blank page*, without breaking the boolean tests at `src/xschem.tcl:3717` and
`:5885`. Options, cheapest first:

- keep 0/1 and add `xschem get last_descend_status` (an enum: `ok`, `busy`, `depth`, `noselect`,
  `nofile`, `notype`, `loadfail`), so existing truthiness is untouched;
- or return `-1` for "refused before any state changed" — still falsy in Tcl's `if`, but testable.

**3. Fix the misread at the call site, independently of 2.** The local fix needs no protocol change
and copies the idiom already in the file at `src/xschem.tcl:5876-5880`:

```tcl
      set lvl [xschem get currsch]
      set descended [xschem descend 1 6]
      if {$descended} {
        incr level
        set dp [hier_traversal $level $only_subckts 1]
        xschem go_back 2
        incr level -1
      } elseif {[xschem get currsch] > $lvl} {
        # pushed, but load_schematic() failed and left us on a blank child page (0250):
        # this is the ONLY refusal that needs compensating.
        xschem go_back 2
      } else {
        # refused before anything was pushed (busy, depth limit, bad selection, no file,
        # wrong type). Nothing to pop -- and the subtree is missing from the report.
        ciw_echo "traversal: could not descend into $instname (subtree skipped)" error
      }
```

The `ciw_echo` matters as much as the guard: a truncated hierarchy report that looks complete is the
user-visible consequence of the `semaphore != 0` row, which the `currsch` delta cannot detect.

## Risks

- **Raising the Tcl threshold to `>= 2` is exactly what the `== 0` guard was defending.** A descend
  reloads `xctx`'s object arrays; a non-grabbing property dialog captured `xctx->sel_array[0]`
  *before* it opened (`src/editprop.c:279-283`, `:395-397` snapshot `sel_array[0].col` / `.n` and
  write back through the same indices after `tkwait` returns). Descending in between makes those
  indices name objects in the **child**, so pressing OK writes the parent's edited property onto
  whatever now sits at that index. That is a data-corrupting path the current guard closes by
  accident. Any move to `>= 2` must be paired with re-resolving (or invalidating) the dialog's
  selection snapshot on a hierarchy change — otherwise prefer the `== 0` direction.
- **Lowering the C keys to `== 0` removes a working escape hatch.** Today `e` / Ctrl+E navigate while
  a foreground simulation runs or a non-modal dialog is up. Users rely on it; taking it away without
  a message is a regression that will read as a freeze.
- **Changing `descend`'s return value breaks boolean callers.** `src/xschem.tcl:3717` and `:5885`
  both use the result directly in `if`. Any sentinel must stay falsy for every refusal and truthy
  only on a real descend; `-1` qualifies in Tcl, a string like `busy` does not (`if {"busy"}` is an
  error).
- **The `currsch`-delta fix in `hier_traversal` is safe but partial.** It stops the corruption
  without addressing why the descend was refused, and it will start *reporting* skipped subtrees
  that today vanish silently — which is the intent, but it changes the dialog's output.
- **`traversal` runs with `no_draw 1` / `no_undo 1`** (`src/xschem.tcl:3575-3576`, cleared at
  `:3596-3597`). A refusal path that returns early, throws, or leaves the walk desynced can strand
  those flags; the existing code has no `catch` around `hier_traversal`. Worth wrapping in the same
  pass.
- **Statusbar cure collides with [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md).** A `statusmsg` refusal is overwritten by the coordinate readout on the next
  pointer motion. Use `statusmsg_hold` (and `statusmsg_hold_clear` on the next real action), the way
  the descend pick already does at `src/scheduler.c:3051`.
- **No coverage anywhere near this band.** Every headless test that touches the semaphore sets it to
  2; nothing sets 1. A change to the threshold is currently unguarded in both directions.
