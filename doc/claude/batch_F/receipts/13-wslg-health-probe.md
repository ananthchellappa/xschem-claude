# Batch F, item 13 — `wslg_health.sh` SALVAGE: finish the probe, and make it obey Pause/Stop

> **v2.1 (fixer round, 2026-08-11).** The review found a **blocker** and three
> majors in v2, all confirmed and all fixed. **The header numbers below are v2's
> and are superseded — including the window count, which was wrong.** Read
> "Review round (v2.1)" at the end of this receipt for the current picture:
> **152/152 checks with a display, 135/135 without, 20 sabotage rounds**, and a
> **measured** window count.

**Verdict (v2.1): [x]** — 152/152 checks green with a display, 135/135 without,
and **142/142 green with a standing PAUSE** (live arm reporting a partial run,
zero windows). Nine sabotage rounds this round (12–20), each driving a named
check red, each reverted from a byte-exact backup and re-run green.

**Probe windows mapped: ONE per live run of the self-test** — measured, not
asserted, with a `wish` logger at the back of `$PATH` (the test prepends its own
shims, so a launch reaching the logger is one nothing intercepted). Two when the
WM hiccups and the probe retries. **v2's claim of "four in the whole pass" was
wrong: v2's file mapped THREE per run**, one of them ungated (see below).
**Total for this fixer round: ~17 windows across 14 live runs** — 2 witness
experiments (the first lost its output to a shell mistake), 8 live suite runs and
4 live sabotage rounds; the logger measured 1 real window in most and 2 in four
of them, because the WM ignored the requested position and the probe retried (the
recorded 1-in-15 hiccup ran well above its rate today). Every headless suite run,
every headless sabotage round and the standing-PAUSE run mapped **zero**. Every headless suite run, every headless sabotage round (12–17) and the
standing-PAUSE run mapped **zero**.

--- v2's original header follows ---

**Verdict: [x]** — 130/130 checks green with a display, 115/115 without, and
**11 sabotages** each driving a named check red, each reverted from a byte-exact
backup (md5 `b87612002b64976ab626e9422bf6a93a`) and re-run green.

Branch `fluid-editing`, on top of `c2d775ef`. **Tree left DIRTY for the verifier —
nothing staged, nothing committed, nothing pushed.**

## The retraction this pass implements

Item 13's first attempt was stopped by the driver mid-verification because of a
design fault in the original brief, now retracted: the probe was told **not** to
depend on the GUI-test gate. But check 5 maps a real window on the user's screen,
so under the sabotage harness dozens of little windows flashed past — and when
the user pressed **Pause on the control panel, nothing stopped**. The probe never
consulted it.

Both amendments are implemented:

1. **The probe now obeys Pause and Stop before it maps anything.**
2. **One window, not a dozen**: the live arm is derived from a *single* probe
   run, and the stub-detection sabotages drive the decision logic with recorded
   values, needing no window at all.

## Files

| file | state |
|------|-------|
| `tests/headless/wslg_health.sh` | **NEW** (salvaged + finished) — the probe |
| `tests/headless/test_wslg_health.sh` | **NEW** (salvaged + restructured) — its self-test, **152 checks (v2.1)**, band `DH01`–`DH67` |
| `doc/claude/specs/wslg_health_probe.md` | **NEW** (salvaged + rewritten to v2, updated to **v2.1**) — spec, **12 rulings**, sabotage table |
| `doc/claude/specs/gui_test_gate.md` | **MODIFIED, +14 then +19 lines** — 0310's "liveness is not visibility" paragraph, plus the new rule that a preflight which paints on the screen answers the panel |

No C changed, no existing test changed, no `Makefile*` changed.

### Salvaged vs rewritten

The halted attempt left ~1200 lines in the tree, uncommitted and unreviewed. It
was read in full before anything was touched, and **not** thrown away.

