//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010      Synopsys, Inc.
//   Copyright 2013      NVIDIA Corporation
//   Copyright 2012-2016 Coverify Systems Technology
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
// CLASS: uvm_packer
//
// The uvm_packer class provides a policy object for packing and unpacking
// uvm_objects. The policies determine how packing and unpacking should be done.
// Packing an object causes the object to be placed into a bit (byte or int)
// array. If the `uvm_field_* macro are used to implement pack and unpack,
// by default no metadata information is stored for the packing of dynamic
// objects (strings, arrays, class objects).
//
//-------------------------------------------------------------------------------

import uvm.base.uvm_misc;
import uvm.base.uvm_object;
import uvm.base.uvm_printer;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_globals;
import uvm.meta.misc;

import esdl.data.packer;
import esdl.data.bstr;
import esdl.data.bvec;
import esdl.base.core: SimTime;
import esdl.data.time;
import std.string: format;
import std.traits;

class uvm_packer
{
  this() {
    synchronized(this) {
      _scope_stack = new uvm_scope_stack();
    }
  }

  // alias BitVec!(UVM_PACKER_MAX_BYTES*8) uvm_pack_bitstream_t;

  //----------------//
  // Group: Packing //
  //----------------//

  void pack(T)(T value)
    if(isBitVector!T || isIntegral!T || isFloatingPoint!T ||
       is(T == SimTime) || is(T == Time) || is(T == bool)) {
      synchronized(this) {
	_m_bits.pack(value, _big_endian);
      }
    }

  void pack(T)(T value)
    if(is(T == string)) {
      synchronized(this) {
	foreach (c; value) {
	  auto b = cast(ubyte) c;
	  _m_bits.pack(b, _big_endian);
	}
	if(_use_metadata is true) {
	  _m_bits.pack(cast(byte) 0);
	}
      }
    }

  void pack(T)(T value)
    if(is(T: uvm_object)) {
      synchronized(this) {
	if(value.m_uvm_status_container.check_cycle(value)) {
	  uvm_report_warning("CYCFND",
			     format("Cycle detected for object @%0d"
				    " during pack", value.get_inst_id()),
			     UVM_NONE);
	  return;
	}
	value.m_uvm_status_container.add_cycle_check(value);

	if((policy != UVM_REFERENCE) && (value !is null) ) {
	  if(use_metadata is true) {
	    _m_bits.pack(cast(UBitVec!4) 1);
	  }
	  scope_stack.down(value.get_name());
	  value.m_uvm_object_automation(null, UVM_PACK, "");
	  value.do_pack(this);
	  scope_stack.up();
	}
	else if(use_metadata is true) {
	  synchronized(this) {
	    _m_bits.pack(cast(UBitVec!4) 0);
	  }
	}
	value.m_uvm_status_container.remove_cycle_check(value);
      }
    }



  // Function: pack_field
  //
  // Packs an integral value (less than or equal to 4096 bits) into the
  // packed array. ~size~ is the number of bits of ~value~ to pack.

  void pack_field (uvm_bitstream_t value, size_t size) {
    synchronized(this) {
      for (size_t i = 0; i != size; ++i) {
	if(_big_endian is true) {
	  _m_bits.pack(value[size-1-i]);
	}
	else {
	  _m_bits.pack(value[i]);
	}
      }
    }
  }


  // Function: pack_field_int
  //
  // Packs the integral value (less than or equal to 64 bits) into the
  // pack array.  The ~size~ is the number of bits to pack, usually obtained by
  // ~$bits~. This optimized version of <pack_field> is useful for sizes up
  // to 64 bits.

  void pack_field_int (uvm_integral_t value, size_t size) {
    synchronized(this) {
      for (size_t i = 0; i != size; ++i) {
	if(_big_endian is true) {
	  _m_bits.pack(value[size-1-i]);
	}
	else {
	  _m_bits.pack(value[i]);
	}
      }
    }
  }


  // Function: pack_bits
  //
  // Packs bits from upacked array of bits into the pack array.
  //
  // See <pack_ints> for additional information.
  // extern virtual function void pack_bits(ref bit value[], input int size = -1);


  // pack_bits
  // -----------------

