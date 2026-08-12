# 0266 — `xschem move_objects END` silently arms a deferred MENU move instead of committing (the sub-verbs are lowercase-only)

Status: **OPEN** — measured while building issue **0244**'s fixture. **Minor but expensive**: it
costs no data, it costs *tests*. A scripted commit that never commits leaves the gesture pending and
the following assertion measures the wrong state, silently.
Area: `src/scheduler.c` — the `move_objects` verb's sub-verb dispatch (`start` / `step` / `end` /
`abort`) and its final `else`
Tests: pinned indirectly by `tests/headless/test_paste_modify_flag_0244.tcl` section A4, which
documents the trap in a comment and uses the correct form.
Found: 2026-08-08, while implementing **0244**.
Related: **0244** (whose session plan named the broken form as its commit constructor), **0069**
(the action-log replay forms that share this verb).

## What happens

The verb dispatches on `argv[2]` with `strcmp` against the lowercase literals `"start"`, `"step"`,
`"end"`, `"abort"`. Anything else falls through to the one-shot release form
`move_objects <dx> <dy> [...]` — and when there are no further arguments *that* form's `else` arms a
**deferred menu move**:

```c
xctx->ui_state |= MENUSTART;
xctx->ui_state2 = MENUSTARTMOVE;
```

which is the "menu item clicked, waiting for the canvas click" state. So `xschem move_objects END`
does not commit anything, does not error, and returns `TCL_OK`.

Measured on a pending paste:

```
xschem merge <f>            ui_state 296     STARTMERGE|STARTMOVE|SELECTION
xschem move_objects END     ui_state 65832   MENUSTART|STARTMERGE|STARTMOVE|SELECTION
                                             <-- nothing committed, paste still pending
xschem abort_operation      -> the paste is deleted, i.e. the "commit" never happened
```

The correct forms, all measured to leave `ui_state 8` (`SELECTION`) with the paste dropped:
`xschem move_objects end 0 0`, `xschem move_objects end <dx> <dy>`, `xschem move_objects <dx> <dy>`,
and `xschem paste <dx> <dy>`.

## Why it is worth fixing rather than documenting

It is silent in the direction that produces false green. A test that "commits" with the uppercase
form and then asserts something about the committed state is asserting about a *pending* gesture,
and the assertion can pass for the wrong reason — issue 0244's own control row D
("dirty + merge + commit → modified 1") was right about the number and wrong about the state, for
exactly this reason. `MENUSTART` is also left set on `ui_state`, so the next canvas click in a GUI
session would start a move nobody asked for.

## Sketch

Either accept the sub-verbs case-insensitively (`strcasecmp` is not C89-portable in this tree — use
a small local lower-casing compare), or make an unrecognised **non-numeric** `argv[2]` a
`TCL_ERROR` (`"xschem move_objects: unknown sub-verb"`). The second is preferable: it converts a
silent no-op into a loud failure, and the one-shot form's arguments are always numeric, so the test
is unambiguous. Check the action-log replay lines (issue 0069) for the exact spellings they emit
before tightening.

---

# RESOLUTION — 2026-08-12, crew item **D10** (unattended backlog run, branch `open_pdk`)

Status: **FIXED** in the one-shot coordinate form — with a **narrower scope than the first write-up
claimed**. See "Still open" below: the adversary pass refuted the *wider* claim, three doc surfaces
were narrowed accordingly, and the uncovered slots are filed as **0405** / **0406** / **0407**.
Item status handed to the driver: **E** (user-visible change, ladder rung **R3**, no prior
ratification — the question is at the bottom of this section).

## BEFORE — measured against `src/xschem` at `d99f3791`, verbatim from the Measure agent

