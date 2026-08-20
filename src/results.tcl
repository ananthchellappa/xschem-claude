#### File: results.tcl
#
# `Results > Select` — the resolver, the registry READERS, and the ONE GESTURE.
# doc/claude/specs/results_selection.md sections 4 (R201-R204), 5 (R302-R305)
# and 10 (R801-R805).
#
# THE FILE HAS TWO HALVES AND THE LINE BETWEEN THEM IS LOAD-BEARING. Everything
# down to `results::_is_result_type` ANSWERS QUESTIONS: no `xschem raw read`, no
# `raw switch`, no `raw select`, no message, no persistence write, no redraw.
# Below it, `results::select` is the GESTURE — the one place that selects (R302)
# and the door every other caller comes through (R303).
#
#   results::resolve {state}  -> the four statuses of section 4, NEVER throwing
#   results::list    {}       -> the engine registry, as dicts
#   results::current {}       -> the SELECTED result, or {} — R103's three parts
#   results::select  {path ?type? ?opts?}
#                             -> select it, say so once, and report what
#                                happened — R302's six steps, in order
#
# ---------------------------------------------------------------------------
# WHY A RESOLVER AT ALL (section 4, copied from
# doc/claude/specs/simulator_profiles.md's stored-profile resolution): A STORED
# SELECTION MUST NEVER MAKE A SESSION UNOPENABLE. A `.raw` named in a saved
# state can be gone, moved, or older than the netlist that produced it, and none
# of those is an error the user should meet as a stack trace on restore. Every
# status hands the caller something it can still act on.
#
# THE MODEL IS ALREADY IN THE TREE: `ase::ui::viewer_restore`
# (src/ase_window.tcl:4441) implements the `ok` and `invalid` arms by hand —
# absolute-ise against the rundir, `file isfile`, else `ase::last_rawfile`. That
# is what this proc generalises, and item 6 re-expresses viewer_restore on top
# of it rather than the other way round.
#
# ---------------------------------------------------------------------------
# CITATIONS. Re-grepped 2026-08-19 at 8b6a8278 (landmine L9: in-source citations
# in wave_viewer.tcl / ase.tcl / calculator.tcl were measured to be
# systematically stale — issue 0507's comment alone is wrong twice, so every
# pointer below was checked, not copied):
#
#   wviewer::rawinfo_parse      src/wave_viewer.tcl:2393   (PURE, per-LINE)
#   wviewer::db_label           src/wave_viewer.tcl:2414
#   ase::raw_content_verdict    src/ase.tcl:2794           (the ONLY content check)
#   ase::last_rawfile           src/ase.tcl:1952
#   ase::rundir                 src/ase.tcl:1643
#   ase::ui::viewer_restore     src/ase_window.tcl:4441
#   sch_waves_loaded()          src/draw.c:2825   -> `xschem raw loaded`,
#                               src/scheduler.c:10494
#
# ⚠ COMMAND RESOLUTION INSIDE THIS NAMESPACE. `results::list` SHADOWS Tcl's
# built-in `list` for every proc in the namespace (a command name resolves in
# the current namespace before the global one). Every list construction below is
# therefore written `::list`. Do not "tidy" the colons away.

namespace eval results {}

