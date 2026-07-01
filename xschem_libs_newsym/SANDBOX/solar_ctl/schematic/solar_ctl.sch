v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
L 4 -520 -370 -500 -410 {}
L 4 -500 -410 -480 -370 {}
L 4 -480 -370 -460 -410 {}
L 4 -460 -410 -440 -370 {}
L 4 -440 -370 -420 -410 {}
L 4 -420 -410 -400 -370 {}
L 4 -90 -290 -80 -290 {}
L 4 -80 -330 -80 -290 {}
L 4 -80 -330 -60 -330 {}
L 4 -60 -330 -60 -290 {}
L 4 -60 -290 -40 -290 {}
L 4 -40 -330 -40 -290 {}
L 4 -40 -330 -20 -330 {}
L 4 -20 -330 -20 -290 {}
L 4 -20 -290 0 -290 {}
L 4 0 -330 0 -290 {}
L 4 0 -330 20 -330 {}
L 4 20 -330 20 -290 {}
L 4 20 -290 30 -290 {}
N -520 -280 -520 -260 {
lab=0}
N -520 -350 -520 -340 {
lab=TRIANG}
N -520 -350 -360 -350 {
lab=TRIANG}
N -310 -240 -310 -160 {
lab=LEVEL}
N -360 -350 -360 -300 {
lab=TRIANG}
N -360 -300 -240 -300 {
lab=TRIANG}
N -630 -190 -530 -190 {
lab=LED}
N -600 -130 -530 -130 {lab=REF}
N -120 -270 -70 -270 {
lab=CTRL1}
N -410 -160 -310 -160 {
lab=LEVEL}
N -310 -240 -240 -240 {
lab=LEVEL}
N -310 -160 -300 -160 {lab=LEVEL}
N -360 -380 -350 -380 {lab=TRIANG}
N -360 -380 -360 -350 {lab=TRIANG}
C {devices/vsource} -520 -310 0 0 {name=Vtriang value="pulse 0 1 0 2u 2u 1f 4u"}
C {devices/lab_pin} -520 -260 0 0 {name=l11  lab=0 }
C {devices/lab_pin} -360 -350 0 1 {name=l14
lab=TRIANG }
C {ngspice/comp_ngspice} -470 -160 0 0 {name=x3 GAIN=100 OFFSET=0.5 AMPLITUDE=1 ROUT=7k COUT=1n
select=AMPLITUDE}
C {devices/lab_pin} -300 -160 0 1 {name=l18  lab=LEVEL}
C {ngspice/comp_ngspice} -180 -270 0 0 {name=x4 GAIN=100 OFFSET=0.5 AMPLITUDE=1 ROUT=1 COUT=1p
select=OFFSET}
C {devices/spice_probe} -280 -300 0 1 {name=p4 analysis=tran}
C {devices/spice_probe} -320 -160 0 1 {name=p5 analysis=tran}
C {xschem_library/devices/ipin.sym} -630 -190 0 0 {name=p1 lab="LED"}
C {xschem_library/devices/ipin.sym} -600 -130 0 0 {name=p2 lab="REF"}
C {xschem_library/devices/opin.sym} -70 -270 0 0 {name=p3 lab="CTRL1"}
C {xschem_library/devices/opin.sym} -350 -380 0 0 {name=p6 lab="TRIANG"}
