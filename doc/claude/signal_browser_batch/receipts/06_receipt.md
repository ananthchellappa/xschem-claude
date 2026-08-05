# Item 06 — multi-select plot from Add Trace — IMPLEMENTER RECEIPT

Batch: `doc/claude/signal_browser_batch/PLAN.md`, item 6.
Branch `fluid-editing`. Parent commit `3c7c993f` (item 5).

---

## 1. Verdict

**`[x]`** — behaviour item, not a pixel item (driver note (a)), so the tests are
expected to judge it and they do.

`wviewer::add_trace_ok` with an EMPTY Expression now adds **one trace per selected
row, in listbox order**, each through the unchanged `wviewer::add_trace`. A typed
Expression still wins and still adds exactly one. The Name field is refused for
N > 1 and applies at exactly N = 1. The first error aborts the rest and the
already-added traces STAY — the deliberate NON-rollback of driver note (f) —
with the message reporting how far it got.

19 new checks (MS00-MS18), all green. Two named sabotages measured, both landing
on their predicted sets; four unnamed mutants measured on top, all four matching
the scout's predictions including the one it flagged as needing re-measurement.

---

## 2. Files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | `add_trace_ok` rewritten (+45/-11); the stale comment at the `-selectmode extended` line rewritten (D7) |
| `tests/headless/test_wave_sigsearch.tcl` | GROUP **MS**, 19 checks appended; three header paragraphs updated (D8) |
| `doc/claude/signal_browser_batch/receipts/06_receipt.md` | this file |

No other file changed. `cd src && make` → `Nothing to be done for 'all'` (Tcl only,
as settled decision 8 requires — no C).

### Anchors, re-verified from source before use

| plan cites | actual at 3c7c993f | ok |
|---|---|---|
| `add_trace_ok` at `:7217` | `src/wave_viewer.tcl:7821` | yes, drift +604 |
| `lindex $sel 0` at `:7226` | `:7830`, same +9 from the proc head | yes |
| decoy `lindex $sel 0` in `add_trace_pick` | `:7818` — **NOT touched**, it is the double-click-to-Expression route and is correct | confirmed |
| decoy in `hilight_wave` | `:3886` — not touched | confirmed |
| stale comment "still reads `lindex $sel 0`" | `:7718` — this item makes it FALSE, so it is rewritten (D7) | confirmed |

---

## 3. The implementation

Shape, in the order the code reads:

1. Read `gi`, `rpn`, `name` up front.
2. **`rpn ne {}` → the RPN path, byte-for-byte what it was.** One `add_trace`,
   one `xschem raw add`, one trace. `test_wave_viewer`'s G12 drives exactly this
   and still passes.
3. Empty Expression → snapshot the selection **by NAME**:
   `foreach i [$w.vars curselection] { lappend names [$w.vars get $i] }`.
   By name, never by index — item 5's AT14 lesson, since a repopulate invalidates
   indices. No sort: `curselection` answers ASCENDING, which IS listbox order, and
   adding an `lsort` would be a bug (mutant U1 measures that it would be caught).
4. `llength $names > 1 && $name ne {}` → refuse, message in `$w.err`, nothing added.
5. Empty selection → `set names [list {}]`, so the empty `rpn` reaches `add_trace`
   and its own `empty expression - type one or pick a raw variable` stays the single
   owner of that string (D3).
6. Loop; on the first error, append ` (added N of M, stopped at 'X')` **only when
   M > 1**, show it, return. Traces already added stay.

### Two properties worth recording

- **Colors are distinct for free.** Each `add_trace` re-reads the graph and calls
  `next_color`, so an N-row batch lands in N different colors (measured 3 distinct
  over a 3-row add, MS05). Nothing in this item cycles color itself.
- **All N land on the same `gi`** from `$w.graph get` — the batch never creates a
  strip, so `capture_live_view_state`'s 1:1 rect/model guard keeps holding on every
  iteration. This is why the item can go through `add_trace` at all, unlike
  `plot_signals`, whose comment at `:5296` explains why it must capture separately.

### A named, deliberate NON-optimisation (R9)

