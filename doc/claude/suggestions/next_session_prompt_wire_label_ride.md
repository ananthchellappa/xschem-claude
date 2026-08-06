# Session prompt — implement the wire-label ride (spec `wire_label_ride.md`)

Paste everything below the line into a fresh session.

---

Implement `doc/claude/specs/wire_label_ride.md`. It is complete, decisions are settled, and the
corpus preflight is already done — do not re-litigate the design or re-run the scans.

**Read first, in this order:**
1. `doc/claude/specs/wire_label_ride.md` — the spec. §5 is the design, §11 is four verified
   hazards that will bite you, §12 lists what is genuinely still open.
2. `doc/claude/WIRING.md` — §7 landmines and §10 (CI cannot catch a fluid regression).
3. `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md` — why the instance
   model is being kept rather than replaced.
4. Issues **0220** (S0 prerequisite), **0227** and **0228** (both partly superseded — see §8 of
   the spec before touching either).

## Goal in one paragraph

A `type=label` instance keeps its `PINLAYER` pin, keeps sitting on the wire, and keeps naming
the net exactly as today. Its pin stops acting as **copper geometry**: it no longer splits a
wire, no longer blocks a collinear merge, no longer mints a kissing stub. In exchange, a
per-gesture in-memory rider set carries the label onto its wire's new geometry when the wire
moves, rotates or flips. Nothing changes on disk, in any `.sym`, in `netlist.c`, in `xWire` or
in `xInstance`. `XSCHEM_FILE_VERSION` stays `1.3`.

## Environment you must assume

The user runs `src/cadence_style_rc`, which sets `cadence_compat 1` (`:40`) and
`fluid_editing 1` (`:50`). `cadence_compat_sync` (`src/xschem.tcl:16260-16264`) force-enables
`autotrim_wires`, one-directionally. So **the split is live for this user**, even though
`autotrim_wires` defaults to 0 for everyone else.

Connected drag is gated on `cadence_compat` (`src/callback.c:7984-8005`), **not** on
`fluid_editing` — so "just turn off `cadence_compat`" is not an option, and "just turn off
`autotrim_wires`" would kill auto join/trim at all 8 `maintain_wire_segments()` call sites.
The fix must be label-targeted. **Test both `autotrim_wires` settings**; the default-config user
sees no change at all from the split guard.

## Start here — S0, no behaviour change

1. `fluid_count_label_shorts()` (`src/move.c:7997-8020`) — add the missing arm. Today the
   `for(w…)` loop `break`s on the first touching wire and counts nothing when **no** wire
   touches. Add: label had `node[0]` at START, touches no copper at END → increment a new
   `xctx->fluid_last_move_label_strands`, Tcl-mirrored. **This is the RED oracle and it must
   fail on today's tree** — a stranded label currently loses its net name with
   `fluid_last_move_violations = 0` and empty stderr. Write the failing fixture first.
2. Ship **issue 0220** (`signal_short()` inert on `-nohier` / Shift-N, plus its unreachable
   highlight branch). It is the only diagnostic for contested-name regressions and every later
   stage is blind without it.

Then S1 → S7 in the order given in spec §7. **S1 must ship the kissing guard and the leash
together** — the guard alone converts today's ugly-but-connected stub into a silent orphan.

## Five traps that will cost you a day each

1. **The apply site.** Put `label_ride_apply()` immediately after `src/move.c:9372`.
   **Not** `:9377` — `:9373-9374` zero `move_rot`, `move_flip`, `x1`, `y1`, `deltax`, `deltay`,
   which is everything the ride reads. A no-op ride still *looks* correct on an unrotated pure
   translate, so this bug ships silently.
2. **Owner-wire id resolution is two steps, both mandatory.** `wire_store_split()`
   (`src/store.c:404`) gives the new **head** a fresh id while the source keeps its id and is
   then rewritten into the **tail** (`src/check.c:719-721`). The captured id can still resolve —
   to a wire that no longer contains the label. So: resolve the id, **then `touch()`-verify the
   anchor**, and fall back to a geometric re-find otherwise. The fallback ships **enabled**.
3. **Placement order under rotation.** The label pin is not always at the instance origin —
   `xschem_library/devices/bus_connect.sym` has its pin at (10, −10), so rotating moves it ~28
   units. Order must be: pick the target pin coordinate on the final wire → apply rot/flip →
   solve `inst.x0/y0 = target_pin − ROTATION(new_rot, new_flip, 0, 0, pin_offset)`.
   Translate-then-rotate slides the label off copper, which the spec forbids.
   `get_inst_pin_coord()` is the forward authority — assert with it.
4. **The `+2` term in the rot bake is not optional.** Copy `src/move.c:8976-8993` verbatim,
   including the `rotatelocal` branch. A naive `(rot + move_rot) & 3` gets flipped odd-rotation
   labels wrong.
