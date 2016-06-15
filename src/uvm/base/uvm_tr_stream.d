//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2013      NVIDIA Corporation
//   Copyright 2016      Coverify Systems Technology
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

import uvm.base.uvm_tr_database;
import uvm.base.uvm_object;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_recorder;
import uvm.base.uvm_globals;
import uvm.base.uvm_entity;
import uvm.base.uvm_once;
import uvm.meta.misc;
import uvm.dap.uvm_set_before_get_dap;
import uvm.meta.mcd;

import esdl.base.core: SimTime, getRootEntity, Process;

import std.random;
import std.string: format;

//------------------------------------------------------------------------------
// File: Transaction Recording Streams
//

// class- m_uvm_tr_stream_cfg
// Undocumented helper class for storing stream
// initialization values.
class m_uvm_tr_stream_cfg
{
  mixin(uvm_sync_string);

  @uvm_private_sync
  uvm_tr_database _db;
  @uvm_private_sync
  string _hscope;
  @uvm_private_sync
  string _stream_type_name;

  // uvm_tr_database db() {
  //   synchronized(this) {
  //     return _db;
  //   }
  // }
  // void db(uvm_tr_database v) {
  //   synchronized(this) {
  //     _db = v;
  //   }
  // }
  // string hscope() {
  //   synchronized(this) {
  //     return _hscope;
  //   }
  // }
  // void hscope(string v) {
  //   synchronized(this) {
  //     _hscope = v;
  //   }
  // }
  // string stream_type_name() {
  //   synchronized(this) {
  //     return _stream_type_name;
  //   }
  // }
  // void stream_type_name(string v) {
  //   synchronized(this) {
  //     _stream_type_name = v;
  //   }
  // }
}


//------------------------------------------------------------------------------
//
// CLASS: uvm_tr_stream
//
// The ~uvm_tr_stream~ base class is a representation of a stream of records
// within a <uvm_tr_database>.
//
// The record stream is intended to hide the underlying database implementation
// from the end user, as these details are often vendor or tool-specific.
//
// The ~uvm_tr_stream~ class is pure virtual, and must be extended with an
// implementation.  A default text-based implementation is provided via the
// <uvm_text_tr_stream> class.
//
abstract class uvm_tr_stream: uvm_object
{

  static class uvm_once: uvm_once_base
  {
    // Variable- m_ids_by_stream
    // An associative array of integers, indexed by uvm_tr_streams.  This
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

  mixin(uvm_once_sync_string);

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

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Stream instance name
  this(string name="unnamed-uvm_tr_stream") {
    synchronized(this) {
      super(name);
      _m_cfg_dap = new uvm_set_before_get_dap!m_uvm_tr_stream_cfg("cfg_dap");
    }
  }


  // Group: Configuration API

