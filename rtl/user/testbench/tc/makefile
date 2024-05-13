.PHONY: basic

# for run basic simulation without edge detection
basic:
	xvlog -sv -i ../ ../tb_fsic.v -f filelist \
      -d USE_skywater_SRAM \
      -d USER_PROJECT_SIDEBAND_SUPPORT 
	xelab tb_fsic -debug typical --snapshot tb_fsic_xelab --timescale 1ns/1ns
	xsim tb_fsic_xelab --tclbatch log_wave.tcl
	mv xvlog.log xvlog.basic.log
	mv xelab.log xelab.basic.log
	mv xsim.log xsim.basic.log

.PHONY: edge
# for run edge detection simulation
edge:
	xvlog -sv -i ../ ../tb_fsic.v -f filelist \
      -d USE_skywater_SRAM \
      -d USE_EDGEDETECT_IP \
      -d USER_PROJECT_SIDEBAND_SUPPORT 
	xelab tb_fsic -debug typical --snapshot tb_fsic_xelab --timescale 1ns/1ns
	xsim tb_fsic_xelab --tclbatch log_wave.tcl
	mv xvlog.log xvlog.edge.log
	mv xelab.log xelab.edge.log
	mv xsim.log xsim.edge.log

.PHONY: all
all : basic edge

.PHONY: clean
clean:	
	- rm *.log *.jou *.wdb
	- rm -rf xsim.dir

.PHONY: cleanall
cleanall : clean all

