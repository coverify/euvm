//
// -------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2015-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2004-2010 Synopsys, Inc.
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

import uvm.base.uvm_resource_db: uvm_resource_db;
import uvm.meta.misc;

import std.string: format;
//------------------------------------------------------------------------------
// TITLE -- NODOCS -- Global Declarations for the Register Layer
//------------------------------------------------------------------------------
//
// This section defines globally available types, enums, and utility classes.
//
//------------------------------------------------------------------------------

//-------------
// Group -- NODOCS -- Types
//-------------

// Type -- NODOCS -- uvm_reg_data_t
//
// 2-state data value with <`UVM_REG_DATA_WIDTH> bits
//
// alias uvm_reg_data_t = UBit!UVM_REG_DATA_WIDTH;
alias uvm_reg_data_t = UBit!UVM_REG_DATA_WIDTH;


// Type -- NODOCS -- uvm_reg_data_logic_t
//
// 4-state data value with <`UVM_REG_DATA_WIDTH> bits
//
// alias uvm_reg_data_logic_t = UBit!UVM_REG_DATA_WIDTH;
// static if (UVM_REG_DATA_WIDTH == 8) {
//   alias uvm_reg_data_logic_t = ubyte;
//  }
//  else static if (UVM_REG_DATA_WIDTH == 16) {
//    alias uvm_reg_data_logic_t = ushort;
//  }
//  else static if (UVM_REG_DATA_WIDTH == 32) {
//    alias uvm_reg_data_logic_t = uint;
//  }
//  else static if (UVM_REG_DATA_WIDTH == 64) {
//    alias uvm_reg_data_logic_t = ulong;
//  }
//  else {
   alias uvm_reg_data_logic_t = ULogic!UVM_REG_DATA_WIDTH;
// }

// Type -- NODOCS -- uvm_reg_addr_t
//
// 2-state address value with <`UVM_REG_ADDR_WIDTH> bits
//
// alias uvm_reg_addr_t = UBit!UVM_REG_ADDR_WIDTH;
static if (UVM_REG_ADDR_WIDTH == 8) {
  alias uvm_reg_addr_t = ubyte;
 }
 else static if (UVM_REG_ADDR_WIDTH == 16) {
   alias uvm_reg_addr_t = ushort;
 }
 else static if (UVM_REG_ADDR_WIDTH == 32) {
   alias uvm_reg_addr_t = uint;
 }
 else static if (UVM_REG_ADDR_WIDTH == 64) {
   alias uvm_reg_addr_t = ulong;
 }
 else {
   alias uvm_reg_addr_t = UBit!UVM_REG_ADDR_WIDTH;
 }

alias uvm_reg_addr_bvec_t = UBit!UVM_REG_ADDR_WIDTH;

// Type -- NODOCS -- uvm_reg_addr_logic_t
//
// 4-state address value with <`UVM_REG_ADDR_WIDTH> bits
//
// alias uvm_reg_addr_logic_t = UBit!UVM_REG_ADDR_WIDTH;
// static if (UVM_REG_ADDR_WIDTH == 8) {
//   alias uvm_reg_addr_logic_t = ubyte;
//  }
//  else static if (UVM_REG_ADDR_WIDTH == 16) {
//    alias uvm_reg_addr_logic_t = ushort;
//  }
//  else static if (UVM_REG_ADDR_WIDTH == 32) {
//    alias uvm_reg_addr_logic_t = uint;
//  }
//  else static if (UVM_REG_ADDR_WIDTH == 64) {
//    alias uvm_reg_addr_logic_t = ulong;
//  }
//  else {
   alias uvm_reg_addr_logic_t = ULogic!UVM_REG_ADDR_WIDTH;
// }


// Type -- NODOCS -- uvm_reg_byte_en_t
//
// 2-state byte_enable value with <`UVM_REG_BYTENABLE_WIDTH> bits
//
// static if (UVM_REG_BYTENABLE_WIDTH == 8) {
//   alias uvm_reg_byte_en_t = ubyte;
//  }
//  else static if (UVM_REG_BYTENABLE_WIDTH == 16) {
//    alias uvm_reg_byte_en_t = ushort;
//  }
//  else static if (UVM_REG_BYTENABLE_WIDTH == 32) {
//    alias uvm_reg_byte_en_t = uint;
//  }
//  else static if (UVM_REG_BYTENABLE_WIDTH == 64) {
//    alias uvm_reg_byte_en_t = ulong;
//  }
//  else {
alias uvm_reg_byte_en_t = UBit!UVM_REG_BYTENABLE_WIDTH;
// }

alias uvm_reg_byte_en_bvec_t = UBit!UVM_REG_BYTENABLE_WIDTH;

// Type -- NODOCS -- uvm_reg_cvr_t
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
static if (UVM_REG_CVR_WIDTH == 8) {
  alias uvm_reg_cvr_t = ubyte;
 }
 else static if (UVM_REG_CVR_WIDTH == 16) {
   alias uvm_reg_cvr_t = ushort;
 }
 else static if (UVM_REG_CVR_WIDTH == 32) {
   alias uvm_reg_cvr_t = uint;
 }
 else static if (UVM_REG_CVR_WIDTH == 64) {
   alias uvm_reg_cvr_t = ulong;
 }
 else {
   alias uvm_reg_cvr_t = UBit!UVM_REG_CVR_WIDTH;
 }

alias uvm_reg_cvr_bvec_t = UBit!UVM_REG_CVR_WIDTH;

