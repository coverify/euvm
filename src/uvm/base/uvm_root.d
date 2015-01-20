//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
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
// Any component whose parent is specified as NULL becomes a child of ~uvm_top~.
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
// been generated so far. If errors are found an UVM_FATAL error is being generated as result
// so that the simulation will not continue to the start_of_simulation_phase.
//

//------------------------------------------------------------------------------

module uvm.base.uvm_root;

// typedef class uvm_test_done_objection;
// typedef class uvm_cmdline_processor;
import uvm.base.uvm_component; // uvm_component
import uvm.base.uvm_cmdline_processor; // uvm_component
import uvm.base.uvm_object_globals;
import uvm.base.uvm_printer;
import uvm.base.uvm_factory;
import uvm.base.uvm_globals;
import uvm.base.uvm_objection;
import uvm.base.uvm_phase;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_report_object;
import uvm.base.uvm_report_server;
import uvm.base.uvm_domain;

public import uvm.meta.misc;

import esdl.base.core;
import esdl.data.queue;

import std.conv;
import std.format;
import std.string: format;

import core.sync.semaphore: Semaphore;
// each process belonging to a given root enity would see the same
// uvm_root. This static (thread local) variable gets assigned during
// the initialization of all the processes and rouines as part of the
// initProcess function.
package static uvm_root _uvm_top;

package static is_root_thread = false;

//------------------------------------------------------------------------------
// Variable: uvm_top
//
// This is the top-level that governs phase execution and provides component
// search interface. See <uvm_root> for more information.
//------------------------------------------------------------------------------

// provide read only access to the _uvm_top static variable
public uvm_root uvm_top() {
  if(_uvm_top !is null || is_root_thread) return _uvm_top;
  auto _entity = cast(uvm_root_entity_base) getRootEntity;
  if(_entity is null) {
    return null;
  }
  _uvm_top = _entity.get_uvm_root();
  return _uvm_top;
}

// return true if pool thread associated with UVM
public bool uvm_is_uvm_thread() {
  if(getPoolThread() is null || uvm_top() is null) return false;
  return true;
}

// This is where the uvm gets instantiated as part of the ESDL
// simulator. Unlike the SystemVerilog version where uvm_root is a
// singleton, we can have multiple instances of uvm_root, but each
// ESDL RootEntity could have only one instance of uvm_root.

class uvm_root_entity_base: RootEntity
{
  this(string name) {
    super(name);
  }

  // The UVM singleton variables are now encapsulated as part of _once
  // mechanism.
  private uvm_root_once _root_once;
  public uvm_root_once root_once() {
    return _root_once;
  }

  abstract public uvm_root get_uvm_root();
  // The randomization seed passed from the top.
  // alias get_uvm_root this;
}

class uvm_root_entity(T): uvm_root_entity_base if(is(T: uvm_root))
  {
    this(string name, uint seed) {
      synchronized(this) {
	super(name);
	_seed = seed;
	_uvmRootInitSemaphore = new Semaphore(); // count 0
	// _uvmRootInitEvent.init("_uvmRootInitEvent");
	debug(SEED) {
	  import std.stdio;
	  writeln("seed for UVM is:", seed);
	}
	T _top;
	_root_once = new uvm_root_once(_top, _seed);
	_uvm_top = _top;
	uvm_top.init_report();
	uvm_top.init_domains();
	_uvmRootInit = true;
	_uvmRootInitSemaphore.notify();
      }
    }

    override public T get_uvm_root() {
      if(_uvmRootInit is false) {
	// _uvmRootInitEvent.wait();
	_uvmRootInitSemaphore.wait();
	_uvmRootInitSemaphore.notify();
	// if(root_once !is null) root_once.initialize();
      }
      return this._uvm_top;
    }

    alias get_uvm_root this;

    // Event _uvmRootInitEvent;
    Semaphore _uvmRootInitSemaphore;

    @uvm_private_sync bool _uvmRootInit;

    // Moved to constructor
    // final public void initUVM() {
    //   is_root_thread = true;
    //   synchronized(this) {
    //	_root_once = new uvm_root_once!(T)(_uvm_top, _seed);
    //	uvm_top.init_report();
    //	uvm_top.init_domains();
    //	_uvmRootInit = true;
    //	// _uvmRootInitEvent.notify();
    //	_uvmRootInitSemaphore.notify();

    //   }
    // }

    // public Task!(initUVM, -1) _initUVM__;

    public void initial() {
      _uvm_top.initial();
    }

    public Task!(initial) _init;

    // no need now we handle once initialization lazily
    // override public void initProcess() {
    //   super.initProcess();
    //   // if(root_once !is null) root_once.initialize();
    // }



    // The uvm_root instance corresponding to this RootEntity.
    private T _uvm_top;

    // The randomization seed passed from the top.
    private uint _seed;
}

