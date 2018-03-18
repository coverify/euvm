//----------------------------------------------------------------------
//   Copyright 2011      Cypress Semiconductor
//   Copyright 2010-2011 Mentor Graphics Corporation
//   Copyright 2014      NVIDIA Corporation
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

// FIXME
// typedef class uvm_phase;

//----------------------------------------------------------------------
// Title: UVM Configuration Database
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

import uvm.base.uvm_component;
import uvm.base.uvm_phase;
import uvm.base.uvm_pool;
import uvm.base.uvm_resource_db;
import uvm.base.uvm_resource;
import uvm.base.uvm_array;
import uvm.base.uvm_root;
import uvm.base.uvm_entity;
import uvm.base.uvm_once;
import uvm.base.uvm_globals;
import uvm.base.uvm_factory;	// uvm_object_wrapper
import uvm.meta.misc;
import uvm.base.uvm_object;
import uvm.base.uvm_entity;
import uvm.base.uvm_object_globals;

import esdl.base.core;

import std.random: Random;

final private class m_uvm_waiter
{
  mixin(uvm_sync_string);
  @uvm_immutable_sync
  private string _inst_name;
  // _field_name is present in the SV version but is not used
  // private string _field_name;
  @uvm_immutable_sync
  private Event _trigger;
  this(string inst_name) { // , string field_name
    synchronized(this) {
      _trigger.initialize("_trigger");
      _inst_name = inst_name;
      // _field_name = field_name;
    }
  }

  final void wait_for_trigger() {
    trigger.wait();
  }

}

// typedef class uvm_config_db_options;

// singleton resources

// In SV, each uvm_config_db template class instance would have a
// separate _m_waiters instance. It is really not required since the
// string KEY is going to be unique for every field_name irrespective
// of the type of the field.
  class uvm_once_config_db: uvm_once_base
{
  // Internal waiter list for wait_modified
  private uvm_array!(m_uvm_waiter)[string] _m_waiters;
}

//----------------------------------------------------------------------
// class: uvm_config_db
//
// All of the functions in uvm_config_db#(T) are static, so they
// must be called using the . operator.  For example:
//
//|  uvm_config_db#(int).set(this, "*", "A");
//
// The parameter value "int" identifies the configuration type as
// an int property.
//
// The <set> and <get> methods provide the same API and
// semantics as the set/get_config_* functions in <uvm_component>.
//----------------------------------------------------------------------

mixin(uvm_once_sync_string!(uvm_once_config_db, "uvm_config_db"));

class uvm_config_db (T = int): uvm_resource_db!T
{

  // This particular one can remain static even if here are multiple
  // instances of UVM. The idea is that uvm_component would be a
  // pointer/handle and therefor unique
  // Internal lookup of config settings so they can be reused
  // The context has a pool that is keyed by the inst/field name.

  // private __gshared uvm_pool!(string, uvm_resource!T)[uvm_component] _m_rsc;

  static class uvm_once: uvm_once_base
  {
    @uvm_immutable_sync
    private uvm_pool!(string, uvm_resource!T) _m_rsc;
    this() {
      synchronized(this) {
	_m_rsc = new uvm_pool!(string, uvm_resource!T);
      }
    }
  }

  mixin(uvm_once_sync_string);

  alias this_type = uvm_config_db!T;

  // function: get
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

  static bool get(uvm_component cntxt,
		  string inst_name,
		  string field_name,
		  ref T value) {
    import uvm.base.uvm_coreservice;
    //TBD: add file/line
    uvm_resource_pool rp = uvm_resource_pool.get();

    uvm_coreservice_t cs = uvm_coreservice_t.get();

    if(cntxt is null) {
      cntxt = cs.get_root();
    }
    if(inst_name == "") {
      inst_name = cntxt.get_full_name();
    }
    else if(cntxt.get_full_name() != "") {
      inst_name = cntxt.get_full_name() ~ "." ~ inst_name;
    }

    uvm_resource_types.rsrc_q_t rq =
      rp.lookup_regex_names(inst_name, field_name,
			    uvm_resource!(T).get_type());
    uvm_resource!T r = uvm_resource!(T).get_highest_precedence(rq);

    if(uvm_config_db_options.is_tracing()) {
      m_show_msg("CFGDB/GET", "Configuration","read",
		 inst_name, field_name, cntxt, r);
    }

    if(r is null) {
      return false;
    }

    value = r.read(cntxt);

    return true;
  }

