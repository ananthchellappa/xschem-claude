v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Theoretical Period = 2 * RC ln(2)} 440 -490 0 0 0.6 0.6 { layer=6}
N 590 -210 590 -160 {
lab=RSTBB}
N 470 -290 590 -210 {
lab=RSTBB}
N 470 -340 470 -290 {
lab=RSTBB}
N 590 -360 590 -310 {
lab=RSTAB}
N 470 -230 590 -310 {
lab=RSTAB}
N 470 -230 470 -180 {
lab=RSTAB}
N 410 -380 470 -380 {
lab=BB}
N 410 -140 470 -140 {
lab=AB}
N 1190 -360 1190 -330 {
lab=#net1}
N 1190 -90 1190 -70 {
lab=VSS}
N 1080 -170 1080 -90 {
lab=VSS}
N 1080 -90 1190 -90 {
lab=VSS}
N 1080 -200 1190 -200 {
lab=B}
N 1040 -330 1150 -330 {
lab=RSTB}
N 590 -160 660 -160 {
lab=RSTBB}
N 590 -360 660 -360 {
lab=RSTAB}
N 1560 -360 1560 -330 {
lab=#net2}
N 1560 -90 1560 -70 {
lab=VSS}
N 1450 -170 1450 -90 {
lab=VSS}
N 1450 -90 1560 -90 {
lab=VSS}
N 1450 -200 1560 -200 {
lab=A}
N 1410 -330 1520 -330 {
lab=RSTA}
N 1560 -210 1660 -210 {
lab=A}
N 1190 -210 1290 -210 {
lab=B}
N 740 -160 820 -160 {
lab=RSTB}
N 740 -360 820 -360 {
lab=RSTA}
N 1560 -300 1560 -280 {
lab=AH}
N 1560 -200 1560 -160 {
lab=A}
N 1190 -300 1190 -280 {
lab=BH}
N 1190 -200 1190 -160 {
lab=B}
N 1190 -100 1190 -90 {
lab=VSS}
N 1190 -210 1190 -200 {
lab=B}
N 1560 -100 1560 -90 {
lab=VSS}
N 1560 -210 1560 -200 {
lab=A}
N 1560 -220 1560 -210 {
lab=A}
N 1190 -220 1190 -210 {
lab=B}
N 900 -360 920 -360 {
lab=Q}
N 900 -160 920 -160 {
lab=QB}
N 1040 -330 1040 -170 {
lab=RSTB}
N 1410 -330 1410 -170 {
lab=RSTA}
C {sky130_tests_ase/lvnand} 520 -360 2 1 {name=x9 WidthN=0.5 LenN=0.15 WidthP=1 LenP=0.15 m=1}
C {sky130_tests_ase/lvnand} 520 -160 0 0 {name=x1 WidthN=0.5 LenN=0.15 WidthP=1 LenP=0.15 m=1}
C {sky130_fd_pr/pfet_01v8} 1170 -330 0 0 {name=M1
W=4
L=0.15
nf=1
mult=1


model=pfet_01v8
spiceprefix=X
}
C {devices/vdd} 1190 -420 0 0 {name=l1 lab=VCC}
C {devices/gnd} 1190 -70 0 0 {name=l2 lab=VSS}
C {sky130_fd_pr/nfet_01v8} 1060 -170 0 0 {name=M2
W=1
L=0.15
nf=1 
mult=1


model=nfet_01v8
spiceprefix=X
}
C {sky130_tests/not} 700 -360 0 0 {name=x2 m=1 VCCPIN=VCC VSSPIN=VSS W_N=0.5 L_N=0.15 W_P=1 L_P=0.15}
C {sky130_tests/not} 700 -160 0 0 {name=x3 m=1 VCCPIN=VCC VSSPIN=VSS W_N=0.5 L_N=0.15 W_P=1 L_P=0.15}
C {sky130_tests_ase/lvnand} 340 -380 2 1 {name=x4 WidthN=0.5 LenN=1 WidthP=1 LenP=0.3 m=1}
C {sky130_tests_ase/lvnand} 340 -140 0 0 {name=x5 WidthN=0.5 LenN=1 WidthP=1 LenP=0.3 m=1}
C {sky130_fd_pr/pfet_01v8} 1540 -330 0 0 {name=M3
W=4
L=0.15
nf=1
mult=1


model=pfet_01v8
spiceprefix=X
}
C {devices/vdd} 1560 -420 0 0 {name=l3 lab=VCC}
C {devices/gnd} 1560 -70 0 0 {name=l4 lab=VSS}
C {sky130_fd_pr/nfet_01v8} 1430 -170 0 0 {name=M4
W=1
L=0.15
nf=1 
mult=1


model=nfet_01v8
spiceprefix=X
}
C {devices/lab_pin} 1290 -210 0 1 {name=p1 sig_type=std_logic lab=B}
C {devices/lab_pin} 1660 -210 0 1 {name=p2 sig_type=std_logic lab=A}
C {devices/lab_pin} 290 -400 0 0 {name=p3 sig_type=std_logic lab=B}
C {devices/lab_pin} 290 -360 0 0 {name=p4 sig_type=std_logic lab=VCC}
C {devices/lab_pin} 290 -120 0 0 {name=p5 sig_type=std_logic lab=A}
C {devices/lab_pin} 290 -160 0 0 {name=p6 sig_type=std_logic lab=ENAB}
C {devices/title} 160 -30 0 0 {name=l5 author="Stefan Schippers"}
C {devices/iopin} 70 -120 0 1 { name=p7 lab=VSS }
C {devices/iopin} 70 -140 0 1 { name=p8 lab=VCC }
C {devices/ipin} 70 -180 0 0 { name=p9 lab=ENAB }
C {devices/lab_wire} 760 -160 0 1 {name=p10 sig_type=std_logic lab=RSTB}
C {devices/lab_wire} 760 -360 0 1 {name=p11 sig_type=std_logic lab=RSTA}
C {devices/opin} 100 -160 0 0 { name=p12 lab=QB }
C {devices/opin} 100 -180 0 0 { name=p13 lab=Q }
C {devices/lab_wire} 650 -360 0 0 {name=p14 sig_type=std_logic lab=RSTAB}
C {devices/lab_wire} 650 -160 0 0 {name=p15 sig_type=std_logic lab=RSTBB}
C {devices/lab_wire} 450 -380 0 0 {name=p16 sig_type=std_logic lab=BB}
C {devices/lab_wire} 450 -140 0 0 {name=p17 sig_type=std_logic lab=AB}
C {devices/lab_pin} 1560 -290 0 1 {name=p18 sig_type=std_logic lab=AH}
C {devices/lab_pin} 1190 -290 0 1 {name=p19 sig_type=std_logic lab=BH}
C {sky130_tests/not} 860 -360 0 0 {name=x6 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {sky130_tests/not} 860 -160 0 0 {name=x7 m=1 VCCPIN=VCC VSSPIN=VSS W_N=1 L_N=0.15 W_P=2 L_P=0.15}
C {devices/lab_pin} 920 -360 0 1 {name=p20 sig_type=std_logic lab=Q}
C {devices/lab_pin} 920 -160 0 1 {name=p21 sig_type=std_logic lab=QB}
C {devices/lab_pin} 1410 -230 0 0 {name=p22 sig_type=std_logic lab=RSTA}
C {devices/lab_pin} 1040 -230 0 0 {name=p23 sig_type=std_logic lab=RSTB}
C {sky130_fd_pr/cap_mim_m3_2} 1190 -130 0 0 {name=C2 model=cap_mim_m3_2 W=10 L=10 MF=5 spiceprefix=X }
C {sky130_fd_pr/cap_mim_m3_2} 1560 -130 0 0 {name=C1 model=cap_mim_m3_2 W=10 L=10 MF=5 spiceprefix=X }
C {sky130_fd_pr/res_xhigh_po_1p41} 1560 -250 0 0 {name=R1
L=20
model=res_xhigh_po_1p41
spiceprefix=X
mult=1}
C {devices/gnd} 1540 -250 0 1 {name=l6 lab=VSS}
C {sky130_fd_pr/res_xhigh_po_1p41} 1190 -250 0 0 {name=R2
L=20
model=res_xhigh_po_1p41
spiceprefix=X
mult=1}
C {devices/gnd} 1170 -250 0 1 {name=l7 lab=VSS}
C {devices/ammeter} 1190 -390 0 0 {name=VB savecurrent=false}
C {devices/ammeter} 1560 -390 0 0 {name=VA savecurrent=false}
