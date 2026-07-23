v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 90 -150 90 -140 {lab=#net1}
N 50 70 50 120 {lab=TRIANG}
N 90 70 90 130 {lab=CTRL1}
N -60 -140 -60 0 {lab=#net2}
N -50 -150 -50 -20 {lab=#net1}
N 140 -20 220 -20 {lab=CTRL1}
N 220 20 220 120 {lab=TRIANG}
N 140 -20 140 130 {lab=CTRL1}
N -60 -140 70 -140 {lab=#net2}
N -50 -150 90 -150 {lab=#net1}
N 50 120 220 120 {lab=TRIANG}
N 90 130 140 130 {lab=CTRL1}
C {SANDBOX/solar_ctl} 80 10 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
