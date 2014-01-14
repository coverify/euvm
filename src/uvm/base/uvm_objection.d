//
//----------------------------------------------------------------------
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
//----------------------------------------------------------------------

module uvm.base.uvm_objection;


import uvm.base.uvm_callback;
import uvm.base.uvm_misc;
import uvm.base.uvm_globals;
import uvm.base.uvm_component;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_queue;
import uvm.base.uvm_registry;
import uvm.base.uvm_message_defines;
import uvm.base.uvm_domain;

import uvm.seq.uvm_sequence_base;

import uvm.meta.misc;

import esdl.base.core: Event, SimTime, Process,
  process, waitForks, wait, getRootEntity, Fork, fork;
import esdl.data.sync;


alias uvm_callbacks!(uvm_objection,uvm_objection_callback) uvm_objection_cbs_t;

// typedef class uvm_cmdline_processor;
// typedef class uvm_callbacks_objection;

class uvm_objection_events {
  mixin(uvm_sync!uvm_objection_events);
  @uvm_private_sync   private int   _waiters;
  private void inc_waiters() {synchronized(this) ++_waiters;}
  private void dec_waiters() {synchronized(this) --_waiters;}
  @uvm_immutable_sync private Event _raised;
  @uvm_immutable_sync private Event _dropped;
  @uvm_immutable_sync private Event _all_dropped;
  this() {
    synchronized(this) {
      _raised.init();
      _dropped.init();
      _all_dropped.init();
    }
  }
}

//------------------------------------------------------------------------------
// Title: Objection Mechanism
//------------------------------------------------------------------------------
// The following classes define the objection mechanism and end-of-test
// functionality, which is based on <uvm_objection>.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//
// Class: uvm_objection
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

import uvm.meta.misc;
import uvm.base.uvm_report_object;
import uvm.base.uvm_object;
import uvm.base.uvm_root;

import esdl.base.time: sec;

class uvm_once_objection
{
  @uvm_immutable_sync private SyncQueue!uvm_objection _m_objections;

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
  @uvm_immutable_sync
  private SyncQueue!uvm_objection_context_object _m_context_pool;

  // These are the contexts which have been scheduled for
  // retrieval by the background process, but which the
  // background process hasn't seen yet.
  @uvm_immutable_sync
  private SyncQueue!uvm_objection_context_object _m_scheduled_list;

  @uvm_immutable_sync
  private Event _m_scheduled_list_event;

  this() {
    synchronized(this) {
      _m_scheduled_list_event.init();
      _m_objections = new SyncQueue!uvm_objection();
      _m_context_pool = new SyncQueue!uvm_objection_context_object();
      _m_scheduled_list = new SyncQueue!uvm_objection_context_object();
    }
  }
}


class uvm_objection: uvm_report_object
{
  mixin(uvm_sync!uvm_objection);
  mixin(uvm_once_sync!uvm_once_objection);

  @uvm_protected_sync
    private bool _m_trace_mode;
  @uvm_immutable_sync
    private SyncAssoc!(uvm_object, int)  _m_source_count;
  @uvm_immutable_sync
    private SyncAssoc!(uvm_object, int)  _m_total_count;
  @uvm_immutable_sync
    private SyncAssoc!(uvm_object, SimTime) _m_drain_time;
  @uvm_immutable_sync
    private SyncAssoc!(uvm_object, uvm_objection_events) _m_events;
  @uvm_public_sync
    private bool _m_top_all_dropped;

  static uvm_root _m_top = null;
  static protected uvm_root m_top() {
    if(_m_top is null) {
      _m_top = uvm_root.get();
    }
    return _m_top;
  }


  // These are the active drain processes, which have been
  // forked off by the background process.  A raise can
  // use this array to kill a drain.
  version(UVM_USE_PROCESS_CONTAINER) {
    @uvm_immutable_sync
      private SyncAssoc!(uvm_object, process_container_c) _m_drain_proc;
  }
  else {
    @uvm_immutable_sync
      private SyncAssoc!(uvm_object, Process) _m_drain_proc;
  }

  // Once a context is seen by the background process, it is
  // removed from the scheduled list, and placed in the forked
  // list.  At the same time, it is placed in the scheduled
  // contexts array.  A re-raise can use the scheduled contexts
  // array to detect (and cancel) the drain.
  @uvm_immutable_sync
    private SyncAssoc!(uvm_object,
		       uvm_objection_context_object) _m_scheduled_contexts;

  @uvm_immutable_sync
    private SyncQueue!uvm_objection_context_object _m_forked_list;

  // Once the forked drain has actually started (this occurs
  // ~1 delta AFTER the background process schedules it), the
  // context is removed from the above array and list, and placed
  // in the forked_contexts list.
  @uvm_immutable_sync
    private SyncAssoc!(uvm_object,
		       uvm_objection_context_object) _m_forked_contexts;

  @uvm_private_sync private bool _m_hier_mode = true;

  // defined in SV version, but seems redundant -- there is m_top too
  // uvm_root top = uvm_root.get();


  @uvm_protected_sync private bool _m_cleared; /* for checking obj count<0 */

