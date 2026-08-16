# 0255 — a text co-selected with an instance blocks descend_schematic; a wire does not

Status: **CLOSED** (2026-08-10, crew item D6 — headline fixed by D4's `descend_pick_target()`,
surviving verb-vs-verb split ratified; see Resolution at the end). Original text follows.
Status was: **OPEN** — reproduced and measured headless for all six co-selected object types; the
GUI silence is argued from the call sites (`src/callback.c:4510`, `src/xschem.tcl:12599`) and
from the fact that the refusal is `dbg(1)`, not observed on a live display.
Area: `src/actions.c` `descend_schematic()` (`:3589-3593`, target read at `:3610`);
`src/move.c` `rebuild_selected_array()` (`:53-142`); `src/select.c` `select_inside()` (`:2048`);
callers `src/callback.c:4510`, `src/callback.c:6453`, `src/scheduler.c:3002`
Tests: none yet — proposed `tests/headless/test_descend_mixed_selection_0255.tcl`
(the existing descend tests all select exactly one instance: `tests/headless/test_descend_fidelity.tcl`,
`test_descend_symbol.tcl`, `test_verb_noun_descend_0200.tcl`)
Found: 2026-08-08, in the descend silent-refusal census
(`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0203](0203-stale-sel_array-descends-a-deselected-instance.md) (same slot-0 read, the
*stale* half — this is the *live-but-wrong-type* half; one fix closes both),
[0249](0249-descend-symbol-silently-refuses-any-multi-selection.md) (`descend_symbol()`
refuses **any** multi-object selection, so the two verbs disagree),
[0251](0251-a-refused-descend-has-no-return-channel.md) (the `0` this returns is discarded),
[0253](0253-descend-semaphore-thresholds-disagree-and-a-zero-is-misread.md),
[0200](0200-descend-has-no-verb-noun-pick.md) (RESOLVED)

## The defect

`descend_schematic()` decides what to descend into by reading **one slot** of the selection
cache, and rejects the whole gesture on that slot's type:

```c
/* src/actions.c:3589-3593 */
 rebuild_selected_array();
 if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
   dbg(1, "descend_schematic(): wrong selection\n");
   return 0;
 }
```

and, if it passes, takes the target from the same slot:

```c
/* src/actions.c:3610 */
   n = xctx->sel_array[0].n;
```

Slot 0 is not "the first thing the user picked". `rebuild_selected_array()`
(`src/move.c:53`) refills `sel_array[]` by walking the object arrays **in a fixed type
order**, discarding selection order entirely:

| order | type written | `src/move.c` |
|---|---|---|
| 1 | `xTEXT` | `:61-68` |
| 2 | `ELEMENT` (instances) | `:69-76` |
| 3 | `INST_PIN` (per selected pin) | `:81-93` |
| 4 | `WIRE` | `:94-101` |
| 5 | `ARC`, `xRECT`, `LINE`, `POLYGON`, per layer `c` | `:102-136` |

Texts are written **before** instances. Everything else is written **after**. So the
predicate `sel_array[0].type != ELEMENT` is, in practice, exactly the predicate
"is any text selected?" — nothing to do with how many objects are selected, or with which
one the user meant.

Consequence, on the same user gesture (one rubber band over a region):

- band encloses instance + a **text** (a comment, an annotation, a `@symname`-style label
  placed as a standalone text object) → slot 0 is the text → **refused**;
- band encloses instance + a **wire / rect / line / poly / arc / its own pins** → the
  instance still lands in slot 0 → **descends normally**.

The commented-out `xctx->lastsel != 1` term is why the second row works: multi-object
selections were deliberately tolerated at some point, and the type test was left behind as
the only gate. It is a type test doing duty as a cardinality test, and it gets the
cardinality question wrong in both directions — it accepts `{instance, wire, rect}` (three
objects, descends into the instance without saying so) and rejects `{text, instance}` (two
objects, one of which is unambiguously the target).

**The refusal is silent.** `dbg(1, ...)` is below the default debug level
(`src/globals.c:166` `int debug_var=-10;` → `src/xinit.c:3364` `if(debug_var==-10) debug_var=0;`;
`src/util.c:267` prints only `if(debug_var>=level)`), so it reaches neither a terminal-launched nor a
desktop-launched user. There is no `statusmsg`, no `ciw_echo`, no `alert_`. The `alert`
parameter of `descend_schematic()` does not help: within the function it is used at exactly
one place, `src/actions.c:3737` (`descend_ok = load_schematic(1, filename, (set_title & 1), alert);`),
which is 147 lines *after* the guard. Callers that pass `alert=1` — the right-click context
menu (`src/callback.c:4510`, `:4513`) and the raw C `e` handler (`src/callback.c:6453`) —
get nothing for this refusal.

**Reachable from the GUI with no message at all.** The context menu offers the item for any
non-empty selection, whatever it contains:

```tcl
/* src/xschem.tcl:12599 */
  set selection  [expr {[xschem get lastsel] > 0}]
