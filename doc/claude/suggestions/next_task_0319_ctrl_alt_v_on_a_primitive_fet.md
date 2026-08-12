# Task hand-off — issue 0319: Ctrl-Alt-V on a FET inside a descended instance neither ticks the box nor reaches the device

**Handed off** 2026-08-12 by the driver session that closed 0312, 0315 and drove
0318. **Branch** `fluid-editing`. **Start HEAD** `a55cba16`. **23 commits are
unpushed and NOTHING MAY BE PUSHED.**

You are the implementer. The driver does no work on this task and will only read
your receipt.

---

## ⚠ THIS TASK BEGINS WITH A MEASUREMENT, NOT AN EDIT

Read `doc/claude/issues/0319-ctrl-alt-v-on-a-fet-inside-a-descended-instance-neither-unhides-nor-reaches-it.md`
whole, first. It is deliberately written as a **located hypothesis, not a
measurement**, and it lists four things that are **not yet known**. Your first
deliverable is to close those four, in writing, before you change a line of code.

The user's own repro, verbatim from the issue:

```
xschem load {/home/qflow/dev/xschem/claude_1/xschem/sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch}
```
then load `ngspice_state1`. Descend into `x1`, select `x1` on the bandgap
schematic, **Ctrl-Alt-V** → the browser finds `x1` correctly (**this part works**).
Now descend into `x1` *inside* the bandgap (an instance of `bandgap_opamp`), select
a **FET such as `M18`**, **Ctrl-Alt-V** → `Show device internals` **does not tick
itself** and the navigator selects only `x1 > x1`, the parent.

### The four unknowns, and how to close them

1. **What does `M18` actually look like in the raw?** Not inferred — read it.
   `xschem raw list` in that context, grep for `m18` / `xm18` / `@m.` / `#`, and
   record the literal strings. This decides everything else.
2. **How is the asked path (`segs`) built for a PRIMITIVE instance?** Locate the
   producer (start at `ase::browser_sel_segment` and `wviewer::hier_now`) and
   record what it produces for `M18` versus for `x1`.
3. **Is item 18 wrong, or merely narrower than advertised?** If a primitive has no
   path segment at all, then "reach the device" is **not expressible** for it, and
   the honest fix is a **different sentence** — land on the parent and say the
   device's internals live at that level — not a relaxed match.
4. **Does descending matter at all?** The report descends first. Run the same
   selection from the TOP level as a control; item 13's descend path already
   eyeballed OK, so this is one run and it tells you whether the descend is part
   of the mechanism or scenery.

⚠⚠ **DO NOT "FIX" THIS BY RELAXING `==` TO `>`** in `browser_show_path`'s R12
auto-unhide probe (`if {$pmatched == [llength $segs]}`). That exact edit is named
in the source as the one that ticks the box, triples tb_bandgap's tree 45 → 129
and explains nothing; check **`BK43`** in `tests/headless/test_wave_sigbrowser_keys.tcl`
exists to red it. If your measurement says the `==` is genuinely wrong, that is a
finding to write up and bring back — **not** an edit to make quietly.

### What "done" can legitimately be

Any of these three, decided by what you measure — and **the decision is yours to
make and defend in the receipt**:

* **(a) A real fix**: the path for a primitive is constructible and the probe can
  reach it. Implement it.
* **(b) An honest narrowing**: a primitive genuinely has no segment, so the
  gesture lands on the parent **and says so in a sentence naming the device** —
  the box is not ticked because ticking it would not help. This is a *feature*
  change to item 18's promise; write the new sentence through the SAME formatter
  (`wviewer::browser_msg`) and nowhere else, or `BK34`'s one-formatter oracle will
  red you, which is exactly what it is for.
* **(c) A refutation**: the mechanism is something else entirely. Then the
  deliverable is the measurement, a rewritten issue, and no code.

**(b) and (c) are not failures.** A wrong fix here costs more than no fix: two-pane
item 18's LEDGER row is unticked and its verdict is NOT OK because of this, so
whatever you conclude has to be defensible to the user by hand.

### Scope

