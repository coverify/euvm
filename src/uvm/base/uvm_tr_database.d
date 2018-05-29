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

module uvm.base.uvm_tr_database;

//------------------------------------------------------------------------------
// File: Transaction Recording Databases
//
// The UVM "Transaction Recording Database" classes are an abstract representation
// of the backend tool which is recording information for the user.  Usually this
// tool would be dumping information such that it can be viewed with the ~waves~
// of the DUT.
//

import uvm.base.uvm_tr_stream: uvm_tr_stream, uvm_text_tr_stream;
import uvm.base.uvm_links: uvm_link_base, uvm_parent_child_link,
  uvm_related_link;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_defines;


import uvm.meta.mcd;
import uvm.meta.misc;

import esdl.base.core;

import std.string: format;
import std.random;


//------------------------------------------------------------------------------
//
// CLASS: uvm_tr_database
//
// The ~uvm_tr_database~ class is intended to hide the underlying database implementation
// from the end user, as these details are often vendor or tool-specific.
//
// The ~uvm_tr_database~ class is pure virtual, and must be extended with an
// implementation.  A default text-based implementation is provided via the
// <uvm_text_tr_database> class.
//

abstract class uvm_tr_database: uvm_object
{

  // Variable- m_is_opened
  // Tracks the opened state of the database
  private bool _m_is_opened;

