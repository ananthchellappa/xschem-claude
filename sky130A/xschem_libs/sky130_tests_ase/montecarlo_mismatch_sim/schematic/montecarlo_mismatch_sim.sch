v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
P 4 7 330 -250 330 -260 325 -260 330 -270 335 -260 330 -260 330 -250 {fill=full}
P 4 7 330 -250 330 -240 335 -240 330 -230 325 -240 330 -240 330 -250 {fill=full}
T {tcleval(mean=[to_eng $mean]V
σ=[to_eng $rms]V
Samples=$samples
Categories=$categories)} 930 -240 0 0 0.6 0.6 {layer=4 floater=yes}
T {Vdiff} 270 -260 0 0 0.4 0.4 {}
T {Montecarlo simulation. Get average, stddev and histogram
of OTA differential input voltage mismatch.} 160 -860 0 0 0.7 0.7 {}
N 400 -340 400 -310 {
lab=VDD}
N 400 -190 400 -150 {
lab=GND}
N 230 -270 340 -270 {
lab=VM}
N 230 -450 230 -270 {
lab=VM}
N 230 -450 310 -450 {
lab=VM}
N 370 -450 540 -450 {
lab=#net1}
N 490 -250 540 -250 {
lab=#net1}
N 230 -230 340 -230 {
lab=VCM}
N 230 -230 230 -200 {
lab=VCM}
N 230 -140 230 -100 {
lab=GND}
N 540 -160 540 -120 {
lab=GND}
N 540 -250 540 -220 {
lab=#net1}
N 60 -650 60 -620 {
lab=VDD}
N 60 -560 60 -520 {
lab=GND}
N 540 -450 540 -250 {
lab=#net1}
C {devices/vdd} 400 -340 0 0 {name=l1 lab=VDD}
C {devices/gnd} 400 -150 0 0 {name=l2 lab=GND}
C {devices/vsource} 340 -450 1 1 {name=Vprobe2 value=0 savecurrent=false}
C {devices/vsource} 230 -170 0 1 {name=VICM value="dc 0.85 ac 0" savecurrent=false}
C {devices/gnd} 230 -100 0 0 {name=l4 lab=GND}
C {devices/capa} 540 -190 0 0 {name=C1
m=1
value=5p
footprint=1206
device="ceramic capacitor"}
C {devices/gnd} 540 -120 0 0 {name=l5 lab=GND}
C {devices/vdd} 60 -650 0 0 {name=l6 lab=VDD}
C {devices/vsource} 60 -590 0 1 {name=V3 value=1.8 savecurrent=false}
C {devices/gnd} 60 -520 0 0 {name=l7 lab=GND}
C {devices/lab_pin} 230 -220 0 0 {name=p2 sig_type=std_logic lab=VCM}
C {devices/title} 160 -30 0 0 {name=l8 author="Nithin P"}
C {sky130_tests/ota1tb} 490 -250 0 0 {name=x2}
C {devices/lab_pin} 230 -340 0 0 {name=p3 sig_type=std_logic lab=VM}
C {devices/spice_probe_vdiff} 230 -250 0 0 {name=p1}
