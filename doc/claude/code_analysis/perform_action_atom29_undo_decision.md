# The normalizing-log-arm migration behind Refactor B atom 29 (`undo`)

*Prepared 2026-07-18 on branch `fluid-editing`. Companion to
`perform_action_atom28_redo_decision.md` (the redo twin, atom 28 / audit §48) and to
`action_log_coverage_audit_and_core_selflog_refactor.md` (the running audit). `undo` is batch item 05
(PLAN.md) — the undo-family twin of redo, a consistency-only migration whose one real wrinkle is that the
old branch logs a NORMALIZED form of its arguments, forcing the first per-verb NORMALIZING log arm for an
integer-pair verb. This document scopes that migration and records the decisions — the log-arm shape, the
tolerant-argc preservation, and the F-shared guard-row hand-off from atom 28 — all resolved from source.*

---

## 1. The verb, from source (re-verified 2026-07-18)

`xschem undo [redo [set_modify]]` — the branch (`scheduler.c:11335-11352`, in `xschem_cmds_u` at 11323):

```c
else if(!strcmp(argv[1], "undo"))
{
  int redo = 0, set_modify = 1;                                   /* 11337 */
  if(!xctx) {...; return TCL_ERROR;}                              /* 11338 */
  if(scheduler_readonly_reject(interp, "undo")) return TCL_ERROR; /* 11339 */
  if(argc > 2) redo = atoi(argv[2]);                              /* 11340-11342 */
  if(argc > 3) set_modify = atoi(argv[3]);                        /* 11343-11345 */
  pop_undo_keep_selection(redo, set_modify);                      /* 11346, issue 0007 */
  if(argc == 2) log_action("xschem undo");                        /* 11349 */
  else          log_action("xschem undo %d %d", redo, set_modify);/* 11350 */
  Tcl_ResetResult(interp);                                        /* 11351 */
}
```

Facts that matter:

- **Already boundary-shaped** (the atom-28 class): inline `!xctx` guard + inline
  `scheduler_readonly_reject(interp, "undo")` + one core call + unconditional log + reset-on-success.
  Migration is gate/log consolidation; **coverage gain is ZERO by design**.
- **Tolerant argc, like redo (§48), NOT like delete (§44)/clear_drawing (§47)**: there is no
  `if(argc==2)` skip-body anywhere. Every argc executes AND logs — extra args beyond argv[3] are consumed
  by the atoi defaults and dropped from the log. So **no arity gate** (an arity gate is a contract
  consequence of an OLD `if(argc==N)` silent no-op, which undo never had — the §48 lesson verbatim).
- **The log is NORMALIZED, not raw-argv** — three distinct normalizations the migrated form must
  reproduce byte-identically:
  1. **atoi canonicalization**: `xschem undo 00 01` executes redo=0/set=1 and logs `xschem undo 0 1`.
  2. **default fill**: `xschem undo 1` (argc==3) logs BOTH ints — `xschem undo 1 1` (set_modify default 1).
  3. **tail drop**: `xschem undo 0 1 extra` logs `xschem undo 0 1` (extra words never reach the log).
  This is the plan's F-flagarg wrinkle: `core_log_action`'s hypothetical raw-argv passthrough would
  diverge on all three; a **per-verb normalizing arm** is required.