  // Function: clear
  //
  // Immediately clears the objection state. All counts are cleared and the
  // any processes waiting on a call to wait_for(UVM_ALL_DROPPED, uvm_top)
  // are released.
  //
  // The caller, if a uvm_object-based object, should pass its 'this' handle
  // to the ~obj~ argument to document who cleared the objection.
  // Any drain_times set by the user are not effected.
  //
  public void clear(uvm_object obj=null) {

    // redundant -- unused variable -- defined in SV version
    // uvm_objection_context_object ctxt;

    if(obj is null) obj = m_top;

    string name = obj.get_full_name();
    if(name == "") name = "uvm_top";
    // else
    //   name = obj.get_full_name();
    if(!m_top_all_dropped && get_objection_total(m_top)) {
      uvm_report_warning("OBJTN_CLEAR", "Object '" ~ name ~
			 "' cleared objection counts for " ~ get_name());
    }

    //Should there be a warning if there are outstanding objections?
    m_source_count.clear();
    m_total_count.clear(); //  = null;


    // Remove any scheduled drains from the static queue
    size_t idx = 0;

    // m_scheduled_list/m_context_pool are a once resource -- use guarded version
    synchronized(m_scheduled_list) {
      while(idx < m_scheduled_list.length) {
	if(m_scheduled_list[idx].objection is this) {
	  m_scheduled_list[idx].clear();
	  m_context_pool.pushBack(m_scheduled_list[idx]);
	  m_scheduled_list.remove(idx);
	}
	else {
	  idx++;
	}
      }
    }

    // Scheduled contexts and m_forked_lists have duplicate
    // entries... clear out one, free the other.
    m_scheduled_contexts.clear();
    synchronized(m_forked_list) {
      while(m_forked_list.length) {
	m_forked_list[0].clear();
	m_context_pool.pushBack(_m_forked_list[0]);
	m_forked_list.removeFront();
      }
    }

    // running drains have a context and a process
    foreach(o, context; m_forked_contexts) {
      version(UVM_USE_PROCESS_CONTAINER) {
	m_drain_proc[o].p.abortRec();
	m_drain_proc.remove(o);
      }
      else {
	m_drain_proc[o].abortRec();
	m_drain_proc.remove(o);
      }

      m_forked_contexts[o].clear();
      m_context_pool.pushBack(_m_forked_contexts[o]);
      m_forked_contexts.remove(o);
    }

    m_top_all_dropped = false;
    m_cleared = true;

    synchronized(m_events) {
      if(m_top in m_events) {
	m_events[m_top].all_dropped.notify();
      }
    }
  }



  // Function: new
  //
  // Creates a new objection instance. Accesses the command line
  // argument +UVM_OBJECTION_TRACE to turn tracing on for
  // all objection objects.

  public this(string name="") {
    synchronized(this) {
      import uvm.base.uvm_cmdline_processor;

      string[] trace_args;
      super(name);
      set_report_verbosity_level(m_top.get_report_verbosity_level());

      // Get the command line trace mode setting
      uvm_cmdline_processor clp = uvm_cmdline_processor.get_inst();
      if(clp.get_arg_matches(`\+UVM_OBJECTION_TRACE`, trace_args)) {
	_m_trace_mode = true;
      }
      debug(UVM_OBJECTION_TRACE) {
	_m_trace_mode = true;
      }
      m_objections.pushBack(this);


      _m_scheduled_contexts = new SyncAssoc!(uvm_object,
					     uvm_objection_context_object)();
      _m_forked_list = new SyncQueue!uvm_objection_context_object();
      _m_forked_contexts = new SyncAssoc!(uvm_object,
					  uvm_objection_context_object)();

      version(UVM_USE_PROCESS_CONTAINER) {
	_m_drain_proc =  new SyncAssoc!(uvm_object, process_container_c);
      }
      else {
	_m_drain_proc = new SyncAssoc!(uvm_object, Process);
      }

      _m_total_count = new SyncAssoc!(uvm_object, int);
      _m_source_count = new SyncAssoc!(uvm_object, int);
      _m_drain_time = new SyncAssoc!(uvm_object, SimTime);
      _m_events = new SyncAssoc!(uvm_object, uvm_objection_events);

    }
  }

  // Function: trace_mode
  //
  // Set or get the trace mode for the objection object. If no
  // argument is specified (or an argument other than 0 or 1)
  // the current trace mode is unaffected. A trace_mode of
  // 0 turns tracing off. A trace mode of 1 turns tracing on.
  // The return value is the mode prior to being reset.

  final public bool trace_mode(int mode = -1) {
    synchronized(this) {
      bool retval = _m_trace_mode;
      if(mode is 0) _m_trace_mode = false;
      else if(mode is 1) _m_trace_mode = true;
      return retval;
    }
  }

  // Function- m_report
  //
  // Internal method for reporting count updates

  final public void m_report(uvm_object obj, uvm_object source_obj,
			     string description, int count, string action) {
    // declared in SV version but not used anywhere
    // string desc;
    int count_ = m_source_count.get(obj, 0);
    int total_ = m_total_count.get(obj, 0);

    if(!uvm_report_enabled(UVM_NONE,UVM_INFO, "OBJTN_TRC") ||
       !m_trace_mode) {
      return;
    }

    //desc = description == "" ? "" : {" ", description, "" };
    if(source_obj is obj) {
      uvm_report_info("OBJTN_TRC",
		      format("Object %0s %0s %0d objection(s)%s: "
			     "count=%0d  total=%0d",
			     (obj.get_full_name() == "") ?
			     "uvm_top" : obj.get_full_name(),
			     action, count,
			     (description != "") ?
			     " (" ~ description ~ ")" : "",
			     count_, total_), UVM_NONE);
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
      // while((sname[cpath] == nm[cpath]) && (cpath < max)) begin
      while((cpath < max) && (sname[cpath] is nm[cpath])) {
	if(sname[cpath] is '.') last_dot = cpath;
	++cpath;
      }

      if(last_dot != 0) sname = sname[last_dot+1..$];
      uvm_report_info("OBJTN_TRC",
		      format("Object %0s %0s %0d objection(s) %0s its "
			     "total (%s from source object %s%s): "
			     "count=%0d  total=%0d",
			     obj.get_full_name() == "" ?
			     "uvm_top" : obj.get_full_name(),
			     action == "raised" ? "added" : "subtracted",
			     count, action == "raised" ?
			     "to" : "from", action, sname,
			     description != "" ? ", "
			     ~ description : "", count_, total_), UVM_NONE);
    }
  }


  // Function- m_get_parent
  //
  // Internal method for getting the parent of the given ~object~.
  // The ultimate parent is uvm_top, UVM's implicit top-level component.

