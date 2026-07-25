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
# list string) is wrapped once more by [list ...], which brace-quotes it if it
# contains whitespace or any of {}[]$;"\ — empirically verified against tclsh.

_QUOTE_CHARS = set(' \t\n\r\v\f{}[]$;"\\')


def _tcl_conv(s):
    """Tcl_ConvertElement for the string `s`: return it brace-wrapped iff it needs
    quoting, bare otherwise. Backslash/unbalanced-brace values fall outside our
    data domain and raise (the caller can then fall back to xschem canonicalize)."""
    if s == "":
        return "{}"
    if not any(c in _QUOTE_CHARS for c in s):
        return s
    if "\\" in s or s.count("{") != s.count("}"):
        raise MigrationError("value needs backslash quoting (out of domain): %r" % s)
    return "{" + s + "}"


def _struct_to_str(x):
    """Canonical Tcl-list string of a nested (str | list) structure."""
    if isinstance(x, (list, tuple)):
        return " ".join(_tcl_conv(_struct_to_str(e)) for e in x)
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
               "save_all_i", "options", "includes", "viewer"]


# --------------------------------------------------------------------------- #
# PDK profiles — the per-technology knowledge the migrator needs
# --------------------------------------------------------------------------- #

class Pdk(object):
    """Per-technology profile: the model-path variable, and how a `corner`
    symbol's corner= value maps to a `.lib file section` model entry."""

    def __init__(self, name, model_var, corner_lib=None, corner_default=None):
        self.name = name
        self.model_var = model_var                # e.g. '180MCU_MODELS' (no $::)
        self.corner_lib = corner_lib              # portable .lib path for corner sym
        self.corner_default = corner_default      # fallback section if corner= absent

    def corner_model(self, corner_value):
        """(file, section) model entry for a `corner` symbol, or None if this PDK
        drives models a different way (gf180 uses a code_shown block instead)."""
        if not self.corner_lib:
            return None
        sec = corner_value or self.corner_default
        return (self.corner_lib, sec)


