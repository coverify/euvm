//
//------------------------------------------------------------------------------
//   Copyright 2012-2016 Coverify Systems Technology
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
//------------------------------------------------------------------------------

module uvm.base.uvm_entity;

import uvm.base.uvm_root: uvm_root;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;

import uvm.meta.misc;
import uvm.meta.meta;
import esdl.base.core;
import core.sync.semaphore: Semaphore;

// This is where the uvm gets instantiated as part of the ESDL
// simulator. Unlike the SystemVerilog version where uvm_root is a
// singleton, we can have multiple instances of uvm_root, but each
// ESDL RootEntity could have only one instance of uvm_root.

class uvm_entity_base: Entity
{
  mixin(uvm_sync_string);
  this() {
    synchronized(this) {
      _uvm_root_init_semaphore = new Semaphore(); // count 0
      // uvm_once has some events etc that need to know the context for init
      set_thread_context();
      _root_once = new uvm_root_once(this);
    }
  }

  // Only for use by the uvm_root constructor -- use nowhere else
  static package uvm_entity_base _uvm_entity_inst;

  @uvm_immutable_sync
  private Semaphore _uvm_root_init_semaphore;

  // effectively immutable
  private uvm_root_once _root_once;
  
  uvm_root_once root_once() {
    return _root_once;
  }

  // do not give public access -- this function is to be called from
  // inside the uvm_root_once constructor -- just to make sure that it
  // is set since some of the uvm_once class instances require this
  // variable to be already set
  private void _set_root_once(uvm_root_once once) {
    synchronized(this) {
      // The assert below makes sure that this function is being
      // called only from the constructor (since the constructor also
      // sets _root_once variable) To make this variable effectively
      // immutable, it is important to ensure that this variable is
      // set from uvm_root_once constructor only
      assert(_root_once is null);
      _root_once = once;
    }
  }

  static uvm_entity_base get() {
    auto context = EntityIntf.getContextEntity();
    if(context !is null) {
      auto entity = cast(uvm_entity_base) context;
      assert(entity !is null);
      return entity;
    }
    return null;
  }

  abstract uvm_root _get_uvm_root();
  abstract uvm_root get_root();
  // The randomization seed passed from the top.
  // alias _get_uvm_root this;

  // This method would associate a free running thread to this UVM
  // ROOT instance -- this function can be called multiple times
  // within the same thread in order to switch context
  void set_thread_context() {
    auto proc = Process.self();
    if(proc !is null) {
      auto _entity = cast(uvm_entity_base) proc.getParentEntity();
      assert(_entity is null, "Default context already set to: " ~
	     _entity.getFullName());
    }
    this.setThreadContext();
  }
}

class uvm_entity(T): uvm_entity_base if(is(T: uvm_root))
{
  mixin(uvm_sync_string);
    
  // alias _get_uvm_root this;

  @uvm_private_sync
    bool _uvm_root_initialized;

  // The uvm_root instance corresponding to this RootEntity.
  // effectively immutable
  @uvm_immutable_sync
    private T _uvm_root_instance;

  this() {
    synchronized(this) {
      super();
      // set static variable that would later be used by uvm_root
      // constructor. Can not pass this instance as an argument to
      // the uvm_root constructor since the constructor has no
      // argument. If an argument is introduced, that will spoil
      // uvm_root user API.
      uvm_entity_base._uvm_entity_inst = this;
      _uvm_root_instance = new T();
      resetThreadContext();
    }
  }

  override void _esdl__postElab() {
    uvm_root_instance.set_root_name(getFullName() ~ ".(" ~
				    qualifiedTypeName!T ~ ")");
  }

  override T _get_uvm_root() {
    return uvm_root_instance;
  }

  // this is part of the public API
  // Make the uvm_root available only after the simulaion has
  // started and the uvm_root is ready to use
  override T get_root() {
    while(uvm_root_initialized is false) {
      uvm_root_init_semaphore.wait();
      uvm_root_init_semaphore.notify();
    }
    // expose the root_instance to the external world only after
    // elaboration is done
    uvm_root_instance.wait_for_end_of_elaboration();
    return uvm_root_instance;
  }

  void initial() {
    lockStage();
    // instatiating phases (part of once initialization) needs the
    // simulation to be running
    root_once.build_phases_once();
    fileCaveat();
    // init_domains can not be moved to the constructor since it
    // results in notification of some events, which can only
    // happen once the simulation starts
    uvm_root_instance.init_domains();
    wait(0);
    uvm_root_initialized = true;
    uvm_root_init_semaphore.notify();
    uvm_root_instance.initial();
  }

  Task!(initial) _init;

