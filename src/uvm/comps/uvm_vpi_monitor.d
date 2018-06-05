//
//------------------------------------------------------------------------------
//   Copyright 2016 Coverify Systems Technology
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------------------------

module uvm.comps.uvm_vpi_monitor;

import uvm.base.uvm_phase;
import uvm.base.uvm_component;
// import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.comps.uvm_monitor;
import uvm.tlm1.uvm_tlm_fifos;
import uvm.tlm1.uvm_ports;
import uvm.tlm1.uvm_analysis_port;
import uvm.tlm1.uvm_tlm_gen_rsp;
import uvm.vpi.uvm_vpi_intf;
import esdl.intf.vpi;
import esdl.base.core: SimTerminatedException, AsyncLockDisabledException;

class uvm_vpi_monitor(RSP, string VPI_PREFIX): uvm_monitor
{
  alias MONITOR = typeof(this);
  uvm_tlm_gen_rsp_vpi_channel!(RSP) rsp_fifo;

  uvm_put_port!(RSP) put_rsp_port;
  uvm_get_port!(RSP) get_rsp_port;
  uvm_get_port!(RSP) gen_rsp_port;

  public uvm_analysis_port!(RSP) rsp_port;
  
  enum string type_name = "uvm_vpi_monitor!(RSP)";

  string vpi_task_prefix;		// can be configured vio uvm_config_db

  string vpi_monitor_task() {
    return "$" ~ vpi_task_prefix ~ "_put_rsp";
  }

  override void build_phase(uvm_phase phase) {
    super.build_phase(phase);
    rsp_fifo = new uvm_tlm_gen_rsp_vpi_channel!(RSP)("rsp_fifo", this);
    put_rsp_port = new uvm_put_port!RSP("put_rsp_port", this);
    get_rsp_port = new uvm_get_port!RSP("get_rsp_port", this);
    gen_rsp_port = new uvm_get_port!RSP("gen_rsp_port", this);
    rsp_port     = new uvm_analysis_port!RSP("rsp_port", this);
  }

  override void connect_phase(uvm_phase phase) {
    gen_rsp_port.connect(rsp_fifo.gen_export);
    put_rsp_port.connect(rsp_fifo.put_export);
    get_rsp_port.connect(rsp_fifo.get_export);
  }

  protected void write(RSP rsp) {}

  override void run_phase(uvm_phase run_phase) {
    RSP rsp;
    while (true) {
      get_rsp_port.get(rsp);
      write(rsp);
      rsp_port.write(rsp);
    }
  }
  
  static int vpi_task_calltf(char* user_data) {
    try {
      MONITOR mon = cast(MONITOR) user_data;
      RSP rsp;
      // auto root = mon.get_root_entity();
      mon.gen_rsp_port.get(rsp);
      vpiHandle systf_handle = vpi_handle(vpiSysTfCall, null);
      assert(systf_handle !is null);
      vpiHandle arg_iterator = vpi_iterate(vpiArgument, systf_handle);
      assert(arg_iterator !is null);
      auto iter = new uvm_vpi_iter(arg_iterator, mon.vpi_monitor_task);
      rsp.do_vpi_get(iter);
      mon.put_rsp_port.put(rsp);
      vpiReturnVal(VpiStatus.SUCCESS);
      return 0;
    }
    catch (SimTerminatedException) {
      import std.stdio;
      stderr.writeln(" > Sending vpiFinish signal to the Verilog Simulator");
      vpi_control(vpiFinish, 1);
      vpiReturnVal(VpiStatus.FINISHED);
      return 0;
    }
    catch (AsyncLockDisabledException) {
      // import std.stdio;
      // stderr.writeln(" > Sending vpiFinish signal to the Verilog Simulator");
      // vpi_control(vpiFinish, 1);
      vpiReturnVal(VpiStatus.DISABLED);
      return 0;
    }
    catch (Throwable e) {
      import std.stdio: stderr;
      stderr.writeln("VPI Task call threw exception: ", e);
      vpiReturnVal(VpiStatus.UNKNOWN);
      return 0;
    }
  }
  
  override void setup_phase(uvm_phase phase) {
    import std.string: toStringz;
    super.setup_phase(phase);
    s_vpi_systf_data tf_data;
    uvm_info("VPIREG", "Registering vpi system task: " ~
	     vpi_monitor_task, uvm_verbosity.UVM_NONE);
    tf_data.type = vpiSysFunc;
    tf_data.sysfunctype = vpiIntFunc;
    tf_data.compiletf   = null;
    tf_data.sizetf      = null;
    tf_data.tfname = cast(char*) vpi_monitor_task.toStringz;
    tf_data.calltf = &vpi_task_calltf;
    // tf_data.compiletf = &pull_avmm_compiletf;
    tf_data.user_data = cast(char*) this;
    vpi_register_systf(&tf_data);
    
  }
  
  override string get_type_name() {
    return type_name;
  }

  this(string name, uvm_component parent) {
    super(name, parent);
    if (vpi_task_prefix == "") {
      if (VPI_PREFIX == "") {
	vpi_task_prefix = RSP.stringof;
      }
      else {
	vpi_task_prefix = VPI_PREFIX;
      }
    }
  }
}

