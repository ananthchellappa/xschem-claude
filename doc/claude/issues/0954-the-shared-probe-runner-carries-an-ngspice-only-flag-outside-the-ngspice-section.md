# 0954 — the shared probe runner carries an ngspice-only flag outside the ngspice section

**STATUS: FIXED (2026-08-30, item S3a) — everything after the program name now
comes from the caller. Rows M1 and M2 of
`tests/headless/test_ase_simcaps_0948.tcl`.**

## The contract it breaks

`src/ase.tcl` states its own seam in its header:

```tcl
src/ase.tcl:24  # v1 registers `ngspice` only; the only ngspice literals outside the
                # ase::backend::ngspice namespace are the state_default schema defaults.
```

and the one exception is declared where it lives:

```tcl
src/ase.tcl:336  # The v1 default state (spec "State file schema"). `simulator ngspice` here is
                 # the one permitted ngspice literal outside the backend namespace.
```

## What is there now

`ase::cap_run` — in the generic `ase::` namespace, offered to every backend
that writes a `capabilities` hook — ends with:

```tcl
src/ase.tcl:1343  lappend cmd -b $deck
```

`-b` is ngspice's batch flag. The ngspice backend's own `run_cmd` spells it the
same way (`lappend cmd -b $deckpath`, :5396), which is the point: it belongs
there, not here.

## Why it matters

A second backend — the reason the hook was made a hook — writes its own
`capabilities` proc, reuses `ase::cap_run` because that is what it is for, and
gets an ngspice flag appended to its command line silently. Whatever that flag
means to the other program, the answer the probe returns is then about a run
nobody asked for. The failure is invisible in a tree with one backend, and it
is the second backend's author who pays for it.

## Fix shape

Move the flag to the caller: `ase::cap_run` takes the command it should run
(exe + args + whatever the backend needs to say "batch, this deck"), and
`ase::backend::ngspice::capabilities` supplies `-b`. Two lines. Then either
extend the header note to say what `cap_run` is allowed to assume, or state
that it assumes nothing.

## Acceptance

* `grep -n ' -b ' src/ase.tcl` shows the flag only inside
  `ase::backend::ngspice`.
* A structural row asserting the generic probe runner's body carries no
  backend-specific flag, so the next reuse cannot re-introduce one.

## The fix (item S3a, 2026-08-30)

`lappend cmd -b $deck` is gone from `ase::cap_run`. Its signature is now
`{exe exeargs workdir secs}` and `exeargs` is EVERYTHING after the program name:
the arguments the user registered, the backend's own flags, and the deck. The
ngspice probe supplies its own spelling:

```tcl
ase::cap_run $exe [concat $exeargs [list -b $decka]] $workdir [ase::cap_left $t0]
```

Row M1 is structural and asserts both ends at once — the shared runner carries no
`-b`, and the ngspice probe does. Row M2 is why M1 alone is not enough: it drives
an argument-logging stand-in and asserts the flag still reaches the program, so
deleting it from BOTH places cannot leave M1 green while every measurement stops
running in batch mode.
