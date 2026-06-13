# Task

Execute **Phase D (identity)** for **instances** of the stable-object-handles
step-2 plan: session-stable instance ids stamped at the lifecycle funnel,
queryable from Tcl, test-driven red-first — alongside the existing name as the
human / cross-session handle.

Branch: `feature/stable-object-handles` (verify with `git branch --show-current`).
Phases A–C for instances are DONE:
- **Phase A** (`c181b325`) — characterization suite, 33 checks,
  `tests/stable_handles/inst_wrap.tcl` + `inst_body.tcl`, sensitivity-proven.
- **Phase B** (`0bcdae7a`) — `code_analysis/instance_lifecycle_census.md`.
- **Phase C** (`6771e985` IC1 death, `3ed836f1` IC2 bulk, `618737f0` IC3 birth;
  report `eb1e73b2`) — the funnel: `inst_delete_compact`, `inst_storage_reset`,
  and the **birth chokepoint `inst_register(n)`** in `src/store.c`. All four
  births funnel their count increment through `inst_register`; it currently
  does `(void)n; xctx->instances++;` — the `(void)n` placeholder is the exact
  spot Phase D stamps the id.

## The decision (already made — DO NOT re-litigate)

**`code_analysis/instance_identity_decision.md`** records the ratified choice:
**both** — a numeric `id` as the canonical *durable session* identity, with the
existing **name** kept as the *human / cross-session* addressing form, under an
explicit role contract:
- **`id`** — monotonic, never reused, NOT persisted; what `selection` returns,
  what `instance_index <id>` resolves, the durable machine handle.
- **`name`** — user-editable, file-persisted, reusable/renamable; the human and
  cross-session form; resolved by existing name-accepting commands + the new
  `instance_id <name>` bridge.

Read first, in this order:
1. `code_analysis/instance_identity_decision.md` — the decision + §7 Phase D shape
2. `code_analysis/instance_lifecycle_census.md` — "Facts banked for Phase D"
3. `claude_suggs/green_but_hollow_tests.md` — binding testing discipline
4. The wire Phase D commits (`dd0a56d6` RED, `6e0c6eaf` GREEN, `d539e30e` D3)
   in `tests/stable_handles/test_body.tcl` H1–H7 — the precedent to mirror

## Phase D1 (RED) — commit failing tests BEFORE any C change

Add to `tests/stable_handles/inst_body.tcl` using the `xcheck` XFAIL marker
(already in `inst_wrap.tcl`). New surface (two additive scheduler subcommands):

    xschem instance_id <name|index>   → id (or -1)   [polymorphic input via get_instance]
    xschem instance_index <id>        → current index (or -1)

Mirror wire H1–H7 as **HI1–HI7**, plus the **instance-specific** properties the
decision doc calls out:

| id | property |
| --- | --- |
| HI1 | created instance's id is > 0 and unique |
| HI2 | the §2e scenario: hold id(A), delete an *earlier* instance, `instance_index id(A)` still resolves to A (its index shifted — CHI7) |
| HI3 | delete A itself → `instance_index id(A)` = -1 (loud dangling) |
| HI4 | **no id reuse**: create→delete→create-at-same-auto-name (the `R37` scenario — placing res.sym auto-reuses the freed name) → the new instance gets a **fresh id** though the **name is the same**. This is the headline: name reuses, id does not |
| HI5 | memory-undo round-trip: id resolves after undo+redo |
| HI6 | copy/merge births (CHI4/CHI5 paths) get **fresh** ids (each is a birth through `inst_register`) |
| HI7 | disk-undo round-trip — **invalidate-on-restore** (settled, same as wire H7): held id → -1, restored instance carries a fresh id, name unchanged. Assert it (not XFAIL) since the behavior is already decided |
| HI8 | **id survives rename, name does not**: stamp id(A); rename A (via attribute edit — see note); `instance_index id(A)` still resolves, but the *old name* no longer does. (If a scripted rename path proves unreliable — `setprop instance <n> name=` was a no-op in probing — assert the weaker, still-true form: id is independent of the `name=` token, e.g. id unchanged after a prop edit that leaves name intact, and document the rename-via-GUI hazard in a comment.) |
| HI9 | `selection` instance row now carries the real id: `{instance <idx> <col> <id>}` with `<id> == instance_id <idx> > 0` |

**Also update CHI8c** (currently asserts the instance selection row's id is
`-1`, locking pre-Phase-D behavior). Phase D intentionally changes that to a
real id, so CHI8c must flip from `== -1` to `> 0 && == [instance_id <idx>]`.
Treat this as part of the GREEN commit (it is a characterization test whose
locked behavior is deliberately changing) and say so in the message.

## Phase D2 (GREEN) — implementation

