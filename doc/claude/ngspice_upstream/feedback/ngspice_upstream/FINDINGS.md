# ngspice `casemode` — findings from a client-program integration

Nine findings, ranked by what they cost a program that consumes ngspice output.
All **measured** 2026-08-12 against `build-ver_50/src/ngspice`
(`ngspice-46+`, build stamp `Wed Aug 12 19:28:37 UTC 2026`), with
`/usr/local/bin/ngspice` (`ngspice-46`, no `casemode` support) as the baseline.

Reproduce everything: **`./repro/run_all.sh [case-capable-ngspice] [baseline-ngspice]`**
(defaults are the two paths above). Each finding below names the deck it uses.

**Findings 1, 2 and 7 have been fixed since these measurements were taken, and
finding 4 half fixed**; each carries a note saying so at its head, the
transcripts under them are left as measured, and `run_all.sh` runs the same
decks against both binaries so the before and the after are visible side by
side. **Finding 3 was fixed and the fix was withdrawn on 2026-08-13** — the
transcript below is current behaviour again, on both binaries. Two notes are
worth reading before re-measuring: finding 3's, because three different
discriminators were built and every one of them also refused correct decks;
and finding 4's, because its **ask** — fire the "differs only in case" warning
from `.save` — is met, while the wider headline it is filed under is not, for
the same reason: a report of every unresolved `.save` token shipped, fired on
correct decks, and was withdrawn.

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

> **Shipped 2026-08-14, in the form this finding asked for.** `raw_write()`
> (`src/frontend/rawfile.c`) emits `Option: casemode=<mode>` immediately after
> the `Plotname:` line, in both the ASCII and the binary format, and the value
> is the mode in force — `inp_case_mode_name()`, what `curcasemode` answers —
> not the `casemode` variable. Measured against the unmodified
> `/usr/local/bin/ngspice` (`ngspice-46`): both files load with no diagnostic
> and `echo $casemode` answers the header's value there as well.
> `doc/codex/issues/0061` is what had to land first — an `Option:` line used to
> reconfigure the next netlist read of any session that loaded the file, so
> writing this line into every raw file would have made every loaded raw file
> steer the deck read after it; that is fixed, and re-measured after this
> change. Two limits worth knowing, both measured in that issue's addendum: the
> `-r`/batch writer (`src/frontend/outitf.c`) is a different function and does
> not carry the line yet, and a plot that was *loaded* and then re-written
> records the writing session's mode beside names spelled under the original
> one. Everything below is the measurement as it stood before the change and is
> left as it was written.
>
> **Amended the same day: it ships opt-in, off by default.** Nothing above is
> withdrawn — the line is written in the form and place this finding asked
> for, and the compatibility measurement against `ngspice-46` stands. What
> changed is who asks for it: `set casemodewrite` before the `write`, and
> without it the header is byte for byte the header `58496a8dc` wrote,
> `cmp`-identical in both formats. The reason is a defect in the *released*
> binary. Loading such a file gives that session a `casemode` key in the
> loaded plot's environment, and `unset casemode` there frees a node it
> leaves linked (`doc/codex/issues/0067`, fixed in this tree, in nothing
> released): on `/usr/local/bin/ngspice`, `ngspice-46`, the `unset` returns
> cleanly and **the next command of any kind is a SIGSEGV** — `set`, `echo
> $casemode`, `display`, `print` and a second `unset` each measured at
> `rc=139`, in the ASCII and the binary format alike. A file we write must
> not become a crash trigger for a simulator that cannot be fixed unless
> somebody asked for the line. The default flips once 0067 has been in a
> release; the switch is described for the client in
> `RESPONSE.md` §2 and in `doc/claude/casemode-distinguish-guide.md` §9.

*Decks: `repro/divider.cir`, nets `In`/`MidNode`, source `Vs`; and
`repro/ascii_raw.cir` for the header experiments below, which need a raw whose
payload is text.*

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
the tool. Right now every consumer must spawn a throwaway simulation just to
learn something the writer already knew and threw away. That probe needs no raw
file and no temp file — a deck on stdin plus `display` reports the stored
spelling — but it does need a deck, and finding 6 is why nothing cheaper works.

