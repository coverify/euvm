MODEL = 64
DFLAGS = -m$(MODEL) -fPIC -g -w -O # -version=LOGPROCS # -version=UVM_NO_DEPRECATED
ESDLDIR = ../../vlang
UVMDIR = ../../vlang-uvm

DMD = dmd
OBJDIR = obj

PHOBOS = phobos2

LIBDIR = $(UVMDIR)/lib

ESDLOBJS = $(OBJDIR)/esdl/base/comm.o $(OBJDIR)/esdl/base/package.o	\
	$(OBJDIR)/esdl/base/core.o $(OBJDIR)/esdl/posix/sys/net/if_.o	\
	$(OBJDIR)/esdl/sync/barrier.o $(OBJDIR)/esdl/vcd/parse.o	\
	$(OBJDIR)/esdl/vcd/bvec.o $(OBJDIR)/esdl/package.o		\
	$(OBJDIR)/esdl/data/bstr.o $(OBJDIR)/esdl/data/sync.o		\
	$(OBJDIR)/esdl/data/packer.o $(OBJDIR)/esdl/data/package.o	\
	$(OBJDIR)/esdl/data/obdd.o $(OBJDIR)/esdl/data/bvec.o		\
	$(OBJDIR)/esdl/data/rand.o $(OBJDIR)/esdl/data/time.o		\
	$(OBJDIR)/esdl/data/queue.o $(OBJDIR)/esdl/data/cstx.o		\
	$(OBJDIR)/esdl/data/packed.o $(OBJDIR)/esdl/sys/sched.o		\
	$(OBJDIR)/esdl/sys/package.o $(OBJDIR)/esdl/intf/hal.o		\
	$(OBJDIR)/esdl/intf/systemc.o $(OBJDIR)/esdl/intf/mraa.o	\
	$(OBJDIR)/esdl/intf/vtap.o $(OBJDIR)/esdl/intf/vpi.o		\
	$(OBJDIR)/esdl/intf/fli.o $(OBJDIR)/esdl/intf/package.o		\
	$(OBJDIR)/esdl/intf/mhpi.o $(OBJDIR)/esdl/intf/vhpi.o		\
	$(OBJDIR)/unstd/casts.o $(OBJDIR)/unstd/memory/weakref.o

