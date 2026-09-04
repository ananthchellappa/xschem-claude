## File: src/op_param_lists.tcl
##
## THE OP PARAMETER LIST STORE -- item B2 of doc/claude/op_param_batch/PLAN.md.
## Spec: doc/claude/specs/op_param_lists.md, section 4.3 (the class map) and
## section 4.4 (the settings file). Rulings: doc/claude/op_param_batch/
## DECISIONS.md -- D-4, D-7, and the driver decisions DD-2 and DD-3.
##
## Four things live here and nothing else. There is NO UI (the window is item
## B3's, the buttons are B5's) and no C.
##
##   (a) THE CLASS MAP.  A `type=` K-record token -> a broad class. It is DATA,
##       an array a user extends with one line, never a `switch`. Measured: the
##       shipped `type=` vocabulary is OPEN -- sky130 alone ships `varactor`,
##       `npn`, `pnp`, `pwell_resistor`, `p_diffusion_resistor`,
##       `n_diffusion_resistor` and `high_precision_p`; IHP ships `pnp` (NOT
##       `vertical_pnp`), `inductor` and `esd`; and xschem_library uses `type=`
##       for bare part numbers (2N3906, 4001, 12SK7). A closed classifier would
##       be wrong on the day it shipped.
##       AN UNMAPPED TOKEN IS ITS OWN CLASS -- identity, never {} and never a
##       raise. That makes the map an OVERRIDE TABLE rather than a gate: a PDK
##       with a token nobody anticipated still gets working lists, and the
##       shipped default therefore stays at section 4.3's five groups and
##       invents no grouping the user never ruled on.
##
##   (b) THE ORDERED LISTS, per class (DD-2's primary key) and per flavor
##       (DD-2's optional override, a CELL-NAME GLOB, the same narrowing
##       op_annot::_matches already performs). List names are `annotation` and
##       `summary`. Section 4.2's third list, `all`, is LIVE from the simulator
##       and is NEVER PERSISTED: storing it would be a list no simulator ever
##       published, which is the invented data ruling D-4 forbids. So `owns`
##       answers 0 for it, `effective` answers {}, and a settings-file row that
##       names it is reported and skipped.
##
##   (c) THE PDK SEED (D-7: "seed from the PDK, the user's file wins"). A class
##       with no user entry answers the ordered {label param kind} triples the
##       PDK registered through op_annot::register, read back through the
##       published op_annot::descriptor. There is no second registry here.
##       THE SEED IS A TRIPLE, NOT A NAME, AND IHP IS THE PROOF:
##       sky130A/sky130_procs.tcl and gf180mcuD/gf180_procs.tcl both declare
##       `{id id 0}`, but ihp-sg13g2/sg13g2_procs.tcl declares `{id ids 0}` --
##       LABEL `id`, PARAM `ids`, and they DIFFER. A store that kept only the
##       name would round-trip two PDKs perfectly and silently rewrite the
##       third. All three fields are carried everywhere, including through the
##       settings file.
##
##   (d) THE SETTINGS FILE, read by a strict parser and written with the
##       write-beside-and-move idiom.
##
## ===========================================================================
## DD-3: THE SETTINGS FILE IS DATA, AND IS NEVER SOURCED
## ===========================================================================
## TWO FILES, NOT ONE. Spec section 4.4 conflates them; DD-3 corrects it. THIS
## file is the IMPLEMENTATION -- Tcl code, shipped, installed, sourced from
## xschem.tcl. The SETTINGS FILE it reads is
##
##     <pwd>/.xschem/op_param_lists.conf        the project tier
##     $USER_CONF_DIR/op_param_lists.conf       the user-global fallback
##
## and it is line-oriented DATA. The reader does no `source`, no `eval`, no
## `subst`, no `uplevel` and no substitution of any kind; anything it does not
## recognise is REPORTED and SKIPPED, never obeyed.
##
## The reason is the user's own requirement that the file be SHAREABLE WITH
## TEAMMATES. A file that is shared and then sourced is arbitrary code
## execution on whoever opens the project -- the headline feature would be the
## vulnerability. MEASURED on this tree, feeding a plausible shared conf to the
## `uplevel #0 [list source $path]` idiom that ase::sim_load_conf uses, with the
## payload placed FIRST under a friendly "share freely" header:
##
##     SOURCED: OPL_PWNED=1  marker_on_disk=1  err={invalid command name "mos"}
##
## The variable was set AND a file was created; the Tcl error that follows is
## COSMETIC, because the payload had already run. A caller that read the raise
## as evidence would have scored that file safe. Issue 0812 already burned this
## tree on `subst` and paths. The price is this parser instead of a one-line
## `source`, and it is worth it.
##
## FIELDS ARE SPLIT WITH `regexp -inline -all {\S+}`, NEVER by treating the
## line as a Tcl list. Measured: `llength {mos annotation { id 0}` RAISES
## `unmatched open brace in list`, so a stray `{` in a teammate's file would
## kill the reader from the inside. A parser its own input can kill is not a
## strict parser.
##
## THE GRAMMAR (every row self-contained, so skipping a malformed one cannot
## silently reassign the rows after it):
##
##     # a whole-line comment ; blank lines are skipped
##     version 1
##     class  <type-token> <broad-class>
##     list   <scope> <key> <listname>
##     param  <scope> <key> <listname> <label> <rawparam> <kind>
##
## A `param` row implicitly declares its list, so a hand-editing user never has
## to write the `list` line; `list` exists so an EMPTIED list can be expressed,
## and a lost `list` line degrades to the PDK seed, which is the safe
## direction. THE FIRST `param` OR `list` ROW FOR A GIVEN (scope,key,listname)
## IN A FILE CLEARS WHAT AN EARLIER TIER PUT THERE -- that is what makes the
## project file WIN over the user-global one (D-7) rather than append to it.
## Within one file the rows then accumulate in file order, and a repeated LABEL
## replaces in place and is reported.
##
## THE TIER WIN IS PER (scope,key,listname), NOT PER CLASS. DD-3's own sentence
## says "per class"; per-list is FINER, never coarser, so a project file that
## customises `mos annotation` no longer silently discards the user-global's
## `mos summary`.
##
## THE PROJECT TIER IS `<pwd>/.xschem/`, NOT `[xschem get current_dirname]`.
## Measured: after loading a schematic from elsewhere current_dirname MOVES
## while pwd does not, so a Save taken while descended into a PDK library cell
## would write the project file into the PDK tree and the next read, back at the
## top, would not find it. pwd is stable for the whole session, so the reader
## and the writer can never silently disagree, and it matches the tree's ONLY
## project-vs-user precedent, xinit.c:3500-3515's `./xschemrc` in pwd. This is
## an L2 ladder decision and is on the owed ledger as a rule debt, issue 1273.
##
## ===========================================================================
## ENCODING IS PINNED ON BOTH CHANNELS; TRANSLATION IS DELIBERATELY NOT
## ===========================================================================
## MEASURED on this box: `encoding system` is utf-8 here and iso8859-1 under
## LC_ALL=C, and the SAME BYTES read back as a DIFFERENT STRING (length 15 vs
## 16) depending on the reader's locale. A file whose headline feature is that
## it is shareable cannot depend on the teammate's LANG, so _chanconf pins
## `-encoding utf-8` on the read channel AND the write channel. Nothing else in
## this tree pins it, so it does not arrive by copying a neighbour.
## CRLF, on the other hand, is ALREADY handled by the DEFAULT `auto`
## translation; copying the tree's `-translation binary` idiom (ase.tcl:1625,
## xschem.tcl:7910) would REINTRODUCE the bug. Pin the encoding, leave the
## translation alone, and keep action_registry.tcl's defensive trailing-\r trim.
##
## ===========================================================================
## SOURCE-TIME PURITY
## ===========================================================================
## This file is a BARE `source` from xschem.tcl, which puts it inside
## tests/headless/test_startup_guard_0663's contract: a raise at SOURCE TIME
## aborts startup (cleanly now, exit 1; via issue 0423 it used to be exit 139).
## So the file defines PROCS and LITERAL namespace variables and nothing else.
## It reads no file, stats no directory, calls no `xschem` subcommand and
## touches op_annot:: not at all until a proc is called. op_annot.tcl:224-231
## states the rule for itself; this file inherits it. It must also source
## cleanly TWICE and into a bare Tcl interpreter that has no `xschem` command.
##
## ===========================================================================
## THE APPLY DOOR IS op_annot::register, AND IT IS CALLED FROM NOWHERE HERE
## ===========================================================================
## Invariant I5 requires a changed list to take effect ON REDRAW -- no restart,
## no rebuild. Only op_annot::register bumps ::op_annot::gen (op_annot.tcl:346),
## which annot_overlay_sync() folds into the overlay's epoch (actions.c:2032). A
## direct `set ::op_annot::desc(...)` would be stored, correct in Tcl, and
## INVISIBLE ON SCREEN until an unrelated redraw -- I5 failing silently. So
## `apply` exists here, and defining it is what stops item B5 writing a second
## door. It is deliberately UNWIRED: an auto-apply at startup is provably wrong
## ordering, because this file is sourced from xschem.tcl before any PDK
## `_procs.tcl` runs, so it would write into an empty registry and register's
## deliberate REPLACE semantics would then discard it.
##
## Suite: tests/headless/test_op_param_store_1245.tcl.

