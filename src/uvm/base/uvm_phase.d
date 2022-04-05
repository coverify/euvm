//
//----------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2011-2012 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2012-2017 Cisco Systems, Inc.
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2010-2014 Synopsys, Inc.
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

// typedef class uvm_sequencer_base;

// typedef class uvm_domain;
// typedef class uvm_task_phase;


//------------------------------------------------------------------------------
//
// Section -- NODOCS -- Phasing Definition classes
//
//------------------------------------------------------------------------------
//
// The following class are used to specify a phase and its implied functionality.
//
  

module uvm.base.uvm_phase;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_objection: uvm_objection;
import uvm.base.uvm_callback: uvm_callback, uvm_callbacks, uvm_register_cb;
import uvm.base.uvm_object_globals: uvm_core_state, m_uvm_core_state;
import uvm.base.uvm_domain: uvm_domain;
import uvm.base.uvm_task_phase: uvm_task_phase;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_scope;

import uvm.base.uvm_object_globals: uvm_phase_type, uvm_phase_state, uvm_wait_op, uvm_verbosity;

import uvm.meta.misc;
import uvm.meta.mailbox;
import uvm.meta.mcd;

import esdl.base.core: waitDelta, wait, Fork, abortForks, getRootEntity,
  sleep, fork;
import esdl.data.time;
import esdl.data.sync;

import std.string: format;
import std.conv: to;
import esdl.base.core: Process;
import esdl.data.queue;

import esdl.rand.misc: rand;


//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_phase
//
//------------------------------------------------------------------------------
//
// This base class defines everything about a phase: behavior, state, and context.
//
// To define behavior, it is extended by UVM or the user to create singleton
// objects which capture the definition of what the phase does and how it does it.
// These are then cloned to produce multiple nodes which are hooked up in a graph
// structure to provide context: which phases follow which, and to hold the state
// of the phase throughout its lifetime.
// UVM provides default extensions of this class for the standard runtime phases.
// VIP Providers can likewise extend this class to define the phase functor for a
// particular component context as required.
//
// This base class defines everything about a phase: behavior, state, and context.
//
// To define behavior, it is extended by UVM or the user to create singleton
// objects which capture the definition of what the phase does and how it does it.
// These are then cloned to produce multiple nodes which are hooked up in a graph
// structure to provide context: which phases follow which, and to hold the state
// of the phase throughout its lifetime.
// UVM provides default extensions of this class for the standard runtime phases.
// VIP Providers can likewise extend this class to define the phase functor for a
// particular component context as required.
//
// *Phase Definition*
//
// Singleton instances of those extensions are provided as package variables.
// These instances define the attributes of the phase (not what state it is in)
// They are then cloned into schedule nodes which point back to one of these
// implementations, and calls its virtual task or function methods on each
// participating component.
// It is the base class for phase functors, for both predefined and
// user-defined phases. Per-component overrides can use a customized imp.
//
// To create custom phases, do not extend uvm_phase directly: see the
// three predefined extended classes below which encapsulate behavior for
// different phase types: task, bottom-up function and top-down function.
//
// Extend the appropriate one of these to create a uvm_YOURNAME_phase class
// (or YOURPREFIX_NAME_phase class) for each phase, containing the default
// implementation of the new phase, which must be a uvm_component-compatible
// delegate, and which may be a ~null~ implementation. Instantiate a singleton
// instance of that class for your code to use when a phase handle is required.
// If your custom phase depends on methods that are not in uvm_component, but
// are within an extended class, then extend the base YOURPREFIX_NAME_phase
// class with parameterized component class context as required, to create a
// specialized functor which calls your extended component class methods.
// This scheme ensures compile-safety for your extended component classes while
// providing homogeneous base types for APIs and underlying data structures.
//
// *Phase Context*
//
// A schedule is a coherent group of one or mode phase/state nodes linked
// together by a graph structure, allowing arbitrary linear/parallel
// relationships to be specified, and executed by stepping through them in
// the graph order.
// Each schedule node points to a phase and holds the execution state of that
// phase, and has optional links to other nodes for synchronization.
//
// The main operations are: construct, add phases, and instantiate
// hierarchically within another schedule.
//
// Structure is a DAG (Directed Acyclic Graph). Each instance is a node
// connected to others to form the graph. Hierarchy is overlaid with m_parent.
// Each node in the graph has zero or more successors, and zero or more
// predecessors. No nodes are completely isolated from others. Exactly
// one node has zero predecessors. This is the root node. Also the graph
// is acyclic, meaning for all nodes in the graph, by following the forward
// arrows you will never end up back where you started but you will eventually
// reach a node that has no successors.
//
// *Phase State*
//
// A given phase may appear multiple times in the complete phase graph, due
// to the multiple independent domain feature, and the ability for different
// VIP to customize their own phase schedules perhaps reusing existing phases.
// Each node instance in the graph maintains its own state of execution.
//
// *Phase Handle*
//
// Handles of this type uvm_phase are used frequently in the API, both by
// the user, to access phasing-specific API, and also as a parameter to some
// APIs. In many cases, the singleton phase handles can be
// used (eg. <uvm_run_phase::get()>) in APIs. For those APIs that need to look
// up that phase in the graph, this is done automatically.

// @uvm-ieee 1800.2-2020 auto 9.3.1.2
class uvm_phase: uvm_object, rand.disable
{
  import uvm.base.uvm_component: uvm_component;
  import esdl.base.core: Signal, wait;


  mixin (uvm_sync_string);
  mixin (uvm_scope_sync_string);

  static class uvm_scope: uvm_scope_base
  {
    @uvm_none_sync
    private bool[uvm_phase] _m_executing_phases;
    // private static mailbox #(uvm_phase) m_phase_hopper = new();
    @uvm_immutable_sync
    private Mailbox!uvm_phase _m_phase_hopper;
    @uvm_immutable_sync
    private immutable bool _m_phase_trace;
    @uvm_immutable_sync
    private immutable bool _m_use_ovm_run_semantic;

    @uvm_private_sync
    private int            _m_default_max_ready_to_end_iters = 20;    // 20 is the initial value defined by 1800.2-2020 9.3.1.3.5

    this() {
      import uvm.base.uvm_cmdline_processor;
      synchronized (this) {
	_m_phase_hopper = new Mailbox!uvm_phase();

	uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
	string val;

	if (clp.get_arg_value("+UVM_PHASE_TRACE", val)) {
	  _m_phase_trace = true;	// once variable
	}
	else {
	  _m_phase_trace = false;
	}

	if (clp.get_arg_value("+UVM_USE_OVM_RUN_SEMANTIC", val)) {
	  _m_use_ovm_run_semantic = true; // once variable
	}
	else {
	  _m_use_ovm_run_semantic = false;
	}

      }
    }
  }

