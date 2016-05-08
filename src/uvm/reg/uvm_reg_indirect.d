//
// -------------------------------------------------------------
//    Copyright 2010 Synopsys, Inc.
//    Copyright 2010 Cadence Design Systems, Inc.
//    Copyright 2011 Mentor Graphics Corporation
//    Copyright 2015 Coverify Systems Technology
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

// typedef class uvm_reg_indirect_ftdr_seq;

//-----------------------------------------------------------------
// CLASS: uvm_reg_indirect_data
// Indirect data access abstraction class
//
// Models the behavior of a register used to indirectly access
// a register array, indexed by a second ~address~ register.
//
// This class should not be instantiated directly.
// A type-specific class extension should be used to
// provide a factory-enabled constructor and specify the
// ~n_bits~ and coverage models.
//-----------------------------------------------------------------

class uvm_reg_indirect_data: uvm_reg
{

  protected uvm_reg m_idx;
  protected uvm_reg m_tbl[];

  // Function: new
  // Create an instance of this class
  //
  // Should not be called directly,
  // other than via super.new().
  // The value of ~n_bits~ must match the number of bits
  // in the indirect register array.
  // function new(string name = "uvm_reg_indirect",
  // 	       int unsigned n_bits,
  // 	       int has_cover);
  this(string name = "uvm_reg_indirect", int unsigned n_bits, int has_cover) {
    super(name, n_bits, has_cover);
  }

  // virtual function void build();
  void build() {}

  // Function: configure
  // Configure the indirect data register.
  //
  // The ~idx~ register specifies the index,
  // in the ~reg_a~ register array, of the register to access.
  // The ~idx~ must be written to first.
  // A read or write operation to this register will subsequently
  // read or write the indexed register in the register array.
  //
  // The number of bits in each register in the register array must be
  // equal to ~n_bits~ of this register.
  // 
  // See <uvm_reg::configure()> for the remaining arguments.
  // function void configure (uvm_reg idx,
  // 			   uvm_reg reg_a[],
  // 			   uvm_reg_block blk_parent,
  // 			   uvm_reg_file regfile_parent = null);
  void configure (uvm_reg idx, uvm_reg reg_a[],
		  uvm_reg_block blk_parent,
		  uvm_reg_file regfile_parent = null) {
    synchronized(this) {
      super.configure(blk_parent, regfile_parent, "");
      m_idx = idx;
      m_tbl = reg_a;

      // Not testable using pre-defined sequences
      uvm_resource_db!(bit).set("REG::" ~ get_full_name(),
				"NO_REG_TESTS", 1);

      // Add a frontdoor to each indirectly-accessed register
      // for every address map this register is in.
      foreach (map, unused; m_maps) {
	add_frontdoors(map);
      }
    }
  }
   
  // /*local*/ virtual function void add_map(uvm_reg_map map);
  void add_map(uvm_reg_map map) {
    synchronized(this) {
      super.add_map(map);
      add_frontdoors(map);
    }
  }
   
  // local function void add_frontdoors(uvm_reg_map map);
  void add_frontdoors(uvm_reg_map map) {
    synchronized(this) {
      foreach (i, row; m_tbl) {
	if (row is null) {
	  uvm_error(get_full_name(),
		    format("Indirect register #%0d is NULL", i));
	  continue;
	}
	uvm_reg_indirect_ftdr_seq fd =
	  new uvm_reg_indirect_ftdr_seq(m_idx, i, this);
	if (row.is_in_map(map)) {
	  row.set_frontdoor(fd, map);
	}
	else {
	  map.add_reg(row, -1, "RW", 1, fd);
	}
      }
    }
  }
   
  void do_predict (uvm_reg_item      rw,
		   uvm_predict_e     kind = UVM_PREDICT_DIRECT,
		   uvm_reg_byte_en_t be = -1) {
    synchronized(this) {
      if (m_idx.get() >= m_tbl.length) {
	uvm_error(get_full_name(),
		  format("Address register %s has a value" ~
			 " (%0d) greater than the maximum" ~
			 " indirect register array size (%0d)",
			 m_idx.get_full_name(), m_idx.get(), m_tbl.size()));
	rw.status = UVM_NOT_OK;
	return;
      }

      //NOTE limit to 2**32 registers
      int unsigned idx = m_idx.get();
      m_tbl[idx].do_predict(rw, kind, be);
    }
  }

  uvm_reg_map get_local_map(uvm_reg_map map, string caller="") {
    synchronized(this) {
      return  m_idx.get_local_map(map, caller);
    }
  }

  //
  // Just for good measure, to catch and short-circuit non-sensical uses
  //
  void add_field  (uvm_reg_field field) {
    uvm_error(get_full_name(),
	      "Cannot add field to an indirect data access register");
  }

  void set (uvm_reg_data_t  value,
	    string          fname = "",
	    int             lineno = 0) {
    uvm_error(get_full_name(), "Cannot set() an indirect data access register");
  }
   
  uvm_reg_data_t  get(string  fname = "",
		      int     lineno = 0) {
    uvm_error(get_full_name(), "Cannot get() an indirect data access register");
    return 0;
  }
   
  uvm_reg get_indirect_reg(string  fname = "",
			   int     lineno = 0) {
    synchronized(this) {
      int unsigned idx = m_idx.get_mirrored_value();
      return(m_tbl[idx]);
    }
  }

  bool needs_update() {
    return false;
  }