namespace eval ::op_param_lists {

  ## THE SHIPPED DEFAULT CLASS MAP -- section 4.3's five groups and nothing
  ## more. A map entry is a CLAIM that two tokens share one list; groupings no
  ## ruling covers (varactor -> capacitor, esd -> diode) are exactly the shape
  ## D-4 forbids, one level up, and the identity fallback below makes leaving
  ## them out harmless. Measured tokens that are deliberately NOT here, each a
  ## one-line `class <token> <class>` row in the user's own settings file:
  ##   sky130: varactor npn pnp pwell_resistor p_diffusion_resistor
  ##           n_diffusion_resistor high_precision_p
  ##   IHP:    pnp inductor esd
  ## sky130 spells a resistor THREE ways, which is why `res` is not enough.
  variable defaultmap {
    nmos                          mos
    pmos                          mos
    res                           resistor
    poly_resistor                 resistor
    high_precision_poly_resistor  resistor
    high_precision_poly_p         resistor
    capacitor                     capacitor
    moscap                        capacitor
    diode                         diode
    vertical_npn                  bipolar
    vertical_pnp                  bipolar
  }

  ## token -> broad class. Guarded exactly as op_annot.tcl guards `desc`, so a
  ## second source of this file is a no-op rather than a silent reset of a
  ## user's map.
  variable classmap
  if {![array exists classmap]} { array set classmap $defaultmap }

