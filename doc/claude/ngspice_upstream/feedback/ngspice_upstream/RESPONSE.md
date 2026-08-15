# Response to the casemode findings — round 3

For whoever picks up the xschem side. Round 1 of this file replied to
`FINDINGS.md`; round 2 replied to `REPLY.md`; **this round replies to nothing
you sent.** Nothing new has come from your side and none is owed. This is the
ngspice side reporting what moved since round 2 went out, because five of the
six items below change advice we gave you, and two of those five were advice
that was wrong.

**Six items. Four are fixes, two are filings.** Do not read the list as six
things closed:

| | | |
| --- | --- | --- |
| a copy carries the file's own mode, byte-identically | **fixed** | `0070`, `eb0b96c8c`, `7b5884249` |
| a plot *derived* from a loaded one records no mode | **stated**, not a change | — |
| the phantom `v(all)` beside your one real trace | **fixed** | `0064`, `25e891ec3` |
| `ngspice -b -r out.raw deck.cir` records the mode | **fixed** | `0071`, `731c01455` |
| the duplicate column you will still see | **filed, not fixed** | `0073`, `c25c324e2` |
| `.op` with no netlist aborts, rc=134, on stock too | **filed, not fixed** | `0072`, `611076989` |

And one thing that has **not** moved and is stated in §9 rather than buried:
**the upstream `cp_remvar` submission has not been sent.** It is written,
validated and ready; the repo owner is sending it, and there is no date. The
`casemodewrite` default therefore stays off with no scheduled flip. Keep
planning on setting the variable yourselves.

**If you read one section, read §5a.** Two of this round's fixes turn out to
compose with two facts you already had, and the result is a deck shape that
avoids everything still open here at once. It costs you the deck-named rawfile,
which may be a price you cannot pay; the trade is stated in full there.

Every line below was **re-measured 2026-08-15** against
`build-ver_50/src/ngspice` (`ngspice-46+`, build stamp
`Sat Aug 15 18:18:34 UTC 2026`) with `/usr/local/bin/ngspice` (`ngspice-46`) as
the featureless baseline. Nothing is carried over from round 2 on trust; where
a round-2 transcript is reproduced it was re-run first, and where a number
moved it says so. Your own `repro2/run_round2.sh` was run unmodified against
this tree before anything was written — §10 has what it now prints.

Round 2's text is not preserved below. Where a round-2 claim still holds it is
restated in its round-3 form; where it does not, §1 says so by name. The
round-2 text is recoverable from this repository's history (`f829c9191`, with
in-place corrections at `4a042f0f4` and `731c01455`).

---

## 1. Five things round 2 told you that were wrong

Round 2 opened by correcting round 1. This one opens the same way, and the
count is worse: you corrected us twice, and we have since corrected ourselves
three times more. All five below are statements we put in front of you as
measured. Four of them were measured — against a build or a code path that has
since changed under them — and one was never right.

### (a) "The `-r` batch path does not carry it." It does now.

Round 2's §2 caveat read, in full:

> **The `-r` batch path does not carry it.** `ngspice -r out.raw deck.cir` is a
> different writer and writes no `Option:` line. Measured. If your generated
> decks name their rawfile from `.control write`, you have the line; if you
> ever switch to `-r`, you lose it.

True when written, and it framed a four-line omission as a property of the
design. ngspice has two writers for one raw format — `raw_write()` behind
`write`, `fileInit()` behind `-r` — and the line had gone into the first only.
The second one now has the same gated line in the same place
(`doc/codex/issues/0071`, `731c01455`). Measured, your own command shape:

```
$ ngspice -b -n -D casemode=distinguish -D casemodewrite -r out.raw deck.cir
Plotname: Transient Analysis
Option: casemode=distinguish        <- line 5, as it is under `write`
Flags: real
```

All three modes, ASCII and binary alike. `run <file>` from the control
language is the same writer and behaves the same. Details in §3.

### (b) "A copy is re-emitted with spaces around the `=`." It is not.

Round 2's §2 told you to match the `Option:` key rather than the line number,
which is still right, but it justified that with a fact that is now false:

> A value that came out of a file the session had loaded is re-emitted further
> down the header and reads `Option: casemode = preserve` — same key, same
> value, spaces around the `=`

There is **one spelling**, closed up, in both places. Measured — a `preserve`
file written with the gate set, loaded by a *folding* session and written
straight back out:

```
$ diff <(grep casemode orig.raw | cat -A) <(grep casemode copy.raw | cat -A)
                                    <- empty; both are `Option: casemode=preserve$`
$ grep -n casemode orig.raw ;  grep -n casemode copy.raw
orig.raw:5:Option: casemode=preserve
copy.raw:8:Option: casemode=preserve
```

Same spelling, two *places* — line 5 under `Plotname:` in the writing session's
own file, line 8 after `No. Points:` in a copy. Exactly one such line in the
copy, above variables still spelled `v(In)` and `v(MidNode)` under the folding
session.

Keep the trim anyway. A *foreign* `Option:` value whose first character is `,`,
or which begins `<=` or `>=`, is deliberately re-emitted with spaces around the
`=` — those two shapes are the only ones that do not survive being closed up.
No mode name can reach that arm, so your `casemode` line is always closed.

### (c) "A copy of a file that recorded nothing records the copier's mode." Not any more, and that was a defect.

Round 2's §2 said:

