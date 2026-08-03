v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Ctrl-Click to execute launcher} 90 -510 0 0 0.3 0.3 {layer=11}
T {possible parameter sweep types:
Auto:Begin:TotalPoints:End
Lin:Begin:StepSize:End
Dec:Begin:PointsPerDecade:End
Log:Begin:TotalPoints:End} 1340 -360 0 0 0.3 0.3 {layer=11}
T {sort .csv file by given index} 1340 -450 0 0 0.3 0.3 {layer=11}
T {number of parallel workers} 1340 -470 0 0 0.3 0.3 {layer=11}
N 110 -180 110 -160 {
lab=GND}
N 270 -180 270 -160 {
lab=GND}
N 110 -320 110 -240 {
lab=isosub_net}
N 110 -320 270 -320 {
lab=isosub_net}
N 270 -320 270 -300 {
lab=isosub_net}
N 270 -240 350 -240 {
lab=nwell_net}
N 270 -320 350 -320 {
lab=isosub_net}
N 350 -240 350 -220 {
lab=nwell_net}
C {devices/title} 245 -55 0 0 {name=l5 author="IHP Open PDK Authors 2025"}
C {devices/gnd} 110 -160 0 0 {name=l6 lab=GND}
C {devices/isource} 110 -210 2 0 {name=I0 value=1m}
C {devices/gnd} 270 -160 0 0 {name=l7 lab=GND}
C {devices/lab_pin} 350 -320 2 0 {name=p6 sig_type=std_logic lab=isosub_net}
C {devices/lab_pin} 350 -240 2 0 {name=p7 sig_type=std_logic lab=nwell_net}
C {sg13g2_pr/isolbox} 270 -240 0 0 {name=D1
model=isolbox
l=\{iso_l\}
w=\{iso_w\}
spiceprefix=X
}
C {devices/noconn} 350 -220 3 0 {name=l8}
