//----------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010-2011 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2014 Cisco Systems, Inc.
// Copyright 2007-2011 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2017 Verific
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
module uvm.seq.uvm_sequencer;

import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequencer_param_base;
import uvm.seq.uvm_sequencer_base;
import uvm.seq.uvm_sequence_base;

import uvm.base.uvm_registry;
import uvm.base.uvm_factory;
import uvm.base.uvm_component;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_port_base;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_component_defines;

import uvm.tlm1.uvm_sqr_connections;
import uvm.tlm1.uvm_sqr_ifs;

import uvm.meta.misc;
import uvm.meta.meta;
import esdl.rand.misc: rand;

import std.format: format;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_sequencer #(REQ,RSP)
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 15.5.1
class uvm_sequencer(REQ = uvm_sequence_item, RSP = REQ) :
  uvm_sequencer_param_base!(REQ, RSP), rand.barrier
{
  mixin (uvm_sync_string);

  alias this_type = uvm_sequencer!(REQ , RSP);

  @uvm_private_sync
    private bool _sequence_item_requested;
  @uvm_private_sync
    private bool _get_next_item_called;

  mixin uvm_component_essentials;


  // @uvm-ieee 1800.2-2020 auto 15.5.2.1
  this(string name, uvm_component parent = null) {
    synchronized (this) {
      super(name, parent);
      _seq_item_export =
	new uvm_seq_item_pull_imp!(REQ, RSP, this_type)("seq_item_export", this);
    }
  }
  

  // Function -- NODOCS -- stop_sequences
  //
  // Tells the sequencer to kill all sequences and child sequences currently
  // operating on the sequencer, and remove all requests, locks and responses
  // that are currently queued.  This essentially resets the sequencer to an
  // idle state.
  //

  override void stop_sequences() {
    synchronized (this) {
      REQ t;
      super.stop_sequences();
      _sequence_item_requested  = false;
      _get_next_item_called     = false;
      // Empty the request fifo
      if (m_req_fifo.used()) {
	uvm_report_info(get_full_name(), "Sequences stopped.  Removing" ~
			" request from sequencer fifo");
	m_req_fifo.flush();
      }
    }
  }

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }

  // Group -- NODOCS -- Sequencer Interface
  // This is an interface for communicating with sequencers.
  //
  // The interface is defined as:
  //| Requests:
  //|  virtual task          get_next_item      (output REQ request);
  //|  virtual task          try_next_item      (output REQ request);
  //|  virtual task          get                (output REQ request);
  //|  virtual task          peek               (output REQ request);
  //| Responses:
  //|  virtual function void item_done          (input RSP response=null);
  //|  virtual task          put                (input RSP response);
  //| Sync Control:
  //|  virtual task          wait_for_sequences ();
  //|  virtual function bit  has_do_available   ();
  //
  // See <uvm_sqr_if_base #(REQ,RSP)> for information about this interface.
   
  // Variable -- NODOCS -- seq_item_export
  //
  // This export provides access to this sequencer's implementation of the
  // sequencer interface.
  //

  @uvm_immutable_sync
    private uvm_seq_item_pull_imp!(REQ, RSP, this_type) _seq_item_export;

  // Task -- NODOCS -- get_next_item
  // Retrieves the next available item from a sequence.
  //
  // task
  // @uvm-ieee 1800.2-2020 auto 15.5.2.3
  void get_next_item(out REQ t) {
    // declared in SV -- but does not seem to be used
    // REQ req_item;

    // If a sequence_item has already been requested, then get_next_item()
    // should not be called again until item_done() has been called.

    if (get_next_item_called is true) {
      uvm_report_error(get_full_name(),
		       "Get_next_item called twice without item_done" ~
		       " or get in between", uvm_verbosity.UVM_NONE);
    }

    if (! sequence_item_requested) {
      m_select_sequence();
    }

    // Set flag indicating that the item has been requested to ensure that item_done or get
    // is called between requests
    synchronized (this) {
      _sequence_item_requested = true;
      _get_next_item_called = true;
    }
    m_req_fifo.peek(t);
  }


  // Task -- NODOCS -- try_next_item
  // Retrieves the next available item from a sequence if one is available.
  //
  // @uvm-ieee 1800.2-2020 auto 15.5.2.4
  void try_next_item(out REQ t) {

    // declared in SV version, but nowhere used
    // time arb_time;

    if (get_next_item_called is true) {
      uvm_report_error(get_full_name(), "get_next_item/try_next_item called" ~
		       " twice without item_done or get in between", uvm_verbosity.UVM_NONE);
      return;
    }

    int selected_sequence;

    // allow state from last transaction to settle such that sequences'
    // relevancy can be determined with up-to-date information
    for (size_t i=0; i!=m_wait_for_sequences_count; ++i) {
      wait_for_sequences();

      // choose the sequence based on relevancy
      selected_sequence = m_choose_next_request();

      // return if none available
      if (selected_sequence is -1)
	break;
    }

    // return if none available
    if (selected_sequence == -1) {
      t = null;
      return;
    }

    uvm_sequence_base seq;
    synchronized (this) {
      // _arb_sequence_q is in the base class -- keep it under guard
      // now, allow chosen sequence to resume
      m_set_arbitration_completed(_arb_sequence_q[selected_sequence].request_id);
      seq = _arb_sequence_q[selected_sequence].sequence_ptr;
      _arb_sequence_q.remove(selected_sequence);

      m_update_lists();
      _sequence_item_requested = true;
      _get_next_item_called = true;
    }

    bool found_item;
    for (size_t i=0; i!=m_wait_for_sequences_count; ++i) {
      // give it one NBA to put a new item in the fifo
      wait_for_sequences();

      // attempt to get the item; if it fails, produce an error and return
      found_item = m_req_fifo.try_peek(t);
      if (found_item)
	break;
    }
  
    if (!found_item) {
      string msg = "try_next_item: the selected sequence '%s' did not produce an item within %0d wait_for_sequences call%s.  If the sequence requires more deltas/NBA within this time step, then the wait_for_sequences_count value for this sequencer should be increased.  Note that sequences should not consume non-delta/NBA time between calls to start_item and finish_item.  Returning null item.";
      uvm_error("TRY_NEXT_BLOCKED",
		format(msg, seq.get_full_name(), m_wait_for_sequences_count,
		       (m_wait_for_sequences_count>1) ? "s" : ""));
    }
  }


  // Function -- NODOCS -- item_done
  // Indicates that the request is completed.
  //

  // @uvm-ieee 1800.2-2020 auto 15.5.2.5
  void item_done(RSP item = null) {
    synchronized (this) {

      // Set flag to allow next get_next_item or peek to get a new sequence_item
      _sequence_item_requested = false;
      _get_next_item_called = false;

      REQ t;
      if (m_req_fifo.try_get(t) is false) {
	uvm_report_fatal("SQRBADITMDN", "Item_done() called with no" ~
			 " outstanding requests. Each call to item_done()" ~
			 " must be paired with a previous call to" ~
			 " get_next_item().");
      }
      else {
	m_wait_for_item_sequence_id = t.get_sequence_id();
	m_wait_for_item_transaction_id = t.get_transaction_id();
      }

      if (item !is null) {
	seq_item_export.put_response(item);
      }

      // Grant any locks as soon as possible
      grant_queued_locks();
    }
  }


  // Task -- NODOCS -- put
  // Sends a response back to the sequence that issued the request.
  //

  // task
  // @uvm-ieee 1800.2-2020 auto 15.5.2.8
  void put (RSP t) {
    put_response(t);
  }

  // Task -- NODOCS -- get
  // Retrieves the next available item from a sequence.
  //

  // task
  // @uvm-ieee 1800.2-2020 auto 15.5.2.6
  void get(out REQ t) {
    if (sequence_item_requested is false) {
      m_select_sequence();
    }
    sequence_item_requested = true;
    m_req_fifo.peek(t);
    item_done();
  }

  // task
  REQ get() {
    REQ t;
    this.get(t);
    return t;
  }


  // Task -- NODOCS -- peek
  // Returns the current request item if one is in the FIFO.
  //

  // task
  // @uvm-ieee 1800.2-2020 auto 15.5.2.7
  void peek(out REQ t) {
    if (sequence_item_requested is false) {
      m_select_sequence();
    }
    // Set flag indicating that the item has been requested to ensure that item_done or get
    // is called between requests
    sequence_item_requested = true;
    m_req_fifo.peek(t);
  }

  // task
  REQ peek() {
    REQ t;
    this.peek(t);
    return t;
  }

  /// Documented here for clarity, implemented in uvm_sequencer_base

  // Task -- NODOCS -- wait_for_sequences
  // Waits for a sequence to have a new item available.
  //

  // Function -- NODOCS -- has_do_available
  // Returns 1 if any sequence running on this sequencer is ready to supply
  // a transaction, 0 otherwise.
  //
   
  //-----------------
  // Internal Methods
  //-----------------
  // Do not use directly, not part of standard


  // item_done_trigger
  // -----------------

  void item_done_trigger(RSP item = null) {
    item_done(item);
  }

  RSP item_done_get_trigger_data() {
    return last_rsp(0);
  }

  // m_find_number_driver_connections
  // --------------------------------
  // Counting the number of of connections is done at end of
  // elaboration and the start of run.  If the user neglects to
  // call super in one or the other, the sequencer will still
  // have the correct value

  override protected size_t m_find_number_driver_connections() {
    uvm_port_base!(uvm_sqr_if_base!(REQ, RSP))[string] provided_to_port_list;

    // Check that the seq_item_pull_port is connected
    seq_item_export.get_provided_to(provided_to_port_list);
    return provided_to_port_list.length;
  }

}

alias uvm_sequencer!uvm_sequence_item uvm_virtual_sequencer;
