//
// -------------------------------------------------------------
//    Copyright 2010 Synopsys, Inc.
//    Copyright 2010 Mentor Graphics Corporation
//    Copyright 2010 Cadence Design Systems, Inc.
//    Copyright 2015 Coverify systems Technology
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
module uvm.reg.uvm_reg_file;

import uvm.base.uvm_object;
import uvm.base.uvm_pool;
import uvm.base.uvm_queue;
import uvm.base.uvm_comparer;
import uvm.base.uvm_printer;
import uvm.base.uvm_packer;
import uvm.base.uvm_globals;

import uvm.reg.uvm_reg_block;

//
// CLASS: uvm_reg_file
// Register file abstraction base class
//
// A register file is a collection of register files and registers
// used to create regular repeated structures.
//
// Register files are usually instantiated as arrays.
//
abstract class uvm_reg_file: uvm_object
{

  private uvm_reg_block     parent;
  private uvm_reg_file      m_rf;
  private string            default_hdl_path = "RTL";
  private uvm_object_string_pool!(uvm_queue!string) hdl_paths_pool;


  //----------------------
  // Group: Initialization
  //----------------------

  //
  // Function: new
  //
  // Create a new instance
  //
  // Creates an instance of a register file abstraction class
  // with the specified name.
  //
  // extern function                  new        (string name="");

  // new

