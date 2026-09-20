# Receipt — item B (issue 1483), FIX ROUND: the two adversarial reviews and what happened

Two verifiers (`reproduce`, `completeness`) returned **14 findings** against the implement
round: **1 blocker, 1 must, 5 should, 7 nit**. Every one was re-measured here before it
was acted on, and **not one turned out to be wrong**.

**Three edits close five findings; two more are recorded as corrections with no code
change; seven are real, outside issue 1483, and written down in §4 for the driver to
file rather than fixed on the way past** (PLAN.md criterion 4).

The blocker and the must are the same defect, found independently: the implement round's
new row in `tests/headless/test_callback_argc.tcl` turned a suite that has been green in
**62** recorded audit artefacts red on the arm `run_suites.sh` and `full_audit.sh`
actually use.

Fixer, 2026-09-20. Tree at start: `2fb377de` + the implement round's two uncommitted
files (`src/scheduler.c`, `tests/headless/test_callback_argc.tcl`).

## 0. Conditions

| name | what it is |
|---|---|
| **clone** | `git clone --no-hardlinks` of the developer tree at `2fb377de`, the implement round's two-file diff applied on top, `./configure` rc 0, `timeout 900 make -C src -j8` rc 0 |
| **:163** | my own `Xvfb :163 -screen 0 1920x1080x24 -nolisten tcp`, started and stopped by me |
| **HOME** | a fresh scratch directory per run, never the developer's |

⚠ **The clone is at `/tmp/vb83/w` — a 12-character root — not in the assigned
`…/scratchpad/stranger_reds/b`, which is 111 characters.** That is not a preference: the
implement receipt's §6.1 and BOTH verifiers measured that `test_op_annot` cannot pass in a
clone whose root is longer than ~73 characters, and `test_op_annot` is one of the four
suites this item is about. I re-measured it (§4.8). A crew that runs item B's own gate
inside the root the harness hands out sees reds that have nothing to do with item B.

`~/.claude/xschem_dev_display` exists on this box, so every run here set `HOME` to a
scratch directory and `GUI_GATE=0`: T1's dev-display auto-start is conditional on that
state directory being found under `$HOME`, so it could not fire and **`:99` was never
touched**. The user's gate control dir was likewise never written after the first
`run_suites.sh` run, which enrolled with it and proceeded on its own (it fails open).

---

## 1. The blocker, re-measured before it was touched

**`reproduce` #1 (must) and `completeness` #1 (blocker) are the same defect.** The
implement round added this row to `tests/headless/test_callback_argc.tcl`:

```tcl
check "1483 neither X field fabricates a number when there is no display" \
  [list [string is integer -strict $x1483_max] [string is integer -strict $x1483_ext]] {0 0}
```

It asserts **unconditionally** that neither X field is an integer. That is true only when
`has_x == 0`. The row's own comment reasons from `run_regression.tcl` hard-coding
`--nogui` — true of T1, and exactly the step that forgets the other two drivers.
`test_callback_argc` is **not** in `full_audit.sh`'s `nogui_tests` list (measured: the
list is one line at `full_audit.sh:171` and the name is absent), so `full_audit.sh` runs
it on its default arm, and `run_suites.sh <t>` — the spelling CLAUDE.md documents as the
trustworthy signal — does the same. There `has_x == 1`, the product correctly reports the
real figures, and the row fails.

**Measured in my clone, implement-round code, one binary, three arms:**

| arm | command | result |
|---|---|---|
| GUI (`run_suites.sh` / `full_audit.sh` arm) | `HOME=… DISPLAY=:163 ./src/xschem --pipe -q --nolog --script …` | `FAIL: 1483 neither X field fabricates a number when there is no display -> {1 1} (exp {0 0})` · `RESULT: 1 FAILED (7 passed)` · rc 1 |
| `--nogui`, DISPLAY set | `HOME=… DISPLAY=:163 ./src/xschem --nogui …` | `RESULT: ALL PASS (8 checks)` rc 0 |
| `--nogui`, DISPLAY unset | `env -u DISPLAY HOME=… ./src/xschem --nogui …` | `RESULT: ALL PASS (8 checks)` rc 0 |

**Control, same binary, the pre-change file from `2fb377de`** (`git stash push` on the one
file, run, `git stash pop`): GUI arm `RESULT: ALL PASS (5 checks)` rc 0. So a green suite
was turned red by the change on the arm a developer actually types — PLAN.md acceptance
criterion 2.

