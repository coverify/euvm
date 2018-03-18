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

module uvm.base.uvm_component;
// typedef class uvm_objection;
// typedef class uvm_sequence_base;
// typedef class uvm_sequence_item;

import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_objection;
import uvm.base.uvm_phase;
import uvm.base.uvm_domain;
import uvm.base.uvm_pool;
import uvm.base.uvm_common_phases;
import uvm.base.uvm_config_db;
import uvm.base.uvm_spell_chkr;
import uvm.base.uvm_cmdline_processor;
// import uvm.base.uvm_globals;
import uvm.base.uvm_config_db;
import uvm.base.uvm_factory;
import uvm.base.uvm_printer;
import uvm.base.uvm_recorder;
import uvm.base.uvm_transaction;
import uvm.base.uvm_resource;
import uvm.base.uvm_queue;
import uvm.base.uvm_event;
import uvm.base.uvm_misc: UVM_ELEMENT_TYPE, UVM_IN_TUPLE;
import uvm.base.uvm_links;
import uvm.base.uvm_port_base;
import uvm.base.uvm_tr_stream;
import uvm.base.uvm_tr_database;
import uvm.comps.uvm_agent;
import uvm.base.uvm_entity;
import uvm.base.uvm_once;

import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequence_base;
import uvm.meta.meta;		// qualifiedTypeName
import uvm.meta.misc;		// qualifiedTypeName
import uvm.base.uvm_globals: uvm_is_match;
import uvm.base.uvm_report_object;

import esdl.base.core;
import esdl.data.queue;

import std.traits: isIntegral, isAbstractClass, isArray;

import std.string: format;
import std.conv: to;
import std.random: Random;

import std.algorithm;
import std.exception: enforce;



//------------------------------------------------------------------------------
//
// CLASS: uvm_component
//
// The uvm_component class is the root base class for UVM components. In
// addition to the features inherited from <uvm_object> and <uvm_report_object>,
// uvm_component provides the following interfaces:
//
// Hierarchy - provides methods for searching and traversing the component
//     hierarchy.
//
// Phasing - defines a phased test flow that all components follow, with a
//     group of standard phase methods and an API for custom phases and
//     multiple independent phasing domains to mirror DUT behavior e.g. power
//
// Reporting - provides a convenience interface to the <uvm_report_handler>. All
//     messages, warnings, and errors are processed through this interface.
//
// Transaction recording - provides methods for recording the transactions
//     produced or consumed by the component to a transaction database (vendor
//     specific).
//
// Factory - provides a convenience interface to the <uvm_factory>. The factory
//     is used to create new components and other objects based on type-wide and
//     instance-specific configuration.
//
// The uvm_component is automatically seeded during construction using UVM
// seeding, if enabled. All other objects must be manually reseeded, if
// appropriate. See <uvm_object::reseed> for more information.
//
//------------------------------------------------------------------------------

version(UVM_NO_DEPRECATED) { }
 else {
   version = UVM_INCLUDE_DEPRECATED;
 }


struct m_verbosity_setting {
  string comp;
  string phase;
  SimTime   offset;
  uvm_verbosity verbosity;
  string id;
}

abstract class uvm_component: uvm_report_object, ParContext
{
  static class uvm_once: uvm_once_base
  {
    version(UVM_INCLUDE_DEPRECATED) {
      @uvm_public_sync
    	bool _m_config_deprecated_warned;

      // Used for caching config settings -- never used??
      // @uvm_public_sync bool _m_config_set = true;
    }
    // m_config_set is declared in SV version but is not used anywhere
    @uvm_private_sync bool _m_config_set = true;

    @uvm_public_sync
    bool _print_config_matches;

    m_verbosity_setting[] _m_time_settings;
    @uvm_private_sync
    bool _print_config_warned;

    uint _m_comp_count;

    uvm_cmdline_parsed_arg_t[] _m_uvm_applied_cl_action;
    @uvm_none_sync
    const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_action() {
      synchronized(this) {
	return _m_uvm_applied_cl_action.dup;
      }
    }

    uvm_cmdline_parsed_arg_t[] _m_uvm_applied_cl_sev;
    @uvm_none_sync
    const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_sev() {
      synchronized(this) {
	return _m_uvm_applied_cl_sev.dup;
      }
    }

    @uvm_private_sync
    bool _cl_action_initialized;
    @uvm_private_sync
    bool _cl_sev_initialized;

    @uvm_none_sync
    void add_m_uvm_applied_cl_action(uvm_cmdline_parsed_arg_t arg) {
      synchronized(this) {
	_m_uvm_applied_cl_action ~= arg;
      }
    }
    @uvm_none_sync
    void add_m_uvm_applied_cl_sev(uvm_cmdline_parsed_arg_t arg) {
      synchronized(this) {
	_m_uvm_applied_cl_sev ~= arg;
      }
    }
  }

  mixin(uvm_once_sync_string);

  protected const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_action() {
    return once.m_uvm_applied_cl_action();
  }
  protected const(uvm_cmdline_parsed_arg_t[]) m_uvm_applied_cl_sev() {
    return once.m_uvm_applied_cl_sev();
  }

  mixin(uvm_sync_string);

  mixin ParContextMixin;

  _esdl__Multicore _par__info = _esdl__Multicore(MulticorePolicy._UNDEFINED_, uint.max);

