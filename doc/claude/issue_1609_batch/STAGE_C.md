# Stage C — implementation brief for issue 1609, with every Stage A claim adjudicated

Read `CREW_BRIEF.md` first, then this. **This supersedes `PLAN.md` and `DECISIONS.md` K1 wherever
they disagree** — Stage A refuted the driver's stated mechanism and two of its consequences. Do not
re-derive the measurements; they are in `receipts/A-measure.md`, and the corrections are at the top
of the issue file. There is no separate Stage B: Stage A measured the fix shape as well, and every
open question it left is adjudicated below.

## ⚠ The mechanism is ZERO-extension, and that is the whole reason the fix is shaped this way

`mov 0x10(%rsp),%r8d` before `call __sprintf_chk` in the shipped `src/util.o`, at every `-O` level.
So the truncated value round-trips **only as unsigned 32-bit** and the two halves of the bug agree
on exactly **`[0, 2^32)`**. `%ld` of `-1` prints `4294967295`; of `LONG_MIN`, `0`.

**And "it works because of the ABI" is refuted by the x86-64 psABI itself**: the excess bits are
*unspecified*, and the consumer must extend them. It works because of **gcc's instruction
selection**. Say that, and not the other thing, in any comment you write.

## The ten adjudications

**L1. FETCH BY MODIFIER. Do NOT refuse `l` and cast at the call sites.** The reason is a
measurement, not a preference: `-Wformat -Wformat-nonliteral` over all 40 `src/*.c` finds **zero**
argument-type mismatches at any `my_snprintf` call, and an anti-vacuity probe proves gcc would catch
both a `long` into `%d` and an `int` into `%ld`. The format attribute already polices every caller,
so **the only type mismatch in the program is inside `my_snprintf`**. Hand-written `(int)` casts
would satisfy gcc and convert a diagnosable bug into an undiagnosable one.

**L2. TWO FETCHES, NOT ONE, AND THIS IS THE DIFFERENCE BETWEEN A FIX AND A RULING.** `d` wants
`long`; `u` and `x` want `unsigned long`. Measured: a single **signed** `long` fetch would make
`%lu` of `-1` print `18446744073709551615` where it prints `4294967295` today. That is
user-visible, so it would stop being internal engineering and the driver would have to file a
`rule`. With the split, **every current output is preserved byte for byte** — which is the property
your neutrality rows must assert.

**L3. `%lc` STAYS ON THE `int` FETCH, and do NOT normalise `%c` to `%lc`.** Two independent
reasons. `wint_t` is 4 bytes on glibc and promotes to `int` on Windows, so the existing fetch is
already the right width. And the tempting shortcut — normalise every integer spec to carry `l` so
one `va_arg`/`sprintf` pair serves all of them — would turn **all eighteen live `%c` into `%lc`**,
which makes **issue 1612 file-borne**: `src/draw.c` formats `"%s[%c]"` with `gr->unitx_suffix`,
which is `val[0]` of a graph rectangle's `unitx=` attribute **out of a `.sch` file**, and `%lc` of
a byte ≥ 128 makes glibc return `-1`, which nothing here checks. **Read issue 1612 before you
write the branch.**

**L4. TIGHTEN GUARD 2 INTO A REAL MODIFIER WHITELIST — it is a per-character loop today.** Driven:
`%lld`, `%llu`, `%llx`, `%hhd`, `%hhu`, `%lhd`, `%hld`, `%llld` and `%hhhhd` are **all accepted**
(`%zd %jd %td %qd %I32d %*d %nd` are correctly refused). **`ll` must be REFUSED, not implemented**:
this tree is C89 and C89 has no `long long`, so implementing it is not available to you. Refuse a
**repeated or mixed** modifier too — `%lhd` and `%hhhhd` are not specs anyone meant to write, and
`%llld` makes glibc emit a literal `%`-fragment instead of a number. This closes a gap in issue
1608's GUARD 2 against **its own stated intent**: that batch's J4 listed `hh` among what it meant to
stop.

