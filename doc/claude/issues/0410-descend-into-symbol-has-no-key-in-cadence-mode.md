# 0410 — descend-into-symbol had NO key in cadence mode (FIXED: Ctrl-Y)

Status: **FIXED** by crew item **D11**, 2026-08-15. Reported by the human during the D1–D10
eyeball verification while checking D4.
Area: `src/cadence_style_rc` (data file, installed verbatim — `src/Makefile:198`).

## The gap

`src/cadence_style_rc` steals the `i` key for Create Instance and ends the binding in `break`:

```tcl
bind .drw <Key-i> {xschem create_instance; break}
```

Its own comment admits the cost: the `break` stops the event reaching the generic
`bind $topwin <KeyPress>` → C dispatcher (`src/xschem.tcl:14343`), which is the **only** key
route to descend-into-symbol (`src/callback.c` case `'i'` → `descend_symbol()`).
Shift-`i` is not a fallback — `callback.c` case `'I'` is insert-symbol/start_place_symbol.
`src/keybindings.csv` carries no descend row, so `xschem bind` cannot reach it either, and
`src/actions.csv:92` (`edit.push_symbol`, accelerator label `I`) has no binding-table row —
measured: `xschem bind key 121 ctrl canvas edit.push_symbol` fails with
`bind: unknown action 'edit.push_symbol'`.

Measured before the fix, under xvfb after `source src/cadence_style_rc`:

```
bind .drw <Key-i>          = {xschem create_instance; break}
bind .drw <Control-Key-y>  = {}
bind .drw <Control-Key-Y>  = {}
.drw bind sequences whose script names descend_symbol : 0   (of 44)
C binding-table rows naming descend                   : 0
```

So in cadence mode descend-into-symbol survived only on the Edit menu, the toolbar, the
canvas right-click (`callback.c:5120` retval 13) and the `e` chooser's symbol row.

## The fix

One data line plus its comment, in the hierarchy-navigation family of `src/cadence_style_rc`
(Ctrl-X descend schematic, Ctrl-Shift-X descend newwin-ro, **Ctrl-Y descend symbol**,
Ctrl-E return one level, Alt-E top, Alt-X last):

```tcl
bind .drw <Control-Key-y>       {xschem descend_symbol;           break}
```

No C change, no Tcl-proc change. `clone_canvas_bindings` (`src/xschem.tcl:14239`) copies it to
every new/detached canvas automatically, exactly as it does for Ctrl-E.

### Why Ctrl-Y

Cadence's own default for descend-into-symbol with an instance selected is Ctrl-Y, and `i`
cannot be given back because cadence mode needs it for Create Instance. Re-confirmed free at
all three layers before taking it: Tk (`<Control-Key-y>` and `<Control-Key-Y>` empty before and
after sourcing the rc, and in all three PDK rc copies); the C key switch (`case 'y'` migrated
out, `callback.c:8112`); the C binding table (the sole `y` row is `key 121 0 canvas
edit.toggle_stretch`, modifier 0, no ctrl variant). A tree-wide grep of `src/` and `utils/` has
exactly one Ctrl-Y-shaped hit — `utils/toggle_pins_netlabels.tcl:57`, a **commented-out**
suggestion for the *different* chord `<Control-Shift-Key-Y>`, not installed.

### Why the BARE verb, not a `cadence::` wrapper (decision, rung R2)

- `xschem descend_symbol` already refuses **out loud**: with nothing selected it returns `0`,
  sets `descend_error` = `no-selection` and `statusmsg` = `Descend symbol: select an instance
  to descend into` (the D4 / issue-0251 refusal channel, `b1326180`). `cadence::descend_into_inst`
  (`utils/cadence_nav.tcl:260`) is a **silent** gate plus `xschem descend` — it would lose that.
- The wrapper's gate accepts a strictly **smaller** set than the core. Measured: with instance
  `x1` **and** wire 0 selected, `cadence::one_instance_selected` returns 0 while
  `xschem descend_symbol` returns 1 and descends (`descend_pick_target` counts ELEMENTs).
  Wrapping would add a new silent refusal on a selection the core handles — against 0251's
  direction — and would give one verb two truths (key ≠ menu).
- There is no window-chain bookkeeping to mirror: measured, `xschem go_back` / Ctrl-E
  (`cadence::return_one_level`) unwinds a symbol descend back to the parent at `currsch 0` with
  no extra registration.
- The verb self-logs at the C core (`src/save.c:5714`), so a wrapper calling `log_action` would
  double-log.

