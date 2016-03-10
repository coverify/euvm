//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2013      NVIDIA Corporation
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


//------------------------------------------------------------------------------
//
// CLASS: uvm_root
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

// typedef class uvm_test_done_objection;
// typedef class uvm_cmdline_processor;
import uvm.base.uvm_component; // uvm_component
import uvm.base.uvm_cmdline_processor; // uvm_component
import uvm.base.uvm_object_globals;
import uvm.base.uvm_global_defines;
import uvm.base.uvm_printer;
import uvm.base.uvm_factory;
import uvm.base.uvm_globals;
import uvm.base.uvm_objection;
import uvm.base.uvm_phase;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_report_object;
import uvm.base.uvm_report_server;
import uvm.base.uvm_domain;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_traversal;
import uvm.base.uvm_coreservice;
import uvm.base.uvm_config_db;
import uvm.base.uvm_version;

public import uvm.meta.misc;
import uvm.meta.meta;

import esdl.base.core;
import esdl.data.queue;

import std.conv;
import std.format;
import std.string: format;

import core.sync.semaphore: Semaphore;

//------------------------------------------------------------------------------
// Variable: uvm_top
//
// This is the top-level that governs phase execution and provides component
// search interface. See <uvm_root> for more information.
//------------------------------------------------------------------------------

uvm_root uvm_top() {
  auto root_entity_instance = uvm_root_entity_base.get(); // static function call
  if(root_entity_instance is null) {
    return null;
  }
  return root_entity_instance._get_uvm_root();
}

// This is where the uvm gets instantiated as part of the ESDL
// simulator. Unlike the SystemVerilog version where uvm_root is a
// singleton, we can have multiple instances of uvm_root, but each
// ESDL RootEntity could have only one instance of uvm_root.

class uvm_root_entity_base: Entity
{
  mixin uvm_sync;
  this() {
    synchronized(this) {
      _uvm_root_init_semaphore = new Semaphore(); // count 0
      // uvm_once has some events etc that need to know the context for init
      set_thread_context();
      _root_once = new uvm_root_once(this);
    }
  }

  // Only for use by the uvm_root constructor -- use nowhere else
  static private uvm_root_entity_base _root_entity_instance;

  // effectively immutable
  @uvm_immutable_sync
  private Semaphore _uvm_root_init_semaphore;

  // effectively immutable
  private uvm_root_once _root_once;
  
  uvm_root_once root_once() {
    return _root_once;
  }

  // do not give public access -- this function is to be called from
  // inside the uvm_root_once constructor -- just to make sure that it
  // is set since some of the uvm_once class instances require this
  // variable to be already set
  private void _set_root_once(uvm_root_once once) {
    synchronized(this) {
      // The assert below makes sure that this function is being
      // called only from the constructor (since the constructor also
      // sets _root_once variable) To make this variable effectively
      // immutable, it is important to ensure that this variable is
      // set from uvm_root_once constructor only
      assert(_root_once is null);
      _root_once = once;
    }
  }

  static uvm_root_entity_base get() {
    auto context = EntityIntf.getContextEntity();
    if(context !is null) {
      auto entity = cast(uvm_root_entity_base) context;
      assert(entity !is null);
      return entity;
    }
    return null;
  }

  abstract protected uvm_root _get_uvm_root();
  abstract uvm_root get_root();
  // The randomization seed passed from the top.
  // alias _get_uvm_root this;

  // This method would associate a free running thread to this UVM
  // ROOT instance -- this function can be called multiple times
  // within the same thread in order to switch context
  void set_thread_context() {
    auto proc = Process.self();
    if(proc !is null) {
      auto _entity = cast(uvm_root_entity_base) proc.getParentEntity();
      assert(_entity is null, "Default context already set to: " ~
	     _entity.getFullName());
    }
    this.setThreadContext();
  }
}

class uvm_root_entity(T): uvm_root_entity_base if(is(T: uvm_root))
  {
    mixin uvm_sync;
    
    // alias _get_uvm_root this;

    @uvm_private_sync
    bool _uvm_root_initialized;

    // The uvm_root instance corresponding to this RootEntity.
    // effectively immutable
    @uvm_immutable_sync
    private T _uvm_root_instance;

    this() {
      synchronized(this) {
	super();
	// set static variable that would later be used by uvm_root
	// constructor. Can not pass this instance as an argument to
	// the uvm_root constructor since the constructor has no
	// argument. If an argument is introduced, that will spoil
	// uvm_root user API.
	uvm_root_entity_base._root_entity_instance = this;
	_uvm_root_instance = new T();
	resetThreadContext();
      }
    }

    override void _esdl__postElab() {
      uvm_root_instance.set_root_name(getFullName() ~ ".(" ~
				      qualifiedTypeName!T ~ ")");
    }

    override protected T _get_uvm_root() {
      return uvm_root_instance;
    }

    // this is part of the public API
    // Make the uvm_root available only after the simulaion has
    // started and the uvm_root is ready to use
    override T get_root() {
      while(uvm_root_initialized is false) {
	uvm_root_init_semaphore.wait();
	uvm_root_init_semaphore.notify();
      }
      // expose the root_instance to the external world only after
      // elaboration is done
      uvm_root_instance.wait_for_end_of_elaboration();
      return uvm_root_instance;
    }

    void initial() {
      lockStage();
      // instatiating phases (part of once initialization) needs the
      // simulation to be running
      root_once.build_phases_once();
      fileCaveat();
      // init_domains can not be moved to the constructor since it
      // results in notification of some events, which can only
      // happen once the simulation starts
      uvm_root_instance.init_domains();
      wait(0);
      uvm_root_initialized = true;
      uvm_root_init_semaphore.notify();
      uvm_root_instance.initial();
    }

    Task!(initial) _init;

    void set_seed(uint seed) {
      synchronized(this) {
	if(_uvm_root_initialized) {
	  uvm_report_fatal("SEED",
			   "Method set_seed can not be called after" ~
			   " the simulation has started",
			   UVM_NONE);
	}
	root_once().set_seed(seed);
      }
    }
}