  final public uvm_object m_get_parent(uvm_object obj) {
    uvm_component comp = cast(uvm_component) obj;
    uvm_sequence_base seq = cast(uvm_sequence_base) obj;
    if(comp !is null) {
      obj = comp.get_parent();
    }
    else if(seq !is null) {
      obj = seq.get_sequencer();
    }
    else obj = m_top;
    if(obj is null) obj = m_top;
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

  final public void m_propagate (uvm_object obj,
				 uvm_object source_obj,
				 string description,
				 int count,
				 bool raise,
				 int in_top_thread) {
    if(obj !is null && obj !is m_top) {
      obj = m_get_parent(obj);
      if(raise) m_raise(obj, source_obj, description, count);
      else m_drop(obj, source_obj, description, count, in_top_thread);
    }
  }

  // Group: Objection Control

  // Function: m_set_hier_mode
  //
  // Hierarchical mode only needs to be set for intermediate components, not
  // for uvm_root or a leaf component.

  final public void m_set_hier_mode (uvm_object obj) {
    if((m_hier_mode is true) || (obj is m_top)) {
      // Don't set if already set or the object is uvm_top.
      return;
    }
    uvm_component c = cast(uvm_component) obj;
    if(c !is null) {
      // Don't set if object is a leaf.
      if(c.get_num_children() is 0) {
	return;
      }
    }
    else {
      // Don't set if object is a non-component.
      return;
    }

    // restore counts on non-source nodes
    m_total_count.clear(); //  = null;

    // used keys to avoid sync lock around foreach body
    foreach (theobj, count; m_source_count) {
      // uvm_object theobj = obj;
      do {
	synchronized(m_total_count) {
	  if(theobj in m_total_count) {
	    m_total_count[theobj] += count;
	  }
	  else {
	    m_total_count[theobj] = count;
	  }
	}
	theobj = m_get_parent(theobj);
      } while(theobj !is null);
    }
    m_hier_mode = true;
  }


  // Function: raise_objection
  //
  // Raises the number of objections for the source ~object~ by ~count~, which
  // defaults to 1.  The ~object~ is usually the ~this~ handle of the caller.
  // If ~object~ is not specified or null, the implicit top-level component,
  // <uvm_root>, is chosen.
  //
  // Rasing an objection causes the following.
  //
  // - The source and total objection counts for ~object~ are increased by
  //   ~count~. ~description~ is a string that marks a specific objection
  //   and is used in tracing/debug.
  //
  // - The objection's <raised> virtual method is called, which calls the
  //   <uvm_component.raised> method for all of the components up the
  //   hierarchy.
  //

  public void raise_objection (uvm_object obj = null,
			       string description = "",
			       int count = 1) {
    if(obj is null) obj = m_top;
    synchronized(this) {
      _m_cleared = true;
      _m_top_all_dropped = false;
    }
    m_raise (obj, obj, description, count);
  }


  // Function- m_raise

  final public void m_raise (uvm_object obj,
			     uvm_object source_obj,
			     string description = "",
			     int count = 1) {
    synchronized(m_total_count) {
      if(obj in m_total_count) {
	m_total_count[obj] += count;
      }
      else {
	m_total_count[obj] = count;
      }
    }
    synchronized(m_source_count) {
      if(source_obj is obj) {
	if(obj in m_source_count) {
	  m_source_count[obj] += count;
	}
	else {
	  m_source_count[obj] = count;
	}
      }
    }
    if(m_trace_mode) {
      m_report(obj, source_obj, description, count, "raised");
    }

    raised(obj, source_obj, description, count);

    // Handle any outstanding drains...

    // First go through the scheduled list
    int idx = 0;
    uvm_objection_context_object ctxt;
    synchronized(m_scheduled_list) {
      while(idx < m_scheduled_list.length) {
	if((m_scheduled_list[idx].obj is obj) &&
	   (m_scheduled_list[idx].objection is this)) {
	  // Caught it before the drain was forked
	  ctxt = m_scheduled_list[idx];
	  m_scheduled_list.remove(idx);
	  break;
	}
	idx++;
      }
    }

    // If it's not there, go through the forked list
    if(ctxt is null) {
      idx = 0;
      synchronized(m_forked_list) {
	while(idx < m_forked_list.length) {
	  if(m_forked_list[idx].obj is obj) {
	    // Caught it after the drain was forked,
	    // but before the fork started
	    ctxt = m_forked_list[idx];
	    m_forked_list.remove(idx);
	    m_scheduled_contexts.remove(ctxt.obj);
	    break;
	  }
	  idx++;
	}
      }
    }

    // If it's not there, go through the forked contexts
    if(ctxt is null) {
      synchronized(m_forked_contexts) {
	if(obj in m_forked_contexts) {
	  // Caught it with the forked drain running
	  ctxt = m_forked_contexts[obj];
	  m_forked_contexts.remove(obj);
	  // Kill the drain
	  version(UVM_USE_PROCESS_CONTAINER) {
	    m_drain_proc[obj].p.abortRec();
	    m_drain_proc.remove(obj);
	  }
	  else {
	    m_drain_proc[obj].abortRec();
	    m_drain_proc.remove(obj);
	  }

	}
      }
    }

    if(ctxt is null) {
      // If there were no drains, just propagate as usual

      if(!m_hier_mode && obj !is m_top) {
	m_raise(m_top, source_obj, description, count);
      }
      else if(obj !is m_top) {
	m_propagate(obj, source_obj, description, count, true, 0);
      }
    }
    else { // Otherwise we need to determine what exactly happened

      // Determine the diff count, if it's positive, then we're
      // looking at a 'raise' total, if it's negative, then
      // we're looking at a 'drop', but not down to 0.  If it's
      // a '0', that means that there is no change in the total.
      int diff_count = count - ctxt.count;

      if(diff_count !is 0) {
	// Something changed
	if(diff_count > 0) {
	  // we're looking at an increase in the total
	  if(!m_hier_mode && obj !is m_top) {
	    m_raise(m_top, source_obj, description, diff_count);
	  }
	  else if(obj !is m_top) {
	    m_propagate(obj, source_obj, description, diff_count, true, 0);
	  }
	}
	else {
	  // we're looking at a decrease in the total
	  // The count field is always positive...
	  diff_count = -diff_count;
	  if(!m_hier_mode && obj !is m_top) {
	    m_drop(m_top, source_obj, description, diff_count);
	  }
	  else if(obj !is m_top) {
	    m_propagate(obj, source_obj, description, diff_count, false, 0);
	  }
	}
      }

      // Cleanup
      ctxt.clear();
      m_context_pool.pushBack(ctxt);
    }
  }


  // Function: drop_objection
  //
  // Drops the number of objections for the source ~object~ by ~count~, which
  // defaults to 1.  The ~object~ is usually the ~this~ handle of the caller.
  // If ~object~ is not specified or null, the implicit top-level component,
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
  // If a new objection for this ~object~ or any of its descendents is raised
  // during the drain time or during execution of the all_dropped callback at
  // any point, the hierarchical chain described above is terminated and the
  // dropped callback does not go up the hierarchy. The raised objection will
  // propagate up the hierarchy, but the number of raised propagated up is
  // reduced by the number of drops that were pending waiting for the
  // all_dropped/drain time completion. Thus, if exactly one objection
  // caused the count to go to zero, and during the drain exactly one new
  // objection comes in, no raises or drops are propagted up the hierarchy,
  //
  // As an optimization, if the ~object~ has no set drain-time and no
  // registered callbacks, the forked process can be skipped and propagation
  // proceeds immediately to the parent as described.

  public void drop_objection (uvm_object obj=null,
			      string description="",
			      int count=1) {
    if(obj is null) obj = m_top;
    m_drop(obj, obj, description, count, 0);
  }


  // Function- m_drop

  final public void m_drop (uvm_object obj,
			    uvm_object source_obj,
			    string description = "",
			    int count = 1,
			    int in_top_thread = 0) {
    synchronized(m_total_count) {
      if(obj !in m_total_count || (count > m_total_count[obj])) {
    	if(m_cleared) return;
    	uvm_report_fatal("OBJTN_ZERO", "Object \"" ~ obj.get_full_name() ~
    			 "\" attempted to drop objection '" ~ this.get_name()
    			 ~ "' count below zero");
    	return;
      }

      if(obj is source_obj) {
    	synchronized(m_source_count) {
    	  if(obj !in m_source_count || (count > m_source_count[obj])) {
    	    if(m_cleared) return;
    	    uvm_report_fatal("OBJTN_ZERO", "Object \"" ~  obj.get_full_name() ~
    			     "\" attempted to drop objection '" ~
    			     this.get_name() ~ "' count below zero");
    	    return;
    	  }
    	  m_source_count[obj] -= count;
    	}
      }
      m_total_count[obj] -= count;

      if(m_trace_mode) {
	m_report(obj, source_obj, description, count, "dropped");
      }

      dropped(obj, source_obj, description, count);

      // if count !is 0, no reason to fork
      if(m_total_count[obj] !is 0) {
	if(!m_hier_mode && obj !is m_top) {
	  m_drop(m_top, source_obj, description, count, in_top_thread);
	}
	else if(obj !is m_top) {
	  this.m_propagate(obj, source_obj, description, count, false, in_top_thread);
	}
      }
      else {
	uvm_objection_context_object ctxt;
	synchronized(m_context_pool) {
	  if(m_context_pool.length !is 0) {
	    m_context_pool.popFront(ctxt);
	  }
	  else {
	    ctxt = new uvm_objection_context_object();
	  }
	}

	ctxt.obj = obj;
	ctxt.source_obj = source_obj;
	ctxt.description = description;
	ctxt.count = count;
	ctxt.objection = this;
	// Need to be thread-safe, let the background
	// process handle it.

	// Why don't we look at in_top_thread here?  Because
	// a re-raise will kill the drain at object that it's
	// currently occuring at, and we need the leaf-level kills
	// to not cause accidental kills at branch-levels in
	// the propagation.

	// Using the background process just allows us to
	// seperate the links of the chain.
	m_scheduled_list.pushBack(ctxt);
	m_scheduled_list_event.notify();
      } // else: !if(m_total_count[obj] !is 0)
    }
  }


  // m_execute_scheduled_forks
  // -------------------------

  // background process; when non

  // task
  static public void m_execute_scheduled_forks() {
    while(true) {
      // wait(m_scheduled_list.size() !is 0);
      wait(m_scheduled_list_event);
      synchronized(m_scheduled_list) {
	while(m_scheduled_list.length !is 0) {
	  uvm_objection o;
	  // Save off the context before the fork
	  uvm_objection_context_object c;
	  m_scheduled_list.popFront(c);
	  // A re-raise can use this to figure out props (if any)
	  c.objection.m_scheduled_contexts[c.obj] = c;
	  // The fork below pulls out from the forked list
	  c.objection.m_forked_list.pushBack(c);
	  // The fork will guard the m_forked_drain call, but
	  // a re-raise can kill m_forked_list contexts in the delta
	  // before the fork executes.

	  (uvm_objection objection) {
	    auto guard = fork({
		// Check to maike sure re-raise didn't empty the fifo
		uvm_objection_context_object ctxt;
		synchronized(objection.m_forked_list) {
		  if(objection.m_forked_list.length > 0) {
		    objection.m_forked_list.popFront(ctxt);
		    // Clear it out of scheduled
		    objection.m_scheduled_contexts.remove(ctxt.obj);
		    // Move it in to forked (so re-raise can figure out props)
		    objection.m_forked_contexts[ctxt.obj] = ctxt;
		    // Save off our process handle, so a re-raise can kill it...
		    version(UVM_USE_PROCESS_CONTAINER) {
		      process_container_c c = new process_container_c(Process.self);
		      objection.m_drain_proc[ctxt.obj]=c;
		    }
		    else {
		      objection.m_drain_proc[ctxt.obj] = Process.self;
		    }
		  }
		}
		if(ctxt !is null) {
		  // Execute the forked drain -- m_forked_drain is a task
		  objection.m_forked_drain(ctxt.obj, ctxt.source_obj,
					   ctxt.description, ctxt.count, 1);
		  // Cleanup if we survived (no re-raises)
		  objection.m_drain_proc.remove(ctxt.obj);
		  objection.m_forked_contexts.remove(ctxt.obj);
		  // Clear out the context object (prevent memory leaks)
		  ctxt.clear();
		  // Save the context in the pool for later reuse
		  m_context_pool.pushBack(ctxt);
		}
	      });
	  } (c.objection);
	}
      }
    }
  }


  // m_forked_drain
  // -------------

  final public void m_forked_drain (uvm_object obj,
				    uvm_object source_obj,
				    string description = "",
				    int count = 1,
				    int in_top_thread = 0) {

    int diff_count;

    synchronized(m_drain_time) {
      if(obj in m_drain_time) {
	wait(m_drain_time[obj]);
      }
    }

    if(m_trace_mode) {
      m_report(obj, source_obj, description, count, "all_dropped");
    }

    all_dropped(obj, source_obj, description, count);

    // wait for all_dropped cbs to complete
    waitForks();

    /* NOT NEEDED - Any raise would have killed us!
       if(!m_total_count.exists(obj))
       diff_count = -count;
       else
       diff_count = m_total_count[obj] - count;
    */

    // we are ready to delete the 0-count entries for the current
    // object before propagating up the hierarchy.
    synchronized(m_source_count) {
      if(obj in m_source_count && m_source_count[obj] is 0) {
	m_source_count.remove(obj);
      }
    }

    synchronized(m_total_count) {
      if(obj in m_total_count && m_total_count[obj] is 0) {
	m_total_count.remove(obj);
      }
    }

    if(!m_hier_mode && obj !is m_top) {
      m_drop(m_top, source_obj, description, count, 1);
    }
    else if(obj !is m_top) {
      m_propagate(obj, source_obj, description, count, false, 1);
    }
  }


  // m_init_objections
  // -----------------

  // Forks off the single background process
  static public void m_init_objections() {
    fork({uvm_objection.m_execute_scheduled_forks();});
  }

  // Function: set_drain_time
  //
  // Sets the drain time on the given ~object~ to ~drain~.
  //
  // The drain time is the amount of time to wait once all objections have
  // been dropped before calling the all_dropped callback and propagating
  // the objection to the parent.
  //
  // If a new objection for this ~object~ or any of its descendents is raised
  // during the drain time or during execution of the all_dropped callbacks,
  // the drain_time/all_dropped execution is terminated.

  // AE: set_drain_time(drain,obj=null)?
  final public void set_drain_time (uvm_object obj, SimTime drain) {
    if(obj is null) obj = m_top;
    m_drain_time[obj] = drain;
    m_set_hier_mode(obj);
  }

  //----------------------
  // Group: Callback Hooks
  //----------------------

  // Function: raised
  //
  // Objection callback that is called when a <raise_objection> has reached ~obj~.
  // The default implementation calls <uvm_component::raised>.

  public void raised (uvm_object obj,
		      uvm_object source_obj,
		      string description,
		      int count) {
    uvm_component comp = cast(uvm_component) obj;
    if(comp !is null) comp.raised(this, source_obj, description, count);
    synchronized(m_events) {
      if(obj in m_events) m_events[obj].raised.notify();
    }
  }


  // Function: dropped
  //
  // Objection callback that is called when a <drop_objection> has reached ~obj~.
  // The default implementation calls <uvm_component::dropped>.

  public void dropped (uvm_object obj,
		       uvm_object source_obj,
		       string description,
		       int count) {
    uvm_component comp = cast(uvm_component) obj;
    if(comp !is null) comp.dropped(this, source_obj, description, count);
    synchronized(m_events) {
      if(obj in m_events) m_events[obj].dropped.notify();
    }
  }


  // Function: all_dropped
  //
  // Objection callback that is called when a <drop_objection> has reached ~obj~,
  // and the total count for ~obj~ goes to zero. This callback is executed
  // after the drain time associated with ~obj~. The default implementation
  // calls <uvm_component::all_dropped>.

  public void all_dropped (uvm_object obj,
			   uvm_object source_obj,
			   string description,
			   int count) {
    uvm_component comp = cast(uvm_component) obj;
    if(comp !is null) comp.all_dropped(this, source_obj, description, count);
    synchronized(m_events) {
      if(obj in m_events) m_events[obj].all_dropped.notify();
    }
    if(obj is m_top) m_top_all_dropped = true;
  }


  //------------------------
  // Group: Objection Status
  //------------------------

  // Function: get_objectors
  //
  // Returns the current list of objecting objects (objects that
  // raised an objection but have not dropped it).

  final public void get_objectors(ref Queue!uvm_object list) {
    list.clear;
    foreach (obj, count; m_source_count) {
      list.pushBack(obj);
    }
  }

  final public void get_objectors(ref uvm_object[] list) {
    list.clear;
    foreach (obj, count; m_source_count) {
      list ~= obj;
    }
  }

  final public uvm_object[] get_objectors() {
    uvm_object[] list;
    get_objectors(list);
    return list;
  }


  // Task: wait_for
  //
  // Waits for the raised, dropped, or all_dropped ~event~ to occur in
  // the given ~obj~. The task returns after all corresponding callbacks
  // for that event have been executed.
  //
  // task
  final public void wait_for(uvm_objection_event objt_event, uvm_object obj=null) {

    if(obj is null) obj = m_top;
    synchronized(m_events) {
      if(obj !in m_events) {
	m_events[obj] = new uvm_objection_events;
      }
      m_events[obj].inc_waiters;
    }
    final switch(objt_event) {
    case UVM_RAISED:      wait(m_events[obj].raised); break;
    case UVM_DROPPED:     wait(m_events[obj].dropped); break;
    case UVM_ALL_DROPPED: wait(m_events[obj].all_dropped); break;
    }

    synchronized(m_events) {
      m_events[obj].dec_waiters;
      if(m_events[obj].waiters is 0) m_events.remove(obj);
    }
  }
    

  // function wait_for_total_count is not documented in the UVM API
  // doc, nor is it used anywhere inside the UVM

  // public void wait_for_total_count(uvm_object obj=null, int count=0) {
  //   AssocWithEvent!(uvm_object, int) total_count;
  //   synchronized(this) {
  //     total_count = m_total_count;
  //     if(obj is null)
  //	obj = m_top;
  //     if(obj !in m_total_count && count is 0)
  //	return;
  //   }

  //   if(count is 0) {
  //     while(obj in total_count) {
  //	wait(total_count);
  //     }
  //     wait (!m_total_count.exists(obj));
  //    else
  //       wait (m_total_count.exists(obj) && m_total_count[obj] is count);
  //  endtask


  // Function: get_objection_count
  //
  // Returns the current number of objections raised by the given ~object~.

  final public int get_objection_count (uvm_object obj=null) {
    if(obj is null) obj = m_top;

    synchronized(m_source_count) {
      if(obj !in m_source_count) return 0;
      return m_source_count[obj];
    }
  }


  // Function: get_objection_total
  //
  // Returns the current number of objections raised by the given ~object~
  // and all descendants.

  final public int get_objection_total(uvm_object obj = null) {
    int retval;
    if(obj is null) obj = m_top;
    synchronized(m_total_count) {
      if(obj !in m_total_count) return 0;
      if(m_hier_mode) return m_total_count[obj];
      else {
	uvm_component c = cast(uvm_component) obj;
	if(c !is null) {
	  synchronized(m_source_count) {
	    if(obj !in m_source_count) retval = 0;
	    else retval = m_source_count[obj];
	  }
	  foreach(ch; c.get_children()) {
	    retval += get_objection_total(ch);
	  }
	  return retval;
	}
	else {
	  return m_total_count[obj];
	}
      }
    }
  }


  // Function: get_drain_time
  //
  // Returns the current drain time set for the given ~object~ (default: 0 ns).

  final public SimTime get_drain_time (uvm_object obj = null) {
    if(obj is null) obj = m_top;

    synchronized(m_drain_time) {
      if(obj !in m_drain_time)	return SimTime(0);
      return m_drain_time[obj];
    }
  }


  // m_display_objections

  final protected string m_display_objections(uvm_object obj = null,
					      bool show_header = true) {
    enum string blank = "                                       "
      "                                            ";

    uvm_object[string] list;
    foreach (theobj, count; m_total_count) {
      if( count > 0) list[theobj.get_full_name()] = theobj;
    }

    if(obj is null) obj = m_top;

    int total = get_objection_total(obj);

    string s = format("The total objection count is %0d\n",total);

    if(total is 0) return s;

    s ~= "---------------------------------------------------------\n";
    s ~= "Source  Total   \n";
    s ~= "Count   Count   Object\n";
    s ~= "---------------------------------------------------------\n";


    string this_obj_name = obj.get_full_name();
    string curr_obj_name = this_obj_name;

    string[string] table;

    foreach (o, count; m_total_count) {
      string name = o.get_full_name;
      if(count > 0 && (name == curr_obj_name ||
		       (name.length > curr_obj_name.length &&
			name[0..curr_obj_name.length+1] == (curr_obj_name ~ ".")))) {
	import std.string;
	size_t depth = countchars(name, ".");

	string leafName = curr_obj_name[lastIndexOf(curr_obj_name, '.')+1..$];

	if(curr_obj_name == "")
	  leafName = "uvm_top";
	else
	  depth++;

	table[name] = format("%-6d  %-6d %s%s\n",
			     m_source_count.get(o, 0),
			     m_total_count.get(o, 0),
			     blank[0..2*depth+1], leafName);
      }
    }
    import std.algorithm;
    foreach(key; sort(table.keys)) {
      s ~= table[key];
    }

    s ~= "---------------------------------------------------------\n";

    return s;

  }

  public string to(S)() if(is(S == string)) {
    return m_display_objections(m_top, true);
  }

  override public string convert2string() {
    return m_display_objections(m_top, true);
  }




  // Function: display_objections
  //
  // Displays objection information about the given ~object~. If ~object~ is
  // not specified or ~null~, the implicit top-level component, <uvm_root>, is
  // chosen. The ~show_header~ argument allows control of whether a header is
  // output.

  final public void display_objections(uvm_object obj=null, bool show_header = true) {
    import uvm.meta.mcd;
    vdisplay(m_display_objections(obj, show_header));
  }


  // Below is all of the basic data stuff that is needed for an uvm_object
  // for factory registration, printing, comparing, etc.

  alias uvm_object_registry!(uvm_objection,"uvm_objection") type_id;

  static public type_id get_type() {
    return type_id.get();
  }

  override public uvm_object create (string name="") {
    return new uvm_objection(name);
  }

  override public string get_type_name () {
    return typeid(this).stringof;
  }

  override public void do_copy (uvm_object rhs) {
    uvm_objection _rhs = cast(uvm_objection) rhs;
    m_source_count = _rhs.m_source_count.dup;
    m_total_count  = _rhs.m_total_count.dup;
    m_drain_time   = _rhs.m_drain_time.dup;
    m_hier_mode    = _rhs.m_hier_mode;
  }

}


version(UVM_USE_CALLBACKS_OBJECTION_FOR_TEST_DONE) {
  alias uvm_callbacks_objection m_uvm_test_done_objection_base;
}
 else {
   alias uvm_objection m_uvm_test_done_objection_base;
 }


// TODO: change to plusarg
public SimTime uvm_default_timeout() {
  return SimTime(getRootEntity(), UVM_DEFAULT_TIMEOUT);
}

// typedef class uvm_cmdline_processor;



class uvm_once_test_done_objection
{
  @uvm_protected_sync private uvm_test_done_objection _m_inst;
  this() {
    _m_inst = new uvm_test_done_objection("run");
  }
}

//------------------------------------------------------------------------------
//
// Class- uvm_test_done_objection DEPRECATED
//
// Provides built-in end-of-test coordination
//------------------------------------------------------------------------------

class uvm_test_done_objection: m_uvm_test_done_objection_base
{
  mixin(uvm_once_sync!uvm_once_test_done_objection);
  mixin(uvm_sync!uvm_test_done_objection);