> a file that recorded *nothing* (the default, and every older ngspice) leaves
> nothing to keep, so a re-write with `casemodewrite` set records the
> re-writing session — "absence is not fold", one step on

That behaviour was `doc/codex/issues/0070` and is fixed by `eb0b96c8c` (with
`7b5884249` beside it). What made it a defect is that the stamp described the
**copier** and not the names under it: under `fold`, a stamp saying `fold` over
capitals a folding run cannot spell. Measured now:

```
file written with the gate unset       ->  casemode lines: 0
that file, loaded by a folding session
with `set casemodewrite`, written out  ->  casemode lines: 0
```

So **"absence is not `fold`" survives a copy**: unknown copies as unknown. For
you this is strictly better — a copy is now either silent or truthful, never
confidently wrong. If you want provenance to survive at all, write the
original with the variable set.

### (d) "Your filter-by-name is the right defence." It does not reach what is left.

Round 2's §5 said, of the phantom column:

> Your filter-by-name is, unfortunately, the right defence for the moment.

It was the right defence for `v(all)`, and `v(all)` is now gone (§4). It is
**not** a defence for the column that remains, and that is the correction that
matters most to you, because it is the one we would have let you build on.
`doc/codex/issues/0073` is the mechanism, and its measured centre is this:

```
.op   .save v(In)   write f.raw v(In)

  fold          ->  0 v(in)   | 1 v(In)
  preserve      ->  0 v(In)   | 1 v(In)      <- one name, two columns
  distinguish   ->  0 v(In)   | 1 v(In)      <- one name, two columns
  stock-46      ->  0 v(in)   | 1 v(in)      <- one name, two columns
```

Under `preserve`, under `distinguish` and on stock, the duplicate carries a
**byte-identical name**. There is nothing to filter on. `fold` escapes that row
only because the deck typed `v(In)` while `fold` had stored `in`; type the
stored spelling and `fold` gives `v(in)` `v(in)` too. §5 has the whole of it.

### (e) "Expect n, or n+1 when n is 1." That rule was never right.

Round 2's §5 and its summary table both gave you a vector-count floor:

> **Your vector-count floor has to account for it.** A deck that saves exactly
> one signal writes two variables. Expect n, or n+1 when n is 1.

Wrong in both directions, measured. It is wrong low — two explicitly named
vectors on a two-save `.op` plot write **three** variables, and a `.dc` write
that names the scale writes three for two. And it is wrong high — the shape it
was written about is fixed, so a one-save deck with a bare `write` now writes
exactly **one**. The corrected rule is in §5 and in the summary table, and it
is not a count rule any more, because a count rule is not what this defect
supports.

### And one correction that is ours alone

`doc/codex/issues/0069`'s Resolution — the exit-status issue §7 rests on —
printed a guard deck with no netlist lines in it and named three deck files
that exist nowhere in this repository. The measurements were right and the
evidence for them was not reproducible. Corrected in place (`61f519208`): every
deck is now printed complete and was extracted back out of the issue and run to
prove that the printed version is the measured version. **The decision it
carries is unchanged** — no change to exit status, use `$sim_status`. §7 below
is that decision, restated with a deck you can run.

One number in that family moved and it is worth your having: round 2 told you a
control-only deck leaves "599 bytes of constants". 599 was measured against a
build that wrote the header line unconditionally. As shipped the line is opt-in,
so today the same file is **570** bytes by default, 592 with `casemodewrite`
set under `fold`, and 599 with it set under `distinguish` — the deltas being 22
and 29 bytes of header line. Stock `ngspice-46` writes **569**. If you
size-check the artefact, size-check it against the setting you run with.

---

## 2. What the header line does now — question 1, still yes, still opt-in

Committed at `9e341a8b7`, with `eb0b96c8c`, `7b5884249` and the `-r` half
`731c01455` on top of it. **You still have to ask for it: `set casemodewrite`,
anywhere before the file is written.**

```
.control
  op
  set casemodewrite          <- the header records the mode
  set filetype=ascii
  write $outfile
.endc
```

With it set, the writer puts the line immediately after `Plotname:`, valued
from the mode **in force** (the one `curcasemode` reports), so a `set casemode=`
typed in a `.control` block after the deck was read cannot make it lie:

```
Title: * divider, nets In / MidNode
Date: Sat Aug 15 12:18:26  2026
Command: ngspice-46+, Build Sat Aug 15 18:18:34 UTC 2026
Plotname: Operating Point
Option: casemode=preserve
Flags: real
No. Variables: 2
```

With it unset, the header is byte for byte the header every ngspice has ever
written. Measured this round against the released binary rather than against
ourselves — same deck, same default mode, `Date:` and `Command:` lines removed
because they carry a clock and a build stamp, everything else compared byte for
byte including the data section:

```
gate unset, -r, binary:  build-ver_50  vs  /usr/local/bin/ngspice (ngspice-46)
    IDENTICAL, 1602 bytes
gate set, same build, same deck, only `-D casemodewrite` added:
    +22 bytes, which is exactly len("Option: casemode=fold\n")
```

An unmodified `ngspice-46` still parses the file, and a file still cannot steer
the session that reads it:

```
$ printf 'load h.raw\ndisplay\necho READBACK=$casemode\nquit 0\n' | ngspice-46 -p -n
v(MidNode) : voltage, real, 59 long
READBACK=preserve            <- the file's record, on the binary you ship against
```

**The rules, restated with what changed marked.**

