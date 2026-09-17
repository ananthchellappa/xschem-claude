# save-citations — `src/save.c:4149` and its drift neighbourhood, corrected in 11 files

**Status:** DONE

## Headline

`R3-build`'s report was **exactly right on the count and understated on the damage**.
Seven suites cite `src/save.c:4149`; all seven were stale. But those same seven comment
blocks carried **eight more** stale coordinates beyond the `4149` token itself, and the
same drift had reached four files nobody had connected to it. **30 coordinates on 29
lines across 11 files**, all comment-only, all line-count preserving.

`src/save.c:4149` today is `if(raw && raw->fold_table.table) int_hash_free(&raw->fold_table);`
inside `raw_fold_table_clear()` — raw-waveform alias-table code, with no relationship
whatever to autosave backups. `write_backup()` is at **`src/save.c:6139`**.

**The drift in this neighbourhood is a near-uniform `+1990`**, which is the cheap check
for anyone auditing the rest of it:

| old | +1990 | measured today | what it is |
|---|---|---|---|
| `4126-4141` | 6116-6131 | **6116-6131** ✅ | `backup_file_name()` (the `~` name) |
| `4149` | 6139 | **6139** ✅ | `void write_backup(void)` |
| `4156` | 6146 | **6146** ✅ | `if(!tclgetboolvar("autosave_backup")) return;` |
| `4159-4162` | 6149-6152 | **6149-6152** ✅ | "back up even when name has no file yet" (issue 0060) |
| `4164` | 6154 | **6154** ✅ | `if(!(fd = fopen(bak, "w")))` — the create |
| `4175-4182` | 6165-6172 | **6165-6172** ✅ | `remove_backup()` |
| `4191` | 6181 | **6181** ✅ | `int load_backup_as(...)` |
| `4197` | 6187 | **6186** ⚠ **+1989** | `load_backup_as`'s `autosave_backup` early return |
| `4207` | 6197 | **6196** ⚠ **+1989** | `load_backup_as`'s closing `set_modify(1)` |

⚠ **The last two rows are the interesting ones.** Every citation in this family drifts by
exactly +1990 except the two that point *inside* `load_backup_as`, which drift by +1989.
A uniform block move cannot produce two different offsets in one function, so **`4197` and
`4207` were off by one on the day they were written** — the batch's "two citations were
wrong when written" pattern, found a third and fourth time. (Cross-check: `src/ase.tcl`
was already corrected to `save.c:6186` for the early return, and it says `6197` for
`set_modify(1)` where the measured line is **6196** — the original off-by-one was carried
forward through the correction.)

## Files touched

All comment-only. Line/column given as `file:line`.

| file | lines | old → new |
|---|---|---|
| `tests/headless/test_annot_show_menu.tcl` | `:54` | `save.c:4149` → `save.c:6139` |
| `tests/headless/test_delete_cut_selflog.tcl` | `:26,:27,:29` | `save.c:4149`→`6139`, `xinit.c:2952`→`3175`, `save.c:4156`→`6146` |
| `tests/headless/test_instance_update.tcl` | `:30,:31,:33` | same three |
| `tests/headless/test_perform_action_align.tcl` | `:50,:51,:53` | same three |
| `tests/headless/test_statusmsg_hold_0248.tcl` | `:40,:41,:43` | same three |
| `tests/headless/test_traversal_flag_leak.tcl` | `:14,:15,:16,:22,:34,:37,:38` | `scheduler.c:12030`→`12868`, `save.c:4713`→`6709`, `save.c:4795`→`6793`, `full_audit.sh:448`→`485`, `save.c:4149`→`6139`, `xinit.c:2952`→`3175`, `save.c:4156`→`6146` |
| `tests/headless/test_undo_selection.tcl` | `:15,:16,:17,:21` | `save.c:4149`→`6139`, `save.c:4159-4162`→`6149-6152`, `xinit.c:2952`→`3175`, `save.c:4156`→`6146` |
| `tests/headless/test_undo_link_symbols.tcl` | `:154,:561` | `scheduler.c:12030`→`12868`, `save.c:4713/4795`→`6709/6793` |
| `src/xschem.tcl` | `:5342` | `scheduler.c:12030` → `scheduler.c:12868` |
| `tests/headless/test_placement_wire_gate.tcl` | `:60` | `save.c:4407` → `save.c:6500` |
| `.gitignore` | `:36` | `save.c:4407` → `save.c:6500` |

