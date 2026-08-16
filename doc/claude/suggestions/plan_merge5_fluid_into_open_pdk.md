# Merge 5 — `origin/fluid-editing` into `open_pdk`

Analysis and resolution plan for the fifth cross-branch merge. Written before the merge,
from a trial `git merge-tree`; the resolutions in section 4 were each compiled or executed
against the merged tree before being applied.

- **Merge base:** `99d6f1ed` (2026-08-08, *"docs(issues): renumber the 0220-0238 block to 0230-0248 for the merge"*)
- **Ours:** `open_pdk` @ `1a45bc06` — 23 commits, 162 files
- **Theirs:** `origin/fluid-editing` @ `ca4e0065` — 134 commits, 566 files
- **Trial merged tree:** `a3fe7be7f2d522774fd44bb5e7080b584713edf3`

## 1. Shape of the merge

| Measure | Value |
| --- | --- |
| Files touched by both sides | 18 |
| Textual conflicts | 3 — `doc/claude/FAQ.md`, `src/callback.c`, `tests/headless/full_audit.sh` |
| Renames / deletions | **none, either side** |
| Issue-number collisions | **none** (the base commit is the renumber that guaranteed this) |
| open_pdk commits already contained in fluid-editing | **none** — all 23 are new work |

The 18 overlapping files are:

```
doc/claude/FAQ.md            src/draw.c        src/xschem.tcl
src/actions.c                src/save.c        tests/headless/full_audit.sh
src/actions.csv              src/scheduler.c   tests/headless/test_altf5_ciw.tcl
src/ase_window.tcl           src/xinit.c       tests/headless/test_cmdmode_descend_0201.tcl
src/cadence_style_rc         src/xschem.h      tests/headless/test_create_instance.tcl
src/callback.c                                 tests/headless/test_phase3_mints.tcl
                                               tests/headless/test_placement_wire_gate.tcl
```

**The 15 non-conflicted overlapping files are pure unions**, proven numerically rather than
by reading: for each one, `git diff --numstat open_pdk <merged> -- <f>` equals theirs'
base-diff exactly, and `git diff --numstat origin/fluid-editing <merged> -- <f>` equals ours'
exactly. `scheduler.c` is the extreme case — ours 556/18, theirs 185/14, merged-vs-ours
185/14, merged-vs-theirs 556/18. Zero interleaving anywhere.

That is why this document is short on "check every file" and long on the handful of places
where git's clean result is not the correct one.

## 2. What was checked and found clean

Recorded so the next merge does not re-derive it:

- **No two-sided `.sch` / `.sym` anywhere.** Neither side touched `xschem_library/`,
  `gf180mcuD/`, or any sky130 tree. fluid's only library work is 16 *new* files under
  `xschem_libraries_oa/` and `xschem_libs_newsym/`; open_pdk touched zero.
- **No build-system collision.** Neither side touched `scconfig/`, `configure`,
  `config.h.in`, `Makefile.conf.in` or `CMakeLists.txt`. fluid touched `src/Makefile.in`
  only (see §5.1).
- **No binary text-merge.** fluid's 10 binaries (8 PNGs, 2 `.raw` fixtures) all show
  `-\t-` in `--numstat`; git never text-merged them.
- **No keybinding or chord collision.** The full chord table from each side was built and
  diffed: 16 `xschem bind` lines and 25 `bind .drw` patterns in the merged tree, zero
  duplicates, zero cross-claims. Ours adds Ctrl+Alt+Shift+Button1, Alt+Up/Alt+Down and a
  `<Control-Key-y>`; theirs adds keysyms 114/102/118 (alt|super) and 118 (ctrl+alt).
- **No duplicate scheduler verb.** Merged verb set = base ∪ {`escape`, `select_same_net`,
  `test_shape_click`} (ours) ∪ {`vcd_read`} (theirs). The one duplicate, `searchmenu`, is
  pre-existing in the base.
- **No lost gate.** All nine open_pdk teardown helpers (`leave_shape_draw_for`,
  `leave_wire_draw_for`, `leave_placement_for`, `leave_merge_for`, `abort_click_mode`,
  `abort_shape_draw`, `abort_pending_merge`, `escape_terminal`,
  `check_placement_preview_invariant`) have identical occurrence counts in `open_pdk` and in
  the merged tree across `callback.c`/`scheduler.c`/`actions.c`/`draw.c`/`paste.c`/`move.c`.
  fluid's deletion of the Alt-R/F/V switch arms removed no gate.
- **No orphaned Tcl caller.** The 12 `wviewer::` and 4 addpin/addlabel-esc procs that appear
  as `-proc` in the two diffs are all still defined in the merged tree.
