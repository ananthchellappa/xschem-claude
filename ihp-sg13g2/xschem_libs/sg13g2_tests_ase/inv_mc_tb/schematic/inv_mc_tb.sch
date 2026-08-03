v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {used to run ngspice mc simulation in parallel} 1440 -1000 0 0 0.3 0.3 {layer=11}
T {used to check OP, AC and TRAN} 920 -1000 0 0 0.3 0.3 {layer=11}
T {Ctrl-Click to execute launcher} 170 -910 0 0 0.3 0.3 {layer=11}
T {.save file can be created with IHP->"Create FET and BIP .save file"} 170 -810 0 0 0.3 0.3 {layer=11}
T {each printed value will be saved in csv file} 1700 -650 0 0 0.3 0.3 {layer=11}
T {_stat ... with staticstial modelling (process) without mismatch!} 150 -750 0 0 0.3 0.3 {layer=11}
T {set num_threads to 1 for small circuits} 1700 -880 0 0 0.3 0.3 {layer=11}
N 180 -270 180 -250 {lab=vdd}
N 180 -190 180 -170 {lab=GND}
N 550 -400 610 -400 {lab=vdd}
N 610 -460 610 -400 {lab=vdd}
N 550 -460 610 -460 {lab=vdd}
N 550 -300 610 -300 {lab=GND}
N 610 -300 610 -230 {lab=GND}
N 550 -230 610 -230 {lab=GND}
N 550 -270 550 -230 {lab=GND}
N 550 -460 550 -430 {lab=vdd}
N 550 -350 550 -330 {lab=inv_out}
N 450 -350 450 -300 {lab=inv_in}
N 750 -350 750 -320 {lab=inv_out}
N 550 -350 750 -350 {lab=inv_out}
N 550 -370 550 -350 {lab=inv_out}
N 720 -230 750 -230 {lab=GND}
N 750 -230 780 -230 {lab=GND}
N 720 -280 720 -230 {lab=GND}
N 750 -280 750 -230 {lab=GND}
N 780 -280 780 -230 {lab=GND}
N 310 -190 310 -170 {lab=GND}
N 310 -350 310 -250 {lab=in}
N 450 -350 470 -350 {lab=inv_in}
N 450 -400 450 -350 {lab=inv_in}
N 530 -350 550 -350 {lab=inv_out}
N 450 -300 510 -300 {lab=inv_in}
N 450 -400 510 -400 {lab=inv_in}
N 400 -350 450 -350 {lab=inv_in}
N 310 -350 340 -350 {lab=in}
C {devices/title} 245 -55 0 0 {name=l5 author="Patrick Fath"}
C {devices/vsource} 180 -220 0 0 {name=VDD1 value=1.5}
C {devices/lab_wire} 180 -270 0 1 {name=p1 sig_type=std_logic lab=vdd}
C {devices/gnd} 180 -170 0 0 {name=l1 lab=GND}
C {sg13g2_pr/sg13_lv_nmos} 530 -300 0 0 {name=M1
l=0.13u
w=0.15u
ng=1
m=1
model=sg13_lv_nmos
spiceprefix=X
}
C {sg13g2_pr/sg13_lv_pmos} 530 -400 0 0 {name=M2
l=0.13u
w=0.15u
ng=1
m=1
model=sg13_lv_pmos
spiceprefix=X
}
C {devices/gnd} 550 -230 0 0 {name=l2 lab=GND}
C {devices/lab_wire} 550 -460 0 1 {name=p2 sig_type=std_logic lab=vdd}
C {sg13g2_pr/sg13_lv_nmos} 750 -300 1 0 {name=M3
l=0.13u
w=0.15u
ng=1
m=1
model=sg13_lv_nmos
spiceprefix=X
}
C {devices/gnd} 720 -230 0 0 {name=l3 lab=GND}
C {devices/lab_wire} 450 -350 0 0 {name=p3 sig_type=std_logic lab=inv_in}
C {devices/lab_wire} 750 -350 0 1 {name=p4 sig_type=std_logic lab=inv_out}
C {devices/vsource} 310 -220 0 0 {name=VIN1 value="dc 0.75 ac 1 sin(0.75 1m 100Meg)"}
C {devices/gnd} 310 -170 0 0 {name=l4 lab=GND}
C {devices/res} 500 -350 1 0 {name=R1
value=100Meg
footprint=1206
device=resistor
m=1}
C {devices/lab_wire} 310 -350 0 0 {name=p5 sig_type=std_logic lab=in}
C {sg13g2_pr/annotate_fet_params} 630 -570 0 0 {name=annot1 ref=M2}
C {sg13g2_pr/annotate_fet_params} 640 -200 0 0 {name=annot2 ref=M1}
C {sg13g2_pr/cap_cmim} 370 -350 1 0 {name=C1
model=cap_cmim
w=10.0e-6
l=10.0e-6
m=7
spiceprefix=X}
