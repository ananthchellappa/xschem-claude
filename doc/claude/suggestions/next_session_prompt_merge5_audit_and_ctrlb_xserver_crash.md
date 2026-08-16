# Next session — merge-5 full audit, and the Ctrl-B X-server crash

Two tasks. The second is the important one; the first is what tells you whether the
tree you are debugging is sound.

## Where the tree is

Merge 5 (`origin/fluid-editing` → `open_pdk`) landed. Branch `open_pdk`, three commits:

```
9be9c2d5  fix(merge5): the six clean auto-merges that were nonetheless wrong
7af2da9e  Merge origin/fluid-editing into open_pdk (merge 5)
c68f207b  docs(merge): the merge-5 analysis and resolution plan
1a45bc06  (pre-merge safety point)
```

569 files, +113154 / −1093. Nothing pushed. Local `fluid-editing` is still 150 behind
`origin/fluid-editing` and must be brought up with `git merge --ff-only`, never re-merged.

Read `doc/claude/suggestions/plan_merge5_fluid_into_open_pdk.md` first. It has the conflict
resolutions, the six post-merge repairs, and — in section 2 — the list of things already
proven clean, so you do not re-derive them.

**Already verified after the merge.** `./configure && make` clean; `vcd_read.o` compiled and
linked; headless binary starts; netlist golden gate 6/6; the CI headless gate 15/15 with zero
skips; `test_audit_classifier` 50/50; `test_cosim_golden_e2e` 15/15.

**Not verified.** Everything else — which is the whole of the merged signal-browser and
waveform-viewer work, roughly 240 test files under `tests/headless/`, none of which has been
run on this machine since the merge.

**This merge required `./configure`** (fluid changed `src/Makefile.in`). If you pull or rebase
onto anything, run it again before `make`.

---

## Task A — the full audit

Run the whole `tests/headless/` suite and triage what is red.

```sh
tests/headless/full_audit.sh                 # self-arms a private Xvfb (default since merge 5)
```

Notes that will save you an hour:

- The display arm is now chosen by `tests/headless/xvfb_arm.sh`. Default is a **private
  Xvfb**, so the suite no longer takes your screen. `AUDIT_DISPLAY=:0` forces the real screen,
  `AUDIT_DISPLAY=none` runs with no DISPLAY at all (GUI legs self-skip).
- The GUI control panel should therefore be **rare**. If it pops for a routine run, something
  bypassed `xvfb_arm.sh` — that is itself worth a look. When it does pop, press
  **`Allow 30m`** or **`Forever`** once. Do not press Proceed forty times.
- `run_suites.sh` is the gated driver for ad-hoc runs and soaks, and its skip predicate was
  repaired in `9be9c2d5` — a self-skip is not a pass, and the regexp is now line-anchored and
  asserted equal to `full_audit.sh`'s `is_skip` by check C44.
- `nogui_tests` in `full_audit.sh` is the **union** of both merge sides. `test_placement_wire_gate`
  in particular is `--nogui` by prescription: with any display it blocks forever at its G4
  `xschem place_text` row (measured — killed at 120 s under WSLg, still stalled at 300 s under
  xvfb-run). If you find yourself editing that list, read section 4.2 of the merge plan first.
- Reading results: a `FAIL` ending a line, `GOLD?`, `RESULT?` or a leading `FATAL` counts.
  `couldn't execute "xschem"` or `exit 127` anywhere means the binary never launched and
  nothing in that run is meaningful.

**What to expect.** A number of GUI/library-migration cases are environment-sensitive and are
deterministically red on GH runners; they are in the informational arm for that reason. The
question to answer is not "is everything green" but **"is anything red that is red *because of
the merge*"** — i.e. a suite from one branch failing on behaviour the other branch changed. The
merge plan's section 2 lists the cross-branch interactions already checked and cleared, so
concentrate on what is not on that list.

Triage each failure into: (a) pre-existing on one of the two parents — check it out and prove
it, (b) environment-sensitive, (c) genuinely caused by the merge. Only (c) is urgent.

---

## Task B — Ctrl-B crashes the X server on this PC

