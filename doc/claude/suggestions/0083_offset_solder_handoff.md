# Handoff — issue 0083 (fluid no-short offset solder-joint), continue

Branch `fluid-editing`. Continue the issue-0083 work: a fluid follow-set wire, on a stretch drag,
gets *translated* so its corner lands on / inside a stationary device body, burying the visible
solder-dot and grazing the body. All correct electrically (no short) — a P5/beautify feel bug. This
is part of the larger **nice-drag-rerouting / incremental-wire-reroute** effort.

## Orient first (read these, in order)
- Memory `nice-drag-rerouting.md` — full status, **newest entries at the BOTTOM** (the 0083 entries
  are the last ~5 paragraphs). Also `MEMORY.md` index.
- Issue `doc/claude/issues/0083-fluid-no-short-landing-loses-offset-solder-joint.md` — the whole story
  (root cause, the Implementation section, the broadening, the review outcomes).
- Spec `doc/claude/specs/incremental_wire_reroute.md` §6 (stop-short/solder-joint) + §10.4; predicates
  in `nice_drag_rerouting.md` §4, conflict order `P1=P2 > P3 > P5 > P4 > P7 > P6`.
- Code: `src/move.c` — `fluid_offset_foreign_pin_landing()` (the pass) + its call site (grep
  `fluid_offset_foreign_pin_landing`); the diagonal decomposition loop (grep `for(attempt`, `nlegs`);
  the trace helper `fltrace()` / `fluid_trace_on()`.
- Test `tests/headless/wireedit/test_wireedit_41_no_short_offset_solder.tcl`.

## Where things are (committed on `fluid-editing`, ALL UNPUSHED)
`40bcea52` issue doc → `9a5c235b` RED test → `5fa69442` feat(fix) → `8bf415a4` review gate-fix →
`614bd6d5` feat(broaden) → `fda5a128` doc → `da175c9c` feat(diagonal per-leg + FLUID_TRACE) →
`1dde5525` fix(trace→file). **Do not push until the user signs off.**

**The fix (`fluid_offset_foreign_pin_landing`, move.c):** a stateless post-detection sibling pass at
the pre-trim commit seam, right after `fluid_reroute_around_obstacles`, gated (caller)
`fluid_editing && stretch_select && rot==flip==0 && (deltax==0 || deltay==0)` — i.e. a PURE-AXIS
delta, so it fires on a pure-axis move AND on each leg of the 0081 diagonal decomposition (X-leg
offsets, Y-leg declines). Detection: a tool-owned VERTICAL riser (sel!=0, same net as a stationary
device pin) whose corner column is STRICTLY INSIDE the device body x-span; find the same-net anchor
pin, classify the horizontal row copper into the BUS (far end = anchor) + optional OVERSHOOT stub
(far end = pin, from a >1-grid drag). Rebuild the riser into a V-H-V that lands one grid OUTSIDE the
body on the pin's side, at a restored degree-3 solder-dot, with a stub to the pin. Bus+stub copper is
a subset of baseline (re-segmented, overshoot removed) ⇒ only the 3 new legs are guarded
(`fluid_seg_crosses_stationary_body` + `_hits_foreign_pin` + `_hits_moving_pin` + `_stray_contact`);
every guard declines-to-baseline. before_3 R18 +N-grid → riser V-H-V to x=-400 dot, stub -400→-390.

Verified: `test_wireedit_41` covers +10/+20/+30 + diagonal(+20,+10), release AND stepwise
(release==stepwise). Full wireedit suite ALL PASS (41); byte-identical fluid=0 (axis + diagonal);
`--memcheck` clean (41/34/40). Two adversarial worktree reviews (`wf_3029984d`, `wf_e96154bf`) → 0
confirmed correctness findings.

## THE IMMEDIATE NEXT STEP — diagnose the user's new failing gesture
The +10-then-+10 (right,right) case and the right,right-DOWN diagonal both pass now. But the user
reported **yet another gesture that still fails** (unknown at handoff time). They are running the
FLUID_TRACE-instrumented binary and will paste `/tmp/xschem_fltrace.log`. **Get that trace first,
then fix exactly what it shows — do NOT guess the path.**

### Using FLUID_TRACE (the user-requested diagnostic; keep it, it's gated-off by default)
```
FLUID_TRACE=1 src/xschem --script src/cadence_style_rc --logdir /tmp    # user's real launch
#   ... do the failing gesture, quit ...
cat /tmp/xschem_fltrace.log        # NOT `2>` -- GUI detach freopens stderr to /dev/null (main.c:132),
                                   # so fltrace() writes to a FILE. Default /tmp/xschem_fltrace.log,
                                   # or FLUID_TRACE=<path>.
```
Read the trace like this:
- `FLTRACE move: ... totdx=.. totdy=.. -> nlegs=N` — the total delta + whether the 0081 diagonal
  decomposition engaged (nlegs=2). A diagonal total is the usual culprit class.
