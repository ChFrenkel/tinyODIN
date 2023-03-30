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
// "spi_slave.v" - 20-bit SPI slave module
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


module spi_slave #(
    parameter N = 256,
    parameter M = 8
)(

    // Global inputs -----------------------------------------
    input  wire                 RST_async,

    // SPI slave interface ------------------------------------
    input  wire                 SCK,
    output wire                 MISO,
    input  wire                 MOSI,

    // Control interface for readback -------------------------
    output reg                  CTRL_READBACK_EVENT,
    output reg                  CTRL_PROG_EVENT,
    output reg  [      2*M-1:0] CTRL_SPI_ADDR,
    output reg  [          1:0] CTRL_OP_CODE,
    output reg  [      2*M-1:0] CTRL_PROG_DATA,
    input  wire [         31:0] SYNARRAY_RDATA,
    input  wire [         31:0] NEUR_STATE,

    // Configuration registers output -------------------------
    output reg                  SPI_GATE_ACTIVITY,
    output reg                  SPI_OPEN_LOOP,
    output reg                  SPI_AER_SRC_CTRL_nNEUR,
    output reg  [        M-1:0] SPI_MAX_NEUR
); 

	//----------------------------------------------------------------------------------
	//	REG & WIRES :
	//----------------------------------------------------------------------------------
    
	reg  [ 5:0]    spi_cnt;
    
    wire [31:0]    readback_weight;
    wire [31:0]    readback_neuron;
	
	reg  [19:0]    spi_shift_reg_out, spi_shift_reg_in;
    reg  [19:0]    spi_data, spi_addr;
    
    genvar i;
    

	//----------------------------------------------------------------------------------
	//	SPI circuitry
	//----------------------------------------------------------------------------------

	// SPI counter
	always @(negedge SCK, posedge RST_async)
		if      (RST_async)        spi_cnt <= 6'd0;
        else if (spi_cnt == 6'd39) spi_cnt <= 6'd0;
		else                       spi_cnt <= spi_cnt + 6'd1;
        
    always @(negedge SCK, posedge RST_async)
		if      (RST_async)        spi_addr <= 20'd0;
		else if (spi_cnt == 6'd19) spi_addr <= spi_shift_reg_in[19:0];
        else                       spi_addr <= spi_addr;
	
    always @(posedge SCK)
        spi_shift_reg_in <= {spi_shift_reg_in[18:0], MOSI};
        
	
	// SPI shift register
	always @(negedge SCK, posedge RST_async)
        if (RST_async) begin
            spi_shift_reg_out   <= 20'b0;
            CTRL_READBACK_EVENT <= 1'b0;
            CTRL_PROG_EVENT     <= 1'b0;
            CTRL_SPI_ADDR       <= {(2*M){1'b0}};
            CTRL_OP_CODE        <= 2'b0;
            CTRL_PROG_DATA      <= {(2*M){1'b0}};
		end else if (spi_shift_reg_in[19] && (spi_cnt == 6'd19)) begin
            spi_shift_reg_out   <= {spi_shift_reg_out[18:0], 1'b0};
            CTRL_READBACK_EVENT <= (spi_shift_reg_in[2*M+1:2*M] != 2'b0);
            CTRL_PROG_EVENT     <= 1'b0;
            CTRL_SPI_ADDR       <= spi_shift_reg_in[2*M-1:  0];
            CTRL_OP_CODE        <= spi_shift_reg_in[2*M+1:2*M];
            CTRL_PROG_DATA      <= {(2*M){1'b0}};
		end else if (spi_shift_reg_in[18] && (spi_cnt == 6'd19)) begin
            spi_shift_reg_out   <= 20'b0;
            CTRL_READBACK_EVENT <= 1'b0;
            CTRL_PROG_EVENT     <= 1'b0;
            CTRL_SPI_ADDR       <= spi_shift_reg_in[2*M-1:  0];
            CTRL_OP_CODE        <= spi_shift_reg_in[2*M+1:2*M];
            CTRL_PROG_DATA      <= {(2*M){1'b0}};
		end else if (spi_addr[19] && (spi_cnt == 6'd31)) begin
            spi_shift_reg_out   <= (CTRL_OP_CODE == 2'b10) ? {readback_weight[7:0],12'b0} : ((CTRL_OP_CODE == 2'b01) ? {readback_neuron[7:0],12'b0} : {spi_shift_reg_out[18:0], 1'b0}); 
            CTRL_READBACK_EVENT <= 1'b0;
            CTRL_PROG_EVENT     <= 1'b0;
            CTRL_SPI_ADDR       <= CTRL_SPI_ADDR;
            CTRL_OP_CODE        <= CTRL_OP_CODE;
            CTRL_PROG_DATA      <= {(2*M){1'b0}};
		end else if (spi_addr[18] && (spi_cnt == 6'd39)) begin
            spi_shift_reg_out   <= {spi_shift_reg_out[18:0], 1'b0};
            CTRL_READBACK_EVENT <= 1'b0;
            CTRL_PROG_EVENT     <= (CTRL_OP_CODE != 2'b0);
            CTRL_SPI_ADDR       <= CTRL_SPI_ADDR;
            CTRL_OP_CODE        <= CTRL_OP_CODE;
            CTRL_PROG_DATA      <= spi_shift_reg_in[2*M-1:0];
		end else begin
            spi_shift_reg_out   <= {spi_shift_reg_out[18:0], 1'b0};
            CTRL_READBACK_EVENT <= CTRL_READBACK_EVENT;
            CTRL_PROG_EVENT     <= 1'b0;
            CTRL_SPI_ADDR       <= CTRL_SPI_ADDR;
            CTRL_OP_CODE        <= CTRL_OP_CODE;
            CTRL_PROG_DATA      <= CTRL_PROG_DATA;
        end
         
    assign readback_weight = SYNARRAY_RDATA >> (({3'b0,CTRL_SPI_ADDR[2*M-2:2*M-3]} << 3));
    assign readback_neuron =     NEUR_STATE >> (({3'b0,CTRL_SPI_ADDR[2*M-1:  M  ]} << 3));
    
	// SPI MISO
	assign MISO = spi_shift_reg_out[19];

    
	//----------------------------------------------------------------------------------
	//	Output config. registers
	//----------------------------------------------------------------------------------
  
    //SPI_GATE_ACTIVITY - 1 bit - address 0
    always @(posedge SCK)
        if      (!spi_addr[17] && !spi_addr[16] && (spi_addr[15:0] == 16'd0 ) && (spi_cnt == 6'd39))  SPI_GATE_ACTIVITY <= MOSI;
        
    //SPI_OPEN_LOOP - 1 bit - address 1
    always @(posedge SCK)
        if      (!spi_addr[17] && !spi_addr[16] && (spi_addr[15:0] == 16'd1 ) && (spi_cnt == 6'd39))  SPI_OPEN_LOOP <= MOSI;

    //SPI_AER_SRC_CTRL_nNEUR - 1 bit - address 2
    always @(posedge SCK)
        if      (!spi_addr[17] && !spi_addr[16] && (spi_addr[15:0] == 16'd2 ) && (spi_cnt == 6'd39))  SPI_AER_SRC_CTRL_nNEUR <= MOSI;

    //SPI_MAX_NEUR - M bits - address 3
    always @(posedge SCK)
        if      (!spi_addr[17] && !spi_addr[16] && (spi_addr[15:0] == 16'd3 ) && (spi_cnt == 6'd39))  SPI_MAX_NEUR <= {spi_shift_reg_in[M-2:0], MOSI};

    /*                                                 *
     * Some address room for other params if necessary *
     *                                                 */

    
endmodule
