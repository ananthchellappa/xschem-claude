# Issue 0076 — Dispatcher `argv[]`-safety audit (unguarded `argv[n]` reads that crash on a short command)

**Opened:** 2026-07-04
**Status:** FIXED (2026-07-04) — the audit found the `xschem()` dispatcher is, with two
exceptions, already well-guarded. Exactly **one** additional crash of the issue-0075 class
was found and fixed (`xschem callback`, `src/scheduler.c:763`); two genuinely-unguarded but
**non-crashing** reads were confirmed and are documented below as low priority. A blanket
`ARG()`/`NEED()` macro sweep was considered and **rejected on the evidence** — see §5.
**Severity:** HIGH for the one confirmed crash (a mistyped/short `xschem callback` kills the
whole editor, exactly as 0075); the two benign findings are cosmetic.
**Branch:** `fluid-editing`.
**Motivation:** issue 0075 fixed one unguarded `atof(argv[n])` crash (`select_inside`). The
open question was whether that was an isolated slip or one instance of a systemic pattern
across the ~250 `atof(argv[/atoi(argv[` sites in `src/scheduler.c`. This issue is the
systematic answer.
**Affects:** `src/scheduler.c` — the `xschem()` command dispatcher and its
`xschem_cmds_a…z` group functions.

---

## 1. Method

A 14-way parallel audit (one agent per `xschem_cmds_*` group, covering the full dispatcher
`scheduler.c:187-9640`), followed by an adversarial verify pass that re-read each
crash-class finding's full branch to confirm no guard actually covered it, then a synthesis
pass. Every finding carries `file:line`. For each read of `argv[k]` (k ≥ 2, the args after
the `argv[1]` subcommand name) the audit determined whether the branch guarantees
`argc > k` before the read — via an early `if(argc < N) return`, a wrapping `if(argc > k)`,
a short-circuit `argc > k && argv[k]…`, or a prior established read.

## 2. Result — the dispatcher is well-guarded

| | count |
|---|---|
| Dispatcher groups audited | 14 (all of `a`…`z`) |
| Total residual unguarded reads found | **3** |
| Confirmed **crash** class (NULL-deref) | **1** (`callback`) |
| Confirmed benign (unguarded but cannot crash) | 2 (`setprop symbol`, `zoom_box` dbg) |
| False positives (a guard did cover it) | 0 |

Per-group residual count: `a`0 · `b+c`1 · `d+e`0 · `f`0 · `g`0 · `h`0 · `i`0 · `l`0 ·
`m+n`0 · `o+p`0 · `r`0 · `s`1 · `t+u`0 · `v+w+x+z`1.

The headline: **the overwhelming majority of the ~250 `atof/atoi(argv[])` sites are already
guarded** (explicit `argc<N` floors, `if(argc>k)` wrappers, short-circuits, or loop bounds
`for(i=2;i<argc;…)`). `select_inside` (0075) and `callback` (this issue) were the only two
genuine crash-class gaps in the whole dispatcher.

## 3. The one confirmed crash — `xschem callback` (FIXED)

```c
/* src/scheduler.c:760  — BEFORE */
if(!strcmp(argv[1], "callback") )
{
  if(!xctx) { ... return TCL_ERROR; }
  callback( argv[2], atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), (KeySym)atol(argv[6]),
           atoi(argv[7]), atoi(argv[8]), atoi(argv[9]) );   /* no argc guard */
  ...
}
```

`callback` needs `win_path event mx my key button aux state` = `argv[2..9]`, i.e.
`argc >= 10`. With no guard, `xschem callback` (argc 2) passes `argv[2] == NULL` as
`win_path` into `callback()`, which dereferences it (window-path lookup) → SIGSEGV →
`sig_handler` emergency-save → the whole editor dies. Same crash chain as 0075.

**Fix applied** — `argc < 10` guard before the reads:

```c
if(argc < 10) {
  Tcl_SetResult(interp,
    "xschem callback: usage: callback win_path event mx my key button aux state", TCL_STATIC);
  return TCL_ERROR;
}
```

