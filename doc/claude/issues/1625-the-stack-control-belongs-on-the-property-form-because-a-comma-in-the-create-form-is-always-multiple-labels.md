# 1625 — the stack control belongs on the property form, because a comma in the create form is always multiple labels

**STAMP:** `v1 claim=fixed tree=c5a11808 stamped=2026-09-30 fix=taken open=4`

Status: **FIXED**, 2026-09-30. Corrects the **placement** of issue 1623's control, not its substance.
Measured on this tree at `c5a11808` · Branch: `fluid-editing`
Related: issue **1623** (the stacked bus label itself — its rendering half is untouched here); batch
`doc/claude/wire_label_vjust_batch/`, receipt `receipts/B-move-vjust.md`;
`doc/claude/specs/wish_list.txt` new-list item **2**; the fence is
`tests/headless/test_add_wire_label.tcl`, now registered in **both** lists.

## The user's ruling, which is the whole issue

> *"When commas are used in the create form, that's multiple labels, not a bus. So the user can only
> specify bits of a bus using the property edit form."*

Two operations that must not share one comma:

* **Add Wire Label form**, comma-separated entry → **N separate labels**, one per click, on N
  different wires. The existing queue behaviour, now unconditional.
* **A bus label** — one label on one bus wire whose value is a comma-separated bit list such as
  `bg_trim[3:0],en_fast,iref_trim[2:0]` — is authored on the **Edit Properties** form.

## What issue 1623 got wrong

1623 put a "Vertically justified" checkbox on the **create** form and made it change **tokenisation**:
`addlabel::start_pass` carried `if {$vjust} { … set pending [list [join $toks ,]] }`, so ticking it
collapsed the typed comma list into one label. Under the ruling that is backwards.

And it follows **mechanically** from the user's own diagnostic — *"`busname<3:0>` will not render any
different with vertical justification"* — that the control could never have belonged there: once
commas always split, every label the create form produces is a **single token**, and a single token
cannot stack. **The control had nothing to act on where it was put.**

## What shipped

* **`src/xschem.tcl`** — `addlabel::vjust` removed; `addlabel::start_pass` reduced to the single
  unconditional `set pending [addlabel::expand_names $name $split_bus]`;
  `addlabel::on_vjust_change` deleted; the checkbutton and its `grid` line removed from
  `addlabel::open`. `addlabel::arm` now publishes `set ::label_new_vjust 0` — **actively cleared, not
  merely unset**, because `place_wire_label()` still reads that global and one stray `1` would stack
  every label placed thereafter.
* **`src/property_form.tcl`** — new `slickprop::symbol_type`, `slickprop::inst_schema`,
  `slickprop::inst_owned` and `slickprop::inst_bool_value`, with `build_fields`, `field_value` and
  `edit_form` taught to render and read a bool row. One row: `{tok vjust label {Stack V} widget bool
  on 1}`, offered when the symbol's `type` is `label`. **Keyed on type, not file name**, so a
  user's own label cell gets it too. `inst_owned` is **derived from `inst_schema`**, never hand-kept.
* **`sym_text_vstack()` and its six call sites are untouched** — `git diff` against `15b76bae` shows
  every `.c` and `.h` in the tree byte-identical. There is no C change in this issue.

**Wording: `Stack V`.** Chosen to match the same form's existing `Center H` / `Center V` vocabulary —
verb plus axis letter — and because it says what happens. "Vertically justified" was typographically
wrong: justification is alignment to a margin, not stacking.

## Red first

Nine rows written and run against the unfixed tree, every one **FAILED and none THREW** (the suite's
`v_try` wrapper turns a missing command into a legible `threw (invalid command name "…")` sentinel):

```
FAIL: V19 the create form owns NO vjust variable, and a stray one planted in its namespace cannot
      collapse the comma list into one label -> {1 1 {bg_trim[3:0],en_fast,iref_trim[2:0]}} (exp {0 3 {bg_trim[3:0]}})
FAIL: V24 the create-form control is GONE FROM THE SOURCE, not merely inert -> {1 1 1} (exp {0 0 0})
FAIL: V25 slickprop::inst_schema offers exactly ONE bool row for a type=label symbol
      -> {threw (invalid command name "slickprop::inst_schema")} (exp {1 vjust bool 1})
FAIL: V27 GUARD a non-label symbol is offered NOTHING -> {threw …} (exp {0})
RESULT: 9 FAILED (224 passed)
```

