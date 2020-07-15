//
//------------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2018 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2017 Intel Corporation
// Copyright 2010-2014 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013 Verilab
// Copyright 2012 AMD
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2014-2018 Cisco Systems, Inc.
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

// File -- NODOCS -- Miscellaneous Structures

module uvm.base.uvm_misc;

//------------------------------------------------------------------------------
//
// Class -- NODOCS -- uvm_void
//
// The ~uvm_void~ class is the base class for all UVM classes. It is an abstract
// class with no data members or functions. It allows for generic containers of
// objects to be created, similar to a void pointer in the C programming
// language. User classes derived directly from ~uvm_void~ inherit none of the
// UVM functionality, but such classes may be placed in ~uvm_void~-typed
// containers along with other UVM objects.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_factory: uvm_factory;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_object_globals: uvm_radix_enum;


import uvm.base.uvm_once;

import uvm.meta.misc;

import esdl.data.bvec;
import esdl.base.core: Event;

import std.traits: isIntegral, isSigned, isBoolean;
import std.algorithm: find, canFind;
import std.conv: to;
import std.range: ElementType;

interface uvm_void_if { }

// @uvm-ieee 1800.2-2017 auto 5.2
abstract class uvm_void: uvm_void_if {
  // Randomization mixin is in uvm_object class
  // mixin Randomization;
}



// alias m_uvm_config_obj_misc = uvm_config_db!(uvm_object);


// Append/prepend symbolic values for order-dependent APIs
enum uvm_apprepend: bool
  {   UVM_APPEND = false,
      UVM_PREPEND = true
      }


// Forward declaration since scope stack uses uvm_objects now
// typedef class uvm_object;



// Class- uvm_seed_map
//
// This map is a seed map that can be used to update seeds. The update
// is done automatically by the seed hashing routine. The seed_table_lookup
// uses an instance name lookup and the seed_table inside a given map
// uses a type name for the lookup.
//
final class uvm_seed_map
{
  static class uvm_once: uvm_once_base
  {
    // ** from uvm_misc
    // Variable- m_global_random_seed
    //
    // Create a seed which is based off of the global seed which can be used to seed
    // srandom processes but will change if the command line seed setting is
    // changed.
    //
    @uvm_public_sync
    private uint _m_global_random_seed;

    // ** from uvm_misc -- global variable in SV
    // assoc array -- make sure all accesses are under once guard
    private uvm_seed_map[string] _uvm_random_seed_table_lookup;
  }

  mixin (uvm_once_sync_string);

  static void set_seed(uint seed) {
    synchronized (_uvm_once_inst) {
      _uvm_once_inst._m_global_random_seed = seed;
    }
  }

  private uint[string] _seed_table;
  private uint[string] _count;

  static private uint map_random_seed(string type_id, string inst_id="") {
    uvm_seed_map seed_map;

    if (inst_id == "")
      inst_id = "__global__";

    type_id =  uvm_instance_scope() ~ type_id;

    synchronized (_uvm_once_inst) {
      if (inst_id !in _uvm_once_inst._uvm_random_seed_table_lookup)
	_uvm_once_inst._uvm_random_seed_table_lookup[inst_id] = new uvm_seed_map();
      seed_map = _uvm_once_inst._uvm_random_seed_table_lookup[inst_id];
    }

    return seed_map.create_random_seed(type_id, inst_id);
  }

  // Function- uvm_create_random_seed
  //
  // Creates a random seed and updates the seed map so that if the same string
  // is used again, a new value will be generated. The inst_id is used to hash
  // by instance name and get a map of type name hashes which the type_id uses
  // for its lookup.

  private uint create_random_seed(string type_id, string inst_id="") {
    synchronized (this) {
      if (type_id !in _seed_table) {
	_seed_table[type_id] = uvm_oneway_hash(type_id ~ "." ~ inst_id,
					       m_global_random_seed);
      }
      if (type_id !in _count) {
	_count[type_id] = 0;
      }

      //can't just increment, otherwise too much chance for collision, so
      //randomize the seed using the last seed as the seed value. Check if
      //the seed has been used before and if so increment it.
      _seed_table[type_id] = _seed_table[type_id] + _count[type_id];
      _count[type_id] += 1;

      return _seed_table[type_id];
    }
  }

