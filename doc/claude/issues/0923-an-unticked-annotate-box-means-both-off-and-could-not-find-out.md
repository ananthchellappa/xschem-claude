# 0923 — an unticked `Results > Annotate` box means BOTH "off" and "I could not find out", and says nothing either way

**Status:** 🔴 **OPEN — filed 2026-08-29 by the ruling pass on
[0682](0682-annotation-visibility-belongs-in-ase-l-results-annotate.md).** Not a
regression; a gap the 0682 ratification named as it went past and deliberately did
not fix, because it is a separate question with its own answer.

**Class:** PLAIN ENGLISH. Neighbour of
[0888](0888-the-annotation-line-says-showing-numbers-on-the-schematic-when-nothing-was-placed.md)
(a sentence that contradicts itself) and of
[0909](0909-the-blank-device-row-explanation-is-a-nag-that-fires-at-netlist-time-not-an-answer-when-you-press-6.md)
(a blank the user was owed an explanation for). Same shape: **the surface is silent
in a state the user cannot distinguish from a different one.**

---

## 1. What the user sees

In the ASE-L window, **`Results > Annotate`** carries three tick boxes —
`Operating Point info`, `DC Node Voltages`, `Transient Node Voltages (at cursor)`
(`src/ase_window.tcl:568-575` and `:602-605`). A tick means the numbers are on the
schematic that window is bound to; the box is the at-a-glance answer to *"are the
numbers on?"*, and that is exactly why 0682 ratified tick boxes rather than plain
menu commands.

**An UNTICKED box has two completely different meanings and looks identical in
both:**

1. the numbers really are off — the honest, common case; or
2. the program **could not find out** — the lookup of the bound design's
   annotation setting failed, so the menu fell back to showing "off".

In case 2 the numbers may well be **on the schematic in front of the user** while
the menu says they are off. Nothing is written to the ASE-L output pane, nothing
appears in the status line, and nothing distinguishes the two on screen.

## 2. Why it is worth its own number rather than a line in 0682

0682's question was *what shape should this control be* — tick boxes or commands,
greyed on what, whose numbers do they write. That was ratified 2026-08-29 and the
shape is right. **This is a defect INSIDE the ratified shape**, not an argument for
a different one, which is precisely why it was carved out instead of bundled: a
debt that mixes "is the shape right" with "does the shape report its own failures"
cannot be answered in one ruling.

## 3. What it is NOT

* **Not** the greying rule. The boxes go grey when the ASE-L session has no results
  file, or has one older than the netlist that describes it — `ase::has_results`,
  `src/ase.tcl:1283-1286`. That is a third, *visibly different* state and it works.
* **Not** issue [0684](0684-annot-ensure-loaded-guards-on-the-wrong-predicate.md),
  which is about a tick having to re-read the results file.
* **Not** the third entry's wording — the label `Transient Node Voltages (at
  cursor)` was invented rather than typed by the user, and that belongs to
  **0868**.

## 4. What would close it

The menu's own refresh already reads the bound design's setting without switching
sheets (`src/ase_window.tcl:2242`, with the switch verified at `:2310` — spec
landmine 17). The read has a failure arm; today that arm is indistinguishable from
a legitimate zero. Closing this means the failure arm must **say so** rather than
render as "off", under the user's PLAIN ENGLISH ruling — *say what happened AND
what the user can do about it*.

Two shapes, neither chosen here, because choosing is a user-visible decision:

* **Grey the entry**, reusing the affordance that already means *"I cannot answer
  this right now"* — cheap, and consistent with the no-results case.
* **Leave it unticked and say one line in the ASE-L output pane** naming what could
  not be read — louder, and it survives the user not looking at the menu.

## 5. Acceptance if fixed

1. Force the bound-design lookup to fail with the numbers ON, open
   `Results > Annotate`, and confirm the user can tell that state from a genuine
   "off" — by the entry's appearance, by a sentence, or both.
2. **Positive twin.** A genuine "off" still reads as an ordinary unticked box, with
   nothing said. A working "on" still reads as ticked.
3. **Positive twin.** The no-results and stale-results greying is untouched.
4. Whatever sentence is minted is minted ONCE and rendered by callers (RULING
   **D5-4**), and is plain English at a 9th-grade level.
5. Sabotage: restore the silent fall-back to "off" and confirm row 1 reds.
