# 0841 — `test_wave_sigbrowser_keys` carries hardcoded counts that are SIX bindings behind the tree

Status: **OPEN — measured 2026-08-26.** A standing red, and a **stale golden**,
not a behaviour break. Found while baselining an unrelated change; confirmed
pre-existing by re-running at `HEAD` with the change removed (identical 3
failures). Related: 0690 and 0689 (the same failure *class* — a golden that rots
while everyone treats the red as furniture), 0826.

## Measured

`tests/headless/test_wave_sigbrowser_keys.tcl`, on `:99` with openbox 3.6.1:

```
FAIL: BK22 … the action id appears in callback.c exactly TWICE
        -> {1 3}          (exp {1 2})
FAIL: BK29 … the LIVE binding table … grew by exactly one
        -> {1 0 78}       (exp {1 0 72})
FAIL: BK31 … unbind removes the row … rebind puts it back
        -> {1 0 77 1 78}  (exp {1 0 71 1 72})
```

Read the numbers:

* **every non-count term is CORRECT.** BK29's first two fields (`1 0` — the
  ctrl+alt row is present, no canvas row for keysym 53) are exactly as expected;
  only the table SIZE differs. BK31's `1 0 … 1 …` likewise, and its *deltas* are
  right: 77 → 78 on rebind is the same `+1` the golden asserts as 71 → 72.
* the size is off by a **constant 6** in all three places (78-72, 77-71, 78-72).
* BK22 counts literal occurrences of an action id in `callback.c` and finds 3
  where the golden says 2.

So six bindings were added to the live table and one more `callback.c` mention
appeared, and nobody re-baselined. **The feature works; the arithmetic is old.**

## Why this is a defect and not furniture

This is precisely the shape CLAUDE.md's rule was written about: a suite that reds
every run teaches every reader to skip it, and it is the one place a real
regression hides in plain sight. Three rows here are dark. A genuine 7th binding
appearing tomorrow would move 78 → 79 and change nothing anybody looks at.

## Fix

Do **not** simply bump 72 → 78. Two of these rows want to stop being absolute
counts at all:

* **BK29 / BK31** already assert the interesting thing — the **delta** (`+1` on
  bind, `-1` on unbind) and the row's presence/absence. Assert those and drop the
  absolute size, which is a fact about the whole binding table and not about this
  feature. Then adding a binding elsewhere cannot red this suite again.
* **BK22**'s count of an id in `callback.c` is a source-shape guard; if the third
  occurrence is legitimate (a comment, a second dispatch site) the golden moves to
  3, but the third site must be **identified in the commit message** — an
  unexplained bump is how 0690 happened.

⚠ **Identify what the six new bindings ARE before re-baselining.** A count that
grew by six is evidence, and discarding it without reading it is the actual
mistake this issue is about.
