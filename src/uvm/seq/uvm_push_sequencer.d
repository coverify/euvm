//------------------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2014-2018 NVIDIA Corporation
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
//------------------------------------------------------------------------------

module uvm.seq.uvm_push_sequencer;
import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequencer_param_base;

import uvm.meta.misc;
import uvm.base.uvm_component;

import uvm.tlm1.uvm_ports;

import esdl.rand.misc: rand;


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_push_sequencer #(REQ,RSP)
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 15.6.1
class uvm_push_sequencer(REQ=uvm_sequence_item, RSP=REQ):
  uvm_sequencer_param_base!(REQ, RSP), rand.barrier
{
  mixin(uvm_sync_string);

  alias this_type = uvm_push_sequencer!(REQ , RSP);

  // Port -- NODOCS -- req_port
  //
  // The push sequencer requires access to a blocking put interface.
  // A continuous stream of sequence items are sent out this port, based on
  // the list of available sequences loaded into this sequencer.
  //
  @uvm_immutable_sync
    private uvm_blocking_put_port!REQ _req_port;


  // @uvm-ieee 1800.2-2017 auto 15.6.3.2
  this(string name, uvm_component parent = null) {
    synchronized(this) {
      super(name, parent);
      _req_port = new uvm_blocking_put_port!REQ ("req_port", this);
    }
  }

  // Task -- NODOCS -- run_phase
  //
  // The push sequencer continuously selects from its list of available
  // sequences and sends the next item from the selected sequence out its
  // <req_port> using req_port.put(item). Typically, the req_port would be
  // connected to the req_export on an instance of a
  // <uvm_push_driver #(REQ,RSP)>, which would be responsible for
  // executing the item.
  //
  override void run_phase(uvm_phase phase) {

    // viriable selected_sequence declared in SV version -- but seems unused
    // int selected_sequence;

    auto runF = fork!("uvm_push_sequencer/run_phase")({
	super.run_phase(phase);
	while(true) {
	  REQ t;
	  m_select_sequence();
	  m_req_fifo.get(t);
	  req_port.put(t);
	  m_wait_for_item_sequence_id = t.get_sequence_id();
	  m_wait_for_item_transaction_id = t.get_transaction_id();
	}
      });
    runF.joinAll();
  }

  protected int  m_find_number_driver_connections() {
    return req_port.size();
  }

}
