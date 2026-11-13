# Stage D receipt: checks that silently never run (item 2), and issue 1712

Implementer crew, 2026-11-12. Tree: HEAD `514868462` plus stage D's uncommitted changes.
Nothing is committed.

- Every xschem run had `unset DISPLAY`.
- The only display I used was my own Xvfb `:271` plus openbox. I killed both by pid
  afterwards. I never used `:99` and ran no T1.
- `src/draw.c` was sabotaged twice and restored each time with `cp`, checked with `cmp`.
  `git status` shows it unmodified. No C file changed, so no rebuild was needed.

**Verdict.** No second dead *check* exists in the tree: nothing like `drc_check()`'s
`fet_drc` gate, where a feature silently never ran. Two upstream leftover branches are dead,
but each has a live sibling that does the work, so the user loses nothing. I left both in place
(see §3). Row A22 is repaired and issue 1712 is filed (§4).

## Changed

| file | what |
|---|---|
| `tests/headless/test_annot_declutter_1244.tcl` | New procs `dc_c_blank` and `dc_c_ngrep`. Row A22 now counts with C comments blanked and has a self-test leg. The golden for the four files is unchanged. The suite's check count is unchanged (134). |
| `doc/claude/issues/1712-annot-declutter-a22-census-counts-a-comment.md` | New issue, stamped `claim=fixed fix=taken open=1`. The open item is registration. |
| `doc/claude/issues/NUMBERING.md` | Records 1712. 1707–1711 are skipped because they are taken or advertised in `~/private/xschem-private`. The pointer is now 1713. |

## 1. Search method

Each pass extracted the gate names and then checked each name against two sources:

- the text of the tree, outside `tests/` and `doc/`;
- a **runtime dump** of every command (`info commands`) and every variable (`info vars`),
  walked recursively through all namespaces. I took the dump from a live xschem in five
  configurations: headless; on Xvfb; and on Xvfb with each workarea rc sourced (sky130A,
  ihp-sg13g2, gf180mcuD). The dump scripts are in the scratchpad: `dumpcmds.tcl` and
  `dumpvars.tcl`.

**Files scanned:**
- `src/*.tcl`, `src/*.c`, `src/*rc`
- the three workareas' `*_procs.tcl` and `cadence_style_rc`
- `utils/*.tcl`, `xschem_library/*/*.tcl`, `xschem_library/*/xschemrc`, `tools/launcher/*.tcl`
- for the attribute hooks, every tracked `*.sym` and `*.sch`

