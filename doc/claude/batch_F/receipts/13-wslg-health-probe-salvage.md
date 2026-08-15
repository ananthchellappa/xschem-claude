# Batch F, item 13 — `wslg_health.sh` salvage: closer receipt

**Verdict [x].** 152/152 checks with a display, 135/135 without, 142/142 under a standing
PAUSE (zero windows). 24 sabotage rounds. Long form: `13-wslg-health-probe.md`; design and
the 12 rulings: `doc/claude/specs/wslg_health_probe.md`.

## 1. Files changed

```
doc/claude/batch_F/receipts/13-wslg-health-probe.md          |  444 ++ (new, long form)
doc/claude/batch_F/receipts/13-wslg-health-probe-salvage.md  |  120 ++ (new, this file)
doc/claude/specs/gui_test_gate.md                            |   41 +  (modified)
doc/claude/specs/wslg_health_probe.md                        |  358 ++ (new)
tests/headless/test_wslg_health.sh                           | 1074 ++ (new)
tests/headless/wslg_health.sh                                |  774 ++ (new)
```
No `make`: nothing under `src/`. Probe md5 `699ed70ee8c2e51146b3cb8ff3ef839d`, test
md5 `c088e3dd36491b85ada066a95f7a3a80` — the files the green runs used. **Salvaged** from
the halted attempt (which left both `.sh` files and the `gui_test_gate.md` edit
uncommitted): the five measured checks and their thresholds, the socket-vs-timeout
discriminator, the sourcing guard, the PATH-shim E2E arm, the 0310 paragraph.
**Rewritten**: the gate-obedience path (absent), the live arm (four probe runs →
one), and `wh_check_placement`, which returned 0 — a silent pass — when the probe
produced no coordinates, so "it never ran" verdicted HEALTHY (the halted tree was
red on DH16/DH19e because of it).

## 2. Decisions and evidence

The probe reads `$GUI_GATE_DIR/control` (default `~/.claude/gui_test_gate/control`)
before mapping: STOP → exit 4, PAUSE → bounded hold then exit 5, RUN/missing/
unreadable → proceed. Twelve rulings are written into
`doc/claude/specs/wslg_health_probe.md` §Rulings; 6–12 are the crew's:

**6** "not measured" gets codes 4/5, never folded into UNHEALTHY 1 — "I did not
look" is not "the display is broken" (DH50/51/57). **7** obey by *reading one file*,
never by sourcing `gui_gate.sh`, circular for a preflight meant to run inside
`gate_start`; read-only (DH34/58). **8** `GUI_GATE=0` does **not** exempt it: that
variable governs *asking*, while PAUSE/STOP is a standing order from a user at the
keyboard (DH56). **9** the hold is bounded *and* the bound reports DEFERRED, never
proceeds (DH51). **10** the consult belongs **inside** the best-of-3 retry loop — with
it outside, a button pressed at window 1 got two more windows and a health verdict
(DH62/63, against the control DH64). **11** "no server there" is decided **before** the
consult: holding for a display with nothing behind it invented a 30 s hold and dragged
unrelated checks red under a PAUSE (DH67). **12** a malformed `WSLG_HEALTH_GATE_WAIT`
is never a broken display — `2.5` aborted bash in `$(( ))` *while holding*, printing no
VERDICT, exit 1 (DH65/66). **1–5** geometry FLOOR not equality; placement TOLERANCE
64 px; uptime and fatal-count as information only; a fourth code UNKNOWN 3;
socket-not-timeout — carried by DH02–05, DH11/12, DH24, DH16/19e, DH32/33.

**Windows counted, not asserted** (Amendment 2): a `wish` logger at the *back* of
`$PATH` — the test prepends its own shims, so a launch reaching it is real. **One per
live run** (two when the WM ignores the request and the probe retries); v2 shipped
three, one `$HOME`-redirected and therefore ungated. Closer's cost: **2**. **DH22d**
witnesses the measurement independently with `xwininfo -root -tree` from the shell
side — without it, a `PROBE_TCL` echoing the *request* back as the measurement passed
all 130 v2 checks. `gui_test_gate.md` gains the rule that anything painting on the
user's screen answers the panel, preflight included, and that `gate_start` *clears* a
standing STOP while the probe *refuses* on one. Wiring into `gate_start` / `full_audit`
ENVBAD is out of scope; 0310 OPEN.

## 3. Suites and verbatim RESULT lines