  void pack_bits(bool[] value, int size = -1) {
    synchronized(this) {
      if (size < 0) {
	size = cast(int) value.length;
      }

      if (size > value.length) {
	uvm_error("UVM/BASE/PACKER/BAD_SIZE",
		  format("pack_bits called with size '%0d', which" ~
			 " exceeds value.size() of '%0d'",
			 size,
			 value.length));
	return;
      }

      for(int i=0; i < size; i++) {
	if (_big_endian is true) {
	  _m_bits.pack(value[size-1-i]);
	}
	else {
	  _m_bits.pack(value[i]);
	}
      }
    }
  }

  // Function: pack_bytes
  //
  // Packs bits from an upacked array of bytes into the pack array.
  //
  // See <pack_ints> for additional information.
  // extern virtual function void pack_bytes(ref byte value[], input int size = -1);

  // pack_bytes
  // -----------------

  void pack_integrals(T)(T[] value, in int size = -1)
    if(isIntegral!T) {
      synchronized(this) {
	int max_size = value.length * T.sizeof * 8;

	if (size < 0) {
	  size = max_size;
	}

	if (size > max_size) {
	  uvm_error("UVM/BASE/PACKER/BAD_SIZE",
		    format("pack_%ss called with size '%0d', which" ~
			   " exceeds value size of '%0d'",
			   T.stringof,
			   size,
			   max_size));
	  return;
	}
	else {
	  size_t maxi = size/(T.sizeof * 8);
	  size_t rem_bits = size % (T.sizeof * 8);
	  if(big_endian is true) {
	    _m_bits.pack(value[maxi], big_endian, rem_bits);
	  }
	  for (int i=0; i < maxi; i++) {
	    if (big_endian is true) {
	      _m_bits.pack(value[maxi-i-1], big_endian);
	    }
	    else {
	      _m_bits.pack(value[i], big_endian);
	    }
	  }
	  if(big_endian is false) {
	    _m_bits.pack(value[maxi], big_endian, rem_bits);
	  }
	}
      }
    }

  alias pack_bytes = pack_integrals;

  // Function: pack_ints
  //
  // Packs bits from an unpacked array of ints into the pack array.
  //
  // The bits are appended to the internal pack array.
  // This method allows for fields of arbitrary length to be
  // passed in, using the SystemVerilog ~stream~ operator.
  //
  // For example
  // | bit[511:0] my_field;
  // | begin
  // |   int my_stream[];
  // |   { << int {my_stream}} = my_field;
  // |   packer.pack_ints(my_stream);
  // | end
  //
  // When appending the stream to the internal pack array, the packer will obey
  // the value of <big_endian> (appending the array from MSB to LSB if set).
  //
  // An optional ~size~ parameter is provided, which defaults to '-1'.  If set
  // to any value greater than '-1' (including 0), then the packer will use
  // the size as the number of bits to pack, otherwise the packer will simply
  // pack the entire stream.
  //
  // An error will be asserted if the ~size~ has been specified, and exceeds the
  // size of the source array.
  //
  // extern virtual function void pack_ints(ref int value[], input int size = -1);

  alias pack_ints = pack_integrals;

  // Function: pack_string
  //
  // Packs a string value into the pack array.
  //
  // When the metadata flag is set, the packed string is terminated by a ~null~
  // character to mark the end of the string.
  //
  // This is useful for mixed language communication where unpacking may occur
  // outside of SystemVerilog UVM.

  void pack_string (string value) {
    this.pack(value);
  }


  // Function: pack_time
  //
  // Packs a time ~value~ as 64 bits into the pack array.

  void pack_time (SimTime value) {
    this.pack(value);
  }


  // Function: pack_real
  //
  // Packs a real ~value~ as 64 bits into the pack array.
  //
  // The real ~value~ is converted to a 6-bit scalar value using the function
  // $real2bits before it is packed into the array.

  void pack_real (real value) {
    this.pack(value);
  }


  // Function: pack_object
  //
  // Packs an object value into the pack array.
  //
  // A 4-bit header is inserted ahead of the string to indicate the number of
  // bits that was packed. If a ~null~ object was packed, then this header will
  // be 0.
  //
  // This is useful for mixed-language communication where unpacking may occur
  // outside of SystemVerilog UVM.

  void pack_object (uvm_object value) {
    this.pack(value);
  }


  //------------------//
  // Group: Unpacking //
  //------------------//

