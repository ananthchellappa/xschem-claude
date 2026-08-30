# 0931 — there is no way to point ASE-L at a simulator that is not on PATH

**STATUS: FIXED (non-GUI half, item S1), 2026-08-29.** The GUI front door —
a Setup dialog that lists, adds and removes entries — is item S2 and must
call `ase::sim_write_conf`, which is the writer this item put in place for it.

## What the user could not do

They have an ngspice build of their own, in a directory of their own. There
was no place in ASE-L to say so. The Setup and Simulation menus had no entry
for it; the session window's bottom bar shows the backend name, never the
program that will actually be started; nothing was remembered between
restarts. The only lever was the `PATH` of the shell that launched xschem —
global to the whole process, invisible from inside it, and impossible to
name, list or take back.

## Measured at HEAD 0e6cb3cb, before the change

The whole body of `ase::backend::ngspice::run_cmd` (src/ase.tcl:4205-4207):

    return [list ngspice -b $deckpath 2>@1]

Five different states — including ones carrying an absolute path under
`binary`, `simulator_path` and `exe` — produced five byte-identical answers:
`$state` was accepted and never read. And a `run_cmd` that *had* consulted its
argument would have had nothing to consult. Searching the running interpreter:
no proc in `::ase::` matched `binar|resolv|which|simpath|exepath|registry`;
the only `ASE_*` globals were `ASE_COSIM_BUILD`, `ASE_DEFAULT_INCLUDES`,
`ASE_DEFAULT_MODELS`; `ase::schema_keys` had no binary key; `$USER_CONF_DIR`
held nothing about simulators and ASE-L wrote nothing there
(`grep -c USER_CONF_DIR src/ase_window.tcl` → 0). Setting `::ASE_SIMULATORS`,
`::ASE_SIMULATOR_PATH` or `::ASE_NGSPICE` as plain globals before `ase.tcl`
was sourced — the idiom `sky130A/cadence_style_rc:37` uses for
`ASE_DEFAULT_MODELS` — changed nothing; nothing read them.

Prepending the custom directory to `PATH` *does* work: `auto_execok ngspice`
then resolves to it, while the command ASE-L builds is byte-identical in both
runs. That is the whole point — the choice lives outside the program.

**The absent thing was the entire configuration surface, not one literal word.**

## The shape this must not copy, already shipped one proc away

`ase::cosim_build_script` (src/ase.tcl) is this tree's only other
"an rc variable names an executable" resolver. Measured in both bad arms:

* `::ASE_COSIM_BUILD` naming a file that does not exist → returns empty,
  **says nothing**;
* `::ASE_COSIM_BUILD` naming a file that exists at mode 644 and is not
  executable → returns empty, **says nothing**;
* the sentence the user is then shown is
  `build_cosim_so.sh not found (set ::ASE_COSIM_BUILD)` — blaming the
  variable as unset when it is set and merely wrong.

It also has no `file isfile` guard, and `file executable` answers 1 for a
**directory**, so a folder passes it. Row C7 of the suite pins that silence as
KNOWN so nobody satisfies this item by copying the neighbour, and so the day
it is repaired that row is what says so. **It is not fixed here** (out of
scope) and deserves its own issue — see the open questions.

## What was built

### One resolver

`ase::sim_status <backend>` is the single answer to "which program will
actually be started". It never raises, and returns one dict:

| field | meaning |
|---|---|
| `ok` | 1 when something can be started; 0 when the user's own choice cannot be honoured |
| `exe` | argv0, exactly as it will be handed to `execute` |
| `args` | the extra arguments that go before the deck |
| `resolved` | the absolute file this names, or `auto_execok`'s answer when the PATH is in charge |
| `source` | `registry` when a registered entry answered, `path` when the program on the PATH did |
| `entry` | the registered name that answered, or empty |
| `why` | the one sentence to show the user, or empty. **Non-empty with `ok` 1 is real**: the run proceeds on the PATH program and the user should know why |

`ase::backend::ngspice::run_cmd` builds its command from it, `ase::sim_exe`
raises its sentence, and a future caller asking merely "is a simulator
available" reads `resolved`. That is what the warning in `ase::run_deck` asks
for, not a violation of it: that comment forbids **re-deriving** argv0 after
the fact for the log header, computed at a different instant from the exec
that ran it. Here it is derived **once**, inside `run_cmd`, and the same
string is both launched and stamped into the log's `command` line.

