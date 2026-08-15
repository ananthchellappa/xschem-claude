# 0220 — `change_index.tcl`'s `+`/`-` loop can cascade: `A[0]→A[1]` then `A[1]→A[2]` merges two nets

Status: **OPEN — but see "Two lenses disagreed" below; verify before acting**
Severity: medium *if* it reproduces; the trigger is **opt-in and unreachable as shipped**
Introduced by: `74ef1aed`, arrived on `fluid-editing` via merge 3 (`958ada03`).
Found by: the merge-3 interaction audit.

## Claimed symptom

`src/change_index.tcl` bumps the bus index of every selected object, one
`xschem setprop instance <n> lab <new>` per object (`src/change_index.tcl:13`, bound to
`+`/`-` at `:18-19`). It is **not** `-fast`, so each iteration now propagates.

On a sheet with `ipin A[0]`, `ipin A[1]` and one unselected `lab_pin` for each, select just
the two pins and press `+`:

1. `A[0] → A[1]` propagates, rewriting the `A[0]` label to `A[1]`.
2. `A[1] → A[2]` now sees **two** labels reading `A[1]` — the one it owns and the one step 1
   just moved. It reports `PRR_MERGE`, or refuses.

End state: both labels read `A[1]` while the ports read `A[1]` and `A[2]`, and port `A[2]`
has no label. Nets `A[0]` and `A[1]` are shorted through the labels.

## Corrections the verifier applied to the original claim

1. **Direction-dependent, not unconditional.** `xschem selected_set` returns instance *names*,
   not indices (`src/scheduler.c:10776`), which `change_index` passes to `get_instance`
   (`src/scheduler.c:11473`). The cascade needs ascending instance order with `+` (or
   descending with `-`). The opposite pairing — `A[1]` then `A[0]` under `+` — propagates
   both labels correctly.
2. **The ERC framing in the original claim was wrong.** The *pins* end at `A[1]`/`A[2]` both
   pre- and post-merge, so `sym_vs_sch_pins` reports the identical mismatch either way. The
   merge does not erase that evidence. What is genuinely new is only the label-borne short.
3. **Currently unreachable.** `lappend tcl_files ${XSCHEM_SHAREDIR}/change_index.tcl` ships
   **commented out** at `src/xschemrc:589`, and it is commented in the user's
   `~/.xschem/xschemrc` too. Reproducing needs an explicit opt-in.

## Two lenses disagreed — resolve this before fixing

- The **branch-interactions** lens filed the cascade above, and an adversarial verifier
  confirmed it (with the three corrections).
- The **c-correctness** lens independently concluded the opposite: *"`change_index.tcl:14`
  (`+`/`-` keys) is genuinely protected by the `PRR_SELECTED` refusal for both selection
  orders."*

Both cannot be right. `PRR_SELECTED` refuses when a *matching label* is selected; in the
scenario above the labels are **unselected**, which is why the branch-interactions reading
looks stronger — but this has not been run. **Reproduce it manually before writing a fix**;
a fix aimed at a refusal that already fires would be worse than the defect.

## If it reproduces

The clean shape is a caller-side "one outer undo, N renames" contract that suppresses
propagation for the whole loop, the same thing [0219](0219-fast-carve-out-is-too-broad-find-navigator-bulk-rename-strands-labels.md)
needs from the other direction — `-fast` is the wrong axis for both.
