# IO_Serdes Implementation Specification
The purpose of this module is to virtually increase the number of IO pins by ratioing the core clock and io clock. In the following diagram, there are m* core signals to IO, and there are n * io pins. To match its throughput, it needs to meet the equation, **m x core_clk = n x io_clk**. For example, if there are only 16 IO pins available for interconnetion between Caravel and FPGA, and the clock ratio m/n = 10, i.e. IO runs at 50Mhz, and core runs at 5Mhz. We virtual have 160 IO pins available. 

![](https://i.imgur.com/BhmuNDY.png)


In designing IO_Serdes, one design issue is that both Caravel and FPGA chip needs to agree on a common phase. The IO_Serdes is implemented by shifters and muxes. Both transmission and receiving sides need to agree on a common phase states, i.e. counter value for the mux select. The initialization is done right after Caravel chip comes out reset state by sending a intialization patterns. After the initialization phase, both side runs synchronously afterward, until Caravel chip reset again. 

## Brief Explanation about the module function


### clk and rst tree balance

![01](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/d1369c41-20ae-4724-be96-f43f0beffb93)



### IO_Delay
The delay from transmiter output pad to receiver input pad introduce larger delay. It is hard to control the IO delay, thus, a parameter io_delay (in unit of io_clk) is introduced. The IO data is received into a IO_FIFO, the parameter io_delay is the offset between the transmit and receive pointer. 

### IO to core (Core_Delay)
The serial data from the IO_FIFO is first shifted into a one of the two set of 8-bit shifters. The parameter core_delay is to control how to transfer from io_clk domain to core_clk domain. 

core_delay = 0, is to directly transfer the current shifter content to parallel core data. This will suffer some input delay. The delay is estimated between io_delay to io_delay + 1.

core_delay = 1, is to synchronize by core_clk before it is available.
The following timing shows the timing sequence for the case io_delay = 2, core_delay = 0.
![02](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/6ca9b3bc-c5c1-4ba6-bcd3-a7cfc8259268)


#### add delay by delay-element ot constrain parameter in FPGA?

![03](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/05b2d7e6-4021-4380-8392-e653e2aaba60)
#### The delay from transmiter output pad to receiver input pad timing.
- Caravel to Remote Host


use set_input_delay in FPGA(remote host)

![04](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/5c98fd08-8969-4c7f-89c9-1193ef82e8bf)
    - reference https://blog.csdn.net/aaaaaaaa585/article/details/118859268
- Remote Host to Caravel

![05](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/f623bcdf-eaca-4f46-a03e-5761803fa24f)
    - reference https://blog.csdn.net/aaaaaaaa585/article/details/118862049



#### rst not balance cause core_clk not sync

![06](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/e92db60e-8747-4b10-9bd9-80b618458393)

#### add a counter to delay the rst for Divider
![07](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/8517223d-ef2b-4acc-999b-792e3dac5103)

#### add core_clk_count to counter the core_clk from 0 to 3

- io_clk = 4*Core_clk
- Tx send data start from core_clk_count = 0
- Rx received data from core_clk_count = 2 when (core_delay=1 and io_delay=2)

## Interface Blocks
Block diagram shows its interconnected module

## Feature Lists
List of functions and features
1. Feature#1
2. Feature#2

## Interface Signals

TX/RX need 47 (47 < 48 = 12*4) signals and use 12 pins for each direction.

| Port | in/out | Descriptiion |
|:------:|:------:|:------------ |
|??_is_axis_clk_i|	In	|axis clock Input|
|??_is_axis_rst_i|	In	|axis reset Input|
|??_is_io_clk_i	1|	In	|io clock|
| rst_n |   in   | reset is active low        |
|as_is_axis_tvalid_i	|In	|as to is Valid			|
|as_is_axis_tready_o	|Out	|as to is Ready			|
|as_is_axis_tdata_i[32]	|In	|as to is Data			|
|as_is_axis_tstrb_i[4]	|In	|as to is Strobe			|
|as_is_axis_tkeep_i[4]	|In	|as to is Keep			|
|as_is_axis_tlast_i	|In	|as to is Last			|
|as_is_axis_tid_i[2]	|In	|as to is Source ID			|
|as_is_axis_tuser_i[2]	|In	|as to is User Siginal			|
|is_as_axis_tvalid_o	|Out|	is to as Valid			|
|is_as_axis_tready_i	|In	|is to as Ready			|
|is_as_axis_tdata_o[32]	|Out	|is to as Data			|
|is_as_axis_tstrb_o[4]	|Out	|is to as Strobe			|
|is_as_axis_tkeep_o[4]	|Out	|is to as Keep			|
|is_as_axis_tlast_o	|Out	|is to as Last			|
|is_as_axis_tid_o[2]	|Out	|is to as Source ID			|
|is_as_axis_tuser_o[2]	|Out	|is to as User Siginal			|
|is_mprj_tx[12]|Out | is to mprj_io TX|
|mprj_is_rx[12]|In | mprj_io to is RX|

## Register Description
A table shows register definitions
### Register Group Name : Based Address

|RegisterName|Offset Address| Description |
|:----------:|:------------:| :-----------|
|Control     |'h0             | Control Register block Definition<br>bit 0: bit 0 function<br>bit 1: bit 1 function<br>bit 2: bit 2 function is<br>bit 3: bit 3 function |
|Status      | 'h4          | Status register block definition<br>bit 0: bit 0 status is<br>bit 1: bit 1 interrupt status|

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


