# Receipt Av — issue 1606, Stage A REFUTATION

**Crew:** Stage A refutation (`refute:A-measure-and-drive`). **Tree:** `34913077`, clean before and
after (`git status --porcelain` = the same three untracked entries both times). **Binary:**
`src/xschem`, rebuilt before every quoted figure. One file was sabotaged for an attribution proof
(`src/callback.c`), restored with `cp` and rebuilt; `md5sum` of `src/callback.c`, `src/draw.c`,
`src/editprop.c`, `src/eval_expr.y` and `src/save.c` all match `git show HEAD:<f>` at the end.

Arms used:
* **headless** — `HOME=<scratch> timeout <n> env -u DISPLAY ./src/xschem --nogui --pipe -q …`
* **display** — `GUI_GATE=0 DISPLAY=:99 HOME=<scratch> timeout <n> ./src/xschem --pipe -q … </dev/null`
  (`devdisplay.sh status` → `alive`, Xvfb 3979908, openbox; I neither started, stopped nor viewed
  it). **No run ever used `$DISPLAY` = `172.20.160.1:0`.** Every `HOME` was a scratchpad directory.
  Pre-existing `xschem` processes from other sessions (pids 1700939, 2530920, 3675456…) were left
  alone; no `/tmp/xschem_emergencysave_*` was touched.

Verdict on Stage A overall: **the big answers survive and four stated conclusions do not.** The
headline threshold, the width table, the site list, the writer list, the counts and the file-borne
answer all reproduce. What breaks is the receipt's **Stage-B-facing** conclusion (a "69 vs 71"
conflict with issue 1602 that does not exist), two of its **"could not drive"** entries (both
drivable, one now driven at a *lower* threshold than the receipt records), and two of its
**all-signs ceilings**.

---

## 1. REFUTED — there is no "69 vs 71" conflict, and a global clamp at 71 is safe everywhere reachable

Receipt A §7 and the structured summary both say:

> the TIGHTEST is 69 (`" %.*g%c "` into `char[100]`, and `"%.*gMEG"` into `char[80]`), which is
> LOWER than issue 1602's ratified dialog ceiling of 71. So a single writer-side clamp to 71 would
> leave `draw_hcursor` and `draw_hcursor_difference` theoretically unsafe at 70 and 71 for a
> negative three-digit-exponent value.

Three independent counters, and the first is the receipt's own table.

**(a) The table in the same section says 89, not 69.** `" %.*g%c "` costs `P+10` chars, `P+11`
bytes: **69** in the **80**-byte column, **89** in the **100**-byte column. Every
`" %.*g%c "` site in this tree (`draw_hcursor`, `draw_hcursor_difference`) uses `char tmpstr[100]`.
No site anywhere pairs that format with an 80-byte buffer. The prose read the wrong column.

**(b) Measurement: `draw_hcursor` at precision 71 with a negative three-digit-exponent value is
fine, and its real all-signs boundary is 89/90.** Fixture (display arm, `:99`): a hermetic
`xschem raw new f.raw dc vsweep 0 1.0 0.1` + `raw add v_a {vsweep 1 *}` and one graph rect with
`unity=T x1=0 x2=1 y1=-1e300 y2=1e300 hcursor1_y=-5e299` (`xschem get graph_flags` → `128`),
then `xschem redraw`:

```
prec=71 rc=0  flags=128 redraw-ok
prec=88 rc=0  flags=128 redraw-ok
prec=89 rc=0  flags=128 redraw-ok
prec=90 rc=134  buffer overflow detected
prec=91 rc=134  buffer overflow detected
```

71 clears the boundary by 18. Only `hcursor1_y` is set, so `draw_hcursor_difference` never runs;
`flags=128` (not `128|256`) is the attribution.

**(c) `"%.*gMEG"`'s 69 is unreachable, and Receipt A measured that itself.** `dtoa_eng`'s `'M'`
branch is entered only for `absi > 0.999999e6 && absi <= 0.999999e9` and then divides by `1e6`, so
the value handed to `"%.*gMEG"` is always in `(0.999999, 999.999]` — `f`-style, and a `double` in
that range has at most ~56 exact fractional digits. Driven headless over 11 values × both signs
(MEG arm and bare arm, worst-case mantissas) at **precision 69, 70, 71, 72, 100, 1000 and 4000**:

```
prec=69   rc=0 maxlen=59 DONE=1 overflow=0
prec=4000 rc=0 maxlen=59 DONE=1 overflow=0      (same at 70, 71, 72, 100, 1000)
```

59 characters, flat, at every precision. The `"%.*gMEG"` arithmetic ceiling can never bind.

**Consequence.** The tightest **reachable** ceiling in this tree is **71** — `dtoa_eng`'s
`"%.*g%c"` arm into `static char s[80]`, i.e. exactly the number 1602 ratified. Nothing in the
tree contradicts 1602, and a single writer-side clamp at 71 is safe at all thirteen sites today.

⚠ This does **not** overturn G2's *recommendation* (clamp per buffer). Per-buffer clamping is
still defensible, because a global 71 leans on an invariant that lives four branches away from the
`sprintf` — `dtoa_eng`'s value-range ladder — and on the fact that the widest buffer's `%.*e`
sibling is pinned at `prec = 2`. But G2's stated *reason*, "a single global constant cannot serve
this tree / a global 71 would leave two sites unsafe", is measurably false and must not be written
down.

---

## 2. REFUTED — `callback.c:2433` (`sy`) is drivable in isolation, and the stated mechanism is backwards

Receipt A lists `waves_callback (sy)` as `driven: not-driven`, because

> `sx` at `:2428` has the identical expression, buffer size and format string and aborts five lines
> earlier, so `sy` can never be observed first. Driving `sy` alone would need `unitx == 1.0` with
> `unity != 1.0`, and the `unitx == 1.0` branch then goes through `dtoa_eng`'s 80-byte buffer.

**The guard tests the wrong variable.** Both branches in that block test `gr->unitx`:

```c
      char sx[100], sy[100];                                        /* callback.c:2409 */
      ...
      if(gr->unitx != 1.0)                                          /* :2427 */
        sprintf(sx, "%.*g%c", xctx->ev_precision, gr->unitx * xval, gr->unitx_suffix);
      else
        my_strncpy(sx, dtoa_eng(xval, xctx->ev_precision), S(sx));

      if(gr->unitx != 1.0)          /* <-- tests unitx, formats unity */   /* :2432 */
        sprintf(sy, "%.*g%c", xctx->ev_precision, gr->unity * yval, gr->unity_suffix);
      else
        my_strncpy(sy, dtoa_eng(yval, xctx->ev_precision), S(sy));
```

So `sy`'s `sprintf` runs whenever `unitx != 1.0`, whatever `unity` is, and under `unitx == 1.0`
**both** go to `dtoa_eng`. The receipt's recipe for isolating `sy` cannot work; a different one can.

**Driven.** Make the x value short and the y value long: `unitx=T`, `x1=0 x2=1` (so
`unitx*xval ≈ 2.66e-13`, ~81 exact significant digits, output pinned) and `y1=-1e300 y2=1e300`
(so `unity*yval ≈ 1.1e288`, ~289 digits). `M` key then MotionNotify at the centre of `.drw`
(`xschem callback .drw 2 400 200 77 0 0 0`, `graph_flags` → 64; `xschem callback .drw 6 400 200 0 0 0 0`):

```
prec=4   rc=0    y len=13   x len=12
prec=88  rc=0    y len=97   x len=88
prec=91  rc=0    y len=100  x len=88
prec=92  rc=0    y len=101  x len=88     <- sy is 99 chars + NUL = exactly 100
prec=93  rc=134  *** buffer overflow detected ***
prec=94  rc=134
```

The `x=` line does not move from 88 characters between precision 88 and 93 — `sx` cannot overflow
in this fixture at any precision. Only `sy` grows, and only `sy` can be the abort.

**Attribution proved by sabotage.** `char sx[100], sy[100];` → `char sx[100], sy[400];`, nothing
else, `make -C src`:

