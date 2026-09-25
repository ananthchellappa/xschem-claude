# Decisions — issue 1606 batch

## G1 — the driver's prediction, registered BEFORE Stage A reports

Recorded at `34913077`, so the measurement tests this rather than confirming it. The 1607 and
1603 batches both ran this way and a crew caught the driver overstating his instrument each
time; that is the point of registering it.

**Prediction: the fix is a clamp, it lands in two or three places rather than twelve, and the
issue's option 3 is not viable in this tree.**

The reasoning:

* **`xctx->ev_precision` has exactly two unclamped writers**, `draw.c:9011` and
  `draw.c:10595`, both `tclgetintvar("ev_precision")`. Nine of the twelve sites read it
  directly or one hop away (`nd_view.prec`, `engineering`). Clamping at those two writers
  bounds nine sites in two lines.
* **`dtoa_eng` must clamp its own parameter regardless**, because it owns the smallest buffer
  (80 bytes) and has 27 callers, one of which — `eval_expr.c`'s `engineering` — is a
  different variable entirely. A fix that only clamps the writers leaves `dtoa_eng` correct
  by coincidence rather than by construction, and the next caller to pass a number from
  somewhere new reopens it.
* **Option 3 is blocked by the build, not by the code.** `HAS_SNPRINTF` is defined nowhere in
  this tree, so `my_snprintf` is the hand-rolled formatter, and two separate source comments
  (`save.c:2894`, `draw.c:7743`) record someone measuring what it does with `%.*g`. Teaching
  it `*` means extending a hand-rolled varargs formatter used tree-wide — a much larger
  blast radius than a clamp, for the same outcome at these twelve sites.

⚠ **What would refute it.** A clamp at the two writers turning out **not** to reach the
reproducer (e.g. `draw()` never runs on the headless arm, so `ev_precision` stays 4 and the
abort comes from somewhere the driver has not found); or a thirteenth writer; or
`my_snprintf`'s hand-rolled arm turning out to already handle `*`, which would make option 3
cheap and better.

⚠ **What must NOT happen if the prediction holds.** "Two lines" is not a reason to skip the
per-site fences. The 1603 batch's four guards were justified by a **measurement** — flipping
one token upstream produced two sequential segfaults — and the same standard applies here:
if a clamp at the writers is what protects `token.c`'s seven `dtoa_eng` calls, then deleting
that clamp must redden a row, or the protection leaves silently the day someone refactors
`draw()`.

## G2 — the ceiling is the user's, and it is already filed

Clamping **changes what a user with `set ev_precision 200` in their `~/.xschem/xschemrc`
sees**: an abort today, some bounded number of digits after. That is user-visible on an
obscure path, so it is a ruling and not the driver's to make silently. **`rule/1606` is
already on the owed ledger**; this batch implements the recommended shape and says so, per
the standing instruction that a needed decision is filed and then implemented rather than
waited on.

The recommended shape, for when the user is asked: **clamp, and clamp per buffer rather than
globally to 71.** A single global 71 would be wrong in both directions — it under-serves
`draw_graph_variables`'s 1024-byte buffer and it is one byte too generous for `dtoa_eng`'s
80-byte buffer at a negative value in the `1e12` branch, which is the arithmetic the 1602
crew used to pick 71 in the first place. One helper that takes the buffer size and returns
the safe precision is the same number of lines and cannot drift from the buffer it protects.

⚠ **The alternative worth stating to the user, because it is not obviously worse**: refuse
rather than clamp — leave the value alone and print an error once, so a user who typed 200
learns their rc file is wrong instead of silently getting 71. Against it: the error would
have to fire from inside `draw()`, i.e. on a redraw path, where a dialog is the last thing
anyone wants.

## G3 — internal test engineering is the driver's and the crews', not a ruling

Per the standing instruction: how a row is structured, whether a fence is static or
behavioural, what a suite is named, and which list it registers in are decided here and
stated, never queued. Only the clamp's user-visible consequence (G2) goes to the user.
