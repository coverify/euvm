//
//------------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013 Verilab
// Copyright 2010-2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2012-2018 Cisco Systems, Inc.
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

module uvm.base.uvm_object_globals;


import esdl.data.bvec;
import esdl.data.time;
import uvm.meta.misc;
import uvm.meta.mcd;
import uvm.base.uvm_scope;

// version (UVM_NO_DEPRECATED) { }
//  else {
//    version = UVM_INCLUDE_DEPRECATED;
//  }

//------------------------------------------------------------------------------
//
// Section --NODOCS-- Types and Enumerations
//
//------------------------------------------------------------------------------

//------------------------
// Group --NODOCS-- Field automation
//------------------------

enum int UVM_MAX_STREAMBITS = 4096;
enum int UVM_STREAMBITS = UVM_MAX_STREAMBITS;



// Type --NODOCS-- uvm_bitstream_t
//
// The bitstream type is used as a argument type for passing integral values
// in such methods as <uvm_object::set_int_local>, <uvm_config_int>,
// <uvm_printer::print_field>, <uvm_recorder::record_field>,
// <uvm_packer::pack_field> and <uvm_packer::unpack_field>.
alias uvm_bitstream_t = LogicVec!UVM_STREAMBITS;

// Type --NODOCS-- uvm_integral_t
//
// The integral type is used as a argument type for passing integral values
// of 64 bits or less in such methods as
// <uvm_printer::print_field_int>, <uvm_recorder::record_field_int>,
// <uvm_packer::pack_field_int> and <uvm_packer::unpack_field_int>.
//
alias uvm_integral_t = LogicVec!64;



// The number of least significant bits of uvm_field_flag_t which are reserved for this
// implementation.  Derived from the value of UVM_RADIX which uses the most significant subset.
enum uint UVM_FIELD_FLAG_RESERVED_BITS = 28;

// The type for storing flag values passed to the uvm_field_* macros.
// typedef bit [`UVM_FIELD_FLAG_SIZE-1 : 0] uvm_field_flag_t;
alias uvm_field_flag_t = uint;

// Enum -- NODOCS -- uvm_radix_enum
//
// Specifies the radix to print or record in.
//
// UVM_BIN       - Selects binary (%b) format
// UVM_DEC       - Selects decimal (%d) format
// UVM_UNSIGNED  - Selects unsigned decimal (%u) format
// UVM_UNFORMAT2 - Selects unformatted 2 value data (%u) format
// UVM_UNFORMAT4 - Selects unformatted 4 value data (%z) format
// UVM_OCT       - Selects octal (%o) format
// UVM_HEX       - Selects hexadecimal (%h) format
// UVM_STRING    - Selects string (%s) format
// UVM_TIME      - Selects time (%t) format
// UVM_ENUM      - Selects enumeration value (name) format
// UVM_REAL      - Selects real (%g) in exponential or decimal format,
//                 whichever format results in the shorter printed output
// UVM_REAL_DEC  - Selects real (%f) in decimal format
// UVM_REAL_EXP  - Selects real (%e) in exponential format

enum uvm_radix_enum: uint
  {   UVM_BIN       = 0x1000000,
      UVM_DEC       = 0x2000000,
      UVM_UNSIGNED  = 0x3000000,
      UVM_UNFORMAT2 = 0x4000000,
      UVM_UNFORMAT4 = 0x5000000,
      UVM_OCT       = 0x6000000,
      UVM_HEX       = 0x7000000,
      UVM_STRING    = 0x8000000,
      UVM_TIME      = 0x9000000,
      UVM_ENUM      = 0xa000000,
      UVM_REAL      = 0xb000000,
      UVM_REAL_DEC  = 0xc000000,
      UVM_REAL_EXP  = 0xd000000,
      UVM_NORADIX   = 0x0000000
      }

enum int UVM_RADIX = 0xf000000; //4 bits setting the radix


// Function- uvm_radix_to_string

