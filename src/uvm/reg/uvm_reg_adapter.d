//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010      Mentor Graphics Corporation
//    Copyright 2014-2016 Coverify Systems Technology
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

module uvm.reg.uvm_reg_adapter;

import uvm.base.uvm_object;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_defines;

import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_adapter;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_mem;

import uvm.meta.misc;

import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequence_item;

import uvm.tlm2.uvm_tlm2_generic_payload;

import esdl.data.rand;

//------------------------------------------------------------------------------
// Title: Classes for Adapting Between Register and Bus Operations
//
// This section defines classes used to convert transaction streams between
// generic register address/data reads and writes and physical bus accesses. 
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//
// Class: uvm_reg_adapter
//
// This class defines an interface for converting between <uvm_reg_bus_op>
// and a specific bus transaction. 
//------------------------------------------------------------------------------

abstract class uvm_reg_adapter: uvm_object
{

  // Function: new
  //
  // Create a new instance of this type, giving it the optional ~name~.

  public this(string name="") {
    super(name);
  }


  mixin(uvm_sync_string);

  // Variable: supports_byte_enable
  //
  // Set this bit in extensions of this class if the bus protocol supports
  // byte enables.
   
  @uvm_public_sync
  bool _supports_byte_enable;


  // Variable: provides_responses
  //
  // Set this bit in extensions of this class if the bus driver provides
  // separate response items.

  @uvm_public_sync
  bool _provides_responses; 


  // Variable: parent_sequence
  //
  // Set this member in extensions of this class if the bus driver requires
  // bus items be executed via a particular sequence base type. The sequence
  // assigned to this member must implement do_clone().

  @uvm_public_sync  
  uvm_sequence_base _parent_sequence; 


  // Function: reg2bus
  //
  // Extensions of this class ~must~ implement this method to convert the specified
  // <uvm_reg_bus_op> to a corresponding <uvm_sequence_item> subtype that defines the bus
  // transaction.
  //
  // The method must allocate a new bus-specific <uvm_sequence_item>,
  // assign its members from
  // the corresponding members from the given generic ~rw~ bus operation, then
  // return it.

  // pure virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
  public abstract uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);


  // Function: bus2reg
  //
  // Extensions of this class ~must~ implement this method to copy members
  // of the given bus-specific ~bus_item~ to corresponding members of the provided
  // ~bus_rw~ instance. Unlike <reg2bus>, the resulting transaction
  // is not allocated from scratch. This is to accommodate applications
  // where the bus response must be returned in the original request.

  public abstract void bus2reg(uvm_sequence_item bus_item,
			       ref uvm_reg_bus_op rw);


  @uvm_private_sync
  private uvm_reg_item _m_item;

  // function: get_item
  //
  // Returns the bus-independent read/write information that corresponds to
  // the generic bus transaction currently translated to a bus-specific
  // transaction.
  // This function returns a value reference only when called in the
  // <uvm_reg_adapter::reg2bus()> method.
  // It returns null at all other times.
  // The content of the return <uvm_reg_item> instance must not be modified
  // and used strictly to obtain additional information about the operation.  
  public uvm_reg_item get_item() {
    synchronized(this) {
      return _m_item;
    }
  }
   
  public void m_set_item(uvm_reg_item item) {
    synchronized(this) {
      _m_item = item;
    }
  }

}


