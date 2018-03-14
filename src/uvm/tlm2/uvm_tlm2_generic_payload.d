//----------------------------------------------------------------------
//   Copyright 2010      Mentor Graphics Corporation
//   Copyright 2010-2011 Synopsys, Inc.
//   Copyright 2016      Coverify Systems Technology
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

module uvm.tlm2.uvm_tlm2_generic_payload;

import uvm.meta.meta;
import uvm.meta.misc;
import uvm.seq.uvm_sequence_item;

import uvm.base.uvm_object;
import uvm.base.uvm_object_defines;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_printer;
import uvm.base.uvm_comparer;
import uvm.base.uvm_packer;
import uvm.base.uvm_recorder;

import esdl.rand;
import std.string: format;
//----------------------------------------------------------------------
// Title: TLM Generic Payload & Extensions
//----------------------------------------------------------------------
// The Generic Payload transaction represents a generic 
// bus read/write access. It is used as the default transaction in
// TLM2 blocking and nonblocking transport interfaces.
//----------------------------------------------------------------------


//---------------
// Group: Globals
//---------------
//
// Defines, Constants, enums.


// Enum: uvm_tlm_command_e
//
// Command attribute type definition
//
// UVM_TLM_READ_COMMAND      - Bus read operation
//
// UVM_TLM_WRITE_COMMAND     - Bus write operation
//
// UVM_TLM_IGNORE_COMMAND    - No bus operation.

enum uvm_tlm_command_e
  {
    UVM_TLM_READ_COMMAND,
    UVM_TLM_WRITE_COMMAND,
    UVM_TLM_IGNORE_COMMAND
  }
mixin(declareEnums!uvm_tlm_command_e);


// Enum: uvm_tlm_response_status_e
//
// Response status attribute type definition
//
// UVM_TLM_OK_RESPONSE                - Bus operation completed successfully
//
// UVM_TLM_INCOMPLETE_RESPONSE        - Transaction was not delivered to target
//
// UVM_TLM_GENERIC_ERROR_RESPONSE     - Bus operation had an error
//
// UVM_TLM_ADDRESS_ERROR_RESPONSE     - Invalid address specified
//
// UVM_TLM_COMMAND_ERROR_RESPONSE     - Invalid command specified
//
// UVM_TLM_BURST_ERROR_RESPONSE       - Invalid burst specified
//
// UVM_TLM_BYTE_ENABLE_ERROR_RESPONSE - Invalid byte enabling specified
//

enum uvm_tlm_response_status_e
  {
    UVM_TLM_OK_RESPONSE = 1,
    UVM_TLM_INCOMPLETE_RESPONSE = 0,
    UVM_TLM_GENERIC_ERROR_RESPONSE = -1,
    UVM_TLM_ADDRESS_ERROR_RESPONSE = -2,
    UVM_TLM_COMMAND_ERROR_RESPONSE = -3,
    UVM_TLM_BURST_ERROR_RESPONSE = -4,
    UVM_TLM_BYTE_ENABLE_ERROR_RESPONSE = -5
  }
mixin(declareEnums!uvm_tlm_response_status_e);


// typedef class uvm_tlm_extension_base;


//-----------------------
// Group: Generic Payload
//-----------------------

//----------------------------------------------------------------------
// Class: uvm_tlm_generic_payload
//
// This class provides a transaction definition commonly used in
// memory-mapped bus-based systems.  It's intended to be a general
// purpose transaction class that lends itself to many applications. The
// class is derived from uvm_sequence_item which enables it to be
// generated in sequences and transported to drivers through sequencers.
//----------------------------------------------------------------------