class uvm_root: uvm_component
{
  mixin uvm_sync;

  this() {
    synchronized(this) {
      super();
      _m_phase_timeout = new WithEvent!SimTime;
      _m_phase_all_done = new WithEvent!bool;
      _uvmElabDoneSemaphore = new Semaphore(); // count 0
    }
  }

  // SV implementation makes this a part of the run_test function
  uvm_component uvm_test_top;

  // in SV this is part of the constructor. Here we have separated it
  // out since we need to make sure that _once initialization has completed
  void init_report() {
    synchronized(this) {
      uvm_root_report_handler rh = new uvm_root_report_handler();
      set_report_handler(rh);
      _clp = uvm_cmdline_processor.get_inst();
      report_header();

      // This sets up the global verbosity. Other command line args may
      // change individual component verbosity.
      m_check_verbosity();
    }
  }

  // in the SV version these two lines are handled in
  // the uvm_root.get function
  void init_domains() {
    synchronized(this) {
      uvm_domain.get_common_domain();
      _uvm_top.m_domain = uvm_domain.get_uvm_domain();
    }
  }

  // uvm_root

  // Function: get()
  // Get the factory singleton
  //
  public static uvm_root get() {
    auto top = uvm_top();
    if(top is null) assert("Null uvm_top");
    return top;
  }

  @uvm_immutable_sync uvm_cmdline_processor _clp;


  // this function can be overridden by the user
  public void initial() {
    run_test();
  }

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
  public void run_test(string test_name="") {
    uvm_factory factory = uvm_factory.get();

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

    // SV version has a begin-end block here
    // {
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
    // }

    // phase runner, isolated from calling process
    // Process phase_runner_proc; // store thread forked below for final cleanup
    Process phase_runner_proc = fork({uvm_phase.m_run_phases();});
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

    report_summarize();

    if(finish_on_completion) {
      debug(FINISH) {
	import std.stdio;
	writeln("finish_on_completion");
      }
      finish();
    }
  }

  // Variable: top_levels
  //
  // This variable is a list of all of the top level components in UVM. It
  // includes the uvm_test_top component that is created by <run_test> as
  // well as any other top level components that have been instantiated
  // anywhere in the hierarchy.

  @uvm_private_sync
    private Queue!uvm_component _top_levels;


  // Function: find

