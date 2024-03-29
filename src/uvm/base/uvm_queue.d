//
//------------------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2017 Intel Corporation
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
// Copyright 2010 Synopsys, Inc.
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


module uvm.base.uvm_queue;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_queue #(T)
//
//------------------------------------------------------------------------------
// Implements a class-based dynamic queue. Allows queues to be allocated on
// demand, and passed and stored by reference.
//------------------------------------------------------------------------------

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_scope;
import uvm.base.uvm_object_defines;

import uvm.meta.misc;

import esdl.data.queue;
import esdl.base.core;

import std.conv;
import std.string: format;


// @uvm-ieee 1800.2-2020 auto 11.3.1
class uvm_queue (T=int): uvm_object
{
  // enum string type_name = "uvm_queue";

  alias this_type = uvm_queue!T;

  // `uvm_object_param_utils(uvm_queue#(T))
  mixin uvm_object_essentials;
  // `uvm_type_name_decl("uvm_queue")

  // No this aliasing -- this aliasing is making the queue object
  // escape from the synchronization guards

  // // For this aliasing
  // ref auto get_queue() {
  //   synchronized (this) {
  //     return _queue;
  //   }
  // }

  // // Some DMD bug is not allowing this alias here
  // alias get_queue this;

  private Queue!T _queue;

  // Function -- NODOCS -- new
  //
  // Creates a new queue with the given ~name~.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.1
  this (string name = "") {
    synchronized (this) {
      super(name);
      _m_size_event.initialize("_m_size_event");
    }
  }


  // m_event is an effectively immutable object
  @uvm_immutable_sync
  private Event      _m_size_event;

  // Function -- NODOCS -- get_global_queue
  //
  // Returns the singleton global queue for the item type, T.
  //
  // This allows items to be shared amongst components throughout the
  // verification environment.

