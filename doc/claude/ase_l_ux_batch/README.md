# ASE-L UX batch — 2026-09-09

Asked for: *"a detailed analysis of brokenness in UX of the ASE-L. I think fonts, etc
could stand to improve. How can we make it slick?"*

⚠ **This line said "Nothing here has been implemented. `src/` is untouched" until
2026-09-21, and it was false by then.** Three of the plan's items have shipped. Measured
`git diff --stat 437a3add 2f1fad58 -- src/` at the time the sentence was corrected:
**+742/−56** across `ase_window.tcl`, `xschem.tcl` and `cadence_style_rc`. What is in the
tree, and what is not:

| item | status | commits |
|---|---|---|
| **1** Save State confirm (issue 1396) | **DONE** | `5fb8f465` |
| **2** fonts and theme (issue 1398) | **DONE**, in TWO commits | `4ddc4900`, then `2f1fad58` (the size the user called *"noticeably smaller than before"*) |
| **3** the clip: tooltip + log scrollbar (issue 1499) | **DONE for the ruling-free half**; the visible `…` waits on ⚖ R-U1 | see `LEDGER.md` |
| **F2** the Value column reads the answers (issue 1498) | **DONE** | see `LEDGER.md` |
| **F1** one producer for pane and deck | **NO-GO — already delivered** by `ase_analyses_batch` (issues 1417–1474), and past what this plan asked for | — |
| everything else | not started; **gated on the seventeen rulings R-1…R-17**, which are the user's | — |

⚠ **`PLAN.md` IS STALE AND MUST BE READ AS A CLAIM.** Its baseline is `437a3add`; 299
commits later `src/ase_window.tcl` is **15 177 lines** against the plan's **7 491** — it
has more than **doubled** — and **every `:NNNN` in it is wrong** (three spot-checked moved
by +1 300 to +5 000 lines). Its **proc names all still resolve** — cite by name, never by
the plan's line numbers. Two of its factual claims are refuted in `receipts/recon.md` §1
and in issue 1499.

⚠ **This paragraph said "12 000+ lines" until the fix round of 2026-09-21.** True as
written, and it understated the drift the sentence exists to warn about by 3 000 lines —
"12 000+" reads as a file that grew by half, and the file has doubled. Measured twice, two
ways, off `git show 6a0d1126:src/ase_window.tcl` (`wc -l` and `awk 'END{print NR}'`, both
**15 177**; the file ends in a newline, so the two agree); **15 454** in the working tree
as the implementer left it and **15 480** after the fix round. `receipts/verify.md` N2
records 15 170 for `6a0d1126`, which is 7 short — take the number above.

The rest of this file is the original analysis and proposal.

| file | what it is |
|---|---|
| `MEASUREMENTS.md` | 15 measurements taken on the built binary on the dev display, against the user's own `sky130_tests_ase/tb_bandgap` bench. Two carry ⚠ CORRECTION blocks where a first claim was refuted and re-measured. |
| `FINDINGS.md` | all 126 findings from a twelve-lens audit, untriaged, severity-ordered within each lens. 24 are marked critical. |
| `PLAN.md` | the deliverable: eight LOOK stages and five FUNCTION stages, sequenced into eight commits, with line counts, the suites each moves, and seventeen rulings batched into one ask. Opens with nine corrections to claims that did not survive checking — including two of the lead's own. |
| `preview_theme.tcl` | edits no file. Redefines `ase::theme` and `ase::ui::apply_theme` in memory so Stage 1 can be seen before it is built. |
| `shots/` | 46 PNGs of the live window: the main window at three sizes, every dialog, the shipped dark colour scheme, `tk_scaling 2.0`, ASE-L beside the RDW and the Calculator, and the Stage 1 before/after composite. |

Run the preview:

```sh
tests/headless/devdisplay.sh start
DISPLAY=:99 GUI_GATE=0 ./src/xschem --pipe -q --nolog \
    --script sky130A/cadence_style_rc \
    --command "source doc/claude/ase_l_ux_batch/preview_theme.tcl"
```

## The one-paragraph version

The window renders in a typeface nobody chose (`Arial` and `Courier` are named in
`ase::theme` and neither is installed), at a size nothing else in the application uses,
with 52 of its 53 fonted widgets set in **bold** — so nothing can be emphasised because
everything already is. Its column widths are pixel constants while its font sizes are in
points, so it clips on any display that is not this one. It sets `-background` without
`-foreground`, so xschem's own shipped dark colour scheme renders the temperature field
at a contrast ratio of 1.000:1. And three of its surfaces report things that are not
true: the analysis Options form displays settings the deck never emits, every state of
every cell shares one run directory, and Save State overwrites an existing state with no
confirmation. Stage 1 of `PLAN.md` — 97 lines, no ruling, no test moved — fixes the first
three of those.

## Not filed yet, deliberately

`PLAN.md` ends with seventeen rulings. They were **not** in `owed.sh` and no issue had
been minted, because nothing had shipped and a ledger entry is a record of an unratified
decision that is already in the tree.

⚠ **That is history now, and the numbers in it are wrong.** Work started: issues **1396**,
**1397**, **1398**, **1399** were minted and rule debts filed for the first four, and items
3 and F2 minted **1498** and **1499**. The seventeen R-1…R-17 of `PLAN.md` are still
unratified and still gate everything they gated. **Two more rulings were raised by the work
itself and belong in the same queue**, both stated in full in their issue files rather than
here:

* **⚖ R-U1** (issue 1499) — should a cell too narrow for its text end in a visible `…`, and
  should the Outputs Name column's fixed 24-character `...` change to match? *Gates
  nothing:* the tooltip half shipped without it.
* **⚖ R-U2** (issue 1498) — should `Results > Select` repoint the Outputs Value column at
  the selected run's numbers, knowing that ASE-L cannot then vouch that they describe the
  deck on screen?

Neither has been filed with `owed.sh`: the implementing crew is forbidden to write
`~/.claude` state, so **the driver owes those two `owed.sh add rule` entries.**
