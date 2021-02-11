//
//------------------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2010 Paradigm Works
// Copyright 2007-2017 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2018 Intel Corporation
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2020 Marvell International Ltd.
// Copyright 2011-2018 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2012-2018 Cisco Systems, Inc.
// Copyright 2012 Accellera Systems Initiative
// Copyright 2017-2018 Verific
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

module uvm.base.uvm_component;
// typedef class uvm_objection;
// typedef class uvm_sequence_base;
// typedef class uvm_sequence_item;

import uvm.base.uvm_object_globals;
import uvm.base.uvm_object: uvm_object, uvm_field_auto_get_flags;
import uvm.base.uvm_phase: uvm_phase;
import uvm.base.uvm_domain: uvm_domain;
import uvm.base.uvm_common_phases: uvm_build_phase, uvm_run_phase;
import uvm.base.uvm_coreservice: uvm_coreservice_t;
import uvm.base.uvm_root: uvm_root;
import uvm.base.uvm_factory: uvm_object_wrapper, uvm_factory;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_recorder: uvm_recorder;
import uvm.base.uvm_pool: uvm_object_string_pool;
import uvm.base.uvm_transaction: uvm_transaction;
import uvm.base.uvm_event: uvm_event;
import uvm.base.uvm_misc: UVM_ELEMENT_TYPE, UVM_IN_TUPLE;
import uvm.base.uvm_tr_stream: uvm_tr_stream;
import uvm.base.uvm_tr_database: uvm_tr_database;
import uvm.base.uvm_entity: uvm_entity, uvm_entity_base;
import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_port_base: uvm_port_base;
import uvm.base.uvm_resource_base: uvm_resource_base;
import uvm.base.uvm_registry: uvm_abstract_component_registry;

import uvm.base.uvm_scope;

import uvm.meta.meta;		// qualifiedTypeName
import uvm.meta.misc;		// qualifiedTypeName

import esdl.base.core;
import esdl.data.queue;
import esdl.rand.misc: rand;

import std.traits: isIntegral, isAbstractClass, isArray;

import std.string: format;
import std.conv: to;
import std.random: Random;

import std.algorithm;
import std.exception: enforce;

alias uvm_event_pool = uvm_object_string_pool!(uvm_event!(uvm_object));


//----------------------------------------------------------------------
// Class: uvm_component
//
// The library implements the following public API beyond what is 
// documented in 1800.2.
///------------------------------------------------------------------------------
struct m_verbosity_setting {
  string comp;
  string phase;
  SimTime   offset;
  uvm_verbosity verbosity;
  string id;
}

// @uvm-ieee 1800.2-2017 auto 13.1.1
@rand(false)
abstract class uvm_component: uvm_report_object, ParContext
{
  import uvm.base.uvm_objection: uvm_objection;
  import uvm.base.uvm_field_op: uvm_field_op;
  static class uvm_scope: uvm_scope_base
  {
    // m_config_set is declared in SV version but is not used anywhere
    @uvm_private_sync
    private bool _m_config_set = true;

    //
    // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
    @uvm_public_sync
    private bool _print_config_matches;

    private m_verbosity_setting[] _m_time_settings;

    @uvm_private_sync
    private bool _print_config_warned;

    private uint _m_comp_count;

    private uvm_cmdline_parsed_arg_t[] _m_uvm_applied_cl_action;
    @uvm_none_sync
    const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_action() {
      synchronized (this) {
	return _m_uvm_applied_cl_action.dup;
      }
    }

    private uvm_cmdline_parsed_arg_t[] _m_uvm_applied_cl_sev;
    @uvm_none_sync
    const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_sev() {
      synchronized (this) {
	return _m_uvm_applied_cl_sev.dup;
      }
    }

    @uvm_private_sync
    private bool _cl_action_initialized;
    @uvm_private_sync
    private bool _cl_sev_initialized;

    @uvm_none_sync
    void add_m_uvm_applied_cl_action(uvm_cmdline_parsed_arg_t arg) {
      synchronized (this) {
	_m_uvm_applied_cl_action ~= arg;
      }
    }
    @uvm_none_sync
    void add_m_uvm_applied_cl_sev(uvm_cmdline_parsed_arg_t arg) {
      synchronized (this) {
	_m_uvm_applied_cl_sev ~= arg;
      }
    }
  }

  mixin (uvm_scope_sync_string);

  protected const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_action() {
    return _uvm_scope_inst.m_uvm_applied_cl_action();
  }
  protected const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_sev() {
    return _uvm_scope_inst.m_uvm_applied_cl_sev();
  }

  mixin (uvm_sync_string);

  // mixin (ParContextMixinString());

  //////////////////////////////////////////////////////
  // Implementation of the parallelize UDP functionality
  //////////////////////////////////////////////////////

  // Lock to inhibit parallel threads in the same Entity
  // This valriable is set in elaboration phase and in the later
  // phases it is only accessed. Therefor this variable can be
  // treated as effectively immutable.

  // In practice, the end-user does not need to bother about
  // this Lock. It is automatically picked up by the simulator
  // when a process wakes up and subsequently, when the process
  // deactivates (starts waiting for an event), the simulator
  // gives away the Lock
  MulticoreConfig _esdl__multicoreConfig;
  MulticoreConfig _esdl__getHierMulticoreConfig() {
    // of the ParContext does not have a MulticoreConfig Object, get it
    // from the enclosing ParContext
    if (_esdl__multicoreConfig is null) {
      _esdl__multicoreConfig =
	_esdl__parInheritFrom()._esdl__getHierMulticoreConfig();
    }
    return _esdl__multicoreConfig;
  }
  MulticoreConfig _esdl__getMulticoreConfig() {
    // of the ParContext does not have a MulticoreConfig Object, get it
    // from the enclosing ParContext
    return _esdl__multicoreConfig;
  }
  static if (!__traits(compiles, _esdl__parLock)) {
    import core.sync.semaphore: CoreSemaphore = Semaphore;
    CoreSemaphore _esdl__parLock;
  }

  // This variable keeps the information provided by the user as
  // an argument to the parallelize UDP -- For the hierarchy
  // levels where the parallelize UDP is not specified, the value
  // for this variable is copied from the uppper hierarchy
  // This variable is set and used only during the elaboration
  // phase
  static if (!__traits(compiles, _esdl__parInfo)) {
    _esdl__Multicore _esdl__parInfo = _esdl__Multicore(MulticorePolicy._UNDEFINED_,
						       uint.max); // default value
    final _esdl__Multicore _esdl__getParInfo() {
      return _esdl__parInfo;
    }
  }

  // Effectively immutable in the run phase since the variable is
  // set durin gthe elaboration
  final CoreSemaphore _esdl__getParLock() {
    return _esdl__parLock;
  }

  //////////////////////////////////////////////////////////////
  
  _esdl__Multicore _par__info = _esdl__Multicore(MulticorePolicy._UNDEFINED_, uint.max);

