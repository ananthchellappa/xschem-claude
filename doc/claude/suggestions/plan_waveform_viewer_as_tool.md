# Making the Waveform Viewer Its Own Tool — how hard is it?

*A plain-English assessment. Written 2026-07-22. Grounded in the subsystem
analysis in `doc/claude/code_analysis/waveform_subsystem_reference.md` and
`waveform_display_explained.md`. This is a scoping/decision document, not a
committed plan.*

## The question

Today a waveform "graph" is just a rectangle drawn on the schematic canvas.
We want to move to a waveform viewer that is its own kind of window —
practically a separate tool. How difficult is that?

## Short answer

**Medium-to-hard, with a wide range: roughly 1–2 weeks for a convincing
version, 6–10 weeks for the architecturally clean one.** It isn't "very hard"
because the expensive half of the work — reading and holding the simulation
data — is already clean and reusable. It isn't "easy" because the *drawing*
and *interaction* code is welded to the schematic canvas, and xschem has no
notion of a window that isn't a schematic.

## The thing most people don't realize

**xschem already made this move once.** The ASE Waveform Viewer
(`wave_viewer.tcl`) is a separate window that shows waveforms. But it's a
clever *disguise*, not a separate tool: it opens an ordinary xschem editor
window, holds it read-only, hides the schematic toolbar, and fills it with
graph-rectangles — so the *same* canvas engine that draws schematics draws the
waveforms. It looks like a dedicated viewer; underneath it's a schematic
window wearing a costume.

So the real question isn't "can we have a waveform window" (we can, and do).
It's "do we evolve the costume, or build something genuinely independent?" —
and that choice is governed by one technical fact.

## The one fact that sets the difficulty

The waveform *renderer* computes where to put each pixel by taking the graph's
own coordinates and then multiplying by the **schematic's** zoom and adding the
**schematic's** pan. It also draws into the schematic's own drawing surface,
using the schematic's colors, and it finds graphs by scanning the schematic's
object list. In other words, the renderer can only draw *inside a schematic
window*. It has no way, today, to draw onto anything else.

That's why the ASE viewer had to fake a schematic window rather than make a
real separate one: reusing the renderer *requires* a schematic context.

## What's reusable and what isn't

**Already clean — keep it, it's the good news:**

- Reading and parsing the simulator's `.raw` file into memory.
- The in-memory data model and all the accessors that fetch a value or look up
  a signal by name.
- The whole `xschem raw ...` scripting interface for querying and computing on
  the data.
- The numbers-on-the-schematic back-annotation *data*.

This is about half the subsystem, and it's the half you'd least want to
rewrite. It doesn't care whether it's feeding an embedded graph or a separate
tool.

**Welded to the schematic canvas — this is the work:**

- The renderer (~1,500 lines): draws only into a schematic context.
- The mouse/keyboard interaction (~1,000 lines): bolted into the schematic's
  event handling.
- The window concept itself: every xschem window *is* a schematic. There is no
  fourth kind of window to hang a viewer on.

## Three ways to do it

### Path A — Evolve the costume (low-to-medium; ~1–2 weeks)

Keep graphs as rectangles drawn by the existing engine, but dress up the ASE
viewer window until it *feels* like a real tool: add a signal-browser panel, a
measurement/calculator panel, docked toolbars, nicer multi-graph layout — all
built in Tcl around the existing read-only-window trick.

- **Pros:** fast, low risk, reuses everything, delivers most of the visible
  user-experience win.
- **Cons:** it stays a schematic-in-disguise forever. You inherit all the
  fragile workarounds that exist only because the viewer is faking it (the
  window must be held read-only with special discipline; the viewer keeps
  shadow copies of state the engine won't share with it; the layout depends on
  pinning the schematic zoom so one graph fills the window).

### Path B — Free the renderer, then serve two windows from it (hard; ~6–10 weeks)