- **Binding-drift guards still pass.** Merged `src/keybindings.csv` (67 rows) and
  `src/mousebindings.csv` (12 rows) still match merged `init_input_bindings` row-for-row and
  in order — open_pdk added no C default rows at all.
- **`test_selflog_grep_guard.tcl` still holds.** All 32 S1 manifest counts and all 29 S1c/S7
  zero-assertions were re-run against the resolved `callback.c`.
- **Escape has one owner.** fluid added zero Escape bindings, so open_pdk's shared
  `.drw <Key-Escape>` slot protocol is uncontested.

## 3. Merge direction

The merged tree is byte-identical whichever direction the merge runs — base and both sides
are fixed. The hazard is doing it **twice**: all three conflicts require a hand-built union,
and `--ours` means opposite things in the two directions. Both careless outcomes are hard
compile breaks (§4.1).

Merges 3 (`958ada03`) and 4 (`15c600c6`) landed on `fluid-editing`. This merge lands on
`open_pdk` instead. Either is correct — but the other branch must then be brought up with
`git merge --ff-only`, **not** re-merged from `99d6f1ed`.

## 4. Conflict resolutions

### 4.1 `src/callback.c` — union, plus one terminator git cannot supply

The conflict looks like two mutually exclusive function insertions. It is not. Ours adds
`act_select_same_net` / `act_select_same_net_add`; theirs adds `act_rotate_in_place` /
`act_flip_in_place` / `act_flipv_in_place` plus two forward declarations. The two blocks
share no code. git only tangled them because both regions end with the same two lines
(`  return 1;` / `}`), so git claimed one closing pair as common context and made the blocks
look like alternatives.

**Every "pick a side" resolution is a hard build break**, because the `action_registry[]`
table below the conflict auto-merged and references *all five* handlers. Measured against
the merged headers:

```
--ours    error: 'act_rotate_in_place' undeclared here (not in a function)
          error: 'act_flip_in_place' undeclared here (not in a function)
          error: 'act_flipv_in_place' undeclared here (not in a function)
--theirs  error: 'act_select_same_net' undeclared here (not in a function)
          error: 'act_select_same_net_add' undeclared here (not in a function)
```

A naive marker-strip is worse than either: `act_select_same_net_add` is never closed, so
theirs' block comment and the two forward declarations are swallowed into its body and the
file dies at the first `{` of `act_rotate_in_place`.

**Resolution** (line numbers in merged blob `a3fe7be7`):

```
5702   delete    <<<<<<< open_pdk
5729   replace   =======   with:   "  return 1;" / "}" / blank line
5852   delete    >>>>>>> origin/fluid-editing
```

Lines 5853-5854 (`  return 1;` / `}`) then close `act_flipv_in_place`, which is what theirs
intended. **Do not reorder**: the forward declarations `connected_drag_group_transform` /
`standalone_group_transform` at 5753-5754 must stay above their first use at 5764.

Verified: `gcc -fsyntax-only -Wall` clean against the merged tree's own headers; brace and
paren balance identical to base, ours and theirs; both helpers defined exactly once; every
static handler still referenced; no `defined but not used`.

#### Alt-R / Alt-F / Alt-V remappability is preserved by this resolution

fluid's `cc3a81fa` made the three in-place transforms remappable actions instead of
hardcoded `else if(EQUAL_MODMASK)` switch arms. **Only the three handler bodies are inside
the conflict** — everything else that makes them remappable auto-merged and needs no work:

| Piece | Merged location |
| --- | --- |
| registry rows `edit.rotate/flip/flipv_in_place` | `callback.c:6057,6059,6061` |
| C defaults, two rows per key (Mod1Mask + Mod4Mask) | `callback.c:6370-6375` |
| `keybindings.csv` rows (114/102/118 × alt, super) | `:67-72` |
| `actions.csv` label rows carrying the remap recipe | `:195-197` |
| `cadence_style_rc` user-facing remap block | `:428-456` |

`EQUAL_MODMASK` count in the merged file equals theirs' (33) — the hardcoded arms are gone,
with no leftover arm and no double handling. The readonly gate survived the move correctly:
theirs' inline `if(readonly_block()) break;` became the registry `mutates=1` column, and
`dispatch_input_action` refuses on a read-only view before the handler runs.

**Consequence for the 0269 work:** the Alt-R/F/V bodies now live above the switch, so the
four-gate teardown discipline no longer has a `case 'r'/'f'/'v'` to hook. The
empty-selection arms of `act_rotate_in_place` / `act_flip_in_place` / `act_flipv_in_place`
set `MENUSTART|MENUSTARTROTATE` without tearing down a live placement or merge preview.
This is **not a regression** — open_pdk never gated those arms either — but the edit site
for the next 0269 extension has moved from the switch to the three `act_*_in_place`
functions.

