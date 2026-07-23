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
N 110 -130 110 0 {lab=#net1}
N 130 -130 130 -20 {lab=#net2}
N 90 20 90 80 {lab=TRIANG}
N 130 80 220 -20 {lab=CTRL1}
N -60 0 110 0 {lab=#net1}
N -50 -20 130 -20 {lab=#net2}
N 90 20 220 20 {lab=TRIANG}
C {SANDBOX/solar_ctl} 120 20 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
