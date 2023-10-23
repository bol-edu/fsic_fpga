`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/04/2023 04:53:50 PM
// Design Name: 
// Module Name: aa_wrapper
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


module aa_wrapper(
  output wire          m_awvalid,
  output wire  [31: 0] m_awaddr,
  output wire          m_wvalid,
  output wire  [31: 0] m_wdata,
  output wire   [3: 0] m_wstrb,
  output wire          m_arvalid,
  output wire  [31: 0] m_araddr,
  output wire          m_rready,
  output wire  [31: 0] s_rdata,
  output wire          s_rvalid,
  output wire          s_awready,
  output wire          s_wready,
  output wire          s_arready,
  input  wire          s_awvalid,
  input  wire  [14: 0] s_awaddr,
  input  wire          s_wvalid,
  input  wire  [31: 0] s_wdata,
  input  wire   [3: 0] s_wstrb,
  input  wire          s_arvalid,
  input  wire  [14: 0] s_araddr,
  input  wire          s_rready,
  input  wire  [31: 0] m_rdata,
  input  wire          m_rvalid,
  input  wire          m_awready,
  input  wire          m_wready,
  input  wire          m_arready,
  input  wire          cc_aa_enable,
  input  wire  [31: 0] as_aa_tdata,
  input  wire   [3: 0] as_aa_tstrb,
  input  wire   [3: 0] as_aa_tkeep,
  input  wire          as_aa_tlast,
  input  wire          as_aa_tvalid,
  input  wire   [1: 0] as_aa_tuser,
  output  wire         aa_as_tready,
  output wire  [31: 0] aa_as_tdata,
  output wire   [3: 0] aa_as_tstrb,
  output wire   [3: 0] aa_as_tkeep,
  output wire          aa_as_tlast,
  output wire          aa_as_tvalid,
  output wire   [1: 0] aa_as_tuser,
  input  wire          as_aa_tready,
  output wire          mb_irq,
  input  wire          axi_clk,
  input  wire          axi_reset_n,
  input  wire          axis_clk,
  input  wire          axis_rst_n
);

AXIL_AXIS   aa_body (
    //out
    .m_awvalid(m_awvalid), 
    .m_awaddr(m_awaddr),
    .m_wvalid(m_wvalid),
    .m_wdata(m_wdata),
    .m_wstrb(m_wstrb),
    .m_arvalid(m_arvalid),
    .m_araddr(m_araddr),
    .m_rready(m_rready),
    .s_rdata(s_rdata),
    .s_rvalid(s_rvalid),
    .s_awready(s_awready),
    .s_wready(s_wready),
    .s_arready(s_arready),
    //input
    .s_awvalid(s_awvalid),
    .s_awaddr(s_awaddr),
    .s_wvalid(s_wvalid),
    .s_wdata(s_wdata),
    .s_wstrb(s_wstrb),
    .s_arvalid(s_arvalid),
    .s_araddr(s_araddr),
    .s_rready(s_rready),
    .m_rdata(m_rdata),
    .m_rvalid(m_rvalid),
    .m_awready(m_awready),
    .m_wready(m_wready),
    .m_arready(m_arready),
    .cc_aa_enable(cc_aa_enable),
    .as_aa_tdata(as_aa_tdata),
    .as_aa_tstrb(as_aa_tstrb),
    .as_aa_tkeep(as_aa_tkeep),
    .as_aa_tlast(as_aa_tlast),
    .as_aa_tvalid(as_aa_tvalid),
    .as_aa_tuser(as_aa_tuser),
    //out
    .aa_as_tready(aa_as_tready),
    .aa_as_tdata(aa_as_tdata),
    .aa_as_tstrb(aa_as_tstrb),
    .aa_as_tkeep(aa_as_tkeep),
    .aa_as_tlast(aa_as_tlast),
    .aa_as_tvalid(aa_as_tvalid),
    .aa_as_tuser(aa_as_tuser),
    //in
    .as_aa_tready(as_aa_tready),
    //out
    .mb_irq(mb_irq),
    //in
    .axi_clk(axi_clk),
    .axi_reset_n(axi_reset_n),
    .axis_clk(axis_clk),
    .axis_rst_n(axis_rst_n)
    );
    
endmodule
