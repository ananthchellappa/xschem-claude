v {xschem version=3.4.4 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
N -500 40 -500 60 {
lab=GND}
N -500 -80 -500 -20 {
lab=Vd}
N -500 -80 -220 -80 {
lab=Vd}
N -220 -80 -220 -40 {
lab=Vd}
N -220 20 -220 60 {
lab=GND}
N -220 -80 -200 -80 {
lab=Vd}
N -70 40 -70 60 {
lab=GND}
N -70 -80 -70 -20 {
lab=Vdp}
N -70 -80 210 -80 {
lab=Vdp}
N 210 -80 210 -40 {
lab=Vdp}
N 210 20 210 60 {
lab=GND}
N 210 -80 230 -80 {
lab=Vdp}
C {devices/gnd} -220 60 0 0 {name=l1 lab=GND}
C {devices/gnd} -500 60 0 0 {name=l2 lab=GND}
C {devices/lab_pin} -200 -80 0 1 {name=p1 sig_type=std_logic lab=Vd}
C {sg13g2_pr/dantenna} -220 -10 2 0 {name=XD1
model=dantenna
l=780n
w=780n
}
C {devices/isource} -500 10 2 0 {name=I0 value=200n}
C {devices/title} -360 130 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/gnd} 210 60 0 0 {name=l3 lab=GND}
C {devices/gnd} -70 60 0 0 {name=l4 lab=GND}
C {devices/lab_pin} 230 -80 0 1 {name=p2 sig_type=std_logic lab=Vdp}
C {devices/isource} -70 10 2 0 {name=I1 value=200n}
C {sg13g2_pr/dpantenna} 210 -10 2 0 {name=XD2
model=dpantenna
l=780n
w=780n
}