  // Function: is_null
  //
  // This method is used during unpack operations to peek at the next 4-bit
  // chunk of the pack data and determine if it is 0.
  //
  // If the next four bits are all 0, then the return value is a 1; otherwise
  // it is 0.
  //
  // This is useful when unpacking objects, to decide whether a new object
  // needs to be allocated or not.

  bool is_null () {
    synchronized(this) {
      UBitVec!4 val;
      // do not use unpack since we do not want to increment unpackIndex here
      _m_bits.getFront(val, _m_bits.unpackIndex);
      return (val == 0);
    }
  }


  void unpack(T)(out T value)
    if(isBitVector!T || isIntegral!T || isFloatingPoint!T ||
       is(T == SimTime) || is(T == Time) || is(T == bool)) {
      synchronized(this) {
	if (enough_bits(T.sizeof*8,"integral")) {
	  _m_bits.unpack(value, _big_endian);
	}
      }
    }

  void unpack(T)(out T value, ptrdiff_t num_chars = -1)
    if(is(T == string)) {
      synchronized(this) {
	ubyte c;
	bool is_null_term = false;
	if(num_chars == -1) is_null_term = true;
	char[] retval;
	for (size_t i=0; i != num_chars; ++i) {
	  if(enough_bits(8,"string")) {
	    _m_bits.unpack(c, _big_endian);
	    if(is_null_term && c == 0) break;
	    retval ~= cast(char) c;
	  }
	}
	value = cast(string) retval;
      }
    }

  void unpack(T)(T value) if(is(T: uvm_object)) {
    synchronized(this) {
      byte is_non_null = 1;
      if(value.m_uvm_status_container.check_cycle(value)) {
	uvm_report_warning("CYCFND",
			   format("Cycle detected for object @%0d"
				  " during unpack", value.get_inst_id()),
			   UVM_NONE);
	return;
      }
      value.m_uvm_status_container.add_cycle_check(value);

      if(_use_metadata is true) {
	UBitVec!4 v;
	_m_bits.unpack(v);
	is_non_null = v;
      }

      // NOTE- policy is a ~pack~ policy, not unpack policy;
      //       and you can't pack an object by REFERENCE
      if (value !is null) {
	if (is_non_null > 0) {
	  _scope_stack.down(value.get_name());
	  value.m_uvm_object_automation(null, UVM_UNPACK,"");
	  value.do_unpack(this);
	  _scope_stack.up();
	}
	else {
	  // TODO: help do_unpack know whether unpacked result would be null
	  //       to avoid new'ing unnecessarily;
	  //       this does not nullify argument; need to pass obj by ref
	}
      }
      else if ((is_non_null != 0) && (value is null)) {
	uvm_report_error("UNPOBJ",
			 "cannot unpack into null object", UVM_NONE);
      }
      value.m_uvm_status_container.remove_cycle_check(value);
    }
  }


  // Function: unpack_field
  //
  // Unpacks bits from the pack array and returns the bit-stream that was
  // unpacked. ~size~ is the number of bits to unpack; the maximum is 4096 bits.

  uvm_bitstream_t unpack_field (int size);

  // Function: unpack_field_int
  //
  // Unpacks bits from the pack array and returns the bit-stream that was
  // unpacked.
  //
  // ~size~ is the number of bits to unpack; the maximum is 64 bits.
  // This is a more efficient variant than unpack_field when unpacking into
  // smaller vectors.

  uvm_integral_t unpack_field_int (int size) {
    synchronized(this) {
      LogicVec!64 retval = 0;
      if (enough_bits(size,"integral")) {
	for (size_t i=0; i != size; ++i) {
	  bool b;
	  _m_bits.unpack(b);
	  if(_big_endian is true) {
	    retval[i] = b;
	  }
	  else {
	    retval[size-i-1] = b;
	  }
	}
      }
      return retval;
    }
  }


  // Function: unpack_field
  //
  // Unpacks bits from the pack array and returns the bit-stream that was
  // unpacked. ~size~ is the number of bits to unpack; the maximum is 4096 bits.

  uvm_bitstream_t unpack_field (int size) {
    synchronized(this) {
      uvm_bitstream_t retval;
      if (enough_bits(size,"integral")) {
	for (size_t i=0; i != size; ++i) {
	  bool b;
	  _m_bits.unpack(b);
	  if(_big_endian is true) {
	    retval[i] = b;
	  }
	  else {
	    retval[size-i-1] = b;
	  }
	}
      }
      return retval;
    }
  }


