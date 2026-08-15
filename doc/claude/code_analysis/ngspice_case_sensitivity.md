# Case sensitivity: how xschem folds names today, and how to support a
# case-sensitive ngspice

Status: **design proposal, nothing implemented.** Written 2026-08-12.

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
   only fold on the netlist side is the *model* name — see the trap in
   Part 3 §F.

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

| site | file:line | what it folds |
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

## Part 3 — the design

### The key call

**Case mode is a property of the RUN that wrote the raw file, not of the
binary on `$PATH` right now.** Upgrade ngspice, reopen last week's raw, and
consulting the current binary gives the wrong answer. So the flag lives on the
`Raw` struct and is set at read time.

Three consumers, three different lifetimes:

1. deck / expression generation → the current binary's answer
2. raw reading → the *producing run's* answer
3. lookup and matching → per-`Raw`, whichever database is being queried

### A. The probe and its cache

A new **optional** backend hook, `case_mode`. Do **not** add it to
`ase::register_backend`'s required list (`ase.tcl:369`) — that list hard-errors
on a missing hook and would break every third-party backend. Add a sibling
accessor:

```tcl
# {} instead of an error for a hook a backend may not implement.
proc ase::backend_hook_opt {sim hook} {
  variable backends
  if {![dict exists $backends $sim $hook]} { return {} }
  return [dict get $backends $sim $hook]
}
```

One resolver that everything else calls:

```tcl
proc ase::case_mode {state} {
  set ov [ase::state_get $state case_sensitive {}]
  if {$ov eq {0} || $ov eq {1}} { return $ov }        ;# explicit override wins
  set h [ase::backend_hook_opt [ase::state_get $state simulator] case_mode]
  if {$h eq {}} { return 0 }
  set r [$h $state]
  return [expr {($r eq {1}) ? 1 : 0}]                 ;# unknown -> legacy
}
```

Schema: append `case_sensitive` to `ase::schema_keys` **and to
`ase::omit_if_empty`**. The second half is mandatory, not tidiness — the
comment at `ase.tcl:41` spells out why: a key added later must not appear in
state files that predate it, or the two committed-golden byte-stability tests
break. So the "auto" value is `{}`, not the literal string `auto`.

Backend implementation, keyed on the binary `run_cmd` actually names:

```tcl
proc case_mode {state} {
  return [ase::caps_get [lindex [run_cmd $state {}] 0] case_sensitive]
}
```

`ase::caps_get` caches on `[file normalize [auto_execok $exe]]` plus mtime and
size, memoised in `::ase::caps` and persisted to `$USER_CONF_DIR/ase_caps`
(the same flat-dict idiom as the state files). **Never in the state file** —
it is a machine fact and state files get committed.

**The probe itself.** If ngspice offers a declared query, use it. Prefer a
*behavioural* probe as the fallback: it is immune to version-string lies and
works on both binaries today.

```
* xschem case probe
V1 EN 0 1
V2 en 0 2
.op
.control
  op
  write $probe_raw
  quit
.endc
.end
```

Legacy ngspice → the raw has one `v(en)`. Case-sensitive → two variables. One
~50 ms batch run, once per binary per machine.

### B. ASE-L consumers

`sod_expr` is documented as PURE and `tests/headless/test_ase_interact.tcl` H1
calls it with **no design loaded** — so pass the mode in, never look it up
inside:

```tcl
proc ase::ui::sod_expr {kind token {csens 0}} {
  set t [string trimleft $token #]
  if {!$csens} { set t [string tolower $t] }
  if {$kind eq {voltage}} { return "v($t)" }
  return "i($t)"
}
```

Defaulting to `0` keeps H1 and every shipped expression byte-identical.
`sod_click` (`ase_window.tcl:1903`) computes `[ase::case_mode $st]` once per
pick and threads it into both `sod_expr` and `sod_qualify`'s current arm.