  // Function- uvm_oneway_hash
  //
  // A one-way hash function that is useful for creating srandom seeds. An
  // unsigned int value is generated from the string input. An initial seed can
  // be used to seed the hash, if not supplied the m_global_random_seed
  // value is used. Uses a CRC like functionality to minimize collisions.
  //

  // TBD -- replace all this junk with std.hash implementation once it
  // gets into DMD

  static private uint uvm_oneway_hash(string string_in, uint seed=0) {
    enum int UVM_STR_CRC_POLYNOMIAL = 0x04c11db6;
    bool          msb;
    ubyte         current_byte;
    uint          crc1 = 0xffffffff;

    if (seed == 0) seed = uvm_global_random_seed;
    uint uvm_oneway_hash_ = seed;

    for (int _byte=0; _byte < string_in.length; _byte++) {
      current_byte = cast (ubyte) string_in[_byte];
      if (current_byte is 0) break;
      for (int _bit=0; _bit < 8; _bit++) {
	msb = cast (bool) (crc1 >>> 31);
	crc1 <<= 1;
	if (msb ^ ((current_byte >> _bit) & 1)) {
	  crc1 ^=  UVM_STR_CRC_POLYNOMIAL;
	  crc1 |= 1;
	}
      }
    }
    uint byte_swapped_crc1 = 0;
    for (int i = 0; i !is 4; ++i) {
      byte_swapped_crc1 <<= 8;
      byte_swapped_crc1 += (crc1 >> i*8) & 0x000000ff;
    }

    // uvm_oneway_hash_ += ~{crc1[7:0], crc1[15:8], crc1[23:16], crc1[31:24]};
    uvm_oneway_hash_ += ~byte_swapped_crc1;
    return uvm_oneway_hash_;
  }

}

uint uvm_create_random_seed(string type_id, string inst_id="") {
  return uvm_seed_map.map_random_seed(type_id, inst_id);
}

uint uvm_global_random_seed() {
  return uvm_seed_map.m_global_random_seed;
}

//------------------------------------------------------------------------------
// Internal utility functions
//------------------------------------------------------------------------------

// Function- uvm_instance_scope
//
// A function that returns the scope that the UVM library lives in, either
// an instance, a module, or a package.
//
string uvm_instance_scope() {
  return "uvm.";
}

// Function- uvm_object_value_str
//
//

string uvm_object_value_str(uvm_object v) {
  import std.conv;
  if (v is null) return "<null>";
  else return "@" ~ (v.get_inst_id()).to!string();
}

  
// Function- uvm_leaf_scope
//
//
string uvm_leaf_scope (string full_name, char scope_separator = '.') {
  char bracket_match;

  switch (scope_separator) {
  case '[': bracket_match = ']'; break;
  case '(': bracket_match = ')'; break;
  case '<': bracket_match = '>'; break;
  case '{': bracket_match = '}'; break;
  // SV uses "" where we use '\0' (null character)
  // We use null character since the intention is to match nothing
  // when compared against that character
  default : bracket_match = '\0'; break;
  }

  //Only use bracket matching if the input string has the end match
  if (bracket_match != '\0' && bracket_match != full_name[$-1])
    bracket_match = '\0';

  int  bmatches = 0;
  size_t  pos;
  for (pos=full_name.length-1; pos > 0; --pos) {
    if (full_name[pos] == bracket_match) ++bmatches;
    else if (full_name[pos] == scope_separator) {
      --bmatches;
      if (!bmatches || (bracket_match == '\0')) {
	break;
      }
    }
  }
  if (pos) {
    if (scope_separator !is '.') --pos;
    return full_name[pos+1..$];
  }
  else {
    return full_name;
  }
}

