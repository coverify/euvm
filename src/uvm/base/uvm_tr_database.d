//
//-----------------------------------------------------------------------------
// Copyright 2016-2021 Coverify Systems Technology
// Copyright 2015 Analog Devices, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2013-2020 NVIDIA Corporation
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


import uvm.base.uvm_tr_stream: uvm_tr_stream;
import uvm.base.uvm_text_tr_stream: uvm_text_tr_stream;
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
// File -- NODOCS -- Transaction Recording Databases
//
// The UVM "Transaction Recording Database" classes are an abstract representation
// of the backend tool which is recording information for the user.  Usually this
// tool would be dumping information such that it can be viewed with the ~waves~
// of the DUT.
//


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_tr_database
//
// The ~uvm_tr_database~ class is intended to hide the underlying database implementation
// from the end user, as these details are often vendor or tool-specific.
//
// The ~uvm_tr_database~ class is pure virtual, and must be extended with an
// implementation.  A default text-based implementation is provided via the
// <uvm_text_tr_database> class.
//

// @uvm-ieee 1800.2-2020 auto 7.1.1
abstract class uvm_tr_database: uvm_object
{

  // Variable- m_is_opened
  // Tracks the opened state of the database
  private bool _m_is_opened;

  // Variable- m_streams
  // Used for tracking streams which are between the open and closed states
  private bool[uvm_tr_stream] _m_streams;


   // @uvm-ieee 1800.2-2020 auto 7.1.2
  this(string name="unnamed-uvm_tr_database") {
    super(name);
  }

  // Group -- NODOCS -- Database API


  // @uvm-ieee 1800.2-2020 auto 7.1.3.1
  bool open_db() {
    synchronized (this) {
      if (!_m_is_opened) {
	_m_is_opened = do_open_db();
      }
      return _m_is_opened;
    }
  }


  // @uvm-ieee 1800.2-2020 auto 7.1.3.2
  bool close_db() {
    synchronized (this) {
      if (_m_is_opened) {
	if (do_close_db()) {
	  _m_is_opened = false;
	}
      }
      return (_m_is_opened == false);
    }
  }


  // @uvm-ieee 1800.2-2020 auto 7.1.3.3
  bool is_open() {
    synchronized (this) {
      return _m_is_opened;
    }
  }

  // Group -- NODOCS -- Stream API


  // @uvm-ieee 1800.2-2020 auto 7.1.4.1
  uvm_tr_stream open_stream(string name,
			    string hscope="",
			    string type_name="") {
    synchronized (this) {
      uvm_tr_stream open_stream_;
      if (!open_db()) {
	return null;
      }
      else {

	open_stream_ = do_open_stream(name, hscope, type_name);


	if (open_stream_ !is null) {
	  _m_streams[open_stream_] = true;
	  open_stream_.m_do_open(this, hscope, type_name);
	}

	version (PRESERVE_RANDSTATE) {
	  if (p !is null)
	    p.setRandState(s);
	}
      }
      return open_stream_;
    }
  }

  // Function- m_free_stream
  // Removes stream from the internal array
  void m_free_stream(uvm_tr_stream stream) {
    synchronized (this) {
      if (stream in _m_streams) {
	_m_streams.remove(stream);
      }
    }
  }


  // @uvm-ieee 1800.2-2020 auto 7.1.4.2
  uint get_streams(out uvm_tr_stream[] q) {
    synchronized (this) {
      // Clear out the queue first...
      // q.delete(); // in vlang we just set the argument as out
      // Then fill in the values
      foreach (stream, unused; _m_streams) {
	q ~= stream;
      }
      return cast (uint) q.length;
    }
  }

  // Group -- NODOCS -- Link API


  // @uvm-ieee 1800.2-2020 auto 7.1.5
  void establish_link(uvm_link_base link) {
    import uvm.base.uvm_recorder;
    import uvm.base.uvm_globals;
    synchronized (this) {
      uvm_object lhs = link.get_lhs();
      uvm_object rhs = link.get_rhs();
      uvm_tr_database db;

      if (lhs is null) {
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    "left hand side '<null>' is not supported" ~
		    " in links for 'uvm_tr_database'");
	return;
      }
      if (rhs is null) {
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    "right hand side '<null>' is not supported" ~
		    " in links for 'uvm_tr_database'");
	return;
      }
      uvm_tr_stream s_lhs = cast (uvm_tr_stream) lhs;
      uvm_recorder r_lhs = cast (uvm_recorder) lhs;
      if (s_lhs is null && r_lhs is null) {
	uvm_warning("UVM/TR_DB/BAD_LINK",
		    format("left hand side of type '%s' not supported" ~
			   " in links for 'uvm_tr_database'",
			   lhs.get_type_name()));
	return;
      }
      uvm_tr_stream s_rhs = cast (uvm_tr_stream) rhs;
      uvm_recorder r_rhs = cast (uvm_recorder) rhs;
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

  // Group -- NODOCS -- Implementation Agnostic API
  //


  // @uvm-ieee 1800.2-2020 auto 7.1.6.1
  protected abstract bool do_open_db();


  // @uvm-ieee 1800.2-2020 auto 7.1.6.2
  protected abstract bool do_close_db();


  // @uvm-ieee 1800.2-2020 auto 7.1.6.3
  protected abstract uvm_tr_stream do_open_stream(string name,
						  string hscope,
						  string type_name);


  // @uvm-ieee 1800.2-2020 auto 7.1.6.4
  protected abstract void do_establish_link(uvm_link_base link);

}
