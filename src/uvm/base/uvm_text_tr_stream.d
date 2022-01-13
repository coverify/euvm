//
//-----------------------------------------------------------------------------
// Copyright 2016-2021 Coverify Systems Technology
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
// Copyright 2007-2009 Mentor Graphics Corporation
// Copyright 2018 NVIDIA Corporation
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

module uvm.base.uvm_text_tr_stream;

import uvm.base.uvm_tr_stream;
import uvm.meta.mcd;
import esdl.base.core: SimTime, getRootEntity, Process;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_tr_database: uvm_tr_database;
import uvm.base.uvm_text_tr_database: uvm_text_tr_database;
import uvm.base.uvm_recorder: uvm_recorder, uvm_text_recorder;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_text_tr_stream
//
// The ~uvm_text_tr_stream~ is the default stream implementation for the
// <uvm_text_tr_database>.
//
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2

class uvm_text_tr_stream: uvm_tr_stream
{

  // Variable- m_text_db
  // Internal reference to the text-based backend
  private uvm_text_tr_database _m_text_db;

  mixin uvm_object_essentials;

  // Function -- NODOCS -- new
  // Constructor
  //
  // Parameters:
  // name - Instance name
  this(string name="unnamed-uvm_text_tr_stream") {
    super(name);
  }

  // Group -- NODOCS -- Implementation Agnostic API

  // Function -- NODOCS -- do_open
  // Callback triggered via <uvm_tr_database::open_stream>.
  //
  override protected void do_open(uvm_tr_database db,
				  string hscope,
				  string stream_type_name) {
    synchronized (this) {
      _m_text_db = cast (uvm_text_tr_database) db;
      assert (_m_text_db !is null);
      if (_m_text_db.open_db()) {
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

  // Function -- NODOCS -- do_close
  // Callback triggered via <uvm_tr_stream::close>.
  override protected void do_close() {
    synchronized (this) {
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

  // Function -- NODOCS -- do_free
  // Callback triggered via <uvm_tr_stream::free>.
  //
  override protected void do_free() {
    synchronized (this) {
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

  // Function -- NODOCS -- do_open_recorder
  // Marks the beginning of a new record in the stream
  //
  // Text-backend specific implementation.
  override protected uvm_recorder do_open_recorder(string name,
						   SimTime open_time,
						   string type_name) {
    synchronized (this) {
      if (_m_text_db.open_db()) {
	return uvm_text_recorder.type_id.create(name);
      }
      return null;
    }
  }
}
