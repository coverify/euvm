//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013-2015 NVIDIA Corporation
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

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_callback: uvm_callbacks;
import uvm.base.uvm_event: uvm_event;
import uvm.base.uvm_objection: uvm_objection, uvm_objection_callback;

import esdl.base.core;
import esdl.data.time;
import esdl.data.queue;

import uvm.meta.misc;

enum uvm_heartbeat_modes
  {    UVM_ALL_ACTIVE,
       UVM_ONE_ACTIVE,
       UVM_ANY_ACTIVE,
       UVM_NO_HB_MODE
  }


// @uvm-ieee 1800.2-2017 auto D.4.2
alias uvm_heartbeat_cbs_t =
  uvm_callbacks!(uvm_objection, uvm_heartbeat_callback);


//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_heartbeat
//
//------------------------------------------------------------------------------
// Heartbeats provide a way for environments to easily ensure that their
// descendants are alive. A uvm_heartbeat is associated with a specific
// objection object. A component that is being tracked by the heartbeat
// object must raise (or drop) the synchronizing objection during
// the heartbeat window.
//
// The uvm_heartbeat object has a list of participating objects. The heartbeat
// can be configured so that all components (UVM_ALL_ACTIVE), exactly one
// (UVM_ONE_ACTIVE), or any component (UVM_ANY_ACTIVE) must trigger the
// objection in order to satisfy the heartbeat condition.
//------------------------------------------------------------------------------

// typedef class uvm_objection_callback;

// @uvm-ieee 1800.2-2017 auto 10.6.1
class uvm_heartbeat: uvm_object
{
  import uvm.base.uvm_component: uvm_component;
  mixin (uvm_sync_string);

  @uvm_protected_sync
  private uvm_objection _m_objection;

  @uvm_immutable_sync
  private uvm_heartbeat_callback _m_cb;

  @uvm_protected_sync
  private uvm_component   _m_cntxt;
  @uvm_protected_sync
  private uvm_heartbeat_modes   _m_mode;
  // protected Queue!uvm_component   _m_hblist; // FIXME -- variable not used anywhere
  @uvm_private_sync
  private uvm_event!(uvm_object)  _m_event;

  @uvm_private_sync
  private bool             _m_started;
  @uvm_immutable_sync
  private Event           _m_stop_event;

  // Function -- NODOCS -- new
  //
  // Creates a new heartbeat instance associated with ~cntxt~. The context
  // is the hierarchical location that the heartbeat objections will flow
  // through and be monitored at. The ~objection~ associated with the heartbeat
  // is optional, if it is left ~null~ but it must be set before the heartbeat
  // monitor will activate.
  //
  //| uvm_callbacks myobjection = new("myobjection"); //some shared objection
  //| class myenv extends uvm_env;
  //|    uvm_heartbeat hb = new("hb", this, myobjection);
  //|    ...
  //| endclass

  // @uvm-ieee 1800.2-2017 auto 10.6.2.1
  this(string name, uvm_component cntxt, uvm_objection objection = null) {
    import uvm.base.uvm_coreservice;
    synchronized (this) {
      super(name);
      _m_objection = objection;

      uvm_coreservice_t cs = uvm_coreservice_t.get();
      //if a cntxt is given it will be used for reporting.
      if (cntxt !is null) _m_cntxt = cntxt;
      else _m_cntxt = cs.get_root();

      _m_cb = new uvm_heartbeat_callback(name ~ "_cb", _m_cntxt);

      _m_stop_event.initialize("_m_stop_event");
    }
  }


  // Function -- NODOCS -- set_mode
  //
  // Sets or retrieves the heartbeat mode. The current value for the heartbeat
  // mode is returned. If an argument is specified to change the mode then the
  // mode is changed to the new value.

  // @uvm-ieee 1800.2-2017 auto 10.6.2.2
  final uvm_heartbeat_modes set_mode(uvm_heartbeat_modes mode
				     = uvm_heartbeat_modes.UVM_NO_HB_MODE) {
    synchronized (this) {
      auto set_mode_ = _m_mode;
      if (mode == uvm_heartbeat_modes.UVM_ANY_ACTIVE ||
	 mode == uvm_heartbeat_modes.UVM_ONE_ACTIVE ||
	 mode == uvm_heartbeat_modes.UVM_ALL_ACTIVE) {
	_m_mode = mode;
      }
      return set_mode_;
    }
  }


  // Function -- NODOCS -- set_heartbeat
  //
  // Sets up the heartbeat event and assigns a list of objects to watch. The
  // monitoring is started as soon as this method is called. Once the
  // monitoring has been started with a specific event, providing a new
  // monitor event results in an error. To change trigger events, you
  // must first <stop> the monitor and then <start> with a new event trigger.
  //
  // If the trigger event ~e~ is ~null~ and there was no previously set
  // trigger event, then the monitoring is not started. Monitoring can be
  // started by explicitly calling <start>.