`result_probe` (`ase.tcl:3284`): under a case-sensitive ngspice the echo comes
back as sent, so its literal regexp already matches. Under legacy, add
`-nocase` to the `regexp -line` — harmless there, and it removes the "only a
lowercase token can ever earn a Value" constraint for hand-typed outputs too.

### C. Carrying the mode to the reader

`ase::run_done` knows the state, so it records the run's mode beside
`last_rawfile` / `last_vcdfiles`. Then:

```
dp_finish → wviewer::attach_raw $key $rf $sim_t $vcds $csens
          → ase::attach_dbs                     (ase.tcl:1447)
          → xschem raw read $rawfile $sim_type -case $csens
```

Also drop a `<cell>_ase.raw.meta` sidecar: `last_run` is gone when the session
is reopened tomorrow, and the raw file outlives the run record.

### D. The C changes — these must land first

1. `Raw` struct (`xschem.h`) gains `int case_sensitive;`, default 0.
2. `read_dataset`, `save.c:1008`:
   `if(!raw->case_sensitive) strtolower(varname);`
3. `get_raw_index`, `save.c:2253`: when the flag is set, probe **verbatim and
   `v(%s)` only** — drop the UPPER and lower rungs. Keeping them would let
   `EN` silently resolve to `en`'s data, which is the bug being fixed. The
   full ladder is preserved when the flag is 0.
4. `scheduler.c:9823`: an optional trailing `-case 0|1` on `raw read`, plus a
   read-only `xschem raw case` so Tcl and tests can assert it.
5. `hilight.c` — the non-ASE-L Ctrl-K path. Four `strtolower` sites, the same
   one-line guard off `xctx->raw->case_sensitive`, falling back to a
   `MIRRORED IN TCL` variable when nothing is loaded.
6. `wave_viewer.tcl:2538` and `:3237` gate on `xschem raw case`.
   `validate_rpn`'s own comment declares its match rule is "`get_raw_index`'s,
   verbatim" — it has to track whatever C does, or expressions get accepted
   and rejected inconsistently.
7. Backannotation last, lowest risk: `token.c` 4358, 4535, 4572, 4855, 4951,
   5036, 5065, 5126, 5217, 5258 plus `ngspice_backannotate.tcl:39`.

**Auto-detect fallback**, for when no flag arrives with the file: legacy
ngspice writes the Variables section all-lowercase, so *any* uppercase letter
implies the producer preserved case and the reader should not fold. Zero
configuration, and it retro-fixes raws produced before any of this existed.
Caveat: Xyce writes `V(EN)` uppercase — so an explicit flag wins, the
heuristic applies only under auto, and Xyce stays pinned to 0.

### E. A free win

`vcd_read.c:140` already keeps names verbatim (Verilog `Count` ≠ `count`), and
its comment records the cost: `get_raw_index`'s folding ladder makes a
lowercase query miss a mixed-case VCD name. Once `case_sensitive` is per-`Raw`,
the VCD reader simply sets it to 1 and that documented cost disappears — the
mixed-signal path stops being a special case.

### F. Land order and traps

- **C first (§D), the ASE-L hook second.** The reverse order produces `v(EN)`
  expressions against a folded table: it works by accident via the UPPER rung,
  and it hides the collision bug.
- Default 0 everywhere ⇒ every golden test stays byte-identical.
- Fixture worth building: one deck carrying both `EN` and `en`. Assert **2
  columns** under mode 1, and **1 column plus a WARNING** under mode 0 — today
  that drop is silent.
- Cache invalidation test: swap the binary, mtime moves, re-probe.
- **Netlister trap, unrelated to plotting.** `spice_netlist.c:143`
  `model_name()` lowercases the `device_model` text to build a dedup hash key
  (the stored value is the verbatim text, so the *emitted* deck is fine). Under
  a case-sensitive ngspice, `.model NMOS` and `.model nmos` are two distinct
  models but hash to one entry, and the second is dropped from the deck. The
  same gate is needed there. `spectre_netlist.c:29` has the same shape.
