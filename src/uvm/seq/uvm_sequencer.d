//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2014      NVIDIA Corporation
//   Copyright 2014-2016 Coverify Systems Technology
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

import uvm.tlm1.uvm_sqr_connections;

import uvm.meta.misc;
import uvm.meta.meta;

//------------------------------------------------------------------------------
//
// CLASS: uvm_sequencer #(REQ,RSP)
//
//------------------------------------------------------------------------------

class uvm_sequencer(REQ = uvm_sequence_item, RSP = REQ) :
  uvm_sequencer_param_base!(REQ, RSP)
{
  mixin(uvm_sync_string);

  alias this_type = uvm_sequencer!(REQ , RSP);

  @uvm_private_sync
    private bool _sequence_item_requested;
  @uvm_private_sync
    private bool _get_next_item_called;

  mixin uvm_component_essentials;


  // Function: new
  //
  // Standard component constructor that creates an instance of this class
  // using the given ~name~ and ~parent~, if any.
  //
  this(string name, uvm_component parent = null) {
    synchronized(this) {
      super(name, parent);
      _seq_item_export =
	new uvm_seq_item_pull_imp!(REQ, RSP, this_type)("seq_item_export", this);
    }
  }
  

  // Function: stop_sequences
  //
  // Tells the sequencer to kill all sequences and child sequences currently
  // operating on the sequencer, and remove all requests, locks and responses
  // that are currently queued.  This essentially resets the sequencer to an
  // idle state.
  //

  override void stop_sequences() {
    synchronized(this) {
      REQ t;
      super.stop_sequences();
      _sequence_item_requested  = false;
      _get_next_item_called     = false;
      // Empty the request fifo
      if (m_req_fifo.used()) {
	uvm_report_info(get_full_name(), "Sequences stopped.  Removing"
			" request from sequencer fifo");
	while (m_req_fifo.try_get(t)) {}
      }
    }
  }

  override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }

  // Group: Sequencer Interface
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
   
  // Variable: seq_item_export
  //
  // This export provides access to this sequencer's implementation of the
  // sequencer interface.
  //

  @uvm_immutable_sync
    private uvm_seq_item_pull_imp!(REQ, RSP, this_type) _seq_item_export;

  // Task: get_next_item
  // Retrieves the next available item from a sequence.
  //
  // task
  void get_next_item(out REQ t) {
    // declared in SV -- but does not seem to be used
    // REQ req_item;

    // If a sequence_item has already been requested, then get_next_item()
    // should not be called again until item_done() has been called.

    if (get_next_item_called is true) {
      uvm_report_error(get_full_name(),
		       "Get_next_item called twice without item_done"
		       " or get in between", UVM_NONE);
    }

    if (! sequence_item_requested) {
      m_select_sequence();
    }

    // Set flag indicating that the item has been requested to ensure that item_done or get
    // is called between requests
    synchronized(this) {
      _sequence_item_requested = true;
      _get_next_item_called = true;
    }
    m_req_fifo.peek(t);
  }


  // Task: try_next_item
  // Retrieves the next available item from a sequence if one is available.
  //

  void try_next_item(out REQ t) {

    // declared in SV version, but nowhere used
    // time arb_time;

    if (get_next_item_called is true) {
      uvm_report_error(get_full_name(), "get_next_item/try_next_item called"
		       " twice without item_done or get in between", UVM_NONE);
      return;
    }

    // allow state from last transaction to settle such that sequences'
    // relevancy can be determined with up-to-date information
    wait_for_sequences();

    uvm_sequence_base seq;
    synchronized(this) {
      // choose the sequence based on relevancy
      int selected_sequence = m_choose_next_request();

      // return if none available
      if (selected_sequence is -1) {
	t = null;
	return;
      }

      // _arb_sequence_q is in the base class -- keep it under guard
      // now, allow chosen sequence to resume
      m_set_arbitration_completed(_arb_sequence_q[selected_sequence].request_id);
      seq = _arb_sequence_q[selected_sequence].sequence_ptr;
      _arb_sequence_q.remove(selected_sequence);

      m_update_lists();
      _sequence_item_requested = true;
      _get_next_item_called = true;
    }

    // give it one NBA to put a new item in the fifo
    wait_for_sequences();

    // attempt to get the item; if it fails, produce an error and return
    if (!m_req_fifo.try_peek(t))
      uvm_report_error("TRY_NEXT_BLOCKED",
		       "try_next_item: the selected sequence '" ~
		       seq.get_full_name() ~ "' did not produce an item"
		       " within an NBA delay. Sequences should not consume"
		       " time between calls to start_item and finish_item. "
		       "Returning null item.", UVM_NONE);

  }


  // Function: item_done
  // Indicates that the request is completed.
  //

  void item_done(RSP item = null) {
    synchronized(this) {

      // Set flag to allow next get_next_item or peek to get a new sequence_item
      _sequence_item_requested = false;
      _get_next_item_called = false;

      REQ t;
      if (m_req_fifo.try_get(t) is false) {
	uvm_report_fatal(get_full_name(), "Item_done() called with no"
			 " outstanding requests. Each call to item_done()"
			 " must be paired with a previous call to"
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


  // Task: put
  // Sends a response back to the sequence that issued the request.
  //

  // task
  void put (RSP t) {
    put_response(t);
  }

  // Task: get
  // Retrieves the next available item from a sequence.
  //

  // task
  final void get(out REQ t) {
    if (sequence_item_requested is false) {
      m_select_sequence();
    }
    sequence_item_requested = true;
    m_req_fifo.peek(t);
    item_done();
  }

  // task
  final REQ get() {
    REQ t;
    this.get(t);
    return t;
  }


  // Task: peek
  // Returns the current request item if one is in the FIFO.
  //

  // task
  final void peek(out REQ t) {
    if (sequence_item_requested is false) {
      m_select_sequence();
    }
    // Set flag indicating that the item has been requested to ensure that item_done or get
    // is called between requests
    sequence_item_requested = true;
    m_req_fifo.peek(t);
  }

  // task
  final REQ peek() {
    REQ t;
    this.peek(t);
    return t;
  }

  /// Documented here for clarity, implemented in uvm_sequencer_base

  // Task: wait_for_sequences
  // Waits for a sequence to have a new item available.
  //

  // Function: has_do_available
  // Returns 1 if any sequence running on this sequencer is ready to supply
  // a transaction, 0 otherwise.
  //
   
  //-----------------
  // Internal Methods
  //-----------------
  // Do not use directly, not part of standard


  // item_done_trigger
  // -----------------

  final void item_done_trigger(RSP item = null) {
    item_done(item);
  }

  final RSP item_done_get_trigger_data() {
    return last_rsp(0);
  }

  // m_find_number_driver_connections
  // --------------------------------
  // Counting the number of of connections is done at end of
  // elaboration and the start of run.  If the user neglects to
  // call super in one or the other, the sequencer will still
  // have the correct value

  override protected size_t m_find_number_driver_connections() {
    uvm_port_component_base[string] provided_to_port_list;

    // Check that the seq_item_pull_port is connected
    uvm_port_component_base seq_port_base = seq_item_export.get_comp();
    seq_port_base.get_provided_to(provided_to_port_list);
    return provided_to_port_list.length;
  }

}

alias uvm_sequencer!uvm_sequence_item uvm_virtual_sequencer;