Worse, and this is why it is a blocker rather than a should: **the false red is
word-for-word the true one.** `-> {1 1} (exp {0 0})` is also what the row prints when the
unfixed binary really does fabricate a number under `--nogui`. A reader meeting it on
their desktop cannot tell a correct product from a broken one.

### 1.1 The premise of the fix, measured rather than assumed

Both verifiers proposed the same mechanism: branch on `::has_x`. I checked it is a
faithful mirror before using it. `src/xinit.c` contains **exactly one** write:

```c
3192- if(has_x) {
3193-   XSetErrorHandler(err);
3194-   Tk_Init(interp);
3195:   tclsetvar("has_x","1");
3196- }
```

so `[info exists ::has_x]` is `has_x == 1` and nothing else. Measured with a probe script
on the same three arms:

| arm | `[info exists ::has_x]` | `xschem globals` X fields |
|---|---|---|
| GUI, `DISPLAY=:163` | **1** | `XMaxRequestSize=65535` · `XExtendedMaxRequestSize=4194303` |
| `--nogui`, `DISPLAY=:163` | **0** | `<no X server connection>` ×2 |
| `--nogui`, DISPLAY unset | **0** | `<no X server connection>` ×2 |

It is also the idiom the tree already uses for this exact purpose — `src/ase.tcl:16403`,
`:19987`, `:20284`, `:20293`, `:20314`, `src/ase_window.tcl:4428`.

### 1.2 What I applied

One row became two branches, so the check count stays **8 on every arm** and the negative
branch's assertion is byte-identical to the row it replaces:

```tcl
if {[info exists ::has_x] && $x1483_unix} {
  check "1483 both X fields carry a real number when a display exists" \
    [list [string is integer -strict $x1483_max] [string is integer -strict $x1483_ext]] {1 1}
} else {
  check "1483 neither X field fabricates a number when there is no display" \
    [list [string is integer -strict $x1483_max] [string is integer -strict $x1483_ext]] {0 0}
}
```

This **gains** detection power rather than trading it away: nothing else in the tree
asserts that the X path still produces real numbers, so a future guard that
short-circuited it would now redden the positive branch. Sabotage **S4** (§5) proves that
row can fail.

I also rewrote the block comment. The old one stated the `--nogui` premise as if it
covered every driver, which is the reasoning that produced the defect; the new one says
plainly that the file runs on three arms, names the two drivers that do not pass
`--nogui`, and records the measured `-> {1 1} (exp {0 0})` red so the next reader does not
re-derive it.

### 1.3 The Windows nit, folded into the same edit

`completeness` #6 (nit) points out that the whole `******* Xserver options: *******`
block, header and both keys, is inside `#ifdef __unix__` (`scheduler.c`), so on a Windows
build the keys do not exist and the row "both Xserver keys are still reported" would fail
although the product is correct. I was rewriting those lines anyway, so the expectation
now tracks the platform instead of asserting a unix truth everywhere:

```tcl
set x1483_unix [expr {$::tcl_platform(platform) eq "unix"}]
check "1483 both Xserver keys are reported wherever the block is compiled" \
  [list [expr {$x1483_max ne {}}] [expr {$x1483_ext ne {}}]] [list $x1483_unix $x1483_unix]
```

and the value row's positive branch requires `$x1483_unix` too, so a Windows build takes
the negative branch on empty strings rather than passing vacuously. **On unix this is
byte-for-byte the same assertion as before** (`platform` measured `unix` on all three
arms; expectation `{1 1}`), so it costs no detection power here. **The non-unix behaviour
is READ from the source, not measured** — I did not build for Windows.

---

## 2. The one other edit: `no_x_display` moved inside `#ifdef __unix__`

**`reproduce` #2 (nit) and `completeness` #5 (nit), the same point.** The implement round
declared

```c
static char *no_x_display = "<no X server connection>";
```

at file scope beside `not_avail`, while both its uses are inside the `#ifdef __unix__` of
`xschem globals`. On a non-unix build that is a file-scope static nothing references.
Measured, the warning shape: `gcc -c -std=c89 -pedantic -Wall` on a two-line file with
that exact declaration prints

```
u.c:1:14: warning: ‘no_x_display’ defined but not used [-Wunused-variable]
```

The implementer flagged it deliberately and declined to change it **after** its proof
runs, on the correct rule that a measurement belongs to the bytes that produced it. That
rule is what makes this cheap for me and not for them: **this round re-runs the four
suites and both T1s anyway**, so the rebuild costs nothing and every number below belongs
to the bytes now in the tree. Applied:

```c
#ifdef __unix__
/* …comment… */
static char *no_x_display = "<no X server connection>";
#endif
```

Verified it is the whole story: `/usr/bin/grep -rn no_x_display src/` returns exactly
three lines — the declaration and the two uses at `scheduler.c:6124` / `:6126`, both
inside the `#ifdef __unix__` that begins at `:6104`. The in-tree build is unchanged:
`make -C src` rc 0, **no `scheduler.c` warning of any kind** in the log. No behavioural
change on unix, and §3 re-measures everything against the rebuilt binary.

C89: the edit moves a declaration between preprocessor guards; no declaration after a
statement, no `//`, nothing else touched.

---

## 3. Green on every arm

All runs: my clone, rebuilt after the §2 edit, `src/xschem` md5 `7b0e3ec568938c40ed67730c752d9bf4`.

### 3.1 `test_callback_argc` on every arm, and through both drivers

| arm / driver | before this round | after |
|---|---|---|
| bare, GUI (`--pipe -q --nolog`, `DISPLAY=:163`) | `1 FAILED (7 passed)` | **`ALL PASS (8 checks)`** |
| bare, `--nogui`, `DISPLAY=:163` | `ALL PASS (8 checks)` | **`ALL PASS (8 checks)`** |
| bare, `--nogui`, DISPLAY unset | `ALL PASS (8 checks)` | **`ALL PASS (8 checks)`** |
| `run_suites.sh test_callback_argc` (`AUDIT_DISPLAY=:163`) | `FAIL \| … 1 FAILED (7 passed)` (verifiers' measurement) | **`PASS     \| test_callback_argc           run 1/1  RESULT: ALL PASS (8 checks)`** · `RESULT: 1/1 runs passed` |
| `full_audit.sh test_callback_argc` (`AUDIT_DISPLAY=:163`) | `SUMMARY: 0 pass 1 fail` (verifiers' measurement) | **`PASS     \| test_callback_argc`** · `SUMMARY: 1 pass  0 fail  0 crash/timeout  0 skip  (total 1)` |

The count is **8 on every arm**, so no arm is passing by asserting less.

### 3.2 The four suites of issue 1483, `DISPLAY` unset

`env -u DISPLAY HOME=<scratch> timeout 900 ../src/xschem --nogui --pipe -q --nolog --script headless/<t>.tcl`,
one scratch HOME each, all four in parallel:

| suite | rc | result | 1483's table |
|---|---|---|---|
| `test_unused_attr_0970` | 0 | `RESULT: ALL PASS (67 checks)` | was `FATAL: signal 11` after `UF28` |
| `test_auto_specialize_1201` | 0 | `RESULT: ALL PASS (85 checks)` | was `FATAL: signal 11` after `AS65` |
| `test_ase_optier_0963` | 0 | `RESULT: ALL PASS (109 checks)` | was `FATAL: signal 11` after `S13` |
| `test_op_annot` | 0 | `RESULT: ALL PASS (485 checks)` | was `FATAL: signal 11` after `W30a` |

Check counts identical to the implement round's and to the stage-F gate's DISPLAY-set
column in the issue.

**Re-measured after the sabotage sequence, on the rebuilt binary** (§5's note on why the
binary's md5 moves although the source does not): `test_unused_attr_0970` **67**,
`test_auto_specialize_1201` **85**, `test_op_annot` **485**, all rc 0;
`test_ase_optier_0963` hit the ngspice flake of §5.1 on that pass and is treated there.

---

## 4. Every finding, and what happened to it

14 findings: **1 blocker, 1 must, 5 should, 7 nit.** Three edits close five of them; two
are recorded as corrections with no code change; **seven are real and outside issue 1483,
so they are written down here for the driver to file, not fixed on the way past**
(PLAN.md criterion 4). None was rejected as wrong: every one I could re-measure,
re-measured true.

| # | from | sev | where | disposition |
|---|---|---|---|---|
| 1 | completeness | **blocker** | `test_callback_argc.tcl` row asserts `{0 0}` unconditionally | **APPLIED** §1 |
| 2 | reproduce | **must** | same defect, found independently | **APPLIED** §1 (one edit closes both) |
| 3 | reproduce | nit | `no_x_display` outside `#ifdef __unix__` | **APPLIED** §2 |
| 4 | completeness | nit | same | **APPLIED** §2 |
| 5 | completeness | nit | the two key rows are unix-only assertions | **APPLIED** §1.3 |
| 6 | reproduce | nit | the `X…(display` survey pattern is too narrow; the per-file counts do not reproduce | **CORRECTION RECORDED**, §4.1 — no code change |
| 7 | completeness | nit | the comment cites `gc_line_style`'s `-1` and then implements prose | **NO CHANGE**, §4.2 — the verifier's own conclusion, and I agree |
| 8 | completeness | should | `callback.c:9891` — four suites crash headless, two of them named in no issue | **OUT OF SCOPE — file it**, §4.3 |
| 9 | reproduce | nit | same site, plus the display-dies-mid-run Xlib IO death | **OUT OF SCOPE — file it**, §4.3 |
| 10 | completeness | should | four `xschem` verbs kill the process headless | **OUT OF SCOPE — file it**, §4.4 |
| 11 | completeness | should | `display = NULL;` after `XCloseDisplay()` in `xserver_ok()` | **OUT OF SCOPE — file it**, §4.5 |
| 12 | completeness | should | `run_suites.sh` NORESULT arm discards the crash text | **OUT OF SCOPE — file it**, §4.6 |
| 13 | reproduce | nit | long clone paths red `test_op_annot`; the batch's own scratch root is 111 chars | **OUT OF SCOPE — file it**, §4.7 |
| 14 | completeness | should | same, wider: `test_annot_hier_0911` too, and a T1 in the assigned root counts 11 | **OUT OF SCOPE — file it**, §4.7 |

### 4.1 The survey method (finding 6) — confirmed, and the digits should not be carried forward

The implement receipt's §5 surveyed the remaining Xlib call sites by the textual pattern
`X…(display`. Confirmed: that pattern cannot see a `display` dereference whose callee does
not start with a capital X, and there are **8** such in the tree — line numbers as my
clone carries them, i.e. with this round's `scheduler.c` edits already in place:

```
draw.c:148, draw.c:268, draw.c:10127, psprint.c:333, scheduler.c:8818,
xinit.c:2821, xinit.c:2845          cairo_xlib_surface_create(display, …)
xinit.c:3761                        XGetXCBConnection(display)
```

The **answer** for `scheduler.c` is unaffected, which I checked by hand rather than
assuming: the one in `xschem net_hilight_dump_pixmap` is inside
`if(has_x && xctx->save_pixmap)`, so the receipt's claim that `xschem globals` held the
only unguarded sites in that file survives the widened pattern.

The per-file **counts** do not reproduce and should not be quoted forward by anyone. Three
passes, three answers for the same files: the receipt has 152 `draw.c` / 69 `xinit.c` /
13 `callback.c`; the verifier measured 172 / 70 / 7; I measure **182 / 70 / 13** today
(`/usr/bin/grep -rEc 'X[A-Za-z_]+ *\( *display'`). I did not edit the implementer's §5 —
rewriting their record would falsify it — the correction is appended to `B-impl.md`
instead. **Recommendation to the driver: drop the per-file counts rather than carry two
conflicting sets.** The conclusion they support ("`scheduler.c` had the only unguarded
Tcl-reachable sites") is independently checked above and stands.

### 4.2 The prose sentinel vs `-1` (finding 7) — no change

The verifier records it as a judgement, not a defect, and closes it itself. I agree and
changed nothing. The reasoning worth keeping: `xschem globals` is a human-readable dump,
so `-1` there would read as a value, whereas `xschem get gc_line_style` returns a single
machine-read token where `-1` is unambiguous. The new test row pins "not an integer" as
the contract, which is the same statement in the test's vocabulary.

### 4.3 `update_statusbar()` → `XGetKeyboardControl(display)` — the 0227 class, still live

**Confirmed here on the fixed binary.** `XGetKeyboardControl(display, &kbdstate);` sits in
`update_statusbar()` (`src/callback.c:9891` **at `2fb377de`** — cited with a revision
because 0227's own `:8721` has already rotted; the function name has not moved), and
`callback()` calls `update_statusbar()` unconditionally (`:10093` at the same revision),
with no `has_x` guard anywhere between. `env -u DISPLAY HOME=<scratch> ./src/xschem --nogui --pipe -q --nolog --script headless/<t>.tcl`,
my build, fixed tree:

| suite | rc | verdict | is it a T1 case? |
|---|---|---|---|
| `test_keybind_snap_grid` | 1 | `FATAL: signal 11` | **no** (`grep -c '"headless/…"' run_regression.tcl` = 0) |
| `test_undo_selection` | 1 | `FATAL: signal 11` | **no** |
| `test_hilight_case_senders` | 1 | `FATAL: signal 11` | **no** |
| `test_window_switch_bogus_enter` | 1 | `FATAL: signal 11` | **no** |

The last two appear in no issue file. **None of the four is a T1 case, which is exactly
why this class has never been counted** — and it is why item B's guard could not have
reached them: a different verb, a different function, a different Xlib call.

**Why I did not fix it**, beyond criterion 4: 0227 itself warns that guarding this call
*"clears the FIRST headless landmine in `callback()`; the rest of that function is unproven
headless and later checks may expose more."* Four suites that nothing counts would start
running further than they ever have, inside a batch capped at one fix round. That is a
new item, not a drive-by.

**For the driver to file:** attach `test_hilight_case_senders` and
`test_window_switch_bogus_enter` to **0227** as additional witnesses; close **0467** as a
duplicate of 0227 (the implement round's §1.4 diagnosis, which the `reproduce` verifier
independently confirmed — 20 `ok:` rows then the crash, mid-suite, not at teardown); and
take 0227 as its own item with `test_undo_selection` as the red-first fixture. The fix is
the idiom this item just applied: `if(has_x) update_statusbar(…);`.

Finding 9 adds one thing worth carrying into that item and **not** treating as the same
bug: a display that **dies mid-run** leaves `xschem globals` returning the cached 65535
(no round trip) and the process then exits rc 1 through Xlib's own
`XIO: fatal IO error 25` handler — no FAIL row, the same silent-death shape as 1483, a
different cause, and **not one a `has_x` guard can reach.** I did not re-measure that
(killing an X server mid-suite); it is the verifier's measurement, recorded as theirs.

### 4.4 Four `xschem` verbs kill the process headless (finding 10)

**Confirmed, my build, fixed binary**, one process each,
`printf 'catch {xschem <verb>} r\nputs SURVIVED\n'`, `env -u DISPLAY … --nogui --pipe -q --nolog`:

| verb | rc | output |
|---|---|---|
| `xschem fill_reset` | 1 | `FATAL: signal 11` — `SURVIVED` never printed |
| `xschem fullscreen` | 1 | `FATAL: signal 11` |
| `xschem copy_hilights` | 1 | `FATAL: signal 11` |
| `xschem compare_schematics` | **139** | died before the handler could print anything |

`catch` cannot catch a SIGSEGV, so a script that guards itself correctly still dies. The
verifier's backtraces put them at `free_gc()`→`XFreeGC()`, `toggle_fullscreen()`→
`XQueryTree()`, `create_gc()`→`XCreateBitmapFromData()` and inside `copy_hilights()`; they
measured the same four crashing on the **base** binary and with `DISPLAY` set under
`--nogui`, so this is pre-existing and reachable on a developer desktop, not something
this round introduced. No suite exercises these verbs headless, so nothing counts them.

**This is the honest limit of item B's shape**: guarding at the call site is right for
`xschem globals` and does not close the class. **For the driver to file:** one issue
naming the four verbs and their branches, with the repro above; **0834** already asks for
exactly this contract (a Tcl-reachable subcommand must error, never crash) and is the
natural parent.

### 4.5 `display = NULL;` after `XCloseDisplay()` in `xserver_ok()` (finding 11)

Read and agreed, not applied. `src/draw.c`, `xserver_ok()` opens a probe connection,
closes it, and leaves the global pointing at the freed `Display`. That is why the
`--nogui`-with-`DISPLAY` arm read a fabricated `XMaxRequestSize=4` instead of faulting,
and the verifier measured a sharper consequence — `test_undo_selection` on that arm dying
inside libxcb with `Assertion !xcb_xlib_extra_reply_data_left failed` rather than
segfaulting, i.e. the freed connection driven far enough to corrupt libxcb's state.

**It is the single highest-value follow-up in this area** and it is still not item B's:
it changes behaviour at an unknown number of the `display` dereferences across `src/`
(deliberately not a count — see §4.1),
and its value is precisely that it would make a DISPLAY-set arm fail wherever a headless
one does — which means landing it without its own sweep would convert a quiet class into
a loud one inside a batch that caps itself at one fix round. **For the driver:** land it
with the 0227 item, with a sweep, not here.

### 4.6 `run_suites.sh` reports a segfault as an exit code and throws the text away (finding 12)

**Confirmed by measurement**, fixed binary, a suite that crashes headless:

```
$ GUI_GATE=0 AUDIT_DISPLAY=none ./run_suites.sh --nogui test_undo_selection
display arm: none (DISPLAY unset; GUI legs will self-skip)
NORESULT | test_undo_selection          run 1/1 (exit 1 — binary never reported)
RESULT: 0/1 runs passed
```

and nothing else — while the same binary run bare prints `EMERGENCY SAVE DIR: …` and
`FATAL: signal 11`. The FAIL arm immediately below (`run_suites.sh`, the
`printf '%s\n' "$out" | grep -E '^(FAIL|FATAL)'` line) echoes exactly those lines under
its verdict; the NORESULT arm has no such line. So **the one command this project
documents for running a suite hides the crash text of a crash.** The `completeness`
verifier reports this cost them directly: a sweep of all 405 suites through the documented
driver found `FATAL: signal` in zero output files, and the four real crashes in §4.3
surfaced only on re-running the non-passers bare.

It is a harness-honesty defect of the same family as issue **1487**, it is not issue 1483,
and it is in a file this item does not otherwise touch. **For the driver to file.** The
fix mirrors the FAIL arm one line up, and the `FATAL: signal` literal is already
`full_audit.sh`'s CRASH discriminator, so the vocabulary exists.

### 4.7 A long checkout path reds `test_op_annot` — and the batch's own scratch root is one (findings 13, 14)

Item C's shape with **length** as the trigger instead of case. The goldens embed an
absolute path in an expected status sentence (`test_op_annot.tcl:4151`, `:4479`,
`:12645`), `xctx->statusmsg_text` is `char[256]`, and `cadence::_annot_fit`
(`utils/annot_mode.tcl:724`) cuts any status line over 255 bytes back to the last space
before byte 252 — so the sentence survives only while the clone root stays under ~73
characters.

Measured three times independently before me (the implementer, and both verifiers, one of
them on the **unfixed** binary with `DISPLAY` **set**, which is what proves it predates
item B and has nothing to do with `DISPLAY`). My own clone root is 12 characters and
`test_op_annot` reports `ALL PASS (485 checks)`; §4.8 records what the same binary does
at 113.

The `completeness` verifier's correction is the operationally important half and it is
**wider than the implement receipt says**: a T1 run inside the assigned scratch root
closes `counted_failures=11`, and all eleven lines are this defect — `test_op_annot` rows
N6/N9/V31b on both arms plus its two `HARNESS` lines, **and `test_annot_hier_0911` rows
H6/H13 plus its HARNESS line**, a suite the implement receipt does not name. I confirmed
`test_annot_hier_0911` carries the same golden shape (its H6 and H13 rows assert a
sentence naming a results-file path).

**For the driver to file**, and two things to do with it beyond filing:

1. the test-side fix is to assert `[file tail $path]`, or to compare against
   `cadence::_annot_fit`'s own output, rather than the raw absolute path;
2. **tell crews in `CREW_BRIEF.md` to work in a short path.** The scratch root this batch
   hands out is 111 characters, so item B's own gate cannot be run where item B's crew is
   told to work, and a crew that runs it there and reports 11 failures has found nothing.

### 4.8 My own long-path measurement (findings 13, 14)

Fourth independent reproduction, and the first on the **fixed** binary. The same tree and
the **same binary** (md5 `7b0e3ec568938c40ed67730c752d9bf4`) that reports
`ALL PASS (485 checks)` at a 12-character clone root, copied to the assigned scratch root
(`…/scratchpad/stranger_reds/b/w`, **113 characters**) and run `env -u DISPLAY --nogui`:

```
RESULT: 3 FAILED (482 passed)
OVERALL: notok
```

rows **N6**, **N9**, **V31b** — and the `got` side shows the cut in the act:

```
got: … There is no results file at...
exp: … There is no results file at /tmp/claude-1000/…/stranger_reds/b/w/tests/headless/
     .scratch/_op_annot_488706/n_nd_empty/n_dev.raw yet. Run a simulation first.
```

One binary, two paths, two verdicts. Nothing to do with `DISPLAY`, nothing to do with
item B, and **it is why every measurement in this receipt was taken from a
12-character root**.

---

## 5. Sabotage — every row I touched, proved able to fail

Every sabotage is a rebuild, not a comment-out. `src/scheduler.c` md5 before the first
sabotage and after the last restore: `4547befbe5464ca11f0ba1af542d611f`, identical, and
`git stash list` empty at the end.

| # | what was reverted / broken | condition | result |
|---|---|---|---|
| S1 | the `has_x` guard, `src/scheduler.c` reverted to `2fb377de` (`git stash push`, rebuild) | `test_unused_attr_0970`, DISPLAY unset | `FATAL: signal 11`, rc 1, last row `ok: UF28 …` — **1483's own table, row for row** |
| S1b | same | `test_auto_specialize_1201`, DISPLAY unset | `FATAL: signal 11`, rc 1, last row `ok: AS65 …` |
| S2 | same | `test_callback_argc`, `--nogui`, `DISPLAY=:163` | `FAIL: 1483 neither X field fabricates a number when there is no display -> {1 1} (exp {0 0})` · `RESULT: 1 FAILED (7 passed)` — **the negative branch still reds on a DISPLAY-set box**, which is what makes this class visible without a headless one |
| S3 | same | `test_callback_argc`, `--nogui`, DISPLAY unset | `FATAL: signal 11`, rc 1 — no banner, so T1 counts the case |
| **C** | same (control, not a sabotage) | `test_callback_argc`, **GUI arm**, `DISPLAY=:163` | `RESULT: ALL PASS (8 checks)` — **the new branch does not false-red on the base binary where the product is correct.** This row is the fix: it is exactly what failed before this round. |
| S4 | `if(has_x) {` → `if(0) {` in the 1483 block only, rebuild — the X path short-circuited with `has_x == 1` | `test_callback_argc`, **GUI arm**, `DISPLAY=:163` | `FAIL: 1483 both X fields carry a real number when a display exists -> {0 0} (exp {1 1})` · `RESULT: 1 FAILED (7 passed)` — **the row this round ADDS has teeth** |

**Bytes restored and verified**: `src/scheduler.c` md5 `4547befbe5464ca11f0ba1af542d611f`
before the first sabotage and after the last restore, `diff` against the copy kept outside
the tree **identical**, `git stash list` **empty**, `git status --short` exactly the two
files of §7.

⚠ **Do not use the binary's md5 as an identity here.** `src/scheduler.c` contains
`__DATE__`/`__TIME__`, so two builds of identical source differ: the pre-sabotage binary
is `7b0e3ec568938c40ed67730c752d9bf4` and the restored one
`99be0a3f0474a0775fdf8f6f583e5098` **from the same bytes**. Everything after the restore
was re-measured on the restored binary rather than assumed — the three arms
(`ALL PASS (8 checks)` each) and all four suites.

### 5.1 One red seen along the way, diagnosed by case, not by count

The post-restore re-measurement ran the four suites **in parallel**, and
`test_ase_optier_0963` came back `RESULT: 1 FAILED (108 passed)` at row **X7**:

```
MEASURE X7 diag| tran simulation(s) aborted
MEASURE X7 diag| RUN-FAILED
MEASURE X7 diag| === exit 1 after 10.55 s ===
FAIL: X7 … -> {0 0 0} (exp {1 1 1}) : FAIL
```

**An ngspice run failed, not a `display` dereference.** It is the family CLAUDE.md already
names for this suite ("`X1`/`X2` — ngspice `rc=1`, `raw=-1bytes`, `NORAW`"), at a
different row, with four suites and their simulators running at once. The same suite, same
source, gave `ALL PASS (109 checks)` on the pre-sabotage build headless, and T1 with
DISPLAY unset closed `counted_failures=0` with this case in it.

CLAUDE.md's prescribed response to this suite is a standalone re-run. Done, `env -u
DISPLAY --nogui`, **nothing else running on the box**, same binary:

```
MEASURE X7 lvt-vector=v(@m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt[vth]) value=0.42337351 / standard-vector=v(@m.x1.x3.xm2.msky130_fd_pr__pfet_01v8[vth]) value=0.85791326
RESULT: ALL PASS (109 checks)
```

so the ngspice leg that failed under four-way parallelism succeeds on its own, and T1
with `DISPLAY` set scored this case `Total num fail: 0` in the same session. **Three
greens and one red for one case, the red under load, in the ngspice leg** — a flake in a
suite CLAUDE.md already names as flaky, not a regression and not something a `has_x`
guard touches. Diagnosed by case, as the rule requires; not filed again, because it
already is.

---

## 6. Both T1s

Both taken in my clone, solo (`another regression run is live` appears **0** times in
each run's own output — the harness's own liveness statement, not a `pgrep`), `HOME`
pointed at a scratch directory so T1 could not find `~/.claude/xschem_dev_display` and
could not touch `:99`.

### 6.1 `DISPLAY` unset — the condition issue 1483 is about

```
T1-RUN-BEGIN pid=426160 script=run_regression.tcl start=2026-09-20 16:19:51 planned_cases=87 verdict=results.426160.log home=throwaway binary=/tmp/vb83/w/src/xschem canonical=results.log
T1-RUN-END pid=426160 cases=87 blocks=86 counted_failures=0 elapsed=523s end=2026-09-20 16:28:34
```

`Start` **87**, `Finish` **87**, peers **0**, `wc -l` **177**, counted failures by the four
counted shapes, re-counted by hand off the file: **0**.
Display arm: `PRIVATE Xvfb :100 for this run only (pid 485188, wm openbox)`.
Test home: `throwaway /tmp/xschem-test-home.426160.P9HVpl (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)`.

`Start`/`Finish` pair at 87/87 rather than 87/76 because `DISPLAY` was unset for the
**suites** while D8's private-Xvfb arm still ran the 11 `dcases` — `cases=` from the
trailer is the authority either way (issue 1481).

**Green is per case; coverage is not in the verdict** (issue 1487). The case logs carry
**8 `skip:` lines** that neither verdict does, and they are the same set on both arms
because every headless case runs `--nogui`, where `has_x` is 0 whatever `DISPLAY` says.
Five are honest no-display skips (`M1/M2`, `O14/O36/O38`, `W23`, `W29`, `V53` — rows whose
subject is `if(has_x)` code). Three are `EE/fork`, `SE/fork` and `SE3/fork` in
`test_ase_converge_1459` and `test_ase_sp_1452`, which looked for the fork ngspice under
**my scratch HOME** and did not find it. None is in a suite this item touches, and none is
a pass in disguise — each names what it did not run.

### 6.2 `DISPLAY` set — the developer's condition, PLAN.md criterion 2

`DISPLAY=:163`, my own Xvfb, started and stopped by me. Note what that does and does not
cover: the 76 headless cases inherited `:163`, while the 11 `dcases` still took a private
Xvfb from `:100`, because `HOME` was a scratch directory with no
`~/.claude/xschem_dev_display` in it. That is the point of pointing HOME there — the
user's `:99` cannot be reached — and the arm line below says so outright.

```
T1-RUN-BEGIN pid=491987 script=run_regression.tcl start=2026-09-20 16:30:50 planned_cases=87 verdict=results.491987.log home=throwaway binary=/tmp/vb83/w/src/xschem canonical=results.log
T1-RUN-END pid=491987 cases=87 blocks=86 counted_failures=0 elapsed=526s end=2026-09-20 16:39:36
```

`Start` **87**, `Finish` **87**, peers **0**, `wc -l` **177**, hand-counted failures **0**.
Display arm: `PRIVATE Xvfb :100 for this run only (pid 553181, wm openbox)`.
Test home: `throwaway /tmp/xschem-test-home.491987.ScHkA3 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)`.

**Both are the documented green shape for an 87-case tree: `cases=87 blocks=86
counted_failures=0`, 87 `Start` / 87 `Finish`, `wc -l` 177.**

---

## 7. Files changed

| file | change |
|---|---|
| `src/scheduler.c` | the implement round's `has_x` guard, **plus** the `no_x_display` declaration moved inside `#ifdef __unix__` (+5 lines against the implement round; +38/−4 against `2fb377de`). md5 `4547befbe5464ca11f0ba1af542d611f`. |
| `tests/headless/test_callback_argc.tcl` | the third 1483 row split into an X-path branch and a no-X branch on `[info exists ::has_x]`; the key row's expectation made platform-tracking; the block comment rewritten to say which arms the file runs on. **+72 lines against `2fb377de`, 5 → 8 checks, and 8 on every arm.** md5 `57b1be1e1f11f3040ffb0ef73defb7bc`. |

Nothing else. **No commit made. No file under `doc/claude/` touched except
`receipts/B-verify.md` and the fix-round section appended to `receipts/B-impl.md`.**

## 8. Scratch

Two directories, both deleted by me. Sizes are `du -sk` samples taken every 20 s across
the sabotage sequence and the second T1, so these are measured maxima rather than estimates.

| scratch | what for | peak |
|---|---|---|
| `/tmp/vb83` | the working clone at a 12-character root: the build, every suite run, both T1s, the three sabotage rebuilds and the restore | **505904 KiB ≈ 494 MiB** |
| `…/scratchpad/stranger_reds/b` | the assigned root (111 characters; the copy inside it 113): a copy of the same tree, used for one thing only — measuring §4.8, the long-path red | **229912 KiB ≈ 224 MiB** |

**Combined peak: 735816 KiB ≈ 718 MiB.**

Also removed: the `Xvfb :163` I started, and the `/tmp/xschem_emergencysave_*` directories
created by **my own** crashing sabotage runs today. The ones already in `/tmp` from earlier
sessions were not touched.