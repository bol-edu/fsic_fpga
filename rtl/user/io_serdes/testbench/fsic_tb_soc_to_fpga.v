`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Author : Tony Ho
//
// Create Date: 06/21/2023 02:34:48 PM
// Design Name:
// Module Name: fsic_tb_soc_to_fpga
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

// 20230712
// 1. check cfg read result
// 20230711
// 1. update cfg read/write
// 2. replace #0 to non-block assigment in initial block.
// 20230706
// 1. update test003 : simulation the behavior of fpga axis_switch rx buffer full
// 2. using #0 to replace @negedge assign value in testbench
// 3. use localparam
// 4. use axis_rst_n & axi_reset_n
// 5. update port for serial_*
// 20230705
// 1. update test002 to verify soc provide soc_as_is_tdata, soc_as_is_tstrb, soc_as_is_tkeep, soc_as_is_tlast, soc_as_is_tid, soc_as_is_tuser, soc_as_is_tvalid, soc_as_is_tready to fpga
// 20230703
// 1. update port name
// 2. update testbench for core clock with offset
// 20230630
// 1. add task soc_delay_valid;		//input tdata and valid_delay 
// 2. add register R/W interface
// 3. add soc_cfg_read
// 20230629
// 1. data transfer from Axis siwtch to io serdes when is_as_tready=1 and as_is_tvalid=1
// 2. use posedge to update data in testbench
//	 - get data_send error 
//		  1060=> data_send	 : soc_as_is_tdata=22222222, soc_as_is_tvalid=1, soc_is_as_tready=1
// 3. use delay to workaround get data_send incorrect issue
//	1059=> data_send	 : soc_as_is_tdata=11111111, soc_as_is_tvalid=1, soc_is_as_tready=1
//	1060=>soc_as_is_tdata=22222222, soc_as_is_tvalid=1, soc_is_as_tready=1
// 4. use negedge to update data in testbench, remove item 2 & 3
// 20230628
// 1. update interface to axis switch
// 2. support flow control in as_is_tready and is_as_tready

//test001 : soc side register R/W test
//test002 : soc to fpga TX/RX test with change coreclk phase
module fsic_tb_soc_to_fpga #(
		parameter IOCLK_Period	= 10,
		parameter DLYCLK_Period	= 1,
		parameter SHIFT_DEPTH = 5,
		parameter RxFIFO_DEPTH = 5,
		parameter CLK_RATIO = 4
	)
	(

	);

		localparam TEST002_START	= 1;
		localparam TEST002_CNT	= 4;
		localparam TEST003_START	= TEST002_START + TEST002_CNT;
		localparam TEST003_CNT	= 4;
		localparam TOTAL_TEST_LOOP	= TEST003_START + TEST003_CNT;

	real ioclk_pd = IOCLK_Period;
	real coreclk_pd = IOCLK_Period*4;
	real dlyclk_pd = DLYCLK_Period;

	reg soc_rst;
	reg fpga_rst;
	reg soc_resetb;
	reg fpga_resetb;
	
	reg ioclk;
	reg dlyclk;

	reg [7:0] soc_compare_data;
	
	//write addr channel
	reg soc_axi_awvalid;
	reg [11:0] soc_axi_awaddr;
	wire soc_axi_awready;
	
	//write data channel
	reg 	soc_axi_wvalid;
	reg 	[31:0] soc_axi_wdata;
	reg 	[3:0] soc_axi_wstrb;
	wire	soc_axi_wready;
	
	//read addr channel
	reg 	soc_axi_arvalid;
	reg 	[11:0] soc_axi_araddr;
	wire 	soc_axi_arready;
	
	//read data channel
	wire 	soc_axi_rvalid;
	wire 	[31:0] soc_axi_rdata;
	reg 	soc_axi_rready;
	
	reg 	soc_cc_ls_enable;		//axi_lite enable


	//write addr channel
	reg fpga_axi_awvalid;
	reg [11:0] fpga_axi_awaddr;
	wire fpga_axi_awready;
	
	//write data channel
	reg 	fpga_axi_wvalid;
	reg 	[31:0] fpga_axi_wdata;
	reg 	[3:0] fpga_axi_wstrb;
	wire	fpga_axi_wready;
	
	//read addr channel
	reg 	fpga_axi_arvalid;
	reg 	[11:0] fpga_axi_araddr;
	wire 	fpga_axi_arready;
	
	//read data channel
	wire 	fpga_axi_rvalid;
	wire 	[31:0] fpga_axi_rdata;
	reg 	fpga_axi_rready;
	
	reg 	fpga_cc_ls_enable;		//axi_lite enable


	reg [31:0] soc_as_is_tdata;
	reg [3:0] soc_as_is_tstrb;
	reg [3:0] soc_as_is_tkeep;
	reg soc_as_is_tlast;
	reg [1:0] soc_as_is_tid;
	reg soc_as_is_tvalid;
	reg [1:0] soc_as_is_tuser;
	reg soc_as_is_tready;		//when local side axis switch Rxfifo size <= threshold then as_is_tready=0; this flow control mechanism is for notify remote side do not provide data with is_as_tvalid=1

	wire [11:0] soc_serial_txd;
//	wire [7:0] soc_Serial_Data_Out_tdata;
//	wire soc_Serial_Data_Out_tstrb;
//	wire soc_Serial_Data_Out_tkeep;
//	wire soc_Serial_Data_Out_tid_tuser;	// tid and tuser	
//	wire soc_Serial_Data_Out_tlast_tvalid_tready;		//flowcontrol

	wire [31:0] soc_is_as_tdata;
	wire [3:0] soc_is_as_tstrb;
	wire [3:0] soc_is_as_tkeep;
	wire soc_is_as_tlast;
	wire [1:0] soc_is_as_tid;
	wire soc_is_as_tvalid;
	wire [1:0] soc_is_as_tuser;
	wire soc_is_as_tready;		//when remote side axis switch Rxfifo size <= threshold then is_as_tready=0; this flow control mechanism is for notify local side do not provide data with as_is_tvalid=1

	reg [31:0] fpga_as_is_tdata;
	reg [3:0] fpga_as_is_tstrb;
	reg [3:0] fpga_as_is_tkeep;
	reg fpga_as_is_tlast;
	reg [1:0] fpga_as_is_tid;
	reg fpga_as_is_tvalid;
	reg [1:0] fpga_as_is_tuser;
	reg fpga_as_is_tready;		//when local side axis switch Rxfifo size <= threshold then as_is_tready=0; this flow control mechanism is for notify remote side do not provide data with is_as_tvalid=1

	wire [11:0] fpga_serial_txd;
//	wire [7:0] fpga_Serial_Data_Out_tdata;
//	wire fpga_Serial_Data_Out_tstrb;
//	wire fpga_Serial_Data_Out_tkeep;
//	wire fpga_Serial_Data_Out_tid_tuser;	// tid and tuser	
//	wire fpga_Serial_Data_Out_tlast_tvalid_tready;		//flowcontrol

	wire [31:0] fpga_is_as_tdata;
	wire [3:0] fpga_is_as_tstrb;
	wire [3:0] fpga_is_as_tkeep;
	wire fpga_is_as_tlast;
	wire [1:0] fpga_is_as_tid;
	wire fpga_is_as_tvalid;
	wire [1:0] fpga_is_as_tuser;
	wire fpga_is_as_tready;		//when remote side axis switch Rxfifo size <= threshold then is_as_tready=0, this flow control mechanism is for notify local side do not provide data with as_is_tvalid=1


	//wire [7:0] Serial_Data_Out_ad_delay1;
	//wire txclk_delay1;

	//wire [7:0] Serial_Data_Out_ad_delay;
	//wire txclk_delay;

	//assign #4 Serial_Data_Out_ad_delay1 = Serial_Data_Out_ad;
	//assign #4 txclk_delay1 = txclk;
	//assign #4 Serial_Data_Out_ad_delay = Serial_Data_Out_ad_delay1;
	//assign #4 txclk_delay = txclk_delay1;

	fsic_clock_div soc_clock_div (
	.resetb(soc_resetb),
	.in(ioclk),
	.out(soc_coreclk)
	);

	fsic_clock_div fpga_clock_div (
	.resetb(fpga_resetb),
	.in(ioclk),
	.out(fpga_coreclk)
	);


	IO_SERDES  #(
		.RxFIFO_DEPTH(RxFIFO_DEPTH),
		.CLK_RATIO(CLK_RATIO)
	)
	soc_fsic_io_serdes(
		.axis_rst_n(~soc_rst),
		.axi_reset_n(~soc_rst),
		.serial_tclk(soc_txclk),
		.serial_rclk(fpga_txclk),
		.ioclk(ioclk),
		.axis_clk(soc_coreclk),
		.axi_clk(soc_coreclk),
		
		//write addr channel
		.axi_awvalid(soc_axi_awvalid),
		.axi_awaddr(soc_axi_awaddr),
		.axi_awready(soc_axi_awready),

		//write data channel
		.axi_wvalid(soc_axi_wvalid),
		.axi_wdata(soc_axi_wdata),
		.axi_wstrb(soc_axi_wstrb),
		.axi_wready(soc_axi_wready),

		//read addr channel
		.axi_arvalid(soc_axi_arvalid),
		.axi_araddr(soc_axi_araddr),
		.axi_arready(soc_axi_arready),
		
		//read data channel
		.axi_rvalid(soc_axi_rvalid),
		.axi_rdata(soc_axi_rdata),
		.axi_rready(soc_axi_rready),
		
		.cc_ls_enable(soc_cc_ls_enable),
		
		.as_is_tdata(soc_as_is_tdata),
		.as_is_tstrb(soc_as_is_tstrb),
		.as_is_tkeep(soc_as_is_tkeep),
		.as_is_tlast(soc_as_is_tlast),
		.as_is_tid(soc_as_is_tid),
		.as_is_tvalid(soc_as_is_tvalid),
		.as_is_tuser(soc_as_is_tuser),
		.as_is_tready(soc_as_is_tready),
		.serial_txd(soc_serial_txd),
		.serial_rxd(fpga_serial_txd),
		.is_as_tdata(soc_is_as_tdata),
		.is_as_tstrb(soc_is_as_tstrb),
		.is_as_tkeep(soc_is_as_tkeep),
		.is_as_tlast(soc_is_as_tlast),
		.is_as_tid(soc_is_as_tid),
		.is_as_tvalid(soc_is_as_tvalid),
		.is_as_tuser(soc_is_as_tuser),
		.is_as_tready(soc_is_as_tready)
	);

	IO_SERDES  #(
		.RxFIFO_DEPTH(RxFIFO_DEPTH),
		.CLK_RATIO(CLK_RATIO)
	)
	fpga_fsic_io_serdes(
		.axis_rst_n(~fpga_rst),
		.axi_reset_n(~fpga_rst),
		.serial_tclk(fpga_txclk),
		.serial_rclk(soc_txclk),
		.ioclk(ioclk),
		.axis_clk(fpga_coreclk),
		.axi_clk(fpga_coreclk),
		
		//write addr channel
		.axi_awvalid(fpga_axi_awvalid),
		.axi_awaddr(fpga_axi_awaddr),
		.axi_awready(fpga_axi_awready),

		//write data channel
		.axi_wvalid(fpga_axi_wvalid),
		.axi_wdata(fpga_axi_wdata),
		.axi_wstrb(fpga_axi_wstrb),
		.axi_wready(fpga_axi_wready),

		//read addr channel
		.axi_arvalid(fpga_axi_arvalid),
		.axi_araddr(fpga_axi_araddr),
		.axi_arready(fpga_axi_arready),
		
		//read data channel
		.axi_rvalid(fpga_axi_rvalid),
		.axi_rdata(fpga_axi_rdata),
		.axi_rready(fpga_axi_rready),
		
		.cc_ls_enable(fpga_cc_ls_enable),


		.as_is_tdata(fpga_as_is_tdata),
		.as_is_tstrb(fpga_as_is_tstrb),
		.as_is_tkeep(fpga_as_is_tkeep),
		.as_is_tlast(fpga_as_is_tlast),
		.as_is_tid(fpga_as_is_tid),
		.as_is_tvalid(fpga_as_is_tvalid),
		.as_is_tuser(fpga_as_is_tuser),
		.as_is_tready(fpga_as_is_tready),
		.serial_txd(fpga_serial_txd),
		.serial_rxd(soc_serial_txd),
		.is_as_tdata(fpga_is_as_tdata),
		.is_as_tstrb(fpga_is_as_tstrb),
		.is_as_tkeep(fpga_is_as_tkeep),
		.is_as_tlast(fpga_is_as_tlast),
		.is_as_tid(fpga_is_as_tid),
		.is_as_tvalid(fpga_is_as_tvalid),
		.is_as_tuser(fpga_is_as_tuser),
		.is_as_tready(fpga_is_as_tready)
	);






	// init and reset
	initial begin
		ioclk = 1;
		dlyclk = 1;
		
		//write addr channel
		soc_axi_awvalid=0;
		soc_axi_awaddr=0;
		
		//write data channel
		soc_axi_wvalid=0;
		soc_axi_wdata=0;
		soc_axi_wstrb=0;
		
		//read addr channel
		soc_axi_arvalid=0;
		soc_axi_araddr=0;
		
		//read data channel
		soc_axi_rready=0;
		
		soc_cc_ls_enable=0;


		soc_as_is_tdata=0;
		soc_as_is_tstrb=0;
		soc_as_is_tkeep=0;
		soc_as_is_tlast=0;
		soc_as_is_tid=0;
		soc_as_is_tvalid=0;
		soc_as_is_tuser=0;
		soc_as_is_tready=0;

		//write addr channel
		fpga_axi_awvalid=0;
		fpga_axi_awaddr=0;

		
		//write data channel
		fpga_axi_wvalid=0;
		fpga_axi_wdata=0;
		fpga_axi_wstrb=0;
		
		//read addr channel
		fpga_axi_arvalid=0;
		fpga_axi_araddr=0;
		
		//read data channel
		fpga_axi_rready=0;
		
		fpga_cc_ls_enable=0;

		fpga_as_is_tdata=0;
		fpga_as_is_tstrb=0;
		fpga_as_is_tkeep=0;
		fpga_as_is_tlast=0;
		fpga_as_is_tid=0;
		fpga_as_is_tvalid=0;
		fpga_as_is_tuser=0;
		fpga_as_is_tready=0;


	end

	// test001 : soc side register R/W test
	initial begin
		//$monitor($time, "=>soc_as_is_tdata=%x, soc_as_is_tvalid=%b, soc_as_is_tready=%b, soc_is_as_tready=%b", soc_as_is_tdata, soc_as_is_tvalid, soc_as_is_tready, soc_is_as_tready);
		$display("test001 : soc side register test");
		soc_apply_reset(40,40);

		#20;
		soc_cc_ls_enable=1;

		//burst write test
		soc_cfg_write(0,0,1,0);		//write offset 0 = 0
		soc_cfg_write(0,1,1,0);		//write offset 0 = 1
		soc_cfg_write(0,2,1,0);		//write offset 0 = 2
		soc_cfg_write(0,3,1,0);		//write offset 0 = 3

		//burst read test
		soc_cfg_write(0,3,1,0);		//write offset 0 = 3
		soc_compare_data = 3;		//read offset 0 result should be 3, other offset is reserved and result equal to offset 0
		soc_cfg_read(0,0);			//read offset 0 
		soc_cfg_read(1,0);			//read offset 4
		soc_cfg_read(2,0);			//read offset 8
		soc_cfg_read(3,0);			//read offset 12


		//burst write/read test
		soc_cfg_write(0,0,1,0);		//write offset 0 = 0
		soc_compare_data = 0;		//read offset 0 result should be 0
		soc_cfg_read(0,0);
		soc_cfg_write(0,1,1,0);		//write offset 0 = 1
		soc_compare_data = 1;		//read offset 0 result should be 1
		soc_cfg_read(0,0);
		soc_cfg_write(0,2,1,0);		//write offset 0 = 2
		soc_compare_data = 2;		//read offset 0 result should be 2
		soc_cfg_read(0,0);
		soc_cfg_write(0,3,1,0);		//write offset 0 = 3
		soc_compare_data = 3;		//read offset 0 result should be 3
		soc_cfg_read(0,0);
		
		//write to offset 1, the data in offset 0 should no changed.
		soc_cfg_write(0,3,1,0);	// write to offset 0, data = 3
		soc_cfg_write(0,0,2,0);	// write to offset 1 (strobe = 4'b0010) , data = 0
		soc_compare_data = 3;	// data should be 3 in offset 0
		soc_cfg_read(0,0);		//read offset 0
		
`ifdef NotSupport_Test		
		//no support below test in IO_SERDES module
		//IO_SERDES output axi_awready_out = 1 and axi_wready_out = 1 when both axi_awvalid_in=1 and axi_wvalid_in=1
		//it will cause dead lock if testbench set axi_awvalid=1 and wait for axi_awready
		soc_cfg_write_addr(0,0);
		soc_cfg_write_data(0,1,0);
		soc_cfg_write_addr(0,0);
		soc_cfg_write_data(1,1,0);
		soc_cfg_write_addr(0,0);
		soc_cfg_write_data(2,1,0);
		soc_cfg_write_addr(0,0);
		soc_cfg_write_data(3,1,0);
