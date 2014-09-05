//
//-----------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
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

module uvm.base.uvm_transaction;

import uvm.base.uvm_object;
import uvm.base.uvm_component;
import uvm.base.uvm_event;
import uvm.base.uvm_recorder;
import uvm.base.uvm_printer;
import uvm.base.uvm_pool;
import uvm.base.uvm_object_globals;
import uvm.meta.mcd;
import uvm.meta.misc;

import esdl.base.core: getSimTime, SimTime;
import std.string: format;

// typedef class uvm_event;
// typedef class uvm_event_pool;
// typedef class uvm_component;

//------------------------------------------------------------------------------
//
// CLASS: uvm_transaction
//
// The uvm_transaction class is the root base class for UVM transactions.
// Inheriting all the methods of uvm_object, uvm_transaction adds a timing and
// recording interface.
//
// This class provides timestamp properties, notification events, and transaction
// recording support.
//
// Use of this class as a base for user-defined transactions
// is deprecated. Its subtype, <uvm_sequence_item>, shall be used as the
// base class for all user-defined transaction types.
//
// The intended use of this API is via a <uvm_driver> to call <uvm_component::accept_tr>,
// <uvm_component::begin_tr>, and <uvm_component::end_tr> during the course of
// sequence item execution. These methods in the component base class will
// call into the corresponding methods in this class to set the corresponding
// timestamps (accept_time, begin_time, and end_tr), trigger the
// corresponding event (<begin_event> and <end_event>, and, if enabled,
// record the transaction contents to a vendor-specific transaction database.
//
// Note that start_item/finish_item (or `uvm_do* macro) executed from a
// <uvm_sequence #(REQ,RSP)> will automatically trigger
// the begin_event and end_events via calls to begin_tr and end_tr. While
// convenient, it is generally the responsibility of drivers to mark a
// transaction's progress during execution.  To allow the driver to control
// sequence item timestamps, events, and recording, you must add
// +define+UVM_DISABLE_AUTO_ITEM_RECORDING when compiling the UVM package.
// Alternatively, users may use the transaction's event pool, <events>,
// to define custom events for the driver to trigger and the sequences to wait on. Any
// in-between events such as marking the begining of the address and data
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

abstract class uvm_transaction: uvm_object
{
  mixin(uvm_sync!uvm_transaction);

  // Function: new
  //
  // Creates a new transaction object. The name is the instance name of the
  // transaction. If not supplied, then the object is unnamed.

  // new
  // ---

  this(string name = "", uvm_component initiator = null) {
    synchronized(this) {
      super(name);
      _initiator = initiator;
      _m_transaction_id = -1;
      _events = new uvm_event_pool();
      _begin_event = _events.get("begin");
      _end_event = _events.get("end");
    }
  }

  // Function: accept_tr
  //
  // Calling ~accept_tr~ indicates that the transaction item has been received by
  // a consumer component. Typically a <uvm_driver> would call <uvm_component::accept_tr>,
  // which calls this method-- upon return from a get_next_item(), get(), or peek()
  // call on its sequencer port, <uvm_driver::seq_item_port>.
  //
  // With some
  // protocols, the received item may not be started immediately after it is
  // accepted. For example, a bus driver, having accepted a request transaction,
  // may still have to wait for a bus grant before begining to execute
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

  final public void accept_tr (SimTime accept_time = 0) {
    synchronized(this) {
      uvm_event e;

      if(accept_time != 0) {
	_accept_time = accept_time;
      }
      else {
	_accept_time = getSimTime();
      }

      do_accept_tr();
      e = events.get("accept");

      if(e !is null) {
	e.trigger();
      }
    }
  }



  // Function: do_accept_tr
  //
  // This user-definable callback is called by <accept_tr> just before the accept
  // event is triggered. Implementations should call ~super.do_accept_tr~ to
  // ensure correct operation.

  // do_accept_tr
  // -------------

  public void do_accept_tr() {
    return;
  }