**Salvaged as-is** (sound, and backed by measurements taken on the two real
machines — a stub cannot be summoned to order, so this evidence is not
reproducible on demand and discarding it would have been expensive):

* the five checks and their thresholds — the geometry **floor** (not equality
  against 640x480, because this root legitimately alternates 5120x1440 and
  2560x1440), the placement **tolerance** (a WM decoration offset of 6,27 is
  correct), uptime and the fatal count as `[info]` only;
* the **two-sample** sentinel rule and the magnitude match. Both are measured
  corrections to the naive `grep -- '+-327'` in issue 0310: a healthy display
  shows a transient WM pre-placement frame at exactly `+-32768+-32768` while any
  window is mapping, and `900x700+-327+140` is an ordinary window overhanging the
  left edge of a 5120-wide desktop;
* the socket-vs-timeout discriminator that tells *absent* from *wedged*;
* the guarded entry point (`[ "${BASH_SOURCE[0]}" = "$0" ]`) that makes the
  judgement sourceable, and the PATH-shim E2E arm that ties reported numbers to
  what X actually said;
* the DECISION / SAFETY / E2E arms, and the best-of-3 probe retry.

**Fixed** — a real bug the interrupted author had not finished:
`wh_check_placement` returned **0** (a silent pass) when the probe produced no
coordinates, so "everything fine but the decisive check never ran" verdicted
HEALTHY. That is precisely the silent downgrade the script exists to prevent, and
the file's own spec ruling 4 said it should be UNKNOWN. It now returns 3.
**The halted tree was RED on this**: `DH16` and `DH19e` were failing (`fails=2`)
when this pass picked it up.

**Rewritten:**

* the whole **GATE arm** (DH50–DH61) and the gate code in the probe — new;
* the **LIVE arm**, which started **four** separate probe runs (each retrying up
  to three times, so up to a dozen windows per pass) and now derives every check
  from **one**. `-q` moved to the shim; `DH27` (window gone afterwards) now
  asserts against the same single run rather than starting another; `DH22b`
  (the mapped window is caught in the tree) folded into it;
* `DH57`'s first check, which was **hollow** — it compared four literals
  (`printf '%s\n' 0 1 4 5 | sort -u | wc -l` is 4 no matter what the code does).
  It now compares the four exit codes actually observed in that run;
* the spec, to v2.

## Amendment 1 — the probe obeys Pause and Stop

Before mapping anything it **reads** `$GUI_GATE_DIR/control` (default
`~/.claude/gui_test_gate/control`):

| control | behaviour |
|---------|-----------|
| `STOP` | maps nothing, `VERDICT: STOPPED`, **exit 4** |
| `PAUSE` | holds, polling, up to a bounded overall wait (default 300 s); still paused at the bound → maps nothing, `VERDICT: DEFERRED`, **exit 5**. A Resume during the hold lets it run |
| `RUN` / missing / unreadable / anything else | proceeds. **Fails open**, like the rest of the gate |

Consulted **twice**: at the top (a STOP then costs no X call at all) and
**immediately before the Tk probe** — the only statement that maps a window. The
second consult is the load-bearing one: a Pause pressed while `xdpyinfo` and the
two `xwininfo` calls run would otherwise still be followed by a window. Both
consults share one deadline, so consulting twice cannot double the bound.

As instructed: it **reads the file** and does **not** source `gui_gate.sh` (the
probe is meant to become a preflight inside `gate_start`; sourcing the gate from
something the gate calls is a circular dependency). It **never writes** into the
gate dir — DH58 pins names, sizes and mtimes unchanged across a run.

## Rulings made this pass (no human to ask; rationale in the spec, §Rulings 6–9)

6. **"Not measured" gets exit codes of its own — STOPPED 4, DEFERRED 5 — never
   folded into UNHEALTHY 1.** "I did not look" is not "the display is broken",
   and a caller that cannot tell those from healthy is back to guessing, which is
   the disease. Evidence: DH50, DH51, DH57 (all four codes observed distinct in
   one run).
