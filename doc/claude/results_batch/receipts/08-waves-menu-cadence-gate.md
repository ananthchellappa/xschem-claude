# Item 8 — `waves-menu-cadence-gate` — receipt

**Verdict `[E]`** — the payload is a modal refusal notice nobody has read on a screen. Base `226302f9`. U4/U12: **gated, not repaired.** No C touched, no rebuild.

## 1. Files changed

| file | +/- | what |
|---|---|---|
| `src/xschem.tcl` | +200/-9 | the gate — `waves_gate_msg`, `waves_gate_blocked`, `waves_op_annotate`; one guard as `load_raw`'s first executable statement; `Op Annotate`'s menu body lifted verbatim into the new proc; the U12 block comment |
| `tests/headless/test_waves_gate.tcl` | +741 (new) | the suite, `SEL417`–`SEL458`: 42 checks with a DISPLAY, 33 under `--nogui` |
| `doc/claude/specs/results_selection.md` | +228/-16 | new §7.2 (R505a–g); R505's tail, §17.2's "cannot get there through a menu", §12's T-L row, §11's L2 corrected **in place**; §18 re-checked |
| `doc/claude/issues/0508-…-no-test-drives-it.md` | +115/-9 | **FIXED = GATED, NOT REPAIRED**, caveat first |
| `doc/claude/results_batch/PLAN.md` | +6/-6 | item-8 pointers re-grepped |
| `specs/hierarchy_editor.md` · `specs/typed_signal_accessors.md` · `hierarchy_editor_batch/PLAN.md` | +5/-5 | citations restaled by this item's insert |
| this receipt | new | — |

**Closer correction — this item's own defect.** The fixer round added ~70 lines to `src/xschem.tcl` *after* the implementer refreshed the citations and did not re-refresh them, so the shipped docs pointed ~70 lines short: **landmine L9 again**, committed by the item that wrote L9's twin paragraph. Re-measured across all six docs, each verified with `sed -n '<n>p'`: `load_raw` `16808`→**`16874`**; cascade `17260-17278`→**`17332-17348`** (`Clear`→**`17335`**); checkbutton→**`17177`**; `set_ne cadence_compat 0`→**`18435`**; the `Simulation ▸ Graphs` twin→**`17709-17718`**; reload launcher→**`17704-17708`**; `build_menu_from_table`→**`17116`**; plus four in the neighbouring specs (`17428`→`17498`, `17547-48`→`17617-18`, `17455`→`17525`, `17621`→`17691`). The `scheduler.c` numbers the item re-derived (`:10850-10889`, wipe `:10865`, read `:10884`, `raw_clear` `:10835`, appending `raw read` `:10355`, `annotate_op` `:2410-2427`, `tclgetboolvar` `:14601`) were independently re-checked and are all **correct**.

## 2. Decisions, and the evidence

Seven crew rulings, all written into **spec §7.2**; none re-opens `DECISIONS.md`.