**Nine distinct stale values corrected**, each verified against the source line it now names:

```
ok   src/save.c:6139 contains 'void write_backup'
ok   src/save.c:6146 contains 'autosave_backup'
ok   src/save.c:6149 contains 'Back up even when'
ok   src/save.c:6152 contains 'issue 0060'
ok   src/save.c:6500 contains 'get_unused_untitled_name'
ok   src/save.c:6709 contains 'void push_undo'
ok   src/save.c:6793 contains 'void pop_undo'
ok   src/xinit.c:3175 contains 'getcwd'
ok   src/scheduler.c:12868 contains 'no_undo'
```

`full_audit.sh:485` verified separately as the **`else` (default) arm** — note `:483` runs
a byte-identical command for `nolog_tests`, so the two are distinguishable only by which
branch they sit in, and only `:485` is the *default*:

```
484	  else
485	    out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --script "$testfile" 2>&1); ec=$?
486	  fi
```

## Rows added/changed

**None, deliberately.** This is a comment-only pass; no suite's assertions, check names,
counts or control flow were touched. No row can red or green as a result, which is why
the verification below is a diff-shape proof rather than a test run.

## Commands run

```sh
timeout 60 /usr/bin/grep -rn 'save\.c:4149' .                      # the full citation set
timeout 60 /usr/bin/grep -rn --exclude-dir=.git 'save\.c:4[0-9][0-9][0-9]' .
timeout 60 /usr/bin/grep -n 'write_backup' src/*.c src/*.h
timeout 60 git diff -U0                                            # comment-only proof
timeout 60 git diff --numstat                                      # line-count proof
timeout 60 /usr/bin/grep -rn 'save\.c:4149' tests/ src/ .gitignore  # residual check
```

**No suite, no `./src/xschem`, no `make`, no `run_regression.tcl`** — another crew holds
the suite slot. Every command had a `timeout` and every grep was `/usr/bin/grep`.

## Measurements

| what | command | answer |
|---|---|---|
| citations of the literal `save.c:4149`, repo-wide | `grep -rn 'save\.c:4149' .` | **15** — 7 live suites, 7 docs/receipts/issues, 1 `.git/COMMIT_EDITMSG` |
| of those, **live suites** | same, filtered to `tests/` | **7 — exactly the seven `R3-build` named** |
| coordinates corrected | the diff | **30, on 29 lines, in 11 files** |
| distinct stale values | the table above | **9** |
| line-count preservation, my 11 files | `git diff --numstat` | **every file symmetric** (1/1, 1/1, 1/1, 3/3, 3/3, 3/3, 1/1, 3/3, 7/7, 2/2, 4/4) |
| residual stale coords in live files | `grep` for all nine old values in `src/ tests/ .gitignore` | **zero** |

### Step 5 — did my edits rot anything? **No, and the mechanism is structural.**

Every replacement is **digit-for-digit the same width** (`4149`→`6139`, `2952`→`3175`,
`12030`→`12868`, `448`→`485`, `4159-4162`→`6149-6152`). Nothing reflowed, no comment line
was added or removed, so **no line in any edited file moved at all**. `git diff --numstat`
is symmetric for all 11 of my files, which is the proof. The known inbound citations —
`test_annot_show_menu.tcl:75-95/:483-491/:1257`, `test_undo_selection.tcl:44`,
`test_placement_wire_gate.tcl:69-70`, `test_no_untitled_litter.tcl:62` pointing at
`test_placement_wire_gate.tcl:58-66` — are all still valid, unchanged.

## ⚠ A LIVE ROT I DID NOT CAUSE, AND THE DRIVER SHOULD ROUTE IT

`git diff --numstat` reported one **asymmetric** file:

```
!! ASYMMETRIC: 85	2	tests/headless/test_startup_guard_0663.tcl
```

