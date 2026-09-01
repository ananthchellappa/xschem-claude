# 0920 - `xschem raw value <vec> 99` answers the cursor's value, not "no such point"

**Status:** RULING SETTLED 2026-08-29 (see the RULING at the foot of this file); the fix is NOT YET IMPLEMENTED. Filed 2026-08-29 by the
PLAN+RED pass of item **B3** (issue 0861), which measured it while fencing the
over-refusal risk on the same `else if` arm. Number claimed as a stub before the
work started, per house rules.

## What was measured

`src/scheduler.c`, the `xschem raw value <vec> <point> [dataset]` arm. When the
explicit point is OUT OF RANGE the in-range arm does not fire and control falls
through to the cursor-B annotation read, which answers **the value at the
annotation point** under the label of the point that was asked for.

On the B3 fixture (3 points, `v(d)` = 1.8 / 1.9 / 2.0, operating point attached
so `annot_p` is 0):

    xschem raw value {v(d)} 2    -> 2      correct, point 2 exists
    xschem raw value {v(d)} 99   -> 1.8    <-- the OP value, wearing "point 99"

Same class as RULING **D5-1**: a number displayed next to a thing it was not
measured for. It is milder than 0861 because the number is real; what is
fabricated is the *point label*.

## Why B3 did not fix it

B3's guard is `annot_p >= 0` on that fall-through, which is the minimum term
that separates the refused state from the published one. It changes the
out-of-range read only in the state where there is nothing to answer with at
all — after B3, `raw value v(d) 99` blanks on a refused transient and is
UNCHANGED at 1.8 on a published operating point. Row `SGN18` of
`tests/headless/test_spice_get_node_0861.tcl` pins both halves so the behaviour
is decided rather than inherited from where a brace landed.

Making the out-of-range read blank outright is a separate, wider decision: it
would change a published database's answer, and no row in the tree says what
depends on that today.

## Acceptance if fixed

1. `xschem raw value <vec> <point>` with `point >= npoints` answers empty, in
   every state, rather than the cursor value.
2. The point `-1` accessor is unaffected: it is the annotation read and keeps
   answering the published value.
3. `SGN18`'s operating-point half moves from `1.8` to blank, deliberately.

## RULING — 2026-08-29, decided under the user's "decide the 23" instruction

**DECIDED: fix it. Asking for a point number the results do not have answers
NOTHING, in every state.**

`xschem raw value <vector> <point>` must answer empty whenever the point number
is outside the loaded results, whether or not an annotation has been published.
Only an EMPTY point (`{}`) or a NEGATIVE point may fall through to the waveform
cursor read; that read is unchanged and still answers the published value.

Two edits, no more:

1. `src/scheduler.c`, the `raw value` arm — add a `point < 0 &&` term to the
   fall-through, so it reads
   `else if(point < 0 && raw->cursor_b_val && raw->annot_p >= 0)`. The in-range
   read on the arm above is untouched, which is what rows SGN13, SGN14 and
   SGN22 fence. Rewrite the comment block above it (the paragraph beginning
   "An OUT-OF-RANGE explicit point also lands on this arm") to state the settled
   rule rather than the open defect.
2. `tests/headless/test_spice_get_node_0861.tcl` row **SGN18** — the
   operating-point leg moves from `1.8` to blank, deliberately, and the row's
   comment stops pointing here as an open defect.

### Why this was decidable rather than a trade-off

* **RULING D5-1 and INVARIANT I3 already cover it.** The number is real but the
  LABEL is fabricated: it is presented as the value at point 99 when it was
  measured at the cursor. A point that does not exist is a missing vector by
  another name, and I3 says missing renders blank.
* **The behaviour is an upstream accident, not a feature.** `git log -L
  10625,10645:src/scheduler.c` shows the bare `else if(xctx->raw->cursor_b_val)`
  predates this branch; commit 57eaa18d (item B3) only added the `annot_p >= 0`
  term. The documented contract at `src/scheduler.c:10404-10409` says the cursor
  read is requested with an empty string `{}` — an out-of-range number has no
  documented meaning at all. Under CADENCE OR NOTHING, "stock XSCHEM did it" is
  an argument against keeping it.