  // Variable- m_streams
  // Used for tracking streams which are between the open and closed states
  private bool[uvm_tr_stream] _m_streams;

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_tr_database") {
    super(name);
  }

  // Group: Database API

  // Function: open_db
  // Open the backend connection to the database.
  //
  // If the database is already open, then this
  // method will return 1.
  //
  // Otherwise, the method will call <do_open_db>,
  // and return the result.
  bool open_db() {
    synchronized(this) {
      if (!_m_is_opened) {
	_m_is_opened = do_open_db();
      }
      return _m_is_opened;
    }
  }

  // Function: close_db
  // Closes the backend connection to the database.
  //
  // Closing a database implicitly closes and
  // frees all <uvm_tr_streams> within the database.
  //
  // If the database is already closed, then this
  // method will return 1.
  //
  // Otherwise, this method will trigger a <do_close_db>
  // call, and return the result.
  bool close_db() {
    synchronized(this) {
      if(_m_is_opened) {
	if(do_close_db()) {
	  _m_is_opened = false;
	}
      }
      return (_m_is_opened == false);
    }
  }

  // Function: is_open
  // Returns the open/closed status of the database.
  //
  // This method returns 1 if the database has been
  // successfully opened, but not yet closed.
  //
  bool is_open() {
    synchronized(this) {
      return _m_is_opened;
    }
  }

  // Group: Stream API

  // Function: open_stream
  // Provides a reference to a ~stream~ within the
  // database.
  //
  // Parameters:
  //   name - A string name for the stream.  This is the name associated
  //          with the stream in the database.
  //   hscope - An optional scope for the stream.
  //   type_name - An optional name describing the type of records which
  //               will be created in this stream.
  //
  // The method returns a reference to a <uvm_tr_stream>
  // object if successful, ~null~ otherwise.
  //
  // This method will trigger a <do_open_stream> call, and if a
  // non ~null~ stream is returned, then <uvm_tr_stream::do_open>
  // will be called.
  //
  // Streams can only be opened if the database is
  // open (per <is_open>).  Otherwise the request will
  // be ignored, and ~null~ will be returned.
  uvm_tr_stream open_stream(string name,
			    string hscope="",
			    string type_name="") {
    synchronized(this) {
      uvm_tr_stream open_stream_;
      if (!open_db()) {
	return null;
      }
      else {
	Process p = Process.self;
	Random s;

	if (p !is null) {
	  p.getRandState(s);
	}

	open_stream_ = do_open_stream(name, hscope, type_name);


	if (open_stream_ !is null) {
	  _m_streams[open_stream_] = true;
	  open_stream_.m_do_open(this, hscope, type_name);
	}

	if (p !is null) {
	  p.setRandState(s);
	}
      }
      return open_stream_;
    }
  }

  // Function- m_free_stream
  // Removes stream from the internal array
  void m_free_stream(uvm_tr_stream stream) {
    synchronized(this) {
      if(stream in _m_streams) {
	_m_streams.remove(stream);
      }
    }
  }

  // Function: get_streams
  // Provides a queue of all streams within the database.
  //
  // Parameters:
  // q - A reference to a queue of <uvm_tr_stream>s
  //
  // The ~get_streams~ method returns the size of the queue,
  // such that the user can conditionally process the elements.
  //
  // | uvm_tr_stream stream_q[$];
  // | if (my_db.get_streams(stream_q)) begin
  // |   // Process the queue...
  // | end
  uint get_streams(out uvm_tr_stream[] q) {
    synchronized(this) {
      // Clear out the queue first...
      // q.delete(); // in vlang we just set the argument as out
      // Then fill in the values
      foreach (stream, unused; _m_streams) {
	q ~= stream;
      }
      return cast(uint) q.length;
    }
  }

  // Group: Link API

  // Function: establish_link
  // Establishes a ~link~ between two elements in the database
  //
  // Links are only supported between ~streams~ and ~records~
  // within a single database.
  //
  // This method will trigger a <do_establish_link> call.
  void establish_link(uvm_link_base link) {
    import uvm.base.uvm_recorder;
    import uvm.base.uvm_globals;
    synchronized(this) {
      uvm_object lhs = link.get_lhs();
      uvm_object rhs = link.get_rhs();
      uvm_tr_database db;

      if(lhs is null) {
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    "left hand side '<null>' is not supported" ~
		    " in links for 'uvm_tr_database'");
	return;
      }
      if(rhs is null) {
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    "right hand side '<null>' is not supported" ~
		    " in links for 'uvm_tr_database'");
	return;
      }
      uvm_tr_stream s_lhs = cast(uvm_tr_stream) lhs;
      uvm_recorder r_lhs = cast(uvm_recorder) lhs;
      if (s_lhs is null && r_lhs is null) {
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    format("left hand side of type '%s' not supported" ~
			   " in links for 'uvm_tr_database'",
			   lhs.get_type_name()));
	return;
      }
      uvm_tr_stream s_rhs = cast(uvm_tr_stream) rhs;
      uvm_recorder r_rhs = cast(uvm_recorder) rhs;
      if (s_rhs is null && r_rhs is null) {
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    format("right hand side of type '%s' not supported" ~
			   " in links for 'uvm_record_datbasae'",
			   rhs.get_type_name()));
	return;
      }

      if (r_lhs !is null) {
      	s_lhs = r_lhs.get_stream();
      }
      if (r_rhs !is null) {
      	s_rhs = r_rhs.get_stream();
      }

      if ((s_lhs !is null) && (s_lhs.get_db() !is this)) {
	db = s_lhs.get_db();
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    format("attempt to link stream from '%s' into '%s'",
			   db.get_name(), this.get_name()));
	return;
      }
      if ((s_rhs !is null) && (s_rhs.get_db() !is this)) {
	db = s_rhs.get_db();
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    format("attempt to link stream from '%s' into '%s'",
			   db.get_name(), this.get_name()));
	return;
      }

      do_establish_link(link);
    }
  }

  // Group: Implementation Agnostic API
  //

  // Function: do_open_db
  // Backend implementation of <open_db>
  protected abstract bool do_open_db();

  // Function: do_close_db
  // Backend implementation of <close_db>
  protected abstract bool do_close_db();

  // Function: do_open_stream
  // Backend implementation of <open_stream>
  protected abstract uvm_tr_stream do_open_stream(string name,
						  string hscope,
						  string type_name);

  // Function: do_establish_link
  // Backend implementation of <establish_link>
  protected abstract void do_establish_link(uvm_link_base link);

}

//------------------------------------------------------------------------------
//
// CLASS: uvm_text_tr_database
//
// The ~uvm_text_tr_database~ is the default implementation for the
// <uvm_tr_database>.  It provides the ability to store recording information
// into a textual log file.
//
//

class uvm_text_tr_database: uvm_tr_database
{
  import uvm.dap.uvm_simple_lock_dap: uvm_simple_lock_dap;
  import uvm.base.uvm_object_globals: UVM_FILE;
  mixin(uvm_sync_string);

