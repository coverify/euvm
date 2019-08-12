//
//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2011 AMD
// Copyright 2015 NVIDIA Corporation
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

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_bottomup_phase
//
//------------------------------------------------------------------------------
// Virtual base class for function phases that operate bottom-up.
// The pure virtual function execute() is called for each component.
// This is the default traversal so is included only for naming.
//
// A bottom-up function phase completes when the <execute()> method
// has been called and returned on all applicable components
// in the hierarchy.

module uvm.base.uvm_bottomup_phase;

import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_component: uvm_component;
import uvm.base.uvm_object_globals: uvm_phase_state, uvm_verbosity;

import std.conv: to;
import std.string: format;

// @uvm-ieee 1800.2-2017 auto 9.5.1
abstract class uvm_bottomup_phase: uvm_phase
{


  // @uvm-ieee 1800.2-2017 auto 9.5.2.1
  this(string name) {
    import uvm.base.uvm_object_globals;
    super(name, uvm_phase_type.UVM_PHASE_IMP);
  }


  // @uvm-ieee 1800.2-2017 auto 9.5.2.2
  override void traverse(uvm_component comp,
			 uvm_phase phase,
			 uvm_phase_state state) {
    import uvm.base.uvm_domain;
    import uvm.base.uvm_globals;
    uvm_domain phase_domain = phase.get_domain();
    uvm_domain comp_domain = comp.get_domain();

    foreach (child; comp.get_children)
      traverse(child, phase, state);

    if (m_phase_trace)
      uvm_info("PH_TRACE",
	       format("bottomup-phase phase=%s state=%s" ~
		      " comp=%s comp.domain=%s phase.domain=%s",
		      phase.get_name(), state,
		      comp.get_full_name(), comp_domain.get_name(),
		      phase_domain.get_name()), uvm_verbosity.UVM_DEBUG);

    if (phase_domain is uvm_domain.get_common_domain() ||
	phase_domain is comp_domain) {
      switch (state) {
      case uvm_phase_state.UVM_PHASE_STARTED:
	comp.m_current_phase = phase;
	comp.m_apply_verbosity_settings(phase);
	comp.phase_started(phase);
	break;
      case uvm_phase_state.UVM_PHASE_EXECUTING:
	uvm_phase ph = this;
	auto pphase = this in comp.m_phase_imps;
	if (pphase !is null)
	  ph = cast (uvm_phase) *pphase;
	ph.execute(comp, phase);
	break;
      case uvm_phase_state.UVM_PHASE_READY_TO_END:
	comp.phase_ready_to_end(phase);
	break;
      case uvm_phase_state.UVM_PHASE_ENDED:
	comp.phase_ended(phase);
	comp.m_current_phase = null;
	break;
      default:
	uvm_fatal("PH_BADEXEC",
		  "bottomup phase traverse internal error");
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 9.5.2.3
  override void execute(uvm_component comp, uvm_phase phase) {
    import esdl.base.core: Process;
    import uvm.base.uvm_misc: uvm_create_random_seed;
    // reseed this process for random stability
    auto proc = Process.self;
    proc.srandom(uvm_create_random_seed(phase.get_type_name(),
					comp.get_full_name()));

    comp.m_current_phase = phase;
    exec_func(comp, phase);
  }
}
