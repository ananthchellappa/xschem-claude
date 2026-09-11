# Dossier: the ngspice interactive / `.control` command surface, as it bears on running analyses

Tree: `/home/analog/dev/ngspice`, branch `ver_50`, `git describe` = `ngspice-46-419-gccebdf2a2`.
Built tree probed read-only at `/home/analog/dev/ngspice/build-ver_50/src/ngspice` (reports `ngspice-46+`, build `Thu Sep  3 06:46:24 UTC 2026`).
All line anchors are `path:LINE` relative to the repo root unless stated.
Live transcripts quoted below were produced with `ngspice -p` fed from a heredoc, in
`/tmp/claude-1000/-home-analog-dev-ngspice/aa67b095-6376-4408-9db3-5c2a5c1d3f85/scratchpad/cmdwork/`. Nothing in either repo was modified.

There is **no ngspice manual in this tree** (`doc/` holds only `doc/claude/` and `doc/codex/`;
`man/man1/ngspice.1` is a 1-page stub). Every claim below is therefore sourced from C, from
`ANALYSES` / `README.optran` in the repo root, or from an observed run. Where I mark something
"unverified against the manual", the official manual is at
<https://ngspice.sourceforge.io/docs/ngspice-manual.pdf> and should be cross-checked by the plan author.

---

## 0. TL;DR for the GUI author

1. Every analysis command (`ac dc op tran tf pz sens disto noise sp`) is a one-line wrapper around
   `dosim()` (`src/frontend/runcoms.c:206`), which literally re-forms your arguments into a
   `.<name> <args>` dot card and pushes it through the deck parser. **The interactive command
   grammar for an analysis is identical to its dot-card grammar** — there is exactly one parser.
2. A run is a state machine with three observable states: no circuit / circuit loaded, not running /
   run in progress (paused). `ft_curckt->ci_inprogress` is the flag; `state` is the only command
   that reports it, and `$sim_status` the only variable.
3. `stop` sets breakpoints, `resume` continues, `step [n]` advances n data points, `reset` throws the
   circuit away and re-sources it. Ctrl-C during a run **pauses** (resumable), it does not abort.
4. `save` narrows what a run stores; **the only way to widen it again is `delete all`** — there is no
   `unsave` command anywhere in the tree.
5. `alter`/`altermod` change device/model parameters in the live CKT with no re-parse, which is the
   supported way to do parametric sweeps from a GUI.
6. Console ngspice on Linux has **no progress callback**. `HAS_PROGREP`/`SetAnalyse()` exist only
   under `HAS_WINGUI` or `SHARED_MODULE`. The only progress signal is the ` Reference value : %12.5e\r`
   line printed to stdout every 0.25 s.

---

## 1. The command table

### 1.1 Structure

`struct comm` is documented inline at `src/frontend/commands.c:103-113`:

```
char *co_comname;                 /* The name of the command. */
void (*co_func)(wordlist *wl);    /* The function that handles the command. */
bool co_spiceonly;                /* These can't be used from nutmeg. */
bool co_major;                    /* Is this a "major" command? */
long co_cctypes[4];               /* Bitmasks for command completion. */
unsigned int co_env;              /* print help message on this environment mask */
int co_minargs;                   /* minimum number of arguments required */
int co_maxargs;                   /* maximum number of arguments allowed */
void (*co_argfn)(wordlist*, struct comm*); /* fn that prompts the user */
char *co_help;
```

Two tables exist: `spcp_coms[]` (`src/frontend/commands.c:114`) for the full simulator, and
`nutcp_coms[]` (`src/frontend/commands.c:692`) for the `ngnutmeg` post-processor binary, where every
simulator-only entry has a `NULL` `co_func`. `LOTS` = 1000 and `NLOTS` = 10000
(`src/include/ngspice/cpdefs.h:50-51`) are the "unbounded" `co_maxargs` sentinels.

### 1.2 Dispatch, and the two generic error texts

`src/frontend/control.c:202-247` is the dispatcher:

- lookup is `strcasecmp` (`control.c:204`) — **command names are case-insensitive**;
- `"%s: no such command available in %s\n"` (`control.c:218`) — name not in the table;
- `"%s: command is not implemented\n"` (`control.c:224`) — table entry with `co_func == NULL`
  (the control-flow keywords `while repeat dowhile foreach if else end break continue label goto`
  are such entries, handled earlier by the block parser);
- `"%s: command available only in spice\n"` (`control.c:228`) — `co_spiceonly` in nutmeg;
- `"%s: too few args.\n"` (`control.c:240`) — unless `co_argfn` is set *and* `set interactive`, in
  which case the arg-prompt function runs instead (`control.c:236-238`);
- `"%s: too many args.\n"` (`control.c:243`).

I/O redirection (`>`, `>>`, `<`, `|`) is applied to every command except the five in
`noredirect[]` = `{ "if", "let", "stop", "define", "circbyline" }` (`src/frontend/control.c:62`).
So `eprvcd a b c > my.vcd` works, but `let x = 1 > f` does not redirect.

### 1.3 Complete inventory of `spcp_coms[]`, in table order

Column 3 marks build gating; "spice-only" = `co_spiceonly == TRUE` (absent from `ngnutmeg`).
`min/max` are `co_minargs`/`co_maxargs`.

