OUTBIN=./simv

hpu:
	vlogan -full64 +v2k +cli -kdb -lca +lint=TFIPC-L +vcs+initreg+random +define+TSMC_CM_UNIT_DELAY \
		+define+UNIT_DELAY +define+TSMC_INITIALIZE_MEM -override_timescale=1ns/1ps -sverilog \
		+vcs+loopreport +incdir+${PRJ_HOME}/rtl/inc \
		+incdir+${SYN_HOME}/dw/sim_ver \
		-y ${SYN_HOME}/dw/sim_ver +libext+.v \
		-f ${PRJ_HOME}/rtl/filelist.lst \
		-f ${PRJ_HOME}/simulation/filelists/hpu_ram.flist \
		-f ${PRJ_HOME}/simulation/filelists/hpu_tb.flist \
		-l compile_hpu200.log

	vcs -o hpu.simv -debug_all +memcbk +vcs+dumparrays -full64 -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed \
		-fsdb -debug_access+cbk -top hpu_tb +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-y ${MEM_SYN_LIB} -l elaborate_hpu.log


batch_hpu:
	vlogan -full64 +v2k +cli -kdb -lca +lint=TFIPC-L +vcs+initreg+random +define+TSMC_CM_UNIT_DELAY \
		-cm line+branch+cond+tgl+fsm+assert \
		+define+UNIT_DELAY +define+TSMC_INITIALIZE_MEM +define+V_BATCH -override_timescale=1ns/1ps -sverilog \
		+vcs+loopreport +incdir+${PRJ_HOME}/rtl/inc \
		+incdir+${SYN_HOME}/dw/sim_ver \
		-y ${SYN_HOME}/dw/sim_ver +libext+.v \
		-f ${PRJ_HOME}/rtl/filelist.lst \
		-f ${PRJ_HOME}/simulation/filelists/hpu_ram.flist \
		-f ${PRJ_HOME}/simulation/filelists/hpu_tb.flist \
		-l compile_hpu200.log

	vcs -o batch_hpu.simv -debug_all +memcbk +vcs+dumparrays -full64 -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed \
		-cm line+branch+cond+tgl+fsm+assert \
		-fsdb -debug_access+cbk -top hpu_tb +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-y ${MEM_SYN_LIB} -l elaborate_hpu.log


vmu:
	vlogan -full64 +v2k -sverilog +cli -kdb -lca +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-override_timescale=1ns/1ps \
		+define+TSMC_CM_UNIT_DELAY +define+UNIT_DELAY +define+TSMC_INITIALIZE_MEM \
		+incdir+${PRJ_HOME}/rtl/inc \
		+incdir+${SYN_HOME}/dw/sim_ver \
		-y ${SYN_HOME}/dw/sim_ver +libext+.v \
		-f ${PRJ_HOME}/rtl/filelist.lst \
		-f ${PRJ_HOME}/simulation/filelists/hpu_ram.flist \
		-f ${PRJ_HOME}/simulation/filelists/vmu_tb.flist \
		-l compile_vmu.log

	vcs -full64 +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed \
		-debug_all +memcbk +vcs+dumparrays \
		-fsdb -debug_access+cbk -top hpu_tb \
		-y ${MEM_SYN_LIB} \
		-o hpu_v.simv \
		-l elaborate_vmu.log


batch_vmu:
	vlogan -full64 +v2k -sverilog +cli -kdb -lca +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-cm line+branch+cond+tgl+fsm+assert \
		-override_timescale=1ns/1ps \
		+define+TSMC_CM_UNIT_DELAY +define+UNIT_DELAY +define+TSMC_INITIALIZE_MEM +define+V_BATCH \
		+incdir+${PRJ_HOME}/rtl/inc \
		+incdir+${SYN_HOME}/dw/sim_ver \
		-y ${SYN_HOME}/dw/sim_ver +libext+.v \
		-f ${PRJ_HOME}/rtl/filelist.lst \
		-f ${PRJ_HOME}/simulation/filelists/hpu_ram.flist \
		-f ${PRJ_HOME}/simulation/filelists/vmu_tb.flist \
		-l compile_vmu.log

	vcs -full64 +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-cm line+branch+cond+tgl+fsm+assert \
		-cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed \
		-debug_all +memcbk +vcs+dumparrays \
		-fsdb -debug_access+cbk -top hpu_tb \
		-y ${MEM_SYN_LIB} \
		-o batch_hpu_v.simv \
		-l elaborate_vmu.log