- **Both writers carry it** — new this round; see §3.
- **Absence is not `fold`.** Any older ngspice, and any file this build wrote
  with `casemodewrite` unset — the default, and so every file until somebody
  asks. Treat a missing line as *unknown* and fall back to the probe.
- **Match the `Option:` key, not the line number.** One spelling, two places —
  §1(b). Scan every `Option:` line, split on the first `=`, trim both halves.
  A line-5 check misses the second place.
- **A copy keeps the mode its own file recorded, and a copy of a file that
  recorded nothing records nothing** — §1(c), corrected this round.
- **Provenance survives a copy, not a transform.** A plot *derived* from a
  loaded one — `linearize`, `cutout`, `fft`, `psd`, `spec` — records no mode at
  all, even with `casemodewrite` set and even when the file it came from
  recorded one. Re-measured, one folding session on a `preserve` file carrying
  the line:

  | written plot | `casemode` lines |
  | --- | --- |
  | the loaded plot itself, re-written | **1** — `Option: casemode=preserve` |
  | `linearize` of it | 0 |
  | `cutout` | 0 |
  | `fft v(MidNode)` | 0 |
  | `psd 1 v(MidNode)` | 0 |
  | `spec 500 20000 500 v(MidNode)` | 0 |

  The derived plot inherits the came-from-a-file mark but not the file's
  `Option:` pair, so the writer has nothing true to say and says nothing. The
  contrast, same session shape on a plot the session **simulated**: `linearize`
  → `Option: casemode=preserve`, `fft` → `Option: casemode=preserve`, because
  there the mode in force is the truth. **If you transform before writing,
  carry the mode across yourself.**
- **`Option: casemodewrite` in a header does not turn the writer on**, for
  either writer. The variable is this session's request about what it writes,
  and a loaded file does not get to answer it (`doc/codex/issues/0061`).

### Why it is still opt-in, and why there is no date on that changing

Unchanged from round 2 in substance, and the schedule is the part that moved —
backwards, in the sense that there is no schedule.

The line is safe to *read* on every ngspice that exists. The hazard is one step
on and it is in the **released** binary, not in ours: loading a file that
carries the line puts a `casemode` key into that session's loaded-plot
environment, and on `ngspice-46` as released, `unset casemode` in that session
frees a node it leaves linked. The `unset` returns cleanly, so the crash lands
on the next command, whatever it is. Re-measured this round, on a file written
through the **new** `-r` path:

```
$ printf 'load rl.raw\nunset casemode\n<CMD>\nquit 0\n' | ngspice-46 -p -n
    <CMD> = set        rc=139        (ver_50: rc=0)
    <CMD> = display    rc=139        (ver_50: rc=0)
```

That is `doc/codex/issues/0067`, fixed here and in nothing released. **For you
it remains a non-issue and you should turn the variable on** — you control both
ends, your reader parses the key rather than unsetting it, and nothing in the
sequence above happens by accident. It matters when a file leaves your hands:
say so if you publish such files, or ship them without the line until the fix
is in a release.

**What is new is that "until the fix is in a release" now has no expected
date.** Round 2 implied a flip was queued behind an upstream fix. The fix for
0067 is prepared as a two-patch submission to `ngspice-devel`, validated
against upstream master, and **it has not been sent** — see §9. So:
`casemodewrite` stays off by default, indefinitely, and your generator should
keep setting it explicitly. That is the same instruction you already have; what
has changed is that you should stop expecting it to become unnecessary.

---

## 3. `ngspice -b -r out.raw deck.cir` records the mode — the round-2 caveat, gone

`doc/codex/issues/0071`, `731c01455`. This is §1(a)'s correction with its
measurements.

Three modes, your own command shape (`-b -n -D casemode=M -D casemodewrite -r
out.raw`):

```
fold         line4=<Plotname: Transient Analysis> line5=<Option: casemode=fold>        line6=<Flags: real>
preserve     line4=<Plotname: Transient Analysis> line5=<Option: casemode=preserve>    line6=<Flags: real>
distinguish  line4=<Plotname: Transient Analysis> line5=<Option: casemode=distinguish> line6=<Flags: real>
```

Gate unset, the same three: line 5 is `Flags: real` and there are zero
`Option:` lines. So **one branch in your reader works on both writers** — same
key, same value, same place relative to `Plotname:`.

Three things to know about it:

- **`set casemodewrite` in the `.control` block works as well as `-D`.** In a
  `-b -r` run the control block finishes before the analysis starts, so a
  variable it sets is live when the file is written.
- **`run <file>` from the control language is this same writer** and behaves
  the same. Covering it was intended, not incidental.
- **The flag spelling matters, and you will reach for the command-line form.**
  Measured: bare `-D casemodewrite` sets the boolean and opens the gate, while
  `-D casemodewrite=TRUE` sets a *string* variable that the boolean read does
  not see, and opens the gate for neither writer. That is `cp_getvar()`'s
  general rule for boolean options, not anything about this key.

```
-D casemodewrite=TRUE  -> Option lines: 0
-D casemodewrite       -> Option lines: 1
```

**This is in `ver_50` and not in any release.** Against a released ngspice the
round-2 caveat still describes reality, so if you support more than one ngspice
you still need the "absent means unknown" branch.

CIDER's seven state dumps (`.op` device dumps, off by default and off here)
write a third header grammar and emit no `Option:` line. They are unchanged by
decision, and are not a file shape you will meet.

