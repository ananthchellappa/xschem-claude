# Where branch `annotate` actually stands — 2026-08-24

> The other `status.md` in this folder belongs to **`fluid-editing`** and its
> 02xx numbering. This file is `annotate`'s, covering **0600–0667**. The two do
> not share a number space; do not merge them.

**68 issues filed in three days. 16 closed, 52 open.** That number looks alarming
and is partly misleading, so the first job of this file is to say which 52.

---

## 1. The honest breakdown of the 52

| # | class | what it means | count |
|---|---|---|---|
| A | **the user hit it** | reported from a real bench, still not fixed | **5** |
| B | **can bite a real user** | structural, nobody has hit it yet | **4** |
| C | **we broke it ourselves** | introduced by one of OUR fixes in the last 72h, found by our own adversary legs | **9** |
| D | **rulings, not defects** | shipped behaviour nobody ratified; the code works, the decision is unmade | **14** |
| E | **test/environment holes** | the suite is blind somewhere; no live defect | **6** |
| F | **deferred by the user** | explicitly parked | **2** |
| G | remainder | small, measured, unprioritised | 12 |

**Class C is the count inflating itself, and it is the process working, not
failing.** Every one of those nine was found by the adversary leg of the crew
that wrote the code, *before* it reached the user — 0652 against 0648's fix,
0664/0665/0666 against 0658's, 0640 against 0635's, 0641 against 0618's. The
alternative is not "nine fewer bugs", it is nine bugs shipped silently. Two
fixes were refuted by their own adversaries and **reverted rather than shipped**
(0617's blank-row message, 0616's first cut).

**Class D is not brokenness at all.** Fourteen decisions are sitting in the queue
waiting for a human. The code runs; it just runs a way nobody has ratified.

So the sentence "a lot of things are broken" is true of roughly **nine items**
(A + B), not fifty-two.

---

## 2. Class A — the user hit these, they are still open

| id | what you saw |
|---|---|
| 0649 | the simulation-log window shows the raw stream, never the framed log file — no scrollback, no filename, no completion line |
| 0612 | reproduced twice on the real screen |
| 0617 (display half) | a sheet whose OP rows are blank says nothing. An attempt was made and **REFUTED on your own bench family** — 35 of 104 `.state` files carry `savecurrents`, which gives every device a free `i(@dev[id])`, so the any-membership test declared a 5-of-6-blank sheet healthy. Reverted. |
| 0625 | a missing vector renders `-`, not blank — I3 says blank |
| 0647 | the design window may be *under* the restored waveform viewer rather than gone |

---

## 3. Class B — structural, and one of them is in a different league

### 0663 is the only item here that stops the tool from starting

```
error at the TOP of any late-sourced helper  -> SIGSEGV, exit 139
error at the END of it                       -> SIGSEGV, exit 139
the file ABSENT (the pure 0424 shape)        -> SIGSEGV, exit 139
```

`src/xschem.tcl` sources sixteen helpers with a **bare `source`**. An error inside
one propagates out of `xschem.tcl`, so the rest of that file never runs — no
statusbar widgets, no `build_widgets`, no colour setup. `source_tcl_file()`
(`src/xinit.c:1513`) prints and returns; **`Tcl_AppInit` ignores the return value**
(`src/xinit.c:3406`) and walks on into `tclgetdoublevar("cairo_font_line_spacing")`
against variables nobody set. That is the crash.

**This is the root cause of issue 0424, not a relative of it.** 0424 lost
`op_annot.tcl` from the install list; 275 in-tree checks stayed green and the
*installed* binary was dead on arrival. The fix then was to add the file back to
the install list. The crash mechanism was never touched, and `op_annot.tcl` is
still one of the sixteen bare sources today.

The test suite is **structurally blind** to it: in-tree, `XSCHEM_SHAREDIR`
resolves to `src/`, so a file missing from the install list is still found. Only
an installed-tree check or a deliberate sharedir farm
(`tests/headless/sharefarm.tcl`, new) can see it.

Exactly one of the sixteen is now guarded, by 0658:

```
14854:  if {[catch {source $XSCHEM_SHAREDIR/ciw.tcl} ciw_source_err]} {   <- guarded
14796:  source $XSCHEM_SHAREDIR/op_annot.tcl                              <- 0424's own file
14802:  source $XSCHEM_SHAREDIR/ase.tcl
14804:  source $XSCHEM_SHAREDIR/ase_window.tcl
        ... twelve more, all bare
```

The others: **0619** (`ps_colors[cadlayers]` heap over-read), **0641** (the log is
truncated at launch), **0632** (the OP walk rewrites `~` autosave backups of
ancestor cells you never touched).

