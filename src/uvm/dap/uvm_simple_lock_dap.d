//
//------------------------------------------------------------------------------
// Copyright 2016-2018 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2007-2009 Mentor Graphics Corporation
// Copyright 2013-2015 NVIDIA Corporation
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

module uvm.dap.uvm_simple_lock_dap;

import uvm.dap.uvm_set_get_dap_base: uvm_set_get_dap_base;

import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_object_defines; // uvm_object_essentials

// Class -- NODOCS -- uvm_simple_lock_dap
// Provides a 'Simple Lock' Data Access Policy.
//
// The 'Simple Lock' Data Access Policy allows for any number of 'sets',
// so long as the value is not 'locked'.  The value can be retrieved using
// 'get' at any time.
//
// The UVM uses this policy to protect the ~file name~ value in the
// <uvm_text_tr_database>.
//

class uvm_simple_lock_dap(T=int): uvm_set_get_dap_base!T
{

  // Used for self-references
  alias this_type = uvm_simple_lock_dap!T;

  mixin uvm_object_essentials;
  // Parameterized Utils
  // `uvm_object_param_utils(uvm_simple_lock_dap#(T))

  // Stored data
  private T _m_value;

  // Lock state
  private bool _m_locked;

  // Function -- NODOCS -- new
  // Constructor
  this(string name="unnamed-uvm_simple_lock_dap!T") {
    synchronized(this) {
      super(name);
      _m_locked = false;
    }
  }

  // Group -- NODOCS -- Set/Get Interface

  // Function -- NODOCS -- set
  // Updates the value stored within the DAP.
  //
  // ~set~ will result in an error if the DAP has
  // been locked.
  override void set(T value) {
    import std.string: format;
    import uvm.base.uvm_globals;
    synchronized(this) {
      if(_m_locked) {
	uvm_error("UVM/SIMPLE_LOCK_DAP/SAG",
		  format("Attempt to set new value on '%s', but the data " ~
			 "access policy forbids setting while locked!",
			 get_full_name()));
      }
      else {
	_m_value = value;
      }
    }
  }

  // Function -- NODOCS -- try_set
  // Attempts to update the value stored within the DAP.
  //
  // ~try_set~ will return a 1 if the value was successfully
  // updated, or a 0 if the value can not be updated due
  // to the DAP being locked.  No errors will be reported
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

  // Function -- NODOCS -- get
  // Returns the current value stored within the DAP
  //
  override T get() {
    synchronized(this) {
      return _m_value;
    }
  }

  // Function -- NODOCS -- try_get
  // Retrieves the current value stored within the DAP
  //
  // ~try_get~ will always return 1.
  override bool try_get(out T value) {
    value = get();
    return true;
  }

  // Group -- NODOCS -- Locking

  // Function -- NODOCS -- lock
  // Locks the data value
  //
  // The data value cannot be updated via <set> or <try_set> while locked.
  void lock() {
    synchronized(this) {
      _m_locked = true;
    }
  }

  // Function -- NODOCS -- unlock
  // Unlocks the data value
  //
  void unlock() {
    synchronized(this) {
      _m_locked = false;
    }
  }

  // Function -- NODOCS -- is_locked
  // Returns the state of the lock.
  //
  // Returns:
  // 1 - The value is locked
  // 0 - The value is unlocked
  bool is_locked() {
    synchronized(this) {
      return _m_locked;
    }
  }

  // Group -- NODOCS -- Introspection
  //
  // The ~uvm_simple_lock_dap~ cannot support the standard UVM
  // instrumentation methods (~copy~, ~clone~, ~pack~ and
  // ~unpack~), due to the fact that they would potentially
  // violate the access policy.
  //
  // A call to any of these methods will result in an error.

  override void do_copy(uvm_object rhs) {
    import uvm.base.uvm_globals;
    uvm_error("UVM/SIMPLE_LOCK_DAP/CPY",
	      "'copy()' is not supported for 'uvm_simple_lock_dap!T'");
  }

  override void do_pack(uvm_packer packer) {
    import uvm.base.uvm_globals;
    uvm_error("UVM/SIMPLE_LOCK_DAP/PCK",
	      "'pack()' is not supported for 'uvm_simple_lock_dap!T'");
  }

  override void do_unpack(uvm_packer packer) {
    import uvm.base.uvm_globals;
    uvm_error("UVM/SIMPLE_LOCK_DAP/UPK",
	      "'unpack()' is not supported for 'uvm_simple_lock_dap!T'");
  }

  // Group -- NODOCS -- Reporting

  // Function -- NODOCS -- convert2string
  override string convert2string() {
    import std.string: format;
    synchronized(this) {
      if(_m_locked) {
	return format("(%s) %s [LOCKED]", T.stringof, _m_value);
      }
      else {
	return format("(%s) %s [UNLOCKED]", T.stringof, _m_value);
      }
    }
  }

  // Function -- NODOCS -- do_print
  override void do_print(uvm_printer printer) {
    import std.string: format;
    synchronized(this) {
      super.do_print(printer);
      printer.print_field("lock_state", _m_locked);
      printer.print_generic("value", T.stringof,
			    0, format("%s", _m_value));
    }
  }
}
