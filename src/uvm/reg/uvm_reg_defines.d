//----------------------------------------------------------------------
// Copyright 2014-2021 Coverify Systems Technology
// Copyright 2010 AMD
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
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

module uvm.reg.uvm_reg_defines;

//------------------------
// Group -- NODOCS -- Register Defines
//------------------------

// Macro -- NODOCS -- `UVM_REG_ADDR_WIDTH
//
// Maximum address width in bits
//
// Default value is 64. Used to define the <uvm_reg_addr_t> type.
//
// @uvm-ieee 1800.2-2020 auto B.6.4
enum int UVM_REG_ADDR_WIDTH = 64;


// Macro -- NODOCS -- `UVM_REG_DATA_WIDTH
//
// Maximum data width in bits
//
// Default value is 64. Used to define the <uvm_reg_data_t> type.
//
// @uvm-ieee 1800.2-2020 auto B.6.5
enum int UVM_REG_DATA_WIDTH = 64;


// Macro -- NODOCS -- `UVM_REG_BYTENABLE_WIDTH
//
// Maximum number of byte enable bits
//
// Default value is one per byte in <`UVM_REG_DATA_WIDTH>.
// Used to define the <uvm_reg_byte_en_t> type.
//
// @uvm-ieee 1800.2-2020 manual B.6.6
enum int UVM_REG_BYTENABLE_WIDTH = (UVM_REG_DATA_WIDTH-1)/8 + 1;

// Macro -- NODOCS -- `UVM_REG_CVR_WIDTH
//
// Maximum number of bits in a <uvm_reg_cvr_t> coverage model set.
//
// Default value is 32.
//
// @uvm-ieee 1800.2-2020 auto B.6.7
enum int UVM_REG_CVR_WIDTH = 32;
