# 0674+0675+0677 — the rejected notify-channel attempt (2026-08-25)

Status **F**: built, measured green on six suites, **refuted by its own adversary
leg, and reverted**. `src/` is byte-identical to `e9232ec3`. The three issues
stay OPEN and carry what to do differently; see also the plan block
`❌ 0674+0675+0677` in
`doc/claude/suggestions/next_session_prompt_op_annotation.md`.

| file | what it is |
|---|---|
| `rejected_attempt.patch` | the complete working diff (1885 lines), re-appliable with `git apply`. **Most of it is right — start from it.** |
| `refutation_popup_iconified.tcl` | the driver that refuted it: `popup` style, other sinks destroyed, `wm iconify .xschem_notify` → the channel passes its own new test, reports delivered, names a sink, reaches nobody, says nothing |
| `head_popup_mark.tcl` | the same probe against **pristine HEAD**, proving the ungated popup mark is a HEAD-level defect (issue **0800**), not an artifact of the attempt |

Both drivers need a display and a log:

```sh
DISPLAY=:99 GUI_GATE=0 XSCHEM_SHAREDIR=<snapshot> \
  ./src/xschem --pipe -q --logdir <dir> --script <driver>.tcl
```

Use a snapshot `XSCHEM_SHAREDIR` (a directory of symlinks to `src/` with the four
`.tcl` files replaced), not the live tree: concurrent agents mutated
`src/xschem.tcl` during this run and corrupted a verify pass.
