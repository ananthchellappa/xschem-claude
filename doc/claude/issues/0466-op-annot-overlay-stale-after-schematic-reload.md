# 0466 — the S9 draw-time overlay's per-instance cache cannot observe a schematic RELOAD, so it renders the PREVIOUS file's numbers

Status: **✅ FIXED BY S9b (2026-08-20), retry landed and committed.**
The reload defect below no longer reproduces; row **O21** (its literal repro) is
green, along with 14 further invalidation rows O22–O35 and O37 that the one-line
fix this issue proposed would NOT have covered. See **§ S9b — HOW IT WAS ACTUALLY
FIXED** at the end of this file, which also carries the decisions D1–D11, the full
sabotage matrix, and the residual risks that are still open.

Historical status (kept verbatim, it is the record of the revert):
**OPEN, measured, NOT fixed. This issue reverted step S9 (attempt 1).**
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

---

# § S9b — HOW IT WAS ACTUALLY FIXED (2026-08-20)

The retry took the src/ half of `0466-attempt-1-reverted.patch` **unchanged**
(`git apply --exclude='tests/*'`, rc=0 — the full patch collides with the
already-modified test file) and replaced its invalidation with an **enumerated
set of four hooks, a 14th epoch term, one hold, and a second seam**. The one-line
fix this issue proposed was **necessary but not sufficient**, and its anchor was
wrong; both corrections are below.

## BEFORE — the S9b Measure agent's transcript, verbatim

Binary `bd5381a3e9fd4c2835d23709bac0b7b8` (fresh; 0 sources newer), test file
`7e94007d90ad4405eb3fb3d5dab8cfbf`.

    OVERLAY-IN-SRC: src/psprint.c:0,src/svgdraw.c:0,src/draw.c:0
    annot_overlay_count in binary: 0
    B0 annot_overlay_count  -> {}
    B0 annot_overlay_flushes-> {}
    B1 after-load   instances=1 inst0.name=MZZA inst0.w=10u modified=0 currsch=0 schname=sheet.sch annot_show=0
    B1 after-reload instances=1 inst0.name=MZZB inst0.w=20u modified=0 currsch=0 schname=sheet.sch annot_show=0
    B4 annot_show=1 instances=1 name=MZZA
    B4 SVG bytes=4458 hits(MZZA)=1 hits(gm|vth|vdsat)=0
    B4 PS  bytes=4953 hits(MZZA)=1 hits(gm|vth|vdsat)=0
    B5 P2 before name=MZZA w=10u type=nmos instances=1 modified=0 currsch=0 file=sheet2.sch
    B5 P2 after  name=MZZB w=20u type=nmos instances=1 modified=0 currsch=0 file=sheet2.sch
    B5 P6 before name=MZZA w=10u type=nmos  instances=1 modified=0 currsch=0 file=sheet2.sch
    B5 P6 after  name=MZZA w=10u type=zzzzz instances=1 modified=0 currsch=0 file=sheet2.sch
    RESULT: 32 FAILED (176 passed)
    FAIL: O21 issue 0466: a device RENAMED on disk and reloaded renders its OWN number,
          not its predecessor's -> {0 {} {} {{ZZOA = 20u} {ZZOB = 200u} {ZZOC = 2u}}}
          (exp {0 {{ZZOA = 10u} ...} {{ZZOA = 20u} ...} {{ZZOA = 20u} ...}}) : FAIL
    FAIL: O13 `xschem get annot_overlay_count` counts one bump per block per export,
          and none at mask 0 -> {NO-SEAM:{} NO-SEAM:{}} (exp {2 0}) : FAIL

`B1` is the premise reproduced on the **unpatched** tree, so the defect statement
survives any rebuild: name **and** value both change across `xschem reload` while
`instances`, `modified`, `currsch`, `schname` and `annot_show` all stand still.
`B5 P6` is the finding this issue's proposed fix would have **missed** entirely.

