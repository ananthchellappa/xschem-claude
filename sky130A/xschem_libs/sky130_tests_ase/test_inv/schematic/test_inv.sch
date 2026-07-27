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
T {Simple ring oscillator for
speed testing} 1030 -800 0 0 0.6 0.6 {layer=4}
N 360 -290 360 -130 { lab=Z[2]}
N 440 -290 440 -130 { lab=Z[3]}
N 520 -290 520 -130 { lab=Z[4]}
N 600 -290 600 -130 { lab=Z[5]}
N 680 -290 680 -130 { lab=Z[6]}
N 760 -190 760 -130 { lab=Z[0]}
N 760 -190 820 -190 { lab=Z[0]}
N 820 -190 820 -80 { lab=Z[0]}
N 160 -80 820 -80 { lab=Z[0]}
N 160 -190 160 -80 { lab=Z[0]}
N 160 -190 200 -190 { lab=Z[0]}
N 200 -290 200 -190 { lab=Z[0]}
N 210 -300 760 -300 {bus=true lab=Z[6:0]}
N 1100 -290 1100 -130 { lab=Y[2]}
N 1180 -290 1180 -130 { lab=Y[3]}
N 1260 -290 1260 -130 { lab=Y[4]}
N 1340 -290 1340 -130 { lab=Y[5]}
N 1420 -290 1420 -130 { lab=Y[6]}
N 1500 -190 1500 -130 { lab=Y[0]}
N 1500 -190 1560 -190 { lab=Y[0]}
N 1560 -190 1560 -80 { lab=Y[0]}
N 900 -80 1560 -80 { lab=Y[0]}
N 900 -190 900 -80 { lab=Y[0]}
N 900 -190 940 -190 { lab=Y[0]}
N 940 -290 940 -190 { lab=Y[0]}
N 950 -300 1500 -300 {bus=true lab=Y[6:0]}
N 280 -290 280 -130 { lab=Z[1]}
N 1020 -290 1020 -130 { lab=Y[1]}
C {devices/title} 160 -30 0 0 {name=l1 author="Stefan Schippers"}
C {devices/parax_cap} 280 -120 0 0 {name=C1 gnd=0 value=4f m=1}
C {devices/parax_cap} 360 -120 0 0 {name=C2 gnd=0 value=4f m=1}
C {devices/parax_cap} 440 -120 0 0 {name=C3 gnd=0 value=4f m=1}
C {devices/parax_cap} 520 -120 0 0 {name=C4 gnd=0 value=4f m=1}
C {devices/parax_cap} 600 -120 0 0 {name=C5 gnd=0 value=4f m=1}
C {devices/parax_cap} 680 -120 0 0 {name=C6 gnd=0 value=4f m=1}
C {devices/parax_cap} 760 -120 0 0 {name=C7 gnd=0 value=4.01f m=1}
C {devices/lab_pin} 760 -300 0 1 {name=l9 sig_type=std_logic lab=Z[6:0]}
C {devices/parax_cap} 1020 -120 0 0 {name=C8 gnd=0 value=4f m=1}
C {devices/parax_cap} 1100 -120 0 0 {name=C9 gnd=0 value=4f m=1}
C {devices/parax_cap} 1180 -120 0 0 {name=C10 gnd=0 value=4f m=1}
C {devices/parax_cap} 1260 -120 0 0 {name=C11 gnd=0 value=4f m=1}
C {devices/parax_cap} 1340 -120 0 0 {name=C12 gnd=0 value=4f m=1}
C {devices/parax_cap} 1420 -120 0 0 {name=C13 gnd=0 value=4f m=1}
C {devices/parax_cap} 1500 -120 0 0 {name=C14 gnd=0 value=4.01f m=1}
C {devices/lab_pin} 1500 -300 0 1 {name=l17 sig_type=std_logic lab=Y[6:0]}
C {sky130_tests/not} 240 -190 0 0 {name=x4 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.15}
C {sky130_tests/not} 320 -190 0 0 {name=x1 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.15}
C {sky130_tests/not} 400 -190 0 0 {name=x2 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.15}
C {sky130_tests/not} 480 -190 0 0 {name=x3 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.15}
C {sky130_tests/not} 560 -190 0 0 {name=x5 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.15}
C {sky130_tests/not} 640 -190 0 0 {name=x6 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.15}
C {sky130_tests/not} 720 -190 0 0 {name=x7 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.15}
C {sky130_tests/lvtnot} 980 -190 0 0 {name=x8 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.35}
C {sky130_tests/lvtnot} 1060 -190 0 0 {name=x9 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.35}
C {sky130_tests/lvtnot} 1140 -190 0 0 {name=x10 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.35}
C {sky130_tests/lvtnot} 1220 -190 0 0 {name=x11 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.35}
C {sky130_tests/lvtnot} 1300 -190 0 0 {name=x12 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.35}
C {sky130_tests/lvtnot} 1380 -190 0 0 {name=x13 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.35}
C {sky130_tests/lvtnot} 1460 -190 0 0 {name=x14 m=1 VCCPIN=VCC VSSPIN=VSS W_N=WN L_N=0.15 W_P=WP L_P=0.35}
C {devices/bus_tap} 210 -300 3 1 {name=l19 lab=[0]}
C {devices/bus_tap} 290 -300 3 1 {name=l2 lab=[1]}
C {devices/bus_tap} 370 -300 3 1 {name=l3 lab=[2]}
C {devices/bus_tap} 450 -300 3 1 {name=l4 lab=[3]}
C {devices/bus_tap} 530 -300 3 1 {name=l5 lab=[4]}
C {devices/bus_tap} 610 -300 3 1 {name=l6 lab=[5]}
C {devices/bus_tap} 690 -300 3 1 {name=l7 lab=[6]}
C {devices/bus_tap} 950 -300 3 1 {name=l8 lab=[0]}
C {devices/bus_tap} 1030 -300 3 1 {name=l10 lab=[1]}
C {devices/bus_tap} 1110 -300 3 1 {name=l11 lab=[2]}
C {devices/bus_tap} 1190 -300 3 1 {name=l12 lab=[3]}
C {devices/bus_tap} 1270 -300 3 1 {name=l13 lab=[4]}
C {devices/bus_tap} 1350 -300 3 1 {name=l14 lab=[5]}
C {devices/bus_tap} 1430 -300 3 1 {name=l15 lab=[6]}
