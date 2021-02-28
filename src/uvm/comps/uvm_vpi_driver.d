//
//------------------------------------------------------------------------------
//   Copyright 2016-2019 Coverify Systems Technology
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

import uvm.base;
import uvm.comps.uvm_driver;
import uvm.tlm1.uvm_tlm_fifos;
import uvm.tlm1.uvm_ports;
import uvm.vpi.uvm_vpi_intf;
import esdl.intf.vpi;
import esdl.base.core: SimTerminatedException, AsyncLockDisabledException;
import esdl.rand.misc: rand;

class uvm_vpi_driver(REQ, string VPI_PREFIX): uvm_driver!REQ, rand.barrier
{
  mixin uvm_component_essentials;
  
  alias DRIVER = typeof(this);
  uvm_tlm_vpi_push_fifo!(REQ) req_fifo;

  protected uvm_put_port!(REQ) drive_vpi_port;
  uvm_get_peek_port!(REQ) get_req_port;

  uvm_async_event item_done_event;
  
  int vpi_fifo_depth = 1;	// can be configured via uvm_config_db

  string vpi_task_prefix;		// can be configured vio uvm_config_db

  string vpi_try_next_item_task() {
    return "$" ~ vpi_task_prefix ~ "_try_next_item";
  }

  string vpi_item_done_task() {
    return "$" ~ vpi_task_prefix ~ "_item_done";
  }

  override void build_phase(uvm_phase phase) {
    super.build_phase(phase);
    req_fifo = new uvm_tlm_vpi_push_fifo!(REQ)("req_fifo", this,
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

  // The functions vpi_try_next_item_task and vpi_item_done_task are
  // static functions because these is directly called by Verilog VPI.
  // But when you look at the user_data argument of these function,
  // the argument carries a pointer to an instance of vpi_driver
  // itself. So the function actually behaves like a OOP class method
  // only. It is therefor good to keep variables of the function as
  // non-static object data inside the class. We try to minimize
  // number of variable declarations on the stack since some EDA tools
  // provide for a very limited stack size

  private vpiHandle _vpi_systf_handle;
  private vpiHandle _vpi_arg_iterator;
  private uvm_vpi_iter _vpi_iter;
  private REQ _vpi_req;
  
  static int vpi_try_next_item_calltf(char* user_data) {
    try {
      DRIVER drv = cast(DRIVER) user_data;
      assert(drv !is null);
      assert(drv._vpi_iter !is null);
      if (drv.get_req_port.try_peek(drv._vpi_req) && drv._vpi_req !is null) {
	drv._vpi_systf_handle = vpi_handle(vpiSysTfCall, null);
	assert(drv._vpi_systf_handle !is null);
	drv._vpi_arg_iterator = vpi_iterate(vpiArgument, drv._vpi_systf_handle);
	assert(drv._vpi_arg_iterator !is null);
	drv._vpi_iter.assign(drv._vpi_arg_iterator, drv.vpi_try_next_item_task);
	drv._vpi_req.do_vpi_put(drv._vpi_iter);
	vpiReturnVal(VpiStatus.SUCCESS);
	return 0;
      }
      import esdl.base.core: RootEntityIntf;
      static RootEntityIntf root;
      if (root is null) root = drv.get_root_entity();
      if (root.isTerminated()) {
	throw (new SimTerminatedException());
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
      DRIVER drv = cast(DRIVER) user_data;
      assert(drv !is null);
      drv._vpi_systf_handle = vpi_handle(vpiSysTfCall, null);
      assert(drv._vpi_systf_handle !is null);
      drv.get_req_port.get(drv._vpi_req);
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
	       vpi_try_next_item_task, uvm_verbosity.UVM_DEBUG);
      tf_data.type = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.compiletf   = null;
      tf_data.sizetf      = null;
      tf_data.tfname = cast(char*) vpi_try_next_item_task.toStringz;
      tf_data.calltf = &vpi_try_next_item_calltf;
      // tf_data.compiletf = &pull_avmm_compiletf;
      tf_data.user_data = cast(char*) this;
      vpi_register_systf(&tf_data);
    }
    {
      s_vpi_systf_data tf_data;
      uvm_info("VPIREG", "Registering vpi system task: " ~
    	       vpi_item_done_task, uvm_verbosity.UVM_DEBUG);
      tf_data.type = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.compiletf   = null;
      tf_data.sizetf      = null;
      tf_data.tfname = cast(char*) vpi_item_done_task.toStringz;
      tf_data.calltf = &vpi_item_done_calltf;
      // tf_data.compiletf = &pull_avmm_compiletf;
      tf_data.user_data = cast(char*) this;
      vpi_register_systf(&tf_data);
    }
  }
  
  this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      item_done_event = new uvm_async_event("item_done_event", this);
      _vpi_iter = new uvm_vpi_iter();
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

