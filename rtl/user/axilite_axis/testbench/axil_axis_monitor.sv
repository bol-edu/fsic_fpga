///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axil_axis_monitor
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/07/08
///////////////////////////////////////////////////////////////////////////////

class axil_axis_monitor;
    virtual axil_axis_interface.connect intf;
    axil_axis_scenario scnr_mon[3];
    mb_axi mb_mon;

    int packet_cnt = 0;

    function new(virtual axil_axis_interface.connect intf, mb_axi mb_mon);
        this.intf = intf;
        this.mb_mon = mb_mon;
    endfunction

    virtual task bus_mon();
        logic [31:0] wr_addr, rd_addr;
        logic [31:0] wr_data, rd_data;
        logic [3:0] wr_strb;
        int stream_size_tmp, stream_size_final, stream_size_q[$], stream_size_item; 
        logic [31:0] data[$];
        logic [3:0] tstrb[$];
        logic [3:0] tkeep[$];
        logic [1:0] tid[$];
        logic [1:0] user[$];
        int largest_fifo_level, fifo_write_cnt, fifo_read_cnt, tmp_fifo_level;


        wait_rst_done();

        fork
            // LM write
            while(1)begin // wr
                while(1)begin
                    @(posedge intf.axi_lm_aclk);

                    // write addr
                    if(intf.axi_lm_awvalid === 1'b1 && intf.axi_lm_awready === 1'b1)begin
                        wr_addr = intf.axi_lm_awready;
                        break;
                    end
                end
                while(1)begin
                    @(posedge intf.axi_lm_aclk);
                    -> top.evt_002;

                    // write data
                    if(intf.axi_lm_wvalid === 1'b1 && intf.axi_lm_wready === 1'b1)begin
                        wr_data = intf.axi_lm_wdata;
                        wr_strb = intf.axi_lm_wstrb;
                        break;
                    end
                end
                scnr_mon[0] = new();
                scnr_mon[0].axi_trans_typ = TRANS_AXIS;
                scnr_mon[0].wr_addr = wr_addr;
                scnr_mon[0].wr_data = wr_data;
                scnr_mon[0].wr_strb = wr_strb;
                scnr_mon[0].axi_op = AXI_WR;
                scnr_mon[0].display("scnr_mon[0]");
                mb_mon.put(scnr_mon[0]);
                packet_cnt +=1;
            end

            // LM read
            while(1)begin // rd
                while(1)begin
                    @(posedge intf.axi_lm_aclk);

                    // read addr
                    if(intf.axi_lm_arvalid === 1'b1 && intf.axi_lm_arready === 1'b1)begin
                        rd_addr = intf.axi_lm_araddr;
                        break;
                    end
                end
                while(1)begin
                    @(posedge intf.axi_lm_aclk);

                    // read data
                    if(intf.axi_lm_rvalid === 1'b1 && intf.axi_lm_rready === 1'b1)begin
                        #(BUS_DELAY);
                        rd_data = intf.bk_lm_rdata;
                        break;
                    end
                end
                scnr_mon[1] = new();
                scnr_mon[1].axi_trans_typ = TRANS_AXIS;
                scnr_mon[1].rd_addr = rd_addr;
                scnr_mon[1].rd_data = rd_data;
                scnr_mon[1].axi_op = AXI_RD;
                scnr_mon[1].display("scnr_mon[1]");
                mb_mon.put(scnr_mon[1]);
                packet_cnt +=1;
            end

            // SM get stream size
            begin
                while(1)begin // get stream size from backend interface, push to queue
                    stream_size_tmp = 0;
                    wait(intf.bk_sm_start === 1);
                    while(1)begin
                        @(posedge intf.axi_sm_aclk);
                        //-> top.evt_001;
                        if(intf.bk_sm_start === 1)
                            stream_size_tmp ++;
                        else begin
                            stream_size_final = stream_size_tmp;
                            stream_size_q.push_back(stream_size_final);
                            //-> top.evt_002;
                            $display("%0t, stream_size_final = %0d", $time(), stream_size_final);
                            break;
                        end
                    end
                end
            end

            // SM get data from frontend interface
            while(1)begin
                fork: get_data
                    while(1)begin // track every valid / ready handshake, push data to queue
                        @(posedge intf.axi_sm_aclk);
                        
                        if(intf.axis_sm_tvalid === 1'b1 && intf.axis_sm_tready === 1'b1)begin
                            //-> top.evt_get_data;
                            data.push_back(intf.axis_sm_tdata);
                            tstrb.push_back(intf.axis_sm_tstrb);
                            tkeep.push_back(intf.axis_sm_tkeep);
                            user.push_back(intf.axis_sm_tuser);
                        end
                    end
                    begin
                        while(1)begin // get stream size from queue
                            @(posedge intf.axi_sm_aclk);
                            if(stream_size_q.size() != 0)begin
                                stream_size_item = stream_size_q.pop_front();
                                break;
                            end
                        end
                            
                        while(1)begin // use stream size to get correct data
                            @(posedge intf.axi_sm_aclk);
                            
                            if(data.size() == stream_size_item)begin
                                //-> top.evt_get_data2;
                                scnr_mon[2] = new();
                                scnr_mon[2].axi_trans_typ = TRANS_AXIL;
                                scnr_mon[2].data = data;
                                scnr_mon[2].tstrb = tstrb;
                                scnr_mon[2].tkeep = tkeep;
                                scnr_mon[2].user = user;
                                scnr_mon[2].stream_size = stream_size_item;
                                scnr_mon[2].display("scnr_mon[2]");
                                mb_mon.put(scnr_mon[2]);
                                packet_cnt +=1;
                                
                                data = {}; // clear queue
                                tstrb = {};
                                tkeep = {};
                                tid = {};
                                user = {};
                                break;
                            end
                        end
                        disable get_data;
                    end
                join
            end

            // track fifo
            begin
                largest_fifo_level = 0;
                while(1)begin // record largest fifo depth used
                    @(posedge intf.axi_sm_aclk);
                    fifo_write_cnt = `dut.sm.fifo.wr_count[7:0];
                    fifo_read_cnt = `dut.sm.fifo.rd_count[7:0];
                    tmp_fifo_level = fifo_write_cnt - fifo_read_cnt;
                    if(tmp_fifo_level > largest_fifo_level)begin
                        largest_fifo_level = tmp_fifo_level;
                        $display("%0t\tlargest_fifo_level is %0d", $time(), largest_fifo_level);
                    end
                end
            end

            while(1)begin
                @(posedge intf.axi_lm_aclk);
                if(packet_cnt >= axil_axis_scenario_gen::PKT_NUM) break;
            end
        join_any
        disable fork;
    endtask
    
    virtual task wait_rst_done();
        wait(intf.axi_ls_aresetn == 1);
    endtask

endclass
