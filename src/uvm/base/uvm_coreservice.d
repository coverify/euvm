//----------------------------------------------------------------------
// Copyright 2016-2021 Coverify Systems Technology
// Copyright 2015 Analog Devices, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2014-2017 Cisco Systems, Inc.
// Copyright 2018 Intel Corporation
// Copyright 2014-2018 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2018 Synopsys, Inc.
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

module uvm.base.uvm_coreservice;

import uvm.base.uvm_factory: uvm_factory, uvm_default_factory;
import uvm.base.uvm_report_server: uvm_report_server, uvm_default_report_server;
import uvm.base.uvm_traversal: uvm_visitor, uvm_component_name_check_visitor;
import uvm.base.uvm_tr_database: uvm_tr_database;
import uvm.base.uvm_text_tr_database: uvm_text_tr_database;
import uvm.base.uvm_root: uvm_root;
import uvm.base.uvm_component: uvm_component;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_resource: uvm_resource_pool;
import uvm.base.uvm_copier: uvm_copier;
import uvm.base.uvm_entity: uvm_entity_base;
import uvm.base.uvm_scope;

import uvm.meta.misc;

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

// @uvm-ieee 1800.2-2020 auto F.4.1.1
abstract class uvm_coreservice_t
{
  import uvm.base.uvm_printer: uvm_printer, uvm_table_printer;
  import uvm.base.uvm_comparer: uvm_comparer;
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    private uvm_coreservice_t _inst;
    
    @uvm_immutable_sync
    private uint _m_uvm_global_seed;

    this() {
      synchronized (this) {
	_inst = new uvm_default_coreservice_t;
	_m_uvm_global_seed = uvm_entity_base.get().get_seed;
      }
    }
  }

  mixin (uvm_scope_sync_string);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.2
  abstract uvm_factory get_factory();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.3
  abstract void set_factory(uvm_factory f);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.4
  abstract uvm_report_server get_report_server();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.5
  abstract void set_report_server(uvm_report_server server);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.6
  abstract uvm_tr_database get_default_tr_database();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.7
  abstract void set_default_tr_database(uvm_tr_database db);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.9
  abstract void set_component_visitor(uvm_visitor!(uvm_component) v);

  abstract uvm_visitor!(uvm_component) get_component_visitor();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.1
  abstract uvm_root get_root();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.10
  abstract void set_phase_max_ready_to_end(int max);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.11
  abstract int get_phase_max_ready_to_end();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.12
  abstract void set_default_printer(uvm_printer printer);
    
  // @uvm-ieee 1800.2-2020 auto F.4.1.4.13
  abstract uvm_printer get_default_printer();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.14
  abstract void set_default_packer(uvm_packer packer);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.15
  abstract uvm_packer get_default_packer();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.16
  abstract void set_default_comparer(uvm_comparer comparer);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.17
  abstract uvm_comparer get_default_comparer();

  abstract uint get_global_seed();


  // @uvm-ieee 1800.2-2020 auto F.4.1.4.18
  abstract void set_default_copier(uvm_copier copier);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.19
  abstract uvm_copier get_default_copier();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.25
  abstract bool get_uvm_seeding();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.26
  abstract void set_uvm_seeding(bool enable);
   
  // @uvm-ieee 1800.2-2020 auto F.4.1.4.21
  abstract void set_resource_pool (uvm_resource_pool pool);

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.22
  abstract uvm_resource_pool get_resource_pool();

  // @uvm-ieee 1800.2-2020 auto F.4.1.4.23
  abstract void set_resource_pool_default_precedence(uint precedence);

  abstract uint get_resource_pool_default_precedence();

  // moved to once
  // local static `UVM_CORESERVICE_TYPE inst;

  // @uvm-ieee 1800.2-2020 auto F.4.1.3
  static uvm_coreservice_t get() {
    return inst;
  }

  // static void set(uvm_coreservice_t cs) {
  //   m_inst = cs;
  // }
}

//----------------------------------------------------------------------
// Class: uvm_default_coreservice_t
//
// uvm_default_coreservice_t provides a default implementation of the
// uvm_coreservice_t API. It instantiates uvm_default_factory, uvm_default_report_server,
// uvm_root.
//----------------------------------------------------------------------
 
// @uvm-ieee 1800.2-2020 auto F.4.2.1
class uvm_default_coreservice_t: uvm_coreservice_t
{
  import uvm.base.uvm_printer: uvm_printer, uvm_table_printer;
  import uvm.base.uvm_comparer: uvm_comparer;
  // this() {
  //   synchronized (this) {
  //     _factory = new uvm_default_factory();
  //   }
  // }

  private uvm_factory _factory;

