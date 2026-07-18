# The asymmetric query/mutate split behind Refactor B atom 26 (`check_unique_names`)

*Prepared 2026-07-18 on branch `fluid-editing`. Companion to
`perform_action_atom25_add_pin_stubs_returnvalue_condlog_decision.md` (the atom-25 decision) and to
`action_log_coverage_audit_and_core_selflog_refactor.md` (the running audit). `check_unique_names` is the
last confirmed survivor of the atom-24 re-scout (friction 5 — the highest), and it introduces a pattern the
boundary has not yet met: a **read-only-safe query form that is CURRENTLY LOGGED**. This document scopes
that migration and records two decisions — the split shape, and the key-path handling — both resolved from
source.*

---

## 1. The verb, from source (re-verified 2026-07-18)

`xschem check_unique_names <0|1>` — one core, `check_unique_names(int rename)` (`token.c:820`), branching
on the flag:

- **Mode 0 (`rename=0`) — a HIGHLIGHT.** Clears existing net highlights (`clear_all_hilights()`+`draw()`),
  sets `inst[i].color = -PINLAYER` on each duplicate-refdes instance, `redraw_hilights`. It touches only
  **transient highlight state** — no `push_undo`, no `set_modify`, no change to saved content. It is
  **read-only-legal** (fine on a read-only cell).
- **Mode 1 (`rename=1`) — a RENAME.** Everything mode 0 does, PLUS: `push_undo()` (token.c:851, on the first
  duplicate found), `new_prop_string` renames the duplicates (868), `set_modify(1)` (875). A real
  saved-content mutation. **The core owns its undo** (first-duplicate `push_undo`), so a `run_core` arm adds
  none (the no-double-push rule).

The scheduler branch (`scheduler.c:2255`, in `xschem_cmds_c` at 2092; `!xctx` guard 2257, mode calls
2259/2261, log 2266, `Tcl_ResetResult` 2267) has **no readonly gate** and **logs both modes** unconditionally:
```c
if(argc > 2 && !strcmp(argv[2], "1")) check_unique_names(1); else check_unique_names(0);
log_action("xschem check_unique_names %s", <"1" | "0">);   /* mode canonicalized */
```

## 2. The split, and why it is ASYMMETRIC

Only mode 1 mutates saved content, so only mode 1 belongs on the mutation boundary:

- **Mode 1 → `perform_action`.** The boundary adds the readonly gate the branch never had — a **correctness
  fix**: today `check_unique_names 1` renames on a read-only cell (a latent 0041/0051 gap, like reset_symbol
  §42 / floaters §30 / apply_pin_prop §38). `run_core` calls `check_unique_names(1)`, adds no push_undo
  (core owns it). `core_log_action` emits `xschem check_unique_names 1`.
- **Mode 0 → stays RAW in front of the boundary.** Routing the highlight through the mutation boundary would
  let the **all-or-nothing readonly gate over-reject a harmless, read-only-legal highlight** — a regression.
  This is the image (§40) / instance_number (§43) query/mutate-split shape.

**The novelty — a LOGGED query.** In image and instance_number the raw-front query form was an **unlogged
getter**: it stayed raw *and silent*, and the reason to keep it raw was "don't let `Tcl_ResetResult` wipe a
result a caller consumes." Here mode 0 returns no data but **is currently logged** (`xschem
check_unique_names 0` — a replayable "highlight the duplicates" action). So the raw-front mode 0 cannot just
fall silent: it must **retain its own `log_action("xschem check_unique_names 0")`**. The result is an
**asymmetric split** — two log sites on two paths:

```c
else if(!strcmp(argv[1], "check_unique_names")) {
  if(!xctx) {...return TCL_ERROR;}
  if(argc > 2 && !strcmp(argv[2], "1"))
    return perform_action("check_unique_names", argc, argv);   /* MUTATE: gate + effect + log(=1) */
  /* mode 0: read-only-safe duplicate-refdes HIGHLIGHT stays RAW in front of the boundary (the
     all-or-nothing gate would over-reject it on a read-only cell). Unlike image/instance_number's
     UNLOGGED query forms, mode 0 is CURRENTLY logged, so it KEEPS its own log_action here. */
  check_unique_names(0);
  log_action("xschem check_unique_names 0");
  Tcl_ResetResult(interp);
}
```
`run_core`: `check_unique_names(1); return TCL_OK;` (no push_undo). `core_log_action`:
`log_action("xschem check_unique_names 1")` — only "1" ever crosses the boundary (the branch delegates only
`argv[2]=="1"`), so a fixed literal is deterministic and faithful; no flag-array needed.

No-op-still-logs holds: mode 1 with no duplicates does nothing in-core, returns void ⇒ TCL_OK ⇒ logs one
idempotent line (§30). No `F-validate` (the branch has no arg-count error path).

## 3. The key-path decision (RESOLVED from source)

**The question:** do the `#` / Ctrl+# keys reach the scheduler branch (→ already logged, migration covers
them) or a raw path (→ a separate gap)? **Resolved:**

