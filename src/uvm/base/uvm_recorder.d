//
//-----------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2015 Analog Devices, Inc.
// Copyright 2011-2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2017-2018 Cisco Systems, Inc.
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


// File -- NODOCS -- UVM Recorders
//
// The uvm_recorder class serves two purposes:
//  - Firstly, it is an abstract representation of a record within a
//    <uvm_tr_stream>.
//  - Secondly, it is a policy object for recording fields ~into~ that
//    record within the ~stream~.
//

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_recorder
//
// Abstract class which defines the ~recorder~ API.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_policy: uvm_policy;
import uvm.base.uvm_misc: uvm_bitvec_to_string;

import uvm.base.uvm_object_globals: uvm_radix_enum, UVM_FILE,
  uvm_bitstream_t, uvm_integral_t, uvm_recursion_policy_enum,
  uvm_field_auto_enum, uvm_field_flag_t, UVM_RADIX;

import uvm.base.uvm_tr_stream: uvm_tr_stream;
import uvm.base.uvm_text_tr_stream: uvm_text_tr_stream;
import uvm.base.uvm_text_tr_database: uvm_text_tr_database;

import uvm.base.uvm_field_op: uvm_field_op;

import uvm.base.uvm_object_defines;
import uvm.base.uvm_scope;

import uvm.meta.mcd;
import uvm.meta.misc;
import uvm.dap.uvm_set_before_get_dap;

import esdl.data.time;
import esdl.data.bvec;
import esdl.data.bstr;
import esdl.base.core: SimTime, getRootEntity, Process;
import esdl.data.bvec;

import std.conv: to;
import std.string: format;



import std.traits: isNumeric, isFloatingPoint, isIntegral, isBoolean, isArray;

import std.random;


// @uvm-ieee 1800.2-2017 auto 16.4.1
abstract class uvm_recorder: uvm_policy
{

  mixin uvm_abstract_object_essentials;
  
  static class uvm_scope: uvm_scope_base
  {
    // Variable- m_ids_by_recorder
    // An associative array of integers, indexed by uvm_recorders.  This
    // provides a unique 'id' or 'handle' for each recorder, which can be
    // used to identify the recorder.
    //
    // By default, neither ~m_ids_by_recorder~ or ~m_recorders_by_id~ are
    // used.  Recorders are only placed in the arrays when the user
    // attempts to determine the id for a recorder.
    @uvm_none_sync
    private int[uvm_recorder] _m_ids_by_recorder;

    // Variable- m_recorders_by_id
    // A corollary to ~m_ids_by_recorder~, this indexes the recorders by their
    // unique ids.
    @uvm_none_sync
    private uvm_recorder[int] _m_recorders_by_id;

    // Variable- m_id
    // Static int marking the last assigned id.
    // private int _m_id;  // declared in SV -- otherwise unused
  };

  mixin (uvm_scope_sync_string);

  mixin (uvm_sync_string);

  // Variable- m_stream_dap
  // Data access protected reference to the stream
  private uvm_set_before_get_dap!uvm_tr_stream _m_stream_dap;

  // Variable- m_warn_null_stream
  // Used to limit the number of warnings
  private bool _m_warn_null_stream;

  // Variable- m_is_opened
  // Used to indicate recorder is open
  private bool _m_is_opened;

  // Variable- m_is_closed
  // Used to indicate recorder is closed
  private bool _m_is_closed;

  // !m_is_opened && !m_is_closed == m_is_freed

  // Variable- m_open_time
  // Used to store the open_time
  private SimTime _m_open_time;

  // Variable- m_close_time
  // Used to store the close_time
  private SimTime _m_close_time;

  // Variable- recording_depth
  // this variable is used in inherited class uvm_object
  @uvm_public_sync
  private int _recording_depth;

  void inc_recording_depth() {
    synchronized (this) {
      ++_recording_depth;
    }
  }

  void dec_recording_depth() {
    synchronized (this) {
      --_recording_depth;
    }
  }