  void set_seed(uint seed) {
    synchronized(this) {
      if(_uvm_root_initialized) {
	uvm_report_fatal("SEED",
			 "Method set_seed can not be called after" ~
			 " the simulation has started",
			 uvm_verbosity.UVM_NONE);
      }
      root_once().set_seed(seed);
    }
  }
 }



class uvm_root_once
{
  import uvm.base.uvm_coreservice: uvm_coreservice_t;
  import uvm.base.uvm_tr_stream;
  import uvm.seq.uvm_sequencer_base;
  import uvm.base.uvm_misc;
  import uvm.base.uvm_recorder;
  import uvm.base.uvm_object;
  import uvm.base.uvm_component;
  import uvm.base.uvm_object_globals;
  import uvm.base.uvm_config_db;
  import uvm.base.uvm_cmdline_processor;
  import uvm.base.uvm_report_catcher;
  import uvm.base.uvm_report_handler;
  import uvm.base.uvm_report_server;
  import uvm.base.uvm_resource;
  import uvm.base.uvm_callback;
  import uvm.base.uvm_factory;
  import uvm.base.uvm_resource_db;
  import uvm.base.uvm_domain;
  import uvm.base.uvm_objection;
  import uvm.base.uvm_phase;
  import uvm.base.uvm_runtime_phases;
  import uvm.base.uvm_common_phases;
  import uvm.reg.uvm_reg_cbs;

  uvm_coreservice_t.uvm_once _uvm_coreservice_t_once;
  uvm_tr_stream.uvm_once _uvm_tr_stream_once;
  uvm_sequencer_base.uvm_once _uvm_sequencer_base_once;
  uvm_seed_map.uvm_once _uvm_seed_map_once;
  uvm_recorder.uvm_once _uvm_recorder_once;
  uvm_once_object_globals _uvm_object_globals_once;
  uvm_object.uvm_once _uvm_object_once;
  uvm_component.uvm_once _uvm_component_once;
  uvm_once_config_db _uvm_config_db_once;
  uvm_config_db_options.uvm_once _uvm_config_db_options_once;
  uvm_cmdline_processor.uvm_once _uvm_cmdline_processor_once;
  uvm_report_catcher.uvm_once _uvm_report_catcher_once;
  uvm_report_handler.uvm_once _uvm_report_handler_once;
  uvm_report_server.uvm_once _uvm_report_server_once;
  uvm_resource_options.uvm_once _uvm_resource_options_once;
  uvm_resource_base.uvm_once _uvm_resource_base_once;
  uvm_resource_pool.uvm_once _uvm_resource_pool_once;
  uvm_callbacks_base.uvm_once _uvm_callbacks_base_once;
  uvm_factory.uvm_once _uvm_factory_once;
  uvm_resource_db_options.uvm_once _uvm_resource_db_options_once;
  uvm_once_domain_globals _uvm_domain_globals_once;
  uvm_domain.uvm_once _uvm_domain_once;
  uvm_objection.uvm_once _uvm_objection_once;
  uvm_test_done_objection.uvm_once _uvm_test_done_objection_once;
  uvm_phase.uvm_once _uvm_phase_once;
  uvm_pre_reset_phase.uvm_once _uvm_pre_reset_phase_once;
  uvm_reset_phase.uvm_once _uvm_reset_phase_once;
  uvm_post_reset_phase.uvm_once _uvm_post_reset_phase_once;
  uvm_pre_configure_phase.uvm_once _uvm_pre_configure_phase_once;
  uvm_configure_phase.uvm_once _uvm_configure_phase_once;
  uvm_post_configure_phase.uvm_once _uvm_post_configure_phase_once;
  uvm_pre_main_phase.uvm_once _uvm_pre_main_phase_once;
  uvm_main_phase.uvm_once _uvm_main_phase_once;
  uvm_post_main_phase.uvm_once _uvm_post_main_phase_once;
  uvm_pre_shutdown_phase.uvm_once _uvm_pre_shutdown_phase_once;
  uvm_shutdown_phase.uvm_once _uvm_shutdown_phase_once;
  uvm_post_shutdown_phase.uvm_once _uvm_post_shutdown_phase_once;

  uvm_build_phase.uvm_once _uvm_build_phase_once;
  uvm_connect_phase.uvm_once _uvm_connect_phase_once;
  uvm_elaboration_phase.uvm_once _uvm_elaboration_phase_once;
  uvm_end_of_elaboration_phase.uvm_once _uvm_end_of_elaboration_phase_once;
  uvm_start_of_simulation_phase.uvm_once _uvm_start_of_simulation_phase_once;
  uvm_run_phase.uvm_once _uvm_run_phase_once;
  uvm_extract_phase.uvm_once _uvm_extract_phase_once;
  uvm_check_phase.uvm_once _uvm_check_phase_once;
  uvm_report_phase.uvm_once _uvm_report_phase_once;
  uvm_final_phase.uvm_once _uvm_final_phase_once;
  uvm_reg_read_only_cbs.uvm_once _uvm_reg_read_only_cbs_once;
  uvm_reg_write_only_cbs.uvm_once _uvm_reg_write_only_cbs_once;