UVMOBJS = $(OBJDIR)/uvm/seq/uvm_sequencer_analysis_fifo.o		\
	$(OBJDIR)/uvm/seq/uvm_push_sequencer.o				\
	$(OBJDIR)/uvm/seq/uvm_sequence_item.o				\
	$(OBJDIR)/uvm/seq/package.o					\
	$(OBJDIR)/uvm/seq/uvm_sequencer_param_base.o			\
	$(OBJDIR)/uvm/seq/uvm_sequencer_base.o				\
	$(OBJDIR)/uvm/seq/uvm_sequencer.o				\
	$(OBJDIR)/uvm/seq/uvm_sequence_base.o				\
	$(OBJDIR)/uvm/seq/uvm_sequence.o				\
	$(OBJDIR)/uvm/comps/uvm_vpi_monitor.o				\
	$(OBJDIR)/uvm/comps/uvm_scoreboard.o				\
	$(OBJDIR)/uvm/comps/package.o $(OBJDIR)/uvm/comps/uvm_test.o	\
	$(OBJDIR)/uvm/comps/uvm_random_stimulus.o			\
	$(OBJDIR)/uvm/comps/uvm_push_driver.o				\
	$(OBJDIR)/uvm/comps/uvm_subscriber.o				\
	$(OBJDIR)/uvm/comps/uvm_algorithmic_comparator.o		\
	$(OBJDIR)/uvm/comps/uvm_monitor.o				\
	$(OBJDIR)/uvm/comps/uvm_env.o					\
	$(OBJDIR)/uvm/comps/uvm_driver.o				\
	$(OBJDIR)/uvm/comps/uvm_policies.o				\
	$(OBJDIR)/uvm/comps/uvm_pair.o					\
	$(OBJDIR)/uvm/comps/uvm_agent.o					\
	$(OBJDIR)/uvm/comps/uvm_in_order_comparator.o			\
	$(OBJDIR)/uvm/comps/uvm_vpi_driver.o				\
	$(OBJDIR)/uvm/base/uvm_object.o $(OBJDIR)/uvm/base/uvm_pool.o	\
	$(OBJDIR)/uvm/base/uvm_task_phase.o				\
	$(OBJDIR)/uvm/base/uvm_event_callback.o				\
	$(OBJDIR)/uvm/base/uvm_spell_chkr.o				\
	$(OBJDIR)/uvm/base/uvm_queue.o					\
	$(OBJDIR)/uvm/base/uvm_report_catcher.o				\
	$(OBJDIR)/uvm/base/uvm_resource_specializations.o		\
	$(OBJDIR)/uvm/base/uvm_callback.o				\
	$(OBJDIR)/uvm/base/uvm_runtime_phases.o				\
	$(OBJDIR)/uvm/base/uvm_tr_stream.o				\
	$(OBJDIR)/uvm/base/uvm_transaction.o				\
	$(OBJDIR)/uvm/base/uvm_array.o $(OBJDIR)/uvm/base/uvm_root.o	\
	$(OBJDIR)/uvm/base/uvm_objection.o				\
	$(OBJDIR)/uvm/base/package.o $(OBJDIR)/uvm/base/uvm_entity.o	\
	$(OBJDIR)/uvm/base/uvm_domain.o					\
	$(OBJDIR)/uvm/base/uvm_config_db.o				\
	$(OBJDIR)/uvm/base/uvm_message_defines.o			\
	$(OBJDIR)/uvm/base/uvm_comparer.o				\
	$(OBJDIR)/uvm/base/uvm_phase.o					\
	$(OBJDIR)/uvm/base/uvm_globals.o				\
	$(OBJDIR)/uvm/base/uvm_report_server.o				\
	$(OBJDIR)/uvm/base/uvm_traversal.o				\
	$(OBJDIR)/uvm/base/uvm_topdown_phase.o				\
	$(OBJDIR)/uvm/base/uvm_factory.o				\
	$(OBJDIR)/uvm/base/uvm_cmdline_processor.o			\
	$(OBJDIR)/uvm/base/uvm_tr_database.o				\
	$(OBJDIR)/uvm/base/uvm_port_base.o				\
	$(OBJDIR)/uvm/base/uvm_printer.o				\
	$(OBJDIR)/uvm/base/uvm_misc.o					\
	$(OBJDIR)/uvm/base/uvm_recorder.o				\
	$(OBJDIR)/uvm/base/uvm_component.o				\
	$(OBJDIR)/uvm/base/uvm_links.o					\
	$(OBJDIR)/uvm/base/uvm_registry.o				\
	$(OBJDIR)/uvm/base/uvm_barrier.o				\
	$(OBJDIR)/uvm/base/uvm_resource_db.o				\
	$(OBJDIR)/uvm/base/uvm_report_object.o				\
	$(OBJDIR)/uvm/base/uvm_report_message.o				\
	$(OBJDIR)/uvm/base/uvm_bottomup_phase.o				\
	$(OBJDIR)/uvm/base/uvm_object_globals.o				\
	$(OBJDIR)/uvm/base/uvm_report_handler.o				\
	$(OBJDIR)/uvm/base/uvm_object_defines.o				\
	$(OBJDIR)/uvm/base/uvm_packer.o					\
	$(OBJDIR)/uvm/base/uvm_coreservice.o				\
	$(OBJDIR)/uvm/base/uvm_version.o				\
	$(OBJDIR)/uvm/base/uvm_global_defines.o				\
	$(OBJDIR)/uvm/base/uvm_once.o					\
	$(OBJDIR)/uvm/base/uvm_heartbeat.o				\
	$(OBJDIR)/uvm/base/uvm_resource.o				\
	$(OBJDIR)/uvm/base/uvm_event.o					\
	$(OBJDIR)/uvm/base/uvm_common_phases.o				\
	$(OBJDIR)/uvm/meta/mcd.o $(OBJDIR)/uvm/meta/meta.o		\
	$(OBJDIR)/uvm/meta/misc.o $(OBJDIR)/uvm/meta/mailbox.o		\
	$(OBJDIR)/uvm/reg/uvm_reg_file.o $(OBJDIR)/uvm/reg/uvm_vreg.o	\
	$(OBJDIR)/uvm/reg/uvm_reg_block.o				\
	$(OBJDIR)/uvm/reg/uvm_reg_map.o					\
	$(OBJDIR)/uvm/reg/uvm_reg_sequence.o				\
	$(OBJDIR)/uvm/reg/uvm_mem_mam.o $(OBJDIR)/uvm/reg/uvm_reg.o	\
	$(OBJDIR)/uvm/reg/uvm_reg_backdoor.o				\
	$(OBJDIR)/uvm/reg/uvm_vreg_field.o				\
	$(OBJDIR)/uvm/reg/uvm_reg_defines.o				\
	$(OBJDIR)/uvm/reg/uvm_mem.o $(OBJDIR)/uvm/reg/package.o		\
	$(OBJDIR)/uvm/reg/uvm_reg_cbs.o					\
	$(OBJDIR)/uvm/reg/uvm_reg_adapter.o				\
	$(OBJDIR)/uvm/reg/uvm_reg_field.o				\
	$(OBJDIR)/uvm/reg/uvm_reg_item.o				\
	$(OBJDIR)/uvm/reg/uvm_reg_model.o $(OBJDIR)/uvm/dap/package.o	\
	$(OBJDIR)/uvm/dap/uvm_get_to_lock_dap.o				\
	$(OBJDIR)/uvm/dap/uvm_simple_lock_dap.o				\
	$(OBJDIR)/uvm/dap/uvm_set_get_dap_base.o			\
	$(OBJDIR)/uvm/dap/uvm_set_before_get_dap.o			\
	$(OBJDIR)/uvm/package.o $(OBJDIR)/uvm/tlm2/uvm_tlm2_imps.o	\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_exports.o				\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_defines.o				\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_generic_payload.o			\
	$(OBJDIR)/uvm/tlm2/package.o					\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_sockets.o				\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_sockets_base.o			\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_ifs.o				\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_time.o				\
	$(OBJDIR)/uvm/tlm2/uvm_tlm2_ports.o				\
	$(OBJDIR)/uvm/dpi/package.o $(OBJDIR)/uvm/dpi/uvm_hdl.o		\
	$(OBJDIR)/uvm/dpi/uvm_svcmd_dpi.o $(OBJDIR)/uvm/vpi/package.o	\
	$(OBJDIR)/uvm/vpi/uvm_vpi_intf.o				\
	$(OBJDIR)/uvm/tlm1/uvm_sqr_ifs.o				\
	$(OBJDIR)/uvm/tlm1/uvm_tlm_imps.o				\
	$(OBJDIR)/uvm/tlm1/package.o					\
	$(OBJDIR)/uvm/tlm1/uvm_tlm_req_rsp.o				\
	$(OBJDIR)/uvm/tlm1/uvm_tlm_defines.o				\
	$(OBJDIR)/uvm/tlm1/uvm_tlm_fifo_base.o				\
	$(OBJDIR)/uvm/tlm1/uvm_ports.o					\
	$(OBJDIR)/uvm/tlm1/uvm_tlm_fifos.o				\
	$(OBJDIR)/uvm/tlm1/uvm_tlm_gen_rsp.o				\
	$(OBJDIR)/uvm/tlm1/uvm_imps.o					\
	$(OBJDIR)/uvm/tlm1/uvm_analysis_port.o				\
	$(OBJDIR)/uvm/tlm1/uvm_exports.o				\
	$(OBJDIR)/uvm/tlm1/uvm_sqr_connections.o			\
	$(OBJDIR)/uvm/tlm1/uvm_tlm_ifs.o


