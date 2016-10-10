//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2013      NVIDIA Corporation
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


module uvm.base.uvm_object;

// typedef class uvm_report_object;
// typedef class uvm_object_wrapper;
// typedef class uvm_objection;
// typedef class uvm_component;


// internal
// typedef class uvm_status_container;

//------------------------------------------------------------------------------
//
// CLASS: uvm_object
//
// The uvm_object class is the base class for all UVM data and hierarchical
// classes. Its primary role is to define a set of methods for such common
// operations as <create>, <copy>, <compare>, <print>, and <record>. Classes
// deriving from uvm_object must implement the pure virtual methods such as
// <create> and <get_type_name>.
//
//------------------------------------------------------------------------------
import uvm.base.uvm_coreservice;
import uvm.base.uvm_misc;

import uvm.base.uvm_recorder;


import uvm.base.uvm_entity;
import uvm.base.uvm_once;
import uvm.base.uvm_factory;
import uvm.base.uvm_printer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_packer;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_report_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_root;
import uvm.base.uvm_component: uvm_component, uvm__config_parallelism;
import uvm.base.uvm_port_base;
import uvm.comps.uvm_agent;
import uvm.meta.mcd;
import uvm.meta.misc;
import uvm.vpi.uvm_vpi_intf;

import esdl.base.core;
import esdl.data.bvec;

version(UVM_NO_RAND) {}
 else {
   import esdl.data.rand;
 }

import std.traits;
import std.string: format;

import std.random: uniform;
import std.range: ElementType;

abstract class uvm_object: uvm_void
{
  static class uvm_once: uvm_once_base
  {
    @uvm_private_sync
    private bool _use_uvm_seeding = true;
    @uvm_protected_sync
    private int _m_inst_count;
  }

  // Can not use "mixin uvm_once_sync" template due to forward reference error
  // Using string Mixin function
  // mixin uvm_once_sync;
  mixin(uvm_once_sync_string);
  mixin(uvm_sync_string);


  static uvm_status_container m_uvm_status_container() {
    static uvm_status_container _m_uvm_status_container;
    if (_m_uvm_status_container is null) {
      _m_uvm_status_container = new uvm_status_container();
    }
    return _m_uvm_status_container;
  }

  version(UVM_NO_RAND) {}
  else {
    mixin Randomization;
  }

  // Function: new

  // Creates a new uvm_object with the given instance ~name~. If ~name~ is not
  // supplied, the object is unnamed.

  this(string name="") {
    int inst_id;
    synchronized(once) {
      inst_id = once._m_inst_count++;
    }
    synchronized(this) {
      _m_inst_id = inst_id;
      _m_leaf_name = name;
      // auto proc = Procedure.self;
      // if(proc !is null) {
      // 	auto seed = uniform!int(proc.getRandGen());
      // 	debug(SEED) {
      // 	  import std.stdio;
      // 	  auto thread = PoolThread.self;
      // 	  auto func = Process.self;
      // 	  if (func !is null) {
      // 	    writeln("Process ", thread ? thread.getPoolIndex : -1, " : ",
      // 		    func.getFullName);
      // 	  }
      // 	  writeln("Setting ", get_full_name, " seed: ", seed);
      // 	}
      // 	this.reseed(seed);
      // }
    }
  }


  // Group: Seeding

  // Variable: use_uvm_seeding
  //
  // This bit enables or disables the UVM seeding mechanism. It globally affects
  // the operation of the <reseed> method.
  //
  // When enabled, UVM-based objects are seeded based on their type and full
  // hierarchical name rather than allocation order. This improves random
  // stability for objects whose instance names are unique across each type.
  // The <uvm_component> class is an example of a type that has a unique
  // instance name.

  // Moved to once
  // shared static bool use_uvm_seeding = true;


  // Function: reseed
  //
  // Calls ~srandom~ on the object to reseed the object using the UVM seeding
  // mechanism, which sets the seed based on type name and instance name instead
  // of based on instance position in a thread.
  //
  // If the <use_uvm_seeding> static variable is set to 0, then reseed() does
  // not perform any function.

  final void reseed (int seed) {
    version(UVM_NO_RAND) {}
    else {
      this.srandom(seed);
    }
  }

  final void reseed () {
    synchronized(this) {
      if(use_uvm_seeding) {
	version(UVM_NO_RAND) {}
	else {
	  this.srandom(uvm_create_random_seed(get_type_name(),
					      get_full_name()));
	}
      }
    }
  }

  void _esdl__setupSolver() {
    if (! _esdl__isRandSeeded()) {
      auto proc = Procedure.self;
      if(proc !is null) {
      	auto seed = uniform!int(proc.getRandGen());
	debug(SEED) {
      	  import std.stdio;
      	  auto thread = PoolThread.self;
	  writeln("Procedure ", thread ? thread.getPoolIndex : -1, " : ",
      		    proc.getFullName);
      	  writeln("Setting ", get_full_name, " seed: ", seed);
	}
	this.reseed(seed);
      }
    }
  }

  // // Group: Identification

  // // Function: set_name
  // //
  // // Sets the instance name of this object, overwriting any previously
  // // given name.

  void set_name (string name) {
    synchronized(this) {
      _m_leaf_name = name;
    }
  }


  // Function: get_name
  //
  // Returns the name of the object, as provided by the ~name~ argument in the
  // <new> constructor or <set_name> method.

  string get_name () {
    synchronized(this) {
      return _m_leaf_name;
    }
  }


  // Function: get_full_name
  //
  // Returns the full hierarchical name of this object. The default
  // implementation is the same as <get_name>, as uvm_objects do not inherently
  // possess hierarchy.
  //
  // Objects possessing hierarchy, such as <uvm_components>, override the default
  // implementation. Other objects might be associated with component hierarchy
  // but are not themselves components. For example, <uvm_sequence #(REQ,RSP)>
  // classes are typically associated with a <uvm_sequencer #(REQ,RSP)>. In this
  // case, it is useful to override get_full_name to return the sequencer's
  // full name concatenated with the sequence's name. This provides the sequence
  // a full context, which is useful when debugging.

  string get_full_name () {
    return get_name();
  }



  // Function: get_inst_id
  //
  // Returns the object's unique, numeric instance identifier.

  int get_inst_id () {
    synchronized(this) {
      return _m_inst_id;
    }
  }


  // Function: get_inst_count
  //
  // Returns the current value of the instance counter, which represents the
  // total number of uvm_object-based objects that have been allocated in
  // simulation. The instance counter is used to form a unique numeric instance
  // identifier.

  static int get_inst_count() {
    synchronized(once) {
      return once._m_inst_count;
    }
  }


  // Function: get_type
  //
  // Returns the type-proxy (wrapper) for this object. The <uvm_factory>'s
  // type-based override and creation methods take arguments of
  // <uvm_object_wrapper>. This method, if implemented, can be used as convenient
  // means of supplying those arguments.
  //
  // The default implementation of this method produces an error and returns
  // ~null~. To enable use of this method, a user's subtype must implement a
  // version that returns the subtype's wrapper.
  //
  // For example:
  //
  //|  class cmd extends uvm_object;
  //|    typedef uvm_object_registry #(cmd) type_id;
  //|    static function type_id get_type();
  //|      return type_id::get();
  //|    endfunction
  //|  endclass
  //
  // Then, to use:
  //
  //|  factory.set_type_override(cmd::get_type(),subcmd::get_type());
  //
  // This function is implemented by the `uvm_*_utils macros, if employed.

  static uvm_object_wrapper get_type () {
    uvm_report_error("NOTYPID", "get_type not implemented in derived class.",
		     UVM_NONE);
    return null;
  }


  // Function: get_object_type
  //
  // Returns the type-proxy (wrapper) for this object. The <uvm_factory>'s
  // type-based override and creation methods take arguments of
  // <uvm_object_wrapper>. This method, if implemented, can be used as convenient
  // means of supplying those arguments. This method is the same as the static
  // <get_type> method, but uses an already allocated object to determine
  // the type-proxy to access (instead of using the static object).
  //
  // The default implementation of this method does a factory lookup of the
  // proxy using the return value from <get_type_name>. If the type returned
  // by <get_type_name> is not registered with the factory, then a ~null~
  // handle is returned.
  //
  // For example:
  //
  //|  class cmd extends uvm_object;
  //|    typedef uvm_object_registry #(cmd) type_id;
  //|    static function type_id get_type();
  //|      return type_id::get();
  //|    endfunction
  //|    virtual function type_id get_object_type();
  //|      return type_id::get();
  //|    endfunction
  //|  endclass
  //
  // This function is implemented by the `uvm_*_utils macros, if employed.

  uvm_object_wrapper get_object_type () {
    if(get_type_name() == "<unknown>") return null;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    return factory.find_wrapper_by_name(get_type_name());
  }


  // Function: get_type_name
  //
  // This function returns the type name of the object, which is typically the
  // type identifier enclosed in quotes. It is used for various debugging
  // functions in the library, and it is used by the factory for creating
  // objects.
  //
  // This function must be defined in every derived class.
  //
  // A typical implementation is as follows:
  //
  //|  class mytype extends uvm_object;
  //|    ...
  //|    const static string type_name = "mytype";
  //|
  //|    virtual function string get_type_name();
  //|      return type_name;
  //|    endfunction
  //
  // We define the ~type_name~ static variable to enable access to the type name
  // without need of an object of the class, i.e., to enable access via the
  // scope operator, ~mytype::type_name~.


  // FIXME
  // the best way to handle this method would be to define a global
  // method with the following functionality:
  // auto oci = typeid(this);
  // return oci.to!string();
  // it will then be available via UFCS
  string get_type_name () {
    return "<unknown>";
  }

