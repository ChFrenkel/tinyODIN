// Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "lif_neuron.v" - File containing the 12-bit leaky integrate-and-fire (LIF) neuron update logic, all SDSP-related states
//                  and parameters from ODIN were removed
// 
// Project: tinyODIN - A low-cost digital spiking neuromorphic processor adapted from ODIN.
//
// Author:  C. Frenkel, Delft University of Technology
//
// Cite/paper: C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
//             Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
//             vol. 13, no. 1, pp. 145-158, 2019.
//
//------------------------------------------------------------------------------


module lif_neuron ( 
    input  wire [          6:0] param_leak_str,          // leakage strength parameter
    input  wire [         11:0] param_thr,               // neuron firing threshold parameter 
    
    input  wire [         11:0] state_core,              // core neuron state from SRAM 
    output wire [         11:0] state_core_next,         // next core neuron state to SRAM
    
    input  wire [          3:0] syn_weight,              // synaptic weight
    input  wire                 syn_event,               // synaptic event trigger
    input  wire                 time_ref,                // time reference event trigger
    
    output wire                 spike_out                // neuron spike event output  
);

    reg  [11:0] state_core_next_i;
    wire [11:0] state_leakp_ovfl, state_leakn_ovfl, state_syn_ovfl;
    wire [11:0] state_leakp     , state_leakn     , state_syn     ;
    wire [11:0] syn_weight_ext;
    wire        event_leak;
    wire        event_syn;

    assign event_leak =  syn_event  &  time_ref;
    assign event_syn  =  syn_event  & ~time_ref;

    assign spike_out       = ~state_core_next_i[11] & (state_core_next_i >= param_thr);
    assign state_core_next =  spike_out ? 8'd0 : state_core_next_i;

    assign syn_weight_ext  = syn_weight[3] ? {8'hFF,syn_weight} : {8'h00,syn_weight};

    always @(*) begin 

            if (event_leak)
                if (state_core[11])
                    state_core_next_i = state_leakp;
                else
                    state_core_next_i = state_leakn;
            else if (event_syn)
                    state_core_next_i = state_syn;
            else 
                    state_core_next_i = state_core;
    end

    assign state_leakn_ovfl = (state_core - {5'b0,param_leak_str});
    assign state_leakn      = ( state_leakn_ovfl[11]                  ) ? 12'h000 : state_leakn_ovfl;
    assign state_leakp_ovfl = (state_core + {5'b0,param_leak_str});
    assign state_leakp      = (~state_leakp_ovfl[11]                  ) ? 12'h000 : state_leakp_ovfl;
    assign state_syn_ovfl   = (state_core + syn_weight_ext);
    assign state_syn        = (~state_syn_ovfl[11] &  state_core[11] &  syn_weight_ext[11]) ? 12'h800 :
                             (( state_syn_ovfl[11] & ~state_core[11] & ~syn_weight_ext[11]) ? 12'h7FF : state_syn_ovfl);


endmodule