Verified RED→GREEN with sabotage: reverting the guard and rebuilding reproduced
`EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_*` on `xschem callback`; with the
guard the command returns the usage string and the process survives. Regression:
`tests/headless/test_callback_argc.tcl` (5 checks, argc 2–9, registered in
`run_regression.tcl` `hcases`).

## 4. The two benign findings (documented, low priority, NOT patched)

Both are genuinely unguarded reads that reach a `NULL` `argv[k]`, but neither can SIGSEGV,
so they are left as-is to keep this change tight. Recorded here so they are not re-flagged.

1. **`setprop symbol` — `src/scheduler.c:8334`.** The `symbol` arm guards only `argc < 4`
   (guarantees `argc >= 4`, not `> 4`), and the `else` of `if(argc > 5)` calls
   `subst_token(sym->prop_ptr, argv[4], NULL)` with no `argc > 4` guard — so
   `xschem setprop symbol <name>` (argc 4) passes `argv[4] == NULL`. **Not a crash:**
   `subst_token` (`token.c:1253`) treats `tok == NULL` as "return a copy of `s`" (NULL-safe).
   The sibling `instance` arm wraps the identical read in `else if(argc > 4)`, so this is an
   inconsistency, not a bug. A one-line `argc > 4` guard would restore symmetry if desired.
2. **`zoom_box` — `src/scheduler.c:9556`.** `argv[2]` is passed to a `dbg(1, "…%s…", argv[2])`
   *before* the `if(argc == 6 || argc == 7)` test. On `xschem zoom_box` (argc 2)
   `argv[2] == NULL`, but `dbg()` only reaches `vfprintf` when `debug_var >= 1` (default 0),
   and `vfprintf` renders a `NULL` `%s` as `"(null)"` rather than crashing on the target
   platforms. All the real numeric reads (`atof(argv[2..6])`) are properly guarded by
   `argc == 6 || argc == 7`. Harmless.

## 5. Why no `ARG()`/`NEED()` macro sweep (evidence-based de-scoping)

The pre-audit hypothesis was that ~250 `atof/atoi(argv[])` sites might each be a latent
crash, justifying a structural fix — a safe accessor `#define ARG(i) ((i)<argc && argv[i] ?
argv[i] : "")` swept across the dispatcher so a short command defaults instead of
NULL-dereferencing. **The audit refutes the premise:** the dispatcher is already guarded
almost everywhere (0 false positives, only 1 residual crash across 14 groups). A blanket
sweep would therefore:

- touch hundreds of already-correct sites for ~one real bug (poor risk/reward),
- silently convert *usage errors* into *silent defaults* (`atof("")` = 0), changing the
  error contract of many commands and masking future genuinely-missing-argument bugs,
- be far higher review/regression surface than the two targeted guards.

**Conclusion:** targeted per-branch guards (as in 0075 and §3) are the right tool here, not
a structural rewrite. The class is not systemic. If a *new* dispatcher branch is added, the
existing convention (an `if(argc < N)` floor before indexing `argv`) is the pattern to
follow — see the many examples the audit confirmed (e.g. `apply_properties` `argc < 6`,
`get_tok` `argc < 4`, `getprop` `argc < 3`).

## 6. Regression

`tests/headless/test_callback_argc.tcl` — asserts every short `xschem callback` (argc 2–9)
returns a Tcl error (not a crash) and pins the usage message. Complements
`tests/headless/test_select_inside_argc.tcl` (0075). Both rely on the harness scoring a
process-crash as FAIL (a SIGSEGV kills the run before the `OVERALL: ok` sentinel).

## 7. Related
- Issue **0075** — the exemplar crash (`select_inside`) that motivated this audit.
- `doc/claude/code_analysis/object_model_agent_reference.md` §9 — defect D1 (unchecked
  `atoi` on `getprop wire`/`rect`); note the audit found those two `getprop` reads ARE
  bounds-checked against `argc` (`argc < 5` floor), so D1's concern is the *value* range
  (an in-range-but-nonexistent index), a different, non-crashing class than this issue's
  NULL-deref — worth a separate follow-up if value-range hardening is wanted.
