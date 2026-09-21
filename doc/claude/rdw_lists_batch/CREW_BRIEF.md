# Crew brief — the RDW list batch

## What the user reported, in their words

> **1 key**: dumps ALL OP info for a MOS FET in the RDW, when it's supposed to
> dump only those parameters that get annotated on the schematic. *(was working
> OK before)*
>
> When I use **2 key**, the RDW doesn't say "summary" view, so it's not clear.
> The fact that the Delete button is NOT greyed out is a clue. In the summary
> view for `M18:/x1/x1` of `tb_bandgap`, I select a bunch of lines — `sa`, `sb`,
> up to `scc` — and press Delete and get the pop up dialog asking where to
> apply, but it doesn't say "summary list" — which would be good for the user to
> know. The delete did not have an effect (I left settings on the pop-up at
> default). Then, I tried deleting one at a time. That also did not have an
> effect next time I printed summary.

Their log is `/tmp/Xschem.log.5`. Design:
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch`,
descended `x1` → `x1`. They registered a simulator named `ngspice-ver_50`.

## What the driver established before the crews started

**All three complaints are downstream of ONE filed issue: 1300.**
`doc/claude/issues/1300-rdw-keys-1-2-3-render-identical-blocks.md`, *"the RDW's
keys 1, 2 and 3 select a list IDENTITY and narrow no CONTENT"*. Read it first;
it costs three options and takes none, and it is on the owed ledger as item
B4's E question.

Read from the source, not inferred:

* `rdw::dump_devpath` (`src/rdw.tcl:854`) asks the backend seam
  `op_param_set` for a devpath and hands the whole answer to
  `rdw::format_answer`.
* **`rdw::format_answer` (`src/rdw.tcl:600`) takes no list argument at all.**
  It renders every pair in `dict get $ans devices`, plus `absent` and
  `nonfinite`. There is no narrowing anywhere on the path.
* `rdw::set_list` (`:2207`) sets `::rdw::listkind` and calls
  `rdw::apply_button_states`. That is the ONLY thing keys 1/2/3 do.
* `rdw::button_state` (`:742`) greys **add** on `annotation` and **delete** on
  `all`. So `annotation` and `summary` differ on screen by the Add button
  alone — which is why the user reached for the Delete button as their clue.
* The scope dialog (`rdw::scope_dialog_build`, ~`:3865`) asks *"And which list
  should it go into?"* **only when `listkind eq {all}`**. On `summary` it names
  no list anywhere.
* `rdw::_edit`'s refusal text already admits the pane is wider than the list:
  *"The pane also shows rows this run published that no list declares, and only
  the list's own rows can be edited here."*

**So the leading hypothesis for "Delete had no effect" is that the store edit
SUCCEEDED and the pane, which never narrows, could not show it.** Prove or
refute that; do not assume it.

**Why it "was working OK before" is a real question, not a throwaway.** The
most likely answer is that the raw used to carry only the annotation
parameters — under the per-device shape the deck asks for exactly those — so an
unnarrowed pane *looked* narrowed. Their log shows the per-device shape was
used for this run (`468 device OP save card(s)`), so find out what actually
widened the answer. Bisect if you must. **Say what you measured, not what is
plausible.**

## The fence that used to block the fix is gone

Issue 1300 rejected option (b) — call the list store — because row **S1** of
`test_rdw_window_1245.tcl` forbade the token `op_param_lists` in `src/rdw.tcl`.
**That fence no longer holds: `src/rdw.tcl` names `op_param_lists` 49 times
today**, and `rdw::_edit` calls `::op_param_lists::effective` directly. Check
S1's current text yourself before relying on this sentence.

The store's doors: `op_param_lists::effective {cls listname {cellname {}}}`
(`src/op_param_lists.tcl:1022`), `governs` (`:1006`), `seed` (`:941`).

## Standing rules — every one of these was paid for

* **NEVER a bare `xschem`.** `/usr/local/bin/xschem` is 3.4.6 from Jan 2025 and
  rewrites the user's `~/.xschem/recent_files` (issue 0924). Always
  `./src/xschem`, or `tests/headless/devdisplay.sh exec ./src/xschem`.
* **GUI suites go on `:99`** via `devdisplay.sh exec` with `GUI_GATE=0`. The
  user's own server is `$DISPLAY` (`172.20.160.1:0`, vendor `HC-Consult`);
  `:0` is WSLg Xwayland and is **not** their screen.
* **Acceptance is a name+status diff, never a count.** Assert a `RESULT` line
  is present; a blank result is not a pass.
* **Every new row must be proved non-vacuous by a sabotage** that reds exactly
  it, applied to the repo file and restored by `cp` from a gold copy with the
  md5 verified after. **Never `git stash`, `git checkout --`, `git restore` or
  `git clean`.**
* **Raise `KX_FLOOR` / `RW_FLOOR` in the same commit as rows you add**, with
  the file's own `AND RAISED N -> M` paragraph. Issue 1351 is what happens when
  you forget.
* **Issue numbers come from `doc/claude/issues/NUMBERING.md` only.** Next free
  is **1353**. Record the number in NUMBERING.md in the same commit.
* **Record every judgement call taken on the user's behalf** with
  `tests/headless/owed.sh add rule <id> "<why>"`, and every pixel deliverable
  with `add look`. Only the user clears those. Never call a pixel deliverable
  done on a green suite.
* Commit as `Ananth <ananth.chellappa@outlook.com>`, ending with
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01B52FS3HgaqHXFbN7foxcd7`.
  **Never push, never open a PR.**

## Baseline, measured at HEAD `79b0a0ce` by the driver

| suite | how | result |
|---|---|---|
| `test_rdw_window_1245` | `--nogui` | ALL PASS (145) |
| `test_rdw_window_1245` | `:99` | ALL PASS (157) |
| `test_rdw_keys_1245` | `:99` | ALL PASS (81) |
| `test_op_param_store_1245` | `--nogui` | ALL PASS (130) |
| `test_op_annot` *(control)* | `--nogui` | ALL PASS (485) |
| T1 `run_regression` | solo | rc=0, 0 counted failures |
