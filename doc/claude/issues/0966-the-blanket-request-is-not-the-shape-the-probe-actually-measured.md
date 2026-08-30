# 0966 — the blanket request is not the shape the probe actually measured

**FILED, NOT FIXED — the tier work of issue 0963 shipped over it, 2026-08-30.**

Status: OPEN.

The capability probe asks the simulator whether it can do `save @<device>[*]` —
ONE request per device, with a wildcard over that device's parameters. The
blanket tier emits `.options saveopparams` — no device named at all — because
that is the shape `doc/claude/ngspice_enhancement_request_op_parameter_saving.md`
section 4 asks ngspice for, and the shape the S4 item requires.

Choosing the second on the strength of the first is precisely the optimistic
guess the item forbids elsewhere. The clean fix is a second probe question, and
"do not change the probe" blocks it.

Harmless in practice, measured: `.options saveopparams` is silently ignored by
ngspice-46+ — exit 0, a normal results file, no warning — and no released build
answers yes to the probe anyway.


## Where it now stands in the code

`ase::backend::ngspice::render_deck`'s blanket arm emits `.save all` +
`.options saveopparams` and names no device. Selection is guard G3 of
`ase::op_save_tier`, which reads `blanket_op_save` — the per-device wildcard the
probe measures. No released ngspice answers yes to that probe, so on every real
box today the guard never fires and the mismatch cannot bite; the arm is
exercised by a `/bin/sh` stand-in that really makes the probe measure
`blanket_op_save 1` (`test_ase_optier_0963` rows A1/A2).

The clean fix is a second probe question. "Do not change the probe" blocks it,
so this is filed rather than guessed at.