# ---------------------------------------------------------------------------
# R201/R202/R203/R204 — the resolver.
#
# ARGUMENT — RULED BY THE CREW (spec section 4, R201, ruling recorded there):
# `state` is a plain dict of RESOLUTION INPUTS, not an ASE session state. Every
# key is optional and an unknown key is ignored, so a caller with only a path
# passes `[dict create rawfile $p]` and a caller with a whole session passes
# three keys. An ASE session state was rejected as the argument type because it
# would make the resolver reach into `ase::` to find the fields (killing R204's
# purity claim and making it untestable without a session), and because the
# viewer's saved `rawfile` lives in the VIEWER sub-dict, not the state root —
# so "the state" was already ambiguous between two dicts.
#
#   rawfile  the named result, exactly as stored. May be RELATIVE (R602's
#            saved form) — resolved against `rundir` when one is given.
#   rundir   the directory a relative `rawfile` is resolved against.
#   derived  the fallback path when nothing is named or the named one is gone.
#   key      an ASE session key. When `derived` is absent this supplies it, via
#            `ase::last_rawfile` — which is section 4's named default and is
#            itself existence-gated.
#   netlist  the netlist this result was produced from. Present -> the mtime
#            half of `stale` is checked; absent -> only the content half is.
#
# RETURNS a dict, always, with these keys:
#
#   status   default | ok | stale | invalid
#   path     WHAT THE CALLER GETS ANYWAY — the third column of R201's table.
#            `ok`/`stale` -> the named result; `default`/`invalid` -> the
#            derived path when one exists on disk, else {}.
#   named    the named result, absolute-ised, or {} when nothing was named.
#            Kept even when the file is gone: R804-class sentences name it.
#   derived  the derived path when it exists on disk, else {}.
#   why      the REASON for `stale`, or for `invalid`; {} for `default`/`ok`.
#   reason   which half fired: content | mtime | missing | unreadable | {}
#   msg      ONE SENTENCE, always non-empty and distinct per status (T-H).
#
# ⚠ `stale` IS STILL SELECTABLE and returns the NAMED path (R202). A user who
# deliberately kept last night's run is not wrong; the sentence says why it
# looks old. Only `invalid` falls back.
#
# ⚠ IT NEVER THROWS (R201/R202). Every filesystem touch and the content verdict
# are wrapped: a path that is a directory, a dangling symlink, a permission
# error, a `state` that is not a well-formed dict — all answer a status.
#
# ⚠ IT IS PURE (R204). It reads the filesystem and returns a dict. It never
# reads the registry, never calls a `xschem raw` mutator, never emits a message.
# THE CALLER DECIDES WHETHER TO ACT.
proc results::resolve {state} {
  set r [dict create status default path {} named {} derived {} why {} reason {} msg {}]

  # a malformed `state` is answered, not thrown (R201).
  if {[catch {results::_get $state rawfile} named]} { set named {} }
  if {[catch {results::_get $state rundir}  rundir]} { set rundir {} }
  if {[catch {results::_get $state derived} derived]} { set derived {} }
  if {[catch {results::_get $state key}     key]}    { set key {} }
  if {[catch {results::_get $state netlist} netlist]} { set netlist {} }

  # the DERIVED default. `ase::last_rawfile` is section 4's named source and is
  # already existence-gated (src/ase.tcl:1952 returns {} unless the file is
  # there); an explicitly passed `derived` gets the same gate, so that T-H's
  # "the derived path when one exists on disk and {} otherwise" holds either way.
  if {$derived eq {} && $key ne {}} {
    if {[catch {ase::last_rawfile $key} derived]} { set derived {} }
  }
  if {$derived ne {} && ![results::_isfile $derived]} { set derived {} }
  dict set r derived $derived

  # --- default: THE STATE NAMES NO RESULT --------------------------------
  if {[string trim $named] eq {}} {
    dict set r status default
    dict set r path $derived
    if {$derived ne {}} {
      dict set r msg "No result is named, so the derived one is used:\
 [file tail $derived]."
    } else {
      dict set r msg "No result is named and none has been produced yet."
    }
    return $r
  }

  # relative paths resolve against the rundir — R602's saved form, and
  # `ase::ui::viewer_restore`'s existing shape -- which, as of results batch
  # item 6, IS this proc: viewer_restore (src/ase_window.tcl:4441) was
  # re-expressed onto it, so the model and its copy are one again (R604).
  set abs $named
  if {[catch {file pathtype $abs} pt]} { set pt relative }
  if {$pt ne {absolute} && $rundir ne {}} {
    if {[catch {file join $rundir $abs} j]} { set j $abs }
    set abs $j
  }
  dict set r named $abs

  # --- invalid: THE NAMED RESULT IS GONE ---------------------------------
  # "no longer exists on disk" (R201) and "exists but cannot be read" are the
  # same answer here — RULED, recorded in the spec under R201: `stale` is a
  # status the user may still SELECT, and an unreadable file cannot be selected
  # at all, so it belongs with `invalid`, which falls back. The `reason` field
  # keeps the two apart for a caller that wants to say which.
  if {![results::_isfile $abs]} {
    dict set r status invalid
    dict set r reason missing
    dict set r path $derived
    dict set r why "the file named by this state is not there any more"
    if {$derived ne {}} {
      dict set r msg "The selected result [file tail $abs] is no longer on disk\
 — falling back to [file tail $derived]."
    } else {
      dict set r msg "The selected result [file tail $abs] is no longer on\
 disk, and there is no other result to fall back to."
    }
    return $r
  }
  if {![results::_readable $abs]} {
    dict set r status invalid
    dict set r reason unreadable
    dict set r path $derived
    dict set r why "the file named by this state cannot be read"
    if {$derived ne {}} {
      dict set r msg "The selected result [file tail $abs] cannot be read —\
 falling back to [file tail $derived]."
    } else {
      dict set r msg "The selected result [file tail $abs] cannot be read, and\
 there is no other result to fall back to."
    }
    return $r
  }

  # --- stale, half one: THE CONTENT VERDICT ------------------------------
  # R203: `ase::raw_content_verdict` is THE ONLY content check in the tree and
  # it is NOT reimplemented here. It parses the first plot header and refuses a
  # constants-only or zero-point raw WITH A FULL SENTENCE, which is exactly the
  # `why` this status owes. A verdict that merely REPORTS (`appended 1`, or a
  # constants plot carrying real vectors) leaves `ok 1` and is not stale.
  set why {}
  set reason {}
  if {[catch {ase::raw_content_verdict $abs} cv]} { set cv {} }
  if {$cv ne {} && [catch {dict get $cv ok} cok] == 0 && $cok == 0} {
    set why [results::_get $cv why]
    if {$why eq {}} { set why "this file does not hold usable simulation data" }
    set reason content
  }

  # --- stale, half two: OLDER THAN ITS NETLIST ---------------------------
  if {$reason eq {} && $netlist ne {} && [results::_isfile $netlist]} {
    if {[catch {file mtime $abs} rm]} { set rm {} }
    if {[catch {file mtime $netlist} nm]} { set nm {} }
    if {$rm ne {} && $nm ne {} && $rm < $nm} {
      set reason mtime
      set why "this result is older than the netlist it was produced from\
 ([file tail $netlist]), so it predates the current design"
    }
  }

  if {$reason ne {}} {
    dict set r status stale
    dict set r reason $reason
    dict set r path $abs                 ;# R202: STILL the named path
    dict set r why $why
    dict set r msg "Using [file tail $abs], but [results::_unterminated $why]."
    return $r
  }

  # --- ok ----------------------------------------------------------------
  dict set r status ok
  dict set r path $abs
  dict set r msg "Using [file tail $abs]."
  return $r
}

# dict get with a default, and no throw on a malformed dict. Kept private: the
# item's public surface is exactly the three procs above.
proc results::_get {d k {dflt {}}} {
  if {[catch {dict exists $d $k} has]} { return $dflt }
  if {!$has} { return $dflt }
  if {[catch {dict get $d $k} v]} { return $dflt }
  return $v
}

# `file isfile` / `file readable` that answer 0 rather than throwing on a path
# Tcl refuses to stat (a name with a NUL, an unreadable parent directory).
proc results::_isfile {p} {
  if {[catch {file isfile $p} v]} { return 0 }
  return [expr {$v ? 1 : 0}]
}
proc results::_readable {p} {
  if {[catch {file readable $p} v]} { return 0 }
  return [expr {$v ? 1 : 0}]
}

# ONE terminator, not two. `ase::raw_content_verdict`'s `why` is a finished,
# full-stopped sentence (R203 says we quote it, so we do not get to restyle it),
# while the mtime half's `why` is written here as a clause. Composing both as
# "Using X, but $why." gave the content half a "..". R805 says each status has
# exactly one sentence FORM, and a sentence ending in two full stops is not it.
# Only the composed `msg` is trimmed: the `why` FIELD stays the verdict's own
# words verbatim, which is what SEL93 pins.
proc results::_unterminated {s} {
  set t [string trimright $s " \t\n"]
  if {[string index $t end] eq {.}} { set t [string range $t 0 end-1] }
  return $t
}