all: libs libs-ldc

libs-ldc: libesdl-ldc libuvm-ldc

libesdl-ldc:
	make DMD=ldmd2 OBJDIR=obj-ldc PHOBOS=phobos2-ldc libesdl-ldc.so

libuvm-ldc:
	make DMD=ldmd2 OBJDIR=obj-ldc PHOBOS=phobos2-ldc libuvm-ldc.so

libs: libesdl.so libuvm.so

clean:
	rm -rf lib*.o lib*.so obj obj-ldc

$(OBJDIR)/esdl/%.o: ../../vlang/src/esdl/%.d
	$(DMD) -c $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

$(OBJDIR)/unstd/%.o: ../../vlang/src/unstd/%.d
	$(DMD) -c $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

$(OBJDIR)/uvm/%.o: ../src/uvm/%.d
	$(DMD) -c $(DFLAGS) -of$@ -I$(ESDLDIR)/src -I$(UVMDIR)/src $^

libesdl-ldc.so: $(ESDLOBJS)
	$(DMD) -shared $(DFLAGS) -of$@ -L-l$(PHOBOS) -I$(ESDLDIR)/src $^

libuvm-ldc.so: $(UVMOBJS)
	$(DMD) -shared $(DFLAGS) -of$@ -L-l$(PHOBOS) -I$(UVMDIR)/src -I$(ESDLDIR)/src $^

libesdl.so: $(ESDLOBJS)
	$(DMD) -shared $(DFLAGS) -of$@ -L-l$(PHOBOS) -I$(ESDLDIR)/src $^

libuvm.so: $(UVMOBJS)
	$(DMD) -shared $(DFLAGS) -of$@ -L-l$(PHOBOS) -I$(UVMDIR)/src -I$(ESDLDIR)/src $^
