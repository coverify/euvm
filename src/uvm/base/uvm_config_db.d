//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2010-2014 Mentor Graphics Corporation
// Copyright 2015 Analog Devices, Inc.
// Copyright 2014 Semifore
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2011-2012 AMD
// Copyright 2012-2018 NVIDIA Corporation
// Copyright 2014-2017 Cisco Systems, Inc.
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

// FIXME
// typedef class uvm_phase;

//----------------------------------------------------------------------
// Title -- NODOCS -- UVM Configuration Database
//
// Topic: Intro
//
// The <uvm_config_db> class provides a convenience interface
// on top of the <uvm_resource_db> to simplify the basic interface
// that is used for configuring <uvm_component> instances.
//
// If the run-time ~+UVM_CONFIG_DB_TRACE~ command line option is specified,
// all configuration DB accesses (read and write) are displayed.
//----------------------------------------------------------------------

//Internal class for config waiters

module uvm.base.uvm_config_db;

import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_factory: uvm_object_wrapper;
import uvm.base.uvm_object_globals: uvm_bitstream_t;
import uvm.base.uvm_resource: uvm_resource, uvm_resource_pool;
import uvm.base.uvm_resource_base:  uvm_resource_types, uvm_resource_base;
import uvm.base.uvm_scope;

import uvm.meta.misc;
import uvm.dpi.uvm_regex: uvm_re_match, uvm_glob_to_re;

import esdl.base.core;

import std.random: Random;

final private class m_uvm_waiter
{
  mixin (uvm_sync_string);
  @uvm_immutable_sync
  private string _inst_name;
  @uvm_immutable_sync
  private string _field_name;
  @uvm_immutable_sync
  private Event _trigger;
  this(string inst_name, string field_name) {
    synchronized (this) {
      _trigger.initialize("_trigger");
      _inst_name = inst_name;
      _field_name = field_name;
    }
  }

  final void wait_for_trigger() {
    trigger.wait();
  }

}

// typedef class uvm_config_db_options;


// @uvm-ieee 1800.2-2017 auto C.4.2.1
class uvm_config_db (T = int): uvm_resource_db!T
{
  
  import uvm.base.uvm_component: uvm_component;
  import uvm.base.uvm_pool: uvm_pool;
  import uvm.base.uvm_array: uvm_array;
  
  // This particular one can remain static even if here are multiple
  // instances of UVM. The idea is that uvm_component would be a
  // pointer/handle and therefor unique
  // Internal lookup of config settings so they can be reused
  // The context has a pool that is keyed by the inst/field name.

  // private __gshared uvm_pool!(string, uvm_resource!T)[uvm_component] _m_rsc;

  // singleton resources
  static class uvm_scope: uvm_scope_base
  {
    // Internal lookup of config settings so they can be reused
    // The context has a pool that is keyed by the inst/field name.
    @uvm_none_sync
    private uvm_pool!(string, uvm_resource!T)[uvm_component] _m_rsc;

    // Internal waiter list for wait_modified
    @uvm_none_sync
    private uvm_array!(m_uvm_waiter)[string] _m_waiters;
  }

  mixin (uvm_scope_sync_string);

  alias this_type = uvm_config_db!T;

  // function -- NODOCS -- get
  //
  // Get the value for ~field_name~ in ~inst_name~, using component ~cntxt~ as
  // the starting search point. ~inst_name~ is an explicit instance name
  // relative to ~cntxt~ and may be an empty string if the ~cntxt~ is the
  // instance that the configuration object applies to. ~field_name~
  // is the specific field in the scope that is being searched for.
  //
  // The basic ~get_config_*~ methods from <uvm_component> are mapped to
  // this function as:
  //
  //| get_config_int(...) => uvm_config_db!(uvm_bitstream_t).get(cntxt,...)
  //| get_config_string(...) => uvm_config_db!(string).get(cntxt,...)
  //| get_config_object(...) => uvm_config_db!(uvm_object).get(cntxt,...)

