# Decisions

## U1 — the user's ruling (verbatim), which is the whole premise

> Yes, registering a simulator (so that future Xschems see the "new" simulator
> instance) is something that can make it to disk right away as soon as done.
> But, registering a simulator is not part of the simulator state that
> accompanies a test-bench cell in the library manager.
>
> *Whether* the "new" simulator just registered gets assigned as "the one to
> use" is an option that is part of the ASE-L state. If changed, that results in
> dirtiness. User must explicitly save and, if user initiates an Xschem
> shutdown, then she must get a warning and a prompt to save.

This corrected a plan that would have autosaved the WHOLE registry, choice
included, on every mutation. Half of that plan was right (registration) and half
was exactly backwards (the choice).

## D1 — the choice is a state key, not a per-window global

`ase::sim_use` stays, but demoted to a cache of the active session's choice. The
store of record is the new `sim_entry` state key, which is what makes it dirty,
savable and promptable for free — `ase::session_dirty` already compares
serialized states, so no new dirty machinery is written.

Rejected: threading an entry name through `ase::sim_status`'s ten call sites.
None of them carries a session key, and the cost is a signature change in the
one resolver every simulator answer flows through.

## D2 — `{}` must mean "no choice", so "deliberately PATH" needs a spelling

104 committed `.state` files force the new key's default to be `{}` and force it
into `omit_if_empty` (the rule is already written at `src/ase.tcl:66` for `cosim`
and `save_op_params`). So `{}` cannot also mean "deliberately the PATH program",
which issue 0932 established is a real choice a user makes and must keep.
Chosen: a three-value encoding, `{}` / `none` / `{name <entry>}`. The two-word
form means no registry name has to be reserved.

Rejected: a reserved entry name (breaks an existing user's conf silently), and a
second boolean key (two keys for one fact breaks invariant I1).

## D3 — a `sim_select` from `conf` or `rc` is a DEFAULT, from `session` it is a CHOICE

This is how the saved file's default reaches `ase::sim_default` without changing
the file format at all: `ase::sim_origin` already distinguishes the three layers
and is already maintained. The existing `ase::sim_select {}` line that issue 0932
writes keeps meaning what it meant, on the default rather than on the choice.

## D4 — `ase::sim_clear` does not persist

*A mutation that expresses a user's choice persists; a teardown does not.*
`sim_clear` is "forget every registered simulator and every choice". Autosaving
there would let a test or a script blank the user's list — the one way an
autosave-at-the-mutation design can destroy data.

## D5 — carried limitation, NOT fixed here (owed as a `rule`)

Two ASE-L windows open on different test benches still share one `ase::sim_use`.
The run path applying the running session's `sim_entry` makes "the window you
clicked in wins" for the run, which is the half that decides what actually
executes. A bar or dialog in the other window may momentarily name the other
choice. Per-window registries are a separate feature and were not asked for.

**2026-11-25, issue 1762: the bar's half is closed.** The bottom bar of a
session window now asks about its own state (`ase::sim_session_label`), so it
names what a run of that window starts whichever window opened, ran or picked
last; and a state's choice goes in force when its window opens, not only when
it runs. What is still carried is the dialogs: with two windows open, Choose
Analyses, the Options sheet and the status line of the Simulators window of
the window that did not open, run or pick last answer about the other's
program.
