//
//----------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2011 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
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


module uvm.base.uvm_task_phase;

import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_object_globals: uvm_phase_state, uvm_phase_type, uvm_verbosity;

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_task_phase
//
//------------------------------------------------------------------------------
// Base class for all task phases.
// It forks a call to <uvm_phase::exec_task()>
// for each component in the hierarchy.
//
// The completion of the task does not imply, nor is it required for,
// the end of phase. Once the phase completes, any remaining forked
// <uvm_phase::exec_task()> threads are forcibly and immediately killed.
//
// By default, the way for a task phase to extend over time is if there is
// at least one component that raises an objection.
//| class my_comp extends uvm_component;
//|    task main_phase(uvm_phase phase);
//|       phase.raise_objection(this, "Applying stimulus")
//|       ...
//|       phase.drop_objection(this, "Applied enough stimulus")
//|    endtask
//| endclass
//
//
// There is however one scenario wherein time advances within a task-based phase
// without any objections to the phase being raised. If two (or more) phases
// share a common successor, such as the <uvm_run_phase> and the
// <uvm_post_shutdown_phase> sharing the <uvm_extract_phase> as a successor,
// then phase advancement is delayed until all predecessors of the common
// successor are ready to proceed.  Because of this, it is possible for time to
// advance between <uvm_component::phase_started> and <uvm_component::phase_ended>
// of a task phase without any participants in the phase raising an objection.
//

// @uvm-ieee 1800.2-2020 auto 9.6.1
abstract class uvm_task_phase: uvm_phase
{
  import uvm.base.uvm_component: uvm_component;


  // @uvm-ieee 1800.2-2020 auto 9.6.2.1
  this(string name) {
    super(name, uvm_phase_type.UVM_PHASE_IMP);
  }


  // @uvm-ieee 1800.2-2020 auto 9.6.2.2
  override void traverse(uvm_component comp,
			 uvm_phase phase,
			 uvm_phase_state state) {
    phase.m_num_procs_not_yet_returned = 0;
    m_traverse(comp, phase, state);
  }

  final void m_traverse(uvm_component comp,
			uvm_phase phase,
			uvm_phase_state state) {
    import uvm.base.uvm_domain;
    import uvm.base.uvm_globals;
    import uvm.seq.uvm_sequencer_base;
    import std.string: format;
    uvm_domain phase_domain = phase.get_domain();
    uvm_domain comp_domain = comp.get_domain();

    foreach (child; comp.get_children) {
      m_traverse(child, phase, state);
    }

    synchronized (this) {
      if (m_phase_trace) {
	uvm_info("PH_TRACE",format("topdown-phase phase=%s state=%s comp=%s " ~
				   "comp.domain=%s phase.domain=%s",
				   phase.get_name(), state,
				   comp.get_full_name(), comp_domain.get_name(),
				   phase_domain.get_name()),
		 uvm_verbosity.UVM_DEBUG);
      }

      if (phase_domain is uvm_domain.get_common_domain() ||
	  phase_domain is comp_domain) {
	switch (state) {
	case uvm_phase_state.UVM_PHASE_STARTED:
	  comp.m_current_phase = phase;
	  comp.m_apply_verbosity_settings(phase);
	  comp.phase_started(phase);
	  auto seqr = cast (uvm_sequencer_base) comp;
          if (seqr !is null) {
            seqr.start_phase_sequence(phase);
	  }
	  break;
	case uvm_phase_state.UVM_PHASE_EXECUTING:
	  uvm_phase ph = this;
	  auto pphase = this in comp.m_phase_imps;
	  if (pphase !is null) {
	    ph = cast (uvm_phase) *pphase;
	  }
	  ph.execute(comp, phase);
	  break;
	case uvm_phase_state.UVM_PHASE_READY_TO_END:
	  comp.phase_ready_to_end(phase);
	  break;
	case uvm_phase_state.UVM_PHASE_ENDED:
	  auto seqr = cast (uvm_sequencer_base) comp;
          if (seqr !is null) {
            seqr.stop_phase_sequence(phase);
	  }
	  comp.phase_ended(phase);
	  comp.m_current_phase = null;
	  break;
	default:
	  uvm_fatal("PH_BADEXEC","task phase traverse internal error");
	  break;
	}
      }
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.6.2.3
  override void execute(uvm_component comp,
			uvm_phase phase) {
    import uvm.base.uvm_misc;
    import esdl.base.core: fork, Process;
    fork("uvm_task_phase/execute(" ~ phase.get_name() ~
	 ")[" ~ comp.get_full_name() ~ "]",
	 {

	   // reseed this process for random stability
	   auto proc = Process.self;
	   proc.srandom(uvm_create_random_seed(phase.get_type_name(),
					       comp.get_full_name()));

	   phase.inc_m_num_procs_not_yet_returned;

	   exec_task(comp, phase);

	   phase.dec_m_num_procs_not_yet_returned;
	 }
	 ).setThreadAffinity(comp);
  }
}