  void add_executing_phase(uvm_phase phase) {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m_executing_phases[phase] = true;
    }
  }
  void rem_executing_phase(uvm_phase phase) {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m_executing_phases.remove(phase);
    }
  }
  uvm_phase[] get_executing_phases() {
    synchronized (_uvm_scope_inst) {
      import std.algorithm.sorting;
      auto phases = _uvm_scope_inst._m_executing_phases.keys;
      sort(phases);
      return phases;
    }
  }
    
  
  // not required in vlang
  //`uvm_object_utils(uvm_phase)

  mixin uvm_register_cb!(uvm_phase_cb);

  //--------------------
  // Group -- NODOCS -- Construction
  //--------------------


  // @uvm-ieee 1800.2-2020 auto 9.3.1.3.1
  this(string name="uvm_phase",
       uvm_phase_type phase_type=uvm_phase_type.UVM_PHASE_SCHEDULE,
       uvm_phase parent=null) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      super(name);
      _m_state = new WithEvent!uvm_phase_state("_m_state");
      _m_jump_fwd = new WithEvent!bool("_m_jump_fwd");
      _m_jump_bkwd = new WithEvent!bool("_m_jump_bkwd");
      _m_premature_end = new WithEvent!bool("_m_premature_end");

      _m_phase_type = phase_type;

      // The common domain is the only thing that initializes m_state.  All
      // other states are initialized by being 'added' to a schedule.
      if ((name == "common") &&
	  (phase_type == uvm_phase_type.UVM_PHASE_DOMAIN)) {
	_m_state = uvm_phase_state.UVM_PHASE_DORMANT;
      }
   
      _m_run_count = 0;
      _m_parent = parent;


      if (parent is null && (phase_type is uvm_phase_type.UVM_PHASE_SCHEDULE ||
			    phase_type is uvm_phase_type.UVM_PHASE_DOMAIN )) {
	//_m_parent = this;
	_m_end_node = new uvm_phase(name ~ "_end", uvm_phase_type.UVM_PHASE_TERMINAL, this);
	this.add_successor(_m_end_node);
	_m_end_node.add_predecessor(this);
      }
      _max_ready_to_end_iters = get_default_max_ready_to_end_iterations();

      _m_nba.initialize();
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.3.2
  final uvm_phase_type get_phase_type() {
    synchronized (this) {
      return _m_phase_type;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.3.3
  void set_max_ready_to_end_iterations(int max) {
    synchronized (this) {
      _max_ready_to_end_iters = max;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 9.3.1.3.4
  int get_max_ready_to_end_iterations() {
    synchronized (this) {
      return _max_ready_to_end_iters;
    }
  }

  // @uvm-ieee 1800.2-2020 auto 9.3.1.3.5
  static void set_default_max_ready_to_end_iterations(int max) {
    synchronized (_uvm_scope_inst) {
      _uvm_scope_inst._m_default_max_ready_to_end_iters = max;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.3.6
  static int get_default_max_ready_to_end_iterations() {
    synchronized (_uvm_scope_inst) {
      return _uvm_scope_inst._m_default_max_ready_to_end_iters;
    }
  }
  
  //-------------
  // Group -- NODOCS -- State
  //-------------


  // @uvm-ieee 1800.2-2020 auto 9.3.1.4.1
  final uvm_phase_state get_state() {
    synchronized (this) {
      return _m_state;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.4.2
  final int get_run_count() {
    synchronized (this) {
      return _m_run_count;
    }
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.4.3
  final uvm_phase find_by_name(string name, bool stay_in_scope = true) {
    // TBD full search
    //$display({"\nFIND node named '", name,"' within ", get_name()," (scope ", m_phase_type.name(),")", (stay_in_scope) ? " staying within scope" : ""});
    if (get_name() == name) {
      return this;
    }
    uvm_phase find_by_name_ = m_find_predecessor_by_name(name, stay_in_scope, this);
    if (find_by_name_ is null) {
      find_by_name_ = m_find_successor_by_name(name, stay_in_scope, this);
    }
    return find_by_name_;
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.4.4
  uvm_phase find(uvm_phase phase, bool stay_in_scope = true) {
    // TBD full search
    //$display({"\nFIND node '", phase.get_name(),"' within ", get_name()," (scope ", m_phase_type.name(),")", (stay_in_scope) ? " staying within scope" : ""});
    synchronized (this) {
      if (phase is _m_imp || phase is this) {
	return phase;
      }
    }
    uvm_phase find_ = m_find_predecessor(phase, stay_in_scope, this);
    if (find_ is null) {
      find_ = m_find_successor(phase, stay_in_scope, this);
    }
    return find_;
  }


  /////////////////////////////////////////////////////////////////
  // This function is named "is" in SV version, but since "is" is a
  // keyword in dlang, we name this function "is_same" here.
  /////////////////////////////////////////////////////////////////

  // @uvm-ieee 1800.2-2020 auto 9.3.1.4.5
  final bool is_same(uvm_phase phase) {
    synchronized (this) {
      return (_m_imp is phase || this is phase);
    }
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.4.6
  final bool is_before(uvm_phase phase) {
    synchronized (this) {
      //$display("this=%s is before phase=%s?", get_name(), phase.get_name());
      // TODO: add support for 'stay_in_scope=1' functionality
      return (!is_same(phase) &&
	      m_find_successor(phase, false, this) !is null);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.4.7
  final bool is_after(uvm_phase phase) {
    synchronized (this) {
      //$display("this=%s is after phase=%s?", get_name(), phase.get_name());
      // TODO: add support for 'stay_in_scope=1' functionality
      return (!is_same(phase) &&
	      m_find_predecessor(phase, false, this) !is null);
    }
  }


  //-----------------
  // Group -- NODOCS -- Callbacks
  //-----------------


  // @uvm-ieee 1800.2-2020 auto 9.3.1.5.1
  void exec_func(uvm_component comp, uvm_phase phase) { }


  // task

  // @uvm-ieee 1800.2-2020 auto 9.3.1.5.2
  void exec_task(uvm_component comp, uvm_phase phase) { }


  //----------------
  // Group -- NODOCS -- Schedule
  //----------------


  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.1
  final void add(uvm_phase phase,
		 uvm_phase with_phase = null,
		 uvm_phase after_phase = null,
		 uvm_phase before_phase = null,
		 uvm_phase start_with_phase = null,
		 uvm_phase end_with_phase = null) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;

    uvm_phase new_node, begin_node, end_node, tmp_node;
    uvm_phase_state_change state_chg;
    if (phase is null) {
      uvm_fatal("PH/NULL", "add: phase argument is null");
    }

    if (with_phase !is null && with_phase.get_phase_type() == uvm_phase_type.UVM_PHASE_IMP) {
      string nm = with_phase.get_name();
      with_phase = find(with_phase);
      if (with_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find with_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if (before_phase !is null &&
       before_phase.get_phase_type() == uvm_phase_type.UVM_PHASE_IMP) {
      string nm = before_phase.get_name();
      before_phase = find(before_phase);
      if (before_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find before_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if (after_phase !is null &&
       after_phase.get_phase_type() == uvm_phase_type.UVM_PHASE_IMP) {
      string nm = after_phase.get_name();
      after_phase = find(after_phase);
      if (after_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find after_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if (start_with_phase !is null &&
	start_with_phase.get_phase_type() == uvm_phase_type.UVM_PHASE_IMP) {
      string nm = start_with_phase.get_name();
      start_with_phase = find(start_with_phase);
      if (start_with_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find start_with_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if (end_with_phase !is null &&
	end_with_phase.get_phase_type() == uvm_phase_type.UVM_PHASE_IMP) {
      string nm = end_with_phase.get_name();
      end_with_phase = find(end_with_phase);
      if (end_with_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find end_with_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if (((with_phase is null ? 0 : 1) + (after_phase is null ? 0 : 1) +
	 (start_with_phase is null ? 0 : 1)) > 1) {
      uvm_fatal("PH_BAD_ADD",
		"only one of with_phase/after_phase/start_with_phase may be specified as they all specify predecessor");
    }

    if (((with_phase is null ? 0 : 1) + (before_phase is null ? 0 : 1) +
	 (end_with_phase is null ? 0 : 1)) > 1) {
      uvm_fatal("PH_BAD_ADD",
		"only one of with_phase/before_phase/end_with_phase" ~
		" may be specified as they all specify successor");
    }

    if (before_phase is this ||
       after_phase is m_end_node ||
       with_phase is m_end_node ||
       start_with_phase is m_end_node ||
       end_with_phase is m_end_node) {
      uvm_fatal("PH_BAD_ADD",
		"cannot add before begin node, after end node, or " ~
		"with end nodes");
    }

    if (before_phase !is null && after_phase !is null) {
      if (! after_phase.is_before(before_phase)) {
	uvm_fatal("PH_BAD_ADD", "Phase '" ~ before_phase.get_name() ~
		  "' is not before phase '" ~ after_phase.get_name() ~ "'");
      }
    }

    if (before_phase !is null && start_with_phase !is null) {
      if (! start_with_phase.is_before(before_phase)) {
	uvm_fatal("PH_BAD_ADD", "Phase '" ~ before_phase.get_name() ~
		  "' is not before phase '" ~
		  start_with_phase.get_name() ~ "'");
      }
    }

    if (end_with_phase !is null && after_phase !is null) {
      if (! after_phase.is_before(end_with_phase)) {
	uvm_fatal("PH_BAD_ADD", "Phase '" ~ end_with_phase.get_name() ~
		  "' is not before phase '" ~ after_phase.get_name() ~ "'");
      }
    }

    // If we are inserting a new "leaf node"
    if (phase.get_phase_type() == uvm_phase_type.UVM_PHASE_IMP) {
      new_node = new uvm_phase(phase.get_name(), uvm_phase_type.UVM_PHASE_NODE, this);
      new_node.m_imp = phase;
      begin_node = new_node;
      end_node = new_node;

    }
    // We are inserting an existing schedule
    else {
      begin_node = phase;
      end_node   = phase.m_end_node;
      phase.m_parent = this;
    }

    // If 'with_phase' is us, then insert node in parallel
    /*
      if (with_phase is this) {
      after_phase = this;
      before_phase = m_end_node;
      }
    */

    // If no before/after/with specified, insert at end of this schedule
    if (with_phase is null && after_phase is null &&
	before_phase is null && start_with_phase is null &&
	end_with_phase is null) {
      before_phase = m_end_node;
    }

    if (m_phase_trace) {
      uvm_phase_type typ = phase.get_phase_type();
      uvm_info("PH/TRC/ADD_PH",
	       get_name() ~ " (" ~ m_phase_type.to!string ~
	       ") ADD_PHASE: phase=" ~ phase.get_full_name() ~ " (" ~
	       typ.to!string ~ ", inst_id=" ~
	       format("%0d", phase.get_inst_id()) ~ ")" ~
	       " with_phase=" ~   ((with_phase is null)   ? "null" :
				   with_phase.get_name()) ~
	       " start_with_phase=" ~ ((start_with_phase is null) ? "null" :
				       start_with_phase.get_name()) ~ 
	       " end_with_phase=" ~ ((end_with_phase is null) ? "null" :
				     end_with_phase.get_name()) ~
	       " after_phase=" ~  ((after_phase is null)  ? "null" :
				   after_phase.get_name()) ~
	       " before_phase=" ~ ((before_phase is null) ? "null" :
				   before_phase.get_name()) ~
	       " new_node=" ~     ((new_node is null)     ? "null" :
				   (new_node.get_name() ~ " inst_id=" ~
				    format("%0d", new_node.get_inst_id()))) ~
	       " begin_node=" ~   ((begin_node is null)   ? "null" :
				   begin_node.get_name())  ~
	       " end_node=" ~     ((end_node is null)     ? "null" :
				   end_node.get_name()),
	       uvm_verbosity.UVM_DEBUG);
    }


    // 
    // INSERT IN PARALLEL WITH 'WITH' PHASE
    if (with_phase !is null) {
      // all pre-existing predecessors to with_phase are predecessors to the new phase
      begin_node.cpy_predecessors(with_phase);
      foreach (pred; with_phase.get_predecessors()) {
	pred.add_successor(begin_node);
      }
      // all pre-existing successors to with_phase are successors to this phase
      end_node.cpy_successors(with_phase);
      foreach (succ; with_phase.get_successors()) {
	succ.add_predecessor(end_node);
      }
    }

    if (start_with_phase !is null) {
      // all pre-existing predecessors to start_with_phase are predecessors to the new phase
      begin_node.cpy_predecessors(start_with_phase);
      foreach (pred; start_with_phase.get_predecessors()) {
	pred.add_successor(begin_node);
      }
      // if not otherwise specified, successors for the new phase are the successors to the end of this schedule
      if (before_phase is null && end_with_phase is null) {
	end_node.cpy_successors(m_end_node);
	foreach (succ; m_end_node.get_successors()) {
	  succ.add_predecessor(end_node);
	}
      }
    }

    if (end_with_phase !is null) {
      // all pre-existing successors to end_with_phase are successors to the new phase
      end_node.cpy_successors(end_with_phase);
      foreach (succ; end_with_phase.get_successors()) {
	succ.add_predecessor(end_node);
      }
      // if not otherwise specified, predecessors for the new phase are the predecessors to the start of this schedule
      if (after_phase is null && start_with_phase is null) {
	begin_node.cpy_predecessors(this);
	foreach (pred; this.get_predecessors()) {
	  pred.add_successor(begin_node);
	}
      }
    }

    // INSERT BEFORE PHASE
    if (before_phase !is null) {
      // unless predecessors to this phase are otherwise specified, 
      // pre-existing predecessors to before_phase move to be predecessors to the new phase
      if (after_phase is null && start_with_phase is null) {
	foreach (pred; before_phase.get_predecessors()) {
	  pred.rem_successor(before_phase);
	  pred.add_successor(begin_node);
	}
	begin_node.cpy_predecessors(before_phase);
	before_phase.clr_predecessors();
      }
      // there is a special case if before and after used to be adjacent;
      // the new phase goes in-between them
      else if (before_phase.has_predecessor(after_phase)) {
	before_phase.rem_predecessor(after_phase);
      }

      // before_phase is now the sole successor of this phase
      before_phase.add_predecessor(end_node);
      end_node.clr_successors();
      end_node.add_successor(before_phase);
    }

    // INSERT AFTER PHASE
    if (after_phase !is null) {
      // unless successors to this phase are otherwise specified, 
      // pre-existing successors to after_phase are now successors to this phase
      if (before_phase is null && end_with_phase is null) {
	foreach (succ; after_phase.get_successors()) {
	  succ.rem_predecessor(after_phase);
	  succ.add_predecessor(end_node);
	}
	end_node.cpy_successors(after_phase);
	after_phase.clr_successors();
      }
      // there is a special case if before and after used to be adjacent;
      // the new phase goes in-between them
      else if (after_phase.has_successor(before_phase)) {
	after_phase.rem_successor(before_phase);
      }

      // after_phase is the sole predecessor of this phase 
      after_phase.add_successor(begin_node);
      begin_node.clr_predecessors();
      begin_node.add_predecessor(after_phase);
    }
  

    // Transition nodes to DORMANT state
    if (new_node is null) {
      tmp_node = phase;
    }
    else {
      tmp_node = new_node;
    }

    state_chg = uvm_phase_state_change.type_id.create(tmp_node.get_name());
    state_chg.m_phase = tmp_node;
    state_chg.m_jump_to = null;
    state_chg.m_prev_state = tmp_node.m_state;
    tmp_node.m_state = uvm_phase_state.UVM_PHASE_DORMANT;
    uvm_do_callbacks(cb => cb.phase_state_change(tmp_node, state_chg));
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.2
  final uvm_phase get_parent() {
    synchronized (this) {
      return _m_parent;
    }
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.3
  override string get_full_name() {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      // string dom; -- redundant in SV implementation
      if (m_phase_type == uvm_phase_type.UVM_PHASE_IMP) {
	return get_name();
      }
      string get_full_name_ = get_domain_name();
      string sch = get_schedule_name();
      if (sch != "") {
	get_full_name_ ~= "." ~ sch;
      }
      if (m_phase_type != uvm_phase_type.UVM_PHASE_DOMAIN &&
	 m_phase_type != uvm_phase_type.UVM_PHASE_SCHEDULE) {
	get_full_name_ ~= "." ~ get_name();
      }
      return get_full_name_;
    }
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.4
  final uvm_phase get_schedule(bool hier = false) {
    import uvm.base.uvm_object_globals;
    uvm_phase sched = this;
    if (hier) {
      while (sched.m_parent !is null &&
	    (sched.m_parent.get_phase_type() == uvm_phase_type.UVM_PHASE_SCHEDULE)) {
	sched = sched.m_parent;
      }
    }
    if (sched.m_phase_type == uvm_phase_type.UVM_PHASE_SCHEDULE) {
      return sched;
    }
    if (sched.m_phase_type == uvm_phase_type.UVM_PHASE_NODE) {
      auto parent = m_parent;
      if (parent !is null && parent.m_phase_type != uvm_phase_type.UVM_PHASE_DOMAIN) {
	return parent;
      }
    }
    return null;
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.5
  final string get_schedule_name(bool hier = 0) {
    import uvm.base.uvm_object_globals;
    uvm_phase sched = get_schedule(hier);
    if (sched is null) {
      return "";
    }
    string s = sched.get_name();
    while (sched.m_parent !is null && sched.m_parent !is sched &&
	  (sched.m_parent.get_phase_type() == uvm_phase_type.UVM_PHASE_SCHEDULE)) {
      sched = sched.m_parent;
      s = sched.get_name() ~ (s.length > 0 ? "." : "")  ~ s;
    }
    return s;
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.6
  final uvm_domain get_domain() {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    uvm_phase phase = this;
    while (phase !is null && phase.m_phase_type !is uvm_phase_type.UVM_PHASE_DOMAIN) {
      phase = phase.m_parent;
    }
    if (phase is null) { // no parent domain
      return null;
    }
    auto get_domain_ = cast (uvm_domain) phase;
    if (get_domain_ is null) {
      uvm_fatal("PH/INTERNAL", "get_domain: m_phase_type is DOMAIN but " ~
		"$cast to uvm_domain fails");
    }
    return get_domain_;
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.7
  final uvm_phase get_imp() {
    synchronized (this) {
      return _m_imp;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.8
  final string get_domain_name() {
    uvm_domain domain = get_domain();
    if (domain is null) {
      return "unknown";
    }
    return domain.get_name();
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.9
  final void get_adjacent_predecessor_nodes(out uvm_phase[] pred) {
    import uvm.base.uvm_object_globals;

    bool done;
    bool[uvm_phase] predecessors;

    // Get all predecessors (including TERMINALS, SCHEDULES, etc.)
    foreach (p; get_predecessors()) {
      predecessors[p] = true;
    }

    // Replace any terminal / schedule nodes with their predecessors,
    // recursively.
    do {
      done = true;
      foreach (p, unused; predecessors) {
	if (p.get_phase_type() != uvm_phase_type.UVM_PHASE_NODE) {
	  predecessors.remove(p);
	  foreach (next_p; p.get_predecessors()) {
	    predecessors[next_p] = true;
	  }
	  done = false;
	}
      }
    } while (done is false);

    foreach (p, unused; predecessors) {
      pred ~= p;
    }
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.6.10
  final void get_adjacent_successor_nodes(out uvm_phase[] succ) {
    import uvm.base.uvm_object_globals;
    bool done;
    bool[uvm_phase] successors;

    // Get all successors (including TERMINALS, SCHEDULES, etc.)
    foreach (s; get_successors()) {
      successors[s] = true;
    }

    // Replace any terminal / schedule nodes with their successors,
    // recursively.
    do {
      done = true;
      foreach (s, unused; successors) {
	if (s.get_phase_type() != uvm_phase_type.UVM_PHASE_NODE) {
	  successors.remove(s);
	  foreach (next_s; s.get_successors()) {
	    successors[next_s] = true;
	  }
	  done = false;
	}
      }
    } while (done is false); 

    foreach (s, unused; successors) {
      succ ~= s;
    }
  }


  //-----------------------
  // Group -- NODOCS -- Phase Done Objection
  //-----------------------
  //
  // Task-based phase nodes within the phasing graph provide a <uvm_objection>
  // based interface for prolonging the execution of the phase.  All other
  // phase types do not contain an objection, and will report a fatal error
  // if the user attempts to ~raise~, ~drop~, or ~get_objection_count~.
   
  // Function- m_report_null_objection
  // Simplifies the reporting of ~null~ objection errors
  void m_report_null_objection(uvm_object obj,
			       string description,
			       int count,
			       string action) {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    string m_obj_name = (obj is null) ? "uvm_top" : obj.get_full_name();
   
    string m_action;
    if ((action == "raise") || (action == "drop")) {
      if (count != 1) {
        m_action = format("%s %0d objections", action, count);
      }
      else {
        m_action = format("%s an objection", action);
      }
    }
    else if (action == "get_objection_count") {
      m_action = "call get_objection_count";
    }

    string m_addon;
    if (this.get_phase_type() == uvm_phase_type.UVM_PHASE_IMP) {
      m_addon = " (This is a UVM_PHASE_IMP, you have to query the" ~
	" schedule to find the UVM_PHASE_NODE)";
    }
   
    uvm_error("UVM/PH/NULL_OBJECTION",
	      format("'%s' attempted to %s on '%s', however '%s' is" ~
		     " not a task-based phase node! %s",
		     m_obj_name,
		     m_action,
		     get_name(),
		     get_name(),
		     m_addon));
  }
                        
   
  // @uvm-ieee 1800.2-2020 auto 9.3.1.7.2
  final void raise_objection(uvm_object obj,
			     string description="",
			     int count=1) {
    uvm_objection phase_done = get_objection();
    if (phase_done !is null) {
      phase_done.raise_objection(obj, description, count);
    }
    else {
      m_report_null_objection(obj, description, count, "raise");
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.7.3
  final void drop_objection(uvm_object obj,
			    string description="",
			    int count=1) {
    uvm_objection phase_done = get_objection();
    if (phase_done !is null) {
      phase_done.drop_objection(obj, description, count);
    }
    else {
      m_report_null_objection(obj, description, count, "drop");
    }
  }



  // @uvm-ieee 1800.2-2020 auto 9.3.1.7.4
  int get_objection_count (uvm_object obj=null) {
    uvm_objection phase_done = get_objection();
    if (phase_done !is null) {
      return phase_done.get_objection_count(obj);
    }
    else {
      m_report_null_objection(obj, "" , 0, "get_objection_count");
      return 0;
    }
  }


  //-----------------------
  // Group -- NODOCS -- Synchronization
  //-----------------------
  // The functions 'sync' and 'unsync' add soft sync relationships between nodes
  //
  // Summary of usage:
  //| my_phase.sync(.target(domain)
  //|              [,.phase(phase)[,.with_phase(phase)]]);
  //| my_phase.unsync(.target(domain)
  //|                [,.phase(phase)[,.with_phase(phase)]]);
  //
  // Components in different schedule domains can be phased independently or in sync
  // with each other. An API is provided to specify synchronization rules between any
  // two domains. Synchronization can be done at any of three levels:
  //
  // - the domain's whole phase schedule can be synchronized
  // - a phase can be specified, to sync that phase with a matching counterpart
  // - or a more detailed arbitrary synchronization between any two phases
  //
  // Each kind of synchronization causes the same underlying data structures to
  // be managed. Like other APIs, we use the parameter dot-notation to set
  // optional parameters.
  //
  // When a domain is synced with another domain, all of the matching phases in
  // the two domains get a 'with' relationship between them. Likewise, if a domain
  // is unsynched, all of the matching phases that have a 'with' relationship have
  // the dependency removed. It is possible to sync two domains and then just
  // remove a single phase from the dependency relationship by unsyncing just
  // the one phase.



  // @uvm-ieee 1800.2-2020 auto 9.3.1.8.1
  final void sync(uvm_domain target,
		  uvm_phase phase = null,
		  uvm_phase with_phase = null) {
    import uvm.base.uvm_globals;
    if (!this.is_domain()) {
      uvm_fatal("PH_BADSYNC","sync() called from a non-domain phase " ~
		"schedule node");
    }
    else if (target is null) {
      uvm_fatal("PH_BADSYNC","sync() called with a null target domain");
    }
    else if (!target.is_domain()) {
      uvm_fatal("PH_BADSYNC","sync() called with a non-domain phase " ~
		"schedule node as target");
    }
    else if (phase is null && with_phase !is null) {
      uvm_fatal("PH_BADSYNC","sync() called with null phase and non-null " ~
		"with phase");
    }
    else if (phase is null) {
      // whole domain sync - traverse this domain schedule from begin to end node and sync each node
      int[uvm_phase] visited;
      Queue!uvm_phase queue;
      queue.pushBack(this);
      visited[this] = true;
      while (queue.length !is 0) {
	uvm_phase node;
	node = queue.front();
	queue.removeFront();
	if (node.m_imp !is null) {
	  sync(target, node.m_imp);
	}
	foreach (succ; node.get_successors()) {
	  if (succ !in visited) {
	    queue.pushBack(succ);
	    visited[succ] = true;
	  }
	}
      }
    }
    else {
      // single phase sync
      // this is a 2-way ('with') sync and we check first in case it
      // is already there
      if (with_phase is null) with_phase = phase;
      uvm_phase from_node = find(phase);
      uvm_phase to_node = target.find(with_phase);
      if (from_node is null || to_node is null) return;
      from_node.add_sync(to_node);
      to_node.add_sync(from_node);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.8.2
  final void unsync(uvm_domain target,
		    uvm_phase phase = null,
		    uvm_phase with_phase = null) {
    import uvm.base.uvm_globals;
    if (!this.is_domain()) {
      uvm_fatal("PH_BADSYNC","unsync() called from a non-domain phase " ~
		"schedule node");
    }
    else if (target is null) {
      uvm_fatal("PH_BADSYNC","unsync() called with a null target domain");
    }
    else if (!target.is_domain()) {
      uvm_fatal("PH_BADSYNC","unsync() called with a non-domain phase " ~
		"schedule node as target");
    }
    else if (phase is null && with_phase !is null) {
      uvm_fatal("PH_BADSYNC","unsync() called with null phase and non-null " ~
		"with phase");
    }
    else if (phase is null) {
      // whole domain unsync - traverse this domain schedule from begin to end node and unsync each node
      int[uvm_phase] visited;
      Queue!uvm_phase queue;
      queue.pushBack(this);
      visited[this] = true;
      while (queue.length !is 0) {
	uvm_phase node = queue.front();
	queue.removeFront();
	if (node.m_imp !is null) unsync(target, node.m_imp);
	foreach (succ; node.get_successors()) {
	  if (succ !in visited) {
	    queue.pushBack(succ);
	    visited[succ] = true;
	  }
	}
      }
    }
    else {
      // single phase unsync
      // this is a 2-way ('with') sync and we check first in case it is already there
      if (with_phase is null) {
	with_phase = phase;
      }
      uvm_phase from_node = find(phase);
      uvm_phase to_node = target.find(with_phase);
      if (from_node is null || to_node is null) {
	return;
      }
      // m_sync is a Queue of uvm_phase
      from_node.rem_sync(to_node);
      to_node.rem_sync(from_node);
    }
  }

  // task

  // @uvm-ieee 1800.2-2020 auto 9.3.1.8.3
  final void wait_for_state(uvm_phase_state state,
			    uvm_wait_op op = uvm_wait_op.UVM_EQ) {
    import uvm.base.uvm_object_globals;
    final switch (op) {
      // wait((state & m_state) !is 0);
    case uvm_wait_op.UVM_EQ:  while ((m_state.get & state) is 0)
	m_state.getEvent.wait();
      break;
      // wait((state & m_state) is 0);
    case uvm_wait_op.UVM_NE:  while ((m_state.get & state) !is 0)
	m_state.getEvent.wait();
      break;
      // wait(m_state <  state);
    case uvm_wait_op.UVM_LT:  while (m_state.get >= state)
	m_state.getEvent.wait();
      break;
      // wait(m_state <=  state);
    case uvm_wait_op.UVM_LTE: while (m_state.get > state)
	m_state.getEvent.wait();
      break;
      // wait(m_state >  state);
    case uvm_wait_op.UVM_GT:  while (m_state.get <= state)
	m_state.getEvent.wait();
      break;
      // wait(m_state >=  state);
    case uvm_wait_op.UVM_GTE: while (m_state.get < state)
	m_state.getEvent.wait();
      break;
    }
  }

  //---------------
  // Group -- NODOCS -- Jumping
  //---------------

  // Force phases to jump forward or backward in a schedule
  //
  // A phasing domain can execute a jump from its current phase to any other.
  // A jump passes phasing control in the current domain from the current phase
  // to a target phase. There are two kinds of jump scope:
  //
  // - local jump to another phase within the current schedule, back- or forwards
  // - global jump of all domains together, either to a point in the master
  //   schedule outwith the current schedule, or by calling jump_all()
  //
  // A jump preserves the existing soft synchronization, so the domain that is
  // ahead of schedule relative to another synchronized domain, as a result of
  // a jump in either domain, will await the domain that is behind schedule.
  //
  // *Note*: A jump out of the local schedule causes other schedules that have
  // the jump node in their schedule to jump as well. In some cases, it is
  // desirable to jump to a local phase in the schedule but to have all
  // schedules that share that phase to jump as well. In that situation, the
  // jump_all static function should be used. This function causes all schedules
  // that share a phase to jump to that phase.


  // @uvm-ieee 1800.2-2020 auto 9.3.1.9.1
  void jump(uvm_phase phase) {
    set_jump_phase(phase) ;
    end_prematurely();
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.9.2
  void set_jump_phase(uvm_phase phase) {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;

    if ((m_state.get <  uvm_phase_state.UVM_PHASE_STARTED) ||
       (m_state.get >  uvm_phase_state.UVM_PHASE_ENDED) )
      {
	uvm_error("JMPPHIDL", "Attempting to jump from phase \"" ~
		  get_name() ~  "\" which is not currently active " ~
		  "(current state is " ~ m_state.get.to!string ~  "). The " ~
		  "jump will not happen until the phase becomes active.");
      }

    // A jump can be either forward or backwards in the phase graph.
    // If the specified phase (name) is found in the set of predecessors
    // then we are jumping backwards.  If, on the other hand, the phase is in the set
    // of successors then we are jumping forwards.  If neither, then we
    // have an error.
    //
    // If the phase is non-existant and thus we don't know where to jump
    // we have a situation where the only thing to do is to uvm_report_fatal
    // and terminate_phase.  By calling this function the intent was to
    // jump to some other phase. So, continuing in the current phase doesn't
    // make any sense.  And we don't have a valid phase to jump to.  So we're done.

    uvm_phase d = m_find_predecessor(phase, false);
    if (d is null) {
      d = m_find_successor(phase, false);
      if (d is null) {
	uvm_fatal("PH_BADJUMP",
		  format("phase %s is neither a predecessor or " ~
			 "successor of phase %s or is non-existant, " ~
			 "so we cannot jump to it. Phase control " ~
			 "flow is now undefined so the simulation " ~
			 "must terminate", phase.get_name(), get_name()));
      }
      else {
	m_jump_fwd = true;
	uvm_info("PH_JUMPF", format("jumping forward to phase %s",
				    phase.get_name()), uvm_verbosity.UVM_DEBUG);
      }
    }
    else {
      m_jump_bkwd = true;
      uvm_info("PH_JUMPB", format("jumping backward to phase %s",
				  phase.get_name()), uvm_verbosity.UVM_DEBUG);
    }

    m_jump_phase = d;
  }
  

  // @uvm-ieee 1800.2-2020 auto 9.3.1.9.3
  void end_prematurely() {
    synchronized (this) {
      _m_premature_end = true;
    }
  }

  // Function- jump_all
  //
  // Make all schedules jump to a specified ~phase~, even if the jump target is local.
  // The jump happens to all phase schedules that contain the jump-to ~phase~,
  // i.e. a global jump.
  //
  final void jump_all(uvm_phase phase) {
    import uvm.base.uvm_globals;
    uvm_warning("NOTIMPL","uvm_phase.jump_all is not implemented and " ~
		"has been replaced by uvm_domain.jump_all");
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.1.9.4
  final uvm_phase get_jump_target() {
    synchronized (this) {
      return _m_jump_phase;
    }
  }

  //--------------------------
  // Internal - Implementation
  //--------------------------

  // Implementation - Construction
  //------------------------------

  // m_phase_type is set in the constructor and is not changed after that
  @uvm_immutable_sync
  private uvm_phase_type _m_phase_type;

  @uvm_protected_sync
  private uvm_phase _m_parent; // our 'schedule' node [or points 'up' one level]

  @uvm_public_sync
  private uvm_phase _m_imp; // phase imp to call when we execute this node

  // Implementation - State
  //-----------------------
  @uvm_immutable_sync
  private WithEvent!uvm_phase_state _m_state;

  @uvm_private_sync
  private int                       _m_run_count; // num times this phase has executed

  @uvm_private_sync
  private Process                   _m_phase_proc;

  @uvm_private_sync
  private int                       _max_ready_to_end_iters;

  @uvm_public_sync
  private int                       _m_num_procs_not_yet_returned;

  // used by wait_for_nba_region
  @uvm_private_sync
  private Signal!int                _m_nba;
  private int                       _m_next_nba;

  
  final void inc_m_num_procs_not_yet_returned() {
    synchronized (this) {
      ++_m_num_procs_not_yet_returned;
    }
  }
  final void dec_m_num_procs_not_yet_returned() {
    synchronized (this) {
      --_m_num_procs_not_yet_returned;
    }
  }

  final uvm_phase m_find_predecessor(uvm_phase phase,
				     bool stay_in_scope = true,
				     uvm_phase orig_phase = null) {
    //$display("  FIND PRED node '", phase.get_name(),"' (id=", $sformatf("%0d", phase.get_inst_id()),") - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(m_imp is null)?"":{"/", $sformatf("%0d", m_imp.get_inst_id())},")");
    if (phase is null) {
      return null ;
    }
    if (phase is m_imp || phase is this) {
      return this;
    }
    foreach (pred; get_predecessors()) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if (!stay_in_scope ||
	 (pred.get_schedule() is orig.get_schedule()) ||
	 (pred.get_domain() is orig.get_domain())) {
	uvm_phase found = pred.m_find_predecessor(phase, stay_in_scope, orig);
	if (found !is null) {
	  return found;
	}
      }
    }
    return null;
  }

  // m_find_successor
  // ----------------

  final uvm_phase m_find_successor(uvm_phase phase,
				   bool stay_in_scope = true,
				   uvm_phase orig_phase = null) {
    //$display("  FIND SUCC node '", phase.get_name(),"' (id=", $sformatf("%0d", phase.get_inst_id()),") - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(m_imp is null)?"":{"/", $sformatf("%0d", m_imp.get_inst_id())},")");
    if (phase is null) {
      return null ;
    }
    if (phase is m_imp || phase is this) {
      return this;
    }
    foreach (succ; get_successors()) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if (!stay_in_scope ||
	 (succ.get_schedule() is orig.get_schedule()) ||
	 (succ.get_domain() is orig.get_domain())) {
	uvm_phase found = succ.m_find_successor(phase, stay_in_scope, orig);
	if (found !is null) {
	  return found;
	}
      }
    }
    return null;
  }

  // m_find_predecessor_by_name
  // --------------------------

  final uvm_phase m_find_predecessor_by_name(string name,
					     bool stay_in_scope = true,
					     uvm_phase orig_phase = null) {
    //$display("  FIND PRED node '", name,"' - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(m_imp is null)?"":{"/", $sformatf("%0d", m_imp.get_inst_id())},")");
    if (get_name() == name) {
      return this;
    }
    foreach (pred; get_predecessors()) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if (!stay_in_scope ||
	 (pred.get_schedule() is orig.get_schedule()) ||
	 (pred.get_domain() is orig.get_domain())) {
	uvm_phase found =
	  pred.m_find_predecessor_by_name(name, stay_in_scope, orig);
	if (found !is null) {
	  return found;
	}
      }
    }
    return null;
  }



  // m_find_successor_by_name
  // ------------------------

  final uvm_phase m_find_successor_by_name(string name,
					   bool stay_in_scope = true,
					   uvm_phase orig_phase = null) {
    //$display("  FIND SUCC node '", name,"' - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(m_imp is null)?"":{"/", $sformatf("%0d", m_imp.get_inst_id())},")");
    if (get_name() == name) {
      return this;
    }
    foreach (succ; get_successors()) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if (!stay_in_scope ||
	 (succ.get_schedule() is orig.get_schedule()) ||
	 (succ.get_domain() is orig.get_domain())) {
	uvm_phase found =
	  succ.m_find_successor_by_name(name, stay_in_scope, orig);
	if (found !is null) {
	  return found;
	}
      }
    }
    return null;
  }


  // m_print_successors
  // ------------------

  final void m_print_successors() {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    enum string spaces = "                                                 ";
    static int level;
    if (m_phase_type is uvm_phase_type.UVM_PHASE_DOMAIN) {
      level = 0;
    }
    uvm_info("UVM/PHASE/SUCC",
	     format("%s%s (%s) id=%0d", spaces[0..level*2+1],
		    get_name(), m_phase_type, get_inst_id()),
	     uvm_verbosity.UVM_NONE);
    ++level;
    foreach (succ; get_successors()) {
      succ.m_print_successors();
    }
    --level;
  }


  // Implementation - Callbacks
  //---------------------------
  // Provide the required component traversal behavior. Called by execute()
  // function -- not task
  void traverse(uvm_component comp,
		uvm_phase phase,
		uvm_phase_state state) { }
  // Provide the required per-component execution flow. Called by traverse()
  // function -- not task
  void execute(uvm_component comp,
	       uvm_phase phase) { }

  // Implementation - Schedule
  //--------------------------
  private bool[uvm_phase] _m_predecessors;
  bool has_predecessors() {
    synchronized (this) {
      if (_m_predecessors.length > 0) {
	return true;
      }
      else {
	return false;
      }
    }
  }
  bool has_predecessor(uvm_phase phase) {
    synchronized (this) {
      if (phase in _m_predecessors) {
	return true;
      }
      else {
	return false;
      }
    }
  }
  void add_predecessor(uvm_phase phase) {
    synchronized (this) {
      _m_predecessors[phase] = true;
    }
  }
  void rem_predecessor(uvm_phase phase) {
    synchronized (this) {
      _m_predecessors.remove(phase);
    }
  }
  void clr_predecessors() {
    synchronized (this) {
      _m_predecessors.clear();
    }
  }
  void cpy_predecessors(uvm_phase from) {
    synchronized (this) {
      this._m_predecessors = from.dup_predecessors();
    }
  }
  uvm_phase[] get_predecessors() {
    synchronized (this) {
      import std.algorithm.sorting;
      auto phases = _m_predecessors.keys;
      sort(phases);
      return phases;
    }
  }
  auto dup_predecessors() {
    synchronized (this) {
      return _m_predecessors.dup;
    }
  }
  
  private bool[uvm_phase] _m_successors;
  bool has_successors() {
    synchronized (this) {
      if (_m_successors.length > 0) {
	return true;
      }
      else {
	return false;
      }
    }
  }
  bool has_successor(uvm_phase phase) {
    synchronized (this) {
      if (phase in _m_successors) {
	return true;
      }
      else {
	return false;
      }
    }
  }
  void add_successor(uvm_phase phase) {
    synchronized (this) {
      _m_successors[phase] = true;
    }
  }
  void rem_successor(uvm_phase phase) {
    synchronized (this) {
      _m_successors.remove(phase);
    }
  }
  void clr_successors() {
    synchronized (this) {
      _m_successors.clear();
    }
  }
  void cpy_successors(uvm_phase from) {
    synchronized (this) {
      this._m_successors = from.dup_successors();
    }
  }
  uvm_phase[] get_successors() {
    synchronized (this) {
      import std.algorithm.sorting;
      auto phases = _m_successors.keys;
      sort(phases);
      return phases;
    }
  }
  auto dup_successors() {
    synchronized (this) {
      return _m_successors.dup;
    }
  }

  @uvm_protected_sync
  private uvm_phase _m_end_node;

  final uvm_phase get_begin_node() {
    synchronized (this) {
      if (_m_imp !is null) return this;
      else return null;
    }
  }

  final uvm_phase get_end_node() {
    synchronized (this) {
      return _m_end_node;
    }
  }

  // Implementation - Synchronization
  //---------------------------------
  @uvm_private_sync
  private Queue!uvm_phase _m_sync; // schedule instance to which we are synced
  private void rem_sync(uvm_phase phase) {
    synchronized (this) {
      import std.algorithm: countUntil;
      auto c = countUntil(_m_sync[], phase);
      if (c !is -1) _m_sync.remove(c);
    }
  }
  private void add_sync(uvm_phase phase) {
    synchronized (this) {
      import std.algorithm: canFind;
      // m_sync is a Queue of uvm_phase
      if (!canFind(_m_sync[], phase)) _m_sync.pushBack(phase);
    }
  }

  @uvm_private_sync
  private uvm_objection _phase_done;

  @uvm_private_sync
  private uint _m_ready_to_end_count;

  final uint get_ready_to_end_count() {
    synchronized (this) {
      return _m_ready_to_end_count;
    }
  }

  // Internal implementation, more efficient than calling get_predessor_nodes on all
  // of the successors returned by get_adjacent_successor_nodes
  final void
  get_predecessors_for_successors(out bool[uvm_phase] pred_of_succ) {
    import uvm.base.uvm_object_globals;
    // This synchronization guard results in deadlock
    // synchronized (this) {
    bool done;
    uvm_phase[] successors;

    get_adjacent_successor_nodes(successors);

    // get all predecessors to these successors
    foreach (successor; successors) {
      foreach (pred; successor.get_predecessors()) {
	pred_of_succ[pred] = true;
      }
    }

    // replace any terminal nodes with their predecessors, recursively.
    // we are only interested in "real" phase nodes
    do {
      done = true;
      import std.algorithm.sorting;
      foreach (pred; sort(pred_of_succ.keys)) {
	if (pred.get_phase_type() !is uvm_phase_type.UVM_PHASE_NODE) {
	  pred_of_succ.remove(pred);
	  foreach (next_pred; pred.get_predecessors()) {
	    pred_of_succ[next_pred] = true;
	  }
	  done = false;
	}
      }
    } while (!done);


    // remove ourselves from the list
    pred_of_succ.remove(this);
    // }
  }

  // m_wait_for_pred
  // ---------------

  // task
  final void m_wait_for_pred() {

    import uvm.base.uvm_object_globals;
    bool[uvm_phase] pred_of_succ;
    get_predecessors_for_successors(pred_of_succ);

    // wait for predecessors to successors (real phase nodes, not terminals)
    // mostly debug msgs
    foreach (sibling, unused; pred_of_succ) {
      if (m_phase_trace) {
	string s = format("Waiting for phase '%s' (%0d) to be " ~
			  "READY_TO_END. Current state is %s",
			  sibling.get_name(), sibling.get_inst_id(),
			  sibling.m_state.get());
	UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC", s, this, uvm_verbosity.UVM_HIGH);
      }

      sibling.wait_for_state(uvm_phase_state.UVM_PHASE_READY_TO_END, uvm_wait_op.UVM_GTE);

      if (m_phase_trace) {
	string s = format("Phase '%s' (%0d) is now READY_TO_END. " ~
			  "Releasing phase",
			  sibling.get_name(),sibling.get_inst_id());
	UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC",s,this,uvm_verbosity.UVM_HIGH);
      }
    }

    if (m_phase_trace) {
      if (pred_of_succ.length !is 0) {
	string s = "( ";
	foreach (pred, unused; pred_of_succ) {
	  s ~= pred.get_full_name() ~ " ";
	}
	s ~= ")";
	UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC",
		     "*** All pred to succ " ~ s ~
		     " in READY_TO_END state, so ending phase ***",
		     this, uvm_verbosity.UVM_HIGH);
      }
      else {
	UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC",
		     "*** No pred to succ other than myself, " ~
		     "so ending phase ***", this, uvm_verbosity.UVM_HIGH);
      }
    }
    wait(0); // #0; // LET ANY WAITERS WAKE UP

  }


  // Implementation - Jumping
  //-------------------------
  @uvm_immutable_sync
  private WithEvent!bool _m_jump_bkwd;
  @uvm_immutable_sync
  private WithEvent!bool _m_jump_fwd;

  @uvm_private_sync
  private uvm_phase _m_jump_phase;

  @uvm_immutable_sync
  private WithEvent!bool _m_premature_end;

  // clear
  // -----
  // for internal graph maintenance after a forward jump
  final void clear(uvm_phase_state state = uvm_phase_state.UVM_PHASE_DORMANT) {
    uvm_objection phase_done = get_objection();
    synchronized (this) {
      _m_state = state;
      _m_phase_proc = null;
    }
    if (phase_done !is null) {
      phase_done.clear(this);
    }
  }


  // clear_successors
  // ----------------
  // for internal graph maintenance after a forward jump
  // - called only by execute_phase()
  // - depth-first traversal of the DAG, calliing clear() on each node
  // - do not clear the end phase or beyond
  final void clear_successors(uvm_phase_state state=uvm_phase_state.UVM_PHASE_DORMANT,
			      uvm_phase end_state = null) {
    if (this is end_state) {
      return;
    }
    clear(state);
    foreach (succ; get_successors()) {
      succ.clear_successors(state, end_state);
    }
  }


  // Implementation - Overall Control
  //---------------------------------

  // m_run_phases
  // ------------

  // This task contains the top-level process that owns all the phase
  // processes.  By hosting the phase processes here we avoid problems
  // associated with phase processes related as parents/children

  // task
  static void m_run_phases() {
    import uvm.base.uvm_root;
    import uvm.base.uvm_coreservice;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root top = cs.get_root();

    // initiate by starting first phase in common domain
    uvm_phase ph = uvm_domain.get_common_domain();
    m_phase_hopper.try_put(ph);

    m_uvm_core_state = uvm_core_state.UVM_CORE_RUNNING;

    for (;;) {
      uvm_phase phase_to_execute;
      m_phase_hopper.get(phase_to_execute);
      (uvm_phase phase) {
	fork("uvm_phases/run_phases(" ~ phase.get_name() ~ ")",
	     {
	       phase.execute_phase();
	     }
	     );
      } (phase_to_execute);
      wait(0);	// #0;		// let the process start running
    }
  }

  // execute_phase
  // -------------

  // task
  void execute_phase() {
    import uvm.base.uvm_root;
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    
    uvm_task_phase task_phase;

    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root top = cs.get_root();

    // If we got here by jumping forward, we must wait for
    // all its predecessor nodes to be marked DONE.
    // (the next conditional speeds this up)
    // Also, this helps us fast-forward through terminal (end) nodes
    foreach (pred; get_predecessors()) {
      while (pred.m_state.get != uvm_phase_state.UVM_PHASE_DONE) {
	pred.m_state.getEvent.wait();
      }
    }

    // If DONE (by, say, a forward jump), return immed
    if (m_state.get == uvm_phase_state.UVM_PHASE_DONE) {
      return;
    }

    uvm_phase_state_change state_chg =
      uvm_phase_state_change.type_id.create(get_name());
    state_chg.m_phase      = this;
    state_chg.m_jump_to    = null;

    //---------
    // SYNCING:
    //---------
    // Wait for phases with which we have a sync()
    // relationship to be ready. Sync can be 2-way -
    // this additional state avoids deadlock.
    state_chg.m_prev_state = m_state;
    m_state = uvm_phase_state.UVM_PHASE_SYNCING;
    uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));
    wait(0);
    if (m_sync.length != 0) {

      foreach (sync; m_sync[]) {
	while (sync.m_state.get < uvm_phase_state.UVM_PHASE_SYNCING) {
	  sync.m_state.getEvent.wait();
	}
      }
    }

    synchronized (this) {
      _m_run_count++;


      if (m_phase_trace) {
	UVM_PH_TRACE("PH/TRC/STRT","Starting phase", this, uvm_verbosity.UVM_LOW);
      }
    }

    // If we're a schedule or domain, then "fake" execution
    if (m_phase_type !is uvm_phase_type.UVM_PHASE_NODE) {
      state_chg.m_prev_state = m_state;
      m_state = uvm_phase_state.UVM_PHASE_STARTED;
      uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));

      wait(0);			// #0;

      state_chg.m_prev_state = m_state;
      m_state = uvm_phase_state.UVM_PHASE_EXECUTING;
      uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));

      wait(0);			// #0;
    }


    else { // PHASE NODE

      //---------
      // STARTED:
      //---------
      state_chg.m_prev_state = m_state;
      m_state = uvm_phase_state.UVM_PHASE_STARTED;
      uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));

      m_imp.traverse(top, this, uvm_phase_state.UVM_PHASE_STARTED);
      m_ready_to_end_count = 0 ; // reset the ready_to_end count when phase starts

      // #0; // LET ANY WAITERS WAKE UP
      wait(0);

      task_phase = cast (uvm_task_phase) m_imp;

      //if (m_imp.get_phase_type() !is UVM_PHASE_TASK) {
      if (task_phase is null) {

	//-----------
	// EXECUTING: (function phases)
	//-----------
	state_chg.m_prev_state = m_state;
	m_state = uvm_phase_state.UVM_PHASE_EXECUTING;
	uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));

	wait(0);
	m_imp.traverse(top, this, uvm_phase_state.UVM_PHASE_EXECUTING);
      }
      else {
	add_executing_phase(this);

        state_chg.m_prev_state = m_state;
        m_state = uvm_phase_state.UVM_PHASE_EXECUTING;
        uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));

	m_phase_proc = fork!("uvm_phases/master_phase_process")
	  ({
	    m_phase_proc = Process.self();
	    //-----------
	    // EXECUTING: (task phases)
	    //-----------

	    task_phase.traverse(top, this, uvm_phase_state.UVM_PHASE_EXECUTING);

	    // wait(0) -- SV version
	    sleep();
	  });

	wait_for_nba_region(); //Give sequences, etc. a chance to object

	// Now wait for one of three criterion for end-of-phase.
	// Fork guard = join({
	Fork end_phase = fork!("uvm_phases/end_phase")({ // JUMP
	    while (m_premature_end.get is false) {
	      wait(m_premature_end.getEvent);
	    }
	    UVM_PH_TRACE("PH/TRC/EXE/JUMP","PHASE EXIT ON JUMP REQUEST",
			 this, uvm_verbosity.UVM_DEBUG);
	  },
	  { // WAIT_FOR_ALL_DROPPED
	    uvm_objection phase_done = get_objection();
	    // OVM semantic: don't end until objection raised or stop request
	    if (phase_done.get_objection_total(top) ||
	       m_use_ovm_run_semantic && m_imp.get_name() == "run") {
	      if (!phase_done.m_top_all_dropped) {
		phase_done.wait_for(uvm_objection_event.UVM_ALL_DROPPED, top);
	      }
	      UVM_PH_TRACE("PH/TRC/EXE/ALLDROP","PHASE EXIT ALL_DROPPED",
			   this, uvm_verbosity.UVM_DEBUG);
	    }
	    else {
	      if (m_phase_trace) {
		UVM_PH_TRACE("PH/TRC/SKIP","No objections raised, " ~
			     "skipping phase", this, uvm_verbosity.UVM_LOW);
	      }
	    }

	    wait_for_self_and_siblings_to_drop();

	    //--------------
	    // READY_TO_END:
	    //--------------

	    bool do_ready_to_end = true; // bit used for ready_to_end iterations
	    while (do_ready_to_end) {
	      wait_for_nba_region(); // Let all siblings see no objections before traverse might raise another
	      UVM_PH_TRACE("PH_READY_TO_END","PHASE READY TO END",
			   this, uvm_verbosity.UVM_DEBUG);
	      synchronized (this) {
		++_m_ready_to_end_count;
		if (m_phase_trace)
		  UVM_PH_TRACE("PH_READY_TO_END_CB","CALLING READY_TO_END CB",
			       this, uvm_verbosity.UVM_HIGH);
		state_chg.m_prev_state = _m_state;
		_m_state = uvm_phase_state.UVM_PHASE_READY_TO_END;
	      }
	      uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));
	      if (m_imp !is null) {
		m_imp.traverse(top, this, uvm_phase_state.UVM_PHASE_READY_TO_END);
	      }

	      wait_for_nba_region(); // Give traverse targets a chance to object

	      wait_for_self_and_siblings_to_drop();

	      synchronized (this) {
		//when we don't wait in task above, we drop out of while loop
		do_ready_to_end = (_m_state.get == uvm_phase_state.UVM_PHASE_EXECUTING) &&
		  (_m_ready_to_end_count < get_max_ready_to_end_iterations());
	      }
	    }
	  },
	  { // TIMEOUT
	    if (this.get_name() == "run") {
	      while (top.phase_timeout.get == 0.sec()) {
		wait(top.phase_timeout.getEvent);
	      }

	      if (m_phase_trace) {
		UVM_PH_TRACE("PH/TRC/TO_WAIT",
			     format("STARTING PHASE TIMEOUT WATCHDOG" ~
				    " (timeout == %s)", top.phase_timeout),
			     this, uvm_verbosity.UVM_HIGH);
	      }
	      
	      // `uvm_delay(top.phase_timeout)
	      wait(top.phase_timeout.get);

	      auto cs = uvm_coreservice_t.get();
	      auto root = cs.get_root();
	      // TBD
	      // if ($time == `UVM_DEFAULT_TIMEOUT) begin
	      if (getRootEntity().getSimTime() == root.phase_sim_timeout) {
		if (m_phase_trace) {
		  UVM_PH_TRACE("PH/TRC/TIMEOUT", "PHASE TIMEOUT WATCHDOG " ~
			       "EXPIRED", this, uvm_verbosity.UVM_LOW);
		}
		foreach (p; get_executing_phases()) {
		  uvm_objection p_phase_done = p.get_objection();
		  if ((p_phase_done !is null) &&
		     (p_phase_done.get_objection_total() > 0)) {
		    if (m_phase_trace)
		      UVM_PH_TRACE("PH/TRC/TIMEOUT/OBJCTN",
				   format("Phase '%s' has outstanding " ~
					  "objections:\n%s",
					  p.get_full_name(),
					  p_phase_done.convert2string()),
				   this, uvm_verbosity.UVM_LOW);
		  }
		}

		uvm_fatal("PH_TIMEOUT",
			  format("Default timeout of %s hit, indicating " ~
				 "a probable testbench issue",
				 root.phase_sim_timeout));
	      }
	      else {
		if (m_phase_trace) {
		  UVM_PH_TRACE("PH/TRC/TIMEOUT", "PHASE TIMEOUT WATCHDOG " ~
			       "EXPIRED", this, uvm_verbosity.UVM_LOW);
		}
		foreach (p; get_executing_phases()) {
		  uvm_objection p_phase_done = p.get_objection();
		  if ((p_phase_done !is null) &&
		     (p_phase_done.get_objection_total() > 0)) {
		    if (m_phase_trace)
		      UVM_PH_TRACE("PH/TRC/TIMEOUT/OBJCTN",
				   format("Phase '%s' has outstanding " ~
					  "objections:\n%s",
					  p.get_full_name(),
					  p_phase_done.convert2string()),
				   this, uvm_verbosity.UVM_LOW);
		  }
		}

		uvm_fatal("PH_TIMEOUT",
			  format("Explicit timeout of %0s hit, indicating " ~
				 "a probable testbench issue",
				 top.phase_timeout));
	      }
	      if (m_phase_trace)
		UVM_PH_TRACE("PH/TRC/EXE/3","PHASE EXIT TIMEOUT",
			     this, uvm_verbosity.UVM_DEBUG);
	    }
	    else {
	      sleep();
	    }
	  });
	end_phase.joinAny();
	end_phase.abortTree();
	// });

      }
    }

    rem_executing_phase(this);

    //---------
    // JUMPING:
    //---------

    // If jump_to() was called then we need to kill all the successor
    // phases which may still be running and then initiate the new
    // phase.  The return is necessary so we don't start new successor
    // phases.  If we are doing a forward jump then we want to set the
    // state of this phase's successors to UVM_PHASE_DONE.  This
    // will let us pretend that all the phases between here and there
    // were executed and completed.  Thus any dependencies will be
    // satisfied preventing deadlocks.
    // GSA TBD insert new jump support

    if (get_phase_type == uvm_phase_type.UVM_PHASE_NODE) {

      if (m_premature_end.get) {
	if (m_jump_phase !is null) {
	  state_chg.m_jump_to = m_jump_phase;

	  uvm_info("PH_JUMP",
		   format("phase %s (schedule %s, domain %s) is " ~
			  "jumping to phase %s", get_name(),
			  get_schedule_name(), get_domain_name(),
			  m_jump_phase.get_name()),
		   uvm_verbosity.UVM_MEDIUM);

	}
	else {
	  uvm_info("PH_JUMP",
		   format("phase %s (schedule %s, domain %s) is ending" ~
			  " prematurely", get_name(), get_schedule_name(),
			  get_domain_name()), uvm_verbosity.UVM_MEDIUM);
	}
	wait(0); // #0; // LET ANY WAITERS ON READY_TO_END TO WAKE UP

	if (m_phase_trace) {
	  UVM_PH_TRACE("PH_END","ENDING PHASE PREMATURELY", this, uvm_verbosity.UVM_HIGH);
	}
      }
      else {
	// WAIT FOR PREDECESSORS:  // WAIT FOR PREDECESSORS:
	// function phases only
	if (task_phase is null) {
	  m_wait_for_pred();
	}
      }
  
      //-------
      // ENDED:
      //-------
      // execute 'phase_ended' callbacks
      synchronized (this) {
	if (m_phase_trace) {
	  UVM_PH_TRACE("PH_END","ENDING PHASE",this,uvm_verbosity.UVM_HIGH);
	}
	state_chg.m_prev_state = _m_state;
	_m_state = uvm_phase_state.UVM_PHASE_ENDED;
      }
      uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));
      if (m_imp !is null) {
	m_imp.traverse(top, this, uvm_phase_state.UVM_PHASE_ENDED);
      }

      wait(0); // LET ANY WAITERS WAKE UP

      //---------
      // CLEANUP:
      //---------
      // kill this phase's threads
      synchronized (this) {
	state_chg.m_prev_state = m_state;
	if (m_premature_end.get) {
	  m_state = uvm_phase_state.UVM_PHASE_JUMPING;
	}
	else {
	  m_state = uvm_phase_state.UVM_PHASE_CLEANUP ;
	}
      }
	    
      uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));

      synchronized (this) {
	if (_m_phase_proc !is null) {
	  _m_phase_proc.abort();
	  _m_phase_proc = null;
	}
      }

      wait(0); // LET ANY WAITERS WAKE UP
      uvm_objection objection = get_objection();
      if (objection !is null) {
	objection.clear();
      }
    }

    //------
    // DONE:
    //------
    m_premature_end = false;
    if (m_jump_fwd.get || m_jump_bkwd.get) {

      if (m_jump_fwd.get) {
	clear_successors(uvm_phase_state.UVM_PHASE_DONE, m_jump_phase);
      }

      m_jump_phase.clear_successors();

    }
    else {

      if (m_phase_trace) {
	UVM_PH_TRACE("PH/TRC/DONE", "Completed phase", this, uvm_verbosity.UVM_LOW);
      }
      state_chg.m_prev_state = m_state;
      m_state = uvm_phase_state.UVM_PHASE_DONE;
      uvm_do_callbacks(cb => cb.phase_state_change(this, state_chg));
      synchronized (this) {
	_m_phase_proc = null;
      }
      wait(0); // LET ANY WAITERS WAKE UP
    }

    wait(0); // LET ANY WAITERS WAKE UP

    uvm_objection objection = get_objection();
    if (objection !is null) {
      objection.clear();
    }

    //-----------
    // SCHEDULED:
    //-----------
    if (m_jump_fwd.get || m_jump_bkwd.get) {
      m_phase_hopper.try_put(m_jump_phase);
      m_jump_phase = null;
      m_jump_fwd = false;
      m_jump_bkwd = false;

    }

    // If more successors, schedule them to run now
    else if (! has_successors()) {
      top.m_phase_all_done = true;
    }
    else {
      // execute all the successors
      foreach (succ; get_successors()) {
	if (succ.m_state.get < uvm_phase_state.UVM_PHASE_SCHEDULED) {
	  state_chg.m_prev_state = succ.m_state;
	  state_chg.m_phase = succ;
	  succ.m_state = uvm_phase_state.UVM_PHASE_SCHEDULED;
	  uvm_do_callbacks(cb => cb.phase_state_change(succ, state_chg));
	  wait(0); // LET ANY WAITERS WAKE UP
	  synchronized (this) {
	    m_phase_hopper.try_put(succ);
	    if (m_phase_trace) {
	      UVM_PH_TRACE("PH/TRC/SCHEDULED", "Scheduled from phase " ~
			   get_full_name(), succ, uvm_verbosity.UVM_LOW);
	    }
	  }
	}
      }
    }
  }

  // terminate_phase
  // ---------------

  void m_terminate_phase() {
    synchronized (this) {
      uvm_objection phase_done = get_objection();
      if (phase_done !is null) {
	phase_done.clear(this);
      }
    }
  }


  // print_termination_state
  // -----------------------

  private void m_print_termination_state() {
    import uvm.base.uvm_root;
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    synchronized (this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_root top = cs.get_root();
      uvm_objection phase_done = get_objection();
      if (phase_done !is null) {
	uvm_info("PH_TERMSTATE",
		 format("phase %s outstanding objections = %0d",
			get_name(), phase_done.get_objection_total(top)),
		 uvm_verbosity.UVM_DEBUG);
      }
      else {
	uvm_info("PH_TERMSTATE",
		 format("phase %s has no outstanding objections",
			get_name()),
		 uvm_verbosity.UVM_DEBUG);
      }
    }
  }



  // task
  final void wait_for_self_and_siblings_to_drop() {
    import uvm.base.uvm_root;
    import uvm.base.uvm_coreservice;
    import uvm.base.uvm_object_globals;
    bool need_to_check_all = true;
    uvm_coreservice_t cs = uvm_coreservice_t.get();
    uvm_root top = cs.get_root();
    bool[uvm_phase] siblings;

    get_predecessors_for_successors(siblings);

    foreach (s; m_sync[]) {
      siblings[s] = true;
    }

    while (need_to_check_all) {
      uvm_objection phase_done = get_objection();
      need_to_check_all = false ; //if all are dropped, we won't need to do this again

      // wait for own objections to drop
      if ((phase_done !is null) &&
	 (phase_done.get_objection_total(top) != 0)) {
	m_state = uvm_phase_state.UVM_PHASE_EXECUTING;
	phase_done.wait_for(uvm_objection_event.UVM_ALL_DROPPED, top);
	need_to_check_all = true;
      }

      // now wait for siblings to drop
      foreach (sib, unused; siblings) {
	uvm_objection sib_phase_done = sib.get_objection();
	sib.wait_for_state(uvm_phase_state.UVM_PHASE_EXECUTING, uvm_wait_op.UVM_GTE); // sibling must be at least executing
	if ((sib_phase_done !is null) &&
	   (sib_phase_done.get_objection_total(top) != 0)) {
	  m_state = uvm_phase_state.UVM_PHASE_EXECUTING;
	  sib_phase_done.wait_for(uvm_objection_event.UVM_ALL_DROPPED, top); // sibling must drop any objection
	  need_to_check_all = true;
	}
      }
    }
  }

  // kill
  // ----

  final void kill() {
    import uvm.base.uvm_globals;
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      uvm_info("PH_KILL", "killing phase '" ~ get_name() ~ "'", uvm_verbosity.UVM_DEBUG);

      if (_m_phase_proc !is null) {
	_m_phase_proc.abort();
	_m_phase_proc = null;
      }

    }
  }


  // kill_successors
  // ---------------

  // Using a depth-first traversal, kill all the successor phases of the
  // current phase.
  final void kill_successors() {
    foreach (succ; get_successors())
      succ.kill_successors();
    kill();
  }


  // TBD add more useful debug
  //---------------------------------

  override  string convert2string() {
    synchronized (this) {
      //return $sformatf("PHASE %s = %p", get_name(), this);
      string s = format("phase: %s parent=%s  pred=%s  succ=%s", get_name(),
			(_m_parent is null) ? "null" : get_schedule_name(),
			m_aa2string(get_predecessors()),
			m_aa2string(get_successors()));
      return s;
    }
  }

  final private string m_aa2string(uvm_phase[] aa) { // TBD tidy
    int i;
    string s = "'{ ";
    foreach (ph; aa) {
      uvm_phase n = ph;
      s ~=  (n is null) ? "null" : n.get_name() ~
	(i is aa.length-1) ? "" : " ~  ";
      ++i;
    }
    s ~= " }";
    return s;
  }

  final bool is_domain() {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      return (m_phase_type == uvm_phase_type.UVM_PHASE_DOMAIN);
    }
  }

  void m_get_transitive_children(ref Queue!uvm_phase phases) {
    synchronized (this) {
      foreach (succ; get_successors()) {
	phases.pushBack(succ);
	succ.m_get_transitive_children(phases);
      }
    }
  }

  void m_get_transitive_children(ref uvm_phase[] phases) {
    synchronized (this) {
      foreach (succ; get_successors()) {
	phases ~= succ;
	succ.m_get_transitive_children(phases);
      }
    }
  }

  final uvm_phase[] m_get_transitive_children() {
    uvm_phase[] phases;
    foreach (succ; get_successors()) {
      phases ~= succ;
      phases ~= succ.m_get_transitive_children();
    }
    return phases;
  }

  final int opCmp(uvm_phase other) {
    if (get_name() > other.get_name()) return 1;
    else if (get_name() < other.get_name()) return -1;
    else return 0;
  }

  
  
  // @uvm-ieee 1800.2-2020 auto 9.3.1.7.1
  uvm_objection get_objection() {
    synchronized (this) {
      uvm_phase imp = get_imp();
      uvm_task_phase tp = cast (uvm_task_phase) imp;
      // Only nodes with a non-null uvm_task_phase imp have objections
      if ((get_phase_type() != uvm_phase_type.UVM_PHASE_NODE) ||
	  (imp is null) || (tp is null)) {
	return null;
      }
      if (phase_done is null) {
	phase_done =
	  uvm_objection.type_id.create(get_name() ~ "_objection");
      }
      return phase_done;
    }
  }
  
  // SV has this function defined as a global function in uvm_globals module
  
  //----------------------------------------------------------------------------
  //
  // Task: wait_for_nba_region
  //
  // This task will block until SystemVerilog's NBA region (or Re-NBA region if 
  // called from a program context).  The purpose is to continue the calling 
  // process only after allowing other processes any number of delta cycles (#0) 
  // to settle out.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  //----------------------------------------------------------------------------

  enum size_t UVM_POUND_ZERO_COUNT=1;
  void wait_for_nba_region() {
    // SV version has UVM_NO_WAIT_FOR_NBA, but for eUVM it may be more
    // efficient to just have that as default
    version (UVM_NO_WAIT_FOR_NBA) {
      // repeat(UVM_POUND_ZERO_COUNT) #0;
      for (size_t i=0; i!=UVM_POUND_ZERO_COUNT; ++i) {
        wait(0);
      }
    }
    else {
      // These are not declared static in the SV version
      // If `included directly in a program block, can't use a non-blocking assign,
      //but it isn't needed since program blocks are in a separate region.
      _m_next_nba++;
      _m_nba = _m_next_nba;
      wait(_m_nba);
    }
  }

}

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_phase_state_change
//
//------------------------------------------------------------------------------
//
// Phase state transition descriptor.
// Used to describe the phase transition that caused a
// <uvm_phase_cb::phase_state_changed()> callback to be invoked.
//

// @uvm-ieee 1800.2-2020 auto 9.3.2.1
class uvm_phase_state_change: uvm_object
{

  mixin (uvm_sync_string);

  mixin uvm_object_essentials;

  // Implementation -- do not use directly
  @uvm_private_sync
  private uvm_phase       _m_phase;
  @uvm_private_sync
  private uvm_phase_state _m_prev_state;
  @uvm_private_sync
  private uvm_phase       _m_jump_to;
  
  this(string name = "uvm_phase_state_change") {
    super(name);
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.2.2.1
  uvm_phase_state get_state() {
    synchronized (this) {
      return _m_phase.get_state();
    }
  }
  

  // @uvm-ieee 1800.2-2020 auto 9.3.2.2.2
  uvm_phase_state get_prev_state() {
    synchronized (this) {
      return _m_prev_state;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 9.3.2.2.3
  uvm_phase jump_to() {
    synchronized (this) {
      return _m_jump_to;
    }
  }
}


//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_phase_cb
//
//------------------------------------------------------------------------------
//
// This class defines a callback method that is invoked by the phaser
// during the execution of a specific node in the phase graph or all phase nodes.
// User-defined callback extensions can be used to integrate data types that
// are not natively phase-aware with the UVM phasing.
//

// @uvm-ieee 1800.2-2020 auto 9.3.3.1
class uvm_phase_cb: uvm_callback
{


  // @uvm-ieee 1800.2-2020 auto 9.3.3.2.1
  this(string name="unnamed-uvm_phase_cb") {
    super(name);
  }
   

  // @uvm-ieee 1800.2-2020 auto 9.3.3.2.2
  void phase_state_change(uvm_phase phase,
			  uvm_phase_state_change change) {}
}

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_phase_cb_pool
//
//------------------------------------------------------------------------------
//
// Convenience type for the uvm_callbacks#(uvm_phase, uvm_phase_cb) class.
//

// @uvm-ieee 1800.2-2020 auto D.4.1
alias uvm_phase_cb_pool = uvm_callbacks!(uvm_phase, uvm_phase_cb);



//------------------------------------------------------------------------------
//                               IMPLEMENTATION
//------------------------------------------------------------------------------

void UVM_PH_TRACE(string file=__FILE__,
		  size_t line=__LINE__)(string ID, string MSG,
					uvm_phase PH,
					uvm_verbosity VERB) {
  import uvm.base.uvm_globals;
  uvm_info!(file, line)(ID, format("Phase '%0s' (id=%0d) ",
				   PH.get_full_name(), PH.get_inst_id()) ~
			MSG, VERB);
}
