v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Target: W = 3.5 , delay = 1.953e-10} 840 -280 0 0 0.4 0.4 {
layer=3}
T {This example sizes the delay chain inverters until a delay less than 200ps is obtained} 60 -820 0 0 0.5 0.5 {}
N 90 -410 90 -390 {
lab=GND}
N 220 -410 220 -390 {
lab=GND}
N 220 -490 220 -470 {
lab=CK}
N 90 -490 90 -470 {
lab=VCC}
N 730 -180 730 -120 { lab=#net1}
N 810 -180 810 -120 { lab=#net2}
N 650 -180 650 -120 { lab=#net3}
N 890 -180 920 -180 {
lab=CK_DEL}
N 900 -180 900 -150 {
lab=CK_DEL}
C {devices/vsource} 90 -440 0 0 {name=V1 value=\{VCC\}}
C {devices/lab_pin} 90 -390 0 0 {name=p9 sig_type=std_logic lab=GND}
C {devices/vsource} 220 -440 0 0 {name=V2 value="pulse 0 \{VCC\} 0 100p 100p
+ \{PER/2-0.1n\} \{PER\}"}
C {devices/lab_pin} 220 -390 0 0 {name=p1 sig_type=std_logic lab=GND}
C {devices/lab_pin} 220 -490 0 1 {name=p2 sig_type=std_logic lab=CK}
C {devices/title} 160 -30 0 0 {name=l2 author="Stefan Schippers"}
C {devices/noconn} 90 -390 0 1 {name=l3}
C {devices/lab_pin} 90 -490 0 1 {name=p32 sig_type=std_logic lab=VCC}
C {devices/parax_cap} 650 -110 0 0 {name=C1 gnd=0 value=4f m=1}
C {devices/parax_cap} 730 -110 0 0 {name=C2 gnd=0 value=4f m=1}
C {devices/parax_cap} 810 -110 0 0 {name=C3 gnd=0 value=4f m=1}
C {sky130_tests/not} 610 -180 0 0 {name=x4 m=1 VCCPIN=VCC VSSPIN=GND W_N=3.5 L_N=0.15 W_P=7.0 L_P=0.15}
C {sky130_tests/not} 690 -180 0 0 {name=x1 m=1 VCCPIN=VCC VSSPIN=GND W_N=3.5 L_N=0.15 W_P=7.0 L_P=0.15}
C {sky130_tests/not} 770 -180 0 0 {name=x2 m=1 VCCPIN=VCC VSSPIN=GND W_N=3.5 L_N=0.15 W_P=7.0 L_P=0.15}
C {sky130_tests/not} 850 -180 0 0 {name=x3 m=1 VCCPIN=VCC VSSPIN=GND W_N=3.5 L_N=0.15 W_P=7.0 L_P=0.15}
C {devices/lab_pin} 570 -180 0 0 {name=p3 sig_type=std_logic lab=CK}
C {devices/lab_pin} 920 -180 0 1 {name=p4 sig_type=std_logic lab=CK_DEL}
C {devices/capa} 900 -120 0 0 {name=C4
m=1
value=100f
footprint=1206
device="ceramic capacitor"}
C {devices/lab_pin} 900 -90 0 0 {name=p5 sig_type=std_logic lab=0}
