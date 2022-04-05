//
//-----------------------------------------------------------------------------
// Copyright 2016-2021 Coverify Systems Technology
// Copyright 2015 Analog Devices, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2013-2018 NVIDIA Corporation
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

module uvm.base.uvm_text_tr_database;


import uvm.base.uvm_tr_database: uvm_tr_database;
import uvm.base.uvm_tr_stream: uvm_tr_stream;
import uvm.base.uvm_text_tr_stream: uvm_text_tr_stream;
import uvm.base.uvm_links: uvm_link_base, uvm_parent_child_link,
  uvm_related_link;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_defines;


import uvm.meta.mcd;
import uvm.meta.misc;
import esdl.base.core: getRootEntity;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_text_tr_database
//
// The ~uvm_text_tr_database~ is the default implementation for the
// <uvm_tr_database>.  It provides the ability to store recording information
// into a textual log file.
//
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

class uvm_text_tr_database: uvm_tr_database
{
  import uvm.dap.uvm_simple_lock_dap: uvm_simple_lock_dap;
  import uvm.base.uvm_object_globals: UVM_FILE;
  mixin (uvm_sync_string);

  // Variable- m_filename_dap
  // Data Access Protected Filename
  private uvm_simple_lock_dap!string _m_filename_dap;


  // Variable- m_file
  @uvm_public_sync
  private UVM_FILE _m_file;

  mixin uvm_object_essentials;

  // Function -- NODOCS -- new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  this(string name="unnamed-uvm_text_tr_database") {
    synchronized (this) {
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
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  override protected bool do_open_db() {
    synchronized (this) {
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
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  override protected bool do_close_db() {
    synchronized (this) {
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
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
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
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  override protected void do_establish_link(uvm_link_base link) {
    import uvm.base.uvm_recorder;
    synchronized (this) {
      uvm_object lhs = link.get_lhs();
      uvm_object rhs = link.get_rhs();

      uvm_recorder r_lhs = cast (uvm_recorder) lhs;
      uvm_recorder r_rhs = cast (uvm_recorder) rhs;

      if ((r_lhs is null) ||
	  (r_rhs is null)) {
	return;
      }
      else {
	auto pc_link = cast (uvm_parent_child_link) link;
	if (pc_link !is null) {
	  vfdisplay(_m_file, "  LINK @%s {TXH1:%s TXH2:%0d RELATION=%s}",
		    getRootEntity.getSimTime(),
		    r_lhs.get_handle(),
		    r_rhs.get_handle(),
		    "child");

	}
	else {
	  auto re_link = cast (uvm_related_link) link;
	  if (re_link !is null) {
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
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
  void set_file_name(string filename) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      if (filename == "") {
	uvm_warning("UVM/TXT_DB/EMPTY_NAME",
		    "Ignoring attempt to set file name to ''!");
	return;
      }

      if (!_m_filename_dap.try_set(filename)) {
	uvm_warning("UVM/TXT_DB/SET_AFTER_OPEN",
		    "Ignoring attempt to change file name after opening the db!");
	return;
      }
    }
  }
}
