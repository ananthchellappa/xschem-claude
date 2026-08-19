# 0506 — the plain Simulate path ignores the simulator profile the dialog just measured

**Status:** OPEN → being fixed in this change. Measured on branch `fluid-editing` at
`c126ac9a`, after the casemode batch closed.
**Area:** `proc simulate` (`src/xschem.tcl:5853`), `netlist_case_mode()`
(`src/save.c:2932`).
**Found:** 2026-08-18, by the user asking how far the batch got from the stated goal
("a net named `EN` in the schematic, displayed in the waveform viewer as `v(EN)`").
**Supersedes a scope line, deliberately:** `doc/claude/specs/simulator_profiles.md` §10
says *"Any `cmd` rewriting. Nothing derives a `cmd` from an `exe` or vice versa"*, and
§10's `netlist_case_mode()` ruling says item 6 leaves that wrapper unwired. Both were
correct **for item 6**, whose contract was an empty audit diff and a byte-identical
simrc. They are not correct as permanent policy, and this issue is the consumer §10
said would come.

---

## What

Items 6, 7 and 13 built a per-simulator profile: an `exe`, `args`, a requested
`Case` mode, a `-n` box, and a **Test** button that probes the binary and offers only
the modes it was measured to deliver. All of that works — measured 2026-08-18:

```
ver_50   probe status ok          detected {fold preserve distinguish}  Case menu offers all three
46       probe status nocasemode  detected {fold}                       Case menu offers fold only
```

**And then none of it reaches the run.** `proc simulate` executes
`sim($tool,$def,cmd)` verbatim. The shipped batch row is

```tcl
set sim(spice,2,cmd) {ngspice -b -r "$n.raw" "$N"}
```

— a bare `ngspice` off `PATH`, with no `-D casemode=`. So:

| path | uses the row's `exe` | uses the row's `Case` |
|---|---|---|
| ASE-L (`::ase::backend::ngspice::run_cmd`) | yes | yes |
| `Simulation ▸ Simulate` | **no** | **no** |

The user-visible sequence: register a case-capable ngspice, set `Case = preserve`,
press **Test**, read *"delivers fold preserve distinguish"* — then press **Simulate**
and get a different binary, at `fold`. The dialog told the truth about a binary it
then did not run.

## The second half — `casemodewrite`, which nothing emits anywhere

ngspice writes the self-describing `Option: casemode=<mode>` raw header **only** when
the `casemodewrite` variable is set (`outitf.c:994`, `rawfile.c:205` in the ver_50
tree). Nothing in xschem sets it — one grep hit in `src/`, and it is a comment.

Item 3 built the header parser as **mode source 2**, the second-strongest of the four
sources, and it can never fire on a file we caused to be written. Measured on one
preserved raw of the same deck:

```
without casemodewrite:   xschem raw casemode -> unknown    source none
with    casemodewrite:   xschem raw casemode -> preserve   source header
```

The `unknown` is not itself a bug — source 3 compares the schematic's spelling against
the raw's, and a **match** is ambiguous between `preserve` and `distinguish`; only a
mismatch is diagnostic, which is why a folded raw of the same schematic correctly
answers `fold/schematic`. But the header would settle it outright, and the viewer's
`Options ▸ Case Mode` readout says *"unknown — nothing could tell"* on a file we could
have made self-describing for one flag.

## Measured, and it is what makes the fix safe

Both taken 2026-08-18 on this machine.

**Append position is fine** — the flags do not have to precede the deck, so the fix
never has to parse a `cmd` template to find an insertion point:

```
ngspice -b -r q1.raw en_goal.spice -D casemode=preserve -D casemodewrite
  -> rc 0, Option: casemode=preserve, v(EN)
```

**A released ngspice ignores both flags in silence** — not merely "accepts", which is
all `DECISIONS.md` A1 claimed. `/usr/local/bin/ngspice` (46) with and without the two
flags, same deck:

```
rc 0 both ways; run logs diff only in the raw filename and timing noise.
No "unknown option", nothing on stderr, no casemode mention at all.
```

An earlier reading of this measurement said `rc=141`. That was `SIGPIPE` from a
`| head` in the measuring command, not the simulator.

## What the fix must not do

1. **It must not rewrite arbitrary `cmd` templates.** §10's ban was sound reasoning
   applied to a real hazard: row 0 is `$terminal -e {ngspice -i "$N" -a || sh}` and
   row 4 is `mpirun /path/to/parallel/Xyce "$N"`. "Replace the simulator in this
   string" has no general answer, and guessing one silently runs the wrong binary —
   the very defect being fixed.
2. **It must not change the command line of a user who asked for nothing.** That is
   item 6's compatibility contract, and A1's reasoning: a stock `apt` user never
   requested any of this and must not start seeing new flags.
3. **It must not emit a flag whose effect it cannot claim.** `-D casemode=` means
   nothing to Xyce, and nothing to a non-spice netlist type.

## The fix

Three parts, all gated so that a configuration nobody has touched produces a
byte-identical command line.

1. **Exe** — substitute the profile's resolved executable for `cmd`'s **first word**,
   and only when that word is a bare literal (no `$`, no `[`) whose `file tail`
   equals the registered exe's `file tail`. That covers every shipped ngspice row
   unambiguously and declines on both hazards in point 1 above: `$terminal` is not a
   literal, and `mpirun`'s tail matches no registered ngspice. A registered exe that
   cannot be applied is **reported, never guessed at**.
2. **Case flags** — append `-D casemode=<mode> -D casemodewrite` when the row's
   requested mode is not `fold`, the tool is `spice`, and the row is not Xyce. The
   non-`fold` gate mirrors ASE-L's own ruling (`simulator_profiles.md` §12.3) and is
   what keeps point 2 above true: `fold` is the default, so the default emits nothing.
3. **`netlist_case_mode()`** — ask the profile instead of returning the global floor,
   for `CAD_SPICE_NETLIST` only. §10 names the expression; asking only for the one
   netlist type whose `sim()` tool name is known disposes of §10's "netlist_type is not
   always a sim() tool name" caveat by construction, and an out-of-range index already
   reads as "unset" through `sim_profile_get`. With no row carrying a `casemode` — the
   shipped state — this is identical to today.

## What is NOT claimed

Nobody has measured what a **Spectre/VACASK** row does with a `Case` field, and the fix
deliberately does not emit for it. The `-n` (`--no-spiceinit`) box stays ASE-L-only:
A2's reasoning is about a run ASE-L probes immediately beforehand, and the plain path
runs no probe, so honouring `-n` there would suppress a user's init file with nothing
watching the result.
