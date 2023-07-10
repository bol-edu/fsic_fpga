`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Author : Tony Ho
//
// Create Date: 06/23/2023 09:18:34 AM
// Design Name:
// Module Name: fsic_clock
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
//20230710
// 1. using counter to avoid hold time issue when using 2 x clk->q delay from the clk.

`define USE_BLOCK_ASSIGNMENT 1




module fsic_clock_div (
    in, out, resetb
);
    input in;			// input clock
    input resetb;		// asynchronous reset (sense negative)
    output out;			// divided output clock

	assign out = cnt[1];
	reg [1:0] cnt;

`ifdef 	USE_BLOCK_ASSIGNMENT

//for use block assigmnet to avoid race condition in simulation

	always @(posedge in or negedge resetb) begin
		if ( !resetb ) cnt = 0;
		else  begin
			cnt = cnt + 1;
		end
	end

`else      //USE_BLOCK_ASSIGNMENT

//for use non-block assigmnet

	always @(posedge in or negedge resetb) begin
		if ( !resetb ) cnt <= 0;
		else  begin
			cnt <= cnt + 1;
		end
	end

`endif 	    //USE_BLOCK_ASSIGNMENT

endmodule