  // @uvm-ieee 1800.2-2017 auto C.4.2.2.2
  static bool get(uvm_component cntxt,
		  string inst_name,
		  string field_name,
		  ref T value) {
    import uvm.base.uvm_coreservice;
    //TBD: add file/line
    uvm_resource_pool rp = uvm_resource_pool.get();

    uvm_coreservice_t cs = uvm_coreservice_t.get();

    if (cntxt is null)
      cntxt = cs.get_root();
    if (inst_name == "")
      inst_name = cntxt.get_full_name();
    else if (cntxt.get_full_name() != "")
      inst_name = cntxt.get_full_name() ~ "." ~ inst_name;

    uvm_resource_types.rsrc_q_t rq =
      rp.lookup_regex_names(inst_name, field_name,
			    uvm_resource!(T).get_type());
    uvm_resource!T r = uvm_resource!(T).get_highest_precedence(rq);

    if (uvm_config_db_options.is_tracing())
      m_show_msg("CFGDB/GET", "Configuration","read",
		 inst_name, field_name, cntxt, r);

    if (r is null)
      return false;

    value = r.read(cntxt);

    return true;
  }

  // function -- NODOCS -- set
  //
  // Create a new or update an existing configuration setting for
  // ~field_name~ in ~inst_name~ from ~cntxt~.
  // The setting is made at ~cntxt~, with the full scope of the set
  // being {~cntxt~,".",~inst_name~}. If ~cntxt~ is ~null~ then ~inst_name~
  // provides the complete scope information of the setting.
  // ~field_name~ is the target field. Both ~inst_name~ and ~field_name~
  // may be glob style or regular expression style expressions.
  //
  // If a setting is made at build time, the ~cntxt~ hierarchy is
  // used to determine the setting's precedence in the database.
  // Settings from hierarchically higher levels have higher
  // precedence. Settings from the same level of hierarchy have
  // a last setting wins semantic. A precedence setting of
  // <uvm_resource_base.default_precedence>  is used for uvm_top, and
  // each hierarchical level below the top is decremented by 1.
  //
  // After build time, all settings use the default precedence and thus
  // have a last wins semantic. So, if at run time, a low level
  // component makes a runtime setting of some field, that setting
  // will have precedence over a setting from the test level that was
  // made earlier in the simulation.
  //
  // The basic ~set_config_*~ methods from <uvm_component> are mapped to
  // this function as:
  //
  //| set_config_int(...) => uvm_config_db!(uvm_bitstream_t).set(cntxt,...)
  //| set_config_string(...) => uvm_config_db!(string).set(cntxt,...)
  //| set_config_object(...) => uvm_config_db!(uvm_object).set(cntxt,...)