  // Function: begin_tr
  //
  // This function indicates that the transaction has been started and is not
  // the child of another transaction. Generally, a consumer component begins
  // execution of a transactions it receives.
  //
  // Typically a <uvm_driver> would call <uvm_component::begin_tr>, which
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


  // begin_tr
  // -----------

  final public int begin_tr (SimTime begin_time = 0) {
    return m_begin_tr(begin_time, 0, false);
  }

  // Function: begin_child_tr
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
  //   the same begin time as above. The record method inherited from <uvm_object>
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

  // begin_child_tr
  // --------------

  //Use a parent handle of zero to link to the parent after begin
  final public int begin_child_tr (SimTime begin_time = 0,
				   int parent_handle = 0) {
    return m_begin_tr(begin_time, parent_handle, true);
  }

  // Function: do_begin_tr
  //
  // This user-definable callback is called by <begin_tr> and <begin_child_tr> just
  // before the begin event is triggered. Implementations should call
  // ~super.do_begin_tr~ to ensure correct operation.

  // do_begin_tr
  // ------------

  protected void do_begin_tr() {
    return;
  }

  // Function: end_tr
  //
  // This function indicates that the transaction execution has ended.
  // Generally, a consumer component ends execution of the transactions it
  // receives.
  //
  // You must have previously called <begin_tr> or <begin_child_tr> for this
  // call to be successful.
  //
  // Typically a <uvm_driver> would call <uvm_component::end_tr>, which
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

  // end_tr
  // ------

  final public void end_tr (SimTime end_time = 0, bool free_handle = true) {
    synchronized(this) {
      if(end_time != 0) {
	_end_time = end_time;
      }
      else {
	_end_time = getSimTime();
      }

      do_end_tr(); // Callback prior to actual ending of transaction

      if(is_active()) {
	_m_recorder.tr_handle = _tr_handle;
	record(_m_recorder);

	_m_recorder.end_tr(_tr_handle, _end_time);

	if(free_handle &&
	   _m_recorder.check_handle_kind("Transaction", _tr_handle) is true) {
	  // once freed, can no longer link to
	  _m_recorder.free_tr(_tr_handle);
	}
	_tr_handle = 0;
      }

      _end_event.trigger();
    }
  }

  // Function: do_end_tr
  //
  // This user-definable callback is called by <end_tr> just before the end event
  // is triggered. Implementations should call ~super.do_end_tr~ to ensure correct
  // operation.

  // do_end_tr
  // ----------

  public void do_end_tr() {
    return;
  }

  // Function: get_tr_handle
  //
  // Returns the handle associated with the transaction, as set by a previous
  // call to <begin_child_tr> or <begin_tr> with transaction recording enabled.

  // get_tr_handle
  // ---------

  final public int get_tr_handle () {
    synchronized(this) {
      return _tr_handle;
    }
  }

  // Function: disable_recording
  //
  // Turns off recording for the transaction stream. This method does not
  // effect a <uvm_component>'s recording streams.

  // disable_recording
  // -----------------

  final public void disable_recording () {
    synchronized(this) {
      _record_enable = false;
    }
  }



  // Function: enable_recording
  //
  // Turns on recording to the stream specified by stream, whose interpretation
  // is implementation specific. The optional ~recorder~ argument specifies
  //
  // If transaction recording is on, then a call to record is made when the
  // transaction is started and when it is ended.

  // enable_recording
  // ----------------

  final public void enable_recording (string stream,
				      uvm_recorder recorder = null) {
    synchronized(this) {
      string rscope;
      size_t lastdot;

      for(lastdot = stream.length-1; lastdot > 0; --lastdot) {
	if(stream[lastdot] is '.') break;
      }

      if(lastdot != 0) {
	rscope = stream[0..lastdot];
	stream = stream[lastdot+1..$];
      }

      if (recorder is null) {
	recorder = uvm_default_recorder;
      }
      _m_recorder = recorder;

      _stream_handle = _m_recorder.create_stream(stream, "TVM", rscope);
      _record_enable = true;
    }
  }

