# Case sensitivity: how xschem folds names today, and how to support a
# case-sensitive ngspice

Status: **SHIPPED.** Parts 1 and 2 are the pre-batch analysis, written
2026-08-12; **Part 3 was rewritten 2026-08-18** and describes what the casemode
batch actually built (items 1–14, all landed, nothing pushed).

> ⚠ **PARTS 1 AND 2 DESCRIBE THE TREE BEFORE THE CASEMODE BATCH (2026-08-16),
> and their `file:line` citations are that tree's.** They are kept because they
> are the analysis the batch was planned from, not because they are current.
> Two of their statements in particular have been overtaken: `read_dataset()`
> no longer `strtolower()`s stored spice names (batch item 1), and
> `get_raw_index()` no longer probes `XXyy -> XXYY -> xxyy -> v(xxyy)` on one
> mutated buffer — it is one non-mutating ladder, exact then case-folded, then
> the same two `v()`-wrapped, then the same two with a leading `i(v.x`
> rewritten (batch item 2), declining rather than guessing when two stored
> names differ only in case.
>
> **The current site map is §3.3 below.** The live specs are
> `doc/claude/specs/raw_case_mode.md` (the file, the lookup, the senders, the
> viewer, backannotation, the netlister) and
> `doc/claude/specs/simulator_profiles.md` (profiles, probes, the run, the
> deck, the dialog). The rulings and their measurements are in
> `doc/claude/casemode_batch/DECISIONS.md` and `LEDGER.md`.

Motivating request: a build of ngspice that honours case everywhere (`EN`,
`en` and `En` are three different names, for nets and for everything else).
A net called `EN` on the schematic should reach the waveform viewer as
`v(EN)`, while every existing flow against a legacy case-folding ngspice keeps
working byte for byte. Assume ngspice offers some way to be asked which kind
it is.

Related: `doc/claude/specs/ase_l.md`, `doc/claude/specs/waveform_viewer.md`,
issue 0154 (`#`-marker strip), issue 0161 (hierarchy qualification).

---

## Part 1 — the current state: where case is folded

There is no global normalisation pass in xschem. The rule that is actually
implemented, spread over six sites, is:

> **lowercase at the boundary going OUT to ngspice; probe case-insensitively
> coming BACK.**

### The chain that turns schematic `EN` into `v(en)`

1. **The netlist keeps case.** xschem emits `EN` verbatim into the deck. The
   only fold on the netlist side is the *model* name — the trap the old
   Part 3 §F recorded; it is now narrowed, not removed, and lives in
   `doc/claude/specs/raw_case_mode.md` §14 (`model_name()`'s dedup key keeps
   its fold except under `distinguish`).

2. **ngspice folds silently.** Node names are case-insensitive and the
   rawfile's Variables section comes back all lowercase.

3. **The raw reader folds too.** `read_dataset()`, `save.c:1008`:

   ```c
   strtolower(varname);
   /* transform ':' hierarchy separators (Xyce) to '.' */
   ```

   so the whole `raw->table` hash is lowercase. This is a deliberate
   divergence from the VCD reader, which keeps names verbatim
   (`vcd_read.c:140` and its comment) because Verilog identifiers *are*
   case-sensitive and folding would silently merge two columns.

4. **Ctrl-4 (ASE-L Direct Plot) builds the expression.** `sod_click`
   (`ase_window.tcl:1903`):

   ```tcl
   set ex [ase::ui::sod_expr $kind [ase::ui::sod_qualify $kind $t $base]]
   ```

   - `sod_qualify` (`ase_window.tcl:909`) produces the hierarchical name —
     voltages via `xschem resolved_net`, currents as `v.` + the **lowercased**
     `sch_path` + the name.
   - `sod_expr` (`ase_window.tcl:862`) strips a leading `#` (issue 0154),
     lowercases, and wraps:

     ```tcl
     return "v([string tolower [string trimleft $token #]])"
     ```

   **Why it folds here rather than leaning on the reader's probe ladder** —
   the comment at `ase_window.tcl:839` says it: ngspice echoes `print`
   expressions lowercased, and `result_probe` (`ase.tcl:3284`) regexp-matches
   the log line *literally*, so only a lowercase token can ever earn a Value in
   the Outputs pane. The same token also goes into `.save` cards
   (`ase.tcl:3166`).

