`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Author : Tony Ho
//
//
// Create Date: 07/10/2023 11:39:49 AM
// Design Name:
// Module Name: fsic_coreclk_phase_cnt
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


module fsic_coreclk_phase_cnt#(
		parameter pCLK_RATIO =4
	) (
		input 	axis_rst_n,
		input 	ioclk,
		input 	coreclk,
		output 	[$clog2(pCLK_RATIO)-1:0] phase_cnt_out
	);

    reg [pCLK_RATIO-1:0] clk_seq;
    reg [$clog2(pCLK_RATIO)-1:0] phase_cnt;
    assign phase_cnt_out = phase_cnt;

	reg core_clk_toggle;
    always @(posedge coreclk or negedge axis_rst_n) begin
        if ( !axis_rst_n ) begin
            core_clk_toggle <= 0;
        end
        else begin
            core_clk_toggle <= ~core_clk_toggle;
        end
    end

    always @(posedge ioclk or negedge axis_rst_n) begin
        if ( !axis_rst_n ) begin
            clk_seq <= 0;
        end
        else begin
            clk_seq[pCLK_RATIO-1:1] <=  clk_seq[pCLK_RATIO-2:0];
            clk_seq[0] <=  core_clk_toggle;
        end
    end


    always @(posedge ioclk or negedge axis_rst_n) begin
        if ( !axis_rst_n) begin
            phase_cnt <= 0;
        end
        else begin
            if ( (clk_seq == 4'h8) || (clk_seq == 4'h7) )
                phase_cnt <= 0;
            else
                phase_cnt <= phase_cnt + 1;
        end
    end

endmodule
