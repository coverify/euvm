//
// -------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
// Copyright 2004-2018 Synopsys, Inc.
// Copyright 2020 Verific
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

import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_cbs: uvm_reg_cbs;
import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_defines: UVM_REG_DATA_1;

import uvm.base.uvm_callback: uvm_register_cb;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_globals: uvm_fatal, uvm_error;

import uvm.base.uvm_object_defines;

import uvm.meta.misc;

import esdl.base.core: Process, fork;
import esdl.rand;

import std.string: format;


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

// @uvm-ieee 1800.2-2020 auto 19.5.1
abstract class uvm_reg_backdoor: uvm_object
{
  mixin(uvm_sync_string);
  
  mixin uvm_abstract_object_utils;

  // @uvm-ieee 1800.2-2020 auto 19.5.2.1
  this(string name = "") {
    super(name);
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.2
  // task
  void do_pre_read(uvm_reg_item rw) {
    pre_read(rw);
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.pre_read(rw);});
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.3
  // task
  protected void do_post_read(uvm_reg_item rw) {
    uvm_reg_data_t[] value_array;
    uvm_do_callbacks_reverse((uvm_reg_cbs cb) {
	value_array = rw.get_value();
	cb.decode(value_array);
      });
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.post_read(rw);});
    post_read(rw);
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.4
  // task
  protected void do_pre_write(uvm_reg_item rw) {
    pre_write(rw);
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.pre_read(rw);});
    uvm_do_callbacks((uvm_reg_cbs cb) {
	uvm_reg_data_t[] rw_value = rw.get_value();
	cb.encode(rw_value);
      });
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.5
  // task
  protected void do_post_write(uvm_reg_item rw) {
    uvm_do_callbacks((uvm_reg_cbs cb) {cb.post_write(rw);});
    post_write(rw);
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.6
  // task
  void write(uvm_reg_item rw) {
    uvm_fatal("RegModel", "uvm_reg_backdoor::write() method has not been overloaded");
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.7
  // task
  void read(uvm_reg_item rw) {
    do_pre_read(rw);
    read_func(rw);
    do_post_read(rw);
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.8
  void read_func(uvm_reg_item rw) {
    uvm_fatal("RegModel", "uvm_reg_backdoor::read_func() method has not been overloaded");
    // SV version has this -- would it ever be executed after uvm_fatal
    rw.set_status(UVM_NOT_OK);
  }

  bool is_auto_updated(uvm_reg_field field) {
    return false;
  }

  // task
  private void wait_for_change(uvm_object element) {
    uvm_fatal("RegModel", "uvm_reg_backdoor::wait_for_change() method has not been overloaded");
  }

  void start_update_thread(uvm_object element) {
    synchronized(this) {
      if (element in this._m_update_thread) {
	this.kill_update_thread(element);
      }
    }
    uvm_reg rg = cast(uvm_reg) element;
    if (rg is null) return; // only regs supported at this time
    fork({
	synchronized(this) {
	  version(UVM_USE_PROCESS_CONTAINER) {
	    this._m_update_thread[element] =
	      new process_container_c(Process.self());
	  }
	  else {
	    this._m_update_thread[element] = Process.self();
	  }
	}
	uvm_reg_field[] fields;
	rg.get_fields(fields);
	while(true) {
	  uvm_status_e status;
	  uvm_reg_data_t  val;
	  uvm_reg_item r_item = new uvm_reg_item("bd_r_item");
	  r_item.set_element(rg);
	  r_item.set_element_kind(UVM_REG);
	  this.read(r_item);
	  val = r_item.get_value(0);
	  if (r_item.get_status() != UVM_IS_OK) {
	    uvm_error("RegModel", format("Backdoor read of register '%s' failed.",
					 rg.get_name()));
	  }
	  foreach (field; fields) {
	    if (this.is_auto_updated(field)) {
	      uvm_reg_data_t tmp = (val >> field.get_lsb_pos()) &
		((UVM_REG_DATA_1 << field.get_n_bits()) - 1);
	      r_item.set_value(tmp, 0);
	      field.do_predict(r_item);
	    }
	  }
	  this.wait_for_change(element);
	}
      });
  }


  void kill_update_thread(uvm_object element) {
    synchronized(this) {
      if (element in this._m_update_thread) {
	version(UVM_USE_PROCESS_CONTAINER) {
	  this._m_update_thread[element].p.abort();
	}
	else {
	  this._m_update_thread[element].abort();
	}
	this._m_update_thread.remove(element);
      }
    }
  }

  bool has_update_threads() {
    synchronized(this) {
      return this._m_update_thread.length > 0;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.9
  // task
  void pre_read(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.10
  // task
  void post_read(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.11
  // task
  void pre_write(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2020 auto 19.5.2.12
  // task
  void post_write(uvm_reg_item rw) { }

  @uvm_public_sync
  private string _fname;

  @uvm_public_sync
  private int _lineno;

  version(UVM_USE_PROCESS_CONTAINER) {
  @uvm_public_sync
    private process_container_c[uvm_object] _m_update_thread;
  }
  else {
    @uvm_public_sync
    private Process[uvm_object] _m_update_thread;
  }

  mixin uvm_register_cb!(uvm_reg_cbs);
  
}