5. **The query side is forgiving anyway.** `get_raw_index()`, `save.c:2253`,
   a four-rung probe ladder:

   ```
   XXyy  ->  XXYY  ->  xxyy  ->  v(xxyy)     (plus an i(v.x…) fixup)
   ```

   so a mixed-case query still hits an all-lowercase table. The Tcl viewer
   mirrors it: `wviewer::resolve_signal_db` (`wave_viewer.tcl:2538`) and
   `wviewer::validate_rpn` (`:3237`) lowercase both sides and additionally try
   `v($lv)`.

   > **SUPERSEDED, 2026-08-16 (casemode items 2 and 5).** Both halves of that
   > last sentence are now false and the ladder above is not the shipped one.
   > `get_raw_index()` no longer mutates its query, the stored names are no
   > longer folded, and the two Tcl matchers are no longer two: they are one
   > pair of procs (`wviewer::name_index` / `name_lookup`) that mirror the C
   > ladder rung for rung, decline a folded key that two different stored names
   > answer (`DECISIONS.md` D2), and fold nothing on a `distinguish` database.
   > Their fold key is `wviewer::fold_key`, an **ASCII-only** `string map`, not
   > `string tolower`: the C authority is `strtolower()` (`util.c:1006`), a
   > byte-wise `tolower()` loop with no `setlocale` in the tree, so a
   > Unicode-aware fold would invent case collisions the engine does not have.
   > `doc/claude/specs/raw_case_mode.md` §9 and §12.

### The parallel C path (Ctrl-K hilight → graph)

Entirely outside ASE-L, same recipe, hand-written twice in `hilight.c`:

- `send_net_to_graph()` `:1584` — `resolved_net` → strip `#` →
  `strtolower(t)` per bus bit
- `send_current_to_graph()` `:1714` — `strtolower(path)` + `strtolower(t)` →
  `i(v.<path><name>)`
- the gaw / bespice bridges at `:1616` / `:1754` are identical

`sod_expr`'s own comment says it mirrors `send_net_to_graph`.

### Elsewhere

- Backannotation: `ngspice_backannotate.tcl:39` keys `$voltage()` by a
  lowercased node; `hspice_backannotate.tcl` lowercases at every lookup.
- `@spice_get_voltage` / `@spice_get_current` token expansion: `token.c`
  `strtolower(fqnet)` / `strtolower(fqdev)` at 4358, 4535, 4572, 4855, 4951,
  5036, 5065, 5126, 5217, 5258.

### Consequence worth knowing today

Mapping a schematic path onto a **VCD** name is not a case-folding problem.
VCD names stay verbatim, `get_raw_index` probes verbatim / UPPER / lower, so a
lowercase query **misses** a mixed-case VCD signal — the caller must use the
name the signal browser shows.

---

## Part 2 — the summary table

**Pre-batch. Every row of this table has moved** — §3.3 is the shipped map.
Kept because "the teeth are `save.c:1008`, not `sod_expr`" is the finding the
whole batch was shaped around, and it turned out to be right.

| site | file:line (2026-08-12 tree) | what it folds |
|---|---|---|
| pick → expression | `ase_window.tcl:862` `sod_expr` | the Ctrl-4 one |
| pick → hierarchical current | `ase_window.tcl:921` `sod_qualify` | `v.` + folded `sch_path` |
| raw **read** | `save.c:1008` `read_dataset` | every variable name |
| raw **lookup** | `save.c:2253` `get_raw_index` | probe ladder verbatim→UPPER→lower |
| hilight→graph (C, **not** ASE-L) | `hilight.c:1601,1639,1718,1758` | Ctrl-K path, 4 hard folds |
| viewer match (Tcl) | `wave_viewer.tcl:2538,3237` | both sides of the comparison |

**The teeth are `save.c:1008`, not `sod_expr`.** Fixing only `sod_expr` makes
`v(EN)` plot — `get_raw_index`'s UPPER rung finds `v(en)` by accident — but:

- the signal browser and the legend still show `en`, not `EN`;
- **`EN` and `en` collide.** Both fold to `en` and
  `int_hash_lookup(..., XINSERT_NOREPLACE)` silently drops the second. Silent
  data loss, on exactly the feature the case-sensitive build is being adopted
  for.

---

## Part 3 — what shipped

> **REWRITTEN 2026-08-18 by casemode batch item 15.** What stood here was the
> **design proposal** of 2026-08-12, written before any of it existed. It is
> not preserved verbatim — the specs below are the live account and keeping a
> second, stale one beside them is how a reader ends up implementing the wrong
> thing. What the proposal got **wrong** is preserved, in §3.9, because
> most of its recommendations were overturned by measurement and the next
> person to reason about this will otherwise re-derive them.
>
> Parts 1 and 2 above are **pre-batch history** and stay: they are the analysis
> the batch was planned from, and their line numbers are the 2026-08-12 tree's.
> §3.3 below is the current site map.

### 3.1 The rule, in one sentence

**Every reader stores the name the file spells; the *lookup* is what is
case-insensitive; and the only thing a mode still switches off is that
case-insensitivity.**

Nothing folds on read any more. `get_raw_index()` answers a query by trying the
exact spelling first, then a case-folded alias index over the stored names — and
**declines rather than guesses** when two different stored names fold to the same
key (`DECISIONS.md` D2). A `distinguish` database sets `Raw.case_sensitive` and
loses the folded rung entirely, because there `EN` and `en` are two real signals.

**Byte-identical for a stock user, by design.** A released ngspice writes
everything lowercase, so the deleted fold was already a no-op for it and the new
folded rung is never reached. `DECISIONS.md` **A1** makes `fold` the default at
every stage — profile, floor, dialog pre-fill — precisely so that a person who
runs `apt install ngspice` and never opens any of this sees no change at all.
Across fourteen implemented items the `full_audit.sh` diff moved **zero** test
statuses in either direction; the only growth is the **fourteen** suites the
batch added (`git log --diff-filter=A 577ef5bc..HEAD -- 'tests/headless/test_*.tcl'`
— 331 rows at the batch base, 345 now).

### 3.2 Where the detail lives

| question | document |
|---|---|
| what a raw file's names are, how a query resolves, what the mode flag is | `doc/claude/specs/raw_case_mode.md` §1–§9 |
| how a *file's* mode is worked out (four sources), and the global floor | same, §10 |
| the Ctrl-K / gaw cross-probe senders | same, §11 |
| the waveform viewer's Tcl matcher and its `Options ▸ Case Mode` control | same, §12 |
| backannotation, and `ngspice::ngspice_data` as a lazy view | same, §13 |
| the netlister's fold-collision warning and the model dedup key | same, §14 |
| the phantom `v(all)` / `i(all)` column | same, §15 |
| simulator profiles: `exe`, `args`, requested mode, `-n` | `doc/claude/specs/simulator_profiles.md` §1–§10 |
| the capability probe and the run probe, and the hard timeout | same, §11 |
| the profile-aware run and B4's mismatch policy (report vs REFUSE) | same, §12 |
| the expressions ASE-L emits from a pick | same, §13 |
| the three defences against a raw that is not a result | same, §14 |
| reading values back out of the run log | same, §15 |
| post-load current repair | same, §16 |
| the `Simulation ▸ Configure simulators and tools` dialog | same, §17 |
| **why** the shipped design differs from the plan | `doc/claude/casemode_batch/DECISIONS.md` (13 rulings) and `DESIGN_REVISION.md` |
| what each item measured, and what it did **not** verify | `doc/claude/casemode_batch/receipts/`, `LEDGER.md` |

### 3.3 The shipped site map

Line numbers re-grepped 2026-08-18. Where Part 2's table said "what it folds",
this one says what the site does now.

