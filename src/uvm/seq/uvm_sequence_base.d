//----------------------------------------------------------------------
// Copyright 2014-2019 Coverify Systems Technology
// Copyright 2007-2017 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2014-2017 Intel Corporation
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013 Verilab
// Copyright 2010-2012 AMD
// Copyright 2012-2018 NVIDIA Corporation
// Copyright 2014 Cisco Systems, Inc.
// Copyright 2012 Accellera Systems Initiative
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

module uvm.seq.uvm_sequence_base;


//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_sequence_base
//
// The uvm_sequence_base class provides the interfaces needed to create streams
// of sequence items and/or other sequences.
//
// A sequence is executed by calling its <start> method, either directly
// or invocation of any of the `uvm_do_* macros.
//
// Executing sequences via <start>:
//
// A sequence's <start> method has a ~parent_sequence~ argument that controls
// whether <pre_do>, <mid_do>, and <post_do> are called *in the parent*
// sequence. It also has a ~call_pre_post~ argument that controls whether its
// <pre_body> and <post_body> methods are called.
// In all cases, its <pre_start> and <post_start> methods are always called.
//
// When <start> is called directly, you can provide the appropriate arguments
// according to your application.
//
// The sequence execution flow looks like this
//
// User code
//
//| sub_seq.randomize(...); // optional
//| sub_seq.start(seqr, parent_seq, priority, call_pre_post)
//|
//
// The following methods are called, in order
//
//|
//|   sub_seq.pre_start()        (task)
//|   sub_seq.pre_body()         (task)  if call_pre_post==1
//|     parent_seq.pre_do(0)     (task)  if parent_sequence !is null
//|     parent_seq.mid_do(this)  (func)  if parent_sequence !is null
//|   sub_seq.body               (task)  YOUR STIMULUS CODE
//|     parent_seq.post_do(this) (func)  if parent_sequence !is null
//|   sub_seq.post_body()        (task)  if call_pre_post==1
//|   sub_seq.post_start()       (task)
//
//
// Executing sub-sequences via `uvm_do macros:
//
// A sequence can also be indirectly started as a child in the <body> of a
// parent sequence. The child sequence's <start> method is called indirectly
// by invoking any of the `uvm_do macros.
// In these cases, <start> is called with
// ~call_pre_post~ set to 0, preventing the started sequence's <pre_body> and
// <post_body> methods from being called. During execution of the
// child sequence, the parent's <pre_do>, <mid_do>, and <post_do> methods
// are called.
//
// The sub-sequence execution flow looks like
//
// User code
//
//|
//| `uvm_do_with_prior(seq_seq, { constraints }, priority)
//|
//
// The following methods are called, in order
//
//|
//|   sub_seq.pre_start()         (task)
//|   parent_seq.pre_do(0)        (task)
//|   parent_req.mid_do(sub_seq)  (func)
//|     sub_seq.body()            (task)
//|   parent_seq.post_do(sub_seq) (func)
//|   sub_seq.post_start()        (task)
//|
//
// Remember, it is the *parent* sequence's pre|mid|post_do that are called, not
// the sequence being executed.
//
//
//
// Executing sequence items via <start_item>/<finish_item> or `uvm_do macros:
//
// Items are started in the <body> of a parent sequence via calls to
// <start_item>/<finish_item> or invocations of any of the `uvm_do
// macros. The <pre_do>, <mid_do>, and <post_do> methods of the parent
// sequence will be called as the item is executed.
//
// The sequence-item execution flow looks like
//
// User code
//
//| parent_seq.start_item(item, priority);
//| item.randomize(...) [with {constraints}];
//| parent_seq.finish_item(item);
//|
//| or
//|
//| `uvm_do_with_prior(item, constraints, priority)
//|
//
// The following methods are called, in order
//
//|
//|   sequencer.wait_for_grant(prior) (task) \ start_item  \
//|   parent_seq.pre_do(1)            (task) /              \
//|                                                      `uvm_do* macros
//|   parent_seq.mid_do(item)         (func) \              /
//|   sequencer.send_request(item)    (func)  \finish_item /
//|   sequencer.wait_for_item_done()  (task)  /
//|   parent_seq.post_do(item)        (func) /
//
// Attempting to execute a sequence via <start_item>/<finish_item>
// will produce a run-time error.
//------------------------------------------------------------------------------

import uvm.base.uvm_coreservice;
import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequencer_base;
import uvm.base.uvm_factory;
import uvm.base.uvm_recorder;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_phase;
import uvm.base.uvm_tr_stream;
import uvm.dap.uvm_get_to_lock_dap;
import uvm.base.uvm_misc: uvm_create_random_seed;

import uvm.meta.misc;

import esdl.base.core;
import esdl.data.queue;

version(UVM_NO_RAND) {}
 else {
   import esdl.rand;
 }

import std.string;

// @uvm-ieee 1800.2-2017 auto 14.2.1
abstract class uvm_sequence_base: uvm_sequence_item
{
  mixin uvm_abstract_object_essentials;
  
  mixin (uvm_sync_string);

  @uvm_immutable_sync
  private WithEvent!uvm_sequence_state _m_sequence_state;

  @uvm_public_sync
  private int _m_next_transaction_id = 1;

  int inc_next_transaction_id() {
    synchronized (this) {
      return _m_next_transaction_id++;
    }
  }

  private int                  _m_priority = -1;
  @uvm_public_sync
  private uvm_recorder _m_tr_recorder;
  @uvm_public_sync
  private int _m_wait_for_grant_semaphore;

  int inc_wait_for_grant_semaphore() {
    synchronized (this) {
      return _m_wait_for_grant_semaphore++;
    }
  }
  int dec_wait_for_grant_semaphore() {
    synchronized (this) {
      return _m_wait_for_grant_semaphore--;
    }
  }

  // Each sequencer will assign a sequence id.  When a sequence is talking to multiple
  // sequencers, each sequence_id is managed separately

  // protected
  private int[int] _m_sqr_seq_ids;

  private bool[uvm_sequence_base] _children_array;
  void add_children_array(uvm_sequence_base seq) {
    synchronized (this) {
      _children_array[seq] = true;
    }
  }
  void rem_children_array(uvm_sequence_base seq) {
    synchronized (this) {
      _children_array.remove(seq);
    }
  }
  bool in_children_array(uvm_sequence_base seq) {
    synchronized (this) {
      if (seq in _children_array) {
	return true;
      }
      else {
	return false;
      }
    }
  }

  private Queue!uvm_sequence_item _response_queue;
  size_t response_queue_length() {
    synchronized (this) {
      return _response_queue.length;
    }
  }

  // protected
  private Event                   _response_queue_event;
  // protected
  private int                     _response_queue_depth = 8;
  // protected
  private bool                    _response_queue_error_report_enabled;

  // Variable -- NODOCS -- do_not_randomize
  //
  // If set, prevents the sequence from being randomized before being executed
  // by the `uvm_do*() and `uvm_rand_send*() macros,
  // or as a default sequence.
  //
  @uvm_private_sync
  private bool _do_not_randomize;

  @uvm_protected_sync
  private Process _m_sequence_process;
  private bool _m_use_response_handler;

  // bools to detect if is_relevant()/wait_for_relevant() are implemented
  private bool _is_rel_default;
  private bool _wait_rel_default;