  // @uvm-ieee 1800.2-2017 auto C.4.2.2.1
  static void set(uvm_component cntxt,
		  string inst_name,
		  string field_name,
		  T value) {

    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_root;
    import esdl.base.core: Process;
    import uvm.base.uvm_phase;
    import uvm.base.uvm_globals;

    uvm_resource!T r;
    bool exists = false;

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_resource_pool rp = cs.get_resource_pool();
    uint precedence;
    
    // take care of random stability during allocation
    version (PRESERVE_RANDSTATE) {
      Random rstate;
      Process p = Process.self();
      if (p !is null)
	p.getRandState(rstate);
    }

    uvm_root top = cs.get_root();
    uvm_phase curr_phase = top.m_current_phase;


    if (cntxt is null)
      cntxt = top;
    if (inst_name == "")
      inst_name = cntxt.get_full_name();
    else if (cntxt.get_full_name() != "")
      inst_name = cntxt.get_full_name() ~ "." ~ inst_name;

    uvm_pool!(string, uvm_resource!T) pool;

    synchronized (_uvm_scope_inst) {
      if (cntxt !in _uvm_scope_inst._m_rsc) {
    	_uvm_scope_inst._m_rsc[cntxt] = new uvm_pool!(string, uvm_resource!T);
      }
      pool = _uvm_scope_inst._m_rsc[cntxt];
    }

    // Insert the token in the middle to prevent cache
    // oddities like i=foobar,f=xyz and i=foo,f=barxyz.
    // Can't just use '.', because '.' isn't illegal
    // in field names
    string lookup = inst_name ~ "__M_UVM__" ~ field_name;

    if (lookup !in pool) {
      r = new uvm_resource!T(field_name);
      rp.set_scope(r, inst_name);
      pool.add(lookup, r);
    }
    else {
      r = pool.get(lookup);
      exists = true;
    }

    if (curr_phase !is null && curr_phase.get_name() == "build")
      precedence = cs.get_resource_pool_default_precedence() - (cntxt.get_depth());
    else
      precedence = cs.get_resource_pool_default_precedence();

    rp.set_precedence(r, precedence);
    r.write(value, cntxt);

    rp.set_priority_name(r, uvm_resource_types.priority_e.PRI_HIGH);
    
    //trigger any waiters
    synchronized (_uvm_scope_inst) {
      if (field_name in _uvm_scope_inst._m_waiters) {
	m_uvm_waiter w;
	for (size_t i=0;
	     i < _uvm_scope_inst._m_waiters[field_name].length; ++i) {
	  w = _uvm_scope_inst._m_waiters[field_name].get(i);
	  if ( uvm_is_match(inst_name, w.inst_name) )
	    w.trigger.notify();  
	}
      }
    }

    version (PRESERVE_RANDSTATE) {
      if (p !is null) {
	p.setRandState(rstate);
      }
    }

    if (uvm_config_db_options.is_tracing())
      m_show_msg("CFGDB/SET", "Configuration","set",
		 inst_name, field_name, cntxt, r);
  }


  // function -- NODOCS -- exists
  //
  // Check if a value for ~field_name~ is available in ~inst_name~, using
  // component ~cntxt~ as the starting search point. ~inst_name~ is an explicit
  // instance name relative to ~cntxt~ and may be an empty string if the
  // ~cntxt~ is the instance that the configuration object applies to.
  // ~field_name~ is the specific field in the scope that is being searched for.
  // The ~spell_chk~ arg can be set to 1 to turn spell checking on if it
  // is expected that the field should exist in the database. The function
  // returns 1 if a config parameter exists and 0 if it doesn't exist.
  //

  // @uvm-ieee 1800.2-2017 auto C.4.2.2.3
  static bool exists(uvm_component cntxt, string inst_name,
		     string field_name, bool spell_chk = false) {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    if (cntxt is null)
      cntxt = cs.get_root();
    if (inst_name == "")
      inst_name = cntxt.get_full_name();
    else if (cntxt.get_full_name() != "") {
      inst_name = cntxt.get_full_name() ~ "." ~ inst_name;
    }
    return (uvm_resource_db!T.get_by_name(inst_name, field_name, spell_chk)
	    !is null);
  }

  // Function -- NODOCS -- wait_modified
  //
  // Wait for a configuration setting to be set for ~field_name~
  // in ~cntxt~ and ~inst_name~. The task blocks until a new configuration
  // setting is applied that effects the specified field.

  // @uvm-ieee 1800.2-2017 auto C.4.2.2.4
  // task
  static void wait_modified(uvm_component cntxt, string inst_name,
			    string field_name) {
    import uvm.base.uvm_array;
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();

    version (PRESERVE_RANDSTATE) {
      Process p = Process.self();
      Random rstate;
      p.getRandState(rstate);
    }

    if (cntxt is null)
      cntxt = cs.get_root();
    if (cntxt !is cs.get_root()) {
      if (inst_name != "")
	inst_name = cntxt.get_full_name() ~ "." ~ inst_name;
      else
	inst_name = cntxt.get_full_name();
    }

    m_uvm_waiter waiter = new m_uvm_waiter(inst_name, field_name);

    synchronized (_uvm_scope_inst) {
      if (field_name !in _uvm_scope_inst._m_waiters)
	_uvm_scope_inst._m_waiters[field_name] = new uvm_array!(m_uvm_waiter);
      _uvm_scope_inst._m_waiters[field_name].push_back(waiter);
    }


    version (PRESERVE_RANDSTATE) {
      p.setRandState(rstate);
    }
    // wait on the waiter to trigger
    waiter.wait_for_trigger();

    synchronized (_uvm_scope_inst) {
      // Remove the waiter from the waiter list
      for (size_t i = 0;
	   i < _uvm_scope_inst._m_waiters[field_name].length; ++i) {
	if (_uvm_scope_inst._m_waiters[field_name].get(i) is waiter) {
	  _uvm_scope_inst._m_waiters[field_name].remove(i);
	  break;
	}
      }
    }
  }

}