- `unsigned int id` appended to `xInstance` (`xschem.h` ~line 609, near
  `instname`); per-context monotonic `inst_id_counter` in `Xschem_ctx`
  (beside `wire_id_counter`); init to 0 in `alloc_xschem_data` (`xinit.c`,
  next to `wire_id_counter = 0`).
- **Stamp inside `inst_register(n)`** (store.c): replace `(void)n;` with
  `xctx->inst[n].id = ++xctx->inst_id_counter;`. This is the whole point of the
  Phase C funnel — one line, one place. Verify the `(void)n` removal compiles.
- `inst_index_from_id(unsigned int id)` in store.c — **linear scan** (no
  side-table; the id rides in the struct so the array is authoritative under
  every shift/swap/undo, exactly like `wire_index_from_id`). Declare in
  `xschem.h` beside the inst funnel decls.
- Two scheduler branches (the `xschem_cmds_i` group for `instance_id`, and
  `instance_index` likely there too): `instance_id <name|index>` resolves the
  ref via `get_instance` then returns `.id` (use `%u`-safe formatting, or cast
  to `int` like `selection` did — `my_snprintf` does NOT handle `%ld`/`%u`
  cleanly; the wire/selection code used `%d`/`my_itoa`); `instance_index <id>`
  returns `inst_index_from_id`.
- Add the id to the instance row of `xschem selection` (scheduler `selection`
  branch): today the `case ELEMENT` leg has no id; set
  `id = (int)xctx->inst[i].id` so the row becomes `{instance <idx> <col> <id>}`.
- C changes need `make -C src -j8` before testing.

**Reference-convention sub-decision** (from the decision doc §6): ship the two
separate commands now (`instance_id` / `instance_index`) — do NOT overload one
"give me the number" command (id and index are both bare ints). Sigils
(`@id`/`#index`) are deferred to the future `xschem object` API. This is the
recommended path; only revisit if the user asks.

## Phase D3 — none needed

The disk-undo decision (invalidate-on-restore) is already settled for the whole
effort (wire D3). No new user decision in instance Phase D — proceed straight
through D2 to E.

## Phase E — close-out

- End-to-end probe in `code_analysis/introspection_probes/` (a `probe4.tcl`)
  re-running the §2e failure for instances side-by-side with the handle version
  **and** demonstrating the id-vs-name divergence: the `R37` reuse scenario
  where the name silently aliases but the id does not.
- Update `instance_identity_decision.md` status → implemented; mark Phase D done
  in the census; add a brief note to `tcl_introspection_wire.md` §3/§5 that
  instances now carry a stable id (the asymmetry section).
- Update `doc/stable_wire_handles.md` (or a sibling) if a user-facing mention of
  instance handles is wanted — at minimum, that `selection` now returns instance
  ids and `instance_id`/`instance_index` exist.
- Present the step-3 menu (don't pick): (a) the remaining graphical types
  (rect/line/poly/arc — per-layer addressing), (b) the uniform `xschem object`
  read API now that two types carry ids, (c) net-as-object, (d) action-logging
  issue 0005 (replay by handle, now feasible for wires+instances).

## Hard-won testing rules (each cost real debugging time — follow exactly)

- Instance suite: `cd src && timeout -s KILL 120 ./xschem -q --script ../tests/stable_handles/inst_wrap.tcl`;
  results `/tmp/sh_inst_test.log`; needs an X display; the 33 existing checks
  (minus the deliberately-updated CHI8c) stay green at EVERY commit.
- **Also run the wire suite** (`wrap.tcl` → `/tmp/sh_test.log`, 57 checks) and
  **file_open** (`tests/file_open_dialog/wrap.tcl` → `/tmp/qo_test.log`, 33) —
  the `selection` command and `delete`/`clear` paths are shared.
- **Green-but-hollow discipline**: every new test FAILS before the C lands
  (XFAIL); after GREEN, sabotage the stamp (e.g. make `inst_register` stamp a
  constant id) and confirm HI1/HI4 go red, then revert — prove the stamp is on
  the live path, as IC3 did.
- Fixture `mos_power_ampli.sch` = 117 instances. Create instances with
  `xschem instance res.sym <x> <y> 0 0 {name=AAA}`; auto-name with no `name=`.
  `get_instance`/`instance_id` accept name OR number (digits→index). There is
  **no** `xschem get_instance` Tcl command — resolve names via name-accepting
  commands. `instance_coord` appends a trailing newline (string trim).
- All edits on the /tmp fixture copy; `xschem set modified 0` before every load;
  modals already stubbed in the harness.

Commit per phase with the established style: `test(handles): …` (RED),
`feat(handles): …` (GREEN), `docs(handles): …` (E). One identity field, one
stamp line, two commands — the funnel did the hard part. Do not start step 3 —
Phase E ends with the menu presented.