  // Seems redundant -- not used anywhere -- declared in SV version
  // protected bool m_forced;

  // For communicating all objections dropped and end of phasing
  @uvm_private_sync private bool _m_executing_stop_processes;
  @uvm_private_sync private int _m_n_stop_threads;
  private Event _m_n_stop_threads_event;


  // Function- new DEPRECATED
  //
  // Creates the singleton test_done objection. Users must not to call
  // this method directly.

  public this(string name = "uvm_test_done") {
    synchronized(this) {
      super(name);
      _m_n_stop_threads_event.init();
      version(UVM_NO_DEPRECATED) {}
      else {
	_stop_timeout = new WithEvent!SimTime(SimTime(0));
      }
    }
  }


  // Function- qualify DEPRECATED
  //
  // Checks that the given ~object~ is derived from either <uvm_component> or
  // <uvm_sequence_base>.

  public void qualify(uvm_object obj,
		      bool is_raise,
		      string description) {
    uvm_component c = cast(uvm_component) obj;
    uvm_sequence_base s = cast(uvm_sequence_base) obj;
    string nm = is_raise ? "raise_objection" : "drop_objection";
    string desc = description == "" ? "" : " (\"" ~ description ~ "\")";

    if(c is null && s is null) {
      uvm_report_error("TEST_DONE_NOHIER",
		       "A non-hierarchical object, '" ~ obj.get_full_name() ~
		       "' (" ~ obj.get_type_name() ~ ") was used in a call " ~
		       "to uvm_test_done." ~ nm ~
		       "(). For this objection, a sequence " ~
		       "or component is required." ~ desc );
    }
  }


