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

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **FIXED**, 2026-09-03 (both parts))


## Part 1 — the unbounded glob, capped at BOTH doors

New `_glob_why {pat}` in `src/op_param_lists.tcl`: `{}` when the pattern carries
at most `$maxstars` (**4**) wildcards, and a sentence naming the pattern
otherwise. Called from **two** places and defined in one (invariant I1's shape):

* `_parse_line`'s flavor arm — **at parse time, where the file is still the
  subject**, in the report-and-skip shape the six existing arms already use;
* `set_list`'s flavor arm — the **other** door, so an rc, a plugin or item B5's
  own scope dialog cannot put in a pattern the settings file would have refused.

**Deliberately NOT in `effective`**, which is this issue's own recommendation:
a file that loads clean and freezes later inside a redraw is the defect, and the
freeze is then unattributable to the file that caused it.

The cap is **4** because every shipped PDK `match` glob and every glob in either
suite is 2-star, and the measured curve against a 31-char cell name is 5 stars
0.97 ms · 7 stars 14.97 ms · 9 stars 128.88 ms · 11 stars 11.6 s · 13 stars
> 70 s. Four is headroom on both sides; three or lower would red the suite's own
ordinary rows as collateral.

## Part 2 — the reader is no longer quadratic

`_parse_line` rescanned the accumulated list linearly for its duplicate-label
check on **every** `param` row. Replaced by `_label_hit` / `_label_note` over a
new `labelmap` array of `key -> dict label->index`, parallel to `lists` exactly
as `owned` is. Rebuilt with the list it indexes (on the first touch of a key in
a file), so it can never describe a list it does not belong to; cleared by
`reset` and invalidated by `set_list`.

## Red before green

| row | red on | green after |
|---|---|---|
| `X5` 13- and 9-star globs | loaded **clean**, `reports=0`, both owned | both reported and skipped, both unowned; the 2-star and 4-star counterweights still load silently and still match |
| `X6` the consumer | `effective` 128.88 ms on a 31-char cell name | milliseconds, answers the class list |
| `X7` `set_list`, the second door | no cap at all | 7-star refused with a report, 4-star accepted |
| `P6` reader shape | ratio **12.6** (20.4 ms → 260.8 ms for 4× the rows) | ratio under 7.0, 4000 entries correct end to end |

Sabotage, with the fix in place:

* `SB-GLOB-UNBOUNDED` (`_glob_why` → `{}`) → **X5, X6, X7 red**, `3 FAILED (53 passed)`.
* `SB-READER-QUADRATIC` (`_label_hit` → the old linear rescan; still **correct**,
  only slow, so only the timing row can see it) → **P6 red**, `1 FAILED (55 passed)`.

## One correction to this issue's acceptance row, and it is a measurement

Row `X5` as first written used `[string repeat *a 9]` and `[string repeat *a 13]`
for its two hostile globs and asserted `ol_saidhits` = 1 for each. That golden is
**unsatisfiable**, not a defect: `ol_saidhits` counts *reports containing a
needle*, a report has to quote the glob it refused or the user cannot tell which
line was skipped, and the 9-star glob is a **substring** of the 13-star one — so
the 13-star report satisfies the 9-star needle too and 2 is the only reachable
answer. The fixture now spells them with different letters
(`*a`×13 and `*b`×9), which is recorded in the suite beside the row.

## Why this was reverted

**This issue's own fix was not refuted, and nothing below was measured wrong.**
It was reverted as **collateral**. Item B2a was implemented as one 2,506-line
diff across four files; the adversary pass refuted the batch's central claim on
three *other* issues — **1277**, **1281** and **1284** — and the write-up agent
reproduced all three independently before deciding. Splitting a diff that size
into a "sound" half and an "unsound" half at write-up time would have committed
a code change that no Measure, Verify-A, Verify-B or Verify-C pass had ever
seen, which is precisely the failure mode this batch has already paid for in
items B1, B2 and B3.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` applies clean to
`825cd3bd`. The next crew's job is **apply → fix the three named holes →
re-verify**, and this issue's portion should survive that pass unchanged.