**This is the priority.** A client should never be able to crash an X server; that it can means
either a malformed request or a server bug, and either way real users hit it.

### The symptom

On this PC, pressing **Ctrl-B in the waveform viewer** — the Signal Browser toggle — kills the
X server outright. Not a Tcl error, not a client crash: the server dies and has to be
restarted manually.

### Why the environment matters

The merged signal-browser work was developed on a **different machine, under WSLg**, i.e.
against Xwayland — a modern X server (21.x-era) that is more permissive, clamps some
out-of-range values, and handles large drawables differently.

This PC runs **VcXsrv X Server 1.20.8.1 (7 Apr 2020)**, launched from a shortcut in the
Windows startup folder. That is X.Org server 1.20.8, roughly six years old at time of writing.
So the crash may well be an interaction that Xwayland silently tolerates and VcXsrv does not.

**Updating VcXsrv is worth doing** — 21.1.x is current and fixes a long list of server-side
crashes — but do it as a *second* step, and record the before/after. If updating makes the
crash disappear, that is a data point, not a fix: it tells you the request was legal-ish and
the old server mishandled it. If it persists, the request is malformed and it is our bug.
Either way, XSCHEM should not be able to kill an X server, and users on old servers exist.

### The code path

```
src/wave_viewer.tcl:13786-13787   bind WaveViewer <Control-Key-b> {wviewer::browser_toggle_at %W; break}
src/wave_viewer.tcl:12255         proc wviewer::browser_toggle_at {W}
src/wave_viewer.tcl:12202         proc wviewer::browser_toggle {{want {}} {token {}}}
```

The chord itself arrived in `08c37980` ("feat(wviewer): Signal Browser moves to Ctrl-B"), whose
message is worth reading — the bind was the easy half and it says so.

Two-pane browser construction, which is what `browser_toggle` actually builds:

```
src/wave_viewer.tcl:8098          ttk::panedwindow $f.pw -orient vertical
src/wave_viewer.tcl:8187          bind $f.pw.sea.c <Control-Button-1> ...
src/wave_viewer.tcl:8365-8378     the "sea of names" flow pane, and its -scrollregion
src/wave_viewer.tcl:7280-7324     browser_flow_layout / browser_flow_cell / browser_flow_scrollregion
src/wave_viewer.tcl:9439-9505     pane construction and the sash fraction
src/wave_viewer.tcl:11951         the grip frame that replaced a horizontal panedwindow (issue 0312)
```

### Hypotheses, strongest first

Each is stated with the measurement that would confirm or kill it. Do not assume the first one
is right because it is listed first — but it is the one I would test first.

1. **16-bit coordinate overflow in the flow pane's scrollregion.** X11 protocol coordinates and
   dimensions are signed 16-bit: valid range −32768..32767. `browser_flow_scrollregion`
   (`:7324`) returns `[list 0 0 [expr {$cols * $colw}] $paneh]`. The sea of names is
   **column-major**, so `cols` grows with the signal count. A raw/VCD database with enough
   signals makes `cols * colw` exceed 32767, and Tk will then issue drawing or window requests
   with out-of-range geometry. Modern servers clamp; a 2020 server may abort.
   **Measure:** open the same design, and before pressing Ctrl-B evaluate the actual numbers —
   print `cols`, `colw`, and the product for the database in question. If the product is over
   32767, this is almost certainly it. Cross-check by opening the browser on a *tiny* raw file
   (a handful of signals) and seeing whether the crash goes away.

2. **Treeview row count / item-id churn in the upper pane.** The `g:` / `s:` id prefixes are
   documented as load-bearing at `:7379` precisely because a duplicate id throws, and a throw
   there lands on the searchbar `<KeyRelease>` pump → `bgerror` → a modal dialog. That is a
   Tcl-level failure rather than a server crash, so it is a *different* bug — but it is close
   enough to the same code that you may find both.
   **Measure:** does the crash depend on the number of signals, or does it happen on any
   database at all?

