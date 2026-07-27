v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
T {Creating a plot with capacitor charge delay vs transistor width} 70 -1030 0 0 1 1 {}
T {tcleval([xschem raw switch $netlist_dir/delay.raw foo
  set table "W,Del"
  foreach w [xschem raw values w] del [xschem raw values del] \{
    append table \\\\n [format \\%2d $w] \{,\} [to_eng $del]
  \}
  xschem raw switch_back
  return [tabulate $table ,]])
} 510 -950 0 1 0.3 0.3 {floater=1 font=monospace layer=15}
N 230 -780 230 -690 {
lab=B}
N 230 -630 230 -580 {
lab=0}
N 90 -580 230 -580 {
lab=0}
N 90 -630 90 -580 {
lab=0}
N 230 -810 290 -810 {
lab=VCC}
N 170 -810 190 -810 {
lab=0}
N 90 -410 90 -390 {
lab=0}
N 90 -500 90 -470 {
lab=VCC}
N 230 -910 230 -840 {
lab=A}
N 90 -910 230 -910 {
lab=A}
N 90 -910 90 -690 {
lab=A}
N 330 -780 330 -690 {
lab=B}
N 230 -780 330 -780 {
lab=B}
N 330 -630 330 -580 {
lab=0}
N 230 -580 330 -580 {
lab=0}
C {devices/vsource} 90 -660 0 0 {name=V1 value="dc 3 pwl 0 0 1n 3" savecurrent=false}
C {devices/capa} 230 -660 0 0 {name=C1
m=1
value=10p
footprint=1206
device="ceramic capacitor"}
C {devices/lab_pin} 90 -580 0 0 {name=p1 sig_type=std_logic lab=0}
C {devices/lab_pin} 90 -750 0 0 {name=p2 sig_type=std_logic lab=A}
C {devices/lab_pin} 230 -750 0 0 {name=p3 sig_type=std_logic lab=B}
C {sky130_fd_pr/pfet_g5v0d10v5} 210 -810 0 0 {name=M1
W=W
L=1
nf=1
mult=1
model=pfet_g5v0d10v5
spiceprefix=X
}
C {devices/lab_pin} 170 -810 0 0 {name=p4 sig_type=std_logic lab=0}
C {devices/vsource} 90 -440 0 0 {name=V2 value=3 savecurrent=false}
C {devices/lab_pin} 90 -390 0 0 {name=p5 sig_type=std_logic lab=0}
C {devices/lab_pin} 90 -500 0 0 {name=p6 sig_type=std_logic lab=VCC}
C {devices/lab_pin} 290 -810 0 1 {name=p7 sig_type=std_logic lab=VCC}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/res} 330 -660 0 0 {name=R1
value=100k
footprint=1206
device=resistor
m=1}