//------------------------------------------------------------------------------
// Group: Example
//
// The following example illustrates how to implement a RegModel-BUS adapter class
// for the APB bus protocol.
//
//|class rreg2apb_adapter extends uvm_reg_adapter;
//|  `uvm_object_utils(reg2apb_adapter)
//|
//|  function new(string name="reg2apb_adapter");
//|    super.new(name);
//|    
//|  endfunction
//|
//|  virtual function uvm_sequence_item reg2bus(uvm_reg_bus_op rw);
//|    apb_item apb = apb_item::type_id::create("apb_item");
//|    apb.op   = (rw.kind == UVM_READ) ? apb::READ : apb::WRITE;
//|    apb.addr = rw.addr;
//|    apb.data = rw.data;
//|    return apb;
//|  endfunction
//|
//|  virtual function void bus2reg(uvm_sequencer_item bus_item,
//|                                uvm_reg_bus_op rw);
//|    apb_item apb;
//|    if (!$cast(apb,bus_item)) begin
//|      `uvm_fatal("CONVERT_APB2REG","Bus item is not of type apb_item")
//|    end
//|    rw.kind  = apb.op==apb::READ ? UVM_READ : UVM_WRITE;
//|    rw.addr = apb.addr;
//|    rw.data = apb.data;
//|    rw.status = UVM_IS_OK;
//|  endfunction
//|
//|endclass
//
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
//
// Class: uvm_reg_tlm_adapter
//
// For converting between <uvm_reg_bus_op> and <uvm_tlm_gp> items.
//
//------------------------------------------------------------------------------

class uvm_reg_tlm_adapter: uvm_reg_adapter
{

  mixin uvm_object_utils;

  public this(string name = "uvm_reg_tlm_adapter") {
    super(name);
  }

  // Function: reg2bus
  //
  // Converts a <uvm_reg_bus_op> struct to a <uvm_tlm_gp> item.

  override uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw) {
    // rw is struct instance -- can not synchronize
    uvm_tlm_gp gp = uvm_tlm_gp.type_id.create("tlm_gp", null,
					      this.get_full_name());
    synchronized(gp) {
      int  nbytes = (rw.n_bits-1)/8 + 1;
      uvm_reg_addr_t addr=rw.addr;

      if (rw.kind == UVM_WRITE) {
	gp.set_command(UVM_TLM_WRITE_COMMAND);
      }
      else {
	gp.set_command(UVM_TLM_READ_COMMAND);
      }

      gp.set_address(addr);

      auto byte_enable = new ubyte[nbytes];
      gp.set_byte_enable_length(nbytes);

      auto data = new ubyte[nbytes];
      gp.set_data_length(nbytes);

      gp.set_streaming_width(nbytes);

      for (int i = 0; i < nbytes; i++) {
	data[i] = rw.data.getByte(i); // [i*8+:8]
	// SV UVM has it this way, but how can i be > nbytes in this loop?
	// byte_enable[i] = (i > nbytes) ? 0 : rw.byte_en[i];
	byte_enable[i] = rw.byte_en[i];
      }

      gp.set_byte_enable(byte_enable);
      gp.set_data(data);
      
      return gp;
    }
  }
  // Function: bus2reg
  //
  // Converts a <uvm_tlm_gp> item to a <uvm_reg_bus_op>.
  // into the provided ~rw~ transaction.
  //
  override public void bus2reg(uvm_sequence_item bus_item,
		      ref uvm_reg_bus_op rw) {
    synchronized(this) {
      int  nbytes;

      if (bus_item is null) {
	uvm_fatal("REG/NULL_ITEM","bus2reg: bus_item argument is null");
      }

      uvm_tlm_gp gp = cast(uvm_tlm_gp) bus_item;

      if (gp is null) {
	uvm_error("WRONG_TYPE","Provided bus_item is not of type uvm_tlm_gp");
	return;
      }

      if (gp.get_command() == UVM_TLM_WRITE_COMMAND) {
	rw.kind = UVM_WRITE;
      }
      else {
	rw.kind = UVM_READ;
      }

      rw.addr = gp.get_address();

      rw.byte_en = 0;
      foreach (i, en; gp.get_byte_enable) {
	rw.byte_en[i] = (en == 0xff);
      }

      rw.data = 0;
      foreach (i, data; gp.get_data) {
	rw.data.setByte(i, data); // [i*8+:8]
      }

      rw.status = (gp.is_response_ok()) ? UVM_IS_OK : UVM_NOT_OK;


    }
  }
}
