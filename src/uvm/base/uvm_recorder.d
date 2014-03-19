//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
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
//-----------------------------------------------------------------------------

module uvm.base.uvm_recorder;

//------------------------------------------------------------------------------
//
// CLASS: uvm_recorder
//
// The uvm_recorder class provides a policy object for recording <uvm_objects>.
// The policies determine how recording should be done.
//
// A default recorder instance, <uvm_default_recorder>, is used when the
// <uvm_object::record> is called without specifying a recorder.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_root;
import uvm.base.uvm_object;
import uvm.base.uvm_misc;
import uvm.base.uvm_object_globals;
import uvm.meta.mcd;
import uvm.meta.misc;
import esdl.base.core: getSimTime;

import std.traits: isNumeric, isFloatingPoint, isIntegral;

class uvm_once_recorder
{
  @uvm_private_sync private bool[int] _m_handles;
  @uvm_private_sync private int _handle;
}

class uvm_recorder: uvm_object
{

  import esdl.base.time;
  import esdl.data.bvec;

  mixin(uvm_once_sync!uvm_once_recorder);

  mixin(uvm_sync!uvm_recorder);
  // TBD
  // `uvm_object_utils(uvm_recorder)

  // this variable is used in inherited class uvm_object
  @uvm_public_sync private int _recording_depth;

  public void inc_recording_depth() {
    synchronized(this) {
      ++_recording_depth;
    }
  }

  public void dec_recording_depth() {
    synchronized(this) {
      --_recording_depth;
    }
  }

  @uvm_private_sync private UVM_FILE _file;

  @uvm_public_sync private string _filename = "tr_db.log";


  // Variable: tr_handle
  //
  // This is an integral handle to a transaction object. Its use is vendor
  // specific.
  //
  // A handle of 0 indicates there is no active transaction object.

  // integer
  @uvm_public_sync private int _tr_handle = 0;


  // Variable: default_radix
  //
  // This is the default radix setting if <record_field> is called without
  // a radix.

  @uvm_public_sync private uvm_radix_enum _default_radix = UVM_HEX;


  // Variable: physical
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The <is_abstract> and physical settings allow an object to distinguish between
  // two different classes of fields.
  //
  // It is up to you, in the <uvm_object::do_record> method, to test the
  // setting of this field if you want to use the physical trait as a filter.

  // physical is defined in SV -- seems to be redundant
  // private bool _physical = true;


  // Variable: is_abstract
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The is_abstract and physical settings allow an object to distinguish between
  // two different classes of fields.
  //
  // It is up to you, in the <uvm_object::do_record> method, to test the
  // setting of this field if you want to use the is_abstract trait as a filter.

  // is_abstract is defined in SV -- seems to be redundant
  // private bool _is_abstract = true;


  // Variable: identifier
  //
  // This bit is used to specify whether or not an object's reference should be
  // recorded when the object is recorded.

  @uvm_public_sync bool _identifier = true;


  // Variable: recursion_policy
  //
  // Sets the recursion policy for recording objects.
  //
  // The default policy is deep (which means to recurse an object).

  @uvm_public_sync uvm_recursion_policy_enum _policy = UVM_DEFAULT_POLICY;


  public this (string name = "uvm_recorder") {
    synchronized(this) {
      super(name);
      _scope_stack = new uvm_scope_stack ();
    }
  }

  // Function: get_type_name
  //
  // Returns type name of the recorder. Subtypes must override this method
  // to enable the <`uvm_record_field> macro.
  //
  //| virtual function string get_type_name()



  // Function: record
  //
  // Records an integral field (less than or equal to 4096 bits). ~name~ is the
  // name of the field.
  //
  // ~value~ is the value of the field to record. ~size~ is the number of bits
  // of the field which apply. ~radix~ is the <uvm_radix_enum> to use.


  public void record(T)(string name,
			T value,
			uvm_radix_enum radix = UVM_NORADIX)
    if(isNumeric!T || isBitVector!T || is(T == bool)) {
      synchronized(this) {
	if(_tr_handle is 0) return;
	_scope_stack.set_arg(name);

	if(radix is UVM_NORADIX) radix = _default_radix;

	set_attribute(_tr_handle, _scope_stack.get(), value, radix,
		      BitLength!T);
      }
    }

  // Function: record_field_real
  //
  // Records an real field. ~value~ is the value of the field to record.

  public void record(T)(string name,
			T value)
    if(isFloatingPoint!T) {
      synchronized(this) {
	ubvec!(BitLength!T) ival = value;
	if(_tr_handle is 0) return;
	_scope_stack.set_arg(name);
	set_attribute(_tr_handle, _scope_stack.get(), ival, UVM_REAL,
		      BitLength!T);
      }
    }

  // Function: record_object
  //
  // Records an object field. ~name~ is the name of the recorded field.
  //
  // This method uses the <recursion_policy> to determine whether or not to
  // recurse into the object.

  public void record(T)(string name, T value)
    if(is(T unused: uvm_object)) {
      synchronized(this) {
	static if(is(T unused: uvm_object)) {
	  int v;
	  if(_identifier) {
	    if(value !is null) {
	      v = value.get_inst_id();
	    }
	    _scope_stack.set_arg(name);
	    set_attribute(_tr_handle, _scope_stack.get(), v,
			  UVM_DEC, 8 * v.sizeof);
	  }
	  if(_policy !is UVM_REFERENCE) {
	    if(value !is null) {
	      if(! value.m_uvm_status_container.add_cycle(value)) return;
	      _scope_stack.down(name);
	      value.record(this);
	      _scope_stack.up();
	      value.m_uvm_status_container.remove_cycle(value);
	    }
	  }
	}
      }
    }

