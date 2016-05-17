//-----------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2012-2016 Coverify Systems Technology
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
// CLASS: uvm_comparer
//
// The uvm_comparer class provides a policy object for doing comparisons. The
// policies determine how miscompares are treated and counted. Results of a
// comparison are stored in the comparer object. The <uvm_object::compare>
// and <uvm_object::do_compare> methods are passed a uvm_comparer policy
// object.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_misc;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_coreservice;
import uvm.base.uvm_root;
import uvm.meta.misc;
import esdl.data.bvec;

import std.traits;
import std.string: format;

class uvm_comparer
{
  mixin(uvm_sync_string);

  // Variable: policy
  //
  // Determines whether comparison is UVM_DEEP, UVM_REFERENCE, or UVM_SHALLOW.

  private uvm_recursion_policy_enum _policy = UVM_DEFAULT_POLICY;


  // Variable: show_max
  //
  // Sets the maximum number of messages to send to the printer for miscompares
  // of an object.

  @uvm_public_sync
  private uint _show_max = 1;


  // Variable: verbosity
  //
  // Sets the verbosity for printed messages.
  //
  // The verbosity setting is used by the messaging mechanism to determine
  // whether messages should be suppressed or shown.

  @uvm_public_sync
  private uint _verbosity = UVM_LOW;


  // Variable: sev
  //
  // Sets the severity for printed messages.
  //
  // The severity setting is used by the messaging mechanism for printing and
  // filtering messages.

  @uvm_public_sync
  private uvm_severity _sev = UVM_INFO;


  // Variable: miscompares
  //
  // This string is reset to an empty string when a comparison is started.
  //
  // The string holds the last set of miscompares that occurred during a
  // comparison.

  @uvm_public_sync
  private string _miscompares = "";


  // Variable: physical
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The is_abstract and physical settings allow an object to distinguish between
  // two different classes of fields.
  //
  // It is up to you, in the <uvm_object::do_compare> method, to test the
  // setting of this field if you want to use the physical trait as a filter.

  @uvm_public_sync
  private bool _is_physical = true;


  // Variable: is_abstract
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The is_abstract and physical settings allow an object to distinguish between
  // two different classes of fields.
  //
  // It is up to you, in the <uvm_object::do_compare> method, to test the
  // setting of this field if you want to use the is_abstract trait as a filter.

  @uvm_public_sync
  private bool _is_abstract = true;


  // Variable: check_type
  //
  // This bit determines whether the type, given by <uvm_object::get_type_name>,
  // is used to verify that the types of two objects are the same.
  //
  // This bit is used by the <compare_object> method. In some cases it is useful
  // to set this to 0 when the two operands are related by inheritance but are
  // different types.

  @uvm_public_sync
  private bool _check_type = true;


  // Variable: result
  //
  // This bit stores the number of miscompares for a given compare operation.
  // You can use the result to determine the number of miscompares that
  // were found.

  @uvm_public_sync
  private uint _result = 0;


  // Function: compare -- templatized version

