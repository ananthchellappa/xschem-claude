# 0835 — three anti-hollow twins were mis-attributed, and one converted path had NO positive cover at all

**Status: FIXED 2026-08-26 (in item 0831's own commit — it is 0831's defect).**
Found by item 0831's sabotage agent (Verify-B), confirmed and closed by its
write-up agent.

## 1. Why this exists

Issue 0828 is "a suite that passes when the feature is gutted". Item 0831 wrote
negative rows for nine converted injection sinks and, for three of them, claimed
an **existing** row as the anti-hollow twin instead of writing one. Sabotage
measured all three claims and **all three were wrong**. Two were harmless
mis-namings; one was a real hole — an entire converted code path with no positive
coverage anywhere in the repository.

This is the same shape as 0831 itself: a guard that certifies its own blind spot.
0831 §6 said "the guard is only as good as its proc list"; this says **an
anti-hollow claim is only as good as the branch the named row actually takes**.

## 2. The real hole — `libmgr::open`'s argument path, ZERO positive cover

`scheduler.c:8109` was converted to
`tcl_call("libmgr::open", argv[2], NULL, NULL)`. `test_lib_manager_launch.tcl`
carried this comment next to the new negative row LL8:

    # ⚠ ANTI-HOLLOW (issue 0828): the positive twin is LL1 above — the window must
    # still open. A conversion that simply stopped calling libmgr::open would pass
    # LL8 and fail LL1, which is the point of keeping them in one file.

**Measured, Verify-B, sabotage `sab_noop_all`** (every new `tcl_call` renamed to a
`tcl_call_nop` returning `""`, rebuilt):

    test_lib_manager_launch: RESULT: ALL PASS      <-- with the argument path GUTTED

Nothing in the file went red. LL1 (:20-22) and LL6 (:47-49) launch with **no
argument**, so they take `scheduler.c`'s untouched
`else tcleval("libmgr::open")` branch and never reach the converted call.

The hole was wider than one file. Write-up agent's grep across the whole repo:

    $ grep -rn 'xschem library_manager' tests/ | grep -v '^\s*#'
    ... every hit is a BARE launch, LL7's menu-string assertion, or LL8's payload row

`test_lib_manager_locate.tcl` looks like the twin — its header comment even
describes the cascade `xschem library_manager {lib cell view} -> libmgr::locate`
— but its body calls **`libmgr::locate` directly** (`:38`) after a bare
`library_manager` (`:34`). It never enters the C dispatcher with an argument.
So the scout's inventory line "drives `xschem library_manager {lib cell view}`"
was also wrong, and **no test in the repo drove the converted path**.

### The fix: LL9

`test_lib_manager_launch.tcl` gains a positive twin that drives the real door:

    xschem library_manager [list $LL_LIB $LL_CELL $LL_VIEW]
    -> all three panes must pre-select that lib/cell/view

The launch suite's default `library_defs_registry` is **empty**, so LL9 points
`XSCHEM_LIBRARY_DEFS` at the in-repo OA registry the way
`test_lib_manager_locate.tcl` does, and restores both globals afterwards.

**AFTER, on the fixed binary:**

    ok:   LL9 library_manager lcv argument still ARRIVES and pre-selects (0835)
          (=> got devices/adc_bridge/symbol want devices/adc_bridge/symbol)
    RESULT: ALL PASS

**Non-vacuity, proved without a build.** The write-up agent may not run `make`
(crew rule 2), so the C-side no-op could not be reproduced. A **Tcl-side**
sabotage is a faithful proxy for "the argument never arrives":

    rename libmgr::open libmgr::__real_open
    proc libmgr::open {{lcv {}}} { libmgr::__real_open {} }   ;# drop the argument
    source tests/headless/test_lib_manager_launch.tcl

    FAIL: LL9 library_manager lcv argument still ARRIVES and pre-selects (0835)
          (=> got // want devices/adc_bridge/symbol)
    RESULT: 1 FAILED

LL1, LL6 and LL8 stayed green throughout — reproducing exactly the false ALL PASS
Verify-B measured, and showing LL9 is what closes it.

## 3. Mis-attribution A — `ciform::open` (harmless, comment corrected)

`test_create_instance.tcl` claimed CI16's twin was **CI1a**. CI1a calls
`xschem create_instance` **bare**, taking the untouched
`else tcleval("ciform::open")` branch. Under `sab_noop_all` CI1a stayed green.

The converted argument path at `scheduler.c:2729` **is** genuinely covered — by
**CI13a / CI13c / CI13d** (which pass `{tlib withsym symbol}`) plus CI6b-CI6h and
CI7e; Verify-B measured 11 of those red. So CI16's protection existed; the
comment named the wrong row. Corrected in place, with the measurement.

## 4. Mis-attribution B — `replace_symbol` (harmless, comment corrected)

`test_raw_read_dispatch.tcl` claimed the hygiene site `scheduler.c:12393` was
covered "by test_pin_type_edit.tcl / test_perform_action_replace_symbol.tcl".

Verify-B, sabotage `sab_replace_symbol_nop`:

    test_pin_type_edit:                PASS=14 FAIL=5 OVERALL: notok   <-- catches it
    test_perform_action_replace_symbol: RESULT: ALL PASS               <-- does NOT

That suite tests the `xschem replace_symbol` **subcommand** — the *callee* —
whereas `scheduler.c:12393` is a *caller* of it from `set_pin_type`. Gutting a
caller cannot fail the callee's own suite. **`test_pin_type_edit` is the only
cover for that site**; the comment now says so.

Secondary, recorded so a later receipt does not misquote it: run without
`--logdir`, `test_perform_action_replace_symbol` prints
`deferred (no --logdir; the perform_action log site needs an open action log)`
and its log-count rows do not execute at all.

## 5. Ladder / decision

**L2** (least surprising, smallest blast radius). Write the one missing positive
row and correct the two false comments, in item 0831's own commit, because they
are 0831's own defect and shipping them would repeat 0828 one item after 0828 was
fixed.

**REJECTED — file it and move on.** A knowingly-false anti-hollow comment is worse
than no comment: the next crew greps for the twin, finds a green row, and believes
the path is covered. That is precisely how 0831 itself shipped.

**REJECTED — also fix `test_lib_manager_locate.tcl`'s misleading header.** Out of
scope for this item and it changes no behaviour; recorded here instead. Its `:1-2`
comment describes a cascade its body does not drive.

## 6. Still open

* Nothing in this issue is unfixed. The three claims are corrected and the missing
  row exists.
* **The general lesson is not enforced by anything.** No guard checks that a row
  named as an anti-hollow twin actually executes the converted branch. Every such
  claim in this repo is still prose. A `sab_noop_all`-style pass is the only thing
  that tests it, and it needs a build — so it cannot be a headless suite row.
* `test_lib_manager_locate.tcl:1-2`'s header still describes a C-verb cascade its
  body bypasses (§5, rejected alternative).
