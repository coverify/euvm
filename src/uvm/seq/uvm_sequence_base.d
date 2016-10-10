//----------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010-2011 Synopsys, Inc.
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

module uvm.seq.uvm_sequence_base;


//------------------------------------------------------------------------------
//
// CLASS: uvm_sequence_base
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
// <pre_frame> and <post_frame> methods are called.
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
//|   sub_seq.pre_frame()         (task)  if call_pre_post==1
//|     parent_seq.pre_do(0)     (task)  if parent_sequence !is null
//|     parent_seq.mid_do(this)  (func)  if parent_sequence !is null
//|   sub_seq.frame               (task)  YOUR STIMULUS CODE
//|     parent_seq.post_do(this) (func)  if parent_sequence !is null
//|   sub_seq.post_frame()        (task)  if call_pre_post==1
//|   sub_seq.post_start()       (task)
//
//
// Executing sub-sequences via `uvm_do macros:
//
// A sequence can also be indirectly started as a child in the <frame> of a
// parent sequence. The child sequence's <start> method is called indirectly
// by invoking any of the `uvm_do macros.
// In these cases, <start> is called with
// ~call_pre_post~ set to 0, preventing the started sequence's <pre_frame> and
// <post_frame> methods from being called. During execution of the
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
//|     sub_seq.frame()            (task)
//|   parent_seq.post_do(sub_seq) (func)
//|   sub_seq.post_start()        (task)
//|
//
// Remember, it is the *parent* sequence's pre|mid|post_do that are called, not
// the sequence being executed.
//
//
// Executing sequence items via <start_item>/<finish_item> or `uvm_do macros:
//
// Items are started in the <frame> of a parent sequence via calls to
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
import uvm.base.uvm_phase;
import uvm.base.uvm_message_defines;
import uvm.base.uvm_tr_stream;
import uvm.dap.uvm_get_to_lock_dap;
import uvm.meta.misc;

import esdl.base.core;
import esdl.data.queue;

version(UVM_NO_RAND) {}
 else {
   import esdl.data.rand;
 }

import std.string;
version(UVM_INCLUDE_DEPRECATED) {
   version = UVM_DEPRECATED_STARTING_PHASE;
 }

class uvm_sequence_base: uvm_sequence_item
{
  mixin(uvm_sync_string);

  @uvm_immutable_sync
  private WithEvent!uvm_sequence_state _m_sequence_state;

  @uvm_public_sync
  private int _m_next_transaction_id = 1;

  int inc_next_transaction_id() {
    synchronized(this) {
      return _m_next_transaction_id++;
    }
  }

  private int                  _m_priority = -1;
  @uvm_public_sync
  private uvm_recorder _m_tr_recorder;
  @uvm_public_sync
  private int _m_wait_for_grant_semaphore;

  int inc_wait_for_grant_semaphore() {
    synchronized(this) {
      return _m_wait_for_grant_semaphore++;
    }
  }
  int dec_wait_for_grant_semaphore() {
    synchronized(this) {
      return _m_wait_for_grant_semaphore--;
    }
  }

  // Each sequencer will assign a sequence id.  When a sequence is talking to multiple
  // sequencers, each sequence_id is managed separately

  // protected
  private int[int] _m_sqr_seq_ids;

  private bool[uvm_sequence_base] _children_array;
  void add_children_array(uvm_sequence_base seq) {
    synchronized(this) {
      _children_array[seq] = true;
    }
  }
  void rem_children_array(uvm_sequence_base seq) {
    synchronized(this) {
      _children_array.remove(seq);
    }
  }
  bool in_children_array(uvm_sequence_base seq) {
    synchronized(this) {
      if(seq in _children_array) {
	return true;
      }
      else {
	return false;
      }
    }
  }

  private Queue!uvm_sequence_item _response_queue;
  size_t response_queue_length() {
    synchronized(this) {
      return _response_queue.length;
    }
  }

  // protected
  private Event                   _response_queue_event;
  // protected
  private int                     _response_queue_depth = 8;
  // protected
  private bool                    _response_queue_error_report_disabled;

  // Variable: do_not_randomize
  //
  // If set, prevents the sequence from being randomized before being executed
  // by the `uvm_do*() and `uvm_rand_send*() macros,
  // or as a default sequence.
  //
  @uvm_public_sync
  private bool _do_not_randomize;

  @uvm_protected_sync
  private Process _m_sequence_process;
  private bool _m_use_response_handler;

  enum string type_name = "uvm_sequence_base";

  // bools to detect if is_relevant()/wait_for_relevant() are implemented
  private bool _is_rel_default;
  private bool _wait_rel_default;


  // Function: new
  //
  // The constructor for uvm_sequence_base.
  //
  this(string name = "uvm_sequence") {
    synchronized(this) {
      super(name);
      _m_sequence_state = new WithEvent!uvm_sequence_state("_m_sequence_state");
      _m_sequence_state = UVM_CREATED;
      _m_wait_for_grant_semaphore = 0;
      _response_queue_event.initialize("_response_queue_event");
      m_init_phase_daps(true);
    }
  }


  // Function: is_item
  //
  // Returns 1 on items and 0 on sequences. As this object is a sequence,
  // ~is_item~ will always return 0.
  //
  override bool is_item() {
    return false;
  }


  // Function: get_sequence_state
  //
  // Returns the sequence state as an enumerated value. Can use to wait on
  // the sequence reaching or changing from one or more states.
  //
  //| wait(get_sequence_state() & (UVM_STOPPED|UVM_FINISHED));

  uvm_sequence_state get_sequence_state() {
    synchronized(this) {
      return _m_sequence_state;
    }
  }


  // Task: wait_for_sequence_state
  //
  // Waits until the sequence reaches the given ~state~. If the sequence
  // is already in this state, this method returns immediately. Convenience
  // for wait ( get_sequence_state == ~state~ );
  //| wait_for_sequence_state(UVM_STOPPED|UVM_FINISHED);

  // task
  void wait_for_sequence_state(uvm_sequence_state state_mask) {
    while((m_sequence_state.get & state_mask) == 0) {
      m_sequence_state.getEvent.wait();
    }
  }

