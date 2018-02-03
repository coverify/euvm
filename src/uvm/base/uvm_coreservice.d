//----------------------------------------------------------------------
//   Copyright 2013 Cadence Design Inc
//   Copyright 2016 Coverify Systems Technology
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

module uvm.base.uvm_coreservice;

import uvm.base.uvm_root;
import uvm.base.uvm_factory;
import uvm.base.uvm_report_server;
import uvm.base.uvm_traversal;
import uvm.base.uvm_component;
import uvm.base.uvm_tr_database;
import uvm.base.uvm_entity;
import uvm.base.uvm_once;

import esdl.base.core: Process;
import std.random: Random;

//----------------------------------------------------------------------
// Class: uvm_coreservice_t
//
// The singleton instance of uvm_coreservice_t provides a common point for all central
// uvm services such as uvm_factory, uvm_report_server, ...
// The service class provides a static <::get> which returns an instance adhering to uvm_coreservice_t
// the rest of the set_<facility> get_<facility> pairs provide access to the internal uvm services
//
// Custom implementations of uvm_coreservice_t can be included in uvm_pkg::*
// and can selected via the define UVM_CORESERVICE_TYPE. They cannot reside in another package.
//----------------------------------------------------------------------

abstract class uvm_coreservice_t
{
  import uvm.base.uvm_root;
  static class uvm_once: uvm_once_base
  {
    @uvm_immutable_sync
    private uvm_coreservice_t _inst;
    this() {
      synchronized(this) {
	_inst = new uvm_default_coreservice_t;
      }
    }
  }

  mixin(uvm_once_sync_string);

  // Function: get_factory
  //
  // intended to return the currently enabled uvm factory,
  abstract uvm_factory get_factory();

  // Function: set_factory
  //
  // intended to set the current uvm factory
  abstract void set_factory(uvm_factory f);

  // Function: get_report_server
  // intended to return the current global report_server
  abstract uvm_report_server get_report_server();

  // Function: set_report_server
  // intended to set the central report server to ~server~
  abstract void set_report_server(uvm_report_server server);

  // Function: get_default_tr_database
  // intended to return the current default record database
  abstract uvm_tr_database get_default_tr_database();

  // Function: set_default_tr_database
  // intended to set the current default record database to ~db~
  //
  abstract void set_default_tr_database(uvm_tr_database db);

  // Function: set_component_visitor
  // intended to set the component visitor to ~v~
  // (this visitor is being used for the traversal at end_of_elaboration_phase
  // for instance for name checking)
  abstract void set_component_visitor(uvm_visitor!(uvm_component) v);

  // Function: get_component_visitor
  // intended to retrieve the current component visitor
  // see <set_component_visitor>
  abstract uvm_visitor!(uvm_component) get_component_visitor();

  // Function: get_root
  //
  // returns the uvm_root instance
  abstract uvm_root get_root();

  // moved to once
  // local static `UVM_CORESERVICE_TYPE inst;

  // Function: get
  //
  // Returns an instance providing the uvm_coreservice_t interface.
  // The actual type of the instance is determined by the define `UVM_CORESERVICE_TYPE.
  //
  //| `define UVM_CORESERVICE_TYPE uvm_blocking_coreservice
  //| class uvm_blocking_coreservice extends uvm_default_coreservice_t;
  //|    virtual function void set_factory(uvm_factory f);
  //|       `uvm_error("FACTORY","you are not allowed to override the factory")
  //|    endfunction
  //| endclass
  //|
  static uvm_coreservice_t get() {
    return inst;
  }

}

//----------------------------------------------------------------------
// Class: uvm_default_coreservice_t
//
// uvm_default_coreservice_t provides a default implementation of the
// uvm_coreservice_t API. It instantiates uvm_default_factory, uvm_default_report_server,
// uvm_root.
//----------------------------------------------------------------------
class uvm_default_coreservice_t: uvm_coreservice_t
{
  // this() {
  //   synchronized(this) {
  //     _factory = new uvm_default_factory();
  //   }
  // }

  private uvm_factory _factory;

  // Function: get_factory
  //
  // Returns the currently enabled uvm factory.
  // When no factory has been set before, instantiates a uvm_default_factory
  override uvm_factory get_factory() {
    synchronized(this) {
      if(_factory is null) {
	_factory = new uvm_default_factory();
      }
      return _factory;
    }
  }

  // Function: set_factory
  //
  // Sets the current uvm factory.
  // Please note: it is up to the user to preserve the contents of the original factory or delegate calls to the original factory
  override void set_factory(uvm_factory f) {
    synchronized(this) {
      _factory = f;
    }
  }

  private uvm_tr_database _tr_database;
  // Function: get_default_tr_database
  // returns the current default record database
  //
  // If no default record database has been set before this method
  // is called, returns an instance of <uvm_text_tr_database>
  override uvm_tr_database get_default_tr_database() {
    synchronized(this) {
      if (_tr_database is null) {
	Process p = Process.self();
	Random s;
	if(p !is null) {
	  p.getRandState(s);
	}
	_tr_database = new uvm_text_tr_database("default_tr_database");
	if(p !is null) {
	  p.setRandState(s);
	}
      }
      return _tr_database;
    }
  }

  // Function: set_default_tr_database
  // Sets the current default record database to ~db~
  override void set_default_tr_database(uvm_tr_database db) {
    synchronized(this) {
      _tr_database = db;
    }
  }

  private uvm_report_server _report_server;
  // Function: get_report_server
  // returns the current global report_server
  // if no report server has been set before, returns an instance of
  // uvm_default_report_server
  override uvm_report_server get_report_server() {
    synchronized(this) {
      if(_report_server is null) {
	_report_server = new uvm_default_report_server();
      }
      return _report_server;
    }
  }

  // Function: set_report_server
  // sets the central report server to ~server~
  override void set_report_server(uvm_report_server server) {
    synchronized(this) {
      _report_server = server;
    }
  }

  override uvm_root get_root() {
    return uvm_root.m_uvm_get_root();
  }

  private uvm_visitor!(uvm_component) _visitor;
  // Function: set_component_visitor
  // sets the component visitor to ~v~
  // (this visitor is being used for the traversal at end_of_elaboration_phase
  // for instance for name checking)
  override void set_component_visitor(uvm_visitor!(uvm_component) v) {
    synchronized(this) {
      _visitor = v;
    }
  }

  // Function: get_component_visitor
  // retrieves the current component visitor
  // if unset(or ~null~) returns a <uvm_component_name_check_visitor> instance
  override uvm_visitor!(uvm_component) get_component_visitor() {
    synchronized(this) {
      if(_visitor is null) {
	_visitor = new uvm_component_name_check_visitor("name-check-visitor");
      }
      return _visitor;
    }
  }
}