  // Function: unpack_bits
  //
  // Unpacks bits from the pack array into an unpacked array of bits.
  //
  // extern virtual function void unpack_bits(ref bit value[], input int size = -1);
  // unpack_bits
  // -------------------

  void unpack_bits(bool[] value, int size = -1) {
    synchronized(this) {
      if (size < 0) {
	size = cast(int) value.length;
      }

      if(size > value.length) {
	uvm_error("UVM/BASE/PACKER/BAD_SIZE",
		  format("unpack_bits called with size '%0d', which exceeds value.size() of '%0d'",
			 size,
			 value.length));
	return;
      }

      if(enough_bits(size, "integral")) {
	for(int i=0; i<size; i++) {
	  if (big_endian is true) {
	    _m_bits.unpack(value[size-i-1]);
	  }
	  else {
	    _m_bits.unpack(value[i]);
	  }
	}
      }
    }
  }


  // Function: unpack_bytes
  //
  // Unpacks bits from the pack array into an unpacked array of bytes.
  //
  // extern virtual function void unpack_bytes(ref byte value[], input int size = -1);

  // unpack_bytes
  // -------------------

  void unpack_integrals(T)(T[] value, int size = -1) {
    synchronized(this) {
      int max_size = cast(int) (value.length * T.sizeof * 8);

      if (size < 0) {
	size = max_size;
      }


      if (size > max_size) {
	uvm_error("UVM/BASE/PACKER/BAD_SIZE",
		  format("unpack_%ss called with size '%0d'," ~
			 " which exceeds value size of '%0d'",
			 T.stringof,
			 size,
			 max_size));
	return;
      }
      else {
	if (enough_bits(size, "integral")) {
	  size_t maxi = size/(T.sizeof * 8);
	  size_t rem_bits = size % (T.sizeof * 8);
	  if(big_endian is true) {
	    _m_bits.unpack(value[maxi], big_endian, rem_bits);
	  }
	  for (int i=0; i < maxi; i++) {
	    if (big_endian is true) {
	      _m_bits.unpack(value[maxi-i-1], big_endian);
	    }
	    else {
	      _m_bits.unpack(value[i], big_endian);
	    }
	  }
	  if(big_endian is false) {
	    _m_bits.unpack(value[maxi], big_endian, rem_bits);
	  }
	}
      }
    }
  }

  alias unpack_bytes = unpack_integrals!byte;

  // Function: unpack_ints
  //
  // Unpacks bits from the pack array into an unpacked array of ints.
  //
  // The unpacked array is unpacked from the internal pack array.
  // This method allows for fields of arbitrary length to be
  // passed in without expanding into a pre-defined integral type first.
  //
  // For example
  // | bit[511:0] my_field;
  // | begin
  // |   int my_stream[] = new[16]; // 512/32 = 16
  // |   packer.unpack_ints(my_stream);
  // |   my_field = {<<{my_stream}};
  // | end
  //
  // When unpacking the stream from the internal pack array, the packer will obey
  // the value of <big_endian> (unpacking the array from MSB to LSB if set).
  //
  // An optional ~size~ parameter is provided, which defaults to '-1'.  If set
  // to any value greater than '-1' (including 0), then the packer will use
  // the size as the number of bits to unpack, otherwise the packer will simply
  // unpack the entire stream.
  //
  // An error will be asserted if the ~size~ has been specified, and
  // exceeds the size of the target array.
  //
  // extern virtual function void unpack_ints(ref int value[], input int size = -1);

  alias unpack_bytes = unpack_integrals!int;
  // Function: unpack_string
  //
  // Unpacks a string.
  //
  // num_chars bytes are unpacked into a string. If num_chars is -1 then
  // unpacking stops on at the first ~null~ character that is encountered.

  string unpack_string (ptrdiff_t num_chars = -1) {
    string str;
    unpack(str, num_chars);
    return str;
  }


  // Function: unpack_time
  //
  // Unpacks the next 64 bits of the pack array and places them into a
  // time variable.

  SimTime unpack_time () {
    SimTime t;
    this.unpack(t);
    return t;
  }