  ParContext _esdl__parInheritFrom() {
    import uvm.base.uvm_coreservice;
    auto c = get_parent();
    if (c is null) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      return cs.get_root();
    }
    else return c;
  }

  uint _esdl__parComponentId() {
    return get_id();
  }

  string _esdl__getName() {
    return get_full_name();
  }

  // Function- new
  //
  // Creates a new component with the given leaf instance ~name~ and handle
  // to its ~parent~.  If the component is a top-level component (i.e. it is
  // created in a static module or interface), ~parent~ should be ~null~.
  //
  // The component will be inserted as a child of the ~parent~ object, if any.
  // If ~parent~ already has a child by the given ~name~, an error is produced.
  //
  // If ~parent~ is ~null~, then the component will become a child of the
  // implicit top-level component, ~uvm_top~.
  //
  // All classes derived from uvm_component must call super.new(name,parent).

  // This constructor is called by all the uvm_component derivatives
  // except for uvm_root instances

  // @uvm-ieee 1800.2-2017 auto 13.1.2.1
  this(string name, uvm_component parent) {
    import uvm.base.uvm_root;
    import uvm.base.uvm_entity;
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_config_db;
    synchronized (this) {

      super(name);

      _m_children = null;
      _m_children_by_handle = null;

      // return if the constructor has been called factory processing
      // we do not want uvm_components to be elaborated for the components
      // that were created for the sake of factory
      if (parent is null && name == "" && 
	  uvm_factory.is_active()) return;

      // Since Vlang allows multi uvm_root instances, it is better to
      // have a unique name for each uvm_root instance

      // If uvm_top, reset name to "" so it doesn't show in full paths then return
      // separated to uvm_root specific constructor
      // if (parent is null && name == "__top__") {
      //	set_name(""); // *** VIRTUAL
      //	return;
      // }

      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root top = cs.get_root();

      // Check that we're not in or past end_of_elaboration
      uvm_domain common = uvm_domain.get_common_domain();
      // uvm_phase bld = common.find(uvm_build_phase.get());
      uvm_phase bld = common.find(uvm_build_phase.get());
      if (bld is null) {
	uvm_report_fatal("COMP/INTERNAL",
			 "attempt to find build phase object failed",uvm_verbosity.UVM_NONE);
      }
      if (bld.get_state() == uvm_phase_state.UVM_PHASE_DONE) {
	uvm_report_fatal("ILLCRT", "It is illegal to create a component ('" ~
			 name ~ "' under '" ~
			 (parent is null ? top.get_full_name() :
			  parent.get_full_name()) ~
			 "') after the build phase has ended.",
			 uvm_verbosity.UVM_NONE);
      }

      if (name == "") {
	name = "COMP_" ~ m_inst_count.to!string;
      }

      if (parent is this) {
	uvm_fatal("THISPARENT", "cannot set the parent of a component to itself");
      }

      if (parent is null) {
	parent = top;
      }

      if (uvm_report_enabled(uvm_verbosity.UVM_MEDIUM+1, uvm_severity.UVM_INFO, "NEWCOMP")) {
	uvm_info("NEWCOMP", "Creating " ~
		 (parent is top ? "uvm_top" :
		  parent.get_full_name()) ~ "." ~ name,
		 cast (uvm_verbosity) (uvm_verbosity.UVM_MEDIUM+1));
      }

      if (parent.has_child(name) && this !is parent.get_child(name)) {
	if (parent is top) {
	  string error_str = "Name '" ~ name ~ "' is not unique to other" ~
	    " top-level instances. If parent is a module, build a unique" ~
	    " name by combining the the module name and component name: " ~
	    "$sformatf(\"%m.%s\" ~ \"" ~ name ~ "\").";
	  uvm_fatal("CLDEXT", error_str);
	}
	else {
	  uvm_fatal("CLDEXT",
		    format("Cannot set '%s' as a child of '%s', %s",
			   name, parent.get_full_name(),
			   "which already has a child by that name."));
	}
	return;
      }

      _m_parent = parent;

      set_name(name); // *** VIRTUAL

      if (!_m_parent.m_add_child(this)) {
	_m_parent = null;
      }

      _event_pool = new uvm_event_pool("event_pool");

      _m_domain = parent.m_domain;     // by default, inherit domains from parents

      // Now that inst name is established, reseed (if use_uvm_seeding is set)
      reseed();

      // Do local configuration settings
      // if (!uvm_config_db!(uvm_bitstream_t).get(this, "", "recording_detail", recording_detail)) {
      //   uvm_config_db!(int).get(this, "", "recording_detail", recording_detail);
      // }
      uvm_bitstream_t bs_recording_detail;
      if (uvm_config_db!uvm_bitstream_t.get(this, "", "recording_detail",
					   bs_recording_detail)) {
	_recording_detail = cast (uint) bs_recording_detail;
      }
      else {
	uvm_config_db!uint.get(this, "", "recording_detail", _recording_detail);
      }

      m_rh.set_name(get_full_name()); // m_rh is in base class uvm_report_object
      set_report_verbosity_level(parent.get_report_verbosity_level());

      m_set_cl_msg_args();

    }
  }

  // This function is called for the uvm_root instance only. When the
  // uvm_root's constructor is called (in ESDL build phase), it's name
  // is not yet available. This function is called later as the name
  // of the instance becomes available.
  package void set_root_name(string name) {
    import uvm.base.uvm_root;
    synchronized (this) {
      assert (cast (uvm_root) this);
      if (get_name() == "__top__") {
	super.set_name(name);
	_m_name = name;
      }
      else {
	assert (false, "Called set_root_name on a non-root");
      }
    }
  }

  // Csontructor called by uvm_root constructor
  package this(bool isRoot) {
    synchronized (this) {
      if (isRoot) {
	super("__top__");

	_m_children = null;
	_m_children_by_handle = null;
	// // make sure that we are actually construting a uvm_root
	// auto top = cast (uvm_root) this;
	// assert (top !is null);
      }
      else {
	assert (false, "This constructor is only for uvm_root instanciation");
      }
    }
  }


  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Hierarchy Interface
  //----------------------------------------------------------------------------
  //
  // These methods provide user access to information about the component
  // hierarchy, i.e., topology.
  //
  //----------------------------------------------------------------------------

  // Function- get_parent
  //
  // Returns a handle to this component's parent, or ~null~ if it has no parent.

  // @uvm-ieee 1800.2-2017 auto 13.1.3.1
  uvm_component get_parent() {
    synchronized (this) {
      return _m_parent;
    }
  }

  // No need to add unnecessary dependency on uvm_root -- use
  // uvm_root_intf instead to break dependency
  // Traverse the component hierarchy and return the uvm_root
  import uvm.base.uvm_root: uvm_root_intf;
  uvm_root_intf get_root() {
    return get_parent().get_root();
  }
  
  uvm_entity_base get_entity() {
    return this.get_root.get_entity();
  }
  
  RootEntity get_root_entity() {
    return this.get_entity.getRoot();
  }


  // Function- get_full_name
  //
  // Returns the full hierarchical name of this object. The default
  // implementation concatenates the hierarchical name of the parent, if any,
  // with the leaf name of this object, as given by <uvm_object::get_name>.


  // @uvm-ieee 1800.2-2017 auto 13.1.3.2
  override string get_full_name () {
    synchronized (this) {
      // Note- Implementation choice to construct full name once since the
      // full name may be used often for lookups.
      if (_m_name == "") {
	return get_name();
      }
      else {
	return _m_name;
      }
    }
  }



  // Function- get_children
  //
  // This function populates the end of the ~children~ array with the
  // list of this component's children.
  //
  //|   uvm_component array[$];
  //|   my_comp.get_children(array);
  //|   foreach (array[i])
  //|     do_something(array[i]);

  // @uvm-ieee 1800.2-2017 auto 13.1.3.3
  final void get_children(ref Queue!uvm_component children) {
    synchronized (this) {
      children ~= cast (uvm_component[]) m_children.values;
    }
  }

  final void get_children(ref uvm_component[] children) {
    synchronized (this) {
      children ~= cast (uvm_component[]) m_children.values;
    }
  }

  final uvm_component[] get_children() {
    synchronized (this) {
      return cast (uvm_component[]) m_children.values;
    }
  }


  // get_child
  // ---------

  // @uvm-ieee 1800.2-2017 auto 13.1.3.4
  final uvm_component get_child(string name) {
    synchronized (this) {
      auto pcomp = name in m_children;
      if (pcomp) {
	return cast (uvm_component) *pcomp;
      }
      uvm_warning("NOCHILD", "Component with name '" ~ name ~
		  "' is not a child of component '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  private string[] _children_names;

  // get_next_child
  // --------------

  // @uvm-ieee 1800.2-2017 auto 13.1.3.4
  final int get_next_child(ref string name) {
    synchronized (this) {
      auto found = find(_children_names, name);
      enforce(found.length != 0, "get_next_child could not match a child" ~
	      "with name: " ~ name);
      if (found.length is 1) {
	return 0;
      }
      else {
	name = found[1];
	return 1;
      }
    }
  }

  // Function- get_first_child
  //
  // These methods are used to iterate through this component's children, if
  // any. For example, given a component with an object handle, ~comp~, the
  // following code calls <uvm_object::print> for each child:
  //
  //|    string name;
  //|    uvm_component child;
  //|    if (comp.get_first_child(name))
  //|      do begin
  //|        child = comp.get_child(name);
  //|        child.print();
  //|      end while (comp.get_next_child(name));

  // @uvm-ieee 1800.2-2017 auto 13.1.3.4
  final int get_first_child(ref string name) {
    synchronized (this) {
      _children_names = m_children.keys;
      if (_children_names.length is 0) {
	return 0;
      }
      else {
	sort(_children_names);
	name = _children_names[0];
	return 1;
      }
    }
  }

  // Function- get_num_children
  //
  // Returns the number of this component's children.

  // @uvm-ieee 1800.2-2017 auto 13.1.3.5
  final size_t get_num_children() {
    synchronized (this) {
      return _m_children.length;
    }
  }

  // Function- has_child
  //
  // Returns 1 if this component has a child with the given ~name~, 0 otherwise.

  // @uvm-ieee 1800.2-2017 auto 13.1.3.6
  final bool has_child(string name) {
    synchronized (this) {
      if (name in _m_children) {
	return true;
      }
      else {
	return false;
      }
    }
  }

  // Function - set_name
  //
  // Renames this component to ~name~ and recalculates all descendants'
  // full names. This is an internal function for now.

  override void set_name(string name) {
    synchronized (this) {
      if (_m_name != "") {
	uvm_error("INVSTNM",
		  format("It is illegal to change the name of a component. " ~
			 "The component name will not be changed to \"%s\"",
			 name));
	return;
      }
      super.set_name(name);
      m_set_full_name();
    }
  }

  // package void _set_name_force(string name) {
  //   synchronized (this) {
  //     super.set_name(name);
  //     m_set_full_name();
  //   }
  // }


  // Function- lookup
  //
  // Looks for a component with the given hierarchical ~name~ relative to this
  // component. If the given ~name~ is preceded with a '.' (dot), then the search
  // begins relative to the top level (absolute lookup). The handle of the
  // matching component is returned, else ~null~. The name must not contain
  // wildcards.

  // @uvm-ieee 1800.2-2017 auto 13.1.3.7
  final uvm_component lookup(string name) {
    import uvm.base.uvm_root;
    import uvm.base.uvm_coreservice;
    synchronized (this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root top = cs.get_root(); // uvm_root.get();
      uvm_component comp = this;

      string leaf , remainder;
      m_extract_name(name, leaf, remainder);

      if (leaf == "") {
	comp = top; // absolute lookup
	m_extract_name(remainder, leaf, remainder);
      }

      if (!comp.has_child(leaf)) {
	uvm_warning("Lookup Error",
		    format("Cannot find child %0s", leaf));
	return null;
      }

      if (remainder != "") {
	return (cast (uvm_component) comp.m_children[leaf]).lookup(remainder);
      }

      return (cast (uvm_component) comp.m_children[leaf]);
    }
  }


  // Function- get_depth
  //
  // Returns the component's depth from the root level. uvm_top has a
  // depth of 0. The test and any other top level components have a depth
  // of 1, and so on.

  final uint get_depth() {
    synchronized (this) {
      if (_m_name == "") {
	return 0;
      }
      uint get_depth_ = 1;
      foreach (c; _m_name) {
	if (c is '.') {
	  ++get_depth_;
	}
      }
      return get_depth_;
    }
  }



  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Phasing Interface
  //----------------------------------------------------------------------------
  //
  // These methods implement an interface which allows all components to step
  // through a standard schedule of phases, or a customized schedule, and
  // also an API to allow independent phase domains which can jump like state
  // machines to reflect behavior e.g. power domains on the DUT in different
  // portions of the testbench. The phase tasks and functions are the phase
  // name with the _phase suffix. For example, the build phase function is
  // <build_phase>.
  //
  // All processes associated with a task-based phase are killed when the phase
  // ends. See <uvm_task_phase> for more details.
  //----------------------------------------------------------------------------


  // Function- build_phase
  //
  // The <uvm_build_phase> phase implementation method.
  //
  // Any override should call super.build_phase(phase) to execute the automatic
  // configuration of fields registered in the component by calling
  // <apply_config_settings>.
  // To turn off automatic configuration for a component,
  // do not call super.build_phase(phase).
  //
  // This method should never be called directly.

  // phase methods
  //--------------
  // these are prototypes for the methods to be implemented in user components
  // build_phase() has a default implementation, the others have an empty default

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.1
  void build_phase(uvm_phase phase) {
    synchronized (this) {
      _m_build_done = true;
      if (use_automatic_config())
	apply_config_settings(print_config_matches);
    }
  }

  // base function for auto build phase
  @uvm_public_sync
  private bool _uvm__parallelize_done = false;

  void uvm__auto_build() {
    debug(UVM_AUTO) {
      import std.stdio;
      writeln("Building .... : ", get_full_name);
    }
    // super is called in m_uvm_component_automation
    // super.uvm__auto_build(); --
    m_uvm_component_automation(uvm_field_auto_enum.UVM_BUILD);
    // .uvm__auto_build!(0, typeof(this))(this);
  }

  void uvm__parallelize() {
    // super is called in m_uvm_component_automation
    // super.uvm__parallelize();
    m_uvm_component_automation(uvm_field_xtra_enum.UVM_PARALLELIZE);
    // .uvm__auto_build!(0, typeof(this))(this);
  }

  // Function- connect_phase
  //
  // The <uvm_connect_phase> phase implementation method.
  //
  // This method should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.2
  void connect_phase(uvm_phase phase) {
    return;
  }

  // Function- setup_phase
  //
  // The <uvm_setup_phase> phase implementation method.
  //
  // This method should never be called directly.

  void setup_phase(uvm_phase phase) {}

  // Function- end_of_elaboration_phase
  //
  // The <uvm_end_of_elaboration_phase> phase implementation method.
  //
  // This method should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.3
  void end_of_elaboration_phase(uvm_phase phase) {
    return;
  }

  // Function- start_of_simulation_phase
  //
  // The <uvm_start_of_simulation_phase> phase implementation method.
  //
  // This method should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.4
  void start_of_simulation_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- run_phase
  //
  // The <uvm_run_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // Thus the phase will automatically
  // end once all objections are dropped using ~phase.drop_objection()~.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // The run_phase task should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.5
  // task
  void run_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- pre_reset_phase
  //
  // The <uvm_pre_reset_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.1
  // task
  void pre_reset_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- reset_phase
  //
  // The <uvm_reset_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.2
  // task
  void reset_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- post_reset_phase
  //
  // The <uvm_post_reset_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.3
  // task
  void post_reset_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- pre_configure_phase
  //
  // The <uvm_pre_configure_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.4
  // task
  void pre_configure_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- configure_phase
  //
  // The <uvm_configure_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.5
  // task
  void configure_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- post_configure_phase
  //
  // The <uvm_post_configure_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.6
  // task
  void post_configure_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- pre_main_phase
  //
  // The <uvm_pre_main_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.7
  // task
  void pre_main_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- main_phase
  //
  // The <uvm_main_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.8
  // task
  void main_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- post_main_phase
  //
  // The <uvm_post_main_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.9
  // task
  void post_main_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- pre_shutdown_phase
  //
  // The <uvm_pre_shutdown_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.10
  // task
  void pre_shutdown_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- shutdown_phase
  //
  // The <uvm_shutdown_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.11
  // task
  void shutdown_phase(uvm_phase phase) {
    return;
  }

  // Task -- NODOCS -- post_shutdown_phase
  //
  // The <uvm_post_shutdown_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // It is necessary to raise an objection
  // using ~phase.raise_objection()~ to cause the phase to persist.
  // Once all components have dropped their respective objection
  // using ~phase.drop_objection()~, or if no components raises an
  // objection, the phase is ended.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // This method should not be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.2.12
  // task
  void post_shutdown_phase(uvm_phase phase) {
    return;
  }

  // Function- extract_phase
  //
  // The <uvm_extract_phase> phase implementation method.
  //
  // This method should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.6
  void extract_phase(uvm_phase phase) {
    return;
  }

  // Function- check_phase
  //
  // The <uvm_check_phase> phase implementation method.
  //
  // This method should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.7
  void check_phase(uvm_phase phase) {
    return;
  }

  // Function- report_phase
  //
  // The <uvm_report_phase> phase implementation method.
  //
  // This method should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.8
  void report_phase(uvm_phase phase) {
    return;
  }

  // Function- final_phase
  //
  // The <uvm_final_phase> phase implementation method.
  //
  // This method should never be called directly.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.1.9
  void final_phase(uvm_phase phase) {
    return;
  }

  // Function- phase_started
  //
  // Invoked at the start of each phase. The ~phase~ argument specifies
  // the phase being started. Any threads spawned in this callback are
  // not affected when the phase ends.

  // phase_started
  // -------------
  // phase_started() and phase_ended() are extra callbacks called at the
  // beginning and end of each phase, respectively.  Since they are
  // called for all phases the phase is passed in as an argument so the
  // extender can decide what to do, if anything, for each phase.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.3.1
  void phase_started(uvm_phase phase) { }

  // Function- phase_ready_to_end
  //
  // Invoked when all objections to ending the given ~phase~ and all
  // sibling phases have been dropped, thus indicating that ~phase~ is
  // ready to begin a clean exit. Sibling phases are any phases that
  // have a common successor phase in the schedule plus any phases that
  // sync'd to the current phase. Components needing to consume delta
  // cycles or advance time to perform a clean exit from the phase
  // may raise the phase's objection.
  //
  // |phase.raise_objection(this,"Reason");
  //
  // It is the responsibility of this component to drop the objection
  // once it is ready for this phase to end (and processes killed).
  // If no objection to the given ~phase~ or sibling phases are raised,
  // then phase_ended() is called after a delta cycle.  If any objection
  // is raised, then when all objections to ending the given ~phase~
  // and siblings are dropped, another iteration of phase_ready_to_end
  // is called.  To prevent endless iterations due to coding error,
  // after 20 iterations, phase_ended() is called regardless of whether
  // previous iteration had any objections raised.

  // phase_ready_to_end
  // ------------------

  // @uvm-ieee 1800.2-2017 auto 13.1.4.3.2
  void phase_ready_to_end (uvm_phase phase) { }

  // Function- phase_ended
  //
  // Invoked at the end of each phase. The ~phase~ argument specifies
  // the phase that is ending.  Any threads spawned in this callback are
  // not affected when the phase ends.

  // phase_ended
  // -----------

  // @uvm-ieee 1800.2-2017 auto 13.1.4.3.3
  void phase_ended(uvm_phase phase) { }

  //------------------------------
  // phase / schedule / domain API
  //------------------------------
  // methods for VIP creators and integrators to use to set up schedule domains
  // - a schedule is a named, organized group of phases for a component base type
  // - a domain is a named instance of a schedule in the master phasing schedule



  // Function- set_domain
  //
  // Apply a phase domain to this component and, if ~hier~ is set,
  // recursively to all its children.
  //
  // Calls the virtual <define_domain> method, which derived components can
  // override to augment or replace the domain definition of its base class.
  //

  // set_domain
  // ----------
  // assigns this component [tree] to a domain. adds required schedules into graph
  // If called from build, ~hier~ won't recurse into all chilren (which don't exist yet)
  // If we have components inherit their parent's domain by default, then ~hier~
  // isn't needed and we need a way to prevent children from inheriting this component's domain

  // @uvm-ieee 1800.2-2017 auto 13.1.4.4.1
  final void set_domain(uvm_domain domain, bool hier=true) {
    synchronized (this) {
      // build and store the custom domain
      _m_domain = domain;
      define_domain(domain);
      if (hier) {
	foreach (c; m_children) {
	  (cast (uvm_component) c).set_domain(domain);
	}
      }
    }
  }

  // Function- get_domain
  //
  // Return handle to the phase domain set on this component

  // @uvm-ieee 1800.2-2017 auto 13.1.4.4.2
  final uvm_domain get_domain() {
    synchronized (this) {
      return _m_domain;
    }
  }

  // Function- define_domain
  //
  // Builds custom phase schedules into the provided ~domain~ handle.
  //
  // This method is called by <set_domain>, which integrators use to specify
  // this component belongs in a domain apart from the default 'uvm' domain.
  //
  // Custom component base classes requiring a custom phasing schedule can
  // augment or replace the domain definition they inherit by overriding
  // their ~defined_domain~. To augment, overrides would call super.define_domain().
  // To replace, overrides would not call super.define_domain().
  //
  // The default implementation adds a copy of the ~uvm~ phasing schedule to
  // the given ~domain~, if one doesn't already exist, and only if the domain
  // is currently empty.
  //
  // Calling <set_domain>
  // with the default ~uvm~ domain (i.e. <uvm_domain::get_uvm_domain>) on
  // a component with no ~define_domain~ override effectively reverts the
  // that component to using the default ~uvm~ domain. This may be useful
  // if a branch of the testbench hierarchy defines a custom domain, but
  // some child sub-branch should remain in the default ~uvm~ domain,
  // call <set_domain> with a new domain instance handle with ~hier~ set.
  // Then, in the sub-branch, call <set_domain> with the default ~uvm~ domain handle,
  // obtained via <uvm_domain::get_uvm_domain>.
  //
  // Alternatively, the integrator may define the graph in a new domain externally,
  // then call <set_domain> to apply it to a component.


  // @uvm-ieee 1800.2-2017 auto 13.1.4.4.3
  final void define_domain(uvm_domain domain) {
    synchronized (this) {
      //schedule = domain.find(uvm_domain::get_uvm_schedule());
      uvm_phase schedule = domain.find_by_name("uvm_sched");
      if (schedule is null) {
	schedule = new uvm_phase("uvm_sched", uvm_phase_type.UVM_PHASE_SCHEDULE);
	uvm_domain.add_uvm_phases(schedule);
	domain.add(schedule);
	uvm_domain common = uvm_domain.get_common_domain();
	if (common.find(domain, 0) is null) {
	  common.add(domain, uvm_run_phase.get());
	}
      }
    }
  }

  // Task -- NODOCS -- suspend
  //
  // Suspend this component.
  //
  // This method must be implemented by the user to suspend the
  // component according to the protocol and functionality it implements.
  // A suspended component can be subsequently resumed using <resume()>.


  // @uvm-ieee 1800.2-2017 auto 13.1.4.5.1
  // task
  void suspend() {
    uvm_warning("COMP/SPND/UNIMP", "suspend() not implemented");
  }

  // Task -- NODOCS -- resume
  //
  // Resume this component.
  //
  // This method must be implemented by the user to resume a component
  // that was previously suspended using <suspend()>.
  // Some component may start in the suspended state and
  // may need to be explicitly resumed.


  // @uvm-ieee 1800.2-2017 auto 13.1.4.5.2
  // task
  void resume() {
    uvm_warning("COMP/RSUM/UNIMP", "resume() not implemented");
  }


  // Function- resolve_bindings
  //
  // Processes all port, export, and imp connections. Checks whether each port's
  // min and max connection requirements are met.
  //
  // It is called just before the end_of_elaboration phase.
  //
  // Users should not call directly.


  // resolve_bindings
  // ----------------

  void resolve_bindings() {
    return;
  }


  final string massage_scope(string scope_stack) {

    // uvm_top
    if (scope_stack == "") {
      return "^$";
    }

    if (scope_stack == "*") {
      return get_full_name() ~ ".*";
    }

    // absolute path to the top-level test
    if (scope_stack == "uvm_test_top") {
      return "uvm_test_top";
    }

    // absolute path to uvm_root
    if (scope_stack[0] is '.') {
      return get_full_name() ~ scope_stack;
    }

    return get_full_name() ~ "." ~ scope_stack;
  }

  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Configuration Interface
  //----------------------------------------------------------------------------
  //
  // Components can be designed to be user-configurable in terms of its
  // topology (the type and number of children it has), mode of operation, and
  // run-time parameters (knobs). The configuration interface accommodates
  // this common need, allowing component composition and state to be modified
  // without having to derive new classes or new class hierarchies for
  // every configuration scenario.
  //
  //----------------------------------------------------------------------------



  // Function- apply_config_settings
  //
  // Searches for all config settings matching this component's instance path.
  // For each match, the appropriate set_*_local method is called using the
  // matching config setting's field_name and value. Provided the set_*_local
  // method is implemented, the component property associated with the
  // field_name is assigned the given value.
  //
  // This function is called by <uvm_component::build_phase>.
  //
  // The apply_config_settings method determines all the configuration
  // settings targeting this component and calls the appropriate set_*_local
  // method to set each one. To work, you must override one or more set_*_local
  // methods to accommodate setting of your component's specific properties.
  // Any properties registered with the optional `uvm_*_field macros do not
  // require special handling by the set_*_local methods; the macros provide
  // the set_*_local functionality for you.
  //
  // If you do not want apply_config_settings to be called for a component,
  // then the build_phase() method should be overloaded and you should not call
  // super.build_phase(phase). Likewise, apply_config_settings can be overloaded to
  // customize automated configuration.
  //
  // When the ~verbose~ bit is set, all overrides are printed as they are
  // applied. If the component's <print_config_matches> property is set, then
  // apply_config_settings is automatically called with ~verbose~ = 1.

  // @uvm-ieee 1800.2-2017 auto 13.1.5.1
  void apply_config_settings (bool verbose=false) {
    import uvm.base.uvm_resource;
    import uvm.base.uvm_resource_base;
    import uvm.base.uvm_pool;
    import uvm.base.uvm_queue;

    uvm_resource_pool rp = uvm_resource_pool.get();

    // The following is VERY expensive. Needs refactoring. Should
    // get config only for the specific field names in 'field_array'.
    // That's because the resource pool is organized first by field name.
    // Can further optimize by encoding the value for each 'field_array'
    // entry to indicate string, uvm_bitstream_t, or object. That way,
    // we call 'get' for specific fields of specific types rather than
    // the search-and-cast approach here.
    uvm_queue!(uvm_resource_base) rq = rp.lookup_scope(get_full_name());
    rp.sort_by_precedence(rq);

    // rq is in precedence order now, so we have to go through in reverse
    // order to do the settings.
    for (ptrdiff_t i = rq.length-1; i >= 0; --i) {
      uvm_resource_base r = rq.get(i);

      if (verbose)
	uvm_report_info("CFGAPL",
			format("applying configuration to field %s",
			       r.get_name()), uvm_verbosity.UVM_NONE);
      set_local(r);
      
    }
  }

  // Function -- NODOCS -- use_automatic_config
  //
  // Returns 1 if the component should call <apply_config_settings> in the <build_phase>;
  // otherwise, returns 0.
  //
  // @uvm-ieee 1800.2-2017 auto 13.1.5.2
  bool use_automatic_config() {
    return true;
  }



  // Function- print_config
  //
  // Print_config prints all configuration information for this
  // component, as set by previous calls to set_config_* and exports to
  // the resources pool.  The settings are printed in the order of
  // their precedence.
  //
  // If ~recurse~ is set, then configuration information for all
  // children and below are printed as well.
  //
  // if ~audit~ is set then the audit trail for each resource is printed
  // along with the resource name and value
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

  final void print_config(bool recurse = false, bool audit = false) {

    import uvm.base.uvm_resource;
    import uvm.base.uvm_pool;

    uvm_resource_pool rp = uvm_resource_pool.get();

    uvm_report_info("CFGPRT", "visible resources:", uvm_severity.UVM_INFO);
    rp.print_resources(rp.lookup_scope(get_full_name()), audit);

    if (recurse) {
      foreach (c; m_children) {
	(cast (uvm_component) c).print_config(recurse, audit);
      }
    }

  }

  // Function- print_config_with_audit
  //
  // Operates the same as print_config except that the audit bit is
  // forced to 1.  This interface makes user code a bit more readable as
  // it avoids multiple arbitrary bit settings in the argument list.
  //
  // If ~recurse~ is set, then configuration information for all
  // children and below are printed as well.

  final void print_config_with_audit(bool recurse = false) {
    print_config(recurse, true);
  }


  // Variable -- NODOCS -- print_config_matches
  //
  // Setting this static variable causes uvm_config_db::get() to print info about
  // matching configuration settings as they are being applied.

  // moved to uvm_scope
  //   __gshared bit print_config_matches;


  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Objection Interface
  //----------------------------------------------------------------------------
  //
  // These methods provide object level hooks into the <uvm_objection>
  // mechanism.
  //
  //----------------------------------------------------------------------------


  // Function- raised
  //
  // The ~raised~ callback is called when this or a descendant of this component
  // instance raises the specified ~objection~. The ~source_obj~ is the object
  // that originally raised the objection.
  // The ~description~ is optionally provided by the ~source_obj~ to give a
  // reason for raising the objection. The ~count~ indicates the number of
  // objections raised by the ~source_obj~.

  // @uvm-ieee 1800.2-2017 auto 13.1.5.4
  void raised (uvm_objection objection, uvm_object source_obj,
	       string description, int count) { }


  // Function- dropped
  //
  // The ~dropped~ callback is called when this or a descendant of this component
  // instance drops the specified ~objection~. The ~source_obj~ is the object
  // that originally dropped the objection.
  // The ~description~ is optionally provided by the ~source_obj~ to give a
  // reason for dropping the objection. The ~count~ indicates the number of
  // objections dropped by the ~source_obj~.

  // @uvm-ieee 1800.2-2017 auto 13.1.5.5
  void dropped (uvm_objection objection, uvm_object source_obj,
		string description, int count) { }


  // Task -- NODOCS -- all_dropped
  //
  // The ~all_droppped~ callback is called when all objections have been
  // dropped by this component and all its descendants.  The ~source_obj~ is the
  // object that dropped the last objection.
  // The ~description~ is optionally provided by the ~source_obj~ to give a
  // reason for raising the objection. The ~count~ indicates the number of
  // objections dropped by the ~source_obj~.

  // @uvm-ieee 1800.2-2017 auto 13.1.5.6
  // task
  void all_dropped (uvm_objection objection, uvm_object source_obj,
		    string description, int count) { }

  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Factory Interface
  //----------------------------------------------------------------------------
  //
  // The factory interface provides convenient access to a portion of UVM's
  // <uvm_factory> interface. For creating new objects and components, the
  // preferred method of accessing the factory is via the object or component
  // wrapper (see <uvm_component_registry #(T,Tname)> and
  // <uvm_object_registry #(T,Tname)>). The wrapper also provides functions
  // for setting type and instance overrides.
  //
  //----------------------------------------------------------------------------

  // Function- create_component
  //
  // A convenience function for <uvm_factory::create_component_by_name>,
  // this method calls upon the factory to create a new child component
  // whose type corresponds to the preregistered type name, ~requested_type_name~,
  // and instance name, ~name~. This method is equivalent to:
  //
  //|  factory.create_component_by_name(requested_type_name,
  //|                                   get_full_name(), name, this);
  //
  // If the factory determines that a type or instance override exists, the type
  // of the component created may be different than the requested type. See
  // <set_type_override> and <set_inst_override>. See also <uvm_factory> for
  // details on factory operation.

  final uvm_component create_component (string requested_type_name,
					string name) {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    return factory.create_component_by_name(requested_type_name,
					    get_full_name(),
					    name, this);
  }

  // Function- create_object
  //
  // A convenience function for <uvm_factory::create_object_by_name>,
  // this method calls upon the factory to create a new object
  // whose type corresponds to the preregistered type name,
  // ~requested_type_name~, and instance name, ~name~. This method is
  // equivalent to:
  //
  //|  factory.create_object_by_name(requested_type_name,
  //|                                get_full_name(), name);
  //
  // If the factory determines that a type or instance override exists, the
  // type of the object created may be different than the requested type.  See
  // <uvm_factory> for details on factory operation.

  final uvm_object create_object (string requested_type_name,
				  string name = "") {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    return factory.create_object_by_name(requested_type_name,
					 get_full_name(), name);
  }



  // Function- set_type_override_by_type
  //
  // A convenience function for <uvm_factory::set_type_override_by_type>, this
  // method registers a factory override for components and objects created at
  // this level of hierarchy or below. This method is equivalent to:
  //
  //|  factory.set_type_override_by_type(original_type, override_type,replace);
  //
  // The ~relative_inst_path~ is relative to this component and may include
  // wildcards. The ~original_type~ represents the type that is being overridden.
  // In subsequent calls to <uvm_factory::create_object_by_type> or
  // <uvm_factory::create_component_by_type>, if the requested_type matches the
  // ~original_type~ and the instance paths match, the factory will produce
  // the ~override_type~.
  //
  // The original and override type arguments are lightweight proxies to the
  // types they represent. See <set_inst_override_by_type> for information
  // on usage.

  static void set_type_override_by_type(uvm_object_wrapper original_type,
					uvm_object_wrapper override_type,
					bool replace = true) {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    factory.set_type_override_by_type(original_type, override_type,
				      replace);
  }


  // Function- set_inst_override_by_type
  //
  // A convenience function for <uvm_factory::set_inst_override_by_type>, this
  // method registers a factory override for components and objects created at
  // this level of hierarchy or below. In typical usage, this method is
  // equivalent to:
  //
  //|  factory.set_inst_override_by_type( original_type,
  //|                                     override_type,
  //|                                     {get_full_name(),".",
  //|                                      relative_inst_path});
  //
  // The ~relative_inst_path~ is relative to this component and may include
  // wildcards. The ~original_type~ represents the type that is being overridden.
  // In subsequent calls to <uvm_factory::create_object_by_type> or
  // <uvm_factory::create_component_by_type>, if the requested_type matches the
  // ~original_type~ and the instance paths match, the factory will produce the
  // ~override_type~.
  //
  // The original and override types are lightweight proxies to the types they
  // represent. They can be obtained by calling ~type::get_type()~, if
  // implemented by ~type~, or by directly calling ~type::type_id::get()~, where
  // ~type~ is the user type and ~type_id~ is the name of the typedef to
  // <uvm_object_registry #(T,Tname)> or <uvm_component_registry #(T,Tname)>.
  //
  // If you are employing the `uvm_*_utils macros, the typedef and the get_type
  // method will be implemented for you. For details on the utils macros
  // refer to <Utility and Field Macros for Components and Objects>.
  //
  // The following example shows `uvm_*_utils usage:
  //
  //|  class comp extends uvm_component;
  //|    `uvm_component_utils(comp)
  //|    ...
  //|  endclass
  //|
  //|  class mycomp extends uvm_component;
  //|    `uvm_component_utils(mycomp)
  //|    ...
  //|  endclass
  //|
  //|  class block extends uvm_component;
  //|    `uvm_component_utils(block)
  //|    comp c_inst;
  //|    virtual function void build_phase(uvm_phase phase);
  //|      set_inst_override_by_type("c_inst",comp::get_type(),
  //|                                         mycomp::get_type());
  //|    endfunction
  //|    ...
  //|  endclass

  final void set_inst_override_by_type(string relative_inst_path,
				       uvm_object_wrapper original_type,
				       uvm_object_wrapper override_type) {
    import uvm.base.uvm_coreservice;
    string full_inst_path;

    if (relative_inst_path == "") {
      full_inst_path = get_full_name();
    }
    else {
      full_inst_path = get_full_name() ~ "." ~ relative_inst_path;
    }

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    factory.set_inst_override_by_type(original_type, override_type,
				      full_inst_path);
  }

  // Function- set_type_override
  //
  // A convenience function for <uvm_factory::set_type_override_by_name>,
  // this method configures the factory to create an object of type
  // ~override_type_name~ whenever the factory is asked to produce a type
  // represented by ~original_type_name~.  This method is equivalent to:
  //
  //|  factory.set_type_override_by_name(original_type_name,
  //|                                    override_type_name, replace);
  //
  // The ~original_type_name~ typically refers to a preregistered type in the
  // factory. It may, however, be any arbitrary string. Subsequent calls to
  // create_component or create_object with the same string and matching
  // instance path will produce the type represented by override_type_name.
  // The ~override_type_name~ must refer to a preregistered type in the factory.

  static void set_type_override(string original_type_name,
				string override_type_name,
				bool replace = true) {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    factory.set_type_override_by_name(original_type_name,
				      override_type_name, replace);
  }



  // Function- set_inst_override
  //
  // A convenience function for <uvm_factory::set_inst_override_by_name>, this
  // method registers a factory override for components created at this level
  // of hierarchy or below. In typical usage, this method is equivalent to:
  //
  //|  factory.set_inst_override_by_name(original_type_name,
  //|                                    override_type_name,
  //|                                    {get_full_name(),".",
  //|                                     relative_inst_path}
  //|                                     );
  //
  // The ~relative_inst_path~ is relative to this component and may include
  // wildcards. The ~original_type_name~ typically refers to a preregistered type
  // in the factory. It may, however, be any arbitrary string. Subsequent calls
  // to create_component or create_object with the same string and matching
  // instance path will produce the type represented by ~override_type_name~.
  // The ~override_type_name~ must refer to a preregistered type in the factory.

  final void  set_inst_override(string relative_inst_path,
				string original_type_name,
				string override_type_name) {
    import uvm.base.uvm_coreservice;
    string full_inst_path;

    if (relative_inst_path == "") {
      full_inst_path = get_full_name();
    }
    else {
      full_inst_path = get_full_name() ~ "." ~ relative_inst_path;
    }

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    factory.set_inst_override_by_name(original_type_name,
				      override_type_name,
				      full_inst_path);
  }


  // Function- print_override_info
  //
  // This factory debug method performs the same lookup process as create_object
  // and create_component, but instead of creating an object, it prints
  // information about what type of object would be created given the
  // provided arguments.

  final void  print_override_info (string requested_type_name,
				   string name = "") {
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_factory factory = cs.get_factory();
    factory.debug_create_by_name(requested_type_name,
				 get_full_name(), name);
  }



  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Hierarchical Reporting Interface
  //----------------------------------------------------------------------------
  //
  // This interface provides versions of the set_report_* methods in the
  // <uvm_report_object> base class that are applied recursively to this
  // component and all its children.
  //
  // When a report is issued and its associated action has the LOG bit set, the
  // report will be sent to its associated FILE descriptor.
  //----------------------------------------------------------------------------

  // Function- set_report_id_verbosity_hier

  final void set_report_id_verbosity_hier( string id, uvm_verbosity verbosity) {
    set_report_id_verbosity(id, verbosity);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_id_verbosity_hier(id, verbosity);
    }
  }


  // Function- set_report_severity_id_verbosity_hier
  //
  // These methods recursively associate the specified verbosity with reports of
  // the given ~severity~, ~id~, or ~severity-id~ pair. A verbosity associated
  // with a particular severity-id pair takes precedence over a verbosity
  // associated with id, which takes precedence over an verbosity associated
  // with a severity.
  //
  // For a list of severities and their default verbosities, refer to
  // <uvm_report_handler>.

  final void set_report_severity_id_verbosity_hier( uvm_severity severity,
						    string id,
						    uvm_verbosity verbosity) {
    set_report_severity_id_verbosity(severity, id, verbosity);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_severity_id_verbosity_hier(severity, id, verbosity);
    }
  }


  // Function- set_report_severity_action_hier

  final void set_report_severity_action_hier( uvm_severity severity,
					      uvm_action action) {
    set_report_severity_action(severity, action);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_severity_action_hier(severity, action);
    }
  }



  // Function- set_report_id_action_hier

  final void set_report_id_action_hier( string id, uvm_action action) {
    set_report_id_action(id, action);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_id_action_hier(id, action);
    }
  }

  // Function- set_report_severity_id_action_hier
  //
  // These methods recursively associate the specified action with reports of
  // the given ~severity~, ~id~, or ~severity-id~ pair. An action associated
  // with a particular severity-id pair takes precedence over an action
  // associated with id, which takes precedence over an action associated
  // with a severity.
  //
  // For a list of severities and their default actions, refer to
  // <uvm_report_handler>.

  final void set_report_severity_id_action_hier( uvm_severity severity,
						 string id,
						 uvm_action action) {
    set_report_severity_id_action(severity, id, action);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_severity_id_action_hier(severity, id, action);
    }
  }

  // Function- set_report_default_file_hier

  final void set_report_default_file_hier(UVM_FILE file) {
    set_report_default_file(file);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_default_file_hier(file);
    }
  }


  // Function- set_report_severity_file_hier

  final void set_report_severity_file_hier( uvm_severity severity,
					    UVM_FILE file) {
    set_report_severity_file(severity, file);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_severity_file_hier(severity, file);
    }
  }

  // Function- set_report_id_file_hier

  final void set_report_id_file_hier(string id, UVM_FILE file) {
    set_report_id_file(id, file);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_id_file_hier(id, file);
    }
  }


  // Function- set_report_severity_id_file_hier
  //
  // These methods recursively associate the specified FILE descriptor with
  // reports of the given ~severity~, ~id~, or ~severity-id~ pair. A FILE
  // associated with a particular severity-id pair takes precedence over a FILE
  // associated with id, which take precedence over an a FILE associated with a
  // severity, which takes precedence over the default FILE descriptor.
  //
  // For a list of severities and other information related to the report
  // mechanism, refer to <uvm_report_handler>.

  final void set_report_severity_id_file_hier(uvm_severity severity,
					      string id,
					      UVM_FILE file) {
    set_report_severity_id_file(severity, id, file);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_severity_id_file_hier(severity, id, file);
    }
  }


  // Function- set_report_verbosity_level_hier
  //
  // This method recursively sets the maximum verbosity level for reports for
  // this component and all those below it. Any report from this component
  // subtree whose verbosity exceeds this maximum will be ignored.
  //
  // See <uvm_report_handler> for a list of predefined message verbosity levels
  // and their meaning.

  final void set_report_verbosity_level_hier(uvm_verbosity verbosity) {
    set_report_verbosity_level(verbosity);
    foreach (c; m_children) {
      (cast (uvm_component) c).set_report_verbosity_level_hier(verbosity);
    }
  }

  // Function- pre_abort
  //
  // This callback is executed when the message system is executing a
  // <UVM_EXIT> action. The exit action causes an immediate termination of
  // the simulation, but the pre_abort callback hook gives components an
  // opportunity to provide additional information to the user before
  // the termination happens. For example, a test may want to executed
  // the report function of a particular component even when an error
  // condition has happened to force a premature termination you would
  // write a function like:
  //
  //| function void mycomponent::pre_abort();
  //|   report();
  //| endfunction
  //
  // The pre_abort() callback hooks are called in a bottom-up fashion.

  // @uvm-ieee 1800.2-2017 auto 13.1.4.6
  void pre_abort() { }

  //----------------------------------------------------------------------------
  // Group -- NODOCS -- Recording Interface
  //----------------------------------------------------------------------------
  // These methods comprise the component-based transaction recording
  // interface. The methods can be used to record the transactions that
  // this component "sees", i.e. produces or consumes.
  //
  // The API and implementation are subject to change once a vendor-independent
  // use-model is determined.
  //----------------------------------------------------------------------------

  // Function- accept_tr
  //
  // This function marks the acceptance of a transaction, ~tr~, by this
  // component. Specifically, it performs the following actions:
  //
  // - Calls the ~tr~'s <uvm_transaction::accept_tr> method, passing to it the
  //   ~accept_time~ argument.
  //
  // - Calls this component's <do_accept_tr> method to allow for any post-begin
  //   action in derived classes.
  //
  // - Triggers the component's internal accept_tr event. Any processes waiting
  //   on this event will resume in the next delta cycle.

  // accept_tr
  // ---------

  // @uvm-ieee 1800.2-2017 auto 13.1.6.1
  final void accept_tr(uvm_transaction tr,
		       SimTime accept_time = 0) {
    if (tr is null)
      return;
    synchronized (this) {
      tr.accept_tr(accept_time);
      do_accept_tr(tr);
      uvm_event!uvm_object e = event_pool.get("accept_tr");
      if (e !is null)  {
	e.trigger();
      }
    }
  }



  // Function- do_accept_tr
  //
  // The <accept_tr> method calls this function to accommodate any user-defined
  // post-accept action. Implementations should call super.do_accept_tr to
  // ensure correct operation.

  // @uvm-ieee 1800.2-2017 auto 13.1.6.2
  protected void do_accept_tr (uvm_transaction tr) {
    return;
  }


  // Function: begin_tr
  // Implementation of uvm_component::begin_tr as described in IEEE 1800.2-2017.
  //
  //| function int begin_tr( uvm_transaction tr,
  //|                        string stream_name="main",
  //|                        string label="",
  //|                        string desc="",
  //|                        time begin_time=0,
  //|                        int parent_handle=0 );
  // 
  // As an added feature, this implementation will attempt to get a non-0 
  // parent_handle from the parent sequence of the transaction tr if the 
  // parent_handle argument is 0 and the transaction can be cast to a 
  // uvm_sequence_item.
 
   // @uvm-ieee 1800.2-2017 auto 13.1.6.3
  final int begin_tr (uvm_transaction tr,
		      string stream_name = "main",
		      string label = "",
		      string desc = "",
		      SimTime begin_time = 0,
		      int parent_handle = 0) {
    return m_begin_tr(tr, parent_handle, stream_name, label, desc, begin_time);
  }


  // Function- do_begin_tr
  //
  // The <begin_tr> and <begin_child_tr> methods call this function to
  // accommodate any user-defined post-begin action. Implementations should call
  // super.do_begin_tr to ensure correct operation.

  // @uvm-ieee 1800.2-2017 auto 13.1.6.4
  protected void do_begin_tr (uvm_transaction tr,
			      string stream_name,
			      int tr_handle) {
    return;
  }

  // Function- end_tr
  //
  // This function marks the end of a transaction, ~tr~, by this component.
  // Specifically, it performs the following actions:
  //
  // - Calls ~tr~'s <uvm_transaction::end_tr> method, passing to it the
  //   ~end_time~ argument. The ~end_time~ must at least be greater than the
  //   begin time. By default, when ~end_time~ = 0, the current simulation time
  //   is used.
  //
  //   The transaction's properties are recorded to the database-transaction on
  //   which it was started, and then the transaction is ended. Only those
  //   properties handled by the transaction's do_record method (and optional
  //   `uvm_*_field macros) are recorded.
  //
  // - Calls the component's <do_end_tr> method to accommodate any post-end
  //   action in derived classes.
  //
  // - Triggers the component's internal end_tr event. Any processes waiting on
  //   this event will resume in the next delta cycle.
  //
  // The ~free_handle~ bit indicates that this transaction is no longer needed.
  // The implementation of free_handle is vendor-specific.

  // @uvm-ieee 1800.2-2017 auto 13.1.6.5
  final void end_tr (uvm_transaction tr,
		     SimTime end_time = 0,
		     bool free_handle = true) {
    if (tr is null) return;
    synchronized (this) {
      uvm_recorder recorder;
      tr.end_tr(end_time, free_handle);

      if ((cast (uvm_verbosity) _recording_detail) != uvm_verbosity.UVM_NONE) {
	if (tr in _m_tr_h) {
	  recorder = _m_tr_h[tr];
	}
      }

      do_end_tr(tr, (recorder is null) ? 0: recorder.get_handle()); // callback

      if (recorder !is null) {
	_m_tr_h.remove(tr);

	tr.record(recorder);

	recorder.close(end_time);

	if (free_handle)
	  recorder.free();
      }

      uvm_event!uvm_object e = event_pool.get("end_tr");
      if ( e !is null) e.trigger();
    }
  }


  // Function- do_end_tr
  //
  // The <end_tr> method calls this function to accommodate any user-defined
  // post-end action. Implementations should call super.do_end_tr to ensure
  // correct operation.

  // @uvm-ieee 1800.2-2017 auto 13.1.6.6
  protected void do_end_tr(uvm_transaction tr,
			   int tr_handle) {
    return;
  }


  // Function- record_error_tr
  //
  // This function marks an error transaction by a component. Properties of the
  // given uvm_object, ~info~, as implemented in its <uvm_object::do_record> method,
  // are recorded to the transaction database.
  //
  // An ~error_time~ of 0 indicates to use the current simulation time. The
  // ~keep_active~ bit determines if the handle should remain active. If 0,
  // then a zero-length error transaction is recorded. A handle to the
  // database-transaction is returned.
  //
  // Interpretation of this handle, as well as the strings ~stream_name~,
  // ~label~, and ~desc~, are vendor-specific.

  // @uvm-ieee 1800.2-2017 auto 13.1.6.7
  final int record_error_tr (string stream_name = "main",
			     uvm_object info = null,
			     string label = "error_tr",
			     string desc = "",
			     SimTime error_time = 0,
			     bool keep_active = false) {
    synchronized (this) {

      uvm_tr_stream stream;

      string etype;
      if (keep_active) etype = "Error, Link";
      else etype = "Error";

      if (error_time == 0) error_time = get_root_entity.getSimTime();

      if (stream_name == "")
	stream_name = "main";
      stream = get_tr_stream(stream_name, "TVM");

      int handle = 0;
      if (stream !is null) {

	uvm_recorder recorder = stream.open_recorder(label,
						     error_time,
						     etype);

	if (recorder !is null) {
	  if (label != "") {
	    recorder.record_string("label", label);
	  }
	  if (desc != "") {
	    recorder.record_string("desc", desc);
	  }
	  if (info !is null) {
	    info.record(recorder);
	  }

	  recorder.close(error_time);

	  if (keep_active == 0) {
	    recorder.free();
	  }
	  else {
	    handle = recorder.get_handle();
	  }
	}
      }
      return handle;
    }
  }


  // Function- record_event_tr
  //
  // This function marks an event transaction by a component.
  //
  // An ~event_time~ of 0 indicates to use the current simulation time.
  //
  // A handle to the transaction is returned. The ~keep_active~ bit determines
  // if the handle may be used for other vendor-specific purposes.
  //
  // The strings for ~stream_name~, ~label~, and ~desc~ are vendor-specific
  // identifiers for the transaction.

  // @uvm-ieee 1800.2-2017 auto 13.1.6.8
  final int record_event_tr(string stream_name = "main",
			    uvm_object info = null,
			    string label = "event_tr",
			    string desc = "",
			    SimTime event_time = 0,
			    bool keep_active = false) {
    synchronized (this) {
      uvm_tr_stream stream;
      uvm_tr_database db = get_tr_database();

      string etype;
      if (keep_active) etype = "Event, Link";
      else etype = "Event";

      if (event_time == 0) {
	event_time = get_root_entity.getSimTime();
      }

      if (stream_name == "")
	stream_name = "main";
   
      stream = get_tr_stream(stream_name, "TVM");

      int handle = 0;
      if (stream !is null) {
	uvm_recorder recorder = stream.open_recorder(label,
						     event_time,
						     etype);

	if (recorder !is null) {
	  if (label != "") {
	    recorder.record_string("label", label);
	  }
	  if (desc != "") {
	    recorder.record_string("desc", desc);
	  }
	  if (info !is null) {
	    info.record(recorder);
	  }

	  recorder.close(event_time);

	  if (keep_active == 0) {
	    recorder.free();
	  }
	  else {
	    handle = recorder.get_handle();
	  }
	} // if (recorder != null)
      } // if (stream != null)

      return handle;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 13.1.6.9
  uvm_tr_stream get_tr_stream(string name,
			      string stream_type_name="") {
    synchronized (this) {
      uvm_tr_database db = get_tr_database();
      if (name !in _m_streams || stream_type_name !in _m_streams[name]) {
	_m_streams[name][stream_type_name] =
	  db.open_stream(name, this.get_full_name(), stream_type_name);
      }
      return _m_streams[name][stream_type_name];
    }
  }

  // @uvm-ieee 1800.2-2017 auto 13.1.6.10
  void free_tr_stream(uvm_tr_stream stream) {
    synchronized (this) {
      // Check the null case...
      if (stream is null) {
	return;
      }

      // Then make sure this name/type_name combo exists
      if (stream.get_name() !in _m_streams ||
	 stream.get_stream_type_name() !in _m_streams[stream.get_name()]) {
	return;
      }

      // Then make sure this name/type_name combo is THIS stream
      if (_m_streams[stream.get_name()][stream.get_stream_type_name()] !is stream) {
	return;
      }

      // Then delete it from the arrays
      _m_streams[stream.get_name()].remove(stream.get_type_name());
      if (_m_streams[stream.get_name()].length == 0) {
	_m_streams.remove(stream.get_name());
      }

      // Finally, free the stream if necessary
      if (stream.is_open() || stream.is_closed()) {
	stream.free();
      }
    }
  }

  // Variable -- NODOCS -- print_enabled
  //
  // This bit determines if this component should automatically be printed as a
  // child of its parent object.
  //
  // By default, all children are printed. However, this bit allows a parent
  // component to disable the printing of specific children.

  private bool _print_enabled = true;

  bool print_enabled() {
    synchronized (this) {
      return _print_enabled;
    }
  }

  void print_enabled(bool val) {
    synchronized (this) {
      _print_enabled = val;
    }
  }

  override void do_execute_op(uvm_field_op op) {
    synchronized (this) {
      if (op.get_op_type == uvm_field_auto_enum.UVM_PRINT) {
	// Handle children of the comp
	uvm_printer printer = cast(uvm_printer) op.get_policy();
	
	if (printer is null)
	  uvm_error("INVPRINTOP",
		    "do_execute_op() called with a field_op that has op_type UVM_PRINT but a policy that does not derive from uvm_printer");
	else {
	  foreach (cname, child_comp; _m_children) {
	    if (child_comp.print_enabled)
	      printer.print_object(cname, child_comp);
	  }
	}
      }
      super.do_execute_op(op);  
    }
  }

  // Variable -- NODOCS -- tr_database
  //
  // Specifies the <uvm_tr_database> object to use for <begin_tr>
  // and other methods in the <Recording Interface>.
  // Default is <uvm_coreservice_t::get_default_tr_database>.
  @uvm_private_sync
  private uvm_tr_database _tr_database;

  // @uvm-ieee 1800.2-2017 auto 13.1.6.12
  uvm_tr_database get_tr_database() {
    synchronized (this) {
      if (_tr_database is null) {
	uvm_coreservice_t cs = uvm_coreservice_t.get();
	_tr_database = cs.get_default_tr_database();
      }
      return _tr_database;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 13.1.6.11
  void set_tr_database(uvm_tr_database db) {
    synchronized (this) {
      _tr_database = db;
    }
  }

  //----------------------------------------------------------------------------
  //                     PRIVATE or PSUEDO-PRIVATE members
  //                      *** Do not call directly ***
  //         Implementation and even existence are subject to change.
  //----------------------------------------------------------------------------
  // Most local methods are prefixed with m_, indicating they are not
  // user-level methods. SystemVerilog does not support friend classes,
  // which forces some otherwise internal methods to be exposed (i.e. not
  // be protected via 'local' keyword). These methods are also prefixed
  // with m_ to indicate they are not intended for public use.
  //
  // Internal methods will not be documented, although their implementa-
  // tions are freely available via the open-source license.
  //----------------------------------------------------------------------------

  @uvm_protected_sync
  private uvm_domain _m_domain;    // set_domain stores our domain handle

  private uvm_phase[uvm_phase] _m_phase_imps;    // functors to override ovm_root defaults
  const(uvm_phase[uvm_phase]) m_phase_imps() {
    synchronized (this) {
      return _m_phase_imps.dup;
    }
  }
  

  //   //TND review protected, provide read-only accessor.
  @uvm_public_sync
  private uvm_phase _m_current_phase;            // the most recently executed phase
  @uvm_protected_sync
  private Process _m_phase_process;

  @uvm_public_sync
  private bool _m_build_done;

  @uvm_public_sync
  private int _m_phasing_active;

  void inc_phasing_active() {
    synchronized (this) {
      ++_m_phasing_active;
    }
  }
  void dec_phasing_active() {
    synchronized (this) {
      --_m_phasing_active;
    }
  }

  override void set_local(uvm_resource_base rsrc) {
    synchronized (this) {
      bool success;

  //set the local properties
      if ((rsrc !is null) && (rsrc.get_name() == "recording_detail")) {
	rsrc.uvm_resource_read(success,
			       _recording_detail,
			       this);
      }

      if (!success)
	super.set_local(rsrc);
  
    }
  }


  @uvm_protected_sync
  private uvm_component _m_parent;

  private uvm_component[string] _m_children;

  const(uvm_component[string]) m_children() {
    synchronized (this) {
      return _m_children.dup;
    }
  }
  
  private uvm_component[uvm_component] _m_children_by_handle;

  const(uvm_component[uvm_component]) m_children_by_handle() {
    synchronized (this) {
      return _m_children_by_handle.dup;
    }
  }
  
  

  protected bool m_add_child(uvm_component child) {
    import std.string: format;
    synchronized (this) {
      string name = child.get_name();
      if (name in _m_children && _m_children[name] !is child) {
	uvm_warning("BDCLD",
		    format ("A child with the name '%0s' (type=%0s)" ~
			    " already exists.",
			    name, (cast (uvm_component) _m_children[name]).get_type_name()));
	return false;
      }

      if (child in _m_children_by_handle) {
	uvm_warning("BDCHLD",
		    format("A child with the name '%0s' %0s %0s'",
			   name, "already exists in parent under name '",
			   (cast (uvm_component) _m_children_by_handle[child]).get_name()));
	return false;
      }

      (cast (uvm_component[string]) _m_children)[name] = child;
      (cast (uvm_component[uvm_component]) _m_children_by_handle)[child] = child;
      return true;
    }
  }

  // Allow association of non-simulation threads with a uvm_root
  void set_thread_context() {
    auto top = this.get_root();
    top.set_thread_context();
  }

  // m_set_full_name
  // ---------------

  private void m_set_full_name() {
    synchronized (this) {
      uvm_root top = cast (uvm_root) _m_parent;
      if (top !is null || _m_parent is null) {
	_m_name = get_name();
      }
      else {
	_m_name = _m_parent.get_full_name() ~ "." ~ get_name();
      }
      foreach (c; m_children) {
	(cast (uvm_component) c).m_set_full_name();
      }
    }
  }

  // do_resolve_bindings
  // -------------------

  final void do_resolve_bindings() {
    foreach (c; m_children) {
      (cast (uvm_component) c).do_resolve_bindings();
    }
    resolve_bindings();
  }

  // do_flush  (flush_hier?)
  // --------

  final void do_flush() {
    foreach (c; m_children) {
      (cast (uvm_component) c).do_flush();
    }
    flush();
  }

  // flush
  // -----

  void flush() {
    return;
  }



  // m_extract_name
  // --------------

  private void m_extract_name(string name,
			      out string leaf,
			      out string remainder) {
    auto i = countUntil(name, '.');

    if (i is -1) {
      leaf = name;
      remainder = "";
      return;
    }
    else {
      leaf = name[0..i];
      remainder = name[i+1..$];	// skip '.'
      return;
    }
  }

  //------------------------------------------------------------------------------
  //
  // Factory Methods
  //
  //------------------------------------------------------------------------------


  // overridden to disable

  // create
  // ------

  // FIXME -- use @disable feature from D -- make it compile time error
  override uvm_object create (string name = "") {
    uvm_error("ILLCRT",
	      "create cannot be called on a uvm_component." ~
	      " Use create_component instead.");
    return null;
  }


  // clone
  // ------

  override uvm_object clone() {
    uvm_error("ILLCLN",
	      format("Attempting to clone '%s'." ~
		     "  Clone cannot be called on a uvm_component." ~
		     "  The clone target variable will be set to null.",
		     get_full_name()));
    return null;
  }

  private uvm_tr_stream[string][string] _m_streams;
  private uvm_recorder[uvm_transaction] _m_tr_h;

  // m_begin_tr
  // ----------
  protected int m_begin_tr (uvm_transaction tr,
			    int parent_handle=0,
			    string stream_name="main", string label="",
			    string desc="", SimTime begin_time=0) {
    import uvm.seq.uvm_sequence_item;
    import uvm.seq.uvm_sequence_base;
    import uvm.base.uvm_links;
    synchronized (this) {

      uvm_event!uvm_object e;
      string    name;
      string    kind;
      int   handle, link_handle;
      uvm_tr_stream stream;
      uvm_recorder recorder, parent_recorder, link_recorder;

      if (tr is null)
	return 0;

      uvm_tr_database db = get_tr_database();

      if (parent_handle != 0) {
	parent_recorder = uvm_recorder.get_recorder_from_handle(parent_handle);
	if (parent_recorder is null)
	  uvm_error("ILLHNDL",
		    "begin_tr was passed a non-0 parent handle that corresponds to a null recorder");
      }
      else {
	uvm_sequence_item seq = cast (uvm_sequence_item) tr;
	if (seq !is null) {
	  uvm_sequence_base parent_seq = seq.get_parent_sequence();
	  if (parent_seq !is null) {
	    parent_recorder = parent_seq.m_tr_recorder;
	  }
	}
      }

      if (parent_recorder !is null) {
	version (UVM_1800_2_2020_EA) {
	  link_handle = tr.begin_tr(begin_time, parent_recorder.get_handle());
	}
	else {
	  link_handle = tr.begin_child_tr(begin_time, parent_recorder.get_handle());
	}
      }
      else {
	link_handle = tr.begin_tr(begin_time);
      }

      if (link_handle != 0) {
	link_recorder = uvm_recorder.get_recorder_from_handle(link_handle);
      }


      if (tr.get_name() != "")
	name = tr.get_name();
      else
	name = tr.get_type_name();

      if (stream_name == "") stream_name = "main";

      if ((cast (uvm_verbosity) _recording_detail) != uvm_verbosity.UVM_NONE) {
	stream = get_tr_stream(stream_name, "TVM");

	if (stream !is null ) {
	  kind = (parent_recorder is null) ? "Begin_No_Parent, Link" : "Begin_End, Link";

	  recorder = stream.open_recorder(name, begin_time, kind);

	  if (recorder !is null) {
	    if (label != "")
	      recorder.record_string("label", label);
	    if (desc != "")
	      recorder.record_string("desc", desc);

	    if (parent_recorder !is null) {
	      tr_database.establish_link(uvm_parent_child_link.get_link(parent_recorder,
									recorder));
	    }

	    if (link_recorder !is null) {
	      tr_database.establish_link(uvm_related_link.get_link(recorder,
								   link_recorder));
	    }
	    _m_tr_h[tr] = recorder;
	  }
	}

	handle = (recorder is null) ? 0 : recorder.get_handle();
      }

      do_begin_tr(tr, stream_name, handle);

      e = event_pool.get("begin_tr");
      if (e !is null)
	e.trigger(tr);

      return handle;

    }
  }

  private string _m_name;

  alias type_id = 
    uvm_abstract_component_registry!(uvm_component);

  static string type_name() {
    return "uvm_component";
  }

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }


  // Vlang specific -- useful for parallelism
  @uvm_private_sync
  private int _m_comp_id = -1; // set in the auto_build_phase

  int get_id() {
    synchronized (this) {
      return _m_comp_id;
    }
  }

  void _set_id() {
    synchronized (this) {
      uint id;
      if (m_comp_id == -1) {
	synchronized (_uvm_scope_inst) {
	  id = _uvm_scope_inst._m_comp_count++;
	}
	debug(UVM_AUTO) {
	  import std.stdio;
	  writeln("Auto Number ", get_full_name, ": ", id);
	}
	m_comp_id = id;
      }
    }
  }

  void _uvm__configure_parallelism(MulticoreConfig config) { // to be called only by a uvm_root
    import uvm.base.uvm_root;
    assert (cast (uvm_root) this);
    _set_id();
    assert (config !is null);
    if (config._threadIndex == uint.max) {
      config._threadIndex =
	_esdl__parComponentId() % config._threadPool.length;
    }
    assert (_esdl__multicoreConfig is null);
    _esdl__multicoreConfig = config;
    _uvm__parallelize_done = true;
  }

  @uvm_immutable_sync
  private uvm_event_pool _event_pool;

  private uint _recording_detail = uvm_verbosity.UVM_NONE;

  override void do_print(uvm_printer printer) {
    synchronized (this) {
      string v;
      super.do_print(printer);

      // It is printed only if its value is other than the default (UVM_NONE)
      if (cast (uvm_verbosity) _recording_detail !is uvm_verbosity.UVM_NONE)
	switch (_recording_detail) {
	case uvm_verbosity.UVM_LOW:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_LOW");
	  break;
	case uvm_verbosity.UVM_MEDIUM:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_MEDIUM");
	  break;
	case uvm_verbosity.UVM_HIGH:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_HIGH");
	  break;
	case uvm_verbosity.UVM_FULL:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_FULL");
	  break;
	default:
	  printer.print("recording_detail", _recording_detail, uvm_radix_enum.UVM_DEC, '.', "integral");
	  break;
	}
    }
  }


  // Internal methods for setting up command line messaging stuff

  final void m_set_cl_msg_args() {
    // string s_;
    // process p_;
	
    // p_=Process.self();
    // if (p_ !is null) 
    //   s_=p_.get_randstate();
    // else
    //   uvm_warning("UVM","run_test() invoked from a non process context");
    
    m_set_cl_verb();
    m_set_cl_action();
    m_set_cl_sev();

    // if (p_ !is null) 
    //   p_.set_randstate(s_);

  }


  private void add_time_setting(m_verbosity_setting setting) {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m_time_settings ~= setting;
    }
  }

  private const(m_verbosity_setting[]) sort_time_settings() {
    synchronized (_uvm_scope_inst) {
      if (_uvm_scope_inst._m_time_settings.length > 0) {
	// m_time_settings.sort() with ( item.offset );
	sort!((m_verbosity_setting a, m_verbosity_setting b)
	      {return a.offset < b.offset;})(_uvm_scope_inst._m_time_settings);
      }
      return _uvm_scope_inst._m_time_settings.dup;
    }
  }

  // m_set_cl_verb
  // -------------
  final void m_set_cl_verb() {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_root;
    import uvm.base.uvm_cmdline_processor;
    import uvm.base.uvm_globals;
    synchronized (this) {
      // _ALL_ can be used for ids
      // +uvm_set_verbosity=<comp>,<id>,<verbosity>,<phase|time>,<offset>
      // +uvm_set_verbosity=uvm_test_top.env0.agent1.*,_ALL_,UVM_FULL,time,800

      static string[] values;
      static bool first = true;
      string[] args;
      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root top = cs.get_root();

      if (first) {
	string[] t;
	m_verbosity_setting setting;
	clp.get_arg_values("+uvm_set_verbosity=", values);
	foreach (i, value; values) {
	  args.length = 0;
	  uvm_split_string(value, ',', args);
	  if (((args.length == 4) || (args.length == 5)) &&
	     (clp.m_convert_verb(args[2], setting.verbosity) == 1))
	    t ~= value;
	  else
	    uvm_report_warning("UVM/CMDLINE",
			       format("argument %s not recognized and therefore dropped", value));
	}
      
	values = t;
	first = false;
      }

      foreach (i, value; values) {
	m_verbosity_setting setting;
	uvm_split_string(value, ',', args);

	setting.comp = args[0];
	setting.id = args[1];
	clp.m_convert_verb(args[2],setting.verbosity);
	setting.phase = args[3];
	setting.offset = 0;
	if (args.length == 5) setting.offset = args[4].to!int;
	if ((setting.phase == "time") && (this is top)) {
	  add_time_setting(setting);
	}

	if (uvm_is_match(setting.comp, get_full_name()) ) {
	  if ((setting.phase == "" || setting.phase == "build" || setting.phase == "time") &&
	     (setting.offset == 0))
	    {
	      if (setting.id == "_ALL_")
		set_report_verbosity_level(setting.verbosity);
	      else
		set_report_id_verbosity(setting.id, setting.verbosity);
	    }
	  else {
	    if (setting.phase != "time") {
	      _m_verbosity_settings.pushBack(setting);
	    }
	  }
	}
      }
      // do time based settings
      if (this is top) {
	fork!("uvm_component/do_time_based_settings")({
	    SimTime last_time = 0;
	    auto time_settings = sort_time_settings();
	    foreach (i, setting; time_settings) {
	      uvm_component[] comps;
	      top.find_all(setting.comp, comps);
	      wait((cast (SimTime) setting.offset) - last_time);
	      // synchronized (this) {
	      last_time = setting.offset;
	      if (setting.id == "_ALL_") {
		foreach (comp; comps) {
		  comp.set_report_verbosity_level(setting.verbosity);
		}
	      }
	      else {
		foreach (comp; comps) {
		  comp.set_report_id_verbosity(setting.id, setting.verbosity);
		}
	      }
	      // }
	    }
	  });
      }
    }
  }


  final void m_set_cl_action() {
    // _ALL_ can be used for ids or severities
    // +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>
    // +uvm_set_action=uvm_test_top.env0.*,_ALL_,UVM_ERROR,UVM_NO_ACTION
    import uvm.base.uvm_cmdline_processor;
    import uvm.base.uvm_globals;
    synchronized (this) {
      uvm_severity sev;
      uvm_action action;

      uvm_cmdline_processor uvm_cmdline_proc =
	uvm_cmdline_processor.get_inst();
  
      if (! cl_action_initialized) {
	string[] values;
	uvm_cmdline_proc.get_arg_values("+uvm_set_action=", values);
	foreach (idx, value; values) {
	  string[] args;
	  uvm_split_string(value, ',', args);

	  if (args.length !is 4) {
	    uvm_warning("INVLCMDARGS",
			format("+uvm_set_action requires 4 arguments, only %0d given for command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			       args.length, value));
	    continue;
	  }
	  if ((args[2] != "_ALL_") && !uvm_string_to_severity(args[2], sev)) {
	    uvm_warning("INVLCMDARGS",
			format("Bad severity argument \"%s\" given to command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			       args[2], value));
	    continue;
	  }
	  if (!uvm_string_to_action(args[3], action)) {
	    uvm_warning("INVLCMDARGS",
			format("Bad action argument \"%s\" given to command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			       args[3], value));
	    continue;
	  }
	  uvm_cmdline_parsed_arg_t t;
	  t.args = args;
	  t.arg = value;
	  _uvm_scope_inst.add_m_uvm_applied_cl_action(t);
	}
	cl_action_initialized = true;
      }

      synchronized (_uvm_scope_inst) {
	foreach (i, ref cl_action; _uvm_scope_inst._m_uvm_applied_cl_action) {
	  string[] args = cl_action.args;

	  if (!uvm_is_match(args[0], get_full_name()) ) {
	    continue;
	  }

	  uvm_string_to_severity(args[2], sev);
	  uvm_string_to_action(args[3], action);

	  synchronized (_uvm_scope_inst) {
	    cl_action.used++;
	  }

	  if (args[1] == "_ALL_") {
	    if (args[2] == "_ALL_") {
	      set_report_severity_action(uvm_severity.UVM_INFO, action);
	      set_report_severity_action(uvm_severity.UVM_WARNING, action);
	      set_report_severity_action(uvm_severity.UVM_ERROR, action);
	      set_report_severity_action(uvm_severity.UVM_FATAL, action);
	    }
	    else {
	      set_report_severity_action(sev, action);
	    }
	  }
	  else {
	    if (args[2] == "_ALL_") {
	      set_report_id_action(args[1], action);
	    }
	    else {
	      set_report_severity_id_action(sev, args[1], action);
	    }
	  }
	}
      }
    }
  }


  // m_set_cl_sev
  // ------------

  final void m_set_cl_sev() {
    // _ALL_ can be used for ids or severities
    //  +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>
    //  +uvm_set_severity=uvm_test_top.env0.*,BAD_CRC,UVM_ERROR,UVM_WARNING
    import uvm.base.uvm_cmdline_processor;
    import uvm.base.uvm_globals;
    synchronized (this) {
      uvm_severity orig_sev;
      uvm_severity sev;

      uvm_cmdline_processor uvm_cmdline_proc =
	uvm_cmdline_processor.get_inst();

      if (! cl_sev_initialized) {
	string[] values;
	uvm_cmdline_proc.get_arg_values("+uvm_set_severity=", values);

	foreach (idx, value; values) {
	  string[] args;
	  uvm_split_string(value, ',', args);
	  if (args.length !is 4) {
	    uvm_warning("INVLCMDARGS", format("+uvm_set_severity requires 4 arguments, only %0d given for command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args.length, value));
	    continue;
	  }
	  if (args[2] != "_ALL_" && !uvm_string_to_severity(args[2], orig_sev)) {
	    uvm_warning("INVLCMDARGS", format("Bad severity argument \"%s\" given to command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args[2], value));
	    continue;
	  }
	  if (!uvm_string_to_severity(args[3], sev)) {
	    uvm_warning("INVLCMDARGS", format("Bad severity argument \"%s\" given to command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args[3], value));
	    continue;
	  }
	  uvm_cmdline_parsed_arg_t t;
	  t.args = args;
	  t.arg = value;
	  _uvm_scope_inst.add_m_uvm_applied_cl_sev(t);
	}
	cl_sev_initialized = true;
      }
      synchronized (_uvm_scope_inst) {
	foreach (i, ref cl_sev; _uvm_scope_inst._m_uvm_applied_cl_sev) {
	  string[] args = cl_sev.args;

	  if (!uvm_is_match(args[0], get_full_name())) {
	    continue;
	  }

	  uvm_string_to_severity(args[2], orig_sev);
	  uvm_string_to_severity(args[3], sev);
	  synchronized (_uvm_scope_inst) {
	    cl_sev.used++;
	  }

	  if (args[1] == "_ALL_" && args[2] == "_ALL_") {
	    set_report_severity_override(uvm_severity.UVM_INFO,sev);
	    set_report_severity_override(uvm_severity.UVM_WARNING,sev);
	    set_report_severity_override(uvm_severity.UVM_ERROR,sev);
	    set_report_severity_override(uvm_severity.UVM_FATAL,sev);
	  }
	  else if (args[1] == "_ALL_") {
	    set_report_severity_override(orig_sev,sev);
	  }
	  else if (args[2] == "_ALL_") {
	    set_report_severity_id_override(uvm_severity.UVM_INFO,args[1],sev);
	    set_report_severity_id_override(uvm_severity.UVM_WARNING,args[1],sev);
	    set_report_severity_id_override(uvm_severity.UVM_ERROR,args[1],sev);
	    set_report_severity_id_override(uvm_severity.UVM_FATAL,args[1],sev);
	  }
	  else {
	    set_report_severity_id_override(orig_sev,args[1],sev);
	  }
	}
      }
    }
  }

  // m_apply_verbosity_settings
  // --------------------------

  final void m_apply_verbosity_settings(uvm_phase phase) {
    synchronized (this) {
      int i;
      while (i < _m_verbosity_settings.length) {
	auto setting = _m_verbosity_settings[i];
	if (phase.get_name() == setting.phase) {
	  if (setting.offset == 0) {
	    if (setting.id == "_ALL_") {
	      set_report_verbosity_level(setting.verbosity);
	    }
	    else {
	      set_report_id_verbosity(setting.id, setting.verbosity);
	    }
	  }
	  else {

	    version (PRESERVE_RANDSTATE) {
	      Process p = Process.self;
	      Random p_rand;
	      p.getRandState(p_rand);
	    }

	    fork!("uvm_component/apply_verbosity_settings")({
		wait(setting.offset);
		// synchronized (this) {
		if (setting.id == "_ALL_")
		  set_report_verbosity_level(setting.verbosity);
		else
		  set_report_id_verbosity(setting.id, setting.verbosity);
		// }
	      });

	    version (PRESERVE_RANDSTATE) {
	      p.setRandState(p_rand);
	    }
	  }
	  // Remove after use
	  _m_verbosity_settings.remove(i);
	  continue;
	}
	i += 1;
      }
    }
  }

  // The verbosity settings may have a specific phase to start at.
  // We will do this work in the phase_started callback.

  private Queue!m_verbosity_setting _m_verbosity_settings;

  //   // does the pre abort callback hierarchically

  final void m_do_pre_abort() {
    foreach (child; get_children) {
      uvm_component child_ = cast (uvm_component) child;
      if (child_ !is null) {
	child_.m_do_pre_abort();
      }
    }
    pre_abort();
  }


  // produce message for unsupported types from apply_config_settings
  uvm_resource_base _m_unsupported_resource_base = null;

  override void m_unsupported_set_local(uvm_resource_base rsrc) {
    synchronized (this) {
      _m_unsupported_resource_base = rsrc;
    }
  }

  struct uvm_cmdline_parsed_arg_t {
    string arg;
    string[] args;
    uint used;
  }

  void set_simulation_status(ubyte status) {
    get_root_entity.setExitStatus(status);
  }

  void m_uvm_component_automation(int what) { }

  static void _m_uvm_component_automation(E, P)(ref E e,
						int what,
						string name,
						int flags,
						_esdl__Multicore pflags,
						P parent)
    if (isArray!E && !is (E == string)) {
      switch (what) {
      case uvm_field_xtra_enum.UVM_PARALLELIZE:
	for (size_t i=0; i!=e.length; ++i) {
	  _m_uvm_component_automation(e[i], what,
				      name ~ format("[%d]", i),
				      flags, pflags, parent);
	}
	break;
      case uvm_field_auto_enum.UVM_BUILD:
	for (size_t i=0; i!=e.length; ++i) {
	  _m_uvm_component_automation(e[i], what,
				      name ~ format("[%d]", i),
				      flags, pflags, parent);
	}
	break;
      default:
	uvm.base.uvm_globals.uvm_error("UVMUTLS",
				       format("UVM UTILS uknown utils " ~
					      "functionality: %s/%s",
					      cast (uvm_field_auto_enum) what,
					      cast (uvm_field_xtra_enum) what));
	break;
      }
    }
  
  static void _m_uvm_component_automation(E)(ref E e,
					     int what,
					     string name,
					     int flags,
					     _esdl__Multicore pflags,
					     uvm_component parent)
    if (is (E: uvm_component)) {
      import uvm.base.uvm_globals;
      switch (what) {
      case uvm_field_xtra_enum.UVM_PARALLELIZE:
	static if (is (E: uvm_component)) {
	  if (e !is null) {
	    e._set_id();
	    uvm__config_parallelism(e, pflags);
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_BUILD:
        if (! (flags & uvm_field_auto_enum.UVM_NOBUILD) && flags & uvm_field_auto_enum.UVM_BUILD) {
	  if (e is null) {
	    e = E.type_id.create(name, parent);
	  }
	}
	break;
      default:
	uvm.base.uvm_globals.uvm_error("UVMUTLS",
				       format("UVM UTILS uknown utils" ~
					      " functionality: %s/%s",
					      cast (uvm_field_auto_enum) what,
					      cast (uvm_field_xtra_enum) what));
	break;
	  
      }
    }

  static void _m_uvm_component_automation(E, P)(ref E e,
						int what,
						string name,
						int flags,
						_esdl__Multicore pflags,
						P parent)
  if (is (E: uvm_port_base!IF, IF)) {
    import uvm.base.uvm_port_base;

      switch (what) {
      case uvm_field_auto_enum.UVM_BUILD:
        if (! (flags & uvm_field_auto_enum.UVM_NOBUILD) && flags & uvm_field_auto_enum.UVM_BUILD) {
	  static if (is (E: uvm_port_base!IF, IF)) {
	    e = new E(name, parent);
	  }
	}
	break;
      default:
	break;
      }
    }

  static void _m_uvm_component_automation(int I, T)(T          t,
						    int        what)
    if (is (T: uvm_component)) {
      static if (I < t.tupleof.length) {
	import uvm.comps.uvm_agent;
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	alias EE = UVM_ELEMENT_TYPE!(typeof(t.tupleof[I]));
	static if ((is (EE: uvm_component) ||
		    is (EE: uvm_port_base!IF, IF)) &&
		   FLAGS != 0) {
	  _esdl__Multicore pflags;
	  if (what == uvm_field_auto_enum.UVM_BUILD) {
	    bool is_active = true; // if not uvm_agent, everything is active
	    static if (is (T: uvm_agent)) {
	      is_active = t.get_is_active();
	    }
	    bool active_flag =
	      UVM_IN_TUPLE!(0, uvm_active_passive_enum.UVM_ACTIVE, __traits(getAttributes, t.tupleof[I]));
	    if (! active_flag || is_active) {
	      _m_uvm_component_automation(t.tupleof[I], what,
					  t.tupleof[I].stringof[2..$],
					  FLAGS, pflags, t);
	    }
	  }
	  else if (what == uvm_field_xtra_enum.UVM_PARALLELIZE) {
	    pflags = _esdl__uda!(_esdl__Multicore, T, I);
	    _m_uvm_component_automation(t.tupleof[I], what,
					t.tupleof[I].stringof[2..$],
					FLAGS, pflags, null);
	  }
	}
	_m_uvm_component_automation!(I+1)(t, what);
      }
    }
}

// Undocumented struct for storing clone bit along w/
// object on set_config_object(...) calls
private class uvm_config_object_wrapper
{
  // pragma(msg, uvm_sync!uvm_config_object_wrapper);
  mixin (uvm_sync_string);
  @uvm_private_sync private uvm_object _obj;
  @uvm_private_sync private bool _clone;
}

////////////////////////////////////////////////////////////////
// Auto Build Functions

template UVM__IS_MEMBER_COMPONENT(L)
{
  static if (is (L == class) && is (L: uvm_component)) {
    enum bool UVM__IS_MEMBER_COMPONENT = true;
  }
  else static if (isArray!L) {
    import std.range: ElementType;
    enum bool UVM__IS_MEMBER_COMPONENT =
      UVM__IS_MEMBER_COMPONENT!(ElementType!L);
  }
  else {
    enum bool UVM__IS_MEMBER_COMPONENT = false;
  }
}

// template UVM__IS_MEMBER_BASE_PORT(L)
// {
//   static if (is (L == class) && is (L: uvm_port_base!IF, IF)) {
//     enum bool UVM__IS_MEMBER_BASE_PORT = true;
//   }
//   else static if (isArray!L) {
//     import std.range: ElementType;
//     enum bool UVM__IS_MEMBER_BASE_PORT =
//       UVM__IS_MEMBER_BASE_PORT!(ElementType!L);
//   }
//   else {
//     enum bool UVM__IS_MEMBER_BASE_PORT = false;
//   }
// }

// void uvm__auto_build(size_t I, T, N...)(T t)
//   if (is (T : uvm_component) && is (T == class)) {
//     // pragma(msg, N);
//     static if (I < t.tupleof.length) {
//       alias M=typeof(t.tupleof[I]);
//       static if (UVM__IS_MEMBER_COMPONENT!M || UVM__IS_MEMBER_BASE_PORT!M) {
// 	uvm__auto_build!(I+1, T, N, I)(t);
//       }
//       else {
// 	uvm__auto_build!(I+1, T, N)(t);
//       }
//     }
//     else {
//       // first build these
//       static if (N.length > 0) {
// 	alias U = typeof(t.tupleof[N[0]]);
// 	uvm__auto_build!(T, U, N)(t, t.tupleof[N[0]]);
//       }
//       else static if (is (T: uvm_root)) {
// 	if (t.m_children.length is 0) {
// 	  uvm_report_fatal("NOCOMP",
// 			   "No components instantiated. You must either "
// 			   "instantiate at least one component before "
// 			   "calling run_test or use run_test to do so. "
// 			   "To run a test using run_test, use +UVM_TESTNAME "
// 			   "or supply the test name in the argument to "
// 			   "run_test(). Exiting simulation.", uvm_verbosity.UVM_NONE);
// 	  return;
// 	}
//       }
//       // then go over the base object
//       static if (is (T B == super)
// 		&& is (B[0]: uvm_component)
// 		&& is (B[0] == class)
// 		&& (! is (B[0] == uvm_component))
// 		&& (! is (B[0] == uvm_root))) {
// 	B[0] b = t;
// 	uvm__auto_build!(0, B)(b);
//       }
//       // and finally iterate over the children
//       // static if (N.length > 0) {
//       //	uvm__auto_build_iterate!(T, U, N)(t, t.tupleof[N[0]], []);
//       // }
//     }
//   }

// void uvm__auto_build(T, U, size_t I, N...)(T t, ref U u,
// 					    uint[] indices = []) {
//   enum bool isActiveAttr =
//     findUvmAttr!(0, uvm_active_passive_enum.UVM_ACTIVE, __traits(getAttributes, t.tupleof[I]));
//   enum bool noAutoAttr =
//     findUvmAttr!(0, UVM_NO_AUTO, __traits(getAttributes, t.tupleof[I]));
//   enum bool isAbstract = isAbstractClass!U;

//   // the top level we start with should also get an id
//   t._set_id();

//   bool is_active = true;
//   static if (is (T: uvm_agent)) {
//     is_active = t.is_active;
//   }
//   static if (isArray!U) {
//     for (size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_build!(T, E, I)(t, u[j], indices ~ cast (uint) j);
//     }
//   }
//   else {
//     string name = __traits(identifier, T.tupleof[I]);
//     foreach (i; indices) {
//       name ~= "[" ~ i.to!string ~ "]";
//     }
//     static if ((! isAbstract) &&  // class is abstract
// 	      (! noAutoAttr)) {
//       if (u is null &&  // make sure that UVM_NO_AUTO is not present
// 	 (is_active ||	  // build everything if the agent is active
// 	  (! isActiveAttr))) { // build the element if not and active element
// 	static if (is (U: uvm_component)) {
// 	  import std.stdio;
// 	  writeln("Making ", name);
// 	  u = U.type_id.create(name, t);
// 	}
// 	else if (is (U: uvm_port_base!IF, IF)) {
// 	  import std.stdio;
// 	  writeln("Making ", name);
// 	  u = new U(name, t);
// 	}
// 	// else {
// 	//   static assert (false, "Support only for uvm_component and uvm_port_base");
// 	// }
//       }
//     }
//     // provide an ID to all the components that are not null
//     if (u !is null) {
//       static if (is (U: uvm_component)) {
// 	u._set_id();
//       }
//     }
//   }
//   static if (N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_build!(T, V, N)(t, t.tupleof[J], []);
//   }
// }

// void uvm__auto_build_iterate(T, U, size_t I, N...)(T t, ref U u,
//						    uint indices[]) {
//   static if (isArray!U) {
//     for (size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_build_iterate!(T, E, I)(t, u[j], indices ~ cast (uint) j);
//     }
//   }
//   else {
//     if (u !is null &&
//        (! u.uvm__auto_build_done)) {
//       u.uvm__auto_build_done(true);
//       u.uvm__auto_build();
//     }
//   }
//   static if (N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_build_iterate!(T, V, N)(t, t.tupleof[J]);
//   }
// }

// void uvm__auto_elab(size_t I=0, T, N...)(T t)
//   if (is (T : uvm_component) && is (T == class)) {
//     // pragma(msg, N);
//     static if (I < t.tupleof.length) {
//       alias M=typeof(t.tupleof[I]);
//       static if (UVM__IS_MEMBER_COMPONENT!M) {
// 	uvm__auto_elab!(I+1, T, N, I)(t);
//       }
//       else {
// 	uvm__auto_elab!(I+1, T, N)(t);
//       }
//     }
//     else {
//       // first elab these
//       static if (N.length > 0) {
// 	alias U = typeof(t.tupleof[N[0]]);
// 	uvm__auto_elab!(T, U, N)(t, t.tupleof[N[0]]);
//       }
//       // then go over the base object
//       static if (is (T B == super)
// 		&& is (B[0]: uvm_component)
// 		&& is (B[0] == class)
// 		&& (! is (B[0] == uvm_component))
// 		&& (! is (B[0] == uvm_root))) {
// 	B[0] b = t;
// 	uvm__auto_elab!(0, B[0])(b);
//       }
//       // and finally iterate over the children
//       static if (N.length > 0) {
// 	uvm__auto_elab_iterate!(T, U, N)(t, t.tupleof[N[0]]);
//       }
//     }
//   }

// void uvm__auto_elab_iterate(T, U, size_t I, N...)(T t, ref U u,
// 						   uint[] indices = []) {
//   static if (isArray!U) {
//     for (size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_elab_iterate!(T, E, I)(t, u[j], indices ~ cast (uint) j);
//     }
//   }
//   else {
//     if (u !is null &&
//        (! u.uvm__parallelize_done)) {
//       u.uvm__parallelize_done(true);
//       u.uvm__auto_elab();
//     }
//   }
//   static if (N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_elab_iterate!(T, V, N)(t, t.tupleof[J]);
//   }
// }

// void uvm__auto_elab(T, U, size_t I, N...)(T t, ref U u,
// 					  uint[] indices = []) {

//   // the top level we start with should also get an id
//   t._set_id();
//   static if (isArray!U) {
//     for (size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_elab!(T, E, I)(t, u[j], indices ~ cast (uint) j);
//     }
//   }
//   else {
//     // string name = __traits(identifier, T.tupleof[I]);
//     // foreach (i; indices) {
//     //   name ~= "[" ~ i.to!string ~ "]";
//     // }
//     // provide an ID to all the components that are not null
//     auto linfo = _esdl__get_parallelism!(I, T)(t);
//     if (u !is null) {
//       uvm__config_parallelism(u, linfo);
//       u._set_id();
//     }
//   }
//   static if (N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_elab!(T, V, N)(t, t.tupleof[J]);
//   }
// }

void uvm__config_parallelism(T)(T t, ref _esdl__Multicore linfo)
  if (is (T : uvm_component) && is (T == class)) {
    assert (t !is null);
    if (! t.uvm__parallelize_done) {
      // if not defined for instance try getting information for class
      // attributes
      if (linfo.isUndefined) {
	linfo = _esdl__uda!(_esdl__Multicore, T);
      }

      auto parent = t.get_parent();
      MulticoreConfig pconf;
      
      if (parent is null || parent is t) { // this is uvm_root
	pconf = Process.self().getParentEntity()._esdl__getMulticoreConfig();
	assert (pconf !is null);
      }
      else {
	pconf = t.get_parent._esdl__getMulticoreConfig;
	assert (pconf !is null,
		t.get_name() ~ " failed to get multicore config from parent " ~
		t.get_parent.get_name() ~ "(" ~ t.get_parent.get_type_name() ~ ")");
      }
	
      assert (t._esdl__getMulticoreConfig is null);
      
      auto config = linfo.makeCfg(pconf);
      
      if (config._threadIndex == uint.max) {
	config._threadIndex =
	  t._esdl__parComponentId() % config._threadPool.length;
      }
      // import std.stdio;
      // writeln("setting multicore  for ", t.get_full_name());
      t._esdl__multicoreConfig = config;
    }
    t.uvm__parallelize_done = true;
  }



// private template findUvmAttr(size_t I, alias S, A...) {
//   static if (I < A.length) {
//     static if (is (typeof(A[I]) == typeof(S)) && A[I] == S) {
//       enum bool findUvmAttr = true;
//     }
//     else {
//       enum bool findUvmAttr = findUvmAttr!(I+1, S, A);
//     }
//   }
//   else {
//     enum bool findUvmAttr = false;
//   }
// }

alias UVM_PARALLEL = _esdl__Multicore;
