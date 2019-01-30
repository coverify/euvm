//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010-2011 Mentor Graphics Corporation
//    Copyright 2010-2011 Cadence Design Systems, Inc.
//    Copyright 2015      Coverify Systems Technology
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
 
module uvm.reg.uvm_reg_sequence;  
import uvm.seq.uvm_sequence;
import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequencer;
import uvm.seq.uvm_sequencer_base;
import uvm.seq.uvm_sequence_item;
import uvm.reg.uvm_reg;
import uvm.reg.uvm_reg_item;
import uvm.reg.uvm_reg_block;
import uvm.reg.uvm_reg_adapter;
import uvm.reg.uvm_reg_map;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_mem;

import esdl.base.core: sleep, wait;

import uvm.base.uvm_object_defines;
import uvm.base.uvm_object_globals;

import uvm.meta.misc;

//------------------------------------------------------------------------------
// TITLE: Register Sequence Classes
//------------------------------------------------------------------------------
//
// This section defines the base classes used for register stimulus generation.
//------------------------------------------------------------------------------

                                                              
//------------------------------------------------------------------------------
//
// CLASS: uvm_reg_sequence
//
// This class provides base functionality for both user-defined RegModel test
// sequences and "register translation sequences".
//
// - When used as a base for user-defined RegModel test sequences, this class
//   provides convenience methods for reading and writing registers and
//   memories. Users implement the body() method to interact directly with
//   the RegModel model (held in the <model> property) or indirectly via the
//   delegation methods in this class. 
//
// - When used as a translation sequence, objects of this class are
//   executed directly on a bus sequencerwhich are used in support of a layered sequencer
//   use model, a pre-defined convert-and-execute algorithm is provided.
//
// Register operations do not require extending this class if none of the above
// services are needed. Register test sequences can be extend from the base
// <uvm_sequence #(REQ,RSP)> base class or even from outside a sequence. 
//
// Note- The convenience API not yet implemented.
//------------------------------------------------------------------------------

class uvm_reg_sequence(BASE=uvm_sequence!uvm_reg_item): BASE
{
  import esdl.rand;
  
  mixin uvm_object_essentials;

  // Parameter: BASE
  //
  // Specifies the sequence type to extend from.
  //
  // When used as a translation sequence running on a bus sequencer, ~BASE~ must
  // be compatible with the sequence type expected by the bus sequencer.
  //
  // When used as a test sequence running on a particular sequencer, ~BASE~
  // must be compatible with the sequence type expected by that sequencer.
  //
  // When used as a virtual test sequence without a sequencer, ~BASE~ does
  // not need to be specified, i.e. the default specialization is adequate.
  // 
  // To maximize opportunities for reuse, user-defined RegModel sequences should
  // "promote" the BASE parameter.
  //
  // | class my_reg_sequence #(type BASE=uvm_sequence #(uvm_reg_item))
  // |                               extends uvm_reg_sequence #(BASE);
  //
  // This way, the RegModel sequence can be extended from 
  // user-defined base sequences.


  // Variable: model
  //
  // Block abstraction this sequence executes on, defined only when this
  // sequence is a user-defined test sequence.
  //
  uvm_reg_block _model;


  // Variable: adapter
  //
  // Adapter to use for translating between abstract register transactions
  // and physical bus transactions, defined only when this sequence is a
  // translation sequence.
  //
  uvm_reg_adapter _adapter;


  // Variable: reg_seqr
  //
  // Layered upstream "register" sequencer.
  //
  // Specifies the upstream sequencer between abstract register transactions
  // and physical bus transactions. Defined only when this sequence is a
  // translation sequence, and we want to "pull" from an upstream sequencer.
  //
  uvm_sequencer!(uvm_reg_item) _reg_seqr;


  // Function: new
  //
  // Create a new instance, giving it the optional ~name~.
  //
  this(string name="uvm_reg_sequence_inst") {
    super(name);
  }


  // Task: body
  //
  // Continually gets a register transaction from the configured upstream
  // sequencer, <reg_seqr>, and executes the corresponding bus transaction
  // via <do_rw_access>. 
  //
  // User-defined RegModel test sequences must override body() and not call
  // super.body(), else a warning will be issued and the calling process
  // not return.
  //

