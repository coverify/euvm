//
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
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
//------------------------------------------------------------------------------


module uvm.base.uvm_queue;

//------------------------------------------------------------------------------
//
// CLASS: uvm_queue #(T)
//
//------------------------------------------------------------------------------
// Implements a class-based dynamic queue. Allows queues to be allocated on
// demand, and passed and stored by reference.
//------------------------------------------------------------------------------

import uvm.base.uvm_object;

class uvm_queue (T=int): uvm_object
{
  import uvm.base.uvm_globals: uvm_report_warning;
  import std.string: format;
  import esdl.data.queue;
  // enum string type_name = "uvm_queue";

  alias uvm_queue!T this_type;

  // No this aliasing -- this aliasing is making the queue object
  // escape from the synchronization guards

  // // For this aliasing
  // @property public ref auto get_queue() {
  //   synchronized(this) {
  //     return _queue;
  //   }
  // }

  // // Some DMD bug is not allowing this alias here
  // alias get_queue this;

  __gshared private this_type[uvm_object] _m_global_queue;
  protected Queue!T _queue;

  // Function: new
  //
  // Creates a new queue with the given ~name~.

  this (string name = "") {
    super(name);
  }


  // Function: get_global_queue
  //
  // Returns the singleton global queue for the item type, T.
  //
  // This allows items to be shared amongst components throughout the
  // verification environment.

  static this_type get_global_queue () {
    synchronized(typeid(this_type)) {
      import uvm.base.uvm_root;
      auto top = uvm_top;
      if(top !in _m_global_queue) {
	_m_global_queue[top] = new this_type("global_queue");
      }
      return _m_global_queue[top];
    }
  }

  // Function: get_global
  //
  // Returns the specified item instance from the global item queue.

  static T get_global (long index) {
    synchronized(typeid(this_type)) {
      this_type gqueue;
      gqueue = get_global_queue();
      return gqueue.get(index);
    }
  }

  final public T opIndex(size_t index) {
    synchronized(this) {
      return _queue[index];
    }
  }

  public T opIndexAssign(T item, size_t index) {
    synchronized(this) {
      _queue[index] = item;
      return item;
    }
  }

  final public int opApplyReverse(int delegate(ref size_t,
					       ref const T) dg) const {
    synchronized(this) {
      for(size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if(int r = dg(idx, this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final public int opApplyReverse(int delegate(const ref T) dg) const {
    synchronized(this) {
      for(size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if(int r = dg(this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final public int opApplyReverse(int delegate(ref size_t, ref T) dg) {
    synchronized(this) {
      for(size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if(int r = dg(idx, this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final public int opApplyReverse(int delegate(ref T) dg) {
    synchronized(this) {
      for(size_t idx = _queue.length-1; idx != size_t.max; --idx) {
	if(int r = dg(this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final public int opApply(int delegate(ref size_t, ref const T) dg) const {
    synchronized(this) {
      for(size_t idx = 0; idx < _queue.length; ++idx) {
	if(int r = dg(idx, this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final public int opApply(int delegate(ref size_t, ref T) dg) {
    synchronized(this) {
      for(size_t idx = 0; idx < _queue.length; ++idx) {
	if(int r = dg(idx, this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final public int opApply(int delegate(const ref T) dg) const {
    synchronized(this) {
      for(size_t idx = 0; idx < _queue.length; ++idx) {
	if(int r = dg(this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  final public int opApply(int delegate(ref T) dg) {
    synchronized(this) {
      for(size_t idx = 0; idx < _queue.length; ++idx) {
	if(int r = dg(this._queue[idx])) {
	  return r;
	}
      }
      return 0;
    }
  }

  // Function: get
  //
  // Returns the item at the given ~index~.
  //
  // If no item exists by that key, a new item is created with that key
  // and returned.

  public T get (long index) {
    synchronized(this) {
      T default_value;
      if (index >= size() || index < 0) {
	uvm_report_warning("QUEUEGET",
			   format("get: given index out of range for queue of"
				  " size %0d. Ignoring get request", size()));
	return default_value;
      }
      return _queue[index];
    }
  }


  // Function: size
  //
  // Returns the number of items stored in the queue.

  public size_t length () const {
    synchronized(this) {
      return _queue.length();
    }
  }

  alias length size;
  // Function: insert
  //
  // Inserts the item at the given ~index~ in the queue.

  public void insert (long index, T item) {
    synchronized(this) {
      if (index >= size() || index < 0) {
	import uvm.base.uvm_message_defines;
	uvm_report_warning("QUEUEINS",
			   format("insert: given index out of range for queue of"
				  " size %0d. Ignoring insert request", size()));
	return;
      }
      _queue.insert(index,item);
    }
  }


  // Function: delete
  //
  // Removes the item at the given ~index~ from the queue; if ~index~ is
  // not provided, the entire contents of the queue are deleted.

  // it is named delete in systemverilog version -- but D reserves
  // delete as a keyword
  public void remove (long index=-1) {
    synchronized(this) {
      if (index >= size() || index < -1) {
	uvm_report_warning("QUEUEDEL",
			   format("remove: given index out of range for queue of"
				  " size %0d. Ignoring delete request", size()));
	return;
      }
      if (index is -1)
	_queue.clear();
      else
	_queue.remove(index);
    }
  }


  // Function: pop_front
  //
  // Returns the first element in the queue (index=0),
  // or ~null~ if the queue is empty.

  public T pop_front() {
    synchronized(this) {
      auto ret = _queue.front();
      _queue.removeFront();
      return ret;
    }
  }

  // Function: pop_front
  //
  // Returns the first element in the queue (index=0),
  // or ~null~ if the queue is empty.

  public void pop_front(ref T t) {
    synchronized(this) {
      t = _queue.front();
      _queue.removeFront();
    }
  }


  // Function: pop_back
  //
  // Returns the last element in the queue (index=size()-1),
  // or ~null~ if the queue is empty.

  public T pop_back() {
    synchronized(this) {
      auto ret = _queue.back();
      _queue.removeBack();
      return ret;
    }
  }


  // Function: pop_back
  //
  // Returns the last element in the queue (index=size()-1),
  // or ~null~ if the queue is empty.

  public void pop_back(ref T t) {
    synchronized(this) {
      t = _queue.back();
      _queue.removeBack();
    }
  }


  // Function: push_front
  //
  // Inserts the given ~item~ at the front of the queue.

  public void push_front(T item) {
    synchronized(this) {
      _queue.pushFront(item);
    }
  }

  // Function: push_back
  //
  // Inserts the given ~item~ at the back of the queue.

  public void push_back(T item) {
    synchronized(this) {
      _queue.pushBack(item);
    }
  }

  public void opOpAssign(string op, R)(R other)
    if(op == "~" && is(R unused: T)) {
      synchronized(this) {
	this.pushBack(other);
      }
    }

  override public uvm_object create (string name = "") {
    synchronized(this) {
      this_type v = new this_type (name);
      return v;
    }
  }

  override public string get_type_name () {
    synchronized(this) {
      import std.conv: to;
      return to!string(typeid(this));
    }
  }

  override public void do_copy (uvm_object rhs) {
    synchronized(this) {
      super.do_copy(rhs);
      this_type p = cast(this_type) rhs;
      if (rhs is null || p is null) {
	return;
      }
      _queue = p._queue;
    }
  }

  override public string convert2string() {
    import std.conv: to;
    return to!string(this);
  }

  public string to(S)() if(is(S == string)) {
    synchronized(this) {
      import std.conv: to;
      return std.conv.to!string(this._queue.toArray);
    }
  }
}
