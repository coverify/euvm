//
//-----------------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2010-2013 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2020 Marvell International Ltd.
// Copyright 2010 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2014-2017 Cisco Systems, Inc.
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

module uvm.base.uvm_transaction;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_event: uvm_event;
import uvm.base.uvm_recorder: uvm_recorder;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_pool: uvm_object_string_pool;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_tr_stream: uvm_tr_stream;
import uvm.base.uvm_tr_database: uvm_tr_database;

import uvm.meta.mcd;
import uvm.meta.misc;

import esdl.base.core: SimTime, getRootEntity;
import esdl.rand.misc: rand;

import std.string: format;

alias uvm_event_pool = uvm_object_string_pool!(uvm_event!(uvm_object));
// typedef class uvm_event;
// typedef class uvm_event_pool;
// typedef class uvm_component;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_transaction
//
// The uvm_transaction class is the root base class for UVM transactions.
// Inheriting all the methods of <uvm_object>, uvm_transaction adds a timing and
// recording interface.
//
// This class provides timestamp properties, notification events, and transaction
// recording support.
//
// Use of this class as a base for user-defined transactions
// is deprecated. Its subtype, <uvm_sequence_item>, shall be used as the
// base class for all user-defined transaction types.
//
// The intended use of this API is via a <uvm_driver #(REQ,RSP)> to call <uvm_component::accept_tr>,
// <uvm_component::begin_tr>, and <uvm_component::end_tr> during the course of
// sequence item execution. These methods in the component base class will
// call into the corresponding methods in this class to set the corresponding
// timestamps (~accept_time~, ~begin_time~, and ~end_time~), trigger the
// corresponding event (<begin_event> and <end_event>, and, if enabled,
// record the transaction contents to a vendor-specific transaction database.
//
// Note that get_next_item/item_done when called on a uvm_seq_item_pull_port
// will automatically trigger the begin_event and end_events via calls to begin_tr and end_tr.
// While convenient, it is generally the responsibility of drivers to mark a
// transaction's progress during execution.  To allow the driver or layering sequence
// to control sequence item timestamps, events, and recording, you must call
// <uvm_sqr_if_base#(REQ,RSP)::disable_auto_item_recording> at the beginning
// of the driver's ~run_phase~ task.
//
// Users may also use the transaction's event pool, <events>,
// to define custom events for the driver to trigger and the sequences to wait on. Any
// in-between events such as marking the beginning of the address and data
// phases of transaction execution could be implemented via the
// <events> pool.
//
// In pipelined protocols, the driver may release a sequence (return from
// finish_item() or it's `uvm_do macro) before the item has been completed.
// If the driver uses the begin_tr/end_tr API in uvm_component, the sequence can
// wait on the item's <end_event> to block until the item was fully executed,
// as in the following example.
//
//| task uvm_execute(item, ...);
//|     // can use the `uvm_do macros as well
//|     start_item(item);
//|     item.randomize();
//|     finish_item(item);
//|     item.end_event.wait_on();
//|     // get_response(rsp, item.get_transaction_id()); //if needed
//| endtask
//|
//
// A simple two-stage pipeline driver that can execute address and
// data phases concurrently might be implemented as follows:
//
//| task run();
//|     // this driver supports a two-deep pipeline
//|     fork
//|       do_item();
//|       do_item();
//|     join
//| endtask
//|
//|
//| task do_item();
//|
//|   forever begin
//|     mbus_item req;
//|
//|     lock.get();
//|
//|     seq_item_port.get(req); // Completes the sequencer-driver handshake
//|
//|     accept_tr(req);
//|
//|       // request bus, wait for grant, etc.
//|
//|     begin_tr(req);
//|
//|       // execute address phase
//|
//|     // allows next transaction to begin address phase
//|     lock.put();
//|
//|       // execute data phase
//|       // (may trigger custom "data_phase" event here)
//|
//|     end_tr(req);
//|
//|   end
//|
//| endtask: do_item
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2017 auto 5.4.1

abstract class uvm_transaction: uvm_object, rand.barrier
{
  import uvm.base.uvm_component;
  mixin (uvm_sync_string);

  // Function -- NODOCS -- new
  //
  // Creates a new transaction object. The name is the instance name of the
  // transaction. If not supplied, then the object is unnamed.