| gate spelling | population | not defined anywhere | resolution |
|---|---|---|---|
| `info procs/commands <literal>` (Tcl and C strings) | 61 distinct names | 8, all Tk/Tcl builtins plus the `::menu_unlogged` rename-once guard | every other name is defined; a namespace-exact text check and the runtime dump agree |
| the same, with a dynamic name (`$p`, `[dict get …]`) | ASE adapter legs, `saved_say` labels, `edit_form=` namespaces | 0 | runtime probe: `ase::analysis_schema_errors ngspice` gives 0; 78 qualified registry leaves and 14 setup/stimuli legs all resolve; every literal `ase::saved_say` label has its `lbl_` proc; all 4 `edit_form=` symbols ship a companion `.tcl` that defines the namespace |
| `tclget{,bool,int,double}var("…")` in C | 161 names | 3 | `tmp2` is set by the same C via `tcleval`; `slickprop_highlight_color`/`_width` are tunables (§2) |
| `info exists <name>` (Tcl and C strings) | 332 names | 11 | all are tunables, builtins (`tk::Priv`, `tcl_interactive`), C-set (`tctx::edit_*`), a glob-built array, or the launcher's test knob (§2). Of the 106 qualified names, 34 are absent at startup; each has a lazy setter in source |
| `catch {<cmd> …}` (Tcl and C strings) | 420 distinct words | 0 | 4 unqualified words resolve only inside a namespace; each call site is inside that namespace (checked at runtime) |
| `xschem <subcmd>` literal | 247 used, 324 dispatched | 0 | 7 apparent hits were prose |
| `xschem get <param>` literal | **measured silent on an unknown name** (`rc=0`, empty) | 0 | every literal param is handled; `cursor${which}_x` covers `cursor1_x` and `cursor2_x` |
| `drc=` attribute procs | 8 names in symbols | 0 | all defined once their PDK rc is loaded |
| `[procname …]` in `.sym`/`.sch` attributes | 99 words | 0 real | not commands at all (spice bracket syntax, schematic-embedded `proc`s such as `xround` and `calc_rc`) or `analyses::*` from the library's own `lib_init.tcl` |
| `winfo exists .<literal path>` | 73 paths | 13 not found by creator regex | 11 are built through `$w`/`$f` variables. 2 are really dead (§3) |
| `[file exists <literal>]`, `$XSCHEM_SHAREDIR/<file>` | all | 0 dead | user paths, install layout, `/proc`, `/usr/share/X11/rgb.txt` |
| `::env(X)` / `getenv("X")` | 24 | 3 | all in comments |
| `#if`/`#ifdef` macros in C | 120 | 4 | deliberate `#undef` debug switches (`ZERO_REALLOC`, `CAIRO_JPEG_TEST_SIMILAR`) and vendored switches; the rest come from `config.h.in` |
| documented `# set X` options in `src/xschemrc` | 132 | 6 | 5 were prose (`#### set paper size…`); `xschem_doc_dir` is an upstream example line that nothing reads (§3) |
| workarea procs with no caller (the mirror shape) | every `proc` in the three `*_procs.tcl` | 0 | |

## 2. Legitimate user hooks: optional knobs, default path runs

| knob | default when unset | where it is named |
|---|---|---|
| `svg_to_png` | SVG image filter off | `src/xschemrc` (commented examples) |
| `user_startup_commands` | none | `src/xschemrc`, `eval_user_startup_commands` |
| `slickprop_accent`, `slickprop_warn` | built-in colours | `doc/claude/specs/apply_scope_highlight.md` |
| `slickprop_highlight_color`, `_width` | built-in colour, width 2 | `doc/claude/specs/apply_scope_highlight.md`, `symbol_editor_apply_scope.md`, comment in `xinit.c` |
| `wviewer_reuse_max_distance` | cap off | `doc/claude/specs/waveform_viewer.md`, comment above `wviewer::reuse_max_distance` |
| `new_window_size_frac` | built-in fraction | source comment only (above the new-window sizing proc in `xschem.tcl`) |
| `palette_emphasis_color` | `#1a6fff` | source comment only (`action_registry.tcl`) |
| `PDK_LAUNCHER_NO_UI` | Tk loaded | test knob, comment in `tools/launcher/pdk_launcher.tcl` |
| `FLUID_TRACE*`, `WVDIAG`, `XSCHEM_BACKING_STORE` (env) | off | developer diagnostics |

Two of these are documented nowhere a user would look: `new_window_size_frac` and
`palette_emphasis_color` are named only in source comments. That is a documentation gap, not
a dead gate. I did not pursue it.

## 3. Dead branches: measured, not changed

| site | gate | measurement | why nothing is lost |
|---|---|---|---|
| `callback.c`, the semaphore≥2 click path in `handle_button_press` | `winfo exists .dialog.txt` | On `:271` I opened `enter_text`: `.dialog.txt=0`, `.dialog.f2.txt=1`. Nothing in the tree creates `.dialog.txt`. The widget was renamed upstream (`a8689becd` era). | The branch just above it tests `.dialog.f2.txt` and does the same thing (`.dialog.buttons.ok invoke`). |
| `xschem.tcl` `file_chooser`, the Dismiss button | `winfo exists .searchall` | On `:271` I opened `file_chooser` and invoked *Search all*: `file_chooser(searchall)=1` and `.searchall=0`. Toplevels: `.ins` plus the main window only. Dismiss rc 0. Upstream `19a28c65c` replaced that dialog with the listbox. | No window exists to close. |
| `src/xschemrc` | `# set xschem_doc_dir …` | nothing in src, utils or the workareas reads `xschem_doc_dir` | it is a commented example line |