7. **Obedience by reading one file, never by sourcing the gate; read-only.**
   Evidence: DH58, and the circularity argument above.
8. **`GUI_GATE=0` does NOT exempt the probe from Pause/Stop.** That variable
   means "do not stop to ask permission" — it is about the *asking*. PAUSE/STOP
   is not a question; it is a standing order from a user at the keyboard who has
   already pressed a button. Honouring the gate only when the gate is enabled
   would hand every future agent a one-word way to flash windows at a user who
   asked for none. Evidence: DH56.
9. **The PAUSE hold is bounded, and the bound reports DEFERRED rather than
   proceeding.** A forgotten Pause must not hang a suite all day; equally, timing
   out must not be a licence to map the window after all, or the bound would just
   be a slow way of ignoring the button. Evidence: DH51 + sabotage 8.

(Rulings 1–5 — floor not equality, tolerance not equality, info-not-gate, the
UNKNOWN code, socket-not-timeout — are salvaged from the first attempt and
restated in the spec.)

## Evidence

`tests/headless/test_wslg_health.sh` — **130 checks, `RESULT fails=0`** with
`$DISPLAY` set; **115 checks, fails=0** with it unset (the live arm is the
difference). Band `DH` re-measured this pass by grepping
`tests/headless/*.tcl` and `*.sh`: no `.tcl` suite uses a `DH` id (nearest
neighbours `HW`, `WH`, `DC`, `DG`, `DM`, `DR`, `DS`, `DT`, `DV` are taken), and
`DH01`–`DH45` were this file's own from the halted attempt, so the new arm took
**DH50–DH61**. No existing check was renumbered or deleted.

Live verdict from the probe itself, this session:

```
VERDICT: HEALTHY  display=:0  root=5120x1440  no parked windows  probe want +200+200 got +206+227 screen 5120x1440
  [ok  ] server answers     xdpyinfo :0 replied in 0s
  [ok  ] root geometry      5120x1440  (floor 1024x768)
  [ok  ] parked windows     none (no window with |x| or |y| > 30000 in either sample of the window tree)
  [ok  ] window placement   want +200+200 got +206+227  (offset 6,27 px, WM decoration, tolerance 64)
  [ok  ] probe screen size  5120x1440  (floor 1024x768)
  [info] server started     2026-08-11 11:30:30  (6509s ago, from /tmp/.X11-unix/X0 -- the socket is recreated on every respawn)
  [info] Fatal server error 14 so far in /mnt/wslg/stderr.log (a rising count predicts more panel deaths; it does not make the results in hand wrong)
```

`+206+227` is exactly the value the driver recorded at launch; the live arm also
asks for an **arbitrary** `+437+311` and got `+443+338`, which a hardcoded
`+206+227` could not have produced.

### Sabotage table — every check earns its keep

All eight run with `DISPLAY` unset (**zero windows mapped**); 115 of the 130
checks are display-independent.

| # | sabotage | checks that went red |
|---|----------|----------------------|
| 1 | floor raised to 8192x4096 | **22**: DH03, DH04, DH05, DH18 x3, DH19e, DH19f, DH41 x3, DH25, DH42, DH44, DH45, DH52, DH53, DH54, DH54b, DH55, DH57, DH61 |
| 2 | sentinel match neutered (`if (0)` in `wh_sentinel_ids`) | **11**: DH08 x2, DH10d, DH10f, DH17, DH19c, DH40 x2, DH42 x2, DH44 |
| 3 | placement comparison neutered (`if false`) | **5**: DH11, DH15, DH17, DH19a, DH40 |
| 4 | `timeout` dropped from the `xdpyinfo` call | **3**: DH33 x3 — the run hit the test's own 25 s outer limit (rc 124) instead of the 2 s inner one |
| 5 | **the probe ignores PAUSE** | **9**: DH51 x4 (incl. "the shim's wish was never called"), DH52, DH57, DH59 x3 |
| 6 | **the second consult removed** (panel read only at startup) | **5**: DH59 x3, DH60 x2 — DH50/DH51 stay green, which is the point: this sabotage is invisible to a test that only checks the startup read |
| 7 | **STOP not obeyed** (`wh_gate_state` maps STOP→RUN) | **8**: DH50 x3, DH56 x2, DH57, DH60 x2 |
| 8 | **the PAUSE bound removed** (deadline `now + 100000`) | **6**: DH51 x4, DH59 x2 — the held run hung into the harness's own 60 s limit and returned rc 124 instead of 5 |

