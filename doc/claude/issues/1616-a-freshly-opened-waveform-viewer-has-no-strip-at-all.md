# 1616 — a freshly opened waveform viewer has no strip at all

**STAMP:** `v1 claim=fixed tree=6ffc032a stamped=2026-09-29 fix=taken open=2`

Status: **FIXED**, 2026-09-29, in `wviewer::open`. Measured on this tree at
`6ffc032a` · Branch: `fluid-editing`
Related: `doc/claude/specs/wish_list.txt` new-list item **15** (the user's own
request, *"WV: Always start with one blank graph element"*); requirement **R4** and
decision **D1** of `doc/claude/specs/waveform_viewer_tabs.md`; rows **OB1**–**OB4**
of `tests/headless/test_wave_viewer.tcl`. The banner/registration half that had to
land first is issue **1615**'s defect family, third site.

## The defect

`wviewer::open` seeds a brand-new token's layout with an EMPTY graph list:

```tcl
if {![dict exists $layouts $token]} {
  dict set layouts $token [dict create sharedx 0 graphs {}]
}
```

`wviewer::regenerate` then runs `xschem clear_drawing` and places one rect per
graph:

```tcl
xschem clear_drawing
set gi_ 0
foreach G_ $gs {
  ... wviewer::place_graph_rect ...
}
```

With `$gs` empty that loop places **zero** rects. So a freshly opened waveform
viewer comes up with **no strip at all** — not one blank strip. The user's wish-list
item 15 asks for exactly the opposite.

⚠ **A second consequence, and it is not cosmetic.** `regenerate` builds `graphbb`
from the same band count:

```tcl
for {set i 0} {$i < $n} {incr i} { lappend bbs [wviewer::band_geometry ...] }
dict set graphbb $wp $bbs
```

With `n == 0`, `graphbb` is an empty list, and `graphbb` is what feeds `over_graph`
and the a/b/s key gate. So on a bare-opened viewer the cursor keys and the marker
keys have nothing to be "over" and are inert. The missing strip is not just an empty
canvas; it is a canvas on which several documented keystrokes silently do nothing.

## Why no row caught it, and why that is the interesting part

The invariant DID exist — but only **reactively**, on every path that puts content
in. `wviewer::display_raw` and `wviewer::add_trace` each carry

```tcl
if {![llength $gs]} { set gs [list [wviewer::empty_graph]] }
```

and `wviewer::clear_all_at` and `wviewer::new_tab_at` both leave exactly one. So:

* load a raw → repaired on the way past;
* add a trace → repaired on the way past;
* Ctrl-D (Clear All) → exactly one blank strip, correctly;
* Ctrl-N (New Tab) → exactly one empty strip, correctly, which is what R4 of
  `waveform_viewer_tabs.md` ratifies.

**Every route that a test fixture naturally takes to get a viewer worth asserting
about repaired the empty list before the assertion ran.** Only a bare open with
nothing added could show the defect, and no row did that. This is the shape
CLAUDE.md warns about in its own words — a fence keyed to a symptom that something
else cures — inverted: an invariant that holds everywhere anyone looked, and
nowhere else.

The proof that the pre-click state really was zero was sitting in the suite the
whole time. Row **G10** opens a fresh viewer, invokes `Add Graph` **twice**, and
asserts:

```tcl
check "G10 model has 2 graphs" ... 2
check "G10 two layer-2 graph rects" [xschem get rects 2] 2
```

Had the window started with one blank graph, both would read 3. So G10 was
*evidence of the defect*, recorded as an expectation, for as long as it has existed.

## The fix — and ⚠ IT IS NOT THE ONE-LINE CHANGE IT LOOKED LIKE

The seed itself is one value in `wviewer::open` — `graphs [list
[wviewer::empty_graph]]`, the expression four other call sites in the same file
already use. The reactive guards in `display_raw` and `add_trace` are LEFT IN PLACE
deliberately: they are cheap, they are still reachable through `forget`/restore
paths this issue did not audit, and removing a guard because one route now cannot
reach it is how the unreachable arm CLAUDE.md warns about gets created.

⚠ **This issue was scouted as "the cheapest fix on the whole backlog — one seeded
value". That was wrong twice, and both refutations came from measurement rather
than review.**

### Refutation 1: the seed draws nothing (row OB3)

With the seed in and no other change, `OB3` stayed **RED at 0 rects**. Rects are
placed only by `wviewer::regenerate`, and **`wviewer::open` never calls it**. The
only route from `open` to a drawn strip is `<Configure>` → `wviewer::on_configure`
→ `after idle wviewer::configure_apply` → `regenerate`, which needs an event-loop
turn, and `configure_apply` returns early while `winfo width` is still `<= 1`.

