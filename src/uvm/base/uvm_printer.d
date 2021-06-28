//
//------------------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2007-2018 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2018 Qualcomm, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2020 Marvell International Ltd.
// Copyright 2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2014-2018 Cisco Systems, Inc.
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


module uvm.base.uvm_printer;

import std.conv: to;
import esdl.base.core: SimTime;
import std.traits: isFloatingPoint;
import std.string: format;


enum int UVM_STDOUT = 1;  // Writes to standard out and logfile

import esdl.data.bvec;

import uvm.base.uvm_misc: uvm_bitvec_to_string, uvm_leaf_scope,
  uvm_object_value_str;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_policy: uvm_policy;
import uvm.base.uvm_object_globals: uvm_radix_enum, UVM_FILE,
  uvm_recursion_policy_enum, uvm_field_auto_enum, uvm_field_flag_t,
  UVM_RADIX, UVM_RECURSION;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_traversal: uvm_structure_proxy;
import uvm.base.uvm_scope: uvm_scope_base;
import uvm.base.uvm_coreservice: uvm_coreservice_t;
import uvm.base.uvm_globals: uvm_error, uvm_warning;
import uvm.base.uvm_field_op: uvm_field_op;

import uvm.meta.misc;
import uvm.meta.meta;
import std.traits: isIntegral, isBoolean, isArray;

// File: uvm_printer
  
// @uvm-ieee 1800.2-2017 auto 16.2.1
abstract class uvm_printer: uvm_policy
{

  mixin uvm_abstract_object_essentials;

  this(string name="") {
    synchronized (this) {
      super(name);
      _knobs = new m_uvm_printer_knobs();
      flush();
    }
  }

  mixin (uvm_sync_string);

  @uvm_private_sync
  private bool _m_flushed ; // 0 = needs flush, 1 = flushed since last use

  // Variable: knobs
  //
  // The knob object provides access to the variety of knobs associated with a
  // specific printer instance.
  //
  @uvm_immutable_sync
  private m_uvm_printer_knobs _knobs; // = new;

  protected m_uvm_printer_knobs get_knobs() {
    synchronized (this) {
      return _knobs;
    }
  }

  @uvm_public_sync
  private string _m_string;


  // Group -- NODOCS -- Methods for printer usage

  // These functions are called from <uvm_object::print>, or they are called
  // directly on any data to get formatted printing.

  static void set_default(uvm_printer printer) {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get() ;
    coreservice.set_default_printer(printer);
  }

  static uvm_printer get_default() {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get();
    return coreservice.get_default_printer();
  }

  // Function -- NODOCS -- print_field
  //
  // Prints an integral field (up to 4096 bits).
  //
  // name  - The name of the field.
  // value - The value of the field.
  // size  - The number of bits of the field (maximum is 4096).
  // radix - The radix to use for printing. The printer knob for radix is used
  //           if no radix is specified.
  // scope_separator - is used to find the leaf name since many printers only
  //           print the leaf name of a field.  Typical values for the separator
  //           are . (dot) or [ (open bracket).

  // @uvm-ieee 1800.2-2017 auto 16.2.3.8
  void print(T)(string          name,
		T               value,
		uvm_radix_enum  radix=uvm_radix_enum.UVM_NORADIX,
		char            scope_separator='.',
		string          type_name="")
    if (isBitVector!T || isIntegral!T || is (T: bool)) {
      print_integral!T(name, value, -1, radix, scope_separator, type_name);
    }


  void print_integral(T)(string          name,
			 T               value,
			 ptrdiff_t       size = -1,
			 uvm_radix_enum  radix=uvm_radix_enum.UVM_NORADIX,
			 char            scope_separator='.',
			 string          type_name="")
    if (isBitVector!T || isIntegral!T || is (T: bool)) {
      import std.conv: to;
      synchronized (this) {
	if (type_name == "") {
	  if (radix is uvm_radix_enum.UVM_TIME)        type_name = "time";
	  else if (radix is uvm_radix_enum.UVM_STRING) type_name = "string";
	  else if (radix is uvm_radix_enum.UVM_ENUM)   type_name = qualifiedTypeName!T ~
							 " (enum)";
	  else {
	    static if (isBitVector!T) {
	      static if (! T.ISSIGNED) type_name = "U";
	      enum int SIZE = cast (int) T.SIZE;
	      static if (T.IS4STATE) type_name ~= "Logic!" ~ SIZE.stringof;
	      else type_name ~= "Bit!" ~ SIZE.stringof;
	    }
	    else {
	      type_name = qualifiedTypeName!T;
	    }
	  }
	}


	if (size < 0) {
	  static if (is (T: bool)) {
	    size = 1;
	  }
	  else static if (isBitVector!T) {
	    size = T.SIZE;
	  }
	  else static if (isIntegral!T) {
	    size = T.sizeof * 8;
	  }
	}

	string sz_str = size.to!string;


	if (radix is uvm_radix_enum.UVM_NORADIX) {
	  static if (is (T == enum)) {
	    radix = uvm_radix_enum.UVM_ENUM;
	  }
	  else {
	    radix = get_default_radix();
	  }
	}

	string val_str = uvm_bitvec_to_string(value, size, radix,
					      get_radix_string(radix));

	name = uvm_leaf_scope(name, scope_separator);

	push_element(name,type_name,sz_str,val_str);
	pop_element() ;

      }
    }

  // @uvm-ieee 1800.2-2017 auto 16.2.3.9
  alias print_field_int = print_integral;
  alias print_field = print_integral;

