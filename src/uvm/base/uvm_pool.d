//
//------------------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2011 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
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
//------------------------------------------------------------------------------

module uvm.base.uvm_pool;


import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_object_defines;

import uvm.base.uvm_scope;

import uvm.meta.meta;
import uvm.meta.misc;

import esdl.rand.misc: rand;

import std.conv: to;

// Title -- NODOCS -- Pool Classes
// This section defines the <uvm_pool #(KEY, VAL)> class and derivative.

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_pool #(KEY,VAL)
//
//------------------------------------------------------------------------------
// Implements a class-based dynamic associative array. Allows sparse arrays to
// be allocated on demand, and passed and stored by reference.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 11.2.1
class uvm_pool(KEY=int, VAL=uvm_void): uvm_object, rand.disable
{

  alias uvm_pool!(KEY,VAL) this_type;

  protected VAL[KEY] _pool;


  mixin uvm_object_essentials;

  // Allow no aliasing, since aliasing leaks out the original assoc
  // array thus putting concurrency in peril
  // For this aliasing
  VAL[KEY] dup_pool() {
    synchronized (this) {
      static if (__traits(compiles, _pool.dup)) {
	return _pool.dup;
      }
      else {
	assert (false, "Cannot copy: " ~ typeof(_pool).stringof);
	// return null;
      }
    }
  }

  // alias dup_pool this;

  // Function -- NODOCS -- new
  //
  // Creates a new pool with the given ~name~.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.1
  this(string name="") {
    synchronized (this) {
      super(name);
    }
  }


  int opApply(int delegate(ref KEY, ref VAL) dg) {
    synchronized (this) {
      int result = 0;
      auto keys = _pool.keys;

      for (size_t i = 0; i != keys.length; ++i) {
	result = dg(keys[i], _pool[keys[i]]);
	if (result) {
	  break;
	}
      }
      return result;
    }
  }

  int opApply(int delegate(ref VAL) dg) {
    synchronized (this) {
      int result = 0;
      auto keys = _pool.keys;

      for (size_t i = 0; i != keys.length; ++i) {
	result = dg(_pool[keys[i]]);
	if (result) {
	  break;
	}
      }
      return result;
    }
  }

  // We delibrately do not return a pointer from opBinaryRight since
  // that pointer can in that case escape the concurrency guards
  bool opBinaryRight(string OP)(KEY key) if (OP == "in") {
    synchronized (this) {
      if (key in _pool) {
	return true;
      }
      else {
	return false;
      }
    }
  }

  void opIndexAssign(VAL val, KEY key) {
    synchronized (this) {
      _pool[key] = val;
    }
  }

  VAL opIndex(KEY key) {
    synchronized (this) {
      return _pool[key];
    }
  }