  bool uvm_field_utils_defined() {
    return false;
  }
  
  // Group: Creation

  // Function: create
  //
  // The ~create~ method allocates a new object of the same type as this object
  // and returns it via a base uvm_object handle. Every class deriving from
  // uvm_object, directly or indirectly, must implement the create method.
  //
  // A typical implementation is as follows:
  //
  //|  class mytype extends uvm_object;
  //|    ...
  //|    virtual function uvm_object create(string name="");
  //|      mytype t = new(name);
  //|      return t;
  //|    endfunction

  uvm_object create (string name = "") {
    return null;
  }

  // Function: clone
  //
  // The ~clone~ method creates and returns an exact copy of this object.
  //
  // The default implementation calls <create> followed by <copy>. As clone is
  // virtual, derived classes may override this implementation if desired.

  uvm_object clone () {
    uvm_object tmp = this.create(get_name());
    if(tmp is null) {
      uvm_report_warning("CRFLD",
			 format("The create method failed for %s,  " ~
				"object cannot be cloned", get_name()),
			 UVM_NONE);
    }
    else {
      tmp.copy(this);
    }
    return tmp;
  }


  // Group: Printing

  // Function: print
  //
  // The ~print~ method deep-prints this object's properties in a format and
  // manner governed by the given ~printer~ argument; if the ~printer~ argument
  // is not provided, the global <uvm_default_printer> is used. See
  // <uvm_printer> for more information on printer output formatting. See also
  // <uvm_line_printer>, <uvm_tree_printer>, and <uvm_table_printer> for details
  // on the pre-defined printer "policies," or formatters, provided by the UVM.
  //
  // The ~print~ method is not virtual and must not be overloaded. To include
  // custom information in the ~print~ and <sprint> operations, derived classes
  // must override the <do_print> method and use the provided printer policy
  // class to format the output.

  final void print(uvm_printer printer = null) {
    if (printer is null) {
      printer = uvm_default_printer;
    }
    if (printer is null) {
      uvm_error("NULLPRINTER", "uvm_default_printer is null");
    }
    synchronized(printer) {
      printer.knobs.mcd.vfdisplay(sprint(printer));
    }
  }


  // Function: sprint
  //
  // The ~sprint~ method works just like the <print> method, except the output
  // is returned in a string rather than displayed.
  //
  // The ~sprint~ method is not virtual and must not be overloaded. To include
  // additional fields in the <print> and ~sprint~ operation, derived classes
  // must override the <do_print> method and use the provided printer policy
  // class to format the output. The printer policy will manage all string
  // concatenations and provide the string to ~sprint~ to return to the caller.