## AFTER

    T3 test_op_annot HEADLESS                     RESULT: ALL PASS (209 checks)
    T3 test_op_annot DISPLAY (xvfb 1920x1080x24)  RESULT: ALL PASS (214 checks)
    T1 tclsh run_regression.tcl                   3 FAIL / 0 GOLD? / 0 RESULT? / 0 FATAL / 3 NOGOLD  (identical to baseline)
    T2 tests/headless/run.sh                      exit 0, == HARNESS: PASS ==, 6/6 goldens
    T4 cd src && make                             SUCCEEDED, zero warnings

Baseline was 32 FAILED (176 passed) = 208 checks; the RED agent added O37 during
the run, so 176 + 32 + 1 = 209. Nothing that was green went red.

## THE ANCHOR CORRECTION — this issue, the spec and the step brief were all wrong

`load_schematic()` is at **`src/save.c:4311`**, not `save.c:4319` as this issue,
spec §5 I3 and the S9b brief all state (`:4319` is mid-prologue). It has exactly
**two** exits — an early `return 0` at `save.c:4391` reached **after**
`xctx->sch[currsch]` has already been rewritten, and `return ret` at `:4509` — so
a call appended at the tail misses the early one.

## WHY THE ONE-LINE FIX WAS NOT ENOUGH — the enumeration, by input

`op_annot::text`'s complete external-state surface, and the mutator for each:

| input | source | mutators the 13-field epoch could not see |
|---|---|---|
| instance name, index→identity | `getprop cell::name` (`op_annot.tcl:311`) | any file re-read; every edit; a **readonly** buffer's edit (`ro_suppress` kills `modify_seq`, `actions.c:189`) |
| symbol `type=` | `getprop cell::type` (`op_annot.tcl:266`) | **`xschem reload_symbols`** = `remove_symbols(); link_symbols_to_instances(-1);` and *nothing else* — no `set_modify`, no `clear_drawing` |
| `@model` / `@spiceprefix` / template / pinexpr | `translate` | as above |
| `sim_sch_path` | `xschem get sim_sch_path` | descend / ascend / sibling descend |
| raw contents | `raw value -1`, `raw loaded`, `raw annot` | **in-place** mutation: `raw rename`, `raw set` (same pointer, same nvars, same level, same `annot_p`) |
| `::op_annot::desc` | `op_annot::register` | covered by `::op_annot::gen` (attempt 1) |
| **`live_cursor2_backannotate`** | `op_annot::_annotated`'s FIRST gate (`op_annot.tcl:561`) | a **shipped menu checkbutton** (`xschem.tcl:15360`); no C mirror, no epoch field. Strands real numbers on screen after the user turns annotation OFF — I3 in the other direction |

One path this issue named as a hole is **honestly already covered**:
`xschem setprop instance <n> name <new>` does call `set_modify(1)`
(`scheduler.c:12377`), so `modify_seq` bumps. Row O28 is a regression guard, not
a new hole.

