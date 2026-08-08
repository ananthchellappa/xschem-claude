# Next session — fix issue 0228: `run_suites.sh` cannot read the `OVERALL: ok` sentinel

**Issue:** `doc/claude/issues/0228-run-suites-will-not-read-the-overall-ok-sentinel.md`
**Branch:** `fluid-editing`. **Base commit when this was written:** `ec3be040`.
**Size:** XS — about eight lines of shell in one file, plus the measuring.

---

## The prompt (paste this)

> Fix issue 0228 in `/home/qflow/dev/xschem/claude_1/xschem` on branch `fluid-editing`.
> Read `doc/claude/issues/0228-run-suites-will-not-read-the-overall-ok-sentinel.md` first —
> it carries the diagnosis, the exact patch and the two details that are the whole point.
> Then read this file's **Traps** and **Done when** sections before writing anything.
>
> The job: `tests/headless/run_suites.sh` scores a passing suite as `NORESULT` when that
> suite reports through the older `OVERALL: ok` sentinel instead of a `RESULT:` line. It is
> the only one of the three harnesses missing the fallback — `full_audit.sh:99` already
> ships it and `run_regression.tcl:115` requires the sentinel. Teach `run_suites.sh` the
> same fallback. **Do not edit the test files.**

---

## Why this one first

No coverage is actually lost — `run_regression.tcl` and `full_audit.sh` both score these
files correctly. What is lost is **readability of the X arm**: a real regression inside
those suites is today indistinguishable from their permanent `NORESULT`. Every other piece
of work on this branch is verified through that arm, so fixing it first makes everything
after it measurable.

---

## Scope

**One file: `tests/headless/run_suites.sh`.** The patch goes immediately after line 104,
which today reads:

```sh
    result=$(printf '%s\n' "$out" | grep -E '^RESULT' | tail -1)
```

The issue's `## Suggested fix` section has the exact block to insert. Two details in it are
load-bearing and must survive review:

* **`OVERALL: notok` must map to `FAIL`**, not fall through to `NORESULT`. Otherwise a real
  failure in these suites stays exactly as unreadable as it is today, and the fix would be
  cosmetic.
* **`grep -qx`** (whole-line match), mirroring `run_regression.tcl:115`'s anchored
  `{^OVERALL: ok$}`. A loose `grep -q` lets the string appear inside a check's *message* and
  forge a pass.

**Out of scope**, both named in the issue as arguably separate — do them only if you
finish early, and as separate commits:
* normalising `test_lib_new_discovered_defs`' lowercase `RESULT: all passed`;
* giving the four custom-banner suites (`test_nogui`, `test_readonly_guard`,
  `test_hi_descend`, `test_cadence_descend_newwin_ro`) a standard `RESULT:` line so
  `full_audit.sh:87-98`'s bespoke cases could be deleted.

---

## ⚠ Traps

1. **DO NOT add a `RESULT:` line to `test_wire_split.tcl`.** The issue says this explicitly.
   That file's header *documents* its choice, `run_regression.tcl` requires it, and patching
   the test leaves `run_suites.sh` unable to read the *next* test written to the same
   convention. The aim is **one banner rule shared by all three readers**.

2. **THE AFFECTED-SUITE COUNT IS DISPUTED — MEASURE IT, DO NOT QUOTE EITHER NUMBER.**
   The issue's own patch comment says **four** suites (`test_wire_split` 121,
   `test_crossview_paste` 28, `test_pin_type_edit` 19, `test_add_pin_lib_symbol_view` 12).
   A later backlog sweep counted **eight** NORESULT plus one FAIL, ~215 checks, adding
   `test_hi_descend` 19, `test_readonly_guard` 11, `test_cadence_descend_newwin_ro` 5 and
   `test_nogui`. Those extra four are the **custom-banner** suites, which the fallback above
   does **not** reach — so both numbers can be right about different things. Produce the real
   list yourself, before and after, and say which suites the fallback actually converts.