class uvm_tlm_generic_payload: uvm_sequence_item
{
  // Variable: m_address
  //
  // Address for the bus operation.
  // Should be set or read using the <set_address> and <get_address>
  // methods. The variable should be used only when constraining.
  //
  // For a read command or a write command, the target shall
  // interpret the current value of the address attribute as the start
  // address in the system memory map of the contiguous block of data
  // being read or written.
  // The address associated with any given byte in the data array is
  // dependent upon the address attribute, the array index, the
  // streaming width attribute, the endianness and the width of the physical bus.
  //
  // If the target is unable to execute the transaction with
  // the given address attribute (because the address is out-of-range,
  // for example) it shall generate a standard error response. The
  // recommended response status is ~UVM_TLM_ADDRESS_ERROR_RESPONSE~.
  //
   @rand ulong _m_address;

 
  // Variable: m_command
  //
  // Bus operation type.
  // Should be set using the <set_command>, <set_read> or <set_write> methods
  // and read using the <get_command>, <is_read> or <is_write> methods.
  // The variable should be used only when constraining.
  //
  // If the target is unable to execute a read or write command, it
  // shall generate a standard error response. The
  // recommended response status is UVM_TLM_COMMAND_ERROR_RESPONSE.
  //
  // On receipt of a generic payload transaction with the command
  // attribute equal to UVM_TLM_IGNORE_COMMAND, the target shall not execute
  // a write command or a read command not modify any data.
  // The target may, however, use the value of any attribute in
  // the generic payload, including any extensions.
  //
  // The command attribute shall be set by the initiator, and shall
  // not be overwritten by any interconnect
  //
  @rand uvm_tlm_command_e _m_command;

   
  // Variable: m_data
  //
  // Data read or to be written.
  // Should be set and read using the <set_data> or <get_data> methods
  // The variable should be used only when constraining.
  //
  // For a read command or a write command, the target shall copy data
  // to or from the data array, respectively, honoring the semantics of
  // the remaining attributes of the generic payload.
  //
  // For a write command or UVM_TLM_IGNORE_COMMAND, the contents of the
  // data array shall be set by the initiator, and shall not be
  // overwritten by any interconnect component or target. For a read
  // command, the contents of the data array shall be overwritten by the
  // target (honoring the semantics of the byte enable) but by no other
  // component.
  //
  // Unlike the OSCI TLM-2.0 LRM, there is no requirement on the endiannes
  // of multi-byte data in the generic payload to match the host endianness.
  // Unlike C++, it is not possible in SystemVerilog to cast an arbitrary
  // data type as an array of bytes. Therefore, matching the host
  // endianness is not necessary. In contrast, arbitrary data types may be
  // converted to and from a byte array using the streaming operator and
  // <uvm_object> objects may be further converted using the
  // <uvm_object::pack_bytes()> and <uvm_object::unpack_bytes()> methods.
  // All that is required is that a consistent mechanism is used to
  // fill the payload data array and later extract data from it.
  //
  // Should a generic payload be transferred to/from a SystemC model,
  // it will be necessary for any multi-byte data in that generic payload
  // to use/be interpreted using the host endianness.
  // However, this process is currently outside the scope of this standard.
  //
  @rand!32768 ubyte[] _m_data;


  // Variable: m_length
  //
  // The number of bytes to be copied to or from the <m_data> array,
  // inclusive of any bytes disabled by the <m_byte_enable> attribute.
  //
  // The data length attribute shall be set by the initiator,
  // and shall not be overwritten by any interconnect component or target.
  //
  // The data length attribute shall not be set to 0.
  // In order to transfer zero bytes, the <m_command> attribute
  // should be set to <UVM_TLM_IGNORE_COMMAND>.
  //
  @rand uint _m_length;
   

  // Variable: m_response_status
  //
  // Status of the bus operation.
  // Should be set using the <set_response_status> method
  // and read using the <get_response_status>, <get_response_string>,
  // <is_response_ok> or <is_response_error> methods.
  // The variable should be used only when constraining.
  //
  // The response status attribute shall be set to
  // UVM_TLM_INCOMPLETE_RESPONSE by the initiator, and may
  // be overwritten by the target. The response status attribute
  // should not be overwritten by any interconnect
  // component, because the default value UVM_TLM_INCOMPLETE_RESPONSE
  // indicates that the transaction was not delivered to the target.
  //
  // The target may set the response status attribute to UVM_TLM_OK_RESPONSE
  // to indicate that it was able to execute the command
  // successfully, or to one of the five error responses
  // to indicate an error. The target should choose the appropriate
  // error response depending on the cause of the error.
  // If a target detects an error but is unable to select a specific
  // error response, it may set the response status to
  // UVM_TLM_GENERIC_ERROR_RESPONSE.
  //
  // The target shall be responsible for setting the response status
  // attribute at the appropriate point in the
  // lifetime of the transaction. In the case of the blocking
  // transport interface, this means before returning
  // control from b_transport. In the case of the non-blocking
  // transport interface and the base protocol, this
  // means before sending the BEGIN_RESP phase or returning a value of UVM_TLM_COMPLETED.
  //
  // It is recommended that the initiator should always check the
  // response status attribute on receiving a
  // transition to the BEGIN_RESP phase or after the completion of
  // the transaction. An initiator may choose
  // to ignore the response status if it is known in advance that the
  // value will be UVM_TLM_OK_RESPONSE,
  // perhaps because it is known in advance that the initiator is
  // only connected to targets that always return
  // UVM_TLM_OK_RESPONSE, but in general this will not be the case. In
  // other words, the initiator ignores the
  // response status at its own risk.
  //
  @rand uvm_tlm_response_status_e _m_response_status;