# ---------------------------------------------------------------------------
# R304 — the registry, as dicts.
#
#   -> {{idx .. path .. type .. cur 0|1 label ..} ...}
#
# in the engine's own order, current one marked rather than moved. `type` is the
# engine's spelling, `<NULL>` included — `wviewer::db_label` is the one place
# that turns that into prose.
#
# ⚠ THERE MUST NOT BE A SECOND PARSER FOR `xschem raw info` (R304, issue
# 0507's ruling). The blob is LINE-structured — `<extra_idx> current`, then one
# `<i> <rawfile> <sim_type-or-<NULL>>` per slot — and `raw_is_loaded`
# (src/xschem.tcl:6980) reads it BY WORD, so one rawfile path containing a space
# turns one database into two malformed slots and truncates the path. This proc
# is built on `wviewer::rawinfo_parse` (src/wave_viewer.tcl:2393), which parses
# per LINE with a greedy path and a trailing `\S+` type and gets that case
# right. Note what the rule is NOT: four line-wise readers already exist
# (rawinfo_parse, ase::raw_indices src/ase.tcl:2935, ase::raw_current :2943, and
# the test helpers), so "exactly one parser" is not the assertion — the
# assertion is that NO BY-WORD PARSER IS CREATED.
#
# EVERY loaded database is listed, VCD and table included. R102 says a VCD is
# not a selectable *result*, but this is the registry reader, not the policy: a
# dialog that wants analog only filters on `type`, and a caller asking "is this
# path already loaded?" must see every slot or it will re-read one it has.
#
# Read-only and non-throwing: `xschem raw info` prints NOTHING AT ALL when no
# raw is loaded, which is why rawinfo_parse answers `cur -1` instead of
# throwing, and why the empty registry here is {} rather than an error.
proc results::list {} {
  set out [::list]
  if {[catch {xschem raw info} txt]} { return $out }
  if {[catch {wviewer::rawinfo_parse $txt} p]} { return $out }
  set cur [results::_get $p cur -1]
  foreach db [results::_get $p dbs] {
    set idx [results::_get $db idx]
    set path [results::_get $db path]
    set type [results::_get $db type]
    if {[catch {wviewer::db_label $path $type} lab]} { set lab [file tail $path] }
    lappend out [dict create idx $idx path $path type $type \
                   cur [expr {$idx eq $cur ? 1 : 0}] label $lab]
  }
  return $out
}

# ---------------------------------------------------------------------------
# R305 — the SELECTED result, or {}.
#
# R103 defines a selection in THREE parts and all three are asserted here:
#   1. it is in the registry            — a slot in `results::list`
#   2. it is current                    — `extra_idx`, i.e. that slot's `cur 1`
#   3. its schname/level stamp RESOLVES  — `xschem raw loaded` >= 0
#      against the current hierarchy stack
#
# and R102 gates the ANSWER: a VCD or a table database can be the current slot
# (`ase::attach_dbs` reads the analog raw and THEN the VCDs, L8, and only
# switches back to slot 0 `if {[llength $got]}`), and it is a loaded database,
# not a selected RESULT. `results::_is_result_type` below is that gate and
# carries the ruling — R305b.
#
# ⚠ A LOADED-BUT-BLIND DATABASE IS NOT A SELECTION (F4). Part 3 is the one that
# is easy to drop and is the whole reason this proc exists. A database is bound
# to the schematic that was current when it was READ (`raw->schname`/`raw->level`);
# navigate to an unrelated cell and `xschem raw info` still lists it and it is
# still `extra_idx`, while every name lookup answers -1. Reporting that as the
# session's result is how the Calculator ends up evaluating against a database
# in which no signal name resolves.
#
# THE QUESTION IS ASKED OF THE ENGINE, NOT RE-DERIVED. `xschem raw loaded`
# (src/scheduler.c:10494) returns `sch_waves_loaded()` (src/draw.c:2825), which
# walks `xctx->sch[i]` from `currsch` DOWN TO 0 and returns the level it matched,
# or -1. Two consequences worth stating because both look like bugs from Tcl:
# an ANCESTOR match counts (a raw read at the top still resolves after a
# descend), and level 0 is a legal answer, so the test is `>= 0` and NEVER
# `!= 0`.
#
# STRICTLY READ-ONLY: three queries, no switch, no walk of the other slots.
# Asking "what is selected?" must never move `extra_idx` (L7: no `update`, no
# `after`, nothing that could redraw against another database).
proc results::current {} {
  if {[catch {xschem raw loaded} lv]} { return {} }
  if {![string is integer -strict $lv] || $lv < 0} { return {} }
  foreach r [results::list] {
    if {[results::_get $r cur 0]} {
      # R102/R305b: the current slot may be a VCD or a table. That is a loaded
      # DATABASE, and it is not a selected RESULT.
      if {![results::_is_result_type [results::_get $r type]]} { return {} }
      return $r
    }
  }
  return {}
}

# ---------------------------------------------------------------------------
# R102 / R305b — is this registry `type` an ANALOG RESULT?
#
# R102: "a result is not a VCD or a table database"; §16 lists independently
# selecting one as a v1 non-goal. `results::list` still lists them (R304a — it
# is the registry reader, not the policy); `results::current` is where the
# policy lives, because it answers "what is THE selected result".
#
# ⚠ NO SECOND TYPE TABLE, AND NO LONGER EVEN ONE TOKEN. The authority is
# `raw_type_is_non_spice()` (src/save.c), driven by `raw_reader_table[]` — the
# same table that picks the reader — and it is the exact predicate R102 needs.
# When item 2 wrote this proc that C function had NO Tcl verb, so the proc asked
# `xschem raw is_digital <type>` (the table's OTHER column) and wrote the one
# remaining reader token, `table`, down in Tcl beside it: `is_digital table` is
# 0 ON PURPOSE (test_backannotate_digital BA12 — a table is columns of real
# numbers, analog data by another reader, RULING D5-2), so the digital column
# covers the VCD half of R102 and cannot cover the table half.
#
# ITEM 3 ADDED THE VERB and this proc became the one-line delegation R305b said
# it should be: `xschem raw non_spice <type>` asks raw_type_is_non_spice()
# directly, and the token is gone from Tcl entirely. Do not bring it back —
# adding a reader type must stay ONE ROW in raw_reader_table[] (issue 0290).
#
# An EMPTY or `<NULL>` type is a spice raw — "first analysis found in the file"
# — which is what raw_type_is_non_spice() answers for a NULL type, so it stays a
# result. `<NULL>` is `xschem raw info`'s rendering of a NULL sim_type, not a
# type token, so it is mapped here rather than in C.
proc results::_is_result_type {type} {
  set t [string trim $type]
  if {$t eq {} || $t eq {<NULL>}} { return 1 }
  if {[catch {xschem raw non_spice $t} ns]} { return 1 }
  if {[string is integer -strict $ns] && $ns} { return 0 }
  return 1
}