- **R505a — one guard in `load_raw`, not eight menu bodies.** Measured: `load_raw` has exactly ONE caller (`proc waves`, `:6385`) whose non-external branch is exactly `load_raw $type`. Eight copies drift, and a T-L greping eight bodies is satisfied by editing one (item 2's SEL82). *Declared cost:* the toolbar `Waves` button (`:15555`) and `-W`/`--waves` (`xinit.c:3839`) are gated too — deliberate; a gate a toolbar walks around is not a gate.
- **R505b — `Op Annotate` gets its own gate**, being the one entry not routing through `load_raw`; its body is lifted verbatim so the gate is a call, not a ninth copy. **Corrects the brief and 0508:** `annotate_op` does *not* wipe the registry — targeted `extra_rawfile(3, …)` delete plus an *appending* read (`scheduler.c:2410-2427`). T-L's clear/read sentence was never about it; it is blocked for U12's other reason.
- **R505c/d — one sentence composed once; `ciw_echo` + modal `alert_` under `has_x`.** Not `puts` (R802), not `results::_emit` (its four hosts are viewer/ase/calc/none, and a menubar is none of them). **Nothing is greyed out** — SEL443/444 pin `-state normal` in both flag states, because U12 says a blocked entry *says why*.
- **R505e/f/g — fixer round, each from a reproduced reviewer defect.** (e) the sentence takes the caller's entry name *and* reason: `Op Annotate` no longer asserts the wipe this item measured false; the name is surface-neutral (three surfaces reach the guard); the pointer names `Tools ▸ Launch ASE-L`, since `Results ▸ Select…` exists only on an ASE-L window (U5). (f) the flag is read as `tclgetboolvar` reads it — `set cadence_compat true` walked straight through a `!= 1` test while C considered Cadence mode ON. (g) `alert_`'s `grab set` is commented out, so a second blocked click threw `window name "alert" already exists in parent` out of a menu `-command`; the gate now retexts **its own** box and never destroys a foreign modal, since destroying one answers somebody else's question.
- **T-L IS DELIVERED AS A REINTERPRETATION, and the spec says so.** Outside `cadence_compat` the entries still reach `raw_clear`/`raw_read` and SEL418 *asserts* those three calls rather than their absence — forced by U4. What widened is the census's reach: two files (`src/xschem.tcl` + `src/actions.csv`, the palette surface) and three verbs (`raw_read_from_attr` added).
- **§18 re-checked — the five-path bypass list is UNCHANGED**; the Waves menu was never on it and stays a bypass whenever `cadence_compat` is 0. Two doors are left open by scope and are now named in §18 **and** in §17.2 where the reader lands: the verbatim `Simulation ▸ Graphs ▸ Annotate Operating Point` twin (`:17709-17718`), and `Add waveform reload launcher` (`:17704-17708`), whose symbol's `tclcommand=` is a bare `xschem raw_read` (U10's territory).

## 3. Test, checks, verbatim RESULT

