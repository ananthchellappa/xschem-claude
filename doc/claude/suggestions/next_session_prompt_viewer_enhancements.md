We're implementing ten waveform-viewer enhancements in xschem. Repo:
/home/qflow/dev/xschem/claude_1/xschem, branch `fluid-editing`, HEAD `1c375582`
plus an uncommitted marker-callout polish (padding / fixed-px strokes /
`graph_marker_textmag` / the selected-text-drag rigid translation). Next free
issue number is **0172**.

**The plan is already written and already grounded. Read it first and in full:**
`doc/claude/suggestions/plan_viewer_enhancements_2026-07.md`

It carries a checkbox per item, the file:line anchors, the shipped precedent to
copy for each, the difficulty verdicts, seven blocking user decisions (D-A … D-G)
and a recommended order. It came out of a six-lane read-only census of the working
tree, so its anchors are real — but its **line numbers will drift**, and the tree
is uncommitted. Verify before you rely on one; correct the plan when it is wrong.

────────────────────────────────────────────────────────────────────────────────
YOUR ROLE THIS SESSION: ORCHESTRATOR. You do not write the code.
────────────────────────────────────────────────────────────────────────────────

This has worked before in this repo and the shape matters. You are the **main
thread**. You hold the plan, the decisions, the sequencing and the verification
verdict. A **subagent crew** does the reading, the writing and the testing, and it
works on **exactly one item at a time**.

**Never run two items concurrently.** Every one of these items touches
`src/wave_viewer.tcl`, and several touch `src/draw.c`, `src/callback.c` and
`src/xschem.h`. Two agents editing those in parallel produces a merge you cannot
review. Fan out *within* an item (map lanes, review lenses) — never *across*
items.

**What you do yourself, inline, and do not delegate:**
- Read the plan and the reference docs.
- Ask the user the blocking decisions (below) — batch them, do not dribble.
- Decide which item is next and write the handoff brief for it.
- Read the crew's diff yourself before accepting it. A crew report is evidence,
  not a verdict.
- Run the test suites and the soak, and read the output.
- Update the plan's checkbox and the specs.
- Decide when an item is done and when to stop.

**What the crew does:**
- Per item: a **map** pass (read-only, verify the plan's anchors against today's
  tree, report drift), then a **build** pass (one agent, the whole item, single
  author — these are interdependent edits, not parallel work), then a
  **review** pass (adversarial, evidence-or-it-did-not-happen, distinct lenses).
- The build agent writes tests as part of the item, not after it.

Available agent types are listed in your system prompt; `caveman:cavecrew-*`
(investigator / builder / reviewer) exist and are a good fit for the three passes.
Use `general-purpose` when an item needs more rope than the builder's scope allows
(it hard-refuses 3+ file scope, and several of these items exceed that — for those
use `general-purpose` for the build pass).

────────────────────────────────────────────────────────────────────────────────
STEP 0 — before any code: get the blocking decisions
────────────────────────────────────────────────────────────────────────────────

Ask the user D-A … D-G from the plan's "Decisions" section, in **one** batch, with
your recommendation for each. They are genuinely blocking — each changes what gets
built, not how. The two most likely to be answered "not what I meant" are:

- **D-A / which grid.** The schematic dot grid is **already absent** from every
  waveform window (`xschem set no_grid 1`, `wave_viewer.tcl` ~438). So items 2 and
  3 can only be about the **graph** grid (`draw_graph_grid`, the dashed lines
  inside each strip). Confirm before writing a line.
- **D-E / which gesture** for item 6. "Moving a strip … the associated trace"
  describes two different shipped gestures that share the hand2 cursor. The strip
  reorder has no single associated trace; the trace drag has exactly one.

Also confirm the **item 1 premise correction** with the user: the ASE legend is
`gr->txtsizelab`, not `txtsizelegend`, and "same weight" is ambiguous between
*size* and *boldness* (boldness is already conditional — the bold-wave legend
entry uses `CAIRO_FONT_WEIGHT_BOLD` while the axis numbers use the normal face).

Do not start an item whose decision is unanswered. Start one whose decision is not
needed (item 4 needs none).

────────────────────────────────────────────────────────────────────────────────
THE PER-ITEM LOOP — run this once per item, in the plan's recommended order
────────────────────────────────────────────────────────────────────────────────

**1. Announce.** One line to the user: which item, why it is next, what it will
touch. If its decision is unanswered, stop and ask.

**2. MAP pass** (read-only subagent, ~1 agent).
Brief it with the plan's section for that item verbatim, plus:
> READ ONLY — do not edit any file. Ignore `.claude/worktrees/` (stale copies).
> Verify every file:line anchor in the section below against the tree as it is
> TODAY and report the corrected line for any that drifted. Report anything the
> plan asserts that the code contradicts — the plan's author could be wrong.
> Every claim needs a quoted line as evidence. Return the corrected anchor table
> and the ordered list of edits the build pass should make.