**L5. ⚠ REFUTED IN ITS MECHANICS BY STAGE C — the edit this adjudication asked for was not the one
needed.** `W1` permits by the text `sprintf(nstr, nfmt,` **up to the comma**, so it already covered
`…, lv)` and `…, ulv)`; its matcher needed no change and it stayed green, with
`total_nonliteral_diags` rising from 5 to 7 and `offending={}`. What actually needed editing was
**three sentences quoting counts** — `util.c`'s *"THE THREE … CALLS"* and *"(util.c, three sites;
draw.c has two more)"*, plus `W1`'s own comment — i.e. named limit **L9**, not a permitted list. All
three are now shape-only and each records that this issue falsified the number in the week it was
written. The original adjudication follows, kept because its instinct (the change touches W1's
neighbourhood) was right even though its mechanism was wrong.

**L5 (as written). YOU WILL ADD A FOURTH NON-LITERAL `sprintf` TO `util.c`, AND ROW `W1` KNOWS ABOUT THE OTHER
THREE.** `W1` of `tests/headless/test_snprintf_fmt_1608.tcl` asserts that no `-Wformat-nonliteral`
diagnostic falls on a line spelling `my_snprintf(`, and permits exactly the existing shapes **by
their text**. Branching the `sprintf` call adds one. **Update `W1`'s permitted list in the same
commit**, and say in its comment why the count moved — the suite's header carries named limit `L9`
forbidding a quoted count, so express it as a shape, not a number.

**L6. THE BEHAVIOURAL ROW MUST PLANT A VALUE, AND SAY IN ITS OWN COMMENT THAT IT DOES.** No live
caller can *ever* redden: every value a live caller can produce lies inside the agreeing band **by
construction** — `Display.max_request_size` is an `unsigned` in `Xlib.h` and XIDs are CARD32.
Stage A left a working instrument at `<scratchpad>/stageA_1609/stubs_1609.c`: a 30-line stub file
that links a driver against **the real `src/util.o`**, not a `sed` extraction. Copy it. Refusal is
observable with no new entry point — `"X%<spec>Y"` gives `X` and ret 1 when refused, `X…Y` when
accepted.

**L7. EVERY GUARD GETS A ROW THAT REDDENS ON ITS OWN SINGLE REMOVAL.** You are adding several: the
`long` fetch, the `unsigned long` fetch, the `ll` refusal, the repeated-modifier refusal. If two of
them cover one path, fence each separately **and say so in its comment** — two guards on one path
means neither is individually fenced, which cost the 1606 batch a whole fencing plan.

**L8. WHAT A COMMENT MAY AND MAY NOT CLAIM.** The psABI clause is the argument to make, and it is a
**quotation**, so quote it. **Win64 is LLP64 and has no defect at all** — say that. **Big-endian
LP64 takes the HIGH half so every value misprints** — say that, labelled a derivation. **Do NOT
write the aarch64 sentence in the original filing**: AArch64 W-register writes also zero-extend and
these arguments are register-passed, so AAPCS64's stack-padding case never arises, and there is no
aarch64 toolchain or emulator here. Issue 1606 shipped a comment that turned exactly this kind of
derivation into a claimed measurement and had to correct it.

**L9. TWO MEASURED TRAPS, both of which wasted a pass in Stage A.** A `--rcfile` probe **without
`--script` exits rc 1 with no output for every value**, including a valid file, because the run ends
before `Tcl_AppInit`'s rcfile block — so it reads as "door closed" while measuring nothing. The
armed spelling is `--nogui --pipe -q --rcfile <spec> --script <file>`. And
`tests/headless/devdisplay.sh exec` **fails under an overridden `HOME`** (`":99 is not running"`)
because it reads `~/.claude/xschem_dev_display`.

**L10. DO NOT QUOTE A COUNT, AND KNOW WHICH FIGURES ARE REPRODUCIBLE.** Named limit `L9` of the 1608
suite. A truncated `long` **is** reproducible and may be quoted with its control; stack garbage is
not. Stage A's own censuses came out **720 compiled / 751 raw / 4 modifier occurrences** — quote the
instrument with any of them, or drop the number.

## Also required

* **Correct nothing in the issue file** — the driver has already written the correction section at
  its top. If you refute something in *that*, say so in your receipt and leave the file alone.
* Carried forward, **named not fixed**: issue 1612 (`sprintf`'s unchecked negative return); the
  `d/x/c/u` and `p` arms' prefix guard (closed by 1608, verify it stayed closed); and `%lp`/`%llp`/
  `%hp` being accepted and ignored by glibc, which is harmless because the tree's only `%p` carries
  no modifier.
