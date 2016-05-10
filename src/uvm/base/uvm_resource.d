//----------------------------------------------------------------------
//   Copyright 2011      Cypress Semiconductor
//   Copyright 2010      Mentor Graphics Corporation
//   Copyright 2011      Cadence Design Systems, Inc.
//   Copyright 2014-2016 Coverify Systems Technology
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

//----------------------------------------------------------------------
// Title: Resources
//
// Topic: Intro
//
// A resource is a parameterized container that holds arbitrary data.
// Resources can be used to configure components, supply data to
// sequences, or enable sharing of information across disparate parts of
// a testbench.  They are stored using scoping information so their
// visibility can be constrained to certain parts of the testbench.
// Resource containers can hold any type of data, constrained only by
// the data types available in SystemVerilog.  Resources can contain
// scalar objects, class handles, queues, lists, or even virtual
// interfaces.
//
// Resources are stored in a resource database so that each resource can
// be retrieved by name or by type. The database has both a name table
// and a type table and each resource is entered into both. The database
// is globally accessible.
//
// Each resource has a set of scopes over which it is visible.  The set
// of scopes is represented as a regular expression.  When a resource is
// looked up the scope of the entity doing the looking up is supplied to
// the lookup function.  This is called the ~current scope~.  If the
// current scope is in the set of scopes over which a resource is
// visible then the resource can be retuned in the lookup.
//
// Resources can be looked up by name or by type. To support type lookup
// each resource has a static type handle that uniquely identifies the
// type of each specialized resource container.
//
// Multiple resources that have the same name are stored in a queue.
// Each resource is pushed into a queue with the first one at the front
// of the queue and each subsequent one behind it.  The same happens for
// multiple resources that have the same type.  The resource queues are
// searched front to back, so those placed earlier in the queue have
// precedence over those placed later.
//
// The precedence of resources with the same name or same type can be
// altered.  One way is to set the ~precedence~ member of the resource
// container to any arbitrary value.  The search algorithm will return
// the resource with the highest precedence.  In the case where there
// are multiple resources that match the search criteria and have the
// same (highest) precedence, the earliest one located in the queue will
// be one returned.  Another way to change the precedence is to use the
// set_priority function to move a resource to either the front or back
// of the queue.
//
// The classes defined here form the low level layer of the resource
// database.  The classes include the resource container and the database
// that holds the containers.  The following set of classes are defined
// here:
//
// <uvm_resource_types>: A class without methods or members, only
// typedefs and enums. These types and enums are used throughout the
// resources facility.  Putting the types in a class keeps them confined
// to a specific name space.
//
// <uvm_resource_options>: policy class for setting options, such
// as auditing, which effect resources.
//
// <uvm_resource_base>: the base (untyped) resource class living in the
// resource database.  This class includes the interface for setting a
// resource as read-only, notification, scope management, altering
// search priority, and managing auditing.
//
// <uvm_resource#(T)>: parameterized resource container.  This class
// includes the interfaces for reading and writing each resource.
// Because the class is parameterized, all the access functions are type
// safe.
//
// <uvm_resource_pool>: the resource database. This is a singleton
// class object.
//----------------------------------------------------------------------

// typedef class uvm_resource_base; // forward reference


//----------------------------------------------------------------------
// Class: uvm_resource_base
//
// Non-parameterized base class for resources.  Supports interfaces for
// scope matching, and virtual functions for printing the resource and
// for printing the accessor list
//----------------------------------------------------------------------

module uvm.base.uvm_resource;

import uvm.base.uvm_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_root;
import uvm.base.uvm_printer;
import uvm.base.uvm_spell_chkr;
import uvm.meta.meta;

import esdl.base.core: SimTime, getRootEntity, Process;

import std.string;
import std.random: Random;
import std.algorithm: sort;
import std.conv: to;

version(UVM_NO_DEPRECATED) { }
 else {
   version = UVM_INCLUDE_DEPRECATED;
 }

//----------------------------------------------------------------------
// Class: uvm_resource_types
//
// Provides typedefs and enums used throughout the resources facility.
// This class has no members or methods, only typedefs.  It's used in
// lieu of package-scope types.  When needed, other classes can use
// these types by prefixing their usage with uvm_resource_types..  E.g.
//
//|  uvm_resource_types.rsrc_q_t queue;
//
//----------------------------------------------------------------------
class uvm_resource_types
{
  import uvm.meta.misc;
  import uvm.base.uvm_queue: uvm_queue;
  import esdl.data.time;
  // types uses for setting overrides
  // typedef bit[1:0] override_t;
  enum override_e: byte
    {   NONE_OVERRIDE = 0b00,
	TYPE_OVERRIDE = 0b01,
	NAME_OVERRIDE = 0b10,
	BOTH_OVERRIDE = 0b11
	}
  mixin(declareEnums!override_e());

  // general purpose queue of resourcex
  alias rsrc_q_t = uvm_queue!uvm_resource_base;

  // enum for setting resource search priority
  enum priority_e: bool
    {   PRI_HIGH,
	PRI_LOW
	}
  mixin(declareEnums!priority_e());

  // access record for resources.  A set of these is stored for each
  // resource by accessing object.  It's updated for each read/write.
  struct access_t
  {
    SimTime read_time = 0;
    SimTime write_time = 0;
    uint read_count = 0;
    uint write_count = 0;
  }
}

//----------------------------------------------------------------------
// Class: uvm_resource_options
//
// Provides a namespace for managing options for the
// resources facility.  The only thing allowed in this class is static
// local data members and static functions for manipulating and
// retrieving the value of the data members.  The static local data
// members represent options and settings that control the behavior of
// the resources facility.

// Options include:
//
//  * auditing:  on/off
//
//    The default for auditing is on.  You may wish to turn it off to
//    for performance reasons.  With auditing off memory is not
//    consumed for storage of auditing information and time is not
//    spent collecting and storing auditing information.  Of course,
//    during the period when auditing is off no audit trail information
//    is available
//
//----------------------------------------------------------------------
class uvm_resource_options
{
  // static private bool auditing = true;
  static class uvm_once
  {
    @uvm_none_sync
    private bool _auditing = true;
  };

  mixin(uvm_once_sync_string);

  // Function: turn_on_auditing
  //
  // Turn auditing on for the resource database. This causes all
  // reads and writes to the database to store information about
  // the accesses. Auditing is turned on by default.

  static void turn_on_auditing() {
    synchronized(once) {
      once._auditing = true;
    }
  }