  version(UVM_NO_DEPRECATED) { }
  else {
    // m_do_stop_all
    // -------------

    // task
    final public void m_do_stop_all(uvm_component comp) {
      // we use an external traversal to ensure all forks are
      // made from a single thread.
      foreach(child; comp.get_children) {
	m_do_stop_all(child);
      }

      if (comp.enable_stop_interrupt) {
	synchronized(this) {
	  _m_n_stop_threads++;
	  _m_n_stop_threads_event.notify();
	}
	fork({
	    comp.stop_phase(run_ph);
	    synchronized(this) {
	      _m_n_stop_threads--;
	      _m_n_stop_threads_event.notify();
	    }
	  });
      }
    }



    // Function- stop_request DEPRECATED
    //
    // Calling this function triggers the process of shutting down the currently
    // running task-based phase. This process involves calling all components'
    // stop tasks for those components whose enable_stop_interrupt bit is set.
    // Once all stop tasks return, or once the optional global_stop_timeout
    // expires, all components' kill method is called, effectively ending the
    // current phase. The uvm_top will then begin execution of the next phase,
    // if any.

    final public void stop_request() {
      synchronized(this) {
	uvm_info_context("STOP_REQ",
			 "Stop-request called. Waiting for all-dropped on uvm_test_done",
			 UVM_FULL, m_top);
	fork({m_stop_request();});
      }
    }

    // task
    final public void m_stop_request() {
      raise_objection(m_top,
		      "stop_request called; raising test_done objection");
      uvm_wait_for_nba_region();
      drop_objection(m_top,
		     "stop_request called; dropping test_done objection");
    }

    // Variable- stop_timeout DEPRECATED
    //
    // These set watchdog timers for task-based phases and stop tasks. You can not
    // disable the timeouts. When set to 0, a timeout of the maximum time possible
    // is applied. A timeout at this value usually indicates a problem with your
    // testbench. You should lower the timeout to prevent "never-ending"
    // simulations.

    @uvm_immutable_sync
      private WithEvent!SimTime _stop_timeout; // = 0;


    // Task- all_dropped DEPRECATED
    //
    // This callback is called when the given ~object's~ objection count reaches
    // zero; if the ~object~ is the implicit top-level, <uvm_root> then it means
    // there are no more objections raised for the ~uvm_test_done~ objection.
    // Thus, after calling <uvm_objection::all_dropped>, this method will call
    // <global_stop_request> to stop the current task-based phase (e.g. run).

    override public void all_dropped (uvm_object obj,
				      uvm_object source_obj,
				      string description,
				      int count) {
      if (obj !is m_top) {
	super.all_dropped(obj,source_obj,description,count);
	return;
      }

      m_top.all_dropped(this, source_obj, description, count);

      // All stop tasks are forked from a single thread within a 'guard' process
      // so 'disable fork' can be used.

      if(m_cleared is false) {
	uvm_info_context("TEST_DONE",
			 "All end-of-test objections have been dropped. Calling stop tasks",
			 UVM_FULL, m_top);
	// join({ // guard
	Fork guard = fork({
	    m_executing_stop_processes = 1;
	    m_do_stop_all(m_top);
	    while(m_n_stop_threads != 0) {
	      wait(_m_n_stop_threads_event);
	    }
	    m_executing_stop_processes = 0;
	  },
	  {
	    if (stop_timeout == 0)
	      wait(stop_timeout != 0);
	    wait(stop_timeout);
	    uvm_error("STOP_TIMEOUT",
		      format("Stop-task timeout of %0t expired. ",
			     stop_timeout) ~
		      "'run' phase ready to proceed to extract phase");
	  });
	guard.joinAny();
	guard.abortRec();

	uvm_info_context("TEST_DONE", "'run' phase is ready "
			 "to proceed to the 'extract' phase", UVM_LOW,m_top);
      }

      synchronized(m_events) {
	if (obj in m_events) {
	  m_events[obj].all_dropped.notify();
	}
      }

      m_top_all_dropped = true;
    }


    // Function- raise_objection DEPRECATED
    //
    // Calls <uvm_objection::raise_objection> after calling <qualify>.
    // If the ~object~ is not provided or is ~null~, then the implicit top-level
    // component, ~uvm_top~, is chosen.

    override public void raise_objection (uvm_object obj = null,
					  string description = "",
					  int count = 1) {
      if(obj is null) obj = m_top;
      else qualify(obj, 1, description);

      if (m_executing_stop_processes) {
	string desc = description == "" ? "" : "(\"" ~ description ~ "\") ";
	uvm_warning("ILLRAISE", "The uvm_test_done objection was "
		    "raised " ~ desc ~ "during processing of a stop_request,"
		    " i.e. stop task execution. The objection is ignored by "
		    "the stop process");
	return;
      }
      super.raise_objection(obj,description,count);
    }


    // Function- drop_objection DEPRECATED
    //
    // Calls <uvm_objection::drop_objection> after calling <qualify>.
    // If the ~object~ is not provided or is ~null~, then the implicit top-level
    // component, ~uvm_top~, is chosen.

    override public void drop_objection (uvm_object obj = null,
					 string description = "",
					 int count = 1) {
      if(obj is null) obj=m_top;
      else qualify(obj, 0, description);
      super.drop_objection(obj,description,count);
    }


    // Task- force_stop DEPRECATED
    //
    // Forces the propagation of the all_dropped() callback, even if there are still
    // outstanding objections. The net effect of this action is to forcibly end
    // the current phase.

    public void force_stop(uvm_object obj = null) {
      uvm_report_warning("FORCE_STOP", "Object '" ~
			 (obj !is null ? obj.get_name() : "<unknown>") ~
			 "' called force_stop");
      m_cleared = true;
      all_dropped(m_top,obj, "force_stop() called", true);
      clear(obj);
    }


  }