char uvm_radix_to_string(uvm_radix_enum radix) {
  switch (radix) {
  case uvm_radix_enum.UVM_BIN:        return 'b';
  case uvm_radix_enum.UVM_OCT:        return 'o';
  case uvm_radix_enum.UVM_DEC:        return 'd';
  case uvm_radix_enum.UVM_HEX:        return 'h';
  case uvm_radix_enum.UVM_UNSIGNED:   return 'u';
  case uvm_radix_enum.UVM_UNFORMAT2:  return 'u';
  case uvm_radix_enum.UVM_UNFORMAT4:  return 'z';
  case uvm_radix_enum.UVM_STRING:     return 's';
  case uvm_radix_enum.UVM_TIME:       return 't';
  case uvm_radix_enum.UVM_ENUM:       return 's';
  case uvm_radix_enum.UVM_REAL:       return 'g';
  case uvm_radix_enum.UVM_REAL_DEC:   return 'f';
  case uvm_radix_enum.UVM_REAL_EXP:   return 'e';
  default:             return 'x'; //hex
  }
}

// Enum --NODOCS-- uvm_recursion_policy_enum
//
// Specifies the policy for copying objects.
//
// UVM_DEEP      - Objects are deep copied (object must implement <uvm_object::copy> method)
// UVM_SHALLOW   - Objects are shallow copied using default SV copy.
// UVM_REFERENCE - Only object handles are copied.

enum uvm_recursion_policy_enum: uint
  {   UVM_DEFAULT_POLICY = 0,
      UVM_DEEP           = (1<<16),
      UVM_SHALLOW        = (1<<17),
      UVM_REFERENCE      = (1<<18)
      }

// UVM_RECURSION is a mask for uvm_recursion_policy_enum, similar to
// UVM_RADIX for uvm_radix_enum.  Flags can be AND'd with the mask
// before casting into the enum, a`la:
// 
//| uvm_recursion_policy_enum foo;
//| foo = uvm_recursion_policy_enum'(flags&UVM_RECURSION);
//
enum uint UVM_RECURSION = (uvm_recursion_policy_enum.UVM_DEEP |
			   uvm_recursion_policy_enum.UVM_SHALLOW |
			   uvm_recursion_policy_enum.UVM_REFERENCE);

// Enum --NODOCS-- uvm_active_passive_enum
//
// Convenience value to define whether a component, usually an agent,
// is in "active" mode or "passive" mode.
//
// UVM_PASSIVE - "Passive" mode
// UVM_ACTIVE  - "Active" mode

enum uvm_active_passive_enum: bool
  {   UVM_PASSIVE = false,
      UVM_ACTIVE = true
      }

// Parameter --NODOCS-- `uvm_field_* macro flags
//
// Defines what operations a given field should be involved in.
// Bitwise OR all that apply.
//
// UVM_DEFAULT   - All field operations turned on
// UVM_COPY      - Field will participate in <uvm_object::copy>
// UVM_COMPARE   - Field will participate in <uvm_object::compare>
// UVM_PRINT     - Field will participate in <uvm_object::print>
// UVM_RECORD    - Field will participate in <uvm_object::record>
// UVM_PACK      - Field will participate in <uvm_object::pack>
//
// UVM_NOCOPY    - Field will not participate in <uvm_object::copy>
// UVM_NOCOMPARE - Field will not participate in <uvm_object::compare>
// UVM_NOPRINT   - Field will not participate in <uvm_object::print>
// UVM_NORECORD  - Field will not participate in <uvm_object::record>
// UVM_NOPACK    - Field will not participate in <uvm_object::pack>
//
// UVM_DEEP      - Object field will be deep copied
// UVM_SHALLOW   - Object field will be shallow copied
// UVM_REFERENCE - Object field will copied by reference
//
// UVM_READONLY  - Object field will NOT be automatically configured.

enum uint UVM_MACRO_NUMFLAGS    = 19;
//A=ABSTRACT Y=PHYSICAL
//F=REFERENCE, S=SHALLOW, D=DEEP
//K=PACK, R=RECORD, P=PRINT, M=COMPARE, C=COPY
//--------------------------- AYFSD K R P M C

enum uvm_field_auto_enum: uint
{   UVM_DEFAULT     = 0b000010101010101,
    UVM_ALL_ON      = 0b000000101010101,
    UVM_FLAGS_ON    = 0b000000101010101,
    UVM_FLAGS_OFF   = 0,

