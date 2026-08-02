v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
B 2 150 -490 950 -90 {flags=graph
y1=-0
y2=0.00012
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=0
x2=3
divx=5
subdivx=1
node=i(vd)
color=4
dataset=-1
unitx=1
logx=0
logy=0
sim_type=dc
autoload=1}
T {Ctrl-Click to execute launcher} 610 -70 0 0 0.3 0.3 {layer=11}
T {.save file can be created with IHP->"Create FET and BIP .save file"} 610 50 0 0 0.3 0.3 {layer=11}
N -110 70 -110 90 {
lab=GND}
N -110 -0 -110 10 {
lab=#net1}
N 20 30 20 90 {
lab=GND}
N 150 30 150 90 {
lab=GND}
N 20 -70 20 -30 {
lab=#net2}
N 150 -70 150 -30 {
lab=#net3}
N 20 0 70 0 {
lab=GND}
N 70 0 70 90 {
lab=GND}
N 20 -70 50 -70 {
lab=#net2}
N 110 -70 150 -70 {
lab=#net3}
N -110 0 -20 0 {
lab=#net1}
C {devices/code_shown} -200 160 0 0 {name=MODEL only_toplevel=true
format="tcleval( @value )"
value="
.lib $::MODELS_NGSPICE/cornerMOShv.lib mos_tt
"}
C {devices/code_shown} 220 0 0 0 {name=NGSPICE only_toplevel=true 
value="
.options savecurrents
.include dc_hv_nmos.save
.param temp=27
.control 
save all
op
write dc_hv_nmos.raw
set appendwrite
dc Vds 0 3.0 0.01 Vgs 0.3 1.5 0.05
write dc_hv_nmos.raw
.endc
"}
C {devices/gnd} 20 90 0 0 {name=l1 lab=GND}
C {devices/gnd} -110 90 0 0 {name=l2 lab=GND}
C {devices/vsource} -110 40 0 0 {name=Vgs value=0.75}
C {devices/vsource} 150 0 0 0 {name=Vds value=1.5}
C {devices/gnd} 150 90 0 0 {name=l3 lab=GND}
C {devices/gnd} 70 90 0 0 {name=l4 lab=GND}
C {devices/title} -130 260 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/ammeter} 80 -70 1 0 {name=Vd}
C {sg13g2_pr/annotate_fet_params} -120 -140 0 0 {name=annot1 ref=M1}
C {sg13g2_pr/sg13_hv_nmos} 0 0 0 0 {name=M1
l=0.45u
w=1.0u
ng=1
m=1
model=sg13_hv_nmos
spiceprefix=X
}
C {devices/launcher} 670 0 0 0 {name=h1
descr="OP annotate" 
tclcommand="xschem annotate_op"
}
C {devices/launcher} 670 30 0 0 {name=h2
descr="Load waves" 
tclcommand="
xschem raw_read $netlist_dir/[file rootname [file tail [xschem get current_name]]].raw dc
xschem setprop rect 2 0 fullxzoom
"
}
C {devices/launcher} 670 -30 0 0 {name=h3
descr=SimulateNGSPICE
tclcommand="
# Setup the default simulation commands if not already set up
# for example by already launched simulations.
set_sim_defaults
puts $sim(spice,1,cmd) 

# Change the Xyce command. In the spice category there are currently
# 5 commands (0, 1, 2, 3, 4). Command 3 is the Xyce batch
# you can get the number by querying $sim(spice,n)
set sim(spice,1,cmd) \{ngspice  \\"$N\\" -a\}

# change the simulator to be used (Xyce)
set sim(spice,default) 0

# Create FET and BIP .save file
file mkdir $netlist_dir
write_data [sg13g2_save_params] $netlist_dir/[file rootname [file tail [xschem get current_name]]].save

# run netlist and simulation
xschem netlist
simulate
"}