  // Below are basic data operations needed for all uvm_objects
  // for factory registration, printing, comparing, etc.

  // FIXME -- dependency on uvm_registry
  alias uvm_object_registry!(uvm_test_done_objection, "uvm_test_done") type_id;

  static public type_id get_type() {
    return type_id.get();
  }

  override public uvm_object create (string name = "") {
    uvm_test_done_objection tmp = new uvm_test_done_objection(name);
    return tmp;
  }

  override public string get_type_name () {
    return "uvm_test_done";
  }

  static public uvm_test_done_objection get() {
    if(m_inst is null) m_inst = uvm_test_done_objection.type_id.create("run");
    return m_inst;
  }

}



// Have a pool of context objects to use
class uvm_objection_context_object
{
  mixin(uvm_sync!uvm_objection_context_object);
  @uvm_private_sync
  private uvm_object _obj;
  @uvm_private_sync
  private uvm_object _source_obj;
  @uvm_private_sync
  private string _description;
  @uvm_private_sync
  private int    _count;
  @uvm_private_sync
  private uvm_objection _objection;

  // Clears the values stored within the object,
  // preventing memory leaks from reused objects
  public void clear() {
    synchronized(this) {
      _obj = null;
      _source_obj = null;
      _description = "";
      _count = 0;
      _objection = null;
    }
  }
}


// FIXME

//------------------------------------------------------------------------------
//
// Class: uvm_callbacks_objection
//
//------------------------------------------------------------------------------
// The uvm_callbacks_objection is a specialized <uvm_objection> which contains
// callbacks for the raised and dropped events. Callbacks happend for the three
// standard callback activities, <raised>, <dropped>, and <all_dropped>.
//
// The <uvm_heartbeat> mechanism use objections of this type for creating
// heartbeat conditions.  Whenever the objection is raised or dropped, the component
// which did the raise/drop is considered to be alive.
//


class uvm_callbacks_objection: uvm_objection
{
  // in the constructor
  //   `uvm_register_cb(uvm_callbacks_objection, uvm_objection_callback)