  ## [list <scope> <key> <listname>] -> the ordered list of {label param kind}.
  variable lists
  if {![array exists lists]} { array set lists {} }

  ## The same key -> 1 when the USER owns that list. `owns` 1 with an empty
  ## list and `owns` 0 are DIFFERENT FACTS -- "I chose to show nothing" against
  ## "I never customised this" -- and collapsing them would answer the PDK seed
  ## to a user who had deliberately cleared the list. Issue 1272 cost this batch
  ## one item for the same collapse, one class further out.
  variable owned
  if {![array exists owned]} { array set owned {} }

  ## broad class -> 1 once a seed divergence has been reported for it. Separate
  ## from `reports` on purpose: said_clear empties the reports the caller has
  ## already read, and must not make the store say the same thing again.
  variable warned
  if {![array exists warned]} { array set warned {} }

  ## The report buffer. A LIST, one element per report, so a caller can count
  ## how many times the user was told something.
  variable reports
  if {![info exists reports]} { set reports {} }

  variable scopes    {class flavor}
  variable listnames {annotation summary}
  ## Section 4.2's list 3. Live from the simulator, never persisted (D-4).
  variable livelist  all
  variable version   1
  variable basename  op_param_lists.conf

  ## -----------------------------------------------------------------------
  ## REPORTING. Reported and skipped, never obeyed (DD-3).
  ## The stderr prefix follows action_registry.tcl:329. It must NOT begin a
  ## line with `FAIL:` at column 0: full_audit.sh's has_failure() is
  ## `^(FAIL[: !]|...)`, so a store that echoed its reports that way would red
  ## its own suite from the outside.
  ## -----------------------------------------------------------------------
  proc _say {msg} {
    variable reports
    lappend reports $msg
    catch {puts stderr "op_param_lists: $msg"}
    return {}
  }

  proc said {} { variable reports ; return $reports }

  proc said_clear {} { variable reports ; set reports {} ; return {} }

  ## Back to the shipped map and no user lists at all.
  proc reset {} {
    variable classmap ; variable defaultmap ; variable lists
    variable owned ; variable warned ; variable reports
    array unset classmap
    array set classmap $defaultmap
    array unset lists
    array set lists {}
    array unset owned
    array set owned {}
    array unset warned
    array set warned {}
    set reports {}
    return {}
  }

  ## -----------------------------------------------------------------------
  ## THE CLASS MAP
  ## -----------------------------------------------------------------------
  ## op_param_lists::class <type-token> -> the broad class.
  ## Identity for a token nobody mapped. Never {} and never a raise: returning
  ## {} would silently lose the lists of every token nobody anticipated, and
  ## raising would contradict op_annot::descriptor's own rule that "this type is
  ## not annotated" is a DATA condition.
  proc class {token} {
    variable classmap
    if {[info exists classmap($token)]} { return $classmap($token) }
    return $token
  }

  ## The extension door. One line in a settings file, or one call from an rc.
  proc set_class {token cls} {
    variable classmap
    set classmap($token) $cls
    return $cls
  }

  ## -----------------------------------------------------------------------
  ## KEYS AND VALIDATION
  ## -----------------------------------------------------------------------
  proc _key {scope key listname} { return [list $scope $key $listname] }

  proc _valid_scope {scope} {
    variable scopes
    return [expr {[lsearch -exact $scopes $scope] >= 0 ? 1 : 0}]
  }

  proc _valid_list {listname} {
    variable listnames
    return [expr {[lsearch -exact $listnames $listname] >= 0 ? 1 : 0}]
  }