  // Function: turn_off_auditing
  //
  // Turn auditing off for the resource database. If auditing is turned off,
  // it is not possible to get extra information about resource
  // database accesses.

  static void turn_off_auditing() {
    synchronized(once) {
      once._auditing = false;
    }
  }

  // Function: is_auditing
  //
  // Returns 1 if the auditing facility is on and 0 if it is off.

  static bool is_auditing() {
    synchronized(once) {
      return once._auditing;
    }
  }
}

//----------------------------------------------------------------------
// Class: uvm_resource_base
//
// Non-parameterized base class for resources.  Supports interfaces for
// scope matching, and virtual functions for printing the resource and
// for printing the accessor list
//----------------------------------------------------------------------

abstract class uvm_resource_base: uvm_object
{
  static class uvm_once
  {
    // variable: default_precedence
    //
    // The default precedence for an resource that has been created.
    // When two resources have the same precedence, the first resource
    // found has precedence.
    //

    @uvm_public_sync
    private uint _default_precedence = 1000;
  };

  mixin(uvm_once_sync_string);
  mixin(uvm_sync_string);

  protected string _rscope;
  @uvm_immutable_sync
  protected WithEvent!bool _modified;
  protected bool _read_only;

  uvm_resource_types.access_t[string] _access;

  // variable: precedence
  //
  // This variable is used to associate a precedence that a resource
  // has with respect to other resources which match the same scope
  // and name. Resources are set to the <default_precedence> initially,
  // and may be set to a higher or lower precedence as desired.

  @uvm_public_sync
  private uint _precedence;


  // Function: new
  //
  // constructor for uvm_resource_base.  The constructor takes two
  // arguments, the name of the resource and a regular expression which
  // represents the set of scopes over which this resource is visible.

  this(string name = null, string s = "*") {
    synchronized(this) {
      super(name);
      _modified = new WithEvent!bool();
      set_scope(s);
      modified = false;
      _read_only = false;
      _precedence = default_precedence;
    }
  }

  // Function: get_type_handle
  //
  // Pure virtual function that returns the type handle of the resource
  // container.

  abstract TypeInfo get_type_handle();


  //---------------------------
  // Group: Read-only Interface
  //---------------------------

  // Function: set_read_only
  //
  // Establishes this resource as a read-only resource.  An attempt
  // to call <uvm_resource#(T).write> on the resource will cause an error.

  void set_read_only() {
    synchronized(this) {
      _read_only = true;
    }
  }

  // function set_read_write
  //
  // Returns the resource to normal read-write capability.

  // Implementation question: Not sure if this function is necessary.
  // Once a resource is set to read_only no one should be able to change
  // that.  If anyone can flip the read_only bit then the resource is not
  // truly read_only.

  void set_read_write() {
    synchronized(this) {
      _read_only = false;
    }
  }

  // Function: is_read_only
  //
  // Retuns one if this resource has been set to read-only, zero
  // otherwise
  bool is_read_only() {
    synchronized(this) {
      return _read_only;
    }
  }


  //--------------------
  // Group: Notification
  //--------------------

  // Task: wait_modified
  //
  // This task blocks until the resource has been modified -- that is, a
  // <uvm_resource#(T).write> operation has been performed.  When a
  // <uvm_resource#(T).write> is performed the modified bit is set which
  // releases the block.  Wait_modified() then clears the modified bit so
  // it can be called repeatedly.

  // task
  void wait_modified() {
    while(modified is false) {
      modified.wait();
    }
    modified = false;
  }

  //-----------------------
  // Group: Scope Interface
  //-----------------------
  //
  // Each resource has a name, a value and a set of scopes over which it
  // is visible. A scope is a hierarchical entity or a context.  A scope
  // name is a multi-element string that identifies a scope.  Each
  // element refers to a scope context and the elements are separated by
  // dots (.).
  //
  //|    top.env.agent.monitor
  //
  // Consider the example above of a scope name.  It consists of four
  // elements: "top", "env", "agent", and "monitor".  The elements are
  // strung together with a dot separating each element.  ~top.env.agent~
  // is the parent of ~top.env.agent.monitor~, ~top.env~ is the parent of
  // ~top.env.agent~, and so on.  A set of scopes can be represented by a
  // set of scope name strings.  A very straightforward way to represent
  // a set of strings is to use regular expressions.  A regular
  // expression is a special string that contains placeholders which can
  // be substituted in various ways to generate or recognize a
  // particular set of strings.  Here are a few simple examples:
  //
  //|     top\..*			all of the scopes whose top-level component
  //|                            is top
  //|    top\.env\..*\.monitor	all of the scopes in env that end in monitor;
  //|                            i.e. all the monitors two levels down from env
  //|    .*\.monitor		    all of the scopes that end in monitor; i.e.
  //|                            all the monitors (assuming a naming convention
  //|                            was used where all monitors are named "monitor")
  //|    top\.u[1-5]\.*		all of the scopes rooted and named u1, u2, u3,
  //                             u4, or u5, and any of their subscopes.
  //
  // The examples above use POSIX regular expression notation.  This is
  // a very general and expressive notation.  It is not always the case
  // that so much expressiveness is required.  Sometimes an expression
  // syntax that is easy to read and easy to write is useful, even if
  // the syntax is not as expressive as the full power of POSIX regular
  // expressions.  A popular substitute for regular expressions is
  // globs.  A glob is a simplified regular expression. It only has
  // three metacharacters -- *, +, and ?.  Character ranges are not
  // allowed and dots are not a metacharacter in globs as they are in
  // regular expressions.  The following table shows glob
  // metacharacters.
  //
  //|      char	meaning			regular expression
  //|                                    equivalent
  //|      *	    0 or more characters	.*
  //|      +	    1 or more characters	.+
  //|      ?	    exactly one character	.
  //
  // Of the examples above, the first three can easily be translated
  // into globs.  The last one cannot.  It relies on notation that is
  // not available in glob syntax.
  //
  //|    regular expression	    glob equivalent
  //|    ---------------------      ------------------
  //|    top\..*		    top.*
  //|    top\.env\..*\.monitor	    top.env.*.monitor
  //|    .*\.monitor		    *.monitor
  //
  // The resource facility supports both regular expression and glob
  // syntax.  Regular expressions are identified as such when they
  // surrounded by '/' characters. For example, ~/^top\.*/~ is
  // interpreted as the regular expression ~^top\.*~, where the
  // surrounding '/' characters have been removed. All other expressions
  // are treated as glob expressions. They are converted from glob
  // notation to regular expression notation internally.  Regular expression
  // compilation and matching as well as glob-to-regular expression
  // conversion are handled by two DPI functions:
  //
  //|    function int uvm_re_match(string re, string str);
  //|    function string uvm_glob_to_re(string glob);
  //
  // uvm_re_match both compiles and matches the regular expression.
  // All of the matching is done using regular expressions, so globs are
  // converted to regular expressions and then processed.


