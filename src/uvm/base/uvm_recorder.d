//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2012-2016 Coverify Systems Technology
//   Copyright 2013      NVIDIA Corporation
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


// File: UVM Recorders
//
// The uvm_recorder class serves two purposes:
//  - Firstly, it is an abstract representation of a record within a
//    <uvm_tr_stream>.
//  - Secondly, it is a policy object for recording fields ~into~ that
//    record within the ~stream~.
//

//------------------------------------------------------------------------------
//
// CLASS: uvm_recorder
//
// Abstract class which defines the ~recorder~ API.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_root;
import uvm.base.uvm_object;
import uvm.base.uvm_misc;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.meta.mcd;
import uvm.meta.misc;
import uvm.base.uvm_report_message;
import uvm.base.uvm_tr_stream;
import uvm.base.uvm_entity;
import uvm.dap.uvm_set_before_get_dap;

import esdl.data.time;
import esdl.data.bvec;
import esdl.data.bstr;
import esdl.base.core: SimTime, getRootEntity, Process;
import esdl.data.bvec;

import std.conv: to;
import std.string: format;



import std.traits: isNumeric, isFloatingPoint, isIntegral, isBoolean;

import std.random;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_tr_database;
import uvm.base.uvm_once;


abstract class uvm_recorder: uvm_object
{

  static class uvm_once: uvm_once_base
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

  mixin(uvm_once_sync_string);