  // __gshared private this_type[uvm_object] _m_global_queue;
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    this_type _m_global_queue;
    this() {
      synchronized (this) {
	_m_global_queue = new this_type("global_queue");
      }
    }
  }

  mixin (uvm_scope_sync_string);

  static this_type get_global_queue () {
    return m_global_queue;
  }

  // Function -- NODOCS -- get_global
  //
  // Returns the specified item instance from the global item queue.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.3
  static T get_global (ptrdiff_t index) {
    return m_global_queue.get(index);
  }

  final T opIndex(size_t index) {
    synchronized (this) {
      return _queue[index];
    }
  }

  T opIndexAssign(T item, size_t index) {
    synchronized (this) {
      _queue[index] = item;
      return item;
    }
  }

  final int opApplyReverse(int delegate(ref size_t,
					       ref const T) dg) const {
    synchronized (this) {
      for (size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if (int r = dg(idx, _queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final int opApplyReverse(int delegate(const ref T) dg) const {
    synchronized (this) {
      for (size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if (int r = dg(_queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final int opApplyReverse(int delegate(ref size_t, ref T) dg) {
    synchronized (this) {
      for (size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if (int r = dg(idx, _queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final int opApplyReverse(int delegate(ref T) dg) {
    synchronized (this) {
      for (size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if (int r = dg(_queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final int opApply(int delegate(ref size_t, ref const T) dg) const {
    synchronized (this) {
      for (size_t idx = 0; idx < _queue.length; ++idx) {
	if (int r = dg(idx, _queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final int opApply(int delegate(ref size_t, ref T) dg) {
    synchronized (this) {
      for (size_t idx = 0; idx < _queue.length; ++idx) {
	if (int r = dg(idx, _queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final int opApply(int delegate(const ref T) dg) const {
    synchronized (this) {
      for (size_t idx = 0; idx < _queue.length; ++idx) {
	if (int r = dg(_queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final int opApply(int delegate(ref T) dg) {
    synchronized (this) {
      for (size_t idx = 0; idx < _queue.length; ++idx) {
	if (int r = dg(_queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  // Function -- NODOCS -- get
  //
  // Returns the item at the given ~index~.
  //
  // If no item exists by that key, a new item is created with that key
  // and returned.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.4
  T get (ptrdiff_t index) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      T default_value;
      if (index >= size() || index < 0) {
	uvm_report_warning("QUEUEGET",
			   format("%s:get: given index out of range for queue of" ~
				  " size %0d. Ignoring get request",
				  this.get_name(), size()));
	return default_value;
      }
      return _queue[index];
    }
  }


  // Function -- NODOCS -- size
  //
  // Returns the number of items stored in the queue.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.5
  size_t length () const {
    synchronized (this) {
      return _queue.length();
    }
  }

  alias size = length;
  // Function -- NODOCS -- insert
  //
  // Inserts the item at the given ~index~ in the queue.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.5
  void insert (ptrdiff_t index, T item) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      if (index >= size() || index < 0) {
	uvm_report_warning("QUEUEINS",
			   format("%s:insert: given index out of range for queue of" ~
				  " size %0d. Ignoring insert request",
				  this.get_name(), size()));
	return;
      }
      _queue.insert(index,item);
      _m_size_event.notify();
    }
  }


  // Function -- NODOCS -- delete
  //
  // Removes the item at the given ~index~ from the queue; if ~index~ is
  // not provided, the entire contents of the queue are deleted.

  // it is named delete in systemverilog version -- but D reserves
  // delete as a keyword

  // @uvm-ieee 1800.2-2020 auto 11.3.2.7
  void remove (ptrdiff_t index=-1) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      if (index != -1 &&
	  (index >= size() || index < -1)) {
	uvm_report_warning("QUEUEDEL",
			   format("%s:remove: given index out of range for queue of" ~
				  " size %0d. Ignoring delete request",
				  this.get_name(), size()));
	return;
      }
      if (index == -1) {
	_queue.clear();
	_m_size_event.notify();
      }
      else {
	_queue.remove(index);
	_m_size_event.notify();
      }
    }
  }


  // Function -- NODOCS -- pop_front
  //
  // Returns the first element in the queue (index=0),
  // or ~null~ if the queue is empty.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.8
  T pop_front() {
    synchronized (this) {
      auto ret = _queue.front();
      _queue.removeFront();
      _m_size_event.notify();
      return ret;
    }
  }

  // Function -- NODOCS -- pop_front
  //
  // Returns the first element in the queue (index=0),
  // or ~null~ if the queue is empty.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.9
  void pop_front(ref T t) {
    synchronized (this) {
      t = _queue.front();
      _queue.removeFront();
      _m_size_event.notify();
    }
  }


  // Function -- NODOCS -- pop_back
  //
  // Returns the last element in the queue (index=size()-1),
  // or ~null~ if the queue is empty.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.9
  T pop_back() {
    synchronized (this) {
      auto ret = _queue.back();
      _queue.removeBack();
      _m_size_event.notify();
      return ret;
    }
  }


  // Function -- NODOCS -- pop_back
  //
  // Returns the last element in the queue (index=size()-1),
  // or ~null~ if the queue is empty.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.9
  void pop_back(ref T t) {
    synchronized (this) {
      t = _queue.back();
      _queue.removeBack();
      _m_size_event.notify();
    }
  }


  // Function -- NODOCS -- push_front
  //
  // Inserts the given ~item~ at the front of the queue.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.10
  void push_front(T item) {
    synchronized (this) {
      _queue.pushFront(item);
      _m_size_event.notify();
    }
  }

  // Function -- NODOCS -- push_back
  //
  // Inserts the given ~item~ at the back of the queue.

  // @uvm-ieee 1800.2-2020 auto 11.3.2.11
  void push_back(T item) {
    synchronized (this) {
      _queue.pushBack(item);
      _m_size_event.notify();
    }
  }

  void opOpAssign(string op, R)(R other)
    if (op == "~" && is (R unused: T)) {
      synchronized (this) {
	this.push_back(other);
      }
    }

  override uvm_object create (string name = "") {
    synchronized (this) {
      this_type v = new this_type (name);
      return v;
    }
  }

  override string get_type_name () {
    synchronized (this) {
      import std.conv: to;
      return typeid(this).to!string();
    }
  }

  // Task -- NODOCS -- wait_until_not_empty
  //
  // Blocks until not empty

  // @uvm-ieee 1800.2-2020 auto 11.3.2.12
  // virtual task
  void wait_until_not_empty() {
    while (_queue.length > 0) {
      _m_size_event.wait();
    }
  }

  override void do_copy (uvm_object rhs) {
    synchronized (this) {
      super.do_copy(rhs);
      this_type p = cast (this_type) rhs;
      if (rhs is null || p is null) {
	return;
      }
      synchronized (p) {
	_queue = p._queue;
      }
    }
  }

  override string convert2string() {
    import std.conv: to;
    return to!string(this);
  }

  string to(S)() if (is (S == string)) {
    import std.conv: to;
    synchronized (this) {
      return std.conv.to!string(_queue.toArray);
    }
  }
}
