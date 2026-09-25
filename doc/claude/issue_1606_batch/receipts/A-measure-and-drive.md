# Receipt A — issue 1606, Stage A: measure the abort, the sites, the writers, the arithmetic

**Crew:** Stage A (`measure:abort+sites`). **Tree:** `34913077`, clean before and after
(`git status --porcelain` identical: the three pre-existing untracked entries only).
**Binary:** `src/xschem`, rebuilt before every quoted figure. Both files sabotaged for a
measurement (`src/eval_expr.y`, `src/draw.c`) were restored with `cp` and rebuilt, and are
byte-identical to `HEAD` (`md5sum` vs `git show HEAD:…` matches for both).

Arms used:
* **headless** — `HOME=<scratch> env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog …`
* **display** — `GUI_GATE=0 DISPLAY=:99 HOME=<scratch> ./src/xschem --pipe -q --nolog …`
  (the dev display was already alive — `devdisplay.sh status` → `alive`, Xvfb pid 3979908,
  `openbox`; I neither started, stopped nor viewed it). **No run ever touched
  `$DISPLAY` = `172.20.160.1:0`.** Every `HOME` was a scratchpad directory.

---

## 0. The headline: THREE things in the plan and in G1 are wrong

1. **`xctx->ev_precision` has FOUR writers, not three, and the fourth is the one the
   reproducer uses.** `kklex()` in `src/eval_expr.y` (generated into `eval_expr.c`) opens
   with `xctx->ev_precision = tclgetintvar("ev_precision");`. The plan's "written in
   exactly three places" and G1's "exactly two unclamped writers, `draw.c:9011` and
   `draw.c:10595`" are both refuted. **A clamp at those two writers alone does not reach
   the reproducer.** Proof by sabotage, below.
2. **The plan's 1024-byte row is the wrong function and is one site short.** The
   `tmpstr[1024]` `sprintf`s at `draw.c:5274`/`:5275` are in **`show_node_measures`**, not
   in `draw_graph_variables`. `draw_graph_variables` does have a `char tmpstr[1024]` but
   formats only through `my_snprintf` with `%s` — it is not a site at all. And
   `show_node_measures` has **two** `sprintf` statements, so the twelve-row table is
   really thirteen sites.
3. **The `graph_marker_fmt` clamp is real and the 1024-byte site cannot overflow at all.**
   Measured, not argued. Details in §4.

The good news for G1: **the prediction's *conclusion* survives.** The fix is a clamp; it
lands in a handful of places, not twelve; and option 3 is not viable — in fact it is
*worse* than the driver thought (§7).

---

## 1. The abort reproduces, headless, rc 134

```
$ HOME=$SP/home timeout 30 env -u DISPLAY ./src/xschem --nogui --pipe -q \
    --preinit "set ev_precision 73" --script repro.tcl
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
ev_precision=73
*** buffer overflow detected ***: terminated
rc=134
```

where `repro.tcl` is `puts "RESULT: [xschem eval_expr {expr_eng(1e300*1.0)}]"`.

Sweep on the same command line (positive value, `1e300`):

| ev_precision | result |
|---|---|
| 4 | `1e+288T` (7 chars), rc 0 |
| 71 | 78 chars, rc 0 |
| 72 | 79 chars, rc 0 — the buffer is exactly full (79 + NUL = 80) |
| **73** | `*** buffer overflow detected ***: terminated`, **rc 134** |

And with a **negative** value (`expr_eng(-1e300*1.0)`), one byte wider:

| ev_precision | result |
|---|---|
| 70 | 77 chars, rc 0 |
| 71 | 79 chars, rc 0 |
| **72** | **rc 134** |
| 73 | rc 134 |

So **71 is the largest precision that is safe for every sign** — the issue's figure,
now measured directly rather than derived. `(0.0-1e300)` is **not** a usable reproducer:
this evaluator returns `0` for it. Use `-1e300*1.0`, `1e300*(-1.0)` or `1e300*-1`.

---

## 2. The headless question, settled: `draw()` DOES run headless, and it is not the writer anyway

The driver's worry was that `--nogui` never reaches `draw()`, so `ev_precision` would stay
at `xinit.c`'s 4. Two measurements, both against the introspection seam
`xschem get drawcount`:

* **`drawcount` is 0 through a whole `--nogui` session that nonetheless aborts.** At
  `ev_precision=73`, `drawcount at start: 0` … `drawcount after eval: 0`, and
  `expr_eng(1e300*1.0)` still aborts. So the 73 did **not** come from `draw()`.
