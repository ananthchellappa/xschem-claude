# 0431 — the `raw switch` / `switch_back` `update_op()` gate mixes PRE- and POST-switch state

**Status:** OPEN. Measured on branch `fluid-editing` at `89d0f13e`, 2026-08-19.
**Area:** the `xschem raw` dispatcher (`src/scheduler.c:10338`) and the two
`update_op()` gates (`:10415-10417`, `:10428-10430`).
**Found:** 2026-08-19, mapping the registry surface for
`doc/claude/specs/typed_signal_accessors.md` §1.2 F3.
**Severity:** low today (both operands usually agree), but it is a
silent-wrong-answer shape and one half is an unguarded dereference.

---

## What

The dispatcher captures the current database **once**, at entry:

```c
Raw *raw = xctx->raw;
```
— `src/scheduler.c:10338`

`raw switch` and `raw switch_back` then move `xctx->raw`, and the gate that
decides whether to re-run the operating-point back-annotation reads **both**:

```c
if(ret && raw && raw->rawfile && raw->allpoints == 1 &&
   (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
  update_op();
}
```
— `src/scheduler.c:10415-10417`, and the identical copy at `:10428-10430`

`raw->allpoints` is the **outgoing** database's point count; `xctx->raw->sim_type`
is the **incoming** database's type. The condition is therefore about no single
database.

## Two distinct consequences

1. **Wrong answer, both ways.** Switching *from* a 1-point operating point *to* a
   many-point `dc` sweep satisfies both halves and re-runs `update_op()` against
   a sweep. Switching *from* a many-point transient *to* a genuine 1-point `op`
   fails the first half and skips the annotation the switch should have
   triggered.
2. **Unguarded dereference.** `raw` is NULL-tested; `xctx->raw` is not, and
   `sim_type` is not either. `src/save.c:1765-1774` names these two gates as unguarded `strcmp` sites, and the
   clear arms (`:2031`, `:2061`, `:2102`) are where `xctx->raw` itself can go, and a slot with a NULL `sim_type` is
   a documented state — `xschem raw info` prints it as the literal `<NULL>`
   (`src/save.c:2119-2121`), and `wviewer::db_suffix` refuses to build a suffix
   for exactly that case (`src/wave_viewer.tcl:2581`).

## Fix direction

Read both operands from `xctx->raw` **after** the switch returns, and NULL-guard
`sim_type`. The predicate itself ("a 1-point `op`-or-`dc` slot is an operating
point") is right and is reused by
`doc/claude/specs/typed_signal_accessors.md` R103; only the operands are wrong.

A test drives it directly: build a raw with a 1-point `Operating Point` plot and
a many-point `dc` plot, load both, and assert the back-annotated values after
each of the four switch directions.

## Related

`doc/claude/specs/typed_signal_accessors.md` R103 (which depends on the
predicate) and §19 defect 2.
