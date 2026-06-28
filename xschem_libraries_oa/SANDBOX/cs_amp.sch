v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
* --- wires ---
N 420 -270 420 -230 {}
N 420 -330 420 -345 {}
N 420 -345 420 -360 {}
N 420 -420 420 -460 {}
N 420 -330 520 -330 {}
N 350 -300 380 -300 {}
N 380 -300 380 -320 {}
N 380 -320 380 -345 {}
N 360 -345 380 -345 {}
N 290 -300 290 -285 {}
N 290 -285 290 -270 {}
N 290 -210 290 -180 {}
* --- instances ---
C {devices/nmos} 400 -300 0 0 {name=M1}
C {devices/res} 320 -300 1 0 {name=R1 value=10k}
C {devices/res} 420 -390 0 0 {name=R2 value=1k}
C {devices/capa} 390 -345 1 0 {name=Cmu value=1p}
C {devices/vsource} 290 -240 0 0 {name=Vi value="dc 0 ac 1"}
C {devices/gnd} 420 -230 0 0 {name=l1 lab=0}
C {devices/gnd} 290 -180 0 0 {name=l2 lab=0}
C {devices/ipin} 420 -460 0 0 {name=p1 lab=VDD}
C {devices/opin} 520 -330 0 0 {name=p2 lab=vo}
C {devices/lab_pin} 290 -285 0 0 {name=p3 lab=vi}
C {devices/lab_pin} 380 -320 0 0 {name=p4 lab=v1}
