v {xschem version=3.4.5 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
N -300 60 -300 80 {
lab=GND}
N -300 -10 -300 0 {
lab=#net1}
N -40 20 -40 80 {
lab=GND}
N -170 -80 -170 -40 {
lab=E1}
N -40 -80 -40 -40 {
lab=#net2}
N -170 -80 -140 -80 {
lab=E1}
N -80 -80 -40 -80 {
lab=#net2}
N -300 -10 -210 -10 {
lab=#net1}
C {devices/gnd} -170 80 0 0 {name=l1 lab=GND}
C {devices/gnd} -300 80 0 0 {name=l2 lab=GND}
C {devices/gnd} -40 80 0 0 {name=l3 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/ammeter} -110 -80 1 0 {name=Ve}
C {devices/ammeter} -300 30 0 0 {name=Vb}
C {devices/ammeter} -170 50 0 0 {name=Vc}
C {devices/isource} -40 -10 2 0 {name=I0 value=1u}
C {devices/lab_pin} -170 -60 0 0 {name=p1 sig_type=std_logic lab=E1}
C {sg13g2_pr/pnpMPA} -190 -10 0 0 {name=Q1
model=pnpMPA
spiceprefix=X
w=1.0e-6
l=2.0e-6
m=1
}
