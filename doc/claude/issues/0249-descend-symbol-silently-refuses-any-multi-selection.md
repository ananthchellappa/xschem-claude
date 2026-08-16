# 0249 — descend_symbol refuses any multi-object selection with zero feedback

Status: **OPEN** — the refusal and its four trigger shapes are measured headless (transcript
below). What is *not* measured: the GUI-only consequences (dead `I` key / dead toolbar button /
dead context-menu item) and the phantom action-log line, both read from the source only.
Area: `src/save.c` `descend_symbol()` (`:5546`), guard at `:5562-5563` and its `else return 0`
at `:5594`; callers `src/callback.c:4519` (context menu), `src/callback.c:6590` (key `i`),
`src/scheduler.c:3033` (menu / toolbar / CIW); contrast `src/actions.c:3589-3593`
Tests: `tests/headless/test_descend_symbol.tcl` exercises only the B6 save-prompt behaviour under
a *single* selection (`:81`, `:123`); nothing anywhere covers the selection guard. Proposed
`tests/headless/test_descend_symbol_multisel_0249.tcl`
Found: 2026-08-08, in the descend silent-refusal census
(`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: **0250** (a failed descend load with `alert=0` strands the window on a blank child page),
**0251** (a refused descend has no return channel — the discarded `int` below is its worst
instance), **0252** (non-subcircuit symbols refused silently), **0253** (the `semaphore >= 2`
gate at `src/callback.c:6589` sitting in front of this one; the threshold disagrees across Tcl
and C), [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md)
(the same class of selection accident, on `descend_schematic`), [0203](0203-stale-sel_array-descends-a-deselected-instance.md)
(stale `sel_array` — the other half of "the guard trusts `sel_array` too much"),
[0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md) (any
statusbar fix here must survive the coordinate readout), [0200](0200-descend-has-no-verb-noun-pick.md)
(verb-noun pick, RESOLVED).

## The defect

`descend_symbol()` opens with two guards. The first announces itself; the second does not:

```c
src/save.c:5557-5563
  if(xctx->currsch + 1 >= CADMAXHIER) {
    dbg(0, "descend_symbol(): max hierarchy depth reached: %d", CADMAXHIER);
    return 0;
  }

  rebuild_selected_array();
  if(xctx->lastsel > 1)  return 0;
```

`dbg(0, ...)` at the default debug level does reach stderr (`globals.c` `debug_var = -10`,
`xinit.c` raises it to 0, `util.c` prints when `debug_var >= level`, `errfp == stderr`), so the
depth guard at least talks to a terminal-launched user. The selection guard has no `dbg`, no
`alert_`, no `tk_messageBox`, no `statusmsg`, no `ciw_echo`, and no `fprintf(errfp, ...)`. By the
census definition that is a fully silent refusal: nothing reaches the user on any channel. The
same is true of the block's other exit, `else return 0;` at `src/save.c:5594`, which catches a
`lastsel == 1` selection whose single entry is not an `ELEMENT` (a lone selected pin, a lone wire).

The `int` return is then discarded by all three callers:

- `src/callback.c:4519` — `descend_symbol();` as a bare statement (context-menu retval 13).
- `src/callback.c:6590` — `descend_symbol();` as a bare statement (key `i`).
- `src/scheduler.c:3033-3035` — the value is not even bound:

```c
src/scheduler.c:3033-3035
        descend_symbol();
      }
      Tcl_ResetResult(interp);
```

`Tcl_ResetResult` makes `xschem descend_symbol` evaluate to `""` on refusal — the *same* empty
string it evaluates to on success. A Tcl caller cannot distinguish "descended" from "refused"
from the command's value, which is why `hi_descend_finish` has to infer the outcome by watching
the hierarchy level:

```tcl
src/xschem.tcl:5874-5881
  set lvl [xschem get currsch]
  if {$vtype eq {symbol}} {
    # descend_symbol has no return value; detect success by the hierarchy level rising,
    # so a no-op symbol descend does not falsely report success and then mislabel /
    # clear the modified flag of the CURRENT (un-descended) schematic.
    xschem descend_symbol
    set ok [expr {[xschem get currsch] > $lvl}]
```

That comment is the workaround for this issue, written at the one call site that noticed.

### The asymmetry with `descend_schematic`

`descend_schematic()` carries the identical test — commented out:

```c
src/actions.c:3589-3593
 rebuild_selected_array();
 if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
   dbg(1, "descend_schematic(): wrong selection\n");
   return 0;
 }