# ===========================================================================
# ITEM 4 -- results::select: THE ONE PLACE THAT SELECTS (R302, R303,
# R801-R805). doc/claude/specs/results_selection.md sections 5 and 10.
#
# Everything above this line answers a question. THIS is the gesture, and R303
# says every other caller comes through it -- the Location bar (item 5), the
# restore path (item 6), the ASE-L dialog (item 7), the Calculator (item 10).
# The five paths that will still bypass it after the batch ships are ENUMERATED
# in spec section 18; this item adds none and removes none.
#
# THE ORDER IS THE CONTRACT (R302), and it is the order below:
#   1. resolve            (results::resolve, item 2)   -- never throws
#   2. one spelling       (R302a, below)               -- `file normalize`
#   3. `xschem raw select`(item 3)                     -- 2 switch / 1 read / 0
#   4. MEASURE the engine BEFORE any side effect       -- L7
#   5. the side effects: MRU, case mode, browser, persistence
#   6. ONE sentence, on the host's channel             -- R801-R805
#
# ⚠ NOTHING THROWS (R801). Every arm returns the dict and writes one sentence.
# That is `wviewer::rawbar_load`'s existing contract, inherited whole, and item
# 5 re-expresses that proc on this one without changing what a caller sees.
#
# ⚠ NO `update`, NO `after`, NOTHING THAT CAN REDRAW between the verb and the
# measurement (L7). A redraw while the current-database pointer is moving draws
# the wrong waveforms. And NO SPICE_DATA * IS CACHED ANYWHERE HERE (L5): a
# cached column belongs to one Raw and a selection reassigns xctx->raw without
# freeing, so a pointer held across this proc silently reads the OTHER database.
# ===========================================================================

# ---------------------------------------------------------------------------
# R302a -- CREW RULING (item 4, 2026-08-19). ONE SPELLING PER RUN, AND
# `file normalize` IS WHERE IT IS DECIDED.
#
# THE MEASUREMENT (item 3's receipt section 2, carried forward to this item):
# `w/an.raw` and `w/../w/an.raw` BOTH read, producing TWO registry slots for one
# file, because the engine dedupes by strcmp on the stored spelling. `~/` is the
# only normalisation the C verb does (R301h). So "is this path already loaded?"
# is a Tcl-side question and this is where it is answered.
#
# TWO HALVES, and the second is the one that actually fixes the duplicate:
#   (a) the path handed to the engine is `file normalize`d, so every caller that
#       comes through R303's single door arrives in ONE spelling;
#   (b) BEFORE that, the registry is asked whether some slot's own spelling
#       normalises to the same file -- and if one does, THE ENGINE'S OWN
#       SPELLING is what is passed, so the select lands on the existing slot
#       instead of reading a second copy of it.
# Without (b), a slot some OTHER path created as `w/../w/an.raw` would be
# permanently unreachable through `results::select`, which would go on adding a
# `w/an.raw` beside it every time. With it, this proc converges the registry on
# one slot per file rather than merely declining to make it worse.
#
# WHY NOT IN C: R113 forbids a new data structure and the strcmp dedupe is
# shared by five loops in extra_rawfile(); changing what those compare is a
# behaviour change to `raw read`, `raw switch` and the draw-time autoload walk
# at once.
#
# ⚠ R302h -- CREW RULING (item 4 fixer round, 2026-08-19). WHERE "ONE SPELLING"
# STOPS: AT A FINAL-COMPONENT SYMLINK, DELIBERATELY.
#
# An earlier draft of this comment claimed `file normalize` "resolves symlinks".
# It half does, and the half it does not is the interesting one. MEASURED, with
# a real link tree:
#   file normalize <d>/real/an.raw      -> <d>/real/an.raw
#   file normalize <d>/linkdir/an.raw   -> <d>/real/an.raw     (INTERMEDIATE:
#                                                               resolved)
#   file normalize <d>/linkfile.raw     -> <d>/linkfile.raw    (FINAL: NOT
#                                                               resolved)
# So `~`, `.`, `..`, relative->absolute, a trailing slash and every symlink in a
# DIRECTORY component converge; a symlink naming the .raw ITSELF does not, and
# reaching one file both by its real name and by its link therefore still makes
# two registry slots.
#
# THAT IS RULED AS THE RIGHT BOUNDARY, NOT TOLERATED AS A GAP. A final-component
# symlink is a NAME THE USER CHOSE, and the reason to choose one is almost
# always that it is a MOVING TARGET -- `latest.raw` pointing at whichever run is
# current. Resolving it would put the run-specific path into the sentence
# (R803's db_label is `file tail`, so "Selected latest.raw" would silently
# become "Selected an.raw"), into the MRU that `rawhist_push` records below, and
# into item 6's persistence slot -- freezing the indirection the user built
# expressly so it would not freeze. The cost of stopping here is one extra
# registry slot when the same file is reached both ways, which F7 already
# accepts as the declared cost of never clearing.
#
# So `_engine_spelling` and `_same_path` both answer "same file?" as
# `file normalize` answers it, and no `file readlink` loop is added. If a later
# item wants link identity it needs dev+inode from `file stat`, and it needs to
# answer the label/MRU/persistence question above first.
#
# It is measured, not promised: SEL237-SEL242, and R302h's two boundary
# measurements are SEL289 (intermediate link converges) and SEL290 (final
# component does not).
proc results::_engine_spelling {p} {
  if {[catch {file normalize $p} n]} { return $p }
  if {$n eq {}} { return $p }
  foreach row [results::list] {
    set rp [results::_get $row path]
    if {$rp eq {}} continue
    if {$rp eq $p} { return $rp }
    if {[catch {file normalize $rp} rn]} continue
    if {$rn eq $n} { return $rp }
  }
  return $n
}

