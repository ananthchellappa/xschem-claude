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
P 7 11 1280 -860 1280 -820 1180 -900 1280 -980 1280 -940 1500 -940 1500 -980 1600 -900 1500 -820 1500 -860 1280 -860 {fill=true}
T {Example of hierarchical schematic
to be netlisted in tEDAx format.
Hierarchy is flattened and hierarchical 
node names and refdes's are mangled to 
avoid collisions.} 1330 -520 0 0 0.8 0.8 {}
T {NOTE: circuit is doing nothing useful,
just a collection of schematics to show
hierarchical tEDAx netlisting} 1330 -220 0 0 0.8 0.8 {}
T {Same design 
repeated 2 times} 1180 -1140 0 0 1 1 {}
N 540 -100 540 -80 {lab=VSS}
N 540 -200 540 -160 {lab=VREF}
N 540 -200 630 -200 {lab=VREF}
N 540 -320 540 -290 {lab=VCC}
N 630 -380 630 -280 {lab=VSSLOAD}
N 630 -380 1130 -380 {lab=VSSLOAD}
N 1130 -380 1130 -360 {lab=VSSLOAD}
N 1130 -300 1130 -270 {lab=D}
N 860 -120 880 -120 {lab=#net1}
N 770 -120 800 -120 {lab=RST}
N 920 -170 920 -150 {lab=#net2}
N 990 -210 990 -200 {lab=G}
N 900 -240 920 -240 {lab=#net2}
N 920 -170 950 -170 {lab=#net2}
N 990 -210 1040 -210 {lab=G}
N 1040 -240 1040 -210 {lab=G}
N 1040 -240 1090 -240 {lab=G}
N 1070 -840 1070 -790 { lab=VOUT_PROTECTED1}
N 390 -440 390 -420 {lab=VSS!}
N 310 -500 390 -500 { lab=VSS_ANALOG}
N 310 -440 310 -420 {lab=VSS}
N 540 -230 540 -200 {lab=VREF}
N 1130 -430 1130 -380 {lab=VSSLOAD}
N 920 -240 920 -170 {lab=#net2}
N 990 -220 990 -210 {lab=G}
N 1020 -790 1070 -790 { lab=VOUT_PROTECTED1}
N 70 -330 90 -330 { lab=#net3}
N 2080 -920 2080 -870 { lab=VOUT_PROTECTED2}
N 2030 -870 2080 -870 { lab=VOUT_PROTECTED2}
N 390 -500 450 -500 { lab=VSS_ANALOG}
C {devices/title} 160 -30 0 0 {name=l2 author="Stefan"}
C {devices/lab_pin} 70 -470 0 1 {name=p8 lab=VCC12}
C {devices/conn_8x1} 50 -450 0 0 {name=C2}
C {devices/lab_pin} 1130 -400 0 0 {name=p1 lab=VSSLOAD}
C {pcb/lm358} 710 -240 0 0 {name=U3:1
spiceprefix=X
VCC=VCC 
VNN=VSS
url="https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=3&ved=2ahUKEwi8_s-Z5KTfAhUmy4UKHbDOBUIQFjACegQICBAC&url=https%3A%2F%2Fwww.sparkfun.com%2Fdatasheets%2FComponents%2FGeneral%2FLM358.pdf&usg=AOvVaw0pOnlomz_hkzyk7OvZBPFv"
}
C {devices/res} 540 -130 0 0 {name=R3 m=1 value=4k footprint=1206}
C {devices/res} 540 -260 0 0 {name=R4 m=1 value=100k footprint=1206 
comptag="tc1 -1.4e-3  tc2 3e-5"
device="resistor 1% tolerance"}
C {devices/gnd} 540 -80 0 0 {name=l0 lab=VSS}
C {devices/nmos} 1110 -240 0 0 {name=M2
spiceprefix=X}
C {devices/res} 1130 -330 0 0 {name=R5 m=1 value=1 footprint=1206}
C {devices/gnd} 1130 -210 0 0 {name=l6 lab=VSS}
C {devices/vdd} 540 -320 0 0 {name=l7 lab=VCC}
C {devices/vdd} 1130 -550 0 0 {name=l8 lab=VCC}
C {pcb/voltage_protection.sch} 10 -490 0 0 {name=xprot1}
C {devices/lab_pin} 540 -180 0 0 {name=p2 lab=VREF}
C {devices/res} 1130 -460 0 0 {name=RLOAD m=1 value="R='1/(time+1e-7)'" footprint=1206}
C {devices/ammeter} 1130 -520 0 0 {name=vmeasure}
C {devices/lab_wire} 1070 -240 0 0 {name=l12 lab=G}
C {devices/lab_pin} 1130 -290 0 0 {name=p3 lab=D}
C {devices/res} 870 -240 1 0 {name=R2 m=1 value=20k footprint=1206}
C {devices/npn} 900 -120 0 0 {name=Q1 model=q2n2222
url="http://html.alldatasheet.com/html-pdf/17919/PHILIPS/MMBT2222/499/2/MMBT2222.html"
}
C {devices/gnd} 920 -90 0 0 {name=l16 lab=VSS}
C {devices/lab_pin} 770 -120 0 0 {name=p4 lab=RST}
C {devices/res} 830 -120 1 0 {name=R6 m=1 value=20k footprint=1206}
C {devices/lab_pin} 70 -430 0 1 {name=p5 lab=RST}
C {devices/npn} 970 -170 0 0 {name=Q2 model=q2n2222
url="http://html.alldatasheet.com/html-pdf/17919/PHILIPS/MMBT2222/499/2/MMBT2222.html"
}
C {devices/gnd} 990 -140 0 0 {name=l11 lab=VSS}
C {devices/res} 990 -250 2 0 {name=R1 m=1 value=20k footprint=1206}
C {devices/vdd} 990 -280 0 0 {name=l13 lab=VCC}
C {devices/lab_pin} 70 -450 0 1 {name=p9 lab=VSS}
C {devices/lab_pin} 1070 -790 0 1 {name=p6 lab=VOUT_PROTECTED1}
C {devices/lab_pin} 180 -1200 0 0 {name=p10 lab=VCC12}
C {devices/diode} 1070 -870 0 0 {name=D1 model=D1N914 area=1 device=D1N914 footprint=acy(300)}
C {devices/vdd} 1070 -900 0 0 {name=l1 lab=VCC}
C {devices/res} 390 -470 0 0 {name=R7 m=1 value=10 footprint=1206}
C {devices/gnd} 390 -420 0 0 {name=l3 lab=VSS}
C {devices/lab_pin} 450 -500 0 1 {name=p7 lab=VSS_ANALOG}
C {devices/lab_pin} 180 -1120 0 0 {name=p11 lab=VSS_ANALOG}
C {devices/capa} 310 -470 0 0 {name=C0 m=1 value=100u device="electrolitic capacitor"}
C {devices/gnd} 310 -420 0 0 {name=l4 lab=VSS}
C {devices/lab_pin} 70 -390 0 1 {name=p12 lab=VOUT_PROTECTED2}
C {devices/lab_pin} 70 -370 0 1 {name=p13 lab=VSS_ANALOG}
C {devices/lab_pin} 70 -350 0 1 {name=p14 lab=VSSLOAD}
C {devices/noconn} 90 -330 0 1 {name=l5}
C {pcb/voltage_protection} 1880 -860 0 0 {name=xprot2}
C {devices/lab_pin} 2080 -870 0 1 {name=p15 lab=VOUT_PROTECTED2}
C {devices/lab_pin} 1730 -870 0 0 {name=p16 lab=VCC12}
C {devices/diode} 2080 -950 0 0 {name=D2 model=D1N914 area=1 device=D1N914 footprint=acy(300)}
C {devices/vdd} 2080 -980 0 0 {name=l10 lab=VCC}
C {devices/lab_pin} 1730 -850 0 0 {name=p17 lab=VSS_ANALOG}
C {devices/lab_pin} 70 -410 0 1 {name=p18 lab=VOUT_PROTECTED1}
C {devices/netlist_options} 30 -260 0 0 {hiersep=.
}
