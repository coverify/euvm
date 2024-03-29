//
//----------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2010-2012 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2014 Cisco Systems, Inc.
// Copyright 2014 Intel Corporation
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

module uvm.base.uvm_objection;


import uvm.base.uvm_callback: uvm_callbacks, uvm_callback, uvm_register_cb;
import uvm.base.uvm_object_globals: uvm_objection_event;
import uvm.base.uvm_registry: uvm_object_registry;

import uvm.meta.misc;
import uvm.meta.meta;

import esdl.base.core: Event, SimTime, Process,
  waitForks, wait, Fork, fork, getRootEntity;
import esdl.data.sync;
import esdl.data.time;

import std.string: format;
import std.algorithm.searching;
import std.string : lastIndexOf;

// version (UVM_NO_DEPRECATED) { }
//  else {
//    version = UVM_INCLUDE_DEPRECATED;
//  }

alias uvm_objection_cbs_t =
  uvm_callbacks!(uvm_objection, uvm_objection_callback); /* @uvm-ieee 1800.2-2020 auto D.4.2*/

// typedef class uvm_cmdline_processor;
// typedef class uvm_callbacks_objection;

class uvm_objection_events {
  mixin (uvm_sync_string);
  @uvm_private_sync
  private int _waiters;
  private void inc_waiters() {
    synchronized (this) {
      _waiters += 1;
    }
  }
  private void dec_waiters() {
    synchronized (this) {
      _waiters -= 1;
    }
  }
  @uvm_immutable_sync
  private Event _raised;
  @uvm_immutable_sync
  private Event _dropped;
  @uvm_immutable_sync
  private Event _all_dropped;
  this() {
    synchronized (this) {
      _raised.initialize("_raised");
      _dropped.initialize("_dropped");
      _all_dropped.initialize("_all_dropped");
    }
  }
}

import uvm.meta.misc;
import uvm.meta.meta;
import uvm.base.uvm_report_object: uvm_report_object;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_scope;

import esdl.data.time: sec;
import esdl.base.core: EntityIntf;
import esdl.data.queue;

import esdl.rand.misc: rand;

//------------------------------------------------------------------------------
// Title -- NODOCS -- Objection Mechanism
//------------------------------------------------------------------------------
// The following classes define the objection mechanism and end-of-test
// functionality, which is based on <uvm_objection>.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_objection
//
//------------------------------------------------------------------------------
// Objections provide a facility for coordinating status information between
// two or more participating components, objects, and even module-based IP.
//
// Tracing of objection activity can be turned on to follow the activity of
// the objection mechanism. It may be turned on for a specific objection
// instance with <uvm_objection.trace_mode>, or it can be set for all
// objections from the command line using the option +UVM_OBJECTION_TRACE.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 10.5.1
// @uvm-ieee 1800.2-2020 auto 10.5.1.1
class uvm_objection: uvm_report_object, rand.disable
{
  mixin uvm_register_cb!(uvm_objection_callback);

  mixin (uvm_sync_string);

  static class uvm_scope: uvm_scope_base
  {
    @uvm_none_sync
    private uvm_objection[] _m_objections;

    //// Drain Logic

    // The context pool holds used context objects, so that
    // they're not constantly being recreated.  The maximum
    // number of contexts in the pool is equal to the maximum
    // number of simultaneous drains you could have occuring,
    // both pre and post forks.
    //
    // There's the potential for a programmability within the
    // library to dictate the largest this pool should be allowed
    // to grow, but that seems like overkill for the time being.
    @uvm_none_sync
    private Queue!(uvm_objection_context_object) _m_context_pool;

    // These are the contexts which have been scheduled for
    // retrieval by the background process, but which the
    // background process hasn't seen yet.
    @uvm_none_sync
    private Queue!uvm_objection_context_object _m_scheduled_list;

    @uvm_none_sync
    size_t m_scheduled_list_length() {
      synchronized (this) {
	return _m_scheduled_list.length;
      }
    }

    @uvm_none_sync
    void m_scheduled_list_pop_front(ref uvm_objection_context_object obj) {
      synchronized (this) {
	if (_m_scheduled_list.length == 0) {
	  obj = null;
	}
	else {
	  obj = _m_scheduled_list.front();
	  _m_scheduled_list.removeFront();
	}
      }
    }

    @uvm_immutable_sync
    private Event _m_scheduled_list_event;

    this() {
      synchronized (this) {
	_m_scheduled_list_event.initialize("_m_scheduled_list_event",
				     EntityIntf.getContextEntity());
      }
    }
  }


  mixin (uvm_scope_sync_string);

  @uvm_protected_sync
  private bool _m_trace_mode;
  private int[uvm_object] _m_source_count;
  private int[uvm_object] _m_total_count;
  private SimTime[uvm_object] _m_drain_time;
  private uvm_objection_events[uvm_object] _m_events;
  @uvm_public_sync
  private bool _m_top_all_dropped;

  // import uvm.base.uvm_root: uvm_root;
  // uvm_root m_top = uvm_root.get();
  
  // static protected uvm_root m_top() {
  //   import uvm.base.uvm_coreservice;
  //   uvm_coreservice_t cs = uvm_coreservice_t.get();
  //   return cs.get_root();
  // }


  // These are the active drain processes, which have been
  // forked off by the background process.  A raise can
  // use this array to kill a drain.
  version (UVM_USE_PROCESS_CONTAINER) {
    private process_container_c[uvm_object] _m_drain_proc;
  }
  else {
    private Process[uvm_object] _m_drain_proc;
  }

