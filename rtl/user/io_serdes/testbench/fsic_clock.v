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


`define USE_BLOCK_ASSIGNMENT 1




module fsic_clock_div (
    in, out, resetb
);
    input in;			// input clock
    input resetb;		// asynchronous reset (sense negative)
    output out;			// divided output clock

	reg clk_div4;
	assign out = clk_div4;
	reg clk_div2;

`ifdef 	USE_BLOCK_ASSIGNMENT

//for use block assigmnet to avoid race condition in simulation
 
	always @(posedge in or negedge resetb)
		if ( !resetb ) clk_div2 = 0;
		else clk_div2 = ~clk_div2;
	
	always @(posedge clk_div2 or negedge resetb)
		if ( !resetb ) clk_div4 = 0;
		else clk_div4 = ~clk_div4;
		
`else      //USE_BLOCK_ASSIGNMENT

//for use non-block assigmnet 
	always @(posedge in or negedge resetb)
		if ( !resetb ) clk_div2 <= 0;
		else clk_div2 <= ~clk_div2;
	
	always @(posedge clk_div2 or negedge resetb)
		if ( !resetb ) clk_div4 <= 0;
		else clk_div4 <= ~clk_div4;

`endif 	    //USE_BLOCK_ASSIGNMENT	
			
endmodule 

