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

// typedef class uvm_test_done_objection;
// typedef class uvm_sequencer_base;

// typedef class uvm_domain;
// typedef class uvm_task_phase;


//------------------------------------------------------------------------------
//
// Class: uvm_phase
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
// *Phase Definition*
//
// Singleton instances of those extensions are provided as package variables.
// These instances define the attributes of the phase (not what state it is in)
// They are then cloned into schedule nodes which point back to one of these
// implementations, and calls it's virtual task or function methods on each
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
// delegate, and which may be a null implementation. Instantiate a singleton
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
// APIs. In many cases, the singleton package-global phase handles can be
// used (eg. connect_ph, run_ph) in APIs. For those APIs that need to look
// up that phase in the graph, this is done automatically.

module uvm.base.uvm_phase;

import uvm.base.uvm_object;
import uvm.base.uvm_objection;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.base.uvm_component;
import uvm.base.uvm_domain;
import uvm.base.uvm_root;
import uvm.base.uvm_task_phase;
import uvm.meta.misc;
import uvm.meta.mailbox;
import uvm.meta.mcd;
import esdl.base.core: waitDelta, wait, Fork, abortForks, getRootEntity,
  sleep, fork;
import esdl.data.time;
import esdl.data.sync;
import uvm.base.uvm_cmdline_processor;

import std.string: format;
import std.conv: to;



class uvm_phase: uvm_object
{
  import esdl.base.core: Process;
  import esdl.data.queue;

  static class uvm_once
  {
    @uvm_immutable_sync private SyncAssoc!(uvm_phase, bool) _m_executing_phases;
    // private static mailbox #(uvm_phase) m_phase_hopper = new();
    @uvm_immutable_sync private Mailbox!uvm_phase _m_phase_hopper;
    @uvm_protected_sync private bool _m_phase_trace;
    @uvm_private_sync private bool _m_use_ovm_run_semantic;
    this() {
      synchronized(this) {
	_m_phase_hopper = new Mailbox!uvm_phase();
						
	_m_executing_phases = new SyncAssoc!(uvm_phase, bool);
      }
    }
  }
  mixin uvm_once_sync;
  mixin uvm_sync;
  // not required in vlang
  //`uvm_object_utils(uvm_phase)


  //--------------------
  // Group: Construction
  //--------------------

  // Function: new
  //
  // Create a new phase node, with a name and a note of its type
  //   name   - name of this phase
  //   type   - task, topdown func or bottomup func
  //
  public this(string name="uvm_phase",
	      uvm_phase_type phase_type=UVM_PHASE_SCHEDULE,
	      uvm_phase parent=null) {
    synchronized(this) {
      super(name);
      _m_state = new WithEvent!uvm_phase_state();
      _m_jump_fwd = new WithEvent!bool();
      _m_jump_bkwd = new WithEvent!bool();
      _m_predecessors = new SyncAssoc!(uvm_phase, bool);
      _m_successors = new SyncAssoc!(uvm_phase, bool);

      _m_phase_type = phase_type;

      if(name == "run") {
	_phase_done = uvm_test_done_objection.get();
      }
      else {
	_phase_done = new uvm_objection(name ~ "_objection");
      }

      _m_state = UVM_PHASE_DORMANT;
      _m_run_count = 0;
      _m_parent = parent;

      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
      string val;
      debug(UVM_PHASE_TRACE) {
	m_phase_trace = true;	// once variable
      }
      else {
	if(clp.get_arg_value("+UVM_PHASE_TRACE", val)) {
	  m_phase_trace = true;	// once variable
	}
	else {
	  m_phase_trace = false;
	}
      }
      if(clp.get_arg_value("+UVM_USE_OVM_RUN_SEMANTIC", val)) {
	m_use_ovm_run_semantic = true; // once variable
      }
      else {
	m_use_ovm_run_semantic = false;
      }


      if(parent is null && (phase_type is UVM_PHASE_SCHEDULE ||
			    phase_type is UVM_PHASE_DOMAIN )) {
	//_m_parent = this;
	_m_end_node = new uvm_phase(name ~ "_end", UVM_PHASE_TERMINAL, this);
	this.m_successors[_m_end_node] = true;
	_m_end_node.m_predecessors[this] = true;
      }
    }
  }

  // Function: get_phase_type
  //
  // Returns the phase type as defined by <uvm_phase_type>
  //
  final public uvm_phase_type get_phase_type() {
    synchronized(this) {
      return _m_phase_type;
    }
  }


  //-------------
  // Group: State
  //-------------

  // Function: get_state
  //
  // Accessor to return current state of this phase
  //
  final public uvm_phase_state get_state() {
    synchronized(this) {
      return _m_state;
    }
  }


  // Function: get_run_count
  //
  // Accessor to return the integer number of times this phase has executed
  //
  final public int get_run_count() {
    synchronized(this)
      return _m_run_count;
  }


  // Function: find_by_name
  //
  // Locate a phase node with the specified ~name~ and return its handle.
  // With ~stay_in_scope~ set, searches only within this phase's schedule or
  // domain.
  //
  final public uvm_phase find_by_name(string name, bool stay_in_scope = true) {
    // TBD full search
    //$display({"\nFIND node named '", name,"' within ", get_name()," (scope ", m_phase_type.name(),")", (stay_in_scope) ? " staying within scope" : ""});
    if(get_name() == name) {
      return this;
    }
    uvm_phase retval = m_find_predecessor_by_name(name, stay_in_scope, this);
    if(retval is null) {
      retval = m_find_successor_by_name(name, stay_in_scope, this);
    }
    return retval;
  }


  // Function: find
  //
  // Locate the phase node with the specified ~phase~ IMP and return its handle.
  // With ~stay_in_scope~ set, searches only within this phase's schedule or
  // domain.
  //
  public uvm_phase find(uvm_phase phase, bool stay_in_scope = true) {
    // TBD full search
    //$display({"\nFIND node '", phase.get_name(),"' within ", get_name()," (scope ", m_phase_type.name(),")", (stay_in_scope) ? " staying within scope" : ""});
    if(phase is _m_imp || phase is this) {
      return phase;
    }
    uvm_phase retval = m_find_predecessor(phase, stay_in_scope, this);
    if(retval is null) {
      retval = m_find_successor(phase, stay_in_scope, this);
    }
    return retval;
  }



  // This function is named "is" in SV version, but since "is" is a
  // keyword in dlang, we name this function "is_same" here.

  // Function: is_same
  //
  // returns true if the containing uvm_phase refers to the same phase
  // as the phase argument, false otherwise
  //
  final public bool is_same(uvm_phase phase) {
    synchronized(this) {
      return (_m_imp is phase || this is phase);
    }
  }