  ParContext _esdl__parInheritFrom() {
    import uvm.base.uvm_coreservice;
    auto c = get_parent();
    if(c is null) {
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
  this(string name, uvm_component parent) {
    import uvm.base.uvm_root;
    import uvm.base.uvm_entity;
    import uvm.base.uvm_coreservice;
    synchronized(this) {

      super(name);

      _m_children = null;
      _m_children_by_handle = null;

      // Since Vlang allows multi uvm_root instances, it is better to
      // have a unique name for each uvm_root instance

      // If uvm_top, reset name to "" so it doesn't show in full paths then return
      // separated to uvm_root specific constructor
      // if(parent is null && name == "__top__") {
      //	set_name(""); // *** VIRTUAL
      //	return;
      // }

      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root top = cs.get_root();

      // Check that we're not in or past end_of_elaboration
      uvm_domain common = uvm_domain.get_common_domain();
      // uvm_phase bld = common.find(uvm_build_phase.get());
      uvm_phase bld = common.find(uvm_build_phase.get());
      if(bld is null) {
	uvm_report_fatal("COMP/INTERNAL",
			 "attempt to find build phase object failed",UVM_NONE);
      }
      if(bld.get_state() == UVM_PHASE_DONE) {
	uvm_report_fatal("ILLCRT", "It is illegal to create a component ('" ~
			 name ~ "' under '" ~
			 (parent is null ? top.get_full_name() :
			  parent.get_full_name()) ~
			 "') after the build phase has ended.",
			 UVM_NONE);
      }

      if(name == "") {
	name = "COMP_" ~ m_inst_count.to!string;
      }

      if(parent is this) {
	uvm_fatal("THISPARENT", "cannot set the parent of a component to itself");
      }

      if(parent is null) {
	parent = top;
      }

      if(uvm_report_enabled(UVM_MEDIUM+1, UVM_INFO, "NEWCOMP")) {
	uvm_info("NEWCOMP", "Creating " ~
		 (parent is top ? "uvm_top" :
		  parent.get_full_name()) ~ "." ~ name,
		 cast(uvm_verbosity) (UVM_MEDIUM+1));
      }

      if(parent.has_child(name) && this !is parent.get_child(name)) {
	if(parent is top) {
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

      if(!_m_parent.m_add_child(this)) {
	_m_parent = null;
      }

      _event_pool = new uvm_event_pool("event_pool");

      _m_domain = parent.m_domain;     // by default, inherit domains from parents

      // Now that inst name is established, reseed (if use_uvm_seeding is set)
      reseed();

      // Do local configuration settings
      // if(!uvm_config_db!(uvm_bitstream_t).get(this, "", "recording_detail", recording_detail)) {
      //   uvm_config_db!(int).get(this, "", "recording_detail", recording_detail);
      // }
      uvm_bitstream_t bs_recording_detail;
      if(uvm_config_db!uvm_bitstream_t.get(this, "", "recording_detail",
					   bs_recording_detail)) {
	_recording_detail = cast(uint) bs_recording_detail;
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
    synchronized(this) {
      assert(cast(uvm_root) this);
      if(get_name() == "__top__") {
	super.set_name(name);
	_m_name = name;
      }
      else {
	assert(false, "Called set_root_name on a non-root");
      }
    }
  }

  // Csontructor called by uvm_root constructor
  package this() {
    synchronized(this) {
      super("__top__");

      _m_children = null;
      _m_children_by_handle = null;
      // // make sure that we are actually construting a uvm_root
      // auto top = cast(uvm_root) this;
      // assert(top !is null);
    }
  }


  //----------------------------------------------------------------------------
  // Group: Hierarchy Interface
  //----------------------------------------------------------------------------
  //
  // These methods provide user access to information about the component
  // hierarchy, i.e., topology.
  //
  //----------------------------------------------------------------------------

  // Function- get_parent
  //
  // Returns a handle to this component's parent, or ~null~ if it has no parent.

  uvm_component get_parent() {
    synchronized(this) {
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

  //   extern virtual function uvm_component get_parent ();


  // Function- get_full_name
  //
  // Returns the full hierarchical name of this object. The default
  // implementation concatenates the hierarchical name of the parent, if any,
  // with the leaf name of this object, as given by <uvm_object::get_name>.


  override string get_full_name () {
    synchronized(this) {
      // Note- Implementation choice to construct full name once since the
      // full name may be used often for lookups.
      if(_m_name == "") {
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
  //|   foreach(array[i])
  //|     do_something(array[i]);

  final void get_children(ref Queue!uvm_component children) {
    synchronized(this) {
      children ~= cast(uvm_component[]) m_children.values;
    }
  }

  final void get_children(ref uvm_component[] children) {
    synchronized(this) {
      children ~= cast(uvm_component[]) m_children.values;
    }
  }

  final uvm_component[] get_children() {
    synchronized(this) {
      return cast(uvm_component[]) m_children.values;
    }
  }


  // get_child
  // ---------

  final uvm_component get_child(string name) {
    synchronized(this) {
      auto pcomp = name in m_children;
      if(pcomp) {
	return cast(uvm_component) *pcomp;
      }
      uvm_warning("NOCHILD", "Component with name '" ~ name ~
		  "' is not a child of component '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  private string[] _children_names;

  // get_next_child
  // --------------

  final int get_next_child(ref string name) {
    synchronized(this) {
      auto found = find(_children_names, name);
      enforce(found.length != 0, "get_next_child could not match a child" ~
	      "with name: " ~ name);
      if(found.length is 1) {
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
  //|    if(comp.get_first_child(name))
  //|      do begin
  //|        child = comp.get_child(name);
  //|        child.print();
  //|      end while (comp.get_next_child(name));

  final int get_first_child(ref string name) {
    synchronized(this) {
      _children_names = m_children.keys;
      if(_children_names.length is 0) {
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

  final size_t get_num_children() {
    synchronized(this) {
      return _m_children.length;
    }
  }

  // Function- has_child
  //
  // Returns 1 if this component has a child with the given ~name~, 0 otherwise.

  final bool has_child(string name) {
    synchronized(this) {
      if(name in _m_children) {
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
    synchronized(this) {
      if(_m_name != "") {
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

  package void _set_name_force(string name) {
    synchronized(this) {
      super.set_name(name);
      m_set_full_name();
    }
  }


  // Function- lookup
  //
  // Looks for a component with the given hierarchical ~name~ relative to this
  // component. If the given ~name~ is preceded with a '.' (dot), then the search
  // begins relative to the top level (absolute lookup). The handle of the
  // matching component is returned, else ~null~. The name must not contain
  // wildcards.

  final uvm_component lookup(string name) {
    import uvm.base.uvm_root;
    import uvm.base.uvm_coreservice;
    synchronized(this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root top = cs.get_root(); // uvm_root.get();
      uvm_component comp = this;

      string leaf , remainder;
      m_extract_name(name, leaf, remainder);

      if(leaf == "") {
	comp = top; // absolute lookup
	m_extract_name(remainder, leaf, remainder);
      }

      if(!comp.has_child(leaf)) {
	uvm_warning("Lookup Error",
		    format("Cannot find child %0s", leaf));
	return null;
      }

      if(remainder != "") {
	return (cast(uvm_component) comp.m_children[leaf]).lookup(remainder);
      }

      return (cast(uvm_component) comp.m_children[leaf]);
    }
  }


  // Function- get_depth
  //
  // Returns the component's depth from the root level. uvm_top has a
  // depth of 0. The test and any other top level components have a depth
  // of 1, and so on.

  final uint get_depth() {
    synchronized(this) {
      if(_m_name == "") {
	return 0;
      }
      uint get_depth_ = 1;
      foreach(c; _m_name) {
	if(c is '.') {
	  ++get_depth_;
	}
      }
      return get_depth_;
    }
  }



  //----------------------------------------------------------------------------
  // Group: Phasing Interface
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

  // extern virtual function void build_phase(uvm_phase phase);

  // phase methods
  //--------------
  // these are prototypes for the methods to be implemented in user components
  // build_phase() has a default implementation, the others have an empty default

  void build_phase(uvm_phase phase) {
    synchronized(this) {
      _m_build_done = true;
      build();
    }
  }

  // For backward compatibility the base <build_phase> method calls <build>.
  // extern virtual function void build();

  // Backward compatibility build function

  void build() {
    synchronized(this) {
      _m_build_done = true;
      apply_config_settings(print_config_matches);
      if(_m_phasing_active == 0) {
	uvm_report_warning("UVM_DEPRECATED",
			   "build()/build_phase() has been called explicitly," ~
			   " outside of the phasing system." ~
			   " This usage of build is deprecated and may" ~
			   " lead to unexpected behavior.");
      }
    }
  }

  // base function for auto build phase
  @uvm_public_sync
  bool _uvm__parallelize_done = false;

  void uvm__auto_build() {
    debug(UVM_AUTO) {
      import std.stdio;
      writeln("Building .... : ", get_full_name);
    }
    // super is called in m_uvm_component_automation
    // super.uvm__auto_build(); --
    m_uvm_component_automation(UVM_BUILD);
    // .uvm__auto_build!(0, typeof(this))(this);
  }

  void uvm__parallelize() {
    // super is called in m_uvm_component_automation
    // super.uvm__parallelize();
    m_uvm_component_automation(UVM_PARALLELIZE);
    // .uvm__auto_build!(0, typeof(this))(this);
  }

  // Function- connect_phase
  //
  // The <uvm_connect_phase> phase implementation method.
  //
  // This method should never be called directly.

  void connect_phase(uvm_phase phase) {
    synchronized(this) {
      connect();
      return;
    }
  }

  // For backward compatibility the base connect_phase method calls connect.
  // extern virtual function void connect();

  void connect() {
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

  void end_of_elaboration_phase(uvm_phase phase) {
    synchronized(this) {
      end_of_elaboration();
      return;
    }
  }

  // For backward compatibility the base <end_of_elaboration_phase> method calls <end_of_elaboration>.
  void end_of_elaboration() {
    return;
  }

  // Function- start_of_simulation_phase
  //
  // The <uvm_start_of_simulation_phase> phase implementation method.
  //
  // This method should never be called directly.

  void start_of_simulation_phase(uvm_phase phase) {
    synchronized(this) {
      start_of_simulation();
      return;
    }
  }

  // For backward compatibility the base <start_of_simulation_phase> method calls <start_of_simulation>.

  void start_of_simulation() {
    return;
  }

  // Task: run_phase
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

  // task
  void run_phase(uvm_phase phase) {
    run();
    return;
  }

  // For backward compatibility the base <run_phase> method calls <run>.

  // task
  void run() {
    return;
  }

  // Task: pre_reset_phase
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

  // task
  void pre_reset_phase(uvm_phase phase) {
    return;
  }

  // Task: reset_phase
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

  // task
  void reset_phase(uvm_phase phase) {
    return;
  }

  // Task: post_reset_phase
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

  // task
  void post_reset_phase(uvm_phase phase) {
    return;
  }

  // Task: pre_configure_phase
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

  // task
  void pre_configure_phase(uvm_phase phase) {
    return;
  }

  // Task: configure_phase
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

  // task
  void configure_phase(uvm_phase phase) {
    return;
  }

  // Task: post_configure_phase
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

  // task
  void post_configure_phase(uvm_phase phase) {
    return;
  }

  // Task: pre_main_phase
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

  // task
  void pre_main_phase(uvm_phase phase) {
    return;
  }

  // Task: main_phase
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

  // task
  void main_phase(uvm_phase phase) {
    return;
  }

  // Task: post_main_phase
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

  // task
  void post_main_phase(uvm_phase phase) {
    return;
  }

  // Task: pre_shutdown_phase
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

  // task
  void pre_shutdown_phase(uvm_phase phase) {
    return;
  }

  // Task: shutdown_phase
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

  // task
  void shutdown_phase(uvm_phase phase) {
    return;
  }

  // Task: post_shutdown_phase
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

  // task
  void post_shutdown_phase(uvm_phase phase) {
    return;
  }

  // Function- extract_phase
  //
  // The <uvm_extract_phase> phase implementation method.
  //
  // This method should never be called directly.

  void extract_phase(uvm_phase phase) {
    synchronized(this) {
      extract();
      return;
    }
  }

  // For backward compatibility the base extract_phase method calls extract.
  void extract() {
    return;
  }

  // Function- check_phase
  //
  // The <uvm_check_phase> phase implementation method.
  //
  // This method should never be called directly.

  void check_phase(uvm_phase phase) {
    synchronized(this) {
      check();
      return;
    }
  }

  // For backward compatibility the base check_phase method calls check.
  void check() {
    return;
  }

  // Function- report_phase
  //
  // The <uvm_report_phase> phase implementation method.
  //
  // This method should never be called directly.

  void report_phase(uvm_phase phase) {
    synchronized(this) {
      report();
      return;
    }
  }

  // For backward compatibility the base report_phase method calls report.
  void report() {
    return;
  }

  // Function- final_phase
  //
  // The <uvm_final_phase> phase implementation method.
  //
  // This method should never be called directly.

  void final_phase(uvm_phase phase) {
    return;
  }

  // Function- phase_started
  //
  // Invoked at the start of each phase. The ~phase~ argument specifies
  // the phase being started. Any threads spawned in this callback are
  // not affected when the phase ends.

  //   extern virtual function void phase_started (uvm_phase phase);

  // phase_started
  // -------------
  // phase_started() and phase_ended() are extra callbacks called at the
  // beginning and end of each phase, respectively.  Since they are
  // called for all phases the phase is passed in as an argument so the
  // extender can decide what to do, if anything, for each phase.

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

  void phase_ready_to_end (uvm_phase phase) { }

  // Function- phase_ended
  //
  // Invoked at the end of each phase. The ~phase~ argument specifies
  // the phase that is ending.  Any threads spawned in this callback are
  // not affected when the phase ends.

  // phase_ended
  // -----------

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

  final void set_domain(uvm_domain domain, bool hier=true) {
    synchronized(this) {
      // build and store the custom domain
      _m_domain = domain;
      define_domain(domain);
      if(hier) {
	foreach (c; m_children) {
	  (cast(uvm_component) c).set_domain(domain);
	}
      }
    }
  }

  // Function- get_domain
  //
  // Return handle to the phase domain set on this component

  // extern function uvm_domain get_domain();

  // get_domain
  // ----------
  //
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


  // define_domain
  // -------------

  final void define_domain(uvm_domain domain) {
    synchronized(this) {
      //schedule = domain.find(uvm_domain::get_uvm_schedule());
      uvm_phase schedule = domain.find_by_name("uvm_sched");
      if(schedule is null) {
	schedule = new uvm_phase("uvm_sched", UVM_PHASE_SCHEDULE);
	uvm_domain.add_uvm_phases(schedule);
	domain.add(schedule);
	uvm_domain common = uvm_domain.get_common_domain();
	if(common.find(domain, 0) is null) {
	  common.add(domain, uvm_run_phase.get());
	}
      }
    }
  }

  // Function- set_phase_imp
  //
  // Override the default implementation for a phase on this component (tree) with a
  // custom one, which must be created as a singleton object extending the default
  // one and implementing required behavior in exec and traverse methods
  //
  // The ~hier~ specifies whether to apply the custom functor to the whole tree or
  // just this component.

  // set_phase_imp
  // -------------

  final void set_phase_imp(uvm_phase phase, uvm_phase imp,
			   bool hier=true) {
    synchronized(this) {
      _m_phase_imps[phase] = imp;
      if(hier) {
	foreach (c; m_children) {
	  (cast(uvm_component) c).set_phase_imp(phase, imp, hier);
	}
      }
    }
  }

  // Task: suspend
  //
  // Suspend this component.
  //
  // This method must be implemented by the user to suspend the
  // component according to the protocol and functionality it implements.
  // A suspended component can be subsequently resumed using <resume()>.


  // suspend
  // -------

  // task
  void suspend() {
    uvm_warning("COMP/SPND/UNIMP", "suspend() not implemented");
  }

  // Task: resume
  //
  // Resume this component.
  //
  // This method must be implemented by the user to resume a component
  // that was previously suspended using <suspend()>.
  // Some component may start in the suspended state and
  // may need to be explicitly resumed.


  // resume
  // ------

  // task
  void resume() {
    uvm_warning("COMP/RSUM/UNIMP", "resume() not implemented");
  }


  version(UVM_INCLUDE_DEPRECATED) {

    // Function- status  - DEPRECATED
    //
    // Returns the status of this component.
    //
    // Returns a string that describes the current status of the
    // components. Possible values include, but are not limited to
    //
    // "<unknown>"   - Status is unknown (default)
    // "FINISHED"    - Component has stopped on its own accord. May be resumed.
    // "RUNNING"     - Component is running.
    //                 May be suspended after normal completion
    //                 of operation in progress.
    // "WAITING"     - Component is waiting. May be suspended immediately.
    // "SUSPENDED"   - Component is suspended. May be resumed.
    // "KILLED"      - Component has been killed and is unable to operate
    //                 any further. It cannot be resumed.


    // status
    //-------

    final string status() {
      synchronized(this) {
  	if(_m_phase_process is null) {
  	  return "<unknown>";
  	}
  	return _m_phase_process.status.to!string;
      }
    }

    // Function- kill  - DEPRECATED
    //
    // Kills the process tree associated with this component's currently running
    // task-based phase, e.g., run.

    // kill
    // ----

    void kill() {
      synchronized(this) {
  	if(_m_phase_process !is null) {
  	  _m_phase_process.abortTree();
  	  _m_phase_process = null;
  	}
      }
    }

    // Function- do_kill_all  - DEPRECATED
    //
    // Recursively calls <kill> on this component and all its descendants,
    // which abruptly ends the currently running task-based phase, e.g., run.
    // See <run_phase> for better options to ending a task-based phase.

    void do_kill_all() {
      foreach(c; m_children) {
  	(cast(uvm_component) c).do_kill_all();
  	this.kill();
      }
    }

    // Task- stop_phase  -- DEPRECATED
    //
    // The stop_phase task is called when this component's <enable_stop_interrupt>
    // bit is set and <global_stop_request> is called during a task-based phase,
    // e.g., run.
    //
    // Before a phase is abruptly ended, e.g., when a test deems the simulation
    // complete, some components may need extra time to shut down cleanly. Such
    // components may implement stop_phase to finish the currently executing
    // transaction, flush the queue, or perform other cleanup. Upon return from
    // stop_phase, a component signals it is ready to be stopped.
    //
    // The ~stop_phase~ method will not be called if <enable_stop_interrupt> is 0.
    //
    // The default implementation is empty, i.e., it will return immediately.
    //
    // This method should never be called directly.


    // stop_phase
    // ----------

    // task
    void stop_phase(uvm_phase phase) {
      stop(phase.get_name());
      return;
    }
    // backward compat

    // task
    void stop(string ph_name) {
      return;
    }

    // Variable- enable_stop_interrupt  - DEPRECATED
    //
    // This bit allows a component to raise an objection to the stopping of the
    // current phase. It affects only time consuming phases (such as the run
    // phase).
    //
    // When this bit is set, the <stop> task in the component is called as a result
    // of a call to <global_stop_request>. Components that are sensitive to an
    // immediate killing of its run-time processes should set this bit and
    // implement the stop task to prepare for shutdown.

    // int enable_stop_interrupt;
    // this variable is declared as int in the SV version
    @uvm_public_sync
      bool _enable_stop_interrupt;
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
    if(scope_stack == "") {
      return "^$";
    }

    if(scope_stack == "*") {
      return get_full_name() ~ ".*";
    }

    // absolute path to the top-level test
    if(scope_stack == "uvm_test_top") {
      return "uvm_test_top";
    }

    // absolute path to uvm_root
    if(scope_stack[0] is '.') {
      return get_full_name() ~ scope_stack;
    }

    return get_full_name() ~ "." ~ scope_stack;
  }

  //----------------------------------------------------------------------------
  // Group: Configuration Interface
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


  version(UVM_INCLUDE_DEPRECATED) {
    // Used for caching config settings
    // moved to uvm_once
    // static bit m_config_set = 1;

    // generic
    void set_config()(string inst_name, string field_name, uvm_object value,
  		      bool clone = true) {
      set_config_object(inst_name, field_name, value, clone);
    }

    void set_config(T)(string inst_name, string field_name, T value)
      if(isIntegral!T || is(T == uvm_bitstream_t) || is(T == string)) {
  	synchronized(once) {
  	  if(m_config_deprecated_warned) {
  	    uvm_warning("UVM/CFG/SET/DPR", "get/set_config_* API has been" ~
  			" deprecated. Use uvm_config_db instead.");
  	    m_config_deprecated_warned = true;
  	  }
  	}
  	uvm_config_db!T.set(this, inst_name, field_name, value);
      }
	


    // Function- set_config_int
    alias set_config_int = set_config;

    // Function- set_config_string

    //
    // set_config_string
    //
    alias set_config_string = set_config;

    // Function- set_config_object
    //
    // Calling set_config_* causes configuration settings to be created and
    // placed in a table internal to this component. There are similar global
    // methods that store settings in a global table. Each setting stores the
    // supplied ~inst_name~, ~field_name~, and ~value~ for later use by descendent
    // components during their construction. (The global table applies to
    // all components and takes precedence over the component tables.)
    //
    // When a descendant component calls a get_config_* method, the ~inst_name~
    // and ~field_name~ provided in the get call are matched against all the
    // configuration settings stored in the global table and then in each
    // component in the parent hierarchy, top-down. Upon the first match, the
    // value stored in the configuration setting is returned. Thus, precedence is
    // global, following by the top-level component, and so on down to the
    // descendent component's parent.
    //
    // These methods work in conjunction with the get_config_* methods to
    // provide a configuration setting mechanism for integral, string, and
    // uvm_object-based types. Settings of other types, such as virtual interfaces
    // and arrays, can be indirectly supported by defining a class that contains
    // them.
    //
    // Both ~inst_name~ and ~field_name~ may contain wildcards.
    //
    // - For set_config_int, ~value~ is an integral value that can be anything
    //   from 1 bit to 4096 bits.
    //
    // - For set_config_string, ~value~ is a string.
    //
    // - For set_config_object, ~value~ must be an <uvm_object>-based object or
    //   ~null~.  Its clone argument specifies whether the object should be cloned.
    //   If set, the object is cloned both going into the table (during the set)
    //   and coming out of the table (during the get), so that multiple components
    //   matched to the same setting (by way of wildcards) do not end up sharing
    //   the same object.
    //
    //
    // See <get_config_int>, <get_config_string>, and <get_config_object> for
    // information on getting the configurations set by these methods.


    //
    // set_config_object
    //
    void set_config_object(string inst_name,
  			   string field_name,
  			   uvm_object value,
  			   bool clone = true) {
      synchronized(once) {
  	if(m_config_deprecated_warned) {
  	  uvm_warning("UVM/CFG/SET/DPR", "get/set_config_* API has been" ~
  		      " deprecated. Use uvm_config_db instead.");
  	  m_config_deprecated_warned = true;
  	}
      }
      if(value is null) {
  	uvm_warning("NULLCFG", "A null object was provided as a " ~
  		    format("configuration object for set_config_object" ~
  			   "(\"%s\",\"%s\")", inst_name, field_name) ~
  		    ". Verify that this is intended.");
      }

      if(clone && (value !is null)) {
  	uvm_object tmp = value.clone();
  	if(tmp is null) {
  	  auto comp = cast(uvm_component) value;
  	  if(comp !is null) {
  	    uvm_error("INVCLNC", "Clone failed during set_config_object " ~
  		      "with an object that is a uvm_component. Components" ~
  		      " cannot be cloned.");
  	    return;
  	  }
  	  else {
  	    uvm_warning("INVCLN", "Clone failed during set_config_object, " ~
  			"the original reference will be used for configuration" ~
  			". Check that the create method for the object type" ~
  			" is defined properly.");
  	  }
  	}
  	else {
  	  value = tmp;
  	}
      }

      uvm_config_object.set(this, inst_name, field_name, value);

      auto wrapper = new uvm_config_object_wrapper();
      synchronized(wrapper) {
  	wrapper.obj = value;
  	wrapper.clone = clone;
      }
      uvm_config_db!(uvm_config_object_wrapper).set(this, inst_name,
  						    field_name, wrapper);
    }

    // generic
    bool get_config(T)(string field_name, ref T value)
      if(isIntegral!T || is(T == uvm_bitstream_t) || is(T == string)) {
  	synchronized(once) {
  	  if(m_config_deprecated_warned) {
  	    uvm_warning("UVM/CFG/SET/DPR", "get/set_config_* API has been" ~
  			" deprecated. Use uvm_config_db instead.");
  	    m_config_deprecated_warned = true;
  	  }
  	}
  	return uvm_config_db!T.get(this, "", field_name, value);
      }

    // Function- get_config_int
    alias get_config_int = get_config;

    // Function- get_config_string
    alias get_config_string = get_config;

    // Function- get_config_object
    //
    // These methods retrieve configuration settings made by previous calls to
    // their set_config_* counterparts. As the methods' names suggest, there is
    // direct support for integral types, strings, and objects.  Settings of other
    // types can be indirectly supported by defining an object to contain them.
    //
    // Configuration settings are stored in a global table and in each component
    // instance. With each call to a get_config_* method, a top-down search is
    // made for a setting that matches this component's full name and the given
    // ~field_name~. For example, say this component's full instance name is
    // top.u1.u2. First, the global configuration table is searched. If that
    // fails, then it searches the configuration table in component 'top',
    // followed by top.u1.
    //
    // The first instance/field that matches causes ~value~ to be written with the
    // value of the configuration setting and 1 is returned. If no match
    // is found, then ~value~ is unchanged and the 0 returned.
    //
    // Calling the get_config_object method requires special handling. Because
    // ~value~ is an output of type <uvm_object>, you must provide a uvm_object
    // handle to assign to (_not_ a derived class handle). After the call, you can
    // then $cast to the actual type.
    //
    // For example, the following code illustrates how a component designer might
    // call upon the configuration mechanism to assign its ~data~ object property,
    // whose type myobj_t derives from uvm_object.
    //
    //|  class mycomponent extends uvm_component;
    //|
    //|    local myobj_t data;
    //|
    //|    function void build_phase(uvm_phase phase);
    //|      uvm_object tmp;
    //|      super.build_phase(phase);
    //|      if(get_config_object("data", tmp))
    //|        if(!$cast(data, tmp))
    //|          `uvm_error("CFGERR","error! config setting for 'data' not of type myobj_t")
    //|        endfunction
    //|      ...
    //
    // The above example overrides the <build_phase> method. If you want to retain
    // any base functionality, you must call super.build_phase(uvm_phase phase).
    //
    // The ~clone~ bit clones the data inbound. The get_config_object method can
    // also clone the data outbound.
    //
    // See Members for information on setting the global configuration table.

    bool get_config_object (string field_name,
  			    ref uvm_object value,
  			    bool clone=true) {
      synchronized(once) {
  	if(m_config_deprecated_warned) {
  	  uvm_warning("UVM/CFG/SET/DPR", "get/set_config_* API has been" ~
  		      " deprecated. Use uvm_config_db instead.");
  	  m_config_deprecated_warned = true;
  	}
      }
      if(! uvm_config_object.get(this, "", field_name, value)) {
  	return false;
      }

      if(clone && value !is null) {
  	value = value.clone();
      }

      return true;
    }

  }


  // Function- check_config_usage
  //
  // Check all configuration settings in a components configuration table
  // to determine if the setting has been used, overridden or not used.
  // When ~recurse~ is 1 (default), configuration for this and all child
  // components are recursively checked. This function is automatically
  // called in the check phase, but can be manually called at any time.
  //
  // To get all configuration information prior to the run phase, do something
  // like this in your top object:
  //|  function void start_of_simulation_phase(uvm_phase phase);
  //|    check_config_usage();
  //|  endfunction

  final void check_config_usage (bool recurse=true) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    uvm_queue!(uvm_resource_base) rq = rp.find_unused_resources();

    if(rq.size() == 0) {
      return;
    }

    uvm_report_info("CFGNRD"," ::: The following resources have" ~
		    " at least one write and no reads :::", UVM_INFO);
    rp.print_resources(rq, 1);
  }

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

  void apply_config_settings (bool verbose=false) {

    uvm_resource_pool rp = uvm_resource_pool.get();

    // populate an internal 'field_array' with list of
    // fields declared with `uvm_field macros (checking
    // that there aren't any duplicates along the way)

    // m_uvm_object_automation (null, UVM_CHECK_FIELDS, "");

    // // if no declared fields, nothing to do.
    // if(m_uvm_status_container.no_fields) {
    //   writeln("RETURNED");
    //   return;
    // }

    if(verbose) {
      uvm_report_info("CFGAPL","applying configuration settings", UVM_NONE);
    }

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
    for(ptrdiff_t i = rq.length-1; i >= 0; --i) {
      uvm_resource_base r = rq.get(i);
      string name = r.get_name();

      // does name have brackets [] in it?
      size_t j;
      for(j = 0; j < name.length; ++j)
	if(name[j] is '[' || name[j] is '.') {
	  break;
	}

      // If it does have brackets then we'll use the name
      // up to the brackets to search m_uvm_status_container.field_array
      string search_name;
      if(j < name.length) {
	search_name = name[0..j];
      }
      else {
	search_name = name;
      }

      // if(!m_uvm_status_container.field_exists(search_name) &&
      // 	 search_name != "recording_detail") {
      // 	continue;
      // }

      if(verbose) {
	uvm_report_info("CFGAPL",
			format("applying configuration to field %s", name),
			UVM_NONE);
      }

      auto rit = cast(uvm_resource!uvm_integral_t) r;
      if(rit !is null) {
	set_int_local(name, rit.read(this));
      }
      else {
	auto rbs = cast(uvm_resource!uvm_bitstream_t) r;
	if(rbs !is null) {
	  set_int_local(name, rbs.read(this));
	}
	else {
	  auto rb = cast(uvm_resource!byte) r;
	  if(rb !is null) {
	    set_int_local(name, rb.read(this));
	  }
	  else {
	    auto rbu = cast(uvm_resource!ubyte) r;
	    if(rbu !is null) {
	      set_int_local(name, rbu.read(this));
	    }
	    else {
	      auto rs = cast(uvm_resource!short) r;
	      if(rs !is null) {
		set_int_local(name, rs.read(this));
	      }
	      else {
		auto rsu = cast(uvm_resource!ushort) r;
		if(rsu !is null) {
		  set_int_local(name, rsu.read(this));
		}
		else {
		  auto ri = cast(uvm_resource!int) r;
		  if(ri !is null) {
		    set_int_local(name, ri.read(this));
		  }
		  else {
		    auto riu = cast(uvm_resource!uint) r;
		    if(riu !is null) {
		      set_int_local(name, riu.read(this));
		    }
		    else {
		      auto rl = cast(uvm_resource!long) r;
		      if(rl !is null) {
			set_int_local(name, rl.read(this));
		      }
		      else {
			auto rlu = cast(uvm_resource!ulong) r;
			if(rlu !is null) {
			  set_int_local(name, rlu.read(this));
			}
			else {
			  auto rap = cast(uvm_resource!uvm_active_passive_enum) r;
			  if(rap !is null) {
			    set_int_local(name, rap.read(this));
			  }
			  else {
			    auto rstr = cast(uvm_resource!string) r;
			    if(rstr !is null) {
			      set_string_local(name, rstr.read(this));
			    }
			    else {
			      auto rcow = cast(uvm_resource!uvm_config_object_wrapper) r;
			      if(rcow !is null) {
				uvm_config_object_wrapper cow = rcow.read();
				set_object_local(name, cow.obj, cow.clone);
			      }
			      else {
				auto ro = cast(uvm_resource!uvm_object) r;
				if(ro !is null) {
				  set_object_local(name, ro.read(this), false);
				}
				else if(verbose) {
				  uvm_report_info("CFGAPL",
						  format("field %s has an unsupported" ~
							 " type", name), UVM_NONE);
				}
			      } // else: !if($cast(rcow, r))
			    } // else: !if($cast(rs, r))
			  } // else: !if($cast(rap, r))
			} // else: !if($cast(rlu, r))
		      } // else: !if($cast(rl, r))
		    } // else: !if($cast(riu, r))
		  } // else: !if($cast(ri, r))
		} // else: !if($cast(rsu, r))
	      } // else: !if($cast(rs, r))
	    } // else: !if($cast(rbu, r))
	  } // else: !if($cast(rb, r))
	} // else: !if($cast(rbs, r))
      } // else: !if($cast(rit, r))
    }
    // m_uvm_status_container.reset_fields();
  }



  // Function- print_config_settings
  //
  // Called without arguments, print_config_settings prints all configuration
  // information for this component, as set by previous calls to <uvm_config_db::set()>.
  // The settings are printing in the order of their precedence.
  //
  // If ~field~ is specified and non-empty, then only configuration settings
  // matching that field, if any, are printed. The field may not contain
  // wildcards.
  //
  // If ~comp~ is specified and non-~null~, then the configuration for that
  // component is printed.
  //
  // If ~recurse~ is set, then configuration information for all ~comp~'s
  // children and below are printed as well.
  //
  // This function has been deprecated.  Use print_config instead.

  // print_config_settings
  // ---------------------

  final void print_config_settings (string field = "",
				    uvm_component comp = null,
				    bool recurse = false) {
    synchronized(once) {
      if(! print_config_warned) {
	uvm_report_warning("deprecated",
			   "uvm_component.print_config_settings" ~
			   " has been deprecated.  Use print_config() instead");
	print_config_warned = true;
      }
    }
    print_config(recurse, true);
  }


  // Function- print_config
  //
  // Print_config_settings prints all configuration information for this
  // component, as set by previous calls to set_config_* and exports to
  // the resources pool.  The settings are printing in the order of
  // their precedence.
  //
  // If ~recurse~ is set, then configuration information for all
  // children and below are printed as well.
  //
  // if ~audit~ is set then the audit trail for each resource is printed
  // along with the resource name and value

  // print_config
  // ------------

  final void print_config(bool recurse = false, bool audit = false) {

    uvm_resource_pool rp = uvm_resource_pool.get();

    uvm_report_info("CFGPRT", "visible resources:", UVM_INFO);
    rp.print_resources(rp.lookup_scope(get_full_name()), audit);

    if(recurse) {
      foreach(c; m_children) {
	(cast(uvm_component) c).print_config(recurse, audit);
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


  // Variable: print_config_matches
  //
  // Setting this static variable causes uvm_config_db::get() to print info about
  // matching configuration settings as they are being applied.

  // moved to uvm_once
  //   __gshared bit print_config_matches;


  //----------------------------------------------------------------------------
  // Group: Objection Interface
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

  void dropped (uvm_objection objection, uvm_object source_obj,
		string description, int count) { }


  // Task: all_dropped
  //
  // The ~all_droppped~ callback is called when all objections have been
  // dropped by this component and all its descendants.  The ~source_obj~ is the
  // object that dropped the last objection.
  // The ~description~ is optionally provided by the ~source_obj~ to give a
  // reason for raising the objection. The ~count~ indicates the number of
  // objections dropped by the ~source_obj~.

  // task
  void all_dropped (uvm_objection objection, uvm_object source_obj,
		    string description, int count) { }

  //----------------------------------------------------------------------------
  // Group: Factory Interface
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

  //   extern function uvm_component create_component (string requested_type_name,
  //                                                   string name);

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

    if(relative_inst_path == "") {
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

    if(relative_inst_path == "") {
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
  // Group: Hierarchical Reporting Interface
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
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_id_verbosity_hier(id, verbosity);
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
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_severity_id_verbosity_hier(severity, id, verbosity);
    }
  }


  // Function- set_report_severity_action_hier

  final void set_report_severity_action_hier( uvm_severity severity,
					      uvm_action action) {
    set_report_severity_action(severity, action);
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_severity_action_hier(severity, action);
    }
  }



  // Function- set_report_id_action_hier

  final void set_report_id_action_hier( string id, uvm_action action) {
    set_report_id_action(id, action);
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_id_action_hier(id, action);
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
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_severity_id_action_hier(severity, id, action);
    }
  }

  // Function- set_report_default_file_hier

  final void set_report_default_file_hier(UVM_FILE file) {
    set_report_default_file(file);
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_default_file_hier(file);
    }
  }


  // Function- set_report_severity_file_hier

  final void set_report_severity_file_hier( uvm_severity severity,
					    UVM_FILE file) {
    set_report_severity_file(severity, file);
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_severity_file_hier(severity, file);
    }
  }

  // Function- set_report_id_file_hier

  final void set_report_id_file_hier(string id, UVM_FILE file) {
    set_report_id_file(id, file);
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_id_file_hier(id, file);
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
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_severity_id_file_hier(severity, id, file);
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
    foreach(c; m_children) {
      (cast(uvm_component) c).set_report_verbosity_level_hier(verbosity);
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

  void pre_abort() { }

  //----------------------------------------------------------------------------
  // Group: Recording Interface
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

  final void accept_tr(uvm_transaction tr,
		       SimTime accept_time = 0) {
    synchronized(this) {
      tr.accept_tr(accept_time);
      do_accept_tr(tr);
      uvm_event!uvm_object e = event_pool.get("accept_tr");
      if(e !is null)  {
	e.trigger();
      }
    }
  }



  // Function- do_accept_tr
  //
  // The <accept_tr> method calls this function to accommodate any user-defined
  // post-accept action. Implementations should call super.do_accept_tr to
  // ensure correct operation.

  protected void do_accept_tr (uvm_transaction tr) {
    return;
  }


  // Function- begin_tr
  //
  // This function marks the start of a transaction, ~tr~, by this component.
  // Specifically, it performs the following actions:
  //
  // - Calls ~tr~'s <uvm_transaction::begin_tr> method, passing to it the
  //   ~begin_time~ argument. The ~begin_time~ should be greater than or equal
  //   to the accept time. By default, when ~begin_time~ = 0, the current
  //   simulation time is used.
  //
  //   If recording is enabled (recording_detail !is UVM_OFF), then a new
  //   database-transaction is started on the component's transaction stream
  //   given by the stream argument. No transaction properties are recorded at
  //   this time.
  //
  // - Calls the component's <do_begin_tr> method to allow for any post-begin
  //   action in derived classes.
  //
  // - Triggers the component's internal begin_tr event. Any processes waiting
  //   on this event will resume in the next delta cycle.
  //
  // A handle to the transaction is returned. The meaning of this handle, as
  // well as the interpretation of the arguments ~stream_name~, ~label~, and
  // ~desc~ are vendor specific.

  final int begin_tr (uvm_transaction tr,
		      string stream_name = "main",
		      string label = "",
		      string desc = "",
		      SimTime begin_time = 0,
		      int parent_handle = 0) {
    return m_begin_tr(tr, parent_handle, stream_name, label, desc, begin_time);
  }


  // Function- begin_child_tr
  //
  // This function marks the start of a child transaction, ~tr~, by this
  // component. Its operation is identical to that of <begin_tr>, except that
  // an association is made between this transaction and the provided parent
  // transaction. This association is vendor-specific.

  final int begin_child_tr(uvm_transaction tr,
			   int parent_handle = 0,
			   string stream_name = "main",
			   string label = "",
			   string desc = "",
			   SimTime begin_time = 0) {
    return m_begin_tr(tr, parent_handle, stream_name, label, desc, begin_time);
  }

  // Function- do_begin_tr
  //
  // The <begin_tr> and <begin_child_tr> methods call this function to
  // accommodate any user-defined post-begin action. Implementations should call
  // super.do_begin_tr to ensure correct operation.

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

  final void end_tr (uvm_transaction tr,
		     SimTime end_time = 0,
		     bool free_handle = true) {
    if(tr is null) return;
    synchronized(this) {
      uvm_recorder recorder;
      tr.end_tr(end_time, free_handle);

      if((cast(uvm_verbosity) _recording_detail) != UVM_NONE) {

	if(tr in _m_tr_h) {

	  recorder = _m_tr_h[tr];

	  do_end_tr(tr, recorder.get_handle()); // callback

	  _m_tr_h.remove(tr);

	  tr.record(recorder);

	  recorder.close(end_time);

	  if(free_handle) {
	    recorder.free();
	  }

	}
	else {
	  do_end_tr(tr, 0); // callback
	}

      }

      uvm_event!uvm_object e = event_pool.get("end_tr");
      if( e !is null) e.trigger();
    }
  }


  // Function- do_end_tr
  //
  // The <end_tr> method calls this function to accommodate any user-defined
  // post-end action. Implementations should call super.do_end_tr to ensure
  // correct operation.

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

  final int record_error_tr (string stream_name = "main",
			     uvm_object info = null,
			     string label = "error_tr",
			     string desc = "",
			     SimTime error_time = 0,
			     bool keep_active = false) {
    synchronized(this) {

      uvm_tr_stream stream;
      uvm_tr_database db = m_get_tr_database();

      string etype;
      if(keep_active) etype = "Error, Link";
      else etype = "Error";

      if(error_time == 0) error_time = get_root_entity.getSimTime();

      if((stream_name == "") || (stream_name == "main")) {
	if(_m_main_stream is null) {
	  _m_main_stream =
	    tr_database.open_stream("main", this.get_full_name(), "TVM");
	}
	stream = _m_main_stream;
      }
      else {
	stream = get_tr_stream(stream_name);
      }

      int handle = 0;
      if(stream !is null) {

	uvm_recorder recorder = stream.open_recorder(label,
						     error_time,
						     etype);

	if(recorder !is null) {
	  if(label != "") {
	    recorder.record_string("label", label);
	  }
	  if(desc != "") {
	    recorder.record_string("desc", desc);
	  }
	  if(info !is null) {
	    info.record(recorder);
	  }

	  recorder.close(error_time);

	  if(keep_active == 0) {
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

  final int record_event_tr(string stream_name = "main",
			    uvm_object info = null,
			    string label = "event_tr",
			    string desc = "",
			    SimTime event_time = 0,
			    bool keep_active = false) {
    synchronized(this) {
      uvm_tr_stream stream;
      uvm_tr_database db = m_get_tr_database();

      string etype;
      if(keep_active) etype = "Event, Link";
      else etype = "Event";

      if(event_time == 0) {
	event_time = get_root_entity.getSimTime();
      }

      if((stream_name == "") || (stream_name == "main")) {
	if(_m_main_stream is null) {
	  _m_main_stream =
	    tr_database.open_stream("main", this.get_full_name(), "TVM");
	}
	stream = _m_main_stream;
      }
      else {
	stream = get_tr_stream(stream_name);
      }

      int handle = 0;
      if(stream !is null) {
	uvm_recorder recorder = stream.open_recorder(label,
						     event_time,
						     etype);

	if(recorder !is null) {
	  if(label != "") {
	    recorder.record_string("label", label);
	  }
	  if(desc != "") {
	    recorder.record_string("desc", desc);
	  }
	  if(info !is null) {
	    info.record(recorder);
	  }

	  recorder.close(event_time);

	  if(keep_active == 0) {
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

  // Function: get_tr_stream
  // Returns a tr stream with ~this~ component's full name as a scope.
  //
  // Streams which are retrieved via this method will be stored internally,
  // such that later calls to ~get_tr_stream~ will return the same stream
  // reference.
  //
  // The stream can be removed from the internal storage via a call
  // to <free_tr_stream>.
  //
  // Parameters:
  // name - Name for the stream
  // stream_type_name - Type name for the stream (Default = "")
  // extern virtual function uvm_tr_stream get_tr_stream(string name,
  //                                                     string stream_type_name="");

  // get_tr_stream
  // ------------
  uvm_tr_stream get_tr_stream(string name,
			      string stream_type_name="") {
    synchronized(this) {
      uvm_tr_database db = m_get_tr_database();
      if(name !in _m_streams || stream_type_name !in _m_streams[name]) {
	_m_streams[name][stream_type_name] =
	  db.open_stream(name, this.get_full_name(), stream_type_name);
      }
      return _m_streams[name][stream_type_name];
    }
  }

  // Function: free_tr_stream
  // Frees the internal references associated with ~stream~.
  //
  // The next call to <get_tr_stream> will result in a newly created
  // <uvm_tr_stream>.  If the current stream is open (or closed),
  // then it will be freed.
  // extern virtual function void free_tr_stream(uvm_tr_stream stream);

  // free_tr_stream
  // --------------
  void free_tr_stream(uvm_tr_stream stream) {
    synchronized(this) {
      // Check the null case...
      if(stream is null) {
	return;
      }

      // Then make sure this name/type_name combo exists
      if(stream.get_name() !in _m_streams ||
	 stream.get_stream_type_name() !in _m_streams[stream.get_name()]) {
	return;
      }

      // Then make sure this name/type_name combo is THIS stream
      if(_m_streams[stream.get_name()][stream.get_stream_type_name()] !is stream) {
	return;
      }

      // Then delete it from the arrays
      _m_streams[stream.get_name()].remove(stream.get_type_name());
      if(_m_streams[stream.get_name()].length == 0) {
	_m_streams.remove(stream.get_name());
      }

      // Finally, free the stream if necessary
      if(stream.is_open() || stream.is_closed()) {
	stream.free();
      }
    }
  }

  // Variable: print_enabled
  //
  // This bit determines if this component should automatically be printed as a
  // child of its parent object.
  //
  // By default, all children are printed. However, this bit allows a parent
  // component to disable the printing of specific children.

  private bool _print_enabled = true;

  bool print_enabled() {
    synchronized(this) {
      return _print_enabled;
    }
  }

  void print_enabled(bool val) {
    synchronized(this) {
      _print_enabled = val;
    }
  }

  // Variable: tr_database
  //
  // Specifies the <uvm_tr_database> object to use for <begin_tr>
  // and other methods in the <Recording Interface>.
  // Default is <uvm_coreservice_t::get_default_tr_database>.
  @uvm_private_sync
  private uvm_tr_database _tr_database;
  // uvm_tr_database m_get_tr_database();

  // m_get_tr_database
  // ---------------------
  uvm_tr_database m_get_tr_database() {
    import uvm.base.uvm_coreservice;
    synchronized(this) {
      if(_tr_database is null) {
	uvm_coreservice_t cs = uvm_coreservice_t.get();
	_tr_database = cs.get_default_tr_database();
      }
      return _tr_database;
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
    synchronized(this) {
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
    synchronized(this) {
      ++_m_phasing_active;
    }
  }
  void dec_phasing_active() {
    synchronized(this) {
      --_m_phasing_active;
    }
  }

  // override void uvm_field_auto_set(string field_name, uint value,
  // 				   ref bool matched, string prefix,
  // 				   uvm_object[] hier) {
  //   super.uvm_field_auto_set(field_name, value, matched, prefix, hier);
  //   if(uvm_is_match(field_name, "recording_detail")) {
  //     _recording_detail = value;
  //   }
  // }
  
  @uvm_protected_sync
  private uvm_component _m_parent;

  private uvm_component[string] _m_children;

  const(uvm_component[string]) m_children() {
    synchronized(this) {
      return _m_children.dup;
    }
  }
  
  private uvm_component[uvm_component] _m_children_by_handle;

  const(uvm_component[uvm_component]) m_children_by_handle() {
    synchronized(this) {
      return _m_children_by_handle.dup;
    }
  }
  
  

  protected bool m_add_child(uvm_component child) {
    synchronized(this) {
      import std.string: format;
      string name = child.get_name();
      if(name in _m_children && _m_children[name] !is child) {
	uvm_warning("BDCLD",
		    format ("A child with the name '%0s' (type=%0s)" ~
			    " already exists.",
			    name, (cast(uvm_component) _m_children[name]).get_type_name()));
	return false;
      }

      if(child in _m_children_by_handle) {
	uvm_warning("BDCHLD",
		    format("A child with the name '%0s' %0s %0s'",
			   name, "already exists in parent under name '",
			   (cast(uvm_component) _m_children_by_handle[child]).get_name()));
	return false;
      }

      (cast(uvm_component[string]) _m_children)[name] = child;
      (cast(uvm_component[uvm_component]) _m_children_by_handle)[child] = child;
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
    import uvm.base.uvm_coreservice;
    synchronized(this) {
      auto cs = uvm_coreservice_t.get();
      auto top = cs.get_root();
      if(_m_parent is top || _m_parent is null) {
	_m_name = get_name();
      }
      else {
	_m_name = _m_parent.get_full_name() ~ "." ~ get_name();
      }
      foreach(c; m_children) {
	(cast(uvm_component) c).m_set_full_name();
      }
    }
  }

  // do_resolve_bindings
  // -------------------

  final void do_resolve_bindings() {
    foreach(c; m_children) {
      (cast(uvm_component) c).do_resolve_bindings();
    }
    resolve_bindings();
  }

  // do_flush  (flush_hier?)
  // --------

  final void do_flush() {
    foreach(c; m_children) {
      (cast(uvm_component) c).do_flush();
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

    if(i is -1) {
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

  private uvm_tr_stream _m_main_stream;
  private uvm_tr_stream[string][string] _m_streams;
  private uvm_recorder[uvm_transaction] _m_tr_h;

  // m_begin_tr
  // ----------
  protected int m_begin_tr (uvm_transaction tr,
			    int parent_handle=0,
			    string stream_name="main", string label="",
			    string desc="", SimTime begin_time=0) {
    synchronized(this) {

      uvm_event!uvm_object e;
      string    name;
      string    kind;
      uvm_tr_database db;
      int   handle, link_handle;
      uvm_tr_stream stream;
      uvm_recorder recorder, parent_recorder, link_recorder;

      if(tr is null) {
	return 0;
      }

      db = m_get_tr_database();

      if(parent_handle != 0) {
	parent_recorder = uvm_recorder.get_recorder_from_handle(parent_handle);
      }

      if(parent_recorder is null) {
	uvm_sequence_item seq = cast(uvm_sequence_item) tr;
	if(seq !is null) {
	  uvm_sequence_base parent_seq = seq.get_parent_sequence();
	  if(parent_seq !is null) {
	    parent_recorder = parent_seq.m_tr_recorder;
	  }
	}
      }

      if(parent_recorder !is null) {
	link_handle = tr.begin_child_tr(begin_time, parent_recorder.get_handle());
      }
      else {
	link_handle = tr.begin_tr(begin_time);
      }

      if(link_handle != 0) {
	link_recorder = uvm_recorder.get_recorder_from_handle(link_handle);
      }


      if(tr.get_name() != "") {
	name = tr.get_name();
      }
      else {
	name = tr.get_type_name();
      }

      if((cast(uvm_verbosity) _recording_detail) != UVM_NONE) {
	if((stream_name == "") || (stream_name == "main")) {
	  if(_m_main_stream is null) {
	    _m_main_stream = db.open_stream("main", this.get_full_name(), "TVM");
	  }
	  stream = _m_main_stream;
	}
	else {
	  stream = get_tr_stream(stream_name);
	}

	if(stream !is null ) {
	  kind = (parent_recorder is null) ? "Begin_No_Parent, Link" : "Begin_End, Link";

	  recorder = stream.open_recorder(name, begin_time, kind);

	  if(recorder !is null) {
	    if(label != "") {
	      recorder.record_string("label", label);
	    }
	    if(desc != "") {
	      recorder.record_string("desc", desc);
	    }

	    if(parent_recorder !is null) {
	      tr_database.establish_link(uvm_parent_child_link.get_link(parent_recorder,
									recorder));
	    }

	    if(link_recorder !is null) {
	      tr_database.establish_link(uvm_related_link.get_link(recorder,
								   link_recorder));
	    }
	    _m_tr_h[tr] = recorder;
	  }
	}

	handle = (recorder is null) ? 0 : recorder.get_handle();
	do_begin_tr(tr, stream_name, handle);
      }

      e = event_pool.get("begin_tr");
      if(e !is null) {
	e.trigger(tr);
      }

      return handle;

    }
  }

  private string _m_name;

  enum string type_name = "uvm_component";

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }

  // Vlang specific -- useful for parallelism
  @uvm_private_sync
  private int _m_comp_id = -1; // set in the auto_build_phase

  int get_id() {
    synchronized(this) {
      return _m_comp_id;
    }
  }

  void _set_id() {
    synchronized(this) {
      uint id;
      if(m_comp_id == -1) {
	synchronized(once) {
	  id = once._m_comp_count++;
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
    import std.stdio;
    import uvm.base.uvm_root;
    writeln("Calling _uvm__configure_parallelism on: ", get_full_name());
    assert(cast(uvm_root) this);
    _set_id();
    assert(config !is null);
    if(config._threadIndex == uint.max) {
      config._threadIndex =
	_esdl__parComponentId() % config._threadPool.length;
    }
    assert(_esdl__multicoreConfig is null);
    _esdl__multicoreConfig = config;
    _uvm__parallelize_done = true;
  }

  @uvm_immutable_sync
  protected uvm_event_pool _event_pool;

  private uint _recording_detail = UVM_NONE;

  // do_print (override)
  // --------

  override void do_print(uvm_printer printer) {
    synchronized(this) {
      string v;
      super.do_print(printer);

      // It is printed only if its value is other than the default (UVM_NONE)
      if(cast(uvm_verbosity) _recording_detail !is UVM_NONE)
	switch (_recording_detail) {
	case UVM_LOW:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_LOW");
	  break;
	case UVM_MEDIUM:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_MEDIUM");
	  break;
	UVM_HIGH:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_HIGH");
	  break;
	UVM_FULL:
	  printer.print_generic("recording_detail", "uvm_verbosity",
				8*_recording_detail.sizeof, "UVM_FULL");
	  break;
	default:
	  printer.print("recording_detail", _recording_detail, UVM_DEC, '.', "integral");
	  break;
	}

      version(UVM_INCLUDE_DEPRECATED) {
      	if(_enable_stop_interrupt !is false) {
      	  printer.print("enable_stop_interrupt", _enable_stop_interrupt,
      			UVM_BIN, '.', "bit");
      	}
      }
    }
  }


  // Internal methods for setting up command line messaging stuff
  //   extern function void m_set_cl_msg_args;
  // m_set_cl_msg_args
  // -----------------

  final void m_set_cl_msg_args() {
    m_set_cl_verb();
    m_set_cl_action();
    m_set_cl_sev();
  }

  //   extern function void m_set_cl_verb;
  //   extern function void m_set_cl_action;
  //   extern function void m_set_cl_sev;


  private void add_time_setting(m_verbosity_setting setting) {
    synchronized(once) {
      once._m_time_settings ~= setting;
    }
  }

  private const(m_verbosity_setting[]) sort_time_settings() {
    synchronized(once) {
      if(once._m_time_settings.length > 0) {
	// m_time_settings.sort() with ( item.offset );
	sort!((m_verbosity_setting a, m_verbosity_setting b)
	      {return a.offset < b.offset;})(once._m_time_settings);
      }
      return once._m_time_settings.dup;
    }
  }

  // m_set_cl_verb
  // -------------
  final void m_set_cl_verb() {
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_root;
    synchronized(this) {
      // _ALL_ can be used for ids
      // +uvm_set_verbosity=<comp>,<id>,<verbosity>,<phase|time>,<offset>
      // +uvm_set_verbosity=uvm_test_top.env0.agent1.*,_ALL_,UVM_FULL,time,800

      static string[] values;
      static bool first = true;
      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root top = cs.get_root();

      if(values.length == 0) {
	uvm_cmdline_proc.get_arg_values("+uvm_set_verbosity=", values);
      }

      foreach(i, value; values) {
	m_verbosity_setting setting;
	string[] args;
	uvm_split_string(value, ',', args);

	// Warning is already issued in uvm_root, so just don't keep it
	if(first && ( ((args.length != 4) && (args.length != 5)) ||
		      (clp.m_convert_verb(args[2], setting.verbosity) == 0))  )
	  {
	    // From the SV LRM -->
	    // If the dimensions of a dynamically sized array are
	    // changed while iterating over a foreach-loop construct,
	    // the results are undefined and may cause invalid index
	    // values to be generated.

	    // Therefor I am commenting out the next line
	    // values.delete(i);
	  }
	else {
	  setting.comp = args[0];
	  setting.id = args[1];
	  clp.m_convert_verb(args[2],setting.verbosity);
	  setting.phase = args[3];
	  setting.offset = 0;
	  if(args.length == 5) setting.offset = args[4].to!int;
	  if((setting.phase == "time") && (this is top)) {
	    add_time_setting(setting);
	  }

	  if(uvm_is_match(setting.comp, get_full_name()) ) {
	    if((setting.phase == "" || setting.phase == "build" || setting.phase == "time") &&
	       (setting.offset == 0))
	      {
		if(setting.id == "_ALL_")
		  set_report_verbosity_level(setting.verbosity);
		else
		  set_report_id_verbosity(setting.id, setting.verbosity);
	      }
	    else {
	      if(setting.phase != "time") {
		_m_verbosity_settings.pushBack(setting);
	      }
	    }
	  }
	}
      }
      // do time based settings
      if(this is top) {
	fork!("uvm_component/do_time_based_settings")({
	    SimTime last_time = 0;
	    auto time_settings = sort_time_settings();
	    foreach(i, setting; time_settings) {
	      uvm_component[] comps;
	      top.find_all(setting.comp, comps);
	      wait((cast(SimTime) setting.offset) - last_time);
	      // synchronized(this) {
	      last_time = setting.offset;
	      if(setting.id == "_ALL_") {
		foreach(comp; comps) {
		  comp.set_report_verbosity_level(setting.verbosity);
		}
	      }
	      else {
		foreach(comp; comps) {
		  comp.set_report_id_verbosity(setting.id, setting.verbosity);
		}
	      }
	      // }
	    }
	  });
      }
      first = false;
    }
  }


  // m_set_cl_action
  // ---------------

  final void m_set_cl_action() {
    // _ALL_ can be used for ids or severities
    // +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>
    // +uvm_set_action=uvm_test_top.env0.*,_ALL_,UVM_ERROR,UVM_NO_ACTION

    synchronized(this) {
      uvm_severity sev;
      uvm_action action;

      if(! cl_action_initialized) {
	string[] values;
	uvm_cmdline_proc.get_arg_values("+uvm_set_action=", values);
	foreach(idx, value; values) {
	  string[] args;
	  uvm_split_string(value, ',', args);

	  if(args.length !is 4) {
	    uvm_warning("INVLCMDARGS",
			format("+uvm_set_action requires 4 arguments, only %0d given for command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			       args.length, value));
	    continue;
	  }
	  if((args[2] != "_ALL_") && !uvm_string_to_severity(args[2], sev)) {
	    uvm_warning("INVLCMDARGS",
			format("Bad severity argument \"%s\" given to command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			       args[2], value));
	    continue;
	  }
	  if(!uvm_string_to_action(args[3], action)) {
	    uvm_warning("INVLCMDARGS",
			format("Bad action argument \"%s\" given to command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			       args[3], value));
	    continue;
	  }
	  uvm_cmdline_parsed_arg_t t;
	  t.args = args;
	  t.arg = value;
	  once.add_m_uvm_applied_cl_action(t);
	}
	cl_action_initialized = true;
      }

      synchronized(once) {
	foreach(i, ref cl_action; once._m_uvm_applied_cl_action) {
	  string[] args = cl_action.args;

	  if (!uvm_is_match(args[0], get_full_name()) ) {
	    continue;
	  }

	  uvm_string_to_severity(args[2], sev);
	  uvm_string_to_action(args[3], action);

	  synchronized(once) {
	    cl_action.used++;
	  }

	  if(args[1] == "_ALL_") {
	    if(args[2] == "_ALL_") {
	      set_report_severity_action(UVM_INFO, action);
	      set_report_severity_action(UVM_WARNING, action);
	      set_report_severity_action(UVM_ERROR, action);
	      set_report_severity_action(UVM_FATAL, action);
	    }
	    else {
	      set_report_severity_action(sev, action);
	    }
	  }
	  else {
	    if(args[2] == "_ALL_") {
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

    synchronized(this) {
      uvm_severity orig_sev;
      uvm_severity sev;

      if(! cl_sev_initialized) {
	string[] values;
	uvm_cmdline_proc.get_arg_values("+uvm_set_severity=", values);

	foreach(idx, value; values) {
	  string[] args;
	  uvm_split_string(value, ',', args);
	  if(args.length !is 4) {
	    uvm_warning("INVLCMDARGS", format("+uvm_set_severity requires 4 arguments, only %0d given for command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args.length, value));
	    continue;
	  }
	  if(args[2] != "_ALL_" && !uvm_string_to_severity(args[2], orig_sev)) {
	    uvm_warning("INVLCMDARGS", format("Bad severity argument \"%s\" given to command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args[2], value));
	    continue;
	  }
	  if(!uvm_string_to_severity(args[3], sev)) {
	    uvm_warning("INVLCMDARGS", format("Bad severity argument \"%s\" given to command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args[3], value));
	    continue;
	  }
	  uvm_cmdline_parsed_arg_t t;
	  t.args = args;
	  t.arg = value;
	  once.add_m_uvm_applied_cl_sev(t);
	}
	cl_sev_initialized = true;
      }
      synchronized(once) {
	foreach(i, ref cl_sev; once._m_uvm_applied_cl_sev) {
	  string[] args = cl_sev.args;

	  if (!uvm_is_match(args[0], get_full_name())) {
	    continue;
	  }

	  uvm_string_to_severity(args[2], orig_sev);
	  uvm_string_to_severity(args[3], sev);
	  synchronized(once) {
	    cl_sev.used++;
	  }

	  if(args[1] == "_ALL_" && args[2] == "_ALL_") {
	    set_report_severity_override(UVM_INFO,sev);
	    set_report_severity_override(UVM_WARNING,sev);
	    set_report_severity_override(UVM_ERROR,sev);
	    set_report_severity_override(UVM_FATAL,sev);
	  }
	  else if(args[1] == "_ALL_") {
	    set_report_severity_override(orig_sev,sev);
	  }
	  else if(args[2] == "_ALL_") {
	    set_report_severity_id_override(UVM_INFO,args[1],sev);
	    set_report_severity_id_override(UVM_WARNING,args[1],sev);
	    set_report_severity_id_override(UVM_ERROR,args[1],sev);
	    set_report_severity_id_override(UVM_FATAL,args[1],sev);
	  }
	  else {
	    set_report_severity_id_override(orig_sev,args[1],sev);
	  }
	}
      }
    }
  }

  // extern function void m_apply_verbosity_settings(uvm_phase phase);

  // m_apply_verbosity_settings
  // --------------------------

  final void m_apply_verbosity_settings(uvm_phase phase) {
    synchronized(this) {
      foreach(i, setting; _m_verbosity_settings) {
	if(phase.get_name() == setting.phase) {
	  if(setting.offset == 0) {
	    if(setting.id == "_ALL_") {
	      set_report_verbosity_level(setting.verbosity);
	    }
	    else {
	      set_report_id_verbosity(setting.id, setting.verbosity);
	    }
	  }
	  else {
	    Process p = Process.self;
	    Random p_rand;
	    p.getRandState(p_rand);
	    fork!("uvm_component/apply_verbosity_settings")({
		wait(setting.offset);
		// synchronized(this) {
		if(setting.id == "_ALL_")
		  set_report_verbosity_level(setting.verbosity);
		else
		  set_report_id_verbosity(setting.id, setting.verbosity);
		// }
	      });
	    p.setRandState(p_rand);
	  }
	  // Remove after use
	  _m_verbosity_settings.remove(i);
	}
      }
    }
  }

  // The verbosity settings may have a specific phase to start at.
  // We will do this work in the phase_started callback.

  private Queue!m_verbosity_setting _m_verbosity_settings;

  //   // does the pre abort callback hierarchically
  //   extern /*local*/ function void m_do_pre_abort;

  // // m_do_pre_abort
  // // --------------

  final void m_do_pre_abort() {
    foreach(child; get_children) {
      uvm_component child_ = cast(uvm_component) child;
      if(child_ !is null) {
	child_.m_do_pre_abort();
      }
    }
    pre_abort();
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
    if (isArray!E && !is(E == string)) {
      switch(what) {
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
					      cast(uvm_field_auto_enum) what,
					      cast(uvm_field_xtra_enum) what));
	break;
      }
    }
  
  static void _m_uvm_component_automation(E)(ref E e,
					     int what,
					     string name,
					     int flags,
					     _esdl__Multicore pflags,
					     uvm_component parent)
    if (is(E: uvm_component)) {
      switch(what) {
      case uvm_field_xtra_enum.UVM_PARALLELIZE:
	static if (is(E: uvm_component)) {
	  if (e !is null) {
	    e._set_id();
	    uvm__config_parallelism(e, pflags);
	  }
	}
	break;
      case uvm_field_auto_enum.UVM_BUILD:
        if (! (flags & UVM_NOBUILD) && flags & UVM_BUILD) {
	  if (e is null) {
	    e = E.type_id.create(name, parent);
	  }
	}
	break;
      default:
	uvm.base.uvm_globals.uvm_error("UVMUTLS",
				       format("UVM UTILS uknown utils" ~
					      " functionality: %s/%s",
					      cast(uvm_field_auto_enum) what,
					      cast(uvm_field_xtra_enum) what));
	break;
	  
      }
    }

  static void _m_uvm_component_automation(E, P)(ref E e,
						int what,
						string name,
						int flags,
						_esdl__Multicore pflags,
						P parent)
    if (is(E: uvm_port_base!IF, IF)) {
      switch(what) {
      case uvm_field_auto_enum.UVM_BUILD:
        if (! (flags & UVM_NOBUILD) && flags & UVM_BUILD) {
	  static if(is(E: uvm_port_base!IF, IF)) {
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
    if (is(T: uvm_component)) {
      static if (I < t.tupleof.length) {
	enum FLAGS = uvm_field_auto_get_flags!(t, I);
	alias EE = UVM_ELEMENT_TYPE!(typeof(t.tupleof[I]));
	static if ((is(EE: uvm_component) ||
		    is(EE: uvm_port_base!IF, IF)) &&
		   FLAGS != 0) {
	  _esdl__Multicore pflags;
	  if (what == UVM_BUILD) {
	    bool is_active = true; // if not uvm_agent, everything is active
	    static if (is(T: uvm_agent)) {
	      is_active = t.get_is_active();
	    }
	    bool active_flag =
	      UVM_IN_TUPLE!(0, UVM_ACTIVE, __traits(getAttributes, t.tupleof[I]));
	    if (! active_flag || is_active) {
	      _m_uvm_component_automation(t.tupleof[I], what,
					  t.tupleof[I].stringof[2..$],
					  FLAGS, pflags, t);
	    }
	  }
	  else if (what == UVM_PARALLELIZE) {
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
  mixin(uvm_sync_string);
  @uvm_private_sync private uvm_object _obj;
  @uvm_private_sync private bool _clone;
}

////////////////////////////////////////////////////////////////
// Auto Build Functions

template UVM__IS_MEMBER_COMPONENT(L)
{
  static if(is(L == class) && is(L: uvm_component)) {
    enum bool UVM__IS_MEMBER_COMPONENT = true;
  }
  else static if(isArray!L) {
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
//   static if(is(L == class) && is(L: uvm_port_base!IF, IF)) {
//     enum bool UVM__IS_MEMBER_BASE_PORT = true;
//   }
//   else static if(isArray!L) {
//     import std.range: ElementType;
//     enum bool UVM__IS_MEMBER_BASE_PORT =
//       UVM__IS_MEMBER_BASE_PORT!(ElementType!L);
//   }
//   else {
//     enum bool UVM__IS_MEMBER_BASE_PORT = false;
//   }
// }

// void uvm__auto_build(size_t I, T, N...)(T t)
//   if(is(T : uvm_component) && is(T == class)) {
//     // pragma(msg, N);
//     static if(I < t.tupleof.length) {
//       alias M=typeof(t.tupleof[I]);
//       static if(UVM__IS_MEMBER_COMPONENT!M || UVM__IS_MEMBER_BASE_PORT!M) {
// 	uvm__auto_build!(I+1, T, N, I)(t);
//       }
//       else {
// 	uvm__auto_build!(I+1, T, N)(t);
//       }
//     }
//     else {
//       // first build these
//       static if(N.length > 0) {
// 	alias U = typeof(t.tupleof[N[0]]);
// 	uvm__auto_build!(T, U, N)(t, t.tupleof[N[0]]);
//       }
//       else static if(is(T: uvm_root)) {
// 	if(t.m_children.length is 0) {
// 	  uvm_report_fatal("NOCOMP",
// 			   "No components instantiated. You must either "
// 			   "instantiate at least one component before "
// 			   "calling run_test or use run_test to do so. "
// 			   "To run a test using run_test, use +UVM_TESTNAME "
// 			   "or supply the test name in the argument to "
// 			   "run_test(). Exiting simulation.", UVM_NONE);
// 	  return;
// 	}
//       }
//       // then go over the base object
//       static if(is(T B == super)
// 		&& is(B[0]: uvm_component)
// 		&& is(B[0] == class)
// 		&& (! is(B[0] == uvm_component))
// 		&& (! is(B[0] == uvm_root))) {
// 	B[0] b = t;
// 	uvm__auto_build!(0, B)(b);
//       }
//       // and finally iterate over the children
//       // static if(N.length > 0) {
//       //	uvm__auto_build_iterate!(T, U, N)(t, t.tupleof[N[0]], []);
//       // }
//     }
//   }

// void uvm__auto_build(T, U, size_t I, N...)(T t, ref U u,
// 					    uint[] indices = []) {
//   enum bool isActiveAttr =
//     findUvmAttr!(0, UVM_ACTIVE, __traits(getAttributes, t.tupleof[I]));
//   enum bool noAutoAttr =
//     findUvmAttr!(0, UVM_NO_AUTO, __traits(getAttributes, t.tupleof[I]));
//   enum bool isAbstract = isAbstractClass!U;

//   // the top level we start with should also get an id
//   t._set_id();

//   bool is_active = true;
//   static if(is(T: uvm_agent)) {
//     is_active = t.is_active;
//   }
//   static if(isArray!U) {
//     for(size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_build!(T, E, I)(t, u[j], indices ~ cast(uint) j);
//     }
//   }
//   else {
//     string name = __traits(identifier, T.tupleof[I]);
//     foreach(i; indices) {
//       name ~= "[" ~ i.to!string ~ "]";
//     }
//     static if((! isAbstract) &&  // class is abstract
// 	      (! noAutoAttr)) {
//       if(u is null &&  // make sure that UVM_NO_AUTO is not present
// 	 (is_active ||	  // build everything if the agent is active
// 	  (! isActiveAttr))) { // build the element if not and active element
// 	static if(is(U: uvm_component)) {
// 	  import std.stdio;
// 	  writeln("Making ", name);
// 	  u = U.type_id.create(name, t);
// 	}
// 	else if(is(U: uvm_port_base!IF, IF)) {
// 	  import std.stdio;
// 	  writeln("Making ", name);
// 	  u = new U(name, t);
// 	}
// 	// else {
// 	//   static assert(false, "Support only for uvm_component and uvm_port_base");
// 	// }
//       }
//     }
//     // provide an ID to all the components that are not null
//     if(u !is null) {
//       static if(is(U: uvm_component)) {
// 	u._set_id();
//       }
//     }
//   }
//   static if(N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_build!(T, V, N)(t, t.tupleof[J], []);
//   }
// }

// void uvm__auto_build_iterate(T, U, size_t I, N...)(T t, ref U u,
//						    uint indices[]) {
//   static if(isArray!U) {
//     for(size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_build_iterate!(T, E, I)(t, u[j], indices ~ cast(uint) j);
//     }
//   }
//   else {
//     if(u !is null &&
//        (! u.uvm__auto_build_done)) {
//       u.uvm__auto_build_done(true);
//       u.uvm__auto_build();
//     }
//   }
//   static if(N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_build_iterate!(T, V, N)(t, t.tupleof[J]);
//   }
// }

// void uvm__auto_elab(size_t I=0, T, N...)(T t)
//   if(is(T : uvm_component) && is(T == class)) {
//     // pragma(msg, N);
//     static if(I < t.tupleof.length) {
//       alias M=typeof(t.tupleof[I]);
//       static if(UVM__IS_MEMBER_COMPONENT!M) {
// 	uvm__auto_elab!(I+1, T, N, I)(t);
//       }
//       else {
// 	uvm__auto_elab!(I+1, T, N)(t);
//       }
//     }
//     else {
//       // first elab these
//       static if(N.length > 0) {
// 	alias U = typeof(t.tupleof[N[0]]);
// 	uvm__auto_elab!(T, U, N)(t, t.tupleof[N[0]]);
//       }
//       // then go over the base object
//       static if(is(T B == super)
// 		&& is(B[0]: uvm_component)
// 		&& is(B[0] == class)
// 		&& (! is(B[0] == uvm_component))
// 		&& (! is(B[0] == uvm_root))) {
// 	B[0] b = t;
// 	uvm__auto_elab!(0, B[0])(b);
//       }
//       // and finally iterate over the children
//       static if(N.length > 0) {
// 	uvm__auto_elab_iterate!(T, U, N)(t, t.tupleof[N[0]]);
//       }
//     }
//   }

// void uvm__auto_elab_iterate(T, U, size_t I, N...)(T t, ref U u,
// 						   uint[] indices = []) {
//   static if(isArray!U) {
//     for(size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_elab_iterate!(T, E, I)(t, u[j], indices ~ cast(uint) j);
//     }
//   }
//   else {
//     if(u !is null &&
//        (! u.uvm__parallelize_done)) {
//       u.uvm__parallelize_done(true);
//       u.uvm__auto_elab();
//     }
//   }
//   static if(N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_elab_iterate!(T, V, N)(t, t.tupleof[J]);
//   }
// }

// void uvm__auto_elab(T, U, size_t I, N...)(T t, ref U u,
// 					  uint[] indices = []) {

//   // the top level we start with should also get an id
//   t._set_id();
//   static if(isArray!U) {
//     for(size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       uvm__auto_elab!(T, E, I)(t, u[j], indices ~ cast(uint) j);
//     }
//   }
//   else {
//     // string name = __traits(identifier, T.tupleof[I]);
//     // foreach(i; indices) {
//     //   name ~= "[" ~ i.to!string ~ "]";
//     // }
//     // provide an ID to all the components that are not null
//     auto linfo = _esdl__get_parallelism!(I, T)(t);
//     if(u !is null) {
//       uvm__config_parallelism(u, linfo);
//       u._set_id();
//     }
//   }
//   static if(N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     uvm__auto_elab!(T, V, N)(t, t.tupleof[J]);
//   }
// }

void uvm__config_parallelism(T)(T t, ref _esdl__Multicore linfo)
  if(is(T : uvm_component) && is(T == class)) {
    assert(t !is null);
    if (! t._uvm__parallelize_done) {
      // if not defined for instance try getting information for class
      // attributes
      if(linfo.isUndefined) {
	linfo = _esdl__uda!(_esdl__Multicore, T);
      }

      auto parent = t.get_parent();
      MulticoreConfig pconf;
      
      if (parent is null || parent is t) { // this is uvm_root
	pconf = Process.self().getParentEntity()._esdl__getMulticoreConfig();
	assert(pconf !is null);
      }
      else {
	pconf = t.get_parent._esdl__getMulticoreConfig;
	assert(pconf !is null);
      }
	
      assert(t._esdl__getMulticoreConfig is null);
      
      auto config = linfo.makeCfg(pconf);
      
      if(config._threadIndex == uint.max) {
	config._threadIndex =
	  t._esdl__parComponentId() % config._threadPool.length;
      }
      // import std.stdio;
      // writeln("setting multicore  for ", t.get_full_name());
      t._esdl__multicoreConfig = config;
    }
    t._uvm__parallelize_done = true;
  }



// private template findUvmAttr(size_t I, alias S, A...) {
//   static if(I < A.length) {
//     static if(is(typeof(A[I]) == typeof(S)) && A[I] == S) {
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