* **But `draw()` is reachable headless:** `xschem redraw` takes `drawcount` from 0 to 1
  under `--nogui` (`xschem draw` is not a verb; `xschem zoom_full` alone did not bump it in
  my fixture). `xctx->ev_precision = tclgetintvar("ev_precision")` sits **above** the
  `if(has_x)` block in `draw()`, so it runs on that arm.

**Where the 73 actually comes from — sabotage proof.** Commenting out the single line
`xctx->ev_precision = tclgetintvar("ev_precision");` in `kklex()` (`src/eval_expr.y`),
rebuilding (bison regenerates `eval_expr.c`, which is gitignored), and re-running:

```
=== run prec=73 with kklex writer removed ===
ev_precision=73
RESULT: 1e+288T          <- formatted at 4, the xinit.c initial value
rc=0
=== run prec=200 with kklex writer removed ===
ev_precision=200
RESULT: 1e+288T
rc=0
```

Restored with `cp` + `make -C src`; the abort came back at 73 immediately
(`md5sum src/eval_expr.y` = `16f9e2678bb173c93f1cd7663c310460`, matching `HEAD`).

**Conclusion.** `xctx->ev_precision` is a global that **any** `xschem eval_expr` refreshes,
independently of drawing. Both a `--nogui` and a display run can poison it, by `kklex()`
or by `draw()`. Measured on the `save.c` publisher path, which reads
`xctx->ev_precision` with no `tclgetintvar` of its own:

| poisoned by | `$ngspice::ngspice_data(v_a)` at `ev_precision=200` |
|---|---|
| nothing | `1.1` (3 chars) — `nd_view.prec` was still 4 |
| `xschem redraw` | 53 chars, `1.100000000000000088817841970012523233890533447265625` |
| `xschem eval_expr {expr(1)}` | the same 53 chars |

So a behavioural test row for this issue **does not need a display**, and it does not need
`draw()` either.

---

## 3. Every indirect-precision site in `src/`, and what happened when it was driven

Exhaustive grep at `34913077`: `/usr/bin/grep -n '%\.\*' src/*.c src/*.h src/*.y src/*.l`
(plus a separate `%[-+ #0-9]*\*` pass, which found only `sscanf` `%*[…]` suppressions — **no
indirect-*width* `printf` site exists in this tree**). Thirteen `sprintf` statements:

| # | symbol | site | buffer | precision from | driven | verdict |
|---|---|---|---|---|---|---|
| 1 | `dtoa_eng` MEG arm | `editprop.c:182` `"%.*gMEG"` | `static char s[80]` | `precision` param | yes | **survived** at 71/100/1000 (56 chars) — its value range is `(0.999999, 999.999]`, so `%g` is f-style and the double has ≤52 exact digits |
| 2 | `dtoa_eng` suffix arm | `editprop.c:184` `"%.*g%c"` | `static char s[80]` | `precision` param | yes | **ABORTED** — 72 (neg) / 73 (pos) |
| 3 | `dtoa_eng` bare arm | `editprop.c:186` `"%.*g"` | `static char s[80]` | `precision` param | yes | **survived** at 71/100/1000 (4 chars) — value range `(0.0999999, 999.999]` or 0 |
| 4 | `draw_cursor` | `draw.c:4967` `"%.*g%c"` | `tmpstr[100]` | `xctx->ev_precision` | yes, display | **ABORTED** — 93 (pos), 92 safe |
| 5 | `draw_cursor_difference` | `draw.c:4999` `"%.*g%c"` | `tmpstr[100]` | `xctx->ev_precision` | yes, display | **ABORTED** — 93 (pos) |
| 6 | `draw_hcursor` | `draw.c:5029` `" %.*g%c "` | `tmpstr[100]` | `xctx->ev_precision` | yes, display | **ABORTED** — 91 (pos), 90 safe |
| 7 | `draw_hcursor_difference` | `draw.c:5063` `" %.*g%c "` | `tmpstr[100]` | `xctx->ev_precision` | yes, display | **ABORTED** — 91 (pos) |
| 8 | `show_node_measures` fmt2 | `draw.c:5274` (`fmt2` = `"%.*g%c"` or `"%.*e%c"`) | `tmpstr[1024]` | `prec` = `xctx->ev_precision`, forced to **2** on the `%e` arm | yes, display | **survived** at 200 — and the site is genuinely REACHED (§4) |
| 9 | `show_node_measures` fmt1 | `draw.c:5275` (`fmt1`) | `tmpstr[1024]` | same | yes, display | **survived** — same |
| 10 | `waves_callback` sx | `callback.c:2428` `"%.*g%c"` | `sx[100]` | `xctx->ev_precision` | yes, display | **ABORTED** — 93 (pos), 92 safe |
| 11 | `waves_callback` sy | `callback.c:2433` `"%.*g%c"` | `sy[100]` | `xctx->ev_precision` | **not-driven separately** — `sx` two lines above aborts first; identical expression, buffer and format | — |
| 12 | `nd_view_set` | `save.c:2904` `"%.*g"` | `s[100]` | `nd_view.prec` ← `xctx->ev_precision` | yes, **headless** | **ABORTED** — 94 (pos), 93 safe |
| 13 | `graph_marker_fmt` | `draw.c:7750` `"%.*g%c"` | `dest`, `destsize` ignored; all callers pass `char[80]` | `prec`, clamped `≤17` at `draw.c:7834` | yes, display | **survived** at 200 and at **4000** — the clamp holds |

