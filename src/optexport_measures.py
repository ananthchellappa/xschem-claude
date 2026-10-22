#!/usr/bin/env python3
"""measures.py -- written by ASE-L Tools > Export for Optimizer (FAQ Q92).

Gives an external optimizer the ASE-L Outputs and Measurements values of one
ngspice run, as ONE dict name -> value, without xschem in the loop:

  * ngspice-native Outputs > Measurements rows are read from the .meas file
    the deck writes, by the rule ASE-L itself uses (ase::meas_parse);
  * every Outputs-pane row is computed by xschem itself, headless
    (xschem --nogui --pipe -q --nolog --script measures.tcl), by the SAME procs
    that fill the ASE-L Outputs pane -- so the numbers match it by construction,
    at full precision.

A wave, a refusal or a missing value is NEVER a number: it is a NonNumeric,
which float() and arithmetic refuse.

Per evaluation:
    deck = prepare_rundir(run, {"rr": 500.0})     # deck + .spiceinit, stale results gone
    subprocess.run(ngspice_command(run), cwd=run, check=True)
    vals = measures(run)                          # {name: float | NonNumeric}

CLI:
    python3 measures.py [--rundir DIR] [--json] [--log FILE]
    python3 measures.py --prepare DIR [--set NAME=VALUE ...]
    python3 measures.py --command [--rundir DIR]
Exit: 0 every measure is a number, 1 some are not, 2 the harness failed.

Python 3.8+, standard library only. See README.txt and manifest.json.
"""

import collections
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST_PROTOCOL = "asexp-manifest/1"
RESULTS_PROTOCOL = "asexp-results/1"
PREDECK_MARKER = "* ASE-L pre-deck settings -- rewritten every run, deleted every run"

__all__ = ["NonNumeric", "MeasuresError", "StaleResults", "DeckMismatch",
           "manifest", "measures", "measures_detail", "parse_meas", "write_deck",
           "prepare_rundir", "ngspice_command", "run", "Result"]


class MeasuresError(Exception):
    """A harness failure: xschem did not launch, crashed, timed out, or wrote
    a missing, partial or malformed results file. Never an empty result."""


class StaleResults(MeasuresError):
    """The results in the run directory are older than its deck: ngspice did
    not (re)write them, so reading them would report an earlier run."""


class DeckMismatch(ValueError):
    """The deck line a design variable lives on is not the exported line."""


class NonNumeric:
    """A measure that has no number. Never a float: float(x) and arithmetic
    raise TypeError, and it is falsy.

    status: wave | refused | novalue | nonnumeric | failed | produced | fatal
    """
    __slots__ = ("status", "msg")

    def __init__(self, status, msg=""):
        self.status = status
        self.msg = msg

    def __bool__(self):
        return False

    def __eq__(self, other):
        return (isinstance(other, NonNumeric) and other.status == self.status
                and other.msg == self.msg)

    def __hash__(self):
        return hash((self.status, self.msg))

    def __repr__(self):
        return "NonNumeric(%r, %r)" % (self.status, self.msg)


Result = collections.namedtuple(
    "Result", ["values", "records", "datasets", "warnings", "results_json"])

_NUM = re.compile(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$|^[+-]?(inf|nan)$",
                  re.IGNORECASE)
# ase::meas_parse, transcribed: name = value [tail]; later lines win.
_MEAS_LINE = re.compile(r"^\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s+(\S+)\s*(.*)$", re.ASCII)


def _number(text):
    """float(text) when text is ONE number as Tcl's `string is double -strict`
    reads it, else None. The regex runs first: float() alone accepts '1_0'."""
    if isinstance(text, str) and _NUM.match(text.strip() if text else ""):
        try:
            return float(text)
        except ValueError:
            return None
    return None


def manifest(export_dir=HERE):
    """The export's manifest.json as a dict."""
    path = os.path.join(export_dir, "manifest.json")
    try:
        with open(path, encoding="utf-8") as f:
            m = json.load(f)
    except (OSError, ValueError) as e:
        raise MeasuresError("cannot read %s: %s" % (path, e))
    if m.get("protocol") != MANIFEST_PROTOCOL:
        raise MeasuresError("%s is not an %s manifest" % (path, MANIFEST_PROTOCOL))
    return m


def parse_meas(text):
    """name (lower case) -> (value, tail), by ase::meas_parse's rule."""
    out = {}
    for line in text.split("\n"):
        line = line.rstrip()
        if not line.strip():
            continue
        mo = _MEAS_LINE.match(line)
        if not mo:
            continue
        out[mo.group(1).lower()] = (mo.group(2), mo.group(3).strip())
    return out


