//----------------------------------------------------------------------
// Copyright 2019 Coverify Systems Technology
// Copyright 2018 Synopsys, Inc.
// Copyright 2018 Cadence Design Systems, Inc.
// Copyright 2018 NVIDIA Corporation
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

module uvm.base.uvm_policy;

import uvm.base.uvm_object;
import uvm.base.uvm_factory: uvm_object_wrapper;
import uvm.base.uvm_globals: uvm_report_fatal, uvm_error, uvm_info;
import uvm.base.uvm_object_globals: uvm_verbosity;

//------------------------------------------------------------------------------
// Class -- NODOCS --  uvm_policy
//
// The abstract uvm_policy class provides a common base from which all UVM policy classes derive
// Implementation as per Section 16.1 UVM Policy
//------------------------------------------------------------------------------
// @uvm-ieee 1800.2-2017 auto 16.1.1
abstract class uvm_policy: uvm_object
{

  enum recursion_state_e
    {
     NEVER,
     STARTED,
     FINISHED
    }


  private uvm_object[uvm_object_wrapper] _m_extensions;
  private uvm_object[] _m_policy_stack; // q in sv




  // Function -- NODOCS -- new
  // 
  // Creates a policy with the specified instance name. If name is not provided, then the policy instance is
  // unnamed.

  // @uvm-ieee 1800.2-2017 auto 16.1.2.1
  this (string name="") {
    synchronized (this) {
      super(name);
    }
  }

  // Function -- NODOCS -- flush
  //
  // The flush method resets the internal state of the policy, such that it can be reused.
  // Policy extensions are Not cleared in below method as per 16.1.2.3
  // @uvm-ieee 1800.2-2017 auto 16.1.2.2
  void flush() {
    synchronized (this) {
      _m_policy_stack.length = 0;
    }
  }



  // Function -- NODOCS -- extension_exists
  // Function extension_exists
  // Returns 1 if an extension exists within the policy with type matching ext_type; otherwise, returns 0.
  // @uvm-ieee 1800.2-2017 auto 16.1.2.3.1
  bool extension_exists(uvm_object_wrapper ext_type) {
    synchronized (this) {
      if (ext_type in _m_extensions)  {
	return true;
      }
      else {
	return false;
      }
    }
  }


  // Function -- NODOCS -- set_extension
  // 
  // Sets the given extension inside of the policy, indexed using return value from extension's get_object_type?
  // method (see 5.3.4.6). Only a single instance of an extension is stored per type. If there is an existing
  // extension instance matching extension's type, extension replaces the instance and the replaced instance
  // handle is returned; otherwise, null is returned.
  // @uvm-ieee 1800.2-2017 auto 16.1.2.3.2
  uvm_object set_extension(uvm_object extension) {
    synchronized (this) {
      uvm_object m_set_extension;
      if (extension  is null) {
	uvm_report_fatal("NULLEXT", "Attempting to set null extension ",
			 uvm_verbosity.UVM_NONE);
      }

      // Case where extension exists.
      if (extension.get_object_type() in _m_extensions) {
	m_set_extension = _m_extensions[extension.get_object_type()] ;
	_m_extensions[extension.get_object_type()] = extension;
	return m_set_extension;	
      }
      else {
	// Other case where extension doesnt exist. Nothing to return
	_m_extensions[extension.get_object_type()] = extension;
      }

      return null;
    }
  }


  // Function -- NODOCS -- get_extension
  //Returns the extension value stored within the policy with type matching ext_type. Returns null if no
  // extension exists matching that type.
  // @uvm-ieee 1800.2-2017 auto 16.1.2.3.3
  uvm_object get_extension(uvm_object_wrapper ext_type ) {
    synchronized (this) {
      if (ext_type in _m_extensions) {
	return _m_extensions[ext_type];
      }
      else {
	return null;
      }
    }
  }

  // Function -- NODOCS -- clear_extension
  // Removes the extension value stored within the policy matching type ext_type. If no extension exists
  // matching type ext_type, the request is silently ignored.
  // @uvm-ieee 1800.2-2017 auto 16.1.2.3.4
  void clear_extension(uvm_object_wrapper ext_type) {
    synchronized (this) {
      _m_extensions.remove(ext_type);
    }
  }

  // Function -- NODOCS -- clear_extensions
  // Removes all extensions currently stored within the policy.
  // @uvm-ieee 1800.2-2017 auto 16.1.2.3.5
  void clear_extensions() {
    synchronized (this) {
      _m_extensions.clear();
    }
  }


  // Function -- NODOCS -- push_active_object
  // Pushes obj on to the internal object stack for this policy, making it the current active object, as retrieved by
  // get_active_object (see 16.1.3.3). An implementation shall generate an error message if obj is null and the
  // request will be ignored. Additionally, the policy shall push itself onto the active policy stack for obj using push_active_policy (see
  // 5.3.14.1) when push_active_object is called.
  // @uvm-ieee 1800.2-2017 auto 16.1.3.1
  void push_active_object(uvm_object obj) {
    synchronized (this) {
      if (obj !is null) {
	_m_policy_stack ~= obj;
	// Placeholder. Will be removed once uvm_object is updated. That's a seperate mantisi 6438
	// obj.push_active_policy(this);
	//
      }
      else {
	uvm_error("UVM_POLICY_PUSHNULL", "Attempting to push an null object push_active_object onto the policy stack");
      }
    }
  }

  // Function -- NODOCS -- pop_active_object
  // Pops the current active object off of the internal object stack for this policy and returns the popped off value.
  // For additional behaviour descriptions (see
  // 5.3.14.2) when pop_active_object is called.
  // @uvm-ieee 1800.2-2017 auto 16.1.3.2
  uvm_object pop_active_object() {
    synchronized (this) {
      uvm_object  l_tmp;
      if (_m_policy_stack.length != 0) {
	l_tmp = _m_policy_stack[$-1];
	_m_policy_stack.length -= 1;
	return l_tmp;
      }
      else {
	uvm_info("UVM_POLICY_EMPTY_POPACTIVE_OBJECT",
		 "Attempting to pop an empty policy stack", uvm_verbosity.UVM_DEBUG);
	return null;
      }
    }
  }

  // Function -- NODOCS -- get_active_object
  // Returns the head of the internal object stack for this policy. 
  // empty, null is returned.
  // @uvm-ieee 1800.2-2017 auto 16.1.3.3
  uvm_object get_active_object() {
    synchronized (this) {
      if (_m_policy_stack.length != 0) {
	return _m_policy_stack[$-1];
      }
      else {
	return null;
      }
    }
  }

  // Function -- NODOCS -- get_active_object_depth
  // Returns the current depth of the internal object stack for this policy.
  uint get_active_object_depth() {
    synchronized (this) {
      return cast (uint) _m_policy_stack.length;
    }
  }
}
