//
// -------------------------------------------------------------
// Copyright 2015-2021 Coverify Systems Technology
// Copyright 2010-2011 Mentor Graphics Corporation
// Copyright 2014 Semifore
// Copyright 2010-2018 Synopsys, Inc.
// Copyright 2010-2018 Cadence Design Systems, Inc.
// Copyright 2010 AMD
// Copyright 2015 NVIDIA Corporation
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

import uvm.reg.uvm_reg_block: uvm_reg_block;

import uvm.base.uvm_object: uvm_object;
import uvm.base.uvm_pool: uvm_object_string_pool;
import uvm.base.uvm_queue: uvm_queue;
import uvm.base.uvm_comparer: uvm_comparer;
import uvm.base.uvm_printer: uvm_printer;
import uvm.base.uvm_packer: uvm_packer;
import uvm.base.uvm_globals: uvm_fatal,
  uvm_error, uvm_warning;
import uvm.base.uvm_object_defines;

import uvm.meta.misc;
import esdl.rand: rand;

// @uvm-ieee 1800.2-2017 auto 18.3.1
class uvm_reg_file: uvm_object, rand.barrier
{
  mixin uvm_sync;
  
  @uvm_private_sync
  private uvm_reg_block     _parent;
  @uvm_private_sync
  private uvm_reg_file      _m_rf;
  @uvm_private_sync
  private string            _default_hdl_path = "RTL";
  @uvm_private_sync
  private uvm_object_string_pool!(uvm_queue!string) _hdl_paths_pool;


  mixin uvm_object_utils;
  
  //----------------------
  // Group -- NODOCS -- Initialization
  //----------------------

