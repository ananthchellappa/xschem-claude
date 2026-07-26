v {xschem version=3.0.0 file_version=1.2 }
G {}
K {}
V {}
S {}
E {}
T {C1 = G[0] | P[0] & C0;
C2 = G[1] | P[1] & G[0] | P[1] & P[0] & C0;
} 20 -690 0 0 0.4 0.4 {font=monospace}
T {SG = G[1] | P[1] & G[0];
SP = P[1] & P[0];
} 20 -580 0 0 0.4 0.4 {font=monospace}
C {devices/ipin} 110 -220 0 0 {name=p1 lab=P[1:0]}
C {devices/ipin} 110 -190 0 0 {name=p2 lab=G[1:0]}
C {devices/ipin} 110 -150 0 0 {name=p3 lab=C0}
C {devices/title} 160 -30 0 0 {name=l2}
C {devices/opin} 180 -200 0 0 { name=p7 lab=C2 }
C {devices/opin} 180 -220 0 0 { name=p9 lab=C1 }
C {devices/opin} 180 -270 0 0 { name=p58 lab=SG }
C {devices/opin} 180 -250 0 0 { name=p59 lab=SP }
C {devices/lab_pin} 730 -500 0 1 {name=p56 lab=net3}
C {devices/lab_pin} 570 -540 0 0 {name=p57 lab=P[0] }
C {devices/lab_pin} 570 -500 0 0 {name=p60 lab=C0}
C {devices/lab_pin} 570 -460 0 0 {name=p61 lab=G[0] }
C {devices/lab_pin} 680 -380 0 1 {name=p62 lab=net1}
C {devices/lab_pin} 600 -380 0 0 {name=p63 lab=G[1] }
C {sky130_stdcells/inv_1} 640 -380 0 0 {
name=x17
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
C {sky130_stdcells/a21oi_1} 650 -500 0 0 {
name=x18
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
C {devices/parax_cap} 680 -370 0 0 {name=C17 gnd=0 value=5f m=1}
C {devices/parax_cap} 730 -490 0 0 {name=C18 gnd=0 value=5f m=1}
C {devices/lab_pin} 680 -250 0 1 {name=p64 lab=net2 }
C {devices/lab_pin} 560 -270 0 0 {name=p65 lab=G[0] }
C {devices/lab_pin} 560 -230 0 0 {name=p67 lab=P[1]}
C {sky130_stdcells/nand2_1} 620 -250 0 0 {
name=x19
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
C {devices/parax_cap} 680 -240 0 0 {name=C19 gnd=0 value=5f m=1}
C {devices/lab_pin} 700 -130 0 1 {name=p66 lab=net4}
C {devices/lab_pin} 580 -170 0 0 {name=p68 lab=P[1] }
C {devices/lab_pin} 580 -130 0 0 {name=p69 lab=P[0] }
C {devices/lab_pin} 580 -90 0 0 {name=p70 lab=C0}
C {sky130_stdcells/nand3_1} 640 -130 0 0 {
name=x20
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
C {devices/parax_cap} 700 -120 0 0 {name=C20 gnd=0 value=5f m=1}
C {devices/lab_pin} 1050 -500 0 1 {name=p71 lab=SG }
C {devices/lab_pin} 930 -520 0 0 {name=p72 lab=net1 }
C {devices/lab_pin} 930 -480 0 0 {name=p73 lab=net2}
C {sky130_stdcells/nand2_1} 990 -500 0 0 {
name=x21
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
C {devices/lab_pin} 1050 -400 0 1 {name=p74 lab=SP }
C {devices/lab_pin} 930 -420 0 0 {name=p75 lab=P[1] }
C {devices/lab_pin} 930 -380 0 0 {name=p76 lab=P[0]}
C {sky130_stdcells/and2_1} 990 -400 0 0 {
name=x22
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
C {devices/lab_pin} 1040 -280 0 1 {name=p77 lab=C1}
C {devices/lab_pin} 960 -280 0 0 {name=p78 lab=net3}
C {sky130_stdcells/inv_1} 1000 -280 0 0 {
name=x23
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
C {devices/lab_pin} 1070 -170 0 1 {name=p79 lab=C2}
C {devices/lab_pin} 950 -210 0 0 {name=p80 lab=net1}
C {devices/lab_pin} 950 -170 0 0 {name=p81 lab=net2}
C {devices/lab_pin} 950 -130 0 0 {name=p82 lab=net4}
C {sky130_stdcells/nand3_1} 1010 -170 0 0 {
name=x24
VGND=VSS
VNB=VSS
VPB=VCC
VPWR=VCC}
