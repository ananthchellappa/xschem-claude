# Lessons learnt — the action-registry / input-binding refactor

A living, **theme-organized** distillation of the transferable lessons from the
`feature/action-registry` work (Phase 1 → Phase 3d). The per-phase tutorials
(`tutorial_action_registry*.md`) tell the chronological story; this doc is the
cross-cutting "what we'd tell someone starting a similar refactor." **Append to it as
new lessons appear** — keep entries themed, not chronological.

Scope of the work, for context: move XSCHEM's input handling (mouse wheel, gestures,
~1600-line `handle_key_press` keysym `switch`) from hardcoded C `case` ladders to a
data-driven binding table (`device,code,mods,ctx → action_id`), remappable at runtime
via `xschem bind/unbind/bindings`, while keeping *behavior* in C. Menus + a command
palette are generated from a declarative `actions.csv`.

---

## 1. Behavior-preservation is the spine — migrate *exactly*, prove it *empirically*

The whole refactor only has value if it changes *nothing* observable. Every lesson
below is downstream of this.

- **Replicate the branch verbatim, don't "improve" it.** Copy the exact C call,
  including args, ordering, and seemingly-redundant lines. Examples: the `O`
  colorscheme act replicated the `dim_value`/`dim_bg` resets + `build_colors(0.0,0.0)`;
  `>` keeps its quirk line `draw_single_layer = rectcolor` that overwrites the `++`;
  the hilight commands keep their `redraw_hilights(0)`/`draw()` tail.
- **The convincing test is the observable, not the code.** For a behavior-preserving
  change, assert the *effect* (a tcl var flips, zoom changes, instance/hilight count
  moves) before and after — not that "the function is called". "I didn't touch the
  engine" is a claim; a green headless harness is evidence.
