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
N -60 0 -30 0 {lab=#net1}
N -50 -20 -30 -20 {lab=#net2}
N 180 20 220 20 {lab=TRIANG}
N 180 -20 220 -20 {}
C {SANDBOX/solar_ctl} 120 -10 0 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