  this(uvm_entity_base uvm_entity_inst) {
    synchronized(this) {
      uvm_entity_inst._set_root_once(this);
      import std.random;
      auto seed = uniform!int;
      _uvm_coreservice_t_once = new uvm_coreservice_t.uvm_once();
      _uvm_tr_stream_once = new uvm_tr_stream.uvm_once();
      _uvm_sequencer_base_once = new uvm_sequencer_base.uvm_once();
      _uvm_seed_map_once = new uvm_seed_map.uvm_once(seed);
      _uvm_recorder_once = new uvm_recorder.uvm_once();
      _uvm_object_once = new uvm_object.uvm_once();
      _uvm_component_once = new uvm_component.uvm_once();
      _uvm_config_db_once = new uvm_once_config_db();
      _uvm_config_db_options_once = new uvm_config_db_options.uvm_once();
      _uvm_report_catcher_once = new uvm_report_catcher.uvm_once();
      _uvm_report_handler_once = new uvm_report_handler.uvm_once();
      _uvm_resource_options_once = new uvm_resource_options.uvm_once();
      _uvm_resource_base_once = new uvm_resource_base.uvm_once();
      _uvm_resource_pool_once = new uvm_resource_pool.uvm_once();
      _uvm_factory_once = new uvm_factory.uvm_once();
      _uvm_resource_db_options_once = new uvm_resource_db_options.uvm_once();
      _uvm_domain_globals_once = new uvm_once_domain_globals();
      _uvm_domain_once = new uvm_domain.uvm_once();
      _uvm_cmdline_processor_once = new uvm_cmdline_processor.uvm_once();


      _uvm_objection_once = new uvm_objection.uvm_once();
      _uvm_test_done_objection_once = new uvm_test_done_objection.uvm_once();

      _uvm_report_server_once = new uvm_report_server.uvm_once();
      _uvm_callbacks_base_once = new uvm_callbacks_base.uvm_once();
      _uvm_object_globals_once = new uvm_once_object_globals();

    }
  }

  // we build the phases only once the simulation has started since
  // the phases require some events to be instantiated and these
  // events need a parent process to be in place.
  void build_phases_once() {
    _uvm_phase_once = new uvm_phase.uvm_once();

    _uvm_pre_reset_phase_once = new uvm_pre_reset_phase.uvm_once();
    _uvm_reset_phase_once = new uvm_reset_phase.uvm_once();
    _uvm_post_reset_phase_once = new uvm_post_reset_phase.uvm_once();
    _uvm_pre_configure_phase_once = new uvm_pre_configure_phase.uvm_once();
    _uvm_configure_phase_once = new uvm_configure_phase.uvm_once();
    _uvm_post_configure_phase_once = new uvm_post_configure_phase.uvm_once();
    _uvm_pre_main_phase_once = new uvm_pre_main_phase.uvm_once();
    _uvm_main_phase_once = new uvm_main_phase.uvm_once();
    _uvm_post_main_phase_once = new uvm_post_main_phase.uvm_once();
    _uvm_pre_shutdown_phase_once = new uvm_pre_shutdown_phase.uvm_once();
    _uvm_shutdown_phase_once = new uvm_shutdown_phase.uvm_once();
    _uvm_post_shutdown_phase_once = new uvm_post_shutdown_phase.uvm_once();

    _uvm_build_phase_once = new uvm_build_phase.uvm_once();
    _uvm_connect_phase_once = new uvm_connect_phase.uvm_once();
    _uvm_elaboration_phase_once = new uvm_elaboration_phase.uvm_once();
    _uvm_end_of_elaboration_phase_once = new uvm_end_of_elaboration_phase.uvm_once();
    _uvm_start_of_simulation_phase_once = new uvm_start_of_simulation_phase.uvm_once();
    _uvm_run_phase_once = new uvm_run_phase.uvm_once();
    _uvm_extract_phase_once = new uvm_extract_phase.uvm_once();
    _uvm_check_phase_once = new uvm_check_phase.uvm_once();
    _uvm_report_phase_once = new uvm_report_phase.uvm_once();
    _uvm_final_phase_once = new uvm_final_phase.uvm_once();
    _uvm_reg_read_only_cbs_once = new uvm_reg_read_only_cbs.uvm_once();
    _uvm_reg_write_only_cbs_once = new uvm_reg_write_only_cbs.uvm_once();
  }

  void set_seed(int seed) {
    _uvm_seed_map_once.set_seed(seed);
  }
}

