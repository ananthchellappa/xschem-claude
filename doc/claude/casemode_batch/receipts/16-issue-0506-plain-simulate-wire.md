# 0506 — the plain Simulate path composed from the profile

**Post-batch.** The casemode batch closed at item 15; this closes the gap the
batch's own scope lines named and deferred. Issue:
`doc/claude/issues/0506-*.md`. Spec: `simulator_profiles.md` **§18** (new),
with §10's two rulings **corrected in place**, and `raw_case_mode.md` §10's
"permanent unknown" ruling corrected for the files we cause to be written.

## What was wrong

Items 6/7/13 built the profile; item 8 wired it into **ASE-L's** run and nothing
wired it into the other one. `proc simulate` ran `sim($tool,$def,cmd)` verbatim.
Register a case-capable ngspice → set `Case = preserve` → press **Test** → read
*"delivers fold preserve distinguish"* → press **Simulate** → a different binary
runs, at `fold`. And `casemodewrite` was emitted **nowhere in the tool**, so item
3's header parser (mode source 2) could never fire on a file we wrote.

## What landed

| | |
|---|---|
| `xschem.tcl` | `sim_profile_run_flags`, `sim_profile_cmd_exe_plan`, `sim_profile_cmd_takes_flags`, `sim_profile_compose_cmd`, `sim_profile_compose_report`, `sim_profile_netlist_casemode`; three lines in `proc simulate` |
| `save.c` | `netlist_case_mode()` asks the profile for `CAD_SPICE_NETLIST`, floor otherwise |
| tests | `tests/headless/test_sim_plain_run.tcl`, **27 checks** |

## The three measurements the design rests on

All 2026-08-18, this machine.

1. **The netlister already preserved case** — `V1 EN 0 1.5` from a schematic net
   `EN`. The fold was never on our side of the deck.
2. **Flags may follow the deck filename**, so nothing parses a `cmd` template
   hunting for an insertion point.
3. **A released ngspice ignores both flags in silence** — stronger than A1, which
   claimed only "accepts and ignores". ngspice-46, same deck, with and without
   `-D casemode=preserve -D casemodewrite`: rc 0 both ways, run logs differing
   only in the raw filename and timing noise. *An earlier reading said `rc=141`;
   that was `SIGPIPE` from a `| head` in the measuring command, not the simulator.*

## The defect this work shipped and then caught

The first revision appended the flags whenever a mode was requested. Driving
shipped **row 0** produced

```
xterm -e {ngspice -i "$N" -a || sh} -D casemode=preserve -D casemodewrite
```

— flags for the **terminal emulator**, two levels out from the simulator. Fixed
by `sim_profile_cmd_takes_flags`: append only where the first word is *known* to
be the simulator (the exe plan applied, or a bare `ngspice*` first word).
Everything else is `unplaceable`, appends nothing, and **says so at tag `error`**.
`CS210`/`CS211`/`CS215` exist because of this and redden when it regresses.

## Sabotage verification — 5 drives, tree restored byte-exact (`md5sum -c` OK)

| sabotage | reddened |
|---|---|
| `netlist_case_mode()` back to the floor (C) | `CS220` only — 26 others stayed green |
| `sim_profile_run_flags` returns `{}` | 9 checks incl. `CS205 CS213 CS221` |
| `casemodewrite` dropped from the flag list | `CS205 CS213` **and `CS221`'s `src=<header>`** |
| placement gate always yes (the shipped defect) | `CS210 CS211 CS215` |
| exe never substituted | `CS201b CS201c CS221` |

`CS220` is the only check that can tell whether the C wire moved, and it observes
**behaviour**: netlist a colliding schematic twice, moving only the default row's
mode, and require the collision warning to appear and then vanish.

## The goal, end to end, measured

```
schematic net EN
  -> xschem netlist          V1 EN 0 1.5              (verbatim)
  -> proc simulate           <registered ver_50> -b -r ... -D casemode=preserve
                                                      -D casemodewrite
  -> xschem raw list         time | v(EN) | v(OUT) | i(V1)
  -> xschem raw casemode     preserve   (source header)
```

`v(EN)`, through the **Simulate button**, with the mode resolved from the raw's
own header — a source that had never once been reachable before this change.

## Compatibility

`CS200` carries both halves in one assertion, so it cannot pass by the feature
being absent: a row naming no exe and requesting `fold` — A1's default, and the
shipped state — composes **byte-identically**, while a configured row does not.
`CS217` pins that such a configuration also says nothing in the CIW.

## Suites

`test_sim_plain_run` 27, `test_sim_profiles` 97, `test_sim_probe` 61,
`test_sim_run_profile` 38, `test_netlist_case_collision` 39,
`test_raw_case_mode` 277, `test_wave_casemode` 74, `test_ase_result_case` 28,
`test_ase_current_repair` 53 — **all pass** (694 + 27).
Full audit: `audit_issue0506_2026-08-18.txt`, diffed by NAME and STATUS against
`audit_item15_closer_2026-08-18.txt`.

## Owed

Two `look` debts recorded at the moment they were incurred (the three new CIW
lines; the whole goal rendered in the viewer). **A green suite does not discharge
either.** `EYEBALL_SIGNOFF.md` steps 48–59, with a committed fixture
`eyeball_en_goal.sch`.

## Not done, and named

The `-n` box stays ASE-L-only; no probe and therefore no B4 verdict on this path;
nothing emitted for Spectre/VACASK; and **item 13's dialog says nothing about any
of this** — an `unplaceable` row is discovered at run time in the CIW, not at
configure time. Surfacing it in the dialog's status line is a real improvement
and is not here.