  ## THE ONE NORMALISER. Every stored entry passes through here, so the store
  ## has exactly one idea of what an entry is: THREE fields, all three carried.
  ## Answers {} for anything it cannot store -- and a whitespace-bearing field
  ## is one of those, because the settings file is whitespace-delimited and a
  ## field with a space in it could not be read back.
  ## The kind is any INTEGER: the store is deliberately not stricter than
  ## op_annot::_wrap, whose default arm copies token.c's "anything but 0/1 is
  ## v(...)" convention, so a PDK that starts using a fourth kind is not gated
  ## by this file.
  proc _triple {t} {
    if {[catch {llength $t} n]} { return {} }
    if {$n != 3} { return {} }
    foreach f $t {
      if {$f eq {}} { return {} }
      if {[regexp {\s} $f]} { return {} }
    }
    if {![string is integer -strict [lindex $t 2]]} { return {} }
    return [list [lindex $t 0] [lindex $t 1] [lindex $t 2]]
  }

  ## -----------------------------------------------------------------------
  ## THE LISTS
  ## -----------------------------------------------------------------------
  proc owns {scope key listname} {
    variable owned
    if {![_valid_scope $scope]} { return 0 }
    if {![_valid_list $listname]} { return 0 }
    return [expr {[info exists owned([_key $scope $key $listname])] ? 1 : 0}]
  }

  proc get_list {scope key listname} {
    variable lists
    if {![owns $scope $key $listname]} { return {} }
    return $lists([_key $scope $key $listname])
  }

  ## Store one whole list. Returns 1, or 0 WITH A REPORT and no change at all:
  ## a half-applied list is a list the user never chose.
  proc set_list {scope key listname triples} {
    variable lists ; variable owned
    if {![_valid_scope $scope]} {
      _say "unknown scope \"$scope\"; expected `class` or `flavor`"
      return 0
    }
    variable livelist
    if {$listname eq $livelist} {
      _say "the `$livelist` list is live from the simulator and is never stored (ruling D-4)"
      return 0
    }
    if {![_valid_list $listname]} {
      _say "unknown list name \"$listname\"; expected `annotation` or `summary`"
      return 0
    }
    if {$key eq {} || [regexp {\s} $key]} {
      _say "the $scope key \"$key\" is empty or carries whitespace, so it could not be written back"
      return 0
    }
    if {[catch {llength $triples} n]} {
      _say "the $scope list \"$key $listname\" is not a well-formed list ($triples)"
      return 0
    }
    set out {}
    foreach t $triples {
      set tt [_triple $t]
      if {$tt eq {}} {
        _say "refusing the $scope list \"$key $listname\": the entry \"$t\" is not a {label param kind} triple of three whitespace-free fields with an integer kind"
        return 0
      }
      lappend out $tt
    }
    set k [_key $scope $key $listname]
    set lists($k) $out
    set owned($k) 1
    return 1
  }

  ## -----------------------------------------------------------------------
  ## THE PDK SEED (D-7)
  ## -----------------------------------------------------------------------
  ## The params of ONE registered type, read through the published accessor.
  ## Never enumerates ::op_annot::desc: the candidate types for a class are the
  ## tokens the CLASS MAP sends there, so this file reaches into no other
  ## namespace's internals and a class nobody registered answers {}.
  proc _params {type} {
    if {[catch {::op_annot::descriptor $type} d]} { return {} }
    if {$d eq {}} { return {} }
    if {[catch {dict exists $d params} has]} { return {} }
    if {!$has} { return {} }
    if {[catch {dict get $d params} p]} { return {} }
    if {[string trim $p] eq {}} { return {} }
    ## ⚠ THE PDK'S `params` IS AN UNVALIDATED STRING AND THIS IS THE ONLY DOOR
    ## IT ENTERS THE STORE BY -- ISSUE 1291.
    ## Every guard above answers a question about the DICT; none asks whether
    ## the value is a well-formed Tcl LIST. It need not be: a descriptor may be
    ## registered from a user's own rc (invariant I5, which is the documented
    ## way to choose a different parameter set), and issue 0447's live shape is
    ## a valid triple followed by an unclosed open brace -- row K17 of
    ## test_op_annot golds that exact string. (It is not written out here: an
    ## unbalanced brace in a comment makes THIS file fail `info complete`,
    ## which is how this comment was first written and immediately caught.)
    ##
    ## Returned verbatim, that string reaches `foreach t [effective ...]` in
    ## _save_set and _show_set and RAISES `unmatched open brace in list`. Item
    ## B2b opened that door without meaning to: HEAD's apply never called seed
    ## at all, and the union is what made the seed reachable. Measured: apply
    ## went rc=0 -> rc=1, wrote nothing, and left the descriptor permanently
    ## un-applyable for the rest of the session.
    ##
    ## ⚠ BOTH LEVELS ARE CHECKED, because both raise. A malformed OUTER list
    ## breaks `foreach`; a well-formed outer list holding a malformed ELEMENT
    ## breaks the `lindex` that reads the triple one line later. Answering {}
    ## for the whole descriptor is deliberate: half a parameter list is not a
    ## safer answer than none, and the report says which type was dropped.
    if {[catch {llength $p}]} {
      _say "the descriptor for `$type` has a params list that does not parse;\
            ignoring it. Fix it in the rc that registered it."
      return {}
    }
    foreach _row $p {
      if {[catch {llength $_row}]} {
        _say "the descriptor for `$type` has a params row that does not parse;\
              ignoring the whole list. Fix it in the rc that registered it."
        return {}
      }
    }
    return $p
  }

