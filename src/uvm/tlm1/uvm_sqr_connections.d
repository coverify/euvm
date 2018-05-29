//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2010 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2014 Coverify Systems Technology
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

module uvm.tlm1.uvm_sqr_connections;

import uvm.base.uvm_port_base;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_component;

import uvm.tlm1.uvm_sqr_ifs;
import uvm.tlm1.uvm_tlm_defines;

mixin template UVM_SEQ_ITEM_PULL_IMP(alias IMP, REQ, RSP)
{
  // task
  override public void get_next_item(out REQ req_arg) {IMP.get_next_item(req_arg);}
  // task
  override public void try_next_item(out REQ req_arg) {IMP.try_next_item(req_arg);}
  override public void item_done(RSP rsp_arg = null) {IMP.item_done(rsp_arg);}
  // task
  override public void wait_for_sequences() {IMP.wait_for_sequences();}
  override public bool has_do_available() {return IMP.has_do_available();}
  override public void put_response(RSP rsp_arg) {IMP.put_response(rsp_arg);}
  // task
  override public void get(out REQ req_arg) {IMP.get(req_arg);}
  // task
  override public void peek(out REQ req_arg) {IMP.peek(req_arg);}
  // task
  override public void put(RSP rsp_arg) {IMP.put(rsp_arg);}
}

//-----------------------------------------------------------------------------
// Title: Sequence Item Pull Ports
//
// This section defines the port, export, and imp port classes for
// communicating sequence items between <uvm_sequencer #(REQ,RSP)> and
// <uvm_driver #(REQ,RSP)>.
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
//
// Class: uvm_seq_item_pull_port #(REQ,RSP)
//
// UVM provides a port, export, and imp connector for use in sequencer-driver
// communication. All have standard port connector constructors, except that
// uvm_seq_item_pull_port's default min_size argument is 0; it can be left
// unconnected.
//
//-----------------------------------------------------------------------------

class uvm_seq_item_pull_port(REQ=int, RSP=REQ):
  uvm_port_base!(uvm_sqr_if_base!(REQ, RSP))
{
  public this(string name=null, uvm_component parent=null,
	      int min_size=0, int max_size=1) {
    synchronized(this) {
      super(name, parent, uvm_port_type_e.UVM_PORT, min_size, max_size);
      m_if_mask = UVM_SEQ_ITEM_PULL_MASK;
    }
  }
  override public string get_type_name() {
    return "uvm_seq_item_pull_port";
  }

  mixin UVM_SEQ_ITEM_PULL_IMP!(m_if, REQ, RSP);

  bool print_enabled;
}


//-----------------------------------------------------------------------------
//
// Class: uvm_seq_item_pull_export #(REQ,RSP)
//
// This export type is used in sequencer-driver communication. It has the
// standard constructor for exports.
//
//-----------------------------------------------------------------------------

class uvm_seq_item_pull_export(REQ=int, RSP=REQ):
  uvm_port_base!(uvm_sqr_if_base!(REQ, RSP))
{
  public this(string name, uvm_component parent,
	      int min_size=1, int max_size=1) {
    synchronized(this) {
      super(name, parent, uvm_port_type_e.UVM_EXPORT, min_size, max_size);
      m_if_mask = UVM_SEQ_ITEM_PULL_MASK;
    }
  }

  public string get_type_name() {
    return "uvm_seq_item_pull_export";
  }

  mixin UVM_SEQ_ITEM_PULL_IMP!(this.m_if, REQ, RSP);
}


//-----------------------------------------------------------------------------
//
// Class: uvm_seq_item_pull_imp #(REQ,RSP,IMP)
//
// This imp type is used in sequencer-driver communication. It has the
// standard constructor for imp-type ports.
//
//-----------------------------------------------------------------------------

class uvm_seq_item_pull_imp(REQ=int, RSP=REQ, IMP=int):
  uvm_port_base!(uvm_sqr_if_base!(REQ, RSP))
{
  private IMP m_imp;
  public this(string name, IMP imp) {
    synchronized(this) {
      super (name, imp, uvm_port_type_e.UVM_IMPLEMENTATION, 1, 1);
      m_imp = imp;
      m_if_mask = UVM_SEQ_ITEM_PULL_MASK;
    }
  }

  override public string get_type_name() {
    return "uvm_seq_item_pull_imp";
  }

  mixin UVM_SEQ_ITEM_PULL_IMP!(m_imp, REQ, RSP);
}
