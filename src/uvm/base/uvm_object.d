//
//-----------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2010-2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2010-2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2017-2018 Cisco Systems, Inc.
// Copyright 2017 Verific
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

// version (UVM_NO_DEPRECATED) { }
//  else {
//    version = UVM_INCLUDE_DEPRECATED;
//  }

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_object
//
// The uvm_object class is the base class for all UVM data and hierarchical
// classes. Its primary role is to define a set of methods for such common
// operations as <create>, <copy>, <compare>, <print>, and <record>. Classes
// deriving from uvm_object must implement the pure virtual methods such as
// <create> and <get_type_name>.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_misc: uvm_void;
import uvm.base.uvm_recorder; // TBD IMPORTS


import uvm.base.uvm_scope;
import uvm.base.uvm_factory: uvm_object_wrapper;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_copier: uvm_copier;
import uvm.base.uvm_resource_base: uvm_resource_base;
import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_coreservice: uvm_coreservice_t;
import uvm.base.uvm_comparer: uvm_comparer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_field_op: uvm_field_op;
import uvm.base.uvm_globals: uvm_report_info;
import uvm.base.uvm_globals: uvm_error;
import uvm.base.uvm_object_globals: uvm_field_auto_enum, uvm_field_xtra_enum;

import uvm.meta.mcd;
import uvm.meta.misc;
import uvm.vpi.uvm_vpi_intf;

import esdl.base.core;
import esdl.data.bvec;
import esdl.rand.misc: rand;

version (UVM_NO_RAND) {}
 else {
   import esdl.rand;
 }

import std.traits;
import std.string: format;

import std.random: uniform;
import std.range: ElementType;