* **The compatibility worry has no live dependent — measured, not assumed.**
  Every caller of the verb in the tree passes `-1`, `{}`, `0`, or an index it
  has already clamped into range:
  `src/op_annot.tcl:732` (-1); `utils/annot_mode.tcl:1684` (-1);
  `utils/annot_mode.tcl:1772` (`$last` = `$np - 1`, and `:1745` returns `{}`
  when `$np < 1`, so `$last` is never negative);
  `src/wave_viewer.tcl:14316-14329` (`0`, `$n - 1`, `$pos`, `$pos + 1`, behind
  `if {$n <= 0} {return {}}` and the `$pos >= $n - 1` clamp);
  `sky130A/sky130_procs.tcl:196-207` (-1);
  `montecarlo_mismatch_sim.sch:145,156` (0).
  Test callers likewise: `test_ase_persist.tcl:410` reads point 180 of a raw
  its own line 400 checks has 181 points; `test_op_annot.tcl:13482` reads point
  4 of a >= 5-point fixture; `test_annot_show_menu.tcl:1257` reads point 2 of
  the 5-point `e_tran.raw` written at its line 769-776;
  `test_cosim_golden_e2e.tcl:390` and `test_del_negative_arg.tcl:101` bound
  their loop counter by `xschem raw points`.
  **SGN18's operating-point leg is the only assertion in the tree of the
  behaviour being changed**, and this ruling changes it on purpose.

### What the user was told

"In the command window, asking a signal for a point number the results do not
have now comes back blank instead of quietly giving you the number under the
waveform cursor."

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29:

> "decide the 23, leave 0861 and 0299 for me"

The ruling queue had reached 57 entries and the user had said repeatedly that
the reading burden was too heavy. A read-only audit classified 25 of those
entries as questions whose answer is cheap and obvious — things that should be
DECIDED rather than put to the user. **This debt was one of the 23.** It was
decided on the user's behalf, under that instruction. (0861 and 0299 were
excluded and still belong to the user.)

This section SUPERSEDES the earlier "RULING — 2026-08-29, decided under the
user's 'decide the 23' instruction" block above it. That block was written
first, an adversary measured it against the code and overturned the
implementation while keeping the direction; nothing above has been altered, so
both readings stay on the record.

### The ruling, as an instruction to the codebase

**Same direction as the block above — a point number the results do not have
answers BLANK — but validate the POINT ARGUMENT ITSELF, not merely the integer
it decayed into.**

`xschem raw value <vector> <point> [dataset]` must answer blank for anything
that is not a point the loaded results actually have, **including the spellings
`atoi` silently rewrites into a different, valid-looking number.**

The rule, in the order the code should read it:

1. **Point given as empty `{}`, or as a well-formed NEGATIVE integer** (`-1`,
   the accessor every product caller uses): the waveform-cursor / annotation
   read, unchanged, still gated on `cursor_b_val && annot_p >= 0`.
2. **Point given as a well-formed non-negative integer that is in range:** the
   direct read, untouched — the leg rows SGN13, SGN14 and SGN22 fence.
3. **EVERYTHING ELSE answers blank:** an integer past the end (`99`); an
   integer too big for the point counter (`4294967295`, `2147483648`,
   `9223372036854775807`); a float (`2.5`); scientific notation (`1e9`); and
   plain garbage (`abc`).

### Why this was decidable rather than something to ask the user

* **RULING D5-1 and INVARIANT I3 settle the direction outright.** The number
  handed back is real, but the LABEL is fabricated — it is served as "the value
  at point 99" when it was measured at the waveform cursor. A point that does
  not exist is a missing reading, and I3 says a missing reading renders blank.
* **Blank is already this verb's answer for the nearest neighbour.**
  `src/op_annot.tcl:721-727` documents the three outcomes as: no results loaded
  → raises; vector absent → EMPTY STRING at rc=0; vector present → the number.
  A point that does not exist has the same shape as a vector that does not
  exist, so blank is consistency here, not a new convention.
