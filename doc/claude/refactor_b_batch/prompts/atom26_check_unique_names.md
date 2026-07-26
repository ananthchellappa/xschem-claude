# Refactor B ATOM 26 — migrate `check_unique_names` onto the perform_action boundary (asymmetric query/mutate split + `#`/Ctrl+# key routing)

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`. You are the implement stage of
Refactor B batch item 01. The scout has already verdicted PROCEED and re-verified every anchor below from
source on 2026-07-18. Atom number: **26** (the 26th per-verb migration; audit section to write: **§46**).

The shape (decided, do not re-litigate — see the decision doc): an **asymmetric query/mutate split**.
Mode 1 (rename, the only saved-content mutation) routes through `perform_action`, gaining the readonly
gate the branch never had (a real mutate-on-read-only bug today). Mode 0 (duplicate-refdes highlight,
read-only-legal, **currently logged**) stays RAW in front of the boundary AND **keeps its own
`log_action("xschem check_unique_names 0")`** — the new *logged-query* sub-shape of the image/§40 +
instance_number/§43 split (whose query fronts were unlogged). Plus: route the `#`/Ctrl+# legacy-switch
keys through the same logic, closing a 0068-class unlogged+ungated key gap and the read-only-rename hole
in one move (the toggle_ignore §32 route-the-equivalent-key precedent).

## READ FIRST (in order)

1. `doc/claude/code_analysis/perform_action_atom26_check_unique_names_asymmetric_split_decision.md` —
   the decision doc (re-verified 2026-07-18; its Status section records the anchor drift already fixed).
2. `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` — §4 (boundary),
   §33 (log-on-success + the Tcl_ResetResult landmine), §40/§43 (query/mutate split), §30/§32
   (no-op-still-logs, route-the-equivalent-key), §44/§45 (delete / add_pin_stubs — the latest shapes).
3. `doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md` §2 (the current
   contract + F-codes).
4. `doc/claude/issues/0068-unmigrated-legacy-switch-keys-not-logged.md` (the key-gap class).
5. Templates: `tests/headless/test_perform_action_delete.tcl` (bare-verb atom test house style),
   `tests/headless/test_perform_action_image.tcl` + `test_perform_action_instance_number.tcl`
   (query/mutate-split checks), `tests/headless/test_selflog_grep_guard.tcl` (S1 manifest :327+, S7
   block :781+).

## DISCIPLINE (non-negotiable)

Re-verify EVERY anchor below from source before editing (line numbers drift). A green suite does not
prove the changed code ran: every named sabotage must fail EXACTLY its target check, be reverted with a
targeted `git checkout -- <file>` ONLY after `git diff` confirms that file holds nothing but the
sabotage, and a clean re-run must be green. C89: declarations at block top. Never `git add -A`,
`git commit -a`, `git reset --hard`, never push — stage the explicit file list only. Do not touch the
`_nhangle_*`/`_allm_*`/`_bold_*` junk dirs or any file outside the scope listed at the end. Headless
tests: each test is its own process; relative paths need repo-root cwd; a script error idles, not hangs.

## ANCHORS (verified 2026-07-18 — re-verify, do not trust)

- **Branch**: `src/scheduler.c:2255` `else if(!strcmp(argv[1], "check_unique_names"))` inside
  `xschem_cmds_c` (fn at 2092). Body: `!xctx` guard 2257; `check_unique_names(1)` 2259 /
  `check_unique_names(0)` 2261 (any argv[2] other than exact `"1"` → mode 0, including bare argc==2);
  canonicalized log 2266 `log_action("xschem check_unique_names %s", (argc > 2 && !strcmp(argv[2],
  "1")) ? "1" : "0");`; `Tcl_ResetResult` 2267. NO readonly gate, NO early-TCL_ERROR validation, NO
  result any caller consumes (zero `[xschem check_unique_names` matches repo-wide).
- **Core**: `src/token.c:820` `void check_unique_names(int rename)` — clears existing hilights 827–831;
  per-duplicate `xctx->inst[i].color = -PINLAYER` 845 + `inst_hilight_hash_lookup(i, -PINLAYER, ...)`
  846; **rename==1 first-duplicate `xctx->push_undo()` 851** (core owns undo); `new_prop_string` rename
  868; `if(modified) set_modify(1)` 875 (mode 0 never sets it); `redraw_hilights` 881; returns **void**.
  Only C callers: the branch + the callback.c `#` key — 1:1 apart from the key (F-2ndentry).
