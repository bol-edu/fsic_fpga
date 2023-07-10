///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axi_ctrl_logic
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/07/05
///////////////////////////////////////////////////////////////////////////////

module axi_ctrl_logic(
    input axi_aclk,
    input axi_aresetn,
    output axi_interrupt,

    // backend interface, axilite_master (LM)
    output logic bk_lm_wstart,
    output logic [31:0] bk_lm_waddr,
    output logic [31:0] bk_lm_wdata,
    output logic [3:0]  bk_lm_wstrb,
    input logic bk_lm_wdone,
    output logic bk_lm_rstart,
    output logic [31:0] bk_lm_raddr,
    input logic [31:0] bk_lm_rdata,
    input logic bk_lm_rdone,

    // backend interface, axilite_slave (LS)
    input logic bk_ls_wstart,
    input logic [14:0] bk_ls_waddr,
    input logic [31:0] bk_ls_wdata,
    input logic [3:0]  bk_ls_wstrb,
    input logic bk_ls_rstart,
    input logic [14:0] bk_ls_raddr,
    output logic [31:0] bk_ls_rdata,
    output logic bk_ls_rdone,

    // backend interface, axis_master (SM)
    output logic bk_sm_start,
    output logic [31:0] bk_sm_data,
    output logic [3:0] bk_sm_tstrb,
    output logic [3:0] bk_sm_tkeep,
    //output logic [1:0] bk_sm_tid,
    output logic [1:0] bk_sm_user,
    input logic bk_sm_nordy,
    input logic bk_sm_done,

    // backend interface, axis_slave (SS)
    input logic [31:0] bk_ss_data,
    input logic [3:0] bk_ss_tstrb,
    input logic [3:0] bk_ss_tkeep,
    //input logic [1:0] bk_ss_tid,
    input logic [1:0] bk_ss_user,
    input logic bk_ss_tlast,
    output logic bk_ss_ready,
    input logic bk_ss_valid
);

    parameter FIFO_LS_WIDTH = 8'd52, FIFO_LS_DEPTH = 8'd8;
    parameter FIFO_SS_WIDTH = 8'd45, FIFO_SS_DEPTH = 8'd8;

    logic fifo_ls_wr_vld, fifo_ls_wr_rdy, fifo_ls_rd_vld, fifo_ls_rd_rdy, fifo_ls_clear;
    logic [FIFO_LS_WIDTH-1:0] fifo_ls_data_in, fifo_ls_data_out;
    logic fifo_ss_wr_vld, fifo_ss_wr_rdy, fifo_ss_rd_vld, fifo_ss_rd_rdy, fifo_ss_clear;
    logic [FIFO_SS_WIDTH-1:0] fifo_ss_data_in, fifo_ss_data_out;

    // data format: 
    // if write: {rd_wr_1bit, waddr_15bit, wdata_32bit, wstrb_4bit}, total 52bit
    // if read:  {rd_wr_1bit, raddr_15bit, padding_zero_36bit},      total 52bit
    axi_fifo #(.WIDTH(FIFO_LS_WIDTH), .DEPTH(FIFO_LS_DEPTH)) fifo_ls(
        .clk(axi_aclk),
        .rst_n(axi_aresetn),
        .wr_vld(fifo_ls_wr_vld),
        .rd_rdy(fifo_ls_rd_rdy),
        .data_in(fifo_ls_data_in),
        .data_out(fifo_ls_data_out),
        .wr_rdy(fifo_ls_wr_rdy),
        .rd_vld(fifo_ls_rd_vld),
        .clear(fifo_ls_clear));

    // data format: 
    // {data_32bit, tstrb_4bit, tkeep_4bit, user_2bit, tlast_1bit}, total 43bit
    axi_fifo #(.WIDTH(FIFO_SS_WIDTH), .DEPTH(FIFO_SS_DEPTH)) fifo_ss(
        .clk(axi_aclk),
        .rst_n(axi_aresetn),
        .wr_vld(fifo_ss_wr_vld),
        .rd_rdy(fifo_ss_rd_rdy),
        .data_in(fifo_ss_data_in),
        .data_out(fifo_ss_data_out),
        .wr_rdy(fifo_ss_wr_rdy),
        .rd_vld(fifo_ss_rd_vld),
        .clear(fifo_ss_clear));

    enum logic [1:0] {TRANS_LS, TRANS_SS} next_trans, last_trans;


    // ===================================
    // The design is still in progress....
    // ===================================
assign bk_lm_wstart = 0;
assign bk_lm_waddr = 0;
assign bk_lm_wdata = 0;
assign bk_lm_wstrb = 0;
assign bk_lm_rstart = 0;
assign bk_lm_raddr = 0;
assign bk_ls_rdata = 0;
assign bk_ls_rdone = 0;
assign bk_sm_start = 0;
assign bk_sm_data = 0;
assign bk_sm_tstrb = 0;
assign bk_sm_tkeep = 0;
assign bk_sm_user = 0;
assign bk_ss_ready = 0;
assign axi_interrupt = 0;

endmodule