# two spellings, one file? The same question (a), asked of two paths.
proc results::_same_path {a b} {
  if {$a eq $b} { return 1 }
  if {[catch {file normalize $a} na]} { return 0 }
  if {[catch {file normalize $b} nb]} { return 0 }
  return [expr {$na eq $nb ? 1 : 0}]
}

# ---------------------------------------------------------------------------
# THE F4 PREDICATE, BEHIND ONE NAME. R305a fixed what "resolves" means: the
# raw's schname is found anywhere on the stack from xctx->currsch DOWN TO 0
# (ancestors count, level 0 is legal), i.e. `xschem raw loaded` >= 0
# (src/scheduler.c:10494 -> sch_waves_loaded(), src/draw.c:2825).
#
# It is a proc and not an inline call for one reason, and the reason is written
# down because it is the kind of seam that looks like indirection for its own
# sake: R804's state is MEASURED UNREACHABLE through `xschem raw select` (see
# R804b below), so the only way to drive the guard is to shim the predicate --
# exactly what landmine L1 prescribes for `select_raw` and what item 2 did for
# `ase::last_rawfile` (SEL108-111). SEL247/SEL248 pin the shim to the engine.
proc results::_resolves_here {} {
  if {[catch {xschem raw loaded} lv]} { return -1 }
  if {![string is integer -strict $lv]} { return -1 }
  return $lv
}

# R803: name the database by db_label -- FILE TAIL + ANALYSIS -- never by full
# path; the full path lives in the balloon and in the returned `path` field.
# R803a limited the RESOLVER to the bare tail because it has no sim_type at all;
# here a type is known, so this is where the db_label form becomes reachable.
proc results::_label {path type} {
  if {[catch {wviewer::db_label $path $type} l]} { set l {} }
  if {$l eq {} || $l eq {?}} {
    if {[catch {file tail $path} l]} { set l $path }
  }
  return $l
}

# ---------------------------------------------------------------------------
# R802 -- THE CHANNEL IS CHOSEN BY HOST, AND THERE IS NO OTHER CHANNEL.
# ASE-L -> ase::echo (src/ase.tcl:138); the viewer sidebar ->
# wviewer::browser_status (src/wave_viewer.tcl:10538); the Calculator ->
# calc::status (src/calculator.tcl:637). NEVER `puts`, NEVER the status bar
# directly -- the house rule.
#
# R802a -- CREW RULING (item 4). THE DEFAULT IS DERIVED FROM WHAT THE CALLER
# GAVE, and "no channel" is a legitimate answer. `opts host` names it outright;
# with no `host`, a `token` means the viewer sidebar and an ASE session `key`
# means ase::echo, and a caller that gave neither gets NO EMISSION AT ALL -- the
# sentence is still in the returned `msg`, which is what a headless caller and
# the dialog's Status region both read. The alternative -- falling back to a
# global channel when the named one is unreachable -- was rejected: a message
# landing in the CIW because a sidebar was not packed is exactly the "never the
# status bar directly" this rule exists to stop.
#
# Returns the channel actually used, or {}. Never throws.
proc results::_emit {host token key msg} {
  if {$msg eq {}} { return {} }
  set h $host
  if {$h eq {}} {
    if {$token ne {}} { set h viewer } elseif {$key ne {}} { set h ase } else { set h none }
  }
  switch -- $h {
    viewer {
      if {$token eq {}} { return {} }
      if {[catch {wviewer::browser_status $token $msg} ok]} { return {} }
      if {!$ok} { return {} }
      return viewer
    }
    ase {
      if {[catch {ase::echo $msg}]} { return {} }
      return ase
    }
    calc {
      if {[catch {calc::status $msg}]} { return {} }
      return calc
    }
  }
  return {}
}

