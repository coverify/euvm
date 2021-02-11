//
//------------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2011 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2011 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2014 Cisco Systems, Inc.
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
// CLASS -- NODOCS -- uvm_event_base
//
// The uvm_event_base class is an abstract wrapper class around the SystemVerilog event
// construct.  It provides some additional services such as setting callbacks
// and maintaining the number of waiters.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_event_callback: uvm_event_callback;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_misc: uvm_apprepend;
import uvm.base.uvm_callback: uvm_callback, uvm_callbacks,
  uvm_register_cb;

import uvm.meta.misc;
import uvm.meta.meta;

import esdl.data.time;
import esdl.base.core;
import esdl.data.queue;

import std.string: format;

// @uvm-ieee 1800.2-2017 auto 10.1.1.1
abstract class uvm_event_base: uvm_object
{
  mixin (uvm_sync_string);


  mixin uvm_abstract_object_essentials;

  // m_event is an effectively immutable object
  @uvm_immutable_sync
  private Event      _m_event;

  // num_waiters is a private state variable. Make sure that every read/write is guarded
  @uvm_protected_sync
  private int _num_waiters;

  // At some places "on" is getting used inside tasks, hence the synchronization guards
  @uvm_protected_sync
  private bool _on;

  // on_event is an effectively immutable object
  @uvm_immutable_sync
  private Event      _on_event;	// in SV any change in value of on is an event

  // private state variable, make sure that all read-writes are guarded
  @uvm_protected_sync
  private SimTime _trigger_time = 0;


  // Function -- NODOCS -- new
  //
  // Creates a new event object.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.1
  this (string name="") {
    synchronized (this) {
      super(name);
      _m_event.initialize("_m_event");
      _on_event.initialize("_on_event");
    }
  }

  //---------//
  // waiting //
  //---------//

  // Task -- NODOCS -- wait_on
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

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.2
  // task
  void wait_on (bool delta=false) {
    if (delta) {
      if (on) {
	wait(0);		// #0
      }
      return;
    }
    synchronized (this) {
      _num_waiters++;
    }
    // on_event is effectively immutable
    wait(on_event);
  }


  // Task -- NODOCS -- wait_off
  //
  // If the event has already triggered and is "on", this task waits for the
  // event to be turned "off" via a call to <reset>.
  //
  // If the event has not already been triggered, this task returns immediately.
  // If ~delta~ is set, the caller will be forced to wait a single delta #0
  // before returning. This prevents the caller from returning before
  // previously waiting processes have had a chance to resume.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.3
  // task
  void wait_off (bool delta=false) {
    if (delta) {
      if (!on) {
	wait(0);
      }
      return;
    }
    synchronized (this) {
      _num_waiters++;
    }
    wait(on_event);
  }


  // Task -- NODOCS -- wait_trigger
  //
  // Waits for the event to be triggered.
  //
  // If one process calls wait_trigger in the same delta as another process
  // calls <uvm_event#(T)::trigger>, a race condition occurs. If the call to wait occurs
  // before the trigger, this method will return in this delta. If the wait
  // occurs after the trigger, this method will not return until the next
  // trigger, which may never occur and thus cause deadlock.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.4
  // task
  void wait_trigger () {
    synchronized (this) {
      _num_waiters++;
    }
    wait(m_event);
  }


  // Task -- NODOCS -- wait_ptrigger
  //
  // Waits for a persistent trigger of the event. Unlike <wait_trigger>, this
  // views the trigger as persistent within a given time-slice and thus avoids
  // certain race conditions. If this method is called after the trigger but
  // within the same time-slice, the caller returns immediately.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.5
  // task
  void wait_ptrigger () {
    synchronized (this) {
      if (m_event.triggered) {
	return;
      }
      _num_waiters++;
    }
    wait(m_event);
  }

  // Function -- NODOCS -- get_trigger_time
  //
  // Gets the time that this event was last triggered. If the event has not been
  // triggered, or the event has been reset, then the trigger time will be 0.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.6
  SimTime get_trigger_time () {
    synchronized (this) {
      return _trigger_time;
    }
  }

  //-------//
  // state //
  //-------//

  // Function -- NODOCS -- is_on
  //
  // Indicates whether the event has been triggered since it was last reset.
  //
  // A return of 1 indicates that the event has triggered.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.7
  bool is_on () {
    synchronized (this) {
      return _on;
    }
  }

  // Function -- NODOCS -- is_off
  //
  // Indicates whether the event has been triggered or been reset.
  //
  // A return of 1 indicates that the event has not been triggered.

  bool is_off () {
    synchronized (this) {
      return !_on;
    }
  }

  // Function -- NODOCS -- reset
  //
  // Resets the event to its off state. If ~wakeup~ is set, then all processes
  // currently waiting for the event are activated before the reset.
  //
  // No callbacks are called during a reset.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.8
  void reset (bool wakeup = false) {
    synchronized (this) {
      if (wakeup) {
	m_event.notify();
      }
      m_event.reset();
      _num_waiters = 0;
      if (_on !is false) {
	_on = false;
	_on_event.notify();	// value of on has changed
      }
      _trigger_time = 0;
    }
  }


  //--------------//
  // waiters list //
  //--------------//