  // Variable: m_dmi
  //
  // DMI mode is not yet supported in the UVM TLM2 subset.
  // This variable is provided for completeness and interoperability
  // with SystemC.
  //
  bool _m_dmi;
   

  // Variable: m_byte_enable
  //
  // Indicates valid <m_data> array elements.
  // Should be set and read using the <set_byte_enable> or <get_byte_enable> methods
  // The variable should be used only when constraining.
  //
  // The elements in the byte enable array shall be interpreted as
  // follows. A value of 8'h00 shall indicate that that
  // corresponding byte is disabled, and a value of 8'hFF shall
  // indicate that the corresponding byte is enabled.
  //
  // Byte enables may be used to create burst transfers where the
  // address increment between each beat is
  // greater than the number of significant bytes transferred on each
  // beat, or to place words in selected byte
  // lanes of a bus. At a more abstract level, byte enables may be
  // used to create "lacy bursts" where the data array of the generic
  // payload has an arbitrary pattern of holes punched in it.
  //
  // The byte enable mask may be defined by a small pattern applied
  // repeatedly or by a large pattern covering the whole data array.
  // The byte enable array may be empty, in which case byte enables
  // shall not be used for the current transaction.
  //
  // The byte enable array shall be set by the initiator and shall
  // not be overwritten by any interconnect component or target.
  //
  // If the byte enable pointer is not empty, the target shall either
  // implement the semantics of the byte enable as defined below or
  // shall generate a standard error response. The recommended response
  // status is UVM_TLM_BYTE_ENABLE_ERROR_RESPONSE.
  //
  // In the case of a write command, any interconnect component or
  // target should ignore the values of any disabled bytes in the
  // <m_data> array. In the case of a read command, any interconnect
  // component or target should not modify the values of disabled
  // bytes in the <m_data> array.
  //
  @rand!32768 ubyte[] _m_byte_enable;


  // Variable: m_byte_enable_length
  //
  // The number of elements in the <m_byte_enable> array.
  //
  // It shall be set by the initiator, and shall not be overwritten
  // by any interconnect component or target.
  //
  @rand uint _m_byte_enable_length;


  // Variable: m_streaming_width
  //    
  // Number of bytes transferred on each beat.
  // Should be set and read using the <set_streaming_width> or
  // <get_streaming_width> methods
  // The variable should be used only when constraining.
  //
  // Streaming affects the way a component should interpret the data
  // array. A stream consists of a sequence of data transfers occurring
  // on successive notional beats, each beat having the same start
  // address as given by the generic payload address attribute. The
  // streaming width attribute shall determine the width of the stream,
  // that is, the number of bytes transferred on each beat. In other
  // words, streaming affects the local address associated with each
  // byte in the data array. In all other respects, the organization of
  // the data array is unaffected by streaming.
  //
  // The bytes within the data array have a corresponding sequence of
  // local addresses within the component accessing the generic payload
  // transaction. The lowest address is given by the value of the
  // address attribute. The highest address is given by the formula
  // address_attribute + streaming_width - 1. The address to or from
  // which each byte is being copied in the target shall be set to the
  // value of the address attribute at the start of each beat.
  //
  // With respect to the interpretation of the data array, a single
  // transaction with a streaming width shall be functionally equivalent
  // to a sequence of transactions each having the same address as the
  // original transaction, each having a data length attribute equal to
  // the streaming width of the original, and each with a data array
  // that is a different subset of the original data array on each
  // beat. This subset effectively steps down the original data array
  // maintaining the sequence of bytes.
  //
  // A streaming width of 0 indicates that a streaming transfer
  // is not required. it is equivalent to a streaming width 
  // value greater than or equal to the size of the <m_data> array.
  //
  // Streaming may be used in conjunction with byte enables, in which
  // case the streaming width would typically be equal to the byte
  // enable length. It would also make sense to have the streaming width
  // a multiple of the byte enable length. Having the byte enable length
  // a multiple of the streaming width would imply that different bytes
  // were enabled on each beat.
  //
  // If the target is unable to execute the transaction with the
  // given streaming width, it shall generate a standard error
  // response. The recommended response status is
  // TLM_BURST_ERROR_RESPONSE.
  //
  @rand uint _m_streaming_width;

