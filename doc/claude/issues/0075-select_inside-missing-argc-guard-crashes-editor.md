# Issue 0075 — `xschem select_inside` with too few args crashes the whole editor (NULL `atof`, SIGSEGV → emergency save)

**Opened:** 2026-07-04
**Status:** FIXED (2026-07-04) — argc guard added at `src/scheduler.c:7692`; see **§8
Resolution**. Root cause was verified by sabotage: reverting the guard and rebuilding
reproduced the exact crash (`EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_*`).
Regression `tests/headless/test_select_inside_argc.tcl` added (8 checks). The broader
`argv`-safety audit is deferred to a follow-up issue (see §5 optional hardening).
**Severity:** HIGH — a single mistyped command in the CIW kills the entire process: every
open window/tab vanishes and any unsaved edits are lost (recoverable only from the
`xschem_emergencysave_*` undo-dir dump). A read-only-looking *query* typo should never be
able to crash the editor. Trivremely easy to hit by tab-completion (see §2).
**Branch:** `fluid-editing`.
**Source:** user report — launched `src/xschem --script src/cadence_style_rc --logdir /tmp`,
opened a schematic via the Library Manager, then typed `xschem select_inside x1` in the CIW
(intending `xschem select instance x1`; reached `select_inside` by tab-completing
`xschem select_in…`). All windows disappeared; a new dir
`/tmp/xschem_emergencysave_test_hier_descend_etc_<rand>` appeared.
**Affects:** the `select_inside` branch of the `xschem` dispatcher,
`src/scheduler.c:7692-7704`.

---

## 1. Symptom

```
xschem select_inside x1
```

→ process dies instantly. All top-level windows close. In the tmp dir a
`xschem_emergencysave_<schematic>_<random>` directory is created (the crashed session's
undo dump, renamed by the signal handler).

## 2. Why it is so easy to trigger

The intended command to select an instance by name is:

```tcl
xschem select instance x1     ;# correct
```

But `xschem select_in…`<TAB> completes to `select_inside` (a different, area-select
command that takes **four numeric coordinates** `x1 y1 x2 y2`), not to any
`select_instance` (no such subcommand exists — the reader mistook `select_inside` for it).
The user then supplies a single bareword `x1` (an instance *name*), and the command
crashes instead of reporting a usage error.

## 3. Root cause — missing argument-count guard → `atof(NULL)`

The `select_inside` branch reads `argv[2..5]` with **no `argc` check**:

```c
/* src/scheduler.c:7692 */
else if(!strcmp(argv[1], "select_inside"))
{
  int sel = SELECTED;
  double x1, y1, x2, y2;
  if(!xctx) { ... return TCL_ERROR; }
  if(argc > 6 && argv[6][0] == '0') sel = 0;
  x1 = atof(argv[2]);      /* "x1"  -> 0.0, harmless */
  y1 = atof(argv[3]);      /* <-- argc==3, so argv[3] == NULL  =>  atof(NULL) */
  x2 = atof(argv[4]);
  y2 = atof(argv[5]);
  select_inside(tclgetboolvar("enable_stretch"), x1, y1, x2, y2, sel);
  Tcl_ResetResult(interp);
}
```

For `xschem select_inside x1`, `argc == 3` (`argv[0]="xschem"`, `argv[1]="select_inside"`,
`argv[2]="x1"`). Tcl's classic string-command contract guarantees `argv[argc] == NULL`, so:

- `atof(argv[2])` parses `"x1"` → `0.0` (no crash — `atof` stops at the first non-numeric
  char).
- `atof(argv[3])` is **`atof(NULL)`**. glibc `atof` calls `strtod(NULL, …)`, which
  dereferences the NULL pointer → **SIGSEGV**. (`argv[4]`/`argv[5]` are past the NULL
  terminator and would be genuine out-of-bounds reads, but the crash happens at `argv[3]`
  first.)

Every sibling `select`-family branch guards its argument count — e.g. plain
`xschem select` returns `"xschem select: missing arguments."` on short argc
(`scheduler.c:7485-7496`). The `select_inside` branch simply omits that guard. It is the
same defect **class** as D1 in `doc/claude/code_analysis/object_model_agent_reference.md`
(unchecked `atoi` on `getprop wire`/`getprop rect`), here made lethal because the bad read
is a NULL deref rather than a stray in-range index.

## 4. Crash chain (why the whole app dies, not just the command)

1. `atof(NULL)` in the `select_inside` branch → SIGSEGV.
2. `main.c:82` installed `signal(SIGSEGV, sig_handler)`.
3. `sig_handler` runs the emergency-save path: it renames the live undo dir
   (`xctx->undo_dirname`) to `xschem_emergencysave_<sanitized-schematic-name>_<rand>` under
   the tmp dir (`main.c:42-52`) and prints `EMERGENCY SAVE DIR: …`.
