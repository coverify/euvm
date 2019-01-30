//
//-----------------------------------------------------------------------------
// Copyright 2016-2019 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2015 Analog Devices, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013-2015 NVIDIA Corporation
// Copyright 2017 Cisco Systems, Inc.
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

module uvm.base.uvm_tr_stream;

import uvm.base.uvm_tr_database: uvm_tr_database;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_recorder: uvm_recorder, uvm_text_recorder;
import uvm.base.uvm_once;
import uvm.base.uvm_object_defines;
import uvm.dap.uvm_set_before_get_dap: uvm_set_before_get_dap;

import uvm.meta.misc;
import uvm.meta.mcd;

import esdl.base.core: SimTime, getRootEntity, Process;

import std.random;

//------------------------------------------------------------------------------
// File -- NODOCS -- Transaction Recording Streams
//

// class- m_uvm_tr_stream_cfg
// Undocumented helper class for storing stream
// initialization values.
class m_uvm_tr_stream_cfg
{
  mixin (uvm_sync_string);

  @uvm_private_sync
  private uvm_tr_database _db;
  @uvm_private_sync
  private string _hscope;
  @uvm_private_sync
  private string _stream_type_name;
}



// @uvm-ieee 1800.2-2017 auto 7.2.1
abstract class uvm_tr_stream: uvm_object
{

  static class uvm_once: uvm_once_base
  {
    // Variable- m_ids_by_stream
    // An associative array of int, indexed by uvm_tr_streams.  This
    // provides a unique 'id' or 'handle' for each stream, which can be
    // used to identify the stream.
    //
    // By default, neither ~m_ids_by_stream~ or ~m_streams_by_id~ are
    // used.  Streams are only placed in the arrays when the user
    // attempts to determine the id for a stream.
    @uvm_none_sync
    private int[uvm_tr_stream] _m_ids_by_stream;

    // Variable- m_streams_by_id
    // A corollary to ~m_ids_by_stream~, this indexes the streams by their
    // unique ids.
    @uvm_none_sync
    private uvm_tr_stream[int] _m_streams_by_id;

    
  }

  mixin (uvm_once_sync_string);

  // Variable- m_cfg_dap
  // Data access protected reference to the DB
  private uvm_set_before_get_dap!m_uvm_tr_stream_cfg _m_cfg_dap;

  // Variable- m_records
  // Active records in the stream (active == open or closed)
  private bool[uvm_recorder] _m_records;

  // Variable- m_warn_null_cfg
  // Used to limit the number of warnings
  private bool _m_warn_null_cfg;

  // Variable- m_is_opened
  // Used to indicate stream is open
  private bool _m_is_opened;

  // Variable- m_is_closed
  // Used to indicate stream is closed
  private bool _m_is_closed;

  // !m_is_opened && !m_is_closed == m_is_freed

  // @uvm-ieee 1800.2-2017 auto 7.2.2
  this(string name="unnamed-uvm_tr_stream") {
    synchronized (this) {
      super(name);
      _m_cfg_dap = new uvm_set_before_get_dap!m_uvm_tr_stream_cfg("cfg_dap");
    }
  }


  // Group -- NODOCS -- Configuration API