  protected uvm_tlm_extension_base[uvm_tlm_extension_base] _m_extensions;
  // @rand!1024
  uvm_tlm_extension_base[] _m_rand_exts;


  mixin uvm_object_utils;


  // Function: new
  //
  // Create a new instance of the generic payload.  Initialize all the
  // members to their default values.

  this(string name="") {
    synchronized(this) {
      super(name);
      _m_address = 0;
      _m_command = UVM_TLM_IGNORE_COMMAND;
      _m_length = 0;
      _m_response_status = UVM_TLM_INCOMPLETE_RESPONSE;
      _m_dmi = false;
      _m_byte_enable_length = 0;
      _m_streaming_width = 0;
    }
  }


  // Function- do_print
  //
  override void do_print(uvm_printer printer) {
    synchronized(this) {
      ubyte be;
      super.do_print(printer);
      printer.print("address", _m_address, UVM_HEX);
      printer.print("command", _m_command);
      printer.print("response_status", _m_response_status);
      printer.print("streaming_width", _m_streaming_width, UVM_HEX);

      printer.print_array_header("data", _m_length, "darray(byte)");
      for(int i=0; i < _m_length && i < _m_data.length; ++i) {
	if(_m_byte_enable_length) {
	  be = _m_byte_enable[i % _m_byte_enable_length];
	  printer.print_generic(format("[%0d]",i), "byte", 8,
				format("'h%h%s", _m_data[i],
				       ((be == 0xFF) ? "" : " x")));
	}
	else {
	  printer.print_generic (format("[%0d]", i), "byte", 8,
				 format("'h%h", _m_data[i]));
	}
      }
      printer.print_array_footer();
    
      string name;
      printer.print_array_header("extensions", _m_extensions.length,
				 "aa(obj,obj)");
      foreach(ext_; _m_extensions) {
	name = "[" ~ ext_.get_name() ~ "]";
	printer.print_object(name, ext_, '[');
      }
      printer.print_array_footer();
    }
  }


  // Function- do_copy
  //
  override void do_copy(uvm_object rhs) {
    super.do_copy(rhs);
    auto gp = cast(uvm_tlm_generic_payload) rhs;
    assert(gp !is null);
    synchronized(this) {
      synchronized(rhs) {
	_m_address            = gp._m_address;
	_m_command            = gp._m_command;
	_m_data               = gp._m_data.dup;
	_m_dmi                = gp._m_dmi;
	_m_length             = gp._m_length;
	_m_response_status    = gp._m_response_status;
	_m_byte_enable        = gp._m_byte_enable.dup;
	_m_streaming_width    = gp._m_streaming_width;
	_m_byte_enable_length = gp._m_byte_enable_length;
	// _m_extensions         = gp._m_extensions.dup;
	_m_extensions = null;
	foreach(key, val; gp._m_extensions) {
	  _m_extensions[key] = cast(uvm_tlm_extension_base) val.clone;
	}
      }
    }
  }

  // Function- do_compare
  //
  override bool do_compare(uvm_object rhs, uvm_comparer comparer) {
    bool do_compare_;
    do_compare_ = super.do_compare(rhs, comparer);
    auto gp = cast(uvm_tlm_generic_payload) rhs;
    assert(gp !is null);
    synchronized(this) {
      synchronized(rhs) {
	do_compare_ = (_m_address == gp._m_address &&
		       _m_command == gp._m_command &&
		       _m_length  == gp._m_length  &&
		       _m_dmi     == gp._m_dmi &&
		       _m_byte_enable_length == gp._m_byte_enable_length  &&
		       _m_response_status    == gp._m_response_status &&
		       _m_streaming_width    == gp._m_streaming_width );
    
	if (do_compare_ && _m_length == gp._m_length) {
	  ubyte lhs_be, rhs_be;
	  for(int i=0; do_compare_ && i < _m_length && i < _m_data.length; ++i) {
	    if(_m_byte_enable_length) {
	      lhs_be = _m_byte_enable[i % _m_byte_enable_length];
	      rhs_be = gp._m_byte_enable[i % gp._m_byte_enable_length];
	      do_compare_ = ((_m_data[i] & lhs_be) == (gp._m_data[i] & rhs_be));
	    }
	    else {
	      do_compare_ = (_m_data[i] == gp._m_data[i]);
	    }
	  }
	}

	if (do_compare_) {
	  foreach (key, val; _m_extensions) {
	    auto pval = key in gp._m_extensions;
	    uvm_tlm_extension_base rhs_val =  (pval !is null) ? *pval : null;
	    do_compare_ = comparer.compare_object(key.get_name(),
						  val, rhs_val);
	    if (!do_compare_) break;
	  }
	}

	if (do_compare_) {
	  foreach (key, val; gp._m_extensions) {
	    if (key !in gp._m_extensions) {
	      do_compare_ = comparer.compare_object(key.get_name(),
						    null, val);
	      if (!do_compare_) break;
	    }
	  }
	}
      
	if (!do_compare_ && comparer.show_max > 0) {
	  string msg =
	    format("GP miscompare between '%s' and '%s':\nlhs = %s\nrhs = %s",
		   get_full_name(), gp.get_full_name(), this.convert2string(),
		   gp.convert2string());
	  switch (comparer.sev) {
	  case UVM_WARNING: uvm_warning("MISCMP", msg); break;
	  case UVM_ERROR:   uvm_error("MISCMP", msg); break;
	  default:          uvm_info("MISCMP", msg, UVM_LOW); break;
	  }
	}
	return do_compare_;
      }
    }
  }
   