  // Function: unpack_real
  //
  // Unpacks the next 64 bits of the pack array and places them into a
  // real variable.
  //
  // The 64 bits of packed data are converted to a real using the $bits2real
  // system function.

  double unpack_real () {
    double f;
    this.unpack(f);
    return f;
  }

  // Function: unpack_object
  //
  // Unpacks an object and stores the result into ~value~.
  //
  // ~value~ must be an allocated object that has enough space for the data
  // being unpacked. The first four bits of packed data are used to determine
  // if a ~null~ object was packed into the array.
  //
  // The <is_null> function can be used to peek at the next four bits in
  // the pack array before calling this method.

  void unpack_object (uvm_object obj) {
    this.unpack(obj);
  }


  // Function: get_packed_size
  //
  // Returns the number of bits that were packed.

  size_t get_packed_size() {
    synchronized(this) {
      return _m_bits.length;
    }
  }

  mixin(uvm_sync_string);

  //------------------//
  // Group: Variables //
  //------------------//

  // Variable: physical
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The <is_abstract> and physical settings allow an object to distinguish between
  // two different classes of fields. It is up to you, in the
  // <uvm_object::do_pack> and <uvm_object::do_unpack> methods, to test the
  // setting of this field if you want to use it as a filter.

  // FIXME -- physical seems redundant, though present in the SV version
  // private bool _physical = true;


  // Variable: is_abstract
  //
  // This bit provides a filtering mechanism for fields.
  //
  // The is_abstract and physical settings allow an object to distinguish between
  // two different classes of fields. It is up to you, in the
  // <uvm_object::do_pack> and <uvm_object::do_unpack> routines, to test the
  // setting of this field if you want to use it as a filter.

  // FIXME -- is_abstract seems redundant, though present in the SV version
  // bool _is_abstract;


  // Variable: use_metadata
  //
  // This flag indicates whether to encode metadata when packing dynamic data,
  // or to decode metadata when unpacking.  Implementations of <uvm_object::do_pack>
  // and <uvm_object::do_unpack> should regard this bit when performing their
  // respective operation. When set, metadata should be encoded as follows:
  //
  // - For strings, pack an additional ~null~ byte after the string is packed.
  //
  // - For objects, pack 4 bits prior to packing the object itself. Use 4'b0000
  //   to indicate the object being packed is ~null~, otherwise pack 4'b0001 (the
  //   remaining 3 bits are reserved).
  //
  // - For queues, dynamic arrays, and associative arrays, pack 32 bits
  //   indicating the size of the array prior to packing individual elements.

  @uvm_public_sync private bool _use_metadata = false;


  // Variable: big_endian
  //
  // This bit determines the order that integral data is packed (using
  // <pack_field>, <pack_field_int>, <pack_time>, or <pack_real>) and how the
  // data is unpacked from the pack array (using <unpack_field>,
  // <unpack_field_int>, <unpack_time>, or <unpack_real>). When the bit is set,
  // data is associated msb to lsb; otherwise, it is associated lsb to msb.
  //
  // The following code illustrates how data can be associated msb to lsb and
  // lsb to msb:
  //
  //|  class mydata extends uvm_object;
  //|
  //|    logic[15:0] value = 'h1234;
  //|
  //|    function void do_pack (uvm_packer packer);
  //|      packer.pack_field_int(value, 16);
  //|    endfunction
  //|
  //|    function void do_unpack (uvm_packer packer);
  //|      value = packer.unpack_field_int(16);
  //|    endfunction
  //|  endclass
  //|
  //|  mydata d = new;
  //|  bit bits[];
  //|
  //|  initial begin
  //|    d.pack(bits);  // 'b0001001000110100
  //|    uvm_default_packer.big_endian = 0;
  //|    d.pack(bits);  // 'b0010110001001000
  //|  end

  @uvm_public_sync private bool _big_endian = true;


  // variables and methods primarily for internal use

  // static bool bitstream[];   // local bits for (un)pack_bytes
  // static bool fabitstream[]; // field automation bits for (un)pack_bytes

  // not required with bstr
  // int count;                // used to count the number of packed bits
  @uvm_immutable_sync private  uvm_scope_stack _scope_stack; // = new;

  // bool  reverse_order;      //flip the bit order around
  // byte  byte_size     = 8;  //set up bytesize for endianess
  // int   word_size     = 16; //set up worksize for endianess
  // bool  nopack;             //only count packable bits

