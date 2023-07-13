///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axilite_slave
//       AUTHOR: Willy
// ORGANIZATION: fsic
//      CREATED: 2023/06/20
///////////////////////////////////////////////////////////////////////////////

module axilite_slave(
    // frontend - axilite slave
    input axi_aclk,
    input axi_aresetn,

    output logic axi_awready,
    output logic axi_wready,
    output logic axi_arready,
    output logic axi_rvalid,
    output logic [31:0] axi_rdata,
    input axi_awvalid,
    input [14:0] axi_awaddr,
    input axi_wvalid,
    input [31:0] axi_wdata,
    input [3:0] axi_wstrb,
    input axi_arvalid,
    input [14:0] axi_araddr,
    input axi_rready,

    // backend source to receive the axilite slave transaction
    output logic bk_wstart,
    output logic [14:0] bk_waddr,
    output logic [31:0] bk_wdata,
    output logic [3:0]  bk_wstrb,
    //input bk_wdone,
    output logic bk_rstart,
    output logic [14:0] bk_raddr,
    input [31:0] bk_rdata,
    input bk_rdone,

    input cc_aa_enable //ConfigControl assert it when the request is forwarding to AA.
);

    // backend interface
    // aclk      _/-\_/-\_/-\_/-\_/-\_/-\
    // bk_wstart _____/-\________________
    // bk_waddr  _____/x\________________
    // bk_wdata  _____XX_________________
    // bk_wstrb  _____XX_________________
    // bk_rstart _________/-\____________
    // bk_raddr  _________/x\____________
    // bk_rdata  _________________XX_____
    // bk_rdone  _________________/-\____

    logic [14:0] cache_waddr, cache_raddr;
    logic [31:0] cache_wdata, cache_rdata;
    logic [3:0]  cache_strb;
    logic cache_wstart, cache_rstart;
    //logic cache_wdone, cache_rdone;
    logic cache_rdone;

    // FSM state
    // Note: WRESP is not supported, always posted write without response
    enum logic [2:0] {WR_WAIT_ADDR, WR_WRITE_ADDR, WR_WRITE_DATA} axi_wr_state, axi_wr_next_state;
    enum logic [2:0] {RD_WAIT_ADDR, RD_READ_ADDR, RD_READ_DATA}   axi_rd_state, axi_rd_next_state;

    // FSM state, sequential logic
    always_ff @(posedge axi_aclk or negedge axi_aresetn) begin
        if (~axi_aresetn) begin
            axi_wr_state <= WR_WAIT_ADDR;
            axi_rd_state <= RD_WAIT_ADDR;
        end else begin
            axi_wr_state <= axi_wr_next_state;
            axi_rd_state <= axi_rd_next_state;
        end
    end

    // FSM state,  sequential logic, input capture fro write cycle
    always_ff @(posedge axi_aclk or negedge axi_aresetn) begin
        if (~axi_aresetn) begin
            cache_waddr <= 15'b0;
            cache_wdata <= 32'b0;
            cache_strb <= 4'b0;
            cache_wstart <= 1'b0;
        end else begin
            case (axi_wr_state)
                WR_WAIT_ADDR: cache_wstart <= 1'b0;
                // Cache the awaddr and will put to backend later.
                WR_WRITE_ADDR: cache_waddr <= axi_awaddr;
                WR_WRITE_DATA: begin
                    // Make sure we get valid wreite data
                    // axi_wr_next_state:  WR_WRITE_DATA to WR_WAIT_ADDR 
                    // It means master provides the wdata and slave assert axi_wready now.
                    if(axi_wr_next_state == WR_WAIT_ADDR) begin
                        // Cache wdata, strb, will put to backend later.
                        cache_wdata <= axi_wdata;
                        cache_strb <= axi_wstrb;
                        // To invoke backend interface
                        cache_wstart <= 1'b1;
                    end
                end
            endcase
        end
    end

   // FSM state, combinational logic for write cycle
    always_comb begin
        axi_wr_next_state = axi_wr_state;

        case(axi_wr_state)
            WR_WAIT_ADDR:
                if(axi_awvalid && cc_aa_enable)begin //Add cc_aa_enable
                //if(axi_awvalid)begin
                    axi_wr_next_state = WR_WRITE_ADDR;
                end
            WR_WRITE_ADDR:
                if(axi_awvalid && axi_awready)begin
                    axi_wr_next_state = WR_WRITE_DATA;
                end
            WR_WRITE_DATA:
                if(axi_wvalid && axi_wready)begin
                    axi_wr_next_state = WR_WAIT_ADDR;
                end
            default:
                axi_wr_next_state = WR_WAIT_ADDR;
        endcase
    end

    // FSM state, combinational logic, output control for write cycle
    always_comb begin
        axi_awready = 1'b0;
        axi_wready = 1'b0;
        case(axi_wr_state)
            //WR_WAIT_ADDR: // do nothing
            WR_WRITE_ADDR:begin
                axi_awready = 1'b1;
            end
            WR_WRITE_DATA:begin
                axi_wready = 1'b1;
            end
        endcase
    end

    // FSM state, sequential logic, input capture for read cycle
    always_ff @(posedge axi_aclk  or negedge axi_aresetn) begin
        if (~axi_aresetn) begin
            cache_raddr <= 15'b0;
            cache_rstart <= 1'b0;
        end else begin
            case (axi_rd_state)
                RD_READ_ADDR: begin
                    cache_raddr <= axi_araddr;
                    // To invoke backend interface
                    cache_rstart <= 1'b1;
                end
                RD_READ_DATA: begin
                    cache_rstart <= 1'b0;
                end
            endcase
        end
    end

    // FSM state, combinational logic for read cycle
    always_comb begin
        axi_rd_next_state = axi_rd_state;

        case(axi_rd_state)
            RD_WAIT_ADDR:
                if(axi_arvalid && cc_aa_enable)begin //Add cc_aa_enable
                //if(axi_arvalid)begin
                    axi_rd_next_state = RD_READ_ADDR;
                end
            RD_READ_ADDR:
                if(axi_arvalid && axi_arready)begin
                    axi_rd_next_state = RD_READ_DATA;
                end
            RD_READ_DATA:
                if(axi_rvalid && axi_rready)begin
                    axi_rd_next_state = RD_WAIT_ADDR;
                end
            default:
                axi_rd_next_state = RD_WAIT_ADDR;
        endcase
    end

    // FSM state, combinational logic, output control for read cycle
    always_comb begin
        axi_arready = 1'b0;
        axi_rvalid = 1'b0;
        axi_rdata = 32'b0;

        case(axi_rd_state)
            //RD_WAIT_ADDR: // do nothing
            RD_READ_ADDR:begin
                axi_arready = 1'b1;
            end
            RD_READ_DATA:begin
                // Waiting for backend interface return the data, then put to output with axi_rvalid assert
                if(cache_rdone == 1'b1) begin
                    axi_rvalid = 1'b1;
                    axi_rdata = cache_rdata;
                end
            end
            //default:
        endcase
    end

    // backend interface, sequential logic
    always_ff@(posedge axi_aclk or negedge axi_aresetn)begin
        if(~axi_aresetn)begin
            //cache_wdone <= 1'b0;
            cache_rdone <= 1'b0;
            cache_rdata <= 32'b0;
        end
        else begin
            if(bk_rdone == 1'b1) begin
                cache_rdone <= bk_rdone;
                cache_rdata <= bk_rdata;
            end

            // Slave return data, and master claim it: axi_rvalid = 1, axi_rready = 1
            if((axi_rd_state == RD_READ_DATA) && (axi_rd_next_state == RD_WAIT_ADDR)) begin
                cache_rdone <= 0;
            end
        end
    end

    // backend interface, combinational logic
    always_comb begin
        bk_waddr = 15'b0;
        bk_wdata = 32'b0;
        bk_wstrb = 4'b0;
        bk_wstart = 1'b0;

        bk_rstart = 1'b0;
        bk_raddr = 15'b0;

        if(cache_wstart == 1'b1) begin
            bk_waddr = cache_waddr;
            bk_wdata = cache_wdata;
            bk_wstrb = cache_strb;
            bk_wstart = 1;
        end

        if(cache_rstart == 1'b1) begin
            bk_raddr = cache_raddr;
            bk_rstart = 1;
        end
    end

endmodule