  ## op_param_lists::seed <class> -> the PDK's ordered triples for that class.
  ##
  ## THE MAP IS NOT ONTO and that is normal: IHP registers `vertical_npn` and
  ## no `vertical_pnp` though section 4.3's map names both, and three of the
  ## five shipped classes (resistor, capacitor, diode) are registered by no PDK
  ## in this tree at all. Each answers {} without raising.
  ##
  ## WHEN TWO TYPES IN ONE CLASS DISAGREE: the FIRST WINS and the divergence is
  ## reported ONCE. NOTHING IS EVER MERGED -- a merged list is one no PDK ever
  ## declared, which is the invented data D-4 forbids.
  ## "First" is spelled FIRST IN LEXICAL ORDER OF THE `type=` TOKEN, not first
  ## registered: ::op_annot::desc is a Tcl ARRAY, `array names` answers hash
  ## order, and op_annot publishes no enumerator, so registration order is not
  ## available to any caller. Lexical order is deterministic and COINCIDES with
  ## registration order for every PDK in this tree (each registers via
  ## `foreach t {nmos pmos}`). The missing enumerator is filed as issue 1274,
  ## not fixed here -- this item may not edit op_annot.tcl.
  ## No shipped PDK produces the disagreement: all three register nmos and pmos
  ## with byte-identical params.
  proc seed {cls} {
    variable classmap ; variable warned
    set cands [list $cls]
    foreach t [array names classmap] {
      if {$classmap($t) eq $cls} { lappend cands $t }
    }
    set best {} ; set winner {} ; set others {}
    foreach t [lsort -unique $cands] {
      set p [_params $t]
      if {$p eq {}} { continue }
      if {$winner eq {}} {
        set winner $t
        set best $p
        continue
      }
      if {$p ne $best} { lappend others $t }
    }
    if {[llength $others] && ![info exists warned($cls)]} {
      set warned($cls) 1
      _say "class \"$cls\" is seeded by types whose PDK lists disagree: \"$winner\" comes first and wins; [join $others {, }] ignored. Nothing is merged."
    }
    return $best
  }

  ## -----------------------------------------------------------------------
  ## RESOLUTION (DD-2): flavor beats class beats the PDK seed
  ## -----------------------------------------------------------------------
  ## The flavor key is a CELL-NAME GLOB matched with `string match -nocase`,
  ## which is the narrowing op_annot::_matches (op_annot.tcl:411) already
  ## performs over `getprop instance <n> cell::name`. Inventing a second flavor
  ## concept keyed on anything else would fork the narrowing.
  ## DD-2's own sentence: `nfet_01v8_lvt` with no entry of its own uses the
  ## `mos` lists.
  proc effective {cls listname {cellname {}}} {
    variable lists ; variable owned
    if {![_valid_list $listname]} { return {} }
    if {$cellname ne {}} {
      foreach k [lsort [array names owned]] {
        if {[lindex $k 0] ne "flavor"} { continue }
        if {[lindex $k 2] ne $listname} { continue }
        if {[string match -nocase [lindex $k 1] $cellname]} { return $lists($k) }
      }
    }
    if {[owns class $cls $listname]} { return [get_list class $cls $listname] }
    return [seed $cls]
  }

  ## -----------------------------------------------------------------------
  ## THE TWO TIERS
  ## -----------------------------------------------------------------------
  proc conf_path {which} {
    variable basename
    if {$which eq "user"} {
      if {![info exists ::USER_CONF_DIR]} { return {} }
      if {$::USER_CONF_DIR eq {}} { return {} }
      return [file join $::USER_CONF_DIR $basename]
    }
    if {$which eq "project"} { return [file join [pwd] .xschem $basename] }
    _say "unknown settings tier \"$which\"; expected `user` or `project`"
    return {}
  }

  ## Read the user-global file, then the project one; the project file wins per
  ## (scope,key,listname). Returns the LIST OF PATHS actually read, in read
  ## order. A missing file is the ordinary first-run case, not a failure
  ## (ase.tcl:2101 states it), and two tiers resolving to the SAME path are read
  ## once.
  proc load {} {
    set got {} ; set seen {}
    foreach which {user project} {
      set p [conf_path $which]
      if {$p eq {}} { continue }
      set n [file normalize $p]
      if {[lsearch -exact $seen $n] >= 0} { continue }
      lappend seen $n
      if {![file isfile $p]} { continue }
      if {[load_conf $p]} { lappend got $p }
    }
    return $got
  }

