`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/25/2023 11:28:50 AM
// Design Name: 
// Module Name: ps_axil
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


module ps_axil(
	//////////////////////////
	// PS AXI-Lite, from PS //
	//////////////////////////
	input  wire  [31: 0] s_axi_araddr,		//for address read
	output wire          s_axi_arready,
	input  wire          s_axi_arvalid,
	input  wire  [31: 0] s_axi_awaddr,		//for address write
	output wire          s_axi_awready,
	input  wire          s_axi_awvalid,
	input  wire          s_axi_bready,		//for write response
	output wire   [1: 0] s_axi_bresp,
	output wire          s_axi_bvalid,
	output wire  [31: 0] s_axi_rdata,		//for data read
	input  wire          s_axi_rready,
	output wire   [1: 0] s_axi_rresp,
	output wire          s_axi_rvalid,	
	input  wire  [31: 0] s_axi_wdata,		//for data write
	output wire          s_axi_wready,	
	input  wire   [3: 0] s_axi_wstrb,
	input  wire          s_axi_wvalid,	

	//////////////////
	// FSIC Signals //
	//////////////////
	output wire aa_mb_irq,
	input wire  is_ioclk,
    output wire [37:0] caravel_mprj_out,
    input wire [37:0] caravel_mprj_in,	

	/////////////////////////////
	// Global AXI-Lite Signals //
	/////////////////////////////
	input  wire          axi_clk,
	input  wire          axi_reset_n,
	input  wire          axis_clk,
	input  wire          axis_rst_n
    );

	////////////////////////////////
	// AXI-Lite Master, to Slaves //
	////////////////////////////////
	//Input
	wire          axi_awready0;		//for AXIS_SWITCH
	wire          axi_wready0;
	wire          axi_arready0;
	wire  [31: 0] axi_rdata0;
	wire          axi_rvalid0;
	wire          axi_wready1;		//for AXIL_AXIS
	wire          axi_awready1;
	wire          axi_arready1;
	wire  [31: 0] axi_rdata1;
	wire          axi_rvalid1;
	wire          axi_awready2;		//for IO_SERDES
	wire          axi_wready2;
	wire          axi_arready2;
	wire  [31: 0] axi_rdata2;
	wire          axi_rvalid2;
	//Output
	wire          axi_awvalid;
	wire  [14: 0] axi_awaddr;
	wire          axi_wvalid;
	wire  [31: 0] axi_wdata;
	wire   [3: 0] axi_wstrb;
	wire          axi_arvalid;
	wire  [14: 0] axi_araddr;
	wire          axi_rready;	
	
	//////////////////////
	// Target Selection //
	//////////////////////
	//Output
	wire          aa_enable;
	wire          as_enable;
	wire          is_enable;

	///////////////////////
	// Stream Connection //
	///////////////////////
	wire [31:0] is_as_tdata;
	wire [3:0] is_as_tstrb;
	wire [3:0] is_as_tkeep;
	wire is_as_tlast;
	wire [1:0] is_as_tid;
	wire is_as_tvalid;
	wire [1:0] is_as_tuser;
	wire as_is_tready;

	wire [31:0] as_is_tdata;
	wire [3:0] as_is_tstrb;
	wire [3:0] as_is_tkeep;
	wire as_is_tlast;
	wire [1:0]as_is_tid;
	wire as_is_tvalid;
	wire [1:0]as_is_tuser;
	wire is_as_tready;

	wire [31:0] as_aa_tdata;
	wire [3:0] as_aa_tstrb;
	wire [3:0] as_aa_tkeep;
	wire as_aa_tlast;
	wire as_aa_tvalid;
	wire [1:0] as_aa_tuser;
	wire aa_as_tready;
	
	wire [31:0] aa_as_tdata;
	wire [3:0] aa_as_tstrb;
	wire [3:0] aa_as_tkeep;
	wire aa_as_tlast;
	wire aa_as_tvalid;
	wire [1:0] aa_as_tuser;
	wire as_aa_tready;
    
	////////////////////////////
	// Internal Signals begin //
	////////////////////////////	
	reg [2:0] ps_axi_fsm_reg;
	reg ps_axi_request;
	reg ps_axi_request_rw;
	reg [3:0] ps_axi_wstrb;
	reg ps_axi_request_done;
	reg [31:0] ps_axi_request_add;
	reg [31:0] ps_axi_wdata;
	reg [31:0] ps_axi_rdata;
	
	reg [2:0] axi_fsm_reg;
	
	wire axi_awready;
	wire axi_wready;
	wire axi_arready;
	wire [31:0] axi_rdata;
	wire axi_rvalid;
	
	reg aa_enable_o;
	reg as_enable_o;
	reg is_enable_o;	

	//////////////////////////////////////
	// Internal signals for Ports begin //
	//////////////////////////////////////
	reg s_axi_arready_o;       //for address read
	reg s_axi_awready_o;       //for address write
	reg [1: 0] s_axi_bresp_o;  //for write response
	reg s_axi_bvalid_o;
	reg [31: 0] s_axi_rdata_o; //for data read
	reg [1: 0] s_axi_rresp_o;
	reg s_axi_rvalid_o;
	reg s_axi_wready_o;        //for data write	
	
    reg axi_awvalid_o;
    reg [14: 0] axi_awaddr_o;
    reg axi_wvalid_o;
    reg [31: 0] axi_wdata_o;
    reg [3: 0] axi_wstrb_o;
    reg axi_arvalid_o;
    reg [14: 0] axi_araddr_o;
    reg axi_rready_o;

    wire [11:0] is_serial_rxd;
    wire is_serial_rclk;
    wire [11:0] is_serial_txd;
    wire is_serial_tclk;
       
    assign caravel_mprj_out = {3'bz, is_ioclk, 1'bz, is_serial_tclk, 12'bz, is_serial_txd, 8'bz};
    assign is_serial_rclk = caravel_mprj_in[33];
    assign is_serial_rxd = caravel_mprj_in[31:20];     
	
	///////////////////////////////////
	// Assignment for Internal begin //
	///////////////////////////////////	
    assign axi_awready = ((({1{is_enable}} & axi_awready2) | ({1{as_enable}} & axi_awready0)) | ({1{aa_enable}} & axi_awready1));
	assign axi_wready = ((({1{is_enable}} & axi_wready2) | ({1{as_enable}} & axi_wready0)) | ({1{aa_enable}} & axi_wready1));
	assign axi_arready = ((({1{is_enable}} & axi_arready2) | ({1{as_enable}} & axi_arready0)) | ({1{aa_enable}} & axi_arready1));
	assign axi_rdata = ((({32{is_enable}} & axi_rdata2) | ({32{as_enable}} & axi_rdata0)) | ({32{aa_enable}} & axi_rdata1));
	assign axi_rvalid = ((({1{is_enable}} & axi_rvalid2) | ({1{as_enable}} & axi_rvalid0)) | ({1{aa_enable}} & axi_rvalid1));
		
	////////////////////////////////
	// Assignment for Ports begin //
	////////////////////////////////	
	assign s_axi_arready = s_axi_arready_o;    //for address read
	assign s_axi_awready = s_axi_awready_o;    //for address write
	assign s_axi_bresp = s_axi_bresp_o;        //for write response
	assign s_axi_bvalid = s_axi_bvalid_o;
	assign s_axi_rdata = s_axi_rdata_o;        //for data read
	assign s_axi_rresp = s_axi_rresp_o;
	assign s_axi_rvalid = s_axi_rvalid_o;
	assign s_axi_wready = s_axi_wready_o;      //for data write
	
    assign axi_awvalid = axi_awvalid_o;
    assign axi_awaddr = axi_awaddr_o;
    assign axi_wvalid = axi_wvalid_o;
    assign axi_wdata = axi_wdata_o;
    assign axi_wstrb = axi_wstrb_o;
    assign axi_arvalid = axi_arvalid_o;
    assign axi_araddr = axi_araddr_o;
    assign axi_rready = axi_rready_o;	
	
	assign aa_enable = aa_enable_o;
	assign as_enable = as_enable_o;
	assign is_enable = is_enable_o;

	//////////////////////////// 
	// Local paramaters begin //
	////////////////////////////
	localparam axi_fsm_idle = 3'b000;
	localparam axi_fsm_read_data = 3'b001;
	localparam axi_fsm_read_complete = 3'b010;
	localparam axi_fsm_write_data = 3'b011;
	localparam axi_fsm_write_complete = 3'b100;
	localparam axi_fsm_write_response = 3'b101;
		
	///////////////////////////////////////////////
	// Always for PS-AXI-Lite Interface handling //
	///////////////////////////////////////////////	
	always @ ( posedge axi_clk or negedge axi_reset_n)
	begin
		if ( !axi_reset_n )
		begin
			ps_axi_fsm_reg <= axi_fsm_idle;
			ps_axi_request <= 1'b0;
			ps_axi_request_rw <= 1'b0;
			ps_axi_wstrb <= 4'b0;
			ps_axi_request_add <= 32'b0;
			ps_axi_wdata <= 32'b0;
	
            s_axi_arready_o <= 1'b0;    //for address read
	        s_axi_awready_o <= 1'b0;    //for address write
            s_axi_bresp_o <= 2'b0;      //for write response
            s_axi_bvalid_o <= 1'b0;
            s_axi_rdata_o <= 32'b0;      //for data read
            s_axi_rresp_o <= 2'b0;
            s_axi_rvalid_o <= 1'b0;
            s_axi_wready_o <= 1'b0;     //for data write			
		end else
		begin
			case ( ps_axi_fsm_reg )
				axi_fsm_idle:
				begin
                    if ( s_axi_awvalid ) begin
                        s_axi_awready_o <= 1'b1;    //for address write
                        ps_axi_request_rw <= 1'b1;                                            
                        ps_axi_request_add <= s_axi_awaddr;
                        ps_axi_fsm_reg <= axi_fsm_write_data;     
				    end else if ( s_axi_arvalid ) begin
				        s_axi_arready_o <= 1'b1;    //for address read 
                        ps_axi_request <= 1'b1;
                        ps_axi_request_rw <= 1'b0;
                        ps_axi_request_add <= s_axi_araddr;
                        ps_axi_fsm_reg <= axi_fsm_read_data;
				    end
				end
				axi_fsm_read_data:
				begin
                    s_axi_arready_o <= 1'b0;    //for address read
                    if ( s_axi_rready && ps_axi_request_done ) begin
                        s_axi_rdata_o <= ps_axi_rdata;      //for data read
                        s_axi_rvalid_o <= 1'b1;
                        ps_axi_request <= 1'b0;
                        ps_axi_request_add <= 32'b0;                        
                        ps_axi_fsm_reg <= axi_fsm_read_complete;                                                
                    end				
				end
				axi_fsm_read_complete:
				begin
                    s_axi_rdata_o <= 32'b0;      //for data read
                    s_axi_rvalid_o <= 1'b0;
                    ps_axi_fsm_reg <= axi_fsm_idle;
				end
				axi_fsm_write_data:
				begin
				    s_axi_awready_o <= 1'b0;    //for address write
				    if ( s_axi_wvalid ) begin
                        ps_axi_request <= 1'b1;
                        ps_axi_wstrb <= s_axi_wstrb;
                        ps_axi_wdata <= s_axi_wdata;
                        s_axi_wready_o <= 1'b1;     //for data write                          	                                
                        ps_axi_fsm_reg <= axi_fsm_write_complete;       
				    end 
				end
				axi_fsm_write_complete:
				begin
				    s_axi_wready_o <= 1'b0;     //for data write
				    if ( ps_axi_request_done ) begin
                        s_axi_bvalid_o <= 1'b1;				    
                        ps_axi_request <= 1'b0;
                        ps_axi_request_add <= 32'b0;                        
                        ps_axi_wstrb <= 4'b0;
                        ps_axi_wdata <= 32'b0;
                        ps_axi_fsm_reg <= axi_fsm_write_response;
				    end
				end
				axi_fsm_write_response:
				begin
				    if ( s_axi_bready ) begin
                        s_axi_bvalid_o <= 1'b0;
                        ps_axi_fsm_reg <= axi_fsm_idle;                        
                    end				        
				end
			endcase			
		end
	end
	
	///////////////////////////////////////////////////
	// Always for AXI-Lite Master Interface handling //
	///////////////////////////////////////////////////
	always @ ( posedge axi_clk or negedge axi_reset_n )
	begin
		if ( !axi_reset_n ) begin

            ps_axi_request_done <= 1'b0;
            ps_axi_rdata <= 32'b0;
			
			axi_awvalid_o <= 1'b0;
			axi_awaddr_o <= 15'b0;
			axi_wvalid_o <= 1'b0;
			axi_wdata_o <= 32'b0;
			axi_wstrb_o <= 4'b0;
			axi_arvalid_o <= 1'b0;
			axi_araddr_o <= 15'b0;
			axi_rready_o <= 1'b0;			

			axi_fsm_reg <= axi_fsm_idle;
		end else begin
			case ( axi_fsm_reg )
				axi_fsm_idle:
				begin
					ps_axi_request_done <= 1'b0;			
					if ( ps_axi_request && !ps_axi_request_done ) begin
						if ( ps_axi_request_rw ) begin
							axi_awvalid_o <= 1'b1;
							axi_awaddr_o <= ps_axi_request_add[14:0];							
							axi_wvalid_o <= 1'b1;
							axi_wdata_o <= ps_axi_wdata;
							axi_wstrb_o <= ps_axi_wstrb;
							axi_fsm_reg <= axi_fsm_write_data;
						end else begin
							axi_arvalid_o <= 1'b1;							
							axi_araddr_o <= ps_axi_request_add[14:0];
							axi_rready_o <= 1'b1;
							axi_fsm_reg <= axi_fsm_read_data;
						end
					end
				end
				axi_fsm_read_data:
				begin
					if ( axi_arready && axi_rvalid) begin
						axi_arvalid_o <= 1'b0;
						axi_araddr_o <= 15'b0;
						axi_rready_o <= 1'b0;
						ps_axi_rdata <= axi_rdata;
						ps_axi_request_done <= 1'b1;
						axi_fsm_reg <= axi_fsm_idle;												
					end else if ( axi_arready ) begin
						axi_araddr_o <= 15'b0;
						axi_arvalid_o <= 1'b0;
						axi_fsm_reg <= axi_fsm_read_complete;	
					end
				end
				axi_fsm_read_complete:
				begin
					if ( axi_rvalid ) begin
						axi_rready_o <= 1'b0;
						ps_axi_rdata <= axi_rdata;
						ps_axi_request_done <= 1'b1;
						axi_fsm_reg <= axi_fsm_idle;						
					end
				end
				axi_fsm_write_data:
				begin
					if ( axi_awready && axi_wready) begin
						axi_awvalid_o <= 1'b0;
						axi_awaddr_o <= 15'b0;
						axi_wvalid_o <= 1'b0;
						axi_wdata_o <= 32'b0;
						axi_wstrb_o <= 4'b0;
						ps_axi_request_done <= 1'b1;						
						axi_fsm_reg <= axi_fsm_idle;	
					end	else begin
						if ( axi_awready ) begin
							axi_awaddr_o <= 15'b0;
							axi_awvalid_o <= 1'b0;
							axi_fsm_reg <= axi_fsm_write_complete;								
						end
					end
				end
				axi_fsm_write_complete:
				begin
					if ( axi_wready) begin
						axi_wvalid_o <= 1'b0;
						axi_wdata_o <= 32'b0;
						axi_wstrb_o <= 4'b0;
						ps_axi_request_done <= 1'b1;					
						axi_fsm_reg <= axi_fsm_idle;	
					end
				end
			endcase
		end
	end	
	
	/////////////////////////////////
	// Always for Target Selection //
	/////////////////////////////////
	always @ ( posedge axi_clk or negedge axi_reset_n)
	begin
		if ( !axi_reset_n )
		begin
			aa_enable_o <= 1'b0;
			as_enable_o <= 1'b0;
			is_enable_o <= 1'b0;
		end else
		begin
			aa_enable_o <= ( (ps_axi_request_add[31:12] >= 20'h60000) && (ps_axi_request_add[31:12] <= 20'h60005) )? 1'b1 : 1'b0;
			as_enable_o <= ( ps_axi_request_add[31:12] == 20'h60006 )? 1'b1 : 1'b0;
			is_enable_o <= ( ps_axi_request_add[31:12] == 20'h60007 )? 1'b1 : 1'b0;
		end
	end	

AXIS_SWz #(.pADDR_WIDTH( 15 ),
           .pDATA_WIDTH( 32 )) 
	PL_AS (
		.axi_reset_n(axi_reset_n),
		.axis_clk(axis_clk),
		.axis_rst_n(axis_rst_n),
		//axi_lite slave interface
		//write addr channel
		.axi_awvalid(axi_awvalid),
		.axi_awaddr(axi_awaddr),
		.axi_awready(axi_awready0),		//o
		//write data channel
		.axi_wvalid(axi_wvalid),
		.axi_wdata(axi_wdata),
		.axi_wstrb(axi_wstrb),
		.axi_wready(axi_wready0),		//o
		//read addr channel
		.axi_arvalid(axi_arvalid),
		.axi_araddr(axi_araddr),
		.axi_arready(axi_arready0),		//o
		//read data channel
		.axi_rvalid(axi_rvalid0),		//o
		.axi_rdata(axi_rdata0),		//o
		.axi_rready(axi_rready),
		.cc_as_enable(as_enable),
		//AXI Stream inputs for Axis Axilite grant 1
		.aa_as_tdata(aa_as_tdata),
		.aa_as_tstrb(aa_as_tstrb),
		.aa_as_tkeep(aa_as_tkeep),   
		.aa_as_tlast(aa_as_tlast),       
		.aa_as_tvalid(aa_as_tvalid),
		.aa_as_tuser(aa_as_tuser),       
		.as_aa_tready(as_aa_tready),	//o
		//AXI Stream outputs for IO Serdes
		.as_is_tdata(as_is_tdata),
		.as_is_tstrb(as_is_tstrb),
		.as_is_tkeep(as_is_tkeep), 
		.as_is_tlast(as_is_tlast),        
		.as_is_tid(as_is_tid), 
		.as_is_tvalid(as_is_tvalid),
		.as_is_tuser(as_is_tuser),     
		.is_as_tready(is_as_tready),	//i
		//AXI Input Stream for IO_Serdes
		.is_as_tdata(is_as_tdata),
		.is_as_tstrb(is_as_tstrb),    
		.is_as_tkeep(is_as_tkeep),
		.is_as_tlast(is_as_tlast),
		.is_as_tid(is_as_tid),
		.is_as_tvalid(is_as_tvalid),
		.is_as_tuser(is_as_tuser),
		.as_is_tready(as_is_tready),	//o
		//AXI Output Stream for Axis_Axilite
		.as_aa_tdata(as_aa_tdata),
		.as_aa_tstrb(as_aa_tstrb),    
		.as_aa_tkeep(as_aa_tkeep),
		.as_aa_tlast(as_aa_tlast),    
		.as_aa_tvalid(as_aa_tvalid),
		.as_aa_tuser(as_aa_tuser), 
		.aa_as_tready(aa_as_tready)	//i
	);

AXIL_AXIS #(.pADDR_WIDTH( 15 ),
            .pDATA_WIDTH( 32 )) 
	PL_AA (
		//AXIL
		.s_wready(axi_wready1),	//o  
		.s_awready(axi_awready1),	//o  
		.s_arready(axi_arready1), 	//o  
		.s_rdata(axi_rdata1),		//o
		.s_rvalid(axi_rvalid1),    //o
		.s_awvalid(axi_awvalid),
		.s_awaddr(axi_awaddr),
		.s_wvalid(axi_wvalid),
		.s_wdata(axi_wdata),
		.s_wstrb(axi_wstrb),
		.s_arvalid(axi_arvalid),
		.s_araddr(axi_araddr),
		.s_rready(axi_rready),
		.cc_aa_enable(aa_enable),
		//AS->AA
		.as_aa_tdata(as_aa_tdata),
		.as_aa_tstrb(as_aa_tstrb),
		.as_aa_tkeep(as_aa_tkeep),
		.as_aa_tlast(as_aa_tlast),
		.as_aa_tvalid(as_aa_tvalid),
		.as_aa_tuser(as_aa_tuser),
		.aa_as_tready(aa_as_tready),	//o
		//AA->AS
		.aa_as_tdata(aa_as_tdata),		//o
		.aa_as_tstrb(aa_as_tstrb),		//o
		.aa_as_tkeep(aa_as_tkeep),		//o
		.aa_as_tlast(aa_as_tlast),		//o
		.aa_as_tvalid(aa_as_tvalid),	//o
		.aa_as_tuser(aa_as_tuser),		//o
		.as_aa_tready(as_aa_tready),		
		//Otheraxi_rready
 		.mb_irq(aa_mb_irq),	//o
		.axi_clk(axi_clk),
		.axi_reset_n(axi_reset_n),
		.axis_clk(axis_clk),
		.axis_rst_n(axis_rst_n)
	);	

IO_SERDES #(.pSERIALIO_WIDTH( 12 ),
             .pADDR_WIDTH( 15 ),
             .pDATA_WIDTH( 32 ),
             .pRxFIFO_DEPTH( 5 ),
             .pCLK_RATIO( 4 )) 
	PL_IS (
		.axi_awready(axi_awready2),	//o
		.axi_wready(axi_wready2),	//o
		.axi_arready(axi_arready2),	//o
		.axi_rdata(axi_rdata2),		//o
		.axi_rvalid(axi_rvalid2),	//o
		.axi_awvalid(axi_awvalid),
		.axi_awaddr(axi_awaddr),
		.axi_wvalid(axi_wvalid),
		.axi_wdata(axi_wdata),
		.axi_wstrb(axi_wstrb),
		.axi_arvalid(axi_arvalid),
		.axi_araddr(axi_araddr),
		.axi_rready(axi_rready),
		.cc_is_enable(is_enable),

		.is_as_tdata(is_as_tdata),		//o
		.is_as_tstrb(is_as_tstrb),		//o
		.is_as_tkeep(is_as_tkeep),		//o
		.is_as_tlast(is_as_tlast),		//o
		.is_as_tid(is_as_tid),			//o
		.is_as_tvalid(is_as_tvalid),	//o
		.is_as_tuser(is_as_tuser),		//o
		.as_is_tready(as_is_tready),

		.as_is_tdata(as_is_tdata),
		.as_is_tstrb(as_is_tstrb),
		.as_is_tkeep(as_is_tkeep),
		.as_is_tlast(as_is_tlast),
		.as_is_tid(as_is_tid),
		.as_is_tvalid(as_is_tvalid),
		.as_is_tuser(as_is_tuser),
		.is_as_tready(is_as_tready),	//o

		.ioclk(is_ioclk),
		.serial_rxd(is_serial_rxd),
		.serial_rclk(is_serial_rclk),
		.serial_txd(is_serial_txd),		//o
		.serial_tclk(is_serial_tclk),	//o
		.axi_clk(axi_clk),
		.axi_reset_n(axi_reset_n),
		.axis_clk(axis_clk),
		.axis_rst_n(axis_rst_n)
	);
    
endmodule
