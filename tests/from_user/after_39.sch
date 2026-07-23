v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 80 -130 80 -120 {lab=#net1}
N 40 90 40 120 {lab=TRIANG}
N 80 90 80 130 {lab=CTRL1}
N -50 -130 -50 -20 {lab=#net1}
N 140 -20 220 -20 {lab=CTRL1}
N 220 20 220 120 {lab=TRIANG}
N 140 -20 140 130 {lab=CTRL1}
N -50 -130 80 -130 {lab=#net1}
N 40 120 220 120 {lab=TRIANG}
N 80 130 140 130 {lab=CTRL1}
N -60 0 -60 100 {lab=#net2}
N 60 -120 60 100 {lab=#net2}
N -60 100 60 100 {lab=#net2}
C {SANDBOX/solar_ctl} 70 30 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