  // task
  override void body() {
    if (m_sequencer is null) {
      uvm_fatal("NO_SEQR",
		"Sequence executing as translation sequence, but is not" ~
		" associated with a sequencer (m_sequencer == null)");
    }
    if (_reg_seqr is null) {
      uvm_warning("REG_XLATE_NO_SEQR",
		  "Executing RegModel translation sequence on sequencer " ~
		  m_sequencer.get_full_name() ~
		  "' does not have an upstream sequencer defined. " ~
		  "Execution of register items available only via direct" ~
		  " calls to 'do_rw_access'");
      // wait(0);
      sleep();		// esdl.base.core.sleep;
    }
    uvm_info("REG_XLATE_SEQ_START",
	     "Starting RegModel translation sequence on sequencer " ~
	     m_sequencer.get_full_name() ~ "'", uvm_verbosity.UVM_LOW);
    while(true) {
      uvm_reg_item reg_item;
      _reg_seqr.peek(reg_item);
      do_reg_item(reg_item);
      _reg_seqr.get(reg_item);
      // #0
      wait(0);
    }
  }


  enum seq_parent_e { LOCAL, UPSTREAM };

  seq_parent_e _parent_select = seq_parent_e.LOCAL;

  uvm_sequence_base _upstream_parent;


  // Function: do_reg_item
  //
  // Executes the given register transaction, ~rw~, via the sequencer on
  // which this sequence was started (i.e. m_sequencer). Uses the configured
  // <adapter> to convert the register transaction into the type expected by
  // this sequencer.
  //

  // task
  void do_reg_item(uvm_reg_item rw) {
    if (m_sequencer is null) {
      uvm_fatal("REG/DO_ITEM/NULL", "do_reg_item: m_sequencer is null");
    }
    if (_adapter is null) {
      uvm_fatal("REG/DO_ITEM/NULL","do_reg_item: adapter handle is null");
    }

    uvm_info("DO_RW_ACCESS","Doing transaction: " ~ rw.convert2string(), uvm_verbosity.UVM_HIGH);

    if (_parent_select == seq_parent_e.LOCAL) {
      _upstream_parent = rw.parent;
      rw.parent = this;
    }

    if (rw.kind == UVM_WRITE) {
      rw.local_map.do_bus_write(rw, m_sequencer, _adapter);
    }
    else {
      rw.local_map.do_bus_read(rw, m_sequencer, _adapter);
    }
    
    if (_parent_select == seq_parent_e.LOCAL) {
      rw.parent = _upstream_parent;
    }
  }


  //----------------------------------
  // Group: Convenience Write/Read API
  //----------------------------------
  //
  // The following methods delegate to the corresponding method in the 
  // register or memory element. They allow a sequence ~body()~ to do
  // reads and writes without having to explicitly supply itself to
  // ~parent~ sequence argument. Thus, a register write
  //
  //| model.regA.write(status, value, .parent(this));
  //
  // can be written instead as
  //
  //| write_reg(model.regA, status, value);
  //


  // Task: write_reg
  //
  // Writes the given register ~rg~ using <uvm_reg::write>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| write_reg(model.regA, status, value);
  //
  // is equivalent to
  //
  //| model.regA.write(status, value, .parent(this));
  //
  // task
  void write_reg(ref uvm_reg       rg,
		 out uvm_status_e  status,
		 uvm_reg_data_t    value,
		 uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
		 uvm_reg_map       map = null,
		 int               prior = -1,
		 uvm_object        extension = null,
		 string            fname = "",
		 int               lineno = 0) {
    if (rg is null) {
      uvm_error("NO_REG","Register argument is null");
    }
    else {
      rg.write(status, value, path, map, this, prior, extension, fname, lineno);
    }
  }


  // Task: read_reg
  //
  // Reads the given register ~rg~ using <uvm_reg::read>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| read_reg(model.regA, status, value);
  //
  // is equivalent to
  //
  //| model.regA.read(status, value, .parent(this));
  //
  //
  // task
  void read_reg(ref uvm_reg           rg,
		out uvm_status_e      status,
		out uvm_reg_data_t    value,
		uvm_path_e            path = uvm_path_e.UVM_DEFAULT_PATH,
		uvm_reg_map           map = null,
		int                   prior = -1,
		uvm_object            extension = null,
		string                fname = "",
		int                   lineno = 0) {
    if (rg is null) {
      uvm_error("NO_REG","Register argument is null");
    }
    else {
      rg.read(status, value, path, map, this, prior, extension, fname, lineno);
    }
  }


