# One list of non-settings — the `Options…` editor refused every row that carried a name (issue 1450)

**One task, two halves.** `src/ase.tcl` + `src/ase_window.tcl` +
`tests/headless/test_ase_core.tcl` + `tests/headless/test_ase_dialogs.tcl` +
the 1450 issue file + `NUMBERING.md` + this receipt. **`test_ase_persist.tcl`,
`test_ase_meas_1443.tcl` and `run_regression.tcl` were NOT opened at all** and no
new suite file was created. No commit, no `git add`, no stash, no restore, no
clean, no push. T1 not run (issue 0990 — the driver's, solo). No simulation was
started on any bench.

**Floors: `test_ase_core` 624 → 626** (both arms) and **`test_ase_dialogs`
37 / 340 → 37 / 346**. Both files' own floor paragraphs and header indices are in
the same diff.

**The display arm of `test_ase_dialogs` is back to exactly ONE red — `G2sens`,
issue 1436, value `{1 1 0 1 0 Entry Entry normal}`, unmoved.** From its own
`RESULT:` line: `RESULT: 1 FAILED (345 passed)`.

`src/ase.tcl` +50/−4 and `src/ase_window.tcl` +23/−3; **eight added lines in the
two source files are not comment, and one of those is blank**:

```
$ git diff src/ase.tcl src/ase_window.tcl | grep '^+' | grep -v '^+++' | grep -v '^+ *#'
+proc ase::analysis_nonsetting_keys {} {
+  return {type enabled x id}
+}
+
+  set known [ase::analysis_nonsetting_keys]
+  set skip [concat [ase::analysis_nonsetting_keys] \
+                   [ase::ui::chana_fields $type $_sim]]
+  set skip [concat [ase::analysis_nonsetting_keys] \
+                   [ase::ui::chana_fields $type $_sim]]
```

---

## 1. THE REPRODUCTION, TAKEN BEFORE ANYTHING WAS CHANGED

`/tmp/nsk1450/repro.tcl` against the unfixed tree at `f3be5542`, run on the dev
display (`:99`, Xvfb + openbox) because the subject is a Tk subdialog and the
measurement is what the **widgets** do. The bench is one `dc` row carrying both
of `DECISIONS.md` D4's optional keys:

```
row : type dc enabled 0 source V2 start 0 stop 1.8 step 0.01 id vinsweep x {{echo hi}}
```

### A. the list, as each site computed it

```
skip, the OLD literal : type enabled source start stop step source2 start2 stop2 step2
anextra seeded from it: id vinsweep x {{echo hi}}
chana_x_ok would refuse: id x
```

### B. and what the real widgets then did

```
chana open           : 1
Options subdialog up : 1
the pairs it SHOWS   : {id vinsweep} {x {{echo hi}}}
after OK, still up   : 1
the stored row now   : type dc enabled 0 source V2 start 0 stop 1.8 step 0.01 id vinsweep x {{echo hi}}
what it SAID         : error : ase: this dc analysis has a setting named 'id' that ASE-L cannot emit
status line          : This dc analysis has a setting named 'id' that ASE-L cannot emit.
```

### C. each key alone reproduces it, and the same row with neither commits

```
ONLY-x   shows {x {{echo hi}}}   OK-closed=0  said: ... has a setting named 'x' that ASE-L cannot emit
ONLY-id  shows {id vinsweep}     OK-closed=0  said: ... has a setting named 'id' that ASE-L cannot emit
NEITHER  shows                   OK-closed=1
```

⚠ **Both keys reproduce, and `x` has been like this since issue 1419** — three
weeks, not a 1447 regression. The row is not damaged; the **editor cannot be
opened-and-saved on it at all**, and the one gesture that *did* get an OK out of
it was **deleting the name** (`chana_x_del` empties `anextra`, the refusal loop
then has nothing to iterate, and the strip below it removes the key).

The same script after the fix — sections B and C in full:

```
the pairs it SHOWS   :                      <- empty
after OK, still up   : 0
the stored row now   : ...id vinsweep x {{echo hi}}   <- both keys survive
what it SAID         :                      <- nothing

ONLY-x   shows   OK-closed=1  row-after=... x {{echo hi}}
ONLY-id  shows   OK-closed=1  row-after=... id vinsweep
NEITHER  shows   OK-closed=1
```

## 2. The one proc and its three callers, with anchors

| where | line | what it is |
|---|---|---|
| `src/ase.tcl` | **`:4518`** | **`proc ase::analysis_nonsetting_keys {}`** — `return {type enabled x id}`, under 33 lines of comment |
| `src/ase.tcl` | **`:4686`** | `ase::analysis_emit_check`: `set known [ase::analysis_nonsetting_keys]` (was `[list type enabled x id]`) |
| `src/ase_window.tcl` | **`:5835`** | `ase::ui::chana_options` (`:5804`), the **reader**: `set skip [concat [ase::analysis_nonsetting_keys] [ase::ui::chana_fields $type $_sim]]` (was `concat {type enabled} …`) |
| `src/ase_window.tcl` | **`:5992`** | `ase::ui::chana_x_ok` (`:5958`), the **writer**: the same line (was the same stale literal) |

It lives in `ase::`, not `ase::ui::`, because the schema owns what a row's keys
mean (**D34**–**D37**) — the window asks, it does not decide.

⚠ **The writer's half is the sharper one and the receipt says so because nothing
else does.** `chana_x_ok` strips the row before write-back:
`foreach k [dict keys $row] { if {[lsearch -exact $skip $k] < 0} { dict remove } }`.
With a `skip` that has never heard of `id`/`x` that loop **deletes both**. It was
latent only because the refusal fired first — "the commit door destroys the
handle" is one reordered `return` away. **NX6** is that sentence as a byte-identity
row.

⚠ **Nothing else was widened.** `chana_x_add`'s `Add` refusal still consults
`chana_fields` alone, so typing `id` or `x` into the NAME/VALUE pair is refused
exactly as before — **NX4** pins it, because otherwise *"hide them from the list"*
and *"let the list edit them"* are indistinguishable. `ase::analysis_emit_msg` is
untouched.

## 3. The fourth-copy guard — `test_ase_core` row NS2

A runtime row cannot see a fourth copy: a copy is correct on the day it is
written and wrong the day D4 gains a key, which is exactly how `Options…` spent
three weeks refusing every row carrying `x`. **NS2** (`test_ase_core.tcl:5590`)
scans `src/ase.tcl` and `src/ase_window.tcl` for a hardcoded list literal on any
line that is not wholly a comment and requires **exactly one** — the proc's own
`return`. Its last three terms are the controls: the scanner really does match a
copy-shaped line, and really does **not** match `dict create type $type enabled 0`
(a row being **built**, not a list being copied) or a commented one.

⚠ **A correction to the brief's phrasing, learned the expensive way.** The guard's
pattern must be written as a regexp and **never quoted in a comment**: a stray
open brace inside a Tcl comment unbalances the enclosing block. Measured — this
file died with `missing close-brace: possible unbalanced brace in comment` at
**line 434**, four thousand lines above the comment that did it, and printed no
`RESULT:` line. The paragraph above NS2 records it in place.

## 4. `GH13b` — what it asserted, and what it asserts now

| | |
|---|---|
| **before** | `{unknownkey id emit_incomplete {}}` — "KNOWN DEFECT (issue 1448)": the emit check refuses `id`, `ase::preflight_gate` refuses the whole bench, the identical bench without the key runs. Its header said *"When it lands this row goes red and names the paragraph that has to be rewritten."* |
| **now** | `{{} {} {} {dc V2 0 1.8 0.01} emit_incomplete vinsweep dc1}` — the emit check is clean, the gate is **silent**, the paired id-less bench is silent too, the row still renders its analysis card (a **literal golden**, so the term cannot pass on an extractor that returned nothing), a **third** state carrying `nonsense 1` is still refused, and the two fixtures **disagree about their own handle** |

⚠ **The paired control is kept and a third state was added, because the pair no
longer disagrees.** Under the defect `GH13G` and `GH13GN` answered differently and
that difference **was** the row; now both answer `{}`, so a gate that had stopped
running at all would satisfy both terms. `GH13BAD` is the non-vacuity control and
sabotage **s9** is its own witness. The paragraph above it, and the file's header
index entry, were rewritten in the same diff.

## 5. Both arms, before and after, from the `RESULT:` line

| suite / arm | before | after |
|---|---|---|
| `test_ase_core` headless | `ALL PASS (624 checks)` | `ALL PASS (626 checks)` |
| `test_ase_core` display (`:99`) | `ALL PASS (624 checks)` | `ALL PASS (626 checks)` |
| `test_ase_dialogs` headless | `ALL PASS (37 checks)` | `ALL PASS (37 checks)` |
| **`test_ase_dialogs` display** | **`2 FAILED (338 passed)`** | **`1 FAILED (345 passed)`** |
| `test_ase_persist` | — | `ALL PASS (49)` / `ALL PASS (153)` |
| `test_ase_meas_1443` | — | `ALL PASS (100)` / `ALL PASS (100)` |
| `test_ase_window` | — | `ALL PASS (56)` / `ALL PASS (295)` |
| `test_ase_preflight` | — | `ALL PASS (235)` / `ALL PASS (235)` |
| `test_ase_options_1437` | — | `ALL PASS (75)` / `ALL PASS (75)` |

Every baseline was **re-measured here** before any edit and matched the dispatch
exactly, including the red's actual value and the names of both reds. Each arm ran
under a hard `timeout` (400 s headless, 700 s display).

**The one remaining red on the display arm is `G2sens`** (issue **1436**, the
standing one), actual `{1 1 0 1 0 Entry Entry normal}` — the value that issue's
own file records, unmoved before and after. `GG9` passed on every run of both
arms, as receipt 28 and 29 both found.

Headless is unmoved at 37 because every NX row drives widgets; the schema half is
`test_ase_core` section NS, which runs on **both** arms.

## 6. The `.state` byte-identity measurement

```
$ git ls-files -- '*.state' | wc -l
104
$ timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/nsk1450/state_roundtrip.tcl
STATEFILES: 104
MISMATCH:   0
ANALYSIS-ROWS: 416
ANALYSIS-ROWS-WITH-id: 0
ANALYSIS-ROWS-WITH-x:  0
CONTROL-DISAGREES: 1
$ git status --porcelain -- '*.state'
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state
```

— untracked, pre-existing at hand-over, not mine. **Zero tracked `.state` files
modified.** `CONTROL-DISAGREES` is the non-vacuity leg: one `id` added to one
committed row must stop round-tripping, or the comparison measures nothing.

⚠ **A trap worth writing down**: `ase::state_serialize` does **not** emit the
file's trailing newline (`ase::state_save` adds it), so a naive
`$out ne $orig` reports **104 of 104 mismatched** — measured, and it is what my
first cut of that script said. The comparison is `"$out\n" ne $orig`, which is
what `test_ase_core`'s own **CP7** does.

**No new state key, no schema version bump, nothing added to
`ase::omit_if_empty`.** `id` and `x` already existed; two more readers were taught
about them and a third stopped spelling the answer itself.

## 7. Sabotage — nine mutations, generator `/tmp/nsk1450/sab.py`

Every arm: `python3 sab.py <id>` writes the mutant **from a pristine copy**, both
suites run (`test_ase_core` headless under `timeout 400`, `test_ase_dialogs`
display under `timeout 700`), then `sab.py restore` copies the pristine files
back and the runner md5s all four against the snapshot. **Every arm printed
`md5 OK` for all four files, and every arm printed a `RESULT:` line** — no
sabotage killed a suite file.

`G2sens` reds on every display arm below and is omitted from the red lists.

| # | what was broken | core `RESULT:` | dlg `RESULT:` | what reddened |
|---|---|---|---|---|
| **s1** | **site 1 reverted to its own stale copy** — `emit_check` back to `[list type enabled x]` | `4 FAILED (622)` | `2 FAILED (344)` | **EK7, EK7c, NS1, NS2** + **GH13b** |
| **s2** | **site 2 reverted** — the `Options…` **reader**'s own `concat {type enabled}` | `1 FAILED (625)` | `6 FAILED (340)` | **NS2** + **NX1, NX2, NX3, NX4, NX5** |
| **s3** | **site 3 reverted** — the `Options…` **writer**'s own copy | `1 FAILED (625)` | `4 FAILED (342)` | **NS2** + **NX2, NX4, NX6** |
| **s4** | the new proc returns the **empty list** | `23 FAILED (603)` | `34 FAILED (312)` | EK1 EK2 EK5 EK6 EK7 EK7c **NS1 NS2** VB4 VB5 GR1 GR2 GR3 GR6 GR9 GR10 GR7 TF3 PZ2e PZ3 SE3 CP3 MP11; and 34 dialog rows including **GH13, GH13b, NX1–NX5** |
| **s5** | the new proc returns **everything** the fixtures use (`… nonsense legacykey`) | `2 FAILED (624)` | `4 FAILED (342)` | **EK7c, NS1** + **GH13b, NX1, NX3** |
| **s6** | **a FOURTH copy appears in live code** — `concat {type enabled} …` inside `chana_x_fill` | `1 FAILED (625)` | `1 FAILED (345)` | **NS2, and nothing else on either arm** |
| **s7** | POSITIVE CONTROL — the NX pair extractor never returns anything | `ALL PASS (626)` | `3 FAILED (343)` | **NX1, NX5** |
| **s8** | POSITIVE CONTROL — NS2's source scanner never matches | `1 FAILED (625)` | `1 FAILED (345)` | **NS2** |
| **s9** | CONTROL — GH13b's third state stops carrying a key nothing can spend | `ALL PASS (626)` | `2 FAILED (344)` | **GH13b** |

**s1, s2 and s3 redden three DIFFERENT sets**, which is the evidence the brief
asked for: each site is separately load-bearing, and no one row is standing in for
all three. **s6 is the sharpest row in the table** — a fourth copy that *agrees
with the proc today* is invisible to every runtime row in the tree and reddens
NS2 alone.

### The four ways a row fails to fail, answered

1. **Fixtures that never disagree — and the old GH13b became one the moment 1449
   landed.** Its pair (`id-ful` vs `id-less`) had answered `emit_incomplete` vs
   `{}`; after the fix both answer `{}`. That is why the rewrite **adds a third
   state** rather than keeping two, and why its last two terms make the fixtures
   disagree about their own handle (`vinsweep` vs `dc1`). **s9** is that control's
   own sabotage. NX1 has the same shape from the other side: its second fixture
   carries a genuine stray, so "the list is empty" cannot pass it.
2. **Position asked where the mechanism is last-writer-wins.** Nothing here
   asserts an ordering. NX6 asks for **byte equality of the whole serialized
   state**, with the id-less serialization as its non-vacuity term.
3. **An extractor that returns nothing.** Two positive controls, both sabotaged:
   the NX pair extractor (**s7**, reds NX1 and NX5) and NS2's source scanner
   (**s8**). GH13b's card term is a literal golden (`dc V2 0 1.8 0.01`) for the
   same reason.
4. **A sabotage missing from the generator.** s7/s8/s9 sabotage the **controls**;
   s5 and s6 are the two ways this fix can be wrong in the *widening* direction
   and both are in the table.

⚠ **No arm produced the "raise inside a check kills the file, rc 0, no `RESULT:`
line" shape** that has killed a suite four times in this batch. Every one of the
eighteen suite runs above printed a `RESULT:` line; s7 and s9 printed
`ALL PASS (626)` on the core arm, which is a *result*, not a gap.

## 8. UI copy, and the ruling

**No new user-facing sentence was minted** — the diff's non-comment lines are the
proc, its `return`, and three call sites (§0). The user-visible change is a
sentence that **stops** being shown and two free-text pairs that stop being
listed. Nothing in `ase::analysis_emit_msg` or the `lbl_*` family moved.

**⚖ R9 is still filed, because hiding a key the user can see is theirs to ratify**
— `owed.sh add rule 1450` recorded (stamped `repo:/home/analog/dev/xschem-claude`,
`ref:` resolving to the issue file). The option set is in the issue file; the
measurement behind it is:

```
handle grid, Handle column     : vinsweep
Analyses > List                : vinsweep  DC  V2 0 1.8 0.01
handle grid, Arguments column  : V2 0 1.8 0.01              <- no hatch
main window Analyses pane      : dc V2 0 1.8 0.01  + verbatim: 1 line
```

⚠ **The two keys are not equally visible, and this is a finding rather than an
assumption.** `id` is on screen **twice inside the very dialog** whose button
opens the subdialog. `x` is mentioned only in the **main window's** Analyses pane:
the grid's Arguments column is `ase::analysis_line`'s answer (through
`ase::analysis_handle_fields`) and **not** `ase::ui::arg_summary`'s, so it never
carries the `+ verbatim` clause. The options are therefore **A** (say nothing new
— recommended and shipped), **A′** (give the handle grid the `+ verbatim` clause
the pane already has — no new sentence, since the clause is already ratified),
**B** (a read-only `HANDLE:` line), **C** (list them greyed) and **D** (A plus a
sharper `Add` refusal for exactly these two keys, since today's sentence gives the
wrong reason — *cannot emit* rather than *is not a setting* — though it is
unchanged from before this fix).

**A `look` debt is filed** — `owed.sh add look ase-options-subdialog-1450`. The
subdialog's list is **empty** where it used to hold two rows, on any bench
carrying either key, and OK now closes instead of refusing. **Suites green, please
look.** Nothing is claimed done on pixels.

⚠ **Ledger hygiene, measured.** A backup of `~/.claude/xschem_owed` was taken
**before** the first `add`. `/usr/bin/grep -L '^repo:'` over the backup and over
the live ledger both list the **same four** unstamped entries (`rule/1357`,
`rule/1357@xschem-claude`, `look/hier_pdf_nav_1357_H6.…`,
`suite/test_hier_pdf_links_1333`) — **pre-existing, not this task's**, and per
`CLAUDE.md` they are evidence that another clone's older `owed.sh` wrote over
something. Counts went `165 rule / 60 look / 10 suite` → `166 / 61 / 10`: two
entries added, none destroyed.

## 9. Testing discipline

**No simulator was started by anything in this task**, so the three-binary rule
(apt 45.2 **and** the fork) does not apply and I did not test twice: every new row
is pure Tcl, and nothing here emits, reads back or offers anything a simulator
sees. The deck the fix unblocks was measured byte-identical to an id-less bench's
by issue 1449 and is re-asserted by `EK7` (both arms) and by GH13b's card term.

**The binary was not rebuilt and did not need to be** — checked rather than
assumed: `find src -name '*.c' -newer src/xschem` and the same for `*.h` both
print **nothing**; only `.tcl` files are newer and those are read from
`XSCHEM_SHAREDIR` at run time.

**Display arm:** `:99` (Xvfb 1920x1080x24 + **openbox**, `devdisplay.sh status`
reports `wm: openbox (Openbox)`), reached through `tests/headless/devdisplay.sh
exec`. Every launch carried `--nolog`; **no `--logdir`**; nothing under
`~/.xschem/` was read, written or moved.

## 10. For the driver

1. **`test_ase_dialogs` display is back to exactly one red**, `G2sens` (issue
   1436). `RESULT: 1 FAILED (345 passed)`.
2. **T1's number moves and its baseline stays zero.** `run_regression.tcl` runs
   `test_ase_core` on **both** arms (624 → **626**, ALL PASS on each, measured
   directly) and `test_ase_dialogs` **headless only** (unmoved at 37, ALL PASS).
   T1 was **not** run by this crew (issue 0990).
3. **`NUMBERING.md`'s pointer advanced 1449 → 1451.** Both mint checks were re-run
   at the moment of minting, not taken from the dispatch: the reserved-band scan
   over this clone's head table (**silent** for 1450) and
   `ls ~/dev/*/doc/claude/issues/1450-*` plus `/usr/bin/grep -lw 1450` across every
   clone's `NUMBERING.md` (only this clone's own pointer line, and the glob was
   proved non-empty first).
