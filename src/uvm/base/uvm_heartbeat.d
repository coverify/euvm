//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2009 Cadence Design Systems, Inc.
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

// `ifndef UVM_HEARTBEAT_SVH
// `define UVM_HEARTBEAT_SVH

module uvm.base.uvm_heartbeat;

import uvm.base.uvm_root;
import uvm.base.uvm_object;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_component;
import uvm.base.uvm_callback;
import uvm.base.uvm_event;
import uvm.base.uvm_objection;
import esdl.base.core;
import esdl.base.time;

import std.string: format;

import uvm.meta.misc;

enum uvm_heartbeat_modes
  {    UVM_ALL_ACTIVE,
       UVM_ONE_ACTIVE,
       UVM_ANY_ACTIVE,
       UVM_NO_HB_MODE
  }

mixin(declareEnums!uvm_heartbeat_modes());

// typedef class uvm_heartbeat_callback;
alias uvm_callbacks!(uvm_callbacks_objection, uvm_heartbeat_callback)
  uvm_heartbeat_cbs_t;


//------------------------------------------------------------------------------
//
// Class: uvm_heartbeat
//
//------------------------------------------------------------------------------
// Heartbeats provide a way for environments to easily ensure that their
// descendants are alive. A uvm_heartbeat is associated with a specific
// objection object. A component that is being tracked by the heartbeat
// object must raise (or drop) the synchronizing objection during
// the heartbeat window. The synchronizing objection must be a
// <uvm_callbacks_objection> type.
//
// The uvm_heartbeat object has a list of participating objects. The heartbeat
// can be configured so that all components (UVM_ALL_ACTIVE), exactly one
// (UVM_ONE_ACTIVE), or any component (UVM_ANY_ACTIVE) must trigger the
// objection in order to satisfy the heartbeat condition.
//------------------------------------------------------------------------------

// typedef class uvm_objection_callback;
class uvm_heartbeat: uvm_object
{
  import esdl.data.queue;
  mixin(uvm_sync!uvm_heartbeat);

  protected uvm_callbacks_objection _m_objection;

  @uvm_immutable_sync
    protected uvm_heartbeat_callback _m_cb;

  protected uvm_component   _m_cntxt;
  protected uvm_heartbeat_modes   _m_mode;
  // protected Queue!uvm_component   _m_hblist; // FIXME -- variable not used anywhere
  @uvm_private_sync
    protected uvm_event       _m_event;

  protected bool             _m_started;
  protected Event           _m_stop_event;

  // Function: new
  //
  // Creates a new heartbeat instance associated with ~cntxt~. The context
  // is the hierarchical location that the heartbeat objections will flow
  // through and be monitored at. The ~objection~ associated with the heartbeat
  // is optional, if it is left null but it must be set before the heartbeat
  // monitor will activate.
  //
  //| uvm_callbacks_objection myobjection = new("myobjection"); //some shared objection
  //| class myenv extends uvm_env;
  //|    uvm_heartbeat hb = new("hb", this, myobjection);
  //|    ...
  //| endclass

  public this(string name, uvm_component cntxt,
	      uvm_callbacks_objection objection = null) {
    synchronized(this) {
      super(name);
      _m_objection = objection;

      //if a cntxt is given it will be used for reporting.
      if(cntxt !is null) _m_cntxt = cntxt;
      else _m_cntxt = uvm_root.get();

      _m_cb = new uvm_heartbeat_callback(name ~ "_cb", _m_cntxt);

      _m_stop_event.init("_m_stop_event");
    }
  }


  // Function: set_mode
  //
  // Sets or retrieves the heartbeat mode. The current value for the heartbeat
  // mode is returned. If an argument is specified to change the mode then the
  // mode is changed to the new value.

  final public uvm_heartbeat_modes set_mode(uvm_heartbeat_modes mode
					    = UVM_NO_HB_MODE) {
    synchronized(this) {
      auto retval = _m_mode;
      if(mode is UVM_ANY_ACTIVE || mode is UVM_ONE_ACTIVE
	 || mode is UVM_ALL_ACTIVE) {
	_m_mode = mode;
      }
      return retval;
    }
  }


  // Function: set_heartbeat
  //
  // Sets up the heartbeat event and assigns a list of objects to watch. The
  // monitoring is started as soon as this method is called. Once the
  // monitoring has been started with a specific event, providing a new
  // monitor event results in an error. To change trigger events, you
  // must first <stop> the monitor and then <start> with a new event trigger.
  //
  // If the trigger event ~e~ is null and there was no previously set
  // trigger event, then the monitoring is not started. Monitoring can be
  // started by explicitly calling <start>.