**Ask:** record the mode in the header. **Not** as a new `Casemode:` key. That
was the original form of this ask and it is wrong — measured, it breaks every
existing reader, ngspice's own included:

```
$ awk '/^Command:/{print; print "Casemode: preserve"; next} {print}' \
      ascii_raw.raw > hdr_newkey.raw
$ echo 'load hdr_newkey.raw' | ngspice -p -n
Error: strange line in rawfile:
  Casemode: preserve
  load aborted.
```

Same on `ngspice-46` and on this build. The header loop in
`src/frontend/rawfile.c` ends in an `else` that aborts the load on any line it
does not recognise; unknown keys are not skipped.

Use a key the reader already parses. `Option:`, emitted after `Plotname:`:

```
Plotname: Operating Point
Option: casemode=preserve
```

Measured against the **unmodified** `ngspice-46`: the plot loads with no
diagnostic, and the reader files the pair into the plot's environment, so
`echo $casemode` answers `preserve` after the `load`. That is genuinely
backward compatible, it travels with the file, and it deletes the probe
apparatus from every downstream tool. Order matters — placed *before*
`Plotname:` the same line still loads the plot but prints
`Error: misplaced Option: line`.

---

## 2. ⭐ `.save` does not fold under `preserve`, but `print` does

*Decks: `repro/print_lower.cir`, `repro/save_lower.cir`. Same circuit, same
mode, same identifier — the net is `MidNode`, both decks spell it `midnode`.*

> **Fixed since this was measured.** Everything below was true of the build it
> names. `doc/codex/issues/0056` replaced `name_eq()`'s byte-exact compare with
> `vec_name_eq()`, so a `.save` now resolves a mis-cased name under `preserve`
> exactly as `print` does, and the branch-current row goes with it. What
> survives is `distinguish`, where **both** commands are exact — that is the
> mode's contract, not this asymmetry. `repro/run_all.sh` section 2 measures
> the fix; the baseline binary there still shows the behaviour reported here.

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

**Root cause.** `.save` names are matched against the run's variable names by
`name_eq()`, `src/frontend/outitf.c:1338`, whose last line is a bare `strcmp`.
It is byte-exact in every mode, and it is not wired to the identity helpers the
rest of the build uses — `tests/lint/identity.baseline:196` already carries it
as an un-migrated comparison. Under `fold` it appears to work only because the
`.save` card's own text was lowercased upstream before it ever reached this
function; `preserve` stops folding the card, and the byte-exact compare is left
exposed.

**Why this is the biggest migration hazard.** It hits hardest exactly the tools
that were already doing the right thing under fold. Any tool that lower-cased
names to cope with fold mode — which is the natural thing to do, and what
xschem did — has every stored `.save` card become fatal the moment the user
selects `preserve`. Nothing warns; the run just stops producing data.

---

## 3. A failed `.save` still writes a well-formed raw — of the constants plot

*Deck: `repro/save_lower.cir`, the failing run from finding 2.*

> **Not fixed. A fix landed and was withdrawn on 2026-08-13**, so the
> transcript below is current behaviour; `doc/codex/issues/0059` is Open and
> its Resolution section is the account. What was tried: `write` with no vector
> list refused, on the error stream, when nothing had chosen the current plot
> or when the plot it had chosen was empty. Three generations of that guard
> shipped, and every one of them also refused a plain nutmeg session that
> builds vectors with `let` and writes them — in `--batch` and through
> `ngspice -p` alike — because those vectors live in the constants plot too,
> which is the very plot the guard read as evidence that nothing had been
> chosen. Writing no file for correct work is the worse failure, so it came
> out. One shape inside this finding was **decided** rather than attempted and
> is unaffected: a bare `write` after a good analysis and a failed rerun writes
> the good run's plot (`doc/claude/decisions/0017` decision 1, the one decision
> there that survives). Reaching this deck's own failure needs
> `-D casemode=distinguish`, because of finding 2's fix.

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

570 bytes, parses cleanly, 12 variables. A consumer that tests only for a
well-formed raw cannot tell this from a successful run — it attaches the
database and shows the user `yes`, `FALSE`, `boltz` as signals. Two tells do
exist for a reader that knows to look: `Plotname: constants`, and a `Date:`
that is the build stamp rather than the run time. Neither is something a raw
reader has any prior reason to test, and `rc` — the obvious defence — is not
available to a tool that streams output rather than waiting on the process.

