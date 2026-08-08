# Item 17 — "Show in Signal Browser" honours the SELECTION

**Status: LANDED.** Work order: `ITEM17_selection_scope.md` (commit `7402e1cb`).
Every number below was run.

---

## 1. ⚠⚠ IT WAS NOT A FEATURE REQUEST. IT WAS R10, SHIPPED HALF-DONE.

Found while writing the spec amendment, after the work order was already
committed. The two-pane spec's ruling table has said it from the start:

> **R10** — Ctrl-Alt-V replaces Ctrl+5 as "Show in Signal Browser", routed
> through the C action registry so it is remappable. **Nothing selected →
> reveal the current descend level. One instance selected → reveal that
> instance, as if the user had descended into it.**

The first sentence shipped in item 12. **The second never did.** No check caught
it, and the reason is worth keeping: *every existing check drives the command
with nothing selected*, so the half that was built is the half they all
exercise. A ruling can be green, approved and never fire.

⚠ **R10's other half is STILL OWED and was deliberately not taken here.** There
is no `Ctrl-Alt-V` binding anywhere in `src/`; the gesture is still `Ctrl-5` on
the Tools menu (`xschem.tcl:14938-14939`) and the C action registry route was
never built. Item 17 changed what the command TARGETS, never how it is reached.

## 2. One correction to the report

The driver wrote *"it appears as if selecting an instance and then saying show
in signal browser does anything"*. It does not do nothing: it reveals and
selects the node for the CURRENT descend level and fills the sea with that
level's signals. What it ignored was the selection. Stated because BX51's
NEGATIVE CONTROL is built on the true premise — same position, same command,
nothing selected, *still lands on `g:x1`* — and a check written against "it does
nothing" would have been pinning a falsehood.

## 3. Three things that were already true, which is why this is 3 lines of behaviour

Each read before any code was written:

* **`browser_reveal` already expands.** `$tv see` opens EVERY ancestor (spec
  §4.2's central finding), then `-open 1`, then the selection — and a tree
  selection is what fills the sea. Reveal `g:x1.x2` and x1.x2's own level
  appears. The lower pane needed nothing.
* **Case was already handled.** `browser_node_for` matches each segment
  exact-first with a `string equal -nocase` fallback; BX42 lands a schematic
  `X1.X2` on the raw's `g:x1.x2` today. So the name is passed through
  **verbatim** — folding it here too would be a second answer to one question,
  and on this fixture (which carries both `X1` and `x1`) the two answers differ.
* **`partial` already existed.** So ruling 1 cost no new branch — except at the
  top level, see §4.

## 4. ⚠ THE ONE PLACE THE RULING NEEDED CODE, AND IT WAS NOT PREDICTED

Ruling 1 is *"land on the parent, say so"*. `browser_show_path` does exactly
that — **but only when at least one segment matched.** A non-hierarchical
instance picked at the TOP level makes the whole path a single unresolvable
segment, so `matched == 0` and the answer is `err` with the selection left
untouched (`wave_viewer.tcl:9513-9521`). That is not landing on the parent.

So the caller retries once, **without** the selection, and only when the
selection is what extended the path — a path that failed on its own merits still
fails, because that is the user's own hierarchy position and there is nothing
better to show. Sabotage U5 removes the retry and reds BX52 twice.

The work order predicted ruling 1 would be free. It was free for the *descended*
case and not for the top-level one; BX52 is deliberately driven at the top level
for that reason.

## 5. What landed

**`src/ase.tcl`**
* NEW `ase::browser_sel_segment` → `{ok <name>}` / `{none}` / `{many <n>}`.
  `xschem objects -type instance -selected`; the name is a dict key
  (`scheduler.c:8466`), so no `getprop`/`get_tok` round trip. Never throws.
* `show_in_browser_for_current` step **3b**: the selection extends the path,
  **after** the `$drop` trim and **before** `wviewer::open`.
* step **6b**: ruling 1's retry.
* Ruling 2's CIW comment, no `error` tag, naming the count AND the action.

**`tests/headless/test_wave_sigbrowser_i12.tcl`** — band `BX16`-`BX18` (pure,
both arms) and `BX51`-`BX53` (real viewer + real design window). Helper
`bx_inst_names`. 101 → **123** on X, 32 → **40** headless.

⚠ **BX51/BX52/BX53 could reuse item 11's fixture unchanged**, and that is not
luck: `wvhier_top` holds `X1` AND `x1` (two instances of one cell — ruling 2's
pair, the case a user hits by rubber-banding) plus the non-subcircuit `V9`
(ruling 1's), and `wvhier_mid` holds `X2`.

**Docs** — two-pane spec **§7.8** (new), parent spec §10's item-12 line,
`waveform_viewer_guide.html` §11.4's Ctrl-5 prose.

## 6. Sabotages — RUN

| # | sabotage | reds | where |
|---|---|---|---|
| U1 | read the selection **after** `wviewer::open` | **4** | BX51 ×2, BX52, BX53 |
| U2 | ruling 2's `many` arm never fires (no CIW comment) | **1** | BX53 |
| U3 | append the instance **id**, not its name | **4** | BX17, BX51 ×2, BX52 |
| U4 | drop the **`-type instance`** filter | **1** | BX18 |
| U5 | drop ruling 1's **retry** | **2** | BX52 ×2 |
| U6 | **prepend** the selected instance instead of appending | **2** | BX51 ×2 |

U1 is a real relocation — the read is deleted from 3b and re-issued after the
raise — not a proxy. Source restored byte-identical after every one.

⚠ **THE PRE-STATE GUARD EARNED ITS KEEP ON ITS FIRST RUN, by catching ME.** The
driver asserts `browser_sel_segment` occurs exactly N times before it patches;
the first run aborted with `PRE = 2 (expect 4)`. The tree was fine — **my
expected count was wrong** (the proc and its one caller, not four). That is the
guard working: it refuses to measure a sabotage against a source state nobody
checked, and it cannot tell "corrupted" from "you counted wrong" — which is
exactly why it stops rather than guesses. (Item 16's receipt §4.2 is why it
exists at all.)

⚠ **U1 and U2 first appeared to red NOTHING**, and that was a defect in the
DRIVER, not a coverage hole: its filter was `grep -E '^(PASS|FAIL|RESULT)'`,
which is anchored — so a `NORESULT |` or `TIMEOUT |` line is silently dropped and
a crashed suite prints as an empty result. Re-run with `NORESULT|TIMEOUT` added,
both red properly. A filter that can hide a crash makes every zero in the table
unreadable.

## 7. Three test-side defects, all found by running

* **`xschem selected_set` BRACE-QUOTES every name** (`scheduler.c:10779`), so a
  one-element answer has the string rep `{X2}`. Compared to `X2` it fails on
  correct code. The legs now read `[lindex ... 0]`.
* **Two legs read the design window WITHOUT switching context back.** The
  command LEAVES THE CONTEXT ON THE VIEWER — BX42 pins that as declared
  behaviour — so `xschem get sim_sch_path` answered about the viewer's own
  untitled buffer and returned `{}`. It looked exactly like a real defect.
* The i12 header prose claims `BX40-BX52`, but **nothing used BX51 or BX52**;
  the highest spent id was BX50. The work order's "next free is BX53" was wrong
  and was corrected in place before the band was spent.

## 8. Owed

* **R10's other half** — `Ctrl-Alt-V` through the C action registry (§1).
* **R12's auto-tick** — a device instance whose node is hidden should auto-tick
  *Show device internals*, reveal it, and say so. Not built; item 12's
  checkboxes are still inert.
* **Wires, pins and text.** `-type instance` is a declared limit: selecting a
  NET and asking to show it wants a signal ROW, not a node, and has no rulings.
* ~~**The eyeball.**~~ **DONE, by the driver, 2026-08-07.** Ctrl-5 with `x2`
  selected inside `x1` of `tb_bandgap` in the `sky130_tests_ase` workarea (the
  real 69 MB `tb_bandgap_ase.raw`, not a fixture): the tree expands to `x1.x2`
  and the lower pane shows that level, with no descend. Reported good.
