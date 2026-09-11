# ASE-L persisted STATE — as it exists today

Dossier for the ASE-L analysis-coverage plan. Area: the state layer of
`/home/analog/dev/xschem-claude/src/ase.tcl`, its readers/writers in
`src/ase_window.tcl`, and everything that assumes the analysis set is exactly
`{op dc ac tran}`.

---

## 0. How to read the source anchors in this document

**Two different anchor bases, and the difference matters.**

* `src/ase.tcl` line numbers are the **working tree**, which for this file is
  byte-identical to `HEAD` = commit **`5fb8f465`** on branch `fluid-editing`
  (`git status --porcelain` lists `src/ase.tcl` as unmodified). These are stable.
* `src/ase_window.tcl` line numbers in this document are **`HEAD:src/ase_window.tcl`
  (`5fb8f465`)**, *not* the working tree. The working tree copy is dirty and was
  being edited by another process *while this dossier was written* — measured
  `mtime 2026-09-09 18:48:37` against a wall clock of `18:50:14`, and the file grew
  from 7652 lines (HEAD) to 8005 lines (working tree) during the session. A
  working-tree line number taken now would be wrong by the time anyone reads it.
  **Every `ase_window.tcl:N` below is a HEAD number; the proc name beside it is the
  real anchor.** Re-derive with
  `git show 5fb8f465:src/ase_window.tcl | grep -n '<proc name>'`.
* `src/save.c`, `src/xschem.tcl`, `src/library_defs.tcl` are working tree =
  HEAD except `src/xschem.tcl`, which is also dirty — its one cited line is a
  vocabulary list, verified by content, not only by number.
* Tcl-semantics claims marked **MEASURED** were run against `tclsh 8.6.17` on
  this machine (`/tmp/…/scratchpad/t2.tcl`), not inferred from the manual.
* Everything in both repositories was READ ONLY. Nothing was built, edited or run
  that mutates either tree.

---

## 1. The complete current state schema, as a commented example document

This is a real, loadable state file. Every value shown is either a committed
on-disk value or the coded default; the annotations carry the type, the default,
and the line where the default is set.

```tcl
# ── ASE-L state file ────────────────────────────────────────────────────────
# ON DISK:  <lib>/<cell>/<view>/<cell>.state, where <view> is a `ngspice_state*`
#           view directory (library_defs.tcl:1147-1161 seeds it).
# FORMAT:   a FLAT Tcl list of key/value pairs, one `key [list value]` per line.
#           NOT a Tcl script — nothing is sourced (ase.tcl:529-547). Comments
#           are ILLEGAL: they would parse as list elements. The saver never
#           writes any (ase.tcl:526-528).
# ORDER:    canonical schema order (ase::schema_keys, ase.tcl:68-71), then any
#           unknown keys in `lsort` order (ase.tcl:614-633). A load→save round
#           trip of any state_save-produced file is BYTE-STABLE, and five
#           committed test rows assert that (F3/G3/R4/V4/R2, see §5.3).

version 1
  # int. Default 1 (ase.tcl:504). ⚠ WRITE-ONLY: `grep -n version src/ase.tcl`
  # finds exactly ONE occurrence outside comments — the default itself. NOTHING
  # in the tree reads it. See §6.

simulator ngspice
  # string, a BACKEND name (an ase::backends key). Default `ngspice`
  # (ase.tcl:505). This literal is the one permitted `ngspice` spelling outside
  # the ase::backend::ngspice namespace (ase.tcl:494-495, :24-25).
  # Selects the five-hook table: render_deck / run_cmd / log_file /
  # result_probe / raw_file (ase::register_backend, ase.tcl:~660).

sim_entry {}
  # OMITTED WHEN EMPTY (ase::omit_if_empty, ase.tcl:110). Default `{}`
  # (ase.tcl:506). WHICH REGISTERED PROGRAM runs the backend. Three values,
  # one decoder (ase::sim_choice_decode):
  #     {} / absent      -> no choice of its own; ase::sim_default runs
  #     none             -> deliberately the program on the PATH (issue 0932)
  #     {name <entry>}   -> that registry entry
  # A bare one-word value that is not `none` is taken as an entry name — a
  # hand-edited file is forgiving (ase.tcl:56-63). Added 2026-09-08, issue 1395.

design {lib gf180mcu_tests cell test_nfet_TRAN view schematic}
  # dict {lib <l> cell <c> view <v>}. Default `{}` (ase.tcl:507). The SCHEMATIC
  # this state simulates. `cell` is the basename of every run artifact
  # (deck_file / log_file / raw_file, ase.tcl:4830, :11134, :11145).

rundir {}
  # string path, `{}` = the global `::netlist_dir` (ase::rundir falls through to
  # `set_netlist_dir 0`, ase.tcl:4812-4821). Default `{}` (ase.tcl:508).
  # ⚠ ase::rundir has SIDE EFFECTS: it `file mkdir`s, and the empty arm rewrites
  # the global ::netlist_dir. Callers that must not do that read the raw key
  # (ase_window.tcl viewer_rawfile_relative, HEAD:~6450 comment block).

temperature 27
  # numeric. Default 27 = ngspice's own default (ase.tcl:509). Renders `.temp
  # <T>` UNCONDITIONALLY (ase.tcl:10577-10583). A non-numeric value is a
  # render-time `-code error`; the GUI validates at commit, so only a
  # hand-edited state reaches that arm.

models {{file {$::180MCU_MODELS/sm141064.ngspice} section typical}
        {file {$::180MCU_MODELS/sm141064.ngspice} section res_typical}}
  # LIST of dicts {file <portable-path> section <sec>}. Default =
  # ::ASE_DEFAULT_MODELS when set, else {} (ase.tcl:510; `set_ne
  # ASE_DEFAULT_MODELS {}` at ase.tcl:458). Renders `.lib <file> <section>`
  # (ase.tcl:10553-10555). `file` goes through ase::expand_path — VARIABLES
  # ONLY, parsed not evaluated (ase.tcl:~307-360 comment; issue 1239).
  # Seeded per-PDK: sky130A/cadence_style_rc:37, gf180mcuD/cadence_style_rc:44,
  # ihp-sg13g2/cadence_style_rc:54.

variables {{name Vgs value 3.3} {name Vds value 1.65}}
  # LIST of dicts {name <n> value <v>}. Default {} (ase.tcl:511).
  # Renders `.param <name>=<value>` (ase.tcl:10556-10558).

analyses {{type op enabled 1}
          {type dc enabled 0}
          {type ac enabled 0}
          {type tran enabled 1 step 1n stop 200n}}
  # ⚠ THE SUBJECT OF THIS PLAN. LIST of open dicts. Default is the FOUR-ROW
  # LITERAL at ase.tcl:512 — op enabled, dc/ac/tran disabled, in that order.
  # Full shape rules in §3.

outputs {{name id expr -i(v1) save 1 plot 0}}
  # LIST of dicts {name <label-or-empty> expr <text> save 0|1 plot 0|1}.
  # Default {} (ase.tcl:513). `save 1` renders `.save <expr>` (ase.tcl:10589-93)
  # AND a `print <expr>` inside .control (ase.tcl:10880-10885), whose log output
  # feeds the Outputs pane's Value column via result_probe.
  # `plot 1` is the waveform-viewer/auto-plot queue.
  # ⚠ THE ONE LOAD-TIME MIGRATION LIVES HERE — see §5.2.