`tests/headless/test_waves_gate.tcl` — **42 checks** with a DISPLAY, **33** under `--nogui` (group WD self-skips with a phrase that is none of `full_audit.sh`'s three skip substrings). **Arm, stated because the baseline's is not the same:** `devdisplay.sh status` reports `:99` **stale**, so `run_suites.sh` and `full_audit.sh` both fell back to their private Xvfb (identical `1920x1080x24`, openbox) rather than attaching to `:99`. The baseline was shot on `:99`; the status set came out identical anyway, which is the evidence that matters.

```
PASS     | test_waves_gate              run 1/1  RESULT: ALL PASS (42 checks)
RESULT: 1/1 runs passed
```

**Audit — judged as a DIFF, never by the red count.** `GUI_GATE=1 full_audit.sh` on `:99`: **334 pass / 15 fail / 0 crash-timeout / 0 skip of 349**, `WIREEDIT: PASS`, `SCRATCH: 0 leaked`, `TREE: 0 appeared 0 vanished`. Joined by name+status against `baseline_2026-08-19_226302f9.txt` (346 rows): **STATUS CHANGED 0 · ONLY IN BASELINE 0 · ONLY IN NEW 3** — `test_results_select` (item 1), `test_results_dialog` (item 7), `test_waves_gate` (item 8). The reds are the baseline's 15, by name. **Driver owes LEDGER's added-suites table a `test_waves_gate` row, total 349.**

## 4. Sabotage table

One row per check. **V** = verifier (28 drives), **F** = fixer (21), **C** = closer. Every drive restored from a byte-exact backup and re-run green.

| check | what was broken | red? | restored? |
|---|---|---|---|
| SEL417 | **UNSABOTAGED — NOT evidence.** `$HOME` fixture guard; `xinit.c:3867-3868` pins `::update_recent_files` to 0 for a whole `--script` body, so no real-code edit can move it (V aimed one; it stayed green). Only a test-side control reds it. | — | — |
| SEL418 | F: a 9th cascade entry wired to `xschem raw_read` (F-NINTH); V: `Clear` gated / no-op'd | yes | yes |
| SEL419 | F: descend-carry site `raw_read $f $t` → `raw_read $f` (F-OTHERSHAPE) | yes | yes |
| SEL420 | F: shared verb regexp → `ZZNOMATCHZZ` (vacuity control, test-side by construction) | yes | yes |
| SEL421 | **C-GATEDEL (closer, independent): `load_raw`'s two-line guard deleted on the shipped tree — md5 `9dc3e94b`→`1427e00f`. Reds EXACTLY SEL421/432/433/434/435/446/451/453/454/458, the set the fixer claimed. Restored from backup, `cmp -s` clean, re-run ALL PASS 42 + 33.** Also V: guard moved after `select_raw` | yes | yes |
| SEL422 | V: `wg_gate_pos` short-circuited to `gate-first` (vacuity control) | yes | yes |
| SEL423 | V: `waves_op_annotate`'s own guard deleted (S-OPANN-UNGATE) | yes | yes |
| SEL424 | F: both `cadence_compat` mentions removed from the sentence (F-NOCC) | yes | yes |
| SEL425 | F: `ASE-L > Results > Select…` → "somewhere else" (F-NOPOINT) | yes | yes |
| SEL426 | F: composer ignores the caller's reason — `because $why` → `because reasons` | yes | yes |
| SEL427 | F: way-out clause made non-actionable, setting name kept — reds alone | yes | yes |
| SEL428 | F: `$entry` dropped from the composer (F-FIXEDENTRY) | yes | yes |
| SEL429 | F: `ase::ui::rsel_dialog` renamed + the ASE-L entry relabelled, in `src/ase_window.tcl` | yes | yes |
| SEL430 | F: gate blocks unconditionally (F-BLOCK1); V: inverted (S-INVERT) | yes | yes |
| SEL431 | F/V: the same two — the refusal is said with the flag OFF | yes | yes |
| SEL432 | F: gate never blocks (F-BLOCK0); C: F-GATEDEL | yes | yes |
| SEL433 | V: `catch {ciw_echo $msg error}` deleted (S-NO-CIW); C: F-GATEDEL | yes | yes |
| SEL434 | V: guard moved after `select_raw` — refuses only *after* asking for a file | yes | yes |
| SEL435 | C: F-GATEDEL | yes | yes |
| SEL436 | V: the 8-entry drive list cut to 3 (count guard; SEL435 `lsort -unique`s and stayed green) | yes | yes |
| SEL437 | F: F-BLOCK1; V: S-INVERT | yes | yes |
| SEL438 | V: S-OPANN-UNGATE — proves `load_raw`'s guard does **not** cover `Op Annotate` | yes | yes |
| SEL439 | V: the `select_raw` call removed from `waves_op_annotate` (S-OPANN-NOSEL) | yes | yes |
| SEL440 | V: `Clear` entry's `-command` gated (S-CLEAR-GATED) / no-op'd (S-CLEAR-NOOP) | yes | yes |
| SEL441 | V: `proc waves`'s `$type ne {external}` → `1`, routing External viewer into `load_raw` | yes | yes |
| SEL442 | F: F-BLOCK0 and F-BLOCK1; V: S-NO-CIW | yes | yes |
| SEL443 | F: F-NINTH; V: `-state disabled` on Tran (S-GREY), label `Tran`→`Transient` (S-LABEL) | yes | yes |
| SEL444 | V: `-state disabled` on the Tran entry (S-GREY) | yes | yes |
| SEL445 | V: `Op Annotate` reverted to its original **ungated inline body** (S-OPANN-INLINE) | yes | yes |
| SEL446 | V: the `alert_` call deleted while `ciw_echo` still fires — 1 FAILED, headless all green | yes | yes |
| SEL447 | V: S-LABEL; F: F-NINTH (index shift) | yes | yes |
| SEL448 | V: S-EXT-ROUTE, S-CLEAR-GATED, S-CLEAR-NOOP — three independent recipes | yes | yes |
| SEL449 | F: F-BLOCK1; V: S-INVERT, S-GREY, S-NINTH | yes | yes |
| SEL450 | F: F-BLOCK1; V: S-OPANN-NOSEL | yes | yes |
| SEL451 | F: `Op Annotate` given the loaders' false wipe-reason (F-REASON); and the entry name made menu-only (F-MENUNAME) — **each reds SEL451 alone** | yes | yes |
| SEL452 | F: the `Tools > Launch ASE-L` clause deleted (F-NODOOR2); and that entry relabelled (F-NOLAUNCH) | yes | yes |
| SEL453 | F: boolean read reverted to `$cadence_compat != 1` (F-BOOL) — a 10-row value table | yes | yes |
| SEL454 | F: guard conditioned on `[xschem raw_query loaded] != -1` (F-EMPTYOK, the reviewer's own recipe — it left the old 34 green) | yes | yes |
| SEL455 | F: F-BLOCK1 | yes | yes |
| SEL456 | F: `set show_hidden_texts 1` moved ahead of the gate (F-SIDEFX — also left the old 34 green) | yes | yes |
| SEL457 | F: the reviewer's exact regression row `waves.zap,…,raw_read_from_attr,…` appended to `src/actions.csv` (F-CSVROW) | yes | yes |
| SEL458 | F: the whole re-entrancy branch replaced by a bare `alert_ $msg` (F-REENTRY) — the only check running the **real unshimmed** `alert_` | yes | yes |

## 5. What was NOT verified

- **THE EYEBALL, AND WHY `[E]`.** The refusal notice is a modal box on nine entries nobody has read on a screen; it **is** the user-facing payload, and the fixer round changed its wording. Two look debts stand, both confirmed in `owed.sh list`: `results-item8-waves-gate-refusal-notice.1787226883.1416066`, `results-item8-fixer-round-refusal-sentence.1787231200.1498145`.
- **13 reviewer findings clustered to 9 defects: all confirmed, reproduced and fixed; the unconfirmed list was EMPTY.** One proposed fix was declined with evidence — per-surface entry names need a new argument threaded through `src/xinit.c`, outside the fence; surface-neutral wording shipped instead, and SEL451 asserts "Waves menu" is **absent** from the sentence.
- **Reviewer not-proven, carried:** the toolbar button and `-W`/`--waves` are gated by reading plus a bare `waves` drive — never a real click or startup (one `-W` attempt did not source its rc and proved nothing); `cadence_compat` was set from the test, never clicked in the Options checkbutton; no multi-tab drive (the flag is in `tctx::global_list`, the registry per-`xctx`); no installed tree, no `:0`, no leak trace; the descend-carry `raw_read` sites were not driven against a two-database registry.
- **Left open by scope:** the ungated `Simulation ▸ Graphs` twin and the reload-launcher symbol (both now named in §17.2 and §18); the `raw_read` C repair U4 declined; `raw_is_loaded` (item 9); `calculator.tcl` (item 10); `autoload=` graph rects (U10).
- **Two `.sh` reds a reviewer found** (`test_file_menu_log.sh`, `test_action_replay.sh`) A/B'd identical against a HEAD-version `XSCHEM_SHAREDIR` — **pre-existing**. `full_audit.sh` globs `test_*.tcl` only, and item 8 touches no `.sh` suite.
- **`$HOME` — checked, not assumed**, before and after every drive and both audits. `raw_history` `34ff432f…`, `recent_files` `f219bba5…`, `xschemrc`, `library.defs`, `recent_files.bak`, `net_hilight_editor_seen` and `pdk_launcher.conf` are byte-identical to the driver's `pre-item8` snapshot. `geometry` and `.clipboard.sch` moved — rewritten by any GUI xschem exit and by `xschem copy`; neither restored, since putting a file back is still a write. **The guard covers only top-level `~/.xschem`**: `~/.xschem/simulations/*.spice` is rewritten by audit tests netlisting into the default `netlist_dir` — long-standing, not this item's.
- **The item's audit artifact `doc/claude/results_batch/audit_item08_2026-08-20.txt` (121 KB, untracked) is DELIBERATELY NOT COMMITTED** — items 1–7 kept their audits in scratchpads only (CREW_BRIEF §6) and it now holds the fixer round's run, not the closing one. Left on disk rather than deleted, since it is another agent's work; the closing audit is in the session scratchpad. Driver's call.
- **Driver owes:** the LEDGER added-suites row (`test_waves_gate`, total **349**), and `CREW_BRIEF.md:104`, which still cites `scheduler.c:10776-10793` for the registry-clearing `raw_read` arm (real `:10850-10889`) — driver-owned, so left alone here, though the same number was corrected in the spec, the issue and the gate comment.
