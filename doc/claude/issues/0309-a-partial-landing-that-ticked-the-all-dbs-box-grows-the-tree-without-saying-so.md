# 0309 — a `partial` landing that had to tick the All-DBs box grows the tree without saying so

**Status:** OPEN. Not fixed. Nothing it reports is FALSE — the omission is that one fact
(the box was ticked on the user's behalf, so the tree just grew) is not mentioned on the
path where the walk also landed short.
**Area:** `src/wave_viewer.tcl` — `wviewer::browser_show_db_scope` (`:10673`), the two
returns at its tail; `wviewer::browser_msg` (`:10809`) and `wviewer::browser_say`, which
between them own every outcome sentence.
**Found:** 2026-08-10, by the adversarial review of batch F item 5's salvage pass.
**Related:** spec `doc/claude/specs/mixed_signal_signal_browser.md` §F, RULINGS **F1c**
(the tick, and R12's rule "grew the tree without being asked, so say so") and **F1e**;
two-pane item 18's **R12**, which is the same ruling one database over.

---

## Mechanism

`browser_show_db_scope` ends with three mutually exclusive returns, in this order:

```tcl
  if {$matched < [llength $segs]} {
    return [wviewer::browser_say $token partial $id $landed $scope]
  }
  if {$ticked} {
    return [wviewer::browser_say $token alldbs $id $landed $scope]
  }
  return [wviewer::browser_say $token ok $id $landed $scope]
```

`partial` is tested first, so a walk that ticked the All-DBs box **and** then landed only on
an ancestor reports `partial` and never reaches the `alldbs` arm. `partial` renders

> `no signals under 'TOP.m' - showing TOP instead`

which is true and useful — but the box is now ticked, the tree has grown by every other
database's rows, and no sentence anywhere says so. R12's own rule is that a tree which grew
without being asked must announce it; this is the one combination where it does not.

## Reproducer

From the review of item 5 (real viewer, `DISPLAY=:0`). A VCD declaring two scopes
(`TOP.m.siga`, `TOP.n.sigx`), the All-DBs box OFF, and a Filter pattern of `*sigx*` in the
sidebar's filter bar. Ask for scope `TOP.m`:

```
res      = partial d:1|g:TOP TOP TOP.m
CIW says = no signals under 'TOP.m' - showing TOP instead
alldb box = 1        <-- ticked on the user's behalf, and `partial` never reports it
```

**⚠ THE EARLIER "near-unreachable" RULING IS WITHDRAWN.** The salvage pass recorded this
combination as not worth fixing on the grounds that `browser_names_under` gates the tick on
the database really carrying names under the scope, making a subsequent short landing
near-impossible. The review reached it on the first try: `browser_names_under` asks whether
the INVENTORY carries such names, while `browser_node_for` walks the TREE, and a Search or
Filter bar narrows the second without touching the first. Any state where those two
disagree reaches this path.

## Why it was not fixed with item 5

Item 5's defect was a *falsehood* — RULING F1e's notice named the scope that was asked for
rather than the one the tree landed on, so on this same `partial` path it asserted
"showing the digital scope 'TOP.m' in the tree" one statement after the CIW had said the
opposite. That is fixed (the sentence now names `[lindex $res 2]`, the landing; `FV45`).

What remains is an omission, and closing it is not a one-liner:

* a twelfth `browser_msg` kind is needed (say `partialdbs`), because the two facts —
  "landed short" and "grew the tree" — cannot both fit in an existing arm without one of
  them drifting from its own wording, which is the drift RULING 5f-3 forbids;
* `browser_say` needs the matching mint, with the positional-argument meaning spelled for
  it as the other kinds have;
* and `BK33` (`tests/headless/test_wave_sigbrowser_keys.tcl:369`) is the nine-legged control
  over every shipped rendering, carrying a deliberately MOVING leg — the formatter's
  `return` count, already restated 9 → 10 → 11 by earlier items. A twelfth arm is a third
  restatement of that check, which must be done deliberately and in the same commit.

## The fix, when someone takes it

Reorder the tail so the tick is not swallowed, and give the combination its own sentence:

```tcl
  if {$matched < [llength $segs]} {
    return [wviewer::browser_say $token \
              [expr {$ticked ? {partialdbs} : {partial}}] $id $landed $scope]
  }
```

with `browser_msg`'s new arm reading something like

> `no signals under '<asked>' - showing <landed> instead, across every results database`

Do it in one commit with the `BK33` restatement (count leg 11 → 12, the new rendering
asserted BESIDE the eleven rather than instead of one of them), and add the behavioural
check that the ticked-and-short path reports the new kind — the existing `FD17` covers the
short landing but with the box already ON, so it cannot see the tick.
