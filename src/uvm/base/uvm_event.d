//
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
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

module uvm.base.uvm_event;

//------------------------------------------------------------------------------
//
// CLASS: uvm_event
//
// The uvm_event class is a wrapper class around the SystemVerilog event
// construct.  It provides some additional services such as setting callbacks
// and maintaining the number of waiters.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_object;
import uvm.base.uvm_event_callback;
import uvm.base.uvm_printer;
import uvm.base.uvm_globals;
import uvm.base.uvm_misc;
import uvm.base.uvm_object_globals;
import uvm.meta.misc;

import esdl.base.time;
import esdl.base.core;
import esdl.data.queue;

import std.string: format;

class uvm_event : /*extends*/ uvm_object
{
  mixin(uvm_sync!(uvm_event));

  enum string type_name = "uvm_event";

  // m_event is an effectively immutable object
  private Event      _m_event;

  // num_waiters is a private state variable. Make sure that every read/write is guarded
  @uvm_private_sync private int _num_waiters;

  // At some places "on" is getting used inside tasks, hence the synchronization guards
  @uvm_private_sync private bool _on;

  // on_event is an effectively immutable object
  private Event      _on_event;	// in SV any change in value of on is an event

  // private state variable, make sure that all read-writes are guarded
  @uvm_private_sync private SimTime _trigger_time = 0;

  // private state object, make sure that all read-writes are guarded
  @uvm_private_sync private uvm_object _trigger_data;

  // private state variable, make sure that all read-writes are guarded
  @uvm_private_sync private Queue!uvm_event_callback _callbacks;

  // Function: new
  //
  // Creates a new event object.

  public this (string name="") {
    synchronized(this) {
      super(name);
      _m_event.init();
      _on_event.init();
    }
  }

  //---------//
  // waiting //
  //---------//

  // Task: wait_on
  //
  // Waits for the event to be activated for the first time.
  //
  // If the event has already been triggered, this task returns immediately.
  // If ~delta~ is set, the caller will be forced to wait a single delta #0
  // before returning. This prevents the caller from returning before
  // previously waiting processes have had a chance to resume.
  //
  // Once an event has been triggered, it will be remain "on" until the event
  // is <reset>.

  // task
  public void wait_on (bool delta=false) {
    if (delta) {
      if (on) {
	wait(0);		// #0
      }
      return;
    }
    synchronized(this) {
      _num_waiters++;
    }
    // on_event is effectively immutable
    wait(_on_event);
  }


  // Task: wait_off
  //
  // If the event has already triggered and is "on", this task waits for the
  // event to be turned "off" via a call to <reset>.
  //
  // If the event has not already been triggered, this task returns immediately.
  // If ~delta~ is set, the caller will be forced to wait a single delta #0
  // before returning. This prevents the caller from returning before
  // previously waiting processes have had a chance to resume.

  // task
  public void wait_off (bool delta=false) {
    if (delta) {
      if (!on) {
	wait(0);
      }
      return;
    }
    synchronized(this) {
      _num_waiters++;
    }
    wait(_on_event);
  }


  // Task: wait_trigger
  //
  // Waits for the event to be triggered.
  //
  // If one process calls wait_trigger in the same delta as another process
  // calls <trigger>, a race condition occurs. If the call to wait occurs
  // before the trigger, this method will return in this delta. If the wait
  // occurs after the trigger, this method will not return until the next
  // trigger, which may never occur and thus cause deadlock.

  // task
  public void wait_trigger () {
    synchronized(this) {
      _num_waiters++;
    }
    wait(_m_event);
  }


  // Task: wait_ptrigger
  //
  // Waits for a persistent trigger of the event. Unlike <wait_trigger>, this
  // views the trigger as persistent within a given time-slice and thus avoids
  // certain race conditions. If this method is called after the trigger but
  // within the same time-slice, the caller returns immediately.

  // task
  public void wait_ptrigger () {
    synchronized(this) {
      if (_m_event.triggered) {
	return;
      }
      _num_waiters++;
    }
    wait(_m_event);
  }

  // Task: wait_trigger_data
  //
  // This method calls <wait_trigger> followed by <get_trigger_data>.

  // task
  public void wait_trigger_data (out uvm_object data) {
    wait_trigger();
    synchronized(this) {
      data = get_trigger_data();
    }
  }

  // Task: wait_ptrigger_data
  //
  // This method calls <wait_ptrigger> followed by <get_trigger_data>.

  // task
  public void wait_ptrigger_data (out uvm_object data) {
    wait_ptrigger();
    synchronized(this) {
      data = get_trigger_data();
    }
  }


  //------------//
  // triggering //
  //------------//

  // Function: trigger
  //
  // Triggers the event, resuming all waiting processes.
  //
  // An optional ~data~ argument can be supplied with the enable to provide
  // trigger-specific information.

