//----------------------------------------------------------------------
// Copyright 2019 Coverify Systems Technology
// Copyright 2018 Synopsys, Inc.
// Copyright 2018 Cadence Design Systems, Inc.
// Copyright 2018 NVIDIA Corporation
// Copyright 2018 Cisco Systems, Inc.
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
//----------------------------------------------------------------------

module uvm.base.uvm_field_op;


import uvm.base.uvm_scope: uvm_scope_base;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_globals: uvm_field_flag_t;
import uvm.base.uvm_object_globals: uvm_field_auto_enum, uvm_field_xtra_enum;
import uvm.base.uvm_globals: uvm_error;
import uvm.base.uvm_policy: uvm_policy;
import uvm.base.uvm_object_defines;
import uvm.meta.misc;
import uvm.meta.meta;

//------------------------------------------------------------------------------
// Class - uvm_field_op
//
// uvm_field_op is the UVM class for describing all operations supported by the do_execute_op function
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 5.3.13.2.1
class uvm_field_op: uvm_object
{

  // @uvm-ieee 1800.2-2017 auto 5.3.4.5
  // @uvm-ieee 1800.2-2017 auto 5.3.4.6
  // @uvm-ieee 1800.2-2017 auto 5.3.4.7
  // @uvm-ieee 1800.2-2017 auto 5.3.5.1
  mixin uvm_object_essentials;
  mixin (uvm_sync_string);
  
  @uvm_private_sync
  private uvm_policy _m_policy;
  @uvm_private_sync
  private bool _m_user_hook = true;
  @uvm_private_sync
  private uvm_object _m_object;
  // Bit m_is_set is set when the set() method is called and acts 
  // like a state variable. It is cleared when flush is called.
  @uvm_private_sync
  private bool _m_is_set = false;
  @uvm_private_sync
  private uvm_field_flag_t _m_op_type;


  // Function -- new 
  // 
  // Creates a policy with the specified instance name. If name is not provided, then the policy instance is
  // unnamed.

  // @uvm-ieee 1800.2-2017 auto 5.3.13.2.3
  // @uvm-ieee 1800.2-2017 auto 5.3.2
  this(string name="") {
    synchronized (this) {
      super(name);
      _m_is_set = false;
      _m_user_hook = true;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 5.3.13.2.4
  void set(uvm_field_flag_t op_type, uvm_policy policy = null, uvm_object rhs = null) {
    synchronized (this) {
      string[] matching_ops;
      if (op_type & uvm_field_auto_enum.UVM_COPY) {
	matching_ops ~= "UVM_COPY";
      }
      if (op_type & uvm_field_auto_enum.UVM_COMPARE) {
	matching_ops ~= "UVM_COMPARE";
      }
      if (op_type & uvm_field_auto_enum.UVM_PRINT) {
	matching_ops ~= "UVM_PRINT";
      }
      if (op_type & uvm_field_auto_enum.UVM_RECORD) {
	matching_ops ~= "UVM_RECORD";
      }
      if (op_type & uvm_field_auto_enum.UVM_PACK) {
	matching_ops ~= "UVM_PACK";
      }
      if (op_type & uvm_field_auto_enum.UVM_UNPACK) {
	matching_ops ~= "UVM_UNPACK";
      }
      if (op_type & uvm_field_auto_enum.UVM_SET) {
	matching_ops ~= "UVM_SET";
      }

      if (matching_ops.length > 1) {
	string msg_queue;
	msg_queue ~= "(";
	foreach (i, op; matching_ops) {
	  msg_queue ~= op;
	  if (i != matching_ops.length - 1) {
	    msg_queue ~= ",";
	  }
	}
	msg_queue ~= ")";
	uvm_error("UVM/FIELD_OP/SET_BAD_OP_TYPE",
		  "set() was passed op_type matching multiple operations: " ~
		  msg_queue);
      }

      if (_m_is_set == 0) {
	_m_op_type = op_type;
	_m_policy = policy;
	_m_object = rhs;
	_m_is_set = true;
      }
      else {
	uvm_error("UVM/FIELD_OP/SET","Attempting to set values in policy without flushing");
      }
    }
  }

   // @uvm-ieee 1800.2-2017 auto 5.3.13.2.5
  string get_op_name() {
    synchronized (this) {
      switch (_m_op_type) {
      case uvm_field_auto_enum.UVM_COPY : return "copy";
      case uvm_field_auto_enum.UVM_COMPARE : return "compare";
      case uvm_field_auto_enum.UVM_PRINT : return "print";
      case uvm_field_auto_enum.UVM_RECORD : return "record";
      case uvm_field_auto_enum.UVM_PACK : return "pack";
      case uvm_field_auto_enum.UVM_UNPACK : return "unpack";
      case uvm_field_auto_enum.UVM_SET : return "set";
      default: return "";
      }
    }
  }

   // @uvm-ieee 1800.2-2017 auto 5.3.13.2.6
  uvm_field_flag_t get_op_type() {
    synchronized (this) {
      if (_m_is_set is true) {
	return _m_op_type;
      }
      else {
	uvm_error("UVM/FIELD_OP/GET_OP_TYPE",
		  "Calling get_op_type() before calling set() is not allowed");
	return 0;		// SV?
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 5.3.13.2.7
  uvm_policy get_policy() {
    synchronized (this) {
      if (_m_is_set is true) {
        return _m_policy;
      }
      else {
        uvm_error("UVM/FIELD_OP/GET_POLICY",
		  "Attempting to call get_policy() before calling set() is not allowed");
	return null;		// SV?
      }
    }
  }

  // @uvm-ieee 1800.2-2017 auto 5.3.13.2.8
  uvm_object get_rhs() {
    synchronized (this) {
      if (_m_is_set is true) {
        return _m_object;
      }
      else {
        uvm_error("UVM/FIELD_OP/GET_RHS",
		  "Calling get_rhs() before calling set() is not allowed");
	return null;		// SV?
      }
    }
  }

  // @uvm-ieee 1800.2-2017 auto 5.3.13.2.9
  bool user_hook_enabled() {
    synchronized (this) {
      if (_m_is_set is true) {
	return _m_user_hook;
      }
      else {
	uvm_error("UVM/FIELD_OP/GET_USER_HOOK",
		  "Attempting to get_user_hook before calling set() is not allowed");
	return false;		// SV?
      }
    }
  }

   // @uvm-ieee 1800.2-2017 auto 5.3.13.2.10
  void disable_user_hook() {
    synchronized (this) {
      _m_user_hook = true;
    }
  }

  mixin (uvm_scope_sync_string);
  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private uvm_field_op[] _m_recycled_op; 
  }


  // @uvm-ieee 1800.2-2017 auto 5.3.13.2.11
  void flush() {
    synchronized (this) {
      _m_policy = null;
      _m_object = null;
      _m_user_hook = true;
      _m_is_set = false;
    }
  }

   // API for reusing uvm_field_op instances.  Implementation
   // artifact, should not be used directly by the user.
  void m_recycle() {
    this.flush();
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m_recycled_op ~= this;
    }
  }
 
  static uvm_field_op m_get_available_op() {
    synchronized (_uvm_scope_inst) {
      uvm_field_op field_op ;
      if (_uvm_scope_inst._m_recycled_op.length > 0) {
	field_op = _uvm_scope_inst._m_recycled_op[$-1];
	_uvm_scope_inst._m_recycled_op.length -= 1;
      }
      else {
	field_op = uvm_field_op.type_id.create("field_op");
      }
      return field_op ;
    }
  }
}
