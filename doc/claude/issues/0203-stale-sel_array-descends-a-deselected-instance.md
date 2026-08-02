# 0203 — `xschem descend` after `unselect_all` descends into the instance that *was* selected

Status: **OPEN** — reproduced and measured, **not fixed**.
Filed 2026-08-01, found while confirming [0200](0200-descend-has-no-verb-noun-pick.md).
Area: `src/actions.c` (`descend_schematic` 3521-3525, 3542), `src/move.c`
(`rebuild_selected_array` 53-60), `src/select.c` (`unselect_all` 1066-1069).
Tests: none yet.
Related: [0200](0200-descend-has-no-verb-noun-pick.md) — any verb-noun arm has to ask
"is anything selected?", and this is the trap in that question.

## The bug

`descend_schematic()` decides what to descend into by reading **one slot** of a cache it
does not validate:

```c
/* src/actions.c:3521 */
rebuild_selected_array();
if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
  dbg(1, "descend_schematic(): wrong selection\n");
  return 0;
}
...
/* src/actions.c:3542 */
n = xctx->sel_array[0].n;
```

The `lastsel` test is commented out, so the guard is only "slot 0 says ELEMENT". Nothing
ever clears that slot:

```c
/* src/move.c:53 */
void rebuild_selected_array()
{
  ...
  if(!xctx->need_reb_sel_arr) return;   /* early out: slot 0 keeps its old contents */
  xctx->lastsel=0;                      /* only the count is reset */
```

and `unselect_all()` (`select.c:1066-1069`) clears the per-object `.sel` flags and
`lastsel`, but never writes `sel_array`. So after a deselect, slot 0 still names the last
instance that was selected, and the guard waves it through.

## Reproduce

`--nogui`, `src/xschem` built 2026-08-01 12:09, at `f166e592`:

```tcl
xschem load [file normalize xschem_library/examples/0_examples_top.sch]
set target {}
foreach {i s t} [xschem instance_list] { if {$t eq {subcircuit}} { set target $i; break } }
xschem select instance $target fast
xschem unselect_all
puts "after unselect sel=[xschem selected_set] lastsel=[xschem get lastsel]"
puts "descend after unselect: rc=[xschem descend] current=[xschem get current_name] currsch=[xschem get currsch]"
```

```
target=x1
sel={x1}
after unselect sel= lastsel=0
descend after unselect: rc=1 current=poweramp.sch currsch=1
```

Nothing is selected — `selected_set` is empty, `lastsel` is 0 — and the descend still
happened, into `x1`'s schematic.

Contrast the clean-start case (measured in [0200](0200-descend-has-no-verb-noun-pick.md)):
a fresh load with nothing ever selected returns `0` and stays at `currsch=0`, because slot
0 is still zeroed. The defect needs one prior selection to arm it.

## Why it matters now

The Tcl path is unaffected today — `hi_descend_target_inst` asks `xschem selected_set`,
which calls `rebuild_selected_array()` and iterates `0..lastsel`, so it correctly reports
"nothing selected". The exposure is:

1. **Scripts and replayed action logs** that call `xschem descend` directly after an
   `unselect_all` get a descend they did not ask for. `xschem descend` is the form the
   toolbar `EditPushSch` button and `hi_descend_current` (`xschem.tcl:5788`) both use.
2. **[0200](0200-descend-has-no-verb-noun-pick.md)'s verb-noun arm** has to branch on "is
   anything selected". If it branches in C on `sel_array[0].type`, it will take the
   noun-verb path against a phantom selection and descend into the wrong instance instead
   of arming the pick. The correct test is `lastsel` after `rebuild_selected_array()` —
   which is exactly the check that is commented out on line 3522.

## Decisions

### D1 — restore the `lastsel` guard, or scrub the array? — OPEN
Cheapest: uncomment `xctx->lastsel != 1 ||` (or use `xctx->lastsel < 1`, to keep today's
"first of several wins" behaviour, `xschem.tcl:5669`). Safer but broader:
`rebuild_selected_array()` zeroes slot 0 when it sets `lastsel = 0`. The second fixes every
other reader of a stale slot at once — and there may be others; **that census has not been
done**.

### D2 — is `lastsel != 1` or `lastsel < 1` the right predicate? — OPEN
They differ for a multi-object selection. `lastsel != 1` is what the original author wrote
and then disabled; `lastsel < 1` matches what the Tcl layer does today. Whichever is
chosen, `hi_descend`'s "first selected instance wins" comment and spec §2's "exactly one
instance must be selected" are already in disagreement — pick one and fix the spec.

### D3 — why was it commented out? → upstream, 2023, to let `Alt-e` descend — CONFIRMED
`git log -S "xctx->lastsel !=1 ||" -- src/actions.c` gives **`8d155af8`**, stefan schippers,
2023-11-20, *"`Alt-e` does a true descend sub-schematic and opens it in another window"*.
The guard was disabled so a descend could proceed with a selection that was not exactly one
object — i.e. the intent was to *relax* it, not to permit a phantom. `lastsel < 1` therefore
preserves the author's intent while closing this hole; `lastsel != 1` would re-break
`Alt-e`. That makes D2's answer **`lastsel < 1`**, unless someone finds a counter-case.

## Cross-references

* `doc/claude/issues/0200-descend-has-no-verb-noun-pick.md` — the consumer that trips on this.
* `doc/claude/specs/hi_descend.md` §2 — the "exactly one instance" claim that the code does
  not implement.