  // Function -- NODOCS -- get_global_pool
  //
  // Returns the singleton global pool for the item type, VAL.
  //
  // This allows items to be shared amongst components throughout the
  // verification environment.

  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    this_type _m_global_pool;
    this() {
      synchronized (this) {
	_m_global_pool = new this_type("pool");
      }
    }
  }
  mixin (uvm_scope_sync_string);

  // private __gshared this_type[uvm_object] _m_global_pool;

  static this_type get_global_pool() {
    // import uvm.base.uvm_coreservice;
    // synchronized (typeid(this_type)) {
    //   uvm_coreservice_t cs = uvm_coreservice_t.get();
    //   uvm_root top = cs.get_root();
    //   if (top !in _m_global_pool || _m_global_pool[top] is null) {
    // 	_m_global_pool[top] = new this_type("pool");
    //   }
    //   return _m_global_pool[top];
    // }
    return m_global_pool;
  }


  // Function -- NODOCS -- get_global
  //
  // Returns the specified item instance from the global item pool.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.3
  static VAL get_global(KEY key) {
    return m_global_pool.get(key);
  }


  // Function -- NODOCS -- get
  //
  // Returns the item with the given ~key~.
  //
  // If no item exists by that key, a new item is created with that key
  // and returned.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.4
  VAL get(KEY key) {
    synchronized (this) {
      VAL* vptr = key in _pool;
      if (vptr is null) {
	VAL default_value;
	_pool[key] = default_value;
	return default_value;
      }
      else {
	return *vptr;
      }
    }
  }


  // Function -- NODOCS -- add
  //
  // Adds the given (~key~, ~item~) pair to the pool. If an item already
  // exists at the given ~key~ it is overwritten with the new ~item~.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.5
  void add(KEY key, VAL item) {
    synchronized (this) {
      _pool[key] = item;
    }
  }


  // Function -- NODOCS -- num
  //
  // Returns the number of uniquely keyed items stored in the pool.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.6
  size_t num() {
    synchronized (this) {
      return _pool.length;
    }
  }

  alias length = num;

  // Function -- NODOCS -- delete
  //
  // Removes the item with the given ~key~ from the pool.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.7
  void remove(KEY key) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      if (!exists(key)) {
	uvm_report_warning("POOLDEL",
			   "delete: pool key doesn't exist. " ~
			   "Ignoring delete request");
	return;
      }
      _pool.remove(key);
    }
  }

  void remove() {
    synchronized (this) {
      _pool.clear();
    }
  }

  void clear() {
    synchronized (this) {
      _pool.clear();
    }
  }

  // Function -- NODOCS -- exists
  //
  // Returns 1 if a item with the given ~key~ exists in the pool,
  // 0 otherwise.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.8
  bool exists(KEY key) {
    synchronized (this) {
      if (key in _pool) return true;
      else return false;
    }
  }

  // We are not defining the iterative operators for pool. Instead we
  // expose the protected member pool using "this" alias.

  private size_t _index;
  private KEY[]  _keys;

  // Function -- NODOCS -- first
  //
  // Returns the key of the first item stored in the pool.
  //
  // If the pool is empty, then ~key~ is unchanged and 0 is returned.
  //
  // If the pool is not empty, then ~key~ is key of the first item
  // and 1 is returned.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.9
  int first(ref KEY key) {
    import std.algorithm;
    synchronized (this) {
      this._keys = _pool.keys;
      static if (__traits(compiles, KEY.init < KEY.init)) {
	sort(_keys);
      }
      if (_keys.length == 0) {
	return 0;
      }
      else {
	_index = 0;
	key = _keys[_index];
	return 1;
      }
    }
  }


  // Function -- NODOCS -- last
  //
  // Returns the key of the last item stored in the pool.
  //
  // If the pool is empty, then 0 is returned and ~key~ is unchanged.
  //
  // If the pool is not empty, then ~key~ is set to the last key in
  // the pool and 1 is returned.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.10
  int last(ref KEY key) {
    import std.algorithm;
    synchronized (this) {
      this._keys = _pool.keys;
      static if (__traits(compiles, KEY.init < KEY.init)) {
	sort(_keys);
      }
      if (_keys.length == 0) {
	return 0;
      }
      else {
	_index = _keys.length - 1;
	key = _keys[_index];
	return 1;
      }
    }
  }

  // Function -- NODOCS -- next
  //
  // Returns the key of the next item in the pool.
  //
  // If the input ~key~ is the last key in the pool, then ~key~ is
  // left unchanged and 0 is returned.
  //
  // If a next key is found, then ~key~ is updated with that key
  // and 1 is returned.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.11
  int next(ref KEY key) {
    synchronized (this) {
      if (_keys.length == 0 ||
	 _keys.length - 1 <= _index) {
	return 0;
      }
      else {
	++_index;
	key = _keys[_index];
	return 1;
      }
    }
  }


  // Function -- NODOCS -- prev
  //
  // Returns the key of the previous item in the pool.
  //
  // If the input ~key~ is the first key in the pool, then ~key~ is
  // left unchanged and 0 is returned.
  //
  // If a previous key is found, then ~key~ is updated with that key
  // and 1 is returned.

  // @uvm-ieee 1800.2-2020 auto 11.2.2.12
  int prev(ref KEY key) {
    synchronized (this) {
      if (_keys.length == 0 ||
	 _index == 0) {
	return 0;
      }
      else {
	--_index;
	key = _keys[_index];
	return 1;
      }
    }
  }

  override void do_copy(uvm_object rhs) {
    if (rhs is null) {
      return;
    }
    auto p = cast (this_type) rhs;
    if (p is null) {
      return;
    }
    super.do_copy(rhs);
    synchronized (this) {
      _pool = p.dup_pool;
    }
  }

  override void do_print(uvm_printer printer) {
    synchronized (this) {
      size_t cnt;
      printer.print_array_header("pool", _pool.length, "aa_object_string");
      foreach (key, val; _pool) {
	string item = "[-key" ~ cnt.to!string() ~ "--]";
	string v = val.to!string;
	printer.print_generic(item,"",-1,v,'[');
	++cnt;
      }
      printer.print_array_footer();
    }
  }
};

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_object_string_pool #(VAL)
//
//------------------------------------------------------------------------------
// This provides a specialization of the generic <uvm_pool #(KEY,VAL)> class for
// an associative array of <uvm_object>-based objects indexed by string.
// Specializations of this class include the ~uvm_event_pool~ (a
// uvm_object_string_pool storing <uvm_event>s) and
// ~uvm_barrier_pool~ (a uvm_obejct_string_pool storing <uvm_barrier>s).
//------------------------------------------------------------------------------

