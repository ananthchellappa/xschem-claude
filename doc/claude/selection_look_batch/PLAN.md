# Selection look batch 2026-11-14 — PLAN

Base: e3c43487e (fluid-editing).

## Why

User, 2026-11-14: selecting a FET makes it LESS visible ("redrawn in a dull dark grey"), and
each visible property text gets a box around it. "Ridiculous" next to Cadence. They like the
white outline the property form draws on its edit targets (`draw_scope_highlight`, gc_scope).

Measured causes (driver, screenshots on a private Xvfb):
- `SELLAYER` and `GRIDLAYER` are the same layer (2) in `src/xschem.h`, colour `#4f4f4f`
  dark / `#aaaaaa` light. Selection is painted in the grid's grey. Upstream default too.
- `draw_temp_symbol` draws each symbol text through `draw_temp_string` -> `drawtemprect`:
  a box per text, never glyphs. Floating texts likewise (`draw_selection_impl`, xTEXT case).

## The ruled design (user approved the recommendation, 2026-11-14)

A setting `selection_style` = `classic` | `bright` | `halo`. Default on this branch: `halo`.
- **classic**: today's pixels, byte for byte (upstream's look; must stay reachable).
- **bright**: selection drawn with a DEDICATED selection colour (not layer 2), theme-aware
  default (bright on dark, strong on light; overridable by `selection_color`), and texts drawn
  as GLYPHS in that colour, not boxes.
- **halo**: the selected object keeps its own layer colours; a band of the selection colour a
  few screen pixels wide (`selection_halo_width`, sensible default) is stroked UNDER/around its
  shapes, then the object's own shapes are re-stroked on top in their own colours. Texts drawn
  as glyphs, brightened (selection colour), no boxes.
- During a DRAG (move/copy rubber band, deltax/deltay or rotation non-zero) of a large
  selection, falling back to the cheaper drawing (boxes for text, no halo) is allowed when
  measured necessary; say what threshold and why.
- The property-form scope outline (`draw_scope_highlight`) and the hover outline
  (`draw_hover`) stay as they are and must still read distinctly on top of the new selection.

## Stages

| stage | what | who |
|---|---|---|
| A | Prototype all three styles in C/Tcl, behind `selection_style`; correct erase (gctiled must cover the halo); light + dark schemes; screenshots for the user | crew, then adversarial verifier |
| B | USER LOOKS at the screenshots (look debt). Tweaks from their answer | driver + crew |
| C | Fences (headless plumbing + display-arm pixel rows), register, T1 gate, commit | crew, verifier, driver gate |

Stage A must NOT be committed before stage B's look.

## Rulings during the batch

- **2026-11-15, label look (A2-fixes decision 1).** Asked: should selected labels keep their own
  colour with a thin selection-colour outline, switching to plain selection colour when the text is
  too small for the outline to show? User: *"yes, proceed with your suggestion on labels"*.
  So halo's default text look is `own` (own-colour glyphs over the 1 px band), with a per-text
  size fallback to `colour`. Bright keeps PLAN's definition (glyphs in the selection colour).
  Built in stage A6. Decision 2 (band width) stays at the measured 1 px unless A6 measures a reason.
- **2026-11-15, label outline cut-off.** A6 shipped `selection_text_own_px` = 12 rendered px. The
  driver judged 12–14 px outlined text heavy and smudged in the composites (worst on light) and
  recommended 16. User: *"Yes, go with your recommendation."* Default becomes **16**; applied at
  the A5b+A6 merge. The same message asked that responsiveness not suffer ("I never had an issue
  with Cadence"), so the post-merge verify repeats the timing table and the user's stage-B look
  should include a responsiveness check on their own screen.
- **2026-11-15, stage-B look on the user's own screen (via `pdk_launcher.sh`, sky130A).** Halo's
  instance text: *"whatever we're doing to the text accompanying the instance is not pretty ...
  smeared look"* (the `own` look: own-colour glyphs with a selection-colour outline). After trying
  Bright: *"Can we add an option to accompany bright with a box of same color? Same box used to do
  the dashed yellow highlight-on-hover (but solid and same color used by bright) should be
  sufficient. that done, make the default = Bright (with box)."* So a fourth value joins
  `selection_style` (Bright plus a solid selection-colour box per selected object, geometry
  mirrored from `draw_hover_shape()`), and it becomes the default. Halo and Bright stay as they
  are, reachable from the menu. The user also asked for a FAQ entry on getting Halo and Bright
  without the box, and a blog post. Built in stage A7.

- **2026-11-15, Bright with box approved.** The user, with the A7 build in the main tree (rebuilt 20:08) and the screenshots sent: "bright with box passes look test." Bright with box stays the default; stage C (fences, small findings) then a T1 gate and the commit.