  // Function: is_recording_enabled
  //
  // Returns 1 if recording is currently on, 0 otherwise.

  // is_recording_enabled
  // --------------------

  final public bool is_recording_enabled () {
    synchronized(this) {
      return _record_enable;
    }
  }

  // Function: is_active
  //
  // Returns 1 if the transaction has been started but has not yet been ended.
  // Returns 0 if the transaction has not been started.

  // is_active
  // ---------

  final public bool is_active() {
    synchronized(this) {
      return (_tr_handle !is 0);
    }
  }

  // Function: get_event_pool
  //
  // Returns the event pool associated with this transaction.
  //
  // By default, the event pool contains the events: begin, accept, and end.
  // Events can also be added by derivative objects. An event pool is a
  // specialization of an <uvm_pool #(T)>, e.g. a ~uvm_pool#(uvm_event)~.

  // get_event_pool
  // --------------

  final public uvm_event_pool get_event_pool() {
    synchronized(this) {
      return events;
    }
  }

  // Function: set_initiator
  //
  // Sets initiator as the initiator of this transaction.
  //
  // The initiator can be the component that produces the transaction. It can
  // also be the component that started the transaction. This or any other
  // usage is up to the transaction designer.

  // set_initiator
  // ------------

  final public void set_initiator(uvm_component initiator) {
    synchronized(this) {
      _initiator = initiator;
    }
  }

  // Function: get_initiator
  //
  // Returns the component that produced or started the transaction, as set by
  // a previous call to set_initiator.

  // get_initiator
  // ------------

  final public uvm_component get_initiator() {
    synchronized(this) {
      return _initiator;
    }
  }

  // Function: get_accept_time

  // get_accept_time
  // ---------------

  final public SimTime get_accept_time () {
    synchronized(this) {
      return _accept_time;
    }
  }


  // Function: get_begin_time

  // get_begin_time
  // --------------

  final public SimTime get_begin_time () {
    synchronized(this) {
      return _begin_time;
    }
  }

  // Function: get_end_time
  //
  // Returns the time at which this transaction was accepted, begun, or ended,
  // as by a previous call to <accept_tr>, <begin_tr>, <begin_child_tr>, or <end_tr>.

  // get_end_time
  // ------------

  final public SimTime get_end_time () {
    synchronized(this) {
      return _end_time;
    }
  }

  // Function: set_transaction_id
  //
  // Sets this transaction's numeric identifier to id. If not set via this
  // method, the transaction ID defaults to -1.
  //
  // When using sequences to generate stimulus, the transaction ID is used along
  // with the sequence ID to route responses in sequencers and to correlate
  // responses to requests.

  // set_transaction_id
  final public void set_transaction_id(int id) {
    synchronized(this) {
      _m_transaction_id = id;
    }
  }


  // Function: get_transaction_id
  //
  // Returns this transaction's numeric identifier, which is -1 if not set
  // explicitly by ~set_transaction_id~.
  //
  // When using a <uvm_sequence #(REQ,RSP)> to generate stimulus, the transaction
  // ID is used along
  // with the sequence ID to route responses in sequencers and to correlate
  // responses to requests.

  // get_transaction_id
  final public int get_transaction_id() {
    synchronized(this) {
      return _m_transaction_id;
    }
  }



  // Variable: events
  //
  // The event pool instance for this transaction. This pool is used to track
  // various The <begin_event>

  @uvm_immutable_sync
  private uvm_event_pool _events;


  // Variable: begin_event
  //
  // A <uvm_event> that is triggered when this transaction's actual execution on the
  // bus begins, typically as a result of a driver calling <uvm_component::begin_tr>.
  // Processes that wait on this event will block until the transaction has
  // begun.
  //
  // For more information, see the general discussion for <uvm_transaction>.
  // See <uvm_event> for details on the event API.
  //
  @uvm_immutable_sync		// gets initialized in the constructor
    private uvm_event _begin_event;