* **In scope:** `src/wave_viewer.tcl` (the R12 probe and the path producer),
  `src/ase.tcl` (the gesture's segment building) if the measurement points there,
  a regression test, the receipt, the issue's Status line, and — if you land (b) —
  `doc/claude/signal_browser_2pane_batch/LEDGER.md` item 18's row **with a note
  saying what changed about the promise**.
* **Out of scope:** issue 0318 (just fixed — do not revisit), issue 0320 (the
  pane's selection loss on resize, filed by the 0318 crew and awaiting a ruling),
  issue 0315 (closed this session), and any relaxation of `==`.
* Third instances of the same shape: **file a new issue**, do not widen this one.

---

## Non-negotiables — each has cost this project a session

1. **No `make`** unless you touch C (you probably will not). If you do: **NEVER
   run `make` while any suite is running.**
2. **Check for a running audit before ANY suite run**:
   ```sh
   while pgrep -af 'bash tests/headless/full_audit' >/dev/null; do sleep 60; done
   ```
   That exact pattern — a bare `pgrep -f full_audit` **matches your own Bash tool
   wrapper** and answers "yes" forever.
3. **GUI gate.** `GUI_GATE=1` **always** — never `GUI_GATE=0`, that disables the
   user's control panel. Use `tests/headless/run_suites.sh` or
   `tests/headless/gated_xschem.sh`, **never a bare `for` loop** (the panel lists
   those as `UNGATED` and cannot pause them). **The panel may be PAUSED while you
   work** — the 0318 crew hit exactly that. A paused gate means you WAIT; it is the
   user saying "hold off". Do not work around it, do not unset `GUI_GATE`, and say
   in your receipt if it blocked a run you wanted.
4. **Display health first:** `bash tests/headless/wslg_health.sh`. `STUB` means
   every GUI result that run is meaningless (issue 0310). The X server dies ~3x a
   session and takes the panel with it; a whole-suite `NORESULT` is that, not your
   bug.
5. **`tests/headless/test_wave_sigbrowser.tcl` is FROZEN** (ruling 30). Every other
   sigbrowser file is amendable. A new `test_*.tcl` is auto-collected by
   `full_audit.sh`; a **helper must never be named `test_*.tcl`**.
6. **This repro needs a real PDK workarea and a real raw.** It is not a
   fixture-in-scratch task. Read the memory note on how the user actually runs
   xschem before assuming a headless run reproduces it, and say plainly in the
   receipt which parts you could only reach by hand.
7. **Do not push. Do not touch 0318, 0320 or 0315.**

---

## Definition of done

1. **The four unknowns closed in writing**, with the literal raw strings quoted.
2. **A verdict**: (a), (b) or (c) above, with the reason.
3. **Checks.** Whatever you land, the *measurement* becomes a check where it can:
   the path a primitive produces, what the probe answers for it, and — if (b) —
   the sentence, asserted through `browser_msg` like the other eleven kinds
   (`BK32`/`BK34` are the pattern). If the raw is too big to ship, seed the
   inventory directly — `test_wave_sigbrowser_i12.tcl:508` (`bx_seed`) and
   `test_wave_sigbrowser_0315.tcl` (`be_seed`, plus the `be_drive_on` idiom that
   drives the REAL gesture with only the design-side reads stubbed) are both
   working precedents.
4. **SABOTAGE EVERY NEW CHECK.** One mutation per claim, applied to source, suite
   re-run, ids recorded in a table in the test file header. **Expect a hole** — the
   0315 battery found five live defects behind a fully green suite and the 0318
   battery found three, including one in the crew's own first cut of its fix.
5. **Adversarial review by agents that are NOT the implementer**, two lenses (one
   on the resolver/path semantics, one on evidence quality). Fix confirmed
   findings; record them with triage.
6. **Suites**: the sigbrowser family whole — `test_wave_sigbrowser`, `_sea`,
   `_panes`, `_2pane`, `_i12`, `_i14`, `_i1315`, `_keys`, `_digital`, `_0312`,
   `_0315`, `_0318` — plus `test_ase_cosim` and `test_wave_sigsearch`. Then
   `full_audit.sh`, reported as a **DIFF by test NAME and STATUS** against
   `doc/claude/batch_F/baseline_status.txt`, **never by red count**, with **every
   red-ward row re-run standalone**. Known non-regressions: batched-sweep
   `NORESULT`/self-SKIP, `test_wave_modes` `MG13`, `_i1315` `BP72`,
   `test_wave_markers` `MX7b`/`MX7d`, `test_ase_plot` P4/P6/P8,
   `test_placement_wire_gate` TIMEOUT, and `_sea`'s `bs_type` key-delivery stall
   (a batched run reported 18 FAILED, 79/79 standalone).
7. **Receipt** at `doc/claude/batch_F/receipts/19-issue-0319-primitive-fet-path.md`
   — the measurement first, then the verdict and why, the sabotage table, review
   findings with triage, suites, audit diff, and an explicit **"what this does not
   claim"**.
8. **Commit** (conventional-commit subject, body says *why*). **DO NOT PUSH.**
9. Update the issue's `**Status:**`. If a human has to look at the navigator pane
   to believe it, write **FIXED pending an eyeball** and the exact steps — the user
   works from **ASE-L**, so write the steps as things to do in the GUI, not as
   CLI incantations.

## Handy context

* `doc/claude/code_analysis/waveform_subsystem_reference.md` — load before touching
  the waveform/browser code.
* Issue **0217** is the declass rule that decides what a device contributes to a
  path (a single-letter head segment plus ≥2 following segments is a device-class
  tag; SPICE requires subcircuit instances to begin with `X`, which is why an
  `M`-prefixed instance is a primitive). The issue's hypothesis rests on it — check
  the rule against the raw rather than assuming it applies.
* Two-pane item 18's own write-up: `doc/claude/signal_browser_2pane_batch/18_receipt.md`
  (commits `6c887aed` + `91a3de1a`).
* Precedent for how a ruling, a sabotage table and review triage get written up:
  `doc/claude/batch_F/receipts/17-issue-0315-one-gesture-one-ciw-account.md`.
