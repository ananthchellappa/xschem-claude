v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 560 -930 560 -910 {
lab=GND}
N 560 -1050 560 -990 {
lab=Vin1}
N 670 -920 670 -910 {
lab=GND}
N 670 -990 670 -980 {
lab=#net1}
N 670 -1060 670 -1050 {
lab=Vin1}
N 850 -930 850 -910 {
lab=GND}
N 850 -1050 850 -990 {
lab=Vin2}
N 940 -920 940 -910 {
lab=GND}
N 940 -990 940 -980 {
lab=#net2}
N 940 -1060 940 -1050 {
lab=Vin2}
C {devices/gnd} 560 -910 0 0 {name=l2 lab=GND}
C {devices/title-3} 0 0 0 0 {name=l3 author="IHP PDK Authors" rev=1.0 lock=true}
C {devices/lab_pin} 560 -1050 1 0 {name=p1 sig_type=std_logic lab=Vin1}
C {devices/gnd} 670 -910 0 0 {name=l9 lab=GND}
C {devices/ammeter} 670 -1020 0 0 {name=Vmda1}
C {devices/lab_pin} 670 -1060 1 0 {name=p8 sig_type=std_logic lab=Vin1}
C {devices/isource} 560 -960 2 0 {name=I0 value=1m}
C {devices/gnd} 850 -910 0 0 {name=l1 lab=GND}
C {devices/lab_pin} 850 -1050 1 0 {name=p2 sig_type=std_logic lab=Vin2}
C {devices/gnd} 940 -910 0 0 {name=l4 lab=GND}
C {devices/ammeter} 940 -1020 0 0 {name=Vmda2}
C {devices/lab_pin} 940 -1060 1 0 {name=p3 sig_type=std_logic lab=Vin2}
C {devices/isource} 850 -960 2 0 {name=I1 value=1m}
C {sg13g2_pr/nmoscl_2} 670 -950 2 0 {name=D1
model=nmoscl_2
m=1
spiceprefix=X
}
C {sg13g2_pr/nmoscl_4} 940 -950 2 0 {name=D2
model=nmoscl_4
m=1
spiceprefix=X
}
