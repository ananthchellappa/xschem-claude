v {xschem version=3.4.5 file_version=1.2
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
B 2 1020 -850 1820 -560 {flags=graph
y1=-0.017
y2=1.3
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=1.23884e-06
x2=1.33992e-06
divx=5
subdivx=1
node="sig_in
x1.integ
vref
x1.q
x1.comp
x1.fb"
color="4 11 10 8 12 9"
dataset=0
unitx=n
}
B 2 1020 -940 1820 -850 {flags=graph
y1=0
y2=1.2
ypos1=0.108246
ypos2=0.224381

subdivy=1
unity=1
x1=1.23884e-06
x2=1.33992e-06
divx=5
subdivx=1
node=ck
color=4
dataset=0
unitx=n
divy=2
digital=1}
P 4 5 700 -480 1680 -480 1680 -90 700 -90 700 -480 {dash=5}
P 5 5 40 -670 690 -670 690 -230 40 -230 40 -670 { dash=5}
T {Modulator} 530 -710 0 0 0.6 0.6 { layer=5}
T {Digital Decimator} 1030 -520 0 0 0.6 0.6 {layer=4}
T {D} 190 -530 0 0 1 1 { layer=5 font=Symbol}
T {S} 370 -650 0 0 1 1 { layer=5 font=Symbol}
T {D-S} 460 -705 0 0 0.6 0.6 { layer=5 font=Symbol}
N 920 -410 940 -410 {lab=Q}
N 940 -410 940 -250 {lab=Q}
N 1640 -430 1700 -430 { lab=CODE[5:0]}
N 1330 -430 1520 -430 { lab=COUNT[5:0]}
N 1180 -170 1180 -150 { lab=#net1}
N 1180 -230 1180 -210 { lab=#net2}
N 1450 -410 1520 -410 { lab=RSTI}
N 1380 -210 1420 -210 { lab=#net3}
N 1540 -270 1540 -230 { lab=RSTI}
N 1450 -270 1540 -270 { lab=RSTI}
N 1450 -410 1450 -270 { lab=RSTI}
N 640 -190 790 -190 { lab=CK}
N 640 -150 790 -150 { lab=RST}
N 670 -410 800 -410 { lab=COMP}
N 210 -250 940 -250 { lab=Q}
N 1080 -410 1170 -410 { lab=QN}
N 940 -410 1000 -410 { lab=Q}
N 520 -440 550 -440 { lab=INTEG}
N 520 -440 520 -400 { lab=INTEG}
N 300 -370 310 -370 { lab=VREF}
N 210 -430 310 -430 {lab=FB}
N 450 -400 520 -400 { lab=INTEG}
N 420 -570 450 -570 { lab=INTEG}
N 450 -570 450 -400 { lab=INTEG}
N 310 -570 360 -570 { lab=FB}
N 120 -430 140 -430 { lab=SIG_IN}
N 310 -570 310 -430 { lab=FB}
N 210 -430 210 -380 { lab=FB}
N 210 -320 210 -250 { lab=Q}
N 430 -400 450 -400 { lab=INTEG}
N 200 -430 210 -430 {lab=FB}
N 1070 -270 1450 -270 { lab=RSTI}
N 1070 -300 1070 -270 { lab=RSTI}
N 1170 -390 1170 -320 { lab=#net4}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/lab_pin} 800 -390 0 0 {name=p4 lab=CK}
C {devices/lab_wire} 760 -410 0 1 {name=l4 lab=COMP}
C {devices/lab_pin} 940 -330 0 1 {name=p8 lab=Q}
C {ngspice/flip_flop_ngspice} 860 -390 0 0 {name=x1}
C {devices/lab_pin} 800 -370 0 0 {name=p3 lab=0}
C {ngspice/counter_6bit_ngspice} 1250 -410 0 0 {name=x2}
C {devices/lab_pin} 1170 -430 0 0 {name=p5 lab=CK}
C {devices/lab_pin} 1070 -340 0 0 {name=p12 lab=RST}
C {ngspice/flip_flop_ngspice} 1580 -410 0 0 {name=x4[5:0]}
C {devices/opin} 1700 -430 0 0 {name=p20 lab=CODE[5:0]}
C {devices/lab_wire} 1350 -430 0 1 {name=l10 lab=COUNT[5:0]}
C {ngspice/counter_6bit_ngspice} 870 -170 0 0 {name=x4}
C {devices/ipin} 640 -190 0 0 {name=p10 lab=CK}
C {devices/ipin} 640 -150 0 0 {name=p11 lab=RST}
C {devices/lab_pin} 790 -170 0 0 {name=p14 lab=VCC}
C {devices/lab_pin} 950 -190 0 1 {name=p24 lab=C[5:0]}
C {ngspice/and3_ngspice} 1120 -230 0 0 {name=x5 ROUT=1000}
C {devices/lab_pin} 1080 -250 0 0 {name=p25 lab=C[5]}
C {devices/lab_pin} 1080 -230 0 0 {name=p26 lab=C[4]}
C {devices/lab_pin} 1080 -210 0 0 {name=p27 lab=C[3]}
C {devices/lab_pin} 1080 -150 0 0 {name=p28 lab=C[1]}
C {devices/lab_pin} 1080 -130 0 0 {name=p29 lab=C[0]}
C {ngspice/and3_ngspice} 1120 -150 0 0 {name=x6 ROUT=1000
}
C {devices/lab_pin} 1080 -170 0 0 {name=p30 lab=C[2]}
C {ngspice/and_ngspice} 1220 -190 0 0 {name=x7 ROUT=1000
}
C {ngspice/or_ngspice} 1320 -210 0 0 {name=x8 ROUT=1000
}
C {devices/lab_pin} 1280 -230 0 0 {name=p31 lab=RST}
C {devices/lab_pin} 1540 -230 0 1 {name=p15 lab=RSTI}
C {ngspice/flip_flop_ngspice} 1480 -210 0 0 {name=x9}
C {devices/lab_pin} 1420 -190 0 0 {name=p32 lab=RST}
C {devices/lab_pin} 1420 -230 0 0 {name=p35 lab=VCC}
C {devices/lab_pin} 1520 -390 0 0 {name=p1 lab=RST}
C {devices/spice_probe} 840 -250 0 0 {name=p6 attrs=""}
C {devices/spice_probe} 710 -410 0 0 {name=p17 attrs=""}
C {devices/spice_probe} 1540 -270 0 0 {name=p18 attrs=""}
C {ngspice/inv_ngspice} 1040 -410 0 0 {name=x11 RUP=1000}
C {devices/lab_wire} 1130 -410 0 0 {name=l2 lab=QN}
C {devices/spice_probe} 1090 -410 0 0 {name=p19 attrs=""}
C {devices/ipin} 300 -370 0 0 {name=p242 lab=VREF}
C {devices/lab_pin} 520 -420 0 0 {name=p244 lab=INTEG}
C {devices/ipin} 120 -430 0 0 {name=p260 lab=SIG_IN}
C {devices/capa} 390 -570 1 0 {name=c10 m=1 value="1e-12"}
C {devices/res} 170 -430 1 0 {name=R4
value=60k
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 550 -380 0 0 {name=p261 lab=VREF}
C {devices/res} 210 -350 0 0 {name=R5
value=60k
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 310 -490 0 0 {name=p262 lab=FB}
C {devices/spice_probe} 450 -500 0 0 {name=p264 attrs=""}
C {devices/spice_probe} 220 -430 0 0 {name=p265 attrs=""}
C {ngspice/opamp_65nm} 370 -400 2 1 {name=x41}
C {ngspice/comp_65nm} 610 -410 0 0 {name=x42}
C {devices/spice_probe} 1470 -430 0 0 {name=p2 attrs=""}
C {ngspice/or_ngspice} 1110 -320 0 0 {name=x3 ROUT=1000}