**That file is on my do-not-touch list and I did not open it.** The hunks are another
crew's in-flight SG22 HOME-isolation block (`@@ -91,0 +92,43 @@`, `@@ -127,0 +171,6 @@`,
`@@ -335,0 +400,19 @@`) — **+83 net lines, inserted above almost every anchor in the
file.** Measured consequence, which is exactly the hazard my own step 5 guards against:

| citation | claimed | what is actually there now | where it moved to |
|---|---|---|---|
| `test_startup_guard_0663.tcl:230` (`F2.md:141`) | the `Tcl_AppInit() error` anchor | `# =====…` separator | the literal is at **`:253`**, SG21's block at **`:293-303`** |
| `:232` (`F1.md:278`, `F2.md:142`, `F4.md:166`) | "pins that literal by number" | a blank line | same block, **`:299-303`** |
| SG13 `:332-334` (`R2-R3-design.md:87`, **`DECISIONS.md:281`**) | the SG13 check | blank / `# ====` / `# R2 -- …` | SG13 is now at **`:396`** |
| SG14 `:343-352` (same two) | the SG14 check | SG9's check body | SG14 is now at **`:419-426`** |

**`DECISIONS.md` is the driver's own file and one of the rotted citers.** I have not
touched any of them — four are receipts (historical records) and `DECISIONS.md` is
explicitly reserved to the driver. Flagging, not fixing.

## Claims checked vs taken on trust

**Was "seven suites" right? — YES, EXACTLY RIGHT.** `R3-build` named
`test_annot_show_menu:54`, `test_delete_cut_selflog:26`, `test_instance_update:30`,
`test_perform_action_align:50`, `test_statusmsg_hold_0248:40`, `test_traversal_flag_leak:34`,
`test_undo_selection:15`. All seven confirmed present, at those exact lines, all stale.
Its "stale by ~2000 lines" is also right: the true offset is **+1990**.

Every citation, by verdict:

| citation | verdict | what settled it |
|---|---|---|
| `save.c:4149` ×7 suites | **CONFIRMED-STALE → CORRECTED** to `6139` | `grep -n 'write_backup' src/save.c` → `6139:void write_backup(void)`; `4149` reads `int_hash_free(&raw->fold_table)` |
| `save.c:4156` ×6 | **CONFIRMED-STALE → CORRECTED** to `6146` | read `write_backup()` body: `6146: if(!tclgetboolvar("autosave_backup")) return;` |
| `save.c:4159-4162` ×1 | **CONFIRMED-STALE → CORRECTED** to `6149-6152` | the issue-0060 comment block, read verbatim |
| `xinit.c:2952` ×6 | **CONFIRMED-STALE → CORRECTED** to `3175` | `3175: if(!getcwd(pwd_dir, PATH_MAX))`; `2952` is `XSetFillStyle(…FillTiled)` |
| `save.c:4713` / `:4795` ×2 files | **CONFIRMED-STALE → CORRECTED** to `6709` / `6793` | `6709:void push_undo`, `6793:void pop_undo`; the `no_undo` early returns are at `:6722` and `:6804` |
| `scheduler.c:12030` ×3 files | **CONFIRMED-STALE → CORRECTED** to `12868` | `12868: else if(!strcmp(argv[2], "no_undo"))`, sets at `:12871` |
| `full_audit.sh:448` ×1 | **CONFIRMED-STALE → CORRECTED** to `485` | `:448` is a gui_gate comment; `:485` is the `else` arm |
| `save.c:4407` ×2 files | **CONFIRMED-STALE → CORRECTED** to `6500` | `6500: get_unused_untitled_name(…)` inside `load_schematic` (def `:6337`); `4407` is `plot_raw_custom_data` |
| **`actions.c:208`** ×7 | **ALREADY-CORRECT — left alone** | `208: if((mod == 1 \|\| mod == 3) && !ro_suppress) write_backup();` — the one anchor in the whole family that never drifted |
| **`xinit.c:174`** ×2 | **ALREADY-CORRECT — left alone** | `174: * pwd_dir captured at startup. Tcl's 'cd' updates neither…` |
| **`full_audit.sh:64`** ×1 | **ALREADY-CORRECT — left alone** | `64: cd "$REPO" \|\| exit 2` |
| **`in_memory_undo.c:439/600`** ×1 | **ALREADY-CORRECT — left alone** | `439: if(xctx->no_undo)return;` in `mem_push_undo`; `600:` same in `mem_pop_undo` |
| **`test_undo_selection.tcl:24-25`**, **`test_placement_wire_gate.tcl:69-70`**, **`test_shape_draw_gate.tcl:44`** | **ALREADY-CORRECT — left alone** | each is the `set ::autosave_backup 0` guard it claims to be |
| **`xinit.c:180`** ×2 (`.gitignore:37`, `test_placement_wire_gate.tcl:62`) | **OFF BY ONE, left alone deliberately** | `get_unused_untitled_name` is defined at **`:181`**; `:180` is the last line of its own doc comment, so a reader following it lands on the right function. Fixing would be churn, not repair. Reported so the next reader does not re-derive it. |