# ---------------------------------------------------------------------------
# THE PERSISTENCE SEAM -- FILLED BY ITEM 6 (R602a). R302 lists "writes the
# persistence slot" among the six things results::select is the one place to
# do, and R601 says the slot is the ASE state's `viewer.rawfile`. The READ side
# was complete and covered from the start; NOTHING HAD EVER WRITTEN IT --
# `wviewer::snapshot` (src/wave_viewer.tcl:4101) hardcoded `rawfile {}`, which
# is the assertion T-F says would have failed for the whole life of the seam.
#
# ⚠⚠ WHAT THIS PROC IS **NOT**, AND WHY ITEM 4'S SEAM DESCRIPTION WAS THE WRONG
# SHAPE (ruled by item 6, spec R602a, evidence in
# doc/claude/results_batch/receipts/06-persistence-write-side.md). Item 4's
# header said this proc would relativise a path and "write" it. It does not
# write the state, for two measured reasons:
#
#   1. THE STATE DICT IS BUILT AT SAVE TIME, NOT AT SELECT TIME. `viewer.rawfile`
#      reaches disk through `wviewer::snapshot` -> `ase::ui::viewer_snapshot`
#      -> `ase::state_save`, and `wviewer::snapshot` REBUILDS the whole viewer
#      sub-dict from the live window. Anything written here would be rebuilt
#      over on the next Save State unless snapshot read it back -- so the write
#      belongs where the dict is built.
#   2. A SELECTION MAY NOT DIRTY THE SESSION. `ase::session_dirty`
#      (src/ase.tcl:3589) is DERIVED -- it serializes `state` and compares it to
#      `saved` -- so an `ase::session_update` from here would mark the session
#      dirty and repaint its title on every Location-bar load, breaking the
#      "snapshot-at-Save-only" contract `ase::ui::viewer_snapshot` documents.
#
#   3. And it could not have carried T-F on its own anyway: the acceptance flow
#      that T-F names (run -> Save State, test_ase_persist G7) never comes
#      through R303's door at all -- `ase::attach_dbs` is a deliberate bypass
#      (spec section 18) -- so a selection RECORDED here would be absent exactly
#      where the round-trip has to hold.
#
# ⚠ WHAT IT DOES: it RECORDS the user's choice for this window, so that
# `wviewer::selected_rawfile` (src/wave_viewer.tcl) can answer with it when the
# engine cannot. The engine is the primary source and is always right when it
# can answer; the recorded choice is the fallback for the one state where it
# cannot -- F4, a result selected while standing on another schematic, where
# `results::current` correctly answers {} (R305) and the user's choice would
# otherwise not survive the save. See `wviewer::selected_rawfile`'s own header.
#
# ⚠ NO RELATIVISATION HERE. R602's relative-when-under-the-rundir form is
# applied by `ase::ui::viewer_snapshot` (src/ase_window.tcl), at the point the
# value is folded INTO the state -- ruled in R602a, and the receipt says why the
# other two candidates lost. What is recorded here is the ENGINE'S OWN spelling,
# absolute, exactly as it was handed to this proc.
#
# ⚠ IT MUST NOT THROW (R801). This is called from the middle of a gesture; the
# call site catches, but a hook that throws would still lose whatever it was in
# the middle of doing. Every step is guarded.
#
# Returns 1 when the choice was recorded, 0 when it declined -- and it declines
# whenever there is no window/session to record it against, which is what a
# headless `results::select $p $t {}` is.
proc results::persist {path type opts} {
  if {[string trim $path] eq {}} { return 0 }
  set tok [results::_get $opts token]
  if {$tok eq {}} { set tok [results::_get $opts key] }
  if {$tok eq {}} { return 0 }
  if {[catch {wviewer::selection_record $tok $path $type} rc]} { return 0 }
  return [expr {$rc eq {1} ? 1 : 0}]
}