---

## 4. The phantom `v(all)` is gone — your filter can go with it

`doc/codex/issues/0064`, fixed at `25e891ec3`. This is R3 from your round 2,
and it is the one item in this round that removes work from your side rather
than adding it.

The cause was as round 2 described: `ft_evaluate()` renamed its result to the
parse node's own text whenever the result was a **single** vector. Right for an
expression — `print v(a)+v(b)` should be labelled `v(a)+v(b)` — and wrong for a
wildcard, whose text is not a name for what it matched. The fix withholds the
rename when that text is one of the wildcard tokens, which is exactly the set
`findvec()` already intercepts before any name lookup: `all`, `allv`, `alli`,
`ally`, `alle`, matched case-insensitively.

Re-measured, with stock `ngspice-46` standing in for "before":

| deck | ngspice-46 (before) | this build (after) |
| --- | --- | --- |
| `.op`, `.save v(In)`, bare `write` | 2: `v(in)` `v(all)` | **1: `v(in)`** |
| `.op`, `.save v(In)`, `write f all` | 2: `v(in)` `v(all)` | **1: `v(in)`** |
| `.op`, `.save v(In)`, `write f allv` | 2: `v(in)` `v(allv)` | **1: `v(in)`** |
| `.tran`, `.save v(In)`, `write f allv` | 2: `time` `v(allv)` | **2: `time` `v(in)`** |
| `.tran`, `.save v(In)`, `write f ally` | 2: `time` `v(ally)` | **2: `time` `v(in)`** |

Note the two `.tran` rows, which round 2 did not tell you about: on an analysis
with a real scale the phantom never inflated the **count**, so a count check
passed while a corrupted **name** still reached your browser. Those rows are
fixed too.

**Your own harness says so.** `repro2/run_round2.sh`, run unmodified against
this tree, now prints for R3:

```
    .save v(In)                    -> 0 v(In) voltage|
    stock, .save v(In)             -> 0 v(in) voltage| 1 v(all) voltage|
```

One column where your reply measured two, with stock in the same output as the
control. **Drop the name filter for `v(all)`/`v(allv)`/`v(ally)`.** Nothing
else in your reply's R3 section still reproduces here.

What the fix deliberately did **not** change, because you have asked for it in
earlier rounds and it is the same lever: a `fold` run still hands back the
deck's own spelling when the deck names the vector. `write f.raw v(In)` under
`fold` still labels the column `v(In)`, not `v(in)`.

---

## 5. The duplicate column that remains — `doc/codex/issues/0073`, filed, not fixed

This is §1(d)'s correction with its evidence, and it is the item to read most
carefully, because it is open and because the defence we gave you does not
reach it.

**The mechanism is not the rename.** `com_write()` identifies the plot's scale
by **name**; if that name is not among the vectors being written, it prepends a
copy. That is correct and necessary on `.tran`/`.dc`/`.ac`, where the scale is
a real axis and a file without it is unplottable. On an `.op` plot the "scale"
is not an axis at all — it is whichever saved node voltage happened to be
created first — and the prepend adds a column nobody asked for.

**When it fires: whenever the name you type is not the name the plot stores.**
Measured, one netlist, `.op`, `.save v(In)`:

```
write f.raw in       -> 1 variable    v(in)          <- typed text == stored name
write f.raw v(in)    -> 2 variables   v(in) v(in)    <- the v() wrapper is enough
write f.raw v(In)    -> 2 variables   v(in) v(In)
```

The `v()` wrapper your generator writes is, by itself, sufficient to trigger
it. And it is not confined to `.op`:

| deck | asked for | `No. Variables` | columns |
| --- | --- | --- | --- |
| `.tran`, `write f time v(In)` | 2 | 2 | `time` `v(In)` |
| `.dc`, `write f v(v-sweep) v(In)` | 2 | **3** | `v(v-sweep)` `v(v-sweep)` `v(In)` |
| `.op` 2-save, `write f v(In) v(MidNode)` | 2 | **3** | `v(in)` `v(In)` `v(MidNode)` |

The `.dc` row is the one a tool hits without doing anything unusual: a `.dc`
plot's scale is *stored* `v-sweep` and *reported* `v(v-sweep)`, because the
writer adds the `v()` wrapper on output while `com_write()` compares against
the bare stored name. **A consumer that round-trips a file's own variable names
back into a `write` line hits this every time**, in every mode including stock.

**Why filter-by-name does not save you** — §1(d)'s table, in full, with the
`fold` row completed:

```
.op   .save v(In)   write f.raw v(In)          .op  .save v(In)  write f.raw v(in)

  fold          0 v(in)   | 1 v(In)              fold   0 v(in) | 1 v(in)
  preserve      0 v(In)   | 1 v(In)
  distinguish   0 v(In)   | 1 v(In)
  stock-46      0 v(in)   | 1 v(in)
```

Both columns carry the same data. Under `preserve`, `distinguish` and stock
they carry the same name, and under `fold` they do too as soon as the deck
types the stored spelling. There is no name test that separates them.

**What to do about it now.** Three things, in the order they are worth doing:

1. **Use `-r` for the artefact your reader consumes, if you can.**
   `ngspice -b -r out.raw deck.cir` never reaches `com_write()` at all — it
   writes the header from the analysis's own vector set — and since `731c01455`
   it also carries the case mode. Measured: `.op` one-save `-r` writes
   `No. Variables: 1`. Its one inherent limit is that `-r` takes no vector
   list, so it answers *"write what I saved"* and not *"write these three of
   the twelve I saved"*. This turns out to be worth more than a workaround for
   this one issue — see §5a.