---

## 4. The notify channel is half-built and currently lands nowhere

Three days of work built a real notification channel (0650, 0658) and it is
**not yet reaching you**:

* **0655** — the ASE session window, the one you drive simulations from, still
  has no notice sink at all.
* **0659** — a CIW that is *open but stacked behind* the design window reaches
  **zero visible sinks**. It tests as open and behaves as shut. Measured:
  `ismapped 1 · viewable 1 · statusbar unchanged`.
* **0667** — the degraded mode is log-only, so a GUI user sees nothing on screen.
* **0654 / 0660** — the drawing-window fallback field is 28 chars, silently
  clipping, shared, last-writer-wins, and carries no remedy. It structurally
  **cannot** carry the menu-path-plus-command sentence ruling R-0653-d requires.
* **0664 / 0665 / 0666** — introduced by 0658's own fix. One notice can write
  **two** durable lines, and can claim "DEGRADED" while the channel is fully live.

Net effect: **the machinery to tell you why an annotation is blank now exists,
and there is no reliable place for it to appear.** That is the single most
important gap on this branch, and it is what 0653 was ratified to close.

---

## 5. RECOMMENDED FIRST ACTION — fix 0663 as a class, in C

Not `ciw.tcl` again. Not sixteen `catch` wrappers. Fix
`Tcl_AppInit` / `source_tcl_file` so a failed helper source cannot walk on into
unset variables.

**Why this one first, ahead of the notify work and ahead of class A:**

1. **It is the only item on the branch that makes the tool not start.** Exit 139
   at launch outranks every blank row and every missing message.
2. **It has already shipped once** (0424) and was closed with a band-aid on the
   install list. It will ship again — sixteen files are exposed and a
   seventeenth added next year gets it wrong by default.
3. **Wrapping each source is sixteen chances to miss one.** A single fix in
   `Tcl_AppInit` covers every helper including ones not yet written.
4. **It dissolves an open ruling instead of adding one.** 0663's question — "should
   a broken `ciw.tcl` start degraded rather than SIGSEGV?" — is currently scoped
   to one file. Fix the class and the answer generalises for free, and 0658's
   per-file `catch` becomes redundant rather than becoming a pattern to copy
   fifteen more times.
5. **It disturbs nothing else.** It is in C, below all the Tcl work; the notify
   crews can proceed afterward without rebasing around it.

Cost: one crew. C change plus a sharedir-farm suite that is already written.

### Then, in order

1. **0664 + 0665 + 0666 as one crew** — all three live in `notify_safe`, one proc.
   Clean the channel before anything else is built on it.
2. **0655 + 0659 + 0667 as one crew** — all three are "where does a notice land
   when the CIW cannot take it". Needs your 0655 ruling first (recommendation:
   an ASE session-window notice segment; the statusbar demotes to a pointer).
3. **0653's annotation consumer** — the six blank-causes in `op_annot::text`, the
   per-pass tally, the remedy strings. This is what you originally asked for; it
   is last because it needs a channel that works.
4. **0649**, the log window.

---

## 6. What is NOT broken

Worth stating, because the issue count hides it.

* The OP-annotation feature works end to end on a real bench. Measured on
  `tb_bandgap`: `id = 4.944u | gm = 7.749u | gds = 9.592u | vgs = 1.805 |
  vth = 1.017`, with node voltages surviving (365 before, 365 after).
* The chords behave as ruled: `6` adds OP info, `Alt-6` adds node voltages,
  `Ctrl-6` clears — two additive setters and one clear-all, never a toggle.
* ngspice does **not** need modifying. A bare `show` in a `.control` block dumps
  every OP parameter of every device (spec §3.1, rule R5); save cards stay
  primary because `show` is operating-point only.
* Tiers at HEAD: `test_ase_core` 159 · `test_ase_final` 67 · `test_ase_dialogs`
  166 · `test_ase_window` 182 · `test_ase_cosim` 341 · `test_op_annot` 330/336 ·
  T2 6/6. T1's 3 FAIL are pre-existing and unrelated.

## 7. A note on elapsed time, so the next long run is not a mystery

Two crews have appeared to take 5–7 hours. Both were the **Windows host sleeping
and freezing the whole WSL2 VM** — 1.93 h of real agent work inside 7.38 h of wall
clock on the 0658 run, with all three live agents freezing within 47 seconds of
each other. `tests/headless/runtime_gaps.sh` now decomposes any run and names the
cause from the `btime` contradiction. The host sleep timeout has since been set
to Never.
