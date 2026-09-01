# 0963 — a run never says how it asked for device numbers, and there is no way to choose

Status: ✅ **FIXED 2026-08-30.** Reds proved first by
`tests/headless/test_ase_optier_0963.tcl` (38 red / 7 green at HEAD c42c5c9e,
identical on the headless arm and on the dev display); **45/45 green after the
fix, on both arms.** Design of record:
`doc/claude/specs/op_annotation.md` §4.3b.

## What the user sees today

They tick Outputs > Save All > save device operating-point parameters on their
own bandgap bench and press Run. The deck grows by 468 lines — six separate
requests for each of 78 transistors — and one sentence appears in the CIW:

    ASE: 468 device OP save card(s) added to the deck.

That is everything they are told. Nothing says which of the possible ways of
asking was used, or why, or that their simulator was asked what it can do and
the answer was then thrown away.

## Measured before-state (HEAD c42c5c9e)

* `ase::sim_capabilities ngspice` answers
  `known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1`.
* That answer has exactly ONE production reader, `ase::cap_report`, which warns
  about three unrelated things and never touches the deck.
* `grep` over `src/*.tcl` for any tier selection or override: nothing exists.

## The three forms, and the traps measured on each

* **blanket** — one device-less request. No released ngspice can do it, so it is
  cold code by construction and has to be exercised by a stand-in that claims
  the capability.
* **one write line** — `write <raw> all @dev1 @dev2 …`. THREE measured traps:
  (1) bare `@dev` on a multi-point write is silently wrong (`dims=1`, one
  non-zero sample parked at index 0); (2) the line holds at most **998** names
  (999 prints `write: too many args.`, writes no file, exits 0) and a SPLIT
  write produces two plots both called `Operating Point`; (3) **one unresolvable
  device name aborts the WHOLE write** — measured on `tb_bandgap`, where two of
  the 78 names this tree emits cost the per-device form 12 blank rows out of 468
  and cost the write-line form the ENTIRE operating point, at exit 0.
* **per-device** — today's cards, unchanged.

## Also measured, and it is where the win actually is

See issue **0964**: the per-device cards ride every time point of the transient.


## What landed

`ase::op_save_tier <state>` returns `{tier a|b|c reason <token> ndev N ncards M}`
from six ordered guards, and `ase::backend::ngspice::render_deck` switches on it.
The full table, the reason tokens and the measurements behind each are in
**§4.3b of the spec**; the short version:

* **G2 tests `known` FIRST and by its own key** — a capability answer with no
  keys at all is *nothing was measured*, never *no to everything*. Row T11 pins
  the ordering structurally, because nothing behavioural can tell a missing key
  from a measured 0.
* **G4 demotes the one-write-line form to per-device even when the simulator
  would accept it**, because one unresolvable device name throws the entire
  operating point away at exit 0 (issue **0965**). Rows T4 and T12 — T12
  structural, because G4 and G5 return the same form.
* **G6 refuses the one-write-line form above 998 devices, and it beats the
  override**, because splitting a `write` produces two plots both named
  `Operating Point` and half the devices become silently unreadable.

**The override** is `ase::op_tier_force_set a|b|c|{}` / `ase::op_tier_forced` —
Tcl-level only, no menu item and nothing in the Save All dialog. It is the only
door to forms a and b, which is what keeps both fallback arms from being paths
only somebody else's machine ever runs.

**The sentence.** Four new kinds minted in `ase::sim_why` — `op_tier_blanket`,
`op_tier_perdevice` (its reason folded in as ordinary words),
`op_tier_writeline`, `op_tier_forced` — said once per run through
`ase::sim_say` from `ase::run_deck`, and silent when the deck asks for no device
numbers at all. Row S2 greps all four for `appendwrite`, `hier_op_names`,
`blanket_op_save`, `known` and `tier`, and expects none.

**The read side.** `op_annot::_wrap_alts` returns the descriptor's spelling first
and the bare one second, both built by `op_annot::_wrap`; `op_annot::text` takes
the first finite number. Without it form b's results file — which spells every
device number bare and `notype` — reads BLANK for 4 of the 6 rows this tree shows
for a sky130 transistor.

**One thing fixed that was not asked for, and one recorder bug found on the way.**
`ase::sim_say` recorded through `variable sim_said`, which binds to whichever
namespace the command lives in AT CALL TIME. Any caller that renames
`::ase::sim_say` aside to see what was said — a test, or a future dialog teeing
the CIW — silently started appending to `::sim_said` in the global namespace:
the sentence still reached the user, `ase::sim_said` still answered empty, and
the dialog that exists to show the user the very words the CIW got would have
shown nothing, with no error anywhere. The record is now written by its full
name. Row S1's third term is what caught it.

## Still owed to the user