  mixin(uvm_sync_string);
  // TBD
  // `uvm_object_utils(uvm_recorder)

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
    synchronized(this) {
      ++_recording_depth;
    }
  }

  void dec_recording_depth() {
    synchronized(this) {
      --_recording_depth;
    }
  }


  // Variable: default_radix
  //
  // This is the default radix setting if <record_field> is called without
  // a radix.

  @uvm_public_sync
  private uvm_radix_enum _default_radix = uvm_radix_enum.UVM_HEX;


  // Variable: physical
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The <is_abstract> and physical settings allow an object to distinguish between
  // two different classes of fields.
  //
  // It is up to you, in the <uvm_object::do_record> method, to test the
  // setting of this field if you want to use the physical trait as a filter.

  private bool _is_physical = true;


  // Variable: is_abstract
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The is_abstract and physical settings allow an object to distinguish between
  // two different classes of fields.
  //
  // It is up to you, in the <uvm_object::do_record> method, to test the
  // setting of this field if you want to use the is_abstract trait as a filter.

  private bool _is_abstract = true;


  // Variable: identifier
  //
  // This bit is used to specify whether or not an object's reference should be
  // recorded when the object is recorded.

  @uvm_public_sync
  private bool _identifier = true;


  // Variable: recursion_policy
  //
  // Sets the recursion policy for recording objects.
  //
  // The default policy is deep (which means to recurse an object).

  @uvm_public_sync
  private uvm_recursion_policy_enum _policy =
    uvm_recursion_policy_enum.UVM_DEFAULT_POLICY;

  // Variable- m_ids_by_recorder
  // An associative array of integers, indexed by uvm_recorders.  This
  // provides a unique 'id' or 'handle' for each recorder, which can be
  // used to identify the recorder.
  //
  // By default, neither ~m_ids_by_recorder~ or ~m_recorders_by_id~ are
  // used.  Recorders are only placed in the arrays when the user
  // attempts to determine the id for a recorder.

  // moved to once
  // static int m_ids_by_recorder[uvm_recorder];


  this (string name = "uvm_recorder") {
    synchronized(this) {
      super(name);
      _m_stream_dap = new uvm_set_before_get_dap!(uvm_tr_stream)("stream_dap");
      _m_warn_null_stream = true;
    }
  }

  // Group: Configuration API

  // Function: get_stream
  // Returns a reference to the stream which created
  // this record.
  //
  // A warning will be asserted if get_stream is called prior
  // to the record being initialized via <do_open>.
  //
  uvm_tr_stream get_stream() {
    synchronized(this) {
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

  // Group: Transaction Recorder API
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

  // Function: close
  // Closes this recorder.
  //
  // Closing a recorder marks the end of the transaction in the stream.
  //
  // Parameters:
  // close_time - Optional time to record as the closing time of this transaction.
  //
  // This method will trigger a <do_close> call.
  void close(SimTime close_time = 0) {
    synchronized(this) {
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

  // Function: free
  // Frees this recorder
  //
  // Freeing a recorder indicates that the stream and database can release
  // any references to the recorder.
  //
  // Parameters:
  // close_time - Optional time to record as the closing time of this transaction.
  //
  // If a recorder has not yet been closed (via a call to <close>), then
  // <close> will automatically be called, and passed the ~close_time~.  If the recorder
  // has already been closed, then the ~close_time~ will be ignored.
  //
  // This method will trigger a <do_free> call.
  void free(SimTime close_time = 0) {
    synchronized(this) {
      Process p=Process.self();
      Random s;

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
      if(p !is null) {
	s = p.getRandState();
      }
      _m_stream_dap = new uvm_set_before_get_dap!uvm_tr_stream("stream_dap");
      if(p !is null) {
	p.setRandState(s);
      }
      _m_warn_null_stream = true;

      synchronized(once) {
	auto pid = this in once._m_ids_by_recorder;
	if(pid !is null) {
	  m_free_id(*pid);
	}
      }

      // Clear out stream state
      if (stream !is null) {
	stream.m_free_recorder(this);
      }
    }
  }

  // Function: is_open
  // Returns true if this ~uvm_recorder~ was opened on its stream,
  // but has not yet been closed.
  //
  bool is_open() {
    synchronized(this) {
      return _m_is_opened;
    }
  }

  // Function: get_open_time
  // Returns the ~open_time~
  //
  SimTime get_open_time() {
    synchronized(this) {
      return _m_open_time;
    }
  }

  // Function: is_closed
  // Returns true if this ~uvm_recorder~ was closed on its stream,
  // but has not yet been freed.
  //
  bool is_closed() {
    synchronized(this) {
      return _m_is_closed;
    }
  }

  // Function: get_close_time
  // Returns the ~close_time~
  //
  SimTime get_close_time() {
    synchronized(this) {
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
    synchronized(this) {
      uvm_tr_stream m_stream;
      if(stream is null) {
	uvm_error("UVM/REC/NULL_STREAM",
		  format("Illegal attempt to set STREAM for '%s' to '<null>'",
			 this.get_name()));
	return;
      }

      if(_m_stream_dap.try_get(m_stream)) {
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

  // Group: Handles

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
    synchronized(once) {
      uvm_recorder recorder;
      auto pid = id in once._m_recorders_by_id;
      if (pid !is null) {
	recorder = *pid;
      }

      if (recorder !is null) {
	once._m_recorders_by_id.remove(id);
	once._m_ids_by_recorder.remove(recorder);
      }
    }
  }

  // Function: get_handle
  // Returns a unique ID for this recorder.
  //
  // A value of ~0~ indicates that the recorder has been ~freed~,
  // and no longer has a valid ID.
  //
  int get_handle() {
    if (!is_open() && !is_closed()) {
      return 0;
    }
    else {
      int handle = get_inst_id();
      synchronized(once) {
	// Check for the weird case where our handle changed.
	auto pid = this in once._m_ids_by_recorder;
	if(pid !is null && *pid !is handle) {
	  assert(false, "The weird case where our handle changed!");
	  // once._m_recorders_by_id.remove(*pid);
	}

	once._m_recorders_by_id[handle] = this;
	once._m_ids_by_recorder[this] = handle;

	return handle;
      }
    }
  }

  // Function: get_recorder_from_handle
  // Static accessor, returns a recorder reference for a given unique id.
  //
  // If no recorder exists with the given ~id~, or if the
  // recorder with that ~id~ has been freed, then ~null~ is
  // returned.
  //
  // This method can be used to access the recorder associated with a
  // call to <uvm_transaction::begin_tr> or <uvm_component::begin_tr>.
  //
  // | integer handle = tr.begin_tr();
  // | uvm_recorder recorder = uvm_recorder::get_recorder_from_handle(handle);
  // | if (recorder != null) begin
  // |   recorder.record_string("begin_msg", "Started recording transaction!");
  // | end
  //
  static uvm_recorder get_recorder_from_handle(int id) {
    synchronized(once) {
      if (id == 0) {
	return null;
      }

      auto pid = id in once._m_recorders_by_id;
      
      if (pid is null) {
	return null;
      }

      return *pid;
    }
  }

  // Group: Attribute Recording

  // Function: record_field
  // Records an integral field (less than or equal to 4096 bits).
  //
  // Parameters:
  // name - Name of the field
  // value - Value of the field to record.
  // size - Number of bits of the field which apply (Usually obtained via $bits).
  // radix - The <uvm_radix_enum> to use.
  //
  // This method will trigger a <do_record_field> call.
  alias record_field = record;
  void record(T)(string name, T value, size_t size,
		 uvm_radix_enum radix=UVM_NORADIX)
    if(isBitVector!T && T.SIZE > 64) {
      synchronized(this) {
	if (get_stream() is null) {
	  return;
	}
	do_record_field(name, value, size, radix);
      }
    }

  void record(T)(string name, T value, uvm_radix_enum radix=UVM_NORADIX)
    if(isBitVector!T && T.SIZE > 64) {
      synchronized(this) {
	if (get_stream() is null) {
	  return;
	}
	do_record_field(name, value, T.SIZE, radix);
      }
    }

  // Function: record_field_int
  // Records an integral field (less than or equal to 64 bits).
  //
  // This optimized version of <record_field> is useful for sizes up
  // to 64 bits.
  //
  // Parameters:
  // name - Name of the field
  // value - Value of the field to record
  // size - Number of bits of the wfield which apply (Usually obtained via $bits).
  // radix - The <uvm_radix_enum> to use.
  //
  // This method will trigger a <do_record_field_int> call.
  alias record_field_int = record;
  void record(T)(string name, T value, uvm_radix_enum radix=UVM_NORADIX)
    if(isIntegral!T || (isBitVector!T && T.SIZE <= 64) || isBoolean!T) {
      synchronized(this) {
	if (get_stream() is null) {
	  return;
	}
	static if(isIntegral!T) size_t size = T.sizeof * 8;
	static if(isBitVector!T) size_t size = T.SIZE;
	static if(isBoolean!T) size_t size = 1;

	do_record_field_int(name, cast(uvm_integral_t) value, size, radix);
      }
    }

  // Function: record_field_real
  // Records a real field.
  //
  // Parameters:
  // name - Name of the field
  // value - Value of the field to record
  //
  // This method will trigger a <do_record_field_real> call.
  void record(T)(string name, T value)
    if(isFloatingPoint!T) {
      synchronized(this) {
	if(get_stream() is null) {
	  return;
	}
	do_record_field_real(name, value);
      }
    }

  alias record_field_real = record;
  // Function: record_object
  // Records an object field.
  //
  // Parameters:
  // name - Name of the field
  // value - Object to record
  //
  // The implementation must use the <recursion_policy> and <identifier> to
  // determine exactly what should be recorded.
  void record(T)(string name, T value)
    if(is(T: uvm_object)) {
      synchronized(this) {
	if(get_stream() is null) {
	  return;
	}
	do_record_object(name, value);
      }
    }

  alias record_object = record;
  // Function: record_string
  // Records a string field.
  //
  // Parameters:
  // name - Name of the field
  // value - Value of the field
  //
  void record(T)(string name,
		 T value)
    if(is(T: string)) {
      synchronized(this) {
	if(get_stream() is null) {
	  return;
	}

	do_record_string(name, value);
      }
    }

  alias record_string = record;
  // Function: record_time
  // Records a time field.
  //
  // Parameters:
  // name - Name of the field
  // value - Value of the field
  //
  void record(T)(string name,
		 T value)
    if(is(T: SimTime)) {
      synchronized(this) {
	if(get_stream() is null) {
	  return;
	}

	do_record_time(name, value);
      }
    }

  alias record_time = record;

  // Function: record_generic
  // Records a name/value pair, where ~value~ has been converted to a string.
  //
  // For example:
  //| recorder.record_generic("myvar","var_type", $sformatf("%0d",myvar), 32);
  //
  // Parameters:
  // name - Name of the field
  // value - Value of the field
  // type_name - ~optional~ Type name of the field

  void record_generic(string name,
		      string value,
		      string type_name="") {
    synchronized(this) {
      if (get_stream() is null) {
	return;
      }

      do_record_generic(name, value, type_name);
    }
  }

  // Function: use_record_attribute
  //
  // Indicates that this recorder does (or does not) support usage of
  // the <`uvm_record_attribute> macro.
  //
  // The default return value is ~0~ (not supported), developers can
  // optionally extend ~uvm_recorder~ and set the value to ~1~ if they
  // support the <`uvm_record_attribute> macro.
  bool use_record_attribute() {
    return false;
  }


  // Function: get_record_attribute_handle
  // Provides a tool-specific handle which is compatible with <`uvm_record_attribute>.
  //
  // By default, this method will return the same value as <get_handle>,
  // however tool vendors can override this method to provide tool-specific handles
  // which will be passed to the <`uvm_record_attribute> macro.
  //
  int get_record_attribute_handle() {
    return get_handle();
  }

  // Group: Implementation Agnostic API

  // Function: do_open
  // Callback triggered via <uvm_tr_stream::open_recorder>.
  //
  // The ~do_open~ callback can be used to initialize any internal
  // state within the recorder, as well as providing a location to
  // record any initial information.
  protected void do_open(uvm_tr_stream stream, SimTime open_time,
			 string type_name) { }

  // Function: do_close
  // Callback triggered via <close>.
  //
  // The ~do_close~ callback can be used to set internal state
  // within the recorder, as well as providing a location to
  // record any closing information.
  protected void do_close(SimTime close_time) { }

  // Function: do_free
  // Callback triggered via <free>.
  //
  // The ~do_free~ callback can be used to release the internal
  // state within the recorder, as well as providing a location
  // to record any "freeing" information.
  protected void do_free() { }

  // Function: do_record_field
  // Records an integral field (less than or equal to 4096 bits).
  //
  // ~Mandatory~ Backend implementation of <record_field>
  abstract protected  void do_record_field(string name,
					   uvm_bitstream_t value,
					   size_t size,
					   uvm_radix_enum radix);

  // Function: do_record_field_int
  // Records an integral field (less than or equal to 64 bits).
  //
  // ~Mandatory~ Backend implementation of <record_field_int>
  abstract protected void do_record_field_int(string name,
					      uvm_integral_t value,
					      size_t size,
					      uvm_radix_enum radix);

  // Function: do_record_field_real
  // Records a real field.
  //
  // ~Mandatory~ Backend implementation of <record_field_real>
  abstract protected void do_record_field_real(string name,
					       double value);

  // Function: do_record_object
  // Records an object field.
  //
  // ~Mandatory~ Backend implementation of <record_object>
  abstract protected void do_record_object(string name,
					   uvm_object value);

  // Function: do_record_string
  // Records a string field.
  //
  // ~Mandatory~ Backend implementation of <record_string>
  abstract protected void do_record_string(string name,
					   string value);

  // Function: do_record_time
  // Records a time field.
  //
  // ~Mandatory~ Backend implementation of <record_time>
  abstract protected void do_record_time(string name,
					 SimTime value);

  // Function: do_record_generic
  // Records a name/value pair, where ~value~ has been converted to a string.
  //
  // ~Mandatory~ Backend implementation of <record_generic>
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
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_text_recorder
//
// The ~uvm_text_recorder~ is the default recorder implementation for the
// <uvm_text_tr_database>.
//

class uvm_text_recorder: uvm_recorder
{

  mixin uvm_object_utils_norand;

  // Variable- m_text_db
  //
  // Reference to the text database backend
  private uvm_text_tr_database _m_text_db;

  // Variable- scope
  // Imeplementation detail
  private uvm_scope_stack _scope_stack;

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_text_recorder") {
    super(name);
  }

  // Group: Implementation Agnostic API

  // Function: do_open
  // Callback triggered via <uvm_tr_stream::open_recorder>.
  //
  // Text-backend specific implementation.
  override protected void do_open(uvm_tr_stream stream,
				  SimTime open_time,
				  string type_name) {
    synchronized(this) {
      _m_text_db = cast(uvm_text_tr_database) stream.get_db();

      assert(_m_text_db !is null);

      if(_m_text_db.open_db()) {
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

  // Function: do_close
  // Callback triggered via <uvm_recorder::close>.
  //
  // Text-backend specific implementation.
  override protected void do_close(SimTime close_time) {
    synchronized(this) {
      if(_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "    CLOSE_RECORDER @%s {TXH:%0d TIME=%s}",
		  getRootEntity.getSimTime,
		  this.get_handle(),
		  close_time);
      }
    }
  }

  // Function: do_free
  // Callback triggered via <uvm_recorder::free>.
  //
  // Text-backend specific implementation.
  override protected void do_free() {
    synchronized(this) {
      if(_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "    FREE_RECORDER @%0t {TXH:%0d}",
		  getRootEntity.getSimTime,
		  this.get_handle());
      }
      _m_text_db = null;
    }
  }

  // Function: do_record_field
  // Records an integral field (less than or equal to 4096 bits).
  //
  // Text-backend specific implementation.
  override protected void do_record_field(string name,
					  uvm_bitstream_t value,
					  size_t size,
					  uvm_radix_enum radix) {
    synchronized(this) {
      _scope_stack.set_arg(name);
      if (!radix) {
	radix = _default_radix;
      }

      write_attribute(_scope_stack.get(), value, radix, size);
    }
  }

  // Function: do_record_field_int
  // Records an integral field (less than or equal to 64 bits).
  //
  // Text-backend specific implementation.
  override protected void do_record_field_int(string name,
					      uvm_integral_t value,
					      size_t size,
					      uvm_radix_enum radix) {
    synchronized(this) {
      _scope_stack.set_arg(name);
      if (!radix) {
	radix = _default_radix;
      }

      write_attribute_int(_scope_stack.get(), value, radix, size);
    }
  }

  T reinterpret( T, U )( U value ) {
    union Uni {
      U u;
      T t;
    }
    return Uni(value).t;
  }

  // Function: do_record_field_real
  // Record a real field.
  //
  // Text-backened specific implementation.
  override protected void do_record_field_real(string name,
					       double value) {
    synchronized(this) {
      enum S = value.sizeof * 8;
      Bit!S ival = reinterpret!(Bit!S)(value);

      _scope_stack.set_arg(name);

      write_attribute_int(_scope_stack.get(), ival, UVM_REAL, S);
    }
  }

  // Function: do_record_object
  // Record an object field.
  //
  // Text-backend specific implementation.
  //
  // The method uses ~identifier~ to determine whether or not to
  // record the object instance id, and ~recursion_policy~ to
  // determine whether or not to recurse into the object.
  override protected void do_record_object(string name,
					   uvm_object value) {
    synchronized(this) {
      int            v;
      // string         str;

      if(_identifier) {
	if(value !is null) {
	  // str = value.get_inst_id().to!string();
	  v = value.get_inst_id();
	}
	_scope_stack.set_arg(name);
	write_attribute_int(_scope_stack.get(), v, UVM_DEC, 32);
      }

      if(_policy != UVM_REFERENCE) {
	if(value !is null) {
	  if(value.m_uvm_status_container.check_cycle(value)) return;
	  value.m_uvm_status_container.add_cycle(value);
	  _scope_stack.down(name);
	  value.record(this);
	  _scope_stack.up();
	  value.m_uvm_status_container.remove_cycle(value);
	}
      }
    }
  }

  // Function: do_record_string
  // Records a string field.
  //
  // Text-backend specific implementation.
  override protected void do_record_string(string name,
					   string value) {
    synchronized(this) {
      _scope_stack.set_arg(name);
      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "      SET_ATTR @%s {TXH:%s NAME:%s VALUE:%s" ~
		  "   RADIX:%s BITS=%s}",
		  getRootEntity.getSimTime,
		  this.get_handle(),
		  _scope_stack.get(),
		  value,
		  "UVM_STRING",
		  8 + value.length);
      }
    }
  }

  // Function: do_record_time
  // Records a time field.
  //
  // Text-backend specific implementation.
  override protected void do_record_time(string name,
					 SimTime value) {
    synchronized(this) {
      _scope_stack.set_arg(name);
      write_attribute_int(_scope_stack.get(), value, UVM_TIME, 64);
    }
  }

  // Function: do_record_generic
  // Records a name/value pair, where ~value~ has been converted to a string.
  //
  // Text-backend specific implementation.
  override protected void do_record_generic(string name,
					    string value,
					    string type_name) {
    synchronized(this) {
      _scope_stack.set_arg(name);
      write_attribute(_scope_stack.get(),
		      uvm_string_to_bits(value),
		      UVM_STRING,
		      8+value.length);
    }
  }


  // Group: Implementation Specific API

  // Function: write_attribute
  // Outputs an integral attribute to the textual log
  //
  // Parameters:
  // nm - Name of the attribute
  // value - Value
  // radix - Radix of the output
  // numbits - number of valid bits
  void write_attribute(T)(string nm,
			  T value,
			  uvm_radix_enum radix,
			  size_t numbits=0) {
    synchronized(this) {
      if(numbits == 0) {
	static if(isIntegral!T) { numbits = T.sizeof * 8; }
	static if(isBitVector!T) { numbits = T.SIZE; }
	static if(isBoolean!T) { numbits = 1; }
	static if(isBitString!T) { numbits = value.length; }
      }

      if(_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "      SET_ATTR @%0t {TXH:%s NAME:%s VALUE:%s" ~
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

  // Function: write_attribute_int
  // Outputs an integral attribute to the textual log
  //
  // Parameters:
  // nm - Name of the attribute
  // value - Value
  // radix - Radix of the output
  // numbits - number of valid bits
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
    synchronized(this) {
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
    synchronized(this) {
      uvm_text_tr_stream stream;
      if (open_file()) {
	stream = cast(uvm_text_tr_stream)
	  _m_text_db.open_stream(name, scope_stack, t);
	assert(stream !is null);
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
    synchronized(this) {
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
    synchronized(this) {
      if (open_file()) {
	UVM_FILE file = _m_text_db.m_file;
	vfdisplay(file,
		  "      SET_ATTR @%0t {TXH:%s NAME:%s VALUE:%s" ~
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
    synchronized(this) {
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
    synchronized(this) {
      if(open_file()) {
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
    synchronized(this) {
      if(open_file()) {
	uvm_recorder record = uvm_recorder.get_recorder_from_handle(handle);
	if(record !is null) {
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
    synchronized(this) {
      if(open_file()) {
	vfdisplay(_m_text_db.m_file, "  LINK @%s {TXH1:%s TXH2:%s RELATION=%s}",
		  getRootEntity.getSimTime, h1, h2, relation);
      }
    }
  }


  // Function- free_tr
  //
  //
  override void free_tr(int handle) {
    synchronized(this) {
      if(open_file()) {
	uvm_recorder record = uvm_recorder.get_recorder_from_handle(handle);
	if (record !is null) {
	  record.free();
	}
      }
    }
  }
}