### How each abort was attributed

`gdb -batch`, `handle SIGABRT stop print`, `bt 40`. Frame 15 always names the format string
and frames 17–19 the site:

* **`draw_cursor`** — `#15 __printf_buffer (… format=0x55555569a6eb "%.*g%c" …)` →
  `#17 ___sprintf_chk` → `#18 draw_cursor ()` → `#19 draw_graph ()`.
* **`draw_cursor_difference`** — same, `#18 draw_cursor_difference ()`. Isolated by putting
  cursor 1 **outside** the plot box (`x2=1`, `cursor1_x=1e300`), which makes
  `draw_cursor`'s `if(xx >= gr->x1 && xx <= gr->x2)` skip while the difference still
  formats — **`draw_cursor_difference` has no such guard before its `sprintf`**.
* **`draw_hcursor`** — `format=0x55555569c8b4 " %.*g%c "`, `#18 draw_hcursor ()`.
* **`draw_hcursor_difference`** — same format string; the frame reads `#18 draw_graph ()`
  because `-O2` inlines it (no symbol in `nm`). Isolated with `hcursor1_y=1e300` outside the
  y range and `hcursor2_y=0`, so `draw_hcursor` prints a short `0T` and only the difference
  is long.
* **`waves_callback`** — `format="%.*g%c"`, `#18 waves_callback.isra ()` → `#19 callback ()`.
  Driven with `xschem callback .drw 2 <cx> <cy> 77 0 0 0` (the `M` key, which toggles
  `graph_flags & 64`) followed by `xschem callback .drw 6 <cx> <cy> 0 0 0 0` (MotionNotify).
  At `ev_precision=4` it prints `measure_text=y=3.479e+287T / x=4.439e+287T`; at 200 it
  aborts.

### The fixture

Hermetic, no ngspice, the `test_wave_markers.tcl` incantation (which is the fixture I
reused rather than building one):

```tcl
xschem raw new f.raw dc vsweep 0 1e300 1e299
xschem raw add v_a {vsweep 1 *}
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph
node=v_a
unitx=T
unity=T
x1=0
x2=1e300
y1=-1e300
y2=1e300} 0
xschem zoom_full
xschem cursor 1 1 ; xschem set cursor1_x 1e300
xschem redraw
```

Two things about it are load-bearing and neither is in the plan:

* **`unitx`/`unity` must be non-1.0 or the `sprintf` arms are never taken.** All four
  `draw.c` cursor sites and both `callback.c` sites sit under `if(gr->unitx != 1.0)` /
  `if(gr->unity != 1.0)`; the `else` arms call `dtoa_eng(…, 5)` with a **hardcoded** 5 and
  are safe. `unitx=T` → `get_unit()` 1e-12.
* **the *value* must have many exact decimal digits, not merely be large.** `%g` strips
  trailing zeros, so `1e15` prints as `1000000000000000` at any precision. The T branch of
  `dtoa_eng` (and a `1e300` cursor) works because the double nearest `1e288` is an exact
  integer with ~289 significant digits. A sweep of `0..1` with `unitx=f` does **not**
  reproduce.

### The `callback.c` tooltip aborts on BOTH branches

With `unitx`/`unity` removed the tooltip takes `my_strncpy(sx, dtoa_eng(xval,
xctx->ev_precision), S(sx))` at `callback.c:2430`/`:2435` — i.e. straight into the 80-byte
`dtoa_eng` buffer. Measured: 71 and 72 survive (the readout grows to 100+ visible chars),
**73 aborts, rc 134**. So there is no safe branch in that block.

