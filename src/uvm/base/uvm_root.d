//
//------------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2010-2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2010-2012 AMD
// Copyright 2012-2018 NVIDIA Corporation
// Copyright 2012-2018 Cisco Systems, Inc.
// Copyright 2012 Accellera Systems Initiative
// Copyright 2017 Verific
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


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_root
//
// The ~uvm_root~ class serves as the implicit top-level and phase controller for
// all UVM components. Users do not directly instantiate ~uvm_root~. The UVM
// automatically creates a single instance of <uvm_root> that users can
// access via the global (uvm_pkg-scope) variable, ~uvm_top~.
//
// (see uvm_ref_root.gif)
//
// The ~uvm_top~ instance of ~uvm_root~ plays several key roles in the UVM.
//
// Implicit top-level - The ~uvm_top~ serves as an implicit top-level component.
// Any component whose parent is specified as ~null~ becomes a child of ~uvm_top~.
// Thus, all UVM components in simulation are descendants of ~uvm_top~.
//
// Phase control - ~uvm_top~ manages the phasing for all components.
//
// Search - Use ~uvm_top~ to search for components based on their
// hierarchical name. See <find> and <find_all>.
//
// Report configuration - Use ~uvm_top~ to globally configure
// report verbosity, log files, and actions. For example,
// ~uvm_top.set_report_verbosity_level_hier(UVM_FULL)~ would set
// full verbosity for all components in simulation.
//
// Global reporter - Because ~uvm_top~ is globally accessible (in uvm_pkg
// scope), UVM's reporting mechanism is accessible from anywhere
// outside ~uvm_component~, such as in modules and sequences.
// See <uvm_report_error>, <uvm_report_warning>, and other global
// methods.
//
//
// The ~uvm_top~ instance checks during the end_of_elaboration phase if any errors have
// been generated so far. If errors are found a UVM_FATAL error is being generated as result
// so that the simulation will not continue to the start_of_simulation_phase.
//

//------------------------------------------------------------------------------

module uvm.base.uvm_root;

// typedef class uvm_cmdline_processor;
import uvm.base.uvm_async_lock: uvm_async_lock, uvm_async_event;
import uvm.base.uvm_component:  uvm_component;
import uvm.base.uvm_cmdline_processor: uvm_cmdline_processor;
import uvm.base.uvm_report_handler: uvm_report_handler;
import uvm.base.uvm_entity: uvm_entity_base;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_object_globals: UVM_FILE, m_uvm_core_state,
  uvm_core_state;
import uvm.base.uvm_objection: uvm_objection;
import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_run_test_callback: uvm_run_test_callback;
import uvm.base.uvm_global_defines;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_version;

import uvm.meta.misc;
import uvm.meta.meta;

import esdl.base.core;
import esdl.data.queue;

import esdl.rand.misc: _esdl__Norand;

import std.conv;
import std.format;
import std.string: format;

import core.sync.semaphore: Semaphore;


interface uvm_root_intf
{
  uvm_entity_base get_entity();
  RootEntity get_root_entity();
  void set_thread_context();
  void print_header();
  void initial();
  void run_test(string test_name="");
  void set_timeout(Time timeout, bool overridable=true);  uvm_component find(string comp_match);
  void find_all(string comp_match, ref Queue!uvm_component comps,
		uvm_component comp=null);
  void find_all(string comp_match, ref uvm_component[] comps,
		uvm_component comp=null);
  uvm_component[] find_all(string comp_match, uvm_component comp=null);
  void print_topology(uvm_printer printer=null);
  SimTime phase_sim_timeout();
  void register_async_lock(uvm_async_lock lock);
  void register_async_event(uvm_async_event event);
  void finalize();
}

// Class: uvm_root
// 
//| class uvm_root extends uvm_component
//
// Implementation of the uvm_root class, as defined
// in 1800.2-2017 Section F.7

//@uvm-ieee 1800.2-2017 manual F.7
class uvm_root: uvm_component, uvm_root_intf, _esdl__Norand
{
  // adding the mixin here results in gotchas if the user does not add
  // the mixin in the derived classes
  // mixin uvm_component_essentials;
  
  mixin (uvm_sync_string);

  // SV implementation makes this a part of the run_test function
  private uvm_component uvm_test_top;

  @uvm_immutable_sync
  private uvm_entity_base _uvm_entity_instance;
  
  this() {
    synchronized (this) {
      super(true);
      _elab_done_semaphore = new Semaphore(); // count 0
    }
  }

  // initialize gets called by the uvm_entity_base constructor right
  // after calling uvm_root constructor
  void initialize(uvm_entity_base base) {
    import uvm.base.uvm_domain;
    synchronized (this) {

      // For error reporting purposes, we need to construct this first.
      uvm_report_handler rh = new uvm_report_handler("reporter");
      set_report_handler(rh);

      // no need for this code block since we do not have explicit uvm_init
      
      // Checking/Setting this here makes it much harder to
      // trick uvm_init into infinite recursions
      //    if (m_inst !is null) {
      // 	uvm_fatal_context("UVM/ROOT/MULTI",
      // 			  "Attempting to construct multiple roots",
      // 			  m_inst);
      // 	return;
      //    }
      // m_inst = this;
      
      _clp = uvm_cmdline_processor.get_inst();


      // following three lines are vlang specific
      _uvm_entity_instance = base;
      // uvm_entity_base._uvm_entity_instance;
      _phase_timeout = new WithEvent!Time("_phase_timeout",
					  UVM_DEFAULT_TIMEOUT, base);
      _m_phase_all_done = new WithEvent!bool("_m_phase_all_done", base);

      // _m_domain is declared in uvm_component
      m_domain = uvm_domain.get_uvm_domain();
    }
  }
  