// @uvm-ieee 1800.2-2017 auto 5.3.1
@rand(false)
abstract class uvm_object: uvm_void
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_protected_sync
    private int _m_inst_count;
  }

  // Can not use "mixin uvm_scope_sync" template due to forward reference error
  // Using string Mixin function
  // mixin uvm_scope_sync;
  mixin (uvm_scope_sync_string);
  mixin (uvm_lock_string);


  version (UVM_NO_RAND) {}
  else {
    mixin Randomization;
  }

  // Function -- NODOCS -- new

  // Creates a new uvm_object with the given instance ~name~. If ~name~ is not
  // supplied, the object is unnamed.

  this(string name="") {
    int inst_id;
    synchronized (_uvm_scope_inst) {
      inst_id = _uvm_scope_inst._m_inst_count++;
    }
    synchronized (this) {
      _m_inst_id = inst_id;
      _m_leaf_name = name;
    }
  }

  // Group -- NODOCS -- Seeding

  // Variable -- NODOCS -- use_uvm_seeding
  //
  // This bit enables or disables the UVM seeding mechanism. It globally affects
  // the operation of the <reseed> method.
  //
  // When enabled, UVM-based objects are seeded based on their type and full
  // hierarchical name rather than allocation order. This improves random
  // stability for objects whose instance names are unique across each type.
  // The <uvm_component> class is an example of a type that has a unique
  // instance name.

  // Moved to _uvm_scope_inst
  // shared static bool use_uvm_seeding = true;


  // @uvm-ieee 1800.2-2017 auto 5.3.3.1
  static bool get_uvm_seeding() {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    return cs.get_uvm_seeding();
  }

      
  // Function -- NODOCS -- set_uvm_seeding

  // @uvm-ieee 1800.2-2017 auto 5.3.3.2
  static void set_uvm_seeding(bool enable) {
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    cs.set_uvm_seeding(enable);
  }
   
  // Function -- NODOCS -- reseed
  //
  // Calls ~srandom~ on the object to reseed the object using the UVM seeding
  // mechanism, which sets the seed based on type name and instance name instead
  // of based on instance position in a thread.
  //
  // If <get_uvm_seeding> returns 0, then reseed() does
  // not perform any function.

  final void reseed (int seed) {
    version (UVM_NO_RAND) {}
    else {
      this.srandom(seed);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 5.3.3.3
  final void reseed () {
    import uvm.base.uvm_misc: uvm_create_random_seed;
    synchronized (this) {
      if (get_uvm_seeding) {
	version (UVM_NO_RAND) {}
	else {
	  this.srandom(uvm_create_random_seed(get_type_name(),
					      get_full_name()));
	}
      }
    }
  }

  // In SV every class object is randomizable by default. Seeding in
  // SV happens right at the time when an object is created.
  // In EUVM, seeding is lazy. It happens only when a randomize (or
  // the related function like srandom) is called.
  // This is the hookup function in EUVM to ensure randomization stability
  void _esdl__seedRandom() {
    version (UVM_NO_RAND) {}
    else {
      if (! _esdl__isRandSeeded()) {
	auto proc = Procedure.self;
	if (proc !is null) {
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
  }

  // // Group -- NODOCS -- Identification

  // // Function -- NODOCS -- set_name
  // //
  // // Sets the instance name of this object, overwriting any previously
  // // given name.

  // @uvm-ieee 1800.2-2017 auto 5.3.4.1
  void set_name(string name) {
    synchronized (this) {
      _m_leaf_name = name;
    }
  }


  // Function -- NODOCS -- get_name
  //
  // Returns the name of the object, as provided by the ~name~ argument in the
  // <new> constructor or <set_name> method.

  // @uvm-ieee 1800.2-2017 auto 5.3.4.2
  string get_name() {
    synchronized (this) {
      return _m_leaf_name;
    }
  }


  // Function -- NODOCS -- get_full_name
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

  // @uvm-ieee 1800.2-2017 auto 5.3.4.3
  string get_full_name() {
    return get_name();
  }



  // Function -- NODOCS -- get_inst_id
  //
  // Returns the object's unique, numeric instance identifier.

  // @uvm-ieee 1800.2-2017 auto 5.3.4.4
  int get_inst_id() {
    return _m_inst_id; // effectively immutable
  }


  // Function -- NODOCS -- get_inst_count
  //
  // Returns the current value of the instance counter, which represents the
  // total number of uvm_object-based objects that have been allocated in
  // simulation. The instance counter is used to form a unique numeric instance
  // identifier.

  static int get_inst_count() {
    synchronized (_uvm_scope_inst) {
      return _uvm_scope_inst._m_inst_count;
    }
  }


  // Function -- NODOCS -- get_type
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

  static uvm_object_wrapper get_type() {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;

    uvm_report_error("NOTYPID", "get_type not implemented in derived class.",
		     uvm_verbosity.UVM_NONE);
    return null;
  }


  // Function -- NODOCS -- get_object_type
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

  uvm_object_wrapper get_object_type() {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_factory;
    if (get_type_name() == "<unknown>") return null;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    return factory.find_wrapper_by_name(get_type_name());
  }


  // Function -- NODOCS -- get_type_name
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
  //|    static function string type_name(); return "myType"; endfunction : type_name
  //|
  //|    virtual function string get_type_name();
  //|      return type_name;
  //|    endfunction
  //
  // We define the ~type_name~ static method to enable access to the type name
  // without need of an object of the class, i.e., to enable access via the
  // scope operator, ~mytype::type_name~.


  // FIXME
  // the best way to handle this method would be to define a global
  // method with the following functionality:
  // auto oci = typeid(this);
  // return oci.to!string();
  // it will then be available via UFCS
  string get_type_name() {
    return "<unknown>";
  }

  // Group -- NODOCS -- Creation

  // Function -- NODOCS -- create
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

  uvm_object create(string name = "") {
    return null;
  }

  // Function -- NODOCS -- clone
  //
  // The ~clone~ method creates and returns an exact copy of this object.
  //
  // The default implementation calls <create> followed by <copy>. As clone is
  // virtual, derived classes may override this implementation if desired.

  // @uvm-ieee 1800.2-2017 auto 5.3.5.2
  uvm_object clone() {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    uvm_object tmp = this.create(get_name());
    if (tmp is null) {
      uvm_report_warning("CRFLD",
			 format("The create method failed for %s,  " ~
				"object cannot be cloned", get_name()),
			 uvm_verbosity.UVM_NONE);
    }
    else
      tmp.copy(this);
    return tmp;
  }


  // Group -- NODOCS -- Printing

  // Function -- NODOCS -- print
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

  // @uvm-ieee 1800.2-2017 auto 5.3.6.1
  final void print(uvm_printer printer = null) {
    if (printer is null) printer = uvm_printer.get_default();
    vfdisplay(printer.get_file(), sprint(printer)); 
  }


  // Function -- NODOCS -- sprint
  //
  // The ~sprint~ method works just like the <print> method, except the output
  // is returned in a string rather than displayed.
  //
  // The ~sprint~ method is not virtual and must not be overloaded. To include
  // additional fields in the <print> and ~sprint~ operation, derived classes
  // must override the <do_print> method and use the provided printer policy
  // class to format the output. The printer policy will manage all string
  // concatenations and provide the string to ~sprint~ to return to the caller.

  // @uvm-ieee 1800.2-2017 auto 5.3.6.2
  final string sprint(uvm_printer printer=null) {
    if (printer is null) printer = uvm_printer.get_default();
    synchronized (printer) {
      string name;
      if (printer.get_active_object_depth() == 0) {
	printer.flush() ;
	name = printer.get_root_enabled() ? get_full_name() : get_name();
      }
      else {
	name  = get_name();
      }
  
      printer.print_object(name, this);
  
      return printer.emit();
    }

  }


  // Function -- NODOCS -- do_print
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

  // @uvm-ieee 1800.2-2017 auto 5.3.6.3
  void do_print(uvm_printer printer) {
    return;
  }


  // Function -- NODOCS -- convert2string
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
  // T opCast(T)() if (is (T == string))
  //   {
  //     return "";
  //   }

  T to(T)() if (is (T == string)) {
    return "";
  }

  // @uvm-ieee 1800.2-2017 auto 5.3.6.4
  string convert2string() {
    return this.to!string();
  }

  // Group -- NODOCS -- Recording

  // Function -- NODOCS -- record
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
  //     static if (FLAGS & uvm_field_auto_enum.UVM_RECORD &&
  // 		!(FLAGS & uvm_field_auto_enum.UVM_NORECORD)) {
  // 	debug(UVM_UTILS) {
  // 	  pragma(msg, "Recording : " ~ t.tupleof[I].stringof);
  // 	}
  // 	enum string name = __traits(identifier, T.tupleof[I]);
  // 	auto value = t.tupleof[I];
  // 	alias U=typeof(t.tupleof[I]);
  // 	// do not use isIntegral -- we keep that for enums
  // 	version (UVM_NO_RAND) { }
  // 	else {
  // 	  import esdl.rand;
  // 	  static if (is (U: _esdl__ConstraintBase)) {
  // 	    // shortcircuit useful for compare etc
  // 	    uvm_field_auto_record_field!(I+1)(t, recorder);
  // 	    // return;
  // 	  }
  // 	}
  // 	static if (is (U == SimTime)) {
  // 	  recorder.record(name, value);
  // 	}
  // 	else static if (is (U == enum)) { // to cover enums
  // 	  recorder.record(name, value, UVM_ENUM);
  // 	}
  // 	else static if (isBitVector!U  || isIntegral!U) {
  // 	  recorder.record(name, value,
  // 			  cast (uvm_radix_enum) (FLAGS & UVM_RADIX));
  // 	}
  // 	else static if (is (U: uvm_object)) {
  // 	  recorder.record(name, value);
  // 	}
  // 	else static if (is (U == string) || is (U == char[])) {
  // 	  recorder.record(name, value);
  // 	}
  // 	// enum should be already handled as part of integral
  // 	else static if (isFloatingPoint!U) {
  // 	  recorder.record(name, value);
  // 	}
  // 	else static if (is (U: EventObj)) {
  // 	  recorder.record_generic(name, "event", "");
  // 	}
  // 	else // static if (isIntegral!U || isBoolean!U )
  // 	  {
  // 	    import std.conv;
  // 	    recorder.record_generic(name, U.stringof, value.to!string);
  // 	  }
  //     }
  //     uvm_field_auto_record_field!(I+1)(t, recorder);
  //   }
  // }

  // @uvm-ieee 1800.2-2017 auto 5.3.7.1
  final void record(uvm_recorder recorder=null) {
    if (recorder is null)
      return;

    recorder.record_object(get_name(), this);
  }

  // Function -- NODOCS -- do_record
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

  // @uvm-ieee 1800.2-2017 auto 5.3.7.2
  void do_record(uvm_recorder recorder) { }


  // Group -- NODOCS -- Copying

  // Function -- NODOCS -- copy
  //
  // The copy makes this object a copy of the specified object.
  //
  // The ~copy~ method is not virtual and should not be overloaded in derived
  // classes. To copy the fields of a derived class, that class should override
  // the <do_copy> method.


  // @uvm-ieee 1800.2-2017 auto 5.3.8.1
  final void copy(uvm_object rhs, uvm_copier copier=null) {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;

    uvm_copier m_copier;

    if (rhs is null) {
      uvm_error("OBJ/COPY","Passing a null object to be copied");
      return;
    }

    if (copier is null) {
      uvm_coreservice_t coreservice = uvm_coreservice_t.get();
      m_copier = coreservice.get_default_copier();
    }
    else 
      m_copier = copier;

    synchronized (m_copier) {
      // Copier is available. check depth as and flush it. Sec 5.3.8.1
      if (m_copier.get_active_object_depth() == 0) 
	m_copier.flush();

      m_copier.copy_object(this, rhs);
    }
  }


  // Function -- NODOCS -- do_copy
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

  // @uvm-ieee 1800.2-2017 auto 5.3.8.2
  void do_copy(uvm_object rhs) {
    return;
  }


  // Group -- NODOCS -- Comparing

  // Function -- NODOCS -- compare
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

  // @uvm-ieee 1800.2-2017 auto 5.3.9.1
  final bool compare(uvm_object rhs, uvm_comparer comparer = null) {
    if (comparer is null) comparer = uvm_comparer.get_default();
    synchronized (comparer) {
      if (comparer.get_active_object_depth() == 0) 
	comparer.flush() ;
      return comparer.compare_object(get_name(), this, rhs);
    }
  }


  // Function -- NODOCS -- do_compare
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

  // @uvm-ieee 1800.2-2017 auto 5.3.9.2
  bool do_compare(uvm_object rhs, uvm_comparer comparer) {
    return true;
  }

  // Group -- NODOCS -- Packing

  // Function -- NODOCS -- pack

  // void uvm_field_auto_pack() {
  //   uvm_report_warning("NOUTILS", "default uvm_field_auto_pack --"
  // 		       "no uvm_object_utils", uvm_verbosity.UVM_NONE);
  // }

  // @uvm-ieee 1800.2-2017 auto 5.3.10.1
  final size_t pack(ref bool[] bitstream, uvm_packer packer=null) {
    m_pack(packer);
    packer.get_packed_bits(bitstream);
    return packer.get_packed_size();
  }

  // Function -- NODOCS -- pack_bytes

  // @uvm-ieee 1800.2-2017 auto 5.3.10.1
  final size_t pack_bytes(ref ubyte[] bytestream,
			  uvm_packer packer=null) {
    m_pack(packer);
    packer.get_packed_bytes(bytestream);
    return packer.get_packed_size();
  }

  // Function -- NODOCS -- pack_ints
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

  // @uvm-ieee 1800.2-2017 auto 5.3.10.1
  final size_t pack_ints(ref uint[] intstream,
			 uvm_packer packer=null) {
    m_pack(packer);
    packer.get_packed_ints(intstream);
    return packer.get_packed_size();
  }


  // @uvm-ieee 1800.2-2017 auto 5.3.10.1
  final size_t pack_longints(ref ulong[] longintstream,
			  uvm_packer packer=null) {
    m_pack(packer);
    packer.get_packed_longints(longintstream);
    return packer.get_packed_size();
  }
  
  // Function -- NODOCS -- do_pack
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
  // the above meta information is included.
  //
  // Packing order does not need to match declaration order. However, unpacking
  // order must match packing order.

  // @uvm-ieee 1800.2-2017 auto 5.3.10.2
  void do_pack(uvm_packer packer) {
    if (packer is null)
      uvm_error("UVM/OBJ/PACK/NULL",
		"uvm_object::do_pack called with null packer!");
    return;
  }


  // Group -- NODOCS -- Unpacking

  // Function -- NODOCS -- unpack

  // void uvm_field_auto_unpack() {
  //   uvm_report_warning("NOUTILS", "default uvm_field_auto_unpack --"
  // 		       "no uvm_object_utils", uvm_verbosity.UVM_NONE);
  // }

  // @uvm-ieee 1800.2-2017 auto 5.3.11.1
  final size_t unpack(ref bool[] bitstream,
		      uvm_packer packer = null) {
    m_unpack_pre(packer);
    packer.set_packed_bits(bitstream);
    return m_unpack_post(packer);
  }

  // Function -- NODOCS -- unpack_bytes

  // @uvm-ieee 1800.2-2017 auto 5.3.11.1
  final size_t unpack_bytes(ref ubyte[] bytestream,
			    uvm_packer packer = null) {
    m_unpack_pre(packer);
    packer.set_packed_bytes(bytestream);
    return m_unpack_post(packer);
  }

  // Function -- NODOCS -- unpack_ints
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

  // @uvm-ieee 1800.2-2017 auto 5.3.11.1
  final size_t unpack_ints(ref uint[] intstream,
			   uvm_packer packer=null) {
    m_unpack_pre(packer);
    packer.set_packed_ints(intstream);
    return m_unpack_post(packer);
  }

  // @uvm-ieee 1800.2-2017 auto 5.3.11.1
  int unpack_longints(ref ulong[] longintstream,
		      uvm_packer packer=null) {
    m_unpack_pre(packer);
    packer.set_packed_longints(longintstream);
    return m_unpack_post(packer);
  }
  
  // Function -- NODOCS -- do_unpack
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
  //|    for (int index=0; index<sz; index++)
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

  // @uvm-ieee 1800.2-2017 auto 5.3.11.2
  void do_unpack(uvm_packer packer) {
    if (packer is null)
      uvm_error("UVM/OBJ/UNPACK/NULL",
		"uvm_object::do_unpack called with null packer!");
    return;
  }

  // @uvm-ieee 1800.2-2017 auto 5.3.13.1
  void do_execute_op(uvm_field_op op) { }

  void m_uvm_execute_field_op(uvm_field_op op) { }
  
  void do_vpi_put(uvm_vpi_iter iter) { }

  void do_vpi_get(uvm_vpi_iter iter) { }
  
  // @uvm-ieee 1800.2-2017 auto 5.3.12
  void  set_local(uvm_resource_base rsrc) {
    if (rsrc is null) {
      return;
    }
    else {
      uvm_field_op op = uvm_field_op.m_get_available_op();
      op.set(uvm_field_auto_enum.UVM_SET, null, rsrc);
      this.do_execute_op(op);
      op.m_recycle();
    }
  }


  //---------------------------------------------------------------------------
  //                 **** Internal Methods and Properties ***
  //                           Do not use directly
  //---------------------------------------------------------------------------

  final private void m_pack(ref uvm_packer packer) {
    if (packer is null)
      packer = uvm_packer.get_default();
    synchronized (packer) {
      if (packer.get_active_object_depth() == 0) 
	packer.flush();
      packer.pack_object(this);
    }
  }

  final private void m_unpack_pre(ref uvm_packer packer) {
    if (packer is null)
      packer = uvm_packer.get_default();
    if (packer.get_active_object_depth() == 0) 
      packer.flush(); 
  }

  private final int m_unpack_post(uvm_packer packer) {
    size_t size_before_unpack = packer.get_packed_size();
    packer.unpack_object(this);
    return cast (int) (size_before_unpack - packer.get_packed_size());
  }

  void m_unsupported_set_local(uvm_resource_base rsrc) { }
    
  // The print_matches bit causes an informative message to be printed
  // when a field is set using one of the set methods.

  @rand(false) @uvm_private_sync
  private string _m_leaf_name;

  // // uvm_sync_private _m_leaf_name string
  // final private string m_leaf_name() {synchronized (this) return this._m_leaf_name;}
  // final private void m_leaf_name(string val) {synchronized (this) this._m_leaf_name = val;}

  @rand(false) @uvm_immutable_sync
  private int _m_inst_id;

  // // uvm_sync_private _m_inst_id int
  // final private int m_inst_id() {synchronized (this) return this._m_inst_id;}
  // final private void m_inst_id(int val) {synchronized (this) this._m_inst_id = val;}

  protected uvm_report_object m_get_report_object() {
    return null;
  }

  
  static void _m_uvm_execute_copy(int I, T)(T t, T rhs, uvm_copier copier)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	static if (!(FLAGS & uvm_field_auto_enum.UVM_NOCOPY) &&
		   FLAGS & uvm_field_auto_enum.UVM_COPY) {
	  copier.uvm_copy_element(t.tupleof[I].stringof[2..$],
				  t.tupleof[I], rhs.tupleof[I], FLAGS);
	}
	_m_uvm_execute_copy!(I+1)(t, rhs, copier);
      }
    }
  
  static void _m_uvm_execute_compare(int I, T)(T t, T rhs,
					       uvm_comparer comparer)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	static if (!(FLAGS & uvm_field_auto_enum.UVM_NOCOMPARE) &&
		   FLAGS & uvm_field_auto_enum.UVM_COMPARE) {
	  comparer.uvm_compare_element(t.tupleof[I].stringof[2..$],
				  t.tupleof[I], rhs.tupleof[I], FLAGS);
	}
	_m_uvm_execute_compare!(I+1)(t, rhs, comparer);
      }
    }
  
  static void _m_uvm_execute_print(int I, T)(T t, uvm_printer printer)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	static if (!(FLAGS & uvm_field_auto_enum.UVM_NOPRINT) &&
		   FLAGS & uvm_field_auto_enum.UVM_PRINT) {
	  printer.uvm_print_element(t.tupleof[I].stringof[2..$],
				    t.tupleof[I], FLAGS);
	}
	_m_uvm_execute_print!(I+1)(t, printer);
      }
    }
  
  static void _m_uvm_execute_pack(int I, T)(T t, uvm_packer packer)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	static if (!(FLAGS & uvm_field_auto_enum.UVM_NOPACK) &&
		   FLAGS & uvm_field_auto_enum.UVM_PACK) {
	  packer.uvm_pack_element(t.tupleof[I].stringof[2..$],
				    t.tupleof[I], FLAGS);
	}
	_m_uvm_execute_pack!(I+1)(t, packer);
      }
    }
  
  static void _m_uvm_execute_unpack(int I, T)(T t, uvm_packer packer)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	static if (!(FLAGS & uvm_field_auto_enum.UVM_NOUNPACK) &&
		   FLAGS & uvm_field_auto_enum.UVM_UNPACK) {
	  packer.uvm_unpack_element(t.tupleof[I].stringof[2..$],
				    t.tupleof[I], FLAGS);
	}
	_m_uvm_execute_unpack!(I+1)(t, packer);
      }
    }
  
  static void _m_uvm_execute_record(int I, T)(T t, uvm_recorder recorder)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	static if (!(FLAGS & uvm_field_auto_enum.UVM_NORECORD) &&
		   FLAGS & uvm_field_auto_enum.UVM_RECORD) {
	  recorder.uvm_record_element(t.tupleof[I].stringof[2..$],
				      t.tupleof[I], FLAGS);
	}
	_m_uvm_execute_record!(I+1)(t, recorder);
      }
    }
  
  static void _m_uvm_execute_set(int I, T)(T t, uvm_resource_base rsrc)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	static if (!(FLAGS & uvm_field_auto_enum.UVM_NOSET) &&
		   FLAGS & uvm_field_auto_enum.UVM_SET) {
	  rsrc.uvm_set_element(t.tupleof[I].stringof[2..$],
			       t.tupleof[I], t, FLAGS);
	}
	_m_uvm_execute_set!(I+1)(t, rsrc);
      }
    }
  
  static void _m_uvm_object_automation(int I, T)(T          t,
						 T          rhs,
						 int        what, 
						 string     str)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      import uvm.base.uvm_misc: UVM_ELEMENT_TYPE;
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	alias EE = UVM_ELEMENT_TYPE!(typeof(t.tupleof[I]));
	static if (FLAGS != 0 &&
		   (isIntegral!EE || isBitVector!EE || isBoolean!EE ||
		    is (EE: uvm_object) || is (EE == string))) {
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
}

template uvm_field_auto_get_flags(alias t, size_t I)
{
  enum int uvm_field_auto_get_flags =
    uvm_field_auto_acc_flags!(__traits(getAttributes, t.tupleof[I]));
}

template uvm_field_auto_acc_flags(A...)
{
  import uvm.base.uvm_object_globals: uvm_recursion_policy_enum,
    uvm_field_auto_enum, uvm_radix_enum;
  static if (A.length is 0) {
    enum int uvm_field_auto_acc_flags = 0;
  }
  else static if (is (typeof(A[0]) == uvm_recursion_policy_enum) ||
		 is (typeof(A[0]) == uvm_field_auto_enum) ||
		 is (typeof(A[0]) == uvm_radix_enum)) {
      enum int uvm_field_auto_acc_flags = A[0] |
	uvm_field_auto_acc_flags!(A[1..$]);
    }
    else {
      enum int uvm_field_auto_acc_flags = uvm_field_auto_acc_flags!(A[1..$]);
    }
}