  // @uvm-ieee 1800.2-2017 auto 14.2.2.1
  this(string name = "uvm_sequence") {
    synchronized (this) {
      super(name);
      _m_sequence_state = new WithEvent!uvm_sequence_state("_m_sequence_state");
      _m_sequence_state = uvm_sequence_state.UVM_CREATED;
      _m_wait_for_grant_semaphore = 0;
      _response_queue_event.initialize("_response_queue_event");
      m_init_phase_daps(true);
    }
  }


  bool get_randomize_enabled() {
    synchronized (this) {
      return (_do_not_randomize == false);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 14.2.2.3
  void set_randomize_enabled(bool enable) {
    synchronized (this) {
      _do_not_randomize = !enable;
    }
  }

  // Function -- NODOCS -- is_item
  //
  // Returns 1 on items and 0 on sequences. As this object is a sequence,
  // ~is_item~ will always return 0.
  //
  override bool is_item() {
    return false;
  }


  // Function -- NODOCS -- get_sequence_state
  //
  // Returns the sequence state as an enumerated value. Can use to wait on
  // the sequence reaching or changing from one or more states.
  //
  //| wait(get_sequence_state() & (UVM_STOPPED|UVM_FINISHED));

  // @uvm-ieee 1800.2-2017 auto 14.2.2.4
  uvm_sequence_state get_sequence_state() {
    synchronized (this) {
      return _m_sequence_state;
    }
  }


  // Task -- NODOCS -- wait_for_sequence_state
  //
  // Waits until the sequence reaches the given ~state~. If the sequence
  // is already in this state, this method returns immediately. Convenience
  // for wait ( get_sequence_state == ~state~ );
  //| wait_for_sequence_state(UVM_STOPPED|UVM_FINISHED);

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.2.5
  void wait_for_sequence_state(uvm_sequence_state state_mask) {
    while ((m_sequence_state.get & state_mask) == 0) {
      m_sequence_state.getEvent.wait();
    }
  }

  // Function -- NODOCS -- get_tr_handle
  //
  // Returns the integral recording transaction handle for this sequence.
  // Can be used to associate sub-sequences and sequence items as
  // child transactions when calling <uvm_component::begin_child_tr>.

  override int get_tr_handle() {
    synchronized (this) {
      if (_m_tr_recorder !is null) {
	return _m_tr_recorder.get_handle();
      }
      else {
	return 0;
      }
    }
  }

  
  //--------------------------
  // Group -- NODOCS -- Sequence Execution
  //--------------------------


  // Task -- NODOCS -- start
  //
  // Executes this sequence, returning when the sequence has completed.
  //
  // The ~sequencer~ argument specifies the sequencer on which to run this
  // sequence. The sequencer must be compatible with the sequence.
  //
  // If ~parent_sequence~ is ~null~, then this sequence is a root parent,
  // otherwise it is a child of ~parent_sequence~. The ~parent_sequence~'s
  // pre_do, mid_do, and post_do methods will be called during the execution
  // of this sequence.
  //
  // By default, the ~priority~ of a sequence
  // is the priority of its parent sequence.
  // If it is a root sequence, its default priority is 100.
  // A different priority may be specified by ~this_priority~.
  // Higher numbers indicate higher priority.
  //
  // If ~call_pre_post~ is set to 1 (default), then the <pre_body> and
  // <post_body> tasks will be called before and after the sequence
  // <body> is called.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.3.1
  void start(uvm_sequencer_base sequencer,
	     uvm_sequence_base parent_sequence = null,
	     int this_priority = -1,
	     bool call_pre_post = true) {

    synchronized (this) {
      set_item_context(parent_sequence, sequencer);

      // if (!(m_sequence_state inside {CREATED,STOPPED,FINISHED}))
      if (_m_sequence_state != uvm_sequence_state.UVM_CREATED &&
	 _m_sequence_state != uvm_sequence_state.UVM_STOPPED &&
	 _m_sequence_state != uvm_sequence_state.UVM_FINISHED) {
	uvm_report_fatal("SEQ_NOT_DONE",
			 "Sequence " ~ get_full_name() ~ " already started",
			 uvm_verbosity.UVM_NONE);
      }

      if (_m_parent_sequence !is null) {
	synchronized (_m_parent_sequence) {
	  _m_parent_sequence.add_children_array(this);
	}
      }

      if (this_priority < -1) {
	uvm_report_fatal("SEQPRI",
			 format("Sequence %s start has illegal priority: %0d",
				get_full_name(),
				this_priority), uvm_verbosity.UVM_NONE);
      }
      if (this_priority < 0) {
	if (parent_sequence is null) {
	  this_priority = 100;
	}
	else {
	  this_priority = parent_sequence.get_priority();
	}
      }

      // Check that the response queue is empty from earlier runs
      clear_response_queue();

      _m_priority = this_priority;

      if (_m_sequencer !is null) {
	int handle;
	if (_m_parent_sequence is null) {
	  handle = _m_sequencer.begin_tr(this, get_name());
	  _m_tr_recorder = uvm_recorder.get_recorder_from_handle(handle);
	}
	else {
          handle = _m_sequencer.begin_tr(this, get_root_sequence_name(),
					 "", "", SimTime(0),
					 (_m_parent_sequence.m_tr_recorder is null) ?
					 0 : _m_parent_sequence.m_tr_recorder.get_handle());
	  _m_tr_recorder = uvm_recorder.get_recorder_from_handle(handle);
	}
      }

      // Ensure that the sequence_id is intialized in case this sequence has been stopped previously
      set_sequence_id(-1);

      // Register the sequence with the sequencer if defined.
      if (_m_sequencer !is null) {
	_m_sequencer.m_register_sequence(this);
      }
    }

    // Change the state to PRE_START, do this before the fork so that
    // the "if (!(m_sequence_state inside {...}" works
    m_sequence_state = uvm_sequence_state.UVM_PRE_START;
    
    auto seqFork = fork!("uvm_sequence_base/start")({
	m_sequence_process = Process.self;

	// The following code segment is intrduced in embedded UVM to enable random stability
	// not present in SV UVM
	if (_m_sequencer !is null) {
	  m_sequence_process.srandom(uvm_create_random_seed(this.get_type_name(),
							    _m_sequencer.get_full_name()));
	}
	else {
	  m_sequence_process.srandom(uvm_create_random_seed(this.get_type_name(),
							    this.get_full_name()));
	}
	
	wait(0);

        // Raise the objection if enabled
        // (This will lock the uvm_get_to_lock_dap)
        if (get_automatic_phase_objection()) {
	  m_safe_raise_starting_phase("automatic phase objection");
	}
         
	pre_start();

	if (call_pre_post is true) {
	  m_sequence_state = uvm_sequence_state.UVM_PRE_BODY;
	  wait(0);
	  pre_body();
	}

	if (parent_sequence !is null) {
	  parent_sequence.pre_do(0);    // task
	  parent_sequence.mid_do(this); // function
	}

	m_sequence_state = uvm_sequence_state.UVM_BODY;
	wait(0);
	body();

	m_sequence_state = uvm_sequence_state.UVM_ENDED;
	wait(0);

	if (parent_sequence !is null) {
	  parent_sequence.post_do(this);
	}

	if (call_pre_post is true) {
	  m_sequence_state = uvm_sequence_state.UVM_POST_BODY;
	  wait(0);
	  post_body();
	}

	m_sequence_state = uvm_sequence_state.UVM_POST_START;
	wait(0);
	post_start();

        // Drop the objection if enabled
        if (get_automatic_phase_objection()) {
	  m_safe_drop_starting_phase("automatic phase objection");
        }
         
	m_sequence_state = uvm_sequence_state.UVM_FINISHED;
	wait(0);

      });
    seqFork.joinAll();

    synchronized (this) {
      if (_m_sequencer !is null) {
	_m_sequencer.end_tr(this);
      }

      // Clean up any sequencer queues after exiting; if we
      // were forcibly stopped, this step has already taken place
      if (_m_sequence_state != uvm_sequence_state.UVM_STOPPED) {
	clean_exit_sequence();
      }
    }

    wait(0); // allow stopped and finish waiters to resume

    if ((m_parent_sequence !is null) &&
	(m_parent_sequence.in_children_array(this))) {
      m_parent_sequence.rem_children_array(this);
    }

    bool old_automatic_phase_objection = get_automatic_phase_objection();
    m_init_phase_daps(true);
    set_automatic_phase_objection(old_automatic_phase_objection);
  }


  // Function -- NODOCS -- clean_exit_sequence
  // This function is for Clean up any sequencer queues after exiting; if we
  // were forcibly stopped, this step has already taken place

  void clean_exit_sequence() {
    synchronized (this) {
      if (_m_sequencer !is null)
        m_sequencer.m_sequence_exiting(this);	 
      else	
	      // remove any routing for this sequence even when virtual sequencers (or a null sequencer is involved)
	      // once we pass this point nothing can be routed to this sequence(id)
	foreach (seqrID, id; _m_sqr_seq_ids) {
	  uvm_sequencer_base s =
	    uvm_sequencer_base.all_sequencer_insts[seqrID];
	  s.m_sequence_exiting(this);
	}
      _m_sqr_seq_ids.clear();
    }
  }
 

  // Task -- NODOCS -- pre_start
  //
  // This task is a user-definable callback that is called before the
  // optional execution of <pre_body>.
  // This method should not be called directly by the user.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.3.2
  void pre_start() {
    return;
  }


  // Task -- NODOCS -- pre_body
  //
  // This task is a user-definable callback that is called before the
  // execution of <body> ~only~ when the sequence is started with <start>.
  // If <start> is called with ~call_pre_post~ set to 0, ~pre_body~ is not
  // called.
  // This method should not be called directly by the user.

  // task
  void pre_body() {
    return;
  }


  // Task -- NODOCS -- pre_do
  //
  // This task is a user-definable callback task that is called ~on the
  // parent sequence~, if any
  // sequence has issued a wait_for_grant() call and after the sequencer has
  // selected this sequence, and before the item is randomized.
  //
  // Although pre_do is a task, consuming simulation cycles may result in
  // unexpected behavior on the driver.
  //
  // This method should not be called directly by the user.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.3.4
  void pre_do(bool is_item) {
    return;
  }


  // Function -- NODOCS -- mid_do
  //
  // This function is a user-definable callback function that is called after
  // the sequence item has been randomized, and just before the item is sent
  // to the driver.  This method should not be called directly by the user.

  // @uvm-ieee 1800.2-2017 auto 14.2.3.5
  void mid_do(uvm_sequence_item this_item) {
    return;
  }


  // Task -- NODOCS -- body
  //
  // This is the user-defined task where the main sequence code resides.
  // This method should not be called directly by the user.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.3.6
  void body() {
    uvm_report_warning("uvm_sequence_base", "Frame definition undefined");
    return;
  }

  // Function -- NODOCS -- post_do
  //
  // This function is a user-definable callback function that is called after
  // the driver has indicated that it has completed the item, using either
  // this item_done or put methods. This method should not be called directly
  // by the user.

  // @uvm-ieee 1800.2-2017 auto 14.2.3.7
  void post_do(uvm_sequence_item this_item) {
    return;
  }


  // Task -- NODOCS -- post_body
  //
  // This task is a user-definable callback task that is called after the
  // execution of <body> ~only~ when the sequence is started with <start>.
  // If <start> is called with ~call_pre_post~ set to 0, ~post_body~ is not
  // called.
  // This task is a user-definable callback task that is called after the
  // execution of the body, unless the sequence is started with call_pre_post=0.
  // This method should not be called directly by the user.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.3.8
  void post_body() {
    return;
  }


  // Task -- NODOCS -- post_start
  //
  // This task is a user-definable callback that is called after the
  // optional execution of <post_body>.
  // This method should not be called directly by the user.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.3.9
  void post_start() {
    return;
  }


  // Group -- NODOCS -- Run-Time Phasing
  //

  // Automatic Phase Objection DAP
  private uvm_get_to_lock_dap!(bool) _m_automatic_phase_objection_dap;
  // Starting Phase DAP
  private uvm_get_to_lock_dap!(uvm_phase) _m_starting_phase_dap;

  // Function- m_init_phase_daps
  // Either creates or renames DAPS
  void m_init_phase_daps(bool create) {
    synchronized (this) {
      string apo_name = format("%s.automatic_phase_objection",
			       get_full_name());
      string sp_name = format("%s.starting_phase", get_full_name());

      if (create) {
	_m_automatic_phase_objection_dap =
	  uvm_get_to_lock_dap!(bool).type_id.create(apo_name, get_sequencer());
	_m_starting_phase_dap =
	  uvm_get_to_lock_dap!(uvm_phase).type_id.create(sp_name, get_sequencer());
      }
      else {
	_m_automatic_phase_objection_dap.set_name(apo_name);
	_m_starting_phase_dap.set_name(sp_name);
      }
    }
  }

  // Function -- NODOCS -- get_starting_phase
  // Returns the 'starting phase'.
  //
  // If non-~null~, the starting phase specifies the phase in which this
  // sequence was started.  The starting phase is set automatically when
  // this sequence is started as the default sequence on a sequencer.
  // See <uvm_sequencer_base::start_phase_sequence> for more information.
  //
  // Internally, the <uvm_sequence_base> uses an <uvm_get_to_lock_dap> to 
  // protect the starting phase value from being modified 
  // after the reference has been read.  Once the sequence has ended 
  // its execution (either via natural termination, or being killed),
  // then the starting phase value can be modified again.
  //
  // @uvm-ieee 1800.2-2017 auto 14.2.4.1
  uvm_phase get_starting_phase() {
    synchronized (this) {
      return _m_starting_phase_dap.get();
    }
  }

  // @uvm-ieee 1800.2-2017 auto 14.2.4.2
  void set_starting_phase(uvm_phase phase) {
    synchronized (this) {
      _m_starting_phase_dap.set(phase);
    }
  }
   
  // @uvm-ieee 1800.2-2017 auto 14.2.4.4
  void set_automatic_phase_objection(bool value) {
    synchronized (this) {
      _m_automatic_phase_objection_dap.set(value);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 14.2.4.3
  bool get_automatic_phase_objection() {
    synchronized (this) {
      return _m_automatic_phase_objection_dap.get();
    }
  }

  // m_safe_raise_starting_phase
  void m_safe_raise_starting_phase(string description = "",
				   int count = 1) {
    uvm_phase starting_phase = get_starting_phase();
    if (starting_phase !is null) {
      starting_phase.raise_objection(this, description, count);
    }
  }
  // m_safe_drop_starting_phase
  void m_safe_drop_starting_phase(string description = "",
				  int count = 1) {
    uvm_phase starting_phase = get_starting_phase();
    if (starting_phase !is null) {
      starting_phase.drop_objection(this, description, count);
    }
  }
   
  //------------------------
  // Group -- NODOCS -- Sequence Control
  //------------------------

  // Function -- NODOCS -- set_priority
  //
  // The priority of a sequence may be changed at any point in time.  When the
  // priority of a sequence is changed, the new priority will be used by the
  // sequencer the next time that it arbitrates between sequences.
  //
  // The default priority value for a sequence is 100.  Higher values result
  // in higher priorities.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.2
  void set_priority (int value) {
    synchronized (this) {
      _m_priority = value;
    }
  }


  // Function -- NODOCS -- get_priority
  //
  // This function returns the current priority of the sequence.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.1
  int get_priority() {
    synchronized (this) {
      return _m_priority;
    }
  }


  // Function -- NODOCS -- is_relevant
  //
  // The default is_relevant implementation returns 1, indicating that the
  // sequence is always relevant.
  //
  // Users may choose to override with their own virtual function to indicate
  // to the sequencer that the sequence is not currently relevant after a
  // request has been made.
  //
  // When the sequencer arbitrates, it will call is_relevant on each requesting,
  // unblocked sequence to see if it is relevant. If a 0 is returned, then the
  // sequence will not be chosen.
  //
  // If all requesting sequences are not relevant, then the sequencer will call
  // wait_for_relevant on all sequences and re-arbitrate upon its return.
  //
  // Any sequence that implements is_relevant must also implement
  // wait_for_relevant so that the sequencer has a way to wait for a
  // sequence to become relevant.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.3
  bool is_relevant() {
    synchronized (this) {
      _is_rel_default = true;
      return true;
    }
  }


  // Task -- NODOCS -- wait_for_relevant
  //
  // This method is called by the sequencer when all available sequences are
  // not relevant.  When wait_for_relevant returns the sequencer attempt to
  // re-arbitrate.
  //
  // Returning from this call does not guarantee a sequence is relevant,
  // although that would be the ideal. The method provide some delay to
  // prevent an infinite loop.
  //
  // If a sequence defines is_relevant so that it is not always relevant (by
  // default, a sequence is always relevant), then the sequence must also supply
  // a wait_for_relevant method.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.5.4
  void wait_for_relevant() {
    synchronized (this) {
      _wait_rel_default = true;
      if (_is_rel_default !is _wait_rel_default) {
	uvm_report_fatal("RELMSM",
			 "is_relevant() was implemented without defining" ~
			 " wait_for_relevant()", uvm_verbosity.UVM_NONE);
      }
    }
    sleep();  // this is intended to never return
  }


  // Task -- NODOCS -- lock
  //
  // Requests a lock on the specified sequencer. If sequencer is ~null~, the lock
  // will be requested on the current default sequencer.
  //
  // A lock request will be arbitrated the same as any other request.  A lock is
  // granted after all earlier requests are completed and no other locks or
  // grabs are blocking this sequence.
  //
  // The lock call will return when the lock has been granted.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.5.5
  void lock(uvm_sequencer_base sequencer = null) {
    if (sequencer is null) {
      sequencer = m_sequencer;
    }

    if (sequencer is null) {
      uvm_report_fatal("LOCKSEQR", "Null m_sequencer reference", uvm_verbosity.UVM_NONE);
    }

    sequencer.lock(this);
  }


  // Task -- NODOCS -- grab
  //
  // Requests a lock on the specified sequencer.  If no argument is supplied,
  // the lock will be requested on the current default sequencer.
  //
  // A grab request is put in front of the arbitration queue. It will be
  // arbitrated before any other requests. A grab is granted when no other grabs
  // or locks are blocking this sequence.
  //
  // The grab call will return when the grab has been granted.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.5.6
  void grab(uvm_sequencer_base sequencer = null) {
    if (sequencer is null) {
      if (m_sequencer is null) {
	uvm_report_fatal("GRAB", "Null m_sequencer reference", uvm_verbosity.UVM_NONE);
      }
      m_sequencer.grab(this);
    }
    else {
      sequencer.grab(this);
    }
  }


  // Function -- NODOCS -- unlock
  //
  // Removes any locks or grabs obtained by this sequence on the specified
  // sequencer. If sequencer is ~null~, then the unlock will be done on the
  // current default sequencer.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.7
  void  unlock(uvm_sequencer_base sequencer = null) {
    synchronized (this) {
      if (sequencer is null) {
	if (_m_sequencer is null) {
	  uvm_report_fatal("UNLOCK", "Null m_sequencer reference", uvm_verbosity.UVM_NONE);
	}
	_m_sequencer.unlock(this);
      }
      else {
	sequencer.unlock(this);
      }
    }
  }

  // Function -- NODOCS -- ungrab
  //
  // Removes any locks or grabs obtained by this sequence on the specified
  // sequencer. If sequencer is ~null~, then the unlock will be done on the
  // current default sequencer.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.8
  void  ungrab(uvm_sequencer_base sequencer = null) {
    unlock(sequencer);
  }


  // Function -- NODOCS -- is_blocked
  //
  // Returns a bool indicating whether this sequence is currently prevented from
  // running due to another lock or grab. A 1 is returned if the sequence is
  // currently blocked. A 0 is returned if no lock or grab prevents this
  // sequence from executing. Note that even if a sequence is not blocked, it
  // is possible for another sequence to issue a lock or grab before this
  // sequence can issue a request.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.9
  bool is_blocked() {
    synchronized (this) {
      return _m_sequencer.is_blocked(this);
    }
  }


  // Function -- NODOCS -- has_lock
  //
  // Returns 1 if this sequence has a lock, 0 otherwise.
  //
  // Note that even if this sequence has a lock, a child sequence may also have
  // a lock, in which case the sequence is still blocked from issuing
  // operations on the sequencer.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.10
  bool has_lock() {
    synchronized (this) {
      return _m_sequencer.has_lock(this);
    }
  }


  // Function -- NODOCS -- kill
  //
  // This function will kill the sequence, and cause all current locks and
  // requests in the sequence's default sequencer to be removed. The sequence
  // state will change to UVM_STOPPED, and its post_body() method, if  will not b
  //
  // If a sequence has issued locks, grabs, or requests on sequencers other than
  // the default sequencer, then care must be taken to unregister the sequence
  // with the other sequencer(s) using the sequencer unregister_sequence()
  // method.

  // @uvm-ieee 1800.2-2017 auto 14.2.5.11
  void kill() {
    synchronized (this) {
      if (_m_sequence_process !is null) {
	// If we are not connected to a sequencer, then issue
	// kill locally.
	if (_m_sequencer is null) {
	  m_kill();
	  // We need to drop the objection if we raised it...
	  if (get_automatic_phase_objection()) {
	    m_safe_drop_starting_phase("automatic phase objection");
	  }
	  return;
	}
	// If we are attached to a sequencer, then the sequencer
	// will clear out queues, and then kill this sequence
	_m_sequencer.kill_sequence(this);
	// We need to drop the objection if we raised it...
	if (get_automatic_phase_objection()) {
	  m_safe_drop_starting_phase("automatic phase objection");
	}
	return;
      }
    }
  }

  // Function -- NODOCS -- do_kill
  //
  // Implementation of the do_kill method, as described in P1800.2-2017
  // section 14.2.6.12.
  // 
  // NOTE:  do_kill is documented in error in the P1800.2-2017
  // LRM as a non-virtual function, whereas it is implemented as a virtual function
  //
  // | virtual function void do_kill()
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
  
  // @uvm-ieee 1800.2-2017 auto 14.2.5.12
  void do_kill() {
    return;
  }

  void m_kill() {
    synchronized (this) {
      do_kill();
      foreach (child; _children_array.keys) {
	child.kill();
      }
      if (_m_sequence_process !is null) {
	_m_sequence_process.abort();
	_m_sequence_process = null;
      }
      _m_sequence_state = uvm_sequence_state.UVM_STOPPED;
      if ((_m_parent_sequence !is null) &&
	 (_m_parent_sequence.in_children_array(this))) {
	m_parent_sequence.rem_children_array(this);
      }
      clean_exit_sequence();
    }
  }

  //-------------------------------
  // Group -- NODOCS -- Sequence Item Execution
  //-------------------------------

  // Function -- NODOCS -- create_item
  //
  // Create_item will create and initialize a sequence_item or sequence
  // using the factory.  The sequence_item or sequence will be initialized
  // to communicate with the specified sequencer.

  // @uvm-ieee 1800.2-2017 auto 14.2.6.1
  protected uvm_sequence_item create_item(uvm_object_wrapper type_var,
					  uvm_sequencer_base l_sequencer,
					  string name) {
    synchronized (this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_factory factory = cs.get_factory();
      auto create_item_ = cast (uvm_sequence_item)
	factory.create_object_by_type(type_var, this.get_full_name(), name);
      create_item_.set_item_context(this, l_sequencer);
      return create_item_;
    }
  }


  // Function -- NODOCS -- start_item
  //
  // ~start_item~ and <finish_item> together will initiate operation of
  // a sequence item.  If the item has not already been
  // initialized using create_item, then it will be initialized here to use
  // the default sequencer specified by m_sequencer.  Randomization
  // may be done between start_item and finish_item to ensure late generation
  //

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.6.2
  void start_item (uvm_sequence_item item,
			  int set_priority=-1,
			  uvm_sequencer_base sequencer=null) {
    synchronized (this) {
      if (item is null) {
	uvm_report_fatal("NULLITM",
			 "attempting to start a null item from sequence '" ~
			 get_full_name() ~ "'", uvm_verbosity.UVM_NONE);
	return;
      }

      if (! item.is_item()) {
	uvm_report_fatal("SEQNOTITM",
			 "attempting to start a sequence using start_item()" ~
			 " from sequence '" ~ get_full_name() ~
			 "'. Use seq.start() instead.", uvm_verbosity.UVM_NONE);
	return;
      }

      if (sequencer is null)
	sequencer = item.get_sequencer();

      if (sequencer is null)
	sequencer = get_sequencer();

      if (sequencer is null) {
	uvm_report_fatal("SEQ", "neither the item's sequencer nor dedicated " ~
			 "sequencer has been supplied to start item in " ~
			 get_full_name(), uvm_verbosity.UVM_NONE);
	return;
      }

      item.set_item_context(this, sequencer);

      if (set_priority < 0) {
	set_priority = get_priority();
      }
    }

    sequencer.wait_for_grant(this, set_priority);

    synchronized (this) {
      if (sequencer.is_auto_item_recording_enabled()) {
	sequencer.begin_tr(item, item.get_root_sequence_name(), "Transactions",
			   "", SimTime(0),
			   (m_tr_recorder is null) ? 0 : m_tr_recorder.get_handle());
      }
    }
    pre_do(true);
  }

  // Function -- NODOCS -- finish_item
  //
  // finish_item, together with start_item together will initiate operation of
  // a sequence_item.  Finish_item must be called
  // after start_item with no delays or delta-cycles.  Randomization, or other
  // functions may be called between the start_item and finish_item calls.
  //

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.6.3
  void finish_item (uvm_sequence_item item,
			   int set_priority = -1) {
    uvm_sequencer_base sequencer = item.get_sequencer();

    if (sequencer is null) {
      uvm_report_fatal("STRITM", "sequence_item has null sequencer", uvm_verbosity.UVM_NONE);
    }

    mid_do(item);
    sequencer.send_request(this, item);

    sequencer.wait_for_item_done(this, -1);

    if (sequencer.is_auto_item_recording_enabled()) {
      sequencer.end_tr(item);
    }

    post_do(item);

  }


  // Task -- NODOCS -- wait_for_grant
  //
  // This task issues a request to the current sequencer.  If item_priority is
  // not specified, then the current sequence priority will be used by the
  // arbiter. If a lock_request is made, then the sequencer will issue a lock
  // immediately before granting the sequence.  (Note that the lock may be
  // granted without the sequence being granted if is_relevant is not asserted).
  //
  // When this method returns, the sequencer has granted the sequence, and the
  // sequence must call send_request without inserting any simulation delay
  // other than delta cycles.  The driver is currently waiting for the next
  // item to be sent via the send_request call.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.6.4
  void wait_for_grant(int item_priority = -1, bool lock_request = false) {
    if (m_sequencer is null) {
      uvm_report_fatal("WAITGRANT", "Null m_sequencer reference", uvm_verbosity.UVM_NONE);
    }
    m_sequencer.wait_for_grant(this, item_priority, lock_request);
  }


  // Function -- NODOCS -- send_request
  //
  // The send_request function may only be called after a wait_for_grant call.
  // This call will send the request item to the sequencer, which will forward
  // it to the driver. If the rerandomize bool is set, the item will be
  // randomized before being sent to the driver.

  // @uvm-ieee 1800.2-2017 auto 14.2.6.5
  void send_request(uvm_sequence_item request, bool rerandomize = false) {
    synchronized (this) {
      if (_m_sequencer is null) {
	uvm_report_fatal("SENDREQ", "Null m_sequencer reference", uvm_verbosity.UVM_NONE);
      }
      _m_sequencer.send_request(this, request, rerandomize);
    }
  }


  // Task -- NODOCS -- wait_for_item_done
  //
  // A sequence may optionally call wait_for_item_done.  This task will block
  // until the driver calls item_done or put.  If no transaction_id parameter
  // is specified, then the call will return the next time that the driver calls
  // item_done or put.  If a specific transaction_id is specified, then the call
  // will return when the driver indicates completion of that specific item.
  //
  // Note that if a specific transaction_id has been specified, and the driver
  // has already issued an item_done or put for that transaction, then the call
  // will hang, having missed the earlier notification.

  // task
  // @uvm-ieee 1800.2-2017 auto 14.2.6.6
  void wait_for_item_done(int transaction_id = -1) {
    if (m_sequencer is null) {
      uvm_report_fatal("WAITITEMDONE", "Null m_sequencer reference", uvm_verbosity.UVM_NONE);
    }
    m_sequencer.wait_for_item_done(this, transaction_id);
  }



  // Group -- NODOCS -- Response API
  //--------------------

  // Function -- NODOCS -- use_response_handler
  //
  // When called with enable set to 1, responses will be sent to the response
  // handler. Otherwise, responses must be retrieved using get_response.
  //
  // By default, responses from the driver are retrieved in the sequence by
  // calling get_response.
  //
  // An alternative method is for the sequencer to call the response_handler
  // function with each response.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.1
  void use_response_handler(bool enable) {
    synchronized (this) {
      _m_use_response_handler = enable;
    }
  }


  // Function -- NODOCS -- get_use_response_handler
  //
  // Returns the state of the use_response_handler bool.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.2
  bool get_use_response_handler() {
    synchronized (this) {
      return _m_use_response_handler;
    }
  }


  // Function -- NODOCS -- response_handler
  //
  // When the use_response_handler bool is set to 1, this virtual task is called
  // by the sequencer for each response that arrives for this sequence.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.3
  void response_handler(uvm_sequence_item response) {
    return;
  }


  // Function -- NODOCS -- set_response_queue_error_report_enabled
  //
  // By default, if the internal response queue overflows, an error is
  // reported.  The response queue will overflow if more responses are
  // sent to this from the driver than ~get_response~ calls are made.
  //
  // Setting the value to '0' disables these errors, while setting it to
  // '1' enables them.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.5
  void set_response_queue_error_report_enabled(bool value) {
    synchronized (this) {
      _response_queue_error_report_enabled = value;
    }
  }

  // Function -- NODOCS -- get_response_queue_error_report_enabled
  //
  // When this bit is '1' (default value), error reports are generated when
  // the response queue overflows.  When this bit is '0', no such error
  // reports are generated.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.4
  bool get_response_queue_error_report_enabled() {
    synchronized (this) {
      return _response_queue_error_report_enabled;
    }
  }


  // Function -- NODOCS -- set_response_queue_depth
  //
  // The default maximum depth of the response queue is 8. These method is used
  // to examine or change the maximum depth of the response queue.
  //
  // Setting the response_queue_depth to -1 indicates an arbitrarily deep
  // response queue.  No checking is done.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.7
  void set_response_queue_depth(int value) {
    synchronized (this) {
      _response_queue_depth = value;
    }
  }


  // Function -- NODOCS -- get_response_queue_depth
  //
  // Returns the current depth setting for the response queue.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.6
  int get_response_queue_depth() {
    synchronized (this) {
      return _response_queue_depth;
    }
  }


  // Function -- NODOCS -- clear_response_queue
  //
  // Empties the response queue for this sequence.

  // @uvm-ieee 1800.2-2017 auto 14.2.7.8
  void clear_response_queue() {
    synchronized (this) {
      _response_queue.clear();
    }
  }


  void put_base_response(uvm_sequence_item response) {
    synchronized (this) {
      if ((_response_queue_depth == -1) ||
	  (_response_queue.length < _response_queue_depth)) {
	_response_queue.pushBack(response);
	_response_queue_event.notify();
	return;
      }
      if (_response_queue_error_report_enabled) {
	uvm_report_error(get_full_name(), "Response queue overflow, " ~
			 "response was dropped", uvm_verbosity.UVM_NONE);
      }
    }
  }


  // Function- put_response
  //
  // Internal method.

  void put_response (uvm_sequence_item response_item) {
    put_base_response(response_item); // no error-checking
  }


  // Function- get_base_response

  // task
  void get_base_response(out uvm_sequence_item response,
				int transaction_id = -1) {

    // if (_response_queue.length is 0) {
    //   wait(_response_queue.length !is 0);
    // }
    while (response_queue_length == 0) {
      _response_queue_event.wait();
    }

    synchronized (this) {
      if (transaction_id == -1) {
	response = _response_queue.front();
	_response_queue.removeFront();
	return;
      }
    }

    while (true) {
      size_t queue_size;
      synchronized (this) {
	queue_size = _response_queue.length;
	for (size_t i = 0; i < queue_size; i++) {
	  if (_response_queue[i].get_transaction_id() == transaction_id) {
	    response = cast (uvm_sequence_item) _response_queue[i];
	    _response_queue.remove(i);
	    return;
	  }
	}
      }
      // wait(response_queue.length != queue_size);
      while (response_queue_length() == queue_size) {
	_response_queue_event.wait();
      }
    }
  }


  //----------------------
  // Misc Internal methods
  //----------------------


  // m_get_sqr_sequence_id
  // ---------------------

  int m_get_sqr_sequence_id(int sequencer_id, bool update_sequence_id) {
    synchronized (this) {
      if (sequencer_id in _m_sqr_seq_ids) {
	if (update_sequence_id is true) {
	  set_sequence_id(_m_sqr_seq_ids[sequencer_id]);
	}
	return _m_sqr_seq_ids[sequencer_id];
      }

      if (update_sequence_id is true) {
	set_sequence_id(-1);
      }

      return -1;
    }
  }


  // m_set_sqr_sequence_id
  // ---------------------

  void m_set_sqr_sequence_id(int sequencer_id, int sequence_id) {
    synchronized (this) {
      _m_sqr_seq_ids[sequencer_id] = sequence_id;
      set_sequence_id(sequence_id);
    }
  }


  // Title -- NODOCS -- Sequence-Related Macros



  //-----------------------------------------------------------------------------
  //
  // Group -- NODOCS -- Sequence Action Macros
  //
  // These macros are used to start sequences and sequence items on the default
  // sequencer, ~m_sequencer~. This is determined a number of ways.
  // - the sequencer handle provided in the <uvm_sequence_base::start> method
  // - the sequencer used by the parent sequence
  // - the sequencer that was set using the <uvm_sequence_item::set_sequencer> method
  //-----------------------------------------------------------------------------

  // MACRO -- NODOCS -- `uvm_create
  //
  //| `uvm_create(SEQ_OR_ITEM)
  //
  // This action creates the item or sequence using the factory.  It intentionally
  // does zero processing.  After this action completes, the user can manually set
  // values, manipulate rand_mode and constraint_mode, etc.

  void uvm_create(T)(ref T SEQ_OR_ITEM) if (is (T: uvm_sequence_item)){
    uvm_create_on(SEQ_OR_ITEM, m_sequencer());
  }


  // MACRO -- NODOCS -- `uvm_do
  //
  //| `uvm_do(SEQ_OR_ITEM)
  //
  // This macro takes as an argument a uvm_sequence_item variable or object.
  // The argument is created using <`uvm_create> if necessary,
  // then randomized.
  // In the case of an item, it is randomized after the call to
  // <uvm_sequence_base::start_item()> returns.
  // This is called late-randomization.
  // In the case of a sequence, the sub-sequence is started using
  // <uvm_sequence_base::start()> with ~call_pre_post~ set to 0.
  // In the case of an item,
  // the item is sent to the driver through the associated sequencer.
  //
  // For a sequence item, the following are called, in order
  //
  //|
  //|   `uvm_create(item)
  //|   sequencer.wait_for_grant(prior) (task)
  //|   this.pre_do(1)                  (task)
  //|   item.randomize()
  //|   this.mid_do(item)               (func)
  //|   sequencer.send_request(item)    (func)
  //|   sequencer.wait_for_item_done()  (task)
  //|   this.post_do(item)              (func)
  //|
  //
  // For a sequence, the following are called, in order
  //
  //|
  //|   `uvm_create(sub_seq)
  //|   sub_seq.randomize()
  //|   sub_seq.pre_start()         (task)
  //|   this.pre_do(0)              (task)
  //|   this.mid_do(sub_seq)        (func)
  //|   sub_seq.body()              (task)
  //|   this.post_do(sub_seq)       (func)
  //|   sub_seq.post_start()        (task)
  //|

  void uvm_do(T) (ref T SEQ_OR_ITEM)
    if (is (T: uvm_sequence_item)) {
    uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, m_sequencer(), -1);
  }


  // MACRO -- NODOCS -- `uvm_do_pri
  //
  //| `uvm_do_pri(SEQ_OR_ITEM, PRIORITY)
  //
  // This is the same as `uvm_do except that the sequene item or sequence is
  // executed with the priority specified in the argument

  void uvm_do_pri(T) (ref T SEQ_OR_ITEM, int PRIORITY)
    if (is (T: uvm_sequence_item)){
      uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, m_sequencer, PRIORITY);
    }


  // FIXME add bitvectors to this template filter
  template allIntengral(V...) {
    static if (V.length == 0) {
      enum bool allIntengral = true;
    }
    else static if (isIntegral!(V[0])) {
	enum bool allIntengral = allIntengral!(V[1..$]);
      }
      else enum bool allIntengral = false;
  }

  // MACRO -- NODOCS -- `uvm_do_with
  //
  //| `uvm_do_with(SEQ_OR_ITEM, CONSTRAINTS)
  //
  // This is the same as `uvm_do except that the constraint block in the 2nd
  // argument is applied to the item or sequence in a randomize with statement
  // before execution.

  void uvm_do_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, V values)
    if (is (T: uvm_sequence_item)) {
    uvm_do_on_pri_with!CONSTRAINTS(SEQ_OR_ITEM, m_sequencer(), -1, values);
  }


  // MACRO -- NODOCS -- `uvm_do_pri_with
  //
  //| `uvm_do_pri_with(SEQ_OR_ITEM, PRIORITY, CONSTRAINTS)
  //
  // This is the same as `uvm_do_pri except that the given constraint block is
  // applied to the item or sequence in a randomize with statement before
  // execution.

  void uvm_do_pri_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, int PRIORITY, values)
    if (is (T: uvm_sequence_item)) {
    uvm_do_on_pri_with!CONSTRAINTS(SEQ_OR_ITEM, m_sequencer(),
				   PRIORITY, values);
  }