  override uvm_entity_base get_entity() {
    return _uvm_entity_instance;
  }

  override RootEntity get_root_entity() {
    return this.get_entity.getRoot();
  }

  override void set_thread_context() {
    uvm_entity_instance.set_thread_context();
  }


  // Function -- NODOCS -- get()
  // Static accessor for <uvm_root>.
  //
  // The static accessor is provided as a convenience wrapper
  // around retrieving the root via the <uvm_coreservice_t::get_root>
  // method.
  //
  // | // Using the uvm_coreservice_t:
  // | uvm_coreservice_t cs;
  // | uvm_root r;
  // | cs = uvm_coreservice_t::get();
  // | r = cs.get_root();
  // |
  // | // Not using the uvm_coreservice_t:
  // | uvm_root r;
  // | r = uvm_root::get();

  static uvm_root get() {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root root = cs.get_root();
    return root;
  }

  // This function is retuired to get the uvm_root of any
  // uvm_component by way of traversing component hierarchy
  override uvm_root_intf get_root() {
    return this;
  }

  @uvm_immutable_sync
  uvm_cmdline_processor _clp;

  void print_header() {
    report_header();
    // This sets up the global verbosity. Other command line args may
    // change individual component verbosity.
    m_check_verbosity();
  }
  
  // this function can be overridden by the user
  void initial() {
    // run_test would be called in an override of initial function
    // run_test();
  }

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }


  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Simulation Control
  //----------------------------------------------------------------------------


  // Task -- NODOCS -- run_test
  //
  // Phases all components through all registered phases. If the optional
  // test_name argument is provided, or if a command-line plusarg,
  // +UVM_TESTNAME=TEST_NAME, is found, then the specified component is created
  // just prior to phasing. The test may contain new verification components or
  // the entire testbench, in which case the test and testbench can be chosen from
  // the command line without forcing recompilation. If the global (package)
  // variable, finish_on_completion, is set, then $finish is called after
  // phasing completes.

  // run_test
  // --------

  // task
  void run_test(string test_name="") {
    import uvm.base.uvm_config_db;
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_report_server;
    import uvm.base.uvm_factory;
    import uvm.base.uvm_object_globals;

    // Moved to uvm_root class
    // uvm_component uvm_test_top;

    uvm_run_test_callback.m_do_pre_run_test();

    uvm_factory factory = uvm_factory.get();

    m_uvm_core_state = uvm_core_state.UVM_CORE_PRE_RUN;

    bool testname_plusarg = false;

    // Set up the process that decouples the thread that drops objections from
    // the process that processes drop/all_dropped objections. Thus, if the
    // original calling thread (the "dropper") gets killed, it does not affect
    // drain-time and propagation of the drop up the hierarchy.
    // Needs to be done in run_test since it needs to be in an
    // initial block to fork a process.

    uvm_objection.m_init_objections();

    // dump cmdline args BEFORE the args are being used
    m_do_dump_args();

    // `ifndef UVM_NO_DPI

    // Retrieve the test names provided on the command line.  Command line
    // overrides the argument.
    string[] test_names;
    size_t test_name_count = clp.get_arg_values("+UVM_TESTNAME=", test_names);

    if (test_name_count == 0) {
      import uvm.dpi.uvm_dpi_utils;
      // look for DPI
      if (uvm_dpi_is_usable()) {
	// Use DPI function to get the name of the test
	string testname = uvm_dpi_utils.instance().get_testname();
	// string test_name = uvm_dpi_utils.instance().get_testname();
	if (testname != "") {
	  test_names ~= testname;
	  test_name_count = 1;
	}
      }
    }

    // If at least one, use first in queue.
    if (test_name_count > 0) {
      test_name = test_names[0];
      testname_plusarg = true;
    }

    // If multiple, provided the warning giving the number, which one will be
    // used and the complete list.
    if (test_name_count > 1) {
      string test_list;
      string sep;
      for (size_t i = 0; i < test_names.length; ++i) {
	if (i !is 0)
	  sep = ", ";
	test_list ~= sep ~ test_names[i];
      }
      uvm_report_warning("MULTTST",
			 format("Multiple (%0d) +UVM_TESTNAME arguments " ~
				"provided on the command line.  '%s' will " ~
				"be used.  Provided list: %s.",
				test_name_count, test_name, test_list),
			 uvm_verbosity.UVM_NONE);
    }

    // if test now defined, create it using common factory
    if (test_name != "") {
      if ("uvm_test_top" in m_children) {
	uvm_report_fatal("TTINST",
			 "An uvm_test_top already exists via a " ~
			 "previous call to run_test", uvm_verbosity.UVM_NONE);
	wait(0); // #0 // forces shutdown because $finish is forked
      }

      uvm_test_top = cast (uvm_component)
	factory.create_component_by_name(test_name, "", "uvm_test_top", this);

      if (uvm_test_top is null) {
	string msg = testname_plusarg ?
	  "command line +UVM_TESTNAME=" ~ test_name :
	  "call to run_test(" ~ test_name ~ ")";
	uvm_report_fatal("INVTST", "Requested test from " ~ msg ~ " not found.",
			 uvm_verbosity.UVM_NONE);
      }
      // inherit multicore config from root
      uvm_test_top._esdl__multicoreConfig = _esdl__multicoreConfig;
    }

    if (m_children.length is 0) {
      uvm_report_fatal("NOCOMP",
    		       "No components instantiated. You must either " ~
    		       "instantiate at least one component before " ~
    		       "calling run_test or use run_test to do so. " ~
    		       "To run a test using run_test, use +UVM_TESTNAME " ~
    		       "or supply the test name in the argument to " ~
    		       "run_test(). Exiting simulation.", uvm_verbosity.UVM_NONE);
      return;
    }

    if (test_name == "")
      uvm_report_info("RNTST", "Running test ...", uvm_verbosity.UVM_LOW);
    else if (test_name == uvm_test_top.get_type_name())
      uvm_report_info("RNTST", "Running test " ~ test_name ~ "...",
		      uvm_verbosity.UVM_LOW);
    else
      uvm_report_info("RNTST", "Running test " ~ uvm_test_top.get_type_name() ~
		      " (via factory override for test \"" ~ test_name ~
		      "\")...", uvm_verbosity.UVM_LOW);

    // phase runner, isolated from calling process
    // Process phase_runner_proc; // store thread forked below for final cleanup
    Process phase_runner_proc = fork!("uvm_root/phase_runner_proc")({
	uvm_phase.m_run_phases();
      });
    // fork({
    //	// spawn the phase runner task
    //	phase_runner_proc = Process.self();
    //	uvm_phase.m_run_phases();
    //   });
    wait(0); // #0; // let the phase runner start

    while (m_phase_all_done is false) {
      m_phase_all_done.wait();
    }

    m_uvm_core_state = uvm_core_state.UVM_CORE_POST_RUN;

    // clean up after ourselves
    phase_runner_proc.abort();

    uvm_report_server l_rs = uvm_report_server.get_server();


    uvm_run_test_callback.m_do_post_run_test();

    l_rs.report_summarize();

    m_uvm_core_state = uvm_core_state.UVM_CORE_FINISHED;

    // disable all locks that have been register with this root
    this.finalize();

    unlockStage();
    
    if (get_finish_on_completion()) {
      debug(FINISH) {
	import std.stdio;
	writeln("finish_on_completion");
      }
      withdrawCaveat();
      // finish();
    }
  }

  // Function -- NODOCS -- die
  //
  // This method is called by the report server if a report reaches the maximum
  // quit count or has a UVM_EXIT action associated with it, e.g., as with
  // fatal errors.
  //
  // Calls the <uvm_component::pre_abort()> method
  // on the entire <uvm_component> hierarchy in a bottom-up fashion.
  // It then calls <uvm_report_server::report_summarize> and terminates the simulation
  // with ~$finish~.

  void die() {
    import uvm.base.uvm_report_server;
    uvm_report_server l_rs = uvm_report_server.get_server();
    // do the pre_abort callbacks
    

    m_uvm_core_state = uvm_core_state.UVM_CORE_PRE_ABORT;


    m_do_pre_abort();

    uvm_run_test_callback.m_do_pre_abort();

    l_rs.report_summarize();

    m_uvm_core_state = uvm_core_state.UVM_CORE_ABORTED;
    
    this.finalize();

    unlockStage();
    
    withdrawCaveat();
    finish();
  }
  
  // Function -- NODOCS -- set_timeout
  //
  // Specifies the timeout for the simulation. Default is <`UVM_DEFAULT_TIMEOUT>
  //
  // The timeout is simply the maximum absolute simulation time allowed before a
  // ~FATAL~ occurs.  If the timeout is set to 20ns, then the simulation must end
  // before 20ns, or a ~FATAL~ timeout will occur.
  //
  // This is provided so that the user can prevent the simulation from potentially
  // consuming too many resources (Disk, Memory, CPU, etc) when the testbench is
  // essentially hung.
  //
  //

  @uvm_private_sync
  private bool _m_uvm_timeout_overridable = true;

  void set_timeout(Time timeout, bool overridable=true) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      import std.string;
      if (_m_uvm_timeout_overridable is false) {
	uvm_report_info("NOTIMOUTOVR",
			format("The global timeout setting of %0d is not " ~
			       "overridable to %0d due to a previous setting.",
			       phase_timeout, timeout), uvm_verbosity.UVM_NONE);
	return;
      }
      _m_uvm_timeout_overridable = overridable;
      _phase_timeout = timeout;
    }
  }


  // Variable -- NODOCS -- finish_on_completion
  //
  // If set, then run_test will call $finish after all phases are executed.


  @uvm_private_sync
  private bool _finish_on_completion = true;

  // Function -- NODOCS -- get_finish_on_completion
   
  bool get_finish_on_completion() {
    synchronized (this) {
      return _finish_on_completion;
    }
  }

  // Function -- NODOCS -- set_finish_on_completion

  void set_finish_on_completion(bool f) {
    synchronized (this) {
      _finish_on_completion = f;
    }
  }

  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Topology
  //----------------------------------------------------------------------------


  // Function -- NODOCS -- find

  uvm_component find(string comp_match) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      import std.string: format;
      uvm_component[] comp_list;

      find_all(comp_match, comp_list);

      if (comp_list.length > 1) {
	uvm_report_warning("MMATCH",
			   format("Found %0d components matching '%s'." ~
				  " Returning first match, %0s.",
				  comp_list.length, comp_match,
				  comp_list[0].get_full_name()), uvm_verbosity.UVM_NONE);
      }

      if (comp_list.length is 0) {
	uvm_report_warning("CMPNFD",
			   "Component matching '" ~comp_match ~
			   "' was not found in the list of uvm_components",
			   uvm_verbosity.UVM_NONE);
	return null;
      }
      return comp_list[0];
    }
  }


  // Function -- NODOCS -- find_all
  //
  // Returns the component handle (find) or list of components handles
  // (find_all) matching a given string. The string may contain the wildcards,
  // * and ?. Strings beginning with '.' are absolute path names. If the optional
  // argument comp is provided, then search begins from that component down
  // (default=all components).

  void find_all(string comp_match, ref Queue!uvm_component comps,
		uvm_component comp=null) {
    synchronized (this) {
      if (comp is null)
	comp = this;
      m_find_all_recurse(comp_match, comps, comp);
    }
  }

  void find_all(string comp_match, ref uvm_component[] comps,
		uvm_component comp=null) {
    synchronized (this) {
      if (comp is null)
	comp = this;
      m_find_all_recurse(comp_match, comps, comp);
    }
  }

  uvm_component[] find_all(string comp_match, uvm_component comp=null) {
    synchronized (this) {
      uvm_component[] comps;
      if (comp is null)
	comp = this;
      m_find_all_recurse(comp_match, comps, comp);
      return comps;
    }
  }

  // Function -- NODOCS -- print_topology
  //
  // Print the verification environment's component topology. The
  // ~printer~ is a <uvm_printer> object that controls the format
  // of the topology printout; a ~null~ printer prints with the
  // default output.

  void print_topology(uvm_printer printer=null) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      if (m_children.length is 0) {
	uvm_report_warning("EMTCOMP", "print_topology - No UVM " ~
			   "components to print.", uvm_verbosity.UVM_NONE);
	return;
      }

      if (printer is null)
	printer = uvm_printer.get_default();

      uvm_info("UVMTOP", "UVM testbench topology:", uvm_verbosity.UVM_NONE);
      print(printer);
    }
  }


  // Variable -- NODOCS -- enable_print_topology
  //
  // If set, then the entire testbench topology is printed just after completion
  // of the end_of_elaboration phase.

  @uvm_public_sync
  private bool _enable_print_topology = false;

   
  // Function: set_enable_print_topology
  //
  //| function void set_enable_print_topology (bit enable)
  //
  // Sets the variable to enable printing the entire testbench topology just after completion
  // of the end_of_elaboration phase.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  void set_enable_print_topology(bool enable) {
    synchronized (this) {
      _enable_print_topology = enable;
    }
  }

  // Function: get_enable_print_topology
  //
  //| function bit get_enable_print_topology()
  //
  // Gets the variable to enable printing the entire testbench topology just after completion.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  bool get_enable_print_topology() {
    synchronized (this) {
      return _enable_print_topology;
    }
  }


  // Variable- phase_timeout
  //
  // Specifies the timeout for the run phase. Default is `UVM_DEFAULT_TIMEOUT

  // private
  @uvm_immutable_sync
  private WithEvent!Time _phase_timeout;


  SimTime phase_sim_timeout() {
    synchronized (this) {
      return SimTime(_uvm_entity_instance, _phase_timeout);
    }
  }

  // PRIVATE members

  void m_find_all_recurse(string comp_match,
			  ref Queue!uvm_component comps,
			  uvm_component comp=null) {
    synchronized (this) {
      string name;

      foreach (child; comp.get_children) {
	this.m_find_all_recurse(comp_match, comps, child);
      }
      import uvm.base.uvm_globals: uvm_is_match;
      if (uvm_is_match(comp_match, comp.get_full_name()) &&
	 comp.get_name() != "") /* uvm_top */
	comps.pushBack(comp);
    }
  }

  void m_find_all_recurse(string comp_match,
			  ref uvm_component[] comps,
			  uvm_component comp=null) {
    synchronized (this) {
      string name;

      foreach (child; comp.get_children) {
	this.m_find_all_recurse(comp_match, comps, child);
      }
      import uvm.base.uvm_globals: uvm_is_match;
      if (uvm_is_match(comp_match, comp.get_full_name()) &&
	 comp.get_name() != "") /* uvm_top */ {
	comps ~= comp;
      }
    }
  }


  //   extern protected virtual function bit m_add_child(uvm_component child);

  // m_add_child
  // -----------

  // Add to the top levels array
  override bool m_add_child(uvm_component child) {
    synchronized (this) {
      if (super.m_add_child(child)) {
	return true;
      }
      else
	return false;
    }
  }

  //   extern function void build_phase(uvm_phase phase);

  // build_phase
  // -----

  override void build_phase(uvm_phase phase) {

    super.build_phase(phase);

    m_set_cl_msg_args();

    m_do_verbosity_settings();
    m_do_timeout_settings();
    m_do_factory_settings();
    m_do_config_settings();
    m_do_max_quit_settings();
  }

  // override void setup_phase(uvm_phase phase) {
  //   foreach (child; get_children()) {
  //     child.uvm__auto_elab();
  //   }
  // }

  override ParContext _esdl__parInheritFrom() {
    return Process.self().getParentEntity();
  }

  //   extern local function void m_do_verbosity_settings();
  // m_do_verbosity_settings
  // -----------------------

  void m_do_verbosity_settings() {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;

    string[] set_verbosity_settings;
    string[] split_vals;

    // Retrieve them all into set_verbosity_settings
    clp.get_arg_values("+uvm_set_verbosity=", set_verbosity_settings);

    foreach (i, setting; set_verbosity_settings) {
      uvm_split_string(setting, ',', split_vals);
      if (split_vals.length < 4 || split_vals.length > 5) {
	uvm_report_warning("INVLCMDARGS",
			   format("Invalid number of arguments found on " ~
				  "the command line for setting " ~
				  "'+uvm_set_verbosity=%s'.  Setting ignored.",
				  setting), uvm_verbosity.UVM_NONE); // , "", "");
      }
      uvm_verbosity tmp_verb;
      // Invalid verbosity
      if (!clp.m_convert_verb(split_vals[2], tmp_verb)) {
	uvm_report_warning("INVLCMDVERB",
			   format("Invalid verbosity found on the command " ~
				  "line for setting '%s'.",
				  setting), uvm_verbosity.UVM_NONE); // , "", "");
      }
    }
  }



  //   extern local function void m_do_timeout_settings();
  // m_do_timeout_settings
  // ---------------------

  void m_do_timeout_settings() {
    // synchronized (this) {
    // declared in SV version -- redundant
    // string[] split_timeout;
    import uvm.base.uvm_object_globals;

    string[] timeout_settings;
    size_t timeout_count = clp.get_arg_values("+UVM_TIMEOUT=", timeout_settings);

    if (timeout_count == 0)
      return;
    else {
      string timeout = timeout_settings[0];
      if (timeout_count > 1) {
	string timeout_list;
	string sep;
	for (size_t i = 0; i < timeout_settings.length; ++i) {
	  if (i !is 0)
	    sep = "; ";
	  timeout_list ~= sep ~ timeout_settings[i];
	}
	uvm_report_warning("MULTTIMOUT",
			   format("Multiple (%0d) +UVM_TIMEOUT arguments " ~
				  "provided on the command line.  '%s' will " ~
				  "be used.  Provided list: %s.",
				  timeout_count, timeout, timeout_list),
			   uvm_verbosity.UVM_NONE);
      }
      uvm_report_info("TIMOUTSET",
		      format("'+UVM_TIMEOUT=%s' provided on the command " ~
			     "line is being applied.", timeout), uvm_verbosity.UVM_NONE);

      uint timeout_int;
      string override_spec;
      formattedRead(timeout, "%d,%s", &timeout_int, &override_spec);

      switch (override_spec) {
      case "YES": set_timeout(timeout_int.nsec, true); break;
      case "NO": set_timeout(timeout_int.nsec, false); break;
      default : set_timeout(timeout_int.nsec, true); break;
      }
    }
    // }
  }


  //   extern local function void m_do_factory_settings();
  // m_do_factory_settings
  // ---------------------

  void m_do_factory_settings() {
    string[] args;

    clp.get_arg_matches("/^\\+(UVM_SET_INST_OVERRIDE|uvm_set_inst_override)=/",
			args);
    foreach (i, arg; args) {
      m_process_inst_override(arg[23..$]);
    }
    clp.get_arg_matches("/^\\+(UVM_SET_TYPE_OVERRIDE|uvm_set_type_override)=/",
			args);
    foreach (i, arg; args) {
      m_process_type_override(arg[23..$]);
    }
  }

  //   extern local function void m_process_inst_override(string ovr);
  // m_process_inst_override
  // -----------------------

  void m_process_inst_override(string ovr) {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_globals;
    import uvm.base.uvm_factory;
    import uvm.base.uvm_object_globals;
    string[] split_val;

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();

    uvm_split_string(ovr, ',', split_val);

    if (split_val.length !is 3 ) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid setting for +uvm_set_inst_override=" ~ ovr ~
		       ", setting must specify <requested_type>," ~
		       "<override_type>,<instance_path>", uvm_verbosity.UVM_NONE);
    }
    uvm_report_info("INSTOVR",
		    "Applying instance override from the command line: " ~
		    "+uvm_set_inst_override=" ~ ovr, uvm_verbosity.UVM_NONE);
    factory.set_inst_override_by_name(split_val[0], split_val[1], split_val[2]);
  }

  //   extern local function void m_process_type_override(string ovr);
  // m_process_type_override
  // -----------------------

  void m_process_type_override(string ovr) {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_globals;
    import uvm.base.uvm_factory;
    import uvm.base.uvm_object_globals;
    string[] split_val;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();

    uvm_split_string(ovr, ',', split_val);

    if (split_val.length > 3 || split_val.length < 2) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid setting for +uvm_set_type_override=" ~ ovr ~
		       ", setting must specify <requested_type>," ~
		       "<override_type>[,<replace>]", uvm_verbosity.UVM_NONE);
      return;
    }

    // Replace arg is optional. If set, must be 0 or 1
    bool replace = true;
    if (split_val.length == 3) {
      if (split_val[2] == "0") replace =  false;
      else if (split_val[2] == "1") replace = true;
      else {
	uvm_report_error("UVM_CMDLINE_PROC", "Invalid replace arg for " ~
			 "+uvm_set_type_override=" ~ ovr ~
			 " value must be 0 or 1", uvm_verbosity.UVM_NONE);
	return;
      }
    }

    uvm_report_info("UVM_CMDLINE_PROC", "Applying type override from " ~
		    "the command line: +uvm_set_type_override=" ~ ovr,
		    uvm_verbosity.UVM_NONE);
    factory.set_type_override_by_name(split_val[0], split_val[1], replace);
  }


  //   extern local function void m_do_config_settings();
  // m_do_config_settings
  // --------------------

  void m_do_config_settings() {
    string[] args;
    clp.get_arg_matches("/^\\+(UVM_SET_CONFIG_INT|uvm_set_config_int)=/",
			args);
    foreach (i, arg; args) {
      m_process_config(arg[20..$], true);
    }
    clp.get_arg_matches("/^\\+(UVM_SET_CONFIG_STRING|uvm_set_config_string)=/",
			args);
    foreach (i, arg; args) {
      m_process_config(arg[23..$], false);
    }

    clp.get_arg_matches("/^\\+(UVM_SET_DEFAULT_SEQUENCE|uvm_set_default_sequence)=/", args);
    foreach (i, arg; args) {
      m_process_default_sequence(arg[26..$]);
    }
  }

  //   extern local function void m_do_max_quit_settings();
  // m_do_max_quit_settings
  // ----------------------

  void m_do_max_quit_settings() {
    import uvm.base.uvm_report_server;
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    uvm_report_server srvr = uvm_report_server.get_server();
    string[] max_quit_settings;
    size_t max_quit_count = clp.get_arg_values("+UVM_MAX_QUIT_COUNT=",
					       max_quit_settings);
    if (max_quit_count is 0)
      return;
    else {
      string max_quit = max_quit_settings[0];
      if (max_quit_count > 1) {
	string sep;
	string max_quit_list;
	for (size_t i = 0; i < max_quit_settings.length; ++i) {
	  if (i !is 0)
	    sep = "; ";
	  max_quit_list ~= sep ~ max_quit_settings[i];
	}
	uvm_report_warning("MULTMAXQUIT",
			   format("Multiple (%0d) +UVM_MAX_QUIT_COUNT " ~
				  "arguments provided on the command line." ~
				  "  '%s' will be used.  Provided list: %s.",
				  max_quit_count, max_quit, max_quit_list),
			   uvm_verbosity.UVM_NONE);
      }
      uvm_report_info("MAXQUITSET",
		      format("'+UVM_MAX_QUIT_COUNT=%s' provided on the " ~
			     "command line is being applied.", max_quit),
		      uvm_verbosity.UVM_NONE);
      string[] split_max_quit;
      uvm_split_string(max_quit, ',', split_max_quit);
      int max_quit_int = parse!int(split_max_quit[0]); // .atoi();
      switch (split_max_quit[1]) {
      case "YES": srvr.set_max_quit_count(max_quit_int, 1); break;
      case "NO" : srvr.set_max_quit_count(max_quit_int, 0); break;
      default   : srvr.set_max_quit_count(max_quit_int, 1); break;
      }
    }
  }

  //   extern local function void m_do_dump_args();
  // m_do_dump_args
  // --------------

  void m_do_dump_args() {
    import uvm.base.uvm_object_globals;
    string[] dump_args;
    string[] all_args;
    if (clp.get_arg_matches(`\+UVM_DUMP_CMDLINE_ARGS`, dump_args)) {
      clp.get_args(all_args);
      foreach (idx, arg; all_args) {
	uvm_report_info("DUMPARGS", format("idx=%0d arg=[%s]",
					   idx, arg), uvm_verbosity.UVM_NONE);
      }
    }
  }


  // extern local function void m_process_config(string cfg, bit is_int);
  // m_process_config
  // ----------------

  void m_process_config(string cfg, bool is_int) {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_config_db;
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    int v;
    string[] split_val;

    uvm_split_string(cfg, ',', split_val);
    if (split_val.length is 1) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid +uvm_set_config command\"" ~ cfg ~
		       "\" missing field and value: component is \"" ~
		       split_val[0] ~ "\"", uvm_verbosity.UVM_NONE);
      return;
    }

    if (split_val.length is 2) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid +uvm_set_config command\"" ~ cfg ~
		       "\" missing value: component is \"" ~ split_val[0] ~
		       "\"  field is \"" ~ split_val[1] ~ "\"", uvm_verbosity.UVM_NONE);
      return;
    }

    if (split_val.length > 3) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       format("Invalid +uvm_set_config command\"%s\" : " ~
			      "expected only 3 fields (component, field " ~
			      "and value).", cfg), uvm_verbosity.UVM_NONE);
      return;
    }

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root m_uvm_top = cs.get_root();

    if (is_int) {
      if (split_val[2].length > 2) {
	string base = split_val[2][0..2];
	string extval = split_val[2][2..$];
	switch (base) {
	case "'b":
	  // case "0b": v = parse!(int, 2)(extval); break; // extval.atobin();
	case "0b": formattedRead(extval, "%b", &v); break;
	// case "'o": v = parse!(int, 8)(extval); break; // extval.atooct();
	case "'o": formattedRead(extval, "%o", &v); break;
	case "'d": v = parse!(int)(extval); break; // extval.atoi();
	case "'h":
	case "'x":
	  // case "0x": v = parse!(int, 16)(extval); break; // extval.atohex();
	case "0x": v = formattedRead(extval, "%x", &v); break;
	default : v = parse!(int)(split_val[2]); break; // split_val[2].atoi();
	}
      }
      else {
	v = parse!(int)(split_val[2]); // split_val[2].atoi();
      }

      uvm_report_info("UVM_CMDLINE_PROC",
		      "Applying config setting from the command line: " ~
		      "+uvm_set_config_int=" ~ cfg, uvm_verbosity.UVM_NONE);
      uvm_config_db!int.set(m_uvm_top, split_val[0], split_val[1], v);
    }
    else {
      uvm_report_info("UVM_CMDLINE_PROC",
		      "Applying config setting from the command line: " ~
		      "+uvm_set_config_string=" ~ cfg, uvm_verbosity.UVM_NONE);
      uvm_config_db!string.set(m_uvm_top, split_val[0], split_val[1], split_val[2]);
    }
  }


  // m_process_default_sequence
  // ----------------

  void m_process_default_sequence(string cfg) {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_config_db;
    import uvm.base.uvm_globals;
    import uvm.base.uvm_factory;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      string[] split_val;
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root m_uvm_top = cs.get_root();   
      uvm_factory f = cs.get_factory();
      uvm_object_wrapper w;

      uvm_split_string(cfg, ',', split_val);
      if (split_val.length == 1) {
	uvm_report_error("UVM_CMDLINE_PROC",
			 "Invalid +uvm_set_default_sequence command\"" ~
			 cfg ~ "\" missing phase and type: sequencer is \"" ~
			 split_val[0] ~ "\"", uvm_verbosity.UVM_NONE);
	return;
      }

      if (split_val.length == 2) {
	uvm_report_error("UVM_CMDLINE_PROC",
			 "Invalid +uvm_set_default_sequence command\"" ~ cfg ~
			 "\" missing type: sequencer is \"" ~ split_val[0] ~
			 "\"  phase is \"" ~ split_val[1] ~ "\"",
			 uvm_verbosity.UVM_NONE);
	return;
      }

      if (split_val.length > 3) {
	uvm_report_error("UVM_CMDLINE_PROC", 
			 format("Invalid +uvm_set_default_sequence command" ~
				"\"%s\" : expected only 3 fields (sequencer" ~
				", phase and type).", cfg), uvm_verbosity.UVM_NONE);
      }

      w = f.find_wrapper_by_name(split_val[2]);
      if (w is null) {
	uvm_report_error("UVM_CMDLINE_PROC",
			 format("Invalid type '%s' provided to +" ~
				"uvm_set_default_sequence", split_val[2]),
			 uvm_verbosity.UVM_NONE);
	return;
      }
      else {
	uvm_report_info("UVM_CMDLINE_PROC",
			"Setting default sequence from the command " ~
			"line: +uvm_set_default_sequence=" ~ cfg, uvm_verbosity.UVM_NONE);
	uvm_config_db!(uvm_object_wrapper).set(this, split_val[0] ~
					       "." ~ split_val[1],
					       "default_sequence", w);
      }
    }
  }

  //   extern function void m_check_verbosity();
  // m_check_verbosity
  // ----------------

  void m_check_verbosity() {
    import uvm.base.uvm_object_globals;

    string verb_string;
    string[] verb_settings;
    int plusarg;
    uvm_verbosity verbosity = uvm_verbosity.UVM_MEDIUM;

    // Retrieve the verbosities provided on the command line.
    size_t verb_count = clp.get_arg_values(`+UVM_VERBOSITY=`, verb_settings);

    // If none provided, provide message about the default being used.
    //if (verb_count is 0)
    //  uvm_report_info("DEFVERB", ("No verbosity specified on the
    //  command line.  Using the default: UVM_MEDIUM"), UVM_NONE);

    // If at least one, use the first.
    if (verb_count > 0) {
      verb_string = verb_settings[0];
      plusarg = 1;
    }

    // If more than one, provide the warning stating how many, which one will
    // be used and the complete list.
    if (verb_count > 1) {
      string verb_list;
      string sep;
      foreach (i, setting; verb_settings) {
	if (i !is 0)
	  sep = ", ";
	verb_list ~= sep ~ setting;
      }

      uvm_report_warning("MULTVERB",
			 format("Multiple (%0d) +UVM_VERBOSITY arguments " ~
				"provided on the command line.  '%s' " ~
				"will be used.  Provided list: %s.",
				verb_count, verb_string, verb_list),
			 uvm_verbosity.UVM_NONE);
    }

    if (plusarg is 1) {
      switch (verb_string) {
      case "UVM_NONE"    : verbosity = uvm_verbosity.UVM_NONE; break;
      case "NONE"        : verbosity = uvm_verbosity.UVM_NONE; break;
      case "UVM_LOW"     : verbosity = uvm_verbosity.UVM_LOW; break;
      case "LOW"         : verbosity = uvm_verbosity.UVM_LOW; break;
      case "UVM_MEDIUM"  : verbosity = uvm_verbosity.UVM_MEDIUM; break;
      case "MEDIUM"      : verbosity = uvm_verbosity.UVM_MEDIUM; break;
      case "UVM_HIGH"    : verbosity = uvm_verbosity.UVM_HIGH; break;
      case "HIGH"        : verbosity = uvm_verbosity.UVM_HIGH; break;
      case "UVM_FULL"    : verbosity = uvm_verbosity.UVM_FULL; break;
      case "FULL"        : verbosity = uvm_verbosity.UVM_FULL; break;
      case "UVM_DEBUG"   : verbosity = uvm_verbosity.UVM_DEBUG; break;
      case "DEBUG"       : verbosity = uvm_verbosity.UVM_DEBUG; break;
      default       : {
	verbosity = cast (uvm_verbosity) parse!int(verb_string); // .atoi();
	if (verbosity > 0) {
	  uvm_report_info("NSTVERB",
			  format("Non-standard verbosity value, using " ~
				 "provided '%0d'.", verbosity), uvm_verbosity.UVM_NONE);
	}
	if (verbosity is 0) {
	  verbosity = uvm_verbosity.UVM_MEDIUM;
	  uvm_report_warning("ILLVERB",
			     "Illegal verbosity value, using default " ~
			     "of UVM_MEDIUM.", uvm_verbosity.UVM_NONE);
	}
      }
      }
    }

    set_report_verbosity_level_hier(verbosity);

  }

  void m_check_uvm_field_flag_size() {
    // SV macro definition specific
    // do nothing for now
  }

  
  void report_header(UVM_FILE file = 0) {
    import uvm.base.uvm_report_server;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      string q;
      uvm_report_server srvr;
      uvm_cmdline_processor clp;
      string[] args;

      srvr = uvm_report_server.get_server();
      clp = uvm_cmdline_processor.get_inst();

      if (clp.get_arg_matches("\\+UVM_NO_RELNOTES", args)) return;

      if (! _m_relnotes_done) {
	q ~= "\n  ***********       IMPORTANT RELEASE NOTES         ************\n";
	_m_relnotes_done = true;

	q ~= "\n  This implementation of the UVM Library deviates from the 1800.2-2017\n";
	q ~= "  standard.  See the DEVIATIONS.md file contained in the release\n";
	q ~= "  for more details.\n";
      

      } // !m_relnotes_done

      q ~= "\n----------------------------------------------------------------\n";
      q ~= uvm_revision_string() ~ "\n";
      q ~= "\n";
      q ~= "All copyright owners for this kit are listed in NOTICE.txt\n";
      q ~= "All Rights Reserved Worldwide\n";
      q ~= "----------------------------------------------------------------\n";


      if (_m_relnotes_done) {
	q ~= "\n      (Specify +UVM_NO_RELNOTES to turn off this notice)\n";
      }

      uvm_info("UVM/RELNOTES", q, uvm_verbosity.UVM_LOW);
    }
  }


  //   // singleton handle
  //   __gshared private uvm_root m_inst;

  //   // For error checking
  //   extern virtual task run_phase(uvm_phase phase);
  // It is required that the run phase start at simulation time 0
  // TBD this looks wrong - taking advantage of uvm_root not doing anything else?
  // TBD move to phase_started callback?

  // task
  override void run_phase(uvm_phase phase) {
    // check that the commandline are took effect
    foreach (idx, cl_action; m_uvm_applied_cl_action) {
      if (cl_action.used == 0) {
	uvm_warning("INVLCMDARGS",
		    format("\"+uvm_set_action=%s\" never took effect" ~
			   " due to a mismatching component pattern",
			   cl_action.arg));
      }
    }

    foreach (idx, cl_sev; m_uvm_applied_cl_sev) {
      if (cl_sev.used == 0) {
	uvm_warning("INVLCMDARGS",
		    format("\"+uvm_set_severity=%s\" never took effect" ~
			   " due to a mismatching component pattern",
			   cl_sev.arg));
      }
    }
    
    if (getRootEntity().getSimTime() > 0) {
      uvm_fatal("RUNPHSTIME",
		"The run phase must start at time 0, current time is " ~
		format("%s", getRootEntity().getSimTime()) ~
		". No non-zero delays are allowed before run_test(), and" ~
		" pre-run user defined phases may not consume simulation" ~
		" time before the start of the run phase.");
    }
  }


  // phase_started
  // -------------
  // At end of elab phase we need to do tlm binding resolution.
  override void phase_started(uvm_phase phase) {
    import uvm.base.uvm_report_server;
    import uvm.base.uvm_domain;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      if (phase is end_of_elaboration_ph) {
	do_resolve_bindings();
	if (enable_print_topology) print_topology();
	uvm_report_server srvr = uvm_report_server.get_server();
	if (srvr.get_severity_count(uvm_severity.UVM_ERROR) > 0) {
	  uvm_report_fatal("BUILDERR", "stopping due to build errors", uvm_verbosity.UVM_NONE);
	}
      }
    }
  }

  @uvm_immutable_sync
  Semaphore _elab_done_semaphore;

  @uvm_private_sync
  bool _elab_done;

  override void phase_ended(uvm_phase phase) {
    import uvm.base.uvm_domain;
    if (phase is end_of_elaboration_ph) {
      synchronized (this) {
	elab_done = true;
	elab_done_semaphore.notify();
      }
    }
  }

  final void wait_for_end_of_elaboration() {
    while (elab_done is false) {
      elab_done_semaphore.wait();
    }
  }

  @uvm_immutable_sync
  WithEvent!bool _m_phase_all_done;

  // internal function not to be used
  // get the initialized singleton instance of uvm_root

  // Unlike SV version, uvm_root is not a singleton in Vlang -- we
  // instead detect what root the present caller needs using the
  // context of the request being made
  static uvm_root m_uvm_get_root() {
    auto uvm_entity_inst = uvm_entity_base.get();
    if (uvm_entity_inst is null)
      assert (false, "Null uvm_top");
    return uvm_entity_inst._get_uvm_root();
  }


  private bool _m_relnotes_done = false;

  override void end_of_elaboration_phase(uvm_phase phase) {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_traversal;
    synchronized (this) {
      auto p = new uvm_component_proxy("proxy");
      auto adapter = new uvm_top_down_visitor_adapter!uvm_component("adapter");
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_visitor!uvm_component v = cs.get_component_visitor();
      adapter.accept(this, v, p);
    }
  }


  override void uvm__auto_build() {
    super.uvm__auto_build();
    // if (m_children.length is 0) {
    //   uvm_fatal("NOCOMP",
    // 		"No components instantiated. You must either " ~
    // 		"instantiate at least one component before " ~
    // 		"calling run_test or use run_test to do so. " ~
    // 		"To run a test using run_test, use +UVM_TESTNAME " ~
    // 		"or supply the test name in the argument to " ~
    // 		"run_test(). Exiting simulation.");
    //   return;
    // }
  }

  override void set_name(string name) {
    super.set_root_name(name);
  }

  private uvm_async_lock[] _async_locks;
  
  final void register_async_lock(uvm_async_lock lock) {
    synchronized (this) {
      _async_locks ~= lock;
    }
  }

  private uvm_async_event[] _async_events;
  
  final void register_async_event(uvm_async_event event) {
    synchronized (this) {
      _async_events ~= event;
    }
  }

  final void finalize() {
    synchronized (this) {
      foreach (lock; _async_locks) {
	lock.disable();
      }
      foreach (event; _async_events) {
	event.disableWait();
      }
    }
  }
}