  // Function: is_before
  //
  // Returns 1 if the containing uvm_phase refers to a phase that is earlier
  // than the phase argument, 0 otherwise
  //
  final public bool is_before(uvm_phase phase) {
    synchronized(this) {
      //$display("this=%s is before phase=%s?", get_name(), phase.get_name());
      // TODO: add support for 'stay_in_scope=1' functionality
      return (!is_same(phase) && m_find_successor(phase, false, this) !is null);
    }
  }

  // Function: is_after
  //
  // returns 1 if the containing uvm_phase refers to a phase that is later
  // than the phase argument, 0 otherwise
  //
  final public bool is_after(uvm_phase phase) {
    synchronized(this) {
      //$display("this=%s is after phase=%s?", get_name(), phase.get_name());
      // TODO: add support for 'stay_in_scope=1' functionality
      return (!is_same(phase) && m_find_predecessor(phase, false, this) !is null);
    }
  }


  //-----------------
  // Group: Callbacks
  //-----------------

  // Function: exec_func
  //
  // Implements the functor/delegate functionality for a function phase type
  //   comp  - the component to execute the functionality upon
  //   phase - the phase schedule that originated this phase call
  //
  public void exec_func(uvm_component comp, uvm_phase phase) { }


  // Function: exec_task
  //
  // Implements the functor/delegate functionality for a task phase type
  //   comp  - the component to execute the functionality upon
  //   phase - the phase schedule that originated this phase call
  //

  // task
  public void exec_task(uvm_component comp, uvm_phase phase) { }


  //----------------
  // Group: Schedule
  //----------------

