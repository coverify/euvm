//
//------------------------------------------------------------------------------
//   Copyright 2007-2011 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2012-2014 Coverify Systems Technology
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
  public this() {
    synchronized(this) {
      _scope_stack = new uvm_scope_stack();
    }
  }

  // alias BitVec!(UVM_PACKER_MAX_BYTES*8) uvm_pack_bitstream_t;

  //----------------//
  // Group: Packing //
  //----------------//

  public void pack(T)(T value)
    if(isBitVector!T || isIntegral!T || isFloatingPoint!T ||
       is(T == SimTime) || is(T == Time) || is(T == bool)) {
      synchronized(this) {
	_m_bits.pack(value, _big_endian);
      }
    }

  public void pack(T)(T value)
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

  public void pack(T)(T value) if(is(T: uvm_object)) {
    synchronized(this) {
      if(value.m_uvm_status_container.check_cycle(value)) {
	uvm_report_warning("CYCFND",
			   format("Cycle detected for object @%0d"
				  " during pack", value.get_inst_id()),
			   UVM_NONE);
	return;
      }
      value.m_uvm_status_container.add_cycle(value);

      if((policy !is UVM_REFERENCE) && (value !is null) ) {
	if(use_metadata is true) {
	  _m_bits.pack(cast(UBitVec!4) 1);
	}
	scope_stack.down(value.get_name());
	value.m_uvm_field_automation(null, UVM_PACK, "");
	value.do_pack(this);
	scope_stack.up();
      }
      else if(use_metadata is true) {
	synchronized(this) {
	  _m_bits.pack(cast(UBitVec!4) 0);
	}
      }
      value.m_uvm_status_container.remove_cycle(value);
    }
  }



  // Function: pack_field
  //
  // Packs an integral value (less than or equal to 4096 bits) into the
  // packed array. ~size~ is the number of bits of ~value~ to pack.

  public void pack_field (uvm_bitstream_t value, size_t size) {
    synchronized(this) {
      for (size_t i = 0; i !is size; ++i) {
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

  public void pack_field_int (LogicVec!64 value, size_t size) {
    synchronized(this) {
      for (size_t i = 0; i !is size; ++i) {
	if(_big_endian is true) {
	  _m_bits.pack(value[size-1-i]);
	}
	else {
	  _m_bits.pack(value[i]);
	}
      }
    }
  }


  // Function: pack_string
  //
  // Packs a string value into the pack array.
  //
  // When the metadata flag is set, the packed string is terminated by a null
  // character to mark the end of the string.
  //
  // This is useful for mixed language communication where unpacking may occur
  // outside of SystemVerilog UVM.

  public void pack_string (string value) {
    this.pack(value);
  }


  // Function: pack_time
  //
  // Packs a time ~value~ as 64 bits into the pack array.

  public void pack_time (SimTime value) {
    this.pack(value);
  }


  // Function: pack_real
  //
  // Packs a real ~value~ as 64 bits into the pack array.
  //
  // The real ~value~ is converted to a 6-bit scalar value using the function
  // $real2bits before it is packed into the array.

  public void pack_real (real value) {
    this.pack(value);
  }


  // Function: pack_object
  //
  // Packs an object value into the pack array.
  //
  // A 4-bit header is inserted ahead of the string to indicate the number of
  // bits that was packed. If a null object was packed, then this header will
  // be 0.
  //
  // This is useful for mixed-language communication where unpacking may occur
  // outside of SystemVerilog UVM.

  public void pack_object (uvm_object value) {
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

  public bool is_null () {
    synchronized(this) {
      UBitVec!4 val;
      // do not use unpack since we do not want to increment unpackIndex here
      _m_bits.getFront(val, _m_bits.unpackIndex);
      return (val == 0);
    }
  }


  public void unpack(T)(out T value)
    if(isBitVector!T || isIntegral!T || isFloatingPoint!T ||
       is(T == SimTime) || is(T == Time) || is(T == bool)) {
      synchronized(this) {
	if (enough_bits(T.sizeof*8,"integral")) {
	  _m_bits.unpack(value, _big_endian);
	}
      }
    }

  public void unpack(T)(out T value, ptrdiff_t num_chars = -1)
    if(is(T == string)) {
      synchronized(this) {
	ubyte c;
	bool is_null_term = false;
	if(num_chars == -1) is_null_term = true;
	char[] retval;
	for (size_t i=0; i != num_chars; ++i) {
	  if(enough_bits(8,"string")) {
	    _m_bits.unpack(c, _big_endian);
	    if(is_null_term && c is 0) break;
	    retval ~= cast(char) c;
	  }
	}
	value = cast(string) retval;
      }
    }

  public void unpack(T)(T value) if(is(T: uvm_object)) {
    synchronized(this) {
      byte is_non_null = 1;
      if(value.m_uvm_status_container.check_cycle(value)) {
	uvm_report_warning("CYCFND",
			   format("Cycle detected for object @%0d"
				  " during unpack", value.get_inst_id()),
			   UVM_NONE);
	return;
      }
      value.m_uvm_status_container.add_cycle(value);

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
	  value.m_uvm_field_automation(null, UVM_UNPACK,"");
	  value.do_unpack(this);
	  _scope_stack.up();
	}
	else {
	  // TODO: help do_unpack know whether unpacked result would be null
	  //       to avoid new'ing unnecessarily;
	  //       this does not nullify argument; need to pass obj by ref
	}
      }
      else if ((is_non_null !is 0) && (value is null)) {
	uvm_report_error("UNPOBJ",
			 "can not unpack into null object", UVM_NONE);
      }
      value.m_uvm_status_container.remove_cycle(value);
    }
  }


  // Function: unpack_field_int
  //
  // Unpacks bits from the pack array and returns the bit-stream that was
  // unpacked.
  //
  // ~size~ is the number of bits to unpack; the maximum is 64 bits.
  // This is a more efficient variant than unpack_field when unpacking into
  // smaller vectors.

  public LogicVec!64 unpack_field_int (int size) {
    synchronized(this) {
      LogicVec!64 retval = 0;
      if (enough_bits(size,"integral")) {
	for (size_t i=0; i !is size; ++i) {
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

  public uvm_bitstream_t unpack_field (int size) {
    synchronized(this) {
      uvm_bitstream_t retval;
      if (enough_bits(size,"integral")) {
	for (size_t i=0; i !is size; ++i) {
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


  // Function: unpack_string
  //
  // Unpacks a string.
  //
  // num_chars bytes are unpacked into a string. If num_chars is -1 then
  // unpacking stops on at the first null character that is encountered.

  public string unpack_string (ptrdiff_t num_chars = -1) {
    string str;
    unpack(str, num_chars);
    return str;
  }


  // Function: unpack_time
  //
  // Unpacks the next 64 bits of the pack array and places them into a
  // time variable.

  public SimTime unpack_time () {
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

  public double unpack_real () {
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
  // if a null object was packed into the array.
  //
  // The <is_null> function can be used to peek at the next four bits in
  // the pack array before calling this method.

  public void unpack_object (uvm_object obj) {
    this.unpack(obj);
  }


  // Function: get_packed_size
  //
  // Returns the number of bits that were packed.

  public size_t get_packed_size() {
    synchronized(this) {
      return _m_bits.length;
    }
  }

  mixin uvm_sync;

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
  // - For strings, pack an additional null byte after the string is packed.
  //
  // - For objects, pack 4 bits prior to packing the object itself. Use 4'b0000
  //   to indicate the object being packed is null, otherwise pack 4'b0001 (the
  //   remaining 3 bits are reserved).
  //
  // - For queues, dynamic arrays, and associative arrays, pack 32 bits
  //   indicating the size of the array prior to to packing individual elements.

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

  @uvm_public_sync private uvm_recursion_policy_enum _policy = UVM_DEFAULT_POLICY;

  // uvm_pack_bitstream_t _m_bits;
  private packer _m_bits;			// esdl.data.packer
  // size_t m_packed_size;

  public void unpack_object_ext  (uvm_object value) {
    unpack_object(value);
  }

  public bstr get_packed_bits () {
    synchronized(this) {
      return _m_bits;
    }
  }

  public Bit!1 get_bit (uint index) {
    synchronized(this) {
      if (index >= _m_bits.length) {
	index_error(index, "Bit!1", 1);
      }
      bool val;
      _m_bits.getFront(val, index);
      return cast(Bit!1) val;
    }
  }

  public ubyte get_byte (uint index) {
    synchronized(this) {
      if (index >= ((_m_bits.length)+7)/8) {
	index_error(index, "byte",8);
      }
      ubyte retval;
      _m_bits.getFront(retval, index*8);
      return retval;
    }
  }

  public uint get_int (uint index) {
    synchronized(this) {
      if (index >= (_m_bits.length+31)/32) {
	index_error(index, "int",32);
      }
      uint retval;
      _m_bits.getFront(retval, index*32);
      return retval;
    }
  }

  public void get_bits (ref Bit!1[] bits) {
    synchronized(this) {
      _m_bits.toArray(bits);
    }
  }

  public Bit!1[] get_bits () {
    synchronized(this) {
      Bit!1[] bits;
      _m_bits.toArray(bits);
      return bits;
    }
  }

  public void get_bits (ref bool[] bits) {
    synchronized(this) {
      _m_bits.toArray(bits);
    }
  }

  public bool[] get_bits () {
    synchronized(this) {
      bool[] bits;
      _m_bits.toArray(bits);
      return bits;
    }
  }

  public void get_bytes (ref ubyte[] bytes) {
    synchronized(this) {
      _m_bits.toArray(bytes);
    }
  }

  public ubyte[] get_bytes() {
    synchronized(this) {
      ubyte[] bytes;
      _m_bits.toArray(bytes);
      return bytes;
    }
  }

  public void get_ints (ref uint[] ints) {
    synchronized(this) {
      _m_bits.toArray(ints);
    }
  }

  public uint[] get_ints () {
    synchronized(this) {
      uint[] ints;
      _m_bits.toArray(ints);
      return ints;
    }
  }

  public void put_bits (bool[] bits) {
    synchronized(this) {
      _m_bits.fromArray(bits);
      _m_bits.unpackReset();
    }
  }

  public void put_bits (Bit!1[] bits) {
    synchronized(this) {
      _m_bits.fromArray(bits);
      _m_bits.unpackReset();
    }
  }

  public void put_bytes(ubyte[] bytes) {
    synchronized(this) {
      _m_bits.fromArray(bytes);
      _m_bits.unpackReset();
    }
  }

  public void put_ints (uint[] ints) {
    synchronized(this) {
      _m_bits.fromArray(ints);
      _m_bits.unpackReset();
    }
  }

  // This function does not do anything in the vlang version of UVM
  // The functionality is taken care if inside the esdl.data.packer
  public void set_packed_size() {
    // void
  }

  final public void index_error(int index, string id, int sz) {
    uvm_report_error("PCKIDX",
		     format("index %0d for get_%0s too large; valid index range is 0-%0d.",
			    index,id,((_m_bits.length+sz-1)/sz)-1), UVM_NONE);
  }

  final public bool enough_bits(size_t needed, string id) {
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

  final public void reset() {
    synchronized(this) {
      this.packReset();
      this.unpackReset();
    }
  }

  final public void packReset() {
    synchronized(this) {
      _m_bits.packReset();
    }
  }

  final public void unpackReset() {
    synchronized(this) {
      _m_bits.unpackReset();
    }
  }
}
