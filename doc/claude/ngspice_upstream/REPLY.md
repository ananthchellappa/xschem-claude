# Reply to `RESPONSE.md` — what we adopted, six new findings, four open questions

Round 2, from the xschem side. Written 2026-08-14 against
`build-ver_50/src/ngspice` reporting `ngspice-46+`, build stamp
**`Thu Aug 13 22:49:54 UTC 2026`** — i.e. the tree that answered round 1, with
`0056`, `0057`, `0058` and `0060` in it. Baseline is `/usr/local/bin/ngspice`
(`ngspice-46`).

Everything below was re-measured, not carried over.
Reproduce: **`./repro2/run_round2.sh [case-capable-ngspice] [baseline-ngspice]`**.

Round 1 is `FINDINGS.md` here; its updated form, with the response's notes at
each finding's head, came back as `feedback/ngspice_upstream/FINDINGS.md` and is
the newer copy. `repro2/` does not supersede either `repro/` directory — it
holds the shapes round 1 did not measure.

---

## 1. Confirmed fixed, and adopted

**`0056` — the ⭐ blocker is gone.** `.save v(midnode)` against a net spelled
`MidNode` is rc=0 under `preserve` and labels the vector `v(MidNode)`. Measured
across all three modes. This is the finding that stood between `preserve` and a
drop-in adoption, and it removes an entire migration pass from our plan: every
lower-cased `.save` card a tool stored to cope with `fold` now works unchanged.

**`0060` — `$curcasemode` is exactly the right shape.** It replaces our probe
apparatus outright: a temp deck, a temp raw, a binary-safe grep of the Variables
section and an eight-cell verdict matrix become one pipe with no filesystem
side-effects at all.

```
printf 'echo CCM=$curcasemode\nquit\n' | ngspice -p <the real run's args>
```

We are relying on two properties of it, both measured (R5 below), and it would
help to know they are intended rather than incidental:

- it reports the mode **after** `.spiceinit` has had its say, so it answers the
  question a client actually has — "what will *this* run do?" — not "what was
  requested";
- its absence on an older build is a clean negative: empty on stdout, an error
  on stderr, rc unchanged.

We have stopped reading `$casemode`, and the "requested vs effective" split is
recorded in our own docs as a trap rather than a bug.

**`0058`** — both announcements now fire once per run. Measured 1 and 1. See R4
for the one that still doubles.

**`0057`** — the near-miss warning does fire from `.save`, naming both
spellings. Adopted as worded. We are not expecting a diagnostic for a name with
no case twin, and R2 is about what that costs rather than an ask to revisit it.

**Finding 1, on the carrier.** Our original ask was wrong and your measurement
corrected it: a new `Casemode:` key aborts every existing reader. `Option:`
after `Plotname:` is right. Checked our end — `read_dataset` in `save.c` is an
else-if chain over known prefixes with no catch-all, so an `Option:` line is
already inert for us today and becomes readable with one added branch.

---

## 2. Six new findings

Three of the six reproduce on stock `ngspice-46` and are not casemode defects
at all. They surfaced here because `0056` moved the failure they hide behind.

### R1. The same failure exits 0 inside `.control` and 1 outside it

```
$ ngspice -b -n -D casemode=distinguish -r plain_fail.raw plain_fail.cir
rc=1                                        <- no raw written

$ ngspice -b -n -D casemode=distinguish ctl_fail.cir        # .control run/write
rc=0        Plotname: constants             <- 570-byte artefact, exit 0
```

Same deck, same `.save`, same mode. The only difference is that the second
drives the run from a `.control` block, because that is how a generated deck
names its own rawfile.

This matters more than a rc quirk, because `rc` is load-bearing in the
response's own advice to clients: *"`rc` and a vector-count sanity check are
still worth having"*, and *"`rc` — the obvious defence"* in finding 3. For a
tool whose decks look like ours, `rc` is not available. It reports 0 while the
analysis did not run and the rawfile holds the constants plot.

**Ask.** Let an analysis failure inside `.control` reach the exit status — or,
if that would break scripts that deliberately continue past a failed `run`, say
so and we will stop treating rc as a signal at all. Either answer is actionable;
the present state is one where the documented defence works for one deck shape
and silently does not for the other.

### R2. The constants artefact is reachable in every mode, on stock, with no case involved

`.save v(nosuchnode)` — a token that is in no netlist in any casing:

| binary / mode | rc | rawfile |
|---|---|---|
| ver_50 `fold` | 0 | `Plotname: constants`, 12 vars |
| ver_50 `preserve` | 0 | same |
| ver_50 `distinguish` | 0 | same |
| **stock ngspice-46, no flag** | 0 | same |

Mentions of `nosuchnode` on either stream: **zero**, in all four runs.

So the shape `0059` describes is not a `preserve` consequence and never was —
`preserve`'s strict `.save` was one route to it, and `0056` closed that route
without touching the destination. A plain typo in a `.save` card on released
ngspice produces: exit 0, no diagnostic naming anything, and a well-formed
rawfile holding `yes`, `FALSE`, `boltz`.

This is offered as evidence for `0059`, not a new ask — the withdrawal reasoning
is sound and we are not asking for a guard that refuses `let`-built vectors. But
it does reframe the priority: the failing shape is not exotic, it needs no
casemode flag, and the response's two tells (`Plotname: constants`, and a
`Date:` that is the build stamp) are the only two signals in existence for it.
We are implementing both as content checks, plus a vector-count floor.

### R3. A deck with exactly one saved vector gains a phantom `v(all)`

