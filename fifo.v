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
// "fifo.v" - Scheduler FIFO module
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


module fifo #(
	parameter width      = 9,
    parameter depth      = 4,
    parameter depth_addr = 2
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              push_req_n,
    input  wire              pop_req_n,
    input  wire [width-1: 0] data_in,
    output reg               empty,
    output wire              full,
    output wire [width-1: 0] data_out
);
  
    reg [width-1:0] mem [0:depth-1]; 

    reg [depth_addr-1:0] write_ptr;
    reg [depth_addr-1:0] read_ptr;
    reg [depth_addr-1:0] fill_cnt;

    genvar i;



    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            write_ptr <= 2'b0;
        else if (!push_req_n)
            write_ptr <= write_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            write_ptr <= write_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            read_ptr <= 2'b0;
        else if (!pop_req_n)
            read_ptr <= read_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            read_ptr <= read_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            fill_cnt <= 2'b0;
        else if (!push_req_n && pop_req_n && !empty)
            fill_cnt <= fill_cnt + {{(depth_addr-1){1'b0}},1'b1};
        else if (!push_req_n && !pop_req_n)
            fill_cnt <= fill_cnt;
        else if (!pop_req_n && |fill_cnt)
            fill_cnt <= fill_cnt - {{(depth_addr-1){1'b0}},1'b1};
        else
            fill_cnt <= fill_cnt;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            empty <= 1'b1;
        else if (!push_req_n)
            empty <= 1'b0;
        else if (!pop_req_n)
            empty <= ~|fill_cnt; 
    end

    assign full  =  &fill_cnt;


    generate

        for (i=0; i<depth; i=i+1) begin
            
            always @(posedge clk) begin
                if (!push_req_n && (write_ptr == i))
                    mem[i] <= data_in;
                else 
                    mem[i] <= mem[i];
            end
            
        end
        
    endgenerate

    assign data_out = mem[read_ptr];


endmodule 