  // @uvm-ieee 1800.2-2017 auto 10.6.2.3
  final void set_heartbeat(uvm_event!uvm_object e, // ref
			   Queue!uvm_component comps) {
    synchronized (m_cb) {
      foreach (c; comps) {
	if (c !in m_cb._cnt) {
	  m_cb._cnt[c] = 0;
	}
	if (c !in m_cb._last_trigger) {
	  m_cb._last_trigger[c] = 0;
	}
      }
      if (e is null && m_event is null) {
	return;
      }
      start(e);
    }
  }

  final void set_heartbeat(uvm_event!uvm_object e,
			   uvm_component[] comps) {
    synchronized (m_cb) {
      foreach (c; comps) {
	if (c !in m_cb._cnt) {
	  m_cb._cnt[c] = 0;
	}
	if (c !in m_cb._last_trigger) {
	  m_cb._last_trigger[c] = 0;
	}
      }
      if (e is null && m_event is null) {
	return;
      }
      start(e);
    }
  }

  // Function -- NODOCS -- add
  //
  // Add a single component to the set of components to be monitored.
  // This does not cause monitoring to be started. If monitoring is
  // currently active then this component will be immediately added
  // to the list of components and will be expected to participate
  // in the currently active event window.

  // @uvm-ieee 1800.2-2017 auto 10.6.2.4
  final void add (uvm_component comp) {
    synchronized (m_cb) {
      uvm_object c = comp;
      if (c in m_cb._cnt) {
	return;
      }
      m_cb._cnt[c] = 0;
      m_cb._last_trigger[c] = 0;
    }
  }

  // Function -- NODOCS -- remove
  //
  // Remove a single component to the set of components being monitored.
  // Monitoring is not stopped, even if the last component has been
  // removed (an explicit stop is required).

  // @uvm-ieee 1800.2-2017 auto 10.6.2.5
  final void remove (uvm_component comp) {
    synchronized (m_cb) {
      uvm_object c = comp;
      if (c in m_cb._cnt) m_cb._cnt.remove(c);
      if (c in m_cb._last_trigger) m_cb._last_trigger.remove(c);
    }
  }


  // Function -- NODOCS -- start
  //
  // Starts the heartbeat monitor. If ~e~ is ~null~ then whatever event
  // was previously set is used. If no event was previously set then
  // a warning is issued. It is an error if the monitor is currently
  // running and ~e~ is specifying a different trigger event from the
  // current event.