  // Variable- m_filename_dap
  // Data Access Protected Filename
  private uvm_simple_lock_dap!string _m_filename_dap;


  // Variable- m_file
  @uvm_public_sync
  private UVM_FILE _m_file;

  mixin uvm_object_essentials;

  // Function: new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_text_tr_database") {
    synchronized(this) {
      super(name);

      _m_filename_dap = new uvm_simple_lock_dap!string("filename_dap");
      _m_filename_dap.set("tr_db.log");
    }
  }

  // Group: Implementation Agnostic API

  // Function: do_open_db
  // Open the backend connection to the database.
  //
  // Text-Backend implementation of <uvm_tr_database::open_db>.
  //
  // The text-backend will open a text file to dump all records in to.  The name
  // of this text file is controlled via <set_file_name>.
  //
  // This will also lock the ~file_name~, so that it cannot be
  // modified while the connection is open.
  override protected bool do_open_db() {
    synchronized(this) {
      if (_m_file == 0) {
	_m_file = vfopen(_m_filename_dap.get(), "a+");
	if (_m_file != 0) {
	  _m_filename_dap.lock();
	}
      }
      return (_m_file != 0);
    }
  }

  // Function: do_close_db
  // Close the backend connection to the database.
  //
  // Text-Backend implementation of <uvm_tr_database::close_db>.
  //
  // The text-backend will close the text file used to dump all records in to,
  // if it is currently opened.
  //
  // This unlocks the ~file_name~, allowing it to be modified again.
  override protected bool do_close_db() {
    synchronized(this) {
      if (_m_file != 0) {
	// fork // Needed because $fclose is a task
	vfclose(_m_file);
	// join_none
	_m_filename_dap.unlock();
      }
      return true;
    }
  }

  // Function: do_open_stream
  // Provides a reference to a ~stream~ within the
  // database.
  //
  // Text-Backend implementation of <uvm_tr_database::open_stream>
  override protected uvm_tr_stream do_open_stream(string name,
						  string hscope,
						  string type_name) {
    uvm_text_tr_stream m_stream = uvm_text_tr_stream.type_id.create(name);
    return m_stream;
  }

  // Function: do_establish_link
  // Establishes a ~link~ between two elements in the database
  //
  // Text-Backend implementation of <uvm_tr_database::establish_link>.
  override protected void do_establish_link(uvm_link_base link) {
    import uvm.base.uvm_recorder;
    synchronized(this) {
      uvm_object lhs = link.get_lhs();
      uvm_object rhs = link.get_rhs();

      uvm_recorder r_lhs = cast(uvm_recorder) lhs;
      uvm_recorder r_rhs = cast(uvm_recorder) rhs;

      if ((r_lhs is null) ||
	  (r_rhs is null)) {
	return;
      }
      else {
	auto pc_link = cast(uvm_parent_child_link) link;
	if(pc_link !is null) {
	  vfdisplay(_m_file, "  LINK @%s {TXH1:%s TXH2:%0d RELATION=%s}",
		    getRootEntity.getSimTime(),
		    r_lhs.get_handle(),
		    r_rhs.get_handle(),
		    "child");

	}
	else {
	  auto re_link = cast(uvm_related_link) link;
	  if(re_link !is null) {
	    vfdisplay(_m_file,"  LINK @%s {TXH1:%s TXH2:%s RELATION=%s}",
		     getRootEntity.getSimTime,
		     r_lhs.get_handle(),
		     r_rhs.get_handle(),
		     "");
	  }
	}
      }
    }
  }

  // Group: Implementation Specific API

  // Function: set_file_name
  // Sets the file name which will be used for output.
  //
  // The ~set_file_name~ method can only be called prior to ~open_db~.
  //
  // By default, the database will use a file named "tr_db.log".
  void set_file_name(string filename) {
    import uvm.base.uvm_globals;
    synchronized(this) {
      if(filename == "") {
	uvm_warning("UVM/TXT_DB/EMPTY_NAME",
		    "Ignoring attempt to set file name to ''!");
	return;
      }

      if(!_m_filename_dap.try_set(filename)) {
	uvm_warning("UVM/TXT_DB/SET_AFTER_OPEN",
		    "Ignoring attempt to change file name after opening the db!");
	return;
      }
    }
  }
}
