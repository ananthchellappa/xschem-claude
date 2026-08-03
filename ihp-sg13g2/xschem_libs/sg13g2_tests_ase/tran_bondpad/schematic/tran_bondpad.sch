v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -240 160 -240 170 {
lab=GND}
N 10 -200 10 -170 {lab=out}
N -60 -200 -60 -170 {lab=GND}
N -130 -200 -130 -170 {lab=in}
N -240 0 -110 0 {lab=in}
N -240 0 -240 100 {lab=in}
N -50 0 130 0 {lab=out}
N 130 0 130 70 {lab=out}
N 130 130 130 170 {lab=GND}
N 130 0 150 0 {lab=out}
N -270 0 -240 -0 {lab=in}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/lab_pin} 150 0 2 0 {name=p2 sig_type=std_logic lab=out}
C {devices/gnd} 130 170 0 0 {name=l6 lab=GND}
C {devices/gnd} -240 170 0 0 {name=l7 lab=GND}
C {devices/vsource} -240 130 0 0 {name=VinB value="dc 0 ac 0 pulse(-3.3, 3.3, 0, 100p, 100p, 2n, 4n ) "}
C {devices/lab_pin} -270 0 0 0 {name=p3 sig_type=std_logic lab=in}
C {devices/lab_pin} -130 -170 0 0 {name=p5 sig_type=std_logic lab=in}
C {devices/lab_pin} 10 -170 2 0 {name=p6 sig_type=std_logic lab=out}
C {devices/gnd} -60 -170 0 0 {name=l8 lab=GND}
C {sg13g2_pr/dantenna} 130 100 2 0 {name=D1
model=dantenna
l=200.78u
w=200.78u
spiceprefix=X
}
C {sg13g2_pr/dantenna} -80 0 1 0 {name=D2
model=dantenna
l=200.78u
w=200.78u
spiceprefix=X
}
C {sg13g2_pr/bondpad} -130 -240 0 0 {name=X1
model=bondpad
spiceprefix=X
size=80u
shape=0
padtype=0
}
C {sg13g2_pr/bondpad} -60 -240 0 0 {name=X2
model=bondpad
spiceprefix=X
size=80u
shape=0
padtype=0
}
C {sg13g2_pr/bondpad} 10 -240 0 0 {name=X3
model=bondpad
spiceprefix=X
size=80u
shape=0
padtype=0
}