  // Once a context is seen by the background process, it is
  // removed from the scheduled list, and placed in the forked
  // list.  At the same time, it is placed in the scheduled
  // contexts array.  A re-raise can use the scheduled contexts
  // array to detect (and cancel) the drain.
  private uvm_objection_context_object[uvm_object] _m_scheduled_contexts;

  private Queue!(uvm_objection_context_object) _m_forked_list;

  // Once the forked drain has actually started (this occurs
  // ~1 delta AFTER the background process schedules it), the
  // context is removed from the above array and list, and placed
  // in the forked_contexts list.
  private uvm_objection_context_object[uvm_object] _m_forked_contexts;

  @uvm_private_sync
  private bool _m_prop_mode = true;


  @uvm_protected_sync
  private bool _m_cleared; /* for checking obj count<0 */


  // Function -- NODOCS -- new
  //
  // Creates a new objection instance. Accesses the command line
  // argument +UVM_OBJECTION_TRACE to turn tracing on for
  // all objection objects.

  // @uvm-ieee 1800.2-2020 auto 10.5.1.2
  this(string name="") {
    import uvm.base.uvm_cmdline_processor;
    import uvm.base.uvm_root: uvm_root;
    synchronized (this) {
      uvm_root m_top = uvm_root.get();

      string[] trace_args;
      super(name);
      set_report_verbosity_level(m_top.get_report_verbosity_level());

      // Get the command line trace mode setting
      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
      if (clp.get_arg_matches(`+UVM_OBJECTION_TRACE`, trace_args)) {
	_m_trace_mode = true;
      }

      synchronized (_uvm_scope_inst) {
	_uvm_scope_inst._m_objections ~= this;
      }

    }
  }

  // Function -- NODOCS -- trace_mode
  //
  // Set or get the trace mode for the objection object. If no
  // argument is specified (or an argument other than 0 or 1)
  // the current trace mode is unaffected. A trace_mode of
  // 0 turns tracing off. A trace mode of 1 turns tracing on.
  // The return value is the mode prior to being reset.

  final bool trace_mode(int mode = -1) {
    synchronized (this) {
      bool trace_mode_ = _m_trace_mode;
      if (mode is 0) {
	_m_trace_mode = false;
      }
      else if (mode is 1) {
	_m_trace_mode = true;
      }
      return trace_mode_;
    }
  }

  // Function- m_report
  //
  // Internal method for reporting count updates

  final void m_report(uvm_object obj, uvm_object source_obj,
		      lazy string description, int count, string action) {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    synchronized (this) {
      int* psource = obj in _m_source_count;
      int* ptotal = obj in _m_total_count;
      int count_ = (psource !is null) ? *psource : 0;
      int total_ = (ptotal !is null) ? *ptotal : 0;

      if (!uvm_report_enabled(uvm_verbosity.UVM_NONE, uvm_severity.UVM_INFO, "OBJTN_TRC") ||
	 ! _m_trace_mode) {
	return;
      }

      string description_ = description();

      if (source_obj is obj) {
	uvm_report_info("OBJTN_TRC",
			format("Object %0s %0s %0d objection(s)%s: " ~
			       "count=%0d  total=%0d",
			       (obj.get_full_name() == "") ?
			       "uvm_top" : obj.get_full_name(),
			       action, count,
			       (description_ != "") ?
			       " (" ~ description_ ~ ")" : "",
			       count_, total_), uvm_verbosity.UVM_NONE);
      }
      else {
	size_t cpath = 0;
	size_t last_dot = 0;
	string sname = source_obj.get_full_name();
	string nm = obj.get_full_name();
	size_t max = sname.length > nm.length ? nm.length : sname.length;

	// For readability, only print the part of the source obj hierarchy
	// underneath the current object.

	// SV version has the other order in conditional -- works for
	// SV because strings are null terminated
	// while ((sname[cpath] == nm[cpath]) && (cpath < max)) begin
	while ((cpath < max) && (sname[cpath] == nm[cpath])) {
	  if (sname[cpath] == '.') {
	    last_dot = cpath;
	  }
	  ++cpath;
	}

	if (last_dot != 0) {
	  sname = sname[last_dot+1..$];
	}
	uvm_report_info("OBJTN_TRC",
			format("Object %0s %0s %0d objection(s) %0s its " ~
			       "total (%s from source object %s%s): " ~
			       "count=%0d  total=%0d",
			       obj.get_full_name() == "" ?
			       "uvm_top" : obj.get_full_name(),
			       action == "raised" ? "added" : "subtracted",
			       count, action == "raised" ?
			       "to" : "from", action, sname,
			       description_ != "" ? ", "
			       ~ description_ : "", count_, total_), uvm_verbosity.UVM_NONE);
      }
    }
  }


  // Function- m_get_parent
  //
  // Internal method for getting the parent of the given ~object~.
  // The ultimate parent is uvm_top, UVM's implicit top-level component.

  final uvm_object m_get_parent(uvm_object obj) {
    import uvm.seq.uvm_sequence_base;
    import uvm.base.uvm_root: uvm_root;
    import uvm.base.uvm_component;

    uvm_root m_top = uvm_root.get();
    uvm_component comp = cast (uvm_component) obj;
    uvm_sequence_base seq = cast (uvm_sequence_base) obj;
    if (comp !is null) {
      obj = comp.get_parent();
    }
    else if (seq !is null) {
      obj = seq.get_sequencer();
    }
    else {
      obj = m_top;
    }
    if (obj is null) {
      obj = m_top;
    }
    return obj;
  }


