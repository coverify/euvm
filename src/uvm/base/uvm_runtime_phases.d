//
//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2011 AMD
// Copyright 2014-2018 NVIDIA Corporation
// Copyright 2013 Cisco Systems, Inc.
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


module uvm.base.uvm_runtime_phases;

import uvm.base.uvm_object_defines;

import uvm.base.uvm_task_phase: uvm_task_phase;
import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_component: uvm_component;

import uvm.base.uvm_scope;

import uvm.meta.misc;
import uvm.meta.meta;

// Title -- NODOCS -- UVM Run-Time Phases
//
// The run-time schedule is the pre-defined phase schedule
// which runs concurrently to the <uvm_run_phase> global run phase.
// By default, all <uvm_component>s using the run-time schedule
// are synchronized with respect to the pre-defined phases in the schedule.
// It is possible for components to belong to different domains
// in which case their schedules can be unsynchronized.
//
// The names of the UVM phases (which will be returned by get_name() for a
// phase instance) match the class names specified below with the "uvm_"
// and "_phase" removed.  For example, the main phase corresponds to the 
// uvm_main_phase class below and has the name "main", which means that 
// the following can be used to call foo() at the start of main phase:
//
// | function void phase_started(uvm_phase phase) ;
// |    if (phase.get_name()=="main") foo() ;
// | endfunction
//
// The run-time phases are executed in the sequence they are specified below.
//
//

// @uvm-ieee 1800.2-2017 auto 9.8.2.1
class uvm_pre_reset_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_pre_reset_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_pre_reset_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.pre_reset_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_pre_reset_phase get() {
    return m_inst;
  }

  protected this(string name="pre_reset") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.2.2
class uvm_reset_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_reset_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_reset_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.reset_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_reset_phase get() {
      return m_inst;
  }
  
  protected this(string name="reset") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.2.3
class uvm_post_reset_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_post_reset_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_post_reset_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.post_reset_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_post_reset_phase get() {
    return m_inst;
  }
  
  protected this(string name="post_reset") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.2.4
class uvm_pre_configure_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_pre_configure_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_pre_configure_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.pre_configure_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_pre_configure_phase get() {
    return m_inst;
  }

  protected this(string name="pre_configure") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.2.5
class uvm_configure_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_configure_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_configure_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.configure_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_configure_phase get() {
    return m_inst;
  }

  protected this(string name="configure") {
    super(name);
  }
  
}


// @uvm-ieee 1800.2-2017 auto 9.8.2.6
class uvm_post_configure_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_post_configure_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_post_configure_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.post_configure_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_post_configure_phase get() {
    return m_inst;
  }

  protected this(string name="post_configure") {
    super(name);
  }
  
}


// @uvm-ieee 1800.2-2017 auto 9.8.2.7
class uvm_pre_main_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_pre_main_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_pre_main_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.pre_main_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_pre_main_phase get() {
    return m_inst;
  }

  protected this(string name="pre_main") {
    super(name);
  }
  
}


// @uvm-ieee 1800.2-2017 auto 9.8.2.8
class uvm_main_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_main_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_main_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.main_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_main_phase get() {
    return m_inst;
  }

  protected this(string name="main") {
    super(name);
  }

}



// @uvm-ieee 1800.2-2017 auto 9.8.2.9
class uvm_post_main_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_post_main_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_post_main_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.post_main_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_post_main_phase get() {
    return m_inst;
  }

  protected this(string name="post_main") {
    super(name);
  }

}



// @uvm-ieee 1800.2-2017 auto 9.8.2.10
class uvm_pre_shutdown_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_pre_shutdown_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_pre_shutdown_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.pre_shutdown_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_pre_shutdown_phase get() {
    return m_inst;
  }

  protected this(string name="pre_shutdown") {
    super(name);
  }

}


// @uvm-ieee 1800.2-2017 auto 9.8.2.11
class uvm_shutdown_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_shutdown_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_shutdown_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.shutdown_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_shutdown_phase get() {
    return m_inst;
  }
  
  protected this(string name="shutdown") {
    super(name);
  }

}



// @uvm-ieee 1800.2-2017 auto 9.8.2.12
class uvm_post_shutdown_phase: uvm_task_phase
{
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    uvm_post_shutdown_phase _m_inst;
    this() {
      synchronized (this) {
	_m_inst = new uvm_post_shutdown_phase();
      }
    }
  };

  mixin (uvm_scope_sync_string);
  // task
  final override void exec_task(uvm_component comp, uvm_phase phase) {
    comp.post_shutdown_phase(phase);
  }
  mixin uvm_type_name_decl;

  // Function -- NODOCS -- get
  // Returns the singleton phase handle 
  static uvm_post_shutdown_phase get() {
    return m_inst;
  }

  protected this(string name="post_shutdown") {
    super(name);
  }

}