    //Values are OR'ed into a 32 bit value
    //and externally
    UVM_COPY         = (1 << 0),
    UVM_NOCOPY       = (1 << 1),
    UVM_COMPARE      = (1 << 2),
    UVM_NOCOMPARE    = (1 << 3),
    UVM_PRINT        = (1 << 4),
    UVM_NOPRINT      = (1 << 5),
    UVM_RECORD       = (1 << 6),
    UVM_NORECORD     = (1 << 7),
    UVM_PACK         = (1 << 8),
    UVM_NOPACK       = (1 << 9),
    UVM_UNPACK       = (1 << 10),
    UVM_NOUNPACK     = UVM_NOPACK,
    UVM_SET          = (1 << 11),
    UVM_NOSET        = (1 << 12),
    UVM_NODEFPRINT   = (1 << 15),
    UVM_BUILD        = (1 << 17),
    UVM_NOBUILD      = (1 << 18),
    }

//UVM_DEEP         = (1 << 10),
//UVM_SHALLOW      = (1 << 11),
//UVM_REFERENCE    = (1 << 12),

//Extra values that are used for extra methods

enum uvm_field_xtra_enum: uint
  {   UVM_MACRO_EXTRAS   = (1 << UVM_MACRO_NUMFLAGS),
      UVM_FLAGS          = UVM_MACRO_EXTRAS + 1,
      UVM_CHECK_FIELDS   = UVM_MACRO_EXTRAS + 2,
      UVM_END_DATA_EXTRA = UVM_MACRO_EXTRAS + 3,


      //Get and set methods (in uvm_object). Used by the set/get* functions
      //to tell the object what operation to perform on the fields.
      UVM_START_FUNCS    = UVM_END_DATA_EXTRA + 1,
      // UVM_SET            = UVM_START_FUNCS + 1, // TBD
      // UVM_SETINT         = UVM_SET,             // TBD
      // UVM_SETOBJ         = UVM_START_FUNCS + 2, // TBD
      // UVM_SETSTR         = UVM_START_FUNCS + 3, // TBD
      UVM_PARALLELIZE    = UVM_START_FUNCS + 4,
      UVM_END_FUNCS      = UVM_START_FUNCS + 5
      }


// Global string variables
// declared in SV but never used
// string uvm_aa_string_key;



//-----------------
// Group --NODOCS-- Reporting
//-----------------

// Enum --NODOCS-- uvm_severity
//
// Defines all possible values for report severity.
//
//   UVM_INFO    - Informative message.
//   UVM_WARNING - Indicates a potential problem.
//   UVM_ERROR   - Indicates a real problem. Simulation continues subject
//                 to the configured message action.
//   UVM_FATAL   - Indicates a problem from which simulation cannot
//                 recover. Simulation exits via $finish after a #0 delay.

// typedef bit [1:0] uvm_severity;

enum uvm_severity: byte
  {   UVM_INFO,
      UVM_WARNING,
      UVM_ERROR,
      UVM_FATAL
      }


// Enum --NODOCS-- uvm_action
//
// Defines all possible values for report actions. Each report is configured
// to execute one or more actions, determined by the bitwise OR of any or all
// of the following enumeration constants.
//
//   UVM_NO_ACTION - No action is taken
//   UVM_DISPLAY   - Sends the report to the standard output
//   UVM_LOG       - Sends the report to the file(s) for this (severity,id) pair
//   UVM_COUNT     - Counts the number of reports with the COUNT attribute.
//                   When this value reaches max_quit_count, the simulation terminates
//   UVM_EXIT      - Terminates the simulation immediately.
//   UVM_CALL_HOOK - Callback the report hook methods
//   UVM_STOP      - Causes ~$stop~ to be executed, putting the simulation into
//                   interactive mode.
//   UVM_RM_RECORD - Sends the report to the recorder


alias uvm_action = int;

enum uvm_action_type: byte
  {   UVM_NO_ACTION = 0b0000000,
      UVM_DISPLAY   = 0b0000001,
      UVM_LOG       = 0b0000010,
      UVM_COUNT     = 0b0000100,
      UVM_EXIT      = 0b0001000,
      UVM_CALL_HOOK = 0b0010000,
      UVM_STOP      = 0b0100000,
      UVM_RM_RECORD = 0b1000000
      }

// Enum --NODOCS-- uvm_verbosity
//
// Defines standard verbosity levels for reports.
//
//  UVM_NONE   - Report is always printed. Verbosity level setting cannot
//               disable it.
//  UVM_LOW    - Report is issued if configured verbosity is set to UVM_LOW
//               or above.
//  UVM_MEDIUM - Report is issued if configured verbosity is set to UVM_MEDIUM
//               or above.
//  UVM_HIGH   - Report is issued if configured verbosity is set to UVM_HIGH
//               or above.
//  UVM_FULL   - Report is issued if configured verbosity is set to UVM_FULL
//               or above.