```

So the two sibling verbs have *opposite* policies for byte-identical program state.
Descend-schematic takes `sel_array[0]` and descends; descend-symbol dies. Measured below: with
`x1` and `x2` both selected, `xschem descend` returns `1` and lands in `nand2.sch`, while
`xschem descend_symbol` does nothing at all. Nothing in the source justifies the split — the
commented-out fragment shows the multi-select restriction was deliberately relaxed on one path
and left standing on the other. (Note that `descend_schematic`'s own guard is not equivalent to
"first selected instance" either: `rebuild_selected_array()` scans texts *before* instances
(`src/move.c:61-76`), so an instance co-selected with a text puts `xTEXT` at `sel_array[0]` and
that path refuses too — that is [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md), and its
`dbg(1, ...)` is invisible at the default level, so it is silent in a different way.)

### Which user gestures hit it

Every direct entry to the C function, i.e. every one except the two that narrow the selection
first:

| entry | route | affected |
|---|---|---|
| key `i` (accelerator **I**) | `src/callback.c:6587-6590` → `descend_symbol()` | yes |
| context menu **Descend symbol** | `src/xschem.tcl:12630` retval 13 → `src/callback.c:4519` | yes |
| menu **Edit > Push symbol** | `src/xschem.tcl:14726` → `xschem descend_symbol` | yes |
| toolbar **EditPushSym** | `src/xschem.tcl:13167` → `xschem descend_symbol` | yes |
| `xschem descend_symbol` from a script/CIW | `src/scheduler.c:3033` | yes |
| `xschem descend_symbol -inst <name>` | `src/scheduler.c:3030-3031` does `unselect_all(1); select_element(...)` | no |
| the `hi_descend` chooser (`e`) | `hi_descend_current` (`src/xschem.tcl:5907-5910`) does `xschem unselect_all` then selects one instance | no |

The context menu offers the item whenever *anything* is selected — `set selection [expr {[xschem
get lastsel] > 0}]` at `src/xschem.tcl:12599`, gating both the widget (`:12630`) and its packing
(`:12705`). Nothing greys it out at `lastsel > 1`, and neither the menu entry nor the toolbar
button has any state management. So the UI advertises the operation and then does nothing when
it is picked.

Trigger shapes, all measured below, in rough order of how easy they are to hit by accident:

1. **Two instances selected** — the obvious case: rubber-band a region, then press `I`.
2. **One instance plus one wire, or plus one text** — the *ordinary* result of a rubber band
   around a symbol, which sweeps in the wires and labels touching it.
3. **One instance plus one of its own pins.** `rebuild_selected_array()` emits an `INST_PIN`
   entry per selected pin *independently* of `inst.sel` (`src/move.c:77-93`), so `lastsel`
   becomes 2 for what the user sees as one selected symbol with one pin handle drawn on it.
   This state is reachable in the GUI: with `en_pin_select` on and the intuitive/cadence
   interface active, **Shift+click on a pin ADDS the pin with no `unselect_all`** —
   `src/callback.c:8214-8225` arms `pin_pending_add`, and `src/callback.c:8410-8420` commits it
   with `select_pin(pn, pc, SELECTED, 0)` and no unselect. Select the symbol, Shift-click one of
   its pins, press `I`: dead key. (The *plain* pin click at `src/callback.c:8427-8433` does
   `unselect_all(1)` first, giving `lastsel == 1` with type `INST_PIN`, which then dies at the
   `else return 0` on `src/save.c:5594` — silent for the same reason, different line.)

### Secondary consequence: a phantom action-log line

The context-menu arm records the pick from a table *after* running it, gated only on the core's
self-log flag, not on success:

```c
src/callback.c:4570-4572
  if(!logcmd && ret > 0 && ret < (int)(sizeof(ctxmenu_log_cmd)/sizeof(ctxmenu_log_cmd[0])))
    logcmd = ctxmenu_log_cmd[ret];
  if(logcmd && !actionlog_cmd_logged) log_action("%s", logcmd);
```

with `"xschem descend_symbol"` at index 13 (`src/callback.c:4395`). `descend_symbol()` self-logs
only on the success path (`src/save.c:5699-5700`), so a *refused* context-menu pick leaves
`actionlog_cmd_logged == 0` and the wrapper writes `xschem descend_symbol` into the log for a
descend that never happened. The comment at `src/save.c:5688-5692` asserts "All refusal paths …
returned 0 above -> no phantom line", which holds for the scheduler branch (it logs nothing) but
**not** for this context-menu table, whose dedup only suppresses the wrapper when the core *did*
log. Replaying such a log descends where the recording did not. Read from source; not measured
(the pick needs a live Tk context menu).

## Reproduce

Measured 2026-08-08 against the working tree, prebuilt `src/xschem`, true headless. `xschem get
lastsel` calls `rebuild_selected_array()` itself (`src/scheduler.c:4394-4397`), so the counts are
the same ones the guard sees.

```
$ ./src/xschem --nogui --pipe -q --script /tmp/.../d0249e.tcl
fixture: instances=2 wires=1 texts=1

