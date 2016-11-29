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

module uvm.comps.uvm_vpi_driver;

import uvm.base.uvm_phase;
import uvm.base.uvm_component;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_root;
import uvm.base.uvm_async_lock;
import uvm.comps.uvm_driver;
import uvm.tlm1.uvm_tlm_fifos;
import uvm.tlm1.uvm_ports;
import uvm.vpi.uvm_vpi_intf;
import esdl.intf.vpi;
import esdl.base.core: SimTerminatedException, AsyncLockDisabledException;

class uvm_vpi_driver(REQ, string VPI_PREFIX): uvm_driver!REQ
{
  alias DRIVER = typeof(this);
  uvm_tlm_fifo_vpi_egress!(REQ) req_fifo;

  protected uvm_put_port!(REQ) drive_vpi_port;
  uvm_get_peek_port!(REQ) get_req_port;

  uvm_async_event item_done_event;
  
  enum string type_name = "uvm_vpi_driver!(REQ,RSP)";

  int vpi_fifo_depth = 1;	// can be configured via uvm_config_db

  string vpi_task_prefix;		// can be configured vio uvm_config_db

  string vpi_get_next_item_task() {
    return "$" ~ vpi_task_prefix ~ "_get_next_item";
  }

  string vpi_item_done_task() {
    return "$" ~ vpi_task_prefix ~ "_item_done";
  }

  override void build_phase(uvm_phase phase) {
    super.build_phase(phase);
    req_fifo = new uvm_tlm_fifo_vpi_egress!(REQ)("req_fifo", this,
						 vpi_fifo_depth);
    drive_vpi_port = new uvm_put_port!REQ("drive_vpi_port", this);
    get_req_port = new uvm_get_peek_port!REQ("get_req_port", this);
    
  }

  override void connect_phase(uvm_phase phase) {
    drive_vpi_port.connect(req_fifo.put_export);
    get_req_port.connect(req_fifo.get_export);
  }
  
  override void final_phase(uvm_phase phase) {
    drive_vpi_port.put(null);	// signal icarus to $finish
  }

  // task
  protected void drive_vpi(REQ req) {
    drive_vpi_port.put(req);
  }

  static int vpi_get_next_item_calltf(char* user_data) {
    try {
      vpiHandle systf_handle =
	vpi_handle(vpiSysTfCall, null);
      assert(systf_handle !is null);
      DRIVER drv = cast(DRIVER) user_data;
      REQ req;
      auto retval = drv.get_req_port.try_peek(req);
      if (retval && req !is null) {
	vpiHandle arg_iterator =
	  vpi_iterate(vpiArgument, systf_handle);
	assert(arg_iterator !is null);
	req.do_vpi_put(uvm_vpi_iter(arg_iterator,
				    drv.vpi_get_next_item_task));
	vpiReturnVal(VpiStatus.SUCCESS);
	return 0;
      }
      vpiReturnVal(VpiStatus.FAILURE);
      return 0;
    }
    catch (SimTerminatedException) {
      import std.stdio;
      writeln(" > Sending vpiFinish signal to the Verilog Simulator");
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

  static int vpi_item_done_calltf(char* user_data) {
    try {
      vpiHandle systf_handle =
	vpi_handle(vpiSysTfCall, null);
      assert(systf_handle !is null);
      DRIVER drv = cast(DRIVER) user_data;
      REQ req;
      drv.get_req_port.get(req);
      drv.item_done_event.schedule(Vpi.getTime());
      vpiReturnVal(VpiStatus.SUCCESS);
      return 0;
    }
    catch (SimTerminatedException) {
      import std.stdio;
      writeln(" > Sending vpiFinish signal to the Verilog Simulator");
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
    {
      s_vpi_systf_data tf_data;
      uvm_info("VPIREG", "Registering vpi system task: " ~
	       vpi_get_next_item_task, UVM_NONE);
      tf_data.type = vpiSysFunc;
      tf_data.tfname = cast(char*) vpi_get_next_item_task.toStringz;
      tf_data.calltf = &vpi_get_next_item_calltf;
      // tf_data.compiletf = &pull_avmm_compiletf;
      tf_data.user_data = cast(char*) this;
      vpi_register_systf(&tf_data);
    }
    {
      s_vpi_systf_data tf_data;
      uvm_info("VPIREG", "Registering vpi system task: " ~
    	       vpi_item_done_task, UVM_NONE);
      tf_data.type = vpiSysFunc;
      tf_data.tfname = cast(char*) vpi_item_done_task.toStringz;
      tf_data.calltf = &vpi_item_done_calltf;
      // tf_data.compiletf = &pull_avmm_compiletf;
      tf_data.user_data = cast(char*) this;
      vpi_register_systf(&tf_data);
    }
  }
  
  override string get_type_name() {
    return type_name;
  }

  this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      item_done_event = new uvm_async_event("item_done_event", this);
      if (vpi_task_prefix == "") {
	if (VPI_PREFIX == "") {
	  vpi_task_prefix = REQ.stringof;
	}
	else {
	  vpi_task_prefix = VPI_PREFIX;
	}
      }
    }
  }
}