  // @uvm-ieee 1800.2-2017 auto 18.3.2.1
  this(string name="") {
    synchronized(this) {
      super(name);
      _hdl_paths_pool = new uvm_object_string_pool!(uvm_queue!string)("hdl_paths");
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.3.2.2
  void configure(uvm_reg_block blk_parent,
		 uvm_reg_file regfile_parent,
		 string hdl_path = "") {
    synchronized(this) {
      if (blk_parent is null) {
	uvm_error("UVM/RFILE/CFG/NOBLK",
		  "uvm_reg_file::configure() called without a parent block for instance \""
		  ~ get_name() ~ "\" of register file type \"" ~ get_type_name() ~ "\".");
	return;
      }
      this._parent = blk_parent;
      this._m_rf = regfile_parent;
      this.add_hdl_path(hdl_path);
    }
  }

  //---------------------
  // Group -- NODOCS -- Introspection
  //---------------------

  //
  // Function -- NODOCS -- get_name
  // Get the simple name
  //
  // Return the simple object name of this register file.
  //

  //
  // Function -- NODOCS -- get_full_name
  // Get the hierarchical name
  //
  // Return the hierarchal name of this register file.
  // The base of the hierarchical name is the root block.
  //

  override string get_full_name() {
    synchronized(this) {
      string retval;
      retval = this.get_name();

      // Is there a parent register file?
      if (_m_rf !is null)
	return _m_rf.get_full_name() ~ "." ~ retval;

      // No: then prepend the full name of the parent block (if any)
      if (this._parent is null)
	return retval;
      return this._parent.get_full_name() ~ "." ~ retval;
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.3.3.1
  uvm_reg_block get_parent() {
    return get_block();
  }

  uvm_reg_block get_block() {
    synchronized(this) {
      return this._parent;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.3.3.2
  uvm_reg_file get_regfile() {
    synchronized(this) {
      return _m_rf;
    }
  }


  //----------------
  // Group -- NODOCS -- Backdoor
  //----------------

  // @uvm-ieee 1800.2-2017 auto 18.3.4.1
  void clear_hdl_path(string kind = "RTL") {
    synchronized(this) {
      if (kind == "ALL") {
	_hdl_paths_pool =
	  new uvm_object_string_pool!(uvm_queue!string)("hdl_paths");
	return;
      }

      if (kind == "") {
	if (_m_rf !is null) 
	  kind = m_rf.get_default_hdl_path();
	else
	  kind = _parent.get_default_hdl_path();
      }

      if (! _hdl_paths_pool.exists(kind)) {
	uvm_warning("RegModel", "Unknown HDL Abstraction '" ~ kind ~ "'");
	return;
      }

      _hdl_paths_pool.remove(kind);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.3.4.2
  void add_hdl_path(string path, string kind = "RTL") {
    synchronized(this) {
      uvm_queue!(string) paths;

      paths = _hdl_paths_pool.get(kind);

      paths.push_back(path);
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.3.4.3
  bool has_hdl_path(string kind = "") {
    synchronized(this) {
      if (kind == "") {
	if (_m_rf !is null)
	  kind = _m_rf.get_default_hdl_path();
	else
	  kind = _parent.get_default_hdl_path();
      }
      return kind in _hdl_paths_pool;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.3.4.4
  void get_hdl_path(ref string[] paths, string kind = "") {
    synchronized(this) {
      uvm_queue!string hdl_paths;

      if (kind == "") {
	if (_m_rf !is null)
	  kind = _m_rf.get_default_hdl_path();
	else
	  kind = _parent.get_default_hdl_path();
      }

      if (! has_hdl_path(kind)) {
	uvm_error("RegModel", "Register does not have hdl path defined for abstraction '"
		  ~ kind ~ "'");
	return;
      }

      hdl_paths = _hdl_paths_pool.get(kind);

      for (int i=0; i < hdl_paths.length; i++)
	paths ~= hdl_paths.get(i);
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.3.4.5
  void get_full_hdl_path(out string[] paths,
			 string kind = "",
			 string separator = ".") {
    synchronized(this) {
      if (kind == "")
	kind = get_default_hdl_path();

      if (! has_hdl_path(kind)) {
	uvm_error("RegModel", "Register file does not have hdl path defined for abstraction '"
		  ~ kind ~ "'");
	return;
      }

      // paths = null;

      uvm_queue!(string) hdl_paths = _hdl_paths_pool.get(kind);

      string[] parent_paths;
      if (_m_rf !is null)
	_m_rf.get_full_hdl_path(parent_paths, kind, separator);
      else if (_parent !is null)
	_parent.get_full_hdl_path(parent_paths, kind, separator);

      for (int i=0; i < hdl_paths.length; i++) {
	string hdl_path = hdl_paths.get(i);

	if (parent_paths.length == 0) {
	  if (hdl_path != "")
	    paths ~= hdl_path;
	  continue;
	}

	foreach (path; parent_paths)  {
	  if (hdl_path == "")
	    paths ~= path;
	  else
	    paths ~= path ~ separator ~ hdl_path ;
	}
      }
    }
  }


  // @uvm-ieee 1800.2-2017 auto 18.3.4.7
  void set_default_hdl_path(string kind) {
    synchronized(this) {
      if (kind == "") {
	if (_m_rf !is null)
	  kind = m_rf.get_default_hdl_path();
	else if (_parent is null)
	  kind = parent.get_default_hdl_path();
	else {
	  uvm_error("RegModel", "Register file has no parent. " ~
		    "Must specify a valid HDL abstraction (kind)");
	  return;
	}
      }
      _default_hdl_path = kind;
    }
  }

  // @uvm-ieee 1800.2-2017 auto 18.3.4.6
  string get_default_hdl_path() {
    synchronized(this) {
      if (_default_hdl_path == "") {
	if (_m_rf !is null)
	  return _m_rf.get_default_hdl_path();
	else
	  return _parent.get_default_hdl_path();
      }
      return _default_hdl_path;
    }
  }

  override void do_print (uvm_printer printer) {
    super.do_print(printer);
  }

  override string convert2string() {
    uvm_fatal("RegModel",
	      "RegModel register files cannot be converted to strings");
    return "";
  }

  override uvm_object clone() {
    uvm_fatal("RegModel","RegModel register files cannot be cloned");
    return null;
  }

  override void do_copy(uvm_object rhs) {
    uvm_fatal("RegModel","RegModel register files cannot be copied");
  }

  override bool do_compare(uvm_object  rhs,
			   uvm_comparer comparer) {
    uvm_warning("RegModel","RegModel register files cannot be compared");
    return 0;
  }

  override void do_pack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel register files cannot be packed");
  }

  override void do_unpack (uvm_packer packer) {
    uvm_warning("RegModel","RegModel register files cannot be unpacked");
  }
}
