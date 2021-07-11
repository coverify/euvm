//-----------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2017-2018 Cisco Systems, Inc.
// Copyright 2018 Qualcomm, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2013-2018 Synopsys, Inc.
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

module uvm.base.uvm_comparer;
//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_comparer
//
// The uvm_comparer class provides a policy object for doing comparisons. The
// policies determine how miscompares are treated and counted. Results of a
// comparison are stored in the comparer object. The <uvm_object::compare>
// and <uvm_object::do_compare> methods are passed a uvm_comparer policy
// object.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_object: uvm_object;

import uvm.base.uvm_object_globals: uvm_recursion_policy_enum, uvm_severity,
  uvm_integral_t, uvm_radix_enum, uvm_bitstream_t, uvm_verbosity,
  uvm_field_flag_t, UVM_RADIX, UVM_RECURSION;
import uvm.base.uvm_globals: uvm_warning, uvm_report_debug;
import uvm.base.uvm_policy: uvm_policy;
import uvm.base.uvm_field_op: uvm_field_op;
import uvm.base.uvm_coreservice: uvm_coreservice_t;
import uvm.base.uvm_object_defines;

import uvm.meta.misc;
import esdl.data.bvec;

import std.traits;
import std.string: format;

// @uvm-ieee 1800.2-2017 auto 16.3.1
class uvm_comparer: uvm_policy
{
  mixin (uvm_sync_string);
  // @uvm-ieee 1800.2-2017 auto 16.3.2.3
  mixin uvm_object_essentials;