| site | `file:line` | behaviour |
|---|---|---|
| spice raw read | `src/save.c:1065` (`read_dataset`) | verbatim; the `strtolower(varname)` is **deleted** |
| VCD read | `src/vcd_read.c:139` | verbatim — its comment is now a statement of the rule, not an apology for a divergence |
| table read | `src/save.c` (`table_read`) | verbatim, unchanged |
| the lookup | `src/save.c:3334` `get_raw_index_in()`, `:3378` `get_raw_index()` | exact → folded alias → `v()` wrap → an **anchored, case-blind** `i(v.x`→`i(x` rewrite; never mutates the query |
| the alias index | `src/save.c:3205` `raw_fold_key()`, `:3215` `raw_build_fold_table()` | a **separate** table from `raw->table`, built lazily, dropped whenever `names[]` moves, poisoned (`-1`) on a D2 collision |
| the mode flag | `src/xschem.h:1192` `Raw.case_sensitive` | boolean; set only by `distinguish`; suppresses the folded rung |
| the mode words | `src/save.c:2136` `raw_case_mode_parse()` | the one place `fold` / `preserve` / `distinguish` / `0` / `1` becomes that boolean |
| file-mode resolution | `src/save.c:2532`ff, verb at `src/scheduler.c:10456` (the `"casemode"` argv test) | `xschem raw casemode` — explicit → `Option: casemode=` header → schematic comparison → sniff (off by default) → `unknown`. **Reports; never acts** |
| the read verbs | `src/scheduler.c:10363` (`raw read … -case`, the `"-case"` argv test), `:10703` (`raw case`, the `"case"` argv test), `:10095` `raw_case_reread()` | a *set* **re-reads the file** — folding is destructive, so a flag flip would lie |
| cross-probe senders | `src/hilight.c:362` `hilight_sender_case_mode()`, `:421` `sender_current_prefix()` | eleven folds gated (Part 1 counted four); the hierarchical-current prefix follows the **token's own first letter** |
| viewer matcher (Tcl) | `src/wave_viewer.tcl:2629/2651/2664/2689` (`name_rungs`/`fold_key`/`name_index`/`name_lookup`), `:2748` `resolve_signal_db`, `:3676` `validate_rpn` | one mirror of the C ladder, D2 included; `fold_key` is **ASCII-only**, because the C authority is a byte-wise `strtolower()` |
| viewer control | `src/wave_viewer.tcl:14447` `casemode_refresh`, `:14574` `set_case_mode` | `Options ▸ Case Mode`: shows the mode **and which source answered**, writes the explicit source only. Not persisted — issue `0425` |
| backannotation | `src/save.c:2155`ff (the lazy view), `src/xschem.tcl:3751` `ngspice::lookup` | `ngspice::ngspice_data` is a **read-traced view** over `get_raw_index_in()`, so while the C view is armed the Tcl `string tolower` + hand-rolled `v(...)` ladder is **gone** and every query goes to the one authority. **One gated fallback survives** — `v($name)`, the folded name, the folded name wrapped — running *only* when `xschem raw view_armed` says no C view owns the array, for the third, pure-Tcl publisher `ngspice::read_raw_dataset` (`src/ngspice_backannotate.tcl:39`, which folds its own keys and has no `Raw` to share). The gate is load-bearing: without it a `distinguish` database answers `En` with `v(en)`'s value (`raw_case_mode.md` §13.7b). **No mode branch exists anywhere in backannotation** |
| profiles | `src/xschem.tcl:2774`ff `sim_profile_set()` and the `sim_profile_*` family, persisted to `$USER_CONF_DIR/simrc` | `exe args casemode detected probed nospiceinit` on the existing `sim()` rows — **no new registry file** |
| probes | `src/xschem.tcl:3309` `sim_probe_once`, `:3503` `sim_profile_probe_capability`; `src/ase.tcl:606` `ase::sim_probe_run` | two probes, one mechanism parameterised by cwd; transport is a **batch deck**; one hard timeout bounding the whole probe |
| the run | `src/ase.tcl:4707` `run_cmd` | composes from the profile; `-D casemode=` emitted only for a **non-`fold`** request; B4 policy |
| pick → expression | `src/ase_window.tcl:961` `sod_expr` (mode is a **required** argument), `:1100` `sod_qualify` | the mode is the **run's request**, resolved once per gesture |
| the three defences | `src/ase.tcl:1572` `preflight_gate`, `:1511` `preflight_fix_session`, the `$sim_status` guard in `render_deck` (`:4532`), the content check in `attach_dbs` | a `.save` of an absent name is refused before launch; a `constants` raw is refused on **content**, never on `rc` |
| log read-back | `src/ase.tcl:4864` `result_probe` | exact line first, then one case-insensitive pass, declining on two differently-cased labels; off under `distinguish`; what the run **delivered** outranks what it asked for |
| current repair | `src/wave_viewer.tcl:2932` `repair_currents`, `src/ase_window.tcl:2224` | in memory only; the session is never rewritten |
| netlister | `src/node_hash.c:313` `netlist_case_collision_check()` (called from `src/spice_netlist.c:221`); model key `keep_model_case` at `src/spice_netlist.c:206`, `src/spectre_netlist.c:74`; the relay at `src/xschem.tcl:5936`ff, which parses the netlister's `differ only in case` warning | warns when **xschem and the simulator disagree about how many nets there are** — under `fold`/`preserve`, **silent under `distinguish`**, never an error |
| **still folding** | `src/token.c`, the six `@spice_get_*` branches | **not fixed** — issue `0420`. Agrees with the authority under `fold`/`preserve`, diverges under `distinguish` |

