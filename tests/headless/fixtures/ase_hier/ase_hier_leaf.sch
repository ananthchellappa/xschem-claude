v {xschem version=3.4.4 file_version=1.2}
G {}
V {}
S {}
E {}
N 0 0 200 0 {}
N 200 60 300 60 {}
N 300 60 300 160 {}
N 0 -100 100 -100 {}
N 0 -200 100 -200 {}
N 400 -100 500 -100 {}
C {devices/ipin.sym} 0 0 0 0 {name=p1 lab=A}
C {devices/vsource.sym} 200 30 0 0 {name=V1 value=0}
C {devices/lab_pin.sym} 300 60 0 0 {name=l1 lab=mid}
C {devices/lab_pin.sym} 0 -100 0 0 {name=l2 lab=bus[1:0]}
C {devices/opin.sym} 0 -200 0 0 {name=p2 lab=B}
C {devices/res.sym} 300 190 0 0 {name=R1 value=1k}
C {devices/gnd.sym} 300 220 0 0 {name=l3 lab=0}
