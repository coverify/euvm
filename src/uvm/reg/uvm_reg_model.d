//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010 Cadence Design Systems, Inc.
//    Copyright 2014 Coverify Systems Technology
//    All Rights Reserved Worldwide
//
//    Licensed under the Apache License, Version 2.0 (the
//    "License"); you may not use this file except in
//    compliance with the License.  You may obtain a copy of
//    the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in
//    writing, software distributed under the License is
//    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//    CONDITIONS OF ANY KIND, either express or implied.  See
//    the License for the specific language governing
//    permissions and limitations under the License.
// -------------------------------------------------------------
//

module uvm.reg.uvm_reg_model;


import uvm.reg.uvm_reg_defines;

import esdl.data.bvec;

import uvm.base.uvm_resource_db;
import uvm.meta.misc;

import std.string: format;
//------------------------------------------------------------------------------
// TITLE: Global Declarations for the Register Layer
//------------------------------------------------------------------------------
//
// This section defines globally available types, enums, and utility classes.
//
//------------------------------------------------------------------------------

// typedef class uvm_reg_field;
// typedef class uvm_vreg_field;
// typedef class uvm_reg;
// typedef class uvm_reg_file;
// typedef class uvm_vreg;
// typedef class uvm_reg_block;
// typedef class uvm_mem;
// typedef class uvm_reg_item;
// typedef class uvm_reg_map;
// typedef class uvm_reg_map_info;
// typedef class uvm_reg_sequence;
// typedef class uvm_reg_adapter;
// typedef class uvm_reg_indirect_data;


//-------------
// Group: Types
//-------------

// Type: uvm_reg_data_t
//
// 2-state data value with <`UVM_REG_DATA_WIDTH> bits
//
// typedef bit unsigned [`UVM_REG_DATA_WIDTH-1:0]  uvm_reg_data_t ;
alias uvm_reg_data_t=UBit!UVM_REG_DATA_WIDTH;


// Type: uvm_reg_data_logic_t
//
// 4-state data value with <`UVM_REG_DATA_WIDTH> bits
//
// typedef  logic unsigned [`UVM_REG_DATA_WIDTH-1:0]  uvm_reg_data_logic_t ;
alias uvm_reg_data_logic_t = ULogic!UVM_REG_DATA_WIDTH;

// Type: uvm_reg_addr_t
//
// 2-state address value with <`UVM_REG_ADDR_WIDTH> bits
//
// typedef  bit unsigned [`UVM_REG_ADDR_WIDTH-1:0]  uvm_reg_addr_t ;
alias uvm_reg_addr_t = UBit!UVM_REG_ADDR_WIDTH;


// Type: uvm_reg_addr_logic_t
//
// 4-state address value with <`UVM_REG_ADDR_WIDTH> bits
//
// typedef  logic unsigned [`UVM_REG_ADDR_WIDTH-1:0]  uvm_reg_addr_logic_t ;
alias uvm_reg_addr_logic_t = ULogic!UVM_REG_ADDR_WIDTH;


// Type: uvm_reg_byte_en_t
//
// 2-state byte_enable value with <`UVM_REG_BYTENABLE_WIDTH> bits
//
// typedef  bit unsigned [`UVM_REG_BYTENABLE_WIDTH-1:0]  uvm_reg_byte_en_t ;
alias uvm_reg_byte_en_t = UBit!UVM_REG_BYTENABLE_WIDTH;


// Type: uvm_reg_cvr_t
//
// Coverage model value set with <`UVM_REG_CVR_WIDTH> bits.
//
// Symbolic values for individual coverage models are defined
// by the <uvm_coverage_model_e> type.
//
// The following bits in the set are assigned as follows
//
// 0-7     - UVM pre-defined coverage models
// 8-15    - Coverage models defined by EDA vendors,
//           implemented in a register model generator.
// 16-23   - User-defined coverage models
// 24..    - Reserved
//
// typedef  bit [`UVM_REG_CVR_WIDTH-1:0]  uvm_reg_cvr_t ;
alias uvm_reg_cvr_t=Bit!UVM_REG_CVR_WIDTH;