Recorded as a `rule` debt, not decided here:

1. **The one-write-line form is not auto-selected**, which is not what the item
   asked for. See G4 above and issue 0965.
2. **The which-form sentence is said on EVERY run.** Issue 0948 decision 3 chose
   every-run for its own warning and decision 4 chose silence for the blanket
   question; neither covers this one.
3. **The blanket form is not the shape the probe measured** — issue **0966**.
4. **The results file's plot order changes** — a `look` debt, see issue 0964.
5. **The override is Tcl-level only.** If it should be reachable from the Save
   All dialog the way the tick is, that is a separate small item.
6. **G6 REFUSES THE OVERRIDE, and the item asked that any form be forceable
   "regardless of what the probe said".** Above 998 devices a forced `b` comes
   back `c`, reason `toomany`. The measured alternative is not "a long line" —
   it is two plots both named `Operating Point` with half the devices silently
   unreadable, because a split `write` does not accumulate (a split `save`
   does). Refusing is the honest answer, and it is still a refusal the user did
   not ask for.

## The repair pass, 2026-08-30 — six guards nothing could see, and one of them ships

The sabotage pass found seven places where changing the code changed nothing in
twelve suites and 1,422 checks. Six were guards in this item's own surface; the
seventh is issue **0967**, a behaviour change this item made that no row saw.
Each now has a row, and each row was re-measured by re-applying the same
sabotage and watching it turn red:

| what was sabotaged | what the user would have got | now caught by |
|---|---|---|
| a code word put inside the `unsafe` sentence | the sentence every real run on this machine prints, in code vocabulary | **S2** |
| the `unsafe` sentence deleted outright | "Your simulator cannot do either of the shorter ways" — said about a simulator that CAN do one and was refused it on purpose | **S6** |
| the blanket test moved above the `known` test | a leftover capability sitting beside `known 0` read as permission to use a short form | **T11** + **T13** |
| the catch around `ase::sim_capabilities` removed | a probe that blows up breaking Netlist-and-Run for a user who only ticked a box about device numbers | **T14** |
| `op_tier_report`'s captured-block gate deleted | a run told it asked one device at a time about a deck carrying no device requests at all | **S9** |
| its tick and operating-point gates deleted | the same sentence to a user who never ticked the box, or whose run has no operating point | **S7**, **S8** |
| `op_cards_names`'s parameter filter dropped | a bare `@dev` reaching a request line, where it means *every* parameter of that device — the other form's meaning | **E13** |

**Why S2 could not see four of the five sentences it is about.** The per-device
sentence is one shared head plus a tail chosen by the reason token, and S2 called
`ase::sim_why` with three arguments, so the token was always empty and only the
default tail was ever minted. The plain-English ruling was enforced for one
sentence out of five, and not for the one that ships here. S2 now walks every
kind × every reason token.

**Why T11 passed on a tree that never tested the key.** It looked for the whole
word `known` anywhere in `ase::op_save_tier`'s comment-stripped body. The proc's
own not-measured fallback, `set caps [dict create known 0]`, sits above every
capability read and contains that word — so the predicate was satisfied whatever
the order below it. It now matches `$caps known`, the spelling of both
`dict exists $caps known` and `dict get $caps known`, which appears only where
the guard actually asks the question. **T13** adds the behavioural half.

Suite is now **56 checks**, green on both arms.

## The write-up pass, 2026-08-30 — two more filed, one false comment corrected

* **0968** — form a's request is a deck-level `.options` line and so applies to
  every analysis, and the blanket arm does not get 0964's reorder. Reproduced
  first-hand: rendering the same op+tran state under each form puts
  `.options saveopparams` above `.control` with `op` still first, while form c
  runs `dc ac tran op` with its requests inside. On the day a build honours the
  option, 0964's defect returns inside the cheapest of the three forms — and
  every committed row that renders form a does so on an operating-point-only
  state, so nothing can see it. FILED, NOT FIXED.
* **0969** — the value acceptance runs on a hand-written level-1 transistor
  rather than the PDK bench the item names, and G-LEADER is a deck grep where
  its measured hazard was a run. Both properties were checked by hand and both
  hold (456 of 456 bit-identical; 424 transient vectors either way). FILED, NOT
  FIXED.
* **`ase::op_save_tier`'s own header said "Pure: it starts nothing, writes
  nothing".** It is not: `ase::sim_capabilities` is lazy, and on a cache miss it
  makes a scratch folder and starts the user's simulator twice under a timeout.
  Nothing is wrong in production — `ase::run_deck` warms the cache one line
  earlier, so the measurement is paid on a Run — but a comment that invites the
  next hand to call this from a deck-rendering path with no Run behind it is a
  trap. Comment corrected in `src/ase.tcl` and in §4.3b; no behaviour changed.

