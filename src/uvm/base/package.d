//
//----------------------------------------------------------------------
// Copyright 2007-2019 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2010-2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2011 Cypress Semiconductor Corp.
// Copyright 2010-2018 Synopsys, Inc.
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

module uvm.base;

// Miscellaneous classes and functions. uvm_void is defined in uvm_misc,
// along with some auxillary functions that UVM needs but are not really
// part of UVM.
public import uvm.base.uvm_version;
public import uvm.base.uvm_object_globals;
public import uvm.base.uvm_misc;
  
public import uvm.base.uvm_coreservice;
public import uvm.base.uvm_globals;

// The base object element. Contains data methods (<copy>, <compare> etc) and
// factory creation methods (<create>). Also includes control classes.
public import uvm.base.uvm_object;

public import uvm.base.uvm_factory;
public import uvm.base.uvm_registry;

public import uvm.base.uvm_pool;
public import uvm.base.uvm_queue;


// Resources/configuration facility
public import uvm.base.uvm_spell_chkr;
public import uvm.base.uvm_resource_base;
public import uvm.base.uvm_resource;
public import uvm.base.uvm_resource_specializations;
public import uvm.base.uvm_resource_db;
public import uvm.base.uvm_resource_db_options;
public import uvm.base.uvm_config_db;


// Policies
public import uvm.base.uvm_policy;
public import uvm.base.uvm_field_op;
public import uvm.base.uvm_copier;
public import uvm.base.uvm_printer;
public import uvm.base.uvm_comparer;
public import uvm.base.uvm_packer;
public import uvm.base.uvm_links;
public import uvm.base.uvm_tr_database;
public import uvm.base.uvm_text_tr_database;
public import uvm.base.uvm_tr_stream;
public import uvm.base.uvm_text_tr_stream;
public import uvm.base.uvm_recorder;

// Event interface
public import uvm.base.uvm_event_callback;
public import uvm.base.uvm_event;
public import uvm.base.uvm_barrier;

// Callback interface
public import uvm.base.uvm_callback;

// Reporting interface
public import uvm.base.uvm_report_message;
public import uvm.base.uvm_report_catcher;
public import uvm.base.uvm_report_server;
public import uvm.base.uvm_report_handler;
public import uvm.base.uvm_report_object;

// Base transaction object
public import uvm.base.uvm_transaction;

// The phase declarations
public import uvm.base.uvm_phase;
public import uvm.base.uvm_domain;
public import uvm.base.uvm_bottomup_phase;
public import uvm.base.uvm_topdown_phase;
public import uvm.base.uvm_task_phase;
public import uvm.base.uvm_common_phases;
public import uvm.base.uvm_runtime_phases;

public import uvm.base.uvm_run_test_callback;
public import uvm.base.uvm_component;

// Objection interface
public import uvm.base.uvm_objection;
public import uvm.base.uvm_heartbeat;


// Command Line Processor
public import uvm.base.uvm_cmdline_processor;
  
// traversal utilities
public import uvm.base.uvm_traversal;

// Embedded UVM specific
public import uvm.base.uvm_aliases;
public import uvm.base.uvm_array;
public import uvm.base.uvm_async_lock;
public import uvm.base.uvm_component_defines;
public import uvm.base.uvm_entity;
public import uvm.base.uvm_global_defines;
public import uvm.base.uvm_object_defines;
public import uvm.base.uvm_once;
public import uvm.base.uvm_port_base;
public import uvm.base.uvm_root;