5. **Skip labels already in the selection.** The shared ELEMENT commit at `move.c:8974-8995`
   already moves a user-selected label; the ride would move it a second time.

Also: the ride must clear `prep_hash_inst`, `prep_net_structs` **and** `prep_hi_structs`
(`move.c:8977`, `:8996-8998`). Omitting the last two leaves stale instpin-hash entries and
stale wire node names.

## Things that are decided — do not "improve" them

- **Do not edit `select_attached_nets()`** (`src/select.c:1723-1853`). It adds only wires; the
  invariant is documented at `src/callback.c:5827` and issue 0114's rigid-group pivot logic
  depends on it. In particular do **not** skip labels in its ELEMENT arm — that arm fires on
  `endpoint_near`, i.e. the end-of-stub label, where the grab stretches the wire and preserves
  the connection.
- **Do not change `IS_LABEL_SH_OR_PIN` or any membership macro.** ~25 call sites need the wide
  membership. Use the new `inst_is_netlabel()` predicate (`strcmp(type,"label")==0`) at the
  three call sites only. `ipin`/`opin`/`iopin` are real terminals and keep every behaviour.
- **Do not give labels zero `PINLAYER` rects.** That empties `inst[].node` and kills every
  hilight/plot/select path plus blank-label back-annotation. Rejected in spec §10 with reasons.
- **No leader line, no dashed indicator, no new layer.** The label is always in contact, so
  there is nothing to indicate.
- **Sliding a label past a wire end extends the wire, with no guard rails.** Resulting shorts
  are the user's concern — explicitly decided. Do not add a refusal or a warning.
- `point_on_wire_or_pin()` (`src/check.c:188`) stays label-aware — it is the Add-Wire-Label
  drop gate. The off-copper *warning* needs a separate self-excluding helper, because that one
  skips SELECTED objects and at load nothing is selected, so a label always self-matches.

## Test discipline

- New tests go beside the existing naming cluster in `tests/headless/`, named
  `test_<topic>_<issue>.tcl`. `tests/headless/test_label_ride.tcl` is specified in spec §6 #13.
- `tests/headless/test_wire_split.tcl` must be **re-authored, not re-run**: 21 label references
  and zero `res.sym` taps — the whole suite splits on a label, and there is no device-pin tap
  fixture to swap to.
- Fluid work needs `tests/headless/wireedit/run_wireedit.sh` run **by hand** (WIRING.md §10).
  Press **Allow 30m** or **Allow 2h** on the GUI gate panel once — never press Proceed per suite,
  and never use a bare `for` loop (it enrols in no gate).
- The R1 along-the-wire repro **must** use `autotrim_wires = 0`; autotrim's `check_includes` cull
  (`src/check.c:312-321`) silently eats the duplicate record otherwise.

## Already established — do not re-run

- **The split change is connectivity-neutral.** 0 of 5,393 `type=label` instances across 578
  `.sch` files sit in the risky geometry; a 244-schematic SPICE A/B at `autotrim_wires` 0 vs 1
  produced zero netlist byte differences while changing wire counts in 144 of 244.
- **Off-wire labels: 21 files, 91 labels (1.7 %)**, dedupes to 5 library designs and 11 test
  fixtures; `gf180mcuD/` is clean. The warning predicate must be **pin-aware** — 1,919 labels
  (36 %) sit on a device pin with no wire, the normal gnd/vdd idiom, and a wire-only test fires
  ~1,900 popups.
- Real helpers for the warning: `alert_` (`src/xschem.tcl:11729`, C form at
  `src/actions.c:2592`) and `ciw_echo` (`src/ciw.tcl:113`, metachar-safe form at
  `src/util.c:425-428`). No generic suppress preference exists; `alert_` has no checkbox slot.

## Open, and worth settling early

Spec §12 lists five. Two are cheap and affect scheduling:

- **Does the on-disk `.sch` change today when labels split?** One scan says 683 splitting label
  pins imply regenerating save baselines; `src/save.c:3886-3889` says the split is in-memory only
  and coalesce-on-save re-joins it. A 10-minute load+save A/B at `autotrim_wires=1` settles it.
  Do this **before** writing any "regenerate goldens" task.
- **Does the label ride visibly during a live fluid wire drag?** The corrected apply site is
  inside `if(!commit_now)`, so today: it snaps at release. Multi-step RUBBER drag (5 steps) vs
  single-step END with the same total delta, save both, diff.

## Deliverable for the first session

S0 landed: the failing strand oracle with its fixture, issue 0220 fixed with a regression test,
and a short note in the spec recording which of §12's open questions you settled. Do not start S1
until the oracle is red for the right reason.
