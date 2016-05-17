//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2013      NVIDIA Corporation
//   Copyright 2016      Coverify Systems Technology
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

module uvm.dap.uvm_get_to_lock_dap;

import uvm.dap.uvm_set_get_dap_base;

import uvm.base.uvm_printer;
import uvm.base.uvm_packer;
import uvm.base.uvm_globals;	// uvm_info
import std.string: format;
import uvm.base.uvm_object_globals: UVM_NONE;
import uvm.base.uvm_object_defines;

// Class: uvm_get_to_lock_dap
// Provides a 'Get-To-Lock' Data Access Policy.
//
// The 'Get-To-Lock' Data Access Policy allows for any number of 'sets',
// until the value is retrieved via a 'get'.  Once 'get' has been called,
// it is illegal to 'set' a new value.
//
// The UVM uses this policy to protect the ~starting phase~ and ~automatic objection~
// values in <uvm_sequence_base>.
//


class uvm_get_to_lock_dap(T=int): uvm_set_get_dap_base!T
{

  // Used for self-references
  alias this_type = uvm_get_to_lock_dap!T;

  mixin uvm_object_utils_norand;

  // Parameterized Utils
  // `uvm_object_param_utils(uvm_get_to_lock_dap#(T))

  // Stored data
  private T _m_value;

  // Lock state
  private bool _m_locked;

  // Function: new
  // Constructor
  this(string name="unnamed-uvm_get_to_lock_dap!T") {
    synchronized(this) {
      super(name);
      _m_locked = false;
    }
  }

  // Group: Set/Get Interface

  // Function: set
  // Updates the value stored within the DAP.
  //
  // ~set~ will result in an error if the value has
  // already been retrieved via a call to ~get~.
  override void set(T value) {
    synchronized(this) {
      if(_m_locked) {
	uvm_error("UVM/GET_TO_LOCK_DAP/SAG",
		  format("Attempt to set new value on '%s', " ~
			 "but the data access policy forbids" ~
			 " setting after a get!", get_full_name()));
      }
      else {
	_m_value = value;
      }
    }
  }

  // Function: try_set
  // Attempts to update the value stored within the DAP.
  //
  // ~try_set~ will return a 1 if the value was successfully
  // updated, or a 0 if the value can not be updated due
  // to ~get~ having been called.  No errors will be reported
  // if ~try_set~ fails.
  override bool try_set(T value) {
    synchronized(this) {
      if(_m_locked) {
	return false;
      }
      else {
	_m_value = value;
	return true;
      }
    }
  }

  // Function: get
  // Returns the current value stored within the DAP, and 'locks' the DAP.
  //
  // After a 'get', the value contained within the DAP cannot
  // be changed.
  override T get() {
    synchronized(this) {
      _m_locked = true;
      return _m_value;
    }
  }

  // Function: try_get
  // Retrieves the current value stored within the DAP, and 'locks' the DAP.
  //
  // ~try_get~ will always return 1.
  override bool try_get(out T value) {
    synchronized(this) {
      value = get();
      return true;
    }
  }

  // Group: Introspection
  //
  // The ~uvm_get_to_lock_dap~ cannot support the standard UVM
  // instrumentation methods (~copy~, ~clone~, ~pack~ and
  // ~unpack~), due to the fact that they would potentially
  // violate the access policy.
  //
  // A call to any of these methods will result in an error.

  override void do_copy(uvm_object rhs) {
    uvm_error("UVM/GET_TO_LOCK_DAP/CPY",
	      "'copy()' is not supported for 'uvm_get_to_lock_dap!T'");
  }

  override void do_pack(uvm_packer packer) {
    uvm_error("UVM/GET_TO_LOCK_DAP/PCK",
	      "'pack()' is not supported for 'uvm_get_to_lock_dap!T'");
  }

  override void do_unpack(uvm_packer packer) {
    uvm_error("UVM/GET_TO_LOCK_DAP/UPK",
	      "'unpack()' is not supported for 'uvm_get_to_lock_dap!T'");
  }

  // Group- Reporting

  // Function- convert2string
  override string convert2string() {
    synchronized(this) {
      if(_m_locked) {
	return format("(%s) %s [LOCKED]", T.stringof, _m_value);
      }
      else {
	return format("(%s) %s [UNLOCKED]", T.stringof, _m_value);
      }
    }
  }

  // Function- do_print
  override void do_print(uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      printer.print_field_int("lock_state", _m_locked);
      printer.print_generic("value",
			    T.stringof,
			    0,
			    format("%s", _m_value));
    }
  }
}
