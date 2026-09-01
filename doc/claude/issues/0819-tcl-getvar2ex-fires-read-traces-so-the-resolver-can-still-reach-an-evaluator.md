# 0819 — Tcl_GetVar2Ex fires READ TRACES, so the 0812 resolver's "no evaluator" comment was false

Status: **measured, comment corrected, mitigation pinned by a test row. The gadget has no
target in the shipped tree.** Found by the 0812-retry adversary pass, AFTER the fix commit
3ab11016 had landed.
Severity: low today, latent-high. Family: 0812 / 0816 / 0817.

## 1. What the fix shipped, and why the claim mattered

Issue 0812's fix (commit 3ab11016) resolves a raw-file path with a C byte scanner,
`expand_tcl_vars()` in `src/util.c`, whose only Tcl call is

```c
val = Tcl_GetVar2Ex(interp, namebuf, NULL, TCL_GLOBAL_ONLY);   /* src/util.c */
```

The shipped comment block said, verbatim:

> THE ONE SAFETY CLAIM MADE HERE, AND IT IS GREP-CHECKABLE: the only Tcl API
> this file's resolver calls is Tcl_GetVar2Ex(), **which is a hash lookup. There
> is no evaluator in the path.**

and `src/xschem.h` repeated it ("There is NO evaluator: the only Tcl API it calls is
Tcl_GetVar2Ex, a hash lookup").

That claim is the whole review surface of the fix. Attempt 1 at 0812 was reverted for
exactly one false safety comment ("`[` and `]` are literal"), so a second false safety
comment in the replacement is the same defect wearing the same tie.

## 2. The refutation, measured

`Tcl_GetVar2Ex` is a variable **read**, and a Tcl variable read runs every
`trace ... read` attached to that variable. A read trace is an arbitrary Tcl script, and
it may also **rewrite the value the read returns**.

BEFORE the comment correction, on the fixed binary (md5 cbf8784a, HEAD 3ab11016):

```
$ cat trace_probe.tcl
  set ::trapvar $D
  proc rtr {a b op} { catch {exec touch $::env(WPROBE)/TRACEOWNED} ; set ::trapvar /etc }
  trace add variable ::trapvar read rtr
  set rc [catch {xschem raw read {$trapvar/plain.raw} tran} r]
  puts "TRACE_FIRED_hostfile=[file exists $D/TRACEOWNED] rc=$rc r=$r"

$ ./src/xschem --nogui --pipe -q --nolog --script trace_probe.tcl
  raw_read(): failed to open file /etc/plain.raw for reading
  TRACE_FIRED_hostfile=1 rc=0 r=0
```

Two things happened that the comment said could not: the trace body **ran** (`exec touch`
created a host file), and it **redirected the resolved path** to `/etc/plain.raw`. The
adversary reproduced the same gadget from a `.sch` graph `node=` field and in the
`${::ns::name}` spelling.

## 3. Why it is not a live hole

The trace has to exist. Every variable trace in the shipped Tcl is a **write** trace:

```
$ grep -rn "trace add variable" --include=*.tcl src/
src/property_form.tcl:1443:  trace add variable ::slickprop_apply_scope write ...
src/ase_window.tcl:4504:     trace add variable ::execute(data,$id) write $cb
src/xschem.tcl:6372:         trace add variable ::hi_descend_dlg_view write ...
src/xschem.tcl:16965:        trace add variable net_hilight_animate write ...
src/xschem.tcl:17177/17179/17180/17192:  ... write ...
$ grep -rn "trace add variable.*read" --include=*.tcl src/     ->  (empty)
```

9 sites, 0 read traces. A user's own `~/.xschem/xschemrc` is Tcl and could add one — but
by the time that file runs the user has already executed their own code, so that is not a
privilege boundary this resolver defends.

## 4. What was done (this write-up's commit)

1. **Both comments corrected** — `src/util.c` (the claim block and the lookup block) and
   `src/xschem.h` (the extern block). The honest statement now shipped is: *this resolver
   ADDS no evaluator and PARSES nothing; the only evaluator it can still reach is one the
   user attached to a global with `trace ... read`; none ships.* Comment-only edit, no
   generated code changes.
2. **GUARD3 added** to `tests/headless/test_raw_read_dispatch.tcl` (51 → 88 → **89**
   checks): it scans every `src/*.tcl` for a `read` (or legacy `r`) variable trace and
   reds if one appears. Teeth demonstrated rather than assumed — appending one
   `trace add variable ::__guard3_probe read ...` to `src/xschem.tcl` produced
   `FAIL: GUARD3-no-shipped-read-trace (... xschem.tcl:17264)`, and removing it restored
   `ALL PASS (89 checks)`.

## 5. Decision (ladder rung L2)

**Do not attempt to suppress read traces in the resolver.** Rejected alternatives:

- *Read the variable with a trace-free API.* There is no public Tcl 8.6 C API that reads
  a variable's value while bypassing its read traces (`Tcl_ObjGetVar2` and friends all
  honour them; reaching into `Var` internals is not C89-portable and not supportable).
- *Refuse to resolve a variable that carries a read trace.* Requires the same read to
  discover, is a new failure mode for a legitimate user idiom, and buys nothing while zero
  read traces ship.
- *Drop variable expansion entirely.* Refuted by 0812 constraint 2 — the shipped corpus
  (autozero_comp.sch, solar_panel.sch, cmos_example.sch) spells `rawfile=$netlist_dir/...`.

Least surprising, smallest blast radius: **state the edge truthfully and pin the
mitigation with a row.** That is what shipped.

## 6. Still open

- GUARD3 covers `src/*.tcl` only. A read trace added from a plugin, from a user rc, or
  from C (`Tcl_TraceVar`) is not covered and would not red anything.
- `grep -rn "Tcl_TraceVar" src/*.c` is empty today; nothing pins that either.
