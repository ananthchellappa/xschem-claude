# 0935 — the simulator resolver says a program can be started when nothing can

**STATUS: OPEN, low severity, contract only.** Measured 2026-08-29 at commit
`0225a962`. No user-visible behaviour changes today; this is about what the
next caller will believe.

## Measured, verbatim

    F5 auto_execok nosuchsim -> ''
    F5 sim_status            -> ok 1 exe nosuchsim args {} resolved {} source path entry {} why {}
    F5 sim_exe               -> 'nosuchsim'   (returned, not refused)

`ase::sim_status`'s own comment (src/ase.tcl) says:

    #   ok        1 when something can be started, 0 when the user's own choice
    #             cannot be honoured

The two clauses of that sentence are not the same claim, and the code
implements the second one. With nothing registered and no such program
anywhere, `ok` is 1 and `resolved` is empty.

A second, smaller disagreement in the same dict: on the backend-mismatch arm
the answer carries `source registry` and `entry <name>` while `resolved` still
holds `auto_execok`'s file for the PATH program — three fields describing two
different things.

## Why it is filed rather than fixed

Making `ok` mean "something can be started" would change behaviour for a user
who has registered **nothing** and has no `ngspice` on their `PATH`: today
`run_cmd` returns the command and the existing sentence
`ase: cannot start simulator '<name>' (<argv0> not runnable)` reports the
failure at launch. That is issue 0931's clause (c) — today's behaviour, byte
for byte — and changing it is a user-visible decision, not a tidy-up.

## Why it still matters

Row **F1** of `tests/headless/test_ase_simreg_0931.tcl` states the contract for
the twelve `auto_execok ngspice` availability gates: the field they should read
is **`resolved`**, and `resolved` is honest in every arm measured. The trap is
that `ok` reads like the obvious field and its comment invites exactly that.

## Options

1. Fix the comment: `ok` is "the user's own choice can be honoured", full stop,
   and say in the same breath that a caller asking "is anything available"
   reads `resolved`. Zero behaviour change.
2. Add a separate field (`runnable`) that answers the other question, so
   neither caller has to know the difference.
3. Make `ok` mean both — a behaviour change to clause (c), needing the user's
   ruling.

Option 1 is free and honest; option 2 is what the twelve gates would actually
like.

## Acceptance

A row asserting the dict for a backend with no program anywhere, so whichever
answer is chosen is the one that is pinned.