  // Function: set_scope
  //
  // Set the value of the regular expression that identifies the set of
  // scopes over which this resource is visible.  If the supplied
  // argument is a glob it will be converted to a regular expression
  // before it is stored.
  //

  void set_scope(string s) {
    synchronized(this) {
      _rscope = uvm_glob_to_re(s);
    }
  }

  // Function: get_scope
  //
  // Retrieve the regular expression string that identifies the set of
  // scopes over which this resource is visible.
  //
  string get_scope() {
    synchronized(this) {
      return _rscope;
    }
  }

  // Function: match_scope
  //
  // Using the regular expression facility, determine if this resource
  // is visible in a scope.  Return one if it is, zero otherwise.
  //
  bool match_scope(string s) {
    synchronized(this) {
      int err = uvm_re_match(_rscope, s);
      return (err == 0);
    }
  }

  //----------------
  // Group: Priority
  //----------------
  //
  // Functions for manipulating the search priority of resources.  The
  // function definitions here are pure virtual and are implemented in
  // derived classes.  The definitons serve as a priority management
  // interface.

  // Function: set priority
  //
  // Change the search priority of the resource based on the value of
  // the priority enum argument.
  //
  abstract void set_priority (uvm_resource_types.priority_e pri);

  //-------------------------
  // Group: Utility Functions
  //-------------------------

  // function convert2string
  //
  // Create a string representation of the resource value.  By default
  // we don't know how to do this so we just return a "?".  Resource
  // specializations are expected to override this function to produce a
  // proper string representation of the resource value.

  string to(T)() if(is(T == string)) {
    return "?";
  }

  override string convert2string() {
    import std.conv: to;
    return to!string(this);
  }


  // Function: do_print
  //
  // Implementation of do_print which is called by print().

  override void do_print (uvm_printer printer) {
    printer.print("", format("%s [%s] : %s", get_name(),
			     get_scope(), convert2string()));
  }

  //-------------------
  // Group: Audit Trail
  //-------------------
  //
  // To find out what is happening as the simulation proceeds, an audit
  // trail of each read and write is kept. The <uvm_resource#(T)::read> and
  // <uvm_resource#(T)::write> methods each take an accessor argument.  This is a
  // handle to the object that performed that resource access.
  //
  //|    function T read(uvm_object accessor = null);
  //|    function void write(T t, uvm_object accessor = null);
  //
  // The accessor can by anything as long as it is derived from
  // uvm_object.  The accessor object can be a component or a sequence
  // or whatever object from which a read or write was invoked.
  // Typically the ~this~ handle is used as the
  // accessor.  For example:
  //
  //|    uvm_resource#(int) rint;
  //|    int i;
  //|    ...
  //|    rint.write(7, this);
  //|    i = rint.read(this);
  //
  // The accessor's ~get_full_name()~ is stored as part of the audit trail.
  // This way you can find out what object performed each resource access.
  // Each audit record also includes the time of the access (simulation time)
  // and the particular operation performed (read or write).
  //
  // Auditing is controlled through the <uvm_resource_options> class.

  // function: record_read_access

  final void record_read_access(uvm_object accessor = null) {
    synchronized(this) {
      string str;
      uvm_resource_types.access_t access_record;

      // If an accessor object is supplied then get the accessor record.
      // Otherwise create a new access record.  In either case populate
      // the access record with information about this access.  Check
      // first to make sure that auditing is turned on.

      if(!uvm_resource_options.is_auditing()) {
	return;
      }

      // If an accessor is supplied, then use its name
      // as the database entry for the accessor record.
      // Otherwise, use "<empty>" as the database entry.
      if(accessor !is null) {
	str = accessor.get_full_name();
      }
      else {
	str = "<empty>";
      }

      // Create a new accessor record if one does not exist
      if(str in _access) {
	access_record = _access[str];
      }
      else {
	// init_access_record(access_record);
	access_record = uvm_resource_types.access_t.init;
      }

      // Update the accessor record
      access_record.read_count++;
      access_record.read_time = getRootEntity().getSimTime();
      _access[str] = access_record;
    }
  }

  // function: record_write_access

  final void record_write_access(uvm_object accessor = null) {
    synchronized(this) {
      // string str;

      // If an accessor object is supplied then get the accessor record.
      // Otherwise create a new access record.  In either case populate
      // the access record with information about this access.  Check
      // first that auditing is turned on

      if(uvm_resource_options.is_auditing()) {
	if(accessor !is null) {
	  uvm_resource_types.access_t access_record;
	  string str = accessor.get_full_name();
	  if(str in _access) {
	    access_record = _access[str];
	  }
	  else {
	    // init_access_record(access_record);
	    access_record = uvm_resource_types.access_t.init;
	  }
	  access_record.write_count++;
	  access_record.write_time = getRootEntity().getSimTime();
	  _access[str] = access_record;
	}
      }
    }
  }

  // Function: print_accessors
  //
  // Dump the access records for this resource
  //
  final void print_accessors() {
    synchronized(this) {
      string qs;

      import uvm.meta.mcd;
      // uvm_component comp;
      uvm_resource_types.access_t access_record;

      if(_access.length is 0) {
	return;
      }

      foreach (str, access_record; _access) {
	qs ~= format("%s reads: %0d @ %0s  writes: %0d @ %0s\n", str,
		     access_record.read_count,
		     access_record.read_time,
		     access_record.write_count,
		     access_record.write_time);
      }
      uvm_root_info("UVM/RESOURCE/ACCESSOR", qs, UVM_NONE);
    }
  }


  // Function: init_access_record
  //
  // Initialize a new access record
  //
  // this should not be required since in D we can get init value for structs
  // All calls of this function have been replaced with access_t.init assignments
  static private void init_access_record (ref uvm_resource_types.access_t
					  access_record) {
    access_record.read_time = 0;
    access_record.write_time = 0;
    access_record.read_count = 0;
    access_record.write_count = 0;
  }

}


//----------------------------------------------------------------------
// Class - get_t
//
// Instances of get_t are stored in the history list as a record of each
// get.  Failed gets are indicated with rsrc set to ~null~.  This is part
// of the audit trail facility for resources.
//----------------------------------------------------------------------
struct get_t {
  string name;
  string rscope;
  uvm_resource_base rsrc;
  SimTime t;
}