enum uvm_verbosity: int
  {   UVM_NONE   = 0,
      UVM_LOW    = 100,
      UVM_MEDIUM = 200,
      UVM_HIGH   = 300,
      UVM_FULL   = 400,
      UVM_DEBUG  = 500
      }


//-----------------
// Group --NODOCS-- Port Type
//-----------------

// Enum --NODOCS-- uvm_port_type_e
//
// Specifies the type of port
//
// UVM_PORT           - The port requires the interface that is its type
//                      parameter.
// UVM_EXPORT         - The port provides the interface that is its type
//                      parameter via a connection to some other export or
//                      implementation.
// UVM_IMPLEMENTATION - The port provides the interface that is its type
//                      parameter, and it is bound to the component that
//                      implements the interface.

enum uvm_port_type_e: byte
  {   UVM_PORT ,
      UVM_EXPORT ,
      UVM_IMPLEMENTATION
      }

//-----------------
// Group --NODOCS-- Sequences
//-----------------

// Enum --NODOCS-- uvm_sequencer_arb_mode
//
// Specifies a sequencer's arbitration mode
//
// UVM_SEQ_ARB_FIFO          - Requests are granted in FIFO order (default)
// UVM_SEQ_ARB_WEIGHTED      - Requests are granted randomly by weight
// UVM_SEQ_ARB_RANDOM        - Requests are granted randomly
// UVM_SEQ_ARB_STRICT_FIFO   - Requests at highest priority granted in fifo order
// UVM_SEQ_ARB_STRICT_RANDOM - Requests at highest priority granted in randomly
// UVM_SEQ_ARB_USER          - Arbitration is delegated to the user-defined
//                         function, user_priority_arbitration. That function
//                         will specify the next sequence to grant.


enum uvm_sequencer_arb_mode: byte
  {   UVM_SEQ_ARB_FIFO,
      UVM_SEQ_ARB_WEIGHTED,
      UVM_SEQ_ARB_RANDOM,
      UVM_SEQ_ARB_STRICT_FIFO,
      UVM_SEQ_ARB_STRICT_RANDOM,
      UVM_SEQ_ARB_USER
      }


// Enum --NODOCS-- uvm_sequence_state_enum
//
// Defines current sequence state
//
// UVM_CREATED            - The sequence has been allocated.
// UVM_PRE_START          - The sequence is started and the
//                      <uvm_sequence_base::pre_start()> task is
//                      being executed.
// UVM_PRE_BODY           - The sequence is started and the
//                      <uvm_sequence_base::pre_body()> task is
//                      being executed.
// UVM_BODY               - The sequence is started and the
//                      <uvm_sequence_base::body()> task is
//                      being executed.
// UVM_ENDED              - The sequence has completed the execution of the
//                      <uvm_sequence_base::body()> task.
// UVM_POST_BODY          - The sequence is started and the
//                      <uvm_sequence_base::post_body()> task is
//                      being executed.
// UVM_POST_START         - The sequence is started and the
//                      <uvm_sequence_base::post_start()> task is
//                      being executed.
// UVM_STOPPED            - The sequence has been forcibly ended by issuing a
//                      <uvm_sequence_base::kill()> on the sequence.
// UVM_FINISHED           - The sequence is completely finished executing.

enum uvm_sequence_state: int
  {   UVM_CREATED    = 1,
      UVM_PRE_START  = 2,
      UVM_PRE_BODY   = 4,
      UVM_BODY       = 8,
      UVM_POST_BODY  = 16,
      UVM_POST_START = 32,
      UVM_ENDED      = 64,
      UVM_STOPPED    = 128,
      UVM_FINISHED   = 256
      }



// Enum --NODOCS-- uvm_sequence_lib_mode
//
// Specifies the random selection mode of a sequence library
//
// UVM_SEQ_LIB_RAND  - Random sequence selection
// UVM_SEQ_LIB_RANDC - Random cyclic sequence selection
// UVM_SEQ_LIB_ITEM  - Emit only items, no sequence execution
// UVM_SEQ_LIB_USER  - Apply a user-defined random-selection algorithm

enum uvm_sequence_lib_mode: byte
  {   UVM_SEQ_LIB_RAND,
      UVM_SEQ_LIB_RANDC,
      UVM_SEQ_LIB_ITEM,
      UVM_SEQ_LIB_USER
      }


