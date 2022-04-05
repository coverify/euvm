//
//----------------------------------------------------------------------
// Copyright 2019-2021 Coverify Sysmtems Technology
// Copyright 2018 Cadence Design Systems, Inc.
// Copyright 2018-2020 NVIDIA Corporation
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

module uvm.base.uvm_run_test_callback;

import uvm.meta.misc;
import uvm.base.uvm_scope;
import uvm.base.uvm_callback;
import std.algorithm.searching: canFind;
import std.algorithm.mutation: removeItem = remove;

// @uvm-ieee 1800.2-2020 auto F.6.1
abstract class uvm_run_test_callback: uvm_callback
{

  static class uvm_scope: uvm_scope_base
  {
    @uvm_none_sync
    private uvm_run_test_callback[] _m_registered_cbs;
  }

  mixin (uvm_scope_sync_string);
  
  // @uvm-ieee 1800.2-2020 auto F.6.2.1
  // @uvm-ieee 1800.2-2020 auto F.7.1.1
  this( string name="uvm_run_test_callback") {
    super(name);
  }

  // @uvm-ieee 1800.2-2020 auto F.6.2.2
  void pre_run_test() {}

  // @uvm-ieee 1800.2-2020 auto F.6.2.3
  void post_run_test() {}

  // @uvm-ieee 1800.2-2020 auto F.6.2.4
  void pre_abort() {}

  // @uvm-ieee 1800.2-2020 auto F.6.2.5
  static bool add(uvm_run_test_callback cb) {
    synchronized (_uvm_scope_inst) {
      if (cb is null || canFind(_uvm_scope_inst._m_registered_cbs, cb))
	return false;
      _uvm_scope_inst._m_registered_cbs ~= cb;
      return true;
    }
  }

  // @uvm-ieee 1800.2-2020 auto F.6.2.6
  static bool remove(uvm_run_test_callback cb) { // delete is a keyword
    synchronized (_uvm_scope_inst) {
      if (cb !is null && canFind(_uvm_scope_inst._m_registered_cbs, cb)) {
	uvm_run_test_callback[] cbs = _uvm_scope_inst._m_registered_cbs.dup;
	_uvm_scope_inst._m_registered_cbs = removeItem!(x => x is cb)(cbs);
	return true;
      }
      else
	return false;
    }
  }

  static void m_do_pre_run_test() {
    synchronized (_uvm_scope_inst) {
      foreach (cb; _uvm_scope_inst._m_registered_cbs) {
	cb.pre_run_test();
      }
    }
  }
    
  static void m_do_post_run_test() {
    synchronized (_uvm_scope_inst) {
      foreach (cb; _uvm_scope_inst._m_registered_cbs) {
	cb.post_run_test();
      }
    }
  }

  static void m_do_pre_abort() {
    synchronized (_uvm_scope_inst) {
      foreach (cb; _uvm_scope_inst._m_registered_cbs) {
	cb.pre_abort();
      }
    }
  }
}