//----------------------------------------------------------------------
// Class: uvm_resource_pool
//
// The global (singleton) resource database.
//
// Each resource is stored both by primary name and by type handle.  The
// resource pool contains two associative arrays, one with name as the
// key and one with the type handle as the key.  Each associative array
// contains a queue of resources.  Each resource has a regular
// expression that represents the set of scopes over which it is visible.
//
//|  +------+------------+                          +------------+------+
//|  | name | rsrc queue |                          | rsrc queue | type |
//|  +------+------------+                          +------------+------+
//|  |      |            |                          |            |      |
//|  +------+------------+                  +-+-+   +------------+------+
//|  |      |            |                  | | |<--+---*        |  T   |
//|  +------+------------+   +-+-+          +-+-+   +------------+------+
//|  |  A   |        *---+-->| | |           |      |            |      |
//|  +------+------------+   +-+-+           |      +------------+------+
//|  |      |            |      |            |      |            |      |
//|  +------+------------+      +-------+  +-+      +------------+------+
//|  |      |            |              |  |        |            |      |
//|  +------+------------+              |  |        +------------+------+
//|  |      |            |              V  V        |            |      |
//|  +------+------------+            +------+      +------------+------+
//|  |      |            |            | rsrc |      |            |      |
//|  +------+------------+            +------+      +------------+------+
//
// The above diagrams illustrates how a resource whose name is A and
// type is T is stored in the pool.  The pool contains an entry in the
// type map for type T and an entry in the name map for name A.  The
// queues in each of the arrays each contain an entry for the resource A
// whose type is T.  The name map can contain in its queue other
// resources whose name is A which may or may not have the same type as
// our resource A.  Similarly, the type map can contain in its queue
// other resources whose type is T and whose name may or may not be A.
//
// Resources are added to the pool by calling <set>; they are retrieved
// from the pool by calling <get_by_name> or <get_by_type>.  When an object
// creates a new resource and calls <set> the resource is made available to be
// retrieved by other objects outside of itself; an object gets a
// resource when it wants to access a resource not currently available
// in its scope.
//
// The scope is stored in the resource itself (not in the pool) so
// whether you get by name or by type the resource's visibility is
// the same.
//
// As an auditing capability, the pool contains a history of gets.  A
// record of each get, whether by <get_by_type> or <get_by_name>, is stored
// in the audit record.  Both successful and failed gets are recorded. At
// the end of simulation, or any time for that matter, you can dump the
// history list.  This will tell which resources were successfully
// located and which were not.  You can use this information
// to determine if there is some error in name, type, or
// scope that has caused a resource to not be located or to be incorrectly
// located (i.e. the wrong resource is located).
//
//----------------------------------------------------------------------

class uvm_resource_pool {
  import esdl.data.queue;
  import std.string: format;

  static class uvm_once
  {
    @uvm_immutable_sync
    private uvm_resource_pool _rp; //  = get();
    @uvm_immutable_sync
    private uvm_line_printer _printer;
    this() {
      synchronized(this) {
	_rp = new uvm_resource_pool();
	_printer = new uvm_line_printer();
	_printer.knobs.separator  = "";
	_printer.knobs.full_name  = 0;
	_printer.knobs.identifier = 0;
	_printer.knobs.type_name  = 0;
	_printer.knobs.reference  = 0;
      }
    }
  };

  mixin(uvm_once_sync_string);

  private uvm_resource_types.rsrc_q_t[string]     _rtab;
  private uvm_resource_types.rsrc_q_t[TypeInfo]   _ttab;

  private get_t[] _get_record;  // history of gets

  // To make a proper singleton the constructor should be protected.
  // However, IUS doesn't support protected constructors so we'll just
  // the default constructor instead.  If support for protected
  // constructors ever becomes available then this comment can be
  // deleted and the protected constructor uncommented.

  private this() { }


  // Function: get
  //
  // Returns the singleton handle to the resource pool

  static uvm_resource_pool get() {
    synchronized(once) {
      return rp;
    }
  }


  // Function: spell_check
  //
  // Invokes the spell checker for a string s.  The universe of
  // correctly spelled strings -- i.e. the dictionary -- is the name
  // map.

  final bool spell_check(string s) {
    synchronized(this) {
      return uvm_spell_chkr!(uvm_resource_types.rsrc_q_t).check(_rtab, s);
    }
  }


  //-----------
  // Group: Set
  //-----------

  // Function: set
  //
  // Add a new resource to the resource pool.  The resource is inserted
  // into both the name map and type map so it can be located by
  // either.
  //
  // An object creates a resources and ~sets~ it into the resource pool.
  // Later, other objects that want to access the resource must ~get~ it
  // from the pool
  //
  // Overrides can be specified using this interface.  Either a name
  // override, a type override or both can be specified.  If an
  // override is specified then the resource is entered at the front of
  // the queue instead of at the back.  It is not recommended that users
  // specify the override parameter directly, rather they use the
  // <set_override>, <set_name_override>, or <set_type_override>
  // functions.
  //
  final void set (uvm_resource_base rsrc,
		  uvm_resource_types.override_e ovrrd =
		  uvm_resource_types.override_e.NONE_OVERRIDE) {
    // If resource handle is ~null~ then there is nothing to do.
    if(rsrc is null) {
      return;
    }

    synchronized(this) {
      // insert into the name map.  Resources with empty names are
      // anonymous resources and are not entered into the name map
      string name = rsrc.get_name();
      uvm_resource_types.rsrc_q_t rq;
      if(name != "") {
	if(name in _rtab) {
	  rq = _rtab[name];
	}
	else {
	  rq = new uvm_resource_types.rsrc_q_t("uvm_resource/set/rq");
	}

	// Insert the resource into the queue associated with its name.
	// If we are doing a name override then insert it in the front of
	// the queue, otherwise insert it in the back.
	if(ovrrd & uvm_resource_types.NAME_OVERRIDE) {
	  rq.push_front(rsrc);
	}
	else {
	  rq.push_back(rsrc);
	}

	_rtab[name] = rq;
      }

      // insert into the type map
      auto type_handle = rsrc.get_type_handle();
      if(type_handle in _ttab) {
	rq = _ttab[type_handle];
      }
      else {
	rq = new uvm_resource_types.rsrc_q_t("uvm_resource/set/rq2");
      }

      // insert the resource into the queue associated with its type.  If
      // we are doing a type override then insert it in the front of the
      // queue, otherwise insert it in the back of the queue.
      if(ovrrd & uvm_resource_types.TYPE_OVERRIDE) {
	rq.push_front(rsrc);
      }
      else {
	rq.push_back(rsrc);
      }
      _ttab[type_handle] = rq;
    }
  }