  static void _m_uvm_object_automation(E)(ref E e,
					 E rhs,
					 int what,
					 string str,
					 string name,
					 int flags)
    if (isArray!E && !is(E == string)) {
      alias EE = ElementType!E;
      switch(what) {
      case uvm_field_auto_enum.UVM_COPY:
	if(!(flags & UVM_NOCOPY) && flags & UVM_COPY) {
	  if(flags & UVM_REFERENCE) {
	    e = rhs;
	  }
	  else {
	    static if (isDynamicArray!E) {
	      e.length = rhs.length;
	    }
	    for (size_t i=0; i!=e.length; ++i) {
	      _m_uvm_object_automation(e[i], rhs[i], what, str,
				      name ~ format("[%d]", i),
				      flags);
	    }
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_COMPARE:
	if (! flags & UVM_NOCOMPARE) {
	  if (flags & UVM_REFERENCE  && m_uvm_status_container.comparer.show_max <= 1 && e !is rhs) {
	    if (m_uvm_status_container.comparer.show_max == 1) {
	      m_uvm_status_container.scope_stack.set_arg(name);
	      m_uvm_status_container.comparer.print_msg("");
	    }
	    else if ((m_uvm_status_container.comparer.is_physical && flags & UVM_PHYSICAL) ||
		     (m_uvm_status_container.comparer.is_abstract && flags & UVM_ABSTRACT) ||
		     (! flags & UVM_PHYSICAL && ! flags & UVM_ABSTRACT)) {
	      m_uvm_status_container.comparer.incr_result;
	    }
	    if (m_uvm_status_container.comparer.result &&
		m_uvm_status_container.comparer.show_max <= m_uvm_status_container.comparer.result) {
	      return;
	    }
	  }
	  else {
	    string s;
	    if(e.length != rhs.length) {
	      m_uvm_status_container.scope_stack.set_arg(name);
	      m_uvm_status_container.comparer.print_msg(format("size mismatch: lhs: %0d  rhs: %0d", e.length, rhs.length));
	      if (m_uvm_status_container.comparer.show_max == 1) return;
	    }
	    for(int i=0; i != e.length && i < rhs.length; ++i) {
	      _m_uvm_object_automation(e[i], rhs[i], what, str,
				      name ~ format("[%d]", i),
				      flags);
	    }
	    if(m_uvm_status_container.comparer.result &&
	       (m_uvm_status_container.comparer.show_max <= m_uvm_status_container.comparer.result)) {
	      return;
	    }
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_PRINT:
	auto p__ = m_uvm_status_container.printer;
	if (p__ is null) p__ = uvm_default_printer;
	auto k__ = p__.knobs;
	
	if (!(flags & UVM_NOPRINT) && flags & UVM_PRINT) {
	  m_uvm_status_container.printer.print_generic(name, E.stringof,
						       e.length, "-");
	  size_t i;
	  for (i=0; i!=e.length; ++i) {
	    if (k__.begin_elements == -1 || k__.end_elements == -1 ||
		i < k__.begin_elements ) {
	      _m_uvm_object_automation(e[i], EE.init, what, str,
				      name ~ format("[%d]", i),
				      flags);
	    }
	    else break;
	  }
	  if (i < e.length) {
	    if ((e.length - k__.end_elements) > i) {
	      i = e.length - k__.end_elements;
	    }
	    if (i < k__.begin_elements) {
	      i = k__.begin_elements;
	    }
	    else {
	      p__.print_array_range(k__.begin_elements, cast(int) i-1);
	    }
	    for (; i!=e.length; ++i) {
	      _m_uvm_object_automation(e[i], EE.init, what, str,
				      name ~ format("[%d]", i),
				      flags);
	    }
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_RECORD:
	if (!(flags & UVM_NORECORD) && flags & UVM_RECORD) {
	  if (e.length == 0) {
	    m_uvm_status_container.recorder.record(name, e.length,
						   uvm_radix_enum.UVM_DEC);
	  }
	  else if (e.length < 10) {
	    for (size_t i=0; i!=e.length; ++i) {
	      _m_uvm_object_automation(e[i], EE.init, what, str,
				      name ~ format("[%d]", i),
				      flags);
	    }
	  }
	  else {		// record only first and last 5 elements
	    for (size_t i=0; i!=5; ++i) {
	      _m_uvm_object_automation(e[i], EE.init, what, str,
				      name ~ format("[%d]", i),
				      flags);
	    }
	    for (size_t i=e.length-5; i!=e.length; ++i) {
	      _m_uvm_object_automation(e[i], EE.init, what, str,
				      name ~ format("[%d]", i),
				      flags);
	    }
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_PACK:
        if (!(flags & UVM_NOPACK) && flags & UVM_PACK) {
	  static if (isDynamicArray!E) {
	    m_uvm_status_container.packer.pack(e.length);
	  }
	  for (size_t i=0; i!=e.length; ++i) {
	    _m_uvm_object_automation(e[i], EE.init, what, str,
				    name ~ format("[%d]", i),
				    flags);
	  }
	}
	break;
      case uvm_field_xtra_enum.UVM_UNPACK:
        if (!(flags & UVM_NOPACK) && flags & UVM_PACK) {
	  static if (isDynamicArray!E) {
	    size_t size;
	    m_uvm_status_container.packer.unpack(size);
	    e.length = size;
	  }
	  for (size_t i=0; i!=e.length; ++i) {
	    _m_uvm_object_automation(e[i], EE.init, what, str,
				    name ~ format("[%d]", i),
				    flags);
	  }
	}
	break;
      case uvm_field_xtra_enum.UVM_SETINT,
	uvm_field_xtra_enum.UVM_SETOBJ,
	uvm_field_xtra_enum.UVM_SETSTR:
	m_uvm_status_container.scope_stack.set_arg(name);
	if (uvm_is_match(str, m_uvm_status_container.scope_stack.get())) {
	  if (flags & UVM_READONLY) {
	    uvm_report_warning("RDONLY",
			       format("Readonly argument match %s is ignored",
				      m_uvm_status_container.get_full_scope_arg()),
			       UVM_NONE);
	  }
	  else {
	    uvm_report_warning("MSMTCH",
			       format("%s: static arrays cannot be resized" ~
				      " via configuraton.",
				      m_uvm_status_container.get_full_scope_arg()),
			       UVM_NONE);
	  }
	}
	m_uvm_status_container.scope_stack.unset_arg(name);
	// else if(!((FLAG)&UVM_READONLY))
	for (size_t i=0; i!=e.length; ++i) {
	  _m_uvm_object_automation(e[i], EE.init, what, str,
				  name ~ format("[%d]", i),
				  flags);
	}
	break;
      case uvm_field_xtra_enum.UVM_CHECK_FIELDS:
	// uvm_warning("UVMUTLS",
	// 	      "UVM UTILS CheckField functions is not yet implemented");
	break;
      case uvm_field_xtra_enum.UVM_PARALLELIZE:
      	// for (size_t i=0; i!=e.length; ++i) {
      	//   _m_uvm_object_automation(e[i], EE.init, what, str,
      	// 			  name ~ format("[%d]", i),
      	// 			  flags);
      	// }
      	break;
      case uvm_field_auto_enum.UVM_BUILD:
      	// for (size_t i=0; i!=e.length; ++i) {
      	//   _m_uvm_object_automation(e[i], EE.init, what, str,
      	// 			  name ~ format("[%d]", i),
      	// 			  flags);
      	// }
      	break;
      default:
	uvm_error("UVMUTLS",
		  format("UVM UTILS uknown utils functionality: %s/%s", cast(uvm_field_auto_enum) what, cast(uvm_field_xtra_enum) what));
	break;
	  
      }
    }
  
  static void _m_uvm_object_automation(E)(ref E e,
					 E rhs,
					 int what,
					 string str,
					 string name,
					 int flags)
    if (isBitVector!E || isIntegral!E || is(E == bool)) {
      switch(what) {
      case uvm_field_auto_enum.UVM_COPY:
	if (!(flags & UVM_NOCOPY) && flags & UVM_COPY) {
	  e = rhs;
	}
	break;
      case uvm_field_auto_enum.UVM_COMPARE:
	if (!(flags & UVM_NOCOMPARE) && flags & UVM_COMPARE) {
	  if (e !is rhs) {
	    m_uvm_status_container.comparer.compare(name, e, rhs);
	    if(m_uvm_status_container.comparer.result &&
	       (m_uvm_status_container.comparer.show_max <= m_uvm_status_container.comparer.result)) return;
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_PRINT:
	if (!(flags & UVM_NOPRINT) && flags & UVM_PRINT) {
	  m_uvm_status_container.printer.print(name, e,
					       cast (uvm_radix_enum) (flags & UVM_RADIX));
	}
	break;
      case uvm_field_auto_enum.UVM_RECORD:
	if (!(flags & UVM_NORECORD) && flags & UVM_RECORD) {
	  m_uvm_status_container.recorder.record(name, e,
						 cast (uvm_radix_enum) (flags & UVM_RADIX));
	}
	break;
      case uvm_field_auto_enum.UVM_PACK:
        if (! (flags & UVM_NOPACK) && flags & UVM_PACK) {
          m_uvm_status_container.packer.pack(e);
        }
	break;
      case uvm_field_xtra_enum.UVM_UNPACK:
        if (! (flags & UVM_NOPACK) && flags & UVM_PACK) {
          m_uvm_status_container.packer.unpack(e);
        }
	break;
      case uvm_field_xtra_enum.UVM_SETINT:
	bool matched;
	m_uvm_status_container.scope_stack.set_arg(name);
	matched = uvm_is_match(str, m_uvm_status_container.scope_stack.get());
	if (matched) {
	  if (flags & UVM_READONLY) {
	    uvm_report_warning("RDONLY",
			       format("Readonly argument match %s is ignored",
				      m_uvm_status_container.get_full_scope_arg()),
			       UVM_NONE);
	  }
	  else {
	    if (m_uvm_status_container.print_matches) {
	      uvm_report_info("STRMTC", "set_int()" ~ ": Matched string " ~
			      str ~ " to field " ~
			      m_uvm_status_container.get_full_scope_arg(),
			      UVM_LOW);
	    }
	    E value = cast(E) m_uvm_status_container.bitstream;
	    uvm_bitstream_t check = value;
	    if (m_uvm_status_container.bitstream == check) {
	      e = value;
	      m_uvm_status_container.status = true;
	    }
	    else {
	      uvm_report_warning("OVRFLW", "set_int()" ~ ": Matched string " ~
				 str ~ " to field " ~
				 m_uvm_status_container.get_full_scope_arg() ~
				 ", but variable is not set because of " ~
				 "overflow error");
	    }
	  }
	}
	m_uvm_status_container.scope_stack.unset_arg(name);
	break;
      case uvm_field_xtra_enum.UVM_SETOBJ:
	break;
      case uvm_field_xtra_enum.UVM_SETSTR:
	static if (is(E == enum)) {
          m_uvm_status_container.scope_stack.set_arg(name);
          if (uvm_is_match(str, m_uvm_status_container.scope_stack.get())) {
            if (flags & UVM_READONLY) {
              uvm_report_warning("RDONLY",
				 format("Readonly argument match %s is ignored",
					m_uvm_status_container.get_full_scope_arg()),
				 UVM_NONE);
            }
            else {
              if (m_uvm_status_container.print_matches) {
		uvm_report_info("STRMTC",
				"set_str()" ~ ": Matched string " ~ str ~
				" to field " ~
				m_uvm_status_container.get_full_scope_arg(),
				UVM_LOW);
	      }
	      E value;
              if (uvm_enum_wrapper!E.from_name(m_uvm_status_container.stringv,
					       value)) {
		m_uvm_status_container.status = true;
		e = value;
	      }
            }
          }
	}
	break;
      case uvm_field_xtra_enum.UVM_CHECK_FIELDS:
	// uvm_warning("UVMUTLS",
	// 	      "UVM UTILS CheckField functions is not yet implemented");
	break;
      case uvm_field_xtra_enum.UVM_PARALLELIZE:
	break;
      case uvm_field_auto_enum.UVM_BUILD:
	break;
      default:
	uvm_error("UVMUTLS",
		  format("UVM UTILS uknown utils functionality: %s/%s", cast(uvm_field_auto_enum) what, cast(uvm_field_xtra_enum) what));
	break;
	  
      }
    }
  
  static void _m_uvm_object_automation(E)(ref E e,
					 E rhs,
					 int what,
					 string str,
					 string name,
					 int flags)
    if (is(E == string)) {
      switch(what) {
      case uvm_field_auto_enum.UVM_COPY:
	if (!(flags & UVM_NOCOPY) && flags & UVM_COPY) {
	  e = rhs;
	}
	break;
      case uvm_field_auto_enum.UVM_COMPARE:
	if (!(flags & UVM_NOCOMPARE) && flags & UVM_COMPARE) {
	  if (e !is rhs) {
	    m_uvm_status_container.comparer.compare(name, e, rhs);
	    if(m_uvm_status_container.comparer.result &&
	       (m_uvm_status_container.comparer.show_max <= m_uvm_status_container.comparer.result)) return;
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_PRINT:
	if (!(flags & UVM_NOPRINT) && flags & UVM_PRINT) {
	  m_uvm_status_container.printer.print(name, e);
	}
	break;
      case uvm_field_auto_enum.UVM_RECORD:
	if (!(flags & UVM_NORECORD) && flags & UVM_RECORD) {
	  m_uvm_status_container.recorder.record(name, e);
	}
	break;
      case uvm_field_auto_enum.UVM_PACK:
        if (! (flags & UVM_NOPACK) && flags & UVM_PACK) {
          m_uvm_status_container.packer.pack(e);
        }
	break;
      case uvm_field_xtra_enum.UVM_UNPACK:
        if (! (flags & UVM_NOPACK) && flags & UVM_PACK) {
          m_uvm_status_container.packer.unpack(e);
        }
	break;
      case uvm_field_xtra_enum.UVM_SETINT:
	break;
      case uvm_field_xtra_enum.UVM_SETOBJ:
	break;
      case uvm_field_xtra_enum.UVM_SETSTR:
	m_uvm_status_container.scope_stack.set_arg(name);
	if (uvm_is_match(str, m_uvm_status_container.scope_stack.get())) {
	  if(flags & UVM_READONLY) {
	    uvm_report_warning("RDONLY",
			       format("Readonly argument match %s is ignored",
				      m_uvm_status_container.get_full_scope_arg()),
			       UVM_NONE);
	  }
	  else {
	    if (m_uvm_status_container.print_matches) {
	      uvm_report_info("STRMTC",
			      "set_str()" ~ ": Matched string " ~ str ~
			      " to field " ~
			      m_uvm_status_container.get_full_scope_arg(),
			      UVM_LOW);
	    }
	    e = m_uvm_status_container.stringv;
	    m_uvm_status_container.status = true;
	  }
	}
	break;
      case uvm_field_xtra_enum.UVM_CHECK_FIELDS:
	// uvm_warning("UVMUTLS",
	// 	      "UVM UTILS CheckField functions is not yet implemented");
	break;
      case uvm_field_xtra_enum.UVM_PARALLELIZE:
	break;
      case uvm_field_auto_enum.UVM_BUILD:
	break;
      default:
	uvm_error("UVMUTLS",
		  format("UVM UTILS uknown utils functionality: %s/%s", cast(uvm_field_auto_enum) what, cast(uvm_field_xtra_enum) what));
	break;
	  
      }
    }
  
  static void _m_uvm_object_automation(E)(ref E e,
					 E rhs,
					 int what,
					 string str,
					 string name,
					 int flags)
    if (is(E: uvm_object)) {
      switch(what) {
      case uvm_field_auto_enum.UVM_COPY:
	if (!(flags & UVM_NOCOPY) && flags & UVM_COPY) {
	  if(flags & UVM_REFERENCE || rhs is null) {
	    e = rhs;
	  }
	  else {
	    uvm_object l_obj;
	    if (rhs.get_name() == "") {
	      rhs.set_name(name);
	    }
	    l_obj = rhs.clone();
	    if (l_obj is null) {
	      uvm_fatal("FAILCLN", format("Failure to clone %s, thus the " ~
					  "variable will remain null.", name));
	    }
	    else {
	      e = cast(E) l_obj;
	      e.set_name(rhs.get_name());
	    }
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_COMPARE:
	if (!(flags & UVM_NOCOMPARE) && flags & UVM_COMPARE) {
	  if (e !is rhs) {
	    m_uvm_status_container.comparer.compare(name, e, rhs);
	    if(m_uvm_status_container.comparer.result &&
	       (m_uvm_status_container.comparer.show_max <= m_uvm_status_container.comparer.result)) return;
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_PRINT:
	if (!(flags & UVM_NOPRINT) && flags & UVM_PRINT) {
	  if ((flags & UVM_REFERENCE) != 0) {
	    m_uvm_status_container.printer.print_object_header(name, e);
	  }
	  else {
	    m_uvm_status_container.printer.print(name, e);
          }
        }
	break;
      case uvm_field_auto_enum.UVM_RECORD:
	if (!(flags & UVM_NORECORD) && flags & UVM_RECORD) {
	  m_uvm_status_container.recorder.record(name, e);
        }
	break;
      case uvm_field_auto_enum.UVM_PACK:
        if (! (flags & UVM_NOPACK) && flags & UVM_PACK &&
	    ! (flags & UVM_REFERENCE)) { // do not pack if UVM_REFERENCE
	  m_uvm_status_container.packer.pack(e);
	}
	break;
      case uvm_field_xtra_enum.UVM_UNPACK:
        if (! (flags & UVM_NOPACK) && flags & UVM_PACK &&
	    ! (flags & UVM_REFERENCE)) { // do not pack if UVM_REFERENCE
	  m_uvm_status_container.packer.unpack(e);
	}
	break;
      case uvm_field_xtra_enum.UVM_SETINT,
	uvm_field_xtra_enum.UVM_SETSTR:
	if ((e !is null) && (flags & UVM_READONLY) == 0 &&
	    (flags & UVM_REFERENCE) == 0) {
	  m_uvm_status_container.scope_stack.down(name);
	  e.m_uvm_object_automation(null, what, str);
	  m_uvm_status_container.scope_stack.up();
	}
	break;
      case uvm_field_xtra_enum.UVM_SETOBJ:
	m_uvm_status_container.scope_stack.set_arg(name);
	if (uvm_is_match(str, m_uvm_status_container.scope_stack.get())) {
	  if (flags & UVM_READONLY) {
	    uvm_report_warning("RDONLY",
			       format("Readonly argument match %s is ignored",
				      m_uvm_status_container.get_full_scope_arg()),
			       UVM_NONE);
	  }
	  else {
	    if (m_uvm_status_container.print_matches) {
	      uvm_report_info("STRMTC", "set_object()" ~ ": Matched string " ~
			      str ~ " to field " ~
			      m_uvm_status_container.get_full_scope_arg(),
			      UVM_LOW);
	    }
	    E value = cast(E) m_uvm_status_container.object;
	    if (value !is null) {
	      e = value;
	      m_uvm_status_container.status = 1;
	    }
	  }
	}
	else if ((e !is null) && ((flags & UVM_READONLY) == 0)) {
	  int cnt;
	  //Only traverse if there is a possible match.
	  for (cnt=0; cnt < str.length; ++cnt) {
	    if (str[cnt] == '.' || str[cnt] == '*') break;
	  }
	  if (cnt != str.length || str[0] is '/') {
	    m_uvm_status_container.scope_stack.down(name);
	    e.m_uvm_object_automation(null, what, str);
	    m_uvm_status_container.scope_stack.up();
	  }
	}
	break;
      case uvm_field_xtra_enum.UVM_CHECK_FIELDS:
	// uvm_warning("UVMUTLS",
	// 	      "UVM UTILS CheckField functions is not yet implemented");
	break;
      default:
	uvm_error("UVMUTLS",
		  format("UVM UTILS uknown utils functionality: %s/%s", cast(uvm_field_auto_enum) what, cast(uvm_field_xtra_enum) what));
	break;
	  
      }
    }

  // static void _m_uvm_object_automation(E)(ref E e,
  // 					 E rhs,
  // 					 int what,
  // 					 string str,
  // 					 string name,
  // 					 int flags)
  //   if (!(isIntegral!E || isBitVector!E || is(E == bool) || isArray!E ||
  // 	  is(E: uvm_object))) {
  //     if (flags != 0) {
  // 	// uvm_error("UVMUTLS", format("Do not know how to interpret flag" ~
  // 	// 			    " %s/%s for field of type %s element %s",
  // 	// 			    cast(uvm_field_auto_enum) flags,
  // 	// 			    cast(uvm_field_xtra_enum) flags,
  // 	// 			    E.stringof, name));
  //     }
  //   }
  

  static void _m_uvm_object_automation(int I, T)(T          t,
						T          rhs,
						int        what, 
						string     str)
    if (is(T: uvm_object)) {
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	alias EE = UVM_ELEMENT_TYPE!(typeof(t.tupleof[I]));
	static if (FLAGS != 0 &&
		   (isIntegral!EE || isBitVector!EE || is(EE == bool) ||
		    is(EE: uvm_object) || is(EE == string))) {
	  if (what == uvm_field_auto_enum.UVM_COMPARE ||
	      what == uvm_field_auto_enum.UVM_COPY) {
	    assert (rhs !is null);
	    _m_uvm_object_automation(t.tupleof[I], rhs.tupleof[I], what, str,
				     t.tupleof[I].stringof[2..$],
				     FLAGS);
	  }
	  else {
	    _m_uvm_object_automation(t.tupleof[I], typeof(t.tupleof[I]).init,
				     what, str, t.tupleof[I].stringof[2..$],
				     FLAGS);
	  }
	}
	_m_uvm_object_automation!(I+1)(t, rhs, what, str);
      }
    }

  // void uvm_field_auto_sprint(uvm_printer printer) { }

  // print the Ith field
  // static void uvm_field_auto_sprint_field(size_t I=0, T)
  //   (T t, uvm_printer printer) {
  //   static if (I < t.tupleof.length) {
  //     import std.traits: isIntegral, isFloatingPoint;
  //     enum int FLAGS = uvm_field_auto_get_flags!(t, I);
  //     static if(FLAGS & UVM_PRINT &&
  // 		!(FLAGS & UVM_NOPRINT)) {
  // 	debug(UVM_UTILS) {
  // 	  pragma(msg, "Printing : " ~ t.tupleof[I].stringof);
  // 	}
  // 	enum string name = __traits(identifier, T.tupleof[I]);
  // 	auto value = t.tupleof[I];
  // 	alias U=typeof(t.tupleof[I]);
  // 	// do not use isIntegral -- we keep that for enums
  // 	// version(UVM_NO_RAND) { }
  // 	// else {
  // 	//   import esdl.data.rand;
  // 	//   static if(is(U: _esdl__ConstraintBase)) {
  // 	//     // shortcircuit useful for compare etc
  // 	//     uvm_field_auto_sprint_field!(I+1)(t, printer);
  // 	//     // return;
  // 	//   }
  // 	// }
  // 	static if(is(U == SimTime)) {
  // 	  printer.print(name, value);
  // 	}
  // 	else static if(is(U == enum)) { // to cover enums
  // 	  printer.print(name, value, UVM_ENUM);
  // 	}
  // 	else static if(isBitVector!U  || isIntegral!U || is(U == bool)) {
  // 	  printer.print(name, value,
  // 			cast(uvm_radix_enum) (FLAGS & UVM_RADIX));
  // 	}
  // 	else static if(is(U: uvm_object)) {
  // 	  static if((FLAGS & UVM_REFERENCE) != 0) {
  // 	    printer.print_object_header(name, value);
  // 	  }
  // 	  else {
  // 	    printer.print(name, value);
  // 	  }
  // 	}
  // 	else static if(is(U == string) || is(U == char[])) {
  // 	  printer.print(name, value);
  // 	}
  // 	// enum should be already handled as part of integral
  // 	else static if(isFloatingPoint!U) {
  // 	  printer.print(name, value);
  // 	}
  // 	else static if(is(U: EventObj)) {
  // 	  printer.print_generic(name, "event", -2, "");
  // 	}
  // 	else static if (isArray!U) {
  // 	  alias E = UVM_ELEMENT_TYPE!U;
  // 	  static if (isIntegral!E || isBitVector!E || is(E == string)) {
  // 	    import std.conv;
  // 	    printer.print_generic(name, U.stringof, -2, value.to!string);
  // 	  }
  // 	  else static if (is(E: uvm_object)) {
  // 	    uvm_field_auto_sprint_field!FLAGS(value, 0, name, printer);
  // 	  }
  // 	  else {
  // 	    static assert(false);
  // 	  }
  // 	}
  // 	else {
  // 	  static assert(false, "Do not know how to handle type: " ~ U.stringof);
  // 	}
  //     }
  //     uvm_field_auto_sprint_field!(I+1)(t, printer);
  //   }
  // }
  
  // static void uvm_field_auto_sprint_field(int FLAGS, T)
  //   (T t, size_t index, string name, uvm_printer printer) {
  //   if (index < t.length) {
  //     alias E = ElementType!T;
  //     static if (isArray!E) {
  // 	uvm_field_auto_sprint_field!FLAGS(t[index], 0,
  // 					  name ~ format("[%d]", index),
  // 					  printer);
  //     }
  //     else {
  // 	static if (is(E: uvm_object)) {
  // 	  auto iname = name ~ format("[%d]", index);
  // 	  static if((FLAGS & UVM_REFERENCE) != 0) {
  // 	    printer.print_object_header(iname, t[index]);
  // 	  }
  // 	  else {
  // 	    printer.print(iname, t[index]);
  // 	  }
  // 	}
  // 	else {
  // 	  static assert(false);
  // 	}
  //     }
  //     uvm_field_auto_sprint_field!FLAGS(t, index+1, name, printer);
  //   }
  // }

  final string sprint (uvm_printer printer=null) {

    if(printer is null) {
      printer = uvm_default_printer;
    }

    synchronized(printer) {
      // not at top-level, must be recursing into sub-object
      if(! printer.istop()) {
	m_uvm_status_container.printer = printer;
	m_uvm_object_automation(null, UVM_PRINT, "");
	// uvm_field_auto_sprint(printer);
	do_print(printer);
	return "";
      }

      printer.print_object(get_name(), this);
      // backward compat with sprint knob: if used,
      //    print that, do not call emit()
      if (printer.m_string != "") {
	return printer.m_string;
      }

      return printer.emit();
    }
  }


  // Function: do_print
  //
  // The ~do_print~ method is the user-definable hook called by <print> and
  // <sprint> that allows users to customize what gets printed or sprinted
  // beyond the field information provided by the `uvm_field_* macros,
  // <Utility and Field Macros for Components and Objects>.
  //
  // The ~printer~ argument is the policy object that governs the format and
  // content of the output. To ensure correct <print> and <sprint> operation,
  // and to ensure a consistent output format, the ~printer~ must be used
  // by all <do_print> implementations. That is, instead of using ~$display~ or
  // string concatenations directly, a ~do_print~ implementation must call
  // through the ~printer's~ API to add information to be printed or sprinted.
  //
  // An example implementation of ~do_print~ is as follows:
  //
  //| class mytype extends uvm_object;
  //|   data_obj data;
  //|   int f1;
  //|   virtual function void do_print (uvm_printer printer);
  //|     super.do_print(printer);
  //|     printer.print_field_int("f1", f1, $bits(f1), UVM_DEC);
  //|     printer.print_object("data", data);
  //|   endfunction
  //
  // Then, to print and sprint the object, you could write:
  //
  //| mytype t = new;
  //| t.print();
  //| uvm_report_info("Received",t.sprint());
  //
  // See <uvm_printer> for information about the printer API.

  void do_print (uvm_printer printer) {
    return;
  }


  // Function: convert2string
  //
  // This virtual function is a user-definable hook, called directly by the
  // user, that allows users to provide object information in the form of
  // a string. Unlike <sprint>, there is no requirement to use a <uvm_printer>
  // policy object. As such, the format and content of the output is fully
  // customizable, which may be suitable for applications not requiring the
  // consistent formatting offered by the <print>/<sprint>/<do_print>
  // API.
  //
  // Fields declared in <Utility Macros> macros (`uvm_field_*), if used, will
  // not automatically appear in calls to convert2string.
  //
  // An example implementation of convert2string follows.
  //
  //| class base extends uvm_object;
  //|   string field = "foo";
  //|   virtual function string convert2string();
  //|     convert2string = {"base_field=",field};
  //|   endfunction
  //| endclass
  //|
  //| class obj2 extends uvm_object;
  //|   string field = "bar";
  //|   virtual function string convert2string();
  //|     convert2string = {"child_field=",field};
  //|   endfunction
  //| endclass
  //|
  //| class obj extends base;
  //|   int addr = 'h123;
  //|   int data = 'h456;
  //|   bit write = 1;
  //|   obj2 child = new;
  //|   virtual function string convert2string();
  //|      convert2string = {super.convert2string(),
  //|        $sformatf(" write=%0d addr=%8h data=%8h ",write,addr,data),
  //|        child.convert2string()};
  //|   endfunction
  //| endclass
  //
  // Then, to display an object, you could write:
  //
  //| obj o = new;
  //| uvm_report_info("BusMaster",{"Sending:\n ",o.convert2string()});
  //
  // The output will look similar to:
  //
  //| UVM_INFO @ 0: reporter [BusMaster] Sending:
  //|    base_field=foo write=1 addr=00000123 data=00000456 child_field=bar


  // // FIXME -- depends on dmd bug 9249
  // // Does not work due to dmd bug
  // // http://d.puremagic.com/issues/show_bug.cgi?id=9249
  // T opCast(T)() if (is(T == string))
  //   {
  //     return "";
  //   }

  T to(T)() if (is(T == string)) {
    return "";
  }

  string convert2string() {
    return this.to!string();
  }

  // Group: Recording

  // Function: record
  //
  // The ~record~ method deep-records this object's properties according to an
  // optional ~recorder~ policy. The method is not virtual and must not be
  // overloaded. To include additional fields in the record operation, derived
  // classes should override the <do_record> method.
  //
  // The optional ~recorder~ argument specifies the recording policy, which
  // governs how recording takes place. See
  // <uvm_recorder> for information.
  //
  // A simulator's recording mechanism is vendor-specific. By providing access
  // via a common interface, the uvm_recorder policy provides vendor-independent
  // access to a simulator's recording capabilities.

  // void uvm_field_auto_record(uvm_recorder recorder) { }
    
  // record the Ith field
  // static void uvm_field_auto_record_field(size_t I=0, T)(T t, uvm_recorder recorder) {
  //   static if (I < t.tupleof.length) {
  //     import std.traits: isIntegral, isFloatingPoint;
  //     enum int FLAGS = uvm_field_auto_get_flags!(t, I);
  //     static if(FLAGS & UVM_RECORD &&
  // 		!(FLAGS & UVM_NORECORD)) {
  // 	debug(UVM_UTILS) {
  // 	  pragma(msg, "Recording : " ~ t.tupleof[I].stringof);
  // 	}
  // 	enum string name = __traits(identifier, T.tupleof[I]);
  // 	auto value = t.tupleof[I];
  // 	alias U=typeof(t.tupleof[I]);
  // 	// do not use isIntegral -- we keep that for enums
  // 	version(UVM_NO_RAND) { }
  // 	else {
  // 	  import esdl.data.rand;
  // 	  static if(is(U: _esdl__ConstraintBase)) {
  // 	    // shortcircuit useful for compare etc
  // 	    uvm_field_auto_record_field!(I+1)(t, recorder);
  // 	    // return;
  // 	  }
  // 	}
  // 	static if(is(U == SimTime)) {
  // 	  recorder.record(name, value);
  // 	}
  // 	else static if(is(U == enum)) { // to cover enums
  // 	  recorder.record(name, value, UVM_ENUM);
  // 	}
  // 	else static if(isBitVector!U  || isIntegral!U) {
  // 	  recorder.record(name, value,
  // 			  cast(uvm_radix_enum) (FLAGS & UVM_RADIX));
  // 	}
  // 	else static if(is(U: uvm_object)) {
  // 	  recorder.record(name, value);
  // 	}
  // 	else static if(is(U == string) || is(U == char[])) {
  // 	  recorder.record(name, value);
  // 	}
  // 	// enum should be already handled as part of integral
  // 	else static if(isFloatingPoint!U) {
  // 	  recorder.record(name, value);
  // 	}
  // 	else static if(is(U: EventObj)) {
  // 	  recorder.record_generic(name, "event", "");
  // 	}
  // 	else // static if(isIntegral!U || isBoolean!U )
  // 	  {
  // 	    import std.conv;
  // 	    recorder.record_generic(name, U.stringof, value.to!string);
  // 	  }
  //     }
  //     uvm_field_auto_record_field!(I+1)(t, recorder);
  //   }
  // }

  final void record(uvm_recorder recorder=null) {

    if(recorder is null) {
      return;
      // recorder = uvm_default_recorder;
    }

    // if(!recorder.tr_handle) return;

    m_uvm_status_container.recorder = recorder;

    synchronized(recorder) {
      recorder.inc_recording_depth();

      m_uvm_object_automation(null, UVM_RECORD, "");
      // uvm_field_auto_record(recorder);

      do_record(recorder);

      recorder.dec_recording_depth();
    }
    // if(recorder.recording_depth is 0) {
    //   recorder.tr_handle = 0;
    // }
  }

  // Function: do_record
  //
  // The ~do_record~ method is the user-definable hook called by the <record>
  // method. A derived class should override this method to include its fields
  // in a record operation.
  //
  // The ~recorder~ argument is policy object for recording this object. A
  // do_record implementation should call the appropriate recorder methods for
  // each of its fields. Vendor-specific recording implementations are
  // encapsulated in the ~recorder~ policy, thereby insulating user-code from
  // vendor-specific behavior. See <uvm_recorder> for more information.
  //
  // A typical implementation is as follows:
  //
  //| class mytype extends uvm_object;
  //|   data_obj data;
  //|   int f1;
  //|   function void do_record (uvm_recorder recorder);
  //|     recorder.record_field("f1", f1, $bits(f1), UVM_DEC);
  //|     recorder.record_object("data", data);
  //|   endfunction

  void do_record (uvm_recorder recorder) {
    return;
  }


  // Group: Copying

  // Function: copy
  //
  // The copy makes this object a copy of the specified object.
  //
  // The ~copy~ method is not virtual and should not be overloaded in derived
  // classes. To copy the fields of a derived class, that class should override
  // the <do_copy> method.

  // void uvm_field_auto_copy(uvm_object rhs) { }

  static uvm_object[uvm_object] _uvm_global_copy_map;

  final void copy(uvm_object rhs) {

    // Thread static
    static int depth;
    if(rhs !is null && rhs in _uvm_global_copy_map) {
      return;
    }

    if(rhs is null) {
      uvm_report_warning("NULLCP", "A null object was supplied to copy;" ~
			 " copy is ignored", UVM_NONE);
      return;
    }

    _uvm_global_copy_map[rhs] = this;

    ++depth;

    m_uvm_object_automation(rhs, UVM_COPY, "");

    // overridden by mixin(uvm_object_utils);
    // uvm_field_auto_copy(rhs);
    
    do_copy(rhs);

    --depth;
    if(depth == 0) {
      _uvm_global_copy_map = null;
    }
  }


  // Function: do_copy
  //
  // The ~do_copy~ method is the user-definable hook called by the copy method.
  // A derived class should override this method to include its fields in a <copy>
  // operation.
  //
  // A typical implementation is as follows:
  //
  //|  class mytype extends uvm_object;
  //|    ...
  //|    int f1;
  //|    function void do_copy (uvm_object rhs);
  //|      mytype rhs_;
  //|      super.do_copy(rhs);
  //|      $cast(rhs_,rhs);
  //|      field_1 = rhs_.field_1;
  //|    endfunction
  //
  // The implementation must call ~super.do_copy~, and it must $cast the rhs
  // argument to the derived type before copying.

  void do_copy (uvm_object rhs) {
    return;
  }


  // Group: Comparing

  // Function: compare
  //
  // Deep compares members of this data object with those of the object provided
  // in the ~rhs~ (right-hand side) argument, returning 1 on a match, 0 otherwise.
  //
  // The ~compare~ method is not virtual and should not be overloaded in derived
  // classes. To compare the fields of a derived class, that class should
  // override the <do_compare> method.
  //
  // The optional ~comparer~ argument specifies the comparison policy. It allows
  // you to control some aspects of the comparison operation. It also stores the
  // results of the comparison, such as field-by-field miscompare information
  // and the total number of miscompares. If a compare policy is not provided,
  // then the global ~uvm_default_comparer~ policy is used. See <uvm_comparer>
  // for more information.

  // void uvm_field_auto_compare(uvm_object rhs) { }

  final bool compare (uvm_object rhs, uvm_comparer comparer = null) {
    if(comparer !is null) {
      m_uvm_status_container.comparer = comparer;
    }
    else {
      m_uvm_status_container.comparer = uvm_default_comparer;
    }
    comparer = m_uvm_status_container.comparer;

    synchronized(comparer) {
      if(! m_uvm_status_container.scope_stack.depth()) {
	comparer.reset_compare_map;
	comparer.result = 0;
	comparer.miscompares = "";
	comparer.scope_stack = m_uvm_status_container.scope_stack;
	if(get_name() == "") {
	  m_uvm_status_container.scope_stack.down("<object>");
	}
	else {
	  m_uvm_status_container.scope_stack.down(this.get_name());
	}
      }

      bool done = false;
      if(! done && (rhs is null)) {
	if(m_uvm_status_container.scope_stack.depth()) {
	  comparer.print_msg_object(this, rhs);
	}
	else {
	  comparer.print_msg_object(this, rhs);
	  uvm_report_info("MISCMP",
			  format("%0d Miscompare(s) for object %s@%0d vs. null",
				 comparer.result,
				 m_uvm_status_container.scope_stack.get(),
				 this.get_inst_id()),
			  m_uvm_status_container.comparer.verbosity);
	  done = true;
	}
      }

      if(! done && (comparer.get_compare_map(rhs) !is null)) {
	if(comparer.get_compare_map(rhs) !is this) {
	  comparer.print_msg_object(this, comparer.get_compare_map(rhs));
	}
	done = true;  //don't do any more work after this case, but do cleanup
      }

      if(! done && comparer.check_type && (rhs !is null) &&
	 (get_type_name() != rhs.get_type_name())) {
	m_uvm_status_container.stringv = "lhs type = \"" ~ get_type_name() ~
	  "\" : rhs type = \"" ~ rhs.get_type_name() ~ "\"";
	comparer.print_msg(m_uvm_status_container.stringv);
      }

      bool dc;

      if(! done) {
	comparer.set_compare_map(rhs, this);

	m_uvm_object_automation(rhs, UVM_COMPARE, "");

	// overridden by mixin(uvm_object_utils);
	// uvm_field_auto_compare(rhs);
	dc = do_compare(rhs, comparer);
      }

      if(m_uvm_status_container.scope_stack.depth() == 1)  {
	m_uvm_status_container.scope_stack.up();
      }

      if(rhs !is null) {
	comparer.print_rollup(this, rhs);
      }
      return (comparer.result == 0 && dc == true);
    }
  }


  // Function: do_compare
  //
  // The ~do_compare~ method is the user-definable hook called by the <compare>
  // method. A derived class should override this method to include its fields
  // in a compare operation. It should return 1 if the comparison succeeds, 0
  // otherwise.
  //
  // A typical implementation is as follows:
  //
  //|  class mytype extends uvm_object;
  //|    ...
  //|    int f1;
  //|    virtual function bit do_compare (uvm_object rhs,uvm_comparer comparer);
  //|      mytype rhs_;
  //|      do_compare = super.do_compare(rhs,comparer);
  //|      $cast(rhs_,rhs);
  //|      do_compare &= comparer.compare_field_int("f1", f1, rhs_.f1);
  //|    endfunction
  //
  // A derived class implementation must call ~super.do_compare()~ to ensure its
  // base class' properties, if any, are included in the comparison. Also, the
  // rhs argument is provided as a generic uvm_object. Thus, you must ~$cast~ it
  // to the type of this object before comparing.
  //
  // The actual comparison should be implemented using the uvm_comparer object
  // rather than direct field-by-field comparison. This enables users of your
  // class to customize how comparisons are performed and how much miscompare
  // information is collected. See uvm_comparer for more details.

  bool do_compare (uvm_object rhs, uvm_comparer comparer) {
    return true;
  }

  // Group: Packing

  // Function: pack

  // void uvm_field_auto_pack() {
  //   uvm_report_warning("NOUTILS", "default uvm_field_auto_pack --"
  // 		       "no uvm_object_utils", UVM_NONE);
  // }

  final size_t pack (ref Bit!1[] bitstream, uvm_packer packer=null) {
    m_pack(packer);
    packer.get_bits(bitstream);
    return packer.get_packed_size();
  }

  final size_t pack (ref bool[] bitstream, uvm_packer packer=null) {
    m_pack(packer);
    packer.get_bits(bitstream);
    return packer.get_packed_size();
  }

  // Function: pack_bytes

  final size_t pack_bytes (ref ubyte[] bytestream,
			   uvm_packer packer=null) {
    m_pack(packer);
    packer.get_bytes(bytestream);
    return packer.get_packed_size();
  }

  // Function: pack_ints
  //
  // The pack methods bitwise-concatenate this object's properties into an array
  // of bits, bytes, or ints. The methods are not virtual and must not be
  // overloaded. To include additional fields in the pack operation, derived
  // classes should override the <do_pack> method.
  //
  // The optional ~packer~ argument specifies the packing policy, which governs
  // the packing operation. If a packer policy is not provided, the global
  // <uvm_default_packer> policy is used. See <uvm_packer> for more information.
  //
  // The return value is the total number of bits packed into the given array.
  // Use the array's built-in ~size~ method to get the number of bytes or ints
  // consumed during the packing process.

  final size_t pack_ints (ref uint[] intstream,
			  uvm_packer packer=null) {
    m_pack(packer);
    packer.get_ints(intstream);
    return packer.get_packed_size();
  }


  // Function: do_pack
  //
  // The ~do_pack~ method is the user-definable hook called by the <pack> methods.
  // A derived class should override this method to include its fields in a pack
  // operation.
  //
  // The ~packer~ argument is the policy object for packing. The policy object
  // should be used to pack objects.
  //
  // A typical example of an object packing itself is as follows
  //
  //|  class mysubtype extends mysupertype;
  //|    ...
  //|    shortint myshort;
  //|    obj_type myobj;
  //|    byte myarray[];
  //|    ...
  //|    function void do_pack (uvm_packer packer);
  //|      super.do_pack(packer); // pack mysupertype properties
  //|      packer.pack_field_int(myarray.size(), 32);
  //|      foreach (myarray)
  //|        packer.pack_field_int(myarray[index], 8);
  //|      packer.pack_field_int(myshort, $bits(myshort));
  //|      packer.pack_object(myobj);
  //|    endfunction
  //
  // The implementation must call ~super.do_pack~ so that base class properties
  // are packed as well.
  //
  // If your object contains dynamic data (object, string, queue, dynamic array,
  // or associative array), and you intend to unpack into an equivalent data
  // structure when unpacking, you must include meta-information about the
  // dynamic data when packing as follows.
  //
  //  - For queues, dynamic arrays, or associative arrays, pack the number of
  //    elements in the array in the 32 bits immediately before packing
  //    individual elements, as shown above.
  //
  //  - For string data types, append a zero byte after packing the string
  //    contents.
  //
  //  - For objects, pack 4 bits immediately before packing the object. For ~null~
  //    objects, pack 4'b0000. For ~non-null~ objects, pack 4'b0001.
  //
  // When the `uvm_field_* macros are used,
  // <Utility and Field Macros for Components and Objects>,
  // the above meta information is included provided the <uvm_packer::use_metadata>
  // variable is set for the packer.
  //
  // Packing order does not need to match declaration order. However, unpacking
  // order must match packing order.

  void do_pack (uvm_packer packer) {
    return;
  }


  // Group: Unpacking

  // Function: unpack

  // void uvm_field_auto_unpack() {
  //   uvm_report_warning("NOUTILS", "default uvm_field_auto_unpack --"
  // 		       "no uvm_object_utils", UVM_NONE);
  // }

  final size_t unpack (ref Bit!1[] bitstream,
		       uvm_packer packer = null) {

    m_unpack_pre(packer);
    packer.put_bits(bitstream);
    m_unpack_post(packer);
    packer.set_packed_size();
    return packer.get_packed_size();
  }

  final size_t unpack (ref bool[] bitstream,
		       uvm_packer packer = null) {
    m_unpack_pre(packer);
    packer.put_bits(bitstream);
    m_unpack_post(packer);
    packer.set_packed_size();
    return packer.get_packed_size();
  }

  // Function: unpack_bytes

  final size_t unpack_bytes (ref ubyte[] bytestream,
			     uvm_packer packer = null) {
    m_unpack_pre(packer);
    packer.put_bytes(bytestream);
    m_unpack_post(packer);
    packer.set_packed_size();
    return packer.get_packed_size();
  }

  // Function: unpack_ints
  //
  // The unpack methods extract property values from an array of bits, bytes, or
  // ints. The method of unpacking ~must~ exactly correspond to the method of
  // packing. This is assured if (a) the same ~packer~ policy is used to pack
  // and unpack, and (b) the order of unpacking is the same as the order of
  // packing used to create the input array.
  //
  // The unpack methods are fixed (non-virtual) entry points that are directly
  // callable by the user. To include additional fields in the <unpack>
  // operation, derived classes should override the <do_unpack> method.
  //
  // The optional ~packer~ argument specifies the packing policy, which governs
  // both the pack and unpack operation. If a packer policy is not provided,
  // then the global ~uvm_default_packer~ policy is used. See uvm_packer for
  // more information.
  //
  // The return value is the actual number of bits unpacked from the given array.

  final size_t unpack_ints (ref uint[] intstream,
			    uvm_packer packer = null) {
    m_unpack_pre(packer);
    packer.put_ints(intstream);
    m_unpack_post(packer);
    packer.set_packed_size();
    return packer.get_packed_size();
  }


  // Function: do_unpack
  //
  // The ~do_unpack~ method is the user-definable hook called by the <unpack>
  // method. A derived class should override this method to include its fields
  // in an unpack operation.
  //
  // The ~packer~ argument is the policy object for both packing and unpacking.
  // It must be the same packer used to pack the object into bits. Also,
  // do_unpack must unpack fields in the same order in which they were packed.
  // See <uvm_packer> for more information.
  //
  // The following implementation corresponds to the example given in do_pack.
  //
  //|  function void do_unpack (uvm_packer packer);
  //|   int sz;
  //|    super.do_unpack(packer); // unpack super's properties
  //|    sz = packer.unpack_field_int(myarray.size(), 32);
  //|    myarray.delete();
  //|    for(int index=0; index<sz; index++)
  //|      myarray[index] = packer.unpack_field_int(8);
  //|    myshort = packer.unpack_field_int($bits(myshort));
  //|    packer.unpack_object(myobj);
  //|  endfunction
  //
  // If your object contains dynamic data (object, string, queue, dynamic array,
  // or associative array), and you intend to <unpack> into an equivalent data
  // structure, you must have included meta-information about the dynamic data
  // when it was packed.
  //
  // - For queues, dynamic arrays, or associative arrays, unpack the number of
  //   elements in the array from the 32 bits immediately before unpacking
  //   individual elements, as shown above.
  //
  // - For string data types, unpack into the new string until a ~null~ byte is
  //   encountered.
  //
  // - For objects, unpack 4 bits into a byte or int variable. If the value
  //   is 0, the target object should be set to ~null~ and unpacking continues to
  //   the next property, if any. If the least significant bit is 1, then the
  //   target object should be allocated and its properties unpacked.

  void do_unpack (uvm_packer packer) {
    return;
  }

  void do_vpi_put(uvm_vpi_iter iter) { }

  void do_vpi_get(uvm_vpi_iter iter) { }
  
  // Group: Configuration
  // static bool uvm_set_value(E, U)(ref E var, U value) {
  //   static if(is(U: E)) {
  //     var = value;
  //     return true;
  //   }
  //   else static if(is(E: U) && is(U: Object)) {
  //     auto var_ = cast(E) value;
  //     if (var_ !is null) {
  // 	var = var_;
  // 	return true;
  //     }
  //     else {
  // 	return false;
  //     }
  //   }
  //   else static if(is(U: string) && is(E == enum)) {
  //     if ((uvm_enum_wrapper!E).from_name(value, var)) {
  // 	return true;
  //     }
  //     else return false;
  //   }
  //   else static if ((isIntegral!U || is(U == bool)) &&
  // 		   is(E == enum) && E.sizeof >= U.sizeof) {
  //     var = cast(E) value;
  //     return true;
  //   }
  //   else static if (((isIntegral!E || isBitVector!E) &&
  // 		     isBitVector!U) ||
  // 		    (isIntegral!E && isIntegral!U)) {
  //     E v = cast(E) value;
  //     if (v == value) {
  // 	var = v;
  // 	return true;
  //     }
  //     else {
  // 	return false;
  //     }
  //   }
  //   else static if (isBitVector!E && isIntegral!U) {
  //     E v = cast(E) value.toBitVec;
  //     if (v == value) {
  // 	var = v;
  // 	return true;
  //     }
  //     else {
  // 	return false;
  //     }
  //   }
  //   else {
  //     return false;
  //   }
  // }

  void set_local(T)(string field_name, T value,
		    bool recurse = true)
    if (isIntegral!T || isBitVector!T || is(T == enum) || is(T == bool)) {
      m_uvm_status_container.reset_cycle_checks();
      m_uvm_status_container.reset_cycle_scopes();

      m_uvm_status_container.status = 0;
	
      static if (isBitVector!T || isIntegral!T ||
		 is(T == enum) || is(T == bool)) {
	m_uvm_status_container.bitstream = value;
	m_uvm_object_automation(null, UVM_SETINT, field_name);
      }
      if (m_uvm_status_container.warning &&
	  ! m_uvm_status_container.status) {
	uvm_report_error("NOMTC", format("did not find a match for" ~
					 " field %s", field_name), UVM_NONE);
      }
      m_uvm_status_container.reset_cycle_checks();
    }

  void set_local(T)(string field_name, T value,
		    bool clone = true, bool recurse = true)
    if (is(T: uvm_object)) {
      m_uvm_status_container.reset_cycle_checks();
      m_uvm_status_container.reset_cycle_scopes();

      m_uvm_status_container.status = 0;

      uvm_object value_;
      if (clone && (value !is null)) {
	value_ = value.clone();
	if (value_ !is null) {
	  value_.set_name(field_name);
	}
      }
      else {
	value_ = value;
      }

      m_uvm_status_container.object = value_;
      m_uvm_object_automation(null, UVM_SETOBJ, field_name);

      if (m_uvm_status_container.warning &&
	  ! m_uvm_status_container.status) {
	uvm_report_error("NOMTC", format("did not find a match for" ~
					 " field %s", field_name), UVM_NONE);
      }
      m_uvm_status_container.reset_cycle_checks();
    }

  void set_local(T)(string field_name, T value,
		    bool recurse = true)
    if (is(T == string)) {
      m_uvm_status_container.reset_cycle_checks();
      m_uvm_status_container.reset_cycle_scopes();

      m_uvm_status_container.status = 0;
      static if (is(T == string)) {
	m_uvm_status_container.stringv = value;
	m_uvm_object_automation(null, UVM_SETSTR, field_name);
      }
      if (m_uvm_status_container.warning &&
	  ! m_uvm_status_container.status) {
	uvm_report_error("NOMTC", format("did not find a match for" ~
					 " field %s", field_name), UVM_NONE);
      }
      m_uvm_status_container.reset_cycle_checks();
    }

  // void uvm_set_local(size_t I=0, T, U)(T t, string regx, U value,
  // 				       ref bool matched, string prefix = "",
  // 				       uvm_object[] hier = []) {
  //   import std.traits: isArray;
  //   static if(I < t.tupleof.length) {
  //     enum int FLAGS = uvm_field_auto_get_flags!(t, I);
  //     alias E = typeof(t.tupleof[I]);
  //     string name = prefix ~ __traits(identifier, T.tupleof[I]);
  //     // handle arrays
  //     static if (isArray!E && ! is(E: string)) {
  // 	// Array elements inherit FLAGS
  // 	uvm_set_local!FLAGS(t.tupleof[I], 0, // index
  // 			    regx, value, matched, name, hier);
  //     }
  //     else {
  // 	static if ((! (FLAGS & UVM_REFERENCE)) &&
  // 		   is(E: uvm_object)) {
  // 	  bool cyclic = false;
  // 	  // first check for any cycle
  // 	  foreach (obj; hier) {
  // 	    if (obj is t.tupleof[I]) {
  // 	      cyclic = true;
  // 	    }
  // 	  }
  // 	  if (! cyclic && t.tupleof[I] !is null) {
  // 	    t.tupleof[I].uvm_field_auto_set(regx, value, matched,
  // 					    name ~ ".", hier ~ this);
  // 	  }
  // 	}
  // 	static if(FLAGS & UVM_READONLY) {
  // 	  if(uvm_is_match(regx, name)) {
  // 	    uvm_report_warning("RDONLY",
  // 			       format("Readonly argument match %s is ignored",
  // 				      name), UVM_NONE);
  // 	  }
  // 	}
  // 	else {
  // 	  if(uvm_is_match(regx, name)) {
  // 	    matched = true;
  // 	    if (! uvm_set_value!(E, U)(t.tupleof[I], value)) {
  // 	      uvm_report_error("SETLCL",
  // 			       format("Could not set value %s to variable %s",
  // 				      value, name));
  // 	    }
  // 	  }
  // 	  else {
  // 	    // uvm_report_info("NOMATCH", "set_object()" ~ ": Could not match string " ~
  // 	    // 		    regx ~ " to field " ~ name,
  // 	    // 		    UVM_LOW);
  // 	  }
  // 	}
  //     }
  //     uvm_set_local!(I+1)(t, regx, value, matched, prefix, hier);
  //   }
  // }

  // // Handle array elements
  // void uvm_set_local(int FLAGS, T, U)(ref T t, size_t index, string regx, U value,
  // 				      ref bool matched, string prefix = "",
  // 				      uvm_object[] hier = [])
  // if (isArray!T && ! is(T: string)) {
  //   import std.traits: isArray;
  //   import std.string: format;
  //   if (index < t.length) {
  //     alias E = typeof(t[index]);
  //     string name = prefix ~ format("[%0d]", index);
  //     // handle arrays
  //     static if (isArray!E && ! is(E: string)) {
  // 	// Array elements inherit FLAGS
  // 	uvm_set_local!FLAGS(t[index], 0, regx, value,
  // 			    matched, name, hier);
  //     }
  //     else {
  // 	static if ((! (FLAGS & UVM_REFERENCE)) &&
  // 		   is(E: uvm_object)) {
  // 	  bool cyclic = false;
  // 	  // first check for any cycle
  // 	  foreach (obj; hier) {
  // 	    if (obj is t[index]) {
  // 	      cyclic = true;
  // 	    }
  // 	  }
  // 	  if (! cyclic && t[index] !is null) {
  // 	    t[index].uvm_field_auto_set(regx, value, matched,
  // 					name ~ ".", hier ~ this);
  // 	  }
  // 	}
  // 	static if(FLAGS & UVM_READONLY) {
  // 	  if(uvm_is_match(regx, name)) {
  // 	    uvm_report_warning("RDONLY",
  // 			       format("Readonly argument match %s is ignored",
  // 				      name),
  // 			       UVM_NONE);
  // 	  }
  // 	}
  // 	else {
  // 	  if(uvm_is_match(regx, name)) {
  // 	    matched = true;
  // 	    if (! uvm_set_value!(E, U)(t[index], value)) {
  // 	      uvm_report_error("SETLCL",
  // 			       format("Could not set value %s to variable %s",
  // 				      value, name));
  // 	    }
  // 	  }
  // 	  else {
  // 	    // uvm_report_info("NOMATCH", "set_object()" ~ ": Could not match string " ~
  // 	    // 		      regx ~ " to field " ~ name, UVM_LOW);
  // 	  }
  // 	}
  //     }
  //     uvm_set_local!(FLAGS)(t, index+1, regx, value, matched, prefix, hier);
  //   }
  // }

  // Function: set_int_local

  // void uvm_field_auto_set(string field_name, uvm_bitstream_t value,
  // 			  ref bool match, string prefix,
  // 			  uvm_object[] hier) { }
  // void uvm_field_auto_set(string field_name, uvm_integral_t value,
  // 			  ref bool match, string prefix,
  // 			  uvm_object[] hier) { }
  // void uvm_field_auto_set(string field_name, ulong value,
  // 			  ref bool match, string prefix,
  // 			  uvm_object[] hier) { }
  // void uvm_field_auto_set(string field_name, uint value,
  // 			  ref bool match, string prefix,
  // 			  uvm_object[] hier) { }
  // void uvm_field_auto_set(string field_name, ushort value,
  // 			  ref bool match, string prefix,
  // 			  uvm_object[] hier) { }
  // void uvm_field_auto_set(string field_name, ubyte value,
  // 			  ref bool match, string prefix,
  // 			  uvm_object[] hier) { }
  // void uvm_field_auto_set(string field_name, bool value,
  // 			  ref bool match, string prefix,
  // 			  uvm_object[] hier) { }

  void set_int_local(T)(string field_name,
			T value,
			bool   recurse = true)
  if (isIntegral!T || isBitVector!T ||
      is(T == enum)) {
    set_local(field_name, value, recurse);
  }
  
  // Function: set_string_local

  // void uvm_field_auto_set(string field_name, string value,
  // 			  ref bool matched, string prefix,
  // 			  uvm_object[] hier) { }
  
  void set_string_local (string field_name,
			 string value,
			 bool   recurse = true) {
    set_local(field_name, value, recurse);
  }

  // Function: set_object_local
  //
  // These methods provide write access to integral, string, and
  // uvm_object-based properties indexed by a ~field_name~ string. The object
  // designer choose which, if any, properties will be accessible, and overrides
  // the appropriate methods depending on the properties' types. For objects,
  // the optional ~clone~ argument specifies whether to clone the ~value~
  // argument before assignment.
  //
  // The global <uvm_is_match> function is used to match the field names, so
  // ~field_name~ may contain wildcards.
  //
  // An example implementation of all three methods is as follows.
  //
  //| class mytype extends uvm_object;
  //|
  //|   local int myint;
  //|   local byte mybyte;
  //|   local shortint myshort; // no access
  //|   local string mystring;
  //|   local obj_type myobj;
  //|
  //|   // provide access to integral properties
  //|   function void set_int_local(string field_name, uvm_bitstream_t value);
  //|     if (uvm_is_match (field_name, "myint"))
  //|       myint = value;
  //|     else if (uvm_is_match (field_name, "mybyte"))
  //|       mybyte = value;
  //|   endfunction
  //|
  //|   // provide access to string properties
  //|   function void set_string_local(string field_name, string value);
  //|     if (uvm_is_match (field_name, "mystring"))
  //|       mystring = value;
  //|   endfunction
  //|
  //|   // provide access to sub-objects
  //|   function void set_object_local(string field_name, uvm_object value,
  //|                                  bit clone=1);
  //|     if (uvm_is_match (field_name, "myobj")) begin
  //|       if (value !is null) begin
  //|         obj_type tmp;
  //|         // if provided value is not correct type, produce error
  //|         if (!$cast(tmp, value) )
  //|           /* error */
  //|         else begin
  //|           if(clone)
  //|             $cast(myobj, tmp.clone());
  //|           else
  //|             myobj = tmp;
  //|         end
  //|       end
  //|       else
  //|         myobj = null; // value is null, so simply assign null to myobj
  //|     end
  //|   endfunction
  //|   ...
  //
  // Although the object designer implements these methods to provide outside
  // access to one or more properties, they are intended for internal use (e.g.,
  // for command-line debugging and auto-configuration) and should not be called
  // directly by the user.

  // void uvm_field_auto_set(string field_name, uvm_object value,
  // 			  ref bool matched, string prefix,
  // 			  uvm_object[] hier) { }
  
  void set_object_local (string field_name, uvm_object value,
			 bool   clone   = true,
			 bool   recurse = true) {
    set_local(field_name, value, clone, recurse);
  }

  //---------------------------------------------------------------------------
  //                 **** Internal Methods and Properties ***
  //                           Do not use directly
  //---------------------------------------------------------------------------

  final private void m_pack(ref uvm_packer packer) {
    if(packer !is null) {
      m_uvm_status_container.packer = packer;
    }
    else {
      m_uvm_status_container.packer = uvm_default_packer;
    }
    packer = m_uvm_status_container.packer;

    packer.reset();
    packer.scope_stack.down(get_name());

    m_uvm_object_automation(null, UVM_PACK, "");
    do_pack(packer);

    packer.set_packed_size();

    packer.scope_stack.up();
  }

  final private void m_unpack_pre  (ref uvm_packer packer) {
    if(packer !is null) {
      m_uvm_status_container.packer = packer;
    }
    else {
      m_uvm_status_container.packer = uvm_default_packer;
    }
    packer = m_uvm_status_container.packer;
    packer.reset();
  }

  private final void m_unpack_post (uvm_packer packer) {
    size_t provided_size = packer.get_packed_size();

    //Put this object into the hierarchy
    packer.scope_stack.down(get_name());

    m_uvm_object_automation(null, UVM_UNPACK, "");

    do_unpack(packer);

    //Scope back up before leaving
    packer.scope_stack.up();

    if(packer.get_packed_size() !is provided_size) {
      uvm_report_warning("BDUNPK",
			 format("Unpack operation unsuccessful: unpacked " ~
				"%0d bits from a total of %0d bits",
				packer.get_packed_size(), provided_size),
			 UVM_NONE);
    }
  }

  // The print_matches bit causes an informative message to be printed
  // when a field is set using one of the set methods.

  @uvm_private_sync
  private string _m_leaf_name;

  @uvm_private_sync
  private int _m_inst_id;

  // static protected int m_inst_count;
  // static /*protected*/ uvm_status_container m_uvm_status_container = new;

  void m_uvm_object_automation(uvm_object tmp_data__,
			       int        what__,
			       string     str__) { }

  protected uvm_report_object m_get_report_object() {
    return null;
  }

}


template uvm_field_auto_get_flags(alias t, size_t I)
{
  enum int uvm_field_auto_get_flags =
    uvm_field_auto_acc_flags!(__traits(getAttributes, t.tupleof[I]));
}

template uvm_field_auto_acc_flags(A...)
{
  import uvm.base.uvm_object_globals: uvm_recursion_policy_enum,
                                      uvm_field_auto_enum;
  static if(A.length is 0) {
    enum int uvm_field_auto_acc_flags = 0;
  }
  else static if(is(typeof(A[0]) == uvm_recursion_policy_enum) ||
		 is(typeof(A[0]) == uvm_field_auto_enum) ||
		 is(typeof(A[0]) == uvm_radix_enum)) {
      enum int uvm_field_auto_acc_flags = A[0] |
	uvm_field_auto_acc_flags!(A[1..$]);
    }
    else {
      enum int uvm_field_auto_acc_flags = uvm_field_auto_acc_flags!(A[1..$]);
    }
}
  
