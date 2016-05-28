//----------------------------------------------------------------------
//   Copyright 2011      Cypress Semiconductor
//   Copyright 2010      Mentor Graphics Corporation
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
// Title: UVM Resource Database
//
// Topic: Intro
//
// The <uvm_resource_db> class provides a convenience interface for
// the resources facility.  In many cases basic operations such as
// creating and setting a resource or getting a resource could take
// multiple lines of code using the interfaces in <uvm_resource_base> or
// <uvm_resource#(T)>.  The convenience layer in <uvm_resource_db>
// reduces many of those operations to a single line of code.
//
// If the run-time ~+UVM_RESOURCE_DB_TRACE~ command line option is
// specified, all resource DB accesses (read and write) are displayed.
//----------------------------------------------------------------------

// typedef class uvm_resource_db_options;
// typedef class uvm_cmdline_processor;

module uvm.base.uvm_resource_db;

import uvm.base.uvm_cmdline_processor;
import uvm.base.uvm_resource;
import uvm.base.uvm_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_entity;

import uvm.meta.misc;

import esdl.data.queue;

import std.string;

//----------------------------------------------------------------------
// class: uvm_resource_db
//
// All of the functions in uvm_resource_db#(T) are static, so they
// must be called using the . operator.  For example:
//
//|  uvm_resource_db#(int).set("A", "*", 17, this);
//
// The parameter value "int" identifies the resource type as
// uvm_resource#(int).  Thus, the type of the object in the resource
// container is int. This maintains the type-safety characteristics of
// resource operations.
//
//----------------------------------------------------------------------
class uvm_resource_db (T=uvm_object) {

  alias rsrc_t = uvm_resource!T;

  protected this() { }

  // function: get_by_type
  //
  // Get a resource by type.  The type is specified in the db
  // class parameter so the only argument to this function is the
  // ~scope~.

  static rsrc_t get_by_type(string rscope) {
    return rsrc_t.get_by_type(rscope, rsrc_t.get_type());
  }

  // function: get_by_name
  //
  // Imports a resource by ~name~.  The first argument is the ~name~ of the
  // resource to be retrieved and the second argument is the current
  // ~scope~. The ~rpterr~ flag indicates whether or not to generate
  // a warning if no matching resource is found.

  static rsrc_t get_by_name(string rscope,
			    string name,
			    bool rpterr = true) {
    return rsrc_t.get_by_name(rscope, name, rpterr);
  }

  // function: set_default
  //
  // add a new item into the resources database.  The item will not be
  // written to so it will have its default value. The resource is
  // created using ~name~ and ~scope~ as the lookup parameters.

  static rsrc_t set_default(string rscope, string name) {
    rsrc_t r = new rsrc_t(name, rscope);
    r.set();
    return r;
  }

  // function- show_msg

  // internal helper function to print resource accesses

  protected static void m_show_msg(string id,
				   string rtype,
				   string action,
				   string rscope,
				   string name,
				   uvm_object accessor,
				   rsrc_t rsrc) {
    string msg = format("%s '%s%s' (type %s) %s by %s = %s", rtype, rscope,
			name=="" ? "" : "." ~ name, typeid(T), action,
			(accessor !is null) ? accessor.get_full_name() :
			"<unknown>", rsrc is null ?
			"null (failed lookup)" : rsrc.convert2string());
    uvm_info(id, msg, UVM_LOW);
  }

