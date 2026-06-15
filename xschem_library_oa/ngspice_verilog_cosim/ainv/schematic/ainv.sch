v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 170 -210 170 -150 {lab=OUT}
N 170 -310 170 -240 {lab=VDD}
N 170 -120 170 -50 {lab=0}
N 130 -240 130 -120 {lab=IN}
N 170 -180 240 -180 {lab=OUT}
N 70 -180 130 -180 {lab=IN}
C {devices/nmos4} 150 -120 0 0 {name=MN model=N1
format="@name @pinlist @model"
device_model=".model n1 nmos
+  level=2 vto=0.5 kp=24e-6 gamma=0.15 phi=0.65 lambda=0.015 xj=0.5e-6
"}
C {devices/pmos4} 150 -240 0 0 {name=MP model=P1
format="@name @pinlist @model"

device_model=".model p1 pmos
+  level=2 vto=-0.5 kp=8.5e-6 gamma=0.4 phi=0.65 lambda=0.05 xj=0.5e-6
"}
C {devices/ipin} 70 -180 0 0 {name=p1 lab=IN}
C {devices/opin} 240 -180 0 0 {name=p2 lab=OUT}
C {devices/lab_pin} 170 -50 0 0 {name=p3 sig_type=std_logic lab=0}
C {devices/ipin} 170 -310 0 0 {name=p4 lab=VDD}