  // Function -- NODOCS -- print_object
  //
  // Prints an object. Whether the object is recursed depends on a variety of
  // knobs, such as the depth knob; if the current depth is at or below the
  // depth setting, then the object is not recursed.
  //
  // By default, the children of <uvm_components> are printed. To turn this
  // behavior off, you must set the <uvm_component::print_enabled> bit to 0 for
  // the specific children you do not want automatically printed.

  void print(T)(string     name,
		T          value,
		char       scope_separator='.')
    if (is (T: uvm_object)) {
      import uvm.base.uvm_component;
      synchronized (this) {
	uvm_recursion_policy_enum recursion_policy = get_recursion_policy();

	if ((value is null) ||
	    (recursion_policy == uvm_recursion_policy_enum.UVM_REFERENCE) ||
	    (get_max_depth() == get_active_object_depth())) {
	  print_object_header(name, value, scope_separator); // calls push_element
	  pop_element();
	}
	else {
	  push_active_object(value);
	  _m_recur_states[value][recursion_policy] =
	    uvm_policy.recursion_state_e.STARTED;
	  print_object_header(name, value, scope_separator); // calls push_element

	  uvm_field_op field_op = uvm_field_op.m_get_available_op() ;
	  field_op.set(uvm_field_auto_enum.UVM_PRINT, this, null);
	  value.do_execute_op(field_op);
	  if (field_op.user_hook_enabled()) {
	    value.do_print(this);
	  }
	  field_op.m_recycle();

	  pop_element() ; // matches push in print_object_header

	  _m_recur_states[value][recursion_policy] =
	    uvm_policy.recursion_state_e.FINISHED ;
	  pop_active_object();
	}
      }
    }

  // @uvm-ieee 1800.2-2017 auto 16.2.3.1
  alias print_object = print;

  void print(T)(string     name,
		T          value,
		char       scope_separator='.')
       if (is (T == struct) && ! is (T == SimTime)) {
	 import uvm.base.uvm_component;
	 synchronized (this) {
	   print_object_header(name, value, scope_separator); // calls push_element

	   uvm_field_op field_op = uvm_field_op.m_get_available_op() ;
	   field_op.set(uvm_field_auto_enum.UVM_PRINT, this, null);
	   uvm_struct_do_execute_op(value, field_op);
	   if (field_op.user_hook_enabled()) {
	     static if (__traits(compiles, value.do_print(this))) {
	       value.do_print(this);
	     }
	   }
	   field_op.m_recycle();

	   pop_element() ; // matches push in print_object_header

	 }
       }


  void print_object_header (string name,
			    uvm_object value,
			    char scope_separator='.') {
    synchronized (this) {
      if (name == "") {
	name = "<unnamed>";
      }

      push_element(name,
		   (value !is null) ?  value.get_type_name() : "object",
		   "-",
		   get_id_enabled() ? uvm_object_value_str(value) : "-");
    }
  }

  void print_object_header(T) (string name,
			       T value,
			       char scope_separator='.') if (is (T == struct)) {
    synchronized (this) {
      if (name == "") {
	name = "<unnamed>";
      }

      push_element(name,
		   "struct(" ~ T.stringof ~ ")",
		   "-", "-");
    }
  }


  // Function -- NODOCS -- print_string
  //
  // Prints a string field.

  void print(T)(string name,
		T      value,
		char   scope_separator = '.')
    if (is (T == string)) {
      synchronized (this) {
	push_element(name,
		     "string",
		     format("%0d", value.length),
		     (value == "" ? "\"\"" : value));
	pop_element() ;
      }
    }

  // @uvm-ieee 1800.2-2017 auto 16.2.3.10
  alias print_string = print;

  private
  uvm_policy.recursion_state_e[uvm_recursion_policy_enum][uvm_object] _m_recur_states;

  // @uvm-ieee 1800.2-2017 auto 16.2.3.2
  uvm_policy.recursion_state_e object_printed(uvm_object value,
					      uvm_recursion_policy_enum recursion) {
    synchronized (this) {
      if (value !in _m_recur_states) return uvm_policy.recursion_state_e.NEVER ;
      if ( recursion !in _m_recur_states[value]) return uvm_policy.recursion_state_e.NEVER ;
      else return _m_recur_states[value][recursion] ;
    }
  }

  // Function -- NODOCS -- print_time
  //
  // Prints a time value. name is the name of the field, and value is the
  // value to print.
  //
  // The print is subject to the ~$timeformat~ system task for formatting time
  // values.

  void print(T)(string name,
		T      value,
		char   scope_separator='.')
    if (is (T == SimTime)) {
      synchronized (this) {
	print(name, value.to!ulong, uvm_radix_enum.UVM_TIME, scope_separator);
      }
    }

  // @uvm-ieee 1800.2-2017 auto 16.2.3.11
  alias print_time = print;

  // Function -- NODOCS -- print_real
  //
  // Prints a string field.

  void print(T)(string  name,
		T       value,
		char    scope_separator = '.')
    if (isFloatingPoint!T) {
      synchronized (this) {
	push_element(name, "real", format("%s", T.sizeof * 8), format("%f",value));
	pop_element() ;
      }
    }

  // @uvm-ieee 1800.2-2017 auto 16.2.3.12
  alias print_real = print;

  // Function -- NODOCS -- print_generic
  //
  // Prints a field having the given ~name~, ~type_name~, ~size~, and ~value~.

