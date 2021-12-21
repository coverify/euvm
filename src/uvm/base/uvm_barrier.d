//
//------------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
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

module uvm.base.uvm_barrier;

//-----------------------------------------------------------------------------
//
// CLASS --NODOCS-- uvm_barrier
//
// The uvm_barrier class provides a multiprocess synchronization mechanism.
// It enables a set of processes to block until the desired number of processes
// get to the synchronization point, at which time all of the processes are
// released.
//-----------------------------------------------------------------------------

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_event: uvm_event;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_object_defines;

import uvm.meta.misc;
import uvm.meta.meta;

import esdl.base.core: wait;

// @uvm-ieee 1800.2-2020 auto 10.3.1
class uvm_barrier: uvm_object
{
  mixin (uvm_sync_string);

  // Guard and encapsulate the state variables
  @uvm_private_sync
  private int  _threshold;
  @uvm_private_sync
  private int  _num_waiters;
  @uvm_private_sync
  private bool _at_threshold;
  @uvm_private_sync
  private bool _auto_reset;

  // m_event is effectively immutable
  @uvm_immutable_sync
  private uvm_event!uvm_object _m_event;

  mixin uvm_object_essentials;

  // Function -- NODOCS -- new
  //
  // Creates a new barrier object.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.1
  this(string name = "", int threshold = 0) {
    synchronized (this) {
      super(name);
      _m_event = new uvm_event!uvm_object("barrier_" ~ name);
      _threshold = threshold;
      _num_waiters = 0;
      _auto_reset = true;
      _at_threshold = false;
    }
  }


  // Task -- NODOCS -- wait_for
  //
  // Waits for enough processes to reach the barrier before continuing.
  //
  // The number of processes to wait for is set by the <set_threshold> method.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.2
  // task
  void wait_for() {
    bool trigger = false;
    synchronized (this) {
      if (_at_threshold)
	return;

      _num_waiters++;

      if (_num_waiters >= _threshold) {
	if (! _auto_reset)
	  _at_threshold = true;
	trigger = true;
      }
    }

    if (trigger) {
      m_trigger();
      return;
    }
    m_event.wait_trigger();
  }


  // Function -- NODOCS -- reset
  //
  // Resets the barrier. This sets the waiter count back to zero.
  //
  // The threshold is unchanged. After reset, the barrier will force processes
  // to wait for the threshold again.
  //
  // If the ~wakeup~ bit is set, any currently waiting processes will
  // be activated.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.3
  void reset(bool wakeup=true) {
    synchronized (this) {
      _at_threshold = false;
      if (_num_waiters) {
	if (wakeup)
	  m_event.trigger();
	else
	  m_event.reset();
      }
      _num_waiters = 0;
    }
  }


  // Function -- NODOCS -- set_auto_reset
  //
  // Determines if the barrier should reset itself after the threshold is
  // reached.
  //
  // The default is on, so when a barrier hits its threshold it will reset, and
  // new processes will block until the threshold is reached again.
  //
  // If auto reset is off, then once the threshold is achieved, new processes
  // pass through without being blocked until the barrier is reset.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.4
  void set_auto_reset(bool value=true) {
    synchronized (this) {
      _at_threshold = false;
      _auto_reset = value;
    }
  }


  // Function -- NODOCS -- set_threshold
  //
  // Sets the process threshold.
  //
  // This determines how many processes must be waiting on the barrier before
  // the processes may proceed.
  //
  // Once the ~threshold~ is reached, all waiting processes are activated.
  //
  // If ~threshold~ is set to a value less than the number of currently
  // waiting processes, then the barrier is reset and waiting processes are
  // activated.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.6
  void set_threshold(int threshold) {
    synchronized (this) {
      _threshold = threshold;
      if (_threshold <= _num_waiters)
	reset(true);
    }
  }


  // Function -- NODOCS -- get_threshold
  //
  // Gets the current threshold setting for the barrier.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.5
  int get_threshold() {
    synchronized (this) {
      return _threshold;
    }
  }


  // Function -- NODOCS -- get_num_waiters
  //
  // Returns the number of processes currently waiting at the barrier.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.7
  int get_num_waiters() {
    synchronized (this) {
      return _num_waiters;
    }
  }


  // Function -- NODOCS -- cancel
  //
  // Decrements the waiter count by one. This is used when a process that is
  // waiting on the barrier is killed or activated by some other means.

  // @uvm-ieee 1800.2-2020 auto 10.3.2.8
  void cancel() {
    synchronized (this) {
      m_event.cancel();
      _num_waiters = m_event.get_num_waiters();
    }
  }


  // task
  private void m_trigger() {
    synchronized (this) {
      m_event.trigger();
      _num_waiters = 0;
    }
    wait(0); // #0 //this process was last to wait; allow other procs to resume first
  }

  override void do_print(uvm_printer printer) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      printer.print("threshold", _threshold, uvm_radix_enum.UVM_DEC, '.',);
      printer.print("num_waiters", _num_waiters, uvm_radix_enum.UVM_DEC, '.');
      printer.print("at_threshold", _at_threshold, uvm_radix_enum.UVM_BIN, '.');
      printer.print("auto_reset", _auto_reset, uvm_radix_enum.UVM_BIN, '.');
    }
  }

  override void do_copy(uvm_object rhs) {
    synchronized (this) {
      super.do_copy(rhs);
      uvm_barrier b = cast (uvm_barrier) rhs;
      if (b is null) return;

      _threshold = b.threshold;
      _num_waiters = b.num_waiters;
      _at_threshold = b.at_threshold;
      _auto_reset = b.auto_reset;
      // FIXME
      // In vlang scheme of things m_event is supposed to be
      // effectively immutable This is the only place m_event could
      // change
    }
  }
}
