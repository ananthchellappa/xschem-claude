v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
L 4 -340 -180 -320 -220 {}
L 4 -320 -220 -300 -180 {}
L 4 -300 -180 -280 -220 {}
L 4 -280 -220 -260 -180 {}
L 4 -260 -180 -240 -220 {}
L 4 -240 -220 -220 -180 {}
L 4 90 -100 100 -100 {}
L 4 100 -140 100 -100 {}
L 4 100 -140 120 -140 {}
L 4 120 -140 120 -100 {}
L 4 120 -100 140 -100 {}
L 4 140 -140 140 -100 {}
L 4 140 -140 160 -140 {}
L 4 160 -140 160 -100 {}
L 4 160 -100 180 -100 {}
L 4 180 -140 180 -100 {}
L 4 180 -140 200 -140 {}
L 4 200 -140 200 -100 {}
L 4 200 -100 210 -100 {}
N -340 -90 -340 -70 {
lab=0}
N -340 -160 -340 -150 {
lab=TRIANG}
N -340 -160 -180 -160 {
lab=TRIANG}
N -130 -50 -130 30 {
lab=LEVEL}
N -180 -160 -180 -110 {
lab=TRIANG}
N -180 -110 -60 -110 {
lab=TRIANG}
N -450 0 -350 0 {
lab=LED}
N -420 60 -350 60 {lab=REF}
N 60 -80 110 -80 {
lab=CTRL1}
N -230 30 -130 30 {
lab=LEVEL}
N -130 -50 -60 -50 {
lab=LEVEL}
N -130 30 -120 30 {lab=LEVEL}
N -180 -190 -170 -190 {lab=TRIANG}
N -180 -190 -180 -160 {lab=TRIANG}
C {devices/vsource} -340 -120 0 0 {name=Vtriang value="pulse 0 1 0 2u 2u 1f 4u"}
C {devices/lab_pin} -340 -70 0 0 {name=l11  lab=0 }
C {devices/lab_pin} -180 -160 0 1 {name=l14
lab=TRIANG }
C {ngspice/comp_ngspice} -290 30 0 0 {name=x3 GAIN=100 OFFSET=0.5 AMPLITUDE=1 ROUT=7k COUT=1n
select=AMPLITUDE}
C {devices/lab_pin} -120 30 0 1 {name=l18  lab=LEVEL}
C {ngspice/comp_ngspice} 0 -80 0 0 {name=x4 GAIN=100 OFFSET=0.5 AMPLITUDE=1 ROUT=1 COUT=1p
select=OFFSET}
C {devices/spice_probe} -100 -110 0 1 {name=p4 analysis=tran}
C {devices/spice_probe} -140 30 0 1 {name=p5 analysis=tran}
C {xschem_library/devices/ipin.sym} -450 0 0 0 {name=p1 lab="LED"}
C {xschem_library/devices/ipin.sym} -420 60 0 0 {name=p2 lab="REF"}
C {xschem_library/devices/opin.sym} 110 -80 0 0 {name=p3 lab="CTRL1"}
C {xschem_library/devices/opin.sym} -170 -190 0 0 {name=p6 lab="TRIANG"}
