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
    //rand axi_path_type axi_path_typ[$];
    rand axi_path_type axi_path_typ;
    rand axi_operation axi_op;
    //rand supported_addr supp_addr[$];
    rand supported_addr supp_addr;

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
    rand logic [1:0] user_value; // fix constraint solver fail
    rand logic [1:0] user[$];
    rand logic [7:0] no_rdy_cnt;
    rand logic tlast[$];

    constraint axi_trans{
        (axi_trans_typ == TRANS_AXIL) ->
            //foreach(axi_path_typ[i]) {
            //    axi_path_typ[i] dist {PATH_LS_AAREG:= 1, PATH_LS_MBREG:= 1, PATH_LS_SM:= 1};
            //}
            axi_path_typ dist {PATH_LS_AAREG:= 1, PATH_LS_MBREG:= 1, PATH_LS_SM:= 1};

        (axi_trans_typ == TRANS_AXIS) ->
            //foreach(axi_path_typ[i]) {
            //    axi_path_typ[i] dist {PATH_SS_MBREG:= 1, PATH_SS_AAREG:= 1, PATH_SS_LM:= 1};
            //}
            // ?????????????????????? axi_path_typ dist {PATH_SS_MBREG:= 1, PATH_SS_AAREG:= 1, PATH_SS_LM:= 1};
            axi_path_typ dist {PATH_SS_MBREG:= 1};
        solve axi_trans_typ before axi_path_typ;
    }

    constraint length_of_stream{
        (axi_trans_typ == TRANS_AXIL) -> stream_size == 1;
        (axi_trans_typ == TRANS_AXIS) -> stream_size > 0;
        
        //user.size <= 10;
        (user_value == 2'b01) -> stream_size == 2;
        (user_value == 2'b10 || user_value == 2'b11) -> stream_size == 1;
        //stream_size <= 30;
        ////stream_size <= 5;
        //stream_size dist {  [1:5]   := 25,
        //                    [6:24]  := 60,
        //                    [25:30] := 15};
        //axi_path_typ.size == stream_size;
        //supp_addr.size == stream_size;

        data.size == stream_size;
        tstrb.size == stream_size;
        tkeep.size == stream_size;
        user.size == stream_size;
        tlast.size == stream_size;
        solve axi_trans_typ before stream_size;
        solve user_value before stream_size;
        //solve stream_size before data;
        //solve stream_size before tstrb;
        //solve stream_size before tkeep;
        //solve stream_size before tlast;
    }

    constraint axi_addr{
        /*(axi_trans_typ == TRANS_AXIL) -> {  wr_addr[31:15] == 0,
                                            rd_addr[31:15] == 0
        };*/

        /*(axi_trans_typ == TRANS_AXIS) -> {  wr_addr[31:16] == 16'h3000,
                                            rd_addr[31:16] == 16'h3000
        };*/

        //if(axi_path_typ[0] == PATH_LS_AAREG){
        //    if(supp_addr[0] == SUPP_ADDR_YES){
        if(axi_path_typ == PATH_LS_AAREG){
            if(supp_addr == SUPP_ADDR_YES){
                wr_addr[14:0] inside { [15'h2100:15'h2107] };
                rd_addr[14:0] inside { [15'h2100:15'h2107] };
            }
            //if(supp_addr[0] == SUPP_ADDR_NO){
            if(supp_addr == SUPP_ADDR_NO){
                wr_addr[14:0] inside { [15'h2108:15'h2FFF] };
                rd_addr[14:0] inside { [15'h2108:15'h2FFF] };
            }
        }
        //if(axi_path_typ[0] == PATH_LS_MBREG){
        //    if(supp_addr[0] == SUPP_ADDR_YES){
        if(axi_path_typ == PATH_LS_MBREG){
            if(supp_addr == SUPP_ADDR_YES){
                wr_addr[14:0] inside { [15'h2000:15'h201F] };
                rd_addr[14:0] inside { [15'h2000:15'h201F] };
            }
            //if(supp_addr[0] == SUPP_ADDR_NO){
            if(supp_addr == SUPP_ADDR_NO){
                wr_addr[14:0] inside { [15'h2020:15'h20FF] };
                rd_addr[14:0] inside { [15'h2020:15'h20FF] };
            }
        }
        //if(axi_path_typ[0] == PATH_LS_SM){
        //    if(supp_addr[0] == SUPP_ADDR_YES){
        if(axi_path_typ == PATH_LS_SM){
            if(supp_addr == SUPP_ADDR_YES){
                wr_addr[14:0] inside { [15'h0000:15'h1FFF], [15'h3000:15'h4FFF] };
                rd_addr[14:0] inside { [15'h0000:15'h1FFF], [15'h3000:15'h4FFF] };
            }
            //if(supp_addr[0] == SUPP_ADDR_NO){
            if(supp_addr == SUPP_ADDR_NO){
                wr_addr[14:0] inside { [15'h5000:15'h7FFF] };
                rd_addr[14:0] inside { [15'h5000:15'h7FFF] };
            }
        }
        solve axi_trans_typ before wr_addr;
        solve axi_trans_typ before rd_addr;
        solve supp_addr before wr_addr;
        solve supp_addr before rd_addr;
    }

    constraint stream_data{
        user_value != 0; // ??????????????????
        user_value == 1; // ??????????????????
        if(axi_path_typ == PATH_SS_MBREG){
            if(supp_addr == SUPP_ADDR_YES){
                (user_value == 2'b01) -> data[0][27:0] inside { [28'h2000:28'h201F] };
                (user_value == 2'b10) -> data[0][31:0] inside { [28'h2000:28'h201F] };
            }
            if(supp_addr == SUPP_ADDR_NO){
                (user_value == 2'b01) -> data[0][27:0] inside { [28'h2020:28'h20FF] };
                (user_value == 2'b10) -> data[0][31:0] inside { [28'h2020:28'h20FF] };
            }
        }
        (axi_path_typ == PATH_SS_AAREG) -> supp_addr == SUPP_ADDR_NO;
        if(axi_path_typ == PATH_SS_AAREG){
            if(supp_addr == SUPP_ADDR_NO){
                (user_value == 2'b01) -> data[0][27:0] inside { [28'h2100:28'h2FFF] };
                (user_value == 2'b10) -> data[0][31:0] inside { [28'h2100:28'h2FFF] };
            }
        }
        if(axi_path_typ == PATH_SS_LM){
            if(supp_addr == SUPP_ADDR_YES){
                (user_value == 2'b01) -> data[0][27:0] inside { [28'h0000:28'h1FFF], [28'h3000:28'h4FFF] };
                (user_value == 2'b10) -> data[0][31:0] inside { [28'h0000:28'h1FFF], [28'h3000:28'h4FFF] };
            }
            if(supp_addr == SUPP_ADDR_NO){
                (user_value == 2'b01) -> data[0][27:0] inside { [28'h5000:28'hFFFFFFF] };
                (user_value == 2'b10) -> data[0][31:0] inside { [28'h5000:28'hFFFFFFF] };
            }
        }
        solve user before data;
    }

    //constraint no_rdy{
    //    no_rdy_cnt >= 0;
    //    (stream_size >= 5) -> (no_rdy_cnt <= stream_size - 2);
    //    no_rdy_cnt <= MAX_NO_RDY;
    //    solve stream_size before no_rdy_cnt;
    //}

    extern constraint rdy;

    function new();
        //this.randomize();
    endfunction

    virtual function void display(string prefix="");
        $display($sformatf("\ntrans_id %6d ========%s", trans_id, prefix));

        $display($sformatf("axi_trans_typ = %s", axi_trans_typ));
        //$display($sformatf("axi_path_typ = %p", axi_path_typ));
        $display($sformatf("axi_path_typ = %s", axi_path_typ));
        //$display($sformatf("supp_addr = %p", supp_addr));
        $display($sformatf("supp_addr = %s", supp_addr));
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
        foreach(user[i]) user[i] = user_value; // all user queue is same as user_value
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
