`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Author : Tony Ho
//
// 
// Create Date: 07/10/2023 11:43:39 AM
// Design Name: 
// Module Name: fsic_io_serdes_tx
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


module fsic_io_serdes_tx#(
		parameter TxFIFO_DEPTH = 4,
		parameter pCLK_RATIO =4
	) (
		input 	axis_rst_n,
		output 	txclk,
		input 	ioclk,
		input 	coreclk,
		output 	Serial_Data_Out,
		input 	[pCLK_RATIO-1:0] txdata_in
	);

	reg	tx_en;
	reg	[7:0] tx_en_phase_cnt;

    always @(negedge ioclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n ) begin
            tx_en_phase_cnt <= 0;
        end
        else begin
				tx_en_phase_cnt <= tx_en_phase_cnt+1;
        end
    end


    always @(negedge ioclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n ) begin
            tx_en <= 0;
        end
        else begin
			if (tx_en_phase_cnt > 82)	//100T
				tx_en <= 1;
			else
				tx_en <= tx_en;
        end
    end

	reg [$clog2(pCLK_RATIO)-1:0] tx_shift_phase_cnt;


    always @(posedge ioclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n ) begin
            tx_shift_phase_cnt <= 3;
        end
        else begin
			if (tx_en)
				tx_shift_phase_cnt <= tx_shift_phase_cnt + 1;
			else
				tx_shift_phase_cnt <= tx_shift_phase_cnt;
        end
    end

	assign Serial_Data_Out= txdata_in[tx_shift_phase_cnt] & tx_en ;
	assign txclk = ioclk&tx_en;		//use negedge to avoid glitch in txclk.

endmodule




