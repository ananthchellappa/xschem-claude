v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 40 50 40 60 {lab=TRIANG}
N 80 50 80 70 {lab=CTRL1}
N -50 -180 -50 -20 {lab=#net1}
N 140 -20 220 -20 {lab=CTRL1}
N 220 20 220 60 {lab=TRIANG}
N 140 -20 140 70 {lab=CTRL1}
N 60 -170 60 -160 {lab=#net2}
N -60 -170 60 -170 {lab=#net2}
N 40 60 220 60 {lab=TRIANG}
N 80 70 140 70 {lab=CTRL1}
N -50 -180 80 -180 {lab=#net1}
N 80 -180 80 -160 {lab=#net1}
N -60 -170 -60 0 {lab=#net2}
C {SANDBOX/solar_ctl} 70 -10 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