* **The behaviour is an upstream accident, not a feature.**
  `git log -L 10625,10645:src/scheduler.c` shows the bare
  `else if(xctx->raw->cursor_b_val)` predates this branch (present at commit
  2f164336); branch commit 57eaa18d (item B3) added only the `annot_p >= 0`
  term. The documented contract at `src/scheduler.c:10404-10409` says the
  cursor read is asked for with an empty string `{}`; an out-of-range point
  number has no documented meaning at all. Under **CADENCE OR NOTHING**,
  "stock XSCHEM did it this way" is an argument AGAINST keeping it.
* **Raising a plain-English error instead was considered and rejected.**
  `src/wave_viewer.tcl:14316-14329` calls this verb four times per cursor move
  with no `catch`, so a raise would break the waveform readout bar; and it
  would give the verb a third shape for "not there" while the vector-absent
  twin stays silent. Blank wins on both counts.
* **No live dependent blocks it.** Every product caller passes `-1`, `{}`, `0`,
  or an index it has already clamped into range, and both product clamps are
  real guards. `SGN18`'s operating-point leg is the only assertion in the tree
  of the behaviour being changed, and acceptance criterion 3 above already
  names moving it as the intended outcome.

### What was verified in the tree, so a later reader need not re-derive it

* `src/scheduler.c:10625-10645` — the `raw value` arm as shipped: the in-range
  read fires first, then `else if(raw->cursor_b_val && raw->annot_p >= 0)`
  catches BOTH a negative/empty point AND an out-of-range positive one. The
  defect is live.
* `src/scheduler.c:10627` — `int point = argv[4][0] ? atoi(argv[4]) : -1;`, a
  bare `atoi` with no validation, one line ABOVE the arm the earlier block
  proposed to edit. This is what breaks the earlier block's own acceptance
  criterion 1: `atoi("4294967295")` and `atoi("9223372036854775807")` are `-1`,
  and `atoi("2147483648")` is `-2147483648`, so a `point < 0` term does not
  merely miss those three spellings — it is the term that ROUTES them to the
  cursor read. `atoi("1e9")` is `1`, `atoi("2.7")` is `2`, `atoi("abc")` is `0`,
  each quietly answering some other point's real value with no cursor involved
  and nothing in the answer hinting the request was not honoured.
* `src/scheduler.c:10630` — `if(argc > 5) dataset = atoi(argv[5]);`, the same
  unvalidated parse on the optional dataset argument; a bad dataset indexes
  `raw->npoints[dataset]` out of bounds.
* `src/scheduler.c:10404-10409` — the documented contract: only an empty string
  `{}` point is documented as the cursor-B read.
* `tests/headless/test_spice_get_node_0861.tcl:352-360` — row `SGN18` pins
  `{}` and `1.8`; its comment names 0920 as the open half. The ONLY assertion
  in the tree of the behaviour being changed.
* `tests/headless/test_zero_point_raw_0836.tcl:429-431` — a committed comment
  stating that on a zero-point database `raw value` "falls through to the
  my_calloc-zeroed cursor_b_val, returning a benign-looking 0." That sentence
  goes stale under this ruling and must be rewritten with the fix — the same
  wrong-comment-about-a-guard trap row SGN19 exists to prevent.
* Product callers, all safe: `src/op_annot.tcl:732` (`-1`);
  `utils/annot_mode.tcl:1684` (`-1`); `utils/annot_mode.tcl:1772`
  (`$last` = `$np - 1`, with `:1745` returning `{}` when `$np < 1`, so `$last`
  is never negative and never out of range);
  `src/wave_viewer.tcl:14316-14329` (`0`, `$n - 1`, `$pos`, `$pos + 1`, behind
  `if {$n <= 0} {return {}}` and the `$pos >= $n - 1` clamp);
  `sky130A/sky130_procs.tcl:196-207` (all eight calls `-1`);
  `montecarlo_mismatch_sim.sch:145,156` (`0`).
* Test callers checked and in range: `test_ase_persist.tcl:410` reads point 180
  of a raw its own line 400 checks has 181 points; `test_op_annot.tcl:13482`
  reads point 4 of a >= 5-point fixture; `test_annot_show_menu.tcl:1257` reads
  point 2 of the 5-point `e_tran.raw` written at its lines 769-776;
  `test_cosim_golden_e2e.tcl:390` and `test_del_negative_arg.tcl:101` bound
  their loop counter by `xschem raw points`.