- The menu items (`xschem.tcl:14519/14521`) carry `-accelerator {#}` / `{Ctrl+#}` — a **display label
  only** (a Tk accelerator does not create a binding). The menu's `-command "xschem check_unique_names 0|1"`
  reaches the branch and logs.
- The physical keys are **absent from `keybindings.csv`** (the built-in binding-table dump, 66 rows — no
  numbersign row), so `dispatch_input_action` does not claim them; `handle_key_press` (callback.c:4863)
  falls through its `if(dispatch_input_action(&ae)) return;` (4899) to the legacy `case '#'` (6467), which
  calls `check_unique_names(1)` (6469, Ctrl) / `check_unique_names(0)` (6472) **raw — no log, no readonly
  gate, and (unlike sibling keys) no semaphore/readonly_block guard of its own.**
- **Issue 0068** ("un-migrated legacy-switch keys are not logged") defines exactly this class — an
  `actions.csv` row whose accel never made it into `keybindings.csv` falls through to the legacy switch,
  unlogged (its §2 root cause). `actions.csv:100/101` are those rows for `#`/Ctrl+# (accel + the
  `xschem check_unique_names 0|1` command); 0068's §3 example list does not name `#`/Ctrl+# individually,
  but they match its root cause verbatim. So the keys are a **pre-existing unlogged + ungated 0068-class
  gap**, and independent of the branch.

**Decision — migrate the keys together with the branch (recommended).** Because atom 26 *is* the
check_unique_names migration and 0068 tracks exactly these keys, route `case '#'` through the **same** logic
as the branch, closing the 0068 entry for this verb and a real read-only-rename bug in one move (the
toggle_ignore §32 "route the equivalent key for consistency + coverage" precedent):

```c
case '#':
  if(state & ControlMask) {                    /* mode 1: rename */
    const char *av[3] = { "xschem", "check_unique_names", "1" };
    perform_action("check_unique_names", 3, av);   /* boundary: readonly gate + effect + log; rc discarded */
  } else {                                     /* mode 0: highlight (read-only-legal) */
    check_unique_names(0);
    log_action("xschem check_unique_names 0");  /* raw + own log, mirroring the branch's mode-0 front */
  }
  break;
```
The key discards `perform_action`'s rc (the change_elem_order §41 Shift-S / toggle_ignore §32 event-handled
contract). This adds a NEW log to the mode-0 key (additive coverage, not a regression) and gives the mode-1
key the readonly gate it lacked. No double-log: these keys never reach the branch nor dispatch Layer A.

*Alternative (rejected as the default):* leave the keys to issue 0068 (migrate only the branch). Cleaner
scope, but it leaves Ctrl+# renaming a read-only cell unlogged while the branch is fixed — an avoidable
asymmetry when the fix is three lines and 0068 already names these keys. Keep this fallback only if the key
migration turns out to need a messageBox-preserving `readonly_block()` shim that balloons scope.

## 4. Friction (fr5) and the grep guard

Friction = **F-split (+2)** (query/mutate split) + **F-2ndentry (+1)** (the two keys) + **F-flagarg (+1)**
(the 0/1 token drives both effect and the two log forms) + **the asymmetric-logged-query wrinkle (+1)** —
the highest of the three re-scout survivors. The wrinkle is the deliverable pattern: *a logged read-only
query stays raw-front AND keeps its own log*, extending the image/instance_number split to the logged case.

**Grep guard:** the current single row `{log_action\("xschem check_unique_names} 1 {check_unique_names
branch}` (test_selflog_grep_guard.tcl:368) must become **two form-specific rows**. NB the S1 manifest rows
are `n >= min` FLOORS (the check at :523-529 is `n >= min`), so after migration the old prefix regex would
count 2 and *silently keep passing* — the fail-closed lock is NOT the S1 row but a new **S7 exact-count
block** (the rotate §26/atom-6 "legitimately-one-site" model): scheduler.c EXACTLY ONE
`log_action("xschem check_unique_names 0")` (the branch raw front) + EXACTLY ONE
`log_action("xschem check_unique_names 1")` (core_log_action) + ZERO of the old
`log_action("xschem check_unique_names %` form + ZERO scattered
`scheduler_readonly_reject(interp, "check_unique_names")`; callback.c EXACTLY ONE `..." 0")` (the `#` key
raw front) + ZERO `..." 1")` raw logs. S1 additions: the branch delegation row
`{return perform_action\("check_unique_names", argc, argv\);}`, the two distinct `..." 0"` / `..." 1"` log
rows, and the callback.c rows for the `case '#'` `perform_action`/mode-0 pair. check_unique_names stays in
S2 CVERBS (already listed at :605).

## 5. Test plan (to author at implementation)