  // @uvm-ieee 1800.2-2017 auto 16.3.2.2
  override void flush() {
    synchronized (this) {
      _miscompares = "" ;
      _check_type = true;
      _result = 0;
      _m_recur_states.clear();
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.3.5
  uvm_policy.recursion_state_e object_compared(uvm_object lhs,
					       uvm_object rhs,
					       uvm_recursion_policy_enum recursion,
					       out bool ret_val) {
    synchronized (this) {
      if (lhs !in _m_recur_states) return uvm_policy.recursion_state_e.NEVER;
      else if (rhs !in _m_recur_states[lhs]) return uvm_policy.recursion_state_e.NEVER;
      else if (recursion !in _m_recur_states[lhs][rhs]) return uvm_policy.recursion_state_e.NEVER;
      else {
	if (_m_recur_states[lhs][rhs][recursion]._state ==
	    uvm_policy.recursion_state_e.FINISHED)
	  ret_val = _m_recur_states[lhs][rhs][recursion]._ret_val;
	return _m_recur_states[lhs][rhs][recursion]._state ;
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.3.3.8
  string get_miscompares() {
    synchronized (this) {
      return _miscompares;
    }
  }

  uint get_result() {
    synchronized (this) {
      return _result;
    }
  }

  void set_result(uint result) {
    synchronized (this) {
      _result = result;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.4.1
  void set_recursion_policy(uvm_recursion_policy_enum policy) {
    synchronized (this) {
      _policy = policy;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.4.1
  uvm_recursion_policy_enum get_recursion_policy() {
    synchronized (this) {
      return _policy ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.4.2
  void set_check_type(bool enabled) {
    synchronized (this) {
      _check_type = enabled ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.4.2
  bool get_check_type() {
    synchronized (this) {
      return _check_type;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.5.1
  void set_show_max(uint show_max) {
    synchronized (this) {
      _show_max = show_max;
    }
  }

  uint get_show_max() {
    synchronized (this) {
      return _show_max;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.5.2
  void set_verbosity(uint verbosity) {
    synchronized (this) {
      _verbosity = verbosity;
    }
  }

  uint get_verbosity() {
    synchronized (this) {
      return _verbosity;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.5.3
  void set_severity(uvm_severity severity) {
    synchronized (this) {
      _sev = severity;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.5.3
  uvm_severity get_severity() {
    synchronized (this) {
      return _sev ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.6
  void set_threshold(uint threshold) {
    synchronized (this) {
      _m_threshold = threshold;
    }
  }

  uint get_threshold() {
    synchronized (this) {
      return _m_threshold;
    }
  }

  struct state_info_t {
    recursion_state_e _state;
    bool _ret_val;
  };



  //           recursion                  RHS         LHS
  state_info_t[uvm_recursion_policy_enum][uvm_object][uvm_object]
  _m_recur_states;

  // Variable -- NODOCS -- policy
  //
  // Determines whether comparison is UVM_DEEP, UVM_REFERENCE, or UVM_SHALLOW.

  @uvm_private_sync
  private uvm_recursion_policy_enum _policy = uvm_recursion_policy_enum.UVM_DEFAULT_POLICY;


  // Variable -- NODOCS -- show_max
  //
  // Sets the maximum number of messages to send to the printer for miscompares
  // of an object.

  @uvm_public_sync
  private uint _show_max = 1;

  // Variable -- NODOCS -- verbosity
  //
  // Sets the verbosity for printed messages.
  //
  // The verbosity setting is used by the messaging mechanism to determine
  // whether messages should be suppressed or shown.

  @uvm_public_sync
  private uint _verbosity = uvm_verbosity.UVM_LOW;

  // Variable -- NODOCS -- sev
  //
  // Sets the severity for printed messages.
  //
  // The severity setting is used by the messaging mechanism for printing and
  // filtering messages.

  @uvm_public_sync
  private uvm_severity _sev = uvm_severity.UVM_INFO;

  // Variable -- NODOCS -- miscompares
  //
  // This string is reset to an empty string when a comparison is started.
  //
  // The string holds the last set of miscompares that occurred during a
  // comparison.

  @uvm_public_sync
  private string _miscompares = "";

  // Variable -- NODOCS -- check_type
  //
  // This bit determines whether the type, given by <uvm_object::get_type_name>,
  // is used to verify that the types of two objects are the same.
  //
  // This bit is used by the <compare_object> method. In some cases it is useful
  // to set this to 0 when the two operands are related by inheritance but are
  // different types.

  @uvm_public_sync
  private bool _check_type = true;

  // Variable -- NODOCS -- result
  //
  // This bit stores the number of miscompares for a given compare operation.
  // You can use the result to determine the number of miscompares that
  // were found.

  @uvm_public_sync
  private uint _result = 0;

  public void incr_result() {
    synchronized (this) {
      ++_result;
    }
  }


  @uvm_private_sync
  private uint _m_threshold;


  // @uvm-ieee 1800.2-2017 auto 16.3.2.1
  this(string name="") {
    synchronized (this) {
      super(name);
      _m_threshold = 1;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.3.2.4
  static void set_default(uvm_comparer comparer) {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get() ;
    coreservice.set_default_comparer(comparer);
  }

  // @uvm-ieee 1800.2-2017 auto 16.3.2.5
  static uvm_comparer get_default() {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get();
    return coreservice.get_default_comparer();
  }

  // Function -- NODOCS -- compare -- templatized version
  //
  // Compares two integral values. 
  //
  // The ~name~ input is used for purposes of storing and printing a miscompare.
  //
  // The left-hand-side ~lhs~ and right-hand-side ~rhs~ objects are the two
  // objects used for comparison. 
  //
  // The size variable indicates the number of bits to compare; size must be
  // less than or equal to 4096. 
  //
  // The radix is used for reporting purposes, the default radix is hex.

  bool compare(T)(string name,
		  T lhs,
		  T rhs,
		  uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX)
    if (isBitVector!T || isIntegral!T || isBoolean!T)  {
      import uvm.base.uvm_object_globals;
      synchronized (this) {
	string msg;
	if (lhs != rhs) {
	  static if (is (T == enum)) {
	    msg = format("%s: lhs = %s : rhs = %s", name, lhs, rhs);
	  }
	  else {
	    switch (radix) {
	    case uvm_radix_enum.UVM_BIN:
	      msg = format("%s: lhs = 'b%0b : rhs = 'b%0b", name, lhs, rhs);
	      break;
	    case uvm_radix_enum.UVM_OCT:
	      msg = format("%s: lhs = 'o%0o : rhs = 'o%0o", name, lhs, rhs);
	      break;
	    case uvm_radix_enum.UVM_DEC:
	      msg = format("%s: lhs = %0d : rhs = %0d", name, lhs, rhs);
	      break;
	    case uvm_radix_enum.UVM_TIME:
	      msg = format("%s: lhs = %0d : rhs = %0d", name, lhs, rhs);
	      break;
	    case uvm_radix_enum.UVM_STRING:
	      msg = format("%s: lhs = %0s : rhs = %0s", name, lhs, rhs);
	      break;
	    case uvm_radix_enum.UVM_ENUM:
	      //Printed as decimal, user should cuse compare string for enum val
	      msg = format("%s: lhs = %s : rhs = %s", name, lhs, rhs);
	      break;
	    default:
	      msg = format("%s: lhs = 'h%0x : rhs = 'h%0x",
			   name, lhs, rhs);
	      break;
	    }
	  }
	  print_msg(msg);
	  return false;
	}
	return true;
      }
    }

  bool compare(T)(string name,
		  T lhs,
		  T rhs)
    if (isFloatingPoint!T) {
      synchronized (this) {
	string msg;

	if (lhs != rhs) {
	  import std.string: format;
	  msg = format("%s: lhs = %s,  : rhs = %s", name, lhs, rhs);
	  print_msg(msg);
	  return false;
	}
	return true;
      }
    }

  
  // Function -- NODOCS -- compare_object
  //
  // Compares two class objects using the <policy> knob to determine whether the
  // comparison should be deep, shallow, or reference. 
  //
  // The name input is used for purposes of storing and printing a miscompare. 
  //
  // The ~lhs~ and ~rhs~ objects are the two objects used for comparison. 
  //
  // The ~check_type~ determines whether or not to verify the object
  // types match (the return from ~lhs.get_type_name()~ matches
  // ~rhs.get_type_name()~).

  bool compare(T)(string name,
		  T lhs,
		  T rhs)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      synchronized (this) {
	int old_result ;
	uvm_field_op field_op;
	bool ret_val = true;

	bool compare_;
	if (rhs is lhs)
	  return ret_val;

	// Push the name on the stack
	_m_object_names ~= name;

	// Reference Fail
	if (_policy is uvm_recursion_policy_enum.UVM_REFERENCE && lhs !is rhs) {
	  print_msg_object(lhs, rhs);
	  ret_val = false;
	}

	// Fast fail on null
	if (ret_val && (rhs is null || lhs is null)) {
	  print_msg_object(lhs, rhs);
	  // if ((get_active_object_depth() == 0) && (lhs != null)) begin
	  //   uvm_report_info("MISCMP",
	  //                   $sformatf("%0d Miscompare(s) for object %s@%0d vs. null", 
	  //                             result, 
	  //                             lhs.get_name(),
	  //                             lhs.get_inst_id()),
	  //                   get_verbosity());
	  // end
	  ret_val = false;
	}

	// Hierarchical comparison
	if (ret_val) {
	  // Warn on possible infinite loop
	  uvm_policy.recursion_state_e prev_state =
	    object_compared(lhs, rhs, get_recursion_policy(), ret_val);
	  if (prev_state != uvm_policy.recursion_state_e.NEVER) // 
	    uvm_warning("UVM/COMPARER/LOOP", "Possible loop when comparing '" ~
			lhs.get_full_name() ~ "' to '" ~
			rhs.get_full_name() ~ "'");

	  push_active_object(lhs);
	  _m_recur_states[lhs][rhs][get_recursion_policy()]  =
	    state_info_t(uvm_policy.recursion_state_e.STARTED, false);
	  old_result = get_result();

	  // Check typename
	  // Implemented as if Mantis 6602 was accepted
	  if (get_check_type() && (lhs.get_object_type() !=
				   rhs.get_object_type())) {
	    if (lhs.get_type_name() != rhs.get_type_name()) {
	      print_msg("type: lhs = \"" ~ lhs.get_type_name() ~
			"\" : rhs = \"" ~ rhs.get_type_name() ~ "\"");
	    }
	    else {
	      print_msg("get_object_type() for " ~ lhs.get_name() ~
			" does not match get_object_type() for " ~ rhs.get_name());
	    }
	  }

	  field_op = uvm_field_op.m_get_available_op();
	  field_op.set(uvm_field_auto_enum.UVM_COMPARE, this, rhs);
	  lhs.do_execute_op(field_op);
	  if (field_op.user_hook_enabled()) {
	    ret_val = lhs.do_compare(rhs,this);
	  }
	  field_op.m_recycle();

	  // If do_compare() returned 1, check for a change
	  // in the result count.
	  if (ret_val && (get_result() > old_result)) {
	    ret_val = false;
	  }

	  // Save off the comparison result
	  _m_recur_states[lhs][rhs][get_recursion_policy()]  =
	    state_info_t(uvm_policy.recursion_state_e.FINISHED,	ret_val);
	  pop_active_object();
	} // if (ret_val)

	// Pop the name off the stack
	_m_object_names.length =- 1;

	// Only emit a message on a miscompare, and only if
	// we're at the top level
	if (!ret_val && (get_active_object_depth() == 0)) {
	  string msg ;

	  // If there are stored results
	  if (get_result()) {
	    // If there's a display limit that we've hit
	    if (get_show_max() && (get_show_max() < get_result()))
	      msg = format("%0d Miscompare(s) (%0d shown) for object ",
			   result, show_max);
	    // Else there's either no limit, or we didn't hit it
	    else
	      msg = format("%0d Miscompare(s) for object ", result);
	  }

	  uvm_report_debug(sev, "MISCMP", format("%s%s@%0d vs. %s@%0d", msg,
						 (lhs is null) ? "<null>" : lhs.get_name(), 
						 (lhs is null) ? 0 : lhs.get_inst_id(), 
						 (rhs is null) ? "<null>" : rhs.get_name(), 
						 (rhs is null) ? 0 : rhs.get_inst_id()),
			   get_verbosity());
        
	}
	return ret_val;
      }
    }

  // Function -- NODOCS -- compare_string
  //
  // Compares two string variables. 
  //
  // The ~name~ input is used for purposes of storing and printing a miscompare. 
  //
  // The ~lhs~ and ~rhs~ objects are the two objects used for comparison.

  bool compare(T)(string name,
		  T lhs,
		  T rhs)
    if (is (T == string)) {
      synchronized (this) {
	string msg;
	if (lhs != rhs) {
	  msg = name ~ ": " ~ "lhs = \"" ~ lhs ~ "\" : rhs = \"" ~ rhs ~ "\"";
	  print_msg(msg);
	  return false;
	}
	return true;
      }
    }

  bool compare(T)(string name,
		  T lhs,
		  T rhs)
    if (isArray!T && !is (T == string)) {
      synchronized (this) {
	string msg;

	if (lhs != rhs) {
	  import std.string: format;
	  msg = format("%s: lhs = %s,  : rhs = %s", name, lhs, rhs);
	  print_msg(msg);
	  return false;
	}
	return true;
      }
    }

  unittest {
    compare("foo", "foo", "bar");
  }

  // Function -- NODOCS -- compare_field
  //
  // Compares two integral values.
  //
  // The ~name~ input is used for purposes of storing and printing a miscompare.
  //
  // The left-hand-side ~lhs~ and right-hand-side ~rhs~ objects are the two
  // objects used for comparison.
  //
  // The size variable indicates the number of bits to compare; size must be
  // less than or equal to 4096.
  //
  // The radix is used for reporting purposes, the default radix is hex.

  // @uvm-ieee 1800.2-2017 auto 16.3.3.1
  bool compare_field(T)(string name, T lhs, T rhs,
			uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX)
    if (isBitVector!T || isIntegral!T || isBoolean!T)
  {
    synchronized (this) {
      if (lhs != rhs) {
	string msg;
	switch (radix) {
	case uvm_radix_enum.UVM_BIN:
	  msg = format("%s: lhs = 'b%0b : rhs = 'b%0b", name, lhs, rhs);
	  break;
	case uvm_radix_enum.UVM_OCT:
	  msg = format("%s: lhs = 'o%0o : rhs = 'o%0o", name, lhs, rhs);
	  break;
	case uvm_radix_enum.UVM_DEC:
	  msg = format("%s: lhs = %0d : rhs = %0d", name, lhs, rhs);
	  break;
	case uvm_radix_enum.UVM_TIME:
	  msg = format("%s: lhs = %0d : rhs = %0d", name, lhs, rhs);
	  break;
	case uvm_radix_enum.UVM_STRING:
	  msg = format("%s: lhs = %0s : rhs = %0s", name, lhs, rhs);
	  break;
	case uvm_radix_enum.UVM_ENUM:
	  //Printed as decimal, user should cuse compare string for enum val
	  msg = format("%s: lhs = %0d : rhs = %0d", name, lhs, rhs);
	  break;
	default:
	  msg = format("%s: lhs = 'h%0x : rhs = 'h%0x", name, lhs, rhs);
	  break;
	}
	print_msg(msg);
	return false;
      }
      return true;
    }
  }

  bool compare_field(string name,
		     uvm_bitstream_t lhs,
		     uvm_bitstream_t rhs,
		     int size,
		     uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      uvm_bitstream_t mask;
      string msg;

      if (size <= 64)
	return compare_field_int(name, cast (LogicVec!64)lhs, cast (LogicVec!64)rhs, size, radix);

      mask = -1;
      mask >>= (UVM_STREAMBITS-size);
      if ((lhs & mask) != (rhs & mask)) {
	switch (radix) {
	case uvm_radix_enum.UVM_BIN:
	  msg = format("%s: lhs = 'b%0b : rhs = 'b%0b",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_OCT:
	  msg = format("%s: lhs = 'o%0o : rhs = 'o%0o",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_DEC:
	  msg = format("%s: lhs = %0d : rhs = %0d",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_TIME:
	  msg = format("%s: lhs = %0d : rhs = %0d",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_STRING:
	  msg = format("%s: lhs = %0s : rhs = %0s",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_ENUM:
	  //Printed as decimal, user should cuse compare string for enum val
	  msg = format("%s: lhs = %0d : rhs = %0d",
		       name, lhs&mask, rhs&mask);
	  break;
	default:
	  msg = format("%s: lhs = 'h%0x : rhs = 'h%0x",
		       name, lhs&mask, rhs&mask);
	  break;
	}
	print_msg(msg);
	return false;
      }
      return true;
    }
  }



  // Function -- NODOCS -- compare_field_int
  //
  // This method is the same as <compare_field> except that the arguments are
  // small integers, less than or equal to 64 bits. It is automatically called
  // by <compare_field> if the operand size is less than or equal to 64.

  // @uvm-ieee 1800.2-2017 auto 16.3.3.2
  bool compare_field_int(string name,
			 uvm_integral_t lhs,
			 uvm_integral_t rhs,
			 int     size,
			 uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      LogicVec!64 mask;
      string msg;

      mask = -1;
      mask >>= (64-size);
      if ((lhs & mask) != (rhs & mask)) {
	switch (radix) {
	  import std.string: format;
	case uvm_radix_enum.UVM_BIN:
	  msg = format("%s: lhs = 'b%0b : rhs = 'b%0b",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_OCT:
	  msg = format("%s: lhs = 'o%0o : rhs = 'o%0o",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_DEC:
	  msg = format("%s: lhs = %0d : rhs = %0d",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_TIME:
	  msg = format("%s: lhs = %0d : rhs = %0d",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_STRING:
	  msg = format("%s: lhs = %0s : rhs = %0s",
		       name, lhs&mask, rhs&mask);
	  break;
	case uvm_radix_enum.UVM_ENUM:
	  //Printed as decimal, user should cuse compare string for enum val
	  msg = format("%s: lhs = %0d : rhs = %0d",
		       name, lhs&mask, rhs&mask);
	  break;
	default:
	  msg = format("%s: lhs = 'h%0x : rhs = 'h%0x",
		       name, lhs&mask, rhs&mask);
	  break;
	}
	print_msg(msg);
	return false;
      }
      return true;
    }
  }


  // Function -- NODOCS -- compare_field_real
  //
  // This method is the same as <compare_field> except that the arguments are
  // real numbers.

  // @uvm-ieee 1800.2-2017 auto 16.3.3.3
  bool compare_field_real(string name,
			  real lhs,
			  real rhs) {
    synchronized (this) {
      return compare(name, lhs, rhs);
    }
  }


  // Stores the passed-in names of the objects in the hierarchy
  private string[] _m_object_names;
  private string m_current_context(string name="") {
    synchronized (this) {
      if (_m_object_names.length  == 0)
	return name; //??
      else if ((_m_object_names.length == 1) && (name==""))
	return _m_object_names[0];
      else {
	string full_name;
	foreach (i, object_name; _m_object_names) {
	  if (i == _m_object_names.length - 1)
	    full_name ~= object_name;
	  else
	    full_name ~= object_name ~ ".";
	}
	if (name != "")
	  return full_name ~ "." ~ name;
	else
	  return full_name;
      }
    }
  }
  
  // Function -- NODOCS -- compare_object
  //
  // Compares two class objects using the <policy> knob to determine whether the
  // comparison should be deep, shallow, or reference.
  //
  // The name input is used for purposes of storing and printing a miscompare.
  //
  // The ~lhs~ and ~rhs~ objects are the two objects used for comparison.
  //
  // The ~check_type~ determines whether or not to verify the object
  // types match (the return from ~lhs.get_type_name()~ matches
  // ~rhs.get_type_name()~).

  // @uvm-ieee 1800.2-2017 auto 16.3.3.4
  bool compare_object(string name,
		      uvm_object lhs,
		      uvm_object rhs) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      int old_result ;
      uvm_field_op field_op;
      bool ret_val = true;

      if (rhs is lhs)
	return ret_val;

      // Push the name on the stack
      _m_object_names ~= name;

      // Reference Fail
      if (_policy is uvm_recursion_policy_enum.UVM_REFERENCE && lhs !is rhs) {
	print_msg_object(lhs, rhs);
	ret_val = false;
      }

      // Fast fail on null
      if (ret_val && (rhs is null || lhs is null)) {
	print_msg_object(lhs, rhs);
	// if ((get_active_object_depth() == 0) && (lhs != null)) begin
	//   uvm_report_info("MISCMP",
	//                   $sformatf("%0d Miscompare(s) for object %s@%0d vs. null", 
	//                             result, 
	//                             lhs.get_name(),
	//                             lhs.get_inst_id()),
	//                   get_verbosity());
	// end
	ret_val = false;
      }

      // Hierarchical comparison
      if (ret_val) {
	// Warn on possible infinite loop
	uvm_policy.recursion_state_e prev_state =
	  object_compared(lhs, rhs, get_recursion_policy(), ret_val);
	if (prev_state != uvm_policy.recursion_state_e.NEVER) // 
	  uvm_warning("UVM/COPIER/LOOP", "Possible loop when comparing '" ~
		      lhs.get_full_name() ~ "' to '" ~
		      rhs.get_full_name() ~ "'");

	push_active_object(lhs);
	_m_recur_states[lhs][rhs][get_recursion_policy()] =
	  state_info_t(uvm_policy.recursion_state_e.STARTED, 0);
	old_result = get_result();

	// Check typename
	// Implemented as if Mantis 6602 was accepted
	if (get_check_type() && (lhs.get_object_type() != rhs.get_object_type())) {
	  if (lhs.get_type_name() != rhs.get_type_name()) {
	    print_msg("type: lhs = \"" ~ lhs.get_type_name() ~
		      "\" : rhs = \"" ~ rhs.get_type_name() ~ "\"");
	  }
	  else {
	    print_msg("get_object_type() for " ~ lhs.get_name() ~
		      " does not match get_object_type() for " ~ rhs.get_name());
	  }
	}

	field_op = uvm_field_op.m_get_available_op();
	field_op.set(uvm_field_auto_enum.UVM_COMPARE, this, rhs);
	lhs.do_execute_op(field_op);
	if (field_op.user_hook_enabled()) {
	  ret_val = lhs.do_compare(rhs,this);
	}
	field_op.m_recycle();

	// If do_compare() returned 1, check for a change
	// in the result count.
	if (ret_val && (get_result() > old_result)) {
	  ret_val = 0;
	}

	// Save off the comparison result
	_m_recur_states[lhs][rhs][get_recursion_policy()] =
	  state_info_t(uvm_policy.recursion_state_e.FINISHED, ret_val);
	pop_active_object();
      } // if (ret_val)

      // Pop the name off the stack
      _m_object_names.length =- 1;

      // Only emit a message on a miscompare, and only if
      // we're at the top level
      if (!ret_val && (get_active_object_depth() == 0)) {
	string msg ;

	// If there are stored results
	if (get_result()) {
	  // If there's a display limit that we've hit
	  if (get_show_max() && (get_show_max() < get_result()))
	    msg = format("%0d Miscompare(s) (%0d shown) for object ",
			 result, show_max);
	  // Else there's either no limit, or we didn't hit it
	  else
	    msg = format("%0d Miscompare(s) for object ", result);
	}

	uvm_report_debug(sev, "MISCMP", format("%s%s@%0d vs. %s@%0d", msg,
					       (lhs is null) ? "<null>" : lhs.get_name(), 
					       (lhs is null) ? 0 : lhs.get_inst_id(), 
					       (rhs is null) ? "<null>" : rhs.get_name(), 
					       (rhs is null) ? 0 : rhs.get_inst_id()),
			 get_verbosity());
        
      }
      return ret_val;
    }
  }

  bool compare_struct(T)(string name,
			 T lhs,
			 T rhs) if (is (T == struct)) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      int old_result ;
      uvm_field_op field_op;
      bool ret_val = true;

      // Push the name on the stack
      _m_object_names ~= name;

      // Hierarchical comparison
      if (ret_val) {
	old_result = get_result();

	field_op = uvm_field_op.m_get_available_op();
	field_op.set(uvm_field_auto_enum.UVM_COMPARE, this);
	uvm_struct_do_execute_op(lhs, rhs, field_op);
	if (field_op.user_hook_enabled()) {
	  static if (__traits(compiles, lhs.do_compare(rhs, this))) {
	    ret_val = lhs.do_compare(rhs, this);
	  }
	}
	field_op.m_recycle();

	// If do_compare() returned 1, check for a change
	// in the result count.
	if (ret_val && (get_result() > old_result)) {
	  ret_val = false;
	}

      } // if (ret_val)

      // Pop the name off the stack
      _m_object_names.length =- 1;

      return ret_val;
    }
  }


  // Function -- NODOCS -- compare_string
  //
  // Compares two string variables.
  //
  // The ~name~ input is used for purposes of storing and printing a miscompare.
  //
  // The ~lhs~ and ~rhs~ objects are the two objects used for comparison.

  // @uvm-ieee 1800.2-2017 auto 16.3.3.6
  bool compare_string(string name,
		      string lhs,
		      string rhs) {
    synchronized (this) {
      return compare(name, lhs, rhs);
    }
  }

  // Function -- NODOCS -- print_msg
  //
  // Causes the error count to be incremented and the message, ~msg~, to be
  // appended to the <miscompares> string (a newline is used to separate
  // messages).
  //
  // If the message count is less than the <show_max> setting, then the message
  // is printed to standard-out using the current verbosity and severity
  // settings. See the <verbosity> and <sev> variables for more information.

  // @uvm-ieee 1800.2-2017 auto 16.3.3.7
  final void print_msg(string msg) {
    synchronized (this) {
      string tmp = m_current_context(msg);
      _result += 1;
      if ((get_show_max() == 0) ||
	  (get_result() <= get_show_max())) {
	msg = "Miscompare for " ~ tmp;
	uvm_report_debug(sev, "MISCMP", msg, get_verbosity());
      }
      _miscompares ~= tmp ~ "\n";
    }
  }



  // Internal methods - do not call directly


  // print_msg_object
  // ----------------

  final void print_msg_object(uvm_object lhs, uvm_object rhs) {
    synchronized (this) {
      string tmp = format("%s: lhs = @%0d : rhs = @%0d",
			  m_current_context(), 
			  (lhs !is null ? lhs.get_inst_id() : 0), 	
			  (rhs !is null ? rhs.get_inst_id() : 0));
      _result += 1;
    
      if ((get_show_max() == 0) ||
	  (get_result() <= get_show_max())) {
	uvm_report_debug(sev,
			 "MISCMP",
			 "Miscompare for " ~ tmp,
			 get_verbosity());
      }

      _miscompares ~= tmp ~ "\n";
    }
  }



  // init ??

  // static uvm_comparer init() {
  //   import uvm.base.uvm_object_globals;
  //   return uvm_default_comparer();
  // }


  // defined in SV version, but does not seem to be used anywhere
  private int depth;                      //current depth of objects


  // This variable is set by an external actor (in uvm_object)
  bool[uvm_object][uvm_object] _compare_map;

  void uvm_compare_object(T)(string name, ref T lhs, ref T rhs,
			     uvm_recursion_policy_enum policy) {
    if (!this.get_threshold() ||
	(this.get_result() < this.get_threshold())) {
      if (lhs !is rhs) {
	uvm_recursion_policy_enum prev_policy = this.get_recursion_policy();
	if (policy != uvm_recursion_policy_enum.UVM_DEFAULT_POLICY)
	  this.set_recursion_policy(policy);
	m_uvm_compare_object(name, lhs, rhs);
	if (policy != uvm_recursion_policy_enum.UVM_DEFAULT_POLICY)
	  this.set_recursion_policy(prev_policy);
      }
    }
  }

  // This macro skips the recursion policy check, which allows it to be efficiently
  // reused by other object macros.
  void m_uvm_compare_object(T)(string name, ref T lhs, ref T rhs) {
    if (this.get_recursion_policy() != uvm_recursion_policy_enum.UVM_REFERENCE) {
      bool rv;
      uvm_policy.recursion_state_e state =
	this.object_compared(lhs, rhs, this.get_recursion_policy(), rv);
      if ((state == recursion_state_e.FINISHED) &&
	  !rv)
	this.print_msg(format("'%s' miscompared using saved return value", name));
      else if (state == recursion_state_e.NEVER)
	this.compare_object(name, lhs, rhs);
      /* else skip to avoid infinite loop */
    }
    else {
      this.compare_object(name, lhs, rhs);
    }
  }

  void uvm_compare_element(E)(string name, ref E lhs, ref E rhs,
			      uvm_field_flag_t flags) {
    synchronized (this) {
      import uvm.base.uvm_misc: UVM_ELEMENT_TYPE;
      alias EE = UVM_ELEMENT_TYPE!E;
      static if (is (EE: uvm_object)) {
	uvm_recursion_policy_enum policy =
	  cast (uvm_recursion_policy_enum) (UVM_RECURSION && flags);
	if ((policy != uvm_recursion_policy_enum.UVM_DEFAULT_POLICY) &&
	    (policy != this.get_recursion_policy())) {
	  uvm_recursion_policy_enum prev_policy  = this.get_recursion_policy();
	  this.set_recursion_policy(policy);
	  m_uvm_compare_element!E(name, lhs, rhs, flags);
	  this.set_recursion_policy(prev_policy);
	}
	else {
	  m_uvm_compare_element!E(name, lhs, rhs, flags);
	}
      }
      else {
	m_uvm_compare_element!E(name, lhs, rhs, flags);
      }
    }
  }

  void m_uvm_compare_element(E)(string name, ref E lhs, ref E rhs,
				uvm_field_flag_t flags) {
    static if (isArray!E && !is (E == string)) {
      static if (isDynamicArray!E) {
	if (lhs.length != rhs.length) {
	  compare(name ~ ".length", lhs.length, rhs.length,
		  uvm_radix_enum.UVM_DEC);
	  return;
	}
      }
      for (size_t i=0; i != lhs.length; ++i) {
	m_uvm_compare_element(format("%s[%s]", name, i),
			      lhs[i], rhs[i], flags);
      }
    }
    else static if (is (E: uvm_object)) {
      auto policy = cast (uvm_recursion_policy_enum) (UVM_RECURSION && flags);
	if ((policy != uvm_recursion_policy_enum.UVM_DEFAULT_POLICY) &&
	    (policy != this.get_recursion_policy())) {
	  uvm_recursion_policy_enum prev_policy  = this.get_recursion_policy();
	  this.set_recursion_policy(policy);
	  m_uvm_compare_object(name, lhs, rhs);
	  this.set_recursion_policy(prev_policy);
	}
	else {
	  m_uvm_compare_object(name, lhs, rhs);
	}
    }
    else static if (isBitVector!E || isIntegral!E || isBoolean!E) {
      compare(name, lhs, rhs, cast (uvm_radix_enum) (flags & UVM_RADIX));
    }
    else static if (is (E == struct)) {
      compare_struct(name, lhs, rhs);
    }
    else {
      compare(name, lhs, rhs);
    }
  }
}
