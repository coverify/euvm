//
// -------------------------------------------------------------
// Copyright 2021 Coverify Systems Technology
// Copyright 2020 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2004-2011 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2014-2018 NVIDIA Corporation
// Copyright 2012 Accellera Systems Initiative
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


module uvm.reg.uvm_predictor;

import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.reg.uvm_reg_model;

import uvm.base.uvm_component: uvm_component;
import uvm.base.uvm_component_defines;

import std.string: format;

//------------------------------------------------------------------------------
// TITLE -- NODOCS -- Explicit Register Predictor
//------------------------------------------------------------------------------
//
// The <uvm_reg_predictor> class defines a predictor component,
// which is used to update the register model's mirror values
// based on transactions explicitly observed on a physical bus. 
//------------------------------------------------------------------------------

class uvm_predict_s
{
   bool [uvm_reg_addr_t] _addr;
   uvm_reg_item _reg_item;
}

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_reg_predictor
//
// Updates the register model mirror based on observed bus transactions
//
// This class converts observed bus transactions of type ~BUSTYPE~ to generic
// registers transactions, determines the register being accessed based on the
// bus address, then updates the register's mirror value with the observed bus
// data, subject to the register's access mode. See <uvm_reg::predict> for details.
//
// Memories can be large, so their accesses are not predicted.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 19.3.1
class uvm_reg_predictor(BUSTYPE): uvm_component
{

  mixin uvm_component_param_utils;

  // Variable -- NODOCS -- bus_in
  //
  // Observed bus transactions of type ~BUSTYPE~ are received from this
  // port and processed.
  //
  // For each incoming transaction, the predictor will attempt to get the
  // register or memory handle corresponding to the observed bus address. 
  //
  // If there is a match, the predictor calls the register or memory's
  // predict method, passing in the observed bus data. The register or
  // memory mirror will be updated with this data, subject to its configured
  // access behavior--RW, RO, WO, etc. The predictor will also convert the
  // bus transaction to a generic <uvm_reg_item> and send it out the
  // ~reg_ap~ analysis port.
  //
  // If the register is wider than the bus, the
  // predictor will collect the multiple bus transactions needed to
  // determine the value being read or written.
  //
  uvm_analysis_imp!(write) _bus_in;


  // Variable -- NODOCS -- reg_ap
  //
  // Analysis output port that publishes <uvm_reg_item> transactions
  // converted from bus transactions received on ~bus_in~.
  uvm_analysis_port!(uvm_reg_item) _reg_ap;


  // Variable -- NODOCS -- map
  //
  // The map used to convert a bus address to the corresponding register
  // or memory handle. Must be configured before the run phase.
  // 
  uvm_reg_map _map;


  // Variable -- NODOCS -- adapter
  //
  // The adapter used to convey the parameters of a bus operation in 
  // terms of a canonical <uvm_reg_bus_op> datum.
  // The <uvm_reg_adapter> must be configured before the run phase.
  //
  uvm_reg_adapter _adapter;



