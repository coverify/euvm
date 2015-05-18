//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
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

module uvm.base.uvm_pool;

// Title: Pool Classes
// This section defines the <uvm_pool #(KEY, VAL)> class and derivative.

//------------------------------------------------------------------------------
//
// CLASS: uvm_pool #(KEY,VAL)
//
//------------------------------------------------------------------------------
// Implements a class-based dynamic associative array. Allows sparse arrays to
// be allocated on demand, and passed and stored by reference.
//------------------------------------------------------------------------------

import uvm.base.uvm_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_printer;
import uvm.base.uvm_root;
import std.conv: to;
import uvm.meta.meta;

class uvm_pool (KEY=int, VAL=uvm_void): /*extends*/ uvm_object
{

  import std.string: format;

  alias uvm_pool!(KEY,VAL) this_type;

  private __gshared this_type[uvm_object] _m_global_pool;

  protected VAL[KEY] _pool;


  // Allow no aliasing, since aliasing leaks out the original assoc
  // array thus putting concurrency in peril
  // For this aliasing
  // @property public ref auto get_pool() {
  //   synchronized(this) {
  //     return _pool;
  //   }
  // }

  // alias get_pool this;

  // Function: new
  //
  // Creates a new pool with the given ~name~.

  this (string name="") {
    synchronized(this) {
      super(name);
    }
  }


  int opApply(int delegate(ref KEY, ref VAL) dg) {
    synchronized(this) {
      int result = 0;
      auto keys = _pool.keys;

      for (size_t i = 0; i < keys.length; ++i) {
	  result = dg(keys[i], _pool[keys[i]]);
	  if (result) break;
	}
      return result;
    }
  }

  int opApply(int delegate(ref VAL) dg) {
    synchronized(this) {
      int result = 0;
      auto keys = _pool.keys;

      for (size_t i = 0; i < keys.length; ++i) {
	  result = dg(_pool[keys[i]]);
	  if (result) break;
	}
      return result;
    }
  }

  // We delibrately do not return a pointer from opBinaryRight since
  // that pointer can in that case escape the concurrency guards
  bool opBinaryRight(string OP)(KEY key) if(OP == "in") {
    synchronized(this) {
      if(key in _pool) return true;
      else return false;
    }
  }

  void opIndexAssign(VAL val, KEY key) {
    synchronized(this) {
      _pool[key] = val;
    }
  }

  VAL opIndex(KEY key) {
    synchronized(this) {
      return _pool[key];
    }
  }

  // Function: get_global_pool
  //
  // Returns the singleton global pool for the item type, VAL.
  //
  // This allows items to be shared amongst components throughout the
  // verification environment.

  static public this_type get_global_pool () {
    synchronized(typeid(this_type)) {
      uvm_root top = uvm_top;
      if (top !in _m_global_pool || _m_global_pool[top] is null) {
	_m_global_pool[top] = new this_type ("pool");
      }
      return _m_global_pool[top];
    }
  }


  // Function: get_global
  //
  // Returns the specified item instance from the global item pool.

  static public VAL get_global (KEY key) {
    synchronized(typeid(this_type)) {
      this_type gpool = get_global_pool();
      return gpool.get(key);
    }
  }


  // Function: get
  //
  // Returns the item with the given ~key~.
  //
  // If no item exists by that key, a new item is created with that key
  // and returned.

  public VAL get (KEY key) {
    synchronized(this) {
      if (key !in _pool) {
	VAL default_value;
	_pool[key] = default_value;
      }
      return _pool[key];
    }
  }


  // Function: add
  //
  // Adds the given (~key~, ~item~) pair to the pool. If an item already
  // exists at the given ~key~ it is overwritten with the new ~item~.

  public void add (KEY key, VAL item) {
    synchronized(this) {
      _pool[key] = item;
    }
  }


  // Function: num
  //
  // Returns the number of uniquely keyed items stored in the pool.

  public size_t num () {
    synchronized(this) {
      return _pool.length;
    }
  }


  // Function: delete
  //
  // Removes the item with the given ~key~ from the pool.

  public void remove (KEY key) {
    synchronized(this) {
      if (!exists(key)) {
	uvm_report_warning("POOLDEL",
			   "delete: pool key doesn't exist. Ignoring delete request");
	return;
      }
      _pool.remove(key);
    }
  }

  public void remove () {
    synchronized(this) {
      _pool = null;
    }
  }

  public void clear () {
    synchronized(this) {
      _pool = null;
    }
  }

  public void destroy () {
    synchronized(this) {
      _pool = null;
    }
  }


  // Function: exists
  //
  // Returns 1 if a item with the given ~key~ exists in the pool,
  // 0 otherwise.

  public bool exists (KEY key) {
    synchronized(this) {
      if (key in _pool) return true;
      else return false;
    }
  }

  // We are not defining the iterative operators for pool. Instead we
  // expose the protected member pool using "this" alias.

  private size_t _index;
  private KEY[]  _keys;

  // Function: first
  //
  // Returns the key of the first item stored in the pool.
  //
  // If the pool is empty, then ~key~ is unchanged and 0 is returned.
  //
  // If the pool is not empty, then ~key~ is key of the first item
  // and 1 is returned.

  public int first (ref KEY key) {
    synchronized(this) {
      this._keys = _pool.keys;
      static if(__traits(compiles, KEY.init < KEY.init)) {
	import std.algorithm;
	sort(_keys);
      }
      if (_keys.length is 0) {
	return 0;
      }
      else {
	_index = 0;
	key = _keys[_index];
	return 1;
      }
    }
  }