  final public void set_heartbeat(uvm_event e, // ref
				  Queue!uvm_component comps) {
    synchronized(m_cb) {
      foreach(c; comps) {
	if(c !in m_cb._cnt) {
	  m_cb._cnt[c] = 0;
	}
	if(c !in m_cb._last_trigger) {
	  m_cb._last_trigger[c] = 0;
	}
      }
      if(e is null && m_event is null) return;
      start(e);
    }
  }

  final public void set_heartbeat(uvm_event e,
				  uvm_component[] comps) {
    synchronized(m_cb) {
      foreach(c; comps) {
	if(c !in m_cb._cnt) {
	  m_cb._cnt[c] = 0;
	}
	if(c !in m_cb._last_trigger) {
	  m_cb._last_trigger[c] = 0;
	}
      }
      if(e is null && m_event is null) return;
      start(e);
    }
  }

  // Function: add
  //
  // Add a single component to the set of components to be monitored.
  // This does not cause monitoring to be started. If monitoring is
  // currently active then this component will be immediately added
  // to the list of components and will be expected to participate
  // in the currently active event window.

  final public void add (uvm_component comp) {
    synchronized(m_cb) {
      uvm_object c = comp;
      if(c in m_cb._cnt) return;
      m_cb._cnt[c] = 0;
      m_cb._last_trigger[c] = 0;
    }
  }

  // Function: remove
  //
  // Remove a single component to the set of components being monitored.
  // Monitoring is not stopped, even if the last component has been
  // removed (an explicit stop is required).

  final public void remove (uvm_component comp) {
    synchronized(m_cb) {
      uvm_object c = comp;
      if(c in m_cb._cnt) m_cb._cnt.remove(c);
      if(c in m_cb._last_trigger) m_cb._last_trigger.remove(c);
    }
  }


  // Function: start
  //
  // Starts the heartbeat monitor. If ~e~ is null then whatever event
  // was previously set is used. If no event was previously set then
  // a warning is issued. It is an error if the monitor is currently
  // running and ~e~ is specifying a different trigger event from the
  // current event.

  final public void start (uvm_event e = null) {
    synchronized(this) {
      if(_m_event is null && e is null) {
	_m_cntxt.uvm_report_warning("NOEVNT", "start() was called for: " ~
				    get_name() ~
				    " with a null trigger and no currently"
				    " set trigger",
				    UVM_NONE);
	return;
      }
      if((_m_event !is null) && (e !is _m_event) && _m_started) {
	_m_cntxt.uvm_report_error("ILHBVNT", "start() was called for: " ~
				  get_name() ~ " with trigger " ~
				  e.get_name() ~ " which is different " ~
				  "from the original trigger " ~
				  _m_event.get_name(), UVM_NONE);
	return;
      }
      if(e !is null) _m_event = e;
      m_enable_cb();
      m_start_hb_process();
    }
  }

  // Function: stop
  //
  // Stops the heartbeat monitor. Current state information is reset so
  // that if <start> is called again the process will wait for the first
  // event trigger to start the monitoring.

  final public void stop () {
    synchronized(this) {
      _m_started = 0;
      _m_stop_event.notify();
      m_disable_cb();
    }
  }

  final public void m_start_hb_process() {
    synchronized(this) {
      if(_m_started) return;
      _m_started = 1;
      fork({m_hb_process();});
    }
  }

  protected bool _m_added;

  final public void m_enable_cb() {
    synchronized(this) {
      _m_cb.callback_mode(true);
      if(_m_objection is null) return;
      if(!_m_added) {
	uvm_heartbeat_cbs_t.add(_m_objection, _m_cb);
      }
      _m_added = true;
    }
  }

  final public void m_disable_cb() {
    synchronized(this) {
      m_cb.callback_mode(false);
    }
  }