## WHAT LANDED

    HOOK A  src/actions.c clear_drawing()  (:2321)
            the file-re-read choke point. Covers load, `xschem reload`,
            `load -keep_symbols`, descend, ascend, descend_symbol, disk undo
            (save.c pop_undo), in-memory undo/redo (in_memory_undo.c
            mem_restore_slot), `xschem clear`, font reload, tab/window teardown
            (xinit.c:962 — which also retires residual #3 below).
    HOOK B  src/actions.c set_modify()  (:255), INSIDE the existing
            `if(mod == 1 || mod == -2 || mod == -1)` floater-cache block.
            `return floaters` contract untouched.
    HOOK C  src/actions.c remove_symbols()  (:923)
            the only thing that covers `xschem reload_symbols`.
    HOOK D  src/save.c raw_add_vector (:1200) / raw_renamevar (:1331) /
            raw_deletevar (:1357), and the `xschem raw set` arm
            (src/scheduler.c:10490).
    TERM 14 live_cursor2_backannotate, via tclgetboolvar in annot_overlay_sync().
    SEAM 2  `xschem get annot_overlay_flushes` (scheduler.c:4148), a monotonic
            count of WHOLESALE flushes, incremented INSIDE annot_overlay_sync()
            at the moment of the flush.
    HOLD    annot_invalidate_hold(1)/(0) (actions.c:1323), depth-counted, ONE
            call site: netlist.c:1805-1807. See D11.
    HARDEN  `if(annot_overlay_busy) return;` at the top of annot_overlay_sync().

## DECISIONS (ladder rung + rejected alternative)

* **D1 (L2)** — `annot_overlay_flushes` counts **flushes**, inside
  `annot_overlay_sync()`, not inside `annot_data_changed()`. *Rejected: counting
  invalidation **requests*** — several hooks legitimately fire for one user
  action (a `reload` bumps via both `remove_symbols` and `clear_drawing`), so a
  request counter reds O32/O34's exact-1 goldens and makes every future hook a
  test edit.
* **D2 (L2, under L1/I3)** — the file-re-read hook goes in `clear_drawing()`.
  *Rejected: this issue's own one-liner in `load_schematic()`* — wrong anchor
  (`:4311` not `:4319`), an early exit at `:4391` after `sch[currsch]` is
  rewritten, and strictly less coverage (it misses `pop_undo`,
  `mem_restore_slot`, `xschem clear` and window/tab teardown).
* **D3 (L2)** — the edit hook goes **inside** `set_modify()`'s floater block,
  the codebase's own "my per-object rendered caches are stale" channel.
  *Rejected: relying on the epoch's `modify_seq` term alone* — it moves only for
  mod 1|3 and never when `ro_suppress` is set, so it misses `editprop.c:1263`'s
  `set_modify(-2); draw();` (which paints a full frame **before** its caller's
  `set_modify(1)` at `editprop.c:1289`) and every readonly-buffer path.
* **D4 (L2)** — the symbol hook goes in `remove_symbols()`. *Rejected: hooking
  the `reload_symbols` scheduler arm only* — would satisfy O31 and cover nothing
  else (misses `editprop.c:1124`'s copy_cell path and `callback.c:8130`).
  Accepted cost: `annot_overlay_flushes` also moves during netlisting, which is
  why every seam row wraps a **single** action and never a netlist.
* **D5 (L1 / I3)** — the four raw-content mutators each bump. *Rejected: bumping
  at the top of the whole `raw` dispatcher arm* — `xschem raw value` is called by
  `op_annot::text` itself, once per row per device, so that would self-invalidate
  every frame and silently become the flush-every-frame design D1 forbids.
* **D6 (L2)** — `live_cursor2_backannotate` becomes epoch term 14, one
  `tclgetboolvar` per frame. *Rejected: a Tcl `trace add variable` bumping
  `::op_annot::gen`* — it installs a trace on a **shipped** global that C also
  writes (`scheduler.c:2409`), affecting every writer, and a trace body that
  errors makes the variable **write** fail.
* **D7 (L2)** — **no** per-entry `strcmp(cached_name, inst[n].instname)` guard.
  *Rejected although it would make renames structurally safe*: it covers one of
  three input classes (name vs `model=` vs raw contents), buys false confidence,
  and would leave O21/O22 green under the `load_flush_off` sabotage variant —
  hiding a missing hook behind a partial guard. Row O23 exists to red such an
  implementation. ⚠ **See issue 0469** — the *name-vs-index* hazard is real and
  separate, and D7 is not a ruling against fixing that.
* **D8 (L2)** — one line of hardening, `if(annot_overlay_busy) return;`.
  *Rejected: a full re-entrancy redesign (a deferred-flush pending flag)* —
  larger than the step. Residual #2 is **narrowed, not closed**; 0464 stays open.
* **D9 (L2)** — keep the name `annot_data_changed()`. *Rejected: renaming to
  `annot_overlay_invalidate()`* — 0464/0466 and spec §5 cite the old name; the
  paper trail is worth more than the wording.
* **D10 (L3 — THE STEP'S E QUESTION, unratified, carried forward)** — anchor,
  size 0.2, layer 15, offsets +5/0, font Monospace ship **compiled-in**, with
  per-instance `annot_dx`/`annot_dy` as the only escape. *Rejected for now:
  making them preferences first* — a second feature, and the two carriers must
  keep matching side by side. **The question stands: should they be user-settable
  before this ships?**
* **D11 (L2) — NOT IN THE PLAN, found by measurement.** With the six planned
  hooks in, the suite went 33 FAILED → **2** FAILED: O32 `{2}` vs `{1}` and O34
  `{2 0}` vs `{1 0}`. A temporary field-by-field epoch dump named it exactly
  (`dseq=8/7`): `prepare_netlist_structs()`'s `set_modify(-2)` (`netlist.c:1798`),
  which `svg_draw()` and `create_ps()` both call **after** their instance loop, so
  a single load+export flushed twice and threw away the blocks the export had just
  built. Fix: a depth-counted `annot_invalidate_hold()` bracket around that one
  line. *Rejected: loosening O32/O34 to 2* — that would legitimise a wasted
  full-cache rebuild per load and blunt the seam against future over-invalidation.
  See issue **0473** for the half this did NOT fix (the floater caches) and for
  the drop-vs-defer contract.

## SABOTAGE MATRIX (8 planned + 1 added; each rebuilt, each run)

| variant | predicted | observed |
|---|---|---|
| `load_flush_off` (HOOK A → real no-op callee) | O22 O23 **O25** O32 O34 | **O22 O23 O32 O34** on both arms; O21/O24 green as required |
| `modify_flush_off` (HOOK B) | O33 | **exactly O33**; O26/O28 green (they ride `modify_seq`) |
| `symbols_flush_off` (HOOK C) | O31 | **exactly O31**; O21/O22/O23 green |
| `raw_mutator_flush_off` (HOOK D ×4) | O30 | **exactly O30**; O27/O37 green (`update_op` untouched) |
| `live_gate_epoch_off` (term 14 → constant 0) | O29 | **exactly O29**, and diagnostically: element 2 rendered stale `{ZZOA = 10u}` while element 4 (`op_annot::text`'s own answer) was correctly blank — the red names the **cache**, not the formatter |
| `cache_deleted` (epoch always mismatches) | O34 O35 | **O32 O33 O34 O35** headless + **O38** on display; every staleness row O21–O31/O36/O37 stayed green — which is exactly why the second seam had to exist |
| `ps_site_stub` | O3 | **exactly O3** |
| `draw_site_stub` — **the variant attempt 1 shipped past** | 0 headless, 4 on display | **exactly that.** Headless printed `ALL PASS (209 checks)` with the screen renderer deleted (re-demonstrating, not assuming, that `draw()`'s body is inside `if(has_x)`); display reds **O13 O14 O17 O38** |
| `cache_frozen` (**added by Verify-B**: `if(annot_epoch.valid) return;`, i.e. this issue's bug in its purest form) | broad | **31 rows red** — the complement of `cache_deleted`, proving the suite is sharp in both directions and that O25 is not vacuous |

### ⚠ THE ONE PREDICTED RED THAT DID NOT APPEAR

**O25 under `load_flush_off`** stays green. Verify-B did not leave that
unexplained: instrumented with the seam, `go_back` runs an intervening
`annot_overlay_sync()` that re-stamps the epoch at `instances=2 / currsch=0`, so
the second descent mismatches on those two ordinary terms. O25's coverage comes
from `instances`+`currsch`, **not** from HOOK A and **not** from the
`sim_sch_path` dependency its own comment claims. Not vacuous (`cache_frozen`
reds it), not a live correctness hole (every descend moves both terms), but a
**mislabelled guard** — filed as issue **0471**.

## PERFORMANCE, re-measured on the acceptance cell

`sky130_tests_ase/bandgap_opamp` (73 instances / 13 annotated devices), median of
3 runs of 20 timed redraws after 5 warm, under xvfb:

    mask 0            3.196 ms/frame
    mask 1 CACHED     3.652 ms/frame
    mask 0 again      3.266 ms/frame     (0.07 ms spread either side)
    mask 1, cache_deleted binary   4.807 ms/frame

The cache is worth **~1.16 ms/frame**, and mask-0 costs nothing. Steady state on
the screen back end: 13 blocks per frame with `annot_overlay_flushes` moving by
**0** across two consecutive redraws (against 1 on `cache_deleted`) — O38's
golden reproduced outside the suite.

## I4 ON SHIPPED DATA

`xschem get modified` = **0** on `bandgap_opamp` with `annot_show 1` and 13
blocks rendered, read **before** any save; `git diff -- sky130A` = **0 bytes**;
`git status --short -- sky130A` empty. Row O17 asserts the same inside the suite,
together with the honest result: **13 devices, all rows blank** — S3/S4 are
deferred, there is no save-card generator, so a real PDK raw carries no device
vectors and I3 requires blank.

## STILL OPEN (the S9b adversary's residual risks)

1. **Issue 0469 — a device is resolved by NAME, so an all-digit or duplicated
   instance name renders ANOTHER device's numbers.** The one adversary attack
   that succeeded. `get_annot_overlay(n, …)` holds the index and passes
   `inst[n].instname`; `get_instance()` (`scheduler.c:187`) reads an all-digit
   name as an index. Reachable via `xschem setprop instance MZZA name 1` with no
   warning, and via any `.sch` with duplicate names (`load` does not uniquify).
   **Not new to S9b** (the S6 carrier's `ref=` has it) but S9b widens it from
   "devices the user placed a carrier on" to "every registered device on every
   sheet". Survivable today only because `annot_show` defaults to 0 (0457).
   **Close it before the mask is ever defaulted on.**
2. **Issue 0470 — `xschem raw switch <file>` without a sim type** returns 1 yet
   leaves the outgoing raw's point published, so every consumer lags one switch.
   Row O37 uses only the working 3-argument form.
3. **The re-entrancy segfault is still live and its blast radius grew** (0464
   residual 2, 0447). A devproc that re-enters an export crashes xschem — proved
   **pre-existing** by the apples-to-apples control (an ordinary symbol whose own
   `T` record is `tcleval([reproc @ref])`, with `annot_show=0` and nothing
   registered, crashes identically). D8 narrows it. **Do not close 0464 on the
   strength of this step.**
4. **A descriptor mutated by writing `::op_annot::desc(<type>)` directly** does
   not bump `::op_annot::gen` — measured: `op_annot::text` answered `VQ = 10u`
   while the export still drew `VZ = 10u`. Unsupported path (0464 residual 1),
   but the array is namespace-visible.
5. **Issue 0474 — `annot_overlay_count` counts blocks the reader APPROVED, not
   blocks DRAWN.** The layer/zoom-cull returns all happen after the bump, so the
   screen back end's only seam cannot tell paint from approval.
6. **Issue 0473 — the `annot_invalidate_hold()` workaround DROPS rather than
   defers**, and `prepare_netlist_structs()` still resets every floater cache
   mid-export.
7. **Over-invalidation is the normal state and nothing measures it** — 13 flushes
   across 5 exports plus 4 navigations was observed, because `reload` bumps
   through both HOOK A and HOOK C and the netlisters bump per sub-sheet.
   Correctness-safe; the exact-1 goldens only pin single wrapped actions.
8. **Issue 0465 is still open** — `grep -c op_annot` is 0 in both
   `tests/run_regression.tcl` and `tests/headless/run.sh`, so T1 and T2 cannot
   see this feature in either direction. Combined with `draw()`'s body being
   inside `if(has_x)`, a screen-renderer regression is invisible to every runner
   unless someone remembers the xvfb leg by hand.
9. **0463** (outside `symbol_bbox()`, zoom-full clipping) unfixed and unfixable
   from the suite; **0454** (PS trailing RGB triple) still requires the
   `opa_l_normps` normaliser.
10. **D10's E question is unanswered**, and `annot_show` still defaults to 0
    (0457).

## PROCESS WARNING, RECORDED AGAIN

The measurement-environment warning above repeated itself. During S9b's Verify-A
pass another `claude` session ran a **repeated `make` loop** against the shared
`src/xschem` (four builds in ~10 minutes, pids 91417/91867/92597/93794), and
Verify-A's first T3 sample landed on a sabotage build: `RESULT: 1 FAILED (208
passed)` with the single red row **O31** — exactly the `symbols_flush_off`
prediction. It was disproved four ways (HOOK C present in source at
`actions.c:923`; `nm` shows zero sabotage symbols; all 11 sources byte-identical
to the pre-campaign snapshot; the re-run on the settled binary is ALL PASS 209).
**Verify-A and a sabotage-running Verify-B must not be scheduled concurrently
against one working tree.**
