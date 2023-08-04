///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axi_ctrl_logic
//       AUTHOR: zack, Willy
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
    //parameter FIFO_SS_WIDTH = 8'd45, FIFO_SS_DEPTH = 8'd8;
    parameter FIFO_SS_WIDTH = 8'd34, FIFO_SS_DEPTH = 8'd8;

    logic fifo_ls_wr_vld, fifo_ls_wr_rdy, fifo_ls_rd_vld, fifo_ls_rd_rdy, fifo_ls_clear, fifo_ls_last;
    logic [FIFO_LS_WIDTH-1:0] fifo_ls_data_in, fifo_ls_data_out;
    logic fifo_ss_wr_vld, fifo_ss_wr_rdy, fifo_ss_rd_vld, fifo_ss_rd_rdy, fifo_ss_clear, fifo_ss_last;
    logic [FIFO_SS_WIDTH-1:0] fifo_ss_data_in, fifo_ss_data_out;

    // data format:
    // if write: {rd_wr_1bit, waddr_15bit, wdata_32bit, wstrb_4bit}, total 52bit
    // if read:  {rd_wr_1bit, raddr_15bit, padding_zero_36bit},      total 52bit
    axi_fifo #(.WIDTH(FIFO_LS_WIDTH), .DEPTH(FIFO_LS_DEPTH)) fifo_ls(
        .clk(axi_aclk),
        .rst_n(axi_aresetn),
        .wr_vld(fifo_ls_wr_vld),
        .rd_rdy(fifo_ls_rd_rdy),
        .hack(1'b0),
        .data_in(fifo_ls_data_in),
        .data_out(fifo_ls_data_out),
        .wr_rdy(fifo_ls_wr_rdy),
        .rd_vld(fifo_ls_rd_vld),
        .last(fifo_ls_last),
        .clear(fifo_ls_clear));

    // data format:
    // {data_32bit, user_2bit}, total 34bit
    axi_fifo #(.WIDTH(FIFO_SS_WIDTH), .DEPTH(FIFO_SS_DEPTH)) fifo_ss(
        .clk(axi_aclk),
        .rst_n(axi_aresetn),
        .wr_vld(fifo_ss_wr_vld),
        .rd_rdy(fifo_ss_rd_rdy),
        .hack(1'b0),
        .data_in(fifo_ss_data_in),
        .data_out(fifo_ss_data_out),
        .wr_rdy(fifo_ss_wr_rdy),
        .rd_vld(fifo_ss_rd_vld),
        .last(fifo_ss_last),
        .clear(fifo_ss_clear));

    // FSM state
    enum logic [2:0] {AXI_WAIT_DATA, AXI_DECIDE_DEST, AXI_MOVE_DATA, AXI_SEND_BKEND, AXI_TRIG_INT} axi_state, axi_next_state;
    enum logic {AXI_WR, AXI_RD} fifo_out_trans_typ;
    enum logic {TRANS_LS, TRANS_SS} next_trans, last_trans;

    // FSM state, sequential logic
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

    logic next_ls, next_ss, wr_mb, rd_mb, wr_aa, rd_aa, rd_unsupp, trig_sm_wr, trig_sm_rd, do_nothing, decide_done, trig_int, sync_trig_int, axi_interrupt_done, sync_trig_sm_wr, sync_trig_sm_rd, trig_lm_rd, send_bk_done, trig_lm_wr, sync_trig_lm_rd, rd_ss_complete;
    logic ls_rd_data_bk, ls_wr_data_done, get_next_data_ss, ss_wr_data_done;

    // FSM state, combinational logic
    always_comb begin
        axi_next_state = axi_state;

        case(axi_state)
            AXI_WAIT_DATA:
                if(enough_ls_data || enough_ss_data)begin
                    axi_next_state = AXI_DECIDE_DEST;
                end
            AXI_DECIDE_DEST:
                if(decide_done)begin
                    axi_next_state = AXI_MOVE_DATA;
                end
                else if(trig_sm_wr || trig_sm_rd || trig_lm_wr || trig_lm_rd)begin
                    axi_next_state = AXI_SEND_BKEND;
                end
                else if(do_nothing)begin
                    axi_next_state = AXI_WAIT_DATA;
                end
            AXI_MOVE_DATA:
                if(ls_rd_data_bk || sync_trig_sm_wr)
                    axi_next_state = AXI_SEND_BKEND;
                else if(ss_wr_data_done && sync_trig_int)
                    axi_next_state = AXI_TRIG_INT;
                else if(ls_wr_data_done || ss_wr_data_done)
                    axi_next_state = AXI_WAIT_DATA;
            AXI_SEND_BKEND:
                if(sync_trig_int)
                    axi_next_state = AXI_TRIG_INT;
                else if(send_bk_done)
                    axi_next_state = AXI_WAIT_DATA;
            AXI_TRIG_INT:
                if(axi_interrupt_done)
                    axi_next_state = AXI_WAIT_DATA;
            default:
                axi_next_state = AXI_WAIT_DATA;
        endcase
    end

    logic [35:0] read_padding_zero;
    assign read_padding_zero = 36'b0;

    // send backend data to LS fifo
    always_comb begin
        //fifo_ls_data_in = '0;
        //fifo_ls_wr_vld = 1'b0;
        //read_padding_zero = 36'b0;

        // note: potential bug if bk_ls_wstart && bk_ls_rstart both 1, but this case will not happen if config_ctrl use cc_aa_enable for read/write exclusively
        if(bk_ls_wstart)begin
            fifo_ls_data_in = {AXI_WR, bk_ls_waddr, bk_ls_wdata, bk_ls_wstrb};
            fifo_ls_wr_vld = 1'b1;
        end
        else if(bk_ls_rstart)begin
            fifo_ls_data_in = {AXI_RD, bk_ls_raddr, read_padding_zero};
            fifo_ls_wr_vld = 1'b1;
        end
        else begin
            fifo_ls_data_in = '0;
            fifo_ls_wr_vld = 1'b0;
        end
    end

    // send backend data to SS fifo
    always_comb begin
        //fifo_ss_data_in = '0;
        //fifo_ss_wr_vld = 1'b0;
        //bk_ss_ready =  1'b0;

        if(bk_ss_valid)begin
            fifo_ss_data_in = {bk_ss_data, bk_ss_user};
            fifo_ss_wr_vld = 1'b1;
        end
        else begin
            fifo_ss_data_in = '0;
            fifo_ss_wr_vld = 1'b0;
        end

        if(fifo_ss_wr_rdy == 1'b0)begin // fifo full, tell SS do not receive new data
            bk_ss_ready = 1'b0;
        end
        else
            bk_ss_ready = 1'b1;
    end

    logic [14:0] fifo_out_waddr, fifo_out_raddr;
    logic [31:0] fifo_out_wdata;
    logic [3:0] fifo_out_wstrb;

    assign fifo_ls_clear = 1'b0;

    // get data from LS fifo
    always_comb begin
        //{fifo_out_trans_typ, fifo_out_waddr, fifo_out_raddr, fifo_out_wdata, fifo_out_wstrb} = '0;
        //fifo_ls_rd_rdy = 1'b0;
        //fifo_ls_clear = 1'b0;

        //if(axi_state != AXI_WAIT_DATA)begin
            if(fifo_ls_data_out[FIFO_LS_WIDTH-1] == AXI_WR)
                {fifo_out_trans_typ, fifo_out_waddr, fifo_out_wdata, fifo_out_wstrb} = fifo_ls_data_out;
            else if(fifo_ls_data_out[FIFO_LS_WIDTH-1] == AXI_RD)
                {fifo_out_trans_typ, fifo_out_raddr} = fifo_ls_data_out[FIFO_LS_WIDTH-1:36]; // wdata + wstrb total 36bit
            else
                {fifo_out_trans_typ, fifo_out_waddr, fifo_out_raddr, fifo_out_wdata, fifo_out_wstrb} = '0;
        //end
        //else
        //    {fifo_out_trans_typ, fifo_out_waddr, fifo_out_raddr, fifo_out_wdata, fifo_out_wstrb} = '0;

        if((axi_state != AXI_WAIT_DATA) && (axi_next_state == AXI_WAIT_DATA) && (next_trans == TRANS_LS))begin // can send next data
            fifo_ls_rd_rdy = 1'b1;
        end
        else
            fifo_ls_rd_rdy = 1'b0;
    end

    logic [31:0] fifo_out_tdata;
    //logic [3:0] fifo_out_tstrb, fifo_out_tkeep;
    logic [1:0] fifo_out_tuser;
    //logic fifo_out_tlast;

    assign fifo_ss_clear = 1'b0;

    // get data from SS fifo
    always_comb begin
        //{fifo_out_tdata, fifo_out_tuser} = '0;
        //fifo_ss_rd_rdy = 1'b0;
        //fifo_ss_clear = 1'b0;

        if(axi_state != AXI_WAIT_DATA)begin
            {fifo_out_tdata, fifo_out_tuser} = fifo_ss_data_out;
        end
        else
            {fifo_out_tdata, fifo_out_tuser} = '0;

        if((axi_state != AXI_WAIT_DATA) && (axi_next_state == AXI_WAIT_DATA) && (next_trans == TRANS_SS))begin
            fifo_ss_rd_rdy = 1'b1;
        end
        else if(get_next_data_ss)begin // if tuser in SS is 1, AXI_WR need nex trans data
            fifo_ss_rd_rdy = 1'b1;
        end
        else
            fifo_ss_rd_rdy = 1'b0;
    end

    logic [31:0] fifo_out_tdata_old;
    always_ff@(posedge axi_aclk or negedge axi_aresetn) // keep old data from SS
        if(~axi_aresetn)
            fifo_out_tdata_old <= 32'b0;
        else
            fifo_out_tdata_old <= fifo_out_tdata;

    parameter MB_SUPP_LOW = 15'h2000, MB_SUPP_HIGH = 15'h201F;
    parameter AA_SUPP_LOW = 15'h2100, AA_SUPP_HIGH = 15'h2107, AA_UNSUPP_HIGH = 15'h2FFF;
    parameter FPGA_USER_WP_0 = 15'h0000, FPGA_USER_WP_1 = 15'h1FFF, FPGA_USER_WP_2 = 15'h3000, FPGA_USER_WP_3 = 15'h4FFF, CARAVEL_BASE= 32'h30000000;
    //assign decide_done = wr_mb | rd_mb | wr_aa | rd_aa | rd_unsupp | trig_sm_wr | trig_sm_rd;
    assign decide_done = wr_mb | rd_mb | wr_aa | rd_aa | rd_unsupp | rd_ss_complete;
    logic [3:0] wstrb_ss;
    logic [27:0] addr_ss;
    logic [31:0] data_ss;
    logic [1:0] ss_data_cnt, lm_rd_cnt;
    logic lm_rd_bk_sent;
    // note: dw address access
    logic [9:0]aa_index; // for index of aa_regs 
    logic [9:0]mb_index; // for index of mb_regs 

    // compute control signals according to source (LS / SS) and address range
    // note this is combinational, so the signals can only exist when state is AXI_DECIDE_DEST, 
    // if the signal need to be used in two clock cycles after the state, have to make a register for it
    always_comb begin
        //wr_mb = 1'b0;
        //rd_mb = 1'b0;
        //wr_aa = 1'b0;
        //rd_aa = 1'b0;
        //rd_unsupp = 1'b0;
        //trig_sm_wr = 1'b0;
        //trig_sm_rd = 1'b0;
        //do_nothing = 1'b0;
        //get_next_data_ss = 1'b0;
        //wstrb_ss = 4'b0;
        //addr_ss = 28'b0;
        //data_ss = 32'b0;
        //trig_int = 1'b0;
        //trig_lm_wr = 1'b0;
        //trig_lm_rd = 1'b0;
        //aa_index = 12'b0;
        //mb_index = 12'b0;

        next_trans = (next_ss) ? TRANS_SS : TRANS_LS;

        if(axi_state == AXI_DECIDE_DEST)begin
            case(next_trans)
                TRANS_LS: begin // request come from left side - axilite_slave
                    case(fifo_out_trans_typ)
                        AXI_WR: begin
                            if( (fifo_out_waddr >= MB_SUPP_LOW) &&
                                (fifo_out_waddr <= MB_SUPP_HIGH))begin // local access MB_reg
                                wr_mb = 1'b1;
                                trig_sm_wr = 1'b1;
                                // compute related index for dw address
                                mb_index = fifo_out_waddr[11:2] - MB_SUPP_LOW[11:2];
                            end
                            else if((fifo_out_waddr >= AA_SUPP_LOW) &&
                                    (fifo_out_waddr <= AA_SUPP_HIGH))begin // local access AA_reg
                                wr_aa = 1'b1;
                                // compute related index for dw address
                                aa_index = fifo_out_waddr[11:2] - AA_SUPP_LOW[11:2];
                            end
                            else if((fifo_out_waddr >= MB_SUPP_LOW) &&
                                    (fifo_out_waddr <= AA_UNSUPP_HIGH))begin // in MB AA range but is unsupported, ignored
                                do_nothing = 1'b1;
                            end
                            else if(((fifo_out_waddr >= FPGA_USER_WP_0) &&
                                     (fifo_out_waddr <= FPGA_USER_WP_1)) ||
                                    ((fifo_out_waddr >= FPGA_USER_WP_2) &&
                                     (fifo_out_waddr <= FPGA_USER_WP_3)))begin // fpga side access caravel usesr project wrapper, this do not fire in caravel side
                                trig_sm_wr = 1'b1;
                            end
                            else
                                do_nothing = 1'b1;
                        end
                        AXI_RD: begin
                            if( (fifo_out_raddr >= MB_SUPP_LOW) &&
                                (fifo_out_raddr <= MB_SUPP_HIGH))begin // local access MB_reg
                                rd_mb = 1'b1;
                                // compute related index for dw address
                                mb_index = fifo_out_raddr[11:2] - MB_SUPP_LOW[11:2];
                            end
                            else if((fifo_out_raddr >= AA_SUPP_LOW) &&
                                    (fifo_out_raddr <= AA_SUPP_HIGH))begin // local access AA_reg
                                rd_aa = 1'b1;
                                // compute related index for dw address
                                aa_index = fifo_out_raddr[11:2] - AA_SUPP_LOW[11:2];
                            end
                            else if((fifo_out_raddr >= MB_SUPP_LOW) &&
                                    (fifo_out_raddr <= AA_UNSUPP_HIGH))begin // in MB AA range but is unsupported
                                rd_unsupp = 1'b1;
                            end
                            else if(((fifo_out_raddr >= FPGA_USER_WP_0) &&
                                     (fifo_out_raddr <= FPGA_USER_WP_1)) ||
                                    ((fifo_out_raddr >= FPGA_USER_WP_2) &&
                                     (fifo_out_raddr <= FPGA_USER_WP_3)))begin // fpga side access caravel usesr project wrapper, this do not fire in caravel side
                                trig_sm_rd = 1'b1;
                            end
                            else
                                //do_nothing = 1'b1;
                                // should not happen, return all 1 for unsupported address request.
                                // ex: AA support local AA + MB + remote caravel MMIO resource = 20K.
                                // but user define AA MMIO resource = 24K, and send 24-1K address to AA.
                                rd_unsupp = 1'b1;
                        end
                    endcase
                end
                TRANS_SS: begin // request come from right side - axis_slave
                    case(fifo_out_tuser)
                        2'b01: begin // axis slave two-cycle data with tuser = 2'b01, can be converted to axilite write address / write data
                            if(ss_data_cnt == 2'b0)begin
                                get_next_data_ss = 1'b1;
                            end
                            else if(ss_data_cnt == 2'b1)begin
                                wstrb_ss = fifo_out_tdata_old[31:28];
                                addr_ss = fifo_out_tdata_old[27:0];
                                data_ss = fifo_out_tdata;
                                get_next_data_ss = 1'b0;

                                if( (addr_ss >= {13'b0, MB_SUPP_LOW}) &&
                                    (addr_ss <= {13'b0, MB_SUPP_HIGH}))begin // remote access MB_reg, write
                                    wr_mb = 1'b1;
                                    trig_int = 1'b1;
                                    // compute related index for dw address
                                    mb_index = addr_ss[11:2] - MB_SUPP_LOW[11:2];
                                end
                                else if((addr_ss >= {13'b0, FPGA_USER_WP_0}) &&
                                        (addr_ss <= {13'b0, FPGA_USER_WP_3}))begin
                                    trig_lm_wr = 1'b1;
                                end
                                else
                                    do_nothing = 1'b1; // ???????
                            end
                        end
                        2'b10: begin // axis slave one-cycle data with tuser = 2'b10, can be converted to axilite read address
                            addr_ss = fifo_out_tdata[27:0];
                            if((addr_ss >= {13'b0, FPGA_USER_WP_0}) &&
                               (addr_ss <= {13'b0, FPGA_USER_WP_3}))begin
                                    trig_lm_rd = 1'b1;
                                end
                            else
                                do_nothing = 1'b1;
                        end
                        2'b11: begin // read user project wrapper, data go back from CC through axis
                            data_ss = fifo_out_tdata;
                            rd_ss_complete = 1'b1;
                        end
                        default: do_nothing = 1'b1;
                    endcase
                end
            endcase
        end
        else begin
            wr_mb = 1'b0;
            rd_mb = 1'b0;
            wr_aa = 1'b0;
            rd_aa = 1'b0;
            rd_unsupp = 1'b0;
            trig_sm_wr = 1'b0;
            trig_sm_rd = 1'b0;
            do_nothing = 1'b0;
            get_next_data_ss = 1'b0;
            wstrb_ss = 4'b0;
            addr_ss = 28'b0;
            data_ss = 32'b0;
            trig_int = 1'b0;
            trig_lm_wr = 1'b0;
            trig_lm_rd = 1'b0;
            rd_ss_complete = 1'b0;
            aa_index = 10'b0; // dw address
            mb_index = 10'b0; // dw address
        end
    end

    // counter for SS
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            ss_data_cnt <= 2'b0;
        end
        else begin
            if((axi_state == AXI_DECIDE_DEST) && (next_trans == TRANS_SS) &&
                (fifo_out_tuser == 2'b01))
                ss_data_cnt <= ss_data_cnt + 1'b1;
            else if((axi_next_state == AXI_SEND_BKEND) && (next_trans == TRANS_LS))
                ss_data_cnt <= ss_data_cnt + 1'b1;
            else
                ss_data_cnt <= 2'b0;
        end
    end

    // counter for trig_lm_rd
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            lm_rd_cnt <= 2'b0;
        end
        else begin
            if((axi_next_state == AXI_SEND_BKEND) && (next_trans == TRANS_SS) &&
                (fifo_out_tuser == 2'b10))
                lm_rd_cnt <= lm_rd_cnt + 1'b1;
            else
                lm_rd_cnt <= 2'b0;
        end
    end

    // sync signal for latter state
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            //sync_rd_mb <= 1'b0;
            //sync_rd_aa <= 1'b0;
            //sync_rd_unsupp <= 1'b0;
            sync_trig_sm_wr <= 1'b0;
            sync_trig_sm_rd <= 1'b0;
            sync_trig_int <= 1'b0;
            //sync_trig_lm_wr
            sync_trig_lm_rd <= 1'b0;
        end
        else begin
            if(axi_state == AXI_WAIT_DATA)begin
                sync_trig_sm_wr <= 1'b0;
                sync_trig_sm_rd <= 1'b0;
                sync_trig_int <= 1'b0;
                sync_trig_lm_rd <= 1'b0;
            end
            else if(axi_state == AXI_DECIDE_DEST && axi_next_state != AXI_DECIDE_DEST)begin
                sync_trig_sm_wr <= trig_sm_wr;
                sync_trig_sm_rd <= trig_sm_rd;
                sync_trig_int <= trig_int;
                sync_trig_lm_rd <= trig_lm_rd;
            end
        end
    end

    assign bk_sm_tstrb = 4'b0;
    assign bk_sm_tkeep = 4'b0;

    logic [31:0] data_return;
    // registerName     offset Address
    // mb_reg_0[31:0]   'h0
    // mb_reg_1[31:0]   'h4
    // mb_reg_2[31:0]   'h8
    // mb_reg_3[31:0]   'hc
    // mb_reg_4[31:0]   'h10
    // mb_reg_5[31:0]   'h14
    // mb_reg_6[31:0]   'h18
    // mb_reg_7[31:0]   'h1c
    logic [31:0] mb_regs [7:0]; // 32bit * 8
    //--------------------------------------------------
    // for AA_REG description
    // offset 0-3 (32bit):
    // bit 0: Enable Interrupt
    // 0 = disable interrupt signal
    // 1 = enable interrupt signal
    // offset 4-7 (32bit):
    // bit 0: Interrupt Status
    // 0: interrupt has occurred
    // 0: no interrupt
    //--------------------------------------------------
    logic [31:0] aa_regs [1:0]; //32bit * 2
    logic mb_int_en;
    assign mb_int_en = aa_regs[0][0];

    // behavior description according to control signals and state
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            //last_trans <= TRANS_LS; // ?????????????????
            last_trans <= TRANS_SS;
            //mb_regs <= '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0}; // fail
            //mb_regs <= '0; // fail
            //mb_regs <= '{default: '0}; // fail
            //mb_regs <= {$bits(mb_regs){1'b0}}; // fail
            mb_regs[0] <= 32'b0;
            mb_regs[1] <= 32'b0;
            mb_regs[2] <= 32'b0;
            mb_regs[3] <= 32'b0;
            mb_regs[4] <= 32'b0;
            mb_regs[5] <= 32'b0;
            mb_regs[6] <= 32'b0;
            mb_regs[7] <= 32'b0;
            //aa_regs <= '{32'h0, 32'h0};
            aa_regs[0] <= 32'b0;
            aa_regs[1] <= 32'b0;
            ls_rd_data_bk <= 1'b0;
            ls_wr_data_done <= 1'b0;
            next_ls <= 1'b0;
            next_ss <= 1'b0;
            ss_wr_data_done <= 1'b0;
            axi_interrupt <= 1'b0;
            axi_interrupt_done <= 1'b0;
            bk_ls_rdata <= 32'b0;
            bk_ls_rdone <= 1'b0;
            bk_sm_start <= 1'b0;
            bk_sm_data <= 32'b0;
            bk_sm_user <= 2'b0;
            send_bk_done <= 1'b0;
            bk_lm_wstart <= 1'b0;
            bk_lm_waddr <= 32'b0;
            bk_lm_wdata <= 32'b0;
            bk_lm_wstrb <= 4'b0;
            bk_lm_rstart <= 1'b0;
            bk_lm_raddr <= 32'b0;
            lm_rd_bk_sent <= 1'b0;
            data_return <= 32'b0;
        end
        else begin
            if(axi_state == AXI_WAIT_DATA && axi_next_state == AXI_DECIDE_DEST)begin
                // decide next transaction is LS / SS by round robin
                next_ls <= enough_ls_data & (~enough_ss_data | (last_trans == TRANS_SS));
                next_ss <= enough_ss_data & (~enough_ls_data | (last_trans == TRANS_LS));
            end

            if(axi_state == AXI_DECIDE_DEST && axi_next_state != AXI_DECIDE_DEST)
                last_trans <= next_trans;

            if(axi_next_state == AXI_WAIT_DATA)begin
                ls_rd_data_bk <= 1'b0;
                ls_wr_data_done <= 1'b0;
                axi_interrupt <= 1'b0;
                axi_interrupt_done <= 1'b0;
                bk_ls_rdata <= 32'b0;
                bk_ls_rdone <= 1'b0;
                bk_sm_start <= 1'b0;
                bk_sm_data <= 32'b0;
                bk_sm_user <= 2'b0;
                send_bk_done <= 1'b0;
                lm_rd_bk_sent <= 1'b0;
                bk_lm_wstart <= 1'b0;
                bk_lm_waddr <= 32'b0;
                bk_lm_wdata <= 32'b0;
                bk_lm_wstrb <= 4'b0;
                data_return <= 32'b0;
            end
            else if(axi_next_state == AXI_MOVE_DATA)begin
                if(wr_mb)begin
                    // write MB_reg
                    case(next_trans)
                        TRANS_LS: begin
                            if(fifo_out_wstrb[0]) mb_regs[mb_index][7: 0] <= fifo_out_wdata[7:0];
                            if(fifo_out_wstrb[1]) mb_regs[mb_index][15:8] <= fifo_out_wdata[15:8];
                            if(fifo_out_wstrb[2]) mb_regs[mb_index][23:16] <= fifo_out_wdata[23:16];
                            if(fifo_out_wstrb[3]) mb_regs[mb_index][31:24] <= fifo_out_wdata[31:24];
                            ls_wr_data_done <= 1'b1;
                        end
                        TRANS_SS: begin
                            if(wstrb_ss[0]) mb_regs[mb_index][7: 0] <= data_ss[7:0];
                            if(wstrb_ss[1]) mb_regs[mb_index][15:8] <= data_ss[15:8];
                            if(wstrb_ss[2]) mb_regs[mb_index][23:16] <= data_ss[23:16];
                            if(wstrb_ss[3]) mb_regs[mb_index][31:24] <= data_ss[31:24];
                            ss_wr_data_done <= 1'b1;
                        end
                    endcase
                end
                else if(rd_mb)begin
                    // read MB_reg
                    case(next_trans)
                        TRANS_LS: begin
                            data_return <= mb_regs[mb_index];
                            ls_rd_data_bk <= 1'b1;
                        end
                        TRANS_SS: begin
                            // should not happen. remote MB/AA register read is not supported
                        end
                    endcase
                end
                else if(wr_aa)begin
                    // write AA_reg
                    case(next_trans)
                        TRANS_LS: begin
                            // offset 0
                            if(aa_index == 10'b0)begin
                                // bit 0 RW, other bits RO
                                if(fifo_out_wstrb[0]) aa_regs[aa_index][0] <= fifo_out_wdata[0];
                            end
                            // offset 4
                            else if(aa_index == 10'b1)begin
                                // bit 0 RW1C, other bits RO
                                if(fifo_out_wstrb[0]) aa_regs[aa_index][0] <= aa_regs[aa_index][0] & ~fifo_out_wdata[0];
                            end
                            // other offset registers, should not come here due to we only support aa_regs[1:0]
                            else begin
                                if(fifo_out_wstrb[0]) aa_regs[aa_index][7: 0] <= fifo_out_wdata[7:0];
                                if(fifo_out_wstrb[1]) aa_regs[aa_index][15:8] <= fifo_out_wdata[15:8];
                                if(fifo_out_wstrb[2]) aa_regs[aa_index][23:16] <= fifo_out_wdata[23:16];
                                if(fifo_out_wstrb[3]) aa_regs[aa_index][31:24] <= fifo_out_wdata[31:24];
                            end
                            ls_wr_data_done <= 1'b1;
                        end
                        TRANS_SS: begin // ?????????????
                            // should not happen. remote MB/AA register write is not supported
                            ss_wr_data_done <= 1'b1;
                        end
                    endcase
                end
                else if(rd_aa)begin
                    // read AA_reg
                    case(next_trans)
                        TRANS_LS: begin
                            data_return <= aa_regs[aa_index];
                            ls_rd_data_bk <= 1'b1;
                        end
                        TRANS_SS: begin
                            // should not happen. Remote MB/AA register read is not supported
                        end
                    endcase
                end
                else if(rd_unsupp)begin
                    // read MB_reg / AA_reg unsupported range
                    // Return 0xFFFFFFFF when the register is not supported
                    data_return <= 32'hFFFFFFFF;
                    case(next_trans)
                        TRANS_LS:
                            ls_rd_data_bk <= 1'b1;
                        //TRANS_SS:
                            // this path will not fire, because only wr_mb or fpga write caravel side can go through axis
                            //ss_rd_data_bk <= 1'b1;
                    endcase
                end
                else if(rd_ss_complete)begin
                    // read data from user project wrapper come back to fpga
                    case(next_trans)
                        //TRANS_LS: begin
                        //end
                        TRANS_SS: begin
                            data_return <= data_ss;
                            ls_rd_data_bk <= 1'b1;
                        end
                    endcase
                end
            end
            else if(axi_next_state == AXI_SEND_BKEND)begin
                if(sync_trig_sm_rd)begin
                    bk_sm_start <= 1'b1;
                    bk_sm_data <= {17'b0, fifo_out_raddr};
                    bk_sm_user <= 2'b10;
                    send_bk_done <= 1'b1;
                end
                else if(ls_rd_data_bk)begin
                    bk_ls_rdata <= data_return;
                    bk_ls_rdone <= 1'b1;
                    send_bk_done <= 1'b1;
                end
                else if(trig_sm_wr || sync_trig_sm_wr)begin
                    if(ss_data_cnt == 2'b0)begin
                        bk_sm_start <= 1'b1;
                        bk_sm_data <= {fifo_out_wstrb, 13'b0, fifo_out_waddr};
                        bk_sm_user <= 2'b01;
                    end
                    else if(ss_data_cnt == 2'b1)begin
                        bk_sm_start <= 1'b1;
                        bk_sm_data <= fifo_out_wdata;
                        bk_sm_user <= 2'b01;
                        send_bk_done <= 1'b1;
                    end
                end
                else if(trig_lm_wr)begin
                    bk_lm_wstart <= 1'b1;
                    bk_lm_waddr <= {4'b0, addr_ss} + CARAVEL_BASE;
                    bk_lm_wdata <= data_ss;
                    bk_lm_wstrb <= wstrb_ss;
                    send_bk_done <= 1'b1;
                end
                else if(trig_lm_rd || sync_trig_lm_rd)begin
                    if(~lm_rd_bk_sent)begin
                        if(lm_rd_cnt == 2'b0)begin
                            bk_lm_rstart <= 1'b1;
                            bk_lm_raddr <= {4'b0, addr_ss} + CARAVEL_BASE;
                        end
                        else if(lm_rd_cnt == 2'b01)begin
                            bk_lm_rstart <= 1'b0;
                            bk_lm_raddr <= 32'b0;
                            lm_rd_bk_sent <= 1'b1;
                        end
                    end

                    if(bk_lm_rdone)begin // data return from config_ctrl axilite slave
                        // trigger axis master send data to fpga
                        bk_sm_start <= 1'b1;
                        bk_sm_data <= bk_lm_rdata;
                        bk_sm_user <= 2'b11; // return data
                        send_bk_done <= 1'b1;
                    end
                end
            end
            else if(axi_next_state == AXI_TRIG_INT)begin
                // edge trigger interrupt signal, will be de-assert in next posedge
                if(mb_int_en)begin
                    axi_interrupt <= 1'b1;
                    // update interrupt status, offset 4 bit 0
                    aa_regs[1][0] <= 1'b1;
                end
                axi_interrupt_done <= 1'b1;
            end
        end
    end

endmodule