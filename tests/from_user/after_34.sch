v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 120 -140 120 -130 {lab=#net1}
N 140 -150 140 -130 {lab=#net2}
N 90 80 90 90 {lab=TRIANG}
N 140 -20 140 100 {lab=CTRL1}
N -60 -140 -60 0 {lab=#net1}
N -50 -150 -50 -20 {lab=#net2}
N 220 20 220 90 {lab=TRIANG}
N 140 -20 220 -20 {lab=CTRL1}
N -60 -140 120 -140 {lab=#net1}
N -50 -150 140 -150 {lab=#net2}
N 90 90 220 90 {lab=TRIANG}
N 90 80 100 80 {lab=TRIANG}
C {SANDBOX/solar_ctl} 130 20 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
