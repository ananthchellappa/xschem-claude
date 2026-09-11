# 1408 — ASE-L described a simulator it had never been told anything about

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C3** of Stage 2 of `doc/claude/ase_analyses_batch/` (plan item **2d**)

## The defect, measured

The Choose Analyses dialog asked `ase::analysis_offered` with **no argument** and
`ase::analysis_entry [ase::default_simulator] $t` for the label, and `ase::ui::chana_fields` /
`ase::ui::arg_summary` both defaulted `sim` to the default simulator. Measured against a bench
whose state says `simulator zznoad` — a backend registered with the five required hooks and **no**
`analysis_types` hook:

```
ase::analysis_offered zznoad   ->  {}                  the registry was RIGHT
ase::analysis_offered          ->  op dc ac tran       what the dialog asked for
ase::ui::arg_summary $row      ->  dc V2 0 1.8 0.01    an NGSPICE DECK LINE
```

So that bench was shown **ngspice's four radio buttons**, a **committable `dc` form**, and **an
ngspice deck line in the Arguments column** for a simulator that cannot render it. The machinery
underneath was correct the whole time; only the dialog never passed the session's simulator.

## What ships

**`ase::ui::chana_sim`** — the **one** resolver. Every other site takes the answer as an argument;
a second `$sim eq {}` default anywhere is a second place for the rule to drift, which is the
defect Stage 1 spent itself deleting. Six call expressions across five procs now pass it. *(The
plan said eight; measured, it is six — one `arg_summary` and five `chana_fields`, two of the
latter inside `chana_ok`.)*

**`ase::analysis_gap_msg`** — why the grid is empty, in ASE-L's voice, or `{}`.

⚠ **The sentence and the empty grid are keyed on the SAME question, and that is the whole
construction.** Keying the sentence on `ase::analysis_types` while the dialog's disable block keys
on `ase::analysis_offered` makes the two disagree for a backend that *declares* a type and
*registers* none — and the user gets a **wholly blank, dead, silent dialog**. D6's rule is four
states and never invisible. The proc returns non-empty **exactly when** `analysis_offered` is
empty, and row **AD1** asserts that biconditional directly.

⚠ **Three arms, because "not a backend at all" is a DIFFERENT FACT and the likelier case.** The
only doors to a non-ngspice `simulator` key are a hand-edited `.state` and the CIW — i.e. a
**typo**. Telling that user *"ASE-L has no adapter for this simulator yet"* is wrong twice: it
blames ASE-L, and it confirms a simulator that is not there. The distinguishing fact was already
in the tree and unused — `ase::backend_names`.

**Membership guards on all three commit doors** (`chana_ok`, `chana_options`, `chana_x_ok`) and a
preselect taken from the offered list rather than the literal `op`.

⚠ **`[info exists dlg($key,antype)]` is TRUE for an `antype` of `{}`** — the value an empty grid
leaves behind. That is how `chana_x_ok` would write **`{type {} enabled 0}`** into the bench: a
state key for a type that does not exist, round-tripping through the `.state` file forever. The
guards test **membership**, not existence, and sit on the **procs** rather than the buttons,
because a disabled Tk button's `invoke` returns `{}` and would hide the whole thing.

## The two rows that only exist because a sabotage went green

**`chana_x_ok`'s guard was unreachable in the row that was supposed to prove it.** That proc
returns early unless `dlg($key,anextra)` exists, and only `chana_options` sets it — which the
*previous* guard had just refused. With the guard deleted the suite still read `ALL PASS`. The
fixture now plants `anextra` and knocks on the door directly; the state it simulates is reachable
in the product (open Options under one simulator, change the bench's simulator, press OK).

⚠ **And the first attempt at that sabotage was itself malformed** — it deleted `set _sim` along
with the guard, so the proc *raised* instead of writing, and the `catch` in the fixture swallowed
it. **A sabotage that breaks the proc proves nothing.** Verified only once the guard alone was
removed and `$_sim` left in place: G14e **and** G14f then both redden.

## The blanking, recorded as a consequence rather than discovered later

⚠ Under a simulator ASE-L has no adapter for, **the `op` row's Arguments column goes blank.**
`arg_summary`'s dump arm emits the empty string for a row with no field keys and no extra keys,
and `op` — the one analysis every new bench opens enabled — is exactly that row. There is no deck
line to show, and the Type column beside it already says `op`, so the blank removes a redundant
echo rather than information. **It is on rule debt 1408 as a ratification, not asserted as
correct.**

## Verification

| suite | arm | before | after |
|---|---|---|---|
| `test_ase_core` (section **AD**, 7 rows — the schema half) | headless | 266 | **273** |
| `test_ase_dialogs` (section **G14**, 9 rows — the widget half) | display | 215 | **224** |
| `test_ase_dialogs` | headless | 37 | 37 (unmoved by design) |

⚠ **The schema half is arm-independent ON PURPOSE.** `run_regression.tcl` runs
`test_ase_dialogs` on **neither** arm — measured — so a receipt quoting a T1 zero has not
exercised one G14 row. Putting the contract in `test_ase_core` is what makes it survive that.
`test_ase_dialogs` also had **no floor paragraph at all**; it has one now, and it is two numbers,
because 37-vs-224 reported as one number reads as a floor that fell by 187.

**Six sabotage passes:** the dialog asking the default simulator again (G14a–e); the literal `op`
preselect (G14d, G14e); `chana_x_ok` losing its guard (G14e, G14f); the sentence keyed on
`analysis_types` (AD1, AD2); the Arguments column unthreaded (G14f); the three arms collapsed to
one sentence (AD2, AD3).

## Related

* **1405** — the same blind spot in a survey; its warning (*"a path survey must search for the
  variable too"*) is in the `chana_show` comment this commit edits.
* **1395** — the simulator choice is the bench's, which is what makes the session's `simulator`
  key meaningful here.
* ⚖ **R9** — four new sentences, all recommended shapes; rule debt **1408**.
