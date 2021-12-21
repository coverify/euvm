//
//----------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2011 AMD
// Copyright 2012 Accellera Systems Initiative
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2018 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
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

import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_scope;

import uvm.meta.misc;

final class uvm_scope_domain_globals: uvm_scope_base
{
  @uvm_public_sync
  private uvm_phase _build_ph;
  @uvm_public_sync
  private uvm_phase _connect_ph;
  @uvm_public_sync
  private uvm_phase _setup_ph;
  @uvm_public_sync
  private uvm_phase _end_of_elaboration_ph;
  @uvm_public_sync
  private uvm_phase _start_of_simulation_ph;
  @uvm_public_sync
  private uvm_phase _run_ph;
  @uvm_public_sync
  private uvm_phase _extract_ph;
  @uvm_public_sync
  private uvm_phase _check_ph;
  @uvm_public_sync
  private uvm_phase _report_ph;
}

mixin (uvm_scope_sync_string!(uvm_scope_domain_globals, "uvm_scope_domain_globals"));

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_domain
//
//------------------------------------------------------------------------------
//
// Phasing schedule node representing an independent branch of the schedule.
// Handle used to assign domains to components or hierarchies in the testbench
//

// @uvm-ieee 1800.2-2020 auto 9.4.1
class uvm_domain: uvm_phase
{
  import std.string: format;

  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    private uvm_domain         _m_uvm_domain; // run-time phases
    private uvm_domain[string] _m_domains;
    @uvm_private_sync
    private uvm_phase          _m_uvm_schedule;
  };

  mixin (uvm_scope_sync_string);

  // @uvm-ieee 1800.2-2020 auto 9.4.2.2
  static void get_domains(out uvm_domain[string] domains) {
    synchronized (_uvm_scope_inst) {
      domains = _uvm_scope_inst._m_domains.dup;
    }
  }

  static const(uvm_domain[string]) get_domains() {
    synchronized (_uvm_scope_inst) {
      return _uvm_scope_inst._m_domains.dup;
    }
  }

  // Function -- NODOCS -- get_uvm_schedule
  //
  // Get the "UVM" schedule, which consists of the run-time phases that
  // all components execute when participating in the "UVM" domain.
  //
  static uvm_phase get_uvm_schedule() {
    get_uvm_domain();
    synchronized (_uvm_scope_inst) {
      return m_uvm_schedule;
    }
  }


  // Function -- NODOCS -- get_common_domain
  //
  // Get the "common" domain, which consists of the common phases that
  // all components execute in sync with each other. Phases in the "common"
  // domain are build, connect, end_of_elaboration, start_of_simulation, run,
  // extract, check, report, and final.
  //
  static uvm_domain get_common_domain() {

    import uvm.base.uvm_common_phases;
    // defined in SV version but not used anywhere
    // uvm_phase schedule;
    synchronized (_uvm_scope_inst) {
      uvm_domain domain;

      if ("common" in _uvm_scope_inst._m_domains) {
	domain = _uvm_scope_inst._m_domains["common"];
      }

      if (domain !is null) {
	return domain;
      }

      domain = new uvm_domain("common");
      domain.add(uvm_build_phase.get());
      domain.add(uvm_connect_phase.get());
      domain.add(uvm_setup_phase.get());
      domain.add(uvm_end_of_elaboration_phase.get());
      domain.add(uvm_start_of_simulation_phase.get());
      domain.add(uvm_run_phase.get());
      domain.add(uvm_extract_phase.get());
      domain.add(uvm_check_phase.get());
      domain.add(uvm_report_phase.get());
      domain.add(uvm_final_phase.get());

      _uvm_scope_inst._m_domains["common"] = domain;

      // for backward compatibility, make common phases visible;
      // same as uvm_<name>_phase.get().
      build_ph               = domain.find(uvm_build_phase.get());
      connect_ph             = domain.find(uvm_connect_phase.get());
      setup_ph               = domain.find(uvm_setup_phase.get());
      end_of_elaboration_ph  = domain.find(uvm_end_of_elaboration_phase.get());
      start_of_simulation_ph = domain.find(uvm_start_of_simulation_phase.get());
      run_ph                 = domain.find(uvm_run_phase.get());
      extract_ph             = domain.find(uvm_extract_phase.get());
      check_ph               = domain.find(uvm_check_phase.get());
      report_ph              = domain.find(uvm_report_phase.get());

      domain = get_uvm_domain();
      _uvm_scope_inst._m_domains["common"].add(domain,
				    _uvm_scope_inst._m_domains["common"].find(uvm_run_phase.get()));

      return _uvm_scope_inst._m_domains["common"];
    }
  }

  // @uvm-ieee 1800.2-2020 auto 9.4.2.3
  static void add_uvm_phases(uvm_phase schedule) {
    import uvm.base.uvm_runtime_phases;
    assert (schedule !is null);
    synchronized (schedule) {
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
  }
  
  // Function: get_uvm_domain
  //
  // Get a handle to the singleton ~uvm~ domain
  //
  static uvm_domain get_uvm_domain() {
    import uvm.base.uvm_object_globals;
    synchronized (_uvm_scope_inst) {
      if (m_uvm_domain is null) {
	m_uvm_domain = new uvm_domain("uvm");
	m_uvm_schedule = new uvm_phase("uvm_sched", uvm_phase_type.UVM_PHASE_SCHEDULE);
	add_uvm_phases(m_uvm_schedule);
	m_uvm_domain.add(m_uvm_schedule);
      }
      return m_uvm_domain;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 9.4.2.1
  this(string name="") {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    super(name, uvm_phase_type.UVM_PHASE_DOMAIN);
    synchronized (_uvm_scope_inst) {
      if (name in _uvm_scope_inst._m_domains) {
	uvm_error("UNIQDOMNAM",
		  format("Domain created with non-unique name '%s'", name));
      }
      _uvm_scope_inst._m_domains[name] = this;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 9.4.2.4
  override void jump(uvm_phase phase) {
    import uvm.base.uvm_object_globals;
    import std.algorithm;	// filter
    // synchronized (this) {
    uvm_phase[] phases = m_get_transitive_children();
    foreach (ph;
	    filter!((uvm_phase p) {
		uvm_phase_state phase_state = p.get_state();
		return (phase_state >= uvm_phase_state.UVM_PHASE_STARTED &&
			phase_state <= uvm_phase_state.UVM_PHASE_CLEANUP);
	      }) (phases)) {
      if (ph.is_before(phase) || ph.is_after(phase))
	ph.jump(phase);
    }
    // }
  }

  // jump_all
  // --------
  static void jump_all(uvm_phase phase) {
    auto domains = get_domains();
    // get_domains(domains);
    foreach (domain; domains) {
      (cast (uvm_domain) domain).jump(phase);
    }
  }

}