  public this(string name="") {
    super(name);
    uvm_callbacks!(uvm_callbacks_objection,
		   uvm_objection_callback).m_register_pair();
  }

  // Return callbacks in form of a range
  // CB would be uvm_objection_callback in most cases
  public auto get_callbacks(CB)() {
    uvm_queue!uvm_callback q;
    uvm_callbacks!(uvm_callbacks_objection,CB).m_get_q(q, this);
    return q;
  }

  // Function: raised
  //
  // Executes the <uvm_objection_callback::raised> method in the user callback
  // class whenever this objection is raised at the object ~obj~.

  override public void raised (uvm_object obj, uvm_object source_obj,
			       string description, int count) {
    foreach(cb; get_callbacks!uvm_objection_callback()) {
      auto callb = cast(uvm_objection_callback) cb;
      if(callb !is null && callb.callback_mode) {
	callb.raised(this,obj,source_obj,description,count);
      }
    }
  }

  // Function: dropped
  //
  // Executes the <uvm_objection_callback::dropped> method in the user callback
  // class whenever this objection is dropped at the object ~obj~.

  override public void dropped (uvm_object obj, uvm_object source_obj,
				string description, int count) {
    foreach(cb; get_callbacks!uvm_objection_callback()) {
      auto callb = cast(uvm_objection_callback) cb;
      if(callb !is null && callb.callback_mode) {
	callb.dropped(this,obj,source_obj,description,count);
      }
    }
  }

