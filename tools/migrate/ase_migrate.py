#!/usr/bin/env python3
"""ase_migrate — de-clutter a testbench schematic into the ASE-L lib/cell/view form.

Turns a "cluttered" xschem testbench — one that carries its own model/corner
setup, its `.control` simulator commands, and its waveform graph(s) directly on
the schematic — into the ASE-L "clean" form:

    <cell>/schematic/<cell>.sch      circuit ONLY (devices, wires, labels, gnd,
                                     sources) — no models, no corner, no .control,
                                     no graphs, no launcher buttons
    <cell>/ngspice_state1/<cell>.state   the extracted setup as an ase:: state view
                                         (models / includes / variables / analyses /
                                          options / outputs), byte-canonical

so that **Tools > Launch ASE-L** on the clean schematic opens an Analog Sim
Environment session (with the workarea rc's default model preloaded), and opening
the `ngspice_state1` view restores exactly the migrated setup. Companion to the
hand-built sky130A/gf180mcuD `nfet_test_claude` (before) / `test_nfet_final`
(after) reference pairs — those are this tool's acceptance fixtures.

See doc/claude/specs/ase_l.md (state schema + deck assembly) and the workarea
READMEs (sky130A/README.md, gf180mcuD/README.md, "ASE-L reference cells").

Design points (same discipline as xschem_libmigrate.py):
  * NON-DESTRUCTIVE: writes a fresh destination; the source .sch is never touched.
  * stdlib only — the .sch record scanner is reused from migrate_pin_names, the
    state serializer reproduces ase::state_serialize's Tcl-list quoting in pure
    Python (byte-identical to what xschem's loader/saver round-trips), so no
    xschem process is needed to emit a cell. `--verify` (optional) does shell out
    to xschem+ngspice to prove the migrated cell reproduces the cluttered cell's
    operating point.
  * LOSSLESS-OR-LOUD: a `.control` command that does not map to the ASE state
    schema (let/meas/foreach/...) is preserved verbatim in the report's warnings
    and NEVER silently dropped.

CLI:
    python3 ase_migrate.py --sch CELL.sch --pdk gf180 --out OUTDIR
    python3 ase_migrate.py --sch CELL.sch --pdk sky130 --out OUTDIR --verify
    python3 ase_migrate.py --library LIBROOT --pdk gf180 --out OUTDIR   # whole lib
    python3 ase_migrate.py --sch CELL.sch --pdk gf180 --dry-run         # report only
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from migrate_pin_names import scan_records, get_tok, ParseError  # noqa: E402


class MigrationError(Exception):
    pass


# --------------------------------------------------------------------------- #
# Tcl-list serialization (faithful to ase::state_serialize / Tcl_ConvertElement)
# --------------------------------------------------------------------------- #
# A state field's canonical line is `key [list <value>]`: the value (itself a Tcl
# list string) is wrapped once more by [list ...]. Tcl_ScanElement /
# Tcl_ConvertElement (tclUtil.c) pick one of FOUR forms for that element — bare,
# brace-wrapped, backslash-escaped, or "mask" (escape everything except braces
# that are already balanced) — and _tcl_conv reproduces that decision exactly, so
# NO value is out of domain. It used to brace-quote unconditionally and raise on
# any backslash, which crashed on a real cell (a graph `node=` line continuation);
# see doc/claude/issues/0167-ase-migrate-quoting-and-graph-node.md. The rules are
# differential-fuzzed against tclsh in tools/migrate/test_ase_migrate.py §1.
# The leading-`#` rule applies to the FIRST element of a list only -> quote_hash.

_WS_CHARS = " \t\n\v\f\r"
_ESC_MAP = {" ": "\\ ", "\t": "\\t", "\n": "\\n", "\v": "\\v", "\f": "\\f",
            "\r": "\\r", "[": "\\[", "]": "\\]", "$": "\\$", ";": "\\;",
            '"': '\\"', "\\": "\\\\"}


def _tcl_conv(s, quote_hash=True):
    """Tcl_ConvertElement for the string `s`: byte-for-byte what Tcl's
    `[list $s]` produces, for every possible `s` (never raises)."""
    if s == "":
        return "{}"
    forbid_none = prefer_brace = require_escape = False
    nesting = 0
    if s[0] in "{\"" or (quote_hash and s[0] == "#"):
        forbid_none = prefer_brace = True
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c == "{":
            nesting += 1
        elif c == "}":
            nesting -= 1
            if nesting < 0:
                require_escape = True            # closes before it opens
        elif c == "]" or c == '"':
            forbid_none = True                   # not brace-preferring on its own
        elif c in "[$;" or c in _WS_CHARS:
            forbid_none = True
            prefer_brace = True
        elif c == "\\":
            forbid_none = True
            if i + 1 >= n or s[i + 1] == "\n":
                require_escape = True            # a trailing \ would eat the `}`
            else:
                prefer_brace = True
                i += 1                           # escaped char takes no further part
        i += 1
    if nesting != 0:
        require_escape = True
    if not require_escape:
        if not forbid_none:
            return s                             # CONVERT_NONE
        if prefer_brace:
            return "{" + s + "}"                 # CONVERT_BRACE
    out = []                                     # CONVERT_ESCAPE / CONVERT_MASK
    for idx, c in enumerate(s):
        if c in "{}":
            out.append("\\" + c if require_escape else c)   # MASK keeps balanced
        elif idx == 0 and c == "#" and quote_hash:
            out.append("\\#")
        else:
            out.append(_ESC_MAP.get(c, c))
    return "".join(out)


def _struct_to_str(x):
    """Canonical Tcl-list string of a nested (str | list) structure."""
    if isinstance(x, (list, tuple)):
        return " ".join(_tcl_conv(_struct_to_str(e), quote_hash=(i == 0))
                        for i, e in enumerate(x))
    return str(x)


def serialize_state(state, schema_keys):
    """State dict (values are str | nested lists) -> canonical ase state text,
    schema_keys first (in order), then any unknown keys sorted — mirroring
    ase::state_serialize so a re-load/re-save is byte-identical."""
    lines = []
    for k in schema_keys:
        if k in state:
            lines.append("%s %s" % (k, _tcl_conv(_struct_to_str(state[k]))))
    for k in sorted(state):
        if k not in schema_keys:
            lines.append("%s %s" % (k, _tcl_conv(_struct_to_str(state[k]))))
    return "\n".join(lines) + "\n"


SCHEMA_KEYS = ["version", "simulator", "design", "rundir", "temperature",
               "models", "variables", "analyses", "outputs", "save_all_v",
               "save_all_i", "options", "includes", "pre_commands", "viewer"]


# --------------------------------------------------------------------------- #
# PDK profiles — the per-technology knowledge the migrator needs
# --------------------------------------------------------------------------- #

# Tcl globals xschem itself always defines, so a path naming one of these is
# resolvable in ANY workarea and must never be flagged. (xinit.c / xschem.tcl:
# `USER_CONF_DIR`, `XSCHEM_SHAREDIR`, … are set before any rc is sourced.)
_XSCHEM_GLOBALS = frozenset((
    "USER_CONF_DIR", "XSCHEM_SHAREDIR", "XSCHEM_LIBRARY_PATH", "netlist_dir",
    "XSCHEM_START_WINDOW", "env"))


class Pdk(object):
    """Per-technology profile: the model-path variable, and how a `corner`
    symbol's corner= value maps to a `.lib file section` model entry."""

    def __init__(self, name, model_var, corner_lib=None, corner_default=None,
                 env_vars=(), device_libs=()):
        self.name = name
        self.model_var = model_var                # e.g. '180MCU_MODELS' (no $::)
        self.corner_lib = corner_lib              # portable .lib path for corner sym
        self.corner_default = corner_default      # fallback section if corner= absent
        # Tcl globals the workarea rc GUARANTEES at run time. A migrated path may
        # name one of these (or an _XSCHEM_GLOBALS name) and nothing else: a
        # `$::SKYWATER_STDCELLS/...` include makes ase::expand_path throw
        # ("can't read ...: no such variable") before ngspice ever starts, so the
        # cell cannot run at all. See _resolvable_path / issue 0210 bucket A.
        self.env_vars = frozenset(env_vars) | {model_var}
        # symbol libraries whose instances are PDK devices: a cell that
        # instantiates one of these and extracted NO model entry has nothing to
        # resolve `sky130_fd_pr__nfet_…` against (issue 0210 bucket D).
        self.device_libs = frozenset(device_libs)

    def corner_model(self, corner_value):
        """(file, section) model entry for a `corner` symbol, or None if this PDK
        drives models a different way (gf180 uses a code_shown block instead)."""
        if not self.corner_lib:
            return None
        sec = corner_value or self.corner_default
        return (self.corner_lib, sec)


PDKS = {
    # SKYWATER_STDCELLS / PDK_ROOT / PDK are set unconditionally by
    # sky130A/cadence_style_rc ("3b. Standard-cell SPICE decks") — seven benches
    # include a stdcell deck from an open_pdks install rather than a model .lib,
    # and dropping those includes would only trade `no such variable` for
    # `unknown subckt: sky130_fd_sc_hd__*`.
    "sky130": Pdk("sky130", "SKYWATER_MODELS",
                  corner_lib="$::SKYWATER_MODELS/sky130.lib.spice",
                  corner_default="tt",
                  env_vars=("SKYWATER_STDCELLS", "PDK_ROOT", "PDK"),
                  device_libs=("sky130_fd_pr",)),
    # gf180 embeds `.include design.ngspice` + `.lib sm141064 typical` in a
    # code_shown block already in portable $::180MCU_MODELS form, so there is no
    # corner symbol to map — models/includes are parsed straight from the block.
    "gf180": Pdk("gf180", "180MCU_MODELS", device_libs=("gf180mcu_pr",)),
    # IHP SG13G2: same shape as gf180 — a code_shown block already in portable
    # `$::MODELS_NGSPICE/corner*.lib <section>` form, no corner symbol. What is
    # specific to it is the OSDI preload: its MOS (psp103va), varicap and
    # r3_cmc resistor models are Verilog-A, loaded by `pre_osdi` lines inside the
    # block's .control section (ihp-sg13g2/cadence_style_rc:40-49). Those are
    # carried through to the state's `pre_commands` field, see _parse_control_line.
    "sg13g2": Pdk("sg13g2", "MODELS_NGSPICE",
                  env_vars=("SG13G2_MODELS", "SG13G2_OSDI"),
                  device_libs=("sg13g2_pr", "sg13g2_stdcells")),
}