  //-----------------------------------------------------------------------------
  //
  // Group -- NODOCS -- Sequence on Sequencer Action Macros
  //
  // These macros are used to start sequences and sequence items on a specific
  // sequencer. The sequence or item is created and executed on the given
  // sequencer.
  //-----------------------------------------------------------------------------

  // MACRO -- NODOCS -- `uvm_create_on
  //
  //| `uvm_create_on(SEQ_OR_ITEM, SEQR)
  //
  // This is the same as <`uvm_create> except that it also sets the parent sequence
  // to the sequence in which the macro is invoked, and it sets the sequencer to
  // the specified ~SEQR~ argument.

  // FIXME -- consider changing SEQ_OR_ITEM and SEQR to aliases passed as temaplte arguments
  void uvm_create_on(T, U)(ref T SEQ_OR_ITEM, U SEQR)
    if (is (T: uvm_sequence_item) && is (U: uvm_sequencer_base)) {
      uvm_object_wrapper w_ = SEQ_OR_ITEM.get_type();
      SEQ_OR_ITEM = cast (T) create_item(w_, SEQR, "SEQ_OR_ITEM");
    }


  // MACRO -- NODOCS -- `uvm_do_on
  //
  //| `uvm_do_on(SEQ_OR_ITEM, SEQR)
  //
  // This is the same as <`uvm_do> except that it also sets the parent sequence to
  // the sequence in which the macro is invoked, and it sets the sequencer to the
  // specified ~SEQR~ argument.

