# 0519 — the TCP command server kills the editor three ways, every one answers like success, and one of the three needs no socket

**Status:** OPEN. Filed 2026-08-20 by the voice/natural-language design pass
(`doc/claude/suggestions/voice_control_natural_language_plan.md`, §8 R1).
**RESCOPED 2026-08-20** after a second verification round, and the correction is
kept in the open because it is half the value of the file. The first two passes
filed defect **B** — the 4 KB action-log overflow — as a *TCP* defect, and said
in this paragraph that "an xschem that never enables it has zero exposure".
**That is false.** The overflow is in `log_action()` and is not gated on the port
at all: **pressing OK on the Header/License text dialog (Shift+B) with 4 KB of
text core-dumps a stock GUI xschem that has no socket and no `--logdir`** —
measured, `rc=-6`, in *Reproducer* leg B. (That leg uses a `--script` only as
the robot finger that presses the dialog's own OK button; a human pressing
Shift+B needs none.) The socket is one route in, and the one that makes it
remote and unauthenticated. Defects **A** and **C** are socket-only and are
unchanged. See *What earlier passes got wrong* for the full list — six further
corrections went with the rescope, five of them numbers.
**Branch:** `fluid-editing`, HEAD `722ce61e`, tracked tree clean.
**Binary:** `src/xschem` built 2026-08-19 18:16, no `.c` newer, so the C claim
(defect **B**) is about the shipped binary. The Tcl claims (**A**, **C**) are
about `src/xschem.tcl` as sourced at runtime — measured
`XSCHEM_SHAREDIR = <repo>/src`, so they need no rebuild to fix or to break.
**Area:**
* the channel — `setup_tcp_xschem` (`src/xschem.tcl:18035-18057`, the listener at
  `:18042`), the accept callback `xschem_server` (`:5923-5930`), the handler
  `xschem_getdata` (`:5851-5894` — `uplevel` at `:5865`, the `puts` rename pair at
  `:5866-5867`, the reply at `:5886-5889`);
* the rename — `redef_puts` (`:11612-11646`) and its **two** callers,
  `xschem_getdata` (`:5863`) and `tclcmd_ok_button` (`:11655-11680`, `redef_puts`
  at `:11660`, the same unconditional pair at `:11662-11663`);
* the nested loops — `alert_` (`:14095-14149`, `tkwait visibility` at `:14132`),
  and the C-side `tk_messageBox` calls at `src/scheduler.c:3594-3596`,
  `:3607-3609`, `:3637-3639`, `:3649-3651` and `src/xinit.c:2327`, `:2419`,
  `:2500`, `:2560`;