/* src/xschem.tcl:12615-12618 */
  if {$selection} {
    button .ctxmenu.b12 -text {Descend schematic} ... -command {set tctx::retval 12; destroy .ctxmenu}
```

and `src/callback.c:4510` throws the result away (`descend_schematic(0, 1, 1, 1);` as a
statement). The user right-clicks on a selection that visibly contains the instance they
want, picks "Descend schematic", and the canvas does not change. Nothing is printed,
nothing is logged at the default level, the menu closes as if it had worked.

`select_inside()` (`src/select.c:2048`) selects texts (`:2086`) and instances (`:2110`)
alike (`:2111`), so producing the failing selection needs no unusual gesture — one rubber
band over a device that has a comment next to it is enough.

**Two paths are immune, for accidental reasons.** The default `e` key is bound to the Tcl
chooser, not to this function: `src/xschem.tcl:14175` binds `<Key-$hi_descend_key>` to
`hi_descend_keybind_script` (`src/xschem.tcl:6272`), which forwards to C only when
`%s & 0x4c`. `hi_descend_current()` then does `xschem unselect_all` and re-selects the one
instance by name (`src/xschem.tcl:5908-5911`) before calling `xschem descend`, so the C
guard always sees a clean single-ELEMENT selection. Likewise `xschem descend -inst <name>`
(`src/scheduler.c:2991-2993`) unselects and re-selects. The comment at
`src/xschem.tcl:5766-5769` — "a mixed rubber-band selection (instance + wires/text) still
descends into the instance, matching the old C descend's `sel_array[0]` behaviour" — is
**wrong for text**: the C descend does not descend in that case. The Tcl layer is not
matching the C behaviour there, it is quietly repairing it.

## Reproduce

Fixture: `tests/headless/fixtures/descend/` (`descend_parent.sch` holds one instance `x1`
of `descend_child.sym` plus one wire). Each trial reloads the parent, builds the selection,
then calls `xschem descend` — whose result is `descend_schematic()`'s return value
(`src/scheduler.c:3002`, `:3006`).

```
$ ./src/xschem --nogui --pipe -q --nolog --script .../repro_0255.tcl
--- baseline: instance alone
  inst only: lastsel=1 selection={{instance 0 1 1}}
  inst only: xschem descend -> '1'   currsch=1  schname=descend_child.sch
--- instance + TEXT
  inst+text: lastsel=2 selection={{text 0 3 1} {instance 0 1 2}}
  inst+text: xschem descend -> '0'   currsch=0  schname=descend_parent.sch
--- instance + WIRE (wire 0 already in the fixture)
  inst+wire: lastsel=2 selection={{instance 0 1 3} {wire 0 1 6}}
  inst+wire: xschem descend -> '1'   currsch=1  schname=descend_child.sch
--- instance + RECT (layer 4)
  inst+rect: lastsel=2 selection={{instance 0 1 4} {rect 0 4 0}}
  inst+rect: xschem descend -> '1'   currsch=1  schname=descend_child.sch
--- instance + LINE (layer 4)
  inst+line: lastsel=2 selection={{instance 0 1 5} {line 0 4 698}}
  inst+line: xschem descend -> '1'   currsch=1  schname=descend_child.sch
--- instance + POLY (layer 4)
  inst+poly: lastsel=2 selection={{instance 0 1 6} {poly 0 4 699}}
  inst+poly: xschem descend -> '1'   currsch=1  schname=descend_child.sch
--- instance + ARC (layer 4)
  inst+arc: lastsel=2 selection={{instance 0 1 7} {arc 0 4 700}}
  inst+arc: xschem descend -> '1'   currsch=1  schname=descend_child.sch
--- TEXT only (control)
  text only: lastsel=1 selection={{text 0 3 2}}
  text only: xschem descend -> '0'   currsch=0  schname=descend_parent.sch
```

`xschem selection` prints rows in `sel_array[]` order, so the transcript also shows the fill
order directly: the text row precedes the instance row; the wire/rect/line/poly/arc rows
follow it.

The real gesture, not a synthetic selection — one rubber band, two sizes:

```
band over instance only : sel={{instance 0 1 1}}
  descend -> 1  currsch=1
band over instance + text: sel={{text 0 3 2} {instance 0 1 2} {wire 0 1 5}}
  descend -> 0  currsch=0
```

Widening the band to take in one annotation text flips a working descend into a no-op.
Note the second band also caught a wire, which changed nothing: only the text matters.

Silence, and the pin cases:

```
$ ./src/xschem --nogui --pipe -q --nolog --script .../repro_0255b.tcl     # default -d
sel={{text 0 3 1} {instance 0 1 1}}
descend -> 0  (expect the dbg(1) line ONLY at -d 1)
pin-only sel={{pin 0 0 2}} lastsel=1
descend -> 0  currsch=0
inst+pin sel={{instance 0 1 3} {pin 0 0 3}}
descend -> 1  currsch=1

$ ./src/xschem --nogui --pipe -q --nolog -d 1 --script .../repro_0255b.tcl 2>&1 | grep -i "wrong selection"
descend_schematic(): wrong selection
descend_schematic(): wrong selection
```

Nothing on stderr at the default level; the diagnostic exists only at `-d 1`. A selection of
**pins only** (no `inst.sel`) also refuses silently, for the same slot-0 reason —
`INST_PIN` sorts after `ELEMENT`, so it is only slot 0 when no instance body is selected.
That is arguably the correct answer, but it is delivered the same wordless way.

The disagreement with `descend_symbol()` ([0249](0249-descend-symbol-silently-refuses-any-multi-selection.md)),
measured on one selection:

```
inst+wire sel={{instance 0 1 1} {wire 0 1 1}}
  descend        -> 1         currsch=1
  descend_symbol -> currsch=0 schname=descend_parent.sch
```

Same selection, same two adjacent context-menu items (`.ctxmenu.b12` at
`src/xschem.tcl:12616`, `.ctxmenu.b13` at `:12630`): one works, one does nothing and says
nothing. `descend_symbol()`'s guard is the opposite shape —
`if(xctx->lastsel > 1) return 0;` then `if(xctx->lastsel==1 && ...ELEMENT)`
(`src/save.c:5562-5564`), i.e. strict cardinality with no diagnostic at all (not even a
`dbg`).

GUI-only, not measured: the claim that a right-click → "Descend schematic" on such a
selection produces no visible feedback. It follows from `src/callback.c:4510` discarding the
return and from the absence of any user-facing emitter between `:3589` and `:3593`, but it
was not observed on a live display.

## Fix, if it is to be closed

The guard and the target read must stop being "slot 0". Scan the selection for the first
`ELEMENT` and use that:

```c
 rebuild_selected_array();
 {
   int s, target = -1;
   for(s = 0; s < xctx->lastsel; ++s) if(xctx->sel_array[s].type == ELEMENT) { target = s; break; }
   if(target < 0) {
     statusmsg("Descend: select a component instance to descend into.", 2);
     dbg(1, "descend_schematic(): no instance in selection\n");
     return 0;
   }
   n = xctx->sel_array[target].n;      /* replaces the read at :3610 */
 }
```

Three points that decide whether this is right:

1. **Do not uncomment `xctx->lastsel != 1`.** That would make instance+wire, instance+rect
   and instance+pin refuse as well — today they all descend (measured above), and a
   rubber-band selection around a device almost always drags a wire in. Restoring strictness
   is a behaviour break with no user benefit, and it would spread this issue to the
   four types that currently work rather than curing it for the one that does not.

2. **Say something.** Whatever the policy, a refusal must reach the user. `statusmsg` is the
   cheapest channel that works for both terminal- and desktop-launched sessions, but note
   [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md) —
   status-bar text is wiped by later redraws, so
   for the context-menu path an `alert_`/`ciw_echo` may be needed instead. Also worth
   emitting *when the scan disambiguates*: "several instances selected, descending into
   `x1`" is information the current code has and throws away.

3. **Stop the two verbs disagreeing.** `descend_schematic()` (tolerant, type-gated) and
   `descend_symbol()` (strict, count-gated) should share one selection resolver — call it
   `descend_target_instance(void)` returning the instance index or `-1` — so that a selection
   that descends into the schematic also descends into the symbol, and a selection that is
   refused is refused identically by both, with the same message. That is the shared half of
   this issue and [0249](0249-descend-symbol-silently-refuses-any-multi-selection.md).

The same resolver closes [0203](0203-stale-sel_array-descends-a-deselected-instance.md)'s
half if it also fixes the staleness: `rebuild_selected_array()` early-returns on
`if(!xctx->need_reb_sel_arr) return;` (`src/move.c:59`), so `sel_array[]` can hold a valid
row for an object that is no longer selected. A resolver that bounds its scan by
`xctx->lastsel` **and** re-checks `xctx->inst[n].sel` before returning `n` fixes both the
wrong-type and the stale-entry failures in one place. 0203 is the stale half; this is the
live-but-wrong-type half.

Test to add, `tests/headless/test_descend_mixed_selection_0255.tcl`: the seven-row table
above as assertions (instance alone descends; instance + each of text/wire/rect/line/poly/arc
descends; text-only and pin-only refuse), plus the `descend`/`descend_symbol` agreement row.
It is a pure return-value test, so it needs no display.

## Risks

- **Multi-instance selections become live.** Today `{instA, instB}` descends into whichever
  instance has the lower array index (slot 0 among the ELEMENT rows) — undocumented but
  deterministic. A first-ELEMENT scan keeps exactly that behaviour, which is the safe
  choice; anything else (refuse, or prompt) changes a working flow. Note `hi_descend`
  already picked the same rule for its own path
  (`src/xschem.tcl:5769`, "Descend into the first selected instance when several are
  selected"), so the two layers would finally agree.
- **A newly-audible refusal is a behaviour change for scripts.** Adding `statusmsg` to a
  path that fires whenever a text is co-selected could spam the status bar in a loop that
  descends repeatedly. Gate on the interactive callers (`alert != 0`) if that turns out to
  matter — but do *not* leave the context-menu path silent, which is the whole complaint.
- **`descend_symbol()` loosening is the riskier half.** Making it tolerate multi-selection
  changes which cell gets opened for editing; its embedded-symbol branch
  (`src/save.c:5572-5579`) has a save-prompt exception keyed to the resolved instance `n`,
  so the resolver must be wired in before that branch, not after.
- **Selection-order semantics are still absent.** Neither this fix nor
  [0200](0200-descend-has-no-verb-noun-pick.md)'s makes `sel_array[]` remember what the user
  clicked first; "first ELEMENT" means lowest instance index, which is not the same as
  "the one I clicked". If a future change gives the selection a true order, this resolver is
  the single place that has to learn about it.
- **No coverage today.** Every descend test in `tests/headless/` selects exactly one
  instance, so any change to this guard is currently unguarded in both directions.

---

## Resolution — crew item D6, 2026-08-10 — CLOSED, no code change

**Status: CLOSED.** The headline defect no longer exists in the tree: it was closed by D4
(commit `b1326180`), which gave both descend verbs a shared first-ELEMENT resolver
`descend_pick_target()` (`src/actions.c:3715`). What survived measurement is only point 3 —
the two verbs disagree on a multi-selection — and that divergence is hereby **ratified as
deliberate** and locked by tests. No code was written for this issue in D6.

### Measured BEFORE (D6 Measure, on a freshly rebuilt binary — the on-disk `src/xschem` was stale)

```
A2 inst+text     : descend                 ret={1} err_pre={} err_post={} currsch=1 cell=descend_child.sch
A5 two instances : descend                 ret={1} err_pre={no-instance-selected} err_post={} currsch=1 cell=descend_child.sch
A6 two instances : descend_symbol          ret={0} err_pre={} err_post={multi-selection} currsch=0 cell=parent.sch
```

`A2` is this issue's headline case (`instance + text`) and it **descends**, returning 1 and landing
on the child. Text-only and wire-only selections refuse with the token `no-instance-selected` and a
**held** status line `Descend: select an instance to descend into`. So the silence is gone and the
false refusal is gone; `descend_schematic()` no longer reads `sel_array[0]` blind.

`A5`/`A6` are the residue: `xschem descend` is permissive on a multi-selection (first ELEMENT wins),
`xschem descend_symbol` is strict (`multi-selection`).

### Decision D9 — ratify the split (ladder rung R1)

The divergence is already **encoded in the source as a parameter**, not an accident:
`descend_pick_target(&n, multi_ok, verb)` is called with `multi_ok=1` at `src/actions.c:3803`
(descend) and `multi_ok=0` at `src/save.c:5573` (descend_symbol). R19 of
`tests/headless/test_descend_refusal_channel_0251.tcl` already pins the permissive half **on
purpose**. Rung R1 applies: "whatever you just pressed is what you meant" — a user who presses the
descend key with several things selected means the instance under the cursor's intent, while
`descend_symbol` opens a cell **for editing** and must not guess which one.

**Rejected alternative:** unify both verbs behind one policy. It would break R19 by design, and it
changes *which cell opens for editing* — `descend_symbol`'s embedded-symbol branch
(`src/save.c:5572-5579`) has a save-prompt exception keyed to the resolved instance, so a loosened
resolver must be wired in before that branch, not after. That is a separate, larger decision.

### AFTER — the whole measured table is now locked by tests

New section E in `tests/headless/test_descend_refusal_channel_0251.tcl` (34 → 45 checks):

* **R30** — an instance co-selected with each of wire / rect / line / poly / arc descends into the
  instance (5 checks, one per type).
* **R31** — text-only and wire-only selections refuse with the exact token `no-instance-selected`
  **and speak it held**.
* **R32** — the ratified split: with two instances selected `xschem descend` == 1 while
  `xschem descend_symbol` == 0 with `descend_error` == `multi-selection`.

A future unification now has to break R32 on purpose, which is the point.

### Sabotage evidence (Verify-B)

`SAB-PICKTARGET` — `#define descend_pick_target(n,m,v) 0` immediately after its definition in
`src/actions.c`, so only `descend_schematic()`'s call is neutralized and `save.c`'s is not:
R30 ×5, R31 ×4 and R32 all went red, with R32 reading `descend=0` while the `descend_symbol` half
still read `0/{multi-selection}` — the row discriminates the two verbs exactly as designed.
Predicted collateral on R18/R19 (same callee) also appeared.

### Still open

* Four different multi-selection policies now coexist across four entry points and none is wrong on
  its own: `descend` permissive (R32), `descend_symbol` strict (R32),
  `cadence::one_instance_selected` exactly-one (issue 0259), `hi_descend_target_inst` `lindex 0`
  (issue 0260). Nothing reconciles them; R32 records the two that matter.
* Selection *order* is still absent: "first ELEMENT" means lowest instance index, not "the one I
  clicked first". If the selection ever gains a true order, `descend_pick_target()` is the single
  place that has to learn it.
