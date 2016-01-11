//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2012-2014 Coverify Systems Technology
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
import esdl.base.core;
import uvm.base.uvm_misc;

import esdl.data.rand;
import esdl.data.obdd;
import uvm.base.uvm_recorder;


import uvm.base.uvm_factory;
import uvm.base.uvm_printer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_packer;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_report_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_root;
import uvm.meta.mcd;
import uvm.meta.misc;
import std.traits;
import std.string: format;

import std.random: uniform;

abstract class uvm_object: uvm_void
{
  import esdl.data.bvec;
  static class uvm_once
  {
    @uvm_private_sync
    private bool _use_uvm_seeding = true;
    // ** from uvm_object -- static variable in SV
    @uvm_immutable_sync
    private uvm_status_container _m_uvm_status_container;
    @uvm_protected_sync
    private int _m_inst_count;

    this() {
      synchronized(this) {
	_m_uvm_status_container = new uvm_status_container();
      }
    }
  }

  // Can not use "mixin uvm_once_sync" template due to forward reference error
  // Using string Mixin function
  // mixin uvm_once_sync;
  mixin(uvm_once_sync_string);
  mixin uvm_sync;

  mixin Randomization;
  // Function: new

  // Creates a new uvm_object with the given instance ~name~. If ~name~ is not
  // supplied, the object is unnamed.

  public this(string name="") {
    int inst_id;
    synchronized(once) {
      inst_id = _m_inst_count++;
    }
    synchronized(this) {
      _m_inst_id = inst_id;
      _m_leaf_name = name;
      auto proc = Procedure.self;
      if(proc !is null) {
	auto seed = uniform!int(proc.getRandGen());
	debug(SEED) {
	  import std.stdio;
	  writeln("Setting seed: ", seed, " for instance: ", get_full_name);
	}
	this.reseed(seed);
      }
    }
  }


  // Group: Seeding

  // Variable: use_uvm_seeding
  //
  // This bit enables or disables the UVM seeding mechanism. It globally affects
  // the operation of the reseed method.
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

  final public void reseed (int seed) {
    this.srandom(seed);
  }

  final public void reseed () {
    synchronized(this) {
      if(_use_uvm_seeding) {
	this.srandom(uvm_create_random_seed(get_type_name(),
					    get_full_name()));
      }
    }
  }


  // // Group: Identification

  // // Function: set_name
  // //
  // // Sets the instance name of this object, overwriting any previously
  // // given name.

  public void set_name (string name) {
    synchronized(this) {
      _m_leaf_name = name;
    }
  }


  // Function: get_name
  //
  // Returns the name of the object, as provided by the ~name~ argument in the
  // <new> constructor or <set_name> method.