Every one restored from the byte-exact backup (`md5sum` re-verified as
`b87612002b64976ab626e9422bf6a93a` after each), suite re-run green.

Sabotage 8 is worth reading twice: DH51's *"nothing was mapped"* leg stayed
**green** under it, because the probe was killed by the outer timeout before it
could reach `wish`. Obedience and boundedness are genuinely two properties, and
they need the two separate checks they have.

Three more rounds inherited from the halted attempt were **re-run against this
file rather than taken on trust**, since the file has changed:

| # | sabotage | checks that went red |
|---|----------|----------------------|
| 9 | the entry-point guard removed | **2**: DH01 x2 — and the run stops there with `checks=2`, which is the guard check doing its job (an unguarded script ends `wh_main "$@"; exit $?`, and a sourced `exit` kills the caller) |
| 10 | usage error made to `return 2` | **1**: DH35 |
| 11 | the socket discriminator removed (`if false`) | **1**: DH32 — an unused display number reported as a fault |

**A check found hollow and replaced, as required:** `DH57`'s first leg compared
four literals and could never go red. It now compares the four exit codes
*observed in that same run* (`$grc` healthy, `$src` stub, `$stoprc`, `$defrc`) —
fold any pair together and it reads 3. Sabotages 5 and 7 both drive it red.

## Not done, deliberately

* **NO AUDIT DIFF** — the brief instructs skipping it, and another Claude session
  is working on this machine, so a full audit would be antisocial. It would also
  be uninformative: `full_audit.sh:137` globs `test_*.tcl`, both new files are
  `.sh`, no C / Tcl / existing test / build file changed, so the audit's file set
  and its inputs are byte-identical to before this item.
  `doc/claude/batch_F/baseline_status.txt` **exists** but was not re-diffed;
  treat the audit as **not run**, not as green.
* **NO `make`** — nothing under `src/` changed, and another session is building.
* **No suite run through `run_suites.sh`** — it resolves every name to `<name>.tcl`
  (`run_suites.sh:57-62`) and `full_audit.sh` globs `test_*.tcl`
  (`full_audit.sh:137`), so neither can drive a `.sh` self-test. This file is
  hand-run, exactly like its neighbours `test_gui_gate_revive.sh` and
  `test_gui_gate_batch.sh`, and its green result is not CI-backed.
* **The panel was never launched, killed, re-armed or written to.** `GUI_GATE=0`
  was never set (it is now explicitly *not* an exemption — ruling 8). No Xvfb, no
  `xvfb-run`, no `wsl --shutdown`, no second display: stub detection is driven
  entirely by recorded values.
* **The live control file was never set to PAUSE or STOP to demonstrate the
  feature.** That would mean writing into `~/.claude/gui_test_gate/`, which is
  forbidden and is the user's own authority. The button is proved under a private
  gate dir in `$TMP` (DH50–DH61), where the shim's `wish` call count is the
  evidence.
* **Issue 0310 was NOT edited** — it is untracked and was already dirty before
  this item; policy forbids staging such a file. It stays OPEN.
* **Wiring into `gate_start` and `full_audit.sh` remains OUT OF SCOPE**, as
  instructed. See the spec's "What remains".

## What remains for the next session