| # | name | handler | gate | spice-only | min/max | one-line help string in the table |
|---|------|---------|------|-----------|---------|-----------------------------------|
| 1 | `let` | `com_let` | — | no | 0/LOTS | `varname = expr : Assign vector variables.` |
| 2 | `reshape` | `com_reshape` | — | no | 1/LOTS | `vector ... [ shape ] : change the dimensions of a vector.` |
| 3 | `define` | `com_define` | — | no | 0/LOTS | `[[func (args)] stuff] : Define a user-definable function.` |
| 4 | `set` | `com_set` | — | no | 0/LOTS | `[option] [option = value] ... : Set a variable.` |
| 5 | `setcs` | `com_set` | — | no | 0/LOTS | same, "case remains as given" |
| 6 | `option` | `com_option` | — | **yes** | 0/LOTS | `[option] [option = value] ... : Set a simulator option.` |
| 7 | `options` | `com_option` | — | **yes** | 0/LOTS | alias of `option` |
| 8 | `snsave` | `com_snsave` | — | no | 1/1 | `file : Save a snapshot.` |
| 9 | `snload` | `com_snload` | — | no | 2/2 | `file : Load a snapshot.` (needs 2 args: ckt file + data file) |
| 10 | `circbyline` | `com_circbyline` | — | no | 1/LOTS | `line : Enter a circuit line.` |
| 11 | `alias` | `com_alias` | — | no | 0/LOTS | `[[word] alias] : Define an alias.` |
| 12 | `deftype` | `com_dftype` | — | no | 3/LOTS | `spec name pat ... : Redefine vector and plot types.` |
| 13 | `bltplot` / `plot`→`com_bltplot` | | `TCL_MODULE` | **absent here** | | Tcl BLT plotting |
| 14 | `plot` | `com_plot` | `!TCL_MODULE` | no | 1/LOTS | `expr ... [vs expr] [xl xlo xhi] [yl ylo yhi] : Plot things.` |
| 15 | `display` | `com_display` | — | no | 0/LOTS | `: Display vector status.` |
| 16 | `destroy` | `com_destroy` | — | no | 0/LOTS | `[plotname] ... : Throw away all the data in the plot.` |
| 17 | `setplot` | `com_splot` | — | no | 0/4 | `[plotname] : Change the current working plot.` |
| 18 | `setcirc` | `com_scirc` | — | **yes** | 0/1 | `[circuit name] : Change the current circuit.` |
| 19 | `setscale` | `com_setscale` | — | no | 0/2 | `[vecname [vecname]] : Change default scale ...` |
| 20 | `setseed` | `com_sseed` | — | no | 0/1 | `[seed value] : Reset the random number generator ...` |
| 21 | `transpose` | `com_transpose` | — | no | 1/LOTS | matrix transposition on multi-D vectors |
| 22 | `gnuplot` | `com_gnuplot` | — | no | 2/LOTS | `file plotargs : Send plot to gnuplot.` |
| 23 | `pyplot` | `com_pyplot` | — | no | 1/LOTS | `[file] plotargs : Send plot to matplotlib` |
| 24 | `wrdata` | `com_write_simple` | — | no | 2/NLOTS | `file plotargs : Send plot data to file.` |
| 25 | `wrs2p` | `com_write_sparam` | — | no | 0/LOTS | `file : Send s-param data to file.` |
| 26 | `hardcopy` | `com_hardcopy` | — | no | 0/LOTS | `file plotargs : Produce hardcopy plots.` |
| 27 | `asciiplot` | `com_asciiplot` | — | no | 1/LOTS | `plotargs : Produce ascii plots.` |
| 28 | `write` | `com_write` | — | no | 0/LOTS | `file expr ... : Write data to a file.` |
| 29 | `compose` | `com_compose` | — | no | 2/LOTS | `var parm=val ... : Compose a vector.` |
| 30 | `unlet` | `com_unlet` | — | no | 1/LOTS | `varname ... : Undefine vectors.` |
| 31 | `remzerovec` | `com_remzerovec` | — | no | 0/LOTS | `remove zero length vectors.` |
| 32 | `print` | `com_print` | — | no | 1/LOTS | `[col] expr ... : Print vector values.` |
| 33 | `sndprint`, `sndparam` | | `HAVE_LIBSNDFILE && HAVE_LIBSAMPLERATE` | **absent here** | | audio output |
| 34 | `esave` | `EVTsave` | `XSPICE` | no | 1/LOTS | `all \| none \| node node ... : Save event values.` |
| 35 | `eprint` | `EVTprint` | `XSPICE` | no | 1/LOTS | `node node ... : Print event values.` |
| 36 | `eprvcd` | `EVTprintvcd` | `XSPICE` | no | 1/LOTS | `[-a] [-t timescale] node node ... : Print event values into VCD file.` |
| 37 | `edisplay` | `EVTdisplay` | `XSPICE` | no | 0/0 | `: Print all event nodes.` |
| 38 | `codemodel` | `com_codemodel` | `XSPICE` | no | 1/1 | `library ... : Loads the code model libraries.` |
| 39 | `osdi` | `com_osdi` | `OSDI` | no | 1/LOTS | `library ... : Loads a osdi library.` |
| 40 | `use` | `com_use` | `DEVLIB` | **absent here** | | device libraries |
| 41 | `load` | `com_load` | — | no | 1/LOTS | `file ... : Load in data.` |
| 42 | `cross` | `com_cross` | — | no | 2/LOTS | `vecname number [ vector ... ]` |
| 43 | `undefine` | `com_undefine` | — | no | 0/LOTS | `[func ...]` |
| 44 | **`op`** | `com_op` | — | **yes** | 0/LOTS | `[.op line args] : Determine the operating point of the circuit.` |
| 45 | **`tf`** | `com_tf` | — | **yes** | 0/LOTS | help text says "Do a transient analysis" — **copy/paste bug**, `commands.c:317` |
| 46 | **`tran`** | `com_tran` | — | **yes** | 0/LOTS | `[.tran line args] : Do a transient analysis.` |
| 47 | **`pss`** | `com_pss` | `WITH_PSS` | **absent here** | 0/LOTS | `[.pss line args] : Do a periodic state analysis.` |
| 48 | **`sp`** | `com_sp` | `RFSPICE` | **present** | 0/LOTS | `[.sp line args] : Do an S-parameter analysis.` |
| 49 | **`ac`** | `com_ac` | — | **yes** | 0/LOTS | `[.ac line args] : Do an ac analysis.` |
| 50 | **`dc`** | `com_dc` | — | **yes** | 0/LOTS | `[.dc line args] : Do a dc analysis.` |
| 51 | **`pz`** | `com_pz` | — | **yes** | 0/LOTS | `[.pz line args] : Do a pole / zero analysis.` |
| 52 | **`sens`** | `com_sens` | — | **yes** | 0/LOTS | `[.sens line args] : Do a sensitivity analysis.` |
| 53 | **`disto`** | `com_disto` | — | **yes** | 0/LOTS | `[.disto line args] : Do an distortion analysis.` |
| 54 | **`noise`** | `com_noise` | — | **yes** | 0/LOTS | `[.noise line args] : Do a noise analysis.` |
| 55 | `listing` | `com_listing` | — | **yes** | 0/LOTS | `[logical] [physical] [deck] : Print the current circuit.` |
| 56 | `edit` | `com_edit` | — | **yes** | 0/1 | `[filename] : Edit a spice deck and then load it in.` |
| 57 | `mc_source` | `com_mc_source` | — | **yes** | 0/0 | `: Re-source the actual circuit deck for MC simulation.` |
| 58 | `dump` | `com_dump` | — | **yes** | 0/0 | `: Print a dump of the current circuit.` |
| 59 | `fft` | `com_fft` | — | no | 1/LOTS | `vector ... : Create a frequency domain plot with FFT.` |
| 60 | `psd` | `com_psd` | — | no | 2/LOTS | `vector ... : Create a power spetral density plot with FFT.` (sic) |
| 61 | `fourier` | `com_fourier` | — | no | 1/LOTS | `fund_freq vector ... : Do a fourier analysis of some data.` |
| 62 | `spec` | `com_spec` | — | no | 4/LOTS | `start_freq stop_freq step_freq vector ...` |
| 63 | `meas` | `com_meas` | — | no | 1/LOTS | `various ... : User defined signal evaluation.` |
| 64 | `show` | `com_show` | — | **yes** | 0/LOTS | `devices ... : parameters ... : Print out device summary.` |
| 65 | `showmod` | `com_showmod` | — | **yes** | 0/LOTS | `models ... : parameters ... : Print out model summary.` |
| 66 | `sysinfo` | `com_sysinfo` | — | **yes** | 0/LOTS | `Print out system info summary.` |
| 67 | `alter` | `com_alter` | — | **yes** | 0/LOTS | `devspecs : parmname value : Alter device parameters.` |
| 68 | `altermod` | `com_altermod` | — | **yes** | 0/LOTS | `devspecs : parmname value : Alter model parameters.` |
| 69 | `alterparam` | `com_alterparam` | — | **yes** | 1/LOTS | `devspecs : parmname value : Alter .param parameters.` |
| 70 | **`resume`** | `com_resume` | — | **yes** | 0/0 | `: Continue after a stop.` |
| 71 | **`state`** | `com_state` | — | **yes** | 0/LOTS | `(unimplemented) : Print the state of the circuit.` |
| 72 | **`stop`** | `com_stop` | — | **yes** | 0/LOTS | `[stop args] : Set a breakpoint.` |
| 73 | `trace` | `com_trce` | — | **yes** | 0/LOTS | `[all] [node ...] : Trace a node.` |
| 74 | **`save`** | `com_save` | — | **yes** | 0/LOTS | `[all] [node ...] : Save a spice output.` |
| 75 | `iplot` | `com_iplot` | — | **yes** | 0/LOTS | `[-w width] [-d initial_steps] [-o] [all] [node ...] : Incrementally plot nodes.` |
| 76 | **`status`** | `com_sttus` | — | **yes** | 0/0 | `: Print the current breakpoints and traces.` |
| 77 | **`delete`** | `com_delete` | — | **yes** | 0/LOTS | `[all] [break number ...] : Delete breakpoints and traces.` |
| 78 | **`step`** | `com_step` | — | **yes** | 0/1 | `[number] : Iterate number times, or one.` |
| 79 | **`remcirc`** | `com_remcirc` | — | **yes** | 0/0 | `: Remove current citcuit.` (sic) |
| 80 | **`reset`** | `com_rset` | — | **yes** | 0/0 | `: Terminate a simulation after a breakpoint (formerly 'end').` |
| 81 | **`run`** | `com_run` | — | **yes** | 0/1 | `[rawfile] : Run the simulation as specified in the input file.` |
| 82 | `aspice` | `com_aspice` | `OK_ASPICE` | no | 1/2 | **stub** — see §12 |
| 83 | `jobs` | `com_jobs` | `OK_ASPICE` | no | 0/0 | **stub** |
| 84 | `rspice` | `com_rspice` | `OK_ASPICE` | no | 0/LOTS | **stub** |
| 85 | `bug` | `com_bug` | — | no | 0/0 | `: Report a %s bug.` |
| 86 | **`where`** | `com_where` | — | **yes** | 0/0 | `: Print last non-converging node or device` |
| 87 | `newhelp` | `com_ahelp` | — | no | 0/LOTS | `[command name] ... : help.` |
| 88 | `tutorial` | `com_ghelp` | — | no | 0/LOTS | hierarchical doc browser |
| 89 | `help` | `com_ghelp` | — | no | 0/LOTS | hierarchical doc browser |
| 90 | `oldhelp` | `com_help` | — | no | 0/LOTS | `[command name] ... : Print help.` |
| 91 | `removecirc` | `com_removecirc` | — | **yes** | 0/1 | `[circuit name] : Remove the current circuit from memory.` |
| 92 | `quit` | `com_quit` | — | no | 0/1 | `: Quit %s.` |
| 93 | `source` | `com_source` | — | no | 1/LOTS | `file : Source a %s file.` |
| 94 | `shift` | `com_shift` | — | no | 0/2 | shift argv or a list var |
| 95 | `unset` | `com_unset` | — | no | 1/LOTS | `varname ... : Unset a variable.` |
| 96 | `unalias` | `com_unalias` | — | no | 1/LOTS | |
| 97 | `history` | `com_history` | — | no | 0/2 | `[-r] [number]` |
| 98 | `echo` | `com_echo` | — | no | 0/NLOTS | |
| 99 | `shell` | `com_shell` | — | no | 0/LOTS | |
| 100 | `rusage` | `com_rusage` | — | no | 0/LOTS | `[resource ...] : Print current resource usage.` |
| 101 | `cd` | `com_chdir` | — | no | 0/1 | |
| 102 | `getcwd` | `com_getcwd` | — | no | 0/1 | |
| 103 | `version` | `com_version` | — | no | 0/LOTS | |
| 104 | `diff` | `com_diff` | — | no | 0/LOTS | `plotname plotname [vec ...] : 'diff' two plots.` |
| 105 | `rehash` | `com_rehash` | — | no | 0/0 | |
| 106-116 | `while repeat dowhile foreach if else end break continue label goto` | NULL | — | no | — | control structures, handled by the block parser |
| 117 | `cdump` | `com_cdump` | — | no | 0/0 | `: Dump the current control structures.` |
| 118 | `mdump` | `com_mdump` | — | **yes** | 0/1 | `outfile: Dump the current matrix.` |
| 119 | `mrdump` | `com_rdump` | — | **yes** | 0/1 | `outfile: Dump the current RHS to file.` |
| 120 | `settype` | `com_stype` | — | no | 2/LOTS | `type vec ... : Change the type of a vector.` |
| 121 | `strcmp` | `com_strcmp` | — | no | 3/3 | |
| 122 | `strstr` | `com_strstr` | — | no | 3/3 | |
| 123 | `strslice` | `com_strslice` | — | no | 4/4 | |
| 124 | `fopen` | `com_fopen` | — | no | 2/3 | |
| 125 | `fread` | `com_fread` | — | no | 2/3 | |
| 126 | `fclose` | `com_fclose` | — | no | 1/1 | |
| 127 | `linearize` | `com_linearize` | — | no (**yes in nutmeg table**) | 0/LOTS | `[ vec ... ] : Convert plot into one with linear scale.` |
| 128 | `cutout` | `com_cutout` | — | no | 0/LOTS | `[ vec ... ] : Cut out portion of a vector.` |
| 129 | `devhelp` | `com_devhelp` | — | no | 0/5 | `devspecs : show device information.` |
| 130 | `inventory` | `com_inventory` | — | **yes** | 0/0 | `: Print circuit inventory` |
| 131 | `optran` | `com_optran` | — | **yes** | **6/6** | `: Prepare optran by setting 6 flags` |
| 132 | `wrnodev` | `com_wric` | — | **yes** | 0/1 | `: Save current node voltage values to file` |
| 133 | `check_ifparm` | `com_check_ifparm` | `HAVE_TSEARCH` | **yes**, present here | 0/0 | developer parameter-descriptor check |

Build-gate status **in this configured tree** (`build-ver_50/src/include/ngspice/config.h`):
`XSPICE` = 1 (`:579`), `OSDI` = 1 (`:502`), `RFSPICE` = 1 (`:535`), `KLU` (`:463`),
`HAVE_TSEARCH` = 1 (`:414`), `HAVE_LIBFFTW3` (`:168`); **undefined**: `CIDER` (`:11`),
`WITH_PSS` (`:576`), `TCL_MODULE` (`:564`), `SHARED_MODULE` (`:550`), `EXPERIMENTAL_CODE` (`:26`),
`HAVE_LIBSNDFILE` (`:192`), `HAVE_LIBSAMPLERATE` (`:189`), `FTEDEBUG` (`:35`).
`WITH_HB` and `DEVLIB` and `OK_ASPICE` are defined nowhere in the tree.
Configure flags: `--enable-pss` sets `WITH_PSS` (`configure.ac:1082-1085`); `--disable-sp` clears
`RFSPICE` (`configure.ac:1220-1228`, on by default); `--enable-cider` sets `CIDER` (`configure.ac:1215-1218`).
Confirmed live: `pss: no such command available in ngspice`, `use:`/`bltplot:`/`sndprint:` likewise;
`sp` exists and answers `Error: there aren't any circuits loaded.`; `esave` exists.

### 1.4 What `nutcp_coms[]` loses

