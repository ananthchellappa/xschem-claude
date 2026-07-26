# The bare-verb boundary migration behind Refactor B atom 27 (`clear_drawing`)

*Prepared 2026-07-18 on branch `fluid-editing` (batch item 02 fresh scout). Companion to
`perform_action_atom26_check_unique_names_asymmetric_split_decision.md` (the atom-26 decision) and to
`action_log_coverage_audit_and_core_selflog_refactor.md` (the running audit; atom 27 will write §47).
`clear_drawing` is the batch plan's lowest-friction silent mutation: a free-everything verb with NO log, NO
readonly gate, NO undo and NO second entry point. This document records the scout's re-verification of every
plan claim from source, the two defer-trigger sweeps (both came back clean), and the full migration scope.*

---

## 1. The verb, from source (re-verified 2026-07-18)

The scheduler branch (`src/scheduler.c:2388`, inside `xschem_cmds_c` at 2119):

```c
/* clear_drawing
 *   Clears drawing but does not purge symbols */
else if(!strcmp(argv[1], "clear_drawing"))
{
  if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}   /* 2390 */
  if(argc==2) {                                                                  /* 2391 */
    unselect_all(1);                                                             /* 2392 */
    clear_drawing();                                                             /* 2393 */
  }
  Tcl_ResetResult(interp);                                                       /* 2395 */
}
```

- **NO readonly gate** — today `xschem clear_drawing` empties a READ-ONLY view (a 0041/0051-class gap).
- **NO log** — a genuine silent mutation (gain class: silent, the last cheap one in the pool).
- **The `if(argc==2)` quirk** — an extra-arg call skips the body entirely and returns `TCL_OK` with an
  empty result: a SILENT no-op that log-on-success would PHANTOM-log without an arity gate.
- **Empty interp result** on every path; grep-verified ZERO repo callers of the verb (see §3), so no
  consumer exists that the boundary's success-path `Tcl_ResetResult` could break.

The core `void clear_drawing(void)` (`src/actions.c:1866`):

- Drops the in-flight Add-Pin/wire-label preview flags (`sympin_preview`/`wirelabel_preview`, 1875–1876)
  and `graph_lastsel`; deletes the inst/wire spatial tables; frees every `sch*prop` string, the version
  string and `header_text`; `wire_storage_reset()`/`inst_storage_reset()`; frees all texts and every
  per-layer line/rect/arc/poly array; frees the `inst_name_table`/`floater_inst_table` hashes (1926–1927).
- **NO `push_undo`, NO `set_modify`, NO `draw()`, NO log. Returns `void`** → the arm is always `TCL_OK`.

`unselect_all(1)` is the branch's selection-teardown PRE-step (it must run before the storage resets free
the objects the selection references); it moves into the `run_core` arm unchanged, same order.

## 2. The shape: a plain bare-verb migration (delete/§44 mold) — and the two accepted oddities

No split is needed: the verb has **one form, one effect, no query sub-form, no flag args, no result**.
The shape is the atom-24 `delete` template verbatim:

- **Branch** → `return perform_action("clear_drawing", argc, argv);` (the old `!xctx` guard and
  `Tcl_ResetResult` are the boundary's).
- **`run_core` arm** → arity gate (`argc != 2` → `TCL_ERROR "too many arguments"`, the reset_inst_prop §33
  argc-gate — the ONE deliberate behaviour tighten: malformed goes from silent-OK to rejected, so
  log-on-success cannot phantom-log), then `unselect_all(1); clear_drawing(); return TCL_OK;`. The arm adds
  **NO push_undo / set_modify / draw** — none exist today anywhere on this path, and adding any would be a
  behaviour change beyond a migration atom's scope.
- **Log form** → bare verb, `core_log_action`'s DEFAULT `xschem %s` arm. **NO per-verb log arm** (the
  floaters/toggle_ignore/delete precedent); only the header-comment bare-verb rosters gain the name.
- **Readonly** → the boundary's generic `scheduler_readonly_reject` gate is **NEW here and is a
  correctness fix** (the reset_symbol §42 / apply_pin_prop §38 / image §40 / add_pin_stubs §45 class):
  pre-migration a read-only view was silently emptied.

**Accepted oddity 1 — destructive with NO undo, anywhere.** Neither the branch nor the core pushes undo
(verified: no `push_undo` between scheduler.c:2388–2396 or actions.c:1866–1928). The logged line is
**faithful** (replaying `xschem clear_drawing` re-clears whatever is loaded, exactly as the original did)
but **irreversible**: `xschem undo` after a clear restores whatever the LAST prior push saved, not the
pre-clear state. This is today's shipped behaviour, unchanged by the migration, and the batch plan records
it as **accepted, not a bug**. (If an undo-before-clear is ever wanted, it is a standalone behaviour-change
fix in the rect/§25-pool mold — NOT this atom.) The test turns the acceptance into a lock: check (f) proves
`run_core` pushed nothing (a spurious push is exactly what the detector would catch).

