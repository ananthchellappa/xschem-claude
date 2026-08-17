# 0419 — top-level `@dev[param]` currents are classed as nets, so `Show device internals` does not hide them

**Status:** OPEN. Measured on branch `fluid-editing` at `9b1394c9` (casemode batch item 5).
Documentation only — nothing fixed. Two committed checks (`CS91h`–`CS91j`,
`tests/headless/test_wave_casemode.tcl`) pin the *current* behaviour, so a fix must
restate them.
**Area:** `src/wave_viewer.tcl` — `wviewer::sig_declass` (`:2145`) and its ≥3-segment guard.
**Found:** 2026-08-16, by the casemode batch item 5 crew, while auditing the two-pane
browser's group/class parser against the `@dev[param]` shape. Named in
`doc/claude/casemode_batch/receipts/05-viewer-tcl-browser-scan.md` §2 as "named, not
fixed — a classification question, not a case one, and out of an empty-diff item's
scope", with no issue number. Filed here by the driver so it has a home.
**Belongs to:** the two-pane signal browser owner. See
`doc/claude/specs/mixed_signal_signal_browser.md`.

**This is not a case-sensitivity bug.** Item 5 established that all three `@`-handling
sites (`sig_declass`, `sig_class`, `browser_label`) are already case-blind and handle
both spellings correctly. The defect is orthogonal and was found alongside.

---

## Mechanism

A hierarchical `@`-param current has dots in it and clears the ≥3-segment guard, so the
tag is seen and the signal is classed as a device internal. A **top-level** one has no
dots at all, never reaches the guard, and `sig_declass` falls through to classing it a
`net`.

Measured on `build-ver_50` with `.options savecurrents`, both modes:

| mode | hierarchical | top level |
|---|---|---|
| `fold` | `i(@r.x1.rq[i])` | `i(@r1[i])` |
| `preserve` | `i(@R.X1.Rq[i])` | `i(@R1[i])` |

With **`Show device internals` OFF**:

```
i(@r.x1.rq[i])   hidden    <- correct
i(@r1[i])        KEPT      <- wrong, it is a device internal too
```

The user asks to hide device internals and the top-level ones stay on screen.

## Why item 5 did not fix it

Item 5's audit contract was an **empty diff** (`receipts/00a-suite-sweep.md`, the rule
for casemode items 1–9). Changing what the browser classifies changes what it displays,
which is a behaviour change with its own blast radius across the two-pane suites — for a
reason unrelated to case. That is exactly what the empty-diff contract exists to detect,
so the right move was to name it and leave it.

## What a fix has to decide

1. **What actually identifies a device-internal current** — the `@` sigil itself is the
   honest signal, not the segment count. The ≥3-segment guard appears to be a proxy that
   happens to work only for hierarchical names.
2. **`CS91h`–`CS91j` pin the current behaviour deliberately.** They are not incidental;
   they were written to record what the parser does today. A fix restates them and says
   why, rather than deleting them.
3. **Whether `sig_class` and `browser_label` need the same correction** — item 5 checked
   them for case-blindness, not for this.

## What is NOT claimed here

Nobody re-rendered the two-pane widget. Item 5's checks drive the parser procs directly,
and the `@`-shape raws were transcribed by hand into an inline ASCII fixture with no
simulator in the loop. So the *parser's* verdict is measured; what the widget draws as a
consequence is inferred.
