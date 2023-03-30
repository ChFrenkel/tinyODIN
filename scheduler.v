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
// "scheduler.v" - Scheduler module, rotating FIFOs removed from the original ODIN scheduler
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

 
module scheduler #(
    parameter                   N = 256,
    parameter                   M = 8
)( 

    // Global inputs ------------------------------------------
    input  wire                 CLK,
    input  wire                 RSTN,
    
    // Inputs from controller ---------------------------------
    input  wire                 CTRL_SCHED_POP_N,
    input  wire [          3:0] CTRL_SCHED_VIRTS,
    input  wire [          7:0] CTRL_SCHED_ADDR,
    input  wire                 CTRL_SCHED_EVENT_IN,
    
    // Inputs from neurons ------------------------------------
    input  wire [        M-1:0] CTRL_NEURMEM_ADDR,
    input  wire                 NEUR_EVENT_OUT,
    
    // Inputs from SPI configuration registers ----------------
    input  wire                 SPI_OPEN_LOOP,
    
    // Outputs ------------------------------------------------
    output wire                 SCHED_EMPTY,
    output wire                 SCHED_FULL,
    output wire [         11:0] SCHED_DATA_OUT
);

    reg                    SPI_OPEN_LOOP_sync_int, SPI_OPEN_LOOP_sync;

    wire                   push_req_n;

    wire                   empty_main;
    wire                   full_main;
    wire [           11:0] data_out_main;


    // Sync barrier from SPI

    always @(posedge CLK, negedge RSTN) begin
        if(~RSTN) begin
            SPI_OPEN_LOOP_sync_int  <= 1'b0;
            SPI_OPEN_LOOP_sync	    <= 1'b0;
        end
        else begin
            SPI_OPEN_LOOP_sync_int  <= SPI_OPEN_LOOP;
            SPI_OPEN_LOOP_sync	    <= SPI_OPEN_LOOP_sync_int;
        end
    end


    // FIFO instances

    fifo #(
        .width(12),
        .depth(128),
        .depth_addr(7)
    ) fifo_spike_0 (
        .clk(CLK),
        .rst_n(RSTN),
        .push_req_n(full_main | push_req_n),
        .pop_req_n(empty_main | CTRL_SCHED_POP_N),
        .data_in(CTRL_SCHED_EVENT_IN ? {CTRL_SCHED_VIRTS,CTRL_SCHED_ADDR} : {4'b0,CTRL_NEURMEM_ADDR}),
        .empty(empty_main),
        .full(full_main),
        .data_out(data_out_main)
    );

    assign push_req_n = ~((~SPI_OPEN_LOOP_sync & NEUR_EVENT_OUT) | CTRL_SCHED_EVENT_IN);


    // Output definition

    assign SCHED_DATA_OUT = data_out_main;
    assign SCHED_EMPTY    = empty_main;
    assign SCHED_FULL     = full_main;



endmodule
