`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Author : Tony Ho
//
// Create Date: 06/18/2023 10:44:18 PM
// Design Name:
// Module Name: IO_SERDES
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


module IO_SERDES #(
		parameter pADDR_WIDTH   = 12,
        parameter pDATA_WIDTH   = 32,
		parameter pRxFIFO_DEPTH = 5,
		parameter pCLK_RATIO =4
    ) (


		input 	ioclk,

		input 	axi_reset_n,
		input 	axi_clk,
		
		input 	axis_rst_n,
		input 	axis_clk,

		//write addr channel
		input 	axi_awvalid,
		input 	[pADDR_WIDTH-1:0] axi_awaddr,
		output	axi_awready,
		
		//write data channel
		input 	axi_wvalid,
		input 	[pDATA_WIDTH-1:0] axi_wdata,
		input 	[3:0] axi_wstrb,
		output	axi_wready,
		
		//read addr channel
		input 	axi_arvalid,
		input 	[pADDR_WIDTH-1:0] axi_araddr,
		output 	axi_arready,
		
		//read data channel
		output 	axi_rvalid,
		output 	[pDATA_WIDTH-1:0] axi_rdata,
		input 	axi_rready,
		
		input 	cc_ls_enable,		//axi_lite enable
		
		

        //TX path
		input 	[pDATA_WIDTH-1:0] as_is_tdata,
		input 	[3:0] as_is_tstrb,
		input 	[3:0] as_is_tkeep,
		input 	as_is_tlast,
		input 	[1:0] as_is_tid,
		input 	as_is_tvalid,
		input 	[1:0] as_is_tuser,
		input 	as_is_tready,		//when local side axis switch Rxfifo size <= threshold then as_is_tready=0, this flow control mechanism is for notify remote side do not provide data with is_as_tvalid=1

		output wire          serial_tclk,
		output wire  [11: 0] serial_txd,

        //Rx path
		input  wire          serial_rclk,
		input  wire  [11: 0] serial_rxd,
		
		output 	[pDATA_WIDTH-1:0] is_as_tdata,
		output 	[3:0] is_as_tstrb,
		output 	[3:0] is_as_tkeep,
		output 	is_as_tlast,
		output 	[1:0] is_as_tid,
		output 	is_as_tvalid,
		output 	[1:0] is_as_tuser,
		output 	is_as_tready		//when remote side axis switch Rxfifo size <= threshold then is_as_tready=0, this flow control mechanism is for notify local side do not provide data with as_is_tvalid=1

    );

	assign coreclk = axis_clk;
	assign serial_tclk = txclk;
	assign rxclk = serial_rclk;
	
	wire Serial_Data_Out_tlast_tvalid_tready;
	wire Serial_Data_Out_tid_tuser;
	wire Serial_Data_Out_tkeep;
	wire Serial_Data_Out_tstrb;
	wire [7:0] Serial_Data_Out_tdata;

	assign 	serial_txd[11:0] = {Serial_Data_Out_tlast_tvalid_tready, Serial_Data_Out_tid_tuser, Serial_Data_Out_tkeep, Serial_Data_Out_tstrb, Serial_Data_Out_tdata[7:0]};
	
	wire Serial_Data_In_tlast_tvalid_tready;
	wire Serial_Data_In_tid_tuser;
	wire Serial_Data_In_tkeep;
	wire Serial_Data_In_tstrb;
	wire [7:0] Serial_Data_In_tdata;
	
	assign {Serial_Data_In_tlast_tvalid_tready, Serial_Data_In_tid_tuser, Serial_Data_In_tkeep, Serial_Data_In_tstrb, Serial_Data_In_tdata[7:0] } = serial_rxd[11:0];


	//register offset 0
	reg rxen_ctl;	//bit 0	
	reg txen_ctl;	//bit 1
	
	//write addr channel
	assign 	axi_awvalid_in	= axi_awvalid && cc_ls_enable;
	wire axi_awready_out;
	assign axi_awready = axi_awready_out;
	
	//write data channel
	assign 	axi_wvalid_in	= axi_wvalid && cc_ls_enable;
	wire axi_wready_out;
	assign axi_wready = axi_wready_out;
	
	// if both axi_awvalid_in=1 and axi_wvalid_in=1 then output axi_awready_out = 1 and axi_wready_out = 1
	assign axi_awready_out = (axi_awvalid_in && axi_wvalid_in) ? 1 : 0;		
	assign axi_wready_out = (axi_awvalid_in && axi_wvalid_in) ? 1 : 0;		

	
    always @(posedge axi_clk or negedge axi_reset_n)  begin
        if ( !axi_reset_n ) begin
            rxen_ctl <= 0;
            txen_ctl <= 0;
        end
        else begin
			if ( axi_awvalid_in && axi_wvalid_in ) begin		//when axi_awvalid_in=1 and axi_wvalid_in=1 means axi_awready_out=1 and axi_wready_out=1
				if (axi_awaddr == 12'h000 && (axi_wstrb[0] == 1) ) begin //offset 0
					rxen_ctl <= axi_wdata[0];
					txen_ctl <= axi_wdata[1];					
				end
				else begin
					rxen_ctl <= rxen_ctl;
					txen_ctl <= txen_ctl;
				end
			end
        end
    end		
	
	
	// io serdes only support 2 register bits in offset 0. config control read other address offset is reserved.
	// io serdes always output axi_arready = 1 and don't care the axi_arvalid & axi_araddr
	assign axi_arready = 1;
	// io serdes always output axi_rvalid = 1 and axi_rdata =  { 30'b0, txen_ctl, rxen_ctl }
	assign axi_rvalid = 1;
	assign axi_rdata =  { 30'b0, txen_ctl, rxen_ctl };
	

	
    assign txen_out = txen;

    wire [$clog2(pCLK_RATIO)-1:0] phase_cnt;

    fsic_coreclk_phase_cnt  #(
		.pCLK_RATIO(pCLK_RATIO)
    )
    fsic_coreclk_phase_cnt_0(
    	.axis_rst_n(axis_rst_n),
    	.ioclk(ioclk),
    	.coreclk(coreclk),
    	.phase_cnt_out(phase_cnt)
    );


// For Tx Path

	reg	txen;


    always @(negedge ioclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n ) begin
            txen <= 0;
        end
        else begin
			if ( (txen_ctl || rx_received_data) && phase_cnt == 3   )	// set txen=1 when timeout or rx_received_data==1
																			// if rx_received_data==1 before timeout, it means remote side txen is ealry then local side. 
																			// then we should set local site txen=1 to allow local site provide ready signal to remote side in tx path.
																			// It is to avoid local site rx fifo full in axis switch.
				txen <= 1;
			else
				txen <= txen;
        end
    end

	reg [$clog2(pCLK_RATIO)-1:0] tx_shift_phase_cnt;


    always @(posedge ioclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n ) begin
            tx_shift_phase_cnt <= 3;
        end
        else begin
			if (txen)
				tx_shift_phase_cnt <= tx_shift_phase_cnt + 1;
			else
				tx_shift_phase_cnt <= tx_shift_phase_cnt;
        end
    end

    reg [pDATA_WIDTH-1:0] as_is_tdata_buf;
    reg [3:0] as_is_tstrb_buf;
    reg [3:0] as_is_tkeep_buf;
    reg [3:0] as_is_tid_tuser_buf;
    reg [3:0] as_is_tlast_tvalid_tready_buf;

    always @(posedge coreclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n || ~txen) begin
            as_is_tdata_buf <= 0;
			as_is_tstrb_buf <= 0;
			as_is_tkeep_buf <= 0;
			as_is_tid_tuser_buf <= 0;
			as_is_tlast_tvalid_tready_buf <= 0;
        end
        else begin
			if (is_as_tready && as_is_tvalid) begin			//data transfer from Axis siwtch to io serdes when is_as_tready=1 and as_is_tvalid=1
				as_is_tdata_buf <= as_is_tdata;
				as_is_tstrb_buf <= as_is_tstrb;
				as_is_tkeep_buf <= as_is_tkeep;
				as_is_tid_tuser_buf[3:2] <= as_is_tid;
				as_is_tid_tuser_buf[1:0] <= as_is_tuser;
				as_is_tlast_tvalid_tready_buf[2] <= as_is_tlast;
				as_is_tlast_tvalid_tready_buf[1] <= as_is_tvalid;
				as_is_tlast_tvalid_tready_buf[0] <= as_is_tready;
			end
			else begin
`ifndef DEBUG_is_as_tready			
				as_is_tdata_buf <= as_is_tdata;
				as_is_tstrb_buf <= as_is_tstrb;
				as_is_tkeep_buf <= as_is_tkeep;
				as_is_tid_tuser_buf[3:2] <= as_is_tid;
				as_is_tid_tuser_buf[1:0] <= as_is_tuser;
				as_is_tlast_tvalid_tready_buf[2] <= as_is_tlast;
				as_is_tlast_tvalid_tready_buf[1] <= 0;			// set as_is_tvalid =0 to remote side
				as_is_tlast_tvalid_tready_buf[0] <= as_is_tready;