// Type -- NODOCS -- uvm_hdl_path_slice
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

struct uvm_hdl_path_slice {
  string _path;
  string path() {return _path;}
  void path(string val) {_path = val;}

  int    _offset;
  int offset() {return _offset;}
  void offset(int val) {_offset = val;}

  int    _size;
  int size() {return _size;}
  void size(int val) {_size = val;}
}


alias uvm_reg_cvr_rsrc_db = uvm_resource_db!uvm_reg_cvr_t;



//--------------------
// Group -- NODOCS -- Enumerations
//--------------------

// Enum -- NODOCS -- uvm_status_e
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

// Enum -- NODOCS -- uvm_path_e
//
// Path used for register operation
//
// UVM_FRONTDOOR    - Use the front door
// UVM_BACKDOOR     - Use the back door
// UVM_PREDICT      - Operation derived from observations by a bus monitor via
//                    the <uvm_reg_predictor> class.
// UVM_DEFAULT_DOOR - Operation specified by the context
//

enum uvm_door_e {
  UVM_FRONTDOOR,
  UVM_BACKDOOR,
  UVM_PREDICT,
  UVM_DEFAULT_DOOR
}
mixin(declareEnums!uvm_door_e());

// Enum -- NODOCS -- uvm_check_e
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


// Enum -- NODOCS -- uvm_endianness_e
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

// Enum -- NODOCS -- uvm_elem_kind_e
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


// Enum -- NODOCS -- uvm_access_e
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


// Enum -- NODOCS -- uvm_hier_e
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



// Enum -- NODOCS -- uvm_predict_e
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


// Enum -- NODOCS -- uvm_coverage_model_e
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

enum uvm_coverage_model_e {
  UVM_NO_COVERAGE      = 0x0000,
  UVM_CVR_REG_BITS     = 0x0001,
  UVM_CVR_ADDR_MAP     = 0x0002,
  UVM_CVR_FIELD_VALS   = 0x0004,
  UVM_CVR_ALL          = -1
}
mixin(declareEnums!uvm_coverage_model_e());

// Enum -- NODOCS -- uvm_reg_mem_tests_e
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

enum uvm_reg_mem_tests_e: ulong
{   UVM_DO_REG_HW_RESET      = 0x0000_0000_0000_0001,
    UVM_DO_REG_BIT_BASH      = 0x0000_0000_0000_0002,
    UVM_DO_REG_ACCESS        = 0x0000_0000_0000_0004,
    UVM_DO_MEM_ACCESS        = 0x0000_0000_0000_0008,
    UVM_DO_SHARED_ACCESS     = 0x0000_0000_0000_0010,
    UVM_DO_MEM_WALK          = 0x0000_0000_0000_0020,
    UVM_DO_ALL_REG_MEM_TESTS = 0xffff_ffff_ffff_ffff 
    }
mixin(declareEnums!uvm_reg_mem_tests_e());


//-----------------------
// Group -- NODOCS -- Utility Classes
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

// @uvm-ieee 1800.2-2020 auto 17.2.3.2
class uvm_hdl_path_concat
{

  // Variable: slices
  // Array of individual slices,
  // stored in most-to-least significant order
  private uvm_hdl_path_slice[] _slices;

  uvm_hdl_path_slice[] slices() {
    synchronized(this) {
      return _slices.dup;
    }
  }

  void slices(uvm_hdl_path_slice[] t) {
    synchronized(this) {
      _slices = t.dup;
    }
  }

  
  // Function -- NODOCS -- set
  // Initialize the concatenation using an array literal
  void set(uvm_hdl_path_slice[] t) {
    synchronized(this) {
      _slices = t.dup;
    }
  }

  // Function -- NODOCS -- add_slice
  // Append the specified ~slice~ literal to the path concatenation
  // @uvm-ieee 1800.2-2020 auto 17.2.3.3.4
  void add_slice(uvm_hdl_path_slice slice) {
    synchronized(this) {
      _slices ~= slice;
    }
  }

  // Function -- NODOCS -- add_path
  // Append the specified ~path~ to the path concatenation,
  // for the specified number of bits at the specified ~offset~.
  void add_path(string path,
		uint offset = -1,
		uint size = -1) {
    uvm_hdl_path_slice t;
    t._offset = offset;
    t._path   = path;
    t._size   = size;
      
    add_slice(t);
  }
}   




// concat2string

// function automatic string uvm_hdl_concat2string(uvm_hdl_path_concat concat);
string uvm_hdl_concat2string(uvm_hdl_path_concat concat) {
  synchronized(concat) {
    string image = "{";
    if (concat._slices.length == 1 &&
	concat._slices[0]._offset == -1 &&
	concat._slices[0]._size == -1) {
      return concat._slices[0]._path;
    }
  
    foreach (i, slice; concat._slices) {
      image ~= (i == 0) ? "" : ", " ~ slice._path;
      if (slice._offset >= 0) {
	image ~= "@" ~ format("[%0d +: %0d]", slice._offset, slice._size);
      }
    }
    image ~= "}";

    return image;
  }
}


struct uvm_reg_map_addr_range {
  uvm_reg_addr_t _min;
  uvm_reg_addr_t min() {return _min;}
  void min(uvm_reg_addr_t val) {_min = val;}
  uvm_reg_addr_t _max;
  uvm_reg_addr_t max() {return _max;}
  void max(uvm_reg_addr_t val) {_max = val;}
  uint _stride;
  uint stride() {return _stride;}
  void stride(uint val) {_stride = val;}
}