PDKS = {
    "sky130": Pdk("sky130", "SKYWATER_MODELS",
                  corner_lib="$::SKYWATER_MODELS/sky130.lib.spice",
                  corner_default="tt"),
    # gf180 embeds `.include design.ngspice` + `.lib sm141064 typical` in a
    # code_shown block already in portable $::180MCU_MODELS form, so there is no
    # corner symbol to map — models/includes are parsed straight from the block.
    "gf180": Pdk("gf180", "180MCU_MODELS"),
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
        self.raw_control = []  # unmappable .control lines (preserved in report)
        self.warnings = []

    def _add_output(self, expr, plot):
        # `all` is the ngspice save-everything token, not a probe expression ->
        # it maps to ASE's blanket save_all_v flag, not a named output.
        if expr.lower() in ("all", "v(all)"):
            self.save_all_v = True
        else:
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
        """Parse an embedded SPICE blob (top level + any .control block)."""
        in_control = False
        for raw in text.splitlines():
            line = raw.strip()
            if not line or line.startswith("*"):
                continue
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

    # -- top-level dot-cards --------------------------------------------------
    def _parse_top_line(self, line):
        low = line.lower()
        if low.startswith(".lib"):
            toks = line.split()
            if len(toks) >= 3:
                self.models.append((toks[1], toks[2]))
            elif len(toks) == 2:
                self.includes.append(toks[1])      # `.lib file` (whole-file) ~ include
            return
        if low.startswith(".include") or low.startswith(".inc "):
            toks = line.split(None, 1)
            if len(toks) == 2:
                self.includes.append(toks[1].strip())
            return
        if low.startswith(".param"):
            self._parse_params(line[len(".param"):])
            return
        if low.startswith(".option"):        # .option or .options
            self._parse_options(line.split(None, 1)[1] if len(line.split()) > 1 else "")
            return
        if low.startswith(".save") or low.startswith(".probe"):
            for e in line.split()[1:]:
                self._add_output(e, 0)
            return
        if low.startswith(".temp"):
            toks = line.split()
            if len(toks) >= 2:
                self.temperature = toks[1]
            return
        if low.startswith((".op", ".dc", ".ac", ".tran")):
            self._parse_analysis(line.lstrip("."))
            return
        if low.startswith((".end", ".title", ".global", ".model", ".subckt",
                           ".ends", ".ic", ".nodeset")):
            return                                # structural / handled elsewhere
        if line.startswith("."):
            self.warnings.append("unmapped top-level card: %s" % line)

    # -- inside .control ------------------------------------------------------
    def _parse_control_line(self, line):
        head = line.split()[0].lower()
        if head in _MAPPABLE_CONTROL:
            self._parse_analysis(line)
            return
        if head in ("save", "print"):
            for e in line.split()[1:]:
                self._add_output(e, 0)
            return
        if head == "plot":
            for e in line.split()[1:]:
                self._add_output(e, 1)
            return
        if head in ("option", "options"):
            self._parse_options(line.split(None, 1)[1] if len(line.split()) > 1 else "")
            return
        if head in _DROP_CONTROL:
            return
        if head in _KEEP_CONTROL:
            self.raw_control.append(line)
            self.warnings.append("unmappable .control command preserved: %s" % line)
            return
        self.raw_control.append(line)
        self.warnings.append("unrecognized .control command preserved: %s" % line)

    # -- shared bits ----------------------------------------------------------
    def _parse_analysis(self, body):
        toks = body.split()
        t = toks[0].lower()
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
        # `.param a=1 b = 2` -> normalize spaces around '=' then split on ws
        rest = re.sub(r"\s*=\s*", "=", rest.strip())
        for tok in rest.split():
            if "=" in tok:
                name, val = tok.split("=", 1)
                self.params.append((name, val))

    def _parse_options(self, rest):
        rest = re.sub(r"\s*=\s*", "=", rest.strip())
        for tok in rest.split():
            if "=" in tok:
                name, val = tok.split("=", 1)
                self.options.append((name, val))
            elif tok:
                self.options.append((tok, None))


# --------------------------------------------------------------------------- #
# graph blocks (B <layer> ... {flags=graph ... node=...}) -> plotted outputs
# --------------------------------------------------------------------------- #

def graph_outputs(props):
    """Plotted expressions recovered from a graph B-record's props: each entry in
    the `node` token becomes an output (plot=1). node is a ws/;/newline list."""
    found, node = get_tok(props, "node")
    if not found or not node:
        return []
    exprs = [e for e in re.split(r"[\s;]+", node.strip()) if e]
    return [(e, 1) for e in exprs]


# --------------------------------------------------------------------------- #
# classification
# --------------------------------------------------------------------------- #

_DROP_CELLS = frozenset(("launcher",))
_EMBED_CELLS = frozenset((
    "code_shown", "code", "spice_code_shown", "netlist_commands",
    "simulator_commands", "simulator_commands_shown", "spice", "ngspice"))


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


class MigrationReport(object):
    def __init__(self):
        self.kept = 0
        self.dropped = []          # (category, detail)
        self.extracted = {}        # field -> count
        self.warnings = []
        self.hoisted = []          # (instance, var, value)

    def as_text(self):
        out = ["kept %d record(s)" % self.kept]
        if self.extracted:
            out.append("extracted: " + ", ".join(
                "%s=%d" % (k, v) for k, v in sorted(self.extracted.items())))
        if self.hoisted:
            out.append("hoisted sources: " + ", ".join(
                "%s->%s(%s)" % h for h in self.hoisted))
        if self.dropped:
            out.append("dropped: " + ", ".join(d[0] for d in self.dropped))
        for w in self.warnings:
            out.append("WARN: " + w)
        return "\n".join(out)


class CellMigrator(object):
    """Migrate one cluttered testbench schematic to (clean_sch, state)."""

    def __init__(self, sch_text, pdk, libname, cellname, hoist_sources=False):
        self.sch_text = sch_text
        self.pdk = pdk
        self.libname = libname
        self.cellname = cellname
        self.hoist_sources = hoist_sources
        self.report = MigrationReport()
        self.clean_sch = None
        self.state = None

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
            elif cat == "corner":
                _f, cv = get_tok(rec.fields[5].content, "corner")
                deck.add_corner(self.pdk, cv)
                self.report.dropped.append(("corner", cv))
            elif cat == "embedded":
                _f, val = get_tok(rec.fields[5].content, "value")
                if val:
                    deck.parse(val)
                self.report.dropped.append(("embedded", _cell_of(rec.fields[0].content)))
            elif cat == "graph":
                g_outputs.extend(graph_outputs(rec.fields[5].content))
                self.report.dropped.append(("graph", None))
            elif cat == "drop":
                self.report.dropped.append(("drop", _cell_of(rec.fields[0].content)))
        self.report.warnings.extend(deck.warnings)

        kept = self._maybe_hoist(kept, deck)
        self.clean_sch = self._reconstruct(kept)
        self.state = self._build_state(deck, g_outputs)
        return self

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
        return "\n".join(parts) + "\n"

    # -- state assembly -------------------------------------------------------
    def _build_state(self, deck, g_outputs):
        st = {
            "version": "1",
            "simulator": "ngspice",
            "design": ["lib", self.libname, "cell", self.cellname,
                       "view", "schematic"],
            "rundir": "",
            "temperature": deck.temperature or "27",
            "models": [["file", f, "section", s] for (f, s) in _dedup(deck.models)],
            "variables": [["name", n, "value", v] for (n, v) in deck.params],
            "analyses": self._analyses(deck),
            "outputs": self._outputs(deck, g_outputs),
            "save_all_v": "1" if deck.save_all_v else "0",
            "save_all_i": "0",
            "options": [self._option_entry(n, v) for (n, v) in deck.options],
            "includes": [["file", f] for f in _dedup(deck.includes)],
            "viewer": "",
        }
        for f in ("models", "variables", "outputs", "options", "includes"):
            if st[f]:
                self.report.extracted[f] = len(st[f])
        return st

    @staticmethod
    def _option_entry(name, val):
        if val is None:
            return ["name", name, "value", "1"]
        return ["name", name, "value", val]

    def _analyses(self, deck):
        # canonical 4 entries, in fixed order; enabled ones carry their params.
        # if nothing was extracted, default op enabled (matches state_default).
        found = dict(deck.analyses)
        if not found:
            found["op"] = {"type": "op", "enabled": "1"}
        order = ["op", "dc", "ac", "tran"]
        out = []
        for t in order:
            if t in found:
                d = found[t]
                out.append(_dict_to_list(d, ["type", "enabled", "source",
                                             "start", "stop", "step", "points"]))
            else:
                out.append(["type", t, "enabled", "0"])
        return out

    def _outputs(self, deck, g_outputs):
        seen = {}
        order = []
        for expr, plot in list(deck.outputs) + list(g_outputs):
            if expr in seen:
                if plot:                        # a plotted node upgrades plot flag
                    seen[expr]["plot"] = "1"
                continue
            seen[expr] = {"expr": expr, "plot": "1" if plot else "0"}
            order.append(expr)
        out = []
        for i, expr in enumerate(order, 1):
            e = seen[expr]
            name = _mk_name(expr, i)
            out.append(["name", name, "expr", e["expr"], "save", "1",
                        "plot", e["plot"]])
        return out

    # -- output files ---------------------------------------------------------
    def write(self, out_cellroot, dry_run=False):
        sch = os.path.join(out_cellroot, "schematic", self.cellname + ".sch")
        stt = os.path.join(out_cellroot, "ngspice_state1",
                           self.cellname + ".state")
        if not dry_run:
            _write(sch, self.clean_sch)
            _write(stt, serialize_state(self.state, SCHEMA_KEYS))
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


def _mk_name(expr, i):
    base = re.sub(r"[^A-Za-z0-9]", "", expr)
    return base if base else ("o%d" % i)


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
        self.libname = libname or os.path.basename(os.path.normpath(libroot))
        self.hoist_sources = hoist_sources
        self.cells = []          # [(cellname, CellMigrator), ...]
        self.skipped = []        # [(cellname, reason), ...]

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
                self.skipped.append((cell, "no clutter to extract"))
                continue
            self.cells.append((cell, CellMigrator(text, self.pdk, self.libname,
                                                  cell, self.hoist_sources)))
        return self

    def migrate_all(self, out_root, dry_run=False):
        results = []
        for cell, cm in self.cells:
            cm.migrate()
            cm.write(os.path.join(out_root, cell), dry_run=dry_run)
            results.append((cell, cm.report))
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
foreach d [list gf180mcu_pr sky130_fd_pr] {
  foreach base [list [file join $repo gf180mcuD xschem_libs $d] \
                     [file join $repo sky130A xschem_libs $d]] {
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


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="De-clutter a testbench schematic into the ASE-L clean form.")
    ap.add_argument("--pdk", required=True, choices=sorted(PDKS),
                    help="technology profile")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--sch", help="a single cluttered <cell>.sch to migrate")
    src.add_argument("--library", help="a lib/cell/view library root; migrate every testbench cell")
    ap.add_argument("--out", help="destination root (a cell root for --sch, a lib root for --library)")
    ap.add_argument("--lib", help="library name for the state design= (default: inferred)")
    ap.add_argument("--hoist-sources", action="store_true",
                    help="lift numeric vsource values into named design variables (heuristic)")
    ap.add_argument("--dry-run", action="store_true", help="report only; write nothing")
    ap.add_argument("--verify", action="store_true",
                    help="run before/after through xschem+ngspice and compare Id")
    ap.add_argument("--xschem", default="./src/xschem", help="xschem binary for --verify")
    ap.add_argument("--models-dir", help="absolute models dir for --verify ($::<var>)")
    args = ap.parse_args(argv)
    pdk = PDKS[args.pdk]

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
        return 0

    lib, cell = _guess_lib_cell(args.sch)
    lib = args.lib or lib
    cm = CellMigrator(_read(args.sch), pdk, lib, cell,
                      hoist_sources=args.hoist_sources).migrate()
    # --out is a LIBRARY-ROOT directory (consistent with --library): the cell is
    # written under out_root/<cell>/{schematic,ngspice_state1}, so a registry
    # DEFINE <lib> out_root resolves <lib>/<cell> for Launch-ASE-L and --verify.
    out_root = args.out or (os.path.dirname(os.path.dirname(
        os.path.dirname(os.path.abspath(args.sch)))) + "_ase")
    out_cellroot = os.path.join(out_root, cell)
    sch, stt = cm.write(out_cellroot, dry_run=args.dry_run)
    print("%s %s/%s" % ("DRY-RUN" if args.dry_run else "migrated", lib, cell))
    print(cm.report.as_text())
    if not args.dry_run:
        print("  wrote %s" % sch)
        print("  wrote %s" % stt)
    if args.verify:
        repo = os.getcwd()
        # $::<model_var> points at the dir that CONTAINS the corner .lib; the two
        # in-repo workareas differ in where that dir lives.
        default_models = {
            "gf180": os.path.join(repo, "gf180mcuD", "models"),
            "sky130": os.path.join(repo, "sky130A", "models", "libs.tech", "combined"),
        }
        models_dir = args.models_dir or default_models[args.pdk]
        idb, ida, ok = verify(repo, pdk, lib, cell, os.path.abspath(args.sch),
                               out_root, models_dir, xschem=args.xschem)
        print("  verify: Id_before=%s Id_after=%s -> %s" % (
            idb, ida, "OK" if ok else ("MISMATCH" if ok is False else "skipped")))
        if ok is False:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
