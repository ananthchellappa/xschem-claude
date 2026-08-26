# 0817 — `tclvareval()` brace-group splices of file-/user-derived strings

STATUS: **OPEN — filed by the 0812 implement agent, 2026-08-25. Site sweep done and
verified against the tree; only the parselabel case is characterised in detail, and it is
deliberately UNMEASURED (see the caveat).**
FOUND IN: many files under `src/`. Same defect class as issue 0812.
⚠ **UPDATED 2026-08-25 after the 0812 attempt was REVERTED**: that attempt would have
removed the raw-file path sites (`save.c` `extra_rawfile()` ×6, `draw.c`
`node_token_split()` ×2); it was reverted, so those eight are live at HEAD too and remain
0812's. This issue is the rest.
⚠ And the fix shape matters: 0812 §1 measured that `subst -nobackslashes -nocommands`
still executes a command substitution in a variable **array index** (`$a([...])`), so
"route it through `subst` as a value" is NOT an answer here either. Pass the string as a
Tcl **list element** / variable (`save.c` `backannot_refuse_digital()` is the in-tree
precedent) or expand it in C.

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
