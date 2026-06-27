# Un-hairball refactor — Step 1: extract the utility layer

Goal: reduce hairball-ness with **behavior-preserving** structural cleanup only
(no functionality change yet). This is the lowest leverage/risk move available,
chosen from the measured call graph.

## The target

`editprop.c` defines 52 functions; **31 are general-purpose utilities** (memory,
string, file, debug, number-format helpers) with nothing to do with property
editing. They account for ~60% of all cross-file calls and are the reason
`editprop.c` falsely looks like the most-coupled file (4,873 incoming calls).

Extract those 31 functions into a new **`util.c`** + **`util.h`**.

Utility set (all global, none depend on editprop.c statics — those statics are
all `edit_*_property` / `update_symbol`):

    dbg  dtoa  my_atod  my_atof  my_calloc  my_expand  my_fgets  my_fgets_skip
    my_fopen  my_free  my_itoa  my_malloc  my_mstrcat  my_realloc  my_snprintf
    my_strcasecmp  my_strcasestr  my_strcat  my_strcat2  my_strdup  my_strdup2
    my_strncasecmp  my_strncat  my_strncpy  my_strndup  my_strtok_r  str_replace
    strboolcmp  strtolower  strtoupper   (+ second my_snprintf variant)

`dtoa` and `my_itoa` touch `xctx` (a global extern), which is fine — `util.c`
includes `xschem.h`.

## Why this is the right first move

- Best leverage/risk ratio; behavior-preserving **by construction** (pure move,
  no logic or signature changes).
- Compiler + linker enforce correctness: every symbol must still resolve, no
  duplicate definitions. A clean link is proof references are intact.
- Headless harness (`tests/headless/run.sh`) proves behavior is unchanged — gold
  SPICE netlists must match exactly.
- Payoffs: `editprop.c` shrinks to its real job (21 property functions); the
  dependency graph becomes honest (`token.c`'s true centrality un-masked); the
  codebase gains a real utility layer at the bottom; and 29 prototypes leave the
  535-extern kitchen-sink header `xschem.h` into `util.h` — a beachhead for
  breaking up the umbrella header.

## Procedure

1. **Baseline**: `cd src && make`; `../tests/headless/run.sh` → green.
2. **`util.h`**: move the 29 `extern` util prototypes out of `xschem.h`; have
   `xschem.h` `#include "util.h"`.
3. **`util.c`**: move the 31 function bodies verbatim; `#include "xschem.h"`.
4. **Makefile**: add `util.o` to `OBJ` + an explicit compile rule.
5. **Build**: must be zero errors/warnings (clean link = all refs resolve).
6. **Verify**: `run.sh` must show identical gold (behavior preserved, demonstrated).
7. **Discipline**: move only — no "improvements" in this pass. Trivial review.

## What NOT to do (not low-hanging)

- Don't split `scheduler.c`'s 7k-line dispatcher (touches control flow).
- Don't touch `xctx` (highest value, highest risk — the long game).
- Don't refactor logic while relocating — keep the commit a pure move.

## The pattern this establishes

Un-hairballing proceeds as a series of behavior-preserving extractions of
self-contained clusters, each verified by the harness:
  Step 1 (this): utility layer out of editprop.c.
  Next candidates: base64/ascii85/raw-file IO in save.c; the hash-table code;
  further breakup of xschem.h.
Deeper structural change (xctx decoupling, dispatcher split) comes only after
the easy, safe layers are carved out and the harness coverage is broadened.