Refactor the renderer so it can draw onto *any* target — you tell it the
surface, the transform, and the colors, instead of it reaching into the
schematic's globals. Then the *same* renderer can draw both the old embedded
graphs and a brand-new standalone waveform window.

- **Pros:** this is the "right" architecture. One rendering codebase, no
  duplication, and embedded graphs keep working.
- **Cons:** it's surgery on the most delicate code in the subsystem — the part
  full of sign-convention traps, separate paths for analog vs digital, and
  shared scratch state that's easy to corrupt. Every one of those traps bites
  during this kind of refactor. This is the expensive path, but it's the one
  that actually removes the coupling.

### Path C — Build a clean-room tool (medium-to-hard; ~3–6 weeks)

Write a genuinely new window (its own canvas, its own event handling) that
talks to the data *only* through the existing `xschem raw ...` interface, and
**re-implements the drawing** from scratch (e.g. in Tcl/cairo).

- **Pros:** completely independent of the schematic; clean slate for the
  window, interaction, and its own saved-session format.
- **Cons:** you re-do the entire ~1,500 lines of drawing — analog lines,
  digital steps, hex buses, cursors, log axes, histograms. And unless you also
  keep Path A alive, you **lose the embedded-on-schematic graphs**, or you end
  up maintaining two separate renderers forever.

## The decision that changes the math

**Do we keep embedded on-canvas graphs, or deprecate them?**

- **If embedded graphs can go away:** Path C is cleanest — a fresh, fully
  independent tool, no ties to the rectangle-on-canvas machinery at all.
- **If embedded graphs must keep working:** Path B is the only way to avoid two
  separate drawing codebases. Pay for the renderer refactor.

This is the first question to settle, because it picks the path.

## Things that will bite, whichever path

- There is no "non-schematic window" in xschem today; inventing one is part of
  the job.
- The renderer draws only into a schematic context and bakes in the schematic's
  pan/zoom — it can't currently target an arbitrary window.
- The loaded simulation data is owned per-window, and the logic that decides
  "does this data belong to what's on screen" assumes a schematic — a separate
  tool needs its own answer.
- Session saving: embedded graphs ride along inside the `.sch` file; a separate
  tool needs its own way to remember its layout (the ASE viewer's saved-state
  approach is a starting point).

## Recommendation

If the goal is a real waveform tool, soon, without breaking embedded graphs:

1. **Do the small shared prerequisites first.** Three tiny engine additions
   (let Tcl read the cursor/measurement state; a way to ask a graph for its
   on-screen box and legend hits; a small speed fix) delete the fragile shadow
   copies that make today's viewer brittle. These help *every* path and should
   happen regardless.
2. **Ship Path A** to get the tool *feel* into users' hands quickly — it's the
   80% experience win at low risk.
3. **Pay down Path B underneath, incrementally** — gradually free the renderer
   from the schematic so the viewer stops being a costume, without a risky
   big-bang rewrite.

That sequence delivers the visible win early and buys the clean architecture
over time, instead of betting everything on one long rewrite.

## Rough effort summary

| Path | What you get | Effort | Risk |
|---|---|---|---|
| Prerequisites | Removes the fragile shadow-state; helps all paths | days | low |
| A — Evolve the costume | Tool *feel*, fast; stays a disguised schematic | 1–2 wk | low |
| B — Free the renderer | One engine for embedded + standalone; the clean answer | 6–10 wk | high |
| C — Clean-room tool | Fully independent tool; re-does drawing; may drop embedded graphs | 3–6 wk | medium |

## See also

- `doc/claude/code_analysis/waveform_subsystem_reference.md` — the engineering
  detail behind every claim here (file/function map, the coupling points, the
  landmines).
- `doc/claude/code_analysis/waveform_display_explained.md` — how the current
  system works, in plain English.
- `doc/claude/specs/waveform_viewer.md` — the existing ASE viewer (the
  "costume" that Path A would evolve).
