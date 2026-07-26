v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
T {x1/x4} 30 -70 0 0 0.3 0.3 {font="Liberation Mono"}
T {This is a bookmark. Select it and
do CTRL-ALT-D. To create such a bookmark,
when you return to top with AlT-E, have
nothing selected and do CTRL-ALT-D} 0 -100 0 0 0.1 0.1 {font="DejaVu Sans"}
N -60 -130 120 -130 {lab=#net1}
N 140 -140 140 -130 {lab=#net2}
N 100 50 100 80 {lab=TRIANG}
N -60 -130 -60 0 {lab=#net1}
N -50 -140 140 -140 {lab=#net2}
N -50 -140 -50 -20 {lab=#net2}
N 100 50 220 50 {lab=TRIANG}
N 220 20 220 50 {lab=TRIANG}
N 140 -20 140 80 {lab=CTRL1}
N 140 -20 220 -20 {lab=CTRL1}
N 80 50 100 50 {lab=TRIANG}
C {SANDBOX/solar_ctl} 130 20 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
