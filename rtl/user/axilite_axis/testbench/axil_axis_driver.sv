///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axil_axis_driver
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/07/08
///////////////////////////////////////////////////////////////////////////////

`define dut top.axil_axis
//event evt_wr_addr, evt_wr_data;

parameter BUS_DELAY = 1ns;

class axil_axis_driver;
    virtual axil_axis_interface.connect intf;
    axil_axis_scenario scnr_drvr;
    mb_axi mb_drvr;
    axil_axis_scenario axil_wr_q[$], axil_rd_q[$], axis_q[$], wr_tr, rd_tr, axis_tr;
    bit down, up;
    //static int no_rdy_trans, no_rdy_cnt;

    function new(virtual axil_axis_interface.connect intf, mb_axi mb_drvr);
        this.intf = intf;
        this.scnr_drvr = scnr_drvr;
        this.mb_drvr = mb_drvr;
    endfunction

    virtual task bus_op();
        bit [31:0] data;
        bit [3:0] tstrb;
        bit [3:0] tkeep;
        bit [1:0] user;
        bit tlast;
        //event evt_wr_addr, evt_wr_data;
        semaphore key = new(1);

        init_bus();

        for(int i=0; i < axil_axis_scenario_gen::PKT_NUM; i++)begin
            scnr_drvr = new();
            mb_drvr.get(scnr_drvr);
            scnr_drvr.display();
            if(scnr_drvr.axi_trans_typ == TRANS_AXIL)begin
                if(scnr_drvr.axi_op == AXI_WR)begin
                    axil_wr_q.push_back(scnr_drvr);
                end
                else begin
                    axil_rd_q.push_back(scnr_drvr);
                end
            end
            else if(scnr_drvr.axi_trans_typ == TRANS_AXIS)begin
                axis_q.push_back(scnr_drvr);
            end
        end

        fork
            // LS write
            while(1)begin
                if(axil_wr_q.size() != 0)begin
                    wr_tr = axil_wr_q.pop_front();
                    fork // write
                        begin // wr addr
                            @(posedge intf.axi_ls_aclk);
                            key.get(1);
                            intf.cc_aa_enable = 1;
                            intf.axi_ls_awaddr = wr_tr.wr_addr;
                            intf.axi_ls_awvalid = 1;
                            
                            while(1)begin
                                @(posedge intf.axi_ls_aclk);
                                if(intf.axi_ls_awready === 1'b1)begin
                                    #(BUS_DELAY);
                                    intf.axi_ls_awaddr = 0;
                                    intf.axi_ls_awvalid = 0;
                                    intf.cc_aa_enable = 0;
                                    key.put(1); // ????????????
                                    break;
                                end
                            end
                        end

                        begin // wr data
                            @(posedge intf.axi_ls_aclk);
                            intf.axi_ls_wdata = wr_tr.wr_data;
                            intf.axi_ls_wstrb = wr_tr.wr_strb;
                            intf.axi_ls_wvalid = 1;
                            
                            while(1)begin
                                @(posedge intf.axi_ls_aclk);
                                if(intf.axi_ls_wready === 1'b1)begin
                                    #(BUS_DELAY);
                                    intf.axi_ls_wdata = 0;
                                    intf.axi_ls_wstrb = 0;
                                    intf.axi_ls_wvalid = 0;
                                    break;
                                end
                            end
                        end
                    join

                    repeat($urandom_range(5)) @(posedge intf.axi_ls_aclk);
                    //break;
                end
                else begin
                    @(posedge intf.axi_ls_aclk);
                end
            end

            // LS read
            while(1)begin
                if(axil_rd_q.size() != 0)begin
                    rd_tr = axil_rd_q.pop_front();
                    fork // read
                        begin // rd addr
                            @(posedge intf.axi_ls_aclk);
                            key.get(1);
                            intf.cc_aa_enable = 1;
                            intf.axi_ls_araddr = rd_tr.rd_addr;
                            intf.axi_ls_arvalid = 1;
                            
                            while(1)begin
                                @(posedge intf.axi_ls_aclk);
                                if(intf.axi_ls_arready === 1'b1)begin
                                    #(BUS_DELAY);
                                    intf.axi_ls_araddr = 0;
                                    intf.axi_ls_arvalid = 0;
                                    intf.cc_aa_enable = 0;
                                    key.put(1); // ????????????
                                    break;
                                end
                            end
                        end

                        begin // rd ready
                            while(1)begin
                                @(posedge intf.axi_ls_aclk);
                                if(intf.axi_ls_rready == 0)begin
                                    #(BUS_DELAY);
                                    if($urandom_range(1))
                                        intf.axi_ls_rready = 1;
                                end
                                @(posedge intf.axi_ls_aclk);
                                if(intf.axi_ls_rready == 1)begin
                                    if(intf.axi_ls_rvalid === 1)begin
                                        #(BUS_DELAY);
                                        if($urandom_range(1))
                                            intf.axi_ls_rready = 0;
                                        break;
                                    end
                                end
                            end
                        end

                        //begin // rd data
                        //    //@(posedge intf.axi_ls_aclk);
                        //    //Willy debug - s
                        //    while(1)begin
                        //        @(posedge intf.axi_ls_aclk);
                        //        if(intf.bk_rstart === 1'b1)begin
                        //            #(BUS_DELAY);
                        //            intf.bk_rdata = rd_tr.rd_data;
                        //            intf.bk_rdone = 1;
                        //
                        //            @(posedge intf.axi_ls_aclk);
                        //            #(BUS_DELAY);
                        //            intf.bk_rdata = 0;
                        //            intf.bk_rdone = 0;
                        //            
                        //            break;
                        //        end
                        //    end
                        //    //Willy debug - e
                        //end
                    join

                    repeat($urandom_range(5)) @(posedge intf.axi_ls_aclk);
                end
                else begin
                    @(posedge intf.axi_ls_aclk);
                end
            end

            // SS
            while(1)begin
                if(axis_q.size() != 0)begin
                    axis_tr = axis_q.pop_front();
                    //fork: drive_packet
                    begin
                        for(int i=0; i<axis_tr.stream_size; i++)begin
                            data = axis_tr.data[i];
                            tstrb = axis_tr.tstrb[i];
                            tkeep = axis_tr.tkeep[i];
                            user = axis_tr.user[i];
                            tlast = axis_tr.tlast[i];

                            @(posedge intf.axi_ss_aclk);
                            #(BUS_DELAY);
                            intf.axis_ss_tvalid = 1;
                            intf.axis_ss_tdata = data;
                            intf.axis_ss_tstrb = tstrb;
                            intf.axis_ss_tkeep = tkeep;
                            intf.axis_ss_tuser = user;
                            intf.axis_ss_tlast = tlast;
                            wait(intf.axis_ss_tready === 1);
                        end

                        @(posedge intf.axi_ss_aclk);
                        #(BUS_DELAY);
                        intf.axis_ss_tvalid = 0;
                        intf.axis_ss_tdata = 0;
                        intf.axis_ss_tstrb = 0;
                        intf.axis_ss_tkeep = 0;
                        intf.axis_ss_tuser = 0;
                        intf.axis_ss_tlast = 0;

                        wait(intf.bk_ss_valid === 0);
                        repeat($urandom_range(5)) @(posedge intf.axi_ss_aclk);
                        //disable drive_packet;
                    end
                        
                        //begin
                        //    while(1)begin
                        //        @(posedge intf.axi_ss_aclk);
                        //        //-> top.evt_001;
                        //
                        //        if(intf.axis_ss_tvalid == 1'b1)begin
                        //            #(BUS_DELAY);
                        //            up = $urandom_range(0, 1);
                        //            if(up)
                        //                intf.bk_ss_ready = 1;
                        //        end
                        //        else begin
                        //            #(BUS_DELAY);
                        //            //-> top.evt_003;
                        //            down = $urandom_range(0, 1);
                        //            if(down)
                        //                intf.bk_ss_ready = 0;
                        //        end
                        //    end
                        //end
                    //join
                end
                else begin
                    @(posedge intf.axi_ls_aclk);
                end
            end

            while(1)begin
                if((axil_wr_q.size() + axil_rd_q.size() + axis_q.size()) == 0)begin
                    repeat(20)@(posedge intf.axi_ls_aclk);
                    break;
                end
                else begin
                    @(posedge intf.axi_ls_aclk);
                end
            end
        join_any
        disable fork;
    endtask

    virtual task init_bus();
        // LM
        intf.axi_lm_rdata = 0;
        intf.axi_lm_awready = 0;
        intf.axi_lm_wready = 0;
        intf.axi_lm_arready = 0;
        intf.axi_lm_rvalid = 0;

        // LS
        intf.axi_ls_awvalid = 0;
        intf.axi_ls_awaddr = 0;
        intf.axi_ls_wvalid = 0;
        intf.axi_ls_wdata = 0;
        intf.axi_ls_wstrb = 0;
        intf.axi_ls_arvalid = 0;
        intf.axi_ls_araddr = 0;
        intf.axi_ls_rready = 0;
        intf.cc_aa_enable = 0;
        //force `dut.axi_ctrl_logic.bk_ss_ready = 1; //??????????

        // SM
        intf.axis_sm_tready = 0;

        // SS
        intf.axis_ss_tvalid = 0;
        intf.axis_ss_tdata = 0;
        intf.axis_ss_tstrb = 0;
        intf.axis_ss_tkeep = 0;
        intf.axis_ss_tlast = 0;
        intf.axis_ss_tuser = 0;

        wait(intf.axi_ls_aresetn == 1);
    endtask
endclass
