# 0250 — a descend whose load fails with alert=0 leaves the window on a blank page one level down

Status: **OPEN** — the stranding is measured headless (state dump below, plus the on-disk `~` backup it writes); what is *not* established is which of the two fix shapes is correct, because a blanket "refuse on missing file" would break the create-the-child-by-descending flow, which is also measured below.
Area: `src/actions.c` `descend_schematic()` — the commit point (`:3727-3737`), the unconditional tail (`:3783-3785`); `src/save.c` `load_schematic()` failure arm (`:3810-3828`); the alert=0 dispatch `src/scheduler.c:2993/3000/3002`; the one compensating caller `src/xschem.tcl:3717-3725`
Tests: none — no headless case descends into a missing child. `tests/headless/test_descend_preserve.tcl`, `test_descend_views.tcl`, `test_hi_descend.tcl` all use fixtures whose child `.sch` exists. Proposed: `tests/headless/test_descend_missing_child_0250.tcl`
Found: 2026-08-08, in the descend silent-refusal census (`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related (same census batch, filed alongside this one): [0251](0251-a-refused-descend-has-no-return-channel.md) (the `0` this returns is discarded at almost every caller — that is why the strand is never noticed), **0261** (the mirror case: descend reports *success* on a page that is blank anyway), **0253** (the semaphore threshold that gates whether this path is even reachable). Pre-existing: [0232](0232-missing-symbol-substitution-silently-unnames-nets.md) (the sibling "the referenced file is missing and nobody says so" defect, on the symbol side), [0203](0203-stale-sel_array-descends-a-deselected-instance.md), [0060](0060-descend-from-untitled-loses-parent-content-on-ascend.md), [0035](0035-descended-new-window-spuriously-modified.md), [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md) (constrains any statusbar-based fix). Spec: `doc/claude/specs/descend_hierarchy_in_memory.md`.

## The defect

`descend_schematic()` has eight exits. Seven `return 0` **before** anything is committed — the
depth cap (`:3587`), the wrong-selection check (`:3592`), the unnamed-parent save cancel
(`:3605`, `:3608`), the empty filename (`:3617`), the non-subcircuit type check (`:3624`), the
cancelled vector-instance prompt (`:3661`). The eighth is the single `return descend_ok`
(`:3785`), and it can carry a failure that was never rolled back.
The child load happens **after** the level has already been pushed:

```c
src/actions.c:3727-3737
   xctx->previous_instance[xctx->currsch]=n;
   xctx->zoom_array[xctx->currsch].x=xctx->xorigin;
   xctx->zoom_array[xctx->currsch].y=xctx->yorigin;
   xctx->zoom_array[xctx->currsch].zoom=xctx->zoom;
   xctx->currsch++;
   hilight_child_pins();
   unselect_all(1);
   dbg(1, "descend_schematic(): filename=%s\n", filename);
   /* we are descending from a parent schematic downloaded from the web */
   if(!tclgetboolvar("keep_symbols")) remove_symbols();
   descend_ok = load_schematic(1, filename, (set_title & 1), alert);
```

and `load_schematic()` on a file it cannot open gates **both** of its user-facing channels
behind `alert`, then wipes the buffer regardless:

```c
src/save.c:3809-3828
    else fd=my_fopen(name,fopen_read_mode);
    if( fd == NULL) {
      size_t len;
      ret = 0;
      if(alert) {
        fprintf(errfp, "load_schematic(): unable to open file: %s, ffname=%s\n", name, ffname );
        if(has_x) {
          my_snprintf(msg, S(msg), "update; alert_ {Unable to open file: %s}", ffname);
          tcleval(msg);
        }
      }
      len = strlen(name);
      if(!strcmp(name + len - 4, ".sym")) {
        …
      }
      clear_drawing();
      if(reset_undo) set_modify(0);
```

Note what precedes that: `xctx->sch[xctx->currsch]` was already overwritten with the
unopenable path (`src/save.c:3781`), `xctx->current_name` with its relative form (`:3783`),
`xctx->clear_undo()` ran (`:3732`) and `xctx->readonly` was reset to 0 (`:3734`) — all before
the `fopen`. So the failure arm is reached with the context already renamed to the file that
does not exist.

Back in `descend_schematic()`, the tail runs the viewport reset unconditionally:

```c
src/actions.c:3778-3785
   if(descend_ok) net_hilight_anim_update();
   …
   if(descend_ok) net_hilight_sync_descend_windows();
   zoom_full(1, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
 }
 return descend_ok;
```

Every side effect that is guarded by `descend_ok` (`:3738`, `:3768`, `:3778`, `:3782`) is a
success-only nicety; the one thing that is *not* guarded — `zoom_full` — is precisely the one
that makes the failure look like a successful load. The result is a fully drawn, correctly zoomed, empty canvas titled with the
missing cell — `set_modify()` builds the title from `[xschem get schname]`
(`src/actions.c:257/260`) and `load_schematic` forced `prev_set_modify = -1`
(`src/save.c:3733`) so the title refresh definitely fires.

**What the user perceives:** they press `e` on an instance; the schematic they were editing
vanishes and is replaced by an empty sheet; the title bar changes to a cell name they may not
recognise; the hierarchy is one level deeper than they think. No dialog, no status line, no
stderr. If they now draw, they are drawing into a buffer whose save target is the missing
path — and the first edit immediately writes the autosave backup `<missingcell>~.sch` next to
where the file should have been (measured below). If instead they press Ctrl+E to get back,
everything recovers and they are left believing they mis-clicked.

**This is the widest of the census holes because `alert=0` is the ordinary case.** The Tcl
dispatcher hardcodes it at every arm:

```c
src/scheduler.c:2993        ret = descend_schematic(0, 0, 0, set_title);
src/scheduler.c:3000            ret = descend_schematic(n, 0, 0, set_title);
src/scheduler.c:3002            ret = descend_schematic(0, 0, 0, set_title);
```

so `alert=0` covers: the `e` key (which is bound to the Tcl chooser `hi_descend`,
`src/xschem.tcl:14175`, → `hi_descend_finish` → `xschem descend $iter`,
`src/xschem.tcl:5885`), Edit > Push schematic (`src/xschem.tcl:14725`, also `hi_descend`),
the toolbar EditPushSch (`src/xschem.tcl:13166`, the bare `xschem descend`),
`descend_hierarchy` (`src/xschem.tcl:3872`) and everything built on it (`select_inst`,
`probe_net`), `hier_traversal` (`src/xschem.tcl:3717`), and every script and replayed action-log
line. Only three call sites pass `alert=1`, all of them raw C: the right-click context menu
items 12 and 22 (`src/callback.c:4510`, `:4513`) and the raw key handler
(`src/callback.c:6453`), each `descend_schematic(0, 1, 1, 1)`.

Even those three are only partly protected. They pass `fallback=1`, so `get_sch_from_sym()`
asks *"Schematic X does not exist. Descend into base schematic?"* (`src/actions.c:3470`) — but
answering **No** sets `fallback = 0` (`:3471`) without clearing `filename`, so the block at
`:3480` is skipped, `filename` stays the missing path, and the descend proceeds into exactly
the same strand. The user gets one `alert_` from `load_schematic` and then the blank page
anyway.

## Reproduce

Fixture: `descend_child.sym` copied from `tests/headless/fixtures/descend/`, and a parent
whose single instance carries an explicit `schematic=` override naming a file that does not
exist:

```
C {descend_child.sym} 0 0 0 0 {name=x1 schematic=no_such_cell_0250.sch}
```

Measured, `src/xschem --nogui --pipe -q --nolog --script …` (stderr captured to a separate
file, shown in full):

```
PARENT      : currsch=0 name=bad_parent.sch insts=1 wires=1 modified=0 path=. instnum=1
descend -> '0'
AFTER FAIL  : currsch=1 name=no_such_cell_0250.sch insts=0 wires=0 modified=0 path=.x1. instnum=1
AFTER GOBACK: currsch=0 name=bad_parent.sch insts=1 wires=1 modified=0 path=. instnum=1

===== STDERR =====
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
```

Nothing on stderr beyond the two startup banners. `xschem get_sch_from_sym 0` resolved to
`/home/analog/dev/xschem-claude/no_such_cell_0250.sch`; `xschem get schname` after the failure
is that same path.

State inventory after the failed descend, as measured:

| field | before | after failure | verdict |
|---|---|---|---|
| `currsch` | 0 | **1** | advanced — not unwound |
| `current_name` / `sch[currsch]` | `bad_parent.sch` | **the missing path** | committed |
| `sch_path[currsch]` | `.` | **`.x1.`** | committed |
| `sch_inst_number` | 1 | 1 | committed at `:3723` (parent slot) |
| instances / wires | 1 / 1 | **0 / 0** | `clear_drawing()` ran |
| `modified` | 0 | 0 | `set_modify(0)` ran (reset_undo=1) |
| `readonly` | 0 | **0** | `load_schematic:3734` reset it; the `descend_readonly` browse lock at `:3768` is gated on `descend_ok` and never applied |
| `hier_attr[0]`, `previous_instance[0]`, `zoom_array[0]`, `portmap[1]` | — | all populated | committed at `:3712-3730`, `:3672-3675` |

`go_back` recovers cleanly (row 3 above): the parent's geometry, name and level all return,
because `go_back()` frees `sch[currsch]` and `portmap[currsch]`, decrements, and reloads
(`src/actions.c:3842-3862`). That is *why* the bug survives — the damage is fully reversible
by a key the user has no reason to press.

Second measurement — the stranded page is live and it touches the disk. With
`descend_readonly` set to 1 (browse mode, where the page should not be editable at all):

```
PARENT : currsch=0 ro=0 name=bad_parent.sch
descend -> '0'
AFTER  : currsch=1 ro=0 name=no_such_cell_0250.sch schname=/home/analog/dev/xschem-claude/no_such_cell_0250.sch
EDITED : wires=1 modified=1
backup exists on the MISSING cell path? 1
```

One wire drawn on the phantom page set `modified=1` and the autosave hook wrote
`/home/analog/dev/xschem-claude/no_such_cell_0250~.sch` — a real file, in the directory the
missing cell was looked for in, created by a gesture the user believes did nothing. (Deleted
after the run.)

**Third measurement — the flow the naive fix would break.** A symbol with no `schematic=`
attribute whose default `<symname>.sch` does not exist yet takes the *same* failure path, and
saving there creates the child:

```
descend(no .sch yet) -> '0'
currsch=1 schname=…/scratchpad/w0250/newcell_0250.sch
child .sch created? 1
```

So `descend_ok == 0` currently means two different things — "the child you named is missing"
and "you are creating this child right now" — and only the first is a defect. Any fix must
discriminate them; see below.

Contrast, to establish that the silence is a policy choice and not an environment artifact:
`dbg(0, …)` does reach stderr in this exact invocation. `xschem load -gui` on a missing file
takes the equivalent branch with the alert enabled and prints:

```
xschem load -gui: unable to open file: /nonexistent/zzz_0250.sch
res=…/untitled.sch
name=untitled.sch
```

— note the buffer keeps its identity there. `xschem load` **without** `-gui` defaults to
`force = 1` (`src/scheduler.c:7003`) → `alert = !force = 0`, is silent, and renames the buffer
to the missing path. The same alert/force split, the same consequence, one level up.

GUI-only aspects not measured: the title-bar text, and whether a `zoom_full` on an empty
buffer paints grid-only or truly nothing. The code path is unambiguous (`src/actions.c:257`,
`:260`) but this was not eyeballed under X.

## Fix, if it is to be closed

Two shapes. Both need the `hier_traversal` change in the same commit (Risks).

**Shape A — discriminate at the resolve, refuse before committing.** The precedent is already
in the tree, at the `xschem load` branch, and it does exactly the right thing (probe, report,
keep the buffer):

```c
src/scheduler.c:7135-7143
          if(!force && f[0] && !is_generator(f) && !is_from_web(f)) {
            FILE *probe = my_fopen(f, fopen_read_mode);
            if(probe) fclose(probe);
            else {
              if(has_x) tclvareval("alert_ {Unable to open file: ", f, "}", NULL);
              else dbg(0, "xschem load -gui: unable to open file: %s\n", f);
              skip = 1;
            }
          }
```

Transplanted into `descend_schematic()` it goes between the `get_sch_from_sym()` return
(`src/actions.c:3615-3617`) and the first commit (`:3646`, `prepare_netlist_structs`), so the
function keeps its "every refusal returns before the push" property and no unwind is needed at
all. The discriminator the third measurement demands: probe-and-refuse **only when the target
came from an explicit `schematic=` token** (instance or symbol), i.e. when
`get_tok_value(…, "schematic", 6)` was non-empty — that is a user-authored reference to a
named file, and a missing one is an error. When the path was *derived* from the symbol name
(`src/actions.c:3479-3499`), the missing file is the create-the-child flow and must still
descend — but should announce itself, e.g.
`statusmsg("Creating new schematic <cell>", 1)` plus `dbg(0, …)`, so the blank page is
explained rather than mysterious. `get_sch_from_sym()` already knows which case it is (`str_tmp`
non-empty vs. the `:3480` fallback block); it needs to hand that back — an out-parameter, or a
small enum return, rather than the current `void`.

**Shape B — unwind on failure.** On `!descend_ok`, undo the push before returning. That is
strictly more code than it looks: the commit spans `sch_path[currsch+1]` (`:3672`, allocated),
`sch_path_hash[currsch+1]` (`:3673`), `portmap[currsch+1]` (`:3674-3675`, an allocated hash
that `:3677-3710` then fills), `hier_attr[currsch]`'s three `my_strdup`s (`:3712-3716`),
`sch_inst_number[currsch]` (`:3723`), `previous_instance[currsch]` (`:3727`),
`zoom_array[currsch]` (`:3728-3730`), the increment (`:3731`), the `remove_symbols()`
(`:3736`), and — inside `load_schematic` — `sch[currsch]`, `current_name`, `current_dirname`,
the cleared undo stack and the `clear_drawing()`. Restoring all of that means reloading the
parent, which is precisely `go_back()`'s job. So Shape B in practice is "call the go_back
unwind with confirm off", and it inherits two wrinkles: `go_back()` self-logs
(`src/actions.c:3900-3901`), which would put a phantom `xschem go_back` in the action log for
a descend that never happened, and `go_back()` re-reads the parent through `load_backup_as`
(`:3860`), so a failed descend would become a full parent reload. Shape A avoids both.

Whichever shape, the refusal must also **report**: a `statusmsg`/`statusmsg_hold`
(`src/scheduler.c:28`, `:90`) so a desktop-launched user sees it, plus `dbg(0, …)` for the
terminal, plus the existing `alert_` on the `alert=1` routes. And the Tcl side already has the
hook: `hi_descend_do_body` emits a `ciw_echo` for every *other* failure
(`src/xschem.tcl:6010`, `:6015`, `:6028`, `:6038`) but `hi_descend_finish` returns the descend's
`0` with none (`src/xschem.tcl:5885-5902`) — see
[0251](0251-a-refused-descend-has-no-return-channel.md).

## Risks

- **The `hier_traversal` double-pop.** This is the whole risk. Exactly one caller in the tree
  compensates for the failed descend's leftover level, and it does so unconditionally:

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

  The `else` comment is the current contract stated out loud: *a failed descend still pushed a
  level*. If `descend_schematic()` starts unwinding (Shape B) or refusing before the push
  (Shape A), that `go_back 2` pops a level the descend never took. At the top of a traversal
  (`currsch==0`) it is benign — `go_back()` is a no-op guarded by `if(xctx->currsch>0)`
  (`src/actions.c:3806`). At depth ≥ 1, inside the recursion, it ascends out of the subtree
  being enumerated and the rest of that level's instance list is walked against the wrong
  schematic. The `else` arm must be deleted in the same commit. Nothing else pairs a `go_back`
  with a descend: the other Tcl `go_back` sites (`src/xschem.tcl:3860`, `:3888`, `:3911`,
  `:3927`, `:3937`, `:13660`) are `while {[xschem get currsch]}` drain loops or the explicit Pop
  command, all insensitive to this; the three C callers (`src/callback.c:4510`, `:4513`,
  `:6453`) do not compensate.
- **Breaking create-the-child-by-descending.** Measured above: descending into a symbol whose
  `.sch` does not exist yet, drawing, and saving *creates* the child. A blanket
  probe-and-refuse deletes that workflow, and it is the standard way to build a hierarchy
  top-down. The explicit-`schematic=` discriminator is not optional.
- **`get_sch_from_sym()` signature change.** Shape A needs it to report *why* the filename is
  what it is. It is called from netlisting and from the `xschem get_sch_from_sym` scheduler
  command as well as from descend; widening it touches all of them.
- **Return-value semantics.** Today `descend_ok == 0` conflates "refused, nothing happened"
  (the seven early exits) with "committed then failed" (this one) with "created a new blank
  child" (the third measurement). Callers that today read `0` as "we are still where we were"
  are already wrong; making that reading *true* changes what
  [0251](0251-a-refused-descend-has-no-return-channel.md) and **0261** have to fix, so
  sequence them.
- **`alert=1` routes get a second message.** Adding a `statusmsg` + `dbg(0)` to the refusal
  means the context-menu and raw-key paths would emit both that and `load_schematic`'s
  `alert_` — unless the probe happens first and returns, in which case `load_schematic` is
  never reached. Shape A gets this right for free; Shape B does not.
- **Statusbar as the channel.** Per
  [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md),
  a plain `statusmsg` on this path can be wiped by the next pointer motion. Use
  `statusmsg_hold` (`src/scheduler.c:90`) or the fix will be silent again in practice.
- **No coverage.** Nothing headless descends into a missing child today, so any change here is
  unguarded until `tests/headless/test_descend_missing_child_0250.tcl` exists. It should assert
  all three cases: explicit missing `schematic=` (refuse, level unchanged, message), derived
  missing `<symname>.sch` (descend, level +1, message), and existing child (unchanged
  behaviour) — plus that no `~` backup appears next to a refused target.