`test_perform_action_check_unique_names.tcl`: fixture = two instances forced to the SAME refdes (duplicate).
(a) mode 1 renames the duplicate + exactly +1 `xschem check_unique_names 1` + one undo restores; (b) mode 0
highlights (duplicate `inst.color == -PINLAYER`), mutates NO saved content, +1 `... 0`, and is **allowed on
a read-only cell** (the raw-front proof — must NOT reject); (c) mode 1 on a read-only cell is REJECTED
(TCL_ERROR, no rename, no log — the boundary's new gate); (d) replay both forms through the suppress seam
(re-highlights / re-renames) not re-logged, control re-logs; (e) undo depth — mode 1's single push_undo
(one undo restores the pre-rename names, a double-push would need two); (f) if keys migrated: `#` mode-0 key
logs `... 0` + is read-only-legal, Ctrl+# mode-1 key logs `... 1` + is read-only-rejected (full Tk key
sequence, the gesture-test discipline). **Sabotage:** (A) route mode 0 through perform_action → (b)
read-only-highlight rejected (over-reject proof); (B) drop the mode-0 raw log → (b) `... 0` +0; (C) spurious
push_undo in run_core → (e) undo depth; (D) drop the mode-1 gate → (c) renames read-only.

## 6. Lessons

1. **A query/mutate split has two sub-shapes.** image/instance_number split an *unlogged* query (stays raw
   AND silent). check_unique_names splits a *logged* query (stays raw but KEEPS its log). Same structural
   reason — don't let the mutation gate over-reject a read-only-legal form — but the query's *logging
   status* determines whether the raw-front half falls silent or retains its own `log_action`.
2. **Resolve dispatch paths from the binding dump, not the comment.** The `-accelerator` label made the menu
   *look* like it bound the key; `keybindings.csv` (the actual binding table) settled it. The key is a
   legacy-switch gap (0068), and the branch comment happened to be right — but only reading the dump proved
   it.
3. **When the atom IS the migration a tracked gap was waiting for, close it.** 0068 named these keys as
   awaiting migration; atom 26 migrates the verb; routing the keys through the same logic closes the gap and
   a read-only-rename bug at three lines' cost — cheaper than deferring and re-loading the context later.

## Status (2026-07-18, batch item 01 fresh-scout re-verify): PROCEED as atom 26

Every anchor re-verified from source by the Refactor-B-batch stage-A scout; drifted line numbers updated
in place (scheduler branch 2243→2255; callback.c handle_key_press 4848→4863, dispatch fall-through
4884→4899, `case '#'` 6452→6467; xschem.tcl menus 14432/14434→14519/14521). token.c anchors (core 820,
push_undo 851, new_prop_string 868, set_modify 875), the grep-guard row :368, S2 CVERBS :605 and the
keybindings.csv absence are UNCHANGED. Two claims were corrected, neither material: issue 0068 names the
*class* (actions.csv:100/101 rows with no keybindings.csv row → legacy switch), not the `#` keys
individually; and the S1 guard rows are `>= min` floors, so the fail-closed lock must be the new S7
exact-count block, not the split S1 rows themselves. NEITHER defer trigger is confirmed: the `#` key has
no messageBox/readonly_block/semaphore guard to preserve (nothing to shim — the boundary's
scheduler_readonly_reject ciw_echo is the read-only feedback), and no caller anywhere consumes an interp
result from the branch (it ends in Tcl_ResetResult; zero `[xschem check_unique_names` matches).
Friction re-scored fr4 by the rubric F-codes (F-split +2, F-2ndentry +1, F-flagarg +1); the §4 "+1
asymmetric-logged-query wrinkle" is the pattern novelty, not a rubric code. Implementation prompt:
`doc/claude/refactor_b_batch/prompts/atom26_check_unique_names.md`.

**IMPLEMENTED 2026-07-18 as atom 26 (audit §46):** shipped exactly as §2/§3 above — branch mode-1
delegation + mode-0 logged-query raw front, run_core/core_log_action arms (fixed `1` literal), and the
RECOMMENDED key routing (Ctrl+# → boundary, `#` → raw + own log; no shim needed — the defer triggers stayed
unconfirmed). One fixture correction vs §5: the duplicate pair must be forced under
`set ::disable_unique_names 1` + `setprop` (`new_prop_string` re-uniquifies otherwise; a trailing `fast`
word is not parsed). 38-check test + 5 sabotages (each failed its target: (b2)/(b)/(e)/(c)+grep-rows/(f)),
S1×5 + S7×7 grep rows; the F-flagarg +1 dissolved (a fixed literal, no flag machinery), landing the real
friction at the scout's fr4-minus.

---

*Cross-references: the boundary design — `action_log_coverage_audit_and_core_selflog_refactor.md` §4;
log-on-success — §33; the query/mutate split (unlogged-query shape) — §40 (image) / §43 (instance_number);
the readonly-gate-as-correctness-fix — §30 (floaters) / §38 (apply_pin_prop) / §42 (reset_symbol); the
route-the-equivalent-key precedent — §32 (toggle_ignore); the no-op-still-logs property — §30; the
re-scout that ranked this candidate — `perform_action_atom24_delete_friction_analysis.md`; the legacy-key
gap — issue 0068.*
