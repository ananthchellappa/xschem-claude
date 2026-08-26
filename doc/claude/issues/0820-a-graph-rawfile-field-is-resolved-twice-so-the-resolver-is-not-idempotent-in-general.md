# 0820 — a graph `%` rawfile field is resolved TWICE, so resolve_rawfile_path() is not idempotent in general, and read/clear can disagree about a registry key

Status: **measured, comments corrected, behaviour deliberately left unchanged (it is
identical to HEAD before the 0812 fix). No shipped spelling reaches it.**
Found by the 0812-retry adversary pass, after commit 3ab11016 landed.
Severity: low. No execution, no data loss — a silent "clear does nothing".
Family: 0812.

## 1. The claim that was shipped, and is false

`src/util.c`, above `resolve_rawfile_path()`, said:

> It is IDEMPOTENT on its own output, which the registry needs because scheduler.c's
> annotate_op branch feeds an already-resolved xctx->raw->rawfile back through the clear
> arm: the output carries no leading `~/`, and **a `$` that survives to the output survived
> by being UNRESOLVABLE, so the second pass leaves it alone too.** The one residual … if
> that variable becomes DEFINED between the two calls, the second resolution differs.

`src/draw.c` leaned on it to justify rewiring both `%` fields:

> the rawfile field is resolved AGAIN by extra_rawfile() downstream, and **that double
> pass is only safe because resolve_rawfile_path() is idempotent on its own output.**

The premise is wrong. A `$` also reaches the output when a **defined** variable's VALUE
contains one — because a value is appended verbatim and *never rescanned*, which is the
safety property itself. No undefined→defined race is needed.

## 2. Measurement

Single-pass non-rescan, on the fixed binary:

```
  set ::lvl1 $D/plain.raw
  set ::lvl2 {$lvl1}                       ;# the literal text $lvl1
  xschem raw read {$lvl2} tran
  ->  raw_read(): failed to open file $lvl1 for reading
```

`$lvl2` resolved to `$lvl1` and stopped. Resolving *that* result yields the real path, so
`resolve(resolve(x)) != resolve(x)`.

The live two-pass route is a graph `node=` `%` rawfile field: `node_token_split()`
(`src/draw.c`) resolves it, then `extra_rawfile()` (`src/save.c`) resolves the result
again. The adversary drove it end to end — a `%` field spelled `$adv_lvl2` (whose value is
the literal `$adv_lvl1`, whose value is the raw path) **resolved and loaded**, window
`0..2e-06` instead of the `-1 -2` unresolvable seed — and then:

```
  xschem raw clear {$adv_lvl2}   ->  0     ;# one pass; cannot match the two-pass key
  xschem raw clear <one-pass result>  ->  1
```

That is precisely the read/clear disagreement decision **D7** (one resolver, called once,
idempotent) exists to prevent, arriving by a route D7 does not cover: not two different
resolvers, but the same resolver applied a different number of times.

## 3. Why it is not being fixed here

- **It is unchanged from HEAD.** HEAD's `subst` did not rescan a value either, and the
  node_token_split → extra_rawfile double pass long predates the 0812 fix. This is not a
  regression the fix introduced; the fix only made the old comment's reasoning checkable.
- **Nothing shipped reaches it.** It needs a variable whose *value* contains another `$`.
  The complete shipped set of `rawfile=` values is three `$netlist_dir/...` spellings plus
  the bare name `distrib`; `$netlist_dir` holds an absolute path with no `$` in it.
- **The injection property is unconditional and does not depend on idempotence.** The
  first pass emits no metacharacter it did not receive as data and the second pass parses
  nothing, so N passes are as safe as one. Only *value stability* is at stake.

## 4. Decision (ladder rung L2)

**Correct the comments, keep the behaviour.** Rejected alternatives:

- *Make node_token_split() stop resolving the rawfile field and let extra_rawfile() do it
  alone.* The `%` field is also consumed by walkers that never reach extra_rawfile, and the
  strip would lose `$netlist_dir` support in the seven `node=` walkers (issue 0305's
  one-helper unification). Larger blast radius than the defect.
- *Make expand_tcl_vars() rescan values until a fixed point.* That re-introduces
  the exact hazard the fix removes: a value would become script-shaped input again, and
  `$a` holding `$b([exec …])` would be re-parsed. Never.
- *Mark resolved paths so a second pass is a no-op.* Requires a sentinel byte inside a
  filename. Rejected as worse than the defect.

## 5. What was done

`src/util.c`, `src/xschem.h` and `src/draw.c` now say what is true: idempotent **on every
spelling that ships** (pinned by KEY1/KEY3 in `tests/headless/test_raw_read_dispatch.tcl`),
**not in general**, with this issue named. `src/wave_viewer.tcl`'s db_path_safe rule 2
carries the same pointer.

## 6. Still open

- **No row covers the two-pass-vs-one-pass shape.** KEY1/KEY3 use spellings that converge
  in one pass, so they cannot see it. A row would need a graph strip plus a nested-value
  variable; worth adding when someone next touches `test_node_token_split.tcl`.
