//----------------------------------------------------------------------
//   Copyright 2016-18    Coverify Systems Technology
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

module uvm.vpi.uvm_vpi_intf;
import esdl.intf.vpi;
import core.stdc.string: strlen;

class uvm_vpi_handle {
  bool _check;
  bool _action;
  vpiHandle _handle;

  this() {}
  
  this(vpiHandle handle, bool action = true, bool check = false) {
    _check  = check;
    _action = action;
    _handle = handle;
  }
  
  void assign(vpiHandle handle, bool action = true, bool check = false) {
    _check  = check;
    _action = action;
    _handle = handle;
  }
  
  void get_value(T)(ref T t) {
    import esdl.data.bvec;
    s_vpi_value val;
    import std.traits; // isIntegral
    import std.conv;
    static if(isIntegral!T) {
      if (_check) {
	uint size = vpi_get(vpiPropertyT.vpiSize, _handle);
	auto hname = vpi_get_str(vpiFullName, _handle);
	assert(size == T.sizeof*8,
	       hname[0..hname.strlen] ~ " is " ~ size.to!string() ~
	       " long; vpiPutValue received a BitVector of size: " ~
	       T.sizeof.stringof ~ "(bytes)\n");
      }
      if (_action) {
	static if(T.sizeof <= 32) {
	  val.format = vpiIntVal;
	  vpi_get_value(_handle, &val);
	  t = cast(T) val.value.integer;
	}
	else {
	  alias TT = _bvec!T;
	  enum VECLEN = T.sizeof / 4;
	  val.format = vpiVectorVal;
	  vpi_get_value(_handle, &val);
	  TT tt = val.value.vector[0..VECLEN];
	  t = tt;
	}
      }
    }
    else static if(is(T: bool)) {
      if (_check) {
	uint size = vpi_get(vpiPropertyT.vpiSize, _handle);
	auto hname = vpi_get_str(vpiFullName, _handle);
	assert(size == 1,
	       hname[0..hname.strlen] ~ " is " ~ size.to!string() ~
	       " long; vpiPutValue received a BitVector of size: 1"
	       ~ "\n");
      }
      if (_action) {
	val.format = vpiScalarVal;
	vpi_get_value(_handle, &val);
	if(val.value.scalar == 0) {
	  t = cast(T) false;
	}
	else {
	  t = cast(T) true;
	}
      }
    }
    else static if(isBitVector!T) {
      if (_check) {
	uint size = vpi_get(vpiPropertyT.vpiSize, _handle);
	auto hname = vpi_get_str(vpiFullName, _handle);
	assert(size == T.SIZE,
	       hname[0..hname.strlen] ~ " is " ~ size.to!string() ~
	       " long; vpiPutValue received a BitVector of size: " ~
	       T.SIZE.stringof ~ "\n");
      }
      if (_action) {
	static if(T.SIZE <= 32) {
	  val.format = vpiIntVal;
	  vpi_get_value(_handle, &val);
	  t = cast(T) val.value.integer.toBitVec();
	}
	else {
	  enum VECLEN = (T.SIZE+31)/32;
	  val.format = vpiVectorVal;
	  vpi_get_value(_handle, &val);
	  t = val.value.vector[0..VECLEN];
	}
      }
    }
    else {
      static assert(false, "vpiGetValue not yet implemented for type: " ~
		    T.stringof);
    }
  }

