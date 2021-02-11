//----------------------------------------------------------------------
// Copyright 2019 Coverify Systems Technology
// Copyright 2018 Cadence Design Systems, Inc.
// Copyright 2018 NVIDIA Corporation
// Copyright 2017-2018 Cisco Systems, Inc.
// Copyright 2017-2018 Verific
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

module uvm.base.uvm_resource_base;
import uvm.base.uvm_scope;
import uvm.base.uvm_pool: uvm_pool;
import uvm.base.uvm_queue: uvm_queue;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_resource: uvm_resource;
import uvm.base.uvm_globals: uvm_is_match, uvm_info;
import uvm.base.uvm_object_globals: uvm_verbosity;
import uvm.dpi.uvm_regex: uvm_glob_to_re;

import esdl.base.core: SimTime, getSimTime, wait;
import uvm.meta.misc;
//----------------------------------------------------------------------
// Title -- NODOCS -- Resources
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
// Class -- NODOCS -- uvm_resource_types
//
// Provides typedefs and enums used throughout the resources facility.
// This class has no members or methods, only typedefs.  It's used in
// lieu of package-scope types.  When needed, other classes can use
// these types by prefixing their usage with uvm_resource_types::.  E.g.
//
//|  uvm_resource_types::rsrc_q_t queue;
//
//----------------------------------------------------------------------
class uvm_resource_types
{

  // types uses for setting overrides
  alias override_t = ubyte;
  enum override_e: override_t {TYPE_OVERRIDE = 0b01, NAME_OVERRIDE = 0b10 }

  // general purpose queue of resourcex
  alias rsrc_q_t = uvm_queue!uvm_resource_base;

  // enum for setting resource search priority
  enum priority_e: ubyte {PRI_HIGH, PRI_LOW}

  // access record for resources.  A set of these is stored for each
  // resource by accessing object.  It's updated for each read/write.
  struct access_t
  {
    SimTime read_time;
    SimTime write_time;
    uint read_count;
    uint write_count;
  }

}

//----------------------------------------------------------------------
// Class -- NODOCS -- uvm_resource_options
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

  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    bool _auditing = true;
  }
    
  mixin (uvm_scope_sync_string);

  // Function -- NODOCS -- turn_on_auditing
  //
  // Turn auditing on for the resource database. This causes all
  // reads and writes to the database to store information about
  // the accesses. Auditing is turned on by default.

  static void turn_on_auditing() {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._auditing = true;
    }
  }

  // Function -- NODOCS -- turn_off_auditing
  //
  // Turn auditing off for the resource database. If auditing is turned off,
  // it is not possible to get extra information about resource
  // database accesses.

  static void turn_off_auditing() {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._auditing = false;
    }
  }

  // Function -- NODOCS -- is_auditing
  //
  // Returns 1 if the auditing facility is on and 0 if it is off.

  static bool is_auditing() {
    synchronized (_uvm_scope_inst) {
      return _uvm_scope_inst._auditing;
    }
  }
}


//----------------------------------------------------------------------
// Class -- NODOCS -- uvm_resource_base
//
// Non-parameterized base class for resources.  Supports interfaces for
// scope matching, and virtual functions for printing the resource and
// for printing the accessor list
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Class: uvm_resource_base
//
// The library implements the following public API beyond what is 
// documented in 1800.2.
//----------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto C.2.3.1
abstract class uvm_resource_base: uvm_object
{

  mixin (uvm_sync_string);

  @uvm_immutable_sync
  private WithEvent!bool _modified;

  @uvm_protected_sync
  private bool _read_only;

  // @uvm_protected_sync
  // protected uvm_resource_types.access_t[string] _access;
  @uvm_immutable_sync
  protected uvm_pool!(string, uvm_resource_types.access_t) _access;

  // Function -- NODOCS -- new
  //
  // constructor for uvm_resource_base.  The constructor takes two
  // arguments, the name of the resource and a regular expression which
  // represents the set of scopes over which this resource is visible.

