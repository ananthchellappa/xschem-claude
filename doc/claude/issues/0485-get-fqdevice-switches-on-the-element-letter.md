# 0485 — `get_fqdevice()` switches on the SPICE element letter, so the generic tokens can never name a subcircuit-wrapped PDK device

Status: **OPEN, measured three times on this tree (S12 scout, S12 measure,
S12 write-up agent, all on HEAD `734456be`). NOT FIXED — filed, not fixed, per
the S12 brief.**
Filed by the S12 crew (2026-08-21). **This issue supersedes the plan's
reservation of number 0419** — nothing was ever created under 0419; the plan
reserved it and the number stayed free, so the next free number at filing time
was 0485. A reader chasing "0419" from the plan should come here.
Related: issue **0484** (the token-family twin — matched then dropped),
issue 0426 (the `strtolower` in the same function), invariant **I1** (one name
builder), spec §2.3 and §4.2 — **this defect is the reason `op_annot` exists**.

## The claim

`get_fqdevice()` decides what kind of device it is looking at from **one
character**: the first letter of the instance name. For every PDK device that
is a subcircuit wrapper — which is every FET in sky130, gf180 and IHP alike —
that letter says nothing useful, and the function silently builds a vector name
that no raw file will ever contain. This is why all three PDKs spell their
annotation vectors out by hand in the symbol, and why the `op_annot`
descriptor mechanism exists at all.

## Measured — BEFORE transcript, quoted verbatim from the S12 measure agent

    sky130 M1: name=M1 spiceprefix=X model=nfet_01v8_lvt  |  get_fqdevice M1 gm 1
        -> @m1[gm] ; M1 vth 2 -> v(@m1[vth]) ; M1 id 0 -> i(@m1[id])
        [top-level M device: no X wrapper, no inner device]
    get_fqdevice XM1 gm 1 -> i(@xm1[i]) ; XM1 vth 2 -> i(@xm1[i]) ; XM1 id 0
        -> i(@xm1[i])   [ISSUE 0485: the 'x' branch token.c:4560 discards param
        AND modelparam -- three parameters, one identical string]

## Measured — AFTER, re-run independently by the S12 write-up agent

No tree change between the two runs. This run also probed element letters the
earlier passes did not:

    == 0485: get_fqdevice, element letter is the only input ==
      get_fqdevice M1   gm   1 -> @m1[gm]
      get_fqdevice M1   vth  2 -> v(@m1[vth])
      get_fqdevice M1   id   0 -> i(@m1[id])
      get_fqdevice XM1  gm   1 -> i(@xm1[i])
      get_fqdevice XM1  vth  2 -> i(@xm1[i])
      get_fqdevice XM1  id   0 -> i(@xm1[i])
      get_fqdevice N1   gm   1 -> i(@n1[i])
      get_fqdevice Q1   gm   1 -> @q1[gm]
      get_fqdevice D1   gm   1 -> @d1[gm]
      get_fqdevice V1   gm   1 -> i(v1)

## Three failure modes, one cause

**⚠ The mechanism is not the one the S12 brief describes, and this issue
deliberately does not repeat the brief's wording.** The brief says the letter
"is always `x` for a `spiceprefix=X` device". It is not: `instname` does **not**
carry `spiceprefix`. On the shipped fixture
`ihp-sg13g2/.../sky130_tests_ase/test_nmos`, instance `M1` has `name=M1`,
`spiceprefix=X`, `model=nfet_01v8_lvt` — and `get_fqdevice()` is handed `"M1"`.

1. **Instance named `M…`, wrapped by `spiceprefix=X`** (the common sky130 /
   gf180 case). `prefix` is `m`, so the function builds a well-formed name for a
   **top-level MOSFET**: `@m1[gm]`. The X wrapper is missing and the inner
   subcircuit device is missing. The string is plausible and wrong — it simply
   is not in the raw.

2. **Instance named `X…`.** `prefix` is `x`, which no branch handles, so control
   reaches the final `else` at `token.c:4560-4565`:

       my_snprintf(fqdev, len, "i(@%s[i])", dev);

   This discards **both** `param` *and* the `iprefix`/`ipostfix` pair that
   `modelparam` selected at `token.c:4524-4525`. Hence gm, vth and id — three
   different parameters, three different vector *kinds* — collapse to one
   identical string `i(@xm1[i])`.

