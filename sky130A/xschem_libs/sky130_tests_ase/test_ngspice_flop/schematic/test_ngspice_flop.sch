v {xschem version=3.0.0 file_version=1.2 }
G {}
K {}
V {}
S {}
E {}
C {sky130_tests/ngspice_flop} 380 -110 0 0 {name=x1}
C {devices/lab_pin} 230 -100 0 0 {name=p1 lab=A_VDD}
C {devices/lab_pin} 530 -130 0 1 {name=p2 lab=A_OUT}
C {devices/lab_pin} 230 -140 0 0 {name=p3 lab=A_IN}
C {devices/lab_pin} 230 -120 0 0 {name=p4 lab=A_CLK}
C {devices/lab_pin} 230 -80 0 0 {name=p5 lab=A_GND}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/iopin} 90 -150 0 1 { name=p6 lab=A_VDD }
C {devices/ipin} 90 -240 0 0 { name=p7 lab=A_IN }
C {devices/iopin} 90 -190 0 1 { name=p8 lab=A_GND }
C {devices/ipin} 90 -280 0 0 { name=p9 lab=A_CLK }
C {devices/opin} 160 -240 0 0 { name=p10 lab=A_OUT }
C {devices/code} 20 -570 0 0 {name=ASE_KEEP1
only_toplevel=true
value="
.opton wnflag=1
va_vdd a_vdd 0 dc 3.3
va_gnd a_gnd 0 dc 0
va_in a_in 0 pulse 0 3.3 10n 0.1n 0.1n 83n 171n
va_clk a_clk 0 pulse 0 3.3 2n 0.1n 0.1n 25n 50n
"}
