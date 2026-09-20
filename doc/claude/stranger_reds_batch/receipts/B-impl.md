# B-impl — issue 1483, four T1 suites segfault under `--nogui` when `DISPLAY` is unset

Implementer receipt. Item B of the stranger-reds batch. Base `1f3f5287`
(the driver's tree had moved to `2fb377de` by the time the edits were applied;
neither file this touches was changed by that commit).

**Result in one line:** one statement, `scheduler.c:6100`, dereferenced the X `display`
global with no `has_x` guard. All four suites crash there. Guarded; T1 with `DISPLAY`
unset now reaches `counted_failures=0` — the first headless ZERO this tree has had.

⚠ **Every `file:line` below is at `1f3f5287`, the unfixed tree.** They are quoted with a
revision because CLAUDE.md measured bare line citations rotting 5 of 5 — and because this
fix itself moves `scheduler.c` by +6 lines above the site it patches, so the very numbers
in §1.1 are already stale in the fixed tree. The identities (`xschem_cmds_g`, the
`"globals"` branch, `xserver_ok()`, `update_statusbar()`) do not move; re-grep before
requoting a number.

---

## 1. The cause, measured

### 1.1 The backtrace — the same one, four times

Debug build (`-O0 -g`) of a fresh clone, `gdb -batch`, `handle SIGSEGV stop nopass` so
xschem's own SIGSEGV handler does not swallow the frame. One scratch HOME per suite,
`env -u DISPLAY`.

```
Thread 1 "xschem" received signal SIGSEGV, Segmentation fault.
0x00007ffff7c1fd14 in XMaxRequestSize () from /usr/lib/x86_64-linux-gnu/libX11.so.6
#0  0x00007ffff7c1fd14 in XMaxRequestSize () from libX11.so.6
#1  0x0000555555652f50 in xschem_cmds_g (interp=…, argc=2, argv=…, cmd_found=…)
        at scheduler.c:6100
#2  0x0000555555677ed6 in xschem (clientdata=0x0, interp=…, argc=2, argv=…)
        at scheduler.c:15095
#3  TclInvokeStringCommand … #6 Tcl_FSEvalFileEx … #7 Tcl_EvalFile
#8  source_tcl_file (s=… "headless/test_unused_attr_0970.tcl") at xinit.c:1522
#9  Tcl_AppInit (inter=…) at xinit.c:4100
#10 main (argc=6, argv=…) at main.c:149
```

`rdi` at the fault is `0x0`. Frame 1, `info locals`, `i = 2` — `argc == 2`, so the
subcommand is the bare two-word form. The `else if(!strcmp(argv[1], "globals"))` branch
begins at `scheduler.c:6010`; the faulting statement is

```c
my_snprintf(res, S(res), "XMaxRequestSize=%ld\n", XMaxRequestSize(display));
```

**Byte-identical frames #0–#10 for all four suites**, differing only in the script name
in frame #8 and in interpreter/argv addresses:

| suite | frame #1 | frame #8 script | `display` |
|---|---|---|---|
| `test_unused_attr_0970` | `xschem_cmds_g … scheduler.c:6100` | `test_unused_attr_0970.tcl` | `0x0` |
| `test_auto_specialize_1201` | `xschem_cmds_g … scheduler.c:6100` | `test_auto_specialize_1201.tcl` | `0x0` |
| `test_ase_optier_0963` | `xschem_cmds_g … scheduler.c:6100` | `test_ase_optier_0963.tcl` | `0x0` |
| `test_op_annot` | `xschem_cmds_g … scheduler.c:6100` | `test_op_annot.tcl` | `0x0` |

**One cause, not four.** Two of the four were required; all four were taken.

### 1.2 Why `display` is invalid, and why it is invalid in *two* different ways

`display` (`src/globals.c`) is initialised `NULL` and assigned in exactly three places:
`draw.c:68` inside `xserver_ok()`, and `xinit.c:332` / `xinit.c:3757`, both
`Tk_Display(mainwindow)` **inside `if(has_x)`**. So with `has_x == 0` the global is never
a live connection, and which kind of wrong it is depends on `DISPLAY`:

