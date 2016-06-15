//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010 Cadence Design Systems, Inc.
//    Copyright 2015 Coverify Systems Technology
//    All Rights Reserved Worldwide
//
//    Licensed under the Apache License, Version 2.0 (the
//    "License"); you may not use this file except in
//    compliance with the License.  You may obtain a copy of
//    the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in
//    writing, software distributed under the License is
//    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//    CONDITIONS OF ANY KIND, either express or implied.  See
//    the License for the specific language governing
//    permissions and limitations under the License.
// -------------------------------------------------------------
//

module uvm.reg.uvm_reg_backdoor;

import uvm.reg.uvm_reg_field;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_cbs;
import uvm.reg.uvm_reg;
import uvm.base.uvm_callback;
import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_defines;

import uvm.meta.misc;

import esdl.base.core: Process, fork;
import esdl.data.rand;



// typedef class uvm_reg_cbs;


//------------------------------------------------------------------------------
// Class: uvm_reg_backdoor
//
// Base class for user-defined back-door register and memory access.
//
// This class can be extended by users to provide user-specific back-door access
// to registers and memories that are not implemented in pure SystemVerilog
// or that are not accessible using the default DPI backdoor mechanism.
//------------------------------------------------------------------------------

class uvm_reg_backdoor: uvm_object
{

  mixin(uvm_sync_string);
  mixin uvm_object_utils;
  mixin uvm_register_cb!(uvm_reg_cbs);

  // Function: new
  //
  // Create an instance of this class
  //
  // Create an instance of the user-defined backdoor class
  // for the specified register or memory
  //
  this(string name = "") {
    synchronized(this) {
      super(name);
    }
  }


  // Task: do_pre_read
  //
  // Execute the pre-read callbacks
  //
  // This method ~must~ be called as the first statement in
  // a user extension of the <read()> method.
  //
  // protected task do_pre_read(uvm_reg_item rw);

