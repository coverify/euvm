//
//------------------------------------------------------------------------------
// Copyright 2012-2019 Coverify Systems Technology
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2018 Qualcomm, Inc.
// Copyright 2014 Intel Corporation
// Copyright 2018 Synopsys, Inc.
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013-2018 NVIDIA Corporation
// Copyright 2017-2018 Cisco Systems, Inc.
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


module uvm.base.uvm_packer;


//------------------------------------------------------------------------------
// CLASS -- NODOCS -- uvm_packer
//
// The uvm_packer class provides a policy object for packing and unpacking
// uvm_objects. The policies determine how packing and unpacking should be done.
// Packing an object causes the object to be placed into a bit (byte or int)
// array. If the `uvm_field_* macro are used to implement pack and unpack,
// by default no metadata information is stored for the packing of dynamic
// objects (strings, arrays, class objects).
//
//-------------------------------------------------------------------------------

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_policy: uvm_policy;
import uvm.base.uvm_factory: uvm_factory;
import uvm.base.uvm_field_op: uvm_field_op;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_coreservice: uvm_coreservice_t;
import uvm.base.uvm_object_globals: uvm_bitstream_t, uvm_integral_t,
  uvm_recursion_policy_enum, uvm_field_flag_t;

import uvm.meta.misc;

import esdl.data.packer: Packer;
import esdl.data.bvec;
import esdl.base.core: SimTime;
import esdl.data.time;
import std.string: format;
import std.traits;

// Class: uvm_packer
// Implementation of uvm_packer, as defined in section
// 16.5.1 of 1800.2-2017

// @uvm-ieee 1800.2-2017 auto 16.5.1
class uvm_packer: uvm_policy
{

  // @uvm-ieee 1800.2-2017 auto 16.5.2.3
  mixin uvm_object_essentials;
  mixin (uvm_sync_string);

  @uvm_public_sync
  private uvm_factory _m_factory;

  @uvm_private_sync
  private uvm_object[int] _m_object_references;
   

  // Function: set_packed_*
  // Implementation of P1800.2 16.5.3.1
  //
  // The LRM specifies the set_packed_* methods as being
  // signed, whereas the <uvm_object::unpack> methods are specified
  // as unsigned.  This is being tracked in Mantis 6423.
  //
  // The reference implementation has implemented these methods
  // as unsigned so as to remain consistent.
  //
  //| virtual function void set_packed_bits( ref bit unsigned stream[] );
  //| virtual function void set_packed_bytes( ref byte unsigned stream[] );
  //| virtual function void set_packed_ints( ref int unsigned stream[] );
  //| virtual function void set_packed_longints( ref longint unsigned stream[] );
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
   
