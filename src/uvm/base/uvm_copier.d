//-----------------------------------------------------------------------------
// Copyright 2019 Coverify Systems Technology
// Copyright 2018 Qualcomm, Inc.
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
//-----------------------------------------------------------------------------

module uvm.base.uvm_copier;

import uvm.base.uvm_policy: uvm_policy;
import uvm.base.uvm_object_globals: uvm_radix_enum, UVM_FILE,
  uvm_bitstream_t, uvm_integral_t, uvm_recursion_policy_enum,
  uvm_field_auto_enum, uvm_field_flag_t, UVM_RECURSION;

import uvm.base.uvm_object_defines;
import uvm.base.uvm_field_op: uvm_field_op;
import uvm.base.uvm_globals: uvm_error, uvm_fatal, uvm_warning;
import uvm.base.uvm_coreservice: uvm_coreservice_t;
import std.traits: isIntegral, isBoolean, isArray, isDynamicArray, isStaticArray;
import uvm.base.uvm_scope;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_copier
//
// The uvm_copier class provides a policy object for doing comparisons. The
// policies determine how miscompares are treated and counted. Results of a
// comparison are stored in the copier object. The <uvm_object::compare>
// and <uvm_object::do_compare> methods are passed a uvm_copier policy
// object.
//
//------------------------------------------------------------------------------

// Class: uvm_copier
// Implementation of the uvm_copier class, as defined in section
// 16.6.1 of 1800.2-2017

// @uvm-ieee 1800.2-2017 auto 16.6.1
class uvm_copier: uvm_policy
{
  // @uvm-ieee 1800.2-2017 auto 16.6.2.2
  mixin uvm_object_essentials;
  // Variable -- NODOCS -- policy
  //
  // Determines whether comparison is UVM_DEEP, UVM_REFERENCE, or UVM_SHALLOW.

  uvm_recursion_policy_enum _policy = uvm_recursion_policy_enum.UVM_DEFAULT_POLICY;


   // @uvm-ieee 1800.2-2017 auto 16.6.2.1
  this(string name="uvm_copier") {
    synchronized (this) {
      super(name);
    }
  }
	
  // Implementation only.

  // Implementation only. Not present in the LRM.
  //recursion_state_e m_saved_state[uvm_object /*LHS*/][uvm_object /*RHS*/][uvm_recursion_policy_enum /*recursion*/];

  //                 /*RHS*/     /*LHS*/     /*recursion*/
  private
  recursion_state_e[uvm_recursion_policy_enum][uvm_object][uvm_object]
  _m_recur_states;

  // Function -- copy_object
  //
  // Copies two class objects using the <policy> knob to determine whether the
  // comparison should be deep, shallow, or reference. 
  //
  // The name input is used for purposes of storing and printing a miscompare. 
  //
  // The ~lhs~ and ~rhs~ objects are the two objects used for comparison. 
  //
  // The ~check_type~ determines whether or not to verify the object
  // types match (the return from ~lhs.get_type_name()~ matches
  // ~rhs.get_type_name()~).

  // @uvm-ieee 1800.2-2017 auto 16.6.4.1
  void copy_object (uvm_object lhs,
		    uvm_object rhs) {
    synchronized (this) {
      uvm_field_op field_op;
      if (get_recursion_policy() == uvm_recursion_policy_enum.UVM_REFERENCE) {
	uvm_error("UVM_COPY_POLICY",
		  "Attempting to make a copy of a object which is a reference");
	return;
      }

      if (rhs is null || lhs is null) {
	uvm_error("UVM_COPY_NULL_OBJ",
		  "Attempting to make a copy of a object with null src/target");
	return;
      }

      push_active_object(lhs);
      _m_recur_states[rhs][lhs][get_recursion_policy()] = recursion_state_e.STARTED;
      field_op = uvm_field_op.m_get_available_op() ;
      field_op.set(uvm_field_auto_enum.UVM_COPY, this, rhs);
      lhs.do_execute_op(field_op);
      if (field_op.user_hook_enabled()) {
	lhs.do_copy(rhs);
      }
      field_op.m_recycle();
      _m_recur_states[rhs][lhs][get_recursion_policy()] = recursion_state_e.FINISHED;
      pop_active_object();
    }
  }
  
