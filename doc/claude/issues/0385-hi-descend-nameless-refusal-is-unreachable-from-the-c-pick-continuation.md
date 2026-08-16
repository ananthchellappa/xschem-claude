# 0385 — the nameless-instance refusal is unreachable from the C verb-noun pick, which re-arms forever

Status: **OPEN** (measured, not fixed)
Found: 2026-08-10, crew item D6 adversary pass (`ATK-3`), immediately after the 0260 fix landed.
Area: `src/callback.c:4125` (`check_menu_start_commands()`'s descend-pick arm calls
`hi_descend_pick_done {<instname>}`); `src/xschem.tcl` `hi_descend_pick_done` (→ `after idle
[list hi_descend_dialog $instname]`), `hi_descend_dialog` (`:6285`), `hi_descend_pick_arm`;
`hi_descend_target_inst` (`:5852`) and `hi_descend_nameless_refuse` — the refusal that is *not*
on this path.
Tests: none. The 0260 rows (`NAMELESS-*` in `tests/headless/test_hi_descend.tcl`) are headless and
exercise the resolver route only; nothing drives the pick continuation with a nameless instance.
Related: **0260** (the fix this hole survives), **0257** (the pick path this is on), **0388**
(`selected_set` is name-keyed and unparseable), **0378** (the refusal channel).

## The defect

Issue 0260 put the "this instance has no `name=`" refusal in `hi_descend_target_inst`. The C
verb-noun pick never calls it. `check_menu_start_commands()` resolves the clicked instance itself
and hands **the instname** to Tcl:

```
src/callback.c:4125   hi_descend_pick_done {<instname>}
   -> after idle [list hi_descend_dialog $instname]
   -> hi_descend_dialog sees llength [xschem selected_set] == 0  (nothing is selected after a pick)
   -> hi_descend_pick_arm   <-- arms the pick AGAIN
```

With a nameless instance the instname is the empty string, so the dialog re-arms the pick every
time the user clicks the instance. Measured under xvfb on the `hi_descend` fixture with a
`name=`-less instance inserted:

```
arm the pick, click the nameless instance
  narm      1 -> 2
  ndialog   2      dlgargs = {<> <>}          <-- both invocations got an empty instname
  currsch   0                                  <-- nothing descended
  statusmsg the plain prompt, hold=1           <-- no refusal ever spoken
  echoes    the prompt, twice; hi_descend_nameless_refuse never reached
```

That is byte-for-byte the pre-0260 symptom ("gives up without a word"), on the exact path that the
0257 fix in the same item exists to make usable. A user clicking that instance gets an endless
polite prompt and no explanation.

## Why it was not fixed in D6

The D6 plan scoped 0260 to the resolver (`hi_descend_target_inst`) because that is where the
measured Measure-agent transcripts entered. The pick path was measured only in the adversary pass,
after the code had landed and after the last build. Fixing it is not a message change: the C arm
knows the instance **index** (`find_closest_instance()` has it) and Tcl is handed a **name**, so the
honest repair is either

* reject an empty instname in `hi_descend_pick_done` — it is the direct C→Tcl seam and knows nothing
  else is selected, so it can refuse and cancel instead of re-arming; or
* refuse in the C arm before calling it, which also stops the pointless `after idle` round trip; or
* stop keying the continuation by name at all and pass the index, which is what 0260's own "layer 3"
  and the D6 scout's consolidation both proposed.

## Also worth fixing while there

`hi_descend_dialog`'s "nothing selected → arm a pick" branch cannot distinguish "the user asked for
a pick" from "the pick already happened and produced nothing", which is what makes the loop
possible. A one-shot guard (or an explicit `-from-pick` argument) would make the second invocation
refuse rather than re-arm.