  // @uvm-ieee 1800.2-2017 auto 7.2.3.1
  uvm_tr_database get_db() {
    import uvm.base.uvm_globals;
    import std.string: format;
    synchronized (this) {
      m_uvm_tr_stream_cfg m_cfg;
      if (!_m_cfg_dap.try_get(m_cfg)) {
	if (_m_warn_null_cfg is true) {
	  uvm_warning("UVM/REC_STR/NO_CFG",
		      format("attempt to retrieve DB from '%s' before it was set!",
			     get_name()));
	}
	_m_warn_null_cfg = false;
	return null;
      }
      return m_cfg.db;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 7.2.3.2
  string get_scope() {
    import uvm.base.uvm_globals;
    import std.string: format;
    synchronized (this) {
      m_uvm_tr_stream_cfg m_cfg;
      if (!_m_cfg_dap.try_get(m_cfg)) {
	if (_m_warn_null_cfg is true) {
	  uvm_warning("UVM/REC_STR/NO_CFG",
		      format("attempt to retrieve scope from '%s' before it was set!",
			     get_name()));
	}
	_m_warn_null_cfg = false;
	return "";
      }
      return m_cfg.hscope;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 7.2.3.3
  string get_stream_type_name() {
    import uvm.base.uvm_globals;
    import std.string: format;
    synchronized (this) {
      m_uvm_tr_stream_cfg m_cfg;
      if (!_m_cfg_dap.try_get(m_cfg)) {
	if (_m_warn_null_cfg is true) {
	  uvm_warning("UVM/REC_STR/NO_CFG",
		      format("attempt to retrieve STREAM_TYPE_NAME from '%s' before it was set!",
			     get_name()));
	}
	_m_warn_null_cfg = false;
	return "";
      }
      return m_cfg.stream_type_name;
    }
  }

  // Group -- NODOCS -- Stream API
  //
  // Once a stream has been opened via <uvm_tr_database::open_stream>, the user
  // can ~close~ the stream.
  //
  // Due to the fact that many database implementations will require crossing
  // a language boundary, an additional step of ~freeing~ the stream is required.
  //
  // A ~link~ can be established within the database any time between "Open" and
  // "Free", however it is illegal to establish a link after "Freeing" the stream.
  //


  // @uvm-ieee 1800.2-2017 auto 7.2.4.1
  void close() {
    synchronized (this) {
      if (!is_open()) {
	return;
      }

      do_close();

      foreach (idx, unused; _m_records) {
	if (idx.is_open()) {
	  idx.close();
	}
      }

      _m_is_opened = false;
      _m_is_closed = true;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 7.2.4.2
  void free() {
    synchronized (this) {
      uvm_tr_database db;
      if (!is_open() && !is_closed()) {
	return;
      }

      if (is_open()) {
	close();
      }

      do_free();

      foreach (idx, unused; _m_records) {
	idx.free();
      }

      // Clear out internal state
      db = get_db();
      _m_is_closed = false;

      version (PRESERVE_RANDSTATE) {
	Process p = Process.self();
	Random s;
	if (p !is null)
	  p.getRandState(s);
      }

      _m_cfg_dap =  new uvm_set_before_get_dap!m_uvm_tr_stream_cfg("cfg_dap");

      version (PRESERVE_RANDSTATE) {
	if (p !is null)
	  p.setRandState(s);
      }

      _m_warn_null_cfg = true;

      synchronized (_uvm_once_inst) {
	auto pid = this in _uvm_once_inst._m_ids_by_stream;
	if (pid !is null) {
	  m_free_id(*pid);
	}
      }

      // Clear out DB state
      if (db !is null) {
	db.m_free_stream(this);
      }
    }
  }

  // Function- m_do_open
  // Initializes the state of the stream
  //
  // Parameters-
  // db - Database which the stream belongs to
  // scope - Optional scope
  // stream_type_name - Optional type name for the stream
  //
  // This method will trigger a <do_open> call.
  //
  // An error will be asserted if-
  // - m_do_open is called more than once without the stream
  //   being ~freed~ between.
  // - m_do_open is passed a ~null~ db
  void m_do_open(uvm_tr_database db,
		 string hscope="",
		 string stream_type_name="") {
    import uvm.base.uvm_globals;
    import std.string: format;
    synchronized (this) {
      m_uvm_tr_stream_cfg m_cfg;
      uvm_tr_database m_db;
      if (db is null) {
	uvm_error("UVM/REC_STR/NULL_DB",
		  format("Illegal attempt to set DB for '%s' to '<null>'",
			 this.get_full_name()));
	return;
      }

      if (_m_cfg_dap.try_get(m_cfg)) {
	uvm_error("UVM/REC_STR/RE_CFG",
		  format("Illegal attempt to re-open '%s'",
			 this.get_full_name()));
      }
      else {
	// Never set before
	m_cfg = new m_uvm_tr_stream_cfg();
	m_cfg.db = db;
	m_cfg.hscope = hscope;
	m_cfg.stream_type_name = stream_type_name;
	_m_cfg_dap.set(m_cfg);
	_m_is_opened = true;

	do_open(db, hscope, stream_type_name);
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 7.2.4.3
  bool is_open() {
    synchronized (this) {
      return _m_is_opened;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 7.2.4.4
  bool is_closed() {
    synchronized (this) {
      return _m_is_closed;
    }
  }

  // Group -- NODOCS -- Transaction Recorder API
  //
  // New recorders can be opened prior to the stream being ~closed~.
  //
  // Once a stream has been closed, requests to open a new recorder
  // will be ignored (<open_recorder> will return ~null~).
  //

  // Function -- NODOCS -- open_recorder
  // Marks the opening of a new transaction recorder on the stream.
  //
  // Parameters:
  // name - A name for the new transaction
  // open_time - Optional time to record as the opening of this transaction
  // type_name - Optional type name for the transaction
  //
  // If ~open_time~ is omitted (or set to 0), then the stream will use
  // the current time.
  //
  // This method will trigger a <do_open_recorder> call.  If ~do_open_recorder~
  // returns a non-~null~ value, then the <uvm_recorder::do_open> method will
  // be called in the recorder.
  //
  // Transaction recorders can only be opened if the stream is
  // ~open~ on the database (per <is_open>).  Otherwise the
  // request will be ignored, and ~null~ will be returned.


  // @uvm-ieee 1800.2-2017 auto 7.2.5.1
  uvm_recorder open_recorder(string name,
			     SimTime open_time = 0,
			     string type_name="") {
    synchronized (this) {
      uvm_recorder result;
      SimTime m_time = (open_time == 0) ? getRootEntity.getSimTime : open_time;

      // Check to make sure we're open
      if (!is_open()) {
	return null;
      }
      else {

	version (PRESERVE_RANDSTATE) {
	  Process p = Process.self;
	  Random s;
	  if (p !is null)
	    p.getRandState(s);
	}

	result = do_open_recorder(name, m_time, type_name);

	if (result !is null) {
	  _m_records[result] = true;
	  result.m_do_open(this, m_time, type_name);
	}

	version (PRESERVE_RANDSTATE) {
	  if (p !is null)
	    p.setRandState(s);
	}
      }
      return result;
    }
  }

  // Function- m_free_recorder
  // Removes recorder from the internal array
  void m_free_recorder(uvm_recorder recorder) {
    synchronized (this) {
      if (recorder in _m_records) {
	_m_records.remove(recorder);
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 7.2.5.2
  uint get_recorders(/*ref*/ out uvm_recorder[] q) {
    synchronized (this) {
      // Clear out the queue first...
      // q.delete();
      // Fill in the values
      foreach (idx, unused; _m_records) {
	q ~= idx;
      }
      // Finally return the size of the queue
      return cast (uint) q.length;
    }
  }

  // Group -- NODOCS -- Handles


  // Function -- NODOCS -- get_handle
  // Returns a unique ID for this stream.
  //
  // A value of ~0~ indicates that the recorder has been ~freed~,
  // and no longer has a valid ID.
  //

  // @uvm-ieee 1800.2-2017 auto 7.2.6.1
  int get_handle() {
    int handle;
    synchronized (this) {
      if (!is_open() && !is_closed()) {
	return 0;
      }
      else {
	handle = get_inst_id();	// call to uvm_object.get_inst_id
      }
    }

    // Check for the weird case where our handle changed.
    synchronized (_uvm_once_inst) {
      auto phandle = this in _uvm_once_inst._m_ids_by_stream;
      if (phandle !is null && *phandle !is handle) {
    	_uvm_once_inst._m_streams_by_id.remove(*phandle);
      }

      _uvm_once_inst._m_streams_by_id[handle] = this;
      _uvm_once_inst._m_ids_by_stream[this] = handle;

    }

    return handle;
  }

  // @uvm-ieee 1800.2-2017 auto 7.2.6.2
  static uvm_tr_stream get_stream_from_handle(int id) {
    if (id == 0) {
      return null;
    }
    synchronized (_uvm_once_inst) {
      auto pstream = id in _uvm_once_inst._m_streams_by_id;
      if (// $isunknown(id) ||
    	 pstream is null) {
    	return null;
      }

      return *pstream;
    }
  }

  // Function- m_free_id
  // Frees the id/stream link (memory cleanup)
  //
  static void m_free_id(int id) {
    synchronized (_uvm_once_inst) {
      uvm_tr_stream stream;
      auto pstream = id in _uvm_once_inst._m_streams_by_id;
      if (// !$isunknown(id) &&
    	 pstream !is null) {
    	stream = *pstream;
      }

      if (stream !is null) {
    	_uvm_once_inst._m_streams_by_id.remove(id);
    	_uvm_once_inst._m_ids_by_stream.remove(stream);
      }
    }
  }

  // Group -- NODOCS -- Implementation Agnostic API
  //


  // @uvm-ieee 1800.2-2017 auto 7.2.7.1
  protected void do_open(uvm_tr_database db,
			 string hscope,
			 string stream_type_name) { }


  // @uvm-ieee 1800.2-2017 auto 7.2.7.2
  protected void do_close() { }


  // @uvm-ieee 1800.2-2017 auto 7.2.7.3
  protected void do_free() { }


  // @uvm-ieee 1800.2-2017 auto 7.2.7.4
  protected uvm_recorder do_open_recorder(string name,
					  SimTime open_time,
					  string type_name) {
    return null;
  }
}