// Type: uvm_hdl_path_slice
//
// Slice of an HDL path
//
// Struct that specifies the HDL variable that corresponds to all
// or a portion of a register.
//
// path    - Path to the HDL variable.
// offset  - Offset of the LSB in the register that this variable implements
// size    - Number of bits (toward the MSB) that this variable implements
//
// If the HDL variable implements all of the register, ~offset~ and ~size~
// are specified as -1. For example:
//|
//| r1.add_hdl_path('{ '{"r1", -1, -1} });
//|
//
// typedef struct {
//    string path;
//    int offset;
//    int size;
// } uvm_hdl_path_slice;

struct uvm_hdl_path_slice {
  string path;
  int offset;
  int size;
}


// typedef uvm_resource_db#(uvm_reg_cvr_t) uvm_reg_cvr_rsrc_db;
alias uvm_reg_cvr_rsrc_db=uvm_resource_db!uvm_reg_cvr_t;



//--------------------
// Group: Enumerations
//--------------------

// Enum: uvm_status_e
//
// Return status for register operations
//
// UVM_IS_OK      - Operation completed successfully
// UVM_NOT_OK     - Operation completed with error
// UVM_HAS_X      - Operation completed successfully bit had unknown bits.
//

enum uvm_status_e {
  UVM_IS_OK,
  UVM_NOT_OK,
  UVM_HAS_X
}

mixin(declareEnums!uvm_status_e());

// Enum: uvm_path_e
//
// Path used for register operation
//
// UVM_FRONTDOOR    - Use the front door
// UVM_BACKDOOR     - Use the back door
// UVM_PREDICT      - Operation derived from observations by a bus monitor via
//                    the <uvm_reg_predictor> class.
// UVM_DEFAULT_PATH - Operation specified by the context
//

enum uvm_path_e {
  UVM_FRONTDOOR,
  UVM_BACKDOOR,
  UVM_PREDICT,
  UVM_DEFAULT_PATH
}
mixin(declareEnums!uvm_path_e());

// Enum: uvm_check_e
//
// Read-only or read-and-check
//
// UVM_NO_CHECK   - Read only
// UVM_CHECK      - Read and check
//   

enum uvm_check_e {
  UVM_NO_CHECK,
  UVM_CHECK
}
mixin(declareEnums!uvm_check_e());


// Enum: uvm_endianness_e
//
// Specifies byte ordering
//
// UVM_NO_ENDIAN      - Byte ordering not applicable
// UVM_LITTLE_ENDIAN  - Least-significant bytes first in consecutive addresses
// UVM_BIG_ENDIAN     - Most-significant bytes first in consecutive addresses
// UVM_LITTLE_FIFO    - Least-significant bytes first at the same address
// UVM_BIG_FIFO       - Most-significant bytes first at the same address
//   

enum uvm_endianness_e {
  UVM_NO_ENDIAN,
  UVM_LITTLE_ENDIAN,
  UVM_BIG_ENDIAN,
  UVM_LITTLE_FIFO,
  UVM_BIG_FIFO
}
mixin(declareEnums!uvm_endianness_e());

// Enum: uvm_elem_kind_e
//
// Type of element being read or written
//
// UVM_REG      - Register
// UVM_FIELD    - Field
// UVM_MEM      - Memory location
//

enum uvm_elem_kind_e {
  UVM_REG,
  UVM_FIELD,
  UVM_MEM
}
mixin(declareEnums!uvm_elem_kind_e());


// Enum: uvm_access_e
//
// Type of operation begin performed
//
// UVM_READ     - Read operation
// UVM_WRITE    - Write operation
//

enum uvm_access_e {
  UVM_READ,
  UVM_WRITE,
  UVM_BURST_READ,
  UVM_BURST_WRITE
}
mixin(declareEnums!uvm_access_e());


// Enum: uvm_hier_e
//
// Whether to provide the requested information from a hierarchical context.
//
// UVM_NO_HIER - Provide info from the local context
// UVM_HIER    - Provide info based on the hierarchical context

enum uvm_hier_e {
  UVM_NO_HIER,
  UVM_HIER
}
mixin(declareEnums!uvm_hier_e());