// Function- uvm_bitstream_to_string
//
//
string uvm_to_string(T)(T value,
			uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX,
			string radix_str="")
  if (isBitVector!T || isIntegral!T || isBoolean!T) {
    import std.string: format;
    static if (isIntegral!T)       _bvec!T val = value;
    else static if (isBoolean!T) Bit!1 val = value;
    else                        alias val = value;

    // sign extend & don't show radix for negative values
    if (radix == uvm_radix_enum.UVM_DEC && (cast (Bit!1) val[$-1]) is 1) {
      return format("%0d", val);
    }

    switch (radix) {
    case uvm_radix_enum.UVM_BIN:      return format("%0s%0b", radix_str, val);
    case uvm_radix_enum.UVM_OCT:      return format("%0s%0o", radix_str, val);
    case uvm_radix_enum.UVM_UNSIGNED: return format("%0s%0d", radix_str, val);
    case uvm_radix_enum.UVM_STRING:   return format("%0s%0s", radix_str, val);
    case uvm_radix_enum.UVM_ENUM:     return format("%0s%s (%s)",  radix_str, value, val);
      // SV UVM uses %0t for time
    case uvm_radix_enum.UVM_TIME:     return format("%0s%0d", radix_str, val);
    case uvm_radix_enum.UVM_DEC:      return format("%0s%0d", radix_str, val);
    default:           return format("%0s%0x", radix_str, val);
    }
  }

string uvm_bitvec_to_string(T)(T value, size_t size,
			       uvm_radix_enum radix=uvm_radix_enum.UVM_NORADIX,
			       string radix_str="") {
  import std.string: format;
  // sign extend & don't show radix for negative values
  static if (isBitVector!T && T.ISSIGNED) {
    if (radix == uvm_radix_enum.UVM_DEC && (cast (Bit!1) value[$-1]) is 1) {
      return format("%0d", value);
    }
  }

  static if (isIntegral!T && isSigned!T) {
    import std.string: format;
    if (radix == uvm_radix_enum.UVM_DEC && value < 0) {
      return format("%0d", value);
    }
  }

  // TODO $countbits(value,'z) would be even better
  static if (isBitVector!T) {
    if (size < T.SIZE) {
      if (value.isX()) {
	T t_ = 0;
	for (int idx=0 ; idx<size; idx++) {
	  t_[idx] = value[idx];
	}
	value = t_;
      }
      else {
	T t_ = 1;
	value &= ((t_ << size) - 1);
      }
    }
  }
  else static if (isIntegral!T) {
    if (size < T.sizeof * 8) {
      T t_ = cast (T) 1;
      T mask = cast (T) ((t_ << size) - 1);
      value &= mask;
    }
  }

  switch (radix) {
  case uvm_radix_enum.UVM_BIN:      return format("%0s%0" ~ size.to!string ~ "b",
						  radix_str, value);
  case uvm_radix_enum.UVM_OCT:      return format("%0s%0" ~
						  ((size+2)/3).to!string ~ "o",
						  radix_str, value);
  case uvm_radix_enum.UVM_UNSIGNED: return format("%0s%0d", radix_str, value);
  case uvm_radix_enum.UVM_STRING:   return format("%0s%0s", radix_str, value);
  case uvm_radix_enum.UVM_TIME:     return format("%0s%0d", radix_str, value);
  case uvm_radix_enum.UVM_DEC:      return format("%0s%0d", radix_str, value);
  case uvm_radix_enum.UVM_HEX:      return format("%0s%0" ~
						  ((size+3)/4).to!string ~ "x",
						  radix_str, value);
  case uvm_radix_enum.UVM_ENUM:     return format("%0s0x%0" ~
						  ((size+3)/4).to!string ~ "x [%0s]",
						  radix_str, value, value);
  default:                          return format("%0s%0" ~
						  ((size+3)/4).to!string ~ "x",
						  radix_str, value);
  }
}

