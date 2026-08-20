# 0466 — the S9 draw-time overlay's per-instance cache cannot observe a schematic RELOAD, so it renders the PREVIOUS file's numbers

Status: **OPEN, measured, NOT fixed. This issue reverted step S9 (attempt 1).**
The full 1273-line attempt is preserved as
`doc/claude/issues/0466-attempt-1-reverted.patch` (applies to `523aa507`,
the `0264-` / `0436-attempt-1-reverted.patch` precedent) — **start from that
patch, do not retype it.** Everything except the invalidation hole was measured
correct: 192 headless / 195 display checks, nine sabotage variants, and an
adversary pass that could not break I1, I2, I4, I6, I7, the anchor, the case
folding, the cache flush or the acceptance.

Filed by the S9 write-up agent (op-annotation crew, branch `annotate`).
Found by the S9 adversary pass (Verify-C); **reproduced independently by the
write-up agent on the as-built binary before the revert was ordered.**

Related: spec §5 I3, spec §5 I5, RULING D5-1 in `save.c` (a plausible wrong
number on a schematic is worse than none), 0463 (the overlay is outside
`symbol_bbox()`), 0464 (the other epoch residuals), 0465 (the suite is invisible
to `run_regression.tcl`).

## The claim that was refuted

S9's central claim: *the overlay is cached per instance and invalidated on
annotation change.* The cache is an observed-state **epoch** (`actions.c:1264`
in the patch, `annot_overlay_sync()` at `:1301`) comparing thirteen fields —
`ctx`, `raw`, `instances`, `currsch`, `annot_show`, `raw_level`, `raw_nvars`,
`raw_annot_p`, `str_hash(sch[currsch])`, `modify_seq`, `data_seq`, `desc_gen`,
`valid` — plus two explicit `annot_data_changed()` bumps in `update_op()`
(`save.c:1999`) and `backannotate_at_cursor_b_pos()` (`callback.c:1536`).

**Not one of those thirteen moves when the schematic FILE is re-read from disk
at the same path with the same instance count.** `xschem reload`
(`scheduler.c:10813`, i.e. the FileReload toolbar button and `File > Reload`)
calls `load_schematic()` (`save.c:4319`) and then `set_modify(0)` — and
`set_modify` bumps `modify_seq` only for `mod == 1 || mod == 3`
(`actions.c:200`). The path is unchanged, so `schhash` is unchanged. The raw is
untouched, so all four raw terms are unchanged.

## Reproduced, on the as-built binary, by the write-up agent

    $ ./src/xschem --nogui --pipe -q --nolog --script scratch_S9C/atk_reload3.tcl
    R3: t0 RENDERED={ZZAA = 10u}
    R3: after reload         RENDERED={ZZAA = 10u}  TRUTH=ZZAA = 20u
    R3: after a bare redraw  RENDERED={ZZAA = 10u}  (still stale? persists across frames)
    R3: after a mask toggle  RENDERED={ZZAA = 20u}  <- user-invisible workaround

One sheet, one device, one raw carrying `i(@m.ma[zzid])` = 10u and
`i(@m.mb[zzid])` = 20u. The instance is renamed `MA` → `MB` on disk and the
schematic reloaded. `op_annot::text MB` — the single formatter, invariant I1 —
answers **20u**. The overlay paints **10u**, on every later frame and in every
later export, until an unrelated epoch move (a `6`/`Ctrl-6` mask toggle, an
edit, a new raw) happens to flush it. Scripts:
`scratch_S9C/atk_reload.tcl`, `atk_reload2.tcl`, `atk_reload3.tcl`.

## Why this is a revert and not a follow-up

1. It is **literally I3's forbidden case**: "not 0, not NaN on screen, *not the
   previous run's number*". The rendered figure is well-formed, plausible, in
   the right units, attached to the right symbol, and wrong.
2. It is **reachable in one click** from a shipped toolbar button, in the
   ordinary workflow this feature exists for: annotate, let a script / another
   tab / an external tool rewrite the `.sch`, press Reload.
