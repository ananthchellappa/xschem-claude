# Bugfix implement prompt — issue 0068: definitive legacy raw-switch key inventory (DOCS deliverable)

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
Issue file: doc/claude/issues/0068-unmigrated-legacy-switch-keys-not-logged.md
Plan: doc/claude/refactor_b_batch/BUGFIX_PLAN.md item 8 ("issue-0068-sweep").
Scout re-verified all anchors below 2026-07-19. Lines WILL drift — re-verify before citing.

## What this item IS and IS NOT

- Deliverable: **DOCS ONLY.** A definitive inventory of every legacy raw-switch key path in
  `src/callback.c` that reaches a mutating core or verb, with a 5-way classification per
  chord-arm, written into issue 0068 (plus an optional companion code_analysis doc if the
  full table is big). **NO code changes. NO test runs.** Return `testFile="NONE"`,
  `checksTotal=0`, `sabotage=[]`.
- The issue is REAL but its §3 scope list is BADLY STALE (written 2026-07-02; most members
  have since been covered by Refactor B atoms 5/6/7/8/21/26 and the 0069 gesture-funnel
  work). The rewrite IS the fix: without the inventory, nobody can say which gaps remain.

## Scout findings that seed the inventory (all re-verified from source 2026-07-19)

Structure of the surface to sweep (`src/callback.c`):
- `handle_key_press` starts at :4863. Registry dispatch gate at :4890-4900
  (`key_chord_has_binding` → `dispatch_input_action`; a dispatched chord RETURNS before the
  switch). Legacy `switch (key)` opens at :4903, `default:` at :6529. Every `case` arm from
  :4904 to :6529 is in scope; within a case, **each `state`/`rstate` branch is a separate
  inventory row** (rstate==0 / ControlMask / EQUAL_MODMASK / SET_MODMASK / combinations).
- Family chords (SET_MODMASK = Alt-or-Super) are ratified stay-in-C — the exact-chord
  binding table cannot express them (comments callback.c:4046-4048, 5302-5307).
- The "numeric verb-noun cases" = the context-menu pick dispatch around callback.c:3147-3327:
  the `ctxmenu_log_cmd[]` classification table (:3147) + record-after-evaluation emit
  (:3325-3327, deduped by `actionlog_cmd_logged`). This surface is ALREADY class-complete
  in-code — the inventory gets one summary section citing the table, not per-pick re-derivation.

Classification (one class per row):
- **(i) covered by core self-log or gesture-drop funnel** — the mutation logs via
  `end_move_copy_logged` (callback.c:1604) / `log_placed_instance` (callback.c:1572) /
  actions.c drop logs (`xschem wire/line/rect/arc` :4313-4607) / editprop core
  (`log_prop_edit_replayable`, editprop.c:1682-1684) / a self-logging core.
- **(ii) logs at key site** — `log_action` inline in the case arm.
- **(iii) routes through a logged verb** — `perform_action(...)` in the arm.
- **(iv) UNLOGGED gap** — mutating, no line anywhere. THE 0068 LIST.
- **(v) readonly-UNGATED** — mutating arm with no `readonly_block()` AND no gate in the
  callee (the 0126/0128 bug class). A row can be both (iv) and (v); record both flags.
- Non-mutating arms (zoom/pan/selection/viewer/dialog-open-only/UI toggles) get class
  `n/a` with a one-word reason — recorded so the sweep is provably complete.

Verified seed rows (cite these; re-verify lines):
- Keys '0'-'4', state==0 (:4909-4913) → `logic_set()` (hilight.c:2309). Mutates instance
  props (pin logic level); `readonly_block()` at :4911; **logic_set has NO log_action →
  class (iv)**. Scout-confirmed surviving gap #1.
- 'J' + SET_MODMASK (:5313-5318) → `print_hilight_net(2)` at :5317, `readonly_block()` at
  :5316. Mutating (labels via routed inner `xschem merge`); the merge DROP is funnel-logged
  but the initiating verb line is not → **class (iv), partial-funnel** (receipt 21 has the
  full anatomy). Scout-confirmed surviving gap #2.
