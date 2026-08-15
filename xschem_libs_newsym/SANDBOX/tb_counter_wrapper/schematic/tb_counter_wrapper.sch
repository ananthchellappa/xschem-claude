v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
T {a1 is a code block: cell SANDBOX/counter has NO schematic view -- symbol + verilog only.
Select it and press Ctrl-Alt-V: the signal browser lists phase, half, prev, next_count,
tc and carry, which exist only inside the digital simulator and in no .raw file.
C2[3..0] is the only analog load on the digital bus, and the reason count_out3..0
reach the .raw at all: it forces the auto dac_bridges.} 60 -560 0 0 0.25 0.25 {layer=7}
N 70 -430 70 -410 {lab=CLK}
N 410 -430 460 -430 {lab=CLK}
N 600 -430 820 -430 {bus=1 lab=count_out[3..0]}
N 820 -430 860 -430 {bus=1 lab=count_out[3..0]}
N 820 -430 820 -390 {lab=count_out[3..0]}
C {devices/vsource} 70 -380 0 0 {name=VCLOCK value="pulse 0 'VDD' 49995p 10p 10p 49990p 100n"}
C {devices/lab_pin} 70 -350 0 0 {name=p6 lab=0}
C {devices/lab_pin} 70 -430 0 0 {name=p13 lab=CLK}
C {devices/lab_pin} 410 -430 0 0 {name=p3 lab=CLK}
C {devices/lab_pin} 860 -430 0 1 {name=p4 lab=count_out[3..0]}
C {SANDBOX/counter} 530 -430 0 0 {name=a1 model=counter

**** put an asteric or any other character before (and no spaces in between)
**** the model you DON'T want to use:

***Verilator***
device_model=".model counter d_cosim simulation=\\"./counter.so\\" sim_args=[\\"counter.vcd\\"] delay=0"

***Icarus_verilog***
*device_model=".model counter d_cosim simulation=\\"ivlng\\" sim_args=[\\"counter\\"] delay=0"

tclcommand="edit_file [xschem cellview_path SANDBOX/counter verilog]"}
C {devices/parax_cap} 820 -380 0 0 {name=C2[3..0] gnd=0 value=1f m=1}
