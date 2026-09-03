# 1273 — which directory is `<project>` for `op_param_lists.conf`?

**Status: RULE DEBT — decided by the L2 ladder inside item B2, NOT ratified by
the user.** The code ships the decision below; this issue is the option set the
user can overrule, and the cost of overruling it is one line.

## The question

Driver decision DD-3 names the settings file's project tier
`<project>/.xschem/op_param_lists.conf`, and leaves `<project>` undefined. There
is **no `<dir>/.xschem/` project directory anywhere in this tree** and no exact
precedent for one, so the item had to pick.

## What was measured (2026-09-03, this tree)

* `xschem get current_dirname` (scheduler.c:4407) answers **the design's**
  directory and it **MOVES**: after loading a schematic from elsewhere it
  follows the loaded cell. `[pwd]` does not — `load` does not `chdir`.
* The tree's **only** project-vs-user config precedent is xinit.c:3500-3515:
  `./xschemrc` in the process's **pwd**, else `$USER_CONF_DIR/xschemrc`.
* `USER_CONF_DIR` resolves to `/home/analog/.xschem` (xinit.c:3286-3289).

## What B2 shipped, and why

**`[pwd]/.xschem/op_param_lists.conf`**, with `$USER_CONF_DIR/op_param_lists.conf`
as the user-global fallback. Ladder **L2** (least surprising, smallest blast
radius):

* `current_dirname` moves under a descend, so a Save taken while descended into
  a PDK library cell would write the project file **into the PDK tree**, and the
  next read, back at the top, would not find it. The reader and the writer would
  silently disagree about where the file lives — and the window and CIW name the
  path on every Save, so the disagreement is user-visible.
* pwd is stable for the whole session, so reader and writer cannot diverge.
* It matches the one shipped analogue.

## Rejected

* **`[xschem get current_dirname]`** — moves under descend, per above.
* **the top-of-hierarchy schematic's dirname** — arguably the most *meaningful*
  answer, but there is no Tcl accessor for it; inventing one is scheduler/
  op_annot work item B2 does not own.

## If the user overrules

One proc changes: `::op_param_lists::conf_path` in `src/op_param_lists.tcl`
(its `project` arm). The row that flips is **T2** of
`tests/headless/test_op_param_store_1245.tcl`.
