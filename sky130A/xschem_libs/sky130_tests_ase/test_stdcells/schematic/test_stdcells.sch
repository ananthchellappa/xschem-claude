v {xschem version=3.4.6 file_version=1.2
* Copyright 2021 Stefan Frederik Schippers
* 
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     https://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.

}
G {}
K {}
V {}
S {}
E {}
T {Comparison of transistor level vs Xspice simulation
xspice netlist obtained with spi2xspice.py script
from qflow.} 340 -1720 0 0 1 1 {}
T {these small capacitors force ngspice
auto-insertion of d2a bridges} 1640 -280 0 0 0.4 0.4 {}
N 50 -670 50 -650 { lab=A}
N 50 -560 50 -540 { lab=B}
N 50 -810 50 -790 { lab=CLK}
N 50 -930 50 -910 { lab=RESET_B}
N 1730 -210 1800 -210 {
lab=X_QLATCH}
N 1670 -190 1800 -190 {
lab=X_X}
N 1730 -170 1800 -170 {
lab=X_Y}
N 1670 -150 1800 -150 {
lab=X_Q}
N 1730 -130 1800 -130 {
lab=X_XSCHEM}
C {devices/sqwsource} 50 -620 0 0 {name=V1 vhi='vcc' freq=0.09e9}
C {devices/sqwsource} 50 -510 0 0 {name=V2 vhi='vcc' freq=0.02e9}
C {devices/lab_pin} 50 -480 0 0 {name=p4 lab=0}
C {devices/lab_pin} 50 -590 0 0 {name=p5 lab=0}
C {devices/lab_pin} 50 -670 0 1 {name=p6 lab=A}
C {devices/lab_pin} 50 -560 0 1 {name=p7 lab=B}
C {devices/sqwsource} 50 -760 0 0 {name=V3 vhi='vcc' freq=0.2e9}
C {devices/lab_pin} 50 -730 0 0 {name=p8 lab=0}
C {devices/lab_pin} 50 -810 0 1 {name=p9 lab=CLK}
C {devices/sqwsource} 50 -880 0 0 {name=V4 vhi='vcc' freq=0.7e8}
C {devices/lab_pin} 50 -850 0 0 {name=p12 lab=0}
C {devices/lab_pin} 50 -930 0 1 {name=p13 lab=RESET_B}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {sky130_tests/stdcells} 1340 -280 0 0 {name=x2}
C {devices/lab_pin} 1490 -330 0 1 {name=p1 lab=QLATCH}
C {devices/lab_pin} 1190 -330 0 0 {name=p2 lab=A}
C {devices/lab_pin} 1490 -310 0 1 {name=p3 lab=X}
C {devices/lab_pin} 1190 -310 0 0 {name=p4 lab=B}
C {devices/lab_pin} 1490 -290 0 1 {name=p5 lab=Y}
C {devices/lab_pin} 1190 -290 0 0 {name=p6 lab=CLK}
C {devices/lab_pin} 1490 -270 0 1 {name=p7 lab=Q}
C {devices/lab_pin} 1190 -270 0 0 {name=p8 lab=RESET_B}
C {devices/lab_pin} 1490 -250 0 1 {name=p9 lab=XSCHEM}
C {devices/lab_pin} 1190 -250 0 0 {name=p10 lab=VCC}
C {devices/lab_pin} 1190 -230 0 0 {name=p11 lab=VSS}
C {sky130_tests_ase/stdcells_xspice} 1340 -130 0 0 {name=x1}
C {devices/lab_pin} 1490 -180 0 1 {name=p1 lab=X_QLATCH}
C {devices/lab_pin} 1190 -180 0 0 {name=p2 lab=A}
C {devices/lab_pin} 1490 -160 0 1 {name=p3 lab=X_X}
C {devices/lab_pin} 1190 -160 0 0 {name=p4 lab=B}
C {devices/lab_pin} 1490 -140 0 1 {name=p5 lab=X_Y}
C {devices/lab_pin} 1190 -140 0 0 {name=p6 lab=CLK}
C {devices/lab_pin} 1490 -120 0 1 {name=p7 lab=X_Q}
C {devices/lab_pin} 1190 -120 0 0 {name=p8 lab=RESET_B}
C {devices/lab_pin} 1490 -100 0 1 {name=p9 lab=X_XSCHEM}
C {devices/lab_pin} 1190 -100 0 0 {name=p10 lab=VCC}
C {devices/lab_pin} 1190 -80 0 0 {name=p11 lab=VSS}
C {devices/lab_pin} 700 -90 0 0 {name=p14 lab=VCC}
C {devices/lab_pin} 700 -70 0 0 {name=p15 lab=VSS}
C {devices/noconn} 700 -90 0 1 {name=l2}
C {devices/noconn} 700 -70 0 1 {name=l3}
C {devices/lab_pin} 1800 -210 0 1 {name=p16 lab=X_QLATCH}
C {devices/lab_pin} 1800 -190 0 1 {name=p17 lab=X_X}
C {devices/lab_pin} 1800 -170 0 1 {name=p18 lab=X_Y}
C {devices/lab_pin} 1800 -150 0 1 {name=p19 lab=X_Q}
C {devices/lab_pin} 1800 -130 0 1 {name=p20 lab=X_XSCHEM}
C {devices/parax_cap} 1720 -210 1 0 {name=C1 gnd=0 value=4f m=1}
C {devices/parax_cap} 1660 -190 1 0 {name=C2 gnd=0 value=4f m=1}
C {devices/parax_cap} 1720 -170 1 0 {name=C3 gnd=0 value=4f m=1}
C {devices/parax_cap} 1660 -150 1 0 {name=C4 gnd=0 value=4f m=1}
C {devices/parax_cap} 1720 -130 1 0 {name=C5 gnd=0 value=4f m=1}
C {devices/code} 1440 -930 0 0 {name=ASE_KEEP1
only_toplevel=true
value="
.model ddflop d_dff(ic=0 rise_delay=200p fall_delay=200p clk_delay=20p reset_delay=20p data_load=10f reset_load=10f clk_load=10f)
.model dlatch d_dlatch(ic=0 rise_delay=200p fall_delay=200p data_delay = 20p enable_delay=20p reset_delay=200p data_load=10f reset_load=10f enable_load=10f)
.model dzero d_pulldown(load=10f)
.model done d_pullup(load=10f)
.model d_lut_sky130_fd_sc_hd__nand2_1 d_lut (rise_delay=200p fall_delay=200p input_load=10f table_values \\"1110\\")
.model d_lut_sky130_fd_sc_hd__nor2b_1 d_lut (rise_delay=200p fall_delay=200p input_load=10f table_values \\"0010\\")
.model d_lut_sky130_fd_sc_hd__a31o_2 d_lut (rise_delay=200p fall_delay=200p input_load=10f table_values \\"0000000111111111\\")
.model d_lut_sky130_fd_sc_hd__inv_2 d_lut (rise_delay=200p fall_delay=200p input_load=10f table_values \\"10\\")
.model d_lut_sky130_fd_sc_hd__buf_2 d_lut (rise_delay=200p fall_delay=200p input_load=10f table_values \\"01\\")
"}
C {devices/code} 1430 -1470 0 0 {name=ASE_KEEP2
only_toplevel=true
value="
vvcc vcc 0 dc 'vcc'
vvss vss 0 0
"}