  // function: set
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

  static void set(uvm_component cntxt,
		  string inst_name,
		  string field_name,
		  T value) {
    import uvm.base.uvm_coreservice;
    import esdl.base.core: Process;

    uvm_resource!T r;
    bool exists = false;
    // uvm_pool!(string, uvm_resource!T) pool;
    Random rstate;

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    // take care of random stability during allocation
    Process p = Process.self();

    if(p !is null) {
      p.getRandState(rstate);
    }
    uvm_root top = cs.get_root();
    uvm_phase curr_phase = top.m_current_phase;


    if(cntxt is null) {
      cntxt = top;
    }
    if(inst_name == "") {
      inst_name = cntxt.get_full_name();
    }
    else if(cntxt.get_full_name() != "") {
      inst_name = cntxt.get_full_name() ~ "." ~ inst_name;
    }

    // synchronized(typeid(this_type)) {
    //   auto prsc = cntxt in _m_rsc;
    //   if(prsc !is null) {
    // 	pool = *prsc;
    //   }
    //   else {
    // 	pool = new uvm_pool!(string, uvm_resource!T);
    // 	_m_rsc[cntxt] = pool;
    //   }
    // }

    // Insert the token in the middle to prevent cache
    // oddities like i=foobar,f=xyz and i=foo,f=barxyz.
    // Can't just use '.', because '.' isn't illegal
    // in field names
    string lookup = inst_name ~ "__M_UVM__" ~ field_name;

    if(lookup !in m_rsc) {
      r = new uvm_resource!T(field_name, inst_name);
      m_rsc.add(lookup, r);
    }
    else {
      r = m_rsc.get(lookup);
      exists = true;
    }

    if(curr_phase !is null && curr_phase.get_name() == "build") {
      r.precedence = uvm_resource_base.default_precedence - (cntxt.get_depth());
    }
    else {
      r.precedence = uvm_resource_base.default_precedence;
    }

    r.write(value, cntxt);

    if(exists) {
      uvm_resource_pool rp = uvm_resource_pool.get();
      rp.set_priority_name(r, uvm_resource_types.PRI_HIGH);
    }
    else {
      //Doesn't exist yet, so put it in resource db at the head.
      r.set_override();
    }

    synchronized(uvm_config_db_uvm_once) {
      //trigger any waiters
      if(field_name in _m_waiters) {
	m_uvm_waiter w;
	for(int i = 0; i < _m_waiters[field_name].size(); ++i) {
	  w = _m_waiters[field_name].get(i);
	  if(uvm_re_match(uvm_glob_to_re(inst_name), w.inst_name) == 0) {
	    w.trigger.notify();
	  }
	}
      }
    }

    if(p !is null) {
      p.setRandState(rstate);
    }

    if(uvm_config_db_options.is_tracing()) {
      m_show_msg("CFGDB/SET", "Configuration","set", inst_name, field_name, cntxt, r);
    }
  }


  // function: exists
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

  static bool exists(uvm_component cntxt, string inst_name,
		     string field_name, bool spell_chk = false) {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    if(cntxt is null) {
      cntxt = cs.get_root();
    }
    if(inst_name == "") {
      inst_name = cntxt.get_full_name();
    }
    else if(cntxt.get_full_name() != "") {
      inst_name = cntxt.get_full_name() ~ "." ~ inst_name;
    }
    return (uvm_resource_db!T.get_by_name(inst_name, field_name, spell_chk)
	    !is null);
  }

  // Function: wait_modified
  //
  // Wait for a configuration setting to be set for ~field_name~
  // in ~cntxt~ and ~inst_name~. The task blocks until a new configuration
  // setting is applied that effects the specified field.

