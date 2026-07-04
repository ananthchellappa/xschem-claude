# Issue 0077 — `getprop wire` / `getprop rect` index the object arrays with an UNCHECKED index (out-of-bounds read)

**Opened:** 2026-07-04
**Status:** OPEN — problem statement only. No fix in this document.
**Severity:** HIGH — memory-safety: a plain scripted/CIW command reads out of bounds off a
caller-supplied index, which can crash the editor or disclose arbitrary heap memory.
**Class:** value-range OOB — DISTINCT from the `argc`/NULL-deref crash class of 0075/0076
(here `argc` IS guarded; the bad value is the `atoi` result used as a subscript).
**Branch:** `fluid-editing`.
**Affects:** the `getprop` reader in `src/scheduler.c` (`getprop` branch at `:2686`),
specifically the `wire` and `rect` arms (and the upper bound of the `text` arm).
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

`getprop wire`/`getprop rect` are the ones that don't. The `getprop text` arm guards only
the **lower** bound (`if(n < 0)`) and not the upper bound (`n >= xctx->texts`), so it is a
partial instance of the same defect.

## 3. Impact

A memory-safety hole reachable from any script, CIW entry, action-log replay, or test that
passes an out-of-range index to `getprop wire`/`getprop rect`/`getprop text`. No malicious
intent required — a stale index from an edited schematic (indices shift on delete/insert,
see the object-model analysis) can land out of range and read wrong/OOB memory silently.

## 4. Out of scope for this document

Fix design (where to bounds-check, whether to error vs return `""`, whether to share the
`object #index` validation helper) is deliberately not included — problem statement only.
The natural fix mirrors 0075/0076: validate `n`/`c` against `xctx->wires` /
`cadlayers` / `xctx->rects[c]` (and `xctx->texts`) before subscripting, matching the
`object #index` range-check, returning an error or empty result on miss.

## 5. Related
- `doc/claude/specs/property_introspection.md` — the P2/P3 ENHANCEMENT (whole-prop read +
  key enumeration for all types; `line`/`poly`/`arc` arms) split out of the original 0077.
- `doc/claude/code_analysis/object_model_agent_reference.md` §9 (D1), §11 (extension recipes).
- Issues **0075** / **0076** — the sibling `argc`/NULL-deref crash class and the
  dispatcher-safety convention (validate before indexing) they establish.