  // new
  // ---

  // @uvm-ieee 1800.2-2017 auto 5.4.2.1
  this(string name = "", uvm_component initiator = null) {
    synchronized (this) {
      super(name);
      _initiator = initiator;
      _m_transaction_id = -1;
      _events = new uvm_event_pool();
    }
  }

  // Function -- NODOCS -- accept_tr
  //
  // Calling ~accept_tr~ indicates that the transaction item has been received by
  // a consumer component. Typically a <uvm_driver #(REQ,RSP)> would call <uvm_component::accept_tr>,
  // which calls this method-- upon return from a ~get_next_item()~, ~get()~, or ~peek()~
  // call on its sequencer port, <uvm_driver#(REQ,RSP)::seq_item_port>.
  //
  // With some
  // protocols, the received item may not be started immediately after it is
  // accepted. For example, a bus driver, having accepted a request transaction,
  // may still have to wait for a bus grant before beginning to execute
  // the request.
  //
  // This function performs the following actions:
  //
  // - The transaction's internal accept time is set to the current simulation
  //   time, or to accept_time if provided and non-zero. The ~accept_time~ may be
  //   any time, past or future.
  //
  // - The transaction's internal accept event is triggered. Any processes
  //   waiting on the this event will resume in the next delta cycle.
  //
  // - The <do_accept_tr> method is called to allow for any post-accept
  //   action in derived classes.

  // accept_tr
  // ---------

  // @uvm-ieee 1800.2-2017 auto 5.4.2.2
  final void accept_tr (SimTime accept_time = 0) {
    synchronized (this) {
      uvm_event!uvm_object e;

      if (accept_time != 0) {
	_accept_time = accept_time;
      }
      else {
	_accept_time = getRootEntity().getSimTime();
      }

      do_accept_tr();
      e = _events.get("accept");

      if (e !is null) {
	e.trigger();
      }
    }
  }



  // Function -- NODOCS -- do_accept_tr
  //
  // This user-definable callback is called by <accept_tr> just before the accept
  // event is triggered. Implementations should call ~super.do_accept_tr~ to
  // ensure correct operation.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.3
  void do_accept_tr() {
    return;
  }

  // Function -- NODOCS -- begin_tr
  //
  // This function indicates that the transaction has been started and is not
  // the child of another transaction. Generally, a consumer component begins
  // execution of a transactions it receives.
  //
  // Typically a <uvm_driver #(REQ,RSP)> would call <uvm_component::begin_tr>, which
  // calls this method, before actual execution of a sequence item transaction.
  // Sequence items received by a driver are always a child of a parent sequence.
  // In this case, begin_tr obtains the parent handle and delegates to <begin_child_tr>.
  //
  // See <accept_tr> for more information on how the
  // begin-time might differ from when the transaction item was received.
  //
  // This function performs the following actions:
  //
  // - The transaction's internal start time is set to the current simulation
  //   time, or to begin_time if provided and non-zero. The begin_time may be
  //   any time, past or future, but should not be less than the accept time.
  //
  // - If recording is enabled, then a new database-transaction is started with
  //   the same begin time as above.
  //
  // - The <do_begin_tr> method is called to allow for any post-begin action in
  //   derived classes.
  //
  // - The transaction's internal begin event is triggered. Any processes
  //   waiting on this event will resume in the next delta cycle.
  //
  // The return value is a transaction handle, which is valid (non-zero) only if
  // recording is enabled. The meaning of the handle is implementation specific.


  // @uvm-ieee 1800.2-2017 auto 5.4.2.4
  version(UVM_1800_2_2020_EA) {
    final int begin_tr(SimTime begin_time = 0, int parent_handle = 0) {
      return m_begin_tr(begin_time, parent_handle);
    }
  }
  else {
    final int begin_tr(SimTime begin_time = 0) {
      return m_begin_tr(begin_time);
    }
  }
  
