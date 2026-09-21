# F-verify — issue 1486, the one fix round

Fixer receipt. Tree `fluid-editing`, HEAD `9fcf9177`, item F's uncommitted work in place.
Every measurement below was taken on a binary rebuilt from the tree that produced it
(`timeout 900 make -C src`). Scratch `/var/tmp/xsr_f/FIX/`, **peak 3.7 MB**, deleted at the
end of the round; `/var/tmp/xsr_f` itself left alone (other crews share it).

**Verdict on the eight findings: 1 blocker APPLIED, 1 must APPLIED, 2 shoulds APPLIED (one
by a different mechanism than proposed, with a measured reason), 4 nits APPLIED. None
rejected as wrong.** Two things are written down for the driver to file rather than fixed
here (acceptance criterion 4).

---

## 1. blocker — `clear_schematic()` forgot a backup this session wrote. **CONFIRMED, FIXED.**

### Verified before touching anything

Fixture: a copy of `xschem_library/examples/0_examples_top.sch` as `foo.sch` in a private
directory, `$PWD` and cwd both pointing at it. Script:

```
xschem load $d/foo.sch
xschem instance .../lab_pin.sym 100 100 0 0 {name=zz1}   ;# foo~.sch written
xschem load $d/foo.sch                                    ;# the reload DISCARDS the edit
xschem clear force
```

| build | `C after clear: foo~ exists=` |
|---|---|
| pre-1486 (`actions.c:6573` reverted to the unconditional `remove_backup()`, rebuilt) | **0** |
| item F as it stood (the boolean) | **1** |
| this fix (the path) | **0** |

The middle row is the regression: `load_schematic()` cleared `xctx->backup_written`, so any
load between the write and the discard made xschem forget its own `~`. The next open of
`foo.sch` then fires `xschem_recover_backup()` and offers, as crash recovery, edits the
user deliberately discarded.

### What changed

`int backup_written` → **`char backup_owned[PATH_MAX]`**, the path we actually wrote:

| file | change |
|---|---|
| `src/xschem.h` | `backup_owned[PATH_MAX]` replaces the flag; two new prototypes |
| `src/save.c` | `write_backup()` stores `bak`; `remove_backup()` clears ownership **only when the path it unlinked is the one we owned**; new `remove_backup_if_owned()` and `drop_owned_backup()`; `load_schematic()` **no longer clears** — with the reason in the comment |
| `src/actions.c` | `clear_schematic()`: `drop_owned_backup()`; `go_back()`'s "No" arm: `remove_backup_if_owned()` (finding 7) |

`remove_backup()` itself stays unconditional on purpose: its other callers are
`save_schematic()` (a real save commits the content) and `xschem backup remove` (an
explicit instruction). Only the **discard** paths are ownership-checked.

Because ownership is now a path, every unlink is of a file this session demonstrably wrote,
so no comparison can ever delete a foreign `~`. The cost is one slot: a session that writes
a second backup stops tracking the first. **The failure direction is a leftover `~`, never
a delete of someone else's**, and it is stated in the struct comment. It is also strictly
better than the boolean, which lost ownership on every `remove_backup()` whatever cell it
was for — and it additionally drops the `untitled~.sch` we wrote before opening a cell,
which the boolean leaked.

### The three false "STRENGTHENED" claims

Corrected, not deleted, in all three places (`src/actions.c`'s `clear_schematic()` comment,
`tests/headless/test_untitled_autosave_1486.tcl`'s header, and F-impl.md §2a via the
fix-round section appended to it). The honest statement now recorded: **B8 has two
directions** — it is broken by deleting a `~` we did not write *and* by leaving one we did
— and the first cut broke the second while claiming to strengthen it.

### New rows

* **U5** — the load/edit/reload/clear sequence above. `U4` cannot see it (no intervening
  load) and `U3` cannot (no load at all), which is why the suite was `ALL PASS (10 checks)`
  with the defect live.
* **U6 / U6b** — finding 7's call site, below.

---

## 2. must — "no suite leaves anything else behind" is false. **CONFIRMED, CLAIMS SCOPED.**

