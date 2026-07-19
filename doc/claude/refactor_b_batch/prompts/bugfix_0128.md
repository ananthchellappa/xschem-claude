# Bugfix implement prompt — issue 0128: menu "Edit with editor" (`xschem edit_vi_prop`) edits a read-only cell

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
Issue file: doc/claude/issues/0128-edit-vi-prop-menu-readonly-gap.md
Scout receipt (batch item 29): doc/claude/refactor_b_batch/receipts/29_edit_vi_prop.md
Plan: doc/claude/refactor_b_batch/BUGFIX_PLAN.md item 2.
Sibling precedent (mirror its shape): bugfix 0126, commit cdb9636d
(prompts/bugfix_0126.md, tests/headless/test_apply_properties_readonly.tcl).

## Bug (re-confirmed LIVE 2026-07-18 by the scout, both display modes)

The scheduler `edit_vi_prop` branch carries only the `!xctx` guard — no readonly gate. Live
repro on Q1.sch with the current binary:

- No X (`--nogui`, DISPLAY unset): `xschem set readonly 1; xschem edit_vi_prop` → rc=0, no
  refusal (the mutation path is dead only because `edit_property` returns at `!has_x`).
- WITH X (DISPLAY=:0, the user's WSLg mode, also full_audit's default runner mode): same call
  → rc=0, the editor Tcl proc WAS invoked, and `xctx->schprop` WAS MUTATED on the read-only
  buffer — with `modified` still 0 (`set_modify`'s ro_suppress hides the flag, the same
  silent-corruption aggravator as 0126) and a spurious `push_undo` slot (the global arm pushes
  before the strdup).

