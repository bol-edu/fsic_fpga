///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: axil_axis_scenario
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/07/08
///////////////////////////////////////////////////////////////////////////////

parameter MAX_NO_RDY = 4;
typedef enum bit [3:0] {TRANS_AXIL, TRANS_AXIS} axi_transaction_type;
typedef enum bit [3:0] {PATH_LS_AAREG, PATH_LS_MBREG, PATH_LS_SM, PATH_SS_MBREG, PATH_SS_AAREG, PATH_SS_LM} axi_path_type;
typedef enum bit [3:0] {AXI_WR, AXI_RD} axi_operation;
typedef enum bit [3:0] {SUPP_ADDR_YES, SUPP_ADDR_NO} supported_addr;

class axil_axis_scenario;
    int trans_id;
    static int trans_id_st;
    rand axi_transaction_type axi_trans_typ;
    rand axi_path_type axi_path_typ[$];
    rand axi_operation axi_op;
    rand supported_addr supp_addr[$];

    // axilite slave (LS)
    rand logic [31:0] wr_addr;
    rand logic [31:0] wr_data;
    rand logic [3:0] wr_strb;

    rand logic [31:0] rd_addr;
    rand logic [31:0] rd_data;

    // axis slave (SS)
    rand int stream_size;
    rand logic [31:0] data[$];
    rand logic [3:0] tstrb[$];
    rand logic [3:0] tkeep[$];
    rand logic [1:0] user[$];
    rand logic [7:0] no_rdy_cnt;
    rand logic tlast[$];

    constraint axi_trans{
        (axi_trans_typ == TRANS_AXIL) ->
            foreach(axi_path_typ[i]) {
                axi_path_typ[i] inside {PATH_LS_AAREG, PATH_LS_MBREG, PATH_LS_SM}
            };

        (axi_trans_typ == TRANS_AXIS) ->
            foreach(axi_path_typ[i]) {
                axi_path_typ[i] inside {PATH_SS_MBREG, PATH_SS_AAREG, PATH_SS_LM}
            };
        solve axi_trans_typ before axi_path_typ;
    }

    constraint length_of_stream{
        (axi_trans_typ == TRANS_AXIL) -> stream_size == 1;
        (axi_trans_typ == TRANS_AXIS) -> stream_size > 0;
        stream_size <= 30;
        //stream_size <= 5;
        stream_size dist {  [1:5]   := 25, 
                            [6:24]  := 60, 
                            [25:30] := 15};
        axi_path_typ.size == stream_size;
        supp_addr.size == stream_size;

        data.size == stream_size;
        tstrb.size == stream_size;
        tkeep.size == stream_size;
        user.size == stream_size;
        tlast.size == stream_size;
        solve axi_trans_typ before stream_size;
    }

    constraint axi_addr{
        (axi_trans_typ == TRANS_AXIL) -> {  wr_addr[31:15] == 0,
                                            rd_addr[31:15] == 0
        };

        (axi_trans_typ == TRANS_AXIS) -> {  wr_addr[31:16] == 16'h3000,
                                            rd_addr[31:16] == 16'h3000
        };
        solve axi_trans_typ before wr_addr;
        solve axi_trans_typ before rd_addr;
    }

    constraint no_rdy{
        no_rdy_cnt >= 0;
        (stream_size >= 5) -> (no_rdy_cnt <= stream_size - 2);
        no_rdy_cnt <= MAX_NO_RDY;
        solve stream_size before no_rdy_cnt;
    }

    extern constraint rdy;

    function new();
        //this.randomize();
    endfunction

    virtual function void display(string prefix="");
        $display($sformatf("\ntrans_id %6d ========%s", trans_id, prefix));

        $display($sformatf("axi_trans_typ = %s", axi_trans_typ));
        $display($sformatf("axi_path_typ = %p", axi_path_typ));
        $display($sformatf("supp_addr = %p", supp_addr));
        if(axi_trans_typ == TRANS_AXIL)begin
            if(this.axi_op == AXI_WR)begin
                $display($sformatf("wr_addr = %h", wr_addr));
                $display($sformatf("wr_data = %h", wr_data));
                $display($sformatf("wr_strb = %b", wr_strb));
            end
            else if(this.axi_op == AXI_RD)begin
                $display($sformatf("rd_addr = %h", rd_addr));
                $display($sformatf("rd_data = %h", rd_data));
            end
        end
        else if(axi_trans_typ == TRANS_AXIS)begin
            $display($sformatf("stream_size = %d", stream_size));
            $display($sformatf("data[0]  = %h, data[$]  = %h", data[0], data[$]));
            $display($sformatf("tstrb[0] = %h, tstrb[$] = %h", tstrb[0], tstrb[$]));
            $display($sformatf("tkeep[0] = %h, tkeep[$] = %h", tkeep[0], tkeep[$]));
            $display($sformatf("user[0]  = %h, user[$]  = %h", user[0], user[$]));
            $display($sformatf("tlast[0] = %h, tlast[$] = %h", tlast[0], tlast[$]));
            $display($sformatf("no_rdy_cnt = %0d", no_rdy_cnt));
        end
        $display($sformatf("========================\n"));
    endfunction

    function void post_randomize();
        trans_id_st += 1;
        trans_id = trans_id_st;
        
        // tlast in axis_m is HIGH only at last transaction
        // however, axis_s can accept tlast is HIGH at any transaction
        // modify the random tlast queue to match axis_m bahavior
        //////////////////////////// 
        foreach(tlast[i]) tlast[i] = 0;
        tlast[$] = 1;
        ////////////////////////////
    endfunction

    function bit compare(axil_axis_scenario tr_cmp);
        int err_cnt;

        err_cnt = 0;
        if(this.data !== tr_cmp.data) err_cnt += 1;
        if(this.tstrb !== tr_cmp.tstrb) err_cnt += 1;
        if(this.tkeep !== tr_cmp.tkeep) err_cnt += 1;
        if(this.user !== tr_cmp.user) err_cnt += 1;
        if(this.tlast !== tr_cmp.tlast) err_cnt += 1;

        if(err_cnt != 0) return 0;
        else return 1;
    endfunction
endclass

typedef mailbox #(axil_axis_scenario) mb_axi;

class axil_axis_scenario_gen;
    axil_axis_scenario scnr;
    mb_axi mb_scnr[2];
    static int PKT_NUM;

    function new(mb_axi mb_scn2drvr, mb_scn2scrbd);
        this.mb_scnr[0] = mb_scn2drvr;
        this.mb_scnr[1] = mb_scn2scrbd;
    endfunction

   task gen();
        for(int i=0; i < PKT_NUM; i++)begin
            scnr = new();
            scnr.randomize();
            //scnr.display();
            mb_scnr[0].put(scnr);
            mb_scnr[1].put(scnr);
        end
    endtask
endclass
