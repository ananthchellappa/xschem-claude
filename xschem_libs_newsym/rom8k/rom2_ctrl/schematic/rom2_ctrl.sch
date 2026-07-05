v {xschem version=3.4.4 file_version=1.2
*
* This file is part of XSCHEM,
* a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
* simulation.
* Copyright (C) 1998-2024 Stefan Frederik Schippers
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
}
G {}
K {}
V {}
S {}
E {}
B 2 580 -140 1200 -30 {flags=graph
y1 = 0
y2 = 1.6
divy = 2
x1=1.17129e-07
x2=1.9371e-07
divx=8
comm="example of using tcl to replace the path 
      with $path variable automatically"
node="xctrl.ldcp_ref
xctrl.ldprechref"
color="12 11"
digital=0
ypos1=-0.0691204
ypos2=0.68559
jpeg_quality=30}
B 2 580 -280 1200 -140 {flags=graph
y1 = 0
y2 = 1.6
divy = 2
x1=1.17129e-07
x2=1.9371e-07
divx=8
comm="example of using tcl to replace the path 
      with $path variable automatically"
node="xctrl.ldcp_ref
xctrl.ldcpb"
color="12 11"
digital=0
ypos1=0.071147
ypos2=1.0465
jpeg_quality=30}
B 2 580 -400 1200 -280 {flags=graph
y1 = 0
y2 = 1.6
divy = 2
x1=1.17129e-07
x2=1.9371e-07
divx=8
comm="example of using tcl to replace the path 
      with $path variable automatically"
node="xctrl.ldq_b
xctrl.ldcp_ref
xctrl.ldouti
xctrl.ldoutib"
color="12 5 11 8"
digital=1
ypos1=0.1572
ypos2=0.829851
jpeg_quality=30}
N 360 -670 500 -670 {lab=LDCPB}
N 240 -760 250 -760 {lab=LDCPB}
N 240 -760 240 -670 {lab=LDCPB}
N 200 -670 240 -670 {lab=LDCPB}
N 240 -870 240 -760 {lab=LDCPB}
N 240 -870 250 -870 {lab=LDCPB}
N 360 -510 420 -510 {lab=LDCPB}
N 900 -960 900 -900 {lab=#net1}
N 800 -870 900 -900 {lab=#net1}
N 800 -870 800 -820 {lab=#net1}
N 900 -860 900 -800 {lab=#net2}
N 800 -890 900 -860 {lab=#net2}
N 800 -940 800 -890 {lab=#net2}
N 1350 -240 1350 -190 {lab=VSS}
N 980 -960 1000 -960 {lab=LDOUTIB}
N 1070 -510 1110 -510 {lab=LDPRECHREF}
N 360 -670 360 -510 {lab=LDCPB}
N 410 -870 430 -870 {lab=#net3}
N 240 -670 360 -670 {lab=LDCPB}
N 1350 -320 1350 -300 {lab=#net4}
N 1310 -350 1310 -270 {lab=LDOUTI}
N 1350 -500 1350 -480 {lab=LDYMSREF}
N 1350 -400 1350 -380 {lab=#net5}
N 1510 -320 1510 -300 {lab=#net6}
N 1470 -350 1470 -270 {lab=LDOUTI}
N 1350 -240 1510 -240 {lab=VSS}
N 1510 -400 1510 -380 {lab=#net7}
C {devices/title} 170 0 0 0 {name=l3 author="Stefan Schippers"}
C {devices/opin} 250 -340 0 0 { name=p1 lab=LDPRECH }
C {devices/opin} 250 -320 0 0 { name=p2 lab=LDSAL}
C {devices/opin} 250 -300 0 0 { name=p3 lab=LDCP_ROWDEC }
C {devices/opin} 250 -280 0 0 { name=p4 lab=LDCP_SA}
C {devices/opin} 250 -260 0 0 { name=p5 lab=LDCP_ADDLAT_B }
C {devices/opin} 250 -240 0 0 { name=p6 lab=LDCP_COL_B }
C {devices/ipin} 200 -280 0 0 { name=p49 lab=LDEN_LAT }
C {devices/ipin} 200 -260 0 0 { name=p50 lab=LDCP }
C {devices/ipin} 200 -240 0 0 { name=p51 lab=VCC }
C {devices/ipin} 200 -220 0 0 { name=p52 lab=VSS }
C {devices/lab_wire} 260 -670 0 0 {name=l19 lab=LDCPB}
C {devices/capa} 270 -640 0 0 {name=c84 m=1 value=5f}
C {devices/lab_pin} 270 -610 0 0 {name=p1109 lab=VSS}
C {devices/lab_pin} 330 -760 0 1 {name=p1111 lab=LDCP_SA}
C {rom8k/lvnand2} 140 -670 0 0 {name=x392 m=1 
+ wna=90u lna=2.4u wpa=60u lpa=2.4u
+ wnb=90u lnb=2.4u wpb=60u lpb=2.4u
+ VCCPIN=vcc VSSPIN=vss }
C {devices/lab_pin} 100 -690 0 0 {name=p1113 lab=LDCP}
C {devices/lab_pin} 100 -650 0 0 {name=p1114 lab=LDEN_LAT}
C {devices/lab_pin} 410 -1000 0 1 {name=p1115 lab=LDCP_ADDLAT_B}
C {rom8k/lvnot} 290 -760 0 0 {name=x394 m=1 
+ wn=8.4u lln=2.8u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss
}
C {rom8k/lvnot} 470 -870 0 0 {name=x395 m=10
+ wn=15u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/lvnot} 290 -870 0 0 {name=x396 m=1 
+ wn=15u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/lvnot} 370 -870 0 0 {name=x397 m=4 
+ wn=15u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/lab_pin} 510 -870 0 1 {name=p1116 lab=LDCP_ROWDEC}
C {devices/lab_pin} 580 -510 0 1 {name=p1117 lab=LDCP_COL_B}
C {rom8k/lvnot} 370 -1000 0 0 {name=x405 m=1 
+ wn=30u lln=2.4u wp=80u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/lab_pin} 330 -1000 0 0 {name=p1118 lab=LDCP}
C {devices/lab_pin} 580 -670 0 1 {name=p7 lab=LDCP_REF}
C {devices/lab_pin} 980 -800 0 1 {name=p22 lab=LDOUTI}
C {rom8k/lvnot} 890 -630 0 0 {name=x7 m=1 
+ wn=24u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/lab_pin} 850 -630 0 0 {name=p10 lab=VSS}
C {rom8k/lvnor2} 1010 -510 0 0 {name=x8 m=1 
+ wna=8.4u lna=2.4u wpa=70u lpa=2.4u
+ wnb=8.4u lnb=2.4u wpb=70u lpb=2.4u
+ VCCPIN=VCC VSSPIN=VSS}
C {devices/lab_pin} 970 -490 0 0 {name=p29 lab=LDOUTI}
C {devices/lab_pin} 930 -630 0 1 {name=p30 lab=LDCP_REF_B}
C {rom8k/lvnand2} 840 -960 0 0 {name=x18 m=1 
+ wna=20u lna=2.4u wpa=36u lpa=2.4u
+ wnb=20u lnb=2.4u wpb=36u lpb=2.4u
+ VCCPIN=VCC VSSPIN=VSS}
C {rom8k/lvnand2} 840 -800 2 1 {name=x3 m=1 
+ wna=30u lna=2.4u wpa=30u lpa=2.4u
+ wnb=30u lnb=2.4u wpb=30u lpb=2.4u
+ VCCPIN=VCC VSSPIN=VSS}
C {devices/lab_pin} 800 -780 0 0 {name=p11 lab=LDCP_REF}
C {devices/lab_pin} 800 -980 0 0 {name=p43 lab=LDQ_B}
C {devices/lab_pin} 1350 -190 0 0 {name=p63 lab=VSS}
C {rom8k/nlv} 1330 -270 0 0 {name=m15 model=cmosn w=4u l=2.4u m=1}
C {rom8k/lvnand3} 1270 -790 0 0 {name=x25 m=1 
+ wn=80u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=VCC VSSPIN=VSS}
C {devices/lab_pin} 1230 -810 0 0 {name=p24 lab=LDCP_REF}
C {devices/lab_pin} 1230 -790 0 0 {name=p27 lab=LDQ_B}
C {devices/lab_pin} 1230 -770 0 0 {name=p66 lab=LDOUTI}
C {devices/lab_pin} 1410 -790 0 1 {name=p67 lab=LDSAL}
C {rom8k/lvnot} 1370 -790 0 0 {name=x26 m=4 
+ wn=13u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/lab_pin} 1410 -970 0 1 {name=p68 lab=LDPRECH}
C {rom8k/lvnot} 1370 -970 0 0 {name=x28 m=8 
+ wn=13u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/lab_pin} 1000 -960 0 1 {name=p15 lab=LDOUTIB}
C {rom8k/lvnot} 540 -670 0 0 {name=x4 m=2 
+ wn=13u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/lvnot} 540 -510 0 0 {name=x1 m=2 
+ wn=20u lln=2.4u wp=44u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/lvnot} 460 -510 0 0 {name=x6 m=1 
+ wn=8.4u lln=2.4u wp=16u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/iopin} 250 -220 0 0 { name=p20 lab=LDYMSREF }
C {rom8k/lvnot} 940 -960 0 0 {name=x5 m=1 
+ wn=30u lln=2.4u wp=40u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {rom8k/lvnot} 940 -800 0 0 {name=x9 m=2 
+ wn=12u lln=2.4u wp=30u lp=2.4u
+ VCCPIN=vcc VSSPIN=vss}
C {devices/lab_pin} 1590 -610 0 1 {name=p17 lab=LDYMSREF}
C {devices/lab_pin} 1590 -630 0 1 {name=p18 lab=LDQ_B}
C {devices/lab_pin} 1290 -630 0 0 {name=p21 lab=LDPRECHREF}
C {devices/lab_pin} 1290 -610 0 0 {name=p23 lab=VCC}
C {devices/lab_pin} 1290 -590 0 0 {name=p26 lab=VSS}
C {devices/lab_pin} 1590 -650 0 1 {name=p32 lab=LDQI}
C {devices/lab_pin} 1110 -510 0 1 {name=p9 lab=LDPRECHREF}
C {devices/noconn} 1570 -750 0 0 {name=l1}
C {devices/lab_pin} 1570 -750 0 1 {name=p33 lab=LDQI}
C {devices/lab_pin} 1350 -500 0 1 {name=p12 lab=LDYMSREF}
C {rom8k/rom2_sacell} 1440 -620 0 0 {name=xsacell}
C {devices/lab_pin} 1310 -270 0 0 {name=p13 lab=LDOUTI}
C {devices/spice_probe} 580 -670 0 0 {name=p95 analysis=tran}
C {devices/spice_probe} 1070 -510 0 0 {name=p19 analysis=tran}
C {devices/spice_probe} 980 -800 0 0 {name=p28 analysis=tran}
C {devices/spice_probe} 980 -960 0 0 {name=p31 analysis=tran}
C {devices/spice_probe} 1590 -650 0 0 {name=p34 analysis=tran}
C {devices/spice_probe} 800 -980 0 1 {name=p35 analysis=tran}
C {rom8k/nlv} 1330 -350 0 0 {name=m1 model=cmosn w=4u l=2.4u m=1}
C {rom8k/lvnand3} 1270 -970 0 0 {name=x2 m=1 
+ wn=80u lln=2.4u wp=60u lp=2.4u
+ VCCPIN=VCC VSSPIN=VSS}
C {devices/lab_pin} 1230 -950 0 0 {name=p36 lab=LDCP}
C {devices/lab_pin} 1230 -970 0 0 {name=p37 lab=LDEN_LAT}
C {devices/lab_pin} 1230 -990 0 0 {name=p38 lab=LDOUTIB}
C {devices/lab_pin} 970 -530 0 0 {name=p8 lab=LDCPB}
C {rom8k/nlv} 1490 -270 0 0 {name=m2 model=cmosn w=4u l=2.4u m=1}
C {devices/lab_pin} 1470 -270 0 0 {name=p0 lab=LDOUTI}
C {rom8k/nlv} 1490 -350 0 0 {name=m0 model=cmosn w=4u l=2.4u m=1}
C {devices/spice_probe} 400 -670 0 0 {name=p25 analysis=tran}
C {devices/lab_pin} 1290 -650 0 0 {name=p14 lab=LDCPB}