1. **`gate_start` / `_gate_ensure_widget` preflight**: run the probe before
   launching the panel; log `panel launched onto a stub display` instead of a
   healthy-looking launch. Ruling 7 (read the file, do not source the gate)
   exists precisely so this is safe.
2. **`full_audit.sh` preflight**: abort with a distinct **`ENVBAD`** status,
   printed once and loudly — not `SKIP` (scored file-wide at `full_audit.sh:128`
   and silently discarded) and not `FAIL` (reads as a code regression).
   **Only exit 1 means ENVBAD**: exits 4 and 5 mean the user stopped or paused
   the probe, which must not abort a run on the display's behalf.
3. Close 0310 only when both are in.

**Hazard for whoever does it:** the probe maps a real top-level for ~0.3 s.
Harmless as a manual command; inside a per-test pause point it could take focus
from an xschem window a test is driving with `event generate` — the same trap
that made the v6 reborn panel deliberately SILENT. Preflight only, never
`gate_pause_point`.

## Eyeball

**Not required for the verdict.** The deliverable is terminal text and exit
codes, reproduced above and asserted headlessly.

Optional, 60 seconds, if someone wants it — and this is the one thing no check
can confirm, because proving it means pressing the real button:

1. Run `tests/headless/wslg_health.sh`. One small window should appear near the
   top-left for a third of a second, and the verdict should read sensibly at a
   glance.
2. Press **Pause** on the control panel, then run it again. **No window should
   appear at all**; after a few minutes it prints `VERDICT: DEFERRED`. Press
   Resume and it measures normally. (Ctrl-C is fine; the probe writes nothing.)

---

# Review round (v2.1) — the confirmed findings, fixed

Three reviewers drove the delivered v2 with shims rather than trusting the
receipt. Everything below was re-measured on the fixed files; nothing was taken
on trust, and one finding turned out to have a second, deeper cause than the one
reported (see F3).

## F1 (BLOCKER) — the retry loop mapped windows after Stop or Pause

`wslg_health.sh`: the consult sat **outside** the best-of-3 probe loop, so only
the FIRST window was gated. With the button pressed the instant probe window 1
appeared, the probe mapped **two more** and reported a health verdict (exit 1)
instead of STOPPED/DEFERRED — and it did that hardest on the very display the
script exists to detect, because a stub misplaces *every* attempt and so always
takes all three.

**Fix:** the consult moved to the **top of the loop**, one per attempt, sharing
the one `WH_GATE_DEADLINE` so repeated consults cannot multiply the bound.
**New checks DH62/DH63** (shim `wish` counts calls, presses the button on call 1,
and returns a misplaced window so the loop wants to retry): exactly **one** call
and exit 4/5. **DH64** is the control — nobody pressing, same misplacing shim,
all three attempts taken and exit 1. Ruling 10 in the spec.

## F2 (MAJOR) — the self-test mapped an UNGATED window on the real display

`test_wslg_health.sh:421` ran `HOME="$fakehome" "$PROBE"` with `GUI_GATE_DIR`
unset, so the probe resolved its control file under `$fakehome`, failed open, and
mapped a real top-level whatever the user's own panel said: **one ungated window
per run of the file whose subject is that windows are gated.** DH31 mapped a
second one, purely to grep for substrings.

**Fix:** a `$NOWIN` shim that fakes **only** `wish` (so `xdpyinfo`/`xwininfo`
still answer from the real display) — DH31's live invocation runs under it and
maps nothing. DH34/DH34b moved into the GATE arm, where the full shim exists, and
now assert *more* than before: **DH34** (a `$HOME` with no `.claude` stays that
way), **DH34b** (a `$HOME` that *has* one has it read, not written — names, sizes
and mtimes unchanged), **DH34c** (STOP in the `$HOME`-derived control file really
stops it, so DH34b cannot pass on a probe that ignores `$HOME`).