  public string get_name () {
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

  public string get_full_name () {
    return get_name();
  }



  // Function: get_inst_id
  //
  // Returns the object's unique, numeric instance identifier.

  public int get_inst_id () {
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

  static public int get_inst_count() {
    synchronized(once) {
      return _m_inst_count;
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
  // null. To enable use of this method, a user's subtype must implement a
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

  static public uvm_object_wrapper get_type () {
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
  // by <get_type_name> is not registered with the factory, then a null
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

  public uvm_object_wrapper get_object_type () {
    if(get_type_name() == "<unknown>") return null;
    return uvm_factory.get().find_by_name(get_type_name());
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
  public string get_type_name () {
    return "<unknown>";
  }


  // Group: Creation

  // Function: create
  //
  // The create method allocates a new object of the same type as this object
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

  public uvm_object create (string name = "") {
    return null;
  }

  // Function: clone
  //
  // The clone method creates and returns an exact copy of this object.
  //
  // The default implementation calls <create> followed by <copy>. As clone is
  // virtual, derived classes may override this implementation if desired.

  public uvm_object clone () {
    uvm_object tmp = this.create(get_name());
    if(tmp is null) {
      uvm_report_warning("CRFLD", format("The create method failed for %s,  "
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
  // The print method deep-prints this object's properties in a format and
  // manner governed by the given ~printer~ argument; if the ~printer~ argument
  // is not provided, the global <uvm_default_printer> is used. See
  // <uvm_printer> for more information on printer output formatting. See also
  // <uvm_line_printer>, <uvm_tree_printer>, and <uvm_table_printer> for details
  // on the pre-defined printer "policies," or formatters, provided by the UVM.
  //
  // The ~print~ method is not virtual and must not be overloaded. To include
  // custom information in the ~print~ and ~sprint~ operations, derived classes
  // must override the <do_print> method and use the provided printer policy
  // class to format the output.

  final public void print (uvm_printer printer = null) {
    if (printer is null) {
      printer = uvm_default_printer;
    }
    if (printer is null) {
      uvm_error("NULLPRINTER","uvm_default_printer is null");
    }
    printer.knobs.mcd.vfdisplay(sprint(printer));
  }


  // Function: sprint
  //
  // The ~sprint~ method works just like the <print> method, except the output
  // is returned in a string rather than displayed.
  //
  // The ~sprint~ method is not virtual and must not be overloaded. To include
  // additional fields in the ~print~ and ~sprint~ operation, derived classes
  // must override the <do_print> method and use the provided printer policy
  // class to format the output. The printer policy will manage all string
  // concatenations and provide the string to ~sprint~ to return to the caller.

  final public string sprint (uvm_printer printer=null) {

    if(printer is null) printer = uvm_default_printer;

    // not at top-level, must be recursing into sub-object
    if(! printer.istop()) {
      m_uvm_status_container.printer = printer;
      // m_uvm_field_automation(null, UVM_PRINT, "");
      uvm_field_auto_sprint();
      do_print(printer);
      return "";
    }

    printer.print_object(get_name(), this);
    // backward compat with sprint knob: if used,
    //    print that, do not call emit()
    if (printer.m_string != "") return printer.m_string;

    return printer.emit();
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
  //|     printer.print_int("f1", f1, $bits(f1), DEC);
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

  public void do_print (uvm_printer printer) {
    return;
  }


  // Function: convert2string
  //
  // This virtual function is a user-definable hook, called directly by the
  // user, that allows users to provide object information in the form of
  // a string. Unlike <sprint>, there is no requirement to use an <uvm_printer>
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
  // public T opCast(T)() if (is(T == string))
  //   {
  //     return "";
  //   }

  public T to(T)() if (is(T == string)) {
    return "";
  }

  public string convert2string() {
    return this.to!string();
  }

  // Group: Recording

  // Function: record
  //
  // The record method deep-records this object's properties according to an
  // optional ~recorder~ policy. The method is not virtual and must not be
  // overloaded. To include additional fields in the record operation, derived
  // classes should override the <do_record> method.
  //
  // The optional ~recorder~ argument specifies the recording policy, which
  // governs how recording takes place. If a recorder policy is not provided
  // explicitly, then the global <uvm_default_recorder> policy is used. See
  // uvm_recorder for information.
  //
  // A simulator's recording mechanism is vendor-specific. By providing access
  // via a common interface, the uvm_recorder policy provides vendor-independent
  // access to a simulator's recording capabilities.

  final public void record (uvm_recorder recorder = null) {

    if(recorder is null) recorder = uvm_default_recorder;

    if(!recorder.tr_handle) return;
    m_uvm_status_container.recorder = recorder;

    recorder.inc_recording_depth();
    m_uvm_field_automation(null, UVM_RECORD, "");
    // uvm_field_auto_record();
    do_record(recorder);

    recorder.dec_recording_depth();

    if(recorder.recording_depth is 0) {
      recorder.tr_handle = 0;
    }
  }


  // Function: do_record
  //
  // The do_record method is the user-definable hook called by the <record>
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
  //|     recorder.record_field_int("f1", f1, $bits(f1), DEC);
  //|     recorder.record_object("data", data);
  //|   endfunction

  public void do_record (uvm_recorder recorder) {
    return;
  }


  // Group: Copying

  // Function: copy
  //
  // The copy makes this object a copy of the specified object.
  //
  // The copy method is not virtual and should not be overloaded in derived
  // classes. To copy the fields of a derived class, that class should override
  // the <do_copy> method.

  void uvm_field_auto_setint(string field_name, uvm_bitstream_t value) {
    uvm_report_warning("NOUTILS", "default uvm_field_auto_setint --"
		       "no uvm_object_utils", UVM_NONE);
  }
  
  void uvm_field_auto_setint(string field_name, ulong value) {
    uvm_report_warning("NOUTILS", "default uvm_field_auto_setint --"
		       "no uvm_object_utils", UVM_NONE);
  }
  
  void uvm_field_auto_copy(uvm_object rhs) {
    uvm_report_warning("NOUTILS", "default uvm_field_auto_copy --"
		       "no uvm_object_utils", UVM_NONE);
  }
  
  void uvm_field_auto_sprint() {
    uvm_report_warning("NOUTILS", "default uvm_field_auto_sprint --"
		       "no uvm_object_utils", UVM_NONE);
  }
  
  void uvm_field_auto_pack() {
    uvm_report_warning("NOUTILS", "default uvm_field_auto_pack --"
		       "no uvm_object_utils", UVM_NONE);
  }
  
  void uvm_field_auto_unpack() {
    uvm_report_warning("NOUTILS", "default uvm_field_auto_unpack --"
		       "no uvm_object_utils", UVM_NONE);
  }
  
  void uvm_field_auto_compare(uvm_object rhs) {
    uvm_report_warning("NOUTILS", "default uvm_field_auto_compare --"
		       "no uvm_object_utils", UVM_NONE);
  }
  
  final public void copy(uvm_object rhs) {
    static uvm_copy_map copy_map; //  = null;
    // if(copy_map is null) {
    //   copy_map = new uvm_copy_map();
    // }
    
    // Thread static
    static int depth;
    if(rhs !is null &&
       // copy_map.get(rhs) !is null) {
       copy_map.get(rhs) is true) {
      return;
    }

    if(rhs is null) {
      uvm_report_warning("NULLCP", "A null object was supplied to copy;"
			 " copy is ignored", UVM_NONE);
      return;
    }

    // copy_map.set(rhs, this);
    copy_map.set(rhs);
    ++depth;

    // SV version -- not required for Vlang
    // m_uvm_field_automation(rhs, UVM_COPY, "");

    // overridden by mixin(uvm_object_utils);
    uvm_field_auto_copy(rhs);
    do_copy(rhs);

    --depth;
    if(depth is 0) {
      // copy_map = null;
      copy_map.clear();
    }
  }


  // Function: do_copy
  //
  // The do_copy method is the user-definable hook called by the copy method.
  // A derived class should override this method to include its fields in a copy
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

  public void do_copy (uvm_object rhs) {
    return;
  }


  // Group: Comparing

  // Function: compare
  //
  // Deep compares members of this data object with those of the object provided
  // in the ~rhs~ (right-hand side) argument, returning 1 on a match, 0 othewise.
  //
  // The compare method is not virtual and should not be overloaded in derived
  // classes. To compare the fields of a derived class, that class should
  // override the <do_compare> method.
  //
  // The optional ~comparer~ argument specifies the comparison policy. It allows
  // you to control some aspects of the comparison operation. It also stores the
  // results of the comparison, such as field-by-field miscompare information
  // and the total number of miscompares. If a compare policy is not provided,
  // then the global ~uvm_default_comparer~ policy is used. See <uvm_comparer>
  // for more information.

  final public bool compare (uvm_object rhs, uvm_comparer comparer = null) {
    if(comparer !is null) {
      m_uvm_status_container.comparer = comparer;
    }
    else {
      m_uvm_status_container.comparer = uvm_default_comparer;
    }
    comparer = m_uvm_status_container.comparer;

    if(! m_uvm_status_container.scope_stack.depth()) {
      comparer.compare_map.clear();
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

    if(! done && (comparer.compare_map.get(rhs) !is null)) {
      if(comparer.compare_map.get(rhs) !is this) {
	comparer.print_msg_object(this, comparer.compare_map.get(rhs));
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
      comparer.compare_map.set(rhs, this);
      // SV version -- not required for Vlang
      // m_uvm_field_automation(rhs, UVM_COMPARE, "");

      // overridden by mixin(uvm_object_utils);
      uvm_field_auto_compare(rhs);
      dc = do_compare(rhs, comparer);
    }

    if(m_uvm_status_container.scope_stack.depth() is 1)  {
      m_uvm_status_container.scope_stack.up();
    }

    if(rhs !is null) {
      comparer.print_rollup(this, rhs);
    }
    return (comparer.result is 0 && dc is true);
  }


  // Function: do_compare
  //
  // The do_compare method is the user-definable hook called by the <compare>
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

  public bool do_compare (uvm_object rhs, uvm_comparer comparer) {
    return true;
  }

  // Group: Packing

  // Function: pack

  final public size_t pack (ref Bit!1[] bitstream, uvm_packer packer=null) {
    m_pack(packer);
    packer.get_bits(bitstream);
    return packer.get_packed_size();
  }

  final public size_t pack (ref bool[] bitstream, uvm_packer packer=null) {
    m_pack(packer);
    packer.get_bits(bitstream);
    return packer.get_packed_size();
  }

  // Function: pack_bytes

  final public size_t pack_bytes (ref ubyte[] bytestream,
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

  final public size_t pack_ints (ref uint[] intstream,
				 uvm_packer packer=null) {
    m_pack(packer);
    packer.get_ints(intstream);
    return packer.get_packed_size();
  }


  // Function: do_pack
  //
  // The do_pack method is the user-definable hook called by the <pack> methods.
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
  //  - For objects, pack 4 bits immediately before packing the object. For null
  //    objects, pack 4'b0000. For non-null objects, pack 4'b0001.
  //
  // When the `uvm_field_* macros are used,
  // <Utility and Field Macros for Components and Objects>,
  // the above meta information is included provided the <uvm_packer::use_metadata>
  // variable is set for the packer.
  //
  // Packing order does not need to match declaration order. However, unpacking
  // order must match packing order.

  public void do_pack (uvm_packer packer) {
    return;
  }


  // Group: Unpacking

  // Function: unpack

  final public size_t unpack (ref Bit!1[] bitstream,
			      uvm_packer packer = null) {

    m_unpack_pre(packer);
    packer.put_bits(bitstream);
    m_unpack_post(packer);
    packer.set_packed_size();
    return packer.get_packed_size();
  }

  final public size_t unpack (ref bool[] bitstream,
			      uvm_packer packer = null) {
    m_unpack_pre(packer);
    packer.put_bits(bitstream);
    m_unpack_post(packer);
    packer.set_packed_size();
    return packer.get_packed_size();
  }

  // Function: unpack_bytes

  final public size_t unpack_bytes (ref ubyte[] bytestream,
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

  final public size_t unpack_ints (ref uint[] intstream,
				   uvm_packer packer = null) {
    m_unpack_pre(packer);
    packer.put_ints(intstream);
    m_unpack_post(packer);
    packer.set_packed_size();
    return packer.get_packed_size();
  }


  // Function: do_unpack
  //
  // The do_unpack method is the user-definable hook called by the <unpack>
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
  // - For string data types, unpack into the new string until a null byte is
  //   encountered.
  //
  // - For objects, unpack 4 bits into a byte or int variable. If the value
  //   is 0, the target object should be set to null and unpacking continues to
  //   the next property, if any. If the least significant bit is 1, then the
  //   target object should be allocated and its properties unpacked.

  public void do_unpack (uvm_packer packer) {
    return;
  }


  // Group: Configuration

  // Function: set_int_local

  public void set_int_local (string      field_name,
			     uvm_bitstream_t value,
			     bool         recurse = true) {
    // presently D has only a funky way to clear up associative arrays
    m_uvm_status_container.remove_all_cycles();
    m_uvm_status_container.reset_cycle_scopes();

    m_uvm_status_container.status = false;
    m_uvm_status_container.bitstream = value;

    // Use Vlang auto instead
    // m_uvm_field_automation(null, UVM_SETINT, field_name);

    uvm_field_auto_setint(field_name, value);
    

    if(m_uvm_status_container.warning &&
       ! m_uvm_status_container.status) {
      uvm_report_error("NOMTC", format("did not find a match for field %s",
				       field_name), UVM_NONE);
    }
    m_uvm_status_container.remove_all_cycles();
  }

  // Function: set_int_local

  public void set_int_local (string      field_name,
			     ulong       value,
			     bool        recurse = true) {
    // presently D has only a funky way to clear up associative arrays
    m_uvm_status_container.remove_all_cycles();
    m_uvm_status_container.reset_cycle_scopes();

    m_uvm_status_container.status = false;
    m_uvm_status_container.bitstream = cast(uvm_bitstream_t) value;

    m_uvm_field_automation(null, UVM_SETINT, field_name);

    if(m_uvm_status_container.warning &&
       ! m_uvm_status_container.status) {
      uvm_report_error("NOMTC", format("did not find a match for field %s",
				       field_name), UVM_NONE);
    }
    m_uvm_status_container.remove_all_cycles();
  }

  // Function: set_string_local

  public void set_string_local (string field_name,
				string value,
				bool   recurse = true) {
    m_uvm_status_container.remove_all_cycles();
    m_uvm_status_container.reset_cycle_scopes();

    m_uvm_status_container.status = false;
    m_uvm_status_container.stringv = value;

    m_uvm_field_automation(null, UVM_SETSTR, field_name);

    if(m_uvm_status_container.warning &&
       ! m_uvm_status_container.status) {
      uvm_report_error("NOMTC",
		       format("did not find a match for field %s (@%0d)",
			      field_name, this.get_inst_id()), UVM_NONE);
    }
    m_uvm_status_container.remove_all_cycles();
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

  public void set_object_local (string      field_name,
				uvm_object  value,
				bool        clone = true,
				bool        recurse = true) {
    m_uvm_status_container.remove_all_cycles();
    m_uvm_status_container.reset_cycle_scopes();

    if(clone && (value !is null)) {
      uvm_object cc = value.clone();
      if(cc !is null) cc.set_name(field_name);
      value = cc;
    }

    m_uvm_status_container.status = false;
    m_uvm_status_container.object = value;
    m_uvm_status_container.clone = clone;

    m_uvm_field_automation(null, UVM_SETOBJ, field_name);

    if(m_uvm_status_container.warning &&
       ! m_uvm_status_container.status) {
      uvm_report_error("NOMTC",
		       format("did not find a match for field %s",
			      field_name), UVM_NONE);
    }
    m_uvm_status_container.remove_all_cycles();

  }

  //---------------------------------------------------------------------------
  //                 **** Internal Methods and Properties ***
  //                           Do not use directly
  //---------------------------------------------------------------------------

  final private void m_pack (ref uvm_packer packer) {
    if(packer !is null) {
      m_uvm_status_container.packer = packer;
    }
    else {
      m_uvm_status_container.packer = uvm_default_packer;
    }
    packer = m_uvm_status_container.packer;

    packer.reset();
    packer.scope_stack.down(get_name());

    m_uvm_field_automation(null, UVM_PACK, "");
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

    m_uvm_field_automation(null, UVM_UNPACK, "");

    do_unpack(packer);

    //Scope back up before leaving
    packer.scope_stack.up();

    if(packer.get_packed_size() !is provided_size) {
      uvm_report_warning("BDUNPK",
			 format("Unpack operation unsuccessful: unpacked "
				"%0d bits from a total of %0d bits",
				packer.get_packed_size(), provided_size),
			 UVM_NONE);
    }
  }

  // The print_matches bit causes an informative message to be printed
  // when a field is set using one of the set methods.

  @uvm_private_sync private string _m_leaf_name;

  @uvm_private_sync private int _m_inst_id;

  // static protected int m_inst_count;
  // static /*protected*/ uvm_status_container m_uvm_status_container = new;

  public void m_uvm_field_automation (uvm_object tmp_data__,
				      int        what__,
				      string     str__) {
    return;
  }

  protected uvm_report_object m_get_report_object() {
    return null;
  }

} // endclass



// private uvm_copy_map uvm_global_copy_map() {
//   // This static variable is required to be thread specific
//   // No need to share this variable
//   static uvm_copy_map copy_map = null;

//   if (copy_map is null) {
//     copy_map = new uvm_copy_map();
//   }

//   return copy_map;
// }