  // Function -- NODOCS -- begin_child_tr
  //
  // This function indicates that the transaction has been started as a child of
  // a parent transaction given by ~parent_handle~. Generally, a consumer
  // component calls this method via <uvm_component::begin_child_tr> to indicate
  // the actual start of execution of this transaction.
  //
  // The parent handle is obtained by a previous call to begin_tr or
  // begin_child_tr. If the parent_handle is invalid (=0), then this function
  // behaves the same as <begin_tr>.
  //
  // This function performs the following actions:
  //
  // - The transaction's internal start time is set to the current simulation
  //   time, or to begin_time if provided and non-zero. The begin_time may be
  //   any time, past or future, but should not be less than the accept time.
  //
  // - If recording is enabled, then a new database-transaction is started with
  //   the same begin time as above. The inherited <uvm_object::record> method
  //   is then called, which records the current property values to this new
  //   transaction. Finally, the newly started transaction is linked to the
  //   parent transaction given by parent_handle.
  //
  // - The <do_begin_tr> method is called to allow for any post-begin
  //   action in derived classes.
  //
  // - The transaction's internal begin event is triggered. Any processes
  //   waiting on this event will resume in the next delta cycle.
  //
  // The return value is a transaction handle, which is valid (non-zero) only if
  // recording is enabled. The meaning of the handle is implementation specific.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.5
  //Use a parent handle of zero to link to the parent after begin
  final int begin_child_tr (SimTime begin_time = 0,
			    int parent_handle = 0) {
    return m_begin_tr(begin_time, parent_handle);
  }

  // Function -- NODOCS -- do_begin_tr
  //
  // This user-definable callback is called by <begin_tr> and <begin_child_tr> just
  // before the begin event is triggered. Implementations should call
  // ~super.do_begin_tr~ to ensure correct operation.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.6
  protected void do_begin_tr() {
    return;
  }

  // Function -- NODOCS -- end_tr
  //
  // This function indicates that the transaction execution has ended.
  // Generally, a consumer component ends execution of the transactions it
  // receives.
  //
  // You must have previously called <begin_tr> or <begin_child_tr> for this
  // call to be successful.
  //
  // Typically a <uvm_driver #(REQ,RSP)> would call <uvm_component::end_tr>, which
  // calls this method, upon completion of a sequence item transaction.
  // Sequence items received by a driver are always a child of a parent sequence.
  // In this case, begin_tr obtain the parent handle and delegate to <begin_child_tr>.
  //
  // This function performs the following actions:
  //
  // - The transaction's internal end time is set to the current simulation
  //   time, or to ~end_time~ if provided and non-zero. The ~end_time~ may be any
  //   time, past or future, but should not be less than the begin time.
  //
  // - If recording is enabled and a database-transaction is currently active,
  //   then the record method inherited from uvm_object is called, which records
  //   the final property values. The transaction is then ended. If ~free_handle~
  //   is set, the transaction is released and can no longer be linked to (if
  //   supported by the implementation).
  //
  // - The <do_end_tr> method is called to allow for any post-end
  //   action in derived classes.
  //
  // - The transaction's internal end event is triggered. Any processes waiting
  //   on this event will resume in the next delta cycle.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.7
  final void end_tr(SimTime end_time = 0, bool free_handle = true) {
    synchronized (this) {
      _end_time = (end_time == 0) ? getRootEntity.getSimTime : end_time;

      do_end_tr(); // Callback prior to actual ending of transaction

      if (is_recording_enabled() && (_tr_recorder !is null)) {
	record(_tr_recorder);

	_tr_recorder.close(_end_time);

	if (free_handle) {
	  // once freed, can no longer link to
	  _tr_recorder.free();
        }
      } // if (is_active())

      _tr_recorder = null;

      uvm_event!(uvm_object) end_event = events.get("end") ;
      end_event.trigger();
    }
  }

  // Function -- NODOCS -- do_end_tr
  //
  // This user-definable callback is called by <end_tr> just before the end event
  // is triggered. Implementations should call ~super.do_end_tr~ to ensure correct
  // operation.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.8
  void do_end_tr() {
    return;
  }

  // Function -- NODOCS -- get_tr_handle
  //
  // Returns the handle associated with the transaction, as set by a previous
  // call to <begin_child_tr> or <begin_tr> with transaction recording enabled.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.9
  int get_tr_handle () {
    synchronized (this) {
      if (_tr_recorder !is null) {
	return _tr_recorder.get_handle();
      }
      else { 
	return 0;
      }
    }
  }

