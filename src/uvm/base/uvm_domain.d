//
//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2012-2014 Coverify Systems Technology
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

module uvm.base.uvm_domain;

import uvm.base.uvm_common_phases;
import uvm.base.uvm_phase;
import uvm.base.uvm_runtime_phases;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.meta.misc;

import esdl.data.queue;

import std.algorithm;

// typedef class uvm_build_phase;
// typedef class uvm_connect_phase;
// typedef class uvm_end_of_elaboration_phase;
// typedef class uvm_start_of_simulation_phase;
// typedef class uvm_run_phase;
// typedef class uvm_extract_phase;
// typedef class uvm_check_phase;
// typedef class uvm_report_phase;
// typedef class uvm_final_phase;

// typedef class uvm_pre_reset_phase;
// typedef class uvm_reset_phase;
// typedef class uvm_post_reset_phase;
// typedef class uvm_pre_configure_phase;
// typedef class uvm_configure_phase;
// typedef class uvm_post_configure_phase;
// typedef class uvm_pre_main_phase;
// typedef class uvm_main_phase;
// typedef class uvm_post_main_phase;
// typedef class uvm_pre_shutdown_phase;
// typedef class uvm_shutdown_phase;
// typedef class uvm_post_shutdown_phase;

final class uvm_once_domain_globals
{
  @uvm_public_sync uvm_phase _build_ph;
  @uvm_public_sync uvm_phase _connect_ph;
  @uvm_public_sync uvm_phase _end_of_elaboration_ph;
  @uvm_public_sync uvm_phase _start_of_simulation_ph;
  @uvm_public_sync uvm_phase _run_ph;
  @uvm_public_sync uvm_phase _extract_ph;
  @uvm_public_sync uvm_phase _check_ph;
  @uvm_public_sync uvm_phase _report_ph;
}

public uvm_once_domain_globals _uvm_domain_globals_once;
mixin(uvm_once_sync!(uvm_once_domain_globals, "_uvm_domain_globals"));

//------------------------------------------------------------------------------
//
// Class: uvm_domain
//
//------------------------------------------------------------------------------
//
// Phasing schedule node representing an independent branch of the schedule.
// Handle used to assign domains to components or hierarchies in the testbench
//

final class uvm_once_domain
{
  @uvm_private_sync private uvm_domain         _m_common_domain;
  @uvm_private_sync private uvm_domain         _m_uvm_domain; // run-time phases
  @uvm_private_sync private uvm_domain[string] _m_domains;
  @uvm_private_sync private uvm_phase          _m_uvm_schedule;
}

class uvm_domain: uvm_phase
{

  mixin(uvm_once_sync!(uvm_once_domain));

  // Function: get_domains
  //
  // Provides a list of all domains in the provided ~domains~ argument.
  //
  static public void get_domains(out uvm_domain[string] domains) {
    synchronized(_once) {
      domains = m_domains;
    }
  }

  static public uvm_domain[string] get_domains() {
    synchronized(_once) {
      return m_domains;
    }
  }

  // Function: get_uvm_schedule
  //
  // Get the "UVM" schedule, which consists of the run-time phases that
  // all components execute when participating in the "UVM" domain.
  //
  static public uvm_phase get_uvm_schedule() {
    get_uvm_domain();
    synchronized(_once) {
      return m_uvm_schedule;
    }
  }