  bool compare(T)(string name,
		  T lhs,
		  T rhs,
		  uvm_radix_enum radix=UVM_NORADIX)
    if(isBitVector!T || isIntegral!T || is(T == bool))  {
      synchronized(this) {
	string msg;
	if(lhs != rhs) {
	  uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	  switch(radix) {
	  case UVM_BIN:
	    msg = format("lhs = 'b%0b : rhs = 'b%0b",
			 lhs, rhs);
	    break;
	  case UVM_OCT:
	    msg = format("lhs = 'o%0o : rhs = 'o%0o",
			 lhs, rhs);
	    break;
	  case UVM_DEC:
	    msg = format("lhs = %0d : rhs = %0d",
			 lhs, rhs);
	    break;
	  case UVM_TIME:
	    msg = format("lhs = %0d : rhs = %0d",
			 lhs, rhs);
	    break;
	  case UVM_STRING:
	    msg = format("lhs = %0s : rhs = %0s",
			 lhs, rhs);
	    break;
	  case UVM_ENUM:
	    //Printed as decimal, user should cuse compare string for enum val
	    msg = format("lhs = %0d : rhs = %0d",
			 lhs, rhs);
	    break;
	  default:
	    msg = format("lhs = 'h%0x : rhs = 'h%0x",
			 lhs, rhs);
	    break;
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
    if(isFloatingPoint!T) {
      synchronized(this) {
	string msg;

	if(lhs != rhs) {
	  import std.string: format;
	  uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	  msg = format("lhs = ", lhs, " : rhs = ", rhs);
	  print_msg(msg);
	  return false;
	}
	return true;
      }
    }

  bool compare(T)(string name,
		  T lhs,
		  T rhs)
    if(is(T == string)) {
      synchronized(this) {
	string msg;
	if(lhs != rhs) {
	  uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	  msg = "lhs = \"" ~ lhs ~ "\" : rhs = \"" ~ rhs ~ "\"";
	  print_msg(msg);
	  return false;
	}
	return true;
      }
    }

  bool compare(T)(string name,
		  T lhs,
		  T rhs)
    if(is(T: uvm_object)) {
      synchronized(this) {
	bool compare_;
	if(rhs is lhs)
	  return true;

	if(_policy == UVM_REFERENCE && lhs != rhs) {
	  uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	  print_msg_object(lhs, rhs);
	  return false;
	}

	if(rhs is null || lhs is null) {
	  uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	  print_msg_object(lhs, rhs);
	  return false;  //miscompare
	}

	uvm_object.m_uvm_status_container.scope_stack.down(name);
	compare_ = lhs.compare(rhs, this);
	uvm_object.m_uvm_status_container.scope_stack.up();
	return compare_;
      }
    }

  unittest {
    compare("foo", "foo", "bar");
  }

  // Function: compare_field
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

  bool compare_field(T)(string name, T lhs, T rhs,
			uvm_radix_enum radix=UVM_NORADIX)
    if(isBitVector!T || isIntegral!T || isBoolean!T)
  {
    synchronized(this) {
      if(lhs != rhs) {
	string msg;
	uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	switch(radix) {
	case UVM_BIN:
	  msg = format("lhs = 'b%0b : rhs = 'b%0b", lhs, rhs);
	  break;
	case UVM_OCT:
	  msg = format("lhs = 'o%0o : rhs = 'o%0o", lhs, rhs);
	  break;
	case UVM_DEC:
	  msg = format("lhs = %0d : rhs = %0d", lhs, rhs);
	  break;
	case UVM_TIME:
	  msg = format("lhs = %0d : rhs = %0d", lhs, rhs);
	  break;
	case UVM_STRING:
	  msg = format("lhs = %0s : rhs = %0s", lhs, rhs);
	  break;
	case UVM_ENUM:
	  //Printed as decimal, user should cuse compare string for enum val
	  msg = format("lhs = %0d : rhs = %0d", lhs, rhs);
	  break;
	default:
	  msg = format("lhs = 'h%0x : rhs = 'h%0x", lhs, rhs);
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
		     uvm_radix_enum radix=UVM_NORADIX) {
    synchronized(this) {
      uvm_bitstream_t mask;
      string msg;

      if(size <= 64)
	return compare_field_int(name, cast(LogicVec!64)lhs, cast(LogicVec!64)rhs, size, radix);

      mask = -1;
      mask >>= (UVM_STREAMBITS-size);
      if((lhs & mask) != (rhs & mask)) {
	uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	switch(radix) {
	case UVM_BIN:
	  msg = format("lhs = 'b%0b : rhs = 'b%0b",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_OCT:
	  msg = format("lhs = 'o%0o : rhs = 'o%0o",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_DEC:
	  msg = format("lhs = %0d : rhs = %0d",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_TIME:
	  msg = format("lhs = %0d : rhs = %0d",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_STRING:
	  msg = format("lhs = %0s : rhs = %0s",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_ENUM:
	  //Printed as decimal, user should cuse compare string for enum val
	  msg = format("lhs = %0d : rhs = %0d",
		       lhs&mask, rhs&mask);
	  break;
	default:
	  msg = format("lhs = 'h%0x : rhs = 'h%0x",
		       lhs&mask, rhs&mask);
	  break;
	}
	print_msg(msg);
	return false;
      }
      return true;
    }
  }



  // Function: compare_field_int
  //
  // This method is the same as <compare_field> except that the arguments are
  // small integers, less than or equal to 64 bits. It is automatically called
  // by <compare_field> if the operand size is less than or equal to 64.

  bool compare_field_int(string name,
			 uvm_integral_t lhs,
			 uvm_integral_t rhs,
			 int     size,
			 uvm_radix_enum radix=UVM_NORADIX) {
    synchronized(this) {
      LogicVec!64 mask;
      string msg;

      mask = -1;
      mask >>= (64-size);
      if((lhs & mask) != (rhs & mask)) {
	uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	switch(radix) {
	  import std.string: format;
	case UVM_BIN:
	  msg = format("lhs = 'b%0b : rhs = 'b%0b",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_OCT:
	  msg = format("lhs = 'o%0o : rhs = 'o%0o",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_DEC:
	  msg = format("lhs = %0d : rhs = %0d",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_TIME:
	  msg = format("lhs = %0d : rhs = %0d",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_STRING:
	  msg = format("lhs = %0s : rhs = %0s",
		       lhs&mask, rhs&mask);
	  break;
	case UVM_ENUM:
	  //Printed as decimal, user should cuse compare string for enum val
	  msg = format("lhs = %0d : rhs = %0d",
		       lhs&mask, rhs&mask);
	  break;
	default:
	  msg = format("lhs = 'h%0x : rhs = 'h%0x",
		       lhs&mask, rhs&mask);
	  break;
	}
	print_msg(msg);
	return false;
      }
      return true;
    }
  }


  // Function: compare_field_real
  //
  // This method is the same as <compare_field> except that the arguments are
  // real numbers.

  bool compare_field_real(string name,
			  real lhs,
			  real rhs) {
    synchronized(this) {
      string msg;

      if(lhs != rhs) {
	import std.string: format;
	uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	msg = format("lhs = ", lhs, " : rhs = ", rhs);
	print_msg(msg);
	return false;
      }
      return true;
    }
  }


  // Function: compare_object
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

  bool compare_object(string name,
		      uvm_object lhs,
		      uvm_object rhs) {
    synchronized(this) {
      bool compare_;
      if(rhs is lhs)
	return true;

      if(_policy is UVM_REFERENCE && lhs !is rhs) {
	uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	print_msg_object(lhs, rhs);
	return false;
      }

      if(rhs is null || lhs is null) {
	uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	print_msg_object(lhs, rhs);
	return false;  //miscompare
      }

      uvm_object.m_uvm_status_container.scope_stack.down(name);
      compare_ = lhs.compare(rhs, this);
      uvm_object.m_uvm_status_container.scope_stack.up();
      return compare_;
    }
  }


  // Function: compare_string
  //
  // Compares two string variables.
  //
  // The ~name~ input is used for purposes of storing and printing a miscompare.
  //
  // The ~lhs~ and ~rhs~ objects are the two objects used for comparison.

  bool compare_string(string name,
		      string lhs,
		      string rhs) {
    synchronized(this) {
      string msg;
      if(lhs != rhs) {
	uvm_object.m_uvm_status_container.scope_stack.set_arg(name);
	msg = "lhs = \"" ~ lhs ~ "\" : rhs = \"" ~ rhs ~ "\"";
	print_msg(msg);
	return false;
      }
      return true;
    }
  }

  // Function: print_msg
  //
  // Causes the error count to be incremented and the message, ~msg~, to be
  // appended to the <miscompares> string (a newline is used to separate
  // messages).
  //
  // If the message count is less than the <show_max> setting, then the message
  // is printed to standard-out using the current verbosity and severity
  // settings. See the <verbosity> and <sev> variables for more information.

  final void print_msg(string msg) {
    synchronized(this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root root = cs.get_root();

      _result++;
      if(_result <= _show_max) {
	msg = "Miscompare for " ~
	  uvm_object.m_uvm_status_container.scope_stack.get() ~ ": " ~ msg;
	root.uvm_report(_sev, "MISCMP", msg, _verbosity);
      }
      _miscompares = _miscompares ~
	uvm_object.m_uvm_status_container.scope_stack.get() ~ ": " ~ msg ~ "\n";
    }
  }



  // Internal methods - do not call directly

  // print_rollup
  // ------------

  //Need this function because sformat doesn't support objects
  final void print_rollup(uvm_object rhs, uvm_object lhs) {
    synchronized(this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root root = cs.get_root();
      string msg;
      if(uvm_object.m_uvm_status_container.scope_stack.depth() == 0) {
	if(_result && (_show_max || (cast(uvm_severity) _sev != UVM_INFO))) {
	  import std.string: format;
	  if(_show_max < _result)
	    msg = format("%0d Miscompare(s) (%0d shown) for object ",
			 _result, _show_max);
	  else {
	    msg = format("%0d Miscompare(s) for object ", _result);
	  }
	  root.uvm_report(_sev, "MISCMP",
			  format("%s%s@%0d vs. %s@%0d", msg,
				 lhs.get_name(), lhs.get_inst_id(),
				 rhs.get_name(), rhs.get_inst_id()),
			  _verbosity);
	}
      }
    }
  }


  // print_msg_object
  // ----------------

  final void print_msg_object(uvm_object lhs, uvm_object rhs) {
    synchronized(this) {
      import std.string: format;
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root root = cs.get_root();
      _result++;
      if(_result <= _show_max) {
	root.uvm_report(_sev, "MISCMP",
			format("Miscompare for %0s: lhs = @%0d : rhs = @%0d",
			       uvm_object.m_uvm_status_container.scope_stack.get(),
			       (lhs !is null ? lhs.get_inst_id() : 0),
			       (rhs !is null ? rhs.get_inst_id() : 0)),
			_verbosity);
      }
      _miscompares = format("%s%s: lhs = @%0d : rhs = @%0d", _miscompares,
			    uvm_object.m_uvm_status_container.scope_stack.get(),
			    (lhs !is null ? lhs.get_inst_id() : 0),
			    (rhs !is null ? rhs.get_inst_id() : 0));
    }
  }



  // init ??

  static uvm_comparer init() {
    return uvm_default_comparer();
  }


  // defined in SV version, but does not seem to be used anywhere
  // private int depth;                      //current depth of objects


  // This variable is set by an external actor (in uvm_object)
  private uvm_object[uvm_object] _compare_map;
  void set_compare_map(uvm_object lhs, uvm_object rhs) {
    synchronized(this) {
      _compare_map[lhs] = rhs;
    }
  }
  
  uvm_object get_compare_map(uvm_object obj) {
    synchronized(this) {
      if(obj in _compare_map) {
	return _compare_map[obj];
      }
      else {
	return null;
      }
    }
  }

  void reset_compare_map() {
    synchronized(this) {
      _compare_map = null;
    }
  }

  @uvm_public_sync
  private uvm_scope_stack _scope_stack;

  this() {
    synchronized(this) {
      _scope_stack = new uvm_scope_stack();
    }
  }

} // endclass