  // Function- do_pack
  //
  // We only pack m_length bytes of the m_data array, even if m_data is larger
  // than m_length. Same treatment for the byte-enable array. We do not pack
  // the extensions, if any, as we will be unable to unpack them.
  override void do_pack(uvm_packer packer) {
    synchronized(this) {
      super.do_pack(packer);
      if (_m_length > _m_data.length) {
	uvm_fatal("PACK_DATA_ARR",
		  format("Data array m_length property (%0d) greater" ~
			 " than m_data.size (%0d)",
			 _m_length, _m_data.length));
      }
      if (_m_byte_enable_length > _m_byte_enable.length) {
	uvm_fatal("PACK_DATA_ARR",
		  format("Data array m_byte_enable_length property (%0d)" ~
			 " greater than m_byte_enable.size (%0d)",
			 _m_byte_enable_length, _m_byte_enable.length));
	packer.pack(_m_address);
	packer.pack(_m_command);
	packer.pack(_m_length);
	for (int i=0; i < _m_length; ++i) {
	  packer.pack(_m_data[i]);
	}
	packer.pack(_m_response_status);
	packer.pack(_m_byte_enable_length);
	for (int i=0; i < _m_byte_enable_length; ++i) {
	  packer.pack(_m_byte_enable[i]);
	}
	packer.pack(_m_streaming_width);
      }
    }
  }

  // Function- do_unpack
  //
  // We only reallocate m_data/m_byte_enable if the new size
  // is greater than their current size. We do not unpack extensions
  // because we do not know what object types to allocate before we
  // unpack into them. Extensions must be handled by user code.
  override void do_unpack(uvm_packer packer) {
    synchronized(this) {
      super.do_unpack(packer);
      packer.unpack(_m_address);
      packer.unpack(_m_command);
      packer.unpack(_m_length);
      if (_m_data.length < _m_length) {
	_m_data.length = _m_length;
      }
      foreach (data; _m_data) {
	packer.unpack(data);
      }
      packer.unpack(_m_response_status);
      packer.unpack(_m_byte_enable_length);
      if (_m_byte_enable.length < _m_byte_enable_length) {
	_m_byte_enable.length = _m_byte_enable_length;
      }
      for (int i=0; i < _m_byte_enable_length; ++i) {
	packer.unpack(_m_byte_enable[i]);
      }
      packer.unpack(_m_streaming_width);
    }
  }

  // Function- do_record
  //
  override void do_record(uvm_recorder recorder) {
    synchronized(this) {
      if (!is_recording_enabled()) {
	return;
      }
      super.do_record(recorder);
      recorder.record("address", _m_address);
      recorder.record("command", _m_command);
      recorder.record("data_length", _m_length);
      recorder.record("byte_enable_length", _m_byte_enable_length);
      recorder.record("response_status", _m_response_status);
      recorder.record("streaming_width", _m_streaming_width);

      for (int i=0; i < _m_length; ++i) {
	recorder.record(format("\\data[%0d] ", i), _m_data[i]);
      }

      for (int i=0; i < _m_byte_enable_length; ++i) {
	recorder.record(format("\\byte_en[%0d] ", i), _m_byte_enable[i]);
      }

      foreach (key, val; _m_extensions) {
	recorder.record_object(key.get_name(), val);
      }
    }
  }

