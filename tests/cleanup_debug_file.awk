#!/usr/bin/gawk -f



FNR == 1 {
    if (_filename_ != "")
        endfile(_filename_)
    _filename_ = FILENAME
    #print "processing: " FILENAME >"/dev/stderr"
    beginfile(FILENAME)
}

END  { endfile(_filename_) }

###### begin user code ########################

BEGIN{
}

function replace_pattern(old, new)
{
  if($0 ~ old) {
    gsub(old, new)
    found = 1
  }
}

{
  ## sample code to delete a line in file.
  # if($0 ~ /pattern_to_delete/) {found = 1; next}
  if($0 ~ /failed to create.*$/) {found = 1; next}
  replace_pattern("v {xschem version=.* file_version=.*}", "v {xschem version=2.9.5 file_version=1.1}")
  replace_pattern("drawing window ID.*$", "drawing window ID ***Removed***")
  replace_pattern("top window ID.*$", "top window ID ***Removed***")
  replace_pattern("created dir.*$", "created dir ***Removed***")
  ## ⚠ THE PER-RUN TOKENS (issue 1476), mapped back to their canonical spelling.
  ## Each run now owns its results root and its scratch root -- <case>/results.<pid>
  ## and <case>/.work.<pid> -- so two runs in one tree cannot wipe each other. But
  ## those paths are PRINTED into the results themselves, in at least four shapes
  ## measured on this tree:
  ##      process_options(): ... set XSCHEM_TMP_DIR {<workroot>/44.tmp}   (1898 files)
  ##      process_option(): file name given: <resdir>/simple_inv.sch      (5 files)
  ##      is_from_web(<resdir>/simple_inv.sch) = 0
  ##      .include <workroot>/31.d/model_test_ne555.txt                   (2 netlists)
  ## Left alone, every one of those files would differ from its own gold on the
  ## very next run -- same machine, same tree, nothing changed -- which is a
  ## harder failure than the machine-absolute paths already in here (those at
  ## least compare equal to themselves).
  ##
  ## Mapped rather than ***Removed***: the substitution restores exactly the text
  ## these lines had before the roots became per-run, so the file keeps its
  ## filename and its context, an existing baseline still matches, and the
  ## recorded path agrees with where publish_results finally puts the file.
  replace_pattern("results\\.[0-9]+", "results")
  replace_pattern("\\.work\\.[0-9]+", ".work")
  replace_pattern("undo_dirname.*$", "undo_dirname ***Removed***")
  replace_pattern("framewinID.*$", "framewinID ***Removed***")
  replace_pattern("framewin parentID.*$", "framewin parentID ***Removed***")
  replace_pattern("framewin child.*$", "framewin child ***Removed***")
  replace_pattern("resetwin.*$", "resetwin ***Removed***")
  replace_pattern("read_xschem_file.*$", "read_xschem_file ***Removed***")
  replace_pattern("EMERGENCY SAVE DIR dir.*$", "EMERGENCY SAVE DIR dir ***Removed***")
  replace_pattern("tcleval[:(:][:):]: evaluation of script: netlist.*$", "tcleval(): evaluation of script: netlist ***Removed***")
  replace_pattern("global_verilog_netlist[:(:][:):]: opening.*$", "global_verilog_netlist(): opening ***Removed***")
  replace_pattern("global_vhdl_netlist[:(:][:):]: opening.*$", "global_vhdl_netlist(): opening ***Removed***")
  replace_pattern("global_tedax_netlist[:(:][:):]: opening.*$", "global_tedax_netlist(): opening***Removed***")
  replace_pattern("global_spice_netlist[:(:][:):]: opening.*$", "global_spice_netlist(): opening ***Removed***")
  replace_pattern("l_s_d[:(:][:):]: fopen.*$", "load_sym_def(): fopen ***Removed***")
  replace_pattern("l_s_d[:(:][:):]: fclose.*$", "load_sym_def(): fclose ***Removed***")
  replace_pattern("drawing string: str=.*$", "drawing string: str=***Removed***")
  replace_pattern("zoom_full[:(:][:):]:.*$", "zoom_full(): ***Removed***")
  replace_pattern("bbox[:(:][:):]: bbox=.*$", "bbox(): bbox=***Removed***")
  replace_pattern("draw_string()[:(:][:):]:.*$", "draw_string(): ***Removed***")
  replace_pattern("find_best_color.*$", "find_best_color ***Removed***")
  replace_pattern("trim_wires.*$", "trim_wires ***Removed***")
  replace_pattern("symbol_bbox.*$", "symbol_bbox ***Removed***")
  replace_pattern("symbol bbox.*$", "symbol bbox ***Removed***")
  __a[__lines++] = $0
}

###### end  user code  ########################

function beginfile(f)
{
 __lines=0
 found=0
}

function endfile(f,   i)
{
 if(found)  {
   #print "patching: " f >"/dev/stderr"
   for(i=0;i<__lines;i++)
   {
    print __a[i] > f
   }
   close(f)
 }
}