  // // Function: record_string
  // //
  // // Records a string field. ~name~ is the name of the recorded field.

  public void record(T)(string name, T value)
    if(is(T == string)) {
      synchronized(this)
	{
	  import uvm.base.uvm_globals;
	  _scope_stack.set_arg(name);
	  set_attribute(_tr_handle, _scope_stack.get(),
			uvm_string_to_bits(value),
			UVM_STRING, 8*value.length);
	}
    }

  // // Function: record_time
  // //
  // // Records a time value. ~name~ is the name to record to the database.


  public void record(T)(string name, T value)
    if(is(T == SimTime) || is(T == Time)) {
      synchronized(this)
	{
	  _scope_stack.set_arg(name);
	  alias UBitVec!(8*T.sizeof) V;
	  V ival = value.to!long();
	  set_attribute(_tr_handle, _scope_stack.get(), ival,
			UVM_TIME, ival.length);
	}
    }


  // // Function: record_generic
  // //
  // // Records the ~name~-~value~ pair, where ~value~ has been converted
  // // to a string. For example:
  // //
  // //| recorder.record_generic("myvar",$sformatf("%0d",myvar));

  // public void record_generic (string name, string value)
  // {
  //   synchronized(this)
  //     {
  //	import uvm.base.uvm_globals;
  //	_scope_stack.set_arg(name);
  //	set_attribute(_tr_handle, _scope_stack.get(), cast(LogicVec!4096) uvm_string_to_bits(value),
  //		      UVM_STRING, 8*value.length);
  //     }
  // }

  private uvm_scope_stack _scope_stack; //  = new;



  //------------------------------
  // Group- Vendor-Independent API
  //------------------------------


  // UVM provides only a text-based default implementation.
  // Vendors provide subtype implementations and overwrite the
  // <uvm_default_recorder> handle.


  // Function- open_file
  //
  // Opens the file in the <filename> property and assigns to the
  // file descriptor <file>.
  //
  public bool open_file() {
    synchronized(this) {
      import uvm.meta.mcd;
      if (_file is 0) {
	_file = vfopen(_filename);
      }
      return (_file > 0);
    }
  }


  // Function- create_stream
  //
  //
  public int create_stream (string name,
			    string t,
			    string _scope) {
    if (open_file()) {
      synchronized(_once) {	// since we are not locking "this"
				// monitor, do not use '_file'
	import uvm.meta.mcd;
	_m_handles[++_handle] = true;
	vfdisplay(this.file,
		  "  CREATE_STREAM @%0t {NAME:%s T:%s SCOPE:%s STREAM:%0d}",
		  getSimTime(), name, t, _scope, _handle);
	return _handle;
      }
    }
    return 0;
  }


  // Function- m_set_attribute
  //
  //
  public void m_set_attribute (int txh,
			       string nm,
			       string value) {
    synchronized(this) {
      if (open_file()) {
	import uvm.meta.mcd;
	vfdisplay(_file,"  SET_ATTR @%0t {TXH:%0d NAME:%s VALUE:%s}",
		  getSimTime(), txh, nm, value);
      }
    }
  }


  // Function- set_attribute
  //
  //
  public void set_attribute(T)(int txh,
			       string nm,
			       T value,
			       uvm_radix_enum radix,
			       size_t numbits = 1024)
    if(isBitVector!T || isIntegral!T || is(T == string)) {
      synchronized(this) {
	if (open_file()) {
	  import uvm.meta.mcd;
	  vfdisplay(_file,"  SET_ATTR @%0t {TXH:%0d NAME:%s VALUE:%0d"
		    "   RADIX:%s BITS=%0d}",
		    getSimTime(), txh, nm, value, radix, numbits);
	}
      }
    }


  // Function- check_handle_kind
  //
  //
  public bool check_handle_kind (string htype, int han) {
    synchronized(_once) {
      if (han in _m_handles) return true;
      else return false;
    }
  }


  // Function- begin_tr
  //
  //
  public int begin_tr(string txtype,
		      int stream,
		      string nm,
		      string label="",
		      string desc="",
		      SimTime begin_time=SimTime(0)) {
    if (open_file()) {
      synchronized(_once) {	// since we are not locking "this"
				// monitor, do not use '_file'
	_m_handles[++_handle] = true;
	import uvm.meta.mcd;
	vfdisplay(this.file, "BEGIN @%0t {TXH:%0d STREAM:%0d NAME:%s "
		  "TIME=%0t  TYPE=\"%0s\" LABEL:\"%0s\" DESC=\"%0s\"}",
		  getSimTime(), _handle, stream, nm, begin_time, txtype,
		  label, desc);
	return _handle;
      }
    }
    else {
      return -1;
    }
  }


  // Function- end_tr
  //
  //
  public void end_tr (int han, SimTime end_time=SimTime(0)) {
    if (open_file()) {
      synchronized(this) {
	import uvm.meta.mcd;
	vfdisplay(_file, "END @%0t {TXH:%0d TIME=%0t}",
		  getSimTime(), han, end_time);
      }
    }
  }


  // Function- link_tr
  //
  //
  public void link_tr(int h1,
		      int h2,
		      string relation="") {
    synchronized(this) {
      if (open_file()) {
	import uvm.meta.mcd;
	vfdisplay(_file, "  LINK @%0t {TXH1:%0d TXH2:%0d RELATION=%0s}",
		  getSimTime(), h1, h2, relation);
      }
    }
  }



  // Function- free_tr
  //
  //
  public void free_tr(int han) {
    if(open_file()) {
      import uvm.meta.mcd;
      vfdisplay(this.file, "FREE @%0t {TXH:%0d}",
		getSimTime(), han);
      synchronized(_once) {
	if(han in _m_handles) _m_handles.remove(han);
      }
    }
  }
}
