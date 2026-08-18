#!/usr/bin/env python3
"""item-15 citation checker: every file:line this item's docs assert, re-read
from the tree.  Prints ok:/FAIL: per row and exits 1 on any FAIL."""
import io,re,sys,os
ROOT="/home/qflow/dev/xschem/claude_1/xschem"
# (file, line, regex that must match that line, why)
CITES=[
 ("src/save.c",1065,r"NAMES ARE STORED VERBATIM","the deleted fold's site"),
 ("src/save.c",3205,r"raw_fold_key","fold key helper"),
 ("src/save.c",3215,r"raw_build_fold_table","lazy alias index builder"),
 ("src/save.c",3334,r"int get_raw_index_in\(","ask a named database"),
 ("src/save.c",3378,r"int get_raw_index\(","the ladder entry point"),
 ("src/save.c",2136,r"The one place a mode token becomes","raw_case_mode_parse block"),
 ("src/save.c",2155,r"IS A LAZY VIEW","the lazy ngspice_data view"),
 ("src/save.c",2532,r"raw_case_mode.md section 10","four-source resolution"),
 ("src/save.c",2932,r"int netlist_case_mode\(","the netlister's mode"),
 ("src/vcd_read.c",139,r"NAMES ARE STORED VERBATIM","VCD verbatim, now the rule"),
 ("src/xschem.h",1192,r"int case_sensitive;","the boolean flag"),
 ("src/scheduler.c",10095,r"raw_case_reread","a set re-reads"),
 ("src/scheduler.c",10363,r'"-case"',"raw read -case"),
 ("src/scheduler.c",10456,r'"casemode"',"raw casemode verb"),
 ("src/scheduler.c",10703,r'"case"',"raw case verb"),
 ("src/hilight.c",362,r"hilight_sender_case_mode","sender gate"),
 ("src/hilight.c",421,r"sender_current_prefix","prefix follows the token"),
 ("src/wave_viewer.tcl",2629,r"proc wviewer::name_rungs","the Tcl mirror"),
 ("src/wave_viewer.tcl",2651,r"proc wviewer::fold_key","ASCII-only fold key"),
 ("src/wave_viewer.tcl",2664,r"proc wviewer::name_index","per-slot index"),
 ("src/wave_viewer.tcl",2689,r"proc wviewer::name_lookup","the mirror's lookup"),
 ("src/wave_viewer.tcl",2748,r"proc wviewer::resolve_signal_db","slot resolution"),
 ("src/wave_viewer.tcl",3676,r"proc wviewer::validate_rpn","the RPN gate"),
 ("src/wave_viewer.tcl",14447,r"proc wviewer::casemode_refresh","Case Mode readout"),
 ("src/wave_viewer.tcl",14574,r"proc wviewer::set_case_mode","Case Mode override"),
 ("src/wave_viewer.tcl",2932,r"proc wviewer::repair_currents","post-load repair"),
 ("src/xschem.tcl",2774,r"proc sim_profile_set","profile field setter"),
 ("src/xschem.tcl",3309,r"proc sim_probe_once","one probe invocation"),
 ("src/xschem.tcl",3503,r"proc sim_profile_probe_capability","the capability probe"),
 ("src/xschem.tcl",5936,r"differ only in case","the relay parse"),
 ("src/xschem.tcl",3751,r"proc ngspice::lookup","the ONE gated fallback (13.7b)"),
 ("src/ngspice_backannotate.tcl",39,r"string tolower","the third publisher folds its own keys"),
 ("src/ase.tcl",174,r"proc ase::expand_path","issue 0422's site"),
 ("src/ase.tcl",606,r"proc ase::sim_probe_run","the run probe"),
 ("src/ase.tcl",990,r"proc ase::run_mode_advice","issue 0424's site"),
 ("src/ase.tcl",1511,r"proc ase::preflight_fix_session","D1's explicit apply"),
 ("src/ase.tcl",1572,r"proc ase::preflight_gate","defence (a)"),
 ("src/ase.tcl",4532,r"proc render_deck","the deck shape"),
 ("src/ase.tcl",4707,r"proc run_cmd","the profile-aware run"),
 ("src/ase.tcl",4864,r"proc result_probe","reading the log back"),
 ("src/ase_window.tcl",961,r"proc ase::ui::sod_expr \{kind token mode\}","mode is REQUIRED"),
 ("src/ase_window.tcl",1100,r"proc ase::ui::sod_qualify","hierarchical name"),
 ("src/ase_window.tcl",2224,r"proc ase::ui::repair_currents","repair caller"),
 ("src/node_hash.c",313,r"int netlist_case_collision_check\(","the C2 check"),
 ("src/spice_netlist.c",206,r"keep_model_case","model dedup key gate"),
 ("src/spice_netlist.c",221,r"netlist_case_collision_check\(\)","called per level"),
 ("src/spectre_netlist.c",74,r"keep_model_case","same gate, spectre"),
]
# ---------------------------------------------------------------------------
# PROSE CLAIMS.  Four numbers/statements the fix round found WRONG in the docs
# (a suite-growth count, a crew count, "untracked", "deleted, not ported").
# Each is now derived from the tree, not copied, so it cannot rot in silence.
WORDS={4:"four",7:"seven",8:"eight",10:"ten",13:"thirteen",14:"fourteen",15:"fifteen"}
BASE="577ef5bc"
def _sh(*a):
    import subprocess
    return subprocess.run(a,cwd=ROOT,capture_output=True,text=True).stdout