**Taken on trust (not re-measured):** nothing load-bearing. `R3-build`'s nine corrections
inside `test_no_untitled_litter.tcl` were not re-verified — that file is on my
do-not-touch list — but the five of them that overlap my own targets
(`6139`/`6146`/`6149-6152`/`6500`/`3175`) I measured independently and **agree**.

## ⚠ REPORTED, NOT FIXED — the `load_backup_as` family, 6 sites in 2 files

The same drift reached a **different defect family** (issues 0495 / 0626 / 0632), and I
left it alone on purpose: those are not `save.c:4149` citations, `src/op_annot.tcl` is a
large live source file this batch has not claimed, and the task's own warning — *different
citations may mean different things* — applies. Targets are **measured and ready to apply**:

| file:line | old | measured today |
|---|---|---|
| `src/op_annot.tcl:2413` | `go_back (actions.c:4766)`, `load_backup_as (save.c:4191)` | **`actions.c:6435`** (def; the call is `actions.c:6505`), **`save.c:6181`** |
| `src/op_annot.tcl:2415` | `save.c:4207` | **`save.c:6196`** |
| `src/op_annot.tcl:3104` | `save.c:4191-4207` | **`save.c:6181-6196`** |
| `src/op_annot.tcl:3106` | `save.c:4197` | **`save.c:6186`** |
| `tests/headless/test_op_annot.tcl:10086` | `actions.c:4766`, `save.c:4191` | **`actions.c:6435`**, **`save.c:6181`** |
| `tests/headless/test_op_annot.tcl:10088` | `save.c:4207` | **`save.c:6196`** |

```
ok   src/save.c:6181 contains 'int load_backup_as'
ok   src/save.c:6186 contains 'autosave_backup'
ok   src/save.c:6196 contains 'set_modify(1)'
ok   src/actions.c:6435 contains 'void go_back'
ok   src/actions.c:6505 contains 'load_backup_as(filename'
```

⚠ **`src/ase.tcl` already carries the corrected spelling** (`save.c:6186`, `actions.c:6505`)
while `op_annot.tcl` still carries the pre-drift one — so this family is **half-fixed**,
which is worse than uniformly stale: a reader comparing the two files sees two different
answers and has no way to tell which is current.

**Also still stale in live files, same `save.c:4xxx` band, unrelated subjects** (reported
for whoever owns them, not measured for replacements): `src/actions.c:1452`
(`save.c:4850`), `src/select.c:2587` (`save.c:4035`), `src/move.c:4923` (`save.c:4475`),
`src/ase.tcl:15663` (`save.c:4161`), `tests/headless/test_op_annot.tcl:5530`
(`save.c:4868`), `tests/headless/test_raw_read_dispatch.tcl:878-879`
(`save.c:4399/4414/4428/4437`), `tests/headless/test_untitled_name_dir_0323.tcl:11,:64`
(`save.c:4413`).