Re-measured, not taken on trust. All five target files were present in the checkout with
tonight's mtimes. I moved `tests/from_user/before_10~.sch` out of the tree (to
`/var/tmp/xsr_f/FIX/aside/`), confirmed it absent, ran

```
tests/headless/run_suites.sh --nogui test_fluid_bodyshove_guards_0132
```

— the **armed** driver, whose `$PWD` redirect is the whole of item F's harness half — and
it came back: `2026-09-20 22:35:49, 656 bytes`, `md5 57589d12589dec3febcb720e3dcefbac`,
**byte-identical** to the copy I had moved aside. `backup_file_name()` puts the `~` beside
the **cell**, not in `$PWD`, so the redirect structurally cannot reach it, and a sweep that
watches only private working directories cannot see it.

The verifier's attribution of nine suites to five files is recorded verbatim in
`tests/headless/suite_cwd.sh`'s header (I re-measured one of the nine, not all nine).

**Fixed by scoping the sentences**, in `tests/headless/suite_cwd.sh`'s header and in
`tests/headless/test_untitled_autosave_1486.tcl`'s header: "no suite leaves anything else
**in its working directory**", plus an explicit ⚠ block naming the nine suites, the five
files, and the fact that the pre-1486 binary leaves the same nine identically — **so this
is not a regression**. F-impl.md's §1 and §3b are corrected in the appended fix-round
section.

**NOT fixed here** (acceptance criterion 4): the nine-suite `cellName~` class belongs to
issues **0609** / **1480**. → driver.

---

## 3. should — cleanup bypassed on two early exits. **CONFIRMED, FIXED — but NOT with a trap.**

Reproduced exactly as described:

```
XSCHEM=/nonexistent/xschem GUI_GATE=0 AUDIT_DISPLAY=none tests/headless/gated_xschem.sh --nogui --pipe -q
  -> FATAL: xschem binary not found/executable at: /nonexistent/xschem
  -> left tests/headless/.scratch/_suitecwd_2065276/
```

After the fix the same command leaves **none**.

**The trap sub-option is refused, on measurement.** A shell has exactly one EXIT trap and
two libraries in this harness already want it: `tests/headless/test_home.sh:590` installs
`trap '_th_cleanup' EXIT` (which deletes the throwaway HOME) and
`tests/headless/gui_gate.sh:630` installs `trap 'gate_finish' EXIT` **only when none
exists**. `suite_cwd_arm` runs *after* the home arm and *before* `gate_start` in all three
drivers, so an unconditional trap there would clobber the throwaway-home cleanup, and a
conditional one would simply never install (the home trap is already there) — and where it
did install it would stop the gate installing its own, leaving a stuck Pause panel. Trading
a leaked scratch directory for a leaked throwaway home is a worse bargain. That reasoning
is written into `suite_cwd.sh` above `suite_cwd_arm`, so the next reader does not re-derive
it.

**Applied instead:** `suite_cwd_disarm` on both exits
(`tests/headless/full_audit.sh`'s gate-stop, `tests/headless/gated_xschem.sh`'s FATAL),
**and the verifier's second half — S1 now requires a disarm on every `exit` between the arm
and the standalone disarm**, so the growing list of exits is covered by the test rather
than by anybody remembering.

---

## 4. should — the leak detector never looks inside the private `$PWD`. **CONFIRMED, FIXED.**

`suite_cwd_disarm` now lists anything that is not an `untitled*` before removing the tree.
Measured with a probe that plants one expected and two unexpected files:

```
SUITECWD: unexpected file(s) in the private $PWD before it was removed: probe/stray_output.log probe/sub/other.raw  -- (n=2, issue 1486)
```

`untitled~.sch` is correctly not named. **The line ends in `)` deliberately**: it must not
be able to end in a shape the verdict readers count (`FAIL`, `GOLD?`, `RESULT?`) whatever a
stray file happens to be called. Sabotage S-I (listing removed) makes the probe silent, so
the line is produced by the new code and not by something else.

I did **not** reorder `full_audit.sh`'s disarm relative to its SCRATCH/TREE snapshots: the
private tree is outside `scratch_snapshot`'s globs either way, and the listing closes the
hole without moving a line that other rows depend on.