  // Variable: end_event
  //
  // A <uvm_event> that is triggered when this transaction's actual execution on
  // the bus ends, typically as a result of a driver calling <uvm_component::end_tr>.
  // Processes that wait on this event will block until the transaction has
  // ended.
  //
  // For more information, see the general discussion for <uvm_transaction>.
  // See <uvm_event> for details on the event API.
  //
  //| virtual task my_sequence::frame();
  //|  ...
  //|  start_item(item);    \
  //|  item.randomize();     } `uvm_do(item)
  //|  finish_item(item);   /
  //|  // return from finish item does not always mean item is completed
  //|  item.end_event.wait_on();
  //|  ...
  //
  @uvm_immutable_sync		// gets initialized in the constructor
    private uvm_event _end_event;

  //----------------------------------------------------------------------------
  //
  // Internal methods properties; do not use directly
  //
  //----------------------------------------------------------------------------

  //Override data control methods for internal properties

  // do_print
  // --------

  override public void do_print (uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      if(_accept_time != -1) {
	printer.print_time("accept_time", _accept_time);
      }
      if(_begin_time != -1) {
	printer.print_time("begin_time", _begin_time);
      }
      if(_end_time != -1) {
	printer.print_time("end_time", _end_time);
      }
      if(_initiator !is null) {
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

  override public void do_record (uvm_recorder recorder) {
    synchronized(this) {
      super.do_record(recorder);
      if(_accept_time != -1) {
	recorder.record("accept_time", _accept_time);
      }

      if(_initiator !is null) {
	uvm_recursion_policy_enum p = recorder.policy;
	recorder.policy = UVM_REFERENCE;
	recorder.record("initiator", _initiator);
	recorder.policy = p;
      }
    }
  }


  // do_copy
  // -------

  override public void do_copy (uvm_object rhs) {
    synchronized(this) {
      super.do_copy(rhs);
      if(rhs is null) return;
      auto txn = cast(uvm_transaction) rhs;
      if(txn is null) return;

      _accept_time = txn.accept_time;
      _begin_time = txn.begin_time;
      _end_time = txn.end_time;
      _initiator = txn.initiator;
      _stream_handle = txn.stream_handle;
      _tr_handle = txn.tr_handle;
      _record_enable = txn.record_enable;
    }
  }

  // m_begin_tr
  // -----------

  public int m_begin_tr (SimTime begin_time = 0,
			 int parent_handle = 0,
			 bool has_parent = false) {
    synchronized(this) {
      if(begin_time != 0) {
	_begin_time = begin_time;
      }
      else {
	_begin_time = getSimTime();
      }

      // May want to establish predecessor/successor relation
      // (don't free handle until then)
      if(_record_enable) {
	if(_m_recorder.check_handle_kind("Transaction", _tr_handle) is true) {
	  end_tr();
	}

	if(!has_parent) {
	  _tr_handle = _m_recorder.begin_tr("Begin_No_Parent, Link",
					    _stream_handle, get_type_name(),
					    "", "", _begin_time);
	}
	else {
	  _tr_handle = _m_recorder.begin_tr("Begin_End, Link",
					    _stream_handle, get_type_name(),
					    "", "", _begin_time);
	  if(parent_handle) {
	    _m_recorder.link_tr(parent_handle, _tr_handle, "child");
	  }
	}
	_m_recorder.tr_handle = _tr_handle;
	if(_m_recorder.check_handle_kind("Transaction", _tr_handle) is false) {
	  vdisplay("tr handle %0d not valid!", _tr_handle);
	}
      }
      else {
	_tr_handle = 0;
      }

      do_begin_tr(); //execute callback before event trigger

      _begin_event.trigger();

      return _tr_handle;
    }
  }



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
    private int _stream_handle = 0;
  @uvm_private_sync
    private int _tr_handle = 0;
  @uvm_private_sync
    private bool _record_enable;
  @uvm_private_sync
    private uvm_recorder _m_recorder;

}