- **Boundary machinery**: `scheduler_readonly_reject` scheduler.c:173 (does a `ciw_echo` in has_x
  sessions — the read-only user feedback); `run_core` 212 (last arm `add_pin_stubs` ends ~1018,
  unreachable default 1019); `core_log_action` 1036 (add_pin_stubs arm 1338–1357; DEFAULT bare
  `log_action("xschem %s", verb)` arm 1358–1360); `perform_action` 1394 (log-on-success + success-only
  Tcl_ResetResult). `extern int perform_action(...)` in `src/xschem.h:2134`.
- **Keys**: `src/callback.c:6467` `case '#':` — 6468 `if((state & ControlMask))` →
  `check_unique_names(1)` 6469, else `check_unique_names(0)` 6472. RAW: no log, no readonly gate, and —
  unlike sibling keys — NO `semaphore`/`readonly_block()` guard of its own. `handle_key_press` 4863;
  `if(dispatch_input_action(&ae)) return;` 4899. `src/keybindings.csv` has NO numbersign row (66 rows)
  → the physical keys never reach `dispatch_input_action`; `src/actions.csv:100/101` carry the
  `#`/Ctrl+# accels + `xschem check_unique_names 0|1` commands (registry/palette display+command, not a
  binding — issue 0068 §2 root cause verbatim). Key-routing template: the Ctrl-! break_wires block
  callback.c:6503–6506 (`const char *av[3];` at block top; rc DISCARDED — the event-handled contract).
- **Menus**: `src/xschem.tcl:14519/14521` — `-command "xschem check_unique_names 0|1"` (reach the
  branch; log there), `-accelerator {#}`/`{Ctrl+#}` display-only.
- **Grep guard**: `tests/headless/test_selflog_grep_guard.tcl:368` S1 row
  `{log_action\("xschem check_unique_names} 1 {check_unique_names branch}`. S1 rows are `n >= min`
  FLOORS (:523–529) — the old prefix regex would count 2 post-migration and silently pass, so the
  fail-closed lock is the NEW S7 exact-count block (S7 starts :781; model = the rotate atom-6
  "legitimately-one-site" rows :857–875). `check_unique_names` already sits in S2 CVERBS (:605) — keep
  it there, keep it OUT of S3.
- **Existing coverage that must keep passing**: `tests/headless/test_selflog_output.tcl:352–357` drives
  both modes on an EDITABLE cell (nand2.sch loaded at :340) and asserts both log lines. (The test is a
  baseline WSLg transform-key flake overall, but these checks are deterministic — do not newly break
  them.)
- **full_audit registration**: `tests/headless/full_audit.sh` `logdir_tests` list (:40–61).
- **Key injection idiom** (deterministic headless, no Tk event generate):
  `xschem callback .drw 2 <mx> <my> <keysym> 0 0 <state>` — see test_perform_action_align.tcl:98,
  test_deselect_mode.tcl:98. `'#'` = keysym 35; ControlMask = state 4 (the case tests only
  `state & ControlMask`, so the shift bit is irrelevant). This drives the REAL
  `callback()->handle_key_press` chain — the gesture-test-full-sequence lesson's approved headless form.

## DO

1. **`run_core` arm** (src/scheduler.c, after the `add_pin_stubs` arm ~1018, before the unreachable
   default):
   ```c
   else if(!strcmp(verb, "check_unique_names")) {
     /* Refactor B atom 26 (audit §46; decision doc perform_action_atom26_check_unique_names_
      * asymmetric_split_decision.md): ONLY mode 1 (rename) crosses the boundary -- the branch
      * delegates solely on argv[2]=="1". check_unique_names(1) (token.c) OWNS its undo (push_undo
      * on the FIRST duplicate found, token.c:851) + set_modify(1) (875), so this arm adds NO
      * push_undo/draw (the atom-1 no-double-push rule). Returns void => always TCL_OK; a
      * no-duplicates run is a no-op SUCCESS that still logs one idempotent line (§30
      * no-op-still-logs). Extra args beyond the "1" are ignored, exactly as the old branch did.
      * Mode 0 (duplicate highlight) is the read-only-legal LOGGED QUERY: it stays RAW in the
      * branch front + the '#' key with its own log_action (the asymmetric split -- see the
      * branch comment). */
     check_unique_names(1);
     return TCL_OK;
   }
   ```
