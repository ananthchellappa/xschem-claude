# 0817 — `tclvareval()` brace-group splices of file-/user-derived strings

STATUS: **STILL OPEN — and now DRIVEN, not just inventoried. See §Z (2026-08-25) for the
measured `xschem load` vector, the sites the 0821+0816+0817 item removed from this list, and
two corrections to the inventory below.** Filed by the 0812 implement agent, 2026-08-25. Site sweep done and
verified against the tree; only the parselabel case is characterised in detail, and it is
deliberately UNMEASURED (see the caveat).**
FOUND IN: many files under `src/`. Same defect class as issue 0812.
⚠ **UPDATED 2026-08-25 (twice)**: the first 0812 attempt was reverted, then **the 0812
RETRY landed** and removed the raw-file path sites (`save.c` `extra_rawfile()` ×6 → one
call, `draw.c` `node_token_split()` ×2). Those eight are **fixed**. This issue is the rest,
and it is untouched.
⚠ And the fix shape matters: 0812 §1 measured that `subst -nobackslashes -nocommands`
still executes a command substitution in a variable **array index** (`$a([...])`), so
"route it through `subst` as a value" is NOT an answer here either. Pass the string as a
Tcl **list element** / variable (`save.c` `backannot_refuse_digital()` is the in-tree
precedent) or expand it in C.

## ✅ THE C-SIDE EXPANDER ALREADY EXISTS

Where a `tclvareval("subst {", x, "}", NULL)` exists **only to expand variables** — which is
what all the raw-file ones were — the drop-in is 0812's
`expand_tcl_vars(const char *s, char *dest, int destsize)` in `src/util.c` (declared in
`src/xschem.h`). It is a **C byte scanner**: `$name`, `${name}` and `$ns::name` are looked up
with `Tcl_GetVar2Ex(..., TCL_GLOBAL_ONLY)` — the only Tcl API it calls, a hash lookup — and
**every** other byte is copied verbatim, `{ } [ ] ; \ ( )` included. `(` is never an index
opener, a variable's value is never rescanned, and an undefined reference is copied through
as its own literal text (so a filename really containing `$` opens under its own name instead
of being blanked). Where the splice is *not* just variable expansion, the list-element route
above is the answer; do not reach for a cleverer `subst` flag — 0812's first attempt already
lost to one.

## The sink

```c
tclvareval("some_command {", str, "} ...", NULL);
```

`tclvareval()` CONCATENATES its arguments into one string and hands it to `Tcl_EvalEx`.
Where `str` sits inside a `{...}` group, a `}` in `str` closes the group and the rest of
`str` is parsed as script. Measured count on this tree: **313 `tclvareval()` call sites,
147 of which build a brace group.** Most interpolate program-generated text and are not a
defect. The ones interpolating **attacker-reachable** text are below, sharpest first.

## Sharpest first

* **`src/parselabel.c` (~:1884-1886)** — a **NET/LABEL NAME** and `xctx->sch[currsch]`
  spliced into a `tk_messageBox ... -message {...}` group, via `my_snprintf` + `tcleval`.
  Both come out of a `.sch` file. Fires when a label fails bus expansion.
  ⚠ **NOT DRIVEN, ON PURPOSE.** It is a **modal dialog**, and issue 0803 records that a
  modal on a failed path hangs any suite under X. Whoever takes this must arrange a
  non-modal probe (or drive it with `has_x` false and assert on the composed string)
  rather than pop it in a suite.
* **`src/actions.c:3784`** — `tclvareval("launcher {", url, "} {", program, "}", NULL)`.
  `url` is a **PROPERTY VALUE** read from a schematic.
* **`src/hilight.c:1118` / `:1120`** — `regexp {<options>} {<pattern>} {<name>}`. `name`
  is a **net name from the file**; `pattern` is typed into the search dialog.
* **`src/hilight.c:847, 855, 1644, 1647, 1760, 1769, 1773`** —
  `puts $gaw_fd {copyvar ...}` with instance and net names from the `.sch`.
* **`src/token.c:148` / `:149`** — `regsub` of a **net name**.

## The rest of the sweep (same class, lower reach; verified present, not individually driven)

`hilight.c` `graph_add_nodes_from_list`; `token.c` `has_included_subcircuit` /
`alert_` with a symbol name; `callback.c` and `scheduler.c` `[file dirname {<path>}]`;
`callback.c` `hi_descend_pick_done {<instname>}`; `actions.c` `update_recent_file` /
`xschem load_new_window` / `is_xschem_file` / `ask_save` / `try_download_url` / `alert_`
with `current_name`; `save.c` `is_xschem_file` / `download_url` / `try_download_url`;
`scheduler.c` `cellview_path` / `cell_views` / `ciform::open` / `library_inst_lcv` /
`library_resolve` / `library_cells` / `libmgr::open` / `file normalize` /
`replace_symbol` / `alert_` / `update_recent_file` / `xschem_recover_backup`;
`move.c` `c_toolbar::add`; `draw.c` and `svgdraw.c` the plotfile path.