3. **NEW, found by the S12 write-up agent and not recorded by any earlier pass:
   the `else` swallows every unrecognised letter, not just `x`.** Measured:
   `get_fqdevice N1 gm 1` → `i(@n1[i])`. The surviving letters are exactly
   `v`/`e` (voltage sources), `q`, `d`, `m`, `i`. Everything else — including
   **`n`**, the prefix IHP's psp103/OSDI devices use — loses its parameter the
   same way `x` does, while `q` and `d` come through intact.

   That matters for anyone writing the fix: the defect is **not** an
   "x-wrapper" special case to be patched. It is the default arm of a
   letter switch, and an x-only fix would leave the IHP `n` case failing
   silently — precisely the "works on two PDKs, fails on the third" trap this
   whole plan exists to avoid.

## Why every PDK works around it by hand

Because the generic token cannot name the device, the symbols spell the vector
out themselves. Shipped, verbatim —
`sky130A/xschem_libs/sky130_fd_pr/nfet_01v8_lvt/symbol/nfet_01v8_lvt.sym:66`:

    T {gm=@spice_get_node \\@m.@path@spiceprefix@name\\.msky130_fd_pr__@model\\[gm]} 30 -10 0 0 0.15 0.15 {layer=15

Every element of the real name — the `m.` element letter, `@path`, the
`@spiceprefix` the instance name lacks, `@name`, the PDK's inner device
`msky130_fd_pr__@model`, and the `[gm]` bracket — is hand-assembled in the
symbol text, because `get_fqdevice()` can supply none of it. Three PDKs, three
independent hand-rolled conventions, which is the duplication invariant **I1**
(one name builder, two consumers) was written against and which `op_annot`'s
registered descriptors replace.

## This one is I3-clean — the difference from 0484

With a raw loaded, the bare-token path renders `-` for these unfindable names.
That satisfies invariant I3: the user sees the project's blank marker, not a
fabricated number and not silence. **0485 is an honest dead end; 0484 is an I3
visibility violation.** Keep the two issues apart on that line.

## Anchors (every one re-verified by the write-up agent on HEAD `734456be`)

| What | Where |
|---|---|
| `char *get_fqdevice(const char *param, int modelparam, const char *instname)` | `token.c:4514` |
| `prefix=dev[0];` — the entire device-class decision | `token.c:4536` |
| `iprefix`/`ipostfix` chosen from `modelparam` | `token.c:4524-4525` |
| the `else` that discards `param`, hierarchical form | `token.c:4560` |
| the `else` that discards `param`, flat form | `token.c:4565` |
| the near-verbatim duplicate, inlined in the bare-token branch | `token.c:5163`, logic at `:5212-5248` |
| repro surface — no schematic and no raw needed | `xschem get_fqdevice <inst> <param> <modelparam>`, `scheduler.c:5488` |

Note the duplicate at `token.c:5212-5248` is a second copy of the same letter
switch, so any fix must land in both places or the two paths will disagree —
itself an I1 hazard.

## Repro (state-free, three lines)

    xschem get_fqdevice XM1 gm 1     ;# -> i(@xm1[i])
    xschem get_fqdevice XM1 vth 2    ;# -> i(@xm1[i])
    xschem get_fqdevice N1  gm 1     ;# -> i(@n1[i])

## Decision — file, do not fix

**Ladder rung L1**, invariant **I7** plus the S12 brief's file-don't-fix clause.
A real fix has to take the device class from somewhere other than the element
letter — the instance's `spiceprefix` and `model`, i.e. the same inputs the
`op_annot` descriptors already take — which is a design change to a function on
the legacy generic-token path, needs a build, and is user-visible with no
ratification. **Rejected alternative:** adding an `x` arm to the switch;
rejected because failure mode 3 shows the defect is the default arm itself, so
an `x` arm would fix sky130-style names and leave IHP's `n` devices failing
exactly as before.

## Still open

* The fix, in both copies of the switch (`token.c:4536` and `token.c:5212`).
* Whether the legacy generic tokens should be fixed at all, or documented as
  superseded by `op_annot`'s descriptors for PDK devices. The spec's §2.3
  argument implies the latter; nobody has ruled.
* Blast radius beyond FETs is unmeasured: only `v`, `e`, `q`, `d`, `m`, `i`
  were probed as survivors. Other letters (`r`, `c`, `l`, `j`, `z`, …) were not
  checked and presumably fall into the same default arm.
