# 0187 — `wviewer::open`'s "did the context follow?" guard compares a value with itself, so the viewer brand can land on a user's schematic

Status: **FIXED** 2026-08-03 (Signal Browser batch item 00), `src/wave_viewer.tcl`.
Filed 2026-07-31, found by the adversarial review of the issue-0172 fix and reproduced
twice, independently, on the real binary.

## The fix (2026-08-03)

The decision moved out of `wviewer::open` into a **pure** proc,
`wviewer::ctx_verdict wp tops0 tops1 ninst nwires` -> `{ok <toplevel>}` | `{err <msg>}`,
so the rules are drivable in the true-headless arm (`wviewer::open` returns 0 without
`::has_x`, and everything past the brands is Tk). Three rules, in order:

1. `$top eq {.}` — the pre-existing ROOT-window refusal, unchanged.
2. **the repair**: the context must have landed on a toplevel that was *not* in
   `winfo children .` before the create and *is* in it after. The intended target is
   not a path anybody hands us; it is "a toplevel THIS call created", so that is what
   is tested. Sound in both window models — `-window` sets `force_window=1` and an empty
   file arg takes `new_schematic("create_window",...)`, which in `xinit.c` always calls
   `create_new_window` regardless of `tabbed_interface`, and that does `toplevel .xN`,
   a direct child of `.` either way. Confirmed empirically: `winfo children .` in a
   tabbed session lists `.tabs .x1 .x2 ...`.
3. the belt from "Direction" below: refuse to stamp a context holding instances or wires.

`wviewer::open` keeps the `"wviewer: "` prefix so there is one site for it; the two
pre-existing CIW strings are byte-for-byte unchanged and a third is added for rule 3.
`create_new_window`'s silent no-free-slots return was **not** changed — that is C, and
this batch is Tcl-only (batch decision 8). Rule 2 does not need it: it detects the
absence of the toplevel rather than the absence of an error.

Tests: `tests/headless/test_wave_viewer.tcl` X1-X9 (57 checks true-headless, 400 under a
real `DISPLAY` — X8 exhausts all 20 window slots, so it self-skips in the DISPLAY arm
where it costs ~57s and 19 real toplevels instead of ~65ms). X9 is a source-shape pin on
`info body ::wviewer::open`: reinstating the circular comparison changes no behaviour, so
no behavioural check can catch it. Sabotage-verified SB-A (rule 2 defeated -> exactly
X3+X4), SB-B (rule 3 deleted -> exactly X5+X6), SB-C (circular guard reinstated alongside
-> exactly X9).

## The guard

`wviewer::open` (`src/wave_viewer.tcl`) stamps five per-context C flags — `readonly`
(D1), `no_grid` (item 18), `no_snap` (0177), `graph_snap_cursor` (item 9) and, since
0172, `wave_viewer`. Because those are per-context state and the context switch is
measured to no-op occasionally under a raised semaphore, the proc re-checks before
stamping:

```tcl
set wp [xschem get current_win_path]      ;# ~583, AFTER `xschem load_new_window -window {}`
...                                        ;# recovery loop: overwrites wp only on a VERIFIED switch
if {[xschem get current_win_path] ne $wp} {   ;# ~618
  ciw_echo "wviewer: the waveform window did not take the context, refusing" error
  return 0
}
```

`wp` is *read from* `current_win_path`, and between that read and the comparison there is
no `update`, no event loop and no command that can move the context. **The comparison is
a value against itself and can never fire.** The only live guard is `$top eq {.}` above
it, which catches slot 0 and nothing else — a context parked on any `.xN.drw` (a detached
editor, or any non-first tab, since `create_new_tab` names them `.x<n>.drw` too) sails
straight through.

## Measured

Deterministic trigger: with all window slots used (`MAX_NEW_WINDOWS` 20, `src/xschem.h`),
`create_new_window()` returns *before* creating anything and before `(*window_count)++`
(`src/xinit.c`) and prints only `new_schematic("create"...): no more free slots` — no Tcl
error. So `xschem load_new_window -window {}` returns rc=0, no new toplevel exists, and
`wp` still equals the window that was current all along.

Headless, context parked on a real schematic:

```
parked win=.x5.drw sch=.../xschem_library/examples/test.sch instances=6 wires=10
new_schematic("create"...): no more free slots
before=.x5.drw wp=.x5.drw ntabs=19
top=.x5     (the `$top eq {.}` guard does not fire)
618 GUARD: PASSED -> stamping
RESULT: ctx=.x5.drw sch=test.sch inst=6 wave_viewer=1 readonly=1
```

Under a real `DISPLAY`, the same setup with a 23-instance schematic in `.x19.drw`:
`wviewer::open` returned **1** (success), the user's schematic stayed loaded, and the
window came out `wave_viewer=1 readonly=1 no_grid=1 no_snap=1` with the viewer registry
pointing at `.x19`.

## Why it matters more now

Four of the five brands are pre-existing (0177-era) and their damage is visible and
recoverable: the window goes read-only and loses its grid and snap. The fifth,
`wave_viewer` (issue 0172), is invisible and permanent — nothing in production ever
clears it — and it removes the window from the pristine-untitled reuse path and forces
`ask_new_file()` down its new-window arm for the rest of the session.

Counter-argument worth keeping: once `wviewer::windows` points at that window, the window
*functionally is* the viewer, so refusing to reuse it is arguably consistent rather than
wrong. The defect is the branding of a live schematic, not the refusal that follows.

## Direction

Capture the intended target *before* the create (the window path the viewer is supposed to
land on) and compare against that, not against a value re-read from the same source; and
make `create_new_window`'s no-free-slots path report failure to its caller instead of
returning silently. A second, cheaper mitigation for the specific 0172 flag: refuse to
stamp when the context holds instances or wires — a viewer never does.

## Cross-references

* `doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md` — the
  `wave_viewer` flag and the four doors it closes.
* `doc/claude/issues/0177-viewer-has-no-snap-grid.md` — where the guard was written.
* `doc/claude/specs/waveform_viewer.md` — the flag block and the D1 contract.