Asymmetry: both raw keyboard entries are correctly gated — legacy `Q` key
(callback.c `case 'Q':` at 5652, `readonly_block()` at 5655, intent comment ~5633-5634 "'Q' =
edit-with-editor stays an explicit edit and keeps its readonly_block") and verb-noun numeric
case 11 (gated by the `readonly_block()` switch at callback.c:3193-3198, `edit_property(1)` at
3263-3265). Only the menu/scripted verb leaks: menu xschem.tcl:14363
(`-command "xschem edit_vi_prop"`, Shift+Q accelerator label) and actions.csv:111.

## ANCHORS (all re-verified from source 2026-07-18 — re-verify again before editing, lines drift)

- src/scheduler.c:2999-3008 — the `edit_vi_prop` branch, inside `xschem_cmds_e`
  (scheduler.c:2955; letter-dispatch: this is the right group, do not relocate):
  - 3003 `else if(!strcmp(argv[1], "edit_vi_prop"))`
  - 3005 `if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}`
  - 3006 `edit_property(1);`
  - 3007 `Tcl_ResetResult(interp);`
  Single argc form, no argc validation, result deliberately reset — NO consumer of the result
  anywhere (verified: the only issuers of the verb are the menu and actions.csv row; the
  editprop.c `edit_vi_prop` references at 285/711/1195/1465 are the Tcl PROC, not this verb).
- src/scheduler.c:173-185 — `static int scheduler_readonly_reject(Tcl_Interp *interp, const
  char *subcmd)`; returns 1 with interp error `"xschem <subcmd>: schematic is read-only ..."`
  + CIW echo; call AFTER the `!xctx` check (contract comment 166-172). Convention siblings:
  setprop 10260, wire 11684, 0126's apply_properties 1598.
- Menu-path TCL_ERROR is established shipped behavior: Edit>Cut / Edit>Paste menus
  (xschem.tcl:14212-14213) and toolbar (12713/12715) call gated verbs (`cut` gate at
  scheduler.c:2707, `paste` at 7619) the same way since issue 0041 — no new consumer risk.
- src/editprop.c — `edit_property(int x)` at 1404; `if(!has_x) return;` at ~1410 (so headless
  no-X the verb is a no-op after the gate check — no blocking ever). Global arm (lastsel==0,
  x==1): presets `tctx::retval`, `tcleval("edit_vi_prop {Global schematic property:}")` at
  1465; on `tctx::rcode` non-empty, per-netlist-type mutation with `xctx->push_undo()` BEFORE
  the strdup (~1481-1520; spice → `xctx->schprop`); self-log `xschem set sch<X>prop` at
  1531-1547; `if(modified) set_modify(1);` at 1529 (ro_suppress hides it when readonly).
- src/xschem.tcl:9546 — `proc edit_vi_prop {txtlabel}`: the editor exec seam. Redefining this
  proc in the test interp fully stubs the external editor (scout-proven live: stub ran, schprop
  mutated, zero external processes). Contract the stub must honor: read `$tctx::retval`, write
  new content back to `tctx::retval`, set `tctx::rcode ok` (or `{}` for "unchanged/cancel").
- Default netlist_type is spice → the mutated/readable field is `xschem get schprop`
  (scheduler.c:4091-4093) / self-log form `xschem set schprop` (10124-10126).
- `xschem set readonly 0|1` (scheduler.c:10055), `xschem get readonly` (4043),
  `xschem get modified`, `xschem set_modify 0` (there is NO `xschem set modified` — 0126
  lesson).
- Tk-presence probe for the test: `info commands winfo` is non-empty iff has_x (main.c:94
  `has_x = xserver_ok()`, 148 `if(has_x) Tk_Main(...) else Tcl_Main(...)`). Scout-verified:
  empty under `--nogui`/no DISPLAY, `winfo` under DISPLAY=:0.
- tests/headless/test_readonly_guard.tcl — issue-0041 guard suite; `cmds` list at ~44-49
  (currently ends `... setprop replace_symbol apply_properties`); loop does `xschem
  select_all` then calls each verb BARE on a readonly buffer, requires rc!=0 + `*read-only*`
  message. full_audit runs it with the DEFAULT runner (NOT in nogui_tests), pass banner
  `READONLY_GUARD_TEST_PASS` (full_audit.sh:83); standalone runner
  tests/headless/test_readonly_guard.sh.
  HAZARD: under DISPLAY, on an UNFIXED/sabotaged binary, a bare `edit_vi_prop` with a
  selection reaches the REAL editor proc → external `$editor` exec → hang-to-timeout. The
  guard suite therefore ALSO gets a one-line inert stub (see EDITS 3).
- tests/headless/full_audit.sh — auto-discovers tests/headless/test_*.tcl; default runner
  `--pipe -q --nolog --script <file>` from repo root; default pass banner `RESULT: ALL PASS`.

## EDITS (exact scope — nothing else)

1. src/scheduler.c, `edit_vi_prop` branch: insert ONE line between the `!xctx` check (3005)
   and `edit_property(1)` (3006):

   ```c
   if(scheduler_readonly_reject(interp, "edit_vi_prop")) return TCL_ERROR;
   ```

   No new declarations (C89 untouched), no allocations, no log site (the refusal must log
   nothing; the core's `set sch<X>prop` / setprop self-logs fire only on an applied edit,
   which the gate now prevents). Rebuild: `cd src && make`.

2. NEW test file tests/headless/test_edit_vi_prop_readonly.tcl (auto-discovered by
   full_audit default runner; own process; run from repo root; per-check `ok:`/`FAIL:` lines
   and final `RESULT: ALL PASS` / `RESULT: N FAILED` + matching exit code — copy the shape of
   tests/headless/test_apply_properties_readonly.tcl).

3. tests/headless/test_readonly_guard.tcl: add `edit_vi_prop` to the `cmds` list (refused
   count auto-adjusts via `[llength $cmds]`), AND — before the treatment loop — define the
   inert editor stub so a red/sabotaged binary can never exec a real editor:

   ```tcl
   # edit_vi_prop reaches an external $editor exec if the readonly gate is absent
   # (red-first / sabotage runs under X) — stub it inert: rcode {} = "unchanged".
   proc edit_vi_prop {txtlabel} { set tctx::rcode {}; return {} }
   ```

## TEST PLAN (tests/headless/test_edit_vi_prop_readonly.tcl)

Fixture: `$REPO/xschem_library/examples/Q1.sch` (never saved; all checks in-memory; derive
$REPO from the script location like test_readonly_guard.tcl). Use the GLOBAL-prop arm: load,
then `xschem unselect_all` so lastsel==0 → the schprop path (no instance-id bookkeeping).

FIRST LINES of the script (before any `xschem edit_vi_prop` call — this is the no-blocking
guarantee): the witness stub

```tcl
set ::evp_calls 0
proc edit_vi_prop {txtlabel} {
  incr ::evp_calls
  set tctx::retval "$tctx::retval\n** stub_edit **"
  set tctx::rcode ok
  return ok
}
```

Then `set has_gui [expr {[info commands winfo] ne {}}]`. The mutation-side checks are
GUI-conditional (edit_property no-ops at `!has_x`); print `skip:` for them when !has_gui so
the file still passes under xvfb-less CI. The refusal checks (EVP3/EVP4) run UNCONDITIONALLY
— the gate is in the scheduler, before edit_property. In the user's audit environment
(DISPLAY=:0) ALL checks run; record which mode your verification ran in.

Sequence (adapt freely, keep check SEMANTICS and names):

```tcl
xschem load $sch ; xschem unselect_all
set orig [xschem get schprop]
# EVP1 (control, editable path unchanged): rc==0; if has_gui also: stub called once,
#   schprop now contains "stub_edit", modified==1.
set rc1 [catch {xschem edit_vi_prop} r1]
# EVP2 (control, undo unchanged, has_gui only): xschem undo -> schprop eq $orig
#   (global arm pushes undo BEFORE the strdup).
# EVP5-setup (has_gui only): one more stubbed edit so the undo head is a REAL edit;
#   then xschem set_modify 0
xschem set readonly 1
set ::evp_calls 0
# EVP3 (the bug): catch {xschem edit_vi_prop} -> rc==1, msg non-empty, matches *read-only*.
# EVP4 (gate fires BEFORE the editor): ::evp_calls == 0 (editor never launched),
#   schprop unchanged since the gate, modified stays 0.
# EVP5 (no spurious undo slot, has_gui only): xschem set readonly 0; xschem undo
#   -> schprop back to the pre-second-edit value (refusal pushed nothing).
```

RED FIRST: run the new file against the UNFIXED binary WITH DISPLAY — EVP3, EVP4 (and EVP5)
must FAIL, and specifically EVP4's witness must show ::evp_calls==1 + mutated schprop on a
readonly buffer (the recorded corruption). test_readonly_guard with the new entry must also
go red on exactly the edit_vi_prop row (+ refused count) — this red-first run doubles as the
guard-membership witness (there is no argc arm here to build a 0126-style SB-E around). Then
apply edit 1, rebuild, re-run: all green.

### Sabotage verification

(Each: apply to src/scheduler.c only, rebuild, run the new file, confirm the TARGET check
fails; the fix is uncommitted, so revert by re-editing back to the exact fixed text, then
`git diff src/scheduler.c` must show ONLY the one-line gate. After ALL sabotages: one clean
rebuild + full green re-run of both test files. Run sabotages WITH DISPLAY so the mutation
arms are live.)

- SB-A -> targets EVP1 (over-reject guard). Gate line becomes
  `if(scheduler_readonly_reject(interp, "edit_vi_prop") || 1) return TCL_ERROR;`
  Editable call now refused -> EVP1 fails (rc!=0); EVP3/EVP4 stay green. (EVP2/EVP5-setup
  cascade from the same refusal — record; primary witness EVP1.)
- SB-B -> targets EVP3. Swallow the refusal:
  `if(scheduler_readonly_reject(interp, "edit_vi_prop")) { Tcl_ResetResult(interp); return TCL_OK; }`
  rc becomes 0 -> EVP3 fails; the gate still returned before edit_property so EVP4 stays
  green; controls green. Exactly EVP3.
- SB-C -> targets EVP4. Move the gate call to AFTER `edit_property(1)` (before
  Tcl_ResetResult). Readonly call now launches the stub AND mutates schprop, then errors ->
  EVP3 passes (rc+msg), EVP4 fails (::evp_calls==1, schprop mutated). EXPECTED COLLATERAL:
  EVP5 fails too (the global arm's push_undo ran) — same causal event, record both; primary
  witness EVP4.
- SB-D -> targets EVP5. Insert a stray `xctx->push_undo();` immediately BEFORE the gate line.
  Refusal stays clean (EVP3/EVP4 green; editable controls tolerate the extra push because
  EVP2 undoes the LAST slot), but the spurious slot makes EVP5's single undo restore the
  wrong state -> exactly EVP5 fails.

### Suite gates

- tests/headless/full_audit.sh — NO new failures beyond the recorded batch baseline
  (PLAN.md header, 2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag,
  test_ciw, test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui,
  test_lib_sweep, test_phase3_mints, test_reopen_readonly, test_save_as_cellview,
  test_select_at, test_selflog_output, test_untitled_reuse, test_wire_split.
  (test_fluid_editing passed at batch start despite the ~14 expectation note; 0126's verify
  saw it flake under congestion but pass in isolation — same allowance applies.) The new
  test_edit_vi_prop_readonly and test_readonly_guard must be PASS.

## DOCS

- doc/claude/issues/0128-edit-vi-prop-menu-readonly-gap.md: Status OPEN -> FIXED (date +
  commit hash) + a "What changed" section: the one-line gate + placement (after !xctx, before
  edit_property, xschem_cmds_e), the LIVE-repro facts (readonly rc=0, editor invoked, schprop
  mutated, modified suppressed by ro_suppress, spurious undo slot), and that the keyboard
  paths were already gated (asymmetry closed). Residual: none — the boundary migration stays
  DEFERRED per receipt 29, independent of this gate.
- doc/claude/refactor_b_batch/BUGFIX_PLAN.md: ledger item 2 `[ ]` -> `[x]` + one-line
  outcome + receipt line, unless the driver pipeline owns the ledger stage — then leave it
  and say so.
- Memory (per discipline): per-item detail goes into the batch block of
  /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/action-logging.md;
  the MEMORY.md action-logging index line stays ONE short line (append "bugfix 0128 done"
  style, terse).

## COMMIT

Explicit file list ONLY (never -a / -A):
  src/scheduler.c
  tests/headless/test_edit_vi_prop_readonly.tcl
  tests/headless/test_readonly_guard.tcl
  doc/claude/issues/0128-edit-vi-prop-menu-readonly-gap.md
  doc/claude/refactor_b_batch/BUGFIX_PLAN.md   (only if edited)

Message:

```
fix(readonly): reject scripted/menu edit_vi_prop on read-only buffer (issue 0128)

The edit_vi_prop scheduler branch had no readonly gate: the Properties >
"Edit with editor" menu (and any scripted/CIW/replay call) launched the
external editor and APPLIED the edit on a read-only cell — silently
(set_modify's ro_suppress hid the modified flag) and with a spurious
push_undo slot. Both keyboard entries (Q key, verb-noun 11) were already
gated via readonly_block; this closes the asymmetry with one
scheduler_readonly_reject at the branch top, per the setprop/wire/
apply_properties (0126) convention. No consumer of the branch result
exists; menu TCL_ERROR on refusal matches the shipped Cut/Paste behavior.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

Do NOT push. Do not touch junk dirs (_nhangle_* etc.) or any file outside the list above.