```
A0 armed:            ui_state=296 ui_state2=0 wires=3
A1 move_objects END: rc=0 result={}
A2 after END:        ui_state=65832 ui_state2=256 wires=3
A3 after ESC:        ui_state=0 ui_state2=256 wires=2
B0 armed:            ui_state=296 ui_state2=256 wires=3
B1 move_objects end 0 0: rc=0 result={}
B2 after end 0 0:    ui_state=8 ui_state2=256 wires=3
B3 after ESC:        ui_state=0 ui_state2=256 wires=3
C1 move_objects END 40 40: rc=0 result={}
C2 wire after END 40 40: N 0 40 100 40 {lab=#net1}
C3 control, plain 40 40:  N 40 40 140 40 {lab=#net1}
D  move_objects START    rc=0 result={} ui_state=65536 ui_state2=256
D  move_objects End      rc=0 result={} ui_state=65536 ui_state2=256
D  move_objects foo      rc=0 result={} ui_state=65536 ui_state2=256
G0 idle:                 ui_state=0 ui_state2=0 selected=0
G1 after move_objects END: ui_state=65536 ui_state2=256 selected=0
G2 after ONE canvas click: ui_state=40 ui_state2=256 selected=1  (40=STARTMOVE|SELECTION -> a move gesture nobody asked for)
K1 copy_objects end:      rc=0 ui_state=65544 ui_state2=2048 wires=1
K2 copy_objects end 0 0:  rc=0 ui_state=8 ui_state2=2048 wires=2
```

Reading: `A3` is the proof that nothing committed — the ESC after the "commit" **deleted** the merged
wire (3 → 2), where the correct `end 0 0` control keeps it (`B3`, wires 3). `C2` is worse than the
filed no-op and was **not** in the original report: `END 40 40` has `argc 5`, so the argument-COUNT
discriminator puts it on the *commit* path with `dx = atof("END") = 0.0` — it writes the document,
at the wrong coordinate, rc 0. `G2` is the GUI half (measured under `xvfb`): the stranded
`MENUSTART` is live, and one canvas click starts a move nobody asked for.

## AFTER — same binary tree, `md5(src/xschem) = d8f471d7eb014c21f5a815957db97c4e`

```
CORE  move_objects END      -> rc=1 ui=8 ui2=0
CORE  move_objects START    -> rc=1 ui=8 ui2=0
CORE  move_objects Start    -> rc=1 ui=8 ui2=0
CORE  move_objects foo      -> rc=1 ui=8 ui2=0
CORE  move_objects abort_it -> rc=1 ui=8 ui2=0
CORE  END 40 40 -> rc=1  N 0 0 100 0 {}          <-- document byte-identical, nothing written
CORE  40 40     -> rc=0  N 40 40 140 40          <-- the pure-commit form is untouched
```

The three messages now emitted:

```
xschem move_objects: unrecognized argument "END": expected sub-verb start|step|end|abort
                     (lowercase), flag kissing|stretch, or a numeric <dx> <dy>
xschem move_objects: "stretch" must follow <dx> <dy>, not precede them
xschem move_objects: <dx> <dy> must both be numbers (got "40" "END")
```

## The change

`src/scheduler.c`, +91 lines, 0 deletions, one call site. Three file-static helpers immediately
after `scheduler_readonly_reject()` (the file's own idiom for a verb-boundary rejecter that returns
1 with the interp error already set):

- `move_objects_slot_is_flag()` — whitelists exactly `kissing` / `stretch`, the two words three
  shipped call sites legitimately put in the dispatch slot (`Control+M`, `Shift+M`, `actions.csv`).
- `move_objects_slot_is_number()` — **full `strtod` parse** (`endp != s && *endp == '\0'`), the
  idiom already used elsewhere in this file, never `isdigit`: `-90 -40` (wireedit_54), `40.5 -0.5`
  and `1e2 40` are all live shipped forms.
- `move_objects_args_reject()` — `argc <= 2` (the bare arm) passes; a flag word passes only in the
  arm shape; a non-number in the dispatch slot is refused by name; a commit shape requires
  `argv[3]` to be a number too.