* **Correction to the earlier block's scope claim.** That block asserted "every
  caller in the tree, measured not assumed" after opening 12 call sites; the
  verb is in fact called from ~40 files (255 occurrences of `raw value`),
  including `tests/headless/test_raw_ascii_point_bounds.tcl` (two
  `raw value $n $p` loops), `test_wave_markers.tcl` (row MF1 reads an unclamped
  marker index plus one), `test_zero_point_raw_0836.tcl`,
  `test_zero_point_pos_at_0852.tcl`, `test_wave_viewer.tcl`,
  `test_wave_cursor_crossdb.tcl`, `test_backannotate_digital.tcl`,
  `test_raw_read_dispatch.tcl`, `test_vcd_read.tcl`, `test_vcd_time_base.tcl`,
  `del_negative_arg_child.tcl` and `ihp-sg13g2/sg13g2_procs.tcl`. Most are in
  range; the sweep must be redone against the full list when the fix is built,
  and the conclusion re-checked rather than inherited.
* `src/ciw.tcl:3` — the command window ("Command Interpreter Window, after
  Virtuoso's") is a real user surface with a command entry, so this verb is
  something the user can type by hand. This is a user-visible change, not an
  internal one.

### This IMPLIES A CODE CHANGE — follow-up work, NOT YET DONE

Nothing here is shipped. The following is owed:

1. **`src/scheduler.c:10627`** — replace the bare
   `int point = argv[4][0] ? atoi(argv[4]) : -1;` with a `strtol` parse that
   keeps `endptr` and `errno`: reject on a non-empty leftover, on `ERANGE`, and
   on anything outside `INT_MIN..INT_MAX`; carry a `point_ok` flag. An empty
   `{}` sets `point_ok` with `point = -1`, exactly as today.
2. **`src/scheduler.c`, the `raw value` arm** — the arm then reads: the
   in-range direct read when `point_ok && point >= 0 && point < <bound>`; else
   the cursor read when
   `point_ok && point < 0 && raw->cursor_b_val && raw->annot_p >= 0`; else
   nothing. The `<bound>` split between `raw->npoints[dataset]` and
   `raw->allpoints` is unchanged.
3. **`src/scheduler.c:10630`** — apply the same validated parse to the optional
   dataset argument while the helper is right there; `atoi(argv[5])` on a bad
   dataset currently indexes `raw->npoints[dataset]` out of bounds.
4. **`src/scheduler.c`, the comment block above the arm** — rewrite the
   paragraph beginning "An OUT-OF-RANGE explicit point also lands on this arm"
   to state the settled rule instead of the open defect.
5. **`tests/headless/test_spice_get_node_0861.tcl` row `SGN18`** — the
   operating-point leg moves from `1.8` to blank, deliberately, and the row's
   comment stops pointing here as an open defect.
6. **New rows in the same suite, against a PUBLISHED database** — `1e9`, `2.5`,
   `abc`, `4294967295` and `2147483648`. These are the spellings that stay
   wrong under a bare `point < 0` term, so **without these rows the suite goes
   green over a live 0920** — the "passed while the bug is live" shape this
   repo has already shipped twice.
7. **`tests/headless/test_zero_point_raw_0836.tcl:429-431`** — rewrite the
   stale sentence describing the zero-point fall-through as returning "a
   benign-looking 0."

### What the user is told, in plain English

"In the command window, asking a signal for a point number the results do not
have now comes back blank instead of quietly giving you the number under the
waveform cursor. The same goes for anything that is not a plain whole number —
`1e9`, `2.5`, or a typo — which used to hand you some other point's value
without saying so. Asking with nothing at all, or with -1, still gives you the
value under the waveform cursor, as before."

### Adversary

An adversary ran against the first decision and **overturned it**: the
direction (blank) was right and genuinely not the user's question, but the
prescribed two-line edit was falsified by a ten-line measurement of `atoi`
against the line directly above the line it edits — four of the spellings a
user can type in the command window survive that fix, one of them (`1e9`)
sharper than the bug being fixed. The adversary's better answer — validate the
argument with `strtol`, and add the five rows that would otherwise let the
suite go green over a live defect — is the ruling recorded above.

**The user may reverse this at any time; it was decided to spare their
attention, not to bind them.**