# --------------------------------------------------------------------------- #
# embedded-SPICE parser: a code_shown / simulator_commands value -> state pieces
# --------------------------------------------------------------------------- #

# analysis-line grammars we can round-trip into the ASE analyses schema.
_MAPPABLE_CONTROL = frozenset(("op", "dc", "ac", "tran"))
# control commands ASE owns/regenerates — safely dropped on migration.
_DROP_CONTROL = frozenset((
    "run", "write", "remzerovec", "reset", "set", "unset", "echo", "listing",
    "rusage", "quit", "shell", "cd", "source", "load", "destroy", "setplot"))
# control commands that carry real analysis intent we cannot express -> passthrough
_KEEP_CONTROL = frozenset((
    "let", "meas", "measure", "foreach", "while", "dowhile", "if", "repeat",
    "alter", "altermod", "compose", "linearize", "fourier", "fft", "sens",
    "noise", "disto", "pz", "tf", "sp"))
# ...of those, the ones that ARE an analysis (as opposed to post-processing or
# control flow). If one of these is all a bench had, the state must NOT fall back
# to the default `op`: the four sp_* IHP benches would then run a
# perfectly-healthy-looking operating point in place of their S-parameter sweep.
_ANALYSIS_CONTROL = frozenset(("sp", "noise", "disto", "pz", "tf", "sens"))


# option names ngspice/Xyce accept (`NONLIN-TRAN` is real); anything else is a
# stray token, not an option
_OPT_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.\-]*$")
# `plot sig+2` / `plot v(clk)+2` is a DISPLAY offset, not a signal — `.save sig+2`
# is not a valid vector
_PLOT_OFFSET_RE = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_.\[\]]*(?:\([^()]*\))?)([+-]\d+(?:\.\d+)?)$")
# ngspice `plot`/`print` display keywords — never signals. Probed against
# ngspice-42: `plot xlog response` plots `response` only.
_PLOT_FLAGS = frozenset(("xlog", "ylog", "loglog", "linear", "polar", "smith",
                         "smithgrid", "nogrid", "samep", "retraceplot"))
_PLOT_KW1 = frozenset(("title", "xlabel", "ylabel", "xdelta", "ydelta",
                       "xcompress", "xindices"))
_PLOT_KW2 = frozenset(("xlimit", "ylimit"))
# `i(@dev[param])` is not an ngspice vector — the device-parameter form is bare
# `@dev[param]` (probed: `print i(@m1[id])` -> "no such function as i")
_IDEV_RE = re.compile(r"^i\((@[^()]*\[[A-Za-z0-9_]+\])\)$", re.I)


def _unquote(tok):
    """Strip one layer of matching surrounding quotes."""
    if len(tok) >= 2 and tok[0] == tok[-1] and tok[0] in "\"'":
        return tok[1:-1]
    return tok


def _split_ws(text):
    """Whitespace split that keeps {...}, (...) and "..." groups together, so
    `.param p={1.8 * 2}` is ONE token and `.include "/opt/my models/x.lib"` is
    one path. A bare str.split() shredded both."""
    toks, cur, depth, quote = [], [], 0, None
    for ch in text:
        if quote:
            cur.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            cur.append(ch)
            continue
        if ch in "{(":
            depth += 1
        elif ch in "})":
            depth = max(0, depth - 1)
        if ch.isspace() and depth == 0:
            if cur:
                toks.append("".join(cur))
                cur = []
            continue
        cur.append(ch)
    if cur:
        toks.append("".join(cur))
    return toks


def _probe_tokens(line, warn=None, display=False):
    """Probe expressions of a `save`/`print`/`plot`/`.save` line: quoted groups
    honoured, shell redirection (`print del > result.txt`) removed.

    `display` marks the `plot`/`print` grammar, which additionally has display
    clauses (`vs <xvector>`, `xlimit a b`, `title t`, `xlog`, …) that are not
    signals. They are NOT dropped on `save`/`.save`/`.probe`, where `vs` and
    `title` are ordinary net names."""
    warn = [] if warn is None else warn
    toks = _split_ws(line)[1:]
    out = []
    i = 0
    while i < len(toks):
        t = toks[i]
        low = t.lower()
        if t in (">", ">>"):
            i += 2                                   # `> file`
            continue
        if t.startswith(">"):
            i += 1                                   # `>file`
            continue
        if display and low == "vs":
            warn.append("plot x-axis selector dropped: vs %s"
                        % (toks[i + 1] if i + 1 < len(toks) else ""))
            i += 2                                   # `vs time`
            continue
        if display and low in _PLOT_FLAGS:
            warn.append("plot display flag dropped: %s" % t)
            i += 1
            continue
        if display and low in _PLOT_KW1:
            warn.append("plot display option dropped: %s" % " ".join(toks[i:i + 2]))
            i += 2
            continue
        if display and low in _PLOT_KW2:
            warn.append("plot display option dropped: %s" % " ".join(toks[i:i + 3]))
            i += 3
            continue
        out.append(_unquote(t))
        i += 1
    return out


def _normalize_expr(expr, warn):
    """Map a probe expression onto a form ngspice can actually `.save`."""
    mo = _IDEV_RE.match(expr)
    if mo:
        warn.append("i(@dev[param]) is not a vector, saving %s instead: %s"
                    % (mo.group(1), expr))
        return mo.group(1)
    return expr


