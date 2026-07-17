# 0120 — `incr_hilight_color` + `inst_name_text` silently vanish on no-cairo builds (over-broad `#if HAS_CAIRO` gate)

**Status:** OPEN
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

## Fix (sketch — NOT yet applied)

Narrow the guard to wrap ONLY the `image` branch: move the `#if HAS_CAIRO==1` down to just
before `else if(!strcmp(argv[1], "image"))`, keeping the `#endif` after it, so
`incr_hilight_color` and `inst_name_text` stay unconditional. Mind the else-if chain bridging on
BOTH configs — the existing `else` + `#endif` + `if(!strcmp(argv[1], "instance"))` idiom that
lets the chain resume after the gate must be preserved (on no-cairo the branch preceding `image`
becomes the last `else if`, and `instance` resumes as a fresh `if`, which is valid). Verify a
no-cairo preprocess (`gcc -E -DHAS_CAIRO=0`) leaves `xschem_cmds_i` brace-balanced and the chain
intact, and that `image` still compiles out cleanly (its lone `edit_image` reference must remain
inside the narrowed guard).

## Notes

- Discovered because atom 20 made `image` the FIRST verb whose `#if HAS_CAIRO` scope was audited
  by the review (audit §40). The review's HAS_CAIRO axis validated the block's brace balance but
  passed over the fact that the block also encloses two unrelated verbs — the critic caught it.
- Low urgency: the default/shipped builds have `HAS_CAIRO==1`, so this only bites a deliberately
  cairo-less build. But it is a genuine latent correctness defect (a feature silently missing on a
  supported build config), worth a narrow fix.
- Related: `doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` §40
  (the atom-20 write-up, which records this as a flagged out-of-scope follow-up).
