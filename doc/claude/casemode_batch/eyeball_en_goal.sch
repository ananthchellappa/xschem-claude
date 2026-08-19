v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -190 200 -190 {}
N 0 -190 0 -130 {}
N 200 -130 200 -90 {}
C {devices/vsource} 0 -100 0 0 {name=V1 value=1.5}
C {devices/gnd} 0 -70 0 0 {name=l1 lab=0}
C {devices/res} 200 -160 0 0 {name=R1 value=1k}
C {devices/res} 200 -60 0 0 {name=R2 value=1k}
C {devices/gnd} 200 -30 0 0 {name=l2 lab=0}
C {devices/lab_pin} 100 -190 0 0 {name=p1 lab=EN}
C {devices/lab_pin} 200 -110 0 0 {name=p2 lab=OUT}
C {devices/code_shown} 460 -190 0 0 {name=STIMULI only_toplevel=false value=".tran 1n 10n
"}
C {devices/title} 160 -40 0 0 {name=l3 author="issue 0506 eyeball fixture: net EN must survive to the viewer as v(EN)"}
