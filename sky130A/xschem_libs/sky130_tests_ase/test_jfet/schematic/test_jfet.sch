v {xschem version=3.4.0 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
N 340 -300 340 -250 {
lab=#net1}
N 340 -190 340 -110 {
lab=GND}
N 260 -220 300 -220 {
lab=#net2}
N 150 -220 200 -220 {
lab=G}
N 340 -420 340 -360 {
lab=D}
N 260 -700 300 -700 {
lab=#net3}
N 150 -700 200 -700 {
lab=G1}
N 150 -700 150 -640 {
lab=G1}
N 340 -510 340 -490 {
lab=GND}
N 150 -580 150 -560 {
lab=GND}
N 340 -610 340 -570 {
lab=D1}
N 340 -830 340 -730 {
lab=GND}
C {devices/title} 160 -30 0 0 {name=l9 
author="tcleval(Stefan Schippers[
  if \{$show_pin_net_names == 0\} \{
    set show_pin_net_names 1
    xschem update_all_sym_bboxes
  \}]
)"}
C {devices/njfet} 320 -220 0 0 {name=J1 model=2N3459 area=1 m=1
}
C {devices/lab_pin} 150 -220 0 0 {name=p1 sig_type=std_logic lab=G}
C {devices/lab_pin} 340 -420 0 0 {name=p2 sig_type=std_logic lab=D}
C {devices/lab_pin} 340 -110 0 0 {name=p3 sig_type=std_logic lab=GND}
C {devices/noconn} 340 -140 0 0 {name=l1}
C {devices/noconn} 340 -390 0 0 {name=l2}
C {devices/noconn} 180 -220 1 0 {name=l3}
C {devices/ammeter} 230 -220 1 0 {name=Vgate}
C {devices/ammeter} 340 -330 0 0 {name=Vdrain}
C {devices/pjfet} 320 -700 0 0 {name=J2 model=2N2609 area=1 m=1
}
C {devices/lab_pin} 150 -700 0 0 {name=p4 sig_type=std_logic lab=G1}
C {devices/lab_pin} 340 -830 0 0 {name=p6 sig_type=std_logic lab=GND}
C {devices/ammeter} 230 -700 1 0 {name=Vgate1}
C {devices/ammeter} 340 -640 0 0 {name=Vdrain1}
C {devices/vcvs} 340 -540 0 0 {name=E1 value=-1}
C {devices/lab_pin} 300 -520 0 0 {name=p7 sig_type=std_logic lab=GND}
C {devices/lab_pin} 300 -560 0 0 {name=p8 sig_type=std_logic lab=D}
C {devices/lab_pin} 340 -580 0 0 {name=p5 sig_type=std_logic lab=D1}
C {devices/vcvs} 150 -610 0 0 {name=E2 value=-1}
C {devices/lab_pin} 110 -590 0 0 {name=p9 sig_type=std_logic lab=GND}
C {devices/lab_pin} 110 -630 0 0 {name=p10 sig_type=std_logic lab=G}
C {devices/lab_pin} 340 -490 0 0 {name=p11 sig_type=std_logic lab=GND}
C {devices/lab_pin} 150 -560 0 0 {name=p12 sig_type=std_logic lab=GND}
