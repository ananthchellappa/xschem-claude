# Receipt 18 — issue 0318: resizing the sidebar wiped the sentence in the pane

**Task** `doc/claude/suggestions/next_task_0318_resize_wipes_in_pane_notice.md`
**Issue** `doc/claude/issues/0318-resizing-the-sidebar-wipes-the-in-pane-notice.md`
**Branch** `fluid-editing` · start HEAD `a34dbf80` · **nothing pushed**
**Commit** `f6e3b20a` (unpushed)
**Files** `src/wave_viewer.tcl`, new `tests/headless/test_wave_sigbrowser_0318.tcl`,
new `doc/claude/issues/0320-…md`, this receipt, the issue's Status line.

---

## 1. The defect, in one paragraph

`browserseanote($token)` holds §F item F5's one sentence explaining why the signal
browser's lower pane is empty. Its whole lifetime was
`set browserseanote($token) {}` at the top of `browser_sea_refresh`, whose comment
argues — correctly — that "a refresh means the user moved". The sea canvas's
`<Configure>` was wired straight into that same proc, so **a resize was treated as
a navigation**: dragging issue 0312's width grip narrow deleted the sentence and
the pane went back to being the unexplained empty box F5 exists to abolish. The
user reported it by hand at `EYEBALL_QUEUE.md` item 5 step 7.

## 2. Which candidate I chose, and why

The issue offered two: **(1)** give `browser_sea_configure` a refresh that redraws
without clearing (save/restore named as one way to spell it), or **(2)** split the
clear out of `browser_sea_refresh` into the callers that really are navigations.
It said (2) is the honest shape. **I took (1)**, spelled as an explicit
`{keepnote 0}` parameter rather than a save/restore dance:

```
proc wviewer::browser_sea_refresh {token {keepnote 0}}   ;# default = NAVIGATION
proc wviewer::browser_sea_configure {token} { … $token 1 }   ;# the one geometry caller
```

Four measured reasons, in the order they decided it:

1. **The default stays "clear", which is the safe direction, and that is the
   codebase's own ruling.** The array's doc comment says *"a stale reason on a pane
   that has since been repopulated would be worse than no reason."* Splitting the
   clear into the navigation callers **flips the default to keep** — every future
   caller that forgets to classify itself then leaves a stale caption. With a
   parameter, forgetting means clearing. The classification is still written down
   in the code (that is (2)'s real benefit) without inverting the failure mode.
2. **The caller count is 3, and (2) alone does not actually fix the caption.**
   Measured, all callers of `browser_sea_refresh` in the tree:
   | # | site | classification |
   |---|------|----------------|
   | 1 | `bind $f.pw.tvf.tv <<TreeviewSelect>>` (`browser_build`) | **navigation** — a new node, and `browser_populate`'s `selection set` fires it once per repopulate |
   | 2 | `browser_refresh`'s tail (`catch {…}`) | **navigation** — a Search/Filter keystroke that narrowed nothing away, so ttk fired no select event |
   | 3 | `browser_sea_configure` (the canvas `<Configure>`) | **GEOMETRY — the one exception** |
   | — | `src/ase.tcl` | none (checked; BZ02 leg 4 pins it) |
   Splitting would have left `browser_sea_say` at the tail still overwriting the
   pane's caption on a resize, so the sentence would come back on the canvas and
   stay lost on the caption — and on the F5 case where the pane is NOT empty (the
   analog fall-through) the caption is the *only* surface carrying it, so the split
   would not have fixed that case at all.
3. **Save/restore around the call is worse than the parameter, for a reason in the
   proc's order:** the clear happens BEFORE the draw, so a restore afterwards needs
   a SECOND draw to put the sentence back, and the caption is overwritten in
   between. The parameter needs one draw and touches no surface.
4. **One geometry door, not five.** Every door the issue's Reachability section
   lists — the grip, the sash, the toplevel resized, a tab bar appearing, a WM
   tiling the window — reaches the pane through that single `<Configure>` bind. I
   verified no geometry path reaches the note through `browser_refresh` instead
   (all 8 of its callers are loads/navigations). **One exception, declared:**
   `Ctrl-B` twice still clears, because `browser_show`'s own rule is
   SHOW = REPOPULATE (it re-reads the raw) — a navigation by the code's own
   declaration, not a geometry event.

A kept notice also **keeps the caption**: with `kept` non-empty the refresh returns
after the draw and before `browser_sea_say`. A geometry event re-flows the pane; it
says nothing.

## 3. What else the change does

* `browser_refresh`'s **two bail-out arms** (`browser_rows_multi` throws,
  `browser_populate` throws) now clear the notice. They return after rewriting the
  pane's snapshot and before the tail refresh — the one place the note was
  cleared — so a failed navigation used to leave a sentence about a pane that no
  longer exists, and since this fix the next `<Configure>` would KEEP it. A
  navigation that failed is still a navigation. (Review finding; see §5.)
