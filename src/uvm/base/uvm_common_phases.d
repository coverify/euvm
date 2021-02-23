//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2011 AMD
// Copyright 2014-2018 NVIDIA Corporation
// Copyright 2013 Cisco Systems, Inc.
// Copyright 2012 Accellera Systems Initiative
// Copyright 2018 Synopsys, Inc.
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

// Title -- NODOCS -- UVM Common Phases
//
// The common phases are the set of function and task phases that all
// <uvm_component>s execute together.
// All <uvm_component>s are always synchronized
// with respect to the common phases.
//
// The names of the UVM phases (which will be returned by get_name() for a
// phase instance) match the class names specified below with the "uvm_"
// and "_phase" removed.  For example, the build phase corresponds to the 
// uvm_build_phase class below and has the name "build", which means that 
// the following can be used to call foo() at the end of the build phase 
// (after all lower levels have finished build):
//
// | function void phase_ended(uvm_phase phase) ;
// |    if (phase.get_name()=="build") foo() ;
// | endfunction
// 
// The common phases are executed in the sequence they are specified below.
//
//
// Class -- NODOCS -- uvm_build_phase
//
// Create and configure of testbench structure
//
// <uvm_topdown_phase> that calls the
// <uvm_component::build_phase> method.
//
// Upon entry:
//  - The top-level components have been instantiated under <uvm_root>.
//  - Current simulation time is still equal to 0 but some "delta cycles" may have occurred
//
// Typical Uses:
//  - Instantiate sub-components.
//  - Instantiate register model.
//  - Get configuration values for the component being built.
//  - Set configuration values for sub-components.
//
// Exit Criteria:
//  - All <uvm_component>s have been instantiated.

module uvm.base.uvm_common_phases;

import uvm.base.uvm_object_defines;

import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_bottomup_phase: uvm_bottomup_phase;
import uvm.base.uvm_topdown_phase: uvm_topdown_phase;
import uvm.base.uvm_component: uvm_component;
import uvm.base.uvm_task_phase: uvm_task_phase;

import uvm.base.uvm_scope;

import uvm.meta.misc;
import uvm.meta.meta;

// @uvm-ieee 1800.2-2017 auto 9.8.1.1
final class uvm_build_phase: uvm_topdown_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    private uvm_build_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_build_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);
  
  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.build_phase(phase);
    // Do the auto build stuff here
    debug(UVM_AUTO) {
      uvm_info("UVM_AUTO", "Post Build on: " ~ comp.get_full_name() ~ ":" ~
	       comp.get_type_name());
    }
    comp.uvm__auto_build();
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  //
  static uvm_build_phase get() {
    return m_inst;
  }

  final protected this(string name="build") {
    super(name);
  }

}

// Class -- NODOCS -- uvm_connect_phase
//
// Establish cross-component connections.
//
// <uvm_bottomup_phase> that calls the
// <uvm_component::connect_phase> method.
//
// Upon Entry:
// - All components have been instantiated.
// - Current simulation time is still equal to 0
//   but some "delta cycles" may have occurred.
//
// Typical Uses:
// - Connect UVM TLM ports and exports.
// - Connect UVM TLM initiator sockets and target sockets.
// - Connect register model to adapter components.
// - Setup explicit phase domains.
//
// Exit Criteria:
// - All cross-component connections have been established.
// - All independent phase domains are set.
//

// @uvm-ieee 1800.2-2017 auto 9.8.1.2
final class uvm_connect_phase: uvm_bottomup_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_connect_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_connect_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);
  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.connect_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_connect_phase get() {
    return m_inst;
  }

  protected this(string name="connect") {
    super(name);
  }

}

