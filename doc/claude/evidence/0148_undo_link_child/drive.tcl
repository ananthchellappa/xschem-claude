set NAND2 /home/analog/dev/xschem-claude/xschem_library/examples/nand2.sch

  xschem undo_type disk
  xschem load $NAND2
  set n0 [xschem get instances]
  xschem select_all ; xschem delete
  set n1 [xschem get instances]
  xschem undo            ;# disk pop_undo(): read-back + link + autosave
  set n2 [xschem get instances]
  xschem redo
  set n3 [xschem get instances]
  xschem undo
  set n4 [xschem get instances]
  puts "COUNTS $n0 $n1 $n2 $n3 $n4"
  # setprop on the restored buffer must RETURN (bounded), success or error:
  set rc [catch {xschem setprop instance 0 selflogtok selflogval} res]
  puts "SETPROP rc=$rc res=$res"
  puts "CHILD_DONE"
  flush stdout
  exit 0