4. The process then terminates — so every window/tab of that single `xschem` process closes
   at once. This matches the reported
   `xschem_emergencysave_test_hier_descend_etc_dedegcebdc`.

So the emergency-save dir is not a corruption — it is the crash handler doing its job. The
bug is that a user typo reached a NULL deref at all.

## 5. Proposed fix

Add the missing `argc` guard at the top of the branch, mirroring the plain `select` branch.
`select_inside` needs `x1 y1 x2 y2`, i.e. `argc >= 6` (`argv[0]`=`xschem`,
`argv[1]`=`select_inside`, `argv[2..5]`=coords; optional `argv[6]`=`0` to deselect).

```c
else if(!strcmp(argv[1], "select_inside"))
{
  int sel = SELECTED;
  double x1, y1, x2, y2;
  if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
  if(argc < 6) {                                 /* <-- NEW: guard before atof */
    Tcl_SetResult(interp,
      "xschem select_inside: usage: select_inside x1 y1 x2 y2 [0]", TCL_STATIC);
    return TCL_ERROR;
  }
  if(argc > 6 && argv[6][0] == '0') sel = 0;
  x1 = atof(argv[2]);
  y1 = atof(argv[3]);
  x2 = atof(argv[4]);
  y2 = atof(argv[5]);
  select_inside(tclgetboolvar("enable_stretch"), x1, y1, x2, y2, sel);
  Tcl_ResetResult(interp);
}
```

This turns the crash into a clean, replay-safe error message. After the fix,
`xschem select_inside x1` returns the usage string and the editor stays alive.

### Optional hardening (separate, lower priority)
- Validate the four coords with `strtod`'s `endptr` (reject non-numeric args like the
  bareword `x1`) so `select_inside x1 y1 x2 y2` (four *names*) also errors instead of
  silently area-selecting the degenerate box at `(0,0)-(0,0)`.
- Because this is a whole-editor crash from one bad query, it is worth a one-pass **audit**
  of every `xschem` sub-branch that indexes `argv[n]` / calls `atof(argv[n])`/`atoi(argv[n])`
  without a preceding `argc` check (D1 is one confirmed instance; grep
  `atof(argv[` / `atoi(argv[` in `scheduler.c` and cross-check the guard). A NULL-deref from
  a mistyped command should be impossible anywhere in the dispatcher.

## 6. Suggested regression

Headless, must NOT crash the interpreter:

```tcl
# expect a TCL error string, not a SIGSEGV
if {![catch {xschem select_inside x1} msg]} {
  puts "FAIL: select_inside with too few args did not error"
} elseif {![string match {*select_inside*} $msg]} {
  puts "FAIL: unexpected error: $msg"
} else {
  puts "PASS: select_inside short-argc returns a usage error"
}
# also exercise the correct 4-arg form still works
xschem select_inside 0 0 1000 1000
```

## 8. Resolution

Applied the §5 guard verbatim at `src/scheduler.c:7692` (returns a usage error when
`argc < 6`, before any `atof(argv[…])`).

Verification (RED→GREEN, sabotage-checked per the green-but-hollow discipline):

- **RED** — with the guard reverted and the binary rebuilt,
  `xschem select_inside x1` (headless) crashed: the log printed
  `EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_dccgbagdag` and the script never
  reached its final line — reproducing the reported failure exactly.
- **GREEN** — with the guard in place, the same command returns
  `xschem select_inside: usage: select_inside x1 y1 x2 y2 [0]` and the process stays alive.
- **Regression** — `tests/headless/test_select_inside_argc.tcl` (registered in
  `run_regression.tcl` `hcases`): 8 checks pass (`OVERALL: ok`). It exercises every
  short-argc form (argc 2–5, including the reported `select_inside x1`), asserts each
  returns a Tcl error rather than crashing, pins the usage message, and confirms the valid
  4-/5-arg forms still work. Because a crash on any form kills the process before the
  `OVERALL: ok` sentinel, the harness scores a crash as FAIL automatically.
- All five pre-existing headless cases plus this new one pass when driven by the built
  `src/xschem` (all `OVERALL: ok`); the golden `tcases` show no FAIL. (Note: the top-level
  `run_regression.tcl` run marks headless cases FAIL only because `xschem_cmd` is `"xschem"`
  from `$PATH` and no `xschem` is installed in this tree — an environment artifact affecting
  every headless case equally, not this change.)

## 7. Related
- `doc/claude/code_analysis/object_model_agent_reference.md` — §9 defect D1 (same
  unchecked-`argv` class on `getprop wire`/`getprop rect`), §6 the correct
  `xschem select instance <name>` grammar the user actually wanted.
- The correct command for the user's intent: `xschem select instance x1` (`scheduler.c:7505`).