save_all_v 0
  # 0|1. Default 0 (ase.tcl:514). 1 -> `.save all` ahead of the per-output
  # cards (ase.tcl:10585-10588).

save_all_i 0
  # 0|1. Default 0 (ase.tcl:515). 1 -> `.options savecurrents`, emitted
  # unconditionally, a duplicate of an explicit options row being harmless
  # (ase.tcl:10569-10574).

# save_op_params      ← ABSENT here, and ABSENCE MEANS ON.
  # OMITTED WHEN EMPTY (ase.tcl:110). Default `{}` (ase.tcl:516). ⚠ TRI-STATE
  # WITH INVERTED POLARITY since 2026-08-29, issue 0927 (ase.tcl:88-101):
  #     {} / absent  -> ON  (the default; what all 104 committed states carry)
  #     0 / no|false -> OFF (the ONLY thing a state file ever spells out)
  #     1 / anything -> ON
  # Decoder: ase::op_gate_on (ase.tcl:4971-4974) = `[string is false -strict $v]`.
  # Writer: ase::op_gate_value (ase.tcl:4985-4987) = `$on ? {} : 0`.
  # Gates the op_annot device operating-point `.save` block, and it is NESTED
  # with an `op`-analysis gate, not &&-ed (ase.tcl:6190-6194, issue 0636).

options {{name savecurrents value 1}}
  # LIST of dicts {name <n> value <v>}. Default {} (ase.tcl:517).
  # Render (ase.tcl:10559-10567): value absent or 1 -> `.options <name>`;
  # value 0 -> the row is SKIPPED; anything else -> `.options <name>=<value>`.
  # Edited through the shared two-column list dialog (`simopt`,
  # ase_window.tcl:118-119) — Simulation > Options….

includes {{file {$::180MCU_MODELS/design.ngspice}}}
  # LIST of dicts {file <portable-path>}; a BARE STRING entry is taken verbatim
  # as the path (ase.tcl:10541-10552). Default = ::ASE_DEFAULT_INCLUDES when
  # set, else {} (ase.tcl:518; `set_ne` at ase.tcl:464).
  # Renders `.include <file>` BEFORE the `.lib` models, so global `.param`s they
  # define are in scope when the models evaluate (ase.tcl:10537-10540).

pre_commands {{cmd {pre_osdi $::SG13G2_OSDI/psp103.osdi}}}
  # LIST of dicts {cmd <text>}; bare string taken verbatim. Default =
  # ::ASE_DEFAULT_PRE_COMMANDS when set, else {} (ase.tcl:519-520).
  # ⚠ ASYMMETRY: unlike models/includes there is NO `set_ne
  # ASE_DEFAULT_PRE_COMMANDS {}` anywhere in the tree — only an rc ever creates
  # it (ihp-sg13g2/cadence_style_rc:62). The `info exists` guard is what makes
  # that safe.
  # Renders at the HEAD of the `.control` block, ahead of the analyses:
  # ngspice's `pre_*` family runs before the netlist is parsed, which is the
  # only way to load a compiled Verilog-A module (there is no `.osdi` dot-card).

# cosim               ← ABSENT here; `{}` means "every default".
  # OMITTED WHEN EMPTY (ase.tcl:110). Default `{}` (ase.tcl:521). Mixed-signal
  # POLICY ONLY — it never lists the digital artifacts, which are DERIVED from
  # the netlist at run time (ase.tcl:39-42). Keys, read through
  # ase::cosim_policy (ase.tcl:7825-7842):
  #     build   auto|always|never   rebuild the .so before the run (default auto)
  #     trace   0|1                 build with -V so the shim writes a VCD (dflt 1)
  #     attach  0|1                 attach the VCDs after a run (default 1)
  #     vsupply <volts>             digital supply for default auto_bridge models
  #     bridges auto|0|1            emit default auto_bridge pre_sets (dflt auto)

viewer {open 1 sharedx 0 rawfile {} graphs {{traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}}
        {traces {{expr v(g) name {} vec v(g) color 4}} logx 0 logy 0 x1 0 x2 2e-07 y1 0 y2 3.3}}}
  # dict. Default {} (ase.tcl:522). The waveform viewer's persisted layout,
  # written by ase::ui::viewer_snapshot (ase_window.tcl:~7078 working tree) from
  # wviewer::snapshot (src/wave_viewer.tcl:4397-4445). Keys:
  #   open 0|1, sharedx 0|1, rawfile <path>, graphs <list>, mode, target,
  #   and (only when >= 2 tabs) tabs + activetab, plus the item-15 signal
  #   browser's own sub-dict.
  # ⚠ `rawfile` is stored RELATIVE to the state's rundir when it is under it
  #   (R602), which is what makes a state file movable.
  # ⚠ The tabs keys were added with NO version bump, and wave_viewer.tcl:4400-06
  #   states the compatibility argument in as many words: "An older build
  #   reading a new file sees the active tab and ignores `tabs`; a new build
  #   reading an old file finds no `tabs` and builds a one-tab viewer."

zz_unknown_future_key {carried through untouched}
  # NOT a schema key. Any key the loader does not know is PRESERVED by the merge
  # and re-serialized at the end in lsort order (ase.tcl:624-631). Pinned by
  # tests/headless/fixtures/ase_state_v1_pre_cosim.state and by
  # tests/headless/test_sim_casemode_registry.tcl:508-511 (`kept_unknown=1`).