  // Function: get_common_domain
  //
  // Get the "common" domain, which consists of the common phases that
  // all components execute in sync with each other. Phases in the "common"
  // domain are build, connect, end_of_elaboration, start_of_simulation, run,
  // extract, check, report, and final.
  //
  static public uvm_domain get_common_domain() {

    // defined in SV version but not used anywhere
    // uvm_phase schedule;
    synchronized(_once) {
      if (m_common_domain !is null) {
	return m_common_domain;
      }
    }

    uvm_domain domain = new uvm_domain("common");
    domain.add(uvm_build_phase.get());
    domain.add(uvm_connect_phase.get());
    domain.add(uvm_end_of_elaboration_phase.get());
    domain.add(uvm_start_of_simulation_phase.get());
    domain.add(uvm_run_phase.get());
    domain.add(uvm_extract_phase.get());
    domain.add(uvm_check_phase.get());
    domain.add(uvm_report_phase.get());
    domain.add(uvm_final_phase.get());

    synchronized(_once) {
      _once._m_domains["common"] = domain;

      // for backward compatibility, make common phases visible;
      // same as uvm_<name>_phase.get().
      build_ph               = domain.find(uvm_build_phase.get());
      connect_ph             = domain.find(uvm_connect_phase.get());
      end_of_elaboration_ph  = domain.find(uvm_end_of_elaboration_phase.get());
      start_of_simulation_ph = domain.find(uvm_start_of_simulation_phase.get());
      run_ph                 = domain.find(uvm_run_phase.get());
      extract_ph             = domain.find(uvm_extract_phase.get());
      check_ph               = domain.find(uvm_check_phase.get());
      report_ph              = domain.find(uvm_report_phase.get());

      m_common_domain = domain;
      domain = get_uvm_domain();
      m_common_domain.add(domain, m_common_domain.find(uvm_run_phase.get()));

      return m_common_domain;
    }
  }

  // Function: add_uvm_phases
  //
  // Appends to the given ~schedule~ the built-in UVM phases.
  //
  static public void add_uvm_phases(uvm_phase schedule) {
    schedule.add(uvm_pre_reset_phase.get());
    schedule.add(uvm_reset_phase.get());
    schedule.add(uvm_post_reset_phase.get());
    schedule.add(uvm_pre_configure_phase.get());
    schedule.add(uvm_configure_phase.get());
    schedule.add(uvm_post_configure_phase.get());
    schedule.add(uvm_pre_main_phase.get());
    schedule.add(uvm_main_phase.get());
    schedule.add(uvm_post_main_phase.get());
    schedule.add(uvm_pre_shutdown_phase.get());
    schedule.add(uvm_shutdown_phase.get());
    schedule.add(uvm_post_shutdown_phase.get());
  }

  // Function: get_uvm_domain
  //
  // Get a handle to the singleton ~uvm~ domain
  //
  static public uvm_domain get_uvm_domain() {
    synchronized(_once) {
      if (m_uvm_domain is null) {
	m_uvm_domain = new uvm_domain("uvm");
	m_uvm_schedule = new uvm_phase("uvm_sched", UVM_PHASE_SCHEDULE);
	add_uvm_phases(m_uvm_schedule);
	m_uvm_domain.add(m_uvm_schedule);
      }
      return m_uvm_domain;
    }
  }

  // Function: new
  //
  // Create a new instance of a phase domain.
  public this(string name="") {
    super(name,UVM_PHASE_DOMAIN);
    synchronized(_once) {
      if (name in m_domains) {
	uvm_error("UNIQDOMNAM",
		  format("Domain created with non-unique name '%s'", name));
      }
      _once._m_domains[name] = this;
    }
  }

  // Function: jump
  //
  // jumps all active phases of this domain to to-phase if
  // there is a path between active-phase and to-phase
  override public void jump(uvm_phase phase) {
    // synchronized(this) {
    uvm_phase[] phases = m_get_transitive_children();
    foreach(ph;
	    filter!((uvm_phase p)
		    { return (p.get_state >= UVM_PHASE_STARTED &&
			      p.get_state <= UVM_PHASE_CLEANUP); })
	    (phases)) {
      if(ph.is_before(phase) || ph.is_after(phase))
	ph.jump(phase);
    }
    // }
  }

  // jump_all
  // --------
  static public void jump_all(uvm_phase phase) {
    uvm_domain[string] domains = get_domains();
    // get_domains(domains);
    foreach(domain; domains) {
      domain.jump(phase);
    }
  }

}