Green: **234** checks headless, **223** on the display arm (driver-re-verified both after its own
edits). No row was deleted: exactly five row **names** changed and all five are the same row **IDs**
restated, verified by extracting every `check` name and running `comm` against `15b76bae` — **zero row
IDs lost**.

## Adversarially verified, and the verification earned its keep

Three independent lenses, all **not refuted**:

* **Rendering intact** — `NONE`. Every `.c` byte-identical to `15b76bae`; the six call sites confirmed
  by `awk` on the enclosing function rather than by the receipt's word; and the stack re-measured four
  independent ways on the modified tree (bbox heights in arithmetic progression, `select_at` hitting
  the flagged label and missing the unflagged twin, SVG text elements, and `translate … @lab` with
  **zero** newlines).
* **Commas always split** — `REAL_BUT_MINOR`, see below. Ten flag permutations, including planted
  stray globals, all yield three pending labels; `split_bus 1` correctly yields eight.
* **No deleted rows / netlist boundary** — `NONE`. The V19 restatement was *proven* a fence by runtime
  sabotage (restoring 1623's `start_pass` reddens `V19` and `V24`).

### ⚠ Two things the verification caught that both the crew and the driver had missed

1. **Two shipped comments asserted a mechanism that does not exist.** They claimed
   `addlabel::split_display_tokens` was "still reached as the per-token splitter inside
   `addlabel::name_ok`'s comma-list arm — the validator a comma-containing `lab=` must pass". Measured
   false: `name_ok`'s only production caller is `addlabel::arm`, `start_pass` → `expand_names` has
   stripped every comma by then (instrumented: `any_arg_with_comma = 0`), and
   `grep -c 'addlabel\|name_ok' src/property_form.tcl` is **0**, so the Edit Properties route never
   passes through it. Both comments were rewritten to record the false claim and why it was believed
   twice — the same shape as the `/* select all */` comment that misled issue **1617**.
2. **The new checkbox was fenced by rows T1 never ran.** Rows `V33`–`V38` drive real Tk widgets and
   self-skip under `--nogui`, and `test_add_wire_label` was registered in `hcases` **alone** — so the
   gate executed none of them. Fixed by registering the `dcases` arm in the same change, which is
   CLAUDE.md's bounded rule applied to a fence that already existed.

## ⚠ And the driver wrote down a number that was wrong, then caught it

Registering the second arm, both the verifier **and** the driver predicted the trailer would move off
`skips=8`. **Both were wrong.** This suite announces its skipped bands with an **uppercase `SKIP:`**
at three sites, and `summarize_all` counts `^skip:` lowercase — its own `regexp {^skip:}` arm. The
correct expectation is **112 → 113 cases, 111 → 112 blocks, `skips=` unchanged at 8**, the same
mechanism `test_replay_door_1619` used, making this the second both-lists entry to cost no skip and the
**sixteenth** consecutive 8. Caught by checking before the claim was committed rather than after the
gate contradicted it.

## Still open (open=4)

1. **`place_multiple` is still an inert checkbox** on the create form — the remaining half of wish
   item 2. The recon's reframing stands: a comma already separates, so "place multiple in one shot" is
   a question about which gesture the user wants, not a missing capability.
2. **`addlabel::name_ok`'s comma-list arm and `addlabel::split_display_tokens` are now reached only by
   test rows**, not by the product. Both are kept deliberately — the arm states that a comma list is
   legal and is checked per token, and the splitter is the Tcl-side statement of the display-line
   contract `sym_text_vstack()` implements — but a reader should know the product does not exercise
   them. Recorded in both comments rather than left to be rediscovered.
3. **`rule/1623` is dissolved but still on the user's queue.** Its question — what to say when "Split
   bus" is silently ignored because "Vertically justified" is ticked — describes a state that can no
   longer be entered: measured live on `:99`, `.addlabel.f`'s children are exactly
   `{lname ename split multi}` and `winfo exists .addlabel.f.vjust` is 0. Only the user clears a
   `rule` debt, so it stays until they say so.
4. **The two `look` debts from issue 1623 carry over unchanged** — the stack is left-aligned with a
   ragged right edge, and it grows downward across the wire. Both pre-existing renderer behaviour.
