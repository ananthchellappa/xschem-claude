# Session prompt — 0193: the `<MouseWheel>` / `%D` path has ZERO test legs

*Written 2026-08-01, at the close of the overnight waveform batch
(`doc/claude/overnight_batch_2026_08_01/`). Items 04 (issue 0191) and 03 (0190)
both route through this path and both shipped `[x]` with it untested; the gap was
recorded in `0191` §4b rather than closed. Paste the block below into a fresh
session.*

---

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Close issue **0193**: the `<MouseWheel>` / `%D` wheel-arrival path is matched by
**zero** test legs, on any surface, anywhere in the tree.

## THE GAP, MEASURED (re-verify, do not trust)

`grep -rn 'MouseWheel' tests/headless/*.tcl` returns exactly **one** file and it
is not an exercise: `test_wave_viewer.tcl:493` lists `<MouseWheel>`,
`<Shift-MouseWheel>` and `<Control-MouseWheel>` in **G1s's hardcoded allow-list**
of surviving canvas bind sequences. G1s asserts the bindings *exist and that
nothing strays outside the set*. **No leg in the tree ever generates one**, so
nothing asserts what any of them DO.

Every wheel leg that exists synthesises the X11 form — Tk `<Button-4>` /
`<Button-5>`, or `xschem callback <w> 4 <x> <y> ... 4|5 ...`.

Anchors (verify from source; line numbers drift):

| file:line | what |
|---|---|
| `src/wave_viewer.tcl:6985-6990` | six X11 binds: `<Button-4/5>`, `<Shift-Button-4/5>`, `<Control-Button-4/5>` → `wviewer::wheel_bind %W up\|down 0\|shift\|ctrl %x %y; break` — **covered** |
| `src/wave_viewer.tcl:6994-6996` | three portability binds: `<MouseWheel>`, `<Shift-MouseWheel>`, `<Control-MouseWheel>` → `wviewer::wheel_bind %W [expr {%D > 0 ? "up" : "down"}] <mods> %x %y; break` — **UNCOVERED** |
| `src/wave_viewer.tcl:6979-6993` | the comment block explaining the split, incl. "Overwrites the kept generic `<MouseWheel>` on THIS canvas only" |
| `src/wave_viewer.tcl` `wviewer::wheel_bind` | 4 lines: resolve token from canvas, delegate to `wviewer::wheel` — shared by both arrival paths |
| `src/xschem.tcl:13999-14005` | the MAIN canvas's own transform: `<MouseWheel>` → `xschem callback %W 4 %x %y 0 5 0 %s` when `%D<0`, else `... 0 4 0 %s` — **also UNCOVERED** |
| `src/xschem.tcl:13930` | a second `<MouseWheel>` bind on `$topwin` — establish which one wins and whether both are live |

## WHAT IS ACTUALLY AT RISK

Almost everything downstream is shared with the X11 path and IS covered. The
uncovered surface is narrow and worth stating precisely, because that is what the
legs must target:

1. **The `%D` sign → direction mapping.** `%D > 0 ? "up" : "down"` in three
   places in `wave_viewer.tcl`, and the inverted-looking `%D<0` → button **5**
   in `xschem.tcl`. An inverted mapping is invisible today.
2. **Modifier routing.** Three separate sequences hand three different `mods`
   literals (`0` / `shift` / `ctrl`) to the same proc. A copy-paste slip between
   them — e.g. `<Control-MouseWheel>` passing `shift` — is invisible today, and
   `ctrl` is the rung issue 0191's axis zoom hangs off.
3. **`%x %y` delivery.** The ctrl rung is *anchored on the pointer pixel*; a
   MouseWheel bind that forwarded the wrong coordinates would zoom about the
   wrong point. 0191's whole fixed-point invariant rests on these two words.
4. **That `break` really fires**, so a MouseWheel does not also fall through to a
   canvas zoom (the X11 half has this asserted; the portability half does not).

## SCOPE

- **In scope**: new test legs only, plus a doc/issue file. This is a **coverage
  repair, not a redesign** — if you find the code correct, do not rewrite it,
  write the leg that watches it.
- **In scope if a leg proves a real defect**: fix it, and say so loudly.
- **Out of scope**: changing the wheel factor, the axis-zoom maths, the X11
  bindings, or `property_form.tcl` / `xschem.tcl:1569`'s unrelated scroll wheels
  (note them if uncovered; do not chase them).

## THE ONE THING THAT MAKES THIS TESTABLE AT ALL — establish it first

`event generate $w <MouseWheel> -delta 120` **works under X11 / Tcl 8.6**: Tk
dispatches to whatever `<MouseWheel>` binding is installed regardless of whether
real hardware on this platform ever produces the event. **Verify that on this
build before writing a suite**, with a throwaway probe — if it does not dispatch,
the whole item is a DEFER with the finding recorded, and that is a success
outcome.