class SpiceDeck(object):
    """Accumulates the structured pieces extracted from one or more embedded
    SPICE text blocks (a corner symbol maps in directly; a code_shown /
    simulator_commands value is parsed here)."""

    def __init__(self):
        self.models = []       # [(file, section), ...]
        self.includes = []     # [file, ...]
        self.params = []       # [(name, value), ...]
        self.options = []      # [(name, value_or_None), ...]
        self.analyses = {}     # type -> dict(type=, enabled=1, **params)
        self.outputs = []      # [(expr, plot), ...]
        self.temperature = None
        self.save_all_v = False  # `save all` / `print all` -> blanket .save all
        self.save_all_i = False  # blanket .options savecurrents
        self.pre_commands = []  # `pre_*` .control lines (osdi preload etc.)
        self.raw_control = []  # unmappable .control lines (preserved in report)
        self.unmapped_analyses = []   # analysis heads with no ASE schema equivalent
        # deck text with no ASE-state destination that is still REAL netlist
        # content: circuit element lines (`vd d 0 0`, XSPICE `A…` devices) and
        # the `.model`/`.ic`/`.nodeset`/`.subckt`/`.global` family. These used to
        # fall off the end of _parse_top_line with no destination and no warning
        # — 54 lines across 15 of the 48 sky130 cells, taking four benches'
        # swept sources and test_jfet's `.MODEL 2N3459` with them (issue 0210
        # `embedded-nondot-lines-silently-dropped`). CellMigrator re-emits them
        # onto the CLEAN SCHEMATIC as a `devices/code` netlist_commands record,
        # which is where circuit content belongs: the ASE state schema has no
        # field for literal deck text, and render_deck (src/ase.tcl) builds the
        # deck as [schematic netlist] + [state cards], so a netlist_commands
        # record reaches the simulator unchanged.
        self.residue = []
        self.warnings = []

    def _add_output(self, expr, plot):
        # `all` is the ngspice save-everything token, not a probe expression ->
        # it maps to ASE's blanket save_all_v flag, not a named output.
        if expr.lower() in ("all", "v(all)"):
            self.save_all_v = True
            return
        # `print {$scratch}.vg` — `$scratch` is an ngspice CONTROL-SHELL variable
        # (`set scratch=$curplot`), interpolated by the shell before the vector is
        # looked up. ASE emits outputs as `.save <expr>` in the DECK, where the
        # shell has not run: ngspice answers "Syntax error: letter [$]" and the
        # whole deck dies. Not a vector -> not an output.
        if "$" in expr:
            self.warnings.append(
                "control-shell variable is not a saveable vector, dropped: %s" % expr)
            return
        self.outputs.append((expr, plot))

    # -- public entry points --------------------------------------------------
    def add_corner(self, pdk, corner_value):
        m = pdk.corner_model(corner_value)
        if m:
            self.models.append(m)
        else:
            self.warnings.append(
                "corner symbol (corner=%s) has no model mapping for pdk %s"
                % (corner_value, pdk.name))

    def parse(self, text):
        """Parse an embedded SPICE blob (top level + any .control block).

        Returns the residue lines THIS blob contributed, in source order, so the
        caller can re-emit them as one netlist_commands record per source block
        (preserving that block's only_toplevel/place scope)."""
        mark = len(self.residue)
        in_control = False
        for line in self._logical_lines(text):
            low = line.lower()
            if not in_control and low == ".control":
                in_control = True
                continue
            if in_control and low == ".endc":
                in_control = False
                continue
            if in_control:
                self._parse_control_line(line)
            else:
                self._parse_top_line(line)
        return self.residue[mark:]

    @staticmethod
    def _logical_lines(text):
        """Blank/`*`-comment lines removed and SPICE `+` continuations folded onto
        the card they continue. Line-at-a-time parsing used to shred a continued
        card into a head with no tail (test_stdcells' `pre_set auto_bridge_d_out =`
        and its two `+ ( ".model …" )` lines), which matters now that heads like
        `pre_*` are carried into the state instead of only into the report."""
        out = []
        for raw in text.splitlines():
            line = raw.strip()
            if not line or line.startswith("*"):
                continue
            if line.startswith("+") and out:
                out[-1] = out[-1] + " " + line[1:].strip()
                continue
            out.append(line)
        return out

    # -- top-level dot-cards --------------------------------------------------
    def _parse_top_line(self, line):
        low = line.lower()
        if low.startswith(".lib"):
            toks = [_unquote(t) for t in _split_ws(line)]
            if len(toks) >= 3:
                self.models.append((toks[1], toks[2]))
            elif len(toks) == 2:
                self.includes.append(toks[1])      # `.lib file` (whole-file) ~ include
            return
        if low.startswith(".include") or low.startswith(".inc "):
            parts = line.split(None, 1)
            rest = parts[1].strip() if len(parts) == 2 else ""
            if not rest:
                return
            toks = _split_ws(rest)
            if len(toks) == 1 or not rest[0] in "\"'":
                # an UNQUOTED path may legally contain spaces -> rest of line
                self.includes.append(_unquote(rest) if len(toks) == 1 else rest)
            else:
                self.includes.append(_unquote(toks[0]))
                if len(toks) > 1:
                    self.warnings.append("extra .include tokens dropped: %s" % line)
            return
        if low.startswith(".param"):
            self._parse_params(line[len(".param"):])
            return
        if low.startswith(".option"):        # .option or .options
            self._parse_options(line.split(None, 1)[1] if len(line.split()) > 1 else "")
            return
        if low.startswith(".save") or low.startswith(".probe"):
            for e in _probe_tokens(line, self.warnings):    # no display clauses
                self._add_output(e, 0)
            return
        if low.startswith(".temp"):
            toks = line.split()
            if len(toks) >= 2:
                # ASE hard-errors on a non-numeric temperature when it renders the
                # deck (src/ase.tcl render_deck) — refuse it here, loudly, instead
                # of shipping a state that only detonates at Run.
                if _NUM_RE.match(toks[1]):
                    self.temperature = toks[1]
                else:
                    self.warnings.append(
                        "non-numeric .temp not migrated (ASE needs a number): %s" % line)
            return
        # \b so a typo'd `.opton wnflag=1` is NOT parsed as an `.op` analysis
        if re.match(r"^\.(op|dc|ac|tran)\b", low):
            self._parse_analysis(line.lstrip("."))
            return
        # `.end` terminates the deck and `.title` names it — render_deck emits
        # its own, and re-emitting either into the netlist body would truncate or
        # rename the run. They are the ONLY two cards that are pure deck framing.
        if low.startswith(".end") and not low.startswith(".ends"):
            self.warnings.append("deck-framing card dropped (ASE emits its "
                                 "own): %s" % line)
            return
        if low.startswith(".title"):
            self.warnings.append("deck-framing card dropped (ASE emits its "
                                 "own): %s" % line)
            return
        # Everything else with no state destination is REAL deck content and goes
        # to the residue: `.model`/`.ic`/`.nodeset` are simulation setup (test_jfet
        # lost its `.MODEL 2N3459`, test_stdcells its nine XSPICE d_lut models),
        # `.subckt`/`.ends`/`.global` are structure the cell defines locally, and
        # an unrecognised dot-card is by definition something we cannot prove is
        # droppable. LOSSLESS-OR-LOUD: keep it AND say so.
        self._to_residue(line, "dot-card" if line.startswith(".")
                         else "circuit element")

    def _to_residue(self, line, what):
        """Keep a deck line that has no ASE-state destination, loudly."""
        self.residue.append(line)
        self.warnings.append(
            "%s has no ASE state field, kept on the clean schematic as a "
            "netlist_commands block: %s" % (what, line))

    # -- inside .control ------------------------------------------------------
    def _parse_control_line(self, line):
        head = line.split()[0].lower()
        # ngspice's `pre_*` family runs BEFORE the netlist is parsed, which is the
        # only way to load a compiled Verilog-A module (`pre_osdi <file>.osdi`) —
        # there is no `.osdi` dot-card. IHP SG13G2 needs four of them or every
        # bench with a MOS/varicap/r3_cmc dies at "could not find a valid
        # modelname" (ihp-sg13g2/cadence_style_rc:40-49). They are not analyses,
        # so they get their own state field rather than the raw_control bin (which
        # is report-only and would silently break every migrated IHP bench).
        # Probed on ngspice-46: a pre_ command placed in render_deck's trailing
        # .control block still preloads correctly.
        if head.startswith("pre_"):
            self.pre_commands.append(line)
            return
        if head in _MAPPABLE_CONTROL:
            self._parse_analysis(line)
            return
        if head in ("save", "print"):
            # `save` takes vectors only — `vs`/`vd`/`vg` are ordinary net names
            # there. Only `print`/`plot` have the display grammar.
            for e in _probe_tokens(line, self.warnings, display=(head == "print")):
                self._add_output(e, 0)
            return
        if head == "plot":
            for e in _probe_tokens(line, self.warnings, display=True):
                mo = _PLOT_OFFSET_RE.match(e)
                if mo:                       # `plot clk+2` — +2 is a screen offset
                    self.warnings.append(
                        "plot display offset dropped: %s -> %s" % (e, mo.group(1)))
                    e = mo.group(1)
                self._add_output(e, 1)
            return
        if head in ("option", "options"):
            self._parse_options(line.split(None, 1)[1] if len(line.split()) > 1 else "")
            return
        if head in _DROP_CONTROL:
            return
        if head in _KEEP_CONTROL:
            self.raw_control.append(line)
            if head in _ANALYSIS_CONTROL:
                self.unmapped_analyses.append(head)
            self.warnings.append("unmappable .control command preserved: %s" % line)
            return
        self.raw_control.append(line)
        self.warnings.append("unrecognized .control command preserved: %s" % line)

    # -- shared bits ----------------------------------------------------------
    def _parse_analysis(self, body):
        toks = body.split()
        t = toks[0].lower()
        # The ASE schema holds ONE row per analysis type, so a second card of the
        # same type overwrites the first. test_inv's ngspice block carries
        # `tran 0.004n 30n` and then `tran 0.02n 30n`; only the last survived, and
        # in silence. Last-wins matches ngspice's own .control semantics (the
        # later card is the one that runs last), so keep it — but say so.
        if t in self.analyses:
            self.warnings.append(
                "a later %s card replaces the one already migrated (ASE holds "
                "one row per type): %s" % (t, body))
        if t == "op":
            self.analyses["op"] = {"type": "op", "enabled": "1"}
        elif t == "dc" and len(toks) >= 5:
            self.analyses["dc"] = {"type": "dc", "enabled": "1", "source": toks[1],
                                   "start": toks[2], "stop": toks[3], "step": toks[4]}
            if len(toks) > 5:
                self.warnings.append("dc 2nd sweep source dropped: %s" % body)
        elif t == "ac" and len(toks) >= 5:
            # ngspice: ac <dec|oct|lin> N fstart fstop  ;  ASE schema uses dec/points
            self.analyses["ac"] = {"type": "ac", "enabled": "1", "points": toks[2],
                                   "start": toks[3], "stop": toks[4]}
        elif t == "tran" and len(toks) >= 3:
            a = {"type": "tran", "enabled": "1", "step": toks[1], "stop": toks[2]}
            self.analyses["tran"] = a
        else:
            self.warnings.append("could not parse analysis: %s" % body)

    def _parse_params(self, rest):
        # `.param a=1 b = 2` -> normalize spaces around '=' then split on ws,
        # keeping brace/paren groups whole (`.param p={1.8 * 2}` is ONE token —
        # a bare split() cut it at the space and emitted the value `{1.8`).
        rest = re.sub(r"\s*=\s*", "=", rest.strip())
        for tok in _split_ws(rest):
            if "=" in tok:
                name, val = tok.split("=", 1)
                self.params.append((name, val))
            elif tok:                        # LOSSLESS-OR-LOUD: never drop silently
                self.warnings.append("trailing .param token dropped: %s" % tok)

    def _parse_options(self, rest):
        rest = re.sub(r"\s*=\s*", "=", rest.strip())
        toks = _split_ws(rest)
        i = 0
        while i < len(toks):
            tok = toks[i]
            if (tok.lower() == "save" and i + 1 < len(toks)
                    and toks[i + 1].lower() == "all"):
                self.save_all_v = True       # `.options save all` = blanket save
                i += 2
                continue
            i += 1
            if "=" in tok:
                name, val = tok.split("=", 1)
            else:
                name, val = tok, None
            if not name:
                continue
            if not _OPT_NAME_RE.match(name):
                self.warnings.append("non-identifier option token dropped: %s" % tok)
                continue
            # `.option temp=<T>` is the simulation temperature, the same knob as
            # `.temp`. Left in `options` it was silently overridden: render_deck
            # (src/ase.tcl) emits the options rows first and `.temp <temperature>`
            # LAST, and ngspice lets the last one win — so a bench that asked for
            # -40 C ran at the default 27 (issue 0210
            # `temperature-overrides-options-temp`).
            if name.lower() == "temp":
                if val is not None and _NUM_RE.match(val):
                    self.temperature = val
                else:
                    self.warnings.append(
                        "non-numeric option temp not migrated (ASE needs a "
                        "number; the deck's .temp would override it): %s" % tok)
                continue
            self.options.append((name, val))


# --------------------------------------------------------------------------- #
# graph blocks (B <layer> ... {flags=graph ... node=...}) -> plotted outputs
# --------------------------------------------------------------------------- #

# `node` is xschem's trace mini-language, NOT a whitespace list. Authority is
# draw_graph() src/draw.c ~4645-4801 (row split my_strtok_r(nptr,"\n","\"",4),
# src/util.c:159); see doc/xschem_man/graphs.html and
# doc/claude/code_analysis/waveform_subsystem_reference.md §2.5:
#   * rows are separated by NEWLINE only; `"` quotes a row (quotes stripped, may
#     span lines) and `\` escapes the next char — a trailing `\` is a
#     CONTINUATION and must never survive as a token (that stray `\` is what
#     used to reach the serializer and abort the whole library migration)
#   * `alias;expr`         -> text before the first `;` is the legend LABEL only
#   * `label;a[3],a[2],..` -> a BUS row (a `,` after the `;`): one trace, N bits
#   * unescaped whitespace in the expression -> an xschem RPN expression
#   * `%N` / `%rawfile%simtype` suffix -> dataset selection (no ASE equivalent)
# ASE outputs are ngspice `.save`/`print` arguments (src/ase.tcl render_deck), so
# a bus contributes its BITS and an RPN expression its OPERANDS — the derived
# trace itself is not a saveable vector. Both are reported, never silent.
_RPN_OPS = frozenset(("+", "-", "*", "/", "**", "%", "^", "!",
                      ">", "<", ">=", "<=", "==", "!=", "&", "|"))