### The `dtoa_eng` call sites — the plan's count is off

Real `dtoa_eng` call sites at `34913077`: **24**, not 27 (`grep -c` counts a comment in
`draw.c` and the definition + a `dbg()` in `editprop.c`). Of the 24:

* **13 pass `xctx->ev_precision` directly** — `token.c` ×7 (`:6131 :6283 :6671 :6775 :6879
  :6948 :7084`) and `callback.c` ×6 (`:2430 :2435` in the tooltip, plus **`:2631 :2661
  :2686 :2701`**, the four `input_line {Pos:}` cursor-position dialogs — the plan does not
  mention these four at all);
* **1 passes `engineering`** (`eval_expr.c:1602`), which `kklex()` sets to
  `xctx->ev_precision` for `expr_eng(...)`;
* **10 in `draw.c`**: eight pass a hardcoded `5`, two (`:7752 :7874`) pass the clamped
  `prec`.

**One `token.c` site driven end to end**, headless: `@spice_get_node` (`token.c:6283`).

```
prec=4    translate len=7     rc=0
prec=71   translate len=78    rc=0
prec=72   translate len=79    rc=0
prec=73   *** buffer overflow detected ***: terminated   rc=134
```

Fixture: hermetic raw with `xschem raw add v_big {vsweep 1e300 *}`, a graph rect on it,
`xschem redraw` (to refresh `xctx->ev_precision` via `draw()`), `xschem cursor 2 1`,
`xschem set cursor2_x 1.0`, then `xschem translate -1 {@spice_get_node v_big}`.
The other six `token.c` sites are **not-driven**: same callee, same argument expression,
and each needs its own instance/net fixture (`@spice_get_voltage`, `@spice_get_current`,
`@spice_get_diff_voltage`). The four `input_line {Pos:}` sites are **not-driven** (they need
a real key event in a graph on a display).

---

## 4. `show_node_measures` is REACHED, and its 1024-byte buffer can never overflow

"Survived" would be a vacuous result if the site were simply not reached, so I sabotaged it:
`draw.c:5229`, `char tmpstr[1024] = "";` → `char tmpstr[16] = "";`, rebuilt, ran the same
fixture with `vlegend=1 legend=1 unity=T` and cursor 1 on a sample:

```
#### SABOTAGED tmpstr[16], prec=4    -> dc=4, SURVIVED, rc=0
#### SABOTAGED tmpstr[16], prec=200  -> *** buffer overflow detected ***: terminated, rc=134
```

So the site **is** exercised on that path, and the 1024 bytes are the only thing protecting
it. Restored with `cp` + rebuild; `md5sum src/draw.c` = `290cb8e65ec0d11a979ebd5213a31e64`,
matching `HEAD`, and the unsabotaged binary survives at 200 again.

Why 1024 is nevertheless enough — see §6: `%.*g` can never emit more than **774**
characters, whatever the precision, because it strips trailing zeros and a `double`'s exact
decimal expansion has at most 767 significant digits.

⚠ **But that safety is one token deep.** `show_node_measures` also owns the tree's only
`%.*e` pair (`fmt1`/`fmt2` at `draw.c:5268`/`:5269`), and `%e` **zero-pads** to exactly P
fraction digits, so the 774-char cap does not apply to it. It is safe today only because
that arm sets `prec = 2` three lines above. Moving or deleting that `prec = 2` turns a
1024-byte buffer into a one-line abort at precision 1015. A fence here should hold the
`%.*e` arm, not just the `%.*g` one.

⚠ **And the format string at that site is a `char *`, not a literal.** A static row that
greps for `"%.*g"` near `show_node_measures` will not match `sprintf(tmpstr, fmt2, prec, …)`.
This is the same class of trap the brief warns about, in a new shape.

### `graph_marker_fmt`: the clamp holds

Driven through the real verb (`xschem graph_marker add_at 0 0 0 10` then
`xschem graph_marker text 1`) on the display arm at `ev_precision` 4, 17, 200 and **4000**:
all four return `M1:1e+288T,1e+288T`, rc 0. The `T` suffix proves the `sprintf` arm at
`draw.c:7750` ran (the `else` arm appends no suffix). The identical output at 4 and 17 is a
genuine coincidence of the value, not a sign the precision is ignored — verified in
isolation: `printf("%.17g", 5.0000000000000004e299 * 1e-12)` is `5e+287`, because the
17-digit rounding is exactly `5.0000000000000000e+287` and `%g` strips the zeros.
The `if(prec > 17) prec = 17;` at `draw.c:7834` and its comment are accurate; at 17 the
worst output is 25 chars into the callers' `char[80]`. **Latent only**, exactly as the
issue re-classified it — and the signature still lies, because the `sprintf` arm ignores
`destsize` while the `else` arm honours it.