  // @uvm-ieee 1800.2-2017 auto 16.2.3.3
  void print_generic(string name, string type_name, size_t size,
		     string value, char scope_separator='.') {
    synchronized (this) {
      push_element(name,
		   type_name,
		   (size == -2 ? "..." : format("%0d", size)),
		   value);
      pop_element();
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.3.4
  void print_generic_element(string  name, string  type_name,
			     string  size, string  value) {
    synchronized (this) {
      push_element(name, type_name, size, value);
      pop_element() ;
    }
  }

  // Group -- NODOCS -- Methods for printer subtyping

  // Function -- NODOCS -- emit
  //
  // Emits a string representing the contents of an object
  // in a format defined by an extension of this object.
  //
  abstract string emit();		// abstract
  //  {
  //   uvm_error("NO_OVERRIDE","emit() method not overridden in printer subtype");
  //   return "";
  // }

  override void flush() {
    synchronized (this) {
      // recycle all elements that were on the stack
      uvm_printer_element element = get_bottom_element();
      uvm_printer_element[] all_descendent_elements;

      element = get_bottom_element();
      if (element !is null) {
	element.get_children(all_descendent_elements, true) ; //recursive
	foreach (descendent_element; all_descendent_elements) {
	  _m_recycled_elements ~= descendent_element;
	  descendent_element.clear_children();
	}
	element.clear_children();
	_m_recycled_elements ~= element;
	// now delete the stack
	_m_element_stack.length = 0;
      }
      _m_recur_states.clear();
      _m_flushed = true;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.1
  void set_name_enabled(bool enabled) {
    synchronized (this) {
      _knobs.identifier = enabled;
    }
  }
  // @uvm-ieee 1800.2-2017 auto 16.2.5.1
  bool get_name_enabled() {
    synchronized (this) {
      return _knobs.identifier;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.2
  void set_type_name_enabled(bool enabled) {
    synchronized (this) {
      _knobs.type_name = enabled;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.2
  bool get_type_name_enabled() {
    synchronized (this) {
      return _knobs.type_name;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.3
  void set_size_enabled(bool enabled) {
    synchronized (this) {
      _knobs.size = enabled;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.3
  bool get_size_enabled() {
    synchronized (this) {
      return _knobs.size;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.4
  void set_id_enabled(bool enabled) {
    synchronized (this) {
      _knobs.reference = enabled;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.4
  bool get_id_enabled() {
    synchronized (this) {
      return _knobs.reference;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.5
  void set_radix_enabled(bool enabled) {
    synchronized (this) {
      _knobs.show_radix = enabled;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.5
  bool get_radix_enabled() {
    synchronized (this) {
      return _knobs.show_radix;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.6
  void set_radix_string(uvm_radix_enum radix, string prefix) {
    synchronized (this) {
      if (radix == uvm_radix_enum.UVM_DEC) _knobs.dec_radix = prefix ;
      else if (radix == uvm_radix_enum.UVM_BIN) _knobs.bin_radix = prefix ;
      else if (radix == uvm_radix_enum.UVM_OCT) _knobs.oct_radix = prefix ;
      else if (radix == uvm_radix_enum.UVM_UNSIGNED) _knobs.unsigned_radix = prefix ;
      else if (radix == uvm_radix_enum.UVM_HEX) _knobs.hex_radix = prefix ;
      else uvm_warning("PRINTER_UNKNOWN_RADIX",
		       format("set_radix_string called with unsupported radix %s", radix));
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.6
  string get_radix_string(uvm_radix_enum radix) {
    synchronized (this) {
      if (radix == uvm_radix_enum.UVM_DEC) return _knobs.dec_radix ;
      else if (radix == uvm_radix_enum.UVM_BIN) return _knobs.bin_radix ;
      else if (radix == uvm_radix_enum.UVM_OCT) return _knobs.oct_radix ;
      else if (radix == uvm_radix_enum.UVM_UNSIGNED) return _knobs.unsigned_radix ;
      else if (radix == uvm_radix_enum.UVM_HEX) return _knobs.hex_radix ;
      else return "";
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.7
  void set_default_radix(uvm_radix_enum radix) {
    synchronized (this) {
      _knobs.default_radix = radix;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.7
  uvm_radix_enum get_default_radix() {
    synchronized (this) {
      return _knobs.default_radix;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.8
  void set_root_enabled(bool enabled) {
    synchronized (this) {
      _knobs.show_root = enabled;
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 16.2.5.8
  bool get_root_enabled() {
    synchronized (this) {
      return _knobs.show_root;
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 16.2.5.9
  void set_recursion_policy(uvm_recursion_policy_enum policy) {
    synchronized (this) {
      _knobs.recursion_policy = policy;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.9
  uvm_recursion_policy_enum get_recursion_policy() {
    synchronized (this) {
      return _knobs.recursion_policy;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.10
  void set_max_depth(int depth) {
    synchronized (this) {
      _knobs.depth = depth;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.10
  int get_max_depth() {
    synchronized (this) {
      return _knobs.depth;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.11
  void set_file(UVM_FILE fl) {
    synchronized (this) {
      _knobs.mcd = fl;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.11
  UVM_FILE get_file() {
    synchronized (this) {
      return _knobs.mcd;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.12
  void set_line_prefix(string prefix) {
    synchronized (this) {
      _knobs.prefix = prefix;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.5.12
  string get_line_prefix() {
    synchronized (this) {
      return _knobs.prefix;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.6
  void set_begin_elements(int elements = 5) {
    synchronized (this) {
      _knobs.begin_elements = elements;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.6
  int get_begin_elements() {
    synchronized (this) {
      return _knobs.begin_elements;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.6
  void set_end_elements(int elements = 5) {
    synchronized (this) {
      _knobs.end_elements = elements;
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 16.2.6
  int get_end_elements() {
    synchronized (this) {
      return _knobs.end_elements;
    }
  }

  private uvm_printer_element[] _m_element_stack;

  protected int m_get_stack_size() {
    synchronized (this) {
      return cast (uint) _m_element_stack.length;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.7.1
  protected uvm_printer_element get_bottom_element() {
    synchronized (this) {
      if (_m_element_stack.length > 0) {
	return _m_element_stack[0];
      }
      else return null ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.7.2
  protected uvm_printer_element get_top_element() {
    synchronized (this) {
      if (_m_element_stack.length > 0) {
	return _m_element_stack[$-1];
      }
      else return null ;
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 16.2.7.3
  void push_element(string name, string type_name,
		    string size, string value="") {
    synchronized (this) {
      uvm_printer_element element = get_unused_element() ;
      uvm_printer_element parent = get_top_element() ;
      element.set(name, type_name, size, value);
      if (parent !is null) parent.add_child(element) ;
      _m_element_stack ~= element;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.7.4
  void pop_element () {
    synchronized (this) {
      if (_m_element_stack.length > 1) {
	_m_element_stack.length -= 1;
      }
    }
  }
    
  
  // return an element from the recycled stack if available or a new one otherwise
  uvm_printer_element get_unused_element() {
    synchronized (this) {
      uvm_printer_element element ;
      if (_m_recycled_elements.length > 0) {
	element = _m_recycled_elements[$-1];
	_m_recycled_elements.length -= 1;
      }
      else {
	element = new uvm_printer_element() ;
      }
      return element ;
    }
  }

  // store element instances that have been created but are not currently on the stack
  uvm_printer_element[] _m_recycled_elements;

  // Function -- NODOCS -- print_array_header
  //
  // Prints the header of an array. This function is called before each
  // individual element is printed. <print_array_footer> is called to mark the
  // completion of array printing.

  // @uvm-ieee 1800.2-2017 auto 16.2.3.5
  void print_array_header(string name, size_t size,
			  string arraytype="array", char scope_separator='.') {
    synchronized (this) {
      push_element(name, arraytype, format("%0d", size), "-");
    }
  }

  // Function -- NODOCS -- print_array_range
  //
  // Prints a range using ellipses for values. This method is used when honoring
  // the array knobs for partial printing of large arrays,
  // <m_uvm_printer_knobs::begin_elements> and <m_uvm_printer_knobs::end_elements>.
  //
  // This function should be called after begin_elements have been printed
  // and before end_elements have been printed.

  // @uvm-ieee 1800.2-2017 auto 16.2.3.6
  void print_array_range (int min, int max) {
    // string tmpstr; // redundant -- declared in the SV version
    if (min == -1 && max == -1) {
      return;
    }
    if (min == -1) {
      min = max;
    }
    if (max == -1) {
      max = min;
    }
    if (max < min) {
      return;
    }
    print_generic_element("...", "...", "...", "...");
  }


  // Function -- NODOCS -- print_array_footer
  //
  // Prints the header of a footer. This function marks the end of an array
  // print. Generally, there is no output associated with the array footer, but
  // this method lets the printer know that the array printing is complete.

  // @uvm-ieee 1800.2-2017 auto 16.2.3.7
  void print_array_footer (size_t size=0) {
    synchronized (this) {
      pop_element() ;
    }
  }


  // Utility methods
  final bool istop() {
    synchronized (this) {
      return (get_active_object_depth() == 0);
    }
  }

  static string index_string (int index, string name="") {
    return name ~ "[" ~ index.to!string() ~ "]";
  }


  void uvm_print_element(E)(string name, ref E elem,
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
	  m_uvm_print_element!E(name, elem, flags);
	  this.set_recursion_policy(prev_policy);
	}
	else {
	  m_uvm_print_element!E(name, elem, flags);
	}
      }
      else {
	m_uvm_print_element!E(name, elem, flags);
      }
    }
  }
  
  void m_uvm_print_element(E)(string name, ref E elem,
			      uvm_field_flag_t flags) {
    static if (isArray!E && !is (E == string)) {
      print_array_header(name, elem.length, E.stringof);
      auto begin_elements = get_begin_elements();
      auto end_elements = get_end_elements();
      if (get_max_depth() == -1 ||
	  get_active_object_depth() < get_max_depth()+1) {
	if (begin_elements == -1 || end_elements == -1) {
	  foreach (index, ref ee; elem) {
	    m_uvm_print_element(format("%s[%0d]", name, index), ee, flags);
	  }
	}
	else {
	  int curr;
	  foreach (index, ref ee; elem) {
	    if (curr < begin_elements) {
	      m_uvm_print_element(format("%s[%0d]", name, index), ee, flags);
	    }
	    else break;
	    curr += 1;
	  }
	  if (curr < elem.length ) {
	    if ((elem.length - end_elements) > curr)
	      curr  = cast (int) elem.length - end_elements;
	    if (curr < begin_elements)
	      curr = begin_elements;
	    else
	      print_array_range(begin_elements, curr-1);
	    while (curr < elem.length) {
	      m_uvm_print_element(format("%s[%0d]", name, curr), elem[curr], flags);
	      curr += 1;
	    }
	  }
	}
      }
      print_array_footer(elem.length);
    }
    else static if (is (E: uvm_object)) {
      if (this.object_printed(elem, this.get_recursion_policy()) !=
	  recursion_state_e.NEVER) {
	// only print a reference if already printed to avoid recrusive print
	uvm_recursion_policy_enum prev_policy = this.get_recursion_policy();
	this.set_recursion_policy(uvm_recursion_policy_enum.UVM_REFERENCE);
	this.print(name, elem);
	this.set_recursion_policy(prev_policy);
      }
      else {
	this.print(name, elem);
      }
    }
    else static if (isBitVector!E || isIntegral!E || isBoolean!E) {
      print(name, elem, cast (uvm_radix_enum) (flags & UVM_RADIX));
    }
    else {
      print(name, elem);
    }
  }
}

// @uvm-ieee 1800.2-2017 auto 16.2.8.1
class uvm_printer_element: uvm_object
{

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.1
  this(string name="") {
    synchronized (this) {
      super(name);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.2
  void set(string element_name = "", string element_type_name = "",
	   string element_size = "", string element_value = "") {
    synchronized (this) {
      _m_name = element_name ;
      _m_type_name = element_type_name ;
      _m_size = element_size ;
      _m_value = element_value ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.3
  void set_element_name (string element_name) {
    synchronized (this) {
      _m_name = element_name;
    }
  }
    
  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.3
  string get_element_name () {
    synchronized (this) {
      return _m_name;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.4
  void set_element_type_name (string element_type_name) {
    synchronized (this) {
      _m_type_name = element_type_name;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.4
  string get_element_type_name () {
    synchronized (this) {
      return _m_type_name;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.5
  void set_element_size (string element_size) {
    synchronized (this) {
      _m_size = element_size;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.5
  string get_element_size () {
    synchronized (this) {
      return _m_size;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.6
  void set_element_value (string element_value) {
    synchronized (this) {
      _m_value = element_value;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.8.2.6
  string get_element_value () {
    synchronized (this) {
      return _m_value;
    }
  }

  void add_child(uvm_printer_element child) {
    synchronized (this) {
      _m_children ~= child;
    }
  }
    
  void get_children(ref uvm_printer_element[] children, in bool recurse) {
    synchronized (this) {
      foreach (child; _m_children) {
	children ~= child;
	if (recurse) {
	  child.get_children(children, true) ;
	}
      }
    }
  }
  
  void clear_children() {
    synchronized (this) {
      _m_children.length = 0;
    }
  }

  private string _m_name;
  private string _m_type_name;
  private string _m_size;
  private string _m_value;
  private uvm_printer_element[] _m_children;
}

// @uvm-ieee 1800.2-2017 auto 16.2.9.1
class uvm_printer_element_proxy: uvm_structure_proxy!(uvm_printer_element)
{
  // @uvm-ieee 1800.2-2017 auto 16.2.9.2.1
  this (string name="") {
    synchronized (this) {
      super(name);
    }
  }
  // @uvm-ieee 1800.2-2017 auto 16.2.9.2.2
  static void get_immediate_children(uvm_printer_element s,
				     ref uvm_printer_element[] children) {
    s.get_children(children, false);
  }
    
}

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_table_printer
//
// The table printer prints output in a tabular format.
//
// The following shows sample output from the table printer.
//
//|  ---------------------------------------------------
//|  Name        Type            Size        Value
//|  ---------------------------------------------------
//|  c1          container       -           @1013
//|  d1          mydata          -           @1022
//|  v1          integral        32          'hcb8f1c97
//|  e1          enum            32          THREE
//|  str         string          2           hi
//|  value       integral        12          'h2d
//|  ---------------------------------------------------
//
//------------------------------------------------------------------------------

//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

// @uvm-ieee 1800.2-2017 auto 16.2.10.1
class uvm_table_printer: uvm_printer
{

  // @uvm-ieee 1800.2-2017 auto 16.2.10.2.2
  mixin uvm_object_essentials;

  mixin (uvm_sync_string);

  // @uvm-ieee 1800.2-2017 auto 16.2.10.2.1
  this(string name="") {
    synchronized (this) {
      super(name);
    }
  }

  // Function -- NODOCS -- emit
  //
  // Formats the collected information from prior calls to ~print_*~
  // into table format.
  //
  override final string emit() {
    synchronized (this) {
      char[] s;
      string user_format;
      static char[] dash; // = "---------------------------------------------------------------------------------------------------";
      char[] dashes;

      string linefeed;

      if (!_m_flushed) {
	uvm_error("UVM/PRINT/NO_FLUSH",
		  "printer emit() method called twice without intervening uvm_printer::flush()");
      }
      else {
	_m_flushed = 0 ;
      }
      linefeed = "\n" ~ get_line_prefix();

      import std.algorithm: max;
      size_t m = max(_m_max_name, _m_max_type, _m_max_size, _m_max_value, 100);

      if (dash.length < m) {
	dash.length = m;
	dash[] = '-';
	_m_space.length = m;
	_m_space[] = ' ';
      }

      string header;
      // string dash_id, dash_typ, dash_sz;
      // string head_id, head_typ, head_sz;
      if (get_name_enabled()) {
	dashes = dash[0.._m_max_name+2];
	header = "Name" ~ cast (string) _m_space[0.._m_max_name-2];
      }
      if (get_type_name_enabled()) {
	dashes ~= dash[0.._m_max_type+2];
	header ~= "Type" ~ cast (string) _m_space[0.._m_max_type-2];
      }
      if (get_size_enabled()) {
	dashes ~= dash[0.._m_max_size+2];
	header ~= "Size" ~ cast (string) _m_space[0.._m_max_size-2];
      }
      dashes ~= dash[0.._m_max_value] ~ linefeed;
      header ~= "Value" ~ cast (string) _m_space[0..m_max_value-5] ~ linefeed;

      s ~= dashes ~ header ~ dashes;

      s ~= m_emit_element(get_bottom_element(),0) ;

      s ~= dashes; // add dashes for footer

      return cast (string) (get_line_prefix() ~ s);
    }
  }

  string m_emit_element(uvm_printer_element element, uint level) {
    synchronized (this) {
      string result ;
      // static uvm_printer_element_proxy proxy = new("proxy") ;
      uvm_printer_element[] element_children;
      string linefeed;

      linefeed = "\n" ~ get_line_prefix();

      string name_str = element.get_element_name() ;
      string value_str = element.get_element_value() ;
      string type_name_str = element.get_element_type_name() ;
      string size_str = element.get_element_size() ;

      if (get_name_enabled()) {
	result ~= _m_space[0..level * get_indent()] ~ name_str ~
	  _m_space[0..(_m_max_name - name_str.length - (level*get_indent())+2)];
      }
      if (get_type_name_enabled()) {
	result ~= type_name_str ~ _m_space[0.._m_max_type-type_name_str.length+2];
      }
      if (get_size_enabled()) {
	result ~= size_str ~ _m_space[0.._m_max_size-size_str.length+2];
      }
      result ~= value_str ~ _m_space[0.._m_max_value-value_str.length] ~ linefeed;
    
      uvm_printer_element_proxy.get_immediate_children(element, element_children) ;
      foreach (child; element_children) {
	result ~= m_emit_element(child, level+1);
      }
      return result ;
    }
  }

  mixin (uvm_scope_sync_string);
  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private uvm_table_printer _m_default_table_printer ;
  }

  private char[] _m_space;

  // @uvm-ieee 1800.2-2017 auto 16.2.10.2.3
  static void set_default(uvm_table_printer printer) {
    synchronized (_uvm_scope_inst) {
      _m_default_table_printer = printer;
    }
  }

  // Function: get_default
  // Implementation of uvm_table_printer::get_default as defined in
  // section 16.2.10.2.3 of 1800.2-2017.
  //
  // *Note:*
  // The library implements get_default as described in IEEE 1800.2-2017
  // with the exception that this implementation will instance a
  // uvm_table_printer if the most recent call to set_default() used an
  // argument value of null.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto 16.2.10.2.4
  static uvm_table_printer get_default() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_default_table_printer is null) {
	_uvm_scope_inst._m_default_table_printer =
	  new uvm_table_printer("uvm_default_table_printer") ;
      }
      return _uvm_scope_inst._m_default_table_printer ;
    }
  }
    

  // @uvm-ieee 1800.2-2017 auto 16.2.10.3
  void set_indent(int indent) {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      knobs.indent = indent;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.10.3
  int get_indent() {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      return knobs.indent;
    }
  }

  override void flush() {
    synchronized (this) {
      super.flush() ;
      _m_max_name = 4;
      _m_max_type = 4;
      _m_max_size = 4;
      _m_max_value = 5;
      //set_indent(2) ; // LRM says to include this call
    }
  }
    

  // Variables- m_max_*
  //
  // holds max size of each column, so table columns can be resized dynamically

  @uvm_protected_sync
  private int _m_max_name=4;
  @uvm_protected_sync
  private int _m_max_type=4;
  @uvm_protected_sync
  private int _m_max_size=4;
  @uvm_protected_sync
  private int _m_max_value=5;

  override void pop_element() {
    synchronized (this) {
      uvm_printer_element popped = get_top_element() ;
      int level = m_get_stack_size() - 1 ;
      string name_str = popped.get_element_name() ;
      string type_name_str = popped.get_element_type_name() ;
      string size_str = popped.get_element_size() ;
      string value_str = popped.get_element_value() ;

      if ((name_str.length + (get_indent() * level)) > _m_max_name) {
	_m_max_name = cast (uint) (name_str.length + (get_indent() * level));
      }
      if (type_name_str.length > _m_max_type) {
	_m_max_type = cast (uint) type_name_str.length;
      }
      if (size_str.length > _m_max_size) {
	_m_max_size = cast (uint) size_str.length;
      }
      if (value_str.length > _m_max_value) {
	_m_max_value = cast (uint) value_str.length;
      }

      super.pop_element() ;
    }
  }


}


//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_tree_printer
//
// By overriding various methods of the <uvm_printer> super class,
// the tree printer prints output in a tree format.
//
// The following shows sample output from the tree printer.
//
//|  c1: (container@1013) {
//|    d1: (mydata@1022) {
//|         v1: 'hcb8f1c97
//|         e1: THREE
//|         str: hi
//|    }
//|    value: 'h2d
//|  }
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 16.2.11.1
class uvm_tree_printer: uvm_printer
{
  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);

  @uvm_private_sync
  private string _m_newline = "\n";
  @uvm_private_sync
  private string _m_linefeed ;

  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private uvm_tree_printer _m_default_tree_printer ;
  }
  
  // @uvm-ieee 1800.2-2017 auto 16.2.11.2.2
  mixin uvm_object_essentials;

  // Variable -- NODOCS -- new
  //
  // Creates a new instance of ~uvm_tree_printer~.

  // @uvm-ieee 1800.2-2017 auto 16.2.11.2.1
  this(string name="") {
    synchronized (this) {
      super(name);
      set_size_enabled(0);
      set_type_name_enabled(0);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.11.2.3
  static void set_default(uvm_tree_printer printer) {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m_default_tree_printer = printer ;
    }
  }

  // Function: get_default
  // Implementation of uvm_tree_printer::get_default as defined in
  // section 16.2.11.2.4 of 1800.2-2017.
  //
  // *Note:*
  // The library implements get_default as described in IEEE 1800.2-2017
  // with the exception that this implementation will instance a
  // uvm_tree_printer if the most recent call to set_default() used an
  // argument value of null.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto 16.2.11.2.4
  static uvm_tree_printer get_default() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_default_tree_printer is null) {
	_uvm_scope_inst._m_default_tree_printer =
	  new uvm_tree_printer("uvm_default_tree_printer") ;
      }
      return _uvm_scope_inst._m_default_tree_printer ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.11.3.1
  void set_indent(int indent) {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      knobs._indent = indent;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.11.3.1
  int get_indent() {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      return knobs.indent;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.11.3.2
  void set_separators(string separators) {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      knobs._separator = separators ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.11.3.2
  string get_separators() {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      return knobs._separator ;
    }
  }

  override void flush() {
    synchronized (this) {
      super.flush() ;
      //set_indent(2) ; // LRM says to include this call
      //set_separators("{}"); // LRM says to include this call
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.4.1
  override final string emit() {
    synchronized (this) {

      string s;
      string user_format;
      // uint level;
      // uvm_printer_element element;

      if (!_m_flushed) {
	uvm_error("UVM/PRINT/NO_FLUSH",
		  "printer emit() method called twice without intervening uvm_printer::flush()");
      }
      else {
	_m_flushed = false;
      }

      s = get_line_prefix();
      _m_linefeed = (_m_newline == "" || _m_newline == " ") ?
	_m_newline : _m_newline ~ get_line_prefix();

      s ~= m_emit_element(get_bottom_element(), 0);

      if (_m_newline == "" || _m_newline == " ") {
	s ~= "\n";
      }

      return s;
    }
  }

  string m_emit_element(uvm_printer_element element,
			uint level) {
    synchronized (this) {
      string result ;
      string space= "                                                                                                   ";
      // static uvm_printer_element_proxy proxy = new("proxy") ;
      uvm_printer_element[] element_children;

      string indent_str = space[0..level * get_indent()];
      string separators = get_separators();

      uvm_printer_element_proxy.get_immediate_children(element, element_children);

      // Name (id)
      if (get_name_enabled()) {
	result ~= indent_str ~ element.get_element_name();
	if (element.get_element_name() != "" && element.get_element_name() != "...") {
	  result ~= ": ";
	}
      }

      // Type Name
      string value_str = element.get_element_value();
      if ((value_str.length > 0) && (value_str[0] == '@')) { // is an object w/ id_enabled() on
	result ~= "(" ~ element.get_element_type_name() ~ value_str ~ ") ";
      }
      else {
	if (get_type_name_enabled() &&
	    (element.get_element_type_name() != "" ||
	     element.get_element_type_name() != "-" ||
	     element.get_element_type_name() != "...")) {
	  result ~= "(" ~ element.get_element_type_name() ~ ") ";
	}
      }

      // Size
      if (get_size_enabled()) {
	if (element.get_element_size() != "" || element.get_element_size() != "-") {
	  result ~= "(" ~ element.get_element_size() ~ ") ";
	}
      }

      if (element_children.length > 0) {
	result ~=  separators[0..1] ~ _m_linefeed;
      }
      else {
	result ~= value_str ~ " " ~ _m_linefeed;
      }

      //process all children (if any) of this element
      foreach (child; element_children) {
	result ~= m_emit_element(child, level+1);
      }
      //if there were children, add the closing separator
      if (element_children.length > 0) {
	result ~= indent_str ~ separators[1..2] ~ _m_linefeed;
      }
      return result ;
    }
  }
    

} // endclass



//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_line_printer
//
// The line printer prints output in a line format.
//
// The following shows sample output from the line printer.
//
//| c1: (container@1013) { d1: (mydata@1022) { v1: 'hcb8f1c97 e1: THREE str: hi } value: 'h2d }
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 16.2.12.1
class uvm_line_printer: uvm_tree_printer {

  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);
  // @uvm-ieee 1800.2-2017 auto 16.2.12.2.2
  mixin uvm_object_essentials;

  // Variable -- NODOCS -- new
  //
  // Creates a new instance of ~uvm_line_printer~. It differs from the
  // <uvm_tree_printer> only in that the output contains no line-feeds
  // and indentation.

  // @uvm-ieee 1800.2-2017 auto 16.2.12.2.1
  // @uvm-ieee 1800.2-2017 auto 16.2.2.1
  this(string name="") {
    synchronized (this) {
      super(name);
      _m_newline = " ";
      set_indent(0);
    }
  }


  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private uvm_line_printer _m_default_line_printer ;
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.12.2.3
  // @uvm-ieee 1800.2-2017 auto 16.2.2.2
  static void set_default(uvm_line_printer printer) {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m_default_line_printer = printer ;
    }
  }

  // Function: get_default
  // Implementation of uvm_line_printer::get_default as defined in
  // section 16.2.12.2.3 of 1800.2-2017.
  //
  // *Note:*
  // The library implements get_default as described in IEEE 1800.2-2017
  // with the exception that this implementation will instance a
  // uvm_line_printer if the most recent call to set_default() used an
  // argument value of null.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto 16.2.2.3
  static uvm_line_printer get_default() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_default_line_printer is null) {
	_uvm_scope_inst._m_default_line_printer =
	  new uvm_line_printer("uvm_default_line_printer") ;
      }
      return _uvm_scope_inst._m_default_line_printer ;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.12.3
  override void set_separators(string separators) {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      if (separators.length < 2) {
	uvm_error("UVM/PRINT/SHORT_SEP",
		  format("Bad call: set_separators(%s) (Argument must have at least 2 characters)",
			 separators));
      }
      knobs.separator = separators;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.12.3
  override string get_separators() {
    synchronized (this) {
      m_uvm_printer_knobs knobs = get_knobs();
      return knobs.separator;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.2.4.2
  override void flush() {
    synchronized (this) {
      super.flush() ;
      //set_indent(0); // LRM says to include this call
      //set_separators("{}"); // LRM says to include this call
    }
  }
} // endclass



//------------------------------------------------------------------------------
//
// Class -- NODOCS -- m_uvm_printer_knobs
//
// The ~m_uvm_printer_knobs~ class defines the printer settings available to all
// printer subtypes.
//
//------------------------------------------------------------------------------

import uvm.meta.mcd;

class m_uvm_printer_knobs {
  // Variable -- NODOCS -- header
  //
  // Indicates whether the <print_header> function should be called when
  // printing an object.

  mixin (uvm_sync_string);


  // Variable -- NODOCS -- identifier
  //
  // Indicates whether <adjust_name> should print the identifier. This is useful
  // in cases where you just want the values of an object, but no identifiers.

  @uvm_public_sync
  private bool _identifier = true;


  // Variable -- NODOCS -- type_name
  //
  // Controls whether to print a field's type name.

  @uvm_public_sync
  private bool _type_name = true;


  // Variable -- NODOCS -- size
  //
  // Controls whether to print a field's size.

  @uvm_public_sync
  private bool _size = true;


  // Variable -- NODOCS -- depth
  //
  // Indicates how deep to recurse when printing objects.
  // A depth of -1 means to print everything.

  @uvm_public_sync
  private int _depth = -1;


  // Variable -- NODOCS -- reference
  //
  // Controls whether to print a unique reference ID for object handles.
  // The behavior of this knob is simulator-dependent.

  @uvm_public_sync
  private bool _reference = true;


  // Variable -- NODOCS -- begin_elements
  //
  // Defines the number of elements at the head of a list to print.
  // Use -1 for no max.

  @uvm_public_sync
  private int _begin_elements = 5;


  // Variable -- NODOCS -- end_elements
  //
  // This defines the number of elements at the end of a list that
  // should be printed.

  @uvm_public_sync
  private int _end_elements = 5;


  // Variable -- NODOCS -- prefix
  //
  // Specifies the string prepended to each output line

  @uvm_public_sync
  private string _prefix = "";


  // Variable -- NODOCS -- indent
  //
  // This knob specifies the number of spaces to use for level indentation.
  // The default level indentation is two spaces.

  @uvm_public_sync
  private int _indent = 2;


  // Variable -- NODOCS -- show_root
  //
  // This setting indicates whether or not the initial object that is printed
  // (when current depth is 0) prints the full path name. By default, the first
  // object is treated like all other objects and only the leaf name is printed.

  @uvm_public_sync
  private bool _show_root = false;


  // Variable -- NODOCS -- mcd
  //
  // This is a file descriptor, or multi-channel descriptor, that specifies
  // where the print output should be directed.
  //
  // By default, the output goes to the standard output of the simulator.

  @uvm_public_sync
  private MCD _mcd = UVM_STDOUT;


  // Variable -- NODOCS -- separator
  //
  // For tree printers only, determines the opening and closing
  // separators used for nested objects.

  @uvm_public_sync
  private string _separator = "{}";


  // Variable -- NODOCS -- show_radix
  //
  // Indicates whether the radix string ('h, and so on) should be prepended to
  // an integral value when one is printed.

  @uvm_public_sync
  private bool _show_radix = true;


  // Variable -- NODOCS -- default_radix
  //
  // This knob sets the default radix to use for integral values when no radix
  // enum is explicitly supplied to the print_int() method.

  @uvm_public_sync
  private uvm_radix_enum _default_radix = uvm_radix_enum.UVM_HEX;


  // Variable -- NODOCS -- dec_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_DEC> is used for the radix of the integral object.
  //
  // When a negative number is printed, the radix is not printed since only
  // signed decimal values can print as negative.

  @uvm_public_sync
  private string _dec_radix = "";


  // Variable -- NODOCS -- bin_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_BIN> is used for the radix of the integral object.

  @uvm_public_sync
  private string _bin_radix = "0b";


  // Variable -- NODOCS -- oct_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_OCT> is used for the radix of the integral object.

  @uvm_public_sync
  private string _oct_radix = "0";


  // Variable -- NODOCS -- unsigned_radix
  //
  // This is the string which should be prepended to the value of an integral
  // type when a radix of <UVM_UNSIGNED> is used for the radix of the integral
  // object.

  @uvm_public_sync
  private string _unsigned_radix = "";


  // Variable -- NODOCS -- hex_radix
  //
  // This string should be prepended to the value of an integral type when a
  // radix of <UVM_HEX> is used for the radix of the integral object.

  @uvm_public_sync
  private string _hex_radix = "0x";


  @uvm_private_sync
  private uvm_recursion_policy_enum _recursion_policy ;

}
