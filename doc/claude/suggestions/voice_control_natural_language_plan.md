# Voice / natural-language control of xschem — architecture and phased plan

Status: **PROPOSED 2026-08-20.** Branch `fluid-editing`, HEAD `14ac1671`.
Next free issue number: **0519** (386 files in `doc/claude/issues/`, highest in use
0518 — the auto-memory's "next is 0513" is stale).

Every repo claim below carries a `file:line`. Every number was **measured this run**
unless it says *estimate*. Live probes ran on the dev display `:99` against
`xschem_library/examples/mos_power_ampli.sch` (117 instances / 91 wires / 225
objects) with `--tcp_port`; all probe instances were killed and the tracked tree was
never modified.

---

## 0. Verdict

**Build a two-tier broker, not a model.** A single long-lived WSL process
(`xvoiced`) owns the only socket to xschem. Tier 0 is a deterministic table —
utterance → intent id → an **emitter template the broker owns** — and answers in
~7 ms. Tier 1 is an LLM, entered only when Tier 0 misses, and it is a *classifier*:
its output space is `{intent_id, slot spans}`, never a command string and never an
identifier. A deterministic resolver maps each span to a real name drawn from the
live design. Speech comes from the recogniser Windows already ships, driven as a
child process over a pipe. **The whole feature adds two processes and one Tcl file
to this tree; it adds no new IPC and no new C entry point.**

**The single most important finding: xschem already ships the command channel.**
`setup_tcp_xschem` (`src/xschem.tcl:18035`) opens a socket server whose handler
(`xschem_getdata`, `src/xschem.tcl:5851`) evaluates the received line as Tcl at
global scope (`uplevel #0 [list catch ...]`, `:5865`) and writes the result back
(`:5887`). I drove a live GUI instance from a separate Python process — queried it,
highlighted a net, placed an instance, deleted the wrong object, rolled it back —
at a **1.3–2.5 ms median round trip**. The layer the user is asking about is
~15 lines of socket code. Everything hard is upstream of it.

**The second most important finding: that channel currently kills the editor three
different ways, and every one of them returns a reply that looks like success.**
Section 8/R1. Nothing else in this plan may start before those are fixed.

---

## ⚠ Corrections to premises this plan was handed

Read these first; they change decisions.

1. **`xschem hash` does not exist.** The verbs are `hash_file`
   (`src/scheduler.c:6202`) and `hash_string` (`:6219`). Measured:
   `xschem hash [xschem objects]` → `xschem hash: invalid command.`;
   `xschem hash_string [xschem objects]` → `250602971` in 1.31 ms. Any rollback
   loop written against `xschem hash` never terminates on its own condition.

2. **`xschem select <type> @<id>` does not work, and fails two different ways.**
   `select instance` routes through `get_instance()` (`src/scheduler.c:187`), which
   accepts only an all-digit index or an instance *name*; `select wire` does a bare
   `atoi(argv[3])` (`src/scheduler.c:11647`). Measured:
   ```
   xschem object instance @6   -> type instance index 5 layer 1 id 6 name {R0}
   xschem select instance @6   -> "0"    lastsel 0          (nothing selected)
   xschem select instance #5   -> "0"
   xschem object wire  @41     -> type wire index 40 layer 1 id 41
   xschem select wire  @41     -> "1"    selection {{wire 0 1 1}}   (WRONG OBJECT)
   ```
   All three design candidates used `select <type> @<id>` as the *visible
   confirmation* step before mutating. See §8/R2 for the data-loss compound this
   produces.

3. **`xschem get semaphore` is the wrong mid-gesture guard.** `xctx->semaphore` is a
   per-event re-entrancy counter incremented on entry to `callback()`
   (`src/callback.c:5159/5161` and the save/restore sites at `:7474`–`:7921`). A
   socket `fileevent` fires from the idle loop — *between* events — so it always
   reads 0; measured 0 on a live GUI instance. The `get` key is even labelled
   `/* used for debug */` (`src/scheduler.c:5041`). The flag that persists across
   events is `ui_state` (`src/xschem.h:233-358`).

4. **`xschem netlist -erc` is not a modal and does not wedge the channel.**
   Measured: rc 0 in 96 ms, creates a `.infotext` window, `grab current` empty,
   server still answering. It is a screen-covering nuisance, not a hazard. The real
   detonators are `alert_` and `tk_messageBox` (§8/R1).

5. **The `log_action` overflow is in the CIW pane mirror, not the file write, and it
   fires at ~4096 bytes, not 5000.** `src/util.c:491` is
   `char buf[4096]; /* pane copy only; the file write below is unbounded */`; the
   file write is `vfprintf` and is safe; the overflow is the `vsprintf(buf, ...)` at
   `src/util.c:508`, taken because `HAS_SNPRINTF` is undefined on this build (zero
   hits in `config.h` and `Makefile.conf`). It runs *before* the
   `actionlog_suppress_echo` check, so suppressing the echo does not avoid it.

6. **The crash is reachable in the user's ordinary GUI session, with no
   `--logdir`.** Measured on a plain `./src/xschem --tcp_port N <file>`:
   `xschem get actionlog_filename` → `/tmp/Xschem.log.5`. A 4022-byte command
   returned `3.4.8RC`; a **4122-byte command returned `''` and the process took
   SIGABRT (core dumped)**, taking every tab with it. Only `--nolog` avoids it.

7. **Entity-index costs are milliseconds over the wire, not microseconds, and they
   are *editor-freeze* milliseconds.** See §1.3 and §8/R4.

---

## 1. What is already in the tree that this stands on

### 1.1 The command surface

| Fact | Measured |
|---|---|
| `strcmp(argv[1], "...")` sites in `src/scheduler.c` (14,698 lines) | **323** |
| distinct subcommand verbs | **322** |
| verbs carrying a conforming doc comment above the branch | **307 / 322** |
| that doc corpus | **114,510 chars ≈ 28.6k tokens**, 16,850 words |
| just the first (signature) line of each | **7,634 chars ≈ 1.9k tokens** |
| `xschem get` `argv[2]` keys | **132** |
| `xschem set` `argv[2]` keys | **47** |
| `scheduler_readonly_reject()` sites | **43** |
| `return perform_action(...)` sites (the single read-only + log gate) | **29** |

Method for the doc-comment walk: from each first-seen branch line, skip blank lines,
take the immediately preceding `/* ... */` block, keep it if its first word equals
the verb. Re-derive it yourself before quoting it; the recon agents got 304 with a
slightly different block boundary.

Everything funnels through one dispatcher, so there is exactly one thing to teach a
model and exactly one place to enumerate. `xschem help` (`src/scheduler.c:217`) only
opens a browser — **there is no machine-readable catalogue in the binary**, and
`src/extract_scheduler_cmd_help.awk`, which `doc/xschem_man/developer_info.html:507`
says generates the manual's command list, **is not in this tree**.

### 1.2 The action registry — and what it is actually made of

`src/actions.csv` (214 lines) + `src/action_registry.tcl` (526 lines) +
`src/keybindings.csv` + `src/mousebindings.csv`, loaded into the global
`action_table` and surfaced by `command_palette` (`src/action_registry.tcl:491`,
Ctrl+Shift+P) which fuzzy-matches with `fuzzy_subseq_score`
(`src/xschem.tcl:9266`) and runs the row via `palette_run` (`:471`).

Measured over the CSV:

| | |
|---|---|
| data rows / `type=command` / **runnable** (non-empty `command`) | 166 / 163 / **155** |
| rows with a `label` / with `help` | 165 / 165 |
| **runnable rows whose `help` differs from `label`** | **49** |
| `keybindings.csv` / `mousebindings.csv` data rows | **66** / **12** |

And the shape of those 155 runnable commands:

| shape | n |
|---|---|
| bare `xschem <verb>` | **78** |
| does not start with `xschem` (a Tcl proc) | **33** |
| `xschem <verb>` + **constant literal** args (`net_label 2`, `netlist -erc`) | **40** |
| compound (contains `;`) | **4** |
| distinct `xschem` verbs represented | **93** |
| **commands containing a variable or placeholder (`$`, `[`, `<`)** | **0** |

**That last row is the number that decides question (d).** The registry is a
fixed-menu catalogue. `grep -c` for `hilight_netname`, `setprop`, `instance`,
`net_at`, `object_at`, `instance_list`, `list_nets` in the `command` column returns
**0** for every one. There is not a single natural-language↔command pair anywhere in
this tree that carries a user-supplied argument.

### 1.3 Introspection, and what it costs over the wire

Median of 7 warm calls, one TCP connection each, 117-instance fixture:

| command | median | bytes |
|---|---|---|
| `xschem get instances` | 1.45 ms | 3 |
| `xschem symbols` | 1.29 ms | 379 |
| `xschem list_nets` | 1.58 ms | 443 |
| `xschem nets` | 1.65 ms | 1,874 |
| `xschem instance_list` | 1.47 ms | 3,549 |
| `xschem objects` | 1.59 ms | 10,436 |
| `xschem zoom_full` | 11.98 ms | 0 |
| `xschem redraw` | 13.69 ms | 0 |
| **`xschem list_hierarchy`** | **45.76 ms** | 103 |

A five-command entity-index rebuild is **~7.6 ms**; adding `list_hierarchy` makes it
**~53 ms**. The in-process µs figures quoted in the recon are real but irrelevant to
a socket client — and every one of these milliseconds is a **frozen editor**
(§8/R4).

### 1.4 What genuinely helps, and is rare

Session-stable ids on all 7 drawable types plus nets; a uniform `object` /
`objects` descriptor API; `object_at x y` returning the durable handle directly;
`instance_nodemap <inst>` giving pin→net in one call; `instance_pin_coord`; undo on
every mutator via `perform_action`; and an action log that already records every
socket command at canonical-verb granularity, `source`-able, with failures written
as `# failed:` comments (`src/xschem.tcl:5874-5884`). The log also has the
suppression controls a broker needs — `log_action -suppress | -noecho | -result |
-error | -suppressecho | -reset` (`src/scheduler.c:7770`) — so the broker's
scaffolding need not pollute the user's log.

---

## 2. (a) Can Windows supply the speech-to-text?

**Yes, and you should let it. Do not build ASR.** Three routes, ranked.

**Recommended — `System.Speech.SpeechRecognitionEngine` (.NET), offline, driven
from WSL as a child process.** `powershell.exe` is reachable from WSL via binfmt
`WSLInterop`; `Add-Type -AssemblyName System.Speech` succeeds and the engine
instantiates offline (recogniser `MS-1033-80-DESK`, en-US). It consumes **SRGS
grammars**, which is what lets you push the *current schematic's* net and instance
names into the recogniser as a `<one-of>` and get near-exact recognition of them —
Alexa's "dynamic entities" pattern. `System.Speech.Synthesis.SpeechSynthesizer` in
the *same* process gives you TTS for free.

*Transport:* spawn it as a child of `xvoiced` and talk over **stdin/stdout**, not
sockets. This is deliberate: it makes the Windows side incapable of reaching xschem
directly, and it removes the dependency on `.wslconfig networkingMode=mirrored` that
a loopback-TCP design would silently inherit.

*The honest caveat:* Windows Speech Recognition was retired as a *user* feature in
Sept 2024 in favour of Voice Access. `System.Speech`/SRGS remain documented .NET
APIs but are not the future, and the successor **Windows AI Speech Recognition API
is free-form transcription only, with no grammar hook** (and needs an MSIX package
declaring `systemAIModels`; no .NET SDK is installed on the Windows side here).
Therefore: **put the recogniser behind one function, `asr_source()`**, and make the
in-grammar biasing an *optimisation* the rest of the design does not depend on. That
is why the phonetic resolver ladder (§3.4) and the confusion table (§6, Phase 3) are
mandatory rather than optional — they are the only biasing that survives an ASR swap.

**Fallback — all-Linux, zero Windows build.** Microphone capture through WSLg is
already proven:
`PULSE_SERVER=unix:/mnt/wslg/PulseServer ffmpeg -f pulse -i default -ac 1 -ar 16000`
(use `-i default`; the named `PulseAudioRDPSource` returns `Input/output error`).
`ffmpeg` 6.1.1 is installed; `pactl`/`arecord`/`sox` are not. Feed that to
`whisper.cpp base.en`. Costs ~0.3–1.0 s (*estimate*, CPU-only) and loses in-grammar
biasing, but has no MSIX, no licence and no cloud. This is also the path if the
machine is ever not WSL.

**Rejected — Win+H dictation** (delivers keystrokes to the focused window, not text
to a program; unschedulable, unparseable) and **Windows Voice Access shortcuts**
(fixed phrase → action list, no arguments, no stdout — a fun afternoon demo, not an
architecture).

**Trigger: push-to-talk, never a wake word.** A foot pedal presenting as an HID
key (F13) is ideal for an EDA tool — both hands stay on mouse and keyboard. The
arithmetic: a best-in-class wake word's headline is <1 false alarm in 10 hours; on a
6-hour design day that is roughly one *unrequested design edit every two days*,
arriving with no operator intent, on a channel that executes what it is given. A
carrier phrase inside the grammar is safer than an acoustic wake word but still
fires on an in-grammar phrase spoken to a colleague.

**Verified on this machine:** `powershell.exe` reachable; `System.Speech` loads;
recogniser and SAPI voices present; WSLg PulseServer capture works. **Not verified:**
recognition accuracy on this CPU, end-of-speech latency, and whether SRGS dynamic
grammar reload is fast enough to run per schematic-load. Those are Phase-3
measurements, not assumptions.

---

## 3. (b) The command layer

### 3.1 Shape

```
 [Windows]  foot pedal / hotkey  ->  VoiceAsr.ps1  (System.Speech + SRGS + TTS)
                                          | one JSON line per recognition, on stdout
                                          | "SAY <text>" / "RELOAD <grammar>" on stdin
 [WSL]      xvoiced  ---------------------+
              |  --utterance "<text>"   <-- the TESTED seam; no mic required
              |  tier 0: exact/alias table -> intent id            (~1 ms)
              |  tier 1: LLM classifier -> {intent_id, slot spans} (only on tier-0 miss)
              |  resolver: span -> real identifier, from the live entity index
              |  broker:  allow-list -> arity/type check -> emitter template
              |           -> ONE wrapped line -> socket -> verify -> speak
              v
 [xschem]  xschem_getdata (src/xschem.tcl:5851) -> uplevel #0 -> scheduler()
```

Nothing new runs *inside* xschem except one small Tcl helper (`src/voice.tcl`, §7).

### 3.2 IPC decision

**Use the shipped TCP server, unmodified except for the safety patches.**

- Enabled by `--tcp_port N` (`src/options.c:113`, applied `src/xinit.c:3373`, refuses
  <1024 at `:3374`), by `xschem_listen_port` in an xschemrc (commented example at
  `src/xschemrc:573`), or by `setup_tcp_xschem <port>` at runtime
  (`src/xschem.tcl:18035`; port 0 auto-assigns and returns the port).
- **Off by default**: `tcp_port = 0` (`src/globals.c:215`),
  `set_ne xschem_listen_port {}` (`src/xschem.tcl:18637`).
- Connection-per-command — the handler does `close $sock ;# server closes`
  (`:5889`). At 1.3–2.5 ms there is nothing to pool. The client **must**
  `shutdown(SHUT_WR)`: the reader is `while {1} {if {[gets $sock line] < 0} break ...}`
  on a non-blocking channel, so only EOF ends it. The reply has **no framing and no
  trailing newline** — read to EOF.

*Rejected:* `--pipe --script` spawns a **fresh editor** per invocation (that is how
`tests/test_utility.tcl:36-50` drives the suite) — it cannot attach to the session
the user is looking at, so it is disqualified for voice, and useful only as the
Phase-2 verifier. Tk `send` has zero occurrences in the tree and is unreliable under
WSLg. A new Unix socket buys only loopback binding and framing, both of which are
cheaper as the one-line patch V1 and the client-side wrapper below.

### 3.3 The wire format — status framing with zero repo diff

The raw channel cannot distinguish success from failure. Measured: `xschem
bogus_verb_here` → an error *string*; `xschem get total_nonsense_key_zz` → `''`;
`xschem zoom_full extra_bogus_arg` → `''`. The `catch` rc **is** computed
(`src/xschem.tcl:5864`, `set tcp_rc ...`) and then thrown away.

Because the server evals arbitrary Tcl, the broker gets framing for free by sending
one wrapped line:

```tcl
set ::__vw {.drw}
if {[xschem get current_win_path] ne $::__vw} {catch {xschem new_schematic switch $::__vw}}
set ::__vn0 [llength [xschem objects]]
set ::__vrc [catch {PAYLOAD} ::__vres]
list $::__vrc $::__vres [xschem get current_win_path] [xschem get modified] \
     $::__vn0 [llength [xschem objects]] [xschem get ui_state] [xschem get lastsel]
```

Measured: `0 {} .drw 1 225 225 0 0`. **Overhead ~0.1–0.4 ms** — `get instances`
bare 1.79 ms vs wrapped 1.88 ms; `hilight_netname VDD` 1.42 vs 1.78. It is cheaper
than issuing the same queries separately, because it folds N round trips into one,
and it is the **only** proposal in which the executing window is reported
*atomically with the payload* rather than by a second, raceable round trip.

Three rules that go in the spec, because two of them are counter-intuitive:

- **The wrapper is framing, not verification.** It catches Tcl-level errors only.
  `xschem get total_nonsense_key_zz` comes back `rc 0`, empty, through the wrapper.
  Status is a **state re-read**, never a reply. Every mutating intent declares a
  post-condition the broker checks (object-count delta, `object instance R3`
  non-empty, net member count).
- **Globals are `::__v*`-namespaced.** The interpreter is shared with the bespice
  and gtkwave socket clients and ~19k lines of `src/xschem.tcl`.
- **Wrap the scaffolding in `log_action -suppress`** so the user's `Xschem.log`
  receives one canonical line per utterance, not the broker's ~7 index queries. At
  200 utterances/day the unsuppressed version buries the user's own actions under
  >1,400 lines and is not safely `source`-able.

### 3.4 Reference resolution

**The load-bearing rule: the model never emits an identifier — it emits a verbatim
span of the transcript.** `{"op":"hilight_netname","slots":{"net":{"span":"vee dee
dee"}}}`. A deterministic resolver maps the span to a real name from the live
design. This makes the language layer design-independent, structurally eliminates
identifier hallucination, and removes real net names from any synthetic corpus. If a
future contributor lets the model emit a net name directly, the architecture has
failed — put that sentence in the spec.

*The entity index* (~7.6 ms, rebuilt on `modified` transitions, window switch and
`descend`; **never** including `list_hierarchy` on the hot path at 45.8 ms):
`list_nets` and `nets` (names + anchors) · `instance_list` → `{name} {sym}
{cell-type}` in one call · `instance_coord` for geometry · `objects` for stable ids ·
`instance_pins` / `instance_nodemap` / `instance_pin_coord` for terminals ·
`symbols` / `lib_cells` · the 127 speakable devices in `xschem_library/devices/`
(measured) · plus precomputed phonetic and spelled-out keys.

*The resolver ladder,* applied to every span: exact → casefold → spelled-out
digits/letters (`R25` ⇒ "arr twenty five", "arr two five") → Metaphone →
Levenshtein ≤2. A fuzzy hit is legal **only** because the result is made visible
before it is acted on. A tie is refused, never guessed: highlight all candidates,
say "two: R25 and R26 — say one or two", and resolve an ordinal against the *offered
list*, not against a re-run spatial sort.

*Deixis ("this", "here", "that") is gated on freshness, and today it cannot be.*
Measured on a live GUI instance with no pointer in the canvas:
`get mousex_snap`/`mousey_snap` returned `-100 -1370` **unchanged across two
seconds**; `hover` → `''`; `closest_object` → `nosel`. There is no timestamp and no
"pointer is in the drawing area" flag anywhere. And a stale point does not fail
loudly — `xschem object_at 0 0` cheerfully returned `instance 62 1 63`, a
**plausible wrong object**. So: until V12 (§7) lands, **deixis binds only when
`xschem hover` is non-empty**, and a stale or empty pointer refuses any *mutating*
intent outright.

*Geometry conventions the broker must encode.* `Y_TO_SCREEN(y) = ((y) +
xctx->yorigin) * xctx->mooz` (`src/xschem.h:599`) — a positive multiplier, so
**schematic Y grows downward and "above" means a smaller (more negative) y.** In
the fixture the two nmos sit at the same x with y = −530 and y = −180, and the
higher one on screen is −530. Getting this backwards inverts every vertical phrase.
Separately: coordinates are unitless schematic units (`cadsnap` 10, `cadgrid` 20,
`src/scheduler.c:12104/12113`) with 3–4 digit signed values and are **never
speakable**; "make it two microns" is a *property string* (`W=2u`) set via
`setprop`, not a geometric operation. Keep geometry slots and property-string slots
in different type classes.

### 3.5 Window targeting

`tabbed_interface` defaults on; each tab owns an `Xschem_ctx` and the global `xctx`
is the target of every command. `handle_window_switching()`
(`src/callback.c:9745`) points it at whatever the user last looked at, and
`switch_window` early-returns when `xctx->semaphore` is set (`src/xinit.c:1857`).

Policy: **trust focus by default, verify always.** The §3.3 wrapper returns
`current_win_path` in the same `uplevel` as the payload, so a mis-targeted or
dropped switch is *detected*, not silently landed. Explicit targeting
(`xschem new_schematic switch <path>`, enumerated from `xschem windows`) is used
only when the utterance names a window.

**Refuse ambiguity about which editor.** Several xschem instances listening at once
is the normal state on this machine. Discover the port from `$XSCHEM_VOICE_PORT`,
then the xschemrc, then `ss -ltnpH` filtered on `users:(("xschem"`; **if more than
one is listening, refuse and print the list.** Attaching to the wrong editor makes
every other safety mechanism irrelevant, because the fingerprints, the referent
stack and the entity index all describe a different schematic than the one being
mutated.

### 3.6 Safety, undo and confirmation

**Default-deny allow-list**, generated from the verb census then hand-audited, with
a `policy` column. Read-only mode is *not* the safety primitive: measured with
`readonly=1`, `xschem wire` was refused (rc 1), **`xschem undo` was also refused**
(rc 1), and **`xschem saveas` succeeded, writing 131,947 bytes** (rc 0). It refuses
the escape hatch you need and permits the one you don't.

| tier | scope | policy |
|---|---|---|
| green | queries, view, selection/highlight | auto-execute |
| amber | single-object document mutators | execute, announce the delta, arm undo |
| red | `save`, `saveas`, `netlist`, `load`, `reload`, `make_symbol` | **second-channel** confirm |
| black | `exit`, `exit force`, `delete_files`, `clear`, `set no_undo`, and every mode-arming form | no tool exists |

**Red-tier confirmation is a keypress or a click, never a spoken "yes".** A misheard
"yes" is a first-channel error and a second voice utterance does not fix a
first-channel error.

**Black tier includes the mode-arming verbs**, because they leave the editor in a
state where the user's *next click* does something they never asked for. Measured:
`xschem place_symbol devices/res.sym` moved `ui_state` 0 → 8232 and returned
immediately; `xschem escape` restored it to 0 in 26 ms. Voice uses fully
parameterised forms only, and fires `escape` defensively at session start, after any
refused command and after any watchdog timeout.

**Mid-gesture arrival is refused.** Voice is the first driver that is asynchronous
with a live human gesture; no existing test covers it, because tests drive a headless
instance with nobody's hand on the mouse. Only 3 sites in `src/scheduler.c` consult
`xctx->semaphore` (`:3218`, `:3274`, `:5879`) and `perform_action` is not one of
them. Guard on `ui_state`, not `semaphore` (⚠3): refuse every mutator when
`ui_state & (STARTWIRE|STARTSELECT|STARTMOVE|RUBBER|MENUSTART)`.

**Undo: one utterance = one command, verified by content.** Do not build
transactions — they cannot be built correctly from the current API.
`cur/head/tail_undo_ptr` are not exposed (`xschem get undo_depth` → `''`, measured);
refused mutators push nothing, so counting sent commands over-counts and a
compensating undo eats a *previous real* operation; netlisting pollutes the stack
(`src/in_memory_undo.c:615`); and `modified` is **not** restored by undo (measured:
still `1` after the object count returned to 117). So the wrapper's `n0`/`n1` delta
plus `hash_string [xschem objects]` (1.51 ms) is the fingerprint, "undo that" pops
once and re-checks, and a second mismatch **stops and says so** rather than guessing.
`MAX_UNDO` is 80 (`src/xschem.h:339`).

### 3.7 Feedback to the user

`src/voice.tcl` — a new file modelled structurally on `ase::echo`
(`src/ase.tcl:138`), which fans one message out to *both* the CIW pane and the
action log, catch-guarded and correct headless. Do **not** tee inside `ciw_echo`
(`src/ciw.tcl:120`) — that double-logs every action line. Plus spoken confirmation
via `SAY <text>` down the recogniser process's stdin, and the canvas itself, which
is the real feedback channel: select-then-act makes every resolution visible in
~3 ms without asking the user a question.

---

## 4. (c) How similar is this to something that already exists?

**Not novel at any layer, and that is the good news — every piece has a reference
implementation to copy.**

- **Windows supplying ASR:** twenty years of shipped SAPI/SRGS; Voice Access today.
- **A command layer over a running EDA tool:** [`virtuoso-bridge-lite`](https://github.com/Arcadia-1/virtuoso-bridge-lite)
  (649 stars) is *architecturally identical to what xschem already ships* — TCP in,
  `evalstring` of the tool's own scripting language, result out, aimed at Claude
  Code/Cursor. Also [KiCad AI Assistant](https://github.com/paul356/KiCad-AI-Assistant)
  (MCP server, ~90 tools over KiCad's IPC API, **no fine-tuning**) and
  [`ltspice-mcp`](https://github.com/cognitohazard/ltspice-mcp).
- **NL → tool call → app API** is the default 2026 agent architecture (MCP, 10k+
  servers, donated to the Linux Foundation Dec 2025). Not solved: best models sit at
  ~77–78% on the [Berkeley Function-Calling Leaderboard](https://gorilla.cs.berkeley.edu/leaderboard.html).
- **Intents + slots + sample utterances** is literally Alexa's interaction model —
  and Amazon **abandoned it**: Alexa+ (Feb 2025) is rebuilt on LLMs + agentic
  orchestration, and the sample-utterance recommendation tooling was deprecated in
  2025.
- **LLM drives EDA:** [ChipNeMo](https://arxiv.org/abs/2311.00176),
  [ChatEDA](https://arxiv.org/abs/2308.10204), Synopsys.ai Copilot, Cadence agentic
  AI. [A Survey of LLMs for EDA](https://arxiv.org/abs/2501.09655) names script
  generation as an established category.

**Voice control of CAD specifically is a twenty-five-year graveyard.** think3 (2000,
SAPI 5, several hundred voice commands) — company closed. Speak4CAD (2005, claimed
doubled productivity in beta) — gone. Xpresso (SolidWorks, 700+ commands, $99) —
abandoned ~2013. The one survivor, [Voice2CAD](https://www.voice2cad.com/), is an
Excel table of phrase→macro, *not* natural language. The stated reasons for failure
are exactly the ones this plan is designed around: exhaustive coverage of a
hundreds-of-icons surface was judged impossible, recognisers could not resolve
context, and drafting-level work ("a bit to the left") is not practical by voice.
And the one thriving voice-driven-editor product, [Talon](https://talonvoice.com/docs/),
wins by being *less* natural — terse invented grammars — while Serenade's
natural-language framing ("add function factorial") stalled after 2023–24. RSI users
chose precision over naturalness.

**No prior art was found for voice control of a schematic/SPICE tool.** Read that as
a warning label, not an opportunity: it is where competent people walked up and
turned around. **What is genuinely ahead of the field here is the substrate, not the
idea** — a single-verb dispatcher, 132 read-only `get` keys, stable ids on 7 types
plus nets, a uniform `object`/`objects` API, undo on every mutator, a declarative
action registry, a replayable action log and a live command socket. That is a better
tool-calling surface than KiCad or Virtuoso had to build from scratch.

---

## 5. (d) Mine the tree, yes. Fine-tune, not yet.

**The mining instinct is right and undersold. The fine-tuning conclusion is wrong,
and the deciding number is zero.**

**Zero** is the count of natural-language↔command pairs in this tree that carry a
**user-supplied argument** (§1.2, measured). Of 155 runnable registry rows: 78 are
bare verbs, 40 carry *constant literals*, 33 are not `xschem` commands at all, 4 are
compound, and **not one contains a `$`, `[` or `<`**. The corpus everyone proposes to
mine is a fixed-menu catalogue. The utterance class that actually matters —
"highlight net VDD", "make R5 twenty k", "put a cap across the output" — has **no
example anywhere in the tree.** So ≥95% of any training set would be synthesised
paraphrase over a seed of a few hundred distinct English strings (and note only
**49** runnable rows have `help` text that differs from `label`, so the seed is
thinner than the row count suggests), with a documented single-generator
distribution-collapse failure mode and **no held-out human set to detect it** —
there are 0 real utterances, you need 300–500, and you can only get them by shipping
something first.

Three more arguments, each independently sufficient:

1. **What fine-tuning buys is format compliance, and that is available free and with
   a *guarantee*.** Grammar-constrained decoding (GBNF/Outlines/XGrammar) makes
   malformed output structurally impossible, at <40 µs/token. "Usually well-formed"
   is the wrong contract for a channel that executes what it receives.
2. **What fine-tuning structurally cannot buy is reference resolution.** ~43% of
   commands need an argument that exists only in the file currently open. A model
   trained on synthetic identifiers learns to hallucinate *plausible* ones — the
   worst possible outcome. §3.4's span-copy rule removes the need entirely.
3. **The whole language fits in a prompt, twice over.** Signatures alone: **7,634
   chars ≈ 1.9k tokens**. Signatures + full doc prose: **114,510 chars ≈ 28.6k
   tokens**. A whole 117-instance schematic's reference table: **~4.4 KB**. The
   complete API *and* the live design state fit in one context window simultaneously
   — and the model can be shown *this schematic's actual objects at inference time*,
   which no fine-tune can bake in.

**And this machine cannot train anything**: 14 cores, ~7 GiB visible to WSL,
`/dev/dri` absent, no CUDA, no torch/llama.cpp/whisper installed. Training means
renting GPUs, for a feature whose stated point is local control.

**So: mine now, train later, gated.** Build the extractor immediately (§7/V7) — it
feeds the grammar, the allow-list and the emitter templates under *every*
architecture, and it repairs `developer_info.html`, whose generator is missing from
this tree. Log `(audio_sha, transcript, ASR confidence, proposal, resolved call,
emitted Tcl, rc, fingerprint before/after, user verdict)` as one JSONL from day one —
one file that is simultaneously the audit trail, the "what did my voice just do"
answer, and the future corpus. Quarantine 300–500 real utterances as a held-out human
set, collected before anything is tuned. Revisit a QLoRA (Apache-2.0 or MIT base —
Qwen3, Gemma 4, Phi-4; **not** Llama, whose licence is wrong for something that may
ship inside a PDK flow) at **2,000–5,000 real logged pairs**, ~$3–20 of rented GPU
per run, **with constrained decoding still on at inference so it never has to learn
syntax**, and gated on a hard kill criterion: *it must beat the deterministic tier
on the held-out human set.* If the published precedent holds — where the API is
invisible to public training data, fine-tuning goes ~0% → ~70%; where the language is
public-ish, base models were already at 65–75% — xschem's Tcl-shaped, single-verb,
fully-documented surface sits firmly in the second column.

---

## 6. Phased plan

Conventions for every phase: one phase at a time; each independently landable and
revertable; **RED-first or sabotage-verify** anything behavioural
([[green-but-hollow]]); house test style is POSIX `sh`, re-exec through
`bash tests/headless/xvfb_arm.sh --arm`, `ok()`/`bad()`, every launch inside
`timeout 30`, print `RESULT: ALL PASS` (see `tests/headless/test_action_log.sh`);
never `make` while suites run. **Voice and pixels are perceptual deliverables: every
phase ends with `owed.sh add look <what>` at the moment the debt is incurred, and is
reported "suites green, please look" — never "done".** A green suite never
discharges a look debt.

**Phase 0 — the channel stops killing the editor. BLOCKING.** (~1 day)
Patches V1, V2, V3 (§7) plus `tests/headless/test_voice_channel.sh`, which fires
down the socket, and after each asserts `xschem get version` answers within 2 s *and*
the pid is still alive: (a) `update`, (b) `vwait`, (c) `tkwait`, (d) a verb that
raises `alert_`, (e) a 4200-byte command. **All five legs are red today** — that is
the RED-first proof.
*Done when:* the five legs pass; `ss -ltnp` shows `127.0.0.1` only; a 4200-byte
command returns an error instead of a core dump. *Independently useful:* closes
issue 0004 and an unauthenticated remote editor-kill, voice or no voice.

**Phase 1 — a typed command bar that beats the shipped palette.** (~3 days)
`xvoiced` with the `--utterance "<text>"` seam, the exact/alias table, the
allow-list, the §3.3 wrapper, `src/voice.tcl`, and the JSONL log. **No microphone.**
Green tier only.
*Done when:* the 30-utterance set (§8/R3) scores ≥27 correct, 0 wrong-hits, and every
miss produces an explicit "not understood" rather than silence; the allow-list's
modal-freedom suite passes on `:99`; a deliberate sabotage (delete one alias row)
turns it red. *Independently useful on its own:* it is a strictly better
Ctrl+Shift+P.

**Phase 2 — it knows your design.** (~4 days)
Entity index, span-copy resolution, the phonetic ladder, slot-bearing intents
(highlight net X, descend into X, set a property), amber tier with announce+undo,
`log_action -suppress` around the scaffolding.
*Done when:* "highlight net VDD" works on a schematic the tables have never seen; the
differential harness (§8/R2) is green; the user's `Xschem.log` gains exactly one line
per utterance.

**Phase 3 — voice.** (~4 days)
`VoiceAsr.ps1`, PTT, TTS, SRGS generated from the entity index, and the **empirical
confusion table**: TTS the alias phrases through the installed voices, run them back
through the recogniser, harvest the real corruptions ("nmos"→"in moss",
"iopin"→"I O pin"), fold them into the grammar and the eval set. The layer's input is
never clean text; it is always a transcript.
*Done when:* end-of-speech→pixels measured and recorded; the `--utterance` suites
still pass unchanged (proving the mic is the only untested link); **`owed.sh add look`
for the spoken confirmations and the recognition feel.**

**Phase 4 — "that one".** (~4 days)
Referent stack, spatial/ordinal/class filtering over the coordinate table, tie
dialogue, deixis **gated on `hover` being non-empty**.
*Done when:* a tie is refused with both candidates highlighted; a stale pointer
refuses a mutating intent.

**Phase 5 — paraphrase.** (~1 week)
Tier-1 LLM classifier, entered only on tier-0 miss or low ASR confidence. Output
space `{intent_id, slot spans}` under a strict schema or GBNF. Local
(`llama.cpp` + Qwen3 4B) or hosted; if hosted, the pseudonymisation map ships in the
same commit.
*Done when:* the held-out human set improves and the wrong-hit rate does not.

**Phase 6 — corpus, and only maybe a fine-tune.** Ongoing; gated per §5.

---

## 7. What xschem itself must grow

**Required — Phase 0 blockers. All three are wanted independently of voice.**

| id | file:line | change | size |
|---|---|---|---|
| **V1** | `src/xschem.tcl:18042` | `socket -server xschem_server -myaddr $xschem_listen_addr $xschem_listen_port`, with `set_ne xschem_listen_addr 127.0.0.1` beside `set_ne xschem_listen_port {}` at `:18637`. Update `src/xschemrc:573` and `doc/xschem_man/xschem_remote.html`. **Measured today: binds `0.0.0.0` AND `[::]`.** Issue **0004**, OPEN | 1 line + ~6 |
| **V2** | `src/util.c:506-509` | `vsnprintf(buf, S(buf), fmt, args)` unconditionally — `HAS_SNPRINTF` is undefined on this build. Note the overflow is the **CIW pane mirror**, not the `vfprintf` file write, and it runs before the `actionlog_suppress_echo` check | 1 line |
| **V3** | `src/xschem.tcl:5851-5893` | Disarm `fileevent $sock readable {}` **before** the `uplevel`; reply and close before any nested loop can run; make the `puts` rename reentrancy-safe, or drop `redef_puts` from this path entirely (`catch … tclcmd_puts` overwrites the captured output anyway). **File as issue 0519** | ~25 lines + test |

**Decide, do not fudge — V3b.** A client-side shared secret buys nothing: any local
process can open the socket and send raw Tcl without one. Only a check *inside*
`xschem_getdata` makes a token meaningful (~10 lines). Either add it, or write in the
spec that the trust boundary is **"any process running as this user on this box"** —
and stop calling it authenticated.

**High value — Phase 1–2.**

| id | file:line | change | size |
|---|---|---|---|
| **V4** | `src/scheduler.c:187` (`get_instance`) + the `select` arms at `:11620-11700` | Accept the `@<id>` / `#<index>` handle syntax that `object` already understands, on **every** type — and make a failed `select` clear or refuse rather than leaving the previous selection armed. This is a live defect in a shipped API (§8/R2), worth its own issue | ~30 lines |
| **V5** | none — use `log_action -suppress` (`src/scheduler.c:7770`) | Broker discipline, not a patch | 0 |
| **V6** | new `src/voice.tcl` | `voice::echo {msg ?tag?}` structurally copied from `ase::echo` (`src/ase.tcl:138`) → CIW pane + action log, catch-guarded, correct headless, rename-able for test stubs | ~15 lines |
| **V7** | restore `src/extract_scheduler_cmd_help.awk` (cited by `doc/xschem_man/developer_info.html:507`, **absent**) | Emit the 307 doc comments as a machine-readable catalogue. Feeds the grammar, the allow-list and the emitter templates; also repairs the shipped manual. Add a test asserting the generated verb set matches `scheduler.c` | ~20 lines |

**Nice to have — each has a working broker-side workaround today.**

`V8` `xschem instance`/`wire` return the stable id (today `"1"`/`"0"`, measured) —
the workaround is a **set-diff on id**, because `objects` is *not* creation-ordered
(measured: after placing an instance, `lindex [xschem objects] end` was
`{type line index 1 layer 15 id 698}`). · `V9` `get first_sel` emits type *names*
(today `0 -1 0`). · `V10` `instance_bbox` returns clean numbers like
`get bbox_selected` (today prose with `\r\n`). · `V11` expose `undo_depth` (today
`''`). · **`V12` a pointer-freshness signal** — a motion timestamp or an
"in-canvas" flag, without which deixis is guessing (§3.4). · `V13` `objects -geom` /
`-class`. · `V14` extend the read-only gate to `saveas`/`netlist`/`load`/`exit`/
`delete_files`, and stop refusing `undo` under read-only. · `V15` expose
`netlist_dir`, which is a Tcl global and neither a `get` nor a `set` key (measured:
`get` → `''` silently, `set` → `invalid command`) — so a voice "netlist" writes
somewhere the broker cannot query.

**Explicitly NOT needed:** a new IPC channel, a `voice` subcommand in `scheduler()`,
an MCP server, any dispatcher change, a GPU, a trained model, or a dataset.

**Scope statement for page one, because it will otherwise be discovered in Phase 4:**
**voice permanently excludes fluid editing.** Parameterised one-shots exist for the
common cases, but the genuinely gesture-shaped operations — fluid stretch, connected
drag, rotate-drag body-route, i.e. this branch's entire body of work — exist only as
`move_objects start|step|end|abort` phase streams and raw `xschem callback` events.
Voice can *replay* a gesture; it cannot *steer* one, because steering is a continuous
position stream and voice has no positional channel. That is the exact rock every
dead voice-CAD product broke on.

---

## 8. Risks, and the cheapest experiment that retires each

**R1 — The channel kills the editor, and every failure returns success.**
Three kills, all reproduced this run on `:99`:

*(a) The nested-loop wedge.* One command — `set ::w 0; incr ::w; update; set ::w` —
returned **`1`, the correct answer, in 24 ms**; three subsequent `xschem get version`
probes all timed out; the process stayed alive (`Sl`) with **stdout 0 B and stderr
0 B**, because the failure destroys `puts` itself (`rename puts {}` /
`rename ::tcl::puts puts`, `src/xschem.tcl:5867-5868`, non-reentrant). The trigger
surface is not exotic: 81 `update` tokens in `src/*.tcl`, 43 `alert_` sites in
`src/*.c`, 20 in `src/xschem.tcl`, 37 `tk_messageBox` across 6 Tcl files — and
`alert_` runs `tkwait visibility .alert` (`src/xschem.tcl:14132`) **unconditionally,
even when `nowait=1`**, so *every* alert re-enters, not only the blocking ones.

*(b) The 4096-byte editor-kill.* `4022`-byte command → `3.4.8RC`; **`4122`-byte
command → `''` and SIGABRT (core dumped)**; next connection refused. Reproduced with
**no `--logdir`** — `xschem get actionlog_filename` returned `/tmp/Xschem.log.5` in
the plain GUI configuration. Unauthenticated, on `0.0.0.0` and `[::]`.

*(c) The modal compound — the most dangerous, verified end to end on one instance:*
```
xschem wire 950 0 950 100     -> ''    modified 1, wires 92
xschem exit                   -> '0'   in 1281 ms      <- looks exactly like success
winfo children . / grab current -> .__tk__messagebox HAS THE GRAB   <- user locked out
xschem wire 900 0 900 100     -> ''    wires 93        <- voice STILL MUTATING behind it
destroy .__tk__messagebox                              <- == pressing the button
xschem get version            -> TIMEOUT, forever. pid alive (Sl), stdout/stderr 0 B.
```
*Cheapest experiment (~1 h, the repro is already written):*
`tests/headless/test_voice_channel.sh` per Phase 0. It is red on all five legs today;
run it before and after V1/V2/V3. Anything else is unmeasured hope.

**R2 — Silent wrong-referent mutation.** The confirmation step is itself the hazard.
Measured compound, on the live fixture:
```
select instance R0   -> 1   lastsel 1   instances 117
select instance @6   -> 0   lastsel STILL 1, selection STILL {instance 5 1 6}
delete               ->     instances 116          <- R0 deleted
undo                 ->     instances 117, modified STILL 1
```
A failed reference resolution silently deletes the *previous* referent, and rc is 0
throughout — the wrapper cannot see it. Compound this with unguarded mid-gesture
arrival (§3.6) and the inverted Y-axis (§3.4) and it is the failure class that costs
real design work.
*Cheapest experiment (~2 h):* a differential harness — a pool of
`--nogui --pipe --tcp_port` workers on `:99`, fixture **reloaded** between cases
(never trusted to undo, which is refused under read-only and does not restore
`modified`), comparing *executed state* (`objects` + relevant `get` keys) against gold
rather than command strings. Seed it with three assertions that fail today and pin
V4: `select instance @<id>` returns 1 and moves `lastsel`; `select wire @<id>`
selects index 40 not 0; a failed `select` clears the selection. At ~1.5 ms/command a
10,000-case sweep runs in well under a minute, and the same harness is the eval for
any future model.

**R3 — Coverage: the free matcher is not a product.** `fuzzy_subseq_score`
(`src/xschem.tcl:9266`) strips spaces, requires the whole query as an in-order
subsequence, and returns −1 otherwise. I ran **30 realistic utterances** through it
against the live 166-row `action_table` (label, help and id):

- **16 returned −1** — silence, no error, no diagnostic.
- **14 scored**, of which **5 were confidently wrong and 3 of those were mutators**:
  `"delete this"` → `xschem add_pin_stubs`; `"paste it"` → `xschem toggle_ignore`;
  **`"move this"` → `xschem break_wires 1`** (a destructive mutator that deletes
  wires). Also `"undo that"` → `xschem select_same_net` and `"highlight net"` →
  the *net-pin mismatch* action rather than `Highlight selected net/pins`.
- **It is not monotone in politeness**, which is the sharpest result:
  `"undo"` → `edit.undo` ✓ (score 1897) · `"undo it"` → `select.same_net_by_label` ✗
  (1289) · `"undo the last thing"` → −1. Adding the most natural English pronoun to a
  working command flips it to a wrong action, silently. Mechanism:
  `fuzzy_subseq_score {undo that} {Undo}` = −1 (query longer than the label), so a
  longer, wronger label wins by default. Likewise
  `{clear highlights}` vs `Un-highlight all net/pins` = −1 (no `c`), and
  `{go back}` vs `Pop` = −1.

So the "hour zero, zero-new-components demo" is a demo, and `voice/aliases.tsv` plus
**exact-match-before-fuzzy** is load-bearing, not a Phase-4 nicety. Out-of-grammar
silence is the standing VUI defect, and a system that silently ignores its user
teaches that user to stop talking to it inside a week.
*Cheapest experiment (half a day, no ASR, no model, no repo change):* **ask the user
for 30 utterances in their own words**, run each through the live matcher, and print
hit / miss / wrong-hit. My 30 were my guesses at their vocabulary; theirs are the
ones that matter. That single table sizes the alias file, measures the fallback
tier's trigger rate before anything is built, and is the only experiment here that
can still change the architecture. **Do it first.**

**R4 — Every voice command freezes the whole editor for its duration.** Tcl is
single-threaded and the socket handler shares the Tk event loop. Measured: connection
A sent `exec sleep 3`; connection B sent `xschem get version` at t+0.6 s and was
served at **t+3.02 s** (own wait 2,415 ms). So the entity-index rebuild is a *freeze
budget*, not a latency budget: ~7.6 ms for five commands, ~53 ms if `list_hierarchy`
is on the hot path, 96 ms for `netlist`, seconds-to-minutes for `simulate`, with no
cancel and no progress indicator. *Cheapest experiment:* the two-connection probe
above, ~5 minutes, already written. *Mitigation:* keep `list_hierarchy` off the hot
path, rebuild the index on `modified` transitions rather than per utterance, and put
anything over ~200 ms behind an explicit "working…" spoken cue.

**R5 — Deixis binds to a stale pointer and fails plausibly.** §3.4. *Cheapest
experiment:* the three-line probe already run — read `mousex_snap`/`mousey_snap`
twice two seconds apart with the pointer outside the canvas, and confirm `hover` is
the only honest freshness proxy. *Mitigation until V12:* deixis binds only when
`hover` is non-empty; a stale pointer refuses any mutating intent.

**R6 — The ASR foundation is a deprecated API.** §2. *Cheapest experiment:* build
Phase 1–2 entirely against `--utterance`, so the day `System.Speech` disappears you
swap one function and lose only the biasing.

---

## 9. Alternatives that lost, and why

- **A fine-tuned local model as the primary NLU** — §5. Zero argument-bearing pairs
  exist in the tree; the machine cannot train; format compliance is free and
  guaranteed elsewhere; reference resolution is structurally out of reach. Kept as
  Phase 6, gated on real logged pairs and a held-out human set.
- **An LLM agent as the *only* tier, with no deterministic path** — 1.5–3.2 s and a
  token spend for "zoom full" (*estimate*, from the candidate's own budget) against
  ~7 ms measured for a table lookup plus a round trip; plus a hard network
  dependency and net/cell names leaving the machine on every utterance. Kept as
  Tier 1, behind the fast path.
- **A pure SRGS grammar with no fallback tier** — ships with out-of-grammar silence
  as a permanent feature (§8/R3), and its whole biasing advantage rests on a
  deprecated API (§2). Kept as the Tier-0 *recogniser constraint*, not as the NLU.
- **A new Unix socket or FIFO** — redundant with a channel that already exists,
  already logs, and already works. The two things it would buy are a one-line patch
  (V1) and a client-side wrapper (§3.3).
- **`--pipe --script`** — spawns a fresh editor; cannot attach to the user's session.
  Retained only as the Phase-2 verifier.
- **Tk `send`** — zero occurrences in the tree; needs secure X auth; unreliable
  under WSLg.
- **A wake word** — one unrequested design edit every two days at the best published
  false-alarm rate (§2).
- **Read-only mode as the safety tier** — measured: it refuses `undo` and permits
  `saveas` (§3.6). A default-deny allow-list is strictly stronger and is ours to
  control.
- **`xschem get semaphore` as the mid-gesture guard** — always 0 from a socket
  (⚠3). Use `ui_state`.

---

## 10. Open questions — a ruling is needed before work starts

1. **Trust boundary.** Patch `xschem_getdata` to require a shared-secret first line
   (V3b, ~10 lines), or write in the spec that any local process running as you can
   drive and crash your editor? A client-side token is theatre; pick one.
2. **Is a hosted Tier 1 acceptable at all?** Your three workareas (sky130A,
   gf180mcuD, ihp-sg13g2) are open PDKs, so the privacy objection is weak *today* and
   becomes disqualifying the day an NDA'd PDK arrives. Should the pseudonymisation
   map ship in the same commit as the first hosted call, or is Tier 1 local-only?
3. **Is "voice permanently excludes fluid editing" (§7) an acceptable scope
   statement?** If not, the whole plan changes shape.
4. **Which 30 utterances?** §8/R3 needs *your* words, not my guesses. This is the
   first task and it gates the alias file's size.
5. **Push-to-talk device** — foot pedal (F13 HID) or keyboard chord?
6. **Red-tier confirmation** — is a keypress acceptable, or do you want a GUI button?
7. **Should V4 (`select <type> @<id>`) be filed and fixed regardless of voice?** It
   is a live defect in a shipped API that silently deletes the wrong object, and it
   is independent of everything here. Suggested numbering: **0519** the
   `xschem_getdata` wedge, **0520** the `log_action` CIW-mirror overflow, **0521**
   the `select`-by-handle failure. Issue 0004 (TCP auth) is already open and is
   closed by V1.