  // Function- convert2string
  //
  override string convert2string() {
    synchronized(this) {
      string msg = format("%s %s [0x%16x] =", super.convert2string(),
			  _m_command, _m_address);

      for(uint i = 0; i < _m_length; ++i) {
	if (!_m_byte_enable_length ||
	    (_m_byte_enable[i % _m_byte_enable_length] == 0xFF)) {
	  msg ~= format(" %02x", _m_data[i]);
	}
	else {
	  msg ~= " --";
	}
      }

      msg ~= " (status=" ~ get_response_string() ~ ")";

      return msg;
    }
  }


  //--------------------------------------------------------------------
  // Group: Accessors
  //
  // The accessor functions let you set and get each of the members of the 
  // generic payload. All of the accessor methods are virtual. This implies 
  // a slightly different use model for the generic payload than 
  // in SystemC. The way the generic payload is defined in SystemC does 
  // not encourage you to create new transaction types derived from 
  // uvm_tlm_generic_payload. Instead, you would use the extensions mechanism. 
  // Thus in SystemC none of the accessors are virtual.
  //--------------------------------------------------------------------

   // Function: get_command
   //
   // Get the value of the <m_command> variable

  uvm_tlm_command_e get_command() {
    synchronized(this) {
      return _m_command;
    }
  }

   // Function: set_command
   //
   // Set the value of the <m_command> variable
   
  void set_command(uvm_tlm_command_e command) {
    synchronized(this) {
      _m_command = command;
    }
  }

   // Function: is_read
   //
   // Returns true if the current value of the <m_command> variable
   // is ~UVM_TLM_READ_COMMAND~.
   
  bool is_read() {
    synchronized(this) {
      return (_m_command == UVM_TLM_READ_COMMAND);
    }
  }
 
   // Function: set_read
   //
   // Set the current value of the <m_command> variable
   // to ~UVM_TLM_READ_COMMAND~.
   
  void set_read() {
    set_command(UVM_TLM_READ_COMMAND);
  }

   // Function: is_write
   //
   // Returns true if the current value of the <m_command> variable
   // is ~UVM_TLM_WRITE_COMMAND~.
 
  bool is_write() {
    synchronized(this) {
      return (_m_command == UVM_TLM_WRITE_COMMAND);
    }
  }
 
   // Function: set_write
   //
   // Set the current value of the <m_command> variable
   // to ~UVM_TLM_WRITE_COMMAND~.

  void set_write() {
    set_command(UVM_TLM_WRITE_COMMAND);
  }
  
   // Function: set_address
   //
   // Set the value of the <m_address> variable
  void set_address(ulong addr) {
    synchronized(this) {
      _m_address = addr;
    }
  }

   // Function: get_address
   //
   // Get the value of the <m_address> variable
 
  ulong get_address() {
    synchronized(this) {
      return _m_address;
    }
  }

   // Function: get_data
   //
   // Return the value of the <m_data> array
 
  void get_data(out ubyte[] p) {
    synchronized(this) {
      p = _m_data.dup;
    }
  }

  ubyte[] get_data() {
    synchronized(this) {
      return _m_data.dup;
    }
  }

   // Function: set_data
   //
   // Set the value of the <m_data> array  

  void set_data(ubyte[] p) {
    synchronized(this) {
      _m_data = p.dup;
    }
  }
  
   // Function: get_data_length
   //
   // Return the current size of the <m_data> array
   
  uint get_data_length() {
    synchronized(this) {
      return _m_length;
    }
  }

  // Function: set_data_length
  // Set the value of the <m_length>
   
  void set_data_length(uint length) {
    synchronized(this) {
      _m_length = length;
    }
  }

   // Function: get_streaming_width
   //
   // Get the value of the <m_streaming_width> array
  
  uint get_streaming_width() {
    synchronized(this) {
      return _m_streaming_width;
    }
  }

 
   // Function: set_streaming_width
   //
   // Set the value of the <m_streaming_width> array
   
  void set_streaming_width(uint width) {
    synchronized(this) {
      _m_streaming_width = width;
    }
  }

   // Function: get_byte_enable
   //
   // Return the value of the <m_byte_enable> array
  void get_byte_enable(out ubyte[] p) {
    synchronized(this) {
      p = _m_byte_enable.dup;
    }
  }

  ubyte[] get_byte_enable() {
    synchronized(this) {
      return _m_byte_enable.dup;
    }
  }

