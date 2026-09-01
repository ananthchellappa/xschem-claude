# 0927 — device OP-parameter saving was OFF by default, so every existing test bench showed blank rows

**Status:** **FIXED 2026-08-29.** Requested by the user the same day. Not a
defect report — a **default change the user ruled on**, filed here because it
inverts the meaning of a value that is written into user files.

**Spec:** [op_annotation.md](../specs/op_annotation.md) §4.3a
**Related:** 0617 (the blank rows), 0620 (the deck cost), 0637 (the truthy-gate
silence, item 1 now closed), 0648/0679/0692/0695/0696 (the Save All writer),
0909 (the blank-cause diagnosis)

---

## 1. What the user asked for

Verbatim, 2026-08-29:

> *"How do we save the Outputs > Save All > Save device OP params thing in the
> ngspice_state1? This only came into existence recently. Make it the default.
> So, a saved state would have to say NOT to save all OP params, so that users
> who start using existing test-benches don't need to do more work to get their
> OP info."*

## 2. The answer to the question, since it is the whole design

The tick is stored in the state view's own file — `ngspice_state1/<cell>.state`
— as one key, `save_op_params`, in the flat `key value` list `ase::state_load`
reads and `ase::state_serialize` writes.

It has one unusual property, and that property is what made the user's request
cheap: the key is in **`ase::omit_if_empty`**, so an *empty* value is not
written to the file at all. Before the flip that meant **"off costs nothing to
store, on writes `save_op_params 1`"**. Which is also why:

* **not one of the 104 committed `.state` files mentions the key** (measured:
  `git grep -l save_op_params -- '*.state'` → nothing), and
* **a bench the user deliberately unticked is byte-identical to one that never
  heard of the feature.** See §5.

## 3. What the user saw before the change

Open any test bench that predates the feature — which is all of them — run a
simulation, press `6`, and get **an empty six-row device block on every
transistor**. The remedy exists (*Outputs > Save All > Save device OP
parameters*), the tool even prints it (issues 0650/0679/0909), but it is one
more thing to do per bench, forever, on work the user already had.

## 4. The fix

The key becomes **tri-state**, and the *empty* value — the one that is not
written to disk — becomes the **default, which is on**:

| value in the state | gate |
|---|---|
| absent, or `{}` | **ON** — the default; every existing bench |
| `0`, `no`, `false`, `off` | **OFF** — the only thing a state file ever spells out |
| `1`, `yes`, anything else | **ON** |

Because the default is still the empty value, **the flip cost zero bytes on
disk**: the 104 committed states inherit the new default and the five load→save
byte-identity rows (F3/G3/R4/V4/R2) stayed green with no edit at all.

Two procs, and nothing else reads or writes the key raw:

* `ase::op_gate_on` (`src/ase.tcl`) — the one reader. `string is false -strict`,
  which is `-strict` precisely so `{}` does not count as false.
* `ase::op_gate_value` (`src/ase.tcl`) — the one writer, **new**. on → `{}`,
  off → `0`. `ase::ui::save_all_apply` calls it instead of spelling the
  literals itself.

### 4.1 Issue 0637 item 1 is closed by this, in the only direction left open

A state hand-edited to `save_op_params yes` used to read **OFF**, and the only
report was the nudge telling the user to tick a box they believed was ticked.
`yes` now reads ON; `no`/`false`/`off` read OFF rather than silently reverting
to the default. The polarity change forced a decision on the normaliser, so this
was not deferrable.

## 5. What is NOT fixed, and cannot be

**A deliberate OFF made before 2026-08-29 is not recoverable.** Off was `{}`,
which is absence, which is indistinguishable from a state that predates the key.
Those benches flip **on**. Unticking again writes `save_op_params 0` and sticks.

**The cost is now paid by default**: 468 `.save` cards on a 31-FET bench, ~3000
on a 500-device block (issue 0620), plus an `op_annot::save_cards` hierarchy
walk on every netlist. That is the trade the user asked for; one tick turns it
off per bench, and the tick now persists.

**The gate-off nudge still fires** when a state says `0` and an `op` analysis is
enabled. It now names a setting the user themselves turned off, which is the
right thing for it to say and no longer the common case.

### 5.1 ⚠ A PRE-EXISTING MESSAGE THIS CHANGE PROMOTES TO ROUTINE — the user's call

`ase::op_cards_capture` refuses to walk a **dirty** schematic (the provisional
0632/0633 refusal) and says so:

> ASE: no device OP save cards were added — this schematic has unsaved edits,
> and walking a dirty sheet rewrites the `~` autosave backups of ancestor cells
> you never touched (issue 0632, ruling pending). Save the schematic, then
> netlist again.

That sentence was previously reachable only by the minority who had ticked the
box. **With the gate on by default, every netlist of an unsaved sheet prints
it.** Two problems, neither created here and neither fixed here:

1. It is written in developer language — "walking a dirty sheet", "`~` autosave
   backups", "issue 0632, ruling pending" — which is what the user's PLAIN
   ENGLISH ruling (2026-08-27) was about.
2. The underlying 0632 ruling is still open, and this change is what makes it
   cost the user attention rather than sit latent.

Not rewritten in this change: `test_ase_core` C12/C13 assert on the sentence's
wording (`*unsaved*`, `*0632*`) on purpose, and rewording is a separate decision
about a separate issue. Raised with the user, 2026-08-29.

## 6. Acceptance — measured

All headless, on the dev display, after the change:

| suite | before | after |
|---|---|---|
| `test_ase_core` | 5 FAILED (168 passed) | **ALL PASS (178)** |
| `test_ase_final` | 15 FAILED (64 passed) | **ALL PASS (79)** |
| `test_ase_window` | 8 FAILED (219 passed) | **ALL PASS (227)** |
| `test_ase_dialogs` | 5 FAILED (169 passed) | **ALL PASS (174)** |
| `test_annot_blank_cause_0909` | 9 FAILED (18 passed) | **ALL PASS (27)** |
| `test_ase_persist` / `_final_gf180` / `_view` | ALL PASS | **ALL PASS, unedited** |

Every one of those failures was a test asserting the OLD default, and each fix
is the same shape: a row that means *"gate off"* now has to **spell the off
out**, because `ase::state_load` of a committed `.state` yields a gate-**ON**
state. That is the sharpest evidence the change landed where it was supposed to.

New rows that pin the polarity itself, so a silent revert cannot pass:

* `test_ase_core` C2 — the empty default reads ON; an **absent** key reads ON;
  only an explicit false reads OFF (`0 no false` vs `1 yes 2`); `op_gate_value`
  maps on → `{}` and off → `0`.
* `test_ase_core` C3 — `save_op_params 0` **is** serialized (off is what costs a
  key), and `1` still serializes too (the key is not write-only).
* `test_ase_final` F19j — the change detector's six answers, every one of which
  inverted.
* `test_ase_final` F19q — ON omits the key entirely, OFF serializes
  `save_op_params 0`. This is the row that proves the on-disk half.
* `test_ase_dialogs` G5c — the checkbutton starts **ticked** on a state that
  never mentions the key, and the untick → OK → reopen → retick → OK round trip
  writes `0` then `{}`.