N traces means N `wviewer::regenerate` calls — N full clear+replace+redraw cycles.
The item says to go through the existing `add_trace`, so this is as specified. On a
20-signal pick it is a real cost. It is NOT optimised into a batch write here; that
is a separate change with its own risk surface (`set_graphs` once, regenerate once)
and it belongs to whoever owns viewer performance.

---

## 4. Tests — GROUP MS, 19 checks

`tests/headless/test_wave_sigsearch.tcl`, appended after the AT group. Settled
decision 9: items 1-7 all live in this one file.

**139 → 158 checks in the DISPLAY arm. `--nogui` stays at 90** (the MS group is
Tk-only and self-skips). Runtime **1.04 s → 1.35 s** whole-file.

Nothing existing was edited. `gsl_frozen_ref`, `GSO_NAMES`, `GSO_PATS`,
`GSO_BLOBS`, `GSPLAIN` were not touched by a single line (driver note (c)).

| check | what it pins |
|---|---|
| MS00 | fixture sanity: the dialog opens on the real-canvas ctx, 9 vars, graph combobox = 1 |
| MS01 | `curselection` comes back ASCENDING — the PREMISE of "listbox order", pinned as a fact |
| MS02 | OK on 3 rows does not throw |
| **MS03** | **three traces on the selected graph, in LISTBOX order** — literal expectation |
| MS04 | the other graph got nothing |
| MS05 | the three traces are in DISTINCT colors |
| MS06 | the dialog closes on a fully successful multi-add |
| MS07 | the graph rect's `node` text on the CANVAS carries all three |
| MS08 | a typed expression beats 3 selected rows: exactly one trace, name and expr applied |
| MS09 | the RPN path still closes the dialog |
| **MS10** | **Name + 2 rows is REFUSED: dialog up, NOTHING added on either graph** |
| MS11 | the refusal message is the contract string, VERBATIM |
| MS12 | Name + exactly ONE row still applies the Name — the boundary |
| MS13 | the first failure aborts the rest and KEEPS the earlier add |
| MS14 | the message reports how many were added before the failure (note (f)) |
| MS15 | no expression and no pick yields `add_trace`'s own message, exact |
| MS16 | a single failing pick keeps that message with NO count suffix — DIFFERENTIAL |
| MS17 | the multi-add path creates NO raw vectors; only the RPN path did |
| MS18 | teardown leaves the main ctx empty and writable |

### Driver note (d) — the trap it warned about, and how it is closed

The obvious trap is asserting on the selection list I set myself rather than on
what `add_trace_ok` actually read from the listbox. It is closed two ways:

- **MS03's expectation is a hand-written literal**, `[list i(v1) v(x1.x2.net5) I(V2)]`,
  never recomputed from `curselection`. A loop over `curselection` would assert the
  list against itself and pin nothing.
- **MS01 pins the premise separately.** The rows are selected in the order 7, 3, 4
  and `curselection` must answer `{3 4 7}`. So "listbox order ≠ click order" is a
  MEASURED fact in this file, not an assumption in my head. Mutant U1 (`lsort`)
  confirms the order claim has teeth: it fails 4 checks.

Three INDEPENDENT oracles observe the same batch — the model's `vec` list (MS03),
the trace colors (MS05), and the graph rect's `node` text read back off the CANVAS
after `regenerate` (MS07). That is why both named sabotages fail a superset; see §5.

### Driver note (e) — `at_wait_mapped`

Not needed and not used: **no MS check reads a value a timeout could forge.** There
is no focus record, no `ismapped` assertion, nothing whose truth depends on the
toplevel having mapped. `at_wait_mapped` is left exactly as item 5 wrote it, and no
second waiting idiom was invented. WSLg map latency shows up here only as wallclock.

---

## 5. Sabotage table

Every injection was diffed against the item baseline before running (the runner
prints the diff), confirmed to hold nothing but the sabotage, run, then reverted,
then the clean file re-run green.