3. **`grep -qx` vs `grep -q`.** Write the sabotage that proves it: put the literal string
   `OVERALL: ok` inside a check message in a scratch copy and confirm the whole-line form
   refuses it while the loose form accepts it.

4. **The X arm is now GATED.** `doc/claude/signal_browser_2pane_batch/xarm.sh mode` answers
   `GATED :0` — the GUI-test-gate panel governs every X run and its Pause/Stop are the
   user's authority. Use `xarm.sh suites <full test file names>` / `xarm.sh one <suite>` with
   `SUITE_TIMEOUT=400`. If a run seems to stall, read `~/.claude/gui_test_gate/control`; if
   it says `PAUSE`, **wait**. Never set `GUI_GATE=0`, never kill the panel, never call
   `run_suites.sh` / `gated_xschem.sh` / `./src/xschem` directly for an X run, and never
   write a bare loop over the binary. Press **Allow 30m / Allow 2h** on the panel once rather
   than clicking Proceed repeatedly.

5. **You are editing the harness you are measured by.** A bug here reports itself as green.
   Every claim needs the before/after pair, and the check COUNT is the witness — a suite that
   flips NORESULT → PASS must show the same check count both ways.

---

## RED first

Before touching `run_suites.sh`, capture the current state so the fix is attributable:

```sh
cd /home/qflow/dev/xschem/claude_1/xschem
SUITE_TIMEOUT=400 doc/claude/signal_browser_2pane_batch/xarm.sh one test_wire_split
```

must today print `NORESULT | test_wire_split … (exit 0 — binary never reported)` and exit 1,
while the same file passes headless:

```sh
env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wire_split.tcl \
  | tail -3          # -> "OVERALL: ok", 121 checks, no RESULT: line
```

That contradiction — pass one way, NORESULT the other, same binary, same output — is the
issue in one screen. Record it.

---

## Done when

* `run_suites.sh` reads both sentinels, with `notok` → FAIL and whole-line matching.
* The suites the fallback converts go `NORESULT` → `PASS` through `xarm.sh`, **at the same
  check counts they already report headless**, and you have listed exactly which ones.
* A deliberate `OVERALL: notok` reports **FAIL**, not NORESULT. Run it, do not reason about it.
* The forged-pass sabotage (trap 3) is refused.
* **Neither recorded baseline moves.** From `doc/claude/signal_browser_2pane_batch/LEDGER.md`:
  * headless **1705 / 0** over 15 files;
  * X **12/12 = 2287** (or 2288 — `i1315`'s `BP56` pixel leg is gated and reports 190 *or*
    191 on identical bytes; both are accepted, neither is drift);
  * the three out-of-baseline X-only suites, run by hand through `xarm.sh one`:
    `test_bindings_file` **13**, `test_keybindings_help` **17**,
    `test_key_graph_context` **70**. Both binding suites THROW under `--nogui`.
* Known flakes — re-run before calling any of them a fail: `BR25`, `MG16`, `BP77`/`BP56`
  (sash geometry echo, perturbable by a window manager), a whole-suite `NORESULT` from a WSLg
  Xwayland death (`X connection to :0 broken`), and a first-batched-attempt 400 s `TIMEOUT`
  of `test_key_graph_context` (ALL PASS in ~1 s standalone).
* Commit, **do not push**. This branch is already many commits ahead of `github/fluid-editing`
  and nothing in this batch has been pushed.

---

## Worth knowing

* Pre-existing, not merge-caused: `git diff --stat pre-open-pdk-merge-4 HEAD --
  tests/headless/run_suites.sh` is empty, and both readers are byte-identical across merge 4.
* The opposite-direction cost of the same disagreement is already visible at
  `tests/headless/test_statusmsg_hold_0248.tcl:22-23` — the convention gap costs
  registrations both ways.
* `xarm.sh` itself keys on **no** sentinel; `xarm.sh one` streams raw output with no verdict.
  Only `run_suites.sh` classifies. That is why the fix belongs there and nowhere else.
