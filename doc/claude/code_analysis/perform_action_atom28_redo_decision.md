# The zero-delta consistency migration behind Refactor B atom 28 (`redo`)

*Prepared 2026-07-18 on branch `fluid-editing`. Companion to
`perform_action_atom26_check_unique_names_asymmetric_split_decision.md` (atom 26),
`perform_action_atom27_clear_drawing_decision.md` (atom 27) and the running audit
`action_log_coverage_audit_and_core_selflog_refactor.md`. `redo` is Refactor B batch item 03
(`doc/claude/refactor_b_batch/PLAN.md`): the atom-12 friction scout named it one of the three original
friction-free verbs but skipped it ("no coverage win"); the batch plan re-admits it as a deliberate
consistency/uniformity atom. This document is the stage-A fresh-scout record: every anchor re-verified
from source, both plan defer-triggers tested and found UNCONFIRMED, and the one design decision — the
tolerant-argc shape — resolved.*

---

## 1. The verb, from source (re-verified 2026-07-18)

The scheduler branch (`scheduler.c:8861`, inside `xschem_cmds_r` at 8276 — the plan's `8800` had
drifted):

```c
/* redo
 *   Redo last undone action */
else if(!strcmp(argv[1], "redo"))
{
  if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}   /* 8863 */
  if(scheduler_readonly_reject(interp, "redo")) return TCL_ERROR;               /* 8864 */
  pop_undo_keep_selection(1, 1); /* issue 0007: keep selection across redo */   /* 8865 */
  log_action("xschem redo"); /* self-log at core */                             /* 8866 */
  Tcl_ResetResult(interp);                                                      /* 8867 */
}
```

**Already boundary-shaped**, exactly as the plan claims: `!xctx` guard, an inline per-verb
`scheduler_readonly_reject`, one effect call, one unconditional fixed-literal log, reset-on-success.
There is **no argc handling of any kind** — `xschem redo extra` executes the redo and logs the bare
line today (contrast delete/clear_drawing, whose old branches were `if(argc==2)` silent no-ops).

**The core.** `pop_undo_keep_selection(int redo, int set_modify)` (`select.c:2360`, decl
`xschem.h:2120`) — the issue-0095 selection-preserving wrapper around the `xctx->pop_undo` function
pointer (disk `pop_undo` save.c:4134 / memory `mem_pop_undo` in_memory_undo.c:596, chosen in
xinit.c:617/624 and by the `undo_type` branch scheduler.c:11336/11346). Undo/redo ownership:

- **No `push_undo` exists anywhere on this path and NONE is added** — a redo is undo-STACK
  NAVIGATION, not a new edit; pushing would clobber the redo tail (see §6's detector).
- **`set_modify` is owned by the core**: the branch passes `set_modify=1` down into
  `xctx->pop_undo(redo, set_modify)` (select.c:2395). `run_core`'s arm adds nothing.
- **Empty-redo-stack is a no-op SUCCESS**: disk `pop_undo(1, ...)` early-returns when
  `cur_undo_ptr >= head_undo_ptr` (save.c:4147–4154). The branch logs the bare line anyway today
  (unconditional log after the call) — so under log-on-success the no-op-still-logs property (§30) is
  not merely preserved, it is **byte-identical to shipped behaviour**.
- **No early `TCL_ERROR` validation** beyond `!xctx`/readonly — nothing for log-on-success to
  newly gate.

## 2. The shape: a bare-verb delegation with NO arity gate (the one design decision)

The migration is the toggle_ignore (§32) / floaters (§30) bare-verb mold, **not** the
delete (§44) / clear_drawing (§47) mold, on one axis: **no `argc` gate is added.**

- delete/clear_drawing added `argc==2` gates because their OLD branches were `if(argc==2)`
  **silent no-ops** on extra args — a TCL_OK-no-op that log-on-success would PHANTOM-log. The gate
  was required by the contract.
- redo's old branch **executes and logs on ANY argc**. There is no phantom-log hazard: an extra-arg
  call is a real (tolerated) execution today and remains one under the boundary. Adding a gate would
  be a gratuitous behaviour change inside a zero-delta consistency atom — precisely what atom 28 must
  not do. The toggle_ignore branch (scheduler.c:11193 `return perform_action("toggle_ignore", argc,
  argv);`) is the shipped precedent: tolerant argc, delegation at any shape.

**The log form stays byte-identical bare at every argc** — the plan's hard requirement — for free:
`core_log_action` grows **NO per-verb arm**; the DEFAULT arm (`log_action("xschem %s", verb)`,
scheduler.c:1417–1419) ignores `argc/argv` entirely, so `xschem redo`, `xschem redo extra`, and the
key/menu/toolbar compound all record the identical bare `xschem redo` line the old branch emitted.
Only the two header rosters (run_core ~191, core_log_action ~1070) gain the name.

Resulting arms:

- **`run_core`**: `pop_undo_keep_selection(1, 1); return TCL_OK;` — no push_undo, no draw, no
  set_modify (all core-owned or core-passed), no argc gate. `(void)argc; (void)argv;` already sits at
  run_core's top.
- **Branch**: collapses to `return perform_action("redo", argc, argv);` — dropping the inline
  `!xctx` guard, the per-verb `scheduler_readonly_reject(interp, "redo")` and the inline
  `log_action("xschem redo")` (the boundary owns all three; the `not_avail` message and the
  readonly message are the SAME strings the boundary emits, so both error paths are byte-identical).

## 3. The entry-point map (RESOLVED from source): every path already funnels through the branch

This is the load-bearing difference from atoms 24–26: **there is NO raw second entry point.** No
callback.c edit, no key decision, no F-2ndentry.

- **Legacy `case 'U'` is GONE.** callback.c:5901–5903 is now only a comment: *"case 'U' (redo) fully
  migrated to the binding table (Phase 3d.2 sem-gated batch 1)"*. `grep "case 'U'"` confirms no code.
- **The Shift+U key** is `keybindings.csv:51` (`key,85,0,canvas,edit.redo,1` — keysym 85='U', mods 0
  because printable keysyms strip ShiftMask into `rstate`, callback.c:4884 `kmods = (key < 0xff00) ?
  rstate : state`; idle-gated). It resolves to the Tcl-backed ActionDef `{ "edit.redo", NULL,
  "xschem redo; xschem redraw", "Redo", 1 /*mutates*/ }` (callback.c:3727) via
  `dispatch_input_action` (callback.c:4124), which `Tcl_GlobalEval`s the compound (4156) → the
  scheduler branch → the boundary.
- **Layer A dedup already correct, and unchanged.** dispatch zeroes `actionlog_cmd_logged` (4155),
  evals the compound; the branch's log (today `log_action` at 8866; post-migration
  `core_log_action`→`log_action`) sets the flag (util.c:503); dispatch's
  `if(!d->nolog && !actionlog_cmd_logged) log_action("%s", d->tcl)` (4162) is therefore skipped —
  the key records exactly ONE bare `xschem redo` line, never the compound, before AND after.
- **Read-only key path unchanged**: `mutates=1` on the ActionDef means dispatch blocks the key at
  4136 (`action_id_mutates && readonly_block()`) BEFORE evaluating any Tcl — no eval, no log, no
  phantom (the §32 mutates=1 rule). `readonly_block` (callback.c:35) is headless-safe (dbg line, no
  dialog when `!has_x`).
- **Menu + toolbar** (`xschem.tcl:14210` Edit>Redo, `12712` toolbar EditRedo) run the same plain
  compound `-command "xschem redo; xschem redraw"` (the `-accelerator {Shift+U}` is display-only) →
  the branch. **actions.csv:74** is the same id's palette/metadata row (idle=1, nolog empty).
- **Scripted/tests** call bare `xschem redo` (tests/headless/test_undo_*, stable_handles bodies,
  `undo_link_child/drive.tcl` — that directory is scratch built by
  tests/headless/test_undo_link_symbols.tcl:45 next to the action log and is not committed;
  the cited copy is preserved at `doc/claude/evidence/0148_undo_link_child/`, see issue 0352)
  → the branch.