**Accepted oddity 2 — no `set_modify`, no `draw`.** A scripted clear leaves the modify flag and the screen
exactly as the old branch did (stale until the caller redraws). Behaviour-preserving; not touched.

## 3. The entry map + the F-shared caller sweep (both defer triggers checked, both CLEAN)

**Defer trigger 1 — "a Tcl machinery caller issuing `xschem clear_drawing` as a sub-step": NOT FOUND.**
Repo-wide grep for `xschem clear_drawing` over `*.tcl`, `*.c`, `*.h`, `*.tk`, tests/, src/*.csv and
xschem.tcl (junk dirs and `.claude/worktrees` excluded) matches ONLY the PLAN.md text itself. There is:
NO callback.c key, NO keybindings.csv / mousebindings.csv / actions.csv row, NO xschem.tcl menu
`-command`, NO test invocation, NO C `tcleval` constructing the verb. `clear_drawing` is a **PURE SCRIPTED
verb** with the reset_inst_prop §33 entry map: reached only by its own scheduler branch. So there is no
F-2ndentry, no key-equivalence decision, no double-log path, and no 0068 involvement.

**Defer trigger 2 — "a read-only-view init/teardown flow the new gate would break": NOT FOUND.** Every
internal teardown calls the **C function raw**, below the boundary, and the gate lives only at the verb:

| Raw C caller | Site | Flow |
|---|---|---|
| `load_schematic` | save.c:3816 / 3819 / 3850 | file load / untitled fallback |
| disk `pop_undo` | save.c:4173 | disk-undo restore |
| `mem_restore_slot` | in_memory_undo.c:463 | memory-undo restore + hierarchy restore |
| `delete_schematic_data` (file-static) | xinit.c:879 | window/tab/context teardown |
| `clear_schematic` | actions.c:3780 | the **separate** `xschem clear` verb's core (Ctrl+N / Ctrl+Shift+N via actions.csv:38/39) |
| `load_unused_fonts` debug dump | font.c:60 | debug |
| `draw_stuff` | actions.c:4191 | debug/perf |

(The netlist backends contain only commented-out calls.) Loading, reloading, descending into, or closing a
READ-ONLY view never dispatches the Tcl verb — so the new gate cannot reject any internal flow. The sibling
verb `xschem clear` (scheduler.c:2373, `clear_schematic(cancel, symbol)` — an ask-to-save composite that
also resets the hierarchy and removes symbols) is a DIFFERENT, unmigrated verb and stays untouched; it is
also the test's F-shared sentinel (check (g)).

This caller set is the **benign F-shared** in the delete/§44 sense: the core is a shared teardown
primitive that ROUTES NO VERBS and stays raw below the boundary (the trim_wires atom-1 sub-step rule).
Because the core must remain SILENT (a log inside `clear_drawing()` would spam a line on every load, undo,
tab close and `xschem clear`), the log lives exclusively at the boundary — which is precisely what the
migration builds and the grep guard locks.

## 4. Friction (verified fr2 — the plan's fr1 under-counted by one) and the grep guard

- **`F-validate` (+1)** — the `if(argc==2)` silent-no-op quirk needs the argc gate (the plan's "one
  behavior tighten"; scheduler.c:2391 verified).
- **`F-shared` (+1)** — the seven raw C teardown callers of §3 (the plan said "single benign F-shared";
  the *class* is one, the sites are seven — all C-level, zero risk).
- **NO** F-split (no query form), F-condlog (no conditional log — no log at all), F-2ndentry (no key/menu),
  F-flagarg (bare verb), F-gate (unconditional compile).

Verified fr = **2** (plan said 1 — same tier, no verdict impact; recorded for rubric honesty, the atom-24
"re-verify from source; classifiers lie" lesson).

**Grep guard** (`tests/headless/test_selflog_grep_guard.tcl`): ADD one S1 scheduler.c floor row
(`return perform_action\("clear_drawing", argc, argv\);` ≥ 1, delete-row prose style); ADD `clear_drawing`
to the S2 CVERBS set (:606–620 — the C side now self-logs the verb via the boundary); ADD an atom-27 S7
exact-count block: scheduler.c `== 1` delegation, scheduler.c `== 0` literal
`log_action\("xschem clear_drawing` (the bare form logs ONLY through `core_log_action`'s default `%s` arm —
no literal site may exist), scheduler.c `== 0` scattered
`scheduler_readonly_reject\(interp, "clear_drawing"\)`, and actions.c `== 0` literal
`log_action\("xschem clear_drawing` (the core stays silent — the §3 spam lock, sabotage D's fail-closed
row). Stays OUT of S3.

## 5. Test plan (to author at implementation — `tests/headless/test_perform_action_clear_drawing.tcl`)

House style = `test_perform_action_delete.tcl` (LOG-open guard, byte-exact line counter, full_audit
`--logdir` registration). **Pin the effect oracle on the PRE-migration binary FIRST** (atom-20 discipline):
confirm on HEAD that (i) `xschem clear_drawing` on a READ-ONLY cell empties it (the bug the gate fixes),
(ii) `xschem clear_drawing extra` is a silent TCL_OK no-op, (iii) `xschem get symbols` stays nonzero after
a clear (the "does not purge symbols" contract).

- **(a) SUCCESS**: fixture (3 placed `devices/res.sym` instances) → `xschem clear_drawing` empties
  (`get instances`==0, `get texts`==0, `get wires`==0), symbols NOT purged (`get symbols` still ≥1 — the
  contract that distinguishes it from `xschem clear`), exactly **+1 byte-exact** `xschem clear_drawing`.
- **(b) ARITY TIGHTEN**: `xschem clear_drawing extra` → TCL_ERROR, NON-EMPTY verb-named message (the §33
  landmine: success-only reset must not wipe it), NO mutation, **+0** log. (Pre-migration: silent TCL_OK.)
- **(c) THE NEW GATE**: `xschem set readonly 1`; `xschem clear_drawing` → TCL_ERROR read-only message,
  NO mutation (instances unchanged), **+0** log. (Pre-migration this CLEARED — the oracle run proves it.)
- **(d) REPLAY**: the recorded line re-executes through the `replay_action_log` suppress seam (re-clears)
  WITHOUT re-logging; a control unwrapped `source` DOES re-log.
- **(e) NO-OP-STILL-LOGS**: `clear_drawing` on an already-empty sheet still logs **+1** (§30 — a void
  success).
- **(f) NO-SPURIOUS-PUSH / accepted irreversibility**: place ONE instance on an empty sheet (the placement
  pushes the pre-placement EMPTY snapshot), `clear_drawing`, then ONE `xschem undo` → `get instances`
  **stays 0** (undo restored the pre-placement empty snapshot — the shipped irreversibility). A sabotage
  `push_undo` in the run_core arm would restore the WITH-instance snapshot (==1) — the detector.
- **(g) SIBLING/SHARED UNTOUCHED**: `xschem clear force` still works and logs **+0**
  `xschem clear_drawing` lines (its `clear_schematic` core calls `clear_drawing()` raw, below the
  boundary — the F-shared spam lock).

**Sabotages** (each targets exactly ONE check; rebuild → targeted fail → `git diff` → targeted
`git checkout --` → clean green):
- **(A)** drop the run_core argc gate → (b) fails (extra-arg mutates + phantom-logs).
- **(B)** bypass the boundary in the branch (restore the old raw inline body) → (c) fails (read-only view
  cleared), AND the S1 delegation / S7 rows fail closed.
- **(C)** spurious `xctx->push_undo()` in the run_core arm → (f) fails (undo resurrects the instance).
- **(D)** `log_action("xschem clear_drawing")` inside the CORE (actions.c) → (g) fails (`xschem clear`
  spams a phantom line), AND the S7 actions.c `== 0` row fails closed.

## 6. Notes

1. **The silent-core rule is the load-bearing half of this atom.** The verb's core is called by seven
   teardown flows; putting the log anywhere but the boundary (the pre-Refactor-A instinct) would spam every
   load/undo/close. The boundary is the ONLY correct log site — this atom is the cleanest illustration yet
   of audit §4's "log at the verb's entry when the core is a shared mechanism".
2. **Irreversible-but-faithful is a legitimate log class.** The replay contract promises the line re-does
   what the user did — not that undo can un-do it. `clear_drawing` had no undo before and has none after;
   the migration neither fixes nor hides that, it documents and locks it (check (f)).
3. **fr drift (1 → 2) without verdict drift.** The plan's rank was computed before the caller sweep counted
   F-validate and F-shared separately; both are the free/benign kinds. Rubric scores are inputs to a
   verdict, not the verdict.

## Status (2026-07-18, batch item 02 fresh-scout): PROCEED as atom 27 — IMPLEMENTED (audit §47)

Every plan claim re-verified from source (line drift: branch 2359 → 2388; C-caller lines confirmed at
font.c:60, in_memory_undo.c:463, save.c:3816/3819/3850/4173, xinit.c:879, plus the two the plan omitted —
actions.c:3780 `clear_schematic` and actions.c:4191 `draw_stuff`). Both defer triggers swept CLEAN (§3).
Implementation prompt: `doc/claude/refactor_b_batch/prompts/atom27_clear_drawing.md`.

IMPLEMENTED 2026-07-18 exactly per §2/§4/§5: pre-migration oracle pinned on HEAD (readonly view emptied
rc=0; extra-arg silent TCL_OK; symbols survive a clear), branch delegation + run_core arm + the two roster
comments shipped, test 29/29 green, all four sabotages (A–D) failed exactly their targets and reverted
byte-exact, grep guard (S1 row + S2 CVERBS + 4-row S7 block) green, full_audit baseline-only fails.
Audit §47 written; next per PLAN.md is item 03 `redo`.