// Section -- NODOCS -- Types

//----------------------------------------------------------------------
// Topic -- NODOCS -- uvm_config_int
//
// Convenience type for uvm_config_db#(uvm_bitstream_t)
//
//| typedef uvm_config_db#(uvm_bitstream_t) uvm_config_int;

/* @uvm-ieee 1800.2-2017 auto C.4.2.3.1*/
alias uvm_config_int = uvm_config_db!uvm_bitstream_t;

//----------------------------------------------------------------------
// Topic -- NODOCS -- uvm_config_string
//
// Convenience type for uvm_config_db#(string)
//
//| typedef uvm_config_db#(string) uvm_config_string;

/* @uvm-ieee 1800.2-2017 auto C.4.2.3.2*/ 
alias uvm_config_string = uvm_config_db!string;

//----------------------------------------------------------------------
// Topic -- NODOCS -- uvm_config_object
//
// Convenience type for uvm_config_db#(uvm_object)
//
//| typedef uvm_config_db#(uvm_object) uvm_config_object;

/* @uvm-ieee 1800.2-2017 auto C.4.2.3.3*/
alias uvm_config_object = uvm_config_db!uvm_object;

//----------------------------------------------------------------------
// Topic -- NODOCS -- uvm_config_wrapper
//
// Convenience type for uvm_config_db#(uvm_object_wrapper)
//
//| typedef uvm_config_db#(uvm_object_wrapper) uvm_config_wrapper;

/* @uvm-ieee 1800.2-2017 auto C.4.2.3.4*/
alias uvm_config_wrapper = uvm_config_db!uvm_object_wrapper;


//----------------------------------------------------------------------
// class: uvm_config_db_options
//
// This class contains static functions for manipulating and
// retrieving options that control the behavior of the 
// configuration DB facility.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
//----------------------------------------------------------------------
package class uvm_config_db_options
{
  import uvm.base.uvm_cmdline_processor: uvm_cmdline_processor;

  static class uvm_scope: uvm_scope_base
  {
    private bool _ready;
    private bool _tracing;
  }


  mixin (uvm_scope_sync_string);

  // Function: turn_on_tracing
  //
  // Turn tracing on for the configuration database. This causes all
  // reads and writes to the database to display information about
  // the accesses. Tracing is off by default.
  //
  // This method is implicitly called by the ~+UVM_CONFIG_DB_TRACE~.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  static void turn_on_tracing() {
    synchronized (_uvm_scope_inst) {
      if (!_uvm_scope_inst._ready) init_trace();
      _uvm_scope_inst._tracing = true;
    }
  }

  // Function: turn_off_tracing
  //
  // Turn tracing off for the configuration database.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  static void turn_off_tracing() {
    synchronized (_uvm_scope_inst) {
      if (!_uvm_scope_inst._ready) init_trace();
      _uvm_scope_inst._tracing = false;
    }
  }

  // Function: is_tracing
  //
  // Returns 1 if the tracing facility is on and 0 if it is off.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  static bool is_tracing() {
    synchronized (_uvm_scope_inst) {
      if (!_uvm_scope_inst._ready) init_trace();
      return _uvm_scope_inst._tracing;
    }
  }


  static private void init_trace() {
    synchronized (_uvm_scope_inst) {
      string[] trace_args;

      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();

      if (clp.get_arg_matches(`\+UVM_CONFIG_DB_TRACE`, trace_args)) {
	_uvm_scope_inst._tracing = true;
      }
      _uvm_scope_inst._ready = true;
    }
  }

}
