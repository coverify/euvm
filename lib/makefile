MODEL = 64
DEBUG = dummy
VERSION = dummy
DFLAGS = -m$(MODEL) -version=$(VERSION) -debug=$(DEBUG) # -g
ESDLDIR = ../../vlang
UVMDIR = ../../vlang-uvm

DMD = ldmd2
PICOBJDIR = picobj-ldc
OBJDIR = obj-ldc

PHOBOS = phobos2-ldc-shared

LIBDIR = $(UVMDIR)/lib

ESDLOBJS = esdl/base/comm.o esdl/base/package.o esdl/base/core.o	\
	esdl/posix/sys/net/if_.o esdl/sync/barrier.o esdl/vcd/parse.o	\
	esdl/vcd/bvec.o esdl/package.o esdl/data/bstr.o			\
	esdl/data/sync.o esdl/data/packer.o esdl/data/package.o		\
	esdl/data/bvec.o esdl/data/time.o esdl/data/queue.o		\
	esdl/data/packed.o esdl/data/cover.o esdl/rand/base.o		\
	esdl/rand/expr.o esdl/rand/obdd.o esdl/rand/package.o		\
	esdl/rand/solver.o esdl/rand/cstx.o esdl/rand/meta.o		\
	esdl/rand/objx.o esdl/rand/vecx.o esdl/sys/sched.o		\
	esdl/sys/package.o esdl/intf/hal.o esdl/intf/systemc.o		\
	esdl/intf/mraa.o esdl/intf/vtap.o esdl/intf/vpi.o		\
	esdl/intf/fli.o esdl/intf/package.o esdl/intf/mhpi.o		\
	esdl/intf/vhpi.o # unstd/casts.o unstd/memory/weakref.o

UVMOBJS = uvm/seq/uvm_sequencer_analysis_fifo.o				\
	uvm/seq/uvm_push_sequencer.o uvm/seq/uvm_sequence_item.o	\
	uvm/seq/package.o uvm/seq/uvm_sequencer_param_base.o		\
	uvm/seq/uvm_sequencer_base.o uvm/seq/uvm_sequencer.o		\
	uvm/seq/uvm_sequence_base.o uvm/seq/uvm_sequence.o		\
	uvm/comps/uvm_vpi_monitor.o uvm/comps/uvm_scoreboard.o		\
	uvm/comps/package.o uvm/comps/uvm_test.o			\
	uvm/comps/uvm_random_stimulus.o uvm/comps/uvm_push_driver.o	\
	uvm/comps/uvm_subscriber.o					\
	uvm/comps/uvm_algorithmic_comparator.o				\
	uvm/comps/uvm_monitor.o uvm/comps/uvm_env.o			\
	uvm/comps/uvm_driver.o uvm/comps/uvm_policies.o			\
	uvm/comps/uvm_pair.o uvm/comps/uvm_agent.o			\
	uvm/comps/uvm_in_order_comparator.o				\
	uvm/comps/uvm_vpi_driver.o uvm/base/uvm_async_lock.o		\
	uvm/base/uvm_object.o uvm/base/uvm_pool.o			\
	uvm/base/uvm_task_phase.o uvm/base/uvm_event_callback.o		\
	uvm/base/uvm_spell_chkr.o uvm/base/uvm_queue.o			\
	uvm/base/uvm_report_catcher.o					\
	uvm/base/uvm_resource_specializations.o				\
	uvm/base/uvm_callback.o uvm/base/uvm_runtime_phases.o		\
	uvm/base/uvm_tr_stream.o uvm/base/uvm_transaction.o		\
	uvm/base/uvm_array.o uvm/base/uvm_root.o			\
	uvm/base/uvm_objection.o uvm/base/package.o			\
	uvm/base/uvm_entity.o uvm/base/uvm_domain.o			\
	uvm/base/uvm_config_db.o uvm/base/uvm_message_defines.o		\
	uvm/base/uvm_comparer.o uvm/base/uvm_phase.o			\
	uvm/base/uvm_globals.o uvm/base/uvm_report_server.o		\
	uvm/base/uvm_traversal.o uvm/base/uvm_topdown_phase.o		\
	uvm/base/uvm_factory.o uvm/base/uvm_cmdline_processor.o		\
	uvm/base/uvm_tr_database.o uvm/base/uvm_port_base.o		\
	uvm/base/uvm_printer.o uvm/base/uvm_misc.o			\
	uvm/base/uvm_recorder.o uvm/base/uvm_component.o		\
	uvm/base/uvm_links.o uvm/base/uvm_registry.o			\
	uvm/base/uvm_barrier.o uvm/base/uvm_resource_db.o		\
	uvm/base/uvm_report_object.o uvm/base/uvm_report_message.o	\
	uvm/base/uvm_bottomup_phase.o uvm/base/uvm_object_globals.o	\
	uvm/base/uvm_report_handler.o uvm/base/uvm_object_defines.o	\
	uvm/base/uvm_packer.o uvm/base/uvm_coreservice.o		\
	uvm/base/uvm_version.o uvm/base/uvm_global_defines.o		\
	uvm/base/uvm_once.o uvm/base/uvm_heartbeat.o			\
	uvm/base/uvm_resource.o uvm/base/uvm_event.o			\
	uvm/base/uvm_common_phases.o uvm/meta/mcd.o uvm/meta/meta.o	\
	uvm/meta/misc.o uvm/meta/mailbox.o uvm/reg/uvm_reg_file.o	\
	uvm/reg/uvm_vreg.o uvm/reg/uvm_reg_block.o			\
	uvm/reg/uvm_reg_map.o uvm/reg/uvm_reg_sequence.o		\
	uvm/reg/uvm_mem_mam.o uvm/reg/uvm_reg.o				\
	uvm/reg/uvm_reg_backdoor.o uvm/reg/uvm_vreg_field.o		\
	uvm/reg/uvm_reg_defines.o uvm/reg/uvm_mem.o uvm/reg/package.o	\
	uvm/reg/uvm_reg_cbs.o uvm/reg/uvm_reg_adapter.o			\
	uvm/reg/uvm_reg_field.o uvm/reg/uvm_reg_item.o			\
	uvm/reg/uvm_reg_model.o uvm/dap/package.o			\
	uvm/dap/uvm_get_to_lock_dap.o uvm/dap/uvm_simple_lock_dap.o	\
	uvm/dap/uvm_set_get_dap_base.o					\
	uvm/dap/uvm_set_before_get_dap.o uvm/package.o			\
	uvm/tlm2/uvm_tlm2_imps.o uvm/tlm2/uvm_tlm2_exports.o		\
	uvm/tlm2/uvm_tlm2_defines.o					\
	uvm/tlm2/uvm_tlm2_generic_payload.o uvm/tlm2/package.o		\
	uvm/tlm2/uvm_tlm2_sockets.o uvm/tlm2/uvm_tlm2_sockets_base.o	\
	uvm/tlm2/uvm_tlm2_ifs.o uvm/tlm2/uvm_tlm2_time.o		\
	uvm/tlm2/uvm_tlm2_ports.o uvm/dpi/package.o uvm/dpi/uvm_hdl.o	\
	uvm/dpi/uvm_svcmd_dpi.o uvm/vpi/package.o			\
	uvm/vpi/uvm_vpi_intf.o uvm/tlm1/uvm_sqr_ifs.o			\
	uvm/tlm1/uvm_tlm_imps.o uvm/tlm1/package.o			\
	uvm/tlm1/uvm_tlm_req_rsp.o uvm/tlm1/uvm_tlm_defines.o		\
	uvm/tlm1/uvm_tlm_fifo_base.o uvm/tlm1/uvm_ports.o		\
	uvm/tlm1/uvm_tlm_fifos.o uvm/tlm1/uvm_tlm_gen_rsp.o		\
	uvm/tlm1/uvm_imps.o uvm/tlm1/uvm_analysis_port.o		\
	uvm/tlm1/uvm_exports.o uvm/tlm1/uvm_sqr_connections.o		\
	uvm/tlm1/uvm_tlm_ifs.o


