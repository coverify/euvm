//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
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
//------------------------------------------------------------------------------
module uvm.seq.uvm_sequencer_param_base;
import uvm.seq.uvm_sequencer_base;
import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequencer_analysis_fifo;

import uvm.base.uvm_component;
import uvm.base.uvm_phase;
import uvm.base.uvm_printer;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object;

import uvm.tlm1.uvm_analysis_port;
import uvm.tlm1.uvm_tlm_fifos;

import uvm.meta.misc;

import esdl.data.queue;
import esdl.data.rand;
import std.string: format;

//------------------------------------------------------------------------------
//
// CLASS: uvm_sequencer_param_base #(REQ,RSP)
//
// Extends <uvm_sequencer_base> with an API depending on specific
// request (REQ) and response (RSP) types.
//------------------------------------------------------------------------------

class uvm_sequencer_param_base (REQ = uvm_sequence_item,
				RSP = REQ): uvm_sequencer_base
if(is(REQ: uvm_sequence_item) && is(RSP: uvm_sequence_item))
{
  mixin(uvm_sync!uvm_sequencer_param_base);

  alias uvm_sequencer_param_base !(REQ , RSP) this_type;
  alias REQ req_type;
  alias RSP rsp_type;

  private Queue!REQ _m_last_req_buffer;
  private Queue!RSP _m_last_rsp_buffer;

  @uvm_protected_sync
  private int _m_num_last_reqs = 1;
  @uvm_protected_sync
  private int _num_last_items = 1; // _m_num_last_reqs
  @uvm_protected_sync
  private int _m_num_last_rsps = 1;
  @uvm_protected_sync
  private int _m_num_reqs_sent;
  @uvm_protected_sync
  private int _m_num_rsps_received;

  @uvm_immutable_sync
    private uvm_sequencer_analysis_fifo!RSP _sqr_rsp_analysis_fifo;


  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for uvm_component: name is the name of the instance,
  // and parent is the handle to the hierarchical parent, if any.
  //

  // new
  // ---

  public this(string name, uvm_component parent) {
    synchronized(this) {
      super(name, parent);
      _rsp_export             =
	new uvm_analysis_export!RSP ("rsp_export", this);
      _sqr_rsp_analysis_fifo  =
	new uvm_sequencer_analysis_fifo!RSP("sqr_rsp_analysis_fifo", this);
      _m_req_fifo             =
	new uvm_tlm_fifo!REQ ("req_fifo", this);
      _sqr_rsp_analysis_fifo.print_enabled = false;
      _m_req_fifo.print_enabled            = false;
    }
  }



  // Function: send_request
  //
  // The send_request function may only be called after a wait_for_grant call.
  // This call will send the request item, t,  to the sequencer pointed to by
  // sequence_ptr. The sequencer will forward it to the driver. If rerandomize
  // is set, the item will be randomized before being sent to the driver.
  //

  // send_request
  // ------------

  override public void send_request(uvm_sequence_base sequence_ptr,
				      uvm_sequence_item t,
				      bool rerandomize = false) {
    synchronized(this) {
      if (sequence_ptr is null) {
	uvm_report_fatal("SNDREQ", "Send request sequence_ptr"
			 " is null", UVM_NONE);
      }
      if (sequence_ptr.m_wait_for_grant_semaphore < 1) {
	uvm_report_fatal("SNDREQ", "Send request called without"
			 " wait_for_grant", UVM_NONE);
      }
      sequence_ptr.dec_wait_for_grant_semaphore();

      REQ param_t = cast(REQ) t;
      if (param_t !is null) {
	if (rerandomize is true) {
	  if (! param_t.randomize()) {
	    uvm_report_warning("SQRSNDREQ", "Failed to rerandomize sequence"
			       " item in send_request");
	  }
	}
	if (param_t.get_transaction_id() is -1) {
	  param_t.set_transaction_id(sequence_ptr.inc_next_transaction_id);
	}
	m_last_req_push_front(param_t);
      }
      else {
	uvm_report_fatal(get_name(), format("send_request failed to cast"
					    " sequence item"), UVM_NONE);
      }
      param_t.set_sequence_id(sequence_ptr.m_get_sqr_sequence_id(m_sequencer_id,
								 true));
      t.set_sequencer(this);
      if (_m_req_fifo.try_put(param_t) !is true) {
	uvm_report_fatal(get_full_name(),
			 format("Concurrent calls to send_request() not"
				" supported. Check your driver for concurrent"
				" calls to get_next_item()"), UVM_NONE);
      }
      _m_num_reqs_sent++;
      // Grant any locks as soon as possible
      grant_queued_locks();
    }
  }

  // Function: get_current_item
  //
  // Returns the request_item currently being executed by the sequencer. If the
  // sequencer is not currently executing an item, this method will return null.
  //
  // The sequencer is executing an item from the time that get_next_item or peek
  // is called until the time that get or item_done is called.
  //
  // Note that a driver that only calls get() will never show a current item,
  // since the item is completed at the same time as it is requsted.
  //
  final public REQ get_current_item() {
    synchronized(this) {
      REQ t;
      if (_m_req_fifo.try_peek(t) is false) return null;
      return t;
    }
  }


  //----------------
  // Group: Requests
  //----------------

  // Function: get_num_reqs_sent
  //
  // Returns the number of requests that have been sent by this sequencer.
  //

  // get_num_reqs_sent
  // -----------------

  final public int get_num_reqs_sent() {
    synchronized(this) {
      return _m_num_reqs_sent;
    }
  }



  // Function: set_num_last_reqs
  //
  // Sets the size of the last_requests buffer.  Note that the maximum buffer
  // size is 1024.  If max is greater than 1024, a warning is issued, and the
  // buffer is set to 1024.  The default value is 1.
  //

  // set_num_last_reqs
  // -----------------

  final public void set_num_last_reqs(uint max) {
    synchronized(this) {
      if(max > 1024) {
	uvm_report_warning("HSTOB",
			   format("Invalid last size; 1024 is the maximum"
				  " and will be used"));
	max = 1024;
      }

      //shrink the buffer if necessary
      while((_m_last_req_buffer.length !is 0) &&
	    (_m_last_req_buffer.length > max)) {
	_m_last_req_buffer.removeBack();
      }

      _m_num_last_reqs = max;
      _num_last_items = max;
    }
  }



  // Function: get_num_last_reqs
  //
  // Returns the size of the last requests buffer, as set by set_num_last_reqs.

  // get_num_last_reqs
  // -----------------

  final public uint get_num_last_reqs() {
    synchronized(this) {
      return _m_num_last_reqs;
    }
  }

  // Function: last_req
  //
  // Returns the last request item by default.  If n is not 0, then it will get
  // the n�th before last request item.  If n is greater than the last request
  // buffer size, the function will return null.
  //
  final public REQ last_req(uint n = 0) {
    synchronized(this) {
      if(n > _m_num_last_reqs) {
	uvm_report_warning("HSTOB",
			   format("Invalid last access (%0d), the max"
				  " history is %0d", n,
				  _m_num_last_reqs));
	return null;
      }
      if(n is _m_last_req_buffer.length) {
	return null;
      }

      return _m_last_req_buffer[n];
    }
  }



  //-----------------
  // Group: Responses
  //-----------------

  // Port: rsp_export
  //
  // Drivers or monitors can connect to this port to send responses
  // to the sequencer.  Alternatively, a driver can send responses
  // via its seq_item_port.
  //
  //|  seq_item_port.item_done(response)
  //|  seq_item_port.put(response)
  //|  rsp_port.write(response)   <--- via this export
  //
  // The rsp_port in the driver and/or monitor must be connected to the
  // rsp_export in this sequencer in order to send responses through the
  // response analysis port.

  @uvm_immutable_sync
    private uvm_analysis_export!RSP _rsp_export;


  // Function: get_num_rsps_received
  //
  // Returns the number of responses received thus far by this sequencer.

  // get_num_rsps_received
  // ---------------------

  final public int get_num_rsps_received() {
    synchronized(this) {
      return _m_num_rsps_received;
    }
  }



  // Function: set_num_last_rsps
  //
  // Sets the size of the last_responses buffer.  The maximum buffer size is
  // 1024. If max is greater than 1024, a warning is issued, and the buffer is
  // set to 1024.  The default value is 1.
  //

  // set_num_last_rsps
  // -----------------

  final public void set_num_last_rsps(uint max) {
    synchronized(this) {
      if(max > 1024) {
	uvm_report_warning("HSTOB",
			   format("Invalid last size; 1024 is the maximum"
				  " and will be used"));
	max = 1024;
      }
      //shrink the buffer
      while((_m_last_rsp_buffer.length !is 0)
	    && (_m_last_rsp_buffer.length > max)) {
	_m_last_rsp_buffer.removeBack();
      }
      _m_num_last_rsps = max;
    }
  }




  // Function: get_num_last_rsps
  //
  // Returns the max size of the last responses buffer, as set by
  // set_num_last_rsps.
  //

  // get_num_last_rsps
  // -----------------

  final public uint get_num_last_rsps() {
    synchronized(this) {
      return _m_num_last_rsps;
    }
  }

  // Function: last_rsp
  //
  // Returns the last response item by default.  If n is not 0, then it will
  // get the nth-before-last response item.  If n is greater than the last
  // response buffer size, the function will return null.
  //
  final public RSP last_rsp(uint n = 0) {
    synchronized(this) {
      if(n > _m_num_last_rsps) {
	uvm_report_warning("HSTOB",
			   format("Invalid last access (%0d), the max"
				  " history is %0d", n, _m_num_last_rsps));
	return null;
      }
      if(n is _m_last_rsp_buffer.length) {
	return null;
      }

      return _m_last_rsp_buffer[n];
    }
  }

  // Internal methods and variables; do not use directly; not part of standard

  // m_last_rsp_push_front
  // ---------------------

  final public void m_last_rsp_push_front(RSP item) {
    synchronized(this) {
      if(!_m_num_last_rsps) return;

      if(_m_last_rsp_buffer.length is _m_num_last_rsps) {
	_m_last_rsp_buffer.removeBack();
      }

      this._m_last_rsp_buffer.pushFront(item);
    }
  }


  // put_response
  // ------------

  final public void put_response (RSP t) {
    synchronized(this) {

      uvm_sequence_base sequence_ptr;

      if (t is null) {
	uvm_report_fatal("SQRPUT", "Driver put a null response", UVM_NONE);
      }

      m_last_rsp_push_front(t);
      _m_num_rsps_received++;

      // Check that set_id_info was called
      if (t.get_sequence_id() is -1) {
	version(CDNS_NO_SQR_CHK_SEQ_ID) {}
	else {
	  uvm_report_fatal("SQRPUT", "Driver put a response with null"
			   " sequence_id", UVM_NONE);
	}
	return;
      }

      sequence_ptr = m_find_sequence(t.get_sequence_id());

      if (sequence_ptr !is null) {
	// If the response_handler is enabled for this sequence,
	// then call the response handler
	if (sequence_ptr.get_use_response_handler() is 1) {
	  sequence_ptr.response_handler(t);
	  return;
	}

	sequence_ptr.put_response(t);
      }
      else {
	uvm_report_info("Sequencer",
			format("Dropping response for sequence %0d, sequence"
			       " not found.  Probable cause: sequence exited"
			       " or has been killed", t.get_sequence_id()));
      }
    }
  }


  // build_phase
  // -----------

  override public void build_phase(uvm_phase phase) {
    synchronized(this) {
      super.build_phase(phase);
      sqr_rsp_analysis_fifo.sequencer_ptr = this;
    }
  }



  // connect_phase
  // -------------

  override public void connect_phase(uvm_phase phase) {
    synchronized(this) {
      super.connect_phase(phase);
      rsp_export.connect(sqr_rsp_analysis_fifo.analysis_export);
    }
  }



  // do_print
  // --------

  override public void do_print (uvm_printer printer) {
    synchronized(this) {
      super.do_print(printer);
      printer.print_int("num_last_reqs", _m_num_last_reqs,
			// $bits(_m_num_last_reqs),
			UVM_DEC);
      printer.print_int("num_last_rsps", _m_num_last_rsps,
			// $bits(_m_num_last_rsps),
			UVM_DEC);
    }
  }


  // analysis_write
  // --------------

  override public void analysis_write(uvm_sequence_item t) {
    synchronized(this) {
      RSP response = cast(RSP) t;

      if (response is null) {
	uvm_report_fatal("ANALWRT", "Failure to cast analysis port write item",
			 UVM_NONE);
      }
      put_response(response);
    }
  }


  // m_last_req_push_front
  // ---------------------

  final public void m_last_req_push_front(REQ item) {
    synchronized(this) {
      if(!_m_num_last_reqs) return;

      if(_m_last_req_buffer.length is _m_num_last_reqs) {
	_m_last_req_buffer.removeBack();
      }

      this._m_last_req_buffer.pushFront(item);
    }
  }

  @uvm_immutable_sync
    private uvm_tlm_fifo!REQ _m_req_fifo;

}
