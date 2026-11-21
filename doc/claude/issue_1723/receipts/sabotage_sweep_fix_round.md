# Issue 1723 items 5-7, fix round: red first, and the sabotage sweep (2026-11-21)

This is a dated record, not a baseline. It was measured on the working tree that became the commit
adding this file (parent `ed635d969`), and nothing re-runs it. The counts are what that tree printed,
and any later edit to the suite moves them.

## Red first

The new and moved rows were written first and run against `ed635d969`'s `src/ase.tcl`, with
`test_ase_preflight` headless (`--nogui`, an armed throwaway HOME). The result was **12 FAILED (304
passed)**:

- `PF1723r3` (keyword alone, LF)
- `PF1723r4` (`//`, quotes, comment-only line)
- `PF1723s4b` (case-only spelling under `distinguish`)
- `PF1723s5` (nested include)
- `PF1723s7` (the reader's two shapes through the scan and the gate)
- `PF1723t` and `PF1723u` (the refusal head and the caution, re-worded)
- `PF1723u3` (the value shapes)
- `PF1723y4` (symlinked PDK root)
- `PF1723ad3` (put-back failure)
- `PF1723ad4` (backup fails after its open)
- `PF1723ac4` (backup mode)

`PF1723s6` and the widened `PF1723ah` were green on that code, as they should be: the code they
fence was correct, and they exist so that breaking it is seen. Sabotages T10 and T11 below are their
discrimination.

Two rows were added later in the round, each red before its fix:

- **`PF1723r5`** was red on the tree before the `#` line fix: 1 FAILED (316 passed).
- **`PF1723ad3`'s B file** was first small. With a small file the failure is at `close`, which closes
  the channel anyway, so sabotage T18 stayed green (ALL PASS 316). B was made larger than a channel
  buffer so that `puts` itself fails, and T18 turned red. The table below is that final tree.

## Method

A scratch Python driver, not committed, made one substitution per sabotage in `src/ase.tcl`. It
refused any site whose text did not occur exactly once. For each sabotage it:

1. wrote the sabotaged copy over the file;
2. ran `P`: `test_ase_preflight` with `--nogui`, `DISPLAY` unset and an armed throwaway HOME
   (`tests/headless/test_home.sh`'s `test_home_arm`), the counted headless arm. For T10 and T11 it also
   ran `W`: `test_ase_window` through `tests/headless/run_suites.sh` with `AUDIT_DISPLAY=private`, a
   private Xvfb with openbox;
3. kept every `FAIL`, `FATAL` and `UNEXPECTED` line;
4. restored the file from its in-memory copy in a `finally` and compared its md5 with the
   pre-sabotage value.

Every sabotage reported `restored`. The baseline is `test_ase_preflight` ALL PASS (317) and
`test_ase_window` ALL PASS (386) on the display arm.

## Results

| id | site (symbol) | substitution | what it breaks | red rows |
|---|---|---|---|---|
| T01 | `ase::include_card_idents` | early out `(?:\s\|$)` → `(?:[ \t\r]\|$)` | finding 1: a keyword alone on an LF line is never read | PF1723 r3 s7 |
| T02 | `ase::spice_comment_at` | the `//` arm → `if {0}` | finding 3: a name behind `//` is read | PF1723 r4 s7 |
| T03 | `ase::spice_comment_at` | the quote skip → `if {0}` | `'a//b'` is cut as a comment | PF1723r4 |
| T04 | `ase::include_card_idents` | the comment cut → `if {0}` | no inline comment is honoured | PF1723 r r2 r4 s7 aa ab ae ae3 ac ac2 ad ad2 |
| T05 | `ase::include_top_words` | the comment cut → `if {0}` | words behind a comment become element words | PF1723r4 |
| T06 | `ase::preflight_scan` | the case-only stand-down put back | finding 2: a case-only spelling under `distinguish` is silent again | PF1723s4b |
| T07 | `ase::preflight_scan` | `set topnest …` → `set topnest 0` | finding 10: a nested include's instance is refused | PF1723s5 |
| T08 | `ase::include_top_nests` | `$depth == 0 &&` → `1 &&` | an include inside a `.subckt` body counts for the top level | PF1723s5 |
| T09 | `ase::include_value_plain` | the first cut's `{`-only rule | finding 4: a quoted or bare-parameter value is called "dropped" | PF1723u3 |
| T10 | `ase::include_top_words` | `incr depth` → `incr depth 0` | finding 12: a stdcell deck's `X1` cards stand the stale `x1.` rows down | PF1723 s6 ah ah2; FX1723 Ea Eb Ec |
| T11 | `ase::include_texts` | skip every entry whose text holds `$` | finding 12: a `$::VAR` include is never scanned | PF1723 s6 ah ah2; FX1723 Ea Eb Ec |
| T12 | `ase::include_protected_roots` | the resolved form → `catch {}` | findings 9 and 13: a symlinked PDK root protects nothing | PF1723y4 |
| T13 | `ase::include_apply_plan` | delete every backup on a failed write | findings 5 and 7: the only copy is destroyed | PF1723ad3 |
| T14 | `ase::include_apply_plan` | the `include_reads_as` skip → `if {0}` | a whole read-only file is reported as not put back | PF1723ad2 |
| T15 | `ase::include_backup_write` | the permission copy → `catch {}` | finding 6: the backup keeps 0600, not the original's mode | PF1723ac4 |
| T16 | `ase::include_backup_write` | the half-made delete → `if {0}` | finding 8: an empty or partial `.bak` is left | PF1723ad4 |
| T17 | `ase::include_backup_write` | the close on failure → `if {0} {}` | finding 8: the backup's channel leaks | PF1723ad4 |
| T18 | `ase::include_write_bytes` | the close on failure → `if {0} {}` | a failed `puts` leaks the file's channel | PF1723ad3 |
| T19 | `ase::preflight_gate` | the refusal head back to "a {...} expression" | finding 4, in the refusal | PF1723t |
| T20 | `ase::preflight_include_caution` | the case branch → `if {0}` | the case caution claims the instance lacks the node | PF1723s4b |
| T21 | `ase::include_card_idents` | a `#` line not transparent | a card is cut at a `#` comment line | PF1723r5 |
| T22 | `ase::include_top_words` | a `#` line counted as an element card | a comment's words stand top-level names down | PF1723r5 |
| T23 | `ase::spice_comment_at` | the `$` arm → `if {0 && …}` | a name behind ` $` is read | PF1723 r r2 |

No sabotage left the suite green.

## What the sweep does not cover

- **The comma form of the `$` arm** (`,$`). Row `PF1723r` drives ` $` (T23), and nothing drives a `$`
  right after a comma.
- **`ase::include_write_bytes` inside `ase::include_unapply`.** That path is the same writer. Row
  `PF1723ac3` drives its success, and `FX1723Cf` drives the press that uses it. Nothing makes the undo's
  own write fail.
- **The Windows arm of `ase::include_backup_write`,** where `file attributes -permissions` is absent and
  the backup stays 0600. It is not measurable here.
