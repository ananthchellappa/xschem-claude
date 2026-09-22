# 1499 — ASE-L cut text off mid-glyph with no way to read it, and the simulation log had no horizontal scrollbar

**STAMP:** `v1 claim=partial tree=6a0d1126 stamped=2026-09-21 fix=taken open=1 scope=tooltip-only by=ase-l-ux-batch-item-3`

**Status: PARTIAL — filed and half-fixed 2026-09-21** by the ASE-L UX batch, stage 3 of
`doc/claude/ase_l_ux_batch/PLAN.md`, from `receipts/recon.md` §1/§5 and `receipts/impl.md`.
The **tooltip** and the **log scrollbar** are in. The **visible `…`** is not: it needs a
ruling (⚖ R-U1 below) and the tooltip does not wait on it.
**Class** reachability: information rendered and then cut, with no affordance.
**Related, read first:** **1398** (the font and column-width derivation, whose per-pane
horizontal scrollbar is the neighbouring mechanism and does **not** close this), **1391**
(the action strip's tooltips), **0132**/`balloon_clipped` (the tree's own show-only-if-cut
gate).

---

## The defect

### (i) A cell too narrow for its text was cut mid-glyph

Measured 2026-09-21 at the user's own `ase_font_size 12` (set by
`src/cadence_style_rc`, not the bare default), on a Monte Carlo variable
`agauss(1.8, 'ABSVAR*1.8', 3)`:

```
vars value column -width px = 143        ink of the string px = 244
CLIPPED = 1                              cell text carries an ellipsis = 0
<Motion>/<Enter> bindings on the three panes = 0
<Motion>/<Enter> bindings on the status bar / Simulators dialog = 0
a real ngspice path in the Simulators Program column: 371px ink in 324px = CLIPS
```

The sigma reference and the sigma count are exactly the characters that fall off. The only
ways to read the value were to drag the column divider or open the row editor.

**⚠ The per-pane horizontal scrollbar that shipped with 1398 cannot reach this, and that is
measured rather than argued.** At 798 px the vars viewport is 246 px against 244 px of
columns, so `ase::ui::hscroll_autohide` correctly leaves the bar **unmapped** while the
cell's ink overflows its own 118 px column; at `ase_font_size 12` the bar *is* mapped and
the cell still clips, 244 px of ink in a 143 px column. Scrolling a pane slides the
viewport across the columns; it never widens one. **The two defects are orthogonal.**

### (ii) The simulation log window had no horizontal scrollbar

`ase::ui::log_open` built `text $lw.t -height 24 -width 84 -wrap none` with a **vertical**
bar only and no `-xscrollcommand`. The line that matters — `command :
/home/analog/dev/ngspice/.../ngspice -b -D casemode=preserve …`, the answer to the only
question anybody asks when a run fails — measured **137 characters** against 84 columns.

**⚠ Correction to the plan, which called it unreachable.** It was **undiscoverable, not
unreachable**: `Text`'s class bindings carry `<Shift-MouseWheel>` / `<Shift-Button-4/5>`
and they work on a disabled widget (measured: `xview` `0.0` → `0.0456` on one wheel event),
and 61 % of the line is visible at the default width. There was no bar, no affordance and
nothing saying the widget scrolled sideways.

**⚠ And a second plan clause is spent.** *"Derive `-width` from the font … buys ~115
columns in the same pixels"* was 84 × 11 px (pre-1398 Nimbus Mono PS) ÷ 8 px. Issue 1398
already cut the mono advance to 8 px at size 10 / 10 px at size 12, so re-deriving 84
columns now makes the window **wider** — the direction `2f1fad58` exists to correct.
`-width 84` and `-wrap none` are deliberately **untouched**, pinned by row `UX1499b4`.

## The fix

* **`ase::ui::cell_tip_text` / `label_tip_text` / `tip_text` / `tip_motion` / `tip_show` /
  `tip_cancel` / `tip_attach` / `cell_font`** (`src/ase_window.tcl`). Hovering a cell whose
  ink exceeds **its own column's width** resolves the whole string and schedules the tree's
  own `balloon_show` — **one renderer, not a second tooltip mechanism**, exactly as
  `ase::ui::rsel_tip_show` reaches it. A cell that fits resolves `{}`: a tooltip on every
  cell is the failure mode, not the feature. Armed on the three panes (`build_pane`), the
  Simulators dialog's table (`simulators_dialog`) and **all three** clippable status-bar
  segments — `sim`, `state` and `health` — where the tree's own `label_clipped` is the gate.
* **The anchor is chosen by class** (`tip_show`): a treeview **cell** is pointer-anchored
  (`pos 0`), because `pos 1` anchors at the whole table's corner rather than the row under
  the pointer; a **label** is widget-anchored (`pos 1`), which is what `balloon_clipped`'s
  own header records as measured and justifies *in terms of a status bar* — issue 1368 saw a
  moved `pos 0` tip land under the pointer, be destroyed by its own `<Leave>` and flicker 25
  times in 1.5 s, and ASE-L's bar is `pack -side bottom`. The neighbouring `rsel_tip_show`
  passes `0`, and that is **not** a precedent for the labels: it is bound to `$f.tv`, a
  Treeview, so it is the same answer this proc gives for that class.

### ⚠ Two departures from `PLAN.md` stage 3(i)'s wording, both deliberate, both recorded

The stage authorises the tooltip on *"the three panes, the Simulators `Program` column and
the status bar's **last** segment."* What shipped is not letter-identical to that:

1. **The status bar.** The first cut armed `sim` and `state` and **not** the last segment.
   The bar packs `win sep1 stat sep2 temp sep3 sim sep4 state sep5 health`, so the last one
   is `health` — which is not a word but a built string (`"<prefix> <n> <name>, <n>
   <name>, …"` from `ase::ui::health_text`) and therefore clippable, so the plan's choice
   was not arbitrary. **Fixed rather than argued** (fix round, 2026-09-21): all three are
   armed now. It costs a user who never asked for the counters exactly nothing — `health`
   carries **no text at all** unless the bench sets `runhealth`, which **none of the 104
   committed benches does**, and `label_tip_text` returns `{}` for an empty `-text`. Pinned
   by `UX1499a9b` (all three armed) and `UX1499a9c` (an empty segment owes nothing).
2. **The Simulators dialog.** `simulators_dialog` arms the **whole** `$w.tv`, not the
   `Program` column alone. **Kept, deliberately.** Narrowing it would mean teaching the
   handler a column allow-list, and the effect of that would be to leave a clipped cell in
   *another* column of the same table unreadable — the precise defect this issue exists to
   close. The gate is per cell and unchanged, so a cell that fits still offers nothing; the
   superset costs a user nothing and buys them the rest of the table.

Neither is a ruling: no wording, sizing or placement changes, and no new text appears
anywhere. They are recorded here because an auditor asking *"did stage 3(i) ship what it
said?"* must get the same answer from this file as from the tree.
* **The gate is pixels against the column's own width**, so it follows `ase_font_size` and
  a dragged divider. Row `UX1499a7` discriminates it from a character count with a pair no
  character rule can get right: 20 characters of wide ink owe a tip, 22 characters of
  narrow ink do not.
* **`ase::ui::log_open`** gains `$lw.hsb`, wired to the **same** auto-hide producer the
  panes use — which is why `ase::ui::pane_hscroll` is now `ase::ui::hscroll_autohide`. The
  window moves pack → grid so `grid remove` can hide the bar without a geometry feedback
  loop; `$lw.t` and `$lw.sb` keep their paths, which is what three suites address.

⚠ **DECLARED LIMIT, inherited from `rsel_tip`:** `balloon_show` returns early unless the X
pointer is physically over the widget, so the rendered balloon is **not drivable from a
script**. What the suite rows drive is the text the handler resolves and the bindings that
reach it. **The pixels are an eyeball debt** — nobody has seen this balloon on a screen.

## Pinned by

`tests/headless/test_ase_window.tcl`, GUI rows `UX1499a`–`UX1499a11` (tooltip),
`UX1499b1`–`UX1499b5` (log bar), `UX1499c1`–`UX1499c2` (the per-pane bar that shipped with
1398 and had **zero** coverage anywhere in `tests/` until now — a retro-pin, which is also
what protects the rename). Sabotaged and red by name: the clip gate always-true →
`UX1499a5`/`a7`; `tip_attach` neutered → `UX1499a`/`a9b`/`a10`; the log `-xscrollcommand`
dropped → `UX1499b2`/`b5`; the pane `-xscrollcommand` dropped → `UX1499c1`; `health` left
un-armed → `UX1499a9b`; `tip_show` giving every class `pos 0` → `UX1499a11`.

⚠ **`UX1499a11` narrows the declared limit below rather than removing it.** The rendered
balloon is still not drivable, but the **anchor the handler asks for** is: the row renames
`balloon_show`, records `{class pos}` for a cell and for two labels, and restores it. So
the convention is now a rule the tree enforces, and only the pixels remain an eyeball debt.

## Still open (1)

**⚖ R-U1 — how should a cell that is too narrow for its text end?** Raised by the recon
crew, unanswered, and **gating nothing**: the tooltip above is a strict subset and already
delivers stage 3's stated outcome.

*Plain English, for the user:* when a value does not fit its column, ASE-L cuts it off
mid-letter. Should it instead end in a `…` so you can see it has been cut — and if so,
should the Outputs **Name** column, which today cuts at a fixed 24 characters and ends in
three dots `...`, change to match?

| option | what the user sees | cost |
|---|---|---|
| **A — tooltip only (SHIPPED)** | the cut stays mid-letter; hovering a clipped cell shows the whole string | no suite moves; nothing tells you a cell is cut until you hover |
| **B — `…` everywhere except Name** | cut cells end in `…`; the Outputs Name column keeps its `...` at 24 chars | two truncation idioms side by side in one pane; `W1p` and every `$tv set … value` row moves to a hidden column |
| **C — `…` everywhere, Name included** | one idiom; Name cuts on pixels rather than on a character count, so it changes where it cuts | as B, plus the three `P2` rows and the string the user currently reads in Name |

**Recommendation, not an answer: C.** It removes the inconsistency rather than trading one
cost for another, and a pixel rule is strictly better than a 24-character one that clips at
a different point in every font size.

⚠ **The plan's stated precondition for this is not implementable, and that is measured.**
It requires *"the full string stays in the item's `-values`; only the DISPLAY is
truncated"*. A `ttk::treeview` renders exactly `-values`; with a hidden `_full` column,
`$tv set $it value` still returns the **truncated** string, and tags carry no per-cell
text. So `PLAN.md`'s *"Suites: none"* is **false for the ellipsis half** — it moves every
`$tv set … <col>` assertion in the ASE suites. (It is true for the tooltip half, which is
why that half shipped.)