  // function: set
  //
  // Create a new resource, write a ~val~ to it, and set it into the
  // database using ~name~ and ~scope~ as the lookup parameters. The
  // ~accessor~ is used for auditting.
  static void set(string rscope, string name,
		  T val, uvm_object accessor = null) {
    rsrc_t rsrc = new rsrc_t(name, rscope);
    rsrc.write(val, accessor);
    rsrc.set();

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/SET", "Resource","set", rscope, name, accessor, rsrc);
    }
  }

  // function: set_anonymous
  //
  // Create a new resource, write a ~val~ to it, and set it into the
  // database.  The resource has no name and therefore will not be
  // entered into the name map. But is does have a ~scope~ for lookup
  // purposes. The ~accessor~ is used for auditting.
  static void set_anonymous(string rscope,
			    T val, uvm_object accessor = null) {
    rsrc_t rsrc = new rsrc_t("", rscope);
    rsrc.write(val, accessor);
    rsrc.set();

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/SETANON","Resource", "set", rscope, "", accessor, rsrc);
    }
  }

  // function set_override
  //
  // Create a new resource, write ~val~ to it, and set it into the
  // database.  Set it at the beginning of the queue in the type map and
  // the name map so that it will be (currently) the highest priority
  // resource with the specified name and type.

  static void set_override(string rscope, string name,
			   T val, uvm_object accessor = null) {
    rsrc_t rsrc = new rsrc_t(name, rscope);
    rsrc.write(val, accessor);
    rsrc.set_override();

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/SETOVRD", "Resource","set", rscope, name,
		 accessor, rsrc);
    }
  }



  // function set_override_type
  //
  // Create a new resource, write ~val~ to it, and set it into the
  // database.  Set it at the beginning of the queue in the type map so
  // that it will be (currently) the highest priority resource with the
  // specified type. It will be normal priority (i.e. at the end of the
  // queue) in the name map.

  static void set_override_type(string rscope, string name,
				T val, uvm_object accessor = null) {
    rsrc_t rsrc = new rsrc_t(name, rscope);
    rsrc.write(val, accessor);
    rsrc.set_override(uvm_resource_types.TYPE_OVERRIDE);

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/SETOVRDTYP","Resource", "set", rscope, name,
		 accessor, rsrc);
    }
  }

  // function set_override_name
  //
  // Create a new resource, write ~val~ to it, and set it into the
  // database.  Set it at the beginning of the queue in the name map so
  // that it will be (currently) the highest priority resource with the
  // specified name. It will be normal priority (i.e. at the end of the
  // queue) in the type map.

  static void set_override_name(string rscope, string name,
				T val, uvm_object accessor = null) {
    rsrc_t rsrc = new rsrc_t(name, rscope);
    rsrc.write(val, accessor);
    rsrc.set_override(uvm_resource_types.NAME_OVERRIDE);

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/SETOVRDNAM","Resource", "set", rscope, name,
		 accessor, rsrc);
    }
  }

  // function: read_by_name
  //
  // locate a resource by ~name~ and ~scope~ and read its value. The value
  // is returned through the output argument ~val~.  The return value is a bit
  // that indicates whether or not the read was successful. The ~accessor~
  // is used for auditting.
  static bool read_by_name(string rscope,
			   string name,
			   ref T val, uvm_object accessor = null) {
    rsrc_t rsrc = get_by_name(rscope, name);

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/RDBYNAM","Resource", "read", rscope, name,
		 accessor, rsrc);
    }

    if(rsrc is null) return false;

    val = rsrc.read(accessor);

    return true;
  }

  // function: read_by_type
  //
  // Read a value by type.  The value is returned through the output
  // argument ~val~.  The ~scope~ is used for the lookup. The return
  // value is a bit that indicates whether or not the read is successful.
  // The ~accessor~ is used for auditting.
  static bool read_by_type(string rscope,
			   ref T val,
			   uvm_object accessor = null) {
    rsrc_t rsrc = get_by_type(rscope);

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/RDBYTYP", "Resource","read", rscope, "",
		 accessor, rsrc);
    }

    if(rsrc is null) return false;

    val = rsrc.read(accessor);

    return true;
  }

  // function: write_by_name
  //
  // write a ~val~ into the resources database.  First, look up the
  // resource by ~name~ and ~scope~.  If it is not located then add a new
  // resource to the database and then write its value.
  //
  // Because the ~scope~ is matched to a resource which may be a
  // regular expression, and consequently may target other scopes beyond
  // the ~scope~ argument. Care must be taken with this function. If
  // a <get_by_name> match is found for ~name~ and ~scope~ then ~val~
  // will be written to that matching resource and thus may impact
  // other scopes which also match the resource.
  static bool write_by_name(string rscope, string name,
			    T val, uvm_object accessor = null) {
    rsrc_t rsrc = get_by_name(rscope, name);

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/WR","Resource", "written", rscope, name,
		 accessor, rsrc);
    }

    if(rsrc is null) {
      return false;
    }

    rsrc.write(val, accessor);

    return true;
  }

  // function: write_by_type
  //
  // write a ~val~ into the resources database.  First, look up the
  // resource by type.  If it is not located then add a new resource to
  // the database and then write its value.
  //
  // Because the ~scope~ is matched to a resource which may be a
  // regular expression, and consequently may target other scopes beyond
  // the ~scope~ argument. Care must be taken with this function. If
  // a <get_by_name> match is found for ~name~ and ~scope~ then ~val~
  // will be written to that matching resource and thus may impact
  // other scopes which also match the resource.
  static bool write_by_type(string rscope,
			    T val, uvm_object accessor = null) {
    rsrc_t rsrc = get_by_type(rscope);

    if(uvm_resource_db_options.is_tracing()) {
      m_show_msg("RSRCDB/WRTYP", "Resource","written", rscope, "",
		 accessor, rsrc);
    }

    if(rsrc is null) {
      return false;
    }

    rsrc.write(val, accessor);

    return true;
  }

  // function: dump
  //
  // Dump all the resources in the resource pool. This is useful for
  // debugging purposes.  This function does not use the parameter T, so
  // it will dump the same thing -- the entire database -- no matter the
  // value of the parameter.

  static void dump() {
    uvm_resource_pool rp = uvm_resource_pool.get();
    rp.dump();
  }
}


//----------------------------------------------------------------------
// Class: uvm_resource_db_options
//
// Provides a namespace for managing options for the
// resources DB facility.  The only thing allowed in this class is static
// local data members and static functions for manipulating and
// retrieving the value of the data members.  The static local data
// members represent options and settings that control the behavior of
// the resources DB facility.

// Options include:
//
//  * tracing:  on/off
//
//    The default for tracing is off.
//
//----------------------------------------------------------------------
class uvm_resource_db_options
{
  static class uvm_once
  {
    @uvm_public_sync
    private bool _ready;
    @uvm_public_sync
    private bool _tracing;
  }

    mixin(uvm_once_sync_string);

  // Function: turn_on_tracing
  //
  // Turn tracing on for the resource database. This causes all
  // reads and writes to the database to display information about
  // the accesses. Tracing is off by default.
  //
  // This method is implicitly called by the ~+UVM_RESOURCE_DB_TRACE~.

  static void turn_on_tracing() {
    synchronized(once) {
      if (! _ready) {
	init();
      }
      _tracing = true;
    }
  }

  // Function: turn_off_tracing
  //
  // Turn tracing off for the resource database.

  static void turn_off_tracing() {
    synchronized(once) {
      if (! _ready) {
	init();
      }
      _tracing = false;
    }
  }

  // Function: is_tracing
  //
  // Returns 1 if the tracing facility is on and 0 if it is off.

  static bool is_tracing() {
    synchronized(once) {
      if (! _ready) init();
      return _tracing;
    }
  }


  static private void init() {
    uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
    string[] trace_args;
    synchronized(once) {
      if (clp.get_arg_matches(`\+UVM_RESOURCE_DB_TRACE`, trace_args)) {
	_tracing = true;
      }
      _ready = true;
    }
  }
}