_RPN_FUNC_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\(\)$")
_RPN_NUM_RE = re.compile(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?[A-Za-z]*$")
_BUS_BIT_SEP_RE = re.compile(r"[;,\s\\]+")      # get_bus_idx_array(), draw.c:2842
# A `----` row is a graph VISUAL SEPARATOR (xschem just draws nothing for it), not
# a vector — see doc/claude/issues/0295-*.md. Deliberately narrower than "row has
# no alphanumerics": `0` is a legal node name, and a numeric row is already caught
# (loudly) by the reference-line path below.
_GRAPH_SEP_RE = re.compile(r"^[-\s]+$")


def _graph_rows(node):
    """Split a `node=` value into trace rows exactly as my_strtok_r(s,"\\n","\\"",4)
    does: newline-only separator, `"` quoting (quotes stripped), `\\` escapes the
    next char and is kept, empty rows dropped."""
    rows, cur, quoted, esc = [], [], False, False
    for ch in node:
        if esc:
            cur.append(ch)
            esc = False
            continue
        if ch == "\\":
            esc = True
            cur.append(ch)
            continue
        if ch == '"':
            quoted = not quoted
            continue
        if ch == "\n" and not quoted:
            if cur:
                rows.append("".join(cur))
                cur = []
            continue
        cur.append(ch)
    if cur:
        rows.append("".join(cur))
    return [r for r in rows if r.strip()]


def _graph_unescape(s):
    """Undo the escapes xschem keeps inside a row: `\\ ` is a literal space
    (draw.c:4770 str_replace), `\\`+newline is a line continuation."""
    s = re.sub(r"\\\n[ \t]*", "", s)
    return s.replace("\\ ", " ").strip()


def _row_outputs(row, warn):
    """One `node=` row -> [(expr, plot, label), ...]."""
    core = row
    if "%" in core:
        core, _sep, tail = core.partition("%")
        warn.append("graph dataset/rawfile selector dropped: %%%s" % tail.strip())
    fields = core.split(";")
    label = fields[0].strip() if len(fields) > 1 else None
    # find_nth() collapses runs of separators, so `a;;b` gives the expression `b`
    tail = [f for f in fields[1:] if f.strip()]
    if len(tail) > 1:
        warn.append("graph row truncated at its 2nd ';' (as xschem does): %s" % row)
    if len(fields) > 1:
        raw = tail[0] if tail else ""
    else:
        raw = core
    if len(fields) > 1 and "," in raw:                          # BUS row
        # keep index 0 out (it is the bus label) WITHOUT filtering empties first,
        # else `;a,b` would lose bit `a` with the empty label field
        bits = [b for b in _BUS_BIT_SEP_RE.split(_graph_unescape(core))[1:] if b]
        if len(bits) > 32:
            warn.append("graph bus %s expanded to %d single-bit outputs"
                        % (label or "?", len(bits)))
        return [(b, 1, None) for b in bits]
    raw = raw.strip()
    if not raw:
        warn.append("graph row carries no expression, dropped: %s" % row)
        return []
    if _GRAPH_SEP_RE.match(raw):                                # `----` separator
        # This row used to reach the plain-signal `return` at the bottom because
        # none of the three drop paths fit it: no whitespace so not RPN, a
        # leading `-` with no digit after it so not _RPN_NUM_RE, and _graph_rows
        # drops only empty/blank rows. Migration therefore emitted
        # `{name o2 expr ----}` and render_deck a `.save ----`. Measured on
        # ngspice-42 (issue 0159's evidence, restated in 0295): a
        # `.save <not-a-vector>` as the ONLY .save aborts the run outright ("no
        # data saved for Transient analysis; analysis not run"), and alongside a
        # valid .save it is dropped silently and the trace simply never appears.
        # Tested against the EXPRESSION rather than the whole row (a DECISION,
        # see 0295): that also kills `sep;----`, while `-; 0.9` still reaches the
        # reference-line path and `----;v(out)` keeps its signal.
        # LOSSLESS-OR-LOUD (:519): warn, never drop in silence.
        warn.append("graph separator row is not a signal, dropped: %s" % row)
        return []
    if re.search(r"(?<!\\)[ \t]", raw):                         # RPN expression
        toks = [_graph_unescape(t) for t in re.split(r"(?<!\\)[ \t]+", raw)]
        operands = [t for t in toks if t and t not in _RPN_OPS
                    and not _RPN_FUNC_RE.match(t) and not _RPN_NUM_RE.match(t)]
        warn.append("graph expression not saveable as one vector, keeping its "
                    "operands (%s): %s" % (", ".join(operands) or "none", raw))
        return [(t, 1, None) for t in operands]
    expr = _graph_unescape(raw)                                 # plain signal
    if _RPN_NUM_RE.match(expr):
        # a constant reference line (`-; 0.9`) is not a vector: ngspice aborts
        # the analysis on `.save 0.9` when nothing else got saved
        warn.append("graph reference-line constant is not a signal, dropped: %s"
                    % row)
        return []
    return [(expr, 1, label)]


def graph_outputs(props, warn=None):
    """Plotted expressions recovered from a graph B-record's props: [(expr, plot,
    label), ...]. `warn` collects the lossy bits (bus expansion, dropped dataset
    selectors, non-saveable expressions)."""
    warn = [] if warn is None else warn
    found, node = get_tok(props, "node")
    if not found or not node:
        return []
    if node.lstrip().startswith("tcleval("):
        warn.append("graph node= is tcleval(...), evaluated at draw time — "
                    "outputs not migrated: %s" % node.strip()[:60])
        return []
    out = []
    for row in _graph_rows(node):
        out.extend(_row_outputs(row, warn))
    return out


# --------------------------------------------------------------------------- #
# classification
# --------------------------------------------------------------------------- #

_DROP_CELLS = frozenset(("launcher",))
_EMBED_CELLS = frozenset((
    "code_shown", "code", "spice_code_shown", "netlist_commands",
    "simulator_commands", "simulator_commands_shown", "spice", "ngspice"))


# --------------------------------------------------------------------------- #
# .sch record writing — the inverse of migrate_pin_names' scanner
# --------------------------------------------------------------------------- #
# Two nested escape layers, and BOTH have to be right or the residue block comes
# back as garbage (or unparseable) on the next read:
#   * value layer   — an attribute value containing whitespace is `"…"`-quoted,
#                     and `\` / `"` inside it are backslash-escaped. This is the
#                     layer get_tok_value (src/token.c ~516) undoes.
#   * record layer  — the whole property string sits inside the record's `{…}`,
#                     so `\`, `{` and `}` each get a backslash (src/save.c:2542).
#                     This is the layer _read_braced (migrate_pin_names) undoes.
# Applied in that order, `table_values "1110"` becomes `table_values \\"1110\\"`,
# which is byte-for-byte how xschem itself stores test_stdcells' d_lut card.

def _attr_quote(v):
    """Value layer: a `"`-quoted attribute value."""
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _sch_escape(props):
    """Record layer: escape a property string for a record's `{…}` field."""
    return re.sub(r"([\\{}])", r"\\\1", props)


def _cell_of(symref):
    """Bare cell name from a C symref (`gf180mcu_pr/nfet_03v3` -> `nfet_03v3`,
    `sky130_fd_pr/corner` -> `corner`), extension stripped."""
    base = symref.rsplit("/", 1)[-1]
    for ext in (".sym", ".sch"):
        if base.endswith(ext):
            base = base[:-len(ext)]
    return base


def classify(rec):
    """Category for a scanned record: 'header' | 'circuit' | 'corner' | 'embedded'
    | 'graph' | 'drop' | 'other'. 'circuit'/'header'/'other' stay on the clean
    schematic; the rest are extracted or dropped."""
    tag = rec.tag
    if tag in ("v", "G", "K", "V", "S", "E", "#"):
        return "header"
    if tag == "N":
        return "circuit"
    if tag == "C":
        cell = _cell_of(rec.fields[0].content)
        if cell == "corner":
            return "corner"
        if cell in _EMBED_CELLS:
            return "embedded"
        if cell in _DROP_CELLS:
            return "drop"
        return "circuit"
    if tag == "B":
        props = rec.fields[5].content
        found, flags = get_tok(props, "flags")
        if (found and "graph" in flags) or "flags=graph" in props:
            return "graph"
        return "other"
    return "other"      # T / L / P / A -> keep as annotation


# --------------------------------------------------------------------------- #
# the migrator
# --------------------------------------------------------------------------- #

_VSOURCE_CELLS = frozenset(("vsource", "isource", "vpulse", "ipulse"))
_NUM_RE = re.compile(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$")
# a lib-qualified `schematic=<lib>/<cell>` override inside an instance's props
_SCHEMATIC_ATTR_RE = re.compile(r"(\bschematic=)([^\s}]+)")
# Every `$VAR` / `$::VAR` / `${VAR}` a path names. Leading digits are legal in a
# Tcl variable name and gf180's model var IS `180MCU_MODELS`, so the name class
# cannot exclude them.
_VAR_RE = re.compile(r"\$(?:::)?\{?([A-Za-z0-9_]+)")
# ngspice `dc` accepts these in the source slot instead of a circuit element
# (`dc temp -40 125 5` is a temperature sweep — test_res, and five IHP benches).
_DC_SPECIAL_SOURCES = frozenset(("temp",))


class MigrationReport(object):
    def __init__(self):
        self.kept = 0
        self.dropped = []          # (category, detail)
        self.extracted = {}        # field -> count
        self.warnings = []
        self.hoisted = []          # (instance, var, value)
        self.rebound = []          # (old_ref, new_ref) srclib -> dstlib rewrites

    def as_text(self):
        out = ["kept %d record(s)" % self.kept]
        if self.extracted:
            out.append("extracted: " + ", ".join(
                "%s=%d" % (k, v) for k, v in sorted(self.extracted.items())))
        if self.hoisted:
            out.append("hoisted sources: " + ", ".join(
                "%s->%s(%s)" % h for h in self.hoisted))
        if self.rebound:
            out.append("rebound %d ref(s): " % len(self.rebound) + ", ".join(
                sorted(set("%s->%s" % r for r in self.rebound))))
        if self.dropped:
            out.append("dropped: " + ", ".join(d[0] for d in self.dropped))
        for w in self.warnings:
            out.append("WARN: " + w)
        return "\n".join(out)


class CellMigrator(object):
    """Migrate one cluttered testbench schematic to (clean_sch, state)."""

    def __init__(self, sch_text, pdk, libname, cellname, hoist_sources=False,
                 srclib=None, migrated_cells=None, sym_text=None, srcdir=None):
        self.sch_text = sch_text
        self.srcdir = srcdir                # source schematic dir, for .include checks
        self.pdk = pdk
        self.libname = libname
        self.cellname = cellname
        self.hoist_sources = hoist_sources
        # A migrated cell that instantiates a SIBLING keeps a `C {<srclib>/<cell>}`
        # symref, so the clean schematic netlists the CLUTTERED original one level
        # down — the same class of bug c31fad1d fixed for the state's `design=`,
        # and the one the tool used to ship (19 of the 48 sky130 cells; tb_bandgap
        # pulled in sky130_tests/bandgap). srclib + migrated_cells are what
        # _rebind_refs needs to re-point those at the destination library.
        self.srclib = srclib
        self.migrated_cells = frozenset(migrated_cells or ())
        self.sym_text = sym_text            # source symbol view, copied verbatim+rebound
        self.report = MigrationReport()
        self.clean_sch = None
        self.clean_sym = None
        self.state = None
        self.residue_recs = []              # synthesized netlist_commands records
        self._circuit_names = set()         # name= of every kept C record (lowercased)

    @staticmethod
    def _embed_skip_reason(props):
        """Why the ngspice netlister would NOT emit this embedded block.

        Parsing a block xschem never emits is worse than useless: test_multisim's
        two `spice_ignore=true` code_shown blocks are Tcl (`[if [sim_is_ngspice]
        {return {`), and its `simulator=xyce` block is a different simulator's
        deck. Both used to be parsed as if they were live ngspice text."""
        found, ign = get_tok(props, "spice_ignore")
        if found and ign.strip().lower() in ("true", "1"):
            return "spice_ignore=true"
        found, sim = get_tok(props, "simulator")
        if found and sim.strip() and sim.strip().lower() != "ngspice":
            return "simulator=%s" % sim.strip()
        return None

    def migrate(self):
        recs = scan_records(self.sch_text)
        deck = SpiceDeck()
        kept = []
        g_outputs = []
        for rec in recs:
            cat = classify(rec)
            if cat in ("header", "circuit", "other"):
                kept.append(rec)
                self.report.kept += 1
                if rec.tag == "C":
                    _f, nm = get_tok(rec.fields[5].content, "name")
                    if nm:
                        self._circuit_names.add(nm.strip().lower())
            elif cat == "corner":
                _f, cv = get_tok(rec.fields[5].content, "corner")
                deck.add_corner(self.pdk, cv)
                self.report.dropped.append(("corner", cv))
            elif cat == "embedded":
                props = rec.fields[5].content
                skip = self._embed_skip_reason(props)
                if skip:
                    self.report.warnings.append(
                        "embedded block %s not parsed: the ngspice netlister "
                        "would not emit it" % skip)
                    self.report.dropped.append(
                        ("embedded", _cell_of(rec.fields[0].content)))
                    continue
                _f, val = get_tok(props, "value")
                if val:
                    res = deck.parse(val)
                    if res:
                        self._add_residue(rec, props, res)
                self.report.dropped.append(("embedded", _cell_of(rec.fields[0].content)))
            elif cat == "graph":
                g_outputs.extend(graph_outputs(rec.fields[5].content,
                                               self.report.warnings))
                self.report.dropped.append(("graph", None))
            elif cat == "drop":
                self.report.dropped.append(("drop", _cell_of(rec.fields[0].content)))
        self.report.warnings.extend(deck.warnings)

        kept = self._maybe_hoist(kept, deck)
        # rebind AFTER reconstruction: _reconstruct slices the SOURCE text by
        # absolute record offsets, so rewriting it first would shift them.
        self.clean_sch = self._rebind_text(self._reconstruct(kept))
        self.clean_sym = self._rebind_text(self.sym_text) if self.sym_text else None
        self.state = self._build_state(deck, g_outputs)
        return self

    # -- residue: deck lines with no state field, kept on the schematic --------
    def _add_residue(self, rec, props, lines):
        """One `devices/code` netlist_commands record carrying `lines`.

        Placed at the source block's own coordinates and inheriting its
        `only_toplevel` / `place` scope, so a source that was `only_toplevel=true`
        stays out of a parent's netlist and a `place=end` block stays at the end.
        `devices/code` (not `code_shown`) keeps the clean schematic visually
        clean, and its symbol `format` is a bare `@value` — no `tcleval(…)`
        wrapper — so a line like the XSPICE `A1 [A B] IX …` survives with its
        brackets intact instead of being read as Tcl command substitution."""
        _f, srcname = get_tok(props, "name")
        _f, otl = get_tok(props, "only_toplevel")
        _f, place = get_tok(props, "place")
        n = len(self.residue_recs) + 1
        name = "ASE_KEEP%d" % n
        attrs = ["name=" + name]
        if otl and otl.strip():
            attrs.append("only_toplevel=" + otl.strip())
        if place and place.strip():
            attrs.append("place=" + place.strip())
        attrs.append("value=" + _attr_quote("\n" + "\n".join(lines) + "\n"))
        x, y = rec.fields[1].text, rec.fields[2].text
        self.residue_recs.append(
            "C {devices/code} %s %s 0 0 {%s}" % (x, y, _sch_escape("\n".join(attrs))))
        # a kept element line DECLARES a circuit element, so the analyses
        # cross-check below must see its name (`vd d 0 0` -> `vd`)
        for ln in lines:
            if not ln.startswith("."):
                self._circuit_names.add(ln.split()[0].strip().lower())
        self.report.extracted["residue_lines"] = (
            self.report.extracted.get("residue_lines", 0) + len(lines))
        self.report.warnings.append(
            "%d line(s) from embedded block %s kept as netlist_commands %s"
            % (len(lines), srcname or "?", name))

    # -- source-library reference rebinding -----------------------------------
    def _rebind_ref(self, ref):
        """`<srclib>/<cell>` -> `<dstlib>/<cell>` when <cell> is itself migrated.

        A reference to a cell that is NOT migrated is left alone: it must keep
        naming the source library, which stays registered beside the destination
        one (sky130_tests/not, sky130_tests/passgate, ... are plain sub-circuits
        with no clutter to extract, so they never get an _ase counterpart).
        Anything else — devices/, another PDK library, a generator with parens,
        an absolute path — is out of scope, same rule as
        xschem_libmigrate.rewrite_reference()."""
        if not self.srclib or not ref or "(" in ref or ref.startswith(("/", "~")):
            return ref
        pre, sep, tail = ref.partition("/")
        if not sep or pre != self.srclib or "/" in tail:
            return ref
        cell = tail
        for ext in (".sym", ".sch"):
            if cell.endswith(ext):
                cell = cell[:-len(ext)]
                break
        if cell not in self.migrated_cells:
            return ref
        new = self.libname + "/" + tail
        self.report.rebound.append((ref, new))
        return new

    def _rebind_text(self, text):
        """Rebind every `C {<ref>}` symref and lib-qualified `schematic=<ref>`
        override in a whole .sch/.sym text."""
        if not self.srclib:
            return text
        out = []
        pos = 0
        for rec in scan_records(text):
            if rec.tag != "C":
                continue
            f = rec.fields[0]
            new = self._rebind_ref(f.content)
            if new != f.content:
                out.append(text[pos:f.cstart])
                out.append(new)
                pos = f.cend
        text = "".join(out) + text[pos:] if out else text
        return _SCHEMATIC_ATTR_RE.sub(
            lambda m: m.group(1) + self._rebind_ref(m.group(2)), text)

    # -- source hoisting (opt-in heuristic) -----------------------------------
    def _maybe_hoist(self, kept, deck):
        if not self.hoist_sources:
            return kept
        new_kept = []
        for rec in kept:
            if rec.tag == "C" and _cell_of(rec.fields[0].content) in _VSOURCE_CELLS:
                props = rec.fields[5].content
                fname, name = get_tok(props, "name")
                fval, val = get_tok(props, "value")
                if fval and val and _NUM_RE.match(val.strip()) and fname and name:
                    var = name           # V1 -> param V1 (unambiguous, reversible)
                    deck.params.append((var, val.strip()))
                    self.report.hoisted.append((name, var, val.strip()))
                    raw = self.sch_text[rec.start:rec.end]
                    raw2 = re.sub(r"(\bvalue=)" + re.escape(val),
                                  r"\g<1>" + var, raw, count=1)
                    new_kept.append(_RawRecord(rec.tag, raw2))
                    continue
            new_kept.append(rec)
        return new_kept

    # -- clean schematic reconstruction ---------------------------------------
    def _reconstruct(self, kept):
        parts = []
        for rec in kept:
            if isinstance(rec, _RawRecord):
                parts.append(rec.raw)
            else:
                parts.append(self.sch_text[rec.start:rec.end])
        parts.extend(self.residue_recs)
        return "\n".join(parts) + "\n"

    # -- state assembly -------------------------------------------------------
    def _build_state(self, deck, g_outputs):
        # ahead of the literal: _includes may set deck.save_all_i when it removes
        # an unresolvable `.save` include, and the flag is read below
        includes = self._includes(deck)
        includes = self._resolvable("includes", includes, drop=True)
        models = self._resolvable("models", _dedup(deck.models), drop=True,
                                  key=lambda m: m[0])
        models = self._default_models(models)
        pre_cmds = self._resolvable("pre_commands", _dedup(deck.pre_commands),
                                    drop=True)
        st = {
            "version": "1",
            "simulator": "ngspice",
            "design": ["lib", self.libname, "cell", self.cellname,
                       "view", "schematic"],
            "rundir": "",
            "temperature": deck.temperature or "27",
            "models": [["file", f, "section", s] for (f, s) in models],
            "variables": [["name", n, "value", v] for (n, v) in deck.params],
            "analyses": self._analyses(deck),
            "outputs": self._outputs(deck, g_outputs),
            "save_all_v": "1" if deck.save_all_v else "0",
            "save_all_i": "1" if deck.save_all_i else "0",
            "options": [self._option_entry(n, v) for (n, v) in deck.options],
            "includes": [["file", f] for f in includes],
            "pre_commands": [["cmd", c] for c in pre_cmds],
            "viewer": "",
        }
        for f in ("models", "variables", "outputs", "options", "includes",
                  "pre_commands"):
            if st[f]:
                self.report.extracted[f] = len(st[f])
        return st

    # -- $VAR resolvability ---------------------------------------------------
    def _resolvable(self, field, items, drop=False, key=None):
        """Drop the entries whose `$VAR`s no workarea rc will ever set.

        `ase::expand_path` is `subst -nocommands -nobackslashes` at GLOBAL level
        (src/ase.tcl:140), so a path is only resolvable if every variable it names
        is a Tcl global at Run time: one the PDK's workarea rc guarantees
        (Pdk.env_vars) or one xschem itself defines (_XSCHEM_GLOBALS). Anything
        else — an UNqualified `$VAR` (never a global by construction) or a
        qualified `$::SKYWATER_STDCELLS` nobody sets — makes ase::expand_path
        THROW, and it throws while rendering the deck, so the whole cell cannot
        run: seven migrated sky130 benches died at
        `can't read "::SKYWATER_STDCELLS": no such variable` before ngspice
        started (issue 0210 bucket A). Failing loudly at MIGRATION time and
        shipping a runnable state beats shipping one that detonates at Run."""
        out = []
        for item in items:
            path = key(item) if key else item
            bad = sorted(set(v for v in _VAR_RE.findall(path)
                             if v not in self.pdk.env_vars
                             and v not in _XSCHEM_GLOBALS))
            if not bad:
                out.append(item)
                continue
            msg = ("%s path names $%s, which no workarea rc sets — "
                   "ase::expand_path would abort the run: %s"
                   % (field, "/$".join(bad), path))
            if drop:
                self.report.warnings.append(msg + " [DROPPED]")
            else:
                self.report.warnings.append(msg)
                out.append(item)
        return out

    def _default_models(self, models):
        """Seed the PDK's default corner when a cell has devices but no models.

        `bandgap`, `bandgap_opamp`, `charge_pump` and `charge_pump2` carry only a
        graph block — no corner symbol, no `.lib`, no embedded models — so they
        migrated with `models {}` and ngspice answered `unknown subckt:
        sky130_fd_pr__…` for every device (issue 0210 bucket D). A loaded state's
        explicit empty `models` also OVERRIDES the workarea's ::ASE_DEFAULT_MODELS
        (ase::state_load is a `dict merge` with the loaded value winning), so the
        rc default cannot rescue them either.

        Deliberately narrow: only when the cell instantiates a symbol from the
        PDK's own device library, and only for a PDK that HAS a corner mapping.
        Of the ten migrated sky130 cells with empty models this fires on exactly
        the four that need it."""
        if models or not self.pdk.corner_lib:
            return models
        if not self._uses_pdk_devices():
            return models
        m = self.pdk.corner_model(None)
        self.report.warnings.append(
            "no model card found but the cell instantiates %s devices; seeded "
            "the PDK default corner %s %s" % ("/".join(sorted(self.pdk.device_libs)),
                                              m[0], m[1]))
        return [m]

    def _uses_pdk_devices(self):
        """Does the CLEAN schematic instantiate a symbol from a PDK device lib?"""
        if not self.pdk.device_libs or self.clean_sch is None:
            return False
        for rec in scan_records(self.clean_sch):
            if rec.tag != "C":
                continue
            ref = rec.fields[0].content
            lib = ref.rsplit("/", 1)[0] if "/" in ref else ""
            if lib in self.pdk.device_libs:
                return True
        return False

    def _includes(self, deck):
        """Includes that will still resolve after the move.

        A relative `.include <cell>.save` is not a file the source tree ships —
        it is GENERATED by the bench's own `devices/launcher` button
        (`write_data [sg13g2_save_params] $netlist_dir/<cell>.save`,
        ihp-sg13g2/sg13g2_procs.tcl), and migration drops launchers. ASE renders
        `.include <cell>.save` verbatim into a deck that runs in ase::rundir, so
        ngspice answers "Could not find include file" and aborts the WHOLE run
        before any analysis — 12 of the 48 IHP benches, and 8 already-shipped
        sky130 states. Portable `$::VAR` paths are the workarea's business and
        are left alone; only a resolvable-here-and-now relative path survives."""
        out = []
        for f in _dedup(deck.includes):
            if "$" in f or os.path.isabs(f) or self.srcdir is None:
                out.append(f)
                continue
            if os.path.isfile(os.path.join(self.srcdir, f)):
                out.append(f)
                continue
            self.report.warnings.append(
                "include target does not exist and its generator (a launcher) is "
                "dropped by migration, include removed: %s" % f)
            # a sg13g2/sky130 `.save` list is exactly a device-current save set,
            # so the blanket flag keeps the intent rather than losing it silently
            if f.endswith(".save") and not deck.save_all_i:
                deck.save_all_i = True
                self.report.warnings.append(
                    "save_all_i enabled to stand in for the dropped %s" % f)
        return out

    @staticmethod
    def _option_entry(name, val):
        if val is None:
            return ["name", name, "value", "1"]
        return ["name", name, "value", val]

    def _analyses(self, deck):
        # canonical 4 entries, in fixed order; enabled ones carry their params.
        # if nothing was extracted, default op enabled (matches state_default).
        found = dict(deck.analyses)
        if not found and deck.unmapped_analyses:
            # the bench HAS an analysis, just not one the schema can express —
            # leave every row disabled rather than substitute a different
            # simulation that runs and looks healthy (the sp_* benches)
            self.report.warnings.append(
                "no analysis migrated: %s has no ASE equivalent; all analyses "
                "left disabled (pick one in ASE-L before running)"
                % ", ".join(sorted(set(deck.unmapped_analyses))))
        elif not found:
            found["op"] = {"type": "op", "enabled": "1"}
        order = ["op", "dc", "ac", "tran"]
        out = []
        for t in order:
            if t in found:
                d = dict(found[t])
                self._check_analysis_source(d)
                out.append(_dict_to_list(d, ["type", "enabled", "source",
                                             "start", "stop", "step", "points"]))
            else:
                out.append(["type", t, "enabled", "0"])
        return out

    def _check_analysis_source(self, d):
        """Refuse to ship a sweep naming a source that is not in the circuit.

        `dc <source> …` hard-FATALs ngspice when <source> is absent —
        "DC Transfer Function: Voltage source, current source, or resistor named
        \"vd\" is not in the circuit" — and the migration itself used to be what
        removed it (issue 0210 bucket B): the source was declared as a non-dot
        line inside the same block whose `.control dc vd …` supplied the analysis.
        With the residue kept the name is normally found; this is the backstop
        that turns any remaining case into a disabled row plus a loud warning
        instead of a state that detonates at Run."""
        src = d.get("source")
        if not src or d.get("enabled") != "1":
            return
        s = src.strip().lower()
        if s in _DC_SPECIAL_SOURCES or s in self._circuit_names:
            return
        d["enabled"] = "0"
        self.report.warnings.append(
            "%s sweeps '%s', which is not an element of the migrated circuit — "
            "ngspice would hard-fatal, so the analysis is shipped DISABLED "
            "(fix the source, then re-enable it in ASE-L)" % (d.get("type"), src))

    @staticmethod
    def _control_defined(deck):
        """Vector names DEFINED by a .control line the migration does not carry.

        `let gain_dB = vdb(inv_out)` / `meas ac fc_l when …` go to raw_control
        (report only), so in the migrated deck those names do not exist. A
        `print gain_dB` in the same block still made an output row with
        `save 1`, i.e. a `.save gain_dB` + `print gain_dB` naming nothing
        (issue 0210 `nonvector-output-exprs`)."""
        names = set()
        for line in deck.raw_control:
            toks = line.split()
            head = toks[0].lower() if toks else ""
            if head == "let" and len(toks) >= 2:
                names.add(toks[1].split("=")[0].split("[")[0].strip().lower())
            elif head in ("meas", "measure") and len(toks) >= 3:
                names.add(toks[2].strip().lower())     # meas <ac|dc|tran> <name>
        names.discard("")
        return names

    def _outputs(self, deck, g_outputs):
        derived = self._control_defined(deck)
        seen = {}
        order = []
        for item in list(deck.outputs) + list(g_outputs):
            expr, plot = _normalize_expr(item[0], self.report.warnings), item[1]
            label = item[2] if len(item) > 2 else None     # graph legend alias
            if expr in seen:
                if plot:                        # a plotted node upgrades plot flag
                    seen[expr]["plot"] = "1"
                if label and not seen[expr]["label"]:
                    seen[expr]["label"] = label
                continue
            seen[expr] = {"expr": expr, "plot": "1" if plot else "0",
                          "label": label}
            order.append(expr)
        out = []
        used = set()
        for i, expr in enumerate(order, 1):
            e = seen[expr]
            name = None
            if e["label"]:                  # the graph legend alias, if it is free
                cand = _mk_name(e["label"], i)
                if cand not in used:        # an alias that would need a _2 suffix
                    name = cand             # reads worse than the expr-derived name
                    used.add(cand)
            if name is None:
                name = _mk_name(expr, i, used)
            save = "1"
            if expr.lower() in derived:
                # keep the ROW (it records what the bench wanted to look at) but
                # do not emit a `.save`/`print` for a vector the deck never makes
                save = "0"
                self.report.warnings.append(
                    "output '%s' is defined by a .control let/meas that has no "
                    "ASE equivalent; kept with save=0 (re-derive it in ASE-L)"
                    % expr)
            out.append(["name", name, "expr", e["expr"], "save", save,
                        "plot", e["plot"]])
        return out

    # -- output files ---------------------------------------------------------
    def write(self, out_cellroot, dry_run=False):
        sch = os.path.join(out_cellroot, "schematic", self.cellname + ".sch")
        stt = os.path.join(out_cellroot, "ngspice_state1",
                           self.cellname + ".state")
        # Serialize BOTH views before writing EITHER: a serializer failure used
        # to leave the clean .sch on disk with no state view beside it (a cell
        # ASE-L would then open with no setup at all). This also makes --dry-run
        # exercise the serializer, so a dry run is a real check, not a
        # false all-clear.
        sch_text = self.clean_sch
        state_text = serialize_state(self.state, SCHEMA_KEYS)
        if not dry_run:
            _write(sch, sch_text)
            _write(stt, state_text)
            # The symbol view comes along or the rebound `<dstlib>/<cell>` refs
            # above resolve to nothing: cellview_resolve (src/library_defs.tcl)
            # wants <libpath>/<cell>/symbol/<cell>.sym, and without it the cell
            # also cannot be placed from the Library Manager.
            if self.clean_sym is not None:
                _write(os.path.join(out_cellroot, "symbol",
                                    self.cellname + ".sym"), self.clean_sym)
        return sch, stt


class _RawRecord(object):
    __slots__ = ("tag", "raw")

    def __init__(self, tag, raw):
        self.tag = tag
        self.raw = raw


# --------------------------------------------------------------------------- #
# small helpers
# --------------------------------------------------------------------------- #

def _dedup(seq):
    seen = set()
    out = []
    for x in seq:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def _dict_to_list(d, key_order):
    out = []
    for k in key_order:
        if k in d:
            out.extend([k, d[k]])
    for k in d:                                  # any extra keys after the known ones
        if k not in key_order:
            out.extend([k, d[k]])
    return out


_NAME_MAX = 40


def _mk_name(expr, i, used=None):
    """ASE output name for an expression: an identifier the waveform viewer
    accepts (`^[A-Za-z_][A-Za-z0-9_]*$`, src/ase_window.tcl) and UNIQUE within
    the state — ase::result_probe keys its results dict by name, so a duplicate
    silently shadowed another output's value."""
    base = re.sub(r"[^A-Za-z0-9]", "", expr)
    if len(base) > _NAME_MAX:
        # keep the TAIL too: for `@m.x11.msky130_fd_pr__pfet…_base[gm|id|vth]`
        # the discriminating part is the suffix, and a head-only cut left three
        # identical names that the _2/_3 dedupe then made indistinguishable
        base = base[:_NAME_MAX - 12] + base[-12:]
    if not base:
        base = "o%d" % i
    if base[0].isdigit():
        base = "o" + base
    if used is None:
        return base
    name, n = base, 2
    while name in used:
        name = "%s_%d" % (base, n)
        n += 1
    used.add(name)
    return name


def _read(p):
    with open(p) as f:
        return f.read()


def _write(p, text):
    d = os.path.dirname(p)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(p, "w") as f:
        f.write(text)


# --------------------------------------------------------------------------- #
# library walk
# --------------------------------------------------------------------------- #

class LibraryMigrator(object):
    """Migrate every testbench cell (a cell with a schematic view carrying an
    embedded corner/commands/graph) under a lib/cell/view library root."""

    def __init__(self, libroot, pdk, libname=None, hoist_sources=False):
        self.libroot = libroot
        self.pdk = pdk
        # The state's `design` must name the library the MIGRATED cell lives in,
        # not the one it came from: ASE resolves lib/cell/view out of the
        # registry, so a source-library name sends Session > Design Window back
        # to the cluttered original. Unless the caller names the library, it is
        # taken from the DESTINATION root in migrate_all() below.
        self.libname = libname or os.path.basename(os.path.normpath(libroot))
        self.libname_explicit = libname is not None
        # the SOURCE library's own name — what a sibling instance is qualified
        # with today, and therefore what _rebind_ref rewrites away from.
        self.srclib = os.path.basename(os.path.normpath(libroot))
        self.hoist_sources = hoist_sources
        self.cells = []          # [(cellname, CellMigrator), ...]
        self.skipped = []        # [(cellname, reason), ...]
        self.failed = []         # [(cellname, error), ...]

    def scan(self):
        for cell in sorted(os.listdir(self.libroot)):
            sch = os.path.join(self.libroot, cell, "schematic", cell + ".sch")
            if not os.path.isfile(sch):
                continue
            try:
                text = _read(sch)
                recs = scan_records(text)
            except (ParseError, OSError) as e:
                self.skipped.append((cell, "parse: %s" % e))
                continue
            cats = [classify(r) for r in recs]
            if not any(c in ("corner", "embedded", "graph") for c in cats):
                # A launcher ('drop') on its own is deliberately NOT a trigger:
                # it is a GUI button, not simulation setup, so the migration
                # would have nothing to put in the state, and triggering on it
                # would sweep in pure index/gallery cells (sg13g2_tests'
                # IHP_testcases, gf180's 0_top). Such a cell simply stays in the
                # source library, where _rebind_ref correctly keeps pointing at
                # it (issue 0210 `drop-only-cells-skipped`).
                self.skipped.append(
                    (cell, "launcher only, nothing to extract" if "drop" in cats
                     else "no clutter to extract"))
                continue
            sym = os.path.join(self.libroot, cell, "symbol", cell + ".sym")
            self.cells.append((cell, CellMigrator(
                text, self.pdk, self.libname, cell, self.hoist_sources,
                srclib=self.srclib, srcdir=os.path.dirname(sch),
                sym_text=_read(sym) if os.path.isfile(sym) else None)))
        return self

    def migrate_all(self, out_root, dry_run=False):
        """Migrate every scanned cell. One bad cell is recorded in `failed` and
        skipped — it must not abort the library walk and strand the rest."""
        results = []
        if not self.libname_explicit:          # the destination library owns the
            self.libname = os.path.basename(os.path.normpath(out_root))
        # The rebind set has to be the WHOLE scan result, known before the first
        # cell is written: cell A may instantiate cell B that the walk reaches
        # later, and a per-cell view of "what exists yet" would rebind A's
        # reference in one direction and B's in the other.
        migrated = frozenset(c for c, _cm in self.cells)
        for cell, cm in self.cells:
            cm.libname = self.libname          # migrated cell, so it names it
            cm.migrated_cells = migrated
            try:
                cm.migrate()
                cm.write(os.path.join(out_root, cell), dry_run=dry_run)
            except Exception as e:
                self.failed.append((cell, "%s: %s" % (type(e).__name__, e)))
                continue
            results.append((cell, cm.report))
        # A library xschem cannot see is a library the migrated `design {lib …}`
        # cannot resolve — library_registry (src/library_defs.tcl) takes a
        # directory for a library only via a library.defs DEFINE or a
        # library.tag. The tag is ours to write; the DEFINE lives in the
        # workarea's registry file, so main() prints it as an instruction.
        if not dry_run and results:
            _write(os.path.join(out_root, "library.tag"),
                   "NAME %s\n" % self.libname)
        return results


# --------------------------------------------------------------------------- #
# verification (optional; needs xschem + ngspice)
# --------------------------------------------------------------------------- #

# Parameters are baked in by verify() via @@PLACEHOLDER@@ substitution: xschem
# consumes args after `--script FILE` as files to OPEN (not Tcl $argv), so there
# is no argv channel — the values are written straight into the generated driver.
_VERIFY_TCL = r"""
set repo      {@@REPO@@}
set modelsdir {@@MODELSDIR@@}
set libname   {@@LIBNAME@@}
set cell      {@@CELL@@}
set before    {@@BEFORE@@}
set afterroot {@@AFTERROOT@@}
set ::@@MODELVAR@@ $modelsdir
set scratch {@@SCRATCH@@}
file delete -force $scratch; file mkdir $scratch
set f [open [file join $scratch library.defs] w]
# the after tree (migrated) as $libname; keep the PRIMITIVE libs resolvable too.
# Only primitive libs from the repo — never redefine $libname (the *_tests lib we
# are migrating), else the registry would load the cluttered repo cell instead of
# the clean migrated one.
puts $f "DEFINE $libname [file normalize $afterroot]"
foreach d [list gf180mcu_pr sky130_fd_pr sg13g2_pr sg13g2_stdcells] {
  foreach base [list [file join $repo gf180mcuD xschem_libs $d] \
                     [file join $repo sky130A xschem_libs $d] \
                     [file join $repo ihp-sg13g2 xschem_libs $d]] {
    if {[file isdir $base]} { puts $f "DEFINE $d $base" }
  }
}
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

proc idval {log} {
  set v ""
  foreach ln [split $log \n] {
    if {[regexp {(?:^|\s)-?i\(v1\)\s*=\s*(\S+)} $ln -> m]} { set v $m }
  }
  return $v
}

# --- BEFORE: the cluttered cell, netlist + direct ngspice ---
set idb ""
if {[auto_execok ngspice] ne {}} {
  xschem load $before
  set ::netlist_dir $scratch
  xschem set netlist_type spice
  xschem netlist
  set bnl [file join $scratch $cell.spice]
  set blog [file join $scratch before.log]
  catch {exec ngspice -b $bnl > $blog 2>@1}
  set f [open $blog r]; set idb [idval [read $f]]; close $f
}

# --- AFTER: the migrated state view, through the public ase:: API ---
set ida ""
set st [ase::state_load [file join $afterroot $cell ngspice_state1 $cell.state]]
set rundir [file normalize [file join $scratch run]]
dict set st rundir $rundir
if {[auto_execok ngspice] ne {}} {
  set id [ase::run $st]; ase::wait $id
  set res [ase::last_result]
  # last_result is keyed by OUTPUT NAME; match the -i(v1) op-point probe by its
  # expr, then fall back to the first numeric result if that expr is absent.
  foreach o [dict get $st outputs] {
    if {[dict get $o expr] eq "-i(v1)"} {
      set nm [dict get $o name]
      if {[dict exists $res $nm]} { set ida [dict get $res $nm] }
    }
  }
  if {$ida eq "" } {
    dict for {k v} $res { if {[string is double -strict $v]} { set ida $v; break } }
  }
}
puts "ID_BEFORE $idb"
puts "ID_AFTER $ida"
"""


def verify(repo, pdk, libname, cellname, before_sch, after_root,
           models_dir, xschem="./src/xschem"):
    """Run the cluttered cell and the migrated state view through xschem+ngspice
    and return (id_before, id_after, ok). ok compares within 1 uA (or None if
    ngspice absent)."""
    drv = os.path.join(after_root, "_verify_%d.tcl" % os.getpid())
    # The driver's scratch dir is OWNED BY PYTHON, not by the driver: the Tcl
    # used to mkdir `_ase_mig_verify_<pid>` under [pwd] (= the repo root) and
    # delete it on its last line, so any driver that errored out, crashed, or
    # hit the 180 s timeout orphaned it in the working tree. Baking the path in
    # here lets the `finally` below remove it on every path.
    # See doc/claude/issues/0148-scratch-dir-leak-recurrence.md.
    scratch = os.path.join(repo, "tests", "headless", ".scratch",
                           "_ase_mig_verify_%d" % os.getpid())
    os.makedirs(scratch, exist_ok=True)
    script = _VERIFY_TCL
    for tok, val in (("@@REPO@@", repo), ("@@MODELSDIR@@", models_dir),
                     ("@@LIBNAME@@", libname), ("@@CELL@@", cellname),
                     ("@@BEFORE@@", before_sch),
                     ("@@AFTERROOT@@", os.path.abspath(after_root)),
                     ("@@SCRATCH@@", os.path.abspath(scratch)),
                     ("@@MODELVAR@@", pdk.model_var)):
        script = script.replace(tok, val)
    _write(drv, script)
    try:
        p = subprocess.run(
            [xschem, "--nogui", "--pipe", "-q", "--nolog", "--script", drv],
            capture_output=True, text=True, cwd=repo, timeout=180)
    finally:
        try:
            os.remove(drv)
        except OSError:
            pass
        shutil.rmtree(scratch, ignore_errors=True)
    idb = ida = None
    for ln in p.stdout.splitlines():
        parts = ln.split(None, 1)
        val = parts[1].strip() if len(parts) > 1 else ""
        if ln.startswith("ID_BEFORE"):
            idb = val or None
        elif ln.startswith("ID_AFTER"):
            ida = val or None
    ok = None
    if idb and ida:
        try:
            ok = abs(float(idb) - float(ida)) * 1e6 < 1.0
        except ValueError:
            ok = False
    return idb, ida, ok


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _guess_lib_cell(sch_path):
    """From <.../<lib>/<cell>/schematic/<cell>.sch> recover (lib, cell)."""
    parts = os.path.normpath(sch_path).split(os.sep)
    cell = os.path.splitext(parts[-1])[0]
    lib = parts[-4] if len(parts) >= 4 else "mylib"
    return lib, cell


def _report_define(out_root, libname):
    """Tell the operator the one registry line the migration cannot write itself.

    A Cadence-style workarea rc sets `library_registry_defs_only 1`, so
    library_registry (src/library_defs.tcl) ignores the library.tag we just
    wrote and takes ONLY the DEFINEs in the workarea's library.defs. Until that
    line exists, `xschem cellview_path <libname>/<cell> schematic` returns "" and
    every migrated state's `design {lib <libname> …}` is unresolvable — i.e. the
    exact symptom the destination-library naming was meant to cure."""
    defs = os.path.join(os.path.dirname(os.path.normpath(out_root) or "."),
                        "library.defs")
    line = "DEFINE %s %s" % (libname, os.path.basename(os.path.normpath(out_root)))
    if os.path.isfile(defs):
        try:
            if any(l.split()[:2] == ["DEFINE", libname]
                   for l in _read(defs).splitlines() if l.split()):
                return
        except OSError:
            pass
        print("  REGISTER: add `%s` to %s" % (line, defs))
    else:
        print("  REGISTER: add `%s` to your workarea's library.defs" % line)


# $::<model_var> points at the dir that CONTAINS the corner .lib; the in-repo
# workareas differ in where that dir lives. Every PDKS key must have an entry, or
# adding a profile turns --verify into a KeyError traceback instead of an honest
# message — _models_dir checks that.
_DEFAULT_MODELS = {
    "gf180": ("gf180mcuD", "models"),
    "sky130": ("sky130A", "models", "libs.tech", "combined"),
    "sg13g2": ("ihp-sg13g2", "models"),
}


def _models_dir(repo, pdkname, override):
    if override:
        return override
    if pdkname not in _DEFAULT_MODELS:
        return None
    return os.path.join(repo, *_DEFAULT_MODELS[pdkname])


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="De-clutter a testbench schematic into the ASE-L clean form.")
    ap.add_argument("--pdk", required=True, choices=sorted(PDKS),
                    help="technology profile")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--sch", help="a single cluttered <cell>.sch to migrate")
    src.add_argument("--library", help="a lib/cell/view library root; migrate every testbench cell")
    ap.add_argument("--out", help="destination LIBRARY-ROOT directory (both modes); "
                                  "the cell is written under DIR/<cell>/")
    ap.add_argument("--lib", help="library name for the state design= "
                                  "(default: the DESTINATION library's name)")
    ap.add_argument("--hoist-sources", action="store_true",
                    help="lift numeric vsource values into named design variables (heuristic)")
    ap.add_argument("--declare-var", action="append", default=[], metavar="NAME",
                    help="an extra Tcl global your workarea rc sets, so a path "
                         "naming it is not treated as unresolvable; repeatable")
    ap.add_argument("--dry-run", action="store_true", help="report only; write nothing")
    ap.add_argument("--verify", action="store_true",
                    help="run before/after through xschem+ngspice and compare Id")
    ap.add_argument("--xschem", default="./src/xschem", help="xschem binary for --verify")
    ap.add_argument("--models-dir", help="absolute models dir for --verify ($::<var>)")
    args = ap.parse_args(argv)
    pdk = PDKS[args.pdk]
    if args.declare_var:
        # the migrator cannot introspect a workarea rc, so an operator with a
        # non-stock one says what it sets rather than being blocked by the
        # unresolvable-path drop
        pdk.env_vars = pdk.env_vars | frozenset(args.declare_var)

    if args.library:
        lm = LibraryMigrator(args.library, pdk, libname=args.lib,
                             hoist_sources=args.hoist_sources).scan()
        out_root = args.out or (args.library.rstrip("/") + "_ase")
        results = lm.migrate_all(out_root, dry_run=args.dry_run)
        print("%s: %d testbench cell(s) -> %s" % (
            "DRY-RUN" if args.dry_run else "migrated", len(results), out_root))
        for cell, rep in results:
            print("  %s: %s" % (cell, rep.as_text().replace("\n", "; ")))
        if lm.skipped:
            print("  skipped %d: %s" % (len(lm.skipped),
                  ", ".join("%s(%s)" % s for s in lm.skipped[:8])))
        if not args.dry_run and results:
            print("  wrote %s" % os.path.join(out_root, "library.tag"))
            _report_define(out_root, lm.libname)
        rc = 0
        if lm.failed:
            print("  FAILED %d cell(s):" % len(lm.failed))
            for cell, err in lm.failed:
                print("    %s: %s" % (cell, err))
            rc = 1
        # --verify used to be ACCEPTED AND IGNORED here: the --library branch
        # returned before the verify block below, so a whole-library run with
        # --verify printed a clean report and proved nothing (issue 0210
        # `library-verify-silently-ignored`).
        if args.verify:
            if args.dry_run:
                print("  verify: --dry-run wrote no tree to verify")
                return 1
            repo = os.getcwd()
            models_dir = _models_dir(repo, args.pdk, args.models_dir)
            if not models_dir:
                print("  verify: no default models dir for pdk %s — pass "
                      "--models-dir" % args.pdk)
                return 1
            nok = nbad = nskip = 0
            for cell, _rep in results:
                before = os.path.join(args.library, cell, "schematic",
                                      cell + ".sch")
                idb, ida, ok = verify(repo, pdk, lm.libname, cell,
                                      os.path.abspath(before), out_root,
                                      models_dir, xschem=args.xschem)
                tag = "OK" if ok else ("MISMATCH" if ok is False else "skipped")
                print("  verify %s: Id_before=%s Id_after=%s -> %s"
                      % (cell, idb, ida, tag))
                nok, nbad, nskip = (nok + (ok is True), nbad + (ok is False),
                                    nskip + (ok is None))
            print("  verify: %d ok, %d mismatch, %d skipped"
                  % (nok, nbad, nskip))
            if nbad:
                rc = 1
        return rc

    srclib, cell = _guess_lib_cell(args.sch)
    # --out is a LIBRARY-ROOT directory (consistent with --library): the cell is
    # written under out_root/<cell>/{schematic,ngspice_state1}, so a registry
    # DEFINE <lib> out_root resolves <lib>/<cell> for Launch-ASE-L and --verify.
    out_root = args.out or (os.path.dirname(os.path.dirname(
        os.path.dirname(os.path.abspath(args.sch)))) + "_ase")
    # the state's design= names the DESTINATION library (see LibraryMigrator):
    # ASE resolves lib/cell/view from the registry, and the source name would
    # point Session > Design Window back at the cluttered cell.
    lib = args.lib or os.path.basename(os.path.normpath(out_root))
    # single-cell mode rebinds only THIS cell's self-reference: any sibling it
    # instantiates is not being migrated here, so it must keep naming srclib.
    sym_path = os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(args.sch))), "symbol", cell + ".sym")
    cm = CellMigrator(_read(args.sch), pdk, lib, cell,
                      hoist_sources=args.hoist_sources,
                      srclib=srclib, migrated_cells=(cell,),
                      srcdir=os.path.dirname(os.path.abspath(args.sch)),
                      sym_text=_read(sym_path) if os.path.isfile(sym_path) else None
                      ).migrate()
    out_cellroot = os.path.join(out_root, cell)
    sch, stt = cm.write(out_cellroot, dry_run=args.dry_run)
    print("%s %s/%s" % ("DRY-RUN" if args.dry_run else "migrated", lib, cell))
    print(cm.report.as_text())
    if not args.dry_run:
        print("  wrote %s" % sch)
        print("  wrote %s" % stt)
    if args.verify:
        repo = os.getcwd()
        models_dir = _models_dir(repo, args.pdk, args.models_dir)
        if not models_dir:
            print("  verify: no default models dir for pdk %s — pass --models-dir"
                  % args.pdk)
            return 1
        idb, ida, ok = verify(repo, pdk, lib, cell, os.path.abspath(args.sch),
                               out_root, models_dir, xschem=args.xschem)
        print("  verify: Id_before=%s Id_after=%s -> %s" % (
            idb, ida, "OK" if ok else ("MISMATCH" if ok is False else "skipped")))
        if ok is False:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