class uvm_root: uvm_component
{
  // adding the mixin here results in gotchas if the user does not add
  // the mixin in the derived classes
  // mixin uvm_component_utils;
  
  mixin uvm_sync;

  // SV implementation makes this a part of the run_test function
  @UVM_NO_AUTO
  uvm_component uvm_test_top;
  @uvm_immutable_sync
  private uvm_root_entity_base _uvm_root_entity_instance;
  
  this() {
    synchronized(this) {
      super();
      _elab_done_semaphore = new Semaphore(); // count 0

      // from static variable
      _uvm_root_entity_instance =
	uvm_root_entity_base._root_entity_instance;
      _phase_timeout = new WithEvent!Time(UVM_DEFAULT_TIMEOUT,
					  _uvm_root_entity_instance);
      _m_phase_all_done = new WithEvent!bool(_uvm_root_entity_instance);
      _clp = uvm_cmdline_processor.get_inst();
      m_rh.set_name("reporter");
      report_header();
      // This sets up the global verbosity. Other command line args may
      // change individual component verbosity.
      m_check_verbosity();
    }
  }

  override void set_thread_context() {
    uvm_root_entity_instance.set_thread_context();
  }


  // in the SV version these two lines are handled in
  // the uvm_root.get function
  void init_domains() {
    synchronized(this) {
      uvm_domain.get_common_domain(); // FIXME -- comment this line??
      m_domain = uvm_domain.get_uvm_domain();
    }
  }

  // uvm_root