```c
/* src/draw.c, xserver_ok() */
if(!getenv("DISPLAY") || !getenv("DISPLAY")[0]) has_x = 0;      /* display stays NULL   */
else {
  display = XOpenDisplay(NULL);
  if(!display) { has_x=0; … }
  else XCloseDisplay(display);                                   /* …and never NULLed   */
}
```

* **`DISPLAY` unset** → `display` is `NULL` → `XMaxRequestSize(NULL)` → **SIGSEGV**.
  That is issue 1483.
* **`DISPLAY` set and `--nogui` given** → `has_x` is 0 (set by `options.c`) but `display`
  holds the pointer `xserver_ok()` already `XCloseDisplay()`d → **use-after-free**.

The second is why nobody ever saw this: reading a freed heap block does not usually
fault. Measured with gdb, `--nogui`, `DISPLAY=:151`, breakpoints on `draw.c:75` and
`scheduler.c:6100`:

```
in xserver_ok, display=0x5555557b2160
at globals call, display=0x5555557b2160, has_x=0
GOT: XMaxRequestSize=4
GOT: XExtendedMaxRequestSize=4194303
```

Same pointer, after `XCloseDisplay()`. And the number is **fabricated**: the same build
with a live display reports `XMaxRequestSize=65535`. So on every developer machine this
statement has been silently printing garbage out of freed memory, and on every headless
one it has been killing the process. **One statement, two defects, and the harmless-looking
one is what hid the fatal one.**

### 1.3 Who calls it

`xschem globals` is called from the product, not only from suites:
`src/op_annot.tcl:936` — `if {[catch {xschem globals} g]} { return {} }`. That `catch`
is the caller already allowing for failure; a SIGSEGV is not catchable. Three of the four
suites reach it through `op_annot`; `test_auto_specialize_1201` calls it directly
(`:2350`, `:2843`). The four differ only in which `ok:` row happens to be the last one
printed before their first `xschem globals` — which is why the issue's four "last rows"
(`UF28`, `AS65`, `S13`, `W30a`) looked like four unrelated sites.

### 1.4 The issue's INFERRED relations: one refuted, one corrected, one diagnosed

1483 marks its relation to **0227**, **0834** and **0467** as INFERRED. Measured:

* **0227 / 0834 are NOT the cause of 1483.** They are `xschem callback` →
  `update_statusbar()` → `XGetKeyboardControl(display)`, now at **`callback.c:9891`**
  (0227 cites `:8721`; the line has moved, the defect has not). 1483 is a different verb,
  a different function and a different Xlib call. **The relation is right about the
  CLASS and wrong about the SITE.**