## Explicitly NOT a defect

`src/token.c:90` `tclpropeval2 {<res>}` is XSCHEM's **documented** `tcleval(...)`
attribute form (`doc/xschem_man/symbol_property_syntax.html`): Tcl evaluation from a
`.sch` **by design**. Do not "fix" it.

## The two in-tree answers, already shipped

* `src/save.c` `backannot_refuse_digital()` — hand the string over as a **VARIABLE**
  (`tclsetvar` + `tcleval` on `$::var`, then `Tcl_UnsetVar`). Its own comment records the
  same measured payload shape and says "the quoting discipline starts here".
* `src/callback.c` `tcl_braceable()` + `log_action_argv()`'s `Tcl_Merge` — the
  conservative refuse-braces-and-backslashes guard, used from `scheduler.c` and
  `actions.c`.

A third, written by the 0812 attempt and **reverted with it** (so it is not in the tree —
see `doc/claude/evidence/0812-attempt1-reverted.patch.txt`): `Tcl_EvalObjv` with a
pre-built word list, which has no parsing step at all. Note the lesson from that revert:
removing the *parsing* step is necessary and not sufficient — the attempt's word list
still invoked `subst`, and `subst` re-introduced evaluation through a variable array
index. If the word you pass is data, make the command you call one that cannot evaluate
it.

---

## §Z — 2026-08-25, after item 0821+0816+0817

### Z.1 What that item REMOVED from this issue

The three sym-path wrappers in `src/actions.c` (`abs_sym_path`, `rel_sym_path`,
`sanitized_abs_sym_path`) were this issue's class and were fixed, as **0825**,
using the `backannot_refuse_digital()` variable route this issue names. They are
no longer part of the sweep. Nothing else here was touched.

### Z.2 This issue is no longer a site inventory — it has a driven vector

Measured on the **fixed** tree, twice independently (`--nogui`, no dialog):

```
xschem load "<dir>/x} ; set ::FNPWN 1; exec touch <dir>/FNHOST; is_xschem_file {a"
->  FNPWN=1   host=1
```

A crafted **filename** executes through `is_xschem_file` / `get_directory` /
`update_recent_file`. That is the `load` verb, on a fixed tree, and it means the
sentence "0816 is fixed" must never be compressed into "`xschem load` is safe" —
0816's sink is closed at all nine of its sites, and this one is beside it.

Note the payload shape is **sink-specific**: 0816's own no-slash payload trips a
wrong-number-of-args error at the first of these sinks and aborts the script, which
is exactly why `test_raw_read_dispatch`'s SC rows are green while this is live. A
suite row for this issue must be shaped for **this** sink.

### Z.3 Two corrections to the inventory above

1. **`cellview_path` is under-rated and is in the wrong file.** It is listed under
   *"the rest of the sweep (same class, **LOWER REACH**; verified present, not
   individually driven)"* and attributed to `scheduler.c`. The live sink is
   **`src/actions.c:4215-4219`** `cellview_sch_path()`, it is now **driven**, and
   its reach **exceeds this issue's own nominated sharpest reachable-on-unix site**:
   one mailed `.sch` + a stock library symbol + `xschem descend` created a host
   file. Split out as **issue 0827**.
2. **`hilight.c:1118` / `:1120` is Windows-only.** Verified on this tree:
   `:1114` is `#ifndef __unix__` and `:1115` is `win_regexec`. It cannot be driven
   here at all, so it should not sit third in a "sharpest first" list.

### Z.4 Still live after that item — the list, so nobody reports the family swept

C side: `actions.c:3784` `launcher` (a `.sch` `url` property); `actions.c` /
`save.c` `is_xschem_file`, `get_directory`, `update_recent_file`, `ask_save`,
`try_download_url`, `download_url` (**driven — Z.2**);
`actions.c:4215` `cellview_sch_path` (**driven — 0827**);
`hilight.c` gaw `copyvar` ×7 (847, 855, 1644, 1647, 1760, 1769, 1773);
`token.c:148/149` `sanitize`; `parselabel.c:~1884` `tk_messageBox` (**modal** —
still deliberately unmeasured, issue 0803); `hilight.c:1118/1120` (Windows-only);
and the rest of the sweep list above.

⚠ `token.c:148` was **attempted and is unproven either way**: a generator-shaped
instance name (`gen(a} … regsub x {b)`) gave `SANHIT=0` on both load and netlist,
because a **missing** symbol never reaches the `@symname`/`.subckt` paths that call
`sanitize()`. It needs a real generator symbol on the library path to drive. Until
then this issue should not describe it as merely "present" — it is untested.