```
.save v(In)                       -> 0 v(In) voltage | 1 v(all) voltage
.save v(In) / .save v(MidNode)    -> 0 v(In) voltage | 1 v(MidNode) voltage
stock ngspice-46, .save v(In)     -> 0 v(in) voltage | 1 v(all) voltage
```

One saved vector in the deck, two in the rawfile. The extra one is named
`v(all)` and is mode-independent and present on stock. The trigger is the total
count of saved vectors in the deck being exactly one — two `.save` cards, or one
card with two tokens, are both clean.

It reaches a consumer as a signal indistinguishable from a net: our signal
browser lists `v(all)` beside the real trace whenever the user plots exactly one
thing. We can filter it, but only by name, which is not a defence we like.

### R4. `0058` latched the announcements; the warning `0057` added still doubles

Same run, counted per stream:

| diagnostic | stdout | stderr |
|---|---|---|
| `unknown casemode` | 0 | **1** |
| `experimental` banner | 0 | **1** |
| `no vector named 'x'; 'X' differs only in case` | 0 | **2** |

`0058`'s latch does what it says. The near-miss warning shipped after it and has
the same duplication finding 7 was filed about — a consumer counting
diagnostics sees two offending tokens where there is one.

### R5. `$curcasemode` is faithful to `.spiceinit` — and therefore to the deck's directory

The good news first, because this is the property that makes `0060` a complete
answer rather than a partial one:

```
cwd = a directory whose .spiceinit says casemode=fold, flag -D casemode=preserve

  no -n:  probe says fold        the real run writes v(in)        <- agree
  -n:     probe says preserve    (and the run preserves)          <- agree
```

The probe tracks the effect, not the request. That is exactly what a client
needs and it is why we deleted our deck-based probe.

The caveat is ours to handle, but worth stating because it is not obvious:
`.spiceinit` is searched in the **deck's** directory, while a `-p` probe has no
deck and searches **cwd**. Run the probe from the wrong directory and it is
confidently wrong:

```
cwd = repro2/ (no .spiceinit), deck in probe/ (.spiceinit says fold)

  probe says preserve            the real run writes v(in)        <- disagree
```

We now chdir to the deck's directory before probing. Two notes for the docs, if
`0060` gets any: the probe must run with the real run's argv *and* its cwd; and
`write` inside `.control` resolves relative to cwd, not to the deck — the
rawfile in the second case above landed in `repro2/`, not beside the deck.

### R6. `0067` corroborated on stock

```
printf 'source deck.cir\nset temp=27\nunset temp\nquit 0\n' | ngspice -p -n
  ver_50            rc=134 (SIGABRT, core dumped)
  stock ngspice-46  rc=134 (SIGABRT, core dumped)
```

Confirming the response's own flag that this is the least-scrutinised item and
pre-existing rather than introduced. We have made "never emit a `set` and an
`unset` of the same simulator variable into a generated `.control` block" a rule
on our side; our current generator does not, and now will not.

---

## 3. Four questions still open

1. **Will `Option: casemode=<mode>` ship (`0061`)?** It is written up, the
   objection to it is resolved, and it is one `fprintf`. It is the difference
   between a rawfile on disk describing itself and a consumer guessing from
   whether any label carries a capital — a guess that is wrong for Xyce, which
   writes `V(EN)` under semantics that are not `preserve`. We are building the
   heuristic because we must read files written before any decision; we would
   drop it for a header line. **If the answer is "not deciding yet", that is
   also useful** — we will ship the heuristic off by default rather than
   designing around a line that may arrive.

2. **Is `distinguish` intended to keep `.save` byte-exact permanently?** The
   response says yes, as the mode's contract, and we have taken it as settled —
   we select `preserve` and warn in our UI that `distinguish` makes stored
   folded cards fatal. Confirming it is a contract and not an interim state
   would let us word that warning as permanent.

3. **Finding 9 — will ngspice warn when two identifiers fold together?** Still
   "needs a decision that has not been made". It is the one signal a schematic
   editor could relay to a user who drew `Out` and `OUT` and got one net. If it
   is not going to happen we will detect the collision in our own netlister,
   which is strictly worse — we can only see the nets we generate, not the ones
   a `.include`d PDK file brings.

4. **R1's rc question**, above: is exit status inside `.control` fixable, or
   should clients stop treating rc as a signal?

Finding 6 (a misspelled `-D` *name* is a silent no-op) has no issue and we are
not pressing it — `$curcasemode` means we no longer need `-D` to be a capability
signal, which was our reason for raising it.

---

## 4. What the client side now does

For the record, so the next round can check we are not compensating for
something already fixed:

| | |
|---|---|
| probe | `echo $curcasemode` through `-p`, real argv, **cwd = deck's directory** |
| absent variable | treated as `fold`, never as a failure |
| requested mode | `preserve`; `distinguish` opt-in per simulator profile, with a warning |
| `.save` spelling | the schematic's own case, always — safe in all three modes both before and after `0056` |
| rawfile sanity | reject `Plotname: constants`; reject a `Date:` equal to the build stamp; reject zero/short vector counts; **not** rc |
| `.control` blocks | no `set`/`unset` pairs of simulator variables |
| `.spiceinit` | not suppressed with `-n`; the probe absorbs its effect instead |

## Method notes

Round 1's three still hold — decks need a title line, rawfiles need `grep -a`,
and stdout/stderr want separate redirections. One to add:

- **`rc` is not a property of the failure, it is a property of the deck shape.**
  Any measurement of a failing run should record which shape it used; R1 exists
  because round 1 measured only the plain one.
