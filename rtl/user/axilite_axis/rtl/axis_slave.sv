///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axis_slave
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/06/29
///////////////////////////////////////////////////////////////////////////////

module axis_slave(
    // backend source to receive the axis slave transaction
    output logic [31:0] bk_data,
    output logic [3:0] bk_tstrb,
    output logic [3:0] bk_tkeep,
    //output logic [1:0] bk_tid,
    output logic [1:0] bk_user,
    output logic bk_tlast,
    input logic bk_ready,
    output logic bk_valid,

    // frontend - axis slave
    input logic axi_aclk,
    input logic axi_aresetn,
    input logic axis_tvalid,
    input logic [31:0] axis_tdata,
    input logic [3:0] axis_tstrb,
    input logic [3:0] axis_tkeep,
    input logic axis_tlast,
    //input logic [1:0] axis_tid,
    input logic [1:0] axis_tuser,
    output logic axis_tready
);

    // backend interface
    // aclk       _/-\_/-\_/-\_/-\_/-\_/-\_/-\
    // bk_data    _____XXXXXXXXXXXXXXXX_______
    // bk_tstrb   _____XXXXXXXXXXXXXXXX_______
    // bk_tkeep   _____XXXXXXXXXXXXXXXX_______
    // bk_user    _____XXXXXXXXXXXXXXXX_______
    // bk_tlast   __________________/-\_______
    // bk_ready   _/-----------------------\__
    // bk_valid   _____/--------------\_______

    // axis_tlast ________________/-\_________

    // FSM state
    enum logic [2:0] {AXIS_WAIT_BACKEND, AXIS_RECV_DATA, AXIS_OUTPUT_DATA} axis_state, axis_next_state;

    // FSM state, sequential logic, axis
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            axis_state <= AXIS_WAIT_BACKEND;
        end
        else begin
            axis_state <= axis_next_state;
        end
    end

    // FSM state, combinational logic, axis
    always_comb begin
        axis_next_state = axis_state;

        case(axis_state)
            AXIS_WAIT_BACKEND:
                if(bk_ready)begin
                    axis_next_state = AXIS_RECV_DATA;
                end
            AXIS_RECV_DATA:
                if(axis_tvalid)begin
                    axis_next_state = AXIS_OUTPUT_DATA;
                end
                else begin
                    axis_next_state = AXIS_RECV_DATA;
                end
            AXIS_OUTPUT_DATA:
                if(axis_tvalid && bk_ready)begin
                    axis_next_state = AXIS_OUTPUT_DATA;
                end
                else begin
                    axis_next_state = AXIS_WAIT_BACKEND;
                end
            default:
                axis_next_state = AXIS_WAIT_BACKEND;
        endcase
    end

    // FSM state, combinational logic, axis, output control
    always_comb begin
        axis_tready = 1'b0;

        case(axis_state)
            //AXIS_WAIT_BACKEND: // do nothing
            AXIS_RECV_DATA:begin
                axis_tready = 1'b1;
            end
            AXIS_OUTPUT_DATA:begin
                axis_tready = 1'b1;
            end
        endcase
    end

    // combinational logic, backend interface
    always_comb begin
        bk_data = 32'h0;
        bk_tstrb = 4'h0;
        bk_tkeep = 4'h0;
        //bk_tid = 2'h0;
        bk_user = 2'h0;
        bk_tlast = 1'b0;
        bk_valid = 1'b0;

        if((axis_next_state == AXIS_OUTPUT_DATA))begin // normal case
            bk_data = axis_tdata;
            bk_tstrb = axis_tstrb;
            bk_tkeep = axis_tkeep;
            //bk_tid = axis_tid;
            bk_user = axis_tuser;
            bk_tlast = axis_tlast;
            bk_valid = 1'b1;
        end
        else if(axis_state == AXIS_OUTPUT_DATA && axis_next_state == AXIS_WAIT_BACKEND && bk_ready == 1'b0)begin // bk_ready falling, but the data is valid. EXCEPTION: short transaction only one clock cycle data
            bk_data = axis_tdata;
            bk_tstrb = axis_tstrb;
            bk_tkeep = axis_tkeep;
            //bk_tid = axis_tid;
            bk_user = axis_tuser;
            bk_tlast = axis_tlast;
            bk_valid = axis_tvalid; // solve short transaction
        end
    end

endmodule