def _value_text(v):
    if isinstance(v, bool):
        raise TypeError("a design variable value cannot be a bool")
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, str):
        if "\n" in v or "\r" in v:
            raise ValueError("a design variable value must be one line: %r" % v)
        return v
    raise TypeError("a design variable value must be int, float or str, not %s"
                    % type(v).__name__)


def write_deck(dest, overrides=None, *, base=None, export_dir=HERE):
    """Write the exported deck to `dest` with design-variable overrides
    {name: value}. Only the variables' own `.param` lines change; every other
    line is copied byte for byte. Returns dest."""
    m = manifest(export_dir)
    if base is None:
        base = os.path.join(export_dir, m["deck"])
    with open(base, "rb") as f:
        raw = f.read()
    lines = raw.split(b"\n")
    known = {v["name"]: v for v in m.get("variables", [])}
    for name, value in (overrides or {}).items():
        if name not in known:
            raise KeyError("no design variable %r; known: %s"
                           % (name, ", ".join(sorted(known)) or "(none)"))
        v = known[name]
        if v.get("deck_line") is None:
            raise KeyError("design variable %r has no deck line of its own, so it"
                           " cannot be overridden" % name)
        n = int(v["deck_line"])
        if n < 1 or n > len(lines) or lines[n - 1].decode("utf-8") != v["deck_text"]:
            raise DeckMismatch("line %d of %s is not %r: the deck was edited"
                               % (n, base, v["deck_text"]))
        lines[n - 1] = (".param %s=%s" % (name, _value_text(value))).encode("utf-8")
    d = os.path.dirname(os.path.abspath(dest)) or "."
    fd, tmp = tempfile.mkstemp(prefix=".deck.", dir=d)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(b"\n".join(lines))
        os.replace(tmp, dest)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return dest


def prepare_rundir(rundir, overrides=None, *, export_dir=HERE):
    """Make `rundir` ready for one ngspice run, exactly as ASE-L's Run does:
    delete the previous run's results (ngspice APPENDS to them otherwise),
    write the deck (with overrides) and the pre-deck file. Returns the deck path."""
    m = manifest(export_dir)
    os.makedirs(rundir, exist_ok=True)
    for name in m.get("delete_before_run", []):
        p = os.path.join(rundir, name)
        if name == ".spiceinit":
            if os.path.isfile(p):
                with open(p, encoding="utf-8", errors="replace") as f:
                    first = f.readline()
                if first.strip() == PREDECK_MARKER.strip():
                    os.unlink(p)
                else:
                    sys.stderr.write("measures.py: %s is not ASE-L's and is left"
                                     " in place\n" % p)
            continue
        try:
            os.unlink(p)
        except FileNotFoundError:
            pass
    deck = write_deck(os.path.join(rundir, m["deck"]), overrides,
                      export_dir=export_dir)
    pre = m.get("predeck_file")
    if pre:
        src = os.path.join(export_dir, pre)
        dst = os.path.join(rundir, pre)
        if os.path.abspath(src) != os.path.abspath(dst):
            shutil.copyfile(src, dst)
    return deck


def ngspice_command(rundir=".", *, export_dir=HERE):
    """The ngspice argv for this deck. Run it with cwd=rundir: the deck names
    its results with bare file names. ASEXP_NGSPICE overrides the binary."""
    m = manifest(export_dir)
    sim = m["simulator"]
    exe = os.environ.get("ASEXP_NGSPICE") or sim.get("resolved") or sim["exe"]
    return [exe] + list(sim.get("args", [])) + [m["deck"]]


def _xschem_results(m, rundir, log, timeout, export_dir, warnings):
    xs = os.environ.get("ASEXP_XSCHEM") or m["xschem"]
    script = os.path.join(export_dir, "measures.tcl")
    cmd = [xs, "--nogui", "--pipe", "-q", "--nolog", "--script", script]
    for attempt in (1, 2):
        env = dict(os.environ)
        for k in ("DISPLAY", "WAYLAND_DISPLAY"):
            env.pop(k, None)              # never a window on any screen
        home = tempfile.mkdtemp(prefix="asexp-home.")
        out = os.path.join(home, "results.json")
        env.update(HOME=home, ASEXP_RUNDIR=os.path.abspath(rundir),
                   ASEXP_OUT=out, ASEXP_LOG=os.path.abspath(log) if log else "")
        try:
            try:
                p = subprocess.run(cmd, env=env, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   timeout=timeout, cwd=home)
            except subprocess.TimeoutExpired:
                raise MeasuresError("xschem did not finish in %s s" % timeout)
            except OSError as e:
                raise MeasuresError("cannot run xschem %s: %s" % (xs, e))
            tail = p.stdout.decode("utf-8", "replace")[-2000:]
            if p.returncode in (-11, 139) and attempt == 1:
                # Issue 1706: same-second launches can crash. Retried ONCE, and said.
                warnings.append("xschem crashed once (signal 11) and was retried:"
                                " issue 1706")
                time.sleep(2.2)
                continue
            try:
                with open(out, encoding="utf-8") as f:
                    text = f.read()
            except OSError:
                raise MeasuresError("xschem wrote no results file (exit %s): %s"
                                    % (p.returncode, tail))
            try:
                res = json.loads(text)
            except ValueError as e:
                raise MeasuresError("xschem's results file is not JSON (%s): %s"
                                    % (e, text[-500:]))
            if not isinstance(res, dict) or res.get("protocol") != RESULTS_PROTOCOL:
                raise MeasuresError("xschem's results file is not %s" % RESULTS_PROTOCOL)
            if res.get("complete") != "true":
                raise MeasuresError("xschem's results file is incomplete")
            if "error" in res:
                raise MeasuresError("xschem failed: %s" % res["error"])
            if p.returncode != 0:
                raise MeasuresError("xschem exited %s: %s" % (p.returncode, tail))
            return res, text
        finally:
            shutil.rmtree(home, ignore_errors=True)
    raise MeasuresError("xschem crashed twice (signal 11): issue 1706")