---

## 5. nit — `SUITE_CWD_ROOT` read from the environment. **CONFIRMED, FIXED.**

`SUITE_CWD_ROOT=""` unconditionally at source time. Red-first re-measured on my own tree by
restoring the `${SUITE_CWD_ROOT:-}` form (sabotage S-H):

| | probe_root afterwards | note printed |
|---|---|---|
| env read restored (sabotage) | `1_test_descend_inert_class/ 2_test_crossview_paste/` **left, with their autosaves** | `refusing to remove '…' (not a suite_cwd name)` |
| fixed | **empty** | none |

(`run_suites.sh --nogui test_descend_inert_class test_crossview_paste`, both PASS in both
arms.)

---

## 6. nit — S1's guard patterns too narrow. **CONFIRMED, FIXED, and widened further.**

* **Disarm terminator** now takes `;`, `&`, `|` and `)` as well as space/end-of-line, so
  the inline `...; suite_cwd_disarm; exit 3; }` form every early exit uses is recognised.
* **Invocation test replaced by POSITION, not shape.** The old
  `{"\$XSCHEM"[ \t]+(-|"\$@")}` is gone; `launches_binary` tokenises the line, treats
  `$(`, `)`, `;`, `&&`, `||` and `|` as command boundaries, skips wrapper words
  (`env`, `timeout` **and its duration argument**, `nohup`, `exec`, `command`, shell
  keywords) and `VAR=value` prefixes, and asks whether the next word is `$XSCHEM`.
  Measured: the old pattern returns **0** for both `$XSCHEM --pipe …` (unquoted) and
  `"$XSCHEM" "$f"`; the new one flags the first (sabotage S-G below) while all five
  non-launch shapes in the three drivers — `case "$XSCHEM" in`, `[ ! -x "$XSCHEM" ]`,
  `$(dirname "$XSCHEM")`, `$(basename "$XSCHEM")` and the FATAL `echo`s — still pass.
* **`exits_here`** recognises `exit` only as a command (line start or after `;&|{}`), never
  after another word or after `(`, because `run_suites.sh:217` and `:255` both spell the
  word "exit" inside a message string and a looser pattern reds on them.

---

## 7. nit — `go_back()`'s "No" arm unguarded. **CONFIRMED — and it is now MEASURED, not read.**

The verifier marked this `measured: false`. It reproduces. Fixture: the repo's own
`tests/headless/fixtures/descend/descend_child.{sch,sym}` copied into a private directory
with a seeded foreign `descend_child~.sch`; child script sets the issue-0601 guard
`set ::autosave_backup 0`, places an instance on the untitled buffer, descends, edits the
child, and calls `xschem go_back` with `ask_save` returning `no`.

| build | seeded `descend_child~.sch` |
|---|---|
| `else remove_backup();` (item F, and HEAD) | **exists=0 — DELETED** |
| `else remove_backup_if_owned();` (this fix) | **exists=1, byte-identical** |

That is a previous session's crash recovery for a cell, destroyed by answering "No" to a
save prompt, in the condition nine suites in this repository run in. Rows **U6** (foreign
file survives with the guard on) and **U6b** (our own backup is still dropped, with the
child recording that it existed *before* `go_back` so the row cannot pass by absence) now
hold both directions.

---

## 8. nit — the overbroad `~` claim in F-impl.md §7. **CONFIRMED, SCOPED.**

`/home/analog/.cache/openbox/openbox.log` has mtime **2026-09-20 21:53:39**, inside item
F's round; the dev display's own openbox started **14:37:48** and is still running, so that
write is a different, privately started openbox — exactly as the verifier reconstructed.
Re-checked at the end of my round: **still 21:53:39**, so my work did not write it either
(I attached to the existing `:99` through `run_suites.sh` and started no window manager).
The sentence in F-impl.md §7 is corrected in the appended section.

