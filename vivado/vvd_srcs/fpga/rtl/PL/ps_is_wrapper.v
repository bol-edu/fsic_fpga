`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/18/2023 03:11:33 PM
// Design Name: 
// Module Name: ps_is_wrapper
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


module ps_is_wrapper(
    input ps_is_tclk,
    input [11:0] ps_is_txd,
    input ps_ioclk,
    output ps_is_rclk,
    output [11:0] ps_is_rxd,
    output [37:0] caravel_mprj_in,
    input [37:0] caravel_mprj_out
    );
    
    assign caravel_mprj_in = {3'b0, ps_ioclk, 13'b0, ps_is_tclk, ps_is_txd, 8'b0};
    assign ps_is_rclk = caravel_mprj_out[33];
    assign ps_is_rxd = caravel_mprj_out[32:21];
    
endmodule