  // task
  void write(out uvm_status_e      status,
	     in  uvm_reg_data_t    value,
	     in  uvm_path_e        path = UVM_DEFAULT_PATH,
	     in  uvm_reg_map       map = null,
	     in  uvm_sequence_base parent = null,
	     in  int               prior = -1,
	     in  uvm_object        extension = null,
	     in  string            fname = "",
	     in  int               lineno = 0) {
    if (path == UVM_DEFAULT_PATH) {
      uvm_reg_block blk = get_parent();
      path = blk.get_default_path();
    }
      
    if (path == UVM_BACKDOOR) {
      uvm_warning(get_full_name(),
		  "Cannot backdoor-write an indirect data access" ~
		  " register. Switching to frontdoor.");
      path = UVM_FRONTDOOR;
    }

    // Can't simply call super.write() because it'll call set()
    uvm_reg_item rw;

    XatomicX(1);

    rw = uvm_reg_item.type_id.create("write_item",,get_full_name());
    rw.element      = this;
    rw.element_kind = UVM_REG;
    rw.kind         = UVM_WRITE;
    rw.value[0]     = value;
    rw.path         = path;
    rw.map          = map;
    rw.parent       = parent;
    rw.prior        = prior;
    rw.extension    = extension;
    rw.fname        = fname;
    rw.lineno       = lineno;
         
    do_write(rw);

    status = rw.status;

    XatomicX(0);
  }

  
  // task
  void read(out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    in  uvm_path_e        path = UVM_DEFAULT_PATH,
	    in  uvm_reg_map       map = null,
	    in  uvm_sequence_base parent = null,
	    in  int               prior = -1,
	    in  uvm_object        extension = null,
	    in  string            fname = "",
	    in  int               lineno = 0) {

    if (path == UVM_DEFAULT_PATH) {
      uvm_reg_block blk = get_parent();
      path = blk.get_default_path();
    }
      
    if (path == UVM_BACKDOOR) {
      uvm_warning(get_full_name(),
		  "Cannot backdoor-read an indirect data access" ~
		  " register. Switching to frontdoor.");
      path = UVM_FRONTDOOR;
    }
      
    super.read(status, value, path, map, parent, prior, extension, fname, lineno);
  }

  // task
  void poke(out uvm_status_e      status,
	    in  uvm_reg_data_t    value,
	    in  string            kind = "",
	    in  uvm_sequence_base parent = null,
	    in  uvm_object        extension = null,
	    in  string            fname = "",
	    in  int               lineno = 0) {
    uvm_error(get_full_name(), "Cannot poke() an indirect data access register");
    status = UVM_NOT_OK;
  }

  // task
  void peek(out uvm_status_e      status,
	    out uvm_reg_data_t    value,
	    in  string            kind = "",
	    in  uvm_sequence_base parent = null,
	    in  uvm_object        extension = null,
	    in  string            fname = "",
	    in  int               lineno = 0) {
    uvm_error(get_full_name(), "Cannot peek() an indirect data access register");
    status = UVM_NOT_OK;
  }

  // task
  void update(out uvm_status_e      status,
	      in  uvm_path_e        path = UVM_DEFAULT_PATH,
	      in  uvm_reg_map       map = null,
	      in  uvm_sequence_base parent = null,
	      in  int               prior = -1,
	      in  uvm_object        extension = null,
	      in  string            fname = "",
	      in  int               lineno = 0) {
    status = UVM_IS_OK;
  }
   
  // task
  void mirror(out uvm_status_e      status,
	      in uvm_check_e        check  = UVM_NO_CHECK,
	      in uvm_path_e         path = UVM_DEFAULT_PATH,
	      in uvm_reg_map        map = null,
	      in uvm_sequence_base  parent = null,
	      in int                prior = -1,
	      in  uvm_object        extension = null,
	      in string             fname = "",
	      in int                lineno = 0) {
    status = UVM_IS_OK;
  }
   
}

class uvm_reg_indirect_ftdr_seq: uvm_reg_frontdoor
{
  private uvm_reg m_addr_reg;
  private uvm_reg m_data_reg;
  private int     m_idx;
   
  this(uvm_reg addr_reg, int idx, uvm_reg data_reg) {
    synchronized(this) {
      super("uvm_reg_indirect_ftdr_seq");
      m_addr_reg = addr_reg;
      m_idx      = idx;
      m_data_reg = data_reg;
    }
  }

  // task
  void body() {

    // $cast(rw,rw_info.clone());
    uvm_reg_item rw = cast(uvm_reg_item) rw_info.clone;
      
    rw.element = m_addr_reg;
    rw.kind    = UVM_WRITE;
    rw.value[0]= m_idx;

    m_addr_reg.XatomicX(1);
    m_data_reg.XatomicX(1);
      
    m_addr_reg.do_write(rw);

    if (rw.status == UVM_NOT_OK) {
      return;
    }

    // $cast(rw,rw_info.clone());
    rw = cast(uvm_reg_item) rw_info.clone;
    rw.element = m_data_reg;

    if (rw_info.kind == UVM_WRITE) {
      m_data_reg.do_write(rw);
    }
    else {
      m_data_reg.do_read(rw);
      rw_info.value[0] = rw.value[0];
    }

    m_addr_reg.XatomicX(0);
    m_data_reg.XatomicX(0);
      
    rw_info.status = rw.status;
  }
}
