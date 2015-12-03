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

module uvm.base.uvm_component;
// typedef class uvm_objection;
// typedef class uvm_sequence_base;
// typedef class uvm_sequence_item;

import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_objection;
import uvm.base.uvm_phase;
import uvm.base.uvm_domain;
import uvm.base.uvm_pool;
import uvm.base.uvm_root;
import uvm.base.uvm_common_phases;
import uvm.base.uvm_config_db;
import uvm.base.uvm_spell_chkr;
import uvm.base.uvm_cmdline_processor;
import uvm.base.uvm_globals;
import uvm.base.uvm_config_db;
import uvm.base.uvm_factory;
import uvm.base.uvm_printer;
import uvm.base.uvm_recorder;
import uvm.base.uvm_transaction;
import uvm.base.uvm_resource;
import uvm.base.uvm_queue;
import uvm.base.uvm_event;
import uvm.base.uvm_misc;
import uvm.base.uvm_port_base;

import uvm.comps.uvm_agent;

import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequence_base;

import std.traits: isIntegral, isAbstractClass;

import std.string: format;
import std.conv: to;

import std.algorithm;
import std.exception: enforce;
import esdl.data.queue;


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
// Configuration - provides methods for configuring component topology and other
//     parameters ahead of and during component construction.
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

import uvm.base.uvm_report_object;
import esdl.base.core;

struct m_verbosity_setting {
  string comp;
  string phase;
  SimTime   offset;
  uvm_verbosity verbosity;
  string id;
}

abstract class uvm_component: uvm_report_object, ParContext
{
  static class uvm_once
  {
    // m_config_set is declared in SV version but is not used anywhere
    // @uvm_private_sync bool _m_config_set = true;

    @uvm_private_sync bool _print_config_matches;
    @uvm_private_sync m_verbosity_setting[] _m_time_settings;
    @uvm_private_sync bool _print_config_warned;
    @uvm_private_sync uint _m_comp_count;
  }

  mixin uvm_once_sync;
  mixin uvm_sync;

  mixin ParContextMixin;

  parallelize _par__info = parallelize(ParallelPolicy._UNDEFINED_,
				       uint.max);;

  public ParContext _esdl__parInheritFrom() {
    auto c = get_parent();
    if(c is null) {
      return uvm_top();
    }
    else return c;
  }

  public uint _esdl__parComponentId() {
    return get_id();
  }
  
  // Function: new
  //
  // Creates a new component with the given leaf instance ~name~ and handle to
  // to its ~parent~.  If the component is a top-level component (i.e. it is
  // created in a static module or interface), ~parent~ should be null.
  //
  // The component will be inserted as a child of the ~parent~ object, if any.
  // If ~parent~ already has a child by the given ~name~, an error is produced.
  //
  // If ~parent~ is null, then the component will become a child of the
  // implicit top-level component, ~uvm_top~.
  //
  // All classes derived from uvm_component must call super.new(name,parent).