  // Function: all_dropped
  //
  // Executes the <uvm_objection_callback::all_dropped> task in the user callback
  // class whenever the objection count for this objection in reference to ~obj~
  // goes to zero.

  // task
  override public void all_dropped (uvm_object obj, uvm_object source_obj,
				    string description, int count) {
    foreach(cb; get_callbacks!uvm_objection_callback()) {
      auto callb = cast(uvm_objection_callback) cb;
      if(callb !is null && callb.callback_mode) {
	callb.all_dropped(this,obj,source_obj,description,count);
      }
    }
  }

}

//------------------------------------------------------------------------------
//
// Class: uvm_objection_callback
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
//|     $display("%0t: Objection %s: Raised for %s", $time, objection.get_name(),
//|         obj.get_full_name());
//|   endfunction
//| endclass
//| ...
//| initial {
//|   my_objection_cb cb = new("cb");
//|   uvm_objection_cbs_t::add(null, cb); //typewide callback
//| }


class uvm_objection_callback: uvm_callback
{
  this(string name) {
    super(name);
  }

  // Function: raised
  //
  // Objection raised callback function. Called by <uvm_callbacks_objection::raised>.

  public void raised (uvm_objection objection, uvm_object obj,
		      uvm_object source_obj, string description, int count) {
  }

  // Function: dropped
  //
  // Objection dropped callback function. Called by <uvm_callbacks_objection::dropped>.

  public void dropped (uvm_objection objection, uvm_object obj,
		       uvm_object source_obj, string description, int count) {
  }

  // Function: all_dropped
  //
  // Objection all_dropped callback function. Called by <uvm_callbacks_objection::all_dropped>.

  // task
  public void all_dropped (uvm_objection objection, uvm_object obj,
			   uvm_object source_obj, string description,
			   int count) {
  }
}