**Docs/receipts/issues left untouched by design** — `H1.md:215`, `G1.md:174`,
`R2-R3-design.md:440`, `R3-build.md:151,157`, `0609:228`, `0601:29`. Receipts are dated
records of what was true when written; rewriting them falsifies the record, and this
follows `H1`'s own precedent (*".gitignore:55/:56 IS STALE IN 5 FILES — REPORTED, NOT
EDITED"*). ⚠ **One exception the driver may want to rule on:** `0601:29-35` is the
*"Root cause (chain, all file:line verified)"* section — the single most likely thing a
future investigator follows — and **every coordinate in it is now wrong**
(`save.c:4149`, `:4164`, `:4126-4141`, `:4159-4162`, `:4156`, `xinit.c:2952`,
`xinit.c:3690-3693`). All replacements are in the `+1990` table above.

## Corrections to PLAN.md

None — this task was dispatched from `R3-build`'s report, not from a plan stage.

**For the next crew:** the `+1990` table is the tool. Any `save.c:41xx`–`42xx` citation in
this repo that talks about backups, undo or untitled buffers can be checked in one
subtraction, and **an offset that is not +1990 means the citation was wrong when it was
written**, not that the code moved — which is how `4197`/`4207` were caught here.

## The standing proposal — "cite the emitter, not the line"

**Strong endorsement, with a measurement behind it.** Nine distinct values rotted in one
neighbourhood; `actions.c:208` is the *only* coordinate in this entire family that has
never moved, and it survived because `set_modify()` sits near the top of a file that grows
at the bottom. Position was luck, not stability.

Where the fix would obviously be more durable as a name, with specific wording:

| today | suggested |
|---|---|
| `write_backup() (src/actions.c:208 -> src/save.c:6139)` | `write_backup() (set_modify() in actions.c -> write_backup() in save.c)` — both ends already name the function; the numbers add nothing a grep cannot supply |
| `returns early when autosave_backup is off (src/save.c:6146)` | `returns early when autosave_backup is off (write_backup()'s `tclgetboolvar("autosave_backup")` guard)` |
| `backs up untitled buffers on purpose (src/save.c:6149-6152, issue 0060)` | `backs up untitled buffers on purpose (write_backup()'s "Back up even when 'name' has no on-disk file yet" comment, issue 0060)` — the comment text is the anchor and it is already unique in the tree |
| `the cwd captured at STARTUP (pwd_dir, src/xinit.c:3175)` | `the cwd captured at STARTUP (pwd_dir, Tcl_AppInit()'s getcwd() in xinit.c)` |
| `push_undo (save.c:6709) and pop_undo (save.c:6793)` | `push_undo() and pop_undo() (save.c)` — the names are already there; the numbers are pure rot surface |
| `only a setter at scheduler.c:12868` | `only a setter (scheduler.c's `xschem set no_undo` arm)` |
| `full_audit.sh's default arm (…, full_audit.sh:485)` | `full_audit.sh's default arm (the final `else` in its per-test dispatch)` — **especially** here: `:483` and `:485` are byte-identical commands, so a bare line number is ambiguous to a reader who lands one branch off |

The two that should **keep** a number even under the proposal: `save.c:6149-6152` and
`save.c:6165-6172` name *spans* of comment prose rather than a callable, so a name alone
under-specifies them — pair the name with the span.

## Left dirty

**11 files modified, comment-only, uncommitted**, listed in the table above.
`git diff --numstat` symmetric for all 11. Nothing staged. No new files except this receipt.

⚠ **The tree also carries another crew's in-flight work**, which is **not mine**:
`tests/headless/test_startup_guard_0663.tcl` (+85/−2, the SG22 block). Untracked
directories present at start and untouched by me: `.xschem/`, `doc/claude/rdw_lists_batch/`,
`doc/claude/rdw_sim_batch/`, `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/`.

## Owed to the user

**Nothing.** No unratified decision and no pixel deliverable — this pass changed only
comment text and asserts nothing new. I did not touch `owed.sh`.

Two items are owed to the **driver**, not the user: the rotted
`DECISIONS.md:281` / `F1` / `F2` / `F4` / `R2-R3-design.md` anchors into
`test_startup_guard_0663.tcl` (caused by the concurrent SG22 edit), and the ruling on
whether the half-fixed `load_backup_as` family and `0601`'s root-cause chain get their own
task.