So the model became right and the window stayed blank. **This is exactly why OB3
was written to count drawn rects rather than model entries** — a fence on the model
alone would have gone green over a viewer that still showed nothing.

Resolved by having OB3 settle the map-time `<Configure>` first (`for {set i 0} {$i <
60} {incr i} { update; after 20 }`), the same pump the `GF` and `IX` bands use for
the same reason. That is not a weakening: in a live session the idle handler runs
within a frame of the window mapping, and nothing between `open`'s return and the
first idle turn puts anything in front of the user, so the row now asserts what a
user actually experiences instead of an implementation detail about synchronicity.

### Refutation 2: the auto-plot appended past the new strip

`wviewer::ensure_auto_graph` ended in an unconditional `lappend`. With a virgin
viewer now holding one blank strip, the ASE post-run auto-plot put its graph at
index **1** — leaving the user looking at an **empty band above their waveforms**,
with every real strip shrunk to make room. That is precisely the defect the issue
**0171** follow-up removed from the Direct-Plot path, whose helper
`empty_graph_indices` is documented in the tree as *"the indices of the strips a
plot batch may REUSE instead of creating a new one"*. `plan_plot` has reused empty
strips ever since; `ensure_auto_graph` never did.

**Measured both directions rather than asserted.** With the reuse arm disabled,
`test_ase_persist` reddens **12 rows** and `test_ase_plot` reddens too, saying it
outright — `G4 auto graph is graph 0 -> {1}`, `P6 auto graph still present -> {1}`.
With it enabled both suites pass (153 and 151 checks).

Making the two paths agree is applying a settled precedent, not a new decision about
layout.

⚠ **AND THE SCOPE OF THAT ARM IS WIDER THAN THE FIRST DRAFT OF THIS FILE CLAIMED.**
Both the code comment and this section originally said the arm fires only for "the
virgin-viewer state 1616 creates and nothing else". **That was false**, and a test row
caught it rather than review: `wviewer::clear_all` (Ctrl-D) also leaves exactly one
empty strip, so a run's auto-plot after a Clear All claims that strip too. Row **CG1**
of `test_wave_clear_all.tcl` reddened at
`CG1 next auto-plot run appends its OWN strip -> {0} (exp {1})`.

That reach is **intended**, and it is the same user-visible rule in both places: after
an open *or* a Clear All, the next run's waveforms fill the window instead of sitting
under a blank band. Claiming an empty strip is never destructive — `graph_is_empty`
means zero **model** traces, so a strip holding `vec`-less traces the user can still
edit into something drawable is not empty and is never taken.