  // Function -- NODOCS -- cancel
  //
  // Decrements the number of waiters on the event.
  //
  // This is used if a process that is waiting on an event is disabled or
  // activated by some other means.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.9
  void cancel () {
    synchronized (this) {
      if (_num_waiters > 0) {
	--_num_waiters;
      }
    }
  }

  // Function -- NODOCS -- get_num_waiters
  //
  // Returns the number of processes waiting on the event.

  // @uvm-ieee 1800.2-2017 auto 10.1.1.2.10
  int get_num_waiters () {
    synchronized (this) {
      return _num_waiters;
    }
  }

  override void do_print (uvm_printer printer) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      printer.print("num_waiters", _num_waiters, uvm_radix_enum.UVM_DEC, '.', "int");
      printer.print("on", _on, uvm_radix_enum.UVM_BIN, '.', "bit");
      printer.print("trigger_time", _trigger_time);
    }
  }


  override void do_copy (uvm_object rhs) {
    synchronized (this) {
      super.do_copy(rhs);
      auto e = cast (uvm_event_base) rhs;
      if (e is null) {
	return;
      }
      synchronized (e) {
	// m_event = e.m_event;	// crazy??
	_num_waiters  = e.get_num_waiters();
	_on           = e.is_on();
	_trigger_time = e.get_trigger_time();
      }
    }
  }
} //endclass  -- NODOCS -- uvm_event


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_event#(T)
//
// The uvm_event class is an extension of the abstract uvm_event_base class.
//
// The optional parameter ~T~ allows the user to define a data type which
// can be passed during an event trigger.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 10.1.2.1
class uvm_event(T=uvm_object): uvm_event_base
{
  alias this_type = uvm_event!(T);
  alias cb_type = uvm_event_callback!(T);
  alias cbs_type = uvm_callbacks!(this_type, cb_type);
   
  // Not using `uvm_register_cb(this_type, cb_type)
  // so as to try and get ~slightly~ better debug
  // output for names.
  // static private bool m_register_cb() {
  //   return
  //     uvm_callbacks!(this_type,cb_type).m_register_pair("uvm_pkg.uvm_event!(T)",
  // 							"uvm_pkg.uvm_event_callback!(T)"
  // 							);
  // }

  // static local bit m_cb_registered = m_register_cb();

  mixin uvm_register_cb!(cb_type);
   
  mixin uvm_object_essentials;

  mixin (uvm_sync_string);

  enum string type_name = "uvm_event";

  // private state object, make sure that all read-writes are guarded
  @uvm_private_sync
  private T _trigger_data;
  @uvm_private_sync
  private T _default_data;

  // Function -- NODOCS -- new
  //
  // Creates a new event object.

  // @uvm-ieee 1800.2-2017 auto 10.1.2.2.1
  this(string name="") {
    super(name);
  }


  // private state variable, make sure that all read-writes are guarded
  private Queue!(uvm_event_callback!T) _callbacks;

  Queue!(uvm_event_callback!T) get_callbacks() {
    synchronized (this) {
      return _callbacks.dup;
    }
  }

  // Task -- NODOCS -- wait_trigger_data
  //
  // This method calls <wait_trigger> followed by <get_trigger_data>.

  // @uvm-ieee 1800.2-2017 auto 10.1.2.2.2
  // task
  void wait_trigger_data (out T data) {
    wait_trigger();
    synchronized (this) {
      data = get_trigger_data();
    }
  }

  // Task -- NODOCS -- wait_ptrigger_data
  //
  // This method calls <wait_ptrigger> followed by <get_trigger_data>.

  // @uvm-ieee 1800.2-2017 auto 10.1.2.2.3
  // task
  void wait_ptrigger_data (out T data) {
    wait_ptrigger();
    synchronized (this) {
      data = get_trigger_data();
    }
  }


  //------------//
  // triggering //
  //------------//

  // Function -- NODOCS -- trigger
  //
  // Triggers the event, resuming all waiting processes.
  //
  // An optional ~data~ argument can be supplied with the enable to provide
  // trigger-specific information.

  // @uvm-ieee 1800.2-2017 auto 10.1.2.2.4
  void trigger(T data=null) {
    synchronized (this) {
      bool skip = false;
      cb_type[] cb_q;
      foreach (cb; cb_q) {
	skip = skip || cb.pre_trigger(this, data);
      }
      if (skip is false) {
	m_event.notify();
	foreach (cb; cb_q) {
	  cb.post_trigger(this, data);
	}
	_num_waiters = 0;
	if (_on !is true) {
	  _on = true;
	  _on_event.notify();
	}
	_trigger_time = getRootEntity().getSimTime();
	_trigger_data = data;
      }
    }
  }

  // Function -- NODOCS -- get_trigger_data
  //
  // Gets the data, if any, provided by the last call to <trigger>.

  // @uvm-ieee 1800.2-2017 auto 10.1.2.2.5
  T get_trigger_data () {
    synchronized (this) {
      return _trigger_data;
    }
  }

  // Function -- NODOCS -- default data

  // @uvm-ieee 1800.2-2017 auto 10.1.2.2.6
  T get_default_data() {
    synchronized (this) {
      return _default_data;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 10.1.2.2.6
  void set_default_data(T data) {
    synchronized (this) {
      _default_data = data;
    }
  }

}