### A registry

`{name <label> path <program> args <extra argv> backend <name or empty>}`,
driven by `ase::sim_register` / `sim_unregister` / `sim_select` /
`sim_selected` / `sim_list` / `sim_clear`. Insertion order is the order the
user registered them in.

### Three layers, in this order

1. **rc** — `::ASE_SIMULATORS` (a list of entry dicts) and `::ASE_SIMULATOR`
   (the name to put in force), `set_ne` beside `ASE_DEFAULT_MODELS` /
   `ASE_DEFAULT_INCLUDES` and seeded at the end of the registry section.
   An rc cannot call `ase::sim_register` directly — the proc does not exist
   when the rc runs — so the rc declares data and the seed turns it into
   entries. **Removing one is the rc no longer declaring it**: the registry is
   rebuilt from those two variables at every startup, so nothing lingers.
2. **the user's own file** — `$USER_CONF_DIR/ase_simulators`, written by
   `ase::sim_write_conf` and read once at startup by `src/xschem.tcl` beside
   `load_recent_file` / `load_net_hilight_conf` / `wviewer::rawhist_load`.
3. **the session** — anything registered from the CIW, a script, or S2's
   dialog.

### Validation that speaks

`ase::sim_check` has four ordered guards, each with its own thing to say:
empty path, no file there, a folder rather than a program, not marked
executable. **The `file isfile` guard is the one a reader skips** and is the
hole `ase::cosim_build_script` has.

`ase::sim_why` is the **mint**: every user-facing sentence about a simulator
entry is written there once and rendered by callers (ruling D5-4). Each is
plain English at a ninth-grade level, says what happened *and* what to do, and
contains no proc names, variable names, state names or `auto_execok`. Row C6
scans them for machinery words; row D6 greps the comment-stripped source and
fails if any fixed phrase occurs more than once.

### Clause (c): nothing changes for a user who registers nothing

With an empty registry `ase::sim_status` answers with the bare backend name
and `auto_execok`'s file, and `run_cmd` returns the byte-identical command it
always returned. That is what keeps `test_ase_core`'s E1e / E2b / E4 goldens
green with nobody editing them, and it is asserted directly by row A2.

## Decisions the user has not ratified (owed as a `rule` debt)

**D1 — registering the first simulator puts it in force.** A later
registration never steals the choice. *Rejected: requiring an explicit pick
always, which makes "register one simulator" do nothing visible.*

**D2 — a registered simulator that is in force and whose file is broken makes
the run FAIL, with a sentence naming it.** *Rejected: falling back to the PATH
binary, which runs a different program than the user chose and mentions it
only in a pane they may not be reading — the D5-1 defect in another costume.*
`auto_execok` remains the fallback **only** when nothing is registered.

**D3 — an entry that fails validation is still recorded, flagged unusable, and
reported.** *Rejected: refusing to record it, which throws the user's typing
away mid-gesture and leaves nothing for S2's list to show them to fix.*

**D4 — the user's own file is read AFTER the rc seed**, so a personal entry
wins a same-name collision with a workarea rc; and an rc-declared entry
removed in-session comes back at the next startup, with a plain sentence
saying so at the moment it is removed. *Rejected: tombstones in the conf,
which would also hide a simulator the PDK adds later.*

**D5 — the conf writer skips rc-origin entries**, and skips the selection line
when what is in force came from an rc. *Rejected: writing everything, which
freezes a stale copy that shadows a later rc edit — and which would make the
file unreadable in a session where the rc no longer declares that name.*

**D6 — a registry path is expanded (`$::VAR` form) and normalised to absolute
at registration.** *Rejected: storing it verbatim — `ase::run_deck` `cd`s into
the run directory before it launches anything, so a relative argv0 would
silently resolve somewhere else.*

## Tests

`tests/headless/test_ase_simreg_0931.tcl` — 48 checks, written red first
(41 red / 1 green-by-design at HEAD 0e6cb3cb), green after the change on both
arms. Registered in `tests/headless/full_audit.sh`'s `nogui_tests` and in
`tests/run_regression.tcl`'s `hcases`, with the dual banner.