  void copy_struct(T)(ref T lhs, ref T rhs) {
    synchronized (this) {
      uvm_field_op field_op;
      field_op = uvm_field_op.m_get_available_op() ;
      field_op.set(uvm_field_auto_enum.UVM_COPY, this);
      uvm_struct_do_execute_op(lhs, rhs, field_op);
      if (field_op.user_hook_enabled()) {
	static if (__traits(compiles, lhs.do_print(rhs))) {
	  lhs.do_copy(rhs);
	}
      }
      field_op.m_recycle();
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 16.6.4.2
  recursion_state_e object_copied(uvm_object lhs,
				  uvm_object rhs,
				  uvm_recursion_policy_enum recursion) {
    synchronized (this) {
      if (rhs !in _m_recur_states) return recursion_state_e.NEVER;
      else if (lhs !in _m_recur_states[rhs]) return recursion_state_e.NEVER;
      else if (recursion !in _m_recur_states[rhs][lhs]) return recursion_state_e.NEVER;
      else {
	return _m_recur_states[rhs][lhs][recursion];
      }
    }
  }

  override void flush() {
    synchronized (this) {
      _m_recur_states.clear();
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.6.3
  void set_recursion_policy (uvm_recursion_policy_enum policy) {
    synchronized (this) {
      this._policy = policy;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.6.3
  uvm_recursion_policy_enum get_recursion_policy() {
    synchronized (this) {
      return _policy;
    }
  }

  // Function: get_num_copies
  //
  // Returns the number of times the ~rhs~ has been copied to a unique ~lhs~ 
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  uint get_num_copies(uvm_object rhs) {
    synchronized (this) {
      if (rhs in _m_recur_states) {
	return cast (uint) _m_recur_states[rhs].length;
      }
      return 0;
    }
  }

  public uvm_object[] get_copies(uvm_object obj) {
    synchronized (this) {
      if (obj in _m_recur_states) {
	return _m_recur_states[obj].keys;
      }
      else return [];
    }
  }

  int get_first_copy(uvm_object rhs, ref uvm_object lhs) {
    synchronized (this) {
      auto copies = get_copies(rhs);
      if (copies.length == 0)
	return 0;
      else {
	lhs = copies[0];
	return 1;
      }
    }
  }
  
  // `define uvm_copier_get_function(FUNCTION)				\
  // function int get_``FUNCTION``_copy(uvm_object rhs, ref uvm_object lhs); \
  //   if (m_recur_states.exists(rhs)) \
  //     return m_recur_states[rhs].FUNCTION(lhs); \
  //   return 0; \
  // endfunction : get_``FUNCTION``_copy
  
  // // Function: get_first_copy
  // //
  // //| function int get_first_copy(uvm_object rhs, ref uvm_object lhs)
  // //
  // // assigns to the ~lhs~ the value of the first (smallest) object that
  // // was copied from the ~rhs~. It returns 0 if the ~rhs~ hasn't been copied;
  // // otherwise, it returns 1.
  // //
  // // @uvm-contrib This API is being considered for potential contribution to 1800.2
  // `uvm_copier_get_function(first)


  // // Function: get_next_copy
  // //
  // //| function int get_next_copy(uvm_object rhs, ref uvm_object lhs)
  // //
  // // finds the smallest object that was copied from the ~rhs~ whose value is 
  // // greater than the given ~lhs~ object argument. If there is a next entry,
  // // the ~lhs~ is assigned the value of the next object, and the function returns 1. 
  // // Otherwise, the ~lhs~ is unchanged, and the function returns 0.
  // //
  // // @uvm-contrib This API is being considered for potential contribution to 1800.2
  // `uvm_copier_get_function(next)

  // // Function: get_last_copy
  // //
  // //| function int get_last_copy(uvm_object rhs, ref uvm_object lhs)
  // //
  // // assigns to the ~lhs~ the value of the last (largest) object that
  // // was copied from the ~rhs~. It returns 0 if the ~rhs~ hasn't been copied;
  // // otherwise, it returns 1.
  // //
  // // @uvm-contrib This API is being considered for potential contribution to 1800.2
  // `uvm_copier_get_function(last)

  // // Function: get_prev_copy
  // //
  // //| function int get_prev_copy(uvm_object rhs, ref uvm_object lhs)
  // //
  // // finds the largest object that was copied from the ~rhs~ whose value is 
  // // smaller than the given ~lhs~ object argument. If there is a previous entry,
  // // the ~lhs~ is assigned the value of the previous object, and the function returns 1. 
  // // Otherwise, the ~lhs~ is unchanged, and the function returns 0.
  // //
  // // @uvm-contrib This API is being considered for potential contribution to 1800.2
  // `uvm_copier_get_function(prev)

  // @uvm-ieee 1800.2-2017 auto 16.6.2.3
  static void set_default(uvm_copier copier) {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get();
    coreservice.set_default_copier(copier);
  }

  // @uvm-ieee 1800.2-2017 auto 16.6.2.4
  static uvm_copier get_default() {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get();
    return coreservice.get_default_copier() ;
  }

  void uvm_copy_element(E)(string name, ref E lhs, ref E rhs,
			   uvm_field_flag_t flags) {
    synchronized (this) {
      import uvm.base.uvm_misc: UVM_ELEMENT_TYPE;
      alias EE = UVM_ELEMENT_TYPE!E;
      static if (is (EE: uvm_object)) {
	uvm_recursion_policy_enum policy =
	  cast (uvm_recursion_policy_enum) (UVM_RECURSION & flags);
	if ((policy != uvm_recursion_policy_enum.UVM_DEFAULT_POLICY) &&
	    (policy != this.get_recursion_policy())) {
	  uvm_recursion_policy_enum prev_policy  = this.get_recursion_policy();
	  this.set_recursion_policy(policy);
	  m_uvm_copy_element!E(name, lhs, rhs, flags);
	  this.set_recursion_policy(prev_policy);
	}
	else {
	  m_uvm_copy_element!E(name, lhs, rhs, flags);
	}
      }
      else {
	m_uvm_copy_element!E(name, lhs, rhs, flags);
      }
    }
  }

  void m_uvm_copy_element(E)(string name, ref E lhs, ref E rhs,
			      uvm_field_flag_t flags) {
    static if (isArray!E && !is (E == string)) {
      static if (isDynamicArray!E) {
	if (lhs.length != rhs.length) {
	  lhs.length = rhs.length;
	}
      }
      for (size_t i=0; i != lhs.length; ++i) {
	m_uvm_copy_element(name, lhs[i], rhs[i], flags);
      }
    }
    else static if (is (E: uvm_object)) {
      auto policy = cast (uvm_recursion_policy_enum) (UVM_RECURSION && flags);
      uvm_copy_object(name, lhs, rhs, policy);
    }
    else static if (is (E == struct)) {
      auto policy = cast (uvm_recursion_policy_enum) (UVM_RECURSION && flags);
      this.copy_struct(lhs, rhs);
    }
    else {
      lhs = rhs;
    }
  }
  
  void uvm_copy_object(T)(string name, ref T lhs, ref T rhs,
			  uvm_recursion_policy_enum policy) {
    synchronized (this) {
      if (lhs !is rhs) {
	if (rhs is null ||
	    policy == uvm_recursion_policy_enum.UVM_REFERENCE ||
	    (policy == uvm_recursion_policy_enum.UVM_DEFAULT_POLICY &&
	     (this.get_recursion_policy() ==
	      uvm_recursion_policy_enum.UVM_REFERENCE))) {
	  lhs = rhs;
	}
	else {
	  uvm_object lobject;
	  auto has_copies = this.get_first_copy(rhs, lobject);
	  lhs = cast (T) lobject;
	  if (!has_copies || lhs is null) {
	    // uvm_copy_element handles setting of recursion policy now
	    // uvm_recursion_policy_enum prev_policy = this.get_recursion_policy();
	    // if (policy != uvm_recursion_policy_enum.UVM_DEFAULT_POLICY)
	    //   this.set_recursion_policy(policy);
	    uvm_recursion_policy_enum curr_policy =
	      this.get_recursion_policy();
	    if (lhs is null) {
	      lhs = cast (T) rhs.create(rhs.get_name());
	      if (lhs is null) {
		uvm_fatal("UVM/COPY/NULL_CREATE",
			  "Could not create '" ~ rhs.get_full_name() ~
			  "' of type '" ~ rhs.get_type_name() ~
			  "' ~ into '" ~ name ~ "'.");
	      }
	      else {
		this.copy_object(lhs, rhs);
	      }
	    }
	    else {
	      if (this.object_copied(lhs, rhs, curr_policy) ==
		  recursion_state_e.STARTED) {
		uvm_warning("UVM/COPY/LOOP",
			    "Loop detected in copy operation (LHS:'" ~
			    lhs.get_full_name() ~
			    "' ~ RHS:'" ~
			    rhs.get_full_name() ~
			    "')");
	      }
	      else {
		this.copy_object(lhs, rhs);
	      }
	    }
	    // uvm_copy_element handles setting of recursion policy now
	    // if (policy != uvm_recursion_policy_enum.UVM_DEFAULT_POLICY)
	    //   this.set_recursion_policy(prev_policy);
	  }
	}
      }
       
    } 
  }
}