### 4.2 `tests/headless/full_audit.sh` — union, both hunks

Two hunks, both requiring a union.

**Hunk 1, the usage-comment header.** Ours documents `AUDIT_LIB_ONLY=1`, theirs documents
`AUDIT_DISPLAY=:0`. Both are live features in the merged file — `xvfb_arm.sh` is sourced near
the top and reads `AUDIT_DISPLAY`, and ours' `test_audit_classifier.tcl` sources the script
with `AUDIT_LIB_ONLY=1`. Keep both lines.

**Hunk 2, `nogui_tests=`.** Both sides rewrote the same single line. Keeping either half
alone silently un-pins the other's tests:

- `--ours` drops 11 fluid registrations.
- `--theirs` drops 5 open_pdk ones — including `test_placement_wire_gate`, which its own
  header records as blocking **forever** at the G4 `xschem place_text` row under any display
  (measured: killed at 120 s under WSLg, still stalled after 300 s under `xvfb-run`).

Keep both comment blocks and hand-write the union:

```sh
nogui_tests=" test_nogui test_sweep_diff test_make_symbol_dialog test_ase_core test_ase_final \
test_ase_final_gf180 test_descend_refusal_channel_0251 test_placement_preview_doors \
test_paste_modify_flag_0244 test_shape_draw_gate test_placement_wire_gate \
test_verilog_view_model test_vcd_read test_ase_cosim test_raw_ascii_point_bounds \
test_vcd_time_base test_raw_read_dispatch test_raw_read_failure_0306 test_node_token_split \
test_wave_cursor_crossdb test_backannotate_digital test_cosim_golden_e2e "
```

(written as one physical line in the file — the wrapping above is for this document only).

### 4.3 `doc/claude/FAQ.md` — union, and renumber theirs

Both sides prepended to a newest-first file, and **both added a `Q40`**. A plain union ships
two Q40 entries.

Renumber **theirs**, not ours: ours' `Q41` is cited from
`doc/claude/issues/0262-unselect-all-verb-still-orphans-a-live-placement-preview.md:67`, and
ours' Q40-Q46 are a contiguous dated block; theirs' has no inbound reference. Neither body
text mentions its own number, so only the heading changes.

Theirs' entry is dated 2026-08-08; the file is date-ordered newest-first and already
tolerates non-monotonic numbering (Q32 sits above Q33 in the base). Place the renumbered
entry directly above `## Q39.` (also 2026-08-08), keeping ours' 08-09 → 08-12 block on top.

## 5. Post-merge repairs — clean auto-merges that are wrong

These are the findings git cannot see. Each is a real interaction between one side's change
and the other's, in files that merged without a marker.

### 5.1 `./configure` is mandatory before the first build — HIGH

fluid changed `src/Makefile.in` twice: `vcd_read.c` into the source list, `calculator.tcl`
into `install_shares`. **`src/Makefile` is generated and untracked**, so an existing dev tree
still has the old one.

- `cd src && make` compiles everything, then fails at link with
  `undefined reference to 'vcd_read'` from `save.o`.
- Hand-editing the `OBJ` line to get past that leaves `install_shares` stale, so
  `make install` ships no `calculator.tcl` and the installed binary dies at startup sourcing
  it — and the hand edit is silently reverted by the next `./configure`.

Run `./configure` from the repo root immediately after the merge, before any `make`. Do not
edit `src/Makefile`. **This is worth stating in the merge commit**, because merge 4's own
message (`15c600c6`) says the opposite — *"No src/Makefile.in change this time, so no
./configure is required"* — and that habit is exactly what makes this one bite. CI is
unaffected; `.github/workflows/ci.yaml` runs `./configure` before `make`.

### 5.2 fluid's golden lands inside open_pdk's new hard CI gate — HIGH

fluid adds `tests/headless/gold/cosim_e2e_counter.golden`. open_pdk's `118d6937` / `825d69ce`
promoted that directory to a hard CI gate, and `tests/headless/run.sh:128` iterates
`for g in "$GOLD"/*` treating every entry as a netlist baseline.

Move it out of the baseline directory — `tests/headless/fixtures/cosim_e2e_counter.golden` —
and update its single reader, `tests/headless/test_cosim_golden_e2e.tcl:71`. Do **not** fix
it by dropping the ci.yaml step; that silently reverts issue 0351.

### 5.3 `xvfb_arm` sits above the `AUDIT_LIB_ONLY` guard — MEDIUM