Row map: **A** the stock tree where nothing is registered (clause (c),
including the byte-identity guard A2); **B** register / list / select /
remove, path expansion and normalisation, malformed calls; **C** the four
ways a path can be wrong, each reported out loud, kept in the list, in four
distinct plain-English sentences, plus the C7 contrast against
`ase::cosim_build_script`; **D** the resolver — re-validation at resolution
time, an unknown selection, a backend mismatch, ambiguity, and one sentence
rendered by every caller; **E** the conf writer and reader, a **real
restart** in spawned children with `HOME` redirected, and the rc layer driven
through `--preinit` (which `xinit.c` runs before `xschemrc`, hence before
`ase.tcl` — the only honest stand-in for an rc); **F** the one-resolution
contract stated for the twelve `auto_execok ngspice` availability gates;
**G** the spec.

## Not in scope

* **The GUI front door is S2.** It must call `ase::sim_write_conf`, which
  takes no widget and touches no Tk for exactly that reason.
* **The twelve `auto_execok ngspice` availability gates** across twelve test
  suites still answer "is a simulator available" their own way, by a different
  rule from the one that now launches. Row F1 states the contract they would
  use. Repointing them is its own item.
* **`ase::cosim_build_script`'s two silent arms and its missing `isfile`
  guard** are a real, untested defect one proc away. Pinned as KNOWN by row
  C7; should be filed separately.
* **Deck rendering.** `-b`, `2>@1` and the absence of `-o` are unchanged, and
  rows A2 / B5 / B6 assert it byte for byte.

## Repair pass — what a sabotage run found, and what was done about it

A sabotage run neutralised each guard on its own and re-measured. Six problems
came back. All six are fixed; none was fixed by deleting a guard.

**One real defect in the shipped behaviour.** The rc seed wrapped the loop
BODY in a catch but left the loop HEADER outside it. `foreach x $v` parses
`$v` as a list before the body runs once, so an unbalanced brace in a startup
configuration file's `::ASE_SIMULATORS` raised while `ase.tcl` was being
sourced: measured, xschem exited with **no schematic editor at all**
(`STARTUP ABORTED … Failing file: … ase.tcl line 926`), while the identical
typo in `::ASE_DEFAULT_MODELS` / `::ASE_DEFAULT_INCLUDES` — the two rc
variables this seed was modelled on — starts normally. The `foreach` is now
inside the catch, and the report is minted like every other sentence
(`badrclist`; the per-entry one it sat beside became `badrcentry`). New row
**E12** measures the two side by side, so the parity is a check and not a
comment.

**The suite was not hermetic, and would have gone red on the first machine
that used the feature.** `$USER_CONF_DIR/ase_simulators` is read at startup,
so on a machine whose user has registered a simulator, "nothing is
registered" is false inside the test process too: measured, 7 rows red
(A1 A2 A3 A4 E8 E9 E10) on a tree with nothing wrong with it. The in-process
rows now clear the registry first, every child runs with `HOME` redirected
into the suite's own scratch tree, and **A4** — which claims something about a
*freshly started* xschem — became a real child that also asserts the run
command it builds. Re-measured with a saved list planted in a redirected home:
48/48, same as without.

**Five live guards no row could see.** Each now has a row, and each row was
proved by neutralising its guard alone and watching that row, and only that
row, go red:

| guard | row | what the user loses without it |
|---|---|---|
| the "it will be back next start" note on removing an rc-declared entry | **E13** | removes it, it silently returns, no idea why |
| the "that location names a setting I do not have" report | **C8** | told the file is missing when the thing to fix is a setting |
| the refusal when an option is typed without its value | **B14** | silently registered with a value they never typed |
| the filter on which simulators can serve this kind of run | **B15** | offered, and told to pick, a simulator that cannot run it |
| the silence when there is no saved list yet | **E11** | a red error sentence at every startup of every fresh install |

C8 also carries a trap worth keeping: an earlier draft named its fixture
`$::ZZ_NO_SUCH_SETTING` and passed against the **wrong** sentence, because the
word "setting" was in the path being echoed back. The user's own words — the
entry name and the location they typed — are now stripped out before the
sentence is read.
