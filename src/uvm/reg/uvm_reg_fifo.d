//
// -------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2014-2018 NVIDIA Corporation
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


//------------------------------------------------------------------------------
// Class -- NODOCS -- uvm_reg_fifo
//
// This special register models a DUT FIFO accessed via write/read,
// where writes push to the FIFO and reads pop from it.
//
// Backdoor access is not enabled, as it is not yet possible to force
// complete FIFO state, i.e. the write and read indexes used to access
// the FIFO data.
//
//------------------------------------------------------------------------------

import uvm.meta.misc;

import uvm.reg.uvm_reg: uvm_reg;
import uvm.reg.uvm_reg_model;
import uvm.reg.uvm_reg_field: uvm_reg_field;
import uvm.reg.uvm_reg_map: uvm_reg_map;
import uvm.reg.uvm_reg_item: uvm_reg_item;
import uvm.seq.uvm_sequence_base: uvm_sequence_base;
import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_globals: uvm_warning, uvm_error;

import esdl.data.queue;
import esdl.rand;

import std.string: format;

class uvm_reg_fifo: uvm_reg
{
  mixin uvm_sync;
  
  @uvm_private_sync
  private uvm_reg_field _value;
  @uvm_private_sync
  private int _m_set_cnt;
  void dcr_m_set_cnt() {
    synchronized(this) {
      _m_set_cnt -= 1;
    }
  }
  @uvm_private_sync
  private uint _m_size;

  // Variable -- NODOCS -- fifo
  //
  // The abstract representation of the FIFO. Constrained
  // to be no larger than the size parameter. It is public
  // to enable subtypes to add constraints on it and randomize.
  //
  @uvm_public_sync
  private @rand Queue!uvm_reg_data_t _fifo;

  private size_t _get_fifo_length() {
    synchronized(this) {
      return _fifo.length;
    }
  }

  private uvm_reg_data_t _get_fifo_elem(size_t i) {
    synchronized(this) {
      return _fifo[i];
    }
  }

  Constraint!q{
    _fifo.length <= _m_size;
  }  valid_fifo_size;


  //----------------------
  // Group -- NODOCS -- Initialization
  //----------------------

  // Function: new
  //
  // Creates an instance of a FIFO register having ~size~ elements of
  // ~n_bits~ each.
  //
  this(string name,
       uint size,
       uint n_bits,
       int has_cover) {
    synchronized(this) {
      super(name, n_bits, has_cover);
      _m_size = size;
    }
  }


  // Funtion: build
  //
  // Builds the abstract FIFO register object. Called by
  // the instantiating block, a <uvm_reg_block> subtype.
  //
  void build() {
    synchronized(this) {
      _value = uvm_reg_field.type_id.create("value");
      _value.configure(this, get_n_bits(), 0, "RW",
		       false, 0, true, false, true);
    }
  }

  // Function: set_compare
  //
  // Sets the compare policy during a mirror (read) of the DUT FIFO. 
  // The DUT read value is checked against its mirror only when both the
  // ~check~ argument in the <mirror()> call and the compare policy
  // for the field is <UVM_CHECK>.
  //
  void set_compare(uvm_check_e check=UVM_CHECK) {
    synchronized(this) {
      _value.set_compare(check);
    }
  }


  //---------------------
  // Group -- NODOCS -- Introspection
  //---------------------

  // Function: size
  //
  // The number of entries currently in the FIFO.
  //
  uint size() {
    synchronized(this) {
      return cast(uint) _fifo.length();
    }
  }


  // Function: capacity
  //
  // The maximum number of entries, or depth, of the FIFO.

  uint capacity() {
    synchronized(this) {
      return _m_size;
    }
  }

  //--------------
  // Group -- NODOCS -- Access
  //--------------

  //  Function: write
  // 
  //  Pushes the given value to the DUT FIFO. If auto-predition is enabled,
  //  the written value is also pushed to the abstract FIFO before the
  //  call returns. If auto-prediction is not enabled (see 
  //  <uvm_map::set_auto_predict>), the value is pushed to abstract
  //  FIFO only when the write operation is observed on the target bus.
  //  This mode requires using the <uvm_reg_predictor #(BUSTYPE)> class.
  //  If the write is via an <update()> operation, the abstract FIFO
  //  already contains the written value and is thus not affected by
  //  either prediction mode.


  //  Function: read
  //
  //  Reads the next value out of the DUT FIFO. If auto-prediction is
  //  enabled, the frontmost value in abstract FIFO is popped.


  // Function: set
  //
  // Pushes the given value to the abstract FIFO. You may call this
  // method several times before an <update()> as a means of preloading
  // the DUT FIFO. Calls to ~set()~ to a full FIFO are ignored. You
  // must call <update()> to update the DUT FIFO with your set values.
  //

  override void set(uvm_reg_data_t  value,
		    string          fname = "",
		    int             lineno = 0) {
    synchronized(this) {
      // emulate write, with intention of update
      value &= ((1 << get_n_bits())-1);
      if (_fifo.length == _m_size) {
	return;
      }
      super.set(value, fname, lineno);
      _m_set_cnt++;
      _fifo ~= this._value.get_value();
    }
  }
    

