//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2010-2011 Paradigm Works
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2015 Analog Devices, Inc.
// Copyright 2017 Intel Corporation
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2011 AMD
// Copyright 2014-2018 NVIDIA Corporation
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2011 Cypress Semiconductor Corp.
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
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Title -- NODOCS --  UVM Resource Database
//
// Topic -- NODOCS --  Intro
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

import uvm.base.uvm_resource: uvm_resource, uvm_resource_pool;
import uvm.base.uvm_resource_base: uvm_resource_types, uvm_resource_base;
import uvm.base.uvm_resource_db_options: uvm_resource_db_options;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_globals: uvm_warning;

import uvm.base.uvm_once;

import uvm.meta.misc;

import esdl.data.queue;

import std.string;

// Class: uvm_resource_db
// Implementation of uvm_resource_db, as defined in section
// C.3.2.1 of 1800.2-2017.
//
//| class uvm_resource_db#(type T=uvm_object)
  
// @uvm-ieee 1800.2-2017 auto C.3.2.1
class uvm_resource_db (T=uvm_object)
{

  alias rsrc_t = uvm_resource!T;

  protected this() { }

  // function -- NODOCS --  get_by_type
  //
  // Get a resource by type.  The type is specified in the db
  // class parameter so the only argument to this function is the
  // ~scope~.

  // @uvm-ieee 1800.2-2017 auto C.3.2.2.5
  static rsrc_t get_by_type(string rscope) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    uvm_resource_base type_handle = rsrc_t.get_type();

    if (type_handle is null)
      return null;

