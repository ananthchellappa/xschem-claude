# 0821 — graph_fill_listbox() splices a .sch `rawfile=` attribute into a Tcl script, so opening the Graph dialog on someone else's schematic runs their Tcl

Status: **measured LIVE, NOT FIXED — outside 0812-retry's C-side scope fence.**
Found by the 0812-retry adversary pass. Family: 0812 / 0816 / **0817** (the Tcl-side
brace-group splices). This is the same defect class 0812 closed in C, still open in Tcl.
Severity: **high** — a `.sch` file is a document people mail each other.

## 1. The two sites

`src/xschem.tcl:4775`, inside `graph_fill_listbox` (LIVE — 7 call sites: the Graph
dialog's Refresh, its listbox rebuild, `-command`, and three dialog entry points):

```tcl
  set rawfile [xschem getprop rect 2 $graph_selected rawfile]
  if {$rawfile ne {}} {
    if {![catch {eval uplevel #0 {subst $rawfile}} res]} {
      set rawfile $res
    }
  }
```

`src/xschem.tcl:4842`, inside `raw_is_loaded` (**DEAD** — zero callers tree-wide, which is
the only reason it is not a second live door):

```tcl
  set r [catch "uplevel #0 {subst $rawfile}" res]
```

`graph_fill_listbox` also runs the same shape over the `autoload` and `sim_type`
properties at `:4772` and `:4779`.

## 2. Measured, in tclsh 8.6.13

```tcl
proc p {} {
  set rawfile {LOCAL[set ::HIT 1]}
  set ::HIT 0
  set r [catch {eval uplevel #0 {subst $rawfile}} res]
  puts "4775-shape: rc=$r res=$res HIT=$::HIT"
}
p          ->  4775-shape: rc=0 res=LOCAL1 HIT=1

proc q {} {
  set rawfile "a\}; set ::HIT2 1; list \{b"
  set ::HIT2 0
  set r [catch "uplevel #0 {subst $rawfile}" res]
  puts "4842-shape: rc=$r res=$res HIT2=$::HIT2"
}
q          ->  4842-shape: rc=0 res=b HIT2=1
```

Both execute. Note this **corrects the adversary's own characterisation** of `:4775`: it
reported that the line substitutes the *global* `rawfile` rather than the .sch-derived
local. It does not — `eval` concatenates to `uplevel #0 subst $rawfile`, `$rawfile` is
substituted in the *proc* frame (`res=LOCAL1`, the local value), and the payload then runs
at global level. So it is not a latent wrong-variable bug; it is a **live command
substitution over a string read out of a `.sch` file**, exactly the 0812 shape.

## 3. Why 0812-retry did not fix it

The item's scope fence names 0816 (the nine remaining `regsub {^~/}` + tcleval splices) and
0817 (the tclvareval brace groups) as the follow-on, and forbids widening. These two sites
are Tcl-side and are in neither list — 0817 enumerates C `tclvareval` call sites. They are
recorded here so the follow-on crew inherits them rather than rediscovering them.

## 4. Recommended fix (for the 0816/0817 crew)

`graph_fill_listbox` wants a *resolved path to display and to hand to `raw switch`*. The C
resolver built for 0812 already is that function and is reachable from Tcl through the
engine: route the attribute through the same one-pass resolution the drawing path uses
rather than through `subst`. Failing that, the minimal Tcl-only repair is
`uplevel #0 [list subst -nobackslashes -nocommands $rawfile]` **plus** the knowledge that
this is *not sufficient* — `$a([exec …])` still runs inside a variable array index (0812
§4, the refutation of attempt 1). Only a resolver with no evaluator in it closes this.

`raw_is_loaded` has no callers: **delete it** rather than fixing it.

## 5. Still open

Everything above. Nothing in this issue was changed by 0812-retry.