  // Variable -- NODOCS -- default_radix
  //
  // This is the default radix setting if <record_field> is called without
  // a radix.

  @uvm_public_sync
  private uvm_radix_enum _default_radix = uvm_radix_enum.UVM_HEX;


  // Variable -- NODOCS -- identifier
  //
  // This bit is used to specify whether or not an object's reference should be
  // recorded when the object is recorded.

  @uvm_public_sync
  private bool _identifier = true;


  // Variable -- NODOCS -- recursion_policy
  //
  // Sets the recursion policy for recording objects.
  //
  // The default policy is deep (which means to recurse an object).

  @uvm_public_sync
  private uvm_recursion_policy_enum _policy =
    uvm_recursion_policy_enum.UVM_DEFAULT_POLICY;

  // @uvm-ieee 1800.2-2017 auto 16.4.2.1
  void set_recursion_policy(uvm_recursion_policy_enum policy) {
    synchronized (this) {
      this._policy  = policy;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.4.2.1
  uvm_recursion_policy_enum get_recursion_policy() {
    synchronized (this) {
      return this._policy;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.4.4.1
  override  void flush() {
    synchronized (this) {
      _policy      = uvm_recursion_policy_enum.UVM_DEFAULT_POLICY;
      _identifier  = true;
      free();
    }
  }
  
  // Variable- m_ids_by_recorder
  // An associative array of int, indexed by uvm_recorders.  This
  // provides a unique 'id' or 'handle' for each recorder, which can be
  // used to identify the recorder.
  //
  // By default, neither ~m_ids_by_recorder~ or ~m_recorders_by_id~ are
  // used.  Recorders are only placed in the arrays when the user
  // attempts to determine the id for a recorder.

  // moved to once
  // static int m_ids_by_recorder[uvm_recorder];

  this (string name = "uvm_recorder") {
    synchronized (this) {
      super(name);
      _m_stream_dap = new uvm_set_before_get_dap!(uvm_tr_stream)("stream_dap");
      _m_warn_null_stream = true;
    }
  }

  // Group -- NODOCS -- Configuration API


  // @uvm-ieee 1800.2-2017 auto 16.4.3
  uvm_tr_stream get_stream() {
    import uvm.base.uvm_globals;
    synchronized (this) {
      uvm_tr_stream get_stream_;
      if (!_m_stream_dap.try_get(get_stream_)) {
	if (_m_warn_null_stream == true) {
	  uvm_warning("UVM/REC/NO_CFG",
		      format("attempt to retrieve STREAM from" ~
			     " '%s' before it was set!", get_name()));
	}
	_m_warn_null_stream = false;
      }
      return get_stream_;
    }
  }

  // Group -- NODOCS -- Transaction Recorder API
  //
  // Once a recorder has been opened via <uvm_tr_stream::open_recorder>, the user
  // can ~close~ the recorder.
  //
  // Due to the fact that many database implementations will require crossing
  // a language boundary, an additional step of ~freeing~ the recorder is required.
  //
  // A ~link~ can be established within the database any time between ~open~ and
  // ~free~, however it is illegal to establish a link after ~freeing~ the recorder.
  //


  // @uvm-ieee 1800.2-2017 auto 16.4.4.2
  void close(SimTime close_time = 0) {
    synchronized (this) {
      if (close_time == 0) {
	close_time = getRootEntity.getSimTime;
      }

      if (!is_open()) {
	return;
      }

      do_close(close_time);

      _m_is_opened = false;
      _m_is_closed = true;
      _m_close_time = close_time;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.4.3
  void free(SimTime close_time = 0) {
    synchronized (this) {
      if (!is_open() && !is_closed()) {
	return;
      }

      if (is_open()) {
	close(close_time);
      }

      do_free();

      // Clear out internal state
      uvm_tr_stream stream = get_stream();

      _m_is_closed = false;

      version (PRESERVE_RANDSTATE) {
	Process p = Process.self();
	Random s;
	if (p !is null)
	  p.getRandState(s);
      }

      _m_stream_dap = new uvm_set_before_get_dap!uvm_tr_stream("stream_dap");

      version (PRESERVE_RANDSTATE) {
	if (p !is null)
	  p.setRandState(s);
      }

      _m_warn_null_stream = true;

      synchronized (_uvm_scope_inst) {
	auto pid = this in _uvm_scope_inst._m_ids_by_recorder;
	if (pid !is null) {
	  m_free_id(*pid);
	}
      }

      // Clear out stream state
      if (stream !is null) {
	stream.m_free_recorder(this);
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.4.4
  bool is_open() {
    synchronized (this) {
      return _m_is_opened;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.4.5
  SimTime get_open_time() {
    synchronized (this) {
      return _m_open_time;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.4.6
  bool is_closed() {
    synchronized (this) {
      return _m_is_closed;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.4.7
  SimTime get_close_time() {
    synchronized (this) {
      return _m_close_time;
    }
  }

  // Function- m_do_open
  // Initializes the internal state of the recorder.
  //
  // Parameters:
  // stream - The stream which spawned this recorder
  //
  // This method will trigger a <do_open> call.
  //
  // An error will be asserted if:
  // - ~m_do_open~ is called more than once without the
  //  recorder being ~freed~ in between.
  // - ~stream~ is ~null~
  void m_do_open(uvm_tr_stream stream, SimTime open_time, string type_name) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      uvm_tr_stream m_stream;
      if (stream is null) {
	uvm_error("UVM/REC/NULL_STREAM",
		  format("Illegal attempt to set STREAM for '%s' to '<null>'",
			 this.get_name()));
	return;
      }

      if (_m_stream_dap.try_get(m_stream)) {
	uvm_error("UVM/REC/RE_INIT",
		  format("Illegal attempt to re-initialize '%s'",
			 this.get_name()));
	return;
      }

      _m_stream_dap.set(stream);
      _m_open_time = open_time;
      _m_is_opened = 1;

      do_open(stream, open_time, type_name);
    }
  }

  // Group -- NODOCS -- Handles

  // Moved to once
  // // Variable- m_recorders_by_id
  // // A corollary to ~m_ids_by_recorder~, this indexes the recorders by their
  // // unique ids.
  // local static uvm_recorder m_recorders_by_id[integer];

  // // Variable- m_id
  // // Static int marking the last assigned id.
  // local static integer m_id;

  // Function- m_free_id
  // Frees the id/recorder link (memory cleanup)
  //
  static void m_free_id(int id) {
    synchronized (_uvm_scope_inst) {
      uvm_recorder recorder;
      auto pid = id in _uvm_scope_inst._m_recorders_by_id;
      if (pid !is null) {
	recorder = *pid;
      }

      if (recorder !is null) {
	_uvm_scope_inst._m_recorders_by_id.remove(id);
	_uvm_scope_inst._m_ids_by_recorder.remove(recorder);
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.5.1
  int get_handle() {
    if (!is_open() && !is_closed()) {
      return 0;
    }
    else {
      int handle = get_inst_id();
      synchronized (_uvm_scope_inst) {
	// Check for the weird case where our handle changed.
	auto pid = this in _uvm_scope_inst._m_ids_by_recorder;
	if (pid !is null && *pid !is handle) {
	  assert (false, "The weird case where our handle changed!");
	  // _uvm_scope_inst._m_recorders_by_id.remove(*pid);
	}

	_uvm_scope_inst._m_recorders_by_id[handle] = this;
	_uvm_scope_inst._m_ids_by_recorder[this] = handle;

	return handle;
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.5.2
  static uvm_recorder get_recorder_from_handle(int id) {
    synchronized (_uvm_scope_inst) {
      if (id == 0) {
	return null;
      }

      auto pid = id in _uvm_scope_inst._m_recorders_by_id;
      
      if (pid is null) {
	return null;
      }

      return *pid;
    }
  }

  // Group -- NODOCS -- Attribute Recording


  // @uvm-ieee 1800.2-2017 auto 16.4.6.1
  alias record_field = record;
  void record(T)(string name, T value, size_t size,
		 uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX)
    if (isBitVector!T && T.SIZE > 64) {
      synchronized (this) {
	if (get_stream() is null) {
	  return;
	}
	do_record_field(name, value, size, radix);
      }
    }

  void record(T)(string name, T value, uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX)
    if (isBitVector!T && T.SIZE > 64) {
      synchronized (this) {
	if (get_stream() is null) {
	  return;
	}
	do_record_field(name, value, T.SIZE, radix);
      }
    }


  // @uvm-ieee 1800.2-2017 auto 16.4.6.2
  alias record_field_int = record;
  void record(T)(string name, T value, uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX)
    if (isIntegral!T || (isBitVector!T && T.SIZE <= 64) || isBoolean!T) {
      synchronized (this) {
	if (get_stream() is null) {
	  return;
	}
	static if (isIntegral!T) size_t size = T.sizeof * 8;
	static if (isBitVector!T) size_t size = T.SIZE;
	static if (isBoolean!T) size_t size = 1;

	do_record_field_int(name, cast (uvm_integral_t) value, size, radix);
      }
    }


  // @uvm-ieee 1800.2-2017 auto 16.4.6.3
  void record(T)(string name, T value)
    if (isFloatingPoint!T) {
      synchronized (this) {
	if (get_stream() is null) {
	  return;
	}
	do_record_field_real(name, value);
      }
    }

  alias record_field_real = record;

  // @uvm-ieee 1800.2-2017 auto 16.4.6.4
  void record(T)(string name, T value)
    if (is (T: uvm_object)) {
      synchronized (this) {
	if (get_stream() is null) {
	  return;
	}
	if (value is null)
	  do_record_object(name, value);
	else {
	  push_active_object(value);
	  do_record_object(name, value);
	  pop_active_object();
	}
      }
    }

  alias record_object = record;

  // @uvm-ieee 1800.2-2017 auto 16.4.6.5
  void record(T)(string name,
		 T value)
    if (is (T: string)) {
      synchronized (this) {
	if (get_stream() is null) {
	  return;
	}

	do_record_string(name, value);
      }
    }

  alias record_string = record;

  // @uvm-ieee 1800.2-2017 auto 16.4.6.6
  void record(T)(string name,
		 T value)
    if (is (T: SimTime)) {
      synchronized (this) {
	if (get_stream() is null) {
	  return;
	}

	do_record_time(name, value);
      }
    }

  alias record_time = record;


  // @uvm-ieee 1800.2-2017 auto 16.4.6.7
  void record_generic(string name,
		      string value,
		      string type_name="") {
    synchronized (this) {
      if (get_stream() is null) {
	return;
      }

      do_record_generic(name, value, type_name);
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.6.8
  bool use_record_attribute() {
    return false;
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.6.9
  int get_record_attribute_handle() {
    return get_handle();
  }

  // Group -- NODOCS -- Implementation Agnostic API


  // @uvm-ieee 1800.2-2017 auto 16.4.7.1
  protected void do_open(uvm_tr_stream stream, SimTime open_time,
			 string type_name) { }


  // @uvm-ieee 1800.2-2017 auto 16.4.7.2
  protected void do_close(SimTime close_time) { }


  // @uvm-ieee 1800.2-2017 auto 16.4.7.3
  protected void do_free() { }


  // @uvm-ieee 1800.2-2017 auto 16.4.7.4
  abstract protected  void do_record_field(string name,
					   uvm_bitstream_t value,
					   size_t size,
					   uvm_radix_enum radix);


  // @uvm-ieee 1800.2-2017 auto 16.4.7.5
  abstract protected void do_record_field_int(string name,
					      uvm_integral_t value,
					      size_t size,
					      uvm_radix_enum radix);


  // @uvm-ieee 1800.2-2017 auto 16.4.7.6
  abstract protected void do_record_field_real(string name,
					       double value);

  // Function : do_record_object
  // The library implements do_record_object as virtual even though the LRM
  // calls for pure virtual. Mantis 6591 calls for the LRM to move to
  // virtual.  The implemented signature is:
  // virtual protected function void do_record_object(string name, uvm_object value);
  
  // @uvm-ieee 1800.2-2017 auto 16.4.7.7
  protected void do_record_object(string name,
				  uvm_object value) {
    if ((get_recursion_policy() != uvm_recursion_policy_enum.UVM_REFERENCE) &&
	(value !is null)) {
      uvm_field_op field_op = uvm_field_op.m_get_available_op();
      field_op.set(uvm_field_auto_enum.UVM_RECORD, this, null);
      value.do_execute_op(field_op);
      if (field_op.user_hook_enabled())
	value.do_record(this);
      field_op.m_recycle();
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.4.7.9
  abstract protected void do_record_string(string name,
					   string value);


  // @uvm-ieee 1800.2-2017 auto 16.4.7.10
  abstract protected void do_record_time(string name,
					 SimTime value);


  // @uvm-ieee 1800.2-2017 auto 16.4.7.11
  abstract protected void do_record_generic(string name,
					    string value,
					    string type_name);


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
  bool open_file() {
    return 0;
  }

  // Function- create_stream
  //
  //
  int create_stream (string name,
		     string t,
		     string scope_stack) {
    return -1;
  }


  // Function- m_set_attribute
  //
  //
  void m_set_attribute (int txh,
			string nm,
			string value) {}


  // Function- set_attribute
  //
  void set_attribute (int txh,
		      string nm,
		      Logic!1024 value,
		      uvm_radix_enum radix,
		      int numbits=1024) {}


  // Function- check_handle_kind
  //
  //
  int check_handle_kind (string htype, int handle) {
    return 0;
  }


  // Function- begin_tr
  //
  //
  int begin_tr(string txtype,
	       int stream,
	       string nm,
	       string label="",
	       string desc="",
	       SimTime begin_time=0) {
    return -1;
  }


  // Function- end_tr
  //
  //
  void end_tr (int handle, SimTime end_time=0) { }


  // Function- link_tr
  //
  //
  void link_tr(int h1,
	       int h2,
	       string relation="") { }


  // Function- free_tr
  //
  //
  void free_tr(int handle) { }

  void uvm_record_element(E)(string name, ref E elem,
			    uvm_field_flag_t flags) {
    synchronized (this) {
      m_uvm_record_element!E(name, elem, flags);
    }
  }
  
  void m_uvm_record_element(E)(string name, ref E elem,
			      uvm_field_flag_t flags) {
    static if (isArray!E && !is (E == string)) {
      int sz = cast (int) elem.length;
      if (sz == 0) {
	uvm_record_int(name, 0, uvm_radix_enum.UVM_DEC);
      }
      else if (sz < 10) {
	foreach (index, ref ee; elem) {
	  m_uvm_record_element(format("%s[%0d]", name, index), ee, flags);
	}
      }
      else {
	for (int i=0; i!=5; ++i) {
	  m_uvm_record_element(format("%s[%0d]", name, i), elem[i], flags);
	}
	for (int i=sz-5; i!=sz; ++i) {
	  m_uvm_record_element(format("%s[%0d]", name, i), elem[i], flags);
	}
      }
    }
    else static if (is (E: uvm_object)) {
      this.record(name, elem);
    }
    else static if (isBitVector!E || isIntegral!E || isBoolean!E) {
      uvm_record_int(name, elem, cast (uvm_radix_enum) (flags & UVM_RADIX));
    }
    else {
      uvm_record(name, elem);
    }
  }

  void uvm_record_int(T)(string name, T value, uvm_radix_enum radix) {
    if (this.use_record_attribute())
      uvm_record_attribute(this.get_record_attribute_handle(),
			   name, value);
    else
      this.record(name, value, radix);
  }
  
  void uvm_record(T)(string name, T value) {
    if (this.use_record_attribute())
      uvm_record_attribute(this.get_record_attribute_handle(),
			   name, value);
    else
      this.record(name, value);
  }

  void uvm_record_attribute(T)(int handle, string name, T value) {
    this.record_generic(name, format("%s", value));
  }
  
}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_text_recorder
//
// The ~uvm_text_recorder~ is the default recorder implementation for the
// <uvm_text_tr_database>.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

class uvm_text_recorder: uvm_recorder
{

  mixin uvm_object_essentials;

  // Variable- m_text_db
  //
  // Reference to the text database backend
  private uvm_text_tr_database _m_text_db;


  // Function -- NODOCS -- new
  // Constructor
  //
  // Parameters --NODOCS--
  // name - Instance name
  this(string name="unnamed-uvm_text_recorder") {
    synchronized (this) {
      super(name);
    }
  }

  // Group -- NODOCS -- Implementation Agnostic API

  // Function -- NODOCS -- do_open
  // Callback triggered via <uvm_tr_stream::open_recorder>.
  //
  // Text-backend specific implementation.
  override protected void do_open(uvm_tr_stream stream,
				  SimTime open_time,
				  string type_name) {
    synchronized (this) {
      _m_text_db = cast (uvm_text_tr_database) stream.get_db();

      assert (_m_text_db !is null);

      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "    OPEN_RECORDER @%s {TXH:%0d STREAM:%0d NAME:%s" ~
		  " TIME:%s TYPE=\"%s\"}",
		  getRootEntity.getSimTime,
		  this.get_handle(),
		  stream.get_handle(),
		  this.get_name(),
		  open_time,
		  type_name);
      }
    }
  }

  // Function -- NODOCS -- do_close
  // Callback triggered via <uvm_recorder::close>.
  //
  // Text-backend specific implementation.
  override protected void do_close(SimTime close_time) {
    synchronized (this) {
      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "    CLOSE_RECORDER @%s {TXH:%0d TIME=%s}",
		  getRootEntity.getSimTime,
		  this.get_handle(),
		  close_time);
      }
    }
  }

  // Function -- NODOCS -- do_free
  // Callback triggered via <uvm_recorder::free>.
  //
  // Text-backend specific implementation.
  override protected void do_free() {
    synchronized (this) {
      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "    FREE_RECORDER @%s {TXH:%0d}",
		  getRootEntity.getSimTime,
		  this.get_handle());
      }
      _m_text_db = null;
    }
  }

  // Function -- NODOCS -- do_record_field
  // Records an integral field (less than or equal to 4096 bits).
  //
  // Text-backend specific implementation.
  override protected void do_record_field(string name,
					  uvm_bitstream_t value,
					  size_t size,
					  uvm_radix_enum radix) {
    synchronized (this) {
      if (!radix)
	radix = _default_radix;

      write_attribute(m_current_context(name),
		      value,
		      radix,
		      size);
    }
  }

  // Function -- NODOCS -- do_record_field_int
  // Records an integral field (less than or equal to 64 bits).
  //
  // Text-backend specific implementation.
  override protected void do_record_field_int(string name,
					      uvm_integral_t value,
					      size_t size,
					      uvm_radix_enum radix) {
    synchronized (this) {
      if (!radix)
	radix = _default_radix;

      write_attribute_int(m_current_context(name),
			  value,
			  radix,
			  size);
    }
  }

  T reinterpret( T, U )( U value ) {
    union Uni {
      U u;
      T t;
    }
    return Uni(value).t;
  }

  // Function -- NODOCS -- do_record_field_real
  // Record a real field.
  //
  // Text-backened specific implementation.
  override protected void do_record_field_real(string name,
					       double value) {
    synchronized (this) {
      enum S = value.sizeof * 8;
      Bit!S ival = reinterpret!(Bit!S)(value);

      write_attribute_int(m_current_context(name),
			  ival,
			  uvm_radix_enum.UVM_REAL,
			  S);
    }
  }

  // Stores the passed-in names of the objects in the hierarchy
  private string[] _m_object_names;
  private string m_current_context(string name="") {
    synchronized (this) {
      if (_m_object_names.length  == 0)
	return name; //??
      else if ((_m_object_names.length == 1) && (name==""))
	return _m_object_names[0];
      else {
	string     full_name;
	foreach (i, object_name; _m_object_names) {
	  if (i == _m_object_names.length - 1)
	    full_name ~= object_name;
	  else
	    full_name  ~= object_name ~ ".";
	}
	if (name != "")
	  return full_name ~ "." ~ name;
	else
	  return full_name;
      }
    }
  }

  
  // Function -- NODOCS -- do_record_object
  // Record an object field.
  //
  // Text-backend specific implementation.
  //
  // The method uses ~identifier~ to determine whether or not to
  // record the object instance id, and ~recursion_policy~ to
  // determine whether or not to recurse into the object.
  override protected void do_record_object(string name,
					   uvm_object value) {
    synchronized (this) {
      int            v;
      // string         str;

      if (_identifier) {
	if (value !is null) {
	  v = value.get_inst_id();
	}
	write_attribute_int("inst_id",
			    v,
			    uvm_radix_enum.UVM_DEC,
			    32);
      }

      if (get_active_object_depth() > 1)
        _m_object_names ~= name;
      super.do_record_object(name, value);
      if (get_active_object_depth() > 1)
        _m_object_names.length -= 1;
    }
  }

  // Function -- NODOCS -- do_record_string
  // Records a string field.
  //
  // Text-backend specific implementation.
  override protected void do_record_string(string name,
					   string value) {
    synchronized (this) {
      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "      SET_ATTR @%s {TXH:%s NAME:%s VALUE:%s" ~
		  "   RADIX:%s BITS=%s}",
		  getRootEntity.getSimTime,
		  this.get_handle(),
                   m_current_context(name),
		  value,
		  "UVM_STRING",
		  8 + value.length);
      }
    }
  }

  // Function -- NODOCS -- do_record_time
  // Records a time field.
  //
  // Text-backend specific implementation.
  override protected void do_record_time(string name,
					 SimTime value) {
    synchronized (this) {
      write_attribute_int(m_current_context(name),
			  value,
			  uvm_radix_enum.UVM_TIME,
			  64);
    }
  }

  // Function -- NODOCS -- do_record_generic
  // Records a name/value pair, where ~value~ has been converted to a string.
  //
  // Text-backend specific implementation.
  override protected void do_record_generic(string name,
					    string value,
					    string type_name) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      write_attribute(m_current_context(name),
		      uvm_string_to_bits(value),
		      uvm_radix_enum.UVM_STRING,
		      8+value.length);
    }
  }


  // Group -- NODOCS -- Implementation Specific API

  // Function -- NODOCS -- write_attribute
  // Outputs a <uvm_bitstream_t> attribute to the textual log
  //
  // Parameters:
  // nm - Name of the attribute
  // value - Value
  // radix - Radix of the output
  // numbits - number of valid bits
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  void write_attribute(T)(string nm,
			  T value,
			  uvm_radix_enum radix,
			  size_t numbits=0) {
    synchronized (this) {
      if (numbits == 0) {
	static if (isIntegral!T) { numbits = T.sizeof * 8; }
	static if (isBitVector!T) { numbits = T.SIZE; }
	static if (isBoolean!T) { numbits = 1; }
	static if (isBitString!T) { numbits = value.length; }
      }

      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "      SET_ATTR @%s {TXH:%s NAME:%s VALUE:%s" ~
		  "   RADIX:%s BITS=%s}",
		  getRootEntity.getSimTime,
		  this.get_handle(),
		  nm,
		  uvm_bitvec_to_string(value, numbits, radix),
		  radix.to!string(),
		  numbits);
      }
    }
  }

  // Function -- NODOCS -- write_attribute_int
  // Outputs an <uvm_integral_t> attribute to the textual log
  //
  // Parameters:
  // nm - Name of the attribute
  // value - Value
  // radix - Radix of the output
  // numbits - number of valid bits
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  alias write_attribute_int = write_attribute;

  /// LEFT FOR BACKWARDS COMPAT ONLY!!!!!!!!

  //------------------------------
  // Group- Vendor-Independent API
  //------------------------------


  // UVM provides only a text-based default implementation.
  // Vendors provide subtype implementations and overwrite the
  // <uvm_default_recorder> handle.

  private string _filename;
  private bool _filename_set;

  // Function- open_file
  //
  // Opens the file in the <filename> property and assigns to the
  // file descriptor <file>.
  //
  override bool open_file() {
    synchronized (this) {
      if (!_filename_set) {
	_m_text_db.set_file_name(_filename);
      }
      return _m_text_db.open_db();
    }
  }


  // Function- create_stream
  //
  //
  override int create_stream (string name,
			      string t,
			      string scope_stack) {
    synchronized (this) {
      uvm_text_tr_stream stream;
      if (open_file()) {
	stream = cast (uvm_text_tr_stream)
	  _m_text_db.open_stream(name, scope_stack, t);
	assert (stream !is null);
	return stream.get_handle();
      }
      return 0;
    }
  }


  // Function- m_set_attribute
  //
  //
  override void m_set_attribute (int txh,
				 string nm,
				 string value) {
    synchronized (this) {
      if (open_file()) {
	UVM_FILE file = _m_text_db.m_file;
	vfdisplay(file,
		  "      SET_ATTR @%s {TXH:%0d NAME:%s VALUE:%s}",
		  getRootEntity.getSimTime, txh, nm, value);
      }
    }
  }


  // Function- set_attribute
  //
  //
  override void set_attribute (int txh,
			       string nm,
			       Logic!1024 value,
			       uvm_radix_enum radix,
			       int numbits=1024) {
    synchronized (this) {
      if (open_file()) {
	UVM_FILE file = _m_text_db.m_file;
	vfdisplay(file,
		  "      SET_ATTR @%s {TXH:%s NAME:%s VALUE:%s" ~
		  "   RADIX:%s BITS=%s}",
		  getRootEntity.getSimTime,
		  txh,
		  nm,
		  uvm_bitvec_to_string(value, numbits, radix),
		  radix.to!string(),
		  numbits);
      }
    }
  }


  // Function- check_handle_kind
  //
  //
  override int check_handle_kind(string htype, int handle) {
    synchronized (this) {
      return ((uvm_recorder.get_recorder_from_handle(handle) !is null) ||
	      (uvm_tr_stream.get_stream_from_handle(handle) !is null));
    }
  }


  // Function- begin_tr
  //
  //
  override int begin_tr(string txtype,
			int stream,
			string nm,
			string label="",
			string desc="",
			SimTime begin_time=0) {
    synchronized (this) {
      if (open_file()) {
	uvm_tr_stream stream_obj =
	  uvm_tr_stream.get_stream_from_handle(stream);
	uvm_recorder recorder;

	if (stream_obj is null) {
	  return -1;
	}

	recorder = stream_obj.open_recorder(nm, begin_time, txtype);

	return recorder.get_handle();
      }
      return -1;
    }
  }


  // Function- end_tr
  //
  //
  override void end_tr (int handle, SimTime end_time=0) {
    synchronized (this) {
      if (open_file()) {
	uvm_recorder record = uvm_recorder.get_recorder_from_handle(handle);
	if (record !is null) {
	  record.close(end_time);
	}
      }
    }
  }

  // Function- link_tr
  //
  //
  override void link_tr(int h1,
			int h2,
			string relation="") {
    synchronized (this) {
      if (open_file()) {
	vfdisplay(_m_text_db.m_file, "  LINK @%s {TXH1:%s TXH2:%s RELATION=%s}",
		  getRootEntity.getSimTime, h1, h2, relation);
      }
    }
  }


  // Function- free_tr
  //
  //
  override void free_tr(int handle) {
    synchronized (this) {
      if (open_file()) {
	uvm_recorder record = uvm_recorder.get_recorder_from_handle(handle);
	if (record !is null) {
	  record.free();
	}
      }
    }
  }
}