  this(string name, uvm_component parent) {
    synchronized(this) {

      super(name);

      // If uvm_top, reset name to "" so it doesn't show in full paths then return
      // separated to uvm_root specific constructor
      // if (parent is null && name == "__top__") {
      // 	set_name(""); // *** VIRTUAL
      // 	return;
      // }

      uvm_root top;
      top = get_root();

      // while we are at contructing the uvm_top, there is no need to
      // check whether we are in build_phase, this can be done for
      // other uvm_components.
      if(this !is top) {
	// Check that we're not in or past end_of_elaboration
	uvm_domain common = uvm_domain.get_common_domain();
	// uvm_phase bld = common.find(uvm_build_phase.get());
	uvm_phase bld = common.find(uvm_build_phase.get());
	if (bld is null) {
	  uvm_report_fatal("COMP/INTERNAL",
			   "attempt to find build phase object failed",UVM_NONE);
	}
	if (bld.get_state() is UVM_PHASE_DONE) {
	  uvm_report_fatal("ILLCRT", "It is illegal to create a component ('" ~
			   name ~ "' under '" ~
			   (parent is null ? top.get_full_name() :
			    parent.get_full_name()) ~
			   "') after the build phase has ended.",
			   UVM_NONE);
	}
      }

      if (name == "") name = "COMP_" ~ m_inst_count.to!string;

      if(parent is this) {
	uvm_fatal("THISPARENT", "cannot set the parent of a component to itself");
      }

      if (parent is null) parent = top;

      if(uvm_report_enabled(UVM_MEDIUM+1, UVM_INFO, "NEWCOMP")) {
	uvm_info("NEWCOMP", "Creating " ~ (parent is top ? "uvm_top" :
					   parent.get_full_name()) ~ "." ~ name, UVM_MEDIUM+1);
      }

      if (parent.has_child(name) && this !is parent.get_child(name)) {
	if (parent is top) {
	  string error_str = "Name '" ~ name ~ "' is not unique to other"
	    " top-level instances. If parent is a module, build a unique"
	    " name by combining the the module name and component name: "
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
	_recording_detail = cast(uint) bs_recording_detail;
      }
      else {
	uvm_config_db!uint.get(this, "", "recording_detail", _recording_detail);
      }

      set_report_verbosity_level(parent.get_report_verbosity_level());

      m_set_cl_msg_args();

    }
  }

  // Csontructor called by uvm_root constructor
  package this() {
    synchronized(this) {
      super("__top__");
      set_name(""); // *** VIRTUAL
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

  // Function: get_parent
  //
  // Returns a handle to this component's parent, or null if it has no parent.

  public uvm_component get_parent() {
    synchronized(this) {
      return _m_parent;
    }
  }
  //   extern virtual function uvm_component get_parent ();


  // Function: get_full_name
  //
  // Returns the full hierarchical name of this object. The default
  // implementation concatenates the hierarchical name of the parent, if any,
  // with the leaf name of this object, as given by <uvm_object::get_name>.


  override public string get_full_name () {
    synchronized(this) {
      // Note- Implementation choice to construct full name once since the
      // full name may be used often for lookups.
      if(_m_name == "") return get_name();
      else  return _m_name;
    }
  }



  // Function: get_children
  //
  // This function populates the end of the ~children~ array with the
  // list of this component's children.
  //
  //|   uvm_component array[$];
  //|   my_comp.get_children(array);
  //|   foreach(array[i])
  //|     do_something(array[i]);

  final public void get_children(ref Queue!uvm_component children) {
    synchronized(this) {
      children ~= _m_children.values;
    }
  }

  final public void get_children(ref uvm_component[] children) {
    synchronized(this) {
      children ~= _m_children.values;
    }
  }

  final public uvm_component[] get_children() {
    synchronized(this) {
      uvm_component[] children = _m_children.values;
      return children;
    }
  }


  // get_child
  // ---------

  final public uvm_component get_child(string name) {
    synchronized(this) {
      if (name in _m_children) {
	return _m_children[name];
      }
      uvm_warning("NOCHILD", "Component with name '" ~ name ~
		  "' is not a child of component '" ~ get_full_name() ~ "'");
      return null;
    }
  }

  private string[]  _children_names;

  // get_next_child
  // --------------

  final public int get_next_child(ref string name) {
    synchronized(this) {
      auto found = find(_children_names, name);
      enforce(found.length != 0, "get_next_child could not match a child"
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

  // Function: get_first_child
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

  final public int get_first_child(ref string name) {
    synchronized(this) {
      this._children_names = _m_children.keys;
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

  // Function: get_num_children
  //
  // Returns the number of this component's children.

  final public size_t get_num_children() {
    synchronized(this) {
      return _m_children.length;
    }
  }

  // Function: has_child
  //
  // Returns 1 if this component has a child with the given ~name~, 0 otherwise.

  final public bool has_child(string name) {
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

  override public void set_name(string name) {
    synchronized(this) {
      if(_m_name != "") {
	uvm_error("INVSTNM",
		  format("It is illegal to change the name of a component. "
			 "The component name will not be changed to \"%s\"",
			 name));
	return;
      }
      super.set_name(name);
      m_set_full_name();
    }
  }


  // Function: lookup
  //
  // Looks for a component with the given hierarchical ~name~ relative to this
  // component. If the given ~name~ is preceded with a '.' (dot), then the search
  // begins relative to the top level (absolute lookup). The handle of the
  // matching component is returned, else null. The name must not contain
  // wildcards.

  final public uvm_component lookup(string name) {
    synchronized(this) {
      uvm_root top = get_root(); // uvm_root.get();
      uvm_component comp = this;

      string leaf , remainder;
      m_extract_name(name, leaf, remainder);

      if(leaf == "") {
	comp = top; // absolute lookup
	m_extract_name(remainder, leaf, remainder);
      }

      if (!comp.has_child(leaf)) {
	uvm_warning("Lookup Error",
		    format("Cannot find child %0s", leaf));
	return null;
      }

      if(remainder != "") {
	return comp.m_children[leaf].lookup(remainder);
      }

      return comp.m_children[leaf];
    }
  }


  // Function: get_depth
  //
  // Returns the component's depth from the root level. uvm_top has a
  // depth of 0. The test and any other top level components have a depth
  // of 1, and so on.

  final public uint get_depth() {
    synchronized(this) {
      if(_m_name == "") return 0;
      uint retval = 1;
      foreach(c; _m_name) {
	if(c is '.') ++retval;
      }
      return retval;
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
  // ends. See <uvm_phase::execute> for more details.
  //----------------------------------------------------------------------------


  // Function: build_phase
  //
  // The <uvm_build_phase> phase implementation method.
  //
  // Any override should call super.build_phase(phase) to execute the automatic
  // configuration of fields registed in the component by calling
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

  public void build_phase(uvm_phase phase) {
    synchronized(this) {
      _m_build_done = true;
      build();
    }
  }

  // For backward compatibility the base build_phase method calls build.
  // extern virtual function void build();

  // Backward compatibility build function

  public void build() {
    synchronized(this) {
      _m_build_done = true;
      apply_config_settings(print_config_matches);
      if(_m_phasing_active is 0) {
	uvm_report_warning("UVM_DEPRECATED",
			   "build()/build_phase() has been called explicitly,"
			   " outside of the phasing system."
			   " This usage of build is deprecated and may"
			   " lead to unexpected behavior.");
      }
    }
  }

  // base function for auto build phase
  bool _uvm__auto_elab_done_ = false;
  public bool _uvm__auto_elab_done() {
    return _uvm__auto_elab_done_;
  }
  public void _uvm__auto_elab_done(bool flag) {
    _uvm__auto_elab_done_ = flag;
  }

  public void _uvm__auto_build() {
    uvm_fatal("COMPUTILS", "Mixin uvm_component_utils missing for: " ~
		get_type_name());
  }

  public void _uvm__auto_elab() {}

  // Function: connect_phase
  //
  // The <uvm_connect_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void connect_phase(uvm_phase phase) {
    synchronized(this) {
      connect();
      return;
    }
  }

  // For backward compatibility the base connect_phase method calls connect.
  // extern virtual function void connect();

  public void connect() {
    return;
  }

  // Function: elaboration_phase
  //
  // The <uvm_elaboration_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void elaboration_phase(uvm_phase phase) {}

  // Function: end_of_elaboration_phase
  //
  // The <uvm_end_of_elaboration_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void end_of_elaboration_phase(uvm_phase phase) {
    synchronized(this) {
      end_of_elaboration();
      return;
    }
  }

  // For backward compatibility the base end_of_elaboration_phase method calls end_of_elaboration.
  public void end_of_elaboration() {
    return;
  }

  // Function: start_of_simulation_phase
  //
  // The <uvm_start_of_simulation_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void start_of_simulation_phase(uvm_phase phase) {
    synchronized(this) {
      start_of_simulation();
      return;
    }
  }

  // For backward compatibility the base start_of_simulation_phase method calls start_of_simulation.

  public void start_of_simulation() {
    return;
  }

  // Task: run_phase
  //
  // The <uvm_run_phase> phase implementation method.
  //
  // This task returning or not does not indicate the end
  // or persistence of this phase.
  // Thn the phase will automatically
  // ends once all objections are dropped using ~phase.drop_objection()~.
  //
  // Any processes forked by this task continue to run
  // after the task returns,
  // but they will be killed once the phase ends.
  //
  // The run_phase task should never be called directly.

  // task
  public void run_phase(uvm_phase phase) {
    run();
    return;
  }

  // For backward compatibility the base run_phase method calls run.

  // task
  public void run() {
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
  public void pre_reset_phase(uvm_phase phase) {
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
  public void reset_phase(uvm_phase phase) {
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
  public void post_reset_phase(uvm_phase phase) {
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
  public void pre_configure_phase(uvm_phase phase) {
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
  public void configure_phase(uvm_phase phase) {
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
  public void post_configure_phase(uvm_phase phase) {
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
  public void pre_main_phase(uvm_phase phase) {
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
  public void main_phase(uvm_phase phase) {
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
  public void post_main_phase(uvm_phase phase) {
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
  public void pre_shutdown_phase(uvm_phase phase) {
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
  public void shutdown_phase(uvm_phase phase) {
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
  public void post_shutdown_phase(uvm_phase phase) {
    return;
  }

  // Function: extract_phase
  //
  // The <uvm_extract_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void extract_phase(uvm_phase phase) {
    synchronized(this) {
      extract();
      return;
    }
  }

  // For backward compatibility the base extract_phase method calls extract.
  public void extract() {
    return;
  }

  // Function: check_phase
  //
  // The <uvm_check_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void check_phase(uvm_phase phase) {
    synchronized(this) {
      check();
      return;
    }
  }

  // For backward compatibility the base check_phase method calls check.
  public void check() {
    return;
  }

  // Function: report_phase
  //
  // The <uvm_report_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void report_phase(uvm_phase phase) {
    synchronized(this) {
      report();
      return;
    }
  }

  // For backward compatibility the base report_phase method calls report.
  public void report() {
    return;
  }

  // Function: final_phase
  //
  // The <uvm_final_phase> phase implementation method.
  //
  // This method should never be called directly.

  public void final_phase(uvm_phase phase) {
    return;
  }

  // Function: phase_started
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

  public void phase_started(uvm_phase phase) { }

  // Function: phase_ready_to_end
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

  public void phase_ready_to_end (uvm_phase phase) { }

  // Function: phase_ended
  //
  // Invoked at the end of each phase. The ~phase~ argument specifies
  // the phase that is ending.  Any threads spawned in this callback are
  // not affected when the phase ends.

  // phase_ended
  // -----------

  public void phase_ended(uvm_phase phase) { }

  //------------------------------
  // phase / schedule / domain API
  //------------------------------
  // methods for VIP creators and integrators to use to set up schedule domains
  // - a schedule is a named, organized group of phases for a component base type
  // - a domain is a named instance of a schedule in the master phasing schedule



  // Function: set_domain
  //
  // Apply a phase domain to this component and, if ~hier~ is set,
  // recursively to all its children.
  //
  // Calls the virtual <define_domain> method, which derived components can
  // override to augment or replace the domain definition of ita base class.
  //

  // set_domain
  // ----------
  // assigns this component [tree] to a domain. adds required schedules into graph
  // If called from build, ~hier~ won't recurse into all chilren (which don't exist yet)
  // If we have components inherit their parent's domain by default, then ~hier~
  // isn't needed and we need a way to prevent children from inheriting this component's domain

  final public void set_domain(uvm_domain domain, bool hier=true) {
    synchronized(this) {
      // build and store the custom domain
      _m_domain = domain;
      define_domain(domain);
      if (hier) {
	foreach (c; _m_children) {
	  c.set_domain(domain);
	}
      }
    }
  }

  // Function: get_domain
  //
  // Return handle to the phase domain set on this component

  // extern function uvm_domain get_domain();

  // get_domain
  // ----------
  //
  final public uvm_domain get_domain() {
    synchronized (this) {
      return _m_domain;
    }
  }

  // Function: define_domain
  //
  // Builds custom phase schedules into the provided ~domain~ handle.
  //
  // This method is called by <set_domain>, which integrators use to specify
  // this component belongs in a domain apart from the default 'uvm' domain.
  //
  // Custom component base classes requiring a custom phasing schedule can
  // augment or replace the domain definition they inherit by overriding
  // <defined_domain>. To augment, overrides would call super.define_domain().
  // To replace, overrides would not call super.define_domain().
  //
  // The default implementation adds a copy of the ~uvm~ phasing schedule to
  // the given ~domain~, if one doesn't already exist, and only if the domain
  // is currently empty.
  //
  // Calling <set_domain>
  // with the default ~uvm~ domain (see <uvm_domain::get_uvm_domain>) on
  // a component with no ~define_domain~ override effectively reverts the
  // that component to using the default ~uvm~ domain. This may be useful
  // if a branch of the testbench hierarchy defines a custom domain, but
  // some child sub-branch should remain in the default ~uvm~ domain,
  // call <set_domain> with a new domain instance handle with ~hier~ set.
  // Then, in the sub-branch, call <set_domain> with the default ~uvm~ domain handle,
  // obtained via <uvm_domain::get_uvm_domain()>.
  //
  // Alternatively, the integrator may define the graph in a new domain externally,
  // then call <set_domain> to apply it to a component.


  // define_domain
  // -------------

  final public void define_domain(uvm_domain domain) {
    synchronized(this) {
      //schedule = domain.find(uvm_domain::get_uvm_schedule());
      uvm_phase schedule = domain.find_by_name("uvm_sched");
      if (schedule is null) {
	schedule = new uvm_phase("uvm_sched", UVM_PHASE_SCHEDULE);
	uvm_domain.add_uvm_phases(schedule);
	domain.add(schedule);
	uvm_domain common = uvm_domain.get_common_domain();
	if (common.find(domain, 0) is null) {
	  common.add(domain, uvm_run_phase.get());
	}
      }
    }
  }

  // Function: set_phase_imp
  //
  // Override the default implementation for a phase on this component (tree) with a
  // custom one, which must be created as a singleton object extending the default
  // one and implementing required behavior in exec and traverse methods
  //
  // The ~hier~ specifies whether to apply the custom functor to the whole tree or
  // just this component.

  // set_phase_imp
  // -------------

  final public void set_phase_imp(uvm_phase phase, uvm_phase imp,
				  bool hier=true) {
    synchronized(this) {
      _m_phase_imps[phase] = imp;
    }
    if (hier) {
      foreach (c; _m_children) {
	c.set_phase_imp(phase, imp, hier);
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
  public void suspend() {
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
  public void resume() {
    uvm_warning("COMP/RSUM/UNIMP", "resume() not implemented");
  }


  version(UVM_NO_DEPRECATED) { }
  else {

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

    final public string status() {
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

    public void kill() {
      synchronized(this) {
	if (_m_phase_process !is null) {
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

    public void do_kill_all() {
      foreach(c; m_children) {
	c.do_kill_all();
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
    public void stop_phase(uvm_phase phase) {
      stop(phase.get_name());
      return;
    }
    // backward compat

    // task
    public void stop(string ph_name) {
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
    @uvm_public_sync bool _enable_stop_interrupt;
  } // end of version(UVM_NO_DEPRECATED) else branch


  // Function: resolve_bindings
  //
  // Processes all port, export, and imp connections. Checks whether each port's
  // min and max connection requirements are met.
  //
  // It is called just before the end_of_elaboration phase.
  //
  // Users should not call directly.


  // resolve_bindings
  // ----------------

  public void resolve_bindings() {
    return;
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


  // Used for caching config settings
  // moved to uvm_once
  // static bit m_config_set = 1;

  final public string massage_scope(string scope_stack) {

    // uvm_top
    if(scope_stack == "") return "^$";

    if(scope_stack == "*") return get_full_name() ~ ".*";

    // absolute path to the top-level test
    if(scope_stack == "uvm_test_top") return "uvm_test_top";

    // absolute path to uvm_root
    if(scope_stack[0] is '.') return get_full_name() ~ scope_stack;

    return get_full_name() ~ "." ~ scope_stack;
  }

  // generic
  public void set_config()(string inst_name, string field_name, uvm_object value,
			   bool clone = true) {
    set_config_object(inst_name, field_name, value, clone);
  }
  public void set_config(T)(string inst_name, string field_name, T value)
    if(isIntegral!T || is(T == uvm_bitstream_t) || is(T == string)) {
      uvm_config_db!T.set(this, inst_name, field_name, value);
    }


  // Function: set_config_int
  public void set_config_int(T)(string inst_name, string field_name, T value)
    if(isIntegral!T || is(T == uvm_bitstream_t)) {
      uvm_config_db!T.set(this, inst_name, field_name, value);
    }

  // Function: set_config_string

  //
  // set_config_string
  //
  public void set_config_string(string inst_name, string field_name, string value) {
    uvm_config_string.set(this, inst_name, field_name, value);
  }

  // Function: set_config_object
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
  //   null.  Its clone argument specifies whether the object should be cloned.
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
  public void set_config_object(string inst_name,
				string field_name,
				uvm_object value,
				bool clone = true) {
    if(value is null) {
      uvm_warning("NULLCFG", "A null object was provided as a " ~
		  format("configuration object for set_config_object"
			 "(\"%s\",\"%s\")", inst_name, field_name) ~
		  ". Verify that this is intended.");
    }

    if(clone && (value !is null)) {
      uvm_object tmp = value.clone();
      if(tmp is null) {
	auto comp = cast(uvm_component) value;
	if (comp !is null) {
	  uvm_error("INVCLNC", "Clone failed during set_config_object "
		    "with an object that is an uvm_component. Components"
		    " cannot be cloned.");
	  return;
	}
	else {
	  uvm_warning("INVCLN", "Clone failed during set_config_object, "
		      "the original reference will be used for configuration"
		      ". Check that the create method for the object type"
		      " is defined properly.");
	}
      }
      else {
	value = tmp;
      }
    }

    uvm_config_object.set(this, inst_name, field_name, value);

    auto wrapper = new uvm_config_object_wrapper();
    wrapper.obj = value;
    wrapper.clone = clone;
    uvm_config_db!(uvm_config_object_wrapper).set(this, inst_name,
						  field_name, wrapper);
  }

  // generic
  public bool get_config(T)(string field_name, ref T value)
    if (isIntegral!T || is(T == uvm_bitstream_t) || is(T == string)) {
      return uvm_config_db!T.get(this, "", field_name, value);
    }
  public bool get_config()(string field_name, ref uvm_object value, bool clone=true) {
    get_config_object(field_name, value, clone);
  }

  // Function: get_config_int

  public bool get_config_int(T)(string field_name, ref T value)
    if (isIntegral!T || is(T == uvm_bitstream_t)) {
      return uvm_config_db!T.get(this, "", field_name, value);
    }


  // Function: get_config_string
  public bool get_config_string(string field_name,
				ref string value) {
    return uvm_config_string.get(this, "", field_name, value);
  }


  // Function: get_config_object
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
  // ~value~ is an output of type <uvm_object>, you must provide an uvm_object
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
  //|        if (!$cast(data, tmp))
  //|          $display("error! config setting for 'data' not of type myobj_t");
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

  public bool get_config_object (string field_name,
				 ref uvm_object value,
				 bool clone=true) {

    if(! uvm_config_object.get(this, "", field_name, value)) {
      return false;
    }

    if(clone && value !is null) {
      value = value.clone();
    }

    return true;
  }


  // Function: check_config_usage
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

  final public void check_config_usage (bool recurse=true) {
    uvm_resource_pool rp = uvm_resource_pool.get();
    uvm_queue!(uvm_resource_base) rq = rp.find_unused_resources();

    if(rq.size() is 0) return;

    uvm_report_info("CFGNRD"," ::: The following resources have"
		    " at least one write and no reads :::", UVM_INFO);
    rp.print_resources(rq, 1);
  }

  // Function: apply_config_settings
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

  public void apply_config_settings (bool verbose=false) {

    uvm_resource_pool rp = uvm_resource_pool.get();

    // populate an internal 'field_array' with list of
    // fields declared with `uvm_field macros (checking
    // that there aren't any duplicates along the way)
    m_uvm_field_automation (null, UVM_CHECK_FIELDS, "");

    // if no declared fields, nothing to do.
    if (m_uvm_status_container.no_fields) return;

    if(verbose) {
      uvm_report_info("CFGAPL","applying configuration settings", UVM_NONE);
    }

    // Note: the following is VERY expensive. Needs refactoring. Should
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
    for(size_t i = rq.length-1; i >= 0; --i) {

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

      if(!uvm_resource_pool.m_has_wildcard_names &&
	 m_uvm_status_container.field_exists(search_name) &&
	 search_name != "recording_detail") {
	continue;
      }

      if(verbose) {
	uvm_report_info("CFGAPL",
			format("applying configuration to field %s", name),
			UVM_NONE);
      }

      auto rbs = cast(uvm_resource!(uvm_bitstream_t)) r;
      if(rbs !is null) {
	set_int_local(name, rbs.read(this));
      }
      else {
	auto ri = cast(uvm_resource!(int)) r;
	if(ri !is null) {
	  set_int_local(name, ri.read(this));
	}
	else {
	  auto riu = cast(uvm_resource!(uint)) r;
	  if(riu !is null) {
	    set_int_local(name, riu.read(this));
	  }
	  else {
	    auto rs = cast(uvm_resource!(string)) r;
	    if(rs !is null) {
	      set_string_local(name, rs.read(this));
	    }
	    else {
	      auto rcow = cast(uvm_resource!(uvm_config_object_wrapper)) r;
	      if(rcow !is null) {
		uvm_config_object_wrapper cow = rcow.read();
		set_object_local(name, cow.obj, cow.clone);
	      }
	      else {
		auto ro = cast(uvm_resource!(uvm_object)) r;
		if(ro !is null) {
		  set_object_local(name, ro.read(this), 0);
		}
		else if (verbose) {
		  uvm_report_info("CFGAPL",
				  format("field %s has an unsupported type", name),
				  UVM_NONE);
		}
	      }
	    }
	  }
	}
      }
    }
    m_uvm_status_container.reset_fields();
  }



  // Function: print_config_settings
  //
  // Called without arguments, print_config_settings prints all configuration
  // information for this component, as set by previous calls to set_config_*.
  // The settings are printing in the order of their precedence.
  //
  // If ~field~ is specified and non-empty, then only configuration settings
  // matching that field, if any, are printed. The field may not contain
  // wildcards.
  //
  // If ~comp~ is specified and non-null, then the configuration for that
  // component is printed.
  //
  // If ~recurse~ is set, then configuration information for all ~comp~'s
  // children and below are printed as well.
  //
  // This function has been deprecated.  Use print_config instead.

  // print_config_settings
  // ---------------------

  final public void print_config_settings (string field = "",
					   uvm_component comp = null,
					   bool recurse = false) {
    if(! print_config_warned) {
      uvm_report_warning("deprecated",
			 "uvm_component.print_config_settings"
			 " has been deprecated.  Use print_config() instead");
      print_config_warned = true;
    }

    print_config(recurse, true);
  }


  // Function: print_config
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

  final public void print_config(bool recurse = false, bool audit = false) {

    uvm_resource_pool rp = uvm_resource_pool.get();

    uvm_report_info("CFGPRT", "visible resources:", UVM_INFO);
    rp.print_resources(rp.lookup_scope(get_full_name()), audit);

    if(recurse) {
      foreach(c; m_children) {
	c.print_config(recurse, audit);
      }
    }

  }

  // Function: print_config_with_audit
  //
  // Operates the same as print_config except that the audit bit is
  // forced to 1.  This interface makes user code a bit more readable as
  // it avoids multiple arbitrary bit settings in the argument list.
  //
  // If ~recurse~ is set, then configuration information for all
  // children and below are printed as well.

  final public void print_config_with_audit(bool recurse = false) {
    print_config(recurse, true);
  }


  // Variable: print_config_matches
  //
  // Setting this static variable causes get_config_* to print info about
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


  // Function: raised
  //
  // The ~raised~ callback is called when this or a descendant of this component
  // instance raises the specfied ~objection~. The ~source_obj~ is the object
  // that originally raised the objection.
  // The ~description~ is optionally provided by the ~source_obj~ to give a
  // reason for raising the objection. The ~count~ indicates the number of
  // objections raised by the ~source_obj~.

  public void raised (uvm_objection objection, uvm_object source_obj,
		      string description, int count) {
  }


  // Function: dropped
  //
  // The ~dropped~ callback is called when this or a descendant of this component
  // instance drops the specfied ~objection~. The ~source_obj~ is the object
  // that originally dropped the objection.
  // The ~description~ is optionally provided by the ~source_obj~ to give a
  // reason for dropping the objection. The ~count~ indicates the number of
  // objections dropped by the the ~source_obj~.

  public void dropped (uvm_objection objection, uvm_object source_obj,
		       string description, int count) {
  }


  // Task: all_dropped
  //
  // The ~all_droppped~ callback is called when all objections have been
  // dropped by this component and all its descendants.  The ~source_obj~ is the
  // object that dropped the last objection.
  // The ~description~ is optionally provided by the ~source_obj~ to give a
  // reason for raising the objection. The ~count~ indicates the number of
  // objections dropped by the the ~source_obj~.

  // task
  public void all_dropped (uvm_objection objection, uvm_object source_obj,
			   string description, int count) {
  }

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

  // Function: create_component
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

  final public uvm_component create_component (string requested_type_name,
					       string name) {
    return uvm_factory.get().create_component_by_name(requested_type_name,
						      get_full_name(),
						      name, this);
  }

  // Function: create_object
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

  final public uvm_object create_object (string requested_type_name,
					 string name = "") {
    return uvm_factory.get().create_object_by_name(requested_type_name,
						   get_full_name(), name);
  }



  // Function: set_type_override_by_type
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

  static public void set_type_override_by_type(uvm_object_wrapper original_type,
					       uvm_object_wrapper override_type,
					       bool replace = true) {
    uvm_factory.get().set_type_override_by_type(original_type, override_type,
						replace);
  }


  // Function: set_inst_override_by_type
  //
  // A convenience function for <uvm_factory::set_inst_override_by_type>, this
  // method registers a factory override for components and objects created at
  // this level of hierarchy or below. In typical usage, this method is
  // equivalent to:
  //
  //|  factory.set_inst_override_by_type({get_full_name(),".",
  //|                                     relative_inst_path},
  //|                                     original_type,
  //|                                     override_type);
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

  final public void set_inst_override_by_type(string relative_inst_path,
					      uvm_object_wrapper original_type,
					      uvm_object_wrapper override_type) {
    string full_inst_path;

    if (relative_inst_path == "") full_inst_path = get_full_name();
    else full_inst_path = get_full_name() ~ "." ~ relative_inst_path;

    uvm_factory.get().set_inst_override_by_type(original_type, override_type,
						full_inst_path);
  }

  // Function: set_type_override
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

  static public void set_type_override(string original_type_name,
				       string override_type_name,
				       bool replace = true) {
    uvm_factory.get().set_type_override_by_name(original_type_name,
						override_type_name, replace);
  }



  // Function: set_inst_override
  //
  // A convenience function for <uvm_factory::set_inst_override_by_name>, this
  // method registers a factory override for components created at this level
  // of hierarchy or below. In typical usage, this method is equivalent to:
  //
  //|  factory.set_inst_override_by_name({get_full_name(),".",
  //|                                     relative_inst_path},
  //|                                      original_type_name,
  //|                                     override_type_name);
  //
  // The ~relative_inst_path~ is relative to this component and may include
  // wildcards. The ~original_type_name~ typically refers to a preregistered type
  // in the factory. It may, however, be any arbitrary string. Subsequent calls
  // to create_component or create_object with the same string and matching
  // instance path will produce the type represented by ~override_type_name~.
  // The ~override_type_name~ must refer to a preregistered type in the factory.

  final public void  set_inst_override(string relative_inst_path,
				       string original_type_name,
				       string override_type_name) {
    string full_inst_path;

    if (relative_inst_path == "") full_inst_path = get_full_name();
    else full_inst_path = get_full_name() ~ "." ~ relative_inst_path;

    uvm_factory.get().set_inst_override_by_name(original_type_name,
						override_type_name,
						full_inst_path);
  }


  // Function: print_override_info
  //
  // This factory debug method performs the same lookup process as create_object
  // and create_component, but instead of creating an object, it prints
  // information about what type of object would be created given the
  // provided arguments.

  final public void  print_override_info (string requested_type_name,
					  string name = "") {
    uvm_factory.get().debug_create_by_name(requested_type_name,
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

  // Function: set_report_id_verbosity_hier

  final public void set_report_id_verbosity_hier( string id, int verbosity) {
    set_report_id_verbosity(id, verbosity);
    foreach(c; m_children) {
      c.set_report_id_verbosity_hier(id, verbosity);
    }
  }


  // Function: set_report_severity_id_verbosity_hier
  //
  // These methods recursively associate the specified verbosity with reports of
  // the given ~severity~, ~id~, or ~severity-id~ pair. An verbosity associated
  // with a particular severity-id pair takes precedence over an verbosity
  // associated with id, which takes precedence over an an verbosity associated
  // with a severity.
  //
  // For a list of severities and their default verbosities, refer to
  // <uvm_report_handler>.

  final public void set_report_severity_id_verbosity_hier( uvm_severity severity,
							   string id,
							   int verbosity) {
    set_report_severity_id_verbosity(severity, id, verbosity);
    foreach(c; m_children) {
      c.set_report_severity_id_verbosity_hier(severity, id, verbosity);
    }
  }


  // Function: set_report_severity_action_hier

  final public void set_report_severity_action_hier( uvm_severity severity,
						     uvm_action action) {
    set_report_severity_action(severity, action);
    foreach(c; m_children) {
      c.set_report_severity_action_hier(severity, action);
    }
  }



  // Function: set_report_id_action_hier

  final public void set_report_id_action_hier( string id, uvm_action action) {
    set_report_id_action(id, action);
    foreach(c; m_children) {
      c.set_report_id_action_hier(id, action);
    }
  }

  // Function: set_report_severity_id_action_hier
  //
  // These methods recursively associate the specified action with reports of
  // the given ~severity~, ~id~, or ~severity-id~ pair. An action associated
  // with a particular severity-id pair takes precedence over an action
  // associated with id, which takes precedence over an an action associated
  // with a severity.
  //
  // For a list of severities and their default actions, refer to
  // <uvm_report_handler>.

  final public void set_report_severity_id_action_hier( uvm_severity severity,
							string id,
							uvm_action action) {
    set_report_severity_id_action(severity, id, action);
    foreach(c; m_children) {
      c.set_report_severity_id_action_hier(severity, id, action);
    }
  }

  // Function: set_report_default_file_hier

  final public void set_report_default_file_hier(UVM_FILE file) {
    set_report_default_file(file);
    foreach(c; m_children) {
      c.set_report_default_file_hier(file);
    }
  }


  // Function: set_report_severity_file_hier

  final public void set_report_severity_file_hier( uvm_severity severity,
						   UVM_FILE file) {
    set_report_severity_file(severity, file);
    foreach(c; m_children) {
      c.set_report_severity_file_hier(severity, file);
    }
  }

  // Function: set_report_id_file_hier

  final public void set_report_id_file_hier(string id, UVM_FILE file) {
    set_report_id_file(id, file);
    foreach(c; m_children) {
      c.set_report_id_file_hier(id, file);
    }
  }


  // Function: set_report_severity_id_file_hier
  //
  // These methods recursively associate the specified FILE descriptor with
  // reports of the given ~severity~, ~id~, or ~severity-id~ pair. A FILE
  // associated with a particular severity-id pair takes precedence over a FILE
  // associated with id, which take precedence over an a FILE associated with a
  // severity, which takes precedence over the default FILE descriptor.
  //
  // For a list of severities and other information related to the report
  // mechanism, refer to <uvm_report_handler>.

  final public void set_report_severity_id_file_hier(uvm_severity severity,
						     string id,
						     UVM_FILE file) {
    set_report_severity_id_file(severity, id, file);
    foreach(c; m_children) {
      c.set_report_severity_id_file_hier(severity, id, file);
    }
  }


  // Function: set_report_verbosity_level_hier
  //
  // This method recursively sets the maximum verbosity level for reports for
  // this component and all those below it. Any report from this component
  // subtree whose verbosity exceeds this maximum will be ignored.
  //
  // See <uvm_report_handler> for a list of predefined message verbosity levels
  // and their meaning.

  final public void set_report_verbosity_level_hier(int verbosity) {
    set_report_verbosity_level(verbosity);
    foreach(c; m_children) {
      c.set_report_verbosity_level_hier(verbosity);
    }
  }

  // Function: pre_abort
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

  public void pre_abort() { }

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

  // Function: accept_tr
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

  final public void accept_tr(uvm_transaction tr,
			      SimTime accept_time = 0) {
    synchronized(this) {
      tr.accept_tr(accept_time);
      do_accept_tr(tr);
      uvm_event e = _event_pool.get("accept_tr");
      if(e !is null)  {
	e.trigger();
      }
    }
  }



  // Function: do_accept_tr
  //
  // The <accept_tr> method calls this function to accommodate any user-defined
  // post-accept action. Implementations should call super.do_accept_tr to
  // ensure correct operation.

  protected void do_accept_tr (uvm_transaction tr) {
    return;
  }


  // Function: begin_tr
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

  final public int begin_tr (uvm_transaction tr,
			     string stream_name = "main",
			     string label = "",
			     string desc = "",
			     SimTime begin_time = 0,
			     int parent_handle = 0) {
    return m_begin_tr(tr, parent_handle, (parent_handle !is 0),
		      stream_name, label, desc, begin_time);
  }


  // Function: begin_child_tr
  //
  // This function marks the start of a child transaction, ~tr~, by this
  // component. Its operation is identical to that of <begin_tr>, except that
  // an association is made between this transaction and the provided parent
  // transaction. This association is vendor-specific.

  final public int begin_child_tr(uvm_transaction tr,
				  int parent_handle = 0,
				  string stream_name = "main",
				  string label = "",
				  string desc = "",
				  SimTime begin_time = 0) {
    return m_begin_tr(tr, parent_handle, true,
		      stream_name, label, desc, begin_time);
  }

  // Function: do_begin_tr
  //
  // The <begin_tr> and <begin_child_tr> methods call this function to
  // accommodate any user-defined post-begin action. Implementations should call
  // super.do_begin_tr to ensure correct operation.

  protected void do_begin_tr (uvm_transaction tr,
			      string stream_name,
			      int tr_handle) {
    return;
  }

  // Function: end_tr
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

  final public void end_tr (uvm_transaction tr,
			    SimTime end_time = 0,
			    bool free_handle = true) {
    if (tr is null) return;
    synchronized(this) {
      uvm_recorder rcrdr = (_recorder is null) ? uvm_default_recorder : _recorder;
      uint tr_h = 0;

      tr.end_tr(end_time,free_handle);

      if (cast(uvm_verbosity) _recording_detail !is UVM_NONE) {
	if(tr in _m_tr_h) {
	  tr_h = _m_tr_h[tr];
	  do_end_tr(tr, tr_h); // callback
	  _m_tr_h.remove(tr);
	  if(rcrdr.check_handle_kind("Transaction", tr_h) is true) {
	    rcrdr.tr_handle = tr_h;
	    tr.record(rcrdr);
	    rcrdr.end_tr(tr_h,end_time);
	    if (free_handle) rcrdr.free_tr(tr_h);
	  }
	}
	else {
	  do_end_tr(tr, tr_h); // callback
	}
      }

      uvm_event e = _event_pool.get("end_tr");
      if( e !is null) e.trigger();
    }
  }


  // Function: do_end_tr
  //
  // The <end_tr> method calls this function to accommodate any user-defined
  // post-end action. Implementations should call super.do_end_tr to ensure
  // correct operation.

  protected void do_end_tr(uvm_transaction tr,
			   int tr_handle) {
    return;
  }


  // Function: record_error_tr
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

  final public int record_error_tr (string stream_name = "main",
				    uvm_object info = null,
				    string label = "error_tr",
				    string desc = "",
				    SimTime error_time = 0,
				    bool keep_active = false) {
    synchronized(this) {
      int retval;
      uvm_recorder rcrdr = (_recorder is null) ?
	uvm_default_recorder : _recorder;

      string etype;
      if(keep_active) etype = "Error, Link";
      else etype = "Error";
      if(error_time == 0) error_time = getRootEntity().getSimTime;
      int stream_h = _m_stream_handle[stream_name];
      if(rcrdr.check_handle_kind("Fiber", stream_h) !is true) {
	stream_h = rcrdr.create_stream(stream_name, "TVM", get_full_name());
	_m_stream_handle[stream_name] = stream_h;
      }

      retval = rcrdr.begin_tr(etype, stream_h, label,
			      label, desc, error_time);
      if(info !is null) {
	rcrdr.tr_handle = record_error_tr;
	info.record(rcrdr);
      }

      rcrdr.end_tr(record_error_tr, error_time);

      return retval;
    }
  }


  // Function: record_event_tr
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

  final public int record_event_tr(string stream_name = "main",
				   uvm_object info = null,
				   string label = "event_tr",
				   string desc = "",
				   SimTime event_time = 0,
				   bool keep_active = false) {
    synchronized(this) {
      int retval;

      uvm_recorder rcrdr = (_recorder is null) ?
	uvm_default_recorder : _recorder;

      string etype;
      if(keep_active) etype = "Event, Link";
      else etype = "Event";

      if(event_time == 0) event_time = getRootEntity().getSimTime();

      int stream_h = _m_stream_handle[stream_name];
      if (rcrdr.check_handle_kind("Fiber", stream_h) !is true) {
	stream_h = rcrdr.create_stream(stream_name, "TVM", get_full_name());
	_m_stream_handle[stream_name] = stream_h;
      }
      retval = rcrdr.begin_tr(etype, stream_h, label,
			      label, desc, event_time);
      if(info !is null) {
	rcrdr.tr_handle = record_event_tr;
	info.record(rcrdr);
      }

      rcrdr.end_tr(record_event_tr,event_time);
      return retval;
    }
  }


  // Variable: print_enabled
  //
  // This bit determines if this component should automatically be printed as a
  // child of its parent object.
  //
  // By default, all children are printed. However, this bit allows a parent
  // component to disable the printing of specific children.

  @uvm_public_sync private bool _print_enabled = true;


  // Variable: recorder
  //
  // Specifies the <uvm_recorder> object to use for <begin_tr> and other
  // methods in the <Recording Interface>. Default is <uvm_default_recorder>.
  //

  private uvm_recorder _recorder;

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

  @uvm_public_sync
  private uvm_phase[uvm_phase] _m_phase_imps;    // functors to override ovm_root defaults

  //   //TND review protected, provide read-only accessor.
  @uvm_public_sync
  private uvm_phase _m_current_phase;            // the most recently executed phase
  protected Process _m_phase_process;

  @uvm_public_sync
  private bool _m_build_done;

  @uvm_public_sync
  private int _m_phasing_active;

  public void inc_phasing_active() {
    synchronized(this) {
      ++_m_phasing_active;
    }
  }
  public void dec_phasing_active() {
    synchronized(this) {
      --_m_phasing_active;
    }
  }

  override public void set_int_local (string field_name,
				      uvm_bitstream_t value,
				      bool recurse = true) {
    synchronized(this) {
      //call the super function to get child recursion and any registered fields
      super.set_int_local(field_name, value, recurse);

      //set the local properties
      if(uvm_is_match(field_name, "recording_detail"))
	_recording_detail = cast(uint) value;

    }
  }

  override public void set_int_local (string field_name,
				      ulong value,
				      bool recurse = true) {
    synchronized(this) {
      //call the super function to get child recursion and any registered fields
      super.set_int_local(field_name, value, recurse);

      //set the local properties
      if(uvm_is_match(field_name, "recording_detail"))
	_recording_detail = cast(uint) value;

    }
  }

  protected uvm_component _m_parent;

  @uvm_public_sync
  protected uvm_component[string] _m_children;
  protected uvm_component[uvm_component] _m_children_by_handle;

  protected bool m_add_child(uvm_component child) {
    synchronized(this) {
      import std.string: format;
      string name = child.get_name();
      if(name in _m_children && _m_children[name] !is child) {
	uvm_warning("BDCLD",
		    format ("A child with the name '%0s' (type=%0s)"
			    " already exists.",
			    name, _m_children[name].get_type_name()));
	return false;
      }

      if (child in _m_children_by_handle) {
	uvm_warning("BDCHLD",
		    format("A child with the name '%0s' %0s %0s'",
			   name, "already exists in parent under name '",
			   _m_children_by_handle[child].get_name()));
	return false;
      }

      _m_children[name] = child;
      _m_children_by_handle[child] = child;
      return true;
    }
  }


  public bool is_root() {
    return false;
  }
  
  private uvm_root get_root() {
    if(this.is_root()) {
      return cast(uvm_root) this;
    }
    else {
      uvm_root root;
      uvm_component parent = get_parent();
      if(parent !is null) {
	root = get_parent().get_root();
	return root;
      }
      else {
	// the call is made during the build and therefor we should
	// use thread specific information to get root
	return uvm_top();
      }
    }
  }

  public uvm_root_entity_base uvm_set_thread_context() {
    return get_root().uvm_set_thread_context();
  }

  // m_set_full_name
  // ---------------

  private void m_set_full_name() {
    synchronized(this) {
      uvm_root top = get_root();
      if (_m_parent is top || _m_parent is null) {
	_m_name = get_name();
      }
      else {
	_m_name = _m_parent.get_full_name() ~ "." ~ get_name();
      }
    }
    foreach(c; _m_children) {
      c.m_set_full_name();
    }
  }

  // do_resolve_bindings
  // -------------------

  final public void do_resolve_bindings() {
    foreach(c; m_children) {
      c.do_resolve_bindings();
    }
    resolve_bindings();
  }

  // do_flush  (flush_hier?)
  // --------

  final public void do_flush() {
    foreach(c; m_children) {
      c.do_flush();
    }
    flush();
  }

  // flush
  // -----

  public void flush() {
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
  override public uvm_object create (string name = "") {
    uvm_error("ILLCRT",
	      "create cannot be called on a uvm_component."
	      " Use create_component instead.");
    return null;
  }


  // clone
  // ------

  override public uvm_object clone() {
    uvm_error("ILLCLN",
	      format("Attempting to clone '%s'."
		     "  Clone cannot be called on a uvm_component."
		     "  The clone target variable will be set to null.",
		     get_full_name()));
    return null;
  }

  private int[string] _m_stream_handle;
  private int[uvm_transaction] _m_tr_h;

  public int m_begin_tr(uvm_transaction tr,
			int parent_handle = 0,
			bool has_parent = false,
			string stream_name = "main",
			string label = "",
			string desc = "",
			SimTime begin_time = 0) {
    synchronized(this) {
      if (tr is null) return 0;

      uvm_recorder rcrdr = (_recorder is null) ? uvm_default_recorder : _recorder;

      if (! has_parent) {
	auto seq = cast(uvm_sequence_item) tr;
	if (seq !is null) {
	  uvm_sequence_base parent_seq = seq.get_parent_sequence();
	  if (parent_seq !is null) {
	    parent_handle = parent_seq.m_tr_handle;
	    if (parent_handle !is 0) {
	      has_parent = true;
	    }
	  }
	}
      }

      int tr_h = 0;
      int link_tr_h;
      if(has_parent) {
	link_tr_h = tr.begin_child_tr(begin_time, parent_handle);
      }
      else {
	link_tr_h = tr.begin_tr(begin_time);
      }

      string name;
      if (tr.get_name() != "") {
	name = tr.get_name();
      }
      else {
	name = tr.get_type_name();
      }

      if(stream_name == "") stream_name = "main";

      int stream_h = 0;

      if((cast(uvm_verbosity) _recording_detail) !is UVM_NONE) {
	if(stream_name in _m_stream_handle) {
	  stream_h = _m_stream_handle[stream_name];
	}
	if (rcrdr.check_handle_kind("Fiber", stream_h) !is true) {
	  stream_h = rcrdr.create_stream(stream_name, "TVM", get_full_name());
	  _m_stream_handle[stream_name] = stream_h;
	}

	string kind = (has_parent is false) ?
	  "Begin_No_Parent, Link" : "Begin_End, Link";

	tr_h = rcrdr.begin_tr(kind, stream_h, name, label, desc, begin_time);

	if (has_parent && parent_handle !is 0) {
	  rcrdr.link_tr(parent_handle, tr_h, "child");
	}

	_m_tr_h[tr] = tr_h;

	if (rcrdr.check_handle_kind("Transaction", link_tr_h) is true) {
	  rcrdr.link_tr(tr_h,link_tr_h);
	}

	do_begin_tr(tr,stream_name,tr_h);

      }

      auto e = _event_pool.get("begin_tr");
      if (e !is null) {
	e.trigger(tr);
      }

      return tr_h;

    }
  }

  private string _m_name;

  @uvm_private_sync
  private int _m_comp_id = -1; // set in the auto_build_phase

  public int get_id() {
    return _m_comp_id;
  }

  package void set_id() {
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

  enum string type_name = "uvm_component";

  override public string get_type_name() {
    return type_name;
  }

  @uvm_immutable_sync protected uvm_event_pool _event_pool;

  private uint _recording_detail = UVM_NONE;

  // do_print (override)
  // --------

  override public void do_print(uvm_printer printer) {
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
	  printer.print_int("recording_detail", _recording_detail, UVM_DEC, '.', "integral");
	  break;
	}

      version(UVM_NO_DEPRECATED) {}
      else {
	if (_enable_stop_interrupt !is false) {
	  printer.print_int("enable_stop_interrupt", _enable_stop_interrupt,
			    UVM_BIN, '.', "bit");
	}
      }
    }
  }


  // Internal methods for setting up command line messaging stuff
  //   extern function void m_set_cl_msg_args;
  // m_set_cl_msg_args
  // -----------------

  final public void m_set_cl_msg_args() {
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

  private m_verbosity_setting[] sort_time_settings() {
    synchronized(once) {
      if (once._m_time_settings.length > 0) {
	// m_time_settings.sort() with ( item.offset );
	sort!((m_verbosity_setting a, m_verbosity_setting b)
	      {return a.offset < b.offset;})(once._m_time_settings);
      }
      return once._m_time_settings.dup;
    }
  }

  // m_set_cl_verb
  // -------------
  final public void m_set_cl_verb() {
    synchronized(this) {
      // _ALL_ can be used for ids
      // +uvm_set_verbosity=<comp>,<id>,<verbosity>,<phase|time>,<offset>
      // +uvm_set_verbosity=uvm_test_top.env0.agent1.*,_ALL_,UVM_FULL,time,800

      static string[] values;
      static bool first = true;
      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
      uvm_root top = get_root();

      if(values.length == 0) {
	uvm_cmdline_proc.get_arg_values("+uvm_set_verbosity=", values);
      }

      foreach(i, value; values) {
	m_verbosity_setting setting;
	string[] args;
	uvm_split_string(value, ',', args);

	// Warning is already issued in uvm_root, so just don't keep it
	if(first && ( ((args.length !is 4) && (args.length !is 5)) ||
		      (clp.m_convert_verb(args[2], setting.verbosity) is 0))  )
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
	  if(args.length is 5) setting.offset = args[4].to!int;
	  if((setting.phase == "time") && (this is top)) {
	    add_time_setting(setting);
	  }

	  if (uvm_is_match(setting.comp, get_full_name()) ) {
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
	fork({
	    SimTime last_time = 0;
	    m_verbosity_setting[] time_settings = sort_time_settings();
	    foreach(i, setting; time_settings) {
	      uvm_component[] comps;
	      top.find_all(setting.comp, comps);
	      wait(setting.offset - last_time);
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

  final public void m_set_cl_action() {
    // synchronized(this) {
    // _ALL_ can be used for ids or severities
    // +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>
    // +uvm_set_action=uvm_test_top.env0.*,_ALL_,UVM_ERROR,UVM_NO_ACTION

    static string[] values;
    string[] args;
    uvm_severity sev;
    uvm_action action;

    if(!values.length) {
      uvm_cmdline_proc.get_arg_values("+uvm_set_action=",values);
    }

    foreach(i, value; values) {
      uvm_split_string(value, ',', args);
      if(args.length !is 4) {
	uvm_warning("INVLCMDARGS",
		    format("+uvm_set_action requires 4 arguments, only %0d given for command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			   args.length, value));
	// values.delete(i);
	break;
      }
      if (!uvm_is_match(args[0], get_full_name()) ) break;
      if((args[2] != "_ALL_") && !uvm_string_to_severity(args[2], sev)) {
	uvm_warning("INVLCMDARGS",
		    format("Bad severity argument \"%s\" given to command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			   args[2], value));
	// values.delete(i);
	break;
      }
      if(!uvm_string_to_action(args[3], action)) {
	uvm_warning("INVLCMDARGS",
		    format("Bad action argument \"%s\" given to command +uvm_set_action=%s, Usage: +uvm_set_action=<comp>,<id>,<severity>,<action[|action]>",
			   args[3], value));
	// values.delete(i);
	break;
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
    // }
  }


  // m_set_cl_sev
  // ------------

  final public void m_set_cl_sev() {
    // synchronized(this) {
    // _ALL_ can be used for ids or severities
    //  +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>
    //  +uvm_set_severity=uvm_test_top.env0.*,BAD_CRC,UVM_ERROR,UVM_WARNING

    static string[] values;
    static bool first = true;
    string[] args;
    uvm_severity_type orig_sev;
    uvm_severity_type sev;

    if(!values.length) {
      uvm_cmdline_proc.get_arg_values("+uvm_set_severity=",values);
    }

    foreach(i, value; values) {
      uvm_split_string(value, ',', args);
      if(args.length !is 4) {
	uvm_warning("INVLCMDARGS", format("+uvm_set_severity requires 4 arguments, only %0d given for command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args.length, value));
	// values.delete(i);
	break;
      }
      if (!uvm_is_match(args[0], get_full_name()) ) break;
      if(args[2] != "_ALL_" && !uvm_string_to_severity(args[2], orig_sev)) {
	uvm_warning("INVLCMDARGS", format("Bad severity argument \"%s\" given to command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args[2], value));
	// values.delete(i);
	break;
      }
      if(!uvm_string_to_severity(args[3], sev)) {
	uvm_warning("INVLCMDARGS", format("Bad severity argument \"%s\" given to command +uvm_set_severity=%s, Usage: +uvm_set_severity=<comp>,<id>,<orig_severity>,<new_severity>", args[3], value));
	// values.delete(i);
	break;
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
    // }
  }

  // extern function void m_apply_verbosity_settings(uvm_phase phase);

  // m_apply_verbosity_settings
  // --------------------------

  final public void m_apply_verbosity_settings(uvm_phase phase) {
    // synchronized(this) {
    foreach(i, setting; _m_verbosity_settings) {
      if(phase.get_name() == setting.phase) {
	if(setting.offset == 0) {
	  if(setting.id == "_ALL_") {
	    set_report_verbosity_level(setting.verbosity);
	  }
	  else
	    set_report_id_verbosity(setting.id, setting.verbosity);
	}
	else {
	  Process p = Process.self;
	  auto p_rand = p.getRandState();

	  fork({
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
    // }
  }

  // The verbosity settings may have a specific phase to start at.
  // We will do this work in the phase_started callback.

  private Queue!m_verbosity_setting _m_verbosity_settings;

  //   // does the pre abort callback hierarchically
  //   extern /*local*/ function void m_do_pre_abort;

  // // m_do_pre_abort
  // // --------------

  final public void m_do_pre_abort() {
    foreach(child; get_children) {
      uvm_component _child = cast(uvm_component) child;
      if(child !is null) _child.m_do_pre_abort();
    }
    pre_abort();
  }

  // FIXME -- evolve esdl.data.bstr and make use of it here
  alias uvm_config_db!(uvm_bitstream_t) uvm_config_bstr;
  alias uvm_config_db!(ulong) uvm_config_ulong;
  alias uvm_config_db!(uint) uvm_config_uint;
  alias uvm_config_db!(string) uvm_config_string;
  alias uvm_config_db!(uvm_object) uvm_config_object;

}

// Undocumented struct for storing clone bit along w/
// object on set_config_object(...) calls
private class uvm_config_object_wrapper
{
  // pragma(msg, uvm_sync!uvm_config_object_wrapper);
  mixin uvm_sync;
  @uvm_private_sync private uvm_object _obj;
  @uvm_private_sync private bool _clone;
}

////////////////////////////////////////////////////////////////
// Auto Build Functions

template _uvm__is_member_component(L)
{
  static if(is(L == class) && is(L: uvm_component)) {
    enum bool _uvm__is_member_component = true;
  }
  else static if(isArray!L) {
      import std.range: ElementType;
      enum bool _uvm__is_member_component =
	_uvm__is_member_component!(ElementType!L);
    }
    else {
      enum bool _uvm__is_member_component = false;
    }
}

template _uvm__is_member_base_port(L)
{
  static if(is(L == class) && is(L: uvm_port_base!IF, IF)) {
    enum bool _uvm__is_member_base_port = true;
  }
  else static if(isArray!L) {
      import std.range: ElementType;
      enum bool _uvm__is_member_base_port =
	_uvm__is_member_base_port!(ElementType!L);
    }
    else {
      enum bool _uvm__is_member_base_port = false;
    }
}

void _uvm__auto_build(size_t I, T, N...)(T t)
  if(is(T : uvm_component) && is(T == class)) {
    // pragma(msg, N);
    static if(I < t.tupleof.length) {
      alias M=typeof(t.tupleof[I]);
      static if(_uvm__is_member_component!M || _uvm__is_member_base_port!M) {
	_uvm__auto_build!(I+1, T, N, I)(t);
      }
      else {
	_uvm__auto_build!(I+1, T, N)(t);
      }
    }
    else {
      // first build these
      static if(N.length > 0) {
	alias U = typeof(t.tupleof[N[0]]);
	_uvm__auto_build!(T, U, N)(t, t.tupleof[N[0]]);
      }
      else static if(is(T: uvm_root)) {
	  if(t.m_children.length is 0) {
	    uvm_report_fatal("NOCOMP",
			     "No components instantiated. You must either "
			     "instantiate at least one component before "
			     "calling run_test or use run_test to do so. "
			     "To run a test using run_test, use +UVM_TESTNAME "
			     "or supply the test name in the argument to "
			     "run_test(). Exiting simulation.", UVM_NONE);
	    return;
	  }
	}
      // then go over the base object
      static if(is(T B == super)
		&& is(B[0]: uvm_component)
		&& is(B[0] == class)
		&& (! is(B[0] == uvm_component))
		&& (! is(B[0] == uvm_root))) {
	B[0] b = t;
	_uvm__auto_build!(0, B)(b);
      }
      // and finally iterate over the children
      // static if(N.length > 0) {
      // 	_uvm__auto_build_iterate!(T, U, N)(t, t.tupleof[N[0]], []);
      // }
    }
  }

void _uvm__auto_build(T, U, size_t I, N...)(T t, ref U u,
					    uint[] indices = []) {
  enum bool isActiveAttr =
    findUvmAttr!(0, UVM_ACTIVE, __traits(getAttributes, t.tupleof[I]));
  enum bool noAutoAttr =
    findUvmAttr!(0, UVM_NO_AUTO, __traits(getAttributes, t.tupleof[I]));
  enum bool isAbstract = isAbstractClass!U;

  // the top level we start with should also get an id
  t.set_id();
  
  bool is_active = true;
  static if(is(T: uvm_agent)) {
    is_active = t.is_active;
  }
  static if(isArray!U) {
    for(size_t j = 0; j < u.length; ++j) {
      alias E = typeof(u[j]);
      _uvm__auto_build!(T, E, I)(t, u[j], indices ~ cast(uint) j);
    }
  }
  else {
    string name = __traits(identifier, T.tupleof[I]);
    foreach(i; indices) {
      name ~= "[" ~ i.to!string ~ "]";
    }
    if(u is null &&
       (! isAbstract) &&  // class is abstract
       (! noAutoAttr) &&  // make sure that UVM_NO_AUTO is not present
       (is_active ||	  // build everything if the agent is active
	(! isActiveAttr))) { // build the element if not and active element
      static if(is(U: uvm_component)) {
	u = U.type_id.create(name, t);
      }
      else if(is(U: uvm_port_base!IF, IF)) {
	u = new U(name, t);
      }
      else {
	static assert("Support only for uvm_component and uvm_port_base");
      }
    }
    // provide an ID to all the components that are not null
    if(u !is null) {
      static if(is(U: uvm_component)) {
	u.set_id();
      }
    }
  }
  static if(N.length > 0) {
    enum J = N[0];
    alias V = typeof(t.tupleof[J]);
    _uvm__auto_build!(T, V, N)(t, t.tupleof[J], []);
  }
}

// void _uvm__auto_build_iterate(T, U, size_t I, N...)(T t, ref U u,
// 						    uint indices[]) {
//   static if(isArray!U) {
//     for(size_t j = 0; j < u.length; ++j) {
//       alias E = typeof(u[j]);
//       _uvm__auto_build_iterate!(T, E, I)(t, u[j], indices ~ cast(uint) j);
//     }
//   }
//   else {
//     if(u !is null &&
//        (! u._uvm__auto_build_done)) {
//       u._uvm__auto_build_done(true);
//       u._uvm__auto_build();
//     }
//   }
//   static if(N.length > 0) {
//     enum J = N[0];
//     alias V = typeof(t.tupleof[J]);
//     _uvm__auto_build_iterate!(T, V, N)(t, t.tupleof[J]);
//   }
// }

void _uvm__auto_elab(size_t I=0, T, N...)(T t)
  if(is(T : uvm_component) && is(T == class)) {
    // pragma(msg, N);
    static if(I < t.tupleof.length) {
      alias M=typeof(t.tupleof[I]);
      static if(_uvm__is_member_component!M) {
	_uvm__auto_elab!(I+1, T, N, I)(t);
      }
      else {
	_uvm__auto_elab!(I+1, T, N)(t);
      }
    }
    else {
      // first elab these
      static if(N.length > 0) {
	alias U = typeof(t.tupleof[N[0]]);
	_uvm__auto_elab!(T, U, N)(t, t.tupleof[N[0]]);
      }
      // then go over the base object
      static if(is(T B == super)
		&& is(B[0]: uvm_component)
		&& is(B[0] == class)
		&& (! is(B[0] == uvm_component))
		&& (! is(B[0] == uvm_root))) {
	B[0] b = t;
	_uvm__auto_elab!(0, B[0])(b);
      }
      // and finally iterate over the children
      static if(N.length > 0) {
      	_uvm__auto_elab_iterate!(T, U, N)(t, t.tupleof[N[0]]);
      }
    }
  }

void _uvm__auto_elab_iterate(T, U, size_t I, N...)(T t, ref U u,
						   uint[] indices = []) {
  static if(isArray!U) {
    for(size_t j = 0; j < u.length; ++j) {
      alias E = typeof(u[j]);
      _uvm__auto_elab_iterate!(T, E, I)(t, u[j], indices ~ cast(uint) j);
    }
  }
  else {
    if(u !is null &&
       (! u._uvm__auto_elab_done)) {
      u._uvm__auto_elab_done(true);
      u._uvm__auto_elab();
    }
  }
  static if(N.length > 0) {
    enum J = N[0];
    alias V = typeof(t.tupleof[J]);
    _uvm__auto_elab_iterate!(T, V, N)(t, t.tupleof[J]);
  }
}

void _uvm__auto_elab(T, U, size_t I, N...)(T t, ref U u,
					    uint[] indices = []) {

  // the top level we start with should also get an id
  t.set_id();
  static if(isArray!U) {
    for(size_t j = 0; j < u.length; ++j) {
      alias E = typeof(u[j]);
      _uvm__auto_elab!(T, E, I)(t, u[j], indices ~ cast(uint) j);
    }
  }
  else {
    // string name = __traits(identifier, T.tupleof[I]);
    // foreach(i; indices) {
    //   name ~= "[" ~ i.to!string ~ "]";
    // }
    // provide an ID to all the components that are not null
    auto linfo = _esdl__get_parallelism!(I, T)(t);
    _uvm__config_parallelism(u, linfo);
    if(u !is null) {
      u.set_id();
    }
  }
  static if(N.length > 0) {
    enum J = N[0];
    alias V = typeof(t.tupleof[J]);
    _uvm__auto_elab!(T, V, N)(t, t.tupleof[J]);
  }
}

void _uvm__config_parallelism(T)(T t, ref parallelize linfo)
  if(is(T : uvm_component) && is(T == class)) {

    if(linfo.isUndefined) {
      linfo = _esdl__get_parallelism(t);
    }
    
    ParConfig pconf;
    parallelize pinfo;
    assert(t !is null);
    if(t.get_parent !is null) {
      pconf = t.get_parent._esdl__getParConfig;
      pinfo = t.get_parent._par__info;
    }

    if(t.get_parent is null ||
       pinfo._parallel == ParallelPolicy._UNDEFINED_) {
      // the parent had no parallel info
      // get it from RootEntity
      pinfo = Process.self().getParentEntity()._esdl__getParInfo();
      pconf = Process.self().getParentEntity()._esdl__getParConfig();
    }

    parallelize par__info;
    ParConfig   par__conf;
    
    if(linfo._parallel == ParallelPolicy._UNDEFINED_) {
      // no parallelize attribute. take hier information
      if(pinfo._parallel == ParallelPolicy.SINGLE) {
	par__info._parallel = ParallelPolicy.INHERIT;
      }
      else {
	par__info = pinfo;
      }
    }
    else {
      par__info = linfo;
    }

    if(par__info._parallel == ParallelPolicy.INHERIT) {
      par__conf = pconf;
    }
    else {
      // UDP @parallelize without argument
      auto nthreads = getRootEntity.getNumPoolThreads();
      if(par__info._poolIndex != uint.max) {
	assert(par__info._poolIndex < nthreads);
	par__conf = new ParConfig(par__info._poolIndex);
      }
      else {
	par__conf = new ParConfig(t._esdl__parComponentId() % nthreads);
      }
    }

    t._esdl__parConfig = par__conf;
    t._par__info = par__info;
  }



private template findUvmAttr(size_t I, alias S, A...) {
  static if(I < A.length) {
    static if(is(typeof(A[I]) == typeof(S)) && A[I] == S) {
      enum bool findUvmAttr = true;
    }
    else {
      enum bool findUvmAttr = findUvmAttr!(I+1, S, A);
    }
  }
  else {
    enum bool findUvmAttr = false;
  }
}