`endif //NotSupport_Test		

	end

	//Dump data_send
	initial begin
		//$monitor($time, "=>soc_as_is_tdata=%x, soc_as_is_tvalid=%b, soc_is_as_tready=%b", soc_as_is_tdata, soc_as_is_tvalid, soc_is_as_tready);
		
		while (1) begin
			@ (posedge soc_coreclk);
			//#39;				 //use delay to workaround get data_send incorrect issue
			if (soc_as_is_tvalid && soc_is_as_tready) begin
				$display($time, "=> soc data_send	 : soc_as_is_tdata=%x, soc_as_is_tvalid=%b, soc_is_as_tready=%b, %x, %x, %b, %x, %x", soc_as_is_tdata, soc_as_is_tvalid, soc_is_as_tready, soc_as_is_tstrb, soc_as_is_tkeep, soc_as_is_tlast, soc_as_is_tid, soc_as_is_tuser);
			end
		end

	end

	//Dump data_received
	initial begin
		//$monitor($time, "=>fpga_is_as_tdata=%x, fpga_is_as_tvalid=%b", fpga_is_as_tdata, fpga_is_as_tvalid);
		
		while (1) begin
			@ (posedge fpga_coreclk);
			if (fpga_is_as_tvalid) begin
				$display($time, "=> fpga data_received : fpga_is_as_tdata=%x, fpga_is_as_tvalid=%b, %x, %x, %b, %x, %x", fpga_is_as_tdata, fpga_is_as_tvalid, fpga_is_as_tstrb, fpga_is_as_tkeep, fpga_is_as_tlast, fpga_is_as_tid, fpga_is_as_tuser);

			end
		end

	end

	// config register read result compare_data

	initial begin
		//$monitor($time, "=>fpga_is_as_tdata=%x, fpga_is_as_tvalid=%b", fpga_is_as_tdata, fpga_is_as_tvalid);
		
		while (1) begin
			@ (posedge soc_coreclk);
			if (soc_axi_rvalid && soc_axi_rready) begin
				if (soc_axi_rdata == soc_compare_data)
					$display($time, "=> soc soc_cfg_read data compare : [PASS], soc_axi_rdata= %x", soc_axi_rdata);
				else 
					$display($time, "=> soc soc_cfg_read data compare : [FAIL], soc_axi_rdata= %x, soc_compare_data=%x", soc_axi_rdata, soc_compare_data);

			end
		end

	end
	
	
	// test_sequence_control
	reg [31:0] k;
	reg [31:0]test_seq;
	
	initial begin
		
		for (k=0;k<(TOTAL_TEST_LOOP+1);k=k+1) begin
			test_seq = k;
			$display($time, "=> test_sequence_control set test_seq=%x", test_seq);
			if (k < TEST003_START)
				#(2000);
			else 
				#(4000);
		end
		
		$finish;
		
	end


	//test002 soc provide soc_as_is_tdata, soc_as_is_tstrb, soc_as_is_tkeep, soc_as_is_tlast, soc_as_is_tid, soc_as_is_tuser, soc_as_is_tvalid, soc_as_is_tready to fpga

	reg [31:0]test002_partA_done, test002_partB_done;
	// test002_partA : soc side - TX/RX test
	reg[31:0]idx1;
	reg[31:0] i;
	initial begin
		//$monitor($time, "=>soc_as_is_tdata=%x, soc_as_is_tvalid=%b, soc_as_is_tready=%b, soc_is_as_tready=%b", soc_as_is_tdata, soc_as_is_tvalid, soc_as_is_tready, soc_is_as_tready);
		
		#2000;
		for (i=0;i<TEST002_CNT;i=i+1) begin

			
			while (test_seq<=i) begin
				@ (posedge soc_coreclk);
				//$display($time, "=> soc wait test_seq=%x, i=%x", test_seq, i);
			end
			$display("test002_partA : soc side - TX/RX test");
			soc_apply_reset(40+i*10, 40);			//change coreclk phase in soc

			#40;
			soc_cc_ls_enable=1;
			soc_cfg_write(0,1,1,0);
			$display($time, "=> soc rxen_ctl=1");
			#400;
			soc_cfg_write(0,3,1,0);
			$display($time, "=> soc txen_ctl=1");
			#200;
			soc_as_is_tdata = 32'h5a5a5a5a;
			#40;

			
			@ (posedge soc_coreclk);
			// wait util soc_is_as_tready == 1 then change data
			for(idx1=0; idx1<16; idx1=idx1+1)begin
				soc_as_is_tdata <=  idx1 * 32'h11111111;
				soc_as_is_tstrb <=  idx1 * 4'h1;
				soc_as_is_tkeep <=  idx1 * 4'h1;
				soc_as_is_tid <=  idx1 * 2'h1;
				soc_as_is_tuser <=  idx1 * 2'h1;
				soc_as_is_tlast <=  idx1 * 1'h1;
				soc_as_is_tvalid <= 1;
				
				@ (posedge soc_coreclk);
				while (soc_is_as_tready == 0) begin
						@ (posedge soc_coreclk);
				end
			end
			soc_as_is_tvalid <= 0;

			#200;
			
			test002_partA_done = i;
			$display($time, "=> soc set test002_partA_done=%x, i=%x", test002_partA_done, i);
		end
		

		//$finish;

	end

	// test002_partB : fpga side RX/TX test
	reg[31:0]idx2;
	reg[31:0] j;
	
	initial begin
		//$monitor($time, "=>fpga_as_is_tdata=%x, fpga_as_is_tvalid=%b, fpga_as_is_tready=%b, as_fifo_cnt=%d, fpga_is_as_tready=%b, fpga_is_as_tvalid=%b",fpga_as_is_tdata, fpga_as_is_tvalid, fpga_as_is_tready, as_fifo_cnt, fpga_is_as_tready, fpga_is_as_tvalid);
		#2000;
		
		for (j=0; j<TEST002_CNT; j=j+1) begin
		
			while (test_seq<=j) begin
				@ (posedge soc_coreclk);
				//$display($time, "=> fpga wait test_seq=%x, j=%x", test_seq, j);
			end

			$display("test002_partB : fpga side - TX/RX test");
			fpga_apply_reset(40,40);		//fix coreclk phase in fpga
			

			#40;
			fpga_cc_ls_enable=1;
			fpga_cfg_write(0,1,1,0);
			$display($time, "=> fpga rxen_ctl=1");
			#400;
			fpga_cfg_write(0,3,1,0);
			$display($time, "=> fpga txen_ctl=1");
			#200;

			fpga_as_is_tdata = 32'h5a5a5a5a;
			fpga_as_is_tready = 1;

			@ (posedge fpga_coreclk);
			//for Axis Switch Rx
			for(idx2=0; idx2<16; idx2=idx2+1)begin
				@ (posedge fpga_coreclk);
				while ( fpga_is_as_tvalid == 0) begin
					@ (posedge fpga_coreclk);
				end
				$display($time, "=> fpga idx2=%x", idx2);
			end

			#200;
			test002_partB_done = j;
			$display($time, "=> fpga set test002_partB_done=%x, j=%x", test002_partB_done, j);
		end

		//$finish;

	end


	// test003 : simulation the behavior of fpga axis_switch rx buffer full
	// Step 1. soc provide data and valid=1 to fpga
	// Step 2. fpga default send tready=1 to soc
	// step 3. fpga set tready=0 (to simulation the behavior of fpga axis_switch rx buffer full)
	// step 4. soc provide valid=0 to fpga
	// step 5. fpga set tready=1
	// step 6. soc provide data and valid=1 to fpga

	// test003_partA : soc side - TX/RX test with tready toggle
	reg[31:0] test003_partA_done, test003_partB_done;
	reg[31:0]idx3;
	reg[31:0] m;
	initial begin
		//$monitor($time, "=>soc_as_is_tdata=%x, soc_as_is_tvalid=%b, soc_as_is_tready=%b, soc_is_as_tready=%b", soc_as_is_tdata, soc_as_is_tvalid, soc_as_is_tready, soc_is_as_tready);
		#2000;
		
		for (m=0;m<TEST003_CNT;m=m+1) begin

			
			while (test_seq < (m+TEST003_START)) begin
				@ (posedge soc_coreclk);
				//$display($time, "=> soc wait test_seq=%x, m=%x", test_seq, m);
			end
			$display("test003_partA : soc side - TX/RX test with tready toggle");
			soc_apply_reset(40+m*10, 40);			//change coreclk phase in soc

			#40;
			soc_cc_ls_enable=1;
			soc_cfg_write(0,1,1,0);
			$display($time, "=> soc rxen_ctl=1");
			#400;
			soc_cfg_write(0,3,1,0);
			$display($time, "=> soc txen_ctl=1");
			#200;
			soc_as_is_tdata = 32'h5a5a5a5a;
			
			@ (posedge soc_coreclk);
			
			// wait util soc_is_as_tready == 1 then change data
			for(idx3=0; idx3<16; idx3=idx3+1)begin
				soc_as_is_tdata <=  idx3 * 32'h11111111;
				soc_as_is_tstrb <=  idx3 * 4'h1;
				soc_as_is_tkeep <=  idx3 * 4'h1;
				soc_as_is_tid <=  idx3 * 2'h1;
				soc_as_is_tuser <=  idx3 * 2'h1;
				soc_as_is_tlast <=  idx3 * 1'h1;
				soc_as_is_tvalid <= 1;
				
				@ (posedge soc_coreclk);
				while (soc_is_as_tready == 0) begin
						@ (posedge soc_coreclk);
				end
			end
			soc_as_is_tvalid <= 0;

			#200;
			
			test003_partA_done = m;
			$display($time, "=> soc set test003_partA_done=%x, m=%x", test003_partA_done, m);
		end
		

		//$finish;

	end

	// test003_partB : fpga side RX/TX test
	reg[31:0]idx4;
	reg[7:0]as_fifo_cnt;
	reg[31:0] n;
	initial begin
		//$monitor($time, "=>fpga_as_is_tdata=%x, fpga_as_is_tvalid=%b, fpga_as_is_tready=%b, as_fifo_cnt=%d, fpga_is_as_tready=%b, fpga_is_as_tvalid=%b",fpga_as_is_tdata, fpga_as_is_tvalid, fpga_as_is_tready, as_fifo_cnt, fpga_is_as_tready, fpga_is_as_tvalid);
		#2000;
		
		for (n=0; n<TEST003_CNT; n=n+1) begin

			while (test_seq < (n+TEST003_START)) begin
				@ (posedge soc_coreclk);
				//$display($time, "=> fpga wait test_seq=%x, n=%x", test_seq, n);
			end


			$display("fpga side - TX/RX test");
			fpga_apply_reset(40,40);		//fix coreclk phase in fpga
			
			as_fifo_cnt = 0;

			#40;
			fpga_cc_ls_enable=1;
			fpga_cfg_write(0,1,1,0);
			$display($time, "=> fpga rxen_ctl=1");
			#400;
			fpga_cfg_write(0,3,1,0);
			$display($time, "=> fpga txen_ctl=1");
			#200;

			fpga_as_is_tdata = 32'h5a5a5a5a;
			fpga_as_is_tready = 1;

			@ (posedge fpga_coreclk);
			while ( fpga_is_as_tvalid == 0) begin
				@ (posedge fpga_coreclk);
			end

			//for Axis Switch Rx
			for(idx4=0; idx4<16; idx4=idx4+1)begin
				if (fpga_is_as_tvalid)
					as_fifo_cnt = as_fifo_cnt + 1;
					
				if (as_fifo_cnt == 4 && fpga_is_as_tvalid )  begin
						fpga_as_is_tready <= 0;
						repeat(20) @ (posedge fpga_coreclk); //wait for 20 coreclk
						fpga_as_is_tready <= 1;
						as_fifo_cnt = as_fifo_cnt + 1;  //add as_fifo_cnt to avoid enter
				end
				else fpga_as_is_tready <= 1;

				$display($time, "=> fpga fpga_as_is_tready=%b, idx4=%x, as_fifo_cnt=%x", fpga_as_is_tready, idx4, as_fifo_cnt);
				@ (posedge fpga_coreclk);

			end

			#200;
			test003_partB_done = n;
			$display($time, "=> fpga set test003_partB_done=%x, n=%x", test003_partB_done, n);
			
		end

		//$finish;

	end

	

	always #(ioclk_pd/2) ioclk = ~ioclk;

	always #(dlyclk_pd/2) dlyclk = ~dlyclk;
	

	//apply reset
	task soc_apply_reset;
		input real delta1;		// for POR De-Assert
		input real delta2;		// for reset De-Assert
		begin
			#(40);
			$display($time, "=> soc POR Assert"); 
			soc_resetb = 0;
			$display($time, "=> soc reset Assert"); 
			soc_rst = 1;
			#(delta1);

			$display($time, "=> soc POR De-Assert"); 
			soc_resetb = 1;

			#(delta2);
			$display($time, "=> soc reset De-Assert"); 
			soc_rst = 0;
		end	
	endtask
	
	task fpga_apply_reset;
		input real delta1;		// for POR De-Assert
		input real delta2;		// for reset De-Assert
		begin
			#(40);
			$display($time, "=> fpga POR Assert"); 
			fpga_resetb = 0;
			$display($time, "=> fpga reset Assert"); 
			fpga_rst = 1;
			#(delta1);

			$display($time, "=> fpga POR De-Assert"); 
			fpga_resetb = 1;

			#(delta2);
			$display($time, "=> fpga reset De-Assert"); 
			fpga_rst = 0;
		end
	endtask
	
	task soc_delay_valid;		//input tdata and valid_delay 
		input [31:0] tdata;
		input [7:0] valid_delay;
		
		begin
			soc_as_is_tdata <= tdata;
			soc_as_is_tvalid <= 0;
			//$display($time, "=> soc_delay_valid before : valid_delay=%x", valid_delay); 
			repeat (valid_delay) @ (posedge soc_coreclk);
			//$display($time, "=> soc_delay_valid after  : valid_delay=%x", valid_delay); 
			soc_as_is_tvalid <= 1;
			@ (posedge soc_coreclk);
			while (soc_is_as_tready == 0) begin
					@ (posedge soc_coreclk);
			end
			$display($time, "=> soc_delay_valid : soc_as_is_tdata=%x, soc_as_is_tvalid=%b, soc_is_as_tready=%b, valid_delay=%x", soc_as_is_tdata, soc_as_is_tvalid, soc_is_as_tready, valid_delay); 
			@ (posedge soc_coreclk);
			soc_as_is_tvalid <= 0;
			
		end
		
	endtask
		

	task soc_cfg_write_addr;		//input addr and valid_delay 
		input [11:0] axi_awaddr;
		input [7:0] valid_delay;
		
		begin
			soc_axi_awaddr <= axi_awaddr;
			soc_axi_awvalid <= 0;
			//$display($time, "=> soc_delay_valid before : valid_delay=%x", valid_delay); 
			repeat (valid_delay) @ (posedge soc_coreclk);
			//$display($time, "=> soc_delay_valid after  : valid_delay=%x", valid_delay); 
			soc_axi_awvalid <= 1;
			@ (posedge soc_coreclk);
			while (soc_axi_awready == 0) begin
					@ (posedge soc_coreclk);
			end
			$display($time, "=> soc_cfg_write_addr : soc_axi_awaddr=%x, soc_axi_awvalid=%b, soc_axi_awready=%b", soc_axi_awaddr, soc_axi_awvalid, soc_axi_awready); 
			soc_axi_awvalid <= 0;
		end
		
	endtask

	task soc_cfg_write_data;		//input data, strb and valid_delay 
		input [31:0] axi_wdata;
		input [3:0] axi_wstrb;
		
		input [7:0] valid_delay;
		
		begin
			soc_axi_wdata <= axi_wdata;
			soc_axi_wstrb <= axi_wstrb;
			soc_axi_wvalid <= 0;
			//$display($time, "=> soc_delay_valid before : valid_delay=%x", valid_delay); 
			repeat (valid_delay) @ (posedge soc_coreclk);
			//$display($time, "=> soc_delay_valid after  : valid_delay=%x", valid_delay); 
			soc_axi_wvalid <= 1;
			@ (posedge soc_coreclk);
			while (soc_axi_wready == 0) begin
					@ (posedge soc_coreclk);
			end
			$display($time, "=> soc_cfg_write_data : soc_axi_wdata=%x, axi_wstrb=%x, soc_axi_wvalid=%b, soc_axi_wready=%b", soc_axi_wdata, axi_wstrb, soc_axi_wvalid, soc_axi_wready); 
			soc_axi_wvalid <= 0;
		end
		
	endtask

	task soc_cfg_write;		//input addr, data, strb and valid_delay 
		input [11:0] axi_awaddr;
		input [31:0] axi_wdata;
		input [3:0] axi_wstrb;
		input [7:0] valid_delay;
		
	
		begin
			soc_axi_awaddr <= axi_awaddr;
			soc_axi_awvalid <= 0;
			soc_axi_wdata <= axi_wdata;
			soc_axi_wstrb <= axi_wstrb;
			soc_axi_wvalid <= 0;
			//$display($time, "=> soc_delay_valid before : valid_delay=%x", valid_delay); 
			repeat (valid_delay) @ (posedge soc_coreclk);
			//$display($time, "=> soc_delay_valid after  : valid_delay=%x", valid_delay); 
			soc_axi_awvalid <= 1;
			soc_axi_wvalid <= 1;
			@ (posedge soc_coreclk);
			while (soc_axi_awready == 0) begin		//assume both soc_axi_awready and soc_axi_wready assert as the same time.
					@ (posedge soc_coreclk);
			end
			$display($time, "=> soc_cfg_write : soc_axi_awaddr=%x, soc_axi_awvalid=%b, soc_axi_awready=%b, soc_axi_wdata=%x, axi_wstrb=%x, soc_axi_wvalid=%b, soc_axi_wready=%b", soc_axi_awaddr, soc_axi_awvalid, soc_axi_awready, soc_axi_wdata, axi_wstrb, soc_axi_wvalid, soc_axi_wready); 
			soc_axi_awvalid <= 0;
			soc_axi_wvalid <= 0;
		end
		
	endtask

	task fpga_cfg_write;		//input addr, data, strb and valid_delay 
		input [11:0] axi_awaddr;
		input [31:0] axi_wdata;
		input [3:0] axi_wstrb;
		input [7:0] valid_delay;
		
		begin
			fpga_axi_awaddr <= axi_awaddr;
			fpga_axi_awvalid <= 0;
			fpga_axi_wdata <= axi_wdata;
			fpga_axi_wstrb <= axi_wstrb;
			fpga_axi_wvalid <= 0;
			//$display($time, "=> fpga_delay_valid before : valid_delay=%x", valid_delay); 
			repeat (valid_delay) @ (posedge fpga_coreclk);
			//$display($time, "=> fpga_delay_valid after  : valid_delay=%x", valid_delay); 
			fpga_axi_awvalid <= 1;
			fpga_axi_wvalid <= 1;
			@ (posedge fpga_coreclk);
			while (fpga_axi_awready == 0) begin		//assume both fpga_axi_awready and fpga_axi_wready assert as the same time.
					@ (posedge fpga_coreclk);
			end
			$display($time, "=> fpga_cfg_write : fpga_axi_awaddr=%x, fpga_axi_awvalid=%b, fpga_axi_awready=%b, fpga_axi_wdata=%x, axi_wstrb=%x, fpga_axi_wvalid=%b, fpga_axi_wready=%b", fpga_axi_awaddr, fpga_axi_awvalid, fpga_axi_awready, fpga_axi_wdata, axi_wstrb, fpga_axi_wvalid, fpga_axi_wready); 
			fpga_axi_awvalid <= 0;
			fpga_axi_wvalid <= 0;
		end
		
	endtask

	task soc_cfg_read;		//input addr and valid_delay 
		input [11:0] axi_araddr;
		input [7:0] valid_delay;
		//input [7:0] compare_data;
		
		begin
			soc_axi_araddr <= axi_araddr;
			soc_axi_arvalid <= 0;
			soc_axi_rready <= 0;
			//$display($time, "=> soc_delay_valid before : valid_delay=%x", valid_delay); 
			repeat (valid_delay) @ (posedge soc_coreclk);
			//$display($time, "=> soc_delay_valid after  : valid_delay=%x", valid_delay); 
			soc_axi_arvalid <= 1;
			@ (posedge soc_coreclk);
			while (soc_axi_arready == 0) begin		
					@ (posedge soc_coreclk);
			end
			$display($time, "=> soc_cfg_read : soc_axi_araddr=%x, soc_axi_arvalid=%b, soc_axi_arready=%b", soc_axi_araddr, soc_axi_arvalid, soc_axi_arready); 
			
			
			soc_axi_arvalid <= 0;
			//$display($time, "=> soc_delay_valid before : valid_delay=%x", valid_delay); 
			repeat (valid_delay) @ (posedge soc_coreclk);
			//$display($time, "=> soc_delay_valid after  : valid_delay=%x", valid_delay); 
			soc_axi_rready <= 1;
			@ (posedge soc_coreclk);
			while (soc_axi_rvalid == 0) begin		
					@ (posedge soc_coreclk);
			end
			$display($time, "=> soc_cfg_read : soc_axi_rdata=%x, soc_axi_rready=%b, soc_axi_rvalid=%b", soc_axi_rdata, soc_axi_rready, soc_axi_rvalid); 
			soc_axi_rready <= 0;

		end
		
	endtask

endmodule


