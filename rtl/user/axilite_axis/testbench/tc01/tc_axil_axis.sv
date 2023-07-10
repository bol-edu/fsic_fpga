///////////////////////////////////////////////////////////////////////////////
//
//       MODULE: tc
//       AUTHOR: zack
// ORGANIZATION: fsic
//      CREATED: 2023/07/08
///////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ns

`include "axil_axis_interface.sv"

module tc(axil_axis_interface axi_intf);
    `include "axil_axis_scenario.sv"
    `include "axil_axis_driver.sv"
    `include "axil_axis_monitor.sv"
    `include "axil_axis_scoreboard.sv"

    axil_axis_scenario_gen gen;
    axil_axis_driver drvr;
    axil_axis_monitor mon;
    axil_axis_scoreboard scrbd;
    mb_axi gen2drvr, gen2scrbd, mon2scrbd;

    constraint axil_axis_scenario::rdy{ // override constraint
        //no_rdy_cnt == 0;
    }

    function connect();
        gen2drvr = new();
        gen2scrbd = new();
        mon2scrbd = new();

        gen = new(gen2drvr, gen2scrbd);
        drvr = new(axi_intf.connect, gen2drvr);
        mon = new(axi_intf.connect, mon2scrbd);
        scrbd = new(axi_intf.connect, gen2scrbd, mon2scrbd);
    endfunction

    initial begin
        connect();
        axil_axis_scenario_gen::PKT_NUM = 30;
        //axil_axis_scenario_gen::PKT_NUM = 500;

        fork
            gen.gen();
            drvr.bus_op();
            mon.bus_mon();
            scrbd.compare_trans();
        join

        scrbd.report();
        $finish();
    end
endmodule