**Measured, with a `wish` logger behind every shim on `$PATH`:** v2 = 3 real
launches per run; v2.1 = **1** (the live arm's own), 0 under a standing PAUSE.

## F3 (MAJOR) — the decisive measurement had no falsifying check

A `PROBE_TCL` that dropped `winfo rootx/rooty` and echoed the REQUEST back as the
measurement passed all 130 of v2's checks (`got == want` satisfies DH22b by
construction). **Fix: DH22d, an independent witness** — while the probe holds its
window, the test reads the position from the shell side with a *different tool*
(`xwininfo -root -tree`, last field = absolute position) and requires the probe's
number to match a number it did not produce. Sabotage 19 drives it red.

Two traps found while building it, both measured, both now handled by keeping the
**last settled** reading rather than the first:

* the window appears in the tree at the WM's **pre-placement frame**
  (`+-32730+-32709` — byte-identical to the recorded stub value) before it lands;
* **the probe may retry**, and then the first settled window is not the one it
  reports. Measured live: attempt 1 at `+6+27` (the documented WM hiccup),
  attempt 2 at `+443+338`; the first version of DH22d compared two *different*
  windows and went red on a display that was fine. Caught here, not in the field.

Second hole in the same finding: DH22b could **vanish silently** (asserted only
inside `if verdict = HEALTHY`). Fixed two ways — the non-healthy branch now
counts a check of its own (the verdict must name the check behind it), and
**DH29 asserts the live arm's check count** (10 measuring / 0 partial-run).
Sabotage 20 deletes a live-arm check and DH29 is the only red.

## F4 (MAJOR) — a Pause turned the suite red instead of holding it

With the panel actually PAUSED, v2's file came back `fails=3` with an unrelated
fail set (DH28, DH43 x2) and **nine checks silently gone**, while the live arm
was SIGKILLed by its own `timeout 90` before the 300 s bound and printed no
verdict at all.