  public uvm_component find(string comp_match) {
    synchronized(this) {
      import std.string: format;
      Queue!uvm_component comp_list;

      find_all(comp_match,comp_list);

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
  // * and ?. Strings beginning with '.' are absolute path names. If optional
  // comp arg is provided, then search begins from that component down
  // (default=all components).

  public void find_all(string comp_match, ref Queue!uvm_component comps,
		       uvm_component comp=null) {
    synchronized(this) {
      if(comp is null) {
	comp = this;
      }
      m_find_all_recurse(comp_match, comps, comp);
    }
  }

  public void find_all(string comp_match, ref uvm_component[] comps,
		       uvm_component comp=null) {
    synchronized(this) {
      if(comp is null) {
	comp = this;
      }
      m_find_all_recurse(comp_match, comps, comp);
    }
  }

  public uvm_component[] find_all(string comp_match, uvm_component comp=null) {
    synchronized(this) {
      uvm_component[] comps;
      if(comp is null) {
	comp = this;
      }
      m_find_all_recurse(comp_match, comps, comp);
      return comps;
    }
  }

  override public string get_type_name() {
    return(typeid(this)).stringof;
  }

  // Function: print_topology
  //
  // Print the verification environment's component topology. The
  // ~printer~ is a <uvm_printer> object that controls the format
  // of the topology printout; a ~null~ printer prints with the
  // default output.

  public void print_topology(uvm_printer printer=null) {
    synchronized(this) {
      // string s; // defined in SV version but never used
      uvm_report_info("UVMTOP", "UVM testbench topology:", UVM_LOW);

      if(m_children.length is 0) {
	uvm_report_warning("EMTCOMP", "print_topology - No UVM "
			   "components to print.", UVM_NONE);
	return;
      }

      if(printer is null)
	printer = uvm_default_printer;

      foreach(i, c; m_children) {
	if(c.print_enabled) {
	  printer.print_object("", c);
	}
      }
      import uvm.meta.mcd: vdisplay;
      vdisplay(printer.emit());
    }
  }


  // Variable: enable_print_topology
  //
  // If set, then the entire testbench topology is printed just after completion
  // of the end_of_elaboration phase.

  @uvm_public_sync private bool _enable_print_topology = false;


  // Variable: finish_on_completion
  //
  // If set, then run_test will call $finish after all phases are executed.


  @uvm_public_sync private bool _finish_on_completion = true;


  // Variable- phase_timeout
  //
  // Specifies the timeout for the run phase. Default is `UVM_DEFAULT_TIMEOUT

  // private
  @uvm_immutable_sync
    public WithEvent!SimTime _m_phase_timeout;



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


  public void set_timeout(Time timeout, bool overridable=true) {
    import std.string;
    __gshared bool m_uvm_timeout_overridable = true;
    if(m_uvm_timeout_overridable is false) {
      uvm_report_info("NOTIMOUTOVR",
		      format("The global timeout setting of %0d is not "
			     "overridable to %0d due to a previous setting.",
			     m_phase_timeout, timeout), UVM_NONE);
      return;
    }
    m_uvm_timeout_overridable = overridable;
    synchronized(this) {
      m_phase_timeout = SimTime(getRootEntity(), timeout);
    }
  }

  public void set_timeout(uint timeout, bool overridable=true) {
    import std.string;
    __gshared bool m_uvm_timeout_overridable = true;
    if(m_uvm_timeout_overridable is false) {
      uvm_report_info("NOTIMOUTOVR",
		      format("The global timeout setting of %0d is not "
			     "overridable to %0d due to a previous setting.",
			     m_phase_timeout, timeout), UVM_NONE);
      return;
    }
    m_uvm_timeout_overridable = overridable;
    synchronized(this) {
      m_phase_timeout = SimTime(timeout);
    }
  }

  public void set_timeout(SimTime timeout, bool overridable=true) {
    import std.string;
    __gshared bool m_uvm_timeout_overridable = true;
    if(m_uvm_timeout_overridable is false) {
      uvm_report_info("NOTIMOUTOVR",
		      format("The global timeout setting of %0d is not "
			     "overridable to %0d due to a previous setting.",
			     m_phase_timeout, timeout), UVM_NONE);
      return;
    }
    m_uvm_timeout_overridable = overridable;
    synchronized(this) {
      m_phase_timeout = timeout;
    }
  }


  // PRIVATE members

  public void m_find_all_recurse(string comp_match, ref Queue!uvm_component comps,
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

  public void m_find_all_recurse(string comp_match, ref uvm_component[] comps,
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

  //   extern protected function new();

  //   extern protected virtual function bit m_add_child(uvm_component child);

  // m_add_child
  // -----------

  // Add to the top levels array
  override public bool m_add_child(uvm_component child) {
    synchronized(this) {
      if(super.m_add_child(child)) {
	if(child.get_name() == "uvm_test_top") {
	  _top_levels.pushFront(child);
	}
	else {
	  _top_levels.pushBack(child);
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

  override public void build_phase(uvm_phase phase) {

    super.build_phase(phase);

    m_set_cl_msg_args();

    m_do_verbosity_settings();
    m_do_timeout_settings();
    m_do_factory_settings();
    m_do_config_settings();
    m_do_max_quit_settings();
    m_do_dump_args();
  }

  override public void elaboration_phase(uvm_phase phase) {
    foreach(child; get_children()) {
      child._uvm__auto_elab();
    }
  }

  public override ParContext _esdl__parInheritFrom() {
    return getRootEntity();
  }

  //   extern local function void m_do_verbosity_settings();
  // m_do_verbosity_settings
  // -----------------------

  public void m_do_verbosity_settings() {

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

  public void m_do_timeout_settings() {
    // synchronized(this) {
    // declared in SV version -- redundant
    // string[] split_timeout;

    string[] timeout_settings;
    size_t timeout_count = clp.get_arg_values("+UVM_TIMEOUT=", timeout_settings);

    if(timeout_count is 0) return;
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
      case "YES": set_timeout(timeout_int, 1); break;
      case "NO": set_timeout(timeout_int, 0); break;
      default : set_timeout(timeout_int, 1); break;
      }
    }
    // }
  }


  //   extern local function void m_do_factory_settings();
  // m_do_factory_settings
  // ---------------------

  public void m_do_factory_settings() {
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

  public void m_process_inst_override(string ovr) {
    string[] split_val;
    uvm_factory fact = uvm_factory.get();

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
    fact.set_inst_override_by_name(split_val[0], split_val[1], split_val[2]);
  }

  //   extern local function void m_process_type_override(string ovr);
  // m_process_type_override
  // -----------------------

  public void m_process_type_override(string ovr) {
    string[] split_val;
    uvm_factory fact = uvm_factory.get();

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
    if(split_val.length is 3) {
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
    fact.set_type_override_by_name(split_val[0], split_val[1], replace);
  }


  //   extern local function void m_do_config_settings();
  // m_do_config_settings
  // --------------------

  public void m_do_config_settings() {
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
  }

  // extern local function void m_process_config(string cfg, bit is_int);
  // m_process_config
  // ----------------

  public void m_process_config(string cfg, bool is_int) {
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

    uvm_root m_uvm_top = uvm_root.get();
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
      m_uvm_top.set_config_int(split_val[0], split_val[1], v);
    }
    else {
      uvm_report_info("UVM_CMDLINE_PROC",
		      "Applying config setting from the command line: "
		      "+uvm_set_config_string=" ~ cfg, UVM_NONE);
      m_uvm_top.set_config_string(split_val[0], split_val[1], split_val[2]);
    }
  }


  //   extern local function void m_do_max_quit_settings();
  // m_do_max_quit_settings
  // ----------------------

  public void m_do_max_quit_settings() {
    uvm_report_server srvr = get_report_server();
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

  public void m_do_dump_args() {
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


  //   extern function void m_check_verbosity();
  // m_check_verbosity
  // ----------------

  public void m_check_verbosity() {

    string verb_string;
    string[] verb_settings;
    int plusarg;
    int verbosity = UVM_MEDIUM;

    // Retrieve the verbosities provided on the command line.
    size_t verb_count = clp.get_arg_values(`\+UVM_VERBOSITY=`, verb_settings);

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

  //   // singleton handle
  //   __gshared private uvm_root m_inst;

  //   // For error checking
  //   extern virtual task run_phase(uvm_phase phase);
  // It is required that the run phase start at simulation time 0
  // TBD this looks wrong - taking advantage of uvm_root not doing anything else?
  // TBD move to phase_started callback?

  // task
  override public void run_phase(uvm_phase phase) {
    if(getSimTime() > 0) {
      uvm_fatal("RUNPHSTIME",
		"The run phase must start at time 0, current time is " ~
		format("%0t", getSimTime()) ~
		". No non-zero delays are allowed before run_test(), and"
		" pre-run user defined phases may not consume simulation"
		" time before the start of the run phase.");
    }
  }


  // phase_started
  // -------------
  // At end of elab phase we need to do tlm binding resolution.
  override public void phase_started(uvm_phase phase) {
    synchronized(this) {
      if(phase is end_of_elaboration_ph) {
	do_resolve_bindings();
	if(enable_print_topology) print_topology();
	uvm_report_server srvr = get_report_server();
	if(srvr.get_severity_count(UVM_ERROR) > 0) {
	  uvm_report_fatal("BUILDERR", "stopping due to build errors", UVM_NONE);
	}
      }
    }
  }

  Semaphore _uvmElabDoneSemaphore;
  @uvm_private_sync bool _uvmElabDone;

  override public void phase_ended(uvm_phase phase) {
    if(phase is end_of_elaboration_ph) {
      synchronized(this) {
	_uvmElabDone = true;
	_uvmElabDoneSemaphore.notify();
      }
    }
  }

  final public void wait_for_end_of_elaboration() {
    while(_uvmElabDone is false) {
      _uvmElabDoneSemaphore.wait();
    }
    _uvmElabDoneSemaphore.notify();
  }

  @uvm_immutable_sync
  WithEvent!bool _m_phase_all_done;


  version(UVM_NO_DEPRECATED) {}
  else {
    // stop_request
    // ------------

    // backward compat only
    // call global_stop_request() or uvm_test_done.stop_request() instead
    public void stop_request() {
      uvm_test_done_objection tdo = uvm_test_done_objection.get();
      tdo.stop_request();
    }
  }

}



class uvm_root_once
{
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

  this(T)(ref T root, uint seed) {
    synchronized(this) {
      // import std.stdio;
      _uvm_sequencer_base_once = new uvm_sequencer_base.uvm_once();
      uvm_sequencer_base._once = _uvm_sequencer_base_once;
      _uvm_seed_map_once = new uvm_seed_map.uvm_once(seed);
      uvm_seed_map._once = _uvm_seed_map_once;
      // writeln("Done -- _uvm_seed_map_once");
      _uvm_recorder_once = new uvm_recorder.uvm_once();
      uvm_recorder._once = _uvm_recorder_once;
      // writeln("Done -- _uvm_recorder_once");
      _uvm_object_once = new uvm_object.uvm_once();
      uvm_object._once = _uvm_object_once;
      // writeln("Done -- _uvm_object_once");
      _uvm_component_once = new uvm_component.uvm_once();
      uvm_component._once = _uvm_component_once;
      // writeln("Done -- _uvm_component_once");
      _uvm_config_db_once = new uvm_once_config_db();
      _uvm_config_db_uvm_once = _uvm_config_db_once;
      // writeln("Done -- _uvm_config_db_once");
      _uvm_config_db_options_once = new uvm_config_db_options.uvm_once();
      uvm_config_db_options._once = _uvm_config_db_options_once;
      // writeln("Done -- _uvm_config_db_options_once");
      _uvm_report_catcher_once = new uvm_report_catcher.uvm_once();
      uvm_report_catcher._once = _uvm_report_catcher_once;
      // writeln("Done -- _uvm_report_catcher_once");
      _uvm_report_handler_once = new uvm_report_handler.uvm_once();
      uvm_report_handler._once = _uvm_report_handler_once;
      // writeln("Done -- _uvm_report_handler_once");
      _uvm_resource_options_once = new uvm_resource_options.uvm_once();
      uvm_resource_options._once = _uvm_resource_options_once;
      // writeln("Done -- _uvm_resource_options_once");
      _uvm_resource_base_once = new uvm_resource_base.uvm_once();
      uvm_resource_base._once = _uvm_resource_base_once;
      // writeln("Done -- _uvm_resource_base_once");
      _uvm_resource_pool_once = new uvm_resource_pool.uvm_once();
      uvm_resource_pool._once = _uvm_resource_pool_once;
      // writeln("Done -- _uvm_resource_pool_once");
      _uvm_factory_once = new uvm_factory.uvm_once();
      uvm_factory._once = _uvm_factory_once;
      // writeln("Done -- _uvm_factory_once");
      _uvm_resource_db_options_once = new uvm_resource_db_options.uvm_once();
      uvm_resource_db_options._once = _uvm_resource_db_options_once;
      // writeln("Done -- _uvm_resource_db_options_once");
      _uvm_domain_globals_once = new uvm_once_domain_globals();
      _uvm_domain_globals_uvm_once = _uvm_domain_globals_once;
      // writeln("Done -- _uvm_domain_once_globals_once");
      _uvm_domain_once = new uvm_domain.uvm_once();
      uvm_domain._once = _uvm_domain_once;
      // writeln("Done -- _uvm_domain_once");
      _uvm_cmdline_processor_once = new uvm_cmdline_processor.uvm_once();
      uvm_cmdline_processor._once = _uvm_cmdline_processor_once;
      // writeln("Done -- _uvm_cmdline_processor_once");

      // Build UVM Root
      root = new T();
      ._uvm_top = root;

      _uvm_objection_once = new uvm_objection.uvm_once();
      uvm_objection._once = _uvm_objection_once;
      // writeln("Done -- _uvm_objection_once");
      _uvm_test_done_objection_once = new uvm_test_done_objection.uvm_once();
      uvm_test_done_objection._once = _uvm_test_done_objection_once;
      // writeln("Done -- _uvm_test_done_objection_once");
      _uvm_phase_once = new uvm_phase.uvm_once();
      uvm_phase._once = _uvm_phase_once;
      // writeln("Done -- _uvm_phase_once");

      // uvm_runtime_phases;
      _uvm_pre_reset_phase_once = new uvm_pre_reset_phase.uvm_once();
      uvm_pre_reset_phase._once = _uvm_pre_reset_phase_once;
      // writeln("Done -- _uvm_pre_reset_phase_once");
      _uvm_reset_phase_once = new uvm_reset_phase.uvm_once();
      uvm_reset_phase._once = _uvm_reset_phase_once;
      // writeln("Done -- _uvm_reset_phase_once");
      _uvm_post_reset_phase_once = new uvm_post_reset_phase.uvm_once();
      uvm_post_reset_phase._once = _uvm_post_reset_phase_once;
      // writeln("Done -- _uvm_post_reset_phase_once");
      _uvm_pre_configure_phase_once = new uvm_pre_configure_phase.uvm_once();
      uvm_pre_configure_phase._once = _uvm_pre_configure_phase_once;
      // writeln("Done -- _uvm_pre_configure_phase_once");
      _uvm_configure_phase_once = new uvm_configure_phase.uvm_once();
      uvm_configure_phase._once = _uvm_configure_phase_once;
      // writeln("Done -- _uvm_configure_phase_once");
      _uvm_post_configure_phase_once = new uvm_post_configure_phase.uvm_once();
      uvm_post_configure_phase._once = _uvm_post_configure_phase_once;
      // writeln("Done -- _uvm_post_configure_phase_once");
      _uvm_pre_main_phase_once = new uvm_pre_main_phase.uvm_once();
      uvm_pre_main_phase._once = _uvm_pre_main_phase_once;
      // writeln("Done -- _uvm_pre_main_phase_once");
      _uvm_main_phase_once = new uvm_main_phase.uvm_once();
      uvm_main_phase._once = _uvm_main_phase_once;
      // writeln("Done -- _uvm_main_phase_once");
      _uvm_post_main_phase_once = new uvm_post_main_phase.uvm_once();
      uvm_post_main_phase._once = _uvm_post_main_phase_once;
      // writeln("Done -- _uvm_post_main_phase_once");
      _uvm_pre_shutdown_phase_once = new uvm_pre_shutdown_phase.uvm_once();
      uvm_pre_shutdown_phase._once = _uvm_pre_shutdown_phase_once;
      // writeln("Done -- _uvm_pre_shutdown_phase_once");
      _uvm_shutdown_phase_once = new uvm_shutdown_phase.uvm_once();
      uvm_shutdown_phase._once = _uvm_shutdown_phase_once;
      // writeln("Done -- _uvm_shutdown_phase_once");
      _uvm_post_shutdown_phase_once = new uvm_post_shutdown_phase.uvm_once();
      uvm_post_shutdown_phase._once = _uvm_post_shutdown_phase_once;
      // writeln("Done -- _uvm_post_shutdown_phase_once");

      // uvm_common_phases;
      _uvm_build_phase_once = new uvm_build_phase.uvm_once();
      uvm_build_phase._once = _uvm_build_phase_once;
      // writeln("Done -- _uvm_build_phase_once");
      _uvm_connect_phase_once = new uvm_connect_phase.uvm_once();
      uvm_connect_phase._once = _uvm_connect_phase_once;
      // writeln("Done -- _uvm_connect_phase_once");
      _uvm_elaboration_phase_once = new uvm_elaboration_phase.uvm_once();
      uvm_elaboration_phase._once = _uvm_elaboration_phase_once;
      // writeln("Done -- _uvm_elaboration_phase_once");
      _uvm_end_of_elaboration_phase_once = new uvm_end_of_elaboration_phase.uvm_once();
      uvm_end_of_elaboration_phase._once = _uvm_end_of_elaboration_phase_once;
      // writeln("Done -- _uvm_end_of_elaboration_phase_once");
      _uvm_start_of_simulation_phase_once = new uvm_start_of_simulation_phase.uvm_once();
      uvm_start_of_simulation_phase._once = _uvm_start_of_simulation_phase_once;
      // writeln("Done -- _uvm_start_of_simulation_phase_once");
      _uvm_run_phase_once = new uvm_run_phase.uvm_once();
      uvm_run_phase._once = _uvm_run_phase_once;
      // writeln("Done -- _uvm_run_phase_once");
      _uvm_extract_phase_once = new uvm_extract_phase.uvm_once();
      uvm_extract_phase._once = _uvm_extract_phase_once;
      // writeln("Done -- _uvm_extract_phase_once");
      _uvm_check_phase_once = new uvm_check_phase.uvm_once();
      uvm_check_phase._once = _uvm_check_phase_once;
      // writeln("Done -- _uvm_check_phase_once");
      _uvm_report_phase_once = new uvm_report_phase.uvm_once();
      uvm_report_phase._once = _uvm_report_phase_once;
      // writeln("Done -- _uvm_report_phase_once");
      _uvm_final_phase_once = new uvm_final_phase.uvm_once();
      uvm_final_phase._once = _uvm_final_phase_once;
      // writeln("Done -- _uvm_final_phase_once");

      _uvm_report_server_once = new uvm_report_server.uvm_once();
      uvm_report_server._once = _uvm_report_server_once;
      // writeln("Done -- _uvm_report_server_once");
      _uvm_callbacks_base_once = new uvm_callbacks_base.uvm_once();
      uvm_callbacks_base._once = _uvm_callbacks_base_once;
      // writeln("Done -- _uvm_callbacks_base_once");
      _uvm_object_globals_once = new uvm_once_object_globals();
      _uvm_object_globals_uvm_once = _uvm_object_globals_once;
      // writeln("Done -- _uvm_object_globals_once");

    }
  }

  package void initialize() {
    // uvm_sequencer_base._once = _uvm_sequencer_base_once;
    // uvm_seed_map._once = _uvm_seed_map_once;
    // uvm_recorder._once = _uvm_recorder_once;
    // uvm_object._once = _uvm_object_once;
    // uvm_component._once = _uvm_component_once;
    // _uvm_config_db_uvm_once = _uvm_config_db_once;
    // uvm_config_db_options._once = _uvm_config_db_options_once;
    // uvm_report_catcher._once = _uvm_report_catcher_once;
    // uvm_report_handler._once = _uvm_report_handler_once;
    // uvm_resource_options._once = _uvm_resource_options_once;
    // uvm_resource_base._once = _uvm_resource_base_once;
    // uvm_resource_pool._once = _uvm_resource_pool_once;
    // uvm_factory._once = _uvm_factory_once;
    // uvm_resource_db_options._once = _uvm_resource_db_options_once;
    // _uvm_domain_once_globals_uvm_once = _uvm_domain_once_globals_once;
    // uvm_domain._once = _uvm_domain_once;
    // uvm_cmdline_processor._once = _uvm_cmdline_processor_once;
    // uvm_objection._once = _uvm_objection_once;
    // uvm_test_done_objection._once = _uvm_test_done_objection_once;
    // uvm_phase._once = _uvm_phase_once;

    // uvm_runtime_phases;
    // uvm_pre_reset_phase._once = _uvm_pre_reset_phase_once;
    // uvm_reset_phase._once = _uvm_reset_phase_once;
    // uvm_post_reset_phase._once = _uvm_post_reset_phase_once;
    // uvm_pre_configure_phase._once = _uvm_pre_configure_phase_once;
    // uvm_configure_phase._once = _uvm_configure_phase_once;
    // uvm_post_configure_phase._once = _uvm_post_configure_phase_once;
    // uvm_pre_main_phase._once = _uvm_pre_main_phase_once;
    // uvm_main_phase._once = _uvm_main_phase_once;
    // uvm_post_main_phase._once = _uvm_post_main_phase_once;
    // uvm_pre_shutdown_phase._once = _uvm_pre_shutdown_phase_once;
    // uvm_shutdown_phase._once = _uvm_shutdown_phase_once;
    // uvm_post_shutdown_phase._once = _uvm_post_shutdown_phase_once;

    // uvm_common_phases;
    // uvm_build_phase._once = _uvm_build_phase_once;
    // uvm_connect_phase._once = _uvm_connect_phase_once;
    // uvm_elaboration_phase._once = _uvm_elaboration_phase_once;
    // uvm_end_of_elaboration_phase._once = _uvm_end_of_elaboration_phase_once;
    // uvm_start_of_simulation_phase._once = _uvm_start_of_simulation_phase_once;
    // uvm_run_phase._once = _uvm_run_phase_once;
    // uvm_extract_phase._once = _uvm_extract_phase_once;
    // uvm_check_phase._once = _uvm_check_phase_once;
    // uvm_report_phase._once = _uvm_report_phase_once;
    // uvm_final_phase._once = _uvm_final_phase_once;
    // uvm_report_server._once = _uvm_report_server_once;
    // uvm_callbacks_base._once = _uvm_callbacks_base_once;
    // _uvm_object_globals_uvm_once = _uvm_object_globals_once;
  }
}



// const uvm_root uvm_top = uvm_root::get();

// // for backward compatibility
// const uvm_root _global_reporter = uvm_root::get();



//-----------------------------------------------------------------------------
//
// Class- uvm_root_report_handler
//
//-----------------------------------------------------------------------------
// Root report has name "reporter"

class uvm_root_report_handler: uvm_report_handler
{
  override public void report(uvm_severity_type severity,
			      string name,
			      string id,
			      string message,
			      int verbosity_level=UVM_MEDIUM,
			      string filename="",
			      size_t line=0,
			      uvm_report_object client=null) {
    if(name == "") name = "reporter";
    super.report(severity, name, id, message, verbosity_level,
		 filename, line, client);
  }
}

public auto uvm_simulate(T)(string name, uint seed,
			    uint multi=1, uint first=0) {
  auto root = new uvm_root_entity!T(name, seed);
  root.multiCore(multi, first);
  root.elaborate();
  root.simulate();
  return root;
}

public auto uvm_elaborate(T)(string name, uint seed,
			     uint multi=1, uint first=0) {
  auto root = new uvm_root_entity!T(name, seed);
  root.multiCore(multi, first);
  root.elaborate();
  // root.simulate();
  return root;
}

public auto uvm_fork(T)(string name, uint seed,
			uint multi=1, uint first=0) {
  auto root = new uvm_root_entity!T(name, seed);
  root.multiCore(multi, first);
  root.elaborate();
  root.fork();
  return root;
}