  // Function: set_override
  //
  // The resource provided as an argument will be entered into the pool
  // and will override both by name and type.

  final void set_override(uvm_resource_base rsrc) {
    set(rsrc, (uvm_resource_types.BOTH_OVERRIDE));
  }


  // Function: set_name_override
  //
  // The resource provided as an argument will entered into the pool
  // using normal precedence in the type map and will override the name.

  final void set_name_override(uvm_resource_base rsrc) {
    set(rsrc, uvm_resource_types.NAME_OVERRIDE);
  }


  // Function: set_type_override
  //
  // The resource provided as an argument will be entered into the pool
  // using normal precedence in the name map and will override the type.

  final void set_type_override(uvm_resource_base rsrc) {
    set(rsrc, uvm_resource_types.TYPE_OVERRIDE);
  }


  // function - push_get_record
  //
  // Insert a new record into the get history list.

  final void push_get_record(string name, string rscope,
			     uvm_resource_base rsrc) {
    synchronized(this) {
      // if auditing is turned off then there is no reason
      // to save a get record
      if(!uvm_resource_options.is_auditing()) {
	return;
      }

      // get_t is a struct in vlang so no need to new
      // impt = new get_t();
      get_t impt;

      impt.name   = name;
      impt.rscope = rscope;
      impt.rsrc   = rsrc;
      impt.t      = getRootEntity().getSimTime();

      _get_record ~= impt;
    }
  }

  // function - dump_get_records
  //
  // Format and print the get history list.

  final void dump_get_records() {
    synchronized(this) {
      bool success;
      string qs;

      qs ~= "--- resource get records ---\n";
      foreach (i, record; _get_record) {
	success = (record.rsrc !is null);
	qs ~= format("get: name=%s  scope=%s  %s @ %s\n",
		     record.name, record.rscope,
		     ((success)?"success":"fail"),
		     record.t);
      }
      uvm_root_info("UVM/RESOURCE/GETRECORD", qs, UVM_NONE);
    }
  }

  //--------------
  // Group: Lookup
  //--------------
  //
  // This group of functions is for finding resources in the resource database.
  //
  // <lookup_name> and <lookup_type> locate the set of resources that
  // matches the name or type (respectively) and is visible in the
  // current scope.  These functions return a queue of resources.
  //
  // <get_highest_precedence> traverse a queue of resources and
  // returns the one with the highest precedence -- i.e. the one whose
  // precedence member has the highest value.
  //
  // <get_by_name> and <get_by_type> use <lookup_name> and <lookup_type>
  // (respectively) and <get_highest_precedence> to find the resource with
  // the highest priority that matches the other search criteria.


  // Function: lookup_name
  //
  // Lookup resources by ~name~.  Returns a queue of resources that
  // match the ~name~, ~scope~, and ~type_handle~.  If no resources
  // match the queue is returned empty. If ~rpterr~ is set then a
  // warning is issued if no matches are found, and the spell checker is
  // invoked on ~name~.  If ~type_handle~ is ~null~ then a type check is
  // not made and resources are returned that match only ~name~ and
  // ~scope~.

  final uvm_resource_types.rsrc_q_t lookup_name(string rscope = "",
						string name = "",
						TypeInfo type_handle = null,
						bool rpterr = true) {
    synchronized(this) {
      uvm_resource_types.rsrc_q_t q;

      // ensure rand stability during lookup
      Process p = Process.self();
      Random s;
      if(p !is null) s=p.getRandState();
      q = new  uvm_resource_types.rsrc_q_t("uvm_resource/lookup_name/q");
      if(p !is null) p.setRandState(s);


      // resources with empty names are anonymous and do not exist in the name map
      if(name == "") {
	return q;
      }

      // Does an entry in the name map exist with the specified name?
      // If not, then we're done
      if(name !in _rtab) {
	if(rpterr) {
	  spell_check(name);
	}
	return q;
      }

      uvm_resource_base rsrc = null;
      uvm_resource_types.rsrc_q_t rq = _rtab[name];
      for(size_t i = 0; i < rq.size(); ++i) {
	uvm_resource_base r = rq.get(i);
	// does the type and scope match?
	if(((type_handle is null) || (r.get_type_handle() is type_handle)) &&
	   r.match_scope(rscope))
	  q.push_back(r);
      }

      return q;

    }
  }

  // Function: get_highest_precedence
  //
  // Traverse a queue, ~q~, of resources and return the one with the highest
  // precedence.  In the case where there exists more than one resource
  // with the highest precedence value, the first one that has that
  // precedence will be the one that is returned.

  static uvm_resource_base get_highest_precedence(// ref
						  uvm_resource_types.rsrc_q_t q) {
    uvm_resource_base rsrc = null;
    foreach(r; q) {
      if(rsrc is null || r.precedence > rsrc.precedence) {
	rsrc = r;
      }
    }
    return rsrc;
  }

  // Function: sort_by_precedence
  //
  // Given a list of resources, obtained for example from <lookup_scope>,
  // sort the resources in  precedence order. The highest precedence
  // resource will be first in the list and the lowest precedence will
  // be last. Resources that have the same precedence and the same name
  // will be ordered by most recently set first.

  static void sort_by_precedence(// ref
				 uvm_resource_types.rsrc_q_t q) {
    uvm_resource_types.rsrc_q_t[int] all;
    foreach(r; q) {
      if(r.precedence !in all) {
	all[r.precedence] =
	  new uvm_resource_types.rsrc_q_t(format("uvm_resource/sort_by" ~
						 "_precedence/all[%d]",
						 r.precedence));
      }
      all[r.precedence].push_front(r); //since we will push_front in the final
    }
    q.remove();
    foreach(i; sort(all.keys)) {
      foreach(r; all[i]) {
	q.push_front(r);
      }
    }
  }


  // Function: get_by_name
  //
  // Lookup a resource by ~name~, ~scope~, and ~type_handle~.  Whether
  // the get succeeds or fails, save a record of the get attempt.  The
  // ~rpterr~ flag indicates whether to report errors or not.
  // Essentially, it serves as a verbose flag.  If set then the spell
  // checker will be invoked and warnings about multiple resources will
  // be produced.