final class uvm_setup_phase: uvm_topdown_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_setup_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_setup_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);
  
  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.setup_phase(phase);
    // Do the auto elab stuff here
    debug(UVM_AUTO) {
      uvm_info("UVM_AUTO", "Elaborating: " ~ comp.get_full_name() ~ ":" ~
	       comp.get_type_name());
    }
    comp.uvm__parallelize();
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_setup_phase get() {
    return m_inst;
  }

  final protected this(string name="elaboration") {
    super(name);
  }

}

// Class -- NODOCS -- uvm_end_of_elaboration_phase
//
// Fine-tune the testbench.
//
// <uvm_bottomup_phase> that calls the
// <uvm_component::end_of_elaboration_phase> method.
//
// Upon Entry:
// - The verification environment has been completely assembled.
// - Current simulation time is still equal to 0
//   but some "delta cycles" may have occurred.
//
// Typical Uses:
// - Display environment topology.
// - Open files.
// - Define additional configuration settings for components.
//
// Exit Criteria:
// - None.

// @uvm-ieee 1800.2-2017 auto 9.8.1.3
final class uvm_end_of_elaboration_phase: uvm_bottomup_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_end_of_elaboration_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_end_of_elaboration_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);

  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.end_of_elaboration_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_end_of_elaboration_phase get() {
    return m_inst;
  }

  protected this(string name="end_of_elaboration") {
    super(name);
  }

}

// Class -- NODOCS -- uvm_start_of_simulation_phase
//
// Get ready for DUT to be simulated.
//
// <uvm_bottomup_phase> that calls the
// <uvm_component::start_of_simulation_phase> method.
//
// Upon Entry:
// - Other simulation engines, debuggers, hardware assisted platforms and
//   all other run-time tools have been started and synchronized.
// - The verification environment has been completely configured
//   and is ready to start.
// - Current simulation time is still equal to 0
//   but some "delta cycles" may have occurred.
//
// Typical Uses:
// - Display environment topology
// - Set debugger breakpoint
// - Set initial run-time configuration values.
//
// Exit Criteria:
// - None.


// @uvm-ieee 1800.2-2017 auto 9.8.1.4
final class uvm_start_of_simulation_phase: uvm_bottomup_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_start_of_simulation_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_start_of_simulation_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);

  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.start_of_simulation_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_start_of_simulation_phase get() {
    return m_inst;
  }

  protected this(string name="start_of_simulation") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.1.5
final class uvm_run_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_run_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_run_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);
  
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.run_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_run_phase get() {
    return m_inst;
  }

  protected this(string name="run") {
    super(name);
  }

}



// @uvm-ieee 1800.2-2017 auto 9.8.1.6
final class uvm_extract_phase: uvm_bottomup_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_extract_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_extract_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);

  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.extract_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_extract_phase get() {
    return m_inst;
  }

  protected this(string name="extract") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.1.7
final class uvm_check_phase: uvm_bottomup_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_check_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_check_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);

  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.check_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_check_phase get() {
    return m_inst;
  }

  protected this(string name="check") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.1.8
final class uvm_report_phase: uvm_bottomup_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_report_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_report_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);

  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.report_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_report_phase get() {
    return m_inst;
  }

  protected this(string name="report") {
    super(name);
  }

}


// Class -- NODOCS -- uvm_final_phase
//
// Tie up loose ends.
//
// <uvm_topdown_phase> that calls the
// <uvm_component::final_phase> method.
//
// Upon Entry:
// - All test-related activity has completed.
//
// Typical Uses:
// - Close files.
// - Terminate co-simulation engines.
//
// Exit Criteria:
// - Ready to exit simulator.
//

// @uvm-ieee 1800.2-2017 auto 9.8.1.9
final class uvm_final_phase: uvm_topdown_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_final_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_final_phase();
      }
    }
  }

  mixin (uvm_scope_sync_string);

  final override void exec_func(uvm_component comp, uvm_phase phase) {
    comp.final_phase(phase);
  }

  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle
  static uvm_final_phase get() {
    return m_inst;
  }

  protected this(string name="final") {
    super(name);
  }

}
