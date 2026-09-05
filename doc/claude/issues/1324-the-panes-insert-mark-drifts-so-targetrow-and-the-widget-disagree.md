# 1324 — the pane's `insert` mark drifts on every new dump, so "the row your cursor is in" and `::rdw::targetrow` disagree

**Status:** FILED, NOT FIXED. Measured 2026-09-04 on `:99` against item B5-2's
working tree (preserved patch, md5 `42890cf163dd9ba1e85e312e1801c6ed`); reverted
with it, so the code this describes is not in the tree.
**Component:** `src/rdw.tcl` — `rdw::render_pane`, `rdw::set_row`,
`rdw::_target_line`, `::rdw::targetrow`.
**Related:** issue **1308** (the window holds the keyboard), issue **1306**, the
`nhse_op_target` precedent at `src/xschem.tcl:1314`.

## The mechanism

B5-2 adopted the `nhse_op_target` idea — *"the row your cursor is in"* — and
implemented it on the read-only text pane's own `insert` mark, which was the
right call (it adds no focusable widget and so avoids issue 1308). But
`rdw::render_pane` rebuilds the pane with

```tcl
$t delete 1.0 end
… insert at end, one entry per line, newest block first …
```

A Tk text mark has **right gravity** by default: `delete 1.0 end` collapses every
mark to 1.0 and the subsequent inserts carry `insert` along to the very end. So
each new `rdw::push` silently moves the cursor to the trailing empty line, while
`::rdw::targetrow` still holds the number the user last clicked.

## The measurement

On `:99` with a real Tk pane:

```
after set_row 3      : insert=3.0   _target_line=3   targetrow=3
after one rdw::push  : insert=9.0   _target_line=9   targetrow=3
```

The widget and the variable disagree — which `set_row`'s own comment states can
never happen.

## The consequence, and why it is a confusion and not a corruption

The mark always lands on the **trailing empty line**, never on another device's
parameter row, so the user gets a refusal (*"line 9 is not a parameter row"*)
rather than an edit to the wrong thing. That makes this a usability defect, not
a data defect — but a sharp one, because the pane is `-state disabled` and
therefore **draws no insertion cursor at all**. There is no cue on screen. The
user clicked a row, watched a new dump arrive, pressed Delete, and was told the
line they can plainly see is not a parameter row.

## Recommended fix

`render_pane` **re-establishes the mark it had** after rebuilding: remember the
block identity and parameter the target named (not the raw line number, which is
meaningless across a re-render that puts a new block on top), and re-point
`insert` at that row if it still exists, else clear the target explicitly and say
so. Clearing loudly is better than drifting quietly.

Whatever is chosen, **the pane must show the user which row is targeted.** A
`-state disabled` text can still carry a tag-based highlight on the target line;
that is the smallest thing that makes the feature honest.

Rejected alternative: **left gravity on the mark.** It survives the inserts but
not the `delete 1.0 end`, so it fixes nothing and reads as though it had.

## Still open

All of it — and note that this belongs on the eventual `look` debt explicitly,
in the form *"press 1 twice, then press Delete, and see whether the window can
still tell you which row you are on."* No count can see it: every suite row sets
the target and acts on it within one render.