  final uvm_resource_base get_by_name(string rscope,
				      string name,
				      TypeInfo type_handle,
				      bool rpterr = true) {
    synchronized(this) {
      uvm_resource_types.rsrc_q_t q = lookup_name(rscope, name, type_handle,
						  rpterr);
      if(q.size() == 0) {
	push_get_record(name, rscope, null);
	return null;
      }
      uvm_resource_base rsrc = get_highest_precedence(q);
      push_get_record(name, rscope, rsrc);
      return rsrc;
    }
  }


  // Function: lookup_type
  //
  // Lookup resources by type. Return a queue of resources that match
  // the ~type_handle~ and ~scope~.  If no resources match then the returned
  // queue is empty.

  final uvm_resource_types.rsrc_q_t lookup_type(string rscope,
						TypeInfo type_handle) {
    synchronized(this) {
      auto q = new uvm_resource_types.rsrc_q_t("uvm_resource/lookup_type/q");

      if(type_handle is null || type_handle !in _ttab) {
	return q;
      }

      uvm_resource_types.rsrc_q_t rq = _ttab[type_handle];
      foreach(r; rq) {
	if(r.match_scope(rscope)) {
	  q.push_back(r);
	}
      }
      return q;
    }
  }

  // Function: get_by_type
  //
  // Lookup a resource by ~type_handle~ and ~scope~.  Insert a record into
  // the get history list whether or not the get succeeded.

  final uvm_resource_base get_by_type(string rscope = "",
				      TypeInfo type_handle=null) {
    synchronized(this) {

      uvm_resource_types.rsrc_q_t q = lookup_type(rscope, type_handle);

      if(q.size() == 0) {
	push_get_record("<type>", rscope, null);
	return null;
      }

      uvm_resource_base rsrc = q.get(0);
      push_get_record("<type>", rscope, rsrc);
      return rsrc;
    }
  }

  // Function: lookup_regex_names
  //
  // This utility function answers the question, for a given ~name~,
  // ~scope~, and ~type_handle~, what are all of the resources with requested name,
  // a matching scope (where the resource scope may be a
  // regular expression), and a matching type?
  // ~name~ and ~scope~ are explicit values.

  final uvm_resource_types.rsrc_q_t lookup_regex_names(string rscope,
						       string name,
						       TypeInfo type_handle = null
						       ) {
    return lookup_name(rscope, name, type_handle, false);
  }

  // Function: lookup_regex
  //
  // Looks for all the resources whose name matches the regular
  // expression argument and whose scope matches the current scope.

  final uvm_resource_types.rsrc_q_t lookup_regex(string re, string rscope) {
    synchronized(this) {

      re = uvm_glob_to_re(re);
      auto result_q =
	new uvm_resource_types.rsrc_q_t("uvm_resource/lookup_regex/result_q");

      foreach (name, rq; _rtab) {
	if(uvm_re_match(re, name)) {
	  continue;
	}
	rq = _rtab[name];
	foreach(r; rq) {
	  if(r.match_scope(rscope)) {
	    result_q.push_back(r);
	  }
	}
      }
      return result_q;
    }
  }

  // Function: lookup_scope
  //
  // This is a utility function that answers the question: For a given
  // ~scope~, what resources are visible to it?  Locate all the resources
  // that are visible to a particular scope.  This operation could be
  // quite expensive, as it has to traverse all of the resources in the
  // database.

  final uvm_resource_types.rsrc_q_t lookup_scope(string rscope) {
    synchronized(this) {
      auto q = new uvm_resource_types.rsrc_q_t("uvm_resource/lookup_scope/q");

      //iterate in reverse order for the special case of autoconfig
      //of arrays. The array name with no [] needs to be higher priority.
      //This has no effect an manual accesses.
      foreach_reverse(name; sort(_rtab.keys)) {
	foreach(r; _rtab[name]) {
	  if(r.match_scope(rscope)) {
	    q.push_back(r);
	  }
	}
      }
      return q;
    }
  }


  //--------------------
  // Group: Set Priority
  //--------------------
  //
  // Functions for altering the search priority of resources.  Resources
  // are stored in queues in the type and name maps.  When retrieving
  // resources, either by type or by name, the resource queue is search
  // from front to back.  The first one that matches the search criteria
  // is the one that is returned.  The ~set_priority~ functions let you
  // change the order in which resources are searched.  For any
  // particular resource, you can set its priority to UVM_HIGH, in which
  // case the resource is moved to the front of the queue, or to UVM_LOW in
  // which case the resource is moved to the back of the queue.

  // function- set_priority_queue
  //
  // This function handles the mechanics of moving a resource to either
  // the front or back of the queue.

  private void set_priority_queue(uvm_resource_base rsrc,
				  /*ref*/ uvm_resource_types.rsrc_q_t q,
				  uvm_resource_types.priority_e pri) {
    synchronized(this) {
      string name = rsrc.get_name();
      uvm_resource_base r;
      size_t i;

      foreach(j, r; q) {
	i = j;
	if(r is rsrc) break;
      }

      if(r !is rsrc) {
	auto msg = format("Handle for resource named %s is not in the" ~
			  " name name; cannot change its priority", name);
	uvm_report_error("NORSRC", msg);
	return;
      }

      q.remove(i);

      final switch (pri) {
      case uvm_resource_types.PRI_HIGH: q.push_front(rsrc); break;
      case uvm_resource_types.PRI_LOW:  q.push_back(rsrc); break;
      }
    }
  }


  // Function: set_priority_type
  //
  // Change the priority of the ~rsrc~ based on the value of ~pri~, the
  // priority enum argument.  This function changes the priority only in
  // the type map, leaving the name map untouched.

  final void set_priority_type(uvm_resource_base rsrc,
			       uvm_resource_types.priority_e pri) {
    synchronized(this) {

      if(rsrc is null) {
	uvm_report_warning("NULLRASRC", "attempting to change"
			   " the serach priority of a null resource");
	return;
      }

      TypeInfo type_handle = rsrc.get_type_handle();
      if(type_handle !in _ttab) {
	string msg = format("Type handle for resrouce named %s not found in"
			    " type map; cannot change its search priority",
			    rsrc.get_name());
	uvm_report_error("RNFTYPE", msg);
	return;
      }

      uvm_resource_types.rsrc_q_t q = _ttab[type_handle];
      set_priority_queue(rsrc, q, pri);
    }
  }


  // Function: set_priority_name
  //
  // Change the priority of the ~rsrc~ based on the value of ~pri~, the
  // priority enum argument.  This function changes the priority only in
  // the name map, leaving the type map untouched.