  // Task: poke_reg
  //
  // Pokes the given register ~rg~ using <uvm_reg::poke>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| poke_reg(model.regA, status, value);
  //
  // is equivalent to
  //
  //| model.regA.poke(status, value, .parent(this));
  //
  //
  // task
  void poke_reg(ref uvm_reg       rg,
		out uvm_status_e  status,
		uvm_reg_data_t    value,
		string            kind = "",
		uvm_object        extension = null,
		string            fname = "",
		int               lineno = 0) {
    if (rg is null) {
      uvm_error("NO_REG","Register argument is null");
    }
    else {
      rg.poke(status, value, kind, this, extension, fname, lineno);
    }
  }



  // Task: peek_reg
  //
  // Peeks the given register ~rg~ using <uvm_reg::peek>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| peek_reg(model.regA, status, value);
  //
  // is equivalent to
  //
  //| model.regA.peek(status, value, .parent(this));
  //
  // task
  void peek_reg(ref uvm_reg           rg,
		out uvm_status_e      status,
		out uvm_reg_data_t    value,
		string                kind = "",
		uvm_object            extension = null,
		string                fname = "",
		int                   lineno = 0) {
    if (rg is null) {
      uvm_error("NO_REG","Register argument is null");
    }
    else {
      rg.peek(status,value,kind,this,extension,fname,lineno);
    }
  }
   
   
  // Task: update_reg
  //
  // Updates the given register ~rg~ using <uvm_reg::update>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| update_reg(model.regA, status, value);
  //
  // is equivalent to
  //
  //| model.regA.update(status, value, .parent(this));
  //
  // task
  void update_reg(ref uvm_reg       rg,
		  out uvm_status_e  status,
		  uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
		  uvm_reg_map       map = null,
		  int               prior = -1,
		  uvm_object        extension = null,
		  string            fname = "",
		  int               lineno = 0) {
    if (rg is null) {
      uvm_error("NO_REG","Register argument is null");
    }
    else {
      rg.update(status,path,map,this,prior,extension,fname,lineno);
    }
  }



  // Task: mirror_reg
  //
  // Mirrors the given register ~rg~ using <uvm_reg::mirror>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| mirror_reg(model.regA, status, UVM_CHECK);
  //
  // is equivalent to
  //
  //| model.regA.mirror(status, UVM_CHECK, .parent(this));
  //
  // task
  void mirror_reg(ref uvm_reg       rg,
		  out uvm_status_e  status,
		  uvm_check_e       check  = uvm_check_e.UVM_NO_CHECK,
		  uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
		  uvm_reg_map       map = null,
		  int               prior = -1,
		  uvm_object        extension = null,
		  string            fname = "",
		  int               lineno = 0) {
    if (rg is null) {
      uvm_error("NO_REG","Register argument is null");
    }
    else {
      rg.mirror(status, check, path, map, this, prior, extension, fname, lineno);
    }
  }
  

  // Task: write_mem
  //
  // Writes the given memory ~mem~ using <uvm_mem::write>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| write_mem(model.regA, status, offset, value);
  //
  // is equivalent to
  //
  //| model.regA.write(status, offset, value, .parent(this));
  //
  // task
  void write_mem(ref uvm_mem       mem,
		 out uvm_status_e  status,
		 uvm_reg_addr_t    offset,
		 uvm_reg_data_t    value,
		 uvm_path_e        path = uvm_path_e.UVM_DEFAULT_PATH,
		 uvm_reg_map       map = null,
		 int               prior = -1,
		 uvm_object        extension = null,
		 string            fname = "",
		 int               lineno = 0) {
    if (mem is null) {
      uvm_error("NO_MEM","Memory argument is null");
    }
    else {
      mem.write(status, offset, value, path, map, this, prior, extension, fname, lineno);
    }
  }


  // Task: read_mem
  //
  // Reads the given memory ~mem~ using <uvm_mem::read>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| read_mem(model.regA, status, offset, value);
  //
  // is equivalent to
  //
  //| model.regA.read(status, offset, value, .parent(this));
  //
  //
  // task
  void read_mem(ref uvm_mem        mem,
		out uvm_status_e   status,
		uvm_reg_addr_t     offset,
		out uvm_reg_data_t value,
		uvm_path_e         path = uvm_path_e.UVM_DEFAULT_PATH,
		uvm_reg_map        map = null,
		int                prior = -1,
		uvm_object         extension = null,
		string             fname = "",
		int                lineno = 0) {
    if (mem is null) {
      uvm_error("NO_MEM","Memory argument is null");
    }
    else {
      mem.read(status, offset, value, path, map, this, prior, extension, fname, lineno);
    }
  }