### 3.4 What a user actually gets

| their ngspice | what they see | what changed |
|---|---|---|
| stock `apt install` (46) | `v(midnode)` for a net drawn `MidNode` | nothing, deliberately (A1) |
| a case-capable build, no profile configured | `v(midnode)` | nothing — the request defaults to `fold` |
| a case-capable build, profile `casemode preserve` | **`v(MidNode)`** — schematic spelling in the browser, the legend and the deck | this is the feature |
| the same, `distinguish` | **`v(MidNode)`** as well — and `MidNode` and `midnode` would be two *different nets*. A downgrade **refuses the run** rather than merging them silently | B4 |
| any of the above, opening an old `.sch` whose graph says `node="v(en)"` | still resolves against a stored `v(EN)` | the folded rung; D2 declines only if the file really holds both spellings |

### 3.5 The phantom column: `v(all)` **and** `i(all)`

`DECISIONS.md` **C1**: leave it, document it, cite upstream. **No filter, no
warning** — verified by grep, nothing in `src/` mentions `v(all)`. The full
record, with the ruling and what would reopen it, is
`doc/claude/specs/raw_case_mode.md` §15. Re-measured for this item, 2026-08-18,
in `render_deck`'s own deck shape (`.save` cards outside `.control`, the analysis
as a control command, a **bare** `write <abs path>` naming no vectors):

| deck | `/usr/local/bin/ngspice` (46) | `build-ver_50` |
|---|---|---|
| `op`, exactly one saved **voltage** | `v(in)` **`v(all)`** | `v(in)` — clean |
| `op`, exactly one saved **current** | `i(v1)` **`i(all)`** | `i(v1)` — clean |
| `op`, two saved signals | clean | clean |
| `tran`, one saved signal | `time v(in)` — clean | clean |

Every note written before 2026-08-16 records only `v(all)`; **the current form
exists too**, and a one-output ASE-L session can hit either, because ASE-L emits
one `.save` per output row. The phantom carries the **same value** as the real
signal — a duplicate column under a wrong name — so it is cosmetic, not wrong
data. `tran`/`dc` escape because their sweep axis already makes the vector count
two; only `op` has no axis. Fixed on `ver_50` by upstream `0064`
(`25e891ec3`); **broken on every release**, so it is the installed base that
meets it. `.options savecurrents` also dodges it, by pushing the count past one.

### 3.6 Xyce is **UNVERIFIED**

There is no Xyce on this machine and its raw files have never been measured
here. Part 1's "Xyce writes `V(EN)` uppercase" is an **assumption inherited from
the 2026-08-12 proposal**, not a measurement. Two rulings follow from that, and
they are consistent rather than contradictory — do not flatten them into "we
support Xyce":

- **The reader adds no Xyce-specific fold** (`raw_case_mode.md` §5). Not because
  Xyce is believed to behave, but because **no measured way to identify a Xyce
  raw exists**: the header's `Command:` line is never parsed anywhere in `src/`,
  and `sim_is_xyce` inspects the *configured simulator command*, never the file.
  A fold gated on a heuristic would be a destructive transform applied on a
  guess.