**The compound wrinkle, verified.** The plan asks: does the boundary's success-only
`Tcl_ResetResult` change what `xschem redo; xschem redraw` observes? No — the OLD branch already did
`Tcl_ResetResult` on its success path (8867), Tcl's `;` discards the intermediate result anyway, and
on the readonly `TCL_ERROR` path both old and new return the identical
`scheduler_readonly_reject(interp, "redo")` message before `xschem redraw` runs (the compound aborts
identically). Byte-identical in all three observable dimensions (result, error message, log line).

**Result-consumer sweep (defer trigger 2): NONE.** Zero `[xschem redo]` command-substitution matches
repo-wide (src + tests). Every caller discards the result. The one subtle near-miss:
`test_selflog_output.tcl:61–63` runs `xschem redo` then reads `xschem log_action -emitted` — that
consumes the `actionlog_cmd_logged` FLAG, not the interp result, and `core_log_action`'s
`log_action` sets the same flag → the check keeps passing. **Trigger UNCONFIRMED.**

**Sprint-policy sweep (defer trigger 1): NO such policy exists.** PLAN.md's "Rules of the batch"
contains no zero-coverage exclusion; the ledger itself carries item 03 with a rationale endorsing it
("worth doing early to unify the log onto core_log_action even though coverage gain is zero"), and
§32's key-routing half was accepted on exactly this consistency basis. **Trigger UNCONFIRMED.**

## 4. The F-shared story: `pop_undo_keep_selection` and the raw undo branch