```
##### SABOTAGED sy[400], prec=93   rc=0   y len=102  x len=88
##### SABOTAGED sy[400], prec=94   rc=0   y len=103  x len=88
##### SABOTAGED sy[400], prec=200  rc=0   y len=209
```

Restored with `cp` (not `cp -a`) + `make -C src`; `md5sum src/callback.c` =
`1f7ae98666964a95c3ef984239b8760b` = `git show HEAD:src/callback.c | md5sum`; the restored binary
aborts again at 93. So `sy`'s threshold is 93 positive / 91 all-signs — the same numbers Receipt A
*inferred* — but it is a **driven** site, not an inferred one, and the inference that got there was
built on a misreading of the guard.

### 2b. The guard bug is a door at 73 that nobody has named, in an ordinary configuration

Because `:2432` tests `unitx`, a graph with `unity=T` and **no** `unitx` sends the **y** readout to
`dtoa_eng`'s 80-byte buffer instead of its own 100-byte one. Same fixture, `unity=T` only:

```
prec=4   rc=0    y=1.101e+288T         x=0.2664
prec=71  rc=0    y len=80
prec=72  rc=0    y len=80
prec=73  rc=134  *** buffer overflow detected ***
```

**The y readout's abort threshold drops from 93 to 73** in a configuration a user reaches by
setting a y-axis unit and no x-axis unit. Receipt A measured the 73 for the case where *both*
units are removed and concluded "there is no safe branch in that block"; it did not notice that
one unit alone is enough, nor that the cause is the guard naming the wrong variable.

⚠ **Carried forward, not fixed, not in the issue, the plan or Receipt A:** `callback.c:2432` tests
`gr->unitx != 1.0` and then formats `gr->unity * yval` with `gr->unity_suffix`. Two consequences,
both live today: `unity=T` alone routes the y readout through the *tighter* buffer (above), and
`unitx=T` alone formats the y value with `unity == 1.0` and `unity_suffix == 0`, i.e. `%c` writes a
NUL where a suffix was intended. Neither is an `ev_precision` defect; both are in the block 1606
has to fence, so a fence written from Receipt A's description of this block will mis-state which
buffer protects `sy`.

---

## 3. REFUTED — the four `input_line {Pos:}` `dtoa_eng` callers are drivable, and the reason given is wrong

Receipt A: *"The four `input_line {Pos:}` sites are **not-driven** (they need a real key event in a
graph on a display)."*

They are not key events. `callback.c:2631/:2661/:2686/:2701` sit under
`else if(event == ButtonPress && button == Button3)`, each behind
`if(fabs(xctx->mousex - W_X(logcursor)) < 10)`. The same `xschem callback` verb Receipt A already
used for the `M` key drives them — event type **4** (ButtonPress), button 3.

Found the hit position by sweeping Button3 press/release over `.drw` (1110×693) with the Tcl
`input_line` proc renamed away so the modal grab cannot hang the run:

```
MARK flags=2 winw=1110 winh=693
MARK INPUT_LINE <1e+288T> at 592,240
```

Then at that one position, `cursor1_x=1e300`, `unitx=T`, `x1=0 x2=2e300`:

```
prec=4   rc=0    INPUT_LINE len=7    AFTERPRESS
prec=71  rc=0    INPUT_LINE len=78   AFTERPRESS
prec=72  rc=0    INPUT_LINE len=79   AFTERPRESS
prec=73  rc=134  *** buffer overflow detected ***
```

The stub is only there to avoid the grab: `dtoa_eng` is evaluated to build the command string
**before** `tclvareval` runs, so the abort happens before any dialog exists and the product path is
byte-identical. In the shipped product this is a **fifth real-user door**: right-click on a cursor
readout in a graph. It needs no unusual content — just an `ev_precision` past 72 and a cursor
parked on a large value.

---

## 4. REFUTED — two "all-signs" ceilings are one digit too tight

Receipt A records all-signs ceilings of **91** for `draw_cursor_difference` and **89** for
`draw_hcursor_difference`, derived by subtracting a sign byte. Neither site can ever print a sign:

```c
  diffw = fabs(c2 - c1);                                            /* draw.c, draw_cursor_difference */
  sprintf(tmpstr, "%.*g%c", xctx->ev_precision, gr->unitx * diffw, gr->unitx_suffix);

  diffh = fabs(c2 - c1);                                            /* draw.c, draw_hcursor_difference */
  sprintf(tmpstr, " %.*g%c ", xctx->ev_precision, gr->unity * diffh, gr->unity_suffix);
```

and `get_unit()` (draw.c) returns only `1.0`, `1e15 … 1e-12` — never zero, never negative. So the
formatted value is always `>= 0` and the all-signs ceilings equal the positive ones: **92** and
**90**. That is exactly what Receipt A's own sweeps measured (`88..92 SURVIVED | 93 rc 134`;
`88,89,90 SURVIVED | 91 rc 134`) — the recorded figures are one tighter than the evidence behind
them. Only `draw_cursor` (91) and `draw_hcursor` (89) genuinely lose a byte to the sign, and I
measured `draw_hcursor`'s 89/90 boundary directly in §1(b).

---

## 5. EVIDENCE THIN — file-borne is YES, but the receipt's two traces disagree about what "opening" means

This is the answer the driver will report, so it got the hardest look. **The conclusion survives and
is in one respect stronger than stated.** The evidence for it, as written, does not hold together:
§6's own trace reads

```
before load: ev=4
after load:  ev=4
svg:
after svg:   ev=200
```

while the landmine trace two paragraphs later reads `step2 after opening someone else's schematic:
ev=200`. Neither says which arm it came from. Both are true, on different arms. Measured on
Receipt A's own eight-line `t_float.sch`, unchanged:

| arm | `xschem load` | `+ xschem redraw` | `+ xschem print svg` |
|---|---|---|---|
| headless (`--nogui`, `env -u DISPLAY`) | ev=4 | ev=4 | **ev=200** |
| display (`:99`) | **ev=200** | — | — |

and the SVG contains `>200POISONED<`. So on a GUI **opening alone really is enough** (the load
triggers a draw, the draw evaluates the floater) — stronger than §6's headless trace shows — while
**a headless Stage C row that asserts "load alone poisons" would fail**, which is exactly the shape
a reader of §6's landmine trace would write.

**The fixture is a plain file with no other privilege** — eight records, no symbol library, no raw
file, no command-line flag, `HOME` a throwaway. Confirmed.

**Doors re-tried, including two the instructions asked for:**

| door | Receipt A | this crew |
|---|---|---|
| `T {tcleval(…)} … {floater=true}` | works | works (table above) |
| `T {tcleval(…)} … {name=x1}` | implied by "`name=` or `floater=`" | **works**: headless ev=4 after load, **ev=113** after svg; display **ev=113** after load alone |
| plain `T {tcleval(…)}` no attribute | dead | dead (headless: load/svg/netlist all ev=4; display: load ev=4) |
| schematic-level `G {tcleval(…)}` | dead | dead (same four probes, all ev=4) |
| `.sym` `format="tcleval(…)"` + `xschem netlist` | works | **works headless**: `after load ev=4` / `netlist rc=0` / `after netlist ev=222`, and the emitted `use_sym.spice` line 3 is literally `222* poisoned by a symbol format` |
| generator | not driven (inferred from `popen`) | not driven either — still an inference |

So: a `.sch` poisons on open (GUI) or on export (headless); a `.sym` poisons on plain netlisting.
**Netlisting someone else's symbol library is enough**, and that half of the answer needs no display
and no export. The severity conclusion stands.

---

## 6. EVIDENCE THIN — "unreachable headless" is right at every door, but only one door was checked

Receipt A: *"What does NOT run headless is `draw_graph()` and everything under it — `draw()` calls
`draw_graph_all()` inside `if(has_x)`."* True, and it covers one of five entry points. I checked the
other four, because the first thing a Stage C author will try is the export path — `xschem print
svg` **does** evaluate floaters headless (§5), so it looks like a door:

* `svg_embedded_graph` (draw.c) calls `setup_graph_data` + `draw_graph(i, 8 + (xctx->graph_flags &
  (4|2|128|256)), …)` — cursor bits and all — but its **first statement after the declarations is
  `if(!has_x) return;`**.
* `ps_embedded_graph` (psprint.c) does the same and has `if (!has_x) return 0;`.
* the `xschem draw_graph <n>` verb (scheduler.c) is gated `if(argc > 2 && has_x && …)`, with a
  comment recording the SIGSEGV that gate exists to prevent.
* `callback.c:2402` and `:3607` need real events.

Driven anyway, to be sure: the hcursor fixture headless with `xschem print svg` **and**
`xschem print ps` at precision 4, 89, 90 and 200 — `rc=0` every time, `graph_flags=0` (headless
`zoom_full` never runs `draw_graph_all`, so the cursor bits are never set either); and a
cursor-1 fixture where `xschem cursor 1 1` *does* set `flags=2` headless, then
`xschem print svg` at 4, 92, 93 and **200** — `rc=0` every time, and the SVG carries no cursor
readout. **Conclusion confirmed at every door; the stated reason covers one of them.**

---

## 7. EVIDENCE THIN — three assertions with no command behind them

**(a) "No emergency save, no message in the GUI."** True, and namable: `main.c` installs
`sig_handler` for `SIGINT`, `SIGSEGV`, `SIGILL`, `SIGTERM` and `SIGFPE` — **not `SIGABRT`** — so
glibc's fortify `abort()` bypasses the emergency-save path entirely. Independent check after ~40
aborts of my own: `find /tmp -maxdepth 1 -name 'xschem_emergencysave_*' -newermt '-60 minutes'` →
**0**.

**(b) `token.c:6283` "ABORTED"** was attributed by threshold only — Receipt A quotes `gdb`
backtraces for the five display-arm sites and none for this one. It reproduces and it is
self-attributing, because the *returned value* is `dtoa_eng`'s output:

```
prec=4  rc=0    TRANSLATE len=7
prec=71 rc=0    TRANSLATE len=78
prec=72 rc=0    TRANSLATE len=79
prec=73 rc=134  *** buffer overflow detected ***
```

via `xschem translate -1 {@spice_get_node v_big}` on a hermetic raw. Verdict stands.

**(c) `nd_view_set` "ABORTED at 94"** likewise has no backtrace, and likewise needs none: the
published string's length is the fingerprint. Reproduced headless:

```
prec=4  rc=0    PUBLISHED len=6
prec=91 rc=0    PUBLISHED len=97
prec=92 rc=0    PUBLISHED len=98
prec=93 rc=0    PUBLISHED len=99      <- 99 + NUL = exactly 100
prec=94 rc=134  *** buffer overflow detected ***
```

99 characters into a 100-byte buffer from a bare `"%.*g"` is unique in this tree. With a negative
vector (`raw add v_a {vsweep -1e-300 *}`): 92 → 99 chars rc 0, **93 → rc 134**, i.e. all-signs
ceiling **92**, as recorded.

**(d) The kklex() fourth writer is right and did not need the bison sabotage.** Non-invasive proof:
`xschem get drawcount` is **0** before and after the reproducer while `expr_eng(1e300*1.0)` still
formats at precision 71 (78 chars), so `draw()` never ran; and
`/usr/bin/grep -n 'xctx->ev_precision *=' src/*.c src/*.y` gives exactly four writers —
`xinit.c:761`, `draw.c:9011`, `draw.c:10595`, `eval_expr.y:258` (`eval_expr.c:1707`). The write in
`draw()` does sit above the `if(has_x)` (the `if(has_x) tk_scaling = …` line is immediately before
it and the next `if(has_x) {` is 18 lines below), and my `nd_view_set` fixture proves it fires
headless: with no `eval_expr` anywhere, `xschem redraw` alone is what makes `nd_view.prec` 93.
⚠ `xinit.c:761`'s own comment — *"copied from TCL ev_precision var in draw() and draw_graph()"* — is
now incomplete, and it is the comment a reader would trust instead of grepping.