1 two instances       BEFORE       lastsel=2 currsch=0 cell=untitled-39.sch
1 two instances       AFTER        lastsel=2 currsch=0 cell=untitled-39.sch
2 instance+wire       BEFORE       lastsel=2 currsch=0 cell=untitled-39.sch
2 instance+wire       AFTER        lastsel=2 currsch=0 cell=untitled-39.sch
3 instance+text       BEFORE       lastsel=2 currsch=0 cell=untitled-39.sch
3 instance+text       AFTER        lastsel=2 currsch=0 cell=untitled-39.sch
4 instance+own pin    BEFORE       lastsel=2 currsch=0 cell=untitled-39.sch
4 instance+own pin    AFTER        lastsel=2 currsch=0 cell=untitled-39.sch
5 pin alone           BEFORE       lastsel=1 currsch=0 cell=untitled-39.sch
5 pin alone           AFTER        lastsel=1 currsch=0 cell=untitled-39.sch
6 single instance     BEFORE       lastsel=1 currsch=0 cell=untitled-39.sch
6 single instance     AFTER        lastsel=0 currsch=1 cell=nand2.sym

7 descend_schematic   BEFORE       lastsel=2 currsch=0 cell=untitled-39.sch
  xschem descend -> 1
7 descend_schematic   AFTER        lastsel=0 currsch=1 cell=nand2.sch
DONE
```

The fixture is two `examples/nand2.sym` instances (`x1`, `x2`), one wire and one text; case 4
uses `xschem select pin x1 0` (`src/scheduler.c:10724-10735`), the headless equivalent of the
Shift+click pin gesture. Case 6 is the control: `lastsel == 1` descends into `nand2.sym`. Case 7
is the asymmetry, on the *same* selection as case 1.

The silence is verifiable on stderr — nothing is emitted between the marks:

```
$ ./src/xschem --nogui --pipe -q --script d0249c.tcl 2>err.txt 1>/dev/null ; cat err.txt
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
=== MARK: about to call descend_symbol with lastsel=2 ===
=== MARK: back, currsch=0 ===
```

And the return channel is indistinguishable between refusal and success:

```
case1 'xschem descend_symbol' returned >><< (empty string = ResetResult)   [lastsel=2, refused]
case4 returned >><< (SUCCESS also yields empty string)                     [lastsel=1, descended]
```

The two selection-narrowing entries are immune, confirming the diagnosis — same two-instance
selection, different route:

```
E before: lastsel=2 currsch=0 cell=untitled-39.sch
E after (-inst form): lastsel=0 currsch=1 cell=nand2.sym     ;# xschem descend_symbol -inst x2
F before: lastsel=2 currsch=0 cell=untitled-39.sch
F: hi_descend rc=0 res=1
F after (hi_descend): lastsel=0 currsch=1 cell=nand2.sym     ;# hi_descend view=symbol type=symbol
```

**Not reproduced:** the GUI-visible half — that `I`, the Edit menu item, the toolbar button and
the context-menu item are dead keys with no explanation — is inferred from the call sites in the
table above, not driven through a real display. Likewise the phantom action-log line.

## Fix, if it is to be closed

Two shapes, and they are not equivalent.

**(a) Give the guard a voice (conservative, recommended first).** Leave the target rule alone and
say why nothing happened:

```c
  rebuild_selected_array();
  if(xctx->lastsel > 1) {
    statusmsg("Descend symbol: select exactly one instance "
              "(a wire, text or pin in the selection also counts)", 2);
    dbg(0, "descend_symbol(): refused, lastsel=%d\n", xctx->lastsel);
    return 0;
  }