   // Function: set_byte_enable
   //
   // Set the value of the <m_byte_enable> array
   
  void set_byte_enable(ref ubyte[] p) {
    synchronized(this) {
      _m_byte_enable = p.dup;
    }
  }

   // Function: get_byte_enable_length
   //
   // Return the current size of the <m_byte_enable> array
   
  uint get_byte_enable_length() {
    synchronized(this) {
      return _m_byte_enable_length;
    }
  }

   // Function: set_byte_enable_length
   //
   // Set the size <m_byte_enable_length> of the <m_byte_enable> array
   // i.e.  <m_byte_enable>.size()
   
  void set_byte_enable_length(uint length) {
    synchronized(this) {
      _m_byte_enable_length = length;
    }
  }

   // Function: set_dmi_allowed
   //
   // DMI hint. Set the internal flag <m_dmi> to allow dmi access
   
  void set_dmi_allowed(bool dmi) {
    synchronized(this) {
      _m_dmi = dmi;
    }
  }
   
   // Function: is_dmi_allowed
   //
   // DMI hint. Query the internal flag <m_dmi> if allowed dmi access 

  bool is_dmi_allowed() {
    synchronized(this) {
      return _m_dmi;
    }
  }

   // Function: get_response_status
   //
   // Return the current value of the <m_response_status> variable
   
  uvm_tlm_response_status_e get_response_status() {
    synchronized(this) {
      return _m_response_status;
    }
  }

   // Function: set_response_status
   //
   // Set the current value of the <m_response_status> variable

  void set_response_status(uvm_tlm_response_status_e status) {
    synchronized(this) {
      _m_response_status = status;
    }
  }

   // Function: is_response_ok
   //
   // Return TRUE if the current value of the <m_response_status> variable
   // is ~UVM_TLM_OK_RESPONSE~

  bool is_response_ok() {
    synchronized(this) {
      return (_m_response_status > 0);
    }
  }

   // Function: is_response_error
   //
   // Return TRUE if the current value of the <m_response_status> variable
   // is not ~UVM_TLM_OK_RESPONSE~

  bool is_response_error() {
    return !is_response_ok();
  }

   // Function: get_response_string
   //
   // Return the current value of the <m_response_status> variable
   // as a string

  string get_response_string() {
    synchronized(this) {
      final switch(_m_response_status) {
      case UVM_TLM_OK_RESPONSE                : return "OK";
      case UVM_TLM_INCOMPLETE_RESPONSE        : return "INCOMPLETE";
      case UVM_TLM_GENERIC_ERROR_RESPONSE     : return "GENERIC_ERROR";
      case UVM_TLM_ADDRESS_ERROR_RESPONSE     : return "ADDRESS_ERROR";
      case UVM_TLM_COMMAND_ERROR_RESPONSE     : return "COMMAND_ERROR";
      case UVM_TLM_BURST_ERROR_RESPONSE       : return "BURST_ERROR";
      case UVM_TLM_BYTE_ENABLE_ERROR_RESPONSE : return "BYTE_ENABLE_ERROR";
      }

      // we should never get here
      // return "UNKNOWN_RESPONSE";
    }
  }

  //--------------------------------------------------------------------
  // Group: Extensions Mechanism
  //
  //--------------------------------------------------------------------

  // Function: set_extension
  //
  // Add an instance-specific extension. Only one instance of any given
  // extension type is allowed. If there is an existing extension
  // instance of the type of ~ext~, ~ext~ replaces it and its handle
  // is returned. Otherwise, ~null~ is returned.
   
  uvm_tlm_extension_base set_extension(uvm_tlm_extension_base ext) {
    synchronized(this) {
      uvm_tlm_extension_base set_extension_;
      uvm_tlm_extension_base ext_handle = ext.get_type_handle();
      auto pext = ext_handle in _m_extensions;
      if (pext is null) {
	set_extension_ = null;
      }
      else {
	set_extension_ = *pext;
      }
      _m_extensions[ext_handle] = ext;
      return set_extension_;
    }
  }


  // Function: get_num_extensions
  //
  // Return the current number of instance specific extensions.
   
  uint get_num_extensions() {
    synchronized(this) {
      return cast(uint) _m_extensions.length;
    }
  }
   

  // Function: get_extension
  //
  // Return the instance specific extension bound under the specified key.
  // If no extension is bound under that key, ~null~ is returned.
   
