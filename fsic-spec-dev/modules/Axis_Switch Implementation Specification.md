# Axis_Switch Implementation Specification

There are two data flow directions of AXI stream. 
- **Upstream**: data flows from Caravel to FPGA/Memory
- **Downstream**: data flows from FPGA/Memory to Caravel

The possible data producers and consumers include
- User Project (in Caravel)
- Extended User Project (in FPGA)
- Logic Analyzer (in Caravel)
- Axilite-Axis (in both Caravel, FPGA)
- AxiDMA (in FPGA)

The following is Switch port mapping for both upstream and downstream data flow.
![Switch port mapping](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/3d748dc1-cfcb-4f61-8e0c-d5fce98d38bd)



From above we can conclude:
1. The Switch supports: 3 ports (s0, s1, s2) in Caravel and 3 ports (m0, m1, m2) in FPGA.
2. The routing path of Axi stream is decoded by TID. Axis_switch module will determine the routing path of upstream and downstream seperately according to the TID information of Axi stream,as shown in the following table.  
3. According to the definition of FSIC-AXIS interface specification, AXIS source module and AXIS destination module of Upstream/Downstream are one-to-one mapping. Therefore, all data producers and consumers connected to AXIS_Switch module do not need to provide TID information, AXIS_Switch module can transmit data stream To the correct destination. These data producers and consumers can omit the TID signals. It is only necessary for the AXIS_Switch module to provide the TID information when the data producer receives the data stream, and then send it to the AXIS_Switch module at the other side via the IO_Serdes. After AXIS_Switch module decoding the TID signals, the data stream is sent to the correct data consumer. Therefore, only the interface with IO_Serdes needs to provide TID signals.

| Direction | TID[1:0] | Source Module | Destination Module |
|:------:|:------:|:------------ |:--------|
|Downstream|  00  |User DMA (M_AXIS_MM2S) in remote host (option extended user project)	|User Project - the current active user project|
|Downstream|  01  |Axilite Master R/W in remote host (include Mail box write)	|Axis-Axilite (include Mail box)|
|Upstream  |  00  |User Project - the current active user project |User DMA (S_AXIS_S2MM) in remote host (option extended user project)|
|Upstream  |  01  |Axis-Axilite (for Mail box)	|Axilite slave in remote host (for mail box write)|
|Upstream  |  10  |Logic Analyzer|	Logic Analyzer data receiver - DMA (S_AXIS_S2MM) in remote host|


## ==Interface Blocks==
The following diagrams are that the interconnections of Axis_Switch with the other modules seperately on Caravel side and FPGA side.
<br><br>
![01](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/75cd3365-de36-4a70-86d3-f6283f3a3a8b)
<br><br><br>
![02](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/09464edc-cbf5-48ee-a7dd-1cae79bab2ab)



## ==Feature Lists==
List of functions and features
1. Round Robin Arbitrator for multi axis transmitters
2. Demultiplexer with TID for multi axis receivers

## ==Interface Signals==
## 1. Caravel side
* ### Common signal

| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|  clk   |  in   | clock        |1|
| rst_n  |  in   | reset is active low |1         |

* ### Axi stream interface with Axilite_Axis module 
#### Output stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid  | out | It indicates the Transmitter is driving a valid transfer. A transfer takes place when both TVALID and TREADY are asserted. |1|
|axis_tready  | in | It indicates that a Receiver can accept a transfer. |1|
|axis_tdata| out | It is the primary payload used to provide the data that is passing across the interface.|32|
|axis_tstrb| out | It is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte. |4|
|axis_tkeep| out | This signal will be bypassed. It is the byte qualifier that indicates whether content of the associated byte of TDATA is processed as part of the data stream. |4|
|axis_tlast| out | It indicates the boundary of a packet. |1|
|axis_tuser| out | It is a user-defined sideband information that distinguish different transaction types along the data stream. Please see the definition of FSIC-AXIS interface specification.|2|
#### Input stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | in  | Please see the above description. |1|
|axis_tready | out | Please see the above description. |1|
|axis_tdata  | in  | Please see the above description. |32|
|axis_tstrb  | in  | Please see the above description. |4|
|axis_tkeep  | in  | Please see the above description. |4|
|axis_tlast  | in  | Please see the above description. |1|
|axis_tuser  | in  | Please see the above description. |2|

* ### Axi stream interface with with Logic Analyzer 
#### Input stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | in  | Please see the above description. |1|
|axis_tready | out | Please see the above description. |1|
|axis_tdata  | in  | Please see the above description. |32|
|axis_tstrb  | in  | Please see the above description. |4|
|axis_tkeep  | in  | Please see the above description. |4|
|axis_tlast  | in  | Please see the above description. |1|
|axis_tuser  | in  | Please see the above description. |2|
#### Sideband signal
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|la_hpri_req | in  | Rising the service priority of data stream from Logic Analyzer. |1|

* ### Axi stream interface with User Project 
#### Output stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | out | Please see the above description. |1|
|axis_tready | in  | Please see the above description. |1|
|axis_tdata  | out | Please see the above description. |32|
|axis_tstrb  | out | Please see the above description. |4|
|axis_tkeep  | out | Please see the above description. |4|
|axis_tlast  | out | Please see the above description. |1|
|axis_tuser  | out | Please see the above description. |2|
#### Input stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | in  | Please see the above description. |1|
|axis_tready | out | Please see the above description. |1|
|axis_tdata  | in  | Please see the above description. |32|
|axis_tstrb  | in  | Please see the above description. |4|
|axis_tkeep  | in  | Please see the above description. |4|
|axis_tlast  | in  | Please see the above description. |1|
|axis_tuser  | in  | Please see the above description. |2|
#### Sideband signal
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|up_hpri_req | in  | Rising the service priority of data stream from User Project. |1|