  final void set_priority_name(uvm_resource_base rsrc,
			       uvm_resource_types.priority_e pri) {
    synchronized(this) {
      if(rsrc is null) {
	uvm_report_warning("NULLRASRC", "attempting to change the serach"
			   " priority of a null resource");
	return;
      }
      string name = rsrc.get_name();
      if(name !in _rtab) {
	string msg = format("Resrouce named %s not found in name map;"
			    " cannot change its search priority", name);
	uvm_report_error("RNFNAME", msg);
	return;
      }
      uvm_resource_types.rsrc_q_t q = _rtab[name];
      set_priority_queue(rsrc, q, pri);
    }
  }


  // Function: set_priority
  //
  // Change the search priority of the ~rsrc~ based on the value of ~pri~,
  // the priority enum argument.  This function changes the priority in
  // both the name and type maps.

  final void set_priority (uvm_resource_base rsrc,
			   uvm_resource_types.priority_e pri) {
    synchronized(this) {
      set_priority_type(rsrc, pri);
      set_priority_name(rsrc, pri);
    }
  }

  //--------------------------------------------------------------------
  // Group: Debug
  //--------------------------------------------------------------------

  // Function: find_unused_resources
  //
  // Locate all the resources that have at least one write and no reads

  final uvm_resource_types.rsrc_q_t find_unused_resources() {
    synchronized(this) {
      auto q =
	new uvm_resource_types.rsrc_q_t("uvm_resource/find_unused_resources/q");
      foreach (name, rq; _rtab) {
	foreach(r; rq) {
	  int reads = 0;
	  int writes = 0;
	  synchronized(r) {
	    foreach(str, a; r._access) {
	      reads += a.read_count;
	      writes += a.write_count;
	    }
	  }
	  if(writes > 0 && reads == 0) {
	    q.push_back(r);
	  }
	}
      }
      return q;
    }
  }


  // Function: print_resources
  //
  // Print the resources that are in a single queue, ~rq~.  This is a utility
  // function that can be used to print any collection of resources
  // stored in a queue.  The ~audit~ flag determines whether or not the
  // audit trail is printed for each resource along with the name,
  // value, and scope regular expression.

  final void print_resources(uvm_resource_types.rsrc_q_t rq,
			     bool audit = false) {
    synchronized(this) {

      // moved to once

      // printer.knobs.separator  = "";
      // printer.knobs.full_name  = 0;
      // printer.knobs.identifier = 0;
      // printer.knobs.type_name  = 0;
      // printer.knobs.reference  = 0;

      if(rq is null || rq.size() is 0) {
	import uvm.meta.mcd;
	uvm_root_info("UVM/RESOURCE/PRINT", "<none>", UVM_NONE);
	return;
      }

      foreach(r; rq) {
	r.print(printer);
	if(audit is true) {
	  r.print_accessors();
	}
      }
    }
  }


  // Function: dump
  //
  // dump the entire resource pool.  The resource pool is traversed and
  // each resource is printed.  The utility function print_resources()
  // is used to initiate the printing. If the ~audit~ bit is set then
  // the audit trail is dumped for each resource.

  final void dump(bool audit = false) {
    synchronized(this) {
      import uvm.meta.mcd;
      uvm_root_info("UVM/RESOURCE/DUMP", "\n=== resource pool ===", UVM_NONE);

      foreach (name, rq; _rtab) {
	print_resources(rq, audit);
      }

      uvm_root_info("UVM/RESOURCE/DUMP", "=== end of resource pool ===", UVM_NONE);

    }
  }
}

//----------------------------------------------------------------------
// Class: uvm_resource #(T)
//
// Parameterized resource.  Provides essential access methods to read
// from and write to the resource database.
//----------------------------------------------------------------------

class uvm_resource (T=int): uvm_resource_base
{

  alias this_type = uvm_resource!(T);

  // singleton handle that represents the type of this resource
  // private shared static this_type _my_type;

  // Can't be rand since things like rand strings are not legal.
  protected T _val;

  // FIXME -- UVM_USE_RESOURCE_CONVERTER needs to be deprecated at some point of time
  version(UVM_USE_RESOURCE_CONVERTER) {
    // Singleton used to convert this resource to a string
    private shared static m_uvm_resource_converter!(T) _m_r2s;

    // static this() {
    //   _my_type = get_type()
    // }

    // Function- m_get_converter
    // Get the conversion policy class that specifies how to convert the value
    // of a resource of this type to a string
    //
    static m_uvm_resource_converter!(T) m_get_converter() {
      synchronized(typeid(this_type)) {
	if (_m_r2s is null) _m_r2s = cast(shared m_uvm_resource_converter!(T))
			      (new m_uvm_resource_converter!(T)());
	return cast(m_uvm_resource_converter!(T)) _m_r2s;
      }
    }


    // Function- m_set_converter
    // Specify how to convert the value of a resource of this type to a string
    //
    // If not specified (or set to ~null~),
    // a default converter that display the name of the resource type is used.
    // Default conversion policies are specified for the built-in type.
    //
    static void m_set_converter(m_uvm_resource_converter!(T) r2s) {
      synchronized(typeid(this_type)) {
	_m_r2s = r2s;
      }
    }

  }

  this(string name="", string rscope="") {
    synchronized(this) {
      super(name, rscope);

      version(UVM_INCLUDE_DEPRECATED) {
      	for(int i=0; i<name.length; i++) {
      	  if(name[i] == '.' || name[i] == '/' ||
      	     name[i] == '[' || name[i] == '*' ||
      	     name[i] == '{') {
      	    uvm_root_warning("UVM/RSRC/NOREGEX",
      			     format("a resource with meta characters in the " ~
      				    "field name has been created \"%s\"",name));
      	    break;
      	  }
      	}
      }
    }
  }

  string to(S)() if(is(S == string)) {
    synchronized(this) {
      version(UVM_USE_RESOURCE_CONVERTER) {
	m_get_converter();
	synchronized(typeid(this_type)) {
	  return _m_r2s.convert2string(_val);
	}
      }
      else {
	import std.string: format;
	return format("(%s) %0s", qualifiedTypeName!T, _val);
      }
    }
  }

  override string convert2string() {
    return this.to!string();
  }


  //----------------------
  // Group: Type Interface
  //----------------------
  //
  // Resources can be identified by type using a static type handle.
  // The parent class provides the virtual function interface
  // <get_type_handle>.  Here we implement it by returning the static type
  // handle.

  // Function: get_type
  //
  // Static function that returns the static type handle.  The return
  // type is this_type, which is the type of the parameterized class.

  static TypeInfo get_type() {
    return typeid(T);
  }