  ## -----------------------------------------------------------------------
  ## THE STRICT READER (DD-3)
  ## -----------------------------------------------------------------------
  proc load_conf {path} {
    if {![file isfile $path]} {
      _say "no settings file at $path"
      return 0
    }
    if {[catch {open $path r} fp]} {
      _say "cannot read $path: $fp"
      return 0
    }
    _chanconf $fp
    if {[catch {read $fp} data]} {
      catch {close $fp}
      _say "cannot read $path: $data"
      return 0
    }
    catch {close $fp}
    set touched {}
    set n 0
    foreach raw [split $data "\n"] {
      incr n
      ## The default `auto` translation already maps \r\n -> \n on read, so
      ## this is a no-op on the normal path; it keeps the parser correct if the
      ## channel is ever opened in a non-auto translation mode.
      set line [string trimright $raw "\r"]
      if {[string trim $line] eq {}} { continue }
      if {[string index [string trimleft $line] 0] eq "#"} { continue }
      _parse_line $path $n $line touched
    }
    return 1
  }

  ## ONE ROW. Nothing here runs, expands or substitutes anything the file says.
  proc _parse_line {path lineno line tvar} {
    variable classmap ; variable lists ; variable owned
    variable livelist ; variable version
    upvar 1 $tvar touched
    set f [regexp -inline -all {\S+} $line]
    set verb [lindex $f 0]
    set at "$path:$lineno"

    if {$verb eq "version"} {
      if {[llength $f] != 2} {
        _say "$at: `version` takes one number, got [llength $f] fields: $line"
        return 0
      }
      if {[lindex $f 1] ne $version} {
        _say "$at: settings file version [lindex $f 1] is not the version $version this xschem writes; reading it row by row anyway: $line"
        return 0
      }
      return 1
    }

    if {$verb eq "class"} {
      if {[llength $f] != 3} {
        _say "$at: `class` takes <type-token> <broad-class>, got [llength $f] fields: $line"
        return 0
      }
      set tok [lindex $f 1]
      set ck "class:$tok"
      if {[lsearch -exact $touched $ck] >= 0} {
        _say "$at: a second `class` row for \"$tok\" in one file; the later mapping wins: $line"
      } else {
        lappend touched $ck
      }
      set classmap($tok) [lindex $f 2]
      return 1
    }

    if {$verb eq "list" || $verb eq "param"} {
      set want [expr {$verb eq "list" ? 4 : 7}]
      if {[llength $f] != $want} {
        _say "$at: `$verb` takes $want whitespace-separated fields, got [llength $f]: $line"
        return 0
      }
      set scope [lindex $f 1]
      set key   [lindex $f 2]
      set ln    [lindex $f 3]
      if {![_valid_scope $scope]} {
        _say "$at: unknown scope \"$scope\"; expected `class` or `flavor`: $line"
        return 0
      }
      if {$ln eq $livelist} {
        _say "$at: the `$livelist` list is live from the simulator and is never stored in a settings file (ruling D-4): $line"
        return 0
      }
      if {![_valid_list $ln]} {
        _say "$at: unknown list name \"$ln\"; expected `annotation` or `summary`: $line"
        return 0
      }
      set t {}
      if {$verb eq "param"} {
        set t [_triple [list [lindex $f 4] [lindex $f 5] [lindex $f 6]]]
        if {$t eq {}} {
          _say "$at: kind \"[lindex $f 6]\" is not an integer: $line"
          return 0
        }
      }
      ## THE FIRST TOUCH OF A KEY IN THIS FILE CLEARS WHAT AN EARLIER TIER PUT
      ## THERE. That is what makes the project file WIN rather than append.
      set k [_key $scope $key $ln]
      if {[lsearch -exact $touched $k] < 0} {
        lappend touched $k
        set lists($k) {}
        set owned($k) 1
      }
      if {$verb eq "list"} { return 1 }
      set cur $lists($k)
      set hit -1
      set i 0
      foreach e $cur {
        if {[lindex $e 0] eq [lindex $t 0]} { set hit $i ; break }
        incr i
      }
      if {$hit >= 0} {
        _say "$at: a second entry for label \"[lindex $t 0]\" in $scope $key $ln; the later one replaces it in place: $line"
        set lists($k) [lreplace $cur $hit $hit $t]
      } else {
        lappend cur $t
        set lists($k) $cur
      }
      return 1
    }

    _say "$at: unknown keyword \"$verb\"; this file is data and nothing in it is ever run, so the line is skipped: $line"
    return 0
  }