  // @uvm-ieee 1800.2-2017 auto C.2.3.2.1
  this(string name = "") {
    synchronized (this) {
      super(name);
      _modified = new WithEvent!bool("modified", false);
      _read_only = false;
      _access =
	new uvm_pool!(string, uvm_resource_types.access_t)("_access");
    }
  }

  // Function -- NODOCS -- get_type_handle
  //
  // Pure virtual function that returns the type handle of the resource
  // container.

  // @uvm-ieee 1800.2-2017 auto C.2.3.2.2
  abstract uvm_resource_base get_type_handle();


  //---------------------------
  // Group -- NODOCS -- Read-only Interface
  //---------------------------

  // Function -- NODOCS -- set_read_only
  //
  // Establishes this resource as a read-only resource.  An attempt
  // to call <uvm_resource#(T)::write> on the resource will cause an error.

  // @uvm-ieee 1800.2-2017 auto C.2.3.3.1
  void set_read_only() {
    synchronized (this) {
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
    synchronized (this) {
      _read_only = false;
    }
  }


  // @uvm-ieee 1800.2-2017 auto C.2.3.3.2
  bool is_read_only() {
    synchronized (this) {
      return _read_only;
    }
  }


  //--------------------
  // Group -- NODOCS -- Notification
  //--------------------

  // Task -- NODOCS -- wait_modified
  //
  // This task blocks until the resource has been modified -- that is, a
  // <uvm_resource#(T)::write> operation has been performed.  When a 
  // <uvm_resource#(T)::write> is performed the modified bit is set which 
  // releases the block.  Wait_modified() then clears the modified bit so 
  // it can be called repeatedly.

  // task
  // @uvm-ieee 1800.2-2017 auto C.2.3.4
  void wait_modified() {
    while (_modified.get() != true) {
      _modified.wait();
    }
    _modified.set(false);
  }

  //-------------------------
  // Group -- NODOCS -- Utility Functions
  //-------------------------

  // function convert2string
  //
  // Create a string representation of the resource value.  By default
  // we don't know how to do this so we just return a "?".  Resource
  // specializations are expected to override this function to produce a
  // proper string representation of the resource value.

  override string convert2string() {
    import std.string: format;
    return format("(%s) %s", m_value_type_name(), m_value_as_string());
  }

  override string toString() {
    import std.string: format;
    return format("(%s) %s", m_value_type_name(), m_value_as_string());
  }

  // Helper for printing externally, non-LRM
  abstract string m_value_type_name();
  abstract string m_value_as_string();
  
  override void do_print(uvm_printer printer) {
    super.do_print(printer);
    printer.print_generic_element("val", m_value_type_name(), "", m_value_as_string());
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

  // Function: record_read_access
  //
  // Record the read access information for this resource for debug purposes.
  // This information is used by <print_accessors> function.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  void record_read_access(uvm_object accessor = null) {
    synchronized (this) {
      string str;
      uvm_resource_types.access_t access_record;

      // If an accessor object is supplied then get the accessor record.
      // Otherwise create a new access record.  In either case populate
      // the access record with information about this access.  Check
      // first to make sure that auditing is turned on.

      if (! uvm_resource_options.is_auditing()) {
	return;
      }

      // If an accessor is supplied, then use its name
      // as the database entry for the accessor record.
      // Otherwise, use "<empty>" as the database entry.
      if (accessor !is null) {
	str = accessor.get_full_name();
      }
      else {
	str = "<empty>";
      }

      // Create a new accessor record if one does not exist
      if (str in _access) {
	access_record = _access[str];
      }
      init_access_record(access_record);

      // Update the accessor record
      access_record.read_count++;
      access_record.read_time = getSimTime();
      _access[str] = access_record;
    }
  }

  // Function: record_write_access
  //
  // Record the write access information for this resource for debug purposes.
  // This information is used by <print_accessors> function.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  void record_write_access(uvm_object accessor = null) {
    synchronized (this) {
      // If an accessor object is supplied then get the accessor record.
      // Otherwise create a new access record.  In either case populate
      // the access record with information about this access.  Check
      // first that auditing is turned on
      if (uvm_resource_options.is_auditing()) {
	if (accessor !is null) {
	  uvm_resource_types.access_t access_record;
	  string str = accessor.get_full_name();
	  if (str in _access) {
	    access_record = _access[str];
	  }
	  else {
	    init_access_record(access_record);
	  }
	  access_record.write_count++;
	  access_record.write_time = getSimTime();
	  _access[str] = access_record;
	}
      }
    }
  }

