v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 80 -160 80 -90 {lab=#net1}
N 40 120 40 150 {lab=TRIANG}
N 80 120 80 160 {lab=CTRL1}
N 140 -20 220 -20 {lab=CTRL1}
N 60 -100 60 -90 {lab=#net2}
N -50 -160 -50 -20 {lab=#net1}
N 40 150 220 150 {lab=TRIANG}
N -60 -100 60 -100 {lab=#net2}
N -50 -160 80 -160 {lab=#net1}
N 80 160 140 160 {lab=CTRL1}
N 220 20 220 150 {lab=TRIANG}
N 140 -20 140 160 {lab=CTRL1}
N -60 -100 -60 0 {lab=#net2}
C {SANDBOX/solar_ctl} 70 60 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