---

## 8. SURVIVED — everything I attacked and could not break

**The headline threshold is the threshold, not a fixture artefact.** Swept **all twelve
`dtoa_eng` branches** (T, G, MEG, k, bare, m, u, n, p, f, a and zero), positive and negative, with
worst-case mantissas, headless:

* **precision 71** — widest output **79 characters** (`-1.797…e+296T`, `DBL_MAX` in the T branch),
  i.e. the 80-byte buffer exactly full, `rc 0` for all 25 values.
* **precision 72** — the first value aborts.
* positive-only at 72 survives at 79 chars; the abort at 72 is the negative twin, and 73 aborts
  positive too. Exactly Receipt A's and the issue's figures.

**The width arithmetic.** Re-derived by hand and again by an exhaustive C search (P = 0…4000 × 27
extreme doubles). Identical to Receipt A's table in every cell:

```
%.*g        buf80=72   buf100=92   buf1024=any
%.*g%c      buf80=71   buf100=91   buf1024=any
%.*gMEG     buf80=69   buf100=89   buf1024=any
 %.*g%c     buf80=69   buf100=89   buf1024=any
%.*e%c      buf80=70   buf100=90   buf1024=1014
max %g chars = 774 at P=767 (value -2.2250738585072009e-308)
```

The 774 bound is real and is the thing that makes every 1024-byte `%g` concern moot. The
`%.*e` ceiling of 1014 is right and so is the prose's "abort at precision 1015" — they are the same
statement. Two degenerate cases worth having on record, neither a defect: `atoi` gives
`ev_precision=2147483648` → `-2147483648` → a negative `*` precision, which C treats as omitted, so
**that value is safe** while 73 is not; and `atoi("99999999999")` → `1215752191`, a positive
precision that `%g`'s 774-char cap still bounds.

**The site list is complete and the counts are right.** Independent
`/usr/bin/grep -n '%\.\*' src/*.c src/*.h src/*.y src/*.l` finds the same **13** `sprintf`
statements and nothing else; a separate pass for indirect **width** finds no `printf`-family site at
all. `dtoa_eng` has **24** call sites (plan says 27): **13** pass `xctx->ev_precision` directly
(`token.c` ×7, `callback.c` ×6 — including the four `input_line {Pos:}` dialogs), **1** passes
`engineering` (`eval_expr.c:1602`), **8** pass a hardcoded `5`, **2** pass the clamped `prec`.
Receipt A's numbers exactly.

**`show_node_measures` is the function, it holds two `sprintf`s, and its formats are variables.**
Confirmed by reading: `char tmpstr[1024] = "";`, `int prec = xctx->ev_precision;`, the `%.*e` arm
sets `prec = 2` three lines above, `fmt1`/`fmt2` are `char *`, and the two `sprintf`s are the
`gr->unity != 1.0` / `else` pair. They are mutually exclusive per call. The tree's only `%.*e` pair.
Its **survival** verdict needs no measurement given the 774 cap and the `prec = 2`.
⚠ Its **reachability** rests entirely on Receipt A's `tmpstr[16]` sabotage, which I did **not**
repeat: `-O2` inlines the function (no symbol in `nm -C src/xschem`), so there is no breakpoint
alternative and the only independent check is the same sabotage. I accept the crew's evidence and
flag that it is single-sourced.

**`graph_marker_fmt`.** Exactly **4** callers, all in `graph_marker_text_rec`, all below
`if(prec <= 0) prec = 5;` and `if(prec > 17) prec = 17;`, all passing `char[80]`. No fifth caller
exists. The signature does lie: the `sprintf` arm ignores `destsize`, the `else` arm honours it.
Latent, as the issue re-classified it. (I did not re-drive the 4000 figure; the call graph is
decisive.)

**The writers, and the in-tree trap.** All reproduced:

```
--rcfile <f>, IN-TREE            -> Sourcing …/rc/myrc / ev_precision=200 / rc 134
~/.xschem/xschemrc, IN-TREE      -> ev_precision=4 / POS len=7 / rc 0        <- VACUOUS
~/.xschem/xschemrc + non-src XSCHEM_SHAREDIR -> ev_precision=200 / rc 134
--preinit 'set ev_precision 73'  -> rc 134
```

and the gate is where Receipt A says: in `xinit.c`, both `./xschemrc` (tried **first**) and
`$USER_CONF_DIR/xschemrc` sit inside `if(!running_in_src_dir)`, while the `--rcfile` arm is the
`if` branch above it and is honoured regardless. `running_in_src_dir` is 1 when `XSCHEM_SHAREDIR`
holds `xschem.tcl` **and** `systemlib` **and** `xschem`. A Stage C rc-file row run in-tree measures
nothing — confirmed, not inherited.

**No C-side writer sets the Tcl variable.** `/usr/bin/grep`ped: no `tclsetintvar("ev_precision"…)`
anywhere; the only writer of the Tcl side is `set_ev_precision` in `src/xschem.tcl` (1602's
validator).

**Option 3's real cost.** Confirmed by reading `src/util.c`: `HAS_SNPRINTF` is in no config header,
so the live `my_snprintf` is the hand-rolled one, and its `g`/`e`/`f` arm is

```c
      char nfmt[50], nstr[50];
      ...
      nlen = sprintf(nstr, nfmt, i);
      if(n + nlen + 1 > size) { overflow = 1; break; }
```

— the bound test after the write. The same unchecked shape is in the `d/x/c/u` arm and the `p` arm.
No live caller reaches 50 characters: every float caller in the tree is `%g`, `%.8g`, `%.10g`,
`%.15g`, `%.16g`, `%.17g` or `%.10e` (all ≤ 24 chars), and the only `%f` is `scheduler.c`'s
`"%.6f"` on a bounded march offset. Receipt A's carried-forward item #1 stands as written.

---

## 9. What I could not measure

* **`show_node_measures` reachability** — see §8. Inlined at `-O2`; the only method is the sabotage
  Receipt A already ran, so this stays single-sourced.
* **`callback.c:2661/:2686/:2701`** (the cursor-2 and two hcursor `input_line {Pos:}` dialogs) — I
  drove `:2631` only. The other three are the same statement behind `graph_flags & 4 / 128 / 256`
  and the same `< 10` proximity test; the method in §3 reaches them with a different flag bit set,
  and I did not spend the runs.
* **Six of the seven `token.c` `dtoa_eng` sites** — as Receipt A says, each needs its own
  instance/net fixture. Unchanged.
* **Generators** — still an inference on both receipts.
* **`draw.c:9011` in isolation** — I did not stage a run in which only `draw_graph()`'s writer
  fires, same as Receipt A.
* **Anything on `:0` or on the user's real screen** — everything display-side was `:99`.

---

## 10. What Stage B and Stage C should take from this

1. **Do not write down a 69-vs-1602 conflict.** It does not exist (§1). If per-buffer clamping is
   recommended, recommend it for the reason that survives: the global-71 answer is only safe
   *because* of `dtoa_eng`'s value-range ladder and a `prec = 2` four branches away from a `sprintf`,
   neither of which is visible at the site being protected.
2. **The `callback.c` measurement block needs reading before it is fenced** (§2, §2b): `sy` is
   selected by `unitx`, so its live ceiling is 73 in one ordinary configuration and 93 in another.
   A fence that assumes "sy is protected by `sy[100]`" is wrong half the time.
3. **`callback.c:2631` and its three siblings are behavioural rows, not static ones** (§3), and the
   drive is a Button3 press with `input_line` renamed away.
4. **A file-borne row must say which arm it is on** (§5): headless needs `xschem print svg` (or
   `xschem netlist` for the `.sym` door); the display arm needs only `xschem load`.
5. **The four `draw.c` cursor sites really do need the display arm** (§6) — but say so on the
   evidence of all five `draw_graph` entry points, because the export path looks open and is not.
6. Correct the two `*_difference` all-signs ceilings to **92** and **90** (§4).