// Enum: uvm_predict_e
//
// How the mirror is to be updated
//
// UVM_PREDICT_DIRECT  - Predicted value is as-is
// UVM_PREDICT_READ    - Predict based on the specified value having been read
// UVM_PREDICT_WRITE   - Predict based on the specified value having been written
//
enum uvm_predict_e {
  UVM_PREDICT_DIRECT,
  UVM_PREDICT_READ,
  UVM_PREDICT_WRITE
}
mixin(declareEnums!uvm_predict_e());


// Enum: uvm_coverage_model_e
//
// Coverage models available or desired.
// Multiple models may be specified by bitwise OR'ing individual model identifiers.
//
// UVM_NO_COVERAGE      - None
// UVM_CVR_REG_BITS     - Individual register bits
// UVM_CVR_ADDR_MAP     - Individual register and memory addresses
// UVM_CVR_FIELD_VALS   - Field values
// UVM_CVR_ALL          - All coverage models
//

// typedef enum uvm_reg_cvr_t {
//    UVM_NO_COVERAGE      = 'h0000,
//    UVM_CVR_REG_BITS     = 'h0001,
//    UVM_CVR_ADDR_MAP     = 'h0002,
//    UVM_CVR_FIELD_VALS   = 'h0004,
//    UVM_CVR_ALL          = -1
// } uvm_coverage_model_e;

enum uvm_coverage_model_e {
   UVM_NO_COVERAGE      = 0x0000,
   UVM_CVR_REG_BITS     = 0x0001,
   UVM_CVR_ADDR_MAP     = 0x0002,
   UVM_CVR_FIELD_VALS   = 0x0004,
   UVM_CVR_ALL          = -1
}
mixin(declareEnums!uvm_coverage_model_e());

// Enum: uvm_reg_mem_tests_e
//
// Select which pre-defined test sequence to execute.
//
// Multiple test sequences may be selected by bitwise OR'ing their
// respective symbolic values.
//
// UVM_DO_REG_HW_RESET      - Run <uvm_reg_hw_reset_seq>
// UVM_DO_REG_BIT_BASH      - Run <uvm_reg_bit_bash_seq>
// UVM_DO_REG_ACCESS        - Run <uvm_reg_access_seq>
// UVM_DO_MEM_ACCESS        - Run <uvm_mem_access_seq>
// UVM_DO_SHARED_ACCESS     - Run <uvm_reg_mem_shared_access_seq>
// UVM_DO_MEM_WALK          - Run <uvm_mem_walk_seq>
// UVM_DO_ALL_REG_MEM_TESTS - Run all of the above
//
// Test sequences, when selected, are executed in the
// order in which they are specified above.
//
// typedef enum bit [63:0] {
//   UVM_DO_REG_HW_RESET      = 64'h0000_0000_0000_0001,
//   UVM_DO_REG_BIT_BASH      = 64'h0000_0000_0000_0002,
//   UVM_DO_REG_ACCESS        = 64'h0000_0000_0000_0004,
//   UVM_DO_MEM_ACCESS        = 64'h0000_0000_0000_0008,
//   UVM_DO_SHARED_ACCESS     = 64'h0000_0000_0000_0010,
//   UVM_DO_MEM_WALK          = 64'h0000_0000_0000_0020,
//   UVM_DO_ALL_REG_MEM_TESTS = 64'hffff_ffff_ffff_ffff 
// } uvm_reg_mem_tests_e;

enum uvm_reg_mem_tests_e: long {
  UVM_DO_REG_HW_RESET      = 0x0000_0000_0000_0001,
  UVM_DO_REG_BIT_BASH      = 0x0000_0000_0000_0002,
  UVM_DO_REG_ACCESS        = 0x0000_0000_0000_0004,
  UVM_DO_MEM_ACCESS        = 0x0000_0000_0000_0008,
  UVM_DO_SHARED_ACCESS     = 0x0000_0000_0000_0010,
  UVM_DO_MEM_WALK          = 0x0000_0000_0000_0020,
  UVM_DO_ALL_REG_MEM_TESTS = 0xffff_ffff_ffff_ffff 
}
mixin(declareEnums!uvm_reg_mem_tests_e());


//-----------------------
// Group: Utility Classes
//-----------------------