- 'j' + SET_MODMASK+Ctrl (:5302-5311) → `print_hilight_net(3)` at :5309 — mode 3 is a
  read-only VIEWER (receipt 21) → unlogged but **non-mutating** → `n/a`, document as the
  family-chord viewer.
- Ctrl+C (:5049), Ctrl+X (:6077), Delete (:6250) → inline `log_action` → class (ii).
- Ctrl+V paste (:5925-5928, `merge_file(2,".sch")`) → STARTMERGE arm; drop logs
  `xschem paste dx dy ...` via end_move_copy_logged (paste.c:384-394) → class (i).
- Alt-R/Alt-F/Alt-V + Shift-R/F/V standalone applies → `perform_action` ("rotate" :5745,
  "flip" :5210, "flipv_in_place" :5961, "flipv" :6001) → class (iii). Their mid-gesture
  arms (STARTMOVE/STARTCOPY branches) are funnel-logged at drop → class (i).
- Shift+S → `perform_action("change_elem_order")` :5827 → (iii). Alt+U →
  `perform_action("align")` :5893 → (iii). '&' → `perform_action("trim_wires")` :6424 →
  (iii). '!' → `perform_action("break_wires")` :6519/:6525 → (iii).
- '#'/Ctrl+# (:6467-6486, atom 26) → (ii)/(iii) split exactly as the case comments state.
- 'a' make_symbol (:4960-4974): core self-logs (comment :4969-4970, receipt 22) → (i).
- Ctrl+L → `create_sch_from_sym()` :5353 — core self-logs `xschem make_sch`
  (save.c:5510, comment names the Ctrl+L handler) → (i).
- Ctrl+P/Ctrl+Shift+P/Alt+Shift+L → `place_net_label(2/3/0)` (:5606/:5615/:5368), all
  `readonly_block()`-gated; drop funnel-logs `xschem instance ...` via log_placed_instance
  (receipt 28 has the full anatomy) → (i).
- Alt+L (:5355-5357) → `addlabel::open` (0122 form): form drop path, see receipt 27 — the
  sweep classifies the form's drop logging, don't re-derive.
- q/Shift+Q `edit_property(0/1)` (:5627-5635, :5654-5657): editprop core self-logs the
  committed edit as `xschem setprop .../ xschem set sch<X>prop` (receipt 29, 0063 atom 10)
  → (i). The dialog-open itself is not an edit.
- Ctrl+Shift+V netlist_type cycle (:6005-6010): unlogged, ungated CONFIG toggle (not a
  schematic edit) → candidate `stay-raw-document`; classify, don't fix.
- 'C' arc/circle gesture arms (:5068-5096): drop self-logs `xschem arc` (actions.c:4476)
  → (i).

Arms the scout did NOT walk (the sweep must): b, d, D, e, E, f, F, h, i, I, m, M, N, o, O,
r, R, s, S, t, T, u, w, W, x, X, z, space, '_', '$', '=', '+', '-', XK_Return, XK_Escape,
XK_Tab, XK_ISO_Left_Tab, arrows, XK_BackSpace, XK_Print, XK_Insert, '*', '\\', '>', '<',
'?', XK_slash, ':', ';', '~', '|', and everything from :6489 to the switch end. Also note
migrated-away cases exist only as comments (A, B, g/G, H, k/K, n, U, y, Z) — record them in
one "fully migrated" line each, evidence = the comment.

## RECEIPTS TO REUSE (do not re-derive what they verified)