3. **`ttk::panedwindow` sash geometry on an unmapped window.** `:9505` records that
   `winfo height` on an unmapped `ttk::panedwindow` is 1 and `sashpos 0` is unreliable, and
   `:12602` notes the split can only be applied to a *mapped* panedwindow. A sash position
   computed from a bogus height could produce a zero- or negative-dimension child window —
   `CreateWindow` with width or height 0 is a protocol error, and some servers handle it badly.
   **Measure:** does the crash still happen if the browser is opened when the viewer window is
   already large and mapped, versus immediately after the viewer opens?

4. **XRender / glyph handling.** If the browser uses a font or text drawing path the rest of
   the viewer does not, an old server's glyph cache is a classic crash site.
   **Measure:** `xdpyinfo -display <vcxsrv display>` and compare the extension list against
   Xwayland's. RENDER, MIT-SHM, BIG-REQUESTS and Composite are the ones that matter.

5. **MIT-SHM across the Windows/WSL boundary.** Shared memory pixmaps behave differently on
   VcXsrv than on a local server.
   **Measure:** VcXsrv's XLaunch has options here; also try `-nowgl` / disabling native OpenGL,
   which is a known source of VcXsrv instability.

### How to get evidence, not guesses

- **Get the server log.** VcXsrv accepts `-logfile <path>` and `-logverbose 3`. Launch it that
  way (edit the startup shortcut, or run it by hand for the session) and reproduce. The last
  lines before the death usually name the failing request or the fatal signal. **This is the
  single highest-value step** — without it every hypothesis above is speculation.
- **Trace the protocol.** If the log is unhelpful, `xtrace` (or `x11trace`) between client and
  server will show the last request issued before the server dies. Out-of-range geometry is
  visible immediately in that dump.
- **Bisect at the Tcl level.** `browser_toggle` builds a lot. Stub out the sea-of-names pane,
  then the treeview, then the sash restore, and see which one is load-bearing for the crash.
- **Confirm the asymmetry.** Reproduce (or fail to reproduce) the same action under the
  private Xvfb and, if you have access, under WSLg. "Crashes on VcXsrv, fine on Xwayland" is
  a much sharper problem statement than "crashes".

### Note on test coverage

Every signal-browser suite is headless:

```
test_wave_sigbrowser.tcl        test_wave_sigbrowser_2pane.tcl     test_wave_sigbrowser_i11.tcl
test_wave_sigbrowser_0312.tcl   test_wave_sigbrowser_digital.tcl   test_wave_sigbrowser_i12.tcl
test_wave_sigbrowser_0315.tcl   test_wave_sigbrowser_keys.tcl      test_wave_sigbrowser_i1315.tcl
test_wave_sigbrowser_0318.tcl   test_wave_sigbrowser_panes.tcl     test_wave_sigbrowser_i14.tcl
test_wave_sigbrowser_0319.tcl   test_wave_sigbrowser_sea.tcl
```

They exercise the view model, the row projection, the filters and the key routing — none of
them puts a real X server under load. So this crash is in a coverage hole **by construction**,
and no amount of green in Task A would have caught it. Whatever the root cause turns out to be,
part of the fix is a check that could have caught it: a geometry assertion on the computed
scrollregion is cheap and headless-testable, even if the crash itself is not.

---

## Housekeeping

- **New issues start at 0413.** The merged tree has 360 issue files; the highest number in use
  is 0412.
- Before touching anything that creates, moves, deletes or reroutes wires, read
  `doc/claude/WIRING.md`. Not expected here, but the rule stands.
- Do not run `make` while a subagent fan-out is live — this box OOMs at ~7.8 GB with ~10 agents
  up. Serialize.
- File the Ctrl-B crash as an issue as soon as you have the repro nailed down, even before the
  fix. The environment asymmetry (WSLg-developed, VcXsrv-crashing) belongs in the write-up —
  it is the most useful thing in it for whoever hits this next.

## Deliverables

1. Full-audit results, triaged into pre-existing / environment-sensitive / merge-caused, with
   the merge-caused ones fixed or filed.
2. A root cause for the Ctrl-B crash, backed by the VcXsrv log or a protocol trace — not a
   hypothesis, a measurement.
3. The fix, plus a headless check that would have caught it.
4. A verdict on whether updating VcXsrv to 21.1.x changes the behaviour, recorded either way.