| # | injection | predicted | **MEASURED** | verdict |
|---|---|---|---|---|
| **(a) narrow** | `set names [lrange $names 0 0]` after the refusal block | {MS03,MS05,MS07,MS13,MS14} | **{MS03,MS05,MS07,MS13,MS14}** — 5 | exact |
| **(a) wide** | whole block reverts to `lindex $sel 0` + single add | {MS03,MS05,MS07,MS10,MS11,MS13,MS14} | **same 7** | exact |
| **(b)** | delete the `[llength $names] > 1 && $name ne {}` refusal | {MS10,MS11} | **{MS10,MS11}** — 2 | exact, = the PLAN's own prediction |
| U1 | `set names [lsort $names]` (wrong ORDER) | {MS03,MS07,MS13,MS14} | **same 4** | exact |
| U2 | refusal threshold `> 1` → `> 0` | {MS12} | **{MS12}** alone | exact |
| U3 | drop the `if {$n > 1}` guard, suffix always | {MS15,MS16} | **same 2** | exact |
| U4 | move the refusal AFTER the loop | scout measured {MS10} with a WEAKER MS11; **required re-measurement** | **{MS10} alone** | re-measured, holds |

### U4 — the re-measurement the scout demanded, and why the number survived

The scout measured U4 with MS11 as `regexp {2}` and warned that strengthening MS11
to an exact match might change the prediction to {MS10, MS11}. **Re-measured under
the exact match: still {MS10} alone.** The reason is that U4 does not corrupt the
*message* — the loop runs first, both picks succeed, then the refusal fires and
writes the contract string verbatim. So MS11 (which pins the MESSAGE) legitimately
passes and MS10 (which pins that NOTHING was added) legitimately fails. The two
checks are pinning different things and U4 only breaks one of them. The exact match
is kept: it is strictly stronger than the regexp and it costs nothing here.

### Both named sabotages fail a SUPERSET, and that is structural

Sabotage (a) is predicted by the PLAN to fail "the 3-trace check". It fails five.
This is not a test defect and MS05/MS07 were NOT weakened to manufacture a
single-target result (ruling 17 forbids narrowing coverage to flatter a sabotage).
The loop IS what MS03, MS05, MS07, MS13 and MS14 each observe, through five
different oracles; there is no injection point that severs the loop for one of them
and not the others. Recorded the way item 5 recorded its E7.

Sabotage (b) DOES hit exactly its predicted 2. The refusal block is genuinely
isolated, and only MS10/MS11 look at it.

### ⚠ THE SABOTAGE FOUND A TEST DEFECT, ON ITS FIRST RUN

Sabotage (a)-narrow's first measurement did **not** produce the predicted set. It
produced `MS03, MS05, MS07, MS13` and then:

```
UNEXPECTED ERROR: invalid command name ".wvms1.wvadd.err"
RESULT: 5 FAILED (149 passed)
```

**MS14 never ran, and neither did MS15-MS18.** MS14 read `$msw.err cget -text`
bare. Under that sabotage scenario E's batch is truncated to one name, which
SUCCEEDS, so the dialog is DESTROYED — and the bare `cget` threw into the outer
`catch ... bigerr` and aborted the rest of the file. The count coincidentally read
5 because the abort itself scores one fail, which is exactly the kind of
coincidence that would have let this ship.

This is D2's other half. Item 5 and the scout both got the "each scenario opens its
own dialog" half right; nobody had noticed that reading the error LABEL is the same
hazard one line later. Fixed by routing **every** error-label read through:

```tcl
proc ms_err {w} {
  if {![winfo exists $w.err]} { return NO-DIALOG }
  return [$w.err cget -text]
}
```

so "the dialog vanished" becomes an **assertable value** rather than a crash. Four
checks (MS11, MS14, MS15, MS16) now go through it. Re-measured after the repair:
sabotage (a)-narrow gives the predicted `{MS03,MS05,MS07,MS13,MS14}` with
`153 passed + 5 failed = 158`, i.e. nothing was skipped. The comment at `ms_err`
records the measurement so nobody "simplifies" it back.

### One process note on reverting sabotages