2. **Do not name the scale on a `write` line**, and in particular do not
   round-trip a `.dc` file's `v(v-sweep)` back into one. `write f.raw time
   v(In)` is clean; `write f.raw v(v-sweep) v(In)` is not.
3. **Deduplicate on the data, not on the name.** Two columns with the same name
   and the same values are the shape; on read-back the phantom becomes the
   loaded plot's default scale, so a consumer that trusts variable 0 to be the
   abscissa gets a node voltage on an `.op` plot.

**Why it is not fixed.** Removing the prepend is not a one-line change: the raw
writer's own loop over the vector list terminates by *finding* the scale in it
and has no NULL test, so removing the prepend walks that loop off the end on
every partial write of every analysis. The invariant also needs restating
before it can be scoped — `No. Variables == len(argument list)` is not
achievable, because a `.tran` file with no `time` column is not a usable file.
0073 is written against the defensible form instead: **the scale is written
when it is a real axis, under the plot's own name for it, and never twice.**
The genuinely open question in it is a behaviour choice, not a bug: whether an
`.op` plot's pseudo-scale should stop being prepended to a partial write at
all. That is the repo owner's to settle and it has not been settled.

---

## 5a. The deck shape that avoids all of it: `-r`, with no `.control` block

This did not exist as a recommendation before this round. One of its four
properties is new code — `-r` did not carry the case mode until `731c01455`,
and without that the shape cost you the header line. The other three were
always true of `-r` and are only now *established*, because the two issues they
answer (`0073`, `0072`) were filed this round. It is the one piece of advice
here that composes, so it is stated on its own rather than buried in §5.

**`ngspice -b -n -D casemodewrite -r out.raw deck.cir`, on a deck whose
analysis is a dot card and which carries no `.control` block at all**, is
measured to have all four of these at once:

| property | measured |
| --- | --- |
| no duplicate column (§5) | `-r` never reaches `com_write()`. `.op` one-save → `No. Variables: 1` |
| immune to the `.op` abort (§6) | `-r` on the six-byte empty deck is **rc=0**, writing `No. Variables: 0`, where `--batch` is rc=134 |
| carries the case mode (§3) | `Option: casemode=<mode>` on header line 5, all three modes |
| **rc is a correct signal in this one shape** | see below |

That last row is the surprise, and it is the exception to §7 rather than a
contradiction of it. Measured, `.save` of a token that is in no netlist in any
casing — so not a case failure at all — with **no** `casemode` flag:

```
                                          rc   rawfile
ngspice -b -n deck.cir -r out.raw          1   ABSENT      <- both binaries
ngspice -b -n deck.cir                     0   (constants)
```

Both rows on this build **and** on stock `ngspice-46`, identically. So for a
deck with a dot-card analysis and no control block, `-r` gives you rc=1 *and*
no artefact on a failed `.save`, with no guard, on every ngspice you support.

**What it costs you**, stated so this is a trade and not a free lunch:

- **The deck cannot name its own rawfile.** The name comes from the command
  line, not from `write $outfile` inside a block. That is the reason your
  generator uses `.control write` in the first place, and it may simply be a
  reason you cannot take this shape.
- **`-r` takes no vector list.** The file holds what the deck `.save`d.
- **You lose the `$sim_status` guard's precision**, because there is no block
  to put it in. You get rc instead, which for *this* shape is right — but §7's
  rule still holds everywhere else, and if you keep a `.control run` alongside
  the dot card you are back to two simulations (measured: analyses=2, and §8).

If you can take it, take it. If you cannot, §5's points 2 and 3 and §7's guard
are the fallback, and they are what the summary table assumes.

---

## 6. `.op` with no netlist aborts — `doc/codex/issues/0072`, filed, not fixed

New this round, found while re-running 0069's own listing, and it is nothing to
do with case modes. It is in released ngspice, byte for byte.

Six bytes are the whole reproducer:

```
$ printf '*\n.op\n' > tiny.cir
$ ngspice --batch -n tiny.cir ; echo rc=$?
ngspice: ../../../src/frontend/dotcards.c:225: ft_cktcoms: Assertion `plot_cur->pl_dvecs != NULL' failed.
rc=134
```

`rc=134` is SIGABRT with a core dump, on **both** binaries — `ngspice-46` as
released and this build — and in all three case modes and with no flag. The
same empty deck with `.tran`, `.dc` or `.ac` instead of `.op` gets the right
answer: `Error: incomplete or empty netlist`, `rc=1`. It is `.op` alone.

**Why this is yours and not a curiosity.** Three measured properties:

- **A generated deck can produce that input.** The trigger is not literally
  "no netlist" but "no non-ground node": `r1 0 0 1k` plus `.op` aborts too. A
  netlister that emits an `.op` probe deck for a schematic with nothing placed,
  or with everything tied to ground, produces it.
- **You do not need `-b`.** Batch mode is entered whenever there is no tty and
  no `-i`, so `ngspice deck.cir` from a `Makefile`, a CI job or a
  `subprocess.run()` is enough. The same deck typed at an interactive prompt
  loads and prompts.