  this(string name="") {
    synchronized(this) {
      super(name);
      hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!string)("hdl_paths");
    }
  }

  //
  // Function: configure
  // Configure a register file instance
  //
  // Specify the parent block and register file of the register file
  // instance.
  // If the register file is instantiated in a block,
  // ~regfile_parent~ is specified as ~null~.
  // If the register file is instantiated in a register file,
  // ~blk_parent~ must be the block parent of that register file and
  // ~regfile_parent~ is specified as that register file.
  //
  // If the register file corresponds to a hierarchical RTL structure,
  // it's contribution to the HDL path is specified as the ~hdl_path~.
  // Otherwise, the register file does not correspond to a hierarchical RTL
  // structure (e.g. it is physically flattened) and does not contribute
  // to the hierarchical HDL path of any contained registers.
  //
  // extern function void     configure  (uvm_reg_block blk_parent,
  //                                      uvm_reg_file regfile_parent,
  //                                      string hdl_path = "");

  // configure

  void configure(uvm_reg_block blk_parent,
		 uvm_reg_file regfile_parent,
		 string hdl_path = "") {
    synchronized(this) {
      this.parent = blk_parent;
      this.m_rf = regfile_parent;
      this.add_hdl_path(hdl_path);
    }
  }

  //---------------------
  // Group: Introspection
  //---------------------

  //
  // Function: get_name
  // Get the simple name
  //
  // Return the simple object name of this register file.
  //

  //
  // Function: get_full_name
  // Get the hierarchical name
  //
  // Return the hierarchal name of this register file.
  // The base of the hierarchical name is the root block.
  //
  // extern virtual function string        get_full_name();

  // get_full_name

  override string get_full_name() {
    synchronized(this) {
      string retval;
      retval = this.get_name();

      // Do not include top-level name in full name
      if (m_rf !is null) {
	return m_rf.get_full_name() ~ "." ~ get_full_name;
      }

      // Do not include top-level name in full name
      uvm_reg_block blk = this.get_block();
      if (blk is null) {
	return retval;
      }
      if (blk.get_parent() is null) {
	return retval;
      }

      return this.parent.get_full_name() ~ "." ~ retval;
    }
  }

  //
  // Function: get_parent
  // Get the parent block
  //
  // extern virtual function uvm_reg_block get_parent ();

  // get_parent

  uvm_reg_block get_parent() {
    return get_block();
  }

  // extern virtual function uvm_reg_block get_block  ();

  // get_block

  uvm_reg_block get_block() {
    synchronized(this) {
      return this.parent;
    }
  }


  //
  // Function: get_regfile
  // Get the parent register file
  //
  // Returns ~null~ if this register file is instantiated in a block.
  //
  // extern virtual function uvm_reg_file  get_regfile     ();

  // get_regfile

  uvm_reg_file get_regfile() {
    synchronized(this) {
      return m_rf;
    }
  }


  //----------------
  // Group: Backdoor
  //----------------

  //
  // Function:  clear_hdl_path
  // Delete HDL paths
  //
  // Remove any previously specified HDL path to the register file instance
  // for the specified design abstraction.
  //
  // extern function void clear_hdl_path    (string kind = "RTL");

  // clear_hdl_path

  void clear_hdl_path(string kind = "RTL") {
    synchronized(this) {
      if (kind == "ALL") {
	hdl_paths_pool =
	  new uvm_object_string_pool!(uvm_queue!string)("hdl_paths");
	return;
      }

      if (kind == "") {
	if (m_rf !is null) {
	  kind = m_rf.get_default_hdl_path();
	}
	else {
	  kind = parent.get_default_hdl_path();
	}
      }

      if (!hdl_paths_pool.exists(kind)) {
	uvm_root_warning("RegModel", "Unknown HDL Abstraction '" ~ kind ~ "'");
	return;
      }

      hdl_paths_pool.remove(kind);
    }
  }

  //
  // Function:  add_hdl_path
  // Add an HDL path
  //
  // Add the specified HDL path to the register file instance for the specified
  // design abstraction. This method may be called more than once for the
  // same design abstraction if the register file is physically duplicated
  // in the design abstraction
  //
  // extern function void add_hdl_path      (string path, string kind = "RTL");

  // add_hdl_path

  void add_hdl_path(string path, string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(string) paths;

      paths = hdl_paths_pool.get(kind);

      paths.push_back(path);
    }
  }


  //
  // Function:   has_hdl_path
  // Check if a HDL path is specified
  //
  // Returns TRUE if the register file instance has a HDL path defined for the
  // specified design abstraction. If no design abstraction is specified,
  // uses the default design abstraction specified for the nearest
  // enclosing register file or block
  //
  // If no design asbtraction is specified, the default design abstraction
  // for this register file is used.
  //
  // extern function bit  has_hdl_path      (string kind = "");

  // has_hdl_path

  bool has_hdl_path(string kind = "") {
    synchronized(this) {
      if (kind == "") {
	if (m_rf !is null) {
	  kind = m_rf.get_default_hdl_path();
	}
	else {
	  kind = parent.get_default_hdl_path();
	}
      }
      return hdl_paths_pool.exists(kind);
    }
  }


  //
  // Function:  get_hdl_path
  // Get the incremental HDL path(s)
  //
  // Returns the HDL path(s) defined for the specified design abstraction
  // in the register file instance. If no design abstraction is specified, uses
  // the default design abstraction specified for the nearest enclosing
  // register file or block.
  // Returns only the component of the HDL paths that corresponds to
  // the register file, not a full hierarchical path
  //
  // If no design asbtraction is specified, the default design abstraction
  // for this register file is used.
  //
  // extern function void get_hdl_path      (ref string paths[$], input string kind = "");

  // get_hdl_path

  void get_hdl_path(ref string[] paths, string kind = "") {
    synchronized(this) {
      uvm_queue!string hdl_paths;

      if (kind == "") {
	if (m_rf !is null) {
	  kind = m_rf.get_default_hdl_path();
	}
	else {
	  kind = parent.get_default_hdl_path();
	}
      }

      if (!has_hdl_path(kind)) {
	uvm_root_error("RegModel", "Register does not have hdl path" ~
		  " defined for abstraction '" ~ kind ~ "'");
	return;
      }

      hdl_paths = hdl_paths_pool.get(kind);

      for (int i=0; i<hdl_paths.length; i++) {
	paths ~= hdl_paths.get(i);
      }
    }
  }


  //
  // Function:  get_full_hdl_path
  // Get the full hierarchical HDL path(s)
  //
  // Returns the full hierarchical HDL path(s) defined for the specified
  // design abstraction in the register file instance. If no design abstraction
  // is specified, uses the default design abstraction specified for the
  // nearest enclosing register file or block.
  // There may be more than one path returned even
  // if only one path was defined for the register file instance, if any of the
  // parent components have more than one path defined for the same design
  // abstraction
  //
  // If no design asbtraction is specified, the default design abstraction
  // for each ancestor register file or block is used to get each
  // incremental path.
  //
  // extern function void get_full_hdl_path (ref string paths[$],
  //					  input string kind = "",
  //					  input string separator = ".");

  // get_full_hdl_path

  void get_full_hdl_path(out string[] paths,
			 string kind = "",
			 in string separator = ".") {
    synchronized(this) {
      if (kind == "")
	kind = get_default_hdl_path();

      if (!has_hdl_path(kind)) {
	uvm_root_error("RegModel", "Register file does not have" ~
		  " hdl path defined for abstraction '" ~ kind ~ "'");
	  return;
      }

      // paths = null;

      uvm_queue!(string) hdl_paths = hdl_paths_pool.get(kind);

      string[] parent_paths;
      if (m_rf !is null) {
	m_rf.get_full_hdl_path(parent_paths, kind, separator);
      }
      else if (parent !is null) {
	parent.get_full_hdl_path(parent_paths, kind, separator);
      }

      for (int i=0; i<hdl_paths.length;i ++) {
	string hdl_path = hdl_paths.get(i);

	if (parent_paths.length == 0) {
	  if (hdl_path != "") {
	    paths ~= hdl_path;
	  }
	  continue;
	}

	foreach (path; parent_paths)  {
	  if (hdl_path == "") {
	    paths ~= path;
	  }
	  else {
	    paths ~= path ~ separator ~ hdl_path ;
	  }
	}
      }
    }
  }


  //
  // Function:    set_default_hdl_path
  // Set the default design abstraction
  //
  // Set the default design abstraction for this register file instance.
  //
  // extern function void   set_default_hdl_path (string kind);

  // set_default_hdl_path

  void set_default_hdl_path(string kind) {
    synchronized(this) {
      if (kind == "") {
	if (m_rf !is null) {
	  kind = m_rf.get_default_hdl_path();
	}
	else if (parent is null) {
	  kind = parent.get_default_hdl_path();
	}
	else {
	  uvm_root_error("RegModel", "Register file has no parent. " ~
		    "Must specify a valid HDL abstraction (kind)");
	  return;
	}
      }
      default_hdl_path = kind;
    }
  }



  //
  // Function:  get_default_hdl_path
  // Get the default design abstraction
  //
  // Returns the default design abstraction for this register file instance.
  // If a default design abstraction has not been explicitly set for this
  // register file instance, returns the default design absraction for the
  // nearest register file or block ancestor.
  // Returns "" if no default design abstraction has been specified.
  //
  // extern function string get_default_hdl_path ();

  // get_default_hdl_path

  string get_default_hdl_path() {
    synchronized(this) {
      if (default_hdl_path == "") {
	if (m_rf !is null) {
	  return m_rf.get_default_hdl_path();
	}
	else {
	  return parent.get_default_hdl_path();
	}
      }
      return default_hdl_path;
    }
  }

  //-------------
  // STANDARD OPS
  //-------------

  // extern virtual function void          do_print (uvm_printer printer);

  // do_print

  override void do_print (uvm_printer printer) {
    super.do_print(printer);
  }

  // convert2string

  override string convert2string() {
    uvm_root_fatal("RegModel",
	      "RegModel register files cannot be converted to strings");
    return "";
  }

  // extern virtual function string        convert2string();
  // extern virtual function uvm_object    clone      ();

  // clone

  override uvm_object clone() {
    uvm_root_fatal("RegModel","RegModel register files cannot be cloned");
    return null;
  }


  // extern virtual function void          do_copy    (uvm_object rhs);

  // do_copy

  override void do_copy(uvm_object rhs) {
    uvm_root_fatal("RegModel","RegModel register files cannot be copied");
  }


  // extern virtual function bit           do_compare (uvm_object  rhs,
  //                                                   uvm_comparer comparer);

  // do_compare

  override bool do_compare(uvm_object  rhs,
			   uvm_comparer comparer) {
    uvm_root_warning("RegModel","RegModel register files cannot be compared");
    return 0;
  }

  // extern virtual function void          do_pack    (uvm_packer packer);

  // do_pack

  override void do_pack (uvm_packer packer) {
    uvm_root_warning("RegModel","RegModel register files cannot be packed");
  }

  // extern virtual function void          do_unpack  (uvm_packer packer);

  // do_unpack

  override void do_unpack (uvm_packer packer) {
    uvm_root_warning("RegModel","RegModel register files cannot be unpacked");
  }
}
