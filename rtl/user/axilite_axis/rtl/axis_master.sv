///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axis_master
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/06/16
///////////////////////////////////////////////////////////////////////////////

module axi_fifo#(WIDTH=8'h8, DEPTH=8'h8)(
    input wire clk,
    input wire rst_n,
    input wire wr_vld,
    input wire rd_rdy,
    input wire hack, // ???????????????
    input wire clear,
    input wire [WIDTH - 1:0] data_in,
    output logic [WIDTH - 1:0] data_out,
    output logic wr_rdy,
    output logic rd_vld,
    output logic last
);

    logic [WIDTH - 1:0] fifo [DEPTH - 1:0];
    logic [7:0] wr_pointer, rd_pointer;
    logic [7:0] wr_count, rd_count, wr_count_pre;
    logic empty, full, sync_rd_vld;

    // pointer and water level, use valid and ready to handshake
    always_ff@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            wr_pointer <= 8'h0;
            rd_pointer <= 8'h0;
            wr_count <= 8'h0;
            rd_count <= 8'h0;
            wr_count_pre <= 8'h0;
        end
        else begin
            if(clear)begin
                wr_pointer <= 8'h0;
                rd_pointer <= 8'h0;
                wr_count <= 8'h0;
                rd_count <= 8'h0;
                wr_count_pre <= 8'h0;
            end
            if(rd_rdy && rd_vld && wr_rdy && wr_vld)begin // do read and write
                rd_pointer <= (rd_pointer == (DEPTH - 8'b1)) ? 8'h0 : rd_pointer + 8'b1;
                wr_pointer <= (wr_pointer == (DEPTH - 8'b1)) ? 8'h0 : wr_pointer + 8'b1;
                fifo[wr_pointer] <= data_in;
                wr_count <= wr_count + 8'b1;
                rd_count <= rd_count + 8'b1;
            end
            else if(rd_rdy && rd_vld)begin // do read
                rd_pointer <= (rd_pointer == (DEPTH - 8'b1)) ? 8'h0 : rd_pointer + 8'b1;
                rd_count <= rd_count + 8'b1;
            end
            else if(wr_rdy && wr_vld)begin // do write
                wr_pointer <= (wr_pointer == (DEPTH - 8'b1)) ? 8'h0 : wr_pointer + 8'b1;
                wr_count <= wr_count + 8'b1;
                fifo[wr_pointer] <= data_in;
            end

            wr_count_pre <= wr_count; // to fix bug in last transaction no ready
        end
    end

    // output current read data if fifo is not empty, data go first before pointer moving, to solve read fifo cost too many clock
    always_comb begin // use combinational so rd_pointer change reflect instantly
        //data_out = '0; // initialize packed array (as a vector) with all zero

        if(empty == 1'b0)begin
            data_out = fifo[rd_pointer];
        end
        else
            data_out = '0; // initialize packed array (as a vector) with all zero
    end

    // to fix bug in short transaction only have one clock data
    always_ff@(posedge clk or negedge rst_n)
        if(~rst_n)  sync_rd_vld <= 1'b0;
        else        sync_rd_vld <= rd_vld;

    // decide when this fifo can be read or wrote
    always_comb begin
        //wr_rdy = 1'b0;
        //rd_vld = 1'b0;

        if(hack)begin // for axis_master
            if((wr_count_pre == wr_count) && (wr_count - rd_count) == 8'h2)begin // last data (n-1), raise last, axis_master can decide the bus behavior it should do
                rd_vld = 1'b1;
                last = 1'b1;
            end
            else if((wr_count_pre == wr_count) && (wr_count - rd_count) <= 8'h1)begin // last data (n)
                rd_vld = 1'b0;
                last = 1'b1;
            end
            else if((wr_count - rd_count) > 8'h1) // normal data, not last
                rd_vld = 1'b1;
            else if(wr_count == 8'h1 && rd_count == 8'h0 && ~sync_rd_vld)begin // for short transaction only have one clock data
                rd_vld = 1'b1;
                last = 1'b0;
            end
            else begin
                rd_vld = 1'b0;
                last = 1'b0;
            end
        end
        else begin // for control_logic
            if((wr_count - rd_count) > 8'h1)
                rd_vld = 1'b1;
            else if((wr_count - rd_count) == 8'h1)
                rd_vld = 1'b1;
            else begin
                rd_vld = 1'b0;
                last = 1'b0;
            end
        end

        if(full == 1'b0) // can be wrote
            wr_rdy = 1'b1;
        else
            wr_rdy = 1'b0;
    end

    always_comb begin
        empty = ((wr_count - rd_count) == 8'h0);
        full = ((wr_count - rd_count) == DEPTH - 8'h1); // reserve one if ready too late
    end

endmodule


module axis_master(
    // backend source to trigger the axis master transaction
    input wire bk_start,
    input wire [31:0] bk_data,
    input wire [3:0] bk_tstrb,
    input wire [3:0] bk_tkeep,
    //input wire [1:0] bk_tid,
    input wire [1:0] bk_user,
    output logic bk_nordy,
    output logic bk_done,

    // frontend - axis master
    input wire axi_aclk,
    input wire axi_aresetn,
    output logic axis_tvalid,
    output logic [31:0] axis_tdata,
    output logic [3:0] axis_tstrb,
    output logic [3:0] axis_tkeep,
    output logic axis_tlast,
    //output logic [1:0] axis_tid,
    output logic [1:0] axis_tuser,
    input wire axis_tready
);

    // backend interface
    // aclk       _/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\_/-\
    // bk_start   _____/--------------\___________________
    // bk_data    _____XXXXXXXXXXXXXXXX___________________
    // bk_tstrb   _____XXXXXXXXXXXXXXXX___________________
    // bk_tkeep   _____XXXXXXXXXXXXXXXX___________________
    // bk_user    _____XXXXXXXXXXXXXXXX___________________
    // bk_nordy   _________________/------\_______________
    // bk_done    _________________________________/-\____

    // axis_tlast _________________________________/-\____

    logic enough_data, next_data;
    logic [7:0] no_rdy_count;
    logic [31:0] fifo_out_tdata;
    logic [3:0] fifo_out_tstrb, fifo_out_tkeep;
    //logic [1:0] fifo_out_tid, fifo_out_user;
    logic [1:0] fifo_out_user;

    parameter AXI_FIFO_DEPTH = 8'd8, AXI_FIFO_WIDTH = 8'd42, AXIS_RDY_TIMEOUT = 8'd5;
    logic fifo_wr_vld, fifo_wr_rdy, fifo_rd_vld, fifo_rd_rdy, fifo_clear, fifo_last;
    logic [41:0] fifo_data_in, fifo_data_out;

    // FSM state
    enum logic [2:0] {AXIS_WAIT_DATA, AXIS_SEND_DATA, AXIS_SEND_LAST} axis_state, axis_next_state;

    // FSM state, sequential logic, axis
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            axis_state <= AXIS_WAIT_DATA;
        end
        else begin
            axis_state <= axis_next_state;
        end
    end

    //assign enough_data = fifo_rd_vld;
    // sync fifo_rd_vld, sequential logic
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            enough_data <= 1'b0;
        end
        else begin
            enough_data <= fifo_rd_vld;
        end
    end

    // FSM state, combinational logic, axis
    always_comb begin
        axis_next_state = axis_state;

        case(axis_state)
            AXIS_WAIT_DATA:
                if(enough_data)begin
                    axis_next_state = AXIS_SEND_DATA;
                end
            AXIS_SEND_DATA:
                if(fifo_last && enough_data == 1'b0)begin // one cycle data
                    axis_next_state = AXIS_SEND_LAST;
                end
                else if(fifo_last && axis_tready)begin // last data
                    axis_next_state = AXIS_SEND_LAST;
                end
            AXIS_SEND_LAST:
                if(axis_tready)begin
                    axis_next_state = AXIS_WAIT_DATA;
                end
            default:
                axis_next_state = AXIS_WAIT_DATA;
        endcase
    end

    // FSM state, combinational logic, axis, output control
    always_comb begin
        //axis_tvalid = 1'b0;
        //axis_tdata = 32'h0;
        //axis_tstrb = 4'h0;
        //axis_tkeep = 4'h0;
        //axis_tuser = 2'h0;
        //next_data = 1'b0;

        if(axis_state == AXIS_SEND_DATA && axis_next_state == AXIS_SEND_LAST && enough_data == 1'b1)begin // workaround for two cycle data
            axis_tvalid = 1'b1;
            axis_tdata = fifo_out_tdata;
            axis_tstrb = fifo_out_tstrb;
            axis_tkeep = fifo_out_tkeep;
            axis_tuser = fifo_out_user;
            if(axis_tready)begin
                next_data = 1'b1;
            end
            else begin
                next_data = 1'b0;
            end
        end
        else if(axis_state == AXIS_SEND_DATA && axis_next_state == AXIS_SEND_LAST && enough_data == 1'b0)begin // workaround for one cycle data, do not drive bus
            if(axis_tready)begin
                next_data = 1'b1;
            end
            else begin
                next_data = 1'b0;
            end
        end
        else if(axis_state == AXIS_SEND_DATA)begin // normal data
            axis_tvalid = 1'b1;
            axis_tdata = fifo_out_tdata;
            axis_tstrb = fifo_out_tstrb;
            axis_tkeep = fifo_out_tkeep;
            axis_tuser = fifo_out_user;
            if(axis_tready)begin
                next_data = 1'b1;
            end
            else begin
                next_data = 1'b0;
            end
        end
        else if(axis_state == AXIS_SEND_LAST)begin // final data
            axis_tvalid = 1'b1;
            axis_tdata = fifo_out_tdata;
            axis_tstrb = fifo_out_tstrb;
            axis_tkeep = fifo_out_tkeep;
            axis_tuser = fifo_out_user;
            next_data = 1'b0;
        end
        else begin
            axis_tvalid = 1'b0;
            axis_tdata = 32'h0;
            axis_tstrb = 4'h0;
            axis_tkeep = 4'h0;
            axis_tuser = 2'h0;
            next_data = 1'b0;
        end
    end

    // count if axis_tready not come
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)
            no_rdy_count <= 8'h0;
        else if(axis_state == AXIS_SEND_DATA)
            if(axis_tready)
                no_rdy_count <= 8'h0;
            else
                no_rdy_count <= no_rdy_count + 1'b1;
        else
            no_rdy_count <= 8'h0;
    end

    assign bk_nordy = (no_rdy_count >= AXIS_RDY_TIMEOUT) ? 1'b1 : 1'b0;

    axi_fifo #(.WIDTH(AXI_FIFO_WIDTH), .DEPTH(AXI_FIFO_DEPTH)) fifo(
        .clk(axi_aclk),
        .rst_n(axi_aresetn),
        .wr_vld(fifo_wr_vld),
        .rd_rdy(fifo_rd_rdy),
        .hack(1'b1),
        .data_in(fifo_data_in),
        .data_out(fifo_data_out),
        .wr_rdy(fifo_wr_rdy),
        .rd_vld(fifo_rd_vld),
        .last(fifo_last),
        .clear(fifo_clear));

    // send backend data to fifo
    always_comb begin
        //fifo_data_in = '0;
        //fifo_wr_vld = 1'b0;

        if(bk_start)begin
            fifo_data_in = {bk_data, bk_tstrb, bk_tkeep, bk_user};
            fifo_wr_vld = 1'b1;
        end
        else begin
            fifo_data_in = '0;
            fifo_wr_vld = 1'b0;
        end
    end

    // get data from fifo
    always_comb begin
        //{fifo_out_tdata, fifo_out_tstrb, fifo_out_tkeep, fifo_out_user} = '0;
        //fifo_rd_rdy = 1'b0;
        //fifo_clear = 1'b0;

        if(axis_state == AXIS_SEND_DATA || axis_state == AXIS_SEND_LAST)begin
            {fifo_out_tdata, fifo_out_tstrb, fifo_out_tkeep, fifo_out_user} = fifo_data_out;
        end
        else
            {fifo_out_tdata, fifo_out_tstrb, fifo_out_tkeep, fifo_out_user} = '0;

        if(next_data)begin // receive slave tready, can send next data
            fifo_rd_rdy = 1'b1;
        end
        else
            fifo_rd_rdy = 1'b0;

        if(bk_done)begin // clear fifo when transaction done to fix bug
            fifo_clear = 1'b1;
        end
        else
            fifo_clear = 1'b0;
    end

    //assign bk_done = (axis_state == AXIS_SEND_DATA) & (axis_next_state == AXIS_WAIT_DATA);
    //assign bk_done_glitch = (axis_state == AXIS_SEND_LAST) & (axis_next_state == AXIS_WAIT_DATA);

    // sync bk_done, sequential logic
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)
            bk_done <= 1'b0;
        else
            bk_done <= (axis_state == AXIS_SEND_LAST) & (axis_next_state == AXIS_WAIT_DATA);
    end

    assign axis_tlast = (axis_state == AXIS_SEND_LAST);
    //assign axis_tlast = bk_done; // send tlast if transaction done ???

endmodule