  // task
  static void wait_modified(uvm_component cntxt, string inst_name,
			    string field_name) {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    Process p = Process.self();
    Random rstate;
    p.getRandState(rstate);

    if(cntxt is null) {
      cntxt = cs.get_root();
    }
    if(cntxt !is cs.get_root()) {
      if(inst_name != "") {
	inst_name = cntxt.get_full_name() ~ "." ~ inst_name;
      }
      else {
	inst_name = cntxt.get_full_name();
      }
    }

    m_uvm_waiter waiter = new m_uvm_waiter(inst_name);

    synchronized(uvm_config_db_uvm_once) {
      if(field_name !in _m_waiters) {
	_m_waiters[field_name] = new uvm_array!(m_uvm_waiter);
      }
      _m_waiters[field_name].push_back(waiter);
    }


    p.setRandState(rstate);
    // wait on the waiter to trigger
    waiter.wait_for_trigger();

    synchronized(uvm_config_db_uvm_once) {
      // Remove the waiter from the waiter list
      for(int i = 0; i < _m_waiters[field_name].size(); ++i) {
	if(_m_waiters[field_name].get(i) is waiter) {
	  _m_waiters[field_name].remove(i);
	  break;
	}
      }
    }
  }

}

// Section: Types

//----------------------------------------------------------------------
// Topic: uvm_config_int
//
// Convenience type for uvm_config_db#(uvm_bitstream_t)
//
//| typedef uvm_config_db#(uvm_bitstream_t) uvm_config_int;
alias uvm_config_int = uvm_config_db!uvm_bitstream_t;

//----------------------------------------------------------------------
// Topic: uvm_config_string
//
// Convenience type for uvm_config_db#(string)
//
//| typedef uvm_config_db#(string) uvm_config_string;
alias uvm_config_string = uvm_config_db!string;

//----------------------------------------------------------------------
// Topic: uvm_config_object
//
// Convenience type for uvm_config_db#(uvm_object)
//
//| typedef uvm_config_db#(uvm_object) uvm_config_object;
alias uvm_config_object = uvm_config_db!uvm_object;

//----------------------------------------------------------------------
// Topic: uvm_config_wrapper
//
// Convenience type for uvm_config_db#(uvm_object_wrapper)
//
//| typedef uvm_config_db#(uvm_object_wrapper) uvm_config_wrapper;

alias uvm_config_wrapper = uvm_config_db!uvm_object_wrapper;


//----------------------------------------------------------------------
// Class: uvm_config_db_options
//
// Provides a namespace for managing options for the
// configuration DB facility.  The only thing allowed in this class is static
// local data members and static functions for manipulating and
// retrieving the value of the data members.  The static local data
// members represent options and settings that control the behavior of
// the configuration DB facility.

// Options include:
//
//  * tracing:  on/off
//
//    The default for tracing is off.
//
//----------------------------------------------------------------------
// singleton resources
package class uvm_config_db_options
{
  import uvm.base.uvm_cmdline_processor;

  static class uvm_once: uvm_once_base
  {
    private bool _ready;
    private bool _tracing;
  }


  mixin(uvm_once_sync_string);

  // Function: turn_on_tracing
  //
  // Turn tracing on for the configuration database. This causes all
  // reads and writes to the database to display information about
  // the accesses. Tracing is off by default.
  //
  // This method is implicitly called by the ~+UVM_CONFIG_DB_TRACE~.

  static void turn_on_tracing() {
    synchronized(once) {
      if (!once._ready) {
	init_trace();
      }
      once._tracing = true;
    }
  }

  // Function: turn_off_tracing
  //
  // Turn tracing off for the configuration database.

  static void turn_off_tracing() {
    synchronized(once) {
      if (!once._ready) {
	init_trace();
      }
      once._tracing = false;
    }
  }

  // Function: is_tracing
  //
  // Returns 1 if the tracing facility is on and 0 if it is off.

  static bool is_tracing() {
    synchronized(once) {
      if (!once._ready) {
	init_trace();
      }
      return once._tracing;
    }
  }


  static private void init_trace() {
    synchronized(once) {
      string[] trace_args;

      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();

      if (clp.get_arg_matches(`\+UVM_CONFIG_DB_TRACE`, trace_args)) {
	once._tracing = true;
      }
      once._ready = true;
    }
  }

}