**Decision (internal, mine):** I did not delete these. They are inert upstream lines in
`callback.c`, `xschem.tcl` and `xschemrc`. Deleting them changes nothing anyone can observe.
The only row that could go red on the dead version would be a text scan asserting the absence
of a string, which CLAUDE.md names as the weak instrument class. Deleting them would also add
diff against upstream for no behaviour. The driver may overrule; each is a one-line removal.

## 4. Row A22 (issue 1712)

**Cause.** The extra `draw.c` "site" is the block comment above `sym_text_vstack()`, added by
15b76baef (issue 1623). It names `text_hidden_inst()` in prose. The four real calls are
unchanged: two in `draw_symbol` (one in the P6 loop), one in `draw_temp_symbol`, one in
`inst_text_bbox`. So the golden was right. The census was reading prose, which is issue 1646's
shape. The product has no defect.

**Fix.** `dc_c_ngrep` counts after `dc_c_blank` blanks every `/* … */`, keeping newlines. A
new leg runs `dc_c_blank` on a fixed sample, so the strip cannot go idle without the row going
red.

| run | result |
|---|---|
| HEAD, display arm `:271` | `1 FAILED (133 passed)`, A22 `{5 2 2 1 0}` |
| fixed | `ALL PASS (134 checks)` |
| SA1: real stray call appended to draw.c | **red**: A22 `{5 2 2 1 0 {1 4}}`, and A38 also red |
| SA2: real P6 call removed (`if(0)`) | **red**: A22 `{3 …}`, and A38 also red |
| SA3: `dc_c_blank` made a no-op | **red**: A22 `{5 2 2 1 0 {3 4}}` |

Counted arm: `run_suites.sh --nogui` gives `NORESULT`. The suite is display-only by design
(its header says so).

**Not done: registration.** The suite is in no T1 list (`test_annot_declutter_1244` appears 0
times in `tests/run_regression.tcl`). It would need a `dcases`-only entry after checking its
epilogue against `banner_complete`. It may also need the short-path gate clone, because it
shares `test_op_annot`'s ancestry. This is recorded as `open=1` in 1712 and left to the driver.

## Blind spots of the method

- **Dynamic names built from runtime strings.** For example `::ase::backend::${sim}::X`,
  `cursor${which}_x`, or `$cl`. These are covered only for the values the live registry held
  (one simulator, ngspice). A second backend's legs would need the same probe.
- **Lazily loaded code.** A gate inside a file that is sourced only on a user gesture is
  checked by text alone. The runtime dump is a startup snapshot. Variables set lazily (34
  qualified `info exists` names) were checked for a setter in source, not for the setter
  being reachable.
- **Unqualified `info exists x` on proc locals.** These were matched against any setter or
  formal of that name anywhere, which is loose. A local that is never set in its own proc but
  set under the same name elsewhere would slip through.
- **Array-element gates** (`info exists X(key)`). Only the array name was checked, not the key.
- **`winfo exists` on variable-built paths.** These were not resolved. Only literal paths
  were, and the 11 literal paths built through `$w`/`$f` were checked by reading.
- **Regex coverage.** A gate whose `{` sits on the next line, or that is split by a backslash
  continuation, is missed by every extraction above. So are names hidden in `eval`/`subst`
  strings.
- **The mirror shape** (a hook defined and documented as called, but never called) was censused
  only for the workarea procs files, not for `src/*.tcl`. A tree-wide word-frequency attempt
  was abandoned because of binary files.
- **Symbol attributes C reads by name** (`get_tok_value(…, "attr")`) that no symbol carries
  were not censused.