**Fix:** every invocation that is *not* about the panel is shielded with a
private empty gate dir (DH26, DH28, DH31's three, DH43's `zout`), and the live
arm gets `WSLG_HEALTH_GATE_WAIT=20`, comfortably inside its own `timeout 90`.
**Measured on the fixed file with a standing PAUSE (a private gate dir — the
user's own panel was never touched): `RESULT fails=0 checks=142`,** live arm
`VERDICT: DEFERRED`, DH29 asserting that nothing was measured, **zero** windows
mapped. Sabotage 18 removes the shields and reproduces the reviewer's exact fail
set.

## F5 (MINOR) — a tunable typo was reported as a broken display

`WSLG_HEALTH_GATE_WAIT=2.5` aborted bash in `$(( ))` **while holding**: no
VERDICT line and exit 1, which every caller reads as "stub display, GUI results
are meaningless". **Fix:** a fractional bound is truncated, a nonsensical one
falls back to the 300 s default, and the substitution is announced on stderr.
**DH65** (2.5 → DEFERRED, exit 5, no syntax error) and **DH66** (`soon` → still
holding at 5 s, warning printed). Ruling 12.

## F6 (MINOR) — it deferred on a display that has no server

The consult came before the socket check, so a display number with nothing behind
it held for the full bound and reported DEFERRED — a hold with no screen behind
it, and the root cause of two of F4's collateral reds. **Fix:** the no-socket
NODISPLAY exit now precedes the first consult. **DH67**: paused panel, `:9` with
no socket → exit 2 in 0 s, not a 30 s hold. Ruling 11.

## F7 (MINOR) — the receipt's window count

Corrected in the header, and reduced for real (F2). The number is now **measured**
rather than reasoned about.

## Sabotage table (v2.1 rounds; 12–17 headless, 18–20 live)

| # | sabotage | reds |
|---|----------|------|
| 12 | the consult moved back OUTSIDE the retry loop | **5**: DH62 x3, DH63 x2 — 3 `wish` calls, exit 1. DH50/DH51/DH59/DH60 stayed green, which is why DH62/63 exist |
| 13 | the `WSLG_HEALTH_GATE_WAIT` validation removed | **5**: DH65 x3 (bash syntax error, no VERDICT, exit 1), DH66 x2 |
| 14 | the no-socket NODISPLAY exit moved back behind the consult | **3**: DH67 x3 (held the full 30 s, reported DEFERRED) |
| 15 | `wh_gate_state` writes a file into the gate dir it read | **2**: DH58, DH34b |
| 16 | `wh_gate_state` creates the gate dir it did not find | **1**: DH34 |
| 17 | the gate dir stops following `$HOME` | **2**: DH34c x2 |
| 18 | the four panel shields removed, run under a standing PAUSE | **3**: DH28, DH43 x2 — the reviewer's exact set. DH26/DH31 stayed green *because of* the F6 fix |
| 19 | `PROBE_TCL` echoes the REQUEST back as the measurement | **1**: DH22d — the fabrication that survived all 130 of v2's checks |
| 20 | a live-arm check (DH24) quietly deleted from the test | **1**: DH29 (`got 9 want 10`) |
| 21 | the best-of-N retry removed (`break` unconditionally) | **8**: DH64, DH45 x3, DH45b, DH62 x2, DH63 — DH64 is the control that stops DH62/63 measuring a dead probe, so it needed its own red |
| 22 | the `[STUB]` detail label stops naming the check, run with an artificial floor so the live verdict is UNHEALTHY | **DH22b's non-healthy branch** (plus heavy, explainable collateral across the geometry family: DH02–DH05, DH17, DH18 x2, DH19e, DH19f, DH23, DH40, DH42, DH44) — the one live branch that a healthy desktop never exercises |

Sabotages 15 and 16 were **scoped to `/tmp/*` gate dirs** so the user's real
`~/.claude/gui_test_gate` could never be written; verified afterwards that it
contains no stray file and that `control` is still `RUN` with its original mtime.

## Raised but NOT confirmed / not acted on

* **DH55 duplicates DH54** (the "unreadable control file" fixture makes `control`
  a directory, which fails the same `[ -f ]` test as "missing"). Reported by the
  v2 verifier as a coverage note, not a defect, and left alone: the read-failure
  path it nominally covers is unreachable from the shell, and inventing a
  fixture for it would be theatre.
* **`gate_start` clears a standing STOP, the probe refuses on one.** An
  observation for whoever wires the preflight in, not a defect here; now written
  into `doc/claude/specs/gui_test_gate.md` so the order gets decided
  deliberately.

## Suites, and the audit

```
GUI_GATE=1 tests/headless/test_wslg_health.sh          -> RESULT fails=0 checks=152   (1 real window)
env -u DISPLAY GUI_GATE=1 tests/headless/test_wslg_health.sh -> RESULT fails=0 checks=135   (0 windows)
GUI_GATE_DIR=<private dir holding PAUSE> GUI_GATE=1 tests/headless/test_wslg_health.sh
                                                      -> RESULT fails=0 checks=142   (0 windows, live arm DEFERRED)
GUI_GATE=1 tests/headless/run_suites.sh test_wslg_health
                                                      -> FATAL: no such test file: .../test_wslg_health.tcl
```

`run_suites.sh` resolves every name to `<name>.tcl` and `full_audit.sh` globs
`test_*.tcl`, so **neither can reach a `.sh` suite** — this file is hand-run, like
`test_gui_gate_revive.sh` and `test_gui_gate_batch.sh`, and its green is not
CI-backed.

**No `make`** (nothing in `src/` changed; another Claude session is on this
machine and CPU load flakes the headless suites). **No `full_audit` diff**: the
item brief instructed this item to skip it as antisocial and uninformative, and
the input set is provably unchanged — the two files are `.sh`, which no runner
globs, and no C, Tcl, existing test or build file was touched.
`doc/claude/batch_F/baseline_status.txt` **exists** but was not re-run, so **the
audit is UNVERIFIED for this item, not green**.
