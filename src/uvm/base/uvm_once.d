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

module uvm.base.uvm_once;

import uvm.base.uvm_entity;

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