  // task
  void do_pre_read(uvm_reg_item rw) {
    pre_read(rw);
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.pre_read(rw);});
  }


  // Task: do_post_read
  //
  // Execute the post-read callbacks
  //
  // This method ~must~ be called as the last statement in
  // a user extension of the <read()> method.
  //
  // protected task do_post_read(uvm_reg_item rw);

  // task
  protected void do_post_read(uvm_reg_item rw) {
    // uvm_do_callbacks_reverse((uvm_reg_cbs cb) {cb.decode(rw.value);});
    uvm_do_callbacks_reverse((uvm_reg_cbs cb) {cb.decode(rw);});
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.post_read(rw);});
    post_read(rw);
  }


  // Task: do_pre_write
  //
  // Execute the pre-write callbacks
  //
  // This method ~must~ be called as the first statement in
  // a user extension of the <write()> method.
  //
  // protected task do_pre_write(uvm_reg_item rw);

  // task
  protected void do_pre_write(uvm_reg_item rw) {
    pre_write(rw);
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.pre_read(rw);});
    // uvm_do_callbacks((uvm_reg_cbs cb) {cb.encode(rw.value);});
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.encode(rw);});
  }


  // Execute the post-write callbacks
  //
  // This method ~must~ be called as the last statement in
  // a user extension of the <write()> method.
  //
  // protected task do_post_write(uvm_reg_item rw);

  // task
  protected void do_post_write(uvm_reg_item rw) {
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.post_write(rw);});
    post_write(rw);
  }


  // Task: write
  //
  // User-defined backdoor write operation.
  //
  // Call <do_pre_write()>.
  // Deposit the specified value in the specified register HDL implementation.
  // Call <do_post_write()>.
  // Returns an indication of the success of the operation.
  //
  // extern virtual task write(uvm_reg_item rw);

  // write

  // task
  void write(uvm_reg_item rw) {
    uvm_fatal("RegModel", "uvm_reg_backdoor::write() method has" ~
	      " not been overloaded");
  }



  // Task: read
  //
  // User-defined backdoor read operation.
  //
  // Overload this method only if the backdoor requires the use of task.
  //
  // Call <do_pre_read()>.
  // Peek the current value of the specified HDL implementation.
  // Call <do_post_read()>.
  // Returns the current value and an indication of the success of
  // the operation.
  //
  // By default, calls <read_func()>.
  //
  // extern virtual task read(uvm_reg_item rw);

  // read

  // task
  void read(uvm_reg_item rw) {
    do_pre_read(rw);
    read_func(rw);
    do_post_read(rw);
  }


  // Function: read_func
  //
  // User-defined backdoor read operation.
  //
  // Peek the current value in the HDL implementation.
  // Returns the current value and an indication of the success of
  // the operation.
  //
  // extern virtual function void read_func(uvm_reg_item rw);

  // read_func

  void read_func(uvm_reg_item rw) {
    uvm_fatal("RegModel", "uvm_reg_backdoor::read_func() method has" ~
	      " not been overloaded");
    // SV version has this -- would it ever be executed after uvm_fatal
    rw.status = UVM_NOT_OK;
  }

  // Function: is_auto_updated
  //
  // Indicates if wait_for_change() method is implemented
  //
  // Implement to return TRUE if and only if
  // <wait_for_change()> is implemented to watch for changes
  // in the HDL implementation of the specified field
  //
  // extern virtual function bit is_auto_updated(uvm_reg_field field);

  // is_auto_updated

  bool is_auto_updated(uvm_reg_field field) {
    return false;
  }



  // Task: wait_for_change
  //
  // Wait for a change in the value of the register or memory
  // element in the DUT.
  //
  // When this method returns, the mirror value for the register
  // corresponding to this instance of the backdoor class will be updated
  // via a backdoor read operation.
  //
  // extern virtual local task wait_for_change(uvm_object element);


  // wait_for_change

  // task
  private void wait_for_change(uvm_object element) {
    uvm_fatal("RegModel", "uvm_reg_backdoor::wait_for_change() method" ~
	      " has not been overloaded");
  }


  // /*local*/ extern function void start_update_thread(uvm_object element);

  // start_update_thread

  void start_update_thread(uvm_object element) {
    synchronized(this) {
      if (element in this.m_update_thread) {
	this.kill_update_thread(element);
      }
      uvm_reg rg = cast(uvm_reg) element;
      if (rg is null) return; // only regs supported at this time

      fork({
	  version(UVM_USE_PROCESS_CONTAINER) {
	    this.m_update_thread[element] =
	      new process_container_c(Process.self());
	  }
	  else {
	    this.m_update_thread[element] = Process.self();
	  }
	  uvm_reg_field[] fields;
	  rg.get_fields(fields);
	  while(true) {
	    uvm_status_e status;
	    uvm_reg_data_t  val;
	    uvm_reg_item r_item = new uvm_reg_item("bd_r_item");
	    r_item.element = rg;
	    r_item.element_kind = UVM_REG;
	    this.read(r_item);
	    // val = r_item.value[0];
	    val = r_item.get_value(0);
	    if (r_item.status != UVM_IS_OK) {
	      uvm_error("RegModel", format("Backdoor read of register" ~
					   " '%s' failed.", rg.get_name()));
	    }
	    foreach (field; fields) {
	      if (this.is_auto_updated(field)) {
		// r_item.value[0] = (val >> field.get_lsb_pos()) &
		//   ((1 << field.get_n_bits())-1);
		r_item.set_value(0, (val >> field.get_lsb_pos()) &
				 ((1 << field.get_n_bits())-1));
		field.do_predict(r_item);
	      }
	    }
	    this.wait_for_change(element);
	  }
	});
    }
  }


  // /*local*/ extern function void kill_update_thread(uvm_object element);

  // kill_update_thread

  void kill_update_thread(uvm_object element) {
    synchronized(this) {
      if (element in this.m_update_thread) {
	version(UVM_USE_PROCESS_CONTAINER) {
	  this.m_update_thread[element].p.abort();
	}
	else {
	  this.m_update_thread[element].abort();
	}
	this.m_update_thread.remove(element);
      }
    }
  }

  // /*local*/ extern function bit has_update_threads();

  // has_update_threads

  bool has_update_threads() {
    return this.m_update_thread.length > 0;
  }


  // Task: pre_read
  //
  // Called before user-defined backdoor register read.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  //
  // virtual task pre_read(uvm_reg_item rw); endtask
  // task
  void pre_read(uvm_reg_item rw) {}


  // Task: post_read
  //
  // Called after user-defined backdoor register read.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  //
  // virtual task post_read(uvm_reg_item rw); endtask
  void post_read(uvm_reg_item rw) {}


  // Task: pre_write
  //
  // Called before user-defined backdoor register write.
  //
  // The registered callback methods are invoked after the invocation
  // of this method.
  //
  // The written value, if modified, modifies the actual value that
  // will be written.
  //
  // virtual task pre_write(uvm_reg_item rw); endtask
  void pre_write(uvm_reg_item rw) {}


  // Task: post_write
  //
  // Called after user-defined backdoor register write.
  //
  // The registered callback methods are invoked before the invocation
  // of this method.
  //
  // virtual task post_write(uvm_reg_item rw); endtask

  void post_write(uvm_reg_item rw) {}

  @uvm_public_sync
  string _fname;
  @uvm_public_sync
  int _lineno;

  version(UVM_USE_PROCESS_CONTAINER) {
    private process_container_c[uvm_object] m_update_thread;
  }
  else {
    private Process[uvm_object] m_update_thread;
  }

}
