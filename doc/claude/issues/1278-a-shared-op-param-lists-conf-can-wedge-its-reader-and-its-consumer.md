# 1278 — a shared `op_param_lists.conf` can wedge its reader and freeze its consumer

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass,
2026-09-03. Latent: nothing calls `effective` yet.

DD-3 made the settings file **data** so a user can accept it from a colleague
**without reading it first**. The parser holds — nothing in the file is ever
executed (item B2's X rows prove it as a side effect, not a return code). But
the file can still cost its recipient unbounded time, in two places, with no
report and no attribution.

`src/op_param_lists.tcl`'s own header claims *"a parser its own input can kill
is not a strict parser."* The parser is safe. The **consumer** is not.

## Part 1 — the flavor glob, exponential and uncaught (the serious half)

`effective` runs `string match -nocase <pattern> $cellname` on a pattern taken
verbatim from the settings file, unbounded and outside any `catch`.

Measured, one flavor entry, cell name `aaa…b` (31 chars):

| `*a` repeats in the pattern | time per call |
|---|---|
| 5 | 0.85 ms |
| 7 | 14.6 ms |
| 9 | 129 ms |
| 11 | 11.6 s *(adversary pass)* |
| 13 | > 70 s, killed *(adversary pass)* |

Roughly ×9 per two stars — classic catastrophic backtracking. **`load_conf`
accepts such a line instantly and reports nothing**, so the freeze arrives
later, inside a redraw or a key press, and is unattributable to the file that
caused it.

Note `op_annot::_matches` (`op_annot.tcl:411`) wraps its glob loop in a
`catch`; `effective` does not. A `catch` would not help here anyway — the call
does not raise, it runs.

## Part 2 — the reader is quadratic in one list's length

`_parse_line` linearly rescans the accumulated list for its duplicate-label
check on **every** `param` row:

| rows in one list | `load_conf` |
|---|---|
| 1000 | 19 ms |
| 2000 | 67 ms |
| 4000 | 249 ms |
| 8000 | 1035 ms |
| 200000 | did not finish in 2 minutes |

Irrelevant for a real 6–13 row list. It is recorded because it is the same
class of hazard as part 1 — a shared file that costs its reader unbounded time
— and because the fix is one line.

## Recommended fix

**Part 1 — bound the pattern at parse time, where the file is still the
subject.** In `_parse_line`'s `list`/`param` arm, when the scope is `flavor`,
reject a glob whose `*` count exceeds a small cap (4 covers every plausible
cell-name pattern; sky130's own `match` globs use 2) and report it:

```
<file>:<n>: the flavor pattern "<pat>" has <k> wildcards, which can take
minutes to match; skipped. Use a simpler pattern.
```

Reporting at parse time is the load-bearing half — a limit enforced in
`effective` would still leave the user with a file that loads clean and a tool
that freezes later.

**Part 2** — carry a per-list `array` of labels alongside, so the duplicate
check is a hash lookup instead of a rescan.

**Rejected: a time budget around `string match`.** Tcl cannot interrupt it, and
a watchdog for a case a two-line validator prevents is machinery nobody can
test.

## Acceptance rows this needs

* X5 — a conf carrying a 13-star flavor glob is **reported and skipped** at
  load, and a subsequent `effective` on a long cell name returns in
  milliseconds.
* X6 (counterweight) — an ordinary 2-star glob (`*sky130_fd_pr*`, the shape the
  PDKs themselves ship) still loads and still matches.

## Who inherits this

**Item B5** writes flavor globs, and **B3** calls `effective` on every redraw.
The wedge is one hand-edited line in a file the feature exists to share.