  ## -----------------------------------------------------------------------
  ## THE WRITER (issue 0937): AN INTERRUPTED WRITE NEVER TRUNCATES
  ## -----------------------------------------------------------------------
  ## Copied in shape from ase::sim_write_conf / ase::sim_write_body
  ## (src/ase.tcl:1999-2036). `open <path> w` TRUNCATES before a single byte is
  ## written, so a failure anywhere after that would leave the user with an
  ## EMPTY settings file and, if the writer raised, no sentence about it either.
  ## The file the user has keeps whatever it had until a complete new one is
  ## ready to take its place. Returns 1, or 0 with a report; never raises.
  ##
  ## What is NOT copied is ase::sim_load_conf's partner reader, whose
  ## `uplevel #0 [list source $path]` is exactly what DD-3 forbids.
  proc _tmpname {path} { return $path.new }

  proc _chanconf {ch} {
    ## The encoding is pinned; the TRANSLATION is deliberately left at `auto`,
    ## which is what already handles CRLF.
    catch {fconfigure $ch -encoding utf-8}
    return {}
  }

  proc write_conf {{path {}}} {
    if {$path eq {}} { set path [conf_path project] }
    if {$path eq {}} {
      _say "no settings file path to write to"
      return 0
    }
    set dir [file dirname $path]
    if {![file isdirectory $dir]} {
      if {[catch {file mkdir $dir} err]} {
        _say "cannot save the parameter lists to $path: $err"
        return 0
      }
    }
    set tmp [_tmpname $path]
    set mode {}
    if {[file exists $path]} { catch {set mode [file attributes $path -permissions]} }
    if {[catch {open $tmp w} fp]} {
      _say "cannot save the parameter lists to $path: $fp. The file you already had is untouched."
      return 0
    }
    if {[catch {_chanconf $fp ; write_body $fp ; close $fp} err]} {
      catch {close $fp}
      catch {file delete -force $tmp}
      _say "cannot save the parameter lists to $path: $err. The file you already had is untouched."
      return 0
    }
    if {[catch {file rename -force $tmp $path} err]} {
      catch {file delete -force $tmp}
      _say "cannot save the parameter lists to $path: $err. The file you already had is untouched."
      return 0
    }
    ## A move replaces the file, and with it whatever permissions the user had
    ## put on their own copy.
    if {$mode ne {}} { catch {file attributes $path -permissions $mode} }
    return 1
  }