  // Function: get_type_handle
  //
  // Returns the static type handle of this resource in a polymorphic
  // fashion.  The return type of get_type_handle() is
  // uvm_resource_base.  This function is not static and therefore can
  // only be used by instances of a parameterized resource.

  override TypeInfo get_type_handle() {
    return get_type();
  }

  //-------------------------
  // Group: Set/Get Interface
  //-------------------------
  //
  // uvm_resource#(T) provides an interface for setting and getting a
  // resources.  Specifically, a resource can insert itself into the
  // resource pool.  It doesn't make sense for a resource to get itself,
  // since you can't call a function on a handle you don't have.
  // However, a static get interface is provided as a convenience.  This
  // obviates the need for the user to get a handle to the global
  // resource pool as this is done for him here.

  // Function: set
  //
  // Simply put this resource into the global resource pool

  final void set() {
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.set(this);
  }


  // Function: set_override
  //
  // Put a resource into the global resource pool as an override.  This
  // means it gets put at the head of the list and is searched before
  // other existing resources that occupy the same position in the name
  // map or the type map.  The default is to override both the name and
  // type maps.  However, using the ~override~ argument you can specify
  // that either the name map or type map is overridden.

  final void set_override(uvm_resource_types.override_e ovrrd =
			  uvm_resource_types.override_e.BOTH_OVERRIDE) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.set(this, ovrrd);
  }

  // Function: get_by_name
  //
  // looks up a resource by ~name~ in the name map. The first resource
  // with the specified name, whose type is the current type, and is
  // visible in the specified ~scope~ is returned, if one exists.  The
  // ~rpterr~ flag indicates whether or not an error should be reported
  // if the search fails.  If ~rpterr~ is set to one then a failure
  // message is issued, including suggested spelling alternatives, based
  // on resource names that exist in the database, gathered by the spell
  // checker.

  static this_type get_by_name(string rscope,
			       string name,
			       bool rpterr = true) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    uvm_resource_base rsrc_base = rp.get_by_name(rscope, name,
						 typeid(T),
						 // cast(this_type) _my_type,
						 rpterr);
    if(rsrc_base is null) {
      return null;
    }

    auto rsrc = cast(this_type) rsrc_base;
    if(rsrc is null) {
      if(rpterr) {
	string msg = format("Resource with name %s in scope %s has incorrect type",
			    name, rscope);
	uvm_root_warning("RSRCTYPE", msg);
      }
      return null;
    }
    return rsrc;
  }

  // Function: get_by_type
  //
  // looks up a resource by ~type_handle~ in the type map. The first resource
  // with the specified ~type_handle~ that is visible in the specified ~scope~ is
  // returned, if one exists. If there is no resource matching the specifications,
  // ~null~ is returned.

  static this_type get_by_type(string rscope = "",
			       TypeInfo type_handle=null) {
    uvm_resource_pool rp = uvm_resource_pool.get();

    if(type_handle is null) {
      return null;
    }
    uvm_resource_base rsrc_base = rp.get_by_type(rscope, type_handle);
    if(rsrc_base is null) {
      return null;
    }
    auto rsrc = cast(this_type) rsrc_base;
    if(rsrc is null) {
      string msg = format("Resource with specified type handle in" ~
			  " scope %s was not located", rscope);
      uvm_root_warning("RSRCNF", msg);
      return null;
    }

    return rsrc;
  }

  //----------------------------
  // Group: Read/Write Interface
  //----------------------------
  //
  // <read> and <write> provide a type-safe interface for getting and
  // setting the object in the resource container.  The interface is
  // type safe because the value argument for <write> and the return
  // value of <read> are T, the type supplied in the class parameter.
  // If either of these functions is used in an incorrect type context
  // the compiler will complain.

  // Function: read
  //
  // Return the object stored in the resource container.  If an ~accessor~
  // object is supplied then also update the accessor record for this
  // resource.

  T read(uvm_object accessor = null) {
    synchronized(this) {
      record_read_access(accessor);
      return _val;
    }
  }

  // Function: write
  // Modify the object stored in this resource container.  If the
  // resource is read-only then issue an error message and return
  // without modifying the object in the container.  If the resource is
  // not read-only and an ~accessor~ object has been supplied then also
  // update the accessor record.  Lastly, replace the object value in
  // the container with the value supplied as the argument, ~t~, and
  // release any processes blocked on
  // <uvm_resource_base.wait_modified>.  If the value to be written is
  // the same as the value already present in the resource then the
  // write is not done.  That also means that the accessor record is not
  // updated and the modified bit is not set.

  void write(T t, uvm_object accessor = null) {
    synchronized(this) {
      if(is_read_only()) {
	uvm_report_error("resource",
			 format("resource %s is read only -- cannot modify",
				get_name()));
	return;
      }

      // Set the modified bit and record the transaction only if the value
      // has actually changed.
      if(_val is t) {
	return;
      }
      record_write_access(accessor);

      // set the value and set the dirty bit
      _val = t;
      modified = true;
    }
  }

  //----------------
  // Group: Priority
  //----------------
  //
  // Functions for manipulating the search priority of resources.  These
  // implementations of the interface defined in the base class delegate
  // to the resource pool.


  // Function: set priority
  //
  // Change the search priority of the resource based on the value of
  // the priority enum argument, ~pri~.

  override void set_priority (uvm_resource_types.priority_e pri) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.set_priority(this, pri);
  }


  // Function: get_highest_precedence
  //
  // In a queue of resources, locate the first one with the highest
  // precedence whose type is T.  This function is static so that it can
  // be called from anywhere.

  static this_type get_highest_precedence(/*ref*/ uvm_resource_types.rsrc_q_t q) {
    if(q.size() == 0) {
      return null;
    }

    this_type rsrc;
    size_t first;		// value is taken to the next for loop
    // Locate first resources in the queue whose type is T
    for (first=0; first < q.size; ++first) {
      rsrc = cast(this_type) q.get(first);
      if(rsrc !is null) {
	break;
      }
    }

    // no resource in the queue whose type is T
    if(rsrc is null) {
      return null;
    }
    uint prec = rsrc.precedence;

    // start searching from the next resource after the first resource
    // whose type is T
    for(size_t i = first+1; i < q.size(); ++i) {
      this_type r = cast(this_type) q.get(i);
      if(r !is null) {
	if(r.precedence > prec) {
	  rsrc = r;
	  prec = r.precedence;
	}
      }
    }
    return rsrc;
  }

};

//----------------------------------------------------------------------
// static global resource pool handle
//----------------------------------------------------------------------

uvm_resource_pool uvm_resources() {
  return uvm_resource_pool.get();
}