  uvm_tlm_extension_base get_extension(uvm_tlm_extension_base ext_handle) {
    synchronized(this) {
      auto pext = ext_handle in _m_extensions;
      if(pext is null) {
	return null;
      }
      return *pext;
    }
  }
   

  // Function: clear_extension
  //
  // Remove the instance-specific extension bound under the specified key.
   
  void clear_extension(uvm_tlm_extension_base ext_handle) {
    synchronized(this) {
      if(ext_handle in _m_extensions) {
	_m_extensions.remove(ext_handle);
      }
      else {
	uvm_info("GP_EXT", format("Unable to find extension to clear"),
		 UVM_MEDIUM);
      }
    }
  }


  // Function: clear_extensions
  //
  // Remove all instance-specific extensions
   
  void clear_extensions() {
    synchronized(this) {
      _m_extensions = null;
    }
  }


  // Function: pre_randomize()
  // Prepare this class instance for randomization
  //
  void pre_randomize() {
    synchronized(this) {
      int i;
      _m_rand_exts = new uvm_tlm_extension_base[_m_extensions.length];
      foreach (ext; _m_extensions) {
	_m_rand_exts[i++] = ext;
      }
    }
  }

  // Function: post_randomize()
  // Clean-up this class instance after randomization
  //
  void post_randomize() {
    synchronized(this) {
      _m_rand_exts = null;
    }
  }
}

//----------------------------------------------------------------------
// Class: uvm_tlm_gp
//
// This typedef provides a short, more convenient name for the
// <uvm_tlm_generic_payload> type.
//----------------------------------------------------------------------

alias uvm_tlm_gp=uvm_tlm_generic_payload;


//----------------------------------------------------------------------
// Class: uvm_tlm_extension_base
//
// The class uvm_tlm_extension_base is the non-parameterized base class for
// all generic payload extensions.  It includes the utility do_copy()
// and create().  The pure virtual function get_type_handle() allows you
// to get a unique handle that represents the derived type.  This is
// implemented in derived classes.
//
// This class is never used directly by users.
// The <uvm_tlm_extension> class is used instead.
//
abstract class uvm_tlm_extension_base: uvm_object
{

  // Function: new
  //
  this(string name = "") {
    super(name);
  }

  // Function: get_type_handle
  //
  // An interface to polymorphically retrieve a handle that uniquely
  // identifies the type of the sub-class

  uvm_tlm_extension_base get_type_handle();

  // Function: get_type_handle_name
  //
  // An interface to polymorphically retrieve the name that uniquely
  // identifies the type of the sub-class

  string get_type_handle_name();

  override void do_copy(uvm_object rhs) {
    super.do_copy(rhs);
  }

  // Function: create
  //
   
  override uvm_object create (string name="") {
    return null;
  }
}


//----------------------------------------------------------------------
// Class: uvm_tlm_extension
//
// TLM extension class. The class is parameterized with arbitrary type
// which represents the type of the extension. An instance of the
// generic payload can contain one extension object of each type; it
// cannot contain two instances of the same extension type.
//
// The extension type can be identified using the <ID()>
// method.
//
// To implement a generic payload extension, simply derive a new class
// from this class and specify the name of the derived class as the
// extension parameter.
//
//|
//| class my_ID extends uvm_tlm_extension#(my_ID);
//|   int ID;
//|
//|   `uvm_object_utils_begin(my_ID)
//|      `uvm_field_int(ID, UVM_ALL_ON)
//|   `uvm_object_utils_end
//|
//|   function new(string name = "my_ID");
//|      super.new(name);
//|   endfunction
//| endclass
//|

class uvm_tlm_extension(T): uvm_tlm_extension_base
{

  alias this_type=uvm_tlm_extension!(T);

  static this_type m_my_tlm_ext_type;

   // Function: new
   //
   // creates a new extension object.

  this(string name="") {
    super(name);
  }
  
   // Function: ID()
   //
   // Return the unique ID of this TLM extension type.
   // This method is used to identify the type of the extension to retrieve
   // from a <uvm_tlm_generic_payload> instance,
   // using the <uvm_tlm_generic_payload::get_extension()> method.
   //
  static this_type ID() {
    if (m_my_tlm_ext_type is null) {
      m_my_tlm_ext_type = new this_type();
    }
    return m_my_tlm_ext_type;
  }

  uvm_tlm_extension_base get_type_handle() {
    return ID();
  }

  string get_type_handle_name() {
    return qualifiedTypeName!T;
  }

  uvm_object create (string name="") {
    return null;
  }
}

