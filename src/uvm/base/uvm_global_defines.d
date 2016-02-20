//------------------------------------------------------------------------------
//   Copyright 2014 Synopsys, Inc.
//   Copyright 2016 Coverify Systems Technology
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

module uvm.base.uvm_global_defines;
import esdl.data.time;

//
// Title: Global Macros 
//------------------------
// Group: Global object Macro definitions can be used in multiple locations
//------------------------
//
// MACRO: `UVM_MAX_STREAMBITS
//
// Defines the maximum bit vector size for integral types. 
// Used to set uvm_bitstream_t

enum UVM_MAX_STREAMBITS=4096;


// MACRO: `UVM_PACKER_MAX_BYTES
//
// Defines the maximum bytes to allocate for packing an object using
// the <uvm_packer>. Default is <`UVM_MAX_STREAMBITS>, in ~bytes~.

enum UVM_PACKER_MAX_BYTES=UVM_MAX_STREAMBITS;

//------------------------
// Group: Global Time Macro definitions that can be used in multiple locations
//------------------------

// MACRO: `UVM_DEFAULT_TIMEOUT
//
// The default timeout for simulation, if not overridden by
// <uvm_root::set_timeout> or <uvm_cmdline_processor::+UVM_TIMEOUT>
//

enum UVM_DEFAULT_TIMEOUT=9200.sec;