  void uvm_do_on(T, U)(ref T SEQ_OR_ITEM, U SEQR)
    if (is (T: uvm_sequence_item) && is (U: uvm_sequencer_base)) {
      uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, SEQR, -1);
    }


  // MACRO -- NODOCS -- `uvm_do_on_pri
  //
  //| `uvm_do_on_pri(SEQ_OR_ITEM, SEQR, PRIORITY)
  //
  // This is the same as <`uvm_do_pri> except that it also sets the parent sequence
  // to the sequence in which the macro is invoked, and it sets the sequencer to
  // the specified ~SEQR~ argument.

  void uvm_do_on_pri(T, U)(ref T SEQ_OR_ITEM,
			   U SEQR, int PRIORITY)
    if (is (T: uvm_sequence_item) && is (U: uvm_sequencer_base)) {
      uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, SEQR, PRIORITY);
    }

  // MACRO -- NODOCS -- `uvm_do_on_with
  //
  //| `uvm_do_on_with(SEQ_OR_ITEM, SEQR, CONSTRAINTS)
  //
  // This is the same as <`uvm_do_with> except that it also sets the parent
  // sequence to the sequence in which the macro is invoked, and it sets the
  // sequencer to the specified ~SEQR~ argument.
  // The user must supply brackets around the constraints.

  void uvm_do_on_with(string CONSTRAINTS, T, U, V...)
    (ref T SEQ_OR_ITEM, U SEQR, V values)
    if (is (T: uvm_sequence_item) && is (U: uvm_sequencer_base)) {
      uvm_do_on_pri_with!CONSTRAINTS(SEQ_OR_ITEM, SEQR, -1, values);
    }


  // MACRO -- NODOCS -- `uvm_do_on_pri_with
  //
  //| `uvm_do_on_pri_with(SEQ_OR_ITEM, SEQR, PRIORITY, CONSTRAINTS)
  //
  // This is the same as `uvm_do_pri_with except that it also sets the parent
  // sequence to the sequence in which the macro is invoked, and it sets the
  // sequencer to the specified ~SEQR~ argument.

  void uvm_do_on_pri_with(string CONSTRAINTS, T, U, V...)
    (ref T SEQ_OR_ITEM, U SEQR, int PRIORITY, V values)
    if (is (T: uvm_sequence_item) && is (U: uvm_sequencer_base)) {
      uvm_create_on(SEQ_OR_ITEM, SEQR);
      uvm_sequence_base seq_ = cast (uvm_sequence_base) SEQ_OR_ITEM;
      if (seq_ is null) {
	start_item(SEQ_OR_ITEM, PRIORITY);
      }
      version(UVM_NO_RAND) {}
      else {
	if ((seq_ is null || ! seq_.do_not_randomize)) {
	  try {
	    SEQ_OR_ITEM.randomizeWith!(CONSTRAINTS)(values);
	  }
	  catch {
	    uvm_warning("RNDFLD",
			"Randomization failed in uvm_do_with action");
	  }
	}
	else {
	    uvm_warning("RNDFLD",
			"Randomization failed in uvm_do_with action (seq_ is null || ! seq_.do_not_randomize)");
	}
      }
      seq_ = cast (uvm_sequence_base) SEQ_OR_ITEM;
      if (seq_ is null) finish_item(SEQ_OR_ITEM, PRIORITY);
      else seq_.start(SEQR, this, PRIORITY, 0);
    }


  //-----------------------------------------------------------------------------
  //
  // Group -- NODOCS -- Sequence Action Macros for Pre-Existing Sequences
  //
  // These macros are used to start sequences and sequence items that do not
  // need to be created.
  //-----------------------------------------------------------------------------


  // MACRO -- NODOCS -- `uvm_send
  //
  //| `uvm_send(SEQ_OR_ITEM)
  //
  // This macro processes the item or sequence that has been created using
  // `uvm_create.  The processing is done without randomization.  Essentially, an
  // `uvm_do without the create or randomization.

  void uvm_send(T)(ref T SEQ_OR_ITEM)
    if (is (T: uvm_sequence_item)) {
    uvm_send_pri(SEQ_OR_ITEM, -1);
  }


  // MACRO -- NODOCS -- `uvm_send_pri
  //
  //| `uvm_send_pri(SEQ_OR_ITEM, PRIORITY)
  //
  // This is the same as `uvm_send except that the sequene item or sequence is
  // executed with the priority specified in the argument.

  void uvm_send_pri(T)(T SEQ_OR_ITEM, int PRIORITY)
    if (is (T: uvm_sequence_item)) {
      uvm_sequence_base _seq = cast (uvm_sequence_base) SEQ_OR_ITEM;
      if (_seq is null) {
	start_item(SEQ_OR_ITEM, PRIORITY);
	finish_item(SEQ_OR_ITEM, PRIORITY);
      }
      else _seq.start(_seq.get_sequencer(), this, PRIORITY, 0);
    }


  // MACRO -- NODOCS -- `uvm_rand_send
  //
  //| `uvm_rand_send(SEQ_OR_ITEM)
  //
  // This macro processes the item or sequence that has been already been
  // allocated (possibly with `uvm_create). The processing is done with
  // randomization.  Essentially, an `uvm_do without the create.

  void uvm_rand_send(T)(ref T SEQ_OR_ITEM)
    if (is (T: uvm_sequence_item)) {
      uvm_rand_send_pri_with!q{}(SEQ_OR_ITEM, -1);
    }


  // MACRO -- NODOCS -- `uvm_rand_send_pri
  //
  //| `uvm_rand_send_pri(SEQ_OR_ITEM, PRIORITY)
  //
  // This is the same as `uvm_rand_send except that the sequene item or sequence
  // is executed with the priority specified in the argument.

  void uvm_rand_send_pri(T)(ref T SEQ_OR_ITEM, int PRIORITY)
    if (is (T: uvm_sequence_item)) {
      uvm_rand_send_pri_with!q{}(SEQ_OR_ITEM, PRIORITY);
    }

  // MACRO -- NODOCS -- `uvm_rand_send_with
  //
  //| `uvm_rand_send_with(SEQ_OR_ITEM, CONSTRAINTS)
  //
  // This is the same as `uvm_rand_send except that the given constraint block is
  // applied to the item or sequence in a randomize with statement before
  // execution.

  void uvm_rand_send_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, V values)
    if (is (T: uvm_sequence_item)) {
    uvm_rand_send_pri_with!CONSTRAINTS(SEQ_OR_ITEM, -1, values);
  }

  // MACRO -- NODOCS -- `uvm_rand_send_pri_with
  //
  //| `uvm_rand_send_pri_with(SEQ_OR_ITEM, PRIORITY, CONSTRAINTS)
  //
  // This is the same as `uvm_rand_send_pri except that the given constraint block
  // is applied to the item or sequence in a randomize with statement before
  // execution.

  void uvm_rand_send_pri_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, int PRIORITY, V values)
    if (is (T: uvm_sequence_item)) {
    uvm_sequence_base seq_ = cast (uvm_sequence_base) SEQ_OR_ITEM;
    if (seq_ is null) start_item(SEQ_OR_ITEM, PRIORITY);
    else seq_.set_item_context(this,SEQ_OR_ITEM.get_sequencer());
    version(UVM_NO_RAND) {}
    else {
      if ((seq_ is null || !seq_.do_not_randomize)) {
	try {
	  SEQ_OR_ITEM.randomizeWith!(CONSTRAINTS)(values);
	}
	catch {
	  uvm_warning("RNDFLD",
		      "Randomization failed in uvm_rand_send_with action");
	}
      }
      else {
	  uvm_warning("RNDFLD",
		      "Randomization failed in uvm_rand_send_with action (seq_ is null || !seq_.do_not_randomize)");
      }
    }
    seq_ = cast (uvm_sequence_base) SEQ_OR_ITEM;
    if (seq_ is null) finish_item(SEQ_OR_ITEM, PRIORITY);
    else _seq_.start(_seq_.get_sequencer(), this, PRIORITY, 0);
  }


  void uvm_create_seq(T, U)(ref T UVM_SEQ, U SEQR_CONS_IF) {
    uvm_create_on(UVM_SEQ, SEQR_CONS_IF.consumer_seqr);
  }

  void uvm_do_seq(T, U)(ref T UVM_SEQ, U SEQR_CONS_IF) {
    uvm_do_on(UVM_SEQ, SEQR_CONS_IF.consumer_seqr);
  }

  void uvm_do_seq_with(string CONSTRAINTS, T, U, V...)
    (ref T UVM_SEQ, U SEQR_CONS_IF, V values) {
    uvm_do_on_with!CONSTRAINTS(UVM_SEQ, SEQR_CONS_IF.consumer_seqr, values);
  }


  //-----------------------------------------------------------------------------
  //
  // Group -- NODOCS -- Sequencer Subtypes
  //
  //-----------------------------------------------------------------------------


  // MACRO -- NODOCS -- `uvm_declare_p_sequencer
  //
  // This macro is used to declare a variable ~p_sequencer~ whose type is
  // specified by ~SEQUENCER~.
  //
  //| `uvm_declare_p_sequencer(SEQUENCER)
  //
  // The example below shows using the the `uvm_declare_p_sequencer macro
  // along with the uvm_object_utils macros to set up the sequence but
  // not register the sequence in the sequencer's library.
  //
  //| class mysequence extends uvm_sequence#(mydata);
  //|   `uvm_object_utils(mysequence)
  //|   `uvm_declare_p_sequencer(some_seqr_type)
  //|   task body;
  //|     //Access some variable in the user's custom sequencer
  //|     if (p_sequencer.some_variable) begin
  //|       ...
  //|     end
  //|   endtask
  //| endclass
  //

  mixin template uvm_declare_p_sequencer(SEQUENCER) {
    SEQUENCER p_sequencer;
    override void m_set_p_sequencer() {
      super.m_set_p_sequencer();
      p_sequencer = cast (SEQUENCER) m_sequencer;
      if (p_sequencer is null) {
	import std.string: format;
	uvm_fatal("DCLPSQ",
		  format("%m %s Error casting p_sequencer, please verify" ~
			 " that this sequence/sequence item is intended " ~
			 "to execute on this type of sequencer",
			 get_full_name()));
      }
    }
  }
}