  public void trigger (uvm_object data=null) {
    bool skip = false;
    synchronized(this) {
      if (_callbacks.length !is 0) {
	foreach (cb; _callbacks[]) {
	  skip = skip || cb.pre_trigger(this,data);
	}
      }
      if (skip is false) {
	_m_event.notify();
	if (_callbacks.length !is 0) {
	  foreach (tmp; _callbacks[]) {
	    tmp.post_trigger(this,data);
	  }
	}
	_num_waiters = 0;
	if(_on !is true) {
	  _on = true;
	  _on_event.notify();
	}
	_trigger_time = getSimTime();
	_trigger_data = data;
      }
    }
  }

  // Function: get_trigger_data
  //
  // Gets the data, if any, provided by the last call to <trigger>.

  public uvm_object get_trigger_data () {
    synchronized(this) {
      return _trigger_data;
    }
  }

  // Function: get_trigger_time
  //
  // Gets the time that this event was last triggered. If the event has not been
  // triggered, or the event has been reset, then the trigger time will be 0.

  public SimTime get_trigger_time () {
    synchronized(this) {
      return _trigger_time;
    }
  }

  //-------//
  // state //
  //-------//

  // Function: is_on
  //
  // Indicates whether the event has been triggered since it was last reset.
  //
  // A return of 1 indicates that the event has triggered.

  public bool is_on () {
    synchronized(this) {
      return _on;
    }
  }

  // Function: is_off
  //
  // Indicates whether the event has been triggered or been reset.
  //
  // A return of 1 indicates that the event has not been triggered.

  public bool is_off () {
    synchronized(this) {
      return !_on;
    }
  }

  // Function: reset
  //
  // Resets the event to its off state. If ~wakeup~ is set, then all processes
  // currently waiting for the event are activated before the reset.
  //
  // No callbacks are called during a reset.

  public void reset (bool wakeup = false) {
    synchronized(this) {
      if (wakeup) {
	_m_event.notify();
      }
      _m_event.reset();
      _num_waiters = 0;
      if(_on !is false) {
	_on = false;
	_on_event.notify();	// value of on has changed
      }
      _trigger_time = 0;
      _trigger_data = null;
    }
  }

  //-----------//
  // callbacks //
  //-----------//

  // Function: add_callback
  //
  // Registers a callback object, ~cb~, with this event. The callback object
  // may include pre_trigger and post_trigger functionality. If ~append~ is set
  // to 1, the default, ~cb~ is added to the back of the callback list. Otherwise,
  // ~cb~ is placed at the front of the callback list.

  public void add_callback (uvm_event_callback cb, bool append = true) {
    synchronized(this) {
      import std.algorithm;
      if(countUntil(_callbacks[], cb) !is -1) {
	uvm_report_warning("CBRGED","add_callback: Callback already registered. Ignoring.", UVM_NONE);
	return;
      }
      if (append) {
	_callbacks.pushBack(cb);
      }
      else {
	_callbacks.pushFront(cb);
      }
    }
  }

  // Function: delete_callback
  //
  // Unregisters the given callback, ~cb~, from this event.

  public void delete_callback (uvm_event_callback cb) {
    synchronized(this) {
      import std.algorithm;
      auto r = countUntil(_callbacks[], cb);
      if(r !is -1) {
	_callbacks.remove(r);
      }
      else {
	uvm_report_warning("CBNTFD", "delete_callback: Callback not found. Ignoring delete request.", UVM_NONE);
      }
    }
  }

  //--------------//
  // waiters list //
  //--------------//

  // Function: cancel
  //
  // Decrements the number of waiters on the event.
  //
  // This is used if a process that is waiting on an event is disabled or
  // activated by some other means.

  public void cancel () {
    synchronized(this) {
      if (_num_waiters > 0)
	--_num_waiters;
    }
  }

  // Function: get_num_waiters
  //
  // Returns the number of processes waiting on the event.

  public int get_num_waiters () {
    synchronized(this) {
      return _num_waiters;
    }
  }

  public static uvm_object create(string name="") {
    uvm_event v = new uvm_event(name);
    return v;
  }

  public override string get_type_name() {
    return "uvm_event";
  }

  public override void do_print (uvm_printer printer) {
    synchronized(this) {
      printer.print_int("num_waiters", _num_waiters, UVM_DEC, '.', "int");
      printer.print_int("on", _on, UVM_BIN, '.', "bit");
      printer.print_time("trigger_time", _trigger_time);
      printer.print_object("trigger_data", _trigger_data);
      printer.m_scope.down("callbacks");
      foreach(size_t e, ref c; _callbacks) {
	printer.print_object(format("[%0d]",e), c, '[');
      }
      printer.m_scope.up();
    }
  }


  public override void do_copy (uvm_object rhs) {
    synchronized(this) {
      uvm_event e;
      super.do_copy(rhs);
      e = cast(uvm_event) rhs;
      if (e is null) return;

      // _m_event = e._m_event;	// crazy??
      _num_waiters = e.num_waiters;
      _on = e.on;
      _trigger_time = e.trigger_time;
      _trigger_data = e.trigger_data;
      // callbacks = [];
      _callbacks = e.callbacks;
    }
  }
} //endclass : uvm_event