  // Function: get_db
  // Returns a reference to the database which contains this
  // stream.
  //
  // A warning will be asserted if get_db is called prior to
  // the stream being initialized via <do_open>.
  uvm_tr_database get_db() {
    synchronized(this) {
      m_uvm_tr_stream_cfg m_cfg;
      if(!_m_cfg_dap.try_get(m_cfg)) {
	if(_m_warn_null_cfg is true) {
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


  // Function: get_scope
  // Returns the ~scope~ supplied when opening this stream.
  //
  // A warning will be asserted if get_scope is called prior to
  // the stream being initialized via <do_open>.
  string get_scope() {
    synchronized(this) {
      m_uvm_tr_stream_cfg m_cfg;
      if(!_m_cfg_dap.try_get(m_cfg)) {
	if(_m_warn_null_cfg is true) {
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

  // Function: get_stream_type_name
  // Returns a reference to the database which contains this
  // stream.
  //
  // A warning will be asserted if get_stream_type_name is called prior to
  // the stream being initialized via <do_open>.
  string get_stream_type_name() {
    synchronized(this) {
      m_uvm_tr_stream_cfg m_cfg;
      if(!_m_cfg_dap.try_get(m_cfg)) {
	if(_m_warn_null_cfg is true) {
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

  // Group: Stream API
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

  // Function: close
  // Closes this stream.
  //
  // Closing a stream closes all open recorders in the stream.
  //
  // This method will trigger a <do_close> call, followed by
  // <uvm_recorder::close> on all open recorders within the
  // stream.
  void close() {
    synchronized(this) {
      if(!is_open()) {
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

  // Function: free
  // Frees this stream.
  //
  // Freeing a stream indicates that the database can free any
  // references to the stream (including references to records
  // within the stream).
  //
  // This method will trigger a <do_free> call, followed by
  // <uvm_recorder::free> on all recorders within the stream.
  void free() {
    synchronized(this) {
      uvm_tr_database db;
      if (!is_open() && !is_closed()) {
	return;
      }

      if (is_open()) {
	close();
      }

      do_free();

      foreach(idx, unused; _m_records) {
	idx.free();
      }

      // Clear out internal state
      db = get_db();
      _m_is_closed = false;
      Process p = Process.self();
      Random s;
      if(p !is null) {
	s = p.getRandState();
      }
      _m_cfg_dap =  new uvm_set_before_get_dap!m_uvm_tr_stream_cfg("cfg_dap");

      if(p !is null) {
	p.setRandState(s);
      }
      _m_warn_null_cfg = true;

      synchronized(once) {
	auto pid = this in once._m_ids_by_stream;
	if(pid !is null) {
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
    synchronized(this) {
      m_uvm_tr_stream_cfg m_cfg;
      uvm_tr_database m_db;
      if(db is null) {
	uvm_error("UVM/REC_STR/NULL_DB",
		  format("Illegal attempt to set DB for '%s' to '<null>'",
			 this.get_full_name()));
	return;
      }

      if(_m_cfg_dap.try_get(m_cfg)) {
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

  // Function: is_open
  // Returns true if this ~uvm_tr_stream~ was opened on the database,
  // but has not yet been closed.
  //
  bool is_open() {
    synchronized(this) {
      return _m_is_opened;
    }
  }

  // Function: is_closed
  // Returns true if this ~uvm_tr_stream~ was closed on the database,
  // but has not yet been freed.
  //
  bool is_closed() {
    synchronized(this) {
      return _m_is_closed;
    }
  }

  // Group: Transaction Recorder API
  //
  // New recorders can be opened prior to the stream being ~closed~.
  //
  // Once a stream has been closed, requests to open a new recorder
  // will be ignored (<open_recorder> will return ~null~).
  //

  // Function: open_recorder
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
  uvm_recorder open_recorder(string name,
			     SimTime open_time = 0,
			     string type_name="") {
    synchronized(this) {
      uvm_recorder result;
      SimTime m_time = (open_time == 0) ? getRootEntity.getSimTime : open_time;

      // Check to make sure we're open
      if (!is_open()) {
	return null;
      }
      else {
	Process p = Process.self;
	Random s;

	if (p !is null) {
	  s = p.getRandState();
	}

	result = do_open_recorder(name, m_time, type_name);

	if (result !is null) {
	  _m_records[result] = true;
	  result.m_do_open(this, m_time, type_name);
	}
	if (p !is null) {
	  p.setRandState(s);
	}
      }
      return result;
    }
  }

  // Function- m_free_recorder
  // Removes recorder from the internal array
  void m_free_recorder(uvm_recorder recorder) {
    synchronized(this) {
      if(recorder in _m_records) {
	_m_records.remove(recorder);
      }
    }
  }

  // Function: get_recorders
  // Provides a queue of all transactions within the stream.
  //
  // Parameters:
  // q - A reference to the queue of <uvm_recorder>s
  //
  // The <get_recorders> method returns the size of the queue,
  // such that the user can conditionally process the elements.
  //
  // | uvm_recorder tr_q[$];
  // | if (my_stream.get_recorders(tr_q)) begin
  // |   // Process the queue...
  // | end
  //
  uint get_recorders(/*ref*/ out uvm_recorder[] q) {
    synchronized(this) {
      // Clear out the queue first...
      // q.delete();
      // Fill in the values
      foreach (idx, unused; _m_records) {
	q ~= idx;
      }
      // Finally return the size of the queue
      return cast(uint) q.length;
    }
  }

  // Group: Handles


  // Function: get_handle
  // Returns a unique ID for this stream.
  //
  // A value of ~0~ indicates that the recorder has been ~freed~,
  // and no longer has a valid ID.
  //
  int get_handle() {
    int handle;
    synchronized(this) {
      if(!is_open() && !is_closed()) {
	return 0;
      }
      else {
	handle = get_inst_id();	// call to uvm_object.get_inst_id
      }
    }

    // Check for the weird case where our handle changed.
    synchronized(once) {
      auto phandle = this in once._m_ids_by_stream;
      if (phandle !is null && *phandle !is handle) {
    	once._m_streams_by_id.remove(*phandle);
      }

      once._m_streams_by_id[handle] = this;
      once._m_ids_by_stream[this] = handle;

    }

    return handle;
  }

  // Function- m_get_handle
  // Provided to allow implementation-specific handles which are not
  // identical to the built-in handles.
  //
  // This is an implementation detail of the UVM library, which allows
  // for vendors to (optionally) put vendor-specific methods into the library.
  int m_get_handle() {
    return get_handle();
  }

  // Function: get_stream_from_handle
  // Static accessor, returns a stream reference for a given unique id.
  //
  // If no stream exists with the given ~id~, or if the
  // stream with that ~id~ has been freed, then ~null~ is
  // returned.
  //
  static uvm_tr_stream get_stream_from_handle(int id) {
    if(id == 0) {
      return null;
    }
    synchronized(once) {
      auto pstream = id in once._m_streams_by_id;
      if(// $isunknown(id) ||
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
    synchronized(once) {
      uvm_tr_stream stream;
      auto pstream = id in once._m_streams_by_id;
      if(// !$isunknown(id) &&
    	 pstream !is null) {
    	stream = *pstream;
      }

      if (stream !is null) {
    	once._m_streams_by_id.remove(id);
    	once._m_ids_by_stream.remove(stream);
      }
    }
  }

  // Group: Implementation Agnostic API
  //

  // Function: do_open
  // Callback triggered via <uvm_tr_database::open_stream>.
  //
  // Parameters:
  // db - Database which the stream belongs to
  // hscope - Optional scope
  // stream_type_name - Optional type name for the stream
  //
  // The ~do_open~ callback can be used to initialize any internal
  // state within the stream, as well as providing a location to
  // record any initial information about the stream.
  protected void do_open(uvm_tr_database db,
			 string hscope,
			 string stream_type_name) {}

  // Function: do_close
  // Callback triggered via <close>.
  //
  // The ~do_close~ callback can be used to set internal state
  // within the stream, as well as providing a location to
  // record any closing information.
  protected void do_close() {}

  // Function: do_free
  // Callback triggered via <free>.
  //
  // The ~do_free~ callback can be used to release the internal
  // state within the stream, as well as providing a location
  // to record any "freeing" information.
  protected void do_free() {}

  // Function: do_open_recorder
  // Marks the beginning of a new record in the stream.
  //
  // Backend implementation of <open_recorder>
  protected uvm_recorder do_open_recorder(string name,
					  SimTime open_time,
					  string type_name) {
    return null;
  }
}

//------------------------------------------------------------------------------
//
// CLASS: uvm_text_tr_stream
//
// The ~uvm_text_tr_stream~ is the default stream implementation for the
// <uvm_text_tr_database>.
//
//

class uvm_text_tr_stream: uvm_tr_stream
{

  // Variable- m_text_db
  // Internal reference to the text-based backend
  private uvm_text_tr_database _m_text_db;

  mixin uvm_object_essentials;

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_text_tr_stream") {
    super(name);
  }

  // Group: Implementation Agnostic API

  // Function: do_open
  // Callback triggered via <uvm_tr_database::open_stream>.
  //
  override protected void do_open(uvm_tr_database db,
			 string hscope,
			 string stream_type_name) {
    synchronized(this) {
      _m_text_db = cast(uvm_text_tr_database) db;
      assert(_m_text_db !is null);
      if(_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "  CREATE_STREAM @%s {NAME:%s T:%s SCOPE:%s STREAM:%s}",
		  getRootEntity.getSimTime,
		  this.get_name(),
		  stream_type_name,
		  hscope,
		  this.get_handle());
      }
    }
  }

  // Function: do_close
  // Callback triggered via <uvm_tr_stream::close>.
  override protected void do_close() {
    synchronized(this) {
      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "  CLOSE_STREAM @%s {NAME:%s T:%s SCOPE:%s STREAM:%s}",
		  getRootEntity.getSimTime,
		  this.get_name(),
		  this.get_stream_type_name(),
		  this.get_scope(),
		  this.get_handle());
      }
    }
  }

  // Function: do_free
  // Callback triggered via <uvm_tr_stream::free>.
  //
  override protected void do_free() {
    synchronized(this) {
      if (_m_text_db.open_db()) {
	vfdisplay(_m_text_db.m_file,
		  "  FREE_STREAM @%s {NAME:%s T:%s SCOPE:%s STREAM:%s}",
		  getRootEntity.getSimTime,
		  this.get_name(),
		  this.get_stream_type_name(),
		  this.get_scope(),
		  this.get_handle());
      }
      _m_text_db = null;
      return;
    }
  }

  // Function: do_open_recorder
  // Marks the beginning of a new record in the stream
  //
  // Text-backend specific implementation.
  override protected uvm_recorder do_open_recorder(string name,
					  SimTime open_time,
					  string type_name) {
    synchronized(this) {
      if(_m_text_db.open_db()) {
	return uvm_text_recorder.type_id.create(name);
      }
      return null;
    }
  }
}
