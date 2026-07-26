# 0120 — `incr_hilight_color` + `inst_name_text` silently vanish on no-cairo builds (over-broad `#if HAS_CAIRO` gate)

**Status:** CLOSED (fixed 2026-07-17)
**Area:** scheduler.c `xschem_cmds_i` dispatch group; `#if HAS_CAIRO==1` scope
**Found:** 2026-07-17, by the completeness critic during the Refactor B atom 20 (`image`) adversarial review — a PRE-EXISTING quirk, NOT introduced by atom 20 (present identically on HEAD before the atom).

## Symptom

On a build with `HAS_CAIRO==0` (config.h), two verbs that have **nothing to do with cairo**
become unavailable — `xschem <verb>` returns `xschem <verb>: invalid command.`:

- `xschem incr_hilight_color` — step the net-highlight style cursor forward one (the symmetric
  partner of `decr_hilight_color`; see `doc/claude/specs/hilight_style_decrement.md`).
- `xschem inst_name_text <inst>` — return the `<index> <size>` of an instance's `@lab` name text;
  drives the CTRL+Plus / CTRL+Minus text-size feature (`doc/claude/specs/text_size_scroll.md`).

So on a no-cairo build the net-highlight style increment and the instance text-size scroll
silently stop working (the callers get an error / no-op), with no diagnostic pointing at the cause.

## Root cause

In `src/scheduler.c`, `xschem_cmds_i` opens its dispatch chain with a single
`#if HAS_CAIRO==1` at the top of the function body (currently ~line 4749) whose matching
`#endif` (~line 4844) sits AFTER the `image` branch. That guard was meant to gate only the
`image` verb (its effect, `edit_image` in draw.c, is itself `#if HAS_CAIRO==1`). But because it
was placed at the chain START, it also encloses the two verbs that happen to sit before `image`
in the chain:

```
#if HAS_CAIRO==1                          /* ~4749  -- intended only for `image` */
    if(!strcmp(argv[1], "incr_hilight_color")) { ... }   /* ~4767  NOT cairo-dependent */
    else if(!strcmp(argv[1], "inst_name_text")) { ... }  /* ~4784  NOT cairo-dependent */
    else if(!strcmp(argv[1], "image")) { ... }           /* ~4813  genuinely cairo-only */
    else
#endif                                    /* ~4844 */
    /* instance ... */
    if(!strcmp(argv[1], "instance")) ...
```

On `HAS_CAIRO==0` the whole block (both innocent verbs + `image` + the bridging `else`) is
preprocessed away, so `incr_hilight_color` / `inst_name_text` fall through to the dispatcher's
`else { *cmd_found = 0; }` → the top-level `xschem()` reports "invalid command".

`incr_hilight_color()` (hilight.c) and `inst_name_text`'s body (`get_sym_text_size`, plain text
metrics) reference no cairo symbols, so there is no build reason to gate them.

## Fix (APPLIED — fix(scheduler), 2026-07-17)

Narrowed the guard to wrap ONLY the `image` branch. The gate now sits between the two innocent
verbs and `image`, so the dispatch chain is:

```
if(!strcmp(argv[1], "incr_hilight_color"))   { ... }   /* UNCONDITIONAL */
else if(!strcmp(argv[1], "inst_name_text"))  { ... }   /* UNCONDITIONAL */
#if HAS_CAIRO==1
/* image doc-comment moved down here with the gate */
else if(!strcmp(argv[1], "image"))           { ... return perform_action("image", argc, argv); }
#endif
else if(!strcmp(argv[1], "instance"))        { ... }   /* was a bare `if` -> now `else if` */
```

Concrete edits to `src/scheduler.c`:
1. Removed the `#if HAS_CAIRO==1` from the top of the function body and relocated the `image`
   doc-comment block down with it.
2. Inserted `#if HAS_CAIRO==1` (+ the relocated doc-comment) immediately before
   `else if(!strcmp(argv[1], "image"))`.
3. Dropped the dangling `else` that used to precede `#endif`; the `#endif` now sits directly after
   the `image` branch's closing `}`.
4. Promoted `if(!strcmp(argv[1], "instance"))` to `else if(...)` so the else-if chain bridges the
   gate correctly.

### The else-if-chain hazard (handled)

The chain must be valid in BOTH preprocessor configs (the atom-20 grep-guard "chains stay
brace-balanced across `#if`" lesson):

- **CAIRO:**    `if(incr) / else if(inst_name) / else if(image) / else if(instance) / else if(instance_bbox) / ...`  ✓
- **NO-CAIRO:** `if(incr) / else if(inst_name) / else if(instance) / else if(instance_bbox) / ...`  ✓

No `else if` is ever left without a preceding `if`, and there are never two sibling `if`s. Promoting
`instance` to `else if` is required: on no-cairo it now attaches to `inst_name_text`; on cairo it
attaches to `image`. Behavior is identical either way (the verb strings are mutually exclusive).

### Verification

- **CAIRO build** (`make xschem`, default `HAS_CAIRO==1`): compiles + links; headless drive confirms
  `xschem incr_hilight_color` → `1`, `xschem inst_name_text <lab>` → `0 0.33`, `xschem image help` →
  usage string. `test_perform_action_image.tcl` and `test_selflog_grep_guard.tcl` still PASS (the
  atom-20 `image` migration is untouched).
- **NO-CAIRO build** (config.h `#define HAS_CAIRO 0`, full rebuild): **compiles + links clean**;
  `xschem incr_hilight_color` → `1` and `xschem inst_name_text <lab>` → `0 0.33` (the regression is
  FIXED — both work), while `xschem image ...` reports `xschem image: invalid command.` gracefully
  (cmd_found=0 fall-through, no crash). `test_perform_action_image.tcl` defers on the no-cairo signal
  → ALL PASS.
- **Sabotage check** (green-but-hollow guard): the PRE-fix `scheduler.c` on a no-cairo build was
  rebuilt and confirmed to LOSE both verbs (`xschem incr_hilight_color: invalid command.`), proving
  the fix genuinely changes no-cairo behavior.

### Regression lock

`tests/headless/test_noncairo_verbs_ungated.tcl` (auto-discovered by `full_audit.sh`):
- **(S) structural fail-closed grep guard** — scans `src/scheduler.c` and asserts the
  `#if HAS_CAIRO==1` in `xschem_cmds_i` sits AFTER both non-cairo verb branches and encloses ONLY
  `image` (`incr < #if`, `inst_name < #if`, `#if < image < #endif`, exactly one `#if`/`#endif`
  pair). This runs on ANY build config, so a future re-widening of the gate fails the test even in a
  cairo CI where the verbs would otherwise still resolve.
- **(F) functional reachability** — drives both verbs on the running binary and asserts their
  documented return shapes; the `image` sub-check accepts either the cairo usage string or the
  no-cairo graceful `invalid command`.

## Notes

- Discovered because atom 20 made `image` the FIRST verb whose `#if HAS_CAIRO` scope was audited
  by the review (audit §40). The review's HAS_CAIRO axis validated the block's brace balance but
  passed over the fact that the block also encloses two unrelated verbs — the critic caught it.
- Low urgency: the default/shipped builds have `HAS_CAIRO==1`, so this only bites a deliberately
  cairo-less build. But it is a genuine latent correctness defect (a feature silently missing on a
  supported build config), worth a narrow fix.
- Related: `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` §40
  (the atom-20 write-up, which records this as a flagged out-of-scope follow-up).
