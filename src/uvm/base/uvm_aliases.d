module uvm.base.uvm_aliases;

import uvm.base.uvm_config_db;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_object;
import uvm.base.uvm_factory;
import uvm.base.uvm_heartbeat;
import uvm.base.uvm_callback;
import uvm.base.uvm_objection;
import uvm.base.uvm_misc;
import uvm.base.uvm_barrier;
import uvm.base.uvm_event;
import uvm.base.uvm_pool;
import uvm.base.uvm_queue;
import uvm.base.uvm_resource;

import uvm.meta.misc;

// Section: Types

//----------------------------------------------------------------------
// Topic: uvm_config_int
//
// Convenience type for uvm_config_db#(uvm_bitstream_t)
//
//| typedef uvm_config_db#(uvm_bitstream_t) uvm_config_int;
alias uvm_config_int = uvm_config_db!uvm_bitstream_t;

//----------------------------------------------------------------------
// Topic: uvm_config_string
//
// Convenience type for uvm_config_db#(string)
//
//| typedef uvm_config_db#(string) uvm_config_string;
alias uvm_config_string = uvm_config_db!string;

//----------------------------------------------------------------------
// Topic: uvm_config_object
//
// Convenience type for uvm_config_db#(uvm_object)
//
//| typedef uvm_config_db#(uvm_object) uvm_config_object;
alias uvm_config_object = uvm_config_db!uvm_object;

//----------------------------------------------------------------------
// Topic: uvm_config_wrapper
//
// Convenience type for uvm_config_db#(uvm_object_wrapper)
//
//| typedef uvm_config_db#(uvm_object_wrapper) uvm_config_wrapper;

alias uvm_config_wrapper = uvm_config_db!uvm_object_wrapper;


// From uvm_heartbeat.d
alias uvm_heartbeat_cbs_t =
  uvm_callbacks!(uvm_objection, uvm_heartbeat_callback);


// From uvm_misc.d
alias uvm_bitstream_to_string = uvm_bitvec_to_string!uvm_bitstream_t;
alias uvm_integral_to_string  = uvm_bitvec_to_string!uvm_integral_t;

// from: uvm_pool

// @uvm-ieee 1800.2-2017 auto 10.4.2.1
alias uvm_object_string_pool!(uvm_barrier) uvm_barrier_pool;
// @uvm-ieee 1800.2-2017 auto 10.4.1.1
alias uvm_object_string_pool!(uvm_event!(uvm_object)) uvm_event_pool;

alias uvm_queue_string_pool = uvm_object_string_pool!(uvm_queue!string);
alias uvm_string_object_resource_pool =
  uvm_pool!(string, uvm_resource!(uvm_object));;


// Enum Aliases

mixin(declareEnums!uvm_heartbeat_modes());
mixin(declareEnums!uvm_apprepend());
mixin(declareEnums!uvm_radix_enum());
mixin(declareEnums!uvm_recursion_policy_enum());
mixin(declareEnums!uvm_active_passive_enum());
mixin(declareEnums!uvm_field_auto_enum());
mixin(declareEnums!uvm_comp_auto_enum());
mixin(declareEnums!uvm_objection_event());
mixin(declareEnums!uvm_wait_op());
mixin(declareEnums!uvm_phase_state());
mixin(declareEnums!uvm_phase_type());
mixin(declareEnums!uvm_sequence_lib_mode());
alias uvm_sequence_state_enum = uvm_sequence_state; // backward compat
mixin(declareEnums!uvm_sequence_state());
mixin(declareEnums!uvm_sequencer_arb_mode());
alias UVM_SEQ_ARB_TYPE = uvm_sequencer_arb_mode; // backward compat
mixin(declareEnums!uvm_port_type_e());
mixin(declareEnums!uvm_verbosity());
mixin(declareEnums!uvm_action_type());
mixin(declareEnums!uvm_severity());
version(UVM_INCLUDE_DEPRECATED) {
  alias uvm_severity_type = uvm_severity;
}
mixin(declareEnums!uvm_field_xtra_enum());