**Rejected alternatives:** a `cadence::descend_into_symbol` wrapper mirroring
`descend_into_inst` (above); a `keybindings.csv` / C binding-table row for `edit.push_symbol`
(that changes the DEFAULT non-cadence key table globally, far outside a cadence-rc item);
omitting the trailing `break` (the generic `<KeyPress>` forwarder would then also dispatch
Control-y into C the moment a C ctrl-y row ever appears — every sibling in the family ends in
`break`); re-homing Create Instance to free `i` (destroys the cadence muscle memory the rc
exists to provide).

## Inherited seams — recorded, deliberately NOT fixed here

1. **`descend_readonly` is not honoured** by `descend_symbol()`. Measured with
   `descend_readonly 1` (set at `cadence_style_rc`): `xschem descend` → child `readonly=1`;
   `xschem descend_symbol` → child `readonly=0` (EDITABLE). The flag is applied at
   `src/actions.c:4097`, inside `descend_schematic()` only. Pre-existing and shared with the
   Edit menu, the toolbar and the right-click item — Ctrl-Y adds no NEW inconsistency, it gives
   a keyboard route to behaviour four paths already have. Filed as **issue 0412**.
2. **Two gates, two thresholds.** The scheduler branch requires `semaphore == 0`
   (`src/scheduler.c:3227`, refusing with a *silent* `descend_set_error("busy", …, 0)`) while
   the C key path requires `semaphore < 2` (`src/callback.c:7233`). A Tk bind takes the
   stricter scheduler gate, so under a live dialog Ctrl-Y is a silent no-op. Already filed as
   **issue 0253**.

## PDK copies: nothing to do

Re-verified: `sky130A/cadence_style_rc` (94 lines), `ihp-sg13g2/cadence_style_rc` (97) and
`gf180mcuD/cadence_style_rc` (77) contain **no `bind .drw` line at all** — no `Key-i` steal, no
`Control-Key-x`, no `Control-Key-y`. They layer `src/cadence_style_rc`, so they inherit Ctrl-Y
for free. Duplicating the bind into each would create three copies to drift.

## Tests

No new suite; rows were added to the two suites that already cover this ground.

- `tests/headless/test_cadence_descend_newwin_ro.tcl` (true headless, 11 → **21** checks):
  **CY1** the rc binds Ctrl-Y; **CY2** the body runs the *bare* `xschem descend_symbol`;
  **CY3** it ends in `break` like the family; **CY4** the `i` steal is untouched;
  **CY5** exactly one `bind .drw` line names `descend_symbol`; **CY10** no competing
  `<Control-Shift-Key-Y>` bind and no C-table ctrl-y row; **CY6** the shipped body (evaluated,
  `break` stripped) descends into `leaf.sym`; **CY8** Ctrl-E returns from it; **CY7** with
  nothing selected it refuses out loud on the 0251 channel; **CY9** the accept-set rail
  (instance+wire descends, the cadence gate refuses) pins the bare-verb decision.
  `--nogui` has no Tk at all (`info commands bind` is empty), so the chord is read from the
  shipped rc TEXT — the precedent set by `test_snap_bindkeys.tcl:262` and
  `test_keybind_snap_grid.tcl:84` — and the captured body is then **evaluated**, so the
  behaviour rows exercise the line that actually ships.
- `tests/headless/test_altf5_ciw.tcl` (live Tk, the existing `cadence_style_rc coexistence`
  block, 7 → **10** checks): **CYT1** the bind is installed and non-empty on `.drw` after the
  rc runs; **CYT2** the installed script names the bare verb; **CYT3** the `i` steal still
  reaches `create_instance` in the live widget.

Both suites are already registered in `tests/headless/full_audit.sh`; no harness change.

### Sabotage (all run, all caught)

| variant | rows that went red |
|---|---|
| S1 bind deleted (the pre-fix state) | CY1 CY2 CY3 CY5 CY6 CY7 CY8 CY9 CYT1 CYT2 |
| S2 empty body `{break}` | CY2 CY3 CY5 CY6 CY7 CY8 CY9 CYT2 |
| S3 renamed no-op callee | CY2 CY6 CY7 CY8 CY9 CYT2 |
| S4 `cadence::` wrapper swap (the rejected alternative) | CY2 CY5 CY6 CY7 CY8 CY9 CYT2 |
| S5 `i` steal removed instead of adding a chord | CY4 CYT3 |
| S6 second competing chord added | CY5 CY10 |
| S7 trailing `break` dropped | CY3 |

The first pass exposed a test defect and it was fixed before landing: a body that cannot run in
a bare interpreter (S2's `break` outside a loop, S3/S4's undefined command) **aborted the whole
suite** at the `eval`, so CY6–CY9 never reported. The eval is now wrapped (`cyeval` returns
`ERR:<msg>`), and CY8 additionally requires that the CY6 descend really happened (`currsch`
1 → 0), which it did not before — under S1, CY8 passed vacuously at `currsch 0`.