---

## 5. The writers — all confirmed, and there are more than the issue names

Each line below was proved by running it and watching `ev_precision` arrive (and, where the
value is 200 and a formatter follows, abort with rc 134).

| writer | proved by | result |
|---|---|---|
| `--preinit 'set ev_precision N'` | `./src/xschem --nogui --pipe -q --preinit "set ev_precision 73" --script repro.tcl` | `ev_precision=73`, **rc 134** |
| **`~/.xschem/xschemrc`** | see the trap below | `Sourcing …/rchome/.xschem/xschemrc init file` / `ev_precision=200` / **rc 134** |
| **`./xschemrc` in the CWD** — *not in the issue* | `cd <projdir>` with `xschemrc` = `set ev_precision 200`, `XSCHEM_SHAREDIR=<share>` | `Sourcing …/proj/xschemrc init file` / **rc 134** |
| **`--rcfile <path>`** — *not in the issue* | `./src/xschem --nogui --pipe -q --rcfile <f> --script repro.tcl` (works in-tree) | `Sourcing …/proj/xschemrc init file` / `ev_precision=200` / **rc 134** |
| any Tcl in a `--script` | trivially | — |
| **a `tcleval` property inside a `.sch`** | §6 below | **rc 134** |
| **a `tcleval` property inside a `.sym`** | §6 below | `ev=200` after `xschem netlist` |

### ⚠ A TRAP that will make a naive test row pass vacuously

**An in-tree run never sources `~/.xschem/xschemrc` or `./xschemrc`.** `xinit.c` gates both
on `if(!running_in_src_dir)`, and `running_in_src_dir` is 1 whenever `XSCHEM_SHAREDIR`
contains `xschem.tcl` **and** `systemlib` **and** an executable named `xschem` — which is
exactly `src/`. My first attempt at the rc test therefore printed `ev_precision=4` and
looked like a refutation.

The way to test it: build a sharedir that is `src/` **minus the binary** —

```sh
mkdir share; for f in src/*; do [ "$f" = src/xschem ] || ln -s "$PWD/$f" share/; done
HOME=$throwaway XSCHEM_SHAREDIR=$PWD/share ./src/xschem --nogui --pipe -q --script repro.tcl
```

— or use `--rcfile`, which is honoured in-tree. A Stage C row that "sets `ev_precision` from
an rc file" and runs in-tree measures nothing.

### There is no fifth C-side writer

`/usr/bin/grep -n 'ev_precision' src/*.c src/*.h src/*.y src/*.tcl` gives exactly four
assignments to `xctx->ev_precision`: `xinit.c:761` (the initial 4), `draw.c:9011` (in
`draw_graph()`), `draw.c:10595` (in `draw()`), and **`eval_expr.y:258` / `eval_expr.c:1707`
(in `kklex()`)**. `draw.c:7830` reads the Tcl var without writing the field, and clamps.
Nothing calls `tclsetintvar("ev_precision", …)`.

`draw.c:9011` is **not** redundant with `draw.c:10595`: `draw_graph()` has independent
callers at `callback.c:2402`, `callback.c:3607` and `scheduler.c:3621`, none of them through
`draw()`.

---

## 6. FILE-BORNE: **YES.** A `.sch` can set `ev_precision`, and a `.sym` can too

This is the severity-deciding answer the driver asked for, and it is **yes**.

`tcl_hook2()` (`token.c`) passes any string that *starts with* `tcleval(` to
`tclpropeval2` (`xschem.tcl`), whose body is `uplevel #0 "subst \{$s\}"`. `subst` performs
**command** substitution, at global level. So a `[...]` inside a file's `tcleval(` property
runs arbitrary Tcl.

### Fixture that works, and the two that do not

**Does NOT work:** a plain `T {tcleval(...)}` text, and a schematic-level `G {tcleval(...)}`
property. Both were loaded, redrawn, netlisted and SVG-exported with no effect; the SVG
rendered the text **literally** (`>tcleval([set ::ev_precision 200]POISONED)<`). A text is
only `tcleval`'d when it carries `TEXT_FLOATER`, which `actions.c` sets from a `name=` or
`floater=` attribute on the text.

**Does work** — `t_float.sch`, eight lines, no symbol library, no raw file:

```
v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
T {tcleval([set ::ev_precision 200]POISONED)} 0 0 0 0 0.4 0.4 {floater=true}
```

```
before load: ev=4
after load:  ev=4
svg:                      <- xschem print svg out.svg
after svg:   ev=200
```
and the SVG contains `>200POISONED<`. ⚠ Use `"` not `{}` inside the `tcleval(` — braces
break both the `.sch` `T` record parse (`WARNING: missing fields for TEXT object`) and
`tclpropeval2`'s `subst {…}`.

### The landmine version: the file sets nothing but the precision, and ORDINARY work aborts later

This is the one that matters, because it separates "the file called `exit`" from "the file
armed a bomb". The file above does **only** `set ::ev_precision 200`. Everything after
`step2` is ordinary editor work on a hermetic fixture the file never mentions:

```
step1 ev=4
step2 after opening someone else's schematic: ev=200
step3 about to read the annotation the cursor published
*** buffer overflow detected ***: terminated
rc=134
```

(`step3` is `set ::ngspice::ngspice_data(v_a)` after `xschem raw new` + a graph rect +
`xschem cursor 2 1` + `xschem set cursor2_x 0.5` — i.e. place a cursor, read the
annotation. `save.c:2904`.)

### And the same file can abort during its own export

```
T {tcleval([set ::ev_precision 200]cfg)} 0 0 0 0 0.4 0.4 {floater=true}
T {tcleval([xschem eval_expr "expr_eng(1e300*1.0)"])} 0 100 0 0 0.4 0.4 {floater=true}
```
`xschem load` + `xschem print svg` → `*** buffer overflow detected ***: terminated`,
**rc 134**, headless, with no user action beyond opening and exporting.

### A `.sym` does it too, through `xschem netlist`

`poison.sym` with `K {type=resistor format="tcleval([set ::ev_precision 200]* poisoned)" …}`,
instantiated by absolute path from a one-instance `.sch`:

```
after load:    ev=4
netlist: 0
after netlist: ev=200
```

(`format1 && strstr(format1, "tcleval(") == format1` → `tcl_hook2`, at `token.c:2063`
and `:2224`.) Note the sharper implication: **netlisting someone else's symbol library is
enough**; you never have to look at the schematic.

### Generators

`is_generator()` symbols are run with **`popen()`** (`save.c:7368`), i.e. an external
process, so a generator cannot write `ev_precision` in-process — but its *output* is a
`.sym` stream, so it reaches the same vector as above. Not driven separately.
`save.c:8393` additionally passes an instance **name** through `tcl_hook2`, which is a third
file-borne `tcleval` entry point.

**So the issue's severity is understated.** It files three writers, all of which are the
local user's own configuration. In fact **opening or netlisting a file someone else wrote is
enough**, and the natural real-world carrier is a PDK or design kit that ships its own
`xschemrc` next to the cells.

⚠ **Carried forward, NOT fixed, and bigger than 1606:** the same `tcleval` mechanism gives a
`.sch`/`.sym` **arbitrary Tcl execution at global level** on open/draw/netlist, and a
generator name gives arbitrary **shell** execution via `popen`. That is a design property of
xschem (documented as a feature), not a regression, and it is far outside this issue — but
it is why "a config file can set it" in the issue title is the *narrow* framing. Named here
so the next reader does not have to rediscover it; no number minted.

---

## 7. The width arithmetic, from first principles, and it agrees with 71

Let P be the precision (glibc treats P = 0 as 1) and let the value be a `double`.

**`%.*g`.** glibc picks e-style when the decimal exponent X is < −4 or ≥ P, else f-style,
and strips trailing zeros (no `#`).

* e-style: `[-] d . (P−1 digits) e ± ddd` = sign(1) + 1 + point(1) + (P−1) + `e`(1) +
  expsign(1) + expdigits(3) = **P + 7 characters**. Three exponent digits is the maximum a
  `double` can reach (308 / 324).
* f-style: X < P bounds the integer part at P digits; X ≥ −4 bounds the leading zeros at
  `0.000`. Worst case = sign(1) + 1 + point(1) + 4 + P = **P + 6**, always narrower.
* So **`%.*g` ≤ P + 7 chars**, i.e. **P + 8 bytes** with the NUL.
* **A second, independent bound**, which the issue does not state and which decides the
  1024-byte sites: because `%g` strips trailing zeros it can never print more significant
  digits than the value's **exact** decimal expansion has. For a `double` the longest is
  `(2^52 − 1) · 2^−1074`, at **767** significant digits, so `%.*g` never exceeds
  1 + 1 + 1 + 766 + 5 = **774 characters at any precision whatsoever**.
  Measured by exhaustive search over P = 1..4000 against six extreme doubles: `max %g chars
  = 774 at P=767`.