* ### Axi stream interface with IO_serdes 
#### Output stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | out | Please see the above description. |1|
|axis_tready | in  | Please see the above description. |1|
|axis_tdata  | out | Please see the above description. |32|
|axis_tstrb  | out | Please see the above description. |4|
|axis_tkeep  | out | Please see the above description. |4|
|axis_tlast  | out | Please see the above description. |1|
|axis_tid    | out | It is the source of data stream identifier. |2|
|axis_tuser  | out | Please see the above description. |2|
#### Input stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | in  | Please see the above description. |1|
|axis_tready | out | Please see the above description. |1|
|axis_tdata  | in  | Please see the above description. |32|
|axis_tstrb  | in  | Please see the above description. |4|
|axis_tkeep  | in  | Please see the above description. |4|
|axis_tlast  | in  | Please see the above description. |1|
|axis_tid    | in  | It is the source of data stream identifier. |2|
|axis_tuser  | in  | Please see the above description. |2|

## 2. FPGA side
* ### Common signal

| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|  clk   |  in   | clock        |1|
| rst_n  |  in   | reset is active low |1         |

* ### Axi stream interface with Axilite_Axis module 
#### Output stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | out | Please see the above description. |1|
|axis_tready | in  | Please see the above description. |1|
|axis_tdata  | out | Please see the above description. |32|
|axis_tstrb  | out | Please see the above description. |4|
|axis_tkeep  | out | Please see the above description. |4|
|axis_tlast  | out | Please see the above description. |1|
|axis_tuser  | out | Please see the above description. |2|
#### Input stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | in  | Please see the above description. |1|
|axis_tready | out | Please see the above description. |1|
|axis_tdata  | in  | Please see the above description. |32|
|axis_tstrb  | in  | Please see the above description. |4|
|axis_tkeep  | in  | Please see the above description. |4|
|axis_tlast  | in  | Please see the above description. |1|
|axis_tuser  | in  | Please see the above description. |2|

* ### Axi stream interface with AxiDMA
#### Output stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | out | Please see the above description. |1|
|axis_tready | in  | Please see the above description. |1|
|axis_tdata  | out | Please see the above description. |32|
|axis_tstrb  | out | Please see the above description. |4|
|axis_tkeep  | out | Please see the above description. |4|
|axis_tlast  | out | Please see the above description. |1|
|axis_tuser  | out | Please see the above description. |2|

* ### Axi stream interface with User DMA (either AxiDMA or Extended User Project)
#### Output stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | out | Please see the above description. |1|
|axis_tready | in  | Please see the above description. |1|
|axis_tdata  | out | Please see the above description. |32|
|axis_tstrb  | out | Please see the above description. |4|
|axis_tkeep  | out | Please see the above description. |4|
|axis_tlast  | out | Please see the above description. |1|
|axis_tuser  | out | Please see the above description. |2|
#### Input stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | in  | Please see the above description. |1|
|axis_tready | out | Please see the above description. |1|
|axis_tdata  | in  | Please see the above description. |32|
|axis_tstrb  | in  | Please see the above description. |4|
|axis_tkeep  | in  | Please see the above description. |4|
|axis_tlast  | in  | Please see the above description. |1|
|axis_tuser  | in  | Please see the above description. |2|

* ### Axi stream interface with IO_serdes 
#### Output stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | out | Please see the above description. |1|
|axis_tready | in  | Please see the above description. |1|
|axis_tdata  | out | Please see the above description. |32|
|axis_tstrb  | out | Please see the above description. |4|
|axis_tkeep  | out | Please see the above description. |4|
|axis_tlast  | out | Please see the above description. |1|
|axis_tid    | out | It is the source of data stream identifier. |2|
|axis_tuser  | out | Please see the above description. |2|
#### Input stream
| Port | in/out | Descriptiion | width |
|:------:|:------:|:------------ |:--------|
|axis_tvalid | in  | Please see the above description. |1|
|axis_tready | out | Please see the above description. |1|
|axis_tdata  | in  | Please see the above description. |32|
|axis_tstrb  | in  | Please see the above description. |4|
|axis_tkeep  | in  | Please see the above description. |4|
|axis_tlast  | in  | Please see the above description. |1|
|axis_tid    | in  | It is the source of data stream identifier. |2|
|axis_tuser  | in  | Please see the above description. |2|

## ==Function Description==

1. ### Round Robin Arbitrator:
![03](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/6b5f9525-93da-43ad-8201-8c1e13b6933a)
![04](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/a51fd1d6-67ca-41ed-9ab2-779f128b83dc)
* Apply round-robin arbitration
* Provide sideband signal connected with Logic Analyzer and User Project for high priority requests. For example, Logic Analyzer needs to pull the xx_hpri_req signal high to reduce the waiting time when its FIFO is almost full. When Axis_Switch module accept and process the high-priority request if the xx_hpri_req signal asserted, Axis_Switch module just accept other pending requests when xx_hpri_req signal desserted.

2. ### Demultiplexer with TID:
![05](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/5cb60ecb-a475-4aec-88b3-70fc075b2955)
![06](https://github.com/bol-edu/fsic-spec-dev/assets/98332019/58c5e6c7-aea1-4599-9c4e-2d7957034749)

* The Axis_Switch module of the destination side of Axi stream will use the TID information to dispatch the transaction to the corresponding receiver. 

## Programming Guide

## Future Work

## Reference
[]