  // Task: poke_mem
  //
  // Pokes the given memory ~mem~ using <uvm_mem::poke>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| poke_mem(model.regA, status, offset, value);
  //
  // is equivalent to
  //
  //| model.regA.poke(status, offset, value, .parent(this));
  //
  //
  // task
  void poke_mem(ref uvm_mem       mem,
		out uvm_status_e  status,
		uvm_reg_addr_t    offset,
		uvm_reg_data_t    value,
		string            kind = "",
		uvm_object        extension = null,
		string            fname = "",
		int               lineno = 0) {
    if (mem is null) {
      uvm_error("NO_MEM", "Memory argument is null");
    }
    else {
      mem.poke(status, offset, value, kind, this, extension, fname, lineno);
    }
  }



  // Task: peek_mem
  //
  // Peeks the given memory ~mem~ using <uvm_mem::peek>, supplying 'this' as
  // the ~parent~ argument. Thus,
  //
  //| peek_mem(model.regA, status, offset, value);
  //
  // is equivalent to
  //
  //| model.regA.peek(status, offset, value, .parent(this));
  //
  // task
  void peek_mem(ref uvm_mem        mem,
		out uvm_status_e   status,
		uvm_reg_addr_t     offset,
		out uvm_reg_data_t value,
		string             kind = "",
		uvm_object         extension = null,
		string             fname = "",
		int                lineno = 0) {
    if (mem is null) {
      uvm_error("NO_MEM","Memory argument is null");
    }
    else {
      mem.peek(status, offset, value, kind, this, extension, fname, lineno);
    }
  }

   
  // Function- put_response
  //
  // not user visible. Needed to populate this sequence's response
  // queue with any bus item type. 
  //
  override void put_response(uvm_sequence_item response_item) {
    put_base_response(response_item);
  }
}


//------------------------------------------------------------------------------
// Class: uvm_reg_frontdoor
//
// Facade class for register and memory frontdoor access.
//------------------------------------------------------------------------------
//
// User-defined frontdoor access sequence
//
// Base class for user-defined access to register and memory reads and writes
// through a physical interface.
//
// By default, different registers and memories are mapped to different
// addresses in the address space and are accessed via those exclusively
// through physical addresses.
//
// The frontdoor allows access using a non-linear and/or non-mapped mechanism.
// Users can extend this class to provide the physical access to these registers.
//
abstract class uvm_reg_frontdoor: uvm_reg_sequence!(uvm_sequence!(uvm_sequence_item))
{
  // mixin(uvm_sync_string);
  // Variable: rw_info
  //
  // Holds information about the register being read or written
  //
  // @uvm_public_sync
  private uvm_reg_item _rw_info;
  // uvm_sync_public _rw_info uvm_reg_item
  final public uvm_reg_item rw_info() {synchronized(this) return this._rw_info;}
  final public void rw_info(uvm_reg_item val) {synchronized(this) this._rw_info = val;}

  // Variable: sequencer
  //
  // Sequencer executing the operation
  //
  // @uvm_public_sync
  private uvm_sequencer_base _sequencer;
  // uvm_sync_public _sequencer uvm_sequencer_base
  final public uvm_sequencer_base sequencer() {synchronized(this) return this._sequencer;}
  final public void sequencer(uvm_sequencer_base val) {synchronized(this) this._sequencer = val;}

  // Function: new
  //
  // Constructor, new object givne optional ~name~.
  //
  this(string name="") {
    super(name);
  }

  // @uvm_public_sync
  private string _fname;
  // uvm_sync_public _fname string
  final public string fname() {synchronized(this) return this._fname;}
  final public void fname(string val) {synchronized(this) this._fname = val;}

  // @uvm_public_sync
  private int _lineno;
  // uvm_sync_public _lineno int
  final public int lineno() {synchronized(this) return this._lineno;}
  final public void lineno(int val) {synchronized(this) this._lineno = val;}

}