  @uvm_public_sync private uvm_recursion_policy_enum _policy =
    uvm_recursion_policy_enum.UVM_DEFAULT_POLICY;

  // uvm_pack_bitstream_t _m_bits;
  private packer _m_bits;			// esdl.data.packer
  // size_t m_packed_size;

  void unpack_object_ext  (uvm_object value) {
    unpack_object(value);
  }

  bstr get_packed_bits () {
    synchronized(this) {
      return _m_bits;
    }
  }

  Bit!1 get_bit (uint index) {
    synchronized(this) {
      if (index >= _m_bits.length) {
	index_error(index, "Bit!1", 1);
      }
      bool val;
      _m_bits.getFront(val, index);
      return cast(Bit!1) val;
    }
  }

  ubyte get_byte (uint index) {
    synchronized(this) {
      if (index >= ((_m_bits.length)+7)/8) {
	index_error(index, "byte",8);
      }
      ubyte retval;
      _m_bits.getFront(retval, index*8);
      return retval;
    }
  }

  uint get_int (uint index) {
    synchronized(this) {
      if (index >= (_m_bits.length+31)/32) {
	index_error(index, "int",32);
      }
      uint retval;
      _m_bits.getFront(retval, index*32);
      return retval;
    }
  }

  void get_bits (ref Bit!1[] bits) {
    synchronized(this) {
      _m_bits.toArray(bits);
    }
  }

  Bit!1[] get_bits () {
    synchronized(this) {
      Bit!1[] bits;
      _m_bits.toArray(bits);
      return bits;
    }
  }

  void get_bits (ref bool[] bits) {
    synchronized(this) {
      _m_bits.toArray(bits);
    }
  }

  bool[] get_bits () {
    synchronized(this) {
      bool[] bits;
      _m_bits.toArray(bits);
      return bits;
    }
  }

  void get_bytes (ref ubyte[] bytes) {
    synchronized(this) {
      _m_bits.toArray(bytes);
    }
  }

  ubyte[] get_bytes() {
    synchronized(this) {
      ubyte[] bytes;
      _m_bits.toArray(bytes);
      return bytes;
    }
  }

  void get_ints (ref uint[] ints) {
    synchronized(this) {
      _m_bits.toArray(ints);
    }
  }

  uint[] get_ints () {
    synchronized(this) {
      uint[] ints;
      _m_bits.toArray(ints);
      return ints;
    }
  }

  void put_bits (bool[] bits) {
    synchronized(this) {
      _m_bits.fromArray(bits);
      _m_bits.unpackReset();
    }
  }

  void put_bits (Bit!1[] bits) {
    synchronized(this) {
      _m_bits.fromArray(bits);
      _m_bits.unpackReset();
    }
  }

  void put_bytes(ubyte[] bytes) {
    synchronized(this) {
      _m_bits.fromArray(bytes);
      _m_bits.unpackReset();
    }
  }

  void put_ints (uint[] ints) {
    synchronized(this) {
      _m_bits.fromArray(ints);
      _m_bits.unpackReset();
    }
  }

  // This function does not do anything in the vlang version of UVM
  // The functionality is taken care if inside the esdl.data.packer
  void set_packed_size() {
    // void
  }

  final void index_error(int index, string id, int sz) {
    uvm_report_error("PCKIDX",
		     format("index %0d for get_%0s too large; valid index range is 0-%0d.",
			    index,id,((_m_bits.length+sz-1)/sz)-1), UVM_NONE);
  }

  final bool enough_bits(size_t needed, string id) {
    synchronized(this) {
      if ((_m_bits.length - _m_bits.unpackIndex) < needed) {
	uvm_report_error("PCKSZ",
			 format("%0d bits needed to unpack %0s, yet only %0d available.",
				needed, id, (_m_bits.length - _m_bits.unpackIndex)), UVM_NONE);
	return false;
      }
      return true;
    }
  }

  final void reset() {
    synchronized(this) {
      this.packReset();
      this.unpackReset();
    }
  }

  final void packReset() {
    synchronized(this) {
      _m_bits.packReset();
    }
  }

  final void unpackReset() {
    synchronized(this) {
      _m_bits.unpackReset();
    }
  }
}
