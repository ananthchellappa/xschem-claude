# 0447 — op_annot::text RAISES on a malformed descriptor list, and its own header says it never does

STATUS: open, measured, NOT fixed. Found by the S5 adversary (Verify-C), independently
re-confirmed by the S5 write-up agent before the step was committed.
BLOCKS: S6 must not land the PDK-neutral carrier symbol until this is closed or accepted.
SEE ALSO: 0446 (the other confirmed I3 hole in the same proc), 0425, 0444.

## Symptom

`op_annot::text` is documented in its own header (src/op_annot.tcl, the block ending
`## NEVER RAISES, on any path — S6/S9 call it from a draw/tcleval path.`) as never
raising. It does raise. `op_annot::register` validates only `dict size`, so a descriptor
whose `params`, `pinexpr` or `derived` value is not a well-formed Tcl list is ACCEPTED at
rc=0 and stored; the raise then happens later, at DRAW time, inside

    foreach row [dict get $d params]     ;# src/op_annot.tcl:652
    foreach row [dict get $d pinexpr]    ;# src/op_annot.tcl:672
    foreach row [dict get $d derived]    ;# src/op_annot.tcl:689

none of which is inside a catch.

Reachable through invariant I5 — "a user's op_annot::register in their own rc overrides
the PDK's" — by a single unbalanced brace in a hand-written descriptor.

## Measured — BEFORE (this is the state as committed at S5)

Re-measured by the write-up agent on the committed tree, binary src/xschem (Aug 16 10:26),
`DISPLAY=:99 GUI_GATE=0 ./src/xschem --nogui --pipe -q --nolog --script <t>.tcl`.
The malformed string is built from `\173`/`\175` so the driver script itself parses:

    set MAL "{id id 0} {gm gm 1"        ;# one unbalanced open brace

Verbatim transcript:

    type of M1 -> nmos
    devpath    -> @m.xm1.msky130_fd_pr__nfet_01v8
    ATTACK1 params  -> register rc=0 | text rc=1 err='unmatched open brace in list'
    ATTACK1 pinexpr -> register rc=0 | text rc=1 err='unmatched open brace in list'
    ATTACK1 derived -> register rc=0 | text rc=1 err='unmatched open brace in list'

All three list-valued descriptor keys fail the same way, and in every case `register`
returned rc=0 and stored the descriptor.

## Why this is a defect and not merely hostile input

THE SAME FILE ALREADY TREATS THIS EXACT CLASS AS A DATA CONDITION. op_annot::_matches
wraps its `foreach g $globs` in a catch, with the comment that a malformed glob list is a
DATA condition, and `op_annot::devpath` with a malformed `match` list correctly returns
`{}` at rc=0 — measured, same session:

    A3 register with malformed match -> rc=0     (and devpath -> {} , no raise)

So the discipline exists in the file, was applied to `match`, and was not carried into
`text`. That asymmetry is the defect.

## Blast radius today: NONE, and that is why S5 shipped anyway

Nothing in the tree calls `op_annot::text` yet — the PDK-neutral carrier symbol is S6 and
does not exist, and the three shipped annotator symbols still name the per-PDK prototype
procs. The raise is therefore unreachable by any user today.

Verify-C also measured the degraded behaviour for when S6 does land: driven through the
real draw path (`xschem translate annot1 {tcleval([op_annot::text @ref ])}`), tcl_hook2
absorbs the raise and renders `?` rather than breaking rendering. So the eventual cost is
a `?` block on the schematic, not a crash — bad, but not fatal.

## Fix options (not chosen here; whoever closes this decides)

1. VALIDATE AT REGISTRATION, loudly. `op_annot::register` already rejects an odd-length
   dict; extend it to require that params/pinexpr/derived each parse as a list (and that
   each row has the arity its key needs). Turns a silent draw-time raise into a loud rc=1
   at rc-source time, which is where a user can actually act on it. PREFERRED by both the
   adversary and this write-up: the failure lands next to the typo.
