# Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
#         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file except in compliance
# with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
# https://solderpad.org/licenses/SHL-2.1/
#
# Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
# an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.
#
#------------------------------------------------------------------------------
#
# "tinyODIN.sdc" - Sample SDC constraints file
# 
# Project: tinyODIN - A low-cost digital spiking neuromorphic processor adapted from ODIN.
#
# Author:  C. Frenkel, Delft University of Technology
#
# Cite/paper: C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
#             Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
#             vol. 13, no. 1, pp. 145-158, 2019.
#
#------------------------------------------------------------------------------


#####################################
#                                   #
#      Timing in active mode        #
#                                   #
#####################################

set CLK_PERIOD  	4
set SCK_PERIOD  	50

set IO_DLY			5

set CLK_LATENCY		0.5
set CLK_UNCERTAINTY	0.2
set CLK_TRAN	    0.2


#####################################
#                                   #
#      		Main clocks		   	 	#
#                                   #
#####################################

# Controller clock
create_clock -name "CLK" -period "$CLK_PERIOD" -waveform "0 [expr $CLK_PERIOD/2]" [get_ports CLK]

# SPI slave clock
create_clock -name "SCK" -period "$SCK_PERIOD" -waveform "0 [expr $SCK_PERIOD/2]" [get_ports SCK]

set_clock_groups -asynchronous -group "CLK" -group "SCK"

# Clock distribution latency and uncertainty
set_clock_latency 		$CLK_LATENCY 		[all_clocks]
set_clock_uncertainty 	$CLK_UNCERTAINTY	[all_clocks]
set_clock_transition    $CLK_TRAN           [all_clocks]


#####################################
#                                   #
#         BOUNDARY CONDITIONS	    #
#                                   #
#####################################

set_driving_cell -lib_cell {SET_YOUR_DRIVING_CELL_HERE} -library {SET_YOUR_LIBRARY_HERE} [all_inputs]

set_load -pin_load 0.050 [all_outputs]



#####################################
#                                   #
#         INPUT/OUPUT DELAYS	    #
#                                   #
#####################################

# False paths
set_false_path		-through [get_ports RST] 	
set_false_path		-through [get_ports AERIN_ADDR] 
set_false_path		-through [get_ports AERIN_REQ] 
set_false_path		-through [get_ports AERIN_ACK]   	
set_false_path		-through [get_ports AEROUT_ADDR] 
set_false_path		-through [get_ports AEROUT_REQ] 
set_false_path		-through [get_ports AEROUT_ACK] 
set_false_path		-through [get_ports SCHED_FULL] 

# INPUT from I/O buffers - mosi
set_input_delay  [expr $IO_DLY]  -network_latency_included -max -clock "SCK" -clock_fall [get_ports MOSI]
set_input_delay  [expr -$IO_DLY] -network_latency_included -min -clock "SCK" -clock_fall [get_ports MOSI]

# OUTPUTS to I/O buffers - miso
set_output_delay [expr $IO_DLY]  -network_latency_included -max -clock "SCK" [get_ports MISO]
set_output_delay [expr -$IO_DLY] -network_latency_included -min -clock "SCK" [get_ports MISO]