  // Function- m_propagate
  //
  // Propagate the objection to the objects parent. If the object is a
  // component, the parent is just the hierarchical parent. If the object is
  // a sequence, the parent is the parent sequence if one exists, or
  // it is the attached sequencer if there is no parent sequence.
  //
  // obj : the uvm_object on which the objection is being raised or lowered
  // source_obj : the root object on which the end user raised/lowered the
  //   objection (as opposed to an anscestor of the end user object)a
  // count : the number of objections associated with the action.
  // raise : indicator of whether the objection is being raised or lowered. A
  //   1 indicates the objection is being raised.

  final void m_propagate (uvm_object obj,
			  uvm_object source_obj,
			  string description,
			  int count,
			  bool raise,
			  int in_top_thread) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj !is null && obj !is m_top) {
      obj = m_get_parent(obj);
      if (raise) {
	m_raise(obj, source_obj, description, count);
      }
      else {
	m_drop(obj, source_obj, description, count, in_top_thread);
      }
    }
  }

  // Group -- NODOCS -- Objection Control


  // @uvm-ieee 1800.2-2020 auto 10.5.1.3.2
  void set_propagate_mode (bool prop_mode) {
    synchronized (this) {
      if (!_m_top_all_dropped && (get_objection_total() != 0)) {
	uvm_error("UVM/BASE/OBJTN/PROP_MODE",
		  "The propagation mode of '" ~ this.get_full_name() ~
		  "' cannot be changed while the objection is raised " ~
		  "or draining!");
	return;
      }

      _m_prop_mode = prop_mode;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 10.5.1.3.1
  bool get_propagate_mode() {
    synchronized (this) {
      return _m_prop_mode;
    }
  }


  // Function -- NODOCS -- raise_objection
  //
  // Raises the number of objections for the source ~object~ by ~count~, which
  // defaults to 1.  The ~object~ is usually the ~this~ handle of the caller.
  // If ~object~ is not specified or ~null~, the implicit top-level component,
  // <uvm_root>, is chosen.
  //
  // Raising an objection causes the following.
  //
  // - The source and total objection counts for ~object~ are increased by
  //   ~count~. ~description~ is a string that marks a specific objection
  //   and is used in tracing/debug.
  //
  // - The objection's <raised> virtual method is called, which calls the
  //   <uvm_component.raised> method for all of the components up the
  //   hierarchy.
  //

  // @uvm-ieee 1800.2-2020 auto 10.5.1.3.3
  void raise_objection (uvm_object obj = null,
			string description = "",
			int count = 1) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }
    synchronized (this) {
      _m_cleared = false;
      _m_top_all_dropped = false;
    }
    m_raise (obj, obj, description, count);
  }


  // Function- m_raise

  final void m_raise (uvm_object obj,
		      uvm_object source_obj,
		      string description = "",
		      int count = 1) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    // Ignore raise if count is 0
    if (count == 0) {
      return;
    }

    synchronized (this) {
      auto ptotal = obj in _m_total_count;
      if (ptotal !is null) {
	*ptotal += count;
      }
      else {
	_m_total_count[obj] = count;
      }

      if (source_obj is obj) {
	auto psource = obj in _m_source_count;
	if (psource !is null) {
	  *psource += count;
	}
	else {
	  _m_source_count[obj] = count;
	}
      }
      if (_m_trace_mode) {
	m_report(obj, source_obj, description, count, "raised");
      }
    }
    
    raised(obj, source_obj, description, count);

    // Handle any outstanding drains...

    // First go through the scheduled list
    int idx = 0;
    uvm_objection_context_object ctxt;
    synchronized (_uvm_scope_inst) {
      while (idx < _uvm_scope_inst._m_scheduled_list.length) {
	if ((_uvm_scope_inst._m_scheduled_list[idx].obj is obj) &&
	   (_uvm_scope_inst._m_scheduled_list[idx].objection is this)) {
	  // Caught it before the drain was forked
	  ctxt = _uvm_scope_inst._m_scheduled_list[idx];
	  _uvm_scope_inst._m_scheduled_list.remove(idx);
	  break;
	}
	idx++;
      }
    }

    // If it's not there, go through the forked list
    if (ctxt is null) {
      idx = 0;
      synchronized (this) {
	while (idx < _m_forked_list.length) {
	  if (_m_forked_list[idx].obj is obj) {
	    // Caught it after the drain was forked,
	    // but before the fork started
	    ctxt = _m_forked_list[idx];
	    _m_forked_list.remove(idx);
	    _m_scheduled_contexts.remove(ctxt.obj);
	    break;
	  }
	  idx++;
	}
      }
    }

    // If it's not there, go through the forked contexts
    if (ctxt is null) {
      synchronized (this) {
	auto pforked = obj in _m_forked_contexts;
	if (pforked !is null) {
	  // Caught it with the forked drain running
	  ctxt = *pforked;
	  _m_forked_contexts.remove(obj);
	  // Kill the drain
	  version (UVM_USE_PROCESS_CONTAINER) {
	    _m_drain_proc[obj].p.abortTree();
	    _m_drain_proc.remove(obj);
	  }
	  else {
	    _m_drain_proc[obj].abortTree();
	    _m_drain_proc.remove(obj);
	  }

	}
      }
    }

    if (ctxt is null) {
      // If there were no drains, just propagate as usual

      if (! m_prop_mode && obj !is m_top) {
	m_raise(m_top, source_obj, description, count);
      }
      else if (obj !is m_top) {
	m_propagate(obj, source_obj, description, count, true, 0);
      }
    }
    else { // Otherwise we need to determine what exactly happened

      // Determine the diff count, if it's positive, then we're
      // looking at a 'raise' total, if it's negative, then
      // we're looking at a 'drop', but not down to 0.  If it's
      // a 0, that means that there is no change in the total.
      int diff_count = count - ctxt.count;

      if (diff_count != 0) {
	// Something changed
	if (diff_count > 0) {
	  // we're looking at an increase in the total
	  if (!m_prop_mode && obj !is m_top) {
	    m_raise(m_top, source_obj, description, diff_count);
	  }
	  else if (obj !is m_top) {
	    m_propagate(obj, source_obj, description, diff_count, true, 0);
	  }
	}
	else {
	  // we're looking at a decrease in the total
	  // The count field is always positive...
	  diff_count = -diff_count;
	  if (!m_prop_mode && obj !is m_top) {
	    m_drop(m_top, source_obj, description, diff_count);
	  }
	  else if (obj !is m_top) {
	    m_propagate(obj, source_obj, description, diff_count, false, 0);
	  }
	}
      }

      // Cleanup
      ctxt.clear();
      synchronized (_uvm_scope_inst) {
	_uvm_scope_inst._m_context_pool.pushBack(ctxt);
      }
    }
  }


  // Function -- NODOCS -- drop_objection
  //
  // Drops the number of objections for the source ~object~ by ~count~, which
  // defaults to 1.  The ~object~ is usually the ~this~ handle of the caller.
  // If ~object~ is not specified or ~null~, the implicit top-level component,
  // <uvm_root>, is chosen.
  //
  // Dropping an objection causes the following.
  //
  // - The source and total objection counts for ~object~ are decreased by
  //   ~count~. It is an error to drop the objection count for ~object~ below
  //   zero.
  //
  // - The objection's <dropped> virtual method is called, which calls the
  //   <uvm_component.dropped> method for all of the components up the
  //   hierarchy.
  //
  // - If the total objection count has not reached zero for ~object~, then
  //   the drop is propagated up the object hierarchy as with
  //   <raise_objection>. Then, each object in the hierarchy will have updated
  //   their ~source~ counts--objections that they originated--and ~total~
  //   counts--the total number of objections by them and all their
  //   descendants.
  //
  // If the total objection count reaches zero, propagation up the hierarchy
  // is deferred until a configurable drain-time has passed and the
  // <uvm_component.all_dropped> callback for the current hierarchy level
  // has returned. The following process occurs for each instance up
  // the hierarchy from the source caller:
  //
  // A process is forked in a non-blocking fashion, allowing the ~drop~
  // call to return. The forked process then does the following:
  //
  // - If a drain time was set for the given ~object~, the process waits for
  //   that amount of time.
  //
  // - The objection's <all_dropped> virtual method is called, which calls the
  //   <uvm_component.all_dropped> method (if ~object~ is a component).
  //
  // - The process then waits for the ~all_dropped~ callback to complete.
  //
  // - After the drain time has elapsed and all_dropped callback has
  //   completed, propagation of the dropped objection to the parent proceeds
  //   as described in <raise_objection>, except as described below.
  //
  // If a new objection for this ~object~ or any of its descendants is raised
  // during the drain time or during execution of the all_dropped callback at
  // any point, the hierarchical chain described above is terminated and the
  // dropped callback does not go up the hierarchy. The raised objection will
  // propagate up the hierarchy, but the number of raised propagated up is
  // reduced by the number of drops that were pending waiting for the
  // all_dropped/drain time completion. Thus, if exactly one objection
  // caused the count to go to zero, and during the drain exactly one new
  // objection comes in, no raises or drops are propagated up the hierarchy,
  //
  // As an optimization, if the ~object~ has no set drain-time and no
  // registered callbacks, the forked process can be skipped and propagation
  // proceeds immediately to the parent as described.

  // @uvm-ieee 1800.2-2020 auto 10.5.1.3.4
  void drop_objection (uvm_object obj=null,
		       string description="",
		       int count=1) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }
    m_drop(obj, obj, description, count, 0);
  }


  // Function- m_drop

  final void m_drop (uvm_object obj,
		     uvm_object source_obj,
		     string description = "",
		     int count = 1,
		     int in_top_thread = 0) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    // Ignore drops if the count is 0
    if (count == 0) {
      return;
    }

    synchronized (this) {
      auto ptotal = obj in _m_total_count;
      if ((ptotal is null) || (count > *ptotal)) {
	if (_m_cleared) {
	  return;
	}
	uvm_report_fatal("OBJTN_ZERO", "Object \"" ~ obj.get_full_name() ~
			 "\" attempted to drop objection '" ~ this.get_name()
			 ~ "' count below zero");
	return;
      }

      if (obj is source_obj) {
	if (obj !in _m_source_count || (count > _m_source_count[obj])) {
	  if (_m_cleared) {
	    return;
	  }
	  uvm_report_fatal("OBJTN_ZERO", "Object \"" ~  obj.get_full_name() ~
			   "\" attempted to drop objection '" ~
			   this.get_name() ~ "' count below zero");
	  return;
	}
	_m_source_count[obj] -= count;
      }
      _m_total_count[obj] -= count;

      if (_m_trace_mode) {
	m_report(obj, source_obj, description, count, "dropped");
      }

      dropped(obj, source_obj, description, count);

      // if count !is 0, no reason to fork
      if (_m_total_count[obj] != 0) {
	if (! _m_prop_mode && obj !is m_top) {
	  m_drop(m_top, source_obj, description, count, in_top_thread);
	}
	else if (obj !is m_top) {
	  this.m_propagate(obj, source_obj, description, count, false, in_top_thread);
	}
      }
      else {
	uvm_objection_context_object ctxt;
	synchronized (_uvm_scope_inst) {
	  if (_uvm_scope_inst._m_context_pool.length !is 0) {
	    ctxt = _uvm_scope_inst._m_context_pool.front();
	    _uvm_scope_inst._m_context_pool.removeFront();
	  }
	  else {
	    ctxt = new uvm_objection_context_object();
	  }
	}

	synchronized (ctxt) {
	  ctxt.obj = obj;
	  ctxt.source_obj = source_obj;
	  ctxt.description = description;
	  ctxt.count = count;
	  ctxt.objection = this;
	}
	// Need to be thread-safe, let the background
	// process handle it.

	// Why don't we look at in_top_thread here?  Because
	// a re-raise will kill the drain at object that it's
	// currently occuring at, and we need the leaf-level kills
	// to not cause accidental kills at branch-levels in
	// the propagation.

	// Using the background process just allows us to
	// separate the links of the chain.
	synchronized (_uvm_scope_inst) {
	  _uvm_scope_inst._m_scheduled_list.pushBack(ctxt);
	  _uvm_scope_inst._m_scheduled_list_event.notify();
	}
      } // else: !if (m_total_count[obj] !is 0)
    }
  }


  // @uvm-ieee 1800.2-2020 auto 10.5.1.3.5
  void clear(uvm_object obj=null) {

    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }

    string name = obj.get_full_name();
    if (name == "") {
      name = "uvm_top";
    }
    // else
    //   name = obj.get_full_name();
    if (! m_top_all_dropped && get_objection_total(m_top)) {
      uvm_report_warning("OBJTN_CLEAR", "Object '" ~ name ~
			 "' cleared objection counts for " ~ get_name());
    }

    //Should there be a warning if there are outstanding objections?
    synchronized (this) {
      _m_source_count = null;
      _m_total_count  = null;
    }


    // Remove any scheduled drains from the static queue
    size_t idx = 0;

    // m_scheduled_list/m_context_pool are a once resource -- use guarded version
    synchronized (_uvm_scope_inst) {
      while (idx < _uvm_scope_inst._m_scheduled_list.length) {
	if (_uvm_scope_inst._m_scheduled_list[idx].objection is this) {
	  _uvm_scope_inst._m_scheduled_list[idx].clear();
	  _uvm_scope_inst._m_context_pool.pushBack(_uvm_scope_inst._m_scheduled_list[idx]);
	  _uvm_scope_inst._m_scheduled_list.remove(idx);
	}
	else {
	  idx++;
	}
      }
    }

    // Scheduled contexts and m_forked_lists have duplicate
    // entries... clear out one, free the other.
    synchronized (this) {
      _m_scheduled_contexts = null;
      while (_m_forked_list.length) {
	_m_forked_list[0].clear();
	synchronized (_uvm_scope_inst) {
	  _uvm_scope_inst._m_context_pool.pushBack(_m_forked_list[0]);
	}
	_m_forked_list.removeFront();
      }
    }

    // running drains have a context and a process
    synchronized (this) {
      foreach (o, context; _m_forked_contexts) {
	version (UVM_USE_PROCESS_CONTAINER) {
	  _m_drain_proc[o].p.abortTree();
	  _m_drain_proc.remove(o);
	}
	else {
	  _m_drain_proc[o].abortTree();
	  _m_drain_proc.remove(o);
	}

	_m_forked_contexts[o].clear();
	synchronized (_uvm_scope_inst) {
	  _uvm_scope_inst._m_context_pool.pushBack(_m_forked_contexts[o]);
	}
	_m_forked_contexts.remove(o);
      }

      _m_top_all_dropped = false;
      _m_cleared = true;
      if (m_top in _m_events) {
	_m_events[m_top].all_dropped.notify();
      }
    }
  }



  // m_execute_scheduled_forks
  // -------------------------

  // background process; when non

  // task
  static void m_execute_scheduled_forks() {
    while (true) {
      // wait(m_scheduled_list.size() !is 0);
      if (_uvm_scope_inst.m_scheduled_list_length() == 0) {
	wait(m_scheduled_list_event);
      }
      else {
	// Save off the context before the fork
	uvm_objection_context_object c;
	_uvm_scope_inst.m_scheduled_list_pop_front(c);
	if (c is null) {
	  continue;
	}
	// A re-raise can use this to figure out props (if any)
	synchronized (c.objection) {
	  c.objection._m_scheduled_contexts[c.obj] = c;
	  // The fork below pulls out from the forked list
	  c.objection._m_forked_list.pushBack(c);
	  // The fork will guard the m_forked_drain call, but
	  // a re-raise can kill m_forked_list contexts in the delta
	  // before the fork executes.
	}

	(uvm_objection objection) {
	  auto guard = fork!("uvm_objection/execute_scheduled_forks/guard")
	    ({
	      // Check to maike sure re-raise didn't empty the fifo
	      synchronized (objection) {
		uvm_objection_context_object ctxt;
		if (objection._m_forked_list.length > 0) {
		  objection._m_forked_list.popFront(ctxt);
		  // Clear it out of scheduled
		  objection._m_scheduled_contexts.remove(ctxt.obj);
		  // Move it in to forked (so re-raise can figure out props)
		  objection._m_forked_contexts[ctxt.obj] = ctxt;
		  // Save off our process handle, so a re-raise can kill it...
		  version (UVM_USE_PROCESS_CONTAINER) {
		    process_container_c c = new process_container_c(Process.self);
		    objection._m_drain_proc[ctxt.obj] = c;
		  }
		  else {
		    objection._m_drain_proc[ctxt.obj] = Process.self;
		  }
		}
		if (ctxt !is null) {
		  // Execute the forked drain -- m_forked_drain is a task
		  objection.m_forked_drain(ctxt.obj, ctxt.source_obj,
					   ctxt.description, ctxt.count, 1);
		  // Cleanup if we survived (no re-raises)
		  objection._m_drain_proc.remove(ctxt.obj);
		  objection._m_forked_contexts.remove(ctxt.obj);
		  // Clear out the context object (prevent memory leaks)
		  ctxt.clear();
		  // Save the context in the pool for later reuse
		  synchronized (_uvm_scope_inst) {
		    _uvm_scope_inst._m_context_pool.pushBack(ctxt);
		  }
		}
	      }
	    });
	} (c.objection);
      }
    }
  }


  // m_forked_drain
  // -------------

  final void m_forked_drain (uvm_object obj,
			     uvm_object source_obj,
			     string description = "",
			     int count = 1,
			     int in_top_thread = 0) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    SimTime* ptime;
    
    synchronized (this) {
      ptime = obj in _m_drain_time;
    }

    if (ptime !is null) {
      wait(*ptime);
    }
    
    if (m_trace_mode) {
      m_report(obj, source_obj, description, count, "all_dropped");
    }

    all_dropped(obj, source_obj, description, count);

    // wait for all_dropped cbs to complete
    waitForks();

    /* NOT NEEDED - Any raise would have killed us!
       if (!m_total_count.exists(obj))
       diff_count = -count;
       else
       diff_count = m_total_count[obj] - count;
    */

    // we are ready to delete the 0-count entries for the current
    // object before propagating up the hierarchy.
    synchronized (this) {
      if (obj in _m_source_count && _m_source_count[obj] == 0) {
	_m_source_count.remove(obj);
      }

      if (obj in _m_total_count && _m_total_count[obj] == 0) {
	_m_total_count.remove(obj);
      }
    }

    if (!m_prop_mode && obj !is m_top) {
      m_drop(m_top, source_obj, description, count, 1);
    }
    else if (obj !is m_top) {
      m_propagate(obj, source_obj, description, count, false, 1);
    }
  }


  // m_init_objections
  // -----------------

  // Forks off the single background process
  static void m_init_objections() {
    fork!("uvm_objection/init_objections")
      ({uvm_objection.m_execute_scheduled_forks();});
  }

  // Function -- NODOCS -- set_drain_time
  //
  // Sets the drain time on the given ~object~ to ~drain~.
  //
  // The drain time is the amount of time to wait once all objections have
  // been dropped before calling the all_dropped callback and propagating
  // the objection to the parent.
  //
  // If a new objection for this ~object~ or any of its descendants is raised
  // during the drain time or during execution of the all_dropped callbacks,
  // the drain_time/all_dropped execution is terminated.

  // AE: set_drain_time(drain,obj=null)?
  // @uvm-ieee 1800.2-2020 auto 10.5.1.3.7
  final void set_drain_time (uvm_object obj, Time drain) {
    set_drain_time(obj, SimTime(getRootEntity(), drain));
  }

  final void set_drain_time (uvm_object obj, SimTime drain) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }
    synchronized (this) {
      _m_drain_time[obj] = drain;
    }
  }

  //----------------------
  // Group -- NODOCS -- Callback Hooks
  //----------------------

  // Function -- NODOCS -- raised
  //
  // Objection callback that is called when a <raise_objection> has reached ~obj~.
  // The default implementation calls <uvm_component::raised>.

  // @uvm-ieee 1800.2-2020 auto 10.5.1.4.1
  void raised(uvm_object obj,
	      uvm_object source_obj,
	      string description,
	      int count) {
    import uvm.base.uvm_component;
    uvm_component comp = cast (uvm_component) obj;
    if (comp !is null) {
      comp.raised(this, source_obj, description, count);
    }
    uvm_do_callbacks(cb => cb.raised(this, obj, source_obj, description, count));
    synchronized (this) {
      if (obj in _m_events) {
	_m_events[obj].raised.notify();
      }
    }
  }
  

  // Function -- NODOCS -- dropped
  //
  // Objection callback that is called when a <drop_objection> has reached ~obj~.
  // The default implementation calls <uvm_component::dropped>.

  // @uvm-ieee 1800.2-2020 auto 10.5.1.4.2
  void dropped (uvm_object obj,
		uvm_object source_obj,
		string description,
		int count) {
    import uvm.base.uvm_component;
    uvm_component comp = cast (uvm_component) obj;
    if (comp !is null) {
      comp.dropped(this, source_obj, description, count);
    }
    uvm_do_callbacks(cb => cb.dropped(this, obj, source_obj, description, count));
    synchronized (this) {
      if (obj in _m_events) {
	_m_events[obj].dropped.notify();
      }
    }
  }


  // Function -- NODOCS -- all_dropped
  //
  // Objection callback that is called when a <drop_objection> has reached ~obj~,
  // and the total count for ~obj~ goes to zero. This callback is executed
  // after the drain time associated with ~obj~. The default implementation
  // calls <uvm_component::all_dropped>.

  // @uvm-ieee 1800.2-2020 auto 10.5.1.4.3
  void all_dropped (uvm_object obj,
		    uvm_object source_obj,
		    string description,
		    int count) {
    import uvm.base.uvm_root: uvm_root;
    import uvm.base.uvm_component;
    uvm_root m_top = uvm_root.get();

    uvm_component comp = cast (uvm_component) obj;
    if (comp !is null) {
      comp.all_dropped(this, source_obj, description, count);
    }
    uvm_do_callbacks(cb => cb.all_dropped(this, obj, source_obj,
					  description, count));
    synchronized (this) {
      auto pevent = obj in _m_events;
      if (pevent !is null) {
	pevent.all_dropped.notify();
      }
      if (obj is m_top) {
	_m_top_all_dropped = true;
      }
    }
  }


  //------------------------
  // Group -- NODOCS -- Objection Status
  //------------------------

  // Function -- NODOCS -- get_objectors
  //
  // Returns the current list of objecting objects (objects that
  // raised an objection but have not dropped it).

  // @uvm-ieee 1800.2-2020 auto 10.5.1.5.1
  final void get_objectors(out Queue!uvm_object list) {
    synchronized (this) {
      foreach (obj, count; _m_source_count) {
	list.pushBack(obj);
      }
    }
  }

  final void get_objectors(out uvm_object[] list) {
    synchronized (this) {
      foreach (obj, count; _m_source_count) {
	list ~= obj;
      }
    }
  }

  final uvm_object[] get_objectors() {
    uvm_object[] list;
    get_objectors(list);
    return list;
  }


  // task

  // @uvm-ieee 1800.2-2020 auto 10.5.1.5.2
  final void wait_for(uvm_objection_event objt_event, uvm_object obj=null) {

    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }

    uvm_objection_events obje;
    
    synchronized (this) {
      auto pobje = obj in _m_events;
      if (pobje is null) {
	obje = new uvm_objection_events;
	_m_events[obj] = obje;
      }
      else {
	obje = *pobje;
      }
      obje.inc_waiters;
    }

    final switch (objt_event) {
    case uvm_objection_event.UVM_RAISED:      wait(obje.raised); break;
    case uvm_objection_event.UVM_DROPPED:     wait(obje.dropped); break;
    case uvm_objection_event.UVM_ALL_DROPPED: wait(obje.all_dropped); break;
    }

    synchronized (this) {
      _m_events[obj].dec_waiters;
      if (_m_events[obj].waiters == 0) {
	_m_events.remove(obj);
      }
    }
  }


  // function wait_for_total_count is not documented in the UVM API
  // doc, nor is it used anywhere inside the UVM

  // void wait_for_total_count(uvm_object obj=null, int count=0) {
  //   AssocWithEvent!(uvm_object, int) total_count;
  //   synchronized (this) {
  //     total_count = m_total_count;
  //     if (obj is null)
  //	obj = m_top;
  //     if (obj !in m_total_count && count is 0)
  //	return;
  //   }

  //   if (count is 0) {
  //     while (obj in total_count) {
  //	wait(total_count);
  //     }
  //     wait (!m_total_count.exists(obj));
  //    else
  //       wait (m_total_count.exists(obj) && m_total_count[obj] is count);
  //  endtask


  // Function -- NODOCS -- get_objection_count
  //
  // Returns the current number of objections raised by the given ~object~.

  // @uvm-ieee 1800.2-2020 auto 10.5.1.5.3
  final int get_objection_count (uvm_object obj=null) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }

    synchronized (this) {
      if (obj !in _m_source_count) {
	return 0;
      }
      return _m_source_count[obj];
    }
  }


  // Function -- NODOCS -- get_objection_total
  //
  // Returns the current number of objections raised by the given ~object~
  // and all descendants.

  // @uvm-ieee 1800.2-2020 auto 10.5.1.5.4
  final int get_objection_total(uvm_object obj = null) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }
    synchronized (this) {
      auto ptotal = obj in _m_total_count;
      if (ptotal is null) {
	return 0;
      }
      else {
	return *ptotal;
      }
    }
  }


  // Function -- NODOCS -- get_drain_time
  //
  // Returns the current drain time set for the given ~object~ (default: 0 ns).

  // @uvm-ieee 1800.2-2020 auto 10.5.1.3.6
  final SimTime get_drain_time (uvm_object obj = null) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    if (obj is null) {
      obj = m_top;
    }

    synchronized (this) {
      auto ptime = obj in _m_drain_time;
      if (ptime is null)	{
	return SimTime(0);
      }
      return *ptime;
    }
  }


  // m_display_objections

  final protected string m_display_objections(uvm_object obj = null,
					      bool show_header = true) {
    synchronized (this) {
      import uvm.base.uvm_root: uvm_root;
      uvm_root m_top = uvm_root.get();

      enum string blank = "                                       " ~
	"                                            ";
      uvm_object[string] list;
      foreach (theobj, count; _m_total_count) {
	if ( count > 0) {
	  list[theobj.get_full_name()] = theobj;
	}
      }

      if (obj is null) {
	obj = m_top;
      }

      int total = get_objection_total(obj);

      string s = format("The total objection count is %0d\n",total);

      if (total is 0) {
	return s;
      }

      s ~= "---------------------------------------------------------\n";
      s ~= "Source  Total   \n";
      s ~= "Count   Count   Object\n";
      s ~= "---------------------------------------------------------\n";


      string this_obj_name = obj.get_full_name();
      string curr_obj_name = this_obj_name;

      string[string] table;

      foreach (o, count; _m_total_count) {
	string name = o.get_full_name;
	if (count > 0 && (name == curr_obj_name ||
			 (name.length > curr_obj_name.length &&
			  name[0..curr_obj_name.length+1] == (curr_obj_name ~ ".")))) {
	  size_t depth = std.algorithm.searching.count(name, '.');

	  string leafName = curr_obj_name[lastIndexOf(curr_obj_name, '.')+1..$];

	  if (curr_obj_name == "") {
	    leafName = "uvm_top";
	  }
	  else {
	    depth++;
	  }

	  table[name] =
	    format("%-6d  %-6d %s%s\n",
		   o in _m_source_count ? _m_source_count[o] : 0,
		   o in _m_total_count  ? _m_total_count[o]  : 0,
		   blank[0..2*depth+1], leafName);
	}
      }
      import std.algorithm;
      foreach (key; sort(table.keys)) {
	s ~= table[key];
      }

      s ~= "---------------------------------------------------------\n";

      return s;
    }

  }

  string to(S)() if (is (S == string)) {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    return m_display_objections(m_top, true);
  }

  override string convert2string() {
    import uvm.base.uvm_root: uvm_root;
    uvm_root m_top = uvm_root.get();

    return m_display_objections(m_top, true);
  }




  // Function -- NODOCS -- display_objections
  //
  // Displays objection information about the given ~object~. If ~object~ is
  // not specified or ~null~, the implicit top-level component, <uvm_root>, is
  // chosen. The ~show_header~ argument allows control of whether a header is
  // output.

  final void display_objections(uvm_object obj=null,
				bool show_header = true) {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    string m = m_display_objections(obj, show_header);
    uvm_info("UVM/OBJ/DISPLAY", m, uvm_verbosity.UVM_NONE);
  }


  // Below is all of the basic data stuff that is needed for a uvm_object
  // for factory registration, printing, comparing, etc.

  alias type_id = uvm_object_registry!(uvm_objection);

  static type_id get_type() {
    return type_id.get();
  }

  override uvm_object create (string name="") {
    return new uvm_objection(name);
  }

  override string get_type_name () {
    return qualifiedTypeName!(typeof(this));
  }

  override void do_copy (uvm_object rhs) {
    uvm_objection rhs_ = cast (uvm_objection) rhs;
    synchronized (this) {
      synchronized (rhs_) {
	_m_source_count = rhs_._m_source_count.dup;
	_m_total_count  = rhs_._m_total_count.dup;
	_m_drain_time   = rhs_._m_drain_time.dup;
	_m_prop_mode    = rhs_._m_prop_mode;
      }
    }
  }

}