doc/claude/refactor_b_batch/receipts/: 07 (make_sch_from_sel), 12 (cut — Ctrl+X anatomy +
ctx-pick-7 dedup web), 13 (copy), 14 (descend), 15 (descend_symbol), 16 (go_back),
18 (save), 19 (saveas), 20 (reload), 21 (print_hilight_net — j/J family chords, mode
mutability split), 22 (make_symbol), 23 (make_sch), 26 (arc), 28 (net_label — the three
place_net_label keys + funnel), 29 (edit_vi_prop — q/Q + verb-noun pick 11). Cite receipt +
line when a receipt already proved a row's class; fresh source check only for arms no
receipt covers.

## SWEEP PROTOCOL

1. `grep -n "case '\|case XK_\|default:" src/callback.c` bounded to the switch
   (:4903-:6529 today) → the authoritative arm list. Walk top-to-bottom; no skipping.
2. For each arm, read the body; one row per state/rstate branch. Columns:

   | Chord | case:line | Effect (callee) | Mutates | RO-gate | Class | Evidence | Action |

   - Mutates: `sch` (schematic objects/props), `cfg` (config/mode), `no`.
   - RO-gate: `key` (readonly_block in arm), `core` (gate in callee/perform_action), `none`,
     `n/a` (non-mutating).
   - Evidence: file:line of the log site / perform_action / receipt §.
   - Action (per-key recommendation, pick ONE): `route-via-audit-§32` /
     `stay-raw-add-selflog` / `stay-raw-document` / `gate-only` / `none`.
3. Cross-ref `src/keybindings.csv` (bound chords dispatch BEFORE the switch — a case arm
   shadowed by a binding row is dormant; mark it `dormant-shadowed`, evidence = the csv row)
   and `src/actions.csv` (accel column) for orphan accels with no keybindings row.
4. Count the results: N = class-(iv) rows, M = class-(v) rows. These go in the commit
   message and the issue header.
5. Verify completeness: every `case` label in the grep output appears in the table exactly
   once (or in the "fully migrated" list).

## EDITS (docs only)

1. **Rewrite doc/claude/issues/0068-unmigrated-legacy-switch-keys-not-logged.md**: keep the
   header/history block, add a dated "2026-07-XX definitive inventory (batch item 8)"
   section; replace stale §3 with (a) the class-(iv) list, (b) the class-(v) bug list
   (each (v) row: open a numbered issue OR record "candidate — needs its own issue" —
   opening new issue files for (v) rows IS in scope for the docs commit), (c) a pointer to
   the full table. Set Status: if class (iv) is empty → CLOSED with rationale; else OPEN
   with the surviving list replacing the stale one.
2. **If the full table exceeds ~60 rows** (likely): put it in
   doc/claude/code_analysis/legacy_switch_key_inventory_0068.md and keep only the
   (iv)/(v) lists + counts in the issue. Cross-link both ways.
3. **Memory**: add the item-8 detail line to the auto-memory action-logging.md batch block;
   MEMORY.md index line stays one short line (update only if the batch line already exists).

## COMMIT

Explicit file list ONLY (the issue file + optional code_analysis doc + any new (v)-class
issue files). NEVER `git add -A`/`commit -a`. Message:

```
docs(0068): definitive legacy raw-key inventory - N unlogged, M ungated

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

(substitute real N/M counts).

## VERIFY-STAGE ADAPTATION (for the verifier, recorded here per plan)

Docs deliverable: SKIP run-test/reproduce/full_audit. Instead: (a) adversarially spot-check
8 sampled inventory rows against source — mix all classes incl. at least one (iv), one (v)
or the explicit "M=0" claim, one `dormant-shadowed`, one funnel-(i); (b) confirm the commit
touches ONLY the declared docs files; (c) confirm every switch case label appears in the
inventory (completeness grep).

## DISCIPLINE

- NO code changes, NO test runs. C89/alloc rules moot but binding if violated.
- Re-verify every anchor line cited above before writing it into the inventory.
- Do not touch junk dirs (`_nhangle_*`, `_allm_*`, ...) or anything outside the declared
  docs files.
- Ambiguous arms: record as `AMBIGUOUS` with the evidence for both readings — a sweep
  cannot balloon; ambiguity is data, not a blocker.