3. It is **silent**: no message, no missing row, nothing a user could notice.
4. It has **zero coverage**, in a suite whose whole point is that class:
   `grep -n reload tests/headless/test_op_annot.tcl` finds four hits and not one
   of them re-loads a schematic (they are N5's raw-reload guard and comments).
5. The pre-S9 carrier (S6) had **no cache** and therefore no such state — the
   overlay's cache is what introduces the failure mode, so shipping it makes a
   correct thing wrong.

## The fix shape for the retry (not applied)

One line, in the same shape as the two bumps that already exist:

    save.c load_schematic() (:4319)  ->  annot_data_changed();

`load_schematic()` is the single choke point for `xschem load`, `xschem reload`,
the toolbar/menu reload and the `Alt-S` inline reload, so one call covers all of
them; descend/ascend also route through it and would simply flush once more than
`currsch` already forces, which is free (the cache refills lazily, visible
instances only).

**And the row that must go in with it**, because the suite could not see this:
load the SAME path twice with different content and the same instance count,
between two exports, and assert the rendered number changed. A row that loads a
*different* path proves nothing — `schhash` moves and the epoch flushes.

Cheaper alternative considered and **rejected**: flush unconditionally every
frame. It is correct and it removes the entire epoch, but it is exactly the cost
the step's risk cell exists to avoid (measured uncached: +1.77 / +3.05 / +3.33
ms per frame on bandgap_opamp / test_comparator / top, i.e. +20–35 % with the
gate closed and +66–100 % with a raw loaded).

## The rest of the S9 receipt — what was measured, so the retry keeps it

### BEFORE (Measure agent, verbatim — the capability absent three ways)

    $ grep -n 'op_annot\|annot_dx\|annot_dy' src/draw.c src/svgdraw.c src/psprint.c   ->   rc=1 (no hits)
    S9-REPRO: 73 instances, 13 with a non-blank op_annot devpath
    S9-REPRO: svg bytes 0/1/3 = 72460 72460 72460
    S9-REPRO: svg identical across the mask (overlay ABSENT) = 1
    S9-REPRO: any 'vdsat' or 'gm/id' row in the export = 0
    S9-REPRO: ps identical across the mask, colour-normalised per issue 0454 = 1
    S9-REPRO: modified = 0
    S9-KEYS: press 6  -> annot_show=1  svg=72460 bytes  modified=0  vdsat-row=0
    S9-CELL: bandgap -> 115 instances, 0 with a non-blank op_annot devpath