fluid sources `xvfb_arm.sh` and calls `xvfb_arm "$0" "$@"` near the top of `full_audit.sh`,
before ours' `AUDIT_LIB_ONLY` early-exit. `xvfb_arm` can `exec xvfb-run`, and
`test_audit_classifier.tcl` *sources* `full_audit.sh` in library mode — so that source now
execs and never returns.

```sh
if [ "${AUDIT_LIB_ONLY:-0}" != "1" ]; then
  # shellcheck source=/dev/null
  . "$HERE/xvfb_arm.sh"
  xvfb_arm "$0" "$@"
fi
```

Keep it in fluid's position, above everything with side effects; only the library-mode branch
is skipped. Do not bundle the `${BASH_SOURCE[0]}` fix for `HERE` with this — it also changes
the `cd "$REPO"` the classifier currently measures.

### 5.4 CI's headless gate silently acquires an X server — MEDIUM

fluid's default private-Xvfb arm gives open_pdk's DISPLAY-less *"Headless gate"* step a live
display it never asked for. Three issue-0246 blocks self-skip when Tk is present and go
**hollow green**: `test_add_wire_label.tcl:603`, `test_sch_add_pin.tcl:156`,
`test_add_pin_lib_symbol_view.tcl:85`.

Add `AUDIT_DISPLAY=none` to that step — one edit restores the measured arm for all 15 gated
suites. Separately, the *"Fluid suites gate (xvfb)"* step now nests `xvfb-run` inside
`xvfb-run` (harmless but wasteful, and it warns that openbox is missing); set `AUDIT_DISPLAY`
there or drop the outer `xvfb-run -a`.

### 5.5 `run_suites.sh` ships the skip predicate open_pdk just repaired — MEDIUM

The merged tree carries two contradictory implementations of one rule.
`run_suites.sh:174` has fluid's unanchored `grep`; `full_audit.sh:224` has ours' anchored
one. Four of open_pdk's own selflog suites (`test_save_reload_copy_selflog`,
`test_delete_cut_selflog`, `test_descend_goback_selflog`,
`test_key_make_sch_from_sel_log`) run every check, pass, exit 0 — and `run_suites.sh` reports
`SKIP … (self-skipped: no X – nothing ran)` while `full_audit.sh` scores them PASS. Since
`run_suites.sh` exits 0 on skips, the entry point CLAUDE.md calls *preferred* gives a green
run in which four suites appear never to have executed.

Replace the grep at `run_suites.sh:175` with `full_audit.sh`'s rule — either source
`full_audit.sh` with `AUDIT_LIB_ONLY=1` and call the shared `is_skip`, or inline the same
anchored regexp — then extend `test_audit_classifier.tcl` to assert the `run_suites.sh` copy
so the two cannot drift again.

### 5.6 fluid's `.gitignore` rule blinds ours' leak detector — MEDIUM

fluid's four `/untitled*.sch|sym` ignore lines hide the symptom its own source fix cures, and
hide it from open_pdk's working-tree leak detector too (`tree_delta_snapshot` trusts
`.gitignore`), so C37 goes red.

Preferred: drop the four ignore lines and keep the rest of fluid's `.gitignore` hunk. fluid's
actual cure for 0322/0323 is the source fix (`get_unused_untitled_name` probing the write
directory) plus the test hygiene in `test_placement_wire_gate.tcl`. If the ignore lines are
kept for developer convenience instead, `tree_delta_snapshot()` must stop trusting
`.gitignore` for this class — and C37's comment must say why. Do **not** rewrite C37 into a
"CANNOT see" row without filing the coverage loss against 0353.

## 6. Advisory, no action

- **Ctrl-B over a graph embedded in a schematic** now falls through to `sym_txt`. fluid
  declared this: on the schematic canvas Ctrl-B still toggles `sym_txt`
  (`xschem.tcl:15021`), and fluid's Signal-Browser Ctrl-B lives only in the waveform-viewer
  toplevel.
- **`actions.csv` lists Alt-R/F/V twice** — the old menu-command rows (85-87) and the new
  key rows (195-197). That is fluid's own design (menu row vs key row) and is present on
  `fluid-editing` already; it is not a merge artifact.

## 7. Order of operations

1. `git merge origin/fluid-editing` — expect exactly the three conflicts.
2. Resolve §4.1, §4.2, §4.3.
3. Commit the merge. Note in the message that `./configure` is required.
4. `./configure && make` from the repo root. **Not** `make` alone (§5.1).
5. Apply §5.2 - §5.6 as a follow-up commit.
6. Run the headless suites under the GUI gate (`tests/headless/run_suites.sh`), pressing
   `Allow 30m` once rather than Proceed per suite.
7. Bring `fluid-editing` up with `git merge --ff-only`. Do not re-merge from `99d6f1ed`.
