# 1329 — ruling DD-16's cross-sheet clause is FALSE through a symlink

**Status: FILED, NOT FIXED.** Found by item **B5-3**'s adversary while
verifying ruling **DD-16**, reproduced independently by the write-up agent.
Subject: `rdw::_sheet_note` (`src/rdw.tcl:2238`).

## What DD-16 asked for

> a **cross-sheet edit is ALLOWED**, and the status line names the source sheet
> **only when it differs** from the sheet now open.

## What was built

`rdw::_sheet_note` compares the block's stamped `schname` against
`xschem get schname` as **plain strings**, which was a deliberate, recorded
choice (item B5-3, ladder rung L2): `file normalize` does not resolve a path's
final component (issue **1327** established that), and the store's real
predicate — `op_param_lists::_fid`, device+inode — is a **private** verb that
window row **BT22** forbids `src/rdw.tcl` from naming.

The proc's own header asserts the two values

> are byte-identical whenever they name the same sheet — measured directly.

**That sentence is false.** It is true of the fixture shape it was measured in,
and not of a symlink.

## The measurement

Before (the claim, as written in `src/rdw.tcl`): the two strings are
byte-identical whenever they name the same sheet.

After (measured on this tree, `./src/xschem --nogui --pipe -q --nolog`, with
`a_link.sch` a symlink to `a.sch` in the same directory):

```
REAL=/tmp/.../wu/a.sch
LINK=/tmp/.../wu/a_link.sch
STRING_EQ=0
NOTE=That dump was taken on /tmp/.../wu/a.sch, which is not the sheet now open
     - these are class and device-flavor settings, not sheet state, so the edit
     applies wherever you are standing.
```

One sheet, opened twice by two names, and the user is told the dump came from
somewhere else.

## Blast radius

**One wrong advisory sentence, never a wrong write.** DD-16 rules that the
cross-sheet edit is *allowed*; the clause is advice, not a gate. The edit lands
on the stamped class either way, which is the behaviour item B5-2 died for and
which is correct here. Nothing is refused, nothing is mis-stored.

It is still worth fixing: this feature's whole standard is that different facts
get different, complete, TRUE sentences, and issue 1327 is the same mistake one
layer down — a string compare standing in for file identity.

## Recommended fix

Publish the store's existing predicate rather than inventing a second one
(invariant **I1**, one rule, two consumers): a **public**
`op_param_lists::same_file {a b}` wrapping `_fid`, added to **BT22**'s
allow-list, called by `_sheet_note`. Rejected alternatives:

* `file normalize` on both — issue 1327 measured that it does not resolve the
  final component, so it does not establish file identity and would leave the
  same defect wearing a longer path;
* calling `op_param_lists::_fid` directly from `rdw.tcl` — BT22 golds
  `op_param_lists::_` at ZERO occurrences in that file, deliberately;
* dropping the clause — DD-16 requires it.

## Acceptance

A row proving all four arms: same path → no clause; genuinely different sheets
→ clause; **the same file reached by a symlink → NO clause**; a `schname` that
is absent, empty, or names a file that does not exist → no clause and no raise.
The fourth arm matters because `same_file` must not turn a missing file into an
error inside a status path.

## Still open

Nothing else. The three DD-16 rows that exist today (window **BT29**, **BT30**)
stay valid; a symlink arm is an addition to them, not a replacement.