⚠ **This is a behaviour change on a shipped, eyeballed path** (issue 0171's Clear All),
so it is named here rather than buried: before, Ctrl-D then a run gave you a blank strip
on top of your waveforms; now the waveforms fill the window. It is recorded as a change
the user should be told about, not as a silent internal fix.

**CG1 was RESTATED, not renumbered.** Its old name asserted the append itself — the
behaviour this change removes — so renumbering `1` to `0` would have left a row whose
name contradicted its literal. It now fences the user-visible outcome in three rows:
the lone empty survivor is claimed, no second strip appears, and the claimed strip is
the auto strip and still empty. Suite 75 → 76 checks.

### The 27 shifted rows, and why not one literal changed

Seeding a strip shifts every fixture that built its own strips on top of the old
empty base — **27 rows** across `G10`–`G14` and `GF1`–`GF4`, plus an index shift
(the Add Trace dialog defaults to the LAST strip, so its target moves from 1 to 2),
plus two rows that would have **thrown** rather than failed (`dict get {} vec`),
aborting the case, plus 29 `IX` rows losing their determinism because
`wviewer::graph_at_pointer` opens with `if {$n <= 1} { return 0 }` and that band's
own header says a 2-strip pointer position is not reproducible headlessly.

**None of those 27 literals were renumbered.** Instead the three fixtures each add
**one fewer strip**, because the seed now supplies the first: `G10` invokes `Add
Graph` once instead of twice, `GF1` drops its invoke entirely (so the SEEDED strip
is the single graph it measures — a strictly better fence, since it now proves the
window a user gets on open fills the viewport rather than one they had to build),
and the `IX` setup drops its `add_graph` (preserving the `n <= 1` short circuit all
33 of its rows rest on). `GF4` keeps its own single invoke and is untouched.

Renumbering would additionally have left three rows whose own names assert a
geometry that no longer exists — *"a single graph fills the whole viewport"*, *"two
graphs each fill a half"*, *"the sole surviving graph re-FILLS the WHOLE viewport
(n=1)"*. A row whose name contradicts its literal is worse than a red one.

⚠ **`wviewer::restore` overwrites `layouts($token)` wholesale**, so restoring a
state dict whose `viewer` key carries `graphs {}` still produces a zero-strip
viewer. The new invariant does not reach that path, and this issue does not claim
it does.

⚠ **`wviewer::forget`'s own comment is made stale by this fix** and is corrected in
the same commit. It said *"a fresh open starts from an empty layout"*. It now starts
from a one-blank-strip layout. `forget` does unset `layouts($token)`, which is why
every fresh open re-seeds and why row OB4 can prove the seed fires rather than a
leftover surviving.

## The fence (rows OB1–OB4)

Placed at the **first** `wviewer::open` in `test_wave_viewer.tcl`, because the seed
is guarded by `if {![dict exists $layouts $token]}` and only a token that has never
had a layout exercises it.

* **OB1** — a virgin open seeds exactly one graph.
* **OB2** — that one graph is BLANK (zero traces), so it is a blank strip and not a
  strip that arrived carrying something.
* **OB3** — it is actually DRAWN, as one layer-2 graph rect. The model is not the
  deliverable; the user has to see a strip. Reads the count through
  `wviewer::in_ctx`, taking the value out via the RETURN — that proc runs its body
  at `uplevel #0`, so a `set` inside would create a global and leave the caller's
  local untouched, which `wave_viewer.tcl` warns about in its own comment.
* **OB4** — `forget` the token, reopen, still exactly one. OB1 alone could pass on a
  leftover layout; OB4 is what makes it the seed.

## ⚠ Registering the suite had to come first, and it was its own commit

`tests/headless/test_wave_viewer.tcl` printed only `RESULT: ALL PASS`. The only Tcl
reader of the completion-banner rule — `banner_complete` in `tests/banner_rule.tcl`,
the one `run_regression.tcl` sources — is
`^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$` and accepts no `RESULT:` spelling, so the
suite was **structurally unregisterable**: adding it to a case list scores
`HARNESS: … did not complete cleanly (exit=0, OVERALL_ok=0, died=0)` with every one
of its own checks passing. That is the red measured at `809c03d1` for the `wvbs`
family, one file over.

Measured both directions before changing anything rather than assumed:
`banner_complete` returns **0** for the old epilogue shape and **1** for the new one.

Registered in **`dcases` alone**. Measured at `59a6fcad`: the display arm scores
**402** checks and the headless arm **59**, because G1–G17 — every row that opens a
real viewer window — self-skip without a usable `DISPLAY`. So 343 of 402 checks are
display-only and an `hcases` copy would spend a whole case re-running 59 rows. Costs
one case and no `skip:` line (the self-skip prints uppercase `SKIPPED:`, which
`summarize_all` does not count).

**This is the THIRD site in that defect family**: `wvbs_common.tcl` (fourteen
suites, issue 1615), this file, and `tests/headless/test_results_select.tcl` — which
is still unregistered and still prints no sentinel. It was split into its own commit
because registering a suite is itself a change that needs gating, so bundling the
two would have made any resulting red unattributable.

## Still open (open=4)

1. **`tests/headless/test_results_select.tcl` is still unregistered** and still
   prints no `OVERALL: ok`. It is the fourth site, it has its own inline epilogue so
   1615's `wvbs_common.tcl` fix does not reach it, and its rows `SEL251`/`SEL252` pin
   both forms of ruling **R804**'s sentence. Not fixed here because it is not this
   issue's suite.
2. **The other 31 `test_wave_*` suites remain unregistered.** This issue registered
   one of them, for the bounded reason CLAUDE.md adopts — *a suite you add a fence
   to, you register in the same commit*. Whether the project wants the rest in front
   of the gate is the open workflow question recorded in
   `doc/claude/code_analysis/t1_runs_84_of_418_headless_suites.md`, unchanged by this
   issue.
3. **Should `ensure_auto_graph` reuse the first empty strip in a layout that has OTHER
   strips, as Direct Plot already does?** This issue claims a **lone** empty strip
   (whether it came from `open` or from Clear All) and stops there. The broader reading
   is arguably the consistent one, since `empty_graph_indices` exists for precisely
   that purpose and `plan_plot` uses it that way. It is **not** taken here because it
   would move the auto graph in layouts a user built by hand, which is a visible
   relayout nobody asked for. ⚠ That makes it a question about something the user SEES,
   so it is theirs, not an internal call.
   ⚠ **And the Clear All half of what IS taken is also user-visible** — Ctrl-D followed
   by a run used to leave a blank strip above the waveforms and now does not. That went
   in because the alternative is the 0171 defect, but the user should be told it changed
   rather than discover it.
4. **`wviewer::restore` still produces a zero-strip viewer** from a state dict whose
   `viewer` key carries `graphs {}`, because it overwrites the layout wholesale and
   never passes through `open`'s seed arm. Whether a restored session should also be
   guaranteed one blank strip was not measured here — no row covers it either way,
   which is the honest state to leave it in rather than a claim.