def claim_suite_growth():
    """Part 3 3.1's suite-growth number == what git says the batch added."""
    out=_sh("git","log","--diff-filter=A","--name-only","--pretty=format:",
            BASE+"..HEAD","--","tests/headless/test_*.tcl")
    added=sorted(set(l for l in out.split("\n") if l.strip()))
    doc=io.open(os.path.join(ROOT,"doc/claude/code_analysis/"
                "ngspice_case_sensitivity.md"),encoding="utf-8").read()
    m=re.search(r"the only growth is the \*\*(\w+)\*\* suites",doc)
    if not m: return "3.1's suite-growth sentence is gone or reworded"
    if m.group(1)!=WORDS.get(len(added)):
        return "3.1 says %r, git says %d (%s)"%(m.group(1),len(added),
                                                WORDS.get(len(added)))
    return None

def claim_crew_count():
    """simulator_profiles' reader map: 'N crews' == distinct items in its table."""
    p=os.path.join(ROOT,"doc/claude/specs/simulator_profiles.md")
    txt=io.open(p,encoding="utf-8").read()
    m=re.search(r"written one item at a time by (\w+) crews",txt)
    if not m: return "the reader map's crew sentence is gone or reworded"
    rows=re.findall(r"^> \|.*\|\s*§[^|]*\|\s*(\d+)\s*\|$",txt,re.M)
    items=set(int(r) for r in rows)
    if not items: return "the reader map table parsed to zero item numbers"
    if m.group(1)!=WORDS.get(len(items)):
        return "map says %r crews, its table lists %d distinct items %s"%(
            m.group(1),len(items),sorted(items))
    return None

def claim_guide_tracked():
    """references/casemode-distinguish-guide.md is TRACKED, and no doc says otherwise."""
    g="references/casemode-distinguish-guide.md"
    if g not in _sh("git","ls-files",g):
        return "%s is no longer tracked -- the three pointers now overclaim"%g
    for f in ("doc/claude/code_analysis/ngspice_case_sensitivity.md",
              "doc/claude/specs/raw_case_mode.md",
              "doc/claude/specs/simulator_profiles.md"):
        txt=io.open(os.path.join(ROOT,f),encoding="utf-8").read()
        for line in txt.split("\n"):
            if "untracked" in line and "casemode-distinguish-guide" in line:
                return "%s calls the guide untracked: %s"%(f,line.strip()[:70])
    return None

