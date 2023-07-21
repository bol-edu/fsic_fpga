`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/17 22:39:23
// Design Name: 
// Module Name: arbiter_tb
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

module axis_sw_tb();

parameter   DATA_WIDTH = 32;
parameter   STRB_WIDTH = DATA_WIDTH/8;
parameter   USER_WIDTH = 2;
parameter   TID_WIDTH = 2;
parameter   VALID_WS_LEN = 2;

reg o_clk, o_rst_n;

//for axi_lite
//write address channel
reg 	soc_axi_awvalid;
reg 	[14:0] soc_axi_awaddr;		
wire	soc_axi_awready;

//write data channel
reg 	soc_axi_wvalid;
reg 	[DATA_WIDTH-1:0] soc_axi_wdata;
reg 	[(DATA_WIDTH/8)-1:0] soc_axi_wstrb;
wire	soc_axi_wready;

//read addr channel
reg 	soc_axi_arvalid;
reg 	[14:0] soc_axi_araddr;
wire soc_axi_arready;

//read data channel
wire soc_axi_rvalid;
wire [DATA_WIDTH-1:0] soc_axi_rdata;
reg 	soc_axi_rready;

reg 	soc_cc_as_enable;		//axi_lite enable       

/*
*for Aribter
*/
//Input stream 0
reg [DATA_WIDTH-1:0] data_0;
reg [STRB_WIDTH-1:0] strb_0, keep_0;
reg [USER_WIDTH-1:0] user_0; 
reg valid_0, hpri_req0, tlast_0;
wire ready_0;

//Input stream 1
reg [DATA_WIDTH-1:0] data_1;
reg [STRB_WIDTH-1:0] strb_1, keep_1;
reg [USER_WIDTH-1:0] user_1; 
reg valid_1, tlast_1;
wire ready_1;

//Input stream 2
reg [DATA_WIDTH-1:0] data_2;
reg [STRB_WIDTH-1:0] strb_2, keep_2;
reg [USER_WIDTH-1:0] user_2; 
reg valid_2, hpri_req2, tlast_2;
wire ready_2;

//ouput stream
wire [DATA_WIDTH-1:0] data_m;
wire [STRB_WIDTH-1:0] strb_m, keep_m;
wire valid_m, tlast_m;
wire [USER_WIDTH-1:0] user_m;
wire [TID_WIDTH-1:0] tid_m; 
reg ready_m;

/*
*for Demux
*/
//Input stream
reg is_valid = 1'b0, is_tlast;
reg [DATA_WIDTH-1:0] is_data;
reg [STRB_WIDTH-1:0] is_strb;
reg [STRB_WIDTH-1:0] is_keep;
reg [TID_WIDTH-1:0] is_tid;
reg [USER_WIDTH-1:0] is_user;
wire is_ready;

//ouput stream 0
wire [DATA_WIDTH-1:0] up_data;
wire [STRB_WIDTH-1:0] up_keep;
wire [STRB_WIDTH-1:0] up_strb;
wire up_valid, up_tlast;
wire [USER_WIDTH-1:0] up_user;
reg up_ready;

//ouput stream 1
wire [DATA_WIDTH-1:0] aa_data;
wire [STRB_WIDTH-1:0] aa_keep;
wire [STRB_WIDTH-1:0] aa_strb;
wire aa_valid, aa_tlast;
wire [USER_WIDTH-1:0] aa_user;
reg aa_ready;

reg start_test; 

//axi_lite
task soc_cfg_write;		//input addr, data, strb and valid_delay 
	input [14:0] axi_awaddr;
	input [DATA_WIDTH-1:0] axi_wdata;
	input [3:0] axi_wstrb;
	input [7:0] valid_delay;
	
	begin
		soc_axi_awaddr <= axi_awaddr;
		soc_axi_awvalid <= 0;
		soc_axi_wdata <= axi_wdata;
		soc_axi_wstrb <= axi_wstrb;
		soc_axi_wvalid <= 0;
		repeat (valid_delay) @ (posedge o_clk);
		soc_axi_awvalid <= 1;
		soc_axi_wvalid <= 1;
		@ (posedge o_clk);
		while (soc_axi_awready == 0) begin		//assume both soc_axi_awready and soc_axi_wready assert as the same time.
			@ (posedge o_clk);
		end
		$display($time, "=> soc_cfg_write : soc_axi_awaddr=%x, soc_axi_awvalid=%b, soc_axi_awready=%b, soc_axi_wdata=%x, axi_wstrb=%x, soc_axi_wvalid=%b, soc_axi_wready=%b", soc_axi_awaddr, soc_axi_awvalid, soc_axi_awready, soc_axi_wdata, axi_wstrb, soc_axi_wvalid, soc_axi_wready); 
		soc_axi_awvalid <= 0;
		soc_axi_wvalid <= 0;
	end
endtask

task soc_cfg_read;		//input addr and valid_delay 
	input [14:0] axi_araddr;
	input [7:0] valid_delay;
	
	begin
		soc_axi_araddr <= axi_araddr;
		soc_axi_arvalid <= 0;
		soc_axi_rready <= 0;
		repeat (valid_delay) @ (posedge o_clk);
		soc_axi_arvalid <= 1;
		@ (posedge o_clk);
		while (soc_axi_arready == 0) begin		
				@ (posedge o_clk);
		end
		$display($time, "=> soc_cfg_read : soc_axi_araddr=%x, soc_axi_arvalid=%b, soc_axi_arready=%b", soc_axi_araddr, soc_axi_arvalid, soc_axi_arready); 
		
		soc_axi_arvalid <= 0;
		repeat (valid_delay) @ (posedge o_clk);
		soc_axi_rready <= 1;
		@ (posedge o_clk);
		while (soc_axi_rvalid == 0) begin		
				@ (posedge o_clk);
		end
		$display($time, "=> soc_cfg_read : soc_axi_rdata=%x, soc_axi_rready=%b, soc_axi_rvalid=%b", soc_axi_rdata, soc_axi_rready, soc_axi_rvalid); 
		soc_axi_rready <= 0;
	end
endtask

task axis_tx;
    input [DATA_WIDTH-1:0] data_in;
    input [STRB_WIDTH-1:0] strb_in, keep_in;
    input [USER_WIDTH-1:0] user_in; 
    input tlast_in;    
    input [VALID_WS_LEN-1:0] valid_wait_state;
    
    begin    
        data_0 = #0 data_in;
        strb_0 = strb_in;
        keep_0 = keep_in;
        tlast_0 = #0 tlast_in;
        user_0 = user_in;
        if(valid_wait_state != {(VALID_WS_LEN){1'b0}}) begin
            valid_0 = 0;
            repeat (valid_wait_state) @ (posedge o_clk);
        end
        valid_0 = 1;
        repeat (1) @ (posedge o_clk);     
        wait(valid_0 && ready_0);
        if(tlast_in) begin
            valid_0 = #0 0;  
            tlast_0 = 0;
        end            
    end  
endtask

task axis_tx_hi_req;
    input [DATA_WIDTH-1:0] data_in;
    input [STRB_WIDTH-1:0] strb_in, keep_in;
    input [USER_WIDTH-1:0] user_in; 
    input tlast_in, hpri_req_in;    
    input [VALID_WS_LEN-1:0] valid_wait_state;
    begin
        hpri_req0 = #0 hpri_req_in;       
        data_0 = #0 data_in;              
        strb_0 = strb_in;
        keep_0 = keep_in;
        tlast_0 = tlast_in;
        user_0 = user_in;
        if(valid_wait_state != {(VALID_WS_LEN){1'b0}}) begin
            valid_0 = 0;
            repeat (valid_wait_state) @ (posedge o_clk);
        end
        valid_0 = 1;
        repeat (1) @ (posedge o_clk);     
        wait(valid_0 && ready_0);
        if(!hpri_req_in) begin
            valid_0 = #0 0;         
            tlast_0 = 0;      
        end                       
    end  
endtask

task axis_tx1;
    input [DATA_WIDTH-1:0] data_in;
    input [STRB_WIDTH-1:0] strb_in, keep_in;
    input [USER_WIDTH-1:0] user_in; 
    input tlast_in;    
    input [VALID_WS_LEN-1:0] valid_wait_state;
    
    begin    
        data_1 = #0 data_in;   
        strb_1 = strb_in;
        keep_1 = keep_in;
        tlast_1 = tlast_in;   
        user_1 = user_in;
        if(valid_wait_state != {(VALID_WS_LEN){1'b0}}) begin
            valid_1 = 0;
            repeat (valid_wait_state) @ (posedge o_clk);
        end
        valid_1 = 1;
        repeat (1) @ (posedge o_clk);     
        wait(valid_1 && ready_1);
        if(tlast_in) begin
            valid_1 = #0 0;  
            tlast_1 = 0;  
        end            
    end  
endtask

task axis_tx_hi_req2;
    input [DATA_WIDTH-1:0] data_in;
    input [STRB_WIDTH-1:0] strb_in, keep_in;
    input [USER_WIDTH-1:0] user_in; 
    input tlast_in, hpri_req_in;    
    input [VALID_WS_LEN-1:0] valid_wait_state;
    begin
        hpri_req2 = #0 hpri_req_in;          
        data_2 = #0 data_in;     
        strb_2 = strb_in;
        keep_2 = keep_in;
        tlast_2 = tlast_in;
        user_2 = user_in;
        if(valid_wait_state != {(VALID_WS_LEN){1'b0}}) begin
            valid_2 = 0;
            repeat (valid_wait_state) @ (posedge o_clk);
        end
        valid_2 = 1;
        repeat (1) @ (posedge o_clk);     
        wait(valid_2 && ready_2);
        if(!hpri_req_in) begin
            valid_2 = #0 0;      
            tlast_2 = 0;                
        end                       
    end  
endtask

task axis_tx2;
    input [DATA_WIDTH-1:0] data_in;
    input [STRB_WIDTH-1:0] strb_in, keep_in;
    input [USER_WIDTH-1:0] user_in; 
    input tlast_in;    
    input [VALID_WS_LEN-1:0] valid_wait_state;
    
    begin    
        data_2 = #0 data_in;   
        strb_2 = strb_in;
        keep_2 = keep_in;
        tlast_2 = tlast_in;   
        user_2 = user_in;
        if(valid_wait_state != {(VALID_WS_LEN){1'b0}}) begin
            valid_2 = 0;
            repeat (valid_wait_state) @ (posedge o_clk);
        end
        valid_2 = 1;
        repeat (1) @ (posedge o_clk);     
        wait(valid_2 && ready_2);
        if(tlast_in) begin
            valid_2 = #0 0;   
            tlast_2 = 0;  
        end            
    end  
endtask

task axis_rx;    
    reg Is_hi_req;
    begin
        ready_m <= 1;
        if(ready_m && valid_m) begin
            $display("Upstream received stream data is %h", data_m);
            $display("TID is %h", tid_m);                
            $display("data strobe is %h", strb_m);
            $display("keep is %h", keep_m);
            $display("user data is %h", user_m);
            if(tlast_m) begin
                $display("This transaction is over"); 
                ready_m <= 0;                
            end
        end                                                                  
    end  
endtask

//for Demux task
task is_axis_tx;
    input [DATA_WIDTH-1:0] data_in;
    input [STRB_WIDTH-1:0] strb_in;    
    input [STRB_WIDTH-1:0] keep_in;
    input tlast_in;  
    input [TID_WIDTH-1:0] tid_in;        
    input [USER_WIDTH-1:0] user_in;  
    input [VALID_WS_LEN-1:0] valid_wait_state;
    
    begin    
        is_data = #0 data_in;
        is_strb = strb_in;        
        is_keep = keep_in;
        is_tlast = tlast_in;
        is_tid = tid_in;
        is_user = user_in;
        if(valid_wait_state != {(VALID_WS_LEN){1'b0}}) begin
            is_valid = 0;
            repeat (valid_wait_state) @ (posedge o_clk);
        end
        is_valid = 1;
        repeat (1) @ (posedge o_clk); 


//test case 1_begin:  when checking valid and ready are 1 from  Io_serses
/*
        if(!is_ready) begin
            wait(is_ready)
            is_valid = 1;
            repeat (1) @ (posedge o_clk); 
        end 
*/             
//test case 1_end                        
//test case 2_begin: when valid is 1 to receive data from Io_serses (now we apply this test case for Tony's requirement)     
        if(!is_ready) begin
            is_valid = 0;
            repeat (1) @ (posedge o_clk);
            wait(is_ready);
            is_valid = 1;
            repeat (1) @ (posedge o_clk);              
        end     
//test case 2_end             
        wait(is_valid && is_ready);
        if(tlast_in) begin
            is_valid = #0 0;  
            is_tlast = 0;
        end            
    end  
endtask

task up_axis_rx;
    begin
        up_ready <= 1;
        if(up_ready && up_valid) begin
            $display("User Project stream data is %h", up_data);
            $display("strb is %h", up_strb);            
            $display("keep is %h", up_keep);
            $display("user data is %h", up_user);
            if(up_tlast) begin 
                $display("This transaction is over");
            end                 
        end
    end  
endtask

task aa_axis_rx;
    reg [4:0] dcount;
    begin
        if(dcount != 5'd0) begin
            if(dcount == 5'd5) begin
                aa_ready <= 1;
                dcount <= 5'd0;
            end else begin
                aa_ready <= 0;
                dcount <= dcount + 1;
            end
        end else begin
            aa_ready <= 1;
            dcount <= 5'd0;
        end                        
        if(aa_ready && aa_valid) begin
            $display("Axis_Axilite stream data is %h", aa_data);
            $display("strb is %h", aa_strb);            
            $display("keep is %h", aa_keep);
            $display("user data is %h", aa_user);
            if(aa_tlast) begin
                $display("This transaction is over"); 
            end
            if((aa_data==16'h5551) && (dcount == 5'd0)) begin
                dcount <= 1;
            end                        
       end
    end  
endtask

//for Arbiter Rx
always @(posedge o_clk) begin
    if(o_rst_n)
        if(start_test == 1)
            axis_rx;
end

//For Demux Rx
always @(posedge o_clk) begin
    if(o_rst_n)
        if(start_test == 1)
            up_axis_rx;
end

always @(posedge o_clk) begin
    if(o_rst_n)
        if(start_test == 1)
            aa_axis_rx;
end

initial
begin
#150
start_test = 1'b1;  
end

initial
begin
    start_test = 1'b0;    
	o_clk = 0;
	o_rst_n = 1'b0;
	#100 o_rst_n = 1;
	#50 
    //for axi_lite
    //write addr channel
    soc_axi_awvalid = 0;
    soc_axi_awaddr = 0;
    //write data channel
    soc_axi_wvalid = 0;
    soc_axi_wdata = 0;
    soc_axi_wstrb = 0;
    //read addr channel
    soc_axi_arvalid = 0;
    soc_axi_araddr = 0;
    //read data channel
    soc_axi_rready = 0;
    
    soc_cc_as_enable = 0;
    
    #100;
    soc_cc_as_enable = 1;
    soc_cfg_write(0,0,1,0);		//write offset 0 = 0
    soc_cfg_read(0,0);			//read offset 0
    soc_cfg_write(0,4,1,0);		//write offset 0 = 4
    soc_cfg_read(0,0);			//read offset 0

    //data, strb, keep, user, tlast, hi_req, wait	
	axis_tx_hi_req(16'h2221, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req(16'h2222, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req(16'h2223, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req(16'h2224, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00);  			    
	axis_tx_hi_req(16'h2225, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req(16'h2226, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00); 	  	
	axis_tx_hi_req(16'h2227, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00); 
	axis_tx_hi_req(16'h2228, 4'hF,  4'hF, 2'b00, 1'b0, 1'b1, 2'b00); 	
	axis_tx_hi_req(16'h2229, 4'hF,  4'hF, 2'b00, 1'b0, 1'b0, 2'b00);  //for no last support, hi_req must deassert for the last transfer	 
//	axis_tx_hi_req(16'h2229, 4'hF,  4'hF, 2'b00, 1'b1, 1'b0, 2'b00);  //for last support
end

initial
begin
    //data, strb, keep, user, tlast, wait	
    #5000 	  
	axis_tx(16'h1111, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00);
	axis_tx(16'h1112, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00); 	  	
	axis_tx(16'h1113, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00);  
	axis_tx(16'h1114, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00); 
	axis_tx(16'h1115, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00);  
	axis_tx(16'h1116, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00); 	  	
	axis_tx(16'h1117, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00);  
	axis_tx(16'h1118, 4'hF,  4'hF, 2'b00, 1'b0, 2'b00); 					
	axis_tx(16'h1119, 4'hF,  4'hF, 2'b00, 1'b1, 2'b00);
end

initial
begin
#1000
	axis_tx1(16'h3331, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00);
	axis_tx1(16'h3332, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00); 	  	
	axis_tx1(16'h3333, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00);  
	axis_tx1(16'h3334, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00); 
	axis_tx1(16'h3335, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00);  
	axis_tx1(16'h3336, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00); 	  	
	axis_tx1(16'h3337, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00);  
	axis_tx1(16'h3338, 4'hF,  4'hF, 2'b01, 1'b0, 2'b00); 					
	axis_tx1(16'h3339, 4'hF,  4'hF, 2'b01, 1'b1, 2'b00);
end

initial
begin
#1000
	axis_tx_hi_req2(16'h6661, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req2(16'h6662, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req2(16'h6663, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req2(16'h6664, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00);  			    
	axis_tx_hi_req2(16'h6665, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req2(16'h6666, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00); 	  	
	axis_tx_hi_req2(16'h6667, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00);  
	axis_tx_hi_req2(16'h6668, 4'hF,  4'hF, 2'b10, 1'b0, 1'b1, 2'b00); 	
	axis_tx_hi_req2(16'h6669, 4'hF,  4'hF, 2'b10, 1'b0, 1'b0, 2'b00);  //for no last support, hi_req must deassert for the last transfer
//	axis_tx_hi_req2(16'h6669, 4'hF,  4'hF, 2'b10, 1'b1, 1'b0, 2'b00);  //for last support	 
end

initial
begin
    //data, strb, keep, user, tlast, wait	
    #5000 	  
	axis_tx2(16'h5551, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00);
	axis_tx2(16'h5552, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00); 	  	
	axis_tx2(16'h5553, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00);  
	axis_tx2(16'h5554, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00); 
	axis_tx2(16'h5555, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00);  
	axis_tx2(16'h5556, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00); 	  	
	axis_tx2(16'h5557, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00);  
	axis_tx2(16'h5558, 4'hF,  4'hF, 2'b10, 1'b0, 2'b00); 					
	axis_tx2(16'h5559, 4'hF,  4'hF, 2'b10, 1'b1, 2'b00);
end

//for Demux
initial
begin
    start_test = 1'b0;    
	o_clk = 0;
	o_rst_n = 1'b0;
	#100 o_rst_n = 1;
	#1000 

    //data, strb, keep, tlast, tid, user, wait 
	is_axis_tx(16'h2221, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);   
	is_axis_tx(16'h2222, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h2223, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);    
	is_axis_tx(16'h2224, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h2225, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);   
	is_axis_tx(16'h2226, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h2227, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);    
	is_axis_tx(16'h2228, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h2229, 4'hF, 4'hF, 1'b1, 2'b00, 2'b00, 2'b00);    	 		   	
	is_axis_tx(16'h1111, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);
	is_axis_tx(16'h1112, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 	  	
	is_axis_tx(16'h1113, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);  
	is_axis_tx(16'h1114, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 
	is_axis_tx(16'h1115, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);  
	is_axis_tx(16'h1116, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 	  	
	is_axis_tx(16'h1117, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);  
	is_axis_tx(16'h1118, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 					
	is_axis_tx(16'h1119, 4'hF, 4'hF, 1'b1, 2'b01, 2'b01, 2'b00);
	
	#1000 
    //data, strb, keep, tlast, tid, user, wait 
	is_axis_tx(16'h3331, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);   
	is_axis_tx(16'h3332, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h3333, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);    
	is_axis_tx(16'h3334, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h3335, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);  
	is_axis_tx(16'h3336, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h3337, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);    
	is_axis_tx(16'h3338, 4'hF, 4'hF, 1'b0, 2'b00, 2'b00, 2'b00);
	is_axis_tx(16'h3339, 4'hF, 4'hF, 1'b1, 2'b00, 2'b00, 2'b00);  	
    is_axis_tx(16'h5551, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);
	is_axis_tx(16'h5552, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 	  	
	is_axis_tx(16'h5553, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);  
	is_axis_tx(16'h5554, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 
	is_axis_tx(16'h5555, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);  
	is_axis_tx(16'h5556, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 	  	
	is_axis_tx(16'h5557, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00);  
	is_axis_tx(16'h5558, 4'hF, 4'hF, 1'b0, 2'b01, 2'b01, 2'b00); 	  	
	is_axis_tx(16'h5559, 4'hF, 4'hF, 1'b1, 2'b01, 2'b01, 2'b00); 	
end

AXIS_SW uut_AXIS_SW(
.axi_reset_n(o_rst_n),
.axis_clk(o_clk),
//axi_lite interface
.axi_awvalid(soc_axi_awvalid),
.axi_awaddr(soc_axi_awaddr),
.axi_awready(soc_axi_awready),
.axi_wvalid(soc_axi_wvalid),
.axi_wdata(soc_axi_wdata),
.axi_wstrb(soc_axi_wstrb),
.axi_wready(soc_axi_wready),
.axi_arvalid(soc_axi_arvalid),
.axi_araddr(soc_axi_araddr),
.axi_arready(soc_axi_arready),
.axi_rvalid(soc_axi_rvalid),
.axi_rdata(soc_axi_rdata),
.axi_rready(soc_axi_rready),
.cc_as_enable(soc_cc_as_enable),
//Upstream for axis arbiter
.up_as_tdata(data_0),
.up_as_tstrb(strb_0),
.up_as_tkeep(keep_0),
.up_as_tlast(tlast_0),
.up_as_tvalid(valid_0),
.up_as_tuser(user_0),
.up_hpri_req(hpri_req0),
.as_up_tready(ready_0),
.aa_as_tdata(data_1),
.aa_as_tstrb(strb_1),
.aa_as_tkeep(keep_1),
.aa_as_tlast(tlast_1),
.aa_as_tvalid(valid_1),
.aa_as_tuser(user_1),
.as_aa_tready(ready_1),
.la_as_tdata(data_2),
.la_as_tstrb(strb_2),
.la_as_tkeep(keep_2),
.la_as_tlast(tlast_2),
.la_as_tvalid(valid_2),
.la_as_tuser(user_2),
.la_hpri_req(hpri_req2),
.as_la_tready(ready_2),
.as_is_tdata(data_m),
.as_is_tstrb(strb_m),
.as_is_tkeep(keep_m),
.as_is_tlast(tlast_m),
.as_is_tid(tid_m), 
.as_is_tvalid(valid_m),
.as_is_tuser(user_m),
.is_as_tready(ready_m),
//Downstream for axis demux
.is_as_tdata(is_data),
.is_as_tstrb(is_strb),
.is_as_tkeep(is_keep),
.is_as_tlast(is_tlast),
.is_as_tid(is_tid),
.is_as_tvalid(is_valid),
.is_as_tuser(is_user),
.as_is_tready(is_ready),
.as_up_tdata(up_data),
.as_up_tstrb(up_strb),
.as_up_tkeep(up_keep),
.as_up_tlast(up_tlast),
.as_up_tvalid(up_valid),
.as_up_tuser(up_user),
.up_as_tready(up_ready),
.as_aa_tdata(aa_data),
.as_aa_tstrb(aa_strb),
.as_aa_tkeep(aa_keep),
.as_aa_tlast(aa_tlast),
.as_aa_tvalid(aa_valid),
.as_aa_tuser(aa_user),
.aa_as_tready(aa_ready)
);

always	#50 o_clk = ~o_clk;
endmodule