  // @uvm-ieee 1800.2-2020 auto 19.3.3.1
  this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      _bus_in = new uvm_analysis_imp!(write)("bus_in", this);
      _reg_ap = new uvm_analysis_port!(uvm_reg_item)("reg_ap", this);
    }
  }

  // This method is documented in uvm_object
  // TODO:  Is it better to replace this with:
  //| `uvm_type_name_decl($sformatf("uvm_reg_predictor #(%s)", BUSTYPE::type_name())
  static string type_name() {
    static string m_type_name;
    if (m_type_name == "") {
      BUSTYPE t;
      t = BUSTYPE.type_id.create("t");
      m_type_name = "uvm_reg_predictor!(" ~ t.get_type_name() ~ ")";
    }
    return m_type_name;
  } // type_name
  
  override string get_type_name() {
    alias TYPE = typeof(this);
    return TYPE.stringof;
  }

  // @uvm-ieee 1800.2-2020 auto 19.3.3.2
  void pre_predict(uvm_reg_item rw) { }

  private uvm_predict_s[uvm_reg] _m_pending;


  // Function- write
  //
  // not a user-level method. Do not call directly. See documentation
  // for the ~bus_in~ member.
  //
  void write(BUSTYPE tr) {
    uvm_reg rg;
    uvm_reg_bus_op rw;
    if (_adapter is null) {
      uvm_fatal("REG/WRITE/NULL","write: adapter handle is null") ;

      // In case they forget to set byte_en
      rw.set_byte_en(-1);
      _adapter.bus2reg(tr, rw);
      rg = map.get_reg_by_offset(rw.get_addr(), (rw.get_kind == UVM_READ));

      // ToDo: Add memory look-up and call <uvm_mem::XsampleX()>

      if (rg !is null) {
	uvm_reg_item reg_item;
	uvm_predict_s predict_info;
 
	if (rg !in _m_pending) {
	  uvm_reg_item item = new uvm_reg_item();
	  predict_info = new uvm_predict_s();
	  item.set_element_kind(UVM_REG);
	  item.set_element(rg);
	  item.set_door(UVM_PREDICT);
	  item.set_map(map);
	  item.set_kind(rw.get_kind());
	  predict_info._reg_item = item;
	  _m_pending[rg] = predict_info;
	}

	predict_info = _m_pending[rg];
	reg_item = predict_info._reg_item;

	if (rw.get_addr() in predict_info._addr) {
	  uvm_error("REG_PREDICT_COLLISION",
		    "Collision detected for register '" ~
		    rg.get_full_name() ~ "'");
	  // TODO: what to do with subsequent collisions?
	  _m_pending.remove(rg);
	}

	uvm_reg_map local_map = rg.get_local_map(map);
	uvm_reg_map_info map_info = local_map.get_reg_map_info(rg);
	uvm_reg_indirect_data ireg = cast(uvm_reg_indirect_data) rg;
	uvm_reg ir = ireg is null ? rg : ireg.get_indirect_reg();
	bool found;

	foreach (i, addr; map_info.addr) {
	  uvm_reg_data_t reg_item_value;
	  if (rw.set_addr(addr)) {
	    found = true;
	    reg_item_value = reg_item.get_value(0);
	    reg_item_value |= rw.data << (i * map.get_n_bytes()*8);
	    reg_item.set_value(reg_item_value, 0);
	    predict_info.addr[rw.addr] = 1;
	    if (predict_info.addr.length == map_info.addr.length) {
              // We've captured the entire abstract register transaction.
	      uvm_predict_e predict_kind = 
		(reg_item.get_kind() == UVM_WRITE) ? UVM_PREDICT_WRITE : UVM_PREDICT_READ;

	      if (reg_item.get_kind() == UVM_READ &&
		  local_map.get_check_on_read() &&
		  reg_item.get_status() != UVM_NOT_OK) {
		rg.do_check(ir.get_mirrored_value(), reg_item.get_value(0), local_map);
	      }
              
	      pre_predict(reg_item);

	      ir.XsampleX(reg_item.get_value(0), rw.get_byte_en(),
			  (reg_item.get_kind() == UVM_READ), local_map);
	      uvm_reg_block blk = rg.get_parent();
	      blk.XsampleX(map_info.offset,
			   (reg_item.get_kind() == UVM_READ),
			   local_map);

              rg.do_predict(reg_item, predict_kind, rw.byte_en);
              if (reg_item.get_kind() == UVM_WRITE)
                uvm_info("REG_PREDICT", "Observed WRITE transaction to register " ~
			 ir.get_full_name() ~ ": value='h" ~
			 format("%0h",reg_item.get_value(0)) ~ " : updated value = 'h" ~
			 format("%0h",ir.get()), UVM_HIGH);
              else
                uvm_info("REG_PREDICT", "Observed READ transaction to register " ~
			 ir.get_full_name() ~ ": value='h" ~
			 format("%0h",reg_item.get_value(0)), UVM_HIGH);
              reg_ap.write(reg_item);
              _m_pending.remove(rg);
	    }
	    break;
	  }
	}
	if (!found)
	  uvm_error("REG_PREDICT_INTERNAL", "Unexpected failed address lookup for register '" ~
		    rg.get_full_name() ~ "'");
      }
      else {
	uvm_info("REG_PREDICT_NOT_FOR_ME",
		 "Observed transaction does not target a register: " ~
		 format("%p",tr), UVM_FULL);
      }
    }
  }

  
  // Function -- NODOCS -- check_phase
  //
  // Checks that no pending register transactions are still queued.

  // @uvm-ieee 1800.2-2020 auto 19.3.3.3
  override void check_phase(uvm_phase phase) {
    string str;
    super.check_phase(phase);
            
    foreach (rg, pending; _m_pending) {
      str ~= format("\n%s", rg.get_full_name());
    }
            
    if (m_pending.length > 0) {
      uvm_error("PENDING REG ITEMS",
		format("There are %0d incomplete register transactions still pending completion:%s",
		       _m_pending.length, str));

    }
  }

}