def _meas_value(entry, verdict, why, val):
    """One Measurements row as float | NonNumeric, by ase::meas_results' rule."""
    if verdict in ("ok", "caution"):
        n = _number(val)
        return n if n is not None else NonNumeric("nonnumeric", val)
    return NonNumeric(verdict, why)


def _check_fresh(m, rundir):
    deck = os.path.join(rundir, m["deck"])
    if not os.path.isfile(deck):
        return
    dt = os.stat(deck).st_mtime
    want = []
    if any(x["source"] == "calc" for x in m["measures"]):
        want.append(m["artifacts"]["raw"])
    if any(x["source"] == "meas" for x in m["measures"]):
        want.append(m["artifacts"]["meas"])
    for name in want:
        p = os.path.join(rundir, name)
        if os.path.exists(p) and os.stat(p).st_mtime < dt:
            raise StaleResults("%s is older than the deck %s: ngspice did not"
                               " rewrite it; run prepare_rundir() before every run"
                               % (p, deck))


def measures_detail(rundir=".", *, log=None, timeout=120.0, check_fresh=True,
                    export_dir=HERE):
    """Like measures(), plus the per-row records, the dataset counts, the
    warnings and the raw results text (None when xschem was not needed)."""
    m = manifest(export_dir)
    rundir = os.path.abspath(rundir)
    warnings = []
    if check_fresh:
        _check_fresh(m, rundir)
    rawp = os.path.join(rundir, m["artifacts"]["raw"])
    measp = os.path.join(rundir, m["artifacts"]["meas"])
    if not os.path.exists(rawp) and not os.path.exists(measp):
        warnings.append("no results in %s: did ngspice run here?" % rundir)
    mtext = ""
    if os.path.isfile(measp):
        with open(measp, encoding="utf-8", errors="replace") as f:
            mtext = f.read()
    parsed = parse_meas(mtext)
    values, records, datasets, text = {}, [], {}, None
    calc = [x for x in m["measures"] if x["source"] == "calc"]
    meas = [x for x in m["measures"] if x["source"] == "meas"]
    if calc:
        res, text = _xschem_results(m, rundir, log, timeout, export_dir, warnings)
        datasets = res.get("datasets", {})
        outs = {}
        for r in res.get("outputs", []):
            outs[r["key"]] = r
        for x in calc:
            r = outs.get(x["name"])
            if r is None:
                values[x["name"]] = NonNumeric("novalue", "xschem returned no record")
                continue
            records.append(r)
            st = r.get("status")
            if st == "number":
                n = _number(r.get("value", ""))
                values[x["name"]] = n if n is not None else NonNumeric(
                    "nonnumeric", r.get("value", ""))
            elif st in ("wave", "refused", "novalue", "nonnumeric"):
                values[x["name"]] = NonNumeric(st, r.get("msg") or r.get("value", ""))
            else:
                values[x["name"]] = NonNumeric("nonnumeric", "unknown status %r" % st)
            an = r.get("analysis") or ""
            n = datasets.get(an)
            if an and n and n.isdigit() and int(n) > 1:
                warnings.append("%s: evaluated on dataset 0 of %s (%s); the Outputs"
                                " pane shows the same" % (x["name"], n, an))
        xm = {}
        for r in res.get("meas", []):
            xm[r["name"].lower()] = r
        for x in meas:
            r = xm.get(x["name"].lower())
            if r is None:
                values[x["name"]] = NonNumeric("novalue", "xschem returned no record")
                continue
            records.append(r)
            if r["verdict"] in ("ok", "caution"):
                mine = parsed.get(x["name"].lower(), ("", ""))[0]
                if mine != r["value"]:
                    raise MeasuresError("meas parse disagrees with ASE-L: %s %r vs %r"
                                        % (x["name"], mine, r["value"]))
                if r["verdict"] == "caution" and r.get("why"):
                    warnings.append("%s: %s" % (x["name"], r["why"]))
            values[x["name"]] = _meas_value(x, r["verdict"], r.get("why", ""),
                                            r.get("value", ""))
    else:
        for x in meas:
            v = x.get("verdict", "ok")
            k = x["name"].lower()
            rec = {"name": x["name"]}
            if v in ("refuse", "fatal"):
                rec.update(verdict="refused" if v == "refuse" else "fatal",
                           value="", why=x.get("why", ""))
            elif k not in parsed and x.get("yields") != "number":
                rec.update(verdict="produced", value="", why="")
            elif k not in parsed:
                rec.update(verdict="failed", value="",
                           why="the simulator did not report this measurement:"
                               " the condition it asks about may never occur in"
                               " this run")
            elif v == "caution":
                rec.update(verdict="caution", value=parsed[k][0], why=x.get("why", ""))
                if rec["why"]:
                    warnings.append("%s: %s" % (x["name"], rec["why"]))
            else:
                rec.update(verdict="ok", value=parsed[k][0], why="")
            records.append(rec)
            values[x["name"]] = _meas_value(x, rec["verdict"], rec["why"], rec["value"])
    ordered = {x["name"]: values[x["name"]] for x in m["measures"]}
    return Result(ordered, records, datasets, warnings, text)