- **Under a pipe the caller sees nothing.** `abort()` does not flush stdio, so
  with stdout redirected the run writes **0 bytes** to stdout and 106 bytes to
  stderr — the assertion line and nothing else. With `-o log` the assertion
  text lands in the log and stderr is empty, so a caller reading only stderr
  sees an empty stream and a 134.

Which routes reach it, and the two that do not — every row measured on both
binaries. The third row is your workaround:

```
ngspice --batch -n tiny.cir             rc=134
ngspice -n tiny.cir < /dev/null         rc=134     <- no -b needed
ngspice -b -n -r out.raw tiny.cir       rc=0       <- writes "No. Variables: 0"
printf 'op\n' | ngspice -p -n           rc=0       <- "Error: there aren't any circuits loaded."
```

The last row is worth noting on its own: reached from the control language,
with no `.op` **dot card** involved, ngspice refuses properly. It is the dot
card in batch mode that aborts, which is why a `.control`-driven deck of the
shape you generate does not hit this and a dot-card deck does.

**Client-side rule while it is open:** treat `rc=134` from a batch run as
"ngspice aborted", not as "the simulation failed", and do not feed a deck with
an `.op` dot card to batch ngspice without checking that the netlist has at
least one non-ground node. The `-r` route is immune, which is a second reason
to prefer it for generated decks.

Filed, not fixed, and it is not scheduled. The fix is small but its shape is an
open decision — whether to guard where the empty plot is created or where the
assertion fires — and so is where it should land, since it reproduces on the
release and has nothing to do with case modes. **Do not plan around this being
fixed.** The client-side rule above is what you have.

---

## 7. `$sim_status`, not `rc` — question 4, unchanged, now with a deck you can run

The decision round 2 gave you stands: **exit status inside `.control` is not
going to change, deliberately.** `run` inside `.control` is the scripting
interface, and decks retry, sweep and continue past a failed run; turning that
into a process failure would be a behaviour change to every such script with no
opt-out. You offered us that answer as acceptable and it is the one we are
giving.

What has changed is the evidence, not the decision. `doc/codex/issues/0069`
printed a guard deck that was missing its netlist and named files that do not
exist. Here is the complete deck, extracted from the corrected issue and run:

```spice
* guard -- .save v(midnode) against a net spelled MidNode
Vs In 0 DC 3
Rl In MidNode 1k
Rg MidNode 0 3k
.save v(midnode)
.op
.control
run
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
write guard.raw
.endc
.end
```

| mode | rc | guard fired | rawfile |
| --- | --- | --- | --- |
| `fold` | 0 | no | written, `Plotname: Operating Point` |
| `preserve` | 0 | no | written, `Plotname: Operating Point` |
| `distinguish` | **1** | **yes** | **absent** |

The same deck with the four guard lines deleted, under `distinguish`: `rc=0`
and a 570-byte `Plotname: constants` file. The guard turns that into rc=1 and
no artefact, because it quits ahead of the `write`.

**It works on stock.** Same guard, `.save v(nosuchnode)`, no `casemode` flag
anywhere:

```
stock ngspice-46   rc=1  RUN-FAILED  raw ABSENT   (unguarded: rc=0, 569-byte constants)
ver_50, no flag    rc=1  RUN-FAILED  raw ABSENT   (unguarded: rc=0, 570-byte constants)
```

So you can emit this into every deck you generate, against every ngspice you
support, today.

Three properties to build against, each re-measured:

1. **Per analysis, last writer wins.** A deck that fails one analysis and then
   succeeds at another reads 0 at the end (`AFTER-BAD=1`, `AFTER-GOOD=0`).
   Read it after *each* run, not once at the end of the block.
2. **It does not exist before the first analysis.** `$?sim_status` is 0 and
   `$sim_status` is empty, with `Error: sim_status: no such variable.` on
   stderr. Test `$?sim_status` first if your block can reach the guard without
   a run.
3. **A `run` with no analysis to do reads 0.** `sim_status == 0` means "the
   last analysis did not report a failure", not "an analysis produced data".
   For the second question you still have to ask the rawfile.

And the round-2 point that has not moved: **rc=1 does not mean nothing was
written.** A deck whose analysis lives only in a `.control` block exits 1 under
`distinguish` having already left a 570-byte constants file on disk. Whatever
`rc` says, the content checks are still owed — `Plotname: constants` and a
`Date:` equal to the build stamp remain the only two signals a rawfile carries
for that failure, and they remain necessary and not sufficient.

**One deck shape is an exception and §5a is it:** a dot-card analysis, no
`.control` block, `-r` for the output. There `rc` is a correct signal, on stock
too. The rule that survives is round 2's — *rc is a property of the deck shape,
not of the failure* — so if you read `rc` at all, read it only for a shape you
have pinned, and prefer the guard everywhere you have a block to put it in.

---

## 8. Questions 2 and 3, and R2/R4/R5/R6 — unchanged, and now durable

Nothing in this section moved. It is here because round 2 is being replaced,
not appended to, and because the two answers have since been written somewhere
that outlives this correspondence.

**Question 2 — `distinguish` keeps `.save` byte-exact, permanently.** It is a
contract, not an interim state; you can word your UI warning as permanent. The
place it is written down is `doc/claude/decisions/0001-distinguish.md`
decision 5, which is a list of guarantees `preserve` makes that `distinguish`
deliberately **withdraws**, `save` among them — not a list of things
`distinguish` has not got round to. Re-measured: `.save v(midnode)` against net
`MidNode` gives `v(midnode)` under `fold`, `v(MidNode)` under `preserve`, and
rc=1 under `distinguish`. Your plan — select `preserve`, make `distinguish`
opt-in per simulator profile with a permanent warning — is the plan we would
have recommended.