- **Check whether a "preserved" line is actually dead.** `y`'s local `enable_stretch =
  !enable_stretch` looked load-bearing but the function returned right after — only the
  `tclsetboolvar` escaped. Trace the lifetime before faithfully copying a mutation.

## 2. The dispatch gate and side effects — *position* matters, not just the predicate

The single most design-shaping trap. The table is consulted at the top of
`handle_key_press`, *before* the `switch`. Computing the event's context calls
`current_input_ctx → waves_selected`, which is **not pure** (mutates `graph_master`,
clears `GRAPHPAN`, reconfigures the cursor, can stop a measurement).

- **Gate the side-effectful work behind "did we actually migrate this chord?"**
  `key_chord_has_binding(code,mods)` is a cheap table scan that runs *first*; only a
  migrated chord ever reaches `waves_selected`. Without the gate, every un-migrated key
  (`g`, `k`, …) hovering a graph would acquire a side effect it never had. **The gate
  is the load-bearing idea.**
- **Consult graph context only when the chord has an `over_graph` row** (the d2
  refinement). A canvas-only key whose `case` you deleted would otherwise resolve to
  `OVER_GRAPH` over a graph, find no row, and silently do nothing. Compute context only
  where it can matter.
- **A guard whose value comes from its *position* relative to a side effect must
  migrate to the same position** (d1b). The old order was `if(sem>=2)break;` *then*
  `if(waves_selected){…}` — so at `sem>=2` the code did nothing *and* never touched
  `waves_selected`. The `idle_only` check therefore sits in the dispatch gate, *before*
  `current_input_ctx`. A flag checked *inside* `dispatch_input_action` (after context
  was already computed) would be too late. **Reproducing the boolean isn't enough;
  reproduce where it's evaluated.**

## 3. Exact chord vs family — the rule for *what you may delete*

A switch branch matches either an *exact* modifier state (`rstate==0`,
`rstate==ControlMask`, `EQUAL_MODMASK` = `==Mod1 || ==Mod4`) or a *family* (`rstate &
ControlMask`, `SET_MODMASK` = "has Mod1 or Mod4", or no mod check at all =
unconditional).

> **Delete a C branch only when the rows you seed cover *exactly* the chord(s) the
> branch matched, and nothing with different semantics runs before it in-branch.**

- **Exact → migrate + delete.** Seed one row per exact chord; delete the branch (or the
  whole case once every chord is a row). `f`, arrows' no-mod member, `n`/`U`, `k`/`K`.
- **Family → keep the case, or narrow the guard.** If you migrated one member of a
  family, keep the branch and let the gate shadow that member (NumLock+arrow still pans
  via the kept `XK_Up` arm). For `Ctrl+t` (`rstate & ControlMask`, a family) the exact
  `Ctrl+t` row was added *and* the guard **narrowed** to `(rstate != ControlMask) &&
  waves_selected(...)` — the row owns the exact chord, the guard serves the remainder.
- **Unconditional (no mod guard) → additive only.** `%`, `_`, `&`, `>`, `<`, `?`, `/`,
  `:` fire for *any* modifier. A whole-case-delete drops their modified-press behavior
  (e.g. `Ctrl+?`), so they can only be migrated additively (keep the case, add a mods-0
  row the gate shadows) — lower value, deferred.
- **A case can be part-exact, part-family — migrate the exact branches, keep the case
  for the family one.** `case 'j'` had three exact sem-gated branches (plain/Ctrl/Alt →
  `print_hilight_net 1/0/4`) and a fourth `SET_MODMASK && Ctrl` *family* branch (no sem
  guard). Migrate the three to idle_only rows, delete just those branches, and leave the
  case holding only the family branch. The kept branch keeps working because no exact
  row covers `Alt+Ctrl+j`, so it falls through to the switch. Don't let one un-migratable
  branch block the rest of the key.

## 4. Semaphore-sensitivity: represent it once, in the data (d1b)

Many branches start with `if(xctx->semaphore >= 2) break;` (unsafe during reentrancy).
The top dispatch runs *before* any per-branch sem check, so a sem-gated chord can't be
migrated naively. Solution: an `idle_only` flag on the **binding** (not the action —
`graph.forward` is shared and mostly not idle-only), checked in the gate before
`current_input_ctx`. At `sem>=2` an idle_only chord is skipped → falls to the switch
(its surviving `if(sem>=2)break`, or no case) → the old no-op.

- **The flag is per-*chord*, so one key can mix idle and non-idle rows.** `k` plain/Ctrl
  are sem-gated (idle) but `k` Alt (`select_hilight_net`) isn't — at `sem>=2` the idle
  chords skip while Alt-`k` still fires. Use `set_input_binding_idle` vs
  `set_input_binding` per chord.
- **Make a new internal property settable + dumpable, not just internal.** Exposing
  `idle_only` via `bindings dump` (` idle` suffix) and `xschem bind … [idle]` (a) lets
  the headless test prove the gate on an *unused-key probe* (the real chords' canvas ops
  are destructive), and (b) feeds the future cheat-sheet/CSV loader. Doing so also
  surfaced a latent bug: `set_input_binding`'s replace path didn't reset the flag, so a
  re-bind left it stale — fixed `xschem bind` to set it explicitly both ways.

## 5. Don't swap a function for its "equivalent" unless you've *read both*

A recurring trap: "there's a menu/Tcl command that looks like this key." It's a
hypothesis until you read the scheduler branch.

- **Verified identical → reuse the csv id Tcl-backed.** `n` already did
  `tcleval("xschem netlist -erc")` (byte-identical by construction); `U`/`u` = `xschem
  redo|undo` = `pop_undo(1|0,1)` + `redraw` = `draw()`; every batch-2 hilight command
  matched its C branch *including the redraw tail*.
- **Looks-alike but differs → write a C act or defer.** `e`: `xschem descend` =
  `descend_schematic(0,0,0,1)` but the key calls `(0,1,1,1)`, and `xschem go_back` adds
  an internal `semaphore==0` check the C `go_back(1)` lacks. Deferred rather than forced.
- **…and the rule cuts both ways: a deferred "collision" is a hypothesis too.** `Z` was
  deferred for months as "csv `view.zoom_in` = `view_zoom(0.0)` vs wheel =
  `view_zoom(CADZOOMSTEP)`, same id two behaviors" — but `view_zoom(0.0)` *defaults its
  factor to CADZOOMSTEP* (actions.c `factor = z!=0.0 ? z : CADZOOMSTEP`), so they were
  identical all along; d4a resolved the "collision" by reading both sides and doing
  nothing. Re-derive deferrals from the code before designing mechanism around them.
- **Translate to the *behavior*, not the *label*.** "Alt-F" is really Alt+`f`; an accel
  display string can be wrong. Bind/verify by keysym + observable, never by the
  decorative `accel` column.

## 6. Match the source's modifier convention exactly

`kmods = (key < 0xff00) ? rstate : state` — letter/printable keysyms strip ShiftMask
(`rstate`), named keys (arrows, Tab) use raw `state`. A "cleaner" uniform rule would
change behavior. `EQUAL_MODMASK` (`==Mod1 || ==Mod4`) → **two** rows (`Mod1Mask`,
`Mod4Mask`). One source condition can map to several exact rows.

## 7. A migrated action gets no `handle_key_press` locals — read the source of truth

`act_*(const ActionEvent *e)` can't see `c_snap`, `enable_stretch`, `infix_interface`,
the window path, mouse coords, etc. Read what the parameter was *derived from*:
`tclgetdoublevar("cadsnap")`, `tclgetboolvar("enable_stretch")`. And **check what a
command actually reads** before assuming it's un-migratable: `hilight_net` looked
mouse-driven but operates on the *selection* (`rebuild_selected_array`), so it migrates
fine; a genuinely mouse/coordinate-driven or modal placement op (`new_wire`,
`place_text`, `move_objects`) stays in C.

## 8. Only migrate what the data model can express

The binding table keys on `device,code,mods,ctx`. If a branch is conditioned on
something *not* in that tuple, it isn't migratable until the model grows an axis.

- **`cadence_compat`-gated** (`plain s`, `Ctrl+r`): the same physical chord means
  different things in different modes; an unconditional row would fire in the wrong
  mode. Deferred pending a mode axis.
- **Family-guarded** (`j`'s `SET_MODMASK && Ctrl`, `J`'s `SET_MODMASK`): can't be
  covered by finite exact rows → branch-migrate at best.
- **Lesson: re-derive the migratable set from the *code*, not from an earlier plan's
  count.** The "6 sem-first chords" were really 4; "migrate `j`" is really "branch-
  migrate `j`."

## 9. When you add a second *kind*, audit every place the old kind was a stand-in

Adding Tcl-backed actions (d1) broke the `xschem bind` validator, which used
`lookup_action_fn(id)` ("has a C fn") as a proxy for "id exists" — true until a kind
with no C fn appeared. Split it: `find_action_def` answers *existence*. **When you
generalize a model, find everywhere the narrower property silently meant the broader
one.**

## 10. Testing a behavior-preserving migration

- **Assert the effect through state you can read.** tcl vars (`enable_stretch`,
  `dark_colorscheme`, `orthogonal_wiring`, `netlist_show`), `xschem get` (`zoom`,
  `instances`, `wires`, `bbox_hilighted`, `semaphore`), or round-trips (`G`×2 then
  `g`÷2 returns `cadsnap`).
- **For destructive/dialog ops, prove the dispatch path another way.** Stub the Tcl
  proc as a counter (`update_schematic_header`, `tclcmd`, `schpins_to_sympins`); or
  prove the *gate* on a safe probe (bind an unused key, drive `xschem set semaphore`);
  or assert "row present + dispatches without error" (`toggle_ignore`). Don't key-press
  a confirm dialog (`clear schematic`) or a file-writer (`netlist -erc`) headless.
- **A sem-gated test needs a reversible, observable mutation.** undo/redo via instance
  count; hilight via `bbox_hilighted` (`-100 -100 100 100` = nothing hilighted). Reset
  `semaphore` to 0 afterwards — leaving it high wedges later checks.
- **Expect to narrow an older assertion every batch.** Adding a device/context/row
  almost always trips a hardcoded count or "no rows for X" check written before it
  existed: "6 rows" → "6 *wheel* rows"; "no modified-arrow rows" → "…no modified-arrow
  *canvas* rows"; "Group B has no canvas rows" → exclude the now-migrated `A`/`f`. This
  is healthy (the assertion was over-broad); narrow it to what's still true.
- **A pure function with a fiddly spec deserves a table-driven test** (e.g. the
  accel→keysym translation from Phase 2).

## 11. Data modeling (the Phase 1–2 foundations)

- **Single source of truth.** Once an action is a row in `actions.csv`, every view
  (menu, palette, cheat-sheet, future keybindings) is *generated* — fix a fact once.
  When the same fact lives in N places (`MIRRORED IN TCL`), the bug is the duplication.
- **Model the data after the real thing.** One table described all four menu-entry
  shapes; keep each `command` cell a single clean call.
- **The moment your format has a quoting rule, stop hand-rolling `split`** — use a real
  RFC4180-ish parser.
- **A generator must be idempotent** — re-running reproduces the file byte-for-byte, or
  it's not a source of truth.
- **"Data-driven" is a claim about *change*, not *origin*** — dispatch can stay in C;
  what matters is that the *binding* is editable data.
- **Generate every *view* from the live source, not a parallel copy.** The cheat-sheet
  (d3) was rebuilt to read `xschem bindings dump` (what the C dispatch actually does)
  instead of the decorative `actions.csv` `accel` column, which had drifted from the
  real keys. A view that reads a *second* description of the truth can disagree with it;
  a view that reads the truth can't. Test it by mutating the source and re-rendering
  (unbind a key → its row vanishes from the sheet).
- **A faithful view doubles as a gap-finder.** Rendering the dump made the not-yet-in-csv
  action ids glaringly visible (they show as `view.scroll_up` instead of a label) — that
  list *is* the d4 work-item, surfaced for free. And building it forced the `mods_name`
  Mod4/Super fix (d3a) that was only a latent cosmetic bug before. Generating a complete
  view flushes out the incompleteness elsewhere. **Then make the gap STAY closed by
  inverting the gap into an assertion** (d4a): once every bound id had a csv label, the
  smoke test that used to assert "C-only ids fall back to the bare id" became "NO bound
  id may fall back" — a freshly-coined C id without a csv row now fails the suite instead
  of silently rendering ugly.
- **Ship generated defaults with a drift-guard test.** d4b ships
  `keybindings.csv`/`mousebindings.csv` *generated from* the built-in C table
  (`save_input_bindings_file` over `bindings dump`). Two descriptions of the defaults
  (C seeds + files) would normally be a drift hazard, so the smoke test diffs the
  committed files against a fresh save every run — change the builtins without
  regenerating and the suite fails. A generated artifact is only trustworthy while
  something *checks* it was regenerated.
- **A metadata row is allowed to be partial — model it explicitly.** d4a's 15 new
  `actions.csv` rows have an EMPTY `command`: the behavior is C-backed and only the
  binding table can run it; the row exists for label/help. Rather than inventing a
  near-equivalent Tcl command per id (the `e` trap again) or a junk palette entry, the
  empty cell became part of the schema's meaning (palette skips empty-command rows;
  csv header documents it). Half-truths beat plausible lies in a source-of-truth table.
- **Idle-ness lives in two layers — keep their roles straight.** The csv `idle` column
  records the *action's* default ("this command needs an idle engine"), per-chord truth
  stays in the binding table (`bindings dump` / the file loader's idle field). The csv
  column is informational; nothing dispatches off it. Don't promote a per-chord fact to
  a per-action column and then *use* it as if it were per-chord.

## 12. Process / working rhythm that paid off

- **Scope → sign-off → short plan doc → implement → test → commit → update the doc
  chain.** Each batch: a plan doc mirroring the last, a code commit and a docs commit
  *separately*, small steps.
- **Migrate at chord granularity, in small batches** (3–5 chords). You never have to
  migrate a whole key at once; a key leaves the switch only when *every* chord it
  handled is a row.
- **Keep the old ladder as the fallthrough** until a key is fully data — reversible,
  incremental, stoppable at any commit.
- **Keep the doc chain current**: per-batch plan, the running tutorial, the refactor
  plan's checkboxes, project memory, and `next_session_prompt.md` (re-scoped for the
  following batch, with candidates + deferrals + reasons). A pivot (e.g. clean-key well
  drying → d1b) is proposed *with reasoning*.

## 13. Environment / tooling gotchas (XSCHEM-specific, save re-discovery)

- GUI runs under `DISPLAY=:0`; **capture stdout with `--pipe`**: `DISPLAY=:0
  ./src/xschem --pipe -q --script FILE`. Drive events with `xschem callback .drw <evt>
  <mx> <my> <keysym> <button> 0 <state>` (KeyPress=2, ButtonPress=4; ShiftMask=1,
  ControlMask=4, Mod1Mask/Alt=8). The **keysym** matches the switch, not display casing.
- The `xschem` Tcl dispatcher is `switch(argv[1][0])` on the subcommand's **first
  letter**, then an else-if chain — a new subcommand must go in the case for its first
  letter (`unbind` → `case 'u'`, not next to `bind`).
- `view_zoom(z)` divides zoom (zoom-in) and also shifts origin (zoom-toward-cursor), so
  the clean discriminator between zoom and pan is "did `zoom` change?". `view_unzoom`
  multiplies. There are getters (`xschem get zoom|xorigin|instances|semaphore|…`) and a
  few setters (`xschem set cadsnap|semaphore|…`) but not for everything.
- **`bindings dump` mods rendering** (fixed in d3a, commit `d8cf32bd`): `mods_name`
  renders `Mod4Mask` as `super` and `parse_mods` accepts `super`/`mod4`. (Before, Super
  rows printed mods `0` — a latent cosmetic bug since Alt-`h`, surfaced when d3 built the
  cheat-sheet from the dump.)
- **Startup ordering (xinit.c):** xschemrc is sourced (~:2742) *before*
  `Tcl_CreateCommand "xschem"` (:2845), which precedes sourcing xschem.tcl (:2883). So
  an `xschem bind` in xschemrc errors at source time — the supported file-remap path is
  `keybindings.csv`/`mousebindings.csv` (d4b), loaded from xschem.tcl top-level where
  the command exists. `xschem bind` itself needs no xctx (only `ensure_input_bindings`),
  so top-of-xschem.tcl is early enough.

---

*Maintainers: add a themed bullet when a batch teaches something transferable; cite the
concrete example (key/commit) so the lesson stays falsifiable.*