//------------------------------------------------------------------------------
// Class: uvm_hdl_path_concat
//
// Concatenation of HDL variables
//
// An dArray of <uvm_hdl_path_slice> specifing a concatenation
// of HDL variables that implement a register in the HDL.
//
// Slices must be specified in most-to-least significant order.
// Slices must not overlap. Gaps may exists in the concatentation
// if portions of the registers are not implemented.
//
// For example, the following register
//|
//|        1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0
//| Bits:  5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
//|       +-+---+-------------+---+-------+
//|       |A|xxx|      B      |xxx|   C   |
//|       +-+---+-------------+---+-------+
//|
//
// If the register is implementd using a single HDL variable,
// The array should specify a single slice with its ~offset~ and ~size~
// specified as -1. For example:
//
//| concat.set('{ '{"r1", -1, -1} });
//
//------------------------------------------------------------------------------

class uvm_hdl_path_concat
{

  // Variable: slices
  // Array of individual slices,
  // stored in most-to-least significant order
  uvm_hdl_path_slice[] slices;

  // Function: set
  // Initialize the concatenation using an array literal
  void set(uvm_hdl_path_slice[] t) {
    synchronized(this) {
      slices = t;
    }
  }

  // Function: add_slice
  // Append the specified ~slice~ literal to the path concatenation
  void add_slice(uvm_hdl_path_slice slice) {
    synchronized(this) {
      slices ~= slice;
    }
  }

  // Function: add_path
  // Append the specified ~path~ to the path concatenation,
  // for the specified number of bits at the specified ~offset~.
  void add_path(string path,
		uint offset = -1,
		uint size = -1) {
    uvm_hdl_path_slice t;
    t.offset = offset;
    t.path   = path;
    t.size   = size;
      
    add_slice(t);
  }
}   




// concat2string

// function automatic string uvm_hdl_concat2string(uvm_hdl_path_concat concat);
string uvm_hdl_concat2string(uvm_hdl_path_concat concat) {
  string image = "{";
   
  if (concat.slices.length == 1 &&
      concat.slices[0].offset == -1 &&
      concat.slices[0].size == -1) {
    return concat.slices[0].path;
  }

  foreach (i, slice; concat.slices) {
    image ~= (i == 0) ? "" : ", " ~ slice.path;
    if (slice.offset >= 0) {
      image ~= "@" ~ format("[%0d +: %0d]", slice.offset, slice.size);
    }
  }
  image ~= "}";

  return image;
}


// typedef struct packed {
//   uvm_reg_addr_t min;
//   uvm_reg_addr_t max;
//   int unsigned stride;
//   } uvm_reg_map_addr_range;

struct uvm_reg_map_addr_range {
  uvm_reg_addr_t min;
  uvm_reg_addr_t max;
  uint stride;
}


// `include "reg/uvm_reg_item.svh"
// `include "reg/uvm_reg_adapter.svh"
// `include "reg/uvm_reg_predictor.svh"
// `include "reg/uvm_reg_sequence.svh"
// `include "reg/uvm_reg_cbs.svh"
// `include "reg/uvm_reg_backdoor.svh"
// `include "reg/uvm_reg_field.svh"
// `include "reg/uvm_vreg_field.svh"
// `include "reg/uvm_reg.svh"
// `include "reg/uvm_reg_indirect.svh"
// `include "reg/uvm_reg_fifo.svh"
// `include "reg/uvm_reg_file.svh"
// `include "reg/uvm_mem_mam.svh"
// `include "reg/uvm_vreg.svh"
// `include "reg/uvm_mem.svh"
// `include "reg/uvm_reg_map.svh"
// `include "reg/uvm_reg_block.svh"

// `include "reg/sequences/uvm_reg_hw_reset_seq.svh"
// `include "reg/sequences/uvm_reg_bit_bash_seq.svh"
// `include "reg/sequences/uvm_mem_walk_seq.svh"
// `include "reg/sequences/uvm_mem_access_seq.svh"
// `include "reg/sequences/uvm_reg_access_seq.svh"
// `include "reg/sequences/uvm_reg_mem_shared_access_seq.svh"
// `include "reg/sequences/uvm_reg_mem_built_in_seq.svh"
// `include "reg/sequences/uvm_reg_mem_hdl_paths_seq.svh"