**`%.*e`.** `%e` pads with zeros to exactly P fraction digits, so the 774 cap does **not**
apply: `[-] d . (P digits) e ± ddd` = **P + 7 characters**, growing without limit in P.

Add each site's trailing literals and the NUL. The right-hand columns are the largest P that
is safe for **every** sign and exponent; they were also re-derived by exhaustive search in a
standalone C program, and the two methods agree exactly.

| format | chars | bytes | **80** | **100** | **1024** |
|---|---|---|---|---|---|
| `"%.*g"` | P + 7 | P + 8 | **72** | **92** | any P (max 775) |
| `"%.*g%c"` | P + 8 | P + 9 | **71** | **91** | any P (max 776) |
| `"%.*gMEG"` | P + 10 | P + 11 | **69** | **89** | any P |
| `" %.*g%c "` | P + 10 | P + 11 | **69** | **89** | any P |
| `"%.*e%c"` | P + 8 | P + 9 | **70** | **90** | **1014** |

**Does it agree with the issue's swept 71? Yes, exactly.** `dtoa_eng`'s hot line is
`sprintf(s, "%.*g%c", precision, i, suffix)` into `static char s[80]`, row two: **71**. And
the sweep matches byte for byte — at P = 71 a negative T-branch value is 79 chars (80 with
the NUL, the buffer exactly full), and P = 72 aborts.

**Where the issue is wrong:** *"`draw.c`'s `char tmpstr[100]` overflows at 92 by the same
arithmetic."* That is the **positive-value** last-safe figure for two of the four `draw.c`
sites (`draw_cursor`, `draw_cursor_difference`: measured 92 safe, 93 aborts) and wrong for
the other two, which carry two extra spaces in `" %.*g%c "` (`draw_hcursor`,
`draw_hcursor_difference`: measured 90 safe, **91 aborts**). The all-signs ceilings are
**91** and **89**. `save.c:2904`'s bare `"%.*g"` measured 93 safe / **94 aborts** (positive);
all-signs ceiling **92**.

This is the arithmetic behind G2's recommended shape, and it supports it: **one helper that
takes the buffer size returns five different numbers for five different format strings in
this tree, and no single global constant is right for all of them.** A global 71 would
under-serve `nd_view_set` by 21 digits and over-serve `draw_hcursor` — that is,
`ev_precision=90` would still abort `draw_hcursor` under a global-71 clamp only if the clamp
were applied at the writer and the writer's ceiling were the loosest; clamping the writers to
**69** (the tightest row) is the only single number that is safe everywhere, and it is
tighter than the dialog's 71, i.e. it would contradict 1602.