  // Function: last
  //
  // Returns the key of the last item stored in the pool.
  //
  // If the pool is empty, then 0 is returned and ~key~ is unchanged.
  //
  // If the pool is not empty, then ~key~ is set to the last key in
  // the pool and 1 is returned.

  public int last (ref KEY key) {
    synchronized(this) {
      this._keys = _pool.keys;
      static if(__traits(compiles, KEY.init < KEY.init)) {
	import std.algorithm;
	sort(_keys);
      }
      if (_keys.length is 0) {
	return 0;
      }
      else {
	_index = _keys.length - 1;
	key = _keys[_index];
	return 1;
      }
    }
  }

  // Function: next
  //
  // Returns the key of the next item in the pool.
  //
  // If the input ~key~ is the last key in the pool, then ~key~ is
  // left unchanged and 0 is returned.
  //
  // If a next key is found, then ~key~ is updated with that key
  // and 1 is returned.

  public int next (ref KEY key) {
    synchronized(this) {
      if (_keys.length is 0 ||
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


  // Function: prev
  //
  // Returns the key of the previous item in the pool.
  //
  // If the input ~key~ is the first key in the pool, then ~key~ is
  // left unchanged and 0 is returned.
  //
  // If a previous key is found, then ~key~ is updated with that key
  // and 1 is returned.

  public int prev (ref KEY key) {
    synchronized(this) {
      if (_keys.length is 0 ||
	  _index is 0) {
	return 0;
      }
      else {
	--_index;
	key = _keys[_index];
	return 1;
      }
    }
  }

  public override uvm_object create (string name=null) {
    synchronized(this) {
      this_type v = new this_type(name);
      return v;
    }
  }

  public override string get_type_name () {
    return qualifiedTypeName!(typeof(this));
  }

  public override void do_copy (uvm_object rhs) {
    synchronized(this, rhs) {
      super.do_copy(rhs);
      auto p = cast(this_type) rhs;
      // KEY key;
      if (rhs is null || p is null) {
	return;
      }
      _pool = p._pool;
    }
  }

  public override void do_print (uvm_printer printer) {
    synchronized(this) {
      size_t cnt;
      printer.print_array_header("pool", _pool.length, "aa_object_string");
      foreach(key, val; _pool) {
	string item = "[-key" ~ cnt.to!string() ~ "--]";
	string v = val.to!string;
	printer.print_generic(item,"",-1,v,'[');
	++cnt;
      }
      printer.print_array_footer();
    }
  }
};				// semicolon here takes care of emacs d-mode
				// indentation bug


//------------------------------------------------------------------------------
//
// CLASS: uvm_object_string_pool #(VAL)
//
//------------------------------------------------------------------------------
// This provides a specialization of the generic <uvm_pool #(KEY,VAL)> class for
// an associative array of <uvm_object>-based objects indexed by string.
// Specializations of this class include the ~uvm_event_pool~ (a
// uvm_object_string_pool storing <uvm_event>s) and
// ~uvm_barrier_pool~ (a uvm_obejct_string_pool storing <uvm_barrier>s).
//------------------------------------------------------------------------------

class uvm_object_string_pool (VAL=uvm_object): /*extends*/ uvm_pool!(string,VAL) {
  import std.string: format;

  alias uvm_object_string_pool!(VAL) this_type;
  private __gshared this_type[uvm_object] _m_global_pool;


  // Function: new
  //
  // Creates a new pool with the given ~name~.

  this(string name = "") {
    synchronized(this) {
      super(name);
    }
  }


  // Function: get_type_name
  //
  // Returns the type name of this object.

  public override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }

  // Function: get_global_pool
  //
  // Returns the singleton global pool for the item type, VAL.
  //
  // This allows items to be shared amongst components throughout the
  // verification environment.

  static public this_type get_global_pool () {
    synchronized(typeid(this_type)) {
      uvm_root top = uvm_top;
      if (top !in _m_global_pool || _m_global_pool[top] is null) {
	_m_global_pool[top] = new this_type ("global_pool");
      }
      return _m_global_pool[top];
    }
  }


  // Function: get_global
  //
  // Returns the specified item instance from the global item pool.

  static public VAL get_global (string key) {
    synchronized(typeid(this_type)) {
      this_type gpool;
      gpool = get_global_pool();
      return gpool.get(key);
    }
  }


  // Function: get
  //
  // Returns the object item at the given string ~key~.
  //
  // If no item exists by the given ~key~, a new item is created for that key
  // and returned.

  public override VAL get (string key) {
    synchronized(this) {
      if (key !in _pool) {
	_pool[key] = new VAL (key);
      }
      return _pool[key];
    }
  }


  // Function: remove
  //
  // Removes the item with the given string ~key~ from the pool.

  public override void remove (string key) {
    synchronized(this) {
      if (!exists(key)) {
	uvm_report_warning("POOLDEL",
			   format("delete: key '%s' doesn't exist", key));
	return;
      }
      _pool.remove(key);
    }
  }


  // Function- do_print

  public override void do_print (uvm_printer printer) {
    synchronized(this) {
      printer.print_array_header("pool", _pool.length, "aa_object_string");
      foreach(key,val; _pool) {
	printer.print_object("[" ~ key ~ "]", val, '[');
      }
      printer.print_array_footer();
    }
  }
}

import uvm.base.uvm_barrier;
import uvm.base.uvm_event;

alias uvm_object_string_pool!(uvm_barrier) uvm_barrier_pool;
alias uvm_object_string_pool!(uvm_event) uvm_event_pool;