  // Function: print_accessors
  //
  // Print the read/write access history of the resource, using the accessor 
  // argument <accessor> which is passed to the <uvm_resource#(T)::read> 
  // and <uvm_resource#(T)::write> 
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  void print_accessors() {
    import std.string: format;
    synchronized (this) {
      // string str;
      // uvm_component comp;
      uvm_resource_types.access_t access_record;
      string qs;
    
      if (_access.length == 0) {
	return;
      }

      foreach (str, acc; _access) {
	access_record = acc;
	qs ~= format("%s reads: %0d @ %0d  writes: %0d @ %0d\n", str,
		     access_record.read_count,
		     access_record.read_time,
		     access_record.write_count,
		     access_record.write_time);
      }
      uvm_info("UVM/RESOURCE/ACCESSOR", qs, uvm_verbosity.UVM_NONE);
    }
  }


  // Function -- NODOCS -- init_access_record
  //
  // Initialize a new access record
  //
  void init_access_record (ref uvm_resource_types.access_t access_record) {
    access_record.read_time = 0;
    access_record.write_time = 0;
    access_record.read_count = 0;
    access_record.write_count = 0;
  }

  void uvm_resource_read(T)(ref bool success, ref T val, uvm_object obj=null) {
    uvm_resource!(T) tmp = cast (uvm_resource!T) this;
    if (tmp !is null) success = true;
    if (success) {
      val = tmp.read(obj);
    }
  }

  void uvm_set_element(E)(string name, ref E lhs,
			  uvm_object obj, uvm_field_flag_t flags) {
    synchronized (this) {
      m_uvm_set_element!E(name, this.get_name(), lhs, obj, flags);
    }
  }

  void m_uvm_set_element(E)(string name, string rsrc_name, ref E lhs,
			    uvm_object obj, uvm_field_flag_t flags) {
    static if (isArray!E && !is (E == string)) {
      static if (isStaticArray!E) {
	uvm_warning("UVM/FIELDS/SARRAY_SIZE",
		    format("Static array '%s.%s' cannot be resized via configuration.",
			   get_full_name(), name));
      }
      static if (isDynamicArray!E) {
	if (name = rsrc_name) {
	  size_t size;
	  bool success;
	  uvm_resource_read(success, size, obj);
	  if (success) {
	    lhs.length = size;
	  }
	}
      }
      // array elements
      if (rsrc_name.length > name.length &&
	  rsrc_name[0..name.length] == name) {
	for (size_t i=0; i != lhs.length; ++i) {
	  m_uvm_set_element(format("%s[%d]", name, i), rsrc_name,
			    lhs[i], obj, flags);
	}
      }
    }
    else static if (is (E: uvm_object)) {
      if (name == rsrc_name) {
	bool success;
	uvm_object local_obj;
	this.uvm_resorce_read(success, local_obj, obj);
	if (local_obj is null) {
	  lhs = null;
	  return;
	}
	lhs = cast (E) local_obj;
	if (lhs is null) {
	  uvm_warning("UVM/FIELDS/OBJ_TYPE",
		      format("Can't set field '%s' on '%s' with '%s' type",
			     name, this.get_full_name(), E.stringof));
	}
      }
    }
    else {
      if (name == rsrc_name) {
	bool success;
	this.uvm_resorce_read(success, lhs, obj);
	if (success is false) {
	  uvm_warning("UVM/FIELDS/UVM_SET",
		      format("Can't set field '%s' on '%s' with '%s' type",
			     name, this.get_full_name(), E.stringof));
	}
      }
    }
  }
  
  
}