The single call sits inside the final `else`, **before** `if(kissing) xctx->connect_by_kissing = 2;`
and `if(stretch) select_attached_nets();`, so a rejected line leaves no state behind. That placement
is the only thing sabotage variant SAB-5 changes, and row F15 is its sole witness.

## Decisions, with ladder rung and rejected alternative

- **D1 (rung R3 — user-visible, forces status E).** An unrecognised, non-numeric dispatch slot
  becomes a `TCL_ERROR` naming the token instead of silently arming a deferred menu move. In-file
  precedents for the *shape* exist (`fluid_trace`, `backup`, `pan` all `TCL_ERROR` on a bad
  sub-verb) and issue 0392 files the same family, but 0392 is OPEN, not ratified, so no prior rung
  covers it. *Rejected:* this issue's own first sketch — accept the sub-verbs case-insensitively via
  the tree's existing `my_strcasecmp` (`src/util.c:29`). Rejected because it only **widens** the
  grammar (a second legal spelling of `end` in a verb whose log-replay surface wants exactly one)
  and still leaves `foo`, `abort_it` and a truncated `move_objects 40` arming silently.
- **D2 (rung R2 — least surprising, smallest).** The validation covers the delta slots too, not just
  `argv[2]` as filed: `END 40 40`, `40 END`, `40 {}`, `kissing 40 40`, `stretch 40 40` and the
  truncated `move_objects 40` all error. Every one was measured committing at a corrupted delta (or
  arming) with rc 0. *Rejected:* fix `argv[2]` only, as filed — it leaves the identical
  `atof()`-eats-a-non-number root cause live one slot to the right, and the truncated form is
  precisely the replay hazard the item was prioritised for.
- **D3 (rung R1 — landmine 2, "never gate a pure-commit coordinate form").** Only argument TYPE and
  COUNT are inspected; no state precondition is added to `move_objects <dx> <dy> …`, which still
  commits from any `ui_state`. Rows F22–F26 are the standing proof, SAB-3 is the detector.
  *Rejected:* requiring a live gesture or a non-empty selection first — that is the replay/test seam.
- **D4 (rung R2 — smallest blast radius).** Scope to `move_objects`; leave the sibling verbs alone
  and **file** them (**0404**). *Rejected:* tighten both verbs here — `copy_objects` has no sub-verb
  contract, so this error text is a misnomer there, and it doubles what one sabotage matrix covers.
- **D5 (rung R1 — 0241, "a teardown must name what it is tearing down", applied to its inverse).**
  The fix is *prevention*: with the bad slot rejected, `MENUSTART`/`MENUSTARTMOVE` are never set by a
  typo. The pre-existing stranded `ui_state2` (measured to survive `abort_operation` **and**
  `xschem clear force`) is **not** cleared here — that is issue **0268**. *Rejected:* zero
  `ui_state2` in this branch.
- **D6 (rung R2).** `scheduler_readonly_reject` stays the first statement of the branch, so a
  read-only buffer answers `*read-only*` for every spelling including a bad one. New rows in
  `test_readonly_guard.tcl` lock it; SAB-6 is the detector. *Rejected:* validate at the top of the
  branch (cheaper) — the read-only refusal is the more important thing to tell the user.
- **D7 (rung R2).** The message echoes the offending token and states the three legal shapes.
  *Rejected:* `backup`'s terser "unknown subcommand" — the reader is debugging a replay log and
  needs to know *which* token was bad and that the sub-verbs are lowercase.
- **D8 (rung R1 — documented contract).** `move_objects end` with no live gesture stays a **no-op**,
  not an error (`fuzz/harness.tcl:122-124` and the wireedit start/step/end tier depend on it). The
  four sub-verb branches are not touched at all. *Rejected:* making a commit-with-nothing-armed an
  error while we were in here.
- **D9 (rung R2 — docs), amended by the adversary pass.** `WIRING.md`, `specs/action_logging.md` and
  `doc/xschem_man/developer_info.html` were updated — and then **narrowed**, because the first
  wording claimed coverage the code does not have. See "Still open".

