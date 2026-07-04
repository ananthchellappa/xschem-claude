# Issue 0077 — `getprop wire` / `getprop rect` index the object arrays with an UNCHECKED index (out-of-bounds read)

**Opened:** 2026-07-04
**Status:** FIXED (2026-07-04) — bounds checks added to the `wire` and `rect` arms
(`src/scheduler.c`), mirroring the `object #layer,index` range-check; see **§6 Resolution**.
The `text` arm needed no change (see §2 correction). RED→GREEN sabotage-verified; regression
`tests/headless/test_getprop_index_bounds.tcl` added.
**Severity:** HIGH — memory-safety: a plain scripted/CIW command reads out of bounds off a
caller-supplied index, which can crash the editor or disclose arbitrary heap memory.
**Class:** value-range OOB — DISTINCT from the `argc`/NULL-deref crash class of 0075/0076
(here `argc` IS guarded; the bad value is the `atoi` result used as a subscript).
**Branch:** `fluid-editing`.
**Affects:** the `getprop` reader in `src/scheduler.c` (`getprop` branch at `:2686`),
specifically the `wire` and `rect` arms (the `text` arm is safe — see §2).
**Origin:** object-model analysis `doc/claude/code_analysis/object_model_agent_reference.md`
§9 defect D1. The P2/P3 items originally filed alongside this are a capability enhancement,
now tracked separately at `doc/claude/specs/property_introspection.md`.

---

## 1. Problem

`getprop wire n` and `getprop rect c n` convert the caller's argument with `atoi` and use it
directly as an array subscript with **no range check**:

```c
/* src/scheduler.c:2818-2819  — getprop wire */
int n = atoi(argv[3]);
Tcl_SetResult(interp, (char *)get_tok_value(xctx->wire[n].prop_ptr, argv[4], 2), ...);

/* src/scheduler.c:2789-2791  — getprop rect */
int c = atoi(argv[3]);
int n = atoi(argv[4]);
Tcl_SetResult(interp, (char *)get_tok_value(xctx->rect[c][n].prop_ptr, argv[5], ...), ...);
```

`argc` is guarded (`argc < 5` / `argc < 6` floors precede these), so this is NOT the
0075/0076 NULL-deref class. The defect is the **value range** of the `atoi` result: a
negative or too-large `n` (or `c`) indexes `xctx->wire[n]` / `xctx->rect[c][n]` out of
bounds and dereferences the `.prop_ptr` at that arbitrary address.

Reachable from ordinary input, e.g.:

```tcl
xschem getprop wire 999999 name      ;# n >> xctx->wires
xschem getprop wire -1 name          ;# negative subscript
xschem getprop rect -1 0 name        ;# c out of [0, cadlayers)
xschem getprop rect 0 999999 name    ;# n out of [0, xctx->rects[0])
```

Each performs an out-of-bounds read → potential SIGSEGV (→ emergency-save → editor dies) or
a heap-memory disclosure through the returned property string.

## 2. Why it is an outlier (existing-functionality defect, not a missing feature)

The sibling read/resolve commands on the SAME kind of index already bounds-check:

- `xschem object #index` / `#layer,index` range-checks per type — `scheduler.c:5507-5514`
  (validates `c` in `[0, cadlayers)` and `i` in `[0, count)`, sets `i = -1` on any miss).
- `xschem select …` validates before selecting.
- `setprop` validates.

`getprop wire`/`getprop rect` are the ones that don't. **Correction to the original
write-up:** the `getprop text` arm is NOT affected — it resolves its index through
`get_text()` (`scheduler.c:54`), which upper-bounds (`i >= xctx->texts → -1`) as well as
guarding negatives, so `text` is already safe. Only `wire` and `rect` (which use a raw
`atoi` subscript) carry the defect.

## 3. Impact

A memory-safety hole reachable from any script, CIW entry, action-log replay, or test that
passes an out-of-range index to `getprop wire`/`getprop rect`/`getprop text`. No malicious
intent required — a stale index from an edited schematic (indices shift on delete/insert,
see the object-model analysis) can land out of range and read wrong/OOB memory silently.

## 4. Resolution (FIXED)

Added bounds checks before the subscript in both affected arms, mirroring the
`object #layer,index` range-check, returning a Tcl error on an out-of-range reference:

```c
/* getprop rect — src/scheduler.c */
if(c < 0 || c >= cadlayers || n < 0 || n >= xctx->rects[c]) {
  Tcl_AppendResult(interp, "xschem getprop: rect not found: ", argv[3], " ", argv[4], NULL);
  return TCL_ERROR;
}
/* getprop wire — src/scheduler.c */
if(n < 0 || n >= xctx->wires) {
  Tcl_AppendResult(interp, "xschem getprop: wire not found: ", argv[3], NULL);
  return TCL_ERROR;
}
```

`text` was left unchanged (already bounded via `get_text()`, §2).

Verified RED→GREEN with sabotage: reverting the checks and rebuilding reproduced
`EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_*` on `xschem getprop wire 999999`;
with the checks the same command returns `xschem getprop: wire not found: 999999` and the
process survives. Regression `tests/headless/test_getprop_index_bounds.tcl` (registered in
`run_regression.tcl` `hcases`, 8 checks): creates a real wire + rect, asserts valid in-range
reads still succeed, and asserts every out-of-range form (wire/rect, negative and too-large)
errors instead of crashing.

## 5. Related
- `doc/claude/specs/property_introspection.md` — the P2/P3 ENHANCEMENT (whole-prop read +
  key enumeration for all types; `line`/`poly`/`arc` arms) split out of the original 0077.
- `doc/claude/code_analysis/object_model_agent_reference.md` §9 (D1), §11 (extension recipes).
- Issues **0075** / **0076** — the sibling `argc`/NULL-deref crash class and the
  dispatcher-safety convention (validate before indexing) they establish.