# ---------------------------------------------------------------------------
# R302 / R303 -- THE ONE PLACE THAT SELECTS.
#
#   results::select {path {sim_type {}} {opts {}}}
#
# ARGUMENTS
#   path      the result to select. May be relative (resolved against `rundir`),
#             may carry `~/`, may be a spelling of a file already loaded under a
#             different one (R302a), may be {} when `opts` names a fallback.
#   sim_type  the analysis, OPTIONAL -- R301b made it optional in the verb, and
#             this is why: the MRU and the persistence slot store a PATH ONLY,
#             so the gesture that consumes them cannot be made to supply a type.
#             A typeless select prefers the analysis you are already on (R301f).
#   opts      an open dict. Unknown keys are ignored.
#     token         a waveform-viewer window token. Enables the viewer-side
#                   follow-ups (case mode, browser refresh) and is the default
#                   channel. See R302e on WHICH CONTEXT this all happens in.
#     host          viewer | ase | calc | none -- R802's channel, explicitly.
#     key           an ASE session key: the resolver's `key` input (its derived
#                   default, via ase::last_rawfile) AND the default `ase` channel.
#     rundir        directory a relative `path` resolves against (R201a).
#     derived       explicit fallback when `path` is gone or absent (R201a).
#     netlist       the netlist this result came from -- present enables the
#                   mtime half of `stale` (R201a).
#     read_against  the schematic this result was READ against, when the caller
#                   knows it. R804c: there is no Tcl accessor for raw->schname,
#                   so the full R804 sentence needs this from the caller.
#
# RETURNS a dict, always (R801 -- nothing throws):
#   ok       1 only when the selection IS the session's result HERE: in the
#            registry, current, its stamp resolves against this stack, and it is
#            not a digital/non-spice database (R102). That is exactly
#            `results::current`, and this proc ASKS IT rather than asserting.
#   how      read | switch | refused -- what the ENGINE did. `how` is not `ok`:
#            a selection can land (how=switch) and still not resolve (ok=0).
#   path     the engine's own spelling of the selected database, or {}.
#   type     the engine's sim_type for it, or {}.
#   status   the RESOLVER's verdict: default | ok | stale | invalid.
#   why      the resolver's reason, verbatim (R203/R805a -- not restyled).
#   reason   content | mtime | missing | unreadable | {}.
#   named    the named result, absolute-ised, even when it was gone.
#   resolves `xschem raw loaded` after the select: >= 0, or -1 for F4.
#   channel  the channel the sentence went out on, or {}.
#   did      the side effects that actually FIRED, in order: mru,
#            casemode_invalidate, casemode_reapply, browser_refresh, persist.
#   msg      ONE SENTENCE. Always non-empty.
#
# ⚠ R202: A `stale` RESULT IS REPORTED AND STILL SELECTED. It is not an error,
# and neither is `invalid` -- which falls back to the derived path and says
# which happened. Only "there is nothing at all to select" refuses.
#
# ⚠ R302d -- CREW RULING (item 4). THE SIDE EFFECTS FOLLOW THE ENGINE, NOT `ok`.
# Whenever `xschem raw select` returns non-zero the current database HAS
# changed, so the case-mode cache is stale, the browser's inventory is stale and
# the MRU owes the entry -- whether or not the stamp resolves here. Gating them
# on `ok` would leave a window showing the OLD raw's signal list over the NEW
# raw's waveforms, which is the exact defect `browser_refresh $token 1` was
# added to rawbar_load to stop. Only a REFUSED select (rc 0) runs none of them,
# because then nothing moved (F7/T-D).
#
# ⚠ R302e -- CREW RULING (item 4). IT DOES NOT SWITCH CONTEXT. The selection
# happens in whatever Xschem_ctx is current, and standing in the right one is
# the CALLER's job -- `rawbar_load` already does `switch_ctx` (a MOVE, not an
# 0173 loan) before it reads, and R501 keeps that. Two reasons: the registry is
# per-context (tabs do not share one -- measured, src/xinit.c:1938/:2204/:2209),
# so "which context" is a caller decision and not a resolver's; and a bracket
# here would put an enter/leave pair around the engine call, which is precisely
# the window L7 forbids anything to redraw in. `token` is therefore used ONLY
# for the follow-ups and the channel, never to decide where the select lands.
#
# ⚠ 0216's SHAPE IS FIXED FOR THIS PATH by the `rawhist_push` below.
# `ase::attach_raw` -- the path every ASE run takes -- never pushes, so the one
# durable list of past results systematically omits the results the user
# actually produced. Converting that path is NOT this item (spec section 18
# keeps `ase::attach_dbs` a deliberate bypass: a run is not a selection), but
# every gesture that comes through R303's door now records itself.
# L11: rawhist_push NO-OPS unless ::update_recent_files is set (issue 0119), so
# a scripted selection legitimately leaves no trace and `did` will not list it.
proc results::select {path {sim_type {}} {opts {}}} {
  set token   [results::_get $opts token]
  set host    [results::_get $opts host]
  set key     [results::_get $opts key]
  set rundir  [results::_get $opts rundir]
  set derived [results::_get $opts derived]
  set netlist [results::_get $opts netlist]
  set against [results::_get $opts read_against]

  set r [dict create ok 0 how refused path {} type {} status {} why {} \
           reason {} named {} resolves -1 channel {} did [::list] msg {}]

  # --- 1. THE RESOLVER (item 2) -----------------------------------------
  set inp [dict create rawfile $path rundir $rundir derived $derived \
             key $key netlist $netlist]
  if {[catch {results::resolve $inp} rs]} {
    # results::resolve is documented never to throw; if it ever does, that is
    # not the user's problem to meet as a stack trace (R801).
    set rs [dict create status invalid path {} named {} why $rs reason unreadable \
              msg "That result could not be resolved."]
  }
  dict set r status [results::_get $rs status]
  dict set r why    [results::_get $rs why]
  dict set r reason [results::_get $rs reason]
  dict set r named  [results::_get $rs named]

  # R201's third column: WHAT THE CALLER GETS ANYWAY. `ok`/`stale` -> the named
  # result (R202 -- stale is still selectable); `default`/`invalid` -> the
  # derived path when one exists on disk, else {}.
  set cand [results::_get $rs path]
  if {[string trim $cand] eq {}} {
    # nothing to select: the resolver already composed the one sentence that
    # says why, in the form R805 fixes for its status. Do not write a second.
    dict set r msg [results::_get $rs msg]
    dict set r channel [results::_emit $host $token $key [dict get $r msg]]
    return $r
  }

  # --- 2. ONE SPELLING PER RUN (R302a) -----------------------------------
  set target [results::_engine_spelling $cand]

  # --- 3. THE VERB (item 3): 2 = switch, 1 = read, 0 = refused ------------
  # L6: an empty type is never passed through as a positional, because an empty
  # positional is not the same question as "no type given" -- and a slot whose
  # sim_type is NULL is unreachable BY NAME either way.
  set rc 0
  if {$sim_type eq {}} {
    if {[catch {xschem raw select $target} rc]} { set rc 0 }
  } else {
    if {[catch {xschem raw select $target $sim_type} rc]} { set rc 0 }
  }
  if {![string is integer -strict $rc]} { set rc 0 }
  if {$rc == 0} {
    # T-D / F7: nothing moved. The registry, the current database and the
    # switch-back cursor are exactly as they were -- item 3's raw_select_undo()
    # restores all three -- and this proc has run no side effect yet, by
    # construction: the verb is the first thing it does after resolving.
    dict set r how refused
    dict set r msg "Could not select [results::_label $target $sim_type] —\
 nothing was loaded and the previous result is unchanged."
    dict set r channel [results::_emit $host $token $key [dict get $r msg]]
    return $r
  }
  dict set r how [expr {$rc == 2 ? {switch} : {read}}]

  # --- 4. MEASURE THE ENGINE, BEFORE ANY SIDE EFFECT (L7) ----------------
  # Four read-only queries and nothing between them: no update, no after, no
  # redraw. The side effects below can reach Tk; the verdict must not depend on
  # what they did.
  set epath $target
  if {[catch {xschem raw rawfile} v] == 0 && $v ne {}} { set epath $v }
  set etype {}
  if {[catch {xschem raw_query sim_type} v] == 0} { set etype $v }
  set lv  [results::_resolves_here]
  set sel {}
  if {[catch {results::current} sel]} { set sel {} }
  dict set r path $epath
  dict set r type $etype
  dict set r resolves $lv
  set label [results::_label $epath $etype]

  # THE VERDICT IS results::current's, NOT A SECOND OPINION (R103, R305).
  # `ok` means all three parts of a selection hold AND R102's type gate passes,
  # which is exactly what results::current answers -- so `ok 1` and a non-empty
  # results::current can never disagree, which is what item 10's T-I needs.
  #
  # ⚠ `$lv >= 0` IS CONJOINED DELIBERATELY AND IS NOT REDUNDANT BOOKKEEPING.
  # results::current asks `xschem raw loaded` for itself (R305a), so in
  # production the two terms always agree -- but the SENTENCE below branches on
  # `$lv`, and a dict whose `msg` says "no signal names will resolve" beside an
  # `ok 1` is exactly the defect R804 and T-M name. One measurement, one
  # verdict, one sentence: the F4 question is asked ONCE, through
  # results::_resolves_here, and both the verdict and the sentence are read off
  # it. (Measured while writing T-M: without this term, shimming the seam moved
  # the sentence and left `ok` at 1 -- the two halves of the dict contradicting
  # each other, which is precisely what a caller cannot be asked to reconcile.)
  set isres 0
  if {$lv >= 0 && $sel ne {} && [results::_same_path [results::_get $sel path] $epath]} {
    set isres 1
  }
  dict set r ok $isres

  # --- 5. THE SIDE EFFECTS (R302d) ---------------------------------------
  set did [::list]
  set pushed 0
  catch {set pushed [wviewer::rawhist_push $epath]}
  if {$pushed eq {1}} { lappend did mru }
  if {$token ne {}} {
    if {![catch {wviewer::casemode_invalidate $token}]} { lappend did casemode_invalidate }
    set re 0
    catch {set re [wviewer::casemode_reapply $token $epath]}
    if {$re eq {1}} { lappend did casemode_reapply }
    set br 0
    catch {set br [wviewer::browser_refresh $token 1]}
    if {$br eq {1}} { lappend did browser_refresh }
  }
  set wrote 0
  catch {set wrote [results::persist $epath $etype $opts]}
  if {$wrote eq {1}} { lappend did persist }
  dict set r did $did

  # --- 6. ONE SENTENCE (R801-R805) ---------------------------------------
  dict set r msg [results::_select_msg [dict get $r status] $label \
                    [dict get $r why] [dict get $r reason] [dict get $r named] \
                    $lv $isres $against]
  dict set r channel [results::_emit $host $token $key [dict get $r msg]]
  return $r
}

