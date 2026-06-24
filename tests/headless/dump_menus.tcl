puts "--- DUMPING CASCADES ---"
for {set i 0} {$i <= [.menubar index end]} {incr i} {
  catch {
    set label [.menubar entrycget $i -label]
    set menuw [.menubar entrycget $i -menu]
    puts "Cascade $i: $label -> $menuw"
  }
}
exit 0