//---------------
// Group --NODOCS-- Phasing
//---------------

// Enum --NODOCS-- uvm_phase_type
//
// This is an attribute of a <uvm_phase> object which defines the phase
// type.
//
//   UVM_PHASE_IMP      - The phase object is used to traverse the component
//                        hierarchy and call the component phase method as
//                        well as the ~phase_started~ and ~phase_ended~ callbacks.
//                        These nodes are created by the phase macros,
//                        `uvm_builtin_task_phase, `uvm_builtin_topdown_phase,
//                        and `uvm_builtin_bottomup_phase. These nodes represent
//                        the phase type, i.e. uvm_run_phase, uvm_main_phase.
//
//   UVM_PHASE_NODE     - The object represents a simple node instance in
//                        the graph. These nodes will contain a reference to
//                        their corresponding IMP object.
//
//   UVM_PHASE_SCHEDULE - The object represents a portion of the phasing graph,
//                        typically consisting of several NODE types, in series,
//                        parallel, or both.
//
//   UVM_PHASE_TERMINAL - This internal object serves as the termination NODE
//                        for a SCHEDULE phase object.
//
//   UVM_PHASE_DOMAIN   - This object represents an entire graph segment that
//                        executes in parallel with the 'run' phase.
//                        Domains may define any network of NODEs and
//                        SCHEDULEs. The built-in domain, ~uvm~, consists
//                        of a single schedule of all the run-time phases,
//                        starting with ~pre_reset~ and ending with
//                        ~post_shutdown~.
//
enum  uvm_phase_type: byte
  {   UVM_PHASE_IMP,
      UVM_PHASE_NODE,
      UVM_PHASE_TERMINAL,
      UVM_PHASE_SCHEDULE,
      UVM_PHASE_DOMAIN,
      UVM_PHASE_GLOBAL
      }


// Enum --NODOCS-- uvm_phase_state
// ---------------------
//
// The set of possible states of a phase. This is an attribute of a schedule
// node in the graph, not of a phase, to maintain independent per-domain state
//
//   UVM_PHASE_UNINITIALIZED - The state is uninitialized.  This is the default
//             state for phases, and for nodes which have not yet been added to
//             a schedule.
//
//   UVM_PHASE_DORMANT -  The schedule is not currently operating on the phase
//             node, however it will be scheduled at some point in the future.
//
//   UVM_PHASE_SCHEDULED - At least one immediate predecessor has completed.
//              Scheduled phases block until all predecessors complete or
//              until a jump is executed.
//
//   UVM_PHASE_SYNCING - All predecessors complete, checking that all synced
//              phases (e.g. across domains) are at or beyond this point
//
//   UVM_PHASE_STARTED - phase ready to execute, running phase_started() callback
//
//   UVM_PHASE_EXECUTING - An executing phase is one where the phase callbacks are
//              being executed. Its process is tracked by the phaser.
//
//   UVM_PHASE_READY_TO_END - no objections remain in this phase or in any
//              predecessors of its successors or in any sync'd phases. This
//              state indicates an opportunity for any phase that needs extra
//              time for a clean exit to raise an objection, thereby causing a
//              return to UVM_PHASE_EXECUTING.  If no objection is raised, state
//              will transition to UVM_PHASE_ENDED after a delta cycle.
//              (An example of predecessors of successors: The successor to
//              phase 'run' is 'extract', whose predecessors are 'run' and
//              'post_shutdown'. Therefore, 'run' will go to this state when
//              both its objections and those of 'post_shutdown' are all dropped.
//
//   UVM_PHASE_ENDED - phase completed execution, now running phase_ended() callback
//
//   UVM_PHASE_JUMPING - all processes related to phase are being killed and all
//                       predecessors are forced into the DONE state.
//
//   UVM_PHASE_CLEANUP - all processes related to phase are being killed
//
//   UVM_PHASE_DONE - A phase is done after it terminated execution.  Becoming
//              done may enable a waiting successor phase to execute.
//
//    The state transitions occur as follows:
//
//|   UNINITIALIZED -> DORMANT -> SCHED -> SYNC -> START -> EXEC -> READY -> END -+-> CLEAN -> DONE
//|                       ^                                                       |
//|                       |                      <-- jump_to                      |
//|                       +-------------------------------------------- JUMPING< -+