* the overflow — `log_action()` (`src/util.c:489-513`, `char buf[4096]` at
  `:491`, `vsprintf` at `:508`), reached from `src/scheduler.c:7814` (the
  socket's own logging) **and** from `log_action_argv()`
  (`src/callback.c:3436-3440`), whose callers include `src/scheduler.c:13145`
  (`xschem setprop instance`), `src/scheduler.c:12207` (`xschem set header_text`
  — the Header/License dialog, `src/xschem.tcl:4116-4120`, menu item `:17442`)
  and the Edit-Properties commit `edit_property()` → `:1868` →
  `log_prop_edit_one` (`src/editprop.c:1522-1571`) plus the global-attribute arm
  (`src/editprop.c:1720-1732`).
**Severity:** three defects, two exposure shapes. Defect **B** needs only an
action log that is open plus one formatted log line longer than 4095 bytes — and
the plain GUI configuration opens the log by itself (`xschem get
actionlog_filename` answers `/tmp/Xschem.log.N` with no flags at all). So it is
reachable by a user who has never heard of the TCP server, by pasting a license
into a dialog and pressing OK; it ends in SIGABRT with a core dump, and when
xschem was started the way a desktop launcher or a script starts it, with no
message anywhere (`src/main.c:130-136`). Defects **A** and **C** do need the socket, which is
off by default and has to be switched on; once it is on, both are reachable by
the *ordinary, documented* client with no privilege and no malice — one leaves
the process alive with its `puts` command destroyed and its command channel dead
forever, the other parks a modal grab over the editor while the socket keeps
mutating the schematic behind it. What makes them worse than three bugs is the
reply contract: `xschem_getdata` sends back the result of `catch`, which is the
*result* on success and the *error message* on failure, and never sends the
return code it computed one line earlier — so `error 42` and `expr {40+2}` come
back as the same two bytes and no client, in any language, can tell a completed
command from a dead editor.

---

## What happens

### First: defect B is not a socket defect

The buffer is `char buf[4096]` in `log_action()` (`src/util.c:491`) and the
unbounded write into it is `vsprintf(buf, fmt, args)` at `:508`. **Anything**
that formats an action-log line longer than 4095 bytes reaches it. The socket is
one caller among many, because `xschem_getdata` logs every command it receives
(`src/xschem.tcl:5879`/`:5882` → `src/scheduler.c:7814`).

Measured this run, each in its own process, **no `--tcp_port` anywhere**:

| how | result |
|---|---|
| `xschem setprop instance 0 {name=p0 <4000 x>}` from a plain `--script` | survives |
| `xschem setprop instance 0 {name=p0 <4200 x>}` from a plain `--script` | **`rc=-6`, `*** buffer overflow detected ***`** |
| `xschem set header_text <4072 bytes>` | survives |
| `xschem set header_text <4073 bytes>` | **`rc=-6`** |
| open **Header/License text** (Shift+B), paste 4200 chars, **press OK** | **`rc=-6`** |
| `--nogui` with no `--logdir` (`actionlog_filename` is empty) | survives — no log open, `:493` returns |
| `--nogui --logdir <d>`, `xschem log_action <4096 bytes>` | **`rc=-6`** |

The 4072/4073 boundary is the same 4095-byte one seen from the socket, minus the
23 bytes of `xschem set header_text ` that `Tcl_Merge` puts in front of the
value. The single gate is `if(!actionlog_fp || actionlog_suppress) return;`
(`src/util.c:493`) — an action log that is **open** is the whole precondition,
and `init_action_log()` opens one for every GUI start without being asked:
`if(!has_x && !cli_opt_logdir[0]) return;` (`src/util.c:351`), i.e. **has_x OR
`--logdir`**, with `--nolog` (`:344-350`) the one explicit opt-out.

Two siblings are **not** affected and it is worth saying so, because it narrows
where a fixer has to look: `log_action_noecho()` (`src/util.c:518-527`) and
`log_output()` (`:536-547`) write straight to the file with `vfprintf`/`fputs`
and have no `buf` at all. So the CIW-typed-line path is safe.

### The channel, and what a reply means

`setup_tcp_xschem` opens the listener:

```tcl
if {[catch {socket -server xschem_server $xschem_listen_port} err]} {
```
— `src/xschem.tcl:18042`

There is no `-myaddr`, so Tcl binds every interface. Measured with `ss -ltn`
against a live `--tcp_port` instance:

```
LISTEN 0 4096 0.0.0.0:49054 0.0.0.0:*
LISTEN 0 4096 [::]:49054 [::]:*
```

Measured again this round against a live instance, `xschem get instances`
answering `117` every time: on `127.0.0.1`, on `::1`, on this host's LAN address
`192.168.0.190`, and on **all three of its global IPv6 addresses** (routable
`2600:…` addresses, redacted here). Nothing about the listener is
loopback-only.

`xschem_server` (`:5923-5930`) records the peer and arms the handler; it never
inspects the peer. It also sets the socket **non-blocking**, which matters below:

```tcl
  fconfigure $sock -buffering line -blocking 0
  set xschem_server_getdata(addr,$sock) [list $addr $port]
  set xschem_server_getdata(line,$sock) {}
  fileevent $sock readable [list xschem_getdata $sock]
```
— `src/xschem.tcl:5926-5929`

`xschem_getdata` drains the readable lines and evaluates them:

```tcl
  redef_puts
  xschem log_action -reset
  set tcp_rc [uplevel #0 [list catch $xschem_server_getdata(line,$sock) tclcmd_puts]]
  rename puts {}
  rename ::tcl::puts puts
```
— `src/xschem.tcl:5863-5867`

and replies with the variable `catch` wrote:

```tcl
  set xschem_server_getdata(res,$sock) "$tclcmd_puts"
  puts -nonewline $sock "$xschem_server_getdata(res,$sock)"
```
— `src/xschem.tcl:5886-5887`

`catch script varName` sets `varName` to the result on success **and to the
error message on failure**. `tcp_rc` at `:5865` holds the 0/1 that distinguishes
them, and is used only to decide how the line is written to the action log
(`:5874-5884`); it is never sent. Measured, on the shipped binary:

| sent | reply |
|---|---|
| `expr {40+2}` | `42` |
| `error 42` | `42` |
| `xschem get version` | `3.4.8RC` |
| `xschem nosuchverb` | `xschem nosuchverb: invalid command.` |
| `xschem wire 950 0 950 100` | *(empty)* |

Empty is a normal success reply, so "the process just died" and "the command
worked" share a representation too.

**`redef_puts`'s capture never reaches the wire.** It sets `tclcmd_puts {}`
(`:11614`) and installs a `puts` that appends to it (`:11635`), and then
`catch … tclcmd_puts` overwrites the whole variable. Measured:
`puts $XSCHEM_LIBRARY_PATH` answers **the empty string**, and
`puts hello; expr 1+1` answers `2`. That is the exact example
`doc/xschem_man/xschem_remote.html:39` gives for what the interface does
(*"will print the content of the `XSCHEM_LIBRARY_PATH` tcl variable"*), so the
rename pair at `:5866-5867` is buying nothing on this path — a fact that matters
under **Fix**, because that pair is what defect **A** is made of.

### Is it on?

Off by default: `int tcp_port = 0;` (`src/globals.c:215`), and `src/xschemrc:573`
ships the variable **commented out** (`# set xschem_listen_port 2021`), as does
the user rc in this workarea. It is turned on by, in the order a user meets them:

* `--tcp_port N` on the command line (`src/options.c:113-116`, value consumed at
  `:249-251`, applied in `src/xinit.c:3373-3379`, which refuses `N < 1024` with a
  message and otherwise sets `xschem_listen_port`);
* uncommenting `set xschem_listen_port <N>` in an xschemrc;
* `setup_tcp_xschem <port>` from any Tcl at any time — a `--script`, a
  `tcl_files` preload, the CIW entry, or an earlier socket command.

**How many users have it on is not measurable from here and this issue does not
claim a number.** What can be said: it is opt-in, it is nobody's default, and it
is the interface `doc/xschem_man/xschem_remote.html` documents as *the* way to
drive xschem from another program — including the `xschem -b &` +
`echo … | nc localhost 2021` recipe at `:69-76`. Anyone automating xschem is a
user of it. **None of that gates defect B**, per the section above.

### When the wedge fires

A wedge (**A**, and the tail of **C**) needs two things at once: a command that
**spins a nested event loop**, and **some socket event serviced inside that
loop**. There are two independent ways to supply the second, and an earlier pass
of this issue knew only the first and wrongly wrote it up as a requirement:

1. **The same connection goes readable.** The socket is non-blocking, `gets`
   returns −1 at EOF exactly as it does on a partial line, and the `fileevent`
   is never disarmed — so a client that stops writing makes its own handler
   re-fire from inside the nested loop. `shutdown(SHUT_WR)` does it, and so does
   this tree's own TCP test:

   ```tcl
     puts $s $cmd
     flush $s
     close $s w                            ;# half-close: server reads to EOF
   ```
   — `tests/headless/test_stdin_tcp_log.tcl:98-100`

   Measured, three runs each, on the one-liner `set ::w 0; incr ::w; update; set ::w`:

   | client | half-closes? | reply | next command |
   |---|---|---|---|
   | python, holds the connection open | no | `1` | **ok** |
   | plain `echo … \| nc localhost P` | no *(verified: a second `recv` on a listener times out)* | `1` | **ok** |
   | python, `shutdown(SHUT_WR)` | yes | `1` | **wedged** |
   | `nc -N` | yes *(verified: second `recv` returns `b''` at 0 ms)* | `1` | **wedged** |
   | `nc -q1` | yes *(same)* | `1` | **wedged** |

2. **A different connection is accepted and serviced.** No half-close anywhere.
   One command that blocks in a nested loop, any other client during it, and the
   unwind destroys `puts` just the same. Measured with **plain `nc` for every
   client** — the recipe in xschem's own manual — in *Reproducer* leg A:
   `alert_ {…} +400+400 0` held open on conn1, `xschem get wires` → `91` on
   conn2 *during the modal*, `destroy .alert` on conn3, and then conn4/conn5
   both time out with the process still alive.

So the honest statement is not "the wedge needs a half-closing client". It is
**the wedge needs a nested loop plus concurrency, and the socket supplies the
concurrency by itself.** Half-close is only what lets a *single* connection be
its own second event.

---

### A — a nested event loop destroys `puts`, and the channel is dead forever

One line does it:

```
set ::w 0; incr ::w; update; set ::w         hc ->      19 ms  '1'
xschem get version                              ->    4005 ms  'TIMEOUT'
xschem get wires                                ->    4008 ms  'TIMEOUT'
process alive, stdout 0B stderr 0B
toplevels on :99: Info window [Toplevel], Application Error [ErrorDialog], xschem [3] - mos_power_ampli.sch [Tk], xschem CIW - /tmp/Xschem.log.8 [Toplevel]
```

The reply is **`1`, the correct answer**, in 19 ms. Every later connection is
accepted and never answered. The process stays alive.

**Mechanism, measured exactly.** `redef_puts` guards its *entry*:

```tcl
  if ![llength [info command ::tcl::puts]] {
    rename puts ::tcl::puts
```
— `src/xschem.tcl:11615-11616`

so a nested call is a no-op. The *exit* at `:5866-5867` is unconditional, and
every nested frame runs it. Instrumented (a `bgerror` that logs to a file, and
`exec` to count entries, because by then there is no `puts` to write with):

```
incr ::d; ...; update; ...; set ::d          hc ->     246 ms  '250'
handler entered 250 times, unwound 250 times
249 background errors:
   248 x  can't delete "puts": command doesn't exist | ::puts= ::tcl::puts=
     1 x  can't rename "::tcl::puts": command doesn't exist | ::puts= ::tcl::puts=
```

The deepest frame deletes the capture proc and restores the real `puts` —
correctly, and it is the one that answers the client. The frame below it then
deletes the **real** `puts` and fails to rename a `::tcl::puts` that is already
gone. Every frame below *that* fails on `rename puts {}`. So of *N* frames,
exactly *N* − 1 can fail and exactly one of those failures is the `rename
::tcl::puts` form — a structure that held in all seven runs of this leg on this tree, at
*N* = 250 six times and *N* = 249 once — and an independent re-verification of
this file on the same tree also landed on 249. **The depth itself is not a
constant** — see the note under the pasted output, and *Coverage*, which forbids
asserting it. Afterwards `info commands ::puts` and `info commands ::tcl::puts`
are **both empty**, permanently: `redef_puts` on the next connection cannot even
start (`can't rename "puts": command doesn't exist`), so no reply is ever written
and no socket is ever closed.

Every `puts` anywhere else in the Tcl layer is dead too. Counted with python
over `src/*.tcl` (`(?<![-_A-Za-z0-9:.])puts(?![-_A-Za-z0-9])`): **407
occurrences on 404 lines across 19 files, 313 of those lines in
`src/xschem.tcl`**. That is a raw token count over the shipped sources including
comment lines; excluding lines whose first non-blank character is `#` it is
212/212/14, with 164 in `src/xschem.tcl`. Either way the answer to "how much of
the GUI still works" is "whatever never prints".

With Tk's own `bgerror` in place (i.e. with no instrumentation) what the user
gets is a dialog reading **`Error: can't delete "puts": command doesn't exist`**,
class `bgerrorDialog`/`ErrorDialog`, over a schematic that still draws.

**`update` is not the interesting trigger.** `alert_` is:

```tcl
  pack .alert.b1 -side left -fill x -expand yes
  if {$yesno} {pack .alert.b2 -side left -fill x -expand yes}
  tkwait visibility .alert
```
— `src/xschem.tcl:14130-14132`

`tkwait visibility` is **unconditional** — it is 15 lines above the
`if {!$nowait} {tkwait window .alert}` at `:14147` that is supposed to be the
blocking half. So *every* alert spins a nested event loop, including the
`nowait 1` ones whose entire point is not to block. Verified by driving the
"don't wait" form down the socket:

```
alert_ {0519} +200+300 1                     hc ->       6 ms  'window name "alert" already exists in parent'
xschem get version                              ->    4005 ms  'TIMEOUT'
```

The reply is itself the proof of re-entry: the nested frame re-evaluated the
same line and tried to build `.alert` a second time. And the blocking form
(`nowait 0`) wedges the same way with **no half-close at all** — leg A's plain-`nc`
sub-leg above.

Size of the trigger surface. Counted with python over `src/*.tcl`, token match
`(?<![-_A-Za-z0-9:.])<tok>(?![-_A-Za-z0-9])`:

| token | occurrences | files |
|---|---|---|
| `update` | **77** (81 by a loose `\bupdate\b`) | 8 |
| `tkwait` | 62 | 4 |
| `vwait` | 26 | 7 |
| `tk_messageBox` | 37 | 6 |
| `tk_getOpenFile` / `tk_getSaveFile` / `tk_chooseDirectory` | 12 / 6 / 3 | 4 / 1 / 2 |
| `alert_` | **43** in `src/*.c`, 21 in `src/*.tcl` | 8 C files, 2 Tcl files |

**Count these with python, not with the `grep` on this box.** It is ugrep 7.8.4,
and the ERE the first two passes used —
`grep -ohE "(^|[^-_[:alnum:]:.])puts([^-_[:alnum:]]|$)" src/*.tcl | wc -l` —
silently returns **0** for `puts` while returning a correct 77 for `update`. That
is how the "397 / 395 / 18 / 308" in the previous revision of this section came
to be; no counting method reproduces it.

**It is not X-dependent.** The same wedge reproduces under `--nogui`, where
there is no Tk at all — `update` is a Tcl command. There the nesting runs past
Tcl's interpreter recursion limit instead of stopping around 250, and the
*reply itself* is the error. Measured, one `--nogui` instance armed with
`setup_tcp_xschem <P>` and parked on a `vwait`:

```
A  plain            : '1 42'
B  update, no hc    : '1'
C  probe            : '1 42'
D  update, HALFCLOSE: 'too many nested evaluations (infinite loop?)'
E  probe after      : 'TIMEOUT'
```

with the unwind visible on the process's stderr:

```
can't rename "::tcl::puts": command doesn't exist
    while executing
"rename ::tcl::puts puts"
    (procedure "xschem_getdata" line 17)
...
can't rename "puts": command doesn't exist
    while executing
"rename puts ::tcl::puts"
...
    (procedure "redef_puts" line 4)
```

Legs A/B/C answer correctly and leave the channel healthy; D wedges it. So a
headless regression leg needs no display and no Tk — which is what makes
*Coverage* items 3-7 cheap.

---

### B — a 4 KB action-log line aborts the process, core dumped, socket or no socket

Over the socket, the boundary is exact:

```
command of 4095 bytes                           ->       3 ms  '4081'     (4095 bytes, last safe)
command of 4096 bytes                           ->     358 ms  ''     (4096 bytes)
xschem get version                              ->       2 ms  'CONNREFUSED'
process DEAD rc=-6, stdout 0B stderr 0B
```

**4095 bytes is fine; 4096 bytes is SIGABRT** (`rc=-6`, `core dumped` in the
shell's job report), the reply is the empty string, and the next connection is
refused. On the *failure* path the threshold is 10 bytes lower — measured, a
4085-byte invalid command answers `invalid command name "nosuchcmd"` and a
4086-byte one aborts — because `xschem_getdata` logs the failed form as
`"# failed: $tcp_cmd"` (`src/xschem.tcl:5879`, prefix 10 bytes). **Note this
leg needs no half-close**: every client in it holds its connection open.

Off the socket, the same buffer is reached by every caller that formats a long
line, and the prefix each one adds moves the boundary by exactly its own length:

* `xschem setprop instance <ref> <prop>` self-logs at `src/scheduler.c:13145`
  (`log_action_argv(argc, argv)`, gated instance-only). A 4200-byte property
  aborts from a plain `--script`. gdb on that exact command, same binary:

  ```
  #6  __GI___fortify_fail (msg=… "buffer overflow detected") at ./debug/fortify_fail.c:24
  #7  __GI___chk_fail () at ./debug/chk_fail.c:28
  #12 __vsprintf_internal (…) at ./libio/iovsprintf.c:62
  #13 0x000055555562986e in log_action ()
  #14 0x000055555556a54e in log_action_argv ()
  #15 0x00005555555f8eb6 in xschem_cmds_s.constprop ()
  #16 0x0000555555609273 in xschem ()
  #17 0x00007ffff7ac42de in TclInvokeStringCommand () from …/libtcl8.6.so
  #21 0x00007ffff7b73e70 in Tcl_EvalFile () from …/libtcl8.6.so
  ```

  with frame 10 showing the formatted string
  `"xschem setprop instance 0 {name=p0 ", 'x' <repeats 165 times>…, count=4236`.
  No socket in the frame list.
* `xschem set header_text <text>` self-logs at `src/scheduler.c:12207`. This is
  the **Header/License text** dialog — `update_schematic_header`
  (`src/xschem.tcl:4115-4120`), menu item with accelerator **Shift+B**
  (`:17442`). Measured boundary **4072 safe / 4073 fatal**, and measured
  end-to-end by opening the dialog on `:99`, inserting 4200 characters into
  `.dialog.textinput` and invoking its own OK button (`.dialog.f1.b1`):
  `rc=-6`, `*** buffer overflow detected ***`. A pasted Apache-2.0 header is
  ~11 KB; GPL-3.0 is ~35 KB.
* The Edit-Properties commit logs the edited object's **whole property string**:
  `edit_property()` → `src/editprop.c:1868` → `log_prop_edit_replayable` →
  `log_prop_edit_one` (`:1522-1571`), which emits
  `xschem setprop <type> <ref> allprops {…}` per selected object; and the
  no-selection arm logs `xschem set schprop {…}` — the schematic's whole global
  attribute block — at `:1720-1732`. **Read, not fired**: both are behind
  `if(!has_x) return;` (`src/editprop.c:1595`) and a modal dialog, and the
  measured GUI leg above is the header dialog, not these. They are the same
  `log_action_argv` → `log_action` pair and the same 4095-byte ceiling.

Path from the socket: `xschem_getdata` logs the received line after evaluating
it (`src/xschem.tcl:5879` on the failure arm, `:5882` on the success arm) →
`src/scheduler.c:7814`:

```c
      else if(argc > 2) log_action("%s", argv[2]);
```

→ `log_action()`, `src/util.c:489-513`:

```c
  char buf[4096]; /* pane copy only; the file write below is unbounded */
  …
#ifdef HAS_SNPRINTF
  vsnprintf(buf, S(buf), fmt, args);
#else
  vsprintf(buf, fmt, args); /* action lines are short xschem commands */
#endif
  va_end(args);
  /* the CIW entry already echoed the typed line; suppress the mirror then */
  if(!actionlog_suppress_echo) log_action_echo(buf);
```
— `:491`, `:505-512`

`HAS_SNPRINTF` is **not defined on this build**: zero hits in `config.h` and in
`Makefile.conf`, so `:508` is the live line. The comment is right that the file
write above it (`vfprintf`, `:498`) is unbounded and safe — the 4096-byte buffer
is only the CIW pane mirror.

Isolated by bisection down the same function, over the socket:

| first command sent | then a 4096-byte command |
|---|---|
| `xschem log_action -suppressecho 1` (skips the echo at `:512`) | **still aborts** — the `vsprintf` at `:508` runs first |
| `xschem set actionlog_suppress 1` (returns at `:493`) | **survives**, answers `4082` |

**The action log is on in the plain GUI configuration** — no `--logdir` was
passed in any GUI run above and `xschem get actionlog_filename` answered
`/tmp/Xschem.log.N` every time — so `actionlog_fp` is non-NULL and `:493` does
not return early. The two measured shapes that are immune are `--nogui`
*without* `--logdir` (the filename is empty, so `:493` returns) and an explicit
`xschem set actionlog_suppress 1`; add `--logdir` to the first and it aborts
again.

**The security shape, plainly: this is a memory-corrupting defect, and over the
socket it is also unauthenticated and remote-reachable.** A single line of text
on a socket that binds `0.0.0.0` and `[::]` reaches an unbounded `vsprintf` into
a stack buffer. On *this* build the write is caught: glibc 2.39 with
`_FORTIFY_SOURCE 3` (gcc's default at `-O2` on this system; `CFLAGS` in
`Makefile.conf` sets neither `-D_FORTIFY_SOURCE` nor `-fno-…`) turns `vsprintf`
into `__vsprintf_chk` and aborts on the first byte past the buffer, so what an
attacker gets here is a crash, not a controlled write. **That mitigation is the
compiler's, not the code's**, and a build without it — a different distro
default, `-O0`, a cross-build, the Windows tree — has the plain unchecked stack
write. Neither outcome is acceptable and the fix is the same one line.

**And it is silent.** stdout and stderr were 0 bytes in every socket abort above,
because xschem redirects them itself whenever it is not the foreground process
group of its terminal — which is every background, desktop-launcher, script and
CI start:

```c
  if(cli_opt_detach) {
    fclose(stdin);
    retval = freopen("/dev/null", "w", stdout);
    …
    retval = freopen("/dev/null", "w", stderr);
```
— `src/main.c:130-136`, armed at `:111-112`

Confirmed both ways: glibc's `*** buffer overflow detected ***: terminated`
does reach a redirected stderr when xschem *is* in the foreground process group
(the `--script` legs of the reproducer capture it, and it is visible under gdb),
and it is nowhere at all when xschem is started the way a TCP-controlled xschem
is always started.

---

### C — `xschem exit` answers `0` while a modal owns the editor, and the design keeps changing behind it

```
xschem get wires                                ->       1 ms  '91'
xschem wire 950 0 950 100                       ->      14 ms  ''
xschem get wires                                ->       2 ms  '92'
xschem get modified                             ->       1 ms  '1'
xschem exit                                  hc ->    1446 ms  '0'
grab current                                    ->       1 ms  '.__tk__messagebox'
.__tk__messagebox.msg cget -text                ->       1 ms  'mos_power_ampli.sch: UNSAVED data: want to exit?'
-- still mutating the design behind the modal:
xschem wire 900 0 900 100                       ->       8 ms  '0'
xschem get wires                                ->       1 ms  '93'
-- dismissing the box (== pressing its button):
destroy .__tk__messagebox                       ->       1 ms  ''
xschem get version                              ->    4005 ms  'TIMEOUT'
xschem get wires                                ->    4005 ms  'TIMEOUT'
```

Four things in that trace, in order of how bad they are:

1. **`xschem exit` answers `0`** — a plausible success value, identical to what
   `xschem get modified` answers on a clean design — after 1446 ms (1541, 1748 and
   1875 ms in three other runs). Nothing in the reply says *a human is being asked
   a question*.
2. **The user is locked out of their own editor.** `grab current` is
   `.__tk__messagebox`, put up from C at `src/scheduler.c:3594-3596` (and
   repeated at `:3607-3609`, `:3637-3639`, `:3649-3651`; `src/xinit.c` has four
   more, at `:2327`, `:2419`, `:2500`, `:2560`).
3. **The socket keeps mutating the schematic behind the modal** — wires 92 → 93
   while the box is up.
4. **Dismissing the box wedges the channel permanently.** Same destroyed-`puts`
   mechanism as **A**, and note *where the re-entries come from*: they are
   **separate connections**, serviced by the nested event loop inside
   `tk_messageBox`, not re-entries on the original socket. A fix that only
   disarms the *current* socket's `fileevent` does not cover this.

**Only item 1 depends on the client shape.** Run with clients that never
half-close, items 2, 3 and 4 are byte-for-byte the same — the modal, the 92 → 93
mutation behind it, the permanent `TIMEOUT` after `destroy` — and what changes is
that `xschem exit` never answers at all: `TIMEOUT` after 20005 ms. Both shapes
are in the pasted output side by side.

### What earlier passes got wrong

Recorded because it is half the value of the re-measurement. **The first pass**
(the design-plan §8 R1 write-up):

* **The 4096 threshold was `4022` safe / `4122` fatal.** Neither is a boundary.
  Measured: **4095 safe, 4096 fatal**, i.e. exactly one byte past
  `char buf[4096]` — the NUL terminator — and **4085/4086** on the failure path.
* **`xschem exit` "returned `0` in 1281 ms"** was stated without the client
  shape. With a non-half-closing client it does not return at all. The `0` is
  real, and only for a half-closing client.
* **"stdout and stderr both 0 bytes … because the failure destroys `puts`"**
  conflates two things. The 0 bytes are `src/main.c:130-136` and prove nothing
  by themselves — they are 0 bytes in a *healthy* background xschem too. The
  destroyed `puts` is real and is proved by the background errors and by
  `info commands ::puts` being empty.

**The second pass** (the previous revision of this file):

* **It called the socket the whole exposure** — "an xschem that never enables it
  has zero exposure" — and filed **B** as a TCP defect: the title, section **B**,
  the single `xschem_getdata → scheduler.c:7814` path, and Coverage item 4,
  which tested only the socket. The overflow is in `log_action()` and a stock
  GUI xschem with no socket reaches it by pressing OK on a dialog. This is the
  rescope in *Status*.
* **It said two of the three defects "need the client to stop writing"**, and
  told a reader that `echo … | nc localhost P` "gets `1` and no wedge". True for
  that one command, and misleading as a general rule: the wedge needs a nested
  loop plus *any* concurrent socket event, and a second plain-`nc` connection
  supplies it — measured, with zero half-closes, in leg A. Also `nc -q1` and
  `nc -N` **do** half-close (verified against a listener), so even the
  single-connection form fires from an ordinary `nc` invocation.
* **The `puts` census `397 / 395 / 18 / 308` does not reproduce** under any
  counting method. It is **407 / 404 / 19 / 313** by token match, 417/410/19/315
  by `\bputs\b`, 212/212/14/164 excluding comment lines. The ERE it was measured
  with returns 0 under this box's ugrep 7.8.4. Every *other* number in that
  table did reproduce exactly.
* **`redef_puts`'s second caller is `tclcmd_ok_button` (`:11655`), not `tclcmd`**
  (`:11683`, which contains no rename pair). The line numbers `:11660` and
  `:11662-11663` were right; the proc name was not, and a fixer grepping
  `proc tclcmd` lands 23 lines past the code. `redef_puts` itself ends at
  `:11646`, not `:11645`.
* **The re-entry depth was presented as reproducible** ("including `250` / `249`
  … across three runs"). It is not: seven runs of that leg on this tree gave
  250 six times and **249** once, and an independent re-verification got 249
  on its first try. What *is* stable is the structure — *N*
  entries, *N* unwinds, *N* − 1 errors, exactly one of them the
  `rename ::tcl::puts` failure.
* **Two citation nits**, both fixed above: the plan's V1/V2/V3 table is §**7**,
  not §6; and the repeated UNSAVED message boxes were cited by their message
  continuation line (`:3609`, `:3639`, `:3651`) rather than by the
  `tk_messageBox` call (`:3607`, `:3637`, `:3649`), inconsistently with the
  first citation in the same sentence.

---

## Reproducer

One script, all three defects plus the mechanism, self-contained: no PDK, no
simulator, no netlisting, no write under `~/.xschem`, no write to any tracked
file (it copies the fixture into its own work dir first), and it kills every
xschem it starts. Safe to re-run. It never uses the ambient `$DISPLAY` —
defaulting to `:99` — because half its legs leave dialogs on the screen.

**Leg B runs first and uses no socket at all.**

Save as `/tmp/repro_0519.py` and run from the repo root:

```sh
tests/headless/devdisplay.sh start          # :99, or point REPRO_0519_DISPLAY elsewhere
python3 /tmp/repro_0519.py                  # optional arg: work dir, default /tmp/repro_0519_work
```

```python
#!/usr/bin/env python3
# 0519 reproducer -- xschem's action log and its TCP command server: inputs that
# kill or wedge the editor, each answering with a reply indistinguishable from
# success.  Leg B needs NO socket at all.
import os, random, shutil, socket, subprocess, sys, time

REPO = os.getcwd()
XS   = os.path.join(REPO, "src", "xschem")
FIX  = os.path.join(REPO, "xschem_library", "examples", "mos_power_ampli.sch")
WORK = sys.argv[1] if len(sys.argv) > 1 else "/tmp/repro_0519_work"
DISP = os.environ.get("REPRO_0519_DISPLAY", ":99")   # never the ambient $DISPLAY:
                                                     # this pops real windows
PORT0 = random.randint(40000, 60000)
KIDS = []

def line(s=""): print(s); sys.stdout.flush()

def talk(port, cmd, timeout=6.0, halfclose=False, host="127.0.0.1"):
    """One command == one TCP connection, as doc/xschem_man/xschem_remote.html says.
       halfclose=True == shutdown(SHUT_WR) after the line, which is what
       tests/headless/test_stdin_tcp_log.tcl's own client does (`close $s w`),
       and what `nc -N` / `nc -q<n>` do.  Default False == the plain `nc` shape."""
    t0 = time.time()
    try: s = socket.create_connection((host, port), timeout=timeout)
    except Exception as e: return ("CONNREFUSED", (time.time()-t0)*1000)
    s.settimeout(timeout)
    try:
        s.sendall((cmd + "\n").encode())
        if halfclose: s.shutdown(socket.SHUT_WR)
        out = b""
        while True:
            b = s.recv(65536)
            if not b: break
            out += b
    except socket.timeout:
        s.close(); return ("TIMEOUT", (time.time()-t0)*1000)
    s.close(); return (out.decode(errors="replace"), (time.time()-t0)*1000)

def p(port, cmd, timeout=6.0, hc=False, label=None):
    r, ms = talk(port, cmd, timeout, hc)
    line("  %-44s %s-> %7.0f ms  %r" % ((label or cmd)[:44], "hc " if hc else "   ", ms, r[:64]))
    return r

def start(port, sch):
    env = dict(os.environ, DISPLAY=DISP, GUI_GATE="0")
    pr = subprocess.Popen([XS, "--tcp_port", str(port), sch],
                          stdout=open(os.path.join(WORK, "out.%d" % port), "wb"),
                          stderr=open(os.path.join(WORK, "err.%d" % port), "wb"), env=env)
    KIDS.append(pr)
    for _ in range(80):                       # wait for the LISTEN, then one probe:
        try:                                  # probing a half-started xschem just
            socket.create_connection(("127.0.0.1", port), 0.4).close()   # queues
            break                             # connections it will serve later
        except Exception: time.sleep(0.25)
    talk(port, "xschem get version", 30.0)
    return pr

def state(pr, port):
    rc = pr.poll()
    err = os.path.getsize(os.path.join(WORK, "err.%d" % port))
    out = os.path.getsize(os.path.join(WORK, "out.%d" % port))
    return ("DEAD rc=%s" % rc) if rc is not None else "alive", "stdout %dB stderr %dB" % (out, err)

def windows():
    """what is on the screen -- xwininfo talks to the X server, not to xschem,
       so it still answers while xschem is wedged."""
    try:
        t = subprocess.run(["xwininfo","-root","-tree"], capture_output=True, text=True,
                           env=dict(os.environ, DISPLAY=DISP)).stdout
    except Exception: return "  (xwininfo not available)"
    import re as _re
    w = _re.findall(r'"([^"]+)": \("[^"]+" "([^"]+)"\)', t)
    return "  toplevels on %s: %s" % (DISP, ", ".join("%s [%s]" % (a,b) for a,b in w))

def stop(pr):
    if pr.poll() is None:
        pr.kill(); pr.wait()

def script(label, body, flags=(), timeout=60):
    """Run a leg with NO socket at all: a plain `--script`, the way any user or
       wrapper runs xschem.  Returns (rc, stdout, 'buffer overflow' seen)."""
    sp = os.path.join(WORK, "s.tcl")
    open(sp, "w").write(body)
    pr = subprocess.run([XS] + list(flags) + ["--pipe", "-q", "--script", sp, os.path.basename(FIX)],
                        cwd=WORK, capture_output=True, text=True, timeout=timeout,
                        env=dict(os.environ, DISPLAY=DISP, GUI_GATE="0"))
    ovf = "buffer overflow detected" in pr.stderr
    line("  %-44s -> rc=%-4s %-38s %s" % (label, pr.returncode,
         repr(" ".join(pr.stdout.split())[:38]), "*** buffer overflow detected ***" if ovf else ""))
    return pr.returncode, pr.stdout, ovf

shutil.rmtree(WORK, ignore_errors=True); os.makedirs(WORK)
shutil.copy(FIX, WORK); os.makedirs(os.path.join(WORK,"logd"))
SCH = os.path.join(WORK, os.path.basename(FIX))
line("repo   %s" % REPO)
line("binary %s  (mtime %s)" % (XS, time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(XS)))))
line("work   %s     DISPLAY %s" % (WORK, DISP))

# ============================================================ B: NO SOCKET ====
line("\n=== leg B -- a 4-KB action-log line aborts the process. NO SOCKET. ==========")
line("  a plain `--script` on the default GUI configuration; no --tcp_port, no --logdir:")
script("xschem get actionlog_filename",
       'puts [xschem get actionlog_filename]\n')
script("setprop instance 0, 4000-byte prop",
       'xschem setprop instance 0 "name=p0 [string repeat x 4000]"\nputs SURVIVED\n')
script("setprop instance 0, 4200-byte prop",
       'xschem setprop instance 0 "name=p0 [string repeat x 4200]"\nputs SURVIVED\n')
script("set header_text, 4072 bytes",
       'xschem set header_text [string repeat L 4072]\nputs SURVIVED\n')
script("set header_text, 4073 bytes",
       'xschem set header_text [string repeat L 4073]\nputs SURVIVED\n')
line("  and the same through the GUI dialog -- Menu 'Header/License text' (Shift+B),")
line("  driven only by pressing its own OK button:")
script("paste 4200 chars, press .dialog.f1.b1", '''puts "LOGFILE=[xschem get actionlog_filename]"
after 2500 {
  .dialog.textinput delete 1.0 end
  .dialog.textinput insert 1.0 [string repeat "L" 4200]
  puts "PRESSING OK len=[string length [.dialog.textinput get 1.0 {end - 1 chars}]]"
  flush stdout
  .dialog.f1.b1 invoke
}
after 8000 { puts SURVIVED; flush stdout; exit 0 }
update_schematic_header
''')
line("  the one configuration that is NOT exposed -- no action log open at all:")
script("--nogui, no --logdir: log_action 4096",
       'puts "logfile=[xschem get actionlog_filename]"\n'
       'xschem log_action [string repeat A 4096]\nputs SURVIVED\n', flags=("--nogui",))
script("--nogui WITH --logdir: log_action 4096",
       'puts "logfile=[xschem get actionlog_filename]"\n'
       'xschem log_action [string repeat A 4096]\nputs SURVIVED\n',
       flags=("--nogui", "--logdir", os.path.join(WORK, "logd")))

# ---------------------------------------------------------------- leg 0: facts
line("\n=== leg 0 -- what the channel is, and what a reply means =====================")
port = PORT0; pr = start(port, SCH)
line("  ss -ltn for port %d:" % port)
for l in subprocess.run(["ss","-ltn"],capture_output=True,text=True).stdout.splitlines():
    if ":%d " % port in l: line("    " + " ".join(l.split()))
p(port, "xschem get current_name", label="xschem get current_name")
p(port, "xschem get instances"); p(port, "xschem get wires"); p(port, "xschem get modified")
line("  -- a Tcl ERROR and a Tcl RESULT come back as the same bytes:")
p(port, "expr {40+2}"); p(port, "error 42")
p(port, "xschem get version"); p(port, "xschem nosuchverb")
line("  -- and the reply is NOT what the man page promises (xschem_remote.html:37-39):")
p(port, "puts $XSCHEM_LIBRARY_PATH")
p(port, "puts hello; expr 1+1")
line("  -- the same 4-KB kill, now over the socket:")
r, ms = talk(port, "string length " + "A"*4081, 6.0)
line("  %-44s    -> %7.0f ms  %r     (4095 bytes, last safe)" % ("command of 4095 bytes", ms, r[:20]))
r, ms = talk(port, "string length " + "A"*4082, 6.0)
line("  %-44s    -> %7.0f ms  %r     (4096 bytes)" % ("command of 4096 bytes", ms, r[:20]))
p(port, "xschem get version", 4.0)
line("  process %s, %s" % state(pr, port))
stop(pr)
line("  and with the CIW mirror suppressed / with log_action disabled:")
for pre in ("xschem log_action -suppressecho 1", "xschem set actionlog_suppress 1"):
    port += 1; pr = start(port, SCH)
    p(port, pre)
    r, ms = talk(port, "string length " + "A"*4082, 6.0)
    line("  %-44s    -> %7.0f ms  %r" % ("then a 4096-byte command", ms, r[:20]))
    line("  process %s, %s" % state(pr, port))
    stop(pr)

# --------------------------------------------------- leg A: nested-loop wedge
line("\n=== leg A -- a nested event loop destroys `puts` and wedges the channel =====")
line("  ONE connection, self-re-entry.  It needs the socket to go readable during the")
line("  nested loop, i.e. the client must stop writing:")
port += 1; pr = start(port, SCH)
line("  control -- the client holds the connection open (the plain `nc` shape):")
p(port, "set ::w 0; incr ::w; update; set ::w")
p(port, "xschem get wires")
line("  the same line, half-closed (`close $s w`, `nc -N`, `nc -q1`):")
p(port, "set ::w 0; incr ::w; update; set ::w", hc=True)
p(port, "xschem get version", 4.0); p(port, "xschem get wires", 4.0)
line("  process %s, %s" % state(pr, port)); line(windows())
stop(pr)

line("\n  TWO connections, no half-close anywhere -- every client below is a plain")
line("  `echo ... | nc localhost P`, the recipe in xschem's own manual:")
port += 1; pr = start(port, SCH)
NC = shutil.which("nc")
def nc(cmd, bg=False, wait=6):
    sh = "echo '%s' | nc localhost %d" % (cmd.replace("'", "'\\''"), port)
    if bg:
        return subprocess.Popen(sh, shell=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    t0 = time.time()
    try: o = subprocess.run(sh, shell=True, capture_output=True, text=True, timeout=wait).stdout
    except subprocess.TimeoutExpired: o = "TIMEOUT"
    line("  %-44s nc -> %7.0f ms  %r" % (cmd[:44], (time.time()-t0)*1000, o[:64]))
    return o
if NC:
    nc("xschem get wires")
    line("  conn1: a BLOCKING alert_ (nowait=0), backgrounded, connection held open:")
    bgp = nc("alert_ {0519-nc} +400+400 0", bg=True)
    time.sleep(2.5)
    line("  conn2..5, each a fresh plain-nc connection, serviced by the nested loop:")
    nc("xschem get wires")
    nc("destroy .alert")
    time.sleep(1.0)
    nc("xschem get version", wait=5)
    nc("xschem get wires", wait=5)
    try: bgp.kill()
    except Exception: pass
    line("  process %s, %s" % state(pr, port))
else:
    line("  (nc not installed -- skipped)")
stop(pr)

line("\n  the same, through an ORDINARY xschem path -- alert_ with nowait=1:")
port += 1; pr = start(port, SCH)
p(port, "xschem get wires")
p(port, "alert_ {0519} +200+300 1", 10.0, hc=True)
p(port, "xschem get version", 4.0); p(port, "xschem get wires", 4.0)
line("  process %s, %s" % state(pr, port))
stop(pr)

line("\n  mechanism -- count the re-entries, and see what the unwind leaves behind:")
port += 1; pr = start(port, SCH)
TR = os.path.join(WORK, "trace.txt"); BG = os.path.join(WORK, "bg.txt")
# Tk's own bgerror puts up an "Application Error" box; swap in one that appends to
# a file instead, and that reports whether `puts` still exists.  `exec` is used
# because by the time it runs there may be no `puts` left to write with.
p(port, 'proc bgerror {m} {catch {exec /bin/sh -c "cat >> ' + BG + '" '
        '<< "$m | ::puts=[info commands ::puts] ::tcl::puts=[info commands ::tcl::puts]\\n"}}',
  label="install a file-logging bgerror")
p(port, 'incr ::d; exec /bin/sh -c "echo enter >> ' + TR + '"; update; '
        'exec /bin/sh -c "echo leave >> ' + TR + '"; set ::d',
  timeout=20.0, hc=True, label="incr ::d; ...; update; ...; set ::d")
time.sleep(1.5)
tr = open(TR).read().split() if os.path.exists(TR) else []
line("  handler entered %d times, unwound %d times" % (tr.count("enter"), tr.count("leave")))
bgl = open(BG).read().splitlines() if os.path.exists(BG) else []
seen = {}
for l in bgl: seen[l] = seen.get(l, 0) + 1
line("  %d background errors:" % len(bgl))
for k, v in sorted(seen.items(), key=lambda kv: -kv[1]): line("    %4d x  %s" % (v, k))
p(port, "xschem get version", 4.0)
line("  process %s, %s" % state(pr, port))
stop(pr)

# ---------------------------------------------------- leg C: modal compound
line("\n=== leg C -- `xschem exit` answers '0' while a modal owns the editor =======")
for hc in (True, False):
    port += 1; pr = start(port, SCH)
    line("  --- clients %s ---" % ("half-closing" if hc else "holding the connection open"))
    p(port, "xschem get wires"); p(port, "xschem wire 950 0 950 100"); p(port, "xschem get wires")
    p(port, "xschem get modified")
    if hc:
        p(port, "xschem exit", 10.0, hc=True)
    else:
        import threading
        res = {}
        t = threading.Thread(target=lambda: res.update(x=talk(port, "xschem exit", 20.0)))
        t.start(); time.sleep(3.0)
    p(port, "grab current"); p(port, ".__tk__messagebox.msg cget -text")
    line("  -- still mutating the design behind the modal:")
    p(port, "xschem wire 900 0 900 100"); p(port, "xschem get wires")
    line("  -- dismissing the box (== pressing its button):")
    p(port, "destroy .__tk__messagebox"); time.sleep(1.0)
    p(port, "xschem get version", 4.0); p(port, "xschem get wires", 4.0)
    if not hc:
        t.join(30)
        line("  held-open `xschem exit` returned %r after %.0f ms" % (res["x"][0][:20], res["x"][1]))
    line("  process %s, %s" % state(pr, port))
    stop(pr)

line("\n=== cleanup =================================================================")
for pr in KIDS: stop(pr)
time.sleep(0.5)
line("  xschem processes started by this script still alive: %d"
     % sum(1 for k in KIDS if k.poll() is None))
q = subprocess.run(["pgrep","-c","-f","src/xschem"],capture_output=True,text=True).stdout.strip()
line("  any xschem process anywhere on this box: %s   (0 unless another session has one)" % (q or "0"))
line("  fixture copy unchanged in workdir: %s" %
     (subprocess.run(["cmp","-s",FIX,SCH]).returncode == 0))
```

Actual output, `src/xschem` built 2026-08-19 18:16, HEAD `722ce61e`, dev display
`:99` (Xvfb 1920x1080x24 + openbox), Tcl/Tk 8.6, glibc 2.39, ugrep 7.8.4,
`nc.openbsd`, fixture `xschem_library/examples/mos_power_ampli.sch` (517 lines,
`xschem get instances` 117, `xschem get wires` 91):

```
repo   /home/qflow/dev/xschem/claude_1/xschem
binary /home/qflow/dev/xschem/claude_1/xschem/src/xschem  (mtime 2026-08-19 18:16)
work   /tmp/claude-1000/-home-qflow-dev-xschem-claude-1-xschem/daa90c98-1228-4589-b0d4-1c0b8e847dad/scratchpad/repro_work     DISPLAY :99

=== leg B -- a 4-KB action-log line aborts the process. NO SOCKET. ==========
  a plain `--script` on the default GUI configuration; no --tcp_port, no --logdir:
  xschem get actionlog_filename                -> rc=0    '/tmp/Xschem.log.9'                    
  setprop instance 0, 4000-byte prop           -> rc=0    'SURVIVED'                             
  setprop instance 0, 4200-byte prop           -> rc=-6   ''                                     *** buffer overflow detected ***
  set header_text, 4072 bytes                  -> rc=0    'SURVIVED'                             
  set header_text, 4073 bytes                  -> rc=-6   ''                                     *** buffer overflow detected ***
  and the same through the GUI dialog -- Menu 'Header/License text' (Shift+B),
  driven only by pressing its own OK button:
  paste 4200 chars, press .dialog.f1.b1        -> rc=-6   'LOGFILE=/tmp/Xschem.log.6 PRESSING OK ' *** buffer overflow detected ***
  the one configuration that is NOT exposed -- no action log open at all:
  --nogui, no --logdir: log_action 4096        -> rc=0    'logfile= SURVIVED'                    
  --nogui WITH --logdir: log_action 4096       -> rc=-6   'logfile=/tmp/claude-1000/-home-qflow-d' *** buffer overflow detected ***

=== leg 0 -- what the channel is, and what a reply means =====================
  ss -ltn for port 49054:
    LISTEN 0 4096 0.0.0.0:49054 0.0.0.0:*
    LISTEN 0 4096 [::]:49054 [::]:*
  xschem get current_name                         ->       2 ms  '/tmp/claude-1000/-home-qflow-dev-xschem-claude-1-xschem/daa90c98'
  xschem get instances                            ->       2 ms  '117'
  xschem get wires                                ->       2 ms  '91'
  xschem get modified                             ->       2 ms  '0'
  -- a Tcl ERROR and a Tcl RESULT come back as the same bytes:
  expr {40+2}                                     ->       2 ms  '42'
  error 42                                        ->       2 ms  '42'
  xschem get version                              ->       2 ms  '3.4.8RC'
  xschem nosuchverb                               ->       3 ms  'xschem nosuchverb: invalid command.'
  -- and the reply is NOT what the man page promises (xschem_remote.html:37-39):
  puts $XSCHEM_LIBRARY_PATH                       ->       2 ms  ''
  puts hello; expr 1+1                            ->       2 ms  '2'
  -- the same 4-KB kill, now over the socket:
  command of 4095 bytes                           ->       3 ms  '4081'     (4095 bytes, last safe)
  command of 4096 bytes                           ->     358 ms  ''     (4096 bytes)
  xschem get version                              ->       2 ms  'CONNREFUSED'
  process DEAD rc=-6, stdout 0B stderr 0B
  and with the CIW mirror suppressed / with log_action disabled:
  xschem log_action -suppressecho 1               ->       3 ms  ''
  then a 4096-byte command                        ->     365 ms  ''
  process DEAD rc=-6, stdout 0B stderr 0B
  xschem set actionlog_suppress 1                 ->       1 ms  ''
  then a 4096-byte command                        ->       1 ms  '4082'
  process alive, stdout 0B stderr 0B

=== leg A -- a nested event loop destroys `puts` and wedges the channel =====
  ONE connection, self-re-entry.  It needs the socket to go readable during the
  nested loop, i.e. the client must stop writing:
  control -- the client holds the connection open (the plain `nc` shape):
  set ::w 0; incr ::w; update; set ::w            ->       3 ms  '1'
  xschem get wires                                ->       2 ms  '91'
  the same line, half-closed (`close $s w`, `nc -N`, `nc -q1`):
  set ::w 0; incr ::w; update; set ::w         hc ->      19 ms  '1'
  xschem get version                              ->    4005 ms  'TIMEOUT'
  xschem get wires                                ->    4008 ms  'TIMEOUT'
  process alive, stdout 0B stderr 0B
  toplevels on :99: Info window [Toplevel], Application Error [ErrorDialog], xschem [3] - mos_power_ampli.sch [Tk], xschem CIW - /tmp/Xschem.log.8 [Toplevel]

  TWO connections, no half-close anywhere -- every client below is a plain
  `echo ... | nc localhost P`, the recipe in xschem's own manual:
  xschem get wires                             nc ->       5 ms  '91'
  conn1: a BLOCKING alert_ (nowait=0), backgrounded, connection held open:
  conn2..5, each a fresh plain-nc connection, serviced by the nested loop:
  xschem get wires                             nc ->       7 ms  '91'
  destroy .alert                               nc ->       6 ms  ''
  xschem get version                           nc ->    5008 ms  'TIMEOUT'
  xschem get wires                             nc ->    5008 ms  'TIMEOUT'
  process alive, stdout 0B stderr 0B

  the same, through an ORDINARY xschem path -- alert_ with nowait=1:
  xschem get wires                                ->       3 ms  '91'
  alert_ {0519} +200+300 1                     hc ->       6 ms  'window name "alert" already exists in parent'
  xschem get version                              ->    4005 ms  'TIMEOUT'
  xschem get wires                                ->    4006 ms  'TIMEOUT'
  process alive, stdout 0B stderr 0B

  mechanism -- count the re-entries, and see what the unwind leaves behind:
  install a file-logging bgerror                  ->       3 ms  ''
  incr ::d; ...; update; ...; set ::d          hc ->     246 ms  '250'
  handler entered 250 times, unwound 250 times
  249 background errors:
     248 x  can't delete "puts": command doesn't exist | ::puts= ::tcl::puts=
       1 x  can't rename "::tcl::puts": command doesn't exist | ::puts= ::tcl::puts=
  xschem get version                              ->    4003 ms  'TIMEOUT'
  process alive, stdout 0B stderr 0B

=== leg C -- `xschem exit` answers '0' while a modal owns the editor =======
  --- clients half-closing ---
  xschem get wires                                ->       1 ms  '91'
  xschem wire 950 0 950 100                       ->      14 ms  ''
  xschem get wires                                ->       2 ms  '92'
  xschem get modified                             ->       1 ms  '1'
  xschem exit                                  hc ->    1446 ms  '0'
  grab current                                    ->       1 ms  '.__tk__messagebox'
  .__tk__messagebox.msg cget -text                ->       1 ms  'mos_power_ampli.sch: UNSAVED data: want to exit?'
  -- still mutating the design behind the modal:
  xschem wire 900 0 900 100                       ->       8 ms  '0'
  xschem get wires                                ->       1 ms  '93'
  -- dismissing the box (== pressing its button):
  destroy .__tk__messagebox                       ->       1 ms  ''
  xschem get version                              ->    4005 ms  'TIMEOUT'
  xschem get wires                                ->    4005 ms  'TIMEOUT'
  process alive, stdout 0B stderr 0B
  --- clients holding the connection open ---
  xschem get wires                                ->       2 ms  '91'
  xschem wire 950 0 950 100                       ->      12 ms  ''
  xschem get wires                                ->       1 ms  '92'
  xschem get modified                             ->       1 ms  '1'
  grab current                                    ->       2 ms  '.__tk__messagebox'
  .__tk__messagebox.msg cget -text                ->       1 ms  'mos_power_ampli.sch: UNSAVED data: want to exit?'
  -- still mutating the design behind the modal:
  xschem wire 900 0 900 100                       ->      11 ms  '0'
  xschem get wires                                ->       1 ms  '93'
  -- dismissing the box (== pressing its button):
  destroy .__tk__messagebox                       ->       2 ms  ''
  xschem get version                              ->    4005 ms  'TIMEOUT'
  xschem get wires                                ->    4005 ms  'TIMEOUT'
  held-open `xschem exit` returned 'TIMEOUT' after 20021 ms
  process alive, stdout 0B stderr 0B

=== cleanup =================================================================
  xschem processes started by this script still alive: 0
  any xschem process anywhere on this box: 0   (0 unless another session has one)
  fixture copy unchanged in workdir: True
```

Nothing in that block is edited. Reading it:

* **The work dir is long** because it was run out of a session scratch
  directory; it is whatever is passed as the script's argument
  (`/tmp/repro_0519_work` by default). `xschem get current_name` and two other
  replies are cut at 64 characters by the probe's own `r[:64]`, not by hand.
* **Ports are random per run** and the `/tmp/Xschem.log.N` suffix depends on what
  else is on the box.
* **The `toplevels on :99` line reads clean here because nothing else was on
  that display.** It will not on a shared one: an earlier run of this same
  script, made while a concurrent session had its own xschem on `:99`, showed
  that session's toplevels in the same line and `4` in the box-wide count. The
  line that carries the cleanup guarantee is the specific one —
  **`xschem processes started by this script still alive: 0`** — not the
  box-wide one below it.
* **Do not read `250` as a constant** — see *What earlier passes got wrong*.
  Reproduced across runs: the 4095/4096 and 4072/4073 boundaries, every `rc=-6`,
  the `0.0.0.0` + `[::]` bind, `error 42` == `expr 42` == `'42'`,
  `puts $XSCHEM_LIBRARY_PATH` → `''`, the `alert_` *"already exists in parent"*
  re-entry proof, `suppressecho` still aborting while `actionlog_suppress`
  survives at `'4082'`, the plain-`nc` wedge, the `'0'` from a half-closed
  `xschem exit` (1446 / 1541 / 1748 / 1875 ms), and the permanent `TIMEOUT` after
  `destroy`.
* The `+X+Y` of any dialog is the WM's.

## Why it matters

1. **Every socket failure returns a reply shaped like a result, so nothing
   downstream can defend itself.** The one bit that distinguishes them exists —
   `tcp_rc`, `src/xschem.tcl:5865` — and is thrown away. A wrapper cannot retry,
   cannot fall back, cannot even *log* that something went wrong; it sees `1`,
   `0`, `42` or `''` and carries on issuing commands into a dead process. This is
   the property that turns three bugs into a class: it is why the wedge looks
   like a correct answer, why the abort looks like a void command, and why the
   modal looks like a completed exit.
2. **The kills are ordinary inputs, not attacks.** 4 KB is a normal size for a
   property string, a global attribute block, or a pasted license header — and
   the license header has a menu item and a keyboard accelerator. `alert_ … 1`
   is what xschem itself calls from 43 places in C when it has something to say,
   and it re-enters *because of a `tkwait` that is on the wrong side of the
   `nowait` check*. No client can avoid these by being careful, because the
   trigger is on the server's side of the wire — and defect B has no wire.
3. **Defect B's blast radius is every xschem, not every networked xschem.** The
   only measured immune configuration is `--nogui` with no `--logdir`. A user who
   has never opened a port, never written a script, and is doing nothing but
   editing a schematic loses the process and the unsaved design to a paste.
4. **The socket exposure is real today and is bigger than the automation it was
   built for.** The listener answers on this machine's LAN address and on its
   global IPv6 address, measured. Issue **0004** covers *who may drive it*; it
   does not cover that the editor dies when the person driving it is the
   legitimate one on `127.0.0.1`. Fixing 0004's bind does not fix A, B or C — it
   only shrinks who can reach them.
5. **A wedged xschem takes unsaved design work with it, and says nothing.**
   Defect C's own trace shows two wires added *after* the user was asked whether
   to discard unsaved changes, on a schematic whose modal answer was never given.
   Defect B ends with a core dump, no message on stdout or stderr when detached
   (`src/main.c:130-136`), and a refused port — the only symptom a wrapper sees
   is that the next connection fails.
6. **The tree's own TCP test already uses a client shape that wedges** — it
   half-closes (`tests/headless/test_stdin_tcp_log.tcl:100`) — and stays green,
   because none of its commands spins a nested loop and none is 4096 bytes long.
   The harness for catching all three is already written; it is a few `check`
   lines short.

## Fix — candidates in order

**V1 — bind the listener to loopback. One line, plus a variable and two doc
edits.** At `src/xschem.tcl:18042`:

```tcl
    if {[catch {socket -server xschem_server -myaddr $xschem_listen_addr $xschem_listen_port} err]} {
```

with `set_ne xschem_listen_addr 127.0.0.1` beside the existing
`set_ne xschem_listen_port {}` at `:18637`, an uncommented note in
`src/xschemrc` beside `:573`, and a sentence in
`doc/xschem_man/xschem_remote.html`. Measured in a standalone Tcl server on this
machine: `-myaddr 127.0.0.1` binds **only** `127.0.0.1:P` — no `0.0.0.0`, no
`[::]` — and a client reaching it as `127.0.0.1`, or through a resolver that
tries both families (python's `socket.create_connection('localhost', P)`), still
works. **Anything that connects to `::1` explicitly breaks**: measured,
`Connection refused` from python and `rc=1` from `nc -6 ::1`, where the same
client succeeds against today's wildcard bind.

**One client shape is unresolved and must be settled before V1 lands:
`nc localhost`** — which is the manual's own recipe (`xschem_remote.html:69-76`).
`getent hosts localhost` on this box answers `::1` first, and `nc localhost`
against a loopback-only listener gave an empty reply in repeated attempts here
while the same command against a wildcard listener answers normally (leg A of the
reproducer drives a real xschem that way and gets `91`). The measurement was not
stable enough across runs to state a verdict, so: **do not assume `nc localhost`
survives V1 — measure it, and if it does not, either bind both `127.0.0.1` and
`::1` or update the recipe in the manual.** The escape hatch for everyone else is
the new variable.
This is issue **0004**'s mitigation (1), which has been open since 2026-06-11.
**It does not fix A, B or C** and is wanted on its own merits.

**V2 — `vsnprintf`, unconditionally. Four lines become one.** At
`src/util.c:505-509`, delete the `#ifdef HAS_SNPRINTF` and keep only

```c
  vsnprintf(buf, S(buf), fmt, args);
```

C89 does not have `vsnprintf`, which is presumably why the `#ifdef` exists — but
`HAS_SNPRINTF` is undefined on the mainstream build, which means the mainstream
build is running the unsafe branch, and the buffer is a *pane mirror*: a
truncated CIW echo is the correct outcome for a 4 KB line, and the action-log
file below it is already unbounded (`vfprintf`, `:498`). Verified against a
standalone reproduction of the same overflow: `vsprintf` aborts, `vsnprintf`
returns cleanly. If C89 portability must be kept, the same fix is
`if(strlen(…) < S(buf))`-guarded, or route the mirror through the house
`my_snprintf` (`src/save.c:2683` documents it as the hand-rolled formatter for
exactly this case). This is **the only C change of the three** and the only one
that needs a rebuild. **It is also the only one that helps an xschem with no
socket**, and by *Why it matters* §3 that is most of them — so V2, not V1, is the
patch to land first. It fixes **B** completely and nothing else.

**V3 — make `xschem_getdata` re-entrancy-safe. ~4 lines of edit in a 44-line
proc, plus a test.** Three parts, and the first two are one line each:

* **Disarm before evaluating**: `fileevent $sock readable {}` immediately before
  `:5865`, so a nested loop cannot re-fire *this* socket's handler. Necessary,
  not sufficient — leg A's plain-`nc` sub-leg and leg C's tail both re-enter from
  *other* connections. Covering those means either replying and closing before
  any nested loop can run, or refusing to service a new connection while an
  evaluation is in flight (a depth counter in `xschem_server`).
* **Stop the unbalanced rename.** Either delete `redef_puts` (`:5863`) and the
  pair at `:5866-5867` outright — measured, they contribute nothing: the reply is
  `catch`'s variable, and `puts $XSCHEM_LIBRARY_PATH` already answers the empty
  string — or make the restore conditional on this frame having done the rename
  (`redef_puts` returns whether it renamed; only that frame undoes it). The
  second form is more work because `redef_puts` has a second caller,
  `tclcmd_ok_button` (`src/xschem.tcl:11655`, `redef_puts` at `:11660`), which
  runs the same unconditional pair at `:11662-11663` and has the same latent
  problem. Deleting it is the smaller change and the one with a measured
  justification; the conditional form is the one that could also make the man
  page's `puts` example (`xschem_remote.html:39`) true again, by appending the
  capture to the reply.
* **Decide what a re-entrant command should do at all.** Disarming and fixing
  the rename stops the *destruction*; it does not answer what `xschem exit`
  should send back while a human stares at a modal. The honest minimum is that
  the reply carry the return code — a one-character prefix, or a documented
  `rc\tresult` framing — so a caller can tell `0`-the-answer from `0`-the-error.
  Everything in this issue's *Why it matters* §1 depends on that bit existing.

**Not recommended: a new Unix socket, a token handshake, or a safe interpreter.**
All three are 0004's territory and none of them touches A, B or C — a token gets
you an *authenticated* client that still kills the editor with 4096 bytes, and
none of them is even in the room for the dialog that kills a socket-free xschem.

V1, V2 and V3 are independent. V2 is the one that stops a crash *and* the only
one that reaches the socket-free majority, V3 is the one that stops the silent
wedge, V1 is the one that decides who can do either.

## Coverage

`tests/headless/test_stdin_tcp_log.tcl` (163 lines) is the only test in the tree
that touches the socket — `grep -rln "tcp_port\|setup_tcp_xschem\|xschem_getdata" tests/`
returns it and nothing else. It arms the server in-process
(`setup_tcp_xschem 0`, `:116`), drives it from a loopback client
(`tcp_send`, `:95-111`) and asserts the *action-log* behaviour: reply `42` for
`expr {6*7}`, one log line per self-logging verb, `# failed:` comments for
errors. **It stays green through all three defects**, and its client already
half-closes (`:100`), so the shape is right and only the commands are missing.

A test must assert, in this tree's `check "<name>" <ok> <info>` style:

1. **The 4 KB line, with no socket in the picture.** This is the cheapest and
   widest check and it belongs *first*, in a plain `--script` leg, not in the TCP
   suite: `xschem set header_text [string repeat L 4073]` (or
   `xschem setprop instance 0 <4200 bytes>`) must not abort. Assert on the
   process — run it under `timeout` and require a clean exit code, because the
   only in-band symptom is that the script stops. Include the safe side (4072)
   so a fix that truncates everything to nothing still fails. Needs `has_x`
   *or* `--logdir`, and must not be run with `--nolog` — that is literally the
   gate, `if(!has_x && !cli_opt_logdir[0]) return;` at `src/util.c:351`. With
   `--nogui` and no `--logdir` the action log is closed and the leg silently
   proves nothing, which is exactly the trap to guard against — assert
   `xschem get actionlog_filename` is non-empty **before** the payload.
2. **The GUI dialog leg for the same defect**, gated on `has_x` and run on `:99`:
   open `update_schematic_header`, insert 4200 characters into
   `.dialog.textinput`, `invoke` the OK button, and require the process to
   survive. This is the shape a user actually reaches.
3. **A re-entrant command over the socket does not kill the channel** — send
   `set ::w 0; incr ::w; update; set ::w`, assert the reply is `1`, **and then
   assert the next command still answers**. The second half is the check; the
   first half passes today. This leg needs **no X**: measured, it reproduces
   under `--nogui`, where the nesting runs into Tcl's
   `too many nested evaluations (infinite loop?)`.
4. **`puts` survives** — `info commands ::puts` and `info commands ::tcl::puts`
   after the round trip. This is the assertion that fails loudest and is
   cheapest to write. Today the *test script itself* dies at the next `puts`,
   which is a diagnosis, not a check.
5. **Both re-entry routes, and both client shapes.** Half-closing and
   connection-holding are measurably different (parameterise `tcp_send`'s
   existing `close $s w`), and the *second-connection* route is a different bug
   from the *same-connection* one: a fix that only disarms the current socket's
   `fileevent` passes the first and fails the second. The second-connection leg
   is a blocking `alert_` on one connection plus an ordinary query on another,
   with no half-close anywhere.
6. **The socket length boundary, from both sides and on both arms** — 4095 bytes
   answers `4081` and the process lives; 4096 bytes must not abort. Add the
   failure arm (4085 / 4086), because the `# failed: ` prefix moves the boundary
   and a test pinned only to the success arm goes green on a half-fix. Assert
   the process is still alive by sending a *second* command, not by checking a
   return code — the abort's only symptom on the wire is an empty reply.
7. **Failure is distinguishable from success** — whatever V3's framing turns out
   to be, assert that `error 42` and `expr {40+2}` do **not** produce identical
   bytes. Without this the other checks can all pass on a channel that still
   lies.
8. **A GUI leg for the modal**, on `:99` and gated on `has_x`: `xschem exit` on a
   modified design must not answer a bare success value while `grab current` is
   a message box, and the channel must survive the box being destroyed.
9. **Sabotage direction** — restore the `rename` pair, or drop the `fileevent`
   disarm, and checks 3/4/5 must go red while the existing
   `test_stdin_tcp_log.tcl` stays green; that difference is the proof the new
   checks are not redundant with it. For 1/2/6, restore `vsprintf` and check the
   over-length legs red *without* the under-length legs moving.

Environment note: the re-entry depth (~250 here) is a property of this machine's
Tcl and stack and **is not stable even on this machine** — assert *that the
channel is dead*, never a frame count.

## Related

- **0004** — *the TCP command server has no authentication and binds all
  interfaces*, OPEN since 2026-06-11. Same entry point, different question.
  0004 asks **who may drive the socket**; this issue is that **the editor dies
  regardless of who drives it**, on loopback, from the legitimate client — and,
  for defect B, with no socket open at all. 0004's mitigation (1) is this
  issue's V1 and is still unapplied — measured again today: `0.0.0.0` and
  `[::]`, reachable on this host's LAN and global IPv6 addresses. Its "What is
  NOT wrong" section (off by default, not a regression) applies to A and C
  unchanged, and **not** to B.
- **0003** — *action-log coverage holes: the stdin REPL and the TCP server*. The
  logging it added to `xschem_getdata` (`:5868-5884`, commit `b247e6f7`,
  2026-07-14) is one of the code paths that reaches defect **B**'s `vsprintf` —
  but the defect is in `log_action()`, not in what 0003 wrote, and it predates
  it: the `char buf[4096]` + `vsprintf` CIW mirror arrived with `80d63eb9`
  (2026-06-10, the CIW live-log window); the original `log_action()` sink
  (`4334b00f`, same day) wrote only to the file and had no buffer at all.
- **0074** — *read-only guard gaps, and `set header_text`'s reject is propagated
  as an uncaught Tcl error*, OPEN since 2026-07-03. **The same dialog and the
  same OK button as defect B's GUI leg**: `update_schematic_header`
  (`src/xschem.tcl:4115-4121`, menu accelerator Shift+B at `:17442`) calls
  `xschem set header_text` with no `catch`. 0074 is what that call does on a
  *read-only* view (TCL_ERROR reaches the user); this issue is what it does with
  a *long* value (SIGABRT, `src/util.c:508`). Independent defects on one line of
  Tcl, and whoever fixes either will be standing in the other's code — 0074's
  own fix candidate, wrapping the call or gating the OK path, does **not** stop
  the overflow, because the abort happens inside the command it wraps. Note
  0074's line numbers for that proc are stale (`:2630` / `:2634`; the proc is at
  `:4115` on this tree).
- **0520** — *`select` cannot read the handle `object` hands out: `@<id>` means
  index 0, and the stale selection gets deleted*. Filed the same day from the
  same design pass (its §8 R2), and it composes badly with this one: a reference
  that silently resolves to the wrong object, on a channel that cannot report
  failure.
- `doc/claude/suggestions/voice_control_natural_language_plan.md` (commit
  `722ce61e`) — where these three were first measured (§8 R1) and where
  V1/V2/V3 are tabulated (§7, the Phase 0 blocker table; §6 refers to them at
  line 578). The defects are not
  about voice: B bites any user of the shipped GUI, and A and C bite any program
  that opens the port.
- `doc/xschem_man/xschem_remote.html` — the shipped documentation for this
  feature, including the `nc` recipe at `:69-76` and, at `:39`, the `puts`
  example that this issue measures as no longer working.
- `src/xschem.tcl:5817-5849` — `bespice_getdata`, the sibling socket handler.
  Its listener (`:18069`) has the same missing `-myaddr`, so V1 applies to it
  too; unlike `xschem_getdata` it does **not** evaluate what it receives, so
  defects A and C do not apply to it. It does call `puts` on the socket, so it
  is a casualty of A rather than a cause. Not otherwise measured.