- **The core**: `pop_undo_keep_selection(int redo, int set_modify)` (`select.c:2360`, decl
  `xschem.h:2120`) — the issue-0095 selection-keeping wrapper over `xctx->pop_undo` (disk `pop_undo`
  save.c:4134 / `mem_pop_undo` in_memory_undo.c:596). **Undo-stack NAVIGATION: no push_undo on this path
  and none may be added** (the internal at-head `xctx->push_undo()` save.c:4159-4164, which arms the redo
  slot, is the CORE's own business). An **empty undo stack no-ops in-core**
  (`cur_undo_ptr == tail_undo_ptr` → return, save.c:4156) = a no-op SUCCESS the old branch already logged
  unconditionally — log-on-success preserves it (§30 no-op-still-logs). The `redo` flag passes through
  verbatim (0/4 undo, 1 redo, 2 peek-restore — save.c:4147-4172), so `xschem undo 1 1` IS a redo wearing
  the undo verb, with its own distinct log line (the atom-28 §48 F-shared record).
- **No result consumer**: zero `xschem undo]` matches repo-wide; the old branch already reset-on-success,
  and its error paths (readonly/!xctx) return before the reset — the boundary's success-only reset is
  observably identical.

## 2. The shape decision — full delegation + a per-verb NORMALIZING log arm

**Not a split.** Every argc/argv form of `undo` pops the undo stack — a saved-content mutation. There is
no read-only-legal sub-form, so no query/mutate split (§40/§43/§46 do not apply); the boundary's
all-or-nothing gate is a pure consolidation (same `scheduler_readonly_reject` + same `"undo"` verb string
= byte-identical message + ciw_echo).

**Branch** → `return perform_action("undo", argc, argv);` (the atom-28 delegation shape).

**`run_core` arm** — moves the argv parse + the core call in, verbatim; NO push_undo, NO arity gate:

```c
else if(!strcmp(verb, "undo")) {
  int redo = 0, set_modify = 1;
  if(argc > 2) redo = atoi(argv[2]);
  if(argc > 3) set_modify = atoi(argv[3]);
  pop_undo_keep_selection(redo, set_modify); /* issue 0007: keep selection across undo */
  return TCL_OK;
}
```

**`core_log_action` arm** — the NORMALIZING form, reading argv IDENTICALLY to run_core (the invariant
every arg-carrying arm has kept since atom 6: rotate/flip/flipv mirror the atof, break_wires canonicalizes
the boolean, attach_labels preserves the atoi'd `%d` — "the logged form can never diverge from the
applied effect"):

```c
} else if(!strcmp(verb, "undo")) {
  int redo = 0, set_modify = 1;
  if(argc > 2) redo = atoi(argv[2]);
  if(argc > 3) set_modify = atoi(argv[3]);
  if(argc == 2) log_action("xschem undo");
  else          log_action("xschem undo %d %d", redo, set_modify);
}
```

Byte-identical to the old branch's two log forms at every argc/argv — including the three normalizations
of §1. **The defer trigger "normalizing arm = shared-machinery scope creep" is NOT confirmed**: this is a
per-verb arm (the rubric's stated F-flagarg cost), zero edits to `perform_action`/`log_action`/any shared
seam. The trigger "policy excludes consistency-only moves" is settled — atom 28 landed the class
(PLAN.md ledger `[x] 03`).

**Rejected alternative — accept a byte-level log change** (default `%s` arm or raw-argv passthrough):
would break the atom-28 test's check (g) (`test_perform_action_redo.tcl:221-223` pins `xschem undo 1 1`
+1 exact) and the `tests/undo_stable_ids.tcl:83` machinery caller's recorded form, and would make
`xschem undo 1` replay as a bare `xschem undo` — a WRONG direction flip on replay. The normalizing arm is
both cheaper and the only faithful option.

## 3. The entry map (resolved from source — NO key/menu edit needed)

Every entry funnels through the Tcl verb; there is **no raw C second entry** for undo:

- **Key `u`**: `keybindings.csv:52` (`key,117,0,canvas,edit.undo,1` — keysym 117, idle-gated), seeded at
  `callback.c:4034`, → Tcl-backed ActionDef `callback.c:3728`
  `{ "edit.undo", NULL, "xschem undo; xschem redraw", "Undo", 1 /*mutates*/ }` →
  `dispatch_input_action` (callback.c:4124): read-only gate at 4136 (`action_id_mutates` +
  `readonly_block`, headless-safe callback.c:35) BEFORE any Tcl runs; Layer-A wrapper log skipped when
  the inner log set `actionlog_cmd_logged` (util.c:503) — exactly ONE `xschem undo` line, never the
  compound, before AND after (identical to redo §48).
- **Legacy `case 'u'` plain is GONE** (callback.c:5880-5884, comment only — Phase 3d.2 sem-gated batch 1);
  the surviving Alt-u (align → `perform_action("align")`) and Ctrl-u (unselect floaters) arms never touch
  undo. **Issue 0068 is NOT implicated** (it names undo only as an already-covered resolve target).
- **Menu** `xschem.tcl:14209` (Edit>Undo, `-accelerator U` display-only) + **toolbar** `:12711` run the
  same plain compound; `actions.csv:73` is the same id's metadata row.
- **Machinery Tcl callers**: `tests/undo_stable_ids.tcl:83` (`xschem undo 1`) plus ~30 headless tests
  driving bare `xschem undo` as fixture plumbing — all already logged today (the branch logs
  unconditionally), so migration changes NOTHING about log volume; no suppress bracket needed.

## 4. Friction (fr2) and the grep guard

Friction = **F-flagarg (+1)** (the normalizing per-verb log arm) + **F-shared (+1)** (the same core is
called fixed-arg `(1, 1)` by run_core's redo arm, scheduler.c:1091 — the atom-28 twin; guard rows must
keep pinning BOTH sites). No F-split (no read-only-legal form), no F-validate (no error path to add), no
F-2ndentry (no raw key), no F-condlog, no F-gate. **The scout confirms the plan's fr2.**

**Grep guard** (`tests/headless/test_selflog_grep_guard.tcl`):

- S1 row `:333` `{log_action\("xschem undo"} 1 {undo branch}` (its closing-quote regex pins ONLY the bare
  form 11349 — the `%d %d` form has a space after `undo`) → **REPLACE** with the delegation row
  `{return perform_action\("undo", argc, argv\);} 1 {...}`. NB S1 rows are `>= min` FLOORS (the §46
  lesson) — the fail-closed lock is the S7 block.
- **New S7 exact-count rows**: scheduler.c **EXACTLY ONE** `log_action\("xschem undo"\)` (the arm's bare
  form — closing paren/quote keeps it distinct from `%d %d` and from `undo_type`), **EXACTLY ONE**
  `log_action\("xschem undo %d %d"` (the arm's normalized form), **ZERO**
  `scheduler_readonly_reject\(interp, "undo"\)` (the boundary's generic gate covers it); callback.c
  **ZERO** `log_action\("xschem undo"` (no key self-logs it).
- **Atom-28 S7 rows survive numerically, but their prose moves**: `:1659` `pop_undo_keep_selection\(1, 1\)`
  == 1 (the redo arm — untouched); `:1662` `pop_undo_keep_selection\(redo, set_modify\);` == 1
  (semicolon-anchored) — the ONE argv-parsed site **MOVES from the branch into run_core's undo arm**, so
  the count stays 1 while the row's description ("the RAW undo branch... must neither disappear nor route
  this atom") must be REWRITTEN to name the run_core undo arm (atom 29) as the pinned site. Update the
  atom-28 S1 row `:334`'s "stays batch item 05's scope" tail and run_core's redo-arm F-shared comment
  (scheduler.c:1087-1090) the same way. `test_perform_action_redo.tcl` is NOT edited: its checks (incl.
  (g), which pins the `xschem undo 1 1` line byte-exactly) pass unchanged; its "stays RAW" comments are
  historical atom-28-time prose.
- `undo` STAYS in S2 CVERBS (`:608`), OUT of S3; the S5 runtime canary `:735`
  (`foreach verb {undo redo copy trim_wires}` exactly-+1) is untouched and must keep passing —
  as must `test_selflog_output.tcl:43-44` ("raw undo self-logs") and `:53-57` ("menu wrapper logs undo
  exactly once", the `menu_action_logged` dedup — still satisfied because `core_log_action`→`log_action`
  sets the same `actionlog_cmd_logged` flag).

## 5. Test plan (to author at implementation — `test_perform_action_undo.tcl`)

House style = `test_perform_action_redo.tcl` (byte-exact line counting; oracle `xschem get instances`;
pin the oracle on the PRE-migration binary first — near-zero-delta means every check should pass on HEAD
too). Fixture: fresh sheet + `xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}` (pushes undo).
Checks: **(e-first) NO-OP-STILL-LOGS** — before any push, `xschem undo` on the empty stack → TCL_OK, no
mutation, +1 exact-bare (§30); **(a) SUCCESS** — after placement, `xschem undo` → 1→0, TCL_OK, +1
exact-bare, result blank; **(b) THE HEADLINE, the normalizing arm** — (b1) `xschem undo 1 1` redoes 0→1,
+1 exact `xschem undo 1 1`, +0 bare, +0 `xschem redo`; (b2) `xschem undo 00 01` undoes 1→0, +1 exact
`xschem undo 0 1`, +0 `xschem undo 00 01`; (b3) `xschem undo 1` redoes 0→1, +1 exact `xschem undo 1 1`
(default-fill); (b4) `xschem undo 0 1 extra` undoes 1→0, +1 exact `xschem undo 0 1`, +0 lines containing
`extra` (tolerant tail-drop); **(c) READONLY CONSOLIDATION** — read-only cell → TCL_ERROR non-empty
`*undo*read-only*` (§33 landmine), no mutation, +0 log; **(d) REPLAY** — the recorded bare line
re-executes through the `replay_action_log` suppress seam without re-logging; control unwrapped `source`
re-logs; **(f) STACK ROUND-TRIP** — undo→0/redo-verb→1 twice (the spurious-push detector; also locks the
sibling: +1 `xschem redo`, +0 undo lines); **(g) KEY FUNNEL + LAYER-A DEDUP** —
`xschem callback .drw 2 400 300 117 0 0 0` (key `u` through the real dispatch chain) applies the undo,
+1 exact-bare, +0 compound `xschem undo; xschem redraw` lines; then read-only + same injection → blocked
at dispatch, no mutation, +0 log.

**Sabotages** (each targets exactly one check): **(A)** bypass the boundary (restore the raw inline
body) → runtime .tcl passes in full while the S1 delegation + S7 rows fail closed (the §48/§32
grep-guard-is-the-lock lesson); **(B)** spurious `xctx->push_undo()` in the arm before the pop → (a)
fails (instances stays 1 — push-then-pop restores the just-pushed state); **(C)** raw-argv log
passthrough instead of the normalizing arm → (b2) fails (`xschem undo 00 01` logs non-normalized);
**(D)** drop the per-verb arm (fall to default bare `%s`) → (b1) fails (`xschem undo 1 1` logs bare);
**(E)** gate the log on did-something (TCL_ERROR at `cur_undo_ptr == tail_undo_ptr`) → (e) fails.

## 6. Lessons

1. **F-flagarg's cost is a per-verb arm, not a boundary change.** The plan flagged the normalizing log as
   a possible scope-creep defer; from source it is exactly the cost the rubric already prices in — every
   arg-carrying arm since atom 6 reads argv identically to run_core, and normalization (atoi/default-fill/
   tail-drop) is just that invariant applied to an integer pair.
2. **A twin migration inherits the sibling's guard rows — including their prose.** Atom 28's S7 rows were
   written to fail closed against exactly this atom done wrong (routing undo's redo-form through the redo
   verb). Done right, the counts survive and only the row DESCRIPTIONS move — re-reading the guard's
   intent, not just its regexes, is what keeps it truthful.
3. **"Consistency-only" still buys something concrete**: after atom 29 the whole undo/redo family is
   behind the ONE gate + ONE log site, and the normalized `undo %d %d` form is locked by exact-count rows
   instead of an unpinned inline branch.

## Status (2026-07-18, batch item 05 fresh-scout): PROCEED as atom 29

Every anchor above re-verified from source (branch 11335-11352 in `xschem_cmds_u` 11323; core select.c:2360
with the empty-stack no-op save.c:4156 and flag semantics 4147-4172; boundary 173/225/1115/1481 with the
redo arm 1073-1093 and default log arm 1445-1447; entry map keybindings.csv:52 / callback.c:3728/4034/4136 /
xschem.tcl:12711/14209 / actions.csv:73; guard rows :333/:334/:608/:735/:1659-1664). NEITHER defer trigger
is confirmed: the normalizing arm is standard per-verb F-flagarg machinery (no shared-seam edit), and the
consistency-only policy was settled when atom 28 landed. No result consumer, no raw second entry, no
read-only-legal form. Friction fr2 (F-flagarg +1, F-shared +1) — the scout confirms the plan's score.
Implementation prompt: `doc/claude/refactor_b_batch/prompts/atom29_undo.md`.

**IMPLEMENTED 2026-07-18 as atom 29 (audit §49)**: shipped exactly as scoped — branch delegation +
run_core argv-parsed arm + the NORMALIZING core_log_action arm; oracle pinned on the PRE-migration
binary first (all 46 checks of `test_perform_action_undo.tcl` pass on BOTH binaries — zero delta);
sabotage ×5 verified (A hit exactly the 6 grep rows while the runtime .tcl passed in full; E's
did-something gate also collaterally blocked the redo-direction forms at stack bottom — cur==tail even
with a redo tail armed, beyond the scoped "ONLY (e)" prediction); atom-28 twin rows' counts survived
with prose re-homed; `test_perform_action_redo.tcl` untouched and green.

---

*Cross-references: the boundary design — `action_log_coverage_audit_and_core_selflog_refactor.md` §4;
log-on-success — §33; the zero-delta consistency class + tolerant argc + the F-shared twin rows — §48
(redo); no-op-still-logs — §30; the arg-read-identically invariant — §26 (rotate) / §29 (break_wires) /
§31 (attach_labels); the arity-gate-is-a-consequence rule — §48; the re-scout rubric —
`perform_action_atom24_delete_friction_analysis.md` §2.*