Tier baseline of record for the branch: T1 70 lines / **3 FAIL** / 0 GOLD? /
0 RESULT? / 0 FATAL / 3 NOGOLD (both FAIL identities pre-existing — 0455's stale
9-library expectation and 0456's `OVERALL: ok` sentinel format); T2 harness
PASS 6/6; `test_op_annot` **172** ALL PASS.

### AFTER (the implementation that is now only in the patch)

    S9-REPRO: svg bytes 0/1/3 = 72460 91067 91067      (mask 0 byte-identical to the pre-S9 export)
    S9-REPRO: svg identical across the mask = 0
    S9-REPRO: any 'vdsat' or 'gm/id' row in the export = 1
    S9-REPRO: ps identical across the mask, colour-normalised = 0
    S9-REPRO: modified = 0
    acceptance, through the S8 keys on :99, `cadence::annot_mode op` / `none` then `xschem save`:
      bandgap_opamp   inst 73  blocks(6) 39  blocks(Ctrl-6) 0  svg 90979/72372  modified 0  FILE-UNCHANGED 1
      test_comparator inst 168 blocks(6) 78  blocks(Ctrl-6) 0  svg 151713/121605 modified 0 FILE-UNCHANGED 1
      top             inst 123 blocks(6) 129 blocks(Ctrl-6) 0  svg 120027/99881  modified 0 FILE-UNCHANGED 1
      git diff -- sky130A/xschem_libs/sky130_tests_ase/  after all four saves = 0 BYTES

Tiers with the implementation in: T1 **unchanged** (70/3/0/0/0/3, same two
identities); T2 PASS 6/6; `test_op_annot` 172 → **192** headless / **195** on
`:99` ALL PASS; `test_pin_name_size_win` 9/9, `test_migrate_pin_names`,
`test_drag_keeps_selection`, and on `:99` `test_nh_export_custom_color`,
`test_nh_angle_render`, `test_hover_selection_repair`, `test_create_instance`
all unmoved.

Performance, same method before and after (`DISPLAY=:99`, no `--nogui`, 5 warm +
20 timed `xschem redraw`, median of 3 runs, ms/frame) — the step's named risk:

| cell | inst/dev | BEFORE | mask 0 | mask 1 cached | first frame after a flush |
|---|---|---|---|---|---|
| bandgap_opamp | 73/13 | 3.19 | 3.11 | 3.49 | 4.96 |
| test_comparator | 168/26 | 4.59 | 4.68 | 4.58 | 7.64 |
| top | 123/43 | 6.61 | 6.71 | 6.89 | 9.94 |

Pixel evidence (kept, and it is the honest result rather than a flattering one):
`doc/claude/evidence/s9_overlay_bandgap_opamp_on.png` / `_off.png`. Every FET
carries its ten-row monospace block **and every row is blank**, because no
save-card generator exists (S3/S4 deferred, 0436/0442/0443) so the raw carries no
device vectors — invariant I3 behaving correctly.

### Decisions, with the ladder rung and the rejected alternative

| # | Rung | Decision | Rejected |
|---|---|---|---|
| D1 | L1 / spec §4.2–4.3 | The render gate is a **non-blank `op_annot::text` block**, never "the symbol type has a registered descriptor" as the step brief said | The descriptor gate — measured, `devices/nmos.sym` answers descriptor?=1 / devpath {} under a sky130-only registration, so it paints blocks on 13 generic symbols and reds rows L19/L20/L21/L22 on the first run |
| D2 | L1 / I7 | The mask gate is `text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)`, called **once** in a shared reader | Three inline `annot_show & ANNOT_SHOW_OP` tests (re-creates the ten-copy defect S7 removed) or a fourth predicate beside `text_hidden` |
| D3 | L2 | The call site is each back end's **instance loop**, not `draw_symbol()`/`svg_draw_symbol()`/`ps_draw_symbol()` | The P6 pin-pass position — on screen it sits under `((c==cadlayers-1) && symptr->texts)` (draw.c:10500) while the two exports have no such guard, so a texts-free registered symbol renders in SVG/PS and **not** on screen; and `hilight.c:4192` calls that pass a second time for every highlighted instance |
| D4 | L1 / I3 | Observed-state epoch **plus** an explicit `annot_data_changed()` in `update_op()` and `backannotate_at_cursor_b_pos()` | An epoch built only from xctx fields — re-running the same deck reuses the Raw with identical nvars/level, so the overlay would show the previous run's numbers. **This decision was right and still insufficient: see the top of this issue — the same argument applies to `load_schematic()` and nobody made it.** |
| D5 | L1 / I5 | `::op_annot::gen` in `op_annot.tcl`, bumped by `register`, folded into the epoch — two lines outside the step's literal Files cell | Dropping I5 (a user's rc override would need a restart); hashing op_annot's private descriptor store from C (a second reader of it) |
| D6 | L2 | A new `xschem get annot_overlay_count` seam | Leaving the screen path to the eyeball — `draw()`'s body is inside `if(has_x)`, so without the seam the screen call site has **no possible red** (proved: variant v9 below) |
| D7 | L2 | Upright (rot 0 / flip 0), anchored at the text-free bbox corner `inst.xx2 / inst.yy1` + relative `annot_dx`/`annot_dy` (defaults +5 / 0), size 0.2, layer 15, font Monospace — all three constants lifted verbatim from the shipped carrier `annotate_params.sym` | Rotating with the instance (a 90° FET prints a vertical wall of rows); absolute dx/dy (breaks the moment the instance moves); inventing fresh constants (carrier 1 and carrier 2 would not match side by side) |
| D8 | L2 | The overlay is **not** folded into `symbol_bbox()` | Folding it in — it would fix zoom-full and the auto-viewport export and give a headless `instance_bbox` oracle, but `symbol_bbox()` is reached from netlist/save paths (save.c:4301) and run over every instance by `update_all_sym_bboxes`, so a per-instance Tcl call there is a re-entrancy hazard against `translate()`'s single static result buffer and a cost on paths that never draw. Consequence filed as **0463** |
| D9 | L2 | The block also obeys `sym_txt`, `hide_texts=true` and `hide=true`, decided once in the shared reader | Gating on the mask alone — a user who switched symbol text off would still get a block of numbers, and the screen/export answer would depend on which back end checked what |
| D10 | **L3** | Ship the overlay with compiled-in anchor/size/layer, `annot_dx`/`annot_dy` the only escape | Making them preferences first. User-visible and unratified; this is the step's E question and it survives the revert — see "still open" |

### Sabotage matrix (8 planned + 1 added by Verify-B; predicted → observed)