**Ask:** `write` should refuse (and say so) when the current plot is
`constants`, or when no analysis ran. This is independent of `casemode` —
`preserve`'s strict `.save` just makes it trivially easy to reach.

---

## 4. Nothing in the output names the offending token

*Deck: `repro/save_lower.cir`.* Grepping the **entire** stdout+stderr of the
failing run for `midnode` finds nothing. All the user or the tool gets is:

> **Half fixed since this was measured**, by `doc/codex/issues/0057`, and the
> half that is not fixed was withdrawn on purpose — read this before
> re-running `repro/run_all.sh` section 4.
>
> **Fixed:** the deck below. A `.save` token that misses **and** has a case
> variant among the run's own names is now reported on `stderr`, naming both
> spellings — `midnode` and `MidNode` — which is exactly this finding's ask.
> Since `0056` that deck only fails under `distinguish`, so that is the mode
> section 4 runs it in.
>
> **Withdrawn:** a `.save` of a name that is simply absent, with no case
> variant anywhere, is silent again, as in stock `ngspice-46`. The wider
> report shipped in three earlier rounds and each round's verification found
> another *correct* deck it fired on — `onoise_total` in a `.noise` plot, an
> XSPICE event node, a `gettoks()` fragment, and two shipped decks under
> `examples/` — so it was replaced by the two-condition rule the tree already
> had (`doc/claude/decisions/0001-distinguish.md` decision 2). `0057`'s Status
> states the cost in the same terms. `rc` is still 1 for such a run; what is
> missing is the token.

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

`.spiceinit` is searched in the **deck's own directory**, not the working
directory — measured by running from the parent with the deck in a
subdirectory, which still folded. So a stale one shipped alongside somebody
else's deck defeats the flag, with no diagnostic.

This is deliberate rather than an oversight, and the tree says so. The comment
above `set_case_mode()`, `src/frontend/inpcom.c:1079`: *"the last writer before
the deck is read wins: `.spiceinit` is sourced after the `-D` getopt loop and
therefore overrides it"*. So the ask below is to revisit a decision, not to fix
a slip — but a command-line option losing to an init file still inverts the
usual Unix precedence, and nothing reports that it happened.

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

Related: **a build without the feature accepts `-D casemode=preserve` and
ignores it**, exiting 0 with folded names. That is arguably correct for an
arbitrary `-D`.

A *valid* value therefore signals nothing — but an invalid one does. Measured,
`-D casemode=bogus`: zero matching lines from `ngspice-46`, two from this
build. The `distinguish` banner separates the two builds the same way. This
tree also already documents a cleaner behavioural probe,
`doc/claude/casemode-distinguish-guide.md` §9, which asks "will the run I am
about to launch be case-sensitive?" instead of "is the feature compiled in?" —
the right question, since a `spinit` or `.spiceinit` can defeat the flag on a
build that has the feature (finding 5).

What none of those probes reach is `preserve`. They all work by creating two
names that differ only in case and asking whether they are two objects — an
*identity* test — and `preserve` folds identity exactly as `fold` does.
Control-language names carry no signal either: measured, `let MixedCase = 1`
stores `MixedCase` under all three modes. Detecting `preserve` takes a deck,
which is finding 1's argument arriving from the other end.

---

## 7. Warnings print once per file read, not once per run

> **Fixed since this was measured**, by `doc/codex/issues/0058` and
> `doc/claude/decisions/0016`: the announcement is latched, so each warning is
> printed once per run whatever the run reads. Every count below reads 1 on
> this tree.

```
$ ngspice -b -n -D casemode=bogus divider.cir      | grep -c 'unknown casemode'
2
$ ngspice -b -n -D casemode=distinguish case_collision.cir | grep -c experimental
2
```

**Root cause.** `set_case_mode()` is called from `inp_readall()`
(`src/frontend/inpcom.c:1178`), which reads *every* input file, not only the
deck — the system `spinit` is one such read and `.spiceinit` is another. So the
count is not fixed at two. Measured on the same deck, same flag:

| run | count |
|---|---|
| `SPICE_SCRIPTS` pointed at a directory with no `spinit` | 1 |
| normal, `-n` | 2 |
| normal, with a `.spiceinit` beside the deck | 3 |

Cosmetic on its own, but worse for log-scraping than a fixed duplicate would
be: a consumer counting diagnostics gets a number that varies with the user's
init files.

---

## 8. `$casemode` reports the request, not the effect

```
$ printf 'echo $casemode\nquit\n' | ngspice-46+ -p -n -D casemode=preserve
preserve
$ printf 'echo $casemode\nquit\n' | ngspice-46  -p -n -D casemode=preserve
preserve            <- folds everything, still says "preserve"
```

The variable is a record of what was asked for. On a build without the feature
it is an outright lie.

It diverges on *this* build too, with no second binary involved. The mode is
fixed once, when the deck is read, so any `set` after that point moves the
variable and nothing else (*deck: `repro/late_set.cir`*):

```
.control
set casemode=preserve
op
display          ->  midnode        <- folded, the deck was already read
echo $casemode   ->  preserve
.endc
```

Finding 5 is *not* a second instance of this, despite appearing to be: there
`.spiceinit` writes the variable and the variable is then read, so `$casemode`
answers `fold` — which is exactly what is in effect. Measured.

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
| 1 | `Option: casemode=<mode>` in the raw header, after `Plotname:` — *not* a new `Casemode:` key, which aborts existing readers | one line, high leverage — **done** |
| 2 | make `.save` fold under `preserve` like `print` does (or document the carve-out) — `name_eq()`, `outitf.c:1338` | design call |
| 3 | `write` refuses when the current plot is `constants` / no analysis ran | small |
| 4 | fire the existing "differs only in case" warning from `.save` | small |
| 5 | CLI `-D` beats `.spiceinit`, or warn on override | small |
| 6 | near-miss check on `-D` variable names | small |
| 7 | emit the warning once per run, not once per `inp_readall()` | trivial |
| 8 | read-only "effective mode" variable | small |
| 9 | warn when two identifiers fold together | small |

Asks 2, 4 and 7 are done in this tree — `doc/codex/issues/0056`, `0057` and
`0058`. **Ask 3 is not done**: `0059` is Open, its fix having been built three
times and withdrawn on 2026-08-13 because each version also refused correct
decks; `doc/claude/decisions/0017` decision 1 still holds for the one row of
ask 3 that was decided rather than changed. Ask 4 is done **as worded**: the
"differs only in case" warning does fire from `.save`. It is narrower than
finding 4's headline, which asked for the token to be named whether or not a
case variant exists; that wider report was built, fired on correct decks, and
withdrawn — `0057`'s Status. **Asks 1 and 8 are done too.** Ask 8 is
`doc/codex/issues/0060`, closed by the read-only `curcasemode` variable. Ask 1
is written exactly as this table words it — after `Plotname:`, on the
`Option:` key — by `raw_write()`, taking its value from the same function
`curcasemode` reads, and it had to ship in that order: it could only be
written once `doc/codex/issues/0061` had stopped a loaded `Option:` line from
steering the reading session's next netlist read. That issue carries the
argument and the measurements, in its Resolution and its 2026-08-14 addendum.
Asks 5, 6 and 9 have no issue of their own yet.

## Method notes, for whoever re-runs this

- **Decks need a title line.** A deck whose first line is a card loses that card
  silently — an early round of these measurements was invalidated that way
  (`Vs In 0 DC 3` became the circuit title, so the source did not exist and
  every voltage read 0). Every deck in `repro/` starts with a comment.
- **Raw files are binary; `grep` needs `-a`.** A probe that greps the Variables
  section without it reports nothing and looks like a capability failure.
- **The header experiments in finding 1 need an ASCII raw** (`set
  filetype=ascii` before `write`), so that `awk` can splice a line into the
  header without corrupting a binary payload. The header itself is text in both
  formats, but rewriting it in place is only safe in the ASCII one.
- Two separate redirections, not `2>&1`: stderr is unbuffered and scrambles
  relative to the stdout line that caused it.