  // Function: get()
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
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root root = cs.get_root();
    return root;
  }

  @uvm_immutable_sync
  uvm_cmdline_processor _clp;


  // this function can be overridden by the user
  void initial() {
    run_test();
  }

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }


  //----------------------------------------------------------------------------
  // Group: Simulation Control
  //----------------------------------------------------------------------------


  // Task: run_test
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
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();

    // Moved to uvm_root class
    // uvm_component uvm_test_top;

    bool testname_plusarg = false;

    // Set up the process that decouples the thread that drops objections from
    // the process that processes drop/all_dropped objections. Thus, if the
    // original calling thread (the "dropper") gets killed, it does not affect
    // drain-time and propagation of the drop up the hierarchy.
    // Needs to be done in run_test since it needs to be in an
    // initial block to fork a process.

    uvm_objection.m_init_objections();

    // `ifndef UVM_NO_DPI

    // Retrieve the test names provided on the command line.  Command line
    // overrides the argument.
    string[] test_names;
    size_t test_name_count = clp.get_arg_values("+UVM_TESTNAME=", test_names);

    // If at least one, use first in queue.
    if(test_name_count > 0) {
      test_name = test_names[0];
      testname_plusarg = true;
    }

    // If multiple, provided the warning giving the number, which one will be
    // used and the complete list.
    if(test_name_count > 1) {
      string test_list;
      string sep;
      for(size_t i = 0; i < test_names.length; ++i) {
	if(i !is 0) {
	  sep = ", ";
	}
	test_list ~= sep ~ test_names[i];
      }
      uvm_report_warning("MULTTST",
			 format("Multiple (%0d) +UVM_TESTNAME arguments "
				"provided on the command line.  '%s' will "
				"be used.  Provided list: %s.",
				test_name_count, test_name, test_list),
			 UVM_NONE);
    }

    // if test now defined, create it using common factory
    if(test_name != "") {
      if("uvm_test_top" in m_children) {
	uvm_report_fatal("TTINST",
			 "An uvm_test_top already exists via a "
			 "previous call to run_test", UVM_NONE);
	wait(0); // #0 // forces shutdown because $finish is forked
      }

      uvm_test_top = cast(uvm_component)
	factory.create_component_by_name(test_name, "", "uvm_test_top", null);
      // Special case for VLang
      // uvm_test_top.set_name("uvm_test_top");

      if(uvm_test_top is null) {
	string msg = testname_plusarg ?
	  "command line +UVM_TESTNAME=" ~ test_name :
	  "call to run_test(" ~ test_name ~ ")";
	uvm_report_fatal("INVTST", "Requested test from " ~ msg ~ " not found.",
			 UVM_NONE);
      }
    }

    // if(m_children.length is 0) {
    //   uvm_report_fatal("NOCOMP",
    //		       "No components instantiated. You must either "
    //		       "instantiate at least one component before "
    //		       "calling run_test or use run_test to do so. "
    //		       "To run a test using run_test, use +UVM_TESTNAME "
    //		       "or supply the test name in the argument to "
    //		       "run_test(). Exiting simulation.", UVM_NONE);
    //   return;
    // }

    if(test_name == "") {
      uvm_report_info("RNTST", "Running test ...", UVM_LOW);
    }
    else if (test_name == uvm_test_top.get_type_name()) {
      uvm_report_info("RNTST", "Running test " ~ test_name ~ "...",
		      UVM_LOW);
    }
    else {
      uvm_report_info("RNTST", "Running test " ~ uvm_test_top.get_type_name() ~
		      " (via factory override for test \"" ~ test_name ~
		      "\")...", UVM_LOW);
    }

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

    while(m_phase_all_done is false) {
      m_phase_all_done.wait();
    }

    // clean up after ourselves
    phase_runner_proc.abort();

    uvm_report_server l_rs = uvm_report_server.get_server();
    l_rs.report_summarize();

    unlockStage();
    if(finish_on_completion) {
      debug(FINISH) {
	import std.stdio;
	writeln("finish_on_completion");
      }
      withdrawCaveat();
      // finish();
    }
  }

  // Function: die
  //
  // This method is called by the report server if a report reaches the maximum
  // quit count or has a UVM_EXIT action associated with it, e.g., as with
  // fatal errors.
  //
  // Calls the <uvm_component::pre_abort()> method
  // on the entire <uvm_component> hierarchy in a bottom-up fashion.
  // It then calls <uvm_report_server::report_summarize> and terminates the simulation
  // with ~$finish~.

  version(UVM_INCLUDE_DEPRECATED) {
    override void die() {_die();}
  }
  else {
    void die() {_die();}
  }

  private void _die() {
    uvm_report_server l_rs = uvm_report_server.get_server();
    // do the pre_abort callbacks
    m_do_pre_abort();

    l_rs.report_summarize();
    finish();
  }
  
  // Function: set_timeout
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
    synchronized(this) {
      import std.string;
      if(_m_uvm_timeout_overridable is false) {
	uvm_report_info("NOTIMOUTOVR",
			format("The global timeout setting of %0d is not "
			       "overridable to %0d due to a previous setting.",
			       phase_timeout, timeout), UVM_NONE);
	return;
      }
      _m_uvm_timeout_overridable = overridable;
      _phase_timeout = timeout;
    }
  }


  // Variable: finish_on_completion
  //
  // If set, then run_test will call $finish after all phases are executed.


  @uvm_public_sync
  private bool _finish_on_completion = true;


  //----------------------------------------------------------------------------
  // Group: Topology
  //----------------------------------------------------------------------------


  // Variable: top_levels
  //
  // This variable is a list of all of the top level components in UVM. It
  // includes the uvm_test_top component that is created by <run_test> as
  // well as any other top level components that have been instantiated
  // anywhere in the hierarchy.

  // note that _top_levels needs to add an element in the front only
  // when the element name is "uvm_test_top". Since the access from
  // front is rare and we do not expect the number of elements to be
  // really large, an array can be used in place of a Queue
  private uvm_component[] _top_levels;


  // Function: find

  uvm_component find(string comp_match) {
    synchronized(this) {
      import std.string: format;
      uvm_component[] comp_list;

      find_all(comp_match, comp_list);

      if(comp_list.length > 1) {
	uvm_report_warning("MMATCH",
			   format("Found %0d components matching '%s'."
				  " Returning first match, %0s.",
				  comp_list.length, comp_match,
				  comp_list[0].get_full_name()), UVM_NONE);
      }

      if(comp_list.length is 0) {
	uvm_report_warning("CMPNFD",
			   "Component matching '" ~comp_match ~
			   "' was not found in the list of uvm_components",
			   UVM_NONE);
	return null;
      }
      return comp_list[0];
    }
  }


  // Function: find_all
  //
  // Returns the component handle (find) or list of components handles
  // (find_all) matching a given string. The string may contain the wildcards,
  // * and ?. Strings beginning with '.' are absolute path names. If the optional
  // argument comp is provided, then search begins from that component down
  // (default=all components).

  void find_all(string comp_match, ref Queue!uvm_component comps,
		uvm_component comp=null) {
    synchronized(this) {
      if(comp is null) {
	comp = this;
      }
      m_find_all_recurse(comp_match, comps, comp);
    }
  }

  void find_all(string comp_match, ref uvm_component[] comps,
		uvm_component comp=null) {
    synchronized(this) {
      if(comp is null) {
	comp = this;
      }
      m_find_all_recurse(comp_match, comps, comp);
    }
  }

  uvm_component[] find_all(string comp_match, uvm_component comp=null) {
    synchronized(this) {
      uvm_component[] comps;
      if(comp is null) {
	comp = this;
      }
      m_find_all_recurse(comp_match, comps, comp);
      return comps;
    }
  }

  // Function: print_topology
  //
  // Print the verification environment's component topology. The
  // ~printer~ is a <uvm_printer> object that controls the format
  // of the topology printout; a ~null~ printer prints with the
  // default output.

  void print_topology(uvm_printer printer=null) {
    synchronized(this) {
      // string s; // defined in SV version but never used

      if(m_children.length is 0) {
	uvm_report_warning("EMTCOMP", "print_topology - No UVM "
			   "components to print.", UVM_NONE);
	return;
      }

      if(printer is null)
	printer = uvm_default_printer;

      foreach(i, c; m_children) {
	if((cast(uvm_component) c).print_enabled) {
	  printer.print_object("", (cast(uvm_component) c));
	}
      }
      uvm_info("UVMTOP", "UVM testbench topology:\n" ~ printer.emit(),
	       UVM_NONE);
    }
  }


  // Variable: enable_print_topology
  //
  // If set, then the entire testbench topology is printed just after completion
  // of the end_of_elaboration phase.

  @uvm_public_sync
  private bool _enable_print_topology = false;

  // Variable- phase_timeout
  //
  // Specifies the timeout for the run phase. Default is `UVM_DEFAULT_TIMEOUT

  // private
  @uvm_immutable_sync
  private WithEvent!Time _phase_timeout;


  SimTime phase_sim_timeout() {
    synchronized(this) {
      return SimTime(_uvm_root_entity_instance, _phase_timeout);
    }
  }

  // PRIVATE members

  void m_find_all_recurse(string comp_match,
			  ref Queue!uvm_component comps,
			  uvm_component comp=null) {
    synchronized(this) {
      string name;

      foreach(child; comp.get_children) {
	this.m_find_all_recurse(comp_match, comps, child);
      }
      import uvm.base.uvm_globals: uvm_is_match;
      if(uvm_is_match(comp_match, comp.get_full_name()) &&
	 comp.get_name() != "") /* uvm_top */
	comps.pushBack(comp);
    }
  }

  void m_find_all_recurse(string comp_match,
			  ref uvm_component[] comps,
			  uvm_component comp=null) {
    synchronized(this) {
      string name;

      foreach(child; comp.get_children) {
	this.m_find_all_recurse(comp_match, comps, child);
      }
      import uvm.base.uvm_globals: uvm_is_match;
      if(uvm_is_match(comp_match, comp.get_full_name()) &&
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
    synchronized(this) {
      if(super.m_add_child(child)) {
	if(child.get_name() == "uvm_test_top") {
	  _top_levels = [child] ~ _top_levels;
	  // _top_levels.pushFront(child);
	}
	else {
	  _top_levels ~= child;
	  // _top_levels.pushBack(child);
	}
	return true;
      }
      else {
	return false;
      }
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
    m_do_dump_args();
  }

  override void elaboration_phase(uvm_phase phase) {
    foreach(child; get_children()) {
      child.uvm__auto_elab();
    }
  }

  override ParContext _esdl__parInheritFrom() {
    return Process.self().getParentEntity();
  }

  //   extern local function void m_do_verbosity_settings();
  // m_do_verbosity_settings
  // -----------------------

  void m_do_verbosity_settings() {

    string[] set_verbosity_settings;
    string[] split_vals;

    // Retrieve them all into set_verbosity_settings
    clp.get_arg_values("+uvm_set_verbosity=", set_verbosity_settings);

    foreach(i, setting; set_verbosity_settings) {
      uvm_split_string(setting, ',', split_vals);
      if(split_vals.length < 4 || split_vals.length > 5) {
	uvm_report_warning("INVLCMDARGS",
			   format("Invalid number of arguments found on "
				  "the command line for setting "
				  "'+uvm_set_verbosity=%s'.  Setting ignored.",
				  setting), UVM_NONE); // , "", "");
      }
      uvm_verbosity tmp_verb;
      // Invalid verbosity
      if(!clp.m_convert_verb(split_vals[2], tmp_verb)) {
	uvm_report_warning("INVLCMDVERB",
			   format("Invalid verbosity found on the command "
				  "line for setting '%s'.",
				  setting), UVM_NONE); // , "", "");
      }
    }
  }



  //   extern local function void m_do_timeout_settings();
  // m_do_timeout_settings
  // ---------------------

  void m_do_timeout_settings() {
    // synchronized(this) {
    // declared in SV version -- redundant
    // string[] split_timeout;

    string[] timeout_settings;
    size_t timeout_count = clp.get_arg_values("+UVM_TIMEOUT=", timeout_settings);

    if(timeout_count == 0) {
      return;
    }
    else {
      string timeout = timeout_settings[0];
      if(timeout_count > 1) {
	string timeout_list;
	string sep;
	for(size_t i = 0; i < timeout_settings.length; ++i) {
	  if(i !is 0) sep = "; ";
	  timeout_list ~= sep ~ timeout_settings[i];
	}
	uvm_report_warning("MULTTIMOUT",
			   format("Multiple (%0d) +UVM_TIMEOUT arguments "
				  "provided on the command line.  '%s' will "
				  "be used.  Provided list: %s.",
				  timeout_count, timeout, timeout_list),
			   UVM_NONE);
      }
      uvm_report_info("TIMOUTSET",
		      format("'+UVM_TIMEOUT=%s' provided on the command "
			     "line is being applied.", timeout), UVM_NONE);

      uint timeout_int;
      string override_spec;
      formattedRead(timeout, "%d,%s", &timeout_int, &override_spec);

      switch(override_spec) {
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
    foreach(i, arg; args) {
      m_process_inst_override(arg[23..$]);
    }
    clp.get_arg_matches("/^\\+(UVM_SET_TYPE_OVERRIDE|uvm_set_type_override)=/",
			args);
    foreach(i, arg; args) {
      m_process_type_override(arg[23..$]);
    }
  }

  //   extern local function void m_process_inst_override(string ovr);
  // m_process_inst_override
  // -----------------------

  void m_process_inst_override(string ovr) {
    string[] split_val;

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();

    uvm_split_string(ovr, ',', split_val);

    if(split_val.length !is 3 ) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid setting for +uvm_set_inst_override=" ~ ovr ~
		       ", setting must specify <requested_type>,"
		       "<override_type>,<instance_path>", UVM_NONE);
    }
    uvm_report_info("INSTOVR",
		    "Applying instance override from the command line: "
		    "+uvm_set_inst_override=" ~ ovr, UVM_NONE);
    factory.set_inst_override_by_name(split_val[0], split_val[1], split_val[2]);
  }

  //   extern local function void m_process_type_override(string ovr);
  // m_process_type_override
  // -----------------------

  void m_process_type_override(string ovr) {
    string[] split_val;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();

    uvm_split_string(ovr, ',', split_val);

    if(split_val.length > 3 || split_val.length < 2) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid setting for +uvm_set_type_override=" ~ ovr ~
		       ", setting must specify <requested_type>,"
		       "<override_type>[,<replace>]", UVM_NONE);
      return;
    }

    // Replace arg is optional. If set, must be 0 or 1
    bool replace = true;
    if(split_val.length == 3) {
      if(split_val[2] == "0") replace =  false;
      else if(split_val[2] == "1") replace = true;
      else {
	uvm_report_error("UVM_CMDLINE_PROC", "Invalid replace arg for "
			 "+uvm_set_type_override=" ~ ovr ~
			 " value must be 0 or 1", UVM_NONE);
	return;
      }
    }

    uvm_report_info("UVM_CMDLINE_PROC", "Applying type override from "
		    "the command line: +uvm_set_type_override=" ~ ovr,
		    UVM_NONE);
    factory.set_type_override_by_name(split_val[0], split_val[1], replace);
  }


  //   extern local function void m_do_config_settings();
  // m_do_config_settings
  // --------------------

  void m_do_config_settings() {
    string[] args;
    clp.get_arg_matches("/^\\+(UVM_SET_CONFIG_INT|uvm_set_config_int)=/",
			args);
    foreach(i, arg; args) {
      m_process_config(arg[20..$], true);
    }
    clp.get_arg_matches("/^\\+(UVM_SET_CONFIG_STRING|uvm_set_config_string)=/",
			args);
    foreach(i, arg; args) {
      m_process_config(arg[23..$], false);
    }

    clp.get_arg_matches("/^\\+(UVM_SET_DEFAULT_SEQUENCE|uvm_set_default_sequence)=/", args);
    foreach(i, arg; args) {
      m_process_default_sequence(arg[26..$]);
    }
  }

  //   extern local function void m_do_max_quit_settings();
  // m_do_max_quit_settings
  // ----------------------

  void m_do_max_quit_settings() {
    uvm_report_server srvr = uvm_report_server.get_server();
    string[] max_quit_settings;
    size_t max_quit_count = clp.get_arg_values("+UVM_MAX_QUIT_COUNT=",
					       max_quit_settings);
    if(max_quit_count is 0) return;
    else {
      string max_quit = max_quit_settings[0];
      if(max_quit_count > 1) {
	string sep;
	string max_quit_list;
	for(size_t i = 0; i < max_quit_settings.length; ++i) {
	  if(i !is 0) sep = "; ";
	  max_quit_list ~= sep ~ max_quit_settings[i];
	}
	uvm_report_warning("MULTMAXQUIT",
			   format("Multiple (%0d) +UVM_MAX_QUIT_COUNT "
				  "arguments provided on the command line."
				  "  '%s' will be used.  Provided list: %s.",
				  max_quit_count, max_quit, max_quit_list),
			   UVM_NONE);
      }
      uvm_report_info("MAXQUITSET",
		      format("'+UVM_MAX_QUIT_COUNT=%s' provided on the "
			     "command line is being applied.", max_quit),
		      UVM_NONE);
      string[] split_max_quit;
      uvm_split_string(max_quit, ',', split_max_quit);
      int max_quit_int = parse!int(split_max_quit[0]); // .atoi();
      switch(split_max_quit[1]) {
      case "YES": srvr.set_max_quit_count(max_quit_int, 1); break;
      case "NO" : srvr.set_max_quit_count(max_quit_int, 0); break;
      default : srvr.set_max_quit_count(max_quit_int, 1); break;
      }
    }
  }

  //   extern local function void m_do_dump_args();
  // m_do_dump_args
  // --------------

  void m_do_dump_args() {
    string[] dump_args;
    string[] all_args;
    string out_string;
    if(clp.get_arg_matches(`\+UVM_DUMP_CMDLINE_ARGS`, dump_args)) {
      clp.get_args(all_args);
      foreach(i, arg; all_args) {
	if(arg == "__-f__") continue;
	out_string ~= out_string ~ arg ~ " ";
      }
      uvm_report_info("DUMPARGS", out_string, UVM_NONE);
    }
  }


  // extern local function void m_process_config(string cfg, bit is_int);
  // m_process_config
  // ----------------

  void m_process_config(string cfg, bool is_int) {
    int v;
    string[] split_val;

    uvm_split_string(cfg, ',', split_val);
    if(split_val.length is 1) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid +uvm_set_config command\"" ~ cfg ~
		       "\" missing field and value: component is \"" ~
		       split_val[0] ~ "\"", UVM_NONE);
      return;
    }

    if(split_val.length is 2) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       "Invalid +uvm_set_config command\"" ~ cfg ~
		       "\" missing value: component is \"" ~ split_val[0] ~
		       "\"  field is \"" ~ split_val[1] ~ "\"", UVM_NONE);
      return;
    }

    if(split_val.length > 3) {
      uvm_report_error("UVM_CMDLINE_PROC",
		       format("Invalid +uvm_set_config command\"%s\" : "
			      "expected only 3 fields (component, field "
			      "and value).", cfg), UVM_NONE);
      return;
    }

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root m_uvm_top = cs.get_root();

    if(is_int) {
      if(split_val[2].length > 2) {
	string base = split_val[2][0..2];
	string extval = split_val[2][2..$];
	switch(base) {
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
		      "Applying config setting from the command line: "
		      "+uvm_set_config_int=" ~ cfg, UVM_NONE);
      uvm_config_db!int.set(m_uvm_top, split_val[0], split_val[1], v);
    }
    else {
      uvm_report_info("UVM_CMDLINE_PROC",
		      "Applying config setting from the command line: "
		      "+uvm_set_config_string=" ~ cfg, UVM_NONE);
      uvm_config_db!string.set(m_uvm_top, split_val[0], split_val[1], split_val[2]);
    }
  }


  // m_process_default_sequence
  // ----------------

  void m_process_default_sequence(string cfg) {
    synchronized(this) {
      string[] split_val;
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root m_uvm_top = cs.get_root();   
      uvm_factory f = cs.get_factory();
      uvm_object_wrapper w;

      uvm_split_string(cfg, ',', split_val);
      if(split_val.length == 1) {
	uvm_report_error("UVM_CMDLINE_PROC",
			 "Invalid +uvm_set_default_sequence command\"" ~
			 cfg ~ "\" missing phase and type: sequencer is \"" ~
			 split_val[0] ~ "\"", UVM_NONE);
	return;
      }

      if(split_val.length == 2) {
	uvm_report_error("UVM_CMDLINE_PROC",
			 "Invalid +uvm_set_default_sequence command\"" ~ cfg ~
			 "\" missing type: sequencer is \"" ~ split_val[0] ~
			 "\"  phase is \"" ~ split_val[1] ~ "\"",
			 UVM_NONE);
	return;
      }

      if(split_val.length > 3) {
	uvm_report_error("UVM_CMDLINE_PROC", 
			 format("Invalid +uvm_set_default_sequence command" ~
				"\"%s\" : expected only 3 fields (sequencer" ~
				", phase and type).", cfg), UVM_NONE);
      }

      w = f.find_wrapper_by_name(split_val[2]);
      if (w is null) {
	uvm_report_error("UVM_CMDLINE_PROC",
			 format("Invalid type '%s' provided to +" ~
				"uvm_set_default_sequence", split_val[2]),
			 UVM_NONE);
	return;
      }
      else {
	uvm_report_info("UVM_CMDLINE_PROC",
			"Setting default sequence from the command " ~
			"line: +uvm_set_default_sequence=" ~ cfg, UVM_NONE);
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

    string verb_string;
    string[] verb_settings;
    int plusarg;
    int verbosity = UVM_MEDIUM;

    // Retrieve the verbosities provided on the command line.
    size_t verb_count = clp.get_arg_values(`+UVM_VERBOSITY=`, verb_settings);

    // If none provided, provide message about the default being used.
    //if(verb_count is 0)
    //  uvm_report_info("DEFVERB", ("No verbosity specified on the
    //  command line.  Using the default: UVM_MEDIUM"), UVM_NONE);

    // If at least one, use the first.
    if(verb_count > 0) {
      verb_string = verb_settings[0];
      plusarg = 1;
    }

    // If more than one, provide the warning stating how many, which one will
    // be used and the complete list.
    if(verb_count > 1) {
      string verb_list;
      string sep;
      foreach(i, setting; verb_settings) {
	if(i !is 0) sep = ", ";
	verb_list ~= sep ~ setting;
      }

      uvm_report_warning("MULTVERB",
			 format("Multiple (%0d) +UVM_VERBOSITY arguments "
				"provided on the command line.  '%s' "
				"will be used.  Provided list: %s.",
				verb_count, verb_string, verb_list),
			 UVM_NONE);
    }

    if(plusarg is 1) {
      switch(verb_string) {
      case "UVM_NONE"    : verbosity = UVM_NONE; break;
      case "NONE"        : verbosity = UVM_NONE; break;
      case "UVM_LOW"     : verbosity = UVM_LOW; break;
      case "LOW"         : verbosity = UVM_LOW; break;
      case "UVM_MEDIUM"  : verbosity = UVM_MEDIUM; break;
      case "MEDIUM"      : verbosity = UVM_MEDIUM; break;
      case "UVM_HIGH"    : verbosity = UVM_HIGH; break;
      case "HIGH"        : verbosity = UVM_HIGH; break;
      case "UVM_FULL"    : verbosity = UVM_FULL; break;
      case "FULL"        : verbosity = UVM_FULL; break;
      case "UVM_DEBUG"   : verbosity = UVM_DEBUG; break;
      case "DEBUG"       : verbosity = UVM_DEBUG; break;
      default       : {
	verbosity = parse!int(verb_string); // .atoi();
	if(verbosity > 0) {
	  uvm_report_info("NSTVERB",
			  format("Non-standard verbosity value, using "
				 "provided '%0d'.", verbosity), UVM_NONE);
	}
	if(verbosity is 0) {
	  verbosity = UVM_MEDIUM;
	  uvm_report_warning("ILLVERB",
			     "Illegal verbosity value, using default "
			     "of UVM_MEDIUM.", UVM_NONE);
	}
      }
      }
    }

    set_report_verbosity_level_hier(verbosity);

  }

  version(UVM_INCLUDE_DEPRECATED) {
    override void report_header(UVM_FILE file = 0) {_report_header(file);}
  }
  else {
    void report_header(UVM_FILE file = 0) {_report_header(file);}
  }
  
  private void _report_header(UVM_FILE file = 0) {
    synchronized(this) {
      string q;
      uvm_report_server srvr;
      uvm_cmdline_processor clp;
      string[] args;

      srvr = uvm_report_server.get_server();
      clp = uvm_cmdline_processor.get_inst();

      if (clp.get_arg_matches("\\+UVM_NO_RELNOTES", args)) return;


      q ~= "\n----------------------------------------------------------------\n";
      q ~= uvm_revision_string() ~ "\n";
      q ~= uvm_co_copyright ~ "\n";
      q ~= uvm_mgc_copyright ~ "\n";
      q ~= uvm_cdn_copyright ~ "\n";
      q ~= uvm_snps_copyright ~ "\n";
      q ~= uvm_cy_copyright ~ "\n";
      q ~= uvm_nv_copyright ~ "\n";
      q ~= "----------------------------------------------------------------\n";


      version(UVM_INCLUDE_DEPRECATED) {
      	if(!_m_relnotes_done) {
      	  q ~= "\n  ***********       IMPORTANT RELEASE NOTES         ************\n";
      	}
      	q ~= "\n  You are using a version of the UVM library that has been compiled\n";
      	q ~= "  with `UVM_INCLUDE_DEPRECATED defined.\n";
      	q ~= "  See http://www.eda.org/svdb/view.php?id=3313 for more details.\n";
      	_m_relnotes_done = true;
      }

      version(UVM_OBJECT_DO_NOT_NEED_CONSTRUCTOR) {}
      else {
	if(!_m_relnotes_done) {
	  q ~= "\n  ***********       IMPORTANT RELEASE NOTES         ************\n";
	}
	q ~= "\n  You are using a version of the UVM library that has been compiled\n";
	q ~= "  with `UVM_OBJECT_DO_NOT_NEED_CONSTRUCTOR undefined.\n";
	q ~= "  See http://www.eda.org/svdb/view.php?id=3770 for more details.\n";
	_m_relnotes_done=1;
      }

      if(_m_relnotes_done) {
	q ~= "\n      (Specify +UVM_NO_RELNOTES to turn off this notice)\n";
      }

      uvm_info("UVM/RELNOTES", q, UVM_LOW);
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
    foreach(idx, cl_action; m_uvm_applied_cl_action) {
      if(cl_action.used == 0) {
	uvm_warning("INVLCMDARGS",
		    format("\"+uvm_set_action=%s\" never took effect" ~
			   " due to a mismatching component pattern",
			   cl_action.arg));
      }
    }

    foreach(idx, cl_sev; m_uvm_applied_cl_sev) {
      if(cl_sev.used == 0) {
	uvm_warning("INVLCMDARGS",
		    format("\"+uvm_set_severity=%s\" never took effect" ~
			   " due to a mismatching component pattern",
			   cl_sev.arg));
      }
    }
    
    if(getRootEntity().getSimTime() > 0) {
      uvm_fatal("RUNPHSTIME",
		"The run phase must start at time 0, current time is " ~
		format("%s", getRootEntity().getSimTime()) ~
		". No non-zero delays are allowed before run_test(), and"
		" pre-run user defined phases may not consume simulation"
		" time before the start of the run phase.");
    }
  }


  // phase_started
  // -------------
  // At end of elab phase we need to do tlm binding resolution.
  override void phase_started(uvm_phase phase) {
    synchronized(this) {
      if(phase is end_of_elaboration_ph) {
	do_resolve_bindings();
	if(enable_print_topology) print_topology();
	uvm_report_server srvr = uvm_report_server.get_server();
	if(srvr.get_severity_count(UVM_ERROR) > 0) {
	  uvm_report_fatal("BUILDERR", "stopping due to build errors", UVM_NONE);
	}
      }
    }
  }

  @uvm_immutable_sync
  Semaphore _elab_done_semaphore;

  @uvm_private_sync
  bool _elab_done;

  override void phase_ended(uvm_phase phase) {
    if(phase is end_of_elaboration_ph) {
      synchronized(this) {
	elab_done = true;
	elab_done_semaphore.notify();
      }
    }
  }

  final void wait_for_end_of_elaboration() {
    while(elab_done is false) {
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
    auto root_entity_instance = uvm_root_entity_base.get();
    if(root_entity_instance is null) {
      assert("Null uvm_top");
    }
    return root_entity_instance._get_uvm_root();
  }

  version(UVM_INCLUDE_DEPRECATED) {
    // stop_request
    // ------------

    // backward compat only
    // call global_stop_request() or uvm_test_done.stop_request() instead
    void stop_request() {
      uvm_test_done_objection tdo = uvm_test_done_objection.get();
      tdo.stop_request();
    }
  }

  private bool _m_relnotes_done = false;

  override void end_of_elaboration_phase(uvm_phase phase) {
    synchronized(this) {
      auto p = new uvm_component_proxy("proxy");
      auto adapter = new uvm_top_down_visitor_adapter!uvm_component("adapter");
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_visitor!uvm_component v = cs.get_component_visitor();
      adapter.accept(this, v, p);
    }
  }
  
}



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

  this(uvm_root_entity_base root_entity_instance) {
    synchronized(this) {
      root_entity_instance._set_root_once(this);
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
  }

  void set_seed(int seed) {
    _uvm_seed_map_once.set_seed(seed);
  }
}



// const uvm_root uvm_top = uvm_root::get();



// FIXME -- remove the junk beyond this line

// // for backward compatibility
// const uvm_root _global_reporter = uvm_root::get();



// //-----------------------------------------------------------------------------
// //
// // Class- uvm_root_report_handler
// //
// //-----------------------------------------------------------------------------
// // Root report has name "reporter"

// class uvm_root_report_handler: uvm_report_handler
// {
//   override void report(uvm_severity severity,
// 			      string name,
// 			      string id,
// 			      string message,
// 			      int verbosity_level=UVM_MEDIUM,
// 			      string filename="",
// 			      size_t line=0,
// 			      uvm_report_object client=null) {
//     if(name == "") name = "reporter";
//     super.report(severity, name, id, message, verbosity_level,
// 		 filename, line, client);
//   }
// }


// auto uvm_simulate(T)(string name, uint seed,
// 			    uint multi=1, uint first=0) {
//   auto root = new uvm_root_entity!T(name, seed);
//   root.multiCore(multi, first);
//   root.elaborate();
//   root.simulate();
//   return root;
// }

// auto uvm_elaborate(T)(string name, uint seed,
// 			     uint multi=1, uint first=0) {
//   auto root = new uvm_root_entity!T(name, seed);
//   root.multiCore(multi, first);
//   root.elaborate();
//   // root.simulate();
//   return root;
// }

// auto uvm_fork(T)(string name, uint seed,
// 			uint multi=1, uint first=0) {
//   auto root = new uvm_root_entity!T(name, seed);
//   root.multiCore(multi, first);
//   root.elaborate();
//   root.fork();
//   return root;
// }
