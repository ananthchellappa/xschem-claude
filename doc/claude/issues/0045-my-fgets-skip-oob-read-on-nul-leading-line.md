# Issue 0045 — `my_fgets_skip()` out-of-bounds read `buf[-1]` on a NUL-leading line

**Opened:** 2026-06-26
**Status:** OPEN
**Severity:** LOW — out-of-bounds read; typically benign, but can mis-count skipped lines on hostile/
corrupt input (and is UB).
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #7 (CONFIRMED).
**Affects:** `src/util.c` `my_fgets_skip()` (~:111).

---

## 1. Symptom

Loading a file containing a line that begins with an embedded NUL byte causes an out-of-bounds read of
`buf[-1]`. Usually harmless on Linux, but it can mis-detect end-of-line (reading stack garbage) and skip
the wrong number of lines; it is undefined behavior and a latent crash on trap builds.

## 2. Root cause

After `fgets()`, the code reads `buf[len-1]` where `len = strlen(buf)` without guarding `len == 0`.
`strlen()` returns 0 when the line starts with a NUL byte, so `buf[len-1]` becomes `buf[-1]`.

## 3. Fix sketch

Guard the access: `if(len > 0 && buf[len-1] == '\n') ...`. Add a unit test feeding a NUL-leading line.

## 4. Acceptance

`my_fgets_skip()` never reads `buf[-1]`; a NUL-leading line is handled without an OOB access.