`else// DEBUG_is_as_tready				
				as_is_tdata_buf <= 0;
				as_is_tstrb_buf <= as_is_tstrb;
				as_is_tkeep_buf <= as_is_tkeep;
				as_is_tid_tuser_buf[3:2] <= as_is_tid;
				as_is_tid_tuser_buf[1:0] <= as_is_tuser;
				as_is_tlast_tvalid_tready_buf[2] <= as_is_tlast;
				as_is_tlast_tvalid_tready_buf[1] <= 0;			// set as_is_tvalid =0 to remote side
				as_is_tlast_tvalid_tready_buf[0] <= as_is_tready;
`endif// DEBUG_is_as_tready				
			end
        end
    end

	assign txclk = ioclk&txen;		//use negedge to avoid glitch in txclk.


`ifdef DEBUG_TDATA
	genvar j;
	generate 
		for (j=0; i<8; j=j+1 ) begin
			assign Serial_Data_Out_tdata[i] = as_is_tdata_buf[j*4+tx_shift_phase_cnt] & txen ;
		end
	endgenerate
`else	//DEBUG_TDATA
    wire [3:0] as_is_tdata_0;
    wire [3:0] as_is_tdata_1;
    wire [3:0] as_is_tdata_2;
    wire [3:0] as_is_tdata_3;
    wire [3:0] as_is_tdata_4;
    wire [3:0] as_is_tdata_5;
    wire [3:0] as_is_tdata_6;
    wire [3:0] as_is_tdata_7;

    assign as_is_tdata_0 = as_is_tdata_buf[3:0];
    assign as_is_tdata_1 = as_is_tdata_buf[7:4];
    assign as_is_tdata_2 = as_is_tdata_buf[11:8];
    assign as_is_tdata_3 = as_is_tdata_buf[15:12];
    assign as_is_tdata_4 = as_is_tdata_buf[19:16];
    assign as_is_tdata_5 = as_is_tdata_buf[23:20];
    assign as_is_tdata_6 = as_is_tdata_buf[27:24];
    assign as_is_tdata_7 = as_is_tdata_buf[31:28];

	assign Serial_Data_Out_tdata[0] = as_is_tdata_0[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tdata[1] = as_is_tdata_1[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tdata[2] = as_is_tdata_2[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tdata[3] = as_is_tdata_3[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tdata[4] = as_is_tdata_4[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tdata[5] = as_is_tdata_5[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tdata[6] = as_is_tdata_6[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tdata[7] = as_is_tdata_7[tx_shift_phase_cnt] & txen ;
`endif	//DEBUG_TDATA


	assign Serial_Data_Out_tstrb = as_is_tstrb_buf[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tkeep = as_is_tkeep_buf[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tid_tuser = as_is_tid_tuser_buf[tx_shift_phase_cnt] & txen ;
	assign Serial_Data_Out_tlast_tvalid_tready = as_is_tlast_tvalid_tready_buf[tx_shift_phase_cnt] & txen ;



// For Rx Path


	reg	rxen;

    always @(negedge ioclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n ) begin
            rxen <= 0;
        end
        else begin
			if (rxen_ctl)
				rxen <= 1;
			else
				rxen <= rxen;
        end
    end


	genvar i;
	generate 
		for (i=0; i<8; i=i+1 ) begin
		
			fsic_io_serdes_rx  #(
				.pRxFIFO_DEPTH(pRxFIFO_DEPTH),
				.pCLK_RATIO(pCLK_RATIO)
			)
			fsic_io_serdes_rx_tdata(
				.axis_rst_n(axis_rst_n),
				.rxclk(rxclk),
				.rxen(rxen),
				.ioclk(ioclk),
				.coreclk(coreclk),
				.Serial_Data_in(Serial_Data_In_tdata[i]),
				.rxdata_out(is_as_tdata[i*4+3:i*4])
//				.rxdata_out_valid(rxdata_out_valid)
			);
		
		end
	endgenerate


	fsic_io_serdes_rx  #(
		.pRxFIFO_DEPTH(pRxFIFO_DEPTH),
		.pCLK_RATIO(pCLK_RATIO)
	)
	fsic_io_serdes_rx_tstrb(
		.axis_rst_n(axis_rst_n),
		.rxclk(rxclk),
		.rxen(rxen),
		.ioclk(ioclk),
		.coreclk(coreclk),
		.Serial_Data_in(Serial_Data_In_tstrb),
		.rxdata_out(is_as_tstrb[3:0])
//		.rxdata_out_valid(rxdata_out_valid)
	);


	fsic_io_serdes_rx  #(
		.pRxFIFO_DEPTH(pRxFIFO_DEPTH),
		.pCLK_RATIO(pCLK_RATIO)
	)
	fsic_io_serdes_rx_tkeep(
		.axis_rst_n(axis_rst_n),
		.rxclk(rxclk),
		.rxen(rxen),
		.ioclk(ioclk),
		.coreclk(coreclk),
		.Serial_Data_in(Serial_Data_In_tkeep),
		.rxdata_out(is_as_tkeep[3:0])
//		.rxdata_out_valid(rxdata_out_valid)
	);

	fsic_io_serdes_rx  #(
		.pRxFIFO_DEPTH(pRxFIFO_DEPTH),
		.pCLK_RATIO(pCLK_RATIO)
	)
	fsic_io_serdes_rx_tid_tuser(
		.axis_rst_n(axis_rst_n),
		.rxclk(rxclk),
		.rxen(rxen),
		.ioclk(ioclk),
		.coreclk(coreclk),
		.Serial_Data_in(Serial_Data_In_tid_tuser),
		.rxdata_out( {is_as_tid[1:0], is_as_tuser[1:0]})
//		.rxdata_out_valid(rxdata_out_valid)
	);

    wire	rx_received_data;		

	fsic_io_serdes_rx  #(
		.pRxFIFO_DEPTH(pRxFIFO_DEPTH),
		.pCLK_RATIO(pCLK_RATIO)
	)
	fsic_io_serdes_rx_fc(
		.axis_rst_n(axis_rst_n),
		.rxclk(rxclk),
		.rxen(rxen),
		.ioclk(ioclk),
		.coreclk(coreclk),
		.Serial_Data_in(Serial_Data_In_tlast_tvalid_tready),
		.rxdata_out( {is_as_tlast, is_as_tvalid, is_as_tready_remote}),      // only connect [2:0]
		.rxdata_out_valid(rx_received_data)
	);

	reg is_as_tready_out;
	assign is_as_tready = is_as_tready_out;
	
    always @(posedge coreclk or negedge axis_rst_n)  begin
        if ( !axis_rst_n || !txen ) begin
            is_as_tready_out <= 0;				//set is_as_tready_out=0 when txen == 0
        end
        else begin
			if (rx_received_data == 0) is_as_tready_out <= 1;		// when txen==1 and still not recevies data from remote side then set is_as_tready_out=1 to avoid dead lock issue.
			else	is_as_tready_out <= is_as_tready_remote;				// when txen == 1 and rx_received_data==1 (received data from remote side) then is_as_tready_out come from is_as_tready_remote (remote side)
        end
    end


endmodule


