//
// -------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2014 Cisco Systems, Inc.
// Copyright 2010-2020 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2004-2018 Synopsys, Inc.
//    All Rights Reserved Worldwide
//
//    Licensed under the Apache License, Version 2.0 (the
//    "License"); you may not use this file except in
//    compliance with the License.  You may obtain a copy of
//    the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in
//    writing, software distributed under the License is
//    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//    CONDITIONS OF ANY KIND, either express or implied.  See
//    the License for the specific language governing
//    permissions and limitations under the License.
// -------------------------------------------------------------
//

module uvm.reg.uvm_reg_cbs;

import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_mem: uvm_mem;
import uvm.reg.uvm_reg_field: uvm_reg_field;
/// import uvm.reg.uvm_reg_sequence;
import uvm.reg.uvm_reg_backdoor: uvm_reg_backdoor;
import uvm.reg.uvm_reg_model;


import uvm.meta.misc;
import uvm.base.uvm_callback: uvm_callback, uvm_callback_iter, uvm_callbacks;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_globals: uvm_error;
// import uvm.base.uvm_entity;
import uvm.base.uvm_scope: uvm_scope_base;

import esdl.rand;

//------------------------------------------------------------------------------
// Title -- NODOCS -- Register Callbacks
//
// This section defines the base class used for all register callback
// extensions. It also includes pre-defined callback extensions for use on
// read-only and write-only registers.
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_cbs
//
// Facade class for field, register, memory and backdoor
// access callback methods.
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 18.11.1
class uvm_reg_cbs: uvm_callback
{

  mixin uvm_object_utils;
  
  // @uvm-ieee 1800.2-2020 auto 18.11.2.1
  this(string name = "uvm_reg_cbs") {
    super(name);
  }


  // @uvm-ieee 1800.2-2020 auto 18.11.2.2
  void pre_write(uvm_reg_item rw) { }