```

### 1.1 Canonical key order (the serializer's own list)

`ase::schema_keys`, `src/ase.tcl:68-71`:

```
version simulator sim_entry design rundir temperature models
variables analyses outputs save_all_v save_all_i save_op_params
options includes pre_commands cosim viewer
```

`ase::omit_if_empty`, `src/ase.tcl:110`: `cosim save_op_params sim_entry`.

18 schema keys; 3 of them omitted when empty. `tests/headless/test_ase_core.tcl:191`
pins the exact set as an `lsort` comparison, so **adding any key reddens that row
deliberately** — it is a tripwire, not an accident.

### 1.2 Keys that are NOT in the state, and deliberately

* **The simulator BINARY registry** (`ase::sim_register` and friends, issue 0931).
  `src/ase.tcl:717` states the rule: *"WHY NOTHING GOES IN ase::schema_keys. The
  binary is a fact about this machine"*. It lives in `::ASE_SIMULATORS`/
  `::ASE_SIMULATOR` from an rc, then `$USER_CONF_DIR/ase_simulators`. Only the
  *choice* (`sim_entry`) is state.
* **Capability probe results** (`ase::sim_caps`, `src/ase.tcl:~124-133`): in
  memory, session-lifetime, *"NEVER written to disk"* — persisting them would
  cost a file format, a corruption arm and a staleness arm to save ~10 ms.
* **Run results.** There is no `results` key. The Outputs Value column comes
  from a per-session in-memory attr (`ase::session_getattr $key results`,
  used at `ase_window.tcl:1551`+). Results survive a restart only as FILES
  in the rundir (`<cell>_ase.raw`, `<cell>_ase.log`).
* **`sim_profile` — a key that EXISTED AND WAS REMOVED.** See §6.3.

---

## 2. State I/O mechanics

| proc | line | contract |
|---|---|---|
| `ase::state_get {state key {dflt {}}}` | `ase.tcl:307-310` | `dict get` with a default. **The whole tree treats states and rows as OPEN dicts through this one accessor.** |
| `ase::state_default` | `ase.tcl:502-523` | the v1 default dict |
| `ase::state_load {path}` | `ase.tcl:529-557` | file → dict **merged OVER** the defaults |
| `ase::bus_expr_bits {ex}` | `ase.tcl:577-591` | the one migration's helper |
| `ase::expand_bus_outputs {outputs}` | `ase.tcl:593-607` | the one migration |
| `ase::state_serialize {state}` | `ase.tcl:614-633` | canonical text; ALSO the dirty-compare form |
| `ase::state_save {path state}` | `ase.tcl:635-640` | `puts` the serialization |

### 2.1 `state_load` in full (ase.tcl:529-557)

1. `![file isfile $path]` → clean `-code error "ase: state file not found: …"`.
2. read whole file.
3. `catch {llength $content} len` → `"malformed state file (not a Tcl list)"`.
   **MEASURED:** `llength` on `a {b` raises `unmatched open brace in list`, so
   this guard is real, not decorative.
4. `$len % 2` → `"malformed state file (odd-length list)"`.
5. `set st [dict merge [ase::state_default] [dict create {*}$content]]` (`:542`).
   * **MEASURED:** `dict merge {a 1 b 2} {b 3 z 9}` → `a 1 b 3 z 9`. File wins on
     collision; unknown keys ride along; absent keys gain their default.
   * **MEASURED:** `dict create {*}{a 1 a 2}` → `a 2`. A DUPLICATE key in the file
     is silently last-wins. Nothing warns.
   * ⚠ The merge is **per top-level key, not recursive**. A file's `analyses`
     value REPLACES the default list wholesale — see §6.4, it is the single most
     important migration consequence for this plan.
6. `catch {dict set st outputs [ase::expand_bus_outputs …]}` (`:555`) — the only
   migration, deliberately `catch`ed (§5.2).

### 2.2 `state_serialize` (ase.tcl:614-633)

```tcl
foreach k $schema_keys {
  if {[dict exists $state $k]} {
    if {[dict get $state $k] eq {} && [lsearch -exact $omit_if_empty $k] >= 0} { continue }
    lappend lines "$k [list [dict get $state $k]]"
  }
}
# then every key NOT in schema_keys, in lsort order, unconditionally
```

Three consequences worth naming:

* `omit_if_empty` applies **only to schema keys**. An unknown key with an empty
  value is still written.
* A schema key absent from the dict is skipped — but after `state_load` or
  `state_default` every schema key always exists, so this arm is unreachable in
  practice.
* **The serialization is also the identity of a state.** `ase::session_dirty`
  (`ase.tcl:9420-9426`) compares `serialize(current)` against `serialize(saved)`
  byte-for-byte, and `ase::sessions_for_state` (`ase.tcl:9651-9661`) resolves a
  session by the same string. So *any* schema change that alters the byte output
  of an untouched state marks every open session dirty and breaks the reverse
  lookup. This is why `omit_if_empty` exists at all.

### 2.3 The session model (ase.tcl:9344-9480)

* `sessions` is a dict keyed `"lib/cell/view"` (`ase::session_key`, `:9352`);
  each entry is `{path <file> state <current dict> saved <disk dict> …}`.
* `ase::session_open` (`:9370-9378`): a re-open of a **dirty** session keeps the
  in-memory edits and only re-homes the path; a clean one reloads from disk.
* `ase::session_update` (`:9397-9414`) is *the* write path every GUI pane uses.
* `ase::new_session` (`:9840-9850`): an **untitled** session — `path {}`,
  `state = state_default` with `design` filled in, `saved == state` so it is not
  dirty until edited.
* `library_new_view` seeds a brand-new `ngspice_state*` view by writing
  `state_default` with `design` set (`src/library_defs.tcl:1155-1161`), with the
  comment *"seeded VALID (never an empty file — ase::state_load must not need an
  empty-file special case)"*.

### 2.4 What a run produces (one set of artifacts per STATE, not per analysis)

* deck  `<rundir>/<cell>_ase.spice`  — `ase::deck_file`, `ase.tcl:4830-4836`
* log   `<rundir>/<cell>_ase.log`    — `log_file`, `ase.tcl:11134-11140`
* raw   `<rundir>/<cell>_ase.raw`    — `raw_file`, `ase.tcl:11145-11151`

All enabled analyses share **one deck, one log, one raw**. Multi-analysis works
because the deck emits `set appendwrite` (`ase.tcl:10844`) and one `write` per
analysis (`ase.tcl:10985-10992`), so the raw carries several named plots, and the
reader picks by plot name. `ase::run_deck` deletes the raw before the run, because
append means the file must not pre-exist (`ase.tcl:10840-10843`).

---

## 3. How an analysis's arguments are stored TODAY

### 3.1 The shape

```tcl
analyses  <list of rows>
row       <open dict>
          type    <string>          ; REQUIRED in practice; nothing enforces it
          enabled 0|1               ; compared as `eq {1}` — see 3.4
          <per-type quick fields>   ; present only when non-empty
          <arbitrary extra keys>    ; from the Options… editor, round-tripped
```

Per-type fields as the four consumers see them:

| type | `anaargs` (summary order + nominal field list) `ase_window.tcl:80-81` | `chana_fields` (the dialog's quick fields) `ase_window.tcl:4075-4084` | what `render_deck` actually reads `ase.tcl:10952-10967` |
|---|---|---|---|
| `op`   | *(none)* | *(none)* | *(none)* — emits the bare word `op` |
| `dc`   | `source start stop step` | `source start stop step` | `dc <source> <start> <stop> <step>` |
| `ac`   | `points start stop dec`  | `points start stop`      | `ac dec <points> <start> <stop>` — **`dec` is HARDWIRED** |
| `tran` | `step stop`              | `step stop`              | `tran <step> <stop>` |

Three mismatches in that table are real defects-in-waiting for the plan:

1. **`ac.dec` is stored but never used.** `anaargs` lists it, the Arguments
   summary prints it, the Options… editor can set it — and the renderer emits
   the literal `dec` regardless. `ase_window.tcl:4073-4074` admits it: *"a subset
   of anaargs — `dec` for ac is render-hardwired and only reachable through the
   extra-options editor"*. So `dec 2` in a state file is a lie the GUI tells.
2. **No `.ac` variation other than `dec`** — no `oct`, no `lin`, and the field is
   named `points` (per decade) rather than ngspice's `n`.
3. **`tran` cannot express `tstart`, `tmax` or `uic`**; `dc` cannot express a
   second (nested) source. Both are single-line `dict get` renders with no
   optional-argument machinery at all.

### 3.2 Where per-type knowledge lives — four independent tables

There is **no single registry of analysis types.** The knowledge is spread across
four places that must be kept in agreement by hand:

| # | what it decides | site |
|---|---|---|
| 1 | which types the state seeds | `ase.tcl:512` (the `state_default` literal) |
| 2 | which types the dialog OFFERS | `ase_window.tcl:4107` `foreach t {op dc ac tran}` |
| 3 | which fields each type shows / summarises | `ase_window.tcl:80-81` (`anaargs`) and `:4075-4084` (`chana_fields`) |
| 4 | which types the deck EMITS, and in what order | `ase.tcl:10863`, `:10939`, `:10952-10967` |

Adding `noise` means touching all four; missing one fails **silently** (§7.3).

### 3.3 Reading and writing a row — the dialog contract

* `ase::ui::chana_row {key type}` (`ase_window.tcl:4086-4091`) returns **the FIRST
  state row of `type`**, or a fresh `{type <t> enabled 0}` stub.
  ⚠ *"extra same-type rows stay X-deletable in the pane"* — i.e. a second `dc`
  row can exist in the state and in the pane, but **the dialog can never reach
  it**. This is the structural blocker for "N analyses, several of the same type"
  (a DC sweep at two corners, three transients with different `tmax`, …).
* `ase::ui::chana_show` (`:4129-4154`) rebuilds the form; switching the radio
  DISCARDS in-form edits of the previous type by design (D4: *"deterministic, no
  hidden multi-type writes"*).
* `ase::ui::chana_ok` (`:4156-4195`) writes back:
  * merges `enabled` + the quick fields **over the original row dict**, so
    unknown/extra keys survive;
  * an **empty quick field DELETES its key** (`dict remove`);
  * finds the row by linear scan for the first `type` match; **appends a new row**
    if none exists.
* `ase::ui::chana_options` / `chana_x_ok` (`:4216-4261`, `:4316-4341`) are the
  extra-key editor: name/value pairs of everything in the row beyond
  `type`/`enabled`/quick fields. `chana_x_ok` REPLACES the whole extra set (so a
  Delete really deletes) and commits immediately, then the main OK merges only
  `enabled` + quick fields over the same row, so the two compose.
  `ase_window.tcl:4210-4214` records the limit: *"Extra keys round-trip through
  the state file and show in the Arguments summary … DECK emission of extra keys
  stays deferred (v1 limit, documented here)."*
* `ase::ui::toggle_flag` (`:942-958`) flips `enabled` from a pane checkbox click,
  preserving every other key.
* `ase::ui::delete_selection` (`:994-1017`) deletes rows from `analyses` by index
  like any other pane list. **So the four-row list is already variable-length in
  practice** — a user can delete `ac` today and the deck just loses nothing.

### 3.4 Validation — what exists, and where

**Exactly one validation rule exists, and it is in the GUI only.**

`ase::ui::chana_ok`, `ase_window.tcl:4165-4172` (rule "D6"):

```tcl
if {$en} {
  foreach f [ase::ui::chana_fields $type] {
    if {![dict exists $vals $f] || [dict get $vals $f] eq {}} {
      catch {::ase::echo "ase: enabled $type analysis needs a non-empty '$f'" error}
      return
    }
  }
}
```

Its stated reason (`:4152-4155`): *"an ENABLED analysis needs every quick field
non-empty, else render_deck's `dict get` would blow up at run time — reject with
the dialog kept up"*.

Everything else is unvalidated:

* **No type validation.** Nothing checks that `type` is one of the four, at load
  or at write. The Options… editor will happily add a key called `type`… no, it
  skips `type`/`enabled` — but a hand-edited file can carry any type at all.
* **No range/units validation** on `start`/`stop`/`step`/`points`. `stop 0` and
  `step -1` reach the deck verbatim.
* **No cross-field validation** (`start < stop`, `step` divides the span,
  `points > 0`).
* **No netlist cross-check.** `ase::preflight_scan` (`ase.tcl:4588-4620+`) walks
  **`outputs` only**. A `dc` analysis whose `source` names a device that is not
  in the netlist is never caught before the run — even though the machinery to
  catch it (`ase::netlist_map` / `netlist_map_resolve`) is right there.
* **No validation at load.** `ase::state_load` runs no schema check whatsoever.
* **No validation in `render_deck`** other than the bare `dict get`, which raises
  a raw Tcl error (`key "source" not known in dictionary`) rather than an ASE
  sentence — reachable from any hand-edited state.
* The only *other* render-time check in the whole block is `temperature`
  (`ase.tcl:10578-10581`).

`enabled` is compared as `[ase::state_get $a enabled 0] eq {1}` at every site
(`ase.tcl:3697`, `:6167`, `:7648`, `:10945`). So `enabled yes`, `enabled true`,
`enabled 01` all read as **disabled**. That is byte-exact, undocumented, and a
hand-edited state can hit it.

### 3.5 What happens to an unknown key on load

**Top-level unknown key:** preserved by the merge, re-emitted at the end of the
file in `lsort` order (`ase.tcl:624-631`), asserted by
`tests/headless/fixtures/ase_state_v1_pre_cosim.state`'s `zz_unknown_future_key`
and by `test_sim_casemode_registry.tcl:508-511`.

**Unknown key inside an analysis row:** preserved (the row is an opaque dict
value inside the `analyses` list). It is *displayed* by
`ase::ui::arg_summary` (`ase_window.tcl:1074-1090`) in its "unknown-key arm",
*editable* in the Options… dialog, and **ignored by the renderer**.

**Unknown analysis TYPE:** preserved in the state, shown in the pane, and
**silently dropped from the deck** — see §7.3, this is the sharpest hazard in the
whole area.

**Malformed row (odd-length dict):** **MEASURED** — `dict exists {type op enabled 1 stray} type`
returns **0**, not an error. So `ase::state_get` returns its *default* for every
key of a malformed row: `type` reads as `{}`, `enabled` reads as `0`. No error,
no warning, the row simply never matches any type and never emits. `state_load`
itself does not notice, because `llength` of the outer list is still even.

---

## 4. The 104 committed `.state` files

`git ls-files '*.state' | wc -l` → **104**, plus one fixture. Measured
distribution of the `analyses` line
(`git ls-files '*.state' | xargs grep -h '^analyses' | sort | uniq -c`):

* **Every one of the 104 has exactly four rows, of types `op dc ac tran`, in that
  order.** Not one has a fifth row, a duplicate type, a missing type, or a type
  outside the set.
* 21 are the bare default (`op` on, the rest off).
* The `dc` rows carry `source start stop step`; the `ac` rows carry
  `start stop points` and **never** `dec`; the `tran` rows carry `step stop`
  (in either key order — `{type tran enabled 1 stop 2u step 10p}` and
  `{… step 1n stop 200n}` both occur, which is fine, dicts are unordered).

These files are test data for five load→save byte-identity rows and for the model
QA benches of three PDK workareas (`sky130A/`, `gf180mcuD/`, `ihp-sg13g2/`).
They are the reason `omit_if_empty` exists and the reason the schema has never
been allowed to rewrite a file it did not have to.

---

## 5. Migrations that have actually happened

### 5.1 The strategy, stated in the source

`src/ase.tcl:494-501`, the comment directly above `state_default`:

> `version` **STAYS 1** when a key is added (spec E4). Nothing reads it, and
> `ase::state_load` merges the file OVER this dict, so a state written before a
> key existed gains it with its default automatically and keeps every key it
> already had. Bumping the number would buy nothing and would invite an equality
> test somewhere that then rejects older files. It is reserved for a change that
> an old loader could MISREAD, not for a new optional key.

So the whole compatibility mechanism is: **merge-over-defaults + preserve
unknowns + omit-new-keys-when-empty.** There is no migration framework, no
`upgrade_v1_to_v2`, no version dispatch.

### 5.2 The ONE data migration in the loader (`ase.tcl:544-556`, issue 0159)

```tcl
catch {dict set st outputs [ase::expand_bus_outputs [ase::state_get $st outputs]]}
```

A state saved before the bit dialog could carry one output row whose `expr` is a
whole bus — `v(a[1:0])` — which is not a valid ngspice vector and, if it is the
only `.save` in the deck, **aborts the run**. The migration expands such a row
per bit on load. It is idempotent (an expanded row is scalar and expands to
itself), and it is **deliberately `catch`ed**: *"opening a session must never FAIL
because a cosmetic migration tripped over an odd stored row … The failure mode of
the catch is 'no migration ran', which is exactly the pre-fix behavior."*

`ase::bus_expr_bits` (`:577-591`) is deliberately narrow — only a bare
`v(<label>)` with an explicit `[n:m]` range; the comma form `v(a,b)` is left alone
because it is also ngspice's DIFFERENTIAL voltage and expanding it would silently
destroy a hand-typed row.

**This is the template a future analyses migration should copy**: run it in
`state_load`, make it idempotent, and `catch` it.

### 5.3 The ledger of every schema change to date

`git log -L '/variable schema_keys/,/variable omit_if_empty/:src/ase.tcl'`:

| commit | date | change |
|---|---|---|
| `20cc4df9` | 2026-07-20 | **v1 born**: `version simulator design rundir models variables analyses outputs options includes` |
| `6230ca56` | 2026-07-21 | `+temperature` (UI v2 session scalar) |
| `76c4cffe` | 2026-07-21 | `+save_all_v +save_all_i` |
| `435a6fc9` | 2026-07-21 | `+viewer` (item 14, waveform-viewer persistence) |
| `c69b88de` | 2026-08-02 | `+pre_commands` |
| `4840d27c` | 2026-08-09 | `+cosim`; **`omit_if_empty` INVENTED** (`{cosim}`) and the serializer's skip arm added |
| `169495a4` | 2026-08-17 | `+sim_profile` (the simulator-profile layer) |
| `44f52f9a` | 2026-08-23 | `+save_op_params`; `omit_if_empty` → `{cosim save_op_params}` |
| `d3f97f01` | 2026-08-29 | **polarity flip** of `save_op_params` (issue 0927) — no key added, no file changed |
| *(the `annotate` merge)* | 2026-08/09 | **`−sim_profile` — a key REMOVED**; see §6.3 |
| `437a3add` | 2026-09-08 | `+sim_entry` (issue 1395); `omit_if_empty` → `{cosim save_op_params sim_entry}` |

Eight keys added, one removed, one polarity flip — and `version` was never
touched. **The `analyses` key's shape has not changed once since 2026-07-20.**

### 5.4 A change that was made *without* touching `schema_keys`

`wave_viewer.tcl:4400-4406` added `tabs` and `activetab` **inside** the `viewer`
value, gated on there being two or more tabs *specifically so that a single-tab
viewer serialises byte-identically* — otherwise every session would have been
marked dirty. Its comment ends: *"No version bump."*

This is the existing precedent for **growing a nested value** rather than adding
a top-level key, and it is the closest structural analogue to what the analyses
plan needs.

### 5.5 The polarity flip is the one migration that LOST information

`ase.tcl:97-101`, on `save_op_params`:

> ⚠ ONE CONSEQUENCE, AND IT IS NOT RECOVERABLE: before the flip, OFF was ALSO
> `{}`. A state a user deliberately unticked is byte-identical to one that never
> heard of the key, so it flips ON with the rest.

Worth carrying into the plan as a rule: **never reuse the empty value for two
different meanings across a schema change**, and if the default must invert, the
old default has to be *spelled out* first.

---

## 6. The versioning story, answered directly

**Is there a version field?** Yes: `version 1`, `ase.tcl:504`. It is present in
all 104 committed files and in every file the saver writes.

**Does anything read it?** **No.** `grep -n version src/ase.tcl` returns exactly
one non-comment hit — the default itself (`:504`) — plus its appearance in
`schema_keys` (`:68`). No comparison, no dispatch, no rejection, anywhere in
either `.tcl` file or the tests. It is a reserved slot, and the source says so.

**How has the schema been migrated before?** Additively, by merge-over-defaults,
eight times (§5.3), plus one data migration inside `outputs` (§5.2), plus one
nested growth inside `viewer` (§5.4). No versioned migration has ever run.

**What does a state file written by an older ASE-L do in today's code?**

* It **loads clean**. Every key it lacks arrives from `state_default`; every key
  it carries wins; every key today's code does not know is preserved.
* It **round-trips byte-identically** iff the keys added since it was written are
  all in `omit_if_empty` and empty — which is exactly what
  `omit_if_empty` was invented to guarantee. `test_sim_casemode_registry.tcl:495-511`
  loads `ase_state_v1_pre_cosim.state`, saves it, and asserts
  `identical=1 no_sim_profile_key=1 kept_unknown=1`.
* **It gains new defaults invisibly.** A pre-`temperature` file silently becomes
  a 27 °C bench; a pre-`save_op_params` file silently turns device-OP saving ON.
  Both were deliberate; both are also the mechanism by which a *badly chosen*
  default reaches every historical bench at once.

### 6.3 The only key ever REMOVED: `sim_profile`

Added `169495a4` (2026-08-17) as `{version simulator sim_profile design …}`,
removed at the `annotate` merge. `src/ase.tcl:3702-3720` is the tombstone:

> ALL of it is retired at the `annotate` merge, and the reason is not tidiness.
> `annotate` shipped a simulator REGISTRY … Keeping both would have left the
> user's simulator described by two stores that nothing kept in agreement.

`tests/headless/test_sim_casemode_registry.tcl:494-497` records the compatibility
outcome:

> The pre-batch fixture must still round-trip byte-identically. It could only do
> so before because `sim_profile` was in `ase::omit_if_empty`; the key is gone
> entirely now, so the round trip holds for a **stronger** reason — there is no
> 17th key to omit.

**The lesson for the plan:** a removed key does not break old files, because an
unknown key is preserved and re-emitted. Removal is *safe*; it just turns a
schema key into an unknown one. That is a genuinely useful property if the
analyses schema has to be reshaped.

### 6.4 The migration hazard the plan must design around

`dict merge` is **per top-level key**. When an old file says

```
analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
```

that value **replaces the whole default list**. Consequence: **if a future
`state_default` seeds a fifth analysis type, not one of the 104 committed benches
— and not one user's existing bench — will ever see it.** New types will only
reach old states through the GUI's Add path, or through an explicit load-time
migration in the shape of §5.2.

That is not necessarily wrong (Cadence's ADE does not silently add analyses to
your bench either), but it must be a *decision*, and today it would happen by
accident.

---

## 7. Blast radius: every place that assumes the analysis set is `{op dc ac tran}`

Classification key:
**(a) trivially generalisable** — a literal that becomes a table lookup with no
design decision.
**(b) needs real work** — a decision, a new mechanism, or a documented behaviour
change.
**(c) a fixed-order invariant that exists for a documented reason** — do not
reorder; the reason is quoted.

### 7.1 `src/ase.tcl` (clean = HEAD `5fb8f465`)

| # | site | what it assumes | class |
|---|---|---|---|
| 1 | `ase.tcl:512` | the default `analyses` list *is* the four types, in order | **(a)** — but see §6.4 for the migration consequence, and `test_ase_core.tcl:287` pins it |
| 2 | `ase.tcl:3695-3701` `n_enabled_analyses` | nothing — it counts every enabled row | **(a)** ✔ already generic. Its own comment: *"An enabled analysis whose type this backend does not recognise IS counted"* |
| 3 | `ase.tcl:6165-6172` `op_analysis_enabled` | `type eq {op}` | **(a)** legitimately about `op`; it gates the device-OP save block |
| 4 | `ase.tcl:7643-7654` `plot_sim_type` | `foreach type {op dc ac tran}` — returns `{}` for anything else | **(b)** — this is the string handed to `wviewer::attach_raw` and thence to `xschem raw read <file> <type>`. A `noise` row makes the viewer attach nothing, silently. |
| 5 | `ase.tcl:10518` (render_deck docstring) | *"one .control block from the enabled analyses in fixed order (op, dc, ac, tran)"* | **(a)** doc |
| 6 | `ase.tcl:10863` `set anorder {op dc ac tran}` | the emit order AND the universe of emittable types | **(c)** for the order, **(b)** for the universe |
| 7 | `ase.tcl:10929` `foreach type {dc ac tran op}` (printanchor) | which analysis the Outputs Value column reads | **(c)** |
| 8 | `ase.tcl:10939` `set anorder {dc ac tran op}` | the reorder when device-OP requests are live | **(c)** |
| 9 | `ase.tcl:10949` `if {$type eq {op}}` and `:10989` `if {$type eq {op} && …}` | device save-cards / bare device names ride the `op` write and no other | **(c)** |
| 10 | `ase.tcl:10952-10967` the `switch -- $type` | four arms, **no `default`** | **(b)** — the card-syntax table; see §7.3 |

**The documented reasons, quoted, for the (c) sites:**

*#6 / #8, the emit order and its one exception* — `ase.tcl:10845-10862`:

> The emit order is normally the fixed `op dc ac tran` this block has always used,
> and every deck that carries no in-`.control` device requests renders
> byte-identically (row E12 …).
> ⚠ THE ONE EXCEPTION IS NOT COSMETIC AND IS NOT REORDERABLE BY TASTE. When the
> per-device requests moved inside `.control` (issue 0964), they are asked for
> immediately before `op` — and ngspice's save list is sticky FORWARD ONLY:
> `unsave` does not exist and a later `save all` does not reset it (both measured,
> ngspice-46+). So `op` must be the LAST analysis or every analysis after it
> records the device numbers again, which is the 74.9 MB this change exists to
> delete.
> ⚠ AND `ase::plot_sim_type` NO LONGER MIRRORS THIS ORDER. Its own comment used
> to say it must, forever … Both readers pick their plot BY NAME out of the
> multi-plot results file, so nothing downstream depends on which analysis ran
> last.

*#7, the print anchor* — `ase.tcl:10900-10928` (issue 1243, ruled by the user
2026-09-02):

> WHY THE OPERATING POINT AND NOT "THE LAST ANALYSIS". The Value column is a
> SCALAR column: `result_probe` accepts `<expr> = <number>` and nothing else, and
> `print` reads whichever plot the simulator is standing in. On a multi-point plot
> `print VBG` emits a paged `Index time vbg` TABLE … The operating point is the
> only analysis in the set that yields a scalar …
> ⚠ TRANSIENT-ONLY IS STILL BLANK, deliberately and on the ledger.

*#9, the op-only device write* — `ase.tcl:10739-10745`:

> ⚠ THE OPERATING-POINT WRITE AND NOTHING ELSE. MEASURED: the same bare device
> name on a `.tran` or `.dc` write is SILENTLY WRONG — every device vector
> arrives dims=1 with one non-zero sample parked at index 0 holding the
> end-of-run value and 0.0 at all 208 remaining points, no warning, well-formed
> file. It round-trips exactly under `op` alone. Rows E5 and M1 are what stop the
> line being moved.

**Note that #6, #7 and #8 are three DIFFERENT orderings of the same four names,
each with its own reason.** Any generalisation must keep three separately
computable orderings — emit order, print anchor, and the op-last exception — not
one shared list.

### 7.2 `src/ase_window.tcl` (HEAD `5fb8f465`; working tree is dirty and moving)

| # | site | what it assumes | class |
|---|---|---|---|
| 11 | `:80-81` `variable anaargs` | the per-type field list and the summary order | **(b)** — the table to generalise; `ac`'s `dec` entry is already a lie (§3.1) |
| 12 | `:4075-4084` `chana_fields` | the dialog's quick fields per type; `{}` for `op` and for anything unknown | **(b)** |
| 13 | `:4107` `foreach t {op dc ac tran}` | **the entire discoverable analysis vocabulary of the GUI** — four radio buttons | **(b)** and the single most visible one |
| 14 | `:4086-4091` `chana_row` | "the FIRST state row of `type`" — one row per type is addressable | **(b)** — blocks N-of-the-same-type |
| 15 | `:4156-4195` `chana_ok` | same first-of-type indexing; appends if absent | **(b)** |
| 16 | `:4316-4341` `chana_x_ok` | same | **(b)** |
| 17 | `:765` `button $top.strip.ana -text {OP,TR}` | the action-strip label names two of the four types | **(a)** cosmetic. Its comment/tooltip echoes are `:47`, `:538`, `:792`, `:5503`, `:5514`, `:5548` |
| 18 | `:2499` `dp_finish`, `:6743` viewer restore, `:7322` `auto_plot` | `if {$sim_t eq {op}} { "op results have no sweep" }` is the ONLY type filter before `attach_raw` | **(b)** — an unrecognised type reaches `attach_raw` as `{}` (via #4) rather than as itself |
| 19 | `:828` `build_pane … ana {num type enable args}` | nothing type-specific — four generic columns | **(a)** ✔ already generic |
| 20 | `:1074-1090` `arg_summary` | `anaargs` order first, then unknown keys | **(a)** ✔ already generic — it *already* renders an unknown type's keys |
| 21 | `:994-1017` `delete_selection`, `:942-958` `toggle_flag` | index-based, type-agnostic | **(a)** ✔ already generic |

### 7.3 ⚠ THE SILENT-DROP PATH — the sharpest hazard

Put #2, #6 and #10 together and a state carrying an analysis type the renderer
does not know behaves like this:

1. `ase::ui::arg_summary` shows the row in the pane with its arguments. It looks
   configured.
2. `ase::n_enabled_analyses` **counts it** (`ase.tcl:3695-3701`, and its comment
   says so on purpose).
3. Therefore `set appendwrite` is emitted (`ase.tcl:10844`), and
   `ase::cap_report $sim [ase::n_enabled_analyses $state]` (`ase.tcl:7194`) may
   warn the user that their build *"keeps only the last analysis"* — a warning
   about an analysis that will not run.
4. `foreach type $anorder` **never visits the row at all**, because `$anorder` is
   the four-name literal. No `default` arm in the `switch` is even reached.
5. The deck is emitted, the run succeeds, `rc=0`, a raw is written — **and the
   analysis is simply absent.** Nothing is said at any level.

This is the exact failure class the ASE-L codebase repeatedly writes long comments
about ("under-emission in silence is the exact failure class this whole feature
exists to delete", `ase.tcl:6176`). **Any plan that grows the type set must close
this path first** — a `default` arm that refuses loudly, before the vocabulary
grows, is the cheapest possible RED-first step.

### 7.4 Tests, fixtures and committed data in the blast radius

| site | what it pins |
|---|---|
| `tests/headless/test_ase_core.tcl:287` | `"R1 analyses are the four types in order"` — asserts `state_default`'s literal |
| `tests/headless/test_ase_core.tcl:288` | `"R1 only op enabled by default"` |
| `tests/headless/test_ase_core.tcl:191` | the exact `lsort` of `schema_keys` — reddens on ANY new schema key |
| `tests/headless/test_ase_core.tcl:407-414` | D2: *"disabled analyses absent + fixed order"*, `op` before `tran` |
| `tests/headless/test_ase_core.tcl:~360-405` | D1: a **committed golden deck** for the nfet state |
| `tests/headless/test_ase_plot.tcl:142-153` | PH1: `plot_sim_type` = *"last enabled analysis in the fixed emit order"*, four rows |
| `tests/headless/test_ase_optier_0963.tcl` §E, §M, §P | E5/M1 (op-only device write), E11, E12 (byte-identical deck), P1/P2/P3 (print anchor) |
| `tests/headless/test_ase_dialogs.tcl:600-665` | the Choose Analyses dialog driven through the menu, the OP,TR strip and a row double-click |
| `tests/headless/test_ase_persist.tcl:259-265, 597-598` | `plot_sim_type` stubbed/asserted |
| `tests/headless/fixtures/ase_state_v1_pre_cosim.state` | the load→save byte-identity + unknown-key fixture |
| 104 committed `*.state` files | all four types, in order, every time (§4) |

Counted references to `analyses` per suite:
`test_ase_core.tcl` 14, `test_ase_window.tcl` 12, `test_ase_simcaps_0948.tcl` 11,
`test_ase_plot.tcl` 9, `test_ase_dialogs.tcl` 9, `test_wave_viewer.tcl` 6,
`test_ase_interact.tcl` 6, `test_ase_final.tcl` 5, `test_ase_preflight.tcl` 4,
`test_ase_persist.tcl` 3, `test_ase_optier_0963.tcl` 3, `test_ase_cosim.tcl` 3.

### 7.5 Outside ASE-L — what does NOT need changing

* **`grep -rn analyses src/ --include=*.tcl --include=*.c` finds the state key
  ONLY in `ase.tcl` and `ase_window.tcl`.** No C code and no other Tcl file
  reads it. The blast radius is genuinely confined to those two files plus tests.
  (`xschem_library/analyses/` is an unrelated symbol library — §8 — and
  `src/xinit.c:3348` only adds it to the library path.)
* **The C raw reader is already broader than ASE-L.** `read_dataset`,
  `src/save.c:957-1005`, maps `Plotname:` to `sim_type`:
  `transient analysis`→`tran`, `dc transfer characteristic`→`dc`,
  `noise spectral density curves`→`noise`, `operating point`→`op`,
  `integrated noise`→`op`/`noise`, and
  `ac analysis` / `spectrum` / `sp analysis`→`ac`. And `save.c:993-1004` has a
  **catch-all arm**: any other `Plotname:` becomes a `sim_type` equal to the
  literal plot name. Plus `save.c:1072-1074`: a multi-point `Operating Point` raw
  is PROMOTED to `sim_type dc`, with `req_sim_type` remembering what was asked
  (`xschem.h:1426-1434`, `scheduler.c:10457-10488`).
  → **Adding `noise` to ASE-L needs no C change at all.** Most other analyses
  will land on the catch-all arm and work as long as ASE-L asks for the right
  string.
* **`src/xschem.tcl:6911`** — the stock (non-ASE) graph dialog's Sim-type
  combobox already offers **nine**:
  `{dc ac tran op sp spectrum noise constants table}`. That is the vocabulary the
  rest of xschem already speaks, and ASE-L's four are a strict subset of it. A
  plan that grows ASE-L's set should agree with this list where they overlap.

---

## 8. Prior art already in this repository: `xschem_library/analyses/`

Not part of ASE-L, easy to miss because of the name collision with the state key,
and directly relevant. `xschem_library/analyses/` (GPL, © 2025 Arpad Buermen) is
a **visual analysis-setup symbol library**: one symbol per analysis, netlisted
into a `.control` block by `::analyses::netlister`, triggered by placing
`command_block.sym` exactly once.

Shipped symbols: `op ac acsp acstb acxf dc1d dcinc dcxf hb noise tran sweep
postproc verbatim command_block` (`ls xschem_library/analyses/`), documented with
a per-simulator support matrix in `xschem_library/analyses/README.md:33-47`.

What it already solves that ASE-L does not:

* **Per-type option bags as symbol attributes** with a declarative type code
  (`format_props` / `format_args`, `lib_init.tcl:36-90`), where each property is
  tagged `N` (name=value), `NV` (value only), `G` (emit `name given` if present),
  `SG`, `UNV`. `tran.sym`'s template alone carries
  `name only_toplevel order sweep step stop start maxstep icmode …` — i.e.
  optional arguments, which ASE-L's `dict get`-per-field render cannot express.
* **A dispatch table by type**: `format_analysis_<type>_spice`,
  `lib_init.tcl:560-641`. An unsupported analysis raises an explicit
  `error "acxf is not supported by Ngspice"` (`:610-611`) — exactly the loud
  `default` arm ASE-L lacks (§7.3).
* **Explicit ordering as data** — an `order` attribute per instance rather than a
  hardcoded list (`README.md:3`).
* **One `write <name>.raw` per analysis**, and for `noise` a two-file writer with
  `setplot previous` (`lib_init.tcl:622-627`) — i.e. it already handles the
  analysis whose results come in two plots, which ASE-L's single-raw model does
  not.
* **Named sweeps** as first-class objects (`sweep.sym`), chainable for
  multi-dimensional sweeps, with the ngspice limits documented
  (`README.md:25-27`).
* **`verbatim.sym`** — an escape hatch for arbitrary control-block text, gated by
  simulator.

⚠ It is also a **security landmine** already recorded in ASE-L's own source:
`command_block.sym`'s format is `tcleval([::analyses::netlister spice])`, so a
plain `getprop instance` read of it **executes the netlister**; that is why
`ase.tcl:10085-10100` reads formats with `instance_notcl`.

**Recommendation for the plan: read this library before designing ASE-L's
analysis table.** It is the same problem, solved once in this tree, by the author
of VACASK, with the ngspice/VACASK capability gaps already mapped.

---

## 9. Recommendation: how the schema should grow

### 9.1 The five load-bearing constraints any proposal must satisfy

1. **104 committed `.state` files must keep round-tripping byte-identically**,
   and five test rows assert it (F3/G3/R4/V4/R2). Any new *top-level* key must
   default to `{}` and join `ase::omit_if_empty` (`ase.tcl:72-102` writes the rule
   out in full).
2. **`ase::state_serialize` is a state's identity** — dirty-marking
   (`session_dirty`, `ase.tcl:9420`) and reverse lookup (`sessions_for_state`,
   `:9651`) both key on the byte string. A change that alters the output for an
   untouched state marks every open session dirty.
3. **Unknown keys are preserved and re-emitted sorted.** That is the forward-compat
   guarantee, and it means removing a key later is *safe* (§6.3).
4. **`dict merge` is per top-level key** — an old file's `analyses` value replaces
   the default list entirely (§6.4).
5. **`ase.tcl` must stay Tk-free** (`ase.tcl:5-10`), and `--nogui` must drive
   every proc. So the analysis registry belongs in `ase.tcl`, and only its
   *rendering* in `ase_window.tcl`.

### 9.2 Recommended shape

**Keep `analyses` exactly where it is: a LIST of open dicts with `type` and
`enabled`, and no version bump.** It is already the right shape. Everything that
is missing is *outside* the state file:

* **The list is already variable-length and order-preserving.** `delete_selection`
  and `chana_ok`'s append prove it in production today.
* **Rows are already open dicts with round-tripping extra keys.** The Options…
  editor already writes them. What is missing is that the renderer ignores them
  (`ase_window.tcl:4210-4214`, "v1 limit").
* **`version` must stay 1.** Adding a fifth type is precisely *"a new optional
  key"*, not *"a change an old loader could MISREAD"* (`ase.tcl:498-500`).

Two additions to the row, both optional and both absent-by-default so no
committed file changes:

```tcl
{type dc enabled 1 source Vce start 0 stop 1.5 step 0.01
     id dc_corner_hi              ;# OPTIONAL, absent = anonymous
     args {sweeptype lin second_source Vg second_start 0 …}}  ;# OPTIONAL
```

* **`id <token>`** — a stable per-row handle, absent on every existing row.
  It is what lets several rows of the same type be addressed (the `chana_row`
  first-of-type limit, §3.3 #14), lets the viewer name a per-analysis plot, and
  lets a future results model key on something other than "the first `dc`".
  Absent ⇒ fall back to `type` ⇒ every existing state behaves exactly as now.
* Prefer putting new per-type arguments **flat in the row** (as `source`/`start`/
  `stop`/`step` already are) rather than in a nested `args` bag. The flat form is
  what `arg_summary`, `chana_ok`'s empty-field-deletes rule and the Options…
  editor already handle end-to-end. A nested bag would need all three rewritten
  for no compatibility gain. (Show `args` above only as the shape to *reject*.)

### 9.3 The real work is a TYPE REGISTRY in `ase.tcl`, not a schema change

Replace the four scattered tables (§3.2) with **one declarative registry**,
`ase::analysis_types`, living beside the backend registry and read by both files:

```tcl
# one entry per analysis type
{ noise {
    label     {Noise}                     ; # dialog radio text / pane display
    fields    {output source points start stop}   ; # order = summary + form order
    required  {output source}             ; # what D6 validation enforces when enabled
    optional  {ptssum}
    render    ase::backend::ngspice::an_noise     ; # proc {row} -> list of control lines
    plotname  noise                       ; # the sim_type the raw will carry
    emitorder 50                          ; # sortable; op keeps the special last-slot rule
} }
```

Then:

* `state_default`'s literal (`ase.tcl:512`) stays a *seed*, not a derivation —
  changing the seed must remain a deliberate act (§6.4).
* `anorder` (`ase.tcl:10863`, `:10939`) becomes a sort over the registry's
  `emitorder`, **with the op-last exception kept as an explicit special case**,
  because its reason (ngspice's forward-only sticky save list, measured) is about
  `op` specifically and does not generalise.
* The `switch` (`ase.tcl:10952`) becomes `[dict get $entry render]` dispatch **with
  a loud `default`** — the §7.3 fix.
* `plot_sim_type` (`ase.tcl:7643`) reads `plotname`, and gains a real answer for
  types the raw reader already knows (`noise`, `sp`, `spectrum` — §7.5).
* `chana_fields` / `anaargs` / the radio `foreach` (`ase_window.tcl:80`, `:4075`,
  `:4107`) all read `fields` and the registry's key list. The radio row becomes a
  scrollable list or a combobox once there are more than ~6 types.
* Backends declare their own registry, exactly as they declare their five hooks —
  so a future Xyce/Spectre backend offers a *different* analysis vocabulary
  without ASE-L hardcoding anyone's.

### 9.4 Old state files under that design

* An old file loads unchanged: its four rows carry no `id`, no new fields; the
  registry supplies label/fields/render by `type`.
* A row whose `type` is not in the registry now hits the loud `default` and is
  **reported**, not dropped (§7.3).
* No new top-level key ⇒ **no change to any of the 104 files, no change to
  `schema_keys`, no `test_ase_core.tcl:191` churn, `version` stays 1.**
* Only `test_ase_core.tcl:287-288` and the D1 golden deck need touching, and only
  if the *default seed* changes — which §9.2 recommends it should not, at first.

### 9.5 The order to do it in (RED-first, cheapest risk first)

1. **Close the silent-drop path** (§7.3): a `default` arm in `render_deck`'s
   switch that refuses/reports. RED test: a state with `type noise enabled 1`
   renders a deck and says nothing today.
2. **Extract the registry** with exactly the four existing types and byte-identical
   output. The D1 golden deck and E12 are the proof.
3. **Then** add types, one at a time, each with a deck golden and a
   `plot_sim_type`/raw-attach row.
4. **Then** the dialog: registry-driven radio list → a scrollable chooser, and
   `chana_row`'s first-of-type limit → `id`-addressed rows.
5. **Last**, and only with a user ruling: whether a new default type is seeded
   into `state_default` (§6.4), and whether a load-time migration adds it to
   existing benches. Today the answer is "no, silently"; that should be a
   decision, not a default.

---

## 10. Gaps and things another agent must confirm

* **The ngspice side of "every analysis and every option"** is out of this area's
  scope. This dossier says only what ASE-L can hold and what it drops; the
  authoritative list of ngspice analyses and their arguments is another dossier's.
  What is established here is that only `op`/`dc`/`ac`/`tran` are reachable, that
  `ac` is locked to `dec`, and that `tran` cannot express `tstart`/`tmax`/`uic`.
* **`src/ase_window.tcl` is being edited concurrently.** Every line number for it
  here is HEAD `5fb8f465`; the working tree had grown by ~350 lines mid-session.
  Re-derive before quoting a line to anyone.
* **The `results`/Value-column model** was only surveyed to the extent it touches
  `analyses` (the print anchor, issue 1243). How a multi-analysis results set
  *should* be presented — Cadence shows results per analysis — is not answered
  here and interacts with the single-raw/single-log artifact model (§2.4).
* **`ase::preflight_scan` does not check analysis arguments at all**, only
  `outputs`. Whether `dc.source` should be netlist-validated is an open design
  question with existing machinery (`ase::netlist_map_resolve`) sitting unused for
  it.
* **The `doc/claude/ase_l_ux_batch/` batch is live** (`LEDGER.md` modified,
  untitled shot directories present). Anything this dossier says about the
  dialog's *appearance* may already be stale; its *data contract* is what was
  verified.
* **Issue numbering**: `doc/claude/issues/NUMBERING.md` is the only authority for
  a new issue number, and this dossier deliberately mints none.
* **Not verified**: whether any `.state` file outside this repository (a user's
  own bench elsewhere on this machine) carries a shape the 104 committed ones do
  not. The claim "every committed state has exactly four rows in order" is scoped
  to `git ls-files '*.state'`.