* **0227 is still live at HEAD, and my fix does not touch it.** 0227's own minimal repro
  on the **fixed** binary:
  ```
  A: about to fire one canvas callback
  EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_fccgcdbgff
  FATAL: signal 11
  ```
  `B: survived` never prints. 0834 is the same defect (both are "`xschem callback`
  under `--nogui`"); nothing measured here distinguishes them.
* **0467 IS 0227 — newly diagnosed.** 0467 has stood since 2026-08-20 saying *"Nobody has
  diagnosed the teardown crash itself"*, and calls it a crash "at teardown". It is
  neither undiagnosed nor at teardown. Backtrace on the **fixed** binary, `env -u DISPLAY`:
  ```
  #0  XGetKeyboardControl () from libX11.so.6
  #1  update_statusbar (persistent_command=0, wire_draw_active=0) at callback.c:9891
  #2  callback (win_path=".drw", event=2, mx=100, my=100, key=117, …) at callback.c:10093
  #3  xschem_cmds_c (… argc=10 …) at scheduler.c:2765
  ```
  It dies **mid-suite** on a `xschem callback` row after 20 `ok:` rows, in
  `update_statusbar()`. That is 0227 exactly. **0467 should be closed as a duplicate of
  0227**, and 0227's severity re-read accordingly.

So the three related issues are one further instance of the same class — *a Tcl-reachable
`xschem` subcommand that touches `display` without a `has_x` guard* — at a second site.
**Not fixed here** (see §5).

---

## 2. What I changed

### 2.1 `src/scheduler.c` — the product fix (29 insertions, 4 deletions)

The `#ifdef __unix__` Xserver-options block of `xschem globals` now branches on `has_x`:

```c
if(has_x) {
  my_snprintf(res, S(res), "XMaxRequestSize=%ld\n", XMaxRequestSize(display));
  Tcl_AppendResult(interp, res, NULL);
  my_snprintf(res, S(res), "XExtendedMaxRequestSize=%ld\n", XExtendedMaxRequestSize(display));
  Tcl_AppendResult(interp, res, NULL);
} else {
  my_snprintf(res, S(res), "XMaxRequestSize=%s\n", no_x_display);
  Tcl_AppendResult(interp, res, NULL);
  my_snprintf(res, S(res), "XExtendedMaxRequestSize=%s\n", no_x_display);
  Tcl_AppendResult(interp, res, NULL);
}
```

plus a file-scope `static char *no_x_display = "<no X server connection>";` next to the
existing `not_avail` (`:265`), with a comment saying why it is deliberately not a number.

**Why this shape.** It is the idiom the file already uses, not a new one:

* `scheduler.c:4903` — `xschem get gc_line_style`: `if(!has_x || …) Tcl_SetResult(…"-1")`
  else `XGetGCValues(display, …)`, with a comment defining `-1` as "no X".
* `hilight.c:859` — `resolve_hilight_style_rgb()`: `if(… || !has_x) return;` before
  `XQueryColor(display, …)`, documented as "no-op for … or headless".
* `xinit.c:3847` — the *other* `XMaxRequestSize(display)` in the tree is already inside
  `if(has_x)`. `scheduler.c:6100/6102` were the only two left out.

**It does not silently skip work the caller asked for.** The section header and both keys
are still emitted; only the value changes, to a string that says there is no display. A
reader still finds the keys, and a reader scanning for digits correctly comes away with
nothing instead of with `4`. Erroring the whole `globals` command out would have been
wrong — it is a dump of ~40 fields of which two are X-derived, and `op_annot.tcl:936`
depends on the non-X ones (`lcc[…]`).

Unchanged on the X path, measured with a live display and no `--nogui`:
`XMaxRequestSize=65535`, `XExtendedMaxRequestSize=4194303` — identical to base.

C89: no declarations after statements, no `//`, the new string is file-scope, and the
executable change stays inside the existing `#ifdef __unix__`.

⚠ **One deliberate untidiness, stated rather than fixed.** `no_x_display` is declared
outside the `#ifdef __unix__` (beside `not_avail`, which is where the file keeps its
static strings) but used only inside it, so a non-`__unix__` build has one unused static.
It is harmless — the project's `CFLAGS` are `-pipe -O2` with no `-Wall`, and the Windows
flags in `XSchemWin/` were not checked — and wrapping it would be a one-line change. I did
**not** make it after the proof runs, because every T1 trailer and every suite count in
this receipt was taken against the source exactly as it now stands, and CLAUDE.md's rule
is that a measurement belongs to the bytes that produced it. If the driver wants the
`#ifdef`, it is a rebuild and a re-run, not an edit.

### 2.2 `tests/headless/test_callback_argc.tcl` — the T1-visible guard (+41 lines)

1483's fix direction step 2 asks for a guard "so the next regression of this shape is
counted on every box and not only on DISPLAY-less ones". Three rows added to an existing
T1 case rather than a new suite — no new `hcases` entry, no change to the case count
(still 87), and no new launcher script for `test_home_isolation`'s G2 row to police.

`test_callback_argc` is the right home on subject, not convenience: its whole existence
is "a Tcl-reachable `xschem` subcommand must ERROR, never crash" (issue 0076). This is
the same sentence about a different verb.

The rows assert that `xschem globals` returns rc 0, that both X keys are still present,
and that **neither carries an integer**. `run_regression.tcl:1132` hard-codes `--nogui`
for every headless case, so `has_x` is 0 there **whatever the tester's `DISPLAY` is** —
which means the guard runs on a developer desktop and on a CI container alike. That
symmetry is the whole point: 1483 survived because the only arm anyone ran was the one
where the same bad pointer merely read freed memory.

Check count: **5 → 8**.

---

## 3. Proof, both ways

All runs in my own clone. The four suites, `env -u DISPLAY`, `--nogui --pipe -q`,
one scratch HOME each:

| suite | base (unfixed) | fixed, `DISPLAY` unset | expected |
|---|---|---|---|
| `test_unused_attr_0970` | `FATAL: signal 11` after `UF28`, rc 1 | `RESULT: ALL PASS (67 checks)` rc 0 | 67 ✅ |
| `test_auto_specialize_1201` | `FATAL: signal 11` after `AS65`, rc 1 | `RESULT: ALL PASS (85 checks)` rc 0 | 85 ✅ |
| `test_ase_optier_0963` | `FATAL: signal 11` after `S13`, rc 1 | `RESULT: ALL PASS (109 checks)` rc 0 | 109 ✅ |
| `test_op_annot` | `FATAL: signal 11` after `W30a`, rc 1 | `RESULT: ALL PASS (485 checks)` rc 0 | 485 ✅ |

The four base rows reproduce 1483's table exactly, including the last `ok:` row of each.

### 3.1 T1 with `DISPLAY` unset — `counted_failures=0`

```
T1-RUN-BEGIN pid=4063562 script=run_regression.tcl start=2026-09-20 15:05:46 planned_cases=87 verdict=results.4063562.log home=throwaway binary=/var/tmp/x1483/w/src/xschem canonical=results.log
T1-RUN-END pid=4063562 cases=87 blocks=86 counted_failures=0 elapsed=520s end=2026-09-20 15:14:26
```

`Start` 87, `Finish` 87, `another regression run is live` **0** (solo, stated positively),
`wc -l` **177** — the documented green shape for an 87-case tree. `home=throwaway`,
`binary=` names my clone's own binary, so neither a PATH fallback nor a real HOME is in
play.

Note the `Start`/`Finish` pair is 87/87 rather than 87/76: `DISPLAY` was unset for the
**suites**, but D8's private-Xvfb display arm still ran the 11 `dcases`, so the issue-1481
asymmetry does not appear here. `cases=87` from the trailer is the authority either way.

A **first** run of this pair, taken before the `test_callback_argc` rows were added
(product fix only, `pid=4003804`, `elapsed=520s`), also closed
`cases=87 blocks=86 counted_failures=0`. So the headless ZERO is the product fix's, and
the added rows did not manufacture it.

### 3.2 T1 with `DISPLAY` set — still `counted_failures=0`

Private Xvfb on **`:151`** (`Xvfb :151 -screen 0 1920x1080x24 -nolisten tcp`), started and
stopped by me. The user's `:99` was never touched and no `~/.claude` state was read or
written — `HOME` was pointed at my own scratch for every run, so T1's dev-display
auto-start (D13.2, conditional on `~/.claude/xschem_dev_display` existing) could not fire.

```
T1-RUN-BEGIN pid=4188390 script=run_regression.tcl start=2026-09-20 15:26:41 planned_cases=87 verdict=results.4188390.log home=throwaway binary=/var/tmp/x1483/w/src/xschem canonical=results.log
T1-RUN-END pid=4188390 cases=87 blocks=86 counted_failures=0 elapsed=525s end=2026-09-20 15:35:26
```

`Start` 87, `Finish` 87, peers 0, `wc -l` **177**.

Criterion 2 (no regression in the developer's condition) is met.

#### 3.2.1 The first `DISPLAY`-set run was RED, and it was the documented flake

Recorded rather than quietly re-run, because CLAUDE.md's rule is *diagnose a T1 red by
case, never by count*. The first attempt (`pid=4127553`, `elapsed=522s`) closed
`cases=87 blocks=86 counted_failures=3`, `wc -l` 180. All three lines are one case:

```
FAIL: X1 issue 0965 … -> {NORAW} (exp {1 0 {}}) : FAIL
FAIL: X2 issue 0969 … -> {{} ZZNOTRUN} (exp {{} {}}) : FAIL
HARNESS: headless/test_ase_optier_0963 did not complete cleanly (exit=1, OVERALL_ok=0, died=0) …
```

and the case log gives the signature:

```
MEASURE X bench form=c rc=1 deck=36616bytes/369lines wall=10759ms raw=-1bytes asked=468 devices=78 back/miss=NORAW
MEASURE X bench form=b rc=0 deck=18962bytes/368lines wall=10048ms raw=706195bytes back/miss=468 468 {}
```

That is **byte-for-byte the `test_ase_optier_0963` flake CLAUDE.md already names** —
"`X1`/`X2` — ngspice `rc=1`, `raw=-1bytes`, `NORAW`" — down to the count of 3. It is one
ngspice invocation failing to write a rawfile: `form=b` in the same row ran fine at
706 kB, and `X7` later in the same run got `rc=0 raw=284353bytes`, so the simulator was
working before and after. The standalone re-run prescribed by CLAUDE.md:

```
MEASURE X bench form=c rc=0 deck=36616bytes/369lines wall=10365ms raw=284353bytes asked=468 devices=78 back/miss=468 468 {}
RESULT: ALL PASS (109 checks)
```

**Nothing to do with item B.** The case is one of the four 1483 was filed against, so the
coincidence is worth stating plainly: it passed with `DISPLAY` unset in both headless T1s
and in its own standalone run, and the one time it failed was on the arm this fix does not
touch, in the ngspice leg, by the exact signature of a flake logged before this batch
existed. Cause still undiagnosed upstream; not filed again, because it already is.

---

## 4. Sabotage

Every sabotage is a rebuild, not a comment-out: `git stash push -- src/scheduler.c`,
`make -C src`, run, `git stash pop`, verify by md5.

| # | what was reverted | condition | result |
|---|---|---|---|
| S1 | the `has_x` branch, `scheduler.c` | 4 suites, `DISPLAY` unset | all four die: `FATAL: signal 11` after `UF28` / `AS65` / `S13` / `W30a`, rc 1 — the defect returns, suite for suite and row for row |
| S2 | same | `test_callback_argc`, `DISPLAY=:151`, `--nogui` | `FAIL: 1483 neither X field fabricates a number … -> {1 1} (exp {0 0})`, `RESULT: 1 FAILED (7 passed)` — the new guard reds **on a DISPLAY-set box** |
| S3 | same | `test_callback_argc`, `DISPLAY` unset | `FATAL: signal 11`, rc 1 — no banner, so T1 counts the case |

**Bytes restored and verified**: `src/scheduler.c` md5 `73e44e02f6b1c1ed3f93bd53940dbf50`
before the sabotage and after `git stash pop`, identical, and identical again to the copy
kept outside the tree and to the file now in the driver's tree. `git stash list` empty.

S2 is the one that matters for the future: on the base code the new row fails **without
needing a headless box**, so this class can no longer hide behind a use-after-free that
happens not to fault.

---

## 5. What I did NOT fix, and why

* **0227 / 0834 / 0467 — `update_statusbar()` → `XGetKeyboardControl(display)`,
  `callback.c:9891`.** Same class, different site, measured live at HEAD (§1.4). Out of
  scope for item B by criterion 4, and not a drive-by: 0227 itself warns that guarding it
  *"clears the FIRST headless landmine in `callback()`; the rest of that function is
  unproven headless and later checks may expose more"*. `test_undo_selection` is not a T1
  case, so fixing it blind could convert a silent crash into a cascade of new reds inside
  a batch that caps itself at one fix round. **Recommend: 0467 closed as a duplicate of
  0227; 0227 fixed as its own item, with `test_undo_selection` as the red-first fixture
  (20 `ok:` rows, then the crash, deterministic).**
* **`display = NULL;` after `XCloseDisplay(display)` (`draw.c:75`).** 0227 already
  recommends it, and §1.2 is the measurement that justifies it: today the `--nogui`-with-
  `DISPLAY` case reads freed memory instead of faulting, so the two arms of every test
  exercise *different pointer states* — which is precisely how 1483 stayed invisible.
  I did not make the change because it is hardening for **other** call sites (my guard
  already covers this one), it would change behaviour at an unknown number of the 245
  `X…(display` sites in `src/`, and it belongs with 0227. **It is the single highest-value
  follow-up in this area**: it would make a DISPLAY-set T1 fail wherever a headless one
  does, permanently.
* **The other 244 `X…(display` call sites.** Surveyed, not audited: 152 in `draw.c`,
  69 in `xinit.c`, 13 in `callback.c`, 4 `actions.c`, 3 `scheduler.c`, 3 `hilight.c`,
  1 `move.c`. The three outside the drawing core that a Tcl command can reach were
  checked by hand — `scheduler.c:4907` and `hilight.c:863` are correctly `has_x`-guarded;
  `scheduler.c:6100/6102` were not, and are the subject of this item. No claim is made
  about the rest.

---

## 6. Found outside item B — filed, not fixed

### 6.1 `test_op_annot` cannot pass in a clone whose path is longer than ~73 characters

**Not related to `DISPLAY` and not related to this fix** — measured on the **unfixed**
binary with `DISPLAY` set, so it predates everything here.

In a clone at `…/scratchpad/stranger_reds/b/work` (a 118-character path) the suite
reports `RESULT: 3 FAILED (482 passed)`: rows **N6**, **N9** and **V31b**. In a clone at
`/var/tmp/x1483/w` (16 characters) the same binary reports `ALL PASS (485 checks)`.

Cause, read out of the product: `xctx->statusmsg_text` is `char[256]` (`xschem.h:1867`),
and `cadence::_annot_fit` (`utils/annot_mode.tcl:724`) deliberately cuts any status line
over 255 bytes back to the last space before byte 252 and appends `...`. The three
goldens embed an **absolute** path in the expected sentence:

```
exp: … There is no results file at <abs>/tests/headless/.scratch/_op_annot_<pid>/n_nd_empty/n_dev.raw yet. Run a simulation first.
got: … There is no results file at...
```

The fixed prefix is 83 bytes and the suffix 29, so the whole sentence fits only while the
absolute path stays under ~143 bytes — i.e. while the clone root stays under ~73. V31b is
the same cause at one remove: it tests `string match "… results file at *"`, and the cut
removes the space the pattern needs.

**Why it is worth filing rather than shrugging at:** this is exactly item C's shape — *a
stranger's checkout path reds a suite that has nothing to do with paths* — with a
different trigger (length, not case). A CI system that checks out into
`/builds/<org>/<project>/<pipeline-id>/…` will trip it. The fix is on the test side (assert
`[file tail $path]`, or compare against `cadence::_annot_fit`'s own output), and the
product side is arguably fine: cutting the file name out of an over-long status line is a
ratified ruling (A11-12b).

**This is why my T1 runs are in a short-path clone** and not in the assigned scratch root:
the scratch root the harness hands out is itself 113 characters, so *no* clone inside it
can run `test_op_annot` green, fix or no fix. Both clones were used; both are deleted.

### 6.2 `t1_arm_home` refuses correctly, and loudly

Not a defect — recorded because it is the arm working and it cost me one run. With
`TMPDIR` pointed at a directory that does not exist, T1 printed

```
!! test home REFUSED: could not create a throwaway home under … (mktemp: … No such file or directory).
!! Nothing was run, and your real HOME was not used in its place (tests/test_utility.tcl, t1_arm_home).
```

and exited **3** having run nothing. It failed closed, said so on both counts, and did not
fall back to the real HOME. Worth knowing that the refusal exit code is 3.

A second, unrelated refusal is worth the same note: giving `HOME` a directory that does
not exist makes `create_save` refuse with `XSCHEM_TEST_REAL_HOME='…' -- it is not an
existing directory`, and the run continues with that case broken rather than stopping.
Create the directory; do not just name it.

### 6.3 Incidental confirmation of item F (issue 1486)

Not investigated, just seen: a `du` walk during a T1 run raced a file the suites write
into the working directory —
`du: cannot access '/var/tmp/x1483/w/tests/untitled~.sch': No such file or directory`.
That is item F's subject appearing on its own, in a tree nobody had pointed at it.

---

## 7. Files changed

| file | change |
|---|---|
| `src/scheduler.c` | +29 / −4. `has_x` guard on the two Xlib calls in `xschem globals`; new file-scope `no_x_display` string. |
| `tests/headless/test_callback_argc.tcl` | +41. Three rows guarding the class on every box. 5 → 8 checks. |

Nothing else. No commit made. No file under `doc/claude/` touched except this receipt.

## 8. Scratch

Two clones, both deleted by me. Sizes are `du -s` samples taken every 15 s across the
T1 runs, so these are measured maxima, not estimates:

| scratch | what for | peak |
|---|---|---|
| `/tmp/claude-1000/…/scratchpad/stranger_reds/b` | the assigned root; debug build (`-O0 -g`), every backtrace, the sabotages | **425 804 KiB ≈ 416 MiB** |
| `/var/tmp/x1483` | short-path clone, normal `-O2` build, the suite proofs and all four T1 runs (§6.1 is why it had to exist) | **519 864 KiB ≈ 508 MiB** |

**Combined peak: 945 668 KiB ≈ 924 MiB (0.90 GiB).**

Also removed: the `Xvfb :151` process I started, and the `/tmp/xschem_emergencysave_*`
directories created by my own crashing runs **today** — 616 such directories exist in
`/tmp` from earlier sessions and none of those were touched.

---

# FIX ROUND (2026-09-20) — appended by the fixer, after the two adversarial reviews

Full account in `receipts/B-verify.md`. This section records only what changed in the two
files this receipt describes, and the corrections the reviews made to the text above.
**The sections above are left exactly as the implementer wrote them**; where a review
corrected one, the correction is here rather than an edit up there.

## What changed in the code

1. **`tests/headless/test_callback_argc.tcl`, the third 1483 row — the one real defect
   the round had.** §2.2's reasoning ("`run_regression.tcl:1132` hard-codes `--nogui`, so
   `has_x` is 0 here whatever the tester's `DISPLAY` is") is **true of T1 and false of the
   other two drivers.** `test_callback_argc` is not in `full_audit.sh`'s `nogui_tests`
   list, so `full_audit.sh` and `run_suites.sh <t>` both run this file **without**
   `--nogui`; there `has_x` is 1, the product correctly reports 65535 / 4194303, and the
   unconditional `{0 0}` row failed. Measured, implement-round code, one binary:
   GUI arm `RESULT: 1 FAILED (7 passed)` against the pre-change file's `ALL PASS
   (5 checks)` on the identical arm and binary. Both verifiers found it independently
   (one as a blocker, one as a must).
   The row now branches on `[info exists ::has_x]` — the codebase's own mirror of the C
   guard, written by `xinit.c:3195` inside `if(has_x)` and nowhere else — asserting
   "both fields carry a real number" on the X path and "neither fabricates a number"
   off it. One check either way: **8 on every arm**, and the off-X assertion is
   byte-identical to the row it replaces, so nothing this round proved is given up.
2. **The two key rows are now unix-conditional.** The whole `Xserver options` block is
   `#ifdef __unix__`, so on a Windows build the keys are absent and the row asserting
   they are present would have failed although the product is correct. READ from the
   source, not measured.
3. **`no_x_display` moved inside `#ifdef __unix__`** — the untidiness §2.1 flagged
   deliberately and declined to change, on the correct rule that its measurements
   belonged to the bytes that produced them. The fix round re-runs the four suites and
   both T1s anyway, so the rebuild was free and every number in `B-verify.md` belongs to
   the bytes now in the tree.

## Corrections to the text above

* **§5, "The other 244 `X…(display` call sites".** The pattern cannot see a `display`
  dereference whose callee does not begin with a capital X, and there are 8 such
  (`cairo_xlib_surface_create` ×7, `XGetXCBConnection` ×1). The **conclusion for
  `scheduler.c` survives** — the one such site in this file, `net_hilight_dump_pixmap`, is
  inside `if(has_x && xctx->save_pixmap)`, checked by hand. The **per-file counts do
  not**: three passes have produced three different sets for the same files. Do not quote
  them forward; the sentence they support is independently checked.
* **§6.1 is narrower than the defect.** A T1 inside the assigned 111-character scratch
  root counts **11** failures, not the three rows named here: `test_op_annot` N6/N9/V31b
  on both arms plus two `HARNESS` lines, **and `test_annot_hier_0911` H6/H13** plus its
  `HARNESS` line. That suite embeds an absolute path in an expected sentence the same way — its **H6**
  row expects `There is no results file at [file join $ND2 top.raw] yet.` — so it fails for
  the same reason at the same lengths. Measured by the `completeness` verifier; the golden
  shape re-read here.
* **§1.4's new diagnosis, that 0467 IS 0227, was independently confirmed** by the
  `reproduce` verifier (20 `ok:` rows then `FATAL: signal 11`, mid-suite), and two suites
  named in no issue file join the same class: `test_hilight_case_senders` and
  `test_window_switch_bogus_enter`.

## Gate after the fix round

Both T1s re-run in a 12-character clone after the last rebuild, solo, `HOME` on scratch so
`:99` was never touched. Trailers, check counts, sabotages and the eight `skip:` lines are
in `receipts/B-verify.md` §5 and §6; the short version is that the headless ZERO the
implement round won is still there, and the developer-condition ZERO with it.
