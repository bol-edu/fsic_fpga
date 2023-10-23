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
	
	////////////////////////////////
	// AXI-Lite Master, to Slaves //
	////////////////////////////////
	input  wire          axi_awready0,		//for AXIS_SWITCH
	input  wire          axi_wready0,
	input  wire          axi_arready0,
	input  wire  [31: 0] axi_rdata0,
	input  wire          axi_rvalid0,	
	input  wire          axi_wready1,		//for AXIL_AXIS
	input  wire          axi_awready1,
	input  wire          axi_arready1,
	input  wire  [31: 0] axi_rdata1,
	input  wire          axi_rvalid1,
	input  wire          axi_awready2,		//for IO_SERDES
	input  wire          axi_wready2,
	input  wire          axi_arready2,
	input  wire  [31: 0] axi_rdata2,
	input  wire          axi_rvalid2,	
	output wire          axi_awvalid,
	output wire  [14: 0] axi_awaddr,
	output wire          axi_wvalid,
	output wire  [31: 0] axi_wdata,
	output wire   [3: 0] axi_wstrb,
	output wire          axi_arvalid,
	output wire  [14: 0] axi_araddr,
	output wire          axi_rready,	
	
	//////////////////////
	// Target Selection //
	//////////////////////
	output wire          aa_enable,
	output wire          as_enable,
	output wire          is_enable,

	/////////////////////////////
	// Global AXI-Lite Signals //
	/////////////////////////////
	input  wire          axi_clk,
	input  wire          axi_reset_n
    );
    
    
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
    
endmodule
