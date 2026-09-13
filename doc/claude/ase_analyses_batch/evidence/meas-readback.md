# How a `meas` result comes back, measured on both binaries

Taken by the driver on **2026-09-13**, in a scratch directory outside the repository,
against **both** binaries this batch is verified on:

* `/usr/bin/ngspice` — **ngspice-45.2** (apt)
* `/home/analog/dev/ngspice/build-ver_50/src/ngspice` — **ngspice-46+** (the fork)

The deck was an RC driven by a pulse source, with `set filetype=ascii` and a `tran`
inside a `.control` block. Every result below was identical on the two binaries unless
the entry says otherwise.

## 1. `meas` creates a VECTOR, not a shell variable

`display` after a successful `meas tran vmax MAX v(out)` lists it in the current plot:

```
    vmax                : notype, real, 1 long
```

`print vmax` answers. **`$vmax` expands to the empty string** and stderr carries
`Error: vmax: no such variable.` — so a readback written as `echo $name` gets nothing
on either binary, and gets it *silently on stdout*.

`print name` is the door. So is `print name > file`.

## 2. `meas … > file` writes, where `option > file` writes nothing

This batch measured `option > file` at **zero bytes** (stage 7, with a positive control
in the same deck). `meas` is not the same: `meas tran vmax2 MAX v(out) > meas_redir.txt`
wrote **54 bytes** on 45.2 and **52** on the fork, holding the measurement line.

**Do not generalise from one redirection to another.** The two commands are different
code paths and they behave differently.

## 3. ⚠ The `meas` echo line is BINARY-DEPENDENT; `print` is not

| | 45.2 | the fork |
|---|---|---|
| `meas` echo | `vmax                =  1.000000e+00 at=  2.000000e-08` | `vmax                =  1.00000e+00 at=  2.00000e-08` |
| `print vmax` | `vmax = 1.000000e+00` | `vmax = 1.000000e+00` |

**Six decimals against five**, in the line `meas` prints for itself; `print` is
byte-identical across both. A golden built from the `meas` echo, or a parse that keys on
field width or digit count, passes on one binary and fails on the other — which is the
shape of defect this batch's two-binary rule exists to catch.

Parse it as a **number**, never by width.

## 4. ⚠ A FAILED measurement is silent on every channel the guard can see

`meas tran bad FIND v(out) WHEN v(out)=99`, where no such crossing exists:

* exit code **0**
* **`$sim_status` 0** — the guard that follows every analysis cannot see it
* **no vector created** — `display` does not list `bad`
* **`print bad` prints NOTHING AT ALL** — not an error, not a blank value, no line
* the only trace: a **stderr** line, `Error: measure  bad  find(AT) : out of interval`

Identical on both binaries. So *"this measurement failed"* is detectable only as
**absence** — the vector is not there, the producer's file has no line for it — or by
reading **stderr**. Neither the exit code nor `$sim_status` will ever say so, and a
producer that reports "no value" and a producer that was never asked look the same from
stdout.

## 5. ⚠ A DECK-CARD `.measure` NEVER BECOMES A VECTOR — it is stdout text and nothing else

The two spellings are not two ways to say the same thing.

A deck carrying `.tran 0.1n 20n` and `.measure tran dmax MAX v(out)`, with a `.control`
block that calls `run` and then looks for the result, measured on both binaries:

```
=== setplot listing ===
Current tran1  * ... (Transient Analysis)
        const  Constant values (constants)
=== display all ===
    in / out / time / v1#branch            <- no dmax, in any plot
=== print tran1.dmax ===
                                           <- prints NOTHING
```

The measurement line **is** printed — before the control block's own output, as the card
is evaluated during the run — and then it is gone. `display all` lists no `dmax` in any
plot, `setplot` shows no extra plot holding it, and `print tran1.dmax` answers with an
empty line and no error.

**So a producer inside `.control` cannot read back a deck-card `.measure` at all.** The
control-block form (`meas …`, §1) is the one that creates the vector. The deck-card form
gives you stdout text in the binary-dependent format of §3, and a `.measure … failed!`
line on stderr when it does not match.

⚠ And note the second trap visible in the same transcript: a deck that carries **both**
`.tran` and a `.control` with `run` **runs the analysis twice** in `-b` mode — the control
block's run, then the deck's own — printing two of every measurement line. That is worth
knowing before anything greps stdout expecting one.
