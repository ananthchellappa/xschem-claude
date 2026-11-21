# Issue 1723 items 5-7: red first, and the sabotage sweep (crew 1723i, 2026-11-21)

This is a dated record, not a baseline. It was measured on the working tree that became the commit
adding this file (parent `a464b7f6b`), and nothing re-runs it. The counts are what that tree printed,
and any later edit to either suite moves them.

## Red first

The new and moved rows were run against the product sources at `HEAD` (`src/ase.tcl`,
`src/ase_window.tcl`, `src/xschem.tcl` checked out from `a464b7f6b`, the suites as written), and the
working copies were then restored byte for byte (md5 compared):

- **`test_ase_preflight`, `--nogui`:** 38 failed and 266 passed. Every new row `PF1723r` to
  `PF1723ah2` was red, and so were the five moved rows `c`, `p`, `l2`, `o2` and `n2`. The unchanged rows
  stayed green. `PF1723ah` on `HEAD` is the user's crash itself. The stale run was not refused, it
  generated `e2e_tb_ase.spice`, `.runstate` and `.log`, and ngspice ran.
- **`test_ase_window`, `AUDIT_DISPLAY=private`:** the `FX1723`, `FX1723I` and `FX1723C` bands aborted
  on the missing label procs (`UNEXPECTED ERROR`, counted). `FX1723Ea`-`Ec` were red: on `HEAD` the stale
  Run reached ngspice and wrote a deck, a log and a runstate, there was no confirmation to press, and the
  next Run ended with exit 1 and `syntax error` in its log.
- **`FX1723Cf` and `PF1723ac3`** were added after the sweep below, together with the code they fence
  (`ase::include_unapply`, and `ase::ui::repair_confirm_ok` undoing the files when its session half
  raises). `FX1723Cf` was red on the tree before that fix (files left rewritten, backup kept, dialog
  gone), and green after it. Sabotage S19 covers it.

## Method of the sweep

A scratch Python driver, not committed, made one substitution per sabotage. Each site was named by
line number *and* text, and the driver refused a site whose line no longer held that text. For each
sabotage the driver:

1. wrote the sabotaged copy over the file in the worktree (S18 instead checks out `src/xschem.tcl` at
   `HEAD`);
2. ran the named suites through `tests/headless/gated_xschem.sh` with an armed throwaway HOME:
   - `P` is `test_ase_preflight` with `--nogui` and `AUDIT_DISPLAY=none`, the counted headless arm;
   - `W` is `test_ase_window` with `AUDIT_DISPLAY=private`, a private Xvfb with openbox;
3. kept every `FAIL`, `FATAL` and `UNEXPECTED` line;
4. restored the file from its in-memory copy in a `finally`, then compared the md5 of all three product
   files against their pre-sabotage values.

Every sabotage reported `restored`. The baseline S00 was `test_ase_preflight` ALL PASS (304) and
`test_ase_window` ALL PASS (385). After the S19 code and rows landed, the counts were 305 and 386.

## Results

| id | site (symbol) | substitution | what it breaks | red rows |
|---|---|---|---|---|
| S01 | `ase::preflight_scan` | `if {[llength $itexts]} {` → `if {0} {` | the scan reads no include file (items 6 and 7 gone at once) | PF1723 l2 n2 s s2 s3 s4 t t2 t3 u u2 x aa ab ae ae3 ac ac2 ad ad2 af ah ah2; FX1723d, Ca Cb Cb2 Cc Cd Ce Ce2, Ea Eb Ec |
| S02 | `ase::preflight_rename_solve` | deciders `in {o i}` → `in {o}` | include rows stop deciding the rename | PF1723s3 |
| S03 | `ase::preflight_gate` | `if {[dict exists $r miss]} {` → `if {1} {` | every absent include name refuses, so there is no caution | PF1723 t t3 u u2 x |
| S04 | `ase::include_card_idents` | `if {$card ne {}}` → `if {0}` | a `+` continuation is not read | PF1723 l2 r r2 s s2 t t2 t3 u aa ab ae ae3 ac ac2 ah ah2 |
| S05 | `ase::include_card_idents` | `incr depth` → `incr depth 0` | a `.subckt` body's cards are read as top level | PF1723 r r2 |
| S06 | `ase::preflight_include_edits` | edit end `- 1}]` → `- 0}]` | the rewrite eats the dot after the prefix | PF1723 aa ac ac2 ad2 af af2 ah2; FX1723 Ce Ce2 Eb Ec |
| S07 | `ase::include_edit_verdict` | `foreach r $roots {` → `foreach r {} {` | no folder is protected (PDK, model folders) | PF1723 y y3 ab ae ae3 ac ac2; FX1723 d f g h j, Ie, Ca Cb Ce |
| S08 | `ase::include_apply_plan` | `if {$now ne [dict get $f text]} {` → `if {0} {` | OK does not re-read the file | PF1723 ad ad2; FX1723 Cd Ce Ce2 |
| S09 | `ase::include_apply_plan` | backup `open $b {WRONLY CREAT EXCL}` → `open /dev/null w` | no backup is written | PF1723 ac af; FX1723 Ce Eb |
| S10 | `ase::include_apply_plan` | put-back loop over `[concat $done [list $f]]` → `{}` | a failed write puts nothing back | PF1723ad2 |
| S11 | `ase::include_add` | `file $t` → `file [ase::expand_path $t]` | Add stores the expanded path, not the portable one | PF1723ag2; FX1723 Ic Id |
| S12 | `ase::preflight_gate` | `if {![llength $rows] && ![llength $irefuse]}` → `if {![llength $rows]}` | include rows never refuse the run (item 7 undone) | PF1723 n2 t t2 t3 x ae ah ah2; FX1723 Ea Eb Ec |
| S13 | `ase::preflight_scan` | the `include_top_words` stand-down → `0` | an instance an include file adds is refused | PF1723s4 |
| S14 | `ase::preflight_scan` | the case-only stand-down → `0` | a case-only spelling under `distinguish` is cautioned | PF1723s4 |
| S15 | `ase::ui::repair_apply` | `if {[dict get $f editable] && [dict get $f n]} {` → `if {0} {` | Apply never asks (the session-only press) | FX1723 Cb Cb2 Cc Cd Ce Ce2 Eb Ec |
| S16 | `ase::ui::repair_confirm_cancel` | prepend `ase::ui::repair_confirm_ok $key ;` | Cancel applies | FX1723 Cc Cd Ce Ce2 |
| S17 | `ase::ui::incdlg_open` | `set ro ro` → `set ro {}` | Open is never read only | FX1723Ie |
| S18 | `textwindow` (`src/xschem.tcl` at `HEAD`) | the whole file | Save writes the last-opened window's file and closes that window | FX1723If |
| S19 | `ase::include_unapply` | `foreach f [dict get $r files] {` → `foreach f {} {` | the undo after a raising session half puts nothing back | PF1723ac3; FX1723 Cf Ce Ce2 |

No sabotage left the suites green.

## What the sweep does not cover

- **`ase::include_rundir_peek` calling `ase::rundir`.** Row `PF1723ag3` compares the folder shown,
  which `ase::rundir` would answer the same way. It does not assert that nothing was created. Not swept.
- **The `` ` $ `` and `;` inline-comment cut** is pinned by `PF1723r`, since `x1.zz` and `x1.yy` would
  appear. It was not swept separately.
- **The PDK arm of `ase::include_protected_roots`** is driven by `PF1723y2` (`::PDK_ROOT`).
  `env(PDK_ROOT)` is read by the same loop and has no row of its own.
