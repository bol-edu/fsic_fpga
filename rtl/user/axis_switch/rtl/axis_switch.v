`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/14 10:28:55
// Design Name: 
// Module Name: AXIS_SW
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
module AXIS_SW #( parameter pADDR_WIDTH   = 12,
                  parameter pDATA_WIDTH   = 32
                )
(
    input  wire                             axi_reset_n,    
    input  wire                             axis_clk,
    input  wire                             axis_rst_n,

    //AXI Stream inputs for User Project grant 0
    input  wire [pDATA_WIDTH-1:0]           up_as_tdata,
    input  wire [pDATA_WIDTH/8-1:0]         up_as_tstrb,
    input  wire [pDATA_WIDTH/8-1:0]         up_as_tkeep,  
    input  wire                             up_as_tlast,      
    input  wire                             up_as_tvalid,
    input  wire [1:0]                       up_as_tuser,    
	input  wire                             up_hpri_req,
    output wire                             as_up_tready,
    //AXI Stream inputs for Axis Axilite grant 1
    input  wire [pDATA_WIDTH-1:0]           aa_as_tdata,
    input  wire [pDATA_WIDTH/8-1:0]         aa_as_tstrb,
    input  wire [pDATA_WIDTH/8-1:0]         aa_as_tkeep,   
    input  wire                             aa_as_tlast,       
    input  wire                             aa_as_tvalid,
    input  wire [1:0]                       aa_as_tuser,       
    output wire                             as_aa_tready,
    //AXI Stream inputs for Logic Analyzer grant 2
    input  wire [pDATA_WIDTH-1:0]           la_as_tdata,
    input  wire [pDATA_WIDTH/8-1:0]         la_as_tstrb,
    input  wire [pDATA_WIDTH/8-1:0]         la_as_tkeep, 
    input  wire                             la_as_tlast,          
    input  wire                             la_as_tvalid,
    input  wire [1:0]                       la_as_tuser,      
	input  wire                             la_hpri_req,
    output wire                             as_la_tready,
    //AXI Stream outputs for IO Serdes
    output  wire [pDATA_WIDTH-1:0]          as_is_tdata,
    output  wire [pDATA_WIDTH/8-1:0]        as_is_tstrb,
    output  wire [pDATA_WIDTH/8-1:0]        as_is_tkeep, 
    output  wire                            as_is_tlast,        
    output  wire [1:0]                      as_is_tid, 
    output  wire                            as_is_tvalid,
    output  wire [1:0]                      as_is_tuser,     
    input	wire                            is_as_tready,
 
    //Demux
    //AXI Input Stream for IO_Serdes
    input  wire [pDATA_WIDTH-1:0]           is_as_tdata,
    input  wire [pDATA_WIDTH/8-1:0]         is_as_tstrb,    
    input  wire [pDATA_WIDTH/8-1:0]         is_as_tkeep,
    input  wire                             is_as_tlast,
    input  wire [1:0]                       is_as_tid,
    input  wire                             is_as_tvalid,
    input  wire [1:0]                       is_as_tuser,
    output wire                             as_is_tready,
    //AXI Output Stream for User Project
    output wire [pDATA_WIDTH-1:0]           as_up_tdata,
    output wire [pDATA_WIDTH/8-1:0]         as_up_tstrb,    
    output wire [pDATA_WIDTH/8-1:0]         as_up_tkeep,
    output wire                             as_up_tlast,
    output wire                             as_up_tvalid,
    output wire [1:0]                       as_up_tuser,    
    input  wire                             up_as_tready,   
    //AXI Output Stream for Axis_Axilite
    output wire [pDATA_WIDTH-1:0]           as_aa_tdata,
    output wire [pDATA_WIDTH/8-1:0]         as_aa_tstrb,    
    output wire [pDATA_WIDTH/8-1:0]         as_aa_tkeep,
    output wire                             as_aa_tlast,    
    output wire                             as_aa_tvalid,
    output wire [1:0]                       as_aa_tuser, 
    input  wire                             aa_as_tready
);

localparam  USER_WIDTH = 2;
localparam  TID_WIDTH = 2;   

//for arbiter
//source 0 support req/hi_req for user project
//source 1 support req for axilite_axis
//source 2 support req/hi_req for Logic Analyzer
localparam N = 3; //Upstream master Num for Input port
localparam req_mask = 3'b111; //normal request mask for Upstream
localparam hi_req_mask = 3'b101; //high request mask for Upstream 
localparam last_support = 3'b000; //last signal support for hi request

//for Demux
// FIFO depth
localparam  FIFO_DEPTH = 8;   
//FIFO threshold setting
localparam TH = 4;    
//FIFO address width
localparam ADDR_WIDTH   = $clog2(FIFO_DEPTH);
//field offset for mem unit 
localparam STRB_OFFSET  = pDATA_WIDTH;
localparam KEEP_OFFSET  = STRB_OFFSET + pDATA_WIDTH/8;
localparam LAST_OFFSET  = KEEP_OFFSET + pDATA_WIDTH/8;
localparam TID_OFFSET   = LAST_OFFSET + 1;
localparam USER_OFFSET  = TID_OFFSET  + TID_WIDTH;
localparam WIDTH        = USER_OFFSET + USER_WIDTH;

//For Arbiter
wire [N-1:0]                req, hi_req;
reg  [N-1:0]                shift_req, shift_hi_req;
reg  [$clog2(N)-1:0]        base_ptr, base_hi_ptr;
reg  [N-1:0]                grant_reg = 3'b000, grant_next, shift_grant = 3'b000, shift_hi_grant= 3'b000;
reg                         frame_start_reg = 1'b0, frame_start_next;   

reg [N-1:0]                 hi_req_flag;

reg [pDATA_WIDTH-1:0]       m_axis_tdata_reg;
reg [pDATA_WIDTH/8-1:0]     m_axis_tstrb_reg;
reg [pDATA_WIDTH/8-1:0]     m_axis_tkeep_reg; 
reg                         m_axis_tlast_reg;        
reg                         m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg [USER_WIDTH-1:0]        m_axis_tuser_reg;     
reg [TID_WIDTH-1:0]         m_axis_tid_reg;

//for Demux
//FIFO control pointer
reg [ADDR_WIDTH:0] wr_ptr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] pre_rd_ptr_reg = {ADDR_WIDTH+1{1'b0}};   

(* ramstyle = "no_rw_check" *)
reg [WIDTH-1:0] mem[(2**ADDR_WIDTH)-1:0];

reg as_up_tvalid_reg; 
reg as_aa_tvalid_reg;  

wire full = ((wr_ptr_reg[ADDR_WIDTH] != rd_ptr_reg[ADDR_WIDTH]) && (wr_ptr_reg[ADDR_WIDTH-1:0] == rd_ptr_reg[ADDR_WIDTH-1:0]));    
wire empty = (wr_ptr_reg == rd_ptr_reg);  
wire above_th = (wr_ptr_reg > rd_ptr_reg) ? ((wr_ptr_reg - rd_ptr_reg) > TH): (((wr_ptr_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}})-(rd_ptr_reg ^ {1'b1, {ADDR_WIDTH{1'b0}}})) > TH);    

wire [WIDTH-1:0] s_axis;
generate
    assign s_axis[pDATA_WIDTH-1:0]                  = is_as_tdata;
    assign s_axis[STRB_OFFSET +: pDATA_WIDTH/8]     = is_as_tstrb;
    assign s_axis[KEEP_OFFSET +: pDATA_WIDTH/8]     = is_as_tkeep;
    assign s_axis[LAST_OFFSET]                      = is_as_tlast;
    assign s_axis[TID_OFFSET   +: TID_WIDTH]        = is_as_tid;
    assign s_axis[USER_OFFSET +: USER_WIDTH]        = is_as_tuser;
endgenerate

wire [WIDTH-1:0] m_axis = mem[rd_ptr_reg[ADDR_WIDTH-1:0]];    
wire [WIDTH-1:0] pre_m_axis = mem[pre_rd_ptr_reg[ADDR_WIDTH-1:0]];  

assign as_is_tready = !above_th; //IO_Serdes will delay  

//for Abiter
assign  req[0] = up_as_tvalid & req_mask[0];
assign  req[1] = aa_as_tvalid & req_mask[1];
assign  req[2] = la_as_tvalid & req_mask[2];
assign  hi_req[0] = up_hpri_req & hi_req_mask[0];
assign  hi_req[1] = hi_req_mask[1];
assign  hi_req[2] = la_hpri_req & hi_req_mask[2];

assign  as_is_tdata     = m_axis_tdata_reg;
assign  as_is_tstrb     = m_axis_tstrb_reg;
assign  as_is_tkeep     = m_axis_tkeep_reg; 
assign  as_is_tlast     = m_axis_tlast_reg;        
assign  as_is_tvalid    = m_axis_tvalid_reg;
assign  as_is_tuser     = m_axis_tuser_reg;   
assign  as_is_tid       = m_axis_tid_reg;

assign as_up_tready = grant_reg[0] && is_as_tready && m_axis_tvalid_reg;
assign as_aa_tready = grant_reg[1] && is_as_tready && m_axis_tvalid_reg;
assign as_la_tready = grant_reg[2] && is_as_tready && m_axis_tvalid_reg;

always @* begin
    if(frame_start_reg == 1'b0) begin 
        if(hi_req) begin
            case (base_hi_ptr) 
                2'b00: shift_hi_req = hi_req;
                2'b01: shift_hi_req = {hi_req[0], hi_req[2:1]};
                2'b10: shift_hi_req = {hi_req[1:0], hi_req[2]};
                2'b11: shift_hi_req = hi_req;
            endcase 
        end else begin          
            case (base_ptr) 
                2'b00: shift_req = req;
                2'b01: shift_req = {req[0], req[2:1]};
                2'b10: shift_req = {req[1:0], req[2]};
                2'b11: shift_req = req;
            endcase                 
        end
    end       
end
always @* begin
    if(frame_start_reg == 1'b0) begin 
        shift_hi_grant[2:0] = 3'b000;    
        shift_grant[2:0] = 3'b000;
        if(hi_req) begin
            if (shift_hi_req[0])       shift_hi_grant[0] = 1'b1;
            else if (shift_hi_req[1])  shift_hi_grant[1] = 1'b1; 
            else if (shift_hi_req[2])  shift_hi_grant[2] = 1'b1;           
        end else begin
            if (shift_req[0])       shift_grant[0] = 1'b1;
            else if (shift_req[1])  shift_grant[1] = 1'b1; 
            else if (shift_req[2])  shift_grant[2] = 1'b1; 
        end
    end    
end            
always @* begin
    if(frame_start_reg == 1'b0) begin
        if(hi_req) begin
            case (base_hi_ptr) 
                2'b00: grant_next = shift_hi_grant;
                2'b01: grant_next = {shift_hi_grant[1:0], shift_hi_grant[2]};
                2'b10: grant_next = {shift_hi_grant[0], shift_hi_grant[2:1]};
                2'b11: grant_next = shift_hi_grant;
            endcase  
        end else begin
            case (base_ptr) 
                2'b00: grant_next = shift_grant;
                2'b01: grant_next = {shift_grant[1:0], shift_grant[2]};
                2'b10: grant_next = {shift_grant[0], shift_grant[2:1]};
                2'b11: grant_next = shift_grant;
            endcase
        end
        if(grant_next != 0) frame_start_next = 1'b1;
    end else begin
        if ((grant_reg == 3'b001)||(grant_reg == 3'b010)||(grant_reg == 3'b100)) begin
            if (m_axis_tlast_reg == 1'b1)  //meet end condition                            
                frame_start_next = 1'b0;
            else
                frame_start_next = 1'b1;                 
        end else begin
            frame_start_next = 1'b0;
        end
        if(frame_start_next == 1'b0) grant_next = 1'b0;              
    end
end

always @(posedge axis_clk or negedge axi_reset_n) begin
    if (!axi_reset_n) begin
        base_ptr <= {($clog2(N)){1'b0}};
        base_hi_ptr <= {($clog2(N)){1'b0}}; 
        hi_req_flag <= {(N){1'b0}};       
    end else begin
        grant_reg <= grant_next;
        frame_start_reg <= frame_start_next;
        if((grant_reg != 0)) begin          
            if(grant_reg[0]) begin
                base_ptr <= 2'd1;
                base_hi_ptr <= 2'd1;
            end else if(grant_reg[1]) begin
                base_ptr <= 2'd2;
                base_hi_ptr <= 2'd2;
            end else if(grant_reg[2]) begin
                base_ptr <= 2'd0;
                base_hi_ptr <= 2'd0;
            end
        end 
        if(grant_reg == 3'b001) begin
            m_axis_tdata_reg <= up_as_tdata;
            m_axis_tstrb_reg <= up_as_tstrb;
            m_axis_tkeep_reg <= up_as_tkeep;
            if((up_hpri_req || hi_req_flag[0]) && (!last_support[0])) begin 
                if(up_hpri_req && !hi_req_flag[0]) begin
                    hi_req_flag[0] <= 1;
                end
                if(!up_hpri_req && hi_req_flag[0]) begin
                    m_axis_tlast_reg <= 1;
                end     
                if(as_is_tvalid && is_as_tready && m_axis_tlast_reg) begin
                    hi_req_flag[0] <= 0;
                    m_axis_tlast_reg <= 0;
                end
            end else begin
            //for  normal req
                m_axis_tlast_reg <= up_as_tlast;
            end 
            m_axis_tvalid_reg <= up_as_tvalid;
            m_axis_tuser_reg <= up_as_tuser;
            m_axis_tid_reg <= 2'b00;
        end
       if(grant_reg == 3'b010) begin
            m_axis_tdata_reg <= aa_as_tdata;
            m_axis_tstrb_reg <= aa_as_tstrb;
            m_axis_tkeep_reg <= aa_as_tkeep;
            m_axis_tlast_reg <= aa_as_tlast;
            m_axis_tvalid_reg <= aa_as_tvalid;
            m_axis_tuser_reg <= aa_as_tuser;
            m_axis_tid_reg <= 2'b01;       
        end
        if(grant_reg == 3'b100) begin
            m_axis_tdata_reg <= la_as_tdata;
            m_axis_tstrb_reg <= la_as_tstrb;
            m_axis_tkeep_reg <= la_as_tkeep;
            if((la_hpri_req || hi_req_flag[2]) && (!last_support[2])) begin            
                if(la_hpri_req && !hi_req_flag[2]) begin    
                    hi_req_flag[2] <= 1;
                end
                if(!la_hpri_req && hi_req_flag[2]) begin                
                    m_axis_tlast_reg <= 1;
                end     
                if(as_is_tvalid && is_as_tready && as_is_tlast) begin
                    hi_req_flag[2] <= 0;
                    m_axis_tlast_reg <= 0;
                end
            end else begin
            //for  normal req
                m_axis_tlast_reg <= la_as_tlast;
            end                
            m_axis_tvalid_reg <= la_as_tvalid;
            m_axis_tuser_reg <= la_as_tuser;
            m_axis_tid_reg <= 2'b10;        
        end                           
    end
end

//for Dexmux
// Write logic
always @(posedge axis_clk) begin
    if (is_as_tvalid) begin // for the current Io_serdes design
        mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= s_axis;
        wr_ptr_reg <= wr_ptr_reg + 1;
    end
    if (!axi_reset_n) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
    end
end

// Read logic
always @(posedge axis_clk) begin
    if(pre_m_axis[TID_OFFSET +: TID_WIDTH]==2'b00) begin
        if (up_as_tready) begin
            if (!empty && (wr_ptr_reg != pre_rd_ptr_reg)) begin
                as_up_tvalid_reg <= 1;
                rd_ptr_reg<=pre_rd_ptr_reg;
                pre_rd_ptr_reg <= pre_rd_ptr_reg + 1;
            end else begin
                as_up_tvalid_reg <= 0;
            end
        end
    end else if(pre_m_axis[TID_OFFSET +: TID_WIDTH]==2'b01) begin
        if (aa_as_tready) begin
            if (!empty && (wr_ptr_reg != pre_rd_ptr_reg)) begin
                as_aa_tvalid_reg <= 1;
                rd_ptr_reg<=pre_rd_ptr_reg;
                pre_rd_ptr_reg <= pre_rd_ptr_reg + 1;
            end else begin
                as_aa_tvalid_reg <= 0;
            end
        end    
    end else begin
        as_up_tvalid_reg <= 0;
        as_aa_tvalid_reg <= 0;
    end       

    if (!axi_reset_n) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        as_up_tvalid_reg <= 0; 
        as_aa_tvalid_reg <= 0;
    end
end

assign as_up_tvalid = ((m_axis[TID_OFFSET +: TID_WIDTH]==2'b00) && !empty) ? as_up_tvalid_reg: 0;
assign as_up_tdata = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b00) ? m_axis[pDATA_WIDTH - 1:0]: 0;
assign as_up_tstrb = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b00) ? m_axis[STRB_OFFSET +: pDATA_WIDTH/8]: 0;
assign as_up_tkeep = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b00) ? m_axis[KEEP_OFFSET +: pDATA_WIDTH/8]: 0;
assign as_up_tlast = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b00) ? m_axis[LAST_OFFSET]: 0;
assign as_up_tuser = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b00) ? m_axis[USER_OFFSET +: USER_WIDTH]: 0;

assign as_aa_tvalid =  ((m_axis[TID_OFFSET +: TID_WIDTH]==2'b01) && !empty) ? as_aa_tvalid_reg: 0;
assign as_aa_tdata = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b01) ? m_axis[pDATA_WIDTH-1:0]: 0;
assign as_aa_tstrb = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b01) ? m_axis[STRB_OFFSET +: pDATA_WIDTH/8]: 0;
assign as_aa_tkeep = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b01) ? m_axis[KEEP_OFFSET +: pDATA_WIDTH/8]: 0;
assign as_aa_tlast = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b01) ? m_axis[LAST_OFFSET]: 0;
assign as_aa_tuser = (m_axis[TID_OFFSET +: TID_WIDTH]==2'b01) ? m_axis[USER_OFFSET +: USER_WIDTH]: 0;

endmodule
