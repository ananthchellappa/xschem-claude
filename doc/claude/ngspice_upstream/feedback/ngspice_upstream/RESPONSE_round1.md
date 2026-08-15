# Response to the casemode findings — what changed, and what did not

For whoever picks up the xschem side. This is the reply to `FINDINGS.md`: which
of the nine findings were fixed, which were not, and what a client program has
to do differently now.

Every line below was **re-measured 2026-08-13** against
`build-ver_50/src/ngspice` at `58496a8dc`, with `/usr/local/bin/ngspice`
(`ngspice-46`) as the featureless baseline. The work is eleven commits,
`720c8743a..58496a8dc`, on branch `ver_50`, unpushed at the time of writing.

Nothing here is copied from `FINDINGS.md`. Where a transcript in that file no
longer reproduces, it is because this work changed the behaviour it recorded —
each such finding carries a note at its head saying so, and its transcripts are
left as measured rather than rewritten.

---

## 1. Use `$curcasemode`. It is the probe the report was asking for.

New read-only variable, `doc/codex/issues/0060`. It answers the mode **in
effect**, computed at the moment of the read:

```
$ echo $curcasemode                       # this build
fold | preserve | distinguish

$ echo $curcasemode                       # ngspice-46
Error: curcasemode: no such variable.     <- stderr; stdout is empty
```

Measured across `-D casemode=fold|preserve|distinguish` and with no flag at
all (→ `fold`).

This replaces the whole probe apparatus: the throwaway-simulation probe, and
the identity probe in `doc/claude/casemode-distinguish-guide.md` §9. That §9
probe works by creating two names differing only in case and asking whether
they stay separate — an *identity* test, which by construction cannot see
`preserve`, because `preserve` folds identity exactly as `fold` does.
`curcasemode` can, and its absence on an old binary is a distinguishable
answer rather than a plausible wrong one.

**Do not read `$casemode`.** It still reports what was *requested*, not what is
in effect — finding 8, and unfixed by design: `casemode` has to stay writable
because `libngspice` has no argv, so the two are now deliberately separate
variables. On a featureless binary `$casemode` still answers `preserve` while
folding everything. That trap is unchanged.

The version string is still not a signal. This build reports `ngspice-46+`
exactly as it did before the work.

## 2. The `.save` blocker is gone (finding 2, `doc/codex/issues/0056`)

`.save v(midnode)` against a net spelled `MidNode`:

| mode | before | now |
| --- | --- | --- |
| `fold` | rc=0 → `midnode` | rc=0 → `midnode` |
| `preserve` | **rc=1, run dead** | **rc=0 → `MidNode`** |
| `distinguish` | rc=1 | rc=1 — correct, that is the mode's contract |

So every stored lower-cased `.save` card a tool wrote to cope with `fold` now
works under `preserve`. That was the finding marked ⭐ as blocking adoption.

Two things worth knowing about the fix. It was never a `preserve`-only defect:
`save v(MIDNODE)` typed at the `ngspice -p` prompt under `casemode=fold` killed
the run too, and stock `ngspice-46` fails identically — the reader's fold
merely hid it on the deck route. And `distinguish` is deliberately untouched,
so a tool that generates folded `.save` cards must not select that mode.

## 3. Four findings were not fixed. Keep the defences you have.

**Finding 3 — the constants-plot artefact is still there, and it is worse than
the report documented.** `doc/codex/issues/0059` is **open**. A discriminator
was built, was found to refuse correct work — a plain nutmeg session doing
`let x = vector(5)` then `write out.raw` got nothing where stock writes a real
file, including through `ngspice -p` — and was **withdrawn**. The write path is
byte-identical to where it was before this work.

Still reproduces, under `-D casemode=distinguish` now that finding 2's fix
means `preserve` no longer reaches it: rc=1, 570-byte file,
`Plotname: constants`, twelve built-in constants.

Two shapes the report did not have, both of which defeat a consumer that tests
the header:

- `set appendwrite` appends the constants plot to an existing rawfile, so the
  file's `Title:` and **first** `Plotname:` are a real run's and the twelve
  constants sit silently behind them.
- `wrdata f.dat all` reaches the same fallback from a different command and
  writes 401 bytes with **no header at all** — nothing to test.

So "check for `Plotname: constants`" is necessary and not sufficient. `rc` and
a vector-count sanity check are still worth having.