all: libs libs-ldc

libs-ldc: libesdl-ldc-shared.so libuvm-ldc-shared.so \
	libesdl-ldc.a libuvm-ldc.a

libesdl:
	$(MAKE) DMD=dmd PICOBJDIR=obj PHOBOS=phobos2 libesdl.so

libuvm:
	$(MAKE) DMD=dmd PICOBJDIR=obj PHOBOS=phobos2 libuvm.so

libs: libesdl libuvm

clean:
	rm -rf lib*.o lib*.so obj obj-ldc picobj-ldc

$(PICOBJDIR)/esdl/%.o: ../../vlang/src/esdl/%.d
	$(DMD) -c $(DFLAGS) -fPIC -of$@ -I$(ESDLDIR)/src $^

$(PICOBJDIR)/unstd/%.o: ../../vlang/src/unstd/%.d
	$(DMD) -c $(DFLAGS) -fPIC -of$@ -I$(ESDLDIR)/src $^

$(PICOBJDIR)/uvm/%.o: ../src/uvm/%.d
	$(DMD) -c $(DFLAGS) -fPIC -of$@ -I$(ESDLDIR)/src -I$(UVMDIR)/src $^

$(OBJDIR)/esdl/%.o: ../../vlang/src/esdl/%.d
	$(DMD) -c $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

$(OBJDIR)/unstd/%.o: ../../vlang/src/unstd/%.d
	$(DMD) -c $(DFLAGS) -of$@ -I$(ESDLDIR)/src $^

$(OBJDIR)/uvm/%.o: ../src/uvm/%.d
	$(DMD) -c $(DFLAGS) -of$@ -I$(ESDLDIR)/src -I$(UVMDIR)/src $^

libesdl-ldc-shared.so: $(addprefix $(PICOBJDIR)/,$(ESDLOBJS))
	$(DMD) -shared $(DFLAGS) -fPIC -of$@ -L-lphobos2-ldc-shared -L-ldruntime-ldc-shared -L-L. -L-R. -I$(ESDLDIR)/src $^

libuvm-ldc-shared.so: $(addprefix $(PICOBJDIR)/,$(UVMOBJS))
	$(DMD) -shared $(DFLAGS) -fPIC -of$@  -L-lphobos2-ldc-shared -L-ldruntime-ldc-shared -L-L. -L-R. -I$(UVMDIR)/src -I$(ESDLDIR)/src $^

libesdl-ldc.a: $(addprefix $(OBJDIR)/,$(ESDLOBJS))
	ar rcs $@ $^

libuvm-ldc.a: $(addprefix $(OBJDIR)/,$(UVMOBJS))
	ar rcs $@ $^

libesdl.so: $(ESDLOBJS)
	$(DMD) -shared $(DFLAGS) -fPIC -of$@ -L-l$(PHOBOS) -I$(ESDLDIR)/src $^

libuvm.so: $(UVMOBJS)
	$(DMD) -shared $(DFLAGS) -fPIC -of$@ -L-l$(PHOBOS) -I$(UVMDIR)/src -I$(ESDLDIR)/src $^