**Question 3 — a case collision is reported, in all three modes.** Shipped at
`4e738fc3e`. Re-measured on `V1 in 0 dc 1.5 / R1 in Out 1k / R2 out 0 1k`:

```
-D casemode=fold          Warning: node names 'Out' and 'out' differ only in case and name one node (casemode=fold)
-D casemode=preserve      ... name one node (casemode=preserve)
-D casemode=distinguish   ... name two nodes (casemode=distinguish)
no flag at all            ... name one node (casemode=fold)
stock ngspice-46          (nothing)
```

It fires in the two modes you will actually ship under, it names the outcome
rather than the mistake, it fires once per colliding pair per parse, and it
sees `.include`d PDK cards because the detection is at the parser's node symbol
table. What it does **not** cover — `.model`, `.subckt`, `.global` and `.param`
names, and under `fold` a collision confined to a subcircuit body — is
enumerated in `doc/claude/decisions/0018-node-name-collision-report.md`. Two
practical notes that round 2 did not carry, both now in the guide: the line is
emitted at **parse** time, before any `.control` block runs, so a deck cannot
capture it with `>&` from inside a block; and a pair inside a `.subckt` body
reports **once per instantiation**, so deduplicate on the quoted pair.

**R4 — the near-miss warning is per simulation, and your deck is two
simulations.** Unchanged and re-measured under `-D casemode=distinguish`:

| deck shape | `Doing analysis` | near-miss lines | rc |
| --- | --- | --- | --- |
| `.op` card, no `.control` | 1 | 1 | 0 |
| `.op` card **and** `.control run` — your `ctl_fail.cir` | **2** | **2** | 0 |
| no analysis card; `op` inside `.control` | 1 | 1 | **1** |

The line count equals the simulation count. **How to avoid it, in one edit: do
not carry both an analysis dot card and a `.control run`.** Row 3 is the one to
pick, because the same edit gets you rc=1 back as well. We are not making the
memory outlive the simulation — it would also silence the second run of a deck
deliberately re-run after an `alter`, which is a correct deck asking the same
question twice and entitled to the same answer twice.

**R5 — the probe must run from the deck's directory.** Yours, adopted, and now
in the guide: probe with the real run's argv *and* its cwd, because
`.spiceinit` is searched beside the deck while a `-p` probe searches cwd. Your
`repro2` harness still demonstrates it against this tree, and the disagreeing
run still writes `Option: casemode=fold` when the gate is set — the header
catching the wrong-cwd probe is the best argument this correspondence has
produced for reading both.

**R2 — the constants artefact** is recorded as corroboration in
`doc/codex/issues/0059`. Re-measured this round: `.save v(nosuchnode)` gives
rc=0 and a `Plotname: constants` file in all three modes and on stock, with
zero mentions of the offending token on either stream. §7's guard is the
answer, and it is why the guard rather than `rc` is the first row of the
summary table.

**R6 — `0067`** is recorded in that issue as independent confirmation, and §2
above re-measures it. Your client-side rule — never emit a `set` and an `unset`
of the same simulator variable into a generated `.control` block — is a good
mitigation and the issue records it.

**Finding 6** (a misspelled `-D` *name* is a silent no-op) stays unfiled, as
you asked.

---

## 9. What has not moved, stated plainly

Three things, and none of them should be read as "soon".

**The upstream `cp_remvar` submission has not been sent.** The two patches that
fix `doc/codex/issues/0067` — the crash behind §2's "why it is opt-in" — are
written, applied cleanly to upstream master, built, and validated: six
reproducers go 134/134/134/134/134/139 on the unpatched tree and 0/0/0/0/0/0 on
the patched one, and upstream's own `make check` passes 58/58 on the patched
build. The mail is drafted. **It has not gone out.** Sending it is the repo
owner's action and there is no date on it, and we are not going to give you one.

What follows for you:

- **`casemodewrite` stays off by default with no scheduled flip.** Keep setting
  it in your generated decks. Do not write code that expects to stop.
- **Keep the "absent means unknown" branch** in your reader indefinitely, not
  as a transitional measure. Every released ngspice writes no line, and will go
  on doing so until an upstream release carries the header work — which has not
  been submitted at all, let alone accepted.
- **The published-file caution in §2 stands unchanged.** A raw you write with
  the line, handed to somebody on a stock `ngspice-46` whose script unsets
  `casemode` after loading it, still kills their session.

**`doc/codex/issues/0073` is filed and not fixed** — §5. The duplicate column
is what you will see, and there is no name-based defence for it.

**`doc/codex/issues/0072` is filed and not fixed** — §6. It is upstream's, it
is in the release, and a generated deck can reach it.

---

## 10. Re-running the evidence

`./repro/run_all.sh [case-capable-ngspice] [baseline-ngspice]` is round 1's and
still runs.

**Your `repro2/run_round2.sh` was run unmodified against this tree**, from a
scratch copy so nothing in the repository changed, before any of the above was
written. What it prints now:

| your finding | this tree |
| --- | --- |
| R1 — same failure exits 0 inside `.control`, 1 outside | reproduces, unchanged. §7 is the answer and it is a decision, not a fix |
| R2 — constants artefact in every mode, on stock | reproduces, unchanged, all four rows |
| R3 — phantom `v(all)` | **no longer reproduces on this build.** One column, `v(In)`. The stock row in the same output still shows two |
| R4 — near-miss doubles | reproduces, unchanged: stderr=2. §8 explains it as two simulations |
| R5 — probe faithful to `.spiceinit`, and to cwd | reproduces, unchanged, including the wrong-cwd row |
| R6 — `0067` on stock | reproduces on stock (rc=134); this build is rc=0 |

**What we did not re-measure, so you know where the edges are.** Your own
client side — `read_dataset`, the signal browser, your probe wrapper — is
yours; nothing here was run against it. Round 1's `repro/run_all.sh` was not
re-run this round. The upstream patch validation quoted in §9 was measured when
the submission was prepared and was not re-run today; if upstream master has
moved since, the apply check is the part that would need repeating, and that is
the owner's to do before sending. The subcircuit-body and `.include` silence
tables in §8 are quoted from
`doc/claude/decisions/0018-node-name-collision-report.md` and the guide, where
they were measured, rather than re-run here.

**Where the durable answers now live.** This file is round-scoped correspondence
and will be archived. `doc/claude/casemode-distinguish-guide.md` §9 now carries
questions 2, 3 and 4 in full — the `$sim_status` guard with all three
properties, the collision warning with its silence table and its
per-instantiation count, the `.save` contract with its decision-5 quotation,
and the `casemodewrite` header section with both writers. If you want one
document to build against after this correspondence ends, that is the one.

---

## Summary for a client program

Rows that changed this round are marked **NEW** or **CHANGED**; a row with
neither is unchanged from round 2 and was re-measured anyway.

| do | why |
| --- | --- |
| **guard with `$sim_status`, not `rc`** | rc reports the last epilogue arm, not the analysis; the guard fires before the artefact exists, and works on stock. One exception, §5a |
| read `$sim_status` after *each* run | per analysis, last writer wins; absent before the first analysis |
| **probe with the real run's argv *and* its cwd** | `.spiceinit` is searched beside the deck, a `-p` probe searches cwd |
| probe with `echo $curcasemode` | the only thing that sees `preserve`; fails loudly on old binaries |
| read `Option: casemode=` from the raw header | written by both writers, `write` and `-r` alike (`0071`, in `ver_50` only); also cross-checks the probe. Absent ≠ `fold` |
| match it as an `Option:` **key**, anywhere in the header | **CHANGED** — one spelling, closed up, in two places: under `Plotname:` in the session's own file, after `No. Points:` in a copy. Keep the trim for foreign keys |
| treat a copy with no `casemode` line as unknown, not as `fold` | **CHANGED** — a copy of a file that recorded nothing now records nothing (`0070`); so does any `linearize`/`cutout`/`fft`/`psd`/`spec` of loaded data |
| carry the mode yourself if you transform before writing | a derived plot records no mode even when its source file did |
| `set casemodewrite` in the deck, never as an `Option:` in a file | the gate is the session's request; a loaded header cannot open it, for either writer |
| use bare `-D casemodewrite`, not `-D casemodewrite=TRUE` | **NEW** — the `=TRUE` form sets a string variable the boolean read cannot see, and opens the gate for neither writer |
| keep the "absent means unknown" branch permanently | **CHANGED** — the default has no scheduled flip; the upstream fix it waits on has not been sent |
| keep `Plotname: constants` and build-stamp-`Date:` checks | still the only two signals for the artefact, still not sufficient alone |
| ~~expect n+1 variables when the deck saves exactly one~~ | **CHANGED** — wrong rule, withdrawn. A bare `write` of a one-save deck now writes exactly n (`0064` fixed) |
| do not name the plot's scale on a `write` line | **NEW** — `0073`, open: naming it in a spelling that is not the stored one prepends a duplicate. `write f time v(In)` is clean, `write f v(v-sweep) v(In)` writes three columns for two |
| deduplicate raw columns on data, not on name | **NEW** — `0073`: under `preserve`, `distinguish` and stock the duplicate carries a byte-identical name. Filter-by-name does not reach it |
| **prefer `-b -r out.raw` on a deck with no `.control` block** | **NEW** — §5a: the one shape that gets no duplicate column, immunity to `0072`, the case-mode line, *and* a correct `rc` (rc=1, no artefact, on stock too), all measured. Costs you the deck-named rawfile and the vector list |
| stop filtering `v(all)`/`v(allv)`/`v(ally)` from the signal list | **NEW** — `0064` fixed at `25e891ec3`; the wildcard no longer renames its single match |
| never batch-run an `.op` dot card on a deck with no non-ground node | **NEW** — `0072`, open: SIGABRT, rc=134, empty stdout, on released ngspice too. `-r` is immune |
| do not carry an analysis dot card *and* a `.control run` | two simulations: two warnings, and rc reports the second |
| select `preserve`; warn permanently if you offer `distinguish` | the folded-`.save` contract is permanent by decision, not interim |
| relay the collision warning to the user | fires in all three modes, once per pair per parse — but once per *instantiation* for a subcircuit body, so deduplicate on the quoted pair |
| stop reading `$casemode` | reports the request; lies on a featureless build |
| avoid `set`/`unset` of simulator variables in generated control blocks | aborts, on released ngspice too |