  // Function: add
  //
  // Build up a schedule structure inserting phase by phase, specifying linkage
  //
  // Phases can be added anywhere, in series or parallel with existing nodes
  //
  //   phase        - handle of singleton derived imp containing actual functor.
  //                  by default the new phase is appended to the schedule
  //   with_phase   - specify to add the new phase in parallel with this one
  //   after_phase  - specify to add the new phase as successor to this one
  //   before_phase - specify to add the new phase as predecessor to this one
  //
  final public void add(uvm_phase phase,
			uvm_phase with_phase = null,
			uvm_phase after_phase = null,
			uvm_phase before_phase = null) {
    uvm_phase new_node, begin_node, end_node;
    if(phase is null) {
      uvm_fatal("PH/NULL", "add: phase argument is null");
    }

    if(with_phase !is null && with_phase.get_phase_type() is UVM_PHASE_IMP) {
      string nm = with_phase.get_name();
      with_phase = find(with_phase);
      if(with_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find with_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if(before_phase !is null &&
       before_phase.get_phase_type() is UVM_PHASE_IMP) {
      string nm = before_phase.get_name();
      before_phase = find(before_phase);
      if(before_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find before_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if(after_phase !is null &&
       after_phase.get_phase_type() is UVM_PHASE_IMP) {
      string nm = after_phase.get_name();
      after_phase = find(after_phase);
      if(after_phase is null) {
	uvm_fatal("PH_BAD_ADD",
		  "cannot find after_phase '" ~ nm ~ "' within node '" ~
		  get_name() ~ "'");
      }
    }

    if(with_phase !is null && (after_phase !is null ||
			       before_phase !is null)) {
      uvm_fatal("PH_BAD_ADD",
		"cannot specify both 'with' and 'before/after' "
		"phase relationships");
    }

    if(before_phase is this || after_phase is m_end_node ||
       with_phase is m_end_node) {
      uvm_fatal("PH_BAD_ADD",
		"cannot add before { node, after end node, or "
		"with end nodes");
    }

    // If we are inserting a new "leaf node"
    if(phase.get_phase_type() is UVM_PHASE_IMP) {
      new_node = new uvm_phase(phase.get_name(), UVM_PHASE_NODE, this);
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
      if(with_phase is this) {
      after_phase = this;
      before_phase = m_end_node;
      }
    */

    // If no before/after/with specified, insert at end of this schedule
    if(with_phase is null && after_phase is null && before_phase is null) {
      before_phase = m_end_node;
    }

    if(m_phase_trace) {
      uvm_phase_type typ = phase.get_phase_type();
      uvm_info("PH/TRC/ADD_PH",
	       get_name() ~ " (" ~ m_phase_type.to!string ~
	       ") ADD_PHASE: phase=" ~ phase.get_full_name() ~ " (" ~
	       typ.to!string ~ ", inst_id=" ~
	       format("%0d", phase.get_inst_id()) ~ ")" ~
	       " with_phase=" ~   ((with_phase is null)   ? "null" :
				   with_phase.get_name()) ~
	       " after_phase=" ~  ((after_phase is null)  ? "null" :
				   after_phase.get_name()) ~
	       " before_phase=" ~ ((before_phase is null) ? "null" :
				   before_phase.get_name()) ~
	       " new_node=" ~     ((new_node is null)     ? "null" :
				   (new_node.get_name() ~ " inst_id=",
				    format("%0d", new_node.get_inst_id()))) ~
	       " begin_node=" ~   ((begin_node is null)   ? "null" :
				   begin_node.get_name())  ~
	       " end_node=" ~     ((end_node is null)     ? "null" :
				   end_node.get_name()), UVM_DEBUG);
    }


    // INSERT IN PARALLEL WITH 'WITH' PHASE
    if(with_phase !is null) {
      begin_node.m_predecessors = with_phase.m_predecessors.dup;
      end_node.m_successors = with_phase.m_successors.dup;
      foreach(pred, unused; with_phase.m_predecessors) {
	pred.m_successors[begin_node] = true;
      }
      foreach(succ, unused; with_phase.m_successors) {
	succ.m_predecessors[end_node] = true;
      }
    }

    // INSERT BEFORE PHASE
    else if(before_phase !is null && after_phase is null) {
      begin_node.m_predecessors = before_phase.m_predecessors.dup;
      end_node.m_successors[before_phase] = true;
      foreach(pred, unused; before_phase.m_predecessors) {
	pred.m_successors.remove(before_phase);
	pred.m_successors[begin_node] = true;
      }
      before_phase.m_predecessors.clear();
      before_phase.m_predecessors[end_node] = true;
    }


    // INSERT AFTER PHASE
    else if(before_phase is null && after_phase !is null) {
      end_node.m_successors = after_phase.m_successors.dup;
      begin_node.m_predecessors[after_phase] = true;
      foreach(succ, unused; after_phase.m_successors) {
	succ.m_predecessors.remove(after_phase);
	succ.m_predecessors[end_node] = true;
      }
      after_phase.m_successors.remove();
      after_phase.m_successors[begin_node] = true;
    }

    // IN BETWEEN 'BEFORE' and 'AFTER' PHASES
    else if(before_phase !is null && after_phase !is null) {
      if(!after_phase.is_before(before_phase)) {
	uvm_fatal("PH_ADD_PHASE", "Phase '" ~ before_phase.get_name() ~
		  "' is not before phase '" ~ after_phase.get_name() ~ "'");
      }
      // before and after? add 1 pred and 1 succ
      begin_node.m_predecessors[after_phase] = true;
      end_node.m_successors[before_phase] = true;
      after_phase.m_successors[begin_node] = true;
      before_phase.m_predecessors[end_node] = true;
      if(before_phase in after_phase.m_successors) {
	after_phase.m_successors.remove(before_phase);
	before_phase.m_successors.remove(after_phase);
      }
    }
  }

  // Function: get_parent
  //
  // Returns the parent schedule node, if any, for hierarchical graph traversal
  //
  final public uvm_phase get_parent() {
    synchronized(this) {
      return _m_parent;
    }
  }



  // Function: get_full_name
  //
  // Returns the full path from the enclosing domain down to this node.
  // The singleton IMP phases have no hierarchy.
  //
  override public string get_full_name() {
    synchronized(this) {
      // string dom; -- redundant in SV implementation
      if(m_phase_type is UVM_PHASE_IMP) {
	return get_name();
      }
      string retval = get_domain_name();
      string sch = get_schedule_name();
      if(sch != "") {
	retval ~= "." ~ sch;
      }
      if(m_phase_type !is UVM_PHASE_DOMAIN &&
	 m_phase_type !is UVM_PHASE_SCHEDULE) {
	retval ~= "." ~ get_name();
      }
      return retval;
    }
  }


  // Function: get_schedule
  //
  // Returns the topmost parent schedule node, if any, for hierarchical graph traversal
  //
  final public uvm_phase get_schedule(bool hier = false) {
    uvm_phase sched = this;
    if(hier) {
      while(sched.m_parent !is null &&
	    (sched.m_parent.get_phase_type() is UVM_PHASE_SCHEDULE)) {
	sched = sched.m_parent;
      }
    }
    if(sched.m_phase_type is UVM_PHASE_SCHEDULE) {
      return sched;
    }
    if(sched.m_phase_type is UVM_PHASE_NODE) {
      auto parent = m_parent;
      if(parent !is null && parent.m_phase_type !is UVM_PHASE_DOMAIN) {
	return parent;
      }
    }
    return null;
  }


  // Function: get_schedule_name
  //
  // Returns the schedule name associated with this phase node
  //
  final public string get_schedule_name(bool hier = 0) {
    uvm_phase sched = get_schedule(hier);
    if(sched is null) {
      return "";
    }
    string s = sched.get_name();
    while(sched.m_parent !is null && sched.m_parent !is sched &&
	  (sched.m_parent.get_phase_type() is UVM_PHASE_SCHEDULE)) {
      sched = sched.m_parent;
      s = sched.get_name() ~ (s.length > 0 ? "." : "")  ~ s;
    }
    return s;
  }


  // Function: get_domain
  //
  // Returns the enclosing domain
  //
  final public uvm_domain get_domain() {
    uvm_phase phase = this;
    while(phase !is null && phase.m_phase_type !is UVM_PHASE_DOMAIN) {
      phase = phase.m_parent;
    }
    if(phase is null) { // no parent domain
      return null;
    }
    auto retval = cast(uvm_domain) phase;
    if(retval is null) {
      uvm_fatal("PH/INTERNAL", "get_domain: m_phase_type is DOMAIN but "
		"$cast to uvm_domain fails");
    }
    return retval;
  }


  // Function: get_imp
  //
  // Returns the phase implementation for this this node.
  // Returns null if this phase type is not a UVM_PHASE_LEAF_NODE.
  //
  final public uvm_phase get_imp() {
    synchronized(this) {
      return _m_imp;
    }
  }

  // Function: get_domain_name
  //
  // Returns the domain name associated with this phase node
  //
  final public string get_domain_name() {
    uvm_domain domain = get_domain();
    if(domain is null) {
      return "unknown";
    }
    return domain.get_name();
  }

  //-----------------------
  // Group: Synchronization
  //-----------------------

  // Function: get_objection
  //
  // Return the <uvm_objection> that gates the termination of the phase.
  //
  final public uvm_objection get_objection() {
    synchronized(this) {
      return _phase_done;
    }
  }


  // Function: raise_objection
  //
  // Raise an objection to ending this phase
  // Provides components with greater control over the phase flow for
  // processes which are not implicit objectors to the phase.
  //
  //|   while(1) {
  //|     some_phase.raise_objection(this);
  //|     ...
  //|     some_phase.drop_objection(this);
  //|   }
  //|   ...
  //
  final public void raise_objection(uvm_object obj,
				    string description="",
				    int count=1) {
    phase_done.raise_objection(obj, description, count);
  }


  // Function: drop_objection
  //
  // Drop an objection to ending this phase
  //
  // The drop is expected to be matched with an earlier raise.
  //
  final public void drop_objection(uvm_object obj,
				   string description="",
				   int count=1) {
    phase_done.drop_objection(obj, description, count);
  }



  // Functions: sync and unsync
  //
  // Add soft sync relationships between nodes
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


  // Function: sync
  //
  // Synchronize two domains, fully or partially
  //
  //   target       - handle of target domain to synchronize this one to
  //   phase        - optional single phase in this domain to synchronize,
  //                  otherwise sync all
  //   with_phase   - optional different target-domain phase to synchronize with,
  //                  otherwise use ~phase~ in the target domain
  //
  final public void sync(uvm_domain target,
			 uvm_phase phase = null,
			 uvm_phase with_phase = null) {
    if(!this.is_domain()) {
      uvm_fatal("PH_BADSYNC","sync() called from a non-domain phase "
		"schedule node");
    }
    else if(target is null) {
      uvm_fatal("PH_BADSYNC","sync() called with a null target domain");
    }
    else if(!target.is_domain()) {
      uvm_fatal("PH_BADSYNC","sync() called with a non-domain phase "
		"schedule node as target");
    }
    else if(phase is null && with_phase !is null) {
      uvm_fatal("PH_BADSYNC","sync() called with null phase and non-null "
		"with phase");
    }
    else if(phase is null) {
      // whole domain sync - traverse this domain schedule from begin to end node and sync each node
      int[uvm_phase] visited;
      Queue!uvm_phase queue;
      queue.pushBack(this);
      visited[this] = true;
      while(queue.length !is 0) {
	uvm_phase node;
	node = queue.front();
	queue.removeFront();
	if(node.m_imp !is null) {
	  sync(target, node.m_imp);
	}
	foreach(succ, unused; node.m_successors) {
	  if(succ !in visited) {
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
      if(with_phase is null) with_phase = phase;
      uvm_phase from_node = find(phase);
      uvm_phase to_node = target.find(with_phase);
      if(from_node is null || to_node is null) return;
      // m_sync is a Queue of uvm_phase
      from_node.add_sync(to_node);
      to_node.add_sync(from_node);
    }
  }

  // Function: unsync
  //
  // Remove synchronization between two domains, fully or partially
  //
  //   target       - handle of target domain to remove synchronization from
  //   phase        - optional single phase in this domain to un-synchronize,
  //                  otherwise unsync all
  //   with_phase   - optional different target-domain phase to un-synchronize with,
  //                  otherwise use ~phase~ in the target domain
  //

  final public void unsync(uvm_domain target,
			   uvm_phase phase = null,
			   uvm_phase with_phase = null) {
    if(!this.is_domain()) {
      uvm_fatal("PH_BADSYNC","unsync() called from a non-domain phase "
		"schedule node");
    }
    else if(target is null) {
      uvm_fatal("PH_BADSYNC","unsync() called with a null target domain");
    }
    else if(!target.is_domain()) {
      uvm_fatal("PH_BADSYNC","unsync() called with a non-domain phase "
		"schedule node as target");
    }
    else if(phase is null && with_phase !is null) {
      uvm_fatal("PH_BADSYNC","unsync() called with null phase and non-null "
		"with phase");
    }
    else if(phase is null) {
      // whole domain unsync - traverse this domain schedule from begin to end node and unsync each node
      int[uvm_phase] visited;
      Queue!uvm_phase queue;
      queue.pushBack(this);
      visited[this] = true;
      while(queue.length !is 0) {
	uvm_phase node;
	node = queue.front();
	queue.removeFront();
	if(node.m_imp !is null) unsync(target, node.m_imp);
	foreach(succ, unused; node.m_successors) {
	  if(succ !in visited) {
	    queue.pushBack(succ);
	    visited[succ] = true;
	  }
	}
      }
    }
    else {
      // single phase unsync
      // this is a 2-way ('with') sync and we check first in case it is already there
      uvm_phase from_node = target.find(phase);
      uvm_phase to_node = target.find(phase);
      // m_sync is a Queue of uvm_phase
      from_node.rem_sync(to_node);
      to_node.rem_sync(from_node);
    }
  }

  // Function: wait_for_state
  //
  // Wait until this phase compares with the given ~state~ and ~op~ operand.
  // For <UVM_EQ> and <UVM_NE> operands, several <uvm_phase_states> can be
  // supplied by ORing their enum constants, in which case the caller will
  // wait until the phase state is any of (UVM_EQ) or none of (UVM_NE) the
  // provided states.
  //
  // To wait for the phase to be at the started state or after
  //
  //| wait_for_state(UVM_PHASE_STARTED, UVM_GTE);
  //
  // To wait for the phase to be either started or executing
  //
  //| wait_for_state(UVM_PHASE_STARTED | UVM_PHASE_EXECUTING, UVM_EQ);
  //

  // task
  final public void wait_for_state(uvm_phase_state state,
				   uvm_wait_op op = UVM_EQ) {
    final switch(op) {
      // wait((state & m_state) !is 0);
    case UVM_EQ:  while((m_state.get & state) is 0)
	m_state.getEvent.wait();
      break;
      // wait((state & m_state) is 0);
    case UVM_NE:  while((m_state.get & state) !is 0)
	m_state.getEvent.wait();
      break;
      // wait(m_state <  state);
    case UVM_LT:  while(m_state.get >= state)
	m_state.getEvent.wait();
      break;
      // wait(m_state <=  state);
    case UVM_LTE: while(m_state.get > state)
	m_state.getEvent.wait();
      break;
      // wait(m_state >  state);
    case UVM_GT:  while(m_state.get <= state)
	m_state.getEvent.wait();
      break;
      // wait(m_state >=  state);
    case UVM_GTE: while(m_state.get < state)
	m_state.getEvent.wait();
      break;
    }
  }

  //---------------
  // Group: Jumping
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

  // Function: jump
  //
  // Jump to a specified ~phase~. If the destination ~phase~ is within the current
  // phase schedule, a simple local jump takes place. If the jump-to ~phase~ is
  // outside of the current schedule then the jump affects other schedules which
  // share the phase.
  //

  // jump
  // ----
  //
  // Note that this function does not directly alter flow of control.
  // That is, the new phase is not initiated in this function.
  // Rather, flags are set which execute_phase() uses to determine
  // that a jump has been requested and performs the jump.

  public void jump(uvm_phase phase) {
    // TBD refactor

    if((m_state.get <  UVM_PHASE_STARTED) ||
       (m_state.get >  UVM_PHASE_READY_TO_END) )
      {
	uvm_error("JMPPHIDL", "Attempting to jump from phase \"" ~
		  get_name() ~  "\" which is not currently active "
		  "(current state is " ~ _m_state.to!string ~  "). The "
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
    if(d is null) {
      d = m_find_successor(phase, false);
      if(d is null) {
	uvm_fatal("PH_BADJUMP",
		  format("phase %s is neither a predecessor or "
			 "successor of phase %s or is non-existant, "
			 "so we cannot jump to it. Phase control "
			 "flow is now undefined so the simulation "
			 "must terminate", phase.get_name(), get_name()));
      }
      else {
	m_jump_fwd = true;
	uvm_info("PH_JUMPF", format("jumping forward to phase %s",
				    phase.get_name()), UVM_DEBUG);
      }
    }
    else {
      m_jump_bkwd = true;
      uvm_info("PH_JUMPB", format("jumping backward to phase %s",
				  phase.get_name()), UVM_DEBUG);
    }

    m_jump_phase = d;
    // m_terminate_phase(); // JAR - not needed
  }


  // Function: jump_all
  //
  // Make all schedules jump to a specified ~phase~, even if the jump target is local.
  // The jump happens to all phase schedules that contain the jump-to ~phase~,
  // i.e. a global jump.
  //
  final public void jump_all(uvm_phase phase) {
    uvm_warning("NOTIMPL","uvm_phase.jump_all is not implemented and "
		"has been replaced by uvm_domain.jump_all");
  }

  // Function: get_jump_target
  //
  // Return handle to the target phase of the current jump, or null if no jump
  // is in progress. Valid for use during the phase_ended() callback
  //
  final public uvm_phase get_jump_target() {
    synchronized(this) {
      return _m_jump_phase;
    }
  }

  @uvm_public_sync
    uint _max_ready_to_end_iter = 20;

  //--------------------------
  // Internal - Implementation
  //--------------------------

  // Implementation - Construction
  //------------------------------

  // m_phase_type is set in the constructor and is not changed after that
  @uvm_immutable_sync
    protected uvm_phase_type _m_phase_type;

  @uvm_protected_sync
    protected uvm_phase _m_parent; // our 'schedule' node [or points 'up' one level]

  @uvm_public_sync
    public uvm_phase _m_imp; // phase imp to call when we execute this node

  // Implementation - State
  //-----------------------
  @uvm_immutable_sync
    private WithEvent!uvm_phase_state _m_state;

  private int                         _m_run_count; // num times this phase has executed
  @uvm_private_sync
    private Process                     _m_phase_proc;

  @uvm_public_sync
    private int                       _m_num_procs_not_yet_returned;

  final public void inc_m_num_procs_not_yet_returned() {
    synchronized(this) {
      ++_m_num_procs_not_yet_returned;
    }
  }
  final public void dec_m_num_procs_not_yet_returned() {
    synchronized(this) {
      --_m_num_procs_not_yet_returned;
    }
  }

  final public uvm_phase m_find_predecessor(uvm_phase phase,
					    bool stay_in_scope = true,
					    uvm_phase orig_phase = null) {
    //$display("  FIND PRED node '", phase.get_name(),"' (id=", $sformatf("%0d", phase.get_inst_id()),") - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(_m_imp is null)?"":{"/", $sformatf("%0d", _m_imp.get_inst_id())},")");
    if(phase is null) {
      return null ;
    }
    if(phase is m_imp || phase is this) {
      return this;
    }
    foreach(pred, unused; m_predecessors) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if(!stay_in_scope ||
	 (pred.get_schedule() is orig.get_schedule()) ||
	 (pred.get_domain() is orig.get_domain())) {
	uvm_phase found = pred.m_find_predecessor(phase, stay_in_scope, orig);
	if(found !is null) {
	  return found;
	}
      }
    }
    return null;
  }

  // m_find_successor
  // ----------------

  final public uvm_phase m_find_successor(uvm_phase phase,
					  bool stay_in_scope = true,
					  uvm_phase orig_phase = null) {
    //$display("  FIND SUCC node '", phase.get_name(),"' (id=", $sformatf("%0d", phase.get_inst_id()),") - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(_m_imp is null)?"":{"/", $sformatf("%0d", _m_imp.get_inst_id())},")");
    if(phase is null) {
      return null ;
    }
    if(phase is m_imp || phase is this) {
      return this;
    }
    foreach(succ, unused; m_successors) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if(!stay_in_scope ||
	 (succ.get_schedule() is orig.get_schedule()) ||
	 (succ.get_domain() is orig.get_domain())) {
	uvm_phase found = succ.m_find_successor(phase, stay_in_scope, orig);
	if(found !is null) {
	  return found;
	}
      }
    }
    return null;
  }

  // m_find_predecessor_by_name
  // --------------------------

  final public uvm_phase m_find_predecessor_by_name(string name,
						    bool stay_in_scope = true,
						    uvm_phase orig_phase = null) {
    //$display("  FIND PRED node '", name,"' - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(_m_imp is null)?"":{"/", $sformatf("%0d", _m_imp.get_inst_id())},")");
    if(get_name() == name) {
      return this;
    }
    foreach(pred, predecessor; m_predecessors) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if(!stay_in_scope ||
	 (pred.get_schedule() is orig.get_schedule()) ||
	 (pred.get_domain() is orig.get_domain())) {
	uvm_phase found =
	  pred.m_find_predecessor_by_name(name, stay_in_scope, orig);
	if(found !is null) {
	  return found;
	}
      }
    }
    return null;
  }



  // m_find_successor_by_name
  // ------------------------

  final public uvm_phase m_find_successor_by_name(string name,
						  bool stay_in_scope = true,
						  uvm_phase orig_phase = null) {
    //$display("  FIND SUCC node '", name,"' - checking against ", get_name()," (", m_phase_type.name()," id=", $sformatf("%0d", get_inst_id()),(_m_imp is null)?"":{"/", $sformatf("%0d", _m_imp.get_inst_id())},")");
    if(get_name() == name) {
      return this;
    }
    foreach(succ, successor; m_successors) {
      uvm_phase orig = (orig_phase is null) ? this : orig_phase;
      if(!stay_in_scope ||
	 (succ.get_schedule() is orig.get_schedule()) ||
	 (succ.get_domain() is orig.get_domain())) {
	uvm_phase found =
	  succ.m_find_successor_by_name(name, stay_in_scope, orig);
	if(found !is null) {
	  return found;
	}
      }
    }
    return null;
  }


  // m_print_successors
  // ------------------

  final public void m_print_successors() {
    enum string spaces = "                                                 ";
    static int level;
    if(m_phase_type is UVM_PHASE_DOMAIN) {
      level = 0;
    }
    vdisplay(spaces[0..level*2+1], get_name(), " (", m_phase_type.to!string,
	     ") id=%0d", get_inst_id());
    ++level;
    foreach(succ, unused; m_successors) {
      succ.m_print_successors();
    }
    --level;
  }


  // Implementation - Callbacks
  //---------------------------
  // Provide the required component traversal behavior. Called by execute()
  // function -- not task
  public void traverse(uvm_component comp,
		       uvm_phase phase,
		       uvm_phase_state state) {
  }
  // Provide the required per-component execution flow. Called by traverse()
  // function -- not task
  public void execute(uvm_component comp,
		      uvm_phase phase) {
  }

  // Implementation - Schedule
  //--------------------------
  @uvm_immutable_sync
    private SyncAssoc!(uvm_phase, bool) _m_predecessors;

  @uvm_immutable_sync
    private SyncAssoc!(uvm_phase, bool) _m_successors;

  @uvm_protected_sync
    private uvm_phase _m_end_node;

  final public uvm_phase get_begin_node() {
    synchronized(this) {
      if(_m_imp !is null) return this;
      else return null;
    }
  }

  final public uvm_phase get_end_node() {
    synchronized(this) {
      return _m_end_node;
    }
  }

  // Implementation - Synchronization
  //---------------------------------
  @uvm_private_sync
    private Queue!uvm_phase _m_sync; // schedule instance to which we are synced
  private void rem_sync(uvm_phase phase) {
    synchronized(this) {
      import std.algorithm: countUntil;
      auto c = countUntil(_m_sync[], phase);
      if(c !is -1) _m_sync.remove(c);
    }
  }
  private void add_sync(uvm_phase phase) {
    synchronized(this) {
      import std.algorithm: canFind;
      if(!canFind(_m_sync[], phase)) _m_sync.pushBack(phase);
    }
  }

  @uvm_immutable_sync
    uvm_objection _phase_done; // phase done objection

  @uvm_private_sync
    private uint _m_ready_to_end_count;

  final public uint get_ready_to_end_count() {
    synchronized(this) {
      return _m_ready_to_end_count;
    }
  }

  final public void
    get_predecessors_for_successors(out bool[uvm_phase] pred_of_succ) {
    // This synchronization guard results in deadlock
    // synchronized(this) {
    bool done;
    bool[uvm_phase] successors;

    // get all successors
    // This is basically the dup operation
    foreach(succ, unused; m_successors) {
      successors[succ] = true;
    }

    // replace TERMINAL or SCHEDULE nodes with their successors
    do {
      done = true;
      foreach(succ; successors.keys) {
	if(succ.get_phase_type() !is UVM_PHASE_NODE) {
	  successors.remove(succ);
	  foreach(next_succ, unused; succ.m_successors) {
	    successors[next_succ] = true;
	  }
	  done = false;
	}
      }
    } while(!done);

    // get all predecessors to these successors
    foreach(succ, unused; successors) {
      foreach(pred, unused; succ.m_predecessors) {
	pred_of_succ[pred] = true;
      }
    }

    // replace any terminal nodes with their predecessors, recursively.
    // we are only interested in "real" phase nodes
    do {
      done = true;
      foreach(pred; pred_of_succ.keys) {
	if(pred.get_phase_type() !is UVM_PHASE_NODE) {
	  pred_of_succ.remove(pred);
	  foreach(next_pred, unused; pred.m_predecessors) {
	    pred_of_succ[next_pred] = true;
	  }
	  done = false;
	}
      }
    } while(!done);


    // remove ourselves from the list
    pred_of_succ.remove(this);
    // }
  }

  // m_wait_for_pred
  // ---------------

  // task
  final public void m_wait_for_pred() {

    if(!(m_jump_fwd.get || m_jump_bkwd.get)) {

      bool[uvm_phase] pred_of_succ;
      get_predecessors_for_successors(pred_of_succ);

      // wait for predecessors to successors (real phase nodes, not terminals)
      // mostly debug msgs
      foreach (sibling, unused; pred_of_succ) {
	if (m_phase_trace) {
	  string s = format("Waiting for phase '%s' (%0d) to be "
			    "READY_TO_END. Current state is %s",
			    sibling.get_name(), sibling.get_inst_id(),
			    sibling.m_state());
	  UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC", s, this, UVM_HIGH);
	}

	sibling.wait_for_state(UVM_PHASE_READY_TO_END, UVM_GTE);

	if (m_phase_trace) {
	  string s = format("Phase '%s' (%0d) is now READY_TO_END. "
			    "Releasing phase",
			    sibling.get_name(),sibling.get_inst_id());
	  UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC",s,this,UVM_HIGH);
	}
      }

      if(m_phase_trace) {
	if(pred_of_succ.length !is 0) {
	  string s = "( ";
	  foreach(pred, unused; pred_of_succ) {
	    s ~= pred.get_full_name() ~ " ";
	  }
	  s ~= s ~ ")";
	  UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC",
		       "*** All pred to succ " ~ s ~
		       " in READY_TO_END state, so ending phase ***",
		       this, UVM_HIGH);
	}
	else {
	  UVM_PH_TRACE("PH/TRC/WAIT_PRED_OF_SUCC",
		       "*** No pred to succ other than myself, "
		       "so ending phase ***", this, UVM_HIGH);
	}
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

  // clear
  // -----
  // for internal graph maintenance after a forward jump
  final public void clear(uvm_phase_state state = UVM_PHASE_DORMANT) {
    synchronized(this) {
      _m_state = state;
      _m_phase_proc = null;
    }
    phase_done.clear(this);
  }


  // clear_successors
  // ----------------
  // for internal graph maintenance after a forward jump
  // - called only by execute_phase()
  // - depth-first traversal of the DAG, calliing clear() on each node
  // - do not clear the end phase or beyond
  final public void clear_successors(uvm_phase_state state = UVM_PHASE_DORMANT,
				     uvm_phase end_state = null) {
    if(this is end_state) return;
    clear(state);
    foreach(succ, unused; m_successors) {
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
  static public void m_run_phases() {
    uvm_root top = uvm_root.get();

    // initiate by starting first phase in common domain
    uvm_phase ph = uvm_domain.get_common_domain();
    m_phase_hopper.try_put(ph);

    for(;;) {
      uvm_phase phase;
      m_phase_hopper.get(phase);
      fork!("uvm_phases/run_phases")({
	  phase.execute_phase();
	});
      wait(0);	// #0;		// let the process start running
    }
  }

  // execute_phase
  // -------------

  // task
  void execute_phase() {

    uvm_task_phase task_phase;
    uvm_root top = uvm_root.get();

    // If we got here by jumping forward, we must wait for
    // all its predecessor nodes to be marked DONE.
    // (the next conditional speeds this up)
    // Also, this helps us fast-forward through terminal (end) nodes
    foreach(pred, unused; m_predecessors) {
      while(pred.m_state.get !is UVM_PHASE_DONE) {
	pred.m_state.getEvent.wait();
      }
    }

    // If DONE (by, say, a forward jump), return immed
    if(m_state is UVM_PHASE_DONE) {
      return;
    }


    //---------
    // SYNCING:
    //---------
    // Wait for phases with which we have a sync()
    // relationship to be ready. Sync can be 2-way -
    // this additional state avoids deadlock.
    if(m_sync.length != 0) {
      m_state = UVM_PHASE_SYNCING;
      foreach(sync; m_sync[]) {
	while(sync.m_state.get < UVM_PHASE_SYNCING) {
	  sync.m_state.getEvent.wait();
	}
      }
    }

    synchronized(this) {
      _m_run_count++;


      if(_m_phase_trace) {
	UVM_PH_TRACE("PH/TRC/STRT","Starting phase", this, UVM_LOW);
      }
    }

    // If we're a schedule or domain, then "fake" execution
    if(m_phase_type !is UVM_PHASE_NODE) {
      m_state = UVM_PHASE_STARTED;
      wait(0);			// #0;
      m_state = UVM_PHASE_EXECUTING;
      wait(0);			// #0;
    }


    else { // PHASE NODE

      //---------
      // STARTED:
      //---------
      m_state = UVM_PHASE_STARTED;
      m_imp.traverse(top, this, UVM_PHASE_STARTED);
      m_ready_to_end_count = 0 ; // reset the ready_to_end count when phase starts

      // #0; // LET ANY WAITERS WAKE UP
      wait(0);

      task_phase = cast(uvm_task_phase) m_imp;

      //if(_m_imp.get_phase_type() !is UVM_PHASE_TASK) {
      if(task_phase is null) {

	//-----------
	// EXECUTING: (function phases)
	//-----------
	m_state = UVM_PHASE_EXECUTING;
	wait(0);
	m_imp.traverse(top, this, UVM_PHASE_EXECUTING);
      }
      else {
	m_executing_phases[this] = true;

	m_phase_proc = fork!("uvm_phases/m_phase_proc")({
	    //-----------
	    // EXECUTING: (task phases)
	    //-----------
	    m_state = UVM_PHASE_EXECUTING;

	    task_phase.traverse(top, this, UVM_PHASE_EXECUTING);

	    // wait(0) -- SV version
	    sleep();
	  });

	uvm_wait_for_nba_region(); //Give sequences, etc. a chance to object

	// Now wait for one of three criterion for end-of-phase.
	// Fork guard = join({
	Fork end_phase = fork!("uvm_phases/end_phase")({ // JUMP
	    while((m_jump_fwd.get || m_jump_bkwd.get) is false) {
	      wait(m_jump_fwd.getEvent | m_jump_bkwd.getEvent);
	    }
	    UVM_PH_TRACE("PH/TRC/EXE/JUMP","PHASE EXIT ON JUMP REQUEST",
			 this, UVM_DEBUG);
	  },
	  { // WAIT_FOR_ALL_DROPPED

	    bool do_ready_to_end  ; // bit used for ready_to_end iterations
	    // OVM semantic: don't end until objection raised or stop request
	    if(phase_done.get_objection_total(top) ||
	       m_use_ovm_run_semantic && m_imp.get_name() == "run") {
	      if (!phase_done.m_top_all_dropped) {
		phase_done.wait_for(UVM_ALL_DROPPED, top);
	      }
	      UVM_PH_TRACE("PH/TRC/EXE/ALLDROP","PHASE EXIT ALL_DROPPED",
			   this, UVM_DEBUG);
	    }
	    else {
	      if (m_phase_trace) {
		UVM_PH_TRACE("PH/TRC/SKIP","No objections raised, "
			     "skipping phase", this, UVM_LOW);
	      }
	    }

	    wait_for_self_and_siblings_to_drop();
	    do_ready_to_end = true;

	    //--------------
	    // READY_TO_END:
	    //--------------

	    while(do_ready_to_end) {
	      uvm_wait_for_nba_region(); // Let all siblings see no objections before traverse might raise another
	      UVM_PH_TRACE("PH_READY_TO_END","PHASE READY TO END",
			   this, UVM_DEBUG);
	      synchronized(this) {
		++_m_ready_to_end_count;
		if(_m_phase_trace)
		  UVM_PH_TRACE("PH_READY_TO_END_CB","CALLING READY_TO_END CB",
			       this, UVM_HIGH);
		_m_state = UVM_PHASE_READY_TO_END;
	      }
	      if(m_imp !is null) {
		m_imp.traverse(top, this, UVM_PHASE_READY_TO_END);
	      }

	      uvm_wait_for_nba_region(); // Give traverse targets a chance to object

	      wait_for_self_and_siblings_to_drop();

	      synchronized(this) {
		//when we don't wait in task above, we drop out of while loop
		do_ready_to_end = (_m_state is UVM_PHASE_EXECUTING) &&
		  (_m_ready_to_end_count < _max_ready_to_end_iter) ;
	      }
	    }
	  },
	  { // TIMEOUT
	    if(this.get_name() == "run") {
	      while(top.m_phase_timeout.get == SimTime(0)) {
		wait(top.m_phase_timeout.getEvent);
	      }

	      if(m_phase_trace) {
		UVM_PH_TRACE("PH/TRC/TO_WAIT",
			     format("STARTING PHASE TIMEOUT WATCHDOG"
				    " (timeout == %t)", top.m_phase_timeout),
			     this, UVM_HIGH);
	      }

	      wait(top.m_phase_timeout.get);

	      if(getRootEntity().getSimTime() == uvm_default_timeout()) {
		if(m_phase_trace) {
		  UVM_PH_TRACE("PH/TRC/TIMEOUT", "PHASE TIMEOUT WATCHDOG "
			       "EXPIRED", this, UVM_LOW);
		}
		foreach(p, unused; m_executing_phases) {
		  if(p.phase_done.get_objection_total() > 0) {
		    if(m_phase_trace)
		      UVM_PH_TRACE("PH/TRC/TIMEOUT/OBJCTN",
				   format("Phase '%s' has outstanding "
					  "objections:\n%s",
					  p.get_full_name(),
					  p.phase_done.convert2string()),
				   this, UVM_LOW);
		  }
		}

		uvm_fatal("PH_TIMEOUT",
			  format("Default timeout of %0t hit, indicating "
				 "a probable testbench issue",
				 uvm_default_timeout()));
	      }
	      else {
		if(m_phase_trace) {
		  UVM_PH_TRACE("PH/TRC/TIMEOUT", "PHASE TIMEOUT WATCHDOG "
			       "EXPIRED", this, UVM_LOW);
		}
		foreach(p, unused; m_executing_phases) {
		  if(p.phase_done.get_objection_total() > 0) {
		    if(m_phase_trace)
		      UVM_PH_TRACE("PH/TRC/TIMEOUT/OBJCTN",
				   format("Phase '%s' has outstanding "
					  "objections:\n%s",
					  p.get_full_name(),
					  p.phase_done.convert2string()),
				   this, UVM_LOW);
		  }
		}

		uvm_fatal("PH_TIMEOUT",
			  format("Explicit timeout of %0t hit, indicating "
				 "a probable testbench issue",
				 top.m_phase_timeout));
	      }
	      if(_m_phase_trace)
		UVM_PH_TRACE("PH/TRC/EXE/3","PHASE EXIT TIMEOUT",
			     this, UVM_DEBUG);
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

    m_executing_phases.remove(this);

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

    if(get_phase_type is UVM_PHASE_NODE) {

      if(m_jump_fwd.get || m_jump_bkwd.get) {

	uvm_info("PH_JUMP",
		 format("phase %s (schedule %s, domain %s) is "
			"jumping to phase %s", get_name(),
			get_schedule_name(), get_domain_name(),
			m_jump_phase.get_name()),
		 UVM_MEDIUM);

	wait(0); // #0; // LET ANY WAITERS ON READY_TO_END TO WAKE UP

	// execute 'phase_ended' callbacks
	synchronized(this) {
	  if(_m_phase_trace) {
	    UVM_PH_TRACE("PH_END","JUMPING OUT OF PHASE", this, UVM_HIGH);
	  }
	  _m_state = UVM_PHASE_ENDED;
	}
	if(m_imp !is null) {
	  m_imp.traverse(top, this, UVM_PHASE_ENDED);
	}

	wait(0); // LET ANY WAITERS WAKE UP

	synchronized(this) {
	  _m_state = UVM_PHASE_JUMPING;
	  if(_m_phase_proc !is null) {
	    _m_phase_proc.abort();
	    _m_phase_proc = null;
	  }
	}

	wait(0); // LET ANY WAITERS WAKE UP


	phase_done.clear();

	if(m_jump_fwd.get) {
	  clear_successors(UVM_PHASE_DONE, m_jump_phase);
	}

	m_jump_phase.clear_successors();

	synchronized(this) {
	  _m_jump_fwd = false;
	  _m_jump_bkwd = false;
	  _m_phase_hopper.try_put(_m_jump_phase);
	  _m_jump_phase = null;
	  return;
	}
      }

      // WAIT FOR PREDECESSORS:  // WAIT FOR PREDECESSORS:
      // function phases only
      if(task_phase is null) {
	m_wait_for_pred();
      }

      //-------
      // ENDED:
      //-------
      // execute 'phase_ended' callbacks
      synchronized(this) {
	if(_m_phase_trace) {
	  UVM_PH_TRACE("PH_END","ENDING PHASE", this, UVM_HIGH);
	}
	_m_state = UVM_PHASE_ENDED;
      }

      if(m_imp !is null) {
	m_imp.traverse(top, this, UVM_PHASE_ENDED);
      }

      wait(0); // LET ANY WAITERS WAKE UP

      //---------
      // CLEANUP:
      //---------
      // kill this phase's threads
      synchronized(this) {
	_m_state = UVM_PHASE_CLEANUP;
	if(_m_phase_proc !is null) {
	  _m_phase_proc.abort();
	  _m_phase_proc = null;
	}
      }

      wait(0); // LET ANY WAITERS WAKE UP

      phase_done.clear();

    }


    //------
    // DONE:
    //------
    synchronized(this) {
      if(_m_phase_trace)
	UVM_PH_TRACE("PH/TRC/DONE","Completed phase", this, UVM_LOW);
      _m_state = UVM_PHASE_DONE;
      _m_phase_proc = null;
    }

    wait(0); // LET ANY WAITERS WAKE UP



    //-----------
    // SCHEDULED:
    //-----------
    // If more successors, schedule them to run now

    if(m_successors.length is 0) {
      top.m_phase_all_done = true;
    }
    else {
      // execute all the successors
      foreach(succ, unused; m_successors) {
	if(succ.m_state < UVM_PHASE_SCHEDULED) {
	  succ.m_state = UVM_PHASE_SCHEDULED;
	  wait(0); // LET ANY WAITERS WAKE UP
	  synchronized(this) {
	    m_phase_hopper.try_put(succ);
	    if(_m_phase_trace)
	      UVM_PH_TRACE("PH/TRC/SCHEDULED", "Scheduled from phase " ~
			   get_full_name(), succ, UVM_LOW);
	  }
	}
      }
    }
  }

  // terminate_phase
  // ---------------

  void m_terminate_phase() {
    synchronized(this) {
      _phase_done.clear(this);
    }
  }


  // print_termination_state
  // -----------------------

  private void m_print_termination_state() {
    synchronized(this) {
      uvm_info("PH_TERMSTATE",
	       format("phase %s outstanding objections = %0d", get_name(),
		      _phase_done.get_objection_total(uvm_root.get())),
	       UVM_DEBUG);
    }
  }



  // task
  final public void wait_for_self_and_siblings_to_drop() {
    bool need_to_check_all = true;
    uvm_root top = uvm_root.get();
    bool[uvm_phase] siblings;

    get_predecessors_for_successors(siblings);

    foreach(s; m_sync[]) {
      siblings[s] = true;
    }

    while(need_to_check_all) {
      need_to_check_all = false ; //if all are dropped, we won't need to do this again

      // wait for own objections to drop
      if(phase_done.get_objection_total(top) !is 0) {
	m_state = UVM_PHASE_EXECUTING;
	phase_done.wait_for(UVM_ALL_DROPPED, top);
	need_to_check_all = true;
      }

      // now wait for siblings to drop
      foreach(sib, unused; siblings) {
	sib.wait_for_state(UVM_PHASE_EXECUTING, UVM_GTE); // sibling must be at least executing
	if(sib.phase_done.get_objection_total(top) !is 0) {
	  m_state = UVM_PHASE_EXECUTING ;
	  sib.phase_done.wait_for(UVM_ALL_DROPPED, top); // sibling must drop any objection
	  need_to_check_all = true;
	}
      }
    }
  }

  // kill
  // ----

  final public void kill() {
    synchronized(this) {
      uvm_info("PH_KILL", "killing phase '" ~ get_name() ~ "'", UVM_DEBUG);

      if(_m_phase_proc !is null) {
	_m_phase_proc.abort();
	_m_phase_proc = null;
      }

    }
  }


  // kill_successors
  // ---------------

  // Using a depth-first traversal, kill all the successor phases of the
  // current phase.
  final public void kill_successors() {
    foreach(succ, unused; m_successors)
      succ.kill_successors();
    kill();
  }


  // TBD add more useful debug
  //---------------------------------

  override  public string convert2string() {
    synchronized(this) {
      //return $sformatf("PHASE %s = %p", get_name(), this);
      string s = format("phase: %s parent=%s  pred=%s  succ=%s", get_name(),
			(_m_parent is null) ? "null" : get_schedule_name(),
			m_aa2string(m_predecessors),
			m_aa2string(m_successors));
      return s;
    }
  }

  final private string m_aa2string(SyncAssoc!(uvm_phase, bool) aa) { // TBD tidy
    int i;
    string s = "'{ ";
    foreach(ph, unused; aa) {
      uvm_phase n = ph;
      s ~=  (n is null) ? "null" : n.get_name() ~
	(i is aa.length-1) ? "" : " ~  ";
      ++i;
    }
    s ~= " }";
    return s;
  }

  final public bool is_domain() {
    synchronized(this) {
      return(m_phase_type is UVM_PHASE_DOMAIN);
    }
  }

  // public void m_get_transitive_children(ref Queue!uvm_phase phases) {
  //   synchronized(this) {
  //     foreach(succ, unused; _m_successors)
  //	{
  //	  phases.pushBack(succ);
  //	  succ.m_get_transitive_children(phases);
  //	}
  //   }
  // }

  // public void m_get_transitive_children(ref uvm_phase[] phases) {
  //   synchronized(this) {
  //     foreach(succ, unused; _m_successors)
  //	{
  //	  phases ~= succ;
  //	  succ.m_get_transitive_children(phases);
  //	}
  //   }
  // }

  final public uvm_phase[] m_get_transitive_children() {
    uvm_phase[] phases;
    foreach(succ, unused; m_successors)
      {
	phases ~= succ;
	phases ~= succ.m_get_transitive_children();
      }
    return phases;
  }

}

//------------------------------------------------------------------------------
//                               IMPLEMENTATION
//------------------------------------------------------------------------------

public void UVM_PH_TRACE(string file=__FILE__,
			 size_t line=__LINE__)(string ID, string MSG,
					       uvm_phase PH,
					       uvm_verbosity VERB) {
  uvm_info!(file, line)(ID, format("Phase '%0s' (id=%0d) ",
				   PH.get_full_name(), PH.get_inst_id()) ~
			MSG, VERB);
}