- `FLTRACE offset-call: deltax=.. deltay=.. pure_axis_gate=0/1` — was the offset pass even called for
  this leg? (gate=0 ⇒ a genuine diagonal leg delta, pass skipped by design.)
- `FLTRACE offset: ENTER` then `... riser Rw=.. M=(..) C=(..) P=(..) body_x=[..]` — what it detected.
  No `riser` line after ENTER ⇒ guard-1 found no intruding riser (corner not inside a body).
- `FIRE! ...` ⇒ it rebuilt. `decline (net ..)` / `decline (wB=.. wS=.. stranded=..)` ⇒ the reason.
  `classified ...` but no `FIRE` ⇒ a per-leg guard (body-cross / foreign-pin / moving-pin / stray)
  declined — add a trace to those `continue`s if you need to know which.
- `FLTRACE move: two-leg attempt=.. partition_changed=.. -> ACCEPT/ROLLBACK` — the 0081 P2 fallback.

From the trace, decide: is the pass not called (gate), not detecting (guard-1 body-span / vertical-
riser-only / same-net), declining (a guard), or firing but the *result* is wrong? Then reproduce that
exact case headless via `tests/headless/wireedit/fixtures.tcl` idioms (the `move_objects
start/step/end` seam is a FAITHFUL mirror of the interactive drag — the trace proves identical path),
add it RED-first to test_41, fix, verify.

## Hard constraints / discipline (every prior layer held these)
- **Default-off byte-identical**: everything gated on `fluid_editing`; prove `fluid=0` fixed ==
  baseline binary `scratchpad/xschem.base0083` (run it with `XSCHEM_SHAREDIR=<repo>/src`; regenerate
  the baseline from HEAD-before-your-change if stale).
- **release==stepwise**: the pass is a pure fn of (pristine snapshot + total delta + geometry); drive
  every fixture BOTH one-shot (`we_move_stretch dx dy`) and stepwise (`move_objects start/step*/end`)
  and assert identical segset.
- **Conflict order** P1=P2 > P3 > P5 > P4 > P7 > P6. This is P5/beautify — never trade P1/P2/P3; every
  guard declines to the exact naive baseline (never a worse route).
- **Commit WIP before spawning any git-capable subagent/Workflow; isolate tree-mutating review/attack
  agents in a worktree** (`isolation:'worktree'`) — a review `git reset --hard` wiped uncommitted work
  once. Worktree agents build from committed HEAD, so commit first.
- **GREEN-BUT-HOLLOW is the recurring failure mode here** (bit us 3×: missed +20, missed diagonal,
  missed the current gesture). A green suite ≠ covered. When you add a case, also imagine the
  *adjacent* untested ones: other magnitudes, other axes, continuous multi-step drags, other device
  orientations. Port EXACT scenes (autotrim cleans simplified scenes and hides the bug). Compare
  fluid-OFF-vs-ON on the SAME scene, never no-obstacle-vs-obstacle.
- Headless: `./src/xschem --nogui --pipe -q --nolog --script <file>` from repo root; net readback
  `xschem resolved_net 0` (trailing 0). Memcheck: `sh tests/headless/wireedit/run_wireedit.sh
  --memcheck` (or targeted valgrind with `env -u DISPLAY ... --error-exitcode=99 --leak-check=no`).
- **The user's real-window eyeball is the acceptance gate, not headless green.** WSLg makes windowed
  `xschem callback` gesture repro unusable (empty output) — rely on FLUID_TRACE from the user + the
  faithful `move_objects` seam headless.

## Known limits / scope (first increment; all decline-safe)
- Vertical-riser / horizontal-bus only; a horizontal riser or rotated bus declines (untested transpose
  — a candidate next increment, needs its own RED fixture, don't ship untested).
- One landing per pass. Collinear-split riser/bus under autotrim declines (doesn't fire).
- A drag whose corner reaches the FAR (distinct-net) device pin is a straddle
  `fluid_reroute_around_obstacles` handles first (this pass then sees a detour and declines).
- Diagonal is handled by per-leg firing; a *genuine* diagonal-delta leg (0081 P2 single-pass fallback,
  or a preselected follow wire keeping nlegs==1) leaves both deltas nonzero → does not fire (correct).

## Acceptance
The user's failing gesture(s) route cleanly (riser offset + visible solder-dot, clear of the device
body) in the real window; suite + memcheck green; default-off byte-identical; release==stepwise; the
user signs off; THEN push the whole `fluid-editing` range. Remember to strip or keep-gated any extra
debug traces you add (FLUID_TRACE itself stays — it's a deliberate gated facility).