  // Function: get_tr_handle
  //
  // Returns the integral recording transaction handle for this sequence.
  // Can be used to associate sub-sequences and sequence items as
  // child transactions when calling <uvm_component::begin_child_tr>.

  override int get_tr_handle() {
    synchronized(this) {
      if (_m_tr_recorder !is null) {
	return _m_tr_recorder.get_handle();
      }
      else {
	return 0;
      }
    }
  }

  
  //--------------------------
  // Group: Sequence Execution
  //--------------------------


  // Task: start
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
  // If ~call_pre_post~ is set to 1 (default), then the <pre_frame> and
  // <post_frame> tasks will be called before and after the sequence
  // <frame> is called.

  // task
  void start(uvm_sequencer_base sequencer,
	     uvm_sequence_base parent_sequence = null,
	     int this_priority = -1,
	     bool call_pre_post = true) {

    synchronized(this) {
      set_item_context(parent_sequence, sequencer);

      // if (!(m_sequence_state inside {CREATED,STOPPED,FINISHED}))
      if(_m_sequence_state != UVM_CREATED &&
	 _m_sequence_state != UVM_STOPPED &&
	 _m_sequence_state != UVM_FINISHED) {
	uvm_report_fatal("SEQ_NOT_DONE",
			 "Sequence " ~ get_full_name() ~ " already started",
			 UVM_NONE);
      }

      if(_m_parent_sequence !is null) {
	synchronized(_m_parent_sequence) {
	  _m_parent_sequence.add_children_array(this);
	}
      }

      if (this_priority < -1) {
	uvm_report_fatal("SEQPRI",
			 format("Sequence %s start has illegal priority: %0d",
				get_full_name(),
				this_priority), UVM_NONE);
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
	uvm_tr_stream stream;
	if (_m_parent_sequence is null) {
	  stream = _m_sequencer.get_tr_stream(get_name(), "Transactions");
	  handle = _m_sequencer.begin_tr(this, get_name());
	  _m_tr_recorder = uvm_recorder.get_recorder_from_handle(handle);
	}
	else {
	  stream = _m_sequencer.get_tr_stream(get_root_sequence_name(), "Transactions");
	  handle = _m_sequencer.begin_child_tr(this,
					       (_m_parent_sequence.m_tr_recorder is null) ? 0 : _m_parent_sequence.m_tr_recorder.get_handle(), 
					       get_root_sequence_name());
	  _m_tr_recorder = uvm_recorder.get_recorder_from_handle(handle);
	}
      }

      // Ensure that the sequence_id is intialized in case this sequence has been stopped previously
      set_sequence_id(-1);
      // Remove all sqr_seq_ids
      _m_sqr_seq_ids = null;

      // Register the sequence with the sequencer if defined.
      if (_m_sequencer !is null) {
	_m_sequencer.m_register_sequence(this);
      }
    }

    // Change the state to PRE_START, do this before the fork so that
    // the "if (!(m_sequence_state inside {...}" works
    m_sequence_state = UVM_PRE_START;
    
    auto seqFork = fork!("uvm_sequence_base/start")({
	m_sequence_process = Process.self;

	wait(0);

        // Raise the objection if enabled
        // (This will lock the uvm_get_to_lock_dap)
        if (get_automatic_phase_objection()) {
	  m_safe_raise_starting_phase("automatic phase objection");
	}
         
	pre_start();

	if (call_pre_post is true) {
	  m_sequence_state = UVM_PRE_FRAME;
	  wait(0);
	  pre_frame();
	}

	if (parent_sequence !is null) {
	  parent_sequence.pre_do(0);    // task
	  parent_sequence.mid_do(this); // function
	}

	m_sequence_state = UVM_FRAME;
	wait(0);
	frame();

	m_sequence_state = UVM_ENDED;
	wait(0);

	if(parent_sequence !is null) {
	  parent_sequence.post_do(this);
	}

	if (call_pre_post is true) {
	  m_sequence_state = UVM_POST_FRAME;
	  wait(0);
	  post_frame();
	}

	m_sequence_state = UVM_POST_START;
	wait(0);
	post_start();

        // Drop the objection if enabled
        if (get_automatic_phase_objection()) {
	  m_safe_drop_starting_phase("automatic phase objection");
        }
         
	m_sequence_state = UVM_FINISHED;
	wait(0);

      });
    seqFork.joinAll();

    synchronized(this) {
      if (_m_sequencer !is null) {
	_m_sequencer.end_tr(this);
      }

      // Clean up any sequencer queues after exiting; if we
      // were forcibly stoped, this step has already taken place
      if (_m_sequence_state != UVM_STOPPED) {
	if (_m_sequencer !is null) {
	  _m_sequencer.m_sequence_exiting(this);
	}
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


  // Task: pre_start
  //
  // This task is a user-definable callback that is called before the
  // optional execution of <pre_frame>.
  // This method should not be called directly by the user.

  // task
  void pre_start() {
    return;
  }


  // Task: pre_frame
  //
  // This task is a user-definable callback that is called before the
  // execution of <frame> ~only~ when the sequence is started with <start>.
  // If <start> is called with ~call_pre_post~ set to 0, ~pre_frame~ is not
  // called.
  // This method should not be called directly by the user.

  // task
  void pre_frame() {
    return;
  }


  // Task: pre_do
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
  void pre_do(bool is_item) {
    return;
  }


  // Function: mid_do
  //
  // This function is a user-definable callback function that is called after
  // the sequence item has been randomized, and just before the item is sent
  // to the driver.  This method should not be called directly by the user.

  void mid_do(uvm_sequence_item this_item) {
    return;
  }


  // Task: frame
  //
  // This is the user-defined task where the main sequence code resides.
  // This method should not be called directly by the user.

  // task
  void frame() {
    uvm_report_warning("uvm_sequence_base", "Frame definition undefined");
    return;
  }

  // Function: post_do
  //
  // This function is a user-definable callback function that is called after
  // the driver has indicated that it has completed the item, using either
  // this item_done or put methods. This method should not be called directly
  // by the user.

  void post_do(uvm_sequence_item this_item) {
    return;
  }


  // Task: post_frame
  //
  // This task is a user-definable callback task that is called after the
  // execution of <frame> ~only~ when the sequence is started with <start>.
  // If <start> is called with ~call_pre_post~ set to 0, ~post_frame~ is not
  // called.
  // This task is a user-definable callback task that is called after the
  // execution of the frame, unless the sequence is started with call_pre_post=0.
  // This method should not be called directly by the user.

  // task
  void post_frame() {
    return;
  }


  // Task: post_start
  //
  // This task is a user-definable callback that is called after the
  // optional execution of <post_frame>.
  // This method should not be called directly by the user.

  // task
  void post_start() {
    return;
  }


  // Group: Run-Time Phasing
  //

  // Automatic Phase Objection DAP
  private uvm_get_to_lock_dap!(bool) _m_automatic_phase_objection_dap;
  // Starting Phase DAP
  private uvm_get_to_lock_dap!(uvm_phase) _m_starting_phase_dap;

  // Function- m_init_phase_daps
  // Either creates or renames DAPS
  void m_init_phase_daps(bool create) {
    synchronized(this) {
      string apo_name = format("%s.automatic_phase_objection",
			       get_full_name());
      string sp_name = format("%s.starting_phase", get_full_name());

      if(create) {
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

  version(UVM_DEPRECATED_STARTING_PHASE) {
    // DEPRECATED!! Use get/set_starting_phase accessors instead!
    uvm_phase _starting_phase;
    // Value set via set_starting_phase
    uvm_phase _m_set_starting_phase;
    // Ensures we only warn once per sequence
    bool _m_warn_deprecated_set;
  }
   
    // Function: get_starting_phase
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
  uvm_phase get_starting_phase() {
    synchronized(this) {
      version(UVM_DEPRECATED_STARTING_PHASE) {
      	bool throw_error;

      	if (_starting_phase !is _m_set_starting_phase) {
      	  if (! _m_warn_deprecated_set) {
      	    uvm_warning("UVM_DEPRECATED", "'starting_phase' is deprecated and" ~
      			" not part of the UVM standard.  See documentation" ~
      			" for uvm_sequence_base::set_starting_phase");
      	    _m_warn_deprecated_set = true;
      	  }
           
      	  if (_m_starting_phase_dap.try_set(_starting_phase)) {
      	    _m_set_starting_phase = _starting_phase;
      	  }
      	  else {
      	    uvm_phase dap_phase = _m_starting_phase_dap.get();
      	    uvm_error("UVM/SEQ/LOCK_DEPR",
      		      "The deprecated 'starting_phase' variable has been"~
      		      " set to '" ~ (_starting_phase is null) ? "<null>" :
      		      _starting_phase.get_full_name() ~ "' after a call to" ~
      		      " get_starting_phase locked the value to '" ~
      		      (dap_phase is null) ? "<null>" :
      		      dap_phase.get_full_name() ~ "'.  See documentation" ~
      		      " for uvm_sequence_base::set_starting_phase.");
      	  }
      	}
      }
      return _m_starting_phase_dap.get();
    }
  }

  // Function: set_starting_phase
  // Sets the 'starting phase'.
  //
  // Internally, the <uvm_sequence_base> uses a <uvm_get_to_lock_dap> to 
  // protect the starting phase value from being modified 
  // after the reference has been read.  Once the sequence has ended 
  // its execution (either via natural termination, or being killed),
  // then the starting phase value can be modified again.
  //
  void set_starting_phase(uvm_phase phase) {
    synchronized(this) {
      version(UVM_DEPRECATED_STARTING_PHASE) {
      	if (_starting_phase !is _m_set_starting_phase) {
      	  if (!_m_warn_deprecated_set) {
      	    uvm_warning("UVM_DEPRECATED", 
      			"The deprecated 'starting_phase' variable has been" ~
      			" set to '" ~ _starting_phase.get_full_name() ~
      			"' manually.  See documentation for " ~
      			"uvm_sequence_base::set_starting_phase.");
      	    _m_warn_deprecated_set = true;
      	  }

      	  _starting_phase = phase;
      	  _m_set_starting_phase = phase;
      	}
      }
      _m_starting_phase_dap.set(phase);
    }
  }
   
  // Function: set_automatic_phase_objection
  // Sets the 'automatically object to starting phase' bit.
  //
  // The most common interaction with the starting phase
  // within a sequence is to simply ~raise~ the phase's objection
  // prior to executing the sequence, and ~drop~ the objection
  // after ending the sequence (either naturally, or
  // via a call to <kill>). In order to 
  // simplify this interaction for the user, the UVM
  // provides the ability to perform this functionality
  // automatically.
  //
  // For example:
  //| function my_sequence::new(string name="unnamed");
  //|   super.new(name);
  //|   set_automatic_phase_objection(1);
  //| endfunction : new
  //
  // From a timeline point of view, the automatic phase objection
  // looks like:
  //| start() is executed
  //|   --! Objection is raised !--
  //|   pre_start() is executed
  //|   pre_body() is optionally executed
  //|   body() is executed
  //|   post_body() is optionally executed
  //|   post_start() is executed
  //|   --! Objection is dropped !--
  //| start() unblocks
  //
  // This functionality can also be enabled in sequences
  // which were not written with UVM Run-Time Phasing in mind:
  //| my_legacy_seq_type seq = new("seq");
  //| seq.set_automatic_phase_objection(1);
  //| seq.start(my_sequencer);
  //
  // Internally, the <uvm_sequence_base> uses a <uvm_get_to_lock_dap> to 
  // protect the ~automatic_phase_objection~ value from being modified 
  // after the reference has been read.  Once the sequence has ended 
  // its execution (either via natural termination, or being killed),
  // then the ~automatic_phase_objection~ value can be modified again.
  //
  // NEVER set the automatic phase objection bit to 1 if your sequence
  // runs with a forever loop inside of the body, as the objection will
  // never get dropped!
  void set_automatic_phase_objection(bool value) {
    synchronized(this) {
      _m_automatic_phase_objection_dap.set(value);
    }
  }

  // Function: get_automatic_phase_objection
  // Returns (and locks) the value of the 'automatically object to 
  // starting phase' bit.
  //
  // If 1, then the sequence will automatically raise an objection
  // to the starting phase (if the starting phase is not ~null~) immediately
  // prior to <pre_start> being called.  The objection will be dropped
  // after <post_start> has executed, or <kill> has been called.
  //
  bool get_automatic_phase_objection() {
    synchronized(this) {
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
    if(starting_phase !is null) {
      starting_phase.drop_objection(this, description, count);
    }
  }
   
  //------------------------
  // Group: Sequence Control
  //------------------------

  // Function: set_priority
  //
  // The priority of a sequence may be changed at any point in time.  When the
  // priority of a sequence is changed, the new priority will be used by the
  // sequencer the next time that it arbitrates between sequences.
  //
  // The default priority value for a sequence is 100.  Higher values result
  // in higher priorities.

  void set_priority (int value) {
    synchronized(this) {
      _m_priority = value;
    }
  }


  // Function: get_priority
  //
  // This function returns the current priority of the sequence.

  int get_priority() {
    synchronized(this) {
      return _m_priority;
    }
  }


  // Function: is_relevant
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

  bool is_relevant() {
    synchronized(this) {
      _is_rel_default = true;
      return true;
    }
  }


  // Task: wait_for_relevant
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
  void wait_for_relevant() {
    synchronized(this) {
      _wait_rel_default = true;
      if (_is_rel_default !is _wait_rel_default) {
	uvm_report_fatal("RELMSM",
			 "is_relevant() was implemented without defining" ~
			 " wait_for_relevant()", UVM_NONE);
      }
    }
    sleep();  // this is intended to never return
  }


  // Task: lock
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
  void lock(uvm_sequencer_base sequencer = null) {
    if (sequencer is null) {
      sequencer = m_sequencer;
    }

    if (sequencer is null) {
      uvm_report_fatal("LOCKSEQR", "Null m_sequencer reference", UVM_NONE);
    }

    sequencer.lock(this);
  }


  // Task: grab
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
  void grab(uvm_sequencer_base sequencer = null) {
    if (sequencer is null) {
      if (m_sequencer is null) {
	uvm_report_fatal("GRAB", "Null m_sequencer reference", UVM_NONE);
      }
      m_sequencer.grab(this);
    }
    else {
      sequencer.grab(this);
    }
  }


  // Function: unlock
  //
  // Removes any locks or grabs obtained by this sequence on the specified
  // sequencer. If sequencer is ~null~, then the unlock will be done on the
  // current default sequencer.

  void  unlock(uvm_sequencer_base sequencer = null) {
    synchronized(this) {
      if (sequencer is null) {
	if (_m_sequencer is null) {
	  uvm_report_fatal("UNLOCK", "Null m_sequencer reference", UVM_NONE);
	}
	_m_sequencer.unlock(this);
      }
      else {
	sequencer.unlock(this);
      }
    }
  }

  // Function: ungrab
  //
  // Removes any locks or grabs obtained by this sequence on the specified
  // sequencer. If sequencer is ~null~, then the unlock will be done on the
  // current default sequencer.

  void  ungrab(uvm_sequencer_base sequencer = null) {
    unlock(sequencer);
  }


  // Function: is_blocked
  //
  // Returns a bool indicating whether this sequence is currently prevented from
  // running due to another lock or grab. A 1 is returned if the sequence is
  // currently blocked. A 0 is returned if no lock or grab prevents this
  // sequence from executing. Note that even if a sequence is not blocked, it
  // is possible for another sequence to issue a lock or grab before this
  // sequence can issue a request.

  bool is_blocked() {
    synchronized(this) {
      return _m_sequencer.is_blocked(this);
    }
  }


  // Function: has_lock
  //
  // Returns 1 if this sequence has a lock, 0 otherwise.
  //
  // Note that even if this sequence has a lock, a child sequence may also have
  // a lock, in which case the sequence is still blocked from issuing
  // operations on the sequencer.

  bool has_lock() {
    synchronized(this) {
      return _m_sequencer.has_lock(this);
    }
  }


  // Function: kill
  //
  // This function will kill the sequence, and cause all current locks and
  // requests in the sequence's default sequencer to be removed. The sequence
  // state will change to UVM_STOPPED, and its post_frame() method, if  will not b
  //
  // If a sequence has issued locks, grabs, or requests on sequencers other than
  // the default sequencer, then care must be taken to unregister the sequence
  // with the other sequencer(s) using the sequencer unregister_sequence()
  // method.

  void kill() {
    synchronized(this) {
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

  // Function: do_kill
  //
  // This function is a user hook that is called whenever a sequence is
  // terminated by using either sequence.kill() or sequencer.stop_sequences()
  // (which effectively calls sequence.kill()).

  void do_kill() {
    return;
  }

  void m_kill() {
    synchronized(this) {
      do_kill();
      foreach(child; _children_array.keys) {
	child.kill();
      }
      if(_m_sequence_process !is null) {
	_m_sequence_process.abort();
	_m_sequence_process = null;
      }
      _m_sequence_state = UVM_STOPPED;
      if((_m_parent_sequence !is null) &&
	 (_m_parent_sequence.in_children_array(this))) {
	m_parent_sequence.rem_children_array(this);
      }
    }
  }

  //-------------------------------
  // Group: Sequence Item Execution
  //-------------------------------

  // Function: create_item
  //
  // Create_item will create and initialize a sequence_item or sequence
  // using the factory.  The sequence_item or sequence will be initialized
  // to communicate with the specified sequencer.

  protected uvm_sequence_item create_item(uvm_object_wrapper type_var,
					  uvm_sequencer_base l_sequencer,
					  string name) {
    synchronized(this) {
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_factory factory = cs.get_factory();
      auto create_item_ = cast(uvm_sequence_item)
	factory.create_object_by_type(type_var, this.get_full_name(), name);
      create_item_.set_item_context(this, l_sequencer);
      return create_item_;
    }
  }


  // Function: start_item
  //
  // ~start_item~ and <finish_item> together will initiate operation of
  // a sequence item.  If the item has not already been
  // initialized using create_item, then it will be initialized here to use
  // the default sequencer specified by m_sequencer.  Randomization
  // may be done between start_item and finish_item to ensure late generation
  //

  // task
  void start_item (uvm_sequence_item item,
			  int set_priority=-1,
			  uvm_sequencer_base sequencer=null) {
    synchronized(this) {
      if(item is null) {
	uvm_report_fatal("NULLITM",
			 "attempting to start a null item from sequence '" ~
			 get_full_name() ~ "'", UVM_NONE);
	return;
      }

      auto seq = cast(uvm_sequence_base) item;
      if(seq !is null) {
	uvm_report_fatal("SEQNOTITM",
			 "attempting to start a sequence using start_item()" ~
			 " from sequence '" ~ get_full_name() ~
			 "'. Use seq.start() instead.", UVM_NONE);
	return;
      }

      if(sequencer is null) {
	sequencer = item.get_sequencer();
      }

      if(sequencer is null)
	sequencer = get_sequencer();

      if(sequencer is null) {
	uvm_report_fatal("SEQ", "neither the item's sequencer nor dedicated " ~
			 "sequencer has been supplied to start item in " ~
			 get_full_name(), UVM_NONE);
	return;
      }

      item.set_item_context(this, sequencer);

      if (set_priority < 0) {
	set_priority = get_priority();
      }
    }

    sequencer.wait_for_grant(this, set_priority);

    synchronized(this) {
      if (sequencer.is_auto_item_recording_enabled()) {
	sequencer.begin_child_tr(item, 
				 (_m_tr_recorder is null) ?
				 0 : _m_tr_recorder.get_handle(), 
				 item.get_root_sequence_name(),
				 "Transactions");
      }
    }
    pre_do(true);
  }

  // Function: finish_item
  //
  // finish_item, together with start_item together will initiate operation of
  // a sequence_item.  Finish_item must be called
  // after start_item with no delays or delta-cycles.  Randomization, or other
  // functions may be called between the start_item and finish_item calls.
  //

  // task
  void finish_item (uvm_sequence_item item,
			   int set_priority = -1) {
    uvm_sequencer_base sequencer = item.get_sequencer();

    if (sequencer is null) {
      uvm_report_fatal("STRITM", "sequence_item has null sequencer", UVM_NONE);
    }

    mid_do(item);
    sequencer.send_request(this, item);

    sequencer.wait_for_item_done(this, -1);

    if (sequencer.is_auto_item_recording_enabled()) {
      sequencer.end_tr(item);
    }

    post_do(item);

  }


  // Task: wait_for_grant
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
  void wait_for_grant(int item_priority = -1, bool lock_request = false) {
    if (m_sequencer is null) {
      uvm_report_fatal("WAITGRANT", "Null m_sequencer reference", UVM_NONE);
    }
    m_sequencer.wait_for_grant(this, item_priority, lock_request);
  }


  // Function: send_request
  //
  // The send_request function may only be called after a wait_for_grant call.
  // This call will send the request item to the sequencer, which will forward
  // it to the driver. If the rerandomize bool is set, the item will be
  // randomized before being sent to the driver.

  void send_request(uvm_sequence_item request, bool rerandomize = false) {
    synchronized(this) {
      if (_m_sequencer is null) {
	uvm_report_fatal("SENDREQ", "Null m_sequencer reference", UVM_NONE);
      }
      _m_sequencer.send_request(this, request, rerandomize);
    }
  }


  // Task: wait_for_item_done
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
  void wait_for_item_done(int transaction_id = -1) {
    if (m_sequencer is null) {
      uvm_report_fatal("WAITITEMDONE", "Null m_sequencer reference", UVM_NONE);
    }
    m_sequencer.wait_for_item_done(this, transaction_id);
  }



  // Group: Response API
  //--------------------

  // Function: use_response_handler
  //
  // When called with enable set to 1, responses will be sent to the response
  // handler. Otherwise, responses must be retrieved using get_response.
  //
  // By default, responses from the driver are retrieved in the sequence by
  // calling get_response.
  //
  // An alternative method is for the sequencer to call the response_handler
  // function with each response.

  void use_response_handler(bool enable) {
    synchronized(this) {
      _m_use_response_handler = enable;
    }
  }


  // Function: get_use_response_handler
  //
  // Returns the state of the use_response_handler bool.

  bool get_use_response_handler() {
    synchronized(this) {
      return _m_use_response_handler;
    }
  }


  // Function: response_handler
  //
  // When the use_response_handler bool is set to 1, this virtual task is called
  // by the sequencer for each response that arrives for this sequence.

  void response_handler(uvm_sequence_item response) {
    return;
  }


  // Function: set_response_queue_error_report_disabled
  //
  // By default, if the response_queue overflows, an error is reported. The
  // response_queue will overflow if more responses are sent to this sequence
  // from the driver than get_response calls are made. Setting value to 0
  // disables these errors, while setting it to 1 enables them.

  void set_response_queue_error_report_disabled(bool value) {
    synchronized(this) {
      _response_queue_error_report_disabled = value;
    }
  }


  // Function: get_response_queue_error_report_disabled
  //
  // When this bool is 0 (default value), error reports are generated when
  // the response queue overflows. When this bool is 1, no such error
  // reports are generated.

  bool get_response_queue_error_report_disabled() {
    synchronized(this) {
      return _response_queue_error_report_disabled;
    }
  }


  // Function: set_response_queue_depth
  //
  // The default maximum depth of the response queue is 8. These method is used
  // to examine or change the maximum depth of the response queue.
  //
  // Setting the response_queue_depth to -1 indicates an arbitrarily deep
  // response queue.  No checking is done.

  void set_response_queue_depth(int value) {
    synchronized(this) {
      _response_queue_depth = value;
    }
  }


  // Function: get_response_queue_depth
  //
  // Returns the current depth setting for the response queue.

  int get_response_queue_depth() {
    synchronized(this) {
      return _response_queue_depth;
    }
  }


  // Function: clear_response_queue
  //
  // Empties the response queue for this sequence.

  void clear_response_queue() {
    synchronized(this) {
      _response_queue.clear();
    }
  }


  void put_base_response(uvm_sequence_item response) {
    synchronized(this) {
      if ((_response_queue_depth == -1) ||
	  (_response_queue.length < _response_queue_depth)) {
	_response_queue.pushBack(response);
	_response_queue_event.notify();
	return;
      }
      if (_response_queue_error_report_disabled == 0) {
	uvm_report_error(get_full_name(), "Response queue overflow, " ~
			 "response was dropped", UVM_NONE);
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
    while(response_queue_length == 0) {
      _response_queue_event.wait();
    }

    synchronized(this) {
      if (transaction_id == -1) {
	response = _response_queue.front();
	_response_queue.removeFront();
	return;
      }
    }

    while(true) {
      size_t queue_size;
      synchronized(this) {
	queue_size = _response_queue.length;
	for (size_t i = 0; i < queue_size; i++) {
	  if (_response_queue[i].get_transaction_id() == transaction_id) {
	    response = cast(uvm_sequence_item) _response_queue[i];
	    _response_queue.remove(i);
	    return;
	  }
	}
      }
      // wait(response_queue.length != queue_size);
      while(response_queue_length() == queue_size) {
	_response_queue_event.wait();
      }
    }
  }



  //------------------------
  // Group- Sequence Library DEPRECATED
  //------------------------

  version(UVM_INCLUDE_DEPRECATED) {

    mixin Randomization;
    
    // Variable- seq_kind
    //
    // Used as an identifier in constraints for a specific sequence type.

    version(UVM_NO_RAND) {
      @uvm_public_sync
	private uint _seq_kind;
    }
    else {
      @uvm_public_sync @rand
	private uint _seq_kind;
    }
    private uint _num_seq;

    void preRandomize() {
      synchronized(this) {
  	_num_seq = num_sequences();
      }
    }

    // For user random selection. This excludes the exhaustive and
    // random sequences.
    // Constraint! q{
    //   ( _num_seq <= 2 ) || ( _seq_kind >= 2 ) ;
    //   ( _seq_kind < _num_seq ) || ( _seq_kind == 0 );
    // }  pick_sequence;

    Constraint! q{
      _num_seq <= 2 || _seq_kind >= 2;
      _seq_kind < _num_seq || _seq_kind == 0;
    }  pick_sequence;


    // Function- num_sequences
    //
    // Returns the number of sequences in the sequencer's sequence library.

    int num_sequences() {
      synchronized(this) {
  	if(_m_sequencer is null) {
  	  return 0;
  	}
  	return cast(int) _m_sequencer.num_sequences();
      }
    }



    // Function- get_seq_kind
    //
    // This function returns an int representing the sequence kind that has
    // been registerd with the sequencer.  The return value may be used with
    // the <get_sequence> or <do_sequence_kind> methods.

    int get_seq_kind(string type_name) {
      synchronized(this) {
  	uvm_warning("UVM_DEPRECATED",
  		    format("uvm_sequence_base.get_seq_kind deprecated."));
  	if(_m_sequencer !is null) {
  	  return _m_sequencer.get_seq_kind(type_name);
  	}
  	else {
  	  uvm_report_warning("NULLSQ", format("%0s sequencer is null.",
  					      get_type_name()), UVM_NONE);
  	  return 0;
  	}
      }
    }


    // Function- get_sequence
    //
    // This function returns a reference to a sequence specified by ~req_kind~,
    // which can be obtained using the <get_seq_kind> method.

    uvm_sequence_base get_sequence(uint req_kind) {
      synchronized(this) {
  	uvm_coreservice_t cs = uvm_coreservice_t.get();
  	uvm_factory factory = cs.get_factory();
  	uvm_warning("UVM_DEPRECATED",
  		    format("uvm_sequence_base.get_sequence deprecated."));
  	if (req_kind < 0 || req_kind >= _m_sequencer.sequences.length) {
  	  uvm_report_error("SEQRNG",
  			   format("Kind arg '%0d' out of range. Need 0-%0d",
  				  req_kind, _m_sequencer.sequences.length-1),
  			   UVM_NONE);
  	}
  	string m_seq_type = _m_sequencer.sequences[req_kind];
  	uvm_sequence_base m_seq = cast(uvm_sequence_base)
  	  factory.create_object_by_name(m_seq_type, get_full_name(), m_seq_type);
  	if(m_seq is null) {
  	  uvm_report_fatal("FCTSEQ",
  			   format("Factory cannot produce a sequence of type" ~
  				  " %0s.", m_seq_type), UVM_NONE);
  	}
  	m_seq.set_use_sequence_info(true);
  	return m_seq;
      }
    }


    // Task- do_sequence_kind
    //
    // This task will start a sequence of kind specified by ~req_kind~,
    // which can be obtained using the <get_seq_kind> method.

    //task
    void do_sequence_kind(uint req_kind) {
      uvm_warning("UVM_DEPRECATED",
  		  format("uvm_sequence_base.do_sequence_kind deprecated."));
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_factory factory = cs.get_factory();
      string m_seq_type = m_sequencer.sequences[req_kind];
      uvm_sequence_base m_seq = cast(uvm_sequence_base)
  	factory.create_object_by_name(m_seq_type, get_full_name(), m_seq_type);
      if (m_seq is null) {
  	uvm_report_fatal("FCTSEQ",
  			 format("Factory cannot produce a sequence of type" ~
  				" %0s.", m_seq_type), UVM_NONE);
      }

      m_seq.set_item_context(this, m_sequencer);

      version(UVM_NO_RAND) {}
      else {
	try {
	  m_seq.randomize();
	}
	catch {
	  uvm_report_warning("RNDFLD", "Randomization failed in" ~
			     " do_sequence_kind()");
	}
      }
      m_seq.start(m_sequencer, this, get_priority(), 0);
    }


    // Function- get_sequence_by_name
    //
    // Internal method.

    uvm_sequence_base get_sequence_by_name(string seq_name) {
      uvm_warning("UVM_DEPRECATED",
		  format("uvm_sequence_base.get_sequence_by_name deprecated."));
      uvm_coreservice_t cs = uvm_coreservice_t.get();
      uvm_factory factory = cs.get_factory();
      uvm_sequence_base m_seq = cast(uvm_sequence_base)
	factory.create_object_by_name(seq_name, get_full_name(), seq_name);
      if (m_seq is null) {
	uvm_report_fatal("FCTSEQ",
			 format("Factory cannot produce a sequence of type" ~
				" %0s.", seq_name), UVM_NONE);
      }
      m_seq.set_use_sequence_info(true);
      return m_seq;
    }


    // Task- create_and_start_sequence_by_name
    //
    // Internal method.

    // task
    void create_and_start_sequence_by_name(string seq_name) {
      uvm_warning("UVM_DEPRECATED",
  		  format("uvm_sequence_base.create_and_start_sequence_by_name" ~
  			 " deprecated."));
      uvm_sequence_base m_seq = get_sequence_by_name(seq_name);
      m_seq.start(m_sequencer, this, this.get_priority(), 0);
    }
  }
  // UVM_INCLUDE_DEPRECATED

  //----------------------
  // Misc Internal methods
  //----------------------


  // m_get_sqr_sequence_id
  // ---------------------

  int m_get_sqr_sequence_id(int sequencer_id, bool update_sequence_id) {
    synchronized(this) {
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
    synchronized(this) {
      _m_sqr_seq_ids[sequencer_id] = sequence_id;
      set_sequence_id(sequence_id);
    }
  }


  // Title: Sequence-Related Macros



  //-----------------------------------------------------------------------------
  //
  // Group: Sequence Action Macros
  //
  // These macros are used to start sequences and sequence items on the default
  // sequencer, ~m_sequencer~. This is determined a number of ways.
  // - the sequencer handle provided in the <uvm_sequence_base::start> method
  // - the sequencer used by the parent sequence
  // - the sequencer that was set using the <uvm_sequence_item::set_sequencer> method
  //-----------------------------------------------------------------------------

  // MACRO: `uvm_create
  //
  //| `uvm_create(SEQ_OR_ITEM)
  //
  // This action creates the item or sequence using the factory.  It intentionally
  // does zero processing.  After this action completes, the user can manually set
  // values, manipulate rand_mode and constraint_mode, etc.

  void uvm_create(T)(ref T SEQ_OR_ITEM) if(is(T: uvm_sequence_item)){
    uvm_create_on(SEQ_OR_ITEM, m_sequencer());
  }


  // MACRO: `uvm_do
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
    if(is(T: uvm_sequence_item)) {
    uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, m_sequencer(), -1);
  }


  // MACRO: `uvm_do_pri
  //
  //| `uvm_do_pri(SEQ_OR_ITEM, PRIORITY)
  //
  // This is the same as `uvm_do except that the sequene item or sequence is
  // executed with the priority specified in the argument

  void uvm_do_pri(T) (ref T SEQ_OR_ITEM, int PRIORITY)
    if(is(T: uvm_sequence_item)){
      uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, m_sequencer, PRIORITY);
    }


  // FIXME add bitvectors to this template filter
  template allIntengral(V...) {
    static if(V.length == 0) {
      enum bool allIntengral = true;
    }
    else static if(isIntegral!(V[0])) {
	enum bool allIntengral = allIntengral!(V[1..$]);
      }
      else enum bool allIntengral = false;
  }

  // MACRO: `uvm_do_with
  //
  //| `uvm_do_with(SEQ_OR_ITEM, CONSTRAINTS)
  //
  // This is the same as `uvm_do except that the constraint block in the 2nd
  // argument is applied to the item or sequence in a randomize with statement
  // before execution.

  void uvm_do_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, V values)
    if(is(T: uvm_sequence_item)) {
    uvm_do_on_pri_with!CONSTRAINTS(SEQ_OR_ITEM, m_sequencer(), -1, values);
  }


  // MACRO: `uvm_do_pri_with
  //
  //| `uvm_do_pri_with(SEQ_OR_ITEM, PRIORITY, CONSTRAINTS)
  //
  // This is the same as `uvm_do_pri except that the given constraint block is
  // applied to the item or sequence in a randomize with statement before
  // execution.

  void uvm_do_pri_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, int PRIORITY, values)
    if(is(T: uvm_sequence_item)) {
    uvm_do_on_pri_with!CONSTRAINTS(SEQ_OR_ITEM, m_sequencer(),
				   PRIORITY, values);
  }


  //-----------------------------------------------------------------------------
  //
  // Group: Sequence on Sequencer Action Macros
  //
  // These macros are used to start sequences and sequence items on a specific
  // sequencer. The sequence or item is created and executed on the given
  // sequencer.
  //-----------------------------------------------------------------------------

  // MACRO: `uvm_create_on
  //
  //| `uvm_create_on(SEQ_OR_ITEM, SEQR)
  //
  // This is the same as <`uvm_create> except that it also sets the parent sequence
  // to the sequence in which the macro is invoked, and it sets the sequencer to
  // the specified ~SEQR~ argument.

  // FIXME -- consider changing SEQ_OR_ITEM and SEQR to aliases passed as temaplte arguments
  void uvm_create_on(T, U)(ref T SEQ_OR_ITEM, U SEQR)
    if(is(T: uvm_sequence_item) && is(U: uvm_sequencer_base)) {
      uvm_object_wrapper w_ = SEQ_OR_ITEM.get_type();
      SEQ_OR_ITEM = cast(T) create_item(w_, SEQR, "SEQ_OR_ITEM");
    }


  // MACRO: `uvm_do_on
  //
  //| `uvm_do_on(SEQ_OR_ITEM, SEQR)
  //
  // This is the same as <`uvm_do> except that it also sets the parent sequence to
  // the sequence in which the macro is invoked, and it sets the sequencer to the
  // specified ~SEQR~ argument.

  void uvm_do_on(T, U)(ref T SEQ_OR_ITEM, U SEQR)
    if(is(T: uvm_sequence_item) && is(U: uvm_sequencer_base)) {
      uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, SEQR, -1);
    }


  // MACRO: `uvm_do_on_pri
  //
  //| `uvm_do_on_pri(SEQ_OR_ITEM, SEQR, PRIORITY)
  //
  // This is the same as <`uvm_do_pri> except that it also sets the parent sequence
  // to the sequence in which the macro is invoked, and it sets the sequencer to
  // the specified ~SEQR~ argument.

  void uvm_do_on_pri(T, U)(ref T SEQ_OR_ITEM,
			   U SEQR, int PRIORITY)
    if(is(T: uvm_sequence_item) && is(U: uvm_sequencer_base)) {
      uvm_do_on_pri_with!q{}(SEQ_OR_ITEM, SEQR, PRIORITY);
    }

  // MACRO: `uvm_do_on_with
  //
  //| `uvm_do_on_with(SEQ_OR_ITEM, SEQR, CONSTRAINTS)
  //
  // This is the same as <`uvm_do_with> except that it also sets the parent
  // sequence to the sequence in which the macro is invoked, and it sets the
  // sequencer to the specified ~SEQR~ argument.
  // The user must supply brackets around the constraints.

  void uvm_do_on_with(string CONSTRAINTS, T, U, V...)
    (ref T SEQ_OR_ITEM, U SEQR, V values)
    if(is(T: uvm_sequence_item) && is(U: uvm_sequencer_base)) {
      uvm_do_on_pri_with!CONSTRAINTS(SEQ_OR_ITEM, SEQR, -1, values);
    }


  // MACRO: `uvm_do_on_pri_with
  //
  //| `uvm_do_on_pri_with(SEQ_OR_ITEM, SEQR, PRIORITY, CONSTRAINTS)
  //
  // This is the same as `uvm_do_pri_with except that it also sets the parent
  // sequence to the sequence in which the macro is invoked, and it sets the
  // sequencer to the specified ~SEQR~ argument.

  void uvm_do_on_pri_with(string CONSTRAINTS, T, U, V...)
    (ref T SEQ_OR_ITEM, U SEQR, int PRIORITY, V values)
    if(is(T: uvm_sequence_item) && is(U: uvm_sequencer_base)) {
      uvm_create_on(SEQ_OR_ITEM, SEQR);
      uvm_sequence_base seq_ = cast(uvm_sequence_base) SEQ_OR_ITEM;
      if (seq_ is null) {
	start_item(SEQ_OR_ITEM, PRIORITY);
      }
      version(UVM_NO_RAND) {}
      else {
	if((seq_ is null || ! seq_.do_not_randomize)) {
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
      seq_ = cast(uvm_sequence_base) SEQ_OR_ITEM;
      if(seq_ is null) finish_item(SEQ_OR_ITEM, PRIORITY);
      else seq_.start(SEQR, this, PRIORITY, 0);
    }


  //-----------------------------------------------------------------------------
  //
  // Group: Sequence Action Macros for Pre-Existing Sequences
  //
  // These macros are used to start sequences and sequence items that do not
  // need to be created.
  //-----------------------------------------------------------------------------


  // MACRO: `uvm_send
  //
  //| `uvm_send(SEQ_OR_ITEM)
  //
  // This macro processes the item or sequence that has been created using
  // `uvm_create.  The processing is done without randomization.  Essentially, an
  // `uvm_do without the create or randomization.

  void uvm_send(T)(ref T SEQ_OR_ITEM)
    if(is(T: uvm_sequence_item)) {
    uvm_send_pri(SEQ_OR_ITEM, -1);
  }


  // MACRO: `uvm_send_pri
  //
  //| `uvm_send_pri(SEQ_OR_ITEM, PRIORITY)
  //
  // This is the same as `uvm_send except that the sequene item or sequence is
  // executed with the priority specified in the argument.

  void uvm_send_pri(T)(T SEQ_OR_ITEM, int PRIORITY)
    if(is(T: uvm_sequence_item)) {
      uvm_sequence_base _seq = cast(uvm_sequence_base) SEQ_OR_ITEM;
      if (_seq is null) {
	start_item(SEQ_OR_ITEM, PRIORITY);
	finish_item(SEQ_OR_ITEM, PRIORITY);
      }
      else _seq.start(_seq.get_sequencer(), this, PRIORITY, 0);
    }


  // MACRO: `uvm_rand_send
  //
  //| `uvm_rand_send(SEQ_OR_ITEM)
  //
  // This macro processes the item or sequence that has been already been
  // allocated (possibly with `uvm_create). The processing is done with
  // randomization.  Essentially, an `uvm_do without the create.

  void uvm_rand_send(T)(ref T SEQ_OR_ITEM)
    if(is(T: uvm_sequence_item)) {
      uvm_rand_send_pri_with!q{}(SEQ_OR_ITEM, -1);
    }


  // MACRO: `uvm_rand_send_pri
  //
  //| `uvm_rand_send_pri(SEQ_OR_ITEM, PRIORITY)
  //
  // This is the same as `uvm_rand_send except that the sequene item or sequence
  // is executed with the priority specified in the argument.

  void uvm_rand_send_pri(T)(ref T SEQ_OR_ITEM, int PRIORITY)
    if(is(T: uvm_sequence_item)) {
      uvm_rand_send_pri_with!q{}(SEQ_OR_ITEM, PRIORITY);
    }

  // MACRO: `uvm_rand_send_with
  //
  //| `uvm_rand_send_with(SEQ_OR_ITEM, CONSTRAINTS)
  //
  // This is the same as `uvm_rand_send except that the given constraint block is
  // applied to the item or sequence in a randomize with statement before
  // execution.

  void uvm_rand_send_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, V values)
    if(is(T: uvm_sequence_item)) {
    uvm_rand_send_pri_with!CONSTRAINTS(SEQ_OR_ITEM, -1, values);
  }

  // MACRO: `uvm_rand_send_pri_with
  //
  //| `uvm_rand_send_pri_with(SEQ_OR_ITEM, PRIORITY, CONSTRAINTS)
  //
  // This is the same as `uvm_rand_send_pri except that the given constraint block
  // is applied to the item or sequence in a randomize with statement before
  // execution.

  void uvm_rand_send_pri_with(string CONSTRAINTS, T, V...)
    (ref T SEQ_OR_ITEM, int PRIORITY, V values)
    if(is(T: uvm_sequence_item)) {
    uvm_sequence_base seq_ = cast(uvm_sequence_base) SEQ_OR_ITEM;
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
    seq_ = cast(uvm_sequence_base) SEQ_OR_ITEM;
    if(seq_ is null) finish_item(SEQ_OR_ITEM, PRIORITY);
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
  // Group: Sequencer Subtypes
  //
  //-----------------------------------------------------------------------------


  // MACRO: `uvm_declare_p_sequencer
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
  //|     if(p_sequencer.some_variable) begin
  //|       ...
  //|     end
  //|   endtask
  //| endclass
  //

  mixin template uvm_declare_p_sequencer(SEQUENCER) {
    SEQUENCER p_sequencer;
    override void m_set_p_sequencer() {
      super.m_set_p_sequencer();
      p_sequencer = cast(SEQUENCER) m_sequencer;
      if(p_sequencer is null) {
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