The discipline says revert with `git checkout -- <file>`. **That idiom presumes a
committed baseline, and this item's implementation was not yet committed** — the
first time I used it, it reverted `src/wave_viewer.tcl` all the way to `3c7c993f`
and deleted the item. It was restored from the transcript, the clean 158 re-verified,
and every later injection was reverted from a byte-exact backup of the item state
(`diff -q` confirms equality after each restore) instead. Worth carrying: while an
item is uncommitted, a *targeted* revert means "back to the item", not "back to HEAD".

---

## 6. Runs

| run | result |
|---|---|
| `cd src && make` | `Nothing to be done for 'all'` |
| `test_wave_sigsearch` DISPLAY arm | **ALL PASS (158 checks)**, 1.35 s |
| `test_wave_sigsearch` `--nogui` arm | **ALL PASS (90 checks)**, MS/AT/BAR banners printed |
| `run_suites.sh test_wave_viewer` (R6 guard) | **ALL PASS (400 checks)** — G11/G12/G12b intact |
| full `full_audit.sh`, solo, gated | see §7 |

`test_wave_viewer`'s G11/G12/G12b are the only end-to-end drivers of `add_trace_ok`
outside this batch. G11 is the single-`selection set 1` listbox path, G12 the
RPN+Name path, G12b the error path. All three still pass, which is the evidence
that the single-pick behaviour is byte-identical.

---

## 7. Audit

Solo, gated, `tests/headless/full_audit.sh`, exit **0**:

```
SUMMARY: 265 pass  17 fail  0 crash/timeout  1 skip  (total 283)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
```

Validity checks BEFORE interpreting it:
`grep -c 'X connection to :0 broken'` = **0**; no `revive FAILED -- suite continues
UNGATED` (ruling 19); `SCRATCH: 0 leaked dir(s)`; `WIREEDIT: PASS`.

**The 17 fails are the 16 HARD baseline names, plus one FLAKY name.** No new name,
and no HARD name failed on a different check than the PLAN's Baseline block records
— the two documented clusters are intact and unchanged in shape:

- cluster (a), ACTION-LOG / SELF-LOG: `test_ase_log_seam_0207`, `test_select_at`,
  `test_selflog_output`, `test_phase3_mints`, `test_ciw` — all on
  `action log open` / `logs <cmd>` shaped checks.
- cluster (b), the three PDK libmgr tests: each on its one
  `library_list = exactly the N intended libs` check, with the extras
  `{SANDBOX TEST …}` from the USER-LEVEL `/home/qflow/.xschem/library.defs`.
- the rest at their recorded checks: `test_ase_window` W7, `test_fluid_editing` FE8,
  `test_rotate_stretch_short_0104` rot180-ip, `test_reopen_readonly` R10,
  `test_lib_manager_gui` GUI8/GUI9, `test_lib_manager_locate` LM-LOC3,
  `test_lib_sweep` P1-P4, and `test_cadence_drag` (RE-ANCHORED, any failure is
  baseline by the stated exception).

The 17th, **`test_altf5_ciw`, is on the 22-name FLAKY list. Re-run 3x: 3/3 PASS.**
Cleared.

The one SKIP is **`test_ase_dirty`** — re-run solo: **ALL PASS (41 checks)**. This is
the "environmental self-skip whose NAME FLAPS run to run" the baseline documents; the
clean re-baseline run had exactly one such skip too (`test_alt_transform_group_0116`,
266/16/1). Same count, different name, same nature.

