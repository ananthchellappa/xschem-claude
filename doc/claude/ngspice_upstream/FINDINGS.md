# ngspice `casemode` — findings from a client-program integration

Nine findings, ranked by what they cost a program that consumes ngspice output.
All **measured** 2026-08-12 against `build-ver_50/src/ngspice`
(`ngspice-46+`, build stamp `Wed Aug 12 19:28:37 UTC 2026`), with
`/usr/local/bin/ngspice` (`ngspice-46`, no `casemode` support) as the baseline.

Reproduce everything: **`./repro/run_all.sh [case-capable-ngspice] [baseline-ngspice]`**
(defaults are the two paths above). Each finding below names the deck it uses.

**Context.** This came out of adding case-preserving signal names to xschem, a
schematic editor that generates decks, reads the raw file, and shows the names
back to the user. The two findings marked ⭐ are what stand between `preserve`
and a drop-in adoption. `preserve` is otherwise very well judged for this use —
labels for humans, folded identity so a PDK library defining `.SUBCKT NAND2`
stays callable as `nand2`, and none of `distinguish`'s silent traps.

Findings 1, 2, 3, 4 are the ones that cost real work downstream. 5–9 are
smaller.

---

## 1. ⭐ The raw-file header carries no casemode

*Deck: `repro/divider.cir`, nets `In`/`MidNode`, source `Vs`.*

```
Title: * baseline divider -- schematic nets In / MidNode, source Vs
Date: Wed Aug 12 23:13:01  2026
Command: ngspice-46+, Build Wed Aug 12 19:28:37 UTC 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
Variables:
	0	v(In)	voltage
	1	v(MidNode)	voltage
	2	i(Vs)	current
```

There is a `Command:` line but nothing recording how names were cased.

**Why it matters more than it looks.** Case mode is a property *of the run that
wrote the file*, not of the binary on `$PATH` today. A user who upgrades ngspice
and reopens last year's raw has no way to know how to read it, and neither does
the tool. Right now every consumer must spawn a throwaway simulation, write a
raw, and parse it just to learn something the writer already knew and threw
away.

**Ask:** one line, `Casemode: preserve`, beside `Command:`. Backward compatible
(readers skip unknown header keys), travels with the file, and deletes an entire
probe apparatus from every downstream tool.

---

## 2. ⭐ `.save` does not fold under `preserve`, but `print` does

*Decks: `repro/print_lower.cir`, `repro/save_lower.cir`. Same circuit, same
mode, same identifier — the net is `MidNode`, both decks spell it `midnode`.*

```
$ ngspice -b -n -D casemode=preserve print_lower.cir
v(midnode) = 2.250000e+00                       <- works, correct value

$ ngspice -b -n -D casemode=preserve save_lower.cir
Error: no data saved for D.C. Operating point analysis; analysis not run
Error: incomplete or empty netlist
rc=1                                            <- whole run dies
```

Same for branch currents (`repro/save_current_lower.cir`): `.save i(Vs)` is
rc=0, `.save i(vs)` is rc=1, against source `Vs`.

Full matrix, net `MidNode`:

| `.save` card | fold | preserve | distinguish |
|---|---|---|---|
| `.save v(MidNode)` | rc=0 → `v(midnode)` | rc=0 → `v(MidNode)` | rc=0 → `v(MidNode)` |
| `.save v(midnode)` | rc=0 → `v(midnode)` | **rc=1, no vectors** | **rc=1, no vectors** |

**The contradiction.** `preserve`'s contract is "labels preserved, *identity
folds*". `print` honours it. `.save` does not. Either that is a bug, or
`preserve` needs documenting as "identity folds except in `.save`".

**Why this is the biggest migration hazard.** It hits hardest exactly the tools
that were already doing the right thing under fold. Any tool that lower-cased
names to cope with fold mode — which is the natural thing to do, and what
xschem did — has every stored `.save` card become fatal the moment the user
selects `preserve`. Nothing warns; the run just stops producing data.

---

## 3. A failed `.save` still writes a well-formed raw — of the constants plot

*Deck: `repro/save_lower.cir`, the failing run from finding 2.*

```
$ ls -la save_lower.raw
-rw-r--r-- 1 qflow qflow 570 Aug 12 23:13 save_lower.raw

Title: Constant values
Date: Wed Aug 12 19:28:37 UTC 2026
Command: ngspice-46+, Build Wed Aug 12 19:28:37 UTC 2026
Plotname: constants
Flags: complex
No. Variables: 12
Variables:
	0	yes	notype
	1	FALSE	notype
	2	TRUE	notype
	3	boltz	notype
	...
```

570 bytes, parses cleanly, 12 variables. A consumer cannot distinguish this
from a successful run — it attaches the database and shows the user `yes`,
`FALSE`, `boltz` as signals. Checking `rc` is the only defence, and a tool that
streams output rather than waiting on the process does not have one.

**Ask:** `write` should refuse (and say so) when the current plot is
`constants`, or when no analysis ran. This is independent of `casemode` —
`preserve`'s strict `.save` just makes it trivially easy to reach.

---

## 4. Nothing in the output names the offending token

*Deck: `repro/save_lower.cir`.* Grepping the **entire** stdout+stderr of the
failing run for `midnode` finds nothing. All the user or the tool gets is:

```
Error: no data saved for D.C. Operating point analysis; analysis not run
```

Meanwhile `distinguish` mode already emits exactly the right message, for the
same identifier, from the `print` path:

```
Warning: no vector named 'midnode'; 'MidNode' differs only in case (casemode=distinguish)
```

**Ask:** fire that message from `.save` too, in every non-fold mode. The
diagnostic exists and is well worded; it is simply not wired to the path where
it matters most. Combined with finding 3, the current behaviour is: no name, no
usable exit signal, and a plausible-looking artefact.

---

## 5. `.spiceinit` silently overrides `-D casemode=`

*Deck: `repro/spiceinit/deck.cir`, with a sibling `.spiceinit` holding
`set casemode=fold`.*

```
$ ngspice -b    -D casemode=preserve deck.cir     # no -n
	0	v(in)	voltage                        <- folded; the flag lost
	1	v(midnode)	voltage

$ ngspice -b -n -D casemode=preserve deck.cir     # with -n
	0	v(In)	voltage                        <- preserved
	1	v(MidNode)	voltage
```

`.spiceinit` is searched in the **deck's own directory** first, so a stale one
shipped alongside somebody else's deck defeats the flag with no diagnostic.
A command-line option losing to an init file inverts the usual Unix precedence.

**Ask:** make the CLI win, or warn on override. The workaround (`-n`) is not
free — it also discards the user's own legitimate `.spiceinit` customisations.

---

## 6. A misspelled variable *name* is silent; a bad *value* is caught

*Deck: `repro/divider.cir`.*

```
$ ngspice -b -n -D CaseMode=preserve divider.cir     # capital M
(no diagnostic at all)

$ ngspice -b -n -D casemode=bogus divider.cir
Warning: unknown casemode 'bogus', using 'fold'
```

The value check is good. The machinery clearly exists — extend it to a
near-miss check on known control-variable names, so `CaseMode`, `case_mode` and
`casemodes` are not silent no-ops.

Related, and the reason clients get silently wrong answers: **a build without
the feature accepts `-D casemode=preserve` and ignores it**, exiting 0 with
folded names. That is arguably correct for an arbitrary `-D`, but it means the
flag can never be used as a capability signal.

---

## 7. Warnings print twice

```
$ ngspice -b -n -D casemode=bogus divider.cir      | grep -c 'unknown casemode'
2
$ ngspice -b -n -D casemode=distinguish case_collision.cir | grep -c experimental
2
```

Cosmetic, but it makes log-scraping ambiguous — a consumer counting
diagnostics sees two problems where there is one.

---

## 8. `$casemode` reports the request, not the effect

```
$ printf 'echo $casemode\nquit\n' | ngspice-46+ -p -n -D casemode=preserve
preserve
$ printf 'echo $casemode\nquit\n' | ngspice-46  -p -n -D casemode=preserve
preserve            <- folds everything, still says "preserve"
```

The variable is a record of what was asked for. On a build without the feature
it is an outright lie, and finding 5 gives a second way for it to diverge.

**Ask:** expose the *effective* mode as a read-only variable. Finding 1 covers
this for files; this covers pipe and interactive use.

---

## 9. Two nets differing only in case collapse silently under `preserve`

*Deck: `repro/case_collision.cir`, nets `Out` and `OUT`.*

```
$ ngspice -b -n -D casemode=preserve case_collision.cir
(no diagnostic)
Variables:
	0	v(In)	voltage
	1	v(Out)	voltage       <- OUT is gone; first spelling won
	2	i(Vs)	current
```

Strictly correct under identity-folds, and fold mode does the same thing. But
under `preserve` the surviving label now carries capitals, so it *reads* as the
deliberate spelling rather than as one of two that were merged. `distinguish`
gives two nets plus its experimental banner.

**Ask:** `Warning: net 'OUT' folded into 'Out'` under fold and preserve. Cheap,
and it is the only signal a schematic tool could relay to a user who drew two
nets and got one.

---

## Summary of asks

| # | ask | size |
|---|---|---|
| 1 | `Casemode:` line in the raw header | one line, high leverage |
| 2 | make `.save` fold under `preserve` like `print` does (or document the carve-out) | design call |
| 3 | `write` refuses when the current plot is `constants` / no analysis ran | small |
| 4 | fire the existing "differs only in case" warning from `.save` | small |
| 5 | CLI `-D` beats `.spiceinit`, or warn on override | small |
| 6 | near-miss check on `-D` variable names | small |
| 7 | de-duplicate the two warnings | trivial |
| 8 | read-only "effective mode" variable | small |
| 9 | warn when two identifiers fold together | small |

## Method notes, for whoever re-runs this

- **Decks need a title line.** A deck whose first line is a card loses that card
  silently — an early round of these measurements was invalidated that way
  (`Vs In 0 DC 3` became the circuit title, so the source did not exist and
  every voltage read 0). Every deck in `repro/` starts with a comment.
- **Raw files are binary; `grep` needs `-a`.** A probe that greps the Variables
  section without it reports nothing and looks like a capability failure.
- Two separate redirections, not `2>&1`: stderr is unbuffered and scrambles
  relative to the stdout line that caused it.
