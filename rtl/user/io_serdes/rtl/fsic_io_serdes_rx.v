`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Author : Tony Ho
//
//
// Create Date: 07/10/2023 11:45:06 AM
// Design Name:
// Module Name: fsic_io_serdes_rx
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module fsic_io_serdes_rx#(
		parameter pRxFIFO_DEPTH = 5,
		parameter pCLK_RATIO =4
	) (
		input wire 	axis_rst_n,
		input wire 	rxclk,
		input wire   rxen,
		input wire 	ioclk,
		input wire 	coreclk,
		input wire 	Serial_Data_in,
		output 	[pCLK_RATIO-1:0] rxdata_out,
		output 	rxdata_out_valid
	);


	reg [$clog2(pRxFIFO_DEPTH)-1:0] w_ptr;
	reg w_ptr_pre;
	reg w_ptr_sync;

	wire w_ptr_graycode_bit0;

	assign w_ptr_graycode_bit0 = w_ptr[1] ^  w_ptr[0];

	always @(negedge rxclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n || !rxen ) begin
			w_ptr <= 0;
		end
		else begin
			if (w_ptr == 4)
				w_ptr <= 0;
			else
				w_ptr <= w_ptr+1;
		end
	end


	reg [pRxFIFO_DEPTH-1:0] RxFifo;


	always @(negedge rxclk or negedge axis_rst_n) begin
		if ( !axis_rst_n || !rxen ) begin
			RxFifo <= 0;
		end
		else begin
			RxFifo[w_ptr] <= Serial_Data_in;
		end
	end



	always @(posedge ioclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n ) begin
			w_ptr_pre <= 0;
			w_ptr_sync <= 0;
		end
		else begin
			w_ptr_pre <= w_ptr_graycode_bit0;		//use gray code
			w_ptr_sync <= w_ptr_pre;				//avoid metastable issue
		end
	end

	reg rx_start;
	always @(posedge ioclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n ) begin
			rx_start <= 0;
		end
		else begin
			if (w_ptr_sync != 0 )
				rx_start <= 1;
			else
				rx_start <= rx_start;
		end
	end


	reg [$clog2(pRxFIFO_DEPTH)-1:0] r_ptr;

	always @(posedge ioclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n ) begin
			r_ptr <= 0;
		end
		else begin
			if (rx_start) begin
				if ( r_ptr == 4 )
					r_ptr <= 0;
				else
					r_ptr <= r_ptr + 1;
			end
			else
				r_ptr <= r_ptr;
		end
	end

	reg [pCLK_RATIO-1:0] rx_shift_reg;

	always @(posedge ioclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n ) begin
			rx_shift_reg <= 0;
		end
		else begin
			if (rx_start) begin
				rx_shift_reg[3] <= RxFifo[r_ptr];		//r_ptr get from LSB to MSB
				rx_shift_reg[2:0] <= rx_shift_reg[3:1];
			end
		end
	end

	reg [$clog2(pCLK_RATIO)-1:0] rx_shift_phase_cnt;

	always @(posedge ioclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n ) begin
			rx_shift_phase_cnt <= pCLK_RATIO-1;
		end
		else begin
			if (rx_start)
				rx_shift_phase_cnt <= rx_shift_phase_cnt+1;
			else
				rx_shift_phase_cnt <= rx_shift_phase_cnt;
		end
	end

	reg [2:0] rx_start_delay;

	always @(posedge ioclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n ) begin
			rx_start_delay <= 0;
		end
		else begin
			rx_start_delay[0] <= rx_start;
			rx_start_delay[2:1] <= rx_start_delay[1:0];
		end
	end

	assign rx_shift_reg_valid = (rx_shift_phase_cnt == pCLK_RATIO-1) && rx_start_delay[2] ; //rx_shift_reg is ready to move.

	//write by ioclk in negedge and read by coreclk in posedge then simulation result is ok.

	reg [pCLK_RATIO-1:0] rx_sync_fifo;
	reg rx_sync_fifo_valid;

	always @(posedge ioclk or negedge axis_rst_n)  begin		//use posedge, the simulation result is early 1T in rxdata
																// - This issue is fixed by use block assigment in clock divider to avoid race condition in simulation
		if ( !axis_rst_n ) begin
			rx_sync_fifo <= 0;
			rx_sync_fifo_valid <= 0;
		end
		else begin
			if (rx_start && rx_shift_reg_valid)  begin
				rx_sync_fifo <= rx_shift_reg;
				rx_sync_fifo_valid <= 1;
			end
			else begin
				rx_sync_fifo <= rx_sync_fifo;
				rx_sync_fifo_valid <= rx_sync_fifo_valid;
			end
		end
	end

	reg [pCLK_RATIO-1:0] rxdata;
	reg rxdata_valid;

	assign rxdata_out = rxdata;
	assign rxdata_out_valid = rxdata_valid;

	always @(posedge coreclk or negedge axis_rst_n)  begin
		if ( !axis_rst_n ) begin
			rxdata <= 0;
			rxdata_valid <= 0;
		end
		else begin
				rxdata <= rx_sync_fifo;
				rxdata_valid <= rx_sync_fifo_valid;
		end
	end



endmodule

