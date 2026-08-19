#### File: results.tcl
#
# `Results > Select` — the PURE resolver and the registry READERS.
# doc/claude/specs/results_selection.md sections 4 (R201-R204) and 5 (R304, R305).
#
# Nothing in this file mutates anything. There is no `xschem raw read`, no
# `raw switch`, no `raw select`, no message and no persistence write here: the
# gesture that selects is `results::select`, and it lives in the same namespace
# but is added by its own item. These three procs answer questions.
#
#   results::resolve {state}  -> the four statuses of section 4, NEVER throwing
#   results::list    {}       -> the engine registry, as dicts
#   results::current {}       -> the SELECTED result, or {} — R103's three parts
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
# (src/ase_window.tcl:3472) implements the `ok` and `invalid` arms by hand —
# absolute-ise against the rundir, `file isfile`, else `ase::last_rawfile`. That
# is what this proc generalises, and item 6 re-expresses viewer_restore on top
# of it rather than the other way round.
#
# ---------------------------------------------------------------------------
# CITATIONS. Re-grepped 2026-08-19 at 930e4676 (landmine L9: in-source citations
# in wave_viewer.tcl / ase.tcl / calculator.tcl were measured to be
# systematically stale — issue 0507's comment alone is wrong twice, so every
# pointer below was checked, not copied):
#
#   wviewer::rawinfo_parse      src/wave_viewer.tcl:2380   (PURE, per-LINE)
#   wviewer::db_label           src/wave_viewer.tcl:2401
#   ase::raw_content_verdict    src/ase.tcl:2794           (the ONLY content check)
#   ase::last_rawfile           src/ase.tcl:1952
#   ase::rundir                 src/ase.tcl:1643
#   ase::ui::viewer_restore     src/ase_window.tcl:3472
#   sch_waves_loaded()          src/draw.c:2825   -> `xschem raw loaded`,
#                               src/scheduler.c:10448
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
  # `ase::ui::viewer_restore`'s existing shape (src/ase_window.tcl:3477-3484).
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
# is built on `wviewer::rawinfo_parse` (src/wave_viewer.tcl:2380), which parses
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
# (src/scheduler.c:10448) returns `sch_waves_loaded()` (src/draw.c:2825), which
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
# ⚠ NO SECOND TYPE TABLE, as far as the engine's Tcl surface reaches. The
# authority is `raw_type_is_non_spice()` (src/save.c:1622), which is driven by
# `raw_reader_table[]` (src/save.c:1610-1613) — the same table that picks the
# reader — and it is the exact predicate R102 needs. It has NO Tcl verb.
# `xschem raw is_digital <type>` (src/scheduler.c:10450) exposes the table's
# OTHER column, `raw_type_is_digital()`, and answers a DIFFERENT question on
# purpose: test_backannotate_digital BA12 pins `is_digital table` -> 0, because
# a table is columns of real numbers, i.e. analog data by another reader. So
# `is_digital` covers the VCD half of R102 and cannot cover the table half.
#
# The engine is therefore asked for everything it can answer, and exactly one
# reader token — `table` — is named here, in ONE place, with its C predicate
# cited next to it. When a `raw non_spice` question reaches Tcl (item 3's verb
# is the natural home), this proc becomes a one-line delegation and the token
# goes away. Do not spread the token to a second site.
#
# An EMPTY or `<NULL>` type is a spice raw — "first analysis found in the file"
# — which is what raw_type_is_non_spice()/raw_type_is_digital() both answer for
# a NULL type, so it stays a result.
proc results::_is_result_type {type} {
  set t [string trim $type]
  if {$t eq {} || $t eq {<NULL>}} { return 1 }
  if {![catch {xschem raw is_digital $t} d] && [string is integer -strict $d] && $d} {
    return 0
  }
  if {[string equal -nocase $t table]} { return 0 }
  return 1
}