  // @uvm-ieee 1800.2-2017 auto 10.6.2.6
  final void start (uvm_event!uvm_object e = null) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      if (_m_event is null && e is null) {
	_m_cntxt.uvm_report_warning("NOEVNT", "start() was called for: " ~
				    get_name() ~ " with a null trigger " ~
				    "and no currently set trigger",
				    uvm_verbosity.UVM_NONE);
	return;
      }
      if ((_m_event !is null) && (e !is _m_event) && _m_started) {
	_m_cntxt.uvm_report_error("ILHBVNT", "start() was called for: " ~
				  get_name() ~ " with trigger " ~
				  e.get_name() ~ " which is different " ~
				  "from the original trigger " ~
				  _m_event.get_name(), uvm_verbosity.UVM_NONE);
	return;
      }
      if (e !is null) {
	_m_event = e;
      }
      m_enable_cb();
      m_start_hb_process();
    }
  }

  // Function -- NODOCS -- stop
  //
  // Stops the heartbeat monitor. Current state information is reset so
  // that if <start> is called again the process will wait for the first
  // event trigger to start the monitoring.

  // @uvm-ieee 1800.2-2017 auto 10.6.2.7
  final void stop () {
    synchronized (this) {
      _m_started = 0;
      _m_stop_event.notify();
      m_disable_cb();
    }
  }

  final void m_start_hb_process() {
    synchronized (this) {
      if (_m_started) {
	return;
      }
      _m_started = 1;
      fork!("uvm_heartbeat/start_hb_process")({m_hb_process();});
    }
  }

  @uvm_protected_sync
  protected bool _m_added;

  final void m_enable_cb() {
    synchronized (this) {
      _m_cb.callback_mode(true);
      if (_m_objection is null) {
	return;
      }
      if (!_m_added) {
	uvm_heartbeat_cbs_t.add(_m_objection, _m_cb);
      }
      _m_added = true;
    }
  }

  final void m_disable_cb() {
    synchronized (this) {
      m_cb.callback_mode(false);
    }
  }

  // task
  final void m_hb_process_1() {
    import uvm.base.uvm_object_globals;
    import std.string: format;
    bool  triggered = false;
    SimTime last_trigger = 0;
    // The process waits for the event trigger. The first trigger is
    // ignored, but sets the first start window. On susequent triggers
    // the monitor tests that the mode criteria was full-filled.
    while (true) {
      m_event.wait_trigger();
      synchronized (this) {
	if (triggered) {
	  final switch (_m_mode) {
	  case uvm_heartbeat_modes.UVM_ALL_ACTIVE:
	    foreach (obj, c; m_cb.get_counts()) {
	      if (! c) {
		_m_cntxt.uvm_report_fatal("HBFAIL",
					  format("Did not recieve an update of" ~
						 " %s for component %s since" ~
						 " last event trigger at time" ~
						 " %s : last update time was" ~
						 " %s", _m_objection.get_name(),
						 obj.get_full_name(),
						 last_trigger,
						 m_cb.get_last_trigger(obj)),
					  uvm_verbosity.UVM_NONE);
	      }
	    }
	    break;
	  case uvm_heartbeat_modes.UVM_ANY_ACTIVE:
	    if (m_cb.num_counts() && !m_cb.objects_triggered()) {
	      string s;
	      foreach (obj, c; m_cb.get_counts()) {
		s ~= "\n  " ~ obj.get_full_name();
	      }
	      _m_cntxt.uvm_report_fatal("HBFAIL",
					format("Did not recieve an update of" ~
					       " %s on any component since" ~
					       " last event trigger at time" ~
					       " %s. The list of registered" ~
					       " components is:%s",
					       _m_objection.get_name(),
					       last_trigger, s),
					uvm_verbosity.UVM_NONE);
	    }
	    break;
	  case uvm_heartbeat_modes.UVM_ONE_ACTIVE:
	    if (m_cb.objects_triggered() > 1) {
	      string s;
	      foreach (obj, c; m_cb.get_counts())  {
		if (c) {
		  s ~= format("\n  %s (updated: %s)",
			      obj.get_full_name(), m_cb.get_last_trigger(obj));
		}
	      }
	      _m_cntxt.uvm_report_fatal("HBFAIL",
					format("Recieved update of %s from " ~
					       "more than one component since" ~
					       " last event trigger at time" ~
					       " %s. The list of triggered" ~
					       " components is:%s",
					       _m_objection.get_name(),
					       last_trigger, s),
					uvm_verbosity.UVM_NONE);
	    }
	    if (m_cb.num_counts && !m_cb.objects_triggered()) {
	      string s;
	      foreach (obj, c; m_cb.get_counts()) {
		s ~= "\n  " ~ obj.get_full_name();
	      }
	      _m_cntxt.uvm_report_fatal("HBFAIL",
					format("Did not recieve an update of" ~
					       " %s on any component since " ~
					       "last event trigger at time " ~
					       "%s. The list of registered " ~
					       "components is:%s",
					       _m_objection.get_name(),
					       last_trigger, s),
					uvm_verbosity.UVM_NONE);
	    }
	    break;
	  case uvm_heartbeat_modes.UVM_NO_HB_MODE:
	    // FIXME -- SV version does not do anything in this switch case leg
	    assert (false, "Should not reach UVM_NO_HB_MODE");
	  }
	}
	m_cb.reset_counts();
	last_trigger = getRootEntity().getSimTime();
	triggered = true;
      }
    }
  }

  // task
  final void m_hb_process() {
    // uvm_object obj;
    Fork hb_process = fork!("uvm_heartbeat/hb_process")({
	m_hb_process_1();
      },
      {
	// _m_stop_event is effectively immutable
	wait(m_stop_event);
      });
    hb_process.joinAny();
    hb_process.abortTree();
  }
}


class uvm_heartbeat_callback: uvm_objection_callback
{
  private int[uvm_object]  _cnt;
  private SimTime[uvm_object] _last_trigger;
  private uvm_object _target;

  this(string name, uvm_object target) {
    import uvm.base.uvm_coreservice;
    synchronized (this) {
      super(name);
      if (target !is null) {
	_target = target;
      }
      else {
	uvm_coreservice_t cs = uvm_coreservice_t.get();
	_target = cs.get_root();
      }
    }
  }

  override void raised (uvm_objection objection,
			uvm_object obj,
			uvm_object source_obj,
			string description,
			int count) {
    synchronized (this) {
      if (obj is _target) {
	if (source_obj !in _cnt) {
	  _cnt[source_obj] = 0;
	}
	_cnt[source_obj] += 1;
	_last_trigger[source_obj] = getRootEntity().getSimTime();
      }
    }
  }

  override void dropped (uvm_objection objection,
			 uvm_object obj,
			 uvm_object source_obj,
			 string description,
			 int count) {
    raised(objection, obj, source_obj, description, count);
  }

  SimTime get_last_trigger(uvm_object obj) {
    synchronized (this) {
      return _last_trigger[obj];
    }
  }

  size_t num_counts() {
    synchronized (this) {
      return _cnt.length;
    }
  }
  
  int[uvm_object] get_counts() {
    synchronized (this) {
      return _cnt.dup;
    }
  }

  final void reset_counts() {
    synchronized (this) {
      foreach (ref c; _cnt) {
	c = 0;
      }
    }
  }

  final int objects_triggered() {
    synchronized (this) {
      int objects_triggered_ = 0;
      foreach (c; _cnt) {
	if (c != 0) {
	  ++objects_triggered_;
	}
      }
      return objects_triggered_;
    }
  }

}