enum uvm_phase_state: int
  {   UVM_PHASE_UNINITIALIZED = 0,
      UVM_PHASE_DORMANT       = 1,
      UVM_PHASE_SCHEDULED     = 2,
      UVM_PHASE_SYNCING       = 4,
      UVM_PHASE_STARTED       = 8,
      UVM_PHASE_EXECUTING     = 16,
      UVM_PHASE_READY_TO_END  = 32,
      UVM_PHASE_ENDED         = 64,
      UVM_PHASE_CLEANUP       = 128,
      UVM_PHASE_DONE          = 256,
      UVM_PHASE_JUMPING       = 512
      }


// Enum --NODOCS-- uvm_wait_op
//
// Specifies the operand when using methods like <uvm_phase::wait_for_state>.
//
// UVM_EQ  - equal
// UVM_NE  - not equal
// UVM_LT  - less than
// UVM_LTE - less than or equal to
// UVM_GT  - greater than
// UVM_GTE - greater than or equal to
//
enum uvm_wait_op: byte
  {   UVM_LT,
      UVM_LTE,
      UVM_NE,
      UVM_EQ,
      UVM_GT,
      UVM_GTE
      }


//------------------
// Group --NODOCS-- Objections
//------------------

// Enum --NODOCS-- uvm_objection_event
//
// Enumerated the possible objection events one could wait on. See
// <uvm_objection::wait_for>.
//
// UVM_RAISED      - an objection was raised
// UVM_DROPPED     - an objection was raised
// UVM_ALL_DROPPED - all objections have been dropped
//
enum uvm_objection_event: byte
{   UVM_RAISED      = 0x01,
    UVM_DROPPED     = 0x02,
    UVM_ALL_DROPPED = 0x04
    }

alias UVM_FILE = MCD;

enum UVM_FILE UVM_STDIN  = 0x8000_0000;
enum UVM_FILE UVM_STDOUT = 0x8000_0001;
enum UVM_FILE UVM_STDERR = 0x8000_0002;

// Type: uvm_core_state
// Implementation of the uvm_core_state enumeration, as defined
// in section F.2.10 of 1800.2-2017.
//
// *Note:* In addition to the states defined in section F.2.10,
// this implementation includes the following additional states.
//
// UVM_CORE_PRE_INIT - The <uvm_init> method has been invoked at least
//                     once, however the core service has yet to be
//                     determined/assigned.  Additional calls to uvm_init
//                     while in this state will result in a fatal message
//                     being generated, as the library can not determine
//                     the correct core service.
//
// UVM_CORE_INITIALIZING - The <uvm_init> method has been called at least
//                         once, and the core service has been determined.
//                         Once in this state, it is safe to query
//                         <uvm_coreservice_t::get>.
//
// UVM_CORE_POST_INIT - Included for consistency, this is equivalent to
//                      ~UVM_CORE_INITIALIZED~ in 1800.2-2017.
//
// @uvm-contrib Potential contribution to 1800.2

// @uvm-ieee 1800.2-2017 manual F.2.10  
enum uvm_core_state {
	UVM_CORE_UNINITIALIZED,
        UVM_CORE_PRE_INIT,
        UVM_CORE_INITIALIZING,
	UVM_CORE_INITIALIZED,
	UVM_CORE_POST_INIT = UVM_CORE_INITIALIZED,
	UVM_CORE_PRE_RUN,
	UVM_CORE_RUNNING,
	UVM_CORE_POST_RUN,
	UVM_CORE_FINISHED,
	UVM_CORE_PRE_ABORT,
	UVM_CORE_ABORTED	
}

class uvm_object_globals_scope: uvm_scope_base {
  @uvm_none_sync
  uvm_core_state _m_uvm_core_state = uvm_core_state.UVM_CORE_UNINITIALIZED;
  // enum uvm_core_state UVM_CORE_POST_INIT = uvm_core_state.UVM_CORE_INITIALIZED;
}

mixin (uvm_scope_sync_string!(uvm_object_globals_scope));

uvm_core_state m_uvm_core_state() {
  synchronized (_uvm_scope_inst) {
    return _uvm_scope_inst._m_uvm_core_state;
  }
}

void m_uvm_core_state(uvm_core_state state) {
  synchronized (_uvm_scope_inst) {
    _uvm_scope_inst._m_uvm_core_state = state;
  }
}

// Vlang initializes all the once variables lazily by design
// typedef class uvm_object_wrapper;
// uvm_object_wrapper uvm_deferred_init[$];
