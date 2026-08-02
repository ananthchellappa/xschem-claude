v {xschem version=3.4.6 file_version=1.2
* Copyright 2023 IHP PDK Authors
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
L 7 360 -810 360 -60 {}
L 7 700 -810 700 -60 {}
L 7 1040 -810 1040 -60 {}
L 7 1380 -810 1380 -60 {}
L 7 20 -810 20 -60 {}
L 7 1720 -810 1720 -60 {}
L 7 2060 -810 2060 -60 {}
L 7 2400 -810 2400 -60 {}
T {DC} 40 -790 0 0 0.8 0.8 {}
T {Transient} 380 -790 0 0 0.8 0.8 {}
T {AC} 730 -790 0 0 0.8 0.8 {}
T {Monte Carlo} 1060 -790 0 0 0.8 0.8 {}
T {S-param} 1420 -790 0 0 0.8 0.8 {}
T {Tools} 1770 -790 0 0 0.8 0.8 {}
T {Isolated} 2110 -790 0 0 0.8 0.8 {}
C {devices/title} 160 -30 0 0 {name=l5 author="Copyright 2023 IHP PDK Authors"}
C {devices/launcher} 90 -860 0 0 {name=h1
descr="IHP-Open-PDK"
url="https://github.com/IHP-GmbH/IHP-Open-PDK/tree/main"}
C {sg13g2_tests/dc_hv_nmos} 180 -680 0 0 {name=x6}
C {sg13g2_tests/dc_lv_pmos} 180 -650 0 0 {name=x7}
C {sg13g2_tests/dc_hv_pmos} 180 -620 0 0 {name=x8}
C {sg13g2_tests/dc_mos_temp} 180 -590 0 0 {name=x11}
C {sg13g2_tests/dc_mos_cs_temp} 180 -560 0 0 {name=x12}
C {sg13g2_tests/dc_res_temp} 180 -520 0 0 {name=x13}
C {sg13g2_tests/dc_diode_op} 180 -400 0 0 {name=x14}
C {sg13g2_tests/dc_diode_temp} 180 -370 0 0 {name=x15}
C {sg13g2_tests/dc_hbt_13g2} 180 -340 0 0 {name=x17}
C {sg13g2_tests/tran_mim_cap} 520 -710 0 0 {name=x10}
C {sg13g2_tests/ac_lv_nmosrf} 860 -710 0 0 {name=x9}
C {sg13g2_tests/ac_mim_cap} 860 -670 0 0 {name=x21}
C {sg13g2_tests/mc_lv_nmos_cs_loop} 1200 -710 0 0 {name=x1}
C {sg13g2_tests/mc_hv_nmos_cs_loop} 1200 -670 0 0 {name=x2}
C {sg13g2_tests/mc_lv_pmos_cs_loop} 1200 -630 0 0 {name=x3}
C {sg13g2_tests/mc_hv_pmos_cs_loop} 1200 -590 0 0 {name=x4}
C {sg13g2_tests/mc_res_op} 1200 -550 0 0 {name=x16}
C {sg13g2_tests/mc_hbt_13g2} 1200 -510 0 0 {name=x18}
C {sg13g2_tests/mc_hbt_13g2_ac} 1200 -480 0 0 {name=x19}
C {sg13g2_tests/mc_mim_cap_ac} 1200 -440 0 0 {name=x24}
C {sg13g2_tests/sp_mim_cap} 1540 -710 0 0 {name=x20}
C {sg13g2_tests/sp_parasitic_cap} 1540 -670 0 0 {name=x22}
C {sg13g2_tests/sp_rfmim_cap} 1540 -630 0 0 {name=x23}
C {sg13g2_tests/dc_ntap1} 180 -480 0 0 {name=x25}
C {sg13g2_tests/dc_ptap1} 180 -440 0 0 {name=x26}
C {sg13g2_tests/tran_logic_not} 520 -670 0 0 {name=x27}
C {sg13g2_tests/dc_logic_not} 180 -240 0 0 {name=x28}
C {sg13g2_tests/tran_logic_nand} 520 -630 0 0 {name=x29}
C {sg13g2_tests/dc_pnpMPA} 180 -280 0 0 {name=x30}
C {sg13g2_tests/dc_lv_nmos} 180 -710 0 0 {name=x5}
C {sg13g2_tests/tran_bondpad} 520 -590 0 0 {name=x31}
C {sg13g2_tests/dc_esd_diodes} 180 -200 0 0 {name=x31}
C {sg13g2_tests/dc_esd_nmos_cl} 180 -160 0 0 {name=x32}
C {sg13g2_tests/dc_hbt_13g2_5t} 180 -310 0 0 {name=x33}
C {sg13g2_tests/inv_mc_tb} 1890 -710 0 0 {name=x34}
C {sg13g2_tests/inv_sweep_tb} 1890 -670 0 0 {name=x35}
C {sg13g2_tests/dc_isolbox} 180 -120 0 0 {name=x36}
C {sg13g2_tests/isolbox_sweep_tb} 1890 -630 0 0 {name=x37}
C {sg13g2_tests/iso_dc_lv_nmos} 2220 -710 0 0 {name=x38}
C {sg13g2_tests/iso_dc_hv_nmos} 2220 -670 0 0 {name=x39}
C {sg13g2_tests/iso_dc_res} 2220 -630 0 0 {name=x40}
C {sg13g2_tests/dc_schottky} 180 -80 0 0 {name=x41}