- **The gaw *sender* keeps an uppercase fallback** (`raw_case_mode.md` §11,
  `hilight.c`). A sender may legitimately trust configured identity where a
  reader cannot identify a file. It uppercases unless the resolution says
  `preserve`/`distinguish`; `fold`/`unknown` are byte-for-byte unchanged.

What would reopen either: one real Xyce raw file, measured.

### 3.7 Known holes, and the issues this batch filed

```
0418  raw_add_vector() swallows a -1 and registers an all-zero column
0419  top-level @dev[param] currents are classed as nets and survive
      'hide device internals'
0420  token.c's six @spice_get_* branches fold the query before the one
      lookup authority -- they agree under fold/preserve, diverge under
      distinguish
0421  a SHIPPED EXAMPLE (xschem_library/examples/test_bus_tap.sch) carries
      VCC+vcc and VSS+vss, so the new netlist warning fires on it, truthfully
0423  a fold-picked output row goes stale under a later distinguish profile
      (NARROWED by item 10 -- the run now refuses and offers the correction --
      not closed: whoever builds the schematic-derived re-case pass closes it)
0424  ase::run_mode_advice tells a user who just configured a profile to
      configure a profile
0425  the viewer's Case Mode override is not persisted, and durability was
      never assigned to an item
```

**`0422` is a security issue and does not belong in a list.** `ase::expand_path`
(`src/ase.tcl:174`) expands `$VAR` in model / `.include` / `.lib` /
`pre_commands` paths taken **out of an ASE-L state file**, using
`subst -nocommands` — and that flag does **not** stop a command substitution
written inside an **array index**, because Tcl parses the index itself. So
**opening a state file someone else wrote can execute arbitrary commands.** It
is **pre-existing**, it was found by this batch and not caused by it, item 6
guarded only its own new field, and the three original call sites are still
unguarded.

Two further things the specs state rather than file. `xschem raw casemode`
**reports and never acts** — it has no behavioural consumer, by design (item 3
separated reporting from acting so that recording a mode could not rebuild a
database); item 5b closed the last untested reader kinds, VCD and `table_read`
(`CS107*`, `CS108*`). And the schematic-name comparison (source 3) has **no
cache** — measured at 147 ms for a folded hit on 2000 instances × 500 names — so
it must never be polled from a redraw.

**Eight `look` debts and one `:0` suite debt are open** (`tests/headless/owed.sh
list`) from items 5, 13 and 14. A `look` debt is cleared by the user and by
nobody else; a green suite does not discharge an eyeball.

### 3.8 Reference material

`references/casemode-distinguish-guide.md` is the **ngspice side** of this work:
how to run a deck under `-D casemode={fold|preserve|distinguish}`, what splits by
case and what never does, and the three silent traps under `distinguish`. It is
**tracked** (committed at `fc65f14a`, and the one tracked file in an otherwise
untracked `references/`), written against `build-ver_50`, and it is the right
thing to read before touching the simulator end. Its §9 addresses client programs — us.

**Three places our shipped behaviour deliberately differs from that guide's
advice, each because we measured something it did not:**

| the guide says | we do | why |
|---|---|---|
| probe with `printf … \| ngspice -p` (§9, "one spawn, no temp file") | probe with a **batch deck**, `-b <abs deck>` | measured mid-batch: `ngspice -p` opens `$DISPLAY`. On an exhausted X server it exits with no answer, and with `DISPLAY` **unset it dumps core**. A three-mode binary reported as supporting *none* purely because X was busy (`simulator_profiles.md` §11.2) |
| `-n` (`--no-spiceinit`) is recommended (§1) — carrying the guide's **own** caveat that `-n` discards your customisations too | **no `-n` by default**; a per-profile checkbox | not a disagreement about the hazard — the guide names it — but about the default. `DECISIONS.md` A2: a tool that silently strips a user's `.spiceinit` is worse than one that measures what it got, so we make it opt-in and **ask the simulator what mode it actually delivered**, because `~/.spiceinit` overrides `-D casemode=` either way |
| "`preserve` is very probably what you want" (§9) | **`fold` is the default everywhere**; `preserve` and `distinguish` are opt-in | `DECISIONS.md` A1 — the default has to be what a person gets from `apt install`. A `preserve` default on a stock binary means a requested-vs-measured mismatch, and therefore a warning, on every run forever for a user who asked for nothing |