**Finding 4 — the token is named only on a case near-miss.**
`doc/codex/issues/0057` shipped, then was narrowed. The report now fires only
under `casemode=distinguish`, and only when the name misses *and* a name
differing from it only in case exists:

```
$ ngspice -b -n -D casemode=distinguish deck.cir     # .save v(midnode), net MidNode
Warning: no vector named 'midnode'; 'MidNode' differs only in case (casemode=distinguish)
```

A plain typo with no case twin — `.save v(nosuchnode)` — is **silent in every
mode**, measured: zero mentions of the token on either stream. The wider report
was built first and withdrawn: it fired on correct decks four separate ways
(multi-analysis decks, `.noise` columns, XSPICE event nodes, and two decks
shipped in `examples/`). Do not expect a diagnostic for a missing name.

**Finding 5 — `.spiceinit` still beats `-D casemode=`.** Deliberate, and the
tree says so at `src/frontend/inpcom.c:1079`: the last writer before the deck
is read wins, and `.spiceinit` is sourced after the `-D` getopt loop. Still
needs `-n`, with the cost that `-n` also discards the user's own `.spiceinit`.

**Finding 9 — two nets differing only in case still fold silently.** `Out` and
`OUT` still become one net under `fold` and `preserve`, with zero warnings.
Needs a decision that has not been made.

## 4. Finding 7 is fixed, and it changes log-scraping

`doc/codex/issues/0058`. The `unknown casemode` warning and the `distinguish`
experimental banner now fire **once per run**. Before, the count tracked input
file reads and varied with the user's init files — 1, 2 or 3, and higher with a
`source`. Both also moved from raw `stderr` to `cp_err`, so a deck can capture
them with `>&`.

## 5. Finding 1 is unbuilt, but the carrier is no longer disqualified

Nothing yet records the case mode in the raw header. What changed is that
`Option:` is now a **safe** carrier for it.

The objection was that an `Option:` line is not inert metadata — it reached
the reading session and could reconfigure how the *next* netlist parsed. That
is fixed (`doc/codex/issues/0061`, shape A): the pair is still filed into the
plot's environment, so a value can be read back out of a header, but the reads
that steer parsing no longer consult it.

```
load hdr_option.raw            # header carries: Option: casemode=preserve
  echo $casemode      -> preserve    <- read-back works
  echo $curcasemode   -> fold        <- the truth, separately labelled
  source mix.cir      -> midnode     <- folded: the file no longer steers
```

So the ask is now implementable as one `fprintf` in `raw_write()`, and an
unmodified `ngspice-46` already parses the line. Nobody has decided to do it.

## 6. A new hazard that will bite a generated `.control` block

```
$ printf 'source deck.cir\nset temp=27\nunset temp\nquit 0\n' | ngspice -p -n
Aborted (core dumped)                                              rc=134
```

Any `set` then `unset` of a simulator variable. Reproduces on stock
`ngspice-46` — pre-existing, not introduced here. `doc/codex/issues/0067`,
**open and unfixed**, and it is the newest thing in this batch, so it has had
the least scrutiny.

Related and also fixed here, in case a tool ever writes headers by hand: a raw
file carrying `Option: curplot=<anything>` used to segfault the reader on a
bare `load`, on stock too. That one is closed (`doc/codex/issues/0065`).

## 7. Re-running the evidence

`./repro/run_all.sh [case-capable-ngspice] [baseline-ngspice]` runs the same
decks against both binaries, so the before and the after sit side by side.
Findings 2, 3 and 4 are re-pinned to `-D casemode=distinguish`, because
`preserve` no longer reaches those failures.

## Summary for a client program

| do | why |
| --- | --- |
| probe with `echo $curcasemode` | only thing that sees `preserve`; fails loudly on old binaries |
| stop reading `$casemode` | reports the request, lies on a featureless build |
| select `preserve`, not `distinguish` | folded `.save` cards work under one and not the other |
| keep the constants-plot defence, and widen it | `Plotname:` is not enough for the append and `wrdata` shapes |
| do not expect a diagnostic for a missing name | only case near-misses are reported, only under `distinguish` |
| pass `-n`, or audit for a stray `.spiceinit` | an init file still beats the flag |
| avoid `set`/`unset` of simulator variables in generated control blocks | aborts, on released ngspice too |