## Tests

`tests/headless/test_paste_modify_flag_0244.tcl` gains section F (**376 → 444 checks**):

- **Negative** — F1 `END` rc 1; F2 the message names the token; F3 `ui_state` still 296 (no
  `MENUSTART`); F4 `ui_state2` still 0; F5 the merge is still pending (the error did not
  half-consume the gesture); F7/F8 `END 40 40` rejected **and** the wire record byte-identical;
  F9 `40 END`; F10 `40 {}` (an empty delta is not 0.0); F11/F12 the truncated `move_objects 40`;
  F13/F14 flag-before-delta; F16 nine mis-cased spellings; F17 `modified` unchanged throughout.
- **Ordering** — F15: after a rejected `stretch 40 40` on an L fixture, `lastsel` is still 1
  (`select_attached_nets()`, measured to grow it 1 → 2 on the arm path, never ran).
- **Positive** — F18 bare arm, F19 `stretch` arm (and `select_attached_nets` *does* run there),
  F20 `kissing`, F21 `stretch kissing`, F22 `40 40` → `N 40 40 140 40`, F23 `-90 -40 stretch
  kissing`, F24 `40.5 -0.5`, F25 `1e2 40`, F26 `0 0 1 0 -anchor 0 0 kissing`, F27/F28 the
  start/step/end/abort seam, F29 `end 0 0` on a pending merge.

`tests/headless/test_readonly_guard.tcl` gains 2 rows: on a read-only buffer `move_objects END`
answers `*read-only*`, **not** `unrecognized argument`.

Tier counts after (baseline → after): shape_draw 421 → 421, paste_modify_flag_0244 376 → **444**,
add_wire_label 196 → 196, placement_wire_gate 187 → 187, label_ride 157 → 157, preview_doors
206 → 206, strand_oracle 32 → 32, sch_add_pin 34 → 34, instance_update 95 → 95, readonly_guard
11 → **13** ok, wireedit ALL PASS, headless/run.sh 6 goldens PASS, `run_regression.tcl` exactly the
same 3 pre-existing FAIL lines.

## Sabotage matrix (run by the Implement agent, re-run and confirmed by Verify-B)

| variant | how | predicted | observed |
|---|---|---|---|
| SAB-1 rejecter-off | `#define move_objects_args_reject(i,c,v,n) 0` | 13 row-groups | **30 checks red** (F1–F17); `readonly_guard` stays PASS, correctly |
| SAB-2 everything-is-a-number | `#define move_objects_slot_is_number(s) 1` | 5 | **8 red** (F7, F8, F9, F10, F17) |
| SAB-3 nothing-is-a-number | `#define move_objects_slot_is_number(s) 0` | 5 rows + 4 suites | **10 red** (F22–F26) + wireedit FAILURES + label_ride/fuzz/fluid_ortho **aborts** |
| SAB-4 flag-whitelist-off | `#define move_objects_slot_is_flag(s) 0` | 3 groups | **7 red** (F19, F20, F21); F13/F14 stay green with the other message, as predicted |
| SAB-5 reject-after-the-side-effects | the call line **relocated** below `select_attached_nets()` | exactly 1 | **exactly 1** — F15 reads `{2}` (exp `{1}`); all 443 other checks green |
| SAB-6 validate-before-readonly | a hoisted copy above `scheduler_readonly_reject` | 1 | **2** — both new readonly rows; 0244 aborts at line 192 |

Restore verified clean: `ALL PASS (444)` + `READONLY_GUARD_TEST_PASS`, source byte-identical.

### Predicted reds that did NOT appear — coverage holes, recorded honestly

- **SAB-1 leaves F5 green.** With the rejecter off, `END` *arms*, which also leaves the merge
  pending — so F5 pins "the error did not half-consume the gesture", **not** the rejection. SAB-1 is
  still caught by 30 other checks.