Sign conventions to cover: Windows delivers ±120 (and multiples), macOS ±1.
Assert **both magnitudes** map to the same direction — the code tests only the
sign, and a future `%D / 120` "tidy-up" would break macOS silently.

## PROBE PLACEMENT — read this before writing a single leg

From `doc/claude/overnight_batch_2026_08_01/PLAN.md`'s universal test discipline,
written after two `[F]` verdicts in one round that were both this mistake:

> **Never drive a leg from a pixel or path where the correct implementation and
> the bug you are guarding against give the SAME answer.**

Applied here, concretely:

- Do **not** probe at the plot box's centre. Item 04 failed exactly this way: its
  Y probes sat at `(box_top + box_bottom) / 2`, where an anchored zoom and a
  zoom-about-centre are numerically identical, and two one-token sabotages left
  **all 338 checks green** while introducing a 12 % error. Use an **off-centre**
  probe and carry an explicit "teeth" leg asserting the probe *is* off-centre.
- Do **not** assert only a magnitude (a width, a count, "the other axis did not
  move"). All three survive an arbitrarily wrong anchor. Assert **both
  endpoints**, or the fixed point, or byte-equality with
  `xschem get graph_axis_wheel_map`.
- A negative leg ("the modifier-less wheel does not axis-zoom") must carry a check
  that the probe was **actually delivered**, or it passes for the wrong reason
  every time the event is lost.

## NAMED SABOTAGES — each must kill exactly its target, then revert, then green

1. `<Control-MouseWheel>`'s `%D > 0 ? "up" : "down"` → `"down" : "up"` (invert one
   arrival path only). Must kill the direction legs and leave the X11 legs green.
2. `<Control-MouseWheel>` passes `shift` instead of `ctrl`. Must kill the ctrl-rung
   legs only.
3. `<Control-MouseWheel>` passes `%x %x` instead of `%x %y`. Must kill the
   fixed-point / anchor legs — this is the one an "assert the width changed" leg
   would sail past.
4. Drop the trailing `break` from one MouseWheel bind. Must kill the
   no-fall-through leg.
5. `xschem.tcl`'s `%D<0` → `%D>0`. Must kill the main-canvas direction leg.

If a sabotage does **not** kill its target, the leg is hollow there and that is a
finding, not a nuisance.

## DISCIPLINE

- Read `doc/claude/code_analysis/waveform_subsystem_reference.md` first (the
  WIRING.md of waveforms), then `doc/claude/specs/waveform_viewer_modes.md` §15
  (the LMB/RMB/wheel ownership table) and issue `0191`.
- Extend `tests/headless/test_wave_axis_zoom.tcl` (it owns the ctrl-wheel `CW*` /
  `CE*` / `CV*` blocks and its fixtures already scan for off-centre pixels) unless
  a new suite is clearly better; if new, register it in
  `tests/headless/full_audit.sh` `logdir_tests`.
- Copy the shipped footer EXACTLY: `RESULT: ALL PASS ($npass checks)` + `exit 0/1`.
  `run_suites.sh` classifies on the literal string `ALL PASS`.
- **Never** a bare `event generate` + one `update`: loop, `focus -force`, confirm
  `[focus -displayof $w] eq $w`, generate, retry until an expr in the caller's
  scope reports the effect.
- Run suites with `GUI_GATE=0` only if nobody is at the desk; otherwise use the
  gate's `Allow 30m` and `tests/headless/run_suites.sh`, never a bare for-loop.
- **KNOWN-FLAKY, not yours**: `test_cadence_drag` (12/12 red on pristine),
  `test_wave_trace_menu` TG9 (4-in-10 WSLg), `test_ase_plot` P4/P6/P8 (1-2 in 10),
  `test_hover_highlight` + `test_palette` (~40 %, measured on a pristine control
  worktree). **The check COUNT is the signal, not the verdict.**
- Git: explicit file list, no `git add -A`, no `git reset --hard`, no `git push`.
  Commit message ends with:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

## DELIVERABLES

1. New legs closing 1–4 above (and the `xschem.tcl` main-canvas transform), each
   sabotage-verified.
2. `doc/claude/issues/0193-mousewheel-path-untested.md` — the measurement, the
   design, the sabotage table, and an honest list of what remains unreachable.
3. A landmine entry in `waveform_subsystem_reference.md` if you find one worth the
   next reader's time — in particular whether `event generate <MouseWheel>` is a
   faithful proxy for real Windows wheel hardware, or merely the best available
   one. **Say which**; the item's value depends on it.
4. Note in the issue that `test_palette` still has no `RESULT:` footer (the other
   gap this round left open) — do not fix it here.