2. **`core_log_action` arm** (before the DEFAULT bare arm ~1358):
   ```c
   else if(!strcmp(verb, "check_unique_names")) {
     /* atom 26: FIXED literal -- only "1" ever crosses the boundary (the branch delegates solely
      * argv[2]=="1"; the Ctrl+# key passes a literal "1"), and the OLD branch log canonicalized
      * every call to "1"/"0" via its ?: -- so this literal is byte-identical to the pre-migration
      * log for every argc/argv shape that reaches it. No flag array, no F-flagarg machinery.
      * The mode-0 line is NOT here: it lives raw-front in the branch + the '#' key (the
      * asymmetric logged-query split, §46). */
     log_action("xschem check_unique_names 1");
   }
   ```
   (Do NOT touch the `(void)argc; (void)argv;` — the arm reads neither.)
3. **Branch** (src/scheduler.c:2255) — the asymmetric split, replacing the whole body:
   ```c
   else if(!strcmp(argv[1], "check_unique_names"))
   {
     if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
     if(argc > 2 && !strcmp(argv[2], "1"))
       return perform_action("check_unique_names", argc, argv);  /* MUTATE: gate + effect + log(=1) */
     /* mode 0: read-only-safe duplicate-refdes HIGHLIGHT stays RAW in front of the boundary
      * (the all-or-nothing readonly gate would over-reject it on a read-only cell -- the image
      * §40 / instance_number §43 split). UNLIKE those unlogged query fronts, mode 0 is a
      * CURRENTLY-LOGGED replayable action, so it KEEPS its own log_action here (the asymmetric
      * logged-query sub-shape, atom 26 / audit §46). Any argv[2] other than exact "1" -- and the
      * bare argc==2 form -- lands here and logs the canonical "0", byte-identical to the old
      * `%s`-with-?: site. */
     check_unique_names(0);
     log_action("xschem check_unique_names 0");
     Tcl_ResetResult(interp);
   }
   ```
4. **Keys** (src/callback.c:6467):
   ```c
   case '#':
     if((state & ControlMask)) {
       /* Ctrl+#: rename duplicates -- route through the mutation boundary (Refactor B atom 26):
        * readonly gate (was NONE -- a read-only cell was silently RENAMED) + effect + the ONE
        * `xschem check_unique_names 1` log (was UNLOGGED -- a 0068-class legacy-switch gap; no
        * keybindings.csv row exists, so this case is the only handler). rc DISCARDED (the
        * toggle_ignore §32 / Shift-S §41 event-handled contract). No semaphore/readonly_block
        * added: this key never had them (sibling keys only KEPT pre-existing guards);
        * scheduler_readonly_reject's ciw_echo is the read-only feedback. C89: av at block top. */
       const char *av[3];
       av[0] = "xschem"; av[1] = "check_unique_names"; av[2] = "1";
       perform_action("check_unique_names", 3, av);
     }
     else {
       /* #: duplicate highlight -- read-only-legal, stays RAW + gains its own log, mirroring the
        * scheduler branch's mode-0 front (asymmetric split, atom 26). ADDITIVE coverage: this key
        * logged nothing before. */
       check_unique_names(0);
       log_action("xschem check_unique_names 0");
     }
     break;
   ```
5. **Named fallback (scope guard, NOT a full DEFER):** if the key routing unexpectedly balloons
   (it should not — there is no messageBox/guard to preserve), shrink to branch-only and leave the keys
   to issue 0068, per the decision doc §3 alternative. Record why in the receipt.

## TEST — `tests/headless/test_perform_action_check_unique_names.tcl`

House style = test_perform_action_delete.tcl (check proc, LOG guard header, `count_lines`-style
byte-exact log counting, full_audit `--logdir` note). **Pin the effect oracle on the PRE-migration
binary FIRST** (atom-20 discipline): build HEAD, confirm the fixture below yields a duplicate pair, that
`check_unique_names 1` renames it on a READ-ONLY cell (the bug), and that
`xschem list_hilights all_inst` reports the mode-0 highlight.