A sweep of `~` (maxdepth 3, last 90 minutes, excluding `dev/`, `.cache/`, `.claude/`) found
only `~/.claude.json`, which is Claude Code's own state file and not a test artefact.
`.xschem/op_param_lists.conf` re-verified **untouched**: mtime `2026-09-09 09:58:51`,
2236 bytes, md5 `aedef2a43789f827edd75934d703056e` — the same values F recorded.

---

## 9. Sabotages — every new or changed check shown failing

Each reverted and rebuilt afterwards; the suite is `ALL PASS (13 checks)` before and after
every one. `/usr/bin/grep -c SABOTAGE` over `src/*.c` and `tests/headless/*.sh` is **0** at
the end of the round.

| # | sabotage | rows that went red |
|---|---|---|
| S-A | `load_schematic()` clears `backup_owned` (the boolean's regression) | **U5** only (`exists: 1`) — U1/U3/U4/U6/U6b green |
| S-B | `go_back()`'s "No" calls `remove_backup()` (item F, and HEAD) | **U6** only (`now: <absent>`) |
| S-C | `go_back()`'s "No" removes nothing (the over-correction) | **U6b** only (`written before go_back: 1; still there after: 1`) |
| S-D | `clear_schematic()` calls `remove_backup()` unconditionally (pre-1486 product) | **U1** and **U4** (`now: <absent>`) |
| S-E2 | `clear_schematic()` drops nothing (the over-correction) | **U3** and **U5** (`exists: 1`) |
| S-E | `gated_xschem.sh:100` loses its new disarm | **S1** (`gated_xschem.sh:100: exit after suite_cwd_arm with no disarm -> exit 1`) |
| S-F | `gated_xschem.sh:108` loses its **inline, semicolon-terminated** disarm | **S1** (`gated_xschem.sh:108: …`) — proves the widened terminator is what sees it |
| S-G | `run_suites.sh:173` rewritten `$XSCHEM` unquoted with no `PWD=` | **S1** (`run_suites.sh:173: starts the binary with no PWD=`) **and D1** (`new: …/untitled~.sch`) — the old pattern returns 0 on this line |
| S-H | `suite_cwd.sh` reads `SUITE_CWD_ROOT` from the environment again | the probe in §5: autosaves left in the hijacked root |
| S-I | `suite_cwd_disarm`'s listing removed | the probe in §4 prints no `SUITECWD:` line |

S-D and S-E2 are the two directions of B8 at `clear_schematic()`; S-B and S-C are the same
two at `go_back()`. Neither pair can be satisfied by "always remove" or "never remove".

---

## 10. No regression in the developer's condition

`tests/headless/run_suites.sh --nogui`, 32 suites, on the final binary:

```
PASS test_backup_file                  PASS test_descend_untitled_preserve
PASS test_descend_preserve             PASS test_descend_fidelity
PASS test_descend_efficiency           SKIP test_descend_goback_selflog (self-skipped: no X)
PASS test_descend_inert_class          PASS test_descend_readonly
PASS test_descend_symbol               PASS test_descend_newwin_return
PASS test_descend_views                PASS test_descend_refusal_channel_0251
PASS test_no_untitled_litter           PASS test_untitled_reuse (6)
PASS test_pristine_untitled_basename (2)  PASS test_untitled_name_dir_0323 (8)
PASS test_crossview_paste              PASS test_reopen_readonly
PASS test_paste_modify_flag_0244 (444) PASS test_placement_wire_gate (187)
PASS test_shape_draw_gate (421)        PASS test_instance_update (95)
PASS test_home_isolation (116)         PASS test_home_isolation_sh (90)
PASS test_audit_classifier (75)        PASS test_ase_core (675)
PASS test_op_dump_altshow (71)         PASS test_add_pin_lib_symbol_view
PASS test_apply_properties_readonly    PASS test_undo_link_symbols
PASS test_untitled_autosave_1486 (13)
FAIL test_load_window_routing (4 FAILED, 10 passed)   <- NOT MINE, see below
```

The descend family is the exposed one (I changed `go_back()`) and all eleven are green,
`test_descend_untitled_preserve` — issue 0060's own regression — included.

`tests/headless/full_audit.sh test_descend_inert_class test_op_dump_altshow
test_backup_file` (exercises the audit's arm, its four exec sites and its disarm):
`SUMMARY: 3 pass 0 fail 0 crash/timeout 0 skip`, `SCRATCH: 0 leaked dir(s)`,
`TREE: 0 appeared 0 vanished`.

### `test_load_window_routing` is a PRE-EXISTING red, proved by building HEAD

It fails `LR1b`, `LR5b`, `LR5e`, `LR6` under `--nogui`. Rather than argue, I checked out
`src/actions.c`, `src/save.c` and `src/xschem.h` at HEAD — i.e. **no 1486 product change at
all, not even item F's** — rebuilt, and ran the same command: the **same four rows, same
messages**. It is a `-gui` window-routing suite being run on the `--nogui` arm. Its display
arm is no help here either: `run_suites.sh test_load_window_routing` on the persistent dev
display `:99` returns **`TIMEOUT … (after 200s)`**, the same shape CLAUDE.md records for
`test_wave_markers` (issue **1488**). Sources restored and rebuilt afterwards.

→ **driver:** a second suite that times out on the persistent dev display, and reds under
`--nogui`. Worth adding to 1488 rather than filing fresh.

---

## 11. What I did NOT fix, and why

1. **The nine-suite `cellName~` class** (finding 2). Out of scope by acceptance criterion
   4; belongs to 0609/1480; measured identical on the pre-fix binary, so it is not a
   regression this batch introduced. The names are recorded in `suite_cwd.sh`'s header so
   whoever picks it up does not re-derive them.
2. **`test_load_window_routing`** (§10). Pre-existing on HEAD; out of item F.
3. **`full_audit.sh`'s disarm/snapshot ordering.** The listing (finding 4) closes the
   visibility hole; moving the disarm would perturb the two leak detectors for no measured
   gain.
4. **T1 registration of `test_untitled_autosave_1486`.** Still not done — F-impl.md's
   opening note stands, and `tests/run_regression.tcl` now carries item E's committed
   change plus further uncommitted edits. **The driver must add the `hcases` entry**, which
   makes T1 88 cases / 87 `Total num fail:` lines. Until then the fix is green but ungated.
5. **T1 itself was not run.** `tests/run_regression.tcl` and
   `tests/headless/test_regression_concurrency_1476.tcl` still carry uncommitted edits from
   item E, so a T1 number taken here would measure E's in-flight tree, not this change. The
   driver's gate run is the right place, after the registration above.

---

## 12. Files changed in this round

```
 src/xschem.h                                   backup_owned[PATH_MAX] replaces the flag; 2 prototypes
 src/save.c                                     write_backup / remove_backup / +remove_backup_if_owned
                                                +drop_owned_backup / load_schematic no longer clears
 src/actions.c                                  clear_schematic -> drop_owned_backup;
                                                go_back "No" -> remove_backup_if_owned; comment corrected
 tests/headless/suite_cwd.sh                    scoped header + the nine cellName~ suites; SUITE_CWD_ROOT
                                                script-local; disarm lists unexpected files; no-trap rationale
 tests/headless/full_audit.sh                   suite_cwd_disarm on the gate-stop exit
 tests/headless/gated_xschem.sh                 suite_cwd_disarm on the FATAL exit
 tests/headless/test_untitled_autosave_1486.tcl +U5 +U6 +U6b; S1 rewritten; header claims corrected
 doc/claude/stranger_reds_batch/receipts/F-impl.md   fix-round section appended
 doc/claude/stranger_reds_batch/receipts/F-verify.md this file
```

Nothing else was touched. `.xschem/op_param_lists.conf` verified untouched (§8). The dev
display `:99` was attached to, never started or stopped; `~/.claude` and
`~/dev/xschem-op-wcard` were never written.

## 13. Scratch

`/var/tmp/xsr_f/FIX/` — **peak 3.7 MB** (three fixture directories, the pre-fix and
sabotage copies of `actions.c`/`save.c`/`xschem.h` and of the three drivers, one moved-aside
`before_10~.sch`). Deleted by me at the end of the round; `/var/tmp/xsr_f` itself left
alone.