One more thing the guide is right about and worth repeating: **never name
vectors on a `write` line** (upstream `0073`) — it writes two identical columns
with byte-identical names, which no filter can separate. `render_deck` complies.

### 3.9 What the 2026-08-12 proposal got wrong

Kept because each row cost real time, and because a reader who finds the old
proposal quoted somewhere else should be able to see which parts of it died.

| the proposal (§A–§F, deleted) | what shipped | why it changed |
|---|---|---|
| `Raw.case_mode`, three-valued, **gating** the fold in `read_dataset` | the fold is **deleted**; `Raw.case_sensitive` is a **boolean** set only by `distinguish` | `DESIGN_REVISION.md` §1–§4: the fold was never about display, it was about making a query resolve. Move the case-insensitivity to the *query* and the fold has no job left |
| a new `ase::caps` cache file `$USER_CONF_DIR/ase_caps`, plus an optional backend hook | the existing `sim()` rows, `simconf` dialog and `simrc` gain structured fields | `DECISIONS.md` B1: xschem already had a simulator configuration system; building a second one beside it was the mistake |
| a behavioural probe deck (`V1 EN 0` / `V2 en 0`, count the columns) | `-D casemode=<m>` per mode, three invocations, read `$curcasemode` back | `$curcasemode` reports the *current* mode, never the supported *set*, and A1 needs to know what a **request** yields. "Presence implies all three" was refuted (`simulator_profiles.md` §11.3) |
| `case_sensitive` as an ASE-L state key | `sim_profile`, naming a row; the mode lives on the **profile** | the mode is a property of a specific binary, not of a design (B1) |
| auto-detect: "*any* uppercase implies the producer preserved case" | four sources in order — explicit → header → **schematic comparison** → capital sniff, and the sniff is **last, off by default, and can never answer `fold`** | B2a: a sniff has no reference point. Comparing against a schematic whose true spelling we know also detects the third outcome — `v(MIDNODE)`, "this simulator has its own convention" — which a capital-sniff calls `preserve` and gets wrong |
| "an explicit flag wins … Xyce stays pinned to 0" | **no Xyce-specific fold** on the read path; an uppercase **fallback** on the gaw sender | §3.6 above. Nothing can identify a Xyce *file* |
| `sod_expr {kind token {csens 0}}` — mode **defaulted** | the mode is a **required** third argument | a defaulted mode is a *silent* fold, and a folded `.save` under `distinguish` is rc=1, zero vectors and "analysis not run" — the whole session's data. A missing argument is a loud Tcl error instead |
| `result_probe`: "add `-nocase` to the regexp — harmless" | a **ladder**: exact line first, one case-insensitive pass second, decline on two differently-cased labels, and off entirely under `distinguish` | the naive fix was re-run, not assumed wrong: `-nocase` on rung 1 reddens 10 checks, because `v(EN)`'s row takes `v(en)`'s number (ruling: `simulator_profiles.md` §15.3; the measurement itself: `casemode_batch/receipts/11-result-probe-nocase.md`) |
| §E "a free win": the VCD reader "simply sets `case_sensitive` to 1" | VCD gets the same verbatim storage and the same folded-alias lookup as everything else; `case_sensitive` means `distinguish`, not "this file has capitals" | conflating "the file kept its capitals" with "two spellings are two signals" is exactly the bug D2 exists to prevent — a `COUNT` query must resolve to **nothing** when a VCD holds both `Count` and `count`, not to an arbitrary one |
| "backannotation last, lowest risk: `token.c` … plus `ngspice_backannotate.tcl:39`" | backannotation became the **hardest** item (5b): a second lookup ladder in Tcl, deleted; `ngspice_data` rebuilt as a lazy view; **four** procs involved, not the two named. `token.c` is **still folding** — issue `0420` | the risk was in the opposite place from where the proposal put it. `ngspice::get_diff_voltage` had never returned a difference at all, and a third publisher of `ngspice_data` existed, in Tcl, that no analysis had noticed |
| "Default 0 everywhere ⇒ every golden test stays byte-identical" | **held** — fourteen items, zero audit statuses moved | the one thing the proposal got exactly right, and it is what made an unattended batch possible |