Fixture: fresh untitled sch;
`xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}` twice at distinct coords → two instances
BOTH named R1. If placement auto-uniquifies the second name (new_prop_string may renumber — check the
oracle run), force the duplicate instead via `xschem setprop instance 1 name R1 fast` (the -fast
backannotation arm skips uniquify and stays unlogged machinery) and re-verify the pair reads back R1/R1. Oracles: rename → instname read-back (`xschem getprop instance 1 name` /
`xschem getprop instance_notcl 1 name`) changes on one of the pair; highlight →
`xschem list_hilights all_inst` non-empty (entries carry value −PINLAYER); modified →
`xschem get modified`.

Checks (each named, each independently assertable):
- **(a) MUTATE success**: `xschem check_unique_names 1` renames the duplicate (names now unique),
  exactly **+1 byte-exact** `xschem check_unique_names 1`, interp result blank.
- **(b) LOGGED QUERY on an editable cell**: rebuild the duplicate pair; `xschem check_unique_names 0`
  highlights (list_hilights all_inst non-empty), renames NOTHING, exactly **+1** `... 0`.
- **(b2) THE SPLIT HEADLINE — read-only query NOT over-rejected**: `xschem set readonly 1`;
  `xschem check_unique_names 0` → TCL_OK, still highlights, **+1** `... 0`, no mutation.
- **(c) THE NEW GATE — read-only mutate refused**: still read-only; `xschem check_unique_names 1` →
  TCL_ERROR with a NON-EMPTY verb-named read-only message (the §33 landmine: success-only
  Tcl_ResetResult must not wipe it), NO rename, **+0** log. (Pre-migration this RENAMED — the oracle
  run proves the fix.)
- **(d) REPLAY**: both recorded lines re-execute through the `replay_action_log` suppress seam
  (re-highlight / re-rename) WITHOUT re-logging; a control unwrapped `source` DOES re-log.
- **(e) UNDO DEPTH (no-double-push)**: rebuild duplicates; one `check_unique_names 1`; ONE undo
  restores BOTH original names; a SECOND undo peels back the fixture placement — a spurious run_core
  push would leave the second undo still at the renamed/pre-rename boundary (the delete-(f) detector
  shape).
- **(e2) NO-OP-STILL-LOGS**: with NO duplicates present, `check_unique_names 1` mutates nothing
  (no push_undo fires in-core), still **+1** `... 1` (§30).