  // @uvm-ieee 1800.2-2020 auto 18.11.2.3
  void post_write(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2020 auto 18.11.2.4
  void pre_read(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2020 auto 18.11.2.5
  void post_read(uvm_reg_item rw) { }

  // @uvm-ieee 1800.2-2020 auto 18.11.2.6
  void post_predict(in  uvm_reg_field  fld,
		    in  uvm_reg_data_t previous,
		    ref uvm_reg_data_t value,
		    in  uvm_predict_e  kind,
		    in  uvm_door_e     path,
		    in  uvm_reg_map    map) { }


  // @uvm-ieee 1800.2-2020 auto 18.11.2.7
  void encode(ref uvm_reg_data_t[] data) { }


  // @uvm-ieee 1800.2-2020 auto 18.11.2.8
  // FIXME SV version has ref and the callback is supposed to modify the data
  // Since this can not be done safely in multicore, we have to find
  // alternative ways
  void decode(ref uvm_reg_data_t[] data) { }

}

//------------------
// Section -- NODOCS -- Typedefs
//------------------


// Type -- NODOCS -- uvm_reg_cb
//
// Convenience callback type declaration for registers
//
// Use this declaration to register register callbacks rather than
// the more verbose parameterized class
//

alias uvm_reg_cb = uvm_callbacks!(uvm_reg, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.1*/ ;


// Type -- NODOCS -- uvm_reg_cb_iter
//
// Convenience callback iterator type declaration for registers
//
// Use this declaration to iterate over registered register callbacks
// rather than the more verbose parameterized class
//

alias uvm_reg_cb_iter = uvm_callback_iter!(uvm_reg, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.2*/ ;


// Type -- NODOCS -- uvm_reg_bd_cb
//
// Convenience callback type declaration for backdoor
//
// Use this declaration to register register backdoor callbacks rather than
// the more verbose parameterized class
//

alias uvm_reg_bd_cb = uvm_callbacks!(uvm_reg_backdoor, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.3*/ ;


// Type -- NODOCS -- uvm_reg_bd_cb_iter
// Convenience callback iterator type declaration for backdoor
//
// Use this declaration to iterate over registered register backdoor callbacks
// rather than the more verbose parameterized class
//
alias uvm_reg_bd_cb_iter = uvm_callback_iter!(uvm_reg_backdoor, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.4*/  ;

// Type -- NODOCS -- uvm_mem_cb
//
// Convenience callback type declaration for memories
//
// Use this declaration to register memory callbacks rather than
// the more verbose parameterized class
//
alias uvm_mem_cb = uvm_callbacks!(uvm_mem, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.5*/  ;

// Type -- NODOCS -- uvm_mem_cb_iter
//
// Convenience callback iterator type declaration for memories
//
// Use this declaration to iterate over registered memory callbacks
// rather than the more verbose parameterized class
//
alias uvm_mem_cb_iter = uvm_callback_iter!(uvm_mem, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.6*/  ;


// Type -- NODOCS -- uvm_reg_field_cb
//
// Convenience callback type declaration for fields
//
// Use this declaration to register field callbacks rather than
// the more verbose parameterized class
//
alias uvm_reg_field_cb = uvm_callbacks!(uvm_reg_field, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.7*/ ;


// Type -- NODOCS -- uvm_reg_field_cb_iter
//
// Convenience callback iterator type declaration for fields
//
// Use this declaration to iterate over registered field callbacks
// rather than the more verbose parameterized class
//
alias uvm_reg_field_cb_iter = uvm_callback_iter!(uvm_reg_field, uvm_reg_cbs)  /* @uvm-ieee 1800.2-2020 auto D.4.5.8*/ ;


//-----------------------------
// Group -- NODOCS -- Predefined Extensions
//-----------------------------

//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_read_only_cbs
//
// Pre-defined register callback method for read-only registers
// that will issue an error if a write() operation is attempted.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 18.11.4.1
class uvm_reg_read_only_cbs: uvm_reg_cbs
{
  // SEE MANTIS 6040. This is supposed to be Virtual, but cannot since an instance is 
  // created.  leaving NON virtual for now. 

  this(string name = "uvm_reg_read_only_cbs") {
    super(name);
  }

  mixin uvm_object_essentials;


  // @uvm-ieee 1800.2-2020 auto 18.11.4.2.1
  // task
  override void pre_write(uvm_reg_item rw) {
    string name = rw.get_element().get_full_name();

    if (rw.get_status() != UVM_IS_OK) return;

    if (rw.get_element_kind() == UVM_FIELD) {
      uvm_reg_field fld = cast(uvm_reg_field) rw.get_element();
      assert(fld !is null);
      uvm_reg rg = fld.get_parent();
      name = rg.get_full_name();
    }

    uvm_error("UVM/REG/READONLY", name ~
	      " is read-only. Cannot call write() method.");

    rw.set_status(UVM_NOT_OK);
  }


  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    private uvm_reg_read_only_cbs _m_me;
    this() {
      // SV version does lazy initialization
      // EUVM takes another approach so that we can make this variable
      // effectively immutable
      synchronized(this) {
	_m_me = new uvm_reg_read_only_cbs();
      }
    }
  };
  mixin(uvm_scope_sync_string);

  private static uvm_reg_read_only_cbs get() {
    // synchronized(_uvm_scope_inst) {
    //   if (m_me is null) m_me = new uvm_reg_read_only_cbs();
    //   return m_me;
    // }

    // EUVM initializes this once variable in the once constructor
    return m_me;
  }


  // @uvm-ieee 1800.2-2020 auto 18.11.4.2.2
  static void add(uvm_reg rg) {
    synchronized(_uvm_scope_inst) {
      uvm_reg_cb.add(rg, get());
      uvm_reg_field[] flds;
      rg.get_fields(flds);
      foreach (fld; flds) {
	uvm_reg_field_cb.add(fld, get());
      }
    }
  }

  // Function -- NODOCS -- remove
  //
  // Remove this callback from the specified register and its contained fields.
  //
  // @uvm-ieee 1800.2-2020 auto 18.11.4.2.3
  static void remove(uvm_reg rg) {
    uvm_reg_cb_iter cbs = new uvm_reg_cb_iter(rg);

    cbs.first();
    while (cbs.get_cb() !is get()) {
      if (cbs.get_cb() is null)
	return;
      cbs.next();
    }
    uvm_reg_cb.remove(rg, get());
    uvm_reg_field[] flds;
    rg.get_fields(flds);
    foreach (fld; flds) {
      uvm_reg_field_cb.remove(fld, get());
    }
  }
}

//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_write_only_cbs
//
// Pre-defined register callback method for write-only registers
// that will issue an error if a read() operation is attempted.
//
//------------------------------------------------------------------------------


// @uvm-ieee 1800.2-2020 auto 18.11.5.1
class uvm_reg_write_only_cbs: uvm_reg_cbs
{
  // SEE MANTIS 6040. This is supposed to be Virtual, but cannot since an instance is 
  // created.  leaving NON virtual for now. 

  // @uvm-ieee 1800.2-2020 auto 18.1.2.1
  this(string name = "uvm_reg_write_only_cbs") {
    super(name);
  }

  mixin uvm_object_essentials;

  // @uvm-ieee 1800.2-2020 auto 18.11.5.2.1
  // task
  override void pre_read(uvm_reg_item rw) {
    string name = rw.get_element().get_full_name();

    if (rw.get_status() != UVM_IS_OK)
      return;

    if (rw.get_element_kind() == UVM_FIELD) {
      uvm_reg_field fld = cast(uvm_reg_field) rw.get_element();
      uvm_reg rg = fld.get_parent();
      name = rg.get_full_name();
    }

    uvm_error("UVM/REG/WRTEONLY",
	      name ~ " is write-only. Cannot call read() method.");
    rw.set_status(UVM_NOT_OK);
  }


  static class uvm_scope: uvm_scope_base
  {
    @uvm_immutable_sync
    private uvm_reg_write_only_cbs _m_me;
    this() {
      // SV version does lazy initialization
      // EUVM takes another approach so that we can make this variable
      // effectively immutable
      synchronized(this) {
	_m_me = new uvm_reg_write_only_cbs();
      }
    }
  }
  mixin(uvm_scope_sync_string);

  private static uvm_reg_write_only_cbs get() {
    // if (m_me == null) m_me = new;
    //   return m_me;

    // vlang initializes this uvm_scope variable in the uvm_scope constructor
    return m_me;
  }

  // @uvm-ieee 1800.2-2020 auto 18.11.5.2.2
  static void add(uvm_reg rg) {
    synchronized(_uvm_scope_inst) {
      uvm_reg_cb.add(rg, get());
      uvm_reg_field[] flds;
      rg.get_fields(flds);
      foreach (fld; flds) {
	uvm_reg_field_cb.add(fld, get());
      }
    }
  }


  // @uvm-ieee 1800.2-2020 auto 18.11.5.2.3
  static void remove(uvm_reg rg) {
    uvm_reg_cb_iter cbs = new uvm_reg_cb_iter(rg);

    cbs.first();
    while (cbs.get_cb() !is get()) {
      if (cbs.get_cb() is null)
	return;
      cbs.next();
    }
    uvm_reg_cb.remove(rg, get());
    uvm_reg_field[] flds;
    rg.get_fields(flds);
    foreach (fld; flds) {
      uvm_reg_field_cb.remove(fld, get());
    }
  }
}