  // Function -- NODOCS -- disable_recording
  //
  // Turns off recording for the transaction stream. This method does not
  // effect a <uvm_component>'s recording streams.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.11
  final void disable_recording () {
    synchronized (this) {
      _stream_handle = null;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 5.4.2.10
  final void enable_recording (uvm_tr_stream stream) {
    synchronized (this) {
      _stream_handle = stream;
    }
  }

  // Function -- NODOCS -- is_recording_enabled
  //
  // Returns 1 if recording is currently on, 0 otherwise.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.12
  final bool is_recording_enabled () {
    synchronized (this) {
      return (_stream_handle !is null);
    }
  }

  // Function -- NODOCS -- is_active
  //
  // Returns 1 if the transaction has been started but has not yet been ended.
  // Returns 0 if the transaction has not been started.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.13
  final bool is_active() {
    synchronized (this) {
      return (_end_time == -1);
    }
  }

  // Function -- NODOCS -- get_event_pool
  //
  // Returns the event pool associated with this transaction.
  //
  // By default, the event pool contains the events: begin, accept, and end.
  // Events can also be added by derivative objects. An event pool is a
  // specialization of <uvm_pool #(KEY,T)>, e.g. a ~uvm_pool#(uvm_event)~.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.14
  final uvm_event_pool get_event_pool() {
    // _events is effectively immutable
    // synchronization guard can be removed
    synchronized (this) {
      return _events;
    }
  }

  // Function -- NODOCS -- set_initiator
  //
  // Sets initiator as the initiator of this transaction.
  //
  // The initiator can be the component that produces the transaction. It can
  // also be the component that started the transaction. This or any other
  // usage is up to the transaction designer.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.15
  final void set_initiator(uvm_component initiator) {
    synchronized (this) {
      _initiator = initiator;
    }
  }

  // Function -- NODOCS -- get_initiator
  //
  // Returns the component that produced or started the transaction, as set by
  // a previous call to set_initiator.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.16
  final uvm_component get_initiator() {
    synchronized (this) {
      return _initiator;
    }
  }

  // Function -- NODOCS -- get_accept_time

  // @uvm-ieee 1800.2-2017 auto 5.4.2.17
  final SimTime get_accept_time () {
    synchronized (this) {
      return _accept_time;
    }
  }


  // Function -- NODOCS -- get_begin_time

  // @uvm-ieee 1800.2-2017 auto 5.4.2.17
  final SimTime get_begin_time () {
    synchronized (this) {
      return _begin_time;
    }
  }

  // Function -- NODOCS -- get_end_time
  //
  // Returns the time at which this transaction was accepted, begun, or ended,
  // as by a previous call to <accept_tr>, <begin_tr>, <begin_child_tr>, or <end_tr>.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.17
  final SimTime get_end_time () {
    synchronized (this) {
      return _end_time;
    }
  }

  // Function -- NODOCS -- set_transaction_id
  //
  // Sets this transaction's numeric identifier to id. If not set via this
  // method, the transaction ID defaults to -1.
  //
  // When using sequences to generate stimulus, the transaction ID is used along
  // with the sequence ID to route responses in sequencers and to correlate
  // responses to requests.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.18
  final void set_transaction_id(int id) {
    synchronized (this) {
      _m_transaction_id = id;
    }
  }


  // Function -- NODOCS -- get_transaction_id
  //
  // Returns this transaction's numeric identifier, which is -1 if not set
  // explicitly by ~set_transaction_id~.
  //
  // When using a <uvm_sequence #(REQ,RSP)> to generate stimulus, the transaction
  // ID is used along
  // with the sequence ID to route responses in sequencers and to correlate
  // responses to requests.

  // @uvm-ieee 1800.2-2017 auto 5.4.2.19
  final int get_transaction_id() {
    synchronized (this) {
      return _m_transaction_id;
    }
  }



  // Variable -- NODOCS -- events
  //
  // The event pool instance for this transaction. This pool is used to track
  // various milestones: by default, begin, accept, and end

  @uvm_immutable_sync
  private uvm_event_pool _events;


  //----------------------------------------------------------------------------
  //
  // Internal methods properties; do not use directly
  //
  //----------------------------------------------------------------------------

  //Override data control methods for internal properties

  // do_print
  // --------

  override void do_print (uvm_printer printer) {
    synchronized (this) {
      super.do_print(printer);
      if (_accept_time != -1) {
	printer.print_time("accept_time", _accept_time);
      }
      if (_begin_time != -1) {
	printer.print_time("begin_time", _begin_time);
      }
      if (_end_time != -1) {
	printer.print_time("end_time", _end_time);
      }
      if (_initiator !is null) {
	// uvm_component tmp_initiator; //work around $swrite bug
	// uvm_component tmp_initiator = _initiator;
	// string str = format("@%0d", tmp_initiator.get_inst_id());
	string str = format("@%0d", _initiator.get_inst_id());
	printer.print_generic("initiator", _initiator.get_type_name(), -1, str);
      }
    }
  }

  // do_record
  // ---------

  override void do_record (uvm_recorder recorder) {
    import uvm.base.uvm_object_globals;
    synchronized (this) {
      super.do_record(recorder);
      if (_accept_time != -1) {
	recorder.record("accept_time", _accept_time);
      }

      if (_initiator !is null) {
	uvm_recursion_policy_enum p = recorder.get_recursion_policy();
	recorder.set_recursion_policy(uvm_recursion_policy_enum.UVM_REFERENCE);
	recorder.record("initiator", _initiator);
	recorder.set_recursion_policy(p);
      }
    }
  }


  // do_copy
  // -------

  override void do_copy (uvm_object rhs) {
    // In SV version super.do_copy is invoked before checking for null
    // But then what would a uvm_object do with a null object copy
    if (rhs is null) {
      return;
    }
    super.do_copy(rhs);
    auto txn = cast (uvm_transaction) rhs;
    if (txn is null) {
      return;
    }
    synchronized (this) {
      synchronized (txn) {
	_accept_time = txn.accept_time;
	_begin_time = txn.begin_time;
	_end_time = txn.end_time;
	_initiator = txn.initiator;
	_stream_handle = txn.stream_handle;
	_tr_recorder = txn.tr_recorder;
      }
    }
  }

  // m_begin_tr
  // -----------

  int m_begin_tr (SimTime begin_time = 0,
		  int parent_handle = 0) {
    import uvm.base.uvm_links;
    synchronized (this) {
      int m_begin_tr_;
      SimTime tmp_time =
	(begin_time == 0) ? getRootEntity.getSimTime : begin_time;
      uvm_recorder parent_recorder;

      if (parent_handle != 0) {
	parent_recorder = uvm_recorder.get_recorder_from_handle(parent_handle);
      }

      // If we haven't ended the previous record, end it.
      if (_tr_recorder !is null) {
	// Don't free the handle, someone else may be using it...
	end_tr(tmp_time);
      }

      // May want to establish predecessor/successor relation 
      // (don't free handle until then)
      if (is_recording_enabled()) {
	uvm_tr_database db = _stream_handle.get_db();
      
	_end_time = -1;
	_begin_time = tmp_time;
      
	if (parent_recorder is null) {
	  _tr_recorder = _stream_handle.open_recorder(get_type_name(),
						      _begin_time,
						      "Begin_No_Parent, Link");
	}
	else {
	  _tr_recorder = _stream_handle.open_recorder(get_type_name(),
						      _begin_time,
						      "Begin_End, Link");
	  if (_tr_recorder !is null) {
	    db.establish_link(uvm_parent_child_link.get_link(parent_recorder,
							     _tr_recorder));
	  }
	}

	if (_tr_recorder !is null) {
	  m_begin_tr_ = _tr_recorder.get_handle();
	}
	else {
	  m_begin_tr_ = 0;
	}
      }
      else {
	_tr_recorder = null;
	_end_time = -1;
	_begin_time = tmp_time;

	m_begin_tr_ = 0;
      }
   
      do_begin_tr(); //execute callback before event trigger
   
      uvm_event!(uvm_object) begin_event = events.get("begin");
      begin_event.trigger();

      return m_begin_tr_;
    }
  }



  @uvm_private_sync
  private int _m_transaction_id = -1;
  @uvm_private_sync
  private SimTime _begin_time = -1;
  @uvm_private_sync
  private SimTime _end_time = -1;
  @uvm_private_sync
  private SimTime _accept_time = -1;
  @uvm_private_sync
  private uvm_component _initiator;
  @uvm_private_sync
  private uvm_tr_stream _stream_handle;
  @uvm_private_sync
  private uvm_recorder _tr_recorder;

}