debug:
	vlogan -full64 +v2k +cli -kdb -lca +lint=TFIPC-L +vcs+initreg+random +define+TSMC_CM_UNIT_DELAY \
		+define+UNIT_DELAY +define+TSMC_INITIALIZE_MEM -override_timescale=1ns/1ps -sverilog \
		+vcs+loopreport +incdir+${PRJ_HOME}/rtl/inc \
		+incdir+${SYN_HOME}/dw/sim_ver \
		-y ${SYN_HOME}/dw/sim_ver +libext+.v \
		-f ${PRJ_HOME}/rtl/filelist.lst \
		-f ${PRJ_HOME}/rtl/src/debug/filelist_sv.lst \
		-f ${PRJ_HOME}/simulation/filelists/hpu_ram.flist \
		-f ${PRJ_HOME}/simulation/filelists/hpu_debug_tb.flist \
		-l compile_hpu200_debug.log

	vcs -o hpu_d.simv -debug_all +memcbk +vcs+dumparrays -full64 -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed \
		-fsdb -debug_access+cbk -top hpu_debug_tb +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-y ${MEM_SYN_LIB} -l elaborate_hpu.log


batch_debug:
	vlogan -full64 +v2k +cli -kdb -lca +lint=TFIPC-L +vcs+initreg+random +define+TSMC_CM_UNIT_DELAY \
		-cm line+branch+cond+tgl+fsm+assert \
		+define+UNIT_DELAY +define+TSMC_INITIALIZE_MEM +define+V_BATCH -override_timescale=1ns/1ps -sverilog \
		+vcs+loopreport +incdir+${PRJ_HOME}/rtl/inc \
		+incdir+${SYN_HOME}/dw/sim_ver \
		-y ${SYN_HOME}/dw/sim_ver +libext+.v \
		-f ${PRJ_HOME}/rtl/filelist.lst \
		-f ${PRJ_HOME}/rtl/src/debug/filelist_sv.lst \
		-f ${PRJ_HOME}/simulation/filelists/hpu_ram.flist \
		-f ${PRJ_HOME}/simulation/filelists/hpu_debug_tb.flist \
		-l compile_hpu200.log

	vcs -o batch_hpu_d.simv -debug_all +memcbk +vcs+dumparrays -full64 -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed \
		-cm line+branch+cond+tgl+fsm+assert \
		-fsdb -debug_access+cbk -top hpu_debug_tb +lint=TFIPC-L +vcs+initreg+random +vcs+loopreport \
		-y ${MEM_SYN_LIB} -l elaborate_hpu.log

run:
	./hpu.simv +vcs+initreg+0 -gui -do run.do -l run.log

batch_run:
	./batch_hpu.simv -cm line+branch+cond+tgl+fsm+assert -cm_dir batch_hpu.simv.vdb -ucli -do batch_run.do -l run.log

run_v:
	./hpu_v.simv +vcs+initreg+0 -gui -do run.do -l run.log

batch_run_v:
	./batch_hpu_v.simv -cm line+branch+cond+tgl+fsm+assert -cm_dir batch_hpu_v.simv.vdb -ucli -do batch_run.do -l run.log

verdi:
	verdi  nWave  -top hpu_tb -f -macrodebug -sverilog +incdir+${PRJ_HOME}/rtl/inc -f ${PRJ_HOME}/rtl/filelist.lst -f ${PRJ_HOME}/simulation/filelists/hpu_ram.flist -f ${PRJ_HOME}/simulation/filelists/hpu_tb.flist -workMode hardwareDebug -ssf hpu.fsdb 

clean :

	@rm -rf ucli.key *.simv *.simv.*  DVEfiles csrc inter.vpd hpu.fsdb
	@rm -rf dump* verdi* run.log runext compile*log  elab*log
	@rm -rf work.lib++
	@rm -rf novas*
	@rm -rf 64 AN.DB
 
.PHONY: $(OUTBIN)

