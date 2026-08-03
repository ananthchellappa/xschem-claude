v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -0 75 110 75 {lab=GND}
N 110 272.5 110 280 {lab=GND}
N -0 220 0 272.5 {lab=GND}
N 0 272.5 110 272.5 {lab=GND}
N 40 10 40 105 {lab=#net1}
N 110 240 110 272.5 {lab=GND}
N -155 105 -40 105 {lab=#net2}
N 40 10 170 10 {lab=#net1}
N 110 240 170 240 {lab=GND}
N 110 75 110 240 {lab=GND}
N 170 215 170 240 {lab=GND}
N -155 220 -0 220 {lab=GND}
N -155 192.5 -155 220 {lab=GND}
N -0 135 -0 220 {lab=GND}
N -155 105 -155 140 {lab=#net2}
N 170 10 170 160 {lab=#net1}
C {devices/gnd} 110 280 0 0 {name=l2 lab=GND}
C {sg13g2_pr/sg13_svaricap} 0 105 0 0 {name=C1 model=sg13_hv_svaricap W=3.74e-6 L=0.3e-6 Nx=1 spiceprefix=X}
C {devices/vsource} 170 187.5 0 0 {name=V1 value="dc 0 ac 0 pulse(-2.5, 2.5, 0, 10u, 100p, 1u, 11u ) "}
C {devices/vsource} -155 167.5 0 0 {name=V2 value="dc 0 ac 0 pulse(-2.5, 2.5, 0, 10u, 100p, 1u, 11u ) "}