def measures(rundir=".", *, log=None, timeout=120.0, check_fresh=True,
             export_dir=HERE):
    """{name: float | NonNumeric}, one key per exported measure, in manifest order."""
    return measures_detail(rundir, log=log, timeout=timeout,
                           check_fresh=check_fresh, export_dir=export_dir).values


def run(rundir, overrides=None, *, timeout=None, export_dir=HERE):
    """Convenience: prepare_rundir + ngspice + measures. Returns the dict."""
    prepare_rundir(rundir, overrides, export_dir=export_dir)
    logp = os.path.join(rundir, "ngspice.log")
    with open(logp, "wb") as lf:
        subprocess.run(ngspice_command(rundir, export_dir=export_dir), cwd=rundir,
                       stdin=subprocess.DEVNULL, stdout=lf, stderr=subprocess.STDOUT,
                       timeout=timeout)
    return measures(rundir, log=logp, export_dir=export_dir)


def _main(argv):
    import argparse
    ap = argparse.ArgumentParser(prog="measures.py", description=(
        "ASE-L measures for one ngspice run (exit 0 all numbers, 1 some not,"
        " 2 harness failure)"))
    ap.add_argument("--rundir", default=".")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--log")
    ap.add_argument("--prepare", metavar="DIR")
    ap.add_argument("--set", action="append", default=[], metavar="NAME=VALUE")
    ap.add_argument("--command", action="store_true")
    ap.add_argument("--timeout", type=float, default=120.0)
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    try:
        if a.prepare:
            ov = {}
            for s in a.set:
                if "=" not in s:
                    raise ValueError("--set wants NAME=VALUE, not %r" % s)
                k, v = s.split("=", 1)
                ov[k] = v
            print(prepare_rundir(a.prepare, ov))
            return 0
        if a.set:
            raise ValueError("--set goes with --prepare")
        if a.command:
            for w in ngspice_command(a.rundir):
                print(w)
            return 0
        r = measures_detail(a.rundir, log=a.log, timeout=a.timeout)
    except (MeasuresError, KeyError, ValueError, TypeError, OSError) as e:
        sys.stderr.write("measures.py: %s: %s\n" % (type(e).__name__, e))
        return 2
    for w in r.warnings:
        sys.stderr.write("measures.py: warning: %s\n" % w)
    allnum = all(not isinstance(v, NonNumeric) for v in r.values.values())
    if a.json:
        obj = {}
        for k, v in r.values.items():
            if isinstance(v, NonNumeric):
                obj[k] = {"status": v.status, "msg": v.msg}
            elif v != v or v in (float("inf"), float("-inf")):
                obj[k] = {"status": "number", "text": repr(v)}
            else:
                obj[k] = v
        sys.stdout.write(json.dumps(obj, allow_nan=False, indent=1) + "\n")
    else:
        for k, v in r.values.items():
            if isinstance(v, NonNumeric):
                sys.stdout.write("%s\t!%s\t%s\n" % (k, v.status, v.msg))
            else:
                sys.stdout.write("%s\t%r\n" % (k, v))
    return 0 if allnum else 1


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
