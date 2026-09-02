# 1239 — `ase::expand_path` still uses `subst`, and now expands SIMULATOR paths

**Status:** OPEN. Filed 2026-09-01, at the `annotate` → `fluid-editing` merge.
Pre-existing on `annotate`; the merge did not create it but **did make it more
reachable**, which is why it is filed now rather than left where it was.

## The hole

`ase::expand_path` (`src/ase.tcl`) is:

```tcl
proc ase::expand_path {p} {
  if {[catch {uplevel #0 [list subst -nocommands -nobackslashes $p]} out]} {
    return -code error "ase: cannot expand model path '$p': $out"
  }
  return $out
}
```

**`subst -nocommands` is not a sandbox.** MEASURED on Tcl 8.6.14:

```tcl
set ::RAN 0
subst -nocommands -nobackslashes {$A([set ::RAN 1])/x}
;# ::RAN is now 1
```

Tcl still evaluates a `[...]` sitting inside the **array index** of a variable
substitution, because the index is parsed as a script word before the
(suppressed) command-substitution pass ever applies. This was driven end to end
on this tree by `fluid-editing`: an `exe` of
`$env([exec touch /tmp/.../PWNED])/ngspice` created the file during what was a
pure *staleness query* — the caller returned `{}` and looked innocent.

## What the merge changed

`ase::sim_register` calls `ase::expand_path` on the simulator's path, and the
merge made the registry **the only** route from a configured simulator to a run.
So the expander now sits on the path of every registered simulator, not only
model files — reached from `Setup > Simulators…`, from the Command window, and
from `ase::sim_load_conf` **at startup**, on a file that is a plain Tcl script in
`$USER_CONF_DIR`.

## The fix exists in this tree

`sim_expand_vars` (`src/xschem.tcl`, kept from `fluid-editing` under a name that
no longer claims a profile) is the hardened expander: `$name`, `${name}` and
`$name(index)` at global level, literal index characters only, and an index
carrying `[`, `$` or a backslash **refused outright** rather than resolved. It is
currently **callerless on purpose** — its last caller went with the profile
layer, and deleting the tree's one fix at the commit that made the registry the
only path to a simulator would have been moving the hole somewhere more
reachable and throwing the fix away.

`tests/headless/test_sim_casemode_registry.tcl` section D (CS157k/l/m) drives it
and is what stops it being removed as dead code.

## What it needs

Point `ase::expand_path` at `sim_expand_vars`, then decide the one behavioural
question it raises: **an index this expander refuses is currently an error, and
model paths in the wild may contain shapes it refuses.** So the change needs a
survey of the committed `.state` fixtures' model paths before it lands, or a
compatibility arm that falls back to the literal rather than raising.

Not done at the merge because it is a behaviour change to model loading and
belongs in its own commit with its own measurement.
