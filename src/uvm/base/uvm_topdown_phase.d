//
//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
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
// Class: uvm_topdown_phase
//
//------------------------------------------------------------------------------
// Virtual base class for function phases that operate top-down.
// The pure virtual function execute() is called for each component.
//
// A top-down function phase completes when the <execute()> method
// has been called and returned on all applicable components
// in the hierarchy.

module uvm.base.uvm_topdown_phase;

import uvm.base.uvm_phase;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_domain;
import uvm.base.uvm_misc: uvm_create_random_seed;

import esdl.base.core: Process;
import std.string: format;

abstract class uvm_topdown_phase: uvm_phase
{
  import uvm.base.uvm_component;
  // Function: new
  //
  // Create a new instance of a top-down phase
  //
  this(string name) {
    super(name,UVM_PHASE_IMP);
  }


  // Function: traverse
  //
  // Traverses the component tree in top-down order, calling <execute> for
  // each component.
  //
  override void traverse(uvm_component comp,
			 uvm_phase phase,
			 uvm_phase_state state) {
    uvm_domain phase_domain = phase.get_domain();
    uvm_domain comp_domain = comp.get_domain();

    synchronized(this) {
      if (m_phase_trace) {
	uvm_info("PH_TRACE", format("topdown-phase phase=%s state=%s comp=%s " ~
				    "comp.domain=%s phase.domain=%s",
				    phase.get_name(), state,
				    comp.get_full_name(), comp_domain.get_name(),
				    phase_domain.get_name()),
		 UVM_DEBUG);
      }

      if (phase_domain is uvm_domain.get_common_domain() ||
	  phase_domain is comp_domain) {
	switch (state) {
	case UVM_PHASE_STARTED:
	  comp.m_current_phase = phase;
	  comp.m_apply_verbosity_settings(phase);
	  comp.phase_started(phase);
	  break;
	case UVM_PHASE_EXECUTING:
	  if (!(phase.get_name() == "build" && comp.m_build_done)) {
	    uvm_phase ph = this;
	    comp.inc_phasing_active();
	    auto pphase = this in comp.m_phase_imps;
	    if (pphase !is null) {
	      ph = cast(uvm_phase) *pphase;
	    }
	    ph.execute(comp, phase);
	    comp.dec_phasing_active();
	  }
	  break;
	case UVM_PHASE_READY_TO_END:
	  comp.phase_ready_to_end(phase);
	  break;
	case UVM_PHASE_ENDED:
	  comp.phase_ended(phase);
	  comp.m_current_phase = null;
	  break;
	default:
	  uvm_fatal("PH_BADEXEC","topdown phase traverse internal error");
	}
      }
    }

    foreach(child; comp.get_children) {
      traverse(child, phase, state);
    }
  }


  // Function: execute
  //
  // Executes the top-down phase ~phase~ for the component ~comp~.
  //
  override void execute(uvm_component comp,
			uvm_phase phase) {
    // reseed this process for random stability
    auto proc = Process.self;
    proc.srandom(uvm_create_random_seed(phase.get_type_name(),
					comp.get_full_name()));
    comp.m_current_phase = phase;
    exec_func(comp, phase);
  }
}