`tests/headless/test_wslg_health.sh`, checks `DH01`–`DH67`, re-run by the closer:
```
RESULT fails=0 checks=152      # GUI_GATE=1 DISPLAY=:0    (1 real probe window)
RESULT fails=0 checks=135      # env -u DISPLAY GUI_GATE=1 (0 windows)
```
The probe itself: `VERDICT: HEALTHY  display=:0  root=5120x1440  no parked windows
probe want +200+200 got +206+227 screen 5120x1440`, exit 0. **Not CI-backed**:
`run_suites.sh` resolves names to `<name>.tcl` and `full_audit.sh:137` globs
`test_*.tcl`, so neither reaches a `.sh` suite — hand-run, like `test_gui_gate_revive.sh`.

## 4. Sabotage table

Each restored from a byte-exact backup and re-run green; rounds 1–18, 21 ran with `DISPLAY` unset and mapped nothing.

| # | broken | went red |
|---|--------|----------|
| 1 | geometry floor raised to 8192x4096 | DH03,04,05,18x3,19e,19f,41x3,25,42,44,45,52,53,54,54b,55,57,61 |
| 2 | sentinel match neutered | DH08x2,10d,10f,17,19c,40x2,42x2,44 |
| 3,4 | placement comparison neutered / `timeout` dropped from `xdpyinfo` | DH11,15,17,19a,40 · DH33x3 |
| 5,6 | probe ignores PAUSE / second consult removed | DH51x4,52,57,59x3 · DH59x3,60x2 |
| 7,8 | STOP not obeyed / PAUSE bound removed | DH50x3,56x2,57,60x2 · DH51x4,59x2 |
| 9,10,11 | entry-point guard removed / usage error returns 2 / socket discriminator removed | DH01x2 · DH35 · DH32 |
| 12,13 | consult moved outside the retry loop / `WSLG_HEALTH_GATE_WAIT` validation removed | DH62x3,63x2 · DH65x3,66x2 |
| 14 | NODISPLAY exit moved behind the consult | DH67x3 |
| 15,16,17 | gate dir written into / created when missing / stops following `$HOME` (writes scoped to `/tmp/*`) | DH58,34b · DH34 · DH34c x2 |
| 18 | panel shields removed, whole file under a PAUSE | DH28,43x2 |
| 19,20 | `PROBE_TCL` echoes the request as the measurement / a live-arm `ck` call deleted (live) | DH22d · DH29 |
| 21 | best-of-N retry removed | DH64,45x3,45b,62x2,63 |
| 22 | `[STUB]` label stops naming the check, forced floor (live) | DH22b + geometry family |
| 23,24 | probe window title changed / probe leaks its window (live) | DH22c · DH27 |
| — | `-q` prints the detail too | DH25 |

**Unsabotaged, therefore not evidence on their own** (27 of 84 ids): DH06, DH07, DH09,
DH10, DH10b, DH10c, DH10e, DH12, DH13, DH14, DH16, DH19, DH19b, DH19d, DH20, DH21,
DH22, DH22a, DH24, DH26, DH30, DH31, DH35b–DH35e, DH36 — all boundary or
positive-control siblings of a sabotaged family (DH16/DH19e were red on the halted
tree before the placement bug was fixed).

## 5. NOT verified

* **THE AUDIT WAS NOT RUN.** `doc/claude/batch_F/baseline_status.txt` **exists**
  (baseline 7a592f9c) and was **not** re-diffed, on the item brief's explicit
  instruction — another Claude session is on this machine. **Treat it as UNVERIFIED, not
  green.** Support: `full_audit.sh:137` globs `test_*.tcl`, nothing in `tests/` refers to
  `wslg_health`, and no C, Tcl, existing-test or build file was touched.
* **The real panel never held the probe** — proving it means writing PAUSE/STOP into
  `~/.claude/gui_test_gate/`, forbidden and the user's own authority. Obedience is
  proved against a private `$GUI_GATE_DIR` with a wish call-counter; the user's
  control file is untouched (`RUN`, mtime 12:56). **No stub display exists** either,
  so every stub judgement runs on recorded 2026-08-10 values.
* **Raised, not acted on**: DH55 duplicates DH54 (its "unreadable" fixture makes
  `control` a directory, caught by the same `[ -f ]` branch); `gate_start` clears a
  standing STOP while the probe refuses on one (now in the gate spec); a newline-
  terminated control file is stripped but exercised by no fixture. The 142-check
  PAUSE run is the fixer's, against byte-identical files.
* **Eyeball owed: none** — the payload is a script and its exit codes, not pixels. Worth
  one human run of `tests/headless/wslg_health.sh` after the next Xwayland abort: the
  one condition nobody here could stage.
