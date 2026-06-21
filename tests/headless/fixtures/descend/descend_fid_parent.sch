v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
L 4 -160 -160 -60 -160 {}
B 8 -160 120 -60 160 {}
P 7 4 0 100 60 100 60 160 0 100 {}
A 5 220 -120 30 0 360 {}
T {fidelity parent} -160 -190 0 0 0.3 0.3 {}
N -100 0 0 0 {lab=INA}
N 0 0 0 -60 {}
N 0 0 100 0 {}
N 300 0 400 0 {lab=OUTB}
C {descend_child.sym} 0 0 0 0 {name=x1}
C {descend_child.sym} 400 0 0 0 {name=x2}
C {lab_pin.sym} -100 0 0 0 {name=l1 lab=INA}
C {lab_pin.sym} 300 0 0 0 {name=l2 lab=OUTB}