- **(f) KEYS** (deterministic injection, the shipping profile's real dispatch chain):
  `xschem callback .drw 2 400 300 35 0 0 0` (`#`) → **+1** `... 0` + highlights, and on a READ-ONLY
  cell still works (+1, TCL_OK path); `xschem callback .drw 2 400 300 35 0 0 4` (Ctrl+#) → **+1**
  `... 1` + renames on an editable cell, and on a READ-ONLY cell is REFUSED (no rename) and logs **+0**.
- **(g) CANONICALIZATION preserved**: `xschem check_unique_names 2` runs mode 0 (highlights, no
  rename) and logs `... 0` — byte-identical to the old `%s`/?: behavior.

**Sabotages** (each targets EXACTLY ONE check; rebuild, confirm the targeted fail, `git diff` the file,
targeted `git checkout --` revert, clean green re-run):
- **(A)** whole-verb delegate (route mode 0 through perform_action too) → (b2) read-only highlight
  rejected (the over-reject proof).
- **(B)** drop the branch mode-0 `log_action` → (b) +0.
- **(C)** spurious `xctx->push_undo()` in the run_core arm → (e) undo depth.
- **(D)** bypass the boundary in the branch (raw `check_unique_names(1)` + old-style inline log) →
  (c) renames read-only, AND the S7 exact-count rows fail closed.
- **(E)** revert Ctrl+# to the raw unrouted call → (f) Ctrl+# logs +0 / read-only key renames.

## GREP GUARD — `tests/headless/test_selflog_grep_guard.tcl`

- **REPLACE** the S1 scheduler.c row at :368 with THREE rows (labels in the S1 house style, citing
  atom 26 / §46):
  - `{return perform_action\("check_unique_names", argc, argv\);} 1 {branch mode-1 delegation ...}`
  - `{log_action\("xschem check_unique_names 0"\);} 1 {mode-0 LOGGED-QUERY raw front in the BRANCH ...}`
  - `{log_action\("xschem check_unique_names 1"\);} 1 {mode-1 form in core_log_action ...}`
- **ADD** callback.c S1 rows:
  - `{perform_action\("check_unique_names", 3, av\);} 1 {Ctrl+# key routes through the boundary ...}`
  - `{log_action\("xschem check_unique_names 0"\);} 1 {'#' key mode-0 raw front + own log ...}`
- **ADD an S7 exact-count block** (the fail-closed lock — S1 rows are `>=` floors):
  scheduler.c `== 1` for `log_action\("xschem check_unique_names 0"`, `== 1` for
  `log_action\("xschem check_unique_names 1"`, `== 0` for the OLD
  `log_action\("xschem check_unique_names %` form, `== 0` for
  `scheduler_readonly_reject\(interp, "check_unique_names"\)`; callback.c `== 1` for
  `log_action\("xschem check_unique_names 0"`, `== 0` for `log_action\("xschem check_unique_names 1"`,
  `== 1` for `perform_action\("check_unique_names", 3, av\);`.
- `check_unique_names` STAYS in S2 CVERBS (:605); stays OUT of S3.

## BUILD + AUDIT

- `cd src && make` (default cairo config). C89 — no `//` comments, decls at block top.
- Run: the new test (repo-root cwd,
  `DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) --script tests/headless/test_perform_action_check_unique_names.tcl`),
  plus siblings `test_perform_action_delete`, `test_perform_action_add_pin_stubs`,
  `test_perform_action_image`, `test_perform_action_instance_number`, `test_selflog_output`,
  `test_selflog_grep_guard`.
- Register the new test in `tests/headless/full_audit.sh` `logdir_tests` (:40–61).
- Run `tests/headless/full_audit.sh`. **Baseline fails are pre-existing, NOT yours** (PLAN.md header,
  2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag, test_ciw,
  test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui, test_lib_sweep,
  test_phase3_mints, test_reopen_readonly, test_save_as_cellview, test_select_at, test_selflog_output,
  test_untitled_reuse, test_wire_split. ANY new fail is this atom's problem, full stop.
  test_selflog_output's baseline fail is the WSLg transform-key flake set — its deterministic
  check_unique_names checks (:352–357) must not newly fail.

## DOCS

- Audit: add **§46** (atom 26) to
  `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` in the §44/§45
  house style (the split, the logged-query novelty, the key routing, the correctness fix, checks,
  sabotages, grep rows, RECOMMENDED NEXT → the PLAN.md ledger). Update §45's RECOMMENDED NEXT tail.
- Update the `run_core`/`core_log_action` header-comment migrated-verb lists (scheduler.c ~191/~1022).
- Decision doc: append one implementation-outcome line to its Status section.
- Issue 0068: add a dated note — the `#`/Ctrl+# legacy-switch keys now route/log via atom 26 (a
  PARTIAL close of the class; the §3 list's other keys remain).
- Memory: update the `action-logging` line in MEMORY.md (atom 26 done; next = PLAN.md item 02).
- PLAN.md ledger/receipt: owned by the pipeline's ledger stage — do NOT tick it yourself unless your
  driver instructs.

## CONSTRAINTS

- C89 throughout; allocations (none should be needed — the log forms are FIXED literals, do NOT
  introduce a heap argv array) would use `my_malloc`/`my_strdup` with the `_ALLOC_ID_` placeholder,
  never hand-numbered.
- Do NOT disturb the 25 migrated verbs or their tests/guards: trim_wires(1) align(2)
  rotate_in_place(3) flip_in_place(4) flipv_in_place(5) rotate(6) flip(7) flipv(8) break_wires(9)
  floaters_from_selected_inst(10) attach_labels(11) toggle_ignore(12) reset_inst_prop(13)
  replace_symbol(14) show_unconnected_pins(15) embed_rawfile(16) wire_cut(17) apply_pin_prop(18)
  move_instance(19) image(20) change_elem_order(21) reset_symbol(22) instance_number(23) delete(24)
  add_pin_stubs(25).
- Scope (the ONLY files you may edit): `src/scheduler.c`, `src/callback.c`,
  `tests/headless/test_perform_action_check_unique_names.tcl` (new),
  `tests/headless/test_selflog_grep_guard.tcl`, `tests/headless/full_audit.sh`, the four docs files
  named above, and `MEMORY.md`.
- ONE commit, explicit file list only. Message:
  `feat(action-log): route check_unique_names through perform_action boundary (Refactor B atom 26)`
  + a body in the atom-25 style (the asymmetric logged-query split, the key routing/0068 partial
  close, the read-only-rename correctness fix, behaviour deltas), ending with the atom-26 line and:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