⚠ **That is a real conflict for Stage B to resolve and it is not in the plan:** 1602's
dialog ceiling is **71**, but `" %.*g%c "` into `char[100]` and `"%.*gMEG"` into `char[80]`
both need **69**. A writer-side clamp to 71 leaves `draw_hcursor` / `draw_hcursor_difference`
theoretically unsafe at 70 and 71 for a negative three-digit-exponent value. Per-buffer
clamping at the point of use (G2's recommendation) does not have this problem; a single
global does.

---

## 8. Other things that contradict the plan, the prediction or the issue

1. **G1 / plan: "`xctx->ev_precision` is written in exactly three places."** Four. §0, §2.
2. **G1: "the two unclamped writers are `draw.c:9011` and `draw.c:10595`."** Three, and
   the third (`kklex()`) is the one the reproducer goes through. A clamp at the two `draw.c`
   sites leaves `xschem eval_expr {expr_eng(1e300)}` aborting. §2.
3. **G1's own refutation clause, half-right:** `draw()` does **not** fail to run headless
   (`xschem redraw` reaches it, `drawcount` 0→1) — but the abort still does not come from it.
4. **Plan table: "`draw.c:~5276 draw_graph_variables`."** The function is
   **`show_node_measures`** (`draw.c:5225`), it holds **two** `sprintf`s (`:5274`, `:5275`),
   and its format strings are **variables** (`fmt1`/`fmt2`), so a literal-matching static row
   misses it. The real `draw_graph_variables` is not a site.
5. **Plan: "`dtoa_eng` … 27 call sites, of which 15 pass `xctx->ev_precision`."** 24 call
   sites; 13 pass it directly and 1 passes it as `engineering`. Issue 1602's "~70 call sites"
   is off by a factor of three.
6. **Plan/issue: the four `input_line {Pos:}` callers.** `callback.c:2631 :2661 :2686 :2701`
   each call `dtoa_eng(cursor, xctx->ev_precision)` and are in neither document.
7. **Issue: "`draw.c` ×2 (near `:4933` and `:4995`)."** The sites are `:4967` and `:4999`,
   and there are **four**, not two.
8. **Issue: "overflows at 92."** Two of the four do; the two with the spaces overflow at 91
   (positive) / 90 (all signs). §7.
9. **The 1024-byte sites cannot be overflowed via `%.*g` at all** — not because of a clamp
   but because of the `double`'s own 767-significant-digit ceiling. §4, §7. Their `%.*e`
   sibling **can** be, and is safe only by a `prec = 2` three lines away.
10. **`save.c:2904`'s comment is false, and now quantified:** *"100 bytes is ample for one
    `%g`"* — ample to precision 92, and the process aborts at 94 with a positive value.
11. **Option 3 is worse than G1 says, and I can name the mechanism.** `HAS_SNPRINTF` is
    indeed defined nowhere (`util.c:500` says so in terms), so `my_snprintf` is the
    hand-rolled formatter at `util.c:623`ff. Its float arm does
    `strncpy(nfmt, fmt, l); … nlen = sprintf(nstr, nfmt, i);` into **`char nstr[50]`**, with
    the length check applied only *after* the `sprintf` has already written. So teaching it
    `*` is not merely an API change: **any** float conversion wider than 49 characters
    overflows a 50-byte stack buffer inside `my_snprintf` itself, whatever the caller's
    buffer size. `"%.60g"` and `"%f"` of `1e300` (316 chars) both qualify.
    ⚠ **Carried forward, not fixed:** this is a latent stack overflow in `my_snprintf`'s
    `%g`/`%e`/`%f` arm, independent of `ev_precision`. The only live caller with a float
    conversion that could grow is `scheduler.c:8988` `my_snprintf(buf, S(buf), "%.6f", …)`
    on a bounded march offset, which is safe today. No number minted; it wants its own.

---

## 9. What I could not measure

* **`callback.c:2433` (`sy`) in isolation** — `sx` two lines above aborts first with the
  same expression, buffer and format string. Driving `sy` alone would need `unitx == 1.0`
  and `unity != 1.0`, and the `unitx == 1.0` branch then goes through `dtoa_eng`, which
  aborts even earlier (at 73).
* **Six of the seven `token.c` `dtoa_eng` sites**, and the four `input_line {Pos:}` sites.
  Same callee, same argument expression; each needs its own instance/net/key fixture.
* **A per-site threshold for `show_node_measures` and `graph_marker_fmt`** — there is none:
  both survive at every precision I could set (4000).
* **Whether `draw.c:9011` (`draw_graph()`'s writer) can poison anything that
  `draw.c:10595` (`draw()`'s) would not.** I proved it has independent callers by reading
  them (`callback.c:2402`, `callback.c:3607`, `scheduler.c:3621`); I did not stage a run in
  which only that writer fires.
* **The display arm on `:0` or on the user's real screen.** Everything display-side was
  measured on `:99`. For a memory-safety abort the server is irrelevant, but it is stated.

---

## 10. Suggestions for Stage B / Stage C, from what this stage measured

* A behavioural row needs **no display**: `--preinit 'set ev_precision 73'` +
  `xschem eval_expr {expr_eng(1e300*1.0)}` + assert rc **0** and a sane string. Assert the
  **exit code**, as the issue says. The negative twin (`-1e300*1.0`, ceiling 71) is one more
  line and it is the byte the issue's whole ceiling rests on.
* A second behavioural row with **no display and no `eval_expr`**: `xschem raw new` + a graph
  rect + `xschem redraw` + `xschem cursor 2 1` + `xschem set cursor2_x` + read
  `$ngspice::ngspice_data(<vec>)` at precision 94. That one exercises `draw()`'s writer and
  `save.c:2904` at once, and it reddens if a clamp lands only in `kklex()`.
* A third, if a file-borne fence is wanted: the eight-line `t_float.sch` above. It needs no
  library and no raw file.
* Any fence on `show_node_measures` must cover the **`%.*e`** arm and must not rely on a
  literal format string, because there is none.
* Any rc-file test row must NOT run in-tree (§5 trap), or it passes vacuously.
* `eval_expr.c` is **generated** and gitignored; a clamp there goes in `eval_expr.y`.