* `keepnote` is normalised with `string is true -strict`, because this proc rides
  `<<TreeviewSelect>>` where a throw pops a modal bgerror that hangs a headless
  run, and `if {!$junk}` throws.

## 4. The check, and the sabotage table

`tests/headless/test_wave_sigbrowser_0318.tcl` — **17 checks under X, 5 on the
`--nogui` arm.** Band `BZ`. It obeys the issue's ⚠: it drives the **real drag**
(`browser_grip_press`/`_motion`/`_drop`, the shipped handlers, with the X
coordinates a pointer would deliver) and then **reads the canvas item**, never the
variable — count, text, wrap width, **colour** and **bbox** of the `seanote` tag,
plus the pane caption and the sidebar status line. A spy on the trampoline proves a
real `<Configure>` arrived, so "it survived" cannot be satisfied by a resize that
never happened; and BZ13/BZ13b prove the sentence was **re-flowed**, not merely
left over, by tracking the wrap width at two widths (one of them clear of the
240 px clamp, because at the clamp the arithmetic collides with the draw's own
fallback constant).

**19 mutations, each applied to `src/wave_viewer.tcl`, the whole file re-run,
reverted from a byte copy. The table is in the test file's header with the reds per
row; it was re-measured from scratch after review changed the checks.** Every one
of the 17 checks is red in at least one row, and no mutation produced a BGERROR.

**The battery found holes, as the brief predicted:**

* **The predicted hole did not exist** (S6, the trampoline calling
  `browser_sea_draw` privately): written expecting only the source checks to see
  it, measured reddening BZ15 as well, because a private draw path never
  re-captions the pane. Recorded in the row rather than dropped.
* **S18 (the keep reading the note array without its token) was green on all 17
  checks** on first measurement. The canvas cannot see it — the draw reads the note
  per token — so BZ20 had to gain a **caption sentinel** before the row reddened
  anything. That is a hole the battery found in my own check.
* **S14 is the first cut of my own fix.** Adding the clear to `browser_refresh`
  without `variable browserseanote` addresses a **local** array; the write succeeds
  against nothing and the `catch` hides it. A source grep for the clear passes.
  Only BZ19, which is behavioural, sees the difference. I nearly shipped it.

## 5. Adversarial review — two lenses, both by agents that are not the implementer

Lens 1 **Tk/Tcl event-lifetime correctness**; lens 2 **evidence quality**. Neither
ran a suite (the panel was paused for part of the session); both reasoned from
source. Triage of everything they raised:

| # | finding | verdict | action |
|---|---------|---------|--------|
| 1-1 | the geometry path still drops the pane's **selection** (`browserseasel`/`browserseaanchor` reset unconditionally), and my new comment claimed the resize changes nothing | **CONFIRMED** | **Not fixed by design** — filed as **issue 0320**, per the brief's "a further door gets its own issue"; it needs its own ruling about an index-based selection and a check that reads `selbox`. The trampoline comment and the test's DOES-NOT-CLAIM now name it, and the over-broad claim is narrowed to "which NAMES the pane lists has not changed". |
| 1-2 | `browser_refresh`'s two throwing arms return before the tail clear, so my fix **widened** an existing hole: a Configure now keeps a sentence about a pane whose snapshot was replaced | **CONFIRMED (widening)** | **FIXED** — the two arms clear the note (+ the `variable` declaration that makes the clear real). New check **BZ19**, sabotage rows **S13/S14**. |
| 1-3 | my comment said the caller count is pinned "behaviourally" by BZ02; BZ02 is a source grep | CONFIRMED (false claim) | **FIXED** — comment says source count, and BZ02 gained a spelling-agnostic leg. |
| 1-4 | "anything that is not a true boolean reads as 0" is wrong for `2` (`Tcl_GetBoolean` semantics) | CONFIRMED (imprecision) | **FIXED** — comment corrected. |
| 2-2 | the notice's **colour** is pinned by nothing here or in the tree: `-fill {#8b0000}` → `-fill [ase::theme table]` draws it **white on white** — the user's exact reported symptom — with 13/13 green | **CONFIRMED HOLE** | **FIXED** — `bz_note` reads `-fill`; legs in BZ11/BZ12; row **S15**. |
| 2-3 | the notice's **position** is pinned by nothing: `create text 6 4` → `600 4` puts it outside a pane whose scrollregion has zero width — invisible, 13/13 green | **CONFIRMED HOLE** | **FIXED** — `bz_note` reads the bbox, `bz_visible` asserts it is inside the pane; legs in BZ11/BZ12; row **S16**. |
| 2-1 | BZ02's "no caller in ase.tcl" leg was satisfied by "ase.tcl was never opened" (`catch` → `{}`, `string first` → -1) | CONFIRMED HOLE | **FIXED** — sentinel leg proving the file was read. |
| 2-4 | BZ17's whole pre-state was manufactured by an earlier check's side effect | CONFIRMED | **FIXED** — the pre-state is minted and asserted; S7/S8 now red BZ17. |
| 2-5 | BZ14's second door was variable-only (the node it navigates to lists cells, so the canvas leg reads `none` either way) | CONFIRMED weak leg | **FIXED** — a third door lands back on the empty node, where a survivor would be drawn. |
| 2-6 | F5's **third surface** (`$f.ph`) was never read; deleting it left 13/13 green | LIKELY | **FIXED** — leg in BZ11; row **S17**. |
| 2-7 | BZ13 leg 3 is ambiguous at the 240 px clamp (228 is also the draw's fallback) | LIKELY | **FIXED** — new **BZ13b** measures at 336 px, clear of the clamp. |
| 2-8 | BZ10 did not prove the 400 px start width was APPLIED (only returned) | LIKELY | **FIXED** — leg compares the canvas width to the width asked for. |
| 2-9 | BZ02's exact-text count misses a caller spelled with another variable | LIKELY | **FIXED** — spelling-agnostic leg (`browser_sea_refresh \$` == 3). |
| 2-10 | the sub-80 px wrap floor the issue quotes is exercised by nothing | LIKELY | **FIXED as far as it can be** — source check **BZ05** + row **S19**; the 240 px clamp puts the floor out of any fixture's reach, and DOES-NOT-CLAIM says so. |
| 2-11 | `Ctrl-B` twice still clears — one of the four doors the issue lists | CONFIRMED, by design | **DECLARED**, not fixed: SHOW = REPOPULATE. In the trampoline comment and DOES-NOT-CLAIM. |
| 2-12 | issue 0320 is live on this very fixture and was not disclaimed | CONFIRMED | **FIXED** (disclaimer). |
| 2-13 | a token-blind keep would be invisible to a one-window fixture | SPECULATIVE | **FIXED** — **BZ20** + row **S18**, without a second window (a second token's note is a value in the same array). |
| 2-14, 2-15 | two sabotage rows' prose overstated what they prove (S11's throw needs a future caller; BZ16 is not the only check a one-shot keep reds) | NOT-A-BUG, overclaimed | **FIXED** — both corrections recorded in the file. |
| 2-16 | "MEASURED" had no artifact yet | process | this receipt + the re-measured table. |
| 2-18 | the `--nogui` arm prints `ALL PASS` on 5 greps | disclosure | in DOES-NOT-CLAIM. |
| 2-19, 2-20 | BZ18 leg 5 near-vacuous; BZ11 leg 4 lacked `bs_num` | NOT-A-PROBLEM / consistency | leg 4 wrapped in `bs_num`; leg 5 left (it does catch a model re-derivation). |

**Left recorded and not fixed: 1-1/2-12 (issue 0320) and 2-11 (Ctrl-B).** Both are
declared in the code and in the test.

## 6. Suites

Standalone, before the audit (`run_suites.sh`, `GUI_GATE=1 DISPLAY=:0`):

| suite | result |
|---|---|
| `test_wave_sigbrowser_0318` (new) | **ALL PASS (17)** under X, **ALL PASS (5)** `--nogui` |
| `test_wave_sigbrowser` | ALL PASS |
| `test_wave_sigbrowser_sea` | ALL PASS (79) — **see the flake note** |
| `test_wave_sigbrowser_panes` | ALL PASS (81) |
| `test_wave_sigbrowser_2pane` | ALL PASS (108) |
| `test_wave_sigbrowser_i14` | ALL PASS (109) |
| `test_wave_sigbrowser_i12` | NORESULT in a batch (binary never reported) — re-run in the audit |

**Flake note, recorded because it looks alarming:** the first batched run of
`test_wave_sigbrowser_sea` reported **18 FAILED**. Every failure traced to a
**stale search-bar pattern (`*net12*`) leaking forward from BQ66** — the pane then
lists 1 name instead of 23, so BQ54-BQ71 all read the wrong pane. That is the
documented WSLg key-delivery class (`bs_type`'s `event generate <KeyRelease>`
stalling, which the prelude's own header describes): the entry is cleared by
`$e delete`, the callback never runs, and the previous filter stands. **It passed
79/79 standalone**, twice removed from my change (no path from `keepnote` to the
search bar). Not a regression.

The remaining family members and `test_ase_cosim` are re-run whole by the audit
below, which is how they are reported.

## 7. The audit, diffed by test NAME

Two comparisons. The required baseline `doc/claude/batch_F/baseline_status.txt`
(306 tests, 2026-08-09) and — better evidence — the driver's own `full_audit.sh`
that finished at **my exact start HEAD `a34dbf80`** minutes before I began
(313 tests, extracted to a name/status list).

My run: `SUMMARY: 279 pass 27 fail 3 crash/timeout 5 skip (total 314)`,
`WIREEDIT: ALL PASS` (58/58), `SCRATCH: 0 leaked dir(s)`. The before-run at the
same HEAD was `288 pass 23 fail 1 crash/timeout 1 skip (total 313)` — **and the
count is not the evidence**; the names are.

### ⚠ This run straddled an X-server death, which is why it looks worse

The gate panel itself **died and was revived at 10:00:50** mid-run
(`~/.claude/gui_test_gate/events.log`: `panel revived`), which is the documented
WSLg Xwayland failure (`doc/claude/…/wslg-xwayland-aborts`). Five rows went
`PASS → SKIP` — a **self-skip is "no X"**, not a failure of the code — and that is
the signature, not a coincidence.

### A. vs the driver's own audit at my start HEAD `a34dbf80` (same extraction)

**Red-ward, 12 rows. EVERY ONE RE-RUN STANDALONE AND GREEN:**

| row | audit | standalone re-run |
|---|---|---|
| `test_wave_sigbrowser_i12` | FAIL | **ALL PASS (126 checks)** |
| `test_ase_plot` | TIMEOUT | **ALL PASS (150 checks)** |
| `test_altf5_ciw` | FAIL | **ALL PASS** (`--logdir`) |
| `test_delete_cut_selflog` | SKIP | **ALL PASS** (`--logdir`) |
| `test_perform_action_rotate_in_place` | FAIL | **ALL PASS** (`--logdir`) |
| `test_perform_action_floaters_from_selected_inst` | FAIL | **ALL PASS** (`--logdir`) |
| `test_perform_action_show_unconnected_pins` | TIMEOUT | **ALL PASS** (`--logdir`) |
| `test_pin_type_edit` | FAIL | **PASS=19 FAIL=0** |
| `test_readonly_action_dispatch` | FAIL | **ACTION_READONLY_TEST_PASS** |
| `test_alt_transform_group_0116` | SKIP | **ALL PASS (5 checks)** |
| `test_rotate_prompt_object` | SKIP | **ALL PASS** |
| `test_rotate_stretch_reconnect_0100` | SKIP | **ALL PASS (51 checks)** |

`test_wave_sigbrowser_i12` is the only one of the twelve inside this change's
blast radius, and it is green twice over. The other eleven are wire-editing,
action-log, pin-editing and ASE cases that never open the signal browser.

**Green-ward / new, 4 rows:** `test_wave_sigbrowser_i1315` FAIL → **PASS** (the
known `BP72` `:0`-geometry flake), `test_connected_drag_keeps_selection_0113`
SKIP → PASS, `test_fluid_editing` FAIL → SKIP, and
**`test_wave_sigbrowser_0318` (new) → PASS**.

**The whole sigbrowser family in this run:** `test_wave_sigbrowser`,
`_0312`, `_0315`, `_0318`, `_2pane`, `_digital`, `_i11`, `_i14`, `_i1315`,
`_keys`, `_panes`, `_sea`, `test_wave_sigsearch` and **`test_ase_cosim`** — all
**PASS**; `_i12` FAIL in the batch and PASS standalone (above).

### B. vs `doc/claude/batch_F/baseline_status.txt` (2026-08-09, 306 tests)

Same 12 red-ward rows minus the ones the baseline already had, plus these
differences that are **not mine**: `test_hover_highlight` and
`test_wave_trace_menu` PASS → FAIL (both re-run standalone by nobody this
session; neither is in this change's reach, and both are in the same
X-death run), and 9 rows that went **green** since the baseline
(`test_ase_persist`, `test_fluid_bodyshove_guards_0132`, `test_wave_axis_zoom`,
`test_wave_crossdb_trace`, `test_wire_vertex_grab`,
`test_rotate_stretch_dangling_0103`, …) plus 7 test files that did not exist
then. The 58 `test_wireedit_*` rows read as `MISSING` in this comparison only
because the baseline lists them individually while `full_audit.sh` reports that
phase as one verdict — mine says `WIREEDIT: ALL PASS`. **Comparison A is the
apples-to-apples one** (same machine, same HEAD, same extraction, 50 minutes
apart).

## 8. What this does not claim

* **It does not claim the sentence is LEGIBLE at ~250 px.** That is
  `EYEBALL_QUEUE.md` item 5 step 7's verdict and it is a human's. The checks say
  the sentence is drawn, in `#8b0000`, inside the pane, wrapped to the pane's
  width at two widths. They do not say it reads well, and I did not touch the
  wording (the owed eyeball on that is not pre-empted).
* **It does not claim every F5 door is closed.** `Ctrl-B` twice still clears the
  notice (SHOW = REPOPULATE) and the same resize still throws away the pane's
  **selection** (issue 0320). Both declared in code and test.
* **It does not claim the end-to-end gesture.** The notice is minted by calling
  `browser_notice` directly on a real sidebar in a bare toplevel; the Ctrl-Alt-V →
  `ase::show_in_browser_for_current` → F5 path is `test_wave_sigbrowser_digital`'s
  FD20-FD27.
* **It does not claim anything about the `--nogui` arm beyond 5 source greps.**
* **It does not claim the two review agents ran anything.** Both were source-only
  (the GUI panel was paused for part of the session); every finding I acted on I
  re-measured myself with a sabotage row.
* **Issue 0320 is filed on a source argument, not a measurement.** The probe I
  wrote for it hung under the gate and I dropped it rather than spend the session
  on an out-of-scope issue; 0320 says so and carries the recipe. The mechanism —
  one unconditional `set browserseasel($token) {}` reached by one geometry caller
  — is read off the source, and review lens 1 confirmed it independently.
* **`test_hover_highlight` and `test_wave_trace_menu`** are red against the
  2026-08-09 baseline in this run and were **not** re-run standalone (they are
  outside this change's reach and were red-ward only in comparison B). Someone
  should confirm them on a clean display before trusting comparison B.
