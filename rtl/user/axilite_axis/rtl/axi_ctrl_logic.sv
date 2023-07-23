///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axi_ctrl_logic
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/07/05
///////////////////////////////////////////////////////////////////////////////

module axi_ctrl_logic(
    input wire axi_aclk,
    input wire axi_aresetn,
    output logic axi_interrupt,

    // backend interface, axilite_master (LM)
    output logic bk_lm_wstart,
    output logic [31:0] bk_lm_waddr,
    output logic [31:0] bk_lm_wdata,
    output logic [3:0]  bk_lm_wstrb,
    input wire bk_lm_wdone,
    output logic bk_lm_rstart,
    output logic [31:0] bk_lm_raddr,
    input wire [31:0] bk_lm_rdata,
    input wire bk_lm_rdone,

    // backend interface, axilite_slave (LS)
    input wire bk_ls_wstart,
    input wire [14:0] bk_ls_waddr,
    input wire [31:0] bk_ls_wdata,
    input wire [3:0]  bk_ls_wstrb,
    input wire bk_ls_rstart,
    input wire [14:0] bk_ls_raddr,
    output logic [31:0] bk_ls_rdata,
    output logic bk_ls_rdone,

    // backend interface, axis_master (SM)
    output logic bk_sm_start,
    output logic [31:0] bk_sm_data,
    output logic [3:0] bk_sm_tstrb,
    output logic [3:0] bk_sm_tkeep,
    //output logic [1:0] bk_sm_tid,
    output logic [1:0] bk_sm_user,
    input wire bk_sm_nordy,
    input wire bk_sm_done,

    // backend interface, axis_slave (SS)
    input wire [31:0] bk_ss_data,
    input wire [3:0] bk_ss_tstrb,
    input wire [3:0] bk_ss_tkeep,
    //input wire [1:0] bk_ss_tid,
    input wire [1:0] bk_ss_user,
    input wire bk_ss_tlast,
    output logic bk_ss_ready,
    input wire bk_ss_valid
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

    // FSM state
    enum logic [2:0] {AXI_WAIT_DATA, AXI_DECIDE_DEST, AXI_MOVE_DATA, AXI_SEND_BKEND, AXI_TRIG_INT} axi_state, axi_next_state;
    enum logic {AXI_WR, AXI_RD} fifo_out_trans_typ;
    enum logic [1:0] {TRANS_LS, TRANS_SS} next_trans, last_trans;

    // FSM state, sequential logic, axis
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            axi_state <= AXI_WAIT_DATA;
        end
        else begin
            axi_state <= axi_next_state;
        end
    end

    logic enough_ls_data, enough_ss_data;
    assign enough_ls_data = fifo_ls_rd_vld;
    assign enough_ss_data = fifo_ss_rd_vld;

    // FSM state, combinational logic, axis
    always_comb begin
        axi_next_state = axi_state;

        case(axi_state)
            AXI_WAIT_DATA:
                if(enough_ls_data || enough_ss_data)begin
                    axi_next_state = AXI_DECIDE_DEST;
                end
            /*AXI_DECIDE_DEST:
                if(enough_data)begin
                    axi_next_state = AXIS_SEND_DATA;
                end
                else begin
                    axi_next_state = AXIS_WAIT_DATA;
                end
            AXI_MOVE_DATA:
                if(enough_data)begin
                    axi_next_state = AXIS_SEND_DATA;
                end
                else begin
                    axi_next_state = AXIS_WAIT_DATA;
                end
            default:
                axi_next_state = AXIS_WAIT_DATA;*/
        endcase
    end

    logic [35:0] read_padding_zero;

    // send backend data to LS fifo
    always_comb begin
        fifo_ls_data_in = '0;
        fifo_ls_wr_vld = 1'b0;
        read_padding_zero = 36'b0;

        // note: potential bug if bk_ls_wstart && bk_ls_rstart both 1, but this case will not happen if config_ctrl use cc_aa_enable for read/write exclusively
        if(bk_ls_wstart)begin
            fifo_ls_data_in = {AXI_WR, bk_ls_waddr, bk_ls_wdata, bk_ls_wstrb};
            fifo_ls_wr_vld = 1'b1;
        end
        else if(bk_ls_rstart)begin
            fifo_ls_data_in = {AXI_RD, bk_ls_raddr, read_padding_zero};
            fifo_ls_wr_vld = 1'b1;
        end
    end

    // send backend data to SS fifo
    always_comb begin
        fifo_ss_data_in = '0;
        fifo_ss_wr_vld = 1'b0;

        if(bk_ss_valid)begin
            fifo_ss_data_in = {bk_ss_data, bk_ss_tstrb, bk_ss_tkeep, bk_ss_user, bk_ss_tlast};
            fifo_ss_wr_vld = 1'b1;
        end
    end

    logic [14:0] fifo_out_waddr, fifo_out_raddr;
    logic [31:0] fifo_out_wdata;
    logic [3:0] fifo_out_wstrb;

    // get data from LS fifo
    always_comb begin
        {fifo_out_trans_typ, fifo_out_waddr, fifo_out_raddr, fifo_out_wdata, fifo_out_wstrb} = '0;
        fifo_ls_rd_rdy = 1'b0;
        fifo_ls_clear = 1'b0;

        if(axi_state == AXI_DECIDE_DEST)begin
            if(fifo_ls_data_out[FIFO_LS_WIDTH-1] == AXI_WR)
                {fifo_out_trans_typ, fifo_out_waddr, fifo_out_wdata, fifo_out_wstrb} = fifo_ls_data_out;
            else if(fifo_ls_data_out[FIFO_LS_WIDTH-1] == AXI_RD)
                {fifo_out_trans_typ, fifo_out_raddr} = fifo_ls_data_out[FIFO_LS_WIDTH-1:36]; // wdata + wstrb total 36bit
        end

        //if(next_data)begin // receive slave tready, can send next data
        //    fifo_ls_rd_rdy = 1'b1;
        //end
        //
        //if(bk_done)begin // clear fifo when transaction done to fix bug
        //    fifo_ls_clear = 1'b1;
        //end
    end

    logic [31:0] fifo_out_tdata;
    logic [3:0] fifo_out_tstrb, fifo_out_tkeep;
    logic [1:0] fifo_out_tuser;
    logic fifo_out_tlast;

    // get data from SS fifo
    always_comb begin
        {fifo_out_tdata, fifo_out_tstrb, fifo_out_tkeep, fifo_out_tuser, fifo_out_tlast} = '0;
        fifo_ss_rd_rdy = 1'b0;
        fifo_ss_clear = 1'b0;

        if(axi_state == AXI_DECIDE_DEST)begin
            {fifo_out_tdata, fifo_out_tstrb, fifo_out_tkeep, fifo_out_tuser, fifo_out_tlast} = fifo_ss_data_out;
        end

        //if(next_data)begin // receive slave tready, can send next data
        //    fifo_ss_rd_rdy = 1'b1;
        //end
        //
        //if(bk_done)begin // clear fifo when transaction done to fix bug
        //    fifo_ss_clear = 1'b1;
        //end
    end

    parameter MB_SUPP_LOW = 15'h2000, MB_SUPP_HIGH = 15'h201F;
    parameter AA_SUPP_LOW = 15'h2100, AA_SUPP_HIGH = 15'h2107, AA_UNSUPP_HIGH = 15'h2FFF;
    parameter FPGA_USER_WP_0 = 15'h0000, FPGA_USER_WP_1 = 15'h1FFF, FPGA_USER_WP_2 = 15'h3000, FPGA_USER_WP_3 = 15'h4FFF;
    logic next_ls, next_ss, wr_mb, rd_mb, wr_aa, rd_aa, rd_unsupp, trig_sm_wr, trig_sm_rd;
    // decide next transaction is LS / SS by round robin
    always_comb begin
        next_ls = 1'b0;
        next_ss = 1'b0;
        wr_mb = 1'b0;
        rd_mb = 1'b0;
        wr_aa = 1'b0;
        rd_aa = 1'b0;
        rd_unsupp = 1'b0;
        trig_sm_wr = 1'b0;
        trig_sm_rd = 1'b0;

        if(axi_next_state == AXI_DECIDE_DEST)begin
            next_ls = enough_ls_data & (~enough_ss_data | (last_trans == TRANS_SS));
            next_ss = enough_ss_data & (~enough_ls_data | (last_trans == TRANS_LS));
            if(next_ls)
                next_trans = TRANS_LS;
            else if(next_ss)
                next_trans = TRANS_SS;

            case(next_trans)
                TRANS_LS: begin
                    case(fifo_out_trans_typ)
                        AXI_WR: begin
                            if( (fifo_out_waddr >= MB_SUPP_LOW) && 
                                (fifo_out_waddr <= MB_SUPP_HIGH))begin // local access MB_reg
                                wr_mb = 1'b1;
                            end
                            else if((fifo_out_waddr >= AA_SUPP_LOW) && 
                                    (fifo_out_waddr <= AA_SUPP_HIGH))begin // local access AA_reg
                                wr_aa = 1'b1;
                            end
                            // in MB AA range but is unsupported, ignored
                            else if(((fifo_out_waddr >= FPGA_USER_WP_0) && 
                                     (fifo_out_waddr <= FPGA_USER_WP_1)) ||
                                    ((fifo_out_waddr >= FPGA_USER_WP_2) && 
                                     (fifo_out_waddr <= FPGA_USER_WP_3)))begin // fpga side access caravel usesr project wrapper, this do not fire in caravel side
                                trig_sm_wr = 1'b1;
                            end
                        end
                        AXI_RD: begin
                            if( (fifo_out_waddr >= MB_SUPP_LOW) && 
                                (fifo_out_waddr <= MB_SUPP_HIGH))begin // local access MB_reg
                                rd_mb = 1'b1;
                            end
                            else if((fifo_out_waddr >= AA_SUPP_LOW) && 
                                    (fifo_out_waddr <= AA_SUPP_HIGH))begin // local access AA_reg
                                rd_aa = 1'b1;
                            end
                            else if((fifo_out_waddr >= MB_SUPP_LOW) && 
                                    (fifo_out_waddr <= AA_UNSUPP_HIGH))begin // in MB AA range but is unsupported
                                rd_unsupp = 1'b1;
                            end
                            else if(((fifo_out_waddr >= FPGA_USER_WP_0) && 
                                     (fifo_out_waddr <= FPGA_USER_WP_1)) ||
                                    ((fifo_out_waddr >= FPGA_USER_WP_2) && 
                                     (fifo_out_waddr <= FPGA_USER_WP_3)))begin // fpga side access caravel usesr project wrapper, this do not fire in caravel side
                                trig_sm_rd = 1'b1;
                            end
                        end
                    endcase
                end
                TRANS_SS: begin
                    
                end
            endcase
        end
    end

    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            //last_trans <= TRANS_LS; // ?????????????????
            last_trans <= TRANS_SS;
        end
        else begin
            if(axi_state == AXI_MOVE_DATA)begin
                last_trans <= next_trans;
            end
        end
    end

















    // ===================================
    // The design is still in progress....
    // ===================================
//assign bk_lm_wstart = 0;
//assign bk_lm_waddr = 0;
//assign bk_lm_wdata = 0;
//assign bk_lm_wstrb = 0;
//assign bk_lm_rstart = 0;
//assign bk_lm_raddr = 0;
//assign bk_ls_rdata = 0;
//assign bk_ls_rdone = 0;
//assign bk_sm_start = 0;
//assign bk_sm_data = 0;
//assign bk_sm_tstrb = 0;
//assign bk_sm_tkeep = 0;
//assign bk_sm_user = 0;
//assign bk_ss_ready = 0;
//assign axi_interrupt = 0;

endmodule