// Moved to uvm_aliases
// alias uvm_bitstream_to_string = uvm_bitvec_to_string!uvm_bitstream_t;
// alias uvm_integral_to_string  = uvm_bitvec_to_string!uvm_integral_t;


// Function- uvm_get_array_index_int
//
// The following functions check to see if a string is representing an array
// index, and if so, what the index is.

int uvm_get_array_index_int(string arg, out bool is_wildcard) {
  int uvm_get_array_index_int_ = 0;
  is_wildcard = true;
  auto i = arg.length - 1;
  if (arg[i] == ']') {
    while (i > 0 && (arg[i] != '[')) {
      --i;
      if ((arg[i] == '*') || (arg[i] == '?')) i = 0;
      else if ((arg[i] < '0') || (arg[i] > '9') && (arg[i] != '[')) {
	uvm_get_array_index_int_ = -1; //illegal integral index
	i = 0;
      }
    }
  }
  else {
    is_wildcard = false;
    return 0;
  }

  if (i > 0) {
    arg = arg[i+1..$-1];
    uvm_get_array_index_int_ = arg.to!int();
    is_wildcard = false;
  }
  return uvm_get_array_index_int_;
}

// Function- uvm_get_array_index_string
//
//
string uvm_get_array_index_string(string arg, out bool is_wildcard) {
  string uvm_get_array_index_string_;
  is_wildcard = true;
  auto i = arg.length - 1;
  if (arg[i] == ']')
    while (i > 0 && (arg[i] != '[')) {
      if ((arg[i] == '*') || (arg[i] == '?')) i = 0;
      --i;
    }
  if (i > 0) {
    uvm_get_array_index_string_ = arg[i+1..$-1];
    is_wildcard = false;
  }
  return uvm_get_array_index_string_;
}


// Function- uvm_is_array
//
//
bool uvm_is_array(string arg) {
  return arg[$-1] == ']';
}


// Function- uvm_has_wildcard
//
//
bool uvm_has_wildcard (string arg) {
  //if it is a regex then return true
  if ((arg.length > 1) && (arg[0] == '/') && (arg[$-1] == '/'))
    return true;

  //check if it has globs
  foreach (c; arg)
    if ( (c == '*') || (c == '+') || (c == '?') )
      return true;

  return false;
}


version (UVM_USE_PROCESS_CONTAINER) {
  import esdl.base.core;
  final class process_container_c
  {
    mixin (uvm_sync_string);

    @uvm_immutable_sync
    private Process _p;

    this(Process p) {
      synchronized (this) {
	_p = p;
      }
    }
  }
}


// this is an internal function and provides a string join independent of a streaming pack
string m_uvm_string_queue_join(string[] strs) {
  string result;
  foreach (str; strs) {
    result ~= str;
  }
  return result;
}

void uvm_wait_for_ever() {
  Event never;
  never.wait();
}

template UVM_ELEMENT_TYPE(T)
{
  static if (is (T == string)) {
    alias UVM_ELEMENT_TYPE = T;
  }
  else {
    alias E = ElementType!T;
    static if (is (E == void)) {
      alias UVM_ELEMENT_TYPE = T;
    }
    else {
      alias UVM_ELEMENT_TYPE = UVM_ELEMENT_TYPE!E;
    }
  }
}

template UVM_IN_TUPLE(size_t I, alias S, A...) {
  static if (I < A.length) {
    static if (is (typeof(A[I]) == typeof(S)) && A[I] == S) {
      enum bool UVM_IN_TUPLE = true;
    }
    else {
      enum bool UVM_IN_TUPLE = UVM_IN_TUPLE!(I+1, S, A);
    }
  }
  else {
    enum bool UVM_IN_TUPLE = false;
  }
}

// instead of macros as in SV version
string uvm_file(string FILE=__FILE__)() {
  return FILE;
}

size_t uvm_line(size_t LINE=__LINE__)() {
  return LINE;
}
