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
N 90 -460 130 -460 { lab=D}
N 500 -570 520 -570 { lab=DI}
N 500 -570 500 -460 { lab=DI}
N 870 -460 1030 -460 { lab=QI}
N 970 -570 990 -570 { lab=QI}
N 970 -570 970 -460 { lab=QI}
N 1110 -460 1160 -460 { lab=Q}
N 990 -460 990 -360 { lab=QI}
N 990 -300 990 -260 { lab=0}
N 790 -460 870 -460 { lab=QI}
N 690 -460 730 -460 { lab=#net1}
N 670 -460 690 -460 { lab=#net1}
N 460 -460 590 -460 { lab=DI}
N 340 -460 400 -460 { lab=#net2}
N 520 -460 520 -360 { lab=DI}
N 520 -300 520 -260 { lab=0}
N 210 -460 280 -460 { lab=#net3}
C {devices/ipin} 70 -240 0 0 {name=p1 lab=D}
C {devices/ipin} 70 -200 0 0 {name=p2 lab=CLK}
C {devices/ipin} 70 -160 0 0 {name=p3 lab=RST}
C {devices/opin} 250 -200 0 0 {name=p4 lab=Q}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {ngspice/keeper_ngspice} 560 -570 0 0 {name=x2}
C {devices/switch_ngspice} 310 -460 1 1 {name=S1 model=SWITCH}
C {devices/lab_pin} 310 -420 0 1 {name=l4 sig_type=std_logic lab=VCC}
C {devices/lab_pin} 290 -420 0 0 {name=l5 sig_type=std_logic lab=CLK}
C {devices/lab_pin} 90 -460 0 0 {name=l6 sig_type=std_logic lab=D}
C {devices/switch_ngspice} 760 -460 1 1 {name=S2 model=SWITCH}
C {devices/lab_pin} 740 -420 0 0 {name=l7 sig_type=std_logic lab=0}
C {devices/lab_pin} 760 -420 0 1 {name=l8 sig_type=std_logic lab=CLK}
C {ngspice/keeper_ngspice} 1030 -570 0 0 {name=x3}
C {devices/lab_pin} 500 -480 0 1 {name=l9 sig_type=std_logic lab=DI}
C {ngspice/buf_ngspice} 1070 -460 0 0 {name=x4 RUP=100 RDOWN=100}
C {devices/lab_pin} 970 -480 0 0 {name=l10 sig_type=std_logic lab=QI}
C {devices/lab_pin} 1160 -460 0 1 {name=l11 sig_type=std_logic lab=Q}
C {devices/switch_ngspice} 990 -330 0 0 {name=S3 model=SWITCH}
C {devices/lab_pin} 990 -260 0 0 {name=l2 sig_type=std_logic lab=0}
C {devices/lab_pin} 950 -310 0 0 {name=l3 sig_type=std_logic lab=0}
C {devices/lab_pin} 950 -330 0 0 {name=l12 sig_type=std_logic lab=RST}
C {ngspice/buf_ngspice} 630 -460 0 0 {name=x1
RUP=1000}
C {devices/switch_ngspice} 430 -460 1 1 {name=S4 model=SWITCH}
C {devices/lab_pin} 430 -420 0 1 {name=l13 sig_type=std_logic lab=VCC}
C {devices/lab_pin} 410 -420 0 0 {name=l14 sig_type=std_logic lab=RST}
C {devices/switch_ngspice} 520 -330 0 0 {name=S5 model=SWITCH}
C {devices/lab_pin} 520 -260 0 0 {name=l15 sig_type=std_logic lab=0}
C {devices/lab_pin} 480 -310 0 0 {name=l16 sig_type=std_logic lab=0}
C {devices/lab_pin} 480 -330 0 0 {name=l17 sig_type=std_logic lab=RST}
C {ngspice/buf_ngspice} 170 -460 0 0 {name=x5
RUP=1000}