  ## The body, split out only so the writer above can wrap the whole of it plus
  ## the close in ONE catch.
  ##
  ## ONLY WHAT THE USER OWNS IS WRITTEN (D-7: nothing has to be checked in
  ## until something is changed), and the class map is written as OVERRIDES
  ## rather than whole, so a future change to the shipped default still reaches
  ## a project that never touched that token.
  ## EVERYTHING IS SORTED AND NOTHING IS STAMPED: no timestamp, no pid, no
  ## hostname, so writing the same store twice gives the same bytes and the
  ## file a team checks in diffs only when someone changed something.
  proc write_body {fp} {
    variable classmap ; variable defaultmap ; variable lists ; variable owned
    variable version
    puts $fp {# xschem operating-point parameter lists -- written by xschem.}
    puts $fp {# See doc/claude/specs/op_param_lists.md section 4.4.}
    puts $fp {#}
    puts $fp {# THIS FILE IS DATA AND xschem RUNS NOTHING THAT IS IN IT. A strict}
    puts $fp {# reader parses it row by row; a row it does not recognise is reported}
    puts $fp {# and skipped. That is what makes it safe to accept from a teammate.}
    puts $fp {#}
    puts $fp {#   class <type-token> <broad-class>}
    puts $fp {#   list  <scope> <key> <listname>}
    puts $fp {#   param <scope> <key> <listname> <label> <rawparam> <kind>}
    puts $fp {#}
    puts $fp {# scope:    class | flavor (a cell-name glob, matched case-insensitively)}
    puts $fp {# listname: annotation | summary}
    puts $fp {# kind:     0 -> i(dev[p]) , 1 -> bare dev[p] , 2 -> v(dev[p])}
    puts $fp "version $version"
    array set dflt $defaultmap
    foreach tok [lsort [array names classmap]] {
      if {[info exists dflt($tok)] && $dflt($tok) eq $classmap($tok)} { continue }
      puts $fp "class $tok $classmap($tok)"
    }
    foreach k [lsort [array names owned]] {
      set scope [lindex $k 0]
      set key   [lindex $k 1]
      set ln    [lindex $k 2]
      ## The `list` row is what lets an EMPTIED list survive a round trip
      ## instead of degrading to the PDK seed.
      puts $fp "list $scope $key $ln"
      foreach t $lists($k) {
        puts $fp "param $scope $key $ln [lindex $t 0] [lindex $t 1] [lindex $t 2]"
      }
    }
    return 1
  }

  ## -----------------------------------------------------------------------
  ## THE APPLY DOOR (invariant I5)
  ## -----------------------------------------------------------------------
  ## Write the user's lists into the descriptor registry, through
  ## op_annot::register and nothing else. Returns the list of types
  ## re-registered. A class the user owns nothing for is left strictly alone --
  ## applying the seed back over the PDK's own descriptor would be a no-op that
  ## still bumped the generation counter and still rewrote a dict this file
  ## does not own.
  ## The FLAVOR entries are deliberately not applied: a descriptor is keyed on
  ## the `type=` token and a flavor is a cell-name glob, so only the display
  ## path can narrow that far.
  ##
  ## ⚠ TWO FIELDS ARE WRITTEN, NOT ONE (rulings DD-4 and DD-6):
  ##   params  the UNION of the annotation and summary lists -- WHAT THE RUN
  ##           COMPUTES. op_annot::_cards_for builds the .save cards from it,
  ##           so a parameter the user only summarises is still in the raw, and
  ##           so is one she hid but a `derived` row still needs as an operand.
  ##   shown   the annotation half of that union -- WHAT THE SHEET DRAWS.
  ##           op_annot::text is its only reader. Without it a Delete has no
  ##           visible effect at all: `params` would keep growing and the sheet
  ##           would keep drawing every row of it.
  ##
  ## ⚠ THE SUBSET IS BUILT, NOT ASSERTED, AND THAT DISTINCTION IS THE WHOLE
  ## POINT. An earlier revision of this door copied the annotation list
  ## wholesale into `shown` and asserted in a comment that it was a subset of
  ## `params`; it was MEASURED FALSE on issue 1288's live duplicate-label door
  ## (`set_list class mos annotation {{A id 0} {A gm 1}}` is accepted with no
  ## report), _save_set's label dedup dropped the second row, and
  ## op_annot::_kind then raised on a label that was in no params list. So
  ## `shown` is DERIVED BY FILTERING the very list written to `params`: every
  ## element of `shown` is literally an element of `params`, for every input,
  ## whether or not 1288 is ever fixed.
  proc _apply_owns {c} {
    return [expr {[owns class $c annotation] || [owns class $c summary]}]
  }

  ## The union, in annotation-then-summary order, deduped BY LABEL with the
  ## annotation triple winning. Taken over `effective`, NEVER `get_list`: an
  ## UNOWNED list answers the PDK seed, so the union can only ever be a
  ## SUPERSET of what `params` already held and no PDK row is ever lost.
  proc _save_set {cls} {
    set out {}
    set seen [dict create]
    foreach ln {annotation summary} {
      foreach t [effective $cls $ln] {
        set l [lindex $t 0]
        if {[dict exists $seen $l]} { continue }
        dict set seen $l 1
        lappend out $t
      }
    }
    return $out
  }

  ## The display list: the union FILTERED by the annotation list's labels.
  ## Never a copy of the annotation list -- see the subset paragraph above.
  proc _show_set {cls saveset} {
    set keep [dict create]
    foreach t [effective $cls annotation] { dict set keep [lindex $t 0] 1 }
    set out {}
    foreach t $saveset {
      if {[dict exists $keep [lindex $t 0]]} { lappend out $t }
    }
    return $out
  }

  ## ⚠ TWO PASSES, AND THE FIRST ONE TOUCHES NOTHING (invariant I1: one seed,
  ## read once, before anything rewrites it). `_save_set` reaches the PDK seed
  ## through ::op_annot::descriptor and the second pass rewrites exactly those
  ## descriptors, so a single loop would let the first type applied become the
  ## seed the second type reads -- nmos sorts before pmos and both map to the
  ## same class, so it is reachable, not theoretical.
  proc apply {args} {
    variable classmap
    if {[llength $args]} {
      set cands $args
    } else {
      set cands [array names classmap]
    }
    set save [dict create]
    set show [dict create]
    set order {}
    foreach t [lsort -unique $cands] {
      set c [class $t]
      if {![_apply_owns $c]} { continue }
      if {[catch {::op_annot::descriptor $t} d]} { continue }
      if {$d eq {}} { continue }
      lappend order [list $t $c $d]
      if {![dict exists $save $c]} {
        set s [_save_set $c]
        dict set save $c $s
        dict set show $c [_show_set $c $s]
      }
    }
    set done {}
    foreach e $order {
      set t [lindex $e 0]
      set c [lindex $e 1]
      set d [lindex $e 2]
      if {[catch {dict set d params [dict get $save $c]} d2]} { continue }
      if {[catch {dict set d2 shown [dict get $show $c]} d3]} { continue }
      if {[catch {::op_annot::register $t $d3} err]} {
        _say "cannot register the parameter lists for symbol type \"$t\": $err"
        continue
      }
      lappend done $t
    }
    return $done
  }
}