def claim_backann_gate():
    """The gated Tcl fallback EXISTS, so no doc may say the ladder was deleted outright."""
    tcl=io.open(os.path.join(ROOT,"src/xschem.tcl"),encoding="utf-8").read()
    i=tcl.index("proc ngspice::lookup")
    body=tcl[i:i+600]
    if "view_armed" not in body or "string tolower" not in body:
        return ("ngspice::lookup no longer has the gated fold fallback -- "
                "raw_case_mode.md 13.7b and the 3.3 backannotation row are now stale")
    for f in ("doc/claude/code_analysis/ngspice_case_sensitivity.md",
              "doc/claude/casemode_batch/DESIGN_REVISION.md"):
        txt=io.open(os.path.join(ROOT,f),encoding="utf-8").read()
        if re.search(r"rungs? (?:are|is|went with them so are)? ?\*\*deleted, not ported\*\*",txt) \
           or "rung went with them, so **the mode" in txt:
            return "%s still says the Tcl ladder was deleted outright"%f
    return None

def claim_lookup_shape():
    """ngspice::lookup HAS a ladder, so no doc may call it 'four lines, no ladder of its own'."""
    tcl=io.open(os.path.join(ROOT,"src/xschem.tcl"),encoding="utf-8").read()
    i=tcl.index("proc ngspice::lookup")
    body=tcl[i:tcl.index("\n}\n",i)]
    if not re.search(r"^\s*foreach\s+\w+\s+\[list\s",body,re.M) or "view_armed" not in body:
        return "ngspice::lookup lost its gated ladder -- re-read raw_case_mode.md 13.2 and 13.7b"
    for f in ("doc/claude/specs/raw_case_mode.md",
              "doc/claude/code_analysis/ngspice_case_sensitivity.md",
              "doc/claude/casemode_batch/DESIGN_REVISION.md"):
        txt=io.open(os.path.join(ROOT,f),encoding="utf-8").read()
        if "no ladder of its own" in txt or re.search(r"ngspice::lookup`?,?\s*four lines",txt):
            return "%s calls ngspice::lookup ladderless; it has %d body lines and a gated ladder"%(
                f,body.count("\n")-1)
    return None

CLAIMS=[("3.1 suite-growth count",claim_suite_growth),
        ("ngspice::lookup has a gated ladder",claim_lookup_shape),
        ("simulator_profiles crew count",claim_crew_count),
        ("the reference guide is tracked",claim_guide_tracked),
        ("backannotation's ONE gated fallback",claim_backann_gate)]

# claims that are ABSENCES, asserted by grep returning nothing
ABSENT=[
 (r"v\(all\)","src","no phantom filter exists (C1: leave it)"),
]
bad=0
for f,ln,rx,why in CITES:
    path=os.path.join(ROOT,f)
    lines=io.open(path,encoding='utf-8',errors='replace').read().split("\n")
    got=lines[ln-1] if 0<ln<=len(lines) else "<past EOF>"
    if re.search(rx,got):
        print("ok:   %s:%d  %s" % (f,ln,why))
    else:
        bad+=1
        print("FAIL: %s:%d  want /%s/ (%s)\n        got: %s" % (f,ln,rx,why,got.strip()[:100]))
import subprocess
for rx,d,why in ABSENT:
    r=subprocess.run(["grep","-rEn",rx,os.path.join(ROOT,d),"--include=*.c","--include=*.h","--include=*.tcl"],
                     capture_output=True,text=True)
    hits=[l for l in r.stdout.split("\n") if l.strip()]
    if hits:
        bad+=1
        print("FAIL: /%s/ found in %s (%s):\n        %s" % (rx,d,why,"\n        ".join(hits[:5])))
    else:
        print("ok:   /%s/ absent from %s/  %s" % (rx,d,why))
for name,fn in CLAIMS:
    why=fn()
    if why:
        bad+=1
        print("FAIL: claim %r\n        %s" % (name,why))
    else:
        print("ok:   claim %r" % name)
print("RESULT: %s (%d citations, %d absence claims, %d prose claims)" % ("ALL PASS" if not bad else "%d FAILED"%bad, len(CITES), len(ABSENT), len(CLAIMS)))
sys.exit(1 if bad else 0)