  void put_value(T)(T t, vpiFlagsTypeT flag = vpiNoDelay) {
    import esdl.data.bvec;
    s_vpi_value val;
    import std.traits; // isIntegral
    import std.conv;
    static if(isIntegral!T) {
      if (_check) {
	uint size = vpi_get(vpiPropertyT.vpiSize, _handle);
	auto hname = vpi_get_str(vpiFullName, _handle);
	assert(size == T.sizeof*8,
	       hname[0..hname.strlen] ~ " is " ~ size.to!string() ~
	       " long; vpiPutValue received a BitVector of size: " ~
	       T.sizeof.stringof ~ "(bytes)\n");
      }
      if (_action) {
	static if(T.sizeof <= 32) {
	  val.format = vpiIntVal;
	  val.value.integer = t;
	  vpi_put_value(_handle, &val, null, flag);
	}
	else {
	  alias TT = _bvec!T;
	  enum VECLEN = T.sizeof / 4;
	  s_vpi_vecval[VECLEN] vecval;
	  TT tt = t;
	  tt.toVpiVecValue(vecval);
	  val.format = vpiVectorVal;
	  val.value.vector = vecval.ptr;
	  vpi_put_value(_handle, &val, null, vpiNoDelay);
	}
      }
    }
    else static if(is(T: bool)) {
      if (_check) {
	uint size = vpi_get(vpiPropertyT.vpiSize, _handle);
	// auto hname = vpi_get_str(vpiFullName, _handle);
	assert(size == 1,
	       "Mismatch:  " ~ size.to!string() ~
	       " long; vpiPutValue received a BitVector of size: 1"
	       ~ "\n");
      }
      if (_action) {
	val.format = vpiScalarVal;
	val.value.scalar = t;
	vpi_put_value(_handle, &val, null, vpiNoDelay);
      }
    }
    else static if(isBitVector!T) {
      if (_check) {
	uint size = vpi_get(vpiPropertyT.vpiSize, _handle);
	auto hname = vpi_get_str(vpiFullName, _handle);
	assert(size == T.SIZE,
	       hname[0..hname.strlen] ~ " is " ~ size.to!string() ~
	       " long; vpiPutValue received a BitVector of size: " ~
	       T.SIZE.stringof ~ "\n");
      }
      if (_action) {
	enum VECLEN = (T.SIZE+31)/32;
	s_vpi_vecval[VECLEN] vecval;
	t.toVpiVecValue(vecval);
	val.format = vpiVectorVal;
	val.value.vector = vecval.ptr;
	vpi_put_value(_handle, &val, null, vpiNoDelay);
      }
    }
    else {
      static assert(false, "vpiPutValue not yet implemented for type: " ~
		    T.stringof);
    }
  }
}

// struct
class uvm_vpi_iter {
  import std.string: format;
  string         _name;
  bool           _check;
  bool           _action;
  vpiHandle      _iter;
  int            _count;
  uvm_vpi_handle _handle;

  this() {
    _handle = new uvm_vpi_handle();
  }

  this(vpiHandle iter, string name,
       bool action = true, bool check = false) {
    _check = check;
    _action = action;
    _iter = iter;
    _name = name;
    _count = 0;
    _handle = new uvm_vpi_handle();
  }

  void assign(vpiHandle iter, string name,
	      bool action = true, bool check = false) {
    _check = check;
    _action = action;
    _iter = iter;
    _name = name;
    _count = 0;
  }
  
  void get_values(T...)(ref T t) {
    static if(T.length > 0) {
      get_values_by_one(t[0], t[1..$]);
    }
  }

  void put_values(T...)(T t) {
    static if(T.length > 0) {
      put_values_by_one(t[0], t[1..$]);
    }
  }

  private void get_next_value(T)(ref T t) {
    vpiHandle h = vpi_scan(_iter);
    _count++;
    assert(h, format("Task %s takes %s arguments, but more are expected",
		     _name, _count));
    _handle.assign(h, _action, _check);
    _handle.get_value(t);
  }
  
  private void put_next_value(T)(T t, vpiFlagsTypeT flag = vpiNoDelay) {
    vpiHandle h = vpi_scan(_iter);
    _count++;
    assert(h, format("Task %s takes %s arguments, but more are expected",
		     _name, _count));
    _handle.assign(h, _action, _check);
    _handle.put_value(t, flag);
  }

  private void get_values_by_one(U, T...)(ref U u, ref T t) {
    get_next_value(u);
    static if(T.length > 0) {
      get_values_by_one(t[0], t[1..$]);
    }
  }

  private void put_values_by_one(U, T...)(U u, T t) {
    put_next_value(u, vpiNoDelay);
    static if(T.length > 0) {
      put_values_by_one(t[0], t[1..$]);
    }
  }
}