Tcl-side same-class siblings, outside this issue's `tclvareval` scope but the same
defect: `src/xschem.tcl:2831` `file_exists` (`catch "uplevel #0 {subst $f}"`,
**dead** — no callers); `src/ase.tcl:202` `ase::expand_path` (`subst -nocommands`,
which 0812 §1 measured still running a command substitution inside an array index);
`src/xschem.tcl:7067/7068`, the preview_window `<Expose>`/`<Configure>` binds built
with `subst` over a file-dialog filename.

## §Z.5 — 2026-08-26, after item 0827+0817+0828

### Z.5.1 What that item CLOSED

**72 concat call sites** across 13 `.c` files converted to the new
`tcl_call()` / `tcl_call_mid()` in `src/util.c` — the data words are handed to the
interpreter as **global variables** and never concatenated; only the command name
and the literal connective words are program text. That is the
`backannot_refuse_digital()` / 0825 route, **not** a second resolver: `tcl_call`
expands nothing and resolves nothing, so 0812's `strcmp()` registry key is
untouched, no route gains a second pass (0820), and it calls `Tcl_SetVar` not
`Tcl_GetVar2Ex`, so it adds no `trace ... read` surface (0819 — GUARD3 still green).

Closed and **driven green**: `cellview_sch_path` **both doors**
(0827 — `actions.c:4291` the instance `schematic=` value, and `:4314` `sym->name`
via an embedded subcircuit); `is_xschem_file` ×3, `get_directory` ×5,
`update_recent_file` ×7, `download_url`, `try_download_url` ×2,
`xschem_recover_backup`, `launcher` ×3, `hi_descend_pick_done`, `cellview_path`
(the verb), `ask_save` ×3, `alert_` ×4, `sanitize`'s two regsubs,
`has_included_subcircuit`, `graph_add_nodes_from_list`, `set_netlist_dir`;
plus the five netlisters' `get_directory [list …]` ×10 and `netlist {%s} … {%s}`
×18 (**issue 0829**, a bracket-not-brace vector filed and fixed in the same pass).

### Z.5.2 ⚠ THE FAMILY IS NOT SWEPT — issue 0831

**It happened again, in the same sentence of the same list.** The "rest of the
sweep" section above names, on one line:

> `cellview_path` / `cell_views` / `ciform::open` / `library_inst_lcv` /
> `library_resolve` / `library_cells` / `libmgr::open` / … / `replace_symbol`

The item fixed **`cellview_path`, the first name**, and left the rest
concatenating. `library_inst_lcv` (`scheduler.c:5527`) takes
`xctx->inst[n].name` — **straight from the `.sch`** — and was **driven to
host-file creation** by the adversary (3/3) and again, independently, by the
write-up agent:

```
LMX=1 host=1 r=y
```

`cell_views` was driven to Tcl execution with a sink-shaped argv payload.
Two more, **not in the adversary's list**, found during the write-up:
`scheduler.c:9707` and `callback.c:559`,
`set INITIALINSTDIR [file dirname {<abs_sym_path(inst.name)>}]` — file-derived and
carrying 0829's bracket problem as well as this issue's brace problem.

**And the guard did not catch it**: `FN07`'s `FN_PROCS` list in
`tests/headless/test_raw_read_dispatch.tcl` covers 9 procs and **none of these**,
so the anti-half-sweep row was green while the sinks were live. Extending that
list is part of 0831's fix, not an afterthought.

### Z.5.3 Still live after that item — the corrected list

* **issue 0831** (driven): `library_inst_lcv` 5527; `cell_views` 2708;
  `ciform::open` 2726; `library_resolve` 8068; `library_cells` 8077;
  `libmgr::open` 8097; `replace_symbol` 12393; `INITIALINSTDIR`
  scheduler.c:9707 + callback.c:559.
* `hilight.c` gaw `copyvar` ×7 (847, 855, 1644, 1647, 1760, 1769, 1773) — a
  **different sink shape**, a protocol line to a co-process; needs its own helper
  and a live GAW that no headless suite has.
* `parselabel.c:~1884` `tk_messageBox` (**modal**, issue 0803).
* `hilight.c:1118/1120` — Windows-only, behind `#ifndef __unix__`.
* `draw.c:126` / `svgdraw.c:1113` / `psprint.c:1795` `file dirname {plotfile}` — a
  Tcl **setting**, not file-derived.
* `move.c:9135` `c_toolbar::add`; `xinit.c:470` `lindex {tclpixdata}`;
  `hilight.c:3303` `net_hilight_anim_update {wp}` — internal, not file-derived.
* Tcl-side siblings unchanged: `ase.tcl:202`, `xschem.tcl:7067/7068`,
  `xschem.tcl:2831` (dead).

### Z.5.4 Newly established as NOT defects — do not re-derive

* `scheduler.c:7819` / `:7840` `xschem load {f}` — already guarded by
  `is_pristine_untitled() && tcl_braceable(f)` with a `new_schematic()` C-string
  fall-through. **Issue 0022 solved this.**
* `scheduler.c:7798` `file normalize` — already commented out.