- **SAB-2 leaves F2 green.** With `is_number` forced to 1, `END` falls through to the *`<dx> <dy>`*
  message, which also echoes `END`, so the glob `*move_objects*END*` still matches. F2 pins "the
  message echoes the offending token", **not** which of the two messages fires. Nothing in section F
  distinguishes them. SAB-2 is still caught by F7/F8/F9/F10/F17.
- **F15 is also green under SAB-1** (the un-rejected line commits and `lastsel` returns to 1), so
  SAB-5 is that row's sole detector — which is the role it was assigned, and it fired alone.
- **Reading hazard:** SAB-3's and SAB-6's tier damage presents as a Tcl **abort with no `RESULT` /
  `OVERALL` line at all**, not as `FAIL:` lines. A `grep -c FAIL` probe reads 0 there and looks
  green. Any re-run of this matrix must key on the *presence* of the verdict line.

## Still open — the adversary pass refuted the wider claim

The central claim as first written ("a mis-cased, hand-edited or truncated move line stops a replay
with a diagnostic") is **false beyond the first two slots**. Measured 2026-08-12, all rc 0, all
silent, all still `atof`/`atoi`:

```
end END 40   -> N 0 40 100 40   (control `end 40 40` -> N 40 40 140 40)   dx eaten
end {} 40    -> N 0 40 100 40                                            dx eaten
end 40       -> N 0 0 100 0                                              commits at (0,0)
0 0 1 0 -anchor 50      -> N 0 0 0 100   (full line -> N 100 0 100 100)   anchor dropped
0 0 1                   -> N 0 0 100 0                                   rotation dropped
0 0 X 0 -anchor 50 50   -> N 0 0 100 0   atoi("X") = 0                   rotation dropped
40 40 GARBAGE           -> rc 0, trailing argument ignored, no witness row
nan 0 -> the saved file gets `N nan 0 nan 0`;  inf 0 -> the wire VANISHES from the saved file
copy_objects / rect / polygon / line / arc / circle  `<verb> END` -> rc 0, arms MENUSTART
```

Filed rather than fixed (the run's rule: never fix a discovered defect silently, never leave one
unfiled): **0405** (sub-verb coordinate slots — and it is the `end <dx> <dy>` form this very issue
recommends as the commit constructor), **0406** (transform slots + truncated emitted log line +
ignored trailing argument), **0407** (`strtod` admits `nan`/`inf`/hex), **0404** (widened to the six
sibling verbs). Test-harness findings from the same pass: **0408** (`test_label_ride` writes a
fixed-path fixture, is not parallel-safe, and row V22 flaked twice in 16 runs under crew load),
**0409** (`test_cadence_drag` reports 2 FAILED and is wired into no harness).

The three doc surfaces were **narrowed in this same commit** to say "the one-shot form's first two
slots ONLY" and to point at 0405/0406, because the over-broad sentences were themselves the
deliverable the adversary refuted: `WIRING.md` had "The delta slots are validated the same way" in
the same bullet that recommends `move_objects end <dx> <dy>`, and `developer_info.html` had "dx and
dy must both be numbers" directly under the `end` entry. The C header comment carries the same
scope note.

Also unchanged and out of scope by decision: `ui_state2` keeps `MENUSTARTMOVE` through
`abort_operation` and through `xschem clear force` (**0268**).

## The question a human must answer (rung R3 — why this item is status E)

> Should `xschem move_objects <garbage>` raise a Tcl error — which **aborts** a user's `.tcl` /
> `xschemrc` script (or a whole action-log replay) at that line, where it previously ran on past a
> silent no-op — rather than keep arming a deferred menu move?

The crew implemented the error. No shipped call site, menu, keybinding, emitted action-log line or
gold fixture passes a bad slot (all enumerated: the complete set of non-numeric dispatch slots in
the tree is `{absent, kissing, stretch, start, step, end, abort}`), so the only callers affected are
scripts that were already broken. Nobody has tested what a replay looks like **after** a mid-file
abort — that half-applied state is new.
