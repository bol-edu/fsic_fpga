# Axilite_Axis (Axilite Axis Protocol Conversion) Implementation Specification
This module provides protocol conversion from axi4 lite (axilite) to axi4 stream (axis) and from axi4 stream to axi4 lite, as shown below.

![](https://drive.google.com/uc?export=view&id=1n7GhsaW1yYoY2KRnGE6839jNQ_jcM4Zl)

For protocol conversion from axilite to axis, it uses s_axilite (input) and m_axis (output).
For protocol conversion from axis to axilite, it uses s_axis (input) and m_axilite (output).

The module provides a channel for FPGA/ARM to access modules in Caravel chip, and vice-versa. every IP inside caravel user project area, its address space can be accessed by fpga PS through this module. it converts axilite transaction to [modified axis transaction](https://github.com/bol-edu/fsic-spec-dev/blob/main/modules/FSIC-AXIS%20interface%20specification.md). for more details, please refer to the spec.

at fpga side, this module has additional axilite master to access external configuration storage mailbox. also, there is one signal added to axilite protocol **axi_wremote** to indicate the transaction is from caravel or fpga side.

The Caravel and FPGA share the same Caravel memory-map. If it conflicts with FPGA system memory-map address. FPGA side remapping scheme is needed. in case of the mailbox base address in address map may change at fpga side, this module implements **remap control register / remap addr register** for software configuration.

## bus protocol conversion
![bus protocol conversion](https://drive.google.com/uc?export=view&id=15UyfNoBsNcn67D7s8WNFNhD4migp2xPY)
as shown in the image, 
1. the transaction received from axilite slave will convert to axis issued by axis master with **tid** = 2'b01, where
<br>  a. axilite write address / write data become a two-cycle axis data, and send with **tuser** = 2'b01.
<br>  b. axilite read address become a one-cycle axis data with **tuser** = 2'b10.
<br>  c. axilite read data will return from axis slave, identified with **tuser** = 2'b11. please note the axilite master shall not send new axilite read request before read data returned. this module keep axilite read address channel slave ready low until the read data returned. in other words, the new axilite read request will not be accepted until previous read data returned. in case of the data not returned thus the system stuck, we will implement a error handling process: 
<br> (i) when timeout, return a fake data (0xFFFF_FFFF) to the read requsest sender.
<br> (ii) also generate a interrupt with error status to the read requsest sender. 
<br> (iii) this module treat the timeout read requsest as completed.
<br>  the error handling process will be implemented in later phase. the definition of timeout? may need a register for that.
2. the transaction received from axis slave will convert to axilite issued by axilite master, where
<br>  a. axis slave two-cycle data with **tuser** = 2'b01, can be converted to axilite write address / write data.
<br>  b. axis slave one-cycle data with **tuser** = 2'b10, can be converted to axilite read address.
<br>  c. once the read data returned from axilite master, the data will convert to axis master transaction with **tuser** = 2'b11.
3. about the address bus width difference:
<br>  a. addr[11:0] is for address space inside module, send by config control. when convert to axis, this module appends zero to make addr[27:0].
<br>  b. for addr[27:0] in axis slave, convert to axilite master addr[31:0], this module appends zero. at caravel side, config_control can identify
<br>  c. for fpga PS, we may need addr[31:0] for axilite slave???

## Interface Blocks
![interface](https://drive.google.com/uc?export=view&id=1-FyWw92OE82LvBXjQsf79M83n-i9EhoD)
how the transaction travel between two sides:
1. caravel write mailbox at fpga side:
<br>  a. the axilite transaction from config_control axilite master convert to axis transaction through m_axis block, then received by s_axis at fpga side.
<br>  b. the address and data are extracted in control_logic, if remap is enabled in **remap control register**, the remap_base_address will add to address.
<br>  c. send to mailbox through m_axilite(mailbox) while indicating this transaction is from caravel by setting **axi_wremote** to 1'b0
2. fpga PS read/write mailbox at fpga side:
<br>  a. the axilite transaction from fpga PS received by s_axilite at fpga side. 
<br>  b. if read, the address is extracted in control_logic, then send to mailbox through m_axilite(mailbox), if the read data returned, will send back to fpga PS.
<br>  c. if write, the address and data are extracted in control_logic, then send to mailbox through m_axilite(mailbox), while indicating this transaction is from fpga by setting **axi_wremote** to 1’b1.
<br>  d. control_logic also send one copy of write transaction to caravel side mailbox.???

## Feature Lists
1. convert axilite transaction to [modified axis transaction](https://github.com/bol-edu/fsic-spec-dev/blob/main/modules/FSIC-AXIS%20interface%20specification.md), and convert axis back to axilite, while the axilite talk between modules, axis transmit data between caravel and fpga.
2. at fpga side, this module sends axilite transaction to mailbox with additional **axi_wremote** signal to indicate the transaction is from caravel or fpga side.
3. in case of the mailbox base address in address map may change at fpga side, this module implements **remap control register / remap addr register** for software configuration.

## Interface Signals
### caravel side common signal
| Port | in/out | Description |
|:------:|:------:|:------------ |
| axi_aclk | in | axi clock | 
| axi_areset_n | in | axi reset active low | 
| **cc_aa_enable** | in | config control enable axilite to axis module | 

### caravel side axilite master
| Port | in/out | Description |
|:------:|:------:|:------------ |
| axi_awvalid | out | axi write address valid | 
| axi_awaddr[31:0] | out | axi write address | 
| axi_wvalid | out | axi write data valid | 
| axi_wdata[31:0] | out | axi write data | 
| axi_wstrb[3:0] | out | axi write data strobe | 
| axi_arvalid | out | axi read address valid | 
| axi_araddr[31:0] | out | axi read address | 
| axi_rready | out | axi read data ready | 
| axi_rdata[31:0] | in | axi read data | 
| axi_awready | in | axi write address ready | 
| axi_wready | in | axi write data ready | 
| axi_arready | in | axi read address ready | 
| axi_rvalid | in | axi read data valid | 

### caravel side axilite slave
| Port | in/out | Description |
|:------:|:------:|:------------ |
| axi_awready | out | refer to above description | 
| axi_wready | out | refer to above description | 
| axi_arready | out | refer to above description | 
| axi_rvalid | out | refer to above description | 
| axi_rdata[31:0] | out | refer to above description | 
| axi_awvalid | in | refer to above description | 
| axi_awaddr[11:0] | in | refer to above description | 
| axi_wvalid | in | refer to above description | 
| axi_wdata[31:0] | in | refer to above description | 
| axi_wstrb[3:0] | in | refer to above description | 
| axi_arvalid | in | refer to above description | 
| axi_araddr[11:0] | in | refer to above description | 
| axi_rready | in | refer to above description | 

### caravel side axis master
| Port | in/out | Description |
|:------:|:------:|:------------ |
| axis_tvalid | out | axis valid | 
| axis_tad[31:0] | out | axis address / data | 
| axis_tstrb[3:0] | out | axis strobe | 
| axis_tkeep[3:0] | out | axis keep | 
| axis_tlast | out | axis last | 
| axis_tid[1:0] | out | axis source id | 
| axis_tuser[1:0] | out | axis user signal | 
| axis_tready | in | axis ready | 


### caravel side axis slave
| Port | in/out | Description |
|:------:|:------:|:------------ |
| axis_tready | out | refer to above description | 
| axis_tad[31:0] | in | refer to above description | 
| axis_tstrb[3:0] | in | refer to above description | 
| axis_tkeep[3:0] | in | refer to above description | 
| axis_tlast | in | refer to above description | 
| axis_tid[1:0] | in | refer to above description | 
| axis_tvalid | in | refer to above description | 
| axis_tuser[1:0] | in | refer to above description | 

fpga side interface signal is like caravel side, but
1. without the **cc_aa_enable** in common signal.
2. additional axilite master talk to mailbox, with **axi_wremote** to indicate the transaction is from caravel or fpga side.

### fpga side axilite master (for mailbox)
| Port | in/out | Description |
|:------:|:------:|:------------ |
| axi_awvalid | out | refer to above description | 
| axi_awaddr[11:0] | out | refer to above description | 
| axi_wvalid | out | refer to above description | 
| axi_wdata[31:0] | out | refer to above description | 
| axi_wstrb[3:0] | out | refer to above description | 
| axi_arvalid | out | refer to above description | 
| axi_araddr[11:0] | out | refer to above description | 
| axi_rready | out | refer to above description | 
| **axi_wremote** | out | 1'b0: indicate data from caravel<br>1'b1: indicate data from fpga<br>take effect when axi_wvalid is 1'b1 | 
| axi_rdata[31:0] | in | refer to above description | 
| axi_awready | in | refer to above description | 
| axi_wready | in | refer to above description | 
| axi_arready | in | refer to above description | 
| axi_rvalid | in | refer to above description | 

please note we only implement a subset of axi4 lite / axi4 stream signals
1. response channel in axi4 lite is not implemented, including write / read response, thus the axilite write transaction is treated as completed without waiting.
2. protection signals awprot, arprot in axi4 lite are not implemented
3. tkeep, tstrb, tdest in axi4 stream are not implemented

## Register Description
### remap control register : ***???***
|RegisterName|Offset Address| Description |
|:----------:|:------------:| :-----------|
| remap_enable | 'h0 | enable remap at fpga side, this module will send address plus base address offset in **remap addr register** <br>1'b0: (default) remap disabled<br>1'b1: remap enabled | 

### remap addr register : ***???***
|RegisterName|Offset Address| Description |
|:----------:|:------------:| :-----------|
| remap_base_addr | 'h0 | base address for address map at fpga side. 32'h0: (default) | 

## Function Description

### Function 1:
Description of the function 1, including 
- block diagram
- Datapath flow
- Control flow
- Logic structure
- Structure component used, e.g. RAM, Shifter, State machine 

## Programming Guide
- Code illustration to control the function

## Future Work