  // task
  final public void m_hb_process_1() {
    bool  triggered = false;
    SimTime last_trigger = 0;
    // The process waits for the event trigger. The first trigger is
    // ignored, but sets the first start window. On susequent triggers
    // the monitor tests that the mode criteria was full-filled.
    while(true) {
      m_event.wait_trigger();
      synchronized(this, m_cb) {
	if(triggered) {
	  final switch (_m_mode) {
	  case UVM_ALL_ACTIVE:
	    foreach(obj, c; m_cb._cnt) {
	      if(! m_cb._cnt[obj]) {
		_m_cntxt.uvm_report_fatal("HBFAIL",
					  format("Did not recieve an update of"
						 " %s for component %s since"
						 " last event trigger at time"
						 " %0t : last update time was"
						 " %0t",
						 _m_objection.get_name(),
						 obj.get_full_name(),
						 last_trigger,
						 m_cb._last_trigger[obj]),
					  UVM_NONE);
	      }
	    }
	    break;
	  case UVM_ANY_ACTIVE:
	    if(m_cb._cnt.length && !m_cb.objects_triggered()) {
	      string s;
	      foreach(obj, c; m_cb._cnt) {
		s ~= "\n  " ~ obj.get_full_name();
	      }
	      _m_cntxt.uvm_report_fatal("HBFAIL",
					format("Did not recieve an update of"
					       " %s on any component since"
					       " last event trigger at time"
					       " %0t. The list of registered"
					       " components is:%s",
					       _m_objection.get_name(),
					       last_trigger, s),
					UVM_NONE);
	    }
	    break;
	  case UVM_ONE_ACTIVE:
	    if(m_cb.objects_triggered() > 1) {
	      string s;
	      foreach(obj, c; m_cb._cnt)  {
		if(m_cb._cnt[obj]) {
		  s = format("%s\n  %s (updated: %0t)",
			     s, obj.get_full_name(), m_cb._last_trigger[obj]);
		}
	      }
	      _m_cntxt.uvm_report_fatal("HBFAIL",
					format("Recieved update of %s from "
					       "more than one component since"
					       " last event trigger at time"
					       " %0t. The list of triggered"
					       " components is:%s",
					       _m_objection.get_name(),
					       last_trigger, s),
					UVM_NONE);
	    }
	    if(m_cb._cnt.length && !m_cb.objects_triggered()) {
	      string s;
	      foreach(obj, c; m_cb._cnt) {
		s ~= "\n  " ~ obj.get_full_name();
	      }
	      _m_cntxt.uvm_report_fatal("HBFAIL",
					format("Did not recieve an update of"
					       " %s on any component since "
					       "last event trigger at time "
					       "%0t. The list of registered "
					       "components is:%s",
					       _m_objection.get_name(),
					       last_trigger, s),
					UVM_NONE);
	    }
	    break;
	  case UVM_NO_HB_MODE:
	    // FIXME -- SV version does not do anything in this switch case leg
	    assert(false, "Should not reach UVM_NO_HB_MODE");
	  }
	}
	m_cb.reset_counts();
	last_trigger = getSimTime();
	triggered = true;
      }
    }
  }

  // task
  final public void m_hb_process() {
    // uvm_object obj;
    Fork hb_process = fork({
	m_hb_process_1();
      },
      {
	// _m_stop_event is effectively immutable
	wait(_m_stop_event);
      });
    hb_process.joinAny();
    hb_process.abortRec();
  }
}


class uvm_heartbeat_callback: uvm_objection_callback
{
  private int[uvm_object]  _cnt;
  private SimTime[uvm_object] _last_trigger;
  private uvm_object _target;

  public this(string name, uvm_object target) {
    synchronized(this) {
      super(name);
      if (target !is null) {
	_target = target;
      }
      else {
	_target = uvm_root.get();
      }
    }
  }

  override public void raised (uvm_objection objection,
			       uvm_object obj,
			       uvm_object source_obj,
			       string description,
			       int count) {
    synchronized(this) {
      if(obj is _target) {
	if(source_obj !in _cnt) {
	  _cnt[source_obj] = 0;
	}
	_cnt[source_obj] += 1;
	_last_trigger[source_obj] = getSimTime();
      }
    }
  }

  override public void dropped (uvm_objection objection,
				uvm_object obj,
				uvm_object source_obj,
				string description,
				int count) {
    raised(objection, obj, source_obj, description, count);
  }

  final public void reset_counts() {
    synchronized(this) {
      foreach(ref c; _cnt) c = 0;
    }
  }

  final public int objects_triggered() {
    synchronized(this) {
      int retval = 0;
      foreach(c; _cnt) {
	if (c !is 0) {
	  ++retval;
	}
      }
      return retval;
    }
  }

}