// TODO: change to plusarg
// SimTime uvm_default_timeout() {
//   return SimTime(EntityIntf.getContextEntity(), UVM_DEFAULT_TIMEOUT);
// }

// typedef class uvm_cmdline_processor;


// Have a pool of context objects to use
class uvm_objection_context_object
{
  mixin (uvm_sync_string);

  @uvm_private_sync
  private uvm_object _obj;
  @uvm_private_sync
  private uvm_object _source_obj;
  @uvm_private_sync
  private string _description;
  @uvm_private_sync
  private int _count;
  @uvm_private_sync
  private uvm_objection _objection;

  // Clears the values stored within the object,
  // preventing memory leaks from reused objects
  void clear() {
    synchronized (this) {
      _obj = null;
      _source_obj = null;
      _description = "";
      _count = 0;
      _objection = null;
    }
  }
}

// Typedef - Exists for backwards compat
alias uvm_callbacks_objection = uvm_objection;


//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_objection_callback
//
//------------------------------------------------------------------------------
// The uvm_objection is the callback type that defines the callback
// implementations for an objection callback. A user uses the callback
// type uvm_objection_cbs_t to add callbacks to specific objections.
//
// For example:
//
//| class my_objection_cb extends uvm_objection_callback;
//|   function new(string name);
//|     super.new(name);
//|   endfunction
//|
//|   virtual function void raised (uvm_objection objection, uvm_object obj,
//|       uvm_object source_obj, string description, int count);
//|     `uvm_info("RAISED","%0t: Objection %s: Raised for %s", $time, objection.get_name(),
//|         obj.get_full_name());
//|   endfunction
//| endclass
//| ...
//| initial begin
//|   my_objection_cb cb = new("cb");
//|   uvm_objection_cbs_t::add(null, cb); //typewide callback
//| end


// @uvm-ieee 1800.2-2020 auto 10.5.2.1
class uvm_objection_callback: uvm_callback
{
  this(string name) {
    super(name);
  }

  // Function -- NODOCS -- raised
  //
  // Objection raised callback function. Called by <uvm_objection::raised>.

  // @uvm-ieee 1800.2-2020 auto 10.5.2.2.1
  void raised (uvm_objection objection, uvm_object obj,
	       uvm_object source_obj, string description, int count) {
  }

  // Function -- NODOCS -- dropped
  //
  // Objection dropped callback function. Called by <uvm_objection::dropped>.

  // @uvm-ieee 1800.2-2020 auto 10.5.2.2.2
  void dropped (uvm_objection objection, uvm_object obj,
		uvm_object source_obj, string description, int count) {
  }

  // Function -- NODOCS -- all_dropped
  //
  // Objection all_dropped callback function. Called by <uvm_objection::all_dropped>.

  // task

  // @uvm-ieee 1800.2-2020 auto 10.5.2.2.3
  void all_dropped (uvm_objection objection, uvm_object obj,
		    uvm_object source_obj, string description,
		    int count) {
  }
}