The `ngnutmeg` binary keeps the vector/plot commands and drops all simulator control. Notably absent
or `NULL`-functioned there: `option`(unless `EXPERIMENTAL_CODE`), `snsave`, `snload`, `circbyline`,
`destroy` is kept, `setcirc` kept but NULL, `wrnodev`, `optran`, `alterparam`, `mc_source`,
`remcirc`, `where`, `iplot`, `sysinfo`, `mdump`, `mrdump`, `psd` is kept, `meas` **is absent**,
`spec` kept, `cutout` kept, `linearize` kept (`src/frontend/commands.c:1108`, and there marked
`co_spiceonly = TRUE`, which contradicts the `spcp_coms` entry at `:655` — a latent inconsistency,
harmless in practice because nutmeg's own table is the one it uses).

---

## 2. `dosim()` — the single entry point for every analysis

`src/frontend/runcoms.c:206-390`. Every one of `pz op dc ac tf tran sens disto noise pss sp run`
is a two-line wrapper (`runcoms.c:125-202`) calling `dosim("<name>", wl)`.

### 2.1 The contract, in order of execution

1. `OUTsaveMissClear()` (`runcoms.c:220`) — forgets the "save name differs only in case" warnings of
   the previous run (`doc/codex/issues/0057`).
2. Output file type: `bool ascii = AsciiRawFile;` (`runcoms.c:230`). `AsciiRawFile = 0` by default
   (`src/conf.c:32`), overridden by env `SPICE_ASCIIRAWFILE` (`src/misc/ivars.c:103-105`), then
   overridden again by the shell variable `filetype` (`runcoms.c:242-254`):
   `binary` → binary, `ascii` → ascii, anything else →
   `"Warning: strange file type \"%s\" (using \"ascii\")\n"` and ascii.
   **Default is binary.**
3. `if (!ft_curckt)` → `"Error: there aren't any circuits loaded.\n"`, return 1 (`runcoms.c:255-257`).
4. `if (ft_curckt->ci_ckt == NULL)` → `"Error: circuit not parsed.\n"`, return 1 (`runcoms.c:258-260`).
   This is the `set noparse` case.
5. For every **other** circuit in `ft_circuits` that is `ci_inprogress`:
   `"Warning: losing old state for circuit '%s'\n"` and its flag is cleared (`runcoms.c:262-269`).
   **Note the asymmetry**: the *current* circuit's in-progress state is silently discarded — see §4.6.
6. `NIresetwarnmsg()` (`runcoms.c:280`) resets the per-run convergence warning counters.
7. `ft_setflag = TRUE; ft_intrpt = FALSE;` (`runcoms.c:286-287`) — from here to the end of the run,
   SIGINT sets a flag instead of longjmping (see §7).
8. Rawfile: only when the command is literally `run` **and** an argument was given
   (`dofile`, `runcoms.c:232-234`). Empty word → `stdout`. Otherwise `fopen(name, ascii ? "w" : "wb")`;
   on failure `perror(name)`, `ft_setflag = FALSE`, return 1. On success it prints
   `ASCII raw file "%s"` or `binary raw file "%s"` (`runcoms.c:288-311`).
   `last_used_rawfile` is set from the name, or NULL (`runcoms.c:316-325`) — that is what `resume`
   re-opens in append mode.
9. `ft_curckt->ci_inprogress = TRUE; cp_vset("sim_status", CP_NUM, &err /*0*/);` (`runcoms.c:327-328`).
10. `err = if_run(ft_curckt->ci_ckt, what, ww, ft_curckt->ci_symtab);` (`runcoms.c:341`).
11. Return-code mapping (`runcoms.c:342-361`):
    - `1` → `"%s simulation interrupted\n"`, `err` reset to 0, **`ci_inprogress` left TRUE** (resumable);
    - `2` → `"%s simulation(s) aborted\n"`, `ci_inprogress = FALSE`, `$sim_status = 1`;
    - `3` → `"%s simulation not started\n"`, `ci_inprogress = FALSE`, `$sim_status = 1`;
    - otherwise → `ci_inprogress = FALSE`, `$sim_status` stays 0.
12. Rawfile closed; if `ftell == 0` the file is `unlink`ed (`runcoms.c:363-372`).
13. `ft_curckt->ci_runonce = TRUE; ft_setflag = FALSE;` (`runcoms.c:374-375`).
14. If no error and `ci_last_an` and `ci_meas`: `do_measure(ft_curckt->ci_last_an, FALSE)`
    (`runcoms.c:386-388`) — the deck's `.measure` lines run here, after the analysis.

### 2.2 `if_run()` — the command line becomes a dot card

`src/frontend/spiceif.c:245-436`.

- For `tran ac dc op pz disto adjsen sens tf noise` (+`pss` if `WITH_PSS`, +`sp` if `RFSPICE`,
  +`hb` if `WITH_HB`) it flattens the wordlist and builds `".%s"` (`spiceif.c:279-281`), fills a
  `struct card` and runs `INPpas2()` on it (`spiceif.c:358`) against a freshly-created **special
  task** `ci_specTask` (`spiceif.c:311-322`). If the parse fails:
  `"Error: %sin   %s\n\n"` with the parser's message and the reconstructed line (`spiceif.c:360-363`),
  return 2 → `"%s simulation(s) aborted"`.
- **Consequence for the GUI**: `tran 1n 1u uic`, `.tran 1n 1u uic` and `ac dec 10 1 1meg` are parsed by
  exactly the same code path as the dot card. There is no separate interactive grammar, and no
  per-analysis option table specific to the command form.
- Each interactive analysis command **deletes the previous special task** first
  (`spiceif.c:295-308`), so only one interactively-defined analysis exists at a time; and it
  re-creates an `options` analysis inside the special task (`spiceif.c:330-352`) so a `.options`
  context exists.
- For `run` it switches to the **default task** built from the deck (`ci_defTask`, `spiceif.c:373-374`).
  If that task has no jobs: `"Warning: No job (tran, ac, op etc.) defined:\n"` to stderr and return 3
  — *unless* `ft_batchmode`, in which case it falls through (`spiceif.c:375-384`, comment calls this
  "a hack to re-enable 'make check'").
- Then `ft_sim->doAnalyses(ckt, 1, ci_curTask)` for a fresh run, or `doAnalyses(ckt, 0, ...)` for
  `resume` (`spiceif.c:416` / `:425`). On non-OK it prints `ft_sperror(err, "doAnalyses")`, i.e.
  literally `doAnalyses: <message>\n` where `<message>` comes from `SPerror()`
  (`src/spicelib/parser/sperror.c:18-119`); `E_PAUSE` → `"pause requested"`, `E_NOTFOUND` →
  `"not found"`, `E_ITERLIM` → `"iteration limit reached"`, `E_SINGULAR` → `"matrix is singular"`,
  `E_TIMESTEP` → `"timestep too small"`, etc. `E_PAUSE` maps to return 1 (interrupted), everything
  else to 2 (aborted).
- Any other `what` → `"if_run: Internal Error: bad run type %s\n"` (`spiceif.c:434`).

### 2.3 Job ordering — **not deck order**

`CKTdoJob()` (`src/spicelib/analysis/cktdojob.c:29-219`) loops over analysis **types** in the order of
`analInfo[]` and, within a type, over the job list. The comment at `cktdojob.c:176` says
"Analysis order is important". `analInfo[]` (`src/spicelib/analysis/analysis.c:36-59`) is:

`OPTinfo, ACinfo, DCTinfo, DCOinfo, TRANinfo, PZinfo, TFinfo, DISTOinfo, NOISEinfo, SENSinfo, [PSSinfo], [SEN2info], [SPinfo], [HBinfo]`

so `.ac` runs before `.dc` before `.op` before `.tran` before `.pz` … regardless of the order the dot
cards appear in the deck. `CKTnewAnal` prepends (`src/spicelib/analysis/cktnewan.c:34`), so multiple
jobs of the same type run in **reverse** deck order.

Verified live with a deck containing `.tran 10u 100u` then `.ac dec 5 1 1k`: `run` produced
`No. of Data Rows : 16` (the AC sweep) before the transient's `No. of Data Rows : 60`, and the raw
file written by `run out1.raw` has `Plotname: AC Analysis` at line 4 and `Plotname: Transient Analysis`
at line 81.

### 2.4 `reset` semantics inside `doAnalyses`

`reset == 1` (a fresh `run`/`tran`/…): zeroes `CKTdelta`, `CKTtime`, `CKTcurrentAnalysis`, then
`CKTunsetup` → `CKTsetup` → `CKTtemp` (`cktdojob.c:135-172`). `reset == 0` (`resume`) skips all of
that. Also, on every job start `inp_evaluate_temper(ft_curckt)` re-evaluates all `temper`-dependent
device and model expressions (`cktdojob.c:130`), and `CKTdoJob` copies the *task's* `TSK*` fields into
the `CKT*` fields (`cktdojob.c:53-120`) — this is why `option` (which writes `ci_defOpt`) takes effect
at the start of the next run and not immediately.

---

## 3. `run` and the batch launch routes

`com_run(wl)` = `dosim("run", wl)` (`runcoms.c:392-396`); `ft_dorun(char *file)` is the C entry used by
`main()` (`runcoms.c:399-408`).

- `run` with no argument: run the deck's dot-card analyses, results into in-memory plots.
- `run <rawfile>`: same, but every plot is streamed to `<rawfile>` instead (`ft_getOutReq`,
  `runcoms.c:412-427`, feeding `beginPlot`'s `run->writeOut` at `outitf.c:485-486`). **When a rawfile
  is active the data is *not* kept in memory** — `fileInit(run)` is used instead of `plotInit(run)`
  (`outitf.c:488-491`), so `display`/`plot` afterwards show nothing new.
- `run ""` (empty word) writes to stdout (`runcoms.c:290-292`).

Command-line launch routes (`src/main.c`):
- `-r FILE` / `--rawfile=FILE` sets the `rawfile` variable (`main.c:1084-1086`); the default is
  `ft_rawfile = "rawspice.raw"` (`main.c:96`).
- `-b` batch: at `main.c:1560-1594`, if `-r` was given (`rflag`) it calls `ft_dorun(ft_rawfile)` and
  **ignores every dot card except `.save`** (comment at `main.c:1561-1564`); with XSPICE it also calls
  `EVTdiscard()` first, so **no event data is written to the rawfile**. Without `-r` it calls
  `ft_savedotargs()` (which converts `.plot/.print/.four/.op/.tf/.meas` into save requests) and then
  `ft_dorun(NULL)` plus `ft_cktcoms(FALSE)`. If neither, and a `.control` section already ran a
  simulation (`$sim_status == 0`), it prints
  `"Note: Simulation executed from .control section \n"`; otherwise the familiar
  `"Error: incomplete or empty netlist\n       or no \".plot\", \".print\", or \".fourier\" lines in batch mode;\nno simulations run!\n"`
  (`main.c:1588-1592`).
- `-a` / `--autorun` sets the `addcontrol` variable, which makes the netlist reader **inject** a
  control section before `.end` (`src/frontend/inpcom.c:3292-3317`):
  `.control / strcmp __flag $curplot const / if $__flag eq 0 / run / end / [write $rawfile] / .endc`.
- `-p` / `--pipe`: read commands from stdin, which is the mode a GUI should drive if it does not use
  `libngspice`. All transcripts in this dossier use it.
- `-s` server mode: requires a loaded circuit, calls `ft_dorun("")` (stdout rawfile) and exits
  (`main.c:1550-1558`).
- `-o FILE`, `-i`, `-n` (skip spinit/.spiceinit), `-c FILE`, `-D var[=val]`, `--soa-log=FILE`,
  `-t TERM`, `-q` (`main.c:954-970`, help text at `main.c:740-758`).

---

## 4. Interactive control of a running analysis

### 4.1 The pause chain, end to end

```
com_stop / SIGINT
   -> dbs breakpoint list          (src/frontend/breakp2.c:19, ft_curckt->ci_dbs)
   -> ft_bpcheck() returns FALSE   (src/frontend/breakp.c:501-566)
   -> shouldstop = TRUE            (src/frontend/outitf.c:840-841, :1931-1933, :2077-2078)
   -> OUTstopnow() returns 1       (src/frontend/outitf.c:1712-1719; also fires on ft_intrpt)
   -> SPfrontEnd->IFpauseTest()    (wired at src/main.c:218 / src/sharedspice.c:258)
   -> analysis returns E_PAUSE     (dctran.c:455-458, acan.c:243-246, dctrcurv.c:470-473,
                                    noisean.c:365-369, noisesp.c:246-250, distoan.c:257-259,
                                    cktpzstr.c:189-191, cktsens.c:364, span.c:656-659, dcpss.c:1030-1033)
   -> CKTdoJob returns E_PAUSE
   -> if_run returns 1
   -> dosim prints "<what> simulation interrupted", leaves ci_inprogress TRUE
```

Note the set of analyses that can pause: **tran, ac, dc, noise (both), disto, pz, sens, sp, pss**.
`op` and `tf` have no `IFpauseTest` call — they are single-shot and cannot be stopped or stepped.

### 4.2 `stop` — `src/frontend/breakp.c:38-206`

Grammar (conjunctions are chained with `db_also`, so several conditions on one line must **all** hold):

```
stop after <integer>
stop when <lhs> <cond> <rhs>
stop when <vec>=<value>            (single-word form, split at breakp.c:88-110)
```
`<cond>` ∈ `eq | = | ne | gt | > | lt | < | <> | ge | >= | le | <=` (`breakp.c:126-146`).
`<lhs>`/`<rhs>` are parsed with `ft_numparse`; if that fails the token is stored as a node name
(`breakp.c:117-124`, `:155-163`).

Behaviour:
- `"No circuit loaded. Stopping is not possible.\n"` if `ft_curckt == NULL` (`breakp.c:42-44`).
- If the shell variable `interp` is set it prints
  `"Note: Stop condition has to fit the interpolated time data!\n\n"` and uses an ULP-tolerant
  comparison with a "no new time step since last stop" guard (`breakp.c:47-53`, `:600-604`, `:611-616`).
- Any parse failure → `"Syntax error parsing breakpoint specification.\n"` (`breakp.c:198`).
- Each accepted `stop` gets the next `debugnumber` (`breakp2.c:22`), added to the `CT_DBNUMS`
  completion class (`breakp.c:182-184`).
- **Special case**: `stop when time > <t>` issued while a transient run is already in progress also
  calls `CKTsetBreak()` so the integrator lands exactly on `<t>` — or, if `<t>` is in the past,
  `"\nWarning: command 'stop' would set breakpoint in the past, ignored!\n    time: %g, bkpt: %e\n\n"`
  (`breakp.c:186-196`).
- The comparison itself is `satisfied()` (`breakp.c:570-634`); a missing node yields
  `"Error: %s: no such node\n"` and FALSE.
- Condition met at run time prints, to `cp_err`:
  `"%-2d: condition met: stop " + printcond(...) + "\n"` (`breakp.c:546-550`, `printcond` at `:651-687`).

**`stop after N` fires only on exact equality** (`iteration == dt->db_iteration`, `breakp.c:521-525`),
so it triggers once and `resume` runs to the end. **`stop when X > Y` re-fires on every subsequent
data point**, so `resume` immediately re-stops until you `delete` the breakpoint. Verified:

```
ngspice -> stop when time > 500u
ngspice -> tran 10u 1m
1 : condition met: stop  when time > 0.0005
doAnalyses: pause requested
tran simulation interrupted
ngspice -> resume
1 : condition met: stop  when time > 0.0005
doAnalyses: pause requested
simulation interrupted        <- one data point later
```

`stop` also applies **across analyses**: `stop after 20` set before a `tran` also stopped a
subsequent `ac dec 10 1 1meg` at its 20th point.

### 4.3 `resume` — `src/frontend/runcoms2.c:62-170`

- `"Error: there aren't any circuits loaded.\n"` / `"Error: circuit not parsed.\n"` guards (`:77-83`).
- **If nothing is in progress it prints `"Note: run starting\n"` and calls `com_run(NULL)`**
  (`:86-90`) — i.e. `resume` degenerates into `run`, which for a deck with no dot cards yields
  `"Warning: No job (tran, ac, op etc.) defined:"` + `"run simulation not started"`. Verified live.
- `reset_trace()` and a scan for `DB_IPLOT`/`DB_IPLOTALL` sets the `resumption` flag so iplot redraws
  its grid (`:94-97`, flag declared at `:59`).
- If a rawfile was in use (`last_used_rawfile`) it is **re-opened in append mode** (`"a"`/`"ab"`,
  `:113-142`) and closed again after; a zero-length file is unlinked (`:150-157`).
- Calls `if_run(ckt, "resume", NULL, symtab)` → `doAnalyses(ckt, 0, ci_curTask)`.
- Messages: `"simulation interrupted\n"` (err 1, still in progress) / `"simulation aborted\n"`
  (err 2, `ci_inprogress = FALSE`) — note these lack the analysis-name prefix that `dosim` adds.
- **`resume` takes no arguments** (`co_maxargs == 0`); `resume foo` → `resume: too many args.`

### 4.4 `step [n]` — `src/frontend/breakp.c:330-341`

```c
if (wl) steps = howmanysteps = atoi(wl->wl_word);
else    steps = howmanysteps = 1;
com_resume(NULL);
```
`ft_bpcheck()` decrements `howmanysteps` and returns FALSE when it hits zero, printing
`"Note: Stopped after %d steps.\n"` only when `steps > 1` (`breakp.c:507-512`). So `step` with no
argument is silent. `ft_stepcheck()` (`breakp.c:697-704`) is the "we are in step mode" predicate used
elsewhere. Verified: `step 5` on a paused tran advanced the plot from 20 to 25 points; a bare `step`
advanced it by 1.

`step` on a *finished* run falls through `com_resume` into `com_run`, with the "No job defined"
result. **A GUI must therefore check `state` before offering Step.**

### 4.5 `status`, `state`, `where` — the interrogation triad

**`status`** (`com_sttus`, `src/frontend/breakp.c:350-419`) walks `dbs` and prints one line per entry:
`%-4d trace <n>` / `%-4d iplot <n> [more]` / `%-4d save <n>` / `%-4d trace all` / `%-4d iplot all` /
`%-4d save all` / `%-4d stop <cond>` / `%-4d exiting iplot <n>`. It prints **nothing at all** when the
list is empty (no header, no "none"). Note `#undef isatty / #define isatty(xxxx) 1` at `breakp.c:346-347`
means the numbered form is always used.

**`state`** (`src/frontend/com_state.c:14-31`) is the only run-status reporter:
```
Error: no circuit loaded.                         (no ft_curckt)
Current circuit: <ci_name>
No run in progress.                               (!ci_inprogress)
Type of run: <plot_cur->pl_name>                  e.g. "Transient Analysis"
Number of points so far: <plot_cur->pl_scale->v_length>
(That's all this command does so far)
```
Its table help string is `"(unimplemented) : Print the state of the circuit."` — the help lies; the
command does work, but only reports those three facts, and it reads `plot_cur`, **not** the plot of
the paused run, so a `setplot` between pause and `state` makes the point count wrong.

**`where`** (`src/frontend/where.c:18-45`) is **broken in this tree**:
```c
if (!ft_curckt) { fprintf(cp_err, "There is no current circuit\n"); return; }
else if (ft_curckt->ci_ckt != NULL) { fprintf(cp_err, "No unconverged node found.\n"); return; }
msg = ft_sim->nonconvErr (ft_curckt->ci_ckt, NULL);   /* only reachable with ci_ckt == NULL */
```
Any parsed circuit has `ci_ckt != NULL`, so `where` **always** prints `No unconverged node found.`
and the real message is unreachable (and would be called with a NULL circuit anyway). Verified live
immediately after sourcing a deck. The message it *should* produce is `CKTtrouble()`
(`src/spicelib/analysis/ckttroub.c:20-103`), which formats
`"<analysis name>:  [<optmsg>; ]<domain context>trouble with node \"<name>\"\n"` or
`"... trouble with <model>-instance <name>\n"` or `"... cause unrecorded.\n"`. That same text is
already printed by the analyses themselves through `CKTncDump()` (`cktncdump.c:11`, called from
`dcop.c:83`, `dctran.c:244`, `acan.c:141`/`:287`, `noisean.c:207`/`:409`, `span.c:462`/`:700`,
`dcpss.c:271`), so a GUI should scrape those lines rather than call `where`.
**This is a defect worth filing under `doc/codex/issues/`.**

### 4.6 The state machine, and its one silent hole

Observable states:

| state | `ft_curckt` | `ci_inprogress` | what `state` says |
|---|---|---|---|
| nothing loaded | NULL | — | `Error: no circuit loaded.` |
| loaded, idle | set | FALSE | `Current circuit: … / No run in progress.` |
| paused mid-run | set | TRUE | `Type of run: … / Number of points so far: N` |

`$sim_status` (`cp_vset` at `runcoms.c:328`, `:352`, `:358`) is `0` while/after a normal or interrupted
run and `1` after an abort or a not-started run. It does **not** exist before the first `dosim` call.

**The hole**: starting a *new* analysis while the current circuit is paused is accepted with **no
warning at all**. The `"Warning: losing old state for circuit '%s'"` check at `runcoms.c:262-269`
explicitly excludes `ft_curckt`. Verified:

```
ngspice -> stop after 20
ngspice -> tran 10u 1m        -> paused at 20 points, plot tran1
ngspice -> ac dec 10 1 1meg   -> (no warning) paused at 20 points, plot ac1
ngspice -> state              -> Type of run: AC Analysis
ngspice -> resume             -> finishes the AC run; tran1 stays truncated at 20 points forever
```
A GUI must guard this itself: check `state`/`$sim_status` and refuse (or confirm) a new run while a
paused one exists.

### 4.7 `reset` and `remcirc`

`com_rset` (`runcoms2.c:174-186`): if no circuit, `"Warning: there is no circuit loaded.\n"` +
`"    Command 'reset' is ignored.\n"`. Otherwise `com_remcirc(NULL)` followed by
`inp_source_recent()` — i.e. **throw the circuit away and re-source the same file**. This is the
clean way to abort a paused run and start over, and it also discards `alter`ed values, breakpoints
and saves (because `dbs` is reset when the deck is re-sourced, `inp.c:1256` / `inp.c:733`).

`com_remcirc` (`runcoms2.c:190-291`) frees essentially everything for the current circuit:
numparam dicos, `ci_dbs` (and sets the global `dbs = NULL`), `INPkillMods()`, XSPICE event queues via
`EVTunsetup` (`:217-221`), `DCtran_step_quit(ckt)` to clear the remnants of an incomplete `step`
run (`:223-225`), the CKT itself, `ci_vars`, the deck/param/options/meas/auto card lists,
`ci_commands`, `FTEstats`, both tasks, the temper parse trees, MC state, and finally unlinks the
circuit from `ft_circuits`, making the head of that list current.

`com_removecirc` (`src/frontend/mw_coms.c:22-…`) is a second, older implementation of the same idea
that additionally deletes the plots belonging to that circuit; it is registered as `removecirc`.

`com_quit` also finalises an in-flight plot: quitting during a paused run printed
`No. of Data Rows : 29` before exiting.

### 4.8 `trace` and `iplot` — live observation

`trace [all] [node …]` → `settrace(wl, VF_PRINT, NULL)` (`breakp.c:220-223`): prints values at every
accepted timepoint.

`iplot` (`breakp.c:230-325`) accepts, before the node list:
- `-w <window-size>` — a positive scrolling window, evaluated with `INPevaluate`; non-positive →
  `"Incremental plot width must be positive.\n"`;
- `-d <steps>` — initial delay in points before the window appears, default `IPOINTMIN`;
- `-o` (XSPICE only) — auto-offset traces for event nodes (`DB_AUTO_OFFSET`).
Then `all` (→ `DB_IPLOTALL`) or a list of node names. `iplot` is refused in batch mode
(`check_batch("iplot")`, `breakp.c:236`) and with no circuit
(`"No circuit loaded. Incremental plotting is not possible.\n"`, `breakp.c:238-241`).

`delete` removes any of these (§5.3).

---

## 5. `save` and the implicit save-everything rule

### 5.1 There is no `unsave`

`grep -rn "unsave" src/ doc/` returns nothing. The task brief's `unsave` does not exist in ngspice.
**The cancel is `delete all`** (or `delete <number>` for a single entry).

### 5.2 `save` — `src/frontend/breakp2.c:33-121`

`com_save(wl)` → `settrace(wl, VF_ACCUM, NULL)`; `com_save2(wl, name)` attaches an **analysis name**
so the entry applies only to that analysis (used by the dot-card machinery, §5.5).

- `"Error: no circuit loaded\n"` if `!ft_curckt` (`breakp2.c:53-56`).
- Each word is `cp_unquote`d; `all` and `nosub` are stored verbatim, everything else goes through
  `copynode()` (`breakp2.c:160-190`), which rewrites `v(2)` → `2`, `i(vds)` → `vds#branch`, leaves
  `@mn1[vth0]` alone, and on a missing `)` warns
  `"Warning: Missing ')' in %s\n  Not saved!\n"` and drops the token.
- Duplicate node names are skipped (except `all`) (`breakp2.c:96-104`).
- Entries are `DB_SAVE` records in the same `dbs` list as breakpoints, numbered from `debugnumber`.
- `save` persists across runs within a session and is per-circuit (`ft_curckt->ci_dbs`).

### 5.3 `delete` — `src/frontend/breakp.c:449-501`

- `delete all` → `dbfree(dbs); dbs = NULL; ft_curckt->ci_dbs = NULL` — kills **saves, stops, traces
  and iplots together**. There is no way to delete only the saves in one command.
- `delete` with no args and an empty list → `"Error: no debugs in effect\n"`.
- `delete <n> …` deletes by number; a non-numeric token → `"Error: %s isn't a number.\n"`.

### 5.4 What `beginPlot()` actually does with the save list

`src/frontend/outitf.c:179-500`. `ft_getSaves()` (`breakp2.c:125-153`) copies the `DB_SAVE` entries
into an array; then:

- **`numsaves == 0` → `saveall` stays TRUE** (`outitf.c:189`) → everything in `dataNames[]` is stored,
  **except** a hard-coded exclusion list (`outitf.c:339-353`): names containing `probe_int_`,
  `#internal`, `#source`, `#drain`, `#collector`, `#collCX`, `#emitter`, `#base` are never saved by
  default. `#branch` currents are.
- Recognised magic tokens (case-insensitive, `outitf.c:234-284`):
  - `all` or `allv` → `saveall` (all node voltages + branch currents, minus the internal list);
  - `alli` → in addition, synthesise terminal-current specials `@dev[ic]`, `[ib]`, `[ie]`, `[is]`,
    `[id]`, `[ig]` from the internal node names (`outitf.c:365-415`);
  - `nosub` → save everything except names containing `.` (subcircuit nodes);
  - `nointernals` → save everything except names containing `#`, but keep `#branch`;
  - `none` → **only under `#ifdef SHARED_MODULE`** (`outitf.c:277-284`). In the console build `none`
    is just an unmatched node name.
- An entry carrying an analysis name that does not match this analysis is skipped for this plot
  (`outitf.c:238-242`), which is how `.print tran v(1)` restricts itself to the transient plot.
- Anything left over after the node pass is tried as a "special" (`@dev[param]`) via `parseSpecial`
  (`outitf.c:423-471`); on failure the near-miss case reporter runs
  (`report_save_case_miss`, `outitf.c:1235-1279`, emitting
  `"Warning: no vector named '%s'; '%s' differs only in case (casemode=distinguish)\n"`), otherwise a
  save with an analysis tag warns `"Warning: can't parse '%s': ignored\n"`. **An untagged token that
  simply does not resolve is silently dropped** — deliberately, per `doc/codex/issues/0057`.
- If after all that the plot would hold nothing:
  `"Error: no data saved for %s; analysis not run\n"` with the analysis *description*, and
  `E_NOTFOUND` (`outitf.c:481-486`) → `doAnalyses: not found` → `"<what> simulation(s) aborted"`.

Verified live on a 2-node RC deck:

| command | resulting vectors |
|---|---|
| (nothing) | `V(1) V(2) time v1#branch` |
| `save v(2)` | `V(2) time` |
| `save nosub` | `V(1) V(2) time v1#branch` |
| `save allv` | `V(1) V(2) time v1#branch` |
| `save nointernals` | `V(1) V(2) time v1#branch` |
| `save alli` | **aborts**: `Error: no data saved for Transient analysis; analysis not run` |
| `save none` | **aborts**, same error (console build) |
| then `delete all` | back to all four |

### 5.5 Implicit saves from dot cards

`src/frontend/dotcards.c`:
- `ft_dotsaves()` (`:57-75`) collects the `.save` lines out of `ci_commands` and feeds `com_save`.
  It is called from `inp.c:733` and `inp.c:1257`, i.e. **on every `source`**, right after
  `dbs = NULL` — so **loading a circuit wipes the save/stop/iplot list** and then re-applies the
  deck's `.save` lines.
- `ft_savedotargs()` (`:93-160`) is called **only from batch mode** (`main.c:1577`). It converts
  `.plot` / `.print` / `.sndparam` / `.sndprint` (with the plot-only keywords `linear xlog ylog loglog`
  stripped), `.four` (→ analysis tag `"TRAN"`), `.op` (→ `save all` tagged `"OP"`), `.tf` (→ tagged
  `"TF"`) and `.meas` (via `measure_extract_variables`) into `com_save2` calls, and returns whether
  anything was requested. Its own comment: *"if a node is requested for one analysis, it is saved for
  all of them"* — but the analysis tag it passes makes that only half true.
- **GUI consequence**: an interactive session ignores `.print`/`.plot`; a `-b` batch run without `-r`
  honours them and silently narrows the saved set; a `-b -r` run ignores all of them except `.save`.

---

## 6. `alter`, `altermod`, `alterparam` — parametric re-runs without regenerating the deck

### 6.1 `alter` / `altermod` — `src/frontend/device.c:1201-1246` and `com_alter_common` at `:1288-1495`

Usage message when `alter` is called with no arguments (`device.c:1218-1221`):
```
usage: alter dev param = expression
  or   alter @dev[param] = expression
  or   alter dev = expression
```
Accepted forms (comment at `device.c:1194-1199`):
```
alter @device[parameter] = expr
alter device = expr
alter device parameter = expr
alter device parameter value            (pre-3f4 form, no '=')
alter @vin[pulse] = [ 0 5 10n 10n 10n 50n 100n ]   (vector value)
```
Mechanics:
- The word containing `=` is split into three words (`device.c:1305-1331`).
- With no `=` anywhere, the legacy `alter dev [param] value` form is accepted, but only **one**
  param/value pair; more →
  `"Error: Only a single param - value pair supported.\n"` + `"Cannot alter parameters.\n"`
  (`device.c:1333-1358`). A bracketed vector as the value is detected by scanning back from the
  final `]` for `[`; a missing `[` →
  `"Error: '[' is missing.\n"` + `"Cannot alter parameters.\n"`.
- Errors: `"Error: no circuit loaded\n"` (`:1298`); `"Error: no assignment found.\n"` +
  `"Cannot alter parameters.\n"` (`:1367-1370`); `"Warning: excess parameter name \"%s\" ignored.\n"`
  with an `"    in line: %s\n"` follow-up (`:1387-1393`); `"Error: no model or device name provided.\n"`
  + `"Cannot alter parameters.\n"` (`:1409-1412`);
  `"Error: cannot evaluate new parameter value.\n"` (`:1450`, `:1479`).
- Names are lowercased only when `inp_case_folding()` says the session folds identifiers
  (`device.c:1414-1421`) — under `casemode=distinguish` the typed spelling is kept.
- The RHS is a full nutmeg expression (`ft_getpnames_quotes` + `ft_evaluate`), so
  `alter r1 = 2k*$myfactor` and `alter r1 = mean(v(2))` work.
- **MOS binning**: altering `w` or `l` on a device whose name starts with `m` re-runs the binning by
  reading back the other dimension and calling `if_setparam_model` with `w=… l=…`
  (`device.c:1249-1284`, dispatched at `device.c:1487-1489`).
- The actual write is `if_setparam(ckt, &dev, param, dv, do_model)` (`src/frontend/spiceif.c:972-1016`).
  Errors from there: `"Error: no such device or model name %s\n"`,
  `"Error: no such parameter %s.\n"`, `"Error: no default parameter.\n"`.
- **`altermod` additionally calls `CKTtemp(ckt)`** when `CKTtime > 0`, so instance-level derived
  parameters (`pParam`) are recomputed immediately; a failure there prints
  `"Error during changing a device model parameter!\n"` and `controlled_exit(1)`
  (`spiceif.c:1002-1015`). **A GUI must be aware that `altermod` can kill the process.**
- `alter` takes effect **immediately in the live CKT** — no re-parse, no `reset` needed. Verified:
  `alter r1 = 2k` then `show r1 : all` reported `resistance 2000`.

`altermod` has a second form, `altermod <mod1> [<mod2> …] file=<modelfile>`
(`com_alter_mod`, `device.c:1500-1672`), which reads a model file, finds the matching `*model` lines,
and issues one `altermod` per parameter, skipping `version`, `level`, `mfg` and `type`. Limits:
16 models (`MODLIM`), and it calls `controlled_exit(1)` on
`"Error: too many model names in altermod command\n"`, `"Error: no filename given\n"`, and
`"Error: could not find model %s in input deck\n"`. A missing file is softer:
`"Warning: Could not open file %s, altermod ignored\n"` + `perror("    Cause: ")`.

### 6.2 `alterparam` — `src/frontend/inp.c:1746-1877`

```
alterparam <pname>=<pval>              # a global .param
alterparam <subcktname> <pname>=<pval> # a parameter on a .subckt line
```
It edits the **compacted deck** `ci_mcdeck`, not the live CKT. The header comment (`inp.c:1741-1744`)
says: *"To become effective, `mc_source` has to be called after `alterparam`"*.
Errors: `"Warning: No circuit loaded!\n" / "    Command 'alterparam' ignored\n"`;
`"Error: No internal deck available\n" / "    Command 'alterparam' ignored\n"`;
`"\nError: Wrong format in line 'alterparam %s'\n   command 'alterparam' skipped\n"`;
`"\nError: parameter '%s' not found,\n   command 'alterparam' skipped\n"`.

`mc_source` (`inp.c:1641-1646`) is just `inp_spsource(NULL, FALSE, NULL, FALSE)` — re-source the
in-memory deck. Together, `alterparam` + `mc_source` is the supported Monte-Carlo / parametric loop
that does **not** need a file on disk. `co_minargs/co_maxargs` for `mc_source` are `0/0`.

### 6.3 `circbyline` — building a deck from the GUI without a file

`com_circbyline(wl)` (`inp.c:2120-2128`) flattens the wordlist and hands it to `create_circbyline()`,
which accumulates lines until `.end`; if `.end` never arrives it reports
`"Error: .end statement is missing in netlist!\n"` (`inp.c:2112`). This is on `noredirect[]`, so `>`
inside a netlist line is passed through. It is a plausible way for a GUI to inject a deck line by
line over a pipe without a temp file — though `source` on a temp file is the better-trodden path.

---

## 7. Interrupts and progress

### 7.1 SIGINT

`ft_sigintr()` (`src/frontend/signal_handler.c:81-113`):
- first Ctrl-C → `"\nInterrupted once . . .\n"`, `ft_intrpt = TRUE`;
- subsequent → `"\nInterrupted again (ouch)\n"`;
- at the **third** → `"\nKilling, since %d interrupts have been requested\n\n"` and `controlled_exit(1)`;
- `if (ft_setflag) return;` — during a run (`ft_setflag == TRUE`, set by `dosim`) the handler just
  returns, and the flag is consumed by `OUTstopnow()` at the next data point, producing a **pause**;
- otherwise it longjmps back to the command loop after `ft_sigintr_cleanup()` (`:55-78`: `gr_clean()`,
  readline cleanup, `inp_netlist_read_reset()`, `cp_resetcontrol(TRUE)`).

Verified: SIGINT to a running `tran 1n 5` produced
```
Interrupted once . . .
doAnalyses: pause requested
tran simulation interrupted
```
with `state` reporting `Type of run: Transient Analysis / Number of points so far: 1870830` — i.e.
**the run is resumable and the data is intact**. A GUI's "Pause" button is `SIGINT`; its "Stop" button
is `SIGINT` followed by `reset` (or three SIGINTs for a hard kill).

`SIGFPE` → `sigfloat()` prints via `fperror` and longjmps (`signal_handler.c:117-124`).

### 7.2 Progress

- `HAS_PROGREP` / `extern void SetAnalyse(const char*, int)` is defined **only** under
  `HAS_WINGUI` (`src/include/ngspice/ngspice.h:129-133`) or `SHARED_MODULE`
  (`src/include/ngspice/ngspice.h:286-299`). **This Linux console build has neither**, so the
  `SetAnalyse` calls in `measure.c:301`, `com_gnuplot.c:29`, `spfactor.c` and the analyses compile out.
- The one progress signal the console build emits is in `OUTpData`
  (`src/frontend/outitf.c:809-834`), guarded `#ifndef HAS_WINGUI` and by
  `!orflag && !ft_norefprint && !cp_background`, throttled to 4 Hz:
  `fprintf(stdout, " Reference value : % 12.5e\r", …)`.
  `ft_norefprint` is set by `option norefvalue` / `set norefvalue` (`spiceif.c:455-457`,
  `options.c:359-360`).
- At the end of each streamed plot, `fileEnd()` prints `"\nNo. of Data Rows : %d\n"`
  (`outitf.c:1190`), or, when writing to stdout, `"@@@ %ld %d\n"` (`outitf.c:1194`).
- `rusage` (`src/frontend/resource.c:80-105`) with no argument prints `time`, `totalcputime` and
  `space`; `rusage all` / `rusage everything` prints everything; individual resources include
  `time`, `cputime`/`totalcputime`, `elapsed`, `space`, `faults` (`resource.c:156-280`).
  `ft_ckspace()` warns when within 95% of available data size.
- `sysinfo` (`src/frontend/com_sysinfo.c`) prints OS, CPU model, physical/logical processors, total
  and available DRAM; `"No system info available!\n"` / `"Memory info is unavailable! \n"` on failure.

---

## 8. Configuring a run: `option`, `set`, `optran`, `setseed`

### 8.1 `option` / `options` — `src/frontend/com_option.c:14-138`

- Needs a circuit: `"Error: no circuit loaded\n"` (`:21-24`).
- **With no argument it dumps the live option state** — a ready-made "current settings" reader for a
  GUI (`com_option.c:28-105`). It prints, verbatim: a `Temperatures:` block (`temp`, `tnom`); an
  `Integration method summary:` block (`TRAPEZOIDAL`/`GEAR`, `MaxOrder`, `xmu`, `indverbosity`,
  `epsmin`); a `Matrix solver:` line (`KLU` or `Sparse 1.3`, `#ifdef KLU`); `Tolerances (absolute):`
  (`abstol`, `chgtol`, `vntol`, `pivtol`); `Tolerances (relative):` (`reltol`, `pivrel`);
  `Iteration limits:` (`itl1`, `itl2`, `itl4`, `gminsteps`, `srcsteps`); a truncation-error block that
  is either `ltereltol/lteabstol/ltetrtol` (when `CKTnewtrunc`) or `trtol`; `Conductances:`
  (`gmin`, `diaggmin`, `gshunt`, `cshunt`); `delmin`; and `Default parameters for MOS devices`
  (M, L, W, AD, AS).
- With arguments it parses `name` / `name = value` pairs with `cp_setparse` and pushes each through
  `cp_vset` (`:108-135`) → `cp_usrset` → `if_option`.

`if_option` (`src/frontend/spiceif.c:463-624`):
- Hardwired print flags handled before the parameter lookup: `acct`, `noacct`, `noinit`,
  `norefvalue`, `list`, `node`, `opts`, `nopage`, `nomod` (`:471-503`).
- Everything else is looked up in the **`options` pseudo-analysis** parameter table
  (`ft_find_analysis("options")`, `ft_find_analysis_parm`). Not found and not in the two special
  lists → returns 0 (the name stays an ordinary shell variable).
- `unsupported[] = { itl3, itl5, lvltim, maxord, method }` → `"Warning: option %s is currently unsupported.\n"`
  (`spiceif.c:448-454`, `:517-521`).
- `obsolete[] = { limpts, limtim, lvlcod }` → `"Warning: option %s is obsolete.\n"` (`spiceif.c:455-460`).
- Type mismatch → a multi-line `"Error: bad type given for option %s --\n\ttype given was <t>, type expected was <t>.\n"`,
  plus, for a boolean, `"\t(Note that you must use an = to separate option name and value.)\n"`
  (`spiceif.c:580-623`).
- No circuit → `"Simulation parameter \"%s\" can't be set until\na circuit has been loaded.\n"` (`:557-563`).
- **The write goes to `ft_curckt->ci_defOpt`** (`spiceif.c:576-579`), i.e. the deck's default task, so
  it survives across analyses and affects `run` as well as interactive commands.

### 8.2 `set` overlaps `option`

`cp_usrset` (`src/frontend/options.c:322-536`) handles a list of front-end variables directly, and
**falls through to `if_option` for everything else** (`options.c:526-534`). So `set reltol=1e-4` and
`option reltol=1e-4` do the same thing. Front-end variables `cp_usrset` intercepts:
`debug`, `rawfile`, `acct`, `noacct`, `ngdebug`, `nginfo`, `noinit`, `norefvalue`, `list`, `nopage`,
`nomod`, `node`, `opts`, `strictnumparse`, `strict_errorhandling`, `rawfileprec`, `measureprec`,
`numdgt`, `unixcom`, `units`, `curplot`, `curplotname`, `curplottitle`, `curplotdate`, `plots`
(read-only, `US_READONLY`), `curcasemode` (read-only).
`setcs` is `com_set` with case preserved (`commands.c:126-129`).

Return codes `US_OK / US_READONLY / US_DONTRECORD / US_SIMVAR / US_NOSIMVAR` decide whether the name
is also recorded in the front-end variable list.

**Shell variables read anywhere in the tree** (from `grep -rhno 'cp_getvar("[^"]*"'` over
`frontend/ spicelib/ xspice/ misc/ maths/`), grouped by relevance to running an analysis:

- *Run control / analysis*: `autostop`, `dyngmin`, `nostepsizelimit`, `xtrtol`, `num_threads`,
  `topo_reduce`, `sqrnoise`, `noisyxspice`, `enable_noisy_r`, `notrnoise`, `interp`, `maxwarns`,
  `soacheck`, `noparse`, `controlswait`, `addcontrol`, `renumber`, `polysteps`, `no_mem_check`,
  `nobreak`, `silent_fileio`, `sanelet`, `plainlet`.
- *Output / rawfile*: `filetype`, `appendwrite`, `plainwrite`, `nopadding`, `keep#branch`,
  `rawfile`, `rawfileprec` (via `raw_prec`), `numdgt`, `measureprec`, `measoutfile`, `nosort`,
  `noprintscale`, `noasciiplotvalue`, `nounits`, `wr_singlescale`, `wr_vecnames`, `wr_onespace`,
  `noquotesinoutput`, `casemode` / `casemodewrite`.
- *Post-processing*: `specwindow`, `specwindoworder`, `nfreqs`, `nperiods`, `polydegree`,
  `fourgridsize`, `fournosave`.
- *Random*: `rndseed`.
- *Misc/UI*: `interactive`, `askquit`, `editor`, `width`, `height`, `moremode`, `history`-ish,
  `altshow`, `device`, `hcopy*`, `gnuplot_terminal`, `pyplot_*`, `plotstyle`, `gridstyle`, etc.

Analysis-directory readers specifically (`grep` over `src/spicelib/analysis/`):
`xtrtol` (`cktdojob.c`), `autostop` (`dctran.c`), `sqrnoise` (`noisean.c`, `noisesp.c`),
`dyngmin` (`cktop.c`), `nostepsizelimit` (`traninit.c`), `topo_reduce` and `num_threads`
(`cktsetup.c`).

### 8.3 `optran` — the transient operating-point search

`com_optran` (`src/spicelib/analysis/optran.c:73-192`), registered with **exactly 6 required
arguments** (`commands.c:672`):

```
optran <noopiter> <gminsteps> <srcsteps> <opstepsize> <opfinaltime> <opramptime>[uic]
```
Argument 1 is inverted: `0` → `TSKnoOpIter = 1` (skip the initial iteration), non-zero → `0`
(`optran.c:113-131`). Arguments 4-6 are evaluated with `INPevaluate`; the 6th may be followed by the
literal `uic` (`optran.c:164-168`).

Defaults: `cp_init()` calls `optran 1 1 1 100n 10u 0` (`src/frontend/init.c:77-93`), i.e.
initial iteration on, gmin stepping on, source stepping on, 100 ns step, 10 µs final time, no ramp.
Static fallbacks in `optran.c:48-51` are `opfinaltime = 1e-6`, `opstepsize = 1e-8`, `opramptime = 0`,
`nooptran = TRUE`. `README.optran` (repo root) documents the intent and confirms "Operating point by
transient is now standard. The fefault optran data are 1 1 1 100n 10u." (sic).

Validation: `"Error: Optran step size larger than final time.\n"`;
`"Note: Optran step size set to %e, (stepsize = finaltime / 50).\n"` when the step exceeds
`finaltime/50`; `"Error: Optran ramp time larger than final time.\n"`;
`opstepsize == 0` → `"Note: Optran is deselected.\n"`. Any parse failure →
`"Error in command 'optran'\n"`. With no circuit and no prior data:
`"Warning: syntax error with command 'optran'!\n    Command ingnored\n"` (sic, `optran.c:91-95`).

Ordering subtlety: when issued from `.spiceinit`/`spinit` (no circuit yet) the values are cached in
statics and applied later when `inp.c:1585` calls `com_optran(NULL)` after the deck loads
(`optran.c:64-101`). In `!SIMULATOR` (nutmeg) builds `com_optran` is a no-op stub (`src/main.c:365-369`).

### 8.4 `setseed`

`com_sseed` (`src/maths/misc/randnumb.c:292-322`): with no argument it uses `$rndseed`, or `getpid()`
if unset (and then sets `$rndseed`); with an argument it must be a positive `int`, else
`"\nWarning: Cannot use %s as seed!\n    Command 'setseed %s' ignored.\n\n"`. On success it calls
`srand()` + `TausSeed()` and stores `$rndseed`. Prints
`"\nSeed value for random number generator is set to %d\n"` only when the internal `seedinfo` flag is
on (`setseedinfo()`). This is the reproducibility control for transient noise, `agauss`/`gauss`
parameter spreads and Monte-Carlo loops.

---

## 9. Plot and circuit lifecycle across several analyses

### 9.1 How plots get their names

`beginPlot` → `plotInit(run)` (`src/frontend/outitf.c:1206-1247`):
`pl_title = <circuit title line>`, `pl_name = <analysis description>` (e.g. `"Transient Analysis"`),
`pl_date = datestring()`, then `plot_new(pl); plot_setcur(pl->pl_typename)` — **the new plot becomes
current the moment the analysis starts**.
`plot_alloc(name)` (`src/frontend/vectors.c:1094-1120`) builds `pl_typename` as
`<abbrev><plot_num>`, incrementing `plot_num` until unique. The abbreviation comes from
`ft_plotabbrev()` (`src/frontend/typesdef.c:331-348`) matching a **substring** of the lowercased
`pl_name` against `plotabs[]` (`typesdef.c:67-90`):

`tran`←"transient", `op`←"op", `tf`←"function", `dc`←"d.c."/"dc"/"transfer", `ac`←"a.c."/"ac",
`pz`←"pz"/"p.z."/"pole-zero", `disto`←"disto", `dist`←"dist", `noise`←"noise",
`sens`←"sens"/"sensitivity", `sens2`←"sens2", `sp`←"s.p."/"sp", `harm`←"harm", `spect`←"spect",
`pss`←"periodic". No match → `unknown`.

So the plot names a GUI must expect are `tran1, tran2, …, ac1, dc1, op1, pz1, noise1, noise2,
disto1, sens1, sp1, unknown1, const`, plus `dig1` for XSPICE event data
(`vectors.c:328-332`) and the derived names from `linearize`/`cutout` (which allocate
`plot_alloc("transient")`, so more `tranN`). `deftype p <name> <pattern> …` (`com_dftype`,
`typesdef.c:93-230`) lets a deck or script add abbreviations, up to `NUMPLOTTYPES` entries.

### 9.2 `setplot` — `src/frontend/postcoms.c:1203-1233`

```
setplot                       # list
setplot <plotname>            # make current
setplot new [typename [title [name]]]
setplot previous | next
```
With no argument it prints
```
List of plots available:

Current tran1	<title> (Transient Analysis)
	const	Constant values (constants)
```
(`postcoms.c:1227-1232`). With an argument it calls `plot_setcur()`
(`src/frontend/vectors.c:1392-1472`), which handles `new` (allocates an `unknown` plot titled
`Anonymous`), `previous` (the plot list is in reverse order, so `previous` walks `pl_next`) and
`next`; the boundary messages are
`"Warning: No previous plot is available. Plot remains unchanged (%s).\n"` and the `next` equivalent.
An unknown name → `"Error: no such plot named %s\n"` (`vectors.c:1381`).
Under XSPICE, `plot_setcur` also switches the event-data view with `EVTswitch_plot()`
(`vectors.c:1462-1468`) — **so a GUI that changes plots must expect `eprint`/`edisplay` to follow**.
`setplot new` accepts up to 3 extra words; note `co_maxargs == 4`.
`set curplot = <name>` is equivalent (`options.c:424-429`), and `$plots`, `$curplot`,
`$curplotname`, `$curplottitle`, `$curplotdate` are readable variables (`options.c:243-254`).

### 9.3 `destroy` — `src/frontend/postcoms.c:1026-1063`

```
destroy                # the current plot
destroy all            # every plot except const
destroy <name> …
```
Unknown name → `"Error: no such plot %s\n"`. `killplot()` refuses the constants plot with
`"Error: can't destroy the constant plot\n"` (`postcoms.c:1066-1069`), and `destroy all` resets
`plot_num = 1` when it reaches `const` (`postcoms.c:1044-1046`) — so plot numbering restarts.
`DelPlotWindows()` (`postcoms.c:1163-1188`) closes any graph windows derived from the plot, scanning
graph ids 1..99. **`destroy` does not touch the circuit or the save list.**

### 9.4 `setcirc` — `src/frontend/runcoms.c:65-118`

```
setcirc         # list loaded circuits, marking the current one
setcirc <n>     # switch to circuit number n (1-based)
```
No circuits → `"Error: there aren't any circuits loaded.\n"`. Listing format:
`"List of circuits loaded:\n\n"` then `"Current\t%d\t%s\n"` / `"\t%d\t%s\n"` (number, `ci_name` =
the deck's title line). A bad number → `"Warning: no such circuit \"%s\"\n"`.
Switching swaps the completion keyword tables and, crucially, re-points the globals
`modtab`, `modtabhash`, `sourceinfo`, **`dbs` (the save/stop/iplot database)** and the numparam
dicos (`runcoms.c:104-117`) — so saves and breakpoints are genuinely per-circuit.

**Bug worth knowing**: the `sscanf`/index walk accepts `i == 0` and `i == j` at the boundaries
(`runcoms.c:87-92`), and the two-line comment block shows an older prefix-matching implementation
that was commented out. `setcirc 0` walks the list oddly; treat only `1..N` as supported.

### 9.5 Vector-level lifecycle

`display [vec …]` (`src/frontend/com_display.c:27-83`) — with no argument lists every vector of the
**current plot** (`Title:`, `Name: <typename> (<name>)`, `Date:`, then one line per vector giving
type, real/complex, length and `[default scale]`), sorted unless `set nosort`. With a name it prints
just that vector, else `"Error: no such vector as %s.\n"` or `"Error: no analog vector as %s.\n"`.
`"There are no vectors currently active.\n"` when the plot is empty.
`let` and `meas` with no arguments both fall back to `com_display(NULL)`
(`com_let.c:51-55`, `measure.c:49-53`).

Others: `unlet`, `remzerovec` (drops zero-length vectors from the current plot,
`postcoms.c:78-97`), `settype <type> <vec …>` (`typesdef.c:317-…`; `"Error: no such vector type as '%s'\n"`
and a warning that `@…` vectors need a completed run first), `setscale [vec [vec]]`,
`transpose`, `reshape`, `cross`, `compose`, `diff` (`src/frontend/diff.c`;
`"Error: plot names not given.\n"`, `"Error: no such plot %s\n"`, tolerances from
`diff_abstol`/`diff_reltol`/`diff_vntol`).

---

## 10. Getting data out: `write`, `wrdata`, `load`, `print`, `plot`

### 10.1 `write` — `src/frontend/postcoms.c:577-751`

```
write [file] [expr …]
```
- No file → `ft_rawfile` (default `"rawspice.raw"`, `main.c:96`, settable with `set rawfile=` or `-r`).
- No expressions → `all` (every vector of the current plot) (`postcoms.c:588-620`).
- Binary vs ASCII: `AsciiRawFile` then the `filetype` variable, exactly as in `dosim`
  (`postcoms.c:585-601`); unknown value → `"Warning: strange file type %s\n"`.
- `set appendwrite` appends instead of truncating (`postcoms.c:602`), **and is forced on for the
  second and later plots of a single `write`** (`postcoms.c:745`) — so `write f.raw v(1) ac1.v(1)`
  produces a multi-plot rawfile.
- `set plainwrite` skips expression parsing entirely and looks names up with `vec_get`, which is how
  you write vectors whose names contain `+`, `-`, `/` (`postcoms.c:604-648`); its failure text is
  `"Error during 'write': vector %s not found\n"`; without it, a completely unparseable list gives
  `"Error during 'write': no writable vector found.\n"`.
- It always drags in the scale vector(s) of everything it writes, iteratively
  (`postcoms.c:686-721`).
- **Gotcha observed live**: `write $undefined.raw v(2)` printed
  `Error: scratch_out.raw: no such variable.` and then took `v(2)` as the *filename*, writing all
  four vectors into a file literally called `v(2)`. A GUI must quote/validate the filename itself.

### 10.2 Rawfile format — `src/frontend/rawfile.c:42-…`

Header, in order: `Title:`, `Date:`, `Command: <simulator>-<version>, Build <date>` (`:117`),
`Plotname:`, optionally `Option: casemode=<mode>` (only when the plot was not read from a file **and**
`casemodewrite` is set, `:203-205` — an ngspice-46+ local extension, see `doc/codex/issues/0070`),
`Flags: real|complex[ unpadded]` (`:206-207`; `unpadded` when `set nopadding`),
`No. Variables:`, `No. Points:`, optional `Dimensions:`, one `Command:` line per `pl_commands`
entry, one `Option:` line per plot-environment variable, then `Variables:` with
`\t<index>\t<name>\t<type>` and optional ` min= max= color= grid= plot= dims=` suffixes,
then either `Binary:` + raw doubles or `Values:` + `<row>\t<value>[,<imag>]` lines.
Numeric precision is `raw_prec` if set (`set rawfileprec=N`, `options.c:380-389`) else
`DEFPREC = 15` (`rawfile.c:31`, `:66-70`).
`i(v1)` vs `v1#branch` naming in the header is controlled by `set keep#branch` (`rawfile.c:56`).
`raw_read()` is at `rawfile.c:456`; it sets `pl_fromfile` so a re-written plot does not claim this
session's case mode.

### 10.3 `load` — `src/frontend/postcoms.c:101-118`

```
load [file …]        # default ft_rawfile
```
Each file goes through `ft_loadfile()` (`src/frontend/vectors.c:580-607`), which prints
`"Loading raw data file (\"%s\") ...\n"` and then `"done.\n"` or `"no data read.\n"`, reverses the plot
list so numbering comes out right, marks each loaded plot `pl_written = TRUE`, and bumps `plot_num`.
`com_load` finishes with `com_display(NULL)`, so it always dumps the vectors of the last plot.

Verified round trip: `set filetype=ascii; run out1.raw; destroy all; load out1.raw` restored both
`tran1` and `ac1` with all four vectors each.

### 10.4 `wrdata` — `src/frontend/com_gnuplot.c:45-70`

```
wrdata <file> <plotargs…>
```
`file` may be `temp` or `tmp` for an auto-named temp file. It delegates to
`plotit(wl, fname, "writesimple")` → `ft_writesimple()`
(`src/frontend/plotting/gnuplot.c:683-…`), which writes **columns of plain numbers**:
- `set wr_singlescale` → print the scale column only once, and refuse with
  `"Error: Option 'singlescale' not possible.\n       Vectors %s and %s have different lengths!\n       No data written to %s!\n\n"`
  if lengths differ;
- `set wr_vecnames` → a header line of vector names;
- `set wr_onespace` → single-space separation instead of column formatting;
- `set appendwrite` → append;
- precision is `cp_numdgt` if > 0, else 8.
Complex vectors are written as two columns.

### 10.5 `wrs2p` — `src/frontend/postcoms.c:762-…`

`wrs2p [file]`, default `s_param.s2p`. Prints `"Note: only 2 ports 1 and 2 are supported by wrs2p\n"`
and requires vectors `frequency`, `S_1_1`, `S_2_1`, `S_1_2`, `S_2_2` (and `Rbase`). Output is
Touchstone v1: `!2-port S-parameter file`, `!Title:`, `!Generated by ngspice at <date>`,
`# Hz S RI R <Rbase>` (`rawfile.c:983-987`).

### 10.6 `print`, `plot`, `asciiplot`, `hardcopy`, `gnuplot`, `pyplot`

`print [col|line] <expr …>` (`src/frontend/postcoms.c:126-…`): `col`/`line` force column or line
layout; without either it picks column when any vector is longer than 1. Width/height come from
`$width`/`$height`; `set noprintscale` suppresses the scale column; precision from `$numdgt`.

`plot` (`src/frontend/com_plot.c:29`) → `plotit()` (`src/frontend/plotting/plotit.c`). Its argument
vocabulary, all matched case-insensitively:
- limits: `xl`/`xlimit` lo hi, `yl`/`ylimit` lo hi, `xindices`/`xind` lo hi,
  `xcompress`/`xcomp` n, `xdelta`/`xdel` d, `ydelta`/`ydel` d, `sgraphid` n
  (`plotit.c:327-450`);
- labels: `xlabel`, `ylabel`, `title` (`plotit.c:334-336`);
- flags: `samep`, `xycontour`, `digitop`, `nointerp`, `kicad`, `linear`, `lingrid`, `loglog`,
  `xlog`, `ylog`, `nogrid`, `polar`, `smith`, `smithgrid`, `linplot`, `retraceplot`, `combplot`,
  `boxesplot`, `pointplot` (`plotit.c:367-720`);
- `vs <expr>` for the x axis (`plotit.c:809-833`);
- conflicting grid types warn `"Warning: too many grid types given. \"%s\" is ignored.\n"`.
`hardcopy`, `gnuplot`, `pyplot`, `wrdata` and the Tcl `blt` device all reach the same `plotit()` with a
different `devname` (`plotit.c:1179`, `:1246`, `:1260`, `:1271`, `:1286`).

---

## 11. Post-processing "analyses" that are commands, not simulator jobs

### 11.1 `meas` — `src/frontend/measure.c:36-142`, grammar in `src/frontend/com_measure2.c`

`meas` with no argument = `display`. Otherwise the wordlist is the **same grammar as a `.measure`
card** minus the leading `.measure`. Before parsing, `com_meas` substitutes any right-hand side that
names a single-valued vector with its numeric value (`measure.c:60-112`), so
`meas tran x find v(2) when v(1)=vth` works when `vth` is a one-element vector.
On success the result is assigned to a vector named by the second token via `com_let`
(`measure.c:138-141`); on failure `" meas %s failed!\n\n"`.
Other errors: `"\nError: meas failed due to missing token in \n    meas %s \n\n"`,
`" meas %s failed!\n   unspecified output var name\n\n"`.

`get_measure2()` (`com_measure2.c:1629-…`) enforces:
- `"Error: no assignment found in command meas.\n"` (empty wordlist);
- `"Error: no vectors available\n"` (no current plot / no scale);
- `"Error: measure limited to tran, dc, sp, or ac analysis\n"` — it tests `plot_cur->pl_typename`
  with `ciprefix` against `tran`, `ac`, `dc`, `sp` (`com_measure2.c:1661-1667`). **`meas` cannot run
  on `op`, `pz`, `noise`, `disto` or `sens` plots.**
- `"\tno such function as '%s'\n"` for an unknown measure function;
- `"\tinvalid num params\n"` when fewer than 3 words.

Measure functions (`measure_function_type`, `com_measure2.c:208-257`, case-insensitive):
`DELAY, TRIG, TARG, FIND, WHEN, AVG, MIN, MAX, MIN_AT, MAX_AT, RMS, PP, INTEG, DERIV, ERR, ERR1,
ERR2, ERR3`.
Standard qualifiers (`measure_parse_stdParams`, `com_measure2.c:1289-1388`), all `name=value`:
`RISE`, `FALL`, `CROSS` (each takes an integer or `LAST`, and setting one clears the other two),
`VAL`, `TD`, `FROM`, `TO`, `AT`; the bare word `LAST` is also accepted.
Errors: `"bad syntax. equal sign missing ?\n"`,
`"bad syntax, cannot evaluate right hand side of %s=%s\n"`, `"no such parameter as '%s'\n"`,
`"no such vector as '%s'\n"`, `"bad syntax of %s\n"`. For `dc`, `FROM`/`TO` are swapped if reversed.
For TRIG/TARG, at least one of `at`, `rise`, `fall`, `cross` must be given, else
`"at, rise, fall or cross must be given\n"`.

The authoritative statement of the full grammar is the comment block at
`src/frontend/com_measure2.c:268-310`, reproduced here because a GUI form maps onto it directly:

```
.MEASURE {DC|AC|TRAN} result TRIG trig_variable VAL=val
+ <TD=td> <CROSS=# | CROSS=LAST> <RISE=#|RISE=LAST> <FALL=#|FALL=LAST>
+ <TRIG AT=time>
+ TARG targ_variable VAL=val
+ <TD=td> <CROSS=# | CROSS=LAST> <RISE=#|RISE=LAST> <FALL=#|FALL=LAST>
+ <TRIG AT=time>
.MEASURE {DC|AC|TRAN} result WHEN out_variable=val
+ <TD=td> <FROM=val> <TO=val> <CROSS=…> <RISE=…> <FALL=…>
.MEASURE {DC|AC|TRAN} result WHEN out_variable=out_variable2   …
.MEASURE {DC|AC|TRAN} result FIND out_variable WHEN out_variable2=val   …
.MEASURE {DC|AC|TRAN} result FIND out_variable WHEN out_variable2=out_variable3 …
.MEASURE {DC|AC|TRAN} result FIND out_variable AT=val <FROM=val> <TO=val>
.MEASURE {DC|AC|TRAN} result {AVG|MIN|MAX|MIN_AT|MAX_AT|PP|RMS} out_variable <TD=td> <FROM=val> <TO=val>
.MEASURE {DC|AC|TRAN} result INTEG<RAL> out_variable <TD=td> <FROM=val> <TO=val>
.MEASURE {DC|AC|TRAN} result DERIV<ATIVE> out_variable AT=val
.MEASURE {DC|AC|TRAN} result DERIV<ATIVE> out_variable WHEN out_variable2=val …
```
`chkAnalysisType()` (`measure.c:145-154`) accepts only `tran`, `ac`, `dc`, `sp` as the analysis token.
Note the disagreement: `.measure`'s own analysis token allows `sp`, and `get_measure2` allows `sp`
plots, but the comment block above still says `{DC|AC|TRAN}`. **Trust the code.**

`.measure` cards in the deck run automatically after the analysis, from `dosim`
(`runcoms.c:386-388` → `do_measure(ci_last_an, FALSE)`, `measure.c:213`). `set autostop` makes
`dctran.c` call `check_autostop()` → `do_measure(..., TRUE)` and end the transient as soon as every
measurement is satisfied, printing
`"\nNote: Autostop after %e s, all measurement conditions are fulfilled.\n"` (`dctran.c:448-449`).
`measoutfile` and `measureprec`/`$measureprec` control the measure report file and precision.

### 11.2 `fft` / `psd`

`fft <vec …>` (`src/frontend/com_fft.c:26-…`) and `psd <smoothing> <vec …>` (`:261-…`).
Both require the current plot's scale to be a **real time vector**, else
`"Error: fft needs real time scale\n"`; no plot → `"Error: no vectors loaded.\n"`; fewer than two
points → `"Error: fft needs more than one time point, check the tran simulation!\n"`.
Vectors whose length differs from the scale →
`"Error: lengths of %s vectors don't match: %d, %d\n"`; complex input → `"Error: %s isn't real!\n"`.
`psd`'s first argument is the number of averaged points; a value < 1 or unparseable prints
`"Number of averaged data points:  1\n"` and uses 1.
Windowing comes from `$specwindow` (default `hanning`) and `$specwindoworder` (default 2, floored at
2). `fft_windows()` (`src/maths/fft/fftext.c:97-183`) implements:
`none`, `rectangular`, `triangle`/`bartlet`/`bartlett`, `hann`/`hanning`/`cosine`, `hamming`,
`blackman`, `blackmanharris`, `flattop`, `gaussian`; anything else →
`"Warning: unknown window type %s for fft, set to \"none\"\n"` (com_fft) or a printed
`"Warning: unknown window type %s\n"` from the library.
With `HAVE_LIBFFTW3` (**defined in this build**) FFTW is used and the transform length is the exact
sample count; otherwise a radix-2 zero-padded transform is used, with amplitude normalisation fixed
to `length/2` (see the E-241 comment at `com_fft.c:76-86`).

### 11.3 `spec`

`spec <start_freq> <stop_freq> <step_freq> <vec …>` (`src/frontend/spec.c:20-…`), min 4 args.
Errors: `"Error: no vectors loaded.\n"`, `"Error: spec needs real time scale\n"`,
`"Error: bad start freq %s\n"` (also when negative), `"Error: bad stop freq %s\n"`
(must exceed start), `"Error: bad step freq %s\n"` (must not exceed stop−start),
`"Error: nyquist limit exceeded, try stop freq less than %e Hz\n"`,
`"Error: time span limits step freq to %1.1e Hz\n"`.
Its window list is a **smaller, separate implementation** from `fft`'s
(`spec.c:86-…`): `none`, `rectangular`, `hanning`/`cosine`, `hamming`, `triangle`/`bartlet`,
`blackman`, `gaussian` — no `blackmanharris`, no `flattop`, no `hann`, no `bartlett`. A GUI offering
one window list for both commands would be wrong.

### 11.4 `fourier`

`fourier <fundfreq> <vec …>` (`src/frontend/fourier.c:263-267` → `fourier()` at `:39`).
Variables and defaults (`fourier.c:69-78`): `$nfreqs` default **10**, `$nperiods` default **1**,
`$polydegree` default **1** (0 = no interpolation), `$fourgridsize` default
`DEF_FOURGRIDSIZE = 200` (`fourier.c:32`), `set fournosave` suppresses creating result vectors.
Errors: `"Error: no vectors loaded.\n"`, `"Error: fourier needs real time scale\n"`,
`"Error: bad fundamental freq %s\n"`, `"Error: lengths don't match: %d, %d\n"`.
Printing precision uses `$numdgt` (`pnum()`, `fourier.c:270-281`).

### 11.5 `linearize` and `cutout`

`linearize [np=<n>|np=auto2n] [vec …]` (`src/frontend/linear.c:23-172`).
- Requires `ciprefix("tran", plot_cur->pl_typename)`, else `"Error: plot must be a transient analysis\n"`;
  also `"Error: no vectors available\n"` and `"Error: non-real time scale for %s\n"`.
- Gets `tstart/tstop/tstep` from the circuit's transient parameters; if there is no circuit (e.g. the
  data came from `load`) it warns
  `"Warning: Can't get transient parameters from circuit.\n         Use transient analysis scale vector data instead.\n"`
  and derives them from the scale vector (`linear.c:50-65`).
- **Override hooks**: if the plot contains vectors named `lin-tstart`, `lin-tstop` or `lin-tstep`
  those win, each announced with `"linearize tstart is set to: %8e\n"` etc. (`linear.c:67-83`). A GUI
  can `let lin-tstep = 1n` before calling `linearize`.
- `np=<n>` sets the point count explicitly; `np=auto2n` rounds to the nearest power of two
  (`linear.c:112-131`) — the natural pre-step for `fft`.
- Sanity: `"Error: bad parameters -- start = %G, stop = %G, step = %G\n"`.
- Creates a **new** plot named `"<oldname> (linearized)"` and makes it current.
- Named vectors that do not exist → `"Error: command 'linearize': no such vector %s\n"`.

`cutout [vec …]` (`linear.c:179-…`) copies a time window into a new plot named
`"<oldname> (cut out)"` (or `"(copy)"` when no window is given), driven by vectors `cut-tstart` /
`cut-tstop` in the current plot. Same transient-only and real-scale guards, plus
`"Error: no data in vector\n"` and `"Error: bad parameters -- start = %G, stop = %G\n"`.

### 11.6 `let` / `define`

`let <name>[<index>] = <expr>` (`src/frontend/com_let.c:33-…`). No arguments = `display`.
`"Error: bad let syntax\n"` when there is no `=`;
`"Error: bad variable name \"%s\"\n"` for `all`, a name containing `@`, an empty name or one starting
with a digit. `let x[0] = 1` requires `x` to exist already. `set plainlet` and `set sanelet` change
the RHS handling. `let` is on `noredirect[]`.
`define [func(args) body]` (`src/frontend/define.c:83`) defines a user function; `undefine` removes it.

---

## 12. Commands that are stubs or traps

| command | reality |
|---|---|
| `aspice`, `jobs`, `rspice` | Guarded by `OK_ASPICE` (`src/frontend/aspice.c:24`), which is **defined nowhere in the tree**. The compiled versions print `"Asynchronous spice jobs are not available.\n"` (`aspice.c:430`, `:438`) and `"Remote spice jobs are not available.\n"` (`aspice.c:452`). Do not build a GUI feature on these. |
| `where` | Always `No unconverged node found.` — see §4.5. |
| `state` | Works, but its help string says `(unimplemented)`, and it reads `plot_cur` rather than the running plot. |
| `dump` | `if_dump()` prints the literal string `"diagnostic output dump unavailable."` (`src/frontend/spiceif.c:634-640`). Useless. |
| `mdump` / `mrdump` | Real: `SMPprint`/`SMPprintRHS` to stdout or a named file; `"Error: no circuit loaded.\n"`, `"Error: no matrix available.\n"`, `"Error: no matrix or RHS available.\n"` (`src/frontend/com_cdump.c:146-194`). In non-SIMULATOR builds they are no-op stubs (`main.c:371-386`). |
| `snsave` / `snload` | Explicitly labelled *"Still very experimental !"* (`spiceif.c:1419-1426`). `snsave <file>` refuses anything but a transient job (`"Warning: Only saving of tran analysis is implemented\n"`), refuses XSPICE A-devices (`"Warning: snsave not implemented for XSPICE A devices.\n    Command 'snsave' will be ingnored!\n"`), and needs a parsed circuit. `snload <ckt-file> <data-file>` refuses if a non-script circuit is loaded (`"Error: there is already a circuit loaded.\n"`), sources the deck, runs `CKTsetup`+`CKTtemp` (`"Some error in the CKT setup fncts!\n"`), sets `ci_inprogress = TRUE` so a `resume` continues, then checks that `sizeof(CKTcircuit)` matches, else `"Error: snapshot saved with different version of spice\n"`. LTRA lines and most XSPICE models will not survive. In nutmeg builds both are no-ops (`main.c:353-363`). |
| `edit` | Refused unless `set interactive`: `"Warning: `edit' is disabled because 'interactive' has not been set.\n  perhaps you want to 'set interactive'\n"` (`inp.c:1657-1663`). Spawns `$editor` / `$EDITOR` / `Def_Editor` / `/usr/bin/vi`. |
| `check_ifparm` | Developer-only descriptor audit; slow, prints to stderr. |

---

## 13. XSPICE event commands (`XSPICE` = 1 here)

- `esave all | none | <node> …` (`src/xspice/evt/evtprint.c:970-1017`). No args →
  `"Usage: esave all | none | <node1> <node2> ...\n"`. No circuit →
  `"Error: no circuit loaded.\n"`. An unknown node →
  `"ERROR - Node %s is not an event node.\n"` and the whole command aborts. Each invocation
  **clears the previous selection** before applying the new one.
  `EVTdiscard()` (same file) is what `-b -r` calls to drop all event data.
- `eprint <node> …` (`evtprint.c:101-…`), max **93** arguments (`EPRINT_MAXARGS`, `evtprint.c:95`).
- `eprvcd [-a] [-t <timescale>] <node> …` (`evtprint.c:577-…`). `-a` also emits analog values at
  timesteps; `-t` sets the VCD timestep (documented range 1 fs … 1 s). Intended usage
  `eprvcd a0 a1 clk > my.vcd`. Missing: hierarchy and bit vectors (comment at `evtprint.c:570-576`).
- `edisplay` (`evtprint.c:398-…`), 0 args exactly. Prints
  `"\nList of event nodes in plot %s\n"` (or `"\nList of event nodes\n"`) and a
  `node name : type, number of events` table; `"No event node available!\n"` when there are none;
  `"Error: no circuit loaded.\n"`.
- `codemodel <library>` loads a `.cm` (`src/frontend/com_dl.c:9-27`); failure sets `ft_spiniterror`
  and prints `"Error: Library %s couldn't be loaded!\n"`, and exits if `strict_errorhandling`.
- `osdi <library …>` loads OpenVAF `.osdi` models (`com_dl.c:31-42`), same error text.
Both are normally issued from `src/spinit.in`.

---

## 14. Consolidated defects / traps for the plan

1. **`where` is dead code** (`src/frontend/where.c:29-33`). Worth a `doc/codex/issues/NNNN` entry.
2. **A paused run is silently abandoned** by starting any new analysis (`runcoms.c:262-269` excludes
   `ft_curckt`). The truncated plot stays in the list looking complete.
3. **`resume`/`step` on a finished run silently become `run`** (`runcoms2.c:86-90`) and then fail with
   "No job defined" on a deck with no dot cards.
4. **`stop when` re-fires immediately on `resume`**; only `stop after N` is one-shot.
5. **`delete all` is the only way to cancel `save`**, and it also deletes breakpoints, traces and
   iplots.
6. **`save none` aborts the analysis** in the console build ("no data saved… analysis not run"); it
   is only meaningful under `SHARED_MODULE`.
7. **`run <rawfile>` keeps nothing in memory** — a GUI that streams to a rawfile must `load` it back
   to plot.
8. **Analysis execution order is by type, not deck order** (`cktdojob.c:176`, `analysis.c:36`).
9. **`altermod` can call `controlled_exit(1)`** on a `CKTtemp` failure (`spiceif.c:1008-1015`), and
   `com_alter_mod` exits on several parse errors. A GUI driving a subprocess must expect the process
   to die.
10. **`tf`'s help text says "Do a transient analysis"** (`commands.c:317`) — a one-line docs fix.
11. `state` reads `plot_cur`, so its point count is wrong after a `setplot`.
12. `linearize` is `co_spiceonly = FALSE` in `spcp_coms` but `TRUE` in `nutcp_coms` — inconsistent.
13. No progress API on Linux console builds; the ` Reference value : …\r` line is all there is.

---

## 15. What a GUI should actually drive

Two viable transports:

- **`ngspice -p` over a pipe** (what every transcript here uses). Commands in, text out. Needs a
  prompt-based framing (`ngspice N -> `) and stdout/stderr scraping. Pause = SIGINT to the child.
- **`libngspice`** (`--with-ngshared`, `src/include/ngspice/sharedspice.h`). Gains `SetAnalyse`
  progress callbacks, `ngSpice_Command`, `ngSpice_Circ`, background-thread running and the
  `save none` semantics; loses process isolation, and everything must survive repeated
  `ngSpice_Reset` (see `CLAUDE.md`). Not built in `build-ver_50` (`SHARED_MODULE` undefined).

Minimum command vocabulary for an ADE-L-class front end:

```
source <deck>                      # or circbyline line by line
delete all                         # reset the save/stop/iplot database
save <nodes…> | save all           # narrow / widen what is stored
option <name>=<value> …            # simulator options for the next run
optran a b c d e f                 # operating-point search strategy
setseed <n>                        # reproducibility
alter / altermod / alterparam+mc_source   # parameter sweeps
tran|ac|dc|op|noise|pz|tf|sens|disto|sp <args>   # or `run` for the deck's dot cards
stop when … / stop after N         # breakpoints
<SIGINT> / resume / step [n] / reset
state / status / display / setplot / $sim_status / rusage
meas … / fft / psd / spec / fourier / linearize [np=auto2n] / cutout
write <file> [vecs] / wrdata <file> <vecs> / load <file>
destroy [all] / remcirc / setcirc
```
