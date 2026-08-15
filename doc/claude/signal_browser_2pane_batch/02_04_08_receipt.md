# Items 2, 4 and 8 receipt — the pure model under the upper pane

**Status: DONE, committed, unpushed.** Three commits, `20ca095b` / `acf26275` / `aae1dd8f`.
Item 10 is implemented in the working tree but **NOT committed** — see §6.

Spec: `doc/claude/specs/waveform_signal_browser_two_pane.md` (R1, R2, R6, M6, §4.3).
Plan: `doc/claude/signal_browser_2pane_batch/PLAN.md` items 2, 4, 8.
Prompt: `doc/claude/suggestions/next_session_2pane_item10.md`.

---

## 1. The baseline, re-measured first

**1531 checks, thirteen files, zero failures** — the prompt's figure reproduced *exactly*,
per file: sigsearch 139, sigbrowser 135, 2pane 59, panes 14, i11 50, i12 29, i1315 80,
i14 47, grid 216, modes 212, viewer 57, markers 437, tabs 56.

Every one of the prompt's sixteen `src/wave_viewer.tcl` anchors reproduced exactly, and
items 2/4/8 were confirmed absent by grepping for the procs rather than by trusting the
ledger.

## 2. One placement correction, taken from the tree rather than the plan

`PLAN.md` §4 puts items 1-8 in a **new** `test_wave_sigbrowser_model.tcl`, band `BN`. That
file was never created: items 3/5/6/7 landed in **`test_wave_sigbrowser_2pane.tcl`, band
`TP`**. The as-built convention was followed, not the as-planned one — items 2, 4 and 8 are
`TP27`-`TP44`, 59 → 108 checks in that file.

## 3. What landed

| item | commit | procs |
|---|---|---|
| 2 | `20ca095b` | `browser_rows {entries {root {}} {anypath {}}}`, `browser_rows_multi {groups {root {}}}` |
| 4 | `acf26275` | `browser_tree_rows {rows}`, `browser_root_label {path}` + the two corpus fixtures |
| 8 | `aae1dd8f` | `browser_node_for {rows segs {start {}}}`, `browser_root_id {rows}`, `browser_id_path {id}` |

Headless **1531 → 1585**, zero failures, and **no existing check moved** in any of the
three. Every extra argument is optional, which is what keeps BT10-BT13, BD19-BD25 and
BX01-BX08 green *by construction* rather than by restatement.

**The `d:N|` mis-decode is FIXED** (spec §4.3, both sites, through one shared
`browser_id_path`). It was measured live before the fix: `browser_target_path` on
`d:0|g:x1.xr1` answered `{ok 0|g:x1.xr1}` — a garbage instance path that "Descend to here"
was happily enabled on.

**The corpus fixtures PLAN §4 said were owed, and which were never extracted**, are now
committed: `tests/headless/fixtures/tb_bandgap_vars.txt` (424 names, 14 KB) and
`tb_charge_pump_vars.txt` (1191, 50 KB), names only, `head -c 4000000` off the 69 MB and
621 MB raws. Every spec number reproduces off them — 128/44/84 and 316/13/303 nodes,
424/190/374/140 class totals, own-level 18 and 43, recursive 406, 18-of-128 pure ancestors,
largest own level 52.

## 4. Four things measurement contradicted

1. **⚠⚠ M6's stated failure mode cannot arise, AND acting on it would be a bug.**
   `PLAN` item 2's BN11/BN12 expect `browser_rows` on a filtered set to answer `v(out)`
   with the gate AUTO and `out` with it forced to 1. Both really answer `v(out)`: the
   flat/hierarchical choice is *also* gated **per entry** on `$path ne {}`, so an
   empty-path entry takes the flat branch whatever the gate says. When the class filter
   leaves no pathed entry the rows are byte-identical either way; when it leaves one, the
   auto-gate already answers 1. The override is observable in exactly **one** direction —
   forcing `0` flattens a pathed set.
   Worse, **passing a pre-filter gate in `browser_refresh` would be actively wrong**: one
   gate computed from the CURRENT DB and applied to every group would flatten a
   hierarchical **foreign** inventory whenever the current raw happens to be flat. The gate
   is per-inventory, and `browser_rows` already computes it per inventory. So the argument
   exists, is unit-tested (TP31/TP32), and has **no production caller** — stated in the
   source rather than papered over with a source-order check that would pin dead code.
   PLAN's **BW32 must not be written.**
2. **PLAN item 8's fourth edit is dropped.** It wanted `browser_target_path`'s leaf arm to
   read a stored `path` key instead of re-parsing the raw name. Since M1 landed,
   `signal_entry`'s `path` **is** `[lindex [sig_split $name] 0]` — the same call the leaf
   arm already makes, and `sig_split` already declasses. Trap 12 is stale; TP43 pins the
   equivalence instead of adding a key to every leaf row.
3. **The `2pane` file's arm statement had already drifted.** Its header says the `--nogui`
   arm runs TP01-TP19 only; items 5/6/7 put pure checks in the 20-39 band and all 59 ran
   headless. Left alone (no oracle reads it), recorded here.
4. **BD06 counts the All-DBs accessor's bare name over the WHOLE source, comments
   included.** A comment that merely *named* it reddened BD06. The one read is now held in
   a local and used twice.

## 5. Sabotages — RUN, not reasoned about

| # | sabotage | measured reds |
|---|---|---|
| S1 | ignore the `anypath` argument | TP31 ×2 |
| S2 | default the gate to `1` | **ZERO** — the measured inertness, from the other side |
| S3 | emit the root unconditionally | **22 reds over four files**: TP27 ×2, TP30, TP31 ×2, TP32; BT10 ×2, BT11 ×2, BT12; BX01-BX07; BD20, BD22, BD24b, BD25 ×2 |
| S4 | re-parent only the groups | TP28, TP29 — the discriminating pair |
| S5 | multi drops the root on a header | TP33 ×2 |
| S6 | `browser_tree_rows` keeps the leaves | TP36 ×3 |
| S7 | `browser_root_label` answers `{}` | TP38 |
| S8 | R1's prune inverted to ANY-under-it | TP11 ×2, TP12 ×2, TP13, TP35 ×2 |
| S10 | the projection loses parent-first order | TP36 ×3 |
| S11 | hard-code the walk's start at `{g:}` | TP40 ×2, BX01-BX07, BD25 — three files, one defect |
| S12 | strip two characters unconditionally | TP42 ×2, TP43 ×2 |
| S13 | fix `browser_target_path`, forget `browser_show_path` | **TP44 ×2 ONLY**, i12 all green — the second site has no pure behavioural witness |
| S14 | accept a DB header as a design root | TP41 ×3 |

Source restored byte-identical after every one (`diff -q`).

## 6. One vacuous check, caught by RUNNING the red pass

TP33's id-uniqueness leg was first spelled
`[llength [lsort -unique $ids]] == [llength $rows]`. On the red run that compared the
`ERR:wrong # args` **string against itself** and went **green before the code existed**. It
now names the duplicates and pins the row count, so neither half can be satisfied by an
error string. This is the third time this batch has paid for the same rule.