  void set_packed(T)(ref T[] stream) {
    synchronized (this) {
      _m_bits.setPacked(stream);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.3.1
  void set_packed_bits(ref bool[] stream) {
    synchronized (this) {
      _m_bits.setPacked(stream);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.3.1
  void set_packed_bytes(ref ubyte[] stream) {
    synchronized (this) {
      _m_bits.setPacked(stream);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.3.1
  void set_packed_ints(ref uint[] stream) {
    synchronized (this) {
      _m_bits.setPacked(stream);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.3.1
  void set_packed_longints(ref ulong[] stream) {
    synchronized (this) {
      _m_bits.setPacked(stream);
    }
  }
   
  // Function: get_packed_*
  // Implementation of P1800.2 16.5.3.2
  //
  // The LRM specifies the get_packed_* methods as being
  // signed, whereas the <uvm_object::pack> methods are specified
  // as unsigned.  This is being tracked in Mantis 6423.
  //
  // The reference implementation has implemented these methods
  // as unsigned so as to remain consistent.
  //
  //| virtual function void get_packed_bits( ref bit unsigned stream[] );
  //| virtual function void get_packed_bytes( ref byte unsigned stream[] );
  //| virtual function void get_packed_ints( ref int unsigned stream[] );
  //| virtual function void get_packed_longints( ref longint unsigned stream[] );
  //
  // @uvm-contrib This API is being considered for potential contribution to 1800.2
   
  void get_packed(T)(ref T[] stream) {
    synchronized (this) {
      _m_bits.getPacked!T(stream);
    }
  }
  
  // @uvm-ieee 1800.2-2017 auto 16.5.3.2
  void get_packed_bits(ref bool[] stream) {
    synchronized (this) {
      _m_bits.getPacked(stream);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.3.2
  void get_packed_bytes(ref ubyte[] stream) {
    synchronized (this) {
      _m_bits.getPacked(stream);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.3.2
  void get_packed_ints(ref uint[] stream) {
    synchronized (this) {
      _m_bits.getPacked(stream);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.3.2
  void get_packed_longints(ref ulong[] stream) {
    synchronized (this) {
      _m_bits.getPacked(stream);
    }
  }
   
  //----------------//
  // Group -- NODOCS -- Packing //
  //----------------//

  // @uvm-ieee 1800.2-2017 auto 16.5.2.4
  static void set_default(uvm_packer packer) {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get();
    coreservice.set_default_packer(packer);
  }

  // @uvm-ieee 1800.2-2017 auto 16.5.2.5
  static uvm_packer get_default() {
    uvm_coreservice_t coreservice = uvm_coreservice_t.get();
    return coreservice.get_default_packer();
  }

  
  // @uvm-ieee 1800.2-2017 auto 16.5.2.2
  override void flush() {
    synchronized (this) {
      // The iterators are spaced 64b from the beginning, enough to store
      // the iterators during get_packed_* and retrieve them during
      // set_packed_*.  Without this, set_packed_[byte|int|longint] will
      // move the iterators too far.
      // m_pack_iter = 64;
      // m_unpack_iter = 64;
      // m_bits       = 0;
      _m_bits.clear();
      _m_object_references.clear();
      _m_object_references[0] = null;
      _m_factory = null;
      super.flush();
    }
  }
    

  
  //----------------//
  // Group -- NODOCS -- Packing //
  //----------------//

  void pack(T)(T value, size_t size=-1)
    if (isBitVector!T || isIntegral!T || isBoolean!T) {
      synchronized (this) {
	_m_bits.pack(value, size);
      }
    }

  void pack(T)(T value, size_t size=-1)
    if (isFloatingPoint!T ||
	is (T == SimTime) || is (T == Time)) {
      synchronized (this) {
	_m_bits.pack(value);
      }
    }

  void pack(T)(T value)
    if (is (T == string)) {
      synchronized (this) {
	_m_bits.pack(value);
	_m_bits.pack(cast (byte) 0);
      }
    }

  void pack(T)(T value)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      import uvm.base.uvm_globals;
      synchronized (this) {
	uvm_field_op field_op;
	if (value is null ) {
	  _m_bits.pack(0, 4);
	  return ;
	}
	else {
	  _m_bits.pack(0xF, 4);
	}
	push_active_object(value);
	field_op = uvm_field_op.m_get_available_op();
	field_op.set(uvm_field_auto_enum.UVM_PACK, this, value);
	value.do_execute_op(field_op);
	if (field_op.user_hook_enabled()) {
	  value.do_pack(this);
	}
	field_op.m_recycle();
	pop_active_object();
      }
    }



  // Function -- NODOCS -- pack_field
  //
  // Packs an integral value (less than or equal to 4096 bits) into the
  // packed array. ~size~ is the number of bits of ~value~ to pack.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.8
  void pack_field(uvm_bitstream_t value, size_t size) {
    synchronized (this) {
      bool bit;
      for (size_t i=0; i != size; ++i) {
	_m_bits.pack(bit);
	value[i] = bit;
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 16.5.2.1
  this(string name="") {
    synchronized (this) {
      super(name);
      flush();
    }
  }

  // Function -- NODOCS -- pack_field_int
  //
  // Packs the integral value (less than or equal to 64 bits) into the
  // pack array.  The ~size~ is the number of bits to pack, usually obtained by
  // ~$bits~. This optimized version of <pack_field> is useful for sizes up
  // to 64 bits.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.9
  void pack_field_int (uvm_integral_t value, size_t size) {
    synchronized (this) {
      for (size_t i = 0; i != size; ++i) {
	_m_bits.pack(value[i]);
      }
    }
  }


  void pack(T)(T value, in int size = -1)
    if (isArray!T) {
      enum E = ElementType!T;
      static assert (isIntegral!E || isBoolean!E || isBitVector!E);
      synchronized (this) {
	int max_size = value.length * BitCount!E;

	if (size < 0) {
	  size = max_size;
	}

	if (size > max_size) {
	  uvm_error("UVM/BASE/PACKER/BAD_SIZE",
		    format("pack_%ss called with size '%0d', which" ~
			   " exceeds value size of '%0d'",
			   E.stringof,
			   size,
			   max_size));
	  return;
	}
	else {
	  _m_bits.pack(value);
	}
      }
    }

  // @uvm-ieee 1800.2-2017 auto 16.5.4.1
  alias pack_bits = pack;
  
  // @uvm-ieee 1800.2-2017 auto 16.5.4.10
  alias pack_bytes = pack;

  // @uvm-ieee 1800.2-2017 auto 16.5.4.11
  alias pack_ints = pack;

  // recursion functions


  // Function -- NODOCS -- pack_string
  //
  // Packs a string value into the pack array.
  //
  // When the metadata flag is set, the packed string is terminated by a ~null~
  // character to mark the end of the string.
  //
  // This is useful for mixed language communication where unpacking may occur
  // outside of SystemVerilog UVM.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.5
  void pack_string (string value) {
    this.pack(value);
    this.pack(0, 8);
  }


  // Function -- NODOCS -- pack_time
  //
  // Packs a time ~value~ as 64 bits into the pack array.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.6
  void pack_time (SimTime value) {
    this.pack(value);
  }


  // Function -- NODOCS -- pack_real
  //
  // Packs a real ~value~ as 64 bits into the pack array.
  //
  // The real ~value~ is converted to a 6-bit scalar value using the function
  // $real2bits before it is packed into the array.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.7
  void pack_real (real value) {
    this.pack(value);
  }


  // Function -- NODOCS -- pack_object
  //
  // Packs an object value into the pack array.
  //
  // A 4-bit header is inserted ahead of the string to indicate the number of
  // bits that was packed. If a ~null~ object was packed, then this header will
  // be 0.
  //
  // This is useful for mixed-language communication where unpacking may occur
  // outside of SystemVerilog UVM.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.2
  void pack_object (uvm_object value) {
    this.pack(value);
  }
  
  void pack_object_with_meta (uvm_object value) {
    synchronized (this) {
      foreach (i, reference; _m_object_references) {
	if (reference is value) {
	  pack(cast (uint) i);
	  return;
	}
      }
  
      // Size will always be >0 because 0 is the null
      uint reference_id = cast (uint) _m_object_references.length;
      pack(reference_id);
      _m_object_references[reference_id] = value;
      pack_object_wrapper(value.get_object_type());

      pack_object(value); 
    }
  }
  
  
  void pack_object_wrapper (uvm_object_wrapper value) {
    synchronized (this) {
      // string type_name;
      if (value !is null) {
	pack(value.get_type_name());
      }
    }
  }

  //------------------//
  // Group -- NODOCS -- Unpacking //
  //------------------//

  // Function -- NODOCS -- is_null
  //
  // This method is used during unpack operations to peek at the next 4-bit
  // chunk of the pack data and determine if it is 0.
  //
  // If the next four bits are all 0, then the return value is a 1; otherwise
  // it is 0.
  //
  // This is useful when unpacking objects, to decide whether a new object
  // needs to be allocated or not.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.3
  bool is_null () {
    synchronized (this) {
      return (_m_bits.read!int(4) == 0);
    }
  }

  bool is_object_wrapper() {
    synchronized (this) {
      return (_m_bits.read!int(4) == 1);
    }
  }

  void unpack(T)(out T value)
    if (isBitVector!T || isIntegral!T || isFloatingPoint!T ||
       is (T == SimTime) || is (T == Time) || isBoolean!T) {
      synchronized (this) {
	if (enough_bits(T.sizeof*8, "integral")) {
	  _m_bits.unpack(value);
	}
      }
    }

  T unpack(T)()
    if (isBitVector!T || isIntegral!T || isFloatingPoint!T ||
       is (T == SimTime) || is (T == Time) || isBoolean!T) {
      synchronized (this) {
	if (enough_bits(T.sizeof*8, "integral")) {
	  T value;
	  _m_bits.unpack(value);
	  return value;
	}
      }
    }

  void unpack(T)(out T value, ptrdiff_t num_chars = -1)
    if (is (T == string)) {
      synchronized (this) {
	ubyte c;
	bool is_null_term = false;
	if (num_chars == -1) is_null_term = true;
	char[] retval;
	for (size_t i=0; i != num_chars; ++i) {
	  if (enough_bits(8,"string")) {
	    _m_bits.unpack(c);
	    if (is_null_term && c == 0) break;
	    retval ~= cast (char) c;
	  }
	}
	value = cast (string) retval;
      }
    }

  void unpack(T)(T value)
    if (is (T: uvm_object)) {
      import uvm.base.uvm_object_globals;
      import uvm.base.uvm_globals;
      synchronized (this) {
	if (is_null()) {
	  if (value !is null) {
	    uvm_error("UVM/BASE/PACKER/UNPACK/N2NN",
		      "attempt to unpack a null object into a not-null object!");
	    return;
	  }
	  _m_bits.skip(4); // advance past the null
	  return;
	}
	else {
	  if (value is null) {
	    uvm_error("UVM/BASE/PACKER/UNPACK/NN2N",
		      "attempt to unpack a non-null object into a null object!");
	    return;
	  }
	  _m_bits.skip(4); // advance past the !null
	  push_active_object(value);
	  uvm_field_op field_op = uvm_field_op.m_get_available_op();
	  field_op.set(uvm_field_auto_enum.UVM_UNPACK, this, value);
	  value.do_execute_op(field_op);
	  if (field_op.user_hook_enabled()) {
	    value.do_unpack(this);
	  }
	  field_op.m_recycle();
	  pop_active_object();
	}
      }
    }


  // Function -- NODOCS -- unpack_field
  //
  // Unpacks bits from the pack array and returns the bit-stream that was
  // unpacked. ~size~ is the number of bits to unpack; the maximum is 4096 bits.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.16
  uvm_bitstream_t unpack_field (int size) {
    synchronized (this) {
      uvm_bitstream_t retval;
      if (enough_bits(size, "integral")) {
	for (size_t i=0; i != size; ++i) {
	  bool b;
	  _m_bits.unpack(b);
	  retval[size-i-1] = b;
	}
      }
      return retval;
    }
  }


  // Function -- NODOCS -- unpack_field_int
  //
  // Unpacks bits from the pack array and returns the bit-stream that was
  // unpacked.
  //
  // ~size~ is the number of bits to unpack; the maximum is 64 bits.
  // This is a more efficient variant than unpack_field when unpacking into
  // smaller vectors.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.17
  uvm_integral_t unpack_field_int (int size) {
    synchronized (this) {
      uvm_integral_t retval;
      if (enough_bits(size, "integral")) {
	for (size_t i=0; i != size; ++i) {
	  bool b;
	  _m_bits.unpack(b);
	  retval[size-i-1] = b;
	}
      }
      return retval;
    }
  }


  void unpack(T)(ref T value, size_t size = -1) if (isArray!T) {
    import uvm.base.uvm_globals;
    synchronized (this) {
      size_t max_size = value.length * BitCount!T;
      if (size == -1)
	size = max_size;

      if (size > max_size) {
	uvm_error("UVM/BASE/PACKER/BAD_SIZE",
		  format("unpack_bits called with size '%0d'," ~
			 " which exceeds value.size() of '%0d'",
			 size,
			 max_size));
	return;
      }

      if (enough_bits(size, "integral")) {
	_m_bits.unpack(value, size);
      }
    }
  }

  // Function -- NODOCS -- unpack_bits
  //
  // Unpacks bits from the pack array into an unpacked array of bits.
  //
  // extern virtual function void unpack_bits(ref bit value[], input int size = -1);
  // unpack_bits
  // -------------------

  // @uvm-ieee 1800.2-2017 auto 16.5.4.18
  alias unpack_bits = unpack;

  // Function -- NODOCS -- unpack_bytes
  //
  // Unpacks bits from the pack array into an unpacked array of bytes.
  //
  // extern virtual function void unpack_bytes(ref byte value[], input int size = -1);
  // @uvm-ieee 1800.2-2017 auto 16.5.4.19

  alias unpack_bytes = unpack;


  // @uvm-ieee 1800.2-2017 auto 16.5.4.12
  alias unpack_ints = unpack;

  // Function -- NODOCS -- unpack_string
  //
  // Unpacks a string.
  //
  // num_chars bytes are unpacked into a string. If num_chars is -1 then
  // unpacking stops on at the first ~null~ character that is encountered.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.13
  string unpack_string () {
    synchronized (this) {
      char[] unpack_string_;
      char unpack_char;
      while (enough_bits(8, "string") && 
	     (_m_bits.read!int(8) != 0)) {
	// silly, because cannot append byte/char to string
	_m_bits.unpack(unpack_char);
	unpack_string_ ~= unpack_char;
      }
      if (enough_bits(8,"string"))
	_m_bits.skip(8);
      return cast (string) unpack_string_;
    }
  }


  // Function -- NODOCS -- unpack_time
  //
  // Unpacks the next 64 bits of the pack array and places them into a
  // time variable.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.14
  SimTime unpack_time () {
    SimTime t;
    this.unpack(t);
    return t;
  }


  // Function -- NODOCS -- unpack_real
  //
  // Unpacks the next 64 bits of the pack array and places them into a
  // real variable.
  //
  // The 64 bits of packed data are converted to a real using the $bits2real
  // system function.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.15
  double unpack_real () {
    double f;
    this.unpack(f);
    return f;
  }

  // Function -- NODOCS -- unpack_object
  //
  // Unpacks an object and stores the result into ~value~.
  //
  // ~value~ must be an allocated object that has enough space for the data
  // being unpacked. The first four bits of packed data are used to determine
  // if a ~null~ object was packed into the array.
  //
  // The <is_null> function can be used to peek at the next four bits in
  // the pack array before calling this method.

  // @uvm-ieee 1800.2-2017 auto 16.5.4.4
  void unpack_object (uvm_object obj) {
    this.unpack(obj);
  }

  
  void unpack_object_with_meta(ref uvm_object value) {
    synchronized (this) {
      int reference_id; 
      reference_id = cast (int) unpack_field_int(32);
      if (reference_id in _m_object_references) {
	value = _m_object_references[reference_id];
	return;
      }
      else {
	uvm_object_wrapper _wrapper = unpack_object_wrapper();
	if ((_wrapper !is null) && 
	    ((value is null) || (value.get_object_type() !is _wrapper))) { 
	  value = _wrapper.create_object("");
	  if (value is null) {
	    value = _wrapper.create_component("", null);
	  }
	} 
      }
      _m_object_references[reference_id] = value;
      unpack_object(value);
    }
  }

  uvm_object_wrapper unpack_object_wrapper() {
    synchronized (this) {
      string type_name = unpack_string();
      if (_m_factory is null)
	_m_factory = uvm_factory.get();
      if (_m_factory.is_type_name_registered(type_name)) {
	return _m_factory.find_wrapper_by_name(type_name);
      }
      return null;
    }
  }

  // Function -- NODOCS -- get_packed_size
  //
  // Returns the number of bits that were packed.

  // @uvm-ieee 1800.2-2017 auto 16.5.3.3
  size_t get_packed_size() {
    synchronized (this) {
      return _m_bits.packIter - _m_bits.unpackIter;
    }
  }

  //------------------//
  // Group -- NODOCS -- Variables //
  //------------------//

  // variables and methods primarily for internal use

  // static bool bitstream[];   // local bits for (un)pack_bytes
  // static bool fabitstream[]; // field automation bits for (un)pack_bytes

  
  // encapsulated in esdl.data.packer
  // int        _m_pack_iter; // Used to track the bit of the next pack
  // int        _m_unpack_iter; // Used to track the bit of the next unpack

  bool  _reverse_order;      //flip the bit order around
  byte  _byte_size     = 8;  //set up bytesize for endianess
  int   _word_size     = 16; //set up worksize for endianess
  bool  _nopack;             //only count packable bits


  // uvm_pack_bitstream_t _m_bits;
  private Packer _m_bits;			// esdl.data.packer

  final void index_error(size_t index, string id, int sz) {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    synchronized (this) {
      uvm_report_error("PCKIDX",
		       format("index %0d for get_%0s too large; valid index range is 0-%0d.",
			      index, id, ((_m_bits.packIter+sz-1)/sz)-1),
		       uvm_verbosity.UVM_NONE);
    }
  }

  final bool enough_bits(size_t needed, string id) {
    import uvm.base.uvm_object_globals;
    import uvm.base.uvm_globals;
    synchronized (this) {
      if ((_m_bits.packIter - _m_bits.unpackIter) < needed) {
	uvm_report_error("PCKSZ",
			 format("%0d bits needed to unpack %0s, yet only %0d available.",
				needed, id, (_m_bits.packIter - _m_bits.unpackIter)),
			 uvm_verbosity.UVM_NONE);
	return false;
      }
      return true;
    }
  }

  final void packReset() {
    synchronized (this) {
      _m_bits.packReset();
    }
  }

  final void unpackReset() {
    synchronized (this) {
      _m_bits.unpackReset();
    }
  }
  
  void uvm_pack_element(E)(string name, ref E elem,
			   uvm_field_flag_t flags) {
    synchronized (this) {
      m_uvm_pack_element!E(name, elem, flags);
    }
  }
  
  void m_uvm_pack_element(E)(string name, ref E elem,
			     uvm_field_flag_t flags) {
    static if (isArray!E && !is (E == string)) {
      static if (isDynamicArray!E) {
	pack(elem.length, 32);
      }
      foreach (index, ref ee; elem) {
	m_uvm_pack_element(name, ee, flags);
      }
    }
    else static if (is (E: uvm_object)) {
      auto recursion =
	cast (uvm_recursion_policy_enum) (flags & UVM_RECURSION);
      if (recursion == uvm_recursion_policy_enum.UVM_REFERENCE) {
	this.pack_object_with_meta(elem);
      }
    }
    else {
      pack(elem);
    }
  }
  
  void uvm_unpack_element(E)(string name, ref E elem,
			     uvm_field_flag_t flags) {
    synchronized (this) {
      m_uvm_unpack_element!E(name, elem, flags);
    }
  }
  
  void m_uvm_unpack_element(E)(string name, ref E elem,
			       uvm_field_flag_t flags) {
    static if (isArray!E && !is (E == string)) {
      static if (isDynamicArray!E) {
	uint size;
	unpack(size);
	elem.length = size;
      }
      foreach (index, ref ee; elem) {
	m_uvm_unpack_element(name, ee, flags);
      }
    }
    else static if (is (E: uvm_object)) {
      auto recursion =
	cast (uvm_recursion_policy_enum) (flags & UVM_RECURSION);
      if (recursion == uvm_recursion_policy_enum.UVM_REFERENCE) {
	uvm_object obj = elem;
	this.unpack_object_with_meta(obj);
	if (obj !is elem) {
	  elem = cast (E) obj;
	  if (elem is null) {
	    uvm_fatal("UVM/UNPACK_EXT/OBJ_CAST_FAILED",
		      "Could not cast object of type '" ~
		      obj.get_type_name() ~ "' into '" ~ name);
	  }
	}
      }
    }
    else {
      unpack(elem);
    }
  }
}