# ---------------------------------------------------------------------------
# R805 -- ONE SENTENCE FORM PER OUTCOME, and the two that outrank the resolver's
# verdict come first, because a selection that landed somewhere unusable is not
# described by how its PATH resolved.
#
# ⚠ `switch` IS NOT USED HERE ON PURPOSE. One of the four resolver statuses is
# spelled `default`, which is also `switch`'s catch-all keyword, so a
# `switch -- $status { default {...} }` would answer the `default` STATUS for
# every unknown one too and would never be seen to be wrong.
proc results::_select_msg {status label why reason named lv isres against} {
  if {$lv < 0} { return [results::_r804_msg $label $against] }
  if {!$isres} {
    # R102: it loaded, and it is not a RESULT. A VCD or a non-spice database is
    # a loaded database with no analysis to evaluate against; ase::attach_dbs
    # leaves exactly this state behind on every mixed-signal run (L8).
    return "$label is now the current database, but a digital or non-spice\
 database is not a result you can evaluate against."
  }
  if {$status eq {stale}} {
    return "Selected $label, but [results::_unterminated $why]."
  }
  if {$status eq {invalid}} {
    set gone [file tail $named]
    if {$reason eq {unreadable}} {
      return "$gone cannot be read, so $label was selected instead."
    }
    return "$gone is no longer on disk, so $label was selected instead."
  }
  if {$status eq {default}} {
    return "No result was named, so the derived one was selected: $label."
  }
  return "Selected $label."
}

# ---------------------------------------------------------------------------
# R804 -- THE SENTENCE THE WHOLE FEATURE EXISTS FOR. A selection that LANDS but
# cannot resolve (F4 -- the stamp does not match the current hierarchy stack) is
# reported as such, IN THOSE WORDS, and is NEVER silently reported as success:
#
#   Selected srlatch_ase.raw (dc), but this result was read against srlatch.sch
#   and you are in tb_diff_amp.sch — no signal names will resolve until you
#   return.
#
# R804c -- CREW RULING (item 4, 2026-08-19). THE "was read against X" CLAUSE
# NEEDS A CALLER, BECAUSE raw->schname HAS NO TCL ACCESSOR. Measured: the whole
# `xschem raw` / `raw_query` arm answers add, annot, datasets, del, index, list,
# points, pos_at, rawfile, rename, sim_type, value, values, vars, view_armed,
# view_keys -- and no schname (src/scheduler.c, the raw arm). `xschem get
# raw_level` gives the LEVEL only, and in exactly the state this sentence
# describes that level indexes a DIFFERENT stack, so `xschem get schname <lev>`
# would name the wrong cell with total confidence. This item is Tcl-only, so the
# accessor is filed as issue 0514 rather than added here.
#
# So: the cell you ARE in is read from the engine (`xschem get schname`, which
# is the current one, tail per R803); the cell it was READ AGAINST comes from
# `opts read_against` when the caller knows it, and when it does not the clause
# is dropped and the sentence keeps the load-bearing half -- that no signal name
# will resolve until you go back. Both forms are pinned (SEL251, SEL252).
#
# R804b -- CREW RULING (item 4). THE F4 STATE IS MEASURED UNREACHABLE THROUGH
# `xschem raw select`, AND THE GUARD STAYS. Measured 2026-08-19 on the item-3
# binary: read an.raw under cellA (`raw loaded` 0), `xschem load` cellB
# (`raw loaded` -1), `raw select an.raw tran` -> 2 and `raw loaded` 0 again.
# `raw select` sets RAW_READ_REBIND, so a dedupe hit re-stamps (R110/R110c) and
# a fresh read is stamped by the reader itself; a table and a VCD were measured
# the same way and also came back >= 0. It is kept, and it is not decoration:
#   - R111 rules that `xschem raw switch` deliberately does NOT re-bind, so any
#     caller that reaches this proc after a navigation is one re-ordering away
#     from the state;
#   - draw.c's autoload walk reaches the same dedupe arm WITHOUT the re-bind bit
#     (U10), so a graph rect can leave a slot bound elsewhere for a later select
#     to find;
#   - R303 makes this the single door, and item 6's restore path and item 7's
#     dialog will drive it from contexts this item cannot test;
#   - and it is what makes `ok 1` mean "signal names resolve here" rather than
#     "the engine did something", which is the whole of T-M.
# Because it is unreachable through the verb, the check drives it through the
# `results::_resolves_here` seam -- shimmed, as L1 prescribes -- with SEL247/248
# pinning that seam to `xschem raw loaded` so the shim cannot be the only
# evidence.
proc results::_r804_msg {label against} {
  set here {}
  if {[catch {xschem get schname} here]} { set here {} }
  if {$here ne {}} {
    if {[catch {file tail $here} t] == 0} { set here $t }
  }
  if {$against ne {}} {
    if {[catch {file tail $against} a] == 0} { set against $a }
  }
  if {$against ne {} && $here ne {}} {
    return "Selected $label, but this result was read against $against and you\
 are in $here — no signal names will resolve until you return."
  }
  if {$here ne {}} {
    return "Selected $label, but this result was not read against $here — no\
 signal names will resolve until you return to the schematic it was read from."
  }
  return "Selected $label, but this result was not read against the schematic\
 you are in — no signal names will resolve until you return to the schematic it\
 was read from."
}
