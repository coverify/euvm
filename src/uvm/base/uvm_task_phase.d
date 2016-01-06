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
// Class: uvm_task_phase
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

module uvm.base.uvm_task_phase;

import uvm.base.uvm_phase;
import uvm.base.uvm_component;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_domain;
import uvm.base.uvm_globals;
import uvm.base.uvm_misc;
import uvm.seq.uvm_sequencer_base;
import esdl.base.core: Process, fork, Fork;

abstract class uvm_task_phase: uvm_phase
{

  // Function: new
  //
  // Create a new instance of a task-based phase
  //
  public this(string name) {
    super(name,UVM_PHASE_IMP);
  }


  // Function: traverse
  //
  // Traverses the component tree in bottom-up order, calling <execute> for
  // each component. The actual order for task-based phases doesn't really
  // matter, as each component task is executed in a separate process whose
  // starting order is not deterministic.
  //
  override public void traverse(uvm_component comp,
				uvm_phase phase,
				uvm_phase_state state) {
    phase.m_num_procs_not_yet_returned = 0;
    m_traverse(comp, phase, state);
  }

  final public void m_traverse(uvm_component comp,
			 uvm_phase phase,
			 uvm_phase_state state) {
    uvm_domain phase_domain = phase.get_domain();
    uvm_domain comp_domain = comp.get_domain();

    foreach(child; comp.get_children) {
      m_traverse(child, phase, state);
    }

    synchronized(this) {
      import std.string: format;
      if (m_phase_trace) {
	uvm_info("PH_TRACE",format("topdown-phase phase=%s state=%s comp=%s "
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
	  uvm_phase ph = this;
	  if (this in comp.m_phase_imps) {
	    ph = comp.m_phase_imps[this];
	  }
	  ph.execute(comp, phase);
	  break;
	case UVM_PHASE_READY_TO_END:
	  comp.phase_ready_to_end(phase);
	  break;
	case UVM_PHASE_ENDED:
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

  // Function: execute
  //
  // Fork the task-based phase ~phase~ for the component ~comp~.
  //
  override public void execute(uvm_component comp,
			       uvm_phase phase) {
    fork!("uvm_task_phase/execute")({

	// reseed this process for random stability
	auto proc = Process.self;
	proc.srandom(uvm_create_random_seed(phase.get_type_name(),
					    comp.get_full_name()));

	phase.inc_m_num_procs_not_yet_returned;

	uvm_sequencer_base seqr = cast(uvm_sequencer_base) comp;
	if (seqr !is null) {
	  seqr.start_phase_sequence(phase);
	}

	exec_task(comp, phase);

	phase.dec_m_num_procs_not_yet_returned;
      }).setAffinity(comp);
  }
}
