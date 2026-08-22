# Driver run 2026-08-16 — branch `annotate`, OP-annotation plan S1–S12

Plan: `doc/claude/suggestions/next_session_prompt_op_annotation.md`
Spec: `doc/claude/specs/op_annotation.md`

Status codes: **x** done+verified+committed · **F** failed (tree left clean, nothing committed) ·
**D** deferred (blocked; nothing committed) · **E** landed but needs a human eyeball
(GUI-only proof, or a user-visible behaviour change nobody ratified)

| item | status | commit | tests | new issues | one-line result |
|---|---|---|---|---|---|
| S1 | E | 44f1c886 | T1 3 FAIL/0 GOLD?/0 RESULT?/0 FATAL/3 NOGOLD -> identical (all 3 pre-existing: 0420, 0421); T2 6/6 goldens PASS -> identical; 11 T3 suites identical (raw_read_dispatch 51, raw_read_failure_0306 63, raw_ascii_point_bounds 90, backannotate_digital 81, ase_core 74, ase_final 28, wave_cursor_crossdb 93, ase_hier_pick_0161 21, resolved_net_attr_scope_0163 34, hi_descend, ciw_actionlog canary 25); NEW t | 0420,0421,0422,0423,0424,0425,0426 | May I run ./configure to regenerate the stale gitignored src/Makefile? Until then `make install` from this tree ships an xschem.tcl that sources an uninstalled op_annot.tcl, and the installed binary segfaults at startup (exit 139, measured — issue 0424). |
| S2 | E | 2be60ece | test_op_annot 32->65 ALL PASS; T1 3 FAIL->3 FAIL (same texts, 0420+0421); T2 HARNESS PASS 6/6->6/6; T3 sky130a_libmgr 18->18, gf180mcud_libmgr 29->29, ihp_sg13g2_libmgr 1FAILED/65->same, gf180_ase_defaults 18->18, ase_final_gf180 33->33, pdk_launcher 30->30, launch_context 7->7; T4 make not run (pure Tcl, build unspent) | 0427, 0428, 0429, 0430, 0431 | sky130's OP save list carries cgso/cgdo, which ngspice-42 rejects - and one rejected .save card makes ngspice write NO raw file at all: correct them to cgs/cgd (re-baselining the prototype and test row P3), or keep bug-compatibility with the prototype until S5 deletes it? |
| S3 | F | f3bded23 | test_op_annot 65->65 ALL PASS (attempt's 83/85 reverted); headless run.sh 6/6 PASS; T1 3 FAIL/0 GOLD?/0 RESULT?/0 FATAL unchanged; descend family all rc=0; no build run | 0432,0433,0434,0435,0436,0437 | S3 implemented and green (85 checks, 11 sabotage variants) but REVERTED: it emits save cards naming devices that will not be in the deck, which under the bench idiom costs the entire raw file — no code committed, only the write-up plus the recoverable patch. |
| S3b | F | cc7a4083 | test_op_annot 65->65 (retry's 96 reverted); T1 3 FAIL->3 FAIL unchanged; T2 HARNESS PASS 6/6->6/6; no build (0 .c/.h/.y/.l touched) | 0438,0439,0440,0441,0442 | S3 retry refuted again and reverted: the netlist filter covers 3 of the netlister's 7 drop classes, and each resulting bad card writes NO raw at all on both ngspice binaries; basis fix (0436) and cgso ruling (0429) were sound, the latter kept. |
| S3c | F | none | test_op_annot 65->65 ALL PASS after driver restore; tree clean | 0443 | driver: crew produced no receipt — 11 agents over ~32h, killed twice by process exit, no commit and no row; working tree left modified and restored by the driver, attempt preserved as doc/claude/issues/0443-attempt-3-interrupted.patch (4117 lines). S3/S4 deferred; run continues at S5. |
| S5 | E | 9fe40128 | test_op_annot 65->97 (0 FAIL); raw_read_failure_0306 63->63; raw_read_dispatch 51->51; raw_ascii_point_bounds 90->90; T1 3 FAIL/0 FATAL->same; T2 6/6->6/6 | 0444,0445,0446,0447,0448 | Ratify two unratified user-visible changes: (1) S5 added one space to sky130_procs.tcl and gf180_procs.tcl OUTSIDE its declared Files cell (0444) - keep it, or revert and ship vgs/vds permanently blank on sky130 and gf180? (2) an IHP FET block is now 13 rows with cgg naming the raw vector and cgg_tot the sum, where the prototype showed 10 with cgg holding the sum - ratify, or relabel cgg_tot back  |
| S6 | F | none | not reached | none | crew aborted: scout produced nothing |
| S6b | E | 1f1b8125 | test_op_annot 97->115 ALL PASS; T1 run_regression 3 FAIL->3 FAIL (same 3, issues 0420/0421); T2 headless/run.sh PASS 6/6->PASS 6/6; sabotage 7/7 predicted reds observed | 0449,0450,0451 | Ship the annotator with issue 0446 accepted — on sky130/gf180 a wrong .raw paints a fabricated `vgs = 0` / `vds = 0` on a FET — or hold the carrier until 0446's C fix (token.c:4364/:5441) lands, and please look at the pixels (look debt annotate_params_on_tb_bandgap open; also owed: is 0447's `?` block an acceptable failure mode for a user's malformed descriptor)? |
| S7 | E | 8ac98756 | test_op_annot 115->147 headless (149 w/ display); property_form/body 284->288; T1 run_regression 3 FAIL->3 FAIL (same 2 suites, same 3 literal msgs); T2 headless/run.sh 6/6 goldens PASS; pin_name_text + nh_export_custom_color + 9 instance_bbox suites all PASS | 0452,0453,0454 | annot_show defaults to 0, so the annotator S6 shipped always-on now renders dark until `xschem set annot_show 1` — is 0 the right resting state for a freshly started xschem, or should S7 default to 1 and let S8's Ctrl-6 introduce the off state? |
| S8 | E | 523aa507 | test_op_annot 147->172 ALL PASS; test_launch_context 7->13 ALL PASS (Xvfb :99); test_wave_sigbrowser_i12 126->126; T1 3 pre-existing FAIL (0455,0456) unchanged; T2 harness 6/6 | 0455,0456,0457,0458,0459,0460,0461,0462 | Should annot_show get a first-class stock control - a View-menu pair of checkbuttons, or three registered C actions in keybindings.csv so the chords are remappable - or is the cadence profile the intended home for this feature? |
| S9 | F | 48f4e4a3 | test_op_annot 172 -> 192 headless / 195 on :99 ALL PASS with the impl, back to 172 ALL PASS after revert; T1 3 FAIL / 0 GOLD? / 0 FATAL / 3 NOGOLD unchanged (0455, 0456 pre-existing); T2 harness PASS 6/6; test_pin_name_size_win 9/9, migrate_pin_names, drag_keeps_selection, nh_export_custom_color, nh_angle_render, hover_selection_repair, create_instance all unmoved | 0463,0464,0465,0466 | S9 built, green on 192/195 checks and 9 sabotage variants, then REVERTED: its per-instance cache paints the previous file's numbers after `xschem reload` (I3); the attempt is preserved as doc/claude/issues/0466-attempt-1-reverted.patch and the retry is one annot_data_changed() in load_schematic() plus a same-path reload row. |
| S9b | E | 616aecc9 | test_op_annot 32F/176P -> ALL PASS 209 headless + ALL PASS 214 xvfb; T1 3 FAIL/3 NOGOLD unchanged (0455+0456); T2 HARNESS PASS 6/6; 19 guard suites ALL PASS; test_undo_selection 20ok+sig11 unchanged (0467) | 0467,0468,0469,0470,0471,0472,0473,0474 | S9b ships the overlay's anchor, size 0.2, layer 15, offsets +5/0 and Monospace as compiled-in constants whose only escape is per-instance annot_dx/annot_dy — should they be user-settable (a preference or an rc variable) before this ships? |
| S10 | F | none | not reached | none | crew aborted: scout produced nothing |
| S10b | E | 09c4a2cd + 503d1018 | test_op_annot 209->218 headless / 214->223 xvfb; T1 run_regression 3 FAIL->3 FAIL (floor: 0420+0421); T2 headless/run.sh PASS 6/6->PASS 6/6; T4 make NOT RUN (data+Tcl+docs, src/xschem byte-identical) | 0475, 0476 | S10b makes 40 shipped sky130 FET symbols annotation-silent unless View > Show hidden texts is on — for a user whose rc never sources sky130_procs.tcl, AND (newly measured) for anyone who reached the symbol through a vendored or aliased library since the descriptor matches on cell::name, that is pure subtraction at every annot_show value: ratify (a) ship as implemented with show_hidden_texts as the |
| S11 | E | 734456be | test_op_annot 218->241 headless / 223->246 display(:99); wave_cursor_crossdb 93->93, backannotate_digital 81->81, wave_viewer 57->57, wave_crossdb_trace 56->56, wave_markers 437->437; T1 3 FAIL-at-eol (pre-existing 0420/0421), T2 HARNESS PASS 6/6 | 0477,0478,0479,0480,0481,0482,0483 | A cursor parked outside the loaded sweep now silently moves every annotated number on a GRAPHLESS schematic to the last sample (RULING D4-4's endpoint hold, identical to the graph path) — is that silent hold right, or should BOTH paths (never one) gain a seam or status-line note naming the condition? (issue 0479) |
| S12 | F | 479be885 | T1 run_regression 3 FAIL->3 FAIL (0420+0421 pre-existing), 0 GOLD?/RESULT?/FATAL; T2 headless/run.sh PASS 6/6->PASS 6/6; T3 test_op_annot 241->241 headless, 246->246 display. No build run. | 0484,0485 | S12 NOT COMPLETED - implement agent changed nothing; write-up filed 0484/0485, consumed the numbers, reconciled plan numbering to 0486 and wrote the spec blocker + nine unratified questions; deliverable (1) still owed. |
| S12b | E | d56283ec | test_op_annot 241->241 headless / 246->246 xvfb; T1 regression 3 FAIL->3 FAIL (pre-existing 0420/0421); T2 run.sh PASS 6/6->6/6; wave_cursor_crossdb 93->93, backannotate_digital 81->81, wave_viewer 57->57, wave_crossdb_trace 56->56, wave_markers 437->437; make NOT run (md5 2f41eadd unchanged) | 0486,0487 | Read §6 of doc/claude/code_analysis/waveform_subsystem_reference.md — is it now an accurate description of the shipped OP-annotation subsystem, in particular §6.5's corrected claim that only params/derived rows blank without .save cards while pinexpr rows (vgs/vds) still render? |

---

## Closing block — run finished 2026-08-21

**Counts.** 17 dispatches, 12 distinct plan steps. **x** 0 · **E** 9 · **F** 8 · **D** 0.

Nothing reached `x`. Every landed step carries an unratified user-visible decision or a
pixel deliverable no green suite can clear, which is exactly what **E** is for — the crews
declined to round partial results up, three times reverting work that was already green
(S3 at 85 checks, S3b at 96, S9 at 192) because an adversary refuted it.

| step | status | commit |
|---|---|---|
| S1 name builder | E | `44f1c886` |
| S2 PDK descriptors | E | `2be60ece` |
| S3 / S3b / S3c save cards | F F F | write-ups only (`f3bded23`, `cc7a4083`, `ce07064e`) |
| S4 ASE integration | — | never dispatched, deferred with S3 |
| S5 display formatter | E | `9fe40128` |
| S6 / S6b annotator symbol | F, E | `1f1b8125` |
| S7 annotation classes | E | `8ac98756` |
| S8 the three keys | E | `523aa507` |
| S9 / S9b draw-time overlay | F, E | `616aecc9` |
| S10 / S10b symbol cleanup | F, E | `09c4a2cd` + `503d1018` |
| S11 graphless cursor | E | `734456be` |
| S12 / S12b docs and issues | F, E | `479be885`, `d56283ec` |

`tests/headless/test_op_annot.tcl`: **32 → 241 checks headless / 246 under Xvfb, ALL PASS.**
T1 `run_regression` held at its 3 pre-existing FAILs (0420, 0421) throughout; T2
`headless/run.sh` 6/6 goldens every step.

### THE ONE THING THAT DID NOT LAND

**There is still no save-card generator.** S3 failed three times and S4 was deferred with it,
so nothing walks the hierarchy emitting `.save` cards into a deck. Every display path built
by this run is real and tested, but on an ordinary bench run the device rows render **blank**,
because the vectors are not in the raw. Putting real numbers on a schematic today still needs
a hand-written deck. Three preserved patches to restart from: `0436-attempt-1-reverted.patch`,
`0442-attempt-2-reverted.patch`, `0443-attempt-3-interrupted.patch`.

Two substantive refutations, both worth reading before attempt 4:
* **0436** — the save-card basis was raw-relative (`sim_sch_path`) where a card written into an
  unsimulated deck must be deck-absolute.
* **0442** — the netlist filter hand-mirrored 3 of the SPICE netlister's 7 instance-drop classes.
  A hand-maintained mirror of another module's rules is wrong by construction; read the
  netlister's output instead of replicating its logic.

Why it matters that these are not cosmetic: one `.save` card naming a device that is not in the
deck makes ngspice write **no raw file at all**, at rc=0, under the `.control`/`write` idiom every
shipped PDK bench uses. The generator would kill the simulation it was generated for.

### E QUESTIONS — ten; **two closed 2026-08-22** (0424 ratified, 0429 superseded)

> ⚠ **THIS TABLE IS NO LONGER THE QUEUE.** As of 2026-08-22 the open questions
> live in the owed ledger as `rule` debts — `tests/headless/owed.sh list rule`,
> or `owed.sh show` for the user's whole queue, rulings and looks together. They
> were moved because a person who owes both had to know which of two files each
> lived in, and because four of them cannot be decided without looking at pixels
> anyway (spec `doc/claude/specs/owed.md` §6). What stays here is the history:
> what each question was when it was asked, and what it turned out to be.
>
> **Migrating them found three mis-keyed numbers**, all in the items below:
>
> | item | said | actually |
> |---|---|---|
> | E6 + E7 | 0457 and 0458 | **both are 0457**, which states the resting value *and* the missing stock control. 0458 is "the installed cadence rc sources uninstalled utils" — a pre-existing **bug**, not a ruling |
> | 0468 | the overlay's compiled-in geometry | 0468 is "the Live-annotate checkbutton has no `-command`" — also a **bug**. The geometry ruling had no issue at all; it is now keyed to **0605**, where the discussion actually lives |
>
> Both bugs stay open as bugs. Neither was ever a question anyone owed an
> answer to, and both would have sat in a "waiting on the user" queue forever.
> The mis-keys were invisible while the questions were prose in a table and
> visible the moment each entry had to resolve to a file (spec R603).

Eight rulings still open:

1. ~~**0424** — may a crew run `./configure`?~~ **RATIFIED 2026-08-22: yes, when and only when the
   step edited `Makefile.in`.** Encoded as rule 2b in `crew_annotate.js` (Implement agent runs it,
   quotes the before/after `grep -c <newfile> src/Makefile` receipt) and as a bullet in `CLAUDE.md`.
   The tree was regenerated and rebuilt in the same sitting: 0 -> 2 install lines, staged
   `make install DESTDIR=` launches at EXIT=0 with `op_annot` present, and the negative control
   (helper hidden) still gives 139 — so the probe can fail. `test_op_annot` 241 ALL PASS,
   `run.sh` 6/6. Full receipts in issue 0424. **0423 stays open** — the segfault-instead-of-exit
   mechanism is untouched.
2. ~~**0429** — sky130's inherited save list carried `cgso`/`cgdo`.~~ **SUPERSEDED 2026-08-22 by
   ruling D9**, which is a bigger decision than the question asked. The MOS annotation default is now
   **`id gm gds vgs vth vds`** on every PDK — "too many parameters displayed is just clutter" — so
   `cgso`/`cgdo`/`cgg`/`vdsat`/`ft`/`gm/id` are simply not in the shipped set and there is nothing to
   ratify. `cgs`/`cgd` are not substituted for anything. Landed: spec §4.2a + invariant I8, all three
   PDK descriptor files, `test_op_annot` 241 -> **244 ALL PASS** with the D9 rows proved non-vacuous
   (10 reds under a pre-D9 sky130 descriptor, 3 more under a bogus IHP param). Two consequences worth
   reading: the six are **measured savable on ngspice-42 AND 46+, on sky130 AND gf180** — the
   ngspice-side check 0429 itself said was owed — and since `vgs`/`vds` are real BSIM4 params, **no
   shipped descriptor carries a `pinexpr` any more**, which takes 0444 and 0446 off the stock path
   without either C defect being fixed. Newly owed: **0603** (a first-class means for the user to pick
   her own set) and **0604** (report requested-but-undelivered vectors in the CIW and logfile).
3. **0444** — S5 added one space to `sky130_procs.tcl` and `gf180_procs.tcl`, outside its declared
   Files cell. Keep it, or revert and ship `vgs`/`vds` permanently blank on both PDKs?
4. **0446** — on sky130/gf180 a wrong `.raw` paints a fabricated `vgs = 0` / `vds = 0` on a FET.
   Accept, or hold the carrier until the C fix (`token.c:4364`/`:5441`) lands?
5. **0447** — is a `?` block an acceptable failure mode for a user's malformed descriptor?
6. **0457** — `annot_show` defaults to 0. Right resting state now that `Ctrl-6` exists to turn
   annotation off, or should it default to 1?
7. **0458** — should `annot_show` get a first-class stock control (a View-menu pair, or three
   registered C actions so the chords are remappable), or is the cadence profile its home?
8. **0475 / 0476** — 40 sky130 FET symbols are now annotation-silent for a user whose rc never
   sources `sky130_procs.tcl`, and for anyone reaching the symbol through a vendored or aliased
   library. Ship as implemented, add a built-in `sky130_fd_pr` fallback registration, or default
   `annot_show` to 1?
9. **0479** — a cursor parked outside the loaded sweep silently holds every annotated number at
   the last sample. Right, or should both paths gain a seam naming the condition?

Plus **0468** — should the overlay's anchor, size, layer, offsets and font be user-settable
rather than compiled-in constants whose only escape is per-instance `annot_dx`/`annot_dy`?

### LOOK DEBTS — cleared only by the user, never by a green suite

Also no longer a list here: `tests/headless/owed.sh list look`, and `owed.sh show`
for these and the rulings as the one queue they are. Recorded at the time:

* `annotate_params_on_tb_bandgap` — the carrier symbol's pixels (S6b).
* S8's keys: proven only by a bbox that grows and shrinks, which is a number, not a look at
  numbers on a schematic.
* A `:0` run of the six GUI rows, which have only ever run under Xvfb `:99` (WSLg delivers 3
  `<Configure>` events where Xvfb delivers 1).

### VERIFICATION GAPS THE CREWS DECLARED

* **S7** — Verify-B died mid-run; 9 of 11 sabotage variants are **unrun**, so S7's coverage
  proof is partial.
* **S12** — Verify-A non-delivery, Verify-B 0 of 8 variants executable, Verify-C refuted; the
  step's own deliverable (1) was unstarted and had to be redispatched as S12b.

### NEW ISSUES

**0420–0487, 68 filed.** Numbers 0418 and 0419, reserved by the plan for the two dead-token
issues, were consumed by earlier crews; those issues are 0484 and 0485 and say so.

### INFRASTRUCTURE

Four dispatches died to host process exits or API connection losses rather than to substance
(S3c after 11 agents and ~32 h, S6 and S10 in Scout, S9b after 5 agents). Two were recovered by
`resumeFromRunId`, two by a fresh relaunch. S3c left the tree modified and the driver restored it.
The GUI-gate pre-grant was blocked by the auto-mode classifier; crews used `GUI_GATE=0 xvfb-run`
throughout, and nothing needed the gate.
| S3d | F | none | not reached | none | crew aborted before write-up |
| S3d | F | 7ad53557 | test_op_annot 241->275 with the attempt, back to 241 ALL PASS after revert; tree clean | 0488-0499 (12) | Attempt 4 built and green at 275 checks, then reverted: two claims false in the field. Write-up agent died to a connection loss after filing and reverting but before committing; driver preserved the work. Patch: 0494-attempt-4-reverted.patch (2813 lines). Postmortem 0499 names why 275 green checks certified it anyway (three guardians cannot fail or are absent). 0498 is an independent C-core segfault found by sabotage. Issue ceiling 0499 reached; next is 0600. |
| X0498 | *(void)* | — | — | — | DRIVER ERROR, superseded by the row below. The driver read the commit off `git log` mid-run, assumed the crew had finished and its notification was lost, and wrote a status of `x` it had no authority to assign. The crew was still running and returned **E**. Kept visible rather than deleted: the run was 12.5h, not the ~8min the driver inferred from a transcript-directory mtime. |
| X0498 | E | 39ef9d74 | test_undo_link_symbols 6->54 ALL PASS; test_op_annot 241->241; headless/run.sh 6/6 goldens HARNESS PASS; run_regression 3 FAIL->3 FAIL (0491 floor); test_wave_hilight 139->139; undo_selection/descend_symbol/netlist_log/apply_hilight_log/buried_hilight unchanged | 0600,0601,0602 | Ratify or reject: a global `xschem netlist` run while `xschem set no_undo 1` is in force now pushes one undo slot instead of silently swapping the document — measured ~6x slower on disk undo (204ms vs 36ms) and ~2.4x on memory undo for a 75-instance cell; accept that cost, or must the netlister refuse to run when no_undo is set? |
