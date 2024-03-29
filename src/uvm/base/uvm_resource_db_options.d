//----------------------------------------------------------------------
// Copyright 2019-2021 Coverify Systems Technology
// Copyright 2018 Cadence Design Systems, Inc.
// Copyright 2017 Cisco Systems, Inc.
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
//----------------------------------------------------------------------


module uvm.base.uvm_resource_db_options;
import uvm.base.uvm_scope;
import uvm.meta.misc;

//----------------------------------------------------------------------
// Title -- NODOCS -- UVM Resource Database
//
// Topic: Intro
//
// The <uvm_resource_db> class provides a convenience interface for
// the resources facility.  In many cases basic operations such as
// creating and setting a resource or getting a resource could take
// multiple lines of code using the interfaces in <uvm_resource_base> or
// <uvm_resource#(T)>.  The convenience layer in <uvm_resource_db>
// reduces many of those operations to a single line of code.
//
// If the run-time ~+UVM_RESOURCE_DB_TRACE~ command line option is
// specified, all resource DB accesses (read and write) are displayed.
//----------------------------------------------------------------------



//----------------------------------------------------------------------
// Class: uvm_resource_db_options
//
// This class contains static functions for manipulating and
// retrieving options that control the behavior of the 
// resources DB facility.
//
// @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2
//----------------------------------------------------------------------
class uvm_resource_db_options
{
   
  static class uvm_scope: uvm_scope_base
  {
    @uvm_private_sync
    bool _ready;
    @uvm_private_sync
    bool _tracing;
  }
    
  mixin (uvm_scope_sync_string);


  // Function: turn_on_tracing
  //
  // Turn tracing on for the resource database. This causes all
  // reads and writes to the database to display information about
  // the accesses. Tracing is off by default.
  //
  // This method is implicitly called by the ~+UVM_RESOURCE_DB_TRACE~.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  static void turn_on_tracing() {
    synchronized (_uvm_scope_inst) {
      if (! _uvm_scope_inst._ready) init();
      _uvm_scope_inst._tracing = true;
    }
  }

  // Function: turn_off_tracing
  //
  // Turn tracing off for the resource database.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  static void turn_off_tracing() {
    synchronized (_uvm_scope_inst) {
      if (! _uvm_scope_inst._ready) init();
      _uvm_scope_inst._tracing = false;
    }
  }

  // Function: is_tracing
  //
  // Returns 1 if the tracing facility is on and 0 if it is off.
  //
  // @uvm-accellera The details of this API are specific to the Accellera implementation, and are not being considered for contribution to 1800.2


  static bool is_tracing() {
    synchronized (_uvm_scope_inst) {
      if (! _uvm_scope_inst._ready) init();
      return _uvm_scope_inst._tracing;
    }
  }

  static private void init() {
    import uvm.base.uvm_cmdline_processor;
    synchronized (_uvm_scope_inst) {
      uvm_cmdline_processor clp;
      string[] trace_args;
     
      clp = uvm_cmdline_processor.get_inst();

      if (clp.get_arg_matches(`+UVM_RESOURCE_DB_TRACE`, trace_args)) {
	_uvm_scope_inst._tracing = true;
      }

      _uvm_scope_inst._ready = true;
    }
  }
}