class uvm_object_string_pool(VAL=uvm_object): uvm_pool!(string,VAL) {

  alias this_type = uvm_object_string_pool!(VAL);


  mixin uvm_object_essentials;

  // Function -- NODOCS -- new
  //
  // Creates a new pool with the given ~name~.

  this(string name = "") {
    synchronized (this) {
      super(name);
    }
  }


  // Function -- NODOCS -- get_global_pool
  //
  // Returns the singleton global pool for the item type, VAL.
  //
  // This allows items to be shared amongst components throughout the
  // verification environment.

  // private __gshared this_type[uvm_object] _m_global_pool;
  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    this_type _m_global_pool;
    this() {
      synchronized (this) {
	_m_global_pool = new this_type("pool");
      }
    }
  }
  mixin (uvm_scope_sync_string);

  static this_type get_global_pool() {
    // import uvm.base.uvm_coreservice;
    // synchronized (typeid(this_type)) {
    //   uvm_coreservice_t cs = uvm_coreservice_t.get();
    //   uvm_root top = cs.get_root();
    //   if (top !in _m_global_pool || _m_global_pool[top] is null) {
    // 	_m_global_pool[top] = new this_type("global_pool");
    //   }
    //   return _m_global_pool[top];
    // }
    return m_global_pool;
  }


  // Function -- NODOCS -- get_global
  //
  // Returns the specified item instance from the global item pool.

  static VAL get_global(string key) {
    return m_global_pool.get(key);
  }


  // Function -- NODOCS -- get
  //
  // Returns the object item at the given string ~key~.
  //
  // If no item exists by the given ~key~, a new item is created for that key
  // and returned.

  override VAL get(string key) {
    synchronized (this) {
      VAL* vptr = key in _pool;
      if (vptr is null) {
	auto val = new VAL(key);
	_pool[key] = val;
	return val;
      }
      else {
	return *vptr;
      }
    }
  }


  // Function -- NODOCS -- remove
  //
  // Removes the item with the given string ~key~ from the pool.

  override void remove(string key) {
    import uvm.base.uvm_globals;
    import std.string: format;
    synchronized (this) {
      if (!exists(key)) {
	uvm_report_warning("POOLDEL",
			   format("delete: key '%s' doesn't exist", key));
	return;
      }
      _pool.remove(key);
    }
  }


  // Function- do_print

  override void do_print(uvm_printer printer) {
    synchronized (this) {
      printer.print_array_header("pool", _pool.length, "aa_object_string");
      foreach (key,val; _pool) {
	printer.print_object("[" ~ key ~ "]", val, '[');
      }
      printer.print_array_footer();
    }
  }
}


// Moved to uvm_aliases
// import uvm.base.uvm_barrier;
// import uvm.base.uvm_event;
// alias uvm_object_string_pool!(uvm_barrier) uvm_barrier_pool;
// alias uvm_object_string_pool!(uvm_event!(uvm_object)) uvm_event_pool;
// alias uvm_queue_string_pool = uvm_object_string_pool!(uvm_queue!string);
// alias uvm_string_object_resource_pool =
//   uvm_pool!(string, uvm_resource!(uvm_object));;

