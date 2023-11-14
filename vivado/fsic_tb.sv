`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2023 03:49:21 PM
// Design Name: 
// Module Name: fsic_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

bit resetb_0 = 0, sys_clock = 0, sys_reset = 0; 
xil_axi_resp_t resp;
bit[31:0] addr, data, base_addr = 32'h6000_0000;

module fsic_tb();

    design_1_wrapper DUT
    (
        .resetb_0(resetb_0),
        .sys_clock(sys_clock),
        .sys_reset(sys_reset)
    );
    
    //always #4ns sys_clock = ~sys_clock;     //Period 8ns, 125MHz
    always #2ns sys_clock = ~sys_clock;     //Period 4ns, 250Mhz    
    
    initial begin
        sys_reset = 0;
        #200ns
        sys_reset = 1;
    end
    
    design_1_axi_vip_0_0_mst_t  master_agent;
    
    initial begin
        master_agent = new("master vip agent", DUT.design_1_i.axi_vip_0.inst.IF);
        master_agent.start_master();
        wait(sys_reset == 1'b1);
        $display($time, "=> sys_rest = %01b", sys_reset);
        
        wait(DUT.design_1_i.rst_clk_wiz_0_5M_peripheral_aresetn == 1'b1);
        
        #200us
        resetb_0 = 1;
        $display($time, "=> resetb_0 = %01b", resetb_0);        
        
        wait(DUT.design_1_i.caravel_0_mprj_o[37:36] == 2'b11);
        $display($time, "=> FW working, caravel_0_mprj_o[37:36] = %02b", DUT.design_1_i.caravel_0_mprj_o[37:36]);
                     
        #100us
        addr = 16'h7000;
        master_agent.AXI4LITE_READ_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_READ_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);
        
        #100us
        addr = 16'h7000;
        data = 32'h0000_0001;
        master_agent.AXI4LITE_WRITE_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_WRITE_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);

        #100us
        addr = 16'h7000;
        master_agent.AXI4LITE_READ_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_READ_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);

        #100us
        addr = 16'h7000;
        data = 32'h0000_0003;
        master_agent.AXI4LITE_WRITE_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_WRITE_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);

        #100us
        addr = 16'h7000;
        master_agent.AXI4LITE_READ_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_READ_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);
                
        #100us
        addr = 16'h5000;
        master_agent.AXI4LITE_READ_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_READ_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);
        
        #100us
        addr = 16'h5000;
        data = 32'h0000_0011;
        master_agent.AXI4LITE_WRITE_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_WRITE_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);

        #100us
        addr = 16'h5000;
        master_agent.AXI4LITE_READ_BURST(base_addr + addr, 0, data, resp);
        $display($time, "=> AXI4LITE_READ_BURST %04h, value: %04h, resp: %02b", base_addr + addr, data, resp);
                
        #500us               
        $finish;
    end

endmodule
