# Issue 0045 — `my_fgets_skip()` out-of-bounds read `buf[-1]` on a NUL-leading line

**Opened:** 2026-06-26
**Status:** ✅ FIXED 2026-07-02 (`fluid-editing`, committed in `c4a44172`). Triaged 2026-07-01: was STILL PRESENT (`src/util.c:103-105`). Confirmed **LOW** (1-byte stack OOB read, only on a NUL-leading line in corrupt/hostile input; `.sch/.sym` are text). **Priority P1 (trivial, S, zero-risk).** ⚠ The sibling `my_fgets()` at `src/util.c:120-122` has the IDENTICAL unguarded `buf[len-1]` read — fix BOTH with `if(len>0 && buf[len-1]=='\n')`.
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

## Resolution (2026-07-02)

Guarded both `my_fgets_skip()` (`src/util.c:105`) **and** its sibling `my_fgets()` (`src/util.c:122`)
— the finding named only the former, but both had the identical unguarded read. Both now use
`if(len > 0 && buf[len - 1] == '\n') break;`. Zero behavioral change on normal lines; only the
`len==0` path (the bug itself) is affected. Builds clean; core regression suite (create_save /
open_close / netlisting) green.
