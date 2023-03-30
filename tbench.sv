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
// "tbench.sv" - Testbench file
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

`define CLK_HALF_PERIOD             2
`define SCK_HALF_PERIOD            25

`define N 256 
`define M 8

`define PROGRAM_ALL_SYNAPSES      1
`define VERIFY_ALL_SYNAPSES       1
`define PROGRAM_NEURON_MEMORY     1
`define VERIFY_NEURON_MEMORY      1
`define DO_FULL_CHECK             1
`define     DO_OPEN_LOOP          1
`define     DO_CLOSED_LOOP        1
 
`define SPI_OPEN_LOOP          1'b1
`define SPI_AER_SRC_CTRL_nNEUR 1'b0
`define SPI_MAX_NEUR         8'd200



module tbench (
);

    logic            CLK;
    logic            RST;
    
    logic            SPI_config_rdy;
    logic            SPI_param_checked;
    logic            SNN_initialized_rdy;
    
    logic            SCK, MOSI, MISO;
    logic [  `M+1:0] AERIN_ADDR;
    logic [  `M-1:0] AEROUT_ADDR;
    logic            AERIN_REQ, AERIN_ACK, AEROUT_REQ, AEROUT_ACK;
    wire             SCHED_FULL;
    
    logic [    31:0] synapse_pattern , syn_data;
    logic [    31:0] neuron_pattern  , neur_data;
    logic [    31:0] shift_amt;
    logic [    15:0] addr_temp;
    
    logic [    19:0] spi_read_data;

    logic        [ 6:0] param_leak_str;
    logic signed [11:0] param_thr;
    logic signed [11:0] mem_init;
    
    
    integer target_neurons[15:0];
    integer input_neurons[15:0];
    
    logic [7:0] aer_neur_spk;

    logic signed [11:0] vcore[255:0];
    integer time_window_check;
    logic auto_ack_verbose;

    integer i,j,k,n;
    integer phase;
            

    /***************************
      INIT 
	***************************/ 
    
    initial begin
        SCK         =  1'b0;
        MOSI        =  1'b0;
        AERIN_ADDR  = 10'b0;
        AERIN_REQ   =  1'b0;
        AEROUT_ACK  =  1'b0;
        
        SPI_config_rdy = 1'b0;
        SPI_param_checked = 1'b0;
        SNN_initialized_rdy = 1'b0;
        auto_ack_verbose = 1'b0;
    end
    

  	/***************************
      CLK
	***************************/ 
	
	initial begin
		CLK = 1'b1; 
		forever begin
			wait_ns(`CLK_HALF_PERIOD);
            CLK = ~CLK; 
	    end
	end 
	
    
    /***************************
      RST
	***************************/
	
	initial begin 
        wait_ns(0.1);
        RST = 1'b0;
        wait_ns(100);
        RST = 1'b1;
        wait_ns(100);
        RST = 1'b0;
        wait_ns(100);
        SPI_config_rdy = 1'b1;
        while (~SPI_param_checked) wait_ns(1);
		wait_ns(100);
        RST = 1'b1;
        wait_ns(100);
        RST = 1'b0;
        wait_ns(100);
        SNN_initialized_rdy = 1'b1;
	end

    
    /***************************
      STIMULI GENERATION
	***************************/

	initial begin 
        while (~SPI_config_rdy) wait_ns(1);
        
        /*****************************************************************************************************************************************************************************************************************
                                                                              PROGRAMMING THE CONTROL REGISTERS AND NEURON PARAMETERS THROUGH 19-bit SPI
        *****************************************************************************************************************************************************************************************************************/

        spi_send (.addr({1'b0,1'b0,2'b00,16'd0 }), .data(20'b1                       ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_GATE_ACTIVITY 
        spi_send (.addr({1'b0,1'b0,2'b00,16'd1 }), .data(`SPI_OPEN_LOOP              ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_OPEN_LOOP
        spi_send (.addr({1'b0,1'b0,2'b00,16'd2 }), .data(`SPI_AER_SRC_CTRL_nNEUR     ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_AER_SRC_CTRL_nNEUR
        spi_send (.addr({1'b0,1'b0,2'b00,16'd3 }), .data(`SPI_MAX_NEUR               ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_MAX_NEUR

        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                    VERIFY THE NEURON PARAMETERS
        *****************************************************************************************************************************************************************************************************************/        

        $display("----- Starting verification of programmed SNN parameters");

        assert(snn_0.spi_slave_0.SPI_GATE_ACTIVITY          ==  1'b1                       ) else $fatal(0, "SPI_GATE_ACTIVITY parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_OPEN_LOOP              == `SPI_OPEN_LOOP              ) else $fatal(0, "SPI_OPEN_LOOP parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_AER_SRC_CTRL_nNEUR     == `SPI_AER_SRC_CTRL_nNEUR     ) else $fatal(0, "SPI_AER_SRC_CTRL_nNEUR parameter not correct.");
        assert(snn_0.spi_slave_0.SPI_MAX_NEUR               == `SPI_MAX_NEUR               ) else $fatal(0, "SPI_MAX_NEUR parameter not correct.");
        
        $display("----- Ending verification of programmed SNN parameters, no error found!");
        
        SPI_param_checked = 1'b1;
        while (~SNN_initialized_rdy) wait_ns(1);
        

        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                    PROGRAM NEURON MEMORY WITH TEST VALUES
        *****************************************************************************************************************************************************************************************************************/

        if (`PROGRAM_NEURON_MEMORY) begin
            $display("----- Starting programmation of neuron memory in the SNN through SPI.");
            neuron_pattern = {2{8'b01010101,8'b10101010}};
            for (i=0; i<`N; i=i+1) begin
                for (j=0; j<4; j=j+1) begin
                    neur_data       = neuron_pattern >> (j<<3);
                    addr_temp[15:8] = j;
                    addr_temp[7:0]  = i;    // Each single neuron
                    spi_send (.addr({1'b0,1'b1,2'b01,addr_temp[15:0]}), .data({4'b0,8'h00,neur_data[7:0]}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
                end
                if(!(i%10))
                    $display("programming neurons... (i=%0d/256)", i);
            end
            $display("----- Ending programmation of neuron memory in the SNN through SPI.");
        end else
            $display("----- Skipping programmation of neuron memory in the SNN through SPI.");
            
        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                        READ BACK AND TEST NEURON MEMORY
        *****************************************************************************************************************************************************************************************************************/
        
        if (`VERIFY_NEURON_MEMORY) begin
            $display("----- Starting verification of neuron memory in the SNN through SPI.");
            for (i=0; i<`N; i=i+1) begin
                for (j=0; j<4; j=j+1) begin
                    neur_data       = neuron_pattern >> (j<<3);
                    addr_temp[15:8] = j;
                    addr_temp[7:0]  = i;    // Each single neuron
                    spi_read (.addr({1'b1,1'b0,2'b01,addr_temp[15:0]}), .data(spi_read_data), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); 
                    assert(spi_read_data == {12'b0,neur_data[7:0]}) else $fatal(0, "Byte %d of neuron %d not written/read correctly.", j, i);
                end
                if(!(i%10))
                    $display("verifying neurons... (i=%0d/256)", i);
            end
            $display("----- Ending verification of neuron memory in the SNN through SPI, no error found!");
        end else
            $display("----- Skipping verification of neuron memory in the SNN through SPI.");
        
        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                    PROGRAM SYNAPSE MEMORY WITH TEST VALUES
        *****************************************************************************************************************************************************************************************************************/
        
        if (`PROGRAM_ALL_SYNAPSES) begin
            synapse_pattern = {4'd15,4'd7,4'd12,4'd13,4'd10,4'd5,4'd1,4'd2};
            $display("----- Starting programmation of all synapses in the SNN through SPI.");
            for (i=0; i<8192; i=i+1) begin
                for (j=0; j<4; j=j+1) begin
                    syn_data        = synapse_pattern >> (j<<3);
                    addr_temp[15:13] = j;    // Each single byte in a 32-bit word
                    addr_temp[12:0 ] = i;    // Programmed address by address
                    spi_send (.addr({1'b0,1'b1,2'b10,addr_temp[15:0]}), .data({4'b0,8'h00,syn_data[7:0]}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
                end
                if(!(i%500))
                    $display("programming synapses... (i=%0d/8192)", i);
            end
            $display("----- Ending programmation of all synapses in the SNN through SPI.");
        end else
            $display("----- Skipping programmation of all synapses in the SNN through SPI.");
            
        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                        READ BACK AND TEST SYNAPSE MEMORY
        *****************************************************************************************************************************************************************************************************************/
        
        if (`VERIFY_ALL_SYNAPSES) begin
            $display("----- Starting verification of all synapses in the SNN through SPI.");
            for (i=0; i<8192; i=i+1) begin
                for (j=0; j<4; j=j+1) begin
                    syn_data        = synapse_pattern >> (j<<3);
                    addr_temp[15:13] = j;    // Each single byte in a 32-bit word
                    addr_temp[12:0 ] = i;    // Programmed address by address
                    spi_read (.addr({1'b1,1'b0,2'b10,addr_temp[15:0]}), .data(spi_read_data), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); 
                    assert(spi_read_data == {12'b0,syn_data[7:0]}) else $fatal(0, "Byte %d of address %d not written/read correctly.", j, i);
                end
                if(!(i%500))
                    $display("verifying synapses... (i=%0d/8192)", i);
            end
            $display("----- Ending verification of all synapses in the SNN through SPI, no error found!");
        end else
            $display("----- Skipping verification of all synapses in the SNN through SPI.");
 

        /*****************************************************************************************************************************************************************************************************************
                                                                                                     SYSTEM-LEVEL CHECKING
        *****************************************************************************************************************************************************************************************************************/
           
        if (`DO_FULL_CHECK) begin
        
            fork
                auto_ack(.req(AEROUT_REQ), .ack(AEROUT_ACK), .addr(AEROUT_ADDR), .neur(aer_neur_spk), .verbose(auto_ack_verbose));
            join_none
        
            // Initializing all neurons to zero
            $display("----- Disabling neurons 0 to 255.");   
            for (i=0; i<`N; i=i+1) begin
                addr_temp[15:8] = 3;   // Programming only last byte for disabling a neuron
                addr_temp[7:0]  = i;   // Doing so for all neurons
                spi_send (.addr({1'b0,1'b1,2'b01,addr_temp[15:0]}), .data({4'b0,8'h7F,8'h80}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
            end
            $display("----- Programming neurons done...");
        

            for (phase=0; phase<2; phase=phase+1) begin


	            $display("--- Starting phase %d.", phase);

	            //Disable network operation
	            spi_send (.addr({1'b0,1'b0,2'b00,16'd0}), .data(20'd1), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_GATE_ACTIVITY (1)
	            spi_send (.addr({1'b0,1'b0,2'b00,16'd1}), .data(20'd1), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_OPEN_LOOP (1)
        
	            $display("----- Starting programming of neurons 0,1,3,13,27,38,53,62,100,119,140,169,194,248,250,255.");
	            
	            target_neurons = '{255,250,248,194,169,140,119,100,62,53,38,27,13,3,1,0};
	            input_neurons  = '{255,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0};
	            
	            // Programming neurons
	            for (i=0; i<16; i=i+1) begin
	                shift_amt      = 32'b0;
	                
	                case (target_neurons[i]) 
	                    0 : begin
	                        param_leak_str  = (!phase) ?           7'd0     :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd1);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    1 : begin
	                        param_leak_str  = (!phase) ?           7'd1     :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd3);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    3 : begin
	                        param_leak_str  = (!phase) ?           7'd10    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd10);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    13 : begin
	                        param_leak_str  = (!phase) ?           7'd30    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd100);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    27 : begin
	                        param_leak_str  = (!phase) ?           7'd40    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd200);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    38 : begin
	                        param_leak_str  = (!phase) ?           7'd50    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd300);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    53 : begin
	                        param_leak_str  = (!phase) ?           7'd60    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd400);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    62 : begin
	                        param_leak_str  = (!phase) ?           7'd70    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd500);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    100 : begin
	                        param_leak_str  = (!phase) ?           7'd80    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd600);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    119 : begin
	                        param_leak_str  = (!phase) ?           7'd90    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd700);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    140 : begin
	                        param_leak_str  = (!phase) ?           7'd100   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd800);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    169 : begin
	                        param_leak_str  = (!phase) ?           7'd110   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd900);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    194 : begin
	                        param_leak_str  = (!phase) ?           7'd127   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd2022);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    248 : begin
	                        param_leak_str  = (!phase) ?           7'd120   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd1000);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    250 : begin
	                        param_leak_str  = (!phase) ?           7'd130   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd1500);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    255 : begin
	                        param_leak_str  = (!phase) ?           7'd140  :            7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd2000);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    default : $fatal("Error in neuron configuration"); 
	                endcase 
	                
	                neuron_pattern = {1'b0, param_leak_str, param_thr, mem_init};
	                                         
	                for (j=0; j<4; j=j+1) begin
	                    neur_data       = neuron_pattern >> shift_amt;
	                    addr_temp[15:8] = j;
	                    addr_temp[7:0]  = target_neurons[i];
	                    spi_send (.addr({1'b0,1'b1,2'b01,addr_temp[15:0]}), .data({4'b0,8'h00,neur_data[7:0]}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));
	                    shift_amt       = shift_amt + 32'd8;
	                end          

			        for (j=0; j<16; j=j+1) begin
			            addr_temp[ 12:5] = input_neurons[j][7:0];
			            addr_temp[  4:0] = target_neurons[i][7:3];
			            addr_temp[14:13] = target_neurons[i][2:1];
			            spi_send (.addr({1'b0,1'b1,2'b10,addr_temp[15:0]}), .data({4'b0,8'h00,{input_neurons[j][3:0],input_neurons[j][3:0]}}), .MISO(MISO), .MOSI(MOSI), .SCK(SCK));    // Synapse value = pre-synaptic neuron index 4 LSBs
			        end

                end


                if (`DO_OPEN_LOOP) begin

    	            //Re-enable network operation (SPI_OPEN_LOOP stays at 1)
    	            spi_send (.addr({1'b0,1'b0,2'b00,16'd0}), .data(20'd0), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_GATE_ACTIVITY (0)
    	            
    	            $display("----- Starting stimulation pattern.");

                    for (n=0; n<256; n++)
                        vcore[n] = $signed(snn_0.neuron_core_0.neurarray_0.SRAM[n][11:0]);

                    if (!phase) begin

                    	for (j=0; j<2050; j=j+1) begin
                    		aer_send (.addr_in({1'b0,1'b1,8'hFF}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ)); //Time reference event (global)
                            wait_ns(2000);

                            for (n=0; n<256; n++)
                                vcore[n] = $signed(snn_0.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                        end

                    	wait_ns(10000);

                        /*
                         * Here, all neurons but number 0 should be at a membrane potential of 0
                         */
                        for (j=0; j<16; j=j+1)
                            assert ($signed(vcore[target_neurons[j]]) == (((target_neurons[j] > 0) && (target_neurons[j] < `SPI_MAX_NEUR)) ? $signed(12'd0) : $signed(12'd2046))) else $fatal(0, "Issue in open-loop experiments: membrane potential of neuron %d not correct after leakage",target_neurons[j]);


                    end else begin

                    	for (j=0; j<16; j=j+1)
    	                	for (k=0; k<10; k=k+1) begin
    	                		aer_send (.addr_in({1'b0,1'b0,input_neurons[j][7:0]}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ)); //Neuron events
                                wait_ns(2000);
                    
                                for (n=0; n<256; n++)
                                    vcore[n] = $signed(snn_0.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                            end

                    	wait_ns(10000);

                		/*
                		 * Here, neurons that did not fire (all except 0,1,3,13,27) should be at mem pot -80
                		 */
                        for (j=0; j<16; j=j+1)
                            if ((target_neurons[j] > 27) && (target_neurons[j] < `SPI_MAX_NEUR))
                                assert ($signed(vcore[target_neurons[j]]) == $signed(-12'd80)) else $fatal(0, "Issue in open-loop experiments: membrane potential of neuron %d not correct after stimulation",target_neurons[j]);


                        for (j=0; j<100; j=j+1) begin
                            aer_send (.addr_in({1'b0,1'b1,8'hFF}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ)); //Time reference event (global)
                            wait_ns(2000);

                            for (n=0; n<256; n++)
                                vcore[n] = $signed(snn_0.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                        end

                        wait_ns(10000);

                        /*
                         * Here, all mem pots should be back to 0
                         */
                        for (j=0; j<16; j=j+1)
                            assert ($signed(vcore[target_neurons[j]]) == $signed(12'd0)) else $fatal(0, "Issue in open-loop experiments: membrane potential of neuron %d not correct after leakage",target_neurons[j]);

                        fork
                            // Thread 1
                        	for (k=0; k<300; k=k+1) begin
                        		aer_send (.addr_in({1'b0,1'b0,input_neurons[7][7:0]}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ)); //Neuron events
                                wait_ns(2000);

                                for (n=0; n<256; n++)
                                    vcore[n] = $signed(snn_0.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                            end

                            //Thread 2
                             /*
                             * Here, neuron 194 (with the highest membrane potential among enabled neurons) should fire. Neuron 248, 250 or 255 should be disabled.
                             */
                            while (aer_neur_spk != 8'd194) begin
                                assert ((aer_neur_spk != 8'd248) && (aer_neur_spk != 8'd250) && (aer_neur_spk != 8'd255)) else $fatal(0, "Issue in open-loop experiments: neurons 248, 250 or 255 should be disabled.");
                                wait_ns(1);
                            end
                        join

                    	wait_ns(100000);

                    end   

                end 


                if (`DO_CLOSED_LOOP) begin

                    //Re-enable network operation
                    spi_send (.addr({1'b0,1'b0,2'b00,16'd0}), .data(20'd0), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_GATE_ACTIVITY (0)
                    spi_send (.addr({1'b0,1'b0,2'b00,16'd1}), .data(20'b0), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //SPI_OPEN_LOOP (0)
                    
                    $display("----- Starting stimulation pattern.");
                    

                    if (phase) begin

                        //Start monitoring output spikes in the console
                        auto_ack_verbose = 1'b1;

                        aer_send (.addr_in({1'b1,1'b0,{4'h5,4'd3}}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ)); //Virtual value-5 event to neuron 3
                        aer_send (.addr_in({1'b1,1'b0,{4'h5,4'd3}}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ)); //Virtual value-5 event to neuron 3
                        /*
                         * Here, the correct output firing sequence is 3,0,1,0.
                         */
                        while (!AEROUT_REQ) wait_ns(1);
                        assert (AEROUT_ADDR == 8'd3) else $fatal(0, "Issue in closed-loop experiments: first spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        while ( AEROUT_REQ) wait_ns(1);
                        while (!AEROUT_REQ) wait_ns(1);
                        assert (AEROUT_ADDR == 8'd0) else $fatal(0, "Issue in closed-loop experiments: second spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        while ( AEROUT_REQ) wait_ns(1);
                        while (!AEROUT_REQ) wait_ns(1);
                        assert (AEROUT_ADDR == 8'd1) else $fatal(0, "Issue in closed-loop experiments: third spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        while ( AEROUT_REQ) wait_ns(1);
                        while (!AEROUT_REQ) wait_ns(1);
                        assert (AEROUT_ADDR == 8'd0) else $fatal(0, "Issue in closed-loop experiments: fourth spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        while ( AEROUT_REQ) wait_ns(1);
                        time_window_check = 0;
                        while (time_window_check < 10000) begin
                            assert (!AEROUT_REQ) else $fatal(0, "There should not be more than 4 output spikes in the closed-loop experiments, received %d", AEROUT_ADDR);
                            wait_ns(1);
                            time_window_check += 1;
                        end
                    end

                end

            end

            $display("----- No error found -- All tests passed! :-)"); 

        end else
            $display("----- Skipping scheduler checking."); 
 
 

 
        wait_ns(500);
        $finish;
        
    end
    
    
    /***************************
      SNN INSTANTIATION
	***************************/
    
    tinyODIN snn_0 (
        // Global input     -------------------------------
        .CLK(CLK),
        .RST(RST),
        
        // SPI slave        -------------------------------
        .SCK(SCK),
        .MOSI(MOSI),
        .MISO(MISO),
        
        // Input 10-bit AER -------------------------------
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK),

        // Output 8-bit AER -------------------------------
        .AEROUT_ADDR(AEROUT_ADDR),
        .AEROUT_REQ(AEROUT_REQ),
        .AEROUT_ACK(AEROUT_ACK),

        // Debug ------------------------------------------
        .SCHED_FULL(SCHED_FULL)

    );   


    
    /***********************************************************************
						    TASK IMPLEMENTATIONS
    ************************************************************************/ 

    /***************************
	 SIMPLE TIME-HANDLING TASKS
	***************************/
	
	// These routines are based on a correct definition of the simulation timescale.
	task wait_ns;
        input   tics_ns;
        integer tics_ns;
        #tics_ns;
    endtask

    
    /***************************
	 AER send event
	***************************/
    
    task automatic aer_send (
        input  logic [`M+1:0] addr_in,
        ref    logic [`M+1:0] addr_out,
        ref    logic          ack,
        ref    logic          req
    );
        while (ack) wait_ns(1);
        addr_out = addr_in;
        wait_ns(5);
        req = 1'b1;
        while (!ack) wait_ns(1);
        wait_ns(5);
        req = 1'b0;
	endtask
    
    
    /***************************
	 AER automatic acknowledge
	***************************/

    task automatic auto_ack (
        ref    logic       req,
        ref    logic       ack,
        ref    logic [7:0] addr,
        ref    logic [7:0] neur,
        ref    logic       verbose
    );
    
        forever begin
            while (~req) wait_ns(1);
            wait_ns(100);
            neur = addr;
            if (verbose)
                $display("----- NEURON OUTPUT SPIKE (FROM AER): Event from neuron %d", neur);
            ack = 1'b1;
            while (req) wait_ns(1);
            wait_ns(100);
            ack = 1'b0;
        end

	endtask

    
    /***************************
	 SPI send data
	***************************/

    task automatic spi_send (
        input  logic [19:0] addr,
        input  logic [19:0] data,
        input  logic        MISO, // not used
        ref    logic        MOSI,
        ref    logic        SCK
    );
        integer i;
        
        for (i=0; i<20; i=i+1) begin
            MOSI = addr[19-i];
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
        for (i=0; i<20; i=i+1) begin
            MOSI = data[19-i];
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
	endtask

    
    /***************************
	 SPI read data
	***************************/

    task automatic spi_read (
        input  logic [19:0] addr,
        output logic [19:0] data,
        ref    logic        MISO,
        ref    logic        MOSI,
        ref    logic        SCK
    );
        integer i;
        
        for (i=0; i<20; i=i+1) begin
            MOSI = addr[19-i];
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
        for (i=0; i<20; i=i+1) begin
            wait_ns(`SCK_HALF_PERIOD);
            data = {data[18:0],MISO};
            SCK  = 1'b1;
            wait_ns(`SCK_HALF_PERIOD);
            SCK  = 1'b0;
        end
	endtask

    
endmodule 