**3. BUILD pass** (ONE subagent — single author, never parallel).
Brief it with: the corrected anchors from step 2, the plan section, the
"Conventions that apply to EVERY item" block from the plan, and:
> Implement this item and its tests in one pass. Follow the shipped precedent
> named in the brief rather than inventing a design. Build with
> `cd src && make -j8` and fix every warning you introduce. Run the affected
> suites and report the real numbers. If a test fails because the PRODUCT is
> wrong, report it as a defect with evidence — do not paper over it.

**4. Review it yourself.** `git diff` the touched files and read them. Then a
**REVIEW pass** (2-3 adversarial subagents, *distinct* lenses — correctness +
landmine compliance / interaction + regression / model-sync + undo), each told:
> Every finding must carry evidence from the real code or from a command you
> actually ran, with its output. If you find nothing in your lens, return an empty
> list — do not manufacture findings.

**5. Verify, yourself.** Run:
```
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_markers.tcl
for t in test_wave_markers test_wave_viewer test_wave_modes test_wave_clear_all test_ase_plot; do
  ./src/xschem --pipe -q --nolog --script tests/headless/$t.tcl 2>&1 | grep -E '^RESULT|^FAIL'
done
```
Expected: markers 641 / 310, viewer 349, modes 384, clear_all 68, ase_plot 145.
`test_wave_markers.tcl` has hand-maintained count constants (`mk_expect_x` /
`mk_expect_nogui`, ~line 3694) — adding legs means updating them or `MZ1` fails.

**6. Sabotage-verify** anything behavioural. Break the new code deliberately, name
the leg that must go red, confirm it does, restore and md5-verify the restore. If
no named leg can go red, that is a **hole in the suite** — fix the suite, or state
plainly why the item is eyeball-only (items 1, 2 and 6 largely are).

**7. Soak** any gesture item: the DISPLAY arm **10+ times** (~32 s each). A
one-in-six WSLg focus flake reads as green on the first run. Do **not** run
`full_audit.sh` — it pops the GUI control panel.

**8. Close the item.** Tick its checkbox in the plan. Update the owning spec
(`waveform_viewer.md` / `waveform_viewer_modes.md` / `graph_markers.md`) and add a
landmine to `waveform_subsystem_reference.md` §11 if the item taught one. Report
to the user in a few lines: what changed, the real test numbers, what is
eyeball-only and needs their look, and what you deliberately did not do.

**Then stop and ask before starting the next item.** Do not chain items without
checking in — the user may want to eyeball the last one first, and several of
these are visual.

────────────────────────────────────────────────────────────────────────────────
NON-NEGOTIABLES — these are shipped landmines, not style preferences
────────────────────────────────────────────────────────────────────────────────

- **`draw_graph` flags: bit 8 = durable CONTENT, bit 16 = UI CHROME** stripped
  from every export (landmine 18). Items 6 and 9 draw transient feedback — bit 16.
- **The viewer is read-only for its whole life.** Every mutation goes through
  `wviewer::with_edit`, which **errors** on a refused context switch and must be
  `catch`ed inside a Tk binding. `switch_ctx` must be *verified*, never assumed.
- **The model mutation contract** (`wviewer::move_strip`'s header comment is the
  written-down rule): *validate → no-op returns without mutating AND without
  logging → verified `switch_ctx` → `capture_live_graph_state` → `push_undo` →
  mutate → remap the stored target in place → ONE `regenerate` → ONE `log_action`.*
  Snapshot-after-mutate is the shipped bug class: `u` then restores the very thing
  it was meant to undo.
- **Do not write into `$top.statusbar.*`** (item 10). C rewrites those slots on
  every GUI event; the viewer must own its own bar.
- **New transient `xctx` fields** reset in the gesture teardown **and**
  `clear_drawing()` **and** `alloc_xschem_data()`.
- **Landmine 11**: `xctx->graph_struct` is shared — a query builds a stack-local
  `Graph_ctx`. **Landmine 37**: `setup_graph_data()` returns early for an
  off-screen graph before parsing units/log/divs and rewrites `graph_flags`
  128|256 — bracket those two bits and treat `gr->cx == 0` as "no transform".
- **Landmine 35**: a *picked* sample's x/y is raw, never through `mylog10`.
- **Reuse the PURE model primitives** (`move_trace_in_graphs`,
  `empty_graph_indices`, `remove_graphs`) rather than writing new index math.
  They already carry the marker migration and the `hilight_wave` hand-off, which
  is how `graph_markers.md` §9's remap obligations get discharged by construction.
- **Never delegate a `git reset`/`checkout` to a subagent** on the shared tree —
  commit first or use `isolation: 'worktree'`.

────────────────────────────────────────────────────────────────────────────────
SCOPE
────────────────────────────────────────────────────────────────────────────────

Ten items is more than one session. Getting **four** of them landed, tested,
soaked and documented is a better outcome than ten half-done. Work the
recommended order, check in after each, and stop when the user says so or when the
tree stops being green.

Nothing in this work is committed. Do not commit or push unless the user asks.
