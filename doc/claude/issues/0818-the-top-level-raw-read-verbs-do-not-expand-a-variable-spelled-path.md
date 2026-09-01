# 0818 — the top-level `raw_read` / `table_read` / `vcd_read` verbs do not expand a
# variable-spelled path, so one spelling loads through `xschem raw read` and not
# through `xschem raw_read`

STATUS: **OPEN — measured at HEAD (fadb226d), left unfixed BY DECISION under item
0812-retry (decision D5, smallest blast radius: those four verbs keep exactly the
resolution they have today, tilde only).**
FOUND IN: `src/scheduler.c` — the `embed_rawfile` (:851), `raw_read` (:10559),
`table_read` (:13202) and `vcd_read` (:13787) verbs. Each splices its argument into
`regsub {^~/} {%s} {%s/}` and `tcleval()`s it; a brace-quoted word does **no**
variable substitution, and the three read verbs then call `read_rawfile_by_type()`
**directly**, bypassing `extra_rawfile()` — which is the only place variables are
expanded.

## Measured (this tree, HEAD, `--nogui`, `netlist_dir` set to a real directory)

```
xschem raw_read {$netlist_dir/ok.raw} tran   -> 0
    raw_read(): failed to open file $netlist_dir/ok.raw for reading
    (`xschem raw rawfile` -> "No raw file loaded")
xschem raw read  {$netlist_dir/ok.raw} tran  -> 1
    Raw file data read: <netlist_dir>/ok.raw
    xschem raw clear {$netlist_dir/ok.raw} tran -> 1
```

Same file, same spelling, two verbs, two answers.

## Why it matters, and why it does not bite today

`open_sub_schematic()` and `hi_descend()`'s new-window arm (both `src/xschem.tcl`)
carry the current database into a new window with
`xschem raw_read $rawfile [xschem raw_query sim_type]` — but `$rawfile` there is the
**already resolved absolute path** the registry stored, so the shipped paths never
hand this verb a `$`-spelled name. The exposure is a user or a script that spells a
path the way the shipped graph attributes do (`$netlist_dir/...`,
`xschem_library/ngspice/autozero_comp.sch` and two others) and reaches for the
top-level verb.

## The second half: the registry key

Because the verb stores what it was given, a `$`-spelled path read through
`raw_read` enters the registry UNRESOLVED, while `xschem raw clear <same spelling>`
resolves it through `extra_rawfile()` — so the `strcmp()` key can disagree between
the two commands. Not reachable through any shipped path for the reason above.

## Fix, when someone takes it

`resolve_rawfile_path()` (`src/util.c`, added by 0812) is the whole fix: call it in
place of `expand_tilde()` in those three read verbs. It is deliberately NOT done
under 0812 because that would ADD variable expansion where there is none today,
which is a behaviour change with its own blast radius and no measured demand.
`embed_rawfile` is a different question — it never expanded variables and its
argument is a path to embed, not a registry key.

RELATED: 0812 (the injection this family came out of), 0816, 0817.
