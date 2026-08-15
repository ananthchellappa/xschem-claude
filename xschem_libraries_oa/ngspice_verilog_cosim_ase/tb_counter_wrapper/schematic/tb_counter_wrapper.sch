v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
T {These capacitors are used to force
auto-creation of dac bridges
(digital count_out --> analog count_out).
Analog nodes can be plotted and saved
in raw file.} 880 -400 0 0 0.3 0.3 {layer=7}
N 70 -230 70 -210 {lab=CLK}
N 410 -430 460 -430 {lab=CLK}
N 820 -430 860 -430 {bus=1 lab=count_out[3..0]}
N 820 -430 820 -390 {lab=count_out[3..0]}
N 1210 -150 1210 -130 {lab=SUM}
N 790 -150 1210 -150 {lab=SUM}
N 790 -240 790 -210 {lab=count_out3}
N 910 -240 910 -210 {lab=count_out2}
N 1030 -240 1030 -210 {lab=count_out1}
N 1150 -240 1150 -210 {lab=count_out0}
N 600 -430 820 -430 {bus=1 lab=count_out[3..0]}
C {devices/vsource} 70 -180 0 0 {name=VCLOCK value="pulse 0 'VDD' 49995p 10p 10p 49990p 100n"}
C {devices/lab_pin} 70 -150 0 0 {name=p6 lab=0}
C {devices/lab_pin} 70 -230 0 0 {name=p13 lab=CLK}
C {devices/lab_pin} 410 -430 0 0 {name=p3 lab=CLK}
C {devices/lab_pin} 860 -430 0 1 {name=p4 lab=count_out[3..0]}
C {ngspice_verilog_cosim_ase/counter} 530 -430 0 0 {name=a1 model=counter

**** put an asteric or any other character before (and no spaces in between)
**** the model you DON'T want to use:

***Verilator***
device_model=".model counter d_cosim simulation=\\"./counter.so\\" sim_args=[\\"counter.vcd\\"] delay=0"

***Icarus_verilog***
*device_model=".model counter d_cosim simulation=\\"ivlng\\" sim_args=[\\"counter\\"] delay=0"

tclcommand="edit_file [xschem cellview_path ngspice_verilog_cosim_ase/counter verilog]"}
C {devices/parax_cap} 820 -380 0 0 {name=C2[3..0] gnd=0 value=1f m=1}
C {devices/ammeter} 1210 -100 0 0 {name=VAMM savecurrent=0 spice_ignore=0}
C {devices/lab_pin} 1210 -70 0 0 {name=p35 lab=0}
C {devices/res} 790 -180 0 0 {name=R4
value=8
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 790 -240 0 0 {name=p44 lab=count_out3}
C {devices/res} 910 -180 0 0 {name=R5
value=16
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 910 -240 0 0 {name=p45 lab=count_out2}
C {devices/res} 1030 -180 0 0 {name=R6
value=32
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 1030 -240 0 0 {name=p46 lab=count_out1}
C {devices/res} 1150 -180 0 0 {name=R7
value=64
footprint=1206
device=resistor
m=1}
C {devices/lab_pin} 1150 -240 0 0 {name=p47 lab=count_out0}
C {devices/lab_pin} 1210 -150 0 1 {name=p48 lab=SUM}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