`pop_undo_keep_selection` has exactly TWO call sites (grep-verified): the redo branch (8865 → moves
into run_core) and the **undo branch** (`scheduler.c:11303–11320`, in `xschem_cmds_u`), which parses
optional `redo`/`set_modify` ints from argv — so **`xschem undo 1 1` performs a redo through the RAW
undo branch** and logs its own normalized `xschem undo 1 1` line (11318). That branch **stays raw**
(it is batch item 05's scope, with its own normalizing-log wrinkle) and there is **no double-log
path**: distinct verbs, distinct log lines, distinct branches; neither ever evaluates the other. The
guard rows must SAY so (the plan's requirement): pin scheduler.c at EXACTLY ONE
`pop_undo_keep_selection(1, 1)` (the run_core redo arm — the count is 1 before and after, the call
just moves) and EXACTLY ONE `pop_undo_keep_selection(redo, set_modify)` (the raw undo branch), so a
future "helpfully route undo's redo-form through the redo verb" edit — which WOULD create a
double-log — fails closed.

The netlist backends' `xctx->pop_undo(2|4, 0)` calls (spice/spectre/verilog/vhdl/tedax_netlist.c)
are C-level save/restore machinery on the raw function pointer, below even the wrapper — out of
scope, unaffected.

## 5. Friction (fr 1) and the win

**fr 1 = F-shared (+1)** only, confirming the plan's score:

- NO F-validate (no gate exists; none added — §2).
- NO F-2ndentry (no raw key; the legacy switch case is gone — §3).
- NO F-flagarg (bare fixed log via the default `%s` arm at any argc).
- NO F-condlog, NO F-split (all-mutate, no query form: highlighting nothing, returning nothing),
  NO F-gate.

**The win is uniformity, not coverage** — the first strictly ZERO-DELTA migration (delete and
clear_drawing each tightened arity; toggle_ignore added gate+log; redo changes NOTHING observable):
the readonly gate and the log CONSOLIDATE onto the boundary's one gate + one log site, the verb
joins the run_core/core_log_action registry, and the S7 exclusivity block turns "no scattered redo
gate/log may reappear" into a fail-closed structural invariant (audit §3.1's per-path-checklist
regression, abolished for one more verb).

## 6. Test plan (to author at implementation — `test_perform_action_redo.tcl`)

House style = test_perform_action_delete.tcl. Fixture: fresh sheet; `xschem instance
devices/res.sym 0 0 0 0 {name=R1 value=1k}` (the placement pushes undo), `xschem undo` (instances
1→0) — now a redo slot exists. Oracle: `xschem get instances`.

- **(a) SUCCESS**: `xschem redo` → instances 0→1, rc TCL_OK, exactly **+1 byte-exact bare**
  `xschem redo`, interp result blank.
- **(b) TOLERANT EXTRA-ARG + BARE LOG FORM** (the plan's byte-identical lock): re-arm (undo);
  `xschem redo extra` → STILL executes (0→1), rc TCL_OK, **+1 exact-bare** `xschem redo`, **+0**
  `xschem redo extra` lines. Pins BOTH the no-arity-gate decision and the default-`%s` log shape.
- **(c) READONLY CONSOLIDATION**: read-only cell → TCL_ERROR, NON-EMPTY message matching
  `*redo*read-only*` (the §33 landmine: the success-only reset must not wipe it), no mutation,
  **+0** log. Not a new gate — the check pins that consolidation did not regress the old inline one.
- **(d) REPLAY**: the recorded `xschem redo` re-executes through the `replay_action_log` suppress
  seam (re-applies against the ambient stack) WITHOUT re-logging; a control unwrapped `source`
  DOES re-log.
- **(e) NO-OP-STILL-LOGS**: with an EMPTY redo stack (nothing undone), `xschem redo` mutates
  nothing (pop_undo early-returns), rc TCL_OK, **+1** line — byte-identical to today's
  unconditional log.
- **(f) STACK NEUTRALITY (the no-spurious-push detector)**: after (a), `xschem undo` → 0, `xschem
  redo` → 1 again (round-trip stable). A spurious `push_undo` in the arm would fire at
  `cur < head`, and push_undo snaps `head = ++cur` (save.c:4115–4116) — TRUNCATING the redo tail —
  so the following `pop_undo(1,..)` finds `cur >= head` and restores NOTHING: instances would stay
  0 and (a)/(f) fail.
- **(g) SIBLING RAW (the F-shared lock)**: `xschem undo 1 1` still redoes via the RAW undo branch,
  logging **+1** `xschem undo 1 1` and **+0** `xschem redo`.
- **(h) KEY FUNNEL + LAYER-A DEDUP**: arm a redo slot; inject
  `xschem callback .drw 2 400 300 85 0 0 0` (keysym 85='U', state 0 → `kmods` 0 matches the
  binding row; the real handle_key_press→dispatch chain, the gesture-test-full-sequence approved
  headless form) → redo applied, **+1 exact-bare** `xschem redo`, **+0**
  `xschem redo; xschem redraw` compound lines (the dedup proof). Read-only + same injection →
  blocked at dispatch (`mutates=1` → readonly_block, headless-safe), no mutation, **+0** log.

**Sabotages** (each targets EXACTLY ONE check-group; rebuild, confirm the targeted fail, `git diff`
the file, targeted `git checkout --` revert, clean green re-run):

- **(A)** bypass the boundary at the branch (restore the raw inline gate+pop+log+reset body) → the
  runtime `.tcl` may STILL pass (the §32 sabotage-2 lesson) while the S1 delegation row + S7
  zero-scatter rows fail closed — the grep guard is the load-bearing exclusivity lock.
- **(B)** spurious `xctx->push_undo()` in the run_core arm before the pop → (a)/(f) fail
  (instances stays 0 — the truncated-redo-tail detector of §6-f).
- **(C)** add a per-verb raw-argv log arm (`log_action_argv` passthrough of argc/argv) → (b) fails
  (`xschem redo extra` logged non-bare; exact-bare count +0).
- **(D)** gate the log on did-something (run_core returns TCL_ERROR when
  `xctx->cur_undo_ptr >= xctx->head_undo_ptr`) → (e) fails (+0 log, rc error) — the
  no-op-still-logs discriminator.

## 7. The grep guard plan (`test_selflog_grep_guard.tcl`)

- **S1 :334** — REPLACE `{log_action\("xschem redo"} 1 {redo branch}` with the delegation row
  `{return perform_action\("redo", argc, argv\);} 1 {...atom 28 prose...}`. (S1 rows are `>=`
  floors; the fail-closed lock is S7.)
- **S7 exact-count block** (atom-28): scheduler.c `== 0` `log_action\("xschem redo"` (the bare form
  lives ONLY in the default `%s` arm — no literal may reappear), `== 0`
  `scheduler_readonly_reject\(interp, "redo"\)`, `== 1` `pop_undo_keep_selection\(1, 1\)` (the
  run_core arm — and NOT a second routed copy in the undo branch), `== 1`
  `pop_undo_keep_selection\(redo, set_modify\)` (the raw undo branch stays raw — batch item 05's
  scope, the §4 F-shared lock); callback.c `== 0` `log_action\("xschem redo"` (no key ever
  self-logs it — the U key is Tcl-funneled).
- **S2 CVERBS**: `redo` is ALREADY listed (:608) — no change. Stays OUT of S3.
- **S5 runtime canary** (:735 `foreach verb {undo redo copy trim_wires}`) — untouched; it keeps
  proving exactly-+1 end-to-end at runtime through the migrated boundary.
- The undo branch's S1 row `{log_action\("xschem undo"}` (:333) is untouched (its regex requires
  the closing quote directly after `undo`, so it pins 11317, not the `%d %d` form).

## 8. Lessons (for the batch record)

1. **The arity gate is a contract consequence, not a boundary convention.** delete/clear_drawing
   gained `argc==2` gates because their old silent-no-op semantics collided with log-on-success;
   redo's tolerant-execute semantics do not collide, so the gate would be pure behaviour churn.
   Read the OLD branch's argc behaviour first; the gate follows from it.
2. **A zero-gain atom still has a fail-closed deliverable.** The observable behaviour is
   byte-identical, so the ONLY new value is structural: the S7 exclusivity rows and the roster
   entry. That is why sabotage (A) targets the guard, not the runtime test.
3. **"Second entry point" is a property of the dispatch era, not the key.** The atom-12 doc's
   "redo already self-gates" note pre-dated Phase 3d.2; today the U key is a Tcl-funneled binding
   with Layer-A dedup, which makes redo cleaner than delete (whose XK_Delete key stays raw) — a
   reminder to re-resolve entry maps from the current binding dump every time.

## Status (2026-07-18, batch item 03 fresh-scout): PROCEED as atom 28 — IMPLEMENTED

IMPLEMENTATION OUTCOME (2026-07-18): shipped as audit §48 exactly per §2/§6/§7 — branch delegates,
run_core arm `pop_undo_keep_selection(1, 1)`, DEFAULT `%s` log, NO arity gate, NO callback.c edit;
test_perform_action_redo.tcl 33/33 green on BOTH the pre- and post-migration binaries (the zero-delta
proof), sabotages A–D each failed exactly their target (A: runtime fully green while the S1 delegation
row + 4 S7 rows failed closed — the grep guard is the load-bearing lock, as predicted), S7 block landed
with the `(redo, set_modify);` row SEMICOLON-ANCHORED (the atom-23 idiom — the run_core arm's F-shared
comment mentions the literal, which the plan's unanchored regex double-counted); full_audit: no new
fails beyond the recorded 2026-07-18 baseline.

Every anchor verified from source this scout (drift: branch 8800→8861; all others listed in the
implementation prompt). NEITHER plan defer-trigger confirmed (§3: no sprint policy excludes
consistency moves — the ledger endorses this one; zero result consumers — the compound discards, the
old branch already reset-on-success, and the one near-miss consumes the `-emitted` flag, not the
result). Friction re-scored **fr 1** (F-shared only) — the plan's score holds. The one design
decision: **tolerant argc, NO arity gate** (§2), keeping the atom strictly zero-delta with the
byte-identical bare log at every argc via the default `%s` arm. Implementation prompt:
`doc/claude/refactor_b_batch/prompts/atom28_redo.md`.

---

*Cross-references: the boundary design — `action_log_coverage_audit_and_core_selflog_refactor.md`
§4; log-on-success + the Tcl_ResetResult landmine — §33; the bare-verb molds — §30 (floaters) / §32
(toggle_ignore, incl. the Layer-A dedup + mutates=1 rules) / §44 (delete) / §47 (clear_drawing); the
arity-gate contrast — §44/§47; the shared-sub-step rule — §21; the rubric —
`perform_action_atom24_delete_friction_analysis.md` §2; the undo twin (raw, item 05) —
`doc/claude/refactor_b_batch/PLAN.md` item 05; selection-keeping wrapper — issue 0095 /
`undo_keep_selection_decision.md`.*