```

and the same for the `else return 0` at `src/save.c:5594`, which needs a *different* message
("select an instance, not a pin/wire"). This changes no behaviour for scripts: the operation
still refuses exactly the selections it refuses today. Riders: the message must be one that
survives the coordinate readout ([0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)),
and `descend_symbol()` is called from `--nogui` contexts, so anything Tk-only (`alert_`) must be
guarded by `has_x`.

**(b) Match `descend_schematic` and act on the selection's instance (behaviour change).** Delete
the `lastsel > 1` test and descend into the instance. Note that literally copying
`descend_schematic`'s rule — trust `sel_array[0]` — does **not** fix case 3 of the transcript:
`rebuild_selected_array()` scans texts first (`src/move.c:61-68`), so instance+text still lands a
non-`ELEMENT` at index 0. The rule that actually matches what the user means is *first `ELEMENT`
in `sel_array`*, which is exactly what the Tcl side already implements —
`hi_descend_target_inst` (`src/xschem.tcl:5758-5773`) takes `[lindex [xschem selected_set] 0]`,
and `selected_set` filters to `ELEMENT` (`src/scheduler.c:10994-11010`). Adopting it in C would
make all three descend paths agree and would close [0255](0255-an-instance-co-selected-with-a-text-silently-blocks-descend.md)
in the same stroke.

**Recommendation: (a) now, (b) only as a deliberate, documented unification.** (b) silently
changes what a script gets: today `xschem descend_symbol` with a sloppy selection is a no-op and
the schematic stays put; afterwards it descends into whichever instance happens to sort first,
and any script that relied on the no-op starts editing a symbol. A refusal that *explains itself*
is strictly better than today with no such risk, and it is the change that can go in without an
audit of every caller. If (b) is taken, it must be taken on all three paths at once, with the
first-`ELEMENT` rule and not `sel_array[0]`, or the paths merely disagree in a new way.

Independently of which is chosen, `src/scheduler.c:3035`'s `Tcl_ResetResult` should become
`Tcl_SetResult(interp, dtoa(ret), TCL_VOLATILE)` to match the `descend` branch
(`src/scheduler.c:3006`) — that is **0251**, and it
would let `hi_descend_finish` drop its `currsch`-watching workaround. And the context-menu log
line should be gated on the return value once one exists.

Proposed coverage, `tests/headless/test_descend_symbol_multisel_0249.tcl`: the six cases of the
transcript, asserting `currsch` after each, plus the `descend`/`descend_symbol` asymmetry as an
explicit cross-check so a future unification has to update the test deliberately.

## Risks

- **Scripts depending on the no-op.** Shape (b) turns a documented-by-accident no-op into a real
  hierarchy change. `xschem descend_symbol` is reachable from the CIW, from custom menus/buttons
  (`*_hooks.tcl`) and from the action log; nothing in-tree greps as depending on the refusal, but
  the surface is user-extensible and cannot be audited from here.
- **Message spam.** `descend_symbol()` sits behind bare key `i`. A statusbar line on every
  mis-selected press is right; an `alert_` modal is not — it would make a fat-fingered `i` a
  dialog to dismiss. Use `statusmsg`, and check it is not immediately overwritten (0248).
- **Headless callers.** The function runs under `--nogui`; any Tk-dependent message must be
  `has_x`-guarded or the regression suite starts erroring inside a guard that is supposed to be
  a courtesy.
- **`lastsel` is not "objects the user selected".** The pin case proves the count includes inert
  `INST_PIN` pseudo-selections (`src/select.c:1544-1546` — "Pin selection is transient and INERT
  … never in `inst.sel`, so no move/copy/delete/stretch op ever acts on it"). Any fix phrased in
  terms of `lastsel` inherits that; a fix phrased in terms of "how many `ELEMENT`s are selected"
  does not. Prefer the latter even for the message-only shape, or the message will name a
  selection the user cannot see.
- **The guard is load-bearing downstream.** Everything after `src/save.c:5564` indexes
  `xctx->sel_array[0].n` into `xctx->inst[]` and then calls `load_schematic()`, which replaces
  that array. Relaxing the guard means the chosen `n` must be resolved *before* any of the
  embedded-symbol save path runs (which can call `save()` and re-enter Tcl). The existing code
  already captures `instname_log` for this reason (`src/save.c:5590-5592`); a target-rule change
  must respect the same ordering.
- **Untested surface.** No test covers any refusal path of `descend_symbol()` today, so a change
  here is currently unguarded in both directions.

---

# RESOLUTION — FIXED (item D4, run 2026-08-09, branch open_pdk)

Status: **FIXED**. Landed with 0251, 0254, 0256 and 0366 as one mechanism.
Item status is **E**: see the ratification question in 0251's resolution (decision D6).

## What was measured BEFORE

Byte-identical state, opposite policy on the two verbs — quoted verbatim from the D4
Measure agent's probe (`--nogui --pipe -q --nolog`):

```
C1 two instances selected: lastsel=2 selected_set={{x1} {x2}}
C2   descend_symbol -> ''   currsch=0  (REFUSED, silently)
C3   descend        -> '1'   currsch=1  (ACCEPTED)
C4 instance + own pin    : lastsel=2 selected_set={{x1}}
C5   descend_symbol -> ''   currsch=0  (REFUSED on an invisible 2nd selection)
```

C4/C5 is the shape that decided the fix: the user sees **one** selected symbol and
`xschem selected_set` agrees (`{{x1}}`), but `xctx->lastsel` is 2 because an instance's
own `INST_PIN` pseudo-selection counts. The old guard `if(xctx->lastsel > 1) return 0;`
(`src/save.c:5563`) therefore refused a selection the user could not see, and said nothing.

## What it does AFTER

Same probe, same fixture, rebuilt binary:

```
C4 instance + own pin    : lastsel=2 selected_set={{x1}}
C5   descend_symbol -> '1'   currsch=1
C2   descend_symbol -> '0'   currsch=0
E1 xschem get descend_error -> 'multi-selection'   (for the C1/C2 two-instance case)
E2 after a refusal, statusmsg = 'Descend symbol: select an instance to descend into'
E3 after a refusal, statusmsg_hold = '1'
```

(The probe's C2/C5 label text `(REFUSED…)` is baked-in BEFORE prose and is now stale;
the values are what changed.)

The genuinely ambiguous case (C1: two real instances) still refuses — but it now returns
`0`, records `multi-selection`, and **says so** on the held status line. The accidental
case (C4/C5: instance + its own pin) now descends, because exactly one ELEMENT is selected.

## How

`src/save.c:5563`'s `lastsel > 1` test and the trailing `else return 0` at `:5594` are
replaced by one named callee, `descend_pick_target(&n, 0, "Descend symbol")`
(`src/actions.c`), which calls `rebuild_selected_array()` once, counts **ELEMENT** entries
over `[0, lastsel)`, and never reads `sel_array[0]` before proving an entry is live.
`descend_schematic()` calls the same picker with `multi_ok = 1`.

Resolving `n` inside the picker also satisfies this issue's own "the guard is load-bearing
downstream" risk note: the target index is now fixed **before** the embedded-symbol save
path can re-enter Tcl and replace `sel_array`.

## Decisions

- **D3 [ladder R1 spirit, R2 phrasing] — the guard moves from `lastsel > 1` to "exactly one
  ELEMENT".** R1 for the spirit ("whatever you just pressed is what you meant",
  0240/0242/0243/0247/0265/0269): with an instance and its own pin selected the user sees one
  symbol and `selected_set` agrees, so refusing names a selection that does not exist. R2 for
  the exact rule — it is forced by the message: a message-only fix would print "select exactly
  one instance" while exactly one instance *is* selected, i.e. the fix would lie.
  - *Rejected (a):* message-only, keeping the `lastsel` phrasing — it makes the tool
    contradict itself out loud.
  - *Rejected (b):* this issue's own full-unification proposal (delete the guard, take
    `sel_array[0]`) — with two genuinely selected instances that silently picks whichever
    sorts first, trading a silent refusal for a silent arbitrary choice.
- **D4 [R2] — `descend_schematic` keeps "first ELEMENT, any count"** and gains only the
  missing zero-ELEMENT refusal (0366). Smallest blast radius, and it buys the invariant that
  bounds the whole item: **no descend that succeeds today stops succeeding**, the single
  exception being 0366's false success.
  - *Rejected:* tightening `descend` to "exactly one ELEMENT" to match `descend_symbol` —
    removes shipped capability with unauditable out-of-tree rc/PDK exposure.
  - *Rejected:* uncommenting `lastsel != 1` at `src/actions.c:3654` verbatim — it inherits
    exactly the `INST_PIN` miscount this issue is about.

The two verbs therefore still disagree on identical state (C1: `descend_symbol` refuses,
`descend` accepts). That asymmetry is now **answered by speaking rather than by unifying** —
see "still open" in 0251.

## Coverage

`tests/headless/test_descend_symbol.tcl` rows R04 (two instances → `0` + `multi-selection`),
R05 (instance + own pin → `1`), R06 (instance + wire via `select_inside` → `1`).

Sabotage **S5b** (restore the true pre-fix rule: `lastsel > 1` for `descend_symbol` plus
`sel_array[0].type` for `descend`) turns R05 and R06 red with `ret={0} sch=descend_parent.sch`,
which is what proves these rows actually cover this issue. Note that the originally-planned
S5 variant did **not** move them — it reproduced `descend_schematic`'s legacy guard, not
`descend_symbol`'s — and Verify-B added S5b specifically to settle that. See the full
sabotage matrix in `doc/claude/code_analysis/descend_silent_refusal_census.md`.
