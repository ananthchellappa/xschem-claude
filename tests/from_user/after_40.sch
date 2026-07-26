v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 150 -120 150 -110 {lab=#net1}
N 110 100 110 120 {lab=TRIANG}
N 150 100 150 130 {lab=CTRL1}
N -50 -120 -50 -20 {lab=#net1}
N 140 -20 220 -20 {lab=CTRL1}
N 220 20 220 120 {lab=TRIANG}
N 140 -20 140 130 {lab=CTRL1}
N -60 -130 130 -130 {lab=#net2}
N -50 -120 150 -120 {lab=#net1}
N 110 120 220 120 {lab=TRIANG}
N 140 130 150 130 {lab=CTRL1}
N -60 -130 -60 0 {lab=#net2}
N 130 -130 130 -110 {lab=#net2}
C {SANDBOX/solar_ctl} 140 40 1 0 {name=x1}
C {devices/lab_pin} 220 20 0 1 {name=l0 lab=TRIANG text_size_0=0.2}
C {devices/lab_pin} 220 -20 0 1 {name=l1 lab=CTRL1 text_size_0=0.2}