| # | Variant | Predicted | Observed |
|---|---|---|---|
| v1 | `get_annot_overlay()` → return 0 | 12 | 17 on `:99` / 16 headless — all 12, + O5 O15 O16 O20 (+ O14 on `:99`) |
| v2 | mask gate bypassed | 6 | 10 / 9 — all 6, + O3 O5 and the two **shipped-carrier** rows L24 L25 |
| v3 | gate on the descriptor, not the text block (the brief's own wrong gate) | 7 | 17 in both — all 7, + 10 more. D1 is exactly what the 57-symbol corpus rows catch |
| v4 | cache never invalidated | 4 | 17 / 16 — all 4, + 13. ⚠ **the plan's stated tell was WRONG**: it said the mask rows must stay green; O1 O10 O13 also went red, because a never-flushed cache is never resized across `xschem load` |
| v5 | `annot_dx`/`annot_dy` swapped | 2 | **exactly 2** (O6 O7), no collateral |
| v6 | SVG site stubbed | 12 | 15 — all 12, + O5 O16 O20; O3 (PS) and O14 (screen) correctly stayed green |
| v7 | PS site stubbed | 1 | **exactly 1** (O3) — the site nobody looks at has exactly one guard and it works |
| v8 | `set_modify(1)` added inside `get_annot_overlay()` (an I4 breach) | 1 (O4) | 2 headless (O4 O17) but **2 DIFFERENT on `:99` (N16 O17) — O4, the row that names itself the I4 row, is GREEN under a live I4 breach on a display** |
| v9 | draw.c site stubbed (**added by Verify-B; the plan had no such variant**) | — | **0 red headless** — `RESULT: ALL PASS (192 checks)` with the screen renderer deleted. 3 red on `:99` (O13 O17 O14) |

### Predicted reds that did NOT appear — and they are test defects, not luck

* **v8 / O4 is structurally vacuous in both environments.** Instrumented: under
  the breach `xschem get modified` is **1** immediately before O4's own trailing
  `catch {xschem save}` and **0** immediately after — the row reads the
  *post-save* value, so that element is 0 whether or not I4 was breached. O4's
  headless red came only from its file-bytes element.
* **and that element is order-dependent, not a modify detector.** On `:99`
  `xschem load` itself redraws, so the fixture is already normalised by O4's
  *first* save and the trailing save writes identical bytes; headless the first
  save is a no-op and only the trailing one moves the bytes. O4 detects "the
  fixture was not yet normalised". **Fix for the retry: read `modified` BEFORE
  the trailing save and keep the byte compare after it.** On a display, I4 was
  caught only by N16 and O17.
* **v9: a headless-only run cannot see the draw.c call site at all.** The retry's
  suite must run on a display in CI, not just headless — which collides with
  **0465** (the suite is in no runner).

## Still open (the adversary's residual risks, carried forward)

1. **The refutation itself**, above. Any future path that changes the schematic's
   content or the hierarchy prefix without moving `currsch`, the path hash or
   `modify_seq` goes stale the same way. The epoch hashes `sch[currsch]` (the
   FILE) and not `sch_path[currsch]` (the INSTANCE path); correct per-branch
   values in a hierarchy rely on `currsch` alternating through `go_back`.
   `sim_sch_path` is deliberately read live in Tcl (`op_annot::_simpath`) to
   avoid exactly this, and the C cache reintroduces it one level up.
2. **S9 widens a pre-existing re-entrancy hazard** from "symbols the user placed a
   carrier on" to "every registered device on every sheet". A devproc that
   re-enters xschem (nested export/redraw) segfaults — confirmed `signal 11` —
   because the nested `annot_overlay_sync()` frees the cache while the outer
   `annot_overlay_cached_text()` is mid-`tcleval`. **Verified pre-existing**: the
   identical devproc crashes the same way through the S6 carrier alone with the
   overlay never running. The `catch` in the fixed script covers Tcl *errors*,
   not Tcl *re-entry*; the busy flag guards `get_annot_overlay()` but not
   `annot_overlay_sync()`, which is what does the freeing. Issue 0447 (register
   validates only `dict size`) makes a malformed user rc a live input to it.
3. `annot_epoch.ctx` is a **dangling pointer compared by value** — a closed tab
   and a new one at the same malloc address with the same instance count,
   `currsch` and path would match and reuse the previous context's cache. The
   arrays are also never freed at teardown (0464).
4. `annot_show` is inside the epoch, so every `6`/`Ctrl-6` press throws the whole
   cache away and the next frame pays a full uncached sweep. Accepted, but the
   "steady state within noise" number is not what a user toggling the mask feels.
5. **0463** (zoom-full / auto-viewport clipping) is unfixed and *unfixable to see*
   from the suite: every S9 row uses the 10-argument explicit-viewport print form.
6. PS comparisons must normalise issue **0454**'s uninitialised trailing RGB
   triple, which changes with the mask even with no overlay present — in the
   other direction, a real PS regression can hide inside that noise.
7. The step's **E question** is unanswered and survives the revert: should the
   overlay's anchor / size / layer be user-settable — a preference or an rc
   variable — before this ships, rather than compiled-in constants whose only
   escape is per-instance `annot_dx`/`annot_dy`?

## Measurement-environment warning for whoever retries

Two agents in this run rebuilt `src/xschem` while others measured (Verify-B was
injecting sabotage variants on a ~40 s cycle). Several readings taken in that
window were garbage — one full-suite run reported 9 FAILED against a sabotaged
binary, and the same script answered 0, 13 and 73 blocks on consecutive runs.
Every number in this issue was taken under a byte-level guard (md5 of the sources,
the binary and the test file before and after, plus a `SABOTAGE` grep) or against
a validated snapshot binary. **Do not trust an S9 number without re-validating
the binary that produced it.**