  // Function: get_factory
  //
  // Returns the currently enabled uvm factory.
  // When no factory has been set before, instantiates a uvm_default_factory
  override uvm_factory get_factory() {
    synchronized (this) {
      if (_factory is null) {
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
    synchronized (this) {
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
    import esdl.base.core: Process;
    synchronized (this) {
      if (_tr_database is null) {

	_tr_database = new uvm_text_tr_database("default_tr_database");

	version (PRESERVE_RANDSTATE) {
	  if (p !is null)
	    p.setRandState(s);
	}
      }
      return _tr_database;
    }
  }

  // Function: set_default_tr_database
  // Sets the current default record database to ~db~
  override void set_default_tr_database(uvm_tr_database db) {
    synchronized (this) {
      _tr_database = db;
    }
  }

  private uvm_report_server _report_server;
  // Function: get_report_server
  // returns the current global report_server
  // if no report server has been set before, returns an instance of
  // uvm_default_report_server
  override uvm_report_server get_report_server() {
    synchronized (this) {
      if (_report_server is null) {
	_report_server = new uvm_default_report_server();
      }
      return _report_server;
    }
  }

  // Function: set_report_server
  // sets the central report server to ~server~
  override void set_report_server(uvm_report_server server) {
    synchronized (this) {
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
    synchronized (this) {
      _visitor = v;
    }
  }

  // Function: get_component_visitor
  // retrieves the current component visitor
  // if unset(or ~null~) returns a <uvm_component_name_check_visitor> instance
  override uvm_visitor!(uvm_component) get_component_visitor() {
    synchronized (this) {
      if (_visitor is null) {
	_visitor = new uvm_component_name_check_visitor("name-check-visitor");
      }
      return _visitor;
    }
  }

  private uvm_printer _m_printer ;

  override void set_default_printer(uvm_printer printer) {
    synchronized (this) {
      _m_printer = printer;
    }
  }

  override uvm_printer get_default_printer() {
    synchronized (this) {
      if (_m_printer is null) {
	_m_printer =  uvm_table_printer.get_default() ;
      }
      return _m_printer;
    }
  }

  @uvm_public_sync
  private uvm_packer _m_packer;

  override void set_default_packer(uvm_packer packer) {
    synchronized (this) {
      _m_packer = packer;
    }
  }

  override uvm_packer get_default_packer() {
    synchronized (this) {
      if (_m_packer is null) {
	_m_packer =  new uvm_packer("uvm_default_packer") ;
      }
      return _m_packer;
    }
  }

  @uvm_public_sync
  private uvm_comparer _m_comparer;
  override void set_default_comparer(uvm_comparer comparer) {
    synchronized (this) {
      _m_comparer = comparer;
    }
  }

  override uvm_comparer get_default_comparer() {
    synchronized (this) {
      if (_m_comparer is null) {
	_m_comparer =  new uvm_comparer("uvm_default_comparer") ;
      }
      return _m_comparer ;
    }
  }

  @uvm_private_sync
  private int _m_default_max_ready_to_end_iters = 20;
  override void set_phase_max_ready_to_end(int max) {
    synchronized (this) {
      _m_default_max_ready_to_end_iters = max;
    }
  }

  override int get_phase_max_ready_to_end() {
    synchronized (this) {
      return _m_default_max_ready_to_end_iters;
    }
  }

  @uvm_public_sync
  private uvm_resource_pool _m_rp;
  override void set_resource_pool (uvm_resource_pool pool) {
    synchronized (this) {
      _m_rp = pool;
    }
  }

  override uvm_resource_pool get_resource_pool() {
    synchronized (this) {
      if (_m_rp is null)
	_m_rp = new uvm_resource_pool();
      return _m_rp;
    }
  }

  private uint _m_default_precedence = 1000;
  override void set_resource_pool_default_precedence(uint precedence) {
    synchronized (this) {
      _m_default_precedence = precedence;
    }
  }

  override uint get_resource_pool_default_precedence() {
    synchronized (this) {
      return _m_default_precedence;
    }
  }

  override uint get_global_seed() {
    return m_uvm_global_seed;
  }

  private bool _m_use_uvm_seeding = true;

  // @uvm-ieee 1800.2-2020 auto F.4.3
  override bool get_uvm_seeding() {
    synchronized (this) {
      return _m_use_uvm_seeding;
    }
  }

   // @uvm-ieee 1800.2-2020 auto F.4.4
  override void set_uvm_seeding(bool enable) {
    synchronized (this) {
      _m_use_uvm_seeding = enable;
    }
  }

  private uvm_copier _m_copier ;

  override void set_default_copier(uvm_copier copier) {
    synchronized (this) {
      _m_copier = copier ;
    }
  }

  override uvm_copier get_default_copier() {
    synchronized (this) {
      if (_m_copier is null) {
	_m_copier =  new uvm_copier("uvm_default_copier");
      }
      return _m_copier ;
    }
  }
}