    uvm_resource_base rsrc_base = rp.get_by_type(rscope, type_handle);
    rsrc_t rsrc = cast (rsrc_t) rsrc_base;
    if (rsrc is null) {
      string msg =
	format("Resource with specified type handle in scope " ~
	       "%s was not located", rscope);
      uvm_warning("RSRCNF", msg);
      return null;
    }
    return rsrc;
  }

  // function -- NODOCS --  get_by_name
  //
  // Imports a resource by ~name~.  The first argument is the ~name~ of the
  // resource to be retrieved and the second argument is the current
  // ~scope~. The ~rpterr~ flag indicates whether or not to generate
  // a warning if no matching resource is found.

  // @uvm-ieee 1800.2-2017 auto C.3.2.2.4
  static rsrc_t get_by_name(string rscope,
			    string name,
			    bool rpterr = true) {
    uvm_resource_pool rp = uvm_resource_pool.get();

    uvm_resource_base rsrc_base =
      rp.get_by_name(rscope, name, rsrc_t.get_type(), rpterr);

    if (rsrc_base is null)
      return null;

    rsrc_t rsrc = cast (rsrc_t) rsrc_base;
    if (rsrc is null) {
      if (rpterr) {
	string msg = format("Resource with name %s in scope " ~
			    "%s has incorrect type",
			    name, rscope);
	uvm_warning("RSRCTYPE", msg);
      }
      return null;
    }
    return rsrc;
  }

  // function -- NODOCS --  set_default
  //
  // add a new item into the resources database.  The item will not be
  // written to so it will have its default value. The resource is
  // created using ~name~ and ~scope~ as the lookup parameters.

  // @uvm-ieee 1800.2-2017 auto C.3.2.2.2
  static rsrc_t set_default(string rscope, string name) {
    uvm_resource_pool rp = uvm_resource_pool.get();

    rsrc_t r = new rsrc_t(name);
    rp.set_scope(r, rscope);
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
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    string msg = format("%s scope='%s' name='%s' (type %s) %s accessor=%s = %s",
			rtype, rscope, name, T.stringof, action,
			(accessor !is null) ? accessor.get_full_name() :
			"<unknown>", rsrc is null ?
			"null (failed lookup)" : rsrc.convert2string());
    uvm_info(id, msg, uvm_verbosity.UVM_LOW);
  }


  // @uvm-ieee 1800.2-2017 auto C.3.2.2.1
  static void set(string rscope, string name,
		  T val, uvm_object accessor = null) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    rsrc_t rsrc = new rsrc_t(name);
    rsrc.write(val, accessor);
    rp.set_scope(rsrc, rscope);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/SET", "Resource", "set", rscope, name, accessor, rsrc);
  }


  // @uvm-ieee 1800.2-2017 auto C.3.2.2.3
  static void set_anonymous(string rscope,
			    T val, uvm_object accessor = null) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    rsrc_t rsrc = new rsrc_t("");
    rsrc.write(val, accessor);
    rp.set_scope(rsrc, rscope);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/SETANON","Resource", "set", rscope, "", accessor, rsrc);
  }

  // function set_override
  //
  // Create a new resource, write ~val~ to it, and set it into the
  // database.  Set it at the beginning of the queue in the type map and
  // the name map so that it will be (currently) the highest priority
  // resource with the specified name and type.

  static void set_override(string rscope, string name,
			   T val, uvm_object accessor = null) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    rsrc_t rsrc = new rsrc_t(name);
    rsrc.write(val, accessor);
    rp.set_override(rsrc, rscope);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/SETOVRD", "Resource","set", rscope, name,
		 accessor, rsrc);
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
    uvm_resource_pool rp = uvm_resource_pool.get();
    rsrc_t rsrc = new rsrc_t(name);
    rsrc.write(val, accessor);
    rp.set_type_override(rsrc, rscope);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/SETOVRDTYP","Resource", "set", rscope, name,
		 accessor, rsrc);
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
    uvm_resource_pool rp = uvm_resource_pool.get();
    rsrc_t rsrc = new rsrc_t(name);
    rsrc.write(val, accessor);
    rp.set_name_override(rsrc, rscope);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/SETOVRDNAM","Resource", "set", rscope, name,
		 accessor, rsrc);
  }


  // function -- NODOCS --  read_by_name
  //
  // Locates a resource by name and scope and reads its value. The value is returned through the inout argument
  // val. The return value is a bit that indicates whether or not the read was successful. The accessor is available
  // for an implementation to use for debug purposes only; its value shall have no functional effect on outcome
  // of this method.
  //
  // *Note:*  This function deviates from IEEE 1800.2-2017 LRM as it defines the ~val~ argument as inout, 
  // whereas the LRM defines it as an output.
  //
  //|   static function bit read_by_name(input string scope,
  //|                                    input string name,
  //|                                    inout T val, 
  //|                                    input uvm_object accessor = null);
  //
  //  The implementation treats the argument as inout for cases where a read may fail 
  //  and the value will not change from its original supplied value.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto C.3.2.2.6
  static bool read_by_name(string rscope,
			   string name,
			   ref T val, uvm_object accessor = null) {
    rsrc_t rsrc = get_by_name(rscope, name);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/RDBYNAM","Resource", "read", rscope, name,
		 accessor, rsrc);

    if (rsrc is null)
      return false;

    val = rsrc.read(accessor);

    return true;
  }

  // function -- NODOCS --  read_by_type
  //
  // Reads a value by type. The value is returned through the inout argument val. The scope is used for the
  // lookup. The return value is a bit that indicates whether or not the read is successful. The accessor is
  // available for an implementation to use for debug purposes only; its value shall have no functional effect on
  // outcome of this method.
  // 
  // *Note:* This function deviates from IEEE 1800.2-2017 LRM as it defines the <val> argument as inout, whereas the
  // LRM defines it as an output.
  //
  //|    static function bit read_by_type(input string scope,
  //|                                     inout T val,
  //|                                     input uvm_object accessor = null);
  //
  // The implementation treats the argument as inout for cases where a read may fail 
  // and the value will not change from its original supplied value.
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2

  // @uvm-ieee 1800.2-2017 auto C.3.2.2.7
  static bool read_by_type(string rscope,
			   ref T val,
			   uvm_object accessor = null) {
    rsrc_t rsrc = get_by_type(rscope);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/RDBYTYP", "Resource","read", rscope, "",
		 accessor, rsrc);

    if (rsrc is null)
      return false;

    val = rsrc.read(accessor);

    return true;
  }


  // @uvm-ieee 1800.2-2017 auto C.3.2.2.8
  static bool write_by_name(string rscope, string name,
			    T val, uvm_object accessor = null) {
    rsrc_t rsrc = get_by_name(rscope, name);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/WR","Resource", "written", rscope, name,
		 accessor, rsrc);

    if (rsrc is null)
      return false;

    rsrc.write(val, accessor);

    return true;
  }


  // @uvm-ieee 1800.2-2017 auto C.3.2.2.9
  static bool write_by_type(string rscope,
			    T val, uvm_object accessor = null) {
    rsrc_t rsrc = get_by_type(rscope);

    if (uvm_resource_db_options.is_tracing())
      m_show_msg("RSRCDB/WRTYP", "Resource","written", rscope, "",
		 accessor, rsrc);

    if (rsrc is null)
      return false;

    rsrc.write(val, accessor);

    return true;
  }

  // function -- NODOCS --  dump
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