**Every waveform test passed**, including the two whose failure would most implicate
this item: `test_wave_viewer` (the G11/G12/G12b guard) and `test_wave_sigsearch` (the
item's own file). Notably `test_wave_trace_menu` — the ~50% flake ruling 22
re-listed — also passed here, so no ruling-22 A/B was needed: nothing failed that I
had cause to suspect myself for. Had one, the decisive evidence would have been an
A/B with `src/wave_viewer.tcl` reverted, not a re-run count.

---

## 8. Divergences — DECLARED

| # | divergence | why |
|---|---|---|
| **D1** | the MS fixture points `win_path` at `$SLMAIN` (`.drw`), NOT the AT group's `$SLVWP` | forced, and it is the item's biggest finding. `$SLVWP` is `.x1.drw`, a **TAB** (`tabbed_interface` 1), so `winfo exists` is 0 and `add_trace` → `regenerate` → `viewport_rect` throws `bad window path name ".x1.drw"` at `winfo width $wp` — **after** `set_graphs` has already written the trace. The dialog half of item 5's handoff works; the ADD half does not. Isolated: `viewport_rect .x1.drw` rc=1 vs `viewport_rect .drw` rc=0 |
| **D2** | each scenario opens its OWN dialog, **and every error-label read goes through `ms_err`** | forced; the second half was found by a sabotage, see §5 |
| **D3** | the empty-selection case is routed through `add_trace` with an empty rpn | so the "empty expression" string has ONE owner; MS15 pins it |
| **D4** | the count suffix appears only when N > 1 | so a single pick's message is byte-identical to today's; MS16 pins it differentially, U3 measures that dropping the guard is caught |
| **D5** | deliberate NON-rollback, per driver note (f) | stated, not silently rolled back. I agree with the ruling: a rollback would have to un-`regenerate` N times and the partial state is honest as long as the message says how far it got, which MS14 pins |
| **D6** | `plot_signals` considered and rejected as the vehicle | its own comment at `:5296` says it must capture live view state separately because the strip count grows under it. This batch never creates a strip, so `add_trace` in a loop is correct and simpler |
| **D7** | the comment at the `-selectmode extended` line is rewritten | this item makes "add_trace_ok still reads `lindex $sel 0`" FALSE. Same repair item 5 declared as its D10 |
| **D8** | three non-appended header-paragraph edits | (i) an `MS00-MS18` entry in the group index; (ii) "BAR **AND AT** … 49 of 139" → "BAR, AT **AND MS** … 68 of 158"; (iii) the PROCESS-STATE paragraph gains an MS entry. Items 3/4/5 all did the same |
| **D9** | one number fixed in a paragraph D8 already rewrites | that paragraph said "this whole **119**-check suite", stale since item 3. Leaving 119 beside my corrected 158 in the same block would be actively misleading, so it now reads 158. No behaviour, no check |

---

## 9. Carried forward

- **ITEM 7 INHERITS AN EXTENDED `sl_main.raw`.** The MS group extends the MAIN
  context's raw from 2 vectors to **10** — the 7 `SLFIX` names plus `db1` from the
  RPN check. It deliberately does NOT `raw new` (that would drop `wrong_ctx_var`,
  which SL12 still names in the same process). The raw stays extended; it cannot be
  undone in place. MS17 is the check that pins the exact 10.
- The MS group is the **first in this file that really DRAWS**. `regenerate` puts
  graph rects into the MAIN schematic and `with_edit` leaves it `readonly 1`. The
  teardown switches back to `$SLMAIN`, clears readonly, clears the drawing and clears
  the modify flag; **MS18 is the check that it really did** (rects=0, readonly=0).
  Item 7 gets a clean canvas, not a promise of one.
- Left defined for item 7: `ms_open`, `ms_field`, `ms_err`, and the globals `MSALL`
  and `MSREF`. Items 3's `gsl_frozen_ref`/`gso_*` names are still off limits.
- No third xschem context was created.

---

## 10. EYEBALL — what a human should look at (not owed as a gate, this is `[x]`)

Behaviour, so the checks judge it. But two things are worth a real user's eye:

1. **R8 — the refusal fires from `<Return>` in the Name field.** Two bindings reach
   `add_trace_ok`: `bind $ee <Return>` and `bind $ne <Return>`. So the most likely way
   a real user meets `one Name cannot cover N traces …` is typing a name, hitting
   Return, and having the dialog stay up. That is correct, and the message says what
   to do ("clear the Name field, or select a single row"). Worth confirming it reads
   well in the label's actual width.
2. **The partial-add message.** Pick five signals where the third is bad and confirm
   `… (added 2 of 5, stopped at 'X')` is legible and that the two traces really are on
   the graph behind the still-open dialog.
