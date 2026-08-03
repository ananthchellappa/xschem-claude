v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -20 80 -20 140 {
lab=GND}
N -20 50 30 50 {
lab=GND}
N -90 50 -60 50 {
lab=Vgs1}
N -20 0 -20 20 {
lab=Vgs1}
N 240 80 240 140 {
lab=GND}
N 240 50 290 50 {
lab=GND}
N 290 50 290 140 {
lab=GND}
N 170 50 200 50 {
lab=Vgs2}
N 640 80 640 140 {
lab=GND}
N 640 50 690 50 {
lab=GND}
N 690 50 690 140 {
lab=GND}
N 560 50 600 50 {
lab=Vgs3}
N 640 0 640 20 {
lab=Vgs3}
N 870 80 870 140 {
lab=GND}
N 870 50 920 50 {
lab=GND}
N 920 50 920 140 {
lab=GND}
N 790 50 830 50 {
lab=Vgs4}
N -90 0 -20 0 {
lab=Vgs1}
N -90 0 -90 50 {
lab=Vgs1}
N -20 -120 -20 -100 {
lab=GND}
N -20 -40 -20 0 {
lab=Vgs1}
N 240 -120 240 -100 {
lab=GND}
N 240 -10 240 20 {
lab=Vgs2}
N 640 -30 640 0 {
lab=Vgs3}
N 640 -110 640 -90 {
lab=GND}
N 870 -110 870 -90 {
lab=GND}
N 870 -10 870 20 {
lab=Vgs4}
N 560 0 560 50 {
lab=Vgs3}
N 560 0 640 0 {
lab=Vgs3}
N 790 -10 790 50 {
lab=Vgs4}
N 790 -10 870 -10 {
lab=Vgs4}
N 170 -10 170 50 {
lab=Vgs2}
N 170 -10 240 -10 {
lab=Vgs2}
N 30 50 30 140 {
lab=GND}
N -130 50 -90 50 {
lab=Vgs1}
N 530 50 560 50 {
lab=Vgs3}
N 760 50 790 50 {
lab=Vgs4}
N 870 -30 870 -10 {
lab=Vgs4}
N 130 50 170 50 {
lab=Vgs2}
N 240 -40 240 -10 {
lab=Vgs2}
C {devices/gnd} -20 140 0 0 {name=l1 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/lab_pin} -130 50 0 0 {name=p2 sig_type=std_logic lab=Vgs1}
C {devices/gnd} 240 140 0 0 {name=l6 lab=GND}
C {devices/gnd} 290 140 0 0 {name=l7 lab=GND}
C {devices/lab_pin} 130 50 0 0 {name=p5 sig_type=std_logic lab=Vgs2}
C {devices/gnd} 640 140 0 0 {name=l8 lab=GND}
C {devices/gnd} 690 140 0 0 {name=l9 lab=GND}
C {devices/lab_pin} 530 50 0 0 {name=p7 sig_type=std_logic lab=Vgs3}
C {devices/gnd} 870 140 0 0 {name=l10 lab=GND}
C {devices/gnd} 920 140 0 0 {name=l11 lab=GND}
C {devices/lab_pin} 760 50 0 0 {name=p9 sig_type=std_logic lab=Vgs4}
C {sg13g2_pr/sg13_lv_pmos} 620 50 2 1 {name=M3
l=1.0u
w=2.0u
ng=1
m=1
model=sg13_lv_pmos
spiceprefix=X
}
C {sg13g2_pr/sg13_hv_pmos} 850 50 2 1 {name=M4
l=1.0u
w=2.0u
ng=1
m=1
model=sg13_hv_pmos
spiceprefix=X
}
C {devices/isource} -20 -70 0 0 {name=I0 value=10u}
C {devices/gnd} -20 -120 2 0 {name=l2 lab=GND}
C {devices/isource} 240 -70 0 0 {name=I1 value=10u}
C {devices/gnd} 240 -120 2 0 {name=l3 lab=GND}
C {devices/isource} 640 -60 2 0 {name=I2 value=10u}
C {devices/isource} 870 -60 2 0 {name=I3 value=10u}
C {devices/gnd} 640 -110 2 0 {name=l12 lab=GND}
C {devices/gnd} 870 -110 2 0 {name=l13 lab=GND}
C {devices/gnd} 30 140 0 0 {name=l14 lab=GND}
C {sg13g2_pr/sg13_hv_nmos} 220 50 0 0 {name=M1
l=0.45u
w=1.0u
ng=1
m=1
model=sg13_hv_nmos
spiceprefix=X
}
C {sg13g2_pr/sg13_lv_nmos} -40 50 0 0 {name=M2
l=0.45u
w=1.0u
ng=1
m=1
model=sg13_lv_nmos
spiceprefix=X
}