4. **Two ledger debts are open and neither clears on a green suite:** `rule 1450`
   (⚖ R9 — should `Options…` say anything about a row's name or its hatch?) and
   `look ase-options-subdialog-1450`.
5. **HEAD did not move under this task.** Handed over at `f3be5542`; still there.
   Working tree: **five modified** (`src/ase.tcl`, `src/ase_window.tcl`,
   `tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_dialogs.tcl`,
   `doc/claude/issues/NUMBERING.md`) and **two new**
   (`doc/claude/issues/1450-the-options-editor-refused-every-row-that-carried-a-name.md`,
   this receipt). The four untracked paths inherited at hand-over are untouched.
6. **Issue 1449's "What is still owed" is now discharged** — both sites named
   there (`ase_window.tcl:5824` / `:5973`, now `:5835` / `:5992`) are fixed, and
   1444's editable `id` field has no remaining blocker.

## 11. Corrections to the brief

* **The brief's table is right about the three lists and slightly off on one
  detail**: `chana_x_ok`'s copy is not only a *reader* of the row's keys, it is
  the **strip list** for the write-back, so the stale copy would have **deleted**
  `id` and `x` rather than merely mis-seeding them. Latent behind the refusal,
  but it is why NX6 exists.
* **"A new user-facing sentence is ⚖ R9's — file `owed.sh add rule 1450`"**: no
  new sentence was minted, and the rule debt is filed anyway, for the *decision*
  the brief itself raised (whether the user should be told their row carries an
  `id`). §8 lists the option set; nothing is quoted verbatim as new copy because
  there is none.
* **A trap the brief could not know**: `ase::state_serialize` omits the trailing
  newline, so the byte-identity comparison is `"$out\n" ne $orig` (§6). And a
  brace quoted inside a Tcl **comment** unbalances the enclosing block — that one
  cost a run and printed no `RESULT:` line (§3).

## 12. Commands, for the driver to re-run

```sh
cd /home/analog/dev/xschem-claude
timeout 300 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script /tmp/nsk1450/repro.tcl
timeout 400 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl
timeout 700 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_core.tcl
timeout 400 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 700 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
timeout 300 ./src/xschem --nogui --pipe -q --nolog --script /tmp/nsk1450/state_roundtrip.tcl
timeout 200 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script /tmp/nsk1450/surfaces.tcl
/tmp/nsk1450/runsab.sh s1 s2 s3 s4 s5 s6 s7 s8 s9
```