2. CATCH AT READ, quietly. Wrap each of the three `foreach`es (or one `catch {lrange …}`
   normalisation, the shape op_annot::_matches already uses) so a malformed key degrades
   to "no rows from this key" and the block still renders whatever is well-formed.
   Consistent with the file's existing `match` handling and with I3's blank-not-wrong rule.
3. BOTH — validate at register, and keep a read-side catch as defence in depth, since I5
   allows a descriptor to be replaced at any time from any rc.

Both 1 and 2 are inside S5's own declared Files cell (src/op_annot.tcl). This was NOT done
in S5 because the S5 write-up agent is not the implement agent and a late unverified edit
would ship without the crew's sabotage and adversary passes.

## Test rows owed when this is fixed

* register with a malformed `params` / `pinexpr` / `derived` value -> rc=1 naming the key
  (option 1), or `text` -> rc=0 (option 2). One row per key: the S5 measurement shows all
  three fail independently, so a single row would leave two uncovered.
* the existing `match` row stays green either way — it is the precedent, not the subject.
* COVERAGE HOLE TO CLOSE AT THE SAME TIME (Verify-B, unplanned probes EXTRA-A/EXTRA-B):
  deleting `op_annot::text`'s descriptor guard, or its type guard, reds NOTHING — the
  suite stays 97/97. All three early returns in `text` are mutually redundant and no
  single-point failure in any one is detectable. Rows S19/S20 claim to cover them but are
  caught by an earlier guard and never reach the one they name.

---

## S6 ACCEPTANCE — measured through the shipped carrier, ACCEPTED, NOT FIXED (2026-08-19)

`src/op_annot.tcl:636-650` says in terms that "S6 must not land the carrier
symbol until it is closed or explicitly accepted." **S6 accepted it.** This is
that record.

### BEFORE (S6's Measure agent, verbatim)

    B04 op_annot::text proc exists                               : 1
    callers of op_annot::text tree-wide, excluding src/op_annot.tcl and
      tests/headless/test_op_annot.tcl -> (count: 0)

The raise existed but reached no draw path, because no draw path called the proc.

### AFTER (S6, through `devices/annotate_params`)

A descriptor whose `params` value is not a well-formed Tcl list still registers
at **rc=0** (`register` validates only `dict size`), `op_annot::text` still
raises `unmatched open brace in list` — and through the carrier the raise is
absorbed by `tcl_hook2` → `tclpropeval2`'s `catch`, which returns `?\n`. The
block renders a single **`?`**. Measured, in one process, both halves.

So the cost through the carrier is **bounded degradation, never a crash**, and it
is the same failure mode the three shipped PDK prototype carriers have had for
years on their own failures.

### The decision — ladder rung L3 (user-visible, no prior ratification)

**D6. The carrier ships with 0447 open.** Rejected: adding list validation to
`op_annot::register` (this issue's own option 1, and still the preferred fix). It
is out of S6's Files cell, and — the substantive reason — it **changes a shipped
proc's rc contract**, so a user's malformed rc would begin raising at STARTUP
where today it degrades at draw. That is a better failure, but it is a
user-visible behaviour change that belongs to a step that owns `op_annot.tcl`
and can run the full sabotage/adversary passes on it. Reachable only via **I5**,
from a user's own rc.

### Pinned by a green check that asserts the DEGRADED behaviour

`tests/headless/test_op_annot.tcl` row **K17**, which **must run last in section
K** — it destroys the nmos descriptor. It asserts rc=0 at register, the raise
from `text`, and `?` through `translate`.

**⚠ K17 IS NOT SPECIFIC TO THIS MECHANISM.** S6's sabotage pass found it passes
VACUOUSLY under variant SB1 (the `@ref])` no-space spelling), which also renders
`?`. Any breakage that yields `?` satisfies K17. When this issue is fixed, K17
must be replaced by the per-key rows this file's "Test rows owed" section
specifies, not merely inverted.

### LEDGER QUESTION STILL OWED TO A HUMAN

> Is a `?` block an acceptable failure mode for a user's own malformed
> descriptor, or must `op_annot::register` reject it loudly at rc-source time?

S6's status is **E** for this question among others.