  // Function: update
  //
  // Pushes (writes) all values preloaded using <set(()> to the DUT>.
  // You must ~update~ after ~set~ before any blocking statements,
  // else other reads/writes to the DUT FIFO may cause the mirror to
  // become out of sync with the DUT.
  //
  // task
  override void update(out uvm_status_e  status,
		       uvm_door_e        door = UVM_DEFAULT_DOOR,
		       uvm_reg_map       map = null,
		       uvm_sequence_base parent = null,
		       int               prior = -1,
		       uvm_object        extension = null,
		       string            fname = "",
		       int               lineno = 0) {
    // declared in SV version but unused
    // uvm_reg_data_t upd;

    
    synchronized(this) {
      if (! _m_set_cnt || _fifo.length == 0) {
	return;
      }
      _m_update_in_progress = true;
    }
    // FIXME synchronization for fifo and for m_set_cnt
    for (size_t i = _get_fifo_length() - m_set_cnt; m_set_cnt > 0; i++, dcr_m_set_cnt()) {
      if (i >= 0) {
	//uvm_reg_data_t val = get();
	//super.update(status,door,map,parent,prior,extension,fname,lineno);
	write(status,_get_fifo_elem(i),door,map,parent,prior,extension,fname,lineno);
      }
    }
    synchronized(this) {
      _m_update_in_progress = false;
    }
  }


  // Function: mirror
  //
  // Reads the next value out of the DUT FIFO. If auto-prediction is
  // enabled, the frontmost value in abstract FIFO is popped. If 
  // the ~check~ argument is set and comparison is enabled with
  // <set_compare()>.


  // Function: get
  //
  // Returns the next value from the abstract FIFO, but does not pop it.
  // Used to get the expected value in a <mirror()> operation.
  //
  override uvm_reg_data_t get(string fname="", int lineno=0) {
    synchronized(this) {
      //return fifo.pop_front();
      return _fifo[0];
    }
  }


  // Function: do_predict
  //
  // Updates the abstract (mirror) FIFO based on <write()> and
  // <read()> operations.  When auto-prediction is on, this method
  // is called before each read, write, peek, or poke operation returns.
  // When auto-prediction is off, this method is called by a 
  // <uvm_reg_predictor> upon receipt and conversion of an observed bus
  // operation to this register.
  //
  // If a write prediction, the observed
  // write value is pushed to the abstract FIFO as long as it is 
  // not full and the operation did not originate from an <update()>.
  // If a read prediction, the observed read value is compared
  // with the frontmost value in the abstract FIFO if <set_compare()>
  // enabled comparison and the FIFO is not empty.
  //
  override void do_predict(uvm_reg_item      rw,
			   uvm_predict_e     kind = UVM_PREDICT_DIRECT,
			   uvm_reg_byte_en_t be = -1) {
    synchronized(this) {
      super.do_predict(rw,kind,be);

      if (rw.status == UVM_NOT_OK)
        return;

      final switch (kind) {

      case UVM_PREDICT_WRITE,
	UVM_PREDICT_DIRECT:
	{
	  if (_fifo.length != _m_size && !m_update_in_progress) {
	    _fifo ~= this._value.get_value();
	  }
	}

      case UVM_PREDICT_READ:
        {
	  uvm_reg_data_t value = rw.get_value(0) & ((1 << get_n_bits())-1);
	  uvm_reg_data_t mirror_val;
	  if (_fifo.length == 0) {
	    return;
	  }
	  _fifo.popFront(mirror_val);
	  if (this.value.get_compare() == UVM_CHECK && mirror_val != value) {
	    uvm_warning("MIRROR_MISMATCH",
			format("Observed DUT read value 'h%0h != mirror" ~
			       " value 'h%0h", value, mirror_val));
	  }
        }

      }

    }
  }


  // Group -- NODOCS -- Special Overrides

  // Task: pre_write
  //
  // Special pre-processing for a <write()> or <update()>.
  // Called as a result of a <write()> or <update()>. It is an error to
  // attempt a write to a full FIFO or a write while an update is still
  // pending. An update is pending after one or more calls to <set()>.
  // If in your application the DUT allows writes to a full FIFO, you
  // must override ~pre_write~ as appropriate.
  //

  // task -- does not have a wait statement though
  override void pre_write(uvm_reg_item rw) {
    synchronized(this) {
      if (_m_set_cnt && !m_update_in_progress) {
	uvm_error("Needs Update","Must call update() after set()" ~
		  " and before write()");
	rw.set_status(UVM_NOT_OK);
	return;
      }
      if (_fifo.length >= _m_size && !m_update_in_progress) {
	uvm_error("FIFO Full","Write to full FIFO ignored");
	rw.set_status(UVM_NOT_OK);
	return;
      }
    }
  }


  // Task: pre_read
  //
  // Special post-processing for a <write()> or <update()>.
  // Aborts the operation if the internal FIFO is empty. If in your application
  // the DUT does not behave this way, you must override ~pre_write~ as
  // appropriate.
  //
  //

  // task
  override void pre_read(uvm_reg_item rw) {
    synchronized(this) {
      // abort if fifo empty
      if (_fifo.length == 0) {
	rw.set_status(UVM_NOT_OK);
	return;
      }
    }
  }


  void postRandomize() {
    synchronized(this) {
      _m_set_cnt = 0;
    }
  }

